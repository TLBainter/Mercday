class_name MapColorTests extends RefCounted

#Palette packing, block colour rules on fixtures, the grey fallback and the baked colour layer.
#Run: godot --headless --path . -- --map-color-tests. Nothing is written under Baked/.

const CELL_PATH: String = "res://Resources/Map/Baked/cell_color.res"
const VRAM_BYTES: int = 4215040

static func run(_host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	var pk: Dictionary = BakePalette.pack(_pal(_LAND, "Sea ice"), _pal(_WATER, ""))
	_case_palette(res, pk)
	_case_blocks(res, pk["table"])
	_case_integration(res)
	_case_real(res)
	return TestFixtures.summarize(res, "MAP COLOR")
const _LAND: Array = [[0, "Grass", "8fb574", "6c9e48", "476830"], [5, "Sand", "e7ce98", "e0be78", "947d4f"],
	[11, "Marsh", "809474", "587248", "3a4b30"], [15, "Magma", "ffa800", "dd4800", "aa2800"],
	[16, "Sea ice", "f4f8fc", "dde6ef", "b4c3d4"]]
const _WATER: Array = [[0, "Deep sea", "4d617e", "263e62", "1e304c"], [3, "Lake", "6297a1", "40808c", "32646d"],
	[6, "Marsh", "7e9779", "62805c", "4c6448"]]
const _LAND_PX: Array = [[0, 0, "e0be78", 2], [0, 2, "e0be78", 2], [1, 1, "6c9e48"], [5, 1, "6c9e48"], [3, 3, "8fb574"],
	[2, 0, "e0be78"], [4, 0, "ffa800"], [7, 0, "aa2800"], [5, 3, "dde6ef"], [7, 3, "1a1616"]]
const _WATER_PX: Array = [[7, 1, "263e62"], [1, 3, "40808c"], [3, 3, "40808c"]]

static func _rows(res: Dictionary, rows: Array) -> void:
	for row: Array in rows:
		TestFixtures.check(res, str(row[0]), row[1] == row[2], "got %s want %s" % [str(row[1]), str(row[2])])

static func _pal(specs: Array, skip: String) -> Dictionary:
	var classes: Array = []
	var lookup: Dictionary = {}
	for sp: Array in specs:
		classes.append({"id": sp[0], "name": sp[1], "light": "#" + sp[2], "base": "#" + sp[3], "dark": "#" + sp[4]})
		for t: int in 3:
			if sp[1] != skip:
				lookup["#" + str(sp[2 + t])] = {"class": sp[1], "tone": BakePalette.TONES[t]}
	return {"classes": classes, "lookup": lookup}

static func _img(w: int, h: int, vals: Array = [], px: Array = []) -> Image:
	if not vals.is_empty():
		return Image.create_from_data(w, h, false, Image.FORMAT_R8, PackedByteArray(vals))
	var img: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for e: Array in px:
		var n: int = e[3] if e.size() > 3 else 1
		img.fill_rect(Rect2i(e[0], e[1], n, n), Color("#" + str(e[2])))
	return img

static func _case_palette(res: Dictionary, pk: Dictionary) -> void:
	var img: Image = pk["image"]
	var table: Dictionary = pk["table"]
	var hex: Dictionary = table["hex"]
	var wcl: Dictionary = table["water_classes"]
	var warns: String = "\n".join(pk["warnings"] as PackedStringArray)
	var twice: String = JSON.stringify(BakePalette.pack(_pal(_LAND, "Sea ice"), _pal(_WATER, ""))["table"])
	var gap: String = "%s %d %s %s" % [str(Array(table["missing"])), int(hex["#dde6ef"]),
		img.get_pixel(65, 0).to_html(false), str(not warns.contains("has no lookup row"))]
	var empty: String = "%s %d" % [img.get_pixel(126, 0).to_html(true), int(table["empty_index"])]
	var shape: String = "%dx%d f%d" % [img.get_width(), img.get_height(), img.get_format()]
	_rows(res, [
		["palette is 256x1 RGBA8", shape, "256x1 f%d" % Image.FORMAT_RGBA8],
		["pack has no error", str(pk["error"]), ""],
		["land base tone index", int(hex["#6c9e48"]), 1], ["land dark tone index", int(hex["#aa2800"]), 62],
		["water base offset", int(hex["#263e62"]), 129], ["water class index", int(wcl["Lake"]), 141],
		["Marsh kept apart", "%d %d" % [int(table["classes"]["Marsh"]), int(wcl["Marsh"])], "45 153"],
		["palette colour at index", img.get_pixel(1, 0).to_html(false), "6c9e48"],
		["deep sea slot", img.get_pixel(255, 0).to_html(false), "263e62"],
		["reserved slot", img.get_pixel(127, 0).to_html(true), BakePalette.RESERVED_COLOR.to_html(true)],
		["magma indices", Array(table["magma"]), [60, 61, 62]], ["lookup gap reported", gap, "[\"Sea ice\"] 65 dde6ef true"],
		["pack is deterministic", JSON.stringify(table), twice],
		["empty slot colour", empty, "%s 126" % BakePalette.EMPTY_COLOR.to_html(true)],
		["index_of exact", BakeCellColor.index_of(Color("#e0be78"), table), 21],
		["index_of #1a1616 is reserved", BakeCellColor.index_of(Color("#1a1616"), table), 127],
		["index_of nearest land", BakeCellColor.index_of(Color("#8fb575"), table, 0), 0],
		["index_of nearest water", BakeCellColor.index_of(Color("#4d617f"), table, 128), 128],
	])

static func _case_blocks(res: Dictionary, table: Dictionary) -> void:
	var levels: Image = _img(4, 2, [5, 5, 5, 0, 2, 5, 0, 5])
	var land: Image = _img(8, 4, [], _LAND_PX)
	var rivers: Image = _img(4, 2, [0, 0, 0, 0, 1, 0, 0, 0])
	var out: Dictionary = BakeCellColor.color_blocks(land, _img(8, 4, [], _WATER_PX), levels, rivers, table)
	var img: Image = out["image"]
	var d: PackedByteArray = img.get_data()
	var ul: Dictionary = out["unmatched_land"]
	var counts: String = "%d|%d|%d|%d|%d|%d|%d" % [ul.size(), int(ul.get("#1a1616", 0)), int(out["magma"]), int(out["reserved"]),
		int(out["water"]), int(out["empty"]), (out["unmatched_water"] as Dictionary).size()]
	var blank: Image = _img(2, 2)
	var wb: Dictionary = BakeCellColor.color_blocks(blank, blank, _img(1, 1, [0]), _img(1, 1, [0]), table)
	var lb: Dictionary = BakeCellColor.color_blocks(blank, blank, _img(1, 1, [5]), _img(1, 1, [0]), table)
	_rows(res, [
		["cell image is R8 at half size", "%dx%d f%d" % [img.get_width(), img.get_height(), img.get_format()],
			"4x2 f%d" % Image.FORMAT_R8],
		["centre px rule", d[0], 1], ["first opaque px when centre is clear", d[1], 21], ["Magma priority", d[2], 60],
		["Magma wins on a water block", d[3], 62], ["water first on a river block", d[4], 141],
		["land first on a land block", d[5], 0], ["water block falls back to land", d[6], 65],
		["#1a1616 gives reserved", d[7], 127], ["unmatched counts", counts, "1|1|2|1|3|0|0"],
		["empty water block is empty", (wb["image"] as Image).get_data()[0], 126],
		["empty land block is empty", (lb["image"] as Image).get_data()[0], 126],
	])

static func _case_integration(res: Dictionary) -> void:
	var baked: bool = MapPalette.is_full()
	var shader: String = FileAccess.get_file_as_string("res://Scripts/Map/Shaders/map_terrain.gdshader")
	var mat: ShaderMaterial = load("res://Resources/Map/Materials/water.tres") as ShaderMaterial
	var wc: Variant = mat.get_shader_parameter("water_color") if mat != null else null
	var v: Vector4 = wc if typeof(wc) == TYPE_VECTOR4 else Vector4(9.0, 9.0, 9.0, 9.0)
	var c: Color = MapConst.DEEP_SEA
	var close: bool = maxf(maxf(absf(v.x - c.r), absf(v.y - c.g)), absf(v.z - c.b)) <= 1.0 / 255.0
	var want1: String = "6c9e48" if baked else MapPalette.grey_ramp().get_pixel(1, 0).to_html(false)
	var grey: Image = MapData._level_to_palette(_img(4, 2, [0, 1, 5, 6, 0, 1, 5, 19]))
	_rows(res, [
		["fallback slots are water", mini(MapPalette.RIVER_INDEX, MapPalette.SEA_INDEX) >= BakePalette.WATER_BASE, true],
		["shader water threshold", shader.contains("PALETTE_WATER_MIN = 128"), true],
		["water plane matches deep sea", close, true],
		["palette and cell_color baked together", baked, ResourceLoader.exists(CELL_PATH)],
		["palette switch follows the bake", MapPalette.color_of(1).to_html(false) + " " + MapPalette.color_of(255).to_html(false),
			want1 + " " + c.to_html(false)],
		["grey level fallback", Array(grey.get_data()), [255, 254, 5, 6, 255, 254, 5, 19]],
		["Baked/ under disk cap", BakeBudgetCheck.dir_bytes(MapData.BAKED_DIR) <= MapConst.BAKED_CAP_BYTES, true],
		["cell_color VRAM", MapConst.BLOCKS_X * MapConst.BLOCKS_Y == VRAM_BYTES and VRAM_BYTES <= 4404019, true],
	])
	if MapTestFixtures.require_baked(res, "block_level"):
		var tex: Texture2D = MapData.cell_index_texture()
		var size: String = "null" if tex == null else "%dx%d" % [tex.get_width(), tex.get_height()]
		_rows(res, [["cell index texture size", size, "%dx%d" % [MapConst.BLOCKS_X, MapConst.BLOCKS_Y]]])

static func _case_real(res: Dictionary) -> void:
	var cell: Image = ResourceLoader.load(CELL_PATH) as Image if ResourceLoader.exists(CELL_PATH) else null
	if cell == null:
		print("SKIP real bake | cell_color.res not baked")
		return
	var d: PackedByteArray = cell.get_data()
	var magma_n: int = d.count(60) + d.count(61) + d.count(62)
	_rows(res, [
		["real magma blocks", magma_n >= 1 and magma_n <= 80, true],
		["real reserved blocks", d.count(127) <= 24, true], ["empty blocks bounded", d.count(126) <= 30, true],
	])
