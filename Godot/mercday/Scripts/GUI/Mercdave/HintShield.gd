class_name HintShield extends Control

#The input shield of an open MercDave card: covers the screen under the card, so a click outside closes the card and
#reaches nothing beneath, Escape closes the card only, and keyboard focus returns to its owner on close.

var card: Control = null
var _prior: Control = null


func _ready() -> void:
	focus_mode = FOCUS_ALL
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false
	set_process_input(false)
	card = get_node("../Card") as Control
	card.visibility_changed.connect(_sync)
	_sync()


func _sync() -> void:
	var on: bool = card.visible
	if on == visible:
		return
	visible = on
	mouse_filter = MOUSE_FILTER_STOP if on else MOUSE_FILTER_IGNORE
	set_process_input(on)
	if on:
		_prior = get_viewport().gui_get_focus_owner()
		grab_focus()
		return
	if has_focus():
		release_focus()
	if is_instance_valid(_prior) and _prior.is_visible_in_tree():
		_prior.grab_focus()
	_prior = null


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		Mercdave.close()


func _input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	Mercdave.close()
