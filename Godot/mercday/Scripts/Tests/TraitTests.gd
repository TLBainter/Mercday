class_name TraitTests

#Deterministic Traits.tsv effect cases. Run: godot --headless --path . -- --trait-tests
#Rolling clauses are seeded and repeated until the outcome is certain; nothing depends on one draw.

const SEED_CLOWN := 20260901
const SEED_DISSECTOR := 20260902
const SEED_ESCAPE := 20260903
const SEED_GROUP := 20260910
const SEED_INFLICT := 20260911
const REPS := 200


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_untapped_potential(res)
	_case_curse_marked(res)
	_case_beginners_luck(res)
	_case_survivors_guilt(res)
	_case_less_than_important(res)
	_case_down_to_clown(res)
	_case_tavern_brawler(res)
	_case_playing_with_fire(res)
	_case_wont_let_it_happen(res)
	_case_dont_heckle_me(res)
	_case_expert_dissector(res)
	_case_damage_dealt_bonus(res)
	_case_claustrophobic(res)
	_case_threat_of_capture(res)
	_case_eyes_in_the_back(res)
	_case_gotta_go_fastest(res)
	_case_shockingly_vicious(res)
	_case_party_tank(res)
	_case_no_one_escapes_me(res)
	_case_knowledge_grants(res)
	_case_fragile_cannon(res)
	_case_new_rows(res)
	_case_buddy_clauses(res)
	_case_perk_groups(res)
	_case_group_perk_generation(res)
	_case_apply_duration(res)
	_case_compound_condition(res)
	_case_bond_scope(res)
	_case_rest_beau_scopes(res)
	_case_inflict_outside(res)
	_case_item_grant(res)
	return TestFixtures.summarize(res, "TRAIT")


#Helpers

#A merc whose stats come from the real Stats.tsv formulas, so a percent or flat delta is observable.
static func _merc(name: String) -> MercenaryData:
	return TestFixtures.level_merc(name, false)


#A fresh merc with this trait DSL applied and its stats refreshed, to compare against a plain merc.
static func _applied(name: String, dsl: String) -> MercenaryData:
	var m := _merc(name)
	TraitDSL.apply_dsl_to_merc(m, dsl)
	StatCalculator.refresh(m)
	return m


#Raises the hit point pool before BattleState.create copies it into current_hp.
static func _hp(merc: MercenaryData, amount: int) -> void:
	merc.stats["maximum_hit_points"] = amount
	merc.current_hp = amount


static func _state(team_a: Array[MercenaryData], team_b: Array[MercenaryData]) -> BattleState:
	var st := BattleState.create(team_a, team_b, null)
	for m: MercenaryData in team_a:
		m.current_ep = 0
		m.excess_ap = 0
	for m2: MercenaryData in team_b:
		m2.current_ep = 0
		m2.excess_ap = 0
	return st


static func _lib(trait_name: String) -> TraitData:
	return DataManager.traits.get(trait_name, null) as TraitData


static func _require(res: Dictionary, label: String, trait_name: String) -> TraitData:
	var td: TraitData = _lib(trait_name)
	if td == null:
		TestFixtures.check(res, label, false, "Traits.tsv row '%s' is not in the DataManager trait library" % trait_name)
	return td


#Clears the trait runtime and looks up the row the case is about.
static func _begin(res: Dictionary, label: String, trait_name: String) -> TraitData:
	TraitRuntime.clear_all()
	return _require(res, label, trait_name)


static func _give(merc: MercenaryData, td: TraitData) -> void:
	if td == null:
		return
	if td.trait_type == "Drawback":
		merc.drawbacks.append(td)
	else:
		merc.perks.append(td)


static func _has_knowledge(merc: MercenaryData, k_name: String) -> bool:
	for k: UtilityTraitData in merc.knowledges:
		if k != null and k.utility_name == k_name:
			return true
	return false


static func _contract(type_name: String, stats: Dictionary, circs: Dictionary) -> ContractData:
	var c := ContractData.new()
	c.contract_type = type_name
	c.stat_boosts = stats
	c.circumstance_boosts = circs
	return c


static func _weapon(fragility: int, is_virtual: bool) -> WeaponData:
	var w := WeaponData.new()
	w.weapon_type = "Probe"
	w.is_ranged = false
	w.is_throwable = false
	w.fragility = fragility
	w.is_virtual = is_virtual
	return w


static func _near(a: float, b: float) -> bool:
	return absf(a - b) <= 0.01


static func _stat(merc: MercenaryData, key: String) -> float:
	return float(merc.stats.get(key, 0.0))


#Mirrors the Traits.tsv column 11 read in DataManager._load_traits for a synthetic cell.
static func _parse_groups(cell: String) -> Array[String]:
	var out: Array[String] = []
	for raw: String in cell.split(","):
		var group: String = DataManager.normalize_perk_group(raw)
		if group != "" and not out.has(group):
			out.append(group)
	return out


#Cases

static func _case_untapped_potential(res: Dictionary) -> void:
	var td: TraitData = _begin(res, "untapped potential row", "Untapped Potential")
	if td == null:
		return
	var m := _merc("Una")
	_give(m, td)
	var relevant: String = ConstCircumstances.NOTICE_COGNITION
	var circs: Dictionary = {}
	circs[relevant] = 15.0
	var c := _contract("Monster Hunt", {"Dexterity": 15.0}, circs)
	var team: Array[MercenaryData] = [m]
	var contract_run := TestFixtures.run_for(team, c, "")
	var before: int = TestFixtures.true_flags(m).size()
	TraitRuntime.begin_contract(contract_run)
	var after: Array[String] = TestFixtures.true_flags(m)
	TestFixtures.check(res, "untapped potential grants one contract relevant circumstance",
		after.size() == before + 1 and after.has(relevant),
		"flags before %d, after %s" % [before, str(after)])
	TestFixtures.check(res, "untapped potential removes itself", not TestFixtures.holds_trait(m, "Untapped Potential"),
		"perks %d drawbacks %d" % [m.perks.size(), m.drawbacks.size()])
	TraitRuntime.revert_contract(contract_run)
	TestFixtures.check(res, "untapped potential grant survives revert_contract",
		bool(m.circumstance_flags.get(relevant, false)) and TestFixtures.true_flags(m).size() == before + 1,
		"flags after revert %s" % str(TestFixtures.true_flags(m)))


static func _case_curse_marked(res: Dictionary) -> void:
	var td: TraitData = _begin(res, "curse marked row", "Curse Marked")
	if td == null:
		return
	var m := _merc("Cain")
	TraitDSL.apply_dsl_to_merc(m, td.effect_dsl)
	TestFixtures.check(res, "curse marked grants Presence (Vigor)",
		bool(m.circumstance_flags.get(ConstCircumstances.PRESENCE_VIGOR, false)),
		"flags %s" % str(TestFixtures.true_flags(m)))
	TestFixtures.check(res, "curse marked grants the Intimidating trait", TestFixtures.holds_trait(m, "Intimidating"),
		"perks %d, holds Intimidating %s" % [m.perks.size(), str(TestFixtures.holds_trait(m, "Intimidating"))])


static func _case_beginners_luck(res: Dictionary) -> void:
	var td: TraitData = _begin(res, "beginners luck row", "Beginner's Luck")
	if td == null:
		return
	var m := _merc("Bel")
	_give(m, td)
	var c := _contract("Assassinate", {"Dexterity": 15.0, "Cognition": 10.0}, {})
	var team: Array[MercenaryData] = [m]
	var contract_run := TestFixtures.run_for(team, c, "")
	var before: int = int(m.stats.get("dexterity", 0))
	TraitRuntime.end_contract(contract_run)
	var after: int = int(m.stats.get("dexterity", 0))
	TestFixtures.check(res, "beginners luck raises the contract core stat by 2", after == before + 2,
		"dexterity %d -> %d (contract core of Assassinate)" % [before, after])
	TestFixtures.check(res, "beginners luck removes itself", not TestFixtures.holds_trait(m, "Beginner's Luck"),
		"perks %d drawbacks %d" % [m.perks.size(), m.drawbacks.size()])


static func _case_survivors_guilt(res: Dictionary) -> void:
	var td: TraitData = _begin(res, "survivors guilt row", "Survivor's Guilt")
	if td == null:
		return
	var holder := _merc("Sur")
	var fallen := _merc("Fal")
	var foe := _merc("Foe")
	_hp(holder, 30)
	_give(holder, td)
	var team_a: Array[MercenaryData] = [holder, fallen]
	var team_b: Array[MercenaryData] = [foe]
	var st := _state(team_a, team_b)
	fallen.current_hp = 0
	fallen.is_dead = true
	var before: int = holder.current_hp
	var lines: Array[String] = []
	TraitRuntime.on_death(fallen, foe, st, lines)
	TestFixtures.check(res, "survivors guilt costs the holder 1 Will", holder.current_hp == before - 1,
		"holder hp %d -> %d, lines %d" % [before, holder.current_hp, lines.size()])


static func _case_less_than_important(res: Dictionary) -> void:
	var td: TraitData = _begin(res, "less than important row", "Less Than Important")
	if td == null:
		return
	var holder := _merc("Les")
	var a1 := _merc("Al")
	var a2 := _merc("Ar")
	var foe := _merc("Fo")
	_give(holder, td)
	var team_a: Array[MercenaryData] = [holder, a1, a2]
	var team_b: Array[MercenaryData] = [foe]
	var st := _state(team_a, team_b)
	var base: float = _stat(holder, "avoid")
	TraitRuntime.refresh_continuous(holder, st)
	var boosted: float = _stat(holder, "avoid")
	TestFixtures.check(res, "less than important scales avoid by the conscious ally count",
		base > 0.0 and _near(boosted, base * 1.6),
		"avoid %.2f -> %.2f with 2 conscious allies (expected %.2f)" % [base, boosted, base * 1.6])
	a1.current_hp = 0
	a1.is_dead = true
	a2.current_hp = 0
	a2.is_dead = true
	TraitRuntime.refresh_continuous(holder, st)
	TestFixtures.check(res, "less than important reverts when the allies drop", _near(_stat(holder, "avoid"), base),
		"avoid back to %.2f (base %.2f)" % [_stat(holder, "avoid"), base])


static func _case_down_to_clown(res: Dictionary) -> void:
	var td: TraitData = _begin(res, "down to clown row", "Down to Clown")
	if td == null:
		return
	var m := _merc("Clo")
	_give(m, td)
	var keep_a: String = ConstCircumstances.GRACE_DEXTERITY
	var keep_b: String = ConstCircumstances.SPEECH_WILE
	var blocked: Array[String] = []
	for display: String in ConstCircumstances.ALL:
		if display != keep_a and display != keep_b:
			blocked.append(display)
	m.blocked_circumstances = blocked
	var c := _contract("Entertain", {"Wile": 10.0}, {})
	var team: Array[MercenaryData] = [m]
	var contract_run := TestFixtures.run_for(team, c, "")
	seed(SEED_CLOWN)
	var count_held: bool = true
	var saw_kept: bool = false
	var saw_new: bool = false
	for _i: int in range(REPS):
		var start: Dictionary = {}
		start[keep_a] = true
		m.circumstance_flags = start
		TraitRuntime.end_contract(contract_run)
		var on_now: Array[String] = TestFixtures.true_flags(m)
		if on_now.size() != 1:
			count_held = false
			break
		if on_now[0] == keep_b:
			saw_new = true
		else:
			saw_kept = true
	TestFixtures.check(res, "down to clown swaps exactly one circumstance", count_held,
		"every one of %d runs ended holding exactly one circumstance" % REPS)
	TestFixtures.check(res, "down to clown can turn a new circumstance on", saw_new,
		"%s reached over %d seeded runs" % [keep_b, REPS])
	TestFixtures.check(res, "down to clown can re-roll the same circumstance", saw_kept,
		"%s reached over %d seeded runs" % [keep_a, REPS])


static func _case_tavern_brawler(res: Dictionary) -> void:
	var td: TraitData = _begin(res, "tavern brawler row", "Tavern Brawler")
	if td == null:
		return
	var plain := _merc("Tav0")
	var base: float = _stat(plain, "accuracy")
	var m := _applied("Tav", td.effect_dsl)
	TestFixtures.check(res, "tavern brawler grants +15 percent accuracy at generation",
		base > 0.0 and _near(_stat(m, "accuracy"), base * 1.15),
		"accuracy %.2f (base %.2f, expected %.2f)" % [_stat(m, "accuracy"), base, base * 1.15])
	_give(m, td)
	m.equipped_weapon = null
	TraitRuntime.refresh_continuous(m, null)
	TestFixtures.check(res, "tavern brawler unarmed reaches +30 percent", _near(_stat(m, "accuracy"), base * 1.30),
		"accuracy %.2f unarmed (expected %.2f)" % [_stat(m, "accuracy"), base * 1.30])
	m.equipped_weapon = _weapon(2, false)
	TraitRuntime.refresh_continuous(m, null)
	TestFixtures.check(res, "tavern brawler makeshift reaches +30 percent", _near(_stat(m, "accuracy"), base * 1.30),
		"accuracy %.2f with fragility 2 (expected %.2f)" % [_stat(m, "accuracy"), base * 1.30])
	m.equipped_weapon = _weapon(0, false)
	TraitRuntime.refresh_continuous(m, null)
	TestFixtures.check(res, "tavern brawler plain melee falls back to +15 percent",
		_near(_stat(m, "accuracy"), base * 1.15),
		"accuracy %.2f with a plain melee weapon (expected %.2f)" % [_stat(m, "accuracy"), base * 1.15])


static func _case_playing_with_fire(res: Dictionary) -> void:
	var td: TraitData = _begin(res, "playing with fire row", "Playing with Fire")
	if td == null:
		return
	var atk := _merc("Pyr")
	var def_m := _merc("Tar")
	_give(atk, td)
	_hp(atk, 30)
	_hp(def_m, 30)
	var team_a: Array[MercenaryData] = [atk]
	var team_b: Array[MercenaryData] = [def_m]
	var st := _state(team_a, team_b)
	var before: int = def_m.current_hp
	var lines := CombatApplicator.apply_damage(atk, def_m, 3, "Fire", st)
	TestFixtures.check(res, "a fire hit costs the defender 1 Will on top of the damage",
		def_m.current_hp == before - 4,
		"hp %d -> %d after a 3 point Fire hit, lines %d" % [before, def_m.current_hp, lines.size()])
	def_m.current_hp = 30
	before = def_m.current_hp
	lines = CombatApplicator.apply_damage(atk, def_m, 3, "Lacerate", st)
	TestFixtures.check(res, "a non fire hit costs no Will", def_m.current_hp == before - 3,
		"hp %d -> %d after a 3 point Lacerate hit" % [before, def_m.current_hp])


static func _case_wont_let_it_happen(res: Dictionary) -> void:
	var td: TraitData = _begin(res, "wont let it happen row", "Won't Let It Happen")
	if td == null:
		return
	var holder := _merc("Won")
	var ally := _merc("Ally")
	var gone := _merc("Gone")
	var foe := _merc("Enm")
	_give(holder, td)
	var team_a: Array[MercenaryData] = [holder, ally, gone]
	var team_b: Array[MercenaryData] = [foe]
	var st := _state(team_a, team_b)
	gone.current_hp = 0
	gone.is_dead = true
	var ally_base: float = _stat(ally, "cheat_death")
	var holder_base: float = _stat(holder, "cheat_death")
	var gone_base: float = _stat(gone, "cheat_death")
	var foe_base: float = _stat(foe, "cheat_death")
	TraitRuntime.refresh_continuous(holder, st)
	TestFixtures.check(res, "wont let it happen gives every living ally 25 cheat death",
		_near(_stat(ally, "cheat_death"), ally_base + 25.0),
		"ally cheat_death %.2f -> %.2f" % [ally_base, _stat(ally, "cheat_death")])
	TestFixtures.check(res, "wont let it happen skips the holder", _near(_stat(holder, "cheat_death"), holder_base),
		"holder cheat_death %.2f -> %.2f" % [holder_base, _stat(holder, "cheat_death")])
	TestFixtures.check(res, "wont let it happen skips the dead and the enemy",
		_near(_stat(gone, "cheat_death"), gone_base) and _near(_stat(foe, "cheat_death"), foe_base),
		"dead %.2f, enemy %.2f" % [_stat(gone, "cheat_death"), _stat(foe, "cheat_death")])


static func _case_dont_heckle_me(res: Dictionary) -> void:
	var td: TraitData = _begin(res, "dont heckle me row", "Don't Heckle Me")
	if td == null:
		return
	var m := _merc("Hek")
	_hp(m, 30)
	_give(m, td)
	var team: Array[MercenaryData] = [m]
	var wile_run := TestFixtures.run_for(team, _contract("Entertain", {"Wile": 15.0}, {}), "Failed")
	var before: int = m.current_hp
	TraitRuntime.end_contract(wile_run)
	TestFixtures.check(res, "dont heckle me costs 1 Will on a failed Wile contract", m.current_hp == before - 1,
		"hp %d -> %d" % [before, m.current_hp])
	TraitRuntime.clear_all()
	var vigor_run := TestFixtures.run_for(team, _contract("Rescue", {"Vigor": 15.0}, {}), "Failed")
	before = m.current_hp
	TraitRuntime.end_contract(vigor_run)
	TestFixtures.check(res, "dont heckle me ignores a failed Vigor contract", m.current_hp == before,
		"hp %d -> %d" % [before, m.current_hp])


static func _case_expert_dissector(res: Dictionary) -> void:
	var td: TraitData = _begin(res, "expert dissector row", "Expert Dissector")
	if td == null:
		return
	var m := _merc("Dis")
	_give(m, td)
	var team: Array[MercenaryData] = [m]
	var hunt := TestFixtures.run_for(team, _contract("Monster Hunt", {"Dexterity": 15.0}, {}), "Succeeded")
	seed(SEED_DISSECTOR)
	var rose: int = 0
	var fell: int = 0
	for _i: int in range(REPS):
		hunt.reward_paid = 1000
		TraitRuntime.end_contract(hunt)
		if hunt.reward_paid > 1000:
			rose += 1
		elif hunt.reward_paid < 1000:
			fell += 1
	TestFixtures.check(res, "expert dissector raises the monster hunt reward on some runs", rose > 0 and fell == 0,
		"%d of %d seeded runs rose, %d fell" % [rose, REPS, fell])
	TestFixtures.check(res, "expert dissector does not fire on every run", rose < REPS,
		"%d of %d runs paid the bonus" % [rose, REPS])
	TraitRuntime.clear_all()
	var other := TestFixtures.run_for(team, _contract("Military", {"Vigor": 15.0}, {}), "Succeeded")
	var changed: int = 0
	for _j: int in range(REPS):
		other.reward_paid = 1000
		TraitRuntime.end_contract(other)
		if other.reward_paid != 1000:
			changed += 1
	TestFixtures.check(res, "expert dissector ignores a non monster hunt contract", changed == 0,
		"%d of %d runs changed the reward" % [changed, REPS])


static func _case_damage_dealt_bonus(res: Dictionary) -> void:
	var td: TraitData = _begin(res, "fearsome cannonball row", "Fearsome Cannonball")
	if td == null:
		return
	var atk := _merc("Can")
	var plain := _merc("Pln")
	var def_m := _merc("Vic")
	_give(atk, td)
	_hp(atk, 30)
	_hp(plain, 30)
	_hp(def_m, 40)
	var team_a: Array[MercenaryData] = [atk, plain]
	var team_b: Array[MercenaryData] = [def_m]
	var st := _state(team_a, team_b)
	var before: int = def_m.current_hp
	CombatApplicator.apply_damage(plain, def_m, 3, "Sonic", st)
	var plain_loss: int = before - def_m.current_hp
	before = def_m.current_hp
	CombatApplicator.apply_damage(atk, def_m, 3, "Sonic", st)
	var trait_loss: int = before - def_m.current_hp
	TestFixtures.check(res, "damage_dealt +1 takes one more hit point",
		plain_loss == 3 and trait_loss == 4,
		"plain attacker %d, trait attacker %d on a 3 point Sonic hit" % [plain_loss, trait_loss])
	var rage: TraitData = _lib("Pact of the Rage")
	var viol: TraitData = _lib("Expert in Violence")
	var same: bool = rage != null and viol != null \
		and rage.effect_dsl == td.effect_dsl and viol.effect_dsl == td.effect_dsl
	TestFixtures.check(res, "the other two damage_dealt rows carry the same cell", same,
		"Pact of the Rage and Expert in Violence match Fearsome Cannonball")


static func _case_claustrophobic(res: Dictionary) -> void:
	var td: TraitData = _begin(res, "claustrophobic row", "Claustrophobic")
	if td == null:
		return
	var m := _merc("Cla")
	var foe := _merc("Wall")
	_hp(m, 30)
	_give(m, td)
	var team_a: Array[MercenaryData] = [m]
	var team_b: Array[MercenaryData] = [foe]
	var st := _state(team_a, team_b)
	var lines: Array[String] = []
	var before: int = m.current_hp
	TraitRuntime.on_state_gained(m, ConstStates.GRAPPLED, st, lines)
	TestFixtures.check(res, "claustrophobic costs 1 Will on Grappled", m.current_hp == before - 1,
		"hp %d -> %d" % [before, m.current_hp])
	before = m.current_hp
	TraitRuntime.on_state_gained(m, ConstStates.INHIBITED, st, lines)
	TestFixtures.check(res, "claustrophobic costs 1 Will on Inhibited", m.current_hp == before - 1,
		"hp %d -> %d" % [before, m.current_hp])
	before = m.current_hp
	TraitRuntime.on_state_gained(m, ConstStates.POISONED, st, lines)
	TestFixtures.check(res, "claustrophobic ignores an unrelated state", m.current_hp == before,
		"hp %d -> %d on Poisoned" % [before, m.current_hp])


static func _case_threat_of_capture(res: Dictionary) -> void:
	var td: TraitData = _begin(res, "threat of capture row", "Threat of Capture")
	if td == null:
		return
	var m := _merc("Thr")
	var foe := _merc("Cap")
	_hp(m, 30)
	_give(m, td)
	var team_a: Array[MercenaryData] = [m]
	var team_b: Array[MercenaryData] = [foe]
	var st := _state(team_a, team_b)
	var lines: Array[String] = []
	var before: int = m.current_hp
	TraitRuntime.fire("targeted_melee", m, {"state": st, "lines": lines})
	TestFixtures.check(res, "threat of capture costs 1 Will when targeted in melee", m.current_hp == before - 1,
		"hp %d -> %d" % [before, m.current_hp])


static func _case_eyes_in_the_back(res: Dictionary) -> void:
	var td: TraitData = _begin(res, "eyes in the back row", "Eyes in the Back of My Head")
	if td == null:
		return
	var plain := _merc("Eye0")
	var m := _applied("Eye", td.effect_dsl)
	TestFixtures.check(res, "eyes in the back raises avoid by 40",
		_near(_stat(m, "avoid"), _stat(plain, "avoid") + 40.0),
		"avoid %.2f vs base %.2f" % [_stat(m, "avoid"), _stat(plain, "avoid")])
	TestFixtures.check(res, "avoid melee follows avoid",
		_near(_stat(m, "avoid_melee"), _stat(plain, "avoid_melee") + 40.0),
		"avoid_melee %.2f vs base %.2f" % [_stat(m, "avoid_melee"), _stat(plain, "avoid_melee")])


static func _case_gotta_go_fastest(res: Dictionary) -> void:
	var td: TraitData = _begin(res, "gotta go fastest row", "Gotta Go Fastest")
	if td == null:
		return
	var m := _merc("Fas")
	var foe := _merc("Rab")
	_hp(m, 30)
	_give(m, td)
	var team_a: Array[MercenaryData] = [m]
	var team_b: Array[MercenaryData] = [foe]
	var st := _state(team_a, team_b)
	m.stats["speed"] = 5
	foe.stats["speed"] = 9
	var lines: Array[String] = []
	var before: int = m.current_hp
	TraitRuntime.on_turn_start(m, st, lines)
	TestFixtures.check(res, "gotta go fastest costs 1 Will with a faster enemy", m.current_hp == before - 1,
		"hp %d -> %d, speeds %d vs %d" % [before, m.current_hp, 5, 9])
	TraitRuntime.clear_all()
	foe.stats["speed"] = 1
	before = m.current_hp
	TraitRuntime.on_turn_start(m, st, lines)
	TestFixtures.check(res, "gotta go fastest ignores a slower field", m.current_hp == before,
		"hp %d -> %d, speeds %d vs %d" % [before, m.current_hp, 5, 1])


static func _case_shockingly_vicious(res: Dictionary) -> void:
	var td: TraitData = _begin(res, "shockingly vicious row", "Shockingly Vicious and Vile")
	if td == null:
		return
	var killer := _merc("Kil")
	var victim := _merc("Vim")
	_hp(killer, 30)
	_give(killer, td)
	var team_a: Array[MercenaryData] = [killer]
	var team_b: Array[MercenaryData] = [victim]
	var st := _state(team_a, team_b)
	victim.current_hp = 0
	victim.is_dead = true
	var lines: Array[String] = []
	var before: int = killer.current_hp
	TraitRuntime.on_death(victim, killer, st, lines)
	TestFixtures.check(res, "shockingly vicious costs the killer 1 Will", killer.current_hp == before - 1,
		"killer hp %d -> %d" % [before, killer.current_hp])


static func _case_party_tank(res: Dictionary) -> void:
	var td: TraitData = _begin(res, "party tank row", "Party Tank")
	if td == null:
		return
	var plain := _merc("Tnk0")
	var m := _applied("Tnk", td.effect_dsl)
	TestFixtures.check(res, "party tank adds 1 maximum hit point",
		int(m.stats.get("maximum_hit_points", 0)) == int(plain.stats.get("maximum_hit_points", 0)) + 1,
		"maximum_hit_points %d vs base %d" % [int(m.stats.get("maximum_hit_points", 0)),
		int(plain.stats.get("maximum_hit_points", 0))])
	_give(m, td)
	var foe := _merc("Hit")
	_hp(m, 30)
	var team_a: Array[MercenaryData] = [m]
	var team_b: Array[MercenaryData] = [foe]
	var st := _state(team_a, team_b)
	var before: int = m.current_hp
	CombatApplicator.apply_damage(foe, m, 5, "Sonic", st)
	TestFixtures.check(res, "party tank turns a 5 damage hit into 4", before - m.current_hp == 4,
		"hp %d -> %d" % [before, m.current_hp])
	before = m.current_hp
	CombatApplicator.apply_damage(foe, m, 1, "Sonic", st)
	TestFixtures.check(res, "party tank keeps a 1 damage hit at 1", before - m.current_hp == 1,
		"hp %d -> %d" % [before, m.current_hp])


static func _case_no_one_escapes_me(res: Dictionary) -> void:
	var td: TraitData = _begin(res, "no one escapes me row", "No One Escapes Me")
	if td == null:
		return
	var m := _merc("Esc")
	_hp(m, 30)
	_give(m, td)
	seed(SEED_ESCAPE)
	var hits: int = 0
	for _i: int in range(REPS):
		m.current_hp = 30
		TraitRuntime.fire("miss_dealt", m, {})
		if m.current_hp < 30:
			hits += 1
	TestFixtures.check(res, "no one escapes me costs Will on a fraction of the misses",
		hits >= 20 and hits <= REPS, "%d of %d seeded fires cost 1 Will" % [hits, REPS])
	var bare := _merc("Bar")
	_hp(bare, 30)
	var bare_hits: int = 0
	for _j: int in range(REPS):
		bare.current_hp = 30
		TraitRuntime.fire("miss_dealt", bare, {})
		if bare.current_hp < 30:
			bare_hits += 1
	TestFixtures.check(res, "no one escapes me never fires without the trait", bare_hits == 0,
		"%d of %d fires cost a merc without the trait" % [bare_hits, REPS])


static func _case_knowledge_grants(res: Dictionary) -> void:
	TraitRuntime.clear_all()
	var wanted: Dictionary = {
		"Celestial Guidance": "Travel",
		"Talk My Way Out": "Diplomacy",
		"Polemologist": "Tactics",
		"Historian": "History",
		"Omnimancer": "Magic",
		"Technologist": "Technology",
		"Literary Expert": "Literature",
	}
	for trait_name: String in wanted:
		var td: TraitData = _require(res, "knowledge row " + trait_name, trait_name)
		if td == null:
			continue
		var k_name: String = wanted[trait_name]
		var m := _merc("Kn_" + trait_name)
		TraitDSL.apply_dsl_to_merc(m, td.effect_dsl)
		TestFixtures.check(res, "%s grants the %s knowledge" % [trait_name, k_name], _has_knowledge(m, k_name),
			"knowledges %d, holds %s %s" % [m.knowledges.size(), k_name, str(_has_knowledge(m, k_name))])
	var cog_rows: Array[String] = ["Polemologist", "Historian", "Omnimancer", "Technologist", "Literary Expert"]
	for cog_name: String in cog_rows:
		var ctd: TraitData = _lib(cog_name)
		if ctd == null:
			continue
		var cm := _merc("Cog_" + cog_name)
		var before: int = int(cm.max_stats.get("max_cognition", 0))
		TraitDSL.apply_dsl_to_merc(cm, ctd.effect_dsl)
		TestFixtures.check(res, "%s raises max_cognition by 1" % cog_name,
			int(cm.max_stats.get("max_cognition", 0)) == before + 1,
			"max_cognition %d -> %d" % [before, int(cm.max_stats.get("max_cognition", 0))])


static func _case_fragile_cannon(res: Dictionary) -> void:
	var td: TraitData = _begin(res, "fragile cannon row", "Fragile Cannon")
	if td == null:
		return
	var plain := _merc("Fra0")
	var m := _applied("Fra", td.effect_dsl)
	TestFixtures.check(res, "fragile cannon lowers the computed maximum hit points",
		int(m.stats.get("maximum_hit_points", 0)) == int(plain.stats.get("maximum_hit_points", 0)) - 2,
		"maximum_hit_points %d vs base %d" % [int(m.stats.get("maximum_hit_points", 0)),
		int(plain.stats.get("maximum_hit_points", 0))])
	TestFixtures.check(res, "fragile cannon writes no max_stats key",
		not m.max_stats.has("maximum_hit_points") and m.max_stats.size() == plain.max_stats.size(),
		"max_stats %s" % str(m.max_stats))


static func _case_new_rows(res: Dictionary) -> void:
	TraitRuntime.clear_all()
	var new_rows: Array[String] = ["Undergrad Studies", "Grief Stricken", "Unrequited Heart"]
	for row_name: String in new_rows:
		TestFixtures.check(res, "new row %s is in the library" % row_name, _lib(row_name) != null,
			"DataManager.traits.has(%s) %s" % [row_name, str(DataManager.traits.has(row_name))])
	var und: TraitData = _lib("Undergrad Studies")
	if und != null:
		var m := _merc("Und")
		TraitDSL.apply_dsl_to_merc(m, und.effect_dsl)
		TestFixtures.check(res, "undergrad studies grants one random knowledge", m.knowledges.size() == 1,
			"knowledges %d" % m.knowledges.size())
	var drops: Dictionary = {"Grief Stricken": 3.0, "Unrequited Heart": 2.0}
	for row_name2: String in drops:
		var td: TraitData = _lib(row_name2)
		if td == null:
			continue
		var amount: float = drops[row_name2]
		var plain := _merc("Bsc_" + row_name2)
		var m2 := _applied("New_" + row_name2, td.effect_dsl)
		TestFixtures.check(res, "%s lowers base success chance by %d" % [row_name2, int(amount)],
			_near(_stat(m2, "base_success_chance"), _stat(plain, "base_success_chance") - amount),
			"base_success_chance %.2f vs base %.2f" % [_stat(m2, "base_success_chance"),
			_stat(plain, "base_success_chance")])


static func _case_buddy_clauses(res: Dictionary) -> void:
	var combo: TraitData = _begin(res, "companion combo row", "Companion Combo")
	var missing: TraitData = _require(res, "missing your pal row", "Missing Your Pal")
	if combo == null or missing == null:
		return
	var holder := _merc("Bud")
	var pal := _merc("Pal")
	var foe := _merc("Fbd")
	holder.merc_uid = 9101
	pal.merc_uid = 9102
	holder.buddy_uid = pal.merc_uid
	_give(holder, combo)
	var team_a: Array[MercenaryData] = [holder, pal]
	var team_b: Array[MercenaryData] = [foe]
	var st := _state(team_a, team_b)
	var base: float = _stat(holder, "base_success_chance")
	TraitRuntime.refresh_continuous(holder, st)
	TestFixtures.check(res, "companion combo raises base success chance with the buddy there",
		_near(_stat(holder, "base_success_chance"), base + 4.0),
		"base_success_chance %.2f -> %.2f" % [base, _stat(holder, "base_success_chance")])
	holder.buddy_uid = 9999
	TraitRuntime.refresh_continuous(holder, st)
	TestFixtures.check(res, "companion combo reverts with the buddy gone",
		_near(_stat(holder, "base_success_chance"), base),
		"base_success_chance back to %.2f, got %.2f" % [base, _stat(holder, "base_success_chance")])
	TraitRuntime.clear_all()
	var lone := _merc("Lon")
	var mate := _merc("Mat")
	var foe2 := _merc("Fln")
	lone.merc_uid = 9201
	mate.merc_uid = 9202
	lone.buddy_uid = 9999
	_give(lone, missing)
	var team_c: Array[MercenaryData] = [lone, mate]
	var team_d: Array[MercenaryData] = [foe2]
	var st2 := _state(team_c, team_d)
	var base2: float = _stat(lone, "base_success_chance")
	TraitRuntime.refresh_continuous(lone, st2)
	#Base success chance floors at 0, so a base under 7 lands on the floor rather than going negative.
	TestFixtures.check(res, "missing your pal lowers base success chance with the buddy gone",
		_near(_stat(lone, "base_success_chance"), maxf(0.0, base2 - 7.0)),
		"base_success_chance %.2f -> %.2f" % [base2, _stat(lone, "base_success_chance")])
	lone.buddy_uid = mate.merc_uid
	TraitRuntime.refresh_continuous(lone, st2)
	TestFixtures.check(res, "missing your pal reverts with the buddy there",
		_near(_stat(lone, "base_success_chance"), base2),
		"base_success_chance back to %.2f, got %.2f" % [base2, _stat(lone, "base_success_chance")])
	lone.buddy_uid = 0
	TraitRuntime.refresh_continuous(lone, st2)
	TestFixtures.check(res, "no buddy uid reads as absent",
		_near(_stat(lone, "base_success_chance"), maxf(0.0, base2 - 7.0)),
		"base_success_chance %.2f, the dangling uid gave %.2f"
		% [_stat(lone, "base_success_chance"), maxf(0.0, base2 - 7.0)])


static func _case_perk_groups(res: Dictionary) -> void:
	TraitRuntime.clear_all()
	var parsed: Array[String] = _parse_groups("Trick Shot, Melee")
	TestFixtures.check(res, "a perk group cell parses into normalized group words",
		parsed.size() == 2 and parsed[0] == "trick_shot" and parsed[1] == "melee",
		"'Trick Shot, Melee' reads as %s" % str(parsed))
	var melee: Array = DataManager.perk_group_library.get("melee", []) as Array
	TestFixtures.check(res, "the derived melee perk group holds members", melee.size() >= 2,
		"melee members %d, ranged members %d" % [melee.size(),
		(DataManager.perk_group_library.get("ranged", []) as Array).size()])
	if melee.size() >= 2:
		seed(SEED_GROUP)
		var m := _merc("Grp")
		var staff: WeaponData = _weapon(0, false)
		staff.weapon_type = "Staff"
		m.equipped_weapon = staff
		m.weapon_drawn = true
		TraitDSL.apply_dsl_to_merc(m, "grant:random:perk_group:melee:2")
		var names: Array[String] = []
		var derived: bool = true
		for td: TraitData in m.weapon_perks:
			names.append(td.trait_name)
			if td.trait_source != "Weapon" or not td.perk_groups.has("melee"):
				derived = false
		TestFixtures.check(res, "a melee group token grants two distinct weapon perks",
			names.size() == 2 and names[0] != names[1] and derived and m.perks.is_empty(),
			"weapon_perks %s, perks %d" % [str(names), m.perks.size()])
		var recorded: bool = m.group_perk_cells_applied.size() == names.size()
		for drawn_name: String in names:
			if not bool(m.group_perk_cells_applied.get(drawn_name, false)):
				recorded = false
		TestFixtures.check(res, "every drawn group perk records its cell as applied",
			recorded and names.size() == 2,
			"recorded %s" % str(m.group_perk_cells_applied.keys()))
	var u := _merc("Unk")
	TraitDSL.apply_dsl_to_merc(u, "grant:random:perk_group:no_such_group:1")
	TestFixtures.check(res, "an unknown perk group grants nothing",
		u.weapon_perks.is_empty() and u.armor_perks.is_empty() and u.perks.is_empty()
		and u.group_perk_cells_applied.is_empty(),
		"weapon perks %d, armor perks %d, perks %d, recorded %d" % [u.weapon_perks.size(),
		u.armor_perks.size(), u.perks.size(), u.group_perk_cells_applied.size()])


static func _case_group_perk_generation(res: Dictionary) -> void:
	TraitRuntime.clear_all()
	var member := TraitData.new()
	member.trait_name = "TEST Group Member"
	member.trait_type = "Perk"
	member.trait_source = "Merc"
	member.effect_dsl = "stat:max_cognition:+1"
	var groups: Array[String] = ["test_group"]
	member.perk_groups = groups
	var giver := TraitData.new()
	giver.trait_name = "TEST Group Giver"
	giver.trait_type = "Perk"
	giver.trait_source = "Merc"
	giver.effect_dsl = "grant:random:perk_group:test_group:1"
	DataManager.traits[giver.trait_name] = giver
	DataManager.traits[member.trait_name] = member
	DataManager.perk_group_library["test_group"] = [member]
	var lp := LifepathData.new()
	lp.perks = ["TEST Group Giver"] as Array[String]
	var lifepaths: Array[LifepathData] = [lp]
	var m := _merc("Gen")
	m.lifepaths = lifepaths
	var before: int = int(m.max_stats.get("max_cognition", 0))
	GenerationSteps.step6_traits(m)
	var after: int = int(m.max_stats.get("max_cognition", 0))
	TestFixtures.check(res, "a drawn group perk cell runs exactly once through generation",
		after == before + 1,
		"max_cognition %d -> %d, a second pass would read %d" % [before, after, before + 2])
	TestFixtures.check(res, "a Merc source group perk lands in perks and is recorded",
		TestFixtures.holds_trait(m, "TEST Group Member")
		and bool(m.group_perk_cells_applied.get("TEST Group Member", false)),
		"perks %d, recorded %s" % [m.perks.size(), str(m.group_perk_cells_applied.keys())])
	DataManager.traits.erase(giver.trait_name)
	DataManager.traits.erase(member.trait_name)
	DataManager.perk_group_library.erase("test_group")


static func _case_apply_duration(res: Dictionary) -> void:
	TraitRuntime.clear_all()
	var m := _merc("Tim")
	var foe := _merc("Tfo")
	var td := TraitData.new()
	td.trait_name = "TEST Timed Apply"
	td.trait_type = "Perk"
	td.effect_dsl = "on:targeted_melee:always:apply:slowed:1:round|on:miss_dealt:always:apply:mute"
	m.perks.append(td)
	var team_a: Array[MercenaryData] = [m]
	var team_b: Array[MercenaryData] = [foe]
	var st := _state(team_a, team_b)
	st.round_number = 1
	TraitRuntime.fire("targeted_melee", m, {"state": st})
	var timer: Dictionary = st.get_state_timer(m, ConstStates.SLOWED)
	TestFixtures.check(res, "apply with a round tail registers a timer",
		ConstStates.has_state(m, ConstStates.SLOWED) and int(timer.get("expires", 0)) == 1,
		"Slowed %s, timer %s on round 1" % [str(ConstStates.has_state(m, ConstStates.SLOWED)),
		str(timer)])
	TraitRuntime.fire("miss_dealt", m, {"state": st})
	TestFixtures.check(res, "apply without a tail stays untimed",
		ConstStates.has_state(m, ConstStates.MUTE)
		and st.get_state_timer(m, ConstStates.MUTE).is_empty(),
		"Mute %s, timer %s" % [str(ConstStates.has_state(m, ConstStates.MUTE)),
		str(st.get_state_timer(m, ConstStates.MUTE))])


static func _case_compound_condition(res: Dictionary) -> void:
	TraitRuntime.clear_all()
	var m := _merc("Cmp")
	var foe := _merc("Cfo")
	_hp(m, 30)
	var td := TraitData.new()
	td.trait_name = "TEST Compound Toll"
	td.trait_type = "Perk"
	td.effect_dsl = "on:targeted_melee:first_round+unarmed:resource:hp:-1"
	m.perks.append(td)
	var team_a: Array[MercenaryData] = [m]
	var team_b: Array[MercenaryData] = [foe]
	var st := _state(team_a, team_b)
	st.round_number = 1
	m.equipped_weapon = null
	var before: int = m.current_hp
	TraitRuntime.fire("targeted_melee", m, {"state": st})
	TestFixtures.check(res, "a compound condition fires when every part passes",
		m.current_hp == before - 1, "hp %d -> %d unarmed on round 1" % [before, m.current_hp])
	m.equipped_weapon = _weapon(0, false)
	before = m.current_hp
	TraitRuntime.fire("targeted_melee", m, {"state": st})
	TestFixtures.check(res, "a compound condition blocks when the weapon part fails",
		m.current_hp == before, "hp %d -> %d armed on round 1" % [before, m.current_hp])
	m.equipped_weapon = null
	st.round_number = 2
	before = m.current_hp
	TraitRuntime.fire("targeted_melee", m, {"state": st})
	TestFixtures.check(res, "a compound condition blocks when the round part fails",
		m.current_hp == before, "hp %d -> %d unarmed on round 2" % [before, m.current_hp])


static func _case_bond_scope(res: Dictionary) -> void:
	TraitRuntime.clear_all()
	var m := _merc("Bnd")
	m.merc_uid = 9301
	m.beau_uid = 9302
	var td := TraitData.new()
	td.trait_name = "TEST Bond Toll"
	td.trait_type = "Perk"
	td.effect_dsl = "on:beau_apart:beau_absent:lasting:bond:stat:max_hp:-1"
	m.perks.append(td)
	var base: int = int(_stat(m, "maximum_hit_points"))
	TraitRuntime.fire("beau_apart", m, {})
	TraitRuntime.fire("beau_apart", m, {})
	TestFixtures.check(res, "a bond scoped max hp loss lands once per fire",
		int(_stat(m, "maximum_hit_points")) == base - 2,
		"maximum_hit_points %d -> %d over two blocks" % [base, int(_stat(m, "maximum_hit_points"))])
	TestFixtures.check(res, "current hp follows the lowered maximum",
		m.current_hp == base - 2, "hp %d, maximum %d" % [m.current_hp, base - 2])
	TraitRuntime.revert_scope(m, TraitRuntime.SCOPE_BOND)
	TestFixtures.check(res, "revert_scope bond restores every block at once",
		int(_stat(m, "maximum_hit_points")) == base,
		"maximum_hit_points back to %d (base %d)" % [int(_stat(m, "maximum_hit_points")), base])


static func _case_rest_beau_scopes(res: Dictionary) -> void:
	TraitRuntime.clear_all()
	var m := _merc("Scp")
	var foe := _merc("Sfo")
	var td := TraitData.new()
	td.trait_name = "TEST Lasting Gifts"
	td.trait_type = "Perk"
	td.effect_dsl = "on:rest_complete:always:stat:accuracy:+5|on:beau_seen:always:stat:avoid:+5"
	m.perks.append(td)
	var team_a: Array[MercenaryData] = [m]
	var team_b: Array[MercenaryData] = [foe]
	var st := _state(team_a, team_b)
	var acc: float = _stat(m, "accuracy")
	var avo: float = _stat(m, "avoid")
	TraitRuntime.fire("rest_complete", m, {})
	TraitRuntime.fire("beau_seen", m, {})
	TestFixtures.check(res, "rest and beau clauses apply their stat deltas",
		_near(_stat(m, "accuracy"), acc + 5.0) and _near(_stat(m, "avoid"), avo + 5.0),
		"accuracy %.2f, avoid %.2f" % [_stat(m, "accuracy"), _stat(m, "avoid")])
	TraitRuntime.end_encounter(st)
	TestFixtures.check(res, "rest_complete and beau_seen default to the permanent scope",
		_near(_stat(m, "accuracy"), acc + 5.0) and _near(_stat(m, "avoid"), avo + 5.0),
		"accuracy %.2f, avoid %.2f after end_encounter" % [_stat(m, "accuracy"), _stat(m, "avoid")])


#A rest clause inflicts with no BattleState, so the Inflict Default duration becomes a campaign timer.
static func _case_inflict_outside(res: Dictionary) -> void:
	TraitRuntime.clear_all()
	CampaignClock.reset()
	CampaignClock.advance(50)
	var m := _merc("Inf")
	var td := TraitData.new()
	td.trait_name = "TEST Wet Rest"
	td.trait_type = "Perk"
	td.effect_dsl = "on:rest_complete:always:inflict:inhibited"
	m.perks.append(td)
	seed(SEED_INFLICT)
	var last: Array[String] = []
	for _i: int in range(REPS):
		var lines: Array[String] = []
		TraitRuntime.fire("rest_complete", m, {"kind": "breather", "run": null, "lines": lines})
		last = lines
		if ConstStates.has_state(m, ConstStates.INHIBITED):
			break
	var named: bool = false
	var failed: bool = false
	for line: String in last:
		if line.contains(ConstStates.INHIBITED):
			named = true
		if line.contains("fails to resist " + ConstStates.INHIBITED):
			failed = true
	var held: bool = ConstStates.has_state(m, ConstStates.INHIBITED)
	var expiry: int = int(m.campaign_states.get(ConstStates.INHIBITED, 0))
	TestFixtures.check(res, "inflict outside a battle writes its lines",
		not last.is_empty() and named,
		"%d lines, first '%s'" % [last.size(), last[0] if not last.is_empty() else "none"])
	TestFixtures.check(res, "inflict outside a battle lands the state", held and failed,
		"held %s, resist line %s" % [str(held), str(failed)])
	TestFixtures.check(res, "the landed state carries a campaign timer",
		expiry == CampaignClock.now() + 1,
		"expiry %d, now %d" % [expiry, CampaignClock.now()])


#A granted item lands as an ItemData resource, so the salary rarity total can read its rarity.
static func _case_item_grant(res: Dictionary) -> void:
	var m := _merc("Grant")
	if DataManager.items.is_empty():
		TestFixtures.check(res, "Items.tsv carries rows for the item grant token", false,
			"DataManager.items is empty, the grant check cannot run")
		return
	var before_items: int = m.items.size()
	var before_gear: int = SalarySystem.carried_gear(m).size()
	var before_rarity: int = SalarySystem.rarity_score(m)
	TraitDSL.apply_dsl_to_merc(m, "grant:random:item:rarity:common,uncommon:1")
	var granted: Array = m.items.slice(before_items)
	var typed: bool = granted.size() == 1
	var want: int = before_rarity
	for entry: Variant in granted:
		if entry is ItemData and (entry as ItemData).item_name != "":
			want += RarityRank.rank((entry as ItemData).item_rarity)
		else:
			typed = false
	TestFixtures.check(res, "a granted item is an ItemData with a name", typed,
		"granted %d of 1, items %d" % [granted.size(), m.items.size()])
	var after_gear: int = SalarySystem.carried_gear(m).size()
	var after_rarity: int = SalarySystem.rarity_score(m)
	TestFixtures.check(res, "the salary rarity total counts the granted item",
		after_gear == before_gear + 1 and after_rarity == want,
		"gear %d to %d, rarity %d to %d, wanted %d" % [before_gear, after_gear,
		before_rarity, after_rarity, want])
