class_name CrewMercPicker extends Control

#Modal merc picker for one Odd Job crew slot: a scrolling list of candidates sorted by fit,
#with an optional remove button when the picked slot already holds a merc. The backdrop click
#is inert by design, matching ConfirmDialog.

signal picked(slot_index: int, id: int)
signal removed(slot_index: int)
signal closed

const BOX_WIDTH: float = 400.0
const BOX_MAX_HEIGHT: float = 540.0
const LIST_HEIGHT: float = 300.0
const BOX_BG: Color = Color("#1a2b4d")
const EDGE_HI: Color = Color("#28447a")
const EDGE_LO: Color = Color("#111c33")
const EDGE_PX: float = 4.0
const BOX_BORDER: int = 4
const BOX_INSET: float = 4.0
const RING_COLOR: Color = Color("#f28c28")
const SHADOW_OFFSET: Vector2 = Vector2(10.0, 10.0)
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.5)
const CLOSE_COLOR: Color = Color("#ff3b2f")
const CLOSE_HOVER: Color = Color("#ff6a55")
const TITLE_COLOR: Color = Color("#f28c28")
const DESC_COLOR: Color = Color("#9cc6ef")
const EMPTY_COLOR: Color = Color("#9cc6ef")
const REMOVE_BG: Color = Color("#2b4f8a")
const REMOVE_HI: Color = Color("#3b6fb6")
const REMOVE_LO: Color = Color("#1f3560")
const REMOVE_TEXT: Color = Color("#e8583f")
const ROW_NAME_COLOR: Color = Color("#f3ead7")
const ROW_PORTRAIT_PX: int = 40
const ROW_GAP: int = 10
const ROW_COL_GAP: int = 6
const CLOSE_SIZE: float = 40.0

const FONT_BOLD: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const MERC_PORTRAIT_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/MercPortrait.tscn")
const FIT_STARS_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/FitStars.tscn")

@export var title: String = "Send a Merc":
	set(v):
		title = v
		if is_node_ready():
			title_label.text = title
@export var pick_desc: String = "Sorted by best fit.":
	set(v):
		pick_desc = v
		if is_node_ready():
			desc_label.text = pick_desc

@onready var backdrop: Panel = $Backdrop
@onready var box: PanelContainer = $Box
@onready var edges: Control = $Box/Edges
@onready var rows: VBoxContainer = $Box/Pad/Rows
@onready var title_label: Label = $Box/Pad/Rows/Title
@onready var desc_label: Label = $Box/Pad/Rows/Desc
@onready var scroll: ScrollContainer = $Box/Pad/Rows/Scroll
@onready var list: VBoxContainer = $Box/Pad/Rows/Scroll/Pad2/List
@onready var empty_label: Label = $Box/Pad/Rows/Empty
@onready var remove_button: BevelButton = $Box/Pad/Rows/RemoveButton
@onready var close_button: Button = $CloseButton

var _slot_index: int = -1
var _rows: Array[Dictionary] = []
var _filled: bool = false
var _row_buttons: Array[Button] = []


func _ready() -> void:
	top_level = true
	hide()
	edges.draw.connect(_draw_edges)
	edges.resized.connect(edges.queue_redraw)
	box.add_theme_stylebox_override(&"panel", _box_style())
	scroll.custom_minimum_size = Vector2(0.0, LIST_HEIGHT)
	close_button.pressed.connect(_on_close)
	remove_button.pressed.connect(_on_remove)
	_style_labels()


func open_for(slot_index: int, rows_in: Array[Dictionary], filled: bool) -> void:
	_slot_index = slot_index
	_rows = rows_in
	_filled = filled
	_rebuild_list()
	remove_button.visible = filled
	show()
	_place_box()
	GuiFrameStack.push(self)


func press_row(id: int) -> void:
	_dismiss()
	picked.emit(_slot_index, id)


func press_remove() -> void:
	_on_remove()


func press_close() -> void:
	_on_close()


func row_count() -> int:
	return _row_buttons.size()


func row_name(i: int) -> String:
	if i < 0 or i >= _rows.size():
		return ""
	return str(_rows[i].get("name", ""))


func row_id(i: int) -> int:
	if i < 0 or i >= _rows.size():
		return -1
	return int(_rows[i].get("id", -1))


func row_fit(i: int) -> float:
	if i < 0 or i >= _rows.size():
		return 0.0
	return float(_rows[i].get("fit", 0.0))


func row_button(i: int) -> Button:
	if i < 0 or i >= _row_buttons.size():
		return null
	return _row_buttons[i]


func desc_text() -> String:
	return desc_label.text


func title_text() -> String:
	return title_label.text


func is_empty_shown() -> bool:
	return empty_label.visible


func remove_visible() -> bool:
	return remove_button.visible


func _on_remove() -> void:
	_dismiss()
	removed.emit(_slot_index)


func _on_close() -> void:
	_dismiss()
	closed.emit()


func _dismiss() -> void:
	hide()
	GuiFrameStack.remove(self)


func _rebuild_list() -> void:
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()
	_row_buttons.clear()
	empty_label.visible = _rows.is_empty()
	scroll.visible = not _rows.is_empty()
	for i: int in _rows.size():
		var row: Dictionary = _rows[i]
		var id: int = int(row.get("id", -1))
		var cand_name: String = str(row.get("name", ""))
		var fit_val: float = float(row.get("fit", 0.5))
		var btn := Button.new()
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(0.0, float(ROW_PORTRAIT_PX) + 12.0)
		btn.add_theme_stylebox_override(&"normal", _row_style(false))
		btn.add_theme_stylebox_override(&"hover", _row_style(true))
		btn.add_theme_stylebox_override(&"pressed", _row_style(true))
		btn.add_theme_stylebox_override(&"focus", _row_style(false))
		btn.tooltip_text = "Match: %s / 5" % _fmt_fit(fit_val)
		var line := HBoxContainer.new()
		line.add_theme_constant_override(&"separation", ROW_GAP)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var portrait: MercPortrait = MERC_PORTRAIT_SCENE.instantiate() as MercPortrait
		portrait.pixel_size = ROW_PORTRAIT_PX
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.merc_uid = id
		portrait.tooltip_text = cand_name
		line.add_child(portrait)
		var col := VBoxContainer.new()
		col.add_theme_constant_override(&"separation", ROW_COL_GAP)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_label := Label.new()
		name_label.text = cand_name
		name_label.add_theme_font_override(&"font", FONT_BOLD)
		name_label.add_theme_font_size_override(&"font_size", 11)
		name_label.add_theme_color_override(&"font_color", ROW_NAME_COLOR)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(name_label)
		var stars: FitStars = FIT_STARS_SCENE.instantiate() as FitStars
		stars.cell = 2
		stars.value = fit_val
		stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(stars)
		line.add_child(col)
		btn.add_child(line)
		btn.pressed.connect(press_row.bind(id))
		list.add_child(btn)
		_row_buttons.append(btn)


func _style_labels() -> void:
	title_label.text = title
	title_label.add_theme_font_override(&"font", FONT_BOLD)
	title_label.add_theme_font_size_override(&"font_size", 14)
	title_label.add_theme_color_override(&"font_color", TITLE_COLOR)
	desc_label.text = pick_desc
	desc_label.add_theme_font_size_override(&"font_size", 13)
	desc_label.add_theme_color_override(&"font_color", DESC_COLOR)
	empty_label.text = "No available mercs."
	empty_label.add_theme_font_size_override(&"font_size", 14)
	empty_label.add_theme_color_override(&"font_color", EMPTY_COLOR)
	remove_button.set_colors(REMOVE_BG, REMOVE_HI, REMOVE_LO, REMOVE_TEXT)
	close_button.text = "X"
	close_button.flat = true
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(CLOSE_SIZE, CLOSE_SIZE)
	close_button.add_theme_font_override(&"font", FONT_BOLD)
	close_button.add_theme_font_size_override(&"font_size", 40)
	close_button.add_theme_color_override(&"font_color", CLOSE_COLOR)
	close_button.add_theme_color_override(&"font_hover_color", CLOSE_HOVER)
	close_button.add_theme_color_override(&"font_pressed_color", CLOSE_HOVER)


func _box_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BOX_BG
	style.border_width_left = BOX_BORDER
	style.border_width_top = BOX_BORDER
	style.border_width_right = BOX_BORDER
	style.border_width_bottom = BOX_BORDER
	style.border_color = RING_COLOR
	style.content_margin_left = BOX_INSET
	style.content_margin_top = BOX_INSET
	style.content_margin_right = BOX_INSET
	style.content_margin_bottom = BOX_INSET
	style.shadow_color = SHADOW_COLOR
	style.shadow_size = 0
	style.shadow_offset = SHADOW_OFFSET
	return style


func _row_style(hover: bool) -> StyleBoxFlat:
	var style_file: String = "crew_picker_row_hover.tres" if hover else "crew_picker_row.tres"
	var path: String = "res://Resources/GUI/Theme/Styles/%s" % style_file
	return (load(path) as StyleBoxFlat).duplicate() as StyleBoxFlat


func _place_box() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	backdrop.offset_bottom = -GuiFrameStack.bottom_reserve
	box.reset_size()
	box.size.x = BOX_WIDTH
	box.size.y = minf(box.size.y, BOX_MAX_HEIGHT)
	box.position = Vector2((view.x - box.size.x) / 2.0,
		(GuiFrameStack.band_height(view.y) - box.size.y) / 2.0)
	box.position.y = maxf(box.position.y, 0.0)
	close_button.position = box.position + Vector2(box.size.x - CLOSE_SIZE / 2.0, -CLOSE_SIZE / 2.0)


func _draw_edges() -> void:
	var span: Vector2 = edges.size
	edges.draw_rect(Rect2(0.0, 0.0, span.x, EDGE_PX), EDGE_HI)
	edges.draw_rect(Rect2(0.0, 0.0, EDGE_PX, span.y), EDGE_HI)
	edges.draw_rect(Rect2(0.0, span.y - EDGE_PX, span.x, EDGE_PX), EDGE_LO)
	edges.draw_rect(Rect2(span.x - EDGE_PX, 0.0, EDGE_PX, span.y), EDGE_LO)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if GuiFrameStack.top() != self:
		return
	_on_close()
	get_viewport().set_input_as_handled()


static func _fmt_fit(v: float) -> String:
	if v == floor(v):
		return str(int(v))
	return str(v)
