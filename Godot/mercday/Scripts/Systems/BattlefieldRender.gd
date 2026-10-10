class_name BattlefieldRender


#Glyph key printed under every per-floor grid.
const MAP_LEGEND := "legend: . floor/street  # wall  D closed door (Interact)  d open door  W window  w broken window  S stair run  ^ stair landing  b balcony  f fence  ~ passthrough  * harmful passthrough  o obstacle  ! jagged  0/1 merc team"


static func to_header_string(area: BattlefieldArea) -> String:
	var b_str := " (%d building%s)" % [area.building_data.size(), "s" if area.building_data.size() != 1 else ""] \
		if not area.building_data.is_empty() else ""
	var loc := ("[%s] " % area.area_name) if area.area_name != "" else ""
	var f_str := ""
	if area.is_interior_map and not area.interior_floor_elevations.is_empty():
		var fl: Array[int] = area.sorted_floors()
		f_str = "  Floors: %d (F%d..F%d)" % [fl.size(), fl[0], fl[fl.size() - 1]]
	return "Battlefield: %dx%d (height %d)  %s %s cover, %s terrain%s%s" % [
		area.width, area.length, area.height, loc, BattlefieldArea.COVER_AMOUNT_NAMES[area.cover_amount],
		BattlefieldArea.UNEVENNESS_NAMES[area.unevenness], b_str, f_str]


#Single-cell glyph for the floor_num view of pos; see MAP_LEGEND.
static func _floor_glyph(area: BattlefieldArea, pos: Vector2i, floor_num: int, landings: Dictionary) -> String:
	var key := Vector3i(pos.x, pos.y, floor_num)
	if area.jagged_cells.has(pos):
		return "!"
	if area.stair_run_cells.has(key):
		return "^" if landings.has(key) else "S"
	var obs: Dictionary = area.get_obs(pos, floor_num)
	if not obs.is_empty():
		var ct: String = obs.get("cell_type", "")
		if ct == "wall":
			return "#"
		if ct == "door":
			return "d" if OpenCloseState.is_open(obs) else "D"
		if ct == "window":
			return "w" if (obs.get("broken", false) as bool) else "W"
		if ct == "fence":
			return "f"
		match _obs_kind(obs):
			"ramp":
				return "S"
			"harm":
				return "*"
			"pass":
				return "~"
		return "o"
	if floor_num == 0:
		return "."
	if area.building_interiors.has(key) and not area.in_footprint(pos):
		return "b"
	if area.has_slab(pos, floor_num):
		return "."
	return " "


#ramp, harm (harmful passthrough), pass (passthrough) or block, from the obstacle data alone.
static func _obs_kind(obs: Dictionary) -> String:
	var d: ObstacleData = obs.get("data") as ObstacleData
	if d != null and d.ramp:
		return "ramp"
	if d == null or not d.passthrough:
		return "block"
	return "harm" if (d.pt_enter_harm > 0 or d.pt_exit_harm > 0) else "pass"


#One ASCII grid per floor, lowest first. markers: Vector3i -> glyph; only_floors limits the set.
static func to_floor_maps_string(area: BattlefieldArea, markers: Dictionary = {}, only_floors: Dictionary = {}) -> String:
	var landings: Dictionary = area.landing_cells()
	var out: Array[String] = []
	for f: int in area.sorted_floors():
		if not only_floors.is_empty() and not only_floors.has(f):
			continue
		out.append("Floor F%d elev=%d" % [f, int(area.interior_floor_elevations.get(f, 0))])
		for y: int in range(area.length):
			var row := ""
			for x: int in range(area.width):
				var key := Vector3i(x, y, f)
				if markers.has(key):
					row += str(markers[key])
				else:
					row += _floor_glyph(area, Vector2i(x, y), f, landings)
			out.append(row)
		out.append(MAP_LEGEND)
	return "\n".join(out)


#Header map: per-floor grids indoors, the single terrain grid outdoors.
static func to_visual_string(area: BattlefieldArea) -> String:
	if area.is_interior_map:
		return to_floor_maps_string(area)
	return _to_exterior_visual_string(area, {})


#F0 grid plus every floor holding a merc, team digits written over the terrain glyph.
#spawns entries: {"team": int, "floor": int, "pos": Vector2i}.
static func to_spawn_map_string(area: BattlefieldArea, spawns: Array) -> String:
	var markers: Dictionary = {}
	var floors: Dictionary = {0: true}
	for s: Dictionary in spawns:
		var sp: Vector2i = s["pos"] as Vector2i
		var sf: int = s["floor"] as int
		markers[Vector3i(sp.x, sp.y, sf)] = "0" if (s["team"] as int) == 0 else "1"
		floors[sf] = true
	if area.is_interior_map:
		return to_floor_maps_string(area, markers, floors)
	return _to_exterior_visual_string(area, markers)


static func _to_exterior_visual_string(area: BattlefieldArea, markers: Dictionary) -> String:
	var pos_map: Dictionary = {}
	for obs: Dictionary in area.obstacles:
		pos_map[BattlefieldArea.cell_of(obs["pos"])] = obs
	var rows: Array[String] = []
	for y: int in range(area.length):
		var row := ""
		for x: int in range(area.width):
			var pos := Vector2i(x, y)
			if markers.has(Vector3i(x, y, 0)):
				row += str(markers[Vector3i(x, y, 0)])
			elif not pos_map.has(pos):
				var h: float = area.get_terrain_height(pos)
				if area.jagged_cells.has(pos):
					row += "[color=red]^[/color]"
				elif h <= -5.0:
					row += "[color=#334455]_[/color]"
				elif h < -0.25:
					row += "[color=gray],[/color]"
				elif h <= 0.25:
					row += "."
				elif h <= 0.75:
					row += "[color=yellow]'[/color]"
				elif h <= 2.0:
					row += "[color=orange]^[/color]"
				else:
					row += "[color=white]^[/color]"
			else:
				match _obs_kind(pos_map[pos] as Dictionary):
					"ramp":
						row += "[color=cyan]S[/color]"
					"harm":
						row += "[color=red]*[/color]"
					"pass":
						row += "[color=pink]~[/color]"
					_:
						row += "[color=orange]#[/color]"
		rows.append(row)
	return "\n".join(rows)
