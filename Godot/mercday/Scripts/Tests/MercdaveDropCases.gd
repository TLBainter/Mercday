class_name MercdaveDropCases

#MercdaveUiTests check 16 (D3c): each converted dropdown opens its DropPanel as a top level Control in
#its frame, above the frame and under the MercDave layer, and closes on an outside press or Esc only.

const PROBE: String = "res://mercdave_probe_drop.tscn"
const FRAME_STYLE: String = "res://Resources/GUI/Theme/Styles/PopupFrame.tres"
const CLIENT_STYLE: String = "res://Resources/GUI/Theme/Styles/client_popup.tres"
const CLIENT_SCENE: String = "res://Scenes/GUI/Clients/ClientFilterButton.tscn"
const FILTER_SCENE: String = "res://Scenes/GUI/Shared/FilterButton.tscn"
const DROPDOWN_SCENE: String = "res://Scenes/GUI/Shared/OptionDropdown.tscn"
const ADS_SCENE: String = "res://Scenes/GUI/Promotions/AdsToolbar.tscn"
const LIST_SCENE: String = "res://Scenes/GUI/Contracts/ContractList.tscn"
const SLOT_SCENE: String = "res://Scenes/GUI/Contracts/TeamSlot.tscn"
const CONVERTED: Array[String] = [
	"res://Scenes/GUI/Contracts/ContractFilterPanel.tscn",
	CLIENT_SCENE,
	"res://Scenes/GUI/Metrics/MercSelector.tscn",
	"res://Scenes/GUI/Metrics/TypeSelector.tscn",
	FILTER_SCENE,
	"res://Scenes/GUI/Shared/FilterSortButton.tscn",
	"res://Scenes/GUI/Shared/SortButton.tscn",
	"res://Scenes/GUI/Promotions/UnitDropdown.tscn",
	DROPDOWN_SCENE,
	ADS_SCENE,
	SLOT_SCENE,
]
const MIN_PANELS: int = 11
const GRID: float = 16.0


class AnyLog extends Logger:
	var errors: int = 0
	var warnings: int = 0
	var first: String = ""

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			warnings += 1
		else:
			errors += 1
		if first == "":
			first = "%s %s" % [code, rationale]


static func run(res: Dictionary, host: Node) -> void:
	await _case_scenes(res, host)
	await _case_start(res, host)
	await _case_parent_hide(res, host)
	var hud: GameHUD = await MercdaveScopeCases.spawn(host)
	var layer: MercdaveLayer = MercdaveScopeCases.layer_of(hud)
	var win: SubWindow = hud.popup()
	var content: Control = win.open(MercdaveScopeCases.probe(PROBE)) as Control
	var kits: Array[Dictionary] = await _build(host, win, content)
	await _case_marker(res, host, layer, kits[kits.size() - 1])
	var avoid: Array[Rect2] = [win.close_x.get_global_rect()]
	for kit: Dictionary in kits:
		avoid.append((kit["box"] as Control).get_global_rect())
	var area: Rect2 = win.holder.get_global_rect().intersection(host.get_viewport().get_visible_rect())
	for kit: Dictionary in kits:
		await _case_drop(res, host, layer, win, kit, area, avoid)
	await _case_two_escapes(res, host, win, kits[0])
	hud.queue_free()
	await TestFixtures.frames(host, 2)


#Item 7: each converted scene loads with no error or warning; item 4 and the look: every DropPanel in
#it starts hidden and closed and draws PopupFrame, client_popup on ClientFilterButton, or its own override
#of the panel slot (UnitDropdown), which a PopupPanel read under the same name.
static func _case_scenes(res: Dictionary, host: Node) -> void:
	var sink: AnyLog = AnyLog.new()
	var bad: Array[String] = []
	var looks: Array[String] = []
	var sizes: Array[String] = []
	var panels: int = 0
	for path: String in CONVERTED:
		sink.errors = 0
		sink.warnings = 0
		sink.first = ""
		OS.add_logger(sink)
		var packed: PackedScene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		var node: Node = null if packed == null else packed.instantiate()
		var hits: Array[int] = [0]
		var found: Array[DropPanel] = []
		if node != null:
			_drop_panels(node, found)
			for panel: DropPanel in found:
				panel.popup_hide.connect(func() -> void: hits[0] += 1)
			host.add_child(node)
		await TestFixtures.frames(host, 1)
		OS.remove_logger(sink)
		if node == null or sink.errors + sink.warnings > 0:
			bad.append("%s e%d w%d %s" % [path.get_file(), sink.errors, sink.warnings, sink.first])
		var style: StyleBox = load(CLIENT_STYLE if path == CLIENT_SCENE else FRAME_STYLE)
		for panel: DropPanel in found:
			panels += 1
			var own: bool = path != CLIENT_SCENE and panel.has_theme_stylebox_override("panel")
			if panel.visible or panel.is_open() or hits[0] != 0 or not (own or panel.get_theme_stylebox("panel") == style):
				looks.append("%s/%s" % [path.get_file(), panel.name])
			var twin_size: Vector2 = _twin_size(panel)
			if not twin_size.is_equal_approx(panel.get_combined_minimum_size()):
				sizes.append("%s/%s %s vs %s" % [path.get_file(), panel.name, panel.get_combined_minimum_size(), twin_size])
		if node != null:
			node.queue_free()
	await TestFixtures.frames(host, 1)
	TestFixtures.check(res, "16 each converted scene loads with no error and no warning", bad.is_empty(), str(bad))
	TestFixtures.check(res, "16 every converted DropPanel starts hidden and closed and keeps its PopupPanel stylebox",
		looks.is_empty() and panels >= MIN_PANELS, "panels %d off %s" % [panels, looks])
	TestFixtures.check(res, "16 every converted DropPanel has the minimum size a PopupPanel gives the same content",
		sizes.is_empty() and panels >= MIN_PANELS, "panels %d off %s" % [panels, sizes])


#A PopupPanel inside the panel, lent its non top level children and its own panel override, if any;
#returns that window's contents minimum size and gives the children back in order.
static func _twin_size(panel: DropPanel) -> Vector2:
	var lent: Array[Control] = []
	var spots: Array[int] = []
	for child: Node in panel.get_children():
		var part: Control = child as Control
		if part != null and not part.top_level:
			lent.append(part)
			spots.append(part.get_index())
	var twin: PopupPanel = PopupPanel.new()
	if panel.has_theme_stylebox_override("panel"):
		twin.add_theme_stylebox_override("panel", panel.get_theme_stylebox("panel"))
	panel.add_child(twin)
	for part: Control in lent:
		part.reparent(twin, false)
	var got: Vector2 = twin.get_contents_minimum_size()
	for i: int in lent.size():
		lent[i].reparent(panel, false)
		panel.move_child(lent[i], spots[i])
	twin.free()
	return got


#Items 3 and 4 with no frame: a panel built in code starts hidden, a second hide fires no popup_hide,
#and a popup under no frame draws at z 1 or more.
static func _case_start(res: Dictionary, host: Node) -> void:
	var hits: Array[int] = [0]
	var panel: DropPanel = DropPanel.new()
	panel.popup_hide.connect(func() -> void: hits[0] += 1)
	var closed_at_init: bool = not panel.visible and not panel.is_open()
	host.add_child(panel)
	await TestFixtures.frames(host, 1)
	panel.hide()
	await TestFixtures.frames(host, 1)
	TestFixtures.check(res, "16 a DropPanel built in code starts hidden and hiding it again fires no popup_hide",
		closed_at_init and not panel.visible and not panel.is_open() and hits[0] == 0, "hits %d" % hits[0])
	panel.popup(Rect2i(40, 40, 120, 60))
	await TestFixtures.frames(host, 1)
	TestFixtures.check(res, "16 a panel opened under no frame draws at z 1 or more",
		GuiFrameStack.top() == null and panel.is_open() and panel.visible and panel.z_index >= 1,
		"top %s z %d" % [GuiFrameStack.top(), panel.z_index])
	panel.hide()
	TestFixtures.check(res, "16 closing an open panel fires popup_hide once", hits[0] == 1, "hits %d" % hits[0])
	panel.queue_free()
	await TestFixtures.frames(host, 1)


#Ruling 9: hiding the parent of an open panel closes it once, and showing the parent again leaves it closed.
static func _case_parent_hide(res: Dictionary, host: Node) -> void:
	var hits: Array[int] = [0]
	var holder: Control = Control.new()
	var panel: DropPanel = DropPanel.new()
	panel.popup_hide.connect(func() -> void: hits[0] += 1)
	holder.add_child(panel)
	host.add_child(holder)
	await TestFixtures.frames(host, 1)
	panel.popup(Rect2i(40, 40, 120, 60))
	await TestFixtures.frames(host, 1)
	var opened: bool = panel.is_open() and panel.is_visible_in_tree()
	holder.hide()
	await TestFixtures.frames(host, 1)
	var closed: bool = not panel.is_open() and not panel.visible and hits[0] == 1
	holder.show()
	await TestFixtures.frames(host, 1)
	TestFixtures.check(res, "16 hiding the parent of an open panel closes it once and showing the parent keeps it closed",
		opened and closed and not panel.is_open() and not panel.visible and hits[0] == 1,
		"opened %s closed %s open %s visible %s hits %d" % [opened, closed, panel.is_open(), panel.visible, hits[0]])
	holder.queue_free()
	await TestFixtures.frames(host, 1)


#The five dropdowns of check 16 in the SubWindow content, over a pad that takes the outside clicks off
#the backdrop; the ContractList sits in a clip_contents box that ends just under its filter button.
#Each kit: tag, panel, opener, box and want (the asked size).
static func _build(host: Node, win: SubWindow, content: Control) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pad: Control = Control.new()
	pad.name = "Pad"
	pad.size = win.holder.size
	content.add_child(pad)
	var filter: FilterButton = _place(content, FILTER_SCENE, Vector2(20, 20)) as FilterButton
	filter.custom_minimum_size = Vector2(120, 32)
	out.append({"tag": "FilterButton", "panel": filter.menu, "opener": filter, "box": filter,
		"want": func() -> Vector2: return _sized(filter._popup_size())})
	var drop: OptionDropdown = _place(content, DROPDOWN_SCENE, Vector2(220, 20)) as OptionDropdown
	drop.custom_minimum_size = Vector2(180, 30)
	var opts: Array[Dictionary] = [{"key": &"alpha", "label": "Alpha"}, {"key": &"bravo", "label": "Bravo"}]
	drop.set_options(opts)
	drop.select(&"alpha")
	out.append({"tag": "OptionDropdown", "panel": drop.menu, "opener": drop.toggle, "box": drop,
		"want": func() -> Vector2: return _dropdown_size(drop)})
	var slot: TeamSlot = _place(content, SLOT_SCENE, Vector2(440, 20)) as TeamSlot
	slot.set_slot(1, "Optional")
	var role: OptionDropdown = slot.role_option
	out.append({"tag": "TeamSlot Role", "panel": role.menu, "opener": role.toggle, "box": slot,
		"want": func() -> Vector2: return _dropdown_size(role)})
	var ads: AdsToolbar = _place(content, ADS_SCENE, Vector2(20, 100)) as AdsToolbar
	out.append({"tag": "AdsToolbar filter", "panel": ads.filter_menu, "opener": ads.filter_button, "box": ads,
		"want": func() -> Vector2: return _min_size(ads.filter_menu, Vector2(AdsToolbar.FILTER_POPUP_WIDTH, 0))})
	var clip: Control = Control.new()
	clip.name = "Clip"
	clip.clip_contents = true
	clip.position = Vector2(20, 170)
	clip.size = Vector2(360, 400)
	content.add_child(clip)
	var list: ContractList = (load(LIST_SCENE) as PackedScene).instantiate() as ContractList
	clip.add_child(list)
	list.set_anchors_preset(Control.PRESET_TOP_LEFT)
	list.position = Vector2.ZERO
	list.size = Vector2(360, 400)
	await MercdaveScopeCases.settle(host)
	clip.size = Vector2(clip.size.x, list.filter_button.get_global_rect().end.y - clip.global_position.y + 2.0)
	out.append({"tag": "ContractFilterPanel", "panel": list.filter_panel, "opener": list.filter_button, "box": clip,
		"want": func() -> Vector2: return _min_size(list.filter_panel, Vector2(260, 200))})
	await TestFixtures.frames(host, 1)
	return out


static func _place(parent: Control, path: String, at: Vector2) -> Control:
	var node: Control = (load(path) as PackedScene).instantiate() as Control
	parent.add_child(node)
	node.position = at
	return node


static func _sized(wanted: Vector2) -> Vector2:
	return Vector2(int(wanted.x), int(wanted.y))


static func _dropdown_size(drop: OptionDropdown) -> Vector2:
	var rect: Rect2i = drop._target_rect(drop.toggle.get_global_rect(), drop.menu.get_combined_minimum_size())
	return Vector2(rect.size)


static func _min_size(panel: DropPanel, floor_size: Vector2) -> Vector2:
	var wanted: Vector2 = panel.get_combined_minimum_size()
	return _sized(Vector2(maxf(wanted.x, floor_size.x), maxf(wanted.y, floor_size.y)))


#Check 16 marker and the clip escape: a fixture HelpTarget on the Reset button of the open
#ContractFilterPanel gets a marker, and the panel, being top level, is not cut by the clip box.
static func _case_marker(res: Dictionary, host: Node, layer: MercdaveLayer, kit: Dictionary) -> void:
	var panel: ContractFilterPanel = kit["panel"] as ContractFilterPanel
	var clip: Control = kit["box"] as Control
	var id: StringName = MercdaveScopeCases.fresh_ids(1)[0]
	var link: HelpTarget = HelpTarget.new()
	link.hint = HintBook.hint(id)
	panel.reset_button.add_child(link)
	await MercdaveScopeCases.settle(host)
	var marked_closed: bool = Mercdave.marks.has(id)
	(kit["opener"] as BaseButton).pressed.emit()
	await MercdaveScopeCases.settle(host)
	var reset: Control = panel.reset_button
	var at: int = Mercdave.marks.find(id)
	var mark: Vector2 = layer.markers[at].global_position if at >= 0 and at < layer.markers.size() else Vector2(-1, -1)
	TestFixtures.check(res, "16 a HelpTarget inside the open ContractFilterPanel gets a marker at its top left",
		not marked_closed and panel.is_open() and at >= 0
			and mark.is_equal_approx(reset.get_global_rect().position + MercdaveScopeCases.MARK_OFFSET),
		"closed %s marks %s mark %s reset %s" % [marked_closed, Mercdave.marks, mark, reset.get_global_rect()])
	var twin: Control = Control.new()
	clip.add_child(twin)
	twin.global_position = reset.global_position
	twin.size = reset.size
	TestFixtures.check(res, "16 a top level panel escapes the clip_contents of its ancestors (HintScope.on_screen)",
		clip.clip_contents and not clip.get_global_rect().intersects(reset.get_global_rect())
			and HintScope.on_screen(reset) and not HintScope.on_screen(twin),
		"clip %s reset %s on %s twin %s" % [clip.get_global_rect(), reset.get_global_rect(),
			HintScope.on_screen(reset), HintScope.on_screen(twin)])
	twin.queue_free()
	link.queue_free()
	panel.hide()
	Mercdave.close()
	await MercdaveScopeCases.settle(host)


#Check 16 per dropdown, with items 3, 5 and 6: open, z and look, a card click keeps it, an outside
#click and the first Esc close it (popup_hide once each) and a press and release on its opener closes it.
static func _case_drop(res: Dictionary, host: Node, layer: MercdaveLayer, win: SubWindow, kit: Dictionary,
		area: Rect2, avoid: Array[Rect2]) -> void:
	var tag: String = kit["tag"]
	var panel: DropPanel = kit["panel"] as DropPanel
	var opener: BaseButton = kit["opener"] as BaseButton
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	panel.popup_hide.connect(count)
	opener.pressed.emit()
	await TestFixtures.frames(host, 1)
	var top: Control = GuiFrameStack.top()
	var none: Array[Control] = []
	TestFixtures.check(res, "16 %s opens as a visible top level Control inside its frame" % tag,
		panel.is_open() and panel.is_visible_in_tree() and panel.top_level and top == win
			and panel.get_viewport() == win.get_viewport() and HintScope.owner_of(panel, top, none) == win,
		"open %s visible %s top %s" % [panel.is_open(), panel.is_visible_in_tree(), top])
	TestFixtures.check(res, "16 %s draws above its frame and under the MercDave layer" % tag,
		panel.z_index > win.z_index and panel.z_index < GuiFrameStack.HINT_Z, "z %d frame %d" % [panel.z_index, win.z_index])
	var want: Vector2 = (kit["want"] as Callable).call()
	var below: float = opener.get_global_rect().end.y
	TestFixtures.check(res, "16 %s keeps its look: PopupFrame, the size it asked for, right under its opener" % tag,
		panel.get_theme_stylebox("panel") == load(FRAME_STYLE) and panel.size.is_equal_approx(want)
			and is_equal_approx(panel.global_position.y, below),
		"size %s want %s y %.1f below %.1f" % [panel.size, want, panel.global_position.y, below])
	Mercdave.show_hint(HintBook.SYS_NONE)
	await TestFixtures.frames(host, 2)
	var keep_out: Array[Rect2] = [panel.get_global_rect()]
	for button: Node in layer.card.find_children("*", "BaseButton", true, false):
		keep_out.append((button as Control).get_global_rect())
	var on_card: Vector2 = _free_point(layer.card.get_global_rect(), keep_out, false)
	await _click(host, on_card)
	TestFixtures.check(res, "16 %s stays open after a click on the MercDave card" % tag,
		on_card.x >= 0.0 and layer.card.visible and panel.is_open() and panel.visible and hits[0] == 0,
		"point %s card %s open %s hits %d" % [on_card, layer.card.visible, panel.is_open(), hits[0]])
	Mercdave.close()
	await TestFixtures.frames(host, 1)
	var away: Array[Rect2] = avoid.duplicate()
	away.append(panel.get_global_rect())
	away.append(opener.get_global_rect())
	var outside: Vector2 = _free_point(area, away, true)
	await _click(host, outside)
	TestFixtures.check(res, "16 %s closes on an outside click and fires popup_hide once" % tag,
		outside.x >= 0.0 and not panel.visible and not panel.is_open() and hits[0] == 1,
		"point %s visible %s hits %d" % [outside, panel.visible, hits[0]])
	opener.pressed.emit()
	await TestFixtures.frames(host, 1)
	_push_escape(host)
	await TestFixtures.frames(host, 1)
	TestFixtures.check(res, "16 %s closes on Esc (popup_hide once) and its frame stays open" % tag,
		not panel.visible and hits[0] == 2 and win.visible and GuiFrameStack.top() == win,
		"visible %s hits %d frame %s" % [panel.visible, hits[0], win.visible])
	opener.pressed.emit()
	await TestFixtures.frames(host, 1)
	var was_open: bool = panel.is_open()
	await _click(host, opener.get_global_rect().get_center())
	await TestFixtures.frames(host, 1)
	TestFixtures.check(res, "16 %s stays closed after a press and release on its opener" % tag,
		was_open and not panel.visible and not panel.is_open() and hits[0] == 3,
		"was %s visible %s hits %d" % [was_open, panel.visible, hits[0]])
	panel.popup_hide.disconnect(count)
	if panel.visible:
		panel.hide()
	await TestFixtures.frames(host, 1)


#Item 6: with a panel open in a frame, the first Esc hides the panel only and the second closes the frame.
static func _case_two_escapes(res: Dictionary, host: Node, win: SubWindow, kit: Dictionary) -> void:
	var panel: DropPanel = kit["panel"] as DropPanel
	(kit["opener"] as BaseButton).pressed.emit()
	await TestFixtures.frames(host, 1)
	var opened: bool = panel.is_open()
	_push_escape(host)
	await TestFixtures.frames(host, 1)
	var first_ok: bool = opened and not panel.visible and win.visible and GuiFrameStack.top() == win
	_push_escape(host)
	await TestFixtures.frames(host, 1)
	TestFixtures.check(res, "16 the first Esc hides the open panel and the second closes its frame",
		first_ok and not win.visible and GuiFrameStack.top() != win,
		"first %s frame %s top %s" % [first_ok, win.visible, GuiFrameStack.top()])


static func _drop_panels(node: Node, out: Array[DropPanel]) -> void:
	if node is DropPanel:
		out.append(node as DropPanel)
	for child: Node in node.get_children():
		_drop_panels(child, out)


#The first grid point of area outside every rect of avoid, and off the MercDave card and markers
#when off_layer is set; (-1, -1) when there is none.
static func _free_point(area: Rect2, avoid: Array[Rect2], off_layer: bool) -> Vector2:
	var y: float = area.position.y + GRID * 0.5
	while y < area.end.y:
		var x: float = area.position.x + GRID * 0.5
		while x < area.end.x:
			var point: Vector2 = Vector2(x, y)
			var clear: bool = not (off_layer and MercdaveLayer.has_point(point))
			for rect: Rect2 in avoid:
				if clear and rect.grow(2.0).has_point(point):
					clear = false
			if clear:
				return point
			x += GRID
		y += GRID
	return Vector2(-1, -1)


#A left press and release at a canvas point, pushed through the viewport; nothing when point is (-1, -1).
static func _click(host: Node, point: Vector2) -> void:
	if point.x < 0.0:
		return
	for down: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		click.position = point
		click.global_position = point
		host.get_viewport().push_input(click, true)
	await TestFixtures.frames(host, 1)


static func _push_escape(host: Node) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	host.get_viewport().push_input(event)
