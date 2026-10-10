@tool
class_name BakeScatterRules extends MapBakeStep

#Builds the scatter rules table (D3) from map-scatter.json and the two palette sources.
#Zones keep FOLIAGE_ZONES order, then one row per land class and the jungle row.

const STAGE := 3
const SCATTER_KEY := "src/map-scatter.json"
const OUT_KEY := "scatter_rules"
const FILTER_KEYS: PackedStringArray = ["cls", "clsNot", "tone", "nation", "region", "regionCat", "island", "zMax", "zMin",
	"near", "seg", "ell", "patch"]


func _init() -> void:
	step_name = &"BakeScatterRules"
	stage = STAGE
	inputs = PackedStringArray([SCATTER_KEY, BakePalette.LAND_KEY, BakePalette.WATER_KEY])
	outputs = PackedStringArray([OUT_KEY])


func run(ctx: MapBakeContext) -> bool:
	var d2: Variant = ctx.get_value(SCATTER_KEY)
	var land: Variant = ctx.get_value(BakePalette.LAND_KEY)
	var water: Variant = ctx.get_value(BakePalette.WATER_KEY)
	if not (d2 is Dictionary) or not (land is Dictionary) or not (water is Dictionary):
		return ctx.fail("BakeScatterRules: scatter or palette json missing")
	var packed: Dictionary = BakePalette.pack(land, water)
	if not String(packed["error"]).is_empty():
		return ctx.fail("BakeScatterRules: " + String(packed["error"]))
	var rules: Dictionary = build(d2, packed["table"])
	ctx.put_value(OUT_KEY, rules)
	var file: FileAccess = FileAccess.open(ctx.path_of(OUT_KEY + ".json"), FileAccess.WRITE)
	if file == null:
		return ctx.fail("BakeScatterRules: cannot write scatter_rules.json")
	file.store_string(JSON.stringify(rules, "", false, true))
	if file.get_error() != OK:
		file.close()
		return ctx.fail("BakeScatterRules: write failed scatter_rules.json")
	file.close()
	ctx.log("BakeScatterRules: %d zones, %d scat ids, %d flat ids" % [(rules["zones"] as Array).size(),
		(rules["scat_ids"] as Array).size(), (rules["flat_ids"] as Array).size()])
	return not ctx.failed


static func build(d2: Dictionary, table: Dictionary) -> Dictionary:
	var zones: Array = []
	var ids: Array = []
	for src: Variant in d2.get("FOLIAGE_ZONES", []):
		zones.append(_zone(src as Dictionary, String((src as Dictionary).get("id", "")), ids))
	var foliage: Dictionary = d2.get("FOLIAGE", {})
	var names: Array = foliage.keys()
	names.sort_custom(func(a: Variant, b: Variant) -> bool:
		return (String(a).is_valid_int() and not String(b).is_valid_int()) or (String(a).is_valid_int()
			and String(b).is_valid_int() and int(a) < int(b)))
	for key: Variant in names:
		var nm: String = "jungle" if String(key) == "jungle" else "class_" + String(key)
		zones.append(_zone(foliage[key] as Dictionary, nm, ids))
	var ws: Dictionary = (d2.get("WATER_SCATTER", {}) as Dictionary).duplicate(true)
	var river: Dictionary = ws.get("river", {})
	ws.erase("river")
	var ice: Dictionary = d2.get("ICE_MOUNTAIN", {})
	for group: Variant in [ws.get("k", []), ws.get("kIcy", []), ws.get("kViolet", []), river.get("kits", []),
			ice.get("kits", []), d2.get("CYF", [])]:
		for row: Variant in group:
			ids.append(String((row as Array)[0]))
	ids.append_array(d2.get("BUSH", []))
	for id: String in ["w_lily", "f_reeds"]:
		if not ids.has(id):
			ids.append(id)
	var gi: Dictionary = (d2.get("GS", {}) as Dictionary).get("ice", {})
	var gs_ice: Dictionary = (gi.get("re", {}) as Dictionary).duplicate()
	for key: String in ["p0", "p1", "denseZ", "denseP"]:
		gs_ice[key] = gi.get(key, 0.0)
	return {"version": 1, "zones": zones, "fill": [], "water": ws, "ice": ice, "river": river,
		"palette": _palette(table, false), "water_palette": _palette(table, true),
		"scat_ids": _matching(ids, d2.get("SCAT", {})), "flat_ids": _matching(ids, d2.get("FLAT_KIT", {})),
		"trees": d2.get("TREES", []), "meadow_cat": (d2.get("GS", {}) as Dictionary).get("meadowCat", []),
		"gs_ice": gs_ice, "spread_ids": d2.get("spread_ids", {})}


static func _zone(src: Dictionary, zname: String, ids: Array) -> Dictionary:
	var kits: Array = src.get("k", [])
	var z: Dictionary = {"name": zname, "kits": kits, "tot": _total(kits), "d": float(src.get("d", 0.0)),
		"c": float(src.get("c", 0.0)), "filters": {}}
	if src.has("dDark"):
		z["dDark"] = float(src["dDark"])
	for key: String in FILTER_KEYS:
		if src.has(key):
			(z["filters"] as Dictionary)[key] = src[key]
	for row: Variant in kits:
		ids.append(String((row as Array)[0]))
	if src.has("fill"):
		var fill: Dictionary = (src["fill"] as Dictionary).duplicate(true)
		fill["tot"] = _total(fill.get("k", []))
		z["fill"] = fill
		for row: Variant in fill["k"]:
			ids.append(String((row as Array)[0]))
	return z


static func _total(kits: Array) -> float:
	var tot: float = 0.0
	for row: Variant in kits:
		tot += float((row as Array)[1])
	return tot


static func _palette(table: Dictionary, water: bool) -> Array:
	var rows: Array = []
	var classes: Dictionary = table.get("water_classes" if water else "classes", {})
	var by_id: Dictionary = {}
	for cname: Variant in classes:
		by_id[(int(classes[cname]) - BakePalette.WATER_BASE * int(water)) >> 2] = String(cname)
	var hex: Dictionary = table.get("hex", {})
	for key: Variant in hex:
		var idx: int = int(hex[key])
		if (idx >= BakePalette.WATER_BASE) != water:
			continue
		var code: int = idx - BakePalette.WATER_BASE * int(water)
		var col: Color = Color(String(key))
		rows.append({"code": code, "cls": code >> 2, "tone": code & 3, "name": by_id.get(code >> 2, ""),
			"rgb": [col.r8, col.g8, col.b8]})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["code"]) < int(b["code"]))
	return rows


static func _matching(ids: Array, spec: Dictionary) -> Array:
	var re: RegEx = RegEx.create_from_string(("(?i)" if String(spec.get("flags", "")).contains("i") else "")
		+ String(spec.get("re", "")))
	var out: Array = []
	for id: Variant in ids:
		if not out.has(String(id)) and re.search(String(id)) != null:
			out.append(String(id))
	return out
