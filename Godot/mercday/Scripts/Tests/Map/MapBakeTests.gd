class_name MapBakeTests extends RefCounted

#Runner ordering, downstream expansion, manifest skips, the height and nation steps on fixtures, greedy merge and the writer.
#Run: godot --headless --path . -- --map-bake-tests. Nothing is written under Baked/.

const CROP_RECT: Rect2i = Rect2i(2400, 1300, 160, 120)
const SKIP_NOTE: String = "source layers not imported; real crop skipped"
const SCRATCH_DIR: String = "user://map_bake_tests/"
#Plan level codes: round(grey / 10.5) terraces n >= 4 map to level n - 5.
const LAND_LEVEL: int = 8
const RIVER_LEVEL: int = 7
const PLATEAU_LEVEL: int = 14
const TOP_LEVEL: int = 19


class Stub extends MapBakeStep:
	func _init(n: StringName, ins: Array, outs: Array, mods: Array = [], last: bool = false) -> void:
		step_name = n
		inputs = PackedStringArray(ins)
		outputs = PackedStringArray(outs)
		modifies = PackedStringArray(mods)
		run_last = last


class FileCtx extends MapBakeContext:
	func path_of(key: String) -> String:
		return SCRATCH_DIR + key


static func run(_host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_order(res)
	_case_downstream(res)
	_case_manifest(res)
	_case_level_of(res)
	_case_height_steps(res)
	_case_nations(res)
	_case_greedy_writer(res)
	_case_crop(res)
	return TestFixtures.summarize(res, "MAP BAKE")


static func _index(list: Array[MapBakeStep], n: StringName) -> int:
	for i: int in list.size():
		if list[i].step_name == n:
			return i
	return -1


static func _case_order(res: Dictionary) -> void:
	var prod: MapBakeStep = Stub.new(&"prod", [], ["k"])
	var mod: MapBakeStep = Stub.new(&"mod", [], [], ["k"])
	var rd: MapBakeStep = Stub.new(&"rd", ["k"], ["o"])
	var last: MapBakeStep = Stub.new(&"last", [], [], [], true)
	var got: Array[MapBakeStep] = MapBakeRunner.new().order([last, rd, mod, prod])
	var ok: bool = got.size() == 4 and _index(got, &"prod") < _index(got, &"mod") \
		and _index(got, &"mod") < _index(got, &"rd") and _index(got, &"last") == 3
	TestFixtures.check(res, "order: producer, modifier, reader, run_last", ok, "got %d steps" % got.size())
	var a: MapBakeStep = Stub.new(&"cyc_a", ["y"], ["x"])
	var b: MapBakeStep = Stub.new(&"cyc_b", ["x"], ["y"])
	var runner: MapBakeRunner = MapBakeRunner.new()
	var empty: Array[MapBakeStep] = runner.order([a, b])
	TestFixtures.check(res, "order: a cycle fails and returns no steps", empty.is_empty() and runner.ctx.failed,
		"size %d failed %s" % [empty.size(), str(runner.ctx.failed)])


static func _case_downstream(res: Dictionary) -> void:
	var prod: MapBakeStep = Stub.new(&"prod", [], ["k"])
	var rd: MapBakeStep = Stub.new(&"rd", ["k"], ["o"])
	var far: MapBakeStep = Stub.new(&"far", ["o"], ["p"])
	var other: MapBakeStep = Stub.new(&"other", ["z"], ["q"])
	var got: Array[MapBakeStep] = MapBakeRunner.new().downstream_of([prod], [prod, rd, far, other])
	var ok: bool = _index(got, &"rd") >= 0 and _index(got, &"far") >= 0 and _index(got, &"other") < 0
	TestFixtures.check(res, "downstream: readers and their readers, not unrelated steps", ok, "got %d steps" % got.size())


static func _case_manifest(res: Dictionary) -> void:
	var step: MapBakeStep = Stub.new(&"mem_step", ["src/map-height.png"], ["mem_only_key"])
	var ctx: MapBakeContext = MapTestFixtures.fixture_ctx()
	var manifest: MapBakeManifest = MapBakeManifest.new()
	TestFixtures.check(res, "manifest: unknown step is not current", not manifest.is_current(step, ctx), "fresh manifest")
	manifest.record(step, ctx, 5)
	var entry: Dictionary = manifest.steps.get("mem_step", {})
	var outs: Dictionary = entry.get("outputs", {})
	TestFixtures.check(res, "manifest: record stores the step with -1 bytes for a memory output",
		int(outs.get("mem_only_key", 0)) == -1 and int(entry.get("ms", 0)) == 5, str(entry))
	TestFixtures.check(res, "manifest: a step with a memory output never counts as current",
		not manifest.is_current(step, ctx), "outputs %s" % str(outs))
	_case_manifest_files(res)


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)


static func _case_manifest_files(res: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCRATCH_DIR))
	var ctx: MapBakeContext = FileCtx.new()
	var step: MapBakeStep = Stub.new(&"file_step", ["in.txt"], ["out.txt"])
	_write(ctx.path_of("in.txt"), "first")
	_write(ctx.path_of("out.txt"), "baked")
	var manifest: MapBakeManifest = MapBakeManifest.new()
	manifest.record(step, ctx, 1)
	TestFixtures.check(res, "manifest: unchanged input and present output is current", manifest.is_current(step, ctx),
		str(manifest.steps.get("file_step", {})))
	_write(ctx.path_of("in.txt"), "second")
	TestFixtures.check(res, "manifest: a changed input is not current", not manifest.is_current(step, ctx), "input rewritten")
	manifest.record(step, ctx, 1)
	DirAccess.remove_absolute(ctx.path_of("out.txt"))
	TestFixtures.check(res, "manifest: a missing output file is not current", not manifest.is_current(step, ctx), "output removed")
	DirAccess.remove_absolute(ctx.path_of("in.txt"))
	DirAccess.remove_absolute(SCRATCH_DIR.trim_suffix("/"))


static func _case_level_of(res: Dictionary) -> void:
	var mono: bool = true
	var prev: int = 0
	for i: int in 256:
		var lv: int = BakeHeightBlocks.level_of(i / 255.0)
		mono = mono and lv >= prev and lv < MapConst.LEVEL_COUNT
		prev = lv
	TestFixtures.check(res, "level_of is monotonic and under LEVEL_COUNT", mono, "last level %d" % prev)
	var lv_land: int = BakeHeightBlocks.level_of(MapTestFixtures.LAND_GRAY / 255.0)
	var lv_plat: int = BakeHeightBlocks.level_of(MapTestFixtures.PLATEAU_GRAY / 255.0)
	TestFixtures.check(res, "level_of matches plan codes: land 8, plateau 14, white 19",
		lv_land == LAND_LEVEL and lv_plat == PLATEAU_LEVEL and prev == TOP_LEVEL,
		"land %d plateau %d top %d" % [lv_land, lv_plat, prev])
	TestFixtures.check(res, "level_of floors dry land at the shore level",
		BakeHeightBlocks.level_of(0.0) == MapConst.LEVEL_SHORE, "got %d" % BakeHeightBlocks.level_of(0.0))
	TestFixtures.check(res, "river block at the water line is the water level",
		BakeHeightBlocks.block_level(0.0, true) == MapConst.LEVEL_WATER, "got %d" % BakeHeightBlocks.block_level(0.0, true))


static func _run_step(res: Dictionary, step: MapBakeStep, ctx: MapBakeContext) -> bool:
	var ok: bool = step.run(ctx)
	TestFixtures.check(res, "%s runs on the fixture" % step.step_name, ok and not ctx.failed, "ok %s" % str(ok))
	return ok


static func _case_height_steps(res: Dictionary) -> void:
	var ctx: MapBakeContext = MapTestFixtures.fixture_ctx()
	if not (_run_step(res, BakeHeightFlood.new(), ctx) and _run_step(res, BakeHeightRivers.new(), ctx) \
			and _run_step(res, BakeHeightBlocks.new(), ctx)):
		return
	var sea: Image = ctx.get_image("sea_frac")
	var river: Image = ctx.get_image("river_mask")
	var lvl: Image = ctx.get_image("block_level")
	var dims: bool = sea.get_size() == Vector2i(MapTestFixtures.FIX_W / 2, MapTestFixtures.FIX_H / 2) \
		and river.get_size() == sea.get_size() and lvl.get_size() == sea.get_size()
	TestFixtures.check(res, "block images are half the fixture size", dims, "sea %s" % str(sea.get_size()))
	TestFixtures.check(res, "flood: border sea and the sea gap round the islet are sea",
		sea.get_pixel(0, 0).r8 >= 128 and sea.get_pixel(7, 3).r8 >= 128, "%d %d" % [sea.get_pixel(0, 0).r8, sea.get_pixel(7, 3).r8])
	TestFixtures.check(res, "flood: land and islet are not sea", sea.get_pixel(30, 30).r8 < 128 and sea.get_pixel(3, 3).r8 < 128,
		"%d %d" % [sea.get_pixel(30, 30).r8, sea.get_pixel(3, 3).r8])
	TestFixtures.check(res, "rivers: river column marked 1, lake 2, plain land and sea 0",
		river.get_pixel(20, 30).r8 == 1 and river.get_pixel(60, 44).r8 == 2 and river.get_pixel(30, 30).r8 == 0 \
		and river.get_pixel(0, 0).r8 == 0, "river %d lake %d" % [river.get_pixel(20, 30).r8, river.get_pixel(60, 44).r8])
	var land: int = lvl.get_pixel(30, 30).r8
	TestFixtures.check(res, "blocks: sea is LEVEL_SEA", lvl.get_pixel(0, 0).r8 == MapConst.LEVEL_SEA, "got %d" % lvl.get_pixel(0, 0).r8)
	TestFixtures.check(res, "blocks: land and islet are level 8",
		land == LAND_LEVEL and lvl.get_pixel(3, 3).r8 == LAND_LEVEL, "land %d islet %d" % [land, lvl.get_pixel(3, 3).r8])
	TestFixtures.check(res, "blocks: river and lake are level 7, one terrace under the land",
		lvl.get_pixel(20, 30).r8 == RIVER_LEVEL and lvl.get_pixel(60, 44).r8 == RIVER_LEVEL,
		"river %d lake %d land %d" % [lvl.get_pixel(20, 30).r8, lvl.get_pixel(60, 44).r8, land])
	TestFixtures.check(res, "blocks: plateau is level 14", lvl.get_pixel(55, 30).r8 == PLATEAU_LEVEL, "plateau %d" % lvl.get_pixel(55, 30).r8)


static func _case_nations(res: Dictionary) -> void:
	var ctx: MapBakeContext = MapTestFixtures.full_nations_ctx()
	if not _run_step(res, BakeNations.new(), ctx):
		return
	var img: Image = ctx.get_image("block_nation")
	var ox: int = MapConst.PAD_L / MapConst.BLOCK_PX
	var oy: int = MapConst.PAD_T / MapConst.BLOCK_PX
	var left: int = img.get_pixel(ox + 30, oy + 30).r8
	var right: int = img.get_pixel(ox + 60, oy + 30).r8
	var islet: int = img.get_pixel(ox + 3, oy + 3).r8
	TestFixtures.check(res, "nations: ids by side, sea 0", (left & MapData.NATION_MASK) == 1 and (right & MapData.NATION_MASK) == 2 \
		and img.get_pixel(0, 0).r8 == 0, "left %d right %d" % [left, right])
	TestFixtures.check(res, "nations: islet keeps its id and gets bit 7, big clusters do not",
		(islet & MapData.NATION_MASK) == 1 and (islet & 0x80) != 0 and (left & 0x80) == 0 and (right & 0x80) == 0,
		"islet %d left %d right %d" % [islet, left, right])


static func _case_greedy_writer(res: Dictionary) -> void:
	var size: int = MapConst.CHUNK_BLOCKS
	var origin: Vector2i = Vector2i.ZERO
	var one_nation: Image = MapTestFixtures.nation_image(size, size, size)
	var two_nations: Image = MapTestFixtures.nation_image(size, size, size / 2)
	var cases: Array = [[&"flat", one_nation, 1], [&"step", one_nation, 2], [&"flat", two_nations, 2]]
	for c: Array in cases:
		var quads: PackedInt32Array = BakeTerrainGreedy.merge_chunk(MapTestFixtures.level_image(size, size, c[0]), c[1], origin)
		var area: int = 0
		for i: int in range(0, quads.size() - 4, 5):
			area += quads[i + 2] * quads[i + 3]
		TestFixtures.check(res, "greedy %s merges to %d quads" % [c[0], c[2]], quads.size() == c[2] * 5 and area == size * size,
			"quads %d area %d" % [quads.size() / 5, area])
	var islet: PackedInt32Array = BakeTerrainGreedy.merge_chunk(MapTestFixtures.level_image(size, size, &"islet"), one_nation, origin)
	var islet_area: int = 0
	for i: int in range(0, islet.size() - 4, 5):
		islet_area += islet[i + 2] * islet[i + 3]
	TestFixtures.check(res, "greedy islet keeps the area and splits the flat quad", islet.size() > 5 and islet_area == size * size,
		"quads %d area %d" % [islet.size() / 5, islet_area])
	var tops: PackedInt32Array = BakeTerrainGreedy.merge_chunk(MapTestFixtures.level_image(size, size, &"step"), one_nation, origin)
	var mesh: ArrayMesh = BakeTerrainWriter.build_chunk(tops, PackedInt32Array())
	TestFixtures.check(res, "writer: one surface, 4 vertices and 6 indices per top quad",
		mesh != null and mesh.get_surface_count() == 1 and mesh.surface_get_array_len(0) == 8 \
		and mesh.surface_get_array_index_len(0) == 12, "mesh %s" % str(mesh))


static func _case_crop(res: Dictionary) -> void:
	var ctx: MapBakeContext = MapTestFixtures.crop_ctx(CROP_RECT)
	if ctx == null:
		print("SKIP real crop | ", SKIP_NOTE)
		return
	if not (_run_step(res, BakeHeightFlood.new(), ctx) and _run_step(res, BakeHeightRivers.new(), ctx) \
			and _run_step(res, BakeHeightBlocks.new(), ctx)):
		return
	var lvl: Image = ctx.get_image("block_level")
	var top: int = 0
	for y: int in lvl.get_height():
		for x: int in lvl.get_width():
			top = maxi(top, lvl.get_pixel(x, y).r8)
	TestFixtures.check(res, "real crop: block_level is half size with every level under LEVEL_COUNT",
		lvl.get_size() == Vector2i(CROP_RECT.size.x / 2, CROP_RECT.size.y / 2) and top < MapConst.LEVEL_COUNT,
		"size %s top %d" % [str(lvl.get_size()), top])
