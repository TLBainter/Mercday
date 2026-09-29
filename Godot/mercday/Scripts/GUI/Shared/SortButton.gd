class_name SortButton extends Button

#Dropdown that picks one of a list of sort options; the button wears the picked option in upper
#case behind a lines glyph and the popup fills the picked row orange.

signal sort_changed(index: int)

const ROW_NORMAL: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/PopupRow.tres")
const ROW_HOVER: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/PopupRowHover.tres")
const ROW_PICKED: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/PopupRowSelected.tres")
const ROW_FONT: FontVariation = preload("res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres")
const ROW_FONT_SIZE: int = 14
const ROW_COLOR: Color = Color("#f3ead7")
const ROW_PICKED_COLOR: Color = Color("#0a0f1c")
#A hovered row darkens and its label turns orange, so the row under the pointer stands out.
const ROW_HOVER_COLOR: Color = Color(0.949020, 0.549020, 0.156863, 1.0)
const GLYPH_COLOR: Color = Color("#f3ead7")
const EMPTY_LABEL: String = "SORT"
const MIN_POPUP_WIDTH: int = 210

@export var options: Array[String] = []:
	set(value):
		options = value
		_refresh()
@export var selected: int = 0:
	set(value):
		selected = value
		_refresh()

@onready var menu: PopupPanel = $Menu
@onready var list: VBoxContainer = $Menu/Box/List


#Both sort popups wear the same rows, so the styling lives here and FilterSortButton calls it.
static func style_row(row: Button, picked: bool) -> void:
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_theme_font_override("font", ROW_FONT)
	row.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	row.add_theme_stylebox_override("normal", ROW_PICKED if picked else ROW_NORMAL)
	row.add_theme_stylebox_override("hover", ROW_PICKED if picked else ROW_HOVER)
	row.add_theme_stylebox_override("pressed", ROW_PICKED if picked else ROW_HOVER)
	var fg: Color = ROW_PICKED_COLOR if picked else ROW_COLOR
	for key: String in ["font_color", "font_pressed_color"]:
		row.add_theme_color_override(key, fg)
	row.add_theme_color_override("font_hover_color", fg if picked else ROW_HOVER_COLOR)


func _ready() -> void:
	icon = GuiGlyphs.lines(GLYPH_COLOR)
	pressed.connect(_on_pressed)
	_refresh()


func pick(i: int) -> void:
	selected = i
	sort_changed.emit(i)


func open_popup() -> void:
	var rect: Rect2 = get_global_rect()
	var wanted: Vector2 = menu.get_contents_minimum_size()
	var width: int = maxi(MIN_POPUP_WIDTH, maxi(int(rect.size.x), int(wanted.x)))
	var pos := Vector2i(int(rect.position.x), int(rect.end.y))
	menu.popup(Rect2i(pos, Vector2i(width, int(wanted.y))))


func popup_open() -> bool:
	return is_node_ready() and menu.visible


func _refresh() -> void:
	if not is_node_ready():
		return
	if options.is_empty() or selected < 0 or selected >= options.size():
		text = EMPTY_LABEL
	else:
		text = options[selected].to_upper()
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for i: int in options.size():
		var b := Button.new()
		b.text = options[i]
		style_row(b, i == selected)
		b.pressed.connect(_on_pick.bind(i))
		list.add_child(b)


func _on_pick(i: int) -> void:
	menu.hide()
	pick(i)


func _on_pressed() -> void:
	open_popup()
