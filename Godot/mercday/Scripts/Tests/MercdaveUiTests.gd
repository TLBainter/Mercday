class_name MercdaveUiTests

#MercDave HUD overlay: the bottom-bar tab (size, badge, pressed, hover face), the BottomBar fit and
#MercdaveFace (Stage 2), then the overlay layer cases (Stage 3). Run with the mercdave-ui-tests flag.

const BAR_SCENE: String = "res://Scenes/GUI/HUD/BottomBar.tscn"
const SHADER_PATH: String = "res://Scenes/GUI/Mercdave/DevilNoise.gdshader"
const TAB_PATH: NodePath = ^"Pad/Inset/Row/MercdaveTab"
const BADGE_IDS: int = 5
const OPINION_FACES: Array[int] = [-5, -1, 0, 2, 5]
const DEVIL_FACES: Array[int] = [20, 21, 22, 23]


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_fresh()
	var muted: Array[MercdaveLayer] = _mute_layers(host)
	var bar: BottomBar = await _spawn_bar(host)
	var tab: MercdaveTab = bar.get_node_or_null(TAB_PATH) as MercdaveTab
	TestFixtures.check(res, "bottom bar carries the MercdaveTab after TimeMenu", tab != null
		and tab.get_index() == bar.time_menu().get_index() + 1, "tab %s" % tab)
	if tab == null:
		bar.queue_free()
		_unmute(muted)
		return TestFixtures.summarize(res, "MERCDAVE UI")
	_case_tab_size(res, tab)
	await _case_badge(res, host, tab)
	await _case_pressed(res, host, tab)
	await _case_hover(res, host, tab)
	await _case_bar_fit(res, host, bar, tab)
	await _case_faces(res, host, tab.face)
	bar.queue_free()
	_fresh()
	await MercdaveScopeCases.run(res, host)
	_fresh()
	await MercdaveCardCases.run(res, host)
	_fresh()
	await MercdaveDropCases.run(res, host)
	_fresh()
	await MercdaveTagCases.run(res, host)
	_fresh()
	await MercdaveShieldCases.run(res, host)
	_unmute(muted)
	_fresh()
	return TestFixtures.summarize(res, "MERCDAVE UI")


static func _fresh() -> void:
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	Mercdave.reset_for_tests()


#The layers already in the tree (the boot HUD) hide while the tab cases drive the card, and stay
#shadowed by the newer layer of each spawned HUD in the overlay cases.
static func _mute_layers(host: Node) -> Array[MercdaveLayer]:
	var out: Array[MercdaveLayer] = []
	for node: Node in host.get_tree().get_nodes_in_group(Mercdave.LAYER_GROUP):
		var layer: MercdaveLayer = node as MercdaveLayer
		if layer != null and layer.visible:
			layer.visible = false
			out.append(layer)
	return out


static func _unmute(layers: Array[MercdaveLayer]) -> void:
	for layer: MercdaveLayer in layers:
		if is_instance_valid(layer):
			layer.visible = true


static func _spawn_bar(host: Node) -> BottomBar:
	var bar: BottomBar = (load(BAR_SCENE) as PackedScene).instantiate()
	host.add_child(bar)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	return bar


static func _case_tab_size(res: Dictionary, tab: MercdaveTab) -> void:
	TestFixtures.check(res, "tab is 52x36 and shrinks to the row centre",
		tab.size.is_equal_approx(Vector2(52, 36)) and tab.custom_minimum_size.is_equal_approx(Vector2(52, 36))
			and tab.size_flags_vertical == Control.SIZE_SHRINK_CENTER and not tab.active,
		"size %s min %s flags %d" % [tab.size, tab.custom_minimum_size, tab.size_flags_vertical])
	TestFixtures.check(res, "tab hides the inherited icon and label and holds a MercdaveFace at 2x",
		not tab.icon_rect.visible and not tab.text_label.visible and tab.face != null
			and tab.face.pixel_scale == 2 and tab.face.size.is_equal_approx(Vector2(32, 32))
			and Rect2(Vector2.ZERO, tab.size).encloses(Rect2(tab.face.position + tab.face.get_parent_control().position,
				tab.face.size)),
		"face %s" % (str(tab.face.get_rect()) if tab.face != null else "none"))
	TestFixtures.check(res, "tab is a toggle with the orange active palette",
		tab.toggle_mode and tab.active_kind == &"orange", "toggle %s kind %s" % [tab.toggle_mode, tab.active_kind])


static func _case_badge(res: Dictionary, host: Node, tab: MercdaveTab) -> void:
	await host.get_tree().process_frame
	TestFixtures.check(res, "badge hidden at 0 unread", tab.badge == 0 and not tab.badge_panel.visible,
		"badge %d visible %s" % [tab.badge, tab.badge_panel.visible])
	var ids: Array[StringName] = []
	for id: StringName in HintBook.ids():
		if ids.size() < BADGE_IDS and Mercdave.is_available(id):
			ids.append(id)
	var hidden_ids: Array[StringName] = []
	Mercdave.set_scope(&"mercdave_ui_badge", ids, hidden_ids)
	await host.get_tree().process_frame
	var style: StyleBoxFlat = tab.badge_panel.get_theme_stylebox(&"panel") as StyleBoxFlat
	TestFixtures.check(res, "badge shows every unread hint of the scope in AMBER",
		tab.badge == BADGE_IDS and tab.badge_panel.visible and tab.badge_label.text == str(BADGE_IDS)
			and tab.badge_color == GuiColors.AMBER and style != null and style.bg_color == GuiColors.AMBER
			and not Mercdave.card_open,
		"badge %d visible %s colour %s" % [tab.badge, tab.badge_panel.visible, tab.badge_color])
	_fresh()
	await host.get_tree().process_frame
	TestFixtures.check(res, "badge hides again when the scope empties", not tab.badge_panel.visible,
		"badge %d" % tab.badge)


static func _case_pressed(res: Dictionary, host: Node, tab: MercdaveTab) -> void:
	Mercdave.show_hint(HintBook.ids()[0])
	await host.get_tree().process_frame
	var open_ok: bool = tab.button_pressed and tab.fx_active() and tab._pal()["fill"] == GuiColors.ORANGE
	Mercdave.close()
	await host.get_tree().process_frame
	TestFixtures.check(res, "tab is pressed (orange) while the card is open and released when it closes",
		open_ok and not tab.button_pressed and tab._pal()["fill"] != GuiColors.ORANGE,
		"open %s closed pressed %s" % [open_ok, tab.button_pressed])
	tab.pressed.emit()
	await host.get_tree().process_frame
	var first: bool = Mercdave.card_open and Mercdave.current == HintBook.SYS_NONE and tab.button_pressed
	tab.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "tab press toggles the card open and closed",
		first and not Mercdave.card_open and not tab.button_pressed,
		"first %s open %s pressed %s" % [first, Mercdave.card_open, tab.button_pressed])


static func _case_hover(res: Dictionary, host: Node, tab: MercdaveTab) -> void:
	_fresh()
	tab.mouse_entered.emit()
	await host.get_tree().process_frame
	var on: bool = tab.face.hovered and tab.face.level() == MercdaveFace.HOVER_FACE
	var on_id: String = tab.face.face_id()
	tab.mouse_exited.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "hover shows the +5 face on the tab and leaving restores the Mercdave face",
		on and on_id == "face_p5_o" and not tab.face.hovered and tab.face.level() == Mercdave.face_level(),
		"on %s id %s level %d" % [on, on_id, tab.face.level()])


#Geometric so it still holds after Calendar C3 widens TimeMenu.
static func _case_bar_fit(res: Dictionary, host: Node, bar: BottomBar, tab: MercdaveTab) -> void:
	var row: HBoxContainer = tab.get_parent() as HBoxContainer
	var inset: PanelContainer = bar.inset()
	var closed_x: Array[float] = _child_xs(row)
	var inset_h: float = inset.size.y
	Mercdave.show_hint(HintBook.ids()[0])
	await host.get_tree().process_frame
	var open_x: Array[float] = _child_xs(row)
	var open_size: Vector2 = tab.size
	Mercdave.close()
	await host.get_tree().process_frame
	TestFixtures.check(res, "bottom bar child x positions and the tab size are the same with the card open and closed",
		closed_x == open_x and open_size.is_equal_approx(Vector2(52, 36)) and tab.size.is_equal_approx(open_size),
		"closed %s open %s" % [closed_x, open_x])
	var inner: Rect2 = Rect2(row.global_position, row.size)
	var fits: bool = (bar.size.is_equal_approx(Vector2(1280, 76))
		and row.get_combined_minimum_size().x <= row.size.x + 0.5)
	var last_end: float = inner.position.x
	for child: Node in row.get_children():
		var item: Control = child as Control
		if item == null or not item.visible:
			continue
		var box: Rect2 = item.get_global_rect()
		if box.position.x + 0.5 < last_end or not inner.grow(0.5).encloses(box):
			fits = false
		last_end = box.end.x
	TestFixtures.check(res, "bottom bar row children fit the inset in order without overlap",
		fits, "bar %s row %s min %s" % [bar.size, inner, row.get_combined_minimum_size()])
	var tab_box: Rect2 = tab.get_global_rect()
	TestFixtures.check(res, "tab sits last at the right edge of the row, centred vertically",
		row.get_child(row.get_child_count() - 1) == tab and absf(tab_box.end.x - inner.end.x) <= 0.5
			and absf(tab_box.get_center().y - inner.get_center().y) <= 1.0,
		"tab %s row %s" % [tab_box, inner])
	tab.visible = false
	await host.get_tree().process_frame
	var bare_h: float = inset.size.y
	tab.visible = true
	await host.get_tree().process_frame
	var pad: Control = inset.get_parent_control()
	var need: float = maxf(bare_h, MercdaveTab.TAB_SIZE.y + inset.get_theme_stylebox(&"panel").get_minimum_size().y)
	TestFixtures.check(res, "the tab keeps the bar at 76 px and the inset inside its pad, no taller than the tab needs",
		is_equal_approx(inset_h, need) and is_equal_approx(inset.size.y, inset_h) and is_equal_approx(bar.size.y, 76.0)
			and pad.get_global_rect().grow(0.5).encloses(inset.get_global_rect()),
		"inset with %.1f without %.1f need %.1f bar %.1f" % [inset_h, bare_h, need, bar.size.y])


static func _child_xs(row: HBoxContainer) -> Array[float]:
	var out: Array[float] = []
	for child: Node in row.get_children():
		if child is Control:
			out.append((child as Control).position.x)
	return out


#Headless runs draw no pixels, so the TIME check reads the shader instead of comparing two frames.
static func _case_faces(res: Dictionary, host: Node, face: MercdaveFace) -> void:
	var id: StringName = HintBook.ids()[0]
	var hint: MercdaveHint = HintBook.hint(id)
	var kept: int = hint.face
	var art_ok: bool = (face.art != null and face.art.name == &"Art" and face.art.get_parent() == face
		and face.art.mouse_filter == Control.MOUSE_FILTER_IGNORE and face.art.size.is_equal_approx(face.size))
	TestFixtures.check(res, "face draws the screen itself and the face on its Art child", art_ok,
		"art %s" % face.art)
	var devil_ok: bool = true
	var shared: Material = null
	for level: int in DEVIL_FACES:
		hint.face = level
		Mercdave.show_hint(id)
		await host.get_tree().process_frame
		var mat: ShaderMaterial = face.art.material as ShaderMaterial
		if mat == null or mat.shader == null or mat.shader.resource_path != SHADER_PATH:
			devil_ok = false
		elif shared != null and mat != shared:
			devil_ok = false
		shared = mat
		if face.face_id() != MercdaveHint.DEVIL_IDS[level] or face.material != null:
			devil_ok = false
	TestFixtures.check(res, "devil faces 20-23 put the DevilNoise material on Art only", devil_ok,
		"material %s" % face.art.material)
	face.hovered = true
	var hover_ok: bool = face.art.material == null and face.face_id() == "face_p5_o"
	face.hovered = false
	TestFixtures.check(res, "hover over a devil face drops the shader for +5 and leaving restores it",
		hover_ok and shared != null and face.art.material == shared, "material %s" % face.art.material)
	var code: String = shared.shader.code if shared != null and shared.shader != null else ""
	var uniforms: Dictionary = _uniform_types(shared.shader if shared != null else null)
	TestFixtures.check(res, "DevilNoise parses as a canvas_item shader driven by TIME with purple, red and speed uniforms",
		code.contains("shader_type canvas_item") and code.contains("TIME") and uniforms.get("purple", -1) == TYPE_COLOR
			and uniforms.get("red", -1) == TYPE_COLOR and uniforms.get("speed", -1) == TYPE_FLOAT,
		"uniforms %s" % uniforms)
	var plain_ok: bool = true
	for level: int in OPINION_FACES:
		hint.face = level
		Mercdave.show_hint(id)
		await host.get_tree().process_frame
		if face.art.material != null or face.face_id() != Icons.face_id(level, true):
			plain_ok = false
		if face.face_tint() != MoodFace.color_for(0, true, level, GuiColors.CLEAR):
			plain_ok = false
	TestFixtures.check(res, "opinion faces carry no material and the outline twin in the opinion colour", plain_ok,
		"material %s" % face.art.material)
	hint.face = MercdaveHint.FACE_UNSELECTED
	Mercdave.show_hint(id)
	await host.get_tree().process_frame
	TestFixtures.check(res, "face 30 draws face_unselected_o in amber with no material",
		face.face_id() == "face_unselected_o" and face.face_tint() == GuiColors.AMBER and face.art.material == null,
		"id %s tint %s" % [face.face_id(), face.face_tint()])
	hint.face = kept
	Mercdave.close()


static func _uniform_types(shader: Shader) -> Dictionary:
	var out: Dictionary = {}
	if shader == null:
		return out
	for entry: Dictionary in shader.get_shader_uniform_list():
		out[str(entry["name"])] = int(entry["type"])
	return out
