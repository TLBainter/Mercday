class_name GuiMeterTests

#The ten S1B GUI atoms: statics and instanced scene behaviour.
#Run: godot --headless --path . -- --gui-meter-tests

const NOTE_ICON_SCENE := "res://Scenes/GUI/Shared/NoteIcon.tscn"
const TRADITION_SIGIL_SCENE := "res://Scenes/GUI/Shared/TraditionSigil.tscn"
const MERC_STATUS_STRIP_SCENE := "res://Scenes/GUI/Shared/MercStatusStrip.tscn"
const SUCCESS_METER_SCENE := "res://Scenes/GUI/Shared/SuccessMeter.tscn"
const STATUS_MARK_SCENE := "res://Scenes/GUI/Shared/StatusMark.tscn"
const URGENCY_PULSE_SCENE := "res://Scenes/GUI/Shared/UrgencyPulse.tscn"
const RESOURCE_BAR_SCENE := "res://Scenes/GUI/Shared/ResourceBar.tscn"
const WEIGHT_BAR_SCENE := "res://Scenes/GUI/Shared/WeightBar.tscn"
const MERC_COUNT_SCENE := "res://Scenes/GUI/Shared/MercCount.tscn"


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await _case_difficulty_stars(res, host)
	await _case_note_icon(res, host)
	await _case_tradition_sigil(res, host)
	await _case_merc_status_strip(res, host)
	await _case_success_meter(res, host)
	await _case_status_mark(res, host)
	await _case_urgency_pulse(res, host)
	await _case_resource_bar(res, host)
	await _case_weight_bar(res, host)
	await _case_merc_count(res, host)
	return TestFixtures.summarize(res, "GUI METER")


static func _near(a: float, b: float, eps: float = 0.001) -> bool:
	return absf(a - b) <= eps


static func _case_difficulty_stars(res: Dictionary, host: Node) -> void:
	TestFixtures.check(res, "Stars colour snaps 3.4 to the 3.5 half step",
		Stars.color_of(3.4, Stars.DIFFICULTY, true) == Icons.star_color(3.5, false),
		str(Stars.color_of(3.4, Stars.DIFFICULTY, true)))
	TestFixtures.check(res, "Stars colour snaps 3.74 down to 3.5",
		Stars.color_of(3.74, Stars.DIFFICULTY, true) == Icons.star_color(3.5, false),
		str(Stars.color_of(3.74, Stars.DIFFICULTY, true)))
	TestFixtures.check(res, "Stars colour without snapping reads the raw value",
		Stars.color_of(3.0, Stars.DIFFICULTY, false) == Icons.star_color(3.0, false),
		str(Stars.color_of(3.0, Stars.DIFFICULTY, false)))
	var node := Stars.new()
	host.add_child(node)
	await host.get_tree().process_frame
	node.star_px = 2
	node.value = 3.5
	await host.get_tree().process_frame
	TestFixtures.check(res, "Stars min size", node.custom_minimum_size == Vector2(176, 32),
		str(node.custom_minimum_size))
	TestFixtures.check(res, "Stars tooltip", node.tooltip_text == "3.5", node.tooltip_text)
	TestFixtures.check(res, "Stars empty colour is the unused star blue",
		node.empty_color == Icons.UNUSED_STAR, str(node.empty_color))
	TestFixtures.check(res, "Stars difficulty ramp reads the Icons ramp",
		Stars.color_of(3.5, Stars.DIFFICULTY, false) == Icons.star_color(3.5, false),
		str(Stars.color_of(3.5, Stars.DIFFICULTY, false)))
	TestFixtures.check(res, "Stars match ramp reads the positive Icons ramp",
		Stars.color_of(3.5, Stars.MATCH, false) == Icons.star_color(3.5, true),
		str(Stars.color_of(3.5, Stars.MATCH, false)))
	node.queue_free()


static func _case_note_icon(res: Dictionary, host: Node) -> void:
	TestFixtures.check(res, "NoteIcon tile_size(2)", NoteIcon.tile_size(2) == Vector2(18, 22),
		str(NoteIcon.tile_size(2)))
	TestFixtures.check(res, "NoteIcon glyph size", NoteIcon.GLYPH_SIZE_PX == Vector2(5, 9),
		str(NoteIcon.GLYPH_SIZE_PX))
	TestFixtures.check(res, "NoteIcon draws its glyph in ink",
		NoteIcon.GLYPH_COLOR == Color("#0a0f1c"), NoteIcon.GLYPH_COLOR.to_html(false))
	var node: NoteIcon = load(NOTE_ICON_SCENE).instantiate()
	host.add_child(node)
	await host.get_tree().process_frame
	node.pixel_scale = 2
	await host.get_tree().process_frame
	TestFixtures.check(res, "NoteIcon min size", node.custom_minimum_size == Vector2(18, 22),
		str(node.custom_minimum_size))
	node.queue_free()


static func _case_tradition_sigil(res: Dictionary, host: Node) -> void:
	var node: TraditionSigil = load(TRADITION_SIGIL_SCENE).instantiate()
	host.add_child(node)
	await host.get_tree().process_frame
	node.pixel_scale = 2
	node.tradition = ""
	await host.get_tree().process_frame
	TestFixtures.check(res, "TraditionSigil empty tradition uses tint", node.color() == node.tint,
		str(node.color()))
	node.tradition = "Some Order"
	await host.get_tree().process_frame
	TestFixtures.check(res, "TraditionSigil named tradition uses GuiTypes color",
		node.color() == GuiTypes.tradition_color("Some Order"), str(node.color()))
	TestFixtures.check(res, "TraditionSigil tooltip", node.tooltip_text == "Some Order", node.tooltip_text)
	TestFixtures.check(res, "TraditionSigil min size",
		node.custom_minimum_size == Vector2(32, 32), str(node.custom_minimum_size))
	TestFixtures.check(res, "TraditionSigil reads the atlas sigil id",
		Icons.sigil_id("Warrior") == "sigil_warrior", Icons.sigil_id("Warrior"))
	node.queue_free()


static func _case_merc_status_strip(res: Dictionary, host: Node) -> void:
	var times: Array[Array] = [[45, "45m"], [60, "1h"], [150, "2h 30m"], [1440, "1d"], [1500, "1d 1h"]]
	for row: Array in times:
		var minutes: int = row[0]
		var text: String = MercStatusStrip.time_text(minutes)
		TestFixtures.check(res, "MercStatusStrip time_text(%d)" % minutes, text == row[1], text)
	TestFixtures.check(res, "MercStatusStrip color_for(AVAILABLE)",
		MercStatusStrip.color_for(GuiTypes.MercStatus.AVAILABLE) == Color("#6cc36a"), "")
	TestFixtures.check(res, "MercStatusStrip color_for(RESTING)",
		MercStatusStrip.color_for(GuiTypes.MercStatus.RESTING) == Color("#f3ead7"), "")
	var node: MercStatusStrip = load(MERC_STATUS_STRIP_SCENE).instantiate()
	host.add_child(node)
	await host.get_tree().process_frame
	node.status = GuiTypes.MercStatus.AVAILABLE
	await host.get_tree().process_frame
	var base_name: String = String(GuiTypes.MERC_STATUS_NAMES.get(GuiTypes.MercStatus.AVAILABLE, ""))
	TestFixtures.check(res, "MercStatusStrip text with no time", node.text == base_name, node.text)
	node.band = true
	TestFixtures.check(res, "band mode centres, backs and upper-cases the strip",
		node.text == base_name.to_upper()
			and node.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
			and node.vertical_alignment == VERTICAL_ALIGNMENT_CENTER
			and node.has_theme_stylebox_override("normal")
			and absf((node.get_theme_stylebox("normal") as StyleBoxFlat).bg_color.a - 0.78) < 0.01,
		"text '%s' align %d %d override %s" % [node.text, node.horizontal_alignment,
			node.vertical_alignment, node.has_theme_stylebox_override("normal")])
	node.band = false
	TestFixtures.check(res, "the plain strip keeps its text and drops the band",
		node.text == base_name and not node.has_theme_stylebox_override("normal"),
		"text '%s' override %s" % [node.text, node.has_theme_stylebox_override("normal")])
	node.queue_free()
	var tag: Label = Label.new()
	host.add_child(tag)
	MercStatusStrip.dress_time_tag(tag, 0)
	TestFixtures.check(res, "the time tag hides at zero minutes", not tag.visible, str(tag.visible))
	MercStatusStrip.dress_time_tag(tag, 90)
	TestFixtures.check(res, "the time tag reads the time left on its own band, right aligned",
		tag.visible and tag.text == "1h 30m" and tag.has_theme_stylebox_override("normal")
			and tag.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT,
		"text '%s' visible %s" % [tag.text, tag.visible])
	tag.queue_free()


static func _case_success_meter(res: Dictionary, host: Node) -> void:
	var cells: Array[Array] = [[0, 0], [52, 10], [53, 11], [100, 20], [140, 20]]
	for row: Array in cells:
		var odds: int = row[0]
		var filled: int = SuccessMeter.filled_cells(odds)
		TestFixtures.check(res, "SuccessMeter filled_cells(%d)" % odds, filled == row[1], str(filled))
	var node: SuccessMeter = load(SUCCESS_METER_SCENE).instantiate()
	host.add_child(node)
	await host.get_tree().process_frame
	node.pixel_scale = 2
	node.odds = 53
	await host.get_tree().process_frame
	TestFixtures.check(res, "SuccessMeter min size", node.custom_minimum_size == Vector2(238, 16),
		str(node.custom_minimum_size))
	TestFixtures.check(res, "SuccessMeter tooltip", node.tooltip_text == "53%", node.tooltip_text)
	node.queue_free()


static func _case_status_mark(res: Dictionary, host: Node) -> void:
	TestFixtures.check(res, "StatusMark id_for(AVAILABLE)",
		StatusMark.id_for(GuiTypes.ContractStatus.AVAILABLE) == ""
			and StatusMark.icon_for(GuiTypes.ContractStatus.AVAILABLE) == null, "")
	TestFixtures.check(res, "StatusMark id_for(ACTIVE)",
		StatusMark.id_for(GuiTypes.ContractStatus.ACTIVE) == ""
			and StatusMark.icon_for(GuiTypes.ContractStatus.ACTIVE) == null, "")
	TestFixtures.check(res, "StatusMark id_for(COMPLETED)",
		StatusMark.id_for(GuiTypes.ContractStatus.COMPLETED) == "check_lg",
		StatusMark.id_for(GuiTypes.ContractStatus.COMPLETED))
	TestFixtures.check(res, "StatusMark id_for(EXPIRED)",
		StatusMark.id_for(GuiTypes.ContractStatus.EXPIRED) == "prohibited",
		StatusMark.id_for(GuiTypes.ContractStatus.EXPIRED))
	TestFixtures.check(res, "StatusMark id_for(REJECTED)",
		StatusMark.id_for(GuiTypes.ContractStatus.REJECTED) == "thumbs_down",
		StatusMark.id_for(GuiTypes.ContractStatus.REJECTED))
	TestFixtures.check(res, "StatusMark id_for(FAILED)",
		StatusMark.id_for(GuiTypes.ContractStatus.FAILED) == "x_lg",
		StatusMark.id_for(GuiTypes.ContractStatus.FAILED))
	TestFixtures.check(res, "StatusMark id_of(BANG)",
		StatusMark.id_of(StatusMark.Mark.BANG) == "alert",
		StatusMark.id_of(StatusMark.Mark.BANG))
	TestFixtures.check(res, "StatusMark icon_for(COMPLETED) is the atlas cell",
		StatusMark.icon_for(GuiTypes.ContractStatus.COMPLETED) == Icons.tex("check_lg"), "")
	TestFixtures.check(res, "StatusMark mark_size(5)", StatusMark.mark_size(5) == Vector2(80, 80),
		str(StatusMark.mark_size(5)))
	var node: StatusMark = load(STATUS_MARK_SCENE).instantiate()
	host.add_child(node)
	await host.get_tree().process_frame
	node.status = GuiTypes.ContractStatus.AVAILABLE
	await host.get_tree().process_frame
	TestFixtures.check(res, "StatusMark min size", node.custom_minimum_size == Vector2(32, 32),
		str(node.custom_minimum_size))
	TestFixtures.check(res, "StatusMark hides icon when none", node.icon_rect.visible == false, "")
	node.status = GuiTypes.ContractStatus.COMPLETED
	await host.get_tree().process_frame
	TestFixtures.check(res, "StatusMark shows icon when present", node.icon_rect.visible == true, "")
	TestFixtures.check(res, "StatusMark carries the mark id at the mark scale",
		node.icon_rect.icon_id == "check_lg" and node.icon_rect.pixel_scale == 2,
		"id '%s' scale %d" % [node.icon_rect.icon_id, node.icon_rect.pixel_scale])
	TestFixtures.check(res, "StatusMark icon centres in its rect",
		node.icon_rect.stretch_mode == TextureRect.STRETCH_KEEP_CENTERED, "")
	node.queue_free()


static func _case_urgency_pulse(res: Dictionary, host: Node) -> void:
	TestFixtures.check(res, "UrgencyPulse alpha_at(0,2.6)", _near(UrgencyPulse.alpha_at(0.0, 2.6), 0.04),
		str(UrgencyPulse.alpha_at(0.0, 2.6)))
	TestFixtures.check(res, "UrgencyPulse alpha_at(1.3,2.6)", _near(UrgencyPulse.alpha_at(1.3, 2.6), 0.38),
		str(UrgencyPulse.alpha_at(1.3, 2.6)))
	TestFixtures.check(res, "UrgencyPulse alpha_at(2.6,2.6)", _near(UrgencyPulse.alpha_at(2.6, 2.6), 0.04),
		str(UrgencyPulse.alpha_at(2.6, 2.6)))
	var node: UrgencyPulse = load(URGENCY_PULSE_SCENE).instantiate()
	host.add_child(node)
	await host.get_tree().process_frame
	TestFixtures.check(res, "UrgencyPulse inactive by default", node.is_processing() == false, "")
	TestFixtures.check(res, "UrgencyPulse alpha zero inactive", _near(node.color.a, 0.0), str(node.color.a))
	node.active = true
	await host.get_tree().process_frame
	TestFixtures.check(res, "UrgencyPulse processes when active", node.is_processing() == true, "")
	node.queue_free()


static func _case_resource_bar(res: Dictionary, host: Node) -> void:
	TestFixtures.check(res, "ResourceBar cell_width(200,20)", ResourceBar.cell_width(200, 20) == 9,
		str(ResourceBar.cell_width(200, 20)))
	TestFixtures.check(res, "ResourceBar cell_width(20,40)", ResourceBar.cell_width(20, 40) == 2,
		str(ResourceBar.cell_width(20, 40)))
	TestFixtures.check(res, "ResourceBar filled(7,5)", ResourceBar.filled(7, 5) == 5,
		str(ResourceBar.filled(7, 5)))
	TestFixtures.check(res, "ResourceBar filled(-1,5)", ResourceBar.filled(-1, 5) == 0,
		str(ResourceBar.filled(-1, 5)))
	var node: ResourceBar = load(RESOURCE_BAR_SCENE).instantiate()
	host.add_child(node)
	await host.get_tree().process_frame
	node.label = "HP"
	node.current = 7
	node.max_value = 12
	await host.get_tree().process_frame
	TestFixtures.check(res, "ResourceBar value text", node.value_label.text == "7/12",
		node.value_label.text)
	TestFixtures.check(res, "ResourceBar name text", node.name_label.text == "HP", node.name_label.text)
	TestFixtures.check(res, "ResourceBar default fill is the HP red",
		node.fill_color.is_equal_approx(Color("#d6453d")), str(node.fill_color))
	TestFixtures.check(res, "XPTooltip fill is the XP gold",
		XPTooltip.FILL_COLOR.is_equal_approx(Color("#f2d43d")), str(XPTooltip.FILL_COLOR))
	await host.get_tree().process_frame
	var head_end: float = node.name_label.get_global_rect().end.y
	var cells_top: float = node.cells.get_global_rect().position.y
	TestFixtures.check(res, "the bar stacks the head row over the cells",
		head_end <= cells_top + 0.5 and node.cells.custom_minimum_size.y == 16
			and node.name_label.get_theme_color("font_color").is_equal_approx(node.fill_color),
		"head end %.1f cells top %.1f min %.1f" % [head_end, cells_top,
			node.cells.custom_minimum_size.y])
	node.queue_free()


static func _case_weight_bar(res: Dictionary, host: Node) -> void:
	TestFixtures.check(res, "WeightBar fraction(5,10)", _near(WeightBar.fraction(5.0, 10.0), 0.5),
		str(WeightBar.fraction(5.0, 10.0)))
	TestFixtures.check(res, "WeightBar fraction(15,10)", _near(WeightBar.fraction(15.0, 10.0), 1.0),
		str(WeightBar.fraction(15.0, 10.0)))
	TestFixtures.check(res, "WeightBar fraction(1,0)", _near(WeightBar.fraction(1.0, 0.0), 0.0),
		str(WeightBar.fraction(1.0, 0.0)))
	TestFixtures.check(res, "WeightBar is_over(11,10)", WeightBar.is_over(11.0, 10.0) == true, "")
	TestFixtures.check(res, "WeightBar filled_cells(5,12)", WeightBar.filled_cells(5.0, 12.0) == 5,
		str(WeightBar.filled_cells(5.0, 12.0)))
	TestFixtures.check(res, "WeightBar filled_cells(20,12) stops at the capacity",
		WeightBar.filled_cells(20.0, 12.0) == 12, str(WeightBar.filled_cells(20.0, 12.0)))
	var node: WeightBar = load(WEIGHT_BAR_SCENE).instantiate()
	host.add_child(node)
	await host.get_tree().process_frame
	node.current_wt = 11.0
	node.capacity = 10.0
	await host.get_tree().process_frame
	TestFixtures.check(res, "WeightBar flag visible when over", node.flag_label.visible == true, "")
	node.current_wt = 5.0
	await host.get_tree().process_frame
	TestFixtures.check(res, "WeightBar flag hidden under capacity", node.flag_label.visible == false, "")
	node.capacity = 12.0
	await host.get_tree().process_frame
	TestFixtures.check(res, "WeightBar draws one cell per unit of capacity", node.cell_count() == 12,
		str(node.cell_count()))
	TestFixtures.check(res, "WeightBar reads the load over the limit",
		node.value_label.text == WeightBar.VALUE_TEXT % [5, 12], node.value_label.text)
	node.queue_free()


static func _case_merc_count(res: Dictionary, host: Node) -> void:
	var tones: Array[Array] = [[0, "#f28c28"], [1, "#f28c28"], [2, "#f3ead7"], [3, "#f3ead7"], [4, "#3b6fb6"]]
	for row: Array in tones:
		var index: int = row[0]
		TestFixtures.check(res, "MercCount color_at(%d,2,4)" % index,
			MercCount.color_at(index, 2, 4) == Color(row[1]), "")
	var node: MercCount = load(MERC_COUNT_SCENE).instantiate()
	host.add_child(node)
	await host.get_tree().process_frame
	node.pixel_scale = 2
	node.required = 1
	node.allowed = 1
	await host.get_tree().process_frame
	TestFixtures.check(res, "MercCount min size", node.custom_minimum_size == Vector2(156, 28),
		str(node.custom_minimum_size))
	TestFixtures.check(res, "MercCount tooltip singular", node.tooltip_text == "Requires 1, up to 1 merc",
		node.tooltip_text)
	node.queue_free()
