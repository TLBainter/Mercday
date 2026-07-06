class_name WireframeGenerator

const CELL: int = 16
const CELL_H: int = 8
const CELL_T: int = 5
const TITLE_H: int = 22
const EL_W: int = 80
const EL_GAP: int = 12

const C_OUTDOOR: String = "#8a9a72"
const C_STREET: String = "#c4bdb0"
const C_FLOOR: String = "#f4f0e4"
const C_WALL: String = "#2c2c30"
const C_CEILING: String = "#1a1a1e"
const C_STAIRWELL: String = "#e8e4d8"
const C_DOOR_FRAME: String = "#404044"
const C_SPAWN_A: String = "#b8ccee"
const C_SPAWN_B: String = "#eedcc8"
const C_PILLAR: String = "#606068"
const C_TABLE: String = "#8a6020"
const C_STAIR_OBS: String = "#907050"
const C_FURNITURE: String = "#6a6880"
const C_VEG: String = "#4a7a30"
const C_TERRAIN: String = "#6a7888"
const C_HATCH: String = "#aaaaaa"
const C_LABEL: String = "#336699"
const C_WINDOW_GLASS: String = "#b8d8e8"
const C_TITLE_BG: String = "#2a2a30"
const C_TITLE_FG: String = "#f0f0e8"
const C_ROOM_LABEL: String = "#555566"
const C_FENCE: String = "#6a5030"


static func save(field: BattlefieldArea, path_stem: String) -> void:
	if field == null:
		return
	var svg := _build_svg(field)
	var f := FileAccess.open(path_stem + ".svg", FileAccess.WRITE)
	if f == null:
		push_warning("WireframeGenerator: could not write %s.svg" % path_stem)
		return
	f.store_string(svg)
	f.close()


static func _build_svg(field: BattlefieldArea) -> String:
	var plan_w: int = field.width * CELL
	var plan_h: int = field.length * CELL
	var yremap: Dictionary = {}
	var yremap_bot: Dictionary = {}

	if field.is_interior_map:
		var fh: int = field.interior_floor_depth if field.interior_floor_depth > 0 else field.interior_floor_height
		var ty: int = field.interior_top_y if field.interior_top_y > 0 else 3
		var sorted_floors: Array = field.interior_floor_elevations.keys()
		sorted_floors.sort_custom(func(a: Variant, b: Variant) -> bool:
			return (field.interior_floor_elevations[a] as int) < (field.interior_floor_elevations[b] as int))
		var num_floors: int = sorted_floors.size()
		for k: int in range(num_floors):
			var f_key: Variant = sorted_floors[k]
			var elev: int = field.interior_floor_elevations[f_key] as int
			for r: int in range(ty - 1, ty + fh + 3):
				yremap[elev + r] = k * (fh + 4) * CELL + (r - ty + 1) * CELL
			yremap_bot[elev + ty + fh + 1] = k * (fh + 4) * CELL + (fh + 2) * CELL
		if num_floors > 0:
			plan_h = num_floors * (fh + 4) * CELL

	var el_block: int = EL_GAP + EL_W
	var total_w: int = plan_w + (el_block if field.is_interior_map else 0)
	var total_h: int = plan_h + TITLE_H
	var parts: Array[String] = []

	parts.append('<?xml version="1.0" encoding="UTF-8"?>')
	parts.append('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d">' % [total_w, total_h])

	var type_str: String = "INTERIOR" if field.is_interior_map else "EXTERIOR"
	parts.append('<rect width="%d" height="%d" fill="%s"/>' % [total_w, TITLE_H, C_TITLE_BG])
	parts.append('<text x="8" y="15" font-size="11" font-family="monospace" font-weight="bold" fill="%s">%s - %s</text>' % [
		C_TITLE_FG, type_str, field.area_name])
	parts.append('<text x="%d" y="15" font-size="9" font-family="monospace" fill="#8888aa" text-anchor="end">%dx%d</text>' % [
		total_w - 6, field.width, field.length])

	parts.append('<g transform="translate(0,%d)">' % TITLE_H)

	var bg: String = C_STREET if field.is_interior_map else C_OUTDOOR
	parts.append(_bg(plan_w, plan_h, bg))

	if field.is_interior_map:
		_layer_interior(field, parts, yremap, yremap_bot)
		_elevation_strip(field, parts, plan_w + EL_GAP, plan_h)
	else:
		_layer_exterior(field, parts)

	parts.append('</g>')
	parts.append('</svg>')
	return "\n".join(parts)


static func _vy(real_y: int, yremap: Dictionary) -> int:
	return yremap.get(real_y, real_y * CELL)


static func _frp(px: int, py: int, color: String) -> String:
	return '<rect x="%d" y="%d" width="%d" height="%d" fill="%s"/>' % [px, py, CELL, CELL, color]


static func _frap(px: int, py: int, color: String, alpha: float) -> String:
	return '<rect x="%d" y="%d" width="%d" height="%d" fill="%s" fill-opacity="%.2f"/>' % [px, py, CELL, CELL, color, alpha]


static func _layer_interior(field: BattlefieldArea, parts: Array[String], yremap: Dictionary, yremap_bot: Dictionary) -> void:
	for p: Variant in field.building_interiors.keys():
		var pos := p as Vector3i
		var elev: int = field.interior_floor_elevations.get(pos.z, 0) as int
		var svg_y: int = _vy(elev + pos.y, yremap)
		if not field.ceiling_cells.has(p) and not field.stairwell_cells.has(p):
			parts.append(_frp(pos.x * CELL, svg_y, C_FLOOR))

	for p: Variant in field.ceiling_cells.keys():
		var pos := p as Vector3i
		var elev: int = field.interior_floor_elevations.get(pos.z, 0) as int
		if not field.stairwell_cells.has(p):
			var py1: int = _vy(elev + pos.y, yremap)
			parts.append(_frp(pos.x * CELL, py1, C_CEILING))
			if yremap_bot.has(elev + pos.y):
				var py2: int = yremap_bot[elev + pos.y]
				if py2 != py1:
					parts.append(_frp(pos.x * CELL, py2, C_CEILING))

	for p: Variant in field.stairwell_cells.keys():
		var pos := p as Vector3i
		var elev: int = field.interior_floor_elevations.get(pos.z, 0) as int
		var py1: int = _vy(elev + pos.y, yremap)
		parts.append(_frp(pos.x * CELL, py1, C_STAIRWELL))
		_hatchp(pos.x * CELL, py1, parts)
		if yremap_bot.has(elev + pos.y):
			var py2: int = yremap_bot[elev + pos.y]
			if py2 != py1:
				parts.append(_frp(pos.x * CELL, py2, C_STAIRWELL))
				_hatchp(pos.x * CELL, py2, parts)

	_spawn_overlays(field, parts, yremap)
	_obstacles(field, parts, yremap, yremap_bot)
	_room_labels(field, parts, yremap)

	for f_num: Variant in field.interior_floor_elevations.keys():
		var elev: int = field.interior_floor_elevations[f_num] as int
		parts.append('<text x="2" y="%d" font-size="9" font-family="monospace" fill="%s">F%d</text>' % [
			_vy(elev, yremap) + 11, C_LABEL, f_num as int])

	_stairwell_connectors(field, parts, yremap, yremap_bot)


static func _layer_exterior(field: BattlefieldArea, parts: Array[String]) -> void:
	for p: Variant in field.jagged_cells.keys():
		parts.append(_fr(p as Vector2i, "#3a3a3a"))

	for p: Variant in field.building_interiors.keys():
		var px: int = (p as Vector2i).x if typeof(p) == TYPE_VECTOR2I else (p as Vector3i).x
		var py: int = (p as Vector2i).y if typeof(p) == TYPE_VECTOR2I else (p as Vector3i).y
		parts.append(_frp(px * CELL, py * CELL, C_FLOOR))

	_spawn_overlays(field, parts, {})
	_obstacles(field, parts, {}, {})


static func _spawn_overlays(field: BattlefieldArea, parts: Array[String], yremap: Dictionary) -> void:
	for p: Variant in field.spawn_zone_a.keys():
		var pos := p as Vector2i
		parts.append(_frap(pos.x * CELL, _vy(pos.y, yremap), C_SPAWN_A, 0.55))
	for p: Variant in field.spawn_zone_b.keys():
		var pos := p as Vector2i
		parts.append(_frap(pos.x * CELL, _vy(pos.y, yremap), C_SPAWN_B, 0.55))


static func _obstacles(field: BattlefieldArea, parts: Array[String], yremap: Dictionary, yremap_bot: Dictionary = {}) -> void:
	for obs: Dictionary in field.obstacles:
		var _raw_pos = obs["pos"]
		var pos: Vector3i = _raw_pos as Vector3i if typeof(_raw_pos) == TYPE_VECTOR3I else Vector3i((_raw_pos as Vector2i).x, (_raw_pos as Vector2i).y, 0)
		var px: int = pos.x * CELL
		var elev: int = field.interior_floor_elevations.get(pos.z, 0) as int if field.is_interior_map else 0
		var py: int = _vy(elev + pos.y, yremap)
		var ct: String = obs.get("cell_type", "")
		var d: ObstacleData = obs.get("data") as ObstacleData
		var dname: String = (d.obstacle_name if d != null else "").to_lower()
		var dtype: String = (d.obstacle_type if d != null else "").to_lower()
		var orient: String = obs.get("orientation", "v")

		var at_ceiling: bool = field.is_interior_map and yremap_bot.has(elev + pos.y)
		var py_bot: int = (yremap_bot[elev + pos.y] as int) if at_ceiling else py
		var dual: bool = at_ceiling and py_bot != py

		if ct == "wall":
			parts.append(_frp(px, py, C_WALL))
			if dual:
				parts.append(_frp(px, py_bot, C_WALL))
		elif ct == "window":
			_windowp(px, py, orient, parts)
			if dual:
				_windowp(px, py_bot, orient, parts)
		elif ct == "door":
			_doorp(px, py, orient, parts)
		elif ct == "stairs" or dname.contains("stair"):
			if field.is_interior_map:
				parts.append(_frp(px, py, C_FLOOR))
			_stair_obsp(px, py, parts)
		elif dname.contains("pillar"):
			if field.is_interior_map:
				parts.append(_frp(px, py, C_FLOOR))
			_pillarp(px, py, parts)
		elif dname.contains("table"):
			if field.is_interior_map:
				parts.append(_frp(px, py, C_FLOOR))
			_tablep(px, py, parts)
		elif dname.contains("bench") or dname.contains("stool") or dname.contains("chair"):
			if field.is_interior_map:
				parts.append(_frp(px, py, C_FLOOR))
			_small_furnp(px, py, parts)
		elif ct == "fence":
			if field.is_interior_map:
				parts.append(_frp(px, py, C_FLOOR))
			_fencep(px, py, orient, parts)
		elif dtype == "vegetation":
			_vegetationp(px, py, parts)
		else:
			if field.is_interior_map:
				parts.append(_frp(px, py, C_FLOOR))
			_generic_furnp(px, py, dtype, parts)


static func _room_labels(field: BattlefieldArea, parts: Array[String], yremap: Dictionary) -> void:
	for entry: Dictionary in field.interior_rooms:
		var rect: Rect2i = entry["rect"] as Rect2i
		var name: String = entry["name"] as String
		if rect.size.x < 2 or rect.size.y < 2:
			continue
		var elev: int = field.interior_floor_elevations.get(entry["floor"], 0) as int
		var cx: int = rect.position.x * CELL + (rect.size.x * CELL >> 1)
		var cy: int = _vy(elev + rect.position.y, yremap) + (rect.size.y * CELL >> 1)
		parts.append('<text x="%d" y="%d" font-size="8" font-family="monospace" fill="%s" text-anchor="middle" dominant-baseline="middle">%s</text>' % [
			cx, cy, C_ROOM_LABEL, name])


static func _stairwell_connectors(field: BattlefieldArea, parts: Array[String], yremap: Dictionary, yremap_bot: Dictionary) -> void:
	for p: Variant in field.stairwell_cells.keys():
		var pos: Vector3i = p as Vector3i
		var elev: int = field.interior_floor_elevations.get(pos.z, 0) as int
		if not yremap_bot.has(elev + pos.y):
			continue
		var gap_start: int = (yremap_bot[elev + pos.y] as int) + CELL
		var gap_end: int = _vy(elev + pos.y, yremap)
		if gap_end <= gap_start:
			continue
		var cx: int = pos.x * CELL + (CELL >> 1)
		parts.append('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#888888" stroke-width="1" stroke-dasharray="2,2"/>' % [
			cx, gap_start, cx, gap_end])


static func _elevation_strip(field: BattlefieldArea, parts: Array[String], x0: int, plan_h: int) -> void:
	var fh: int = field.interior_floor_depth if field.interior_floor_depth > 0 else field.interior_floor_height
	var ty: int = field.interior_top_y if field.interior_top_y > 0 else 3
	var left_w: int = (EL_W - CELL) >> 1
	var right_w: int = EL_W - left_w - CELL
	var gap_x: int = x0 + left_w

	parts.append('<rect x="%d" y="0" width="%d" height="%d" fill="%s"/>' % [x0, EL_W, plan_h, C_STREET])

	var stair_elevs: Dictionary = {}
	for p: Variant in field.stairwell_cells.keys():
		var pos := p as Vector3i
		var elev: int = field.interior_floor_elevations.get(pos.z, 0) as int
		stair_elevs[elev + pos.y] = true

	var max_elev: int = 0
	var first_floor := true
	for f_num: Variant in field.interior_floor_elevations.keys():
		var f: int = f_num as int
		var elev: int = field.interior_floor_elevations[f_num] as int
		if first_floor or elev > max_elev:
			max_elev = elev
			first_floor = false

		var sorted_keys: Array = field.interior_floor_elevations.keys()
		sorted_keys.sort_custom(func(a: Variant, b: Variant) -> bool:
			return (field.interior_floor_elevations[a] as int) < (field.interior_floor_elevations[b] as int))
		var fi: int = sorted_keys.find(f_num)
		var svg_floor_top: int = fi * (fh + 4) * CELL
		parts.append('<rect x="%d" y="%d" width="%d" height="%d" fill="%s"/>' % [
			x0, svg_floor_top + CELL, EL_W, fh * CELL, C_FLOOR])

		var wall_y: int = svg_floor_top
		if stair_elevs.has(elev):
			parts.append('<rect x="%d" y="%d" width="%d" height="%d" fill="%s"/>' % [x0, wall_y, left_w, CELL, C_WALL])
			parts.append('<rect x="%d" y="%d" width="%d" height="%d" fill="%s"/>' % [gap_x + CELL, wall_y, right_w, CELL, C_WALL])
			parts.append('<rect x="%d" y="%d" width="%d" height="4" fill="%s"/>' % [gap_x, wall_y + 12, CELL, C_STAIR_OBS])
			parts.append('<rect x="%d" y="%d" width="11" height="4" fill="%s"/>' % [gap_x + 5, wall_y + 7, C_STAIR_OBS])
			parts.append('<rect x="%d" y="%d" width="6" height="4" fill="%s"/>' % [gap_x + 10, wall_y + 2, C_STAIR_OBS])
		else:
			parts.append('<rect x="%d" y="%d" width="%d" height="%d" fill="%s"/>' % [x0, wall_y, EL_W, CELL, C_WALL])

		parts.append('<text x="%d" y="%d" font-size="9" font-family="monospace" fill="%s">F%d</text>' % [
			x0 + 4, svg_floor_top + CELL + 11, C_LABEL, f])

	var sorted_elev_keys: Array = field.interior_floor_elevations.keys()
	sorted_elev_keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		return (field.interior_floor_elevations[a] as int) < (field.interior_floor_elevations[b] as int))
	var last_fi: int = sorted_elev_keys.size() - 1
	var bot_svg_y: int = last_fi * (fh + 4) * CELL + (fh + 2) * CELL
	if stair_elevs.has(max_elev + ty + fh + 1):
		parts.append('<rect x="%d" y="%d" width="%d" height="%d" fill="%s"/>' % [x0, bot_svg_y, left_w, CELL, C_WALL])
		parts.append('<rect x="%d" y="%d" width="%d" height="%d" fill="%s"/>' % [gap_x + CELL, bot_svg_y, right_w, CELL, C_WALL])
	else:
		parts.append('<rect x="%d" y="%d" width="%d" height="%d" fill="%s"/>' % [x0, bot_svg_y, EL_W, CELL, C_WALL])


static func _windowp(px: int, py: int, orient: String, parts: Array[String]) -> void:
	parts.append('<rect x="%d" y="%d" width="%d" height="%d" fill="%s"/>' % [px, py, CELL, CELL, C_WALL])
	if orient == "v":
		parts.append('<rect x="%d" y="%d" width="6" height="%d" fill="%s"/>' % [px + 5, py + 3, CELL - 6, C_WINDOW_GLASS])
	else:
		parts.append('<rect x="%d" y="%d" width="%d" height="6" fill="%s"/>' % [px + 3, py + 5, CELL - 6, C_WINDOW_GLASS])


static func _doorp(px: int, py: int, orient: String, parts: Array[String]) -> void:
	parts.append('<rect x="%d" y="%d" width="%d" height="%d" fill="%s"/>' % [px, py, CELL, CELL, C_FLOOR])
	if orient == "h":
		parts.append('<rect x="%d" y="%d" width="%d" height="3" fill="%s"/>' % [px, py, CELL_T, C_DOOR_FRAME])
		parts.append('<rect x="%d" y="%d" width="%d" height="3" fill="%s"/>' % [px + CELL - CELL_T, py, CELL_T, C_DOOR_FRAME])
		parts.append('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="%s" stroke-width="1.5"/>' % [
			px, py + 3, px + CELL, py + 3, C_DOOR_FRAME])
		parts.append('<path d="M %d,%d A %d,%d 0 0,1 %d,%d" fill="none" stroke="%s" stroke-width="1"/>' % [
			px + CELL_T, py + 3, CELL - CELL_T * 2, CELL - CELL_T * 2,
			px + CELL - CELL_T, py + CELL - CELL_T + 3, C_DOOR_FRAME])
	else:
		parts.append('<rect x="%d" y="%d" width="3" height="%d" fill="%s"/>' % [px, py, CELL_T, C_DOOR_FRAME])
		parts.append('<rect x="%d" y="%d" width="3" height="%d" fill="%s"/>' % [px, py + CELL - CELL_T, CELL_T, C_DOOR_FRAME])
		parts.append('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="%s" stroke-width="1.5"/>' % [
			px + 3, py, px + 3, py + CELL, C_DOOR_FRAME])
		parts.append('<path d="M %d,%d A %d,%d 0 0,0 %d,%d" fill="none" stroke="%s" stroke-width="1"/>' % [
			px + 3, py + CELL_T, CELL - CELL_T * 2, CELL - CELL_T * 2,
			px + CELL - CELL_T + 3, py + CELL - CELL_T, C_DOOR_FRAME])


static func _fencep(px: int, py: int, orient: String, parts: Array[String]) -> void:
	if orient == "v":
		parts.append('<rect x="%d" y="%d" width="%d" height="%d" fill="%s"/>' % [px + 6, py, 4, CELL, C_FENCE])
	else:
		parts.append('<rect x="%d" y="%d" width="%d" height="%d" fill="%s"/>' % [px, py + 6, CELL, 4, C_FENCE])


static func _pillarp(px: int, py: int, parts: Array[String]) -> void:
	var m: int = 4
	parts.append('<rect x="%d" y="%d" width="%d" height="%d" fill="%s" stroke="%s" stroke-width="1"/>' % [
		px + m, py + m, CELL - m * 2, CELL - m * 2, C_PILLAR, C_WALL])


static func _stair_obsp(px: int, py: int, parts: Array[String]) -> void:
	parts.append('<rect x="%d" y="%d" width="16" height="6" fill="%s"/>' % [px, py + 10, C_STAIR_OBS])
	parts.append('<rect x="%d" y="%d" width="11" height="5" fill="%s"/>' % [px + 5, py + 5, C_STAIR_OBS])
	parts.append('<rect x="%d" y="%d" width="6" height="5" fill="%s"/>' % [px + 10, py, C_STAIR_OBS])


static func _tablep(px: int, py: int, parts: Array[String]) -> void:
	parts.append('<rect x="%d" y="%d" width="12" height="10" fill="%s" stroke="%s" stroke-width="0.5"/>' % [
		px + 2, py + 3, C_TABLE, "#5a3a10"])


static func _small_furnp(px: int, py: int, parts: Array[String]) -> void:
	parts.append('<rect x="%d" y="%d" width="7" height="7" fill="%s"/>' % [px + 4, py + 4, "#7a5520"])


static func _vegetationp(px: int, py: int, parts: Array[String]) -> void:
	parts.append('<ellipse cx="%d" cy="%d" rx="6" ry="6" fill="%s" stroke="#2a5820" stroke-width="0.5"/>' % [
		px + CELL_H, py + CELL_H, C_VEG])


static func _generic_furnp(px: int, py: int, dtype: String, parts: Array[String]) -> void:
	var fill: String = C_TERRAIN if dtype == "terrain" else C_FURNITURE
	parts.append('<rect x="%d" y="%d" width="10" height="10" fill="%s" stroke="%s" stroke-width="0.5"/>' % [
		px + 3, py + 3, fill, C_WALL])


static func _hatchp(px: int, py: int, parts: Array[String]) -> void:
	parts.append('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="%s" stroke-width="1"/>' % [
		px, py, px + CELL, py + CELL, C_HATCH])
	parts.append('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="%s" stroke-width="1"/>' % [
		px + CELL, py, px, py + CELL, C_HATCH])


static func _fr(pos: Vector2i, color: String) -> String:
	return '<rect x="%d" y="%d" width="%d" height="%d" fill="%s"/>' % [
		pos.x * CELL, pos.y * CELL, CELL, CELL, color]


static func _fra(pos: Vector2i, color: String, alpha: float) -> String:
	return '<rect x="%d" y="%d" width="%d" height="%d" fill="%s" fill-opacity="%.2f"/>' % [
		pos.x * CELL, pos.y * CELL, CELL, CELL, color, alpha]


static func _bg(w: int, h: int, color: String) -> String:
	return '<rect width="%d" height="%d" fill="%s"/>' % [w, h, color]
