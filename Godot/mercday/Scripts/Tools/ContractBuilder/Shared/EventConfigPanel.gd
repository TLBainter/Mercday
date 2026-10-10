@tool
class_name EventConfigPanel extends VBoxContainer

#Page 4's Event Config rows for one event from EventConfig.FIELDS: a slider per multiplier, a radio row per choice (D76).
#show_event stays silent; a slider move or a choice button press emits changed once. Choice buttons keep the options order.

signal changed

const BUTTON_SCENE: PackedScene = preload("res://Scenes/Tools/Shared/ToolBevelButton.tscn")
const CAPTION_WIDTH: float = 150.0
const ROW_HEIGHT: float = 30.0
const ROW_GAP: int = 10
const ITEM_GAP: int = 8
const VALUE_WIDTH: float = 50.0
const SLIDER_SIZE: Vector2 = Vector2(240.0, 21.0)
const CHOICE_SIZE: Vector2 = Vector2(110.0, 30.0)
const NO_FIELDS_TEXT: String = "No options for %s. Set Time and Consequence."

var _event: String = ""
var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}
var _buttons: Dictionary = {}
var _choices: Dictionary = {}


func _init() -> void:
	add_theme_constant_override(&"separation", ROW_GAP)


#A blank event shows no rows; a value the cell lacks or cannot hold shows the field default.
func show_event(event: String, cell: String) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_sliders.clear()
	_value_labels.clear()
	_buttons.clear()
	_choices.clear()
	_event = event
	if _event == "":
		return
	var fields: Array[Dictionary] = EventConfig.fields(_event)
	if fields.is_empty():
		var note: Label = _label(NO_FIELDS_TEXT % _event, &"DescriptionLabel")
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(note)
		return
	for field: Dictionary in fields:
		if String(field["kind"]) == EventConfig.KIND_MULTIPLIER:
			_add_multiplier(field, cell)
		else:
			_add_choice(field, cell)


#The cell the widgets show, keys in EventConfig.keys order; "" when the event has no fields.
func config() -> String:
	var values: Dictionary = {}
	for key: String in _sliders:
		values[key] = EventConfig.format_number((_sliders[key] as ToolPixelSlider).value)
	for key: String in _choices:
		values[key] = String(_choices[key])
	return EventConfig.compose(values, EventConfig.keys(_event))


func has_fields() -> bool:
	return not _sliders.is_empty() or not _buttons.is_empty()


func event_name() -> String:
	return _event


func slider(key: String) -> ToolPixelSlider:
	return _sliders.get(key, null) as ToolPixelSlider


func button(key: String, option: String) -> ToolBevelButton:
	var row: Dictionary = _buttons.get(key, {})
	return row.get(option, null) as ToolBevelButton


func _add_multiplier(field: Dictionary, cell: String) -> void:
	var key: String = String(field["key"])
	var row: HBoxContainer = _row(String(field["label"]))
	var low: float = float(field["min"])
	var high: float = float(field["max"])
	var stride: float = float(field["step"])
	var marks: Array[float] = []
	for s: int in range(roundi((high - low) / stride) + 1):
		marks.append(low + stride * s)
	var made: ToolPixelSlider = ToolPixelSlider.make()
	made.step = stride
	made.min_value = low
	made.max_value = high
	made.markers = marks
	made.custom_minimum_size = SLIDER_SIZE
	made.size_flags_horizontal = Control.SIZE_FILL
	made.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	made.set_value_silent(EventConfig.multiplier_value(_event, key, cell))
	made.value_changed.connect(_on_slider_moved.bind(key))
	row.add_child(made)
	var shown: Label = _label("x" + EventConfig.format_number(made.value), &"DescriptionLabel")
	shown.custom_minimum_size = Vector2(VALUE_WIDTH, ROW_HEIGHT)
	shown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(shown)
	_sliders[key] = made
	_value_labels[key] = shown


func _add_choice(field: Dictionary, cell: String) -> void:
	var key: String = String(field["key"])
	var row: HBoxContainer = _row(String(field["label"]))
	var group: ButtonGroup = ButtonGroup.new()
	var picked: String = EventConfig.choice_value(_event, key, cell)
	var made: Dictionary = {}
	for option: String in field["options"]:
		var radio: ToolBevelButton = BUTTON_SCENE.instantiate() as ToolBevelButton
		radio.text = option.left(1).to_upper() + option.substr(1)
		radio.kind = &"blue"
		radio.active_kind = &"orange"
		radio.min_size = CHOICE_SIZE
		radio.custom_minimum_size = CHOICE_SIZE
		radio.toggle_mode = true
		radio.button_group = group
		radio.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		radio.button_pressed = option == picked
		radio.toggled.connect(_on_choice_toggled.bind(key, option))
		row.add_child(radio)
		made[option] = radio
	_buttons[key] = made
	_choices[key] = picked


func _row(caption: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	row.add_theme_constant_override(&"separation", ITEM_GAP)
	add_child(row)
	var label: Label = _label(caption, &"CaptionLabel")
	label.custom_minimum_size = Vector2(CAPTION_WIDTH, ROW_HEIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return row


static func _label(caption: String, variation: StringName) -> Label:
	var label: Label = Label.new()
	label.text = caption
	label.theme_type_variation = variation
	return label


func _on_slider_moved(new_value: float, key: String) -> void:
	(_value_labels[key] as Label).text = "x" + EventConfig.format_number(new_value)
	changed.emit()


#A click on the pressed button toggles it on again and counts as a press too, so it rewrites a bad loaded value (D76).
func _on_choice_toggled(now_on: bool, key: String, option: String) -> void:
	if not now_on:
		return
	_choices[key] = option
	changed.emit()
