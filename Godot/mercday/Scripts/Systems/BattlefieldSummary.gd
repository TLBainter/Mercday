class_name BattlefieldSummary
extends RefCounted


#Summary lines of a generated battlefield: size, obstacle counts and the cavern, city or building block.
static func lines(field: BattlefieldArea) -> PackedStringArray:
	var out := PackedStringArray()
	out.append("--- Battlefield Generation ---")
	out.append("Dimensions: %dx%d (height %d)  Cover: %s" % [
		field.width, field.length, field.height,
		BattlefieldArea.COVER_AMOUNT_NAMES[field.cover_amount]])
	var wall_count := 0
	var door_count := 0
	var passthrough_count := 0
	var damaging_count := 0
	var other_count := 0
	for obs: Dictionary in field.obstacles:
		var ct: String = obs.get("cell_type", "")
		if ct == "wall":
			wall_count += 1
		elif ct == "door":
			door_count += 1
		else:
			var d: ObstacleData = obs.get("data") as ObstacleData
			if d != null and d.passthrough:
				if d.pt_enter_harm > 0 or d.pt_exit_harm > 0:
					damaging_count += 1
				else:
					passthrough_count += 1
			else:
				other_count += 1
	out.append("Obstacles: %d total  walls=%d  doors=%d  passthrough=%d  damaging=%d  solid=%d" % [
		field.obstacles.size(), wall_count, door_count, passthrough_count, damaging_count, other_count])
	if field.is_cavern:
		var pools := 0
		for ch: Dictionary in field.cavern_chambers:
			if ch.get("flooded", false) as bool:
				pools += 1
		out.append("Cavern: chambers=%d tunnels=%d entrances=%d pools=%d scatters=%d" % [
			field.cavern_chambers.size(), field.cavern_tunnels.size(),
			_cavern_entrance_count(field), pools, field.obstacles.size() - wall_count])
	elif field.is_city:
		out.append_array(city_lines(field))
	elif field.is_interior_map:
		var ifp: Rect2i = field.building_footprint
		out.append("Buildings: interior  footprint=(%d,%d) %dx%d (shell walls included) mask=%d cells" % [
			ifp.position.x, ifp.position.y, ifp.size.x, ifp.size.y, field.footprint_union.size()])
	elif field.building_data.is_empty():
		out.append("Buildings: none (0 placed exterior buildings)")
	else:
		for i: int in range(field.building_data.size()):
			var b: Dictionary = field.building_data[i]
			var rect: Rect2i = b["rect"] as Rect2i
			var door_positions: Array = b.get("door_positions", [])
			var door_parts: Array[String] = []
			for dp in door_positions:
				var v: Vector2i = dp
				door_parts.append("(%d,%d)" % [v.x, v.y])
			out.append("Building %d [%s]: pos=(%d,%d) size=%dx%d  doors=%d at %s" % [
				i + 1, b.get("name", "?"),
				rect.position.x, rect.position.y, rect.size.x, rect.size.y,
				door_positions.size(), ", ".join(door_parts)])
	out.append("---")
	out.append("---")
	return out


#The two city summary lines of a generation block; readable without an open log file.
static func city_lines(field: BattlefieldArea) -> PackedStringArray:
	var city: Dictionary = field.city
	var stats: Dictionary = city.get("stats", {})
	var spawn: Dictionary = city.get("spawn", {})
	var out := PackedStringArray()
	out.append(("City: tier=%s mains=%d sides=%d alleys=%d dead_ends=%d plots=%d/%d/%d lots=%d buildings=%d failed_lots=%d "
			+ "back_lanes=%d street_objects=%d nature_objects=%d nature=%d%% tries=%d alley_ring=%d alley_conn=%d "
			+ "connectors=%d isolated=%d connect_d=%d") % [
		String(city.get("tier", "")), int(stats.get("mains", 0)), int(stats.get("sides", 0)),
		int(stats.get("alleys", 0)), int(stats.get("dead_ends", 0)),
		int(stats.get("plots_large", 0)), int(stats.get("plots_medium", 0)),
		int(stats.get("plots_small", 0)), int(stats.get("lots", 0)), int(stats.get("buildings", 0)),
		int(stats.get("failed_lots", 0)), int(stats.get("back_lanes", 0)),
		int(stats.get("street_objects", 0)), int(stats.get("nature_objects", 0)),
		int(round(float(stats.get("nature_pct", 0.0)))), int(city.get("tries", 0)),
		int(stats.get("alley_ring_cells", 0)), int(stats.get("alley_connector_cells", 0)),
		int(stats.get("alley_connectors", 0)), int(stats.get("alley_isolated", 0)),
		int(stats.get("alley_connect_d", 0))])
	out.append(("City spawn: A side=%d outdoor=%d zone=%d buildings=%d posts=%d; "
			+ "B side=%d outdoor=%d zone=%d buildings=%d posts=%d") % [
		int(spawn.get("side_a", 0)), int(spawn.get("outdoor_a", 0)), field.spawn_zone_a.size(),
		(spawn.get("buildings_a", []) as Array).size(), CitySpawns.window_posts(field, 0).size(),
		int(spawn.get("side_b", 0)), int(spawn.get("outdoor_b", 0)), field.spawn_zone_b.size(),
		(spawn.get("buildings_b", []) as Array).size(), CitySpawns.window_posts(field, 1).size()])
	return out


#Entrance tunnels carved to the border; falls back to the border cell count.
static func _cavern_entrance_count(field: BattlefieldArea) -> int:
	var n := 0
	for t: Dictionary in field.cavern_tunnels:
		if str(t.get("kind", "")) == "entrance":
			n += 1
	return n if n > 0 else field.entrance_cells.size()
