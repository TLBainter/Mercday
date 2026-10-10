class_name GuiFilterTests

#The shared trait filter atoms: ChipRow, ModuleTile, StarRangePicker, FilterSection, FilterGroup and
#TraitFilterPanel, plus the FilterCheckRow hover look. Every case renders real TraitFilterDefs rows,
#so a change to the def table shows up here instead of in a screen. Run with the gui-filter-tests
#harness flag.

const CHIP_SCENE: String = "res://Scenes/GUI/Shared/ChipRow.tscn"
const TILE_SCENE: String = "res://Scenes/GUI/Shared/ModuleTile.tscn"
const STARS_SCENE: String = "res://Scenes/GUI/Shared/StarRangePicker.tscn"
const SECTION_SCENE: String = "res://Scenes/GUI/Shared/FilterSection.tscn"
const GROUP_SCENE: String = "res://Scenes/GUI/Shared/FilterGroup.tscn"
const PANEL_SCENE: String = "res://Scenes/GUI/Shared/TraitFilterPanel.tscn"
const CHECK_ROW_SCENE: String = "res://Scenes/GUI/Shared/FilterCheckRow.tscn"
const SPONSOR_TYPE: StringName = &"sponsor"
const DIRECT_TYPE: StringName = &"direct"
const PLANS_TARGET: Dictionary = {"page": "plans", "upgrade": "guildpromo"}
const TILE_RELATION: int = 2
#The rows the campaign builder offers, in the order its panel draws them.
const BUILDER_ROWS: Array[StringName] = [&"salary", &"tradition", &"ancestry", &"vigor", &"speed",
	&"dexterity", &"cognition", &"wile"]
#The rows only applicant review in Hiring narrows by, which the builder never carries.
const REVIEW_ONLY_ROWS: Array[StringName] = [&"bloodline", &"heritage", &"criminality", &"age",
	&"knowledges", &"tools"]
const VIA_ROW: StringName = &"from"
const VALUE_GROUP: String = "Value"
const IDENTITY_GROUP: String = "Identity"
const PHYSICAL_GROUP: String = "Physical"
const MENTAL_GROUP: String = "Mental"
const BUILDER_GROUPS: Dictionary = {
	VALUE_GROUP: [&"salary"],
	IDENTITY_GROUP: [&"tradition", &"ancestry"],
	PHYSICAL_GROUP: [&"vigor", &"speed", &"dexterity"],
	MENTAL_GROUP: [&"cognition", &"wile"],
}
const UNKNOWN_GROUP: String = "Nowhere"
#The prefix the old placeholder ancestry names carried; no real ancestry name starts with it.
const PLACEHOLDER_ANCESTRY: String = "Ancestry "
#The pad of the box a headed group draws around a section, and the rounding a layout check allows.
const BOX_PAD: float = 8.0
const GEOMETRY_SLACK: float = 0.5
#Travel ratio and the salary the track gives there, each pinned within TABLE_SLACK notes.
const SALARY_TABLE: Array = [[0.0, 1.0], [0.1, 29.0], [0.2, 58.0], [0.3, 86.0], [0.35, 100.0], [0.5, 181.0],
	[0.7, 406.0], [1.0, 999.0]]
const TABLE_SLACK: float = 1.0
const RATIO_SLACK: float = 0.001
const VALUE_SLACK: float = 0.5
const CURVE_SAMPLES: int = 100
#A salary off the grid and the stop it snaps onto.
const SALARY_SNAPS: Array = [[101.0, 100.0], [102.0, 100.0], [103.0, 105.0], [104.0, 105.0], [996.0, 995.0],
	[997.0, 995.0], [998.0, 999.0]]
#A held salary, whether the arrow rises, and the step the salary track takes from there.
const SALARY_ARROWS: Array = [[99.0, true, 1.0], [99.0, false, 1.0], [100.0, true, 5.0], [100.0, false, 1.0],
	[105.0, true, 5.0], [105.0, false, 5.0]]
#The high salary thumb pressed at 99, then the arrows right, right, left and left, and the salary after each.
const JOIN_RISING: Array[bool] = [true, true, false, false]
const JOIN_WALK: Array[float] = [99.0, 100.0, 105.0, 100.0, 99.0]
const TRACK_WIDTH: float = 400.0


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	ContractResourceBuilder.build_all()
	SubscriptionManager.max_out()
	await _case_chip_row(res, host)
	await _case_module_tile(res, host)
	await _case_star_range_picker(res, host)
	await _case_star_locked_ends(res, host)
	await _case_section_numbers(res, host)
	await _case_salary_curve(res, host)
	await _case_section_chips(res, host)
	await _case_section_mods(res, host)
	await _case_section_locks(res, host)
	await _case_filter_group(res, host)
	await _case_section_boxes(res, host)
	_case_builder_rows(res)
	await _case_ancestry_chips(res, host)
	await _case_panel_merc(res, host)
	await _case_panel_builder(res, host)
	await _case_panel_accordion(res, host)
	await _case_panel_stale(res, host)
	await _case_panel_contract(res, host)
	await _case_check_row_hover(res, host)
	SubscriptionManager.max_out()
	return TestFixtures.summarize(res, "GUI FILTER")


static func _section(host: Node, def: Dictionary, ents: Dictionary) -> FilterSection:
	var section: FilterSection = (load(SECTION_SCENE) as PackedScene).instantiate()
	host.add_child(section)
	await host.get_tree().process_frame
	section.setup(def, FilterSection.default_value(def), ents)
	await host.get_tree().process_frame
	return section


#The titles of the groups a panel shows open, in draw order.
static func _open_titles(panel: TraitFilterPanel) -> Array[String]:
	var out: Array[String] = []
	for group: FilterGroup in panel.groups():
		if group.is_open():
			out.append(group.title)
	return out


static func _case_chip_row(res: Dictionary, host: Node) -> void:
	var chips: ChipRow = (load(CHIP_SCENE) as PackedScene).instantiate()
	var rows: Array[Dictionary] = [
		{"key": &"a", "label": "Alpha"},
		{"key": &"b", "label": "Beta"},
		{"key": &"c", "label": "Gamma", "enabled": false, "note": "No radio coverage"},
	]
	chips.options = rows
	host.add_child(chips)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a chip row builds one chip per option",
		chips.chip_count() == 3, "got %d" % chips.chip_count())
	var seen: Array = []
	chips.selection_changed.connect(func(sel: Array) -> void: seen.append(sel.duplicate()))
	chips.press_chip(&"a")
	chips.press_chip(&"b")
	TestFixtures.check(res, "multi mode keeps every pressed chip",
		chips.selected == [&"a", &"b"] and seen.size() == 2, "sel %s" % str(chips.selected))
	chips.press_chip(&"a")
	TestFixtures.check(res, "a second press clears that chip",
		chips.selected == [&"b"] and seen.size() == 3, "sel %s" % str(chips.selected))
	chips.press_chip(&"c")
	TestFixtures.check(res, "a disabled option never changes the selection",
		chips.selected == [&"b"] and seen.size() == 3, "sel %s" % str(chips.selected))
	var blocked: Button = chips.chip_for(&"c")
	TestFixtures.check(res, "a disabled chip carries its note as the tooltip",
		blocked != null and blocked.tooltip_text == "No radio coverage",
		"tip %s" % ("null" if blocked == null else blocked.tooltip_text))
	TestFixtures.check(res, "a disabled chip is dimmed",
		blocked != null and is_equal_approx(blocked.modulate.a, ChipRow.DISABLED_ALPHA),
		"alpha %s" % ("none" if blocked == null else str(blocked.modulate.a)))
	chips.set_selected([&"a"])
	TestFixtures.check(res, "set_selected marks chips without emitting",
		chips.is_on(&"a") and seen.size() == 3, "sel %s" % str(chips.selected))
	chips.multi = false
	chips.press_chip(&"b")
	TestFixtures.check(res, "single mode replaces the pick",
		chips.selected == [&"b"], "sel %s" % str(chips.selected))
	chips.press_chip(&"b")
	TestFixtures.check(res, "single mode clears on a second press",
		chips.selected.is_empty(), "sel %s" % str(chips.selected))
	TestFixtures.check(res, "an unknown key has no chip index",
		chips.index_of(&"zz") == -1 and chips.chip_for(&"zz") == null,
		"idx %d" % chips.index_of(&"zz"))
	chips.queue_free()
	var dots: ChipRow = (load(CHIP_SCENE) as PackedScene).instantiate()
	var dot_rows: Array[Dictionary] = [{"key": &"t", "label": "Tradition",
		"color": Color("#f28c28")}]
	dots.options = dot_rows
	host.add_child(dots)
	await host.get_tree().process_frame
	var dotted: Button = dots.chip_for(&"t")
	TestFixtures.check(res, "a coloured option gets the tradition dot",
		dotted != null and dotted.icon != null, "icon missing")
	dots.queue_free()


static func _case_module_tile(res: Dictionary, host: Node) -> void:
	var tile: ModuleTile = (load(TILE_SCENE) as PackedScene).instantiate()
	tile.key = &"t0"
	tile.label = "Assassinate"
	tile.image_note = "Contract Image"
	tile.received = 5
	tile.completed = 3
	tile.failed = 1
	tile.relationship = TILE_RELATION
	host.add_child(tile)
	await host.get_tree().process_frame
	var square: Vector2 = Vector2(ModuleTile.TILE_SIDE, ModuleTile.TILE_SIDE)
	var needed: float = tile.rows.get_combined_minimum_size().y + 2.0 * ModuleTile.PAD_PX
	TestFixtures.check(res, "a module tile is a %d px square" % int(ModuleTile.TILE_SIDE),
		tile.custom_minimum_size == square and tile.size == square and needed <= ModuleTile.TILE_SIDE,
		"needs %s of %s, size %s" % [needed, ModuleTile.TILE_SIDE, tile.size])
	var hits: Array = []
	tile.pressed_tile.connect(func(k: Variant) -> void: hits.append(k))
	tile.press_tile()
	TestFixtures.check(res, "a module tile reports its key on a press",
		hits == [&"t0"], "hits %s" % str(hits))
	var received: Label = tile.get_node("Rows/Stats/Received/Row/Value")
	var failed: Label = tile.get_node("Rows/Stats/Failed/Row/Value")
	TestFixtures.check(res, "the tile prints the contract history it was given",
		received.text == "5" and failed.text == "1",
		"got %s and %s" % [received.text, failed.text])
	var placeholder: Label = tile.get_node("Rows/Top/ImageBox/ImageLabel")
	TestFixtures.check(res, "a tile without art shows the image caption",
		placeholder.visible and placeholder.text == "Contract Image", "cap %s" % placeholder.text)
	tile.set_selected(true)
	var mark: TextureRect = tile.get_node("Rows/Top/Side/Check/Mark")
	TestFixtures.check(res, "a picked tile checks its box",
		tile.selected and mark.visible, "selected %s" % str(tile.selected))
	var face: MoodFace = tile.relationship_face()
	TestFixtures.check(res, "an open relationship shows the guild face",
		face != null and face.visible and face.guild and face.opinion == TILE_RELATION
		and not tile.relationship_lock().visible,
		"opinion %s" % (str(face.opinion) if face != null else "missing"))
	tile.relationship_open = false
	tile.refresh()
	TestFixtures.check(res, "a closed relationship shows the upgrade lock instead",
		tile.relationship_lock() != null and tile.relationship_lock().visible
		and face != null and not face.visible, "lock state wrong")
	tile.relationship = ModuleTile.NO_RELATION
	tile.refresh()
	TestFixtures.check(res, "a module with no relationship hides the face and the lock",
		face != null and not face.visible and not tile.relationship_lock().visible,
		"face or lock still shown")
	tile.disabled_reason = TraitFilterDefs.NO_PERMIT_NOTE
	tile.refresh()
	tile.press_tile()
	TestFixtures.check(res, "a blocked tile cannot be picked",
		tile.is_blocked() and hits.size() == 1, "hits %d" % hits.size())
	TestFixtures.check(res, "a blocked tile is dimmed and names the reason",
		is_equal_approx(tile.modulate.a, ModuleTile.BLOCKED_ALPHA)
		and tile.tooltip_text == TraitFilterDefs.NO_PERMIT_NOTE, "alpha %s" % str(tile.modulate.a))
	var note: Label = tile.get_node("Rows/Note")
	TestFixtures.check(res, "the blocked reason shows under the module name",
		note.visible and note.text == TraitFilterDefs.NO_PERMIT_NOTE and not tile.stats.visible,
		"note %s, counts shown %s" % [note.text, tile.stats.visible])
	tile.queue_free()


static func _case_star_range_picker(res: Dictionary, host: Node) -> void:
	var picker: StarRangePicker = (load(STARS_SCENE) as PackedScene).instantiate()
	host.add_child(picker)
	await host.get_tree().process_frame
	var pairs: Array = []
	picker.range_changed.connect(func(lo: float, hi: float) -> void: pairs.append([lo, hi]))
	picker.set_range(TraitFilterDefs.MIN_STARS, TraitFilterDefs.MAX_STARS)
	TestFixtures.check(res, "set_range writes both ends without emitting",
		is_equal_approx(picker.low, 0.5) and is_equal_approx(picker.high, 5.0) and pairs.is_empty(),
		"low %s high %s" % [str(picker.low), str(picker.high)])
	picker.press_star(StarRangePicker.ROW_MIN, 3.0)
	TestFixtures.check(res, "pressing a Min star moves the low end and emits",
		is_equal_approx(picker.low, 3.0) and is_equal_approx(picker.high, 5.0) and pairs.size() == 1,
		"low %s high %s" % [str(picker.low), str(picker.high)])
	picker.press_star(StarRangePicker.ROW_MAX, 2.0)
	TestFixtures.check(res, "a Max press below Min pushes Min down",
		is_equal_approx(picker.low, 2.0) and is_equal_approx(picker.high, 2.0),
		"low %s high %s" % [str(picker.low), str(picker.high)])
	picker.press_star(StarRangePicker.ROW_MIN, 4.5)
	TestFixtures.check(res, "a Min press above Max pushes Max up on a half step",
		is_equal_approx(picker.low, 4.5) and is_equal_approx(picker.high, 4.5),
		"low %s high %s" % [str(picker.low), str(picker.high)])
	picker.press_star(StarRangePicker.ROW_MIN, 0.2)
	TestFixtures.check(res, "a value below the first half star clamps to 0.5",
		is_equal_approx(picker.low, 0.5), "low %s" % str(picker.low))
	TestFixtures.check(res, "each row paints in its own difficulty colour",
		picker.row_color(StarRangePicker.ROW_MAX)
		== Icons.star_color(picker.row_value(StarRangePicker.ROW_MAX), false), "colour differs")
	var width: float = picker.custom_minimum_size.x
	TestFixtures.check(res, "the picker asks for the width of both star blocks",
		width > 270.0 and width < 285.0, "width %s" % str(width))
	TestFixtures.check(res, "the default picker draws 16 px stars",
		picker.star_scale == StarRangePicker.DEFAULT_STAR_SCALE
			and is_equal_approx(picker._star_px(), 16.0),
		"scale %d star %s" % [picker.star_scale, str(picker._star_px())])
	picker.star_scale = 2
	await host.get_tree().process_frame
	TestFixtures.check(res, "star_scale 2 draws 32 px stars across 452 px",
		is_equal_approx(picker._star_px(), 32.0)
			and is_equal_approx(picker.custom_minimum_size.x, 452.0),
		"star %s width %s" % [str(picker._star_px()), str(picker.custom_minimum_size.x)])
	var star_x: float = picker._stars_x(StarRangePicker.ROW_MIN)
	var left_half: Vector2 = picker._hit(Vector2(star_x + 51.0, 0.0))
	TestFixtures.check(res, "at star_scale 2 the left half of the second star reads 1.5",
		int(left_half.x) == StarRangePicker.ROW_MIN and is_equal_approx(left_half.y, 1.5),
		"hit %s" % str(left_half))
	var right_half: Vector2 = picker._hit(Vector2(star_x + 56.0, 0.0))
	TestFixtures.check(res, "at star_scale 2 the right half of the second star reads 2.0",
		int(right_half.x) == StarRangePicker.ROW_MIN and is_equal_approx(right_half.y, 2.0),
		"hit %s" % str(right_half))
	picker.star_scale = StarRangePicker.DEFAULT_STAR_SCALE
	await host.get_tree().process_frame
	var locks: Array[Dictionary] = [_star_lock("Min Difficulty", 2), {}]
	picker.set_row_locks(locks)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a row lock shows only on the row it names",
		picker.is_row_locked(StarRangePicker.ROW_MIN)
		and not picker.is_row_locked(StarRangePicker.ROW_MAX)
		and picker.lock_for(StarRangePicker.ROW_MIN).visible
		and not picker.lock_for(StarRangePicker.ROW_MAX).visible, "lock visibility wrong")
	var before: float = picker.low
	var count: int = pairs.size()
	picker.press_star(StarRangePicker.ROW_MIN, 1.0)
	TestFixtures.check(res, "a locked row never moves",
		is_equal_approx(picker.low, before) and pairs.size() == count, "low %s" % str(picker.low))
	picker.press_star(StarRangePicker.ROW_MAX, 3.0)
	TestFixtures.check(res, "the open row still moves while the other is locked",
		is_equal_approx(picker.high, 3.0) and pairs.size() == count + 1,
		"high %s" % str(picker.high))
	var relayed: Array = []
	picker.take_me_there.connect(func(t: Dictionary) -> void: relayed.append(t))
	picker.lock_for(StarRangePicker.ROW_MIN).take_me_there.emit(PLANS_TARGET)
	TestFixtures.check(res, "a row lock relays Take Me There upward",
		relayed.size() == 1 and relayed[0] == PLANS_TARGET, "relayed %s" % str(relayed))
	picker.queue_free()


#One Guild Promo row lock in the shape TraitFilterDefs builds for a stars2 row.
static func _star_lock(feature: String, tier: int) -> Dictionary:
	return {"feature": feature, "upgrade": "Guild Promo",
		"upgrade_id": TraitFilterDefs.GUILD_PROMO_ID, "tier": tier,
		"tiers": UpgradeDefs.display_tiers(TraitFilterDefs.GUILD_PROMO_ID), "verb": "target"}


#A locked row keeps its pinned end whatever a stored pair or a press on the other row asks for.
static func _case_star_locked_ends(res: Dictionary, host: Node) -> void:
	var picker: StarRangePicker = (load(STARS_SCENE) as PackedScene).instantiate()
	host.add_child(picker)
	await host.get_tree().process_frame
	var pairs: Array = []
	picker.range_changed.connect(func(lo: float, hi: float) -> void: pairs.append([lo, hi]))
	var min_locked: Array[Dictionary] = [_star_lock("Min Difficulty", 2), {}]
	picker.set_row_locks(min_locked)
	await host.get_tree().process_frame
	picker.set_range(2.0, 3.0)
	TestFixtures.check(res, "a stored pair cannot move the locked Min row off the floor",
		is_equal_approx(picker.low, StarRangePicker.MIN_VALUE)
			and is_equal_approx(picker.high, 3.0) and pairs.is_empty(),
		"low %s high %s" % [str(picker.low), str(picker.high)])
	picker.press_star(StarRangePicker.ROW_MIN, 4.0)
	TestFixtures.check(res, "a press on the locked Min row changes nothing and emits nothing",
		is_equal_approx(picker.low, StarRangePicker.MIN_VALUE)
			and is_equal_approx(picker.high, 3.0) and pairs.is_empty(),
		"low %s high %s emits %d" % [str(picker.low), str(picker.high), pairs.size()])
	picker.press_star(StarRangePicker.ROW_MAX, 1.0)
	TestFixtures.check(res, "a Max press that would push the locked Min stops at the floor",
		is_equal_approx(picker.low, StarRangePicker.MIN_VALUE)
			and is_equal_approx(picker.high, 1.0) and pairs.size() == 1,
		"low %s high %s emits %d" % [str(picker.low), str(picker.high), pairs.size()])
	var max_locked: Array[Dictionary] = [{}, _star_lock("Max Difficulty", 3)]
	picker.set_row_locks(max_locked)
	await host.get_tree().process_frame
	picker.set_range(1.5, 2.5)
	TestFixtures.check(res, "a stored pair cannot move the locked Max row off the ceiling",
		is_equal_approx(picker.low, 1.5)
			and is_equal_approx(picker.high, StarRangePicker.MAX_VALUE) and pairs.size() == 1,
		"low %s high %s" % [str(picker.low), str(picker.high)])
	picker.press_star(StarRangePicker.ROW_MIN, 4.5)
	TestFixtures.check(res, "a Min press leaves the locked Max row on the ceiling",
		is_equal_approx(picker.low, 4.5)
			and is_equal_approx(picker.high, StarRangePicker.MAX_VALUE) and pairs.size() == 2,
		"low %s high %s emits %d" % [str(picker.low), str(picker.high), pairs.size()])
	picker.queue_free()


static func _case_section_numbers(res: Dictionary, host: Node) -> void:
	SubscriptionManager.max_out()
	var ents: Dictionary = SubscriptionManager.entitlements()
	var defs: Array[Dictionary] = TraitFilterDefs.merc_defs(true)
	var salary_def: Dictionary = TraitFilterDefs.find(defs, &"salary")
	var salary: FilterSection = await _section(host, salary_def, ents)
	TestFixtures.check(res, "a slider2 row renders a dual slider",
		salary.kind() == TraitFilterDefs.KIND_SLIDER2 and not salary.is_locked()
		and salary.dual_slider() != null, "kind %s" % salary.kind())
	var dual: DualSlider = salary.dual_slider()
	TestFixtures.check(res, "the dual slider takes its bounds from the def",
		is_equal_approx(dual.min_value, TraitFilterDefs.SALARY_MIN) and is_equal_approx(dual.max_value,
		TraitFilterDefs.SALARY_MAX) and is_equal_approx(dual.step, TraitFilterDefs.SALARY_STEP),
		"min %s max %s step %s" % [str(dual.min_value), str(dual.max_value), str(dual.step)])
	var seen: Array = []
	salary.value_changed.connect(func(k: StringName, v: Variant) -> void: seen.append([k, v]))
	salary.set_value([250.0, 750.0])
	TestFixtures.check(res, "set_value moves the slider without emitting",
		is_equal_approx(dual.low, 250.0) and is_equal_approx(dual.high, 750.0) and seen.is_empty(),
		"low %s high %s" % [str(dual.low), str(dual.high)])
	TestFixtures.check(res, "a narrowed salary range counts as active",
		salary.is_active(), "not active")
	salary.press_value([TraitFilterDefs.SALARY_MIN, TraitFilterDefs.SALARY_MAX])
	TestFixtures.check(res, "press_value reports the def key and the new pair",
		seen.size() == 1 and seen[0][0] == &"salary" and not salary.is_active(),
		"seen %s" % str(seen))
	var low_label: Label = salary.get_node("Body/Values/Low")
	TestFixtures.check(res, "the low label prints the bottom of the range and the unit",
		low_label.text == "1 / mo", "low %s" % low_label.text)
	var high_label: Label = salary.get_node("Body/Values/High")
	TestFixtures.check(res, "the high label prints the top of the range",
		high_label.text == "999 / mo", "high %s" % high_label.text)
	salary.queue_free()
	var age_def: Dictionary = TraitFilterDefs.find(defs, &"age")
	var age: FilterSection = await _section(host, age_def, ents)
	TestFixtures.check(res, "a range row renders a dual slider on the def bounds",
		age.dual_slider() != null and is_equal_approx(age.dual_slider().min_value,
		TraitFilterDefs.AGE_MIN) and is_equal_approx(age.dual_slider().max_value,
		TraitFilterDefs.AGE_MAX), "age bounds wrong")
	age.queue_free()
	var vigor_def: Dictionary = TraitFilterDefs.find(defs, &"vigor")
	var vigor: FilterSection = await _section(host, vigor_def, ents)
	TestFixtures.check(res, "a min row renders one pixel slider",
		vigor.min_slider() != null and vigor.dual_slider() == null
		and vigor.title_text() == "Min Vigor", "title %s" % vigor.title_text())
	var moves: Array = []
	vigor.value_changed.connect(func(_k: StringName, v: Variant) -> void: moves.append(v))
	vigor.press_value(4.0)
	TestFixtures.check(res, "a min row stores a single number and counts as active",
		is_equal_approx(float(vigor.value()), 4.0) and vigor.is_active() and moves.size() == 1,
		"value %s" % str(vigor.value()))
	TestFixtures.check(res, "the min label prints the lower bound with a plus",
		(vigor.get_node("Body/Values/Low") as Label).text == "4+",
		"label %s" % (vigor.get_node("Body/Values/Low") as Label).text)
	vigor.set_value(TraitFilterDefs.STAT_MIN)
	TestFixtures.check(res, "a min row at its floor filters nothing",
		not vigor.is_active() and moves.size() == 1, "active with the floor value")
	vigor.queue_free()


static func _case_salary_curve(res: Dictionary, host: Node) -> void:
	var curve: SalaryCurve = SalaryCurve.new()
	var lo: float = TraitFilterDefs.SALARY_MIN
	var hi: float = TraitFilterDefs.SALARY_MAX
	var ends: Array[float] = [curve.value_of(0.0, lo, hi), curve.value_of(SalaryCurve.LOW_SHARE, lo, hi),
		curve.value_of(1.0, lo, hi)]
	TestFixtures.check(res, "the salary track starts at 1, reaches 100 at the join and ends at 999",
		is_equal_approx(ends[0], SalaryCurve.SALARY_MIN) and is_equal_approx(ends[1], SalaryCurve.LOW_TOP)
			and is_equal_approx(ends[2], SalaryCurve.SALARY_MAX), str(ends))
	var misses: Array = []
	for row: Array in SALARY_TABLE:
		var at: float = curve.value_of(float(row[0]), lo, hi)
		if absf(at - float(row[1])) > TABLE_SLACK:
			misses.append([row[0], at])
	TestFixtures.check(res, "the salary track meets the design table within one note",
		misses.is_empty(), str(misses))
	var increasing: bool = true
	var last: float = ends[0]
	var worst_ratio: float = absf(curve.ratio_of(last, lo, hi))
	for i: int in range(1, CURVE_SAMPLES + 1):
		var t: float = float(i) / CURVE_SAMPLES
		var v: float = curve.value_of(t, lo, hi)
		increasing = increasing and v > last
		last = v
		worst_ratio = maxf(worst_ratio, absf(curve.ratio_of(v, lo, hi) - t))
	TestFixtures.check(res, "the salary track rises at every step of its travel", increasing,
		"a sample did not rise")
	TestFixtures.check(res, "a travel ratio maps to a salary and back to the same ratio",
		worst_ratio <= RATIO_SLACK, "worst %.6f" % worst_ratio)
	var stops: Array[float] = _salary_stops()
	var on_stop: Dictionary = {}
	for stop: float in stops:
		on_stop[stop] = true
	var worst_value: float = 0.0
	var strays: Array = []
	for whole: int in range(int(lo), int(hi) + 1):
		var pay: float = float(whole)
		worst_value = maxf(worst_value, absf(curve.value_of(curve.ratio_of(pay, lo, hi), lo, hi) - pay))
		if not on_stop.has(curve.snap(pay, lo, hi, TraitFilterDefs.SALARY_STEP)):
			strays.append(whole)
	TestFixtures.check(res, "a salary maps to a ratio and back to the same salary",
		worst_value <= VALUE_SLACK, "worst %.4f" % worst_value)
	var moved: Array = []
	for stop: float in stops:
		if curve.snap(stop, lo, hi, TraitFilterDefs.SALARY_STEP) != stop:
			moved.append(stop)
	TestFixtures.check(res, "every salary stop snaps to itself", moved.is_empty(), str(moved))
	TestFixtures.check(res, "every whole salary snaps onto a stop", strays.is_empty(), str(strays))
	var off: Array = []
	for row: Array in SALARY_SNAPS:
		var landed: float = curve.snap(float(row[0]), lo, hi, TraitFilterDefs.SALARY_STEP)
		if landed != float(row[1]):
			off.append([row[0], landed])
	TestFixtures.check(res, "a salary between stops snaps onto the stop the table names",
		off.is_empty(), str(off))
	var wrong: Array = []
	for row: Array in SALARY_ARROWS:
		var stride: float = curve.step_at(float(row[0]), bool(row[1]), TraitFilterDefs.SALARY_STEP)
		if stride != float(row[2]):
			wrong.append([row[0], row[1], stride])
	TestFixtures.check(res, "arrows step one note below 100 and five above it, and 100 falls by one",
		wrong.is_empty(), str(wrong))
	SubscriptionManager.max_out()
	var defs: Array[Dictionary] = TraitFilterDefs.merc_defs(true)
	var salary_row: FilterSection = await _section(host, TraitFilterDefs.find(defs, &"salary"),
		SubscriptionManager.entitlements())
	var dual: DualSlider = salary_row.dual_slider()
	TestFixtures.check(res, "the salary row slider runs on the salary curve",
		dual != null and dual.curve is SalaryCurve, "no salary curve on the slider")
	if dual == null:
		salary_row.queue_free()
		return
	salary_row.set_value([lo, SalaryCurve.LOW_TOP])
	TestFixtures.check(res, "the thumb for 100 sits at the join of the salary track",
		is_equal_approx(dual.high_ratio(), SalaryCurve.LOW_SHARE), "ratio %.4f" % dual.high_ratio())
	salary_row.set_value([lo, JOIN_WALK[0]])
	dual.size = Vector2(TRACK_WIDTH, dual.size.y)
	var press: Vector2 = Vector2(dual.size.x * dual.high_ratio(), 0.0)
	dual._gui_input(GuiAtomTests._mouse_button(press, true))
	var walk: Array[float] = [dual.high]
	for up: bool in JOIN_RISING:
		dual._gui_input(GuiAtomTests._key(KEY_RIGHT if up else KEY_LEFT))
		walk.append(dual.high)
	dual._gui_input(GuiAtomTests._mouse_button(press, false))
	TestFixtures.check(res, "arrow keys walk the high thumb from 99 to 100 to 105 and back down",
		walk == JOIN_WALK, str(walk))
	salary_row.queue_free()


#Every salary the track can rest on: each note up to LOW_TOP, then every COARSE_STEP, then SALARY_MAX.
static func _salary_stops() -> Array[float]:
	var out: Array[float] = []
	for fine: int in range(int(SalaryCurve.SALARY_MIN), int(SalaryCurve.LOW_TOP) + 1):
		out.append(float(fine))
	var coarse: int = int(SalaryCurve.COARSE_STEP)
	for stop: int in range(int(SalaryCurve.LOW_TOP) + coarse, int(SalaryCurve.SALARY_MAX), coarse):
		out.append(float(stop))
	out.append(SalaryCurve.SALARY_MAX)
	return out


static func _case_section_chips(res: Dictionary, host: Node) -> void:
	SubscriptionManager.max_out()
	var ents: Dictionary = SubscriptionManager.entitlements()
	var defs: Array[Dictionary] = TraitFilterDefs.merc_defs(true)
	var trad_def: Dictionary = TraitFilterDefs.find(defs, &"tradition")
	var trad: FilterSection = await _section(host, trad_def, ents)
	var traditions: Array[String] = TraitFilterDefs.traditions()
	TestFixtures.check(res, "a trad row renders one chip per tradition",
		trad.chip_row() != null and trad.chip_row().chip_count() == traditions.size(),
		"count %d" % (0 if trad.chip_row() == null else trad.chip_row().chip_count()))
	TestFixtures.check(res, "tradition chips carry their tradition colour",
		trad.chip_row().chip_for(traditions[0]).icon != null, "no dot")
	var picks: Array = []
	trad.value_changed.connect(func(_k: StringName, v: Variant) -> void: picks.append(v))
	trad.chip_row().press_chip(traditions[0])
	trad.chip_row().press_chip(traditions[1])
	TestFixtures.check(res, "a chip press flows into the section value",
		trad.value() == [traditions[0], traditions[1]] and picks.size() == 2,
		"value %s" % str(trad.value()))
	TestFixtures.check(res, "a chip row with a pick counts as active",
		trad.is_active(), "not active")
	trad.set_value([])
	TestFixtures.check(res, "clearing a chip row leaves it inactive and silent",
		not trad.is_active() and trad.chip_row().selected.is_empty() and picks.size() == 2,
		"value %s" % str(trad.value()))
	trad.queue_free()
	var from_def: Dictionary = TraitFilterDefs.find(defs, &"from")
	var from: FilterSection = await _section(host, from_def, ents)
	TestFixtures.check(res, "the Applied Via row lists the walk-in chip",
		from.chip_row() != null and from.chip_row().chip_count() == 1
		and from.chip_row().index_of(TraitFilterDefs.WALK_IN) == 0, "walk-in chip missing")
	from.chip_row().press_chip(TraitFilterDefs.WALK_IN)
	TestFixtures.check(res, "the walk-in chip stores its own value",
		from.value() == [TraitFilterDefs.WALK_IN], "value %s" % str(from.value()))
	from.queue_free()
	var know_def: Dictionary = TraitFilterDefs.find(defs, &"knowledges")
	var know: FilterSection = await _section(host, know_def, ents)
	TestFixtures.check(res, "a chips row renders every placeholder option",
		know.chip_row() != null
		and know.chip_row().chip_count() == TraitFilterDefs.KNOWLEDGE_COUNT,
		"count %d" % (0 if know.chip_row() == null else know.chip_row().chip_count()))
	TestFixtures.check(res, "a plain chips row is multi pick",
		know.chip_row().multi, "single pick")
	know.queue_free()
	var contract_defs: Array[Dictionary] = TraitFilterDefs.contract_defs(SPONSOR_TYPE)
	var target_def: Dictionary = TraitFilterDefs.find(contract_defs, &"target")
	var target: FilterSection = await _section(host, target_def, ents)
	TestFixtures.check(res, "a one row is a single pick chip row that says pick 1",
		target.chip_row() != null and not target.chip_row().multi
		and target.title_text().ends_with(FilterSection.PICK_ONE_NOTE), "%s" % target.title_text())
	target.chip_row().press_chip("Company 1")
	TestFixtures.check(res, "a one row stores the bare pick, not a list",
		String(target.value()) == "Company 1", "value %s" % str(target.value()))
	target.chip_row().press_chip("Company 1")
	TestFixtures.check(res, "a second press on the pick empties a one row",
		target.value() == null and not target.is_active(), "value %s" % str(target.value()))
	target.queue_free()
	var direct_defs: Array[Dictionary] = TraitFilterDefs.contract_defs(DIRECT_TYPE)
	var direct_def: Dictionary = TraitFilterDefs.find(direct_defs, &"target")
	var direct: FilterSection = await _section(host, direct_def, ents)
	TestFixtures.check(res, "the Advertise To row is a multi pick chip row with no pick 1 note",
		direct.chip_row() != null and direct.chip_row().multi
		and direct.title_text() == "Advertise To"
		and direct.value() == [], "%s %s" % [direct.title_text(), str(direct.value())])
	TestFixtures.check(res, "the Advertise To row holds one chip per company",
		direct.chip_row().chip_count() == TraitFilterDefs.COMPANY_COUNT,
		"count %d" % direct.chip_row().chip_count())
	direct.chip_row().press_chip("Company 1")
	direct.chip_row().press_chip("Company 3")
	TestFixtures.check(res, "two Advertise To chips stay on together",
		direct.value() == ["Company 1", "Company 3"] and direct.is_active(),
		"value %s" % str(direct.value()))
	direct.chip_row().press_chip("Company 1")
	TestFixtures.check(res, "dropping one Advertise To chip keeps the other on",
		direct.value() == ["Company 3"] and direct.is_active(),
		"value %s" % str(direct.value()))
	direct.queue_free()


static func _case_section_mods(res: Dictionary, host: Node) -> void:
	SubscriptionManager.max_out()
	var ents: Dictionary = SubscriptionManager.entitlements()
	var defs: Array[Dictionary] = TraitFilterDefs.contract_defs(SPONSOR_TYPE)
	var ctype_def: Dictionary = TraitFilterDefs.find(defs, &"ctype")
	var ctype: FilterSection = await _section(host, ctype_def, ents)
	TestFixtures.check(res, "a mods row renders one module tile per option",
		ctype.tiles().size() == TraitFilterDefs.contract_type_count()
		and TraitFilterDefs.contract_type_count() > 0,
		"tiles %d" % ctype.tiles().size())
	TestFixtures.check(res, "a module tile takes its name from the mods row",
		ctype.tiles()[0].label == "Assassinate", "name %s" % ctype.tiles()[0].label)
	var labels: Array[String] = []
	for shown: ModuleTile in ctype.tiles():
		labels.append(shown.label)
	TestFixtures.check(res, "the Contract Type tiles carry the real type names in library order",
		labels == ["Assassinate", "Entertain", "Escort", "Investigate", "Military",
		"Monster Hunt", "Rescue", "Treasure Hunt"], "%s" % [labels])
	var picks: Array = []
	ctype.value_changed.connect(func(_k: StringName, v: Variant) -> void: picks.append(v))
	ctype.tiles()[1].press_tile()
	TestFixtures.check(res, "a tile press stores its value on the section",
		ctype.value() == [1] and ctype.tiles()[1].selected and picks.size() == 1,
		"value %s" % str(ctype.value()))
	ctype.tiles()[1].press_tile()
	TestFixtures.check(res, "a second tile press drops that pick",
		ctype.value() == [] and not ctype.tiles()[1].selected, "value %s" % str(ctype.value()))
	TestFixtures.check(res, "a mods row with no single flag is multi pick",
		not ctype.tiles()[0].single, "single pick")
	TestFixtures.check(res, "contract type modules carry no relationship face or lock",
		ctype.tiles()[0].relationship == ModuleTile.NO_RELATION
		and not ctype.tiles()[0].relationship_face().visible
		and not ctype.tiles()[0].relationship_lock().visible,
		"rel %d" % ctype.tiles()[0].relationship)
	var loc_def: Dictionary = TraitFilterDefs.find(defs, &"loc")
	var loc: FilterSection = await _section(host, loc_def, ents)
	var rows: Array = loc_def["mods"]
	TestFixtures.check(res, "the locations row renders every location module",
		loc.tiles().size() == rows.size(), "tiles %d of %d" % [loc.tiles().size(), rows.size()])
	var blocked_ok: bool = true
	for i: int in range(rows.size()):
		var row: Dictionary = rows[i]
		if loc.tiles()[i].is_blocked() != bool(row.get("disabled", false)):
			blocked_ok = false
	TestFixtures.check(res, "a location without its permit renders blocked",
		blocked_ok, "a tile disagrees with its mods row")
	TestFixtures.check(res, "location modules show their relationship when it is open",
		loc.tiles()[0].relationship != ModuleTile.NO_RELATION
		and loc.tiles()[0].relationship_open and loc.tiles()[0].relationship_face().visible
		and not loc.tiles()[0].relationship_lock().visible, "relationship closed")
	SubscriptionManager.changed.emit()
	await host.get_tree().process_frame
	var type_lock: bool = ctype.tiles()[0].relationship_lock().visible
	var loc_lock: bool = loc.tiles()[0].relationship_lock().visible
	TestFixtures.check(res, "a subscription change keeps the lock off tiles with no relationship or an open one",
		not type_lock and not loc_lock, "lock shown: contract type %s, location %s" % [type_lock, loc_lock])
	ctype.queue_free()
	loc.queue_free()
	SubscriptionManager.set_entitlements({"clientOpinion": false})
	var shut: FilterSection = await _section(host, loc_def, SubscriptionManager.entitlements())
	TestFixtures.check(res, "without Customer Satisfaction the relationship shows locked",
		not shut.tiles()[0].relationship_open
		and shut.tiles()[0].relationship_lock().visible
		and not shut.tiles()[0].relationship_face().visible, "relationship still open")
	shut.queue_free()
	SubscriptionManager.max_out()
	var diff_def: Dictionary = TraitFilterDefs.find(defs, &"diff")
	var diff: FilterSection = await _section(host, diff_def, SubscriptionManager.entitlements())
	TestFixtures.check(res, "a stars2 row renders the star range picker",
		diff.star_picker() != null and not diff.is_active(), "no picker")
	var pairs: Array = []
	diff.value_changed.connect(func(_k: StringName, v: Variant) -> void: pairs.append(v))
	diff.star_picker().press_star(StarRangePicker.ROW_MIN, 2.5)
	TestFixtures.check(res, "a star press stores the pair on the section",
		pairs.size() == 1 and is_equal_approx(float((diff.value() as Array)[0]), 2.5)
		and diff.is_active(), "value %s" % str(diff.value()))
	diff.queue_free()


static func _case_section_locks(res: Dictionary, host: Node) -> void:
	SubscriptionManager.max_out()
	SubscriptionManager.set_entitlements({"hiringDiscrim": false, "brawn": false})
	var ents: Dictionary = SubscriptionManager.entitlements()
	var defs: Array[Dictionary] = TraitFilterDefs.merc_defs(true)
	var anc_def: Dictionary = TraitFilterDefs.find(defs, &"ancestry")
	var anc: FilterSection = await _section(host, anc_def, ents)
	TestFixtures.check(res, "a locked row builds no widget at all",
		anc.is_locked() and anc.chip_row() == null
		and (anc.get_node("Body") as VBoxContainer).get_child_count() == 0, "body not empty")
	TestFixtures.check(res, "a locked row keeps its title and shows the lock",
		anc.title_text() == "Ancestry" and anc.section_lock().visible
		and anc.section_lock().label == "Locked", "lock hidden")
	TestFixtures.check(res, "the lock names the feature the row filters by",
		anc.section_lock().feature == "Ancestry" and anc.section_lock().verb == anc.lock_verb,
		"feature %s" % anc.section_lock().feature)
	TestFixtures.check(res, "a locked row never counts as active",
		not anc.is_active(), "counted as active")
	var relayed: Array = []
	anc.take_me_there.connect(func(t: Dictionary) -> void: relayed.append(t))
	anc.section_lock().take_me_there.emit(PLANS_TARGET)
	TestFixtures.check(res, "a section lock relays Take Me There upward",
		relayed.size() == 1 and relayed[0] == PLANS_TARGET, "relayed %s" % str(relayed))
	anc.queue_free()
	var vigor_def: Dictionary = TraitFilterDefs.find(defs, &"vigor")
	var vigor: FilterSection = await _section(host, vigor_def, ents)
	TestFixtures.check(res, "the lock strips the Min prefix from a stat row",
		vigor.is_locked() and vigor.section_lock().feature == "Vigor"
		and vigor.min_slider() == null, "feature %s" % vigor.section_lock().feature)
	vigor.queue_free()
	SubscriptionManager.max_out()
	var open: FilterSection = await _section(host, anc_def, SubscriptionManager.entitlements())
	TestFixtures.check(res, "an entitled row pins its lock out of the layout",
		not open.is_locked() and not open.section_lock().visible
		and not open.section_lock().always_visible, "lock still visible")
	open.queue_free()
	var free_ents: Dictionary = {"plan": TraitFilterDefs.PLAN_RANKS[0]}
	var speed_def: Dictionary = TraitFilterDefs.find(defs, &"speed")
	var speed: FilterSection = await _section(host, speed_def, free_ents)
	TestFixtures.check(res, "a plan rank below the row locks it",
		speed.is_locked() and speed.section_lock().visible, "open on the free plan")
	speed.queue_free()
	var diff_def: Dictionary = TraitFilterDefs.find(TraitFilterDefs.contract_defs(SPONSOR_TYPE),
		&"diff")
	var tiered: FilterSection = await _section(host, diff_def,
		{"gpMinDifficulty": false, "gpMaxDifficulty": true})
	TestFixtures.check(res, "a stars2 row locks one star row at a time",
		tiered.star_picker() != null
		and tiered.star_picker().is_row_locked(StarRangePicker.ROW_MIN)
		and not tiered.star_picker().is_row_locked(StarRangePicker.ROW_MAX), "row locks wrong")
	TestFixtures.check(res, "a locked star row names its own feature",
		tiered.star_picker().lock_for(StarRangePicker.ROW_MIN).feature == "Min Difficulty",
		"feature %s" % tiered.star_picker().lock_for(StarRangePicker.ROW_MIN).feature)
	var up: Array = []
	tiered.take_me_there.connect(func(t: Dictionary) -> void: up.append(t))
	tiered.star_picker().lock_for(StarRangePicker.ROW_MIN).take_me_there.emit(PLANS_TARGET)
	TestFixtures.check(res, "a star row lock relays through the section",
		up.size() == 1, "relayed %s" % str(up))
	tiered.queue_free()
	SubscriptionManager.max_out()


static func _case_filter_group(res: Dictionary, host: Node) -> void:
	var group: FilterGroup = (load(GROUP_SCENE) as PackedScene).instantiate()
	group.title = TraitFilterDefs.GROUPS[0]
	group.expanded = false
	host.add_child(group)
	await host.get_tree().process_frame
	var body: PanelContainer = group.get_node("Body")
	var badge: PanelContainer = group.get_node("Head/Row/Badge")
	TestFixtures.check(res, "a closed group hides its body",
		not group.is_open() and not body.visible, "body shown")
	var opens: Array = []
	group.toggled_open.connect(func(o: bool) -> void: opens.append(o))
	group.toggle()
	TestFixtures.check(res, "toggling a group opens it and reports it",
		group.is_open() and body.visible and opens == [true], "opens %s" % str(opens))
	group.set_count(3)
	TestFixtures.check(res, "a group badge shows the active count",
		badge.visible and group.count() == 3
		and (group.get_node("Head/Row/Badge/Count") as Label).text == "3",
		"count %d" % group.count())
	group.set_count(0)
	TestFixtures.check(res, "a group with nothing active shows no badge",
		not badge.visible, "badge shown")
	group.set_open(false)
	TestFixtures.check(res, "set_open closes a group without reporting it",
		not group.is_open() and opens.size() == 1, "opens %s" % str(opens))
	var section: FilterSection = (load(SECTION_SCENE) as PackedScene).instantiate()
	group.add_section(section)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a group holds the sections added to it",
		group.sections().size() == 1, "sections %d" % group.sections().size())
	group.clear_sections()
	TestFixtures.check(res, "clear_sections empties the body",
		group.sections().is_empty(), "sections %d" % group.sections().size())
	group.queue_free()
	var bare: FilterGroup = (load(GROUP_SCENE) as PackedScene).instantiate()
	bare.headless = true
	host.add_child(bare)
	await host.get_tree().process_frame
	var head: Button = bare.get_node("Head")
	var bare_opens: Array = []
	bare.toggled_open.connect(func(o: bool) -> void: bare_opens.append(o))
	bare.toggle()
	TestFixtures.check(res, "a headless group has no header and never closes",
		not head.visible and bare.is_open() and bare_opens.is_empty(), "headless group toggled")
	bare.queue_free()
	var caret: ImageTexture = FilterGroup.caret_texture(true, FilterGroup.CARET_COLOR)
	var shut: ImageTexture = FilterGroup.caret_texture(false, FilterGroup.CARET_COLOR)
	TestFixtures.check(res, "the open caret points down and the closed one points right",
		caret != null and caret.get_size() == Vector2(10, 6)
		and shut != null and shut.get_size() == Vector2(6, 10),
		"open %s shut %s" % [str(caret.get_size()), str(shut.get_size())])
	TestFixtures.check(res, "the caret texture is cached per direction",
		FilterGroup.caret_texture(true, FilterGroup.CARET_COLOR) == caret and shut != caret,
		"cache wrong")


static func _case_section_boxes(res: Dictionary, host: Node) -> void:
	SubscriptionManager.max_out()
	var ents: Dictionary = SubscriptionManager.entitlements()
	var defs: Array[Dictionary] = TraitFilterDefs.merc_defs(false)
	var panel: TraitFilterPanel = (load(PANEL_SCENE) as PackedScene).instantiate()
	host.add_child(panel)
	await host.get_tree().process_frame
	panel.set_defs(defs, {}, ents)
	await host.get_tree().process_frame
	var identity: FilterGroup = panel.group_for(IDENTITY_GROUP)
	var children: Array[Node] = identity.body().get_children()
	var boxed: int = 0
	for child: Node in children:
		if child is PanelContainer and child.get_child_count() == 1:
			if child.get_child(0) is FilterSection:
				boxed += 1
	TestFixtures.check(res, "a headed group holds each of its sections in a box of its own",
		children.size() == 2 and boxed == 2 and identity.sections().size() == 2,
		"%d children, %d boxed" % [children.size(), boxed])
	var tradition: FilterSection = panel.section_for("tradition")
	var box: PanelContainer = tradition.get_parent() as PanelContainer
	var style: StyleBox = box.get_theme_stylebox(&"panel")
	TestFixtures.check(res, "each box wears the tile style with the same pad on every side",
		style == FilterGroup.STYLE_SECTION
		and style.get_minimum_size().is_equal_approx(Vector2(BOX_PAD * 2.0, BOX_PAD * 2.0)),
		"minimum size %s" % [style.get_minimum_size()])
	var band: StyleBox = tradition.title_label.get_theme_stylebox(&"normal")
	TestFixtures.check(res, "a boxed section sets its title on a band of the band height",
		tradition.banded and band == FilterSection.STYLE_BAND
		and is_equal_approx(tradition.title_label.custom_minimum_size.y, FilterSection.BAND_HEIGHT),
		"banded %s, height %s" % [tradition.banded, tradition.title_label.custom_minimum_size.y])
	identity.set_open(true)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var ancestry: FilterSection = panel.section_for("ancestry")
	var ancestry_box: Control = ancestry.get_parent() as Control
	var inner: Rect2 = ancestry_box.get_global_rect().grow(-BOX_PAD)
	var span: Rect2 = ancestry.chip_row().get_global_rect()
	TestFixtures.check(res, "the chips sit inside the box pad on both sides",
		ancestry_box.size.x > BOX_PAD * 2.0
		and span.position.x >= inner.position.x - GEOMETRY_SLACK
		and span.end.x <= inner.end.x + GEOMETRY_SLACK,
		"box %s chips %s" % [ancestry_box.get_global_rect(), span])
	panel.queue_free()
	var lone: FilterSection = await _section(host,
		TraitFilterDefs.find(defs, &"tradition"), ents)
	TestFixtures.check(res, "a section outside any group draws a plain title",
		not lone.banded and not lone.title_label.has_theme_stylebox_override(&"normal")
		and is_zero_approx(lone.title_label.custom_minimum_size.y),
		"banded %s" % [lone.banded])
	lone.banded = true
	TestFixtures.check(res, "banding a section puts its title on the band",
		lone.title_label.get_theme_stylebox(&"normal") == FilterSection.STYLE_BAND
		and is_equal_approx(lone.title_label.custom_minimum_size.y, FilterSection.BAND_HEIGHT),
		"height %s" % [lone.title_label.custom_minimum_size.y])
	lone.banded = false
	TestFixtures.check(res, "unbanding a section gives the plain title back",
		not lone.title_label.has_theme_stylebox_override(&"normal")
		and is_zero_approx(lone.title_label.custom_minimum_size.y),
		"height %s" % [lone.title_label.custom_minimum_size.y])
	lone.queue_free()
	var bare: FilterGroup = (load(GROUP_SCENE) as PackedScene).instantiate()
	bare.headless = true
	host.add_child(bare)
	await host.get_tree().process_frame
	var plain: FilterSection = (load(SECTION_SCENE) as PackedScene).instantiate()
	bare.add_section(plain)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a headless group adds its sections bare, with no box and no band",
		plain.get_parent() == bare.body() and not plain.banded
		and not plain.title_label.has_theme_stylebox_override(&"normal")
		and bare.sections().size() == 1, "parent %s" % [plain.get_parent()])
	bare.queue_free()


static func _case_builder_rows(res: Dictionary) -> void:
	var builder: Array[Dictionary] = TraitFilterDefs.merc_defs(false)
	var hiring: Array[Dictionary] = TraitFilterDefs.merc_defs(true)
	var builder_keys: Array[StringName] = TraitFilterDefs.keys_of(builder)
	TestFixtures.check(res, "the campaign builder offers eight merc rows in the design order",
		builder_keys == BUILDER_ROWS, "keys %s" % [builder_keys])
	var carried: Array[String] = []
	for key: StringName in REVIEW_ONLY_ROWS:
		if not TraitFilterDefs.find(builder, key).is_empty():
			carried.append(String(key))
	TestFixtures.check(res, "the builder carries no row that only applicant review narrows by",
		carried.is_empty() and TraitFilterDefs.find(builder, VIA_ROW).is_empty(),
		"builder carries %s" % [carried])
	var wanted: Array[StringName] = []
	wanted.append_array(BUILDER_ROWS)
	wanted.append_array(REVIEW_ONLY_ROWS)
	wanted.append(VIA_ROW)
	var absent: Array[String] = []
	for key: StringName in wanted:
		if TraitFilterDefs.find(hiring, key).is_empty():
			absent.append(String(key))
	TestFixtures.check(res, "Hiring keeps every builder row, every review row and Applied Via",
		absent.is_empty() and hiring.size() == wanted.size(),
		"missing %s, %d rows" % [absent, hiring.size()])
	var misfiled: Array[String] = []
	for group: String in BUILDER_GROUPS:
		var rows: Array[StringName] = TraitFilterDefs.keys_of(
			TraitFilterDefs.in_group(builder, group))
		if rows != BUILDER_GROUPS[group]:
			misfiled.append(group)
	TestFixtures.check(res, "the builder fills the four groups with the rows the design lists",
		misfiled.is_empty(), "off groups %s" % [misfiled])


static func _case_ancestry_chips(res: Dictionary, host: Node) -> void:
	SubscriptionManager.max_out()
	var ents: Dictionary = SubscriptionManager.entitlements()
	var real_names: Array[String] = TraitFilterDefs.ancestry_names()
	var sheet: Array = DataManager.ancestries.keys()
	TestFixtures.check(res, "the ancestry names are the ancestries the data sheet holds, in order",
		not real_names.is_empty() and real_names == sheet, "names %s" % [real_names])
	var placeholders: Array[String] = []
	for ancestry_name: String in real_names:
		if ancestry_name.begins_with(PLACEHOLDER_ANCESTRY):
			placeholders.append(ancestry_name)
	TestFixtures.check(res, "no ancestry name is a numbered placeholder",
		placeholders.is_empty(), "placeholders %s" % [placeholders])
	var off_hosts: Array[String] = []
	for hiring: bool in [false, true]:
		var row: Dictionary = TraitFilterDefs.find(TraitFilterDefs.merc_defs(hiring), &"ancestry")
		if row.get("options", []) != real_names or row.get("values", []) != real_names:
			off_hosts.append("Hiring" if hiring else "builder")
	TestFixtures.check(res, "the builder and Hiring both list the real ancestries as labels and values",
		off_hosts.is_empty(), "off in %s" % [off_hosts])
	var builder: Array[Dictionary] = TraitFilterDefs.merc_defs(false)
	var section: FilterSection = await _section(host,
		TraitFilterDefs.find(builder, &"ancestry"), ents)
	var chips: ChipRow = section.chip_row()
	TestFixtures.check(res, "the ancestry row renders one chip per real ancestry",
		chips != null and chips.chip_count() == real_names.size(),
		"count %d of %d" % [0 if chips == null else chips.chip_count(), real_names.size()])
	var read: Array[String] = []
	for ancestry_name: String in real_names:
		var chip: Button = chips.chip_for(ancestry_name)
		read.append("" if chip == null else chip.text)
	TestFixtures.check(res, "each ancestry chip reads its ancestry name and stores it as its value",
		read == real_names, "chips %s" % [read])
	TestFixtures.check(res, "the ancestry row is a multi pick without tradition dots",
		chips.multi and chips.chip_for(real_names[0]).icon == null, "single pick or dotted")
	chips.press_chip(real_names[0])
	chips.press_chip(real_names[1])
	TestFixtures.check(res, "two ancestry chips store two real names and count as active",
		section.value() == [real_names[0], real_names[1]] and section.is_active(),
		"value %s" % [section.value()])
	section.queue_free()


static func _case_panel_merc(res: Dictionary, host: Node) -> void:
	SubscriptionManager.max_out()
	var panel: TraitFilterPanel = (load(PANEL_SCENE) as PackedScene).instantiate()
	host.add_child(panel)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the filter panel asks for its pinned width",
		panel.panel_width == 290 and is_equal_approx(panel.custom_minimum_size.x, 290.0),
		"width %s" % str(panel.custom_minimum_size.x))
	var defs: Array[Dictionary] = TraitFilterDefs.merc_defs(true)
	panel.set_defs(defs, {}, SubscriptionManager.entitlements())
	await host.get_tree().process_frame
	var titles: Array[String] = []
	for group: FilterGroup in panel.groups():
		titles.append(group.title)
	TestFixtures.check(res, "the panel builds one group per named def group",
		titles == TraitFilterDefs.GROUPS, "titles %s" % str(titles))
	TestFixtures.check(res, "every def row gets a section",
		panel.sections().size() == defs.size(),
		"sections %d of %d" % [panel.sections().size(), defs.size()])
	TestFixtures.check(res, "merc groups start closed",
		not panel.group_for("Value").is_open(), "Value open")
	var events: Array = []
	panel.filters_changed.connect(func(f: Dictionary) -> void: events.append(f))
	panel.set_value("salary", [100.0, 500.0])
	TestFixtures.check(res, "set_value on the panel is silent and reaches the section",
		events.is_empty() and panel.active_total() == 1
		and is_equal_approx(float((panel.section_for("salary").value() as Array)[1]), 500.0),
		"total %d" % panel.active_total())
	TestFixtures.check(res, "the group of a narrowed row counts it",
		panel.group_for("Value").count() == 1 and panel.group_for("Physical").count() == 0,
		"Value %d" % panel.group_for("Value").count())
	var keys: Array = panel.filters().keys()
	TestFixtures.check(res, "the filter table is keyed by the def keys as StringNames",
		not keys.is_empty() and keys[0] is StringName and panel.filters().has(&"salary"),
		"first key is type %d" % (TYPE_NIL if keys.is_empty() else typeof(keys[0])))
	panel.press_value("age", [20.0, 40.0])
	TestFixtures.check(res, "press_value reports the whole filter table",
		events.size() == 1 and panel.active_total() == 2
		and panel.group_for("Physical").count() == 1, "total %d" % panel.active_total())
	panel.section_for("tradition").press_value([TraitFilterDefs.traditions()[0]])
	TestFixtures.check(res, "a section press flows up to the panel",
		events.size() == 2 and panel.active_total() == 3
		and panel.group_for("Identity").count() == 1,
		"identity %d" % panel.group_for("Identity").count())
	var stored: Dictionary = panel.filters()
	panel.press_clear()
	TestFixtures.check(res, "clear empties every filter and every badge",
		panel.active_total() == 0 and events.size() == 3
		and panel.group_for("Value").count() == 0 and panel.group_for("Identity").count() == 0,
		"total %d" % panel.active_total())
	panel.set_defs(defs, stored, SubscriptionManager.entitlements())
	await host.get_tree().process_frame
	TestFixtures.check(res, "a stored filter table renders back onto the sections",
		panel.active_total() == 3
		and is_equal_approx(float((panel.value_of("salary") as Array)[1]), 500.0),
		"total %d" % panel.active_total())
	panel.footer_note = "Applicant level cannot be targeted."
	panel.show_clear = false
	panel.set_defs(defs, {}, SubscriptionManager.entitlements())
	await host.get_tree().process_frame
	var footer: Label = panel.get_node("Footer")
	var clear_button: Button = panel.get_node("Header/Clear")
	TestFixtures.check(res, "the footer note shows and Clear can be hidden",
		footer.visible and footer.text == "Applicant level cannot be targeted."
		and not clear_button.visible, "footer %s" % footer.text)
	TestFixtures.check(res, "the panel header sits outside the scrolling body",
		(panel.get_node("Header") as Control).get_parent() == panel
		and (panel.get_node("Scroll/Pad/Groups") as Control).get_parent().get_parent()
		== panel.get_node("Scroll"), "header inside the scroll")
	panel.queue_free()


static func _case_panel_builder(res: Dictionary, host: Node) -> void:
	SubscriptionManager.max_out()
	var panel: TraitFilterPanel = (load(PANEL_SCENE) as PackedScene).instantiate()
	host.add_child(panel)
	await host.get_tree().process_frame
	panel.set_defs(TraitFilterDefs.merc_defs(false), {}, SubscriptionManager.entitlements())
	await host.get_tree().process_frame
	var drawn: Array[StringName] = []
	for section: FilterSection in panel.sections():
		drawn.append(section.def_key())
	TestFixtures.check(res, "the builder panel draws its eight rows in the design order",
		drawn == BUILDER_ROWS, "rows %s" % [drawn])
	var titles: Array[String] = []
	for group: FilterGroup in panel.groups():
		titles.append(group.title)
	TestFixtures.check(res, "the builder panel keeps all four groups",
		titles == TraitFilterDefs.GROUPS, "titles %s" % [titles])
	var found: Array[String] = []
	for key: StringName in REVIEW_ONLY_ROWS:
		if panel.section_for(String(key)) != null:
			found.append(String(key))
	TestFixtures.check(res, "the builder panel has no section for a row only review narrows by",
		found.is_empty(), "sections %s" % [found])
	panel.queue_free()


static func _case_panel_accordion(res: Dictionary, host: Node) -> void:
	SubscriptionManager.max_out()
	var ents: Dictionary = SubscriptionManager.entitlements()
	var panel: TraitFilterPanel = (load(PANEL_SCENE) as PackedScene).instantiate()
	host.add_child(panel)
	await host.get_tree().process_frame
	panel.set_defs(TraitFilterDefs.merc_defs(false), {}, ents)
	await host.get_tree().process_frame
	var events: Array = []
	panel.filters_changed.connect(func(f: Dictionary) -> void: events.append(f))
	var none_open: Array[String] = []
	var only_identity: Array[String] = [IDENTITY_GROUP]
	var only_physical: Array[String] = [PHYSICAL_GROUP]
	var only_mental: Array[String] = [MENTAL_GROUP]
	var only_value: Array[String] = [VALUE_GROUP]
	TestFixtures.check(res, "every named group starts shut",
		_open_titles(panel) == none_open, "open %s" % [_open_titles(panel)])
	panel.group_for(IDENTITY_GROUP).toggle()
	TestFixtures.check(res, "opening a group leaves it as the only open one",
		_open_titles(panel) == only_identity, "open %s" % [_open_titles(panel)])
	panel.group_for(PHYSICAL_GROUP).toggle()
	TestFixtures.check(res, "opening a second group shuts the first",
		_open_titles(panel) == only_physical and not panel.group_for(IDENTITY_GROUP).is_open(),
		"open %s" % [_open_titles(panel)])
	panel.group_for(PHYSICAL_GROUP).toggle()
	TestFixtures.check(res, "closing the open group leaves every group shut",
		_open_titles(panel) == none_open, "open %s" % [_open_titles(panel)])
	panel.open_group(MENTAL_GROUP)
	TestFixtures.check(res, "open_group opens the named group, shuts the rest and reports nothing",
		_open_titles(panel) == only_mental and events.is_empty(),
		"open %s, %d events" % [_open_titles(panel), events.size()])
	panel.open_group(VALUE_GROUP)
	TestFixtures.check(res, "open_group moves the open slot to the group it names",
		_open_titles(panel) == only_value, "open %s" % [_open_titles(panel)])
	panel.open_group(UNKNOWN_GROUP)
	TestFixtures.check(res, "open_group with an unknown name changes nothing",
		_open_titles(panel) == only_value, "open %s" % [_open_titles(panel)])
	panel.press_value("tradition", [TraitFilterDefs.traditions()[0]])
	panel.open_group(PHYSICAL_GROUP)
	var identity: FilterGroup = panel.group_for(IDENTITY_GROUP)
	TestFixtures.check(res, "a group shut by the accordion still counts its narrowed rows",
		not identity.is_open() and identity.count() == 1, "identity count %d" % identity.count())
	panel.set_defs(TraitFilterDefs.merc_defs(true), panel.filters(), ents)
	await host.get_tree().process_frame
	panel.group_for(VALUE_GROUP).toggle()
	panel.group_for(MENTAL_GROUP).toggle()
	TestFixtures.check(res, "a panel rebuilt with the Hiring rows still keeps one group open",
		_open_titles(panel) == only_mental, "open %s" % [_open_titles(panel)])
	panel.queue_free()


static func _case_panel_stale(res: Dictionary, host: Node) -> void:
	SubscriptionManager.max_out()
	var ents: Dictionary = SubscriptionManager.entitlements()
	var held: Dictionary = {&"salary": [100.0, 500.0], &"bloodline": ["Bloodline 2"],
		&"age": [20.0, 40.0], "tools": ["Tool 1"]}
	var panel: TraitFilterPanel = (load(PANEL_SCENE) as PackedScene).instantiate()
	host.add_child(panel)
	await host.get_tree().process_frame
	panel.set_defs(TraitFilterDefs.merc_defs(false), held, ents)
	await host.get_tree().process_frame
	var events: Array = []
	panel.filters_changed.connect(func(f: Dictionary) -> void: events.append(f))
	TestFixtures.check(res, "saved filters for rows the builder dropped stay out of the table",
		panel.filters().keys() == BUILDER_ROWS, "keys %s" % [panel.filters().keys()])
	TestFixtures.check(res, "the saved rows the builder still carries come through",
		panel.active_total() == 1
		and is_equal_approx(float((panel.value_of("salary") as Array)[1]), 500.0),
		"total %d" % panel.active_total())
	TestFixtures.check(res, "a dropped row reads as unknown and draws no section",
		panel.value_of("bloodline") == null and panel.value_of("tools") == null
		and panel.section_for("age") == null, "bloodline %s" % [panel.value_of("bloodline")])
	panel.press_value("bloodline", ["Bloodline 1"])
	panel.set_value("age", [30.0, 50.0])
	TestFixtures.check(res, "writing a dropped row reports nothing and adds no key",
		events.is_empty() and panel.filters().keys() == BUILDER_ROWS
		and panel.active_total() == 1, "%d events, keys %s" % [events.size(), panel.filters().keys()])
	TestFixtures.check(res, "only the Value group counts a narrowed row after the stale keys",
		panel.group_for(VALUE_GROUP).count() == 1 and panel.group_for(IDENTITY_GROUP).count() == 0
		and panel.group_for(PHYSICAL_GROUP).count() == 0
		and panel.group_for(MENTAL_GROUP).count() == 0,
		"Value %d" % panel.group_for(VALUE_GROUP).count())
	panel.set_defs(TraitFilterDefs.merc_defs(true), held, ents)
	await host.get_tree().process_frame
	var revived: Dictionary = panel.filters()
	TestFixtures.check(res, "the same saved table applies in full once the Hiring rows are back",
		revived.has(&"bloodline") and revived.has(&"age") and revived.has(&"tools")
		and panel.active_total() == 4, "total %d" % panel.active_total())
	panel.queue_free()


static func _case_panel_contract(res: Dictionary, host: Node) -> void:
	SubscriptionManager.max_out()
	var panel: TraitFilterPanel = (load(PANEL_SCENE) as PackedScene).instantiate()
	panel.lock_verb = "target"
	host.add_child(panel)
	await host.get_tree().process_frame
	var defs: Array[Dictionary] = TraitFilterDefs.contract_defs(SPONSOR_TYPE)
	panel.set_defs(defs, {}, SubscriptionManager.entitlements())
	await host.get_tree().process_frame
	TestFixtures.check(res, "rows with no group render in one headless group",
		panel.groups().size() == 1 and panel.groups()[0].headless
		and panel.groups()[0].is_open(), "groups %d" % panel.groups().size())
	TestFixtures.check(res, "every contract row gets a section",
		panel.sections().size() == defs.size(),
		"sections %d of %d" % [panel.sections().size(), defs.size()])
	panel.set_value("diff", [2.0, 4.0])
	TestFixtures.check(res, "the headless group counts its active rows",
		panel.active_total() == 1 and panel.group_for("").count() == 1,
		"total %d" % panel.active_total())
	panel.clear()
	TestFixtures.check(res, "clear puts a stars2 row back on the full range",
		panel.active_total() == 0
		and is_equal_approx(float((panel.value_of("diff") as Array)[1]),
		TraitFilterDefs.MAX_STARS), "value %s" % str(panel.value_of("diff")))
	SubscriptionManager.set_entitlements({"gpContractType": false})
	panel.set_defs(defs, {}, SubscriptionManager.entitlements())
	await host.get_tree().process_frame
	var ctype: FilterSection = panel.section_for("ctype")
	TestFixtures.check(res, "a row the guild promo tier does not cover shows its lock",
		ctype.is_locked() and ctype.section_lock().visible
		and ctype.section_lock().upgrade == UpgradeDefs.name_of(TraitFilterDefs.GUILD_PROMO_ID),
		"upgrade %s" % ctype.section_lock().upgrade)
	TestFixtures.check(res, "the panel passes its lock verb down to the sections",
		ctype.lock_verb == "target" and ctype.section_lock().verb == "target",
		"verb %s" % ctype.section_lock().verb)
	var relayed: Array = []
	panel.take_me_there.connect(func(t: Dictionary) -> void: relayed.append(t))
	ctype.section_lock().take_me_there.emit(PLANS_TARGET)
	TestFixtures.check(res, "the panel relays Take Me There from a locked row",
		relayed.size() == 1 and relayed[0] == PLANS_TARGET, "relayed %s" % str(relayed))
	panel.set_value("ctype", [0])
	TestFixtures.check(res, "an active value on a locked row is left out of the active total",
		panel.active_total() == 0 and panel.group_for("").count() == 0
			and (panel.value_of("ctype") as Array).size() == 1,
		"total %d on %s" % [panel.active_total(), str(panel.value_of("ctype"))])
	var held: Dictionary = panel.filters()
	SubscriptionManager.set_entitlements({"gpContractType": true})
	panel.set_defs(defs, held, SubscriptionManager.entitlements())
	await host.get_tree().process_frame
	TestFixtures.check(res, "the same value counts again once the lock opens",
		not panel.section_for("ctype").is_locked() and panel.active_total() == 1
			and panel.group_for("").count() == 1,
		"total %d on %s" % [panel.active_total(), str(panel.value_of("ctype"))])
	panel.queue_free()
	SubscriptionManager.max_out()


static func _case_check_row_hover(res: Dictionary, host: Node) -> void:
	var cold_off: Color = FilterCheckRow.border_for(false, false)
	var cold_on: Color = FilterCheckRow.border_for(true, false)
	var hot_off: Color = FilterCheckRow.border_for(false, true)
	var hot_on: Color = FilterCheckRow.border_for(true, true)
	TestFixtures.check(res, "a resting check box keeps its pale or dark orange border",
		cold_off == FilterCheckRow.OFF_BORDER and cold_on == FilterCheckRow.ON_BORDER,
		"off %s on %s" % [cold_off.to_html(false), cold_on.to_html(false)])
	TestFixtures.check(res, "a hovered check box turns its border orange, brighter when ticked",
		hot_off == FilterCheckRow.BORDER_HOT_OFF and hot_on == FilterCheckRow.BORDER_HOT_ON
		and hot_off != cold_off and hot_on != cold_on and hot_on != hot_off,
		"off %s on %s" % [hot_off.to_html(false), hot_on.to_html(false)])
	var row: FilterCheckRow = (load(CHECK_ROW_SCENE) as PackedScene).instantiate()
	host.add_child(row)
	await host.get_tree().process_frame
	var label_rest: Color = row._label_color()
	row.mouse_entered.emit()
	var label_hot_on: Color = row._label_color()
	row.on = false
	var label_hot_off: Color = row._label_color()
	row.mouse_exited.emit()
	var label_after: Color = row._label_color()
	TestFixtures.check(res, "the label turns orange under the pointer, ticked or not",
		label_rest == FilterCheckRow.ROW_COLOR and label_hot_on == FilterCheckRow.HOVER_COLOR
		and label_hot_off == FilterCheckRow.HOVER_COLOR and label_after == FilterCheckRow.ROW_COLOR,
		"rest %s ticked %s clear %s after %s" % [label_rest.to_html(false), label_hot_on.to_html(false),
		label_hot_off.to_html(false), label_after.to_html(false)])
	TestFixtures.check(res, "the row shows the pointing hand over it",
		row.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
		"cursor %d" % row.mouse_default_cursor_shape)
	row.queue_free()
