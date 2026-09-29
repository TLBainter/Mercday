class_name InfoField extends PanelContainer

#A captioned read-only row of the Overview tab. Plain rows print a value string; the salary and the
#level mode rows hand a widget to the slot instead and leave the value blank. A row whose
#entitlement key is unmet keeps its caption and shows the lock where its value would read.

const LOCK_HEIGHT: float = 20.0

@export var caption: String = "":
	set(value):
		caption = value
		_refresh()
@export var value: String = "":
	set(new_value):
		value = new_value
		_refresh()
#The MercLocks key that gates the value, or "" for a row every plan may read.
@export var lock_key: String = "":
	set(value):
		lock_key = value
		_refresh()

@onready var caption_label: Label = $Rows/Caption
@onready var value_label: Label = $Rows/Value
@onready var slot: VBoxContainer = $Rows/Slot
@onready var lock: FeatureLock = $Rows/Lock


func _ready() -> void:
	if not SubscriptionManager.changed.is_connected(_refresh):
		SubscriptionManager.changed.connect(_refresh)
	_refresh()


func _exit_tree() -> void:
	if SubscriptionManager.changed.is_connected(_refresh):
		SubscriptionManager.changed.disconnect(_refresh)


func set_field(new_caption: String, new_value: String) -> void:
	caption = new_caption
	value = new_value


func set_value_color(color: Color) -> void:
	if is_node_ready():
		value_label.add_theme_color_override("font_color", color)


func add_widget(node: Control) -> void:
	if not is_node_ready():
		return
	slot.add_child(node)
	slot.visible = true


func value_text() -> String:
	return value_label.text if is_node_ready() else value


func is_locked() -> bool:
	if lock_key == "":
		return false
	return MercLocks.locked(lock_key, SubscriptionManager.entitlements())


func _refresh() -> void:
	if not is_node_ready():
		return
	caption_label.text = caption
	var shut: bool = is_locked()
	value_label.text = value
	value_label.visible = value != "" and not shut
	if lock_key != "":
		MercLocks.apply(lock, lock_key, LOCK_HEIGHT)
	lock.visible = shut
	slot.visible = slot.get_child_count() > 0 and not shut
