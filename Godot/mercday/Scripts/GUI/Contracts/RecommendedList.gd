class_name RecommendedList extends VBoxContainer

#One "Recommended ..." block of the posting: a caption and the entry names in their listed order.
#A plain entry rides a slot chip; a tradition takes the shared TraditionModule row. The hidden
#bonus behind each entry is never shown.

const MODULE_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/TraditionModule.tscn")
const CHIP_SCENE: PackedScene = preload("res://Scenes/GUI/Mercs/SlotChip.tscn")

@onready var caption_label: Label = $Caption
@onready var scroll: ScrollContainer = $Scroll
@onready var rows: VBoxContainer = $Scroll/Pad/Rows
@onready var empty_label: Label = $Empty

var caption: String = ""
var entries: Array[BonusEntry] = []
var with_sigil: bool = false


func _ready() -> void:
	_refresh()


func set_entries(new_caption: String, new_entries: Array[BonusEntry],
		sigils: bool = false) -> void:
	caption = new_caption
	entries = new_entries
	with_sigil = sigils
	_refresh()


func row_count() -> int:
	return rows.get_child_count() if is_node_ready() else 0


func well() -> ScrollContainer:
	return scroll


#The chip of row i, or null when the row is a tradition module instead.
func chip_at(index: int) -> SlotChip:
	var row: Node = _row_at(index)
	if row is SlotChip:
		return row as SlotChip
	return null


#The tradition module of row i, or null when the row carries a chip.
func module_at(index: int) -> TraditionModule:
	var row: Node = _row_at(index)
	if row is TraditionModule:
		return row as TraditionModule
	return null


func _row_at(index: int) -> Node:
	if not is_node_ready() or index < 0 or index >= rows.get_child_count():
		return null
	return rows.get_child(index)


func names() -> Array[String]:
	var out: Array[String] = []
	for entry: BonusEntry in entries:
		if entry != null:
			out.append(entry.name)
	return out


func _refresh() -> void:
	if not is_node_ready():
		return
	caption_label.text = caption
	for child: Node in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	for entry: BonusEntry in entries:
		if entry == null:
			continue
		rows.add_child(_make_row(entry.name))
	empty_label.visible = entries.is_empty()


func _make_row(entry_name: String) -> Control:
	if with_sigil:
		var module: TraditionModule = MODULE_SCENE.instantiate()
		module.size_mode = TraditionModule.SizeMode.ROW
		module.tradition = entry_name
		module.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		module.tooltip_text = entry_name
		return module
	var chip: SlotChip = CHIP_SCENE.instantiate()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.set_slot(caption, entry_name, "")
	return chip
