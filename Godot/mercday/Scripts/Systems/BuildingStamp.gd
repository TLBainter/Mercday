class_name BuildingStamp

#Generates one planned building on a scratch map and copies it into a city map at an offset.
#The generator never sees the city map, so its validation and retries stay map-wide on the scratch map.

const OUTDOOR_FH := 3


#One generated building on its own map; null for a legacy row. building_plan["issues"] holds what validation left.
static func build_scratch(area_data: Dictionary, front: String = "", fh_forced: int = 0,
		site: Dictionary = {}) -> BattlefieldArea:
	if area_data.is_empty() or BuildingRules.is_legacy(area_data):
		return null
	var scratch := BattlefieldArea.new()
	scratch.area_name = String(area_data.get("name", ""))
	scratch.unevenness = 6
	scratch.is_interior_map = true
	InteriorGenerator.generate_interior(scratch, area_data, GenerationContext.new(), front, fh_forced, site)
	return scratch


#Every xy cell the building uses on any floor: masks, interiors, balconies, patios and obstacle cells.
static func used_cells(scratch: BattlefieldArea) -> Dictionary:
	var out: Dictionary = {}
	if scratch == null:
		return out
	for fk: Variant in scratch.footprint_cells.keys():
		out[BattlefieldArea.cell_of(fk)] = true
	for ik: Variant in scratch.building_interiors.keys():
		out[BattlefieldArea.cell_of(ik)] = true
	for ok: Variant in scratch._obs_map.keys():
		out[BattlefieldArea.cell_of(ok)] = true
	return out


#Bounding rect of used_cells; an empty rect when the scratch map holds nothing.
static func used_rect(scratch: BattlefieldArea) -> Rect2i:
	return _rect_of(used_cells(scratch))


#Offset that puts the top left corner of the used rect at the map cell `at`.
static func offset_for(scratch: BattlefieldArea, at: Vector2i) -> Vector2i:
	return at - used_rect(scratch).position


#Copies the scratch building into map at offset and returns its building id; -1 and no write when any used
#cell falls off the map or onto a cell another building owns. The scratch map is consumed: do not reuse it.
static func place(map: BattlefieldArea, scratch: BattlefieldArea, offset: Vector2i) -> int:
	if map == null or scratch == null:
		return -1
	var cells: Dictionary = used_cells(scratch)
	if cells.is_empty():
		return -1
	var ur: Rect2i = _rect_of(cells)
	for ck: Variant in cells.keys():
		var cell: Vector2i = (ck as Vector2i) + offset
		if cell.x < 0 or cell.x >= map.width or cell.y < 0 or cell.y >= map.length:
			return -1
		if map.building_id_at.has(cell):
			return -1
	var id: int = map.buildings.size()
	var room_base: int = map.interior_rooms.size()
	for obs: Dictionary in scratch.obstacles:
		obs["pos"] = _shift(obs["pos"], offset)
		map.obstacles.append(obs)
	for mk: Variant in scratch._obs_map.keys():
		map._obs_map[_shift(mk, offset)] = scratch._obs_map[mk]
	var tables: Array = [
		[scratch.building_interiors, map.building_interiors],
		[scratch.ceiling_cells, map.ceiling_cells],
		[scratch.stairwell_cells, map.stairwell_cells],
		[scratch.stair_run_cells, map.stair_run_cells],
		[scratch.footprint_cells, map.footprint_cells],
	]
	for pair: Array in tables:
		var src: Dictionary = pair[0]
		var dst: Dictionary = pair[1]
		for sk: Variant in src.keys():
			dst[_shift(sk, offset)] = true
	RoofBuilder.copy_to(scratch, map, offset, id)
	for wk: Variant in scratch.stairwell_connections.keys():
		map.stairwell_connections[_shift(wk, offset)] = _shift(scratch.stairwell_connections[wk], offset)
	var rooms: Array[int] = []
	for i: int in range(scratch.interior_rooms.size()):
		var entry: Dictionary = (scratch.interior_rooms[i] as Dictionary).duplicate(true)
		var rrect: Rect2i = entry.get("rect", Rect2i())
		entry["rect"] = Rect2i(rrect.position + offset, rrect.size)
		entry["building"] = id
		map.interior_rooms.append(entry)
		rooms.append(room_base + i)
	for bk: Variant in cells.keys():
		map.building_id_at[(bk as Vector2i) + offset] = id
	var plan: Dictionary = scratch.building_plan.duplicate(true)
	var fdoor: Vector3i = plan.get("front_door", Vector3i(-1, -1, 0))
	if fdoor.x >= 0:
		plan["front_door"] = Vector3i(fdoor.x + offset.x, fdoor.y + offset.y, fdoor.z)
	var bdoor: Vector3i = plan.get("back_door", Vector3i(-1, -1, 0))
	if bdoor.x >= 0:
		plan["back_door"] = Vector3i(bdoor.x + offset.x, bdoor.y + offset.y, bdoor.z)
	if plan.has("band_x0") and int(plan["band_x0"]) >= 0:
		plan["band_x0"] = int(plan["band_x0"]) + offset.x
	var floors: Array[int] = []
	for ek: Variant in scratch.interior_floor_elevations.keys():
		floors.append(ek as int)
	floors.sort()
	var issues: Array = (plan.get("issues", []) as Array).duplicate()
	var rect := Rect2i(ur.position + offset, ur.size)
	map.buildings.append({
		"id": id,
		"name": String(plan.get("name", scratch.area_name)),
		"size_class": String(plan.get("size_class", "")),
		"shell": String(plan.get("shell", "Walled")),
		"front": String(plan.get("front", "")),
		"fh": int(plan.get("fh", scratch.interior_floor_height)),
		"fp": int(plan.get("fp", 0)),
		"fm": int(plan.get("fm", 0)),
		"floors": floors,
		"rect": rect,
		"footprint": Rect2i(scratch.building_footprint.position + offset, scratch.building_footprint.size),
		"top_y": scratch.interior_top_y + offset.y,
		"floor_depth": scratch.interior_floor_depth,
		"front_door": plan.get("front_door", Vector3i(-1, -1, 0)),
		"back_door": plan.get("back_door", Vector3i(-1, -1, 0)),
		"plan": plan,
		"issues": issues,
		"rooms": rooms,
	})
	map.building_planes.append({})
	map.generation_log.append("[GEN] building %d %s front=%s fh=%d floors +%d/-%d rect=%d,%d %dx%d issues=%d"
		% [id, String(plan.get("name", "")), String(plan.get("front", "")),
		int(plan.get("fh", scratch.interior_floor_height)), int(plan.get("fp", 0)), int(plan.get("fm", 0)),
		rect.position.x, rect.position.y, rect.size.x, rect.size.y, issues.size()])
	return id


#Call once after the last place(): ground frame, planes per building, roofs, links and obstacle caches.
static func finish(map: BattlefieldArea) -> void:
	if map == null:
		return
	var ground: int = 0
	for rec: Dictionary in map.buildings:
		ground = maxi(ground, int(rec["fm"]) * int(rec["fh"]))
	var union: Dictionary = {0: true}
	map.building_planes.clear()
	for rec2: Dictionary in map.buildings:
		var fh: int = int(rec2["fh"])
		var planes: Dictionary = {}
		for f: int in (rec2["floors"] as Array):
			planes[f] = ground + f * fh
			union[f] = true
		map.building_planes.append(planes)
	var keys: Array = union.keys()
	keys.sort()
	map.interior_floor_elevations.clear()
	for f2: int in keys:
		map.interior_floor_elevations[f2] = ground + f2 * OUTDOOR_FH
	map.outdoor_planes = {0: ground}
	map.interior_floor_height = OUTDOOR_FH
	RoofBuilder.rebuild_index(map)
	map.set_footprint_from_cells()
	map.build_stair_links()
	map.build_drop_links()
	map._rebuild_cover_obstacles()
	map._rebuild_droppable_obs_map()


#Bounding rect of a set of Vector2i keys; an empty rect for an empty set.
static func _rect_of(cells: Dictionary) -> Rect2i:
	var list: Array[Vector2i] = []
	list.assign(cells.keys())
	return RoofBuilder._rect_of(list)


static func _shift(raw: Variant, offset: Vector2i) -> Variant:
	if typeof(raw) == TYPE_VECTOR3I:
		var v: Vector3i = raw as Vector3i
		return Vector3i(v.x + offset.x, v.y + offset.y, v.z)
	return (raw as Vector2i) + offset
