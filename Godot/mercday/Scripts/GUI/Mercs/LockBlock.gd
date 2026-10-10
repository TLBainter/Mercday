class_name LockBlock extends PanelContainer

#The slab a gated list leaves behind: the dark block, the "<Feature> hidden" caption and the lock
#that sells the upgrade. One row of MercLocks fills it, so the caption, the plan and the tier are
#never spelled out at the call site, and the block shows itself only while its key is unmet.

const BG: Color = GuiColors.ROW_FILL
const RING: Color = GuiColors.LOCK_RING
const RING_PX: int = 2
const CAPTION_COLOR: Color = GuiColors.MUTED
const CAPTION_SIZE: int = 10

@export var lock_key: String = "":
	set(value):
		lock_key = value
		gate.lock_key = value
		_refresh()
@export var block_height: float = 188.0:
	set(value):
		block_height = value
		_refresh()

@onready var caption: Label = $Rows/Caption
@onready var lock: FeatureLock = $Rows/Lock

var gate: LockGate = LockGate.new()


func _init() -> void:
	gate.lock_height = MercLocks.BLOCK_LOCK_HEIGHT
	add_child(gate, false, Node.INTERNAL_MODE_FRONT)


func _ready() -> void:
	_style()
	caption.add_theme_color_override("font_color", CAPTION_COLOR)
	caption.add_theme_font_size_override("font_size", CAPTION_SIZE)
	gate.changed.connect(refresh)
	_refresh()


func set_key(key: String, height: float) -> void:
	block_height = height
	lock_key = key


func caption_text() -> String:
	return caption.text if is_node_ready() else MercLocks.hidden_text(lock_key)


func is_locked() -> bool:
	return gate.is_locked()


#The block is its own switch: a met key takes it off the page and leaves the real list in view.
func refresh() -> void:
	if is_node_ready():
		visible = gate.is_locked()


func _refresh() -> void:
	if not is_node_ready():
		return
	caption.text = MercLocks.hidden_text(lock_key)
	custom_minimum_size.y = block_height
	gate.fill(lock)
	refresh()


func _style() -> void:
	add_theme_stylebox_override(&"panel", GuiStyle.flat(BG, RING_PX, RING, 8.0))
