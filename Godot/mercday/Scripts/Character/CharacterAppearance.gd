@tool
class_name CharacterAppearance extends Resource

#A rolled look: one AppearanceElement per filled slot in CharacterBaker.LAYER_ORDER, plus the shared skin, hair and
#eye rows (group -> row) that every element region of a shared group takes.

const SEED_MAX: int = 0x7fffffff

@export var rng_seed: int = 0
@export var gender: String = "M"
@export var elements: Array[AppearanceElement] = []
@export var shared_colors: Dictionary = {}


#adult drops the kid body from the gender roll. The draw order is fixed so a seed always gives the same look.
#A pool (AppearanceRules) weights bodies, unit odds, part families and color rows; its empty dicts draw as no pool.
static func roll(roll_seed: int, adult: bool = false, pool: ResolvedPool = null) -> CharacterAppearance:
	var rng := RandomNumberGenerator.new()
	rng.seed = roll_seed
	var app := CharacterAppearance.new()
	app.rng_seed = roll_seed
	var kid: bool = pool != null and pool.force_kid
	app.gender = CharacterOdds.KID_BODY if kid else _pick_gender(rng, adult)
	var picked: Dictionary = {}
	var bodies: Array[Dictionary] = CharacterParts.parts("body", app.gender)
	if not bodies.is_empty():
		picked["body"] = _pick_part(rng, "body", bodies, pool.bodies if pool != null else {}, app.gender)
	for unit: String in CharacterOdds.UNITS:
		if unit == "beard" and app.gender in CharacterOdds.NO_BEARD:
			continue
		var sets: bool = false
		if pool != null:
			for slot: String in CharacterOdds.unit_slots(unit):
				sets = sets or not (pool.parts.get(slot, {}) as Dictionary).is_empty()
		if pool != null and pool.strict and not sets:
			continue
		if sets:
			_roll_set_unit(rng, unit, app.gender, pool, picked)
		else:
			var odds: float = float(CharacterOdds.UNIT_ODDS[unit])
			if pool != null:
				odds = float(pool.slot_odds.get(unit, odds))
			if rng.randf() < odds:
				_roll_open_unit(rng, unit, app.gender, picked)
	if picked.has("cloak1"):
		var fam: String = CharacterParts.cloak_partner(CharacterParts.family(String(picked["cloak1"])))
		var partner: String = CharacterParts.family_member("cloak2", fam, app.gender) if not fam.is_empty() else ""
		if not partner.is_empty():
			picked["cloak2"] = partner
	for group: String in CharacterOdds.SHARED_GROUPS:
		var count: int = CharacterParts.palette_rows(group)
		if count > 0:
			app.shared_colors[group] = _pick_row(rng, group, count, pool)
	var rolled: Dictionary = {}
	for slot: String in picked:
		rolled[slot] = _element(slot, picked[slot], rng, pool)
	app.elements = _in_layer_order(rolled)
	return app


#A unit whose pool sets parts: a link draws None against fill once, then each slot picks; a group or slot picks once.
static func _roll_set_unit(rng: RandomNumberGenerator, unit: String, gender: String, pool: ResolvedPool,
		picked: Dictionary) -> void:
	var slots: Array[String] = CharacterOdds.unit_slots(unit)
	var candidates: Dictionary = {}
	var none_w: float = 0.0
	for slot: String in slots:
		var weights: Dictionary = pool.parts.get(slot, {})
		candidates.merge(_fitting_weights(slot, weights, gender), true)
		if not CharacterOdds.is_link(unit) or slot == slots[0]:
			none_w += maxf(float(weights.get(CharacterOdds.NONE_ID, 0.0)), 0.0)
	if CharacterOdds.is_link(unit):
		var fill_w: float = 0.0
		for id: Variant in candidates:
			fill_w += float(candidates[id])
		var draw: String = ResolvedPool.weighted_pick(rng, {CharacterOdds.NONE_ID: none_w,
			"fill": fill_w if fill_w > 0.0 else 1.0})
		if draw == CharacterOdds.NONE_ID:
			return
		for slot: String in slots:
			var weights: Dictionary = pool.parts.get(slot, {})
			var options: Array[Dictionary] = CharacterParts.parts(slot, gender)
			if options.is_empty() or (weights.is_empty() and pool.strict):
				continue
			picked[slot] = _pick_part(rng, slot, options, weights, gender)
		return
	var table: Dictionary = candidates.duplicate()
	if none_w > 0.0:
		table[CharacterOdds.NONE_ID] = none_w
	var id_pick: String = ResolvedPool.weighted_pick(rng, table)
	if id_pick == CharacterOdds.NONE_ID or (id_pick.is_empty() and none_w > 0.0):
		return
	if id_pick.is_empty():
		var options: Array[Dictionary] = _unit_options(unit, gender)
		if options.is_empty():
			return
		id_pick = String(options[rng.randi_range(0, options.size() - 1)]["id"])
	picked[String(CharacterParts.part(id_pick).get("slot", ""))] = id_pick


#A unit that passed its fill roll with no pool parts: uniform per slot for a link, else over the unit's options.
static func _roll_open_unit(rng: RandomNumberGenerator, unit: String, gender: String, picked: Dictionary) -> void:
	if CharacterOdds.is_link(unit):
		for slot: String in CharacterOdds.unit_slots(unit):
			var slot_options: Array[Dictionary] = CharacterParts.parts(slot, gender)
			if not slot_options.is_empty():
				picked[slot] = String(slot_options[rng.randi_range(0, slot_options.size() - 1)]["id"])
		return
	var options: Array[Dictionary] = _unit_options(unit, gender)
	if options.is_empty():
		return
	var id: String = String(options[rng.randi_range(0, options.size() - 1)]["id"])
	picked[String(CharacterParts.part(id).get("slot", ""))] = id


static func _unit_options(unit: String, gender: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot: String in CharacterOdds.unit_slots(unit):
		out.append_array(CharacterParts.parts(slot, gender))
	return out


#Pool keys (families, or raw ids read as their family) resolved to the member fitting the body: {id: weight}.
static func _fitting_weights(slot: String, weights: Dictionary, gender: String) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in weights:
		var text: String = String(key)
		if text == CharacterOdds.NONE_ID:
			continue
		var fam: String = CharacterParts.family(text) if not CharacterParts.part(text).is_empty() else text
		var id: String = CharacterParts.family_member(slot, fam, gender)
		if not id.is_empty():
			out[id] = weights[key]
	return out


#Weighted among the pool families that have a member in options; uniform as before when none do.
static func _pick_part(rng: RandomNumberGenerator, slot: String, options: Array[Dictionary], weights: Dictionary,
		gender: String) -> String:
	if not weights.is_empty():
		var id_pick: String = ResolvedPool.weighted_pick(rng, _fitting_weights(slot, weights, gender))
		if not id_pick.is_empty():
			return id_pick
	return String(options[rng.randi_range(0, options.size() - 1)]["id"])


#Weighted among the pool rows inside the palette; uniform as before when the pool has none for the group.
static func _pick_row(rng: RandomNumberGenerator, group: String, count: int, pool: ResolvedPool) -> int:
	if pool != null and pool.colors.has(group):
		var rows: Dictionary = {}
		var weights: Dictionary = pool.colors[group]
		for row: Variant in weights:
			if int(row) >= 0 and int(row) < count:
				rows[int(row)] = weights[row]
		var row_pick: String = ResolvedPool.weighted_pick(rng, rows)
		if not row_pick.is_empty():
			return int(row_pick)
	return rng.randi_range(0, count - 1)


static func _pick_gender(rng: RandomNumberGenerator, adult: bool) -> String:
	var genders: Array = CharacterOdds.BODY_WEIGHTS.keys()
	var weights := PackedFloat32Array()
	for g: String in genders:
		weights.append(0.0 if adult and g == CharacterOdds.KID_BODY else float(CharacterOdds.BODY_WEIGHTS[g]))
	return String(genders[rng.rand_weighted(weights)])


#Every mask region of the part gets an entry; a null rng leaves the unshared rows at -1 for from_dict to fill.
static func _element(slot: String, id: String, rng: RandomNumberGenerator, pool: ResolvedPool = null) -> AppearanceElement:
	var el := AppearanceElement.new()
	el.slot = slot
	el.part_id = id
	for region: Dictionary in CharacterParts.part(id).get("regions", []):
		var group: String = String(region.get("group", CharacterParts.DEFAULT_GROUP))
		var row: int = -1
		if rng != null and not (group in CharacterOdds.SHARED_GROUPS):
			var count: int = CharacterParts.palette_rows(group)
			if count > 0:
				row = _pick_row(rng, group, count, pool)
		el.colors[region_key(region.get("key", []))] = {"group": group, "row": row}
	return el


static func _in_layer_order(by_slot: Dictionary) -> Array[AppearanceElement]:
	var out: Array[AppearanceElement] = []
	for slot: String in CharacterBaker.LAYER_ORDER:
		if by_slot.has(slot):
			out.append(by_slot[slot])
	for slot: String in by_slot:
		if not (slot in CharacterBaker.LAYER_ORDER):
			out.append(by_slot[slot])
	return out


func element(slot: String) -> AppearanceElement:
	for el: AppearanceElement in elements:
		if el != null and el.slot == slot:
			return el
	return null


func part_id(slot: String) -> String:
	var el: AppearanceElement = element(slot)
	return el.part_id if el != null else ""


func slots() -> Array[String]:
	var out: Array[String] = []
	for el: AppearanceElement in elements:
		if el != null:
			out.append(el.slot)
	return out


func is_empty() -> bool:
	return slots().is_empty()


#The {"group", "row"} entry coloring one mask region of a part; empty when the region is not rolled.
func region_row(part: String, rgb: Variant) -> Dictionary:
	var key_text: String = String(rgb) if rgb is String else region_key(rgb)
	for el: AppearanceElement in elements:
		if el != null and el.part_id == part:
			return el.row_for(key_text, shared_colors)
	return {}


#Seed plus content hash, so an appearance edited after its roll bakes a fresh texture.
func cache_key() -> String:
	return "%d|%d" % [rng_seed, JSON.stringify(to_dict(), "", true).hash()]


static func region_key(rgb: Variant) -> String:
	if not (rgb is Array) or rgb.size() < 3:
		return ""
	return "%d,%d,%d" % [int(rgb[0]), int(rgb[1]), int(rgb[2])]


#{"seed", "gender", "parts": {slot: id}, "colors": {group: {group, row}, "<part id>|r,g,b": {group, row}}}
func to_dict() -> Dictionary:
	var parts: Dictionary = {}
	var colors: Dictionary = {}
	for group: Variant in shared_colors:
		colors[String(group)] = {"group": String(group), "row": int(shared_colors[group])}
	for el: AppearanceElement in elements:
		if el == null:
			continue
		parts[el.slot] = el.part_id
		for key_text: Variant in el.colors:
			var entry: Dictionary = el.colors[key_text]
			var row: int = int(entry.get("row", -1))
			if row >= 0:
				var group: String = String(entry.get("group", CharacterParts.DEFAULT_GROUP))
				colors["%s|%s" % [el.part_id, key_text]] = {"group": group, "row": row}
	return {"seed": rng_seed, "gender": gender, "parts": parts, "colors": colors}


static func from_dict(data: Dictionary) -> CharacterAppearance:
	var app := CharacterAppearance.new()
	app.rng_seed = int(data.get("seed", 0))
	app.gender = String(data.get("gender", "M"))
	var rolled: Dictionary = data.get("colors", {})
	for group: String in CharacterOdds.SHARED_GROUPS:
		if rolled.has(group):
			app.shared_colors[group] = int((rolled[group] as Dictionary).get("row", 0))
	var by_slot: Dictionary = {}
	var slots_in: Dictionary = data.get("parts", {})
	for slot: Variant in slots_in:
		var el: AppearanceElement = _element(String(slot), String(slots_in[slot]), null)
		var prefix: String = el.part_id + "|"
		for color_key: Variant in rolled:
			if String(color_key).begins_with(prefix):
				var entry: Dictionary = rolled[color_key]
				var group: String = String(entry.get("group", CharacterParts.DEFAULT_GROUP))
				el.colors[String(color_key).substr(prefix.length())] = {"group": group, "row": int(entry.get("row", 0))}
		by_slot[el.slot] = el
	app.elements = _in_layer_order(by_slot)
	return app
