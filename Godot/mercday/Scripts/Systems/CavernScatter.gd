class_name CavernScatter

const EPS := 0.000001
const CHAMBER_PER_OBJECT := 10
const WIDE_TUNNEL_PER_OBJECT := 6
const NARROW_TUNNEL_PER_OBJECT := 8
const PILE_SPAN := 3
const BOULDER_SPAN := 4
const BOULDER_CLEARANCE := 4.0
const STALACTITE_CLEARANCE := 3.0
const STALACTITE_DROP := 2.0
const STALAGMITE_HEIGHT := 2.0
const ANCHOR_TRIES := 30

const CAVE_NAMES: Array[String] = ["Stalagmite", "Stalactite", "Column"]
const DROP_VARIANTS: Array[String] = ["Rock Spike", "Rock Spike:Specialized", "Rock Spike:Great"]
#Tunnel draw over CAVE_NAMES: stalactite 50, stalagmite 30, column 20.
const TUNNEL_WEIGHTS: Array[int] = [30, 50, 20]
#Chamber draw: 1..70 a cave scatter, 71..90 a rock pile, 91..100 a boulder.
const PILE_ROLL := 70
const BOULDER_ROLL := 90


#Scatters cave objects over a finished cavern; returns the number of objects placed.
static func place(field: BattlefieldArea) -> int:
	if not field.is_cavern:
		return 0
	var protected: Dictionary = _protected_cells(field)
	var tally: Dictionary = {}
	for ch: Dictionary in field.cavern_chambers:
		_fill_chamber(field, ch, protected, tally)
	for tunnel: Dictionary in field.cavern_tunnels:
		_fill_tunnel(field, tunnel, protected, tally)
	var total: int = 0
	for key: String in tally.keys():
		total += int(tally[key])
	field.generation_log.append("[CAVERN] scatters: %d (stalagmite %d, stalactite %d, column %d, pile %d, boulder %d)" % [
		total, int(tally.get("Stalagmite", 0)), int(tally.get("Stalactite", 0)), int(tally.get("Column", 0)),
		int(tally.get("Rock Pile", 0)), int(tally.get("Boulder", 0))])
	return total


#Cells no scatter may take: water, the entrance mouths and both spawn zones.
static func _protected_cells(field: BattlefieldArea) -> Dictionary:
	var out: Dictionary = {}
	for cell: Vector2i in field.water_cells.keys():
		out[cell] = true
	for cell: Vector2i in field.entrance_cells:
		out[cell] = true
	for cell: Vector2i in field.spawn_zone_a.keys():
		out[cell] = true
	for cell: Vector2i in field.spawn_zone_b.keys():
		out[cell] = true
	out[field.spawn_center_a] = true
	out[field.spawn_center_b] = true
	return out


static func _fill_chamber(field: BattlefieldArea, ch: Dictionary, protected: Dictionary, tally: Dictionary) -> void:
	var pool: Array = (ch["cells"] as Dictionary).keys()
	var count: int = int(pool.size() / float(CHAMBER_PER_OBJECT))
	for _i: int in range(count):
		var roll: int = randi_range(1, 100)
		var placed: bool = false
		if roll > BOULDER_ROLL:
			placed = _place_block(field, "Boulder", BOULDER_SPAN, BOULDER_CLEARANCE, pool, protected, tally)
		elif roll > PILE_ROLL:
			placed = _place_block(field, "Rock Pile", PILE_SPAN, 1.0, pool, protected, tally)
		if not placed:
			_place_cave(field, CAVE_NAMES[randi_range(0, CAVE_NAMES.size() - 1)], pool, protected, tally)


static func _fill_tunnel(field: BattlefieldArea, tunnel: Dictionary, protected: Dictionary, tally: Dictionary) -> void:
	var cells: Array = tunnel["cells"] as Array[Vector2i]
	var wide: bool = int(tunnel.get("width", 1)) >= 2
	var per: int = WIDE_TUNNEL_PER_OBJECT if wide else NARROW_TUNNEL_PER_OBJECT
	var count: int = int(cells.size() / float(per))
	for _i: int in range(count):
		var obs_name: String = "Stalactite"
		if wide:
			obs_name = CAVE_NAMES[WeightedTable.pick_index(TUNNEL_WEIGHTS)]
		_place_cave(field, obs_name, cells, protected, tally)


#One 1x1 cave object on a free cell of the pool; solid picks that cut the cavern in two are rolled back.
static func _place_cave(field: BattlefieldArea, obs_name: String, pool: Array,
		protected: Dictionary, tally: Dictionary) -> bool:
	var data: ObstacleData = DataManager.get_obstacle_by_name(obs_name)
	if data == null:
		return false
	var hanging: bool = obs_name == "Stalactite"
	var cell: Vector2i = _free_cell(field, pool, protected, STALACTITE_CLEARANCE if hanging else 1.0)
	if cell.x < 0:
		return false
	var obs: Dictionary = {"pos": cell, "size": data.size, "data": data, "floor": 0, "cell_type": "terrain",
		"drop_variant": DROP_VARIANTS[randi_range(0, DROP_VARIANTS.size() - 1)]}
	if hanging:
		obs["hanging"] = true
		obs["restore_clearance"] = field.clearance(cell)
		obs["height"] = STALACTITE_DROP
		_attach(field, obs)
		field.cavern_ceiling[cell] = float(field.cavern_ceiling[cell]) - STALACTITE_DROP
		_tally(tally, obs_name)
		return true
	obs["height"] = STALAGMITE_HEIGHT if obs_name == "Stalagmite" else field.clearance(cell)
	_attach(field, obs)
	if not _connected(field):
		_detach(field, [obs])
		return false
	_tally(tally, obs_name)
	return true


#A square footprint carrying one obstacle dict per cell, the exterior convention for grown objects.
static func _place_block(field: BattlefieldArea, obs_name: String, span: int, need: float,
		pool: Array, protected: Dictionary, tally: Dictionary) -> bool:
	var data: ObstacleData = DataManager.get_obstacle_by_name(obs_name)
	if data == null or pool.is_empty():
		return false
	for _try: int in range(ANCHOR_TRIES):
		var anchor: Vector2i = pool[randi_range(0, pool.size() - 1)] as Vector2i
		if not _block_free(field, anchor, span, need, protected):
			continue
		var added: Array[Dictionary] = []
		for dy: int in range(span):
			for dx: int in range(span):
				var obs: Dictionary = {"pos": Vector2i(anchor.x + dx, anchor.y + dy), "size": data.size,
					"data": data, "floor": 0, "cell_type": "terrain"}
				added.append(obs)
				_attach(field, obs)
		if _connected(field):
			_tally(tally, obs_name)
			return true
		_detach(field, added)
	return false


static func _block_free(field: BattlefieldArea, anchor: Vector2i, span: int, need: float,
		protected: Dictionary) -> bool:
	for dy: int in range(span):
		for dx: int in range(span):
			var cell := Vector2i(anchor.x + dx, anchor.y + dy)
			if not _usable(field, cell, protected):
				return false
			if field.clearance(cell) < need - EPS:
				return false
	return true


static func _free_cell(field: BattlefieldArea, pool: Array, protected: Dictionary, need: float) -> Vector2i:
	var free: Array[Vector2i] = []
	for cell: Vector2i in pool:
		if _usable(field, cell, protected) and field.clearance(cell) >= need - EPS:
			free.append(cell)
	if free.is_empty():
		return Vector2i(-1, -1)
	return free[randi_range(0, free.size() - 1)]


static func _usable(field: BattlefieldArea, cell: Vector2i, protected: Dictionary) -> bool:
	if protected.has(cell) or field.rock_cells.has(cell) or field.is_water(cell):
		return false
	return field.get_obs(cell, 0).is_empty()


static func _attach(field: BattlefieldArea, obs: Dictionary) -> void:
	field.add_obstacle(obs, field.obs_key(obs["pos"] as Vector2i, 0))


static func _detach(field: BattlefieldArea, added: Array[Dictionary]) -> void:
	for obs: Dictionary in added:
		field.obstacles.erase(obs)
		field._obs_map.erase(field.obs_key(obs["pos"] as Vector2i, 0))


#True while every cell a merc may stand on still reaches the entrances.
static func _connected(field: BattlefieldArea) -> bool:
	if field.entrance_cells.is_empty():
		return true
	var reach: Dictionary = CavernGenerator.reachable_from(field, field.entrance_cells)
	for y: int in range(field.length):
		for x: int in range(field.width):
			var cell := Vector2i(x, y)
			if field.rock_cells.has(cell) or field.is_obstacle(cell, 0):
				continue
			if not reach.has(cell):
				return false
	return true


static func _tally(tally: Dictionary, obs_name: String) -> void:
	tally[obs_name] = int(tally.get(obs_name, 0)) + 1
