@tool
class_name BakeCellColor extends MapBakeStep

#Resolves one palette index per 2 px block from the land and water colour layers; Magma wins, water blocks read water first.
#cell_color is R8 at block size. Px order inside a block: centre, then (x0,y0), (x0+1,y0), (x0,y0+1).

const STAGE := 2
const LAND_KEY := "src/map-color-land.png"
const WATER_KEY := "src/map-color-water.png"
const RESERVED_HEX := "#1a1616"
const OPAQUE: int = 128
const UNMATCHED_TO_RESERVED := false
const TOP_HEX: int = 8


func _init() -> void:
	step_name = &"BakeCellColor"
	stage = STAGE
	inputs = PackedStringArray([LAND_KEY, WATER_KEY, "palette_table", "block_level", "river_mask"])
	optional = PackedStringArray(["pond_mask"])
	outputs = PackedStringArray(["cell_color"])


func run(ctx: MapBakeContext) -> bool:
	var land: Image = ctx.get_image(LAND_KEY)
	var water: Image = ctx.get_image(WATER_KEY)
	var levels: Image = ctx.get_image("block_level")
	var rivers: Image = ctx.get_image("river_mask")
	var table: Variant = ctx.get_value("palette_table")
	var pond: Image = ctx.get_image("pond_mask")
	var absent: PackedStringArray = PackedStringArray()
	for pair: Array in [[land, LAND_KEY], [water, WATER_KEY], [levels, "block_level"], [rivers, "river_mask"],
			[table if table is Dictionary else null, "palette_table"]]:
		if pair[0] == null:
			absent.append(pair[1])
	if not absent.is_empty():
		return ctx.fail("BakeCellColor: %s missing" % ", ".join(absent))
	var half: Vector2i = land.get_size() / 2
	for img: Image in [water, levels, rivers] + ([pond] if pond != null else []):
		var want: Vector2i = land.get_size() if img == water else half
		if img.get_size() != want:
			return ctx.fail("BakeCellColor: size %s does not match %s" % [img.get_size(), want])
	if ((table as Dictionary).get("hex", {}) as Dictionary).is_empty():
		return ctx.fail("BakeCellColor: palette_table has no colours")
	var res: Dictionary = color_blocks(land, water, levels, rivers, table, pond)
	ctx.put_image("cell_color", res["image"], true)
	var un: Array = [res["unmatched_land"], res["unmatched_water"]]
	var reserved_px: int = int(un[0].get(RESERVED_HEX, 0)) + int(un[1].get(RESERVED_HEX, 0))
	ctx.log(("BakeCellColor: %d blocks, %d water, %d magma, %d reserved, empty blocks: %d; partial alpha land %d px, "
		+ "water %d px; #1a1616 %d px; unmatched land %s, water %s") % [half.x * half.y, res["water"], res["magma"],
		res["reserved"], res["empty"], res["partial_land"], res["partial_water"], reserved_px, _top(un[0]), _top(un[1])])
	if pond != null:
		ctx.log("BakeCellColor: %d pond blocks, %d without a slot" % [res["pond"], res["pond_unslotted"]])
	return not ctx.failed


static func index_of(rgb: Color, table: Dictionary, layer_base: int = -1) -> int:
	var key: String = "#%06x" % (rgb.to_rgba32() >> 8)
	var hex: Dictionary = table["hex"]
	if hex.has(key):
		return int(hex[key])
	if UNMATCHED_TO_RESERVED or key == RESERVED_HEX:
		return BakePalette.RESERVED_INDEX
	var src: Vector3i = Vector3i(rgb.r8, rgb.g8, rgb.b8)
	var best: int = BakePalette.RESERVED_INDEX
	var best_d: int = 1 << 40
	for k: String in hex:
		var index: int = int(hex[k])
		if layer_base >= 0 and (index >= BakePalette.WATER_BASE) != (layer_base == BakePalette.WATER_BASE):
			continue
		var c: int = k.substr(1).hex_to_int()
		var d: int = (Vector3i((c >> 16) & 255, (c >> 8) & 255, c & 255) - src).length_squared()
		if d < best_d or (d == best_d and index < best):
			best_d = d
			best = index
	return best


static func color_blocks(land: Image, water: Image, levels: Image, rivers: Image, table: Dictionary,
		pond: Image = null) -> Dictionary:
	var lc: Image = land.duplicate()
	var wc: Image = water.duplicate()
	lc.convert(Image.FORMAT_RGBA8)
	wc.convert(Image.FORMAT_RGBA8)
	var ld: PackedByteArray = lc.get_data()
	var wd: PackedByteArray = wc.get_data()
	var lv: PackedByteArray = levels.get_data()
	var rv: PackedByteArray = rivers.get_data()
	var pd: PackedByteArray = pond.get_data() if pond != null else PackedByteArray()
	var w: int = lc.get_width()
	var h: int = lc.get_height()
	var bw: int = w / 2
	var bh: int = h / 2
	var lut: Dictionary = {}
	for k: String in table["hex"]:
		lut[k.substr(1).hex_to_int()] = int(table["hex"][k])
	var magma: Array = table.get("magma", []).map(func(m: Variant) -> int: return int(m))
	var out: PackedByteArray = PackedByteArray()
	out.resize(bw * bh)
	var unmatched: Array = [{}, {}]
	var misses: Array = [{}, {}]
	var counts: Array = [0, 0, 0, 0, 0, 0]
	var li: PackedInt32Array = PackedInt32Array([-1, -1, -1, -1])
	var wi: PackedInt32Array = PackedInt32Array([-1, -1, -1, -1])
	for by: int in bh:
		var y0: int = by * 2
		var yc: int = mini(h - 1, y0 + 1)
		for bx: int in bw:
			var x0: int = bx * 2
			var xc: int = mini(w - 1, x0 + 1)
			var qs: Array = [(yc * w + xc) * 4, (y0 * w + x0) * 4, (y0 * w + x0 + 1) * 4, ((y0 + 1) * w + x0) * 4]
			for i: int in 4:
				li[i] = _px_index(ld, qs[i], lut, misses[0], table, 0, unmatched[0])
				wi[i] = _px_index(wd, qs[i], lut, misses[1], table, BakePalette.WATER_BASE, unmatched[1])
			var b: int = by * bw + bx
			var is_water: bool = lv[b] <= MapConst.LEVEL_WATER or rv[b] > 0
			var result: int = _pick(li, wi, is_water, magma)
			if not pd.is_empty() and pd[b] != 0:
				var slot: Array = (table.get("pond", {}) as Dictionary).get(str(pd[b]), [])
				counts[4] += 1
				counts[5] += 1 if slot.is_empty() else 0
				result = int(slot[1 if (bx * 7 + by * 13) % 5 == 0 else 0]) if not slot.is_empty() else result
			counts[0] += 1 if is_water else 0
			counts[1] += 1 if magma.has(result) and li.has(result) else 0
			counts[2] += 1 if result == BakePalette.RESERVED_INDEX else 0
			counts[3] += 1 if result == BakePalette.EMPTY_INDEX else 0
			out[b] = result
	return {"image": Image.create_from_data(bw, bh, false, Image.FORMAT_R8, out), "water": counts[0],
		"magma": counts[1], "reserved": counts[2], "empty": counts[3], "partial_land": _partial(ld),
		"partial_water": _partial(wd), "unmatched_land": unmatched[0], "unmatched_water": unmatched[1],
		"pond": counts[4], "pond_unslotted": counts[5]}


static func _px_index(rgba: PackedByteArray, q: int, lut: Dictionary, misses: Dictionary, table: Dictionary,
		base: int, unmatched: Dictionary) -> int:
	if rgba[q + 3] < OPAQUE:
		return -1
	var key: int = (rgba[q] << 16) | (rgba[q + 1] << 8) | rgba[q + 2]
	var hit: int = lut.get(key, -1)
	if hit >= 0:
		return hit
	unmatched["#%06x" % key] = int(unmatched.get("#%06x" % key, 0)) + 1
	if not misses.has(key):
		misses[key] = index_of(Color8(rgba[q], rgba[q + 1], rgba[q + 2]), table, base)
	return misses[key]


static func _pick(li: PackedInt32Array, wi: PackedInt32Array, is_water: bool, magma: Array) -> int:
	for v: int in li:
		if magma.has(v):
			return v
	for v: int in (wi + li if is_water else li + wi):
		if v >= 0:
			return v
	return BakePalette.EMPTY_INDEX


static func _partial(rgba: PackedByteArray) -> int:
	var n: int = 0
	for q: int in range(3, rgba.size(), 4):
		n += 1 if rgba[q] >= OPAQUE and rgba[q] < 255 else 0
	return n


static func _top(px: Dictionary) -> String:
	var keys: Array = px.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return px[a] > px[b] or (px[a] == px[b] and a < b))
	var parts: PackedStringArray = PackedStringArray()
	for i: int in mini(TOP_HEX, keys.size()):
		parts.append("%s=%d" % [keys[i], px[keys[i]]])
	var total: int = px.values().reduce(func(n: int, v: Variant) -> int: return n + int(v), 0)
	return "%d px [%s]" % [total, ", ".join(parts)]
