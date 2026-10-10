class_name RescueSystem extends RefCounted

#Rescue the Captive: a caged merc, a stealth approach through a roused dungeon and the gear chest.

const EVENT_NAME := "Rescue the Captive"
const MODE_COMBAT := "combat"
const MODE_STEALTH := "stealth"
const RESULT_STEALTH := "stealth"
const RESULT_COMBAT := "combat"
const RESULT_FAILED := "failed"
const STATE_HIDDEN := "Hidden"
const CELL_ROOM := "Dungeon Cell"
const FOYER_ROOM := "Dungeon Foyer"
const STORAGE_ROOM := "Dungeon Storage"
const CHEST_NAME := "Chest"
const ROLE_GUARD := "guard"
const ROLE_CHEST := "chest"
const ROLE_WANDER := "wander"
const ROLE_PATROL := "patrol"
const MAX_WAITS := 3
const MOVES_PER_TURN := 2
const BLOCK_WAITS := 3
const CALL_GO := "go"
const CALL_WAIT := "wait"
const CALL_DETOUR := "detour"
const CALL_AMBUSH := "ambush"
const CALL_ABORT := "abort"


static func is_active(state: BattleState) -> bool:
	return state != null and not state.rescue.is_empty()


#True while the freed captive keeps to its cell and has neither struck nor taken gear: no enemy may target it.
static func shelters(state: BattleState, merc: MercenaryData) -> bool:
	if state == null or merc == null or state.rescue.is_empty():
		return false
	var rescue: Dictionary = state.rescue
	if merc != (rescue["captive"] as MercenaryData):
		return false
	if not bool(rescue["freed"]) or bool(rescue.get("captive_acted", false)):
		return false
	on_turn_reset(merc, state)
	if bool(rescue.get("captive_acted", false)):
		return false
	var own: Vector3i = state.pos3(merc)
	var rect: Rect2i = rescue["cell_rect"] as Rect2i
	return own.z == int(rescue["cell_floor"]) and rect.has_point(Vector2i(own.x, own.y))


#Latches the captive as a target for the rest of the battle.
static func mark_acted(state: BattleState, why: String) -> void:
	if state == null or state.rescue.is_empty():
		return
	var rescue: Dictionary = state.rescue
	if bool(rescue.get("captive_acted", false)):
		return
	rescue["captive_acted"] = true
	if EncounterLogger.is_active():
		var captive: MercenaryData = rescue["captive"] as MercenaryData
		EncounterLogger.log_verbose("RESCUE: %s has acted (%s) and can be targeted from now on" % [
			captive.merc_name, why])


#Chest gear in the captive's hands ends its shelter.
static func on_gear_taken(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	if state == null or merc == null or state.rescue.is_empty():
		return
	var rescue: Dictionary = state.rescue
	if merc != (rescue["captive"] as MercenaryData) or bool(rescue.get("captive_acted", false)):
		return
	mark_acted(state, "took gear")
	lines.append("  %s has taken gear and can be targeted from now on." % BattleState.colored_name(merc, state))


#Called just before a merc's attack counters reset: an attack by the captive ends its shelter.
static func on_turn_reset(merc: MercenaryData, state: BattleState) -> void:
	if state == null or merc == null or state.rescue.is_empty():
		return
	var rescue: Dictionary = state.rescue
	if merc == (rescue["captive"] as MercenaryData) and bool(rescue["freed"]) and merc.turn_attack_total > 0:
		mark_acted(state, "attacked")


#True when the rescue drives this merc's turn instead of the normal decision loop.
static func start_of_turn(merc: MercenaryData, state: BattleState, lines: Array[String]) -> bool:
	if merc == null or not is_active(state):
		return false
	var rescue: Dictionary = state.rescue
	if bool(rescue["done"]) or merc.off_field:
		return false
	var captive: MercenaryData = rescue["captive"] as MercenaryData
	var stealth: bool = str(rescue["mode"]) == MODE_STEALTH
	var alarm: bool = bool(rescue["alarm"])
	var team: int = int(state._merc_team_index.get(merc, -1))
	var exit_cell: Vector3i = rescue["exit_cell"] as Vector3i
	if team == 0 and exit_cell != PathTargeter.NO_CELL and state.pos3(merc) == exit_cell \
			and RescueTactics.may_leave(merc, state):
		RescueDirector.leave(merc, state, lines)
		return true
	if merc == captive and not bool(rescue["freed"]):
		return true
	if stealth and not alarm:
		if team == 1:
			return true
		if team == 0 and ConstStates.has_state(merc, STATE_HIDDEN):
			return true
	elif team == 0:
		RescueTactics.track_odds(state)
		if merc == picker(state):
			RescueTactics.evaluate_gate(state, lines)
		if RescueTactics.withdraw_enabled or (RescueTactics.careful and merc == captive):
			RescueTactics.set_posture(merc, state, lines)
		if RescueTactics.takes_turn(merc, state):
			return true
	return _chest_run_due(merc, state)


#True when the freed captive should run for the chest: gear is still to take and the careful rule allows it.
static func _chest_run_due(merc: MercenaryData, state: BattleState) -> bool:
	var rescue: Dictionary = state.rescue
	if merc != (rescue["captive"] as MercenaryData) or not bool(rescue["freed"]) or needs(state) <= 0:
		return false
	return not RescueTactics.careful or not RescueTactics.fighting(state) \
		or RescueTactics.captive_rule(state) == RescueTactics.RULE_CHEST_RUN


#Rescue-driven turn: creeping, patrolling, picking the gate or running for the chest.
static func run_turn(merc: MercenaryData, state: BattleState, lines: Array[String], enhancements: int) -> bool:
	if merc == null or not is_active(state) or merc.off_field:
		return false
	var rescue: Dictionary = state.rescue
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("RESCUE: %s acts under the rescue director (enh %d)" % [
			merc.merc_name, enhancements])
	var turn: Dictionary = AutoBattle.new_turn(merc, state)
	var captive: MercenaryData = rescue["captive"] as MercenaryData
	if merc == captive and not bool(rescue["freed"]):
		lines.append("  %s waits behind the bars." % BattleState.colored_name(merc, state))
		return true
	if int(state._merc_team_index.get(merc, -1)) == 1:
		RescueStealth.enemy_turn(merc, state, lines)
		return true
	if RescueTactics.fighting(state) and RescueDirector.run_director(merc, state, lines, enhancements, turn):
		return true
	if _chest_run_due(merc, state) and not _is_sneaking(merc, state):
		_chest_run(merc, state, lines, enhancements, turn)
		return true
	return _sneak_turn(merc, state, lines)


#Hook in the turn loop: a rescuer making a fighting withdrawal bends its chosen action toward the exit.
static func adjust_decision(merc: MercenaryData, decision: Dictionary, state: BattleState,
		turn: Dictionary, lines: Array[String]) -> Dictionary:
	if merc == null or not is_active(state) or bool(state.rescue["done"]):
		return decision
	if int(state._merc_team_index.get(merc, -1)) != 0:
		return decision
	if RescueTactics.posture_of(state, merc) != RescueTactics.POSTURE_FALL_BACK:
		return decision
	return RescueDirector.redirect(merc, decision, state, turn, lines)


#A live rescue keeps the battle running even while nobody attacks.
static func suspends_stalemate(state: BattleState) -> bool:
	if not is_active(state):
		return false
	return not bool(state.rescue["done"])


#Counts one Pick Lock attempt, rolls notice against the picker and opens the cell on success.
static func on_pick_attempt(merc: MercenaryData, obs: Dictionary, state: BattleState,
		lines: Array[String], success: bool) -> void:
	if not is_active(state):
		return
	var rescue: Dictionary = state.rescue
	rescue["picks"] = int(rescue["picks"]) + 1
	if not success:
		rescue["pick_fails"] = int(rescue["pick_fails"]) + 1
	if merc != null and not bool(rescue["alarm"]) and ConstStates.has_state(merc, STATE_HIDDEN):
		for enemy: MercenaryData in enemy_team(state):
			if not BattleState._is_alive(enemy):
				continue
			RescueStealth.sight_contest(state, enemy, merc, lines)
	if success and is_gate(state, obs) and int(state._merc_team_index.get(merc, 0)) == 0:
		free_captive(state, lines, merc, false)


#An Open/Close that opened the cell gate frees the captive.
static func on_gate_opened(state: BattleState, lines: Array[String]) -> void:
	if not is_active(state):
		return
	free_captive(state, lines, null, false)


static func enemy_team(state: BattleState) -> Array:
	if state == null or state.teams.size() < 2:
		return []
	return state.teams[1] as Array


static func captive_alive(captive: MercenaryData) -> bool:
	return captive != null and not captive.is_dead and captive.current_hp > 0


static func enemies_dead(state: BattleState) -> bool:
	for m: MercenaryData in enemy_team(state):
		if BattleState._is_alive(m):
			return false
	return true


static func team_wiped(state: BattleState) -> bool:
	if not is_active(state):
		return false
	var captive: MercenaryData = state.rescue["captive"] as MercenaryData
	if bool(state.rescue["freed"]) and captive_alive(captive):
		return false
	for m: MercenaryData in state.teams[0]:
		if m == captive:
			continue
		if not m.is_dead and m.current_hp > 0:
			return false
	return true


static func _is_sneaking(merc: MercenaryData, state: BattleState) -> bool:
	var rescue: Dictionary = state.rescue
	return str(rescue["mode"]) == MODE_STEALTH and not bool(rescue["alarm"]) \
		and ConstStates.has_state(merc, STATE_HIDDEN)


#Best odds on the gate itself; without a gate, the best Finesse roll on the team.
static func best_picker(state: BattleState) -> MercenaryData:
	var best: MercenaryData = null
	var best_score: float = -1.0
	var best_tie: float = -1.0
	var check: Dictionary = DungeonLocks.pick_def()
	var rescue: Dictionary = state.rescue
	var captive: MercenaryData = rescue.get("captive", null) as MercenaryData
	var gate_obs: Dictionary = rescue.get("gate_obs", {}) as Dictionary
	for m: MercenaryData in state.teams[0]:
		if m == captive or m.off_field or not BattleState._is_alive(m):
			continue
		var tie: float = CheckSystem.expected_successes(m, check)
		var score: float = tie
		if not gate_obs.is_empty():
			score = DungeonLocks.pick_chance(m, gate_obs)
		if score > best_score or (score == best_score and tie > best_tie):
			best_score = score
			best_tie = tie
			best = m
	return best


#The merc leading the approach; a dead or departed one hands the job to the next best.
static func picker(state: BattleState) -> MercenaryData:
	if not is_active(state):
		return null
	var rescue: Dictionary = state.rescue
	var held: MercenaryData = rescue.get("picker", null) as MercenaryData
	if held != null and BattleState._is_alive(held) and not held.off_field:
		return held
	var fresh: MercenaryData = best_picker(state)
	rescue["picker"] = fresh
	return fresh


#True when this merc should risk the jam rather than leave the lock to a better hand.
static func worth_picking(merc: MercenaryData, state: BattleState, obs: Dictionary) -> bool:
	if not DungeonLocks.can_pick(merc, state):
		return false
	if DungeonLocks.lock_fails(obs) >= DungeonLocks.MAX_JAM:
		return true
	var p_me: float = DungeonLocks.pick_chance(merc, obs)
	var captive: MercenaryData = null
	if is_active(state):
		captive = state.rescue.get("captive", null) as MercenaryData
	var best: MercenaryData = null
	var p_best: float = -1.0
	for m: MercenaryData in state.teams[0]:
		if m == merc or m == captive or m.off_field or not BattleState._is_alive(m):
			continue
		var p: float = DungeonLocks.pick_chance(m, obs)
		if p > p_best:
			p_best = p
			best = m
	if best == null:
		return true
	var p_after: float = DungeonLocks.pick_chance_at(best, DungeonLocks.lock_difficulty(obs) + 1)
	return p_me + (1.0 - p_me) * p_after >= p_best


#Cell of the rescue gate this merc should Interact with now, or NO_CELL.
static func gate_target(merc: MercenaryData, state: BattleState) -> Vector3i:
	if merc == null or not is_active(state):
		return PathTargeter.NO_CELL
	var rescue: Dictionary = state.rescue
	if bool(rescue["done"]) or bool(rescue["freed"]):
		return PathTargeter.NO_CELL
	var gate_obs: Dictionary = rescue["gate_obs"] as Dictionary
	if gate_obs.is_empty() or not DungeonLocks.is_locked(gate_obs):
		return PathTargeter.NO_CELL
	if int(state._merc_team_index.get(merc, -1)) != 0:
		return PathTargeter.NO_CELL
	if not RescueTactics.gate_wanted(state) or not RescueTactics.pick_first(merc, state):
		return PathTargeter.NO_CELL
	var gate_cell: Vector3i = rescue["gate_cell"] as Vector3i
	if not RescueGrid.is_adjacent(state.pos3(merc), gate_cell):
		return PathTargeter.NO_CELL
	if not worth_picking(merc, state, gate_obs):
		return PathTargeter.NO_CELL
	return gate_cell


#Cell the picker must stand beside: the gate, or the captive when the cell has no gate.
static func free_target_cell(state: BattleState) -> Vector3i:
	var rescue: Dictionary = state.rescue
	var gate_cell: Vector3i = rescue["gate_cell"] as Vector3i
	if gate_cell != PathTargeter.NO_CELL:
		return gate_cell
	var captive: MercenaryData = rescue["captive"] as MercenaryData
	if captive == null:
		return PathTargeter.NO_CELL
	return state.pos3(captive)


#True when this obstacle dict is the cell gate of the running rescue.
static func is_gate(state: BattleState, obs: Dictionary) -> bool:
	if not is_active(state):
		return false
	var rescue: Dictionary = state.rescue
	var gate_obs: Dictionary = rescue["gate_obs"] as Dictionary
	if obs.is_empty() or gate_obs.is_empty():
		return false
	if is_same(obs, gate_obs):
		return true
	return (obs.get("pos", PathTargeter.NO_CELL) as Vector3i) == (rescue["gate_cell"] as Vector3i)


#Opens the cell for good and puts the captive back on the team.
static func free_captive(state: BattleState, lines: Array[String], opener: MercenaryData,
		cleared: bool) -> void:
	var rescue: Dictionary = state.rescue
	if bool(rescue["freed"]):
		return
	var captive: MercenaryData = rescue["captive"] as MercenaryData
	if captive == null:
		return
	var gate_obs: Dictionary = rescue["gate_obs"] as Dictionary
	if not gate_obs.is_empty():
		DungeonLocks.open_door(gate_obs, state)
	rescue["freed"] = true
	rescue["freed_round"] = state.round_number
	if not state.teams[0].has(captive):
		state.teams[0].append(captive)
	state._merc_team_index[captive] = 0
	if not state.turn_queue.has(captive):
		state.turn_queue.append(captive)
	if cleared:
		lines.append("FREED: with the dungeon cleared, %s is free." % captive.merc_name)
	elif opener != null:
		lines.append("FREED: %s opens the cell; %s is free." % [opener.merc_name, captive.merc_name])
	else:
		lines.append("FREED: the cell is open; %s is free." % captive.merc_name)


#True when the chest holds at least one entry of this type ("weapon" or "ammo").
static func chest_has_type(chest_obs: Dictionary, entry_type: String) -> bool:
	for e: Dictionary in ChestLoot.entries(chest_obs):
		if str(e.get("type", "")) == entry_type:
			return true
	return false


#Entries the freed captive still wants out of the chest: a weapon, then ammo for it.
static func needs(state: BattleState) -> int:
	var rescue: Dictionary = state.rescue
	if bool(rescue.get("chest_given_up", false)):
		return 0
	var captive: MercenaryData = rescue["captive"] as MercenaryData
	var chest_obs: Dictionary = rescue["chest_obs"] as Dictionary
	if captive == null or chest_obs.is_empty() or ChestLoot.is_empty(chest_obs):
		return 0
	if RescueTactics.captive_armed(state):
		return 0
	var held: WeaponData = captive.equipped_weapon
	var wanted: String = "weapon" if held == null or held.is_virtual else "ammo"
	return 1 if chest_has_type(chest_obs, wanted) else 0


#A hidden rescuer's turn: creep to the gate, pick it, then walk the captive out. False hands the turn to the fight loop.
static func _sneak_turn(merc: MercenaryData, state: BattleState, lines: Array[String]) -> bool:
	var rescue: Dictionary = state.rescue
	var captive: MercenaryData = rescue["captive"] as MercenaryData
	var lead: MercenaryData = picker(state)
	var freed: bool = bool(rescue["freed"])
	var exit_cell: Vector3i = rescue["exit_cell"] as Vector3i
	var goal: Vector3i = PathTargeter.NO_CELL
	if merc == captive or freed or bool(rescue.get("aborted", false)):
		goal = exit_cell
	elif merc == lead:
		if try_free(merc, state, lines):
			return true
		goal = RescueGrid.approach_cell(merc, state)
	if goal == PathTargeter.NO_CELL or goal == state.pos3(merc):
		lines.append("  %s holds still in the dark." % BattleState.colored_name(merc, state))
		return true
	var call_name: String = RescueWalk.blocked_call(merc, state, goal, lines)
	if call_name == CALL_ABORT:
		RescueWalk.abort(state, lines)
		goal = exit_cell
		call_name = RescueWalk.blocked_call(merc, state, goal, lines)
	if call_name == CALL_WAIT:
		return true
	if call_name == CALL_AMBUSH:
		return false
	var walk: Dictionary = RescueWalk.hidden_moves(merc, state, goal, lines, true, MOVES_PER_TURN, call_name == CALL_DETOUR)
	var seen: Dictionary = walk["seen_by"]
	for key: Variant in seen.keys():
		if bool(rescue["alarm"]):
			break
		RescueStealth.contest(merc, key as MercenaryData, int(walk["unseen"]), state, lines)
	if merc == lead and not bool(rescue["freed"]) and not bool(rescue.get("aborted", false)):
		try_free(merc, state, lines)
	return true


#Opens the cell when the merc stands beside it; picks the lock when it is still locked.
static func try_free(merc: MercenaryData, state: BattleState, lines: Array[String]) -> bool:
	var rescue: Dictionary = state.rescue
	if bool(rescue["freed"]) or not RescueTactics.gate_wanted(state):
		return false
	if not RescueTactics.pick_first(merc, state):
		return false
	var target: Vector3i = free_target_cell(state)
	if target == PathTargeter.NO_CELL or not RescueGrid.is_adjacent(state.pos3(merc), target):
		return false
	var gate_obs: Dictionary = rescue["gate_obs"] as Dictionary
	if gate_obs.is_empty() or not DungeonLocks.is_locked(gate_obs):
		free_captive(state, lines, merc, false)
		return true
	if not worth_picking(merc, state, gate_obs):
		return false
	if not state.can_afford(merc, state.get_cost(merc, "Interact", 2)):
		return false
	InteractionSystem.perform(merc, gate_obs, rescue["gate_cell"] as Vector3i, state, lines)
	return true


#Cells under living enemies, keyed by cell with the enemy as value.
static func enemy_cells(state: BattleState) -> Dictionary:
	var out: Dictionary = {}
	for enemy: MercenaryData in enemy_team(state):
		if BattleState._is_alive(enemy):
			out[state.pos3(enemy)] = enemy
	return out


#The freed captive runs to the chest for a weapon and the ammo it needs.
static func _chest_run(merc: MercenaryData, state: BattleState, lines: Array[String],
		enhancements: int, turn: Dictionary) -> void:
	var rescue: Dictionary = state.rescue
	if bool(rescue.get("chest_given_up", false)):
		return
	var chest_obs: Dictionary = rescue["chest_obs"] as Dictionary
	var chest_cell: Vector3i = rescue["chest_cell"] as Vector3i
	if chest_obs.is_empty() or chest_cell == PathTargeter.NO_CELL:
		return
	if not RescueGrid.is_adjacent(state.pos3(merc), chest_cell):
		var goal: Vector3i = RescueGrid.adjacent_free_cell(state, chest_cell, merc)
		if goal == PathTargeter.NO_CELL:
			lines.append("  %s cannot reach the chest." % BattleState.colored_name(merc, state))
			return
		if RescueTactics.fighting(state):
			RescueDirector.travel(merc, state, goal, lines, enhancements, turn)
		else:
			RescueWalk.hidden_moves(merc, state, goal, lines, false, MOVES_PER_TURN)
		if not RescueGrid.is_adjacent(state.pos3(merc), chest_cell) and _jammed_beside(merc, state):
			rescue["chest_given_up"] = true
			lines.append("  %s gives up on the chest." % BattleState.colored_name(merc, state))
			return
	while needs(state) > 0 and RescueGrid.is_adjacent(state.pos3(merc), chest_cell):
		if not state.can_afford(merc, state.get_cost(merc, "Interact", 2)):
			break
		if not InteractionSystem.perform(merc, chest_obs, chest_cell, state, lines):
			break
		rescue["loot_taken"] = int(rescue["loot_taken"]) + 1


#A neighbouring lock jammed past saving, which this merc has no real chance of opening.
static func _jammed_beside(merc: MercenaryData, state: BattleState) -> bool:
	var field: BattlefieldArea = state.battlefield
	if field == null:
		return false
	var pos: Vector3i = state.pos3(merc)
	for d: Vector2i in PathCost.DIRS8:
		var obs: Dictionary = field.get_obs(Vector2i(pos.x + d.x, pos.y + d.y), pos.z)
		if obs.is_empty() or not DungeonLocks.is_locked(obs):
			continue
		if DungeonLocks.lock_fails(obs) >= DungeonLocks.MAX_JAM \
				and DungeonLocks.pick_chance(merc, obs) < 0.1:
			return true
	return false

