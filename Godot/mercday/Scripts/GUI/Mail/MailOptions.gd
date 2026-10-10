class_name MailOptions extends HBoxContainer

#The answer buttons of one mail, right-aligned: negative tone left, neutral in the middle, positive right, each led
#by its notes chip (hidden at cost 0). rel never shows on a button, chip or tooltip. Hidden once answered, and on
#a vacation mail whose request is no longer PENDING. The buttons are rebuilt only when the mail changes; the chips
#are repainted on every set_mail, since a later mail of the same bill thread replaces the shared bill amount.

signal chosen(index: int)

const NOTES_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/NotesLabel.tscn")
const BUTTON_SIZE: Vector2 = Vector2(110, 36)
const TONE_KINDS: Dictionary = {-1: &"danger", 0: &"neutral", 1: &"go"}

var mail: MailInstance = null
var _buttons: Array[BevelButton] = []
var _chips: Array[NotesLabel] = []
#The option index of each button, in shown order.
var _indices: Array[int] = []


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override(&"separation", 10)


func set_mail(m: MailInstance) -> void:
	if m != mail:
		mail = m
		_build()
	_paint_chips()
	visible = is_open(m)


#True when the mail still takes an answer here.
static func is_open(m: MailInstance) -> bool:
	if m == null or m.choice >= 0 or MailCatalog.options(m.def_id).is_empty():
		return false
	return m.request == null or m.request.state == VacationRequest.State.PENDING


#Option indices in shown order: tone ascending, then the authored order.
static func order(options: Array) -> Array[int]:
	var out: Array[int] = []
	for i: int in options.size():
		out.append(i)
	out.sort_custom(func(a: int, b: int) -> bool:
		var ta: int = MailEffects.tone((options[a] as Dictionary)["fx"])
		var tb: int = MailEffects.tone((options[b] as Dictionary)["fx"])
		return ta < tb or (ta == tb and a < b))
	return out


func buttons() -> Array[BevelButton]:
	return _buttons.duplicate()


func chips() -> Array[NotesLabel]:
	return _chips.duplicate()


func indices() -> Array[int]:
	return _indices.duplicate()


func _build() -> void:
	GuiNodes.clear(self)
	_buttons.clear()
	_chips.clear()
	_indices.clear()
	if mail == null:
		return
	var options: Array = MailCatalog.options(mail.def_id)
	for i: int in order(options):
		_add(options[i] as Dictionary, i)


func _add(option: Dictionary, index: int) -> void:
	var fx: PackedStringArray = option["fx"]
	var chip: NotesLabel = NOTES_SCENE.instantiate() as NotesLabel
	add_child(chip)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.signed = true
	var button: BevelButton = BevelButton.make(String(option["label"]),
		StringName(TONE_KINDS.get(MailEffects.tone(fx), &"neutral")), BUTTON_SIZE)
	add_child(button)
	button.pressed.connect(_on_pressed.bind(index))
	_buttons.append(button)
	_chips.append(chip)
	_indices.append(index)


func _paint_chips() -> void:
	if mail == null:
		return
	var options: Array = MailCatalog.options(mail.def_id)
	for i: int in _chips.size():
		var cost: int = MailEffects.cost(mail, (options[_indices[i]] as Dictionary)["fx"])
		_chips[i].amount = cost
		_chips[i].value_color = GuiColors.RED if cost < 0 else GuiColors.GREEN
		_chips[i].visible = cost != 0


func _on_pressed(index: int) -> void:
	chosen.emit(index)
