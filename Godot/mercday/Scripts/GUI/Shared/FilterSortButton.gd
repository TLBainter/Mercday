class_name FilterSortButton extends Button

#Combined sort and filter dropdown: two columns of pickable options under one button. The rows
#wear the sort popup's look, so the picked row in either column reads as an orange block.

signal changed(sort: int, filter: int)

const GLYPH_COLOR: Color = Color("#f3ead7")

@export var sort_options: Array[String] = []:
	set(value):
		sort_options = value
		_refresh()
@export var filter_options: Array[String] = []:
	set(value):
		filter_options = value
		_refresh()
@export var sort_index: int = 0:
	set(value):
		sort_index = value
		_refresh()
@export var filter_index: int = 0:
	set(value):
		filter_index = value
		_refresh()

@onready var menu: PopupPanel = $Menu
@onready var sort_list: VBoxContainer = $Menu/Columns/SortColumn
@onready var filter_list: VBoxContainer = $Menu/Columns/FilterColumn


func _ready() -> void:
	icon = GuiGlyphs.lines(GLYPH_COLOR)
	pressed.connect(_on_pressed)
	_refresh()


func pick_sort(i: int) -> void:
	sort_index = i
	changed.emit(sort_index, filter_index)


func pick_filter(i: int) -> void:
	filter_index = i
	changed.emit(sort_index, filter_index)


func set_selection(sort: int, filter: int) -> void:
	sort_index = sort
	filter_index = filter


func _refresh() -> void:
	if not is_node_ready():
		return
	_fill(sort_list, sort_options, sort_index, pick_sort)
	_fill(filter_list, filter_options, filter_index, pick_filter)


func _fill(column: VBoxContainer, opts: Array[String], index: int, target: Callable) -> void:
	for i: int in range(column.get_child_count() - 1, 0, -1):
		var child: Node = column.get_child(i)
		column.remove_child(child)
		child.queue_free()
	for i: int in opts.size():
		var b := Button.new()
		b.text = opts[i]
		SortButton.style_row(b, i == index)
		b.pressed.connect(target.bind(i))
		column.add_child(b)


func _on_pressed() -> void:
	var rect: Rect2 = get_global_rect()
	var wanted: Vector2 = menu.get_contents_minimum_size()
	var width: int = maxi(int(rect.size.x), int(wanted.x))
	var pos := Vector2i(int(rect.position.x), int(rect.end.y))
	menu.popup(Rect2i(pos, Vector2i(width, int(wanted.y))))
