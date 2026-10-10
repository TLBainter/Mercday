class_name ObstacleUtils

static var _tag_rx: RegEx = null


#Callers pass display names that may carry BBCode; verbose log lines must stay plain text.
static func _plain(text: String) -> String:
	if _tag_rx == null:
		_tag_rx = RegEx.new()
		_tag_rx.compile("\\[[^\\]]*\\]")
	return _tag_rx.sub(text, "", true)


#Sheet Health wins; rows that leave it blank fall back to the size of their type.
static func get_hp(obs_data: ObstacleData) -> int:
	if obs_data.health > 0:
		return obs_data.health
	match obs_data.obstacle_type:
		"Vegetation", "Furniture":
			return maxi(2, obs_data.size)
		"Terrain":
			return maxi(4, obs_data.size * 2)
		_:
			return maxi(3, obs_data.size)


#Immune To zeroes a damage type, Susceptible To doubles it; a list entry may name a type or its category.
static func damage_modifier(obs_data: ObstacleData, damage_type: String) -> float:
	if obs_data == null or damage_type == "":
		return 1.0
	if _type_listed(obs_data.immune_to, damage_type):
		return 0.0
	if _type_listed(obs_data.susceptible_to, damage_type):
		return 2.0
	return 1.0


static func _type_listed(list_text: String, damage_type: String) -> bool:
	if list_text.strip_edges() == "":
		return false
	var wanted := damage_type.to_lower()
	var category := str(ConstDamageTypes.get_type(damage_type).get("category", "")).to_lower()
	for entry: String in list_text.split(","):
		var token := entry.strip_edges().to_lower()
		if token == "":
			continue
		if token == wanted or (category != "" and token == category):
			return true
	return false


static func apply_damage(obs_cell: Dictionary, damage: int, state: BattleState,
		attacker_name: String = "", damage_type: String = "") -> Dictionary:
	var obs_data: ObstacleData = obs_cell.get("data") as ObstacleData
	var obs_name: String = obs_data.obstacle_name if obs_data != null else "obstacle"
	var obs_hp_max: int = int(obs_cell.get("hp_max", get_hp(obs_data) if obs_data != null else 1))
	if not obs_cell.has("current_hp"):
		obs_cell["current_hp"] = obs_hp_max
	var lines: Array[String] = []
	var result := {"damage": 0, "hp_remaining": int(obs_cell["current_hp"]), "destroyed": false,
			"drop_pos": Vector2i(-1, -1), "drop_name": "", "lines": lines}
	if damage <= 0:
		if not attacker_name.is_empty():
			lines.append("  %s strikes %s but deals no damage." % [attacker_name, obs_name])
		return result
	CaveInSystem.note_damage(state, damage_type, damage)
	var modifier := damage_modifier(obs_data, damage_type)
	if modifier == 0.0:
		lines.append("  %s strikes %s but %s does no harm to it." % [attacker_name, obs_name, damage_type])
		return result
	if modifier == 2.0:
		damage *= 2
	obs_cell["current_hp"] = maxi(0, int(obs_cell["current_hp"]) - damage)
	var hp_remaining: int = int(obs_cell["current_hp"])
	result["damage"] = damage
	result["hp_remaining"] = hp_remaining
	_log_hit(attacker_name, obs_name, damage, hp_remaining, obs_hp_max, lines)
	if hp_remaining <= 0:
		var raw_opos = obs_cell.get("pos", Vector2i.ZERO)
		var obs_pos := BattlefieldArea.cell_of(raw_opos)
		var obs_floor := BattlefieldArea.floor_of(raw_opos, int(obs_cell.get("floor", 0)))
		if obs_cell.get("rubble", false):
			if not CaveInSystem.pop_cube(obs_cell, state, lines):
				result["hp_remaining"] = int(obs_cell.get("current_hp", 0))
				return result
			remove_obstacle(obs_cell, raw_opos, obs_pos, obs_floor, obs_data, state)
			CaveInSystem.on_cell_cleared(obs_cell, obs_pos, state, lines)
			lines.append("  Rubble is cleared!")
			result["destroyed"] = true
		elif obs_cell.get("cell_type", "") == "window" or obs_name == "Window":
			_shatter_window(obs_cell, obs_pos, obs_floor, state, lines)
		else:
			var drop: Dictionary = _spawn_drop(obs_cell, obs_data, obs_name, obs_pos, state, lines)
			result["drop_name"] = str(drop["name"])
			result["drop_pos"] = drop["pos"] as Vector2i
			remove_obstacle(obs_cell, raw_opos, obs_pos, obs_floor, obs_data, state)
			var destroyed_line: String = "  %s is destroyed!" % obs_name
			lines.append(destroyed_line)
			lines.append("  %s collapses  -  terrain at %s cleared." % [obs_name, str(obs_pos)])
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose(destroyed_line)
			result["destroyed"] = true
	return result


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
#A cell that carries "drop_variant" skips the roll and drops that makeshift key instead.
static func _spawn_drop(obs_cell: Dictionary, obs_data: ObstacleData, obs_name: String, obs_pos: Vector2i,
		state: BattleState, lines: Array[String]) -> Dictionary:
	var out := {"name": "", "pos": Vector2i(-1, -1)}
	var drop_name: String = str(obs_cell.get("drop_variant", ""))
	if drop_name == "":
		if obs_data == null or obs_data.drops.is_empty():
			return out
		drop_name = obs_data.drops[randi() % obs_data.drops.size()]
	out["name"] = drop_name
	var drop_tmpl: WeaponData = DataManager.makeshift_weapons.get(drop_name) as WeaponData
	if drop_tmpl == null:
		return out
	var drop_inst := WeaponData.duplicate_template(drop_tmpl)
	out["name"] = drop_inst.item_name
	out["pos"] = obs_pos
	if not state.dropped_weapons.has(obs_pos):
		state.dropped_weapons[obs_pos] = []
	(state.dropped_weapons[obs_pos] as Array).append({
		"weapon": drop_inst, "ammo_loaded": 0, "ammo_loaded_type": ""
	})
	lines.append("  A %s breaks loose!" % drop_inst.item_name)
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("  DROP: %s at %s from %s" % [drop_name, str(obs_pos), obs_name])
	return out


static func remove_obstacle(obs_cell: Dictionary, raw_opos: Variant, obs_pos: Vector2i,
		obs_floor: int, obs_data: ObstacleData, state: BattleState) -> void:
	state.battlefield.remove_obstacle_at(obs_cell, raw_opos, obs_pos, obs_floor, obs_data)
	var roof_object: bool = bool(obs_cell.get("roof_object", false))
	state.battlefield.los_version += 1
	state.battlefield.droppable_obs_map.erase(Vector3i(obs_pos.x, obs_pos.y, obs_floor))
	if roof_object:
		#The roof plane keeps its own height table; the ground under the building is not touched.
		NavLinkBuilder.relink_after_obstacle_loss(state.battlefield, obs_cell)
		return
	if state.battlefield.is_cavern:
		state.battlefield.terrain_heights[obs_pos] = state.battlefield.ground_height(obs_pos)
		if bool(obs_cell.get("hanging", false)):
			state.battlefield.cavern_ceiling[obs_pos] = state.battlefield.ground_height(obs_pos) \
				+ float(obs_cell.get("restore_clearance", 0.0))
	else:
		state.battlefield.terrain_heights[obs_pos] = 0.0
	state.battlefield.bump_path_version()
