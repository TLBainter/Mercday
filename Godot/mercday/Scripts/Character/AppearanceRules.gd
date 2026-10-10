@tool
class_name AppearanceRules extends RefCounted

#Builds a character's ResolvedPool from its profiles: ancestry, then bloodline overriding the slots it sets; a hybrid
#mixes that stack with the recessive one at 2 x primary + 1 x recessive; the tradition then overrides clothing and gear.

const HYBRID_PRIMARY: float = 2.0
const HYBRID_RECESSIVE: float = 1.0


static func resolve(merc: MercenaryData) -> ResolvedPool:
	if merc == null:
		return ResolvedPool.new()
	return resolve_names(
		merc.ancestry.ancestry_name if merc.ancestry != null else "",
		merc.bloodline.ancestry_name if merc.bloodline != null else "",
		merc.tradition.tradition_name if merc.tradition != null else "",
		merc.recessive_ancestry.ancestry_name if merc.recessive_ancestry != null else "",
		merc.recessive_bloodline.ancestry_name if merc.recessive_bloodline != null else "",
		merc.ancestry.size if merc.ancestry != null else 2)


#size is the primary ancestry's Ancestries.tsv Size; 0 or 1 forces the kid body set.
static func resolve_names(ancestry: String, bloodline: String, tradition: String, recessive_ancestry: String = "",
		recessive_bloodline: String = "", size: int = 2) -> ResolvedPool:
	var pool: ResolvedPool = _stack(ancestry, bloodline)
	if not recessive_ancestry.is_empty():
		pool = _mix(pool, _stack(recessive_ancestry, recessive_bloodline))
	_apply_tradition(pool, AppearanceProfiles.load_profile("tradition", tradition))
	pool.force_kid = not ancestry.is_empty() and size <= 1
	return pool


static func _stack(ancestry: String, bloodline: String) -> ResolvedPool:
	var pool := ResolvedPool.new()
	_apply_layer(pool, AppearanceProfiles.load_profile("ancestry", ancestry))
	_apply_layer(pool, AppearanceProfiles.load_profile("bloodline", bloodline))
	return pool


static func _apply_layer(pool: ResolvedPool, p: AppearanceProfile) -> void:
	if p == null:
		return
	if p.sets_body():
		pool.bodies = _positive(p.body_weights, false, true)
	for key: Variant in p.slot_odds:
		var unit: String = _unit_key(String(key))
		if not unit.is_empty():
			pool.slot_odds[unit] = clampf(float(p.slot_odds[key]), 0.0, 1.0)
	for slot: Variant in p.part_weights:
		if p.sets_slot(String(slot)):
			pool.parts[String(slot)] = _positive(p.part_weights[slot], false, true)
	for group: Variant in p.color_weights:
		if p.sets_group(String(group)):
			pool.colors[String(group)] = _positive(p.color_weights[group], true)
	for category: Variant in p.gear_weights:
		if p.sets_gear(String(category)):
			pool.gear[String(category)] = _positive(p.gear_weights[category])


#Clothing slots, the fill odds of all-clothing units, the common color group and gear; anything else is ignored.
static func _apply_tradition(pool: ResolvedPool, p: AppearanceProfile) -> void:
	if p == null:
		return
	for slot: String in AppearanceProfile.CLOTHING_SLOTS:
		if p.sets_slot(slot):
			pool.parts[slot] = _positive(p.part_weights[slot], false, true)
	for key: Variant in p.slot_odds:
		var unit: String = _unit_key(String(key))
		if not unit.is_empty() and CharacterOdds.unit_slots(unit).all(
				func(slot: String) -> bool: return slot in AppearanceProfile.CLOTHING_SLOTS):
			pool.slot_odds[unit] = clampf(float(p.slot_odds[key]), 0.0, 1.0)
	if p.sets_group(CharacterParts.DEFAULT_GROUP):
		pool.colors[CharacterParts.DEFAULT_GROUP] = _positive(p.color_weights[CharacterParts.DEFAULT_GROUP], true)
	for category: Variant in p.gear_weights:
		if p.sets_gear(String(category)):
			pool.gear[String(category)] = _positive(p.gear_weights[category])


#Weights add as 2 x primary + 1 x recessive per key; fill odds average the same way, an unset side using the default.
static func _mix(primary: ResolvedPool, recessive: ResolvedPool) -> ResolvedPool:
	var out := ResolvedPool.new()
	out.bodies = _mix_weights(primary.bodies, recessive.bodies)
	for table: String in ["parts", "colors", "gear"]:
		var a: Dictionary = primary.get(table)
		var b: Dictionary = recessive.get(table)
		var mixed: Dictionary = {}
		for key: Variant in _union(a, b):
			mixed[key] = _mix_weights(a.get(key, {}), b.get(key, {}))
		out.set(table, mixed)
	for unit: Variant in _union(primary.slot_odds, recessive.slot_odds):
		var fallback: float = float(CharacterOdds.UNIT_ODDS.get(unit, 0.0))
		var pa: float = float(primary.slot_odds.get(unit, fallback))
		var pb: float = float(recessive.slot_odds.get(unit, fallback))
		out.slot_odds[unit] = (HYBRID_PRIMARY * pa + HYBRID_RECESSIVE * pb) / (HYBRID_PRIMARY + HYBRID_RECESSIVE)
	return out


static func _mix_weights(a: Dictionary, b: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in a:
		out[key] = HYBRID_PRIMARY * float(a[key])
	for key: Variant in b:
		out[key] = float(out.get(key, 0.0)) + HYBRID_RECESSIVE * float(b[key])
	return out


static func _union(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = a.keys()
	for key: Variant in b:
		if not a.has(key):
			out.append(key)
	return out


#Positive weights only; int_keys turns color row keys saved as text back into ints; families turns part ids into
#their family keys, a later duplicate overwriting.
static func _positive(weights: Variant, int_keys: bool = false, families: bool = false) -> Dictionary:
	var out: Dictionary = {}
	if not (weights is Dictionary):
		return out
	for key: Variant in weights:
		var w: float = float(weights[key])
		if w <= 0.0:
			continue
		if int_keys:
			out[int(key)] = w
		elif families and not CharacterParts.part(String(key)).is_empty():
			out[CharacterParts.family(String(key))] = w
		else:
			out[String(key)] = w
	return out


#A slot_odds key as its roll unit: a unit stays, a slot maps to its unit, anything else (cloak2) is "".
static func _unit_key(key: String) -> String:
	return key if CharacterOdds.UNIT_ODDS.has(key) else CharacterOdds.unit_of(key)
