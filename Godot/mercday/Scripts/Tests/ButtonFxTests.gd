class_name ButtonFxTests

#ButtonFx catalog and the rig every BevelButton owns: presets, the KIND resolver, each click, hover and stay
#animation, layer stacking and the fx picks the scenes write. Run with button-fx-tests harness flag.

const ENTRY_COUNTS: Array[int] = [7, 7, 3, 7, 3, 3]
const PRESET_ROWS: Dictionary = {
	&"go": [ButtonFx.ClickMove.POP, ButtonFx.ClickShade.FLASH, ButtonFx.HoverMove.LIFT, ButtonFx.HoverShade.GLOW,
		ButtonFx.StayMove.PULSE, ButtonFx.StayShade.SHIMMER,
		ButtonFx.HoverMove.NONE, ButtonFx.HoverShade.RING],
	&"danger": [ButtonFx.ClickMove.RATTLE, ButtonFx.ClickShade.INK, ButtonFx.HoverMove.RAISE,
		ButtonFx.HoverShade.DARKEN, ButtonFx.StayMove.NONE, ButtonFx.StayShade.NONE,
		ButtonFx.HoverMove.NONE, ButtonFx.HoverShade.RING],
	&"orange": [ButtonFx.ClickMove.BOUNCE, ButtonFx.ClickShade.HALO, ButtonFx.HoverMove.TILT,
		ButtonFx.HoverShade.TINT, ButtonFx.StayMove.FLOAT, ButtonFx.StayShade.BEACON,
		ButtonFx.HoverMove.NONE, ButtonFx.HoverShade.RING],
	&"blue": [ButtonFx.ClickMove.DROP, ButtonFx.ClickShade.INVERT, ButtonFx.HoverMove.LIFT,
		ButtonFx.HoverShade.LIGHTEN, ButtonFx.StayMove.NONE, ButtonFx.StayShade.NONE,
		ButtonFx.HoverMove.NONE, ButtonFx.HoverShade.RING],
	&"neutral": [ButtonFx.ClickMove.SHRINK, ButtonFx.ClickShade.FADE, ButtonFx.HoverMove.NONE,
		ButtonFx.HoverShade.LIGHTEN, ButtonFx.StayMove.NONE, ButtonFx.StayShade.NONE,
		ButtonFx.HoverMove.NONE, ButtonFx.HoverShade.RING],
}
#The one read each animation moves off its resting value.
const READS: Dictionary = {
	"SHRINK": "scale", "SQUASH": "scale", "POP": "scale", "LIFT": "scale", "PULSE": "scale",
	"DROP": "position", "RATTLE": "position", "BOUNCE": "position", "RAISE": "position", "FLOAT": "position",
	"ROCK": "rotation", "TILT": "rotation", "SWAY": "rotation",
	"FLASH": "modulate", "FADE": "modulate", "LIGHTEN": "modulate", "SPARK": "modulate", "DARKEN": "modulate",
	"BREATHE": "modulate",
	"INVERT": "edges", "BLAZE": "edges", "GLOW": "edges", "SHIMMER": "edges",
	"INK": "body", "TINT": "body", "LABEL": "label",
	"HALO": "ring", "RING": "ring", "PING": "ring", "BEACON": "ring",
}
#Eight picks per node in SLOTS order: -1 follows the kind preset and 0 turns the slot off.
const SCENES: Dictionary = {
	"res://Scenes/GUI/Contracts/ActionBar.tscn": {"Pad/Row/Buttons/Clear": [1, 6, 2, -1, -1, -1, -1, -1]},
	"res://Scenes/GUI/Contracts/DecisionButtons.tscn": {"Accept": [2, 5, -1, 2, 1, 2, -1, -1],
		"Reject": [6, 3, 3, 6, -1, -1, -1, -1], "CancelDispatch": [5, 7, 2, 6, -1, -1, -1, -1]},
	"res://Scenes/GUI/Mercs/CoachingBox.tscn": {"Coach": [7, 4, -1, 5, 3, -1, -1, -1]},
	"res://Scenes/GUI/Notifications/NotificationPanel.tscn": {
		"Pad/Col/TabRow/UnreadTab": [1, 6, 0, -1, -1, -1, -1, -1],
		"Pad/Col/TabRow/ReadTab": [1, 6, 0, -1, -1, -1, -1, -1],
		"Pad/Col/ToolWrap/ToolRow/SortBtn": [-1, 3, 0, 3, -1, -1, -1, -1],
		"Pad/Col/ToolWrap/ToolRow/FilterBtn": [-1, 3, 0, 3, -1, -1, -1, -1]},
	"res://Scenes/GUI/Results/ContractResults.tscn": {"Center/Panel/Body/Foot/Continue": [3, 1, -1, 2, 2, 3, -1, -1]},
	"res://Scenes/GUI/Shared/MercPicker.tscn": {"Box/Pad/Rows/Remove": [5, 3, 2, 6, -1, -1, -1, -1]},
	"res://Scenes/GUI/Shared/ModalDialog.tscn": {"Box/Pad/Rows/Buttons/Cancel": [-1, -1, -1, 6, -1, -1, -1, -1],
		"Box/Pad/Rows/Buttons/Confirm": [-1, -1, -1, 4, -1, -1, -1, -1]},
	"res://Scenes/GUI/Finance/Invest/InvestTradePanel.tscn": {
		"Col/Switch/Row/SwapButton": [-1, -1, 0, 7, -1, -1, -1, -1],
		"Col/ConfirmButton": [-1, -1, 0, 7, -1, -1, -1, -1]},
	"res://Scenes/GUI/Finance/Invest/InvestTradeConfirm.tscn": {
		"Box/Pad/Rows/Buttons/Cancel": [-1, -1, 0, 7, -1, -1, -1, -1],
		"Box/Pad/Rows/Buttons/Confirm": [-1, -1, 0, 7, -1, -1, -1, -1]},
	"res://Scenes/GUI/Finance/Invest/InvestQuantityField.tscn": {"Minus": [-1, -1, 0, 7, -1, -1, -1, -1],
		"Plus": [-1, -1, 0, 7, -1, -1, -1, -1], "MaxButton": [-1, -1, 0, 7, -1, -1, -1, -1]},
	"res://Scenes/GUI/Finance/Invest/InvestRangeButton.tscn": {".": [1, 1, 0, 0, 0, 0, -1, -1]},
}


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_catalog(res)
	_case_presets(res)
	await _case_fx_value(res, host)
	for slot: int in _enums().size():
		await _case_slot(res, host, slot)
	await _case_stacking(res, host)
	await _case_release(res, host)
	await _case_resort(res, host)
	await _case_modulate_base(res, host)
	await _case_modulate_channel(res, host)
	await _case_drop(res, host)
	await _case_active(res, host)
	await _case_raise(res, host)
	await _case_hit(res, host)
	await _case_sync(res, host)
	await _case_look(res, host)
	await _case_wiring(res, host)
	await _case_lender_card(res, host)
	_case_scenes(res)
	await _case_blends(res, host)
	return TestFixtures.summarize(res, "BUTTON FX")


static func _button(host: Node, kind: StringName) -> BevelButton:
	var button: BevelButton = BevelButton.make("Fx", kind, Vector2(120.0, 36.0))
	host.add_child(button)
	await TestFixtures.frames(host, 2)
	return button


static func _enums() -> Array[Dictionary]:
	return [ButtonFx.ClickMove, ButtonFx.ClickShade, ButtonFx.HoverMove, ButtonFx.HoverShade, ButtonFx.StayMove,
		ButtonFx.StayShade]


static func _row(picks: Dictionary) -> Array[int]:
	var row: Array[int] = []
	for slot: StringName in ButtonFx.SLOTS:
		row.append(picks.get(slot, ButtonFx.KIND))
	return row


static func _picks(button: BevelButton, resolve: bool) -> Array[int]:
	var row: Array[int] = []
	for slot: StringName in ButtonFx.SLOTS:
		row.append(button.fx_value(slot) if resolve else int(button.get(slot)))
	return row


static func _start(rig: ButtonFxRig, slot: int, value: int) -> void:
	var picks: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
	picks[slot] = value
	if slot < 2:
		rig.click(picks[0], picks[1])
	elif slot < 6:
		rig.hover_in(picks[2], picks[3], picks[4], picks[5])
	else:
		rig.hover_in(picks[6], picks[7], 0, 0)


static func _read(button: BevelButton, read: String, base: Vector2) -> Variant:
	match read:
		"scale":
			return button.scale
		"position":
			return button.position - base
		"rotation":
			return button.rotation_degrees
		"modulate":
			return button.modulate
		"body":
			return button._fx.body(GuiColors.BLUE)
		"edges":
			return button._fx.edges(GuiColors.BLUE_HI, GuiColors.BLUE_LO)
		"label":
			return button._fx.label(GuiColors.CREAM)
	return button._fx.ring().a


static func _changed(button: BevelButton, base: Vector2) -> Array[String]:
	var rest: Dictionary = {"scale": Vector2.ONE, "position": Vector2.ZERO, "rotation": 0.0, "modulate": Color.WHITE,
		"body": GuiColors.BLUE, "edges": PackedColorArray([GuiColors.BLUE_HI, GuiColors.BLUE_LO]),
		"label": GuiColors.CREAM, "ring": 0.0}
	var moved: Array[String] = []
	for read: String in rest:
		if not _near(_read(button, read, base), rest[read]):
			moved.append(read)
	return moved


static func _near(got: Variant, want: Variant) -> bool:
	if typeof(got) != typeof(want):
		return false
	if got is float:
		return is_equal_approx(got, want)
	if got is PackedColorArray:
		var a: PackedColorArray = got
		var b: PackedColorArray = want
		if a.size() != b.size():
			return false
		for i: int in a.size():
			if not a[i].is_equal_approx(b[i]):
				return false
		return true
	return got.is_equal_approx(want)


static func _held() -> Dictionary:
	return {"LIFT": Vector2(1.04, 1.04), "RAISE": Vector2(0.0, -2.0), "TILT": 1.5,
		"LIGHTEN": Color(1.15, 1.15, 1.15, 1.0), "DARKEN": Color(0.85, 0.85, 0.85, 1.0), "RING": 0.8,
		"GLOW": PackedColorArray([GuiColors.BLUE_HI.lerp(GuiColors.CREAM, 0.6),
			GuiColors.BLUE_LO.lerp(GuiColors.CREAM, 0.6)]),
		"TINT": GuiColors.BLUE.lerp(GuiColors.CREAM, 0.35)}


static func _case_catalog(res: Dictionary) -> void:
	var counts: Array[int] = []
	for table: Dictionary in _enums():
		var animated: int = 0
		for value: int in table.values():
			if value > 0:
				animated += 1
		counts.append(animated)
	TestFixtures.check(res, "each slot enum holds its count of animations",
		counts == ENTRY_COUNTS and ButtonFx.SLOTS.size() == 8,
		"counts %s want %s, slots %d" % [counts, ENTRY_COUNTS, ButtonFx.SLOTS.size()])


static func _case_presets(res: Dictionary) -> void:
	var unknown: Array[int] = _row(ButtonFx.preset(&"nothing"))
	for kind: StringName in PRESET_ROWS:
		var got: Array[int] = _row(ButtonFx.preset(kind))
		var want: Array = PRESET_ROWS[kind]
		var label: String = "the %s preset holds its eight picks" % kind
		if kind == &"blue":
			label += " and an unknown kind falls back to it"
		TestFixtures.check(res, label,
			got == want and ButtonFx.preset(kind).size() == 8 and (kind != &"blue" or unknown == want),
			"got %s want %s, an unknown kind gets %s" % [got, want, unknown])


static func _case_fx_value(res: Dictionary, host: Node) -> void:
	var button: BevelButton = await _button(host, &"go")
	var go_row: Array[int] = _row(ButtonFx.preset(&"go"))
	var plain: Array[int] = _picks(button, true)
	button.click_move = ButtonFx.ClickMove.ROCK
	button.stay_move = ButtonFx.StayMove.NONE
	var picked: Array[int] = _picks(button, true)
	var want: Array[int] = _row(ButtonFx.preset(&"go"))
	want[0] = ButtonFx.ClickMove.ROCK
	want[4] = ButtonFx.StayMove.NONE
	TestFixtures.check(res, "KIND follows the go preset and an explicit pick or NONE overrides it",
		plain == go_row and picked == want,
		"defaults %s want %s, with ROCK and NONE %s want %s" % [plain, go_row, picked, want])
	button.queue_free()


#Plays every animation of one slot on a fresh button: a click or a one-shot hover runs out by itself,
#a held hover keeps its target until the release and a stay still loops a second and a half later.
static func _case_slot(res: Dictionary, host: Node, slot: int) -> void:
	var table: Dictionary = _enums()[slot]
	var held: Dictionary = _held()
	var slot_name: String = String(ButtonFx.SLOTS[slot]).replace("_", " ")
	for value: int in table.values():
		if value <= 0:
			continue
		var entry: String = str(table.find_key(value))
		var read: String = READS[entry]
		var once: bool = slot < 4 and not held.has(entry)
		var button: BevelButton = await _button(host, &"blue")
		var base: Vector2 = button.position
		_start(button._fx, slot, value)
		var label: String = "%s %s plays once and settles back to rest" % [slot_name, entry]
		var passed: bool = false
		var seen: String = ""
		if once:
			await TestFixtures.frames(host, 2)
			var playing: bool = button._fx.busy()
			var mid: Array[String] = _changed(button, base)
			passed = playing and mid == [read]
			seen = "busy %s off rest %s want [%s]" % [playing, mid, read]
		elif held.has(entry):
			label = "%s %s holds its target until the release" % [slot_name, entry]
			await host.get_tree().create_timer(0.25).timeout
			var got: Variant = _read(button, read, base)
			passed = _near(got, held[entry])
			seen = "%s held %s want %s" % [read, got, held[entry]]
		else:
			label = "%s %s keeps looping until the release" % [slot_name, entry]
			await host.get_tree().create_timer(0.3).timeout
			var early: Array[String] = _changed(button, base)
			await host.get_tree().create_timer(1.5).timeout
			var looping: bool = button._fx.busy()
			passed = early == [read] and looping
			seen = "at 0.3s off rest %s want [%s], busy at 1.8s %s" % [early, read, looping]
		if once:
			await host.get_tree().create_timer(0.6 if entry == "PING" else 0.45).timeout
		else:
			button._fx.hover_out()
			await host.get_tree().create_timer(0.1).timeout
		var after: Array[String] = _changed(button, base)
		var idle: bool = not button._fx.busy()
		TestFixtures.check(res, label, passed and after.is_empty() and idle,
			"%s; once over off rest %s idle %s" % [seen, after, idle])
		button.queue_free()


static func _case_stacking(res: Dictionary, host: Node) -> void:
	var button: BevelButton = await _button(host, &"blue")
	button._fx.hover_in(ButtonFx.HoverMove.LIFT, ButtonFx.HoverShade.LIGHTEN, 0, 0)
	await host.get_tree().create_timer(0.2).timeout
	button._fx.click(ButtonFx.ClickMove.POP, ButtonFx.ClickShade.FLASH)
	await TestFixtures.frames(host, 2)
	var peak: Vector2 = button.scale
	var flash: float = button.modulate.r
	await host.get_tree().create_timer(0.45).timeout
	var kept: Vector2 = button.scale
	var lit: float = button.modulate.r
	button._fx.hover_out()
	await host.get_tree().create_timer(0.1).timeout
	TestFixtures.check(res, "a click stacks on a held hover and the hover outlasts the click",
		peak.x > 1.04 and flash > 1.15 and kept.is_equal_approx(Vector2(1.04, 1.04)) and is_equal_approx(lit, 1.15)
		and button.scale.is_equal_approx(Vector2.ONE) and button.modulate.is_equal_approx(Color.WHITE),
		"during the click scale %s red %s, after it %s red %s, after the release %s %s"
		% [peak, flash, kept, lit, button.scale, button.modulate])
	button.queue_free()


static func _case_release(res: Dictionary, host: Node) -> void:
	var button: BevelButton = await _button(host, &"blue")
	button._fx.hover_in(ButtonFx.HoverMove.LIFT, 0, 0, 0)
	await host.get_tree().create_timer(0.25).timeout
	button._fx.hover_out()
	await host.get_tree().create_timer(ButtonFx.EXIT * 2.0).timeout
	TestFixtures.check(res, "the release is at least three times quicker than the ease in and ends in twice its length",
		ButtonFx.EXIT * 3.0 <= ButtonFx.ENTER and button.scale.is_equal_approx(Vector2.ONE)
		and not button._fx.busy(),
		"EXIT %s ENTER %s, %ss after the release scale %s busy %s"
		% [ButtonFx.EXIT, ButtonFx.ENTER, ButtonFx.EXIT * 2.0, button.scale, button._fx.busy()])
	button.queue_free()


static func _case_resort(res: Dictionary, host: Node) -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 0)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 20.0)
	box.add_child(spacer)
	var button: BevelButton = BevelButton.make("Fx", &"blue", Vector2(120.0, 36.0))
	box.add_child(button)
	host.add_child(box)
	await TestFixtures.frames(host, 2)
	button._fx.hover_in(ButtonFx.HoverMove.RAISE, 0, 0, 0)
	await host.get_tree().create_timer(0.25).timeout
	var raised: Vector2 = button.position
	spacer.custom_minimum_size = Vector2(0.0, 60.0)
	await host.get_tree().create_timer(0.1).timeout
	var resorted: Vector2 = button.position
	button._fx.hover_out()
	await host.get_tree().create_timer(0.1).timeout
	TestFixtures.check(res, "a container sort under a held raise moves the base and keeps the raise",
		raised.is_equal_approx(Vector2(0.0, 18.0)) and resorted.is_equal_approx(Vector2(0.0, 58.0))
		and button.position.is_equal_approx(Vector2(0.0, 60.0)),
		"raised %s want (0, 18), after the sort %s want (0, 58), at rest %s want (0, 60)"
		% [raised, resorted, button.position])
	box.queue_free()


static func _case_modulate_base(res: Dictionary, host: Node) -> void:
	var button: BevelButton = await _button(host, &"blue")
	var half: Color = Color(1.0, 1.0, 1.0, 0.5)
	button.modulate = half
	button._fx.hover_in(0, ButtonFx.HoverShade.LIGHTEN, 0, 0)
	await host.get_tree().create_timer(0.25).timeout
	var lit: Color = button.modulate
	button._fx.hover_out()
	await host.get_tree().create_timer(0.1).timeout
	TestFixtures.check(res, "lighten scales the modulate the caller set and gives it back at rest",
		lit.is_equal_approx(Color(1.15, 1.15, 1.15, 0.5)) and button.modulate.is_equal_approx(half),
		"lit %s want (1.15, 1.15, 1.15, 0.5), at rest %s want %s" % [lit, button.modulate, half])
	button.queue_free()


static func _case_modulate_channel(res: Dictionary, host: Node) -> void:
	var button: BevelButton = await _button(host, &"blue")
	button._fx.hover_in(0, ButtonFx.HoverShade.LIGHTEN, 0, 0)
	await host.get_tree().create_timer(0.2).timeout
	button.modulate.a = 0.5
	await TestFixtures.frames(host, 2)
	var lit: Color = button.modulate
	button._fx.hover_out()
	await host.get_tree().create_timer(0.1).timeout
	var half: Color = Color(1.0, 1.0, 1.0, 0.5)
	TestFixtures.check(res, "an alpha write under a held lighten keeps the lit base clean and comes back at rest",
		lit.is_equal_approx(Color(1.15, 1.15, 1.15, 0.5)) and button.modulate.is_equal_approx(half),
		"lit %s want (1.15, 1.15, 1.15, 0.5), at rest %s want %s" % [lit, button.modulate, half])
	button.queue_free()


static func _case_drop(res: Dictionary, host: Node) -> void:
	var button: BevelButton = await _button(host, &"blue")
	button.disabled = true
	button.mouse_entered.emit()
	await host.get_tree().process_frame
	var passed: bool = not button._fx.busy()
	var seen: Array[String] = ["disabled hover busy %s" % button._fx.busy()]
	for hidden: bool in [false, true]:
		button.disabled = false
		button._fx.hover_in(ButtonFx.HoverMove.LIFT, 0, 0, 0)
		await host.get_tree().create_timer(0.2).timeout
		var lifted: Vector2 = button.scale
		button.disabled = not hidden
		button.visible = not hidden
		await TestFixtures.frames(host, 2)
		passed = passed and lifted.is_equal_approx(Vector2(1.04, 1.04)) and button.scale.is_equal_approx(Vector2.ONE)
		passed = passed and not button._fx.busy()
		seen.append("%s scale %s then %s busy %s" % ["hidden" if hidden else "disabled", lifted, button.scale,
			button._fx.busy()])
	TestFixtures.check(res, "a disabled button skips the hover and disabling or hiding one drops its animations",
		passed, ", ".join(seen))
	button.queue_free()


static func _case_active(res: Dictionary, host: Node) -> void:
	var solid: BevelButton = await _button(host, &"blue")
	solid.disabled = true
	solid.disabled_solid = true
	solid.mouse_entered.emit()
	await host.get_tree().create_timer(0.25).timeout
	var ring: float = solid._fx.ring().a
	var grown: Vector2 = solid.scale
	var playing: bool = solid._fx.busy()
	solid.mouse_exited.emit()
	await host.get_tree().create_timer(0.1).timeout
	TestFixtures.check(res, "a solid disabled button rings on hover without moving and settles on the release",
		is_equal_approx(ring, 0.8) and grown.is_equal_approx(Vector2.ONE) and playing
		and is_zero_approx(solid._fx.ring().a) and not solid._fx.busy() and solid.z_index == 0,
		"ring %s scale %s busy %s, after the release ring %s busy %s z %d"
		% [ring, grown, playing, solid._fx.ring().a, solid._fx.busy(), solid.z_index])
	solid.queue_free()
	var toggle: BevelButton = await _button(host, &"blue")
	toggle.toggle_mode = true
	toggle.button_pressed = true
	#is_hovered follows the notification and the fx follows the signal, so the test sends both as a real hover does.
	toggle.notification(Control.NOTIFICATION_MOUSE_ENTER)
	toggle.mouse_entered.emit()
	await host.get_tree().create_timer(0.25).timeout
	var pressed_ring: float = toggle._fx.ring().a
	var pressed_scale: Vector2 = toggle.scale
	toggle.button_pressed = false
	await host.get_tree().create_timer(0.25).timeout
	var lifted: Vector2 = toggle.scale
	var lifted_ring: float = toggle._fx.ring().a
	toggle.notification(Control.NOTIFICATION_MOUSE_EXIT)
	toggle.mouse_exited.emit()
	await host.get_tree().create_timer(0.1).timeout
	TestFixtures.check(res, "a pressed toggle rings on hover and lifts once it is released under the cursor",
		is_equal_approx(pressed_ring, 0.8) and pressed_scale.is_equal_approx(Vector2.ONE)
		and lifted.is_equal_approx(Vector2(1.04, 1.04)) and is_zero_approx(lifted_ring)
		and toggle.scale.is_equal_approx(Vector2.ONE) and not toggle._fx.busy(),
		"pressed ring %s scale %s, released ring %s scale %s, after the exit scale %s busy %s"
		% [pressed_ring, pressed_scale, lifted_ring, lifted, toggle.scale, toggle._fx.busy()])
	toggle.queue_free()
	var faded: BevelButton = await _button(host, &"blue")
	faded.disabled = true
	faded.disabled_solid = false
	faded.mouse_entered.emit()
	await TestFixtures.frames(host, 2)
	TestFixtures.check(res, "a disabled button that is not solid plays no hover", not faded._fx.busy(),
		"busy %s" % faded._fx.busy())
	faded.queue_free()


static func _case_raise(res: Dictionary, host: Node) -> void:
	var passed: bool = true
	var seen: Array[String] = []
	#Resting z, click move, click shade, settled z; a settled z unlike the resting one is written mid move.
	for spec: Array in [[2, ButtonFx.ClickMove.POP, 0, 5], [0, ButtonFx.ClickMove.POP, 0, 0],
			[2, ButtonFx.ClickMove.NONE, ButtonFx.ClickShade.FLASH, 2]]:
		var rest: int = spec[0]
		var settled: int = spec[3]
		var lift: int = 0 if spec[1] == ButtonFx.ClickMove.NONE else 1
		var button: BevelButton = await _button(host, &"blue")
		button.z_index = rest
		button._fx.click(spec[1], spec[2])
		await TestFixtures.frames(host, 2)
		var during: int = button.z_index
		if settled != rest:
			button.z_index = settled
		await host.get_tree().create_timer(0.45).timeout
		passed = passed and during == rest + lift and button.z_index == settled and not button._fx.busy()
		seen.append("z %d move %d: %d playing, %d settled, busy %s" % [rest, spec[1], during, button.z_index,
			button._fx.busy()])
		button.queue_free()
	TestFixtures.check(res,
		"a button raises its z_index by one only while a move holds it off rest and keeps a z written meanwhile",
		passed, ", ".join(seen))


#The parent point mapped into the button: whether _has_point takes it and whether the plain local rect does.
static func _hits(button: BevelButton, parent_point: Vector2) -> Array[bool]:
	var local: Vector2 = button.get_transform().affine_inverse() * parent_point
	return [button._has_point(local), Rect2(Vector2.ZERO, button.size).has_point(local)]


static func _case_hit(res: Dictionary, host: Node) -> void:
	var shrunk: BevelButton = await _button(host, &"blue")
	var rest: Rect2 = Rect2(shrunk.position, shrunk.size)
	shrunk._fx.click(ButtonFx.ClickMove.SHRINK, 0)
	#SHRINK is mid rise here, well under the 59/60 scale that puts the edge point outside the plain rect.
	await host.get_tree().create_timer(0.04).timeout
	var squeeze: Vector2 = shrunk.scale
	var edge: Array[bool] = _hits(shrunk, rest.position + Vector2(1.0, rest.size.y / 2.0))
	var outside: Array[bool] = _hits(shrunk, rest.position + Vector2(-1.0, rest.size.y / 2.0))
	shrunk.queue_free()
	var raised: BevelButton = await _button(host, &"blue")
	rest = Rect2(raised.position, raised.size)
	raised._fx.hover_in(ButtonFx.HoverMove.RAISE, 0, 0, 0)
	await host.get_tree().create_timer(0.2).timeout
	var foot: Array[bool] = _hits(raised, rest.position + Vector2(rest.size.x / 2.0, rest.size.y - 1.0))
	raised._fx.hover_out()
	await host.get_tree().create_timer(0.1).timeout
	var settled: Array[bool] = [raised._fx.is_processing(), raised._has_point(Vector2(1.0, 18.0)),
		raised._has_point(Vector2(-1.0, 18.0))]
	TestFixtures.check(res, "a moving button keeps its resting hit rect and the plain rect is back once it settles",
		edge == [true, false] and not outside[0] and foot == [true, false] and settled == [false, true, false],
		"shrunk to %s edge %s and outside %s, raised foot %s, settled processing and hits %s"
		% [squeeze, edge, outside, foot, settled])
	raised.queue_free()


static func _case_sync(res: Dictionary, host: Node) -> void:
	var button: BevelButton = await _button(host, &"blue")
	var base: Vector2 = button.position
	button.disabled = true
	button.notification(Control.NOTIFICATION_MOUSE_ENTER)
	button.mouse_entered.emit()
	await TestFixtures.frames(host, 2)
	var blocked: bool = button._fx.busy()
	button.disabled = false
	await host.get_tree().create_timer(0.25).timeout
	var grown: Vector2 = button.scale
	var playing: bool = button._fx.busy()
	button.notification(Control.NOTIFICATION_MOUSE_EXIT)
	button.mouse_exited.emit()
	await host.get_tree().create_timer(0.1).timeout
	var after: Array[String] = _changed(button, base)
	TestFixtures.check(res, "a button enabled under a resting cursor starts its hover and the exit releases it",
		not blocked and grown.is_equal_approx(Vector2(1.04, 1.04)) and playing and after.is_empty()
		and not button._fx.busy(),
		"busy while disabled %s, enabled scale %s busy %s, after the exit off rest %s busy %s"
		% [blocked, grown, playing, after, button._fx.busy()])
	button.queue_free()


static func _case_look(res: Dictionary, host: Node) -> void:
	var lit: BevelButton = await _button(host, &"blue")
	lit.toggle_mode = true
	lit.active_kind = &"orange"
	lit.button_pressed = true
	var lit_body: Color = lit.body_color()
	var lit_label: Color = lit._label_color()
	lit.notification(Control.NOTIFICATION_MOUSE_ENTER)
	var lit_hover: Color = lit.body_color()
	lit.queue_free()
	var pushed: BevelButton = await _button(host, &"blue")
	pushed.toggle_mode = true
	pushed.button_pressed = true
	pushed.notification(Control.NOTIFICATION_MOUSE_ENTER)
	var held: bool = pushed.body_color() == pushed.pressed_color()
	pushed.queue_free()
	var plain: BevelButton = await _button(host, &"blue")
	plain.notification(Control.NOTIFICATION_MOUSE_ENTER)
	var shaded: Color = plain.body_color()
	plain.hover_shade = ButtonFx.HoverShade.NONE
	var lifted: Color = plain.body_color()
	TestFixtures.check(res, "an active button keeps its look under the cursor and the lift paints only with no shade",
		lit_body == GuiColors.ORANGE and lit_label == GuiColors.INK and lit_hover == GuiColors.ORANGE and held
		and shaded == plain.fill and lifted == plain.hover_color() and lifted != plain.fill,
		"active_kind body %s label %s hovered %s, pressed toggle hovered at its pressed colour %s, plain %s then %s"
		% [lit_body, lit_label, lit_hover, held, shaded, lifted])
	plain.queue_free()


static func _case_wiring(res: Dictionary, host: Node) -> void:
	var button: BevelButton = await _button(host, &"blue")
	var inner: Node = button.get_child(0, true) if button.get_child_count(true) > 0 else null
	var owned: bool = button.get_child_count() == 0 and button.get_child_count(true) == 1 and inner == button._fx
	button.button_down.emit()
	await TestFixtures.frames(host, 2)
	var clicked: bool = button._fx.busy()
	button.mouse_entered.emit()
	await host.get_tree().create_timer(0.25).timeout
	var lifted: Vector2 = button.scale
	button.mouse_exited.emit()
	await host.get_tree().create_timer(0.1).timeout
	TestFixtures.check(res, "the rig is the one internal child and the button signals drive it",
		owned and inner is ButtonFxRig and clicked and lifted.is_equal_approx(Vector2(1.04, 1.04))
		and button.scale.is_equal_approx(Vector2.ONE),
		"children %d internal %d, busy after button_down %s, scale after mouse_entered %s, after mouse_exited %s"
		% [button.get_child_count(), button.get_child_count(true), clicked, lifted, button.scale])
	button.queue_free()


static func _case_lender_card(res: Dictionary, host: Node) -> void:
	var card: LenderCard = LenderCard.new()
	host.add_child(card)
	await host.get_tree().process_frame
	var got: Array[int] = [card.fx_value(&"click_shade"), card.fx_value(&"hover_move"), card.fx_value(&"click_move")]
	var want: Array[int] = [ButtonFx.ClickShade.INK, ButtonFx.HoverMove.RAISE, ButtonFx.ClickMove.DROP]
	TestFixtures.check(res, "a lender card inks on click and rises on hover over the blue preset", got == want,
		"click_shade, hover_move, click_move %s want %s" % [got, want])
	card.queue_free()


static func _case_scenes(res: Dictionary) -> void:
	for path: String in SCENES:
		var nodes: Dictionary = SCENES[path]
		var root: Node = (load(path) as PackedScene).instantiate()
		var miss: String = ""
		for node_path: String in nodes:
			var node: Node = root.get_node_or_null(NodePath(node_path))
			if not (node is BevelButton):
				miss = "%s is not a BevelButton" % node_path
			elif _picks(node as BevelButton, false) != nodes[node_path]:
				miss = "%s holds %s want %s" % [node_path, _picks(node as BevelButton, false), nodes[node_path]]
			if miss != "":
				break
		TestFixtures.check(res, "%s carries its fx picks" % path.get_file().get_basename(), miss == "",
			miss if miss != "" else "%d nodes match" % nodes.size())
		root.free()


static func _case_blends(res: Dictionary, host: Node) -> void:
	var button: BevelButton = await _button(host, &"blue")
	var layer: ButtonFx.Layer = button._fx._hover
	layer.body_mix = 0.5
	layer.body_to = GuiColors.INK
	layer.invert = 1.0
	layer.label_mix = 1.0
	layer.ring_alpha = 0.3
	var body: Color = button._fx.body(GuiColors.BLUE)
	var edges: PackedColorArray = button._fx.edges(GuiColors.BLUE_HI, GuiColors.BLUE_LO)
	var label: Color = button._fx.label(GuiColors.CREAM)
	var ring: Color = button._fx.ring()
	layer.reset()
	TestFixtures.check(res, "the colour blends reach their targets and reset clears the layer",
		body.is_equal_approx(GuiColors.BLUE.lerp(GuiColors.INK, 0.5))
		and _near(edges, PackedColorArray([GuiColors.BLUE_LO, GuiColors.BLUE_HI]))
		and label.is_equal_approx(GuiColors.SKY) and is_equal_approx(ring.a, 0.3) and layer.is_identity(),
		"body %s edges %s label %s ring alpha %s, at rest after reset %s"
		% [body, edges, label, ring.a, layer.is_identity()])
	button.queue_free()
