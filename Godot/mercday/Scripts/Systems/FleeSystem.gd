class_name FleeSystem

#A losing merc whose flee value reaches the gate may break and run for the map edge; abandoners leave the party after it.

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")
const _SLOT_CAP := 8
const _BANK_CAP := 20

static var enabled: bool = true
#Test hook: each entry is popped as the next d100 before any random roll.
static var forced_rolls: Array[int] = []
static var forced: Dictionary = {}   #merc -> true; kidnap forces flee with no gate, roll or Terrified
static var checks_rolled: int = 0
static var withdraws: int = 0
static var goal_cache: Dictionary = {}     #MercenaryData -> {"round": int, "goal": Vector3i}
static var _immune_logged: Dictionary = {}  #MercenaryData -> true


static func reset() -> void:
	forced_rolls.clear()
	checks_rolled = 0
	withdraws = 0
	forced.clear()
	goal_cache.clear()
	_immune_logged.clear()
	enabled = true


static func begin_battle(_state: BattleState) -> void:
	goal_cache.clear()
	_immune_logged.clear()


static func _d100() -> int:
	if not forced_rolls.is_empty():
		return forced_rolls.pop_front()
	return randi_range(1, 100)


static func _team_index(merc: MercenaryData, state: BattleState) -> int:
	if state == null:
		return -1
	for i: int in range(state.teams.size()):
		if (state.teams[i] as Array).has(merc):
			return i
	return -1


#Percent of the team's summed maximum HP that is gone; escaped members are left out of both sums.
static func missing_percent(team: Array, state: BattleState) -> float:
	var total := 0.0
	var missing := 0.0
	for m: Variant in team:
		if not (m is MercenaryData) or state.escaped.has(m):
			continue
		var merc := m as MercenaryData
		var mx := maxf(1.0, float(merc.stats.get("maximum_hit_points", 0)))
		total += mx
		if merc.is_dead or merc.current_hp <= 0 or state.removed_from_field.has(merc):
			missing += mx
		else:
			missing += clampf(mx - float(merc.current_hp), 0.0, mx)
	return missing / maxf(1.0, total) * 100.0


static func swing(merc: MercenaryData, state: BattleState) -> float:
	if state == null or state.teams.size() < 2:
		return 0.0
	var i := _team_index(merc, state)
	if i == -1:
		return 0.0
	return missing_percent(state.teams[i] as Array, state) - missing_percent(state.teams[1 - i] as Array, state)


static func spread(merc: MercenaryData, state: BattleState) -> float:
	var i := _team_index(merc, state)
	if i == -1:
		return 0.0
	var team := state.teams[i] as Array
	var count := 0
	for m: Variant in team:
		if m == merc or not (m is MercenaryData):
			continue
		if is_fleeing(m as MercenaryData) or state.escaped.has(m):
			count += 1
	return count / float(team.size()) * 100.0


#True when this turn is a flee turn: a merc already fleeing keeps running, or a new check sends it running.
static func start_of_turn(merc: MercenaryData, state: BattleState, lines: Array[String]) -> bool:
	if state == null or not BattleState._is_alive(merc) or ConstStates.has_state(merc, ConstStates.DYING):
		return false
	if forced.has(merc) and merc.flee_intent:
		return true
	if merc.flee_intent:
		if ConstStates.has_state(merc, ConstStates.TERRIFIED):
			state.clear_state_timer(merc, ConstStates.TERRIFIED)
			return true
		lines.append_array(stop(merc))
	if not enabled or not state.flee_enabled:
		return false
	var sheet := float(merc.stats.get("flee", 0.0))
	var sw := swing(merc, state)
	var v := sheet + sw
	if sw <= 0.0 or v < _CONFIG.flee_gate:
		return false
	if ConstStates.is_immune(merc, ConstStates.TERRIFIED):
		if not _immune_logged.has(merc):
			_immune_logged[merc] = true
			lines.append("  FLEE IMMUNE: %s" % merc.merc_name)
		return false
	var sp := spread(merc, state)
	checks_rolled += 1
	var a := _d100()
	var head := "  FLEE CHECK: %s flee %.1f (sheet %.1f swing %.1f spread %.1f) d100 %d" % [
			merc.merc_name, v + sp, sheet, sw, sp, a]
	if float(a) > v + sp:
		lines.append(head + " -> stays")
		return false
	var b := _d100()
	var abandons := float(b) <= v / 2.0
	lines.append(head + " -> runs; d100 %d vs %.1f -> %s" % [b, v / 2.0, "abandons" if abandons else "returns"])
	merc.flee_intent = true
	merc.flee_abandons = abandons
	merc.flee_escape_paces = 0
	var rm: Array[String] = ["interact"]
	var ok := ConstStates.apply_state(merc, ConstStates.TERRIFIED, ConstStates.get_source(merc, ConstStates.TERRIFIED),
			"", "engine:flee", rm)
	if not ok:
		merc.flee_intent = false
		merc.flee_abandons = false
		merc.flee_escape_paces = 0
		return false
	state.clear_state_timer(merc, ConstStates.TERRIFIED)
	lines.append("  %s breaks and runs!" % BattleState.colored_name(merc, state))
	return true


static func is_flee_terrified(merc: MercenaryData) -> bool:
	for src: Dictionary in StateSources.state_sources(merc, ConstStates.TERRIFIED):
		if str(src.get("kind", "")) == "engine" and str(src.get("name", "")) == "flee":
			return true
	return false


static func is_fleeing(merc: MercenaryData) -> bool:
	return merc != null and merc.flee_intent \
		and (forced.has(merc) or ConstStates.has_state(merc, ConstStates.TERRIFIED))


static func hold(merc: MercenaryData, state: BattleState) -> void:
	if state != null and is_fleeing(merc):
		state.clear_state_timer(merc, ConstStates.TERRIFIED)


static func stop(merc: MercenaryData) -> Array[String]:
	merc.flee_intent = false
	merc.flee_abandons = false
	merc.flee_escape_paces = 0
	goal_cache.erase(merc)
	forced.erase(merc)
	var out: Array[String] = ["  FLEE ENDED: %s" % merc.merc_name]
	return out


static func on_edge(merc: MercenaryData, state: BattleState) -> bool:
	if state == null or state.battlefield == null:
		return true
	var field := state.battlefield
	var p := state.get_position(merc)
	return p.x <= 0 or p.y <= 0 or p.x >= field.width - 1 or p.y >= field.length - 1


#True when an enemy would take an Advantage Attack if merc stepped away from its cell now.
static func in_danger(merc: MercenaryData, state: BattleState) -> bool:
	if state == null or state.battlefield == null:
		return false
	var p := state.get_position(merc)
	return not ReactiveActionSystem.get_triggered_reactions("enemy_leaves_melee_range", merc, p, p, state).is_empty()


static func run_turn(merc: MercenaryData, state: BattleState, lines: Array[String], enhancements: int) -> void:
	var turn: Dictionary = AutoBattle.new_turn(merc, state)
	var ctx := {"enhancements": enhancements}
	var field := state.battlefield
	if field != null and field.is_cavern:
		_cavern_posture(merc, state, lines, ctx)
		if _climb_out(merc, state, lines, turn):
			return
	elif ConstStates.has_state(merc, ConstStates.DEPOSED) and state.can_afford(merc, state.get_cost(merc, "get_up", 2)):
		lines.append_array(SpecialActionSystem.execute({"action_name": "get_up"}, merc, state, ctx))
	var locked := ConstStates.is_blocked(merc, "action:move") or MovementExecutor.pace_per_move(merc) <= 0
	if locked and _can_break_free(merc) and state.can_afford(merc, state.get_cost(merc, "break_free", 2)):
		lines.append_array(SpecialActionSystem.execute({"action_name": "break_free"}, merc, state, ctx))
		locked = ConstStates.is_blocked(merc, "action:move") or MovementExecutor.pace_per_move(merc) <= 0
	if locked:
		return
	#A runner caught on a wall finishes that climb before it looks for anywhere else to go.
	if not state.is_sunk(merc) and _continue_climb(merc, state, lines, turn):
		return
	var banked := false
	var withdrew := false
	for _slot: int in range(_SLOT_CAP):
		if not BattleState._is_alive(merc):
			break
		lines.append_array(BattleStateUpdater.update_auto_states(merc, state))
		if on_edge(merc, state):
			bank(merc, state, lines)
			banked = true
			break
		var foes := state.get_enemies(merc)
		if foes.is_empty():
			break
		var nearest := MovementDecider.closest_enemy(merc, foes, state)
		if not withdrew and not merc.advantage_immune and in_danger(merc, state) \
				and state.can_afford(merc, state.get_cost(merc, "withdraw", 2)):
			withdrew = true
			lines.append_array(SpecialActionSystem.execute({"action_name": "withdraw", "target": nearest},
					merc, state, ctx))
			continue
		if not state.can_afford(merc, state.move_cost(merc, "Move Far", _CONFIG.move_base_ap)):
			break
		var before := state.pos3(merc)
		lines.append_array(MovementExecutor.run_move_arm(merc, {"type": "move", "action_name": "Move Far",
				"target": nearest, "goal_cell": escape_goal(merc, state), "moves_allowed": 2, "reserve_ap": 0},
				state, enhancements, turn))
		if not BattleState._is_alive(merc):
			break
		if state.pos3(merc) == before and not _handover(merc, state, lines, turn, nearest, enhancements):
			break
	if not banked and BattleState._is_alive(merc) and on_edge(merc, state):
		bank(merc, state, lines)


#Runs a climb already under way to its end; true when the turn is over, false once the climb is done.
static func _continue_climb(merc: MercenaryData, state: BattleState, lines: Array[String],
		turn: Dictionary) -> bool:
	if not ConstStates.has_state(merc, ConstStates.CLIMBING):
		return false
	for _step: int in range(_SLOT_CAP):
		if not BattleState._is_alive(merc):
			return true
		if not ConstStates.has_state(merc, ConstStates.CLIMBING):
			return false
		var cd := state.get_climbing_data(merc)
		if int(cd.get("current_h", 0)) >= int(cd.get("target_h", 0)):
			return true
		if not MovementExecutor.can_fund_climb(merc, state, "Climb", MovementExecutor.climb_pace_cost(merc)):
			return true
		var out := MovementExecutor.run_climb_arm(merc,
			{"type": "climb", "action_name": "Climb", "climb_continuing": true}, state, turn)
		if out.is_empty():
			return true
		lines.append_array(out)
	return true


#The climb or leap a blocked walk left this runner at the foot of; true when the turn goes on.
static func _handover(merc: MercenaryData, state: BattleState, lines: Array[String], turn: Dictionary,
		nearest: MercenaryData, enhancements: int) -> bool:
	var foot := state.pos3(merc)
	if MovementExecutor.climb_route_ready(merc, state):
		var found := ClimbAction.find_target(merc, state)
		if found.is_empty():
			return false
		var down: bool = bool(found.get("down", false))
		var decision: Dictionary = {"type": "climb", "action_name": "Initiate Climb",
			"climb_target_pos": found["pos"] as Vector2i}
		var link: Dictionary = found.get("link", {}) as Dictionary
		if not link.is_empty():
			decision["climb_link"] = link
			decision["climb_down"] = down
		var out := MovementExecutor.run_climb_arm(merc, decision, state, turn)
		if out.is_empty():
			return false
		lines.append_array(out)
		turn.erase("climb_foot_seen")
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("FLEE CLIMB: %s foot=(%d,%d,%d) dir=%s" % [
				merc.merc_name, foot.x, foot.y, foot.z, "down" if down else "up"])
		return not _continue_climb(merc, state, lines, turn)
	if MovementExecutor.jump_route_ready(merc, state):
		var land := JumpAction.routed_landing_for(merc, state)
		if land == JumpAction.NO_JUMP:
			return false
		var jumped := MovementExecutor.run_jump_arm(merc, {"type": "jump", "action_name": "Jump",
			"target": nearest, "jump_target_pos": Vector2i(land.x, land.y),
			"jump_target_floor": land.z, "jump_why": "roof"}, state, enhancements, turn)
		if jumped.is_empty():
			return false
		lines.append_array(jumped)
		turn.erase("climb_foot_seen")
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("FLEE LEAP: %s to=(%d,%d,%d)" % [
				merc.merc_name, land.x, land.y, land.z])
		return true
	return false


static func _can_break_free(merc: MercenaryData) -> bool:
	for key: Variant in merc.active_states.keys():
		if key is String and ConstStates.DATA.has(key) and ConstStates.has_removal(key as String, "action:break_free"):
			#Water and crawl hold the merc through the cavern itself; no action shakes them off.
			if CavernRules.is_cavern_sourced(merc, key as String):
				continue
			return true
	return false


#Standing, dropping to a crawl, or the plain GetUp, whichever the rock roof overhead allows.
static func _cavern_posture(merc: MercenaryData, state: BattleState, lines: Array[String], ctx: Dictionary) -> void:
	var field := state.battlefield
	var size := maxi(1, int(merc.stats.get("size", 1)))
	var room: bool = field.clearance(state.get_position(merc)) >= float(size)
	if merc.crawling:
		if room and _spend_pace(merc, state, 1):
			CavernRules.stand(merc, state, lines)
		return
	if not ConstStates.has_state(merc, ConstStates.DEPOSED):
		return
	if not room:
		CavernRules.start_crawl(merc, state, lines)
		return
	if state.can_afford(merc, state.get_cost(merc, "get_up", 2)):
		lines.append_array(SpecialActionSystem.execute({"action_name": "get_up"}, merc, state, ctx))


#Takes paces out of the pool, buying one Move first when the pool is short and the AP allows it.
static func _spend_pace(merc: MercenaryData, state: BattleState, paces: int) -> bool:
	var pool := state.get_pace_pool(merc)
	if pool < paces:
		if MovementExecutor.pace_per_move(merc) <= 0:
			return false
		if not state.can_afford(merc, state.get_cost(merc, "Move Far", _CONFIG.move_base_ap)):
			return false
		MovementExecutor._buy_move(merc, state, "Move Far")
		pool = state.get_pace_pool(merc)
		if pool < paces:
			return false
	state.set_pace_pool(merc, pool - paces)
	return true


#A merc on the bottom of a pool climbs out before it flees anywhere; true when it spent the turn on that.
static func _climb_out(merc: MercenaryData, state: BattleState, lines: Array[String], turn: Dictionary) -> bool:
	if not state.is_sunk(merc):
		return false
	if ConstStates.has_state(merc, ConstStates.CLIMBING):
		lines.append_array(MovementExecutor.run_climb_arm(merc,
			{"type": "climb", "action_name": "Climb", "climb_continuing": true}, state, turn))
		return true
	var target := ClimbAction._find_climb_target(merc, state)
	if target == Vector2i(-1, -1):
		return false
	lines.append_array(MovementExecutor.run_climb_arm(merc,
		{"type": "climb", "action_name": "Initiate Climb", "climb_target_pos": target}, state, turn))
	return true


#Buys Moves with the AP left and banks the pool as paces off the map; a captor needs fewer than a plain flee-er.
static func bank(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	var buys := 0
	while buys < _BANK_CAP and MovementExecutor.pace_per_move(merc) > 0 \
			and state.can_afford(merc, state.get_cost(merc, "Move Far", _CONFIG.move_base_ap)):
		MovementExecutor._buy_move(merc, state, "Move Far")
		buys += 1
	var paces := state.get_pace_pool(merc)
	state.set_pace_pool(merc, 0)
	if paces <= 0:
		return
	var need: int = _CONFIG.kidnap_escape_paces if KidnapSystem.holds(merc, state) \
			else _CONFIG.flee_escape_paces
	merc.flee_escape_paces += paces
	lines.append("  FLEE TRACK: %s +%d paces (%d/%d)" % [merc.merc_name, paces, merc.flee_escape_paces,
			need])
	if merc.flee_escape_paces >= need:
		state.remove_from_field(merc, "fled", lines)
		if merc.off_field:
			KidnapSystem.on_escape(merc, state, lines)


#Map-edge cell a fleeing merc walks toward, cached for the round; NO_CELL when there is no field or no cell.
static func escape_goal(merc: MercenaryData, state: BattleState) -> Vector3i:
	if state == null or state.battlefield == null:
		return PathTargeter.NO_CELL
	var cached := _cached_goal(merc, state)
	if cached != PathTargeter.NO_CELL:
		return cached
	var field := state.battlefield
	var floors: Array[int] = field.sorted_floors()
	if floors.is_empty():
		floors.append(0)
	var cells: Array[Vector3i] = []
	for f: int in floors:
		for x: int in range(field.width):
			cells.append(Vector3i(x, 0, f))
			if field.length > 1:
				cells.append(Vector3i(x, field.length - 1, f))
		for y: int in range(1, field.length - 1):
			cells.append(Vector3i(0, y, f))
			if field.width > 1:
				cells.append(Vector3i(field.width - 1, y, f))
	var reach := PathTargeter.reachable_far_for(merc, state, cells, PathTargeter.RING_SLACK)
	var scored := _score_reachable(merc, state, cells, reach, _foe_cells(merc, state))
	var goal: Vector3i = scored["goal"]
	goal_cache[merc] = {"round": state.round_number, "goal": goal}
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("FLEE GOAL: %s tier %d (%d,%d,%d) cost %d"
				% [merc.merc_name, int(scored["tier"]), goal.x, goal.y, goal.z, int(reach.get(goal, -1))])
	return goal


#Goal kept from an earlier call this round; NO_CELL when there is none or it is the cell the merc stands on.
static func _cached_goal(merc: MercenaryData, state: BattleState) -> Vector3i:
	var cached: Variant = goal_cache.get(merc)
	if cached is Dictionary and int((cached as Dictionary).get("round", -1)) == state.round_number:
		var prev: Vector3i = (cached as Dictionary).get("goal", PathTargeter.NO_CELL) as Vector3i
		if prev != PathTargeter.NO_CELL and prev != state.pos3(merc):
			return prev
	return PathTargeter.NO_CELL


static func _foe_cells(merc: MercenaryData, state: BattleState) -> Array[Vector3i]:
	var foe_cells: Array[Vector3i] = []
	for foe: MercenaryData in state.get_enemies(merc):
		foe_cells.append(state.pos3(foe))
	return foe_cells


#Picks the escape goal out of the reachable edge cells; returns {"goal": Vector3i, "tier": int}.
static func _score_reachable(merc: MercenaryData, state: BattleState, cells: Array[Vector3i],
		reach: Dictionary, foe_cells: Array[Vector3i]) -> Dictionary:
	var own := state.pos3(merc)
	var field := state.battlefield
	var kept: Array[Vector3i] = []
	for c: Vector3i in cells:
		if c != own and _goal_ok(c, reach, merc, state):
			kept.append(c)
	var goal := PathTargeter.NO_CELL
	var tier := 0
	var open_cell := PathTargeter.NO_CELL
	var any_cell := PathTargeter.NO_CELL
	for c: Vector3i in kept:
		if c.z != 0:
			continue
		var cost := int(reach[c])
		if any_cell == PathTargeter.NO_CELL or cost < int(reach[any_cell]):
			any_cell = c
		if (open_cell == PathTargeter.NO_CELL or cost < int(reach[open_cell])) and not _foe_beside(c, foe_cells):
			open_cell = c
	if any_cell != PathTargeter.NO_CELL:
		goal = open_cell if open_cell != PathTargeter.NO_CELL else any_cell
		tier = 1
	else:
		for c: Vector3i in kept:
			if goal == PathTargeter.NO_CELL or absi(c.z) < absi(goal.z) \
					or (absi(c.z) == absi(goal.z) and int(reach[c]) < int(reach[goal])):
				goal = c
				tier = 2
	if kept.is_empty():
		var best_d := 0
		var best_f := 0
		var best_cost := 0
		var own_d := mini(mini(own.x, own.y), mini(field.width - 1 - own.x, field.length - 1 - own.y))
		for c: Vector3i in reach:
			var cost := int(reach[c])
			var d := mini(mini(c.x, c.y), mini(field.width - 1 - c.x, field.length - 1 - c.y))
			if d >= own_d:
				continue
			var f := absi(c.z)
			if goal != PathTargeter.NO_CELL and (d > best_d or (d == best_d and (f > best_f
					or (f == best_f and cost >= best_cost)))):
				continue
			if not _goal_ok(c, reach, merc, state):
				continue
			goal = c
			tier = 3
			best_d = d
			best_f = f
			best_cost = cost
	return {"goal": goal, "tier": tier}


static func _goal_ok(cell: Vector3i, reach: Dictionary, merc: MercenaryData, state: BattleState) -> bool:
	if not reach.has(cell) or int(reach[cell]) >= PathTargeter.JUMP_COST_OFFSET:
		return false
	return PathHelper.is_goal_passable(cell, state.battlefield, PathTargeter.fall_tolerance(merc), true,
			int(merc.stats.get("size", 1)), PathTargeter.is_flying(merc), state.get_height(merc), state, merc)


static func _foe_beside(cell: Vector3i, foe_cells: Array[Vector3i]) -> bool:
	for p: Vector3i in foe_cells:
		if p.z == cell.z and maxi(absi(p.x - cell.x), absi(p.y - cell.y)) <= 1:
			return true
	return false


static func escaping_bonus(enemy: MercenaryData, state: BattleState) -> float:
	if state == null or not is_fleeing(enemy):
		return 0.0
	if not AuraTactics.is_aura_source(enemy) and not state.priority_targets.has(enemy):
		return 0.0
	return minf(1.25, 0.5 + 0.05 * float(enemy.flee_escape_paces))


static func pursuit_paces(enemy: MercenaryData, state: BattleState) -> float:
	return escaping_bonus(enemy, state) * float(_CONFIG.flee_pursuit_paces)


static func has_better_quarry(cur: MercenaryData, valid: Array, state: BattleState) -> bool:
	if state == null:
		return false
	var own := escaping_bonus(cur, state)
	for other: Variant in valid:
		if other is MercenaryData and other != cur and escaping_bonus(other as MercenaryData, state) > own:
			return true
	return false


static func clear_merc(merc: MercenaryData) -> void:
	if is_flee_terrified(merc):
		ConstStates.remove_state(merc, ConstStates.TERRIFIED)
	merc.off_field = false
	merc.flee_intent = false
	forced.erase(merc)
	merc.flee_abandons = false
	merc.flee_escape_paces = 0
	merc.advantage_immune = false
