class_name ClientFace
extends Control

#The hatched portrait stand-in of a client inside a thin blue frame, square at face_size.

@export var face_size: int = 48:
	set(value):
		face_size = maxi(1, value)
		_refresh()
@export var band: int = 4:
	set(value):
		band = maxi(1, value)
		_refresh()
@export var frame_px: int = 2:
	set(value):
		frame_px = maxi(0, value)
		_refresh()

@onready var fill: TextureRect = $Fill
@onready var frame: Panel = $Frame


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	custom_minimum_size = Vector2(face_size, face_size)
	fill.texture = ClientGlyphs.hatch(face_size, band)
	frame.add_theme_stylebox_override(&"panel", GuiStyle.flat(GuiColors.CLEAR, frame_px, GuiColors.BLUE_HI))
