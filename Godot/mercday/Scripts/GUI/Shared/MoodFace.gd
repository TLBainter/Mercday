class_name MoodFace extends Control

#One atlas face at the integer pixel_scale. filled draws the row 7 art in the level colour;
#unfilled draws its row 8 outline twin in the outline blue. guild true reads the opinion level
#instead of the mood level, for the guild relationship faces.

const INK_COLOR := Color(0.039216, 0.058824, 0.109804, 1)
const DIM_COLOR := Color(0.168627, 0.309804, 0.541176, 1)
#The trimmed face window inside the 16 px cell.
const FACE_ART: Vector2 = Vector2(12, 12)

const MOOD_COLORS: Array[Color] = [
	Color(0.909804, 0.345098, 0.247059, 1),
	Color(0.949020, 0.549020, 0.156863, 1),
	Color(0.949020, 0.701961, 0.239216, 1),
	Color(0.352941, 0.650980, 0.909804, 1),
	Color(0.423529, 0.764706, 0.415686, 1),
]
const MOOD_NAMES: Array[String] = ["Angry", "Frustrated", "Neutral", "Okay", "Happy"]
const GUILD_COLORS: Array[Color] = [
	Color(0.909804, 0.345098, 0.247059, 1),
	Color(0.925490, 0.415686, 0.211765, 1),
	Color(0.937255, 0.486275, 0.184314, 1),
	Color(0.949020, 0.549020, 0.156863, 1),
	Color(0.949020, 0.627451, 0.200000, 1),
	Color(0.949020, 0.701961, 0.239216, 1),
	Color(0.352941, 0.650980, 0.909804, 1),
	Color(0.372549, 0.690196, 0.721569, 1),
	Color(0.392157, 0.725490, 0.549020, 1),
	Color(0.423529, 0.764706, 0.415686, 1),
	Color(0.247059, 0.682353, 0.352941, 1),
]

@export var mood: int = 2:
	set(value):
		mood = value
		_refresh()
@export var filled: bool = true:
	set(value):
		filled = value
		_refresh()
@export var fill_color: Color = Color(0, 0, 0, 0):
	set(value):
		fill_color = value
		_refresh()
@export var guild: bool = false:
	set(value):
		guild = value
		_refresh()
@export var opinion: int = 0:
	set(value):
		opinion = value
		_refresh()
@export var pixel_scale: int = 2:
	set(value):
		pixel_scale = value
		_refresh()


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	custom_minimum_size = FACE_ART * pixel_scale
	queue_redraw()


static func face_id_for(mood_value: int, guild_value: bool, opinion_value: int,
		filled_value: bool) -> String:
	if guild_value:
		return Icons.face_id(clampi(opinion_value, -5, 5), not filled_value)
	return Icons.face_id(Icons.mood_level(mood_value), not filled_value)


static func color_for(mood_value: int, guild_value: bool, opinion_value: int,
		fill_color_value: Color) -> Color:
	if fill_color_value.a > 0.0:
		return fill_color_value
	if guild_value:
		return GUILD_COLORS[clampi(opinion_value, -5, 5) + 5]
	return MOOD_COLORS[clampi(mood_value, 0, MOOD_COLORS.size() - 1)]


func _draw() -> void:
	var id: String = face_id_for(mood, guild, opinion, filled)
	var tint: Color = Icons.FACE_OUTLINE
	if filled:
		tint = color_for(mood, guild, opinion, fill_color)
	Icons.draw(self, id, Vector2.ZERO, pixel_scale, tint, true)
