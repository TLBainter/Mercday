class_name HintCard extends PanelContainer

#The MercDave card: face, title, step and text of the hint Mercdave shows, with Tell Me More, Next
#Hint and Ok (rightmost). The sys_none card is titled Mercdave and shows Ok only. The face shows +5
#while the pointer is over the card.

const TITLE_NONE: String = "Mercdave"
const TITLE_NEW: String = "New: %s"
const STEP: String = "%d of %d"

@onready var face: MercdaveFace = $Row/Face
@onready var title: Label = $Row/Body/Head/Title
@onready var step: Label = $Row/Body/Head/Step
@onready var body: Label = $Row/Body/Text
@onready var tell_more: BevelButton = $Row/Body/Buttons/TellMore
@onready var next_hint: BevelButton = $Row/Body/Buttons/NextHint
@onready var ok: BevelButton = $Row/Body/Buttons/Ok

#The pointer target of the last aim and the number of aims; tests read them since warp_mouse does nothing headless.
var aim_point: Vector2 = Vector2(-1, -1)
var aim_count: int = 0
var _aim_key: Array = []
var _aim_wait: int = 0


func _ready() -> void:
	add_child(TimeHold.new())
	tell_more.pressed.connect(Mercdave.tell_more)
	next_hint.pressed.connect(Mercdave.next_hint)
	ok.pressed.connect(Mercdave.ok)
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	item_rect_changed.connect(_queue_aim)
	set_process(false)
	fill()


#Reads the shown hint from Mercdave; the layer sets the width (344 docked, else 384).
func fill() -> void:
	if not is_node_ready():
		return
	var id: StringName = Mercdave.current
	var none: bool = id == HintBook.SYS_NONE or not HintBook.is_valid(id)
	title.text = TITLE_NONE if none else TITLE_NEW % HintBook.label(id)
	step.visible = not none and Mercdave.step >= 0
	step.text = STEP % [Mercdave.step + 1, Mercdave.step_total]
	var shown: StringName = HintBook.SYS_NONE if none else id
	body.text = HintBook.more(shown) if Mercdave.showing_more else HintBook.text(shown)
	tell_more.visible = not none and HintBook.has_more(id) and not Mercdave.showing_more
	next_hint.visible = Mercdave.has_next()
	reset_size()
	_queue_aim()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_node_ready():
		if not visible:
			face.hovered = false
			_aim_key = []
			set_process(false)


#The first visible of Tell Me More, Next Hint and Ok, the button the pointer jumps to.
func aim_button() -> BevelButton:
	for button: BevelButton in [tell_more, next_hint, ok]:
		if button.visible:
			return button
	return null


#An open, moved or refilled card aims two frames later, once the layout has settled; nothing aims per frame.
func _queue_aim() -> void:
	if not visible:
		return
	_aim_wait = 2
	set_process(true)


func _process(_delta: float) -> void:
	_aim_wait -= 1
	if _aim_wait > 0:
		return
	set_process(false)
	_aim_now()


#Warps the pointer once per new button, card rect, hint or page; a hover animation of the button never re-aims.
func _aim_now() -> void:
	if not is_visible_in_tree():
		return
	var button: BevelButton = aim_button()
	if button == null:
		return
	var key: Array = [button.name, global_position, size, Mercdave.current, Mercdave.showing_more]
	if key == _aim_key:
		return
	_aim_key = key
	aim_count += 1
	aim_point = button.get_global_rect().get_center()
	get_viewport().warp_mouse(aim_point)


#The three buttons pass the mouse (PASS filter), so moving onto one keeps the card hovered.
func _set_hover(on: bool) -> void:
	face.hovered = on and visible
