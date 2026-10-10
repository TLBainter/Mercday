class_name BattlefieldArea extends RefCounted

const MIN_DIM := 20
const MAX_DIM := 50

#cells per area unit per density level; 0 = minimal, 4 = excessive
const COVER_DENSITY: Array[float] = [0.01, 0.03, 0.05, 0.08, 0.12]
const COVER_AMOUNT_NAMES: Array[String] = ["minimal", "some", "average", "many", "excessive"]

const SPAWN_BUFFER := 3
#Paces past spawn_radius that terrain, scatter obstacles and the exit check keep clear around a spawn.
const SPAWN_CLEAR_MARGIN := 4.0

#Thickness in paces of the sloped slab under a stair tread; the solid band is [tread - this, tread].
const STAIR_SLAB := 0.5
#Returned by stair_headroom() when no stair run overhangs the cell.
const NO_HEADROOM_LIMIT := 1000.0

#Max buildings per combat, indexed by cover_amount (0-4)
const MAX_BUILDINGS_BY_DENSITY: Array[int] = [0, 0, 1, 2, 3]

#A drop edge that crosses no obstacle cell on its way down.
const NO_VAULT := Vector3i(-1, -1, -1)

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
#Generation log lines collected during generation; flushed by EncounterLogger.log_generation().
var generation_log: Array[String] = []
var _obs_map: Dictionary = {}               #Vector2i key on exterior maps, Vector3i(x,y,floor) on interior maps
var cover_obstacles: Array[Dictionary] = [] # pre-filtered to provides_cover==true; rebuilt after generation
var droppable_obs_map: Dictionary = {}      #Vector3i (x, y, floor) -> true; destroyable obstacles that have drops
var is_interior_map: bool = false
var los_version: int = 0                     #bumped whenever sight through a cell changes; invalidates LOS caches
var path_version: int = 0                    #bumped whenever passability changes; keys reach and cost caches
var door_version: int = 0                    #bumped when a door opens, closes or unlocks; the geometry tables stay
var path_static: Dictionary = {}             #int merc_size -> Dictionary Vector3i -> Array; static per-cell walk facts
var neighbor_cache: Dictionary = {}          #Vector3i -> Array[Vector3i]; walk neighbours of the cell
var jump_static: Dictionary = {}             #[merc_size, jump_range] -> Dictionary Vector3i -> Array; jump landings
var jump_geom: Dictionary = {}               #Vector3i origin -> [built_range: int, rows: Array]; size independent landings
var jump_kind_static: Dictionary = {}        #Vector3i -> int; size independent landing kind of the cell
var roof_jump_cache: Dictionary = {}         #[merc_size, jump_range, fall_tolerance] -> Dictionary Vector3i -> Array; roof to roof leaps
var ceiling_cells: Dictionary = {}          # Vector3i(x,y,floor_num) -> true
var stairwell_cells: Dictionary = {}        # Vector3i(x,y,floor_num) -> true
var interior_floor_height: int = 4          # interior cell rows per floor strip
var interior_floor_depth: int = 0
var interior_top_y: int = 0
var interior_floor_elevations: Dictionary = {} # int floor_num -> int base elevation in cells above ground
var stairwell_connections: Dictionary = {}  # Vector3i -> Vector3i; maps stair entry cell to connected cell on adjacent floor
var interior_rooms: Array[Dictionary] = []   # interior only: [{rect, name, floor}] for wireframe labels
var building_footprint: Rect2i = Rect2i()    #interior only: bounding rect of footprint_union; empty on exterior maps
var footprint_cells: Dictionary = {}         #Vector3i(x,y,floor_num) -> true; building cells of that floor, walls inclusive
var footprint_union: Dictionary = {}         #Vector2i -> true; union of every floor mask
var stair_run_cells: Dictionary = {}         #Vector3i(x,y,floor_num) -> true; every carved stair cell incl. landing
var stair_runs: Dictionary = {}              #int floor_num -> Array of {"sx","ly","uy","up"}; one run per building that has a run on that floor
var stair_links: Dictionary = {}             #Vector3i -> Array[Vector3i]; cross-floor stair steps
var well_links: Dictionary = {}              #Vector3i -> Array[Vector3i]; vertical flight through the stair well
var drop_links: Dictionary = {}              #Vector3i -> Array[{to,paces,kind,vault}]; deliberate drops to the footing below
var climb_links: Dictionary = {}             #Vector3i base -> Array[{top,paces,kind,vault}]; the reverse of drop_links
var roof_fly_links: Dictionary = {}          #Vector3i landing cell -> Array[Vector3i] of roof cells a flyer rises to

#Path width: 1 (extreme/dense) -> 3 (gentle/sparse). Computed from unevenness + cover_amount.
#Stored so ConnectivityVerifier can match the width used during nav path generation.
var path_width: int = 2

#Cells reserved as walkable corridors between spawns. Established before any obstacle or terrain
#effect placement so nothing can block them. Exposed to Pathfinder as passable_cells at runtime.
var reserved_corridor_cells: Dictionary = {}

#Vector3i fence gap cells of exterior rooms (patio gates); the furniture pass keeps the cell inside each one free.
var gate_cells: Dictionary = {}

var spawn_center_a: Vector2i = Vector2i.ZERO
var spawn_center_b: Vector2i = Vector2i.ZERO
var spawn_radius: float = 3.0
var spawn_zone_a: Dictionary = {}
var spawn_zone_b: Dictionary = {}

var is_cavern: bool = false
var cavern_ceiling: Dictionary = {}     #Vector2i -> float absolute ceiling elevation; open cells only
var water_cells: Dictionary = {}        #Vector2i -> int pool depth 1..15; the terrain height is the pool floor, the surface is floor + depth
var rock_cells: Dictionary = {}         #Vector2i -> true for every solid rock cell
var ground_heights: Dictionary = {}     #Vector2i -> float natural floor of every open cavern cell
var entrance_cells: Array[Vector2i] = []      #border cells of every entrance; the party entrance comes first
var cavern_chambers: Array[Dictionary] = []   #[{rect, cells, level, peak, peak_size, peak_clearance, edge_clearance, flooded, depth, name}]
var cavern_tunnels: Array[Dictionary] = []    #[{cells, width, height, from, to, kind}]

var is_dungeon: bool = false
var dungeon_difficulty: float = 0.0           #contract Difficulty the dungeon was sized from
var spawn_floor_a: int = 0
var spawn_floor_b: int = 0
var dungeon_halls: Array[Dictionary] = []     #[{rect, floor, name}] straight hall segments
var dungeon_stats: Dictionary = {}
#Planned building only: the rolled plan plus the front door, back door, band column, tries and issues.
var building_plan: Dictionary = {}
#City maps only: one record per stamped building, see BuildingStamp. Empty on every single-building map.
var buildings: Array[Dictionary] = []
var building_planes: Array[Dictionary] = []   #index = building id; int floor_num -> int elevation
var building_id_at: Dictionary = {}           #Vector2i -> int building id, over every cell a building uses
var outdoor_planes: Dictionary = {}           #city maps: {0: ground elevation}; the planes of a cell no building owns
#Roofs (RoofBuilder): one roof level above the top floor of every footprint cell. Keys are Vector3i(x, y, level).
var roof_cells: Dictionary = {}               #Vector3i -> int RoofBuilder.FLAT, SLOPE, PEAK or SOLID
var roof_rise: Dictionary = {}                #Vector3i -> float top of the roof at that cell, over its roof plane
var rugged_cells: Dictionary = {}             #Vector3i -> bool; every SLOPE cell. Movement reads it from stage R2 on
var roof_parts: Array[Dictionary] = []        #one record per roof part, see RoofBuilder
var roof_elevations: Dictionary = {}          #Vector2i -> int roof plane over that footprint cell
var roof_span: Dictionary = {}                #Vector2i -> Vector2(lo, hi): absolute solid span that stops a sight ray
var _roof_levels: Dictionary = {}             #int level -> true, filled from roof_cells
var _roof_level_at: Dictionary = {}           #Vector2i -> int roof level over that cell
var _roof_levels_n: int = -1                  #roof_cells size both caches were built from
#City block maps only (CityGenerator). Both grids are indexed y * width + x and stay empty on every other map.
const SURF_NONE := 0
const SURF_MAIN := 1
const SURF_SIDE := 2
const SURF_SIDEWALK := 3
const SURF_ALLEY := 4
const SURF_LOT := 5
const SURF_NATURE := 6
var is_city: bool = false
var surface_grid: PackedByteArray = PackedByteArray()      #SURF_* per cell
var street_grid: PackedInt32Array = PackedInt32Array()     #street id per cell; -1 when no street owns it
var city: Dictionary = {}                     #tier, main_w, pitch, tries, ms, streets, blocks, plots, lots, stats, issues


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


#An empty area_data rolls one of area_type; a caller that already picked an area passes it in.
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
	if _area_is(area_type, area_data, "City"):
		CityGenerator.generate(f, area_data, ctx)
		return f
	if _area_is(area_type, area_data, "Cavern"):
		var min_sz: int = int(area_data.get("min_size", 30))
		var max_sz: int = maxi(int(area_data.get("max_size", 45)), min_sz)
		f.is_cavern = true
		f.width = randi_range(min_sz, max_sz)
		f.length = randi_range(min_sz, max_sz)
		f.height = 20
		f.unevenness = 0
		CavernGenerator.generate(f, area_data, ctx)
		return _finish(f)
	if _area_is(area_type, area_data, "Dungeon"):
		f.unevenness = 6
		f.is_interior_map = true
		f.is_dungeon = true
		DungeonGenerator.generate(f, area_data, ctx)
		return _finish(f)
	if total_w == 0:
		f.unevenness = 6
		f.is_interior_map = true
		InteriorGenerator.generate_interior(f, area_data, ctx)
		return _finish(f)
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
		ExteriorGenerator.generate_cover(f, config)
		if ConnectivityVerifier.spawns_connected(f) and ExteriorGenerator.approach_zone_ok(f):
			break
	return _finish(f)


static func _area_is(area_type: String, area_data: Dictionary, kind: String) -> bool:
	return area_type == kind or str(area_data.get("type", "")) == kind


#Builds the stair and drop links of a generated map and hands the map back.
static func _finish(f: BattlefieldArea) -> BattlefieldArea:
	NavLinkBuilder.build_stair_links(f)
	NavLinkBuilder.build_drop_links(f)
	return f


func _pick_spawn_centers(ctx: GenerationContext) -> void:
	var max_team: int = maxi(ctx.team_size_a, ctx.team_size_b)
	spawn_radius = maxf(3.0, float(max_team))
	spawn_radius = maxf(spawn_radius, sqrt(float(width * length)) / 12.0)
	var side_a: int = randi() % 4
	var side_b: int = side_a ^ 1
	spawn_center_a = pick_side_center(side_a)
	spawn_center_b = pick_side_center(side_b)
	spawn_zone_a = build_spawn_zone(spawn_center_a)
	spawn_zone_b = build_spawn_zone(spawn_center_b)


func pick_side_center(side: int) -> Vector2i:
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


func build_spawn_zone(center: Vector2i) -> Dictionary:
	var zone: Dictionary = {}
	var ri: int = ceili(spawn_radius)
	for dy: int in range(-ri, ri + 1):
		for dx: int in range(-ri, ri + 1):
			var cell := Vector2i(center.x + dx, center.y + dy)
			if not in_bounds(cell):
				continue
			if Vector2(float(dx), float(dy)).length() <= spawn_radius:
				zone[cell] = true
	return zone


func clamp_position(pos: Vector2i) -> Vector2i:
	return Vector2i(clamp(pos.x, 0, width - 1), clamp(pos.y, 0, length - 1))


#True when the cell lies on the map grid.
func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < width and p.y >= 0 and p.y < length


func in_bounds_xy(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < length


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
func landing_cells() -> Dictionary:
	var out: Dictionary = {}
	for f: Variant in stair_runs.keys():
		for entry: Variant in (stair_runs[f] as Array):
			var run: Dictionary = entry as Dictionary
			out[Vector3i(int(run["sx"]), run_bottom_y(run), (f as int) - 1)] = true
	return out


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
	#An outdoor hut roof is a level of its own: the wall and the furniture below it stay on level 0.
	if floor_num >= 1 and not is_interior_map and not roof_cells.is_empty():
		return {}
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
#Transparency is code owned by design and is not read from a column in Obstacles.tsv.
static func is_transparent(obs: Dictionary) -> bool:
	var ct: String = obs.get("cell_type", "")
	if ct == "window":
		return true
	if obs.get("bars", false) as bool:
		return true
	return ct == "door" and OpenCloseState.is_open(obs)


#Base elevation of a floor plane in cells; 0.0 on exterior maps.
func floor_base_elevation(floor_num: int) -> float:
	if not is_interior_map:
		return 0.0
	return float(interior_floor_elevations.get(floor_num, 0))


#True when floor_num at pos is a roof cell.
func _is_roof(pos: Vector2i, floor_num: int) -> bool:
	return floor_num >= 1 and not roof_cells.is_empty() and roof_cells.has(Vector3i(pos.x, pos.y, floor_num))


#Elevation of floor_num at pos. A city map reads the planes of the building that owns the cell.
func floor_elevation_at(pos: Vector2i, floor_num: int) -> float:
	if _is_roof(pos, floor_num):
		return float(roof_elevations.get(pos, 0))
	if not is_interior_map:
		return 0.0
	if not building_id_at.is_empty():
		var bid: int = int(building_id_at.get(pos, -1))
		if bid >= 0 and bid < building_planes.size():
			var planes: Dictionary = building_planes[bid]
			if planes.has(floor_num):
				return float(planes[floor_num])
	return float(interior_floor_elevations.get(floor_num, 0))


#Floor planes that exist at pos: the map table, or on a city map the owner's planes or the ground plane.
func floor_planes_at(pos: Vector2i) -> Dictionary:
	if building_id_at.is_empty():
		return interior_floor_elevations
	var bid: int = int(building_id_at.get(pos, -1))
	if bid >= 0 and bid < building_planes.size():
		return building_planes[bid]
	return outdoor_planes


#Id of the building that owns pos on a city map; -1 outdoors and on every single-building map.
func building_at(pos: Vector2i) -> int:
	return int(building_id_at.get(pos, -1))


#SURF_* of pos on a city block map; SURF_NONE off the map and on every other map.
func surface_at(pos: Vector2i) -> int:
	if surface_grid.is_empty() or not in_bounds(pos):
		return SURF_NONE
	return surface_grid[pos.y * width + pos.x]


#The run of floor_num whose band holds pos. The only run of a floor is returned as is. {} when there is none.
func stair_run_at(pos: Vector2i, floor_num: int) -> Dictionary:
	if not stair_runs.has(floor_num):
		return {}
	var runs: Array = stair_runs[floor_num] as Array
	if runs.size() == 1:
		return runs[0] as Dictionary
	for entry: Variant in runs:
		var run: Dictionary = entry as Dictionary
		if absi(pos.x - int(run["sx"])) <= 1 and pos.y >= int(run["ly"]) and pos.y <= int(run["uy"]):
			return run
	return {}


#Elevation a unit stands on at pos: floor plane indoors, terrain height outdoors.
#Stair run cells interpolate between the floor below and their own floor.
func cell_base_elevation(pos: Vector2i, floor_num: int) -> float:
	if not is_interior_map:
		if _is_roof(pos, floor_num):
			return float(roof_elevations.get(pos, 0))
		return surface_height(pos)
	if _is_roof(pos, floor_num):
		return float(roof_elevations.get(pos, 0)) + float(roof_rise.get(Vector3i(pos.x, pos.y, floor_num), 0.0))
	if stair_runs.has(floor_num) and is_stair_cell(pos, floor_num):
		var run: Dictionary = stair_run_at(pos, floor_num)
		if not run.is_empty():
			var ly: int = run["ly"] as int
			var uy: int = run["uy"] as int
			var sx: int = run["sx"] as int
			if absi(pos.x - sx) <= 1 and uy > ly and pos.y >= ly and pos.y <= uy:
				var lo := floor_elevation_at(pos, floor_num - 1)
				var hi := floor_elevation_at(pos, floor_num)
				var t := float(pos.y - ly) / float(uy - ly)
				if int(run.get("up", 1)) < 0:
					t = float(uy - pos.y) / float(uy - ly)
				return lo + (hi - lo) * t
	return floor_elevation_at(pos, floor_num)


#Standing elevation for walkers: terrain outdoors; floor plane or tread indoors, relative to floor 0.
func walk_elevation(pos: Vector2i, floor_num: int) -> float:
	if not is_interior_map and _is_roof(pos, floor_num):
		return cell_base_elevation(pos, floor_num)
	if is_interior_map and (floor_num != 0 or in_footprint(pos)):
		return cell_base_elevation(pos, floor_num) - floor_base_elevation(0)
	return surface_height(pos)


#Open height in paces between the walking or swimming surface and the rock ceiling; 0.0 on rock, no limit off a cavern.
func clearance(pos: Vector2i) -> float:
	if not is_cavern:
		return NO_HEADROOM_LIMIT
	if rock_cells.has(pos) or not cavern_ceiling.has(pos):
		return 0.0
	return float(cavern_ceiling[pos]) - surface_height(pos)


func is_water(pos: Vector2i) -> bool:
	return water_cells.has(pos)


#Pool depth in paces at pos; 0 on dry cells.
func water_depth(pos: Vector2i) -> int:
	return int(water_cells.get(pos, 0))


#Elevation a body stands or floats on at pos: the water surface over a pool, else the terrain.
func surface_height(pos: Vector2i) -> float:
	return get_terrain_height(pos) + float(water_depth(pos))


#Natural cavern floor of pos, kept apart from terrain_heights so removed obstacles restore it.
func ground_height(pos: Vector2i) -> float:
	return ground_heights.get(pos, 0.0)


#Clear height in paces under the floor+1 run that overhangs pos; NO_HEADROOM_LIMIT when nothing overhangs it.
func stair_headroom(pos: Vector2i, floor_num: int) -> float:
	if is_cavern:
		return clearance(pos)
	if not is_interior_map:
		return NO_HEADROOM_LIMIT
	var above: int = floor_num + 1
	if not stair_runs.has(above):
		return NO_HEADROOM_LIMIT
	if not is_stair_cell(pos, above) or is_stair_cell(pos, floor_num):
		return NO_HEADROOM_LIMIT
	return cell_base_elevation(pos, above) - STAIR_SLAB - floor_elevation_at(pos, floor_num)


#Climb links rising out of base; empty when the cell carries none.
func climb_links_at(base: Vector3i) -> Array:
	return climb_links.get(base, []) as Array


#Appends obs and maps it at key; a pw x ph object maps every covered cell from its Vector3i key.
func add_obstacle(obs: Dictionary, key: Variant, pw: int = 1, ph: int = 1) -> void:
	obstacles.append(obs)
	if pw == 1 and ph == 1:
		_obs_map[key] = obs
		return
	var k: Vector3i = key
	for ox: int in range(pw):
		for oy: int in range(ph):
			_obs_map[Vector3i(k.x + ox, k.y + oy, k.z)] = obs


#Drops one obstacle cell from the obstacle list and from the obstacle index.
func remove_obstacle_at(obs_cell: Dictionary, raw_pos: Variant, pos: Vector2i, floor_num: int,
		obs_data: ObstacleData) -> void:
	obstacles.erase(obs_cell)
	var dupes: Array = []
	for other: Dictionary in obstacles:
		if other.get("pos") == raw_pos and other.get("data") == obs_data:
			dupes.append(other)
	for other: Dictionary in dupes:
		obstacles.erase(other)
	_obs_map.erase(raw_pos)
	if bool(obs_cell.get("roof_object", false)):
		for ox: int in range(maxi(1, int(obs_cell.get("pw", 1)))):
			for oy: int in range(maxi(1, int(obs_cell.get("ph", 1)))):
				_obs_map.erase(Vector3i(pos.x + ox, pos.y + oy, floor_num))


#Rebuilds footprint_union and the bounding rect from the per-floor masks; generators call it once.
func set_footprint_from_cells() -> void:
	footprint_union.clear()
	for k: Variant in footprint_cells.keys():
		var c: Vector3i = k as Vector3i
		footprint_union[Vector2i(c.x, c.y)] = true
	if footprint_union.is_empty():
		building_footprint = Rect2i()
		return
	var min_x: int = 1 << 30
	var min_y: int = 1 << 30
	var max_x: int = -(1 << 30)
	var max_y: int = -(1 << 30)
	for uk: Variant in footprint_union.keys():
		var p: Vector2i = uk as Vector2i
		min_x = mini(min_x, p.x)
		min_y = mini(min_y, p.y)
		max_x = maxi(max_x, p.x)
		max_y = maxi(max_y, p.y)
	building_footprint = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


#True when pos lies within the building outline on any floor (walls inclusive).
func in_footprint(pos: Vector2i) -> bool:
	if not footprint_union.is_empty():
		return footprint_union.has(pos)
	if building_footprint.size.x <= 0 or building_footprint.size.y <= 0:
		#An outdoor hut carries no footprint mask; its roof cells are the outline.
		return not is_interior_map and not roof_cells.is_empty() and roof_level_at(pos) >= 0
	return building_footprint.has_point(pos)


#True when pos belongs to the building on that floor (walls inclusive).
func in_footprint_floor(pos: Vector2i, floor_num: int) -> bool:
	if not footprint_cells.is_empty():
		return footprint_cells.has(Vector3i(pos.x, pos.y, floor_num))
	return in_footprint(pos)


#True when pos is inside the outline but absent from this floor: rock or earth, never walkable.
func is_void(pos: Vector2i, floor_num: int) -> bool:
	return in_footprint(pos) and not in_footprint_floor(pos, floor_num)


#True when the cell on floor_num is part of a carved stair run (including the landing).
func is_stair_cell(pos: Vector2i, floor_num: int) -> bool:
	return stair_run_cells.has(Vector3i(pos.x, pos.y, floor_num))


#True when the floor plane of floor_num at pos is solid; no slab outdoors, on balconies, or at stair runs.
func has_slab(pos: Vector2i, floor_num: int) -> bool:
	if not is_interior_map or not interior_floor_elevations.has(floor_num):
		return false
	return in_footprint_floor(pos, floor_num) and not is_stair_cell(pos, floor_num)


#Drops both roof level caches; every writer of the roof table that can keep its size calls it.
func invalidate_roof_levels() -> void:
	_roof_levels_n = -1
	_roof_levels.clear()
	_roof_level_at.clear()


#Refills both roof level caches when the table size changed; a writer that keeps the size calls invalidate_roof_levels.
func _rebuild_roof_levels() -> void:
	if _roof_levels_n == roof_cells.size():
		return
	_roof_levels.clear()
	_roof_level_at.clear()
	for k: Variant in roof_cells.keys():
		var c: Vector3i = k as Vector3i
		_roof_levels[c.z] = true
		_roof_level_at[Vector2i(c.x, c.y)] = c.z
	_roof_levels_n = roof_cells.size()


#True when floor_num is a roof level of this map; the roof level is no floor of the building.
func has_roof_level(floor_num: int) -> bool:
	if roof_cells.is_empty():
		return false
	_rebuild_roof_levels()
	return _roof_levels.has(floor_num)


#Roof level over pos; -1 when the cell carries no roof.
func roof_level_at(pos: Vector2i) -> int:
	if roof_cells.is_empty():
		return -1
	_rebuild_roof_levels()
	return int(_roof_level_at.get(pos, -1))


#True when the roof cell of floor_num at pos carries a footing: every roof cell but a solid block.
func is_roof_footing(pos: Vector2i, floor_num: int) -> bool:
	if floor_num < 1 or roof_cells.is_empty():
		return false
	var key := Vector3i(pos.x, pos.y, floor_num)
	if not roof_cells.has(key):
		return false
	return int(roof_cells[key]) != RoofBuilder.SOLID


#True when a merc can stand on the cell of floor_num: floor 0, a slab, a stair run, a balcony, or a roof.
func has_walkable_surface(pos: Vector2i, floor_num: int) -> bool:
	if floor_num == 0:
		return not is_void(pos, 0)
	if has_slab(pos, floor_num) or is_stair_cell(pos, floor_num):
		return true
	if building_interiors.has(Vector3i(pos.x, pos.y, floor_num)):
		return true
	return is_roof_footing(pos, floor_num)


#Drops every cached route cost: the passable geometry of at least one cell changed.
func bump_path_version() -> void:
	path_version += 1
	path_static.clear()
	neighbor_cache.clear()
	jump_static.clear()
	jump_geom.clear()
	jump_kind_static.clear()
	roof_jump_cache.clear()


#Drops every cached flood but keeps the geometry tables: only a door's open or locked state changed.
func bump_door_version() -> void:
	door_version += 1


#Marks an intact window as broken in place; returns false when there is no intact window at pos.
func break_window(pos: Vector2i, floor_num: int) -> bool:
	var obs: Dictionary = get_obs(pos, floor_num)
	if obs.is_empty() or obs.get("cell_type", "") != "window":
		return false
	if obs.get("broken", false) as bool:
		return false
	obs["broken"] = true
	los_version += 1
	NavLinkBuilder.build_drop_links(self)
	bump_path_version()
	return true


func get_obstacle_at_3d(pos: Vector3i) -> Dictionary:
	return _skip_placeholder(_obs_map.get(pos, {}) as Dictionary)


#cell_type of the raw _obs_map entry at an interior cell, stair placeholders included; "" for an empty cell.
func cell_type_at(pos: Vector3i) -> String:
	return String((_obs_map.get(pos, {}) as Dictionary).get("cell_type", ""))


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
	gate_cells.clear()
	ceiling_cells.clear()
	stairwell_cells.clear()
	stairwell_connections.clear()
	interior_floor_elevations.clear()
	building_footprint = Rect2i()
	footprint_cells.clear()
	footprint_union.clear()
	stair_run_cells.clear()
	stair_runs.clear()
	stair_links.clear()
	well_links.clear()
	drop_links.clear()
	climb_links.clear()
	roof_fly_links.clear()
	is_cavern = false
	cavern_ceiling.clear()
	water_cells.clear()
	rock_cells.clear()
	ground_heights.clear()
	entrance_cells.clear()
	cavern_chambers.clear()
	cavern_tunnels.clear()
	is_dungeon = false
	dungeon_difficulty = 0.0
	spawn_floor_a = 0
	spawn_floor_b = 0
	dungeon_halls.clear()
	dungeon_stats.clear()
	building_plan.clear()
	buildings.clear()
	building_planes.clear()
	building_id_at.clear()
	outdoor_planes.clear()
	roof_elevations.clear()
	roof_cells.clear()
	invalidate_roof_levels()
	roof_rise.clear()
	rugged_cells.clear()
	roof_parts.clear()
	roof_span.clear()
	is_city = false
	surface_grid = PackedByteArray()
	street_grid = PackedInt32Array()
	city.clear()


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


func log_total(total_ms: int) -> void:
	log_gen("[GEN] TOTAL: %dms  -  %s" % [total_ms, BattlefieldRender.to_header_string(self)])


func _in_spawn_zone(pos: Vector2i) -> bool:
	return spawn_zone_a.has(pos) or spawn_zone_b.has(pos)


#Returns true only for solid, impassable non-door obstacles.
#Passthrough obstacles and doors are never "blocking" for path/spawn checks.
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
