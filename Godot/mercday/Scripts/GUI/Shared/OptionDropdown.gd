class_name OptionDropdown extends HBoxContainer

#Generic data-driven dropdown: a caption label plus a button that opens a right-aligned popup of
#rows. Each option carries its own enabled flag and refusal reason, so callers never hand this
#control any Period/Scale specific logic; it only ever reads {key, label, enabled, reason}.

signal option_selected(key: StringName)

const ROW_HEIGHT: float = 26.0
const MIN_POPUP_WIDTH: float = 112.0
const DISABLED_ALPHA: float = 0.4
const LOCKED_TOOLTIP: String = "Locked"
const VALID_TEXT: Color = Color("#f3ead7")
const SELECTED_TEXT: Color = Color("#0a0f1c")
const INVALID_TEXT: Color = Color("#4a5a78")
const INVALID_BG: Color = Color("#101a30")
const CARET_COLOR: Color = Color("#f3ead7")

const OPEN_STYLE: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/ButtonBlueHover.tres")
const ROW_VALID: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/PopupRow.tres")
const ROW_SELECTED: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/PopupRowSelected.tres")

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
@onready var menu: PopupPanel = $Menu
@onready var list: VBoxContainer = $Menu/Box/List


func _ready() -> void:
	toggle.pressed.connect(_on_toggle_pressed)
	toggle.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toggle.icon = _caret_icon()
	_refresh()


#Convenience setter matching the plan's set_options(opts) name; options already does the work.
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
	var wanted: Vector2 = menu.get_contents_minimum_size()
	menu.popup(_target_rect(rect, wanted))
	_refresh_button_style()


#Pure geometry: the right-aligned popup rect for a given button rect and wanted content size.
#Split out from open_popup so tests can check the intended target rect directly, since a
#headless DisplayServer can clamp an actual popup Window's reported position and size.
func _target_rect(button_rect: Rect2, wanted: Vector2) -> Rect2i:
	var width: int = maxi(int(MIN_POPUP_WIDTH), int(wanted.x))
	var pos := Vector2i(int(button_rect.end.x) - width, int(button_rect.end.y))
	return Rect2i(pos, Vector2i(width, int(wanted.y)))


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
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()
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
	var fg: Color
	if not enabled:
		style = _invalid_style()
		fg = INVALID_TEXT
		b.tooltip_text = reason
	elif picked:
		style = ROW_SELECTED
		fg = SELECTED_TEXT
	else:
		style = ROW_VALID
		fg = VALID_TEXT
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("hover", style)
	b.add_theme_stylebox_override("pressed", style)
	for key_name: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(key_name, fg)
	b.pressed.connect(_on_row_pressed.bind(key))
	return b


func _refresh_button_style() -> void:
	if not is_node_ready():
		return
	if popup_open():
		toggle.add_theme_stylebox_override("normal", OPEN_STYLE)
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
