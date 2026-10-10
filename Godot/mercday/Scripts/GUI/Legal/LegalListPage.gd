class_name LegalListPage extends VBoxContainer

#The shared body of a Legal tab that lists one row per record: the orange head block, the scroll
#that holds the rows and the pool that grows and trims them. A page builds its own layout from
#these parts and supplies only its records, its row scene and what each new row connects to.

@export var row_scene: PackedScene = null
@export var title: String = ""

var head_label: Label = null
var scroll: ScrollContainer = null
var list: BoxContainer = null


func _ready() -> void:
	_build()
	refresh()


#Grows or trims the children of parent to count instances of scene and returns the ones it made,
#so a caller names and connects only its new rows. A trimmed row leaves the tree at once.
static func sync_pool(parent: Node, count: int, scene: PackedScene) -> Array[Node]:
	var made: Array[Node] = []
	while parent.get_child_count() > count:
		var last: Node = parent.get_child(parent.get_child_count() - 1)
		parent.remove_child(last)
		last.queue_free()
	while parent.get_child_count() < count:
		var row: Node = scene.instantiate()
		parent.add_child(row)
		made.append(row)
	return made


func rows() -> Array[Node]:
	if list == null:
		return []
	return list.get_children()


func row_count() -> int:
	return list.get_child_count() if list != null else 0


func row_at(i: int) -> Node:
	if list == null or i < 0 or i >= list.get_child_count():
		return null
	return list.get_child(i)


func row_for(id: int) -> LegalRow:
	for child: Node in rows():
		var found: LegalRow = child as LegalRow
		if found != null and found.row_id() == id:
			return found
	return null


func press_review(id: int) -> void:
	var found: LegalRow = row_for(id)
	if found != null:
		found.press_review()


func head_text() -> String:
	return head_label.text if head_label != null else ""


func refresh() -> void:
	if list == null:
		return
	var data: Array = _row_data()
	for made: Node in sync_pool(list, data.size(), row_scene):
		_new_row(made as Control)
	for i: int in range(data.size()):
		_fill_row(list.get_child(i), data[i])


func _build() -> void:
	pass


func _row_data() -> Array:
	return []


func _fill_row(_row: Node, _data: Variant) -> void:
	pass


#A new row fills the list across its width, or a strip down its height.
func _new_row(row: Control) -> void:
	if list is HBoxContainer:
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL


#The page title in orange pixel type over the line the page passes in.
func _head_block(sub: Control) -> VBoxContainer:
	var box: VBoxContainer = GuiStyle.vbox(4)
	box.name = "Head"
	head_label = GuiStyle.label(title, GuiStyle.SILK_BOLD, 16, GuiColors.ORANGE)
	box.add_child(head_label)
	box.add_child(sub)
	return box


#The scroll and the row box inside it: a vertical list, or a strip that scrolls sideways. A page
#that pads its rows passes the MarginContainer that goes between the two.
func _row_scroll(sideways: bool, gap: int, pad: MarginContainer = null) -> ScrollContainer:
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if sideways:
		scroll.name = "Strip"
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		list = GuiStyle.hbox(gap)
		list.name = "Cards"
		list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		scroll.name = "List"
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		list = GuiStyle.vbox(gap)
		list.name = "Rows"
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if pad == null:
		scroll.add_child(list)
	else:
		#The pad takes the list's place as the scroll's child, so it inherits the expand flags.
		pad.size_flags_horizontal = list.size_flags_horizontal
		pad.size_flags_vertical = list.size_flags_vertical
		pad.add_child(list)
		scroll.add_child(pad)
	return scroll
