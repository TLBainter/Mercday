class_name MoodFace extends Control

#One 9x9 pixel face. filled true draws the ink outline plus the fill colour on the 'f' pixels;
#filled false draws the outline only, in the dim blue. guild true reads the opinion map instead
#of the mood map, for the guild relationship faces.

const INK_COLOR := Color(0.039216, 0.058824, 0.109804, 1)
const DIM_COLOR := Color(0.168627, 0.309804, 0.541176, 1)

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

const B := "#f#fff#f#"
const N := "#fffffff#"
const E := "#ff#f#ff#"

const MOUTHS: Dictionary = {
	0: ["#ff###ff#", "#f#fff#f#"],
	1: ["#fff#fff#", "#ff#f#ff#"],
	2: ["#ff###ff#", "#fffffff#"],
	3: ["#ff#f#ff#", "#fff#fff#"],
	4: ["#f#fff#f#", "#ff###ff#"],
}

const GUILD_ROWS: Dictionary = {
	-5: [B, "#f##f##f#", "#f#####f#", "#f#fff#f#"],
	-4: [B, E, "#ff###ff#", "#f#fff#f#"],
	-3: [N, E, "#ff###ff#", "#f#fff#f#"],
	-2: [N, E, "#fff#fff#", "#ff#f#ff#"],
	-1: [N, E, "#fff##ff#", "#ff#ffff#"],
	0: [N, E, "#ff###ff#", N],
	1: [N, E, "#ffff#ff#", "#ff##fff#"],
	2: [N, E, "#ff#f#ff#", "#fff#fff#"],
	3: [N, E, "#f#fff#f#", "#ff###ff#"],
	4: [N, E, "#f#####f#", "#ff###ff#"],
	5: ["#ff#f#ff#", "#f#fff#f#", "#f#####f#", "#ff###ff#"],
}

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
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	custom_minimum_size = Vector2(9, 9) * pixel_scale
	queue_redraw()


func current_map() -> PackedStringArray:
	return guild_face_map(opinion) if guild else face_map(mood)


static func face_map(mood_value: int) -> PackedStringArray:
	var m: int = clampi(mood_value, 0, 4)
	var brow: String = B if m == 0 else N
	var mouth: Array = MOUTHS[m]
	return PackedStringArray([
		"..#####..",
		".#fffff#.",
		brow,
		E,
		N,
		mouth[0],
		mouth[1],
		".#fffff#.",
		"..#####..",
	])


static func guild_face_map(opinion_value: int) -> PackedStringArray:
	var op: int = clampi(opinion_value, -5, 5)
	var r: Array = GUILD_ROWS[op]
	return PackedStringArray([
		"..#####..",
		".#fffff#.",
		r[0],
		r[1],
		N,
		r[2],
		r[3],
		".#fffff#.",
		"..#####..",
	])


static func color_for(mood_value: int, guild_value: bool, opinion_value: int,
		fill_color_value: Color) -> Color:
	if fill_color_value.a > 0.0:
		return fill_color_value
	if guild_value:
		return GUILD_COLORS[clampi(opinion_value, -5, 5) + 5]
	return MOOD_COLORS[clampi(mood_value, 0, MOOD_COLORS.size() - 1)]


func _draw() -> void:
	var map: PackedStringArray = current_map()
	var ink: Color = INK_COLOR if filled else DIM_COLOR
	var fill: Color = color_for(mood, guild, opinion, fill_color)
	for row_i: int in range(map.size()):
		var row: String = map[row_i]
		for col_i: int in range(row.length()):
			var ch: String = row[col_i]
			if ch == "#":
				draw_rect(Rect2(col_i * pixel_scale, row_i * pixel_scale, pixel_scale,
					pixel_scale), ink)
			elif ch == "f" and filled:
				draw_rect(Rect2(col_i * pixel_scale, row_i * pixel_scale, pixel_scale,
					pixel_scale), fill)
