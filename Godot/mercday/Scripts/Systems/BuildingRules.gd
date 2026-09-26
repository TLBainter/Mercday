class_name BuildingRules
extends RefCounted

#Buildings.tsv rules shared by the generator, its validator and the tests. Reads data, writes nothing.

const LAYOUTS: Array[String] = ["Open", "Shop", "Hall", "Corridor"]
const SHELLS: Array[String] = ["Walled", "Open"]
const WINDOW_LEVELS: Array[String] = ["None", "Few", "Normal", "Many"]
const FRONTS: Array[String] = ["W", "E", "N", "S"]
const TRIES: int = 6
#A floor narrower than this on either axis is too small for the corridor partitioner.
const CORRIDOR_MIN: int = 14


#Legacy rows keep the old interior generator body; every Buildings.tsv row without a layout is one.
static func is_legacy(area_data: Dictionary) -> bool:
	if not area_data.has("building"):
		return true
	var b: Dictionary = area_data["building"]
	return bool(b.get("legacy", false))


#One rolled building plan. The order of the random calls is part of the contract; do not reorder.
#site (city lots): max_w and max_d bound floor_w and floor_d; no_wings and no_ext_rooms drop those parts.
static func roll_plan(area_data: Dictionary, front: String = "", fh_forced: int = 0, site: Dictionary = {}) -> Dictionary:
	if is_legacy(area_data):
		return {}
	var b: Dictionary = area_data["building"]
	var size_class: String = String(b.get("size_class", ""))
	var use_front: String = front if FRONTS.has(front) else FRONTS[randi() % 4]
	var fp_range: Vector2i = b.get("f_plus", Vector2i.ZERO)
	var fm_range: Vector2i = b.get("f_minus", Vector2i.ZERO)
	var fp: int = randi_range(fp_range.x, fp_range.y)
	var fm: int = randi_range(fm_range.x, fm_range.y)
	var w_range: Vector2i = b.get("width", Vector2i.ONE)
	var d_range: Vector2i = b.get("depth", Vector2i.ONE)
	var frontage: int = randi_range(w_range.x, w_range.y)
	var building_depth: int = randi_range(d_range.x, d_range.y)
	var fh: int = 3
	if fh_forced == 3 or fh_forced == 4:
		fh = fh_forced
	elif size_class != "Small":
		fh = randi_range(3, 4)
	var floor_w: int = building_depth
	var floor_d: int = frontage
	var y_max: int = w_range.y
	var w_max: int = d_range.y
	if use_front == "N" or use_front == "S":
		floor_w = frontage
		floor_d = building_depth
		y_max = d_range.y
		w_max = w_range.y
	var max_w: int = int(site.get("max_w", 0))
	var max_d: int = int(site.get("max_d", 0))
	if max_w > 0:
		floor_w = maxi(3, mini(floor_w, max_w))
		w_max = mini(w_max, max_w)
	if max_d > 0:
		floor_d = maxi(3, mini(floor_d, max_d))
		y_max = mini(y_max, max_d)
	if fp + fm > 0:
		var need: int = 2 * fh + 3
		if floor_d < need:
			if y_max >= need:
				floor_d = need
			elif fh == 4 and fh_forced == 0 and y_max >= 9:
				fh = 3
				floor_d = maxi(floor_d, 9)
			else:
				fp = 0
				fm = 0
	if fp + fm > 0 and floor_w < 5:
		if w_max >= 5:
			floor_w = 5
		else:
			fp = 0
			fm = 0
	var street: int = randi_range(3, 5)
	var wings_range: Vector2i = b.get("wings", Vector2i.ZERO)
	var ent_range: Vector2i = b.get("entrances", Vector2i.ZERO)
	var wing_count: int = randi_range(wings_range.x, wings_range.y)
	var entrances: int = randi_range(ent_range.x, ent_range.y)
	if bool(site.get("no_wings", false)):
		wing_count = 0
	var shell: String = String(b.get("shell", "Walled"))
	if shell == "Open":
		fp = 0
		fm = 0
		wing_count = 0
		entrances = 0
	var layout_f0: String = String(b.get("layout_f0", ""))
	var layout_other: String = String(b.get("layout_other", ""))
	if layout_other == "":
		layout_other = layout_f0
	if layout_f0 == "Corridor" and mini(floor_w, floor_d) < CORRIDOR_MIN:
		layout_f0 = "Hall"
	var band_side: String = ""
	if fp + fm > 0 and not (layout_f0 == "Corridor" and layout_other == "Corridor"):
		if use_front == "W":
			band_side = "W"
		elif use_front == "E":
			band_side = "E"
		else:
			band_side = "W" if randi() % 2 == 0 else "E"
	var required_rooms: Array[String] = []
	required_rooms.assign(b.get("required_rooms", []))
	var other_rooms: Array[String] = []
	other_rooms.assign(b.get("other_rooms", []))
	var window_rooms: Dictionary = b.get("window_rooms", {})
	var plan: Dictionary = {
		"name": String(area_data.get("name", "")),
		"size_class": size_class,
		"front": use_front,
		"fh": fh,
		"fp": fp,
		"fm": fm,
		"floor_w": floor_w,
		"floor_d": floor_d,
		"street": street,
		"layout_f0": layout_f0,
		"layout_other": layout_other,
		"shell": shell,
		"wing_count": wing_count,
		"entrances": entrances,
		"windows": String(b.get("windows", "Normal")),
		"window_rooms": window_rooms.duplicate(),
		"main_room": String(b.get("main_room", "")),
		"required_rooms": required_rooms,
		"other_rooms": other_rooms,
		"band_side": band_side,
		"roof": String(b.get("roof", "Flat")),
		"roof_objects": (b.get("roof_objects", []) as Array).duplicate(true),
	}
	if not site.is_empty():
		plan["no_ext_rooms"] = bool(site.get("no_ext_rooms", false))
	return plan


#Floor fit for one room name; false when the name names no room.
static func room_fits_floor(room_name: String, f: int, top_floor: int) -> bool:
	var d: ObstacleData = DataManager.get_obstacle_by_name(room_name)
	if d == null or not d.is_room:
		return false
	return _suffix_fits(d.room_type, f, top_floor)


#Any fits floors 0 and up, F0 the street floor, F+ above it, F- below it, Top the highest floor.
static func _suffix_fits(room_type: String, f: int, top_floor: int) -> bool:
	if room_type.ends_with("Any"):
		return f >= 0
	if room_type.ends_with("F0"):
		return f == 0
	if room_type.ends_with("F+"):
		return f > 0
	if room_type.ends_with("F-"):
		return f < 0
	if room_type.ends_with("Top"):
		return top_floor >= 1 and f == top_floor
	return false


#Violations of a generated planned building; an empty array means the field is good.
static func validate(area: BattlefieldArea) -> Array[String]:
	var out: Array[String] = []
	if area == null:
		return out
	var plan: Dictionary = area.building_plan
	if plan.is_empty() or bool(plan.get("legacy", false)):
		return out
	var front: String = String(plan.get("front", "W"))
	var main_room: String = String(plan.get("main_room", ""))
	var fp: int = int(plan.get("fp", 0))
	var fm: int = int(plan.get("fm", 0))
	if String(plan.get("shell", "Walled")) != "Open":
		var door: Vector3i = plan.get("front_door", Vector3i(-1, -1, 0))
		var obs: Dictionary = area._obs_map.get(door, {})
		if door.x < 0 or door.y < 0 or door.z != 0 or String(obs.get("cell_type", "")) != "door":
			out.append("no front door")
		else:
			var inside: Vector3i = _inside_cell(door, front)
			var dist: Dictionary = DungeonGenerator._walk_dist(area, inside, true)
			for entry: Dictionary in area.interior_rooms:
				if _is_exterior(String(entry.get("name", ""))):
					continue
				if not _rect_reached(dist, entry.get("rect", Rect2i()), int(entry.get("floor", 0))):
					out.append("unreached %s f%d" % [String(entry.get("name", "")), int(entry.get("floor", 0))])
			if not _main_at_door(area, main_room, Vector2i(inside.x, inside.y)):
				out.append("main room not at the front door")
	var req_names: Array = plan.get("required_rooms", [])
	for req: Variant in req_names:
		var req_name: String = String(req)
		var fits_any: bool = false
		var found: bool = false
		for f: int in range(fp, -fm - 1, -1):
			if not room_fits_floor(req_name, f, fp):
				continue
			fits_any = true
			if _has_room_on_floor(area, req_name, f):
				found = true
				break
		if fits_any and not found:
			out.append("missing required %s" % req_name)
	if fp + fm > 0 and area.stairwell_connections.is_empty():
		out.append("no stairs")
	return out


#The cell just inside the front door, taken from the wall the door sits in.
static func _inside_cell(door: Vector3i, front: String) -> Vector3i:
	if front == "W":
		return Vector3i(door.x + 1, door.y, door.z)
	if front == "E":
		return Vector3i(door.x - 1, door.y, door.z)
	if front == "N":
		return Vector3i(door.x, door.y + 1, door.z)
	return Vector3i(door.x, door.y - 1, door.z)


#True when the walk reached at least one cell of the rect on its own floor.
static func _rect_reached(dist: Dictionary, rect: Rect2i, f: int) -> bool:
	for x: int in range(rect.position.x, rect.position.x + rect.size.x):
		for y: int in range(rect.position.y, rect.position.y + rect.size.y):
			if dist.has(Vector3i(x, y, f)):
				return true
	return false


#The floor 0 main room must carry the plan's name and sit at the door or across the front corridor from it.
static func _main_at_door(area: BattlefieldArea, main_room: String, inside: Vector2i) -> bool:
	for entry: Dictionary in area.interior_rooms:
		if int(entry.get("floor", 0)) != 0 or not bool(entry.get("main", false)):
			continue
		if String(entry.get("name", "")) != main_room:
			continue
		var rect: Rect2i = entry.get("rect", Rect2i())
		if rect.grow(3).has_point(inside):
			return true
	return false


#Patios and balconies lie outside the footprint, so the footprint walk never enters them.
static func _is_exterior(room_name: String) -> bool:
	var d: ObstacleData = DataManager.get_obstacle_by_name(room_name)
	return d != null and d.is_room and d.room_type.begins_with("Exterior")


static func _has_room_on_floor(area: BattlefieldArea, room_name: String, f: int) -> bool:
	for entry: Dictionary in area.interior_rooms:
		if int(entry.get("floor", 0)) == f and String(entry.get("name", "")) == room_name:
			return true
	return false
