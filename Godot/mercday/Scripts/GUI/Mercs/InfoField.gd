class_name InfoField extends PanelContainer

#A captioned read-only row of the Overview tab. Plain rows print a value string; the salary and the
#level mode rows hand a widget to the slot instead and leave the value blank.

@export var caption: String = "":
	set(value):
		caption = value
		_refresh()
@export var value: String = "":
	set(new_value):
		value = new_value
		_refresh()

@onready var caption_label: Label = $Rows/Caption
@onready var value_label: Label = $Rows/Value
@onready var slot: VBoxContainer = $Rows/Slot


func _ready() -> void:
	_refresh()


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


func _refresh() -> void:
	if not is_node_ready():
		return
	caption_label.text = caption
	value_label.text = value
	value_label.visible = value != ""
	slot.visible = slot.get_child_count() > 0
