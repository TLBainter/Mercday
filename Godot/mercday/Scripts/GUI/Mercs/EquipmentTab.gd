class_name EquipmentTab extends ScrollContainer

#Worn, container and carried gear in three named sections with the weight bar under them. A row
#with a named slot lands in that slot; everything else falls into the carried grid in order.

const WORN_SLOTS: Array[String] = ["Primary Hand", "Secondary Hand", "Armor", "Cloak", "Headwear",
	"Gloves", "Belt", "Shoes"]
const CONTAINER_SLOTS: Array[String] = ["Satchel", "Backpack", "Holster 1", "Holster 2",
	"Holster 3", "Holster 4", "Quiver 1", "Quiver 2"]
const CARRIED_FORMAT: String = "%s %d"
const CARRIED_SLOTS: int = 16
const QUIVER_KEY: String = "Quiver"
const QUIVER_FIRST: int = 6
const QUIVER_COUNT: int = 2
const SLOT_COUNT: int = 32

@onready var worn_grid: GridContainer = $Pad/Rows/TopRow/Worn/Grid
@onready var container_grid: GridContainer = $Pad/Rows/TopRow/Containers/Grid
@onready var carried_grid: GridContainer = $Pad/Rows/Carried/Grid
@onready var weight_bar: WeightBar = $Pad/Rows/Weight

var view: MercView = null
var dropped: int = 0


func _ready() -> void:
	_name_slots()


func set_view(new_view: MercView) -> void:
	view = new_view
	if not is_node_ready() or view == null:
		return
	dropped = 0
	for slot: EquipSlot in slots():
		slot.item_name = ""
	var quiver: int = 0
	var carried: int = 0
	for row: Dictionary in view.equipment:
		var key: String = String(row.get("slot", ""))
		var target: EquipSlot = _named_slot(key)
		if key == QUIVER_KEY and quiver < QUIVER_COUNT:
			target = container_slots()[QUIVER_FIRST + quiver]
			quiver += 1
		if target != null and target.is_filled():
			target = null
		if target == null:
			if carried >= CARRIED_SLOTS:
				dropped += 1
				continue
			target = carried_slots()[carried]
			carried += 1
		target.item_name = String(row.get("name", ""))
	weight_bar.capacity = maxf(1.0, view.weight_limit)
	weight_bar.current_wt = view.weight


func worn_slots() -> Array[EquipSlot]:
	return _slots_of(worn_grid)


func container_slots() -> Array[EquipSlot]:
	return _slots_of(container_grid)


func carried_slots() -> Array[EquipSlot]:
	return _slots_of(carried_grid)


func slots() -> Array[EquipSlot]:
	var out: Array[EquipSlot] = worn_slots()
	out.append_array(container_slots())
	out.append_array(carried_slots())
	return out


func slot_count() -> int:
	return slots().size()


func filled_count() -> int:
	var total: int = 0
	for slot: EquipSlot in slots():
		if slot.is_filled():
			total += 1
	return total


func _slots_of(grid: GridContainer) -> Array[EquipSlot]:
	var out: Array[EquipSlot] = []
	if not is_node_ready():
		return out
	for child: Node in grid.get_children():
		if child is EquipSlot:
			out.append(child as EquipSlot)
	return out


func _name_slots() -> void:
	var worn: Array[EquipSlot] = worn_slots()
	for i: int in worn.size():
		worn[i].caption = WORN_SLOTS[i]
	var held: Array[EquipSlot] = container_slots()
	for i: int in held.size():
		held[i].caption = CONTAINER_SLOTS[i]
		held[i].container = true
	var carried: Array[EquipSlot] = carried_slots()
	for i: int in carried.size():
		carried[i].caption = CARRIED_FORMAT % [EquipSlot.CARRIED_CAPTION, i + 1]


func _named_slot(key: String) -> EquipSlot:
	var i: int = WORN_SLOTS.find(key)
	return worn_slots()[i] if i >= 0 else null
