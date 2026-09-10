class_name BattleEventResolver

#Resolves a Battle event as a full AutoBattle encounter and reports casualties back to the run.


static func resolve(event: EventData, run: ContractRun) -> Dictionary:
	var out: Dictionary = EventRunner.outcome(event)
	var team_a: Array[MercenaryData] = run.living_team()
	if team_a.is_empty():
		var no_team: Array[String] = ["no living mercs"]
		out["notes"] = no_team
		run.emit("EVENT SKIPPED: %s (no living mercs)" % event.event_name)
		return out
	var extra: int = 0
	if event.enemy_counter.contains("bad_luck_roll"):
		var r: Dictionary = BadLuckRoll.roll(team_a, ContractLibrary.config().bad_luck_step)
		run.emit(String(r["line"]))
		extra = int(r["extra"])
	out["bad_luck_extra"] = extra
	var enemies: Array[MercenaryData] = EnemyTeamBuilder.build(event, run, extra)
	if enemies.is_empty():
		var no_enemy: Array[String] = ["no enemies"]
		out["notes"] = no_enemy
		run.emit("EVENT FAILED: %s (no enemies generated)" % event.event_name)
		return out
	out["enemies"] = run.merc_names(enemies)
	out["enemy_count"] = enemies.size()
	if run.contract != null and event.event_name == run.contract.assigned_primary_event:
		run.target_record = _target_record(event, enemies)
	run.emit("ENEMY TEAM: %d x %s" % [enemies.size(), event.enemy])
	for enemy: MercenaryData in enemies:
		run.emit("ENEMY: %s" % ContractLog.merc_line(enemy))
	var field: BattlefieldArea = ContractTerrain.field_for(event, run.location, team_a.size(), enemies.size())
	run.emit("MAP: %s %dx%d %s" % [field.area_name, field.width, field.length,
		"interior" if field.is_interior_map else "exterior"])
	for merc: MercenaryData in team_a:
		run.emit(OverallSuccess.describe(merc, OverallSuccess.for_merc(run.contract, team_a, merc, event)))
	var record: Dictionary = OverallSuccess.apply_event_delta(run.contract, team_a, event)
	var state: BattleState = BattleState.create(team_a, enemies, field, true)
	var result: Dictionary = await AutoBattle.run_battle(state, run.line_fn, event.event_name)
	OverallSuccess.revert_event_delta(record)
	var log_file: String = EncounterLogger.current_log_path()
	if log_file != "":
		run.encounter_logs.append(log_file)
	out["log_file"] = log_file
	out["winner"] = int(result.get("winner", -1))
	out["rounds"] = int(result.get("rounds", 0))
	#TODO fled enemies count as defeated once fleeing exists
	var defeated: int = 0
	for enemy: MercenaryData in enemies:
		if enemy.is_dead or enemy.current_hp <= 0:
			defeated += 1
	out["enemies_defeated"] = defeated
	out["success"] = defeated == enemies.size()
	for line: String in ExperienceSystem.award_encounter(team_a, enemies, state.damage_dealt_total, event.event_name):
		run.emit(line)
	var dead: Array[MercenaryData] = []
	for merc: MercenaryData in state.casualties:
		if team_a.has(merc):
			dead.append(merc)
	var moved: Array[MercenaryData] = run.remove_dead(dead)
	for merc: MercenaryData in moved:
		run.emit("CASUALTY: %s" % merc.merc_name)
	out["casualties"] = run.merc_names(moved)
	for name: String in stabilize(run):
		run.emit("STABILIZED: %s" % name)
	TraitRuntime.on_combat_complete(run, event.event_name)
	run.emit("EVENT RESULT: %s %s winner %d rounds %d enemies defeated %d/%d" % [
		event.event_name, "success" if bool(out["success"]) else "failure",
		int(out["winner"]), int(out["rounds"]), defeated, enemies.size()])
	return out


#What the lifepath Target Creature subjects read: every tag the assigned event's enemies carry.
static func _target_record(event: EventData, enemies: Array[MercenaryData]) -> Dictionary:
	var tags: Array[String] = []
	var speed: int = 0
	var max_hp: int = 0
	for enemy: MercenaryData in enemies:
		if enemy == null:
			continue
		for raw: String in enemy.creature_types:
			var t: String = ConstStates.normalize_token(raw)
			if t != "" and not tags.has(t):
				tags.append(t)
		speed = maxi(speed, int(enemy.stats.get("speed", 0)))
		max_hp = maxi(max_hp, int(enemy.stats.get("maximum_hit_points", 0)))
	var enemy_token: String = ConstStates.normalize_token(event.enemy)
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
