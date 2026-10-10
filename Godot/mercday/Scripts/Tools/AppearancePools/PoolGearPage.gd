@tool
class_name PoolGearPage extends PoolPage

#Tradition gear weights: the weapon and armor names as click-to-tick lists, each with a side column holding a
#weight box for every ticked name. Writes gear_weights[category][item_name].

const CATEGORIES: Array[String] = ["weapon", "armor"]
const TICKED: String = "[x] "
const UNTICKED: String = "[ ] "
const SIDE_WIDTH: float = 180.0

var _lists: Dictionary = {}
var _sides: Dictionary = {}


func is_ticked(category: String, item: String) -> bool:
	return float(_weights(category).get(item, 0.0)) > 0.0


func toggle(category: String, item: String) -> void:
	if profile == null:
		return
	var weights: Dictionary = _weights(category)
	if is_ticked(category, item):
		weights.erase(item)
	else:
		weights[item] = PartCell.DEFAULT_WEIGHT
	_put(category, weights)
	_load_category(category)
	edited.emit()


func _build() -> void:
	size_flags_vertical = SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(row)
	for category: String in CATEGORIES:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(column)
		column.add_child(label(category.capitalize()))
		var list := ItemList.new()
		list.size_flags_vertical = SIZE_EXPAND_FILL
		for item: String in AppearancePoolsData.item_names(category):
			var at: int = list.add_item(UNTICKED + item)
			list.set_item_metadata(at, item)
		list.item_clicked.connect(_on_clicked.bind(category))
		column.add_child(list)
		_lists[category] = list
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size.x = SIDE_WIDTH
		scroll.size_flags_vertical = SIZE_EXPAND_FILL
		row.add_child(scroll)
		var side := VBoxContainer.new()
		scroll.add_child(side)
		_sides[category] = side


func _load() -> void:
	for category: String in CATEGORIES:
		_load_category(category)


func _load_category(category: String) -> void:
	var list: ItemList = _lists.get(category) as ItemList
	if list == null:
		return
	for i: int in range(list.item_count):
		var item: String = String(list.get_item_metadata(i))
		list.set_item_text(i, (TICKED if is_ticked(category, item) else UNTICKED) + item)
	var side: VBoxContainer = _sides[category] as VBoxContainer
	for child: Node in side.get_children():
		side.remove_child(child)
		child.queue_free()
	var weights: Dictionary = _weights(category)
	var names: Array = weights.keys()
	names.sort()
	for item: Variant in names:
		if float(weights[item]) <= 0.0:
			continue
		var line := HBoxContainer.new()
		var caption: Label = label(String(item))
		caption.clip_text = true
		caption.size_flags_horizontal = SIZE_EXPAND_FILL
		line.add_child(caption)
		var spin: SpinBox = weight_box(PartCell.WEIGHT_MAX, PartCell.WEIGHT_STEP)
		spin.set_value_no_signal(float(weights[item]))
		spin.value_changed.connect(_on_weight.bind(category, String(item)))
		line.add_child(spin)
		side.add_child(line)


func _weights(category: String) -> Dictionary:
	if profile == null:
		return {}
	return profile.gear_weights.get(category, {}) as Dictionary


func _put(category: String, weights: Dictionary) -> void:
	if weights.is_empty():
		profile.gear_weights.erase(category)
	else:
		profile.gear_weights[category] = weights


func _on_clicked(index: int, _at: Vector2, _mouse: int, category: String) -> void:
	var list: ItemList = _lists[category] as ItemList
	list.deselect_all()
	toggle(category, String(list.get_item_metadata(index)))


func _on_weight(value: float, category: String, item: String) -> void:
	if profile == null:
		return
	var weights: Dictionary = _weights(category)
	weights[item] = value
	_put(category, weights)
	edited.emit()
