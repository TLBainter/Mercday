class_name ObstacleUtils

static var _tag_rx: RegEx = null


#Callers pass display names that may carry BBCode; verbose log lines must stay plain text.
static func _plain(text: String) -> String:
	if _tag_rx == null:
		_tag_rx = RegEx.new()
		_tag_rx.compile("\\[[^\\]]*\\]")
	return _tag_rx.sub(text, "", true)


static func get_hp(obs_data: ObstacleData) -> int:
	match obs_data.obstacle_type:
		"Vegetation", "Furniture":
			return maxi(2, obs_data.size)
		"Terrain":
			return maxi(4, obs_data.size * 2)
		_:
			return maxi(3, obs_data.size)


static func apply_damage(obs_cell: Dictionary, damage: int, state: BattleState,
		attacker_name: String = "") -> Dictionary:
	var obs_data: ObstacleData = obs_cell.get("data") as ObstacleData
	var obs_name: String = obs_data.obstacle_name if obs_data != null else "obstacle"
	var obs_hp_max: int = get_hp(obs_data) if obs_data != null else 1
	if not obs_cell.has("current_hp"):
		obs_cell["current_hp"] = obs_hp_max
	var lines: Array[String] = []
	if damage <= 0:
		if not attacker_name.is_empty():
			lines.append("  %s strikes %s but deals no damage." % [attacker_name, obs_name])
		return {"damage": 0, "hp_remaining": int(obs_cell["current_hp"]), "destroyed": false,
				"drop_pos": Vector2i(-1, -1), "drop_name": "", "lines": lines}
	obs_cell["current_hp"] = maxi(0, int(obs_cell["current_hp"]) - damage)
	var hp_remaining: int = int(obs_cell["current_hp"])
	_log_hit(attacker_name, obs_name, damage, hp_remaining, obs_hp_max, lines)
	var drop_pos := Vector2i(-1, -1)
	var drop_name := ""
	var destroyed := false
	if hp_remaining <= 0:
		var raw_opos = obs_cell.get("pos", Vector2i.ZERO)
		var obs_pos := BattlefieldArea.cell_of(raw_opos)
		var obs_floor := BattlefieldArea.floor_of(raw_opos, int(obs_cell.get("floor", 0)))
		if obs_cell.get("cell_type", "") == "window" or obs_name == "Window":
			_shatter_window(obs_cell, obs_pos, obs_floor, state, lines)
		else:
			var drop: Dictionary = _spawn_drop(obs_data, obs_name, obs_pos, state, lines)
			drop_name = str(drop["name"])
			drop_pos = drop["pos"] as Vector2i
			_remove_obstacle(obs_cell, raw_opos, obs_pos, obs_floor, obs_data, state)
			lines.append("  %s is destroyed!" % obs_name)
			lines.append("  %s collapses  -  terrain at %s cleared." % [obs_name, str(obs_pos)])
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("  %s is destroyed!" % obs_name)
			destroyed = true
	return {"damage": damage, "hp_remaining": hp_remaining, "destroyed": destroyed,
			"drop_pos": drop_pos, "drop_name": drop_name, "lines": lines}


static func _log_hit(attacker_name: String, obs_name: String, damage: int, hp_remaining: int,
		obs_hp_max: int, lines: Array[String]) -> void:
	var text := "  %s attacks %s! [%d] -> %d/%d"
	if not attacker_name.is_empty():
		lines.append(text % [attacker_name, obs_name, damage, hp_remaining, obs_hp_max])
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose(text % [_plain(attacker_name), obs_name, damage, hp_remaining, obs_hp_max])


static func _shatter_window(obs_cell: Dictionary, obs_pos: Vector2i, obs_floor: int,
		state: BattleState, lines: Array[String]) -> void:
	var shattered: bool = state.battlefield.break_window(obs_pos, obs_floor)
	if not shattered and not (obs_cell.get("broken", false) as bool):
		obs_cell["broken"] = true
		state.battlefield.los_version += 1
		state.battlefield.bump_path_version()
		shattered = true
	if shattered:
		lines.append("  The Window shatters! Broken glass remains.")
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("  Window at %s shatters" % str(obs_pos))


#Rolls one of the obstacle's drops onto its cell; "name" is the roll, "pos" stays (-1,-1) with no template.
static func _spawn_drop(obs_data: ObstacleData, obs_name: String, obs_pos: Vector2i,
		state: BattleState, lines: Array[String]) -> Dictionary:
	var out := {"name": "", "pos": Vector2i(-1, -1)}
	if obs_data == null or obs_data.drops.is_empty():
		return out
	var drop_name: String = obs_data.drops[randi() % obs_data.drops.size()]
	out["name"] = drop_name
	var drop_tmpl: WeaponData = DataManager.makeshift_weapons.get(drop_name) as WeaponData
	if drop_tmpl == null:
		return out
	var drop_inst := WeaponData.duplicate_template(drop_tmpl)
	out["pos"] = obs_pos
	if not state.dropped_weapons.has(obs_pos):
		state.dropped_weapons[obs_pos] = []
	(state.dropped_weapons[obs_pos] as Array).append({
		"weapon": drop_inst, "ammo_loaded": 0, "ammo_loaded_type": ""
	})
	lines.append("  A %s breaks loose!" % drop_name)
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("  DROP: %s at %s from %s" % [drop_name, str(obs_pos), obs_name])
	return out


static func _remove_obstacle(obs_cell: Dictionary, raw_opos: Variant, obs_pos: Vector2i,
		obs_floor: int, obs_data: ObstacleData, state: BattleState) -> void:
	state.battlefield.obstacles.erase(obs_cell)
	var dupes: Array = []
	for other: Dictionary in state.battlefield.obstacles:
		if other.get("pos") == raw_opos and other.get("data") == obs_data:
			dupes.append(other)
	for other: Dictionary in dupes:
		state.battlefield.obstacles.erase(other)
	state.battlefield._obs_map.erase(raw_opos)
	state.battlefield.los_version += 1
	state.battlefield.droppable_obs_map.erase(Vector3i(obs_pos.x, obs_pos.y, obs_floor))
	state.battlefield.terrain_heights[obs_pos] = 0.0
	state.battlefield.bump_path_version()
