class_name TraitCard extends BevelButton

#One card of a trait grid: the trait name over its category, on a panel with a coloured bottom edge.
#The list panel owns the selection, so a press only reports the index back.

const BG_COLOR: Color = GuiColors.ROW_FILL
const HOVER_COLOR: Color = GuiColors.ROW_HOVER
const MIN_HEIGHT: float = 74.0
const ROWS_PAD_Y: float = 20.0

signal card_selected(index: int)

@export var index: int = 0
@export var trait_name: String = "":
	set(value):
		trait_name = value
		_refresh()
@export var category: String = "":
	set(value):
		category = value
		_refresh()
@export var active: bool = false:
	set(value):
		active = value
		_refresh()
@export var accent: Color = GuiColors.ORANGE:
	set(value):
		accent = value
		_refresh()

@onready var rows: VBoxContainer = $Rows
@onready var name_label: Label = $Rows/TraitName
@onready var category_label: Label = $Rows/Category


func _init() -> void:
	pressed_fill = HOVER_COLOR
	click_move = ButtonFx.ClickMove.NONE
	click_shade = ButtonFx.ClickShade.FLASH
	hover_move = ButtonFx.HoverMove.NONE
	hover_shade = ButtonFx.HoverShade.LIGHTEN
	stay_move = ButtonFx.StayMove.NONE
	stay_shade = ButtonFx.StayShade.NONE
	active_move = ButtonFx.HoverMove.NONE
	active_shade = ButtonFx.HoverShade.RING
	_paint_accent()


func _ready() -> void:
	super()
	pressed.connect(_on_pressed)
	rows.minimum_size_changed.connect(_fit_height)
	_refresh()


func set_row(row: Dictionary, i: int) -> void:
	index = i
	trait_name = String(row.get("name", ""))
	category = String(row.get("category", ""))


func _refresh() -> void:
	if not is_node_ready():
		return
	name_label.text = trait_name
	category_label.text = category.to_upper()
	category_label.add_theme_color_override("font_color", accent)
	_paint_accent()
	_fit_height()


func _fit_height() -> void:
	custom_minimum_size.y = maxf(MIN_HEIGHT, rows.get_combined_minimum_size().y + ROWS_PAD_Y)


func fx_active() -> bool:
	return super() or active


#The accent runs along the low band; an active card rings itself in it on both bands.
func _paint_accent() -> void:
	var top: Color = accent if active else BG_COLOR.lightened(0.18)
	set_colors(BG_COLOR, top, accent, text_color)


func _on_pressed() -> void:
	card_selected.emit(index)
