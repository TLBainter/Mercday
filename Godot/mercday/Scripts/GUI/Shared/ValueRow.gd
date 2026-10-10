class_name ValueRow extends HBoxContainer

#One caption and value line: a caption with an optional sub line on the left and, on the right,
#either a plain value or a notes amount with its glyph, both in value_color. A positive caption_width
#or value_width fixes that column; a positive bar_cells puts a CellBar between the two that takes
#the spare width.

@export var caption: String = "":
	set(text):
		caption = text
		_refresh()
@export var sub_text: String = "":
	set(text):
		sub_text = text
		_refresh()
@export var value_text: String = "":
	set(text):
		value_text = text
		_refresh()
@export var notes: int = 0:
	set(amount):
		notes = amount
		_refresh()
@export var use_notes: bool = false:
	set(on):
		use_notes = on
		_refresh()
@export var value_color: Color = GuiColors.CREAM:
	set(color):
		value_color = color
		_refresh()
@export var caption_variation: StringName = &"CaptionLabel":
	set(variation):
		caption_variation = variation
		_refresh()
@export var caption_width: float = 0.0:
	set(width):
		caption_width = width
		_refresh()
@export var value_width: float = 0.0:
	set(width):
		value_width = width
		_refresh()
@export var bar_cells: int = 0:
	set(count):
		bar_cells = count
		_refresh()
@export var bar_filled: int = 0:
	set(count):
		bar_filled = count
		_refresh()
@export var bar_color: Color = GuiColors.ORANGE:
	set(color):
		bar_color = color
		_refresh()
@export var bar_empty: Color = GuiColors.BLUE_LO:
	set(color):
		bar_empty = color
		_refresh()

@onready var caption_label: Label = $Texts/Caption
@onready var sub_label: Label = $Texts/Sub
@onready var value_label: Label = $Value
@onready var notes_label: NotesLabel = $Notes
@onready var texts: VBoxContainer = $Texts

var _bar: CellBar = null


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	caption_label.text = caption
	caption_label.theme_type_variation = caption_variation
	sub_label.text = sub_text
	sub_label.visible = sub_text != ""
	value_label.text = value_text
	value_label.add_theme_color_override(&"font_color", value_color)
	value_label.visible = not use_notes
	notes_label.visible = use_notes
	notes_label.amount = notes
	notes_label.value_color = value_color
	var fixed: bool = caption_width > 0.0
	texts.custom_minimum_size.x = caption_width
	texts.size_flags_horizontal = Control.SIZE_FILL if fixed or bar_cells > 0 else Control.SIZE_EXPAND_FILL
	caption_label.clip_text = fixed
	value_label.custom_minimum_size.x = value_width
	notes_label.custom_minimum_size.x = value_width
	if value_width > 0.0:
		notes_label.alignment = BoxContainer.ALIGNMENT_END
	_refresh_bar()


#The bar between the columns, or null when bar_cells is zero.
func bar() -> CellBar:
	return _bar


func _refresh_bar() -> void:
	if bar_cells <= 0:
		if _bar != null:
			_bar.queue_free()
			_bar = null
		return
	if _bar == null:
		_bar = CellBar.new()
		_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(_bar)
		move_child(_bar, texts.get_index() + 1)
	_bar.cells = bar_cells
	_bar.fill_color = bar_color
	_bar.empty_color = bar_empty
	_bar.filled = clampi(bar_filled, 0, bar_cells)
