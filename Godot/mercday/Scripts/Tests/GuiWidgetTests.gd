class_name GuiWidgetTests

#Stage 1 widget atoms: LevelBadge, XPTooltip, MercPortrait, SpeedButton, GridMenuButton,
#MoodFace, MoodMeter, TraditionModule, TabButton on the atlas.
#Run: godot --headless --path . with the user arg --gui-widget-tests

const LEVEL_BADGE := preload("res://Scenes/GUI/Shared/LevelBadge.tscn")
const XP_TOOLTIP := preload("res://Scenes/GUI/Shared/XPTooltip.tscn")
const MERC_PORTRAIT := preload("res://Scenes/GUI/Shared/MercPortrait.tscn")
const SPEED_BUTTON := preload("res://Scenes/GUI/Shared/SpeedButton.tscn")
const GRID_MENU_BUTTON := preload("res://Scenes/GUI/Shared/GridMenuButton.tscn")
const MOOD_METER := preload("res://Scenes/GUI/Shared/MoodMeter.tscn")
const TRADITION_MODULE := preload("res://Scenes/GUI/Shared/TraditionModule.tscn")
const SLOT_CHIP := preload("res://Scenes/GUI/Mercs/SlotChip.tscn")
const TAB_BUTTON := preload("res://Scenes/GUI/Mercs/TabButton.tscn")
const GUILD_THEME := preload("res://Resources/GUI/Theme/guild_theme.tres")

#The width a compact tradition line gets inside a 120 px team slot: 120 - 6 ring - 6 inset.
const COMPACT_LINE: float = 108.0


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await _case_xp_tooltip(res, host)
	await _case_xp_tooltip_mouse(res, host)
	await _case_scroll_bar(res, host)
	await _case_level_badge(res, host)
	await _case_level_badge_mouse_filter(res, host)
	await _case_merc_portrait(res, host)
	await _case_speed_button(res, host)
	await _case_grid_menu_button(res, host)
	await _case_mood_face(res, host)
	await _case_mood_meter(res, host)
	await _case_tradition_module(res, host)
	await _case_tab_button_atlas(res, host)
	return TestFixtures.summarize(res, "GUI WIDGET")


static func _case_xp_tooltip(res: Dictionary, host: Node) -> void:
	TestFixtures.check(res, "fraction reads a plain ratio",
		is_equal_approx(XPTooltip.fraction(25, 100), 0.25),
		"got %.4f" % XPTooltip.fraction(25, 100))
	TestFixtures.check(res, "fraction guards a zero or negative next",
		XPTooltip.fraction(5, 0) == 0.0, "got %.4f" % XPTooltip.fraction(5, 0))
	TestFixtures.check(res, "fraction clamps above one",
		XPTooltip.fraction(200, 100) == 1.0, "got %.4f" % XPTooltip.fraction(200, 100))
	var tip: XPTooltip = XP_TOOLTIP.instantiate()
	host.add_child(tip)
	await host.get_tree().process_frame
	tip.set_xp(30, 120)
	TestFixtures.check(res, "set_xp writes the title and body",
		tip.title_label.text == "XP" and tip.body_label.text == "30 / 120",
		"got title '%s' body '%s'" % [tip.title_label.text, tip.body_label.text])
	TestFixtures.check(res, "a tooltip starts hidden",
		not tip.visible, "visible was %s" % tip.visible)
	TestFixtures.check(res, "the xp bar breaks into ten cells",
		XPTooltip.CELLS == 10 and XPTooltip.cells(0.25).size() == XPTooltip.CELLS
			and int(tip.bar.custom_minimum_size.x) == 150,
		"cells %d size %d bar %s" % [XPTooltip.CELLS, XPTooltip.cells(0.25).size(),
			tip.bar.custom_minimum_size])
	var quarter: Array[float] = XPTooltip.cells(0.25)
	TestFixtures.check(res, "a quarter fills two cells and half of the third",
		is_equal_approx(quarter[0], 1.0) and is_equal_approx(quarter[1], 1.0)
			and is_equal_approx(quarter[2], 0.5) and quarter[3] == 0.0
			and quarter[9] == 0.0,
		"got %s" % [quarter])
	var empty_cells: Array[float] = XPTooltip.cells(0.0)
	var full_cells: Array[float] = XPTooltip.cells(1.0)
	TestFixtures.check(res, "an empty bar reads ten zeros and a full bar ten ones",
		empty_cells.count(0.0) == XPTooltip.CELLS and full_cells.count(1.0) == XPTooltip.CELLS,
		"empty %s full %s" % [empty_cells, full_cells])
	TestFixtures.check(res, "cells clamps a fraction outside zero to one",
		XPTooltip.cells(-1.0).count(0.0) == XPTooltip.CELLS
			and XPTooltip.cells(2.0).count(1.0) == XPTooltip.CELLS,
		"under %s over %s" % [XPTooltip.cells(-1.0), XPTooltip.cells(2.0)])
	tip.queue_free()


#Item 8: the tip may never take the pointer, or a hit inside it reads as leaving the badge.
static func _case_xp_tooltip_mouse(res: Dictionary, host: Node) -> void:
	var tip: XPTooltip = XP_TOOLTIP.instantiate()
	host.add_child(tip)
	await host.get_tree().process_frame
	var stoppers: Array[String] = []
	for node: Node in _all_nodes(tip):
		var control: Control = node as Control
		if control != null and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			stoppers.append(control.name)
	TestFixtures.check(res, "every node of the xp tooltip ignores the mouse",
		tip.passes_mouse() and stoppers.is_empty(), "blockers %s" % str(stoppers))
	TestFixtures.check(res, "the tooltip rows and the xp bar ignore the mouse",
		tip.bar.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and tip.title_label.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and tip.body_label.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"bar %d title %d body %d" % [tip.bar.mouse_filter, tip.title_label.mouse_filter,
			tip.body_label.mouse_filter])
	tip.queue_free()
	var badge: LevelBadge = LEVEL_BADGE.instantiate()
	host.add_child(badge)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the badge alone owns the hover so only the plate holds the tip",
		badge.row.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and badge.tag_label.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and badge.mouse_filter == Control.MOUSE_FILTER_PASS,
		"row %d tag %d badge %d" % [badge.row.mouse_filter, badge.tag_label.mouse_filter,
			badge.mouse_filter])
	badge.show_tip()
	badge.notification(Control.NOTIFICATION_MOUSE_EXIT)
	TestFixtures.check(res, "the tip closes the moment the pointer leaves the badge",
		not badge.tip().visible, "visible was %s" % badge.tip().visible)
	badge.show_tip()
	badge.notification(Control.NOTIFICATION_MOUSE_EXIT_SELF)
	TestFixtures.check(res, "leaving the plate itself closes the tip as well",
		not badge.tip().visible, "visible was %s" % badge.tip().visible)
	badge.queue_free()


static func _all_nodes(root: Node) -> Array[Node]:
	var out: Array[Node] = [root]
	for child: Node in root.get_children():
		out.append_array(_all_nodes(child))
	return out


static func _case_scroll_bar(res: Dictionary, host: Node) -> void:
	var scroll := ScrollContainer.new()
	scroll.theme = GUILD_THEME
	host.add_child(scroll)
	await host.get_tree().process_frame
	var v_thick: float = scroll.get_v_scroll_bar().get_combined_minimum_size().x
	var h_thick: float = scroll.get_h_scroll_bar().get_combined_minimum_size().y
	TestFixtures.check(res, "item 9 every scroll bar is 12 px thick",
		v_thick >= 12.0 and h_thick >= 12.0,
		"vertical %f horizontal %f" % [v_thick, h_thick])
	scroll.queue_free()


static func _case_level_badge(res: Dictionary, host: Node) -> void:
	var badge: LevelBadge = LEVEL_BADGE.instantiate()
	host.add_child(badge)
	await host.get_tree().process_frame
	badge.level = 7
	TestFixtures.check(res, "level writes the Number label",
		badge.number_label.text == "7", "got '%s'" % badge.number_label.text)
	badge.show_tip()
	TestFixtures.check(res, "show_tip opens the XP tooltip with the default fraction",
		badge.tip().visible and badge.tip().body_label.text == "0 / 1",
		"visible %s body '%s'" % [badge.tip().visible, badge.tip().body_label.text])
	badge.hide_tip()
	TestFixtures.check(res, "hide_tip closes it",
		not badge.tip().visible, "visible was %s" % badge.tip().visible)
	badge.size_mode = LevelBadge.SizeMode.TILE
	await host.get_tree().process_frame
	var tile_ok: bool = (badge.custom_minimum_size == Vector2(48, 56)
		and badge.number_label.text == "07" and badge.row.vertical)
	badge.size_mode = LevelBadge.SizeMode.LARGE
	await host.get_tree().process_frame
	var large_ok: bool = (badge.custom_minimum_size == Vector2(112, 112)
		and badge.tag_label.text == "Level")
	badge.size_mode = LevelBadge.SizeMode.CHIP
	await host.get_tree().process_frame
	var chip_ok: bool = badge.number_label.text == "7" and badge.tag_label.text == "LVL"
	TestFixtures.check(res, "tile and large modes size the badge and pad the number",
		tile_ok and large_ok and chip_ok,
		"tile %s large %s chip %s" % [tile_ok, large_ok, chip_ok])
	badge.queue_free()


#Item: an owner that mutes the badge's mouse input gets no tip even though Row still forwards hover.
static func _case_level_badge_mouse_filter(res: Dictionary, host: Node) -> void:
	var badge: LevelBadge = LEVEL_BADGE.instantiate()
	host.add_child(badge)
	await host.get_tree().process_frame
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.show_tip()
	TestFixtures.check(res, "show_tip is a no-op when mouse_filter is IGNORE",
		not badge.tip().visible, "visible was %s" % badge.tip().visible)
	badge.mouse_filter = Control.MOUSE_FILTER_PASS
	badge.show_tip()
	TestFixtures.check(res, "show_tip opens the tip again once mouse_filter is PASS",
		badge.tip().visible, "visible was %s" % badge.tip().visible)
	badge.queue_free()


static func _case_merc_portrait(res: Dictionary, host: Node) -> void:
	var expect_layers: Array[String] = ["Backpack", "HairBack", "Cape", "Body", "Weapon",
		"OverCape", "Eyes", "HairFront", "Headwear", "Headwear Add-On"]
	TestFixtures.check(res, "layers lists the ten sprites in scene order",
		MercPortrait.layers() == expect_layers, "got %s" % [MercPortrait.layers()])
	TestFixtures.check(res, "shrink_for steps at the 48 px frame size",
		MercPortrait.shrink_for(48) == 1 and MercPortrait.shrink_for(96) == 2
			and MercPortrait.shrink_for(144) == 3,
		"got %d, %d, %d" % [MercPortrait.shrink_for(48), MercPortrait.shrink_for(96),
			MercPortrait.shrink_for(144)])
	var portrait: MercPortrait = MERC_PORTRAIT.instantiate()
	host.add_child(portrait)
	await host.get_tree().process_frame
	portrait.pixel_size = 96
	TestFixtures.check(res, "pixel_size sizes the container and the shrink factor",
		portrait.custom_minimum_size == Vector2(96, 96) and portrait.stretch_shrink == 2,
		"got size %s shrink %d" % [portrait.custom_minimum_size, portrait.stretch_shrink])
	portrait.set_frame(3)
	var all_frame_3 := true
	for layer_name: String in MercPortrait.layers():
		if portrait.layer(layer_name).frame != 3:
			all_frame_3 = false
	TestFixtures.check(res, "set_frame writes every layer sprite",
		all_frame_3, "one or more layers did not read frame 3")
	portrait.clear_layer("Cape")
	TestFixtures.check(res, "clear_layer hides the sprite",
		not portrait.layer("Cape").visible, "Cape was visible")
	var tex := PlaceholderTexture2D.new()
	portrait.set_layer_texture("Cape", tex)
	TestFixtures.check(res, "set_layer_texture shows the sprite again",
		portrait.layer("Cape").visible and portrait.layer("Cape").texture == tex,
		"visible %s" % portrait.layer("Cape").visible)
	TestFixtures.check(res, "a change rearms the viewport for one more render",
		portrait.view.render_target_update_mode == SubViewport.UPDATE_ONCE,
		"got %d" % portrait.view.render_target_update_mode)
	portrait.queue_free()


static func _case_speed_button(res: Dictionary, host: Node) -> void:
	var ids: Array[String] = []
	var known := true
	for mode: int in range(5):
		var id: String = SpeedButton.icon_id(mode)
		ids.append(id)
		if not Icons.has(id):
			known = false
	TestFixtures.check(res, "icon_id names the atlas art of every speed step",
		ids == ["speed_slow", "pause", "play", "speed_fast", "speed_faster"], "got %s" % [ids])
	TestFixtures.check(res, "every speed icon is an id the atlas holds",
		known and SpeedButton.icon_id(9) == "", "got %s" % [ids])
	TestFixtures.check(res, "label_for names every speed",
		SpeedButton.label_for(0) == "Slow Down" and SpeedButton.label_for(1) == "Pause"
			and SpeedButton.label_for(2) == "Play" and SpeedButton.label_for(3) == "Fast Forward"
			and SpeedButton.label_for(4) == "Faster Fast Forward",
		"got %s" % [[SpeedButton.label_for(0), SpeedButton.label_for(1), SpeedButton.label_for(2),
			SpeedButton.label_for(3), SpeedButton.label_for(4)]])
	var btn: SpeedButton = SPEED_BUTTON.instantiate()
	host.add_child(btn)
	await host.get_tree().process_frame
	btn.speed_mode = ClockRunner.Speed.FAST
	var heard: Array = []
	btn.speed_selected.connect(func(mode: int) -> void: heard.append(mode))
	btn.pressed.emit()
	TestFixtures.check(res, "pressed emits speed_selected with the current mode",
		heard == [3], "got %s" % [heard])
	btn.queue_free()


static func _case_grid_menu_button(res: Dictionary, host: Node) -> void:
	var btn: GridMenuButton = GRID_MENU_BUTTON.instantiate()
	host.add_child(btn)
	await host.get_tree().process_frame
	btn.label = "Metrics"
	TestFixtures.check(res, "label writes the strip text",
		btn.text_label.text == "Metrics", "got '%s'" % btn.text_label.text)
	btn.description = "Opens the metrics window"
	TestFixtures.check(res, "description sets the tooltip",
		btn.tooltip_text == "Opens the metrics window", "got '%s'" % btn.tooltip_text)
	btn.hover(true)
	TestFixtures.check(res, "hover on reads the orange highlight",
		btn.text_color().is_equal_approx(GridMenuButton.HOVER_COLOR), "got %s" % btn.text_color())
	btn.hover(false)
	TestFixtures.check(res, "hover off restores cream",
		btn.text_color().is_equal_approx(GridMenuButton.NORMAL_COLOR), "got %s" % btn.text_color())
	var throwaway := Control.new()
	var scene := PackedScene.new()
	scene.pack(throwaway)
	throwaway.free()
	btn.window_scene = scene
	var heard: Array = []
	btn.opened.connect(func(s: PackedScene) -> void: heard.append(s))
	btn.pressed.emit()
	TestFixtures.check(res, "pressed emits opened with the window scene",
		heard.size() == 1 and heard[0] == scene, "got %s" % [heard])
	btn.icon_rect.set_id("metrics", 4)
	await host.get_tree().process_frame
	var grid_icon: IconRect = btn.icon_rect
	var grid_icon_rect: Rect2 = grid_icon.get_global_rect()
	var grid_btn_rect: Rect2 = btn.get_global_rect()
	TestFixtures.check(res, "grid menu button icon centres at 4x after set_id",
		grid_icon.stretch_mode == TextureRect.STRETCH_KEEP_CENTERED
			and grid_icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
			and grid_icon.custom_minimum_size == Vector2(64, 64)
			and grid_icon.size == Vector2(64, 64)
			and absf(grid_icon_rect.get_center().x - grid_btn_rect.get_center().x) <= 1.0,
		"stretch %d filter %d min %s size %s icon_center %.2f btn_center %.2f" % [grid_icon.stretch_mode,
			grid_icon.texture_filter, grid_icon.custom_minimum_size, grid_icon.size,
			grid_icon_rect.get_center().x, grid_btn_rect.get_center().x])
	btn.queue_free()


static func _case_mood_face(res: Dictionary, host: Node) -> void:
	TestFixtures.check(res, "the five mood levels read the row 7 face ids",
		MoodFace.face_id_for(0, false, 0, true) == "face_m5"
			and MoodFace.face_id_for(1, false, 0, true) == "face_m3"
			and MoodFace.face_id_for(2, false, 0, true) == "face_0"
			and MoodFace.face_id_for(3, false, 0, true) == "face_p3"
			and MoodFace.face_id_for(4, false, 0, true) == "face_p5",
		"got %s" % MoodFace.face_id_for(0, false, 0, true))
	TestFixtures.check(res, "an unfilled face reads its row 8 outline twin",
		MoodFace.face_id_for(2, false, 0, false) == "face_0_o",
		MoodFace.face_id_for(2, false, 0, false))
	TestFixtures.check(res, "guild faces read the opinion level instead",
		MoodFace.face_id_for(0, true, -5, true) == "face_m5"
			and MoodFace.face_id_for(0, true, 0, true) == "face_0"
			and MoodFace.face_id_for(0, true, 5, true) == "face_p5",
		"got %s" % MoodFace.face_id_for(0, true, 5, true))
	TestFixtures.check(res, "an opinion above 5 clamps to 5",
		MoodFace.face_id_for(0, true, 7, true) == "face_p5",
		MoodFace.face_id_for(0, true, 7, true))
	TestFixtures.check(res, "an unfilled guild face reads its outline twin",
		MoodFace.face_id_for(0, true, -2, false) == "face_m2_o",
		MoodFace.face_id_for(0, true, -2, false))
	var clear := Color(0, 0, 0, 0)
	TestFixtures.check(res, "color_for reads the mood colour when guild is off",
		MoodFace.color_for(4, false, 0, clear).is_equal_approx(
			Color(0.423529, 0.764706, 0.415686, 1)), "got %s" % MoodFace.color_for(4, false, 0, clear))
	TestFixtures.check(res, "color_for reads the worst guild colour at opinion -5",
		MoodFace.color_for(0, true, -5, clear).is_equal_approx(
			Color(0.909804, 0.345098, 0.247059, 1)), "got %s" % MoodFace.color_for(0, true, -5, clear))
	TestFixtures.check(res, "an opaque fill_color overrides the mood colour",
		MoodFace.color_for(0, false, 0, Color(1, 1, 1, 1)).is_equal_approx(Color(1, 1, 1, 1)),
		"got %s" % MoodFace.color_for(0, false, 0, Color(1, 1, 1, 1)))
	var face: MoodFace = MoodFace.new()
	host.add_child(face)
	await host.get_tree().process_frame
	face.pixel_scale = 2
	await host.get_tree().process_frame
	TestFixtures.check(res, "a face at scale 2 asks for the 24 px box",
		face.custom_minimum_size == Vector2(24, 24), str(face.custom_minimum_size))
	face.queue_free()


static func _case_mood_meter(res: Dictionary, host: Node) -> void:
	var meter: MoodMeter = MOOD_METER.instantiate()
	host.add_child(meter)
	await host.get_tree().process_frame
	meter.mood = 3
	var filled_ok := true
	for i: int in range(meter.faces.size()):
		if meter.faces[i].filled != (i == 3):
			filled_ok = false
	TestFixtures.check(res, "mood 3 fills only the third face", filled_ok,
		"a face did not match the expected filled state")
	TestFixtures.check(res, "the tooltip names the mood",
		meter.tooltip_text == "Okay", "got '%s'" % meter.tooltip_text)
	meter.set_from_relationship(10)
	TestFixtures.check(res, "a relationship of 10 reads the happiest face",
		meter.mood == 4, "got %d" % meter.mood)
	meter.set_from_relationship(0)
	TestFixtures.check(res, "a relationship of 0 reads the angriest face",
		meter.mood == 0, "got %d" % meter.mood)
	meter.queue_free()


#S13: the one tradition panel, in its title size, its list row size and the compact slot size.
static func _case_tradition_module(res: Dictionary, host: Node) -> void:
	var title: TraditionModule = TRADITION_MODULE.instantiate()
	title.custom_minimum_size = Vector2(260, 0)
	host.add_child(title)
	await host.get_tree().process_frame
	title.tradition = "Warrior"
	await host.get_tree().process_frame
	TestFixtures.check(res, "the title module keeps the 40 px sigil box and the 18 px name",
		title.size_mode == TraditionModule.SizeMode.TITLE
			and title.sigil_box().size == Vector2(40, 40)
			and title.name_label().get_theme_font_size("font_size") == 18
			and title.band_px() == TraditionModule.TITLE_BAND_PX,
		"mode %d box %s font %d band %.1f" % [title.size_mode, title.sigil_box().size,
			title.name_label().get_theme_font_size("font_size"), title.band_px()])
	var ring: StyleBoxFlat = title.sigil_box().get_theme_stylebox("panel") as StyleBoxFlat
	TestFixtures.check(res, "the ring and the sigil take the tradition colour",
		ring != null and ring.border_color == GuiTypes.tradition_color("Warrior")
			and title.ring_color() == GuiTypes.tradition_color("Warrior")
			and title.sigil().tradition == "Warrior"
			and title.name_label().text == "Warrior",
		"ring %s name '%s'" % [ring.border_color if ring != null else Color.BLACK,
			title.name_label().text])
	var sigil_rect: Rect2 = title.sigil().get_global_rect()
	var name_rect: Rect2 = title.name_label().get_global_rect()
	var panel_rect: Rect2 = title.get_global_rect()
	TestFixtures.check(res, "the sigil sits left of the name inside the module",
		panel_rect.encloses(sigil_rect) and sigil_rect.end.x <= name_rect.position.x
			and title.size_flags_horizontal == Control.SIZE_EXPAND_FILL,
		"sigil %s name %s panel %s flags %d" % [sigil_rect, name_rect, panel_rect,
			title.size_flags_horizontal])
	title.tradition = ""
	await host.get_tree().process_frame
	var blank: StyleBoxFlat = title.sigil_box().get_theme_stylebox("panel") as StyleBoxFlat
	TestFixtures.check(res, "an empty tradition reads the empty text in the fallback ring",
		title.name_label().text == title.empty_text
			and blank != null and blank.border_color == GuiTypes.tradition_color("")
			and title.ring_color() == GuiTypes.FALLBACK_COLOR,
		"name '%s' ring %s" % [title.name_label().text,
			blank.border_color if blank != null else Color.BLACK])
	title.queue_free()
	var chip: SlotChip = SLOT_CHIP.instantiate()
	host.add_child(chip)
	var row: TraditionModule = TRADITION_MODULE.instantiate()
	row.size_mode = TraditionModule.SizeMode.ROW
	row.custom_minimum_size = Vector2(260, 0)
	host.add_child(row)
	await host.get_tree().process_frame
	row.tradition = "Mage"
	await host.get_tree().process_frame
	TestFixtures.check(res, "the row module stands as tall as a slot chip",
		row.size.y == chip.custom_minimum_size.y and row.size.y == 32.0,
		"row %.1f chip %.1f" % [row.size.y, chip.custom_minimum_size.y])
	TestFixtures.check(res, "the row module carries the 28 px sigil box and the chip font size",
		row.sigil_box().size == Vector2(28, 28)
			and row.name_label().get_theme_font_size("font_size")
				== chip.name_label.get_theme_font_size("font_size")
			and row.band_px() == TraditionModule.ROW_BAND_PX,
		"box %s font %d chip font %d band %.1f" % [row.sigil_box().size,
			row.name_label().get_theme_font_size("font_size"),
			chip.name_label.get_theme_font_size("font_size"), row.band_px()])
	var row_sigil: Rect2 = row.sigil().get_global_rect()
	var row_name: Rect2 = row.name_label().get_global_rect()
	TestFixtures.check(res, "the row module keeps the sigil left of the name",
		row.get_global_rect().encloses(row_sigil) and row_sigil.end.x <= row_name.position.x
			and row.size_flags_horizontal == Control.SIZE_EXPAND_FILL,
		"sigil %s name %s panel %s" % [row_sigil, row_name, row.get_global_rect()])
	chip.queue_free()
	row.queue_free()
	var compact: TraditionModule = TRADITION_MODULE.instantiate()
	compact.size_mode = TraditionModule.SizeMode.COMPACT
	compact.custom_minimum_size = Vector2(COMPACT_LINE, 0)
	host.add_child(compact)
	await host.get_tree().process_frame
	compact.tradition = "Warrior"
	await host.get_tree().process_frame
	TestFixtures.check(res, "the compact module carries a 20 px sigil box and the 9 px name",
		compact.sigil_box().size == TraditionModule.COMPACT_BOX
			and compact.name_label().get_theme_font_size("font_size")
				== TraditionModule.COMPACT_FONT_PX
			and compact.band_px() == TraditionModule.COMPACT_BAND_PX,
		"box %s font %d band %.1f" % [compact.sigil_box().size,
			compact.name_label().get_theme_font_size("font_size"), compact.band_px()])
	var thin: StyleBoxFlat = compact.sigil_box().get_theme_stylebox("panel") as StyleBoxFlat
	TestFixtures.check(res, "the compact ring thins to 1 px and the name keeps its full width",
		thin != null and thin.border_width_left == TraditionModule.COMPACT_RING_PX
			and not compact.name_label().clip_text,
		"ring %d clip %s" % [thin.border_width_left if thin != null else -1,
			compact.name_label().clip_text])
	var widest: String = ""
	var widest_px: float = 0.0
	for tradition_name: String in GuiTypes.TRADITION_COLORS:
		compact.tradition = tradition_name
		await host.get_tree().process_frame
		var want: float = (compact.name_label().get_minimum_size().x
			+ TraditionModule.COMPACT_BOX.x + float(TraditionModule.COMPACT_SEPARATION)
			+ TraditionModule.COMPACT_MARGIN.x * 2.0)
		if want > widest_px:
			widest_px = want
			widest = tradition_name
	TestFixtures.check(res, "every tradition name fits the 108 px slot line",
		widest_px <= COMPACT_LINE, "widest %s asks %.1f of %.1f" % [widest, widest_px,
			COMPACT_LINE])
	compact.queue_free()


#S14: a tab button driven by an atlas id instead of a loose texture.
static func _case_tab_button_atlas(res: Dictionary, host: Node) -> void:
	var tab: TabButton = TAB_BUTTON.instantiate()
	host.add_child(tab)
	await host.get_tree().process_frame
	tab.icon_id = "eye"
	tab.icon_scale = 2
	tab.active = false
	await host.get_tree().process_frame
	TestFixtures.check(res, "an atlas tab carries one 16 px cell at its icon scale",
		tab.icon_rect.custom_minimum_size == Vector2(32, 32)
			and tab.icon_rect.icon_id == "eye" and tab.icon_rect.pixel_scale == 2
			and tab.icon_rect.visible,
		"box %s id '%s' scale %d" % [tab.icon_rect.custom_minimum_size, tab.icon_rect.icon_id,
			tab.icon_rect.pixel_scale])
	TestFixtures.check(res, "an idle atlas tab draws its plain art",
		tab.icon_rect.mode == Icons.MODE_PLAIN, str(tab.icon_rect.mode))
	tab.active = true
	await host.get_tree().process_frame
	TestFixtures.check(res, "the active atlas tab takes the two tone paint",
		tab.icon_rect.mode == Icons.MODE_TWO_TONE, str(tab.icon_rect.mode))
	tab.locked = true
	await host.get_tree().process_frame
	TestFixtures.check(res, "a locked atlas tab wears the gold lock at scale 3",
		tab.lock_overlay.visible and tab.lock_overlay.texture != null
			and tab.lock_overlay.texture.get_size() == Vector2(24, 27)
			and tab.lock_overlay.modulate == GuiColors.LOCK_GOLD,
		"visible %s size %s tint %s" % [tab.lock_overlay.visible,
			tab.lock_overlay.texture.get_size() if tab.lock_overlay.texture != null else Vector2.ZERO,
			tab.lock_overlay.modulate])
	tab.queue_free()
