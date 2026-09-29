class_name GuiAtomTests

#Six shared GUI atoms: QuantityStepper, PixelSlider, DualSlider, OptionDropdown, TextEntryDialog
#and ConfirmDialog rich variant. Run with gui-atom-tests harness flag.

const QUANTITY_SCENE := "res://Scenes/GUI/Shared/QuantityStepper.tscn"
const PIXEL_SLIDER_SCENE := "res://Scenes/GUI/Shared/PixelSlider.tscn"
const DUAL_SLIDER_SCENE := "res://Scenes/GUI/Shared/DualSlider.tscn"
const OPTION_DROPDOWN_SCENE := "res://Scenes/GUI/Shared/OptionDropdown.tscn"
const TEXT_ENTRY_SCENE := "res://Scenes/GUI/Shared/TextEntryDialog.tscn"
const CONFIRM_SCENE := "res://Scenes/GUI/Shared/ConfirmDialog.tscn"
const DIALOG_PAD: int = 14
const BEVEL_STATES: Array[StringName] = [&"normal", &"hover", &"pressed", &"disabled", &"focus",
	&"hover_pressed"]


#The effect script the effect export is pointed at: it counts the two hooks it is handed.
class ProbeEffect extends BevelButtonEffect:
	var attached: int = 0
	var painted: int = 0

	func attach(_button: BevelButton) -> void:
		attached += 1

	func draw(_button: BevelButton) -> void:
		painted += 1


#A Control that runs the two static painters inside a real draw pass.
class PaintProbe extends Control:
	var painted: int = 0
	var failed: int = 0

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			failed += 1
			return
		BevelButton.paint_body(self, rect, BevelButton.BLUE_FILL, 2.0, BevelButton.INK)
		BevelButton.paint_edges(self, rect, BevelButton.BLUE_HI, BevelButton.BLUE_LO, 2.0)
		painted += 1


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await _case_quantity_stepper(res, host)
	await _case_pixel_slider(res, host)
	await _case_dual_slider(res, host)
	await _case_option_dropdown(res, host)
	await _case_text_entry_dialog(res, host)
	await _case_confirm_rich(res, host)
	await _case_bevel_button(res, host)
	await _case_bevel_paint(res, host)
	await _case_confirm_buttons(res, host)
	await _case_confirm_dialog_legacy(res, host)
	return TestFixtures.summarize(res, "GUI ATOM")


static func _mouse_button(pos: Vector2, pressed: bool) -> InputEventMouseButton:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = pressed
	mb.position = pos
	return mb


static func _key(keycode: Key, pressed: bool = true, unicode: int = 0) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = keycode
	k.pressed = pressed
	k.unicode = unicode
	return k


#_unhandled_key_input is an engine virtual and cannot be resolved as an external class
#member for a direct call, so physical-keyboard tests push the event through the viewport
#and let normal input dispatch reach it, matching the _push_escape convention in
#GuiFrameTests.gd.
static func _push_key(host: Node, event: InputEventKey) -> void:
	host.get_viewport().push_input(event)
	await host.get_tree().process_frame


static func _case_quantity_stepper(res: Dictionary, host: Node) -> void:
	var stepper: QuantityStepper = (load(QUANTITY_SCENE) as PackedScene).instantiate()
	host.add_child(stepper)
	await host.get_tree().process_frame
	stepper.min_value = 0
	stepper.max_value = 5
	stepper.step = 1
	stepper.value = 3
	TestFixtures.check(res, "value setter clamps to an explicit range",
		stepper.value == 3, "got %d" % stepper.value)
	var events: Array[int] = []
	stepper.value_changed.connect(func(v: int) -> void: events.append(v))
	stepper.press_plus()
	stepper.press_plus()
	TestFixtures.check(res, "press_plus steps up and emits value_changed",
		stepper.value == 5 and events == [4, 5], "value %d events %s" % [stepper.value, str(events)])
	stepper.press_plus()
	TestFixtures.check(res, "press_plus clamps at max_value and stops emitting",
		stepper.value == 5 and events == [4, 5], "value %d events %s" % [stepper.value, str(events)])
	stepper.set_value_silent(0)
	TestFixtures.check(res, "set_value_silent changes the value without a signal",
		stepper.value == 0 and events == [4, 5], "value %d events %s" % [stepper.value, str(events)])
	stepper.press_minus()
	TestFixtures.check(res, "press_minus clamps at min_value and stops emitting",
		stepper.value == 0 and events == [4, 5], "value %d events %s" % [stepper.value, str(events)])
	stepper.step = 2
	stepper.press_plus()
	TestFixtures.check(res, "a wider step multiplies the change",
		stepper.value == 2 and events == [4, 5, 2], "value %d events %s" % [stepper.value, str(events)])
	TestFixtures.check(res, "the stepper wears the atlas minus and plus instead of a letter",
		stepper.minus_button.text == "" and stepper.plus_button.text == ""
			and stepper.minus_button.icon != null and stepper.plus_button.icon != null
			and stepper.minus_button.icon.get_size() == Vector2(10, 2)
			and stepper.plus_button.icon.get_size() == Vector2(10, 10),
		"minus %s plus %s" % [str(stepper.minus_button.icon), str(stepper.plus_button.icon)])
	TestFixtures.check(res, "the stepper buttons stand 28 px square and tint their art cream",
		stepper.minus_button.custom_minimum_size == Vector2(28, 28)
			and stepper.plus_button.custom_minimum_size == Vector2(28, 28)
			and stepper.minus_button.get_theme_color(&"icon_normal_color") == QuantityStepper.ICON_COLOR,
		"minus %s" % str(stepper.minus_button.custom_minimum_size))
	stepper.queue_free()


static func _case_pixel_slider(res: Dictionary, host: Node) -> void:
	var slider: PixelSlider = (load(PIXEL_SLIDER_SCENE) as PackedScene).instantiate()
	host.add_child(slider)
	await host.get_tree().process_frame
	slider.custom_minimum_size = Vector2.ZERO
	slider.size = Vector2(100.0, 21.0)
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = 0.0
	var events: Array[float] = []
	slider.value_changed.connect(func(v: float) -> void: events.append(v))
	slider._gui_input(_mouse_button(Vector2(50.0, 10.0), true))
	TestFixtures.check(res, "a click sets the value from its ratio along the track",
		is_equal_approx(slider.value, 50.0) and events.size() == 1
			and is_equal_approx(events[0], 50.0),
		"value %.1f events %s" % [slider.value, str(events)])
	slider._gui_input(_mouse_button(Vector2(50.0, 10.0), false))
	slider._gui_input(_key(KEY_RIGHT))
	TestFixtures.check(res, "the right arrow steps the value up by one step",
		is_equal_approx(slider.value, 51.0) and events.size() == 2
			and is_equal_approx(events[1], 51.0),
		"value %.1f events %s" % [slider.value, str(events)])
	slider._gui_input(_key(KEY_LEFT))
	TestFixtures.check(res, "the left arrow steps the value back down",
		is_equal_approx(slider.value, 50.0) and events.size() == 3,
		"value %.1f events %s" % [slider.value, str(events)])
	slider.disabled = true
	slider._gui_input(_key(KEY_RIGHT))
	TestFixtures.check(res, "a disabled slider ignores keyboard input",
		is_equal_approx(slider.value, 50.0) and events.size() == 3,
		"value %.1f events %s" % [slider.value, str(events)])
	slider.queue_free()


static func _case_dual_slider(res: Dictionary, host: Node) -> void:
	var slider: DualSlider = (load(DUAL_SLIDER_SCENE) as PackedScene).instantiate()
	host.add_child(slider)
	await host.get_tree().process_frame
	slider.custom_minimum_size = Vector2.ZERO
	slider.size = Vector2(100.0, 21.0)
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.low = 20.0
	slider.high = 80.0
	var events: Array[Vector2] = []
	slider.range_changed.connect(func(lo: float, hi: float) -> void: events.append(Vector2(lo, hi)))
	slider._gui_input(_mouse_button(Vector2(15.0, 10.0), true))
	TestFixtures.check(res, "a click nearer the low thumb moves only the low end",
		is_equal_approx(slider.low, 15.0) and is_equal_approx(slider.high, 80.0)
			and events.size() == 1, "low %.1f high %.1f events %s" %
			[slider.low, slider.high, str(events)])
	slider._gui_input(_mouse_button(Vector2(15.0, 10.0), false))
	slider._gui_input(_mouse_button(Vector2(90.0, 10.0), true))
	TestFixtures.check(res, "a click nearer the high thumb moves only the high end",
		is_equal_approx(slider.low, 15.0) and is_equal_approx(slider.high, 90.0)
			and events.size() == 2, "low %.1f high %.1f events %s" %
			[slider.low, slider.high, str(events)])
	slider._gui_input(_mouse_button(Vector2(90.0, 10.0), false))
	slider.low = 95.0
	TestFixtures.check(res, "raising low above high pulls high up to match",
		is_equal_approx(slider.low, 95.0) and is_equal_approx(slider.high, 95.0),
		"low %.1f high %.1f" % [slider.low, slider.high])
	slider.high = 30.0
	TestFixtures.check(res, "lowering high below low pulls low down to match",
		is_equal_approx(slider.low, 30.0) and is_equal_approx(slider.high, 30.0),
		"low %.1f high %.1f" % [slider.low, slider.high])
	slider.queue_free()


static func _case_option_dropdown(res: Dictionary, host: Node) -> void:
	var dropdown: OptionDropdown = (load(OPTION_DROPDOWN_SCENE) as PackedScene).instantiate()
	host.add_child(dropdown)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var opts: Array[Dictionary] = [
		{"key": &"a", "label": "Alpha", "enabled": true},
		{"key": &"b", "label": "Beta", "enabled": false, "reason": "Locked recipe"}]
	dropdown.set_options(opts)
	var chosen: Array[StringName] = []
	dropdown.option_selected.connect(func(k: StringName) -> void: chosen.append(k))
	dropdown.select(&"a", true)
	TestFixtures.check(res, "selecting a valid key updates the button text and emits",
		dropdown.selected == &"a" and dropdown.button_text() == "Alpha" and chosen == [&"a"],
		"selected %s text '%s' chosen %s" % [dropdown.selected, dropdown.button_text(), str(chosen)])
	dropdown.select(&"b", true)
	TestFixtures.check(res, "selecting a disabled key is refused",
		dropdown.selected == &"a" and chosen == [&"a"],
		"selected %s chosen %s" % [dropdown.selected, str(chosen)])
	dropdown.open_popup()
	var row: Button = dropdown.row_for(&"b")
	TestFixtures.check(res, "an invalid row carries its reason as a tooltip",
		row != null and row.tooltip_text == "Locked recipe",
		"row %s tooltip '%s'" % [row, row.tooltip_text if row != null else ""])
	dropdown._on_row_pressed(&"b")
	TestFixtures.check(res, "pressing an invalid row still refuses the pick",
		dropdown.selected == &"a" and chosen == [&"a"],
		"selected %s chosen %s" % [dropdown.selected, str(chosen)])
	var rect: Rect2 = dropdown.toggle.get_global_rect()
	var wanted: Vector2 = dropdown.menu.get_contents_minimum_size()
	var target: Rect2i = dropdown._target_rect(rect, wanted)
	TestFixtures.check(res, "the open popup is right aligned under the button",
		target.position.x + target.size.x == int(rect.end.x) and target.position.y == int(rect.end.y),
		"target %s button rect %s" % [target, rect])
	dropdown.close_popup()
	TestFixtures.check(res, "close_popup hides the menu", not dropdown.popup_open(),
		"popup_open %s" % dropdown.popup_open())
	dropdown.disabled = true
	TestFixtures.check(res, "a disabled dropdown dims and carries a locked tooltip",
		is_equal_approx(dropdown.modulate.a, 0.4) and dropdown.toggle.tooltip_text == "Locked",
		"alpha %.2f tooltip '%s'" % [dropdown.modulate.a, dropdown.toggle.tooltip_text])
	dropdown.open_popup()
	TestFixtures.check(res, "a disabled dropdown refuses to open its popup",
		not dropdown.popup_open(), "popup_open %s" % dropdown.popup_open())
	dropdown.disabled = false
	dropdown.open_popup()
	TestFixtures.check(res, "open_popup opens the menu once enabled again",
		dropdown.popup_open(), "popup_open %s" % dropdown.popup_open())
	dropdown.queue_free()


static func _case_text_entry_dialog(res: Dictionary, host: Node) -> void:
	GuiFrameStack.clear()
	GuiFrameStack.bottom_reserve = 0.0
	var dialog: TextEntryDialog = (load(TEXT_ENTRY_SCENE) as PackedScene).instantiate()
	host.add_child(dialog)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	dialog.open("Enter Name", "", 5)
	TestFixtures.check(res, "open shows the dialog and pushes the frame stack",
		dialog.visible and GuiFrameStack.top() == dialog and dialog.text() == "",
		"visible %s top %s text '%s'" % [dialog.visible, GuiFrameStack.top(), dialog.text()])
	dialog.press_key("A")
	TestFixtures.check(res, "typing a letter while shift is on appends it upper case",
		dialog.text() == "A", "got '%s'" % dialog.text())
	dialog.press_key("Shift")
	dialog.press_key("B")
	TestFixtures.check(res, "shift toggles and stays off until pressed again",
		dialog.text() == "Ab", "got '%s'" % dialog.text())
	dialog.press_key("Space")
	TestFixtures.check(res, "space appends a blank", dialog.text() == "Ab ",
		"got '%s'" % dialog.text())
	dialog.press_key("Del")
	TestFixtures.check(res, "del removes the last character", dialog.text() == "Ab",
		"got '%s'" % dialog.text())
	dialog.press_key("c")
	dialog.press_key("d")
	dialog.press_key("e")
	TestFixtures.check(res, "typing up to max_length fills the field",
		dialog.text() == "Abcde" and dialog.count_label.text == "5 / 5",
		"text '%s' count '%s'" % [dialog.text(), dialog.count_label.text])
	TestFixtures.check(res, "the counter turns red at max_length",
		dialog.count_label.get_theme_color(&"font_color").is_equal_approx(TextEntryDialog.RED),
		"colour %s" % dialog.count_label.get_theme_color(&"font_color"))
	dialog.press_key("f")
	TestFixtures.check(res, "typing past max_length is refused",
		dialog.text() == "Abcde", "got '%s'" % dialog.text())
	for _i: int in 5:
		dialog.press_key("Del")
	TestFixtures.check(res, "done is disabled once the field is empty",
		dialog.text() == "" and dialog.done_button.disabled,
		"text '%s' disabled %s" % [dialog.text(), dialog.done_button.disabled])
	dialog.press_key("x")
	TestFixtures.check(res, "done re-enables once the field holds text",
		not dialog.done_button.disabled, "disabled %s" % dialog.done_button.disabled)
	TestFixtures.check(res, "Done and Cancel are the shared BevelButton scene with the right kinds",
		dialog.done_button is BevelButton and dialog.done_button.kind == &"go"
			and dialog.done_button.text == "Done"
			and dialog.cancel_button is BevelButton and dialog.cancel_button.kind == &"neutral"
			and dialog.cancel_button.text == "Cancel",
		"done kind %s cancel kind %s" % [dialog.done_button.kind, dialog.cancel_button.kind])
	var done_texts: Array[String] = []
	dialog.done.connect(func(t: String) -> void: done_texts.append(t))
	dialog.press_done()
	TestFixtures.check(res, "press_done emits done with the text and closes the dialog",
		done_texts == ["x"] and not dialog.visible and GuiFrameStack.top() != dialog,
		"done %s visible %s top %s" % [str(done_texts), dialog.visible, GuiFrameStack.top()])

	dialog.open("Enter Name", "start", 10)
	var cancels: Array[int] = [0]
	dialog.cancelled.connect(func() -> void: cancels[0] += 1)
	dialog.press_cancel()
	TestFixtures.check(res, "press_cancel emits cancelled and closes the dialog",
		cancels[0] == 1 and not dialog.visible and GuiFrameStack.top() != dialog,
		"cancels %d visible %s top %s" % [cancels[0], dialog.visible, GuiFrameStack.top()])

	dialog.open("Enter Name", "", 10)
	await _push_key(host, _key(KEY_ESCAPE))
	TestFixtures.check(res, "escape reaches the topmost dialog and cancels it",
		cancels[0] == 2 and not dialog.visible, "cancels %d visible %s" % [cancels[0], dialog.visible])

	dialog.open("Enter Name", "y", 10)
	await _push_key(host, _key(KEY_ENTER))
	TestFixtures.check(res, "enter reaches the topmost dialog and finishes it",
		done_texts == ["x", "y"] and not dialog.visible,
		"done %s visible %s" % [str(done_texts), dialog.visible])

	dialog.open("Enter Name", "ab", 10)
	await _push_key(host, _key(KEY_BACKSPACE))
	TestFixtures.check(res, "backspace deletes through the physical keyboard path",
		dialog.text() == "a", "got '%s'" % dialog.text())

	await _push_key(host, _key(KEY_NONE, true, 65))
	TestFixtures.check(res, "a physical letter key appends its raw unicode character",
		dialog.text() == "aA", "got '%s'" % dialog.text())

	dialog.press_cancel()
	var text_before: String = dialog.text()
	await _push_key(host, _key(KEY_A, true, 65))
	TestFixtures.check(res, "a hidden dialog ignores physical keyboard input",
		dialog.text() == text_before and cancels[0] == 3,
		"text '%s' cancels %d" % [dialog.text(), cancels[0]])
	dialog.queue_free()


static func _case_confirm_rich(res: Dictionary, host: Node) -> void:
	GuiFrameStack.clear()
	GuiFrameStack.bottom_reserve = 0.0
	var dlg: ConfirmDialog = (load(CONFIRM_SCENE) as PackedScene).instantiate()
	host.add_child(dlg)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var shown_count: Array[int] = [0]
	var hidden_count: Array[int] = [0]
	dlg.shown.connect(func() -> void: shown_count[0] += 1)
	dlg.dialog_hidden.connect(func() -> void: hidden_count[0] += 1)
	var rich := ConfirmRich.new()
	rich.kicker = "Pay the fine now?"
	rich.crew = [{"name": "Rook", "role": "Leader"}]
	rich.money = [{"label": "Fine", "amount": 250}]
	rich.outcome = "Charges dropped"
	rich.outcome_ok = true
	dlg.ask_rich("Pay Fine", "Settle the outstanding fine.", "Pay 250", rich)
	TestFixtures.check(res, "ask_rich shows the kicker line and fires shown",
		dlg.rich_kicker_text() == "Pay the fine now?" and shown_count[0] == 1,
		"kicker '%s' shown %d" % [dlg.rich_kicker_text(), shown_count[0]])
	TestFixtures.check(res, "ask_rich builds one crew row",
		dlg._crew_box != null and dlg._crew_box.get_child_count() == 1,
		"count %d" % (dlg._crew_box.get_child_count() if dlg._crew_box != null else -1))
	TestFixtures.check(res, "ask_rich builds one money row",
		dlg.money_row_count() == 1, "got %d" % dlg.money_row_count())
	TestFixtures.check(res, "ask_rich builds an outcome box with the outcome text",
		dlg.has_outcome_box() and dlg.outcome_text() == "Charges dropped",
		"has_box %s text '%s'" % [dlg.has_outcome_box(), dlg.outcome_text()])
	var labels: Array[String] = dlg.button_labels()
	TestFixtures.check(res, "ask_rich labels the cta with the caller's full text",
		labels.size() == 2 and labels[0] == "Cancel" and labels[1] == "Pay 250",
		"labels %s" % str(labels))
	var confirmed_flag: Array[bool] = [false]
	dlg.confirmed.connect(func() -> void: confirmed_flag[0] = true)
	dlg.press(1)
	TestFixtures.check(res, "confirming a rich dialog emits confirmed and hidden",
		confirmed_flag[0] and hidden_count[0] == 1 and not dlg.visible,
		"confirmed %s hidden_count %d visible %s" % [confirmed_flag[0], hidden_count[0], dlg.visible])
	dlg.queue_free()


#The core action button scene: the palettes, the shading members and the effect hook.
static func _case_bevel_button(res: Dictionary, host: Node) -> void:
	var made: BevelButton = BevelButton.make("Accept", &"go", Vector2(120.0, 30.0))
	host.add_child(made)
	await host.get_tree().process_frame
	TestFixtures.check(res, "make builds the one core scene with the text and size it was given",
		made.scene_file_path == BevelButton.SCENE_PATH and made.text == "Accept"
		and made.custom_minimum_size == Vector2(120.0, 30.0),
		"scene '%s' text '%s' size %s" % [made.scene_file_path, made.text,
			str(made.custom_minimum_size)])
	var kinds: Array[StringName] = [&"go", &"danger", &"orange", &"blue", &"neutral"]
	var fills: Array[Color] = []
	for name_of: StringName in kinds:
		var pal: Dictionary = BevelButton.palette(name_of)
		var one: Color = pal["fill"]
		fills.append(one)
	TestFixtures.check(res, "the five kinds each carry their own fill",
		fills.size() == 5 and fills[0] == BevelButton.GO_FILL and fills[1] == BevelButton.DANGER_FILL
		and fills[2] == BevelButton.ORANGE_FILL and fills[3] == BevelButton.BLUE_FILL
		and fills[4] == BevelButton.NEUTRAL_FILL, "%s" % [fills])
	var go_pal: Dictionary = BevelButton.palette(&"go")
	TestFixtures.check(res, "a palette carries the fill, the two bevel tones and the label colour",
		go_pal["hi"] == BevelButton.GO_HI and go_pal["lo"] == BevelButton.GO_LO
		and go_pal["text"] == BevelButton.CREAM, "%s" % [go_pal])
	TestFixtures.check(res, "an unknown kind falls back to the blue palette",
		BevelButton.palette(&"nonsense")["fill"] == BevelButton.BLUE_FILL,
		"%s" % [BevelButton.palette(&"nonsense")["fill"]])
	TestFixtures.check(res, "make wrote the kind it was handed into the button",
		made.fill == BevelButton.GO_FILL and made.text_color == BevelButton.CREAM,
		"fill %s text %s" % [made.fill.to_html(false), made.text_color.to_html(false)])
	made.apply_palette(&"danger")
	TestFixtures.check(res, "apply_palette writes all four colours of the named kind",
		made.fill == BevelButton.DANGER_FILL and made.hi == BevelButton.DANGER_HI
		and made.lo == BevelButton.DANGER_LO and made.text_color == BevelButton.CREAM,
		"%s %s %s" % [made.fill.to_html(false), made.hi.to_html(false), made.lo.to_html(false)])
	var own := Color("#123456")
	made.set_colors(own, Color("#224466"), Color("#0a1a2a"), Color("#ffffff"))
	TestFixtures.check(res, "set_colors overrides the palette with the caller's own shading",
		made.fill == own and made.hi == Color("#224466") and made.lo == Color("#0a1a2a")
		and made.text_color == Color("#ffffff"), made.fill.to_html(false))
	TestFixtures.check(res, "hover lightens and press darkens the fill when neither is given",
		made.hover_color() == own.lightened(BevelButton.HOVER_LIFT)
		and made.pressed_color() == own.darkened(BevelButton.PRESS_DROP),
		"%s %s" % [made.hover_color().to_html(false), made.pressed_color().to_html(false)])
	made.hover_fill = Color("#abcdef")
	made.pressed_fill = Color("#013579")
	TestFixtures.check(res, "an explicit hover or pressed fill wins over the derived one",
		made.hover_color() == Color("#abcdef") and made.pressed_color() == Color("#013579"),
		"%s %s" % [made.hover_color().to_html(false), made.pressed_color().to_html(false)])
	TestFixtures.check(res, "an idle button paints its plain fill",
		made.body_color() == own, made.body_color().to_html(false))
	made.disabled = true
	TestFixtures.check(res, "a disabled button keeps its colour and paints it faded",
		is_equal_approx(made.body_color().a, own.a * BevelButton.DISABLED_FILL_ALPHA)
		and is_equal_approx(made.body_color().r, own.r), "%.2f" % made.body_color().a)
	made.disabled = false
	var boxes_empty: bool = true
	var margins_ok: bool = true
	for state: StringName in BEVEL_STATES:
		var box: StyleBox = made.get_theme_stylebox(state)
		if not (box is StyleBoxEmpty):
			boxes_empty = false
		elif not is_equal_approx(box.get_margin(SIDE_LEFT), BevelButton.PAD_X):
			margins_ok = false
	TestFixtures.check(res, "every state of the core button wears an empty box, so _draw is the look",
		boxes_empty and margins_ok, "empty %s margins %s" % [boxes_empty, margins_ok])
	made.effect = ProbeEffect
	var hook: Object = made.effect_node()
	TestFixtures.check(res, "the effect export hangs one child of that script and attaches it",
		hook != null and made.get_child_count() == 1 and int(hook.get("attached")) == 1,
		"children %d attached %s" % [made.get_child_count(),
			str(hook.get("attached")) if hook != null else "none"])
	made.effect = null
	TestFixtures.check(res, "clearing the effect frees the child it hung",
		made.effect_node() == null and made.get_child_count() == 0,
		"children %d" % made.get_child_count())
	made.queue_free()


#The two static painters, run inside a real draw pass.
static func _case_bevel_paint(res: Dictionary, host: Node) -> void:
	var probe := PaintProbe.new()
	probe.size = Vector2(60.0, 24.0)
	probe.custom_minimum_size = Vector2(60.0, 24.0)
	host.add_child(probe)
	await host.get_tree().process_frame
	probe.queue_redraw()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "the body and the bevel painters run inside a draw pass",
		probe.painted > 0 and probe.failed == 0,
		"painted %d failed %d" % [probe.painted, probe.failed])
	probe.queue_free()


#Every dialog button is the core scene, shaded from the kind the dialog asked for.
static func _case_confirm_buttons(res: Dictionary, host: Node) -> void:
	GuiFrameStack.clear()
	GuiFrameStack.bottom_reserve = 0.0
	var dlg: ConfirmDialog = (load(CONFIRM_SCENE) as PackedScene).instantiate()
	host.add_child(dlg)
	await host.get_tree().process_frame
	dlg.ask("Pay Fine", "Settle the outstanding fine.", "Pay", "No",
		ConfirmDialog.Severity.ORANGE, ConfirmDialog.Kind.GO)
	await host.get_tree().process_frame
	var kids: Array[Node] = dlg.button_row.get_children()
	var all_core: bool = kids.size() == 2
	for kid: Node in kids:
		if not (kid is BevelButton):
			all_core = false
	TestFixtures.check(res, "both dialog buttons are the core action button scene",
		all_core, "%d buttons" % kids.size())
	var cancel: BevelButton = kids[0] as BevelButton
	var confirm: BevelButton = kids[1] as BevelButton
	TestFixtures.check(res, "the cancel button wears the neutral shading",
		cancel != null and cancel.fill == BevelButton.NEUTRAL_FILL
		and cancel.custom_minimum_size == ConfirmDialog.BUTTON_SIZE,
		"fill %s" % (cancel.fill.to_html(false) if cancel != null else "none"))
	TestFixtures.check(res, "a go dialog shades its confirm button green",
		confirm != null and confirm.fill == BevelButton.GO_FILL and confirm.text == "Pay",
		"fill %s" % (confirm.fill.to_html(false) if confirm != null else "none"))
	dlg.ask("Break Contract", "This cannot be undone.", "Break", "Keep",
		ConfirmDialog.Severity.RED, ConfirmDialog.Kind.BAD)
	await host.get_tree().process_frame
	var bad: BevelButton = dlg.button_row.get_child(1) as BevelButton
	TestFixtures.check(res, "a bad dialog shades its confirm button red",
		bad != null and bad.fill == BevelButton.DANGER_FILL, "fill %s" % bad.fill.to_html(false))
	TestFixtures.check(res, "the warn kind shades blue and an unknown kind falls back to neutral",
		dlg._shade_of(ConfirmDialog.Kind.WARN) == &"blue" and dlg._shade_of(9) == &"neutral",
		"%s %s" % [dlg._shade_of(ConfirmDialog.Kind.WARN), dlg._shade_of(9)])
	var pad: MarginContainer = dlg.box.get_node("Pad") as MarginContainer
	var sides: Array[String] = ["margin_left", "margin_top", "margin_right", "margin_bottom"]
	var pad_ok: bool = pad != null
	for side: String in sides:
		if pad == null or pad.get_theme_constant(side) != DIALOG_PAD:
			pad_ok = false
	TestFixtures.check(res, "the dialog box holds its content 14 px clear on all four sides",
		pad_ok, "%d" % (pad.get_theme_constant("margin_left") if pad != null else -1))
	var pressed: Array[int] = []
	dlg.confirmed.connect(func() -> void: pressed.append(1))
	dlg.press(1)
	TestFixtures.check(res, "a core dialog button still reports its press",
		pressed == [1], "%s" % [pressed])
	dlg.queue_free()


static func _case_confirm_dialog_legacy(res: Dictionary, host: Node) -> void:
	var ok: bool = await GuiFrameTests.run(host)
	TestFixtures.check(res, "the existing gui frame suite still passes with the rich extension in place",
		ok, "GuiFrameTests.run returned %s" % ok)
