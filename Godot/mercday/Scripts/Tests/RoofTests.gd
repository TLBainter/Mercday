class_name RoofTests

#Roof stages R1, R2a, R2b, R2c, R2d, R2e, R3a, R3b and R3c: one roof level per footprint cell, the
#shape fills, the span tables, the readers, the footing a unit stands, paths and is seen on, the
#edges it leaves by, the climb links it comes back up or down, the routes a climber plans over them,
#the cross level leaps a jumper plans from roof to roof, the post a shooter scores and climbs to,
#the parapets, chimneys and dormers it carries and the one flat roof every outdoor hut gets.
#It also holds the city fix cases: the runner that has to climb or leap to get off a roof, the
#spawn probe that refuses a roof with no way down, the grown flood ensure_cells runs and the post
#budget weighed against the walk to a first shot.
#Run: godot --headless --path . -- --roof-tests

const SEED_BASE := 4300
const EPS := 0.001
const FH := 3
const SYNTH_DIM := 28
const CITY_SEED := 9100
const CITY_MARGIN := 4
const CITY_GAP := 3
const MANOR := 0
const TOWER := 1
const COBBLER := 2
const CITY_SPECS: Array = [["Manor", "S", 4], ["Watchtower", "W", 0], ["Cobbler", "N", 0]]
const KINDS: Array[String] = ["flat", "hip", "gable", "lean", "awning", "dome"]
const DUMP_STEM := "user://roof_test"
const HUT_SEED := 4460
const HUT_RECT := Rect2i(8, 8, 6, 6)
const HUT_WALL := 3.0
const POST_WEST := Rect2i(5, 12, 4, 3)
const POST_EAST := Rect2i(18, 12, 4, 3)
const POST_WALL_Y := 10
const POST_SCREEN_X := 16
const POST_FOE_X := 12
const POST_START := Vector3i(13, 13, 0)
const BUDGET_BLOCK := Rect2i(4, 12, 4, 3)
const BUDGET_DOOR_X := 13
const BUDGET_NEAR_Y := 4
const BUDGET_FOE := Vector3i(13, 1, 0)
const BUDGET_START := Vector3i(19, 14, 0)
const BUDGET_EVEN := Vector3i(2, 24, 0)
const BUDGET_FOOT := Vector3i(8, 13, 0)


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_gable_house(res)
	_case_hip_shop(res)
	_case_flat_store(res)
	_case_lean_shed(res)
	_case_awning_stall(res)
	_case_steeple_chapel(res)
	_case_clock_town_hall(res)
	_case_dome_temple(res)
	_case_battlement_tower(res)
	_case_tavern_legacy(res)
	_case_every_building(res)
	_case_wing_lean(res)
	_case_l_hip(res)
	_case_l_gable(res)
	_case_gable_widths(res)
	_case_vertex_heights(res)
	_case_readers(res)
	_case_footing(res)
	_case_edges(res)
	_case_climb(res)
	_case_routes(res)
	_case_roof_jumps(res)
	_case_post_score(res)
	_case_objects(res)
	_case_huts(res)
	_case_sight(res)
	_case_disabled(res)
	_case_no_rng(res)
	_case_determinism(res)
	_case_reset(res)
	_case_data(res)
	_case_validator(res)
	_case_city(res)
	_case_flee_roof(res)
	_case_spawn_roof(res)
	_case_reach_grow(res)
	_case_post_budget(res)
	_case_hover_reach(res)
	_case_upper_reach(res)
	_case_probe_state(res)
	_case_reload_reach(res)
	_case_roof_cache(res)
	_case_dump(res)
	_case_wireframe_keys(res)
	randomize()
	return TestFixtures.summarize(res, "ROOF")


static func _case_gable_house(res: Dictionary) -> void:
	var f: BattlefieldArea = _field("Small House", "S", SEED_BASE)
	var levels: Array[String] = _level_errors(f)
	TestFixtures.check(res, "roof_gable every footprint cell carries one roof cell", levels.is_empty(),
		TestFixtures.detail(levels, f.footprint_union.size(), "cell(s)"))
	var part: Dictionary = _first_part(f)
	var rect: Rect2i = part.get("rect", Rect2i()) as Rect2i
	var cells: Array = part.get("cells", []) as Array
	var axis: String = _axis_of(rect, "S")
	TestFixtures.check(res, "roof_gable the small house roofs as one rectangular gable",
		f.roof_parts.size() == 1 and String(part.get("shape", "")) == "Gable"
		and String(part.get("kind", "")) == "gable" and String(part.get("axis", "")) == axis
		and cells.size() == rect.size.x * rect.size.y,
		"%d part(s), %s/%s axis %s, %d of %d cell(s)" % [f.roof_parts.size(),
			String(part.get("shape", "")), String(part.get("kind", "")), String(part.get("axis", "")),
			cells.size(), rect.size.x * rect.size.y])
	var span: int = rect.size.x if axis == "y" else rect.size.y
	var along: int = rect.size.y if axis == "y" else rect.size.x
	var want_peaks: int = along * (1 if span % 2 == 1 else 2)
	var peaks: int = int(RoofBuilder.counts(f, part).get("peak", 0))
	TestFixtures.check(res, "roof_gable the ridge runs the whole long side", peaks == want_peaks,
		"%d peak cell(s) for %d rows of %d" % [peaks, along, 1 if span % 2 == 1 else 2])
	var errs: Array[String] = _gable_errors(f, part, axis)
	TestFixtures.check(res, "roof_gable every cell keeps its step, type and rise", errs.is_empty(),
		TestFixtures.detail(errs, cells.size(), "cell(s)"))
	var rugged: Array[String] = _rugged_errors(f, part)
	TestFixtures.check(res, "roof_gable only the slope cells are rugged", rugged.is_empty(),
		TestFixtures.detail(rugged, cells.size(), "cell(s)"))
	var want_rise: float = RoofBuilder.PITCH * float(int((span + 1) / 2.0))
	TestFixtures.check(res, "roof_gable max_rise is the pitch over the short side",
		absf(float(part.get("max_rise", 0.0)) - want_rise) < EPS,
		"%.2f for a span of %d, want %.2f" % [float(part.get("max_rise", 0.0)), span, want_rise])


static func _case_hip_shop(res: Dictionary) -> void:
	var f: BattlefieldArea = _field("Apothecary", "S", SEED_BASE + 1)
	var part: Dictionary = _first_part(f)
	var rect: Rect2i = part.get("rect", Rect2i()) as Rect2i
	var cells: Array = part.get("cells", []) as Array
	var level: int = int(part.get("level", 0))
	TestFixtures.check(res, "roof_hip the apothecary roofs as one rectangular hip",
		f.roof_parts.size() == 1 and String(part.get("shape", "")) == "Hip"
		and String(part.get("kind", "")) == "hip" and String(part.get("axis", "")) == ""
		and cells.size() == rect.size.x * rect.size.y,
		"%d part(s), %s/%s, %d of %d cell(s)" % [f.roof_parts.size(), String(part.get("shape", "")),
			String(part.get("kind", "")), cells.size(), rect.size.x * rect.size.y])
	var corners: Array[Vector2i] = [rect.position, Vector2i(rect.end.x - 1, rect.position.y),
		Vector2i(rect.position.x, rect.end.y - 1), rect.end - Vector2i.ONE]
	var bad_corner: Array[String] = []
	var bad_edge: Array[String] = []
	for c: Vector2i in corners:
		if _type_at(f, level, c) != RoofBuilder.PEAK:
			bad_corner.append("%s type %d" % [str(c), _type_at(f, level, c)])
		var inward := Vector2i(1 if c.x == rect.position.x else -1, 0)
		var beside: Vector2i = c + inward
		if _type_at(f, level, beside) != RoofBuilder.SLOPE:
			bad_edge.append("%s type %d" % [str(beside), _type_at(f, level, beside)])
	TestFixtures.check(res, "roof_hip every rect corner is a peak", bad_corner.is_empty(),
		TestFixtures.detail(bad_corner, corners.size(), "corner(s)"))
	TestFixtures.check(res, "roof_hip the cell beside a corner slopes", bad_edge.is_empty(),
		TestFixtures.detail(bad_edge, corners.size(), "cell(s)"))
	var errs: Array[String] = _hip_errors(f, part)
	TestFixtures.check(res, "roof_hip every cell keeps its ring step, type and rise", errs.is_empty(),
		TestFixtures.detail(errs, cells.size(), "cell(s)"))
	var want_rise: float = RoofBuilder.PITCH * float(int((mini(rect.size.x, rect.size.y) + 1) / 2.0))
	var flat: int = int(RoofBuilder.counts(f, part).get("flat", 0))
	TestFixtures.check(res, "roof_hip max_rise is the pitch over the short side and nothing lies flat",
		absf(float(part.get("max_rise", 0.0)) - want_rise) < EPS and flat == 0,
		"%.2f want %.2f, %d flat cell(s)" % [float(part.get("max_rise", 0.0)), want_rise, flat])


static func _case_flat_store(res: Dictionary) -> void:
	var f: BattlefieldArea = _field("General Store", "S", SEED_BASE + 2)
	var part: Dictionary = _first_part(f)
	var cells: Array = part.get("cells", []) as Array
	var errs: Array[String] = _flat_errors(f, part)
	TestFixtures.check(res, "roof_flat the general store lies flat at its roof plane",
		String(part.get("shape", "")) == "Flat" and String(part.get("kind", "")) == "flat"
		and errs.is_empty(), "%s/%s; %s" % [String(part.get("shape", "")),
			String(part.get("kind", "")), TestFixtures.detail(errs, cells.size(), "cell(s)")])
	var tally: Dictionary = RoofBuilder.counts(f, part)
	TestFixtures.check(res, "roof_flat a flat roof is never rugged",
		f.rugged_cells.is_empty() and int(tally.get("slope", 0)) == 0
		and int(tally.get("peak", 0)) == 0 and int(tally.get("solid", 0)) == 0,
		"%d rugged, %s" % [f.rugged_cells.size(), str(tally)])
	var bad: Array[String] = []
	for c: Vector2i in cells:
		var plane: float = float(int(f.roof_elevations.get(c, -999)))
		var span: Vector2 = f.roof_span.get(c, Vector2(-9.0, -9.0))
		if not is_equal_approx(span.x, plane) or not is_equal_approx(span.y, plane):
			bad.append("%s span %s plane %.1f" % [str(c), str(span), plane])
	TestFixtures.check(res, "roof_flat the solid span is the roof plane alone",
		bad.is_empty() and absf(float(part.get("max_rise", 0.0))) < EPS,
		"%s; max_rise %.2f" % [TestFixtures.detail(bad, cells.size(), "cell(s)"), float(part.get("max_rise", 0.0))])


static func _case_lean_shed(res: Dictionary) -> void:
	var south: BattlefieldArea = _field("Storage Shed", "S", SEED_BASE + 3)
	var north: BattlefieldArea = _field("Storage Shed", "N", SEED_BASE + 3)
	var sp: Dictionary = _first_part(south)
	var np: Dictionary = _first_part(north)
	TestFixtures.check(res, "roof_lean the shed roof rises toward its front",
		String(sp.get("shape", "")) == "Lean-to" and String(sp.get("kind", "")) == "lean"
		and String(sp.get("high", "")) == "s" and String(np.get("high", "")) == "n",
		"south %s/%s high %s, north high %s" % [String(sp.get("shape", "")),
			String(sp.get("kind", "")), String(sp.get("high", "")), String(np.get("high", ""))])
	var s_errs: Array[String] = _lean_errors(south, sp, "s")
	TestFixtures.check(res, "roof_lean a south front leaves the north row at one step", s_errs.is_empty(),
		TestFixtures.detail(s_errs, (sp.get("cells", []) as Array).size(), "cell(s)"))
	var n_errs: Array[String] = _lean_errors(north, np, "n")
	TestFixtures.check(res, "roof_lean a north front leaves the south row at one step", n_errs.is_empty(),
		TestFixtures.detail(n_errs, (np.get("cells", []) as Array).size(), "cell(s)"))
	var rugged: Array[String] = _rugged_errors(south, sp)
	rugged.append_array(_rugged_errors(north, np))
	TestFixtures.check(res, "roof_lean every sloping shed cell is rugged", rugged.is_empty(),
		TestFixtures.detail(rugged, south.roof_cells.size() + north.roof_cells.size(), "cell(s)"))


static func _case_awning_stall(res: Dictionary) -> void:
	var f: BattlefieldArea = _field("Market Stall", "S", SEED_BASE + 4)
	var part: Dictionary = _first_part(f)
	var cells: Array = part.get("cells", []) as Array
	var level: int = int(part.get("level", 0))
	var fh: float = float(f.interior_floor_height)
	var want_rise: float = RoofBuilder.AWNING_HI - fh
	var bad: Array[String] = []
	for c: Vector2i in cells:
		var key := Vector3i(c.x, c.y, level)
		if _type_at(f, level, c) != RoofBuilder.SOLID or _d_at(part, c) != 1:
			bad.append("%s type %d d %d" % [str(c), _type_at(f, level, c), _d_at(part, c)])
		elif absf(float(f.roof_rise.get(key, 0.0)) - want_rise) > EPS:
			bad.append("%s rise %.2f" % [str(c), float(f.roof_rise.get(key, 0.0))])
	TestFixtures.check(res, "roof_awning the stall canopy is one solid sheet",
		String(part.get("shape", "")) == "Awning" and String(part.get("kind", "")) == "awning"
		and absf(float(part.get("base", 0.0)) - (RoofBuilder.AWNING_LO - fh)) < EPS and bad.is_empty(),
		"%s/%s base %.2f; %s" % [String(part.get("shape", "")), String(part.get("kind", "")),
			float(part.get("base", 0.0)), TestFixtures.detail(bad, cells.size(), "cell(s)")])
	var bad_span: Array[String] = []
	for c2: Vector2i in cells:
		var ground: float = f.floor_elevation_at(c2, 0)
		var span: Vector2 = f.roof_span.get(c2, Vector2(-9.0, -9.0))
		if not is_equal_approx(span.x, ground + RoofBuilder.AWNING_LO) \
				or not is_equal_approx(span.y, ground + RoofBuilder.AWNING_HI):
			bad_span.append("%s span %s over %.1f" % [str(c2), str(span), ground])
	TestFixtures.check(res, "roof_awning the canopy hangs %.2f to %.2f over floor 0"
		% [RoofBuilder.AWNING_LO, RoofBuilder.AWNING_HI], bad_span.is_empty(),
		TestFixtures.detail(bad_span, cells.size(), "cell(s)"))
	var under := Vector2i.ZERO
	if not cells.is_empty():
		under = cells[0]
	var base: float = f.floor_elevation_at(under, 0)
	var level_ray: String = LineOfSight._floor_block(f, under, base + 1.5, base + 1.5, 0)
	TestFixtures.check(res, "roof_awning a shot under the canopy passes", level_ray == "",
		"got '%s' over %s" % [level_ray, str(under)])
	var down_ray: String = LineOfSight._floor_block(f, under, base + 4.0, base + 1.0, 0)
	TestFixtures.check(res, "roof_awning a shot through the canopy reports it",
		down_ray.begins_with("roof"), "got '%s' over %s" % [down_ray, str(under)])


static func _case_steeple_chapel(res: Dictionary) -> void:
	var f: BattlefieldArea = _field("Chapel", "S", SEED_BASE + 5)
	var part: Dictionary = _first_part(f)
	var rect: Rect2i = part.get("rect", Rect2i()) as Rect2i
	var cells: Array = part.get("cells", []) as Array
	var axis: String = _axis_of(rect, "S")
	TestFixtures.check(res, "roof_steeple the chapel keeps a gable under its steeple",
		String(part.get("shape", "")) == "Steeple" and String(part.get("kind", "")) == "gable"
		and String(part.get("axis", "")) == axis,
		"%s/%s axis %s want %s" % [String(part.get("shape", "")), String(part.get("kind", "")),
			String(part.get("axis", "")), axis])
	var block: Array[String] = _block_errors(f, part, RoofBuilder.STEEPLE_H, "S")
	TestFixtures.check(res, "roof_steeple a %dx%d block stands at the front edge"
		% [RoofBuilder.TOWER_SIDE, RoofBuilder.TOWER_SIDE], block.is_empty(),
		TestFixtures.detail(block, RoofBuilder.TOWER_SIDE * RoofBuilder.TOWER_SIDE, "block cell(s)"))
	var errs: Array[String] = _gable_errors(f, part, axis)
	TestFixtures.check(res, "roof_steeple the rest of the chapel keeps the gable rule", errs.is_empty(),
		TestFixtures.detail(errs, cells.size(), "cell(s)"))


static func _case_clock_town_hall(res: Dictionary) -> void:
	var f: BattlefieldArea = _field("Town Hall", "S", SEED_BASE + 6)
	var part: Dictionary = _main_part(f)
	var cells: Array = part.get("cells", []) as Array
	TestFixtures.check(res, "roof_clock the town hall hips under its clock tower",
		String(part.get("shape", "")) == "Clock Tower" and String(part.get("kind", "")) == "hip",
		"%s/%s" % [String(part.get("shape", "")), String(part.get("kind", ""))])
	var block: Array[String] = _block_errors(f, part, RoofBuilder.CLOCK_H, "S")
	TestFixtures.check(res, "roof_clock a %dx%d block reaches %.1f above the plane"
		% [RoofBuilder.TOWER_SIDE, RoofBuilder.TOWER_SIDE, RoofBuilder.CLOCK_H], block.is_empty(),
		TestFixtures.detail(block, RoofBuilder.TOWER_SIDE * RoofBuilder.TOWER_SIDE, "block cell(s)"))
	var errs: Array[String] = _hip_errors(f, part)
	TestFixtures.check(res, "roof_clock the rest of the town hall keeps the hip rule", errs.is_empty(),
		TestFixtures.detail(errs, cells.size(), "cell(s)"))


static func _case_dome_temple(res: Dictionary) -> void:
	var f: BattlefieldArea = _field("Temple", "S", SEED_BASE + 7)
	var part: Dictionary = _main_part(f)
	var level: int = int(part.get("level", 0))
	var cells: Array = part.get("cells", []) as Array
	var dome: Dictionary = part.get("dome", {}) as Dictionary
	var shapes: Array[String] = []
	for p: Dictionary in f.roof_parts:
		if String(p.get("shape", "")) == "Dome" and String(p.get("kind", "")) == "dome":
			continue
		shapes.append("%s/%s" % [String(p.get("shape", "")), String(p.get("kind", ""))])
	TestFixtures.check(res, "roof_dome every temple part carries the dome shape",
		shapes.is_empty() and not f.roof_parts.is_empty() and not dome.is_empty(),
		"%d part(s), dome %s; %s" % [f.roof_parts.size(), str(not dome.is_empty()),
			TestFixtures.detail(shapes, f.roof_parts.size(), "part(s)")])
	var h: float = float(dome.get("h", 0.0))
	var plateau: float = float(dome.get("plateau", 0.0))
	var crown: float = float(int(dome.get("crown", 0)))
	var cx: float = float(dome.get("cx", 0.0))
	var cy: float = float(dome.get("cy", 0.0))
	var a: float = maxf(float(dome.get("a", 1.0)), 0.001)
	var b: float = maxf(float(dome.get("b", 1.0)), 0.001)
	var r_min: float = minf(a, b)
	var crowns: Array[Vector2i] = []
	var bad_crown: Array[String] = []
	var bad_shell: Array[String] = []
	var shell: Array[Vector2] = []
	for c: Vector2i in cells:
		var ux: float = (float(c.x) + 0.5 - cx) / a
		var uy: float = (float(c.y) + 0.5 - cy) / b
		var u: float = sqrt(ux * ux + uy * uy)
		var t: int = _type_at(f, level, c)
		var rise: float = float(f.roof_rise.get(Vector3i(c.x, c.y, level), 0.0))
		if u * r_min <= crown:
			crowns.append(c)
			if t != RoofBuilder.FLAT or absf(rise - plateau) > EPS:
				bad_crown.append("%s type %d rise %.3f want %.3f" % [str(c), t, rise, plateau])
			continue
		if t != RoofBuilder.SOLID or rise > h + EPS or rise <= 0.0:
			bad_shell.append("%s type %d rise %.3f over %.3f" % [str(c), t, rise, h])
			continue
		shell.append(Vector2(u, rise))
	shell.sort_custom(func(p1: Vector2, p2: Vector2) -> bool: return p1.x < p2.x)
	for i: int in range(1, shell.size()):
		if shell[i].y <= shell[i - 1].y + EPS:
			continue
		bad_shell.append("u %.3f rises %.3f over u %.3f at %.3f" % [shell[i].x, shell[i].y,
			shell[i - 1].x, shell[i - 1].y])
		break
	TestFixtures.check(res, "roof_dome the crown lies flat at the plateau height",
		bad_crown.is_empty() and not crowns.is_empty(),
		"%d crown cell(s); %s" % [crowns.size(), TestFixtures.detail(bad_crown, crowns.size(), "cell(s)")])
	TestFixtures.check(res, "roof_dome every cell outside the crown is solid and falls away",
		bad_shell.is_empty() and not shell.is_empty(),
		TestFixtures.detail(bad_shell, cells.size(), "cell(s)"))
	var marred: Array[String] = []
	for p2: Dictionary in f.roof_parts:
		var lv: int = int(p2.get("level", 0))
		for c2: Vector2i in (p2.get("cells", []) as Array):
			if f.rugged_cells.has(Vector3i(c2.x, c2.y, lv)):
				marred.append("%s stayed rugged" % str(c2))
			elif not f.get_obs(c2, lv).is_empty():
				marred.append("%s carries an object" % str(c2))
	TestFixtures.check(res, "roof_dome no dome cell is rugged or carries a roof object",
		marred.is_empty(), TestFixtures.detail(marred, f.roof_cells.size(), "cell(s)"))
	_dome_climb_check(res, f, part, crowns)


#A dome is climbed as a wall, so a ground cell beside it rises to the nearest crown cell.
static func _dome_climb_check(res: Dictionary, f: BattlefieldArea, part: Dictionary,
		crowns: Array[Vector2i]) -> void:
	f.build_drop_links()
	var level: int = int(part.get("level", 0))
	var rect: Rect2i = part.get("rect", Rect2i()) as Rect2i
	var held: Dictionary = {}
	for c: Vector2i in crowns:
		held[c] = true
	var links: int = 0
	var bad: Array[String] = []
	for gy: int in range(rect.position.y - 1, rect.end.y + 1):
		for gx: int in range(rect.position.x - 1, rect.end.x + 1):
			var g := Vector2i(gx, gy)
			if rect.has_point(g) or gx < 0 or gy < 0 or gx >= f.width or gy >= f.length:
				continue
			for link: Dictionary in f.climb_links_at(Vector3i(gx, gy, 0)):
				var top: Vector3i = link["top"] as Vector3i
				var xy := Vector2i(top.x, top.y)
				if top.z != level or not held.has(xy):
					continue
				links += 1
				var paces: int = int(floor(f.cell_base_elevation(xy, level)
					- f.cell_base_elevation(g, 0)))
				if int(link["paces"]) == paces and String(link["kind"]) == "roof":
					continue
				bad.append("%s to %s %d pace(s) of %d, kind %s" % [str(g), str(top),
					int(link["paces"]), paces, String(link["kind"])])
	for c3: Vector2i in crowns:
		for dl: Dictionary in (f.drop_links.get(Vector3i(c3.x, c3.y, level), []) as Array):
			if String(dl["kind"]) != "roof":
				bad.append("%s drops as %s" % [str(c3), String(dl["kind"])])
	TestFixtures.check(res, "roof_dome a ground cell beside the temple climbs to a crown cell",
		links > 0 and bad.is_empty(), "%d link(s); %s" % [links, TestFixtures.detail(bad, links, "link(s)")])


static func _case_battlement_tower(res: Dictionary) -> void:
	var f: BattlefieldArea = _field("Watchtower", "W", SEED_BASE + 8)
	var part: Dictionary = _first_part(f)
	var cells: Array = part.get("cells", []) as Array
	var errs: Array[String] = _flat_errors(f, part)
	TestFixtures.check(res, "roof_battlement the watchtower top lies flat", errs.is_empty(),
		TestFixtures.detail(errs, cells.size(), "cell(s)"))
	TestFixtures.check(res, "roof_battlement the part keeps the battlement shape",
		f.roof_parts.size() == 1 and String(part.get("shape", "")) == "Battlement"
		and String(part.get("kind", "")) == "flat" and f.rugged_cells.is_empty(),
		"%d part(s), %s/%s, %d rugged" % [f.roof_parts.size(), String(part.get("shape", "")),
			String(part.get("kind", "")), f.rugged_cells.size()])
	var fp: int = int(f.building_plan.get("fp", 0))
	var bad: Array[String] = []
	for c: Vector2i in cells:
		var want: int = roundi(f.floor_elevation_at(c, fp)) + f.interior_floor_height
		if int(part.get("level", 0)) != fp + 1 or int(f.roof_elevations.get(c, -1)) != want:
			bad.append("%s plane %d want %d" % [str(c), int(f.roof_elevations.get(c, -1)), want])
	TestFixtures.check(res, "roof_battlement the roof plane sits one floor over the top floor",
		bad.is_empty() and int(part.get("level", 0)) == fp + 1,
		"level %d for fp %d; %s" % [int(part.get("level", 0)), fp,
			TestFixtures.detail(bad, cells.size(), "cell(s)")])


static func _case_tavern_legacy(res: Dictionary) -> void:
	var f: BattlefieldArea = _field("Tavern", "", SEED_BASE + 9)
	var part: Dictionary = _main_part(f)
	TestFixtures.check(res, "roof_legacy the tavern hips its main part",
		not f.roof_parts.is_empty() and String(part.get("shape", "")) == "Hip"
		and String(part.get("kind", "")) == "hip",
		"%d part(s), %s/%s" % [f.roof_parts.size(), String(part.get("shape", "")),
			String(part.get("kind", ""))])
	var levels: Array[String] = _level_errors(f)
	TestFixtures.check(res, "roof_legacy every tavern cell roofs over its own top floor",
		levels.is_empty(), TestFixtures.detail(levels, f.footprint_union.size(), "cell(s)"))
	var flat: int = 0
	for entry: Dictionary in f.roof_parts:
		flat += int(RoofBuilder.counts(f, entry).get("flat", 0))
	TestFixtures.check(res, "roof_legacy no tavern cell lies flat", flat == 0,
		"%d of %d cell(s)" % [flat, f.roof_cells.size()])


static func _case_every_building(res: Dictionary) -> void:
	var names: Array[String] = _planned_names()
	var bad_level: Array[String] = []
	var bad_shape: Array[String] = []
	var bad_index: Array[String] = []
	var bad_part: Array[String] = []
	for i: int in range(names.size()):
		var f: BattlefieldArea = _field(names[i], "S", SEED_BASE + 20 + i)
		var errs: Array[String] = _level_errors(f)
		if not errs.is_empty():
			bad_level.append("%s %s" % [names[i], errs[0]])
		if f.roof_elevations.size() != f.roof_cells.size() \
				or f.roof_span.size() != f.roof_cells.size():
			bad_index.append("%s %d cell(s), %d plane(s), %d span(s)" % [names[i],
				f.roof_cells.size(), f.roof_elevations.size(), f.roof_span.size()])
		for part: Dictionary in f.roof_parts:
			if not RoofBuilder.SHAPES.has(String(part.get("shape", ""))):
				bad_shape.append("%s %s" % [names[i], String(part.get("shape", ""))])
			var perr: Array[String] = _part_errors(f, part)
			if not perr.is_empty():
				bad_part.append("%s %s" % [names[i], perr[0]])
	TestFixtures.check(res, "roof_all every building roofs each cell once", bad_level.is_empty(),
		TestFixtures.detail(bad_level, names.size(), "building(s)"))
	TestFixtures.check(res, "roof_all every part names a known shape", bad_shape.is_empty(),
		TestFixtures.detail(bad_shape, names.size(), "building(s)"))
	TestFixtures.check(res, "roof_all the plane and span tables match the roof cells",
		bad_index.is_empty(), TestFixtures.detail(bad_index, names.size(), "building(s)"))
	TestFixtures.check(res, "roof_all every part keeps its rect, order and steps", bad_part.is_empty(),
		TestFixtures.detail(bad_part, names.size(), "building(s)"))


static func _case_wing_lean(res: Dictionary) -> void:
	var f: BattlefieldArea = _synth([[Rect2i(2, 2, 10, 8), [0, 1]], [Rect2i(4, 10, 6, 4), [0]]])
	RoofBuilder.build(f, "Hip", "S", "")
	var wing: Dictionary = _part_with_level(f, 1)
	var main: Dictionary = _part_with_level(f, 2)
	TestFixtures.check(res, "roof_wing a lower wing roofs as its own part",
		f.roof_parts.size() == 2 and not wing.is_empty() and not main.is_empty(),
		"%d part(s), wing %s, main %s" % [f.roof_parts.size(), str(wing.get("rect", Rect2i())),
			str(main.get("rect", Rect2i()))])
	TestFixtures.check(res, "roof_wing the wing leans away from the taller wall",
		String(wing.get("shape", "")) == "Lean-to" and String(wing.get("kind", "")) == "lean"
		and String(wing.get("high", "")) == "n",
		"%s/%s high %s" % [String(wing.get("shape", "")), String(wing.get("kind", "")),
			String(wing.get("high", ""))])
	var errs: Array[String] = _lean_errors(f, wing, "n")
	TestFixtures.check(res, "roof_wing the wing peaks against the wall and ends at one step",
		errs.is_empty(), TestFixtures.detail(errs, (wing.get("cells", []) as Array).size(), "cell(s)"))
	var main_errs: Array[String] = _hip_errors(f, main)
	TestFixtures.check(res, "roof_wing the main block keeps the building shape",
		String(main.get("shape", "")) == "Hip" and main_errs.is_empty(),
		"%s; %s" % [String(main.get("shape", "")),
			TestFixtures.detail(main_errs, (main.get("cells", []) as Array).size(), "cell(s)")])


static func _case_l_hip(res: Dictionary) -> void:
	var f: BattlefieldArea = _synth([[Rect2i(2, 2, 10, 6), [0]], [Rect2i(2, 8, 5, 5), [0]]])
	RoofBuilder.build(f, "Hip", "S", "")
	var part: Dictionary = _first_part(f)
	var cells: Array = part.get("cells", []) as Array
	TestFixtures.check(res, "roof_valley an L outline roofs as one hip part",
		f.roof_parts.size() == 1 and cells.size() == 85
		and (part.get("rect", Rect2i()) as Rect2i) == Rect2i(2, 2, 10, 11),
		"%d part(s), %d cell(s), rect %s" % [f.roof_parts.size(), cells.size(),
			str(part.get("rect", Rect2i()))])
	var bad_valley: Array[String] = []
	for c: Vector2i in [Vector2i(6, 8), Vector2i(7, 7)]:
		if _type_at(f, 1, c) != RoofBuilder.SLOPE:
			bad_valley.append("%s type %d" % [str(c), _type_at(f, 1, c)])
	TestFixtures.check(res, "roof_valley the inner corner slopes into the valley",
		bad_valley.is_empty(), TestFixtures.detail(bad_valley, 2, "cell(s)"))
	var outer: Array[Vector2i] = [Vector2i(2, 2), Vector2i(11, 2), Vector2i(11, 7),
		Vector2i(2, 12), Vector2i(6, 12)]
	var bad_outer: Array[String] = []
	for c2: Vector2i in outer:
		if _type_at(f, 1, c2) != RoofBuilder.PEAK:
			bad_outer.append("%s type %d" % [str(c2), _type_at(f, 1, c2)])
	TestFixtures.check(res, "roof_valley every outer corner is a peak", bad_outer.is_empty(),
		TestFixtures.detail(bad_outer, outer.size(), "corner(s)"))
	var errs: Array[String] = _hip_errors(f, part)
	TestFixtures.check(res, "roof_valley every L cell keeps its ring step", errs.is_empty(),
		TestFixtures.detail(errs, cells.size(), "cell(s)"))


static func _case_l_gable(res: Dictionary) -> void:
	var f: BattlefieldArea = _synth([[Rect2i(2, 2, 10, 6), [0]], [Rect2i(2, 8, 5, 5), [0]]])
	RoofBuilder.build(f, "Gable", "S", "")
	var part: Dictionary = _first_part(f)
	var cells: Array = part.get("cells", []) as Array
	TestFixtures.check(res, "roof_fallback a gable on a ragged outline fills as a hip",
		String(part.get("shape", "")) == "Gable" and String(part.get("kind", "")) == "hip"
		and String(part.get("axis", "")) == "",
		"%s/%s axis '%s'" % [String(part.get("shape", "")), String(part.get("kind", "")),
			String(part.get("axis", ""))])
	var errs: Array[String] = _hip_errors(f, part)
	TestFixtures.check(res, "roof_fallback the fallback cells keep the ring step", errs.is_empty(),
		TestFixtures.detail(errs, cells.size(), "cell(s)"))


static func _case_gable_widths(res: Dictionary) -> void:
	var odd: BattlefieldArea = _synth([[Rect2i(2, 2, 9, 12), [0]]])
	RoofBuilder.build(odd, "Gable", "S", "")
	_check_gable(res, odd, "roof_ridge an odd span peaks on one line", "y", 12)
	var even: BattlefieldArea = _synth([[Rect2i(2, 2, 8, 12), [0]]])
	RoofBuilder.build(even, "Gable", "S", "")
	_check_gable(res, even, "roof_ridge an even span peaks on two lines", "y", 24)
	var square: BattlefieldArea = _synth([[Rect2i(2, 2, 8, 8), [0]]])
	RoofBuilder.build(square, "Gable", "W", "")
	_check_gable(res, square, "roof_ridge a square part follows its front", "y", 16)


static func _case_vertex_heights(res: Dictionary) -> void:
	var g: BattlefieldArea = _synth([[Rect2i(2, 2, 8, 12), [0]]])
	RoofBuilder.build(g, "Gable", "S", "")
	var gv: PackedFloat32Array = RoofBuilder.vertex_heights(_first_part(g))
	var bad_g: Array[String] = []
	for vy: int in range(13):
		for vx: int in range(9):
			var want: float = RoofBuilder.PITCH * float(mini(vx, 8 - vx))
			if absf(gv[vy * 9 + vx] - want) > EPS:
				bad_g.append("(%d,%d) %.2f want %.2f" % [vx, vy, gv[vy * 9 + vx], want])
	TestFixtures.check(res, "roof_vertex a gable ridge line stands over its eaves", bad_g.is_empty(),
		TestFixtures.detail(bad_g, 9 * 13, "vertex(es)"))
	var h: BattlefieldArea = _synth([[Rect2i(2, 2, 6, 6), [0]]])
	RoofBuilder.build(h, "Hip", "S", "")
	var hv: PackedFloat32Array = RoofBuilder.vertex_heights(_first_part(h))
	var edge_ok: bool = true
	for i: int in range(7):
		edge_ok = edge_ok and absf(hv[i]) < EPS and absf(hv[6 * 7 + i]) < EPS \
			and absf(hv[i * 7]) < EPS and absf(hv[i * 7 + 6]) < EPS
	TestFixtures.check(res, "roof_vertex a hip stands on its own boundary",
		edge_ok and absf(hv[3 * 7 + 3] - RoofBuilder.PITCH * 3.0) < EPS,
		"boundary %s, centre %.2f want %.2f" % [str(edge_ok), hv[3 * 7 + 3], RoofBuilder.PITCH * 3.0])
	var l: BattlefieldArea = _synth([[Rect2i(2, 2, 6, 9), [0]]])
	RoofBuilder.build(l, "Lean-to", "N", "")
	var lv: PackedFloat32Array = RoofBuilder.vertex_heights(_first_part(l))
	var bad_l: Array[String] = []
	for vx2: int in range(7):
		if absf(lv[vx2] - RoofBuilder.PITCH * 9.0) > EPS or absf(lv[9 * 7 + vx2]) > EPS:
			bad_l.append("%d high %.2f low %.2f" % [vx2, lv[vx2], lv[9 * 7 + vx2]])
	TestFixtures.check(res, "roof_vertex a lean-to falls from its high side", bad_l.is_empty(),
		TestFixtures.detail(bad_l, 7, "column(s)"))
	TestFixtures.check(res, "roof_vertex each part carries one height per rect vertex",
		gv.size() == 9 * 13 and hv.size() == 7 * 7 and lv.size() == 7 * 10,
		"%d, %d, %d" % [gv.size(), hv.size(), lv.size()])


static func _case_readers(res: Dictionary) -> void:
	var f: BattlefieldArea = _field("Small House", "S", SEED_BASE + 10)
	var part: Dictionary = _first_part(f)
	var level: int = int(part.get("level", 0))
	var cell: Vector2i = _slope_cell(f, part)
	var plane: float = float(int(f.roof_elevations.get(cell, 0)))
	var rise: float = float(f.roof_rise.get(Vector3i(cell.x, cell.y, level), 0.0))
	TestFixtures.check(res, "roof_reader a roof cell stands at its plane plus its rise",
		cell.x >= 0 and is_equal_approx(f.cell_base_elevation(cell, level), plane + rise)
		and is_equal_approx(f.floor_elevation_at(cell, level), plane),
		"%s base %.2f want %.2f, plane %.2f want %.2f" % [str(cell),
			f.cell_base_elevation(cell, level), plane + rise, f.floor_elevation_at(cell, level), plane])
	var bad: Array[String] = []
	for fk: Variant in f.interior_floor_elevations.keys():
		var fl: int = fk as int
		var want: float = float(int(f.interior_floor_elevations[fl]))
		if not is_equal_approx(f.floor_elevation_at(cell, fl), want) \
				or not is_equal_approx(f.cell_base_elevation(cell, fl), want):
			bad.append("f%d %.2f/%.2f want %.2f" % [fl, f.floor_elevation_at(cell, fl),
				f.cell_base_elevation(cell, fl), want])
	TestFixtures.check(res, "roof_reader the floors under the roof read the same as before",
		bad.is_empty(), TestFixtures.detail(bad, f.interior_floor_elevations.size(), "floor(s)"))


static func _case_footing(res: Dictionary) -> void:
	var house: BattlefieldArea = _field("Small House", "S", SEED_BASE + 11)
	var store: BattlefieldArea = _field("General Store", "S", SEED_BASE + 18)
	var chapel: BattlefieldArea = _field("Chapel", "S", SEED_BASE + 19)
	var level: int = int(_first_part(house).get("level", 0))
	var planed: Array[String] = []
	for k: Variant in house.roof_cells.keys():
		var c: Vector3i = k as Vector3i
		var xy := Vector2i(c.x, c.y)
		if house.floor_planes_at(xy).has(c.z) or house.has_slab(xy, c.z) or house.is_stair_cell(xy, c.z):
			planed.append(str(c))
	TestFixtures.check(res, "roof_walk the roof level is no floor of the building",
		planed.is_empty() and not house.interior_floor_elevations.has(level),
		TestFixtures.detail(planed, house.roof_cells.size(), "cell(s)"))
	var foot: Array[String] = _footing_errors(house)
	foot.append_array(_footing_errors(store))
	foot.append_array(_footing_errors(chapel))
	var roofed: int = house.roof_cells.size() + store.roof_cells.size() + chapel.roof_cells.size()
	TestFixtures.check(res, "roof_foot flat, slope and peak cells are walkable, solid is not",
		foot.is_empty() and roofed > 0, TestFixtures.detail(foot, roofed, "cell(s)"))
	var other: Array[String] = []
	for x: int in range(house.width):
		for y: int in range(house.length):
			var cell := Vector2i(x, y)
			if house.roof_cells.has(Vector3i(x, y, level)) or house.has_slab(cell, level) \
					or house.is_stair_cell(cell, level) \
					or house.building_interiors.has(Vector3i(x, y, level)):
				continue
			if house.has_walkable_surface(cell, level):
				other.append(str(cell))
	TestFixtures.check(res, "roof_foot no other cell of the roof level is walkable", other.is_empty(),
		TestFixtures.detail(other, house.width * house.length, "cell(s)"))
	var slope: Vector2i = _slope_cell(house, _first_part(house))
	var store_level: int = int(_first_part(store).get("level", 0))
	var chapel_level: int = int(_first_part(chapel).get("level", 0))
	var cost: Array[String] = _entry_errors(house, slope, level, 2, false)
	cost.append_array(_entry_errors(house, _kind_cell(house, _first_part(house), RoofBuilder.PEAK),
		level, 1, false))
	cost.append_array(_entry_errors(store, _kind_cell(store, _first_part(store), RoofBuilder.FLAT),
		store_level, 1, false))
	cost.append_array(_entry_errors(chapel, _kind_cell(chapel, _first_part(chapel), RoofBuilder.SOLID),
		chapel_level, 1, true))
	TestFixtures.check(res, "roof_foot slope costs 2, flat and peak cost 1", cost.is_empty(),
		TestFixtures.detail(cost, 4, "cell(s)"))
	var g: BattlefieldArea = _synth([[Rect2i(2, 2, 9, 12), [0]]])
	RoofBuilder.build(g, "Gable", "S", "")
	var over: Array[Vector3i] = Pathfinder.find_path(Vector3i(2, 6, 1), Vector3i(10, 6, 1), g, {})
	var off: Array[String] = []
	for step: Vector3i in over:
		if not g.roof_cells.has(step):
			off.append(str(step))
	TestFixtures.check(res, "roof_foot a walker crosses the ridge",
		over.size() >= 9 and off.is_empty(),
		"%d cell(s); %s" % [over.size(), TestFixtures.detail(off, over.size(), "cell(s)")])
	var start: Vector2i = _open_floor_cell(house)
	var roof_key := Vector3i(slope.x, slope.y, level)
	var up: Array[Vector3i] = Pathfinder.find_path(Vector3i(start.x, start.y, 0), roof_key, house, {})
	TestFixtures.check(res, "roof_foot no route joins the roof and the floors",
		start.x >= 0 and slope.x >= 0 and up.is_empty(),
		"from %s to %s: %d cell(s)" % [str(start), str(roof_key), up.size()])
	var plane: float = float(int(house.roof_elevations.get(slope, 0)))
	var under: float = PathCost.slab_above(slope, level - 1, house)
	var on_top: float = PathCost.slab_above(slope, level, house)
	TestFixtures.check(res, "roof_foot the roof is a ceiling under it and none on it",
		is_equal_approx(under, plane) and is_equal_approx(on_top, PathCost.NO_CEILING),
		"under %.2f want %.2f, on %.1f" % [under, plane, on_top])
	var down: Dictionary = LineOfSight._compute(g, Vector3i(6, 6, 1), 0, 1, Vector3i(16, 6, 0), 0, 1)
	var eave_up: Dictionary = LineOfSight._compute(g, Vector3i(13, 6, 0), 0, 1, Vector3i(10, 6, 1), 0, 1)
	TestFixtures.check(res, "roof_foot sight from the ridge to the eave side ground",
		bool(down["visible"]) and bool(eave_up["visible"]),
		"ridge '%s', eave '%s'" % [str(down["blocker"]), str(eave_up["blocker"])])
	var across: Dictionary = LineOfSight._compute(g, Vector3i(2, 6, 1), 0, 1, Vector3i(10, 6, 1), 0, 1)
	var along: Dictionary = LineOfSight._compute(g, Vector3i(2, 6, 1), 0, 1, Vector3i(2, 10, 1), 0, 1)
	TestFixtures.check(res, "roof_foot the ridge hides a unit on the far slope",
		not bool(across["visible"]) and bool(along["visible"]),
		"across '%s', along %s" % [str(across["blocker"]), str(along["visible"])])
	var under_roof: Dictionary = LineOfSight._compute(g, Vector3i(9, 6, 0), 0, 1, Vector3i(10, 6, 1), 0, 1)
	TestFixtures.check(res, "roof_foot a unit under the roof never sees a unit on it",
		not bool(under_roof["visible"]), "blocker '%s'" % str(under_roof["blocker"]))
	var had: bool = house.has_roof_level(level)
	var ground: bool = house.has_roof_level(0)
	house.reset_generated_state()
	TestFixtures.check(res, "roof_foot level cache follows the tables",
		had and not ground and not house.has_roof_level(level),
		"level %d before %s, after %s" % [level, str(had), str(house.has_roof_level(level))])


#Synth map with a flat roof and the drop tables rebuilt over it.
static func _edge_map(blocks: Array) -> BattlefieldArea:
	var f: BattlefieldArea = _synth(blocks)
	RoofBuilder.build(f, "Flat", "S", "")
	f.build_drop_links()
	return f


static func _case_edges(res: Dictionary) -> void:
	var house: BattlefieldArea = _edge_map([[Rect2i(4, 4, 8, 8), [0]]])
	var bad: Array[String] = []
	var edges: int = 0
	for k: Variant in house.roof_cells.keys():
		var r: Vector3i = k as Vector3i
		for d: Vector2i in BattlefieldArea.DROP_DIRS:
			var n := Vector2i(r.x + d.x, r.y + d.y)
			if house.in_footprint(n):
				continue
			edges += 1
			var want := Vector3i(n.x, n.y, 0)
			var paces: int = int(floor(house.cell_base_elevation(Vector2i(r.x, r.y), r.z)
				- house.cell_base_elevation(n, 0)))
			var dl: Dictionary = PathCost.drop_link(r, want, house)
			if dl.is_empty() or String(dl["kind"]) != "roof" or int(dl["paces"]) != paces:
				bad.append("%s -> %s" % [str(r), str(want)])
	for fk: Variant in house.drop_links.keys():
		var f3: Vector3i = fk as Vector3i
		for up: Dictionary in (house.drop_links[fk] as Array):
			if (up["to"] as Vector3i).z >= f3.z:
				bad.append("%s rises" % str(f3))
	TestFixtures.check(res, "roof_edge every open roof edge cell drops to the street",
		edges > 0 and bad.is_empty(), TestFixtures.detail(bad, edges, "edge(s)"))

	var step: BattlefieldArea = _edge_map([[Rect2i(4, 4, 6, 8), [0, 1]], [Rect2i(10, 4, 5, 8), [0]]])
	var lower: Array[String] = []
	for y: int in range(4, 12):
		var top3 := Vector3i(9, y, 2)
		var onto: Dictionary = PathCost.drop_link(top3, Vector3i(10, y, 1), step)
		if onto.is_empty() or String(onto["kind"]) != "roof" or int(onto["paces"]) <= 0:
			lower.append("%s has no roof landing" % str(top3))
		elif not PathCost.drop_link(top3, Vector3i(10, y, 0), step).is_empty():
			lower.append("%s falls past the lower roof" % str(top3))
	TestFixtures.check(res, "roof_edge the upper roof drops onto the lower roof",
		step.roof_parts.size() == 2 and lower.is_empty(), TestFixtures.detail(lower, 8, "edge(s)"))

	var solid: BattlefieldArea = _edge_map([[Rect2i(4, 4, 6, 8), [0, 1]], [Rect2i(10, 4, 5, 8), [0]]])
	var blocked := Vector3i(10, 6, 1)
	solid.roof_cells[blocked] = RoofBuilder.SOLID
	solid.build_drop_links()
	var landed: int = 0
	for sk: Variant in solid.drop_links.keys():
		for sl: Dictionary in (solid.drop_links[sk] as Array):
			if (sl["to"] as Vector3i) == blocked:
				landed += 1
	var beside: Dictionary = PathCost.drop_link(Vector3i(9, 7, 2), Vector3i(10, 7, 1), solid)
	TestFixtures.check(res, "roof_edge no drop lands on a solid roof part",
		landed == 0 and not beside.is_empty(),
		"%d link(s) onto %s, beside %s" % [landed, str(blocked), str(not beside.is_empty())])

	var from_roof := Vector3i(4, 6, 1)
	var to_street := Vector3i(3, 6, 0)
	var out_path: Array[Vector3i] = Pathfinder.find_path(from_roof, to_street, house, {}, 2.0)
	var used_drop: bool = false
	for i: int in range(1, out_path.size()):
		if out_path[i - 1].z != out_path[i].z \
				and not PathCost.drop_link(out_path[i - 1], out_path[i], house).is_empty():
			used_drop = true
	var back: Array[Vector3i] = Pathfinder.find_path(to_street, from_roof, house, {}, 2.0)
	TestFixtures.check(res, "roof_edge a walker leaves the roof and never walks back",
		used_drop and back.is_empty(),
		"down %d cell(s) drop %s, up %d cell(s)" % [out_path.size(), str(used_drop), back.size()])

	var harsh: int = PathCost.cell_pace_cost(from_roof, to_street, house, {}, 0.2)
	var soft: int = PathCost.cell_pace_cost(from_roof, to_street, house, {}, 2.0)
	TestFixtures.check(res, "roof_edge a fall too severe for the walker is refused",
		harsh < 0 and soft > 0, "tol 0.2 costs %d, tol 2.0 costs %d" % [harsh, soft])

	var rise: int = PathCost.cell_pace_cost(to_street, from_roof, house, {}, 1.0, true, false, 1, 0)
	var want_rise: int = 1 + int(ceil(house.cell_base_elevation(Vector2i(4, 6), 1)
		- house.cell_base_elevation(Vector2i(3, 6), 0)))
	var glide: int = PathCost.cell_pace_cost(from_roof, to_street, house, {}, 1.0, true, false, 1, 0)
	var walk_up: int = PathCost.cell_pace_cost(to_street, from_roof, house, {}, 1.0, false, false, 1, 0)
	var alt: int = PathCost.fly_arrival_altitude(to_street, from_roof, house, 3, 1)
	var flown: Array[Vector3i] = Pathfinder.find_path(to_street, from_roof, house, {}, 1.0, true)
	TestFixtures.check(res, "roof_edge a flyer rises to the roof and descends free",
		rise == want_rise and glide == 1 and walk_up < 0 and alt == 0 and not flown.is_empty(),
		"up %d want %d, down %d, walk %d, altitude %d, path %d" % [rise, want_rise, glide,
			walk_up, alt, flown.size()])

	var win: BattlefieldArea = _synth([[Rect2i(4, 6, 6, 4), [0, 1, 2]], [Rect2i(10, 6, 5, 4), [0]]])
	RoofBuilder.build(win, "Flat", "S", "")
	win.building_interiors[Vector3i(8, 6, 2)] = true
	win.building_interiors[Vector3i(8, 6, 1)] = true
	TestFixtures.put(win, Vector3i(9, 6, 2), {"cell_type": "window", "broken": true})
	TestFixtures.put(win, Vector3i(9, 6, 1), {"cell_type": "window", "broken": true})
	win.build_drop_links()
	var wlink: Dictionary = PathCost.drop_link(Vector3i(8, 6, 2), Vector3i(10, 6, 1), win)
	var low_links: Array = win.drop_links.get(Vector3i(8, 6, 1), []) as Array
	TestFixtures.check(res, "roof_edge a broken upper window drops onto the lower roof",
		not wlink.is_empty() and String(wlink.get("kind", "")) == "window"
		and (wlink.get("vault", Vector3i()) as Vector3i) == Vector3i(9, 6, 2)
		and low_links.is_empty(),
		"upper %s, lower %d link(s)" % [str(wlink), low_links.size()])

	var st := BattleState.new()
	st.battlefield = house
	var jumper: MercenaryData = TestFixtures.sheet_merc("Roof Leaper")
	TestFixtures.place(st, jumper, Vector2i(3, 6))
	var land: Dictionary = JumpAction._landing_at(from_roof, house, st, jumper, 1, 0)
	var survivable: bool = JumpAction._fall_ok(jumper, 2.0, true)
	var lethal: bool = JumpAction._fall_ok(jumper, 40.0, true)
	var plain: bool = JumpAction._fall_ok(jumper, 1.0, false)
	TestFixtures.check(res, "roof_edge a roof cell is a jump landing that accepts a fall",
		String(land.get("why", "")) == "roof" and survivable and not lethal and not plain,
		"why '%s', 2 paces %s, 40 paces %s, ground %s" % [String(land.get("why", "")),
			str(survivable), str(lethal), str(plain)])

	var over: bool = JumpAction._roof_in_way(step, Vector2i(10, 6), Vector2i(3, 6),
		step.cell_base_elevation(Vector2i(10, 6), 1))
	var open_air: bool = JumpAction._roof_in_way(house, Vector2i(2, 4), Vector2i(2, 10), 0.0)
	TestFixtures.check(res, "roof_edge a higher roof part blocks the leap", over and not open_air,
		"across the upper roof %s, along the street %s" % [str(over), str(open_air)])

	var g: BattlefieldArea = _synth([[Rect2i(2, 2, 9, 12), [0]]])
	RoofBuilder.build(g, "Gable", "S", "")
	var eave := Vector3i(10, 6, 1)
	var sides: Array[String] = []
	for gap: int in [2, 4, 6, 9]:
		var spot := Vector3i(10 + gap, 6, 0)
		var out_view: bool = bool(LineOfSight._compute(g, eave, 0, 1, spot, 0, 1)["visible"])
		var in_view: bool = bool(LineOfSight._compute(g, spot, 0, 1, eave, 0, 1)["visible"])
		if out_view != in_view:
			sides.append("%d cell(s) out %s in %s" % [gap, str(out_view), str(in_view)])
	TestFixtures.check(res, "roof_edge eave sight agrees in both directions", sides.is_empty(),
		TestFixtures.detail(sides, 4, "range(s)"))

	var fly_had: int = house.roof_fly_links.size()
	house.reset_generated_state()
	var fly_left: int = house.roof_fly_links.size()
	TestFixtures.check(res, "roof_edge the fly link table follows the drop table",
		fly_had > 0 and fly_left == 0 and house.drop_links.is_empty(),
		"%d before, %d after" % [fly_had, fly_left])


#Two-team state on this field; the caller places every unit itself.
static func _climb_state(field: BattlefieldArea, a: Array, b: Array) -> BattleState:
	var st := BattleState.new()
	st.battlefield = field
	st.teams = [a, b]
	for ti: int in range(st.teams.size()):
		for m: MercenaryData in (st.teams[ti] as Array):
			st._merc_team_index[m] = ti
	return st


#Melee fixture with the climb skill, so one pace of height costs one pace.
static func _climber(merc_name: String, size: int = 1) -> MercenaryData:
	var m := MercenaryData.new()
	m.merc_name = merc_name
	m.merc_uid = CampaignKnowledge.next_uid()
	m.stats = {"level": 5.0, "luck": 5.0, "size": size, "maximum_hit_points": 20,
		"maximum_endurance_points": 5, "speed": 3.0, "dexterity": 2, "vigor": 3,
		"pain_limit": 0, "pace": 3, "swim": 0.0, "climb": 1,
		"melee_accuracy": 8.0, "ranged_accuracy": 1.0}
	m.current_hp = 20
	return m


#The same fixture with a drawn bow, so CitySpawns calls it ranged focused.
static func _shooter(merc_name: String) -> MercenaryData:
	var m: MercenaryData = _climber(merc_name)
	m.stats["melee_accuracy"] = 1.0
	m.stats["ranged_accuracy"] = 12.0
	var w := WeaponData.new()
	w.item_name = merc_name + " bow (test)"
	w.weapon_type = "Bow"
	w.is_ranged = true
	w.misfire = 0
	w.damage_formula_1 = "1d6"
	w.damage_types_1 = ["Impale"] as Array[String]
	m.equipped_weapon = w
	m.weapon_drawn = true
	m.ammo_loaded = 6
	m.ammo_loaded_type = "Arrow"
	return m


#The two block step of the edge case with the upper window broken or whole.
static func _window_map(broken: bool) -> BattlefieldArea:
	var f: BattlefieldArea = _synth([[Rect2i(4, 6, 6, 4), [0, 1, 2]], [Rect2i(10, 6, 5, 4), [0]]])
	RoofBuilder.build(f, "Flat", "S", "")
	f.building_interiors[Vector3i(8, 6, 2)] = true
	f.building_interiors[Vector3i(8, 6, 1)] = true
	TestFixtures.put(f, Vector3i(9, 6, 2), {"cell_type": "window", "broken": broken})
	TestFixtures.put(f, Vector3i(9, 6, 1), {"cell_type": "window", "broken": broken})
	f.build_drop_links()
	return f


#The movement decision MovementExecutor.execute_climb reads, built from a found climb link.
static func _climb_dec(found: Dictionary, down: bool) -> Dictionary:
	return {"climb_target_pos": found.get("pos", Vector2i(-1, -1)),
		"climb_link": found.get("link", {}) as Dictionary, "climb_down": down}


#Seats a climber and one perched foe on the same house, with an optional roof mate in the party.
static func _climb_setup(field: BattlefieldArea, climber_name: String, foe_name: String,
	base: Vector3i, mate_name: String = "") -> Dictionary:
	var mover: MercenaryData = _climber(climber_name)
	var foe: MercenaryData = _climber(foe_name)
	var party: Array = [mover]
	var mate: MercenaryData = null
	if mate_name != "":
		mate = _climber(mate_name)
		party.append(mate)
	var st: BattleState = _climb_state(field, party, [foe])
	st.set_pos3(mover, base)
	st.set_pos3(foe, Vector3i(6, 6, 1))
	var found: Dictionary = ClimbAction.find_target(mover, st)
	return {"mover": mover, "mate": mate, "state": st, "found": found,
		"link": found.get("link", {}) as Dictionary}


#The drop and climb tables agree, and a street unit only climbs when its enemy is above it.
static func _check_climb_links(res: Dictionary, house: BattlefieldArea, base: Vector3i) -> void:
	var pairs: int = 0
	var ups: int = 0
	var bad: Array[String] = []
	for fk: Variant in house.drop_links.keys():
		var top: Vector3i = fk as Vector3i
		for dl: Dictionary in (house.drop_links[fk] as Array):
			pairs += 1
			var found_up: bool = false
			for up: Dictionary in house.climb_links_at(dl["to"] as Vector3i):
				if (up["top"] as Vector3i) == top and int(up["paces"]) == int(dl["paces"]) \
					and String(up["kind"]) == String(dl["kind"]):
					found_up = true
			if not found_up:
				bad.append("%s -> %s" % [str(top), str(dl["to"])])
	for ck: Variant in house.climb_links.keys():
		ups += (house.climb_links[ck] as Array).size()
	TestFixtures.check(res, "roof_climb the climb table reverses every drop link",
		pairs > 0 and ups == pairs and bad.is_empty(), TestFixtures.detail(bad, pairs, "link(s)"))

	var climber: MercenaryData = _climber("Roof Climber")
	var perch: MercenaryData = _climber("Roof Foe")
	var st: BattleState = _climb_state(house, [climber], [perch])
	st.set_pos3(climber, base)
	st.set_pos3(perch, Vector3i(6, 6, 1))
	var found: Dictionary = ClimbAction.find_target(climber, st)
	var link: Dictionary = found.get("link", {}) as Dictionary
	var facet := CanStartClimbFacet.new()
	var score: float = facet.evaluate(climber, {"state": st})
	var top3: Vector3i = link.get("top", Vector3i(-1, -1, -1)) as Vector3i
	TestFixtures.check(res, "roof_climb a street unit takes the roof link to an enemy above",
		house.climb_links_at(base).size() == 1 and not link.is_empty()
		and String(link["kind"]) == "roof" and not bool(found.get("down", false))
		and house.is_roof_footing(Vector2i(top3.x, top3.y), top3.z) and score == 1.0,
		"top %s, %d pace(s), score %.1f" % [str(top3), int(link.get("paces", 0)), score])

	st.set_pos3(perch, Vector3i(3, 20, 0))
	var ground: Dictionary = ClimbAction.find_target(climber, st)
	var ground_score: float = facet.evaluate(climber, {"state": st})
	TestFixtures.check(res, "roof_climb a melee unit stays down while its enemy is on the street",
		ground.is_empty() and ground_score == 0.0,
		"%d key(s), score %.1f" % [ground.size(), ground_score])


#A blinded shooter takes a roof firing post, and a plain wall is climbed by link and never hopped.
static func _check_climb_target(res: Dictionary, base: Vector3i) -> void:
	#A screen column blinds the street cell and walls the foes off, and the roof over it sees them.
	var post_map: BattlefieldArea = _edge_map([[Rect2i(4, 4, 8, 8), [0]]])
	var screen_x: int = base.x - 1
	for sy: int in range(0, SYNTH_DIM):
		TestFixtures.put(post_map, Vector3i(screen_x, sy, 0), {"cell_type": "wall", "height": 2.0})
	var shooter: MercenaryData = _shooter("Roof Shooter")
	var far_foe: MercenaryData = _climber("Far Foe")
	var far_two: MercenaryData = _climber("Far Foe Two")
	var post_st: BattleState = _climb_state(post_map, [shooter], [far_foe, far_two])
	post_st.set_pos3(shooter, base)
	post_st.set_pos3(far_foe, Vector3i(screen_x - 2, base.y, 0))
	post_st.set_pos3(far_two, Vector3i(screen_x - 2, base.y + 1, 0))
	var blind: bool = not bool(LineOfSight.check(post_st, shooter, far_foe).get("visible", true))
	var post: Dictionary = ClimbAction.find_target(shooter, post_st)
	var post_link: Dictionary = post.get("link", {}) as Dictionary
	var post3: Vector3i = post_link.get("top", Vector3i(-1, -1, -1)) as Vector3i
	var roof_sees: bool = post3.x >= 0 \
		and bool(LineOfSight.check_from(post_st, post3, 0, 1, far_foe).get("visible", true))
	post_st.roof_posts.clear()
	MovementExecutor.clear_caches()
	post_st.set_pos3(far_two, Vector3i(base.x, base.y + 2, 0))
	var close_post: Dictionary = RoofPostScore.best(shooter, post_st)
	var close: Dictionary = ClimbAction.find_target(shooter, post_st)
	TestFixtures.check(res, "roof_climb a shooter takes a firing post only with nothing in sight",
		blind and roof_sees and String(post_link.get("kind", "")) == "roof"
		and post_map.is_roof_footing(Vector2i(post3.x, post3.y), post3.z) and close_post.is_empty()
		and String((close.get("link", {}) as Dictionary).get("kind", "")) != "roof",
		"blind %s, top %s, near %d post key(s)" % [str(blind), str(post3), close_post.size()])
	MovementExecutor.clear_caches()
	PathCost.clear_climb()

	var walls: BattlefieldArea = _edge_map([[Rect2i(4, 4, 8, 8), [0]]])
	TestFixtures.put(walls, Vector3i(4, 6, 0), {"cell_type": "wall"})
	TestFixtures.put(walls, Vector3i(2, 6, 0), {"cell_type": "wall"})
	var hopper: MercenaryData = _climber("Wall Hopper")
	var wall_st: BattleState = _climb_state(walls, [hopper], [])
	wall_st.set_pos3(hopper, base)
	var hop: Vector2i = ClimbAction._find_climb_target(hopper, wall_st)
	TestFixtures.check(res, "roof_climb a building wall is climbed by link and never hopped",
		hop == Vector2i(2, 6) and not ClimbAction.wall_hop(walls, Vector2i(4, 6))
		and ClimbAction.wall_hop(walls, Vector2i(2, 6)), "target (%d,%d)" % [hop.x, hop.y])


#An up link ends on the roof cell it named, and a short pace pool leaves the climber on the wall.
static func _check_climb_up(res: Dictionary, house: BattlefieldArea, base: Vector3i) -> void:
	var up_fx: Dictionary = _climb_setup(house, "Roof Mover", "Perch Foe", base)
	var mover: MercenaryData = up_fx["mover"] as MercenaryData
	var up_st: BattleState = up_fx["state"] as BattleState
	var up: Dictionary = up_fx["found"] as Dictionary
	var up_link: Dictionary = up_fx["link"] as Dictionary
	var up_dec: Dictionary = _climb_dec(up, false)
	up_st.set_pace_pool(mover, 50)
	MovementExecutor.execute_climb(mover, up_dec, "Climb", up_st)
	MovementExecutor.execute_climb(mover, up_dec, "Climb", up_st)
	var up_top: Vector3i = up_link.get("top", Vector3i(-1, -1, -1)) as Vector3i
	TestFixtures.check(res, "roof_climb an up link ends on the roof cell it named",
		up_st.pos3(mover) == up_top and up_st.get_height(mover) == 0
		and not ConstStates.has_state(mover, ConstStates.CLIMBING),
		"at %s want %s h %d" % [str(up_st.pos3(mover)), str(up_top), up_st.get_height(mover)])

	var slow_fx: Dictionary = _climb_setup(house, "Slow Climber", "Slow Foe", base)
	var slow: MercenaryData = slow_fx["mover"] as MercenaryData
	var slow_st: BattleState = slow_fx["state"] as BattleState
	var slow_up: Dictionary = slow_fx["found"] as Dictionary
	var slow_link: Dictionary = slow_fx["link"] as Dictionary
	var slow_dec: Dictionary = _climb_dec(slow_up, false)
	slow_st.set_pace_pool(slow, 1)
	MovementExecutor.execute_climb(slow, slow_dec, "Climb", slow_st)
	var hung: bool = ConstStates.has_state(slow, ConstStates.CLIMBING) \
		and slow_st.get_height(slow) == 1 and slow_st.pos3(slow) == base
	slow_st.set_pace_pool(slow, 50)
	MovementExecutor.execute_climb(slow, slow_dec, "Climb", slow_st)
	var slow_top: Vector3i = slow_link.get("top", Vector3i(-1, -1, -1)) as Vector3i
	TestFixtures.check(res, "roof_climb a short pool holds the climber on the wall",
		hung and slow_st.pos3(slow) == slow_top
		and not ConstStates.has_state(slow, ConstStates.CLIMBING),
		"hung %s, at %s" % [str(hung), str(slow_st.pos3(slow))])


#A taken landing holds the climber at the top of the wall until it clears or the hold runs out.
static func _check_climb_hold(res: Dictionary, house: BattlefieldArea, base: Vector3i) -> void:
	var held_fx: Dictionary = _climb_setup(house, "Held Climber", "Held Foe", base, "Roof Squatter")
	var held: MercenaryData = held_fx["mover"] as MercenaryData
	var squatter: MercenaryData = held_fx["mate"] as MercenaryData
	var held_st: BattleState = held_fx["state"] as BattleState
	var held_up: Dictionary = held_fx["found"] as Dictionary
	var held_link: Dictionary = held_fx["link"] as Dictionary
	var held_top: Vector3i = held_link.get("top", Vector3i(-1, -1, -1)) as Vector3i
	var held_dec: Dictionary = _climb_dec(held_up, false)
	held_st.set_pace_pool(held, 50)
	MovementExecutor.execute_climb(held, held_dec, "Climb", held_st)
	held_st.set_pos3(squatter, held_top)
	MovementExecutor.execute_climb(held, held_dec, "Climb", held_st)
	var held_cd: Dictionary = held_st.get_climbing_data(held)
	var held_paces: int = int(held_link.get("paces", 0))
	TestFixtures.check(res, "roof_climb an occupied top holds the climber at the top of the wall",
		ConstStates.has_state(held, ConstStates.CLIMBING) and held_st.pos3(held) == base
		and int(held_cd.get("current_h", 0)) == held_paces and int(held_cd.get("hold", 0)) == 1
		and held_st.get_height(held) == held_paces,
		"h %d of %d, hold %d, at %s" % [int(held_cd.get("current_h", 0)), held_paces,
			int(held_cd.get("hold", 0)), str(held_st.pos3(held))])
	var held_pool: int = held_st.get_pace_pool(held)
	var hold_lines: Array[String] = MovementExecutor.execute_climb(held, held_dec, "Climb", held_st)
	held_cd = held_st.get_climbing_data(held)
	TestFixtures.check(res, "roof_climb a second held turn costs no pace and keeps the climb",
		hold_lines.is_empty() and held_st.get_pace_pool(held) == held_pool
		and int(held_cd.get("hold", 0)) == 2 and ConstStates.has_state(held, ConstStates.CLIMBING)
		and held_st.pos3(held) == base,
		"%d line(s), pool %d -> %d, hold %d" % [hold_lines.size(), held_pool, held_st.get_pace_pool(held),
			int(held_cd.get("hold", 0))])
	var drop_lines: Array[String] = MovementExecutor.execute_climb(held, held_dec, "Climb", held_st)
	TestFixtures.check(res, "roof_climb a third held turn ends the climb at the base at no cost",
		drop_lines.size() == 1 and drop_lines[0].contains("drops back")
		and not ConstStates.has_state(held, ConstStates.CLIMBING) and held_st.pos3(held) == base
		and held_st.get_height(held) == 0 and held_st.get_climbing_data(held).is_empty()
		and held_st.get_pace_pool(held) == held_pool and not held_st.move_goals.has(held)
		and not held_st.move_targets.has(held) and not held_st.roof_posts.has(held),
		"%d line(s), climbing %s, h %d, at %s, pool %d" % [drop_lines.size(),
			str(ConstStates.has_state(held, ConstStates.CLIMBING)), held_st.get_height(held),
			str(held_st.pos3(held)), held_st.get_pace_pool(held)])


#A landing that clears while the climber waits is taken on the turn after it opens.
static func _check_climb_clear(res: Dictionary, house: BattlefieldArea, base: Vector3i) -> void:
	var pat_fx: Dictionary = _climb_setup(house, "Patient Climber", "Patient Foe", base, "Roof Sitter")
	var patient: MercenaryData = pat_fx["mover"] as MercenaryData
	var sitter: MercenaryData = pat_fx["mate"] as MercenaryData
	var pat_st: BattleState = pat_fx["state"] as BattleState
	var pat_up: Dictionary = pat_fx["found"] as Dictionary
	var pat_link: Dictionary = pat_fx["link"] as Dictionary
	var pat_top: Vector3i = pat_link.get("top", Vector3i(-1, -1, -1)) as Vector3i
	var pat_dec: Dictionary = _climb_dec(pat_up, false)
	pat_st.set_pace_pool(patient, 50)
	MovementExecutor.execute_climb(patient, pat_dec, "Climb", pat_st)
	pat_st.set_pos3(sitter, pat_top)
	MovementExecutor.execute_climb(patient, pat_dec, "Climb", pat_st)
	pat_st.set_pos3(sitter, Vector3i(8, 8, 1))
	MovementExecutor.execute_climb(patient, pat_dec, "Climb", pat_st)
	TestFixtures.check(res, "roof_climb a top that clears during a hold is taken on the next turn",
		pat_st.pos3(patient) == pat_top and pat_st.get_height(patient) == 0
		and not ConstStates.has_state(patient, ConstStates.CLIMBING),
		"at %s want %s, climbing %s" % [str(pat_st.pos3(patient)), str(pat_top),
			str(ConstStates.has_state(patient, ConstStates.CLIMBING))])


#A down link swings the climber to the street, a survivable drop is left to movement, and a fall hurts.
static func _check_climb_down(res: Dictionary, house: BattlefieldArea) -> void:
	var two: BattlefieldArea = _edge_map([[Rect2i(4, 4, 8, 8), [0, 1]]])
	var ledge := Vector3i(4, 6, 2)
	var dropper: MercenaryData = _climber("Roof Dropper")
	var street_foe: MercenaryData = _climber("Street Foe")
	var down_st: BattleState = _climb_state(two, [dropper], [street_foe])
	down_st.set_pos3(dropper, ledge)
	down_st.set_pos3(street_foe, Vector3i(2, 6, 0))
	var down: Dictionary = ClimbAction.find_target(dropper, down_st)
	var down_link: Dictionary = down.get("link", {}) as Dictionary
	var down_to: Vector3i = down_link.get("to", Vector3i(-1, -1, -1)) as Vector3i
	var down_paces: int = int(down_link.get("paces", 0))
	var down_dec: Dictionary = _climb_dec(down, true)
	down_st.set_pace_pool(dropper, 50)
	MovementExecutor.execute_climb(dropper, down_dec, "Climb", down_st)
	var swung: bool = down_st.pos3(dropper) == down_to \
		and down_st.get_height(dropper) == down_paces - 1
	MovementExecutor.execute_climb(dropper, down_dec, "Climb", down_st)
	TestFixtures.check(res, "roof_climb a down link lands the climber and lowers it",
		bool(down.get("down", false)) and down_paces >= 4 and swung
		and down_st.get_height(dropper) == 0
		and not ConstStates.has_state(dropper, ConstStates.CLIMBING),
		"%d pace(s), swung %s, h %d" % [down_paces, str(swung), down_st.get_height(dropper)])

	var shallow: MercenaryData = _climber("Low Dropper")
	var shallow_foe: MercenaryData = _climber("Low Foe")
	var shallow_st: BattleState = _climb_state(house, [shallow], [shallow_foe])
	shallow_st.set_pos3(shallow, Vector3i(4, 6, 1))
	shallow_st.set_pos3(shallow_foe, Vector3i(2, 6, 0))
	var shallow_found: Dictionary = ClimbAction.find_target(shallow, shallow_st)
	TestFixtures.check(res, "roof_climb a drop the walker survives is left to movement",
		shallow_found.is_empty() and house.drop_links.has(Vector3i(4, 6, 1)),
		"%d key(s), table %s" % [shallow_found.size(), str(house.drop_links.has(Vector3i(4, 6, 1)))])

	var faller: MercenaryData = _climber("Wall Faller")
	var fall_foe: MercenaryData = _climber("Fall Foe")
	var fall_st: BattleState = _climb_state(two, [faller], [fall_foe])
	fall_st.set_pos3(faller, ledge)
	fall_st.set_pos3(fall_foe, Vector3i(2, 6, 0))
	var fall_found: Dictionary = ClimbAction.find_target(faller, fall_st)
	var fall_link: Dictionary = fall_found.get("link", {}) as Dictionary
	var fall_dec: Dictionary = _climb_dec(fall_found, true)
	fall_st.set_pace_pool(faller, 50)
	MovementExecutor.execute_climb(faller, fall_dec, "Climb", fall_st)
	var left: int = int(fall_link.get("paces", 0)) - 1
	var fall_lines: Array[String] = CombatApplicator.fall_from_wall(faller, fall_st)
	TestFixtures.check(res, "roof_climb a down climber falls the height still under it",
		left > 0 and not fall_lines.is_empty() and fall_lines[0].contains("falls %d Pace" % left)
		and fall_st.get_height(faller) == 0
		and not ConstStates.has_state(faller, ConstStates.CLIMBING),
		"%d line(s) for %d pace(s)" % [fall_lines.size(), left])


#A broken upper window is a climb link back into the building and a whole one is not.
static func _check_climb_window(res: Dictionary) -> void:
	var open_win: BattlefieldArea = _window_map(true)
	var shut_win: BattlefieldArea = _window_map(false)
	var vault_pos := Vector3i(10, 6, 1)
	var foe_pos := Vector3i(7, 6, 2)
	var vaulter: MercenaryData = _climber("Window Vaulter", 2)
	var win_foe: MercenaryData = _climber("Window Foe")
	var open_st: BattleState = _climb_state(open_win, [vaulter], [win_foe])
	open_st.set_pos3(vaulter, vault_pos)
	open_st.set_pos3(win_foe, foe_pos)
	var through: Dictionary = ClimbAction.find_target(vaulter, open_st)
	var through_link: Dictionary = through.get("link", {}) as Dictionary
	var shut_vaulter: MercenaryData = _climber("Window Squeezer", 2)
	var shut_foe: MercenaryData = _climber("Shut Foe")
	var shut_st: BattleState = _climb_state(shut_win, [shut_vaulter], [shut_foe])
	shut_st.set_pos3(shut_vaulter, vault_pos)
	shut_st.set_pos3(shut_foe, foe_pos)
	var shut: Dictionary = ClimbAction.find_target(shut_vaulter, shut_st)
	TestFixtures.check(res, "roof_climb a broken upper window is climbed back up",
		not through_link.is_empty() and String(through_link.get("kind", "")) == "window"
		and (through_link.get("vault", Vector3i()) as Vector3i) == Vector3i(9, 6, 2)
		and shut.is_empty(),
		"broken %s, whole %d key(s)" % [str(through_link.get("kind", "")), shut.size()])


static func _case_climb(res: Dictionary) -> void:
	var house: BattlefieldArea = _edge_map([[Rect2i(4, 4, 8, 8), [0]]])
	var base := Vector3i(3, 6, 0)
	_check_climb_links(res, house, base)
	_check_climb_target(res, base)
	_check_climb_up(res, house, base)
	_check_climb_hold(res, house, base)
	_check_climb_clear(res, house, base)
	_check_climb_down(res, house)
	_check_climb_window(res)


#The last foot and top a route climbs a link over; both are (-1, -1, -1) when it climbs none.
static func _climb_pair(path: Array[Vector3i], field: BattlefieldArea) -> Array[Vector3i]:
	var pair: Array[Vector3i] = [Vector3i(-1, -1, -1), Vector3i(-1, -1, -1)]
	for i: int in range(1, path.size()):
		if path[i - 1].z == path[i].z:
			continue
		if PathCost.climb_link(path[i - 1], path[i], field).is_empty():
			continue
		pair[0] = path[i - 1]
		pair[1] = path[i]
	return pair


#A climber with climb values plans a route over a wall link; a plain mover and a flyer do not.
static func _check_route_plan(res: Dictionary, house: BattlefieldArea, rect: Rect2i,
	climber: MercenaryData, st: BattleState, start: Vector3i, roof: Vector3i) -> Dictionary:
	PathCost.set_mover_doors(climber, st)
	var up: Array[Vector3i] = Pathfinder.find_path(start, roof, house, {}, 2.0)
	#Every edge cell owns a climb link, so the foot and top come from the route, never from the map.
	var pair: Array[Vector3i] = _climb_pair(up, house)
	var foot: Vector3i = pair[0]
	var ledge_top: Vector3i = pair[1]
	TestFixtures.check(res, "roof_route a climber plans a route up the wall onto the roof",
		not up.is_empty() and up[up.size() - 1] == roof and foot.z == 0
		and not rect.has_point(Vector2i(foot.x, foot.y)) and ledge_top.z == 1
		and house.is_roof_footing(Vector2i(ledge_top.x, ledge_top.y), ledge_top.z),
		"%d cell(s), foot %s, top %s" % [up.size(), str(foot), str(ledge_top)])

	PathCost.clear_climb()
	var flat: Array[Vector3i] = Pathfinder.find_path(start, roof, house, {}, 2.0)
	TestFixtures.check(res, "roof_route a mover that never set its climb values gets no route",
		flat.is_empty(), "%d cell(s)" % flat.size())

	var fly_plain: Array[Vector3i] = Pathfinder.find_path(start, roof, house, {}, 2.0, true)
	PathCost.set_mover_doors(climber, st)
	var fly_climb: Array[Vector3i] = Pathfinder.find_path(start, roof, house, {}, 2.0, true)
	TestFixtures.check(res, "roof_route a flyer takes the same route whatever its climb stat",
		not fly_plain.is_empty() and fly_plain == fly_climb,
		"%d cell(s), %d with climb" % [fly_plain.size(), fly_climb.size()])
	return {"up": up, "foot": foot, "top": ledge_top}


#The walk stops on the foot of the climb it planned and the pending route is what the climb takes.
static func _check_route_walk(res: Dictionary, house: BattlefieldArea, climber: MercenaryData,
	foe: MercenaryData, st: BattleState, start: Vector3i, roof: Vector3i,
	plan: Dictionary) -> Dictionary:
	var up: Array[Vector3i] = plan["up"]
	var foot: Vector3i = plan["foot"] as Vector3i
	var ledge_top: Vector3i = plan["top"] as Vector3i
	var traversed: Array[Vector3i] = [start]
	var cost_at: Array[int] = [0]
	var harm_at: Array[int] = []
	var body_at: Array[int] = []
	var harms: Array[Dictionary] = []
	var lines: Array[String] = []
	var empty: Dictionary = {}
	var buy: Dictionary = {"action_name": "Move Close", "left": 0, "reserve": 0, "bought": 0,
		"pool_start": 40, "why": ""}
	var walk: Dictionary = MovementExecutor._walk_path(climber, st, house, up, 0, 40, start, 0,
		roof, empty, 2.0, false, true, 1, empty, false, traversed, cost_at, harm_at, body_at,
		harms, lines, buy)
	var route: Dictionary = walk["climb_route"] as Dictionary
	var route_link: Dictionary = route.get("link", {}) as Dictionary
	var stopped: Vector3i = walk["last"] as Vector3i
	TestFixtures.check(res, "roof_route the walk ends on the foot of the climb it planned",
		stopped == foot and not route.is_empty() and (route["foot"] as Vector3i) == foot
		and (route_link.get("top", Vector3i(-1, -1, -1)) as Vector3i) == ledge_top
		and not bool(route["down"]),
		"stopped %s, route %d key(s)" % [str(stopped), route.size()])

	st.set_pos3(climber, foot)
	st.set_pos3(foe, Vector3i(0, 20, 0))
	var bare: Dictionary = ClimbAction.find_target(climber, st)
	st.set_climb_route(climber, route_link, false, foot)
	var routed: Dictionary = ClimbAction.find_target(climber, st)
	var routed_link: Dictionary = routed.get("link", {}) as Dictionary
	TestFixtures.check(res, "roof_route the pending route outranks the nearest enemy tests",
		bare.is_empty() and not routed.is_empty() and not bool(routed.get("down", false))
		and (routed_link.get("top", Vector3i(-1, -1, -1)) as Vector3i) == ledge_top,
		"bare %d key(s), routed %s" % [bare.size(), str(routed.get("pos", Vector2i(-1, -1)))])

	var dec: Dictionary = _climb_dec(routed, false)
	st.set_pace_pool(climber, 50)
	MovementExecutor.execute_climb(climber, dec, "Climb", st)
	MovementExecutor.execute_climb(climber, dec, "Climb", st)
	TestFixtures.check(res, "roof_route the recorded climb lands the walker on the link top",
		st.pos3(climber) == ledge_top and st.get_height(climber) == 0
		and not ConstStates.has_state(climber, ConstStates.CLIMBING),
		"at %s want %s" % [str(st.pos3(climber)), str(ledge_top)])
	return route_link


#A drop that would hurt the walker is priced as a down climb, not as a fall.
static func _check_route_drop_cost(res: Dictionary, two: BattlefieldArea,
	ledge: Vector3i) -> Vector3i:
	var drops: Array = two.drop_links.get(ledge, []) as Array
	var land := Vector3i(-1, -1, -1)
	var land_paces: int = 0
	if not drops.is_empty():
		land = (drops[0] as Dictionary)["to"] as Vector3i
		land_paces = int((drops[0] as Dictionary)["paces"])
	var frail: MercenaryData = _climber("Frail Dropper")
	frail.current_hp = 4
	var hale: MercenaryData = _climber("Hale Dropper")
	hale.current_hp = 60
	var down_st: BattleState = _climb_state(two, [frail, hale], [])
	down_st.set_pos3(frail, ledge)
	down_st.set_pos3(hale, Vector3i(6, 6, 2))
	PathCost.set_mover_doors(hale, down_st)
	var fall_cost: int = PathCost.cell_pace_cost(ledge, land, two, {}, 2.0)
	PathCost.set_mover_doors(frail, down_st)
	var climb_cost: int = PathCost.cell_pace_cost(ledge, land, two, {}, 2.0)
	TestFixtures.check(res, "roof_route a drop that would hurt is priced as a down climb",
		land_paces > 0 and climb_cost == 1 + land_paces
		and fall_cost == 1 + PathCost._fall_cost(land_paces, 2.0) and fall_cost > climb_cost,
		"%d pace(s), climb %d, fall %d" % [land_paces, climb_cost, fall_cost])
	return land


#A melee unit on the street approaches an enemy standing on the roof.
static func _check_route_approach(res: Dictionary, house: BattlefieldArea, start: Vector3i,
	roof: Vector3i) -> void:
	var seeker: MercenaryData = _climber("Route Seeker")
	var perch: MercenaryData = _climber("Route Perch")
	var app_st: BattleState = _climb_state(house, [seeker], [perch])
	app_st.set_pos3(seeker, start)
	app_st.set_pos3(perch, roof)
	var approach: Vector3i = PathTargeter.best_approach_cell(seeker, perch, app_st)
	TestFixtures.check(res, "roof_route a melee climber approaches an enemy on the roof",
		approach != PathTargeter.NO_CELL and approach.z == roof.z
		and house.is_roof_footing(Vector2i(approach.x, approach.y), approach.z),
		"approach %s" % str(approach))


#A pending route lives for one turn and is dropped again when the walker moves.
static func _check_route_pending(res: Dictionary, house: BattlefieldArea,
	route_link: Dictionary, start: Vector3i, foot: Vector3i) -> void:
	var kept: MercenaryData = _climber("Route Keeper")
	var keep_st: BattleState = _climb_state(house, [kept], [])
	keep_st.set_pos3(kept, foot)
	keep_st.set_climb_route(kept, route_link, false, foot)
	var held_route: bool = not keep_st.climb_route(kept).is_empty()
	keep_st.start_of_turn(kept)
	var cleared: bool = keep_st.climb_route(kept).is_empty()
	keep_st.set_climb_route(kept, route_link, false, foot)
	keep_st.set_pos3(kept, start)
	TestFixtures.check(res, "roof_route the pending route clears at turn start and on a move",
		held_route and cleared and keep_st.climb_route(kept).is_empty(),
		"held %s, cleared %s" % [str(held_route), str(cleared)])


#A mover with no climb stat still climbs, at one pace of height for every pace of its move.
static func _check_route_no_stat(res: Dictionary, house: BattlefieldArea, start: Vector3i,
	roof: Vector3i) -> void:
	var plain: MercenaryData = _climber("Route Plain")
	plain.stats["climb"] = 0
	var plain_foe: MercenaryData = _climber("Route Plain Foe")
	var plain_st: BattleState = _climb_state(house, [plain], [plain_foe])
	plain_st.set_pos3(plain, start)
	plain_st.set_pos3(plain_foe, roof)
	PathCost.set_mover_doors(plain, plain_st)
	var plain_up: Array[Vector3i] = Pathfinder.find_path(start, roof, house, {}, 2.0)
	var plain_pair: Array[Vector3i] = _climb_pair(plain_up, house)
	var plain_link: Dictionary = PathCost.climb_link(plain_pair[0], plain_pair[1], house)
	var pp: int = MovementExecutor.pace_per_move(plain)
	var plain_cost: int = PathCost.cell_pace_cost(plain_pair[0], plain_pair[1], house, {}, 2.0)
	TestFixtures.check(res, "roof_route a mover with no climb stat climbs at its pace per move",
		not plain_up.is_empty() and plain_up[plain_up.size() - 1] == roof and pp > 1
		and not plain_link.is_empty() and PathCost.climb_pace == pp
		and plain_cost == 1 + int(plain_link["paces"]) * pp,
		"%d cell(s), edge %d, pace %d" % [plain_up.size(), plain_cost, pp])


#A walk whose first step is the climb records the foot, yields one action slot and then blocks.
static func _check_route_arm(res: Dictionary, house: BattlefieldArea, foot: Vector3i,
	ledge_top: Vector3i) -> void:
	var no_mercs: Array[MercenaryData] = []
	MovementExecutor.clear_caches()
	var footer: MercenaryData = _climber("Route Footer")
	footer.current_ap = 12
	var foot_foe: MercenaryData = _climber("Route Foot Foe")
	var foot_st: BattleState = _climb_state(house, [footer], [foot_foe])
	foot_st.set_pos3(footer, foot)
	foot_st.set_pos3(foot_foe, Vector3i(8, 6, 1))
	var foot_lines: Array[String] = MovementExecutor.execute_move(footer, "Move Close", foot_foe,
		foot_st, null, 0, -1, false, no_mercs, no_mercs, ledge_top)
	var foot_row: Dictionary = foot_st.climb_route(footer)
	TestFixtures.check(res, "roof_route a walk whose first step is the climb records the foot and takes none",
		foot_lines.is_empty() and not foot_row.is_empty() and foot_st.pos3(footer) == foot
		and (foot_row["foot"] as Vector3i) == foot and not bool(foot_row["down"]),
		"%d line(s), route %d key(s)" % [foot_lines.size(), foot_row.size()])

	var ready_ap: bool = MovementExecutor.climb_route_ready(footer, foot_st)
	footer.current_ap = 0
	footer.excess_ap = 0
	foot_st.set_pace_pool(footer, 0)
	var ready_dry: bool = MovementExecutor.climb_route_ready(footer, foot_st)
	TestFixtures.check(res, "roof_route the pending route is ready with AP and not without",
		ready_ap and not ready_dry, "ap %s, dry %s" % [str(ready_ap), str(ready_dry)])

	footer.current_ap = 12
	var walk_act := ActionData.new()
	walk_act.action_name = "Move Close"
	walk_act.execution_type = "move"
	walk_act.ap_cost_mode = "move_base"
	var gate_ctx: Dictionary = {"state": foot_st, "move_base_ap": AutoBattle.MOVE_BASE_AP}
	var gate_shut: bool = walk_act.can_execute(footer, gate_ctx)
	foot_st.clear_climb_route(footer)
	var gate_open: bool = walk_act.can_execute(footer, gate_ctx)
	foot_st.set_climb_route(footer, foot_row["link"] as Dictionary, false, foot)
	TestFixtures.check(res, "roof_route a plain move action yields its slot to the pending climb",
		not gate_shut and gate_open,
		"pending %s, cleared %s" % [str(gate_shut), str(gate_open)])

	MovementExecutor.clear_caches()
	var foot_turn: Dictionary = AutoBattle.new_turn(footer, foot_st)
	var foot_dec: Dictionary = {"type": "move", "action_name": "Move Close", "target": foot_foe,
		"goal_cell": ledge_top}
	MovementExecutor.run_move_arm(footer, foot_dec, foot_st, 0, foot_turn)
	var first_seen: bool = bool(foot_turn.get("climb_foot_seen", false))
	var first_block: bool = bool(foot_turn["movement_blocked"])
	MovementExecutor.run_move_arm(footer, foot_dec, foot_st, 0, foot_turn)
	TestFixtures.check(res, "roof_route the move arm yields one slot to the climb and blocks after it",
		first_seen and not first_block and bool(foot_turn["movement_blocked"]),
		"seen %s, blocked %s then %s" % [str(first_seen), str(first_block),
			str(foot_turn["movement_blocked"])])


#A walk off a roof top records the down climb at its foot instead of stepping over the edge.
static func _check_route_walk_off(res: Dictionary, two: BattlefieldArea, ledge: Vector3i,
	land: Vector3i) -> void:
	var no_mercs: Array[MercenaryData] = []
	MovementExecutor.clear_caches()
	var dropper: MercenaryData = _climber("Route Dropper")
	dropper.current_hp = 4
	dropper.current_ap = 12
	var drop_foe: MercenaryData = _climber("Route Drop Foe")
	var drop_st: BattleState = _climb_state(two, [dropper], [drop_foe])
	drop_st.set_pos3(dropper, ledge)
	drop_st.set_pos3(drop_foe, Vector3i(0, 20, 0))
	var drop_walk: Array[String] = MovementExecutor.execute_move(dropper, "Move Close", drop_foe,
		drop_st, null, 0, -1, false, no_mercs, no_mercs, land)
	var drop_row: Dictionary = drop_st.climb_route(dropper)
	TestFixtures.check(res, "roof_route a walk off a roof top records the down climb at its foot",
		drop_walk.is_empty() and not drop_row.is_empty() and drop_st.pos3(dropper) == ledge
		and (drop_row["foot"] as Vector3i) == ledge and bool(drop_row["down"]),
		"%d line(s), route %d key(s)" % [drop_walk.size(), drop_row.size()])
	MovementExecutor.clear_caches()
	PathCost.clear_climb()


static func _case_routes(res: Dictionary) -> void:
	var rect := Rect2i(4, 4, 8, 8)
	var house: BattlefieldArea = _edge_map([[rect, [0]]])
	var start := Vector3i(0, 6, 0)
	var roof := Vector3i(6, 6, 1)
	var climber: MercenaryData = _climber("Route Climber")
	var foe: MercenaryData = _climber("Route Foe")
	var st: BattleState = _climb_state(house, [climber], [foe])
	st.set_pos3(climber, start)
	st.set_pos3(foe, roof)
	var plan: Dictionary = _check_route_plan(res, house, rect, climber, st, start, roof)
	var foot: Vector3i = plan["foot"] as Vector3i
	var route_link: Dictionary = _check_route_walk(res, house, climber, foe, st, start,
		roof, plan)
	var two: BattlefieldArea = _edge_map([[Rect2i(4, 4, 8, 8), [0, 1]]])
	var ledge := Vector3i(4, 6, 2)
	var land: Vector3i = _check_route_drop_cost(res, two, ledge)
	_check_route_approach(res, house, start, roof)
	_check_route_pending(res, house, route_link, start, foot)
	_check_route_no_stat(res, house, start, roof)
	_check_route_arm(res, house, foot, plan["top"] as Vector3i)
	_check_route_walk_off(res, two, ledge, land)


static func _case_roof_jumps(res: Dictionary) -> void:
	var high := Rect2i(4, 4, 5, 5)
	var low := Rect2i(10, 4, 5, 5)
	var map: BattlefieldArea = _edge_map([[high, [0, 1]], [low, [0]]])
	var take := Vector3i(8, 6, 2)
	var land := Vector3i(10, 6, 1)
	var start := Vector3i(6, 6, 2)
	var jumper: MercenaryData = _climber("Roof Jumper")
	jumper.stats["jump"] = 2
	jumper.stats["parkour"] = 100.0
	jumper.current_ap = 12
	var foe: MercenaryData = _climber("Roof Jump Foe")
	var st: BattleState = _climb_state(map, [jumper], [foe])
	st.set_pos3(jumper, start)
	st.set_pos3(foe, Vector3i(0, 20, 0))
	PathCost.set_mover_doors(jumper, st)
	var tol: float = PathTargeter.fall_tolerance(jumper)
	var edge: Dictionary = PathCost.roof_jump_step(take, land, map, false, 1)
	var over: Array[Vector3i] = Pathfinder.find_path(start, land, map, {}, tol, false, true)
	var leapt := Vector3i(-1, -1, -1)
	for i: int in range(over.size() - 1):
		if not PathCost.roof_jump_step(over[i], over[i + 1], map, false, 1).is_empty():
			leapt = over[i]
			break
	TestFixtures.check(res, "roof_xjump a route onto the lower roof crosses the gap on a leap edge",
		map.roof_parts.size() == 2 and not edge.is_empty() and int(edge["paces"]) > 0
		and not over.is_empty() and over[over.size() - 1] == land and leapt.z == take.z,
		"edge %d key(s), %d cell(s), leapt %s" % [edge.size(), over.size(), str(leapt)])

	var no_mercs: Array[MercenaryData] = []
	MovementExecutor.clear_caches()
	var lines: Array[String] = MovementExecutor.execute_move(jumper, "Move Close", foe, st,
		null, 0, -1, false, no_mercs, no_mercs, land)
	var row: Dictionary = st.jump_route(jumper)
	TestFixtures.check(res, "roof_xjump the walk stops on the take-off cell and records the leap",
		not row.is_empty() and st.pos3(jumper) == (row["foot"] as Vector3i)
		and (row["to"] as Vector3i) == land and st.pos3(jumper).z == take.z
		and st.pos3(jumper) != start,
		"%d line(s), at %s" % [lines.size(), str(st.pos3(jumper))])

	var jr_ready: bool = MovementExecutor.jump_route_ready(jumper, st)
	jumper.current_ap = 0
	jumper.excess_ap = 0
	st.set_pace_pool(jumper, 0)
	var jr_dry: bool = MovementExecutor.jump_route_ready(jumper, st)
	jumper.current_ap = 12
	TestFixtures.check(res, "roof_xjump the recorded leap is ready with AP and not without",
		jr_ready and not jr_dry, "ap %s, dry %s" % [str(jr_ready), str(jr_dry)])

	var act := JumpAction.new()
	var ctx: Dictionary = {"state": st, "enemies": [foe] as Array}
	var picked: Vector3i = act._find_best_jump_target(jumper, ctx)
	TestFixtures.check(res, "roof_xjump the jump action takes the recorded landing with no foe on a roof",
		picked == land and act._jump_why == "roof",
		"picked %s, why %s" % [str(picked), act._jump_why])

	PathCost.set_mover_doors(jumper, st)
	var up_rows: Array = PathCost.roof_jumps(land, map, 1)
	TestFixtures.check(res, "roof_xjump a leap onto a roof above the jump stat is refused",
		up_rows.is_empty(), "%d row(s)" % up_rows.size())

	PathCost.set_mover_doors(foe, st)
	var none_rows: Array = PathCost.roof_jumps(take, map, 1)
	var none_step: Dictionary = PathCost.roof_jump_step(take, land, map, false, 1)
	TestFixtures.check(res, "roof_xjump a unit with no jump stat gets no leap edge",
		PathCost.jump_roofs == 0 and none_rows.is_empty() and none_step.is_empty(),
		"%d row(s), step %d key(s)" % [none_rows.size(), none_step.size()])

	var tall: BattlefieldArea = _edge_map([[high, [0, 1]], [low, [0]]])
	tall.roof_span[Vector2i(9, 6)] = Vector2(0.0, 99.0)
	tall.bump_path_version()
	PathCost.set_mover_doors(jumper, st)
	var tall_step: Dictionary = PathCost.roof_jump_step(take, land, tall, false, 1)
	var clear_step: Dictionary = PathCost.roof_jump_step(take, land, map, false, 1)
	TestFixtures.check(res, "roof_xjump a taller roof on the line refuses the leap",
		tall_step.is_empty() and not clear_step.is_empty(),
		"tall %d key(s), clear %d key(s)" % [tall_step.size(), clear_step.size()])

	var held_at: Vector3i = st.pos3(jumper)
	st.set_jump_route(jumper, land, held_at)
	var held: bool = not st.jump_route(jumper).is_empty()
	st.start_of_turn(jumper)
	var cleared: bool = st.jump_route(jumper).is_empty()
	st.set_jump_route(jumper, land, held_at)
	st.set_pos3(jumper, start)
	TestFixtures.check(res, "roof_xjump the pending leap clears at turn start and on a move",
		held and cleared and st.jump_route(jumper).is_empty(),
		"held %s, cleared %s" % [str(held), str(cleared)])
	MovementExecutor.clear_caches()
	PathCost.clear_climb()


#Two flat roofs south of a sealed wall line the street cannot see over and the roofs look past, and
#a screen that leaves the east roof facing a wall while the west one faces the enemies.
static func _post_map() -> BattlefieldArea:
	var f: BattlefieldArea = _synth([[POST_WEST, [0]], [POST_EAST, [0]]])
	for x: int in range(0, SYNTH_DIM):
		TestFixtures.put(f, Vector3i(x, POST_WALL_Y, 0), {"cell_type": "wall", "height": 2.0})
	for y: int in range(0, POST_WALL_Y + 2):
		TestFixtures.put(f, Vector3i(POST_SCREEN_X, y, 0), {"cell_type": "wall", "height": 8.0})
	RoofBuilder.build(f, "Flat", "S", "")
	f.build_drop_links()
	return f


#This unit alone against the three enemies in the open, on the post map.
static func _post_state(map: BattlefieldArea, unit: MercenaryData, foes: Array[MercenaryData],
		at: Vector3i) -> BattleState:
	var st: BattleState = _climb_state(map, [unit], foes)
	st.set_pos3(unit, at)
	for i: int in range(foes.size()):
		st.set_pos3(foes[i], Vector3i(POST_FOE_X + i, 0, 0))
	return st


#A ranged fixture with the pace to cross the street and the AP to buy the Moves.
static func _post_shooter(merc_name: String) -> MercenaryData:
	var m: MercenaryData = _shooter(merc_name)
	m.stats["pace"] = 5
	m.current_ap = 12
	return m


#One roof post score is kept for the whole turn and dropped again when the next turn opens.
static func _check_post_hold(res: Dictionary, st: BattleState, merc: MercenaryData,
	label: String) -> void:
	RoofPostScore.reset_counter()
	var first: Dictionary = RoofPostScore.best(merc, st)
	var once: int = RoofPostScore.origins_scored
	var again: Dictionary = RoofPostScore.best(merc, st)
	var held: int = RoofPostScore.origins_scored
	st.start_of_turn(merc)
	var dropped: bool = not st.roof_posts.has(merc)
	TestFixtures.check(res, label,
		once > 0 and held == once and first == again and dropped,
		"%d origin(s), held %d, dropped %s" % [once, held, str(dropped)])


static func _case_post_score(res: Dictionary) -> void:
	var map: BattlefieldArea = _post_map()
	var foes: Array[MercenaryData] = []
	for i: int in range(3):
		foes.append(_climber("Post Foe %d" % i))
	var shooter: MercenaryData = _post_shooter("Post Shooter")
	var st: BattleState = _post_state(map, shooter, foes, POST_START)
	var west_top := Vector3i(POST_WEST.end.x - 1, POST_WEST.end.y - 1, 1)
	var east_top := Vector3i(POST_EAST.position.x, POST_EAST.end.y - 1, 1)
	RoofPostScore.reset_counter()
	var row: Dictionary = RoofPostScore.best(shooter, st)
	var scored: int = RoofPostScore.origins_scored
	var top: Vector3i = (row["top"] as Vector3i) if not row.is_empty() else Vector3i(-1, -1, -1)
	var west_seen: int = RoofPostScore._seen_from(st, west_top, 1, foes)
	var east_seen: int = RoofPostScore._seen_from(st, east_top, 1, foes)
	TestFixtures.check(res, "roof_post the roof facing the enemies beats the one facing a wall",
		map.roof_parts.size() == 2 and not row.is_empty() and top.z == 1
		and POST_WEST.has_point(Vector2i(top.x, top.y))
		and west_seen == foes.size() and east_seen == 0,
		"%d part(s), top %s, west %d, east %d" % [map.roof_parts.size(), str(top),
			west_seen, east_seen])

	TestFixtures.check(res, "roof_post at most six candidates are scored",
		scored == RoofPostScore.MAX_POSTS, "%d origin(s)" % scored)

	var seer: MercenaryData = _post_shooter("Post Seer")
	var seer_st: BattleState = _post_state(map, seer, foes, Vector3i(13, 8, 0))
	var sees: bool = bool(LineOfSight.check(seer_st, seer, foes[1]).get("visible", false))
	var seer_row: Dictionary = RoofPostScore.best(seer, seer_st)
	TestFixtures.check(res, "roof_post a unit with an enemy in sight scores no post",
		sees and seer_row.is_empty(), "sees %s, row %d key(s)" % [str(sees), seer_row.size()])

	var brute: MercenaryData = _climber("Post Brute")
	var brute_st: BattleState = _post_state(map, brute, foes, POST_START)
	var brute_row: Dictionary = RoofPostScore.best(brute, brute_st)
	TestFixtures.check(res, "roof_post a melee unit scores no post",
		not WeaponEvaluator.is_ranged_focused(brute) and brute_row.is_empty(),
		"row %d key(s)" % brute_row.size())

	var far: MercenaryData = _post_shooter("Post Walker")
	far.stats["pace"] = 1
	var far_st: BattleState = _post_state(map, far, foes, Vector3i(13, 25, 0))
	var far_rows: Array = RoofPostScore._candidates(far, far_st, map, 1,
		MovementExecutor.pace_per_move(far), RoofPostScore.MAX_MOVES)
	var far_row: Dictionary = RoofPostScore.best(far, far_st)
	TestFixtures.check(res, "roof_post a link farther than eight Moves is no candidate",
		far_rows.is_empty() and far_row.is_empty(), "%d row(s)" % far_rows.size())

	var keeper: MercenaryData = _post_shooter("Post Keeper")
	var keep_st: BattleState = _post_state(map, keeper, foes, POST_START)
	_check_post_hold(res, keep_st, keeper,
		"roof_post the score is held for the turn and dropped at turn start")

	var stander: MercenaryData = _post_shooter("Post Stander")
	var stand_foot := Vector3i(POST_EAST.position.x, POST_EAST.end.y, 0)
	var stand_st: BattleState = _post_state(map, stander, foes, stand_foot)
	var roofs: int = 0
	for link: Dictionary in map.climb_links_at(stand_foot):
		if String(link["kind"]) == "roof":
			roofs += 1
	var stand_top: Vector3i = RoofPostScore.post_top(stander, stand_st)
	var taken: Dictionary = ClimbAction._link_up(stander, stand_st, map, stand_foot)
	TestFixtures.check(res, "roof_post a link the score rejects is no longer taken by the climb",
		roofs > 0 and stand_top != east_top and taken.is_empty(),
		"%d roof link(s), top %s, taken %d key(s)" % [roofs, str(stand_top), taken.size()])
	MovementExecutor.clear_caches()
	PathCost.clear_climb()


#A synthetic flat roof carrying the objects named, links rebuilt over the finished roof.
static func _obj_map(blocks: Array, shape: String, objects: Array) -> BattlefieldArea:
	var f: BattlefieldArea = _synth(blocks)
	RoofBuilder.build(f, shape, "S", "")
	RoofBuilder.place_objects(f, shape, objects)
	f.build_drop_links()
	return f


static func _ring_cells(part: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var owned: Dictionary = {}
	for c: Vector2i in (part.get("cells", []) as Array):
		owned[c] = true
	for c2: Vector2i in (part.get("cells", []) as Array):
		for d: Vector2i in RoofBuilder.DIRS4:
			if not owned.has(c2 + d):
				out.append(c2)
				break
	return out


static func _objs_named(area: BattlefieldArea, obj_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for obs: Dictionary in area.obstacles:
		if not bool(obs.get("roof_object", false)):
			continue
		var d: ObstacleData = obs.get("data") as ObstacleData
		if d != null and d.obstacle_name == obj_name:
			out.append(obs)
	return out


#A wide flat roof rails its whole edge in parapets and a narrow one carries none.
static func _check_obj_parapet(res: Dictionary, flat: BattlefieldArea, part: Dictionary,
	level: int, ring: Array[Vector2i]) -> void:
	var missing: Array[String] = []
	for cell: Vector2i in ring:
		var d: ObstacleData = flat.get_obs(cell, level).get("data") as ObstacleData
		if d == null or d.obstacle_name != "Parapet":
			missing.append(str(cell))
	TestFixtures.check(res, "roof_obj a wide flat roof rails its whole edge in parapets",
		not ring.is_empty() and missing.is_empty(), TestFixtures.detail(missing, ring.size(), "cell(s)"))

	var inner: Array[String] = []
	var ring_set: Dictionary = {}
	for rc: Vector2i in ring:
		ring_set[rc] = true
	for cell2: Vector2i in (part.get("cells", []) as Array):
		if ring_set.has(cell2) or flat.get_obs(cell2, level).is_empty():
			continue
		inner.append(str(cell2))
	TestFixtures.check(res, "roof_obj no parapet stands off the edge", inner.is_empty(),
		TestFixtures.detail(inner, (part.get("cells", []) as Array).size(), "cell(s)"))

	var small: BattlefieldArea = _obj_map([[Rect2i(6, 6, 4, 4), [0]]], "Flat", [])
	TestFixtures.check(res, "roof_obj a roof under %d cells wide carries no parapet" % RoofBuilder.PARAPET_MIN,
		_objs_named(small, "Parapet").is_empty() and not small.roof_parts.is_empty(),
		"%d object(s)" % small.obstacles.size())


#A battlement alternates merlons and parapets around its ring, with a merlon on every corner.
static func _check_obj_battlement(res: Dictionary, batt: BattlefieldArea,
	bpart: Dictionary) -> void:
	var blevel: int = int(bpart.get("level", 0))
	var brect: Rect2i = bpart.get("rect", Rect2i()) as Rect2i
	var wrong: Array[String] = []
	for cell3: Vector2i in _ring_cells(bpart):
		var bd: ObstacleData = batt.get_obs(cell3, blevel).get("data") as ObstacleData
		var corner: bool = (cell3.x == brect.position.x or cell3.x == brect.end.x - 1) \
			and (cell3.y == brect.position.y or cell3.y == brect.end.y - 1)
		var want: String = "Merlon" if corner or (cell3.x + cell3.y) % 2 == 0 else "Parapet"
		if bd == null or bd.obstacle_name != want:
			wrong.append(str(cell3))
	TestFixtures.check(res, "roof_obj a battlement alternates merlons and parapets with merlon corners",
		wrong.is_empty() and not _objs_named(batt, "Merlon").is_empty(),
		TestFixtures.detail(wrong, _ring_cells(bpart).size(), "cell(s)"))


#Chimneys stand apart on cells that carry them, and a large one answers on all four of its cells.
static func _check_obj_chimneys(res: Dictionary) -> void:
	var two: BattlefieldArea = _obj_map([[Rect2i(4, 4, 10, 10), [0]]], "Flat",
		[{"name": "Chimney", "count": 2}])
	var stacks: Array[Dictionary] = _objs_named(two, "Chimney")
	var apart: int = 0
	if stacks.size() == 2:
		var a: Vector3i = stacks[0]["pos"] as Vector3i
		var b: Vector3i = stacks[1]["pos"] as Vector3i
		apart = maxi(absi(a.x - b.x), absi(a.y - b.y))
	TestFixtures.check(res, "roof_obj two chimneys stand on the roof and stand apart",
		stacks.size() == 2 and apart >= 2, "%d stack(s), %d cell(s) apart" % [stacks.size(), apart])

	var tpart: Dictionary = _first_part(two)
	var tlevel: int = int(tpart.get("level", 0))
	var off: Array[String] = []
	for stack: Dictionary in stacks:
		var p: Vector3i = stack["pos"] as Vector3i
		var kind: int = int(two.roof_cells.get(Vector3i(p.x, p.y, tlevel), -1))
		if p.z != tlevel or kind == RoofBuilder.SOLID or kind == RoofBuilder.PEAK or kind < 0:
			off.append(str(p))
	TestFixtures.check(res, "roof_obj every chimney sits on a roof cell it may stand on", off.is_empty(),
		TestFixtures.detail(off, stacks.size(), "stack(s)"))

	var big: BattlefieldArea = _obj_map([[Rect2i(4, 4, 10, 10), [0]]], "Flat",
		[{"name": "Large Chimney", "count": 1}])
	var larges: Array[Dictionary] = _objs_named(big, "Large Chimney")
	var same: bool = larges.size() == 1
	if same:
		var lp: Vector3i = larges[0]["pos"] as Vector3i
		for ox: int in range(2):
			for oy: int in range(2):
				if big.get_obs(Vector2i(lp.x + ox, lp.y + oy), lp.z) != larges[0]:
					same = false
	TestFixtures.check(res, "roof_obj a large chimney answers on all four of its cells", same,
		"%d stack(s)" % larges.size())


#Every dormer breaks a sloping cell and the set is split over both long sides of the gable.
static func _check_obj_dormers(res: Dictionary) -> void:
	var gable: BattlefieldArea = _obj_map([[Rect2i(4, 4, 11, 13), [0]]], "Gable",
		[{"name": "Dormer", "count": 4}])
	var dorms: Array[Dictionary] = _objs_named(gable, "Dormer")
	var gpart: Dictionary = _first_part(gable)
	var glevel: int = int(gpart.get("level", 0))
	var bad_slope: Array[String] = []
	for dorm: Dictionary in dorms:
		var dp: Vector3i = dorm["pos"] as Vector3i
		if int(gable.roof_cells.get(Vector3i(dp.x, dp.y, glevel), -1)) != RoofBuilder.SLOPE:
			bad_slope.append(str(dp))
	TestFixtures.check(res, "roof_obj every dormer breaks a sloping cell",
		dorms.size() == 4 and bad_slope.is_empty(),
		"%d dormer(s); %s" % [dorms.size(), TestFixtures.detail(bad_slope, dorms.size(), "cell(s)")])

	var sides: Dictionary = {}
	var grect: Rect2i = gpart.get("rect", Rect2i()) as Rect2i
	var mid: float = float(grect.position.y) + float(grect.size.y) * 0.5
	for dorm2: Dictionary in dorms:
		var dp2: Vector3i = dorm2["pos"] as Vector3i
		sides[1 if float(dp2.y) > mid else 0] = true
	TestFixtures.check(res, "roof_obj the dormers split over both long sides", sides.size() == 2,
		"%d side(s)" % sides.size())


#A parapet is vaulted on the way off the roof; a merlon stands too tall to be vaulted at all.
static func _check_obj_vaults(res: Dictionary, flat: BattlefieldArea,
	batt: BattlefieldArea) -> void:
	var vaults: int = 0
	var from_object: int = 0
	for fk: Variant in flat.drop_links.keys():
		var from: Vector3i = fk as Vector3i
		if not flat.get_obs(Vector2i(from.x, from.y), from.z).is_empty():
			from_object += 1
		for dl: Dictionary in (flat.drop_links[fk] as Array):
			if String(dl["kind"]) != "roof":
				continue
			var vault: Vector3i = dl["vault"] as Vector3i
			if vault.x >= 0 and bool(flat.get_obs(Vector2i(vault.x, vault.y), vault.z).get("roof_object", false)):
				vaults += 1
	TestFixtures.check(res, "roof_obj a parapet is vaulted on the way off the roof and never stood on",
		vaults > 0 and from_object == 0, "%d vault(s), %d link(s) off an object" % [vaults, from_object])

	var merlon_vaults: int = 0
	for bk: Variant in batt.drop_links.keys():
		for dl2: Dictionary in (batt.drop_links[bk] as Array):
			var v2: Vector3i = dl2["vault"] as Vector3i
			if v2.x < 0:
				continue
			var vd: ObstacleData = batt.get_obs(Vector2i(v2.x, v2.y), v2.z).get("data") as ObstacleData
			if vd != null and vd.obstacle_name == "Merlon":
				merlon_vaults += 1
	TestFixtures.check(res, "roof_obj a merlon stands too tall to be vaulted", merlon_vaults == 0,
		"%d merlon vault(s)" % merlon_vaults)


#A parapet that is broken opens its own cell to the drop under it.
static func _check_obj_broken(res: Dictionary, flat: BattlefieldArea, level: int,
	ring: Array[Vector2i]) -> void:
	var gone: Vector2i = ring[0]
	var lost: Dictionary = flat.get_obs(gone, level)
	flat.obstacles.erase(lost)
	flat._obs_map.erase(Vector3i(gone.x, gone.y, level))
	flat.relink_after_obstacle_loss(lost)
	var direct: bool = false
	for dk: Variant in flat.drop_links.keys():
		if (dk as Vector3i) != Vector3i(gone.x, gone.y, level):
			continue
		for dl3: Dictionary in (flat.drop_links[dk] as Array):
			if (dl3["vault"] as Vector3i).x < 0:
				direct = true
	TestFixtures.check(res, "roof_obj a broken parapet opens its own cell to the drop", direct,
		"link from %s: %s" % [str(gone), str(direct)])


#The sheet names the obstacle rows the roof pass places.
static func _check_obj_sheet(res: Dictionary) -> void:
	var chim_rows: int = 0
	for oname: String in RoofBuilder.ROOF_ROWS:
		if DataManager.get_obstacle_by_name(oname) != null:
			chim_rows += 1
	var sheet: Dictionary = DataManager.get_area_by_name("Smithy").get("building", {}) as Dictionary
	var listed: Array = sheet.get("roof_objects", []) as Array
	var first: String = "" if listed.is_empty() else String((listed[0] as Dictionary).get("name", ""))
	TestFixtures.check(res, "roof_obj the sheet names the rows the roof pass places",
		chim_rows == RoofBuilder.ROOF_ROWS.size() and first == "Large Chimney",
		"%d of %d row(s), smithy %s" % [chim_rows, RoofBuilder.ROOF_ROWS.size(), first])


static func _case_objects(res: Dictionary) -> void:
	var flat: BattlefieldArea = _obj_map([[Rect2i(4, 4, 8, 8), [0]]], "Flat", [])
	var part: Dictionary = _first_part(flat)
	var level: int = int(part.get("level", 0))
	var ring: Array[Vector2i] = _ring_cells(part)
	_check_obj_parapet(res, flat, part, level, ring)
	var batt: BattlefieldArea = _obj_map([[Rect2i(4, 4, 8, 8), [0]]], "Battlement", [])
	var bpart: Dictionary = _first_part(batt)
	_check_obj_battlement(res, batt, bpart)
	_check_obj_chimneys(res)
	_check_obj_dormers(res)
	_check_obj_vaults(res, flat, batt)
	_check_obj_broken(res, flat, level, ring)
	_check_obj_sheet(res)


#One hand placed outdoor hut: flat ground, a wall ring, inner cells and the level 1 roof.
static func _hut_field() -> BattlefieldArea:
	var f: BattlefieldArea = TestFixtures.exterior_field()
	f.width = SYNTH_DIM
	f.length = SYNTH_DIM
	var rect: Rect2i = HUT_RECT
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			f.terrain_heights[cell] = 0.0
			if x == rect.position.x or x == rect.end.x - 1 \
					or y == rect.position.y or y == rect.end.y - 1:
				TestFixtures.put(f, Vector3i(x, y, 0),
					{"cell_type": "wall", "height": HUT_WALL, "size": 3})
			else:
				f.building_interiors[cell] = true
	f.building_data.append({"rect": rect})
	RoofBuilder.add_hut_roof(f, rect, HUT_WALL)
	f.build_drop_links()
	return f


#One hut through the real generator on a bare outdoor map, with the roof pass on or off.
static func _gen_hut_field(with_roofs: bool) -> BattlefieldArea:
	var f: BattlefieldArea = TestFixtures.exterior_field()
	f.width = SYNTH_DIM
	f.length = SYNTH_DIM
	for x: int in range(f.width):
		f.spawn_zone_a[Vector2i(x, 0)] = true
		f.spawn_zone_b[Vector2i(x, f.length - 1)] = true
	var template := ObstacleData.new()
	template.obstacle_name = "Test Hut"
	template.size_x = 4.0
	template.size_y = 4.0
	template.size_z = HUT_WALL
	template.is_building = true
	var was: bool = RoofBuilder.enabled
	RoofBuilder.enabled = with_roofs
	seed(HUT_SEED)
	BuildingGenerator.place_building(f, template)
	RoofBuilder.enabled = was
	f.build_drop_links()
	return f


#The hut rect is one flat roof a floor above the ground, with its wall and its heights in place.
static func _check_hut_shape(res: Dictionary, f: BattlefieldArea, bare: BattlefieldArea,
	rect: Rect2i, wall: Vector2i, top: Vector2i, plane: float) -> void:
	var cells: int = rect.size.x * rect.size.y
	var bad: Array[String] = []
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if int(f.roof_cells.get(Vector3i(x, y, 1), -1)) != RoofBuilder.FLAT:
				bad.append("%s type %d" % [str(Vector2i(x, y)), int(f.roof_cells.get(Vector3i(x, y, 1), -1))])
	TestFixtures.check(res, "roof_hut the hut rect is one flat roof at level 1 and nothing else",
		bad.is_empty() and f.roof_cells.size() == cells and f.roof_parts.size() == 1
		and int((f.roof_parts[0] as Dictionary).get("level", 0)) == 1,
		TestFixtures.detail(bad, cells, "cell(s)"))

	TestFixtures.check(res, "roof_hut level 1 exists over a hut and nowhere else outdoors",
		PathCost.floor_exists(f, 1) and PathCost.floor_exists(f, 0)
		and not PathCost.floor_exists(bare, 1) and PathCost.floor_exists(bare, 0),
		"hut %s, bare %s" % [str(PathCost.floor_exists(f, 1)), str(PathCost.floor_exists(bare, 1))])

	TestFixtures.check(res, "roof_hut the hut wall stays on level 0 and is gone at level 1",
		f.get_obs(wall, 1).is_empty()
		and String(f.get_obs(wall, 0).get("cell_type", "")) == "wall"
		and not f.is_obstacle(wall, 1) and f.is_obstacle(wall, 0),
		"level 1 '%s', level 0 '%s'" % [String(f.get_obs(wall, 1).get("cell_type", "")),
			String(f.get_obs(wall, 0).get("cell_type", ""))])

	TestFixtures.check(res, "roof_hut a roof cell stands at the wall height and the ground does not",
		absf(f.cell_base_elevation(top, 1) - plane) < EPS
		and absf(f.cell_base_elevation(top, 0)) < EPS
		and absf(f.walk_elevation(top, 1) - plane) < EPS,
		"roof %.2f, ground %.2f, want %.2f" % [f.cell_base_elevation(top, 1),
			f.cell_base_elevation(top, 0), plane])


#Every roof edge drops the wall height to the ground and the climb table reverses every drop.
static func _check_hut_drops(res: Dictionary, f: BattlefieldArea, rect: Rect2i,
	plane: float) -> void:
	var edges: int = 0
	var drops: Array[String] = []
	var climbs: Array[String] = []
	for y2: int in range(rect.position.y, rect.end.y):
		for x2: int in range(rect.position.x, rect.end.x):
			var on_edge: bool = x2 == rect.position.x or x2 == rect.end.x - 1 \
				or y2 == rect.position.y or y2 == rect.end.y - 1
			if not on_edge:
				continue
			edges += 1
			var from3 := Vector3i(x2, y2, 1)
			var links: Array = f.drop_links.get(from3, []) as Array
			if links.is_empty():
				drops.append("%s has no drop" % str(from3))
				continue
			for dl: Dictionary in links:
				if int(dl["paces"]) != int(plane) or String(dl["kind"]) != "roof":
					drops.append("%s %d pace(s) %s" % [str(from3), int(dl["paces"]), String(dl["kind"])])
				var found_up: bool = false
				for up: Dictionary in f.climb_links_at(dl["to"] as Vector3i):
					if (up["top"] as Vector3i) == from3 and int(up["paces"]) == int(dl["paces"]):
						found_up = true
				if not found_up:
					climbs.append("%s -> %s" % [str(from3), str(dl["to"])])
	TestFixtures.check(res, "roof_hut every roof edge drops the wall height to the ground",
		edges > 0 and drops.is_empty(), TestFixtures.detail(drops, edges, "edge(s)"))
	TestFixtures.check(res, "roof_hut the climb table reverses every hut drop", climbs.is_empty(),
		TestFixtures.detail(climbs, edges, "link(s)"))


#A unit beside the hut climbs the wall onto the roof, and a survivable drop is left to movement.
static func _check_hut_climb(res: Dictionary, f: BattlefieldArea, top: Vector2i,
	base: Vector3i) -> void:
	var climber: MercenaryData = _climber("Hut Climber", 2)
	var perch: MercenaryData = _climber("Hut Foe")
	var st: BattleState = _climb_state(f, [climber], [perch])
	st.set_pos3(climber, base)
	st.set_pos3(perch, Vector3i(top.x, top.y, 1))
	var found: Dictionary = ClimbAction.find_target(climber, st)
	var link: Dictionary = found.get("link", {}) as Dictionary
	var dec: Dictionary = _climb_dec(found, false)
	st.set_pace_pool(climber, 50)
	MovementExecutor.execute_climb(climber, dec, "Climb", st)
	MovementExecutor.execute_climb(climber, dec, "Climb", st)
	var want_top: Vector3i = link.get("top", Vector3i(-1, -1, -1)) as Vector3i
	TestFixtures.check(res, "roof_hut a unit beside the hut climbs the wall onto the roof",
		not link.is_empty() and String(link.get("kind", "")) == "roof"
		and not bool(found.get("down", false)) and st.pos3(climber) == want_top
		and st.get_floor(climber) == 1,
		"link %s, ended %s" % [String(link.get("kind", "")), str(st.pos3(climber))])

	var stander: MercenaryData = _climber("Hut Stander")
	var below: MercenaryData = _climber("Hut Quarry")
	var down_st: BattleState = _climb_state(f, [stander], [below])
	down_st.set_pos3(stander, Vector3i(top.x, top.y, 1))
	down_st.set_pos3(below, Vector3i(base.x - 2, base.y, 0))
	var down: Dictionary = ClimbAction.find_target(stander, down_st)
	TestFixtures.check(res, "roof_hut a drop the mover survives is taken over a down climb",
		not bool(down.get("down", false)),
		"%d key(s), down %s" % [down.size(), str(down.get("down", false))])


#The roof is seen from the street, stops a ray through it, and a route off it runs through a drop.
static func _check_hut_sight(res: Dictionary, f: BattlefieldArea, rect: Rect2i,
	top: Vector2i, plane: float, base: Vector3i) -> void:
	var street := Vector3i(base.x, base.y, 0)
	var roof3 := Vector3i(top.x, top.y, 1)
	#The wall hides the inner roof from a viewer at its foot, so the view is taken from afar onto the edge cell.
	var up_view: bool = bool(LineOfSight._compute(f, Vector3i(1, base.y, 0), 0, 1,
		Vector3i(rect.position.x, base.y, 1), 0, 1)["visible"])
	var through: String = LineOfSight._floor_block(f, top, plane + 1.0, plane - 1.0, 0)
	var across: bool = bool(LineOfSight._compute(f, street, 0, 1,
		Vector3i(rect.end.x, base.y, 0), 0, 1)["visible"])
	TestFixtures.check(res, "roof_hut the roof is seen from the street and stops a ray through it",
		up_view and through.begins_with("roof") and not across,
		"up %s, through '%s', across %s" % [str(up_view), through, str(across)])

	var hidden: bool = bool(LineOfSight._compute(f, Vector3i(rect.position.x + 1, rect.position.y + 1, 1),
		0, 1, Vector3i(rect.end.x - 2, rect.end.y - 2, 0), 0, 1)["visible"])
	TestFixtures.check(res, "roof_hut a unit on the roof cannot see into the hut under it",
		not hidden, "visible %s" % str(hidden))

	var out_path: Array[Vector3i] = Pathfinder.find_path(roof3, Vector3i(2, base.y, 0), f, {}, 2.0)
	var used_drop: bool = false
	for i: int in range(1, out_path.size()):
		if out_path[i - 1].z != out_path[i].z \
				and not PathCost.drop_link(out_path[i - 1], out_path[i], f).is_empty():
			used_drop = true
	TestFixtures.check(res, "roof_hut a route off the hut roof runs through a drop link",
		not out_path.is_empty() and used_drop,
		"%d cell(s), drop %s" % [out_path.size(), str(used_drop)])


#The roof pass moves no obstacle and no hut, and a generated hut stays bare when roofs are off.
static func _check_hut_gen(res: Dictionary) -> void:
	var on: BattlefieldArea = _gen_hut_field(true)
	var off: BattlefieldArea = _gen_hut_field(false)
	var moved: Array[String] = []
	if on.obstacles.size() != off.obstacles.size():
		moved.append("%d of %d obstacle(s)" % [on.obstacles.size(), off.obstacles.size()])
	else:
		for i2: int in range(on.obstacles.size()):
			var a: Vector2i = (on.obstacles[i2] as Dictionary)["pos"] as Vector2i
			var b: Vector2i = (off.obstacles[i2] as Dictionary)["pos"] as Vector2i
			if a != b:
				moved.append("%s vs %s" % [str(a), str(b)])
	if on.building_data.size() != off.building_data.size():
		moved.append("%d of %d hut(s)" % [on.building_data.size(), off.building_data.size()])
	else:
		for i3: int in range(on.building_data.size()):
			var ra: Rect2i = (on.building_data[i3] as Dictionary)["rect"] as Rect2i
			var rb: Rect2i = (off.building_data[i3] as Dictionary)["rect"] as Rect2i
			if ra != rb:
				moved.append("%s vs %s" % [str(ra), str(rb)])
	TestFixtures.check(res, "roof_hut the roof pass moves no obstacle and no hut",
		not on.building_data.is_empty() and moved.is_empty(),
		TestFixtures.detail(moved, on.obstacles.size(), "obstacle(s)"))
	TestFixtures.check(res, "roof_hut the generated hut is roofed and stays bare when roofs are off",
		not on.roof_cells.is_empty() and PathCost.floor_exists(on, 1)
		and off.roof_cells.is_empty() and off.roof_parts.is_empty()
		and not PathCost.floor_exists(off, 1),
		"%d on, %d off" % [on.roof_cells.size(), off.roof_cells.size()])


#The hut footprint covers its roof cells and nothing beside them.
static func _check_hut_footprint(res: Dictionary, f: BattlefieldArea, bare: BattlefieldArea,
	rect: Rect2i, wall: Vector2i, base: Vector3i) -> void:
	var inside := Vector2i(rect.position.x + 1, rect.position.y + 1)
	TestFixtures.check(res, "roof_hut the hut footprint covers its roof cells alone",
		f.in_footprint(inside) and f.in_footprint(wall)
		and not f.in_footprint(Vector2i(base.x, base.y))
		and not bare.in_footprint(inside),
		"inside %s, beside %s" % [str(f.in_footprint(inside)),
			str(f.in_footprint(Vector2i(base.x, base.y)))])


static func _case_huts(res: Dictionary) -> void:
	var f: BattlefieldArea = _hut_field()
	var rect: Rect2i = HUT_RECT
	var bare: BattlefieldArea = TestFixtures.exterior_field()
	var wall := Vector2i(rect.position.x, rect.position.y + 2)
	var top := Vector2i(rect.position.x + 2, rect.position.y + 2)
	var plane: float = float(roundi(HUT_WALL))
	var base := Vector3i(rect.position.x - 1, rect.position.y + 2, 0)
	_check_hut_shape(res, f, bare, rect, wall, top, plane)
	_check_hut_drops(res, f, rect, plane)
	_check_hut_climb(res, f, top, base)
	_check_hut_sight(res, f, rect, top, plane, base)
	_check_hut_gen(res)
	_check_hut_footprint(res, f, bare, rect, wall, base)


static func _case_sight(res: Dictionary) -> void:
	var f: BattlefieldArea = _synth([[Rect2i(2, 2, 9, 12), [0]]])
	RoofBuilder.build(f, "Gable", "S", "")
	var part: Dictionary = _first_part(f)
	var plane: float = float(FH)
	var eave := Vector2i(2, 6)
	var ridge := Vector2i(6, 6)
	var over_eave: String = LineOfSight._floor_block(f, eave, plane + 1.0, plane + 1.0, 0)
	TestFixtures.check(res, "roof_sight a ray over an eave passes",
		over_eave == "" and _d_at(part, eave) == 1,
		"got '%s' over %s at d %d" % [over_eave, str(eave), _d_at(part, eave)])
	var over_ridge: String = LineOfSight._floor_block(f, ridge, plane + 1.0, plane + 1.0, 0)
	var ridge_rise: float = float(f.roof_rise.get(Vector3i(ridge.x, ridge.y, 1), 0.0))
	TestFixtures.check(res, "roof_sight a ray through the ridge reports the roof",
		over_ridge.begins_with("roof") and ridge_rise > 1.0,
		"got '%s' over %s at rise %.2f" % [over_ridge, str(ridge), ridge_rise])
	var crossing: Array[String] = []
	for c: Vector2i in (part.get("cells", []) as Array):
		if not LineOfSight._floor_block(f, c, plane + 2.0, plane - 1.0, 0).begins_with("roof"):
			crossing.append(str(c))
	TestFixtures.check(res, "roof_sight a ray that crosses the plane is stopped everywhere",
		crossing.is_empty(), TestFixtures.detail(crossing, (part.get("cells", []) as Array).size(), "cell(s)"))


static func _case_disabled(res: Dictionary) -> void:
	RoofBuilder.enabled = false
	var off: BattlefieldArea = _field("Small House", "S", SEED_BASE + 12)
	RoofBuilder.enabled = true
	var on: BattlefieldArea = _field("Small House", "S", SEED_BASE + 12)
	TestFixtures.check(res, "roof_switch the roof pass writes nothing when it is off",
		off.roof_cells.is_empty() and off.roof_rise.is_empty() and off.rugged_cells.is_empty()
		and off.roof_parts.is_empty() and off.roof_elevations.is_empty() and off.roof_span.is_empty(),
		"%d/%d/%d/%d/%d/%d left" % [off.roof_cells.size(), off.roof_rise.size(),
			off.rugged_cells.size(), off.roof_parts.size(), off.roof_elevations.size(),
			off.roof_span.size()])
	TestFixtures.check(res, "roof_switch the same seed roofs again once it is on",
		not on.roof_cells.is_empty() and not on.roof_parts.is_empty()
		and on.roof_span.size() == on.roof_cells.size(),
		"%d cell(s), %d part(s), %d span(s)" % [on.roof_cells.size(), on.roof_parts.size(),
			on.roof_span.size()])


static func _case_no_rng(res: Dictionary) -> void:
	var f: BattlefieldArea = _field("Small House", "S", SEED_BASE + 13)
	seed(77)
	var before: int = randi()
	seed(77)
	RoofBuilder.build(f, "Hip", "S", "")
	var after: int = randi()
	TestFixtures.check(res, "roof_rng the roof pass draws no random number", before == after,
		"%d/%d" % [before, after])


static func _case_determinism(res: Dictionary) -> void:
	var a: BattlefieldArea = _field("Medium House", "S", SEED_BASE + 14)
	var b: BattlefieldArea = _field("Medium House", "S", SEED_BASE + 14)
	TestFixtures.check(res, "roof_seed one seed roofs the same cells twice",
		not a.roof_cells.is_empty() and _same_table(a.roof_cells, b.roof_cells),
		"%d/%d cell(s)" % [a.roof_cells.size(), b.roof_cells.size()])
	TestFixtures.check(res, "roof_seed one seed rises the same amount twice",
		_same_table(a.roof_rise, b.roof_rise) and a.roof_parts.size() == b.roof_parts.size(),
		"%d/%d rise(s), %d/%d part(s)" % [a.roof_rise.size(), b.roof_rise.size(),
			a.roof_parts.size(), b.roof_parts.size()])


static func _case_reset(res: Dictionary) -> void:
	var f: BattlefieldArea = _field("Small House", "S", SEED_BASE + 15)
	var had: int = f.roof_cells.size()
	f.reset_generated_state()
	TestFixtures.check(res, "roof_reset reset empties every roof table",
		had > 0 and f.roof_cells.is_empty() and f.roof_rise.is_empty()
		and f.rugged_cells.is_empty() and f.roof_parts.is_empty()
		and f.roof_elevations.is_empty() and f.roof_span.is_empty(),
		"%d cell(s) before, %d/%d/%d/%d/%d/%d after" % [had, f.roof_cells.size(), f.roof_rise.size(),
			f.rugged_cells.size(), f.roof_parts.size(), f.roof_elevations.size(), f.roof_span.size()])


static func _case_data(res: Dictionary) -> void:
	var bad: Array[String] = []
	var rows: int = 0
	for area: Dictionary in DataManager.areas_pool:
		if not area.has("building"):
			continue
		rows += 1
		var roof: String = String((area["building"] as Dictionary).get("roof", ""))
		if not RoofBuilder.SHAPES.has(roof):
			bad.append("%s %s" % [String(area.get("name", "?")), roof])
	TestFixtures.check(res, "roof_data every building row names a known roof", bad.is_empty(),
		TestFixtures.detail(bad, rows, "row(s)"))
	var wanted: Dictionary = {"Market Stall": "Awning", "Temple": "Dome", "Tavern": "Hip",
		"Storage Shed": "Lean-to"}
	var bad_name: Array[String] = []
	for key: Variant in wanted.keys():
		var b: Dictionary = DataManager.get_area_by_name(String(key)).get("building", {})
		if String(b.get("roof", "")) != String(wanted[key]):
			bad_name.append("%s %s" % [String(key), String(b.get("roof", ""))])
	TestFixtures.check(res, "roof_data the sheet keeps the roof of each named row", bad_name.is_empty(),
		TestFixtures.detail(bad_name, wanted.size(), "row(s)"))
	seed(SEED_BASE + 16)
	var data: Dictionary = DataManager.get_area_by_name("Manor")
	var plan: Dictionary = BuildingRules.roll_plan(data, "W", 0)
	var want: String = String((data.get("building", {}) as Dictionary).get("roof", ""))
	TestFixtures.check(res, "roof_data the rolled plan carries the row roof",
		String(plan.get("roof", "")) == want and want != "",
		"plan %s, row %s" % [String(plan.get("roof", "")), want])


static func _case_validator(res: Dictionary) -> void:
	var row: Dictionary = DataManager.get_area_by_name("Small House").duplicate(true)
	var bld: Dictionary = row["building"]
	bld["roof"] = "Thatch"
	var hits: Array[String] = []
	for text: String in BuildingDataValidator._building_row_warnings(row):
		if text.contains("column Roof"):
			hits.append(text)
	TestFixtures.check(res, "roof_validator an unknown roof warns on its own column",
		hits.size() == 1, TestFixtures.detail(hits, 1, "warning(s)"))
	var live: Array[String] = []
	for text2: String in BuildingDataValidator.building_warnings():
		if text2.contains("column Roof"):
			live.append(text2)
	TestFixtures.check(res, "roof_validator the sheet itself raises no roof warning", live.is_empty(),
		TestFixtures.detail(live, DataManager.get_building_names().size(), "row(s)"))


static func _case_city(res: Dictionary) -> void:
	var city: Dictionary = _city(CITY_SEED)
	var map: BattlefieldArea = city["map"]
	var pre: Array[Dictionary] = city["pre"]
	var want_cells: int = 0
	var want_parts: int = 0
	for entry: Dictionary in pre:
		want_cells += int(entry["cells"])
		want_parts += int(entry["parts"])
	TestFixtures.check(res, "roof_city every stamped roof reaches the map",
		want_cells > 0 and map.roof_cells.size() == want_cells
		and map.roof_parts.size() == want_parts,
		"%d of %d cell(s), %d of %d part(s)" % [map.roof_cells.size(), want_cells,
			map.roof_parts.size(), want_parts])
	var bad_owner: Array[String] = []
	for part: Dictionary in map.roof_parts:
		var bid: int = int(part.get("building", -1))
		if bid < 0 or bid >= map.buildings.size():
			bad_owner.append("part %d building %d" % [int(part.get("id", -1)), bid])
			continue
		var owner: Rect2i = (map.buildings[bid] as Dictionary)["rect"]
		if not owner.encloses(part.get("rect", Rect2i()) as Rect2i):
			bad_owner.append("part %d %s outside %s" % [int(part.get("id", -1)),
				str(part.get("rect", Rect2i())), str(owner)])
	TestFixtures.check(res, "roof_city every part names the building it sits on", bad_owner.is_empty(),
		TestFixtures.detail(bad_owner, map.roof_parts.size(), "part(s)"))
	var ground: int = int(map.outdoor_planes.get(0, 0))
	var bad_plane: Array[String] = []
	for part2: Dictionary in map.roof_parts:
		var rec: Dictionary = map.buildings[int(part2["building"])]
		var want: int = ground + int(part2["level"]) * int(rec["fh"])
		for c: Vector2i in (part2.get("cells", []) as Array):
			if int(map.roof_elevations.get(c, -1)) != want:
				bad_plane.append("%s %d want %d" % [str(c), int(map.roof_elevations.get(c, -1)), want])
	TestFixtures.check(res, "roof_city each roof plane counts the floors of its own building",
		bad_plane.is_empty() and _city_levels(map), TestFixtures.detail(bad_plane, map.roof_cells.size(), "cell(s)"))
	var ridge: Vector2i = _highest_cell(map, _main_part_of(map, MANOR))
	var span: Vector2 = map.roof_span.get(ridge, Vector2.ZERO)
	TestFixtures.check(res, "roof_city the manor ridge blocks a whole span, not one plane",
		ridge.x >= 0 and span.y > span.x, "%s span %s" % [str(ridge), str(span)])


static func _case_dump(res: Dictionary) -> void:
	var f: BattlefieldArea = _field("Small House", "S", SEED_BASE + 17)
	LevelDumpWriter.save(f, DUMP_STEM)
	var text: String = FileAccess.get_file_as_string(DUMP_STEM + "_level.txt")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DUMP_STEM + "_level.txt"))
	var part_line: bool = false
	for line: String in text.split("\n"):
		if line.begins_with("ROOF: part=0"):
			part_line = true
	TestFixtures.check(res, "roof_dump the dump names every roof part", part_line,
		"%d line(s)" % text.split("\n").size())
	TestFixtures.check(res, "roof_dump the dump draws the roof maps",
		text.contains("=== Roofs") and text.contains("--- Roof level"),
		"header %s" % str(text.contains("=== Roofs")))
	var data: Dictionary = HtmlWireframeGenerator._extract_data(f)
	var roofs: Array = data.get("roofs", []) as Array
	var entry: Dictionary = {}
	if not roofs.is_empty():
		entry = roofs[0]
	var rect: Array = entry.get("rect", [0, 0, 0, 0]) as Array
	var w: int = int(rect[2])
	var h: int = int(rect[3])
	TestFixtures.check(res, "roof_dump the viewer carries one record per part",
		roofs.size() == f.roof_parts.size() and w > 0
		and String(entry.get("types", "")).length() == w * h
		and (entry.get("vh", []) as Array).size() == (w + 1) * (h + 1),
		"%d record(s), %dx%d, %d glyph(s), %d vertex(es)" % [roofs.size(), w, h,
			String(entry.get("types", "")).length(), (entry.get("vh", []) as Array).size()])


static func _case_wireframe_keys(res: Dictionary) -> void:
	var f := BattlefieldArea.new()
	f.width = 8
	f.length = 8
	f.height = 4
	f.building_interiors[Vector2i(2, 3)] = true
	f.building_interiors[Vector3i(4, 5, 1)] = true
	var data: Dictionary = HtmlWireframeGenerator._extract_data(f)
	var bi: Array = data.get("building_interiors", []) as Array
	TestFixtures.check(res, "wireframe_building_keys", bi.size() == 2 and bi.has([2, 3, 0]) and bi.has([4, 5, 1]), "entries %s" % str(bi))


static func _field(area_name: String, front: String, seed_i: int) -> BattlefieldArea:
	seed(seed_i)
	var ctx := GenerationContext.new()
	ctx.building_front = front
	return BattlefieldArea.generate_random(null, ctx, "Interior", DataManager.get_area_by_name(area_name))


#Every Buildings.tsv row that carries a layout, in sheet order.
static func _planned_names() -> Array[String]:
	var out: Array[String] = []
	for entry: String in DataManager.get_building_names():
		if not BuildingRules.is_legacy(DataManager.get_area_by_name(entry)):
			out.append(entry)
	return out


#Interior map with no generator behind it: each block is [Rect2i, Array of floor numbers].
static func _synth(blocks: Array) -> BattlefieldArea:
	var f := BattlefieldArea.new()
	f.width = SYNTH_DIM
	f.length = SYNTH_DIM
	f.height = 24
	f.unevenness = 6
	f.is_interior_map = true
	f.interior_floor_height = FH
	f.area_name = "Roof Synth"
	var top: int = 0
	for block: Array in blocks:
		var rect: Rect2i = block[0] as Rect2i
		for fv: Variant in (block[1] as Array):
			var fl: int = fv as int
			top = maxi(top, fl)
			for x: int in range(rect.position.x, rect.end.x):
				for y: int in range(rect.position.y, rect.end.y):
					f.footprint_cells[Vector3i(x, y, fl)] = true
	for lv: int in range(0, top + 1):
		f.interior_floor_elevations[lv] = lv * FH
	f.set_footprint_from_cells()
	return f


#Three buildings stamped left to right, with the roof counts each scratch map carried in.
static func _city(seed_i: int) -> Dictionary:
	seed(seed_i)
	var scratches: Array[BattlefieldArea] = []
	var pre: Array[Dictionary] = []
	for spec: Array in CITY_SPECS:
		var scratch: BattlefieldArea = BuildingStamp.build_scratch(
			DataManager.get_area_by_name(String(spec[0])), String(spec[1]), int(spec[2]))
		if scratch == null:
			continue
		scratches.append(scratch)
		pre.append({"cells": scratch.roof_cells.size(), "parts": scratch.roof_parts.size(),
			"rect": BuildingStamp.used_rect(scratch)})
	var width: int = CITY_MARGIN * 2 + CITY_GAP * maxi(0, pre.size() - 1)
	var depth: int = 0
	for entry: Dictionary in pre:
		var r: Rect2i = entry["rect"]
		width += r.size.x
		depth = maxi(depth, r.size.y)
	var map := BattlefieldArea.new()
	map.width = width
	map.length = CITY_MARGIN * 2 + depth
	map.height = 40
	map.unevenness = 6
	map.is_interior_map = true
	map.area_name = "Roof City"
	var cursor_x: int = CITY_MARGIN
	for i: int in range(scratches.size()):
		BuildingStamp.place(map, scratches[i],
			BuildingStamp.offset_for(scratches[i], Vector2i(cursor_x, CITY_MARGIN)))
		cursor_x += (pre[i]["rect"] as Rect2i).size.x + CITY_GAP
	BuildingStamp.finish(map)
	return {"map": map, "pre": pre}


#The cobbler roofs one floor up and the watchtower one floor over its top floor.
static func _city_levels(map: BattlefieldArea) -> bool:
	var cobbler: Dictionary = _main_part_of(map, COBBLER)
	var tower: Dictionary = _main_part_of(map, TOWER)
	if cobbler.is_empty() or tower.is_empty():
		return false
	var fp: int = int((map.buildings[TOWER] as Dictionary)["fp"])
	return int(cobbler["level"]) == 1 and int(tower["level"]) == fp + 1


static func _main_part_of(map: BattlefieldArea, bid: int) -> Dictionary:
	var best: Dictionary = {}
	for part: Dictionary in map.roof_parts:
		if int(part.get("building", -1)) != bid:
			continue
		if best.is_empty() or int(part["level"]) > int(best["level"]):
			best = part
	return best


static func _highest_cell(area: BattlefieldArea, part: Dictionary) -> Vector2i:
	var best := Vector2i(-1, -1)
	var top: float = -1.0
	var level: int = int(part.get("level", 0))
	for c: Vector2i in (part.get("cells", []) as Array):
		var rise: float = float(area.roof_rise.get(Vector3i(c.x, c.y, level), 0.0))
		if best.x < 0 or rise > top:
			best = c
			top = rise
	return best


static func _first_part(area: BattlefieldArea) -> Dictionary:
	if area.roof_parts.is_empty():
		return {}
	return area.roof_parts[0]


#Greatest level, then the most cells, then the lowest id.
static func _main_part(area: BattlefieldArea) -> Dictionary:
	var best: Dictionary = {}
	for part: Dictionary in area.roof_parts:
		if best.is_empty():
			best = part
			continue
		var pl: int = int(part.get("level", 0))
		var bl: int = int(best.get("level", 0))
		var pc: int = (part.get("cells", []) as Array).size()
		var bc: int = (best.get("cells", []) as Array).size()
		if pl > bl or (pl == bl and pc > bc):
			best = part
	return best


static func _part_with_level(area: BattlefieldArea, level: int) -> Dictionary:
	for part: Dictionary in area.roof_parts:
		if int(part.get("level", -1)) == level:
			return part
	return {}


static func _type_at(area: BattlefieldArea, level: int, cell: Vector2i) -> int:
	return int(area.roof_cells.get(Vector3i(cell.x, cell.y, level), -1))


static func _d_at(part: Dictionary, cell: Vector2i) -> int:
	var rect: Rect2i = part.get("rect", Rect2i()) as Rect2i
	if not rect.has_point(cell):
		return -1
	var steps: PackedInt32Array = part.get("d", PackedInt32Array())
	var idx: int = (cell.y - rect.position.y) * rect.size.x + (cell.x - rect.position.x)
	if idx < 0 or idx >= steps.size():
		return -1
	return steps[idx]


#Highest floor per xy over the footprint masks.
static func _tops(area: BattlefieldArea) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in area.footprint_cells.keys():
		var c: Vector3i = k as Vector3i
		var xy := Vector2i(c.x, c.y)
		if not out.has(xy) or c.z > int(out[xy]):
			out[xy] = c.z
	return out


#One roof cell per xy whose top floor is 0 or higher, at that floor plus one, and no other.
static func _level_errors(area: BattlefieldArea) -> Array[String]:
	var bad: Array[String] = []
	var tops: Dictionary = _tops(area)
	var want: int = 0
	for tk: Variant in tops.keys():
		var xy: Vector2i = tk as Vector2i
		var top: int = int(tops[xy])
		if top < 0:
			continue
		want += 1
		if RoofBuilder.level_at(area, xy) != top + 1:
			bad.append("%s roofs at %d over floor %d" % [str(xy), RoofBuilder.level_at(area, xy), top])
	if area.roof_cells.size() != want:
		bad.append("%d roof cell(s) for %d xy" % [area.roof_cells.size(), want])
	return bad


#Invariants every part keeps whatever its shape: sorted cells, the bounding rect, the steps, max_rise.
static func _part_errors(area: BattlefieldArea, part: Dictionary) -> Array[String]:
	var bad: Array[String] = []
	var cells: Array = part.get("cells", []) as Array
	var rect: Rect2i = part.get("rect", Rect2i()) as Rect2i
	var level: int = int(part.get("level", 0))
	var steps: PackedInt32Array = part.get("d", PackedInt32Array())
	if cells.is_empty():
		bad.append("no cell")
		return bad
	if steps.size() != rect.size.x * rect.size.y:
		bad.append("%d step(s) for a %dx%d rect" % [steps.size(), rect.size.x, rect.size.y])
	if not KINDS.has(String(part.get("kind", ""))):
		bad.append("kind %s" % String(part.get("kind", "")))
	var tops: Dictionary = _tops(area)
	var lo: Vector2i = cells[0] as Vector2i
	var hi: Vector2i = lo
	var prev := Vector2i(-1000000, -1000000)
	var best: float = -INF
	for c: Vector2i in cells:
		if c.y < prev.y or (c.y == prev.y and c.x <= prev.x):
			bad.append("%s follows %s" % [str(c), str(prev)])
		prev = c
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		if int(tops.get(c, -99)) + 1 != level:
			bad.append("%s tops at %d for level %d" % [str(c), int(tops.get(c, -99)), level])
		if _d_at(part, c) <= 0:
			bad.append("%s step %d" % [str(c), _d_at(part, c)])
		best = maxf(best, float(area.roof_rise.get(Vector3i(c.x, c.y, level), 0.0)))
	if Rect2i(lo, hi - lo + Vector2i.ONE) != rect:
		bad.append("rect %s for cells %s" % [str(rect), str(Rect2i(lo, hi - lo + Vector2i.ONE))])
	#An awning hangs below its plane, so its greatest rise is negative.
	if absf(best - float(part.get("max_rise", 0.0))) > EPS:
		bad.append("max_rise %.3f for a top rise of %.3f" % [float(part.get("max_rise", 0.0)), best])
	return bad


#Only the sloping cells of the part are rugged.
static func _rugged_errors(area: BattlefieldArea, part: Dictionary) -> Array[String]:
	var bad: Array[String] = []
	var level: int = int(part.get("level", 0))
	var cells: Array = part.get("cells", []) as Array
	if cells.is_empty():
		bad.append("no roof part")
		return bad
	for c: Vector2i in cells:
		var key := Vector3i(c.x, c.y, level)
		if (_type_at(area, level, c) == RoofBuilder.SLOPE) != area.rugged_cells.has(key):
			bad.append("%s type %d rugged %s" % [str(c), _type_at(area, level, c),
				str(area.rugged_cells.has(key))])
	return bad


#Flat fill: every cell flat, one step, no rise and no rugged mark.
static func _flat_errors(area: BattlefieldArea, part: Dictionary) -> Array[String]:
	var bad: Array[String] = []
	var level: int = int(part.get("level", 0))
	var cells: Array = part.get("cells", []) as Array
	if cells.is_empty():
		bad.append("no roof part")
		return bad
	for c: Vector2i in cells:
		var rise: float = float(area.roof_rise.get(Vector3i(c.x, c.y, level), 0.0))
		if _type_at(area, level, c) != RoofBuilder.FLAT or _d_at(part, c) != 1 or absf(rise) > EPS:
			bad.append("%s type %d d %d rise %.2f" % [str(c), _type_at(area, level, c),
				_d_at(part, c), rise])
	return bad


#Hip fill: one step per ring inward over 8 neighbours, a peak where no 4 neighbour climbs higher.
static func _hip_errors(area: BattlefieldArea, part: Dictionary) -> Array[String]:
	var bad: Array[String] = []
	var level: int = int(part.get("level", 0))
	var cells: Array = part.get("cells", []) as Array
	if cells.is_empty():
		bad.append("no roof part")
		return bad
	var owned: Dictionary = {}
	for c: Vector2i in cells:
		owned[c] = true
	var want: Dictionary = _ring_steps(owned)
	for c2: Vector2i in cells:
		var d: int = int(want.get(c2, 0))
		var kind: int = RoofBuilder.PEAK
		for step: Vector2i in InteriorGenerator.DIRS4:
			if int(want.get(c2 + step, 0)) > d:
				kind = RoofBuilder.SLOPE
		bad.append_array(_cell_errors(area, part, c2, level, d, kind))
	return bad


#Gable fill: the step counts in from the two eave lines of the cross axis.
static func _gable_errors(area: BattlefieldArea, part: Dictionary, axis: String) -> Array[String]:
	var bad: Array[String] = []
	var level: int = int(part.get("level", 0))
	var rect: Rect2i = part.get("rect", Rect2i()) as Rect2i
	var cells: Array = part.get("cells", []) as Array
	if cells.is_empty():
		bad.append("no roof part")
		return bad
	var span: int = rect.size.x if axis == "y" else rect.size.y
	var top: int = int((span + 1) / 2.0)
	for c: Vector2i in cells:
		var d: int = mini(c.x - rect.position.x, rect.end.x - 1 - c.x) + 1
		if axis == "x":
			d = mini(c.y - rect.position.y, rect.end.y - 1 - c.y) + 1
		bad.append_array(_cell_errors(area, part, c, level, d,
			RoofBuilder.PEAK if d == top else RoofBuilder.SLOPE))
	return bad


#Lean fill: the step counts from the low edge up to the high side.
static func _lean_errors(area: BattlefieldArea, part: Dictionary, high: String) -> Array[String]:
	var bad: Array[String] = []
	var level: int = int(part.get("level", 0))
	var rect: Rect2i = part.get("rect", Rect2i()) as Rect2i
	var cells: Array = part.get("cells", []) as Array
	if cells.is_empty():
		bad.append("no roof part")
		return bad
	var top: int = rect.size.y if high == "n" or high == "s" else rect.size.x
	for c: Vector2i in cells:
		var d: int = c.x - rect.position.x + 1
		if high == "n":
			d = rect.end.y - c.y
		elif high == "s":
			d = c.y - rect.position.y + 1
		elif high == "w":
			d = rect.end.x - c.x
		bad.append_array(_cell_errors(area, part, c, level, d,
			RoofBuilder.PEAK if d == top else RoofBuilder.SLOPE))
	if absf(float(part.get("max_rise", 0.0)) - RoofBuilder.PITCH * float(top)) > EPS:
		bad.append("max_rise %.3f want %.3f" % [float(part.get("max_rise", 0.0)),
			RoofBuilder.PITCH * float(top)])
	return bad


#One cell against the step, the type and the rise its fill rule asks for; a solid block keeps its step alone.
static func _cell_errors(area: BattlefieldArea, part: Dictionary, cell: Vector2i, level: int,
		want_d: int, want_type: int) -> Array[String]:
	var bad: Array[String] = []
	var got_d: int = _d_at(part, cell)
	if got_d != want_d:
		bad.append("%s step %d want %d" % [str(cell), got_d, want_d])
	var got_type: int = _type_at(area, level, cell)
	if got_type == RoofBuilder.SOLID:
		return bad
	var rise: float = float(area.roof_rise.get(Vector3i(cell.x, cell.y, level), 0.0))
	if got_type != want_type:
		bad.append("%s type %d want %d" % [str(cell), got_type, want_type])
	if absf(rise - RoofBuilder.PITCH * float(want_d)) > EPS:
		bad.append("%s rise %.3f want %.3f" % [str(cell), rise, RoofBuilder.PITCH * float(want_d)])
	return bad


#Square of part cells the tower rule asks for: from the front edge inward, at most four steps; empty when none fits.
static func _block_rect(part: Dictionary, front: String) -> Rect2i:
	var rect: Rect2i = part.get("rect", Rect2i()) as Rect2i
	var side: int = RoofBuilder.TOWER_SIDE
	if rect.size.x < side or rect.size.y < side:
		return Rect2i()
	var owned: Dictionary = {}
	for c: Vector2i in (part.get("cells", []) as Array):
		owned[c] = true
	var half: int = int(side / 2.0)
	var cx: int = rect.position.x + int(rect.size.x / 2.0)
	var cy: int = rect.position.y + int(rect.size.y / 2.0)
	var at := Vector2i(rect.position.x, cy - half)
	var step := Vector2i(1, 0)
	var f: String = front.to_lower()
	if f == "n":
		at = Vector2i(cx - half, rect.position.y)
		step = Vector2i(0, 1)
	elif f == "s":
		at = Vector2i(cx - half, rect.end.y - side)
		step = Vector2i(0, -1)
	elif f == "e":
		at = Vector2i(rect.end.x - side, cy - half)
		step = Vector2i(-1, 0)
	for move: int in range(5):
		var block := Rect2i(at + step * move, Vector2i(side, side))
		var fits: bool = true
		for x: int in range(block.position.x, block.end.x):
			for y: int in range(block.position.y, block.end.y):
				fits = fits and owned.has(Vector2i(x, y))
		if fits:
			return block
	return Rect2i()


#The solid cells of a steeple or a clock tower are that square, each one raised to the block height.
static func _block_errors(area: BattlefieldArea, part: Dictionary, height: float,
		front: String) -> Array[String]:
	var bad: Array[String] = []
	var level: int = int(part.get("level", 0))
	var want: Rect2i = _block_rect(part, front)
	var solids: Array[Vector2i] = []
	for c: Vector2i in (part.get("cells", []) as Array):
		if _type_at(area, level, c) == RoofBuilder.SOLID:
			solids.append(c)
	if solids.size() != want.size.x * want.size.y:
		bad.append("%d solid cell(s) for the %s block" % [solids.size(), str(want)])
		return bad
	for c2: Vector2i in solids:
		if not want.has_point(c2):
			bad.append("%s stands outside %s" % [str(c2), str(want)])
			continue
		var plane: float = float(int(area.roof_elevations.get(c2, 0)))
		var span: Vector2 = area.roof_span.get(c2, Vector2.ZERO)
		var rise: float = float(area.roof_rise.get(Vector3i(c2.x, c2.y, level), 0.0))
		if absf(rise - height) > EPS or absf(span.y - (plane + height)) > EPS:
			bad.append("%s rise %.2f span top %.2f want %.2f" % [str(c2), rise, span.y, plane + height])
		if area.rugged_cells.has(Vector3i(c2.x, c2.y, level)):
			bad.append("%s stayed rugged" % str(c2))
	return bad


#Step per cell by the hip rule: 1 wherever a cell touches the outside, then one more per ring.
static func _ring_steps(owned: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var queue: Array[Vector2i] = []
	for ck: Variant in owned.keys():
		var c: Vector2i = ck as Vector2i
		if _touches_outside(owned, c):
			out[c] = 1
			queue.append(c)
	var head: int = 0
	while head < queue.size():
		var c2: Vector2i = queue[head]
		head += 1
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var n := Vector2i(c2.x + dx, c2.y + dy)
				if not owned.has(n) or out.has(n):
					continue
				out[n] = int(out[c2]) + 1
				queue.append(n)
	return out


static func _touches_outside(owned: Dictionary, cell: Vector2i) -> bool:
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if not owned.has(Vector2i(cell.x + dx, cell.y + dy)):
				return true
	return false


#The ridge runs along the longer rect side; a square part follows its front.
static func _axis_of(rect: Rect2i, front: String) -> String:
	if rect.size.x > rect.size.y:
		return "x"
	if rect.size.y > rect.size.x:
		return "y"
	return "y" if front == "W" or front == "E" else "x"


static func _check_gable(res: Dictionary, area: BattlefieldArea, label: String, axis: String,
		want_peaks: int) -> void:
	var part: Dictionary = _first_part(area)
	var errs: Array[String] = _gable_errors(area, part, axis)
	var peaks: int = int(RoofBuilder.counts(area, part).get("peak", 0))
	TestFixtures.check(res, label,
		String(part.get("axis", "")) == axis and peaks == want_peaks and errs.is_empty(),
		"axis %s want %s, %d of %d peak(s); %s" % [String(part.get("axis", "")), axis, peaks,
			want_peaks, TestFixtures.detail(errs, (part.get("cells", []) as Array).size(), "cell(s)")])


#Every roof cell but a solid block carries footing, and the roof level answers as a floor of the map.
static func _footing_errors(area: BattlefieldArea) -> Array[String]:
	var bad: Array[String] = []
	for k: Variant in area.roof_cells.keys():
		var c: Vector3i = k as Vector3i
		var xy := Vector2i(c.x, c.y)
		var kind: int = int(area.roof_cells[c])
		var walk: bool = area.has_walkable_surface(xy, c.z)
		if walk != (kind != RoofBuilder.SOLID):
			bad.append("%s type %d walkable %s" % [str(c), kind, str(walk)])
		elif not PathCost.floor_exists(area, c.z):
			bad.append("%s level %d is no floor of the map" % [str(c), c.z])
	return bad


#The path entry of one roof cell against the base pace and the blocked flag it should carry.
static func _entry_errors(area: BattlefieldArea, cell: Vector2i, level: int, want_base: int,
		want_blocked: bool) -> Array[String]:
	var bad: Array[String] = []
	if cell.x < 0:
		bad.append("no cell for base %d" % want_base)
		return bad
	var entry: Array = PathCost.static_entry(area, Vector3i(cell.x, cell.y, level), 1)
	var blocked: bool = bool(entry[PathCost.SE_BLOCKED])
	if blocked != want_blocked:
		bad.append("%s blocked %s want %s" % [str(cell), str(blocked), str(want_blocked)])
	elif not want_blocked and int(entry[PathCost.SE_BASE]) != want_base:
		bad.append("%s base %d want %d" % [str(cell), int(entry[PathCost.SE_BASE]), want_base])
	return bad


static func _kind_cell(area: BattlefieldArea, part: Dictionary, kind: int) -> Vector2i:
	var level: int = int(part.get("level", 0))
	for c: Vector2i in (part.get("cells", []) as Array):
		if _type_at(area, level, c) != kind or not area.get_obs(c, level).is_empty():
			continue
		return c
	return Vector2i(-1, -1)


#A clear floor 0 cell of the building a walker could start from.
static func _open_floor_cell(area: BattlefieldArea) -> Vector2i:
	for k: Variant in area.footprint_cells.keys():
		var c: Vector3i = k as Vector3i
		if c.z != 0:
			continue
		var xy := Vector2i(c.x, c.y)
		if area.has_walkable_surface(xy, 0) and area.get_obs(xy, 0).is_empty() \
				and not area.is_stair_cell(xy, 0):
			return xy
	return Vector2i(-1, -1)


#First sloping cell of the part that no stair run shares; (-1, -1) when the part holds none.
static func _slope_cell(area: BattlefieldArea, part: Dictionary) -> Vector2i:
	var level: int = int(part.get("level", 0))
	for c: Vector2i in (part.get("cells", []) as Array):
		if _type_at(area, level, c) != RoofBuilder.SLOPE:
			continue
		var clear: bool = true
		for fk: Variant in area.interior_floor_elevations.keys():
			if area.is_stair_cell(c, fk as int):
				clear = false
		if clear:
			return c
	return Vector2i(-1, -1)


static func _same_table(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k: Variant in a.keys():
		if not b.has(k) or str(b[k]) != str(a[k]):
			return false
	return true


static func _has_line(lines: Array[String], text: String) -> bool:
	for line: String in lines:
		if line.findn(text) >= 0:
			return true
	return false


#A frail climber with one turn of AP that has already broken and is running.
static func _flee_climber(merc_name: String) -> MercenaryData:
	var m: MercenaryData = _climber(merc_name)
	m.current_hp = 4
	m.current_ap = 12
	m.flee_intent = true
	var rm: Array[String] = ["interact"]
	ConstStates.apply_state(m, ConstStates.TERRIFIED, null, "", "engine:flee", rm)
	return m


#A runner the roof edge, the wall or the gap stopped: the climb or leap its blocked walk recorded
#still runs, so a fleeing unit never stands still on a roof.
static func _case_flee_roof(res: Dictionary) -> void:
	var no_mercs: Array[MercenaryData] = []
	MovementExecutor.clear_caches()
	PathCost.clear_climb()
	FleeSystem.reset()
	var two: BattlefieldArea = _edge_map([[Rect2i(4, 4, 8, 8), [0, 1]]])
	var ledge := Vector3i(4, 6, 2)
	var drops: Array = two.drop_links.get(ledge, []) as Array
	var link: Dictionary = (drops[0] as Dictionary) if not drops.is_empty() else {}
	var land: Vector3i = link.get("to", Vector3i(-1, -1, -1)) as Vector3i
	var target_h: int = int(link.get("paces", 0))
	var down_dec: Dictionary = {"climb_target_pos": Vector2i(land.x, land.y), "climb_link": link,
		"climb_down": true}

	var runner: MercenaryData = _flee_climber("Flee Dropper")
	var foe: MercenaryData = _climber("Flee Dropper Foe")
	var st: BattleState = _climb_state(two, [runner], [foe])
	st.set_pos3(runner, ledge)
	st.set_pos3(foe, Vector3i(0, 20, 0))
	FleeSystem.begin_battle(st)
	var pre: Array[String] = MovementExecutor.execute_move(runner, "Move Close", foe, st, null, 0,
		-1, false, no_mercs, no_mercs, land)
	var recorded: bool = not st.climb_route(runner).is_empty()
	var lines: Array[String] = []
	FleeSystem.run_turn(runner, st, lines, 0)
	TestFixtures.check(res, "roof_flee a runner the roof edge stopped takes the climb it recorded",
		target_h > 0 and pre.is_empty() and recorded and st.pos3(runner) != ledge
		and _has_line(lines, "climb"),
		"at %s, %d line(s)" % [str(st.pos3(runner)), lines.size()])

	MovementExecutor.clear_caches()
	var cont: MercenaryData = _flee_climber("Flee Wall")
	var cfoe: MercenaryData = _climber("Flee Wall Foe")
	var cst: BattleState = _climb_state(two, [cont], [cfoe])
	cst.set_pos3(cont, ledge)
	cst.set_pos3(cfoe, Vector3i(0, 20, 0))
	FleeSystem.begin_battle(cst)
	cst.set_pace_pool(cont, 1)
	var init_lines: Array[String] = MovementExecutor.execute_climb(cont, down_dec, "Climb", cst)
	var started: bool = ConstStates.has_state(cont, ConstStates.CLIMBING)
	var mid_h: int = cst.get_height(cont)
	var cont_lines: Array[String] = []
	FleeSystem.run_turn(cont, cst, cont_lines, 0)
	TestFixtures.check(res, "roof_flee a runner that starts its turn on the wall finishes the climb",
		started and not init_lines.is_empty() and mid_h == target_h - 1
		and not ConstStates.has_state(cont, ConstStates.CLIMBING) and cst.get_height(cont) == 0
		and cst.get_climbing_data(cont).is_empty(),
		"mid %d, end %d, %d line(s)" % [mid_h, cst.get_height(cont), cont_lines.size()])

	MovementExecutor.clear_caches()
	var stuck: MercenaryData = _flee_climber("Flee Stuck")
	var sfoe: MercenaryData = _climber("Flee Stuck Foe")
	var sst: BattleState = _climb_state(two, [stuck], [sfoe])
	sst.set_pos3(stuck, ledge)
	sst.set_pos3(sfoe, Vector3i(0, 20, 0))
	FleeSystem.begin_battle(sst)
	sst.set_pace_pool(stuck, 1)
	MovementExecutor.execute_climb(stuck, down_dec, "Climb", sst)
	var hung: Vector3i = sst.pos3(stuck)
	var hung_h: int = sst.get_height(stuck)
	stuck.current_ap = 0
	stuck.excess_ap = 0
	sst.set_pace_pool(stuck, 0)
	var stuck_lines: Array[String] = []
	FleeSystem.run_turn(stuck, sst, stuck_lines, 0)
	TestFixtures.check(res, "roof_flee a runner that cannot fund the next grab hangs on the wall",
		ConstStates.has_state(stuck, ConstStates.CLIMBING) and sst.pos3(stuck) == hung
		and sst.get_height(stuck) == hung_h and stuck_lines.is_empty(),
		"at %s h %d, %d line(s)" % [str(sst.pos3(stuck)), sst.get_height(stuck), stuck_lines.size()])

	MovementExecutor.clear_caches()
	var dry: MercenaryData = _flee_climber("Flee Dry")
	dry.current_ap = 0
	dry.excess_ap = 0
	var dfoe: MercenaryData = _climber("Flee Dry Foe")
	var dst: BattleState = _climb_state(two, [dry], [dfoe])
	dst.set_pos3(dry, ledge)
	dst.set_pos3(dfoe, Vector3i(0, 20, 0))
	dst.set_pace_pool(dry, 0)
	dst.set_climb_route(dry, link, true, ledge)
	FleeSystem.begin_battle(dst)
	var dry_lines: Array[String] = []
	FleeSystem.run_turn(dry, dst, dry_lines, 0)
	TestFixtures.check(res, "roof_flee a runner with no AP starts no climb and stays on the ledge",
		dst.pos3(dry) == ledge and not ConstStates.has_state(dry, ConstStates.CLIMBING)
		and not dst.climb_route(dry).is_empty(),
		"at %s, %d line(s)" % [str(dst.pos3(dry)), dry_lines.size()])

	MovementExecutor.clear_caches()
	var walker: MercenaryData = _flee_climber("Flee Walker")
	walker.current_hp = 20
	var wfoe: MercenaryData = _climber("Flee Walker Foe")
	var wst: BattleState = _climb_state(two, [walker], [wfoe])
	var street := Vector3i(14, 14, 0)
	wst.set_pos3(walker, street)
	wst.set_pos3(wfoe, Vector3i(20, 20, 0))
	FleeSystem.begin_battle(wst)
	var walk_lines: Array[String] = []
	FleeSystem.run_turn(walker, wst, walk_lines, 0)
	TestFixtures.check(res, "roof_flee a runner on open ground still walks its turn out",
		wst.pos3(walker) != street and not ConstStates.has_state(walker, ConstStates.CLIMBING)
		and not walk_lines.is_empty(),
		"at %s, %d line(s)" % [str(wst.pos3(walker)), walk_lines.size()])

	var idle: MercenaryData = _flee_climber("Flee Idle")
	var ifoe: MercenaryData = _climber("Flee Idle Foe")
	var ist: BattleState = _climb_state(two, [idle], [ifoe])
	ist.set_pos3(idle, street)
	ist.set_pos3(ifoe, Vector3i(20, 20, 0))
	var iturn: Dictionary = AutoBattle.new_turn(idle, ist)
	var idle_lines: Array[String] = []
	var idle_climb: bool = FleeSystem._continue_climb(idle, ist, idle_lines, iturn)
	var idle_hand: bool = FleeSystem._handover(idle, ist, idle_lines, iturn, ifoe, 0)
	TestFixtures.check(res, "roof_flee a runner with nothing pending neither climbs nor leaps",
		not idle_climb and not idle_hand and idle_lines.is_empty(),
		"%d line(s)" % idle_lines.size())

	MovementExecutor.clear_caches()
	PathCost.clear_climb()
	var gap: BattlefieldArea = _edge_map([[Rect2i(4, 4, 5, 5), [0, 1]], [Rect2i(10, 4, 5, 5), [0]]])
	var take := Vector3i(8, 6, 2)
	var leap_land := Vector3i(10, 6, 1)
	var jumper: MercenaryData = _flee_climber("Flee Jumper")
	jumper.current_hp = 20
	jumper.stats["jump"] = 2
	jumper.stats["parkour"] = 100.0
	var jfoe: MercenaryData = _climber("Flee Jump Foe")
	var jst: BattleState = _climb_state(gap, [jumper], [jfoe])
	jst.set_pos3(jumper, take)
	jst.set_pos3(jfoe, Vector3i(0, 20, 0))
	FleeSystem.begin_battle(jst)
	var bare_landing: Vector3i = JumpAction.routed_landing_for(jumper, jst)
	jst.set_jump_route(jumper, leap_land, take)
	var routed_landing: Vector3i = JumpAction.routed_landing_for(jumper, jst)
	TestFixtures.check(res, "roof_flee the routed landing reader answers only with a leap pending",
		bare_landing == JumpAction.NO_JUMP and routed_landing == leap_land,
		"bare %s, routed %s" % [str(bare_landing), str(routed_landing)])

	var leap_lines: Array[String] = []
	var jturn: Dictionary = AutoBattle.new_turn(jumper, jst)
	var leaped: bool = FleeSystem._handover(jumper, jst, leap_lines, jturn, jfoe, 0)
	TestFixtures.check(res, "roof_flee a runner on a take-off cell takes the leap it recorded",
		leaped and jst.pos3(jumper) == leap_land and _has_line(leap_lines, "leaps"),
		"at %s, %d line(s)" % [str(jst.pos3(jumper)), leap_lines.size()])
	MovementExecutor.clear_caches()
	PathCost.clear_climb()
	FleeSystem.reset()


#No unit is spawned on a roof it cannot climb, drop or fly off, and the probe that answers that
#hands the mover's climb values back untouched.
#The flood SpawnPlacer._can_leave_roof runs: the caller sets and restores the climb state around it.
static func _exit_flood(field: BattlefieldArea, passable: Dictionary, roof: Vector3i,
		merc: MercenaryData) -> ReachSearch:
	return ReachSearch.create(roof, field, passable, PathTargeter.fall_tolerance(merc),
		PathTargeter.is_flying(merc), true, int(merc.stats.get("jump", 0)),
		int(merc.stats.get("size", 1)), 0)


static func _case_spawn_roof(res: Dictionary) -> void:
	PathCost.set_door_penalty(0)
	PathCost.set_water_cost(null, null)
	PathCost.clear_climb()
	var railed: BattlefieldArea = _obj_map([[Rect2i(4, 4, 8, 8), [0]]], "Flat", [])
	var bare: BattlefieldArea = _edge_map([[Rect2i(4, 4, 8, 8), [0]]])
	var level: int = int(_first_part(railed).get("level", 1))
	var perch := Vector3i(6, 6, level)
	var railed_pass: Dictionary = railed.get_nav_passable_cells()
	var bare_pass: Dictionary = bare.get_nav_passable_cells()
	var small: MercenaryData = _climber("Spawn Small", 1)
	var big: MercenaryData = _climber("Spawn Big", 2)
	var flyer: MercenaryData = _climber("Spawn Flyer", 1)
	flyer.stats["fly"] = 1

	var small_out: bool = SpawnPlacer._can_leave_roof(railed, railed_pass, perch, small)
	TestFixtures.check(res, "roof_spawn a parapet the mover cannot vault leaves it no way down",
		railed.roof_cells.has(perch) and not small_out,
		"roof %s, leaves %s" % [str(railed.roof_cells.has(perch)), str(small_out)])

	var big_out: bool = SpawnPlacer._can_leave_roof(railed, railed_pass, perch, big)
	TestFixtures.check(res, "roof_spawn a mover big enough to vault the parapet gets down",
		big_out, "leaves %s" % str(big_out))

	var bare_out: bool = SpawnPlacer._can_leave_roof(bare, bare_pass, perch, small)
	TestFixtures.check(res, "roof_spawn a roof with no rail is open to the same small mover",
		bare_out, "leaves %s" % str(bare_out))

	var exit_snap: Array = PathCost.climb_snapshot()
	PathCost.set_climb(small)
	var off_roof := func(cell: Vector3i) -> bool: return cell.z == 0 and not bare.roof_cells.has(cell)
	var quick: ReachSearch = _exit_flood(bare, bare_pass, perch, small)
	var quick_out: bool = quick.ensure_until(SpawnPlacer.ROOF_EXIT_BUDGET, off_roof)
	var short_exit: ReachSearch = _exit_flood(bare, bare_pass, perch, small)
	var short_out: bool = short_exit.ensure_until(2, off_roof)
	PathCost.restore_climb(exit_snap)
	TestFixtures.check(res, "roof_spawn the exit flood stops on the first ground cell it settles",
		quick_out and quick.result.size() < 200 and not short_out,
		"%d cell(s), under 2 paces %s" % [quick.result.size(), str(short_out)])

	var fly_out: bool = SpawnPlacer._can_leave_roof(railed, railed_pass, perch, flyer)
	TestFixtures.check(res, "roof_spawn a flyer passes over the parapet and leaves the roof", fly_out,
		"leaves %s" % str(fly_out))

	var held: MercenaryData = _climber("Spawn Grounded", 1)
	held.stats["fly"] = 1
	ConstStates.apply_state(held, ConstStates.GROUNDED)
	var held_fly: bool = ConstStates.is_blocked(held, "ability:fly")
	var held_out: bool = SpawnPlacer._can_leave_roof(railed, railed_pass, perch, held)
	TestFixtures.check(res, "roof_spawn a flyer held to the ground is refused the railed roof",
		held_fly and not held_out, "blocked %s, leaves %s" % [str(held_fly), str(held_out)])

	var para_from := Vector3i(-1, -1, -1)
	var para_to := Vector3i(-1, -1, -1)
	for key: Variant in railed.drop_links.keys():
		var from: Vector3i = key as Vector3i
		for dl: Dictionary in (railed.drop_links[key] as Array):
			var vault: Vector3i = dl["vault"] as Vector3i
			if vault.x < 0 or railed.get_obs(Vector2i(vault.x, vault.y), vault.z).is_empty():
				continue
			para_from = from
			para_to = dl["to"] as Vector3i
			break
		if para_from.x >= 0:
			break
	var fly_pace: int = PathCost._drop_link_cost(para_from, para_to, railed, 2.0, 1, true)
	var walk_pace: int = PathCost._drop_link_cost(para_from, para_to, railed, 2.0, 1, false)
	TestFixtures.check(res, "roof_spawn a parapet drop costs a flyer one pace and refuses a walker",
		para_from.x >= 0 and fly_pace == 1 and walk_pace == -1,
		"from %s, fly %d, walk %d" % [str(para_from), fly_pace, walk_pace])

	PathCost.link_climbs = true
	PathCost.climb_pace = 7
	PathCost.climb_hp = 33
	PathCost.jump_roofs = 4
	PathCost.jump_fall = 1.75
	var snap: Array = PathCost.climb_snapshot()
	var _probe: bool = SpawnPlacer._can_leave_roof(bare, bare_pass, perch, small)
	var kept: bool = PathCost.link_climbs == bool(snap[0]) and PathCost.climb_pace == int(snap[1]) \
		and PathCost.climb_hp == int(snap[2]) and PathCost.jump_roofs == int(snap[3]) \
		and is_equal_approx(PathCost.jump_fall, float(snap[4]))
	PathCost.clear_climb()
	TestFixtures.check(res, "roof_spawn the way down probe hands the climb values back untouched",
		kept and snap.size() == 5, "pace %d, roofs %d" % [PathCost.climb_pace, PathCost.jump_roofs])

	var index: Dictionary = SpawnPlacer._roof_part_index(railed)
	var missing: Array[String] = []
	var owned: int = 0
	for i: int in range(railed.roof_parts.size()):
		var part: Dictionary = railed.roof_parts[i]
		var plevel: int = int(part.get("level", 0))
		for c: Vector2i in (part.get("cells", []) as Array):
			owned += 1
			if int(index.get(Vector3i(c.x, c.y, plevel), -1)) != i:
				missing.append(str(c))
	TestFixtures.check(res, "roof_spawn the roof part index answers for every cell of every part",
		owned > 0 and missing.is_empty() and index.size() == owned,
		TestFixtures.detail(missing, owned, "cell(s)"))


#The grown flood: ensure_cells must settle the same costs the whole flood does, stop once the
#listed cells are in, and leave a repeat call nothing to do.
static func _case_reach_grow(res: Dictionary) -> void:
	PathCost.set_door_penalty(0)
	PathCost.set_water_cost(null, null)
	PathCost.clear_climb()
	var map: BattlefieldArea = _edge_map([[Rect2i(4, 4, 8, 8), [0]]])
	var origin := Vector3i(0, 6, 0)
	var roof := Vector3i(6, 6, 1)
	var far_a := Vector3i(SYNTH_DIM - 1, 6, 0)
	var far_b := Vector3i(SYNTH_DIM - 1, SYNTH_DIM - 1, 0)
	var listed: Array[Vector3i] = [far_a, far_b, far_a, roof]

	var whole := ReachSearch.create(origin, map, {}, 2.0, false, false, 0, 1, 0)
	whole.ensure_all()
	var grown := ReachSearch.create(origin, map, {}, 2.0, false, false, 0, 1, 0)
	grown.ensure_cells(listed, -1, 6)
	var off: Array[String] = []
	for k: Variant in grown.result.keys():
		var c: Vector3i = k as Vector3i
		if not whole.result.has(c) or int(whole.result[c]) != int(grown.result[c]):
			off.append(str(c))
	TestFixtures.check(res, "roof_reach a grown flood prices every cell it settles as the whole one does",
		off.is_empty() and grown.result.has(far_a) and grown.result.has(far_b)
		and grown.result.size() <= whole.result.size(),
		TestFixtures.detail(off, grown.result.size(), "cell(s)"))

	var full := ReachSearch.create(origin, map, {}, 2.0, false, false, 0, 1, 0)
	full.ensure_cells(listed, -1, -1)
	var diff: Array[String] = []
	for k2: Variant in whole.result.keys():
		var c2: Vector3i = k2 as Vector3i
		if not full.result.has(c2) or int(full.result[c2]) != int(whole.result[c2]):
			diff.append(str(c2))
	TestFixtures.check(res, "roof_reach an unbounded ensure_cells settles what ensure_all settles",
		diff.is_empty() and full.result.size() == whole.result.size() and full.exhausted,
		TestFixtures.detail(diff, whole.result.size(), "cell(s)"))

	var held: int = full.result.size()
	var sum_held: int = _cost_sum(full.result)
	full.ensure_cells(listed, -1, -1)
	TestFixtures.check(res, "roof_reach a repeat ensure_cells leaves the settled result alone",
		full.result.size() == held and _cost_sum(full.result) == sum_held and full.exhausted,
		"%d cell(s), sum %d" % [full.result.size(), sum_held])

	var near := Vector3i(0, 10, 0)
	var stub := ReachSearch.create(origin, map, {}, 2.0, false, false, 0, 1, 0)
	var dup: Array[Vector3i] = [near, near, near]
	stub.ensure_cells(dup, -1, 0)
	TestFixtures.check(res, "roof_reach a listed cell repeated settles once and stops the growth",
		stub.result.has(near) and whole.result.has(near)
		and int(stub.result[near]) == int(whole.result[near])
		and stub.result.size() < grown.result.size(),
		"cost %d, %d of %d cell(s)" % [int(stub.result.get(near, -1)), stub.result.size(),
			whole.result.size()])

	TestFixtures.check(res, "roof_reach a listed cell no walk reaches settles in no flood",
		not grown.result.has(roof) and not whole.result.has(roof) and not full.result.has(roof)
		and not stub.result.has(roof),
		"grown %s, whole %s" % [str(grown.result.has(roof)), str(whole.result.has(roof))])


static func _cost_sum(costs: Dictionary) -> int:
	var total: int = 0
	for k: Variant in costs.keys():
		total += int(costs[k])
	return total


#One two level block south of a street wall no ground eye sees over: "open" leaves a doorway in it,
#"blind" adds a second wall the walk never sees past, "sealed" leaves no way through at all.
static func _budget_map(mode: String) -> BattlefieldArea:
	var f: BattlefieldArea = _synth([[BUDGET_BLOCK, [0, 1]]])
	for x: int in range(0, SYNTH_DIM):
		if mode != "sealed" and x == BUDGET_DOOR_X:
			continue
		TestFixtures.put(f, Vector3i(x, POST_WALL_Y, 0), {"cell_type": "wall", "height": 2.0})
	if mode == "blind":
		for bx: int in range(0, SYNTH_DIM):
			TestFixtures.put(f, Vector3i(bx, BUDGET_NEAR_Y, 0), {"cell_type": "wall", "height": 2.0})
	RoofBuilder.build(f, "Flat", "S", "")
	f.build_drop_links()
	return f


#The one enemy of the budget map stands north of every wall line it carries.
static func _budget_state(map: BattlefieldArea, unit: MercenaryData, foes: Array[MercenaryData],
		at: Vector3i) -> BattleState:
	var st: BattleState = _climb_state(map, [unit], foes)
	st.set_pos3(unit, at)
	st.set_pos3(foes[0], BUDGET_FOE)
	return st


#The rounds of walking this unit needs for its first shot, read from where it stands.
static func _budget_walk(unit: MercenaryData, st: BattleState,
		foes: Array[MercenaryData]) -> int:
	return RoofPostScore._walk_round(unit, st, st.pos3(unit), foes, 1,
		MovementExecutor.pace_per_move(unit))


#The post budget: a climb is taken only when the unit stands on the top in fewer rounds than the
#walk needs to see a foe, and no candidate costs more than eight Moves of walking and climbing.
static func _case_post_budget(res: Dictionary) -> void:
	PathCost.set_door_penalty(0)
	PathCost.set_water_cost(null, null)
	PathCost.clear_climb()
	var open_map: BattlefieldArea = _budget_map("open")
	var walker: MercenaryData = _post_shooter("Budget Walker")
	var walk_foes: Array[MercenaryData] = [_climber("Budget Foe")]
	var open_st: BattleState = _budget_state(open_map, walker, walk_foes, BUDGET_START)
	var per_move: int = MovementExecutor.pace_per_move(walker)
	var open_row: Dictionary = RoofPostScore.best(walker, open_st)
	var open_walk: int = _budget_walk(walker, open_st, walk_foes)
	TestFixtures.check(res, "roof_budget a walk into sight this round leaves the post no budget",
		open_row.is_empty() and open_walk == 1,
		"%d key(s), walk round %d" % [open_row.size(), open_walk])

	var open_rows: Array = RoofPostScore._candidates(walker, open_st, open_map, 1, per_move,
		RoofPostScore.MAX_MOVES)
	var near_total: int = int((open_rows[0] as Array)[0]) if not open_rows.is_empty() else 0
	var near_turns: int = int(ceil(float(near_total) / float(per_move)))
	TestFixtures.check(res, "roof_budget the post the budget refused stands four Moves off",
		near_total == 18 and near_turns == 4,
		"%d row(s), %d pace(s), %d Move(s)" % [open_rows.size(), near_total, near_turns])
	MovementExecutor.clear_caches()

	var blind_map: BattlefieldArea = _budget_map("blind")
	var perched: MercenaryData = _post_shooter("Budget Climber")
	var blind_foes: Array[MercenaryData] = [_climber("Blind Foe")]
	var blind_st: BattleState = _budget_state(blind_map, perched, blind_foes, BUDGET_START)
	RoofPostScore.reset_counter()
	var blind_row: Dictionary = RoofPostScore.best(perched, blind_st)
	var blind_cells: int = RoofPostScore.walk_cells_scored
	var blind_origins: int = RoofPostScore.origins_scored
	var blind_top := Vector3i(-1, -1, -1)
	if not blind_row.is_empty():
		blind_top = blind_row["top"] as Vector3i
	TestFixtures.check(res, "roof_budget a walk that never opens a line leaves the post its budget",
		not blind_row.is_empty() and blind_top.z == 2
		and blind_map.is_roof_footing(Vector2i(blind_top.x, blind_top.y), blind_top.z),
		"top %s" % str(blind_top))

	var blind_post: int = int(blind_row.get("post_round", 0))
	var blind_walk: int = int(blind_row.get("walk_round", 0))
	TestFixtures.check(res, "roof_budget the taken post carries its round and the walking round",
		blind_post == 2 and blind_walk == 5,
		"post round %d, walk round %d" % [blind_post, blind_walk])

	var seen_top: int = RoofPostScore._seen_from(blind_st, blind_top, 1, blind_foes)
	TestFixtures.check(res, "roof_budget the walk cells are counted apart from the post origins",
		blind_cells > 0 and blind_origins == RoofPostScore.MAX_POSTS and seen_top == 1
		and RoofPostScore.origins_scored == blind_origins + 1
		and RoofPostScore.walk_cells_scored == blind_cells,
		"%d walk cell(s), %d origin(s)" % [blind_cells, blind_origins])

	blind_st.roof_posts.clear()
	_check_post_hold(res, blind_st, perched,
		"roof_budget the scored post is held for the turn and dropped at turn start")
	MovementExecutor.clear_caches()

	var sealed_map: BattlefieldArea = _budget_map("sealed")
	var slow: MercenaryData = _post_shooter("Budget Perch")
	slow.stats["pace"] = 1
	var slow_foes: Array[MercenaryData] = [_climber("Sealed Foe")]
	var slow_st: BattleState = _budget_state(sealed_map, slow, slow_foes, BUDGET_FOOT)
	var slow_row: Dictionary = RoofPostScore.best(slow, slow_st)
	var slow_walk: int = _budget_walk(slow, slow_st, slow_foes)
	TestFixtures.check(res, "roof_budget a unit with no way to approach scores its walk at nothing",
		slow_walk == 0 and not slow_row.is_empty() and int(slow_row.get("walk_round", -1)) == 0,
		"walk round %d, %d key(s)" % [slow_walk, slow_row.size()])

	var slow_rows: Array = RoofPostScore._candidates(slow, slow_st, sealed_map, 1,
		MovementExecutor.pace_per_move(slow), RoofPostScore.MAX_MOVES)
	var worst: int = 0
	for row: Array in slow_rows:
		worst = maxi(worst, int(row[0]))
	TestFixtures.check(res, "roof_budget a post nine Moves off is no candidate",
		slow_rows.size() == 3 and worst == 8,
		"%d row(s), %d pace(s) at most" % [slow_rows.size(), worst])
	MovementExecutor.clear_caches()

	var even_map: BattlefieldArea = _budget_map("open")
	var even: MercenaryData = _post_shooter("Budget Even")
	var even_foes: Array[MercenaryData] = [_climber("Even Foe")]
	var even_st: BattleState = _budget_state(even_map, even, even_foes, BUDGET_EVEN)
	var even_row: Dictionary = RoofPostScore.best(even, even_st)
	var even_walk: int = _budget_walk(even, even_st, even_foes)
	var even_rows: Array = RoofPostScore._candidates(even, even_st, even_map, 1, per_move,
		RoofPostScore.MAX_MOVES)
	var even_total: int = int((even_rows[0] as Array)[0]) if not even_rows.is_empty() else 0
	var even_moves: int = int(ceil(float(even_total) / float(per_move)))
	var even_round: int = int(ceil(float(even_moves) / float(RoofPostScore.MOVES_PER_ROUND)))
	TestFixtures.check(res, "roof_budget a post landing on the walking round is left behind",
		even_row.is_empty() and even_walk == 2 and even_round == 2,
		"walk round %d, post round %d, %d pace(s)" % [even_walk, even_round, even_total])
	MovementExecutor.clear_caches()
	PathCost.clear_climb()


#Fix round 1: a walker one cell from a hovering flyer marks it blocked instead of scanning rings every slot.
static func _case_hover_reach(res: Dictionary) -> void:
	var no_mercs: Array[MercenaryData] = []
	MovementExecutor.clear_caches()
	var field: BattlefieldArea = TestFixtures.exterior_field()
	var walker: MercenaryData = _climber("Hover Walker")
	walker.current_ap = 6
	var flyer: MercenaryData = _climber("Hover Flyer")
	flyer.stats["fly"] = 3
	var st: BattleState = _climb_state(field, [walker], [flyer])
	st.set_pos3(walker, Vector3i(4, 4, 0))
	st.set_pos3(flyer, Vector3i(5, 4, 0))
	st.set_height(flyer, 4)
	var hover_lines: Array[String] = MovementExecutor.execute_move(walker, "Move Close", flyer, st, null, 0, -1,
		false, no_mercs, no_mercs)
	var marked: bool = (st.movement_blocked.get(walker, {}) as Dictionary).has(flyer)
	TestFixtures.check(res, "hover_reach a walker under a hovering flyer marks it blocked and keeps its AP",
		hover_lines.is_empty() and marked and walker.current_ap == 6 and st.pos3(walker) == Vector3i(4, 4, 0)
		and int(walker.active_states.get("_move_blocked_round", -1)) == st.round_number,
		"%d line(s), marked %s, ap %d" % [hover_lines.size(), str(marked), walker.current_ap])
	st.movement_blocked.erase(walker)
	walker.active_states.erase("_move_blocked_round")
	st.set_height(flyer, 0)
	MovementExecutor.execute_move(walker, "Move Close", flyer, st, null, 0, -1, false, no_mercs, no_mercs)
	var landed_marked: bool = (st.movement_blocked.get(walker, {}) as Dictionary).has(flyer)
	TestFixtures.check(res, "hover_reach a landed flyer beside the walker is not marked blocked",
		not landed_marked, "marked %s" % str(landed_marked))
	MovementExecutor.clear_caches()


#Fix round 2: a walker whose best cell is its own cannot reach a target standing above melee reach.
static func _case_upper_reach(res: Dictionary) -> void:
	var no_mercs: Array[MercenaryData] = []
	MovementExecutor.clear_caches()
	var field: BattlefieldArea = TestFixtures.exterior_field()
	field.terrain_heights[Vector2i(6, 4)] = 4.0
	var walker: MercenaryData = _climber("Upper Walker")
	walker.current_ap = 6
	var perched: MercenaryData = _climber("Upper Perched")
	var st: BattleState = _climb_state(field, [walker], [perched])
	st.set_pos3(walker, Vector3i(5, 4, 0))
	st.set_pos3(perched, Vector3i(6, 4, 0))
	var up_lines: Array[String] = MovementExecutor.execute_move(walker, "Move Close", perched, st, null, 0, -1,
		false, no_mercs, no_mercs)
	var marked: bool = (st.movement_blocked.get(walker, {}) as Dictionary).has(perched)
	TestFixtures.check(res, "upper_reach a walker under a perched target marks it blocked and keeps its AP",
		up_lines.is_empty() and marked and walker.current_ap == 6 and st.pos3(walker) == Vector3i(5, 4, 0)
		and int(walker.active_states.get("_move_blocked_round", -1)) == st.round_number,
		"%d line(s), marked %s, ap %d, at (%d,%d)" % [up_lines.size(), str(marked), walker.current_ap,
		st.pos3(walker).x, st.pos3(walker).y])
	MovementExecutor.clear_caches()
	var low_field: BattlefieldArea = TestFixtures.exterior_field()
	low_field.terrain_heights[Vector2i(6, 4)] = 1.0
	var low_walker: MercenaryData = _climber("Low Walker")
	low_walker.current_ap = 6
	var low_perched: MercenaryData = _climber("Low Perched")
	var low_st: BattleState = _climb_state(low_field, [low_walker], [low_perched])
	low_st.set_pos3(low_walker, Vector3i(5, 4, 0))
	low_st.set_pos3(low_perched, Vector3i(6, 4, 0))
	MovementExecutor.execute_move(low_walker, "Move Close", low_perched, low_st, null, 0, -1, false, no_mercs,
		no_mercs)
	var low_marked: bool = (low_st.movement_blocked.get(low_walker, {}) as Dictionary).has(low_perched)
	TestFixtures.check(res, "upper_reach a target one pace up beside the walker is not marked blocked",
		not low_marked, "marked %s" % str(low_marked))
	MovementExecutor.clear_caches()


#Fix round 3: the first shot walk probe leaves no goal, target, far_full or team blocked entry behind.
static func _case_probe_state(res: Dictionary) -> void:
	PathCost.set_door_penalty(0)
	PathCost.set_water_cost(null, null)
	PathCost.clear_climb()
	MovementExecutor.clear_caches()
	var open_map: BattlefieldArea = _budget_map("open")
	var walker: MercenaryData = _post_shooter("Probe Walker")
	var foes: Array[MercenaryData] = [_climber("Probe Foe")]
	var st: BattleState = _budget_state(open_map, walker, foes, BUDGET_START)
	var first: int = _budget_walk(walker, st, foes)
	TestFixtures.check(res, "roof_probe a walk probe leaves no goal, target or blocked mark behind",
		st.move_goals.is_empty() and st.move_targets.is_empty() and st.far_full.is_empty()
		and st.team_blocked_round.is_empty() and st.team_blocked_count.is_empty(),
		"goals %d, targets %d, far %d, blocked %d/%d" % [st.move_goals.size(), st.move_targets.size(),
			st.far_full.size(), st.team_blocked_round.size(), st.team_blocked_count.size()])
	st.move_goals[walker] = Vector3i(1, 1, 0)
	st.move_targets[walker] = foes[0]
	st.team_blocked_round[foes[0]] = st.round_number
	st.team_blocked_count[foes[0]] = 1
	var again: int = _budget_walk(walker, st, foes)
	TestFixtures.check(res, "roof_probe a walk probe puts back the entries it found",
		again == first and st.move_goals.get(walker, Vector3i(-9, -9, -9)) == Vector3i(1, 1, 0)
		and st.move_targets.get(walker) == foes[0] and st.far_full.is_empty()
		and int(st.team_blocked_round.get(foes[0], -1)) == st.round_number
		and int(st.team_blocked_count.get(foes[0], 0)) == 1,
		"rounds %d then %d, goal %s, count %d" % [first, again, str(st.move_goals.get(walker)),
			int(st.team_blocked_count.get(foes[0], 0))])
	MovementExecutor.clear_caches()
	var sealed_map: BattlefieldArea = _budget_map("sealed")
	var stuck: MercenaryData = _post_shooter("Probe Stuck")
	var sealed_foes: Array[MercenaryData] = [_climber("Sealed Foe")]
	var sealed_st: BattleState = _budget_state(sealed_map, stuck, sealed_foes, BUDGET_START)
	_budget_walk(stuck, sealed_st, sealed_foes)
	TestFixtures.check(res, "roof_probe a probe that finds no cell leaves the team counters clean",
		sealed_st.team_blocked_round.is_empty() and sealed_st.team_blocked_count.is_empty()
		and sealed_st.far_full.is_empty() and sealed_st.move_goals.is_empty(),
		"blocked %d/%d, far %d" % [sealed_st.team_blocked_round.size(), sealed_st.team_blocked_count.size(),
			sealed_st.far_full.size()])
	MovementExecutor.clear_caches()


#Fix round 3: an empty shooter with ammo in hand is held for the round but never marked blocked for good.
static func _case_reload_reach(res: Dictionary) -> void:
	var no_mercs: Array[MercenaryData] = []
	MovementExecutor.clear_caches()
	var field: BattlefieldArea = TestFixtures.exterior_field()
	var archer: MercenaryData = _shooter("Empty Archer")
	archer.current_ap = 6
	archer.ammo_loaded = 0
	archer.ammo_inventory = {"Arrow": 3}
	var flyer: MercenaryData = _climber("Reload Flyer")
	flyer.stats["fly"] = 3
	var st: BattleState = _climb_state(field, [archer], [flyer])
	st.set_pos3(archer, Vector3i(4, 4, 0))
	st.set_pos3(flyer, Vector3i(5, 4, 0))
	st.set_height(flyer, 4)
	var lines: Array[String] = MovementExecutor.execute_move(archer, "Move Close", flyer, st, null, 0, -1,
		false, no_mercs, no_mercs)
	var marked: bool = (st.movement_blocked.get(archer, {}) as Dictionary).has(flyer)
	TestFixtures.check(res, "reload_reach an empty archer with arrows under a flyer is held this round only",
		lines.is_empty() and not marked and st.pos3(archer) == Vector3i(4, 4, 0)
		and int(archer.active_states.get("_move_blocked_round", -1)) == st.round_number,
		"%d line(s), marked %s, round mark %d" % [lines.size(), str(marked),
			int(archer.active_states.get("_move_blocked_round", -1))])
	archer.ammo_inventory = {}
	archer.active_states.erase("_move_blocked_round")
	MovementExecutor.clear_caches()
	MovementExecutor.execute_move(archer, "Move Close", flyer, st, null, 0, -1, false, no_mercs, no_mercs)
	var dry_marked: bool = (st.movement_blocked.get(archer, {}) as Dictionary).has(flyer)
	TestFixtures.check(res, "reload_reach the same archer with no arrows left is marked blocked",
		dry_marked, "marked %s" % str(dry_marked))
	MovementExecutor.clear_caches()
	var up_field: BattlefieldArea = TestFixtures.exterior_field()
	up_field.terrain_heights[Vector2i(6, 4)] = 4.0
	var up_archer: MercenaryData = _shooter("Empty Perch Archer")
	up_archer.current_ap = 6
	up_archer.ammo_loaded = 0
	up_archer.ammo_inventory = {"Arrow": 2}
	var perched: MercenaryData = _climber("Reload Perched")
	var up_st: BattleState = _climb_state(up_field, [up_archer], [perched])
	up_st.set_pos3(up_archer, Vector3i(5, 4, 0))
	up_st.set_pos3(perched, Vector3i(6, 4, 0))
	var up_lines: Array[String] = MovementExecutor.execute_move(up_archer, "Move Close", perched, up_st, null,
		0, -1, false, no_mercs, no_mercs)
	var up_marked: bool = (up_st.movement_blocked.get(up_archer, {}) as Dictionary).has(perched)
	TestFixtures.check(res, "reload_reach an empty archer with arrows under a perched foe is not marked",
		up_lines.is_empty() and not up_marked
		and int(up_archer.active_states.get("_move_blocked_round", -1)) == up_st.round_number,
		"%d line(s), marked %s" % [up_lines.size(), str(up_marked)])
	MovementExecutor.clear_caches()


#Fix round 3: the roof level caches survive no rebuild, reset or copy, even at an unchanged cell count.
static func _case_roof_cache(res: Dictionary) -> void:
	var f: BattlefieldArea = _edge_map([[Rect2i(4, 4, 8, 8), [0]]])
	var c := Vector2i(6, 6)
	var built: int = f.roof_level_at(c)
	var shifted: Dictionary = {}
	for k: Variant in f.roof_cells.keys():
		var v: Vector3i = k as Vector3i
		shifted[Vector3i(v.x, v.y, v.z + 5)] = int(f.roof_cells[k])
	f.roof_cells = shifted.duplicate()
	f.invalidate_roof_levels()
	var manual: int = f.roof_level_at(c)
	RoofBuilder.build(f, "Flat", "S", "")
	var rebuilt: int = f.roof_level_at(c)
	TestFixtures.check(res, "roof_cache a rebuild at the same cell count reads the new levels",
		built >= 1 and manual == built + 5 and rebuilt == built,
		"built %d, manual %d, rebuilt %d, %d cell(s)" % [built, manual, rebuilt, f.roof_cells.size()])
	var count: int = f.roof_cells.size()
	f.reset_generated_state()
	var cleared: int = f.roof_level_at(c)
	var again: Dictionary = {}
	for k2: Variant in shifted.keys():
		var v2: Vector3i = k2 as Vector3i
		again[Vector3i(v2.x, v2.y, built + 3)] = int(shifted[k2])
	f.roof_cells = again
	var after_reset: int = f.roof_level_at(c)
	TestFixtures.check(res, "roof_cache a reset forgets the levels and a same sized table reads fresh",
		cleared == -1 and again.size() == count and after_reset == built + 3,
		"cleared %d, after %d want %d" % [cleared, after_reset, built + 3])
	var scratch: BattlefieldArea = _edge_map([[Rect2i(4, 4, 8, 8), [0]]])
	var target: BattlefieldArea = _synth([[Rect2i(4, 4, 8, 8), [0]]])
	for k3: Variant in scratch.roof_cells.keys():
		var v3: Vector3i = k3 as Vector3i
		target.roof_cells[Vector3i(v3.x, v3.y, v3.z + 4)] = int(scratch.roof_cells[k3])
	var primed: int = target.roof_level_at(c)
	target.roof_cells.clear()
	RoofBuilder.copy_to(scratch, target, Vector2i.ZERO, 0)
	var copied: int = target.roof_level_at(c)
	TestFixtures.check(res, "roof_cache a copy at the same cell count reads the copied levels",
		primed == built + 4 and target.roof_cells.size() == scratch.roof_cells.size() and copied == built,
		"primed %d, copied %d want %d" % [primed, copied, built])
