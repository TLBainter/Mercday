class_name JobProgress extends PanelContainer

#The strip that stands in for a row's due column and a Review dialog's actions while an odd job
#runs on that case: what the crew is doing and how far through the job's days it has come.

const BAR_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/CellBar.tscn")
const BAR_CELLS: int = 12
const CELL_HEIGHT: int = 10
const CELL_GAP: int = 2

@export var caption: String = "":
	set(value):
		caption = value
		_refresh()
@export var cells: int = BAR_CELLS:
	set(value):
		cells = maxi(1, value)
		_refresh()
@export var filled: int = 0:
	set(value):
		filled = maxi(0, value)
		_refresh()
#0 lets the bar spread over the width it is given; anything else pins the cell width.
@export var cell_width: int = 9:
	set(value):
		cell_width = maxi(0, value)
		_refresh()

var caption_label: Label = null
var bar: CellBar = null


func _ready() -> void:
	_build()
	_refresh()


func set_progress(text: String, lit_cells: int, total_cells: int = BAR_CELLS) -> void:
	cells = maxi(1, total_cells)
	filled = lit_cells
	caption = text


func caption_text() -> String:
	return caption_label.text if caption_label != null else ""


func filled_cells() -> int:
	return bar.filled if bar != null else 0


func bar_node() -> CellBar:
	return bar


func _build() -> void:
	if caption_label != null:
		return
	name = "JobProgress"
	add_theme_stylebox_override(&"panel", LegalStyle.styled("legal_cell.tres"))
	var row: HBoxContainer = GuiStyle.hbox(10)
	row.name = "Row"
	caption_label = GuiStyle.label("", GuiStyle.SILK, 10, GuiColors.SKY)
	caption_label.name = "Caption"
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption_label.clip_text = true
	row.add_child(caption_label)
	bar = BAR_SCENE.instantiate() as CellBar
	bar.name = "Bar"
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	add_child(row)


func _refresh() -> void:
	if caption_label == null or bar == null:
		return
	caption_label.text = caption
	bar.cell_height = CELL_HEIGHT
	bar.gap = CELL_GAP
	bar.cell_width = cell_width
	bar.fill_color = GuiColors.SKY
	bar.empty_color = GuiColors.BLUE_LO
	bar.cells = cells
	bar.filled = filled
