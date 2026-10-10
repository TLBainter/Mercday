@tool
class_name BakeHeightBlocks extends MapBakeStep

#Resolves one level code per 2 px block from height, sea fraction and river mask; codes follow MapSpace.
#Sea blocks (sea_frac >= 0.5) are SEA_BED; river and lake blocks sit one terrace under the land floor.

const STAGE := 1
const HEIGHT_KEY := "src/map-height.png"
const SEA_KEY := "sea_frac"
const RIVER_KEY := "river_mask"
const SEA_BYTE: int = 128


func _init() -> void:
	step_name = &"BakeHeightBlocks"
	inputs = PackedStringArray([HEIGHT_KEY, SEA_KEY, RIVER_KEY])
	outputs = PackedStringArray(["block_level"])


func run(ctx: MapBakeContext) -> bool:
	var img: Image = ctx.get_image(HEIGHT_KEY)
	var sea_img: Image = ctx.get_image(SEA_KEY)
	var river_img: Image = ctx.get_image(RIVER_KEY)
	if img == null or sea_img == null or river_img == null:
		return ctx.fail("BakeHeightBlocks: height, sea_frac or river_mask missing")
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var rgba: PackedByteArray = img.get_data()
	var sea: PackedByteArray = sea_img.get_data()
	var river: PackedByteArray = river_img.get_data()
	var w: int = img.get_width()
	var bw: int = sea_img.get_width()
	var bh: int = sea_img.get_height()
	var out: PackedByteArray = PackedByteArray()
	out.resize(bw * bh)
	var census: Dictionary = {}
	var rivers: int = 0
	for by: int in bh:
		for bx: int in bw:
			var b: int = by * bw + bx
			var level: int = MapConst.LEVEL_SEA
			if sea[b] < SEA_BYTE:
				var o: int = (by * 2 * w + bx * 2) * 4
				level = block_level(_land_mean(rgba, o, w, sea[b] > 0), river[b] != 0)
				rivers += 1 if river[b] != 0 else 0
			out[b] = level
			census[level] = int(census.get(level, 0)) + 1
	ctx.put_image("block_level", Image.create_from_data(bw, bh, false, Image.FORMAT_R8, out), true)
	var sea_blocks: int = int(census.get(MapConst.LEVEL_SEA, 0))
	var counts: Variant = ctx.get_value(MapBakeManifest.CENSUS_KEY)
	var merged: Dictionary = counts if counts is Dictionary else {}
	merged["blocks_sea"] = sea_blocks
	merged["blocks_river"] = rivers
	merged["blocks_land"] = bw * bh - sea_blocks - rivers
	merged["block_levels"] = census.keys().filter(func(k: int) -> bool: return k > MapConst.LEVEL_WATER).size()
	ctx.put_value(MapBakeManifest.CENSUS_KEY, merged)
	ctx.log("BakeHeightBlocks: %d levels %s" % [census.size(), str(census)])
	return true


#Level code of a land or water block with mean land height hv (0..1).
static func block_level(hv: float, is_river: bool) -> int:
	var t: float = MapConst.TERRACE
	if is_river:
		return MapSpace.height_to_level(maxf(MapConst.WATER_H, floorf(hv / t) * t - t))
	return level_of(hv)


static func level_of(h: float) -> int:
	var terraced: float = roundf(h / MapConst.TERRACE) * MapConst.TERRACE
	return MapSpace.height_to_level(maxf(MapConst.WATER_H + MapConst.TERRACE, terraced))


#Mean R/255 over the 2x2 px at byte offset o; with coast set, px at the sea grey are skipped.
func _land_mean(rgba: PackedByteArray, o: int, w: int, coast: bool) -> float:
	var o2: int = o + w * 4
	var r0: int = rgba[o]
	var r1: int = rgba[o + 4]
	var r2: int = rgba[o2]
	var r3: int = rgba[o2 + 4]
	if not coast:
		return float(r0 + r1 + r2 + r3) / 1020.0
	var g: int = MapConst.SEA_GRAY
	var n: int = int(r0 != g) + int(r1 != g) + int(r2 != g) + int(r3 != g)
	var sum: int = (r0 if r0 != g else 0) + (r1 if r1 != g else 0) + (r2 if r2 != g else 0) + (r3 if r3 != g else 0)
	if n == 0:
		return MapConst.WATER_H
	return float(sum) / float(n) / 255.0
