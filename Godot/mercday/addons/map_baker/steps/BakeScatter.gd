@tool
class_name BakeScatter extends MapBakeStep

#Scatter passes in JS order (C12, MC:945-1037): ice mountain, lattice with ponds, fill, water, river, bank.
#Positions are image px (S1); land and water codes come by exact hex through BakePalette.pack in memory (S2).

const STAGE := 3
const CS: int = 8
const REASONS: PackedStringArray = ["no_zone", "density", "blocked", "spread", "filter_missing", "missing_kit"]


func _init() -> void:
	step_name = &"BakeScatter"
	stage = STAGE
	inputs = PackedStringArray(["scatter_rules", BakeCellColor.LAND_KEY, BakeCellColor.WATER_KEY, BakePalette.LAND_KEY,
		BakePalette.WATER_KEY, "block_level", "block_nation", "river_mask", "src/map-region.png", "src/map-region.json",
		"src/map-label-points.json", "rail_mask"])
	optional = PackedStringArray(["occupancy", "paint"])
	outputs = PackedStringArray(["place_foliage", "scatter_occ", "pond_mask", "pond_keys"])


func run(ctx: MapBakeContext) -> bool:
	var rules: Variant = ctx.get_value("scatter_rules")
	var land: Variant = ctx.get_value(BakePalette.LAND_KEY)
	var water: Variant = ctx.get_value(BakePalette.WATER_KEY)
	var region: Variant = ctx.get_value("src/map-region.json")
	var labels: Variant = ctx.get_value("src/map-label-points.json")
	var land_img: Image = ctx.get_image(BakeCellColor.LAND_KEY)
	var water_img: Image = ctx.get_image(BakeCellColor.WATER_KEY)
	var levels: Image = ctx.get_image("block_level")
	var nation: Image = ctx.get_image("block_nation")
	var region_img: Image = ctx.get_image("src/map-region.png")
	if not (rules is Dictionary) or not (land is Dictionary) or not (water is Dictionary) or not (region is Dictionary):
		return ctx.fail("BakeScatter: scatter_rules, palette or region json missing")
	if land_img == null or water_img == null or levels == null or nation == null or region_img == null:
		return ctx.fail("BakeScatter: colour, level, nation or region image missing")
	if land_img.get_size() != levels.get_size() * 2 or water_img.get_size() != land_img.get_size():
		return ctx.fail("BakeScatter: colour images are not twice block_level")
	var table: Dictionary = BakePalette.pack(land, water)["table"]
	var land_codes: PackedByteArray = codes(land_img, table, false)
	var water_codes: PackedByteArray = codes(water_img, table, true)
	var placed: MapPlacementSet = MapPlacementSet.new()
	var grid: ScatterGrid = ScatterGrid.new()
	grid.setup(levels, ctx.get_image("river_mask"), ctx.get_image("rail_mask"), ctx.get_image("occupancy"),
		ctx.get_image("paint"), rules, placed)
	var zones: ScatterZones = ScatterZones.new()
	zones.setup(rules, land_codes, nation, region_img, region, labels if labels is Dictionary else {})
	var ponds: ScatterPonds = ScatterPonds.new()
	ponds.setup(grid, water_codes, water_rgb(rules))
	var sw: ScatterWater = ScatterWater.new()
	sw.setup(grid, water_codes)
	sw.ice_mountain()
	var zc: Dictionary = {}
	var skip: Dictionary = {"no_zone": 0, "density": 0}
	lattice(grid, zones, ponds, land_codes, zc, skip)
	fill(grid, zones, zc)
	sw.water()
	sw.river()
	ctx.put_image("scatter_occ", grid.to_image(), true)
	ctx.put_image("pond_mask", ponds.mask_image(), true)
	ctx.put_value("place_foliage", placed)
	var err: Error = ResourceSaver.save(placed, ctx.path_of("place_foliage"))
	if err != OK:
		return ctx.fail("BakeScatter: cannot save place_foliage (error %d)" % err)
	var keys: Array[int] = ponds.keys()
	ctx.put_value("pond_keys", keys)
	var file: FileAccess = FileAccess.open(ctx.path_of("pond_keys.json"), FileAccess.WRITE)
	if file == null:
		return ctx.fail("BakeScatter: cannot write pond_keys.json")
	file.store_string(JSON.stringify(keys, "", false, true))
	if file.get_error() != OK:
		file.close()
		return ctx.fail("BakeScatter: write failed pond_keys.json")
	file.close()
	var names: Array = zc.keys()
	names.sort()
	for zk: Variant in names:
		ctx.log("scatter zone %s placed %d" % [zk, zc[zk]])
	skip.merge(grid.counts)
	skip["filter_missing"] = int(zones.counts.get("filter_missing", 0))
	for reason: String in REASONS:
		ctx.log("scatter skipped %s %d" % [reason, int(skip.get(reason, 0))])
	for key: String in ["ice_mountain", "water", "river"]:
		ctx.log("scatter %s %d" % [key, int(sw.counts[key])])
	var pc: Dictionary = ponds.counts
	ctx.log("scatter ponds wet %d mud %d reeds %d lilies %d overflow %d" % [pc["wet"], pc["mud"], pc["reeds"],
		pc["lilies"], pc["overflow"]])
	return not ctx.failed


#Land code = palette index, water code = index - 128 (A30); 255 when alpha < 128 or no exact hex match.
static func codes(img: Image, table: Dictionary, water: bool) -> PackedByteArray:
	var lut: Dictionary = {}
	var hex: Dictionary = table.get("hex", {})
	for key: Variant in hex:
		var idx: int = int(hex[key])
		if (idx >= BakePalette.WATER_BASE) == water:
			var col: Color = Color(String(key))
			lut[(col.r8 << 16) | (col.g8 << 8) | col.b8] = idx - BakePalette.WATER_BASE * int(water)
	var c: Image = img
	if img.get_format() != Image.FORMAT_RGBA8:
		c = img.duplicate()
		c.convert(Image.FORMAT_RGBA8)
	var data: PackedByteArray = c.get_data()
	var out: PackedByteArray = PackedByteArray()
	out.resize(c.get_width() * c.get_height())
	out.fill(255)
	var last: int = -1
	var code: int = 255
	for i: int in out.size():
		var q: int = i * 4
		if data[q + 3] < BakeCellColor.OPAQUE:
			continue
		var rgb: int = (data[q] << 16) | (data[q + 1] << 8) | data[q + 2]
		if rgb != last:
			last = rgb
			code = int(lut.get(rgb, 255))
		out[i] = code
	return out


static func water_rgb(rules: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for row: Variant in rules.get("water_palette", []):
		var rgb: Array = (row as Dictionary).get("rgb", [0, 0, 0])
		out[int((row as Dictionary)["code"])] = Color8(int(rgb[0]), int(rgb[1]), int(rgb[2]))
	return out


#Zone counter key as MC:999: the zone name for FOLIAGE_ZONES rows, "class" for class_<cls> and jungle rows.
static func zone_key(rules: Dictionary, zi: int) -> String:
	var zones: Array = rules.get("zones", [])
	for i: int in mini(zi + 1, zones.size()):
		if String((zones[i] as Dictionary).get("name", "")).begins_with("class_"):
			return "class"
	return String((zones[zi] as Dictionary).get("name", ""))


static func lattice(grid: ScatterGrid, zones: ScatterZones, ponds: ScatterPonds, land: PackedByteArray, zc: Dictionary,
		skip: Dictionary) -> void:
	var trees: Array = grid.rules.get("trees", [])
	for z: int in range(3, grid.h - 3, 6):
		for x: int in range(3, grid.w - 3, 6):
			var jx: int = jitter(x, z).x
			var jz: int = jitter(x, z).y
			var j: int = grid.j_at(jx, jz)
			if not grid.free_at(j) or grid.near_at(j):
				continue
			var code: int = land[jz * grid.w + jx]
			if code == 255:
				continue
			var zr: Dictionary = zones.zone_at(jx, jz, code)
			if zr.is_empty():
				skip["no_zone"] = int(skip["no_zone"]) + 1
				continue
			var d: float = float(zr["dDark"]) if zr.has("dDark") and (code & 3) == 2 else float(zr.get("d", 0.0))
			var c: float = float(zr.get("c", 0.0))
			if MapRng.hh(jx * 3 + 1, jz * 5 + 2) > d * (1.0 - c + c * 2.0 * MapRng.vn(jx / 70.0, jz / 70.0)):
				skip["density"] = int(skip["density"]) + 1
				continue
			var zi: int = int(zr["zi"])
			var id: String = String(MapRng.pick(zr["kits"], MapRng.hh(jx + 13, jz + 29)))
			var ok: bool = false
			if id == "p_pond" or id == "p_mudpit":
				ok = ponds.carve(jx, jz, id == "p_pond", zi)
			else:
				if trees.has(id):
					id += "#%d" % floori(MapRng.hh(jx + 41, jz + 7) * 5)
				ok = grid.prop(StringName(id), jx, jz, zi)
			if ok:
				var zk: String = zone_key(grid.rules, zi)
				zc[zk] = int(zc.get(zk, 0)) + 1


static func jitter(x: int, z: int) -> Vector2i:
	return Vector2i(x + floori(MapRng.hh(x + 7, z + 3) * 5) - 2, z + floori(MapRng.hh(x, z + 11) * 5) - 2)


#Fill lattice over each zone's near mask (8 px cells), then over each zone's segment box (MC:1003-1010).
static func fill(grid: ScatterGrid, zones: ScatterZones, zc: Dictionary) -> void:
	var rows: Array = grid.rules.get("zones", [])
	var cw: int = ceili(float(grid.w) / float(CS))
	for pass_seg: bool in [false, true]:
		for zi: int in rows.size():
			var f: Variant = (rows[zi] as Dictionary).get("fill")
			if not (f is Dictionary):
				continue
			var key: String = String((rows[zi] as Dictionary).get("name", "")) + "_fill"
			var step: int = maxi(1, int((f as Dictionary).get("step", 1)))
			var boxes: Array[Rect2i] = []
			var sg: Dictionary = zones.seg_of(zi) if pass_seg else {}
			if not sg.is_empty():
				var a: Vector2 = sg["a"]
				var b: Vector2 = sg["b"]
				var w: float = float(sg["w"])
				var x0: int = int(maxf(3.0, minf(a.x, b.x) - w))
				var z0: int = int(maxf(3.0, minf(a.y, b.y) - w))
				boxes.append(Rect2i(x0, z0, int(minf(grid.w - 3, maxf(a.x, b.x) + w)) - x0,
					int(minf(grid.h - 3, maxf(a.y, b.y) + w)) - z0))
			elif not pass_seg:
				var near: PackedByteArray = zones.near_mask(zi)
				for ci: int in near.size():
					if near[ci] != 0:
						boxes.append(Rect2i((ci % cw) * CS, floori(float(ci) / float(cw)) * CS, CS, CS))
			for r: Rect2i in boxes:
				for z: int in range(r.position.y, r.end.y, step):
					for x: int in range(r.position.x, r.end.x, step):
						if not sg.is_empty() and seg_d(Vector2(x, z), sg) > float(sg["w"]):
							continue
						if fill_one(grid, f, x, z, zi):
							zc[key] = int(zc.get(key, 0)) + 1


static func fill_one(grid: ScatterGrid, f: Dictionary, x: int, z: int, zi: int) -> bool:
	if x < 3 or z < 3 or x >= grid.w - 3 or z >= grid.h - 3 or MapRng.hh(x * 5 + 3, z * 3 + 7) > float(f.get("d", 0.0)):
		return false
	if not grid.free_at(grid.j_at(x, z)):
		return false
	return grid.prop(StringName(String(MapRng.pick(f["k"], MapRng.hh(x + 3, z + 5)))), x, z, zi)


static func seg_d(p: Vector2, sg: Dictionary) -> float:
	var a: Vector2 = sg["a"]
	var v: Vector2 = Vector2(sg["b"]) - a
	var l2: float = v.length_squared() if v.length_squared() != 0.0 else 1.0
	var f: float = clampf((p - a).dot(v) / l2, 0.0, 1.0)
	return (p - a - v * f).length()
