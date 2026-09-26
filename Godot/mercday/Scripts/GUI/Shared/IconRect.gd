class_name IconRect extends TextureRect

@export var icon: Texture2D
@export var tint: Color = Color.WHITE
@export var pixel_scale: int = 1


func _ready() -> void:
	_apply()


func set_icon(tex: Texture2D) -> void:
	icon = tex
	_apply()


func _apply() -> void:
	texture = icon
	modulate = tint
	texture_filter = TEXTURE_FILTER_NEAREST
	stretch_mode = STRETCH_KEEP_ASPECT_CENTERED
	if icon != null:
		custom_minimum_size = icon.get_size() * pixel_scale
