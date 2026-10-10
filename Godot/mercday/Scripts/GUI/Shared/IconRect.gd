class_name IconRect extends TextureRect

#One icon on screen. The rect never scales its art: the source is baked to an ImageTexture at the
#integer pixel_scale and TextureRect only centres it, whatever size a container hands the node.
#icon_id names a cell of the shared atlas; icon carries a legacy source texture for the scenes
#that still point at a PNG.

@export var icon: Texture2D:
	set(value):
		icon = value
		refresh()
@export var tint: Color = Color.WHITE:
	set(value):
		tint = value
		refresh()
@export var pixel_scale: int = 1:
	set(value):
		pixel_scale = value
		refresh()
#An atlas id; it wins over icon when both are set.
@export var icon_id: String = "":
	set(value):
		icon_id = value
		refresh()
@export var trimmed: bool = false:
	set(value):
		trimmed = value
		refresh()
@export var mode: StringName = Icons.MODE_PLAIN:
	set(value):
		mode = value
		refresh()
#A non-zero size cuts that window out of the cell instead of the whole cell.
@export var window: Rect2i = Rect2i():
	set(value):
		window = value
		refresh()


func _ready() -> void:
	if icon == null and icon_id == "" and texture != null:
		icon = texture
	_apply()


#Points the rect at a legacy source texture and drops any atlas id.
func set_icon(tex: Texture2D) -> void:
	icon_id = ""
	icon = tex


#Points the rect at an atlas cell; -1 keeps the scale and an empty name keeps the mode.
func set_id(id: String, new_scale: int = -1, new_mode: StringName = &"") -> void:
	if new_scale > 0:
		pixel_scale = new_scale
	if new_mode != &"":
		mode = new_mode
	icon_id = id


#Test probe: sets mode.
func set_mode(m: StringName) -> void:
	mode = m


#Test probe: sets pixel_scale.
func set_pixel_scale(s: int) -> void:
	pixel_scale = s


#The unscaled art behind the rect: the atlas cut, or the legacy texture.
func source() -> Texture2D:
	if icon_id != "":
		if window.size != Vector2i.ZERO:
			return Icons.window(icon_id, window)
		return Icons.tex(icon_id, trimmed)
	return icon


func icon_size() -> Vector2i:
	var src: Texture2D = source()
	if src == null:
		return Vector2i.ZERO
	return Vector2i(src.get_size())


func refresh() -> void:
	if is_node_ready():
		_apply()


func _apply() -> void:
	var src: Texture2D = source()
	texture = Icons.bake(src, maxi(1, pixel_scale), mode)
	modulate = tint
	texture_filter = TEXTURE_FILTER_NEAREST
	stretch_mode = STRETCH_KEEP_CENTERED
	expand_mode = EXPAND_KEEP_SIZE
	custom_minimum_size = Vector2.ZERO if texture == null else texture.get_size()
