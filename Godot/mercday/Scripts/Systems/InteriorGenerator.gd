class_name InteriorGenerator

const WING_ONE := 45
const WING_TWO := 85
const WING_TRIES := 20
const WING_GAP := 3
#Obstacle size the interior wall cells are placed with.
const WALL_SZ: int = 4
const WING_LEN_MIN := 5
const REGION_PASSES := 12
const DIRS4: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
const OFF4: Array[Vector3i] = [Vector3i(-1, 0, 0), Vector3i(1, 0, 0), Vector3i(0, -1, 0), Vector3i(0, 1, 0)]


#Legacy rows keep the original generator; every Buildings.tsv row goes through the planned path.
static func generate_interior(area: BattlefieldArea, area_data: Dictionary, ctx: GenerationContext,
		front: String = "", fh_forced: int = 0, site: Dictionary = {}) -> void:
	if BuildingRules.is_legacy(area_data):
		_generate_legacy(area, area_data, ctx)
		return
	_generate_planned(area, area_data, ctx, front, fh_forced, site)


static func _generate_legacy(area: BattlefieldArea, area_data: Dictionary, ctx: GenerationContext) -> void:
	var gen_start := Time.get_ticks_msec()
	_reset(area)

	var fp: int = area_data.get("f_plus", 0)
	var fm: int = area_data.get("f_minus", 0)
	var min_sz: int = area_data.get("min_size", 18)
	var max_sz: int = area_data.get("max_size", 45)
	var num_floors: int = fp + fm + 1

	var fh: int = randi_range(3, 4)
	var floor_d: int = randi_range(min_sz, max_sz)
	var floor_w: int = randi_range(min_sz, max_sz)
	var street: int = randi_range(3, 5)
	var bld_x: int = street
	var wings: Array[Dictionary] = _roll_wings(bld_x, floor_w)
	var north_ext: int = _wing_ext(wings, "n")
	var south_ext: int = _wing_ext(wings, "s")

	_setup_floors(area, area_data, fp, fm, fh, floor_w, floor_d, street,
		floor_d + 1 + 2 * street + north_ext + south_ext)

	#One well per building: every floor is partitioned around the same column pair.
	var sx: int = bld_x + 2 + (randi() % maxi(1, floor_w - 3))
	var stairwell_xs: Dictionary = {}
	var stairwell_adj_xs: Dictionary = {}
	_fill_stair_cols(stairwell_xs, stairwell_adj_xs, fp, fm, sx, _stair_adj_x(sx, bld_x, floor_w))

	var wall_data: ObstacleData = DataManager.get_obstacle_by_name("Wall")
	if wall_data == null:
		push_error("InteriorGenerator: Wall obstacle missing")
		return
	var stairs_data: ObstacleData = DataManager.get_obstacle_by_name("Stairs")
	var window_data: ObstacleData = DataManager.get_obstacle_by_name("Window")

	var top_y: int = street + north_ext
	area.interior_top_y = top_y

	var all_rooms: Array[Dictionary] = []

	_build_shells(area, fp, fm, bld_x, top_y, floor_w, floor_d, wings, wall_data, fh)

	var ent_y: int = _place_entrance_doors(area, bld_x, top_y, floor_w, floor_d, fh, num_floors)

	var floor_v_cors: Dictionary = {}
	var frame: BuildingFrame = _building_frame(bld_x, top_y, floor_w, floor_d, fh, wall_data)
	for f: int in range(fp, -(fm + 1), -1):
		var v_cors_out: Array = []
		var rooms: Array[Dictionary] = _partition_floor(area, f, frame, area_data, stairwell_xs, stairwell_adj_xs,
			v_cors_out)
		all_rooms.append_array(rooms)
		floor_v_cors[f] = v_cors_out
		_place_exterior_rooms(area, f, frame, area_data, street, all_rooms)
		if f < 0:
			continue
		_partition_wings(area, f, wings, frame, area_data, all_rooms)

	if num_floors > 1:
		_build_stairwells(area, floor_v_cors, fp, fm, bld_x, floor_w, floor_d, top_y,
			stairs_data, stairwell_xs, stairwell_adj_xs)

	_open_entrance_cells(area, bld_x, floor_w, ent_y, fh)

	for f: int in range(fp, -1, -1):
		_place_wing_doors(area, wings, f, top_y, floor_d, stairwell_xs, fh)
	for f: int in range(fp, -(fm + 1), -1):
		_connect_floor_regions(area, f, fh)

	_place_windows(area, fp, window_data, stairwell_xs, fh)
	_fix_blind_doors(area)
	place_furniture_in_rooms(area, all_rooms)
	_assign_spawns(area, ctx, bld_x, floor_w, floor_d, top_y)

	var legacy_b: Dictionary = area_data.get("building", {}) as Dictionary
	_finalize(area, RoofBuilder.shape_of(area_data), "W", legacy_b.get("roof_objects", []) as Array)

	var total_ms: int = Time.get_ticks_msec() - gen_start
	_log_generation(area, total_ms, num_floors, floor_w, fh, floor_d, wings)


#Rolls a plan and builds it, retrying while the validator still reports issues.
static func _generate_planned(area: BattlefieldArea, area_data: Dictionary, ctx: GenerationContext,
		front: String = "", fh_forced: int = 0, site: Dictionary = {}) -> void:
	var gen_start := Time.get_ticks_msec()
	var want_front: String = front
	var want_fh: int = fh_forced
	if ctx != null:
		if want_front == "":
			want_front = ctx.building_front
		if want_fh <= 0:
			want_fh = ctx.floor_height
	var plan: Dictionary = {}
	var state: Dictionary = {}
	var all_rooms: Array[Dictionary] = []
	var issues: Array[String] = []
	var retry_notes: Array[String] = []
	var tries: int = 0
	for attempt: int in range(maxi(1, BuildingRules.TRIES)):
		tries = attempt + 1
		_reset(area)
		state = {}
		plan = BuildingRules.roll_plan(area_data, want_front, want_fh, site)
		all_rooms = _build_planned(area, area_data, plan, state)
		issues = BuildingRules.validate(area)
		if issues.is_empty():
			break
		retry_notes.append("[GEN] try %d: %s" % [tries, "; ".join(issues)])
	area.building_plan["tries"] = tries
	area.building_plan["issues"] = issues
	var wings: Array[Dictionary] = []
	if state.has("wings"):
		wings.assign(state["wings"] as Array)
	var geo: FloorGeo = state.get("geo") as FloorGeo
	place_furniture_in_rooms(area, all_rooms)
	_assign_spawns_planned(area, ctx, plan, geo)
	_finalize(area, String(area.building_plan.get("roof", "Flat")), String(area.building_plan.get("front", "")),
		area.building_plan.get("roof_objects", []) as Array)
	var fp: int = int(plan.get("fp", 0))
	var fm: int = int(plan.get("fm", 0))
	var total_ms: int = Time.get_ticks_msec() - gen_start
	_log_generation(area, total_ms, fp + fm + 1, int(plan.get("floor_w", 0)), int(plan.get("fh", 3)),
		int(plan.get("floor_d", 0)), wings)
	area.generation_log.append("[GEN] building %s front=%s %dx%d floors +%d/-%d layout=%s/%s band=%s tries=%d issues=%d"
		% [String(plan.get("name", "?")), String(plan.get("front", "?")), int(plan.get("floor_w", 0)),
		int(plan.get("floor_d", 0)), fp, fm, String(plan.get("layout_f0", "?")),
		String(plan.get("layout_other", "?")), String(plan.get("band_side", "")), tries, issues.size()])
	for note: String in retry_notes:
		area.generation_log.append(note)
	for text: String in issues:
		area.generation_log.append("[GEN] issue: %s" % text)


#Builds one attempt at the rolled plan and returns its room records.
static func _build_planned(area: BattlefieldArea, area_data: Dictionary, plan: Dictionary,
		out_state: Dictionary = {}) -> Array[Dictionary]:
	var all_rooms: Array[Dictionary] = []
	var fp: int = maxi(0, int(plan.get("fp", 0)))
	var fm: int = maxi(0, int(plan.get("fm", 0)))
	var fh: int = maxi(3, int(plan.get("fh", 3)))
	var floor_w: int = maxi(3, int(plan.get("floor_w", 3)))
	var floor_d: int = maxi(3, int(plan.get("floor_d", 3)))
	var street: int = maxi(1, int(plan.get("street", 3)))
	var front: String = String(plan.get("front", "W"))
	var band_side: String = String(plan.get("band_side", ""))
	var num_floors: int = fp + fm + 1
	var bld_x: int = street
	var ix0: int = bld_x + 1
	var ix1: int = bld_x + floor_w
	var band_x0: int = _band_x0(bld_x, floor_w, band_side)
	var wall_data: ObstacleData = DataManager.get_obstacle_by_name("Wall")
	if wall_data == null:
		push_error("InteriorGenerator: Wall obstacle missing")
		return all_rooms
	var stairs_data: ObstacleData = DataManager.get_obstacle_by_name("Stairs")
	var window_data: ObstacleData = DataManager.get_obstacle_by_name("Window")
	var open_shell: bool = String(plan.get("shell", "Walled")) == "Open"
	var wings: Array[Dictionary] = []
	if not open_shell:
		wings = _roll_wings_planned(bld_x, floor_w, plan)
	var north_ext: int = _wing_ext(wings, "n")
	var south_ext: int = _wing_ext(wings, "s")
	var top_y: int = street + north_ext
	_setup_floors(area, area_data, fp, fm, fh, floor_w, floor_d, street,
		floor_d + 2 + 2 * street + north_ext + south_ext)
	area.interior_top_y = top_y
	area.building_plan = plan.duplicate(true)
	area.building_plan["front_door"] = Vector3i(-1, -1, 0)
	area.building_plan["back_door"] = Vector3i(-1, -1, 0)
	area.building_plan["band_x0"] = band_x0
	area.building_plan["tries"] = 0
	area.building_plan["issues"] = []
	var we: bool = front == "W" or front == "E"
	var iy0: int = top_y + 1
	var iy1: int = top_y + floor_d
	var ux0: int = ix0 + (2 if band_x0 == ix0 else 0)
	var ux1: int = ix1 - (2 if band_x0 == ix1 - 1 else 0)
	var geo := FloorGeo.new()
	geo.front = front
	geo.bld_x = bld_x
	geo.top_y = top_y
	geo.floor_w = floor_w
	geo.floor_d = floor_d
	geo.ix0 = ix0
	geo.ix1 = ix1
	geo.iy0 = iy0
	geo.iy1 = iy1
	geo.ux0 = ux0
	geo.ux1 = ux1
	geo.band_x0 = band_x0
	geo.rows = stair_run_rows(top_y, floor_d, fh)
	geo.top_floor = fp
	geo.ent_row = _entrance_row(area, top_y, floor_d, fh, num_floors)
	geo.street = street
	geo.t0 = iy0 if we else ux0
	geo.t1 = iy1 if we else ux1
	geo.s_size = (ux1 - ux0 + 1) if we else (iy1 - iy0 + 1)
	out_state["wings"] = wings
	out_state["geo"] = geo
	if open_shell:
		all_rooms.append_array(BuildingLayouts.open_shell(area, plan, geo))
		return all_rooms
	if band_x0 >= 0:
		for bx: int in [band_x0, band_x0 + 1]:
			for by: int in range(iy0, iy1 + 1):
				area.reserved_corridor_cells[Vector2i(bx, by)] = true
	_build_shells(area, fp, fm, bld_x, top_y, floor_w, floor_d, wings, wall_data, fh)
	var stairwell_xs: Dictionary = {}
	var stairwell_adj_xs: Dictionary = {}
	var fixed_pair: Array[int] = []
	if num_floors > 1:
		var sx: int = band_x0
		var adj: int = band_x0 + 1
		if band_x0 >= 0:
			fixed_pair = [band_x0, band_x0 + 1]
		else:
			var sx_lo: int = bld_x + 2
			var sx_n: int = floor_w - 3
			#A corridor floor keeps the stair hall off the front wall so a room can stand behind the street door.
			if String(plan.get("layout_f0", "")) == "Corridor" and floor_w >= BuildingRules.CORRIDOR_MIN:
				if front == "W":
					sx_lo += 5
					sx_n -= 5
				elif front == "E":
					sx_n -= 5
			sx = sx_lo + (randi() % maxi(1, sx_n))
			adj = _stair_adj_x(sx, bld_x, floor_w)
		_fill_stair_cols(stairwell_xs, stairwell_adj_xs, fp, fm, sx, adj)
	var layout_other: String = String(plan.get("layout_other", ""))
	if layout_other == "":
		layout_other = String(plan.get("layout_f0", "Open"))
	var floor_v_cors: Dictionary = {}
	var frame: BuildingFrame = _building_frame(bld_x, top_y, floor_w, floor_d, fh, wall_data)
	for f: int in range(fp, -(fm + 1), -1):
		var layout: String = String(plan.get("layout_f0", "Open")) if f == 0 else layout_other
		var fill_data: Dictionary = _fill_data(area_data, plan, f, fp)
		var v_cors_out: Array = []
		if layout == "Corridor":
			var rooms_f: Array[Dictionary] = _partition_floor(area, f, frame, fill_data, stairwell_xs, stairwell_adj_xs,
				v_cors_out)
			if rooms_f.is_empty():
				rooms_f = BuildingLayouts.open_floor(area, f, plan, geo)
			all_rooms.append_array(rooms_f)
		elif layout == "Shop":
			all_rooms.append_array(BuildingLayouts.shop_floor(area, f, plan, geo, wall_data, fh))
		elif layout == "Hall":
			all_rooms.append_array(BuildingLayouts.hall_floor(area, f, plan, geo, wall_data, fh))
		else:
			all_rooms.append_array(BuildingLayouts.open_floor(area, f, plan, geo))
		floor_v_cors[f] = v_cors_out
		if f < 0:
			continue
		_partition_wings(area, f, wings, frame, fill_data, all_rooms)
		_ext_room_planned(area, f, frame, area_data, plan, street, all_rooms)
	if num_floors > 1:
		_build_stairwells(area, floor_v_cors, fp, fm, bld_x, floor_w, floor_d, top_y,
			stairs_data, stairwell_xs, stairwell_adj_xs, fixed_pair)
	BuildingLayouts.place_doors(area, plan, geo, all_rooms, fh, wings)
	BuildingLayouts.label_rooms(area, plan, all_rooms, geo)
	for f: int in range(fp, -1, -1):
		_place_wing_doors(area, wings, f, top_y, floor_d, stairwell_xs, fh)
	for f: int in range(fp, -(fm + 1), -1):
		_connect_floor_regions(area, f, fh)
	_place_windows(area, fp, window_data, stairwell_xs, fh, String(plan.get("windows", "Normal")),
		plan.get("window_rooms", {}) as Dictionary)
	_fix_blind_doors(area)
	return all_rooms


#Clears the generated tables, the spawn zones and the room list before a build.
static func _reset(area: BattlefieldArea) -> void:
	area.reset_generated_state()
	area.spawn_zone_a.clear()
	area.spawn_zone_b.clear()
	area.interior_rooms.clear()


#Map size, interior flags, name and floor elevations; the caller passes the map length.
static func _setup_floors(area: BattlefieldArea, area_data: Dictionary, fp: int, fm: int, fh: int, floor_w: int,
		floor_d: int, street: int, map_length: int) -> void:
	area.width = floor_w + 2 + 2 * street
	area.length = map_length
	area.height = randi_range(20, 40)
	area.cover_amount = 2
	area.is_interior_map = true
	area.unevenness = 6
	area.interior_floor_height = fh
	area.interior_floor_depth = floor_d
	area.area_name = String(area_data.get("name", "Unknown"))
	#floors sorted from lowest to highest: -fm, ..., 0, ..., fp
	var floor_list: Array[int] = []
	for f: int in range(-fm, fp + 1):
		floor_list.append(f)
	floor_list.sort()
	for fi: int in range(floor_list.size()):
		area.interior_floor_elevations[floor_list[fi]] = fi * fh


#Partner column of a stair well: west of an odd column with room, else east unless that passes the east wall.
static func _stair_adj_x(sx: int, bld_x: int, floor_w: int) -> int:
	var tdx: int = -1 if (sx % 2 == 1 and sx - 1 >= bld_x + 1) else 1
	if tdx > 0 and sx + 1 > bld_x + floor_w:
		tdx = -1
	return sx + tdx


#Every floor above the lowest one gets the shared stair column pair.
static func _fill_stair_cols(stairwell_xs: Dictionary, stairwell_adj_xs: Dictionary, fp: int, fm: int, sx: int,
		adj: int) -> void:
	for f: int in range(fp, -fm, -1):
		stairwell_xs[f] = sx
		stairwell_adj_xs[f] = adj


#Floor and wing shells from the top floor down, then the footprint masks and the ceiling cells.
static func _build_shells(area: BattlefieldArea, fp: int, fm: int, bld_x: int, top_y: int, floor_w: int,
		floor_d: int, wings: Array[Dictionary], wall_data: ObstacleData, fh: int) -> void:
	for f: int in range(fp, -(fm + 1), -1):
		_place_floor_shell(area, f, bld_x, top_y, floor_w, floor_d, wall_data, fh)
		if f < 0:
			continue
		for wing: Dictionary in wings:
			_place_wing_shell(area, f, wing, top_y, floor_d, wall_data, fh)
	_apply_masks(area, fp, fm, bld_x, top_y, floor_w, floor_d, wings)
	mark_ceiling_cells(area, fp, fm, bld_x, floor_w, floor_d, top_y)


#Partitions main floor f around the stair columns of f and of the floor above.
static func _partition_floor(area: BattlefieldArea, f: int, frame: BuildingFrame, data: Dictionary,
		stairwell_xs: Dictionary, stairwell_adj_xs: Dictionary, v_cors_out: Array) -> Array[Dictionary]:
	var sx_below: int = stairwell_xs.get(f, -1)
	var sx_above: int = stairwell_xs.get(f + 1, -1)
	var ax_below: int = stairwell_adj_xs.get(f, -1)
	var ax_above: int = stairwell_adj_xs.get(f + 1, -1)
	return _partition_rooms(area, f, frame, data, sx_below, sx_above, ax_below, ax_above, v_cors_out)


#Partitions every wing of floor f into rooms.
static func _partition_wings(area: BattlefieldArea, f: int, wings: Array[Dictionary], frame: BuildingFrame,
		data: Dictionary, all_rooms: Array[Dictionary]) -> void:
	for wing: Dictionary in wings:
		var wrect: Rect2i = _wing_rect(wing, frame.top_y, frame.floor_d)
		var wing_frame: BuildingFrame = _building_frame(wrect.position.x, wrect.position.y, int(wing["len"]),
			int(wing["depth"]), frame.fh, frame.wall_data)
		all_rooms.append_array(_partition_rooms(area, f, wing_frame, data))


#Stair and drop links, the cover caches, then the roof and its objects.
static func _finalize(area: BattlefieldArea, roof: String, front: String, roof_objects: Array) -> void:
	NavLinkBuilder.build_stair_links(area)
	NavLinkBuilder.build_drop_links(area)
	area._rebuild_cover_obstacles()
	area._rebuild_droppable_obs_map()
	RoofBuilder.build(area, roof, front)
	RoofObjects.place_objects(area, roof_objects)
	#Roof edges carry drop links, so the table is rebuilt once the roof exists.
	NavLinkBuilder.build_drop_links(area)


#Left column of the two column stair band on a W or E band side; -1 when the plan has no band.
static func _band_x0(bld_x: int, floor_w: int, band_side: String) -> int:
	if band_side == "W":
		return bld_x + 1
	elif band_side == "E":
		return bld_x + floor_w - 1
	return -1


#Wings on the north or south side only, never on the front and never across the stair band.
static func _roll_wings_planned(bld_x: int, floor_w: int, plan: Dictionary) -> Array[Dictionary]:
	var wings: Array[Dictionary] = []
	var want: int = int(plan.get("wing_count", 0))
	if want <= 0 or floor_w < WING_LEN_MIN + 2:
		return wings
	var front: String = String(plan.get("front", "W"))
	var sides: Array[String] = []
	for side: String in ["n", "s"]:
		if (side == "n" and front == "N") or (side == "s" and front == "S"):
			continue
		sides.append(side)
	if sides.size() > 1 and want < 2:
		var only: String = sides[randi() % sides.size()]
		sides.clear()
		sides.append(only)
	var band_side: String = String(plan.get("band_side", ""))
	var band_x0: int = _band_x0(bld_x, floor_w, band_side)
	for side: String in sides:
		if wings.size() >= want:
			break
		for _try: int in range(WING_TRIES):
			var wing: Dictionary = _roll_one_wing(wings, side, bld_x, floor_w)
			if wing.is_empty():
				break
			if band_x0 >= 0 and int(wing["x0"]) <= band_x0 + 2 \
					and int(wing["x0"]) + int(wing["len"]) - 1 >= band_x0 - 1:
				continue
			wings.append(wing)
			break
	return wings


#Room fill list for one floor: other rooms first, then the required ones, then everything named.
static func _fill_data(area_data: Dictionary, plan: Dictionary, f: int, top_floor: int) -> Dictionary:
	var out: Dictionary = area_data.duplicate()
	out["top_floor"] = top_floor
	var others: Array[String] = _plan_names(plan.get("other_rooms", []))
	out["rooms_list"] = others
	if not RoomCatalog.get_rooms_for_floor(out, f).is_empty():
		return out
	var wider: Array[String] = _plan_names(plan.get("required_rooms", []))
	wider.append_array(others)
	out["rooms_list"] = wider
	if not RoomCatalog.get_rooms_for_floor(out, f).is_empty():
		return out
	var every: Array[String] = [String(plan.get("main_room", ""))]
	every.append_array(wider)
	out["rooms_list"] = every
	return out


static func _plan_names(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	for entry: Variant in (raw as Array):
		var name_text: String = String(entry)
		if name_text != "":
			out.append(name_text)
	return out


#Half the time an eligible floor gets a walled exterior room on a side the front and band leave free.
static func _ext_room_planned(area: BattlefieldArea, f: int, frame: BuildingFrame, area_data: Dictionary,
		plan: Dictionary, street: int, all_rooms: Array[Dictionary]) -> void:
	if f < 0:
		return
	if bool(plan.get("no_ext_rooms", false)):
		return
	var ext_data: Dictionary = area_data.duplicate()
	ext_data["top_floor"] = int(plan.get("fp", 0))
	var every: Array[String] = [String(plan.get("main_room", ""))]
	every.append_array(_plan_names(plan.get("required_rooms", [])))
	every.append_array(_plan_names(plan.get("other_rooms", [])))
	ext_data["rooms_list"] = every
	if RoomCatalog.get_exterior_rooms_for_floor(ext_data, f).is_empty():
		return
	if randi() % 2 != 0:
		return
	var front: String = String(plan.get("front", "W"))
	var band_side: String = String(plan.get("band_side", ""))
	var sides: Array[String] = []
	for side: String in ["W", "E"]:
		if side == front or side == band_side:
			continue
		sides.append(side)
	if sides.is_empty():
		return
	_place_exterior_rooms(area, f, frame, ext_data, street, all_rooms, sides[randi() % sides.size()])


#Spawns for a planned building: team A behind the front door, team B at the far end of floor 0.
static func _assign_spawns_planned(area: BattlefieldArea, ctx: GenerationContext, plan: Dictionary,
		geo: FloorGeo) -> void:
	if geo == null:
		return
	var floor_w: int = geo.floor_w
	var floor_d: int = geo.floor_d
	var max_team: int = 4 if ctx == null else maxi(ctx.team_size_a, ctx.team_size_b)
	area.spawn_radius = maxf(3.0, float(max_team))
	area.spawn_radius = minf(area.spawn_radius, minf(float(floor_w), float(floor_d)) / 2.0)
	var front: String = String(plan.get("front", "W"))
	var ix0: int = geo.ix0
	var ix1: int = geo.ix1
	var iy0: int = geo.iy0
	var iy1: int = geo.iy1
	var mid_x: int = (ix0 + ix1) >> 1
	var mid_y: int = (iy0 + iy1) >> 1
	var near: Vector2i = Vector2i(ix0 + (floor_w >> 2), mid_y)
	var far: Vector2i = Vector2i(ix1 - (floor_w >> 2), mid_y)
	if front == "E":
		near = Vector2i(ix1 - (floor_w >> 2), mid_y)
		far = Vector2i(ix0 + (floor_w >> 2), mid_y)
	elif front == "N":
		near = Vector2i(mid_x, iy0 + (floor_d >> 2))
		far = Vector2i(mid_x, iy1 - (floor_d >> 2))
	elif front == "S":
		near = Vector2i(mid_x, iy1 - (floor_d >> 2))
		far = Vector2i(mid_x, iy0 + (floor_d >> 2))
	area.spawn_center_a = near
	area.spawn_center_b = far
	for key: Variant in area.building_interiors.keys():
		var c: Vector3i = key as Vector3i
		if c.z != 0 or area._obs_map.has(c):
			continue
		var flat := Vector2i(c.x, c.y)
		if flat.distance_squared_to(near) <= flat.distance_squared_to(far):
			area.spawn_zone_a[flat] = true
		else:
			area.spawn_zone_b[flat] = true
	var span: Vector2i = BuildingLayouts.wall_t_range(geo, front)
	var t_mid: int = (span.x + span.y) >> 1
	var door: Vector3i = area.building_plan.get("front_door", Vector3i(-1, -1, 0))
	var anchor_a: Vector2i = BuildingLayouts.wall_cell(geo, front, t_mid)
	if door.x >= 0:
		anchor_a = Vector2i(door.x, door.y)
	var anchor_b: Vector2i = BuildingLayouts.wall_cell(geo, BuildingLayouts.opposite(front), t_mid)
	if area.spawn_zone_a.size() < 4:
		_add_street_cells(area, area.spawn_zone_a, area.spawn_zone_b, anchor_a)
	if area.spawn_zone_b.size() < 4:
		_add_street_cells(area, area.spawn_zone_b, area.spawn_zone_a, anchor_b)


#Free floor 0 street cells within 3 cells of the anchor join a zone that is too small to hold a team.
static func _add_street_cells(area: BattlefieldArea, zone: Dictionary, other: Dictionary, anchor: Vector2i) -> void:
	for dx: int in range(-3, 4):
		for dy: int in range(-3, 4):
			var flat := Vector2i(anchor.x + dx, anchor.y + dy)
			if not area.in_bounds(flat):
				continue
			var c := Vector3i(flat.x, flat.y, 0)
			if area.in_footprint(flat) or area.building_interiors.has(c) or area._obs_map.has(c) or other.has(flat):
				continue
			zone[flat] = true


static func _place_floor_shell(area: BattlefieldArea, f: int, bld_x: int, top_y: int, floor_w: int, floor_d: int, wall_data: ObstacleData, fh: int) -> void:
	var bot_y: int = top_y + floor_d + 1

	for x: int in range(bld_x, bld_x + floor_w + 2):
		place_wall_if_empty(area, Vector3i(x, top_y, f), WALL_SZ, wall_data, fh)
		place_wall_if_empty(area, Vector3i(x, bot_y, f), WALL_SZ, wall_data, fh)

	for y: int in range(top_y + 1, bot_y):
		place_wall_if_empty(area, Vector3i(bld_x, y, f), WALL_SZ, wall_data, fh)
		place_wall_if_empty(area, Vector3i(bld_x + floor_w + 1, y, f), WALL_SZ, wall_data, fh)

	for iy: int in range(top_y + 1, bot_y):
		for ix: int in range(bld_x + 1, bld_x + floor_w + 1):
			area.building_interiors[Vector3i(ix, iy, f)] = true


#One to three wings on the north and south walls; each one stays inside the main block's side walls.
static func _roll_wings(bld_x: int, floor_w: int) -> Array[Dictionary]:
	var roll: int = randi() % 100
	var want: int = 1
	if roll >= WING_ONE:
		want = 2
	if roll >= WING_TWO:
		want = 3
	var sides: Array[String] = []
	for _i: int in range(want):
		sides.append("n" if randi() % 2 == 0 else "s")
	if want == 3 and not (sides.has("n") and sides.has("s")):
		sides[randi() % 3] = "s" if sides[0] == "n" else "n"
	var wings: Array[Dictionary] = []
	for side: String in sides:
		var w: Dictionary = _roll_one_wing(wings, side, bld_x, floor_w)
		if not w.is_empty():
			wings.append(w)
	if wings.is_empty():
		wings.append({"side": "n", "x0": bld_x + 1 + maxi(0, (floor_w - WING_LEN_MIN) >> 1),
			"len": WING_LEN_MIN, "depth": 3})
	return wings


#One wing roll: length, depth and column start clear of the wings already taken on that side.
static func _roll_one_wing(wings: Array[Dictionary], side: String, bld_x: int, floor_w: int) -> Dictionary:
	var max_len: int = floor_w - 4
	if max_len < WING_LEN_MIN:
		return {}
	for _t: int in range(WING_TRIES):
		var wlen: int = randi_range(WING_LEN_MIN, max_len)
		var depth: int = randi_range(3, 6)
		var x0: int = randi_range(bld_x + 1, bld_x + floor_w + 1 - wlen)
		var clash: bool = false
		for other: Dictionary in wings:
			if String(other["side"]) != side:
				continue
			var ox0: int = int(other["x0"])
			var olen: int = int(other["len"])
			if not (x0 >= ox0 + olen + WING_GAP + 2 or ox0 >= x0 + wlen + WING_GAP + 2):
				clash = true
		if not clash:
			return {"side": side, "x0": x0, "len": wlen, "depth": depth}
	return {}


#Rows the map gains beyond the main block on one side: the deepest wing plus its outer wall.
static func _wing_ext(wings: Array[Dictionary], side: String) -> int:
	var best: int = 0
	for w: Dictionary in wings:
		if String(w["side"]) == side:
			best = maxi(best, int(w["depth"]) + 1)
	return best


#Wing rect with its walls: the row shared with the main block is the rect edge nearest the block.
static func _wing_rect(wing: Dictionary, top_y: int, floor_d: int) -> Rect2i:
	var wlen: int = int(wing["len"])
	var depth: int = int(wing["depth"])
	var x0: int = int(wing["x0"]) - 1
	var y0: int = top_y - depth - 1 if String(wing["side"]) == "n" else top_y + floor_d + 1
	return Rect2i(x0, y0, wlen + 2, depth + 2)


#Wall ring on the wing's three outer sides; the shared wall row keeps the main block wall.
static func _place_wing_shell(area: BattlefieldArea, f: int, wing: Dictionary, top_y: int,
		floor_d: int, wall_data: ObstacleData, fh: int) -> void:
	var rect: Rect2i = _wing_rect(wing, top_y, floor_d)
	var x1: int = rect.end.x - 1
	var y1: int = rect.end.y - 1
	var out_y: int = rect.position.y if String(wing["side"]) == "n" else y1
	for x: int in range(rect.position.x, x1 + 1):
		place_wall_if_empty(area, Vector3i(x, out_y, f), WALL_SZ, wall_data, fh)
	for y: int in range(rect.position.y, y1 + 1):
		place_wall_if_empty(area, Vector3i(rect.position.x, y, f), WALL_SZ, wall_data, fh)
		place_wall_if_empty(area, Vector3i(x1, y, f), WALL_SZ, wall_data, fh)
	for iy: int in range(rect.position.y + 1, y1):
		for ix: int in range(rect.position.x + 1, x1):
			area.building_interiors[Vector3i(ix, iy, f)] = true


#Per-floor footprint masks: the main block on every floor, the wings on floor 0 and above.
static func _apply_masks(area: BattlefieldArea, fp: int, fm: int, bld_x: int, top_y: int,
		floor_w: int, floor_d: int, wings: Array[Dictionary]) -> void:
	var main := Rect2i(bld_x, top_y, floor_w + 2, floor_d + 2)
	for f: int in range(fp, -(fm + 1), -1):
		_mask_rect(area, f, main)
		if f < 0:
			continue
		for wing: Dictionary in wings:
			_mask_rect(area, f, _wing_rect(wing, top_y, floor_d))
	area.set_footprint_from_cells()


static func _mask_rect(area: BattlefieldArea, f: int, rect: Rect2i) -> void:
	for ix: int in range(rect.position.x, rect.end.x):
		for iy: int in range(rect.position.y, rect.end.y):
			area.footprint_cells[Vector3i(ix, iy, f)] = true


static func mark_ceiling_cells(area: BattlefieldArea, fp: int, fm: int, bld_x: int, floor_w: int, floor_d: int,
		top_y: int) -> void:
	var ceiling_y: int = top_y + floor_d
	for f: int in range(fp, -fm, -1):
		for x: int in range(bld_x, bld_x + floor_w + 2):
			area.ceiling_cells[Vector3i(x, ceiling_y, f)] = true


#Main floor or wing to partition: corner wall cell bld_x, top_y, inner size, floor height and wall template.
class BuildingFrame:
	var bld_x: int = 0
	var top_y: int = 0
	var floor_w: int = 0
	var floor_d: int = 0
	var fh: int = 0
	var wall_data: ObstacleData = null


static func _building_frame(bld_x: int, top_y: int, floor_w: int, floor_d: int, fh: int,
		wall_data: ObstacleData) -> BuildingFrame:
	var fr := BuildingFrame.new()
	fr.bld_x = bld_x
	fr.top_y = top_y
	fr.floor_w = floor_w
	fr.floor_d = floor_d
	fr.fh = fh
	fr.wall_data = wall_data
	return fr


static func _partition_rooms(area: BattlefieldArea, f: int, frame: BuildingFrame, area_data: Dictionary,
		stairwell_x_below: int = -1, stairwell_x_above: int = -1, adj_x_below: int = -1, adj_x_above: int = -1,
		v_cors_out: Array = []) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var eligible: Array[ObstacleData] = RoomCatalog.get_rooms_for_floor(area_data, f)
	if eligible.is_empty():
		return result
	eligible.shuffle()
	var door_data: ObstacleData = DataManager.door_data()
	if frame.floor_d >= 4:
		_partition_corridor(area, f, frame, eligible, door_data, result, stairwell_x_below, stairwell_x_above,
			adj_x_below, adj_x_above, v_cors_out)
	else:
		_partition_strip(area, f, frame.bld_x + 1, frame.top_y + 1, frame.floor_w, frame.floor_d, eligible, frame,
			result, stairwell_x_below, adj_x_below, true)
	return result


static func _partition_corridor(area: BattlefieldArea, f: int, frame: BuildingFrame, eligible: Array[ObstacleData],
		door_data: ObstacleData, result: Array[Dictionary], stairwell_x_below: int = -1, stairwell_x_above: int = -1,
		adj_x_below: int = -1, adj_x_above: int = -1, v_cors_out: Array = []) -> void:
	var ix0: int = frame.bld_x + 1
	var iy0: int = frame.top_y + 1
	var ix1: int = frame.bld_x + frame.floor_w
	var iy1: int = frame.top_y + frame.floor_d

	var h_cors: Array[int] = []
	var v_cors: Array[int] = []
	if not _corridor_lines(ix0, iy0, ix1, iy1, frame.top_y, frame.floor_d, frame.fh, eligible,
			stairwell_x_below, stairwell_x_above, adj_x_below, adj_x_above, h_cors, v_cors):
		_partition_strip(area, f, ix0, iy0, frame.floor_w, frame.floor_d, eligible, frame, result, stairwell_x_above,
			adj_x_above, true)
		return

	for sw_x: int in [stairwell_x_below, stairwell_x_above]:
		if sw_x >= ix0 and sw_x <= ix1 and not v_cors.has(sw_x):
			v_cors.append(sw_x)
	for ax: int in [adj_x_below, adj_x_above]:
		if ax >= ix0 and ax <= ix1 and not v_cors.has(ax):
			v_cors.append(ax)

	for cx: int in v_cors:
		if cx >= ix0 and cx <= ix1 and not v_cors_out.has(cx):
			v_cors_out.append(cx)

	for cy: int in h_cors:
		for x: int in range(ix0, ix1 + 1):
			area.reserved_corridor_cells[Vector2i(x, cy)] = true
	for cx: int in v_cors:
		for y: int in range(iy0, iy1 + 1):
			area.reserved_corridor_cells[Vector2i(cx, y)] = true

	h_cors.sort()
	v_cors.sort()

	var y_edges: Array[int] = [iy0]
	for cy: int in h_cors:
		y_edges.append(cy - 1)
		y_edges.append(cy + 1)
	y_edges.append(iy1)

	var x_edges: Array[int] = [ix0]
	for cx: int in v_cors:
		x_edges.append(cx - 1)
		x_edges.append(cx + 1)
	x_edges.append(ix1)

	var y_bands: Array[Array] = []
	for i: int in range(0, y_edges.size(), 2):
		if y_edges[i] <= y_edges[i + 1]:
			y_bands.append([y_edges[i], y_edges[i + 1]])

	var x_bands: Array[Array] = []
	for i: int in range(0, x_edges.size(), 2):
		if x_edges[i] <= x_edges[i + 1]:
			x_bands.append([x_edges[i], x_edges[i + 1]])

	var elig: Array[ObstacleData] = eligible.duplicate()
	elig.shuffle()

	for yb: Array in y_bands:
		for xb: Array in x_bands:
			var rx0: int = xb[0] as int
			var ry0: int = yb[0] as int
			var rw: int = (xb[1] as int) - rx0 + 1
			var rh: int = (yb[1] as int) - ry0 + 1
			if rw < 3 or rh < 2:
				continue
			var reg_result: Array[Dictionary] = []
			var sw_x: int = stairwell_x_above if ry0 == iy0 else stairwell_x_below
			var ax: int = adj_x_above if ry0 == iy0 else adj_x_below
			var right_x: int = xb[1] as int
			var at_outer: bool = right_x == ix1 or v_cors.has(right_x + 1)
			_partition_strip(area, f, rx0, ry0, rw, rh, elig, frame, reg_result, sw_x, ax, at_outer)
			result.append_array(reg_result)

	var h_cor_set: Dictionary = {}
	for cy: int in h_cors:
		h_cor_set[cy] = true
	var v_cor_set: Dictionary = {}
	for cx: int in v_cors:
		v_cor_set[cx] = true
	var stairwell_v_set: Dictionary = {}
	for swx2: int in [stairwell_x_below, stairwell_x_above, adj_x_below, adj_x_above]:
		if swx2 >= ix0 and swx2 <= ix1:
			stairwell_v_set[swx2] = true
	var accessible_rects: Dictionary = _mark_accessible_rects(result, f, h_cor_set, v_cor_set, stairwell_v_set)
	_cut_region_doors(area, f, result, h_cor_set, v_cor_set, stairwell_v_set, accessible_rects,
		WALL_SZ, frame.wall_data, frame.fh, door_data)


#Corridor rows and columns for one floor, written into h_cors and v_cors.
#Returns false when no corridor fits and the caller must fill the floor with one strip.
static func _corridor_lines(ix0: int, iy0: int, ix1: int, iy1: int, top_y: int, floor_d: int, fh: int,
		eligible: Array[ObstacleData], stairwell_x_below: int, stairwell_x_above: int,
		adj_x_below: int, adj_x_above: int, h_cors: Array[int], v_cors: Array[int]) -> bool:
	var max_room_sz_x: int = 0
	var max_room_sz_y: int = 0
	for r: ObstacleData in eligible:
		max_room_sz_x = maxi(max_room_sz_x, ceili(r.size_x))
		max_room_sz_y = maxi(max_room_sz_y, ceili(r.size_y))
	if max_room_sz_x == 0:
		max_room_sz_x = 4
	if max_room_sz_y == 0:
		max_room_sz_y = 4

	var floor_h_depth: int = iy1 - iy0
	var min_strip: int = maxi(3, mini(max_room_sz_y, (floor_h_depth >> 1) - 1))
	var min_v_strip: int = maxi(3, max_room_sz_x)
	var h_min: int = iy0 + min_strip
	var h_max: int = iy1 - min_strip
	var v_min: int = ix0 + min_v_strip
	var v_max: int = ix1 - min_v_strip
	var can_h: bool = h_min <= h_max
	var can_v: bool = v_min <= v_max

	if not can_h and not can_v:
		return false

	var sw_covers_v: bool = false
	for swx: int in [stairwell_x_below, stairwell_x_above, adj_x_below, adj_x_above]:
		if swx >= ix0 and swx <= ix1:
			sw_covers_v = true
			break

	var run_rows: Vector2i = stair_run_rows(top_y, floor_d, fh)
	var well_band: bool = sw_covers_v and run_rows.x - 1 >= iy0 and run_rows.y + 1 <= iy1
	if well_band:
		#A corridor at each end of the run band reaches the landing and the run top; nothing crosses the band.
		h_cors.append(run_rows.x - 1)
		h_cors.append(run_rows.y + 1)
		for band: Array in [[iy0, run_rows.x - 2], [run_rows.y + 2, iy1]]:
			var by0: int = band[0] as int
			var by1: int = band[1] as int
			if by1 - by0 + 1 >= min_strip * 2 + 1:
				h_cors.append(randi_range(by0 + min_strip, by1 - min_strip))
		if can_v:
			var v_cands: Array[int] = []
			for vx: int in range(v_min, v_max + 1):
				var far_enough: bool = true
				for swx3: int in [stairwell_x_below, stairwell_x_above, adj_x_below, adj_x_above]:
					if swx3 >= 0 and absi(vx - swx3) < 4:
						far_enough = false
				if far_enough:
					v_cands.append(vx)
			if not v_cands.is_empty():
				v_cors.append(v_cands[randi() % v_cands.size()])
	else:
		var valid_pats: Array[int] = []
		if can_h:
			valid_pats.append(0)
			valid_pats.append(0)
		if can_v and not sw_covers_v:
			valid_pats.append(1)
		if can_h and can_v and not sw_covers_v:
			valid_pats.append(2)
		if can_h and h_max - h_min >= min_strip * 2 + 1:
			valid_pats.append(3)
		if valid_pats.is_empty():
			return false
		var pat: int = valid_pats[randi() % valid_pats.size()]
		match pat:
			0:
				h_cors.append(randi_range(h_min, h_max))
			1:
				v_cors.append(randi_range(v_min, v_max))
			2:
				h_cors.append(randi_range(h_min, h_max))
				v_cors.append(randi_range(v_min, v_max))
			3:
				var mid: int = (h_min + h_max) >> 1
				var cy1: int = randi_range(h_min, maxi(h_min, mid - min_strip))
				var cy2: int = randi_range(mini(h_max, mid + min_strip), h_max)
				if cy1 < cy2:
					h_cors.append(cy1)
					h_cors.append(cy2)
				else:
					h_cors.append(randi_range(h_min, h_max))
		if h_cors.is_empty() and sw_covers_v and can_h:
			h_cors.append(randi_range(h_min, h_max))
	return true


#Rooms that already touch a corridor edge, grown through the rooms stacked against them.
static func _mark_accessible_rects(result: Array[Dictionary], f: int, h_cor_set: Dictionary,
		v_cor_set: Dictionary, stairwell_v_set: Dictionary) -> Dictionary:
	var accessible_rects: Dictionary = {}
	for are: Dictionary in result:
		if (are["floor"] as int) != f:
			continue
		var ar: Rect2i = are["rect"] as Rect2i
		var arhc: bool = h_cor_set.has(ar.position.y - 1) or h_cor_set.has(ar.end.y)
		var arns: bool = (v_cor_set.has(ar.position.x - 1) and not stairwell_v_set.has(ar.position.x - 1)) or (v_cor_set.has(ar.end.x) and not stairwell_v_set.has(ar.end.x))
		if arhc or arns:
			accessible_rects[ar.position] = true
	var arc: bool = true
	while arc:
		arc = false
		for are: Dictionary in result:
			if (are["floor"] as int) != f:
				continue
			var ar: Rect2i = are["rect"] as Rect2i
			if accessible_rects.has(ar.position):
				continue
			for are2: Dictionary in result:
				if (are2["floor"] as int) != f:
					continue
				var ar2: Rect2i = are2["rect"] as Rect2i
				if not accessible_rects.has(ar2.position):
					continue
				if ar2.position.x == ar.position.x and ar2.end.x == ar.end.x and ((ar.end.y + 1 == ar2.position.y) or (ar2.end.y + 1 == ar.position.y)):
					accessible_rects[ar.position] = true
					arc = true
					break
	return accessible_rects


#Wall runs and one door on every room edge that meets a corridor.
static func _cut_region_doors(area: BattlefieldArea, f: int, result: Array[Dictionary],
		h_cor_set: Dictionary, v_cor_set: Dictionary, stairwell_v_set: Dictionary,
		accessible_rects: Dictionary, wall_sz: int, wall_data: ObstacleData, fh: int,
		door_data: ObstacleData) -> void:
	for entry: Dictionary in result:
		if (entry["floor"] as int) != f:
			continue
		var rect: Rect2i = entry["rect"] as Rect2i
		var door_x: int = rect.position.x + (rect.size.x >> 1)
		var door_y: int = rect.position.y + (rect.size.y >> 1)

		if h_cor_set.has(rect.position.y - 1):
			var hx_t: int = door_x
			if _well_row_blocked(area, rect.position.y - 1):
				hx_t = _door_col_clear(stairwell_v_set, rect.position.x, rect.end.x, door_x)
			_place_edge_doors(area, f, "h", rect.position.y, rect.position.x, rect.end.x,
				hx_t, false, wall_sz, wall_data, fh, door_data)

		if h_cor_set.has(rect.end.y):
			var hx_b: int = door_x
			if _well_row_blocked(area, rect.end.y):
				hx_b = _door_col_clear(stairwell_v_set, rect.position.x, rect.end.x, door_x)
			_place_edge_doors(area, f, "h", rect.end.y - 1, rect.position.x, rect.end.x,
				hx_b, false, wall_sz, wall_data, fh, door_data)

		if v_cor_set.has(rect.position.x - 1):
			var skip_l: bool = stairwell_v_set.has(rect.position.x - 1) and accessible_rects.has(rect.position)
			var vy_l: int = door_y
			if stairwell_v_set.has(rect.position.x - 1):
				vy_l = _door_row_clear(area, rect.position.y, rect.end.y, door_y)
			_place_edge_doors(area, f, "v", rect.position.x, rect.position.y, rect.end.y,
				vy_l, skip_l, wall_sz, wall_data, fh, door_data)

		if v_cor_set.has(rect.end.x):
			var skip_r: bool = stairwell_v_set.has(rect.end.x) and accessible_rects.has(rect.position)
			var vy_r: int = door_y
			if stairwell_v_set.has(rect.end.x):
				vy_r = _door_row_clear(area, rect.position.y, rect.end.y, door_y)
			_place_edge_doors(area, f, "v", rect.end.x - 1, rect.position.y, rect.end.y,
				vy_r, skip_r, wall_sz, wall_data, fh, door_data)


#One room edge: a wall run along "axis" with a single door at door_i unless skip_door.
static func _place_edge_doors(area: BattlefieldArea, f: int, axis: String, fixed: int,
		from_i: int, to_i: int, door_i: int, skip_door: bool,
		wall_sz: int, wall_data: ObstacleData, fh: int, door_data: ObstacleData) -> void:
	for i: int in range(from_i, to_i):
		var p3 := Vector3i(i, fixed, f) if axis == "h" else Vector3i(fixed, i, f)
		if i == door_i and not skip_door:
			place_door_at(area, p3, door_data, fh, axis)
		else:
			place_wall_if_empty(area, p3, wall_sz, wall_data, fh)
			area.building_interiors.erase(p3)


static func _partition_strip(area: BattlefieldArea, f: int, sx0: int, sy0: int, sw: int, sh: int,
		rooms: Array[ObstacleData], frame: BuildingFrame, result: Array[Dictionary], stairwell_x: int = -1,
		adj_x: int = -1, expand_right: bool = false) -> void:
	if rooms.is_empty():
		return
	var x_off: int = 0
	var room_idx: int = 0
	var sw_limit: int = sw if expand_right else sw - 1
	while x_off < sw_limit:
		var room: ObstacleData = rooms[room_idx % rooms.size()]
		room_idx += 1
		var base_w: int = maxi(3, ceili(room.size_x / 2.0))
		var rw: int = mini(clamp(base_w + randi_range(-1, 1), 3, sw_limit), sw_limit - x_off)
		if rw < 3 or x_off + rw > sw_limit:
			break
		for sx: int in [stairwell_x, adj_x]:
			if sx >= sx0 and sx < sx0 + sw_limit:
				var dist: int = sx - (sx0 + x_off)
				if dist > 0 and dist <= rw:
					rw = dist
		if rw < 3:
			break
		var has_div: bool = x_off + rw + 1 < sw
		if expand_right and x_off + rw < sw and sw - x_off - rw < 3:
			has_div = false
			rw = sw - x_off
		if not expand_right and has_div and x_off + rw == sw_limit - 1:
			var div_x: int = sx0 + x_off + rw
			if div_x != stairwell_x and div_x != adj_x:
				has_div = false
				rw = sw_limit - x_off
		var y_slots: Array = _strip_y_slots(rooms, room_idx, sh, rw)
		if has_div:
			_cut_strip_divider(area, f, sy0, sh, sx0 + x_off + rw, y_slots, stairwell_x, adj_x,
				WALL_SZ, frame.wall_data, frame.fh)
		_emit_strip_rooms(area, f, sx0, sy0, x_off, rw, y_slots, WALL_SZ, frame.wall_data, frame.fh, result)
		x_off += rw + (1 if has_div else 0)
		if x_off >= sw:
			break
	while x_off < sw:
		var col_x: int = sx0 + x_off
		if col_x == stairwell_x or col_x == adj_x:
			for iy: int in range(sy0, sy0 + sh):
				area.reserved_corridor_cells[Vector2i(col_x, iy)] = true
		elif x_off == sw - 1 and not expand_right:
			for iy: int in range(sy0, sy0 + sh):
				place_wall_if_empty(area, Vector3i(col_x, iy, f), WALL_SZ, frame.wall_data, frame.fh)
				area.building_interiors.erase(Vector3i(col_x, iy, f))
		x_off += 1


#Row slots for one room column: each entry is [y offset, height, divider below, room].
static func _strip_y_slots(rooms: Array[ObstacleData], room_idx: int, sh: int, rw: int) -> Array:
	var y_slots: Array = []
	var y_off: int = 0
	var y_room_idx: int = room_idx - 1
	while y_off < sh:
		var yroom: ObstacleData = rooms[y_room_idx % rooms.size()]
		y_room_idx += 1
		var sh_rem: int = sh - y_off
		var aspect_ratio: float = yroom.size_y / yroom.size_x if yroom.size_x > 0.0 else 1.0
		var target_rh: int = maxi(3, roundi(float(rw) * aspect_ratio))
		var rh: int = mini(clamp(target_rh + randi_range(-1, 1), 3, sh_rem), sh_rem)
		if rh < 3:
			break
		var has_h_div: bool = sh_rem - rh - 1 >= 3
		if not has_h_div:
			rh = sh_rem
		y_slots.append([y_off, rh, has_h_div, yroom])
		y_off += rh + (1 if has_h_div else 0)
	return y_slots


#The divider column on the right of one room column: a reservation at a stair hall, else a walled door.
static func _cut_strip_divider(area: BattlefieldArea, f: int, sy0: int, sh: int, div_x: int,
		y_slots: Array, stairwell_x: int, adj_x: int, wall_sz: int, wall_data: ObstacleData,
		fh: int) -> void:
	if div_x == stairwell_x or div_x == adj_x:
		for iy: int in range(sy0, sy0 + sh):
			area.reserved_corridor_cells[Vector2i(div_x, iy)] = true
	else:
		var mid_y: int = sy0 + (sh >> 1)
		var door_iy: int = -1
		for slot: Array in y_slots:
			var sly0: int = sy0 + (slot[0] as int)
			var sly1: int = sly0 + (slot[1] as int)
			if mid_y >= sly0 and mid_y < sly1:
				door_iy = mid_y
				break
		if door_iy == -1 and not y_slots.is_empty():
			var s0: Array = y_slots[0]
			door_iy = sy0 + (s0[0] as int) + ((s0[1] as int) >> 1)
		var div_door_data: ObstacleData = DataManager.door_data()
		_place_edge_doors(area, f, "v", div_x, sy0, sy0 + sh, door_iy, false, wall_sz, wall_data, fh, div_door_data)


#Rooms of one column plus the horizontal divider under each slot that has one.
static func _emit_strip_rooms(area: BattlefieldArea, f: int, sx0: int, sy0: int, x_off: int,
		rw: int, y_slots: Array, wall_sz: int, wall_data: ObstacleData, fh: int,
		result: Array[Dictionary]) -> void:
	for slot: Array in y_slots:
		var slot_y_off: int = slot[0] as int
		var slot_rh: int = slot[1] as int
		var slot_has_h_div: bool = slot[2] as bool
		var slot_room: ObstacleData = slot[3] as ObstacleData
		if slot_has_h_div:
			var div_y: int = sy0 + slot_y_off + slot_rh
			var door_ix: int = sx0 + x_off + (rw >> 1)
			var h_div_door: ObstacleData = DataManager.door_data()
			_place_edge_doors(area, f, "h", div_y, sx0 + x_off, sx0 + x_off + rw, door_ix, false,
				wall_sz, wall_data, fh, h_div_door)
		var room_rect := Rect2i(sx0 + x_off, sy0 + slot_y_off, rw, slot_rh)
		result.append({"room": slot_room, "rect": room_rect, "floor": f})
		area.interior_rooms.append({"rect": room_rect, "name": slot_room.obstacle_name, "floor": f})


static func place_door_at(area: BattlefieldArea, pos: Vector3i, door_data: ObstacleData, fh: int,
		orientation: String = "v") -> void:
	_clear_cell(area, pos)
	area.building_interiors.erase(pos)
	var door_obs := {"pos": pos, "size": 2, "data": door_data, "cell_type": "door", OpenCloseState.KEY: false,
		"orientation": orientation, "height": float(fh), "floor": pos.z}
	area.add_obstacle(door_obs, pos)


#Highest floor in the building; the run parity is measured down from it.
static func _top_floor(area: BattlefieldArea) -> int:
	var best: int = 0
	var first: bool = true
	for k: Variant in area.interior_floor_elevations.keys():
		var f: int = k as int
		if first or f > best:
			best = f
			first = false
	return best


#Climb direction of the run on floor f: +1 rises with y, -1 rises against it. Alternates by floor.
static func _run_up(area: BattlefieldArea, f: int) -> int:
	return 1 if ((_top_floor(area) - f) % 2) == 0 else -1


#Row of the street doors: the level corridor at the floor 0 end of the well; the middle row without a well.
static func _entrance_row(area: BattlefieldArea, top_y: int, floor_d: int, fh: int, num_floors: int) -> int:
	if num_floors <= 1:
		return top_y + 1 + (floor_d >> 1)
	var rows: Vector2i = stair_run_rows(top_y, floor_d, fh)
	return rows.x - 1 if _run_up(area, 1) > 0 else rows.y + 1


#Rows of every run: 2 * fh steps of half a pace, centered so level corridor remains beyond both ends.
static func stair_run_rows(top_y: int, floor_d: int, fh: int) -> Vector2i:
	var iy0: int = top_y + 1
	var iy1: int = top_y + floor_d
	var steps: int = 2 * fh
	var r0: int = ((iy0 + iy1) >> 1) - fh
	r0 = clampi(r0, iy0 + 1, maxi(iy0 + 1, iy1 - 1 - steps))
	return Vector2i(r0, mini(r0 + steps, iy1 - 1))


#True at rows where a well column is a tread or lies under one; no door opens onto them.
static func _well_row_blocked(area: BattlefieldArea, y: int) -> bool:
	var rows: Vector2i = stair_run_rows(area.interior_top_y, area.interior_floor_depth, area.interior_floor_height)
	return y >= rows.x and y < rows.y


#Value nearest want in [lo, hi) that passes ok; fallback when no value in the span does.
static func _nearest_clear(lo: int, hi: int, want: int, ok: Callable, fallback: int) -> int:
	if ok.call(want):
		return want
	for d: int in range(1, hi - lo):
		for cand: int in [want - d, want + d]:
			if cand >= lo and cand < hi and ok.call(cand):
				return cand
	return fallback


#Row nearest want in [y0, y1) where a well door opens onto level floor; -1 when the wall has none.
static func _door_row_clear(area: BattlefieldArea, y0: int, y1: int, want: int) -> int:
	return _nearest_clear(y0, y1, want, func(v: int) -> bool: return not _well_row_blocked(area, v), -1)


#Column nearest want in [x0, x1) that is not a stair column; want when none is.
static func _door_col_clear(stair_cols: Dictionary, x0: int, x1: int, want: int) -> int:
	return _nearest_clear(x0, x1, want, func(v: int) -> bool: return not stair_cols.has(v), want)


#True when any door sits in column x on any floor of the building.
static func _column_has_door(area: BattlefieldArea, x: int, fp: int, fm: int, top_y: int, floor_d: int) -> bool:
	for f: int in range(fp, -(fm + 1), -1):
		for iy: int in range(top_y + 1, top_y + floor_d + 1):
			if area.cell_type_at(Vector3i(x, iy, f)) == "door":
				return true
	return false


#One column pair for the whole building: adjacent vertical corridors on every floor, both door free.
static func _pick_stair_columns(area: BattlefieldArea, floor_v_cors: Dictionary, fp: int, fm: int,
		bld_x: int, floor_w: int, top_y: int, floor_d: int, fb_sx: int, fb_adj: int) -> Array[int]:
	var common: Dictionary = {}
	var first: bool = true
	for f: int in range(fp, -(fm + 1), -1):
		var vcors: Array = floor_v_cors.get(f, [])
		if first:
			for cx: int in vcors:
				common[cx] = true
			first = false
			continue
		for cx: Variant in common.keys():
			if not vcors.has(cx as int):
				common.erase(cx)
	var cands: Array[int] = []
	for cx: Variant in common.keys():
		var x: int = cx as int
		if x < bld_x + 1 or x + 1 > bld_x + floor_w or not common.has(x + 1):
			continue
		if _column_has_door(area, x, fp, fm, top_y, floor_d):
			continue
		if _column_has_door(area, x + 1, fp, fm, top_y, floor_d):
			continue
		cands.append(x)
	if cands.is_empty():
		return [fb_sx, fb_adj]
	cands.sort()
	var pick: int = cands[randi() % cands.size()]
	return [pick, pick + 1]


#One well per building: the run on floor f takes one column, the next run takes the neighbour and
#climbs back the other way, so its landing sits beside the top of the run below it.
static func place_stairwells(area: BattlefieldArea, fp: int, fm: int, bld_x: int, floor_w: int, floor_d: int,
		stairs_data: ObstacleData, stairwell_xs: Dictionary, stairwell_adj_xs: Dictionary, top_y: int) -> void:
	var run_rows: Vector2i = stair_run_rows(top_y, floor_d, area.interior_floor_height)
	var upper_y: int = run_rows.y
	var lower_y: int = run_rows.x
	for f: int in range(fp, -fm, -1):
		var sx: int = stairwell_xs.get(f, bld_x + 1 + (floor_w >> 1))
		var adj_x: int = stairwell_adj_xs.get(f, -1)
		if adj_x == -1:
			adj_x = _stair_adj_x(sx, bld_x, floor_w)
		var up: int = _run_up(area, f)
		var col: int = sx if up > 0 else adj_x
		var top_row: int = upper_y if up > 0 else lower_y
		var bot_row: int = lower_y if up > 0 else upper_y
		var top_cell := Vector3i(col, top_row, f)
		if area.ceiling_cells.has(top_cell):
			_clear_cell(area, top_cell)
			area.ceiling_cells.erase(top_cell)
		for cy: int in range(lower_y, upper_y + 1):
			var sv := Vector3i(col, cy, f)
			_clear_cell(area, sv)
			area.building_interiors[sv] = true
			area.stair_run_cells[sv] = true
		if area.interior_floor_elevations.has(f - 1):
			var landing := Vector3i(col, bot_row, f - 1)
			_clear_cell(area, landing)
			area.building_interiors[landing] = true
			area.stair_run_cells[landing] = true
		#stairwell at floor f connects f to f-1; cell is on floor f at the run top
		area.stairwell_cells[top_cell] = true
		if stairs_data != null:
			var upper := Vector3i(col, top_row, f)
			var lower := Vector3i(col, bot_row, f - 1)
			area.stairwell_connections[upper] = lower
			area.stairwell_connections[lower] = upper
			if area.building_interiors.has(upper):
				_clear_cell(area, upper)
				area.building_interiors[upper] = true
				var up_obs := {"pos": upper, "size": stairs_data.size, "data": stairs_data, "cell_type": "stairs", "floor": f}
				area.add_obstacle(up_obs, upper)
			if area.building_interiors.has(lower):
				_clear_cell(area, lower)
				area.building_interiors[lower] = true
				var lo_obs := {"pos": lower, "size": stairs_data.size, "data": stairs_data, "cell_type": "stairs", "floor": f - 1}
				area.add_obstacle(lo_obs, lower)


#Cell flags of one room for the furniture pass; index = (x - rect.position.x) * h + (y - rect.position.y).
class FurnGrid:
	var rect: Rect2i = Rect2i()
	var f: int = 0
	var w: int = 0
	var h: int = 0
	var walk: PackedByteArray = PackedByteArray()
	var free: PackedByteArray = PackedByteArray()
	var entry: PackedByteArray = PackedByteArray()
	var ap: PackedByteArray = PackedByteArray()
	var walk_count: int = 0
	var free_count: int = 0
	var ap_fresh: bool = false
	var accessible: bool = false


#Builds the flags from _obs_map; the furniture pass keeps them in step through _grid_mark.
static func _furn_grid(area: BattlefieldArea, rect: Rect2i, f: int) -> FurnGrid:
	var g := FurnGrid.new()
	g.rect = rect
	g.f = f
	g.w = maxi(0, rect.size.x)
	g.h = maxi(0, rect.size.y)
	var n: int = g.w * g.h
	var walk := _zeroed(n)
	var free := _zeroed(n)
	var entry := _zeroed(n)
	var ap := _zeroed(n)
	var i: int = 0
	for ix: int in range(rect.position.x, rect.end.x):
		for iy: int in range(rect.position.y, rect.end.y):
			var p3 := Vector3i(ix, iy, f)
			var ct: String = area.cell_type_at(p3)
			var near_door: bool = false
			for off: Vector3i in OFF4:
				if area.cell_type_at(p3 + off) == "door" \
						or area.gate_cells.has(p3 + off):
					near_door = true
					break
			if not ct in ["wall", "fence", "furniture", "reserved"]:
				walk[i] = 1
				g.walk_count += 1
				if near_door:
					entry[i] = 1
			if not near_door and not area._obs_map.has(p3) and not area.reserved_corridor_cells.has(Vector2i(ix, iy)):
				free[i] = 1
				g.free_count += 1
			i += 1
	g.walk = walk
	g.free = free
	g.entry = entry
	g.ap = ap
	return g


#A byte array of n zeros.
static func _zeroed(n: int) -> PackedByteArray:
	var a := PackedByteArray()
	a.resize(n)
	a.fill(0)
	return a


#Free cells in x then y order, the order the furniture shuffles depend on.
static func _grid_free_list(g: FurnGrid, skip_ap: bool) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var free: PackedByteArray = g.free
	var ap: PackedByteArray = g.ap
	var i: int = 0
	for ix: int in range(g.rect.position.x, g.rect.end.x):
		for iy: int in range(g.rect.position.y, g.rect.end.y):
			if free[i] == 1 and not (skip_ap and ap[i] == 1):
				out.append(Vector3i(ix, iy, g.f))
			i += 1
	return out


#Sets or clears a furniture footprint; every cell of it was free, so it was walkable too.
static func _grid_mark(g: FurnGrid, pos: Vector3i, pw: int, ph: int, value: int) -> void:
	var walk: PackedByteArray = g.walk
	var free: PackedByteArray = g.free
	for dx: int in range(pw):
		for dy: int in range(ph):
			var i: int = (pos.x + dx - g.rect.position.x) * g.h + (pos.y + dy - g.rect.position.y)
			walk[i] = value
			free[i] = value
	g.walk = walk
	g.free = free
	var cells: int = pw * ph
	if value == 1:
		g.walk_count += cells
		g.free_count += cells
	else:
		g.walk_count -= cells
		g.free_count -= cells


#Walk cells reached from the seeds over 4-neighbours.
static func _grid_flood(g: FurnGrid, seeds: PackedInt32Array) -> int:
	var n: int = g.w * g.h
	var h: int = g.h
	var walk: PackedByteArray = g.walk
	var seen := PackedByteArray()
	seen.resize(n)
	seen.fill(0)
	var stack := PackedInt32Array()
	var reached: int = 0
	for s: int in seeds:
		if seen[s] == 0:
			seen[s] = 1
			stack.push_back(s)
			reached += 1
	var push := func(v: int) -> int:
		if walk[v] == 1 and seen[v] == 0:
			seen[v] = 1
			stack.push_back(v)
			return 1
		return 0
	while not stack.is_empty():
		var top: int = stack.size() - 1
		var u: int = stack[top]
		stack.remove_at(top)
		var row: int = u % h
		if u + h < n:
			reached += push.call(u + h) as int
		if u - h >= 0:
			reached += push.call(u - h) as int
		if row != h - 1:
			reached += push.call(u + 1) as int
		if row != 0:
			reached += push.call(u - 1) as int
	return reached


#Every walk cell is reached from the door cells, and parts touching only a shared door force one region.
static func _grid_accessible(g: FurnGrid) -> bool:
	if g.walk_count == 0:
		return true
	var walk: PackedByteArray = g.walk
	var entry: PackedByteArray = g.entry
	var first: int = -1
	var entries := PackedInt32Array()
	for i: int in range(g.w * g.h):
		if walk[i] == 0:
			continue
		if first < 0:
			first = i
		if entry[i] == 1:
			entries.push_back(i)
	var one := PackedInt32Array([first])
	if entries.is_empty():
		return _grid_flood(g, one) == g.walk_count
	if _grid_flood(g, entries) != g.walk_count:
		return false
	return _grid_flood(g, one) == g.walk_count


#Articulation points of the walk cells, written to g.ap.
static func _grid_articulation(g: FurnGrid) -> void:
	var n: int = g.w * g.h
	var h: int = g.h
	var walk: PackedByteArray = g.walk
	var ap := PackedByteArray()
	ap.resize(n)
	ap.fill(0)
	var disc := PackedInt32Array()
	disc.resize(n)
	disc.fill(-1)
	var low := PackedInt32Array()
	low.resize(n)
	low.fill(0)
	var parent := PackedInt32Array()
	parent.resize(n)
	parent.fill(-1)
	var next_dir := PackedByteArray()
	next_dir.resize(n)
	next_dir.fill(0)
	var stack := PackedInt32Array()
	var timer: int = 0
	for root: int in range(n):
		if walk[root] == 0 or disc[root] != -1:
			continue
		disc[root] = timer
		low[root] = timer
		timer += 1
		var root_children: int = 0
		stack.push_back(root)
		while not stack.is_empty():
			var top: int = stack.size() - 1
			var u: int = stack[top]
			var dir: int = next_dir[u]
			if dir < 4:
				next_dir[u] = dir + 1
				var v: int = -1
				if dir == 0:
					if u + h < n:
						v = u + h
				elif dir == 1:
					if u - h >= 0:
						v = u - h
				elif dir == 2:
					if u % h != h - 1:
						v = u + 1
				elif u % h != 0:
					v = u - 1
				if v < 0 or walk[v] == 0:
					continue
				if disc[v] == -1:
					parent[v] = u
					disc[v] = timer
					low[v] = timer
					timer += 1
					if u == root:
						root_children += 1
					stack.push_back(v)
				elif v != parent[u] and disc[v] < low[u]:
					low[u] = disc[v]
			else:
				stack.remove_at(top)
				var p: int = parent[u]
				if p >= 0:
					if low[u] < low[p]:
						low[p] = low[u]
					if p != root and low[u] >= disc[p]:
						ap[p] = 1
		if root_children > 1:
			ap[root] = 1
	g.ap = ap
	g.ap_fresh = true


static func place_furniture_in_rooms(area: BattlefieldArea, room_list: Array[Dictionary]) -> void:
	var total_cells: int = 0
	for entry: Dictionary in room_list:
		total_cells += (entry["rect"] as Rect2i).size.x * (entry["rect"] as Rect2i).size.y
	var s_min: int = maxi(1, floori(float(total_cells) / 40.0))
	var s_max: int = maxi(s_min + 1, floori(float(total_cells) / 15.0))
	var scatter_left: int = randi_range(s_min, s_max)

	for entry: Dictionary in room_list:
		var room: ObstacleData = entry["room"] as ObstacleData
		var rect: Rect2i = entry["rect"] as Rect2i
		var f: int = entry.get("floor", 0) as int

		var g: FurnGrid = _furn_grid(area, rect, f)
		g.accessible = _grid_accessible(g)

		var base_free: Array[Vector3i] = _grid_free_list(g, false)
		var wadj: Dictionary = _wall_adj_set(area, base_free)
		var corners: Dictionary = _corner_set(area, base_free, wadj)
		var wadjwin: Dictionary = _window_adj_set(area, base_free)

		var obj_adj: Dictionary = {}
		var placed_alike: Dictionary = {}

		for sname: String in room.guaranteed_structures:
			var pfree: Array[Vector3i] = _free_non_articulation(g)
			pfree.shuffle()
			_place_pref(area, sname, pfree, g, wadj, corners, wadjwin, obj_adj, placed_alike)

		if not room.possible_structures.is_empty():
			var avail: int = g.free_count
			for _i: int in range(maxi(0, floori(float(avail) / 3.0))):
				var pfree: Array[Vector3i] = _free_non_articulation(g)
				pfree.shuffle()
				var sname: String = room.possible_structures[randi() % room.possible_structures.size()]
				_place_pref(area, sname, pfree, g, wadj, corners, wadjwin, obj_adj, placed_alike)

		if room.possible_scatter.is_empty() or scatter_left <= 0:
			continue

		var free2_init: Array[Vector3i] = _free_non_articulation(g)
		if free2_init.is_empty():
			continue

		var room_total: int = rect.size.x * rect.size.y
		var free_ratio: float = float(free2_init.size()) / float(maxi(1, room_total))
		var room_max: int = maxi(0, roundi(float(free2_init.size()) * free_ratio * 0.4))
		var count: int = mini(room_max, scatter_left)
		if count <= 0:
			continue

		var wadj2: Dictionary = _wall_adj_set(area, free2_init)
		var corners2: Dictionary = _corner_set(area, free2_init, wadj2)
		var wadjwin2: Dictionary = _window_adj_set(area, free2_init)

		for _s: int in range(count):
			var free2: Array[Vector3i] = _free_non_articulation(g)
			if free2.is_empty():
				break
			free2.shuffle()
			var sname: String = room.possible_scatter[randi() % room.possible_scatter.size()]
			if _place_pref(area, sname, free2, g, wadj2, corners2, wadjwin2, obj_adj, placed_alike):
				scatter_left -= 1
			if scatter_left <= 0:
				break


#Free cells minus the articulation points; the point set is reused until a placement changes the room.
static func _free_non_articulation(g: FurnGrid) -> Array[Vector3i]:
	if not g.ap_fresh:
		_grid_articulation(g)
	return _grid_free_list(g, true)


static func _wall_adj_set(area: BattlefieldArea, free: Array[Vector3i]) -> Dictionary:
	var result: Dictionary = {}
	for p: Vector3i in free:
		for off: Vector3i in OFF4:
			if area.cell_type_at(p + off) == "wall":
				result[p] = true
				break
	return result


static func _corner_set(area: BattlefieldArea, free: Array[Vector3i], wadj: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for p: Vector3i in free:
		if not wadj.has(p):
			continue
		var has_nx: bool = area.cell_type_at(p + Vector3i(-1, 0, 0)) == "wall"
		var has_px: bool = area.cell_type_at(p + Vector3i(1, 0, 0)) == "wall"
		var has_ny: bool = area.cell_type_at(p + Vector3i(0, -1, 0)) == "wall"
		var has_py: bool = area.cell_type_at(p + Vector3i(0, 1, 0)) == "wall"
		if (has_nx or has_px) and (has_ny or has_py):
			result[p] = true
	return result


static func _window_adj_set(area: BattlefieldArea, free: Array[Vector3i]) -> Dictionary:
	var result: Dictionary = {}
	for p: Vector3i in free:
		for off: Vector3i in OFF4:
			var e: Dictionary = area._obs_map.get(p + off, {}) as Dictionary
			var d2: ObstacleData = e.get("data", null)
			if d2 != null and d2.obstacle_name == "Window":
				result[p] = true
				break
	return result


static func room_accessible_from_doors(area: BattlefieldArea, rect: Rect2i, f: int) -> bool:
	return _grid_accessible(_furn_grid(area, rect, f))


static func _footprint_free(g: FurnGrid, origin: Vector3i, pw: int, ph: int) -> bool:
	for dx: int in range(pw):
		for dy: int in range(ph):
			var lx: int = origin.x + dx - g.rect.position.x
			var ly: int = origin.y + dy - g.rect.position.y
			if lx < 0 or ly < 0 or lx >= g.w or ly >= g.h:
				return false
			var i: int = lx * g.h + ly
			if g.free[i] == 0 or g.ap[i] == 1:
				return false
	return true


#Wall hugging footprints for one furniture size; restrict, when non empty, limits the cells scanned.
static func _wall_candidates(area: BattlefieldArea, g: FurnGrid, free: Array[Vector3i], ceil_x: int,
		ceil_y: int, kinds: Array, restrict: Dictionary) -> Array:
	var out: Array = []
	var pw_wide: int = maxi(ceil_x, ceil_y)
	var ph_wide: int = mini(ceil_x, ceil_y)
	var limited: bool = not restrict.is_empty()
	for p: Vector3i in free:
		if limited and not restrict.has(p):
			continue
		var has_ny: bool = area.cell_type_at(p + Vector3i(0, -1, 0)) in kinds
		var has_py: bool = area.cell_type_at(p + Vector3i(0, 1, 0)) in kinds
		var has_nx: bool = area.cell_type_at(p + Vector3i(-1, 0, 0)) in kinds
		var has_px: bool = area.cell_type_at(p + Vector3i(1, 0, 0)) in kinds
		if has_ny:
			var o := Vector3i(p.x, p.y, p.z)
			if _footprint_free(g, o, pw_wide, ph_wide):
				out.append([o, pw_wide, ph_wide])
		if has_py:
			var o := Vector3i(p.x, p.y - ph_wide + 1, p.z)
			if _footprint_free(g, o, pw_wide, ph_wide):
				out.append([o, pw_wide, ph_wide])
		if has_nx:
			var o := Vector3i(p.x, p.y, p.z)
			if _footprint_free(g, o, ph_wide, pw_wide):
				out.append([o, ph_wide, pw_wide])
		if has_px:
			var o := Vector3i(p.x - ph_wide + 1, p.y, p.z)
			if _footprint_free(g, o, ph_wide, pw_wide):
				out.append([o, ph_wide, pw_wide])
	return out


#Every free cell whose w by h footprint is clear, as [origin, w, h] in the order of free.
static func _any_footprint(free: Array[Vector3i], g: FurnGrid, w: int, h: int) -> Array:
	var out: Array = []
	for p: Vector3i in free:
		if _footprint_free(g, p, w, h):
			out.append([p, w, h])
	return out


#Footprints [origin, pw, ph] that suit one preferred position, before the any cell fallback.
static func _candidates_for(pref: String, area: BattlefieldArea, obs_name: String, free: Array[Vector3i], g: FurnGrid,
		ceil_x: int, ceil_y: int, force_wall: bool, wadj: Dictionary, corners: Dictionary, wadjwin: Dictionary,
		obj_adj: Dictionary, placed_alike: Dictionary) -> Array:
	var rect: Rect2i = g.rect
	var orient_list: Array = [[ceil_x, ceil_y]] if ceil_x == ceil_y else [[ceil_x, ceil_y], [ceil_y, ceil_x]]
	var candidates: Array = []

	match pref:
		"Corner":
			for p: Vector3i in free:
				if not corners.has(p):
					continue
				var has_nx: bool = area.cell_type_at(p + Vector3i(-1, 0, 0)) == "wall"
				var has_ny: bool = area.cell_type_at(p + Vector3i(0, -1, 0)) == "wall"
				for orient in orient_list:
					var pw: int = orient[0] as int
					var ph: int = orient[1] as int
					var ox: int = p.x if has_nx else (p.x - pw + 1)
					var oy: int = p.y if has_ny else (p.y - ph + 1)
					var origin := Vector3i(ox, oy, p.z)
					if _footprint_free(g, origin, pw, ph):
						candidates.append([origin, pw, ph])
		"Any Wall":
			candidates = _wall_candidates(area, g, free, ceil_x, ceil_y, ["wall"], wadj)
		"Window":
			for p: Vector3i in free:
				if not wadjwin.has(p):
					continue
				for orient in orient_list:
					var pw: int = orient[0] as int
					var ph: int = orient[1] as int
					if _footprint_free(g, p, pw, ph):
						candidates.append([p, pw, ph])
						break
		"By Object", "On Object":
			for p: Vector3i in free:
				if not obj_adj.has(p):
					continue
				var src: Dictionary = obj_adj[p] as Dictionary if obj_adj[p] is Dictionary else {}
				var src_pw: int = src.get("pw", 1) as int
				var src_ph: int = src.get("ph", 1) as int
				var orders: Array
				if ceil_x == ceil_y:
					orders = [[ceil_x, ceil_y]]
				elif src_pw > src_ph:
					orders = [[maxi(ceil_x, ceil_y), mini(ceil_x, ceil_y)], [mini(ceil_x, ceil_y), maxi(ceil_x, ceil_y)]]
				elif src_ph > src_pw:
					orders = [[mini(ceil_x, ceil_y), maxi(ceil_x, ceil_y)], [maxi(ceil_x, ceil_y), mini(ceil_x, ceil_y)]]
				else:
					orders = [[ceil_x, ceil_y], [ceil_y, ceil_x]]
				for orient in orders:
					var pw: int = orient[0] as int
					var ph: int = orient[1] as int
					if _footprint_free(g, p, pw, ph):
						candidates.append([p, pw, ph])
						break
		"Align Alike":
			if not placed_alike.has(obs_name):
				candidates = _any_footprint(free, g, ceil_x, ceil_y)
			else:
				var cset: Dictionary = {}
				for entry in (placed_alike[obs_name] as Array):
					var pp: Vector3i = (entry as Array)[0] as Vector3i
					var epw: int = (entry as Array)[1] as int
					var eph: int = (entry as Array)[2] as int
					var mx: int = rect.position.x + rect.end.x - pp.x - epw
					var my: int = rect.position.y + rect.end.y - pp.y - eph
					cset[Vector3i(mx, pp.y, pp.z)] = [epw, eph]
					cset[Vector3i(pp.x, my, pp.z)] = [epw, eph]
					cset[Vector3i(mx, my, pp.z)] = [epw, eph]
				for p: Vector3i in free:
					if cset.has(p):
						var dims: Array = cset[p] as Array
						var pw: int = dims[0] as int
						var ph: int = dims[1] as int
						if _footprint_free(g, p, pw, ph):
							candidates.append([p, pw, ph])
		_:
			if force_wall:
				candidates = _wall_candidates(area, g, free, ceil_x, ceil_y, ["wall", "fence"], {})
			else:
				candidates = _any_footprint(free, g, ceil_x, ceil_y)
	return candidates


static func _place_pref(
	area: BattlefieldArea,
	obs_name: String,
	free: Array[Vector3i],
	g: FurnGrid,
	wadj: Dictionary,
	corners: Dictionary,
	wadjwin: Dictionary,
	obj_adj: Dictionary,
	placed_alike: Dictionary
) -> bool:
	var d: ObstacleData = DataManager.get_obstacle_by_name(obs_name)
	if d == null:
		return false
	var rect: Rect2i = g.rect
	var pref: String = d.preferred_position
	var ceil_x: int = ceili(d.size_x)
	var ceil_y: int = ceili(d.size_y)
	var no_fallback: bool = pref == "Align Alike" and placed_alike.has(obs_name)
	var narrow_short: int = mini(rect.size.x, rect.size.y) - 2
	var force_wall: bool = (pref == "Anywhere" or pref == "") and (mini(ceil_x, ceil_y) >= maxi(1, narrow_short))
	#An open shell has no wall to hug.
	if force_wall and String(area.building_plan.get("shell", "")) == "Open":
		force_wall = false
	var candidates: Array = _candidates_for(pref, area, obs_name, free, g, ceil_x, ceil_y, force_wall, wadj, corners,
		wadjwin, obj_adj, placed_alike)

	if candidates.is_empty():
		if no_fallback or force_wall:
			return false
		candidates = _any_footprint(free, g, ceil_x, ceil_y)
		if candidates.is_empty():
			return false

	candidates.shuffle()
	for cand: Array in candidates:
		if not _try_place(area, g, cand, d):
			continue
		var pos: Vector3i = cand[0] as Vector3i
		var pw: int = cand[1] as int
		var ph: int = cand[2] as int
		_mark_adjacent(obj_adj, pos, pw, ph)
		if pref == "Align Alike":
			if not placed_alike.has(obs_name):
				placed_alike[obs_name] = []
			(placed_alike[obs_name] as Array).append([pos, pw, ph])
		return true
	return false


#Adds one furniture piece at cand and keeps it only while every free cell of the room stays reachable.
static func _try_place(area: BattlefieldArea, g: FurnGrid, cand: Array, d: ObstacleData) -> bool:
	var pos: Vector3i = cand[0] as Vector3i
	var pw: int = cand[1] as int
	var ph: int = cand[2] as int
	var obs := {"pos": pos, "size": pw * ph, "data": d, "cell_type": "furniture", "pw": pw, "ph": ph, "floor": pos.z}
	area.add_obstacle(obs, pos)
	var extra_cells: Array[Vector3i] = []
	for dx: int in range(pw):
		for dy: int in range(ph):
			if dx == 0 and dy == 0:
				continue
			var extra := Vector3i(pos.x + dx, pos.y + dy, pos.z)
			if not area._obs_map.has(extra):
				area._obs_map[extra] = {"cell_type": "reserved", "floor": pos.z}
				extra_cells.append(extra)
	_grid_mark(g, pos, pw, ph, 0)
	var fits: bool = true
	#A lone cell that is no articulation point cannot split a room that was whole.
	if pw * ph > 1 or not g.accessible:
		fits = _grid_accessible(g)
	if not fits:
		_grid_mark(g, pos, pw, ph, 1)
		area.obstacles.pop_back()
		area._obs_map.erase(pos)
		for ep: Vector3i in extra_cells:
			area._obs_map.erase(ep)
		return false
	g.accessible = true
	g.ap_fresh = false
	return true


#Records the size of a placed footprint on every cell bordering it, corners included, for By Object pieces.
static func _mark_adjacent(obj_adj: Dictionary, pos: Vector3i, pw: int, ph: int) -> void:
	for dx: int in range(-1, pw + 1):
		obj_adj[Vector3i(pos.x + dx, pos.y - 1, pos.z)] = {"pw": pw, "ph": ph}
		obj_adj[Vector3i(pos.x + dx, pos.y + ph, pos.z)] = {"pw": pw, "ph": ph}
	for dy: int in range(ph):
		obj_adj[Vector3i(pos.x - 1, pos.y + dy, pos.z)] = {"pw": pw, "ph": ph}
		obj_adj[Vector3i(pos.x + pw, pos.y + dy, pos.z)] = {"pw": pw, "ph": ph}


static func _assign_spawns(area: BattlefieldArea, ctx: GenerationContext, bld_x: int, floor_w: int, floor_d: int, top_y: int) -> void:
	var max_team: int = maxi(ctx.team_size_a, ctx.team_size_b)
	area.spawn_radius = maxf(3.0, float(max_team))
	area.spawn_radius = minf(area.spawn_radius, minf(float(floor_w), float(floor_d)) / 2.0)

	var half: int = maxi(1, floor_w >> 1)
	area.spawn_center_a = Vector2i(bld_x + 1 + (half >> 1), top_y + 1 + (floor_d >> 1))
	area.spawn_center_b = Vector2i(bld_x + 1 + half + ((floor_w - half) >> 1), top_y + 1 + (floor_d >> 1))
	var split: int = bld_x + 1 + half
	for key: Variant in area.building_interiors.keys():
		var c: Vector3i = key as Vector3i
		if c.z != 0 or area._obs_map.has(c):
			continue
		var p := Vector2i(c.x, c.y)
		if c.x < split:
			area.spawn_zone_a[p] = true
		else:
			area.spawn_zone_b[p] = true


static func _place_exterior_rooms(area: BattlefieldArea, f: int, frame: BuildingFrame, area_data: Dictionary,
		street: int, all_rooms: Array[Dictionary], side: String = "") -> void:
	if f < 0:
		return
	var eligible: Array[ObstacleData] = RoomCatalog.get_exterior_rooms_for_floor(area_data, f)
	if eligible.is_empty():
		return
	eligible.shuffle()
	var room: ObstacleData = eligible[0]
	var max_ext_w: int = street - 1
	if max_ext_w < 2:
		return
	var ext_w: int = randi_range(2, max_ext_w)
	var use_right: bool
	if side == "":
		use_right = (f == 0) or (randi() % 2 == 0)
	else:
		use_right = side == "E"
	var fence_data: ObstacleData = DataManager.get_obstacle_by_name("Fence")
	if fence_data == null:
		fence_data = frame.wall_data

	var top_y: int = frame.top_y
	var floor_d: int = frame.floor_d
	var bld_wall_x: int
	var ix_start: int
	var ix_end: int
	var far_wall_x: int
	if use_right:
		bld_wall_x = frame.bld_x + frame.floor_w + 1
		ix_start = bld_wall_x + 1
		ix_end = ix_start + ext_w
		far_wall_x = ix_end
	else:
		bld_wall_x = frame.bld_x
		ix_end = bld_wall_x
		ix_start = ix_end - ext_w
		far_wall_x = ix_start - 1

	for ix: int in range(ix_start, ix_end):
		for iy: int in range(top_y + 1, top_y + floor_d + 1):
			area.building_interiors[Vector3i(ix, iy, f)] = true

	var w_x_lo: int = mini(far_wall_x, ix_start)
	var w_x_hi: int = maxi(far_wall_x, ix_end - 1)
	for ix: int in range(w_x_lo, w_x_hi + 1):
		_place_fence_if_empty(area, Vector3i(ix, top_y, f), fence_data, f, "h")
		_place_fence_if_empty(area, Vector3i(ix, top_y + floor_d + 1, f), fence_data, f, "h")

	var door_y: int = top_y + 2 + (floor_d >> 1)
	for iy: int in range(top_y, top_y + floor_d + 2):
		if f == 0 and iy == door_y:
			area.gate_cells[Vector3i(far_wall_x, iy, f)] = true
			continue
		_place_fence_if_empty(area, Vector3i(far_wall_x, iy, f), fence_data, f)

	var adj_x: int = bld_wall_x + (-1 if use_right else 1)
	if area._obs_map.has(Vector3i(adj_x, door_y, f)):
		var mid_y: int = door_y
		var best_dist: int = floor_d + 1
		for try_y: int in range(top_y + 1, top_y + floor_d + 1):
			if not area._obs_map.has(Vector3i(adj_x, try_y, f)):
				var dist: int = absi(try_y - mid_y)
				if dist < best_dist:
					best_dist = dist
					door_y = try_y
	var door_data: ObstacleData = DataManager.door_data()
	place_door_at(area, Vector3i(bld_wall_x, door_y, f), door_data, frame.fh)

	var rect := Rect2i(ix_start, top_y + 1, ext_w, floor_d)
	area.interior_rooms.append({"rect": rect, "name": room.obstacle_name, "floor": f})
	all_rooms.append({"room": room, "rect": rect, "floor": f})


static func _place_fence_if_empty(area: BattlefieldArea, pos: Vector3i, fence_data: ObstacleData, floor_num: int = -999, orientation: String = "v") -> void:
	if area._obs_map.has(pos):
		return
	var obs := {"pos": pos, "size": fence_data.size if fence_data != null else 2, "data": fence_data, "cell_type": "fence", "floor": floor_num, "orientation": orientation}
	area.add_obstacle(obs, pos)


#A divider door placed on the next column's wall row faces a wall; it slides along its wall to a row open on both sides.
static func _fix_blind_doors(area: BattlefieldArea) -> void:
	var doors: Array[Dictionary] = []
	for obs: Dictionary in area.obstacles:
		if obs.get("cell_type", "") == "door" and typeof(obs.get("pos")) == TYPE_VECTOR3I:
			doors.append(obs)
	for door: Dictionary in doors:
		var pos: Vector3i = door["pos"] as Vector3i
		var orientation: String = door.get("orientation", "v") as String
		var across := Vector3i(1, 0, 0) if orientation == "v" else Vector3i(0, 1, 0)
		var along := Vector3i(0, 1, 0) if orientation == "v" else Vector3i(1, 0, 0)
		if not _door_is_blind(area, pos, across):
			continue
		for step: int in [1, -1, 2, -2, 3, -3]:
			var cand: Vector3i = pos + along * step
			var wall: Dictionary = area._obs_map.get(cand, {}) as Dictionary
			if wall.get("cell_type", "") != "wall" or not _door_sides_open(area, cand, across):
				continue
			var fh: int = int(door.get("height", 4.0) as float)
			var door_data: ObstacleData = door.get("data") as ObstacleData
			var wall_data: ObstacleData = wall.get("data") as ObstacleData
			var wall_sz: int = wall.get("size", 1) as int
			_clear_cell(area, pos)
			place_wall_if_empty(area, pos, wall_sz, wall_data, fh)
			area.building_interiors.erase(pos)
			place_door_at(area, cand, door_data, fh, orientation)
			area.generation_log.append("[GEN] blind door F%d (%d,%d) moved to (%d,%d)" % [pos.z, pos.x, pos.y, cand.x, cand.y])
			break


static func _door_is_blind(area: BattlefieldArea, pos: Vector3i, across: Vector3i) -> bool:
	var walls: int = 0
	var open: int = 0
	for side: Vector3i in [pos - across, pos + across]:
		if area.cell_type_at(side) == "wall":
			walls += 1
		elif not area._obs_map.has(side) and area.building_interiors.has(side):
			open += 1
	return walls == 1 and open == 1


static func _door_sides_open(area: BattlefieldArea, pos: Vector3i, across: Vector3i) -> bool:
	for side: Vector3i in [pos - across, pos + across]:
		if area._obs_map.has(side) or not area.building_interiors.has(side):
			return false
	return true


#One door through the wall a wing shares with the main block, a second at 40% on a long wing.
static func _place_wing_doors(area: BattlefieldArea, wings: Array[Dictionary], f: int, top_y: int,
		floor_d: int, stairwell_xs: Dictionary, fh: int) -> void:
	var door_data: ObstacleData = DataManager.door_data()
	var sw: Dictionary = {}
	for v: Variant in stairwell_xs.values():
		sw[int(v)] = true
	for wing: Dictionary in wings:
		var north: bool = String(wing["side"]) == "n"
		var row: int = top_y if north else top_y + floor_d + 1
		var in_y: int = row - 1 if north else row + 1
		var main_y: int = row + 1 if north else row - 1
		var x0: int = int(wing["x0"])
		var wlen: int = int(wing["len"])
		var mid: int = x0 + (wlen >> 1)
		var open_c: Array[int] = []
		var any_c: Array[int] = []
		for dx: int in range(wlen):
			var x: int = x0 + dx
			if sw.has(x):
				continue
			any_c.append(x)
			if not area._obs_map.has(Vector3i(x, in_y, f)) and not area._obs_map.has(Vector3i(x, main_y, f)):
				open_c.append(x)
		var picks: Array[int] = any_c
		if not open_c.is_empty():
			picks = open_c
		if picks.is_empty():
			continue
		picks.sort_custom(func(a: int, b: int) -> bool: return absi(a - mid) < absi(b - mid))
		_cut_wing_door(area, picks[0], row, in_y, main_y, f, door_data, fh)
		if wlen < 9 or randi() % 100 >= 40:
			continue
		for x2: int in picks:
			if absi(x2 - picks[0]) >= 3:
				_cut_wing_door(area, x2, row, in_y, main_y, f, door_data, fh)
				break


#Opens the two cells across a shared wall and cuts the door between them.
static func _cut_wing_door(area: BattlefieldArea, x: int, row: int, in_y: int, main_y: int, f: int,
		door_data: ObstacleData, fh: int) -> void:
	_open_wing_cell(area, Vector3i(x, in_y, f))
	_open_wing_cell(area, Vector3i(x, main_y, f))
	place_door_at(area, Vector3i(x, row, f), door_data, fh, "h")


static func _open_wing_cell(area: BattlefieldArea, pos: Vector3i) -> void:
	var ct: String = area.cell_type_at(pos)
	if ct != "" and ct != "wall":
		return
	_clear_cell(area, pos)
	area.building_interiors[pos] = true


#Cuts doors into shared walls until the open cells of one floor form a single region.
static func _connect_floor_regions(area: BattlefieldArea, f: int, fh: int) -> void:
	var door_data: ObstacleData = DataManager.door_data()
	for _pass: int in range(REGION_PASSES):
		var reg: Dictionary = _floor_regions(area, f)
		var count: int = int(reg["count"])
		if count <= 1:
			return
		var ids: Dictionary = reg["ids"] as Dictionary
		var sizes: Dictionary = reg["sizes"] as Dictionary
		var best := Vector3i(0, 0, 0)
		var best_orient: String = "v"
		var best_score: int = -1
		for key: Variant in area._obs_map.keys():
			var c: Vector3i = key as Vector3i
			if c.z != f:
				continue
			if area.cell_type_at(c) != "wall":
				continue
			if _on_mask_edge(area, c):
				continue
			for pair: int in range(2):
				var d := Vector2i(1, 0) if pair == 0 else Vector2i(0, 1)
				var a := Vector3i(c.x - d.x, c.y - d.y, f)
				var b := Vector3i(c.x + d.x, c.y + d.y, f)
				if not ids.has(a) or not ids.has(b) or int(ids[a]) == int(ids[b]):
					continue
				var score: int = maxi(int(sizes[int(ids[a])]), int(sizes[int(ids[b])]))
				if score > best_score:
					best_score = score
					best = c
					best_orient = "v" if pair == 0 else "h"
		if best_score < 0:
			area.generation_log.append("[GEN] F%d: %d regions left" % [f, count])
			return
		place_door_at(area, best, door_data, fh, best_orient)


#True when the cell has a 4-neighbour outside its own floor mask, so it carries the outside wall.
static func _on_mask_edge(area: BattlefieldArea, c: Vector3i) -> bool:
	for d: Vector2i in DIRS4:
		if not area.in_footprint_floor(Vector2i(c.x + d.x, c.y + d.y), c.z):
			return true
	return false


#Open cells of one floor: floor cells with no obstacle, plus doors, stairs and stair markers.
static func _floor_open_cells(area: BattlefieldArea, f: int) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in area.building_interiors.keys():
		var c: Vector3i = key as Vector3i
		if c.z == f and not area._obs_map.has(c):
			out[c] = true
	for key2: Variant in area._obs_map.keys():
		var c2: Vector3i = key2 as Vector3i
		if c2.z != f:
			continue
		var ct: String = area.cell_type_at(c2)
		if ct == "door" or ct == "stairs" or ct == "stair_run" or ct == "reserved_stairwell":
			out[c2] = true
	return out


#4-connected regions of one floor: {"ids": cell -> region, "sizes": region -> cells, "count": int}.
static func _floor_regions(area: BattlefieldArea, f: int) -> Dictionary:
	var open_cells: Dictionary = _floor_open_cells(area, f)
	var ids: Dictionary = {}
	var sizes: Dictionary = {}
	var n: int = 0
	for key: Variant in open_cells.keys():
		var s: Vector3i = key as Vector3i
		if ids.has(s):
			continue
		var queue: Array[Vector3i] = [s]
		ids[s] = n
		var qi: int = 0
		while qi < queue.size():
			var cur: Vector3i = queue[qi]
			qi += 1
			for d: Vector2i in DIRS4:
				var nb := Vector3i(cur.x + d.x, cur.y + d.y, f)
				if open_cells.has(nb) and not ids.has(nb):
					ids[nb] = n
					queue.append(nb)
		sizes[n] = queue.size()
		n += 1
	return {"ids": ids, "sizes": sizes, "count": n}


static func place_wall_if_empty(area: BattlefieldArea, pos: Vector3i, wall_sz: int, wall_data: ObstacleData, fh: int) -> void:
	if area._obs_map.has(pos):
		return
	var obs := {"pos": pos, "size": wall_sz, "data": wall_data, "cell_type": "wall", "height": float(fh), "floor": pos.z}
	area.add_obstacle(obs, pos)


static func _clear_cell(area: BattlefieldArea, pos: Vector3i) -> void:
	if not area._obs_map.has(pos):
		return
	area._obs_map.erase(pos)
	for i: int in range(area.obstacles.size() - 1, -1, -1):
		if (area.obstacles[i]["pos"] as Vector3i) == pos:
			area.obstacles.remove_at(i)
			break


static func _replace_wall_with(area: BattlefieldArea, pos: Vector3i, obs: Dictionary) -> void:
	if area._obs_map.has(pos):
		if area.cell_type_at(pos) != "wall":
			return
		_clear_cell(area, pos)
	area.add_obstacle(obs, pos)


#Windows walk the outside wall of every floor mask: every other cell out from each segment midpoint.
static func _place_windows(area: BattlefieldArea, fp: int, window_data: ObstacleData,
		stairwell_xs: Dictionary, fh: int, level: String = "Normal",
		room_levels: Dictionary = {}) -> void:
	if window_data == null:
		return
	var stairwell_x_set: Dictionary = {}
	for v: Variant in stairwell_xs.values():
		stairwell_x_set[int(v)] = true
	var opts: Dictionary = {}
	var planned: bool = not area.building_plan.is_empty()
	if planned or level != "Normal" or not room_levels.is_empty():
		var band_xs: Dictionary = {}
		var band_x0: int = int(area.building_plan.get("band_x0", -1))
		if band_x0 >= 0:
			band_xs[band_x0] = true
			band_xs[band_x0 + 1] = true
		opts = {"level": level, "rooms": room_levels, "planned": planned, "band": band_xs}
	for f: int in range(fp, -1, -1):
		var segs: Dictionary = _wall_segments(area, f)
		for key: Variant in segs.keys():
			var k: Vector2i = key as Vector2i
			var vals: Array = segs[k] as Array
			vals.sort()
			var run: Array[int] = []
			for i: int in range(vals.size()):
				var v: int = int(vals[i])
				if not run.is_empty() and v != run[run.size() - 1] + 1:
					_window_run(area, f, k, run, stairwell_x_set, window_data, fh, opts)
					run = []
				run.append(v)
			_window_run(area, f, k, run, stairwell_x_set, window_data, fh, opts)


#Outside wall cells of one floor grouped by side and fixed coordinate: Vector2i(side, fixed) -> Array.
static func _wall_segments(area: BattlefieldArea, f: int) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in area.footprint_cells.keys():
		var c: Vector3i = key as Vector3i
		if c.z != f:
			continue
		if area.cell_type_at(c) != "wall":
			continue
		var side: int = -1
		var outside: int = 0
		for i: int in range(DIRS4.size()):
			if not area.footprint_union.has(Vector2i(c.x + DIRS4[i].x, c.y + DIRS4[i].y)):
				outside += 1
				side = i
		if outside != 1:
			continue
		var k := Vector2i(side, c.x if side <= 1 else c.y)
		var vals: Array = out.get(k, []) as Array
		vals.append(c.y if side <= 1 else c.x)
		out[k] = vals
	return out


#One straight wall segment: keeps every other cell measured from the segment midpoint.
static func _window_run(area: BattlefieldArea, f: int, k: Vector2i, run: Array[int],
		stairwell_x_set: Dictionary, window_data: ObstacleData, fh: int,
		opts: Dictionary = {}) -> void:
	if run.is_empty():
		return
	var side: int = k.x
	var mid: int = run[run.size() >> 1]
	var inward: Vector2i = -DIRS4[side]
	var along: Vector2i = Vector2i(0, 1) if side <= 1 else Vector2i(1, 0)
	var def_level: String = String(opts.get("level", "Normal"))
	var room_levels: Dictionary = opts.get("rooms", {}) as Dictionary
	var planned: bool = bool(opts.get("planned", false))
	var band_xs: Dictionary = opts.get("band", {}) as Dictionary
	var kept: int = 0
	for v: int in run:
		var spaced: bool = absi(v - mid) % 2 == 0
		var kept_i: int = kept
		if spaced:
			kept += 1
		var p: Vector2i = Vector2i(k.y, v) if side <= 1 else Vector2i(v, k.y)
		var inn: Vector3i = Vector3i(p.x + inward.x, p.y + inward.y, f)
		var cell_level: String = def_level
		if not room_levels.is_empty():
			cell_level = _room_window_level(area, f, inn, room_levels, def_level)
		if cell_level == "None":
			continue
		if cell_level != "Many":
			if not spaced:
				continue
			if cell_level == "Few" and kept_i % 4 != 0:
				continue
		if stairwell_x_set.has(p.x):
			continue
		var adj_door: bool = false
		for step: int in [-1, 1]:
			var q: Vector2i = p + along * step
			if area.cell_type_at(Vector3i(q.x, q.y, f)) == "door":
				adj_door = true
		if adj_door:
			continue
		var inn_type: String = area.cell_type_at(inn)
		if inn_type == "wall":
			continue
		if planned:
			if band_xs.has(inn.x):
				continue
			if inn_type == "stair_run" or inn_type == "reserved_stairwell":
				continue
		var pos := Vector3i(p.x, p.y, f)
		_replace_wall_with(area, pos, {"pos": pos, "size": window_data.size, "data": window_data,
			"cell_type": "window", "orientation": "v" if side <= 1 else "h", "height": float(fh),
			"floor": f})


#Window level of the room behind one wall cell; the building level when no room names that cell.
static func _room_window_level(area: BattlefieldArea, f: int, inn: Vector3i,
		room_levels: Dictionary, def_level: String) -> String:
	var flat := Vector2i(inn.x, inn.y)
	for label: Dictionary in area.interior_rooms:
		if int(label.get("floor", 0)) != f:
			continue
		var room_name: String = String(label.get("name", ""))
		if not room_levels.has(room_name):
			continue
		if (label["rect"] as Rect2i).grow(1).has_point(flat):
			return String(room_levels[room_name])
	return def_level


#Cuts the two street level doors into the end walls and returns the row they share.
static func _place_entrance_doors(area: BattlefieldArea, bld_x: int, top_y: int, floor_w: int,
		floor_d: int, fh: int, num_floors: int) -> int:
	var ent_y: int = _entrance_row(area, top_y, floor_d, fh, num_floors)
	var ent_door: ObstacleData = DataManager.door_data()
	place_door_at(area, Vector3i(bld_x, ent_y, 0), ent_door, fh)
	_clear_cell(area, Vector3i(bld_x + 1, ent_y, 0))
	var exit_x: int = bld_x + floor_w + 1
	place_door_at(area, Vector3i(exit_x, ent_y, 0), ent_door, fh)
	_clear_cell(area, Vector3i(exit_x - 1, ent_y, 0))
	return ent_y


#Chooses the shared stair columns, builds the runs and reserves both columns on every floor.
static func _build_stairwells(area: BattlefieldArea, floor_v_cors: Dictionary, fp: int, fm: int,
		bld_x: int, floor_w: int, floor_d: int, top_y: int, stairs_data: ObstacleData,
		stairwell_xs: Dictionary, stairwell_adj_xs: Dictionary, fixed_pair: Array[int] = []) -> void:
	var stair_pair: Array[int] = fixed_pair if fixed_pair.size() == 2 else _pick_stair_columns(
		area, floor_v_cors, fp, fm, bld_x, floor_w, top_y, floor_d,
		stairwell_xs.get(fp, bld_x + 1) as int, stairwell_adj_xs.get(fp, bld_x + 2) as int)
	_fill_stair_cols(stairwell_xs, stairwell_adj_xs, fp, fm, stair_pair[0], stair_pair[1])
	place_stairwells(area, fp, fm, bld_x, floor_w, floor_d, stairs_data, stairwell_xs, stairwell_adj_xs, top_y)
	for stair_f: int in stairwell_xs.keys():
		for sw_x: int in stair_pair:
			for affected_f: int in [stair_f, stair_f - 1]:
				if not area.interior_floor_elevations.has(affected_f):
					continue
				for iy: int in range(top_y + 1, top_y + floor_d + 1):
					var p := Vector3i(sw_x, iy, affected_f)
					if area._obs_map.has(p):
						continue
					if area.stair_run_cells.has(p):
						area._obs_map[p] = {"cell_type": "stair_run", "floor": affected_f}
					else:
						area._obs_map[p] = {"cell_type": "reserved_stairwell", "floor": affected_f}


#Turns the cell just inside each entrance into a door or open floor.
static func _open_entrance_cells(area: BattlefieldArea, bld_x: int, floor_w: int, ent_y: int,
		fh: int) -> void:
	var ent_rx: int = bld_x + floor_w + 1
	var edt := DataManager.door_data()
	_open_entrance_cell(area, Vector3i(bld_x + 1, ent_y, 0), edt, fh)
	_open_entrance_cell(area, Vector3i(ent_rx - 1, ent_y, 0), edt, fh)


#A wall cell becomes a door; any other cell is cleared to open interior floor.
static func _open_entrance_cell(area: BattlefieldArea, pos: Vector3i, door_data: ObstacleData, fh: int) -> void:
	if area.cell_type_at(pos) == "wall":
		place_door_at(area, pos, door_data, fh, "h")
	else:
		_clear_cell(area, pos)
		area.building_interiors[pos] = true


#Writes the interior header lines to the generation log and prints the total.
static func _log_generation(area: BattlefieldArea, total_ms: int, num_floors: int, floor_w: int,
		fh: int, floor_d: int, wings: Array[Dictionary]) -> void:
	var north: int = 0
	var south: int = 0
	for w: Dictionary in wings:
		if String(w["side"]) == "n":
			north += 1
		else:
			south += 1
	var mask_f0: int = 0
	for key: Variant in area.footprint_cells.keys():
		if (key as Vector3i).z == 0:
			mask_f0 += 1
	area.generation_log.append("Area: %s  terrain: %s" % [area.area_name, BattlefieldArea.UNEVENNESS_NAMES[6]])
	area.generation_log.append("[GEN] interior floors: %d  floor_w: %d  fh: %d  floor_d: %d  map: %dx%d" % [
		num_floors, floor_w, fh, floor_d, area.width, area.length])
	area.generation_log.append("[GEN] wings=%d north=%d south=%d mask_f0=%d" % [
		wings.size(), north, south, mask_f0])
	area.log_total(total_ms)

