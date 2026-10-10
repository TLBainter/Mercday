class_name SectionHead extends HBoxContainer

#A section or list head: the panel title on the left and a count on the right, hidden while empty.

@export var caption: String = "":
	set(text):
		caption = text
		_refresh()
@export var count_text: String = "":
	set(text):
		count_text = text
		_refresh()

@onready var caption_label: Label = $Caption
@onready var count_label: Label = $Count


func _ready() -> void:
	GuiStyle.paint(count_label, GuiStyle.SILK, 11, GuiColors.SKY)
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	caption_label.text = caption
	count_label.text = count_text
	count_label.visible = count_text != ""
