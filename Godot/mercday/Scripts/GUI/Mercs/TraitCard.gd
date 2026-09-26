class_name TraitCard extends Button

#One card of a trait grid: the trait name over its category, on a panel with a coloured bottom edge.
#The list panel owns the selection, so a press only reports the index back.

const BG_COLOR: Color = Color("#0e1628")
const HOVER_COLOR: Color = Color("#15223d")
const EDGE_PX: int = 4
const ACTIVE_PX: int = 3
const MIN_HEIGHT: float = 74.0
const PAD_Y: float = 20.0

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
@export var accent: Color = Color("#f28c28"):
	set(value):
		accent = value
		_refresh()

@onready var rows: VBoxContainer = $Rows
@onready var name_label: Label = $Rows/TraitName
@onready var category_label: Label = $Rows/Category


func _ready() -> void:
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
	add_theme_stylebox_override("normal", _box(BG_COLOR))
	add_theme_stylebox_override("hover", _box(HOVER_COLOR))
	add_theme_stylebox_override("pressed", _box(HOVER_COLOR))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_fit_height()


func _fit_height() -> void:
	custom_minimum_size.y = maxf(MIN_HEIGHT, rows.get_combined_minimum_size().y + PAD_Y)


func _box(bg: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = accent
	box.border_width_bottom = EDGE_PX
	if active:
		box.border_width_left = ACTIVE_PX
		box.border_width_top = ACTIVE_PX
		box.border_width_right = ACTIVE_PX
	box.content_margin_left = 12.0
	box.content_margin_top = 10.0
	box.content_margin_right = 12.0
	box.content_margin_bottom = 10.0
	return box


func _on_pressed() -> void:
	card_selected.emit(index)
