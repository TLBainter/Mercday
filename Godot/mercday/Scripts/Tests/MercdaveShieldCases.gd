class_name MercdaveShieldCases

#MercdaveUiTests check 17 (cards 711 and 712): the shield of an open card swallows hovers and clicks outside it,
#freezes the other markers, takes the first Escape and the focus, and the card aims the pointer at its first button.

const PROBE: String = "res://mercdave_probe_shield.tscn"
const MENU_PATH: NodePath = ^"Root/MainMenuToggle"
const SPOTS: Array[Vector2] = [Vector2(40, 200), Vector2(1100, 200), Vector2(40, 480), Vector2(1100, 480)]
const OFF_POINT: Vector2 = Vector2(5, 5)
const NARROW: float = 200.0


static func run(res: Dictionary, host: Node) -> void:
	var hud: GameHUD = await MercdaveScopeCases.spawn(host)
	var layer: MercdaveLayer = MercdaveScopeCases.layer_of(hud)
	var hits: Array[int] = [0]
	var probe: Button = Button.new()
	probe.name = "ShieldProbe"
	probe.custom_minimum_size = Vector2(100, 40)
	probe.size = Vector2(100, 40)
	probe.pressed.connect(func() -> void: hits[0] += 1)
	hud.get_node("Root").add_child(probe)
	await MercdaveScopeCases.settle(host)
	await _case_cover(res, host, layer, probe)
	await _case_click(res, host, layer, probe, hits)
	await _case_focus(res, host, layer, probe)
	probe.queue_free()
	var win: SubWindow = hud.popup()
	var content: Control = win.open(MercdaveScopeCases.probe(PROBE)) as Control
	var ids: Array[StringName] = MercdaveScopeCases.fresh_ids(2)
	var boxes: Array[Control] = [MercdaveScopeCases.target(content, ids[0], Rect2(40, 40, 120, 40)),
		MercdaveScopeCases.target(content, ids[1], Rect2(40, 120, 120, 40))]
	Mercdave.reset_for_tests()
	await MercdaveScopeCases.settle(host)
	await _case_frozen(res, host, layer, ids)
	await _case_aim(res, host, layer, win, ids)
	await _case_none(res, host, layer, boxes)
	await _case_escape(res, host, hud, content)
	hud.queue_free()
	await TestFixtures.frames(host, 2)


#Check 1, and parks the probe at a spot clear of the HUD card and the markers.
static func _case_cover(res: Dictionary, host: Node, layer: MercdaveLayer, probe: Control) -> void:
	var shield: HintShield = layer.shield
	var idle: bool = not shield.visible and shield.mouse_filter == Control.MOUSE_FILTER_IGNORE
	var marked: bool = not Mercdave.marks.is_empty()
	Mercdave.toggle()
	await TestFixtures.frames(host, 2)
	var view: Rect2 = host.get_viewport().get_visible_rect()
	TestFixtures.check(res, "17.1 no card: the shield hides and passes the pointer; an open card shows it over the screen",
		idle and marked and layer.card.visible and shield.visible and shield.mouse_filter == Control.MOUSE_FILTER_STOP
			and shield.get_global_rect().is_equal_approx(view),
		"idle %s marks %s card %s shield %s filter %d rect %s view %s" % [idle, marked, layer.card.visible,
			shield.visible, shield.mouse_filter, shield.get_global_rect(), view])
	var card: Rect2 = layer.card.get_global_rect()
	Mercdave.close()
	await TestFixtures.frames(host, 1)
	for spot: Vector2 in SPOTS:
		var rect: Rect2 = Rect2(spot, probe.size)
		if not rect.grow(8.0).intersects(card) and not MercdaveLayer.has_point(rect.get_center()):
			probe.global_position = spot
			break
	await MercdaveScopeCases.settle(host)


#Checks 2 and 3: the probe hovers with no card, not under an open one, and a click on it closes the card only.
static func _case_click(res: Dictionary, host: Node, layer: MercdaveLayer, probe: Button, hits: Array[int]) -> void:
	var at: Vector2 = probe.get_global_rect().get_center()
	await MercdaveCardCases._move(host, at)
	var bare: bool = host.get_viewport().gui_get_hovered_control() == probe
	Mercdave.toggle()
	await TestFixtures.frames(host, 2)
	await MercdaveCardCases._move(host, at)
	var over: Control = host.get_viewport().gui_get_hovered_control()
	TestFixtures.check(res, "17.2 the probe hovers with no card and not while a card is open",
		bare and layer.card.visible and over != probe and not layer.card.get_global_rect().has_point(at),
		"bare %s card %s over %s at %s" % [bare, layer.card.visible, over, at])
	var held: bool = MercdaveLayer.has_point(OFF_POINT)
	host.get_viewport().push_input(MercdaveCardCases._click(at), true)
	host.get_viewport().push_input(MercdaveCardCases._click(at, false), true)
	await TestFixtures.frames(host, 2)
	TestFixtures.check(res, "17.3 a click outside the card closes it and reaches nothing beneath",
		hits[0] == 0 and not Mercdave.card_open and not layer.card.visible and not layer.shield.visible,
		"hits %d open %s card %s shield %s" % [hits[0], Mercdave.card_open, layer.card.visible, layer.shield.visible])
	TestFixtures.check(res, "17.3 MercdaveLayer.has_point is true off the card while it is open and false after it closes",
		held and not MercdaveLayer.has_point(OFF_POINT), "open %s closed %s" % [held, MercdaveLayer.has_point(OFF_POINT)])


static func _case_focus(res: Dictionary, host: Node, layer: MercdaveLayer, probe: Button) -> void:
	probe.grab_focus()
	Mercdave.toggle()
	await TestFixtures.frames(host, 2)
	var held: Control = host.get_viewport().gui_get_focus_owner()
	Mercdave.close()
	await TestFixtures.frames(host, 1)
	var back: Control = host.get_viewport().gui_get_focus_owner()
	TestFixtures.check(res, "17.6 an open card gives the focus to the shield and closing it hands the focus back",
		held == layer.shield and back == probe, "open %s closed %s" % [held, back])


static func _case_frozen(res: Dictionary, host: Node, layer: MercdaveLayer, ids: Array[StringName]) -> void:
	Mercdave.show_hint(ids[0])
	await TestFixtures.frames(host, 3)
	var at: int = Mercdave.marks.find(ids[1])
	var marker: HintMarker = layer.markers[at] if at >= 0 and at < layer.markers.size() else null
	var frozen: bool = marker != null and marker.visible and marker.mouse_filter == Control.MOUSE_FILTER_IGNORE
	Mercdave.close()
	await TestFixtures.frames(host, 1)
	TestFixtures.check(res, "17.4 another marker stays shown but ignores the pointer while a card is open",
		frozen and marker.mouse_filter == Control.MOUSE_FILTER_STOP,
		"marker %s frozen %s filter %d" % [marker, frozen, marker.mouse_filter if marker != null else -1])


#Checks 7 and 8 on two marks, the first with a more text: Tell Me More, then Next Hint, then a moved card.
static func _case_aim(res: Dictionary, host: Node, layer: MercdaveLayer, win: SubWindow,
		ids: Array[StringName]) -> void:
	var card: HintCard = layer.card
	var row: Dictionary = HintBook.row(ids[0])
	var had: bool = row.has("more")
	var kept: Variant = row.get("more", "")
	row["more"] = MercdaveCardCases.MORE_TEXT
	Mercdave.reset_for_tests()
	await MercdaveScopeCases.settle(host)
	Mercdave.show_hint(ids[0])
	await TestFixtures.frames(host, 3)
	var tell: Vector2 = card.tell_more.get_global_rect().get_center()
	TestFixtures.check(res, "17.7 an opened card aims the pointer at Tell Me More",
		card.tell_more.visible and card.next_hint.visible and card.aim_point.is_equal_approx(tell),
		"aim %s tell %s next %s" % [card.aim_point, tell, card.next_hint.visible])
	Mercdave.tell_more()
	await TestFixtures.frames(host, 3)
	var next: Vector2 = card.next_hint.get_global_rect().get_center()
	TestFixtures.check(res, "17.7 after Tell Me More the pointer aims at Next Hint",
		not card.tell_more.visible and card.aim_point.is_equal_approx(next), "aim %s next %s" % [card.aim_point, next])
	var old: Vector2 = card.aim_point
	var was: Vector2 = card.global_position
	var width: float = win.content_width
	win.content_width = width - NARROW
	win._layout()
	await MercdaveScopeCases.settle(host)
	await TestFixtures.frames(host, 3)
	next = card.next_hint.get_global_rect().get_center()
	TestFixtures.check(res, "17.7 a relocated card aims again at the new centre of Next Hint",
		card.visible and not card.global_position.is_equal_approx(was) and card.aim_point.is_equal_approx(next)
			and not card.aim_point.is_equal_approx(old),
		"card %s was %s aim %s next %s old %s" % [card.global_position, was, card.aim_point, next, old])
	await MercdaveCardCases._move(host, card.aim_point)
	var over: Control = host.get_viewport().gui_get_hovered_control()
	TestFixtures.check(res, "17.8 the pointer at the aim point hovers the aimed button",
		over != null and (over == card.next_hint or card.next_hint.is_ancestor_of(over)), "over %s" % over)
	var count: int = card.aim_count
	var point: Vector2 = card.aim_point
	await MercdaveCardCases._move(host, OFF_POINT)
	await TestFixtures.frames(host, 8)
	TestFixtures.check(res, "17.9 leaving the aimed button never aims again",
		card.aim_count == count and card.aim_point == point and count > 0,
		"count %d now %d point %s now %s" % [count, card.aim_count, point, card.aim_point])
	win.content_width = width
	win._layout()
	if had:
		row["more"] = kept
	else:
		row.erase("more")
	Mercdave.close()
	await MercdaveScopeCases.settle(host)


static func _case_none(res: Dictionary, host: Node, layer: MercdaveLayer, boxes: Array[Control]) -> void:
	for box: Control in boxes:
		box.queue_free()
	await MercdaveScopeCases.settle(host)
	Mercdave.toggle()
	await TestFixtures.frames(host, 3)
	var ok: Vector2 = layer.card.ok.get_global_rect().get_center()
	TestFixtures.check(res, "17.7 the no-hints card aims the pointer at Ok",
		Mercdave.current == HintBook.SYS_NONE and layer.card.aim_point.is_equal_approx(ok),
		"current %s aim %s ok %s" % [Mercdave.current, layer.card.aim_point, ok])
	Mercdave.close()
	await TestFixtures.frames(host, 1)


#Check 5: the first Escape closes the card only, the next closes the frame, then the menu grid flips and returns.
static func _case_escape(res: Dictionary, host: Node, hud: GameHUD, content: Control) -> void:
	MercdaveScopeCases.target(content, MercdaveScopeCases.fresh_ids(1)[0], Rect2(40, 40, 120, 40))
	await MercdaveScopeCases.settle(host)
	Mercdave.toggle()
	await TestFixtures.frames(host, 2)
	var opened: bool = Mercdave.card_open and GuiFrameStack.depth() == 1
	await GuiAtomTests._push_key(host, GuiAtomTests._key(KEY_ESCAPE))
	await TestFixtures.frames(host, 1)
	var first: bool = not Mercdave.card_open and GuiFrameStack.depth() == 1
	await GuiAtomTests._push_key(host, GuiAtomTests._key(KEY_ESCAPE))
	await TestFixtures.frames(host, 1)
	TestFixtures.check(res, "17.5 the first Escape closes only the card and the second closes the frame",
		opened and first and GuiFrameStack.depth() == 0,
		"opened %s first %s depth %d" % [opened, first, GuiFrameStack.depth()])
	var toggle: MainMenuToggle = hud.get_node_or_null(MENU_PATH) as MainMenuToggle
	var before: bool = toggle != null and toggle.is_menu_visible()
	await GuiAtomTests._push_key(host, GuiAtomTests._key(KEY_ESCAPE))
	await TestFixtures.frames(host, 1)
	var flipped: bool = toggle != null and toggle.is_menu_visible() != before
	await GuiAtomTests._push_key(host, GuiAtomTests._key(KEY_ESCAPE))
	await TestFixtures.frames(host, 1)
	TestFixtures.check(res, "17.5 at depth 0 Escape flips the main menu grid and the next Escape restores it",
		flipped and toggle.is_menu_visible() == before, "toggle %s before %s flipped %s" % [toggle, before, flipped])
