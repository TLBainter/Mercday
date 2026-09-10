class_name BattleHarness
extends RefCounted

#Builds the harness roster and drives autobattles and test contracts for MercTest.

const ROSTER_LEVEL_MIN := 5
const ROSTER_LEVEL_MAX := 9

static var team_mix: bool = false

static var _battle_state: BattleState = null
static var _battle_line_fn: Callable
static var _battle_team_a: Array[MercenaryData] = []
static var _battle_team_b: Array[MercenaryData] = []
static var _contract_running: bool = false


#Roster mercs start at a random level 5 to 9; enemy teams built elsewhere keep their own levels.
static func roster_merc(index: int) -> MercenaryData:
	MercGenerator.forced_level = randi_range(ROSTER_LEVEL_MIN, ROSTER_LEVEL_MAX)
	var merc := MercGenerator.generate(index)
	MercGenerator.forced_level = -1
	return merc


#The first half of the generated mercs (by index) carry the passive immunity token of the auto-immune name.
static func grant_auto_immunity(merc: MercenaryData, index: int, total: int) -> void:
	var name := _auto_immune_name()
	if name == "" or index >= (total >> 1):
		return
	var token := "immune:" + ConstStates.normalize_token(name)
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
static func _shuffle_mixed_teams(mercs: Array[MercenaryData]) -> bool:
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


#"--auto-forget": every automated encounter starts with an empty campaign knowledge store.
static func _auto_forget() -> bool:
	return OS.get_cmdline_user_args().has("--auto-forget")


#Reads a state name from an "--auto-state=Name" user arg; "" when absent or unknown.
static func _auto_state_name() -> String:
	var state_name := _auto_spec("--auto-state")
	if state_name == "" or ConstStates.ALL.has(state_name):
		return state_name
	print("auto-state: unknown state %s" % state_name)
	return ""


#Reads a state or damage type name from an "--auto-immune=Name" user arg; "" when absent or unknown.
static func _auto_immune_name() -> String:
	var name := _auto_spec("--auto-immune")
	if name == "" or ConstStates.ALL.has(name) or not ConstDamageTypes.get_type(name).is_empty():
		return name
	print("auto-immune: unknown name %s" % name)
	return ""


#"--auto-inflict=Spec" and "--auto-remove=Spec" replace the harness resist specs; "" when absent.
static func _auto_spec(flag: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(flag + "="):
			return arg.substr(flag.length() + 1).strip_edges()
	return ""


#Runs `count` interior autobattles back to back, then quits the engine.
static func run_auto_interior(host: Node, mercs: Array[MercenaryData], count: int) -> void:
	for i: int in range(count):
		if _auto_forget():
			CampaignKnowledge.clear()
		var t0 := Time.get_ticks_msec()
		start_interior_battle(mercs)
		var guard := 0
		while _battle_state != null and guard < 600000:
			guard += 1
			await Engine.get_main_loop().process_frame
		if _battle_state != null:
			print("AUTO INTERIOR: battle %d did not finish" % (i + 1))
			CriticalSuccessSystem.banking = false
			_battle_state = null
		print("ENCOUNTER MS: %d" % (Time.get_ticks_msec() - t0))
	host.get_tree().quit()


#Runs count test contracts back to back, then quits the engine.
static func run_auto_contract(host: Node, mercs: Array[MercenaryData], count: int) -> void:
	for i: int in range(count):
		if _auto_forget():
			CampaignKnowledge.clear()
		await run_test_contract(mercs)
	host.get_tree().quit()


static func _run_battle_loop() -> void:
	while _battle_state != null:
		var ongoing: bool = await AutoBattle.step_round(_battle_state, _battle_line_fn)
		if not ongoing:
			_print_battle_result()
			_battle_state = null


static func start_battle(mercs: Array[MercenaryData]) -> void:
	_start_battle(mercs, "")


static func start_interior_battle(mercs: Array[MercenaryData]) -> void:
	_start_battle(mercs, "Interior")


#Splits the roster, builds the field for kind and runs the autobattle loop.
static func _start_battle(mercs: Array[MercenaryData], kind: String) -> void:
	if _contract_running:
		print("Contract already in progress.")
		return
	if mercs.size() < 2:
		print("Need at least 2 mercs to start a battle.")
		return
	if _battle_state != null:
		print("Battle already in progress.")
		return
	var interior := kind == "Interior"
	if interior:
		print("
====== AUTOBATTLE (INTERIOR) ======
")
	else:
		print("
====== AUTOBATTLE ======
")
	if interior and team_mix:
		if not _shuffle_mixed_teams(mercs):
			print("AUTO MIX: no split with a flyer and a firearm on each side")
	else:
		mercs.shuffle()
	var mid: int = mercs.size() >> 1
	_battle_team_a.clear()
	_battle_team_b.clear()
	_battle_team_a.assign(mercs.slice(0, mid))
	_battle_team_b.assign(mercs.slice(mid))
	var field := BattlefieldArea.generate_random() if not interior else BattlefieldArea.generate_random(null, null, "Interior")
	_battle_state = BattleState.create(_battle_team_a, _battle_team_b, field)
	_battle_line_fn = func(s: String) -> void: print_rich(s)
	var a_names := ", ".join(_battle_team_a.map(func(m: MercenaryData) -> String: return m.merc_name.get_slice(" ", 0)))
	var b_names := ", ".join(_battle_team_b.map(func(m: MercenaryData) -> String: return m.merc_name.get_slice(" ", 0)))
	var order_parts: Array[String] = []
	for i: int in range(_battle_state.turn_queue.size()):
		var m: MercenaryData = _battle_state.turn_queue[i]
		var color := "white" if _battle_team_a.has(m) else "yellow"
		order_parts.append("[color=%s]%s[/color]" % [color, m.merc_name.get_slice(" ", 0)])
	print_rich("[color=white]Team A:[/color] %s" % a_names)
	print_rich("[color=yellow]Team B:[/color] %s" % b_names)
	print_rich("Turn order: %s" % ", ".join(order_parts))
	AutoBattle.setup(_battle_state, _battle_line_fn)
	if interior:
		_log_auto_immune()
		_inflict_auto_state()
	_run_battle_loop()


#Builds a test contract, deploys a shuffled slice of the roster and replaces every casualty.
static func run_test_contract(mercs: Array[MercenaryData]) -> void:
	if _battle_state != null:
		print("Battle already in progress.")
		return
	if _contract_running:
		print("Contract already in progress.")
		return
	_contract_running = true
	BeauSystem.set_roster(mercs)
	var config: ContractConfig = ContractLibrary.config()
	var need: int = maxi(1, config.default_max_mercs)
	if _furlough_flag():
		for line: String in furlough_first(mercs):
			print(line)
	var deployable: Array[MercenaryData] = _wait_for_rested(mercs, need)
	var topped_up: bool = false
	while deployable.size() < need:
		if not topped_up:
			topped_up = true
			print("\n====== ROSTER TOP-UP ======\n")
		var extra: MercenaryData = roster_merc(mercs.size())
		mercs.append(extra)
		grant_auto_immunity(extra, mercs.size() - 1, mercs.size())
		deployable.append(extra)
		MercSheetPrinter.print_merc(extra)
	if topped_up:
		BeauSystem.set_roster(mercs)
	deployable.shuffle()
	var team: Array[MercenaryData] = []
	team.assign(deployable.slice(0, need))
	if config.test_merc_level > 0:
		for merc: MercenaryData in team:
			ContractModifiers.set_level(merc, config.test_merc_level)
	var contract: ContractData = ContractGenerator.generate(config.default_contract_type)
	if contract == null:
		print("CONTRACT: generation failed")
		_contract_running = false
		return
	var saved: String = ContractGenerator.save_instance(contract)
	if saved != "":
		print("CONTRACT SAVED: %s" % saved)
	print("\n====== TEST CONTRACT ======\n")
	var line_fn := func(s: String) -> void: print_rich(s)
	var run: ContractRun = await ContractManager.run(contract, team, line_fn)
	if saved != "":
		ContractGenerator.save_instance(contract, saved)
	harness_restore(team)
	for dead: MercenaryData in run.casualties:
		var slot: int = mercs.find(dead)
		CampaignKnowledge.forget(dead.merc_uid)
		var replacement: MercenaryData = roster_merc(mercs.size())
		if slot < 0:
			mercs.append(replacement)
			slot = mercs.size() - 1
		else:
			mercs[slot] = replacement
		grant_auto_immunity(replacement, slot, mercs.size())
		print("\n====== REPLACEMENT MERC (at the tavern) ======\n")
		MercSheetPrinter.print_merc(replacement)
	_contract_running = false


static func _deployable(mercs: Array[MercenaryData]) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	for merc: MercenaryData in mercs:
		if merc != null and merc.merc_uid > 0 and RestSystem.is_deployable(merc):
			out.append(merc)
	return out


#A rest lockout holds the roster back, so the harness skips ahead to the first merc who comes free.
static func _wait_for_rested(mercs: Array[MercenaryData], need: int) -> Array[MercenaryData]:
	var deployable: Array[MercenaryData] = _deployable(mercs)
	while deployable.size() < need:
		var next: int = -1
		for merc: MercenaryData in mercs:
			if merc == null or merc.merc_uid <= 0 or merc.is_dead or not RestSystem.is_resting(merc):
				continue
			if next < 0 or merc.rest_lockout_until < next:
				next = merc.rest_lockout_until
		if next < 0:
			break
		var delta: int = next - CampaignClock.now()
		CampaignClock.advance_to(next)
		print(CampaignClock.line("rest wait", delta))
		for line: String in RestSystem.complete_due_furloughs(mercs, CampaignClock.now()):
			print(line)
		for line: String in BeauSystem.tick(CampaignClock.now()):
			print(line)
		deployable = _deployable(mercs)
	return deployable


#"--furlough": the first deployable roster merc takes ten days off before the next test contract.
static func _furlough_flag() -> bool:
	return OS.get_cmdline_user_args().has("--furlough")


static func furlough_first(mercs: Array[MercenaryData]) -> Array[String]:
	var lines: Array[String] = []
	for merc: MercenaryData in mercs:
		if merc != null and merc.merc_uid > 0 and RestSystem.is_deployable(merc):
			lines.append_array(RestSystem.furlough_start(merc))
			return lines
	return lines


#Batch statistics stay comparable when every contract starts whole; excess pools are left alone.
static func harness_restore(team: Array[MercenaryData]) -> void:
	var names: Array[String] = []
	for merc: MercenaryData in team:
		if merc == null:
			continue
		merc.current_hp = int(merc.stats.get("maximum_hit_points", merc.current_hp))
		merc.is_dead = false
		merc.current_ep = int(merc.stats.get("maximum_endurance_points", merc.current_ep))
		merc.current_ap = int(merc.stats.get("action_points", merc.current_ap))
		var max_mp: int = int(merc.stats.get("maximum_magic_points", 0))
		if max_mp > 0:
			merc.current_mp = max_mp
		merc.ap_debt = 0
		BattleState._reset_starting_ammo(merc)
		for state_name: String in ConstStates.campaign_state_names():
			_hard_clear_state(merc, state_name)
		merc.campaign_states.clear()
		merc.rest_lockout_until = 0
		merc.rest_lockout_kind = ""
		names.append(merc.merc_name)
	if not names.is_empty():
		print("HARNESS RESTORE: %s" % ", ".join(names))


#A state kept alive by an applying root survives remove_state, so the harness drops it outright.
static func _hard_clear_state(merc: MercenaryData, state_name: String) -> void:
	if not ConstStates.has_state(merc, state_name):
		return
	ConstStates.remove_state(merc, state_name)
	merc.active_states.erase(state_name)
	var record: Variant = merc.active_states.get(ConstStates.APPLIED_BY_KEY)
	if record is Dictionary:
		(record as Dictionary).erase(state_name)


#"AUTO IMMUNE: <token> <names>" lists the mercs carrying the auto-immune token this encounter.
static func _log_auto_immune() -> void:
	var name := _auto_immune_name()
	if name == "" or not EncounterLogger.is_active():
		return
	var token := "immune:" + ConstStates.normalize_token(name)
	var names: Array[String] = []
	for team: Array in [_battle_team_a, _battle_team_b]:
		for merc: MercenaryData in team:
			if merc.passive_effects.has(token):
				names.append(merc.merc_name)
	EncounterLogger.log_verbose("AUTO IMMUNE: %s %s" % [token, ",".join(names)])


#"--auto-state=Name": every merc rolls to resist Name from a random living enemy before round 1.
static func _inflict_auto_state() -> void:
	var name := _auto_state_name()
	if name == "":
		return
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("STATE TEST: %s" % name)
	var remove_spec := "Resist:Vigor:2:Interact" if name == ConstStates.BURNING else "Resist:Vigor:2:End Turn"
	var inflict_spec := "Resist:Vigor:2"
	if _auto_spec("--auto-remove") != "":
		remove_spec = _auto_spec("--auto-remove")
	if _auto_spec("--auto-inflict") != "":
		inflict_spec = _auto_spec("--auto-inflict")
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("STATE TEST SPECS: inflict=%s remove=%s" % [inflict_spec, remove_spec])
	var immune_names: Array[String] = []
	for im_team: Array in [_battle_team_a, _battle_team_b]:
		for im_merc: MercenaryData in im_team:
			if ConstStates.is_immune(im_merc, name):
				immune_names.append(im_merc.merc_name)
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("STATE TEST IMMUNE: %s" % ",".join(immune_names))
	for team: Array in [_battle_team_a, _battle_team_b]:
		for merc: MercenaryData in team:
			var foes := _battle_state.get_enemies(merc)
			if foes.is_empty():
				continue
			var source: MercenaryData = foes[randi() % foes.size()]
			var lines := StateInfliction.inflict(
				merc, name, inflict_spec, "1 Minute", remove_spec, source, _battle_state)
			for line: String in lines:
				EncounterLogger.log_line(line)
			if _battle_line_fn.is_valid() and not lines.is_empty():
				_battle_line_fn.call("\n".join(lines))
	EncounterLogger.flush()


static func _print_battle_result() -> void:
	var winner_idx: int = _battle_state.get_winner()
	if winner_idx >= 0:
		var winning_team: Array = _battle_state.teams[winner_idx]
		var winner_names: Array[String] = []
		for m: MercenaryData in winning_team:
			winner_names.append(m.merc_name.get_slice(" ", 0))
		var w_color := "white" if winner_idx == 0 else "yellow"
		print_rich("[color=gray]=== Battle over in %d rounds ===[/color]" % _battle_state.round_number)
		print_rich("[color=%s]Team %s wins!  (%s)[/color]" % [w_color, "A" if winner_idx == 0 else "B", ", ".join(winner_names)])
	else:
		print_rich("[color=gray]=== Draw / timeout after %d rounds ===[/color]" % _battle_state.round_number)
