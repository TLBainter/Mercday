class_name AppearancePoolTests

#Appearance pools: the profile resource, the layer and hybrid rules, the weighted roll, tradition gear and the
#Appearance Pools editor. Run with the appearance-pool-tests harness flag.

const SAVE_PATH: String = "user://appearance_pool_test.tres"
const EDITOR_SCENE: String = "res://Scenes/Tools/AppearancePools.tscn"
const HAIR: String = "hair_front"
const FILL_SLOT: String = "hat"
const CLOTHING: String = "clothing1"
const COMMON: String = "common"
const COLOR_ROW: int = 1
const PICK_ROLLS: int = 200
const ODDS_ROLLS: int = 100
const EMPTY_SEEDS: int = 20
const COLOR_SEEDS: int = 20
const KID_SEEDS: int = 20
const GEN_MERCS: int = 10
const GEAR_MERCS: int = 20
const ADULT_GENDERS: Array[String] = ["F", "M"]
const ALL_BODIES: Array[String] = ["F", "M", "K"]
const UNKNOWN_WEAPON: String = "No Such Weapon"
const WANT_LISTS: Array[int] = [11, 41, 10]
#Profile names no TSV row uses, so a saved profile can never shadow them.
const ANC: String = "Test Ancestry"
const BLOOD: String = "Test Bloodline"
const REC: String = "Test Recessive"
const TRAD: String = "Test Tradition"


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	AppearanceProfiles.reset()
	_case_round_trip(res)
	_case_empty(res)
	_case_override(res)
	_case_hybrid(res)
	_case_tradition(res)
	_case_kid(res)
	_case_null_pool(res)
	_case_weights(res)
	_case_color(res)
	_case_odds(res)
	_case_generator(res)
	_case_gear(res)
	await _case_editor(res, host)
	AppearanceProfiles.reset()
	return TestFixtures.summarize(res, "APPEARANCE POOL")


static func _profile(kind: String, profile_name: String, part_weights: Dictionary = {},
		gear_weights: Dictionary = {}) -> AppearanceProfile:
	var p := AppearanceProfile.new()
	p.kind = kind
	p.profile_name = profile_name
	p.part_weights = part_weights
	p.gear_weights = gear_weights
	AppearanceProfiles.set_override(kind, profile_name, p)
	return p


static func _pool_is_empty(pool: ResolvedPool) -> bool:
	return pool.bodies.is_empty() and pool.slot_odds.is_empty() and pool.parts.is_empty() \
		and pool.colors.is_empty() and pool.gear.is_empty()


#[heavy ids, light ids]: the first two parts of a slot for each adult body, so either body has one of each.
static func _adult_pairs(slot: String) -> Array:
	var heavy: Array[String] = []
	var light: Array[String] = []
	for g: String in ADULT_GENDERS:
		var options: Array[Dictionary] = CharacterParts.parts(slot, g)
		if options.size() < 2:
			return [[] as Array[String], [] as Array[String]]
		heavy.append(String(options[0]["id"]))
		light.append(String(options[1]["id"]))
	return [heavy, light]


static func _pair_weights(heavy: Array[String], light: Array[String], heavy_w: float, light_w: float) -> Dictionary:
	var out: Dictionary = {}
	for id: String in heavy:
		out[id] = heavy_w
	for id: String in light:
		out[id] = light_w
	return out


static func _case_round_trip(res: Dictionary) -> void:
	var p := AppearanceProfile.new()
	p.kind = "bloodline"
	p.profile_name = BLOOD
	p.body_weights = {"body_a": 2.0}
	p.slot_odds = {HAIR: 0.25}
	p.part_weights = {HAIR: {"hair_a": 1.5, "hair_b": 3.0}}
	p.color_weights = {"skin": {2: 1.0, 5: 0.5}}
	p.gear_weights = {"weapon": {"Dagger": 1.0}, "armor": {"Leather": 2.0}}
	var err: Error = ResourceSaver.save(p, SAVE_PATH)
	var loaded: AppearanceProfile = null
	if err == OK:
		loaded = ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as AppearanceProfile
	var same: bool = loaded != null and loaded.kind == p.kind and loaded.profile_name == p.profile_name \
		and loaded.body_weights == p.body_weights and loaded.slot_odds == p.slot_odds \
		and loaded.part_weights == p.part_weights and loaded.color_weights == p.color_weights \
		and loaded.gear_weights == p.gear_weights
	TestFixtures.check(res, "a profile keeps its kind, name and five dicts through ResourceSaver", same,
		"err %d, loaded %s" % [err, loaded != null])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


static func _case_empty(res: Dictionary) -> void:
	AppearanceProfiles.reset()
	var pool: ResolvedPool = AppearanceRules.resolve_names(ANC, BLOOD, TRAD, REC, BLOOD)
	TestFixtures.check(res, "names with no profiles resolve to an empty adult pool",
		_pool_is_empty(pool) and not pool.force_kid, "force_kid %s, parts %s" % [pool.force_kid, pool.parts])


static func _case_override(res: Dictionary) -> void:
	AppearanceProfiles.reset()
	_profile("ancestry", ANC, {HAIR: {"hair_a": 1.0}, FILL_SLOT: {"hat_a": 1.0}})
	_profile("bloodline", BLOOD, {HAIR: {"hair_b": 2.0}})
	var pool: ResolvedPool = AppearanceRules.resolve_names(ANC, BLOOD, "")
	TestFixtures.check(res, "a bloodline that sets hair_front replaces the ancestry pool; the unset hat keeps it",
		pool.parts.get(HAIR) == {"hair_b": 2.0} and pool.parts.get(FILL_SLOT) == {"hat_a": 1.0}, str(pool.parts))
	AppearanceProfiles.reset()


static func _case_hybrid(res: Dictionary) -> void:
	AppearanceProfiles.reset()
	_profile("ancestry", ANC, {HAIR: {"x": 1.0, "y": 1.0}})
	_profile("ancestry", REC, {HAIR: {"y": 1.0, "z": 2.0}, FILL_SLOT: {"h": 1.0}})
	var pool: ResolvedPool = AppearanceRules.resolve_names(ANC, "", "", REC)
	TestFixtures.check(res, "a hybrid mixes 2 x primary + 1 x recessive per key, a missing key counting 0",
		pool.parts.get(HAIR) == {"x": 2.0, "y": 3.0, "z": 2.0} and pool.parts.get(FILL_SLOT) == {"h": 1.0},
		str(pool.parts))
	AppearanceProfiles.reset()


static func _case_tradition(res: Dictionary) -> void:
	AppearanceProfiles.reset()
	_profile("ancestry", ANC, {CLOTHING: {"a_cloth": 1.0}, HAIR: {"a_hair": 1.0}})
	_profile("tradition", TRAD, {CLOTHING: {"t_cloth": 1.0}, HAIR: {"t_hair": 1.0}}, {"weapon": {"Dagger": 1.0}})
	var pool: ResolvedPool = AppearanceRules.resolve_names(ANC, "", TRAD)
	TestFixtures.check(res, "a tradition overrides clothing1 and gear and its hair_front entry is ignored",
		pool.parts.get(CLOTHING) == {"t_cloth": 1.0} and pool.parts.get(HAIR) == {"a_hair": 1.0}
		and pool.gear.get("weapon") == {"Dagger": 1.0}, "%s, gear %s" % [pool.parts, pool.gear])
	AppearanceProfiles.reset()


static func _case_kid(res: Dictionary) -> void:
	var wrong: Array[String] = []
	for size: int in range(4):
		var pool: ResolvedPool = AppearanceRules.resolve_names(ANC, "", "", "", "", size)
		if pool.force_kid != (size <= 1):
			wrong.append("size %d" % size)
	TestFixtures.check(res, "Size 0 and 1 force the kid body; Size 2 and 3 do not", wrong.is_empty(),
		TestFixtures.detail(wrong, 4, "sizes"))
	var kid: ResolvedPool = AppearanceRules.resolve_names(ANC, "", "", "", "", 0)
	var bad: Array[String] = []
	for seed_i: int in range(1, KID_SEEDS + 1):
		var app: CharacterAppearance = CharacterAppearance.roll(seed_i, true, kid)
		var body: String = String(CharacterParts.part(app.part_id("body")).get("gender", ""))
		if app.gender != CharacterOdds.KID_BODY or body != CharacterOdds.KID_BODY:
			bad.append("seed %d %s/%s" % [seed_i, app.gender, body])
	TestFixtures.check(res, "a forced kid rolls gender K with a K body", bad.is_empty(),
		TestFixtures.detail(bad, KID_SEEDS, "seeds"))


static func _case_null_pool(res: Dictionary) -> void:
	CharacterTests._case_log(res)
	var empty := ResolvedPool.new()
	var bad: Array[String] = []
	for seed_i: int in range(1, EMPTY_SEEDS + 1):
		for adult: bool in [false, true]:
			var with_pool: Dictionary = CharacterAppearance.roll(seed_i, adult, empty).to_dict()
			if with_pool != CharacterAppearance.roll(seed_i, adult).to_dict():
				bad.append("seed %d adult %s" % [seed_i, adult])
	TestFixtures.check(res, "an all-empty pool rolls exactly as no pool", bad.is_empty(),
		TestFixtures.detail(bad, EMPTY_SEEDS * 2, "rolls"))


static func _case_weights(res: Dictionary) -> void:
	var pairs: Array = _adult_pairs(HAIR)
	var heavy: Array[String] = pairs[0]
	var light: Array[String] = pairs[1]
	if heavy.is_empty():
		TestFixtures.check(res, "each adult body has two hair_front parts for the weight cases", false, HAIR)
		return
	var pool := ResolvedPool.new()
	pool.parts = {HAIR: _pair_weights(heavy, light, 1.0, 0.0)}
	var fills: int = 0
	var bad: Array[String] = []
	for seed_i: int in range(1, PICK_ROLLS + 1):
		var got: String = CharacterAppearance.roll(seed_i, true, pool).part_id(HAIR)
		if got.is_empty():
			continue
		fills += 1
		if not (got in heavy):
			bad.append("seed %d %s" % [seed_i, got])
	TestFixtures.check(res, "a weight-0 part is never picked and the weighted one always is",
		fills > 0 and bad.is_empty(), "%d fills, %s" % [fills, TestFixtures.detail(bad, fills, "fills")])
	pool.parts = {HAIR: _pair_weights(heavy, light, 3.0, 1.0)}
	var first: int = 0
	var second: int = 0
	for seed_i: int in range(1, PICK_ROLLS + 1):
		var got: String = CharacterAppearance.roll(seed_i, true, pool).part_id(HAIR)
		if got in heavy:
			first += 1
		elif got in light:
			second += 1
	TestFixtures.check(res, "weights 3 and 1 both appear and the heavier one more often",
		second > 0 and first > second, "%d heavy, %d light" % [first, second])


static func _case_color(res: Dictionary) -> void:
	if CharacterParts.palette_rows(COMMON) <= COLOR_ROW:
		TestFixtures.check(res, "the common palette has a row %d" % COLOR_ROW, false,
			"%d rows" % CharacterParts.palette_rows(COMMON))
		return
	var pool := ResolvedPool.new()
	pool.colors = {COMMON: {COLOR_ROW: 1.0}}
	var regions: int = 0
	var bad: Array[String] = []
	for seed_i: int in range(1, COLOR_SEEDS + 1):
		for el: AppearanceElement in CharacterAppearance.roll(seed_i, true, pool).elements:
			for key: Variant in el.colors:
				var entry: Dictionary = el.colors[key]
				if String(entry.get("group", "")) != COMMON:
					continue
				regions += 1
				if int(entry.get("row", -1)) != COLOR_ROW:
					bad.append("seed %d %s row %d" % [seed_i, el.part_id, int(entry.get("row", -1))])
	TestFixtures.check(res, "a common color pool of one row colors every common region with it",
		regions > 0 and bad.is_empty(), "%d regions, %s" % [regions, TestFixtures.detail(bad, regions, "regions")])


static func _case_odds(res: Dictionary) -> void:
	var pool := ResolvedPool.new()
	pool.slot_odds = {FILL_SLOT: 0.0}
	var filled: Array[String] = []
	for seed_i: int in range(1, ODDS_ROLLS + 1):
		if not CharacterAppearance.roll(seed_i, true, pool).part_id(FILL_SLOT).is_empty():
			filled.append(str(seed_i))
	TestFixtures.check(res, "fill odds 0 never fill the hat slot", filled.is_empty(),
		TestFixtures.detail(filled, ODDS_ROLLS, "seeds"))
	pool.slot_odds = {FILL_SLOT: 1.0}
	var empty: Array[String] = []
	var counted: int = 0
	for seed_i: int in range(1, ODDS_ROLLS + 1):
		var app: CharacterAppearance = CharacterAppearance.roll(seed_i, true, pool)
		if CharacterParts.parts(FILL_SLOT, app.gender).is_empty():
			continue
		counted += 1
		if app.part_id(FILL_SLOT).is_empty():
			empty.append(str(seed_i))
	TestFixtures.check(res, "fill odds 1 always fill the hat slot", counted > 0 and empty.is_empty(),
		TestFixtures.detail(empty, counted, "seeds"))


#Every ancestry gets a hair_front pool of one part per body gender, always filled.
static func _case_generator(res: Dictionary) -> void:
	AppearanceProfiles.reset()
	TestFixtures.reset_campaign()
	var allowed: Dictionary = {}
	for g: String in ALL_BODIES:
		var options: Array[Dictionary] = CharacterParts.parts(HAIR, g)
		if not options.is_empty():
			allowed[String(options[options.size() - 1]["id"])] = 1.0
	for ancestry_name: Variant in DataManager.ancestries:
		var p: AppearanceProfile = _profile("ancestry", String(ancestry_name), {HAIR: allowed.duplicate()})
		p.slot_odds = {HAIR: 1.0}
	var bad: Array[String] = []
	for i: int in range(GEN_MERCS):
		var merc: MercenaryData = MercGenerator.generate(i)
		var app: CharacterAppearance = merc.appearance if merc != null else null
		if app == null:
			bad.append("merc %d has no appearance" % i)
			continue
		var got: String = app.part_id(HAIR)
		var can_fill: bool = not CharacterParts.parts(HAIR, app.gender).is_empty()
		if (got.is_empty() and can_fill) or (not got.is_empty() and not allowed.has(got)):
			bad.append("merc %d %s %s '%s'" % [i, merc.ancestry.ancestry_name if merc.ancestry != null else "?",
				app.gender, got])
	TestFixtures.check(res, "generated mercs take hair_front only from their ancestry profile pool",
		not allowed.is_empty() and bad.is_empty(),
		"%s, %s" % [allowed.keys(), TestFixtures.detail(bad, GEN_MERCS, "mercs")])
	TestFixtures.reset_campaign()
	AppearanceProfiles.reset()


static func _held_weapons(merc: MercenaryData) -> Array[String]:
	var out: Array[String] = []
	if merc == null:
		return out
	for w: WeaponData in [merc.equipped_weapon, merc.offhand_weapon]:
		if w != null:
			out.append(w.item_name)
	for entry: Dictionary in merc.inventory:
		if entry.get("type") == "weapon" and entry.get("data") is WeaponData:
			out.append((entry["data"] as WeaponData).item_name)
	return out


static func _case_gear(res: Dictionary) -> void:
	AppearanceProfiles.reset()
	TestFixtures.reset_campaign()
	var trads: Array = DataManager.traditions.keys()
	var melee: Array = StartingGear._starting_melee_pool()
	if trads.is_empty() or melee.is_empty():
		TestFixtures.check(res, "traditions and starting melee weapons are loaded", false,
			"%d traditions, %d melee" % [trads.size(), melee.size()])
		return
	var trad: String = String(trads[0])
	var weapon: String = (melee[0] as WeaponData).item_name
	var held_trad: String = MercGenerator.forced_tradition
	MercGenerator.forced_tradition = trad
	_profile("tradition", trad, {}, {"weapon": {weapon: 1.0}})
	var missing: Array[String] = []
	var able: int = 0
	for i: int in range(GEAR_MERCS):
		var merc: MercenaryData = MercGenerator.generate(i)
		if merc == null or int(merc.stats.get("weight_limit", 0)) - 1 < (melee[0] as WeaponData).weight:
			continue
		able += 1
		var held: WeaponData = merc.equipped_weapon
		if held == null or held.item_name != weapon:
			missing.append("merc %d %s" % [i, _held_weapons(merc)])
	TestFixtures.check(res, "a tradition weighting one melee weapon puts it in the hand of every merc able to carry it",
		able > 0 and missing.is_empty(), "%s, %d able: %s" % [weapon, able, TestFixtures.detail(missing, able, "mercs")])
	_case_gear_budget(res, trad)
	_profile("tradition", trad, {}, {"weapon": {UNKNOWN_WEAPON: 1.0}})
	var unarmed: Array[String] = []
	var seen: Dictionary = {}
	for i: int in range(GEAR_MERCS):
		var held: Array[String] = _held_weapons(MercGenerator.generate(i))
		if held.is_empty():
			unarmed.append("merc %d" % i)
		for item: String in held:
			seen[item] = true
	TestFixtures.check(res, "an unknown weapon name falls back to the unfiltered pool",
		unarmed.is_empty() and seen.size() > 1, "%d names seen, %s" % [seen.size(),
		TestFixtures.detail(unarmed, GEAR_MERCS, "mercs")])
	MercGenerator.forced_tradition = held_trad
	TestFixtures.reset_campaign()
	AppearanceProfiles.reset()


#A merc with room for the lightest armor and melee weapon only still wears armor when its tradition weights heavier armor.
static func _case_gear_budget(res: Dictionary, trad: String) -> void:
	var merc: MercenaryData = MercGenerator.generate(0)
	var armor: Array = StartingGear._starting_armor_pool(merc) if merc != null else []
	var light: int = StartingGear._lightest_weight(armor)
	var heavy: ArmorData = null
	for a: ArmorData in armor:
		if heavy == null or a.weight > heavy.weight:
			heavy = a
	if heavy == null or heavy.weight <= light:
		TestFixtures.check(res, "the starting armor pool holds two armor weights", false, "%d suits" % armor.size())
		return
	_profile("tradition", trad, {}, {"armor": {heavy.item_name: 1.0}})
	StartingGear.clear_gear(merc, [] as Array[String])
	merc.inventory = []
	merc.stats["weight_limit"] = 1 + light + StartingGear._lightest_weight(StartingGear._starting_melee_pool())
	StartingGear.step_gear(merc)
	var worn: ArmorData = merc.equipped_armor
	TestFixtures.check(res, "armor weights too heavy for the budget fall back to a lighter suit, never to no armor",
		worn != null and worn.weight <= light, "weighted %s %d, worn %s, limit %d" % [heavy.item_name, heavy.weight,
		worn.item_name if worn != null else "none", int(merc.stats["weight_limit"])])


static func _case_editor(res: Dictionary, host: Node) -> void:
	AppearanceProfiles.reset()
	var scene: PackedScene = load(EDITOR_SCENE) as PackedScene
	var pools: AppearancePools = scene.instantiate() as AppearancePools if scene != null else null
	TestFixtures.check(res, "AppearancePools.tscn roots an AppearancePools control", pools != null, EDITOR_SCENE)
	if pools == null:
		return
	pools.hosted = true
	host.add_child(pools)
	await TestFixtures.frames(host, 1)
	var counts: Array[int] = [pools.names("ancestry").size(), pools.names("bloodline").size(),
		pools.names("tradition").size()]
	TestFixtures.check(res, "the editor lists 11 ancestries, 41 bloodlines and 10 traditions", counts == WANT_LISTS,
		str(counts))
	TestFixtures.check(res, "the gear tab is hidden for an ancestry profile",
		pools.kind == "ancestry" and pools.is_page_hidden("Gear"), "kind %s" % pools.kind)
	pools.show_page(CLOTHING)
	var page: PoolPartPage = pools.page(CLOTHING) as PoolPartPage
	var want: int = CharacterParts.parts(CLOTHING, "F").size()
	var shown: int = -1
	if page != null:
		page.set_gender_filter("F")
		shown = page.visible_cells().size()
	TestFixtures.check(res, "the clothing1 tab builds one cell per F-fitting part", want > 0 and shown == want,
		"%d cells, %d parts" % [shown, want])
	var was_dirty: bool = pools.dirty
	if shown > 0:
		page.visible_cells()[0].set_ticked(true)
	TestFixtures.check(res, "ticking a cell writes the slot pool and marks the profile dirty",
		not was_dirty and pools.dirty and pools.profile != null and pools.profile.sets_slot(CLOTHING),
		"dirty %s to %s" % [was_dirty, pools.dirty])
	host.remove_child(pools)
	pools.free()
	AppearanceProfiles.reset()
