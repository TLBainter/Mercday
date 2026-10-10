class_name MercdaveScopeCases

#MercdaveUiTests overlay checks 1-3, the focus parts of 6, 12 and 14 on a spawned GameHUD, whose layer is the
#newest and so the live one. Fixture targets sit in an in-memory probe scene opened in the HUD SubWindow.

const LAYER_PATH: NodePath = ^"Root/MercdaveLayer"
const MODAL_SCENE: String = "res://Scenes/GUI/Shared/ModalDialog.tscn"
const PANEL_SCENE: String = "res://Scenes/GUI/Notifications/NotificationPanel.tscn"
const PROBE_A: String = "res://mercdave_probe_a.tscn"
const PROBE_B: String = "res://mercdave_probe_b.tscn"
const MARK_OFFSET: Vector2 = Vector2(-17, -17)
#Nine hud_* targets and the nine menu_* tiles.
const HUD_HINTS: int = 18


class WarnLog extends Logger:
	var watched: String = ""
	var warnings: int = 0
	var errors: int = 0

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			errors += 1
		elif watched != "" and (code.contains(watched) or rationale.contains(watched)):
			warnings += 1


static func run(res: Dictionary, host: Node) -> void:
	var hud: GameHUD = await spawn(host)
	await _case_scope(res, host, hud)
	await _case_targets(res, host, hud)
	hud.queue_free()
	await TestFixtures.frames(host, 2)


static func spawn(host: Node) -> GameHUD:
	Mercdave.reset_for_tests()
	SubscriptionManager.max_out()
	var hud: GameHUD = GuiHudTests.spawn_hud(host)
	await settle(host)
	return hud


static func layer_of(hud: GameHUD) -> MercdaveLayer:
	return hud.get_node_or_null(LAYER_PATH) as MercdaveLayer


static func settle(host: Node) -> void:
	Mercdave.request_scan()
	await TestFixtures.frames(host, 3)


#An in-memory scene with a file path, so the SubWindow scope key is that path.
static func probe(path: String) -> PackedScene:
	var packed: PackedScene = GuiFrameTests.empty_scene()
	packed.take_over_path(path)
	return packed


static func target(parent: Node, id: StringName, at: Rect2) -> Control:
	var box: Control = Control.new()
	box.name = "Probe_%s" % id
	box.position = at.position
	box.size = at.size
	var link: HelpTarget = HelpTarget.new()
	link.hint = HintBook.hint(id)
	box.add_child(link)
	parent.add_child(box)
	return box


static func fresh_ids(count: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in HintBook.ids():
		if out.size() < count and id != HintBook.SYS_NONE and Mercdave.is_available(id):
			out.append(id)
	return out


static func shown_markers(layer: MercdaveLayer) -> int:
	var count: int = 0
	for marker: HintMarker in layer.markers:
		if marker.visible:
			count += 1
	return count


static func _case_scope(res: Dictionary, host: Node, hud: GameHUD) -> void:
	var layer: MercdaveLayer = layer_of(hud)
	var missing: Array[StringName] = []
	for id: StringName in HintBook.ids():
		if (String(id).begins_with("hud_") or String(id).begins_with("menu_")) and not Mercdave.marks.has(id):
			missing.append(id)
	TestFixtures.check(res, "1 no frame: HUD scope, a marker on every unread HUD target, no card",
		layer != null and layer.is_live() and GuiFrameStack.top() == null and Mercdave.scope_key == HintScope.HUD_KEY
			and Mercdave.marks == Mercdave.unread and Mercdave.marks.size() == HUD_HINTS
			and shown_markers(layer) == HUD_HINTS and not Mercdave.card_open and not layer.card.visible,
		"key %s marks %d shown %d open %s missing %s" % [Mercdave.scope_key, Mercdave.marks.size(),
			shown_markers(layer), Mercdave.card_open, missing])
	var head: StringName = Mercdave.marks[0] if not Mercdave.marks.is_empty() else &""
	Mercdave.toggle()
	await settle(host)
	TestFixtures.check(res, "1 the tab opens the first HUD hint, step 1 of 18, and its mark goes",
		Mercdave.card_open and Mercdave.current == head and not Mercdave.marks.has(head)
			and layer.card.visible and layer.card.step.text == "1 of %d" % HUD_HINTS,
		"open %s current %s step %s" % [Mercdave.card_open, Mercdave.current, layer.card.step.text])
	Mercdave.close()
	await settle(host)
	TestFixtures.check(res, "1 the HUD card stays shut after close and the read hint keeps no mark",
		not Mercdave.card_open and Mercdave.marks.size() == HUD_HINTS - 1 and not layer.card.visible,
		"open %s marks %d" % [Mercdave.card_open, Mercdave.marks.size()])
	var modal: ModalDialog = (load(MODAL_SCENE) as PackedScene).instantiate()
	host.add_child(modal)
	await TestFixtures.frames(host, 2)
	modal.present()
	await settle(host)
	var modal_key: StringName = Mercdave.scope_key
	var modal_marks: int = shown_markers(layer)
	modal.close()
	await settle(host)
	TestFixtures.check(res, "1 a ModalDialog takes the scope and closing it returns to the HUD",
		modal_key == StringName(MODAL_SCENE) and modal_marks == 0 and Mercdave.scope_key == HintScope.HUD_KEY,
		"modal %s marks %d after %s" % [modal_key, modal_marks, Mercdave.scope_key])
	modal.queue_free()
	var win: SubWindow = hud.popup()
	win.open(probe(PROBE_A))
	await settle(host)
	var key_a: StringName = Mercdave.scope_key
	win.open(probe(PROBE_B))
	await settle(host)
	var key_b: StringName = Mercdave.scope_key
	win.close()
	await settle(host)
	TestFixtures.check(res, "1 an open SubWindow keys the scope by its content scene and swaps it on the next open",
		key_a == StringName(PROBE_A) and key_b == StringName(PROBE_B) and Mercdave.scope_key == HintScope.HUD_KEY,
		"a %s b %s after %s" % [key_a, key_b, Mercdave.scope_key])
	var bell: NotificationBell = hud.bell() as NotificationBell
	if bell == null:
		TestFixtures.check(res, "1 the HUD has a NotificationBell", false, "no bell")
		return
	bell.open_panel()
	await settle(host)
	var panel_key: StringName = Mercdave.scope_key
	bell.close_panel()
	await settle(host)
	TestFixtures.check(res, "1 an open NotificationPanel is its own scope and closing it returns to the HUD",
		panel_key == StringName(PANEL_SCENE) and Mercdave.scope_key == HintScope.HUD_KEY,
		"panel %s after %s" % [panel_key, Mercdave.scope_key])


static func _case_targets(res: Dictionary, host: Node, hud: GameHUD) -> void:
	Mercdave.reset_for_tests()
	var layer: MercdaveLayer = layer_of(hud)
	var win: SubWindow = hud.popup()
	var content: Control = win.open(probe(PROBE_A)) as Control
	var ids: Array[StringName] = fresh_ids(7)
	var first: Control = target(content, ids[0], Rect2(40, 40, 120, 40))
	var second: Control = target(content, ids[1], Rect2(40, 120, 120, 40))
	var hidden: Control = target(content, ids[2], Rect2(40, 200, 120, 40))
	hidden.visible = false
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(240, 40)
	scroll.size = Vector2(200, 100)
	content.add_child(scroll)
	var sheet: Control = Control.new()
	sheet.custom_minimum_size = Vector2(180, 600)
	scroll.add_child(sheet)
	var clipped: Control = target(sheet, ids[3], Rect2(10, 400, 120, 40))
	await settle(host)
	var two: Array[StringName] = [ids[0], ids[1]]
	TestFixtures.check(res, "2 a hidden target is not present and a clipped one is present without a marker",
		Mercdave.marks == two and shown_markers(layer) == 2 and Mercdave.unread.has(ids[3])
			and not Mercdave.unread.has(ids[2]),
		"marks %s unread %s" % [Mercdave.marks, Mercdave.unread])
	TestFixtures.check(res, "3 markers sit centred on the target top left (-17,-17)",
		layer.markers[0].global_position.is_equal_approx(first.get_global_rect().position + MARK_OFFSET)
			and layer.markers[1].global_position.is_equal_approx(second.get_global_rect().position + MARK_OFFSET),
		"m0 %s t0 %s" % [layer.markers[0].global_position, first.get_global_rect().position])
	var m: HintMarker = layer.markers[0]
	var centre: Vector2 = m.get_global_rect().get_center()
	var art: bool = (m.get_global_rect().size == Vector2(34, 34) and m.icon.icon_id == "question"
		and m.icon.pixel_scale == 1 and m.icon.tint == HintMarker.GLYPH
		and m.icon.get_global_rect().size.is_equal_approx(Vector2(16, 16))
		and m.icon.get_global_rect().get_center().is_equal_approx(centre)
		and m.box.get_global_rect().size.is_equal_approx(HintBox.SIZE)
		and m.box.get_global_rect().get_center().is_equal_approx(centre)
		and m.halo.texture.get_size() == Vector2(22, 22)
		and m.halo.get_global_rect().get_center().is_equal_approx(centre)
		and m.halo.get_index() == 0 and m.box.get_index() == 1 and m.icon.get_parent() == m.box)
	var ring: Image = m.halo.texture.get_image()
	var alphas: Array[float] = [ring.get_pixel(1, 11).a, ring.get_pixel(0, 11).a, ring.get_pixel(0, 0).a,
		ring.get_pixel(11, 11).a]
	TestFixtures.check(res,
		"3 markers are a 34x34 hit box around an 18x18 amber box holding the 16x16 dark amber question mark, "
			+ "with a 2 px halo ringing the box",
		art and absf(alphas[0] - 0.75) < 0.01 and absf(alphas[1] - 0.35) < 0.01 and absf(alphas[2] - 0.35) < 0.01
			and alphas[3] == 0.0,
		"hit %s box %s icon %s halo %s ring %s trimmed glyph %s" % [m.get_global_rect().size,
			m.box.get_global_rect().size, m.icon.get_global_rect().size, m.halo.texture.get_size(), alphas,
			Icons.image("question", true).get_size()])
	var click: SoundLibrary = UiSfx.click_library(m)
	var hover: SoundLibrary = UiSfx.hover_library(m)
	TestFixtures.check(res, "3 markers click and hover with the MercDave libraries",
		click == UiSfx.config.mercdave_click and hover == UiSfx.config.mercdave_hover,
		"click %s hover %s" % [click.resource_path.get_file() if click != null else "null",
			hover.resource_path.get_file() if hover != null else "null"])
	var shown: bool = m.visible
	m.mouse_entered.emit()
	var popping: bool = m._pop_tween != null and m._pop_tween.is_running()
	await host.get_tree().create_timer(0.25).timeout
	var peak_level: float = m.hover_level
	var peak_glow: Color = m.icon.modulate
	var peak_halo: float = m.halo.modulate.a
	var settled: Vector2 = m.box.scale
	m.mouse_exited.emit()
	await host.get_tree().create_timer(0.45).timeout
	TestFixtures.check(res,
		"3 hovering a marker tweens its halo to full glow with a box and glyph pop and eases back into the pulse",
		shown and popping and is_equal_approx(peak_level, 1.0) and peak_glow.is_equal_approx(HintMarker.GLYPH)
			and is_equal_approx(peak_halo, 1.0) and settled == Vector2.ONE
			and m.box.pivot_offset == HintBox.SIZE / 2.0 and is_equal_approx(m.hover_level, 0.0),
		"visible %s pop %s level %.3f glow %s halo %.3f scale %s pivot %s after %.3f" % [shown, popping, peak_level,
			peak_glow, peak_halo, settled, m.box.pivot_offset, m.hover_level])
	var wave: bool = (is_equal_approx(HintMarkers.glow_at(0.0), 1.0) and is_equal_approx(HintMarkers.glow_at(1.0), 0.0)
		and is_equal_approx(HintMarkers.glow_at(0.5), 0.5) and is_equal_approx(HintMarkers.glow_at(2.0), 1.0))
	await TestFixtures.frames(host, 2)
	var glow: Color = layer.markers[0].icon.modulate
	var halo_a: float = layer.markers[0].halo.modulate.a
	var both: bool = layer.markers[0].visible and layer.markers[1].visible
	TestFixtures.check(res,
		"3 markers glow in step: the halo alpha follows one 2 s triangle wave and the glyph stays steady",
		wave and halo_a >= 0.0 and halo_a <= 1.0 and glow == HintMarker.GLYPH and (not both
			or (layer.markers[0].halo.modulate == layer.markers[1].halo.modulate
			and layer.markers[1].icon.modulate == HintMarker.GLYPH)),
		"halo %.3f glow %s other %s wave %s" % [halo_a, glow, layer.markers[1].icon.modulate, wave])
	Mercdave.toggle()
	await TestFixtures.frames(host, 1)
	var aim: Rect2 = first.get_global_rect().grow(MercdaveLayer.OUTLINE_PX)
	var start: Rect2 = layer.focus.ring_rect()
	var start_dim: float = layer.focus.dim_alpha()
	TestFixtures.check(res, "6 the focus starts at 1.5x the target with a lighter dim",
		layer.focus.visible and start.size.x > aim.size.x and start.size.y > aim.size.y
			and start_dim > 0.0 and start_dim < HintFocus.DIM_ALPHA,
		"ring %s target %s dim %.3f" % [start, aim, start_dim])
	await _settle_focus(host)
	var end: Rect2 = layer.focus.ring_rect()
	TestFixtures.check(res, "6 the focus settles on the target in 0.5 s",
		_near(end, aim) and absf(layer.focus.dim_alpha() - HintFocus.DIM_ALPHA) < 0.001,
		"ring %s target %s dim %.3f" % [end, aim, layer.focus.dim_alpha()])
	var wrap: Rect2 = Rect2(layer.outline.global_position, layer.outline.size)
	TestFixtures.check(res, "3 the outline wraps the current target",
		Mercdave.current == ids[0] and layer.outline.visible
			and wrap.is_equal_approx(first.get_global_rect().grow(MercdaveLayer.OUTLINE_PX)),
		"current %s ring %s" % [Mercdave.current, wrap])
	layer.markers[0].pressed.emit()
	await TestFixtures.frames(host, 1)
	var again_dim: float = layer.focus.dim_alpha()
	TestFixtures.check(res, "6 a second hint restarts the focus",
		Mercdave.current == ids[1] and again_dim < HintFocus.DIM_ALPHA, "dim %.3f" % again_dim)
	await _settle_focus(host)
	wrap = Rect2(layer.outline.global_position, layer.outline.size)
	TestFixtures.check(res, "3 pressing a marker opens its hint and the outline follows",
		Mercdave.current == ids[1] and wrap.is_equal_approx(second.get_global_rect().grow(MercdaveLayer.OUTLINE_PX)),
		"current %s ring %s" % [Mercdave.current, wrap])
	var third: Control = target(content, ids[5], Rect2(480, 40, 120, 40))
	target(content, ids[6], Rect2(480, 120, 120, 40))
	await settle(host)
	Mercdave.show_hint(ids[0])
	await TestFixtures.frames(host, 2)
	var poke: InputEventMouseButton = InputEventMouseButton.new()
	poke.button_index = MOUSE_BUTTON_LEFT
	poke.pressed = true
	poke.position = Vector2(2, 2)
	poke.global_position = layer.markers[0].global_position + Vector2(2, 2)
	layer.markers[0]._gui_input(poke)
	await _settle_focus(host)
	wrap = Rect2(layer.outline.global_position, layer.outline.size)
	TestFixtures.check(res, "3 a click in the hit box corner, off the glyph, opens that hint",
		Mercdave.current == ids[5] and layer.card.visible
			and wrap.is_equal_approx(third.get_global_rect().grow(MercdaveLayer.OUTLINE_PX)),
		"current %s card %s ring %s" % [Mercdave.current, layer.card.visible, wrap])
	Mercdave.close()
	await TestFixtures.frames(host, 1)
	TestFixtures.check(res, "6 the dim leaves with the card",
		not layer.focus.visible and layer.focus.dim_alpha() == 0.0,
		"visible %s dim %.3f" % [layer.focus.visible, layer.focus.dim_alpha()])
	await _case_dialog_over(res, host, layer)
	scroll.scroll_vertical = 350
	await TestFixtures.frames(host, 1)
	TestFixtures.check(res, "12 scrolling the clipped target into view marks it after one scan",
		Mercdave.marks.has(ids[3]) and shown_markers(layer) == 2, "marks %s" % [Mercdave.marks])
	Mercdave.show_hint(ids[3])
	await TestFixtures.frames(host, 2)
	var ring_in: bool = layer.outline.visible
	scroll.scroll_vertical = 0
	await TestFixtures.frames(host, 2)
	var ring_out: bool = layer.outline.visible
	scroll.scroll_vertical = 350
	await TestFixtures.frames(host, 2)
	TestFixtures.check(res, "12 the outline hides when the current target scrolls out of its clip and returns with it",
		ring_in and not ring_out and layer.card.visible and Mercdave.current == ids[3] and layer.outline.visible,
		"in %s out %s back %s current %s" % [ring_in, ring_out, layer.outline.visible, Mercdave.current])
	#Opening ids[3] read it; a reset brings its mark back so the resize has a mark to drop.
	Mercdave.reset_for_tests()
	await settle(host)
	clipped.position = Vector2(10, 40)
	await TestFixtures.frames(host, 3)
	var stale: bool = Mercdave.marks.has(ids[3])
	host.get_viewport().size_changed.emit()
	await TestFixtures.frames(host, 3)
	TestFixtures.check(res, "12 a viewport resize rescans (a target moved out of the clip drops its mark)",
		stale and not Mercdave.marks.has(ids[3]), "stale %s marks %s" % [stale, Mercdave.marks])
	await _case_bad_links(res, host, content, ids[4])
	win.close()
	await settle(host)


static func _case_dialog_over(res: Dictionary, host: Node, layer: MercdaveLayer) -> void:
	var before: int = shown_markers(layer)
	var modal: ModalDialog = (load(MODAL_SCENE) as PackedScene).instantiate()
	host.add_child(modal)
	await TestFixtures.frames(host, 2)
	modal.present()
	await settle(host)
	var over: int = shown_markers(layer)
	var over_marks: int = Mercdave.marks.size()
	modal.close()
	modal.queue_free()
	await settle(host)
	TestFixtures.check(res, "2 a dialog over the window hides the window markers and closing it brings them back",
		before > 0 and over == 0 and over_marks == 0 and shown_markers(layer) == before,
		"before %d over %d back %d" % [before, over, shown_markers(layer)])


static func _case_bad_links(res: Dictionary, host: Node, content: Control, id: StringName) -> void:
	var sink: WarnLog = WarnLog.new()
	OS.add_logger(sink)
	sink.watched = "has no hint"
	var bare: Control = Control.new()
	bare.position = Vector2(40, 280)
	bare.size = Vector2(120, 40)
	bare.add_child(HelpTarget.new())
	content.add_child(bare)
	var no_hint: int = sink.warnings
	sink.warnings = 0
	sink.watched = "is not a Control"
	var lost: HelpTarget = HelpTarget.new()
	lost.hint = HintBook.hint(id)
	lost.target = ^"../Nowhere"
	var holder: Control = Control.new()
	holder.position = Vector2(40, 340)
	holder.size = Vector2(120, 40)
	holder.add_child(lost)
	content.add_child(holder)
	var no_target: int = sink.warnings
	OS.remove_logger(sink)
	await settle(host)
	TestFixtures.check(res, "14 a null hint and an unresolvable target push one warning each and add no mark",
		no_hint == 1 and no_target == 1 and not Mercdave.unread.has(id) and not Mercdave.marks.has(&""),
		"no hint %d no target %d unread %s" % [no_hint, no_target, Mercdave.unread])


#Waits past HintFocus.DURATION so the gold box sits on its target.
static func _settle_focus(host: Node) -> void:
	await host.get_tree().create_timer(0.6).timeout
	await TestFixtures.frames(host, 1)


static func _near(a: Rect2, b: Rect2) -> bool:
	return a.position.distance_to(b.position) <= 1.0 and a.end.distance_to(b.end) <= 1.0
