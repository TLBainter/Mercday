class_name CavernTests

#Cavern generation, clearance, water, crawling, the breath countdown, scatters and map routing.
#Run: godot --headless --path . -- --cavern-tests

const SEEDS := 20
const POOL_DEPTH := 3
const SPAWN_FIELDS := 5


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	PathCost.water_cost = 2
	PathCost.sunk_depth = 0
	var fields := _seeded_fields(SEEDS)
	_case_generation(res, fields)
	_case_pool_terrain(res, fields)
	_case_clearance(res)
	_case_crawl_pricing(res)
	_case_water_pricing(res)
	_case_sunk_pathing(res)
	_case_enter_water(res)
	_case_climb_out(res)
	_case_crawl_state(res)
	_case_crawl_immune(res)
	_case_breath(res)
	_case_sheet(res)
	_case_drop_variant(res)
	_case_stalactite(res, fields)
	_case_los(res)
	_case_pool_los(res)
	_case_spawns(res, fields)
	_case_routing(res)
	PathCost.water_cost = 2
	PathCost.sunk_depth = 0
	randomize()
	return TestFixtures.summarize(res, "CAVERN")


#Caverns rolled from fixed seeds, so every case that reads them sees the same maps.
static func _seeded_fields(count: int) -> Array[BattlefieldArea]:
	var out: Array[BattlefieldArea] = []
	for i: int in range(count):
		seed(i + 1)
		var ctx := GenerationContext.new()
		out.append(BattlefieldArea.generate_random(null, ctx, "Cavern"))
	return out


#One open row across a 9x3 map; the middle three cells are roofed one pace up.
static func _corridor() -> BattlefieldArea:
	var ceilings: Dictionary = {}
	for x: int in range(1, 8):
		ceilings[Vector2i(x, 1)] = 1.0 if x >= 3 and x <= 5 else 3.0
	return TestFixtures.cavern_field(9, 3, ceilings)


#An open 5x3 room on a 7x5 map whose middle row is a pool three paces deep, floor at -3.
static func _pool_field() -> BattlefieldArea:
	var ceilings: Dictionary = {}
	for y: int in range(1, 4):
		for x: int in range(1, 6):
			ceilings[Vector2i(x, y)] = 3.0
	var f := TestFixtures.cavern_field(7, 5, ceilings)
	for x: int in range(2, 5):
		f.water_cells[Vector2i(x, 2)] = POOL_DEPTH
		f.terrain_heights[Vector2i(x, 2)] = -float(POOL_DEPTH)
		f.ground_heights[Vector2i(x, 2)] = -float(POOL_DEPTH)
	f.bump_path_version()
	return f


#One open row across a 13x3 map, six paces of clearance; cells x 5..7 are a pool three paces deep.
static func _ledge_field() -> BattlefieldArea:
	var ceilings: Dictionary = {}
	for x: int in range(1, 12):
		ceilings[Vector2i(x, 1)] = 6.0
	var f := TestFixtures.cavern_field(13, 3, ceilings)
	for x: int in range(5, 8):
		f.water_cells[Vector2i(x, 1)] = POOL_DEPTH
		f.terrain_heights[Vector2i(x, 1)] = -float(POOL_DEPTH)
		f.ground_heights[Vector2i(x, 1)] = -float(POOL_DEPTH)
	f.bump_path_version()
	return f


static func _merc(merc_name: String, size: int, swim: float = 0.0, vigor: int = 3) -> MercenaryData:
	var m := MercenaryData.new()
	m.merc_name = merc_name
	m.merc_uid = CampaignKnowledge.next_uid()
	m.stats = {"level": 5.0, "luck": 5.0, "size": size, "maximum_hit_points": 20,
		"maximum_endurance_points": 5, "speed": 3.0, "dexterity": 2, "vigor": vigor,
		"pain_limit": 0, "pace": 3, "swim": swim, "climb": 1}
	m.current_hp = 20
	return m


static func _step(f: BattlefieldArea, from: Vector2i, to: Vector2i, size: int) -> int:
	return PathCost.cell_pace_cost(Vector3i(from.x, from.y, 0), Vector3i(to.x, to.y, 0),
		f, {}, 1.0, false, false, size)


static func _case_generation(res: Dictionary, fields: Array[BattlefieldArea]) -> void:
	var broken: int = 0
	var bad_chambers: int = 0
	var bad_entrances: int = 0
	var off_border: int = 0
	var first := ""
	for f: BattlefieldArea in fields:
		var v: Array[String] = CavernGenerator.validate(f)
		if not v.is_empty():
			broken += 1
			if first == "":
				first = v[0]
		var chambers: int = f.cavern_chambers.size()
		if chambers < 2 or chambers > 6:
			bad_chambers += 1
		var ents: int = CavernBatch.entrances(f)
		if ents < 1 or ents > 3:
			bad_entrances += 1
		for cell: Vector2i in f.entrance_cells:
			if cell.x != 0 and cell.y != 0 and cell.x != f.width - 1 and cell.y != f.length - 1:
				off_border += 1
	TestFixtures.check(res, "cavern validate clean", broken == 0,
		"%d of %d with violations %s" % [broken, fields.size(), first])
	TestFixtures.check(res, "cavern chamber count", bad_chambers == 0,
		"%d field(s) outside 2..6 chambers" % bad_chambers)
	TestFixtures.check(res, "cavern entrance count", bad_entrances == 0,
		"%d field(s) outside 1..3 entrances" % bad_entrances)
	TestFixtures.check(res, "cavern entrances on border", off_border == 0,
		"%d entrance cell(s) off the border" % off_border)


#Vector2i -> the surface of the flooded chamber that holds it, for every water cell of the field.
static func _pool_surfaces(f: BattlefieldArea, open: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for ch: Dictionary in f.cavern_chambers:
		if not bool(ch.get("flooded", false)):
			continue
		var surface: float = float(ch.get("surface", ch.get("level", 0.0)))
		var zone: Dictionary = CavernGenerator._spill_zone(open, ch["cells"] as Dictionary)
		for cell: Vector2i in zone.keys():
			if not f.is_water(cell):
				continue
			if out.has(cell) and absf(f.surface_height(cell) - surface) > CavernGenerator.EPS:
				continue
			out[cell] = surface
	return out


static func _case_pool_terrain(res: Dictionary, fields: Array[BattlefieldArea]) -> void:
	var swimmer := _merc("Otter", 1, 1.0)
	var crew: Array[MercenaryData] = [swimmer]
	PathCost.set_water_cost(swimmer, TestFixtures.field_state(_pool_field(), crew))
	var eps: float = CavernGenerator.EPS
	var slope: float = CavernGenerator.SLOPE
	var top: float = float(CavernGenerator.MAX_CLEARANCE)
	var pools: int = 0
	var wet: int = 0
	var bad_floor: int = 0
	var bad_lip: int = 0
	var bad_clear: int = 0
	var bad_step: int = 0
	for f: BattlefieldArea in fields:
		var open: Dictionary = CavernGenerator.open_cells(f)
		var surfaces: Dictionary = _pool_surfaces(f, open)
		for ch: Dictionary in f.cavern_chambers:
			if bool(ch.get("flooded", false)):
				pools += 1
		for cell: Vector2i in f.water_cells.keys():
			wet += 1
			if not surfaces.has(cell):
				bad_floor += 1
				continue
			var surface: float = float(surfaces[cell])
			var floor_h: float = f.get_terrain_height(cell)
			if absf(floor_h - (surface - float(f.water_depth(cell)))) > eps:
				bad_floor += 1
			var clear: float = f.clearance(cell)
			if clear < 1.0 - eps or clear > top + eps:
				bad_clear += 1
			for d: Vector2i in CavernGenerator.DIRS8:
				var nb: Vector2i = cell + d
				if not open.has(nb) or f.is_water(nb):
					continue
				var lip: float = f.get_terrain_height(nb)
				if lip < surface - eps or lip > surface + slope + eps:
					bad_lip += 1
			if f.is_obstacle(cell, 0):
				continue
			for d4: Vector2i in CavernGenerator.DIRS4:
				var rim: Vector2i = cell + d4
				if not open.has(rim) or f.is_water(rim) or f.is_obstacle(rim, 0):
					continue
				if _step(f, rim, cell, 1) < 1 or _step(f, cell, rim, 1) < 1:
					bad_step += 1
	PathCost.water_cost = 2
	TestFixtures.check(res, "seeded caverns hold a pool", pools > 0,
		"%d pool(s) and %d water cell(s) over %d fields" % [pools, wet, fields.size()])
	TestFixtures.check(res, "pool floors sit depth under the surface", bad_floor == 0,
		"%d of %d water cell(s) off the floor" % [bad_floor, wet])
	TestFixtures.check(res, "pool lips level with the surface", bad_lip == 0,
		"%d rim cell(s) off the surface" % bad_lip)
	TestFixtures.check(res, "pool clearance measured from the surface", bad_clear == 0,
		"%d water cell(s) outside 1..%d clear" % [bad_clear, CavernGenerator.MAX_CLEARANCE])
	TestFixtures.check(res, "rim steps priced", bad_step == 0,
		"%d rim step(s) refused" % bad_step)


static func _case_clearance(res: Dictionary) -> void:
	var flat := TestFixtures.exterior_field()
	var open := flat.clearance(Vector2i(2, 2))
	TestFixtures.check(res, "clearance off cavern", is_equal_approx(open, BattlefieldArea.NO_HEADROOM_LIMIT),
		"exterior clearance %.1f" % open)
	var f := _corridor()
	TestFixtures.check(res, "clearance on rock", is_equal_approx(f.clearance(Vector2i(0, 0)), 0.0),
		"rock clearance %.2f" % f.clearance(Vector2i(0, 0)))
	TestFixtures.check(res, "clearance tall cell", is_equal_approx(f.clearance(Vector2i(1, 1)), 3.0),
		"open clearance %.2f" % f.clearance(Vector2i(1, 1)))
	TestFixtures.check(res, "clearance low cell", is_equal_approx(f.clearance(Vector2i(3, 1)), 1.0),
		"low clearance %.2f" % f.clearance(Vector2i(3, 1)))


static func _case_crawl_pricing(res: Dictionary) -> void:
	PathCost.water_cost = 2
	PathCost.sunk_depth = 0
	var f := _corridor()
	var enter := _step(f, Vector2i(2, 1), Vector2i(3, 1), 2)
	var under := _step(f, Vector2i(3, 1), Vector2i(4, 1), 2)
	var leave := _step(f, Vector2i(5, 1), Vector2i(6, 1), 2)
	var upright := _step(f, Vector2i(6, 1), Vector2i(7, 1), 2)
	TestFixtures.check(res, "crawl entry cost", enter == 3, "tall to crawl %d" % enter)
	TestFixtures.check(res, "crawl through cost", under == 2, "crawl to crawl %d" % under)
	TestFixtures.check(res, "crawl exit cost", leave == 2, "crawl to tall %d" % leave)
	TestFixtures.check(res, "upright cost", upright == 1, "tall to tall %d" % upright)
	var small: Array[int] = []
	for x: int in range(1, 7):
		small.append(_step(f, Vector2i(x, 1), Vector2i(x + 1, 1), 1))
	var small_ok := true
	for c: int in small:
		if c != 1:
			small_ok = false
	TestFixtures.check(res, "small walker upright", small_ok, "size 1 costs %s" % str(small))


static func _case_water_pricing(res: Dictionary) -> void:
	var f := _pool_field()
	var swimmer := _merc("Otter", 1, 1.0)
	var heavy := _merc("Wader", 1, 1.0)
	heavy.equipped_armor = TestFixtures.swim_armor(true, false)
	var lubber := _merc("Lubber", 1, 0.0)
	var sinker := _merc("Anvil", 1, 1.0)
	sinker.equipped_armor = TestFixtures.swim_armor(false, true)
	var crew: Array[MercenaryData] = [swimmer, heavy, lubber, sinker]
	var st := TestFixtures.field_state(f, crew)
	var dry := Vector2i(1, 2)
	var wet := Vector2i(2, 2)
	PathCost.set_water_cost(swimmer, st)
	var swim_cost := PathCost.water_cost
	var swim_step := _step(f, dry, wet, 1)
	PathCost.set_water_cost(heavy, st)
	var heavy_cost := PathCost.water_cost
	PathCost.set_water_cost(lubber, st)
	var lubber_cost := PathCost.water_cost
	PathCost.set_water_cost(sinker, st)
	var sink_cost := PathCost.water_cost
	var sink_step := _step(f, dry, wet, 1)
	TestFixtures.check(res, "swimmer water pace", swim_cost == 1, "swimmer cost %d" % swim_cost)
	TestFixtures.check(res, "halved swim pace", heavy_cost == 2, "halve_swim cost %d" % heavy_cost)
	TestFixtures.check(res, "non swimmer pace", lubber_cost == 2, "no swim cost %d" % lubber_cost)
	TestFixtures.check(res, "sinker water pace", sink_cost == CavernRules.SINK_PACE_COST,
		"cannot_swim cost %d" % sink_cost)
	TestFixtures.check(res, "swimmer step priced", swim_step == 1, "step onto water %d" % swim_step)
	TestFixtures.check(res, "sinker step priced", sink_step == CavernRules.SINK_PACE_COST,
		"step onto water %d" % sink_step)
	PathCost.water_cost = 2


static func _case_sunk_pathing(res: Dictionary) -> void:
	var f := _pool_field()
	PathCost.water_cost = 2
	PathCost.sunk_depth = POOL_DEPTH
	var out := _step(f, Vector2i(2, 2), Vector2i(2, 1), 1)
	var across := _step(f, Vector2i(2, 2), Vector2i(3, 2), 1)
	PathCost.sunk_depth = 0
	TestFixtures.check(res, "sunk cannot walk out", out == -1, "water to dry %d" % out)
	TestFixtures.check(res, "sunk swims across", across == 2, "water to water %d" % across)


static func _case_enter_water(res: Dictionary) -> void:
	var f := _pool_field()
	var swimmer := _merc("Otter", 1, 1.0)
	var lubber := _merc("Lubber", 1, 0.0)
	var sinker := _merc("Anvil", 1, 1.0)
	sinker.equipped_armor = TestFixtures.swim_armor(false, true)
	var blessed := _merc("Shallow", 1, 1.0)
	blessed.equipped_armor = TestFixtures.swim_armor(false, true)
	var crew: Array[MercenaryData] = [swimmer, lubber, sinker, blessed]
	var st := TestFixtures.field_state(f, crew)
	blessed.passive_effects.append("immune:drowning")
	var dry := Vector2i(1, 2)
	var wet := Vector2i(2, 2)
	var lines: Array[String] = []
	var swim_halt := CavernRules.on_enter_cell(swimmer, dry, wet, st, lines)
	TestFixtures.check(res, "swimmer drenched", ConstStates.has_state(swimmer, ConstStates.DRENCHED)
		and not ConstStates.has_state(swimmer, ConstStates.INHIBITED) and not swim_halt,
		"halt %s inhibited %s" % [str(swim_halt), str(ConstStates.has_state(swimmer, ConstStates.INHIBITED))])
	CavernRules.on_enter_cell(lubber, dry, wet, st, lines)
	var bound := ConstStates.has_state(lubber, ConstStates.INHIBITED)
	TestFixtures.check(res, "non swimmer inhibited", ConstStates.has_state(lubber, ConstStates.DRENCHED) and bound,
		"drenched %s inhibited %s" % [str(ConstStates.has_state(lubber, ConstStates.DRENCHED)), str(bound)])
	TestFixtures.check(res, "water source is engine",
		CavernRules.is_cavern_sourced(lubber, ConstStates.INHIBITED),
		"sources %s" % str(StateSources.state_sources(lubber, ConstStates.INHIBITED)))
	CavernRules.on_enter_cell(lubber, wet, dry, st, lines)
	TestFixtures.check(res, "leaving water frees", not ConstStates.has_state(lubber, ConstStates.INHIBITED),
		"inhibited %s" % str(ConstStates.has_state(lubber, ConstStates.INHIBITED)))
	var sink_halt := CavernRules.on_enter_cell(sinker, dry, wet, st, lines)
	TestFixtures.check(res, "sinker drowns", sink_halt and st.is_sunk(sinker)
		and st.sunk_depth(sinker) == POOL_DEPTH and ConstStates.has_state(sinker, ConstStates.DROWNING),
		"halt %s depth %d drowning %s" % [str(sink_halt), st.sunk_depth(sinker),
		str(ConstStates.has_state(sinker, ConstStates.DROWNING))])
	CavernRules.on_enter_cell(blessed, dry, wet, st, lines)
	TestFixtures.check(res, "immune merc never drowns", st.is_sunk(blessed)
		and not ConstStates.has_state(blessed, ConstStates.DROWNING),
		"sunk %s drowning %s" % [str(st.is_sunk(blessed)),
		str(ConstStates.has_state(blessed, ConstStates.DROWNING))])


static func _case_climb_out(res: Dictionary) -> void:
	var f := _pool_field()
	var diver := _merc("Anvil", 1, 1.0)
	diver.equipped_armor = TestFixtures.swim_armor(false, true)
	var crew: Array[MercenaryData] = [diver]
	var st := TestFixtures.field_state(f, crew)
	var wet := Vector2i(3, 2)
	TestFixtures.place(st, diver, wet)
	var lines: Array[String] = []
	CavernRules.on_enter_cell(diver, Vector2i(3, 1), wet, st, lines)
	var rim := ClimbAction._find_climb_target(diver, st)
	TestFixtures.check(res, "sunk climb target dry", rim != Vector2i(-1, -1) and not f.is_water(rim)
		and not f.rock_cells.has(rim), "target (%d,%d)" % [rim.x, rim.y])
	st.set_pace_pool(diver, 50)
	var decision: Dictionary = {"climb_target_pos": rim}
	var guard: int = 0
	while st.is_sunk(diver) and guard < 6:
		guard += 1
		MovementExecutor.execute_climb(diver, decision, "Climb", st)
	TestFixtures.check(res, "climb leaves the pool", not st.is_sunk(diver) and st.get_position(diver) == rim,
		"pos (%d,%d) sunk %s" % [st.get_position(diver).x, st.get_position(diver).y, str(st.is_sunk(diver))])
	TestFixtures.check(res, "climb clears drowning", not ConstStates.has_state(diver, ConstStates.DROWNING),
		"drowning %s" % str(ConstStates.has_state(diver, ConstStates.DROWNING)))
	TestFixtures.check(res, "climb clears inhibited", not ConstStates.has_state(diver, ConstStates.INHIBITED),
		"inhibited %s" % str(ConstStates.has_state(diver, ConstStates.INHIBITED)))


static func _case_crawl_state(res: Dictionary) -> void:
	var f := _corridor()
	var big := _merc("Ox", 2)
	var floored := _merc("Tripped", 1)
	var crew: Array[MercenaryData] = [big, floored]
	var st := TestFixtures.field_state(f, crew)
	TestFixtures.place(st, big, Vector2i(1, 1))
	var lines: Array[String] = []
	for x: int in range(1, 6):
		st.positions[big] = Vector2i(x + 1, 1)
		CavernRules.on_enter_cell(big, Vector2i(x, 1), Vector2i(x + 1, 1), st, lines)
		if x == 2:
			TestFixtures.check(res, "low roof starts a crawl", big.crawling
				and ConstStates.has_state(big, ConstStates.DEPOSED),
				"crawling %s deposed %s" % [str(big.crawling),
				str(ConstStates.has_state(big, ConstStates.DEPOSED))])
			TestFixtures.check(res, "crawl paces uncapped", ConstStates.max_paces(big) == -1,
				"max paces %d" % ConstStates.max_paces(big))
	TestFixtures.check(res, "tall roof ends the crawl", not big.crawling
		and not ConstStates.has_state(big, ConstStates.DEPOSED),
		"crawling %s deposed %s" % [str(big.crawling), str(ConstStates.has_state(big, ConstStates.DEPOSED))])
	ConstStates.apply_state(floored, ConstStates.DEPOSED)
	TestFixtures.check(res, "knockdown paces capped", ConstStates.max_paces(floored) == 1,
		"max paces %d" % ConstStates.max_paces(floored))


static func _case_crawl_immune(res: Dictionary) -> void:
	var f := _corridor()
	var stone := _merc("Stone", 2)
	stone.passive_effects.append("immune:deposed")
	var crew: Array[MercenaryData] = [stone]
	var st := TestFixtures.field_state(f, crew)
	TestFixtures.place(st, stone, Vector2i(1, 1))
	var forced := ConstStates.apply_state(stone, ConstStates.DEPOSED)
	TestFixtures.check(res, "forced knockdown refused", not forced
		and not ConstStates.has_state(stone, ConstStates.DEPOSED),
		"applied %s deposed %s" % [str(forced), str(ConstStates.has_state(stone, ConstStates.DEPOSED))])
	var lines: Array[String] = []
	for x: int in range(1, 6):
		st.positions[stone] = Vector2i(x + 1, 1)
		CavernRules.on_enter_cell(stone, Vector2i(x, 1), Vector2i(x + 1, 1), st, lines)
		if x != 2:
			continue
		TestFixtures.check(res, "immune merc crawls Deposed", stone.crawling
			and ConstStates.has_state(stone, ConstStates.DEPOSED),
			"crawling %s deposed %s" % [str(stone.crawling),
			str(ConstStates.has_state(stone, ConstStates.DEPOSED))])
		var again := ConstStates.apply_state(stone, ConstStates.DEPOSED)
		TestFixtures.check(res, "forced knockdown refused while crawling", not again
			and ConstStates.has_state(stone, ConstStates.DEPOSED),
			"applied %s deposed %s" % [str(again),
			str(ConstStates.has_state(stone, ConstStates.DEPOSED))])
	TestFixtures.check(res, "immune crawler stands", not stone.crawling
		and not ConstStates.has_state(stone, ConstStates.DEPOSED),
		"crawling %s deposed %s" % [str(stone.crawling),
		str(ConstStates.has_state(stone, ConstStates.DEPOSED))])


static func _case_breath(res: Dictionary) -> void:
	var f := _pool_field()
	var choker := _merc("Choker", 1, 0.0, 3)
	var drowner := _merc("Drowner", 1, 0.0, 3)
	var crew: Array[MercenaryData] = [choker, drowner]
	var st := TestFixtures.field_state(f, crew)
	ConstStates.apply_state(choker, ConstStates.SUFFOCATING)
	for _i: int in range(3):
		CavernRules.breath_turn_start(choker, st)
	TestFixtures.check(res, "breath holds for vigor", choker.suffocation_hp_loss == 0
		and choker.suffocate_rounds == 3,
		"loss %d rounds %d" % [choker.suffocation_hp_loss, choker.suffocate_rounds])
	CavernRules.breath_turn_start(choker, st)
	TestFixtures.check(res, "breath spends max hp", choker.suffocation_hp_loss == 1
		and choker.current_hp == 19, "loss %d hp %d" % [choker.suffocation_hp_loss, choker.current_hp])
	TestFixtures.check(res, "effective max hp drops", CavernRules.effective_max_hp(choker) == 19,
		"effective %d" % CavernRules.effective_max_hp(choker))
	ConstStates.remove_state(choker, ConstStates.SUFFOCATING)
	CavernRules.breath_turn_start(choker, st)
	CavernRules.breath_turn_start(choker, st)
	var mid_loss := choker.suffocation_hp_loss
	CavernRules.breath_turn_start(choker, st)
	TestFixtures.check(res, "breath restores max hp", mid_loss == 1 and choker.suffocation_hp_loss == 0,
		"loss after 2 clear %d, after 3 %d" % [mid_loss, choker.suffocation_hp_loss])
	ConstStates.apply_state(drowner, ConstStates.DROWNING)
	for _i: int in range(4):
		CavernRules.breath_turn_start(drowner, st)
	TestFixtures.check(res, "drowning shares the count", drowner.suffocation_hp_loss == 1
		and drowner.suffocate_rounds == 4,
		"loss %d rounds %d" % [drowner.suffocation_hp_loss, drowner.suffocate_rounds])


static func _case_sheet(res: Dictionary) -> void:
	var names: Array[String] = ["Stalagmite", "Stalactite", "Column"]
	var hps: Array[int] = [25, 20, 28]
	var missing: Array[String] = []
	var off_spec: Array[String] = []
	var bad_hp: Array[String] = []
	for i: int in range(names.size()):
		var d := DataManager.get_obstacle_by_name(names[i])
		if d == null:
			missing.append(names[i])
			continue
		if d.obstacle_type != "Terrain" or not d.drops.has("Rock Spike") or d.moveable:
			off_spec.append(names[i])
		if d.health != hps[i]:
			bad_hp.append(names[i])
	TestFixtures.check(res, "cavern scatter rows", missing.is_empty(), "missing %s" % str(missing))
	TestFixtures.check(res, "cavern scatter values", off_spec.is_empty(), "off spec %s" % str(off_spec))
	TestFixtures.check(res, "cavern scatter health", bad_hp.is_empty(), "wrong health %s" % str(bad_hp))
	var keys: Array[String] = ["Rock Spike", "Rock Spike:Specialized", "Rock Spike:Great"]
	var bases: Array[String] = ["Basic Makeshift", "Specialized Makeshift", "Great Makeshift"]
	var bad_keys: Array[String] = []
	for i: int in range(keys.size()):
		var w: WeaponData = DataManager.makeshift_weapons.get(keys[i]) as WeaponData
		if w == null or w.base_weapon == null or w.base_weapon.item_name != bases[i] \
				or w.item_name != "Rock Spike":
			bad_keys.append(keys[i])
	TestFixtures.check(res, "rock spike variants", bad_keys.is_empty(), "wrong or missing %s" % str(bad_keys))
	var spike: WeaponData = DataManager.makeshift_weapons.get("Rock Spike") as WeaponData
	TestFixtures.check(res, "rock spike impales", spike != null and spike.damage_types_1.has("Impale"),
		"damage types %s" % (str(spike.damage_types_1) if spike != null else "none"))
	var area := DataManager.get_random_area("Cavern")
	TestFixtures.check(res, "cavern area row", str(area.get("name", "")) == "Cavern"
		and int(area.get("min_size", 0)) == 30 and int(area.get("max_size", 0)) == 45,
		"%s %d..%d" % [str(area.get("name", "")), int(area.get("min_size", 0)), int(area.get("max_size", 0))])


static func _case_drop_variant(res: Dictionary) -> void:
	var f := _pool_field()
	var breaker := _merc("Breaker", 1)
	var crew: Array[MercenaryData] = [breaker]
	var st := TestFixtures.field_state(f, crew)
	var data := ObstacleData.new()
	data.obstacle_name = "Stalagmite"
	data.obstacle_type = "Terrain"
	data.health = 4
	data.drops.append("Rock Spike")
	var cell := Vector2i(1, 1)
	var obs: Dictionary = {"pos": cell, "size": 1, "data": data, "floor": 0,
		"cell_type": "terrain", "drop_variant": "Rock Spike:Great"}
	f.obstacles.append(obs)
	f._obs_map[f.obs_key(cell, 0)] = obs
	var result := ObstacleUtils.apply_damage(obs, 99, st, "Breaker")
	var dropped: Array = st.dropped_weapons.get(cell, []) as Array
	var base_name := ""
	if not dropped.is_empty():
		var w: WeaponData = (dropped[0] as Dictionary).get("weapon") as WeaponData
		if w != null and w.base_weapon != null:
			base_name = w.base_weapon.item_name
	TestFixtures.check(res, "scatter destroyed", bool(result["destroyed"]),
		"destroyed %s" % str(result["destroyed"]))
	TestFixtures.check(res, "drop variant class", base_name == "Great Makeshift",
		"base weapon %s" % base_name)


static func _case_stalactite(res: Dictionary, fields: Array[BattlefieldArea]) -> void:
	var found: int = 0
	var bad_clearance: int = 0
	var bad_variant: int = 0
	for f: BattlefieldArea in fields:
		for obs: Dictionary in f.obstacles:
			var d: ObstacleData = obs.get("data") as ObstacleData
			if d == null or d.obstacle_name != "Stalactite":
				continue
			found += 1
			var cell := BattlefieldArea.cell_of(obs.get("pos", Vector2i.ZERO))
			var restore: float = float(obs.get("restore_clearance", 0.0))
			if not is_equal_approx(f.clearance(cell), restore - CavernScatter.STALACTITE_DROP):
				bad_clearance += 1
			if not CavernScatter.DROP_VARIANTS.has(str(obs.get("drop_variant", ""))):
				bad_variant += 1
	TestFixtures.check(res, "stalactites placed", found > 0, "%d over %d fields" % [found, fields.size()])
	TestFixtures.check(res, "stalactite lowers the roof", found > 0 and bad_clearance == 0,
		"%d of %d off the hang of %.1f" % [bad_clearance, found, CavernScatter.STALACTITE_DROP])
	TestFixtures.check(res, "stalactite carries a drop", found > 0 and bad_variant == 0,
		"%d of %d without a rock spike variant" % [bad_variant, found])
	_case_stalactite_break(res, fields)


#Breaking one gives its cell back the clearance it had before the scatter pass; the field is then spent.
static func _case_stalactite_break(res: Dictionary, fields: Array[BattlefieldArea]) -> void:
	for i: int in range(fields.size() - 1, SPAWN_FIELDS - 1, -1):
		var f := fields[i]
		for obs: Dictionary in f.obstacles:
			var d: ObstacleData = obs.get("data") as ObstacleData
			if d == null or d.obstacle_name != "Stalactite":
				continue
			var cell := BattlefieldArea.cell_of(obs.get("pos", Vector2i.ZERO))
			var restore: float = float(obs.get("restore_clearance", 0.0))
			var crew: Array[MercenaryData] = [_merc("Breaker", 1)]
			var st := TestFixtures.field_state(f, crew)
			ObstacleUtils.apply_damage(obs, 99, st, "")
			TestFixtures.check(res, "broken stalactite frees the roof",
				is_equal_approx(f.clearance(cell), restore),
				"clearance %.2f, wanted %.2f" % [f.clearance(cell), restore])
			return
	TestFixtures.check(res, "broken stalactite frees the roof", false, "no stalactite to break")


static func _case_los(res: Dictionary) -> void:
	var f := _corridor()
	var eyes := _merc("Eyes", 1)
	var mark := _merc("Mark", 1)
	var crew: Array[MercenaryData] = [eyes, mark]
	var st := TestFixtures.field_state(f, crew)
	TestFixtures.place(st, eyes, Vector2i(1, 1))
	TestFixtures.place(st, mark, Vector2i(7, 1))
	var flat := LineOfSight.check(st, eyes, mark)
	st.heights[eyes] = 2
	var high := LineOfSight.check(st, eyes, mark)
	TestFixtures.check(res, "flat ray clears the roof", bool(flat["visible"]),
		"visible %s blocker %s" % [str(flat["visible"]), str(flat["blocker"])])
	TestFixtures.check(res, "high ray hits the roof", not bool(high["visible"]),
		"visible %s" % str(high["visible"]))
	TestFixtures.check(res, "roof named as blocker", str(high["blocker"]).begins_with("ceiling"),
		"blocker %s" % str(high["blocker"]))


static func _case_pool_los(res: Dictionary) -> void:
	var f := _ledge_field()
	var diver := _merc("Anvil", 1, 1.0)
	diver.equipped_armor = TestFixtures.swim_armor(false, true)
	var mark := _merc("Mark", 1)
	var otter := _merc("Otter", 1, 1.0)
	var crew: Array[MercenaryData] = [diver, mark, otter]
	var st := TestFixtures.field_state(f, crew)
	TestFixtures.place(st, mark, Vector2i(1, 1))
	TestFixtures.place(st, diver, Vector2i(5, 1))
	var lines: Array[String] = []
	CavernRules.on_enter_cell(diver, Vector2i(4, 1), Vector2i(5, 1), st, lines)
	TestFixtures.check(res, "diver sinks to the pool floor", st.is_sunk(diver)
		and st.sunk_depth(diver) == POOL_DEPTH, "depth %d" % st.sunk_depth(diver))
	var up := LineOfSight.check(st, diver, mark)
	TestFixtures.check(res, "pool wall blocks the sunk merc", not bool(up["visible"])
		and str(up["blocker"]).begins_with("terrain"),
		"visible %s blocker %s" % [str(up["visible"]), str(up["blocker"])])
	var down := LineOfSight.check(st, mark, diver)
	TestFixtures.check(res, "rim blocks the view down the pool", not bool(down["visible"]),
		"visible %s blocker %s" % [str(down["visible"]), str(down["blocker"])])
	st.set_position(diver, Vector2i(9, 1))
	st.set_sunk(diver, 0)
	TestFixtures.place(st, otter, Vector2i(5, 1))
	CavernRules.on_enter_cell(otter, Vector2i(4, 1), Vector2i(5, 1), st, lines)
	var swim := LineOfSight.check(st, otter, mark)
	TestFixtures.check(res, "swimmer sees over the rim", bool(swim["visible"]) and not st.is_sunk(otter),
		"visible %s sunk %s" % [str(swim["visible"]), str(st.is_sunk(otter))])


#Chebyshev distance from pos to the nearest entrance cell; -1 when the field has none.
static func _entrance_dist(f: BattlefieldArea, pos: Vector2i) -> int:
	var best: int = -1
	for cell: Vector2i in f.entrance_cells:
		var d: int = maxi(absi(cell.x - pos.x), absi(cell.y - pos.y))
		if best < 0 or d < best:
			best = d
	return best


static func _case_spawns(res: Dictionary, fields: Array[BattlefieldArea]) -> void:
	seed(101)
	var far: int = 0
	var out_of_zone: int = 0
	var wet: int = 0
	var placed: int = 0
	for i: int in range(mini(SPAWN_FIELDS, fields.size())):
		var f := fields[i]
		var team_a: Array[MercenaryData] = []
		var team_b: Array[MercenaryData] = []
		for k: int in range(4):
			team_a.append(_merc("A%d" % k, 1))
			team_b.append(_merc("B%d" % k, 1))
		var st := BattleState.create(team_a, team_b, f)
		for m: MercenaryData in team_a:
			placed += 1
			var pos := st.get_position(m)
			if f.is_water(pos):
				wet += 1
			if not f.spawn_zone_a.has(pos) and _entrance_dist(f, pos) > 4:
				far += 1
		for m: MercenaryData in team_b:
			placed += 1
			var pos_b := st.get_position(m)
			if f.is_water(pos_b):
				wet += 1
			if not f.spawn_zone_b.has(pos_b):
				out_of_zone += 1
	TestFixtures.check(res, "party spawns at an entrance", far == 0,
		"%d merc(s) over 4 cells from an entrance" % far)
	TestFixtures.check(res, "enemy spawns in its chamber", out_of_zone == 0,
		"%d merc(s) outside spawn zone B" % out_of_zone)
	TestFixtures.check(res, "nobody spawns in water", wet == 0,
		"%d of %d placed in a pool" % [wet, placed])


static func _case_routing(res: Dictionary) -> void:
	var event := EventData.new()
	event.event_name = "TEST Cave"
	event.event_type = "Primary"
	event.success_formula = "Battle"
	event.enemy = "Bandit"
	event.enemy_counter = "Contract Level"
	event.map_rule = "Cavern"
	var by_rule := ContractTerrain.field_for(event, null, 4, 4)
	var loc := LocationData.new()
	loc.location_name = "TEST Hollow"
	loc.location_type = "Country"
	loc.environment = "Cavern"
	loc.set_meta("temperature_raw", "Below 0")
	event.map_rule = "Location"
	var by_env := ContractTerrain.field_for(event, loc, 4, 4)
	loc.environment = "Desert"
	var open_odds := ContractData.new()
	open_odds.contract_type = "TEST Open"
	var plain_odds: Array[Dictionary] = [{"area": "Desert Plain", "percent": 100}]
	open_odds.terrain_odds = plain_odds
	var plain := ContractTerrain.field_for(event, loc, 4, 4, open_odds)
	TestFixtures.check(res, "map rule cavern routes", by_rule.is_cavern,
		"is_cavern %s area %s" % [str(by_rule.is_cavern), by_rule.area_name])
	TestFixtures.check(res, "cavern environment routes", by_env.is_cavern,
		"is_cavern %s area %s" % [str(by_env.is_cavern), by_env.area_name])
	TestFixtures.check(res, "other environment stays open", not plain.is_cavern,
		"is_cavern %s area %s" % [str(plain.is_cavern), plain.area_name])
	event.map_rule = "Cavern"
	var warnings := ContractDataValidator.validate_event(event, {"_row": 2})
	var map_warnings: int = 0
	for w: String in warnings:
		if w.find("column Map") >= 0:
			map_warnings += 1
	TestFixtures.check(res, "validator accepts cavern", map_warnings == 0,
		"%d Map warning(s)" % map_warnings)
