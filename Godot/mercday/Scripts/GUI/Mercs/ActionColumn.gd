class_name ActionColumn extends VBoxContainer

#One column of the Actions tab: its caption and cost unit over a padded, scrolling list of action rows.

@export var caption: String = "":
	set(text):
		caption = text
		_refresh()
@export var unit: String = "":
	set(text):
		unit = text
		_refresh()

@onready var caption_label: Label = $GroupHead/Caption
@onready var unit_label: Label = $GroupHead/Unit


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	caption_label.text = caption
	unit_label.text = unit
