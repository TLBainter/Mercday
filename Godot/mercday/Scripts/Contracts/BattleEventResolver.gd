class_name BattleEventResolver

#Resolves a Battle event as a full AutoBattle encounter and reports casualties back to the run.

#The batch harness reads the last encounter; nothing in the game loop touches these.
static var last_state: BattleState = null
static var last_enemies: Array[MercenaryData] = []


static func resolve(event: EventData, run: ContractRun, opts: Dictionary = {}) -> Dictionary:
	last_state = null
	last_enemies = []
	var out: Dictionary = EventRunner.outcome(event)
	var team_a: Array[MercenaryData] = run.living_team()
	if team_a.is_empty():
		var no_team: Array[String] = ["no living mercs"]
		out["notes"] = no_team
		run.emit("EVENT SKIPPED: %s (no living mercs)" % event.event_name)
		return out
	var roster: Array[MercenaryData] = []
	roster.assign(team_a)
	var built: Dictionary = _build_enemies(event, run, team_a, opts, out)
	var rescue: Dictionary = built["rescue"]
	var enemies: Array[MercenaryData] = []
	enemies.assign(built["enemies"])
	if enemies.is_empty():
		var no_enemy: Array[String] = ["no enemies"]
		out["notes"] = no_enemy
		run.emit("EVENT FAILED: %s (no enemies generated)" % event.event_name)
		return out
	last_enemies = enemies
	if run.contract != null and event.event_name == run.contract.assigned_primary_event:
		run.target_record = _target_record(event, enemies)
	run.emit("ENEMY TEAM: %d x %s" % [enemies.size(), event.enemy])
	for enemy: MercenaryData in enemies:
		run.emit("ENEMY: %s" % ContractLog.merc_line(enemy))
	var size_a: int = team_a.size() + (1 if not rescue.is_empty() else 0)
	var field: BattlefieldArea = ContractTerrain.field_for(event, run.location, size_a,
		enemies.size(), run.contract, 1 if not rescue.is_empty() else 0)
	run.emit("TERRAIN: %s" % ContractTerrain.last_draw)
	run.emit("MAP: %s %dx%d %s" % [field.area_name, field.width, field.length,
		"interior" if field.is_interior_map else "exterior"])
	for merc: MercenaryData in team_a:
		run.emit(OverallSuccess.describe(merc, OverallSuccess.for_merc(run.contract, team_a, merc, event)))
	var record: Dictionary = OverallSuccess.apply_event_delta(run.contract, team_a, event)
	var side_a: Array[MercenaryData] = []
	side_a.assign(team_a)
	if not rescue.is_empty():
		side_a.append(rescue["captive"])
	var side_b: Array[MercenaryData] = []
	side_b.assign(enemies)
	var state: BattleState = BattleState.create(side_a, side_b, field, true)
	last_state = state
	state.flee_enabled = bool(opts.get("flee", true))
	if not rescue.is_empty():
		state.flee_enabled = false
		for line: String in RescueSystem.attach(state, rescue["captive"], String(rescue["mode"]),
				run.difficulty()):
			run.emit(line)
	_apply_opts(state, opts)
	if BetrayalSystem.should_run(event, opts):
		for merc: MercenaryData in BetrayalSystem.run_pre_battle(run, state, roster):
			BetrayalSystem.drop_delta(record, merc)
	var result: Dictionary = await AutoBattle.run_battle(state, run.line_fn, event.event_name)
	OverallSuccess.revert_event_delta(record)
	_settle(run, state, roster, event, enemies, rescue, result, out)
	return out


#The rescue setup and the enemy side: an opts override, the rescue captors, else the built team.
static func _build_enemies(event: EventData, run: ContractRun, team_a: Array[MercenaryData],
		opts: Dictionary, out: Dictionary) -> Dictionary:
	var rescue: Dictionary = {}
	if event.event_name == RescueSystem.EVENT_NAME:
		rescue = RescueContractBuilder.battle_setup(run, event)
		if rescue.is_empty():
			run.emit("RESCUE: no captive found; plain battle")
	var enemies: Array[MercenaryData] = []
	if opts.has("enemies"):
		enemies.assign(opts["enemies"])
	elif not rescue.is_empty():
		enemies.assign(rescue["enemies"])
	else:
		var extra: int = 0
		if event.enemy_counter.contains("bad_luck_roll"):
			var r: Dictionary = BadLuckRoll.roll(team_a, ContractLibrary.config().bad_luck_step)
			run.emit(String(r["line"]))
			extra = int(r["extra"])
		out["bad_luck_extra"] = extra
		enemies = EnemyTeamBuilder.build(event, run, extra)
	return {"rescue": rescue, "enemies": enemies}


#The battle state keys the caller passed in; flee stays in resolve because the rescue wiring overrides it.
static func _apply_opts(state: BattleState, opts: Dictionary) -> void:
	state.no_death_removal = bool(opts.get("no_death_removal", false))
	var prio: Variant = opts.get("priority_targets", [])
	if prio is Array:
		state.priority_targets.assign(prio)
	var adjacent: Dictionary = opts.get("adjacent", {})
	for enemy: MercenaryData in adjacent.keys():
		SpawnPlacer.place_adjacent(state, enemy, adjacent[enemy])
	var surprised: Array = opts.get("surprised", [])
	var rm: Array[String] = ["time"]
	for merc: MercenaryData in surprised:
		ConstStates.apply_state(merc, ConstStates.SURPRISED, null, "", "engine:kidnap", rm)


#What the finished battle leaves behind: the log path, the tallies and every post battle system in turn.
static func _settle(run: ContractRun, state: BattleState, roster: Array[MercenaryData],
		event: EventData, enemies: Array[MercenaryData], rescue: Dictionary, result: Dictionary,
		out: Dictionary) -> void:
	var log_file: String = EncounterLogger.current_log_path()
	if log_file != "":
		run.encounter_logs.append(log_file)
	out["log_file"] = log_file
	out["winner"] = int(result.get("winner", -1))
	out["rounds"] = int(result.get("rounds", 0))
	var foe_list := BetrayalSystem.foes(enemies, state)
	var loyal_list := BetrayalSystem.loyal(roster, state)
	out["enemies"] = run.merc_names(foe_list)
	out["enemy_count"] = foe_list.size()
	var defeated: int = defeated_foes(foe_list, state, run)
	out["enemies_defeated"] = defeated
	var abandoned: Array[MercenaryData] = []
	for foe: MercenaryData in foe_list:
		if state.escaped.has(foe) and foe.flee_abandons:
			abandoned.append(foe)
	out["foes_abandoned"] = abandoned
	out["success"] = defeated == foe_list.size()
	if not rescue.is_empty():
		var ro: Dictionary = RescueSystem.outcome(state)
		out["success"] = bool(ro.get("success", false))
		out["rescue"] = ro
		out["rescue_result"] = String(ro.get("result", ""))
		RescueContractBuilder.complete(run, ro)
	for line: String in ExperienceSystem.award_encounter(loyal_list, foe_list, state.damage_dealt_total, event.event_name):
		run.emit(line)
	var dead := BetrayalSystem.dead_of(state, roster)
	var moved: Array[MercenaryData] = run.remove_dead(dead)
	for merc: MercenaryData in moved:
		run.emit("CASUALTY: %s" % merc.merc_name)
	out["casualties"] = run.merc_names(moved)
	for line: String in BetrayalSystem.settle(run, state):
		run.emit(line)
	for line: String in FleeSettlement.settle(run, state, loyal_list):
		run.emit(line)
	for line: String in CaveInSystem.settle(run, state, roster):
		run.emit(line)
	for line: String in KidnapSystem.settle(run, state, roster, event.enemy):
		run.emit(line)
	for name: String in stabilize(run):
		run.emit("STABILIZED: %s" % name)
	TraitRuntime.on_combat_complete(run, event.event_name)
	run.emit("EVENT RESULT: %s %s winner %d rounds %d enemies defeated %d/%d" % [
		event.event_name, "success" if bool(out["success"]) else "failure",
		int(out["winner"]), int(out["rounds"]), defeated, foe_list.size()])


#Foes dead, down or off the field; an escaped foe counts and is named in the log.
static func defeated_foes(foe_list: Array[MercenaryData], state: BattleState, run: ContractRun) -> int:
	var defeated: int = 0
	for enemy: MercenaryData in foe_list:
		if enemy.is_dead or enemy.current_hp <= 0 or enemy.off_field:
			defeated += 1
		if state.escaped.has(enemy):
			run.emit("ESCAPED: %s counts as defeated" % enemy.merc_name)
	return defeated


#What the lifepath Target Creature subjects read: every tag the assigned event's enemies carry.
static func _target_record(event: EventData, enemies: Array[MercenaryData]) -> Dictionary:
	var tags: Array[String] = []
	var speed: int = 0
	var max_hp: int = 0
	for enemy: MercenaryData in enemies:
		if enemy == null:
			continue
		for raw: String in enemy.creature_types:
			var t: String = StateTokens.normalize_token(raw)
			if t != "" and not tags.has(t):
				tags.append(t)
		speed = maxi(speed, int(enemy.stats.get("speed", 0)))
		max_hp = maxi(max_hp, int(enemy.stats.get("maximum_hit_points", 0)))
	var enemy_token: String = StateTokens.normalize_token(event.enemy)
	if enemy_token != "" and not tags.has(enemy_token):
		tags.append(enemy_token)
	if enemy_token == "mercs" and not tags.has("merc"):
		tags.append("merc")
	return {"tags": tags, "count": enemies.size(), "speed": speed, "max_hp": max_hp, "failed": {}}


static func stabilize(run: ContractRun) -> Array[String]:
	var names: Array[String] = []
	for merc: MercenaryData in run.living_team():
		if merc.current_hp > 0:
			continue
		merc.current_hp = 1
		if ConstStates.has_state(merc, ConstStates.DYING):
			ConstStates.remove_state(merc, ConstStates.DYING)
		names.append(merc.merc_name)
	return names
