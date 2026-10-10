class_name SendMercsPanel extends CrewPanel

#Left column of an Odd Job crew: a titled dark panel of EnvoySlot rows, or one centred
#FeatureLock when the Odd Jobs feature itself is locked for the guild's plan.

signal slot_pressed(index: int)
signal remove_pressed(index: int)
signal take_me_there(target: Dictionary)

const ENVOY_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/EnvoySlot.tscn")
const SLOT_GAP: int = 10

@export var locked: bool = false:
	set(v):
		locked = v
		_refresh_lock()
@export var tip_kind: String = "Odd Job":
	set(v):
		tip_kind = v
		_apply_tip()
@export var tip_text: String = "Send a merc on this Odd Job.":
	set(v):
		tip_text = v
		_apply_tip()

@onready var rows: VBoxContainer = $Rows
@onready var slots_row: HBoxContainer = $Rows/SlotsRow
@onready var lock_wrap: CenterContainer = $Rows/LockWrap
@onready var lock: FeatureLock = $Rows/LockWrap/FeatureLock

var _slots: Array[EnvoySlot] = []


func _ready() -> void:
	super()
	title_label.text = "Send Mercs"
	slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_row.add_theme_constant_override(&"separation", SLOT_GAP)
	lock.feature = "Odd Jobs"
	lock.plan = "Mercday Enterprise"
	lock.upgrade = "Odd Jobs"
	lock.upgrade_id = "oddjobs"
	lock.entitlement = "oddJobs"
	lock.tier = 1
	lock.tiers = 3
	lock.verb = "use"
	lock.label = "Add Merc"
	lock.height = 40.0
	lock.font_size = 11
	lock.always_visible = true
	lock.min_width = 150.0
	lock.take_me_there.connect(func(target: Dictionary) -> void: take_me_there.emit(target))
	_refresh_lock()


func set_slots(rows_in: Array[Dictionary]) -> void:
	GuiNodes.clear(slots_row)
	_slots.clear()
	for row: Dictionary in rows_in:
		var envoy: EnvoySlot = ENVOY_SCENE.instantiate() as EnvoySlot
		slots_row.add_child(envoy)
		envoy.index = int(row.get("index", 0))
		envoy.merc_id = int(row.get("merc_id", -1))
		envoy.merc_name = str(row.get("merc_name", ""))
		envoy.fit = float(row.get("fit", 0.5))
		envoy.tip_kind = tip_kind
		envoy.tip_text = tip_text
		envoy.slot_pressed.connect(_on_slot_pressed)
		envoy.remove_pressed.connect(_on_remove_pressed)
		_slots.append(envoy)


func slot_count() -> int:
	return _slots.size()


func slot(i: int) -> EnvoySlot:
	if i < 0 or i >= _slots.size():
		return null
	return _slots[i]


func _on_slot_pressed(index: int) -> void:
	slot_pressed.emit(index)


func _on_remove_pressed(index: int) -> void:
	remove_pressed.emit(index)


func _apply_tip() -> void:
	for envoy: EnvoySlot in _slots:
		envoy.tip_kind = tip_kind
		envoy.tip_text = tip_text


func _refresh_lock() -> void:
	if not is_node_ready():
		return
	slots_row.visible = not locked
	lock_wrap.visible = locked
