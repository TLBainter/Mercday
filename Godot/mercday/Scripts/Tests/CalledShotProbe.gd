class_name CalledShotProbe

#Called Shot decision probe: what the AI picks at set levels and whether the pick beat a plain attack.
#Run: godot --headless --path . -- --calledshot-probe --probe-levels=1,9,19,29,40 --probe-n=1000 --probe-trials=64

const DEFAULT_LEVELS: Array[int] = [1, 9, 19, 29, 40]
const TIE_BAND := 0.15
const SAMPLE_HEAD := 5
const SAMPLE_CALLED := 20

static var _template_keys: Array[String] = []


#Per-level tallies; picks, missed and wrong_option count by option name, calib sums by option.
class Acc:
	var picks: Dictionary = {}
	var missed: Dictionary = {}
	var wrong_option: Dictionary = {}
	var decisions := 0
	var right_total := 0
	var called_total := 0
	var called_right := 0
	var plain_total := 0
	var plain_right := 0
	var wrong_called := 0
	var should_have_attacked := 0
	var heuristic_agree := 0
	var called_samples := 0
	var calib: Dictionary = {}
	var sum_plain_mean := 0.0
	var sum_called_mean := 0.0
	var sum_called_land := 0.0
	var sum_gain := 0.0
	var sum_dmg_cost := 0.0
	var flyers := 0
	var armed := 0
	var ranged_mercs := 0
	var no_option := 0
	var unaffordable := 0
	var templates_failed := 0
	var ammo_topped := 0


static func run() -> bool:
	var levels := BattleHarness.probe_levels(DEFAULT_LEVELS)
	var n := maxi(1, BattleHarness.arg_int("--probe-n", 1000))
	var trials := maxi(1, BattleHarness.arg_int("--probe-trials", 64))
	seed(BattleHarness.arg_int("--probe-seed", 4242))
	var saved_level := MercGenerator.forced_level
	var saved_every := CalledShotSystem.force_every
	var saved_option := CalledShotSystem.force_option
	var saved_banking := CriticalSuccessSystem.banking
	CalledShotSystem.force_every = false
	CalledShotSystem.force_option = ""
	#A rolled critical would hand the merc a real reward mid probe; banking parks it instead.
	CriticalSuccessSystem.banking = true
	var idle: Array[int] = []
	for level: int in levels:
		if _run_level(level, n, trials) == 0:
			idle.append(level)
	MercGenerator.forced_level = saved_level
	CalledShotSystem.force_every = saved_every
	CalledShotSystem.force_option = saved_option
	CriticalSuccessSystem.banking = saved_banking
	var res := {"pass": 0, "fail": 0}
	TestFixtures.check(res, "the probe ran every requested level", idle.is_empty(),
		"%d levels, no decision at %s" % [levels.size(), str(idle)])
	return TestFixtures.summarize(res, "CALLEDSHOT PROBE")


#Runs n decisions at this level, prints its report and returns how many decisions were measured.
static func _run_level(level: int, n: int, trials: int) -> int:
	var t0 := Time.get_ticks_msec()
	var acc := Acc.new()
	for i: int in range(n):
		_run_decision(level, i, trials, acc)
	_print_level(level, n, acc, Time.get_ticks_msec() - t0)
	return acc.decisions


static func _run_decision(level: int, index: int, trials: int, acc: Acc) -> void:
	TestFixtures.reset_generator_rolls()
	MercGenerator.forced_level = level
	var merc := MercGenerator.generate(index)
	MercGenerator.forced_level = -1
	var enemy := _enemy(level, index, merc, acc)
	if enemy == null:
		return
	var state := _field(merc, enemy, acc)
	acc.decisions += 1
	if PathTargeter.is_flying(enemy):
		acc.flyers += 1
	if CalledShotSystem.is_valid(merc, enemy, "wrist", state):
		acc.armed += 1
	if merc.equipped_weapon != null and merc.equipped_weapon.is_ranged:
		acc.ranged_mercs += 1
	var reduction := int(merc.active_states.get("attack_ap_reduction", 0))
	var cost := maxi(0, state.get_cost(merc, "CalledShot", AutoBattle.ATTACK_BASE_AP) - reduction)
	if not state.can_afford(merc, cost):
		acc.unaffordable += 1
	var decision := {"type": "attack", "action_name": "Attack", "target": enemy}
	var pick := str(CalledShotOdds.upgrade(merc, decision, state, 0).get("called_shot", ""))
	var cands := _candidates(merc, enemy, state)
	if cands.size() == 1:
		acc.no_option += 1
	var worth: Dictionary = {}
	var means: Dictionary = {}
	var lands: Dictionary = {}
	var crits: Dictionary = {}
	for key: String in cands:
		var m := _measure(merc, enemy, state, key, trials)
		means[key] = float(m["mean"])
		lands[key] = float(m["land"])
		crits[key] = float(m["crit"])
		worth[key] = float(m["mean"]) \
			+ float(m["land"]) * CalledShotOdds.effect_value(merc, enemy, key, state)
	var ctx := CalledShotOdds.marked_context(merc, enemy, state, 0)
	for key: String in cands:
		var est := CalledShotOdds.expected_marked(ctx, CalledShotSystem.value(key))
		_calibrate(acc, _name(key), float(est["damage"]), float(means[key]), float(est["land"]),
			float(lands[key]), float(ctx["crit"]), float(crits[key]))
	var best := _best(cands, worth)
	if CalledShotOdds.choose(merc, enemy, state, 0) == best:
		acc.heuristic_agree += 1
	_record(acc, pick, best, worth, means, lands)
	_sample(level, index, merc, enemy, [pick, best], worth, acc)


#One opponent at the merc's own level: mercs on an even index, an NPCs.tsv template on an odd one.
static func _enemy(level: int, index: int, merc: MercenaryData, acc: Acc) -> MercenaryData:
	var party: Array[MercenaryData] = [merc]
	var req := OpponentRequest.new()
	req.count = 1
	req.fixed_level = level
	req.party = party
	req.tag = "called_shot_probe"
	req.source = "Mercs" if index % 2 == 0 else _template_key()
	var out := OpponentGenerator.generate(req)
	if out.is_empty():
		acc.templates_failed += 1
		req.source = "Mercs"
		out = OpponentGenerator.generate(req)
	if out.is_empty():
		return null
	return out[0]


static func _template_key() -> String:
	if _template_keys.is_empty():
		for key: String in DataManager.npc_templates:
			_template_keys.append(key)
		_template_keys.sort()
	if _template_keys.is_empty():
		return "Mercs"
	return _template_keys[randi_range(0, _template_keys.size() - 1)]


#A flat field with the enemy in reach of whatever the merc drew.
static func _field(merc: MercenaryData, enemy: MercenaryData, acc: Acc) -> BattleState:
	var team_a: Array[MercenaryData] = [merc]
	var team_b: Array[MercenaryData] = [enemy]
	var state := BattleState.create(team_a, team_b, null)
	state.battlefield = TestFixtures.exterior_field()
	TestFixtures.place(state, merc, Vector2i(4, 4))
	TestFixtures.place(state, enemy, Vector2i(4 + _reach(merc), 4))
	#create() zeroes AP; the decision is measured with the merc's full turn, as AutoBattle sees it.
	state.start_of_turn(merc)
	merc.weapon_drawn = merc.equipped_weapon != null
	enemy.weapon_drawn = enemy.equipped_weapon != null
	var weapon: WeaponData = merc.equipped_weapon
	if weapon != null and weapon.is_ranged and merc.ammo_loaded == 0:
		merc.ammo_loaded = maxi(1, weapon.chamber)
		acc.ammo_topped += 1
	return state


static func _reach(merc: MercenaryData) -> int:
	var weapon: WeaponData = merc.equipped_weapon
	if weapon == null:
		return 1
	if weapon.is_ranged:
		return 3
	return 2 if weapon.is_throwable else 1


static func _candidates(merc: MercenaryData, enemy: MercenaryData, state: BattleState) -> Array[String]:
	var out: Array[String] = [""]
	for key: String in CalledShotSystem.AI_OPTIONS:
		if CalledShotSystem.is_valid(merc, enemy, key, state):
			out.append(key)
	return out


#Rolls the real attack and the real defence `trials` times; every field either side writes is put back.
static func _measure(merc: MercenaryData, enemy: MercenaryData, state: BattleState, key: String,
		trials: int) -> Dictionary:
	var penalty := CalledShotSystem.value(key)
	var flaws := WeaponArmorPerkLibrary.defense_flaws_against(merc, enemy)
	var total := 0.0
	var landed := 0
	var crits := 0
	for _t: int in range(trials):
		var snap := _snapshot(merc, enemy)
		var atk := AttackSystem.execute_attack(merc, 0, 0, enemy, false, state, false, penalty)
		var dmg := 0
		if not bool(atk.get("misfired", false)) and not bool(atk.get("no_los", false)) \
				and not bool(atk.get("no_ammo", false)):
			dmg = int(atk["damage"])
		var final := 0
		var floor_only := false
		if dmg > 0:
			var scratch: Array[String] = []
			var res := CombatApplicator._resolve_defence(merc, enemy, dmg, str(atk["damage_type"]),
				state, 0, scratch, flaws)
			final = int(res.get("final_damage", 0))
			floor_only = bool(res.get("min_1_only", false))
		var crit := bool(atk.get("critical", false))
		if crit:
			crits += 1
		var core_left := penalty <= 0 or int(atk.get("core_successes", 0)) >= 1
		if crit or (final >= 1 and not floor_only and core_left):
			landed += 1
		total += float(final)
		_restore(merc, enemy, snap)
	var runs := float(trials)
	return {"mean": total / runs, "land": float(landed) / runs, "crit": float(crits) / runs}


static func _snapshot(merc: MercenaryData, enemy: MercenaryData) -> Dictionary:
	var weapon: WeaponData = merc.equipped_weapon
	return {
		"hp": enemy.current_hp, "ehp": enemy.excess_hp, "ep": enemy.current_ep,
		"eep": enemy.excess_ep, "eap": enemy.excess_ap,
		"ammo": merc.ammo_loaded, "inv": merc.ammo_inventory.duplicate(),
		"misfired": merc.weapon_misfired, "frag": weapon.current_fragility if weapon != null else 0,
		"m_ep": merc.current_ep, "m_eep": merc.excess_ep,
	}


static func _restore(merc: MercenaryData, enemy: MercenaryData, snap: Dictionary) -> void:
	enemy.current_hp = int(snap["hp"])
	enemy.excess_hp = int(snap["ehp"])
	enemy.current_ep = int(snap["ep"])
	enemy.excess_ep = int(snap["eep"])
	enemy.excess_ap = int(snap["eap"])
	merc.ammo_loaded = int(snap["ammo"])
	merc.ammo_inventory = snap["inv"] as Dictionary
	merc.weapon_misfired = bool(snap["misfired"])
	merc.current_ep = int(snap["m_ep"])
	merc.excess_ep = int(snap["m_eep"])
	if merc.equipped_weapon != null:
		merc.equipped_weapon.current_fragility = int(snap["frag"])
	merc.pending_crit_rewards.clear()
	enemy.pending_crit_rewards.clear()


static func _best(cands: Array[String], worth: Dictionary) -> String:
	var best := ""
	var best_worth := float(worth[""])
	for key: String in cands:
		if key != "" and float(worth[key]) > best_worth:
			best = key
			best_worth = float(worth[key])
	return best


static func _calibrate(acc: Acc, name: String, est_dmg: float, meas_dmg: float, est_land: float,
		meas_land: float, est_crit: float, meas_crit: float) -> void:
	var calib: Dictionary = acc.calib
	if not calib.has(name):
		calib[name] = {"n": 0, "est_dmg": 0.0, "meas_dmg": 0.0, "est_land": 0.0, "meas_land": 0.0,
			"est_crit": 0.0, "meas_crit": 0.0}
	var row: Dictionary = calib[name]
	row["n"] = int(row["n"]) + 1
	for pair: Array in [["est_dmg", est_dmg], ["meas_dmg", meas_dmg], ["est_land", est_land],
			["meas_land", meas_land], ["est_crit", est_crit], ["meas_crit", meas_crit]]:
		row[pair[0]] = float(row[pair[0]]) + float(pair[1])


static func _record(acc: Acc, pick: String, best: String, worth: Dictionary,
		means: Dictionary, lands: Dictionary) -> void:
	_bump(acc.picks, _name(pick))
	acc.sum_plain_mean += float(means[""])
	var w_pick := float(worth.get(pick, worth[""]))
	var right := pick == best or absf(w_pick - float(worth[best])) <= TIE_BAND
	if right:
		acc.right_total += 1
	if pick == "":
		acc.plain_total += 1
		if right:
			acc.plain_right += 1
		elif best != "":
			_bump(acc.missed, best)
		return
	acc.called_total += 1
	acc.sum_called_mean += float(means.get(pick, 0.0))
	acc.sum_called_land += float(lands.get(pick, 0.0))
	acc.sum_gain += w_pick - float(worth[""])
	acc.sum_dmg_cost += float(means[""]) - float(means.get(pick, 0.0))
	if right:
		acc.called_right += 1
		return
	acc.wrong_called += 1
	if best == "":
		acc.should_have_attacked += 1
	else:
		_bump(acc.wrong_option, pick + ">" + best)


#The first few decisions of a level and its called ones, so the reader can eyeball the maths.
static func _sample(level: int, index: int, merc: MercenaryData, enemy: MercenaryData,
		keys: Array, worth: Dictionary, acc: Acc) -> void:
	var pick := str(keys[0])
	var called := pick != ""
	var wanted := index < SAMPLE_HEAD or (called and int(acc.called_samples) < SAMPLE_CALLED)
	if not wanted:
		return
	if called:
		acc.called_samples += 1
	var weapon: WeaponData = merc.equipped_weapon
	print("PROBE SAMPLE %d: %d %s vs %s lvl %d pick=%s best=%s worth_plain=%.2f worth_pick=%.2f worth_best=%.2f" % [
		level, int(merc.stats.get("level", 0)),
		weapon.item_name if weapon != null else "unarmed",
		enemy.merc_name, int(enemy.stats.get("level", 0)),
		_name(pick), _name(str(keys[1])),
		float(worth[""]), float(worth.get(pick, worth[""])), float(worth[str(keys[1])])])


static func _print_level(level: int, n: int, acc: Acc, ms: int) -> void:
	var picks: Dictionary = acc.picks
	var parts: Array[String] = ["n=%d" % n, "plain=%d" % int(picks.get("plain", 0))]
	for key: String in CalledShotSystem.OPTIONS:
		parts.append("%s=%d" % [key, int(picks.get(key, 0))])
	print("PROBE LEVEL %d: %s" % [level, " ".join(parts)])
	print("PROBE LEVEL %d RIGHT: total=%d called=%d/%d plain=%d/%d wrong_called=%d should_have_attacked=%d heuristic_agree=%d" % [
		level, int(acc.right_total), int(acc.called_right), int(acc.called_total),
		int(acc.plain_right), int(acc.plain_total), int(acc.wrong_called),
		int(acc.should_have_attacked), int(acc.heuristic_agree)])
	print("PROBE LEVEL %d MISSED: %s" % [level, _counts_text(acc.missed)])
	print("PROBE LEVEL %d WRONG_OPTION: %s" % [level, _counts_text(acc.wrong_option)])
	var called := float(maxi(1, int(acc.called_total)))
	var decisions := float(maxi(1, int(acc.decisions)))
	print("PROBE LEVEL %d DAMAGE: plain_mean=%.2f called_mean=%.2f called_land=%.3f gain_mean=%.2f dmg_cost_mean=%.2f" % [
		level, float(acc.sum_plain_mean) / decisions, float(acc.sum_called_mean) / called,
		float(acc.sum_called_land) / called, float(acc.sum_gain) / called,
		float(acc.sum_dmg_cost) / called])
	var calib: Dictionary = acc.calib
	var order: Array[String] = ["plain"]
	for key: String in CalledShotSystem.OPTIONS:
		order.append(key)
	var calib_parts: Array[String] = []
	for key: String in order:
		if not calib.has(key):
			continue
		var row: Dictionary = calib[key]
		var rows := float(maxi(1, int(row["n"])))
		calib_parts.append("%s=%d:%.2f/%.2f:%.3f/%.3f" % [key, int(row["n"]),
			float(row["est_dmg"]) / rows, float(row["meas_dmg"]) / rows,
			float(row["est_land"]) / rows, float(row["meas_land"]) / rows])
	print("PROBE LEVEL %d CALIB: %s" % [level, " ".join(calib_parts)])
	var plain_row: Dictionary = calib.get("plain", {})
	var plain_rows := float(maxi(1, int(plain_row.get("n", 0))))
	print("PROBE LEVEL %d CRIT: est=%.4f meas=%.4f" % [level,
		float(plain_row.get("est_crit", 0.0)) / plain_rows,
		float(plain_row.get("meas_crit", 0.0)) / plain_rows])
	print("PROBE LEVEL %d CONTEXT: flyers=%d armed=%d ranged_mercs=%d no_option=%d unaffordable=%d templates_failed=%d ammo_topped=%d" % [
		level, int(acc.flyers), int(acc.armed), int(acc.ranged_mercs), int(acc.no_option),
		int(acc.unaffordable), int(acc.templates_failed), int(acc.ammo_topped)])
	print("PROBE LEVEL %d MS: %d" % [level, ms])


static func _counts_text(counts: Dictionary) -> String:
	if counts.is_empty():
		return "none"
	var keys: Array[String] = []
	for key: String in counts:
		keys.append(key)
	keys.sort_custom(func(a: String, b: String) -> bool: return int(counts[a]) > int(counts[b]))
	var parts: Array[String] = []
	for key: String in keys:
		parts.append("%s=%d" % [key, int(counts[key])])
	return " ".join(parts)


static func _name(key: String) -> String:
	return "plain" if key == "" else key


static func _bump(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1
