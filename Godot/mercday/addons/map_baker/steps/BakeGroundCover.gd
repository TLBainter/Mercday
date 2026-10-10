@tool
class_name BakeGroundCover extends MapBakeStep

#Ground clumps and sea ice (C13, MC:1262-1301) into place_ground; KIND and DENS fixed here, ice from gs_ice (E40).

const STAGE := 3
const KIND: Dictionary = {0: "grass", 1: "grass", 2: "grass", 3: "grass", 4: "grass", 5: "sand", 6: "gravel",
	7: "gravel", 8: "snow", 9: "grass", 10: "sand", 11: "grass", 12: "grass", 13: "wheat", 14: "gravel"}
const DENS: Dictionary = {"grass": 0.8, "sand": 0.5, "gravel": 0.6, "snow": 0.65, "wheat": 0.95}
const GKI: Dictionary = {"grass": 0, "flowers": 1, "gravel": 2, "sand": 3, "wheat": 4, "snow": 5}
const D_FOREST: float = 0.35
const FLOWER_P: float = 0.12
const MEADOW_P: float = 0.4
const ICE_FP: Array[Vector2i] = [Vector2i(9, 6), Vector2i(16, 11), Vector2i(18, 4), Vector2i(11, 7), Vector2i(10, 8),
	Vector2i(6, 5), Vector2i(17, 9)]
const ICE_NORTH: float = 0.55
const W0: Color = Color(0.97, 0.99, 1.0)

var _grid: ScatterGrid
var _sw: ScatterWater
var _socc: PackedByteArray = PackedByteArray()
var _region_img: Image
var _meadow_hit: Dictionary = {}
var _water_img: Image


func _init() -> void:
	step_name = &"BakeGroundCover"
	stage = STAGE
	inputs = PackedStringArray([BakeCellColor.LAND_KEY, BakeCellColor.WATER_KEY, "palette_table", "block_level",
		"block_nation", "river_mask", "scatter_occ", "scatter_rules", "src/map-region.png", "src/map-region.json",
		"rail_mask"])
	optional = PackedStringArray(["occupancy", "paint"])
	outputs = PackedStringArray(["place_ground"])


func run(ctx: MapBakeContext) -> bool:
	var table: Variant = ctx.get_value("palette_table")
	var rules: Variant = ctx.get_value("scatter_rules")
	var region: Variant = ctx.get_value("src/map-region.json")
	var land_img: Image = ctx.get_image(BakeCellColor.LAND_KEY)
	_water_img = ctx.get_image(BakeCellColor.WATER_KEY)
	var levels: Image = ctx.get_image("block_level")
	var socc_img: Image = ctx.get_image("scatter_occ")
	_region_img = ctx.get_image("src/map-region.png")
	if not (table is Dictionary) or not (rules is Dictionary) or not (region is Dictionary):
		return ctx.fail("BakeGroundCover: palette_table, scatter_rules or region json missing")
	if land_img == null or _water_img == null or levels == null or socc_img == null or _region_img == null:
		return ctx.fail("BakeGroundCover: colour, level, scatter_occ or region image missing")
	if (land_img.get_size() != levels.get_size() * 2 or socc_img.get_size() != levels.get_size()
			or _region_img.get_size() != land_img.get_size()):
		return ctx.fail("BakeGroundCover: image sizes do not match block_level")
	_grid = ScatterGrid.new()
	_grid.setup(levels, ctx.get_image("river_mask"), ctx.get_image("rail_mask"), ctx.get_image("occupancy"),
		ctx.get_image("paint"), rules, MapPlacementSet.new())
	_sw = ScatterWater.new()
	_sw.setup(_grid, PackedByteArray())
	_socc = ScatterGrid.bytes_of(socc_img, _grid.rw, _grid.rh)
	var land: PackedByteArray = BakeScatter.codes(land_img, table, false)
	var skip: Dictionary = {}
	_meadow_hit = _meadow(region, rules)
	var n: int = ground(land, _land_rgb(table), PackedByteArray(), skip)
	var ni: int = ice(PackedByteArray(), table)
	ctx.put_value("place_ground", _grid.set)
	var err: Error = ResourceSaver.save(_grid.set, ctx.path_of("place_ground"))
	if err != OK:
		return ctx.fail("BakeGroundCover: cannot save place_ground (error %d)" % err)
	ctx.log("ground placed %d" % n)
	for reason: String in ["water", "occupied", "kind", "density"]:
		ctx.log("ground skipped %s %d" % [reason, int(skip.get(reason, 0))])
	ctx.log("ice placed %d" % ni)
	return not ctx.failed


#Per px meadow flags; when empty, _region_img is read at kept grass px against _meadow_hit.
func ground(land: PackedByteArray, rgb: Dictionary, meadow: PackedByteArray, skip: Dictionary) -> int:
	var g: ScatterGrid = _grid
	var t: float = MapConst.TERRACE
	var n: int = 0
	for cz: int in range(2, g.rh - 2):
		for cx: int in range(2, g.rw - 2):
			var j: int = cz * g.rw + cx
			var reason: String = ""
			if g.lvl[j] <= MapConst.LEVEL_WATER or _sw.is_riv(j):
				reason = "water"
			elif (_socc[j] != 0 or g.occ[j] != 0 or g.paint[j] != 0 or g.rail[j] == 2 or g.rail[j - 1] == 2
					or g.rail[j + 1] == 2 or g.rail[j - g.rw] == 2 or g.rail[j + g.rw] == 2):
				reason = "occupied"
			if not reason.is_empty():
				skip[reason] = int(skip.get(reason, 0)) + 1
				continue
			var px: int = cx * 2 + floori(MapRng.hh(cx, cz + 1) * 2)
			var pz: int = cz * 2 + floori(MapRng.hh(cx + 1, cz) * 2)
			var code: int = land[pz * g.w + px]
			var cls: int = code >> 2
			var kind: String = String(KIND.get(cls, ""))
			if kind.is_empty():
				reason = "kind"
			elif MapRng.hh(cx * 3 + 11, cz * 7 + 5) > (D_FOREST if cls >= 2 and cls <= 4 else float(DENS[kind])):
				reason = "density"
			if not reason.is_empty():
				skip[reason] = int(skip.get(reason, 0)) + 1
				continue
			var v: int = floori(MapRng.hh(cx + 17, cz + 23) * 12)
			var mh: bool = kind == "grass" and ((meadow[pz * g.w + px] != 0) if not meadow.is_empty() else (
				_region_img != null and _meadow_hit.has(_region_img.get_pixel(px, pz).to_rgba32() >> 8)))
			var fp: float = 0.0 if kind != "grass" else (MEADOW_P if mh else (FLOWER_P * 2.0
				if (cls == 0 and (code & 3) == 0) or cls == 12 else (FLOWER_P if cls == 0 else 0.0)))
			var vk: String = "flowers" if kind == "grass" and MapRng.hh(cx + 29, cz + 31) < fp else kind
			var m: int = 1 if MapRng.hh(cx + 61, cz + 67) < 0.5 else 0
			var y: float = MapSpace.height_to_y(maxf(MapConst.WATER_H + t, MapRng.jround(g.hgt[j] / t) * t)) + 0.02
			var pos: Vector3 = Vector3(cx * 2 + 1 + (MapRng.hh(cx + 5, cz + 3) - 0.5) * 0.6, y,
				cz * 2 + 1 + (MapRng.hh(cx + 2, cz + 9) - 0.5) * 0.6)
			g.set.add(StringName("g/%s/%d/%d" % [vk, v, m]), pos, 0.0, 1.0, Vector4i.ZERO, int(GKI[vk]), rgb.get(code, Color.WHITE))
			n += 1
	return n


#Sea ice (MC:1289-1293); y is WATER_H * hs - 0.4 as MC:1289; when water is empty, _water_img is read per sample.
func ice(water: PackedByteArray, table: Dictionary) -> int:
	var g: ScatterGrid = _grid
	var gi: Dictionary = g.rules.get("gs_ice", {})
	var re: RegEx = ScatterGrid.regex_of(gi)
	var icy: Dictionary = {}
	var lut: Dictionary = {}
	var wcl: Dictionary = table.get("water_classes", {})
	for cname: Variant in wcl:
		if re != null and re.search(String(cname)) != null:
			icy[(int(wcl[cname]) - BakePalette.WATER_BASE) >> 2] = true
	var hex: Dictionary = table.get("hex", {})
	for key: Variant in hex:
		if int(hex[key]) >= BakePalette.WATER_BASE:
			lut[Color(String(key)).to_rgba32() >> 8] = int(hex[key]) - BakePalette.WATER_BASE
	var n: int = 0
	var wy: float = MapSpace.height_to_y(MapConst.WATER_H) - 0.4
	var per_px: bool = not water.is_empty()
	for z: int in (range(0, g.h, 10) if not icy.is_empty() and (per_px or _water_img != null) else []):
		for x: int in range(0, g.w, 10):
			var jx: int = x + floori(MapRng.hh(x, z + 77) * 6)
			var jz: int = z + floori(MapRng.hh(x + 77, z) * 6)
			if jx >= g.w or jz >= g.h:
				continue
			var dense: bool = jz < MapConst.PAD_T + int(gi.get("denseZ", 0))
			var col: Color = Color.TRANSPARENT if dense or per_px else _water_img.get_pixel(jx, jz)
			var c: int = water[jz * g.w + jx] if per_px else (255 if col.a8 < BakeCellColor.OPAQUE
				else int(lut.get(col.to_rgba32() >> 8, 255)))
			if not dense and (c == 255 or not icy.has(c >> 2)):
				continue
			var f: float = maxf(0.0, 1.0 - float(jz) / (g.h * ICE_NORTH))
			var p: float = float(gi["denseP"]) if dense else float(gi["p0"]) + float(gi["p1"]) * pow(f, 1.5)
			if MapRng.hh(jx * 3, jz * 5 + 1) > p:
				continue
			var ty: int = floori(MapRng.hh(jx + 9, jz + 3) * 7)
			var ok: bool = true
			for a: float in [-0.5, 0.0, 0.5]:
				for b: float in [-0.5, 0.0, 0.5]:
					ok = ok and _open(int(MapRng.jround(jx + a * ICE_FP[ty].x)), int(MapRng.jround(jz + b * ICE_FP[ty].y)))
			if ok:
				g.set.add(StringName("ice/%d" % ty), Vector3(jx, wy, jz), 0.0, 1.0, Vector4i.ZERO, -1, W0)
				n += 1
	return n


func _open(x: int, z: int) -> bool:
	if x < 0 or z < 0 or x >= _grid.w or z >= _grid.h:
		return false
	var j: int = mini(_grid.rh - 1, z >> 1) * _grid.rw + mini(_grid.rw - 1, x >> 1)
	return _grid.lvl[j] <= MapConst.LEVEL_WATER and not _sw.is_riv(j) and _socc[j] == 0


static func _land_rgb(table: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var hex: Dictionary = table.get("hex", {})
	for key: Variant in hex:
		if int(hex[key]) < BakePalette.WATER_BASE:
			out[int(hex[key])] = Color(String(key))
	return out


#Region colours (rgb int) whose category is in meadow_cat (array per E20; a {re, flags} dict also works).
static func _meadow(region: Dictionary, rules: Dictionary) -> Dictionary:
	var cats: Variant = rules.get("meadow_cat", [])
	var re: RegEx = ScatterGrid.regex_of(cats)
	var hit: Dictionary = {}
	for r: Variant in region.get("regions", []):
		var cat: String = String((r as Dictionary).get("category", ""))
		if (cats is Array and (cats as Array).has(cat)) or (re != null and re.search(cat) != null):
			hit[Color.html(String((r as Dictionary)["color"])).to_rgba32() >> 8] = true
	return hit
