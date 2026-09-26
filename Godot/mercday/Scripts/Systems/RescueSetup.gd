class_name RescueSetup extends RefCounted

#Builds the rescue map state: the cell room, the gear chest and the captor roles.


#Caged captive, stripped gear, enemy roles and the stealth start; returns the pre-battle lines.
static func attach(state: BattleState, captive: MercenaryData, mode: String, difficulty: float) -> Array[String]:
	var lines: Array[String] = []
	if state == null or captive == null or state.battlefield == null:
		push_warning("RescueSystem.attach: missing state, captive or battlefield")
		return lines
	var field: BattlefieldArea = state.battlefield
	var stealth: bool = mode == RescueSystem.MODE_STEALTH
	var room: Dictionary = _pick_room(field, RescueSystem.CELL_ROOM)
	if room.is_empty():
		room = _pick_room(field, RescueSystem.STORAGE_ROOM)
	if room.is_empty():
		push_warning("RescueSystem.attach: the dungeon has no cell room")
		return lines
	state.teams[0].erase(captive)
	state.turn_queue.erase(captive)
	state._merc_team_index.erase(captive)
	var cell_rect: Rect2i = room.get("rect", Rect2i()) as Rect2i
	var cell_floor: int = int(room.get("floor", 0))
	var inside: Array[Vector3i] = RescueGrid.free_cells(field, state, cell_rect, cell_floor, captive)
	var captive_cell: Vector3i = Vector3i(cell_rect.position.x, cell_rect.position.y, cell_floor)
	if not inside.is_empty():
		captive_cell = inside[randi() % inside.size()]
	state.set_pos3(captive, captive_cell)
	var gate: Dictionary = RescueSystem.find_gate(field, cell_rect, cell_floor)
	var gate_obs: Dictionary = gate.get("obs", {}) as Dictionary
	var gate_cell: Vector3i = gate.get("cell", PathTargeter.NO_CELL) as Vector3i
	if not gate_obs.is_empty():
		gate_obs[DungeonLocks.KEEP_SHUT_KEY] = true
	var chest: Dictionary = _choose_chest(field, state, cell_rect, cell_floor)
	var chest_obs: Dictionary = chest.get("obs", {}) as Dictionary
	var chest_cell: Vector3i = chest.get("cell", PathTargeter.NO_CELL) as Vector3i
	var taken: Array[Dictionary] = ChestLoot.strip_gear(captive)
	for entry: Dictionary in taken:
		ChestLoot.add(chest_obs, entry)
	var exit_cell: Vector3i = PathTargeter.NO_CELL
	if not field.entrance_cells.is_empty():
		var door: Vector2i = field.entrance_cells[0] as Vector2i
		exit_cell = Vector3i(door.x, door.y, 0)
	state.rescue = {
		"mode": mode,
		"difficulty": difficulty,
		"captive": captive,
		"cell_rect": cell_rect,
		"cell_floor": cell_floor,
		"gate_cell": gate_cell,
		"gate_obs": gate_obs,
		"chest_cell": chest_cell,
		"chest_obs": chest_obs,
		"exit_cell": exit_cell,
		"picker": null,
		"roles": {},
		"patrol_goals": {},
		"wander_goal": {},
		"waits": {},
		"alarm": false,
		"alarm_round": 0,
		"freed": false,
		"freed_round": 0,
		"captive_exited": false,
		"exit_round": 0,
		"resolved": false,
		"result": "",
		"loot_taken": 0,
		"loot_restored": 0,
		"picks": 0,
		"pick_fails": 0,
		"chest_given_up": false,
		"done": false,
		"gate_go": false,
		"gate_eval_round": 0,
		"gate_hopeless": false,
		"escort": null,
		"hide_goal": PathTargeter.NO_CELL,
		"abandoned": false,
		"postures": {},
		"withdraw_said": {},
		"order_said": {},
		"exit_dist": {},
		"gate_dist": {},
		"go_count": 0,
		"stay_count": 0,
		"gate_runs": 0,
		"escort_turns": 0,
		"withdraw_turns": 0,
		"fall_back_turns": 0,
		"captive_rule": 0,
		"shelter_turns": 0,
		"hide_turns": 0,
		"door_opens": 0,
		"party_exits": 0,
		"block_waits": {},
		"block_wait_turns": 0,
		"detours": 0,
		"ambushes": 0,
		"aborted": false,
		"captive_acted": false,
		"acted_round": 0,
		"reason": "",
	}
	if exit_cell != PathTargeter.NO_CELL:
		state.rescue["exit_dist"] = DungeonGenerator._walk_dist(field, exit_cell, true)
	if gate_cell != PathTargeter.NO_CELL:
		state.rescue["gate_dist"] = DungeonGenerator._walk_dist(field, gate_cell, true)
	var roles: Array[String] = []
	if stealth:
		roles = _assign_roles(state)
		RescueStealth.start_hidden(state)
	state.rescue["picker"] = RescueSystem.best_picker(state)
	lines.append("RESCUE: mode %s, difficulty %.1f, captive %s in the cell at (%d,%d) F%d" % [
		mode, difficulty, captive.merc_name, captive_cell.x, captive_cell.y, captive_cell.z])
	lines.append("CAPTIVE: %s stripped of %d item(s) into the chest at (%d,%d) F%d" % [
		captive.merc_name, taken.size(), chest_cell.x, chest_cell.y, chest_cell.z])
	if gate_obs.is_empty():
		lines.append("GATE: none, the cell is open")
	else:
		lines.append("GATE: (%d,%d) F%d locked difficulty %d" % [
			gate_cell.x, gate_cell.y, gate_cell.z, DungeonLocks.lock_difficulty(gate_obs)])
	lines.append("EXIT: (%d,%d) F0" % [exit_cell.x, exit_cell.y])
	if not roles.is_empty():
		lines.append("ROLES: %s" % ", ".join(roles))
	state.pre_battle_lines.append_array(lines)
	return lines


static func _pick_room(field: BattlefieldArea, room_name: String) -> Dictionary:
	var rooms: Array[Dictionary] = RescueSystem.rooms_named(field, room_name)
	if rooms.is_empty():
		return {}
	return rooms[randi() % rooms.size()]


#Storage chest first, any chest outside the cell second, otherwise one is placed.
static func _choose_chest(field: BattlefieldArea, state: BattleState, rect: Rect2i, f: int) -> Dictionary:
	var best: Dictionary = {}
	var fallback: Dictionary = {}
	for obs: Dictionary in ChestLoot.chests(field):
		var cell: Vector3i = obs.get("pos", PathTargeter.NO_CELL) as Vector3i
		if cell == PathTargeter.NO_CELL:
			continue
		if cell.z == f and rect.has_point(Vector2i(cell.x, cell.y)):
			continue
		var room_name: String = RescueSystem.room_name_at(field, cell)
		if room_name == RescueSystem.FOYER_ROOM:
			continue
		if room_name == RescueSystem.STORAGE_ROOM and best.is_empty():
			best = {"obs": obs, "cell": cell}
		elif fallback.is_empty():
			fallback = {"obs": obs, "cell": cell}
	if not best.is_empty():
		return best
	if not fallback.is_empty():
		return fallback
	return _place_chest(field, state, rect, f)


#Drops a chest into a room away from the cell when the dungeon has none.
static func _place_chest(field: BattlefieldArea, state: BattleState, rect: Rect2i, f: int) -> Dictionary:
	var data: ObstacleData = DataManager.get_obstacle_by_name(RescueSystem.CHEST_NAME)
	if data == null:
		push_warning("RescueSystem: no Chest obstacle row; the captive gear is lost")
		return {}
	var spots: Array[Vector3i] = []
	for room: Dictionary in field.interior_rooms:
		var name: String = str(room.get("name", ""))
		if name == RescueSystem.CELL_ROOM or name == RescueSystem.FOYER_ROOM:
			continue
		var rf: int = int(room.get("floor", 0))
		var rr: Rect2i = room.get("rect", Rect2i()) as Rect2i
		if rf == f and rr == rect:
			continue
		spots.append_array(RescueGrid.free_cells(field, state, rr, rf, null))
	if spots.is_empty():
		push_warning("RescueSystem: no free cell for the chest")
		return {}
	var cell: Vector3i = spots[randi() % spots.size()]
	var obs: Dictionary = {"pos": cell, "size": 1, "data": data, "cell_type": "furniture",
		"pw": 1, "ph": 1, "floor": cell.z}
	InteriorGenerator._add_obstacle(field, obs, cell)
	field.los_version += 1
	field.bump_path_version()
	MovementExecutor.clear_caches()
	return {"obs": obs, "cell": cell}


#Gives every enemy a station and a job; returns the ROLES line parts.
static func _assign_roles(state: BattleState) -> Array[String]:
	var out: Array[String] = []
	var rescue: Dictionary = state.rescue
	var field: BattlefieldArea = state.battlefield
	var roles: Dictionary = rescue["roles"]
	var patrol_goals: Dictionary = rescue["patrol_goals"]
	var rect: Rect2i = rescue["cell_rect"] as Rect2i
	var enemies: Array = RescueSystem.enemy_team(state)
	var rest: int = 0
	for i: int in range(enemies.size()):
		var enemy: MercenaryData = enemies[i] as MercenaryData
		var role: String = RescueSystem.ROLE_WANDER
		var spot: Vector3i = PathTargeter.NO_CELL
		if i == 0:
			role = RescueSystem.ROLE_GUARD
			spot = RescueSystem.free_cell_near(state, rescue["gate_cell"] as Vector3i, 2, rect)
		elif i == 1 and enemies.size() >= 3:
			role = RescueSystem.ROLE_CHEST
			spot = RescueSystem.free_cell_near(state, rescue["chest_cell"] as Vector3i, 2, rect)
		else:
			role = RescueSystem.ROLE_WANDER if rest % 2 == 0 else RescueSystem.ROLE_PATROL
			rest += 1
			var room: Dictionary = _random_open_room(field, rect)
			if not room.is_empty():
				var cells: Array[Vector3i] = RescueGrid.free_cells(field, state, room.get("rect", Rect2i()) as Rect2i,
					int(room.get("floor", 0)), null)
				if not cells.is_empty():
					spot = cells[randi() % cells.size()]
		if spot != PathTargeter.NO_CELL:
			state.set_pos3(enemy, spot)
		roles[enemy] = role
		if role == RescueSystem.ROLE_PATROL:
			patrol_goals[enemy] = _patrol_pair(state, rect)
		out.append("%s %s" % [enemy.merc_name, role])
	return out


static func _patrol_pair(state: BattleState, rect: Rect2i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var field: BattlefieldArea = state.battlefield
	for _i: int in range(2):
		var room: Dictionary = _random_open_room(field, rect)
		if room.is_empty():
			continue
		var cells: Array[Vector3i] = RescueGrid.free_cells(field, state, room.get("rect", Rect2i()) as Rect2i,
			int(room.get("floor", 0)), null)
		if cells.is_empty():
			continue
		out.append(cells[randi() % cells.size()])
	return out


static func _random_open_room(field: BattlefieldArea, rect: Rect2i) -> Dictionary:
	var rooms: Array[Dictionary] = []
	for room: Dictionary in field.interior_rooms:
		var name: String = str(room.get("name", ""))
		if name == RescueSystem.CELL_ROOM or name == RescueSystem.FOYER_ROOM:
			continue
		if (room.get("rect", Rect2i()) as Rect2i) == rect:
			continue
		rooms.append(room)
	if rooms.is_empty():
		return {}
	return rooms[randi() % rooms.size()]
