class_name CoachDialog extends Control

#The Performance Improvement Plan popup: every level-up mode PipDefs knows, grouped and gridded
#three to a row, over the SalaryDialog chrome. A pick only moves the draft; Confirm stays dead
#until the draft differs from the plan in force, and writing it goes through GameState.set_pip_mode
#so a mode whose gate is shut can never be stored. The rows are never spelled out here: they come
#from PipDefs, so a new mode appears with no edit to this screen.

signal confirmed(mode: StringName)
signal cancelled

const HEADER_TEXT: String = "Performance Improvement Plan"
const SUBTITLE_TEXT: String = "Choose how this merc focuses when they level up."
const UNCHANGED_HINT: String = "Pick a different plan to confirm"
const MODULE_SCENE_PATH: String = "res://Scenes/GUI/Mercs/PipModule.tscn"
const TIP_SCENE_PATH: String = "res://Scenes/GUI/Shared/SlotTooltip.tscn"
const BOX_WIDTH: float = 600.0
const COLUMNS: int = 3
const GROUP_SEPARATION: int = 10
const GROUP_ROW_SEPARATION: int = 6
const GRID_SEPARATION: int = 8
const HEADING_SIZE: int = 9
const HEADING_COLOR: Color = Color("#9cc6ef")
const DISABLED_ALPHA: float = 0.4
const BOX_INSET: float = 4.0
const BOX_BORDER: int = 4
const BOX_BG: Color = Color("#1a2b4d")
const BOX_EDGE: Color = Color("#f28c28")
const EDGE_HI: Color = Color("#28447a")
const EDGE_LO: Color = Color("#111c33")
const EDGE_PX: float = 4.0
const CLOSE_INSET: float = 10.0

@onready var backdrop: Panel = $Backdrop
@onready var box: PanelContainer = $Box
@onready var edges: Control = $Box/Edges
@onready var header_label: Label = $Box/Pad/Rows/Head/Header
@onready var name_label: Label = $Box/Pad/Rows/Head/MercName
@onready var subtitle_label: Label = $Box/Pad/Rows/Head/Subtitle
@onready var groups: VBoxContainer = $Box/Pad/Rows/Groups
@onready var cancel_button: BevelButton = $Box/Pad/Rows/Footer/Cancel
@onready var confirm_button: BevelButton = $Box/Pad/Rows/Footer/Confirm
@onready var close_x: Button = $CloseX

#MercView is a RefCounted view model, so the merc arrives through open_for, not the editor.
var merc: MercView = null
var current_mode: StringName = PipDefs.DEFAULT_MODE
var draft_mode: StringName = PipDefs.DEFAULT_MODE

var _modules: Dictionary = {}
var _group_boxes: Dictionary = {}
var _tip: SlotTooltip = null


func _ready() -> void:
	top_level = true
	size = get_viewport().get_visible_rect().size
	header_label.text = HEADER_TEXT
	subtitle_label.text = SUBTITLE_TEXT
	edges.draw.connect(_draw_edges)
	edges.resized.connect(edges.queue_redraw)
	_style_box()
	cancel_button.pressed.connect(press_cancel)
	confirm_button.pressed.connect(press_confirm)
	CloseX.style(close_x, CloseX.SCALE_WINDOW)
	close_x.pressed.connect(press_cancel)
	SubscriptionManager.changed.connect(_on_entitlements_changed)
	_build_groups()
	_build_tip()
	_refresh()
	hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		GuiFrameStack.remove(self)


func open_for(view: MercView) -> void:
	if view == null:
		return
	merc = view
	current_mode = GameState.pip_mode(view.uid)
	draft_mode = current_mode
	size = get_viewport().get_visible_rect().size
	_refresh()
	show()
	_center()
	GuiFrameStack.push(self)


#Moves the draft only. A locked mode is refused here as well as in GameState.
func press_mode(mode: StringName) -> void:
	if not PipDefs.has(mode):
		return
	if not PipDefs.unlocked(mode, SubscriptionManager.entitlements()):
		return
	draft_mode = mode
	_refresh()


func press_confirm() -> void:
	if not confirm_enabled():
		return
	var mode: StringName = draft_mode
	if merc == null or not GameState.set_pip_mode(merc.uid, mode):
		return
	current_mode = mode
	_dismiss()
	confirmed.emit(mode)


func press_cancel() -> void:
	draft_mode = current_mode
	_refresh()
	_dismiss()
	cancelled.emit()


func confirm_enabled() -> bool:
	if draft_mode == current_mode:
		return false
	return PipDefs.unlocked(draft_mode, SubscriptionManager.entitlements())


func modules() -> Array[PipModule]:
	var out: Array[PipModule] = []
	for group: String in PipDefs.groups():
		for mode: StringName in PipDefs.modes_in(group):
			var module: PipModule = module_for(mode)
			if module != null:
				out.append(module)
	return out


func module_for(mode: StringName) -> PipModule:
	return _modules.get(mode, null) as PipModule


func group_box(group: String) -> VBoxContainer:
	return _group_boxes.get(group, null) as VBoxContainer


func group_names() -> Array[String]:
	return PipDefs.groups()


func tooltip() -> SlotTooltip:
	return _tip


#One column of group blocks, each a heading over a three wide grid of modules.
func _build_groups() -> void:
	for group: String in PipDefs.groups():
		var block: VBoxContainer = VBoxContainer.new()
		block.name = node_name_of(group)
		block.add_theme_constant_override("separation", GROUP_ROW_SEPARATION)
		var heading: Label = Label.new()
		heading.name = "Heading"
		heading.text = group
		heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heading.add_theme_color_override("font_color", HEADING_COLOR)
		heading.add_theme_font_size_override("font_size", HEADING_SIZE)
		block.add_child(heading)
		var grid: GridContainer = GridContainer.new()
		grid.name = "Grid"
		grid.columns = COLUMNS
		grid.add_theme_constant_override("h_separation", GRID_SEPARATION)
		grid.add_theme_constant_override("v_separation", GRID_SEPARATION)
		block.add_child(grid)
		groups.add_child(block)
		_group_boxes[group] = block
		for mode: StringName in PipDefs.modes_in(group):
			var module: PipModule = _make_module(mode)
			if module != null:
				grid.add_child(module)
				_modules[mode] = module


func _make_module(mode: StringName) -> PipModule:
	var scene: PackedScene = load(MODULE_SCENE_PATH) as PackedScene
	if scene == null:
		return null
	var module: PipModule = scene.instantiate() as PipModule
	module.name = node_name_of(String(mode))
	module.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	module.picked.connect(press_mode)
	module.hover_started.connect(_show_tip)
	module.hover_ended.connect(_hide_tip)
	return module


func _build_tip() -> void:
	var scene: PackedScene = load(TIP_SCENE_PATH) as PackedScene
	if scene == null:
		return
	_tip = scene.instantiate() as SlotTooltip
	add_child(_tip)


func _show_tip(module: PipModule) -> void:
	if _tip == null or module == null:
		return
	_tip.set_slot(module.group_title(), module.mode_text(), module.description,
		module.foot_text())
	_tip.show_at(module, get_viewport().get_visible_rect())


func _hide_tip() -> void:
	if _tip != null:
		_tip.hide_tip()


func _on_entitlements_changed() -> void:
	if merc != null:
		current_mode = GameState.pip_mode(merc.uid)
		if not PipDefs.unlocked(draft_mode, SubscriptionManager.entitlements()):
			draft_mode = current_mode
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	name_label.text = "" if merc == null else merc.name
	var ent: Dictionary = SubscriptionManager.entitlements()
	for group: String in PipDefs.groups():
		for mode: StringName in PipDefs.modes_in(group):
			var module: PipModule = module_for(mode)
			if module == null:
				continue
			module.set_row(PipDefs.find(mode), ent)
			module.selected = mode == draft_mode
			module.is_current = mode == current_mode
	var live: bool = confirm_enabled()
	confirm_button.disabled = not live
	confirm_button.modulate.a = 1.0 if live else DISABLED_ALPHA
	confirm_button.tooltip_text = "" if live else UNCHANGED_HINT


func _dismiss() -> void:
	_hide_tip()
	hide()
	GuiFrameStack.remove(self)


func _style_box() -> void:
	var base: StyleBoxFlat = box.get_theme_stylebox(&"panel", &"PopupBox") as StyleBoxFlat
	var style: StyleBoxFlat
	if base != null:
		style = base.duplicate()
	else:
		style = StyleBoxFlat.new()
	style.bg_color = BOX_BG
	style.border_width_left = BOX_BORDER
	style.border_width_top = BOX_BORDER
	style.border_width_right = BOX_BORDER
	style.border_width_bottom = BOX_BORDER
	style.border_color = BOX_EDGE
	style.content_margin_left = BOX_INSET
	style.content_margin_top = BOX_INSET
	style.content_margin_right = BOX_INSET
	style.content_margin_bottom = BOX_INSET
	box.add_theme_stylebox_override(&"panel", style)


func _draw_edges() -> void:
	var span: Vector2 = edges.size
	edges.draw_rect(Rect2(0.0, 0.0, span.x, EDGE_PX), EDGE_HI)
	edges.draw_rect(Rect2(0.0, 0.0, EDGE_PX, span.y), EDGE_HI)
	edges.draw_rect(Rect2(0.0, span.y - EDGE_PX, span.x, EDGE_PX), EDGE_LO)
	edges.draw_rect(Rect2(span.x - EDGE_PX, 0.0, EDGE_PX, span.y), EDGE_LO)


func _center() -> void:
	backdrop.offset_bottom = -GuiFrameStack.bottom_reserve
	box.reset_size()
	box.position = Vector2(floorf((size.x - box.size.x) / 2.0),
		floorf((GuiFrameStack.band_height(size.y) - box.size.y) / 2.0))
	box.position.y = maxf(box.position.y, 0.0)
	close_x.size = CloseX.size(CloseX.SCALE_WINDOW)
	close_x.position = box.position + Vector2(box.size.x - CLOSE_INSET - 30.0 - 3.0,
		CLOSE_INSET - 3.0)


#A group or mode name becomes a node name, so a test can reach one by path.
static func node_name_of(text: String) -> String:
	return text.replace(" ", "")


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if GuiFrameStack.top() != self:
		return
	press_cancel()
	get_viewport().set_input_as_handled()
