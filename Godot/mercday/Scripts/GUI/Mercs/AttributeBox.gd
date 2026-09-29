class_name AttributeBox extends PanelContainer

#One attribute square of the Overview tab: the three letter abbreviation beside the current value.
#The maximum only shows in the tooltip (Q16). The number is what the test upgrade sells, so a box
#whose entitlement key is unmet keeps its abbreviation and shows the lock where the number sat.

const ABBREVIATIONS: Dictionary = {
	"cognition": "CGN", "dexterity": "DEX", "vigor": "VGR", "wile": "WIL",
}
const FULL_NAMES: Dictionary = {
	"cognition": "Cognition", "dexterity": "Dexterity", "vigor": "Vigor", "wile": "Wile",
}
const LOCK_BG: Color = Color("#0a0f1c")
const LOCK_RING: Color = Color("#3b4d6e")
const LOCK_RING_PX: int = 2
const LOCK_HEIGHT: float = 24.0

@export var attribute_key: String = "cognition":
	set(value):
		attribute_key = value
		_refresh()
@export var current: int = 0:
	set(value):
		current = value
		_refresh()
@export var maximum: int = 0:
	set(value):
		maximum = value
		_refresh()

@onready var value_box: PanelContainer = $Row/ValueBox
@onready var value_label: Label = $Row/ValueBox/Value
@onready var lock_box: PanelContainer = $Row/LockBox
@onready var lock: FeatureLock = $Row/LockBox/Lock
@onready var abbr_label: Label = $Row/Abbr


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_style_lock_box()
	if not SubscriptionManager.changed.is_connected(_refresh):
		SubscriptionManager.changed.connect(_refresh)
	_refresh()


func _exit_tree() -> void:
	if SubscriptionManager.changed.is_connected(_refresh):
		SubscriptionManager.changed.disconnect(_refresh)


func set_attribute(key: String, entry: Dictionary) -> void:
	attribute_key = key
	current = int(entry.get("current", 0))
	maximum = int(entry.get("max", 0))


func full_name() -> String:
	return String(FULL_NAMES.get(attribute_key, attribute_key))


func lock_key() -> String:
	return String(MercLocks.ATTRIBUTE_KEYS.get(attribute_key, ""))


func is_locked() -> bool:
	var key: String = lock_key()
	if key == "":
		return false
	return MercLocks.locked(key, SubscriptionManager.entitlements())


func _refresh() -> void:
	if not is_node_ready():
		return
	abbr_label.text = String(ABBREVIATIONS.get(attribute_key, ""))
	value_label.text = str(current)
	var key: String = lock_key()
	if key != "":
		MercLocks.apply(lock, key, LOCK_HEIGHT)
	var shut: bool = is_locked()
	value_box.visible = not shut
	lock_box.visible = shut
	tooltip_text = "" if shut else "%s: max %d" % [full_name(), maximum]


func _style_lock_box() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = LOCK_BG
	style.border_width_left = LOCK_RING_PX
	style.border_width_top = LOCK_RING_PX
	style.border_width_right = LOCK_RING_PX
	style.border_width_bottom = LOCK_RING_PX
	style.border_color = LOCK_RING
	lock_box.add_theme_stylebox_override(&"panel", style)
