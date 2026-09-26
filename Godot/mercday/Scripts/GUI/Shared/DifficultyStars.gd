class_name DifficultyStars extends Control

#Five stars drawn from the icon_star alpha mask; half steps split a star left orange/cream, right empty.

enum Ramp {DIFFICULTY, MATCH}

const STAR_MAP: PackedStringArray = [
	"....#....",
	"...###...",
	"...###...",
	"#########",
	".#######.",
	"..#####..",
	"..#####..",
	".###.###.",
	".##...##.",
]
const EMPTY_COLOR: Color = Color("#1f3560")
const STAR_SIZE_PX: int = 9
const HALF_COLUMNS: int = 5
const GAP_PX: int = 2
const STAR_COUNT: int = 5

@export var rating: float = 0.0:
	set(value):
		rating = value
		_refresh()
@export var star_size: int = 2:
	set(value):
		star_size = value
		_refresh()
@export var ramp: Ramp = Ramp.DIFFICULTY:
	set(value):
		ramp = value
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	custom_minimum_size = Vector2((STAR_COUNT * STAR_SIZE_PX + (STAR_COUNT - 1) * GAP_PX) * star_size,
		STAR_SIZE_PX * star_size)
	tooltip_text = "%.1f" % rating
	queue_redraw()


func _draw() -> void:
	var star_color: Color = color_for(rating, ramp)
	var full: int = full_count(rating)
	var half: bool = has_half(rating)
	for i: int in STAR_COUNT:
		var is_full: bool = i < full
		var is_half: bool = (not is_full) and i == full and half
		var x0: int = i * (STAR_SIZE_PX + GAP_PX) * star_size
		for row: int in STAR_MAP.size():
			var line: String = STAR_MAP[row]
			for col: int in line.length():
				if line[col] != "#":
					continue
				var px: Color = EMPTY_COLOR
				if is_full:
					px = star_color
				elif is_half:
					px = star_color if col < HALF_COLUMNS else EMPTY_COLOR
				draw_rect(Rect2(x0 + col * star_size, row * star_size, star_size, star_size), px)


static func full_count(rating_value: float) -> int:
	return floori(rating_value)


static func has_half(rating_value: float) -> bool:
	return fmod(rating_value, 1.0) >= 0.5 - 0.0001


static func color_for(rating_value: float, ramp_kind: Ramp) -> Color:
	if ramp_kind == Ramp.MATCH:
		return GuiTypes.match_color(rating_value)
	return GuiTypes.difficulty_color(rating_value)
