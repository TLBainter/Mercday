class_name MercdaveTab extends TabButton

#The bottom-bar MercDave tab: the unread count as the badge, pressed (orange) while the card is open,
#the +5 face on hover, and a press toggles the card. Same size open and closed.

const TAB_SIZE: Vector2 = Vector2(52, 36)

@export var face_path: NodePath = ^"Row/Face"

var face: MercdaveFace = null


func _init() -> void:
	super()
	idle_size = TAB_SIZE
	toggle_mode = true
	active_kind = &"orange"


func _ready() -> void:
	super()
	face = get_node_or_null(face_path) as MercdaveFace
	badge_color = GuiColors.AMBER
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	Mercdave.changed.connect(_sync)
	_sync()


func _refresh() -> void:
	super()
	size_flags_vertical = SIZE_SHRINK_CENTER


func _sync() -> void:
	badge = Mercdave.unread.size()
	set_pressed_no_signal(Mercdave.card_open)
	queue_redraw()


func _set_hover(on: bool) -> void:
	if face != null:
		face.hovered = on


func _on_pressed() -> void:
	Mercdave.toggle()
