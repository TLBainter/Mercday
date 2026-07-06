class_name ObstacleUtils


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
	if not attacker_name.is_empty():
		lines.append("  %s attacks %s! [%d] -> %d/%d" % [attacker_name, obs_name, damage, hp_remaining, obs_hp_max])
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("  %s attacks %s! [%d] -> %d/%d" % [attacker_name, obs_name, damage, hp_remaining, obs_hp_max])
	var drop_pos := Vector2i(-1, -1)
	var drop_name := ""
	var destroyed := false
	if hp_remaining <= 0:
		var _raw_opos = obs_cell.get("pos", Vector2i.ZERO)
		var obs_pos: Vector2i = Vector2i((_raw_opos as Vector3i).x, (_raw_opos as Vector3i).y) if typeof(_raw_opos) == TYPE_VECTOR3I else _raw_opos as Vector2i
		var obs_cells: Array = obs_cell.get("cells", [])
		if obs_name == "Window":
			var broken: ObstacleData = DataManager.get_obstacle_by_name("Broken Window")
			if broken != null:
				obs_cell["data"] = broken
				obs_cell["size"] = broken.size
				obs_cell.erase("current_hp")
				lines.append("  The Window shatters! Broken glass remains.")
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("  Window at %s broken -> Broken Window" % str(obs_pos))
		else:
			if obs_data != null and not obs_data.drops.is_empty():
				drop_name = obs_data.drops[randi() % obs_data.drops.size()]
				var drop_tmpl: WeaponData = DataManager.makeshift_weapons.get(drop_name) as WeaponData
				if drop_tmpl != null:
					var drop_inst := WeaponData.new()
					drop_inst.item_name = drop_tmpl.item_name
					drop_inst.item_type = drop_tmpl.item_type
					drop_inst.item_rarity = drop_tmpl.item_rarity
					drop_inst.weapon_type = drop_tmpl.weapon_type
					drop_inst.damage_formula_1 = drop_tmpl.damage_formula_1
					drop_inst.damage_types_1 = drop_tmpl.damage_types_1.duplicate()
					drop_inst.is_ranged = drop_tmpl.is_ranged
					drop_inst.is_throwable = drop_tmpl.is_throwable
					drop_inst.has_heavy = drop_tmpl.has_heavy
					drop_inst.has_light = drop_tmpl.has_light
					drop_inst.has_extend = drop_tmpl.has_extend
					drop_inst.melee_range = drop_tmpl.melee_range
					drop_inst.range_thrown = drop_tmpl.range_thrown
					drop_inst.thrown_intended_range = drop_tmpl.thrown_intended_range
					drop_inst.thrown_extended_range = drop_tmpl.thrown_extended_range
					drop_inst.fragility = drop_tmpl.fragility
					drop_inst.current_fragility = drop_tmpl.fragility
					drop_pos = obs_pos
					if not state.dropped_weapons.has(obs_pos):
						state.dropped_weapons[obs_pos] = []
					(state.dropped_weapons[obs_pos] as Array).append({
						"weapon": drop_inst, "ammo_loaded": 0, "ammo_loaded_type": ""
					})
					lines.append("  A %s breaks loose!" % drop_name)
					if EncounterLogger.is_active():
						EncounterLogger.log_verbose("  DROP: %s at %s from %s" % [drop_name, str(obs_pos), obs_name])
			state.battlefield.obstacles.erase(obs_cell)
			var _dupes: Array = []
			for _o: Dictionary in state.battlefield.obstacles:
				if _o.get("pos") == _raw_opos and _o.get("data") == obs_data:
					_dupes.append(_o)
			for _o: Dictionary in _dupes:
				state.battlefield.obstacles.erase(_o)
			state.battlefield._obs_map.erase(_raw_opos)
			state.battlefield.droppable_obs_map.erase(obs_pos)
			MovementExecutor._near_passable_cache.clear()
			if obs_cells.is_empty():
				state.battlefield.terrain_heights[obs_pos] = 0.0
			else:
				for cell in obs_cells:
					state.battlefield.terrain_heights[cell as Vector2i] = 0.0
			lines.append("  %s is destroyed!" % obs_name)
			lines.append("  %s collapses  -  terrain at %s cleared." % [obs_name, str(obs_pos)])
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("  %s is destroyed!" % obs_name)
			destroyed = true
	return {"damage": damage, "hp_remaining": hp_remaining, "destroyed": destroyed,
			"drop_pos": drop_pos, "drop_name": drop_name, "lines": lines}
