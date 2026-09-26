class_name GuiMeterTests

#The ten S1B GUI atoms: statics and instanced scene behaviour.
#Run: godot --headless --path . -- --gui-meter-tests

const DIFFICULTY_STARS_SCENE := "res://Scenes/GUI/Shared/DifficultyStars.tscn"
const NOTE_ICON_SCENE := "res://Scenes/GUI/Shared/NoteIcon.tscn"
const TRADITION_SIGIL_SCENE := "res://Scenes/GUI/Shared/TraditionSigil.tscn"
const MERC_STATUS_STRIP_SCENE := "res://Scenes/GUI/Shared/MercStatusStrip.tscn"
const SUCCESS_METER_SCENE := "res://Scenes/GUI/Shared/SuccessMeter.tscn"
const STATUS_MARK_SCENE := "res://Scenes/GUI/Shared/StatusMark.tscn"
const URGENCY_PULSE_SCENE := "res://Scenes/GUI/Shared/UrgencyPulse.tscn"
const RESOURCE_BAR_SCENE := "res://Scenes/GUI/Shared/ResourceBar.tscn"
const WEIGHT_BAR_SCENE := "res://Scenes/GUI/Shared/WeightBar.tscn"
const MERC_COUNT_SCENE := "res://Scenes/GUI/Shared/MercCount.tscn"

const ICON_CHECK: Texture2D = preload("res://Art/GUI/Icons/icon_check.png")
const ICON_EXPIRED: Texture2D = preload("res://Art/GUI/Icons/icon_expired.png")
const ICON_THUMBS_DOWN: Texture2D = preload("res://Art/GUI/Icons/icon_thumbs_down.png")


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
	TestFixtures.check(res, "DifficultyStars full_count(3.5)", DifficultyStars.full_count(3.5) == 3,
		str(DifficultyStars.full_count(3.5)))
	TestFixtures.check(res, "DifficultyStars has_half(3.5)", DifficultyStars.has_half(3.5) == true,
		str(DifficultyStars.has_half(3.5)))
	TestFixtures.check(res, "DifficultyStars has_half(3.0)", DifficultyStars.has_half(3.0) == false,
		str(DifficultyStars.has_half(3.0)))
	var node: DifficultyStars = load(DIFFICULTY_STARS_SCENE).instantiate()
	host.add_child(node)
	await host.get_tree().process_frame
	node.star_size = 2
	node.rating = 3.5
	await host.get_tree().process_frame
	TestFixtures.check(res, "DifficultyStars min size", node.custom_minimum_size == Vector2(106, 18),
		str(node.custom_minimum_size))
	TestFixtures.check(res, "DifficultyStars tooltip", node.tooltip_text == "3.5", node.tooltip_text)
	node.queue_free()


static func _case_note_icon(res: Dictionary, host: Node) -> void:
	TestFixtures.check(res, "NoteIcon tile_size(2)", NoteIcon.tile_size(2) == Vector2(18, 22),
		str(NoteIcon.tile_size(2)))
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
		node.custom_minimum_size == node.icon.get_size() * 2, str(node.custom_minimum_size))
	node.queue_free()


static func _case_merc_status_strip(res: Dictionary, host: Node) -> void:
	TestFixtures.check(res, "MercStatusStrip time_text(45)", MercStatusStrip.time_text(45) == "45m",
		MercStatusStrip.time_text(45))
	TestFixtures.check(res, "MercStatusStrip time_text(60)", MercStatusStrip.time_text(60) == "1h",
		MercStatusStrip.time_text(60))
	TestFixtures.check(res, "MercStatusStrip time_text(150)", MercStatusStrip.time_text(150) == "2h 30m",
		MercStatusStrip.time_text(150))
	TestFixtures.check(res, "MercStatusStrip time_text(1440)", MercStatusStrip.time_text(1440) == "1d",
		MercStatusStrip.time_text(1440))
	TestFixtures.check(res, "MercStatusStrip time_text(1500)", MercStatusStrip.time_text(1500) == "1d 1h",
		MercStatusStrip.time_text(1500))
	TestFixtures.check(res, "MercStatusStrip color_for(AVAILABLE)",
		MercStatusStrip.color_for(GuiTypes.MercStatus.AVAILABLE) == Color("#6cc36a"), "")
	TestFixtures.check(res, "MercStatusStrip color_for(RESTING)",
		MercStatusStrip.color_for(GuiTypes.MercStatus.RESTING) == Color("#f3ead7"), "")
	var node: MercStatusStrip = load(MERC_STATUS_STRIP_SCENE).instantiate()
	host.add_child(node)
	await host.get_tree().process_frame
	node.status = GuiTypes.MercStatus.AVAILABLE
	node.time_left_minutes = 0
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
	node.time_left_minutes = 90
	await host.get_tree().process_frame
	TestFixtures.check(res, "MercStatusStrip text with time",
		node.text == "%s 1h 30m" % base_name, node.text)
	node.queue_free()


static func _case_success_meter(res: Dictionary, host: Node) -> void:
	TestFixtures.check(res, "SuccessMeter filled_cells(0)", SuccessMeter.filled_cells(0) == 0,
		str(SuccessMeter.filled_cells(0)))
	TestFixtures.check(res, "SuccessMeter filled_cells(52)", SuccessMeter.filled_cells(52) == 10,
		str(SuccessMeter.filled_cells(52)))
	TestFixtures.check(res, "SuccessMeter filled_cells(53)", SuccessMeter.filled_cells(53) == 11,
		str(SuccessMeter.filled_cells(53)))
	TestFixtures.check(res, "SuccessMeter filled_cells(100)", SuccessMeter.filled_cells(100) == 20,
		str(SuccessMeter.filled_cells(100)))
	TestFixtures.check(res, "SuccessMeter filled_cells(140)", SuccessMeter.filled_cells(140) == 20,
		str(SuccessMeter.filled_cells(140)))
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
	TestFixtures.check(res, "StatusMark icon_for(AVAILABLE)",
		StatusMark.icon_for(GuiTypes.ContractStatus.AVAILABLE) == null, "")
	TestFixtures.check(res, "StatusMark icon_for(ACTIVE)",
		StatusMark.icon_for(GuiTypes.ContractStatus.ACTIVE) == null, "")
	TestFixtures.check(res, "StatusMark icon_for(COMPLETED)",
		StatusMark.icon_for(GuiTypes.ContractStatus.COMPLETED) == ICON_CHECK, "")
	TestFixtures.check(res, "StatusMark icon_for(EXPIRED)",
		StatusMark.icon_for(GuiTypes.ContractStatus.EXPIRED) == ICON_EXPIRED, "")
	TestFixtures.check(res, "StatusMark icon_for(REJECTED)",
		StatusMark.icon_for(GuiTypes.ContractStatus.REJECTED) == ICON_THUMBS_DOWN, "")
	var node: StatusMark = load(STATUS_MARK_SCENE).instantiate()
	host.add_child(node)
	await host.get_tree().process_frame
	node.status = GuiTypes.ContractStatus.AVAILABLE
	await host.get_tree().process_frame
	TestFixtures.check(res, "StatusMark min size", node.custom_minimum_size == Vector2(28, 28),
		str(node.custom_minimum_size))
	TestFixtures.check(res, "StatusMark hides icon when none", node.icon_rect.visible == false, "")
	node.status = GuiTypes.ContractStatus.COMPLETED
	await host.get_tree().process_frame
	TestFixtures.check(res, "StatusMark shows icon when present", node.icon_rect.visible == true, "")
	TestFixtures.check(res, "StatusMark icon centres in its rect",
		node.icon_rect.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "")
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
	TestFixtures.check(res, "MercCount color_at(0,2,4)", MercCount.color_at(0, 2, 4) == Color("#f28c28"), "")
	TestFixtures.check(res, "MercCount color_at(1,2,4)", MercCount.color_at(1, 2, 4) == Color("#f28c28"), "")
	TestFixtures.check(res, "MercCount color_at(2,2,4)", MercCount.color_at(2, 2, 4) == Color("#f3ead7"), "")
	TestFixtures.check(res, "MercCount color_at(3,2,4)", MercCount.color_at(3, 2, 4) == Color("#f3ead7"), "")
	TestFixtures.check(res, "MercCount color_at(4,2,4)", MercCount.color_at(4, 2, 4) == Color("#3b6fb6"), "")
	var hollow: PackedStringArray = MercCount.hollow_map()
	TestFixtures.check(res, "MercCount hollow_map row count", hollow.size() == 14, str(hollow.size()))
	var row_len_ok: bool = true
	for line: String in hollow:
		if line.length() != 10:
			row_len_ok = false
	TestFixtures.check(res, "MercCount hollow_map row width", row_len_ok, "")
	var full_hashes: int = 0
	for line: String in MercCount.SILHOUETTE_MAP:
		full_hashes += line.count("#")
	var hollow_hashes: int = 0
	for line: String in hollow:
		hollow_hashes += line.count("#")
	TestFixtures.check(res, "MercCount hollow_map has fewer hashes", hollow_hashes < full_hashes,
		"%d vs %d" % [hollow_hashes, full_hashes])
	var node: MercCount = load(MERC_COUNT_SCENE).instantiate()
	host.add_child(node)
	await host.get_tree().process_frame
	node.pixel_scale = 2
	node.required = 1
	node.allowed = 1
	await host.get_tree().process_frame
	TestFixtures.check(res, "MercCount min size", node.custom_minimum_size == Vector2(116, 28),
		str(node.custom_minimum_size))
	TestFixtures.check(res, "MercCount tooltip singular", node.tooltip_text == "Requires 1, up to 1 merc",
		node.tooltip_text)
	node.queue_free()
