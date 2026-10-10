class_name Stars extends Control

#Five atlas stars. star_px is the integer atlas scale, so a star is 16 px at 1 and 32 px at 2; half
#steps take the left eight columns of the set star and the right eight of the unused one. The
#difficulty ramp runs from the low end of the star colours and the match ramp from the high end.

const DIFFICULTY: StringName = &"difficulty"
const MATCH: StringName = &"match"

@export var ramp: StringName = DIFFICULTY:
	set(kind):
		ramp = kind
		_refresh()
#Holds the value to half steps from 0.5 to 5.0.
@export var snap_half: bool = false:
	set(on):
		snap_half = on
		value = value
@export var star_px: int = 2:
	set(px):
		star_px = maxi(1, px)
		_refresh()
@export var empty_color: Color = Icons.UNUSED_STAR:
	set(color):
		empty_color = color
		_refresh()
#Writes the value to the tooltip; off leaves the tooltip to the owner.
@export var value_tip: bool = true:
	set(on):
		value_tip = on
		_refresh()
@export var value: float = 0.0:
	set(v):
		value = GuiTypes.snap_half(v) if snap_half else v
		_refresh()


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	custom_minimum_size = Vector2(Icons.stars_width(star_px), Icons.CELL * star_px)
	if value_tip:
		tooltip_text = "%.1f" % value
	queue_redraw()


func _draw() -> void:
	Icons.draw_stars(self, Vector2.ZERO, star_px, value, ramp == MATCH, empty_color, Icons.STAR_GAP)


static func color_of(v: float, ramp_kind: StringName, half: bool) -> Color:
	return Icons.star_color(GuiTypes.snap_half(v) if half else v, ramp_kind == MATCH)


#A fit row: the match ramp in half steps from 0.5, with the tooltip left to the owner.
static func fit_stars(px: int) -> Stars:
	var stars := Stars.new()
	stars.ramp = MATCH
	stars.snap_half = true
	stars.value_tip = false
	stars.star_px = px
	stars.value = 0.5
	return stars
