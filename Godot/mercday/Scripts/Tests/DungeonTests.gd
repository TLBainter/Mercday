class_name DungeonTests

#Dungeon generation, the stair band, cell gates, hall shape, spawns, locks and map routing.
#Run: godot --headless --path . -- --dungeon-tests

const SEEDS := 4
const SEED_BASE := 1
const SIZE_ROLLS := 40
const SPAWN_FIELDS := 3
const MASK_SAMPLE := 6
const BLOCK_SAMPLE := 12
const DEEP_D := 3.0
const D_LIST: Array[float] = [1.0, 1.5, 2.0, 3.0, 4.0, 5.0]


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	var fields := _seeded_fields()
	_case_validate(res, fields)
	_case_sizes(res, fields)
	_case_floors(res, fields)
	_case_masks(res, fields)
	_case_blocks(res, fields)
	_case_entrance(res, fields)
	_case_cells(res, fields)
	_case_lock_table(res)
	_case_reach(res, fields)
	_case_halls(res, fields)
	_case_room_locks(res, fields)
	_case_locked_runtime(res, fields)
	_case_door_rooms(res, fields)
	_case_wanted_reasons(res)
	_case_wanted_routing(res)
	_case_wanted_cache(res)
	_case_warm_rng(res)
	_case_leaps(res)
	_case_spawns(res, fields)
	_case_routing(res)
	_case_determinism(res)
	_case_transparent(res, fields)
	randomize()
	return TestFixtures.summarize(res, "DUNGEON")


static func _seeded(seed_i: int, d: float) -> BattlefieldArea:
	seed(seed_i)
	var ctx := GenerationContext.new()
	ctx.difficulty = d
	return BattlefieldArea.generate_random(null, ctx, "Dungeon")


#SEEDS dungeons per Difficulty in D_LIST, ordered Difficulty first, so every case sees the same maps.
static func _seeded_fields() -> Array[BattlefieldArea]:
	var out: Array[BattlefieldArea] = []
	for di: int in range(D_LIST.size()):
		for s: int in range(SEEDS):
			out.append(_seeded(SEED_BASE + di * SEEDS + s, D_LIST[di]))
	return out


static func _case_validate(res: Dictionary, fields: Array[BattlefieldArea]) -> void:
	for di: int in range(D_LIST.size()):
		var bad: Array[String] = []
		for s: int in range(SEEDS):
			var f := fields[di * SEEDS + s]
			for v: String in DungeonGenerator.validate(f):
				bad.append("seed %d: %s" % [SEED_BASE + di * SEEDS + s, v])
		TestFixtures.check(res, "D=%.1f dungeons validate" % D_LIST[di], bad.is_empty(),
			"%d violation(s): %s" % [bad.size(), ", ".join(bad.slice(0, 5))])


static func _case_sizes(res: Dictionary, fields: Array[BattlefieldArea]) -> void:
	seed(500)
	var rolls_bad: int = 0
	for band: int in range(1, 6):
		var i: int = band - 1
		for _r: int in range(SIZE_ROLLS):
			var spec: Dictionary = DungeonGenerator.size_for(float(band) + 0.5)
			var floors: int = int(spec["floors"])
			var rooms: int = int(spec["rooms"])
			var blocks: int = int(spec["blocks"])
			var side: Vector2i = spec["side"] as Vector2i
			if floors < DungeonGenerator.FLOOR_LO[i] or floors > DungeonGenerator.FLOOR_HI[i]:
				rolls_bad += 1
			elif rooms < DungeonGenerator.ROOM_LO[i] or rooms > DungeonGenerator.ROOM_HI[i]:
				rolls_bad += 1
			elif blocks < 0 or blocks > 2:
				rolls_bad += 1
			elif blocks == 0 and DungeonGenerator.BLOCK_CHANCE[i] >= 100:
				rolls_bad += 1
			elif blocks > 1 and DungeonGenerator.BLOCK_TWO[i] <= 0:
				rolls_bad += 1
			elif side.x != DungeonGenerator.SIDE_LO[i] or side.y != DungeonGenerator.SIDE_HI[i]:
				rolls_bad += 1
	TestFixtures.check(res, "size_for stays in the band table", rolls_bad == 0,
		"%d of %d rolls outside" % [rolls_bad, SIZE_ROLLS * 5])
	var bad_floors: int = 0
	var bad_rooms: int = 0
	var bad_map: int = 0
	for f: BattlefieldArea in fields:
		var b: int = clampi(floori(f.dungeon_difficulty), 1, 5) - 1
		var st: Dictionary = f.dungeon_stats
		var floors: int = f.interior_floor_elevations.size()
		if floors < DungeonGenerator.FLOOR_LO[b] or floors > DungeonGenerator.FLOOR_HI[b]:
			bad_floors += 1
		var chambers: int = int(st.get("chambers", 0))
		if chambers < DungeonGenerator.ROOM_LO[b] or chambers > DungeonGenerator.ROOM_HI[b]:
			bad_rooms += 1
		var fw: int = int(st.get("floor_w", 0))
		var fd: int = int(st.get("floor_d", 0))
		var hi: int = DungeonGenerator.SIDE_HI[b] + DungeonGenerator.CANVAS_SLACK
		if fw < DungeonGenerator.SIDE_LO[b] or fw > hi \
				or fd < DungeonGenerator.SIDE_LO[b] or fd > hi \
				or f.width != fw + 2 + 2 * DungeonGenerator.STREET \
				or f.length != fd + 1 + 2 * DungeonGenerator.STREET:
			bad_map += 1
	TestFixtures.check(res, "floor count fits the band", bad_floors == 0,
		"%d field(s) outside" % bad_floors)
	TestFixtures.check(res, "chamber count fits the band", bad_rooms == 0,
		"%d field(s) outside" % bad_rooms)
	TestFixtures.check(res, "the canvas carries the band side plus slack", bad_map == 0,
		"%d field(s) mis-sized" % bad_map)


#Deep dungeons carry several floors, a chamber on each, a run per gap and a mask that changes by floor.
static func _case_floors(res: Dictionary, fields: Array[BattlefieldArea]) -> void:
	var thin: int = 0
	var bare: int = 0
	var missing_run: int = 0
	var same_mask: int = 0
	var seen: int = 0
	for f: BattlefieldArea in fields:
		if f.dungeon_difficulty < DEEP_D:
			continue
		seen += 1
		var floors: Array[int] = _floor_nums(f)
		if floors.size() < 2:
			thin += 1
			continue
		var rooms_on: Dictionary = {}
		for entry: Dictionary in f.interior_rooms:
			if String(entry.get("name", "")) == DungeonGenerator.CELL_ROW:
				continue
			rooms_on[int(entry.get("floor", 0))] = true
		var runs_on: Dictionary = {}
		for key: Variant in f.stair_run_cells.keys():
			runs_on[(key as Vector3i).z] = true
		var deepest: int = floors[floors.size() - 1]
		for fl: int in floors:
			if not rooms_on.has(fl):
				bare += 1
			if fl != deepest and not runs_on.has(fl):
				missing_run += 1
		if _masks_equal(_mask_of(f, floors[0]), _mask_of(f, deepest)):
			same_mask += 1
	TestFixtures.check(res, "a D=3.0 sample exists to measure", seen > 0, "no deep field")
	TestFixtures.check(res, "deep dungeons carry more than one floor", thin == 0,
		"%d field(s) with one floor" % thin)
	TestFixtures.check(res, "every floor holds a chamber", bare == 0, "%d bare floor(s)" % bare)
	TestFixtures.check(res, "every floor gap carries a stair run", missing_run == 0,
		"%d gap(s) without a run" % missing_run)
	TestFixtures.check(res, "the outline changes from floor to floor", same_mask == 0,
		"%d field(s) with one repeated mask" % same_mask)


#The per-floor mask is one 8-connected blob, wraps every carved cell and never fills its box.
static func _case_masks(res: Dictionary, fields: Array[BattlefieldArea]) -> void:
	var split: int = 0
	var edge_carved: int = 0
	for f: BattlefieldArea in fields:
		for fl: int in _floor_nums(f):
			var mask: Dictionary = _mask_of(f, fl)
			if not _one_region8(mask):
				split += 1
			for key: Variant in f.building_interiors.keys():
				var c: Vector3i = key as Vector3i
				if c.z == fl and not _ring8_in(mask, Vector2i(c.x, c.y)):
					edge_carved += 1
	var loose: int = 0
	for i: int in range(mini(MASK_SAMPLE, fields.size())):
		if int(fields[i].dungeon_stats.get("fill_min", 100)) < DungeonGenerator.FILL_BOXY:
			loose += 1
	TestFixtures.check(res, "each floor mask is one 8-connected outline", split == 0,
		"%d split mask(s)" % split)
	TestFixtures.check(res, "no carved cell sits on the mask edge", edge_carved == 0,
		"%d cell(s) on the edge" % edge_carved)
	TestFixtures.check(res, "an outline leaves its bounding box unfilled", loose > 0,
		"%d of %d maps under %d%%" % [loose, mini(MASK_SAMPLE, fields.size()), DungeonGenerator.FILL_BOXY])


#Cells come in blocks: 4 to 10 per floor, every gate fronting one straight hall.
static func _case_blocks(res: Dictionary, fields: Array[BattlefieldArea]) -> void:
	var bad_count: int = 0
	var split_hall: int = 0
	for f: BattlefieldArea in fields:
		var per_floor: Dictionary = {}
		for entry: Dictionary in f.interior_rooms:
			if String(entry.get("name", "")) != DungeonGenerator.CELL_ROW:
				continue
			var fl: int = int(entry.get("floor", 0))
			var list: Array = per_floor.get(fl, []) as Array
			list.append(entry)
			per_floor[fl] = list
		for key: Variant in per_floor.keys():
			var cells: Array = per_floor[key] as Array
			if cells.size() < DungeonGenerator.CELLS_MIN or cells.size() > DungeonGenerator.CELLS_MAX:
				bad_count += 1
			if not _gates_in_line(f, cells, key as int):
				split_hall += 1
	TestFixtures.check(res, "a floor with cells holds 4 to 10 of them", bad_count == 0,
		"%d floor(s) outside" % bad_count)
	TestFixtures.check(res, "every gate on a floor fronts one hall", split_hall == 0,
		"%d floor(s) with scattered gates" % split_hall)
	var zero: int = 0
	var blocked: int = 0
	for i: int in range(BLOCK_SAMPLE):
		var fld := _seeded(SEED_BASE + 900 + i, 1.0)
		if int(fld.dungeon_stats.get("cells", 0)) == 0:
			zero += 1
		else:
			blocked += 1
	TestFixtures.check(res, "band 1 dungeons carry a block about half the time",
		zero > 0 and blocked > 0, "%d without and %d with over %d maps" % [zero, blocked, BLOCK_SAMPLE])


static func _case_entrance(res: Dictionary, fields: Array[BattlefieldArea]) -> void:
	var wrong_count: int = 0
	var off_floor: int = 0
	var off_shell: int = 0
	var off_foyer: int = 0
	var gaps: int = 0
	for f: BattlefieldArea in fields:
		var doors: int = 0
		for fl: int in _floor_nums(f):
			for cell: Vector3i in _shell_cells(f, fl):
				var ct: String = f.cell_type_at(cell)
				if ct == "door":
					doors += 1
					if cell.z != 0:
						off_floor += 1
				elif ct != "wall":
					gaps += 1
		if doors != 1 or f.entrance_cells.size() != 1:
			wrong_count += 1
		if f.entrance_cells.is_empty():
			continue
		var e: Vector2i = f.entrance_cells[0]
		if not _on_mask_edge(f, e, 0):
			off_shell += 1
		if not _touches_foyer(f, e):
			off_foyer += 1
	TestFixtures.check(res, "exactly one shell door and one entrance cell", wrong_count == 0,
		"%d field(s) with another count" % wrong_count)
	TestFixtures.check(res, "the entrance is on F0", off_floor == 0,
		"%d door(s) below ground" % off_floor)
	TestFixtures.check(res, "the entrance sits on the mask edge", off_shell == 0,
		"%d entrance(s) inside" % off_shell)
	TestFixtures.check(res, "the entrance opens on the Foyer", off_foyer == 0,
		"%d entrance(s) elsewhere" % off_foyer)
	TestFixtures.check(res, "the shell is otherwise solid", gaps == 0, "%d gap(s)" % gaps)


static func _case_cells(res: Dictionary, fields: Array[BattlefieldArea]) -> void:
	var wrong_doors: int = 0
	var unlocked: int = 0
	var no_bars: int = 0
	var wrong_lock: int = 0
	var oversize: int = 0
	var off_block: int = 0
	for f: BattlefieldArea in fields:
		var want: int = DungeonLocks.lock_difficulty_for(f.dungeon_difficulty)
		var cells: int = int(f.dungeon_stats.get("cells", 0))
		var blocks: int = int(f.dungeon_stats.get("blocks", 0))
		if cells < blocks * DungeonGenerator.CELLS_MIN or cells > blocks * DungeonGenerator.CELLS_MAX:
			off_block += 1
		for entry: Dictionary in f.interior_rooms:
			if String(entry.get("name", "")) != DungeonGenerator.CELL_ROW:
				continue
			var r: Rect2i = entry["rect"] as Rect2i
			if r.size.x != 2 or r.size.y != 2:
				oversize += 1
			var doors: Array[Dictionary] = DungeonGenerator._ring_doors(f, r, int(entry.get("floor", 0)))
			if doors.size() != 1:
				wrong_doors += 1
				continue
			if not DungeonLocks.is_locked(doors[0]):
				unlocked += 1
			if not DungeonLocks.has_bars(doors[0]):
				no_bars += 1
			if DungeonLocks.lock_difficulty(doors[0]) != want:
				wrong_lock += 1
	TestFixtures.check(res, "one gate per cell", wrong_doors == 0,
		"%d cell(s) with another count" % wrong_doors)
	TestFixtures.check(res, "every cell gate is locked", unlocked == 0, "%d open gate(s)" % unlocked)
	TestFixtures.check(res, "every cell gate has bars", no_bars == 0, "%d solid gate(s)" % no_bars)
	TestFixtures.check(res, "gate lock matches the Difficulty", wrong_lock == 0,
		"%d mismatched gate(s)" % wrong_lock)
	TestFixtures.check(res, "every cell is 2x2", oversize == 0, "%d mis-sized cell(s)" % oversize)
	TestFixtures.check(res, "the cell total matches the block count", off_block == 0,
		"%d field(s) outside %d to %d per block" % [off_block, DungeonGenerator.CELLS_MIN,
			DungeonGenerator.CELLS_MAX])


#The lock difficulty table and the jam of a failed attempt, on hand-made lock dictionaries.
static func _case_lock_table(res: Dictionary) -> void:
	var table_bad: Array[String] = []
	for step: int in range(1, 11):
		var d: float = float(step) / 2.0
		var got: int = DungeonLocks.lock_difficulty_for(d)
		if got != maxi(1, floori(d - 1.0)):
			table_bad.append("D=%.1f lock %d" % [d, got])
	TestFixtures.check(res, "lock difficulty follows the Difficulty", table_bad.is_empty(),
		", ".join(table_bad))
	var probe: Dictionary = {DungeonLocks.LOCKED_KEY: true, DungeonLocks.DIFFICULTY_KEY: 2,
		DungeonLocks.FAILS_KEY: 0}
	var after: int = DungeonLocks.fail(probe)
	DungeonLocks.fail(probe)
	var jam_ok: bool = after == 3 and DungeonLocks.lock_difficulty(probe) == 4 \
		and DungeonLocks.lock_fails(probe) == 2
	DungeonLocks.unlock(probe)
	TestFixtures.check(res, "a failed attempt jams the lock and unlock clears it",
		jam_ok and not DungeonLocks.is_locked(probe),
		"lock %d fails %d locked %s" % [DungeonLocks.lock_difficulty(probe),
			DungeonLocks.lock_fails(probe), str(DungeonLocks.is_locked(probe))])
	var jammed: Dictionary = {DungeonLocks.LOCKED_KEY: true, DungeonLocks.DIFFICULTY_KEY: 5,
		DungeonLocks.FAILS_KEY: DungeonLocks.MAX_JAM}
	DungeonLocks.fail(jammed)
	TestFixtures.check(res, "a jammed lock stops at three",
		DungeonLocks.lock_difficulty(jammed) == 5 and DungeonLocks.lock_fails(jammed) == 4,
		"lock %d fails %d" % [DungeonLocks.lock_difficulty(jammed), DungeonLocks.lock_fails(jammed)])


static func _case_reach(res: Dictionary, fields: Array[BattlefieldArea]) -> void:
	var cut_off: int = 0
	var gated_chamber: int = 0
	var locked_chamber: int = 0
	var open_cell: int = 0
	var blind_room: int = 0
	for f: BattlefieldArea in fields:
		var start: Vector3i = _foyer_cell(f)
		if start.x < 0:
			continue
		cut_off += GenFixtures.orphan_count(f, start, f.footprint_cells.keys())
		var free_dist: Dictionary = DungeonGenerator._walk_dist(f, start, false)
		for entry: Dictionary in f.interior_rooms:
			var r: Rect2i = entry["rect"] as Rect2i
			var fl2: int = int(entry.get("floor", 0))
			var reached: bool = _room_reached(free_dist, r, fl2)
			if String(entry.get("name", "")) == DungeonGenerator.CELL_ROW:
				if reached:
					open_cell += 1
			elif not reached:
				if DungeonGenerator.locked_room(f, r, fl2):
					locked_chamber += 1
				else:
					gated_chamber += 1
			if not InteriorGenerator.room_accessible_from_doors(f, r, fl2):
				blind_room += 1
	TestFixtures.check(res, "every carved cell reaches the Foyer", cut_off == 0,
		"%d orphan cell(s)" % cut_off)
	TestFixtures.check(res, "chambers need no key", gated_chamber == 0,
		"%d chamber(s) behind a lock, %d locked room(s)" % [gated_chamber, locked_chamber])
	TestFixtures.check(res, "cells stay shut", open_cell == 0,
		"%d cell(s) open without unlocking" % open_cell)
	TestFixtures.check(res, "room interiors reach their own doors", blind_room == 0,
		"%d blind room(s)" % blind_room)


static func _case_halls(res: Dictionary, fields: Array[BattlefieldArea]) -> void:
	var no_loop: int = 0
	var no_dead_end: int = 0
	var empty_halls: int = 0
	var short_halls: int = 0
	var narrow_total: int = 0
	var wide_total: int = 0
	for f: BattlefieldArea in fields:
		if f.dungeon_halls.is_empty():
			empty_halls += 1
		for hall: Dictionary in f.dungeon_halls:
			var r: Rect2i = hall["rect"] as Rect2i
			if maxi(r.size.x, r.size.y) < 3:
				short_halls += 1
			if String(hall.get("name", "")) == DungeonGenerator.HALL_WIDE:
				wide_total += 1
			elif String(hall.get("name", "")) == DungeonGenerator.HALL_NARROW:
				narrow_total += 1
		var per_floor: Dictionary = {}
		for entry: Dictionary in f.interior_rooms:
			if String(entry.get("name", "")) == DungeonGenerator.CELL_ROW:
				continue
			var fl: int = int(entry.get("floor", 0))
			per_floor[fl] = int(per_floor.get(fl, 0)) + 1
		for fl2: Variant in per_floor.keys():
			if int(per_floor[fl2]) < 4:
				continue
			var st: Dictionary = DungeonGenerator.floor_graph(f, fl2 as int)
			if int(st["loops"]) < 1:
				no_loop += 1
			if int(st["dead_ends"]) < 1:
				no_dead_end += 1
	TestFixtures.check(res, "busy floors carry a loop", no_loop == 0, "%d floor(s) without" % no_loop)
	TestFixtures.check(res, "busy floors carry a dead end", no_dead_end == 0,
		"%d floor(s) without" % no_dead_end)
	TestFixtures.check(res, "halls get recorded", empty_halls == 0,
		"%d field(s) with no hall" % empty_halls)
	TestFixtures.check(res, "hall segments run three cells or more", short_halls == 0,
		"%d short segment(s)" % short_halls)
	TestFixtures.check(res, "both hall rows get used", narrow_total > 0 and wide_total > 0,
		"narrow %d wide %d over %d fields" % [narrow_total, wide_total, fields.size()])


static func _case_locked_runtime(res: Dictionary, fields: Array[BattlefieldArea]) -> void:
	var lock: Dictionary = _first_locked_gate(fields)
	if lock.is_empty():
		TestFixtures.check(res, "a locked gate exists to test", false, "no locked door in any field")
		return
	_case_lock_routing(res, lock)
	var state: BattleState = _lock_state(lock["field"])
	_case_lock_pick(res, lock, state)
	_case_lock_key(res, lock, state)


#The first locked door of the seeded fields as {"gate", "field", "cell"}; empty when none is locked.
static func _first_locked_gate(fields: Array[BattlefieldArea]) -> Dictionary:
	for f: BattlefieldArea in fields:
		for key: Variant in f._obs_map.keys():
			var obs: Dictionary = f._obs_map[key] as Dictionary
			if DungeonLocks.is_locked(obs):
				return {"gate": obs, "field": f, "cell": key as Vector3i}
	return {}


#PathCost gating of a locked gate: a wall to a plain mover, a route to a picker and to a key holder.
static func _case_lock_routing(res: Dictionary, lock: Dictionary) -> void:
	var gate: Dictionary = lock["gate"]
	var field: BattlefieldArea = lock["field"]
	var cell: Vector3i = lock["cell"]
	PathCost.set_door_penalty(0)
	TestFixtures.check(res, "a locked gate is not interactable", not PathCost.is_interactable_door(gate),
		"is_interactable_door true")
	TestFixtures.check(res, "a locked gate is no shut door route",
		not PathCost.is_shut_door(field, cell), "is_shut_door true")
	TestFixtures.check(res, "a locked gate cannot be planned through",
		PathCost.shut_door_cost(gate) == -1, "cost %d" % PathCost.shut_door_cost(gate))
	TestFixtures.check(res, "a locked gate blocks the ground pass", not PathCost.is_ground_pass(gate),
		"is_ground_pass true")
	PathCost.lock_mode = PathCost.LOCK_PICK
	PathCost.lock_pace_penalty = 4
	TestFixtures.check(res, "an unwanted locked gate stays a wall to a picker",
		not PathCost.is_interactable_door(gate), "is_interactable_door true")
	PathCost.wanted_locks = [gate]
	TestFixtures.check(res, "a picker routes through a locked gate",
		PathCost.is_interactable_door(gate) and PathCost.is_ground_pass(gate),
		"is_interactable_door %s" % str(PathCost.is_interactable_door(gate)))
	TestFixtures.check(res, "the pick surcharge prices the locked gate",
		PathCost.shut_door_cost(gate) == 5, "cost %d" % PathCost.shut_door_cost(gate))
	PathCost.lock_mode = PathCost.LOCK_KEYS
	PathCost.lock_pace_penalty = 0
	var keyed_ok: bool = PathCost.is_interactable_door(gate)
	gate[DungeonLocks.KEEP_SHUT_KEY] = true
	var shut_ok: bool = PathCost.is_interactable_door(gate)
	gate.erase(DungeonLocks.KEEP_SHUT_KEY)
	TestFixtures.check(res, "a key holder routes through a locked gate unless it is kept shut",
		keyed_ok and not shut_ok, "keyed %s keep_shut %s" % [str(keyed_ok), str(shut_ok)])


#The picking failure path: a hopeless pick leaves the gate locked and reports the failure.
static func _case_lock_pick(res: Dictionary, lock: Dictionary, state: BattleState) -> void:
	var gate: Dictionary = lock["gate"]
	var picker: MercenaryData = _lead(state, 0)
	var old_lock: int = DungeonLocks.lock_difficulty(gate)
	gate[DungeonLocks.DIFFICULTY_KEY] = 99
	gate[DungeonLocks.FAILS_KEY] = 0
	picker.stats["dexterity"] = 1
	picker.stats["luck"] = 0.0
	var lines: Array[String] = []
	var opened: bool = InteractionSystem.interact(picker, gate, state, lines)
	TestFixtures.check(res, "a hopeless pick leaves the gate locked",
		not opened and DungeonLocks.is_locked(gate) and not OpenCloseState.is_open(gate),
		"interact returned true")
	TestFixtures.check(res, "the failed pick is reported", TestFixtures.has_line(lines, "fails to pick"),
		"lines: %s" % ", ".join(lines))
	gate[DungeonLocks.DIFFICULTY_KEY] = old_lock
	gate[DungeonLocks.FAILS_KEY] = 0


#The key path, the gate kept shut, the gate unlocked again and the reset the door penalty makes.
static func _case_lock_key(res: Dictionary, lock: Dictionary, state: BattleState) -> void:
	var gate: Dictionary = lock["gate"]
	var field: BattlefieldArea = lock["field"]
	var picker: MercenaryData = _lead(state, 0)
	var warden: MercenaryData = _lead(state, 1)
	var key_lines: Array[String] = []
	var key_opened: bool = InteractionSystem.interact(warden, gate, state, key_lines)
	TestFixtures.check(res, "a captor unlocks the gate with a key",
		key_opened and not DungeonLocks.is_locked(gate) and OpenCloseState.is_open(gate)
			and TestFixtures.has_line(key_lines, "with a key"),
		"opened %s lines: %s" % [str(key_opened), ", ".join(key_lines)])
	gate[DungeonLocks.LOCKED_KEY] = true
	OpenCloseState.set_open(gate, false)
	field.bump_path_version()
	gate[DungeonLocks.KEEP_SHUT_KEY] = true
	var held_lines: Array[String] = []
	var held: bool = InteractionSystem.interact(warden, gate, state, held_lines)
	gate.erase(DungeonLocks.KEEP_SHUT_KEY)
	TestFixtures.check(res, "a gate kept shut refuses the key",
		not held and DungeonLocks.is_locked(gate), "interact returned true")
	TestFixtures.check(res, "the locked gate reports its lock", TestFixtures.has_line(held_lines, "locked"),
		"lines: %s" % ", ".join(held_lines))
	DungeonLocks.unlock(gate)
	var lines2: Array[String] = []
	var opened2: bool = InteractionSystem.interact(picker, gate, state, lines2)
	var reopened: bool = opened2 and PathCost.shut_door_cost(gate) > 0
	gate[DungeonLocks.LOCKED_KEY] = true
	OpenCloseState.set_open(gate, false)
	field.bump_path_version()
	TestFixtures.check(res, "an unlocked gate opens and prices like a door", reopened,
		"opened %s cost %d" % [str(opened2), PathCost.shut_door_cost(gate)])
	PathCost.set_door_penalty(-1)
	TestFixtures.check(res, "the door penalty clears the mover's lock mode",
		PathCost.lock_mode == PathCost.LOCK_NONE and PathCost.lock_pace_penalty == 0,
		"mode %d penalty %d" % [PathCost.lock_mode, PathCost.lock_pace_penalty])
	TestFixtures.check(res, "the door penalty clears the wanted set",
		PathCost.wanted_locks.is_empty() and PathCost.wanted_sig == "",
		"%d wanted, sig %s" % [PathCost.wanted_locks.size(), PathCost.wanted_sig])


#Every locked door names the room it guards, and the field lists them all.
static func _case_door_rooms(res: Dictionary, fields: Array[BattlefieldArea]) -> void:
	var roomless: int = 0
	var off_room: int = 0
	var counted: int = 0
	var miscount: int = 0
	for f: BattlefieldArea in fields:
		var by_hand: int = 0
		for key: Variant in f._obs_map.keys():
			var obs: Dictionary = f._obs_map[key] as Dictionary
			if obs.get("cell_type", "") != "door" or not DungeonLocks.is_locked(obs):
				continue
			by_hand += 1
			var p: Vector3i = key as Vector3i
			var room: Dictionary = DungeonLocks.room_of(f, obs)
			if room.is_empty():
				roomless += 1
				continue
			var r: Rect2i = room["rect"] as Rect2i
			if int(room["floor"]) != p.z or not r.grow(1).has_point(Vector2i(p.x, p.y)):
				off_room += 1
		var listed: int = DungeonLocks.locked_doors(f).size()
		counted += listed
		if listed != by_hand:
			miscount += 1
	TestFixtures.check(res, "every locked door names its room", roomless == 0,
		"%d door(s) with no room" % roomless)
	TestFixtures.check(res, "the named room holds the door it guards", off_room == 0,
		"%d door(s) outside their room" % off_room)
	TestFixtures.check(res, "the locked door list matches a hand count", miscount == 0,
		"%d field(s) off, %d door(s) listed" % [miscount, counted])
	var again: Array[Dictionary] = DungeonLocks.locked_doors(fields[0])
	TestFixtures.check(res, "the locked door list is cached per field",
		is_same(again, DungeonLocks.locked_doors(fields[0])), "a second call rebuilt the list")


#Rule A: a locked door is a wall to a party merc unless it owes that merc a way through.
static func _case_wanted_reasons(res: Dictionary) -> void:
	var f := _lock_field()
	var a_door: Dictionary = _locked_door(f, Vector3i(3, 5, 0), Rect2i(4, 4, 4, 4))
	var b_door: Dictionary = _locked_door(f, Vector3i(11, 5, 0), Rect2i(12, 4, 4, 4))
	var stray: Dictionary = _locked_door(f, Vector3i(20, 20, 0), Rect2i())
	var state: BattleState = _lock_state(f)
	var picker: MercenaryData = _lead(state, 0)
	var warden: MercenaryData = _lead(state, 1)
	TestFixtures.place(state, picker, Vector2i(1, 1))
	TestFixtures.place(state, warden, Vector2i(1, 2))
	TestFixtures.check(res, "a quiet locked room is a wall",
		DungeonLocks.wanted_reason(picker, a_door, Vector3i(3, 5, 0), state) == "",
		"reason %s" % DungeonLocks.wanted_reason(picker, a_door, Vector3i(3, 5, 0), state))
	TestFixtures.check(res, "a roomless locked door is worth opening",
		DungeonLocks.wanted_reason(picker, stray, Vector3i(20, 20, 0), state)
			== DungeonLocks.REASON_UNKNOWN_ROOM,
		"reason %s" % DungeonLocks.wanted_reason(picker, stray, Vector3i(20, 20, 0), state))
	TestFixtures.place(state, warden, Vector2i(5, 5))
	TestFixtures.check(res, "an enemy inside the room is worth opening for",
		DungeonLocks.wanted_reason(picker, a_door, Vector3i(3, 5, 0), state)
			== DungeonLocks.REASON_ENEMY_INSIDE,
		"reason %s" % DungeonLocks.wanted_reason(picker, a_door, Vector3i(3, 5, 0), state))
	TestFixtures.check(res, "the enemy next door changes nothing",
		DungeonLocks.wanted_reason(picker, b_door, Vector3i(11, 5, 0), state) == "",
		"reason %s" % DungeonLocks.wanted_reason(picker, b_door, Vector3i(11, 5, 0), state))
	TestFixtures.place(state, picker, Vector2i(13, 5))
	TestFixtures.place(state, warden, Vector2i(1, 2))
	TestFixtures.check(res, "a merc shut in a room may pick its way out",
		DungeonLocks.wanted_reason(picker, b_door, Vector3i(11, 5, 0), state)
			== DungeonLocks.REASON_WAY_OUT,
		"reason %s" % DungeonLocks.wanted_reason(picker, b_door, Vector3i(11, 5, 0), state))
	TestFixtures.check(res, "a captor never picks",
		DungeonLocks.wanted_reason(warden, a_door, Vector3i(3, 5, 0), state) == "",
		"reason %s" % DungeonLocks.wanted_reason(warden, a_door, Vector3i(3, 5, 0), state))
	TestFixtures.check(res, "can_open follows the wanted reason",
		not DungeonLocks.can_open(picker, a_door, state)
			and DungeonLocks.can_open(picker, b_door, state),
		"a %s b %s" % [str(DungeonLocks.can_open(picker, a_door, state)),
			str(DungeonLocks.can_open(picker, b_door, state))])


#Only the wanted locked doors are routed through; the rest price out as walls.
static func _case_wanted_routing(res: Dictionary) -> void:
	var f := _lock_field()
	var a_door: Dictionary = _locked_door(f, Vector3i(3, 5, 0), Rect2i(4, 4, 4, 4))
	var b_door: Dictionary = _locked_door(f, Vector3i(11, 5, 0), Rect2i(12, 4, 4, 4))
	var state: BattleState = _lock_state(f)
	var picker: MercenaryData = _lead(state, 0)
	var warden: MercenaryData = _lead(state, 1)
	TestFixtures.place(state, picker, Vector2i(1, 1))
	TestFixtures.place(state, warden, Vector2i(5, 5))
	PathCost.set_mover_doors(picker, state)
	TestFixtures.check(res, "the picker's lock mode is set", PathCost.lock_mode == PathCost.LOCK_PICK,
		"mode %d" % PathCost.lock_mode)
	TestFixtures.check(res, "only the wanted locked door is routed through",
		PathCost.lock_passable(a_door) and not PathCost.lock_passable(b_door),
		"a %s b %s" % [str(PathCost.lock_passable(a_door)), str(PathCost.lock_passable(b_door))])
	TestFixtures.check(res, "an unwanted locked door prices out",
		PathCost.shut_door_cost(b_door) == -1, "cost %d" % PathCost.shut_door_cost(b_door))
	PathCost.set_mover_doors(warden, state)
	TestFixtures.check(res, "a key holder still routes through both locked doors",
		PathCost.lock_passable(a_door) and PathCost.lock_passable(b_door),
		"mode %d" % PathCost.lock_mode)
	PathCost.set_door_penalty(-1)


#The wanted set keys the reach cache, so a door that turns wanted rebuilds the flood.
static func _case_wanted_cache(res: Dictionary) -> void:
	var f := _lock_field()
	var a_door: Dictionary = _locked_door(f, Vector3i(3, 5, 0), Rect2i(4, 4, 4, 4))
	var state: BattleState = _lock_state(f)
	var picker: MercenaryData = _lead(state, 0)
	var warden: MercenaryData = _lead(state, 1)
	TestFixtures.place(state, picker, Vector2i(1, 1))
	TestFixtures.place(state, warden, Vector2i(1, 2))
	PathCost.set_mover_doors(picker, state)
	var quiet: String = PathCost.wanted_sig
	TestFixtures.place(state, warden, Vector2i(5, 5))
	PathCost.set_mover_doors(picker, state)
	var busy: String = PathCost.wanted_sig
	TestFixtures.check(res, "the wanted signature names the wanted door",
		quiet == "" and busy == "3,5,0", "quiet '%s' busy '%s'" % [quiet, busy])
	TestFixtures.check(res, "the wanted door is in the routed set",
		PathCost.wanted_locks.size() == 1 and is_same(PathCost.wanted_locks[0], a_door),
		"%d wanted" % PathCost.wanted_locks.size())
	PathCost.set_door_penalty(-1)


#The spawn warm-up plans without the lock branch, so it draws no RNG and the battle's first roll stands.
static func _case_warm_rng(res: Dictionary) -> void:
	var f := _lock_field()
	_locked_door(f, Vector3i(3, 5, 0), Rect2i(4, 4, 4, 4))
	var state: BattleState = _lock_state(f, 1)
	var picker: MercenaryData = _lead(state, 0)
	var warden: MercenaryData = _lead(state, 1)
	TestFixtures.place(state, picker, Vector2i(1, 1))
	TestFixtures.place(state, warden, Vector2i(5, 5))
	seed(4242)
	var bare: String = "%d|%d|%d" % [randi(), randi(), randi()]
	seed(4242)
	var jumpers: int = ReachCache.warm_jumps(state)
	var after: String = "%d|%d|%d" % [randi(), randi(), randi()]
	TestFixtures.check(res, "warm-up draws no RNG", jumpers == 2 and bare == after,
		"%d jumper(s), %s then %s" % [jumpers, bare, after])
	PathCost.set_mover_doors(picker, state, true)
	var warm_mode: int = PathCost.lock_mode
	PathCost.set_mover_doors(picker, state)
	TestFixtures.check(res, "warm-up plans without locks",
		warm_mode == PathCost.LOCK_NONE and PathCost.lock_mode == PathCost.LOCK_PICK,
		"warm %d, turn %d" % [warm_mode, PathCost.lock_mode])
	ReachCache.clear_caches()
	ReachCache.reachable_for(picker, state, true)
	var warm_key: Array = ((ReachCache.reach_slots[picker] as Dictionary)["key"] as Array).duplicate()
	ReachCache.reachable_for(picker, state)
	var turn_key: Array = (ReachCache.reach_slots[picker] as Dictionary)["key"] as Array
	var wm: int = int(warm_key[warm_key.size() - 2])
	var tm: int = int(turn_key[turn_key.size() - 2])
	TestFixtures.check(res, "warm slot is not reused by the lock turn",
		wm == PathCost.LOCK_NONE and tm == PathCost.LOCK_PICK and warm_key != turn_key,
		"warm mode %d, turn mode %d" % [wm, tm])
	ReachCache.clear_caches()
	PathCost.set_door_penalty(-1)


#Rule D: a wall, an unbroken window or a shut door on the line stops a leap.
static func _case_leaps(res: Dictionary) -> void:
	var f := TestFixtures.exterior_field()
	TestFixtures.put(f, Vector3i(10, 10, 0), {"cell_type": "wall", "size": 4})
	var win: Dictionary = TestFixtures.put(f, Vector3i(12, 10, 0), {"cell_type": "window", "size": 4})
	TestFixtures.put(f, Vector3i(14, 10, 0), {"cell_type": "obstacle", "size": 1})
	var door: Dictionary = TestFixtures.put(f, Vector3i(16, 10, 0),
		{"cell_type": "door", "size": 2, OpenCloseState.KEY: false})
	TestFixtures.put(f, Vector3i(18, 10, 0), {"cell_type": "wall", "size": 4})
	TestFixtures.put(f, Vector3i(19, 11, 0), {"cell_type": "wall", "size": 4})
	TestFixtures.check(res, "open ground leaps clear",
		not PathJump.leap_blocked(f, Vector3i(2, 2, 0), Vector3i(4, 2, 0)), "blocked")
	TestFixtures.check(res, "a wall on the line stops a leap",
		PathJump.leap_wall_blocked(f, Vector3i(9, 10, 0), Vector3i(11, 10, 0)), "not blocked")
	TestFixtures.check(res, "the landing cell is not tested as a wall",
		not PathJump.leap_wall_blocked(f, Vector3i(9, 10, 0), Vector3i(10, 10, 0)), "blocked")
	TestFixtures.check(res, "an unbroken window stops a leap",
		PathJump.leap_wall_blocked(f, Vector3i(11, 10, 0), Vector3i(13, 10, 0)), "not blocked")
	win["broken"] = true
	TestFixtures.check(res, "a broken window is leapt through",
		not PathJump.leap_wall_blocked(f, Vector3i(11, 10, 0), Vector3i(13, 10, 0)), "blocked")
	TestFixtures.check(res, "a low obstacle is leapt over",
		not PathJump.leap_blocked(f, Vector3i(13, 10, 0), Vector3i(15, 10, 0)), "blocked")
	TestFixtures.check(res, "a shut door stops a leap, walls aside",
		PathJump.leap_blocked(f, Vector3i(15, 10, 0), Vector3i(17, 10, 0))
			and not PathJump.leap_wall_blocked(f, Vector3i(15, 10, 0), Vector3i(17, 10, 0)),
		"not blocked")
	TestFixtures.check(res, "the crossed door is reported",
		PathJump.leap_doors(f, Vector3i(15, 10, 0), Vector3i(17, 10, 0)).size() == 1,
		"%d door(s)" % PathJump.leap_doors(f, Vector3i(15, 10, 0), Vector3i(17, 10, 0)).size())
	OpenCloseState.set_open(door, true)
	TestFixtures.check(res, "an open door is leapt through",
		not PathJump.leap_blocked(f, Vector3i(15, 10, 0), Vector3i(17, 10, 0)), "blocked")
	TestFixtures.check(res, "a diagonal wall corner cannot be squeezed through",
		PathJump.leap_wall_blocked(f, Vector3i(18, 11, 0), Vector3i(19, 10, 0)), "not blocked")
	TestFixtures.check(res, "one corner wall leaves the diagonal open",
		not PathJump.leap_wall_blocked(f, Vector3i(18, 9, 0), Vector3i(19, 8, 0)), "blocked")
	var row: Array = [Vector3i(17, 10, 0), 2, {}, [door]]
	OpenCloseState.set_open(door, false)
	TestFixtures.check(res, "a jump row with a shut door on the line is refused",
		PathJump.jump_row_blocked(row), "not blocked")
	OpenCloseState.set_open(door, true)
	TestFixtures.check(res, "a jump row with the door open is allowed",
		not PathJump.jump_row_blocked(row), "blocked")


#A bare dungeon field with two rooms, for the locked door rules.
static func _lock_field() -> BattlefieldArea:
	var f := TestFixtures.exterior_field()
	f.is_interior_map = true
	f.is_dungeon = true
	f.dungeon_difficulty = 3.0
	f.interior_rooms.append({"rect": Rect2i(4, 4, 4, 4), "floor": 0,
		"name": DungeonGenerator.STORAGE_ROW})
	f.interior_rooms.append({"rect": Rect2i(12, 4, 4, 4), "floor": 0,
		"name": DungeonGenerator.ARMORY_ROW})
	return f


#A Lockpick against a Warden on f; a jump of zero or more is set on both before the battle is built.
static func _lock_state(f: BattlefieldArea, jump: int = -1) -> BattleState:
	var team_a: Array[MercenaryData] = [_merc("Lockpick")]
	var team_b: Array[MercenaryData] = [_merc("Warden")]
	if jump >= 0:
		team_a[0].stats["jump"] = jump
		team_b[0].stats["jump"] = jump
	return BattleState.create(team_a, team_b, f)


static func _lead(state: BattleState, team: int) -> MercenaryData:
	return (state.teams[team] as Array)[0] as MercenaryData


#One locked door at cell, guarding rect when a rect is given.
static func _locked_door(f: BattlefieldArea, cell: Vector3i, rect: Rect2i) -> Dictionary:
	var data := ObstacleData.new()
	data.obstacle_name = "Door"
	data.interactable = true
	data.interaction_result = "Open/Close"
	var door: Dictionary = TestFixtures.put(f, cell,
		{"cell_type": "door", "size": 2, "data": data, OpenCloseState.KEY: false})
	var room: Dictionary = {}
	if rect.size.x > 0:
		room = {"rect": rect, "floor": cell.z, "name": DungeonGenerator.STORAGE_ROW}
	DungeonLocks.lock_door(f, cell, 3.0, room)
	f.bump_path_version()
	return door


#Storage and Armory rooms lock at 20% per point of Difficulty; no other door in the dungeon locks.
static func _case_room_locks(res: Dictionary, fields: Array[BattlefieldArea]) -> void:
	var locked_doors: int = 0
	var barred: int = 0
	var stray: int = 0
	var rooms: int = 0
	var locked_rooms: int = 0
	for f: BattlefieldArea in fields:
		var cell_gates: Dictionary = {}
		var room_doors: Dictionary = {}
		for entry: Dictionary in f.interior_rooms:
			var n: String = String(entry.get("name", ""))
			var r: Rect2i = entry["rect"] as Rect2i
			var fl: int = int(entry.get("floor", 0))
			if n == DungeonGenerator.CELL_ROW:
				for gate: Dictionary in DungeonGenerator._ring_doors(f, r, fl):
					cell_gates[gate.get("pos", Vector3i.ZERO) as Vector3i] = true
				continue
			if n != DungeonGenerator.STORAGE_ROW and n != DungeonGenerator.ARMORY_ROW:
				continue
			rooms += 1
			var any_locked: bool = false
			for door: Dictionary in DungeonGenerator._ring_doors(f, r, fl):
				room_doors[door.get("pos", Vector3i.ZERO) as Vector3i] = true
				if DungeonLocks.is_locked(door):
					any_locked = true
			if any_locked:
				locked_rooms += 1
		for key: Variant in f._obs_map.keys():
			var obs: Dictionary = f._obs_map[key] as Dictionary
			if obs.get("cell_type", "") != "door" or not DungeonLocks.is_locked(obs):
				continue
			var p: Vector3i = key as Vector3i
			if cell_gates.has(p):
				continue
			locked_doors += 1
			if DungeonLocks.has_bars(obs):
				barred += 1
			if not room_doors.has(p):
				stray += 1
	TestFixtures.check(res, "a locked room door carries no bars", barred == 0,
		"%d barred door(s) of %d locked" % [barred, locked_doors])
	TestFixtures.check(res, "only Storage and Armory doors lock", stray == 0,
		"%d locked door(s) on another room" % stray)
	TestFixtures.check(res, "Storage and Armory rooms do lock", rooms < 6 or locked_rooms > 0,
		"%d locked of %d room(s)" % [locked_rooms, rooms])


static func _case_spawns(res: Dictionary, fields: Array[BattlefieldArea]) -> void:
	var not_foyer: int = 0
	var empty_b: int = 0
	var wrong_floor: int = 0
	var overlap: int = 0
	for f: BattlefieldArea in fields:
		if f.spawn_zone_b.is_empty():
			empty_b += 1
		if f.spawn_floor_b > f.spawn_floor_a or f.spawn_floor_a != 0:
			wrong_floor += 1
		var foyer: Rect2i = _foyer_entry(f).get("rect", Rect2i()) as Rect2i
		for key: Variant in f.spawn_zone_a.keys():
			var p: Vector2i = key as Vector2i
			if not foyer.has_point(p):
				not_foyer += 1
			if f.spawn_floor_b == f.spawn_floor_a and f.spawn_zone_b.has(p):
				overlap += 1
	TestFixtures.check(res, "team A spawns in the Foyer", not_foyer == 0,
		"%d cell(s) outside" % not_foyer)
	TestFixtures.check(res, "team B has a zone", empty_b == 0, "%d field(s) without" % empty_b)
	TestFixtures.check(res, "team A holds F0 and team B never sits above it", wrong_floor == 0,
		"%d field(s) inverted" % wrong_floor)
	TestFixtures.check(res, "the two zones never share a cell", overlap == 0,
		"%d shared cell(s)" % overlap)
	seed(909)
	var stray_a: int = 0
	var stray_b: int = 0
	for i: int in range(mini(SPAWN_FIELDS, fields.size())):
		var f2 := fields[i]
		#A zone with fewer free cells than the team may legally overflow, so it is not measured.
		if f2.spawn_zone_a.size() < 6 or f2.spawn_zone_b.size() < 6:
			continue
		var teams: Array = GenFixtures.rival_teams("A", "B", 3, TestFixtures.flat_merc)
		var st := BattleState.create(teams[0], teams[1], f2)
		for m: MercenaryData in teams[0]:
			if not f2.spawn_zone_a.has(st.get_position(m)):
				stray_a += 1
		for m2: MercenaryData in teams[1]:
			if not f2.spawn_zone_b.has(st.get_position(m2)):
				stray_b += 1
	TestFixtures.check(res, "team A places inside its zone", stray_a == 0,
		"%d merc(s) outside" % stray_a)
	TestFixtures.check(res, "team B places inside its zone", stray_b == 0,
		"%d merc(s) outside" % stray_b)


static func _case_routing(res: Dictionary) -> void:
	var event := EventData.new()
	event.event_name = "TEST Dungeon"
	event.event_type = "Primary"
	event.success_formula = "Battle"
	event.enemy = "Bandit"
	event.enemy_counter = "Contract Level"
	event.map_rule = "Dungeon"
	var contract := ContractData.new()
	contract.contract_type = "TEST Deep"
	contract.difficulty = 3.5
	var by_rule := ContractTerrain.field_for(event, null, 4, 4, contract)
	TestFixtures.check(res, "the map rule Dungeon routes", by_rule.is_dungeon,
		"is_dungeon %s area %s" % [str(by_rule.is_dungeon), by_rule.area_name])
	TestFixtures.check(res, "the contract Difficulty sizes the dungeon",
		is_equal_approx(by_rule.dungeon_difficulty, 3.5),
		"difficulty %.1f" % by_rule.dungeon_difficulty)
	var locks: Dictionary = {}
	for key: Variant in by_rule._obs_map.keys():
		var obs: Dictionary = by_rule._obs_map[key] as Dictionary
		if DungeonLocks.is_locked(obs):
			locks[DungeonLocks.lock_difficulty(obs)] = true
	TestFixtures.check(res, "a Difficulty 3.5 dungeon locks its gates at 2",
		locks.size() == 1 and locks.has(2), "lock values %s" % str(locks.keys()))
	TestFixtures.check(res, "the Dungeon area is drawable",
		ContractTerrain.drawable(DataManager.get_area_by_name("Dungeon")), "drawable false")
	var warnings := ContractDataValidator.validate_event(event, {"_row": 2})
	var map_warnings: int = 0
	for w: String in warnings:
		if w.contains("column Map"):
			map_warnings += 1
	TestFixtures.check(res, "the validator accepts the Dungeon map rule", map_warnings == 0,
		"%d warning(s)" % map_warnings)
	event.map_rule = "Oubliette"
	var bad_warnings := ContractDataValidator.validate_event(event, {"_row": 2})
	var bad_count: int = 0
	for w2: String in bad_warnings:
		if w2.contains("column Map"):
			bad_count += 1
	TestFixtures.check(res, "the validator still rejects an unknown map", bad_count > 0,
		"%d warning(s)" % bad_count)
	var area: Dictionary = DataManager.get_random_area("Dungeon")
	var top_names: Array[String] = _room_names(RoomCatalog.get_dungeon_rooms_for_floor(area, 0))
	var deep_names: Array[String] = _room_names(RoomCatalog.get_dungeon_rooms_for_floor(area, -1))
	TestFixtures.check(res, "F0 rooms keep the Foyer and drop the deep rows",
		top_names.has(DungeonGenerator.FOYER_ROW) and not top_names.has("Dungeon Torture Chamber"),
		"F0 rows: %s" % ", ".join(top_names))
	TestFixtures.check(res, "deep rooms drop the Foyer and keep the deep rows",
		not deep_names.has(DungeonGenerator.FOYER_ROW) and deep_names.has("Dungeon Torture Chamber"),
		"F-1 rows: %s" % ", ".join(deep_names))


static func _case_determinism(res: Dictionary) -> void:
	var a := _seeded(4242, 3.0)
	var b := _seeded(4242, 3.0)
	var c := _seeded(4243, 3.0)
	TestFixtures.check(res, "one seed gives one header and one obstacle set",
		BattlefieldRender.to_header_string(a) == BattlefieldRender.to_header_string(b) \
			and a.obstacles.size() == b.obstacles.size(),
		"%s / %s" % [BattlefieldRender.to_header_string(a), BattlefieldRender.to_header_string(b)])
	TestFixtures.check(res, "one seed gives one room list", _rooms_text(a) == _rooms_text(b),
		"A: %s" % _rooms_text(a).substr(0, 96))
	TestFixtures.check(res, "one seed gives one entrance and one stat block",
		a.entrance_cells == b.entrance_cells and _stats_text(a) == _stats_text(b),
		"%s vs %s" % [_stats_text(a), _stats_text(b)])
	TestFixtures.check(res, "another seed gives another dungeon",
		_rooms_text(a) != _rooms_text(c), "both: %s" % _rooms_text(a).substr(0, 96))


static func _case_transparent(res: Dictionary, fields: Array[BattlefieldArea]) -> void:
	var bars: Dictionary = {}
	var plain: Dictionary = {}
	for f: BattlefieldArea in fields:
		for key: Variant in f._obs_map.keys():
			var obs: Dictionary = f._obs_map[key] as Dictionary
			if obs.get("cell_type", "") != "door":
				continue
			if DungeonLocks.has_bars(obs):
				bars = obs
			elif plain.is_empty() and not OpenCloseState.is_open(obs):
				plain = obs
		if not bars.is_empty() and not plain.is_empty():
			break
	TestFixtures.check(res, "sight passes iron bars",
		not bars.is_empty() and BattlefieldArea.is_transparent(bars),
		"bars found %s" % str(not bars.is_empty()))
	TestFixtures.check(res, "sight stops at a shut plank door",
		not plain.is_empty() and not BattlefieldArea.is_transparent(plain),
		"plain door found %s" % str(not plain.is_empty()))
	TestFixtures.check(res, "iron bars still block the body",
		not bars.is_empty() and not PathCost.is_ground_pass(bars), "is_ground_pass true")


static func _rect_ring(fp: Rect2i, f: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for x: int in range(fp.position.x, fp.end.x):
		out.append(Vector3i(x, fp.position.y, f))
		out.append(Vector3i(x, fp.end.y - 1, f))
	for y: int in range(fp.position.y + 1, fp.end.y - 1):
		out.append(Vector3i(fp.position.x, y, f))
		out.append(Vector3i(fp.end.x - 1, y, f))
	return out


#Mask cells of one floor with a 4-neighbour outside that floor's mask.
static func _shell_cells(field: BattlefieldArea, f: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for key: Variant in field.footprint_cells.keys():
		var c: Vector3i = key as Vector3i
		if c.z != f:
			continue
		for d: Vector2i in DungeonGenerator.DIRS4:
			if not field.footprint_cells.has(Vector3i(c.x + d.x, c.y + d.y, f)):
				out.append(c)
				break
	return out


static func _on_mask_edge(field: BattlefieldArea, p: Vector2i, f: int) -> bool:
	if not field.footprint_cells.has(Vector3i(p.x, p.y, f)):
		return false
	for d: Vector2i in DungeonGenerator.DIRS4:
		if not field.footprint_cells.has(Vector3i(p.x + d.x, p.y + d.y, f)):
			return true
	return false


#Floor numbers of one field, F0 first and the deepest last.
static func _floor_nums(field: BattlefieldArea) -> Array[int]:
	var out: Array[int] = []
	for k: Variant in field.interior_floor_elevations.keys():
		out.append(k as int)
	out.sort()
	out.reverse()
	return out


static func _mask_of(field: BattlefieldArea, f: int) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in field.footprint_cells.keys():
		var c: Vector3i = key as Vector3i
		if c.z == f:
			out[Vector2i(c.x, c.y)] = true
	return out


static func _masks_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key: Variant in a.keys():
		if not b.has(key):
			return false
	return true


static func _ring8_in(mask: Dictionary, p: Vector2i) -> bool:
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if not mask.has(Vector2i(p.x + dx, p.y + dy)):
				return false
	return true


static func _one_region8(mask: Dictionary) -> bool:
	if mask.is_empty():
		return true
	var start: Vector2i = mask.keys()[0] as Vector2i
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = []
	queue.append(start)
	while not queue.is_empty():
		var p: Vector2i = queue.pop_back()
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var n := Vector2i(p.x + dx, p.y + dy)
				if seen.has(n) or not mask.has(n):
					continue
				seen[n] = true
				queue.append(n)
	return seen.size() == mask.size()


#Gate fronts of every cell on one floor share a row or a column, so one hall serves the block.
static func _gates_in_line(field: BattlefieldArea, cells: Array, f: int) -> bool:
	var fronts: Array[Vector2i] = []
	for entry: Dictionary in cells:
		var r: Rect2i = entry["rect"] as Rect2i
		var gate: Vector2i = _gate_of(field, r, f)
		if gate.x < 0:
			return false
		var inward := Vector2i(clampi(gate.x, r.position.x, r.end.x - 1),
			clampi(gate.y, r.position.y, r.end.y - 1))
		fronts.append(gate + (gate - inward))
	if fronts.is_empty():
		return true
	var same_x: bool = true
	var same_y: bool = true
	for p: Vector2i in fronts:
		if p.x != fronts[0].x:
			same_x = false
		if p.y != fronts[0].y:
			same_y = false
	return same_x or same_y


static func _gate_of(field: BattlefieldArea, r: Rect2i, f: int) -> Vector2i:
	for cell: Vector3i in _rect_ring(r.grow(1), f):
		var obs: Dictionary = field._obs_map.get(cell, {}) as Dictionary
		if obs.get("cell_type", "") == "door":
			return Vector2i(cell.x, cell.y)
	return Vector2i(-1, -1)


#The interior_rooms entry of the Foyer; empty when the field has none.
static func _foyer_entry(field: BattlefieldArea) -> Dictionary:
	for entry: Dictionary in field.interior_rooms:
		if String(entry.get("name", "")) == DungeonGenerator.FOYER_ROW:
			return entry
	return {}


static func _touches_foyer(field: BattlefieldArea, e: Vector2i) -> bool:
	var foyer: Dictionary = _foyer_entry(field)
	return not foyer.is_empty() and (foyer["rect"] as Rect2i).grow(1).has_point(e)


static func _foyer_cell(field: BattlefieldArea) -> Vector3i:
	var foyer: Dictionary = _foyer_entry(field)
	if foyer.is_empty():
		return Vector3i(-1, -1, 0)
	var r: Rect2i = foyer["rect"] as Rect2i
	return Vector3i(r.position.x, r.position.y, int(foyer.get("floor", 0)))


static func _room_reached(dist: Dictionary, r: Rect2i, f: int) -> bool:
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			if dist.has(Vector3i(x, y, f)):
				return true
	return false


static func _room_names(rows: Array[ObstacleData]) -> Array[String]:
	var out: Array[String] = []
	for row: ObstacleData in rows:
		out.append(row.obstacle_name)
	return out


static func _rooms_text(field: BattlefieldArea) -> String:
	var parts := PackedStringArray()
	for entry: Dictionary in field.interior_rooms:
		var r: Rect2i = entry["rect"] as Rect2i
		parts.append("%s F%d %d,%d %dx%d" % [String(entry.get("name", "")),
			int(entry.get("floor", 0)), r.position.x, r.position.y, r.size.x, r.size.y])
	return "; ".join(parts)


#The stat block without the timing field, which never repeats run to run.
static func _stats_text(field: BattlefieldArea) -> String:
	var copy: Dictionary = field.dungeon_stats.duplicate(true)
	copy.erase("ms")
	return str(copy)


static func _merc(merc_name: String) -> MercenaryData:
	return TestFixtures.flat_merc(merc_name)
