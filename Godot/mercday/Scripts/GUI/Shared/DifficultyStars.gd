class_name DifficultyStars extends Control

#Five atlas stars. star_size is the integer atlas scale, so a star is 16 px at 1 and 32 px at 2;
#half steps take the left eight columns of the set star and the right eight of the unused one.

enum Ramp {DIFFICULTY, MATCH}

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
@export var empty_color: Color = Icons.UNUSED_STAR:
	set(value):
		empty_color = value
		_refresh()


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	custom_minimum_size = Vector2(Icons.stars_width(star_size), Icons.CELL * star_size)
	tooltip_text = "%.1f" % rating
	queue_redraw()


func _draw() -> void:
	Icons.draw_stars(self, Vector2.ZERO, star_size, rating, ramp == Ramp.MATCH, empty_color,
		Icons.STAR_GAP)


static func full_count(rating_value: float) -> int:
	return floori(rating_value)


static func has_half(rating_value: float) -> bool:
	return fmod(rating_value, 1.0) >= 0.5 - 0.0001


static func color_for(rating_value: float, ramp_kind: Ramp) -> Color:
	return Icons.star_color(rating_value, ramp_kind == Ramp.MATCH)
