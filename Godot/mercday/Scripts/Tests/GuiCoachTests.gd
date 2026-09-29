class_name GuiCoachTests

#Stage 2 coaching: the Coaching box on the Overview tab, the CoachDialog and its PipModules.
#Run: godot --headless --path . with the user arg --gui-coach-tests

const COACH_BOX := preload("res://Scenes/GUI/Mercs/CoachingBox.tscn")
const COACH_DIALOG := preload("res://Scenes/GUI/Mercs/CoachDialog.tscn")
const PIP_MODULE := preload("res://Scenes/GUI/Mercs/PipModule.tscn")
const MERC_VIEWER := preload("res://Scenes/GUI/Mercs/MercViewer.tscn")

const STANDARD_MODES: Array[StringName] = [&"Auto", &"Random", &"Utility", &"Stats"]
const COMBAT_MODES: Array[StringName] = [&"Support", &"Defensive", &"Offensive"]
const SKILL_MODES: Array[StringName] = [&"Skills", &"Existing Skills", &"New Skills",
	&"Universal", &"Ancestral", &"Tradition", &"Spell"]


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await _case_box(res, host)
	await _case_box_follows_plan(res, host)
	await _case_dialog_chrome(res, host)
	await _case_dialog_groups(res, host)
	await _case_module_states(res, host)
	await _case_locked_modules(res, host)
	await _case_confirm_gate(res, host)
	await _case_confirm_writes(res, host)
	await _case_confirm_refused(res, host)
	await _case_prune(res, host)
	await _case_lock_hover(res, host)
	await _case_on_page(res, host)
	SubscriptionManager.reset()
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	return TestFixtures.summarize(res, "GUI COACH")


static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(11)
	SubscriptionManager.reset()
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()


static func _first() -> MercView:
	return GameState.roster[0] if not GameState.roster.is_empty() else null


static func _open_box(host: Node) -> CoachingBox:
	_fresh()
	var box: CoachingBox = COACH_BOX.instantiate()
	host.add_child(box)
	await host.get_tree().process_frame
	var view: MercView = _first()
	box.set_merc(view.uid if view != null else 0, true)
	return box


static func _open_dialog(host: Node) -> CoachDialog:
	_fresh()
	var dialog: CoachDialog = COACH_DIALOG.instantiate()
	host.add_child(dialog)
	await host.get_tree().process_frame
	dialog.open_for(_first())
	await host.get_tree().process_frame
	return dialog


#The gates of every mode but Auto, shut in one write.
static func _shut_all_gates() -> void:
	var off: Dictionary = {}
	for row: Dictionary in PipDefs.MODES:
		var gate: String = String(row.get("gate", ""))
		if gate != "":
			off[gate] = false
	SubscriptionManager.set_entitlements(off)


static func _case_box(res: Dictionary, host: Node) -> void:
	var box: CoachingBox = await _open_box(host)
	TestFixtures.check(res, "the box is captioned Coaching",
		box.caption.text == "Coaching", "got '%s'" % box.caption.text)
	TestFixtures.check(res, "the caption is Silkscreen 9 px orange",
		box.caption.get_theme_font_size("font_size") == 9
			and box.caption.get_theme_color("font_color").is_equal_approx(Color("#f28c28")),
		"size %d colour %s" % [box.caption.get_theme_font_size("font_size"),
			box.caption.get_theme_color("font_color")])
	TestFixtures.check(res, "the button reads Coach in Silkscreen 11 px",
		box.button_label.text == "Coach"
			and box.button_label.get_theme_font_size("font_size") == 11,
		"text '%s' size %d" % [box.button_label.text,
			box.button_label.get_theme_font_size("font_size")])
	TestFixtures.check(res, "the Coach button is 40 px tall",
		is_equal_approx(box.button.custom_minimum_size.y, 40.0),
		"got %f" % box.button.custom_minimum_size.y)
	TestFixtures.check(res, "the Coach button is the shared BevelButton scene",
		box.button is BevelButton and box.button.kind == &"blue",
		"button %s kind %s" % [box.button, box.button.kind])
	TestFixtures.check(res, "the whistle icon is drawn at two px per art pixel",
		box.icon_rect.pixel_scale == 2 and box.icon_rect.icon != null,
		"scale %d icon %s" % [box.icon_rect.pixel_scale, box.icon_rect.icon])
	TestFixtures.check(res, "the plan line opens on Auto",
		box.plan_text() == "Plan: Auto" and box.plan_value.text == "Auto",
		"line '%s' value '%s'" % [box.plan_text(), box.plan_value.text])
	TestFixtures.check(res, "the plan prefix is sky and the mode is cream",
		box.plan_prefix.get_theme_color("font_color").is_equal_approx(Color("#9cc6ef"))
			and box.plan_value.get_theme_color("font_color").is_equal_approx(Color("#f3ead7")),
		"prefix %s mode %s" % [box.plan_prefix.get_theme_color("font_color"),
			box.plan_value.get_theme_color("font_color")])
	TestFixtures.check(res, "the plan line is 12 px on both halves",
		box.plan_prefix.get_theme_font_size("font_size") == 12
			and box.plan_value.get_theme_font_size("font_size") == 12,
		"prefix %d mode %d" % [box.plan_prefix.get_theme_font_size("font_size"),
			box.plan_value.get_theme_font_size("font_size")])
	TestFixtures.check(res, "the Coach button is live for an employed merc",
		box.can_coach() and not box.button.disabled,
		"can %s disabled %s" % [box.can_coach(), box.button.disabled])
	TestFixtures.check(res, "the box tooltip names the plan in force",
		box.tip_kind() == "Coaching" and box.tip_title() == "Performance Improvement Plan"
			and box.tip_desc().ends_with("Current plan: Auto."),
		"kind '%s' title '%s' desc '%s'" % [box.tip_kind(), box.tip_title(), box.tip_desc()])
	var heard: Array[bool] = [false]
	box.coach_pressed.connect(func() -> void: heard[0] = true)
	box.press_coach()
	TestFixtures.check(res, "press_coach asks for the dialog",
		heard[0], "heard %s" % heard[0])
	box.greyed = true
	heard[0] = false
	box.press_coach()
	TestFixtures.check(res, "a greyed box never asks and takes no pointer",
		not heard[0] and box.button.disabled
			and box.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"heard %s disabled %s filter %d" % [heard[0], box.button.disabled, box.mouse_filter])
	TestFixtures.check(res, "a greyed box dims to the grey tint",
		box.modulate == CoachingBox.GREY_TINT and is_equal_approx(box.modulate.a, 0.4),
		"modulate %s" % box.modulate)
	box.greyed = false
	box.set_merc(0, false)
	TestFixtures.check(res, "an unemployed merc cannot be coached",
		not box.can_coach(), "can %s" % box.can_coach())
	box.queue_free()


static func _case_box_follows_plan(res: Dictionary, host: Node) -> void:
	var box: CoachingBox = await _open_box(host)
	var uid: int = box.merc_uid
	GameState.set_pip_mode(uid, &"Offensive")
	TestFixtures.check(res, "the box follows pip_modes_changed with no refresh call",
		box.plan_text() == "Plan: Offensive" and box.mode() == &"Offensive",
		"line '%s' mode '%s'" % [box.plan_text(), box.mode()])
	GameState.set_pip_mode(uid, &"Auto")
	TestFixtures.check(res, "coaching back to Auto shows Auto",
		box.plan_text() == "Plan: Auto", "got '%s'" % box.plan_text())
	SubscriptionManager.set_entitlements({"pip": false})
	GameState.set_pip_mode(uid, &"Random")
	TestFixtures.check(res, "a mode whose gate is shut is never stored",
		GameState.pip_mode(uid) == &"Auto" and box.plan_text() == "Plan: Auto",
		"mode '%s' line '%s'" % [GameState.pip_mode(uid), box.plan_text()])
	SubscriptionManager.reset()
	box.queue_free()


static func _case_dialog_chrome(res: Dictionary, host: Node) -> void:
	var dialog: CoachDialog = await _open_dialog(host)
	var view: MercView = _first()
	TestFixtures.check(res, "the dialog opens on the merc it was given",
		dialog.visible and dialog.merc != null and dialog.merc.uid == view.uid,
		"visible %s merc %s" % [dialog.visible, dialog.merc])
	TestFixtures.check(res, "the header names the Performance Improvement Plan",
		dialog.header_label.text == "Performance Improvement Plan",
		"got '%s'" % dialog.header_label.text)
	TestFixtures.check(res, "the merc name is orange at 18 px",
		dialog.name_label.text == view.name
			and dialog.name_label.get_theme_color("font_color").is_equal_approx(Color("#f28c28"))
			and dialog.name_label.get_theme_font_size("font_size") == 18,
		"name '%s' colour %s size %d" % [dialog.name_label.text,
			dialog.name_label.get_theme_color("font_color"),
			dialog.name_label.get_theme_font_size("font_size")])
	TestFixtures.check(res, "the line under the name explains the pick",
		dialog.subtitle_label.text == "Choose how this merc focuses when they level up.",
		"got '%s'" % dialog.subtitle_label.text)
	TestFixtures.check(res, "the box is 600 px wide",
		is_equal_approx(dialog.box.custom_minimum_size.x, 600.0)
			and is_equal_approx(CoachDialog.BOX_WIDTH, 600.0),
		"min %f const %f" % [dialog.box.custom_minimum_size.x, CoachDialog.BOX_WIDTH])
	var ring: StyleBoxFlat = dialog.box.get_theme_stylebox("panel") as StyleBoxFlat
	TestFixtures.check(res, "the box wears the four px orange ring",
		ring != null and ring.border_color == Color("#f28c28") and ring.border_width_left == 4,
		"ring %s width %d" % [ring.border_color if ring != null else Color.BLACK,
			ring.border_width_left if ring != null else -1])
	var dim: StyleBoxFlat = dialog.backdrop.get_theme_stylebox("panel") as StyleBoxFlat
	TestFixtures.check(res, "the backdrop dims the screen behind the box",
		dim != null and dim.bg_color.a >= 0.69
			and dim.bg_color.is_equal_approx(Color(6.0 / 255.0, 10.0 / 255.0, 20.0 / 255.0,
				dim.bg_color.a)),
		"dim %s" % [dim.bg_color if dim != null else Color.BLACK])
	TestFixtures.check(res, "the close X is red and the footer names Cancel and Confirm",
		dialog.close_x.text == "X"
			and dialog.close_x.get_theme_color("font_color").r > 0.9
			and dialog.cancel_button.text == "Cancel" and dialog.confirm_button.text == "Confirm",
		"x '%s' cancel '%s' confirm '%s'" % [dialog.close_x.text, dialog.cancel_button.text,
			dialog.confirm_button.text])
	TestFixtures.check(res, "an open dialog is the top frame so escape reaches it",
		GuiFrameStack.top() == dialog, "top %s" % GuiFrameStack.top())
	dialog.press_cancel()
	TestFixtures.check(res, "cancel closes the dialog and leaves the frame stack",
		not dialog.visible and GuiFrameStack.top() != dialog,
		"visible %s top %s" % [dialog.visible, GuiFrameStack.top()])
	dialog.queue_free()


static func _case_dialog_groups(res: Dictionary, host: Node) -> void:
	var dialog: CoachDialog = await _open_dialog(host)
	TestFixtures.check(res, "the three groups sit in the prototype order",
		dialog.group_names() == [PipDefs.GROUP_STANDARD, PipDefs.GROUP_COMBAT,
			PipDefs.GROUP_SKILL],
		"got %s" % str(dialog.group_names()))
	var bad_heads: Array[String] = []
	for group: String in dialog.group_names():
		var block: VBoxContainer = dialog.group_box(group)
		var heading: Label = block.get_node("Heading") as Label
		if heading.text != group or heading.get_theme_font_size("font_size") != 9:
			bad_heads.append(group)
		if not heading.get_theme_color("font_color").is_equal_approx(Color("#9cc6ef")):
			bad_heads.append(group + " colour")
	TestFixtures.check(res, "every group heading is Silkscreen 9 px sky",
		bad_heads.is_empty(), "bad %s" % str(bad_heads))
	var grids_ok: bool = true
	var gaps_ok: bool = true
	for group: String in dialog.group_names():
		var grid: GridContainer = dialog.group_box(group).get_node("Grid") as GridContainer
		if grid.columns != 3:
			grids_ok = false
		if grid.get_theme_constant("h_separation") != 8 or grid.get_theme_constant(
				"v_separation") != 8:
			gaps_ok = false
	TestFixtures.check(res, "each group is a three column grid",
		grids_ok, "columns were not all three")
	TestFixtures.check(res, "each grid keeps the eight px gap",
		gaps_ok, "separations were not all eight")
	TestFixtures.check(res, "the Standard group holds Auto, Random, Utility and Stats in order",
		PipDefs.modes_in(PipDefs.GROUP_STANDARD) == STANDARD_MODES,
		"got %s" % str(PipDefs.modes_in(PipDefs.GROUP_STANDARD)))
	TestFixtures.check(res, "the Combat PIP group holds Support, Defensive and Offensive",
		PipDefs.modes_in(PipDefs.GROUP_COMBAT) == COMBAT_MODES,
		"got %s" % str(PipDefs.modes_in(PipDefs.GROUP_COMBAT)))
	TestFixtures.check(res, "the Skill PIP group holds its seven modes in order",
		PipDefs.modes_in(PipDefs.GROUP_SKILL) == SKILL_MODES,
		"got %s" % str(PipDefs.modes_in(PipDefs.GROUP_SKILL)))
	TestFixtures.check(res, "the dialog builds one module per mode",
		dialog.modules().size() == PipDefs.MODES.size() and PipDefs.MODES.size() == 14,
		"modules %d modes %d" % [dialog.modules().size(), PipDefs.MODES.size()])
	var missing: Array[String] = []
	for row: Dictionary in PipDefs.MODES:
		var mode: StringName = StringName(row["mode"])
		var module: PipModule = dialog.module_for(mode)
		if module == null or module.mode != mode:
			missing.append(String(mode))
		elif module.get_parent().get_parent().name != CoachDialog.node_name_of(
				String(row["group"])):
			missing.append(String(mode) + " group")
	TestFixtures.check(res, "every module sits in the grid of its own group",
		missing.is_empty(), "wrong %s" % str(missing))
	var colours_ok: bool = true
	for group: String in dialog.group_names():
		for mode: StringName in PipDefs.modes_in(group):
			if dialog.module_for(mode).group_color != PipDefs.group_color(group):
				colours_ok = false
	TestFixtures.check(res, "each module takes the colour of its group",
		colours_ok and PipDefs.group_color(PipDefs.GROUP_STANDARD) == Color("#9cc6ef")
			and PipDefs.group_color(PipDefs.GROUP_COMBAT) == Color("#e8583f")
			and PipDefs.group_color(PipDefs.GROUP_SKILL) == Color("#6cc36a"),
		"standard %s combat %s skill %s" % [PipDefs.group_color(PipDefs.GROUP_STANDARD),
			PipDefs.group_color(PipDefs.GROUP_COMBAT),
			PipDefs.group_color(PipDefs.GROUP_SKILL)])
	var descs_ok: bool = true
	for row: Dictionary in PipDefs.MODES:
		var module: PipModule = dialog.module_for(StringName(row["mode"]))
		if module.description != String(row["desc"]) or module.description == "":
			descs_ok = false
	TestFixtures.check(res, "every module carries the description of its row",
		descs_ok, "a module description did not match PipDefs")
	dialog.press_cancel()
	dialog.queue_free()


static func _case_module_states(res: Dictionary, host: Node) -> void:
	_fresh()
	var module: PipModule = PIP_MODULE.instantiate()
	host.add_child(module)
	await host.get_tree().process_frame
	module.set_row(PipDefs.find(&"Support"), SubscriptionManager.entitlements())
	TestFixtures.check(res, "a module stands 44 px tall",
		is_equal_approx(module.custom_minimum_size.y, 44.0),
		"got %f" % module.custom_minimum_size.y)
	var box_style: StyleBoxFlat = module.icon_box.get_theme_stylebox("panel") as StyleBoxFlat
	TestFixtures.check(res, "the icon box is 30 by 30 over the ink swatch",
		module.icon_box.custom_minimum_size == Vector2(30.0, 30.0)
			and box_style != null and box_style.bg_color == Color("#0a0f1c"),
		"size %s bg %s" % [module.icon_box.custom_minimum_size,
			box_style.bg_color if box_style != null else Color.BLACK])
	var span: float = module.icon_rect.offset_right - module.icon_rect.offset_left
	TestFixtures.check(res, "the eight px art is drawn at three px a pixel",
		PipModule.ICON_PX == 3 and is_equal_approx(span, 24.0) and module.icon_rect.texture != null,
		"scale %d span %f texture %s" % [PipModule.ICON_PX, span, module.icon_rect.texture])
	TestFixtures.check(res, "the name reads the mode in Silkscreen 11 px",
		module.name_label.text == "Support"
			and module.name_label.get_theme_font_size("font_size") == 11,
		"text '%s' size %d" % [module.name_label.text,
			module.name_label.get_theme_font_size("font_size")])
	var idle: StyleBoxFlat = module.get_theme_stylebox("panel") as StyleBoxFlat
	TestFixtures.check(res, "an idle module sits dark under a two px blue ring",
		idle.bg_color == Color("#0e1628") and idle.border_color == Color("#2b4f8a")
			and idle.border_width_left == 2
			and module.name_label.get_theme_color("font_color") == Color("#f3ead7"),
		"bg %s ring %s width %d" % [idle.bg_color, idle.border_color, idle.border_width_left])
	module.selected = true
	var hot: StyleBoxFlat = module.get_theme_stylebox("panel") as StyleBoxFlat
	TestFixtures.check(res, "the picked module takes the three px orange ring and orange name",
		hot.bg_color == Color("#15223d") and hot.border_color == Color("#f28c28")
			and hot.border_width_left == 3
			and module.name_label.get_theme_color("font_color") == Color("#f28c28"),
		"bg %s ring %s width %d name %s" % [hot.bg_color, hot.border_color, hot.border_width_left,
			module.name_label.get_theme_color("font_color")])
	TestFixtures.check(res, "the Current tag waits until the mode is the plan in force",
		not module.tag.visible and module.foot_text() == "",
		"visible %s foot '%s'" % [module.tag.visible, module.foot_text()])
	module.is_current = true
	var pill: StyleBoxFlat = module.tag.get_theme_stylebox("panel") as StyleBoxFlat
	TestFixtures.check(res, "the Current tag is a sky pill with ink text at 7 px",
		module.tag.visible and module.tag_label.text == "Current"
			and pill != null and pill.bg_color == Color("#9cc6ef")
			and module.tag_label.get_theme_color("font_color") == Color("#0a0f1c")
			and module.tag_label.get_theme_font_size("font_size") == 7,
		"visible %s text '%s' bg %s" % [module.tag.visible, module.tag_label.text,
			pill.bg_color if pill != null else Color.BLACK])
	TestFixtures.check(res, "the tooltip of the plan in force is footed Current plan",
		module.foot_text() == "Current plan" and module.group_title() == PipDefs.GROUP_COMBAT,
		"foot '%s' group '%s'" % [module.foot_text(), module.group_title()])
	var heard: Array[StringName] = [&""]
	module.picked.connect(func(m: StringName) -> void: heard[0] = m)
	module.press()
	TestFixtures.check(res, "a live module answers a press with its own mode",
		heard[0] == &"Support", "heard '%s'" % heard[0])
	_shut_all_gates()
	module.set_row(PipDefs.find(&"Support"), SubscriptionManager.entitlements())
	var shut: StyleBoxFlat = module.get_theme_stylebox("panel") as StyleBoxFlat
	TestFixtures.check(res, "a locked module goes flat under a two px deep ring",
		module.locked and shut.bg_color == Color("#101a30")
			and shut.border_color == Color("#1f3560") and shut.border_width_left == 2,
		"locked %s bg %s ring %s" % [module.locked, shut.bg_color, shut.border_color])
	TestFixtures.check(res, "a locked module greys its icon and its name",
		module.icon_rect.modulate == Color("#3b4d6e")
			and module.name_label.get_theme_color("font_color") == Color("#5e7699"),
		"icon %s name %s" % [module.icon_rect.modulate,
			module.name_label.get_theme_color("font_color")])
	TestFixtures.check(res, "a locked module carries the lock of its own upgrade",
		module.lock != null and module.lock_holder.visible and module.lock.always_visible
			and module.lock.upgrade == PipDefs.upgrade_name(&"Support")
			and module.lock.upgrade != "" and module.lock.upgrade_id == "combatpip",
		"lock %s upgrade '%s' id '%s'" % [module.lock,
			module.lock.upgrade if module.lock != null else "",
			module.lock.upgrade_id if module.lock != null else ""])
	TestFixtures.check(res, "a locked module drops its Current tag",
		not module.tag.visible, "visible %s" % module.tag.visible)
	heard[0] = &""
	module.press()
	TestFixtures.check(res, "a locked module never answers a press",
		heard[0] == &"", "heard '%s'" % heard[0])
	SubscriptionManager.reset()
	module.queue_free()


#The modes the dialog is offering right now, in grid order.
static func _open_modes(dialog: CoachDialog) -> Array[StringName]:
	var out: Array[StringName] = []
	for module: PipModule in dialog.modules():
		if not module.locked:
			out.append(module.mode)
	return out


static func _case_locked_modules(res: Dictionary, host: Node) -> void:
	var dialog: CoachDialog = await _open_dialog(host)
	TestFixtures.check(res, "the dev default offers every mode",
		_open_modes(dialog).size() == 14, "open %d" % _open_modes(dialog).size())
	SubscriptionManager.set_state(SubscriptionManager.Plan.FREE, {})
	var free_only: Array[StringName] = [&"Auto"]
	TestFixtures.check(res, "a Free plan leaves Auto alone unlocked",
		_open_modes(dialog) == free_only, "open %s" % str(_open_modes(dialog)))
	var bad: Array[String] = []
	for module: PipModule in dialog.modules():
		if not module.locked:
			continue
		if module.lock == null or module.lock.upgrade != PipDefs.upgrade_name(module.mode):
			bad.append(String(module.mode))
		elif module.lock.upgrade == "" or module.lock.tier < 1:
			bad.append(String(module.mode) + " tier")
	TestFixtures.check(res, "every locked module names the upgrade of its own gate",
		bad.is_empty(), "wrong %s" % str(bad))
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"pip": 1})
	var basic: Array[StringName] = [&"Auto", &"Random", &"Utility", &"Stats", &"Skills"]
	TestFixtures.check(res, "the basic plan opens the four Standard modes and Skills",
		_open_modes(dialog) == basic, "open %s" % str(_open_modes(dialog)))
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE,
		{"pip": 1, "combatpip": 2})
	TestFixtures.check(res, "two Combat PIP tiers open Support and Defensive but not Offensive",
		not dialog.module_for(&"Support").locked and not dialog.module_for(&"Defensive").locked
			and dialog.module_for(&"Offensive").locked,
		"open %s" % str(_open_modes(dialog)))
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE,
		{"pip": 1, "combatpip": 3, "skillpip": 5, "magicpip": 1})
	TestFixtures.check(res, "every coaching tier owned offers all fourteen modes",
		_open_modes(dialog).size() == 14, "open %d" % _open_modes(dialog).size())
	SubscriptionManager.reset()
	dialog.press_cancel()
	dialog.queue_free()


static func _case_confirm_gate(res: Dictionary, host: Node) -> void:
	var dialog: CoachDialog = await _open_dialog(host)
	TestFixtures.check(res, "the dialog opens on the plan in force with Confirm dead",
		dialog.current_mode == &"Auto" and dialog.draft_mode == &"Auto"
			and not dialog.confirm_enabled() and dialog.confirm_button.disabled,
		"current '%s' draft '%s'" % [dialog.current_mode, dialog.draft_mode])
	TestFixtures.check(res, "a dead Confirm dims to four tenths and says why",
		is_equal_approx(dialog.confirm_button.modulate.a, 0.4)
			and dialog.confirm_button.tooltip_text == CoachDialog.UNCHANGED_HINT,
		"alpha %f hint '%s'" % [dialog.confirm_button.modulate.a,
			dialog.confirm_button.tooltip_text])
	dialog.press_mode(&"Offensive")
	TestFixtures.check(res, "a pick moves the draft and wakes Confirm",
		dialog.draft_mode == &"Offensive" and dialog.confirm_enabled()
			and not dialog.confirm_button.disabled
			and is_equal_approx(dialog.confirm_button.modulate.a, 1.0),
		"draft '%s' disabled %s" % [dialog.draft_mode, dialog.confirm_button.disabled])
	TestFixtures.check(res, "Confirm is the deep prototype green through the shared BevelButton",
		dialog.confirm_button is BevelButton and dialog.confirm_button.fill == Color("#3f9a4a"),
		"fill %s" % [dialog.confirm_button.fill])
	TestFixtures.check(res, "Cancel and Confirm are both the shared BevelButton scene",
		dialog.cancel_button is BevelButton and dialog.confirm_button is BevelButton
			and dialog.cancel_button.kind == &"neutral" and dialog.confirm_button.kind == &"go",
		"cancel %s confirm %s" % [dialog.cancel_button, dialog.confirm_button])
	TestFixtures.check(res, "only the drafted module wears the ring",
		dialog.module_for(&"Offensive").selected and not dialog.module_for(&"Auto").selected
			and dialog.module_for(&"Auto").is_current,
		"offensive %s auto %s" % [dialog.module_for(&"Offensive").selected,
			dialog.module_for(&"Auto").selected])
	dialog.press_mode(&"Auto")
	TestFixtures.check(res, "picking the plan in force again puts Confirm back to sleep",
		dialog.draft_mode == &"Auto" and dialog.confirm_button.disabled
			and is_equal_approx(dialog.confirm_button.modulate.a, 0.4),
		"draft '%s' disabled %s" % [dialog.draft_mode, dialog.confirm_button.disabled])
	_shut_all_gates()
	dialog.press_mode(&"Spell")
	TestFixtures.check(res, "a locked mode is refused at the dialog as well as the ledger",
		dialog.draft_mode == &"Auto" and not dialog.confirm_enabled(),
		"draft '%s'" % dialog.draft_mode)
	SubscriptionManager.reset()
	dialog.press_cancel()
	dialog.queue_free()


#The engine's own field, which only knows four of the modes.
static func _level_mode(uid: int) -> String:
	var extras: Dictionary = GameState.merc_extras.get(uid, {})
	return String(extras.get("level_mode", ""))


static func _case_confirm_writes(res: Dictionary, host: Node) -> void:
	var dialog: CoachDialog = await _open_dialog(host)
	var uid: int = dialog.merc.uid
	var heard: Array[StringName] = [&""]
	dialog.confirmed.connect(func(m: StringName) -> void: heard[0] = m)
	dialog.press_mode(&"Defensive")
	dialog.press_confirm()
	TestFixtures.check(res, "confirm stores the coached mode on the ledger",
		StringName(GameState.pip_modes.get(uid, &"")) == &"Defensive"
			and GameState.pip_mode(uid) == &"Defensive",
		"stored '%s'" % GameState.pip_modes.get(uid, &""))
	TestFixtures.check(res, "confirm reports the mode it wrote",
		heard[0] == &"Defensive", "heard '%s'" % heard[0])
	TestFixtures.check(res, "confirm closes the dialog and keeps the new plan as current",
		not dialog.visible and GuiFrameStack.top() != dialog
			and dialog.current_mode == &"Defensive",
		"visible %s current '%s'" % [dialog.visible, dialog.current_mode])
	TestFixtures.check(res, "the engine level mode follows a mode it can express",
		_level_mode(uid) == "Defensive", "got '%s'" % _level_mode(uid))
	dialog.open_for(_first())
	TestFixtures.check(res, "reopening tags the stored plan as the current one",
		dialog.current_mode == &"Defensive" and dialog.module_for(&"Defensive").is_current
			and dialog.module_for(&"Defensive").selected,
		"current '%s'" % dialog.current_mode)
	dialog.press_mode(&"Offensive")
	dialog.press_cancel()
	TestFixtures.check(res, "cancel drops the draft and leaves the ledger alone",
		dialog.draft_mode == &"Defensive" and GameState.pip_mode(uid) == &"Defensive",
		"draft '%s' stored '%s'" % [dialog.draft_mode, GameState.pip_mode(uid)])
	dialog.open_for(_first())
	dialog.press_mode(&"Ancestral")
	dialog.press_confirm()
	TestFixtures.check(res, "a mode the engine cannot express still stores whole",
		GameState.pip_mode(uid) == &"Ancestral", "stored '%s'" % GameState.pip_mode(uid))
	TestFixtures.check(res, "the engine level mode falls to Auto for a mode it cannot express",
		_level_mode(uid) == "Auto", "got '%s'" % _level_mode(uid))
	dialog.queue_free()


static func _case_prune(res: Dictionary, host: Node) -> void:
	var box: CoachingBox = await _open_box(host)
	var uid: int = box.merc_uid
	GameState.set_pip_mode(uid, &"Offensive")
	TestFixtures.check(res, "the coached mode is in force while its upgrade is held",
		GameState.pip_mode(uid) == &"Offensive" and box.plan_text() == "Plan: Offensive",
		"mode '%s' line '%s'" % [GameState.pip_mode(uid), box.plan_text()])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"pip": 1})
	TestFixtures.check(res, "losing the upgrade reverts the plan to Auto",
		GameState.pip_mode(uid) == &"Auto" and GameState.stored_pip_mode(uid) == &"Auto"
			and not GameState.pip_modes.has(uid),
		"mode '%s' stored '%s'" % [GameState.pip_mode(uid), GameState.stored_pip_mode(uid)])
	TestFixtures.check(res, "the box shows Auto the moment the upgrade goes",
		box.plan_text() == "Plan: Auto" and _level_mode(uid) == "Auto",
		"line '%s' level '%s'" % [box.plan_text(), _level_mode(uid)])
	SubscriptionManager.reset()
	GameState.set_pip_mode(uid, &"Tradition")
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE,
		{"pip": 1, "skillpip": 5})
	TestFixtures.check(res, "a mode still paid for survives a downgrade beside it",
		GameState.pip_mode(uid) == &"Tradition" and box.plan_text() == "Plan: Tradition",
		"mode '%s' line '%s'" % [GameState.pip_mode(uid), box.plan_text()])
	SubscriptionManager.set_state(SubscriptionManager.Plan.FREE, {})
	TestFixtures.check(res, "a Free plan takes every coached mode with it",
		GameState.pip_modes.is_empty() and box.plan_text() == "Plan: Auto",
		"modes %s line '%s'" % [str(GameState.pip_modes), box.plan_text()])
	SubscriptionManager.reset()
	box.queue_free()


static func _case_lock_hover(res: Dictionary, host: Node) -> void:
	var dialog: CoachDialog = await _open_dialog(host)
	SubscriptionManager.set_state(SubscriptionManager.Plan.FREE, {})
	var module: PipModule = dialog.module_for(&"Offensive")
	var tip: SlotTooltip = dialog.tooltip()
	TestFixtures.check(res, "the dialog carries one tooltip for its modules",
		tip != null and not tip.visible and module.locked,
		"tip %s locked %s" % [tip, module.locked])
	module.hover_started.emit(module)
	TestFixtures.check(res, "hovering a module tells its group, name and description",
		tip.visible and tip.title == "Offensive" and tip.kind_label == PipDefs.GROUP_COMBAT
			and tip.description == PipDefs.desc_of(&"Offensive"),
		"visible %s title '%s' kind '%s'" % [tip.visible, tip.title, tip.kind_label])
	module.lock_hover_enter()
	TestFixtures.check(res, "hovering the lock hides the module tooltip",
		not tip.visible, "visible %s" % tip.visible)
	module.lock_hover_exit()
	TestFixtures.check(res, "leaving the lock brings the module tooltip back",
		tip.visible and tip.title == "Offensive",
		"visible %s title '%s'" % [tip.visible, tip.title])
	module.hover_ended.emit()
	TestFixtures.check(res, "leaving the module closes the tooltip",
		not tip.visible, "visible %s" % tip.visible)
	TestFixtures.check(res, "the tooltip never takes the pointer",
		tip.mouse_filter == Control.MOUSE_FILTER_IGNORE and tip.top_level,
		"filter %d top %s" % [tip.mouse_filter, tip.top_level])
	var live: PipModule = dialog.module_for(&"Auto")
	live.hover_started.emit(live)
	TestFixtures.check(res, "an open module tooltip carries no lock beside it",
		live.lock == null and not live.lock_holder.visible and tip.visible,
		"lock %s holder %s" % [live.lock, live.lock_holder.visible])
	SubscriptionManager.reset()
	dialog.press_cancel()
	dialog.queue_free()


static func _case_on_page(res: Dictionary, host: Node) -> void:
	_fresh()
	var screen: MercViewer = MERC_VIEWER.instantiate()
	host.add_child(screen)
	await host.get_tree().process_frame
	var uid: int = _first().uid
	screen.show_merc(uid)
	await host.get_tree().process_frame
	var tab: OverviewTab = screen.overview()
	var dialog: CoachDialog = screen.coach_dialog()
	TestFixtures.check(res, "the viewer carries the coach dialog shut",
		dialog != null and not dialog.visible, "dialog %s" % dialog)
	TestFixtures.check(res, "the Coaching box sits in the badge column of the Overview tab",
		tab.coaching != null and tab.coaching.get_parent() == tab.badge.get_parent(),
		"parent %s" % tab.coaching.get_parent().name)
	tab.coaching.press_coach()
	TestFixtures.check(res, "the Coach button opens the dialog on the merc on show",
		dialog.visible and dialog.merc != null and dialog.merc.uid == uid,
		"visible %s merc %s" % [dialog.visible, dialog.merc])
	dialog.press_mode(&"Utility")
	dialog.press_confirm()
	TestFixtures.check(res, "confirming from the page writes the plan and moves the line",
		GameState.pip_mode(uid) == &"Utility" and tab.coaching.plan_text() == "Plan: Utility",
		"mode '%s' line '%s'" % [GameState.pip_mode(uid), tab.coaching.plan_text()])
	var left: Node = tab.coaching.get_parent()
	TestFixtures.check(res, "the badge column holds the badge over the box and nothing else",
		left.get_child_count() == 2 and left.get_child(0) == tab.badge
			and left.get_child(1) == tab.coaching,
		"children %d" % left.get_child_count())
	tab.set_applicant_mode(true)
	TestFixtures.check(res, "an applicant cannot be coached",
		not tab.coaching.can_coach() and tab.coaching.button.disabled
			and tab.coaching.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"can %s disabled %s" % [tab.coaching.can_coach(), tab.coaching.button.disabled])
	tab.set_applicant_mode(false)
	TestFixtures.check(res, "back on an employee the box is live again",
		tab.coaching.can_coach() and not tab.coaching.button.disabled,
		"can %s" % tab.coaching.can_coach())
	screen.queue_free()


#A uid no merc in the roster answers to.
static func _free_uid() -> int:
	var high: int = 0
	for view: MercView in GameState.roster:
		high = maxi(high, view.uid)
	return high + 1000


#A write the ledger refuses leaves the dialog open, the draft in place and the signal unsent.
static func _case_confirm_refused(res: Dictionary, host: Node) -> void:
	var dialog: CoachDialog = await _open_dialog(host)
	var uid: int = dialog.merc.uid
	var heard: Array[StringName] = [&""]
	dialog.confirmed.connect(func(m: StringName) -> void: heard[0] = m)
	dialog.press_mode(&"Offensive")
	var gone := MercView.new()
	gone.uid = _free_uid()
	gone.name = dialog.merc.name
	dialog.merc = gone
	dialog.press_confirm()
	TestFixtures.check(res, "a merc who left the roster stores no plan",
		GameState.pip_mode(gone.uid) == &"Auto" and not GameState.pip_modes.has(gone.uid)
			and GameState.pip_mode(uid) == &"Auto",
		"gone '%s' merc '%s'" % [GameState.pip_mode(gone.uid), GameState.pip_mode(uid)])
	TestFixtures.check(res, "a refused write says nothing and keeps the dialog on its draft",
		heard[0] == &"" and dialog.visible and dialog.draft_mode == &"Offensive"
			and dialog.current_mode == &"Auto" and dialog.confirm_enabled()
			and not dialog.confirm_button.disabled,
		"heard '%s' visible %s draft '%s' current '%s'" % [heard[0], dialog.visible,
			dialog.draft_mode, dialog.current_mode])
	dialog.merc = _first()
	dialog.press_confirm()
	TestFixtures.check(res, "the same Confirm lands once the merc is back on the roster",
		GameState.pip_mode(uid) == &"Offensive" and heard[0] == &"Offensive"
			and not dialog.visible and dialog.current_mode == &"Offensive",
		"stored '%s' heard '%s' visible %s" % [GameState.pip_mode(uid), heard[0],
			dialog.visible])
	dialog.queue_free()
