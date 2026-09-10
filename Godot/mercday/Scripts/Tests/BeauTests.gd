class_name BeauTests

#Beau bond cases: sightings, time apart, the bond revert scope and the two support readers.
#Run: godot --headless --path . -- --beau-tests
#Every case resets the campaign clock, the roster and the trait records, so order does not matter.

const DISTRACTED := "Distracted"

const YEARNING := "Longing Yearning"
const HEART_EYED := "Heart-Eyed Bushy-Tailed"
const WAKE_UP := "Something to Wake Up To"
const HONEYMOON := "Honeymoon Phase"

const YEARNING_CELL := "on:beau_apart:beau_absent:lasting:bond:stat:max_hp:-1"
const HEART_EYED_CELL := "on:beau_seen:always:resource:excess_hp:+1"
const WAKE_UP_CELL := "on:beau_seen:has_trait:Heart-Eyed Bushy-Tailed:resource:excess_hp:+1"
const HONEYMOON_SELF := "on:round_start:first_round+beau_present:apply:distracted:1:round"
const HONEYMOON_BEAU := "on:round_start:first_round+beau_present:to:beau:apply:distracted:1:round"
const COMPOUND_CELL := "on:round_start:first_round+beau_present:resource:excess_hp:+1"
const SUPPORT_TOKEN := "grant:passive:always:none:support_given:beau:+50%"


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_partner(res)
	_case_contract_sighting(res)
	_case_apart_blocks(res)
	_case_bond_max_hp(res)
	_case_hp_floor(res)
	_case_tavern_sighting(res)
	_case_seen_grants(res)
	_case_support(res)
	_case_compound_condition(res)
	_case_honeymoon(res)
	_reset()
	return TestFixtures.summarize(res, "BEAU")


#Helpers

static func _reset() -> void:
	CampaignClock.reset()
	BeauSystem.reset()
	TraitRuntime.clear_all()


static func _merc(name: String) -> MercenaryData:
	var m := MercenaryData.new()
	m.merc_name = name
	m.merc_uid = CampaignKnowledge.next_uid()
	m.max_stats = {"max_vigor": 8, "max_dexterity": 8, "max_cognition": 8, "max_wile": 8, "size": 1}
	m.luck_roll = 5.0
	m.stats = {"level": 5}
	m.stats = StatCalculator.calculate_all(m)
	m.stats["pain_limit"] = 0
	m.stats_baseline = StatCalculator.calculate_all(m)
	m.current_hp = int(m.stats.get("maximum_hit_points", 1))
	m.current_ep = 0
	return m


#Two mercs pointing at each other, seeded as the whole roster BeauSystem.tick walks.
static func _pair(a_name: String, b_name: String) -> Array[MercenaryData]:
	var a := _merc(a_name)
	var b := _merc(b_name)
	a.beau_uid = b.merc_uid
	b.beau_uid = a.merc_uid
	var pair: Array[MercenaryData] = [a, b]
	BeauSystem.set_roster(pair)
	return pair


static func _give(merc: MercenaryData, name: String, cell: String) -> void:
	var td := TraitData.new()
	td.trait_name = name
	td.trait_type = "Perk"
	td.effect_dsl = cell
	merc.perks.append(td)


static func _run_for(team: Array[MercenaryData]) -> ContractRun:
	var run := ContractRun.new()
	run.team.assign(team)
	return run


static func _max_hp(merc: MercenaryData) -> int:
	return int(merc.stats.get("maximum_hit_points", 0))


static func _count(lines: Array[String], needle: String) -> int:
	var n: int = 0
	for line: String in lines:
		if line.contains(needle):
			n += 1
	return n


#Cases

static func _case_partner(res: Dictionary) -> void:
	_reset()
	var pair := _pair("Kael", "Mira")
	var a: MercenaryData = pair[0]
	var b: MercenaryData = pair[1]
	var run := _run_for(pair)
	TestFixtures.check(res, "partner reads the contract team", BeauSystem.partner(a, {"run": run}) == b,
		"%s resolves to %s through run.team" % [a.merc_name, b.merc_name])
	TestFixtures.check(res, "partner falls back to the roster", BeauSystem.partner(a, {}) == b,
		"with no run in ctx the roster still holds %s" % b.merc_name)
	var lone := _merc("Toft")
	TestFixtures.check(res, "no beau uid resolves to nothing", BeauSystem.partner(lone, {}) == null,
		"beau_uid 0 has no partner")
	BeauSystem.reset()
	TestFixtures.check(res, "an empty roster resolves to nothing", BeauSystem.partner(a, {}) == null,
		"reset clears the roster")


static func _case_contract_sighting(res: Dictionary) -> void:
	_reset()
	var pair := _pair("Kael", "Mira")
	var a: MercenaryData = pair[0]
	var first := _run_for(pair)
	var lines: Array[String] = BeauSystem.begin_contract(first)
	TestFixtures.check(res, "deploying together is a sighting", _count(lines, "BEAU SEEN") == 2,
		"expected one line per merc, got %d" % lines.size())
	TestFixtures.check(res, "the sighting names the contract", _count(lines, "(contract)") == 2,
		"lines: %s" % ", ".join(lines))
	TestFixtures.check(res, "the pair are marked together", a.beau_together,
		"beau_together is true after a shared deployment")
	var second := _run_for(pair)
	var again: Array[String] = BeauSystem.begin_contract(second)
	TestFixtures.check(res, "a second contract together is not a new sighting", again.is_empty(),
		"expected no lines, got %d" % again.size())
	var solo: Array[MercenaryData] = [a]
	var apart_lines: Array[String] = BeauSystem.begin_contract(_run_for(solo))
	TestFixtures.check(res, "deploying without the beau separates the pair",
		not a.beau_together and apart_lines.is_empty(),
		"beau_together %s with %d lines" % [str(a.beau_together), apart_lines.size()])


static func _case_apart_blocks(res: Dictionary) -> void:
	_reset()
	var pair := _pair("Kael", "Mira")
	var a: MercenaryData = pair[0]
	a.on_contract = true
	BeauSystem.tick(CampaignClock.now())
	CampaignClock.advance(BeauSystem.TICK_MINUTES)
	var first: Array[String] = BeauSystem.tick(CampaignClock.now())
	TestFixtures.check(res, "ten days apart lands one block", a.beau_hp_ticks == 1,
		"expected 1 block, got %d" % a.beau_hp_ticks)
	TestFixtures.check(res, "a merc with no clause logs nothing", _count(first, "BEAU APART") == 0,
		"the block still counts, but nothing was taken to report")
	CampaignClock.advance(15 * CampaignClock.MINUTES_PER_DAY)
	BeauSystem.tick(CampaignClock.now())
	TestFixtures.check(res, "twenty five days apart lands two blocks", a.beau_hp_ticks == 2,
		"expected 2 blocks, got %d" % a.beau_hp_ticks)
	TestFixtures.check(res, "the part block is carried", a.beau_apart_minutes == 7200,
		"expected 7200 minutes carried, got %d" % a.beau_apart_minutes)


static func _case_bond_max_hp(res: Dictionary) -> void:
	_reset()
	var pair := _pair("Kael", "Mira")
	var a: MercenaryData = pair[0]
	_give(a, YEARNING, YEARNING_CELL)
	a.on_contract = true
	var base: int = _max_hp(a)
	BeauSystem.tick(CampaignClock.now())
	CampaignClock.advance(BeauSystem.TICK_MINUTES)
	var first: Array[String] = BeauSystem.tick(CampaignClock.now())
	TestFixtures.check(res, "a block apart costs one maximum hit point", _max_hp(a) == base - 1,
		"max HP %d -> %d" % [base, _max_hp(a)])
	TestFixtures.check(res, "the block is logged", _count(first, "BEAU APART") == 1,
		"expected one BEAU APART line, got %d" % _count(first, "BEAU APART"))
	CampaignClock.advance(BeauSystem.TICK_MINUTES)
	BeauSystem.tick(CampaignClock.now())
	TestFixtures.check(res, "a second block costs another", _max_hp(a) == base - 2,
		"max HP %d -> %d" % [base, _max_hp(a)])
	a.on_contract = false
	CampaignClock.advance(60)
	var seen: Array[String] = BeauSystem.tick(CampaignClock.now())
	TestFixtures.check(res, "a sighting reverts every block at once", _max_hp(a) == base,
		"expected max HP back to %d, got %d" % [base, _max_hp(a)])
	TestFixtures.check(res, "the counters reset on the sighting",
		a.beau_hp_ticks == 0 and a.beau_apart_minutes == 0 and _count(seen, "BEAU SEEN") == 2,
		"ticks %d, minutes %d, lines %d" % [a.beau_hp_ticks, a.beau_apart_minutes,
		_count(seen, "BEAU SEEN")])


static func _case_hp_floor(res: Dictionary) -> void:
	_reset()
	var pair := _pair("Nim", "Vale")
	var a: MercenaryData = pair[0]
	_give(a, YEARNING, YEARNING_CELL)
	a.on_contract = true
	a.stats["maximum_hit_points"] = 2
	a.current_hp = 2
	BeauSystem.tick(CampaignClock.now())
	CampaignClock.advance(BeauSystem.TICK_MINUTES)
	BeauSystem.tick(CampaignClock.now())
	TestFixtures.check(res, "the loss stops at a maximum of 1", _max_hp(a) == 1,
		"max HP 2 -> %d" % _max_hp(a))
	TestFixtures.check(res, "current hit points follow the maximum to 1", a.current_hp == 1,
		"current HP 2 -> %d" % a.current_hp)
	CampaignClock.advance(BeauSystem.TICK_MINUTES)
	var floored: Array[String] = BeauSystem.tick(CampaignClock.now())
	TestFixtures.check(res, "a block at the floor takes nothing",
		_max_hp(a) == 1 and a.current_hp == 1,
		"max HP %d, current HP %d" % [_max_hp(a), a.current_hp])
	TestFixtures.check(res, "the floor is logged", _count(floored, "BEAU FLOOR") == 1,
		"expected one BEAU FLOOR line, got %d" % _count(floored, "BEAU FLOOR"))


static func _case_tavern_sighting(res: Dictionary) -> void:
	_reset()
	var pair := _pair("Bex", "Tull")
	var a: MercenaryData = pair[0]
	var b: MercenaryData = pair[1]
	for merc: MercenaryData in pair:
		merc.rest_lockout_until = 600
		merc.rest_lockout_kind = RestSystem.KIND_RESPITE
	var resting: Array[String] = BeauSystem.tick(CampaignClock.now())
	TestFixtures.check(res, "two resting mercs do not meet", _count(resting, "BEAU SEEN") == 0,
		"a respite lockout keeps the pair apart")
	CampaignClock.advance(600)
	a.on_contract = true
	var deployed: Array[String] = BeauSystem.tick(CampaignClock.now())
	TestFixtures.check(res, "a deployed merc does not meet at the tavern",
		_count(deployed, "BEAU SEEN") == 0, "one of the pair is away on a contract")
	a.on_contract = false
	CampaignClock.advance(10)
	var met: Array[String] = BeauSystem.tick(CampaignClock.now())
	TestFixtures.check(res, "both lockouts passed is a tavern sighting", _count(met, "BEAU SEEN") == 2,
		"expected one line per merc, got %d" % _count(met, "BEAU SEEN"))
	TestFixtures.check(res, "the sighting names the tavern", _count(met, "(tavern)") == 2,
		"lines: %s" % ", ".join(met))
	TestFixtures.check(res, "both sides are marked together", a.beau_together and b.beau_together,
		"the reunion sets the flag on each merc")


static func _case_seen_grants(res: Dictionary) -> void:
	_reset()
	var pair := _pair("Kael", "Mira")
	var a: MercenaryData = pair[0]
	_give(a, HEART_EYED, HEART_EYED_CELL)
	_give(a, WAKE_UP, WAKE_UP_CELL)
	var run := _run_for(pair)
	BeauSystem.begin_contract(run)
	TestFixtures.check(res, "both beau_seen clauses grant excess HP", ExcessPool.amount(a, "hp") == 2,
		"expected 2 Excess HP, got %d" % ExcessPool.amount(a, "hp"))
	TestFixtures.check(res, "the grant is logged on the contract",
		_count(run.log_lines, "gains 1 Excess HP (%s)" % HEART_EYED) == 1,
		"log: %s" % ", ".join(run.log_lines))
	_reset()
	var solo := _pair("Odd", "Wren")
	var c: MercenaryData = solo[0]
	_give(c, WAKE_UP, WAKE_UP_CELL)
	BeauSystem.begin_contract(_run_for(solo))
	TestFixtures.check(res, "the second clause needs the first perk", ExcessPool.amount(c, "hp") == 0,
		"expected 0 Excess HP without %s, got %d" % [HEART_EYED, ExcessPool.amount(c, "hp")])


static func _case_support(res: Dictionary) -> void:
	_reset()
	var pair := _pair("Kael", "Mira")
	var a: MercenaryData = pair[0]
	var b: MercenaryData = pair[1]
	var other := _merc("Toft")
	TestFixtures.check(res, "no token is no bonus",
		is_equal_approx(BeauSystem.support_multiplier(a, b), 1.0),
		"the passive token is what turns the bonus on")
	a.passive_effects.append(SUPPORT_TOKEN)
	TestFixtures.check(res, "the token raises support toward the beau",
		is_equal_approx(BeauSystem.support_multiplier(a, b), 1.5),
		"expected 1.5, got %.2f" % BeauSystem.support_multiplier(a, b))
	TestFixtures.check(res, "support toward anyone else is unchanged",
		is_equal_approx(BeauSystem.support_multiplier(a, other), 1.0),
		"expected 1.0 toward a merc who is not the beau")
	var spec: Dictionary = {"stat": "vigor"}
	var pool: int = int(a.stats.get("vigor", 0))
	var want: int = ceili(float(pool) * 0.5)
	TestFixtures.check(res, "the aid roll gains half the pool as enhancements",
		StateInfliction.support_enhancements(a, b, spec) == want,
		"expected %d enhancements from a pool of %d, got %d" % [want, pool,
		StateInfliction.support_enhancements(a, b, spec)])
	TestFixtures.check(res, "no enhancements toward anyone else",
		StateInfliction.support_enhancements(a, other, spec) == 0,
		"only the beau is aided better")


static func _case_compound_condition(res: Dictionary) -> void:
	_reset()
	var pair := _pair("Kael", "Mira")
	var a: MercenaryData = pair[0]
	var b: MercenaryData = pair[1]
	_give(a, "TEST Compound Round", COMPOUND_CELL)
	var team_a: Array[MercenaryData] = [a, b]
	var team_b: Array[MercenaryData] = [_merc("Ghul")]
	var state := BattleState.create(team_a, team_b, null)
	state.round_number = 1
	var lines: Array[String] = []
	TraitRuntime.on_round_start(state, lines)
	TestFixtures.check(res, "first_round with the beau present passes", ExcessPool.amount(a, "hp") == 1,
		"expected 1 Excess HP on round 1, got %d" % ExcessPool.amount(a, "hp"))
	state.round_number = 2
	TraitRuntime.on_round_start(state, lines)
	TestFixtures.check(res, "the compound fails on a later round", ExcessPool.amount(a, "hp") == 1,
		"round 2 grants nothing, pool is %d" % ExcessPool.amount(a, "hp"))
	state.round_number = 1
	a.beau_uid = 0
	TraitRuntime.on_round_start(state, lines)
	TestFixtures.check(res, "the compound fails with no beau on the field",
		ExcessPool.amount(a, "hp") == 1,
		"beau_present is false, pool is %d" % ExcessPool.amount(a, "hp"))


static func _case_honeymoon(res: Dictionary) -> void:
	_reset()
	var injected: bool = _ensure_distracted()
	if ConstStates.state_from_token("distracted") == "":
		print("WARN BEAU | no Distracted state definition, honeymoon case skipped")
		return
	var pair := _pair("Kael", "Mira")
	var a: MercenaryData = pair[0]
	var b: MercenaryData = pair[1]
	_give(a, HONEYMOON, HONEYMOON_SELF + "|" + HONEYMOON_BEAU)
	var team_a: Array[MercenaryData] = [a, b]
	var team_b: Array[MercenaryData] = [_merc("Ghul")]
	var state := BattleState.create(team_a, team_b, null)
	state.round_number = 1
	var lines: Array[String] = []
	TraitRuntime.on_round_start(state, lines)
	TestFixtures.check(res, "round one distracts the holder", ConstStates.has_state(a, DISTRACTED),
		"%s holds %s" % [a.merc_name, DISTRACTED])
	TestFixtures.check(res, "round one distracts the beau", ConstStates.has_state(b, DISTRACTED),
		"the to:beau clause reaches %s" % b.merc_name)
	var expires_a: int = int(state.get_state_timer(a, DISTRACTED).get("expires", 0))
	var expires_b: int = int(state.get_state_timer(b, DISTRACTED).get("expires", 0))
	TestFixtures.check(res, "the state carries a one round timer",
		expires_a == 1 and expires_b == 1,
		"expires holder %d, beau %d" % [expires_a, expires_b])
	ConstStates.remove_state(a, DISTRACTED)
	ConstStates.remove_state(b, DISTRACTED)
	state.clear_state_timer(a, DISTRACTED)
	state.clear_state_timer(b, DISTRACTED)
	state.round_number = 2
	TraitRuntime.on_round_start(state, lines)
	TestFixtures.check(res, "round two does not distract again",
		not ConstStates.has_state(a, DISTRACTED) and not ConstStates.has_state(b, DISTRACTED),
		"first_round is false from round 2 on")
	if injected:
		_drop_distracted()


#States.tsv carries no Distracted row yet; the case injects one and returns true when it did.
static func _ensure_distracted() -> bool:
	if ConstStates.DATA.has(DISTRACTED):
		return false
	var effects: Array[String] = ["skip_turn"]
	var removals: Array[String] = ["time:1:round"]
	ConstStates.DATA[DISTRACTED] = {
		"effects": effects,
		"removals": removals,
		"afflict_text": "[Target] cannot look away.",
		"remove_text": "[Target] gets back to work.",
		"special": "",
		"is_stacking": false,
		"inflict_default": "",
	}
	ConstStates.ALL.append(DISTRACTED)
	return true


static func _drop_distracted() -> void:
	ConstStates.DATA.erase(DISTRACTED)
	ConstStates.ALL.erase(DISTRACTED)
