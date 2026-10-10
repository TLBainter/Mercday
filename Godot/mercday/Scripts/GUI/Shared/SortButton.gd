class_name SortButton extends PopupButton

#Dropdown that picks one of a list of sort options; the button wears the picked option in upper
#case behind a lines glyph and the popup fills the picked row orange.

signal sort_changed(index: int)

const ROW_NORMAL: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/PopupRow.tres")
const ROW_HOVER: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/PopupRowHover.tres")
const ROW_PICKED: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/PopupRowSelected.tres")
const ROW_FONT: FontVariation = GuiStyle.BODY
const ROW_FONT_SIZE: int = 14
const ROW_COLOR: Color = GuiColors.CREAM
const ROW_PICKED_COLOR: Color = GuiColors.INK
#A hovered row darkens and its label turns orange, so the row under the pointer stands out.
const ROW_HOVER_COLOR: Color = GuiColors.ORANGE
const GLYPH_COLOR: Color = GuiColors.CREAM
const EMPTY_LABEL: String = "SORT"

@export var options: Array[String] = []:
	set(value):
		options = value
		_refresh()
@export var selected: int = 0:
	set(value):
		selected = value
		_refresh()

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
	super()
	icon = GuiGlyphs.lines(GLYPH_COLOR)
	_refresh()


func pick(i: int) -> void:
	selected = i
	sort_changed.emit(i)


func _refresh() -> void:
	if not is_node_ready():
		return
	if options.is_empty() or selected < 0 or selected >= options.size():
		text = EMPTY_LABEL
	else:
		text = options[selected].to_upper()
	GuiNodes.clear(list)
	for i: int in options.size():
		var b := Button.new()
		b.text = options[i]
		style_row(b, i == selected)
		b.pressed.connect(_on_pick.bind(i))
		list.add_child(b)


func _on_pick(i: int) -> void:
	close_popup()
	pick(i)
