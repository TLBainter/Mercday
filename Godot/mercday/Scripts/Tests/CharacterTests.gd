class_name CharacterTests

#The random character builder: the parts library, the appearance resource and its roll, the gradient recolor,
#the baked sheet, the character scene and portrait, the gear icon recolor and the NPC preview atlas.
#Run with the character-tests harness flag.

const CHARACTER_SCENE: String = "res://Scenes/characterScene.tscn"
const PORTRAIT_SCENE: String = "res://Scenes/GUI/Shared/MercPortrait.tscn"
const PREVIEW_DIR: String = "user://character_tests"
const GENDERS: Array[String] = ["F", "M", "K", "U"]
const BODY_GENDERS: Array[String] = ["F", "M", "K"]
const GROUPS: Array[String] = ["skin", "hair", "eyes", "common"]
const KEEP_LINE: String = "importer=\"keep\""
const SHEET_SIZE: Vector2i = Vector2i(576, 384)
const FRAME_SIZE: Vector2i = Vector2i(64, 64)
const ROLLS: int = 200
const BAKES: int = 5
const GEAR_ROLLS: int = 5
const PREVIEW_COUNT: int = 12
const PORTRAIT_SEED: int = 4321
const VIEW_SEED: int = 8765
const SAVE_SEED: int = 7
const SAVE_PATH: String = "user://appearance_test.tres"
const LOG_JSON: String = "res://_logs/npc_preview.json"
const LOG_SEEDS: int = 3
const FAMILY_SEEDS: int = 50
const EARS_FAMILY: String = "TRI_X_SV_Ears_p02"
#A profile name no TSV row uses.
const FAMILY_ANCESTRY: String = "Test Family Ancestry"
#Recolor probe: a base color, its 0.299/0.587/0.114 luminance in 0..255, and a mask key.
const PROBE_RGBA: Vector4i = Vector4i(220, 200, 180, 180)
const PROBE_LUM: int = 204
const PROBE_KEY: Vector3i = Vector3i(10, 20, 30)
const LUM_SLACK: int = 2
#Sheet frames after set_motion(0, 2), set_motion(7, 1) and idle().
const WANT_FRAMES: Array[int] = [2, 13, 0]


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	CharacterParts.reset()
	_case_index(res)
	_case_lookup(res)
	_case_palettes(res)
	_case_odds(res)
	_case_families(res)
	_case_custom_colors(res)
	_case_palette_ramp(res)
	_case_roll(res)
	_case_units(res)
	_case_elements(res)
	_case_log(res)
	_case_save(res)
	_case_generator(res)
	_case_recolor(res)
	_case_bake(res)
	_case_hat_clip(res)
	await _case_sprite(res, host)
	await _case_portrait(res, host)
	_case_gear(res)
	_case_preview(res)
	return TestFixtures.summarize(res, "CHARACTER")


static func _index_parts() -> Array:
	return CharacterParts.index().get("parts", []) as Array


static func _index_slots() -> Array[String]:
	var out: Array[String] = []
	for slot: Variant in CharacterParts.index().get("slots", []) as Array:
		out.append(String(slot))
	return out


static func _opaque(img: Image) -> int:
	return GuiIconTests.count_pixels(img, GuiIconTests.is_opaque)


static func _rgba(c: Color) -> Vector4i:
	return Vector4i(c.r8, c.g8, c.b8, c.a8)


static func _rgba8(img: Image) -> Image:
	var out: Image = img.duplicate() as Image
	if out.get_format() != Image.FORMAT_RGBA8:
		out.convert(Image.FORMAT_RGBA8)
	return out


static func _case_index(res: Dictionary) -> void:
	var index: Dictionary = CharacterParts.index()
	var parts: Array = _index_parts()
	TestFixtures.check(res, "the parts index loads at version 1 with parts listed",
		int(index.get("version", 0)) == 1 and not parts.is_empty(),
		"version %s, %d parts" % [index.get("version"), parts.size()])
	var slots: Array[String] = _index_slots()
	var missing: Array[String] = []
	var twins: Array[String] = []
	var slotless: Array[String] = []
	var genderless: Array[String] = []
	for entry: Variant in parts:
		var part: Dictionary = entry as Dictionary
		var id: String = String(part.get("id", ""))
		var path: String = "%s/%s" % [CharacterParts.ROOT, String(part.get("file", ""))]
		if not FileAccess.file_exists(path):
			missing.append(id)
		elif not FileAccess.file_exists(path + ".import"):
			twins.append(id)
		if not slots.has(String(part.get("slot", ""))):
			slotless.append("%s %s" % [id, part.get("slot")])
		if not GENDERS.has(String(part.get("gender", ""))):
			genderless.append("%s %s" % [id, part.get("gender")])
	TestFixtures.check(res, "every listed part file exists", missing.is_empty(),
		TestFixtures.detail(missing, parts.size(), "parts"))
	TestFixtures.check(res, "every part file has an import twin", twins.is_empty(),
		TestFixtures.detail(twins, parts.size(), "parts"))
	TestFixtures.check(res, "every part names a listed slot", slotless.is_empty(),
		TestFixtures.detail(slotless, parts.size(), "parts"))
	TestFixtures.check(res, "every part is F, M, K or U", genderless.is_empty(),
		TestFixtures.detail(genderless, parts.size(), "parts"))
	var twin_text: String = ""
	if not parts.is_empty():
		var first_file: String = String((parts[0] as Dictionary).get("file", ""))
		twin_text = FileAccess.get_file_as_string("%s/%s.import" % [CharacterParts.ROOT, first_file])
	TestFixtures.check(res, "an import twin keeps the PNG as a plain file", twin_text.contains(KEEP_LINE),
		twin_text.strip_edges().replace("\n", " "))
	var palettes: Dictionary = index.get("palettes", {}) as Dictionary
	var absent: Array[String] = []
	for group: String in GROUPS:
		var entry: Dictionary = palettes.get(group, {}) as Dictionary
		if not FileAccess.file_exists("%s/%s" % [CharacterParts.ROOT, String(entry.get("file", ""))]):
			absent.append(group)
	TestFixtures.check(res, "the index lists a palette file for all four groups", absent.is_empty(),
		TestFixtures.detail(absent, GROUPS.size(), "groups"))


static func _case_lookup(res: Dictionary) -> void:
	var misfit: Array[String] = []
	var empty: Array[String] = []
	for slot: String in _index_slots():
		for gender: String in BODY_GENDERS:
			var options: Array[Dictionary] = CharacterParts.parts(slot, gender)
			if slot == "body" and options.is_empty():
				empty.append(gender)
			for part: Dictionary in options:
				if String(part.get("slot", "")) != slot or not [gender, "U"].has(String(part.get("gender", ""))):
					misfit.append("%s %s %s" % [slot, gender, part.get("id")])
	TestFixtures.check(res, "parts(slot, gender) returns only that slot in that gender or U", misfit.is_empty(),
		TestFixtures.detail(misfit, misfit.size(), "parts"))
	TestFixtures.check(res, "every body gender has at least one body part", empty.is_empty(), "missing %s" % [empty])
	var masked: Dictionary = {}
	var plain: Dictionary = {}
	for entry: Variant in _index_parts():
		var part: Dictionary = entry as Dictionary
		if bool(part.get("has_mask", false)):
			if masked.is_empty():
				masked = part
		elif plain.is_empty():
			plain = part
	var bad: Array[String] = []
	for part: Dictionary in [masked, plain]:
		if part.is_empty():
			continue
		var id: String = String(part["id"])
		if CharacterParts.part(id).get("id") != id:
			bad.append("%s lookup" % id)
		var pair: Array[Image] = CharacterParts.load_pair(id)
		if pair.size() != 2 or pair[0] == null or pair[0].get_size() != SHEET_SIZE:
			bad.append("%s base" % id)
		elif bool(part.get("has_mask", false)) != (pair[1] != null):
			bad.append("%s mask presence" % id)
		elif pair[1] != null and pair[1].get_size() != SHEET_SIZE:
			bad.append("%s mask size" % id)
	TestFixtures.check(res, "part(id) finds a part and load_pair gives a 576x384 base and a mask only when masked",
		bad.is_empty() and not masked.is_empty(), "%s masked %s plain %s" % [bad, masked.get("id"), plain.get("id")])


static func _case_palettes(res: Dictionary) -> void:
	var bad: Array[String] = []
	for group: String in GROUPS:
		var count: int = CharacterParts.palette_rows(group)
		var row: Image = CharacterParts.palette_row(group, 0) if count > 0 else null
		if count <= 0 or row == null or row.get_size() != Vector2i(256, 1):
			bad.append("%s rows %d" % [group, count])
	TestFixtures.check(res, "skin, hair, eyes and common each hold gradient rows 256 wide", bad.is_empty(),
		TestFixtures.detail(bad, GROUPS.size(), "groups"))


static func _sorted(list: Array) -> Array[String]:
	var out: Array[String] = []
	for item: Variant in list:
		out.append(String(item))
	out.sort()
	return out


static func _case_odds(res: Dictionary) -> void:
	var slots: Array[String] = _index_slots()
	var rolled: Array[String] = _sorted(slots.filter(func(slot: String) -> bool:
		return slot != "body" and not (slot in CharacterOdds.PARTNER_SLOTS)))
	var covered: Array[String] = []
	for unit: String in CharacterOdds.UNITS:
		covered.append_array(CharacterOdds.unit_slots(unit))
	var keyed: bool = _sorted(CharacterOdds.UNIT_ODDS.keys()) == _sorted(CharacterOdds.UNITS)
	TestFixtures.check(res, "UNITS cover every slot except body and partners once",
		not rolled.is_empty() and _sorted(covered) == rolled and keyed, "units %s slots %s" % [_sorted(covered), rolled])
	var layers: Array[String] = _sorted(CharacterBaker.LAYER_ORDER)
	TestFixtures.check(res, "LAYER_ORDER draws every slot once", layers == _sorted(slots) and layers.size() == slots.size(),
		"%d layers %d slots" % [layers.size(), slots.size()])


#No pool: the hair link fills both or neither, groups fill one slot, a partnered cloak1 always wears its cloak2.
static func _case_units(res: Dictionary) -> void:
	var half_hair: Array[String] = []
	var both: Array[String] = []
	var cloaks: Array[String] = []
	var cloaked: int = 0
	for seed_i: int in range(1, ROLLS + 1):
		var app: CharacterAppearance = CharacterAppearance.roll(seed_i)
		if app.part_id("hair_front").is_empty() != app.part_id("hair_back").is_empty():
			half_hair.append(str(seed_i))
		for pair: Array in [["glasses", "mask"], ["accessory", "headband"]]:
			if not app.part_id(String(pair[0])).is_empty() and not app.part_id(String(pair[1])).is_empty():
				both.append("%d %s" % [seed_i, pair[0]])
		var back: String = app.part_id("cloak1")
		var front: String = app.part_id("cloak2")
		if back.is_empty():
			if not front.is_empty():
				cloaks.append("%d %s without cloak1" % [seed_i, front])
			continue
		var fam: String = CharacterParts.cloak_partner(CharacterParts.family(back))
		var want: String = CharacterParts.family_member("cloak2", fam, app.gender) if not fam.is_empty() else ""
		cloaked += 1
		if front != want:
			cloaks.append("%d %s wants '%s' has '%s'" % [seed_i, back, want, front])
	TestFixtures.check(res, "the hair link never fills just one of hair_front and hair_back", half_hair.is_empty(),
		TestFixtures.detail(half_hair, ROLLS, "seeds"))
	TestFixtures.check(res, "glasses|mask and accessory|headband never fill both slots", both.is_empty(),
		TestFixtures.detail(both, ROLLS, "seeds"))
	TestFixtures.check(res, "a partnered cloak1 wears its cloak2 and no cloak2 comes alone",
		cloaked > 0 and cloaks.is_empty(), "%d cloaked, %s" % [cloaked, TestFixtures.detail(cloaks, ROLLS, "seeds")])


#Fixture hat: a column at x 10 from y 20 in band 0 and at x 70 from y 80 in band 1, over an opaque hair layer.
static func _case_hat_clip(res: Dictionary) -> void:
	var hat: Image = Image.create_empty(SHEET_SIZE.x, SHEET_SIZE.y, false, Image.FORMAT_RGBA8)
	for y: int in range(20, 40):
		hat.set_pixel(10, y, Color.WHITE)
	for y: int in range(80, 90):
		hat.set_pixel(70, y, Color.WHITE)
	hat.set_pixel(30, 5, Color(1, 1, 1, 0.25))
	var tops: PackedInt32Array = CharacterBaker.tops_of(hat)
	TestFixtures.check(res, "tops_of finds the topmost solid hat pixel per column and band",
		tops.size() == SHEET_SIZE.x * 6 and tops[10] == 20 and tops[SHEET_SIZE.x + 70] == 80 and tops[11] == -1
		and tops[30] == -1 and tops[SHEET_SIZE.x + 10] == -1, "%d tops" % tops.size())
	var hair: Image = Image.create_empty(FRAME_SIZE.x, FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	hair.fill(Color.RED)
	var first: Image = CharacterBaker.clip_under_hat(hair, Rect2i(Vector2i.ZERO, FRAME_SIZE), tops)
	var second: Image = CharacterBaker.clip_under_hat(hair, Rect2i(Vector2i(64, 64), FRAME_SIZE), tops)
	var bad: Array[String] = []
	for y: int in range(FRAME_SIZE.y):
		if (first.get_pixel(10, y).a8 == 0) != (y < 20):
			bad.append("frame 0 x 10 y %d" % y)
		if first.get_pixel(11, y).a8 != 255:
			bad.append("frame 0 x 11 y %d" % y)
		if (second.get_pixel(6, y).a8 == 0) != (y < 16):
			bad.append("frame 1 x 70 y %d" % (y + 64))
		if second.get_pixel(10, y).a8 != 255:
			bad.append("frame 1 x 74 y %d" % (y + 64))
	TestFixtures.check(res, "a clipped layer is empty above the hat top in a hat column and whole in a hatless one",
		bad.is_empty(), TestFixtures.detail(bad, FRAME_SIZE.y * 4, "pixels"))


static func _near(a: Color, b: Color) -> bool:
	return absi(a.r8 - b.r8) <= 2 and absi(a.g8 - b.g8) <= 2 and absi(a.b8 - b.b8) <= 2


static func _case_palette_ramp(res: Dictionary) -> void:
	var color := Color8(200, 80, 40)
	var bad: Array[String] = []
	for rising: bool in [true, false]:
		var template: Image = Image.create_empty(256, 1, false, Image.FORMAT_RGBA8)
		for x: int in range(256):
			var v: float = (x if rising else 255 - x) / 255.0
			template.set_pixel(x, 0, Color.from_hsv(0.6, 0.4 + 0.4 * v, v))
		var ramp: Image = PaletteRamp.generate(template, color)
		if ramp == null or ramp.get_size() != Vector2i(256, 1):
			bad.append("rising %s size" % rising)
			continue
		if not _near(PaletteRamp.mid_color(ramp), color):
			bad.append("rising %s mid %s" % [rising, PaletteRamp.mid_color(ramp)])
		if (ramp.get_pixel(0, 0).v < ramp.get_pixel(255, 0).v) != rising:
			bad.append("rising %s direction" % rising)
	TestFixtures.check(res, "PaletteRamp.generate gives a 256x1 ramp through the color that follows the template",
		bad.is_empty(), "%s" % [bad])


#Restores the custom colors file exactly as found.
static func _case_custom_colors(res: Dictionary) -> void:
	var path: String = CharacterParts.CUSTOM_COLORS_FILE
	var had: bool = FileAccess.file_exists(path)
	var text: String = FileAccess.get_file_as_string(path) if had else ""
	var group: String = "eyes"
	var found: PackedColorArray = CharacterParts.custom_colors(group)
	var rows: int = CharacterParts.palette_rows(group)
	var color := Color8(30, 160, 90)
	var grown: PackedColorArray = found.duplicate()
	grown.append(color)
	var err: Error = CharacterParts.set_custom_colors(group, grown)
	var added: int = CharacterParts.palette_rows(group)
	var ramp: Image = CharacterParts.palette_row(group, rows)
	var ramp_ok: bool = ramp != null and ramp.get_size() == Vector2i(256, 1) and _near(PaletteRamp.mid_color(ramp), color)
	CharacterParts.set_custom_colors(group, found)
	var restored: int = CharacterParts.palette_rows(group)
	if had:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(text)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	CharacterParts.reset()
	TestFixtures.check(res, "a custom color adds a ramped palette row and removing it restores the count",
		err == OK and added == rows + 1 and ramp_ok and restored == rows and CharacterParts.palette_rows(group) == rows,
		"err %d rows %d added %d restored %d ramp %s" % [err, rows, added, restored, ramp_ok])


static func _case_families(res: Dictionary) -> void:
	var members: Array[String] = []
	for g: String in BODY_GENDERS:
		var id: String = CharacterParts.family_member("ears", EARS_FAMILY, g)
		if String(CharacterParts.part(id).get("gender", "")) != g:
			members.append("%s '%s'" % [g, id])
	TestFixtures.check(res, "family() swaps the gender token and family_member resolves each body gender",
		CharacterParts.family("MZ_F_SV_Ears_p02") == "MZ_X_SV_Ears_p02" and members.is_empty(), "%s" % [members])
	var pool := ResolvedPool.new()
	pool.strict = true
	pool.parts = {"ears": {EARS_FAMILY: 1.0}}
	var direct: String = _family_ears_bad(pool)
	TestFixtures.check(res, "a strict family pool gives every roll the ears member of its body gender",
		direct.is_empty(), direct)
	AppearanceProfiles.reset()
	var p := AppearanceProfile.new()
	p.kind = "ancestry"
	p.profile_name = FAMILY_ANCESTRY
	p.part_weights = {"ears": {"TRI_F_SV_Ears_p02": 1.0}}
	AppearanceProfiles.set_override("ancestry", FAMILY_ANCESTRY, p)
	var resolved: ResolvedPool = AppearanceRules.resolve_names(FAMILY_ANCESTRY, "", "")
	resolved.strict = true
	var raw: String = _family_ears_bad(resolved)
	TestFixtures.check(res, "a raw part id key resolves to its family and rolls the same way",
		resolved.parts.get("ears") == {EARS_FAMILY: 1.0} and raw.is_empty(), "%s %s" % [resolved.parts, raw])
	AppearanceProfiles.reset()


static func _family_ears_bad(pool: ResolvedPool) -> String:
	var bad: Array[String] = []
	for seed_i: int in range(1, FAMILY_SEEDS + 1):
		var app: CharacterAppearance = CharacterAppearance.roll(seed_i, false, pool)
		var id: String = app.part_id("ears")
		if id.is_empty() or String(CharacterParts.part(id).get("gender", "")) != app.gender:
			bad.append("%d %s '%s'" % [seed_i, app.gender, id])
	return "" if bad.is_empty() else TestFixtures.detail(bad, FAMILY_SEEDS, "seeds")


static func _row_ok(group: String, row: int) -> bool:
	return GROUPS.has(group) and row >= 0 and row < CharacterParts.palette_rows(group)


static func _case_roll(res: Dictionary) -> void:
	var first: CharacterAppearance = CharacterAppearance.roll(1)
	var again: CharacterAppearance = CharacterAppearance.roll(1)
	TestFixtures.check(res, "roll(seed) is deterministic", first.to_dict() == again.to_dict(),
		"%d elements %d shared" % [first.elements.size(), first.shared_colors.size()])
	var other: CharacterAppearance = CharacterAppearance.roll(2)
	var looks: Array[Dictionary] = [first.to_dict(), other.to_dict()]
	TestFixtures.check(res, "two seeds roll different looks",
		looks[0]["parts"] != looks[1]["parts"] or looks[0]["colors"] != looks[1]["colors"],
		"seed 1 %s seed 2 %s" % [(looks[0]["parts"] as Dictionary).values(), (looks[1]["parts"] as Dictionary).values()])
	TestFixtures.check(res, "from_dict(to_dict) gives the same look",
		CharacterAppearance.from_dict(first.to_dict()).to_dict() == first.to_dict(), "seed 1")
	var bodiless: Array[String] = []
	var misfit: Array[String] = []
	var beards: Array[String] = []
	var bad_colors: Array[String] = []
	var genders: Dictionary = {}
	var bearded: int = 0
	for seed_i: int in range(1, ROLLS + 1):
		var app: CharacterAppearance = CharacterAppearance.roll(seed_i)
		genders[app.gender] = int(genders.get(app.gender, 0)) + 1
		if app.element("body") == null:
			bodiless.append(str(seed_i))
		for el: AppearanceElement in app.elements:
			var part: Dictionary = CharacterParts.part(el.part_id)
			if part.is_empty() or String(part.get("slot", "")) != el.slot \
					or not [app.gender, "U"].has(String(part.get("gender", ""))):
				misfit.append("%d %s %s on %s" % [seed_i, el.slot, el.part_id, app.gender])
			for color_key: Variant in el.colors:
				var entry: Dictionary = el.row_for(String(color_key), app.shared_colors)
				if not _row_ok(String(entry.get("group", "")), int(entry.get("row", -1))):
					bad_colors.append("%d %s %s %s" % [seed_i, el.part_id, color_key, entry])
		if app.element("beard") != null:
			bearded += 1
			if CharacterOdds.NO_BEARD.has(app.gender):
				beards.append("%d %s" % [seed_i, app.gender])
		for group: Variant in app.shared_colors:
			if not _row_ok(String(group), int(app.shared_colors[group])):
				bad_colors.append("%d shared %s %d" % [seed_i, group, int(app.shared_colors[group])])
	TestFixtures.check(res, "every roll has a body part", bodiless.is_empty(),
		TestFixtures.detail(bodiless, ROLLS, "seeds"))
	TestFixtures.check(res, "rolled parts sit in their slot and fit the body gender", misfit.is_empty(),
		TestFixtures.detail(misfit, ROLLS, "seeds"))
	TestFixtures.check(res, "no F or K roll wears a beard and some M rolls do", beards.is_empty() and bearded > 0,
		"%d bearded; %s" % [bearded, TestFixtures.detail(beards, ROLLS, "seeds")])
	TestFixtures.check(res, "every rolled color names a group and a row inside its palette", bad_colors.is_empty(),
		TestFixtures.detail(bad_colors, ROLLS, "seeds"))
	TestFixtures.check(res, "F, M and K bodies all come up over %d rolls" % ROLLS,
		BODY_GENDERS.all(func(g: String) -> bool: return int(genders.get(g, 0)) > 0), "%s" % [genders])


static func _case_elements(res: Dictionary) -> void:
	var uncovered: Array[String] = []
	var unshared: Array[String] = []
	var parents: Array[String] = []
	var disorder: Array[String] = []
	for seed_i: int in range(1, ROLLS + 1):
		var app: CharacterAppearance = CharacterAppearance.roll(seed_i)
		for group: String in CharacterOdds.SHARED_GROUPS:
			if not _row_ok(group, int(app.shared_colors.get(group, -1))):
				parents.append("%d %s %s" % [seed_i, group, app.shared_colors.get(group)])
		var layers: Array[int] = []
		for el: AppearanceElement in app.elements:
			layers.append(CharacterBaker.LAYER_ORDER.find(el.slot))
			for region: Variant in CharacterParts.part(el.part_id).get("regions", []):
				var key_text: String = CharacterAppearance.region_key((region as Dictionary).get("key", []))
				if not el.colors.has(key_text):
					uncovered.append("%d %s %s" % [seed_i, el.part_id, key_text])
					continue
				var entry: Dictionary = el.colors[key_text]
				var shared: bool = String(entry.get("group", "")) in CharacterOdds.SHARED_GROUPS
				var row: int = int(entry.get("row", -1))
				if (shared and row != -1) or (not shared and not _row_ok(String(entry.get("group", "")), row)):
					unshared.append("%d %s %s %s" % [seed_i, el.part_id, key_text, entry])
		var sorted_layers: Array[int] = layers.duplicate()
		sorted_layers.sort()
		if layers != sorted_layers or layers.has(-1):
			disorder.append("%d %s" % [seed_i, app.slots()])
	TestFixtures.check(res, "every element names a color for every mask region of its part", uncovered.is_empty(),
		TestFixtures.detail(uncovered, ROLLS, "seeds"))
	TestFixtures.check(res, "shared regions store row -1 and other regions a palette row", unshared.is_empty(),
		TestFixtures.detail(unshared, ROLLS, "seeds"))
	TestFixtures.check(res, "the parent holds a valid skin, hair and eyes row", parents.is_empty(),
		TestFixtures.detail(parents, ROLLS, "seeds"))
	TestFixtures.check(res, "elements sit in LAYER_ORDER", disorder.is_empty(), TestFixtures.detail(disorder, ROLLS, "seeds"))


#Seeds 1..LOG_SEEDS against the committed preview listing, compared through JSON so number types match.
static func _case_log(res: Dictionary) -> void:
	if not FileAccess.file_exists(LOG_JSON):
		TestFixtures.check(res, "the preview listing is absent so the log comparison is skipped", true, LOG_JSON)
		return
	var listing: Variant = JSON.parse_string(FileAccess.get_file_as_string(LOG_JSON))
	var bad: Array[String] = []
	for seed_i: int in range(1, LOG_SEEDS + 1):
		var want: Variant = (listing as Dictionary).get(str(seed_i)) if listing is Dictionary else null
		var got: Variant = JSON.parse_string(JSON.stringify(CharacterAppearance.roll(seed_i).to_dict()))
		if want == null or got != want:
			bad.append(str(seed_i))
	TestFixtures.check(res, "seeds 1..%d roll the looks listed in npc_preview.json" % LOG_SEEDS, bad.is_empty(),
		TestFixtures.detail(bad, LOG_SEEDS, "seeds"))


static func _case_save(res: Dictionary) -> void:
	var app: CharacterAppearance = CharacterAppearance.roll(SAVE_SEED)
	var err: Error = ResourceSaver.save(app, SAVE_PATH)
	var text: String = FileAccess.get_file_as_string(SAVE_PATH)
	var loaded: CharacterAppearance = null
	if err == OK:
		loaded = ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as CharacterAppearance
	var typed: bool = loaded != null and not loaded.elements.is_empty() \
		and loaded.elements.all(func(el: Variant) -> bool: return el is AppearanceElement)
	TestFixtures.check(res, "ResourceSaver round trip keeps the look with elements as embedded sub-resources",
		loaded != null and typed and loaded.to_dict() == app.to_dict() and text.count("[sub_resource") == app.elements.size()
		and text.count("[ext_resource") == 2,
		"err %d, %d elements, %d sub-resources" % [err, app.elements.size(), text.count("[sub_resource")])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var edited: CharacterAppearance = CharacterAppearance.roll(1)
	var first_key: String = edited.cache_key()
	edited.shared_colors["skin"] = (int(edited.shared_colors.get("skin", 0)) + 1) % CharacterParts.palette_rows("skin")
	var fresh: bool = CharacterBaker.texture(edited) != CharacterBaker.texture(CharacterAppearance.roll(1))
	TestFixtures.check(res, "an edited appearance changes its cache key and bakes a fresh texture",
		edited.cache_key() != first_key and fresh,
		"%s to %s" % [first_key, edited.cache_key()])


static func _case_generator(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var merc: MercenaryData = MercGenerator.generate(0)
	var app: CharacterAppearance = merc.appearance if merc != null else null
	TestFixtures.check(res, "a generated merc carries a rolled appearance with elements and its seed",
		app != null and not app.elements.is_empty() and app.rng_seed == merc.appearance_seed and merc.appearance_seed != 0,
		"seed %d, %d elements" % [merc.appearance_seed if merc != null else -1, app.elements.size() if app != null else -1])
	var pool: ResolvedPool = AppearanceRules.resolve(merc)
	TestFixtures.check(res, "the generated appearance is the roll of its seed over its resolved pool",
		app != null and app.to_dict() == CharacterAppearance.roll(merc.appearance_seed, true, pool).to_dict()
		and (app.gender == CharacterOdds.KID_BODY) == pool.force_kid,
		"gender %s, force_kid %s" % [app.gender if app != null else "none", pool.force_kid])
	var templates: Array = DataManager.npc_templates.values()
	var npc: MercenaryData = NPCGenerator.generate(templates[0] as NPCTemplate) if not templates.is_empty() else null
	var npc_app: CharacterAppearance = npc.appearance if npc != null else null
	var npc_pool: ResolvedPool = AppearanceRules.resolve(npc)
	TestFixtures.check(res, "a generated NPC carries the roll of its appearance seed over its resolved pool",
		npc_app != null and not npc_app.elements.is_empty() and npc_app.rng_seed == npc.appearance_seed
		and npc_app.to_dict() == CharacterAppearance.roll(npc.appearance_seed, true, npc_pool).to_dict(),
		"%d templates, seed %d" % [templates.size(), npc.appearance_seed if npc != null else -1])
	TestFixtures.reset_campaign()


#A 256x1 gray ramp, rising from black when rising, else falling from white.
static func _ramp(rising: bool) -> Image:
	var img: Image = Image.create_empty(256, 1, false, Image.FORMAT_RGBA8)
	for x: int in range(256):
		var v: int = x if rising else 255 - x
		img.set_pixel(x, 0, Color8(v, v, v, 255))
	return img


#Pixels: 0 masked probe, 1 white mask, 2 transparent base under a key, 3 transparent mask.
static func _recolor_probe(rising: bool) -> Array[Vector4i]:
	var base: Image = Image.create_empty(4, 1, false, Image.FORMAT_RGBA8)
	var mask: Image = Image.create_empty(4, 1, false, Image.FORMAT_RGBA8)
	var probe := Color8(PROBE_RGBA.x, PROBE_RGBA.y, PROBE_RGBA.z, PROBE_RGBA.w)
	var opaque := Color8(PROBE_RGBA.x, PROBE_RGBA.y, PROBE_RGBA.z, 255)
	var key := Color8(PROBE_KEY.x, PROBE_KEY.y, PROBE_KEY.z, 255)
	base.set_pixel(0, 0, probe)
	base.set_pixel(1, 0, opaque)
	base.set_pixel(2, 0, Color(0, 0, 0, 0))
	base.set_pixel(3, 0, opaque)
	mask.set_pixel(0, 0, key)
	mask.set_pixel(1, 0, Color.WHITE)
	mask.set_pixel(2, 0, key)
	mask.set_pixel(3, 0, Color(0, 0, 0, 0))
	var rows: Dictionary = {CharacterAppearance.region_key([PROBE_KEY.x, PROBE_KEY.y, PROBE_KEY.z]): _ramp(rising)}
	var out: Image = CharacterBaker.recolor(base, mask, Rect2i(0, 0, 4, 1), rows)
	var got: Array[Vector4i] = []
	if out == null or out.get_size() != Vector2i(4, 1):
		return got
	for x: int in range(4):
		got.append(_rgba(out.get_pixel(x, 0)))
	return got


static func _near_lum(px: Vector4i) -> bool:
	return absi(px.x - PROBE_LUM) <= LUM_SLACK and absi(px.y - PROBE_LUM) <= LUM_SLACK \
		and absi(px.z - PROBE_LUM) <= LUM_SLACK


static func _case_recolor(res: Dictionary) -> void:
	var rising: Array[Vector4i] = _recolor_probe(true)
	var opaque := Vector4i(PROBE_RGBA.x, PROBE_RGBA.y, PROBE_RGBA.z, 255)
	TestFixtures.check(res, "recolor leaves white-masked, transparent and unmasked pixels alone",
		rising.size() == 4 and rising[1] == opaque and rising[2].w == 0 and rising[3] == opaque, "%s" % [rising])
	TestFixtures.check(res, "recolor maps a masked pixel by luminance and keeps its alpha",
		rising.size() == 4 and _near_lum(rising[0]) and rising[0].w == PROBE_RGBA.w,
		"%s want gray %d alpha %d" % [rising[0] if rising.size() == 4 else Vector4i(), PROBE_LUM, PROBE_RGBA.w])
	var falling: Array[Vector4i] = _recolor_probe(false)
	TestFixtures.check(res, "a row lighter at x 0 is read from the light end so light stays light",
		falling.size() == 4 and _near_lum(falling[0]) and falling[0].w == PROBE_RGBA.w,
		"%s want gray %d" % [falling[0] if falling.size() == 4 else Vector4i(), PROBE_LUM])


static func _case_bake(res: Dictionary) -> void:
	var bad: Array[String] = []
	for seed_i: int in range(1, BAKES + 1):
		var idle: Image = CharacterBaker.bake_frame(CharacterAppearance.roll(seed_i), 0, 0)
		if idle == null or idle.get_size() != FRAME_SIZE or _opaque(idle) == 0:
			bad.append("%d %s" % [seed_i, idle.get_size() if idle != null else Vector2i(-1, -1)])
	TestFixtures.check(res, "bake_frame gives a 64x64 idle frame with opaque pixels", bad.is_empty(),
		TestFixtures.detail(bad, BAKES, "seeds"))
	var app: CharacterAppearance = CharacterAppearance.roll(1)
	var sheet: Image = CharacterBaker.bake_sheet(app)
	TestFixtures.check(res, "bake_sheet gives a 576x384 RGBA8 sheet",
		sheet != null and sheet.get_size() == SHEET_SIZE and sheet.get_format() == Image.FORMAT_RGBA8,
		"%s" % [sheet.get_size() if sheet != null else Vector2i(-1, -1)])
	var frame: Image = CharacterBaker.bake_frame(app, 0, 0)
	var same: bool = sheet != null and frame != null \
		and _rgba8(sheet.get_region(Rect2i(Vector2i.ZERO, FRAME_SIZE))).get_data() == _rgba8(frame).get_data()
	TestFixtures.check(res, "the idle frame matches the top-left cell of the sheet", same, "seed 1")
	var tex: ImageTexture = CharacterBaker.texture(app)
	TestFixtures.check(res, "texture(app) returns one cached texture per seed",
		tex != null and CharacterBaker.texture(app) == tex and CharacterBaker.texture(CharacterAppearance.roll(1)) == tex,
		"%s" % [tex])


static func _find_sprite(root: Node) -> CharacterSprite:
	if root is CharacterSprite:
		return root as CharacterSprite
	for child: Node in root.get_children():
		var found: CharacterSprite = _find_sprite(child)
		if found != null:
			return found
	return null


static func _case_sprite(res: Dictionary, host: Node) -> void:
	TestFixtures.check(res, "motion 0 frame 2 is frame index 2 and motion 7 frame 1 is 1 * 9 + 4",
		CharacterSprite.frame_index(0, 2) == 2 and CharacterSprite.frame_index(7, 1) == 13,
		"%d %d" % [CharacterSprite.frame_index(0, 2), CharacterSprite.frame_index(7, 1)])
	var scene: PackedScene = load(CHARACTER_SCENE) as PackedScene
	var sprite: CharacterSprite = scene.instantiate() as CharacterSprite if scene != null else null
	TestFixtures.check(res, "characterScene.tscn roots a CharacterSprite", sprite != null, CHARACTER_SCENE)
	if sprite == null:
		return
	host.add_child(sprite)
	await TestFixtures.frames(host, 1)
	var sheet: Sprite2D = sprite.get_node_or_null("Sheet") as Sprite2D
	var frames: Array[int] = []
	if sheet != null:
		sprite.set_motion(0, 2)
		frames.append(sheet.frame)
		sprite.set_motion(7, 1)
		frames.append(sheet.frame)
		sprite.idle()
		frames.append(sheet.frame)
	TestFixtures.check(res, "the Sheet sprite is a 9x6 grid that set_motion and idle drive",
		sheet != null and sheet.hframes == 9 and sheet.vframes == 6 and frames == WANT_FRAMES,
		"frames %s" % [frames])
	var app: CharacterAppearance = CharacterAppearance.roll(3)
	sprite.set_appearance(app)
	TestFixtures.check(res, "set_appearance shows the baked texture",
		sheet != null and sheet.texture != null and sheet.texture == CharacterBaker.texture(app), "seed 3")
	var prop: CharacterAppearance = CharacterAppearance.roll(4)
	sprite.appearance = prop
	TestFixtures.check(res, "setting the appearance property shows its baked texture",
		sheet != null and sprite.appearance == prop and sheet.texture == CharacterBaker.texture(prop), "seed 4")
	sprite.appearance = null
	TestFixtures.check(res, "clearing the appearance property clears the texture",
		sheet != null and sheet.texture == null, "%s" % [sheet.texture if sheet != null else null])
	var fresh_x: float = sprite.scale.x
	sprite.face_right = false
	TestFixtures.check(res, "a fresh sprite faces right by a root flip and face_right off unflips it",
		fresh_x == -1.0 and sprite.scale.x == 1.0 and sheet != null and not sheet.flip_h,
		"fresh %f off %f" % [fresh_x, sprite.scale.x])
	sprite.queue_free()
	await TestFixtures.frames(host, 1)


static func _case_portrait(res: Dictionary, host: Node) -> void:
	var scene: PackedScene = load(PORTRAIT_SCENE) as PackedScene
	var face: MercPortrait = scene.instantiate() as MercPortrait if scene != null else null
	if face == null:
		TestFixtures.check(res, "the merc portrait scene loads", false, PORTRAIT_SCENE)
		return
	host.add_child(face)
	await TestFixtures.frames(host, 1)
	var view := MercView.new()
	view.uid = 91
	view.name = "Builder Probe"
	view.appearance_seed = PORTRAIT_SEED
	face.set_merc(view)
	var sprite: CharacterSprite = _find_sprite(face)
	var app: CharacterAppearance = sprite.appearance if sprite != null else null
	var sheet: Sprite2D = sprite.get_node_or_null("Sheet") as Sprite2D if sprite != null else null
	TestFixtures.check(res, "the portrait shows the baked texture of the merc appearance seed",
		app != null and app.rng_seed == PORTRAIT_SEED and sheet != null and sheet.texture == CharacterBaker.texture(app, true),
		"sprite %s seed %d" % [sprite != null, app.rng_seed if app != null else -1])
	var held := MercView.new()
	held.uid = 92
	held.name = "Resource Probe"
	held.appearance_seed = PORTRAIT_SEED
	held.appearance = CharacterAppearance.roll(VIEW_SEED, true)
	face.set_merc(held)
	TestFixtures.check(res, "the portrait shows the view's own appearance resource over its seed",
		sprite != null and sprite.appearance == held.appearance and sheet != null
		and sheet.texture == CharacterBaker.texture(held.appearance, true),
		"seed %d" % [sprite.appearance.rng_seed if sprite != null and sprite.appearance != null else -1])
	TestFixtures.check(res, "the portrait's character faces right",
		sprite != null and sprite.scale.x == -1.0, "scale.x %f" % [sprite.scale.x if sprite != null else 0.0])
	face.queue_free()
	await TestFixtures.frames(host, 1)


static func _case_gear(res: Dictionary) -> void:
	var atlases: Array[Dictionary] = GearIconBaker.atlases()
	TestFixtures.check(res, "the gear atlas index lists atlases", not atlases.is_empty(), "%d atlases" % atlases.size())
	var bad: Array[String] = []
	var off_palette: Array[String] = []
	var common_rows: int = CharacterParts.palette_rows(GearIconBaker.PALETTE_GROUP)
	for i: int in range(GEAR_ROLLS):
		var rng := RandomNumberGenerator.new()
		rng.seed = i + 1
		var icon: Dictionary = GearIconBaker.random_icon(rng)
		var colors: Dictionary = icon.get("colors", {})
		if colors.is_empty():
			off_palette.append("%d no colors" % (i + 1))
		for key_name: Variant in colors:
			var pick: Dictionary = colors[key_name] if colors[key_name] is Dictionary else {}
			var row: int = int(pick.get("row", -1))
			if not GearIconBaker.MASK_KEYS.has(key_name) or String(pick.get("group", "")) != GearIconBaker.PALETTE_GROUP \
					or row < 0 or row >= common_rows:
				off_palette.append("%d %s %s" % [i + 1, key_name, pick])
		var img: Image = icon.get("image") as Image
		if img == null:
			bad.append("%d no image" % (i + 1))
			continue
		var rect: Rect2i = icon.get("rect", Rect2i())
		var plain: Image = GearIconBaker.icon(String(icon.get("atlas", "")), rect, {})
		if plain == null or plain.get_size() != img.get_size() or img.get_size() != rect.size:
			bad.append("%d size %s" % [i + 1, img.get_size()])
			continue
		var base: Image = _rgba8(plain)
		var changed: int = GuiIconTests.count_pixels(_rgba8(img),
			func(x: int, y: int, px: Color) -> bool: return _rgba(px) != _rgba(base.get_pixel(x, y)))
		if changed == 0:
			bad.append("%d %s unchanged" % [i + 1, icon.get("atlas")])
	TestFixtures.check(res, "random_icon recolors masked pixels of a rect-sized icon", bad.is_empty(),
		TestFixtures.detail(bad, GEAR_ROLLS, "icons"))
	TestFixtures.check(res, "random_icon colors are common palette rows in range for mask keys",
		off_palette.is_empty() and common_rows > 0,
		"%d rows; %s" % [common_rows, TestFixtures.detail(off_palette, GEAR_ROLLS, "icons")])


static func _case_preview(res: Dictionary) -> void:
	var made: Dictionary = NpcPreview.write(PREVIEW_COUNT, PREVIEW_DIR)
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(String(made.get("path", ""))))
	var cell: int = CharacterBaker.FRAME_SIZE * NpcPreview.SCALE
	var rows: int = ceili(PREVIEW_COUNT / float(NpcPreview.COLUMNS))
	var want := Vector2i(NpcPreview.COLUMNS * cell + (NpcPreview.COLUMNS + 1) * NpcPreview.GAP,
		rows * cell + (rows + 1) * NpcPreview.GAP)
	TestFixtures.check(res, "the NPC preview writes a 10 column atlas of 2x cells",
		bool(made.get("ok", false)) and img != null and img.get_size() == want,
		"%s want %s %s" % [img.get_size() if img != null else Vector2i(-1, -1), want, made.get("errors")])
	var listing: Variant = JSON.parse_string(FileAccess.get_file_as_string(String(made.get("json", ""))))
	TestFixtures.check(res, "the preview json lists every seed",
		listing is Dictionary and (listing as Dictionary).size() == PREVIEW_COUNT and (listing as Dictionary).has("1"),
		"%d entries" % ((listing as Dictionary).size() if listing is Dictionary else -1))
