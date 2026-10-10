@tool
class_name BakeHeightRivers extends MapBakeStep

#Marks river and lake blocks from the water colour layer on blocks that are not sea.
#river_mask is R8 per 2 px block: 0 none, 1 river, 2 lake or pond. Water px that are sea px are not counted.
#A block also counts when its centre px has opaque water over transparent land (map-core wcol).

const STAGE := 1
const WATER_KEY := "src/map-color-water.png"
const LAND_KEY := "src/map-color-land.png"
const PALETTE_KEY := "src/map-water-palette.json"
const SEA_KEY := "sea_frac"
const SEA_BYTE: int = 128
const MIN_WATER_PX: int = 2
const MASK_RIVER: int = 1
const MASK_LAKE: int = 2


func _init() -> void:
	step_name = &"BakeHeightRivers"
	inputs = PackedStringArray([SEA_KEY, WATER_KEY, LAND_KEY, PALETTE_KEY])
	outputs = PackedStringArray(["river_mask"])


func run(ctx: MapBakeContext) -> bool:
	var water: Image = ctx.get_image(WATER_KEY)
	var land_img: Image = ctx.get_image(LAND_KEY)
	var sea_img: Image = ctx.get_image(SEA_KEY)
	var palette: Variant = ctx.get_value(PALETTE_KEY)
	if water == null or land_img == null or sea_img == null or not (palette is Dictionary):
		return ctx.fail("BakeHeightRivers: water layer, land layer, palette or sea_frac missing")
	if water.get_format() != Image.FORMAT_RGBA8:
		water.convert(Image.FORMAT_RGBA8)
	if land_img.get_format() != Image.FORMAT_RGBA8:
		land_img.convert(Image.FORMAT_RGBA8)
	if land_img.get_size() != water.get_size():
		return ctx.fail("BakeHeightRivers: land and water layers differ in size")
	var land: PackedByteArray = land_img.get_data()
	var lake: Dictionary = _lake_colors(palette as Dictionary)
	var rgba: PackedByteArray = water.get_data()
	var sea: PackedByteArray = sea_img.get_data()
	var w: int = water.get_width()
	var h: int = water.get_height()
	var bw: int = sea_img.get_width()
	var bh: int = sea_img.get_height()
	var out: PackedByteArray = PackedByteArray()
	out.resize(bw * bh)
	var rivers: int = 0
	var lakes: int = 0
	for by: int in bh:
		for bx: int in bw:
			var b: int = by * bw + bx
			if sea[b] >= SEA_BYTE:
				continue
			var o: int = (by * 2 * w + bx * 2) * 4
			var n: int = 0
			var is_lake: bool = false
			for q: int in [o, o + 4, o + w * 4, o + w * 4 + 4]:
				if rgba[q + 3] < 128:
					continue
				n += 1
				var key: int = (rgba[q] << 16) | (rgba[q + 1] << 8) | rgba[q + 2]
				is_lake = is_lake or lake.has(key)
			n -= roundi(sea[b] * 4.0 / 255.0)
			var c: int = (mini(h - 1, by * 2 + 1) * w + mini(w - 1, bx * 2 + 1)) * 4
			var wcol: bool = land[c + 3] < 128 and rgba[c + 3] >= 128
			if n < MIN_WATER_PX and not wcol:
				continue
			out[b] = MASK_LAKE if is_lake else MASK_RIVER
			if is_lake:
				lakes += 1
			else:
				rivers += 1
	ctx.put_image("river_mask", Image.create_from_data(bw, bh, false, Image.FORMAT_R8, out), true)
	ctx.log("BakeHeightRivers: %d river blocks, %d lake blocks" % [rivers, lakes])
	return true


#Colours of the lake classes (Lake and its Icy, Murky and Violet variants) as packed 0xRRGGBB keys.
func _lake_colors(palette: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var lookup: Dictionary = palette.get("lookup", {})
	for hex: String in lookup:
		var cls: String = String((lookup[hex] as Dictionary).get("class", "")).to_lower()
		if cls.ends_with("lake"):
			out[hex.trim_prefix("#").hex_to_int()] = true
	return out
