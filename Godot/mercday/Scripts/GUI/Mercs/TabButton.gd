class_name TabButton extends Button

#One tab of the Merc Viewer's tab bar. The active tab widens and shows its label; the rest stay
#52 px icon squares. The icon rides an IconRect child so it scales to the prototype's 24 px grid.

const ACTIVE_HEIGHT: int = 44
const IDLE_SIZE: Vector2 = Vector2(52, 38)
const HI_ACTIVE: Color = Color("#ffb266")
const HI_IDLE: Color = Color("#3b6fb6")
const TEXT_ACTIVE: Color = Color("#0a0f1c")
const TEXT_IDLE: Color = Color("#f3ead7")
const HI_PX: float = 4.0
#a tab that carries a label and no icon needs room for the word
const LABEL_PAD: float = 16.0

signal tab_pressed(index: int)

@export var label: String = "":
	set(value):
		label = value
		_refresh()
@export var description: String = "":
	set(value):
		description = value
		_refresh()
@export var active: bool = false:
	set(value):
		active = value
		_refresh()
@export var index: int = 0
#Tabs that carry no icon keep their label up in both states.
@export var label_always: bool = false:
	set(value):
		label_always = value
		_refresh()

@onready var icon_rect: IconRect = $Row/Icon
@onready var text_label: Label = $Row/Text

var _pending_icon: Texture2D = null


func _ready() -> void:
	pressed.connect(_on_pressed)
	expand_icon = false
	if _pending_icon != null:
		icon_rect.set_icon(_pending_icon)
	_refresh()


func set_icon_texture(tex: Texture2D) -> void:
	_pending_icon = tex
	if is_node_ready():
		icon_rect.set_icon(tex)
		_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	text = ""
	text_label.text = label
	text_label.visible = active or label_always
	text_label.add_theme_color_override("font_color", TEXT_ACTIVE if active else TEXT_IDLE)
	icon_rect.visible = _pending_icon != null
	tooltip_text = description
	theme_type_variation = &"TabActive" if active else &"TabIdle"
	size_flags_vertical = SIZE_SHRINK_END
	if active:
		size_flags_horizontal = SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(IDLE_SIZE.x, ACTIVE_HEIGHT)
	elif label_always:
		size_flags_horizontal = SIZE_FILL
		var wide: float = text_label.get_combined_minimum_size().x + LABEL_PAD
		custom_minimum_size = Vector2(maxf(IDLE_SIZE.x, wide), IDLE_SIZE.y)
	else:
		size_flags_horizontal = SIZE_FILL
		custom_minimum_size = IDLE_SIZE
	queue_redraw()


#The prototype's inset top highlight; a stylebox has no inset shadow so the band is drawn.
func _draw() -> void:
	draw_rect(Rect2(HI_PX, HI_PX, size.x - HI_PX * 2.0, HI_PX), HI_ACTIVE if active else HI_IDLE)


func _on_pressed() -> void:
	tab_pressed.emit(index)
