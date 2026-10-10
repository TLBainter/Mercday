class_name DungeonLocks

#Locked doors: the barred cell gates and the doors of a locked Storage or Armory room.
#Sight passes the bars, movement does not.

const LOCKED_KEY := "locked"
const BARS_KEY := "bars"
const DIFFICULTY_KEY := "lock_difficulty"
const FAILS_KEY := "lock_fails"
const KEYED_KEY := "keyed"
const KEEP_SHUT_KEY := "keep_shut"
const ROOM_KEY := "lock_room"

#Failed picks that still jam the lock; beyond it the failures are counted and nothing more.
const MAX_JAM := 3

#Reasons a party merc may pick a locked door; every other locked door is a wall to it.
const REASON_WAY_OUT := "way_out"
const REASON_ENEMY_INSIDE := "enemy_inside"
const REASON_UNKNOWN_ROOM := "unknown_room"

#[field id, path_version, door_version] and the locked door rows built for it; one field at a time.
static var _door_key: Array = []
static var _door_rows: Array[Dictionary] = []
#MercenaryData -> the wanted signature last written to the log, and the log file it went to.
static var _wanted_log: Dictionary = {}
static var _log_stem: String = ""


static func is_locked(obs: Dictionary) -> bool:
	return obs.get(LOCKED_KEY, false) as bool


static func has_bars(obs: Dictionary) -> bool:
	return obs.get(BARS_KEY, false) as bool


static func lock_difficulty(obs: Dictionary) -> int:
	return int(obs.get(DIFFICULTY_KEY, 0))


static func lock_fails(obs: Dictionary) -> int:
	return int(obs.get(FAILS_KEY, 0))


#True unless a writer says the captors carry no key for this door.
static func is_keyed(obs: Dictionary) -> bool:
	return obs.get(KEYED_KEY, true) as bool


#True when the captors keep this door shut whatever key they hold.
static func keep_shut(obs: Dictionary) -> bool:
	return obs.get(KEEP_SHUT_KEY, false) as bool


#A failed attempt jams the lock one step further, up to MAX_JAM; returns the new difficulty.
static func fail(obs: Dictionary) -> int:
	var fails := lock_fails(obs)
	obs[FAILS_KEY] = fails + 1
	if fails < MAX_JAM:
		obs[DIFFICULTY_KEY] = lock_difficulty(obs) + 1
	return lock_difficulty(obs)


static func unlock(obs: Dictionary) -> void:
	obs[LOCKED_KEY] = false


#Unlocks and opens a door, then refreshes the door-dependent caches.
static func open_door(obs: Dictionary, state: BattleState) -> void:
	unlock(obs)
	OpenCloseState.set_open(obs, true)
	state.on_door_changed()


#Lock difficulty of every cell gate in a dungeon of contract Difficulty d.
static func lock_difficulty_for(d: float) -> int:
	return maxi(1, floori(d - 1.0))


static func bar_door_template() -> ObstacleData:
	var row: ObstacleData = DataManager.get_obstacle_by_name("Iron Bar Door")
	if row == null:
		push_error("DungeonLocks: no 'Iron Bar Door' row in Obstacles.tsv")
	return row


#Finesse check a merc rolls against the lock difficulty.
static func pick_def() -> Dictionary:
	var know: Array[String] = []
	for k: Variant in (DataManager.knowledge_categories.get("ESPIONAGE", []) as Array):
		know.append(String(k))
	return {"stat_keys": ["dexterity"], "circumstances": [ConstCircumstances.FINESSE_DEXTERITY],
		"knowledges": know, "tools": ["Locksmith's"], "formula": "luck", "flat_threshold_bonus": 0.0}


#Odds this merc beats a lock of that difficulty on one attempt.
static func pick_chance_at(merc: MercenaryData, difficulty: int) -> float:
	if merc == null:
		return 0.0
	return CheckSystem.expected_success_chance(merc, pick_def(), difficulty)


static func pick_chance(merc: MercenaryData, obs: Dictionary) -> float:
	if obs.is_empty():
		return 0.0
	return pick_chance_at(merc, lock_difficulty(obs))


#Only the party picks locks; the captors carry keys instead.
static func can_pick(merc: MercenaryData, state: BattleState) -> bool:
	if state == null:
		return false
	return int(state._merc_team_index.get(merc, -1)) == 0


#Team 1 holds a key to every locked door of its own dungeon.
static func holds_keys(merc: MercenaryData, state: BattleState) -> bool:
	if state == null or state.battlefield == null or not state.battlefield.is_dungeon:
		return false
	return int(state._merc_team_index.get(merc, -1)) == 1


#True when this merc has some way through the door: unlocked, picked, or unlocked with a key.
static func can_open(merc: MercenaryData, obs: Dictionary, state: BattleState) -> bool:
	if not is_locked(obs):
		return true
	if can_pick(merc, state):
		return wanted_reason(merc, obs, PathTargeter.NO_CELL, state) != ""
	return holds_keys(merc, state) and is_keyed(obs) and not keep_shut(obs)


#One pick attempt: opens the door on a pass, jams it further on a fail. The Interact charges the AP.
static func attempt_pick(merc: MercenaryData, obs: Dictionary, state: BattleState,
		lines: Array[String]) -> bool:
	if merc == null or obs.is_empty() or state == null:
		return false
	var oname := InteractionSystem.obstacle_name(obs)
	var need := lock_difficulty(obs)
	var roll := CheckSystem.make_check(merc, pick_def())
	var success: bool = bool(roll["critical"]) or int(roll["successes"]) >= need
	if success:
		open_door(obs, state)
		lines.append("  %s picks the lock on the %s. (AP: %d)" % [
			BattleState.colored_name(merc, state), oname, merc.current_ap])
	else:
		lines.append("  %s fails to pick the lock on the %s (difficulty now %d). (AP: %d)" % [
			BattleState.colored_name(merc, state), oname, fail(obs), merc.current_ap])
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("PICK LOCK: %s vs %d -> %d success(es)%s [%dAP]" % [
			merc.merc_name, need, int(roll["successes"]),
			" CRIT" if bool(roll["critical"]) else "", state.get_cost(merc, "Interact", 2)])
	RescueSystem.on_pick_attempt(merc, obs, state, lines, success)
	return success


#A captor turns its key: the door unlocks and swings open.
static func key_open(merc: MercenaryData, obs: Dictionary, state: BattleState,
		lines: Array[String]) -> bool:
	if merc == null or obs.is_empty() or state == null:
		return false
	open_door(obs, state)
	lines.append("  %s unlocks the %s with a key. (AP: %d)" % [
		BattleState.colored_name(merc, state), InteractionSystem.obstacle_name(obs), merc.current_ap])
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("KEY: %s unlocks %s" % [
			merc.merc_name, InteractionSystem.obstacle_name(obs)])
	return true


#Cuts a shut, locked bar door into the cell and returns the stored dict.
static func place_bar_door(area: BattlefieldArea, pos: Vector3i, fh: int, orientation: String,
		difficulty: float, room: Dictionary = {}) -> Dictionary:
	var template: ObstacleData = bar_door_template()
	if template == null:
		return {}
	InteriorGenerator.place_door_at(area, pos, template, fh, orientation)
	var obs: Dictionary = lock_door(area, pos, difficulty, room)
	if not obs.is_empty():
		obs[BARS_KEY] = true
	return obs


#Locks a door already placed on the map, at the cell gate difficulty and with no bars.
static func lock_door(area: BattlefieldArea, pos: Vector3i, difficulty: float,
		room: Dictionary = {}) -> Dictionary:
	var obs: Dictionary = area._obs_map.get(pos, {}) as Dictionary
	if obs.is_empty():
		return obs
	obs[LOCKED_KEY] = true
	obs[DIFFICULTY_KEY] = lock_difficulty_for(difficulty)
	obs[FAILS_KEY] = 0
	obs[KEYED_KEY] = true
	if not room.is_empty():
		obs[ROOM_KEY] = room
	return obs


#Odds a Storage or Armory room is locked in a dungeon of contract Difficulty d.
static func lock_chance(d: float) -> float:
	return clampf(0.2 * d, 0.0, 1.0)


#Cell the door was stored at; NO_CELL when the obstacle carries no Vector3i position.
static func door_cell(obs: Dictionary) -> Vector3i:
	var raw: Variant = obs.get("pos")
	if raw is Vector3i:
		return raw as Vector3i
	return PathTargeter.NO_CELL


#The room this locked door guards as {rect, floor, name}; {} when no room can be named.
static func room_of(field: BattlefieldArea, obs: Dictionary,
		cell: Vector3i = PathTargeter.NO_CELL) -> Dictionary:
	var stored: Dictionary = obs.get(ROOM_KEY, {}) as Dictionary
	if not stored.is_empty():
		return stored
	if field == null:
		return {}
	var at: Vector3i = cell if cell != PathTargeter.NO_CELL else door_cell(obs)
	if at == PathTargeter.NO_CELL:
		return {}
	var fallback: Dictionary = {}
	for entry: Dictionary in field.interior_rooms:
		var f: int = int(entry.get("floor", 0))
		if f != at.z:
			continue
		var rect: Rect2i = entry.get("rect", Rect2i()) as Rect2i
		if not rect.grow(1).has_point(Vector2i(at.x, at.y)):
			continue
		var row: Dictionary = {"rect": rect, "floor": f, "name": String(entry.get("name", ""))}
		if DungeonGenerator.locked_room(field, rect, f):
			return row
		if fallback.is_empty():
			fallback = row
	return fallback


#Every locked door on the field as {"obs", "cell"} rows; a pick bumps door_version and drops it.
static func locked_doors(field: BattlefieldArea) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if field == null:
		return out
	var key: Array = [field.get_instance_id(), field.path_version, field.door_version]
	if _door_key == key:
		return _door_rows
	for raw: Variant in field._obs_map.keys():
		if not (raw is Vector3i):
			continue
		var obs: Dictionary = field._obs_map[raw] as Dictionary
		if obs.get("cell_type", "") != "door" or not is_locked(obs):
			continue
		out.append({"obs": obs, "cell": raw as Vector3i})
	_door_key = key
	_door_rows = out
	return out


#True when the merc stands inside the room rect on the room floor.
static func _stands_in(state: BattleState, merc: MercenaryData, rect: Rect2i, f: int) -> bool:
	if merc == null or not state.positions.has(merc):
		return false
	var p: Vector3i = state.pos3(merc)
	return p.z == f and rect.has_point(Vector2i(p.x, p.y))


#Why this party merc may pick the locked door; "" leaves the door a wall for it.
static func wanted_reason(merc: MercenaryData, obs: Dictionary, cell: Vector3i,
		state: BattleState) -> String:
	if merc == null or state == null or not is_locked(obs) or not can_pick(merc, state):
		return ""
	var rescue: String = RescueDoors.reason(merc, obs, state)
	if rescue == RescueDoors.BLOCKED_GATE:
		return ""
	if rescue != "":
		return rescue
	var room: Dictionary = room_of(state.battlefield, obs, cell)
	if room.is_empty():
		return REASON_UNKNOWN_ROOM
	var rect: Rect2i = room.get("rect", Rect2i()) as Rect2i
	var f: int = int(room.get("floor", 0))
	if _stands_in(state, merc, rect, f):
		return REASON_WAY_OUT
	for enemy: MercenaryData in state.get_enemies(merc):
		if _stands_in(state, enemy, rect, f):
			return REASON_ENEMY_INSIDE
	return ""


#One verbose line per merc whenever its wanted set changes; a new log file starts a new battle.
static func log_wanted(merc: MercenaryData, reasons: PackedStringArray) -> void:
	if merc == null or not EncounterLogger.is_active():
		return
	var stem := EncounterLogger.current_log_path()
	if stem != _log_stem:
		_log_stem = stem
		_wanted_log.clear()
	var sig := "; ".join(reasons)
	if _wanted_log.has(merc) and String(_wanted_log[merc]) == sig:
		return
	_wanted_log[merc] = sig
	EncounterLogger.log_verbose("LOCKS: %s wants %s" % [merc.merc_name, "none" if sig == "" else sig])


#Pace a router adds to a locked door: the extra Interacts this merc expects to spend on the pick.
static func plan_lock_penalty(merc: MercenaryData, field: BattlefieldArea) -> int:
	if merc == null or field == null:
		return 0
	var p: float = maxf(0.05, pick_chance_at(merc, lock_difficulty_for(field.dungeon_difficulty)))
	var extra: int = clampi(int(ceil(1.0 / p)) - 1, 0, 4)
	return extra * PathCost.door_penalty(merc)
