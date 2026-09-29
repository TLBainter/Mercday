class_name ActionsTab extends VBoxContainer

#Two side by side columns of action rows. ActionData.is_reactive decides the column, the turn cost
#is ap_cost and the reactive one ep_cost; view.actions carries the times used.

const ROW_SCENE: PackedScene = preload("res://Scenes/GUI/Mercs/ActionRow.tscn")

const SORT_OPTIONS: Array[String] = ["Name A-Z", "Most Used", "Highest Cost", "Lowest Cost"]
const SORT_NAME: int = 0
const SORT_USED: int = 1
const SORT_HIGH_COST: int = 2
const SORT_LOW_COST: int = 3
const TURN_UNIT: String = "AP"
const REACTIVE_UNIT: String = "EP"

@onready var sort_button: SortButton = $Head/Sort
@onready var turn_list: VBoxContainer = $Columns/Turn/Scroll/Pad/List
@onready var reactive_list: VBoxContainer = $Columns/Reactive/Scroll/Pad/List
@onready var turn_group: VBoxContainer = $Columns/Turn
@onready var reactive_group: VBoxContainer = $Columns/Reactive
@onready var turn_unit: Label = $Columns/Turn/GroupHead/Unit
@onready var reactive_unit: Label = $Columns/Reactive/GroupHead/Unit

var view: MercView = null


func _ready() -> void:
	sort_button.options = SORT_OPTIONS.duplicate()
	sort_button.selected = SORT_NAME
	sort_button.sort_changed.connect(_on_sort_changed)
	turn_unit.text = unit_text(false)
	reactive_unit.text = unit_text(true)


func set_view(new_view: MercView) -> void:
	view = new_view
	_rebuild()


func turn_rows() -> Array[ActionRow]:
	return _rows_of(turn_list)


func reactive_rows() -> Array[ActionRow]:
	return _rows_of(reactive_list)


func row_count() -> int:
	return turn_rows().size() + reactive_rows().size()


static func unit_text(reactive: bool) -> String:
	return REACTIVE_UNIT if reactive else TURN_UNIT


func action_data(action_name: String) -> ActionData:
	if view == null or view.merc == null or view.merc.action_set == null:
		return null
	for data: ActionData in view.merc.action_set.actions:
		if data != null and data.action_name == action_name:
			return data
	return null


func _rows_of(list: VBoxContainer) -> Array[ActionRow]:
	var out: Array[ActionRow] = []
	if not is_node_ready():
		return out
	for child: Node in list.get_children():
		if child is ActionRow:
			out.append(child as ActionRow)
	return out


func _rebuild() -> void:
	if not is_node_ready():
		return
	_clear(turn_list)
	_clear(reactive_list)
	if view == null:
		return
	var turn: Array[Dictionary] = []
	var reactive: Array[Dictionary] = []
	for row: Dictionary in view.actions:
		var data: ActionData = action_data(String(row.get("name", "")))
		var on_reaction: bool = data != null and data.is_reactive
		var entry: Dictionary = row.duplicate()
		entry["cost"] = _cost_of(data, on_reaction)
		entry["used"] = int(row.get("times_used", 0))
		if on_reaction:
			reactive.append(entry)
		else:
			turn.append(entry)
	var mode: int = sort_button.selected
	_sort(turn, mode)
	_sort(reactive, mode)
	_fill(turn_list, turn, false)
	_fill(reactive_list, reactive, true)


static func _cost_of(data: ActionData, reactive: bool) -> int:
	if data == null:
		return 0
	return data.ep_cost if reactive else data.ap_cost


func _clear(list: VBoxContainer) -> void:
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()


func _fill(list: VBoxContainer, entries: Array[Dictionary], reactive: bool) -> void:
	for entry: Dictionary in entries:
		var row: ActionRow = ROW_SCENE.instantiate()
		list.add_child(row)
		row.set_row(entry, reactive)


func _sort(entries: Array[Dictionary], mode: int) -> void:
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _before(a, b, mode))


static func _before(a: Dictionary, b: Dictionary, mode: int) -> bool:
	if mode == SORT_USED and int(a.get("used", 0)) != int(b.get("used", 0)):
		return int(a.get("used", 0)) > int(b.get("used", 0))
	if mode == SORT_HIGH_COST and int(a.get("cost", 0)) != int(b.get("cost", 0)):
		return int(a.get("cost", 0)) > int(b.get("cost", 0))
	if mode == SORT_LOW_COST and int(a.get("cost", 0)) != int(b.get("cost", 0)):
		return int(a.get("cost", 0)) < int(b.get("cost", 0))
	return String(a.get("name", "")).naturalnocasecmp_to(String(b.get("name", ""))) < 0


func _on_sort_changed(_index: int) -> void:
	_rebuild()
