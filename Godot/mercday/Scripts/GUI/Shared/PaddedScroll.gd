class_name PaddedScroll extends ScrollContainer

#A vertical scroll around a padded item column. The pads and the gap between items are exports, so
#an owner scene sets them on the instance.

@export var pad_top: int = 14:
	set(px):
		pad_top = px
		_refresh()
@export var pad_bottom: int = 14:
	set(px):
		pad_bottom = px
		_refresh()
@export var pad_side: int = 0:
	set(px):
		pad_side = px
		_refresh()
@export var separation: int = 8:
	set(px):
		separation = px
		_refresh()

@onready var pad: MarginContainer = $Pad
@onready var items: VBoxContainer = $Pad/Items


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	pad.add_theme_constant_override(&"margin_top", pad_top)
	pad.add_theme_constant_override(&"margin_bottom", pad_bottom)
	pad.add_theme_constant_override(&"margin_left", pad_side)
	pad.add_theme_constant_override(&"margin_right", pad_side)
	items.add_theme_constant_override(&"separation", separation)
