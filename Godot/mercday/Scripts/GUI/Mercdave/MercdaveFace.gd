class_name MercdaveFace extends MoodFace

#The MercDave monitor: mercdave_screen drawn here, the face drawn by the Art child so the devil
#shader tints the face only. Shows the level Mercdave reports, or +5 while hovered.

const SCREEN_ID: String = "mercdave_screen"
const SCREEN_ART: Vector2 = Vector2(16, 16)
#The face cell sits one art pixel higher on the screen than in its atlas cell.
const FACE_SHIFT: Vector2 = Vector2(0, -1)
const HOVER_FACE: int = 5
const DEVIL_SHADER: Shader = preload("res://Scenes/GUI/Mercdave/DevilNoise.gdshader")

static var _devil_material: ShaderMaterial = null

var hovered: bool = false:
	set(value):
		hovered = value
		_refresh()

var art: Control = Control.new()


func _init() -> void:
	guild = true
	filled = false
	art.name = "Art"
	art.mouse_filter = MOUSE_FILTER_IGNORE
	art.set_anchors_preset(PRESET_FULL_RECT)
	add_child(art, false, Node.INTERNAL_MODE_FRONT)
	art.draw.connect(_on_art_draw)


func _ready() -> void:
	super()
	Mercdave.changed.connect(_refresh)


func level() -> int:
	return HOVER_FACE if hovered else Mercdave.face_level()


static func devil_material() -> ShaderMaterial:
	if _devil_material == null:
		_devil_material = ShaderMaterial.new()
		_devil_material.shader = DEVIL_SHADER
	return _devil_material


func _refresh() -> void:
	if not is_node_ready():
		return
	custom_minimum_size = SCREEN_ART * pixel_scale
	art.material = devil_material() if MercdaveHint.DEVIL_IDS.has(level()) else null
	queue_redraw()
	art.queue_redraw()


func _draw() -> void:
	Icons.draw(self, SCREEN_ID, Vector2.ZERO, pixel_scale, Color.WHITE, true)


#The atlas id Art draws for the shown level.
func face_id() -> String:
	return MercdaveHint.icon_id(level())


#Opinion colour for -5..5, the 0-face amber for unselected, white under the devil shader.
func face_tint() -> Color:
	var shown: int = level()
	if MercdaveHint.DEVIL_IDS.has(shown):
		return Color.WHITE
	return color_for(mood, true, 0 if shown == MercdaveHint.FACE_UNSELECTED else shown, fill_color)


func _on_art_draw() -> void:
	var id: String = face_id()
	Icons.draw(art, id, (Vector2(Icons.offset(id)) + FACE_SHIFT) * pixel_scale, pixel_scale, face_tint(), true)
