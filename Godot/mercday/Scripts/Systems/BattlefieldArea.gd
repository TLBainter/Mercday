class_name BattlefieldArea extends RefCounted

const MIN_DIM := 20
const MAX_DIM := 50

# cells per area unit per density level; 0 = minimal, 4 = excessive
const COVER_DENSITY: Array[float] = [0.01, 0.03, 0.05, 0.08, 0.12]
const COVER_AMOUNT_NAMES: Array[String] = ["minimal", "some", "average", "many", "excessive"]

const SPAWN_BUFFER := 3

#Thickness in paces of the sloped slab under a stair tread; the solid band is [tread - this, tread].
const STAIR_SLAB := 0.5
#Returned by stair_headroom() when no stair run overhangs the cell.
const NO_HEADROOM_LIMIT := 1000.0

# Max buildings per combat, indexed by cover_amount (0-4)
const MAX_BUILDINGS_BY_DENSITY: Array[int] = [0, 0, 1, 2, 3]

#Glyph key printed under every per-floor grid.
const MAP_LEGEND := "legend: . floor/street  # wall  D closed door (Interact)  d open door  W window  w broken window  S stair run  ^ stair landing  b balcony  f fence  ~ passthrough  * harmful passthrough  o obstacle  ! jagged  0/1 merc team"

#Cardinal steps used for balcony and window drop edges.
const DROP_DIRS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]

const UNEVENNESS_NAMES: Array[String] = ["flat", "gentle", "hilly", "rough", "extreme", "mountainous", "interior"]
const UNEVENNESS_RANGE: Array[Vector2] = [
	Vector2(-2.0, 2.0),
	Vector2(-2.0, 2.0),
	Vector2(-2.0, 5.0),
	Vector2(-5.0, 5.0),
	Vector2(-5.0, 9.0),
	Vector2(-0.5, 2.0),
	Vector2(0.0,  0.0),
]

var width: int
var length: int
var height: int
var cover_amount: int
var unevenness: int = 0
var area_name: String = ""
var jagged_cells: Dictionary = {}
var fly_only_cells: Dictionary = {}
var obstacles: Array[Dictionary] = []   #[{pos, size, data, ?cell_type, ?is_open}]
var building_interiors: Dictionary = {} # Vector3i(x,y,floor_num) -> true (interior); Vector2i(x,y) -> true (exterior)
var building_data: Array[Dictionary] = []  # [{rect, door_facing, door_positions, name}]
var terrain_heights: Dictionary = {}    # Vector2i -> float; absent key = 0.0
# Generation log lines collected during _generate_cover(); flushed by EncounterLogger.log_generation().
var generation_log: Array[String] = []
var _obs_map: Dictionary = {}               #Vector2i key on exterior maps, Vector3i(x,y,floor) on interior maps
var cover_obstacles: Array[Dictionary] = [] # pre-filtered to provides_cover==true; rebuilt after generation
var droppable_obs_map: Dictionary = {}      #Vector3i (x, y, floor) -> true; destroyable obstacles that have drops
var is_interior_map: bool = false
var los_version: int = 0                     #bumped whenever sight through a cell changes; invalidates LOS caches
var path_version: int = 0                    #bumped whenever passability changes; keys reach and cost caches
var path_static: Dictionary = {}             #int merc_size -> Dictionary Vector3i -> Array; static per-cell walk facts
var neighbor_cache: Dictionary = {}          #Vector3i -> Array[Vector3i]; walk neighbours of the cell
var jump_static: Dictionary = {}             #[merc_size, jump_range] -> Dictionary Vector3i -> Array; jump landings
var ceiling_cells: Dictionary = {}          # Vector3i(x,y,floor_num) -> true
var stairwell_cells: Dictionary = {}        # Vector3i(x,y,floor_num) -> true
var interior_floor_height: int = 4          # interior cell rows per floor strip
var interior_floor_depth: int = 0
var interior_top_y: int = 0
var interior_floor_elevations: Dictionary = {} # int floor_num -> int base elevation in cells above ground
var stairwell_connections: Dictionary = {}  # Vector3i -> Vector3i; maps stair entry cell to connected cell on adjacent floor
var interior_rooms: Array[Dictionary] = []   # interior only: [{rect, name, floor}] for wireframe labels
var building_footprint: Rect2i = Rect2i()    #interior only: shell rect, walls inclusive; empty on exterior maps
var stair_run_cells: Dictionary = {}         #Vector3i(x,y,floor_num) -> true; every carved stair cell incl. landing
var stair_runs: Dictionary = {}              #int floor_num -> {"sx": int, "ly": int, "uy": int}
var stair_links: Dictionary = {}             #Vector3i -> Array[Vector3i]; cross-floor stair steps
var well_links: Dictionary = {}              #Vector3i -> Array[Vector3i]; vertical flight through the stair well
var drop_links: Dictionary = {}              #Vector3i -> Array[{to,paces,kind,vault}]; deliberate drops to floor 0

# Path width: 1 (extreme/dense) -> 3 (gentle/sparse). Computed from unevenness + cover_amount.
# Stored so ConnectivityVerifier can match the width used during nav path generation.
var path_width: int = 2

# Cells reserved as walkable corridors between spawns. Established before any obstacle or terrain
# effect placement so nothing can block them. Exposed to Pathfinder as passable_cells at runtime.
var reserved_corridor_cells: Dictionary = {}

var spawn_center_a: Vector2i = Vector2i.ZERO
var spawn_center_b: Vector2i = Vector2i.ZERO
var spawn_radius: float = 3.0
var spawn_zone_a: Dictionary = {}
var spawn_zone_b: Dictionary = {}


#An empty area_data rolls one of area_type; a caller that already picked an area passes it in.
#Grid cell of an obstacle position, stored as Vector2i on exterior maps and Vector3i on interior ones.
static func cell_of(raw: Variant) -> Vector2i:
	if typeof(raw) == TYPE_VECTOR3I:
		return Vector2i((raw as Vector3i).x, (raw as Vector3i).y)
	return raw as Vector2i


#Floor carried by such a position; fallback stands in when the position has no floor.
static func floor_of(raw: Variant, fallback: int = 0) -> int:
	if typeof(raw) == TYPE_VECTOR3I:
		return (raw as Vector3i).z
	return fallback


static func generate_random(config: BuildingConfig = null, context: GenerationContext = null, area_type: String = "Exterior", area_data: Dictionary = {}) -> BattlefieldArea:
	var f := BattlefieldArea.new()
	f.width  = randi_range(MIN_DIM, MAX_DIM)
	f.length = randi_range(MIN_DIM, MAX_DIM)
	f.height = randi_range(MIN_DIM, MAX_DIM)
	f.cover_amount = randi() % 5
	if area_data.is_empty():
		area_data = DataManager.get_random_area(area_type)
	f.area_name = area_data.get("name", "Unknown")
	var weights: Array = area_data.get("weights", [])
	var total_w: int = 0
	for w: int in weights:
		total_w += w
	var ctx: GenerationContext = context if context != null else GenerationContext.new()
	if total_w == 0:
		f.unevenness = 6
		f.is_interior_map = true
		InteriorGenerator.generate_interior(f, area_data, ctx)
		f.build_stair_links()
		f.build_drop_links()
		return f
	var roll: int = randi() % total_w
	var cum: int = 0
	f.unevenness = 0
	for i: int in range(weights.size()):
		cum += (weights[i] as int)
		if roll < cum:
			f.unevenness = i
			break
	f._pick_spawn_centers(ctx)
	for _attempt: int in range(4):
		f._generate_cover(config)
		if ConnectivityVerifier.spawns_connected(f) and f._approach_zone_ok():
			break
	f.build_stair_links()
	f.build_drop_links()
	return f


func _pick_spawn_centers(ctx: GenerationContext) -> void:
	var max_team: int = maxi(ctx.team_size_a, ctx.team_size_b)
	spawn_radius = maxf(3.0, float(max_team))
	spawn_radius = maxf(spawn_radius, sqrt(float(width * length)) / 12.0)
	var side_a: int = randi() % 4
	var side_b: int = side_a ^ 1
	spawn_center_a = _pick_side_center(side_a)
	spawn_center_b = _pick_side_center(side_b)
	spawn_zone_a = _build_spawn_zone(spawn_center_a)
	spawn_zone_b = _build_spawn_zone(spawn_center_b)


func _pick_side_center(side: int) -> Vector2i:
	var margin: int = clampi(ceili(sqrt(float(width * length)) / 10.0), 1, 6)
	match side:
		0:
			return Vector2i(randi_range(0, width - 1), randi_range(1, margin))
		1:
			return Vector2i(randi_range(0, width - 1), randi_range(length - 1 - margin, length - 2))
		2:
			return Vector2i(randi_range(1, margin), randi_range(0, length - 1))
		_:
			return Vector2i(randi_range(width - 1 - margin, width - 2), randi_range(0, length - 1))


func _build_spawn_zone(center: Vector2i) -> Dictionary:
	var zone: Dictionary = {}
	var ri: int = ceili(spawn_radius)
	for dy: int in range(-ri, ri + 1):
		for dx: int in range(-ri, ri + 1):
			var cell := Vector2i(center.x + dx, center.y + dy)
			if cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= length:
				continue
			if Vector2(float(dx), float(dy)).length() <= spawn_radius:
				zone[cell] = true
	return zone


func clamp_position(pos: Vector2i) -> Vector2i:
	return Vector2i(clamp(pos.x, 0, width - 1), clamp(pos.y, 0, length - 1))


func to_header_string() -> String:
	var b_str := " (%d building%s)" % [building_data.size(), "s" if building_data.size() != 1 else ""] \
		if not building_data.is_empty() else ""
	var loc := ("[%s] " % area_name) if area_name != "" else ""
	var f_str := ""
	if is_interior_map and not interior_floor_elevations.is_empty():
		var fl: Array[int] = sorted_floors()
		f_str = "  Floors: %d (F%d..F%d)" % [fl.size(), fl[0], fl[fl.size() - 1]]
	return "Battlefield: %dx%d (height %d)  %s %s cover, %s terrain%s%s" % [
		width, length, height, loc, COVER_AMOUNT_NAMES[cover_amount],
		UNEVENNESS_NAMES[unevenness], b_str, f_str]


#Floor numbers lowest first; empty on exterior maps.
func sorted_floors() -> Array[int]:
	var keys: Array = interior_floor_elevations.keys()
	keys.sort()
	var out: Array[int] = []
	for k: Variant in keys:
		out.append(k as int)
	return out


#Row a run starts from; "up" +1 climbs from "ly" to "uy", -1 climbs from "uy" to "ly".
static func run_bottom_y(run: Dictionary) -> int:
	return int(run["ly"]) if int(run.get("up", 1)) > 0 else int(run["uy"])


#Row a run arrives at on its own floor.
static func run_top_y(run: Dictionary) -> int:
	return int(run["uy"]) if int(run.get("up", 1)) > 0 else int(run["ly"])


#Cells where a stair run ends on the floor below; Vector3i -> true.
func _landing_cells() -> Dictionary:
	var out: Dictionary = {}
	for f: Variant in stair_runs.keys():
		var run: Dictionary = stair_runs[f] as Dictionary
		out[Vector3i(int(run["sx"]), run_bottom_y(run), (f as int) - 1)] = true
	return out


#Single-cell glyph for the floor_num view of pos; see MAP_LEGEND.
func _floor_glyph(pos: Vector2i, floor_num: int, landings: Dictionary) -> String:
	var key := Vector3i(pos.x, pos.y, floor_num)
	if jagged_cells.has(pos):
		return "!"
	if stair_run_cells.has(key):
		return "^" if landings.has(key) else "S"
	var obs: Dictionary = get_obs(pos, floor_num)
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
		var d: ObstacleData = obs.get("data") as ObstacleData
		if d != null and d.ramp:
			return "S"
		if d != null and d.passthrough:
			return "*" if (d.pt_enter_harm > 0 or d.pt_exit_harm > 0) else "~"
		return "o"
	if floor_num == 0:
		return "."
	if building_interiors.has(key) and not in_footprint(pos):
		return "b"
	if has_slab(pos, floor_num):
		return "."
	return " "


#One ASCII grid per floor, lowest first. markers: Vector3i -> glyph; only_floors limits the set.
func to_floor_maps_string(markers: Dictionary = {}, only_floors: Dictionary = {}) -> String:
	var landings: Dictionary = _landing_cells()
	var out: Array[String] = []
	for f: int in sorted_floors():
		if not only_floors.is_empty() and not only_floors.has(f):
			continue
		out.append("Floor F%d elev=%d" % [f, int(interior_floor_elevations.get(f, 0))])
		for y: int in range(length):
			var row := ""
			for x: int in range(width):
				var key := Vector3i(x, y, f)
				if markers.has(key):
					row += str(markers[key])
				else:
					row += _floor_glyph(Vector2i(x, y), f, landings)
			out.append(row)
		out.append(MAP_LEGEND)
	return "\n".join(out)


#Header map: per-floor grids indoors, the single terrain grid outdoors.
func to_visual_string() -> String:
	if is_interior_map:
		return to_floor_maps_string()
	return _to_exterior_visual_string({})


#F0 grid plus every floor holding a merc, team digits written over the terrain glyph.
#spawns entries: {"team": int, "floor": int, "pos": Vector2i}.
func to_spawn_map_string(spawns: Array) -> String:
	var markers: Dictionary = {}
	var floors: Dictionary = {0: true}
	for s: Dictionary in spawns:
		var sp: Vector2i = s["pos"] as Vector2i
		var sf: int = s["floor"] as int
		markers[Vector3i(sp.x, sp.y, sf)] = "0" if (s["team"] as int) == 0 else "1"
		floors[sf] = true
	if is_interior_map:
		return to_floor_maps_string(markers, floors)
	return _to_exterior_visual_string(markers)


func _to_exterior_visual_string(markers: Dictionary) -> String:
	var pos_map: Dictionary = {}
	for obs: Dictionary in obstacles:
		pos_map[cell_of(obs["pos"])] = obs
	var rows: Array[String] = []
	for y: int in range(length):
		var row := ""
		for x: int in range(width):
			var pos := Vector2i(x, y)
			if markers.has(Vector3i(x, y, 0)):
				row += str(markers[Vector3i(x, y, 0)])
			elif not pos_map.has(pos):
				var h: float = get_terrain_height(pos)
				if jagged_cells.has(pos):
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
				var obs: Dictionary = pos_map[pos]
				var d: ObstacleData = obs.get("data") as ObstacleData
				if d != null and d.ramp:
					row += "[color=cyan]S[/color]"
				else:
					var ct: String = obs.get("cell_type", "")
					if ct == "wall" or ct == "door":
						row += "[color=orange]#[/color]"
					elif d == null or not d.passthrough:
						row += "[color=orange]#[/color]"
					elif d.pt_enter_harm > 0 or d.pt_exit_harm > 0:
						row += "[color=red]*[/color]"
					else:
						row += "[color=pink]~[/color]"
		rows.append(row)
	return "\n".join(rows)


#Generator markers (stair_run, reserved_stairwell) keep cells free of furniture; they are not obstacles.
static func _skip_placeholder(obs: Dictionary) -> Dictionary:
	if obs.is_empty() or obs.has("data"):
		return obs
	var ct: String = obs.get("cell_type", "")
	if ct == "stair_run" or ct == "reserved_stairwell":
		return {}
	return obs


#_obs_map key for a cell: Vector3i on interior maps, Vector2i on exterior maps.
func obs_key(pos: Vector2i, floor_num: int) -> Variant:
	if is_interior_map:
		return Vector3i(pos.x, pos.y, floor_num)
	return pos


#Floor-aware obstacle lookup; returns the stored dict (by reference) or {}.
func get_obs(pos: Vector2i, floor_num: int) -> Dictionary:
	return _skip_placeholder(_obs_map.get(obs_key(pos, floor_num), {}) as Dictionary)


#Vertical extent of an obstacle in paces; broken windows drop to 1.0.
static func obstacle_height(obs: Dictionary) -> float:
	if obs.get("broken", false) as bool:
		return 1.0
	if obs.has("height"):
		return float(obs["height"])
	var d: ObstacleData = obs.get("data") as ObstacleData
	if d != null:
		return d.height
	return 0.0


#True when sight passes through the obstacle: windows (intact or broken) and open doors.
#TODO: transparency should come from a Transparent column in Obstacles.tsv
static func is_transparent(obs: Dictionary) -> bool:
	var ct: String = obs.get("cell_type", "")
	if ct == "window":
		return true
	return ct == "door" and OpenCloseState.is_open(obs)


#Base elevation of a floor plane in cells; 0.0 on exterior maps.
func floor_base_elevation(floor_num: int) -> float:
	if not is_interior_map:
		return 0.0
	return float(interior_floor_elevations.get(floor_num, 0))


#Elevation a unit stands on at pos: floor plane indoors, terrain height outdoors.
#Stair run cells interpolate between the floor below and their own floor.
func cell_base_elevation(pos: Vector2i, floor_num: int) -> float:
	if not is_interior_map:
		return get_terrain_height(pos)
	if stair_runs.has(floor_num) and is_stair_cell(pos, floor_num):
		var run: Dictionary = stair_runs[floor_num] as Dictionary
		var ly: int = run["ly"] as int
		var uy: int = run["uy"] as int
		var sx: int = run["sx"] as int
		if absi(pos.x - sx) <= 1 and uy > ly and pos.y >= ly and pos.y <= uy:
			var lo := floor_base_elevation(floor_num - 1)
			var hi := floor_base_elevation(floor_num)
			var t := float(pos.y - ly) / float(uy - ly)
			if int(run.get("up", 1)) < 0:
				t = float(uy - pos.y) / float(uy - ly)
			return lo + (hi - lo) * t
	return floor_base_elevation(floor_num)


#Standing elevation for walkers: terrain outdoors; floor plane or tread indoors, relative to floor 0.
func walk_elevation(pos: Vector2i, floor_num: int) -> float:
	if is_interior_map and (floor_num != 0 or in_footprint(pos)):
		return cell_base_elevation(pos, floor_num) - floor_base_elevation(0)
	return get_terrain_height(pos)


#Clear height in paces under the floor+1 run that overhangs pos; NO_HEADROOM_LIMIT when nothing overhangs it.
func stair_headroom(pos: Vector2i, floor_num: int) -> float:
	if not is_interior_map:
		return NO_HEADROOM_LIMIT
	var above: int = floor_num + 1
	if not stair_runs.has(above):
		return NO_HEADROOM_LIMIT
	if not is_stair_cell(pos, above) or is_stair_cell(pos, floor_num):
		return NO_HEADROOM_LIMIT
	return cell_base_elevation(pos, above) - STAIR_SLAB - floor_base_elevation(floor_num)


#Rebuilds stair_runs and stair_links from stairwell_connections; safe on exterior maps.
func build_stair_links() -> void:
	stair_runs.clear()
	stair_links.clear()
	well_links.clear()
	neighbor_cache.clear()
	if not is_interior_map:
		return
	for key: Vector3i in stairwell_connections.keys():
		var dest: Vector3i = stairwell_connections[key] as Vector3i
		if dest.z >= key.z:
			continue
		stair_runs[key.z] = {"sx": key.x, "ly": mini(dest.y, key.y), "uy": maxi(dest.y, key.y),
			"up": 1 if key.y > dest.y else -1}
	for f: int in stair_runs.keys():
		var run: Dictionary = stair_runs[f] as Dictionary
		var sx: int = run["sx"] as int
		var ly: int = run_bottom_y(run)
		var landing := Vector3i(sx, ly, f - 1)
		if not stair_run_cells.has(landing):
			continue
		#The well opening joins the landing to the floor cells around the run alias above it.
		for wdx: int in [-1, 0, 1]:
			for wdy: int in [-1, 0, 1]:
				if wdx == 0 and wdy == 0:
					continue
				var w2 := Vector2i(sx + wdx, ly + wdy)
				if w2.x < 0 or w2.x >= width or w2.y < 0 or w2.y >= length:
					continue
				if is_stair_cell(w2, f):
					continue
				if not has_walkable_surface(w2, f):
					continue
				var wn := Vector3i(w2.x, w2.y, f)
				var w_down: Array[Vector3i] = []
				if well_links.has(landing):
					w_down.assign(well_links[landing] as Array)
				w_down.append(wn)
				well_links[landing] = w_down
				var w_up: Array[Vector3i] = []
				if well_links.has(wn):
					w_up.assign(well_links[wn] as Array)
				w_up.append(landing)
				well_links[wn] = w_up
		var ups: Array[Vector3i] = []
		for dx: int in [-1, 0, 1]:
			for dy: int in [-1, 1]:
				var c := Vector3i(sx + dx, ly + dy, f)
				if not stair_run_cells.has(c):
					continue
				ups.append(c)
		if ups.is_empty():
			continue
		stair_links[landing] = ups
		for c: Vector3i in ups:
			var down: Array[Vector3i] = []
			if stair_links.has(c):
				down.assign(stair_links[c] as Array)
			down.append(landing)
			stair_links[c] = down


#Rebuilds drop_links from balcony edges and broken shell windows; safe on exterior maps.
func build_drop_links() -> void:
	drop_links.clear()
	#Every build path ends here, so the reach and cost caches are reset for the finished geometry.
	bump_path_version()
	if not is_interior_map:
		return
	for key: Variant in building_interiors.keys():
		if typeof(key) != TYPE_VECTOR3I:
			continue
		var b: Vector3i = key as Vector3i
		if b.z < 1:
			continue
		var b2 := Vector2i(b.x, b.y)
		if in_footprint(b2):
			continue
		for d: Vector2i in DROP_DIRS:
			var edge := Vector2i(b.x + d.x, b.y + d.y)
			if in_footprint(edge) or building_interiors.has(Vector3i(edge.x, edge.y, b.z)):
				continue
			var edge_obs: Dictionary = get_obs(edge, b.z)
			var land := edge
			var vault := Vector3i(-1, -1, -1)
			if not edge_obs.is_empty():
				if edge_obs.get("cell_type", "") == "wall":
					continue
				land = Vector2i(edge.x + d.x, edge.y + d.y)
				vault = Vector3i(edge.x, edge.y, b.z)
			_add_drop_link(b, land, vault, "balcony")
	for wkey: Variant in _obs_map.keys():
		if typeof(wkey) != TYPE_VECTOR3I:
			continue
		var w: Vector3i = wkey as Vector3i
		if w.z < 1:
			continue
		var wobs: Dictionary = _obs_map[wkey] as Dictionary
		if wobs.get("cell_type", "") != "window":
			continue
		if not (wobs.get("broken", false) as bool):
			continue
		if not _on_footprint_edge(Vector2i(w.x, w.y)):
			continue
		for d: Vector2i in DROP_DIRS:
			var inner := Vector2i(w.x - d.x, w.y - d.y)
			if not in_footprint(inner) or not building_interiors.has(Vector3i(inner.x, inner.y, w.z)):
				continue
			var outer := Vector2i(w.x + d.x, w.y + d.y)
			if in_footprint(outer):
				continue
			_add_drop_link(Vector3i(inner.x, inner.y, w.z), outer, w, "window")


#True when pos sits on the outermost ring of the building footprint.
func _on_footprint_edge(pos: Vector2i) -> bool:
	if not in_footprint(pos):
		return false
	return pos.x == building_footprint.position.x or pos.x == building_footprint.end.x - 1 		or pos.y == building_footprint.position.y or pos.y == building_footprint.end.y - 1


#Records one drop edge from `from` to the floor 0 cell `land`; rejects unusable landings.
func _add_drop_link(from: Vector3i, land: Vector2i, vault: Vector3i, kind: String) -> void:
	if land.x < 0 or land.x >= width or land.y < 0 or land.y >= length:
		return
	if jagged_cells.has(land):
		return
	var lobs: Dictionary = get_obs(land, 0)
	if not lobs.is_empty():
		var lct: String = lobs.get("cell_type", "")
		if lct == "wall":
			return
		if lct == "door" and not OpenCloseState.is_open(lobs):
			return
	var paces: int = int(floor(floor_base_elevation(from.z) - cell_base_elevation(land, 0)))
	if paces <= 0:
		return
	var links: Array = drop_links.get(from, []) as Array
	links.append({"to": Vector3i(land.x, land.y, 0), "paces": paces, "kind": kind, "vault": vault})
	drop_links[from] = links


#True when pos lies within the building shell (walls inclusive); false when no footprint is set.
func in_footprint(pos: Vector2i) -> bool:
	if building_footprint.size.x <= 0 or building_footprint.size.y <= 0:
		return false
	return building_footprint.has_point(pos)


#True when the cell on floor_num is part of a carved stair run (including the landing).
func is_stair_cell(pos: Vector2i, floor_num: int) -> bool:
	return stair_run_cells.has(Vector3i(pos.x, pos.y, floor_num))


#True when the floor plane of floor_num at pos is solid; no slab outdoors, on balconies, or at stair runs.
func has_slab(pos: Vector2i, floor_num: int) -> bool:
	if not is_interior_map or not interior_floor_elevations.has(floor_num):
		return false
	return in_footprint(pos) and not is_stair_cell(pos, floor_num)


#True when a merc can stand on the cell of floor_num: floor 0, a slab, a stair run, or a balcony.
func has_walkable_surface(pos: Vector2i, floor_num: int) -> bool:
	if floor_num == 0:
		return true
	if has_slab(pos, floor_num) or is_stair_cell(pos, floor_num):
		return true
	return building_interiors.has(Vector3i(pos.x, pos.y, floor_num))


#Drops every cached route cost: the passable geometry of at least one cell changed.
func bump_path_version() -> void:
	path_version += 1
	path_static.clear()
	neighbor_cache.clear()
	jump_static.clear()


#Marks an intact window as broken in place; returns false when there is no intact window at pos.
func break_window(pos: Vector2i, floor_num: int) -> bool:
	var obs: Dictionary = get_obs(pos, floor_num)
	if obs.is_empty() or obs.get("cell_type", "") != "window":
		return false
	if obs.get("broken", false) as bool:
		return false
	obs["broken"] = true
	los_version += 1
	build_drop_links()
	bump_path_version()
	return true


func get_obstacle_at_3d(pos: Vector3i) -> Dictionary:
	return _skip_placeholder(_obs_map.get(pos, {}) as Dictionary)


func _generate_cover(config: BuildingConfig = null) -> void:
	reset_generated_state()
	var _gen_start := Time.get_ticks_msec()
	generation_log.append("Area: %s  terrain: %s" % [area_name, UNEVENNESS_NAMES[unevenness]])

	stage("corridor_reservation", func() -> void:
		_reserve_spawn_corridors())

	stage("base_terrain", func() -> void:
		TerrainGenerator.generate(self))

	_smooth_corridor_edges()

	var density: float = COVER_DENSITY[cover_amount]
	var total_count: int = int(width * length * density)
	@warning_ignore("integer_division")
	var terrain_count: int = total_count / 4

	stage("terrain_obstacles", func() -> String:
		var placed_terrain: int = ObstacleGenerator.place_terrain_obstacles(self, terrain_count)
		return "(%d placed)" % placed_terrain)

	stage("terrain_effects", func() -> void:
		ObstacleGenerator.apply_terrain_effects(self))

	TerrainGenerator.clamp_spawn_zones(self)

	stage("buildings", func() -> void:
		BuildingGenerator.generate_buildings(self, config))

	generation_log.append("Spawn centers: Team-0=(%d,%d) r=%.1f  Team-1=(%d,%d) r=%.1f" % [
		spawn_center_a.x, spawn_center_a.y, spawn_radius,
		spawn_center_b.x, spawn_center_b.y, spawn_radius])
	if building_data.is_empty():
		generation_log.append("Buildings placed: 0")
	else:
		generation_log.append("Buildings placed: %d" % building_data.size())
		for i: int in range(building_data.size()):
			var b: Dictionary = building_data[i]
			var rect: Rect2i = b["rect"] as Rect2i
			generation_log.append("  Building %d [%s]: pos=(%d,%d) size=%dx%d" % [
				i + 1, b.get("name", "?"),
				rect.position.x, rect.position.y, rect.size.x, rect.size.y])

	stage("furniture", func() -> void:
		BuildingGenerator.place_furniture_in_buildings(self))

	var scatter_count: int = total_count - terrain_count
	stage("obstacle_placement", func() -> String:
		var placed_scatter: int = ObstacleGenerator.place_obstacles(self, scatter_count)
		return "(%d placed)" % placed_scatter)

	stage("stairs", func() -> void:
		_place_stairs_at_transitions())

	var _az_a_blocked: bool = _spawn_exit_blocked(spawn_center_a, spawn_zone_a)
	var _az_b_blocked: bool = _spawn_exit_blocked(spawn_center_b, spawn_zone_b)
	if not _az_a_blocked and not _az_b_blocked:
		log_gen("[GEN] approach_zone: OK")
	else:
		var _az_parts: Array[String] = []
		if _az_a_blocked:
			_az_parts.append("Team-0")
		if _az_b_blocked:
			_az_parts.append("Team-1")
		var _az_msg: String = "[GEN] approach_zone: BLOCKED (%s)" % ", ".join(_az_parts)
		log_gen(_az_msg)

	stage("pathability", func() -> void:
		_ensure_pathability())

	stage("spawn_connectivity", func() -> void:
		ConnectivityVerifier.carve_corridor(self))

	stage("pocket_removal", func() -> void:
		ConnectivityVerifier.remove_pockets(self))

	stage("spawn_approaches", func() -> void:
		ConnectivityVerifier.verify_spawn_approaches(self))

	stage("fly_only_cells", func() -> String:
		_classify_fly_only_cells()
		return "(%d classified)" % fly_only_cells.size())

	_rebuild_cover_obstacles()
	_rebuild_droppable_obs_map()

	var _total_ms := Time.get_ticks_msec() - _gen_start
	log_gen("[GEN] TOTAL: %dms  -  %s" % [_total_ms, to_header_string()])



#Clears every field the generation pipeline fills in, before a fresh run.
func reset_generated_state() -> void:
	generation_log.clear()
	obstacles.clear()
	_obs_map.clear()
	cover_obstacles.clear()
	droppable_obs_map.clear()
	building_interiors.clear()
	building_data.clear()
	terrain_heights.clear()
	jagged_cells.clear()
	fly_only_cells.clear()
	reserved_corridor_cells.clear()
	ceiling_cells.clear()
	stairwell_cells.clear()
	stairwell_connections.clear()
	interior_floor_elevations.clear()
	building_footprint = Rect2i()
	stair_run_cells.clear()
	stair_runs.clear()
	stair_links.clear()
	well_links.clear()
	drop_links.clear()


#Runs one generation stage, times it and writes the GEN line to both outputs.
func stage(label: String, fn: Callable) -> void:
	var t := Time.get_ticks_msec()
	var detail: Variant = fn.call()
	var text := "[GEN] %s: %dms" % [label, Time.get_ticks_msec() - t]
	if detail is String and str(detail) != "":
		text += " " + str(detail)
	log_gen(text)


#Appends a generation line to the log and prints the same text.
func log_gen(text: String) -> void:
	generation_log.append(text)
	print(text)


func _classify_fly_only_cells() -> void:
	var cardinal: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	for y: int in range(length):
		for x: int in range(width):
			var cell := Vector2i(x, y)
			if jagged_cells.has(cell):
				continue
			if _obs_map.has(cell):
				continue
			if reserved_corridor_cells.has(cell):
				continue
			var cell_h: float = get_terrain_height(cell)
			var reachable: bool = false
			for dir: Vector2i in cardinal:
				var nb := cell + dir
				if nb.x < 0 or nb.x >= width or nb.y < 0 or nb.y >= length:
					continue
				if jagged_cells.has(nb):
					continue
				var h_diff: float = cell_h - get_terrain_height(nb)
				if h_diff <= 2.0:
					reachable = true
					break
			if not reachable:
				fly_only_cells[cell] = true


func _smooth_corridor_edges() -> void:
	var cardinal: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	for _pass: int in range(3):
		for cell: Vector2i in reserved_corridor_cells.keys():
			var sum: float = terrain_heights.get(cell, 0.0)
			var count: int = 1
			for dir: Vector2i in cardinal:
				var nb: Vector2i = cell + dir
				if nb.x >= 0 and nb.x < width and nb.y >= 0 and nb.y < length:
					sum += terrain_heights.get(nb, 0.0)
				count += 1
			terrain_heights[cell] = clampf(sum / float(count), -0.1, 0.1)


func _in_spawn_zone(pos: Vector2i) -> bool:
	return spawn_zone_a.has(pos) or spawn_zone_b.has(pos)


# Returns true only for solid, impassable non-door obstacles.
# Passthrough obstacles and doors are never "blocking" for path/spawn checks.
func is_obstacle(pos: Vector2i, floor_num: int = 0) -> bool:
	var obs: Dictionary = get_obs(pos, floor_num)
	if obs.is_empty():
		return false
	if obs.get("cell_type", "") == "door":
		return false
	var d: ObstacleData = obs.get("data") as ObstacleData
	if d != null and (d.passthrough or d.ramp):
		return false
	return true


func _ensure_pathability() -> void:
	var skip: Dictionary = {}
	for k: Vector2i in reserved_corridor_cells.keys():
		skip[k] = true
	for k: Vector2i in jagged_cells.keys():
		skip[k] = true
	var _terrain_passes := 0
	while not _is_passable() and _terrain_passes < 5:
		TerrainGenerator.smooth(terrain_heights, width, length, skip)
		_terrain_passes += 1


#Cardinal flood from starts over ground cells; true as soon as reached returns true for one cell.
#Steps reject a height change over 0.5, or over 0.25 onto a cell without stairs.
func _flood(starts: Array[Vector2i], reached: Callable) -> bool:
	var dirs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = []
	for start: Vector2i in starts:
		if not visited.has(start):
			visited[start] = true
			queue.append(start)
	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		if bool(reached.call(curr)):
			return true
		for d: Vector2i in dirs:
			var nxt: Vector2i = curr + d
			if nxt.x < 0 or nxt.x >= width or nxt.y < 0 or nxt.y >= length:
				continue
			if visited.has(nxt) or is_obstacle(nxt) or jagged_cells.has(nxt):
				continue
			var h_diff: float = absf(get_terrain_height(nxt) - get_terrain_height(curr))
			if h_diff > 0.5:
				continue
			if h_diff > 0.25 and not has_stairs_at(nxt):
				continue
			visited[nxt] = true
			queue.append(nxt)
	return false


func _is_passable() -> bool:
	var starts: Array[Vector2i] = []
	for x: int in range(width):
		var start := Vector2i(x, 0)
		if not is_obstacle(start):
			starts.append(start)
	return _flood(starts, func(cell: Vector2i) -> bool: return cell.y == length - 1)


func _spawn_exit_blocked(center: Vector2i, zone: Dictionary) -> bool:
	var outer: float = spawn_radius + 4.0
	var starts: Array[Vector2i] = []
	for cell: Vector2i in zone.keys():
		if not is_obstacle(cell) and not jagged_cells.has(cell):
			starts.append(cell)
	var far := func(cell: Vector2i) -> bool:
		return Vector2(float(cell.x - center.x), float(cell.y - center.y)).length() > outer
	return not _flood(starts, far)


func _approach_zone_ok() -> bool:
	return not _spawn_exit_blocked(spawn_center_a, spawn_zone_a) \
		and not _spawn_exit_blocked(spawn_center_b, spawn_zone_b)


func get_adjacent_obstacles(pos: Vector2i, floor_num: int = 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var obs: Dictionary = get_obs(pos + Vector2i(dx, dy), floor_num)
			if not obs.is_empty():
				result.append(obs)
	return result


func get_terrain_height(pos: Vector2i) -> float:
	return terrain_heights.get(pos, 0.0)


func has_stairs_at(pos: Vector2i, floor_num: int = 0) -> bool:
	var obs := get_obs(pos, floor_num)
	if obs.is_empty():
		return false
	var d: ObstacleData = obs.get("data") as ObstacleData
	return d != null and d.ramp


func _reserve_spawn_corridors() -> void:
	reserved_corridor_cells.clear()
	var difficulty: int = unevenness + cover_amount
	var map_area: int = width * length
	var max_width: int = 1 if map_area < 600 else (2 if map_area < 1500 else 3)
	if difficulty <= 1:
		path_width = min(3, max_width)
	elif difficulty <= 4:
		path_width = min(2, max_width)
	else:
		path_width = 1
	@warning_ignore("integer_division")
	var max_paths: int = clampi(1 + map_area / 600, 1, 3)
	if unevenness >= 4:
		max_paths = mini(max_paths, 2)
	var fork_count: int = randi_range(0, max_paths - 1)

	var delta := Vector2(float(spawn_center_b.x - spawn_center_a.x),
		float(spawn_center_b.y - spawn_center_a.y))
	var perp := Vector2(-delta.normalized().y, delta.normalized().x)
	var max_offset: float = minf(float(width), float(length)) * 0.3

	var num_waypoints: int = randi_range(2, 5)
	var waypoints: Array[Vector2i] = [spawn_center_a]
	for i: int in range(num_waypoints):
		var t: float = float(i + 1) / float(num_waypoints + 1)
		var base := Vector2(float(spawn_center_a.x), float(spawn_center_a.y)) + delta * t
		var offset: float = randf_range(-max_offset, max_offset)
		waypoints.append(Vector2i(
			clampi(int(base.x + perp.x * offset), 0, width - 1),
			clampi(int(base.y + perp.y * offset), 0, length - 1)))
	waypoints.append(spawn_center_b)

	for i: int in range(waypoints.size() - 1):
		_carve_path_segment(waypoints[i], waypoints[i + 1])

	for _f: int in range(fork_count):
		var src_idx: int = randi_range(1, waypoints.size() - 2)
		var fork_offset: float = randf_range(-max_offset * 0.5, max_offset * 0.5)
		var fork_end := Vector2i(
			clampi(int(float(spawn_center_b.x) + perp.x * fork_offset), 0, width - 1),
			clampi(int(float(spawn_center_b.y) + perp.y * fork_offset), 0, length - 1))
		_carve_path_segment(waypoints[src_idx], fork_end)

	generation_log.append("Corridor reservation: %d waypoint(s), %d fork(s), width=%d, %d cells reserved" % [
		num_waypoints, fork_count, path_width, reserved_corridor_cells.size()])


func _carve_path_segment(from_pt: Vector2i, to_pt: Vector2i) -> void:
	var hw: int = path_width >> 1
	var pos := from_pt
	while pos != to_pt:
		var ddx: int = to_pt.x - pos.x
		var ddy: int = to_pt.y - pos.y
		var step: Vector2i
		if ddx == 0:
			step = Vector2i(0, signi(ddy))
		elif ddy == 0:
			step = Vector2i(signi(ddx), 0)
		elif randf() < absf(float(ddx)) / (absf(float(ddx)) + absf(float(ddy))):
			step = Vector2i(signi(ddx), 0)
		else:
			step = Vector2i(0, signi(ddy))
		var perp := Vector2i(-step.y, step.x)
		for p: int in range(-hw, hw + 1):
			var cell := Vector2i(
				clampi(pos.x + perp.x * p, 0, width - 1),
				clampi(pos.y + perp.y * p, 0, length - 1))
			reserved_corridor_cells[cell] = true
			terrain_heights[cell] = 0.0
		pos += step
	var end_perp := Vector2i(1, 0) if (to_pt.x - from_pt.x) == 0 else Vector2i(0, 1)
	for p: int in range(-hw, hw + 1):
		var cell := Vector2i(
			clampi(pos.x + end_perp.x * p, 0, width - 1),
			clampi(pos.y + end_perp.y * p, 0, length - 1))
		reserved_corridor_cells[cell] = true
		terrain_heights[cell] = 0.0


func get_nav_passable_cells() -> Dictionary:
	return reserved_corridor_cells


func _place_stairs_at_transitions() -> void:
	var stairs_template: ObstacleData = DataManager.get_obstacle_by_name("Stairs")
	if stairs_template == null:
		return
	var cardinal: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	for y: int in range(length):
		for x: int in range(width):
			var pos := Vector2i(x, y)
			if _in_spawn_zone(pos) or is_obstacle(pos) or building_interiors.has(pos):
				continue
			var qualifies := false
			for dir: Vector2i in cardinal:
				var nb: Vector2i = pos + dir
				if nb.x < 0 or nb.x >= width or nb.y < 0 or nb.y >= length:
					continue
				var h_diff: float = absf(get_terrain_height(nb) - get_terrain_height(pos))
				if h_diff > 0.25 and h_diff <= 0.5:
					qualifies = true
					break
			if qualifies and randf() < 0.4:
				var _stair_obs := {"pos": pos, "size": stairs_template.size, "data": stairs_template, "floor": 0}
				obstacles.append(_stair_obs)
				_obs_map[pos] = _stair_obs


func _rebuild_cover_obstacles() -> void:
	cover_obstacles.clear()
	for obs: Dictionary in obstacles:
		var d: ObstacleData = obs.get("data") as ObstacleData
		if d != null and d.covers:
			cover_obstacles.append(obs)


func _rebuild_droppable_obs_map() -> void:
	droppable_obs_map.clear()
	for obs: Dictionary in obstacles:
		if obs.get("cell_type", "") == "wall":
			continue
		var d: ObstacleData = obs.get("data") as ObstacleData
		if d == null or d.health == 0 or d.drops.is_empty() or d.passthrough or d.ramp:
			continue
		var raw_pos = obs.get("pos", Vector2i(-1, -1))
		var pos := cell_of(raw_pos)
		var fl := floor_of(raw_pos, int(obs.get("floor", 0)))
		if pos.x >= 0:
			droppable_obs_map[Vector3i(pos.x, pos.y, fl)] = true
