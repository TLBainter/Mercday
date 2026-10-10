class_name HarnessRoster
extends RefCounted

#Builds the harness roster and its teams and resets their campaign state.

const ROSTER_LEVEL_MIN := 5
const ROSTER_LEVEL_MAX := 9


#Roster mercs start at a random level 5 to 9; enemy teams built elsewhere keep their own levels.
static func roster_merc(index: int) -> MercenaryData:
	MercGenerator.forced_level = randi_range(ROSTER_LEVEL_MIN, ROSTER_LEVEL_MAX)
	var merc := MercGenerator.generate(index)
	MercGenerator.forced_level = -1
	return merc


#The first half of the generated mercs (by index) carry the passive immunity token of the auto-immune name.
static func grant_auto_immunity(merc: MercenaryData, index: int, total: int) -> void:
	var name := HarnessFlags.auto_immune_name()
	if name == "" or index >= (total >> 1):
		return
	var token := _immune_token(name)
	if not merc.passive_effects.has(token):
		merc.passive_effects.append(token)


static func _is_flyer(merc: MercenaryData) -> bool:
	return int(merc.stats.get("fly", 0)) > 0


#The off hand is checked too: BattleState.create packs it away only after the split is chosen.
static func _has_firearm(merc: MercenaryData) -> bool:
	if merc.equipped_weapon != null and merc.equipped_weapon.weapon_type.contains("Firearm"):
		return true
	if merc.offhand_weapon != null and merc.offhand_weapon.weapon_type.contains("Firearm"):
		return true
	for entry: Dictionary in merc.inventory:
		if entry.get("type") != "weapon":
			continue
		var w: WeaponData = entry.get("data") as WeaponData
		if w != null and w.weapon_type.contains("Firearm"):
			return true
	return false


static func _count_where(pool: Array[MercenaryData], test: Callable) -> int:
	var n := 0
	for m: MercenaryData in pool:
		if test.call(m):
			n += 1
	return n


static func team_mixed(team: Array[MercenaryData]) -> bool:
	return _count_where(team, _is_flyer) > 0 and _count_where(team, _has_firearm) > 0


#"--auto-team-mix": generates mercs until n are kept with at least two flyers and two firearm holders.
static func generate_mixed_mercs(mercs: Array[MercenaryData], n: int) -> void:
	var tries := 0
	while mercs.size() < n and tries < 5000:
		tries += 1
		var merc := roster_merc(mercs.size())
		var flyers := _count_where(mercs, _is_flyer)
		var guns := _count_where(mercs, _has_firearm)
		var need := maxi(0, 2 - flyers) + maxi(0, 2 - guns)
		var helps := (_is_flyer(merc) and flyers < 2) or (_has_firearm(merc) and guns < 2)
		if not helps and n - mercs.size() <= need:
			continue
		mercs.append(merc)
		grant_auto_immunity(merc, mercs.size() - 1, n)
		MercSheetPrinter.print_merc(merc)
	print("AUTO MIX: %d mercs kept from %d generated, flyers=%d firearms=%d" % [
		mercs.size(), tries, _count_where(mercs, _is_flyer), _count_where(mercs, _has_firearm)])


#Shuffles until each half holds a flyer and a firearm; false when no such split turned up.
static func shuffle_mixed_teams(mercs: Array[MercenaryData]) -> bool:
	var mid: int = mercs.size() >> 1
	for _try: int in range(2000):
		mercs.shuffle()
		var a: Array[MercenaryData] = []
		var b: Array[MercenaryData] = []
		a.assign(mercs.slice(0, mid))
		b.assign(mercs.slice(mid))
		if team_mixed(a) and team_mixed(b):
			return true
	return false


#Every combination of pick indexes drawn from 0 to n_rest - 1, in lexicographic order.
static func _halvings(n_rest: int, pick: int) -> Array:
	var out: Array = []
	if pick <= 0:
		out.append([])
		return out
	if pick > n_rest:
		return out
	for first: int in range(n_rest - pick + 1):
		for rest: Array in _halvings(n_rest - first - 1, pick - 1):
			var combo: Array = [first]
			for at: int in rest:
				combo.append(first + 1 + at)
			out.append(combo)
	return out


#Halves the roster: "plain" cuts it in two, any other mode rotates which mercs share the first team by index.
static func split_teams(mercs: Array[MercenaryData], mode: String, index: int) -> Array:
	var mid: int = mercs.size() >> 1
	var a: Array[MercenaryData] = []
	var b: Array[MercenaryData] = []
	if mode == "plain" or mercs.size() < 4 or mercs.size() % 2 != 0:
		a.assign(mercs.slice(0, mid))
		b.assign(mercs.slice(mid))
		return [a, b]
	var ordered: Array[MercenaryData] = []
	ordered.assign(mercs)
	ordered.sort_custom(func(x: MercenaryData, y: MercenaryData) -> bool:
		if x.merc_name == y.merc_name:
			return x.merc_uid < y.merc_uid
		return x.merc_name < y.merc_name)
	var combos: Array = _halvings(mercs.size() - 1, mid - 1)
	var picked: Array = combos[index % combos.size()] as Array
	#The first sorted merc anchors team a so every halving of a roster is a distinct pairing.
	var in_a: Dictionary = {ordered[0]: true}
	for at: int in picked:
		in_a[ordered[at + 1]] = true
	for m: MercenaryData in mercs:
		if in_a.has(m):
			a.append(m)
		else:
			b.append(m)
	return [a, b]


#"--force-unsavory=60,75" gives the first roster mercs those Unsavory values in order; empty when absent.
static func unsavory_values() -> Array[float]:
	var values: Array[float] = []
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--force-unsavory="):
			continue
		for raw: String in arg.substr("--force-unsavory=".length()).split(","):
			var term: String = raw.strip_edges()
			if term.is_valid_float():
				values.append(float(term))
			else:
				print("FORCE UNSAVORY: ignored '%s'" % term)
	return values


static func force_unsavory(mercs: Array[MercenaryData]) -> void:
	var values: Array[float] = unsavory_values()
	for i: int in range(mini(values.size(), mercs.size())):
		var merc: MercenaryData = mercs[i]
		if merc == null:
			continue
		var current: float = float(merc.stats.get("unsavory", 0.0))
		StatCalculator.add_flat(merc, "unsavory", values[i] - current)
		StatCalculator.refresh(merc)
		print("FORCE UNSAVORY: %s %.1f" % [merc.merc_name, float(merc.stats.get("unsavory", 0.0))])


#Batch statistics stay comparable when every contract starts whole; excess pools are left alone.
static func harness_restore(team: Array[MercenaryData]) -> void:
	var names: Array[String] = []
	for merc: MercenaryData in team:
		if merc == null:
			continue
		BattleState.restore_pools(merc)
		for state_name: String in StateCampaign.campaign_state_names():
			_hard_clear_state(merc, state_name)
		merc.campaign_states.clear()
		merc.rest_lockout_until = 0
		merc.rest_lockout_start = -1
		merc.rest_lockout_kind = ""
		names.append(merc.merc_name)
	if not names.is_empty():
		print("HARNESS RESTORE: %s" % ", ".join(names))


#A state kept alive by an applying root survives remove_state, so the harness drops it outright.
static func _hard_clear_state(merc: MercenaryData, state_name: String) -> void:
	if not ConstStates.has_state(merc, state_name):
		return
	StateCascade.remove_state(merc, state_name)
	merc.active_states.erase(state_name)
	var record: Variant = merc.active_states.get(ConstStates.APPLIED_BY_KEY)
	if record is Dictionary:
		(record as Dictionary).erase(state_name)


#"AUTO IMMUNE: <token> <names>" lists the mercs carrying the auto-immune token this encounter.
static func log_auto_immune() -> void:
	var name := HarnessFlags.auto_immune_name()
	if name == "" or not EncounterLogger.is_active():
		return
	var token := _immune_token(name)
	var names: Array[String] = []
	for merc: MercenaryData in _battle_mercs():
		if merc.passive_effects.has(token):
			names.append(merc.merc_name)
	EncounterLogger.log_verbose("AUTO IMMUNE: %s %s" % [token, ",".join(names)])


#"--auto-state=Name": every merc rolls to resist Name from a random living enemy before round 1.
static func inflict_auto_state() -> void:
	var name := HarnessFlags.auto_state_name()
	if name == "":
		return
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("STATE TEST: %s" % name)
	var remove_spec := "Resist:Vigor:2:Interact" if name == ConstStates.BURNING else "Resist:Vigor:2:End Turn"
	var inflict_spec := "Resist:Vigor:2"
	var remove_flag := HarnessFlags.auto_spec("--auto-remove")
	if remove_flag != "":
		remove_spec = remove_flag
	var inflict_flag := HarnessFlags.auto_spec("--auto-inflict")
	if inflict_flag != "":
		inflict_spec = inflict_flag
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("STATE TEST SPECS: inflict=%s remove=%s" % [inflict_spec, remove_spec])
	var immune_names: Array[String] = []
	for im_merc: MercenaryData in _battle_mercs():
		if ConstStates.is_immune(im_merc, name):
			immune_names.append(im_merc.merc_name)
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("STATE TEST IMMUNE: %s" % ",".join(immune_names))
	for merc: MercenaryData in _battle_mercs():
		var foes := BattleHarness.battle_state.get_enemies(merc)
		if foes.is_empty():
			continue
		var source: MercenaryData = foes[randi() % foes.size()]
		var lines := StateInfliction.inflict(
			merc, name, inflict_spec, "1 Minute", remove_spec, source, BattleHarness.battle_state)
		for line: String in lines:
			EncounterLogger.log_line(line)
		if BattleHarness.battle_line_fn.is_valid() and not lines.is_empty():
			BattleHarness.battle_line_fn.call("\n".join(lines))
	EncounterLogger.flush()


static func _immune_token(name: String) -> String:
	return "immune:" + StateTokens.normalize_token(name)


#Team A then team B of the running harness battle.
static func _battle_mercs() -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	out.append_array(BattleHarness.battle_team_a)
	out.append_array(BattleHarness.battle_team_b)
	return out
