class_name LockBlock extends PanelContainer

#The slab a gated list leaves behind: the dark block, the "<Feature> hidden" caption and the lock
#that sells the upgrade. One row of MercLocks fills it, so the caption, the plan and the tier are
#never spelled out at the call site, and the block shows itself only while its key is unmet.

const BG: Color = Color("#0e1628")
const RING: Color = Color("#3b4d6e")
const RING_PX: int = 2
const CAPTION_COLOR: Color = Color("#5e7699")
const CAPTION_SIZE: int = 10
const LOCK_HEIGHT: float = 24.0

@export var lock_key: String = "":
	set(value):
		lock_key = value
		_refresh()
@export var block_height: float = 188.0:
	set(value):
		block_height = value
		_refresh()

@onready var caption: Label = $Rows/Caption
@onready var lock: FeatureLock = $Rows/Lock


func _ready() -> void:
	_style()
	caption.add_theme_color_override("font_color", CAPTION_COLOR)
	caption.add_theme_font_size_override("font_size", CAPTION_SIZE)
	if not SubscriptionManager.changed.is_connected(refresh):
		SubscriptionManager.changed.connect(refresh)
	_refresh()


func _exit_tree() -> void:
	if SubscriptionManager.changed.is_connected(refresh):
		SubscriptionManager.changed.disconnect(refresh)


func set_key(key: String, height: float) -> void:
	block_height = height
	lock_key = key


func caption_text() -> String:
	return caption.text if is_node_ready() else MercLocks.hidden_text(lock_key)


func is_locked() -> bool:
	return MercLocks.locked(lock_key, SubscriptionManager.entitlements())


#The block is its own switch: a met key takes it off the page and leaves the real list in view.
func refresh() -> void:
	if is_node_ready():
		visible = is_locked()


func _refresh() -> void:
	if not is_node_ready():
		return
	caption.text = MercLocks.hidden_text(lock_key)
	custom_minimum_size.y = block_height
	MercLocks.apply(lock, lock_key, LOCK_HEIGHT)
	refresh()


func _style() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BG
	style.border_width_left = RING_PX
	style.border_width_top = RING_PX
	style.border_width_right = RING_PX
	style.border_width_bottom = RING_PX
	style.border_color = RING
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	add_theme_stylebox_override(&"panel", style)
