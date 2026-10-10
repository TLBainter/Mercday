@tool
class_name BakePalette extends MapBakeStep

#Packs the land and water class palettes into one 256x1 colour strip and writes the name and hex to index table.
#Land index = id * 4 + tone; water index = WATER_BASE + id * 4 + tone; tones are light, base, dark.

const STAGE := 2
const LAND_KEY := "src/map-color-palette.json"
const WATER_KEY := "src/map-water-palette.json"
const WATER_BASE := 128
const DEEP_SEA_INDEX := 255
const RESERVED_INDEX := 127
const EMPTY_INDEX := 126
const RESERVED_COLOR := Color8(255, 0, 255)
const EMPTY_COLOR := Color8(110, 110, 110)
const TONES: PackedStringArray = ["light", "base", "dark"]
const MAX_ID := 30
const MISSING_USE_CLASS_COLOR := true
const POND_RGB: Array[Color] = [Color8(86, 62, 40), Color8(70, 50, 32), Color8(60, 100, 120)]


func _init() -> void:
	step_name = &"BakePalette"
	stage = STAGE
	inputs = PackedStringArray([LAND_KEY, WATER_KEY])
	optional = PackedStringArray(["pond_keys"])
	outputs = PackedStringArray(["palette", "palette_table"])


func run(ctx: MapBakeContext) -> bool:
	var land: Variant = ctx.get_value(LAND_KEY)
	var water: Variant = ctx.get_value(WATER_KEY)
	if not (land is Dictionary) or not (water is Dictionary):
		return ctx.fail("BakePalette: palette json missing")
	var res: Dictionary = pack(land, water)
	if not String(res["error"]).is_empty():
		return ctx.fail("BakePalette: " + String(res["error"]))
	for msg: String in res["warnings"]:
		ctx.log(msg)
	var keys: Array = ctx.get_value("pond_keys") if ctx.get_value("pond_keys") is Array else []
	if not keys.is_empty():
		ctx.log("BakePalette: %d pond keys, %d on mud slots" % [keys.size(), pond_slots(res["image"], res["table"], keys)])
	var table: Dictionary = res["table"]
	var gaps: PackedStringArray = PackedStringArray(table["missing"])
	var hex: Dictionary = table["hex"]
	var water_n: int = hex.values().filter(func(i: Variant) -> bool: return int(i) >= WATER_BASE).size()
	ctx.log("BakePalette: %d land, %d water colours; lookup lacks %s" % [hex.size() - water_n, water_n,
		", ".join(gaps) if not gaps.is_empty() else "none"])
	ctx.put_image("palette", res["image"], true)
	ctx.put_value("palette_table", table)
	var file: FileAccess = FileAccess.open(ctx.path_of("palette_table.json"), FileAccess.WRITE)
	if file == null:
		return ctx.fail("BakePalette: cannot write palette_table.json")
	file.store_string(JSON.stringify(table, "\t"))
	if file.get_error() != OK:
		file.close()
		return ctx.fail("BakePalette: write failed palette_table.json")
	file.close()
	return not ctx.failed


static func pack(land: Dictionary, water: Dictionary) -> Dictionary:
	var img: Image = Image.create_empty(256, 1, false, Image.FORMAT_RGBA8)
	img.fill(RESERVED_COLOR)
	img.set_pixel(EMPTY_INDEX, 0, EMPTY_COLOR)
	var hexes: Dictionary = {}
	var magma: Array = []
	var missing: Array = []
	var table: Dictionary = {"version": 1, "water_base": WATER_BASE, "deep_sea_index": DEEP_SEA_INDEX,
		"reserved_index": RESERVED_INDEX, "empty_index": EMPTY_INDEX, "classes": {}, "water_classes": {}, "hex": hexes,
		"magma": magma, "missing": missing}
	var warnings: PackedStringArray = PackedStringArray()
	var error: String = ""
	for layer: Array in [[land, 0, "classes"], [water, WATER_BASE, "water_classes"]]:
		var data: Dictionary = layer[0]
		var base: int = layer[1]
		var lookup: Dictionary = data.get("lookup", {})
		var covered: Array = lookup.values().map(func(r: Variant) -> String: return String((r as Dictionary).get("class", "")))
		var by_name: Dictionary = {}
		var classes: Array = data.get("classes", [])
		for c: Dictionary in classes:
			var id: int = int(c["id"])
			var cname: String = String(c["name"])
			by_name[cname] = c
			if id < 0 or id > MAX_ID:
				error = "class %s id %d is out of range" % [cname, id]
				continue
			table[layer[2]][cname] = base + id * 4 + 1
			var has_row: bool = covered.has(cname)
			if not has_row:
				missing.append(cname)
				if not MISSING_USE_CLASS_COLOR:
					warnings.append("BakePalette: %s has no lookup row; reserved colour until given" % cname)
			if base == WATER_BASE and id == 0 and Color(String(c["base"])) != MapConst.DEEP_SEA:
				warnings.append("BakePalette: water class 0 base %s is not #263e62" % String(c["base"]))
			for t: int in 3:
				var index: int = base + id * 4 + t
				var tone_hex: String = String(c[TONES[t]]).to_lower()
				if hexes.has(tone_hex):
					error = "duplicate colour %s" % tone_hex
				hexes[tone_hex] = index
				if has_row or MISSING_USE_CLASS_COLOR:
					img.set_pixel(index, 0, Color(tone_hex))
				if base == 0 and cname.to_lower() == "magma":
					magma.append(index)
		for key: String in lookup:
			var row: Dictionary = lookup[key]
			var cls: Variant = by_name.get(String(row.get("class", "")))
			var tone: String = String(row.get("tone", ""))
			if not (cls is Dictionary) or not TONES.has(tone):
				continue
			var class_hex: String = String((cls as Dictionary)[tone])
			if class_hex.to_lower() != key.to_lower():
				warnings.append("BakePalette: lookup %s is %s.%s, class says %s" % [key, row["class"], tone, class_hex])
	img.set_pixel(MapPalette.RIVER_INDEX, 0, MapPalette.RIVER_COLOR)
	img.set_pixel(DEEP_SEA_INDEX, 0, MapConst.DEEP_SEA)
	magma.sort()
	return {"image": img, "table": table, "warnings": warnings, "error": error}


#Gives each pond key, ascending, two free indices under EMPTY_INDEX (base, dark) and table "pond" its [base, dark].
#Short on slots: the mud pair is taken first and key 1 shares it with every key past the free slots; returns those keys.
static func pond_slots(img: Image, table: Dictionary, keys: Array) -> int:
	var spare: Array = range(EMPTY_INDEX).filter(func(i: int) -> bool: return (table["hex"] as Dictionary).find_key(i) == null)
	var wanted: Array = keys.map(func(k: Variant) -> int: return int(k))
	var pond: Dictionary = {}
	table["pond"] = pond
	var mud: Array = []
	if wanted.size() * 2 > spare.size() and spare.size() >= 2:
		for t: int in 2:
			img.set_pixel(spare[t], 0, POND_RGB[t])
		mud = [spare.pop_front(), spare.pop_front()]
	var overflow: int = 0
	for k: int in range(1, 256):
		if not wanted.has(k):
			continue
		if spare.size() < 2 or (k == 1 and not mud.is_empty()):
			overflow += int(k != 1 or mud.is_empty())
			if not mud.is_empty():
				pond[str(k)] = mud.duplicate()
			continue
		var src: Color = POND_RGB[2] if k < 4 else img.get_pixel(WATER_BASE + k - 4, 0)
		for t: int in 2:
			var f: float = 0.8 if t == 0 else 0.72
			var c: Color = Color8(roundi(src.r8 * f), roundi(src.g8 * f), roundi(src.b8 * f))
			img.set_pixel(spare[t], 0, POND_RGB[t] if k == 1 else c)
		pond[str(k)] = [spare.pop_front(), spare.pop_front()]
	return overflow
