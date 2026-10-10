class_name OptionDropdown extends HBoxContainer

#Generic data-driven dropdown: a caption label plus a button that opens a right-aligned popup of
#rows. Each option carries its own enabled flag and refusal reason, so callers never hand this
#control any Period/Scale specific logic; it only ever reads {key, label, enabled, reason}.

signal option_selected(key: StringName)

const ROW_HEIGHT: float = 26.0
const MIN_POPUP_WIDTH: float = 112.0
const DISABLED_ALPHA: float = 0.4
const LOCKED_TOOLTIP: String = "Locked"
const VALID_TEXT: Color = GuiColors.CREAM
const SELECTED_TEXT: Color = GuiColors.INK
const INVALID_TEXT: Color = Color("#4a5a78")
const INVALID_BG: Color = GuiColors.FRAME_BG
const CARET_COLOR: Color = GuiColors.CREAM

const OPEN_STYLE: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/ButtonBlueHover.tres")
const ROW_VALID: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/PopupRow.tres")
const ROW_SELECTED: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/PopupRowSelected.tres")
const ROW_HOVER: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/PopupRowHover.tres")

static var _invalid_cache: StyleBoxFlat = null

@export var label: String = "":
	set(v):
		label = v
		_refresh()
@export var options: Array[Dictionary] = []:
	set(v):
		options = v
		_refresh()
@export var selected: StringName = &"":
	set(v):
		selected = v
		_refresh()
@export var disabled: bool = false:
	set(v):
		disabled = v
		_refresh()

@onready var caption: Label = $Caption
@onready var toggle: Button = $Toggle
@onready var menu: DropPanel = $Menu
@onready var list: VBoxContainer = $Menu/Box/List

#The toggle's normal style while the popup is open; an owner with its own button look sets its hover here.
var open_style: StyleBox = OPEN_STYLE


func _ready() -> void:
	toggle.pressed.connect(_on_toggle_pressed)
	menu.popup_hide.connect(_refresh_button_style)
	toggle.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toggle.icon = _caret_icon()
	_refresh()


#Setter form of the options export, for callers that pass the list in a call.
func set_options(opts: Array[Dictionary]) -> void:
	options = opts


func select(key: StringName, emit: bool = false) -> void:
	var row: Dictionary = _option_for(key)
	if row.is_empty() or not bool(row.get("enabled", true)):
		return
	selected = key
	if emit:
		option_selected.emit(selected)


func open_popup() -> void:
	if disabled:
		return
	_rebuild_rows()
	var rect: Rect2 = toggle.get_global_rect()
	var wanted: Vector2 = menu.get_combined_minimum_size()
	menu.popup(_target_rect(rect, wanted), toggle)
	_refresh_button_style()


#Pure geometry: the right-aligned popup rect for a given button rect and wanted content size.
#Split out from open_popup so tests can check the intended target rect apart from the open
#DropPanel, which DropPanel.popup moves inside the viewport.
func _target_rect(button_rect: Rect2, wanted: Vector2) -> Rect2i:
	var width: float = float(maxi(int(MIN_POPUP_WIDTH), int(wanted.x)))
	return PopupButton.place_below_rect(button_rect, Vector2(width, wanted.y), true)


func close_popup() -> void:
	menu.hide()
	_refresh_button_style()


func popup_open() -> bool:
	return is_node_ready() and menu.visible


func row_for(key: StringName) -> Button:
	for child: Node in list.get_children():
		if child is Button and StringName(child.get_meta("key", &"")) == key:
			return child as Button
	return null


func button_text() -> String:
	return toggle.text


func _option_for(key: StringName) -> Dictionary:
	for opt: Dictionary in options:
		if StringName(opt.get("key", &"")) == key:
			return opt
	return {}


func _on_toggle_pressed() -> void:
	if disabled:
		return
	if popup_open():
		close_popup()
	else:
		open_popup()


func _on_row_pressed(key: StringName) -> void:
	var row: Dictionary = _option_for(key)
	if row.is_empty() or not bool(row.get("enabled", true)):
		return
	close_popup()
	select(key, true)


func _rebuild_rows() -> void:
	GuiNodes.clear(list)
	for opt: Dictionary in options:
		list.add_child(_make_row(opt))


func _make_row(opt: Dictionary) -> Button:
	var key: StringName = StringName(opt.get("key", &""))
	var enabled: bool = bool(opt.get("enabled", true))
	var reason: String = String(opt.get("reason", ""))
	var picked: bool = key == selected
	var b: Button = Button.new()
	b.text = String(opt.get("label", ""))
	b.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.set_meta("key", key)
	var style: StyleBoxFlat
	var hover: StyleBoxFlat
	var fg: Color
	if not enabled:
		style = _invalid_style()
		hover = style
		fg = INVALID_TEXT
		b.tooltip_text = reason
	elif picked:
		style = ROW_SELECTED
		hover = GuiStyle.lifted(ROW_SELECTED)
		fg = SELECTED_TEXT
	else:
		style = ROW_VALID
		hover = ROW_HOVER
		fg = VALID_TEXT
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	for key_name: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(key_name, fg)
	b.pressed.connect(_on_row_pressed.bind(key))
	return b


func _refresh_button_style() -> void:
	if not is_node_ready():
		return
	if popup_open():
		toggle.add_theme_stylebox_override("normal", open_style)
	else:
		toggle.remove_theme_stylebox_override("normal")


func _refresh() -> void:
	if not is_node_ready():
		return
	caption.text = label
	caption.visible = not label.is_empty()
	var row: Dictionary = _option_for(selected)
	toggle.text = String(row.get("label", "")) if not row.is_empty() else ""
	toggle.tooltip_text = LOCKED_TOOLTIP if disabled else ""
	modulate.a = DISABLED_ALPHA if disabled else 1.0
	if disabled and popup_open():
		close_popup()
	if popup_open():
		_rebuild_rows()
	_refresh_button_style()


static func _invalid_style() -> StyleBoxFlat:
	if _invalid_cache == null:
		var s: StyleBoxFlat = StyleBoxFlat.new()
		s.bg_color = INVALID_BG
		s.content_margin_left = 8.0
		s.content_margin_top = 4.0
		s.content_margin_right = 8.0
		s.content_margin_bottom = 4.0
		_invalid_cache = s
	return _invalid_cache


static func _caret_icon() -> ImageTexture:
	return Icons.tinted("caret_down", CARET_COLOR, 2, true)
