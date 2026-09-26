class_name SpeedButton extends Button

#One clock speed toggle. The glyphs are drawn arrows or bars, never a texture, unless icon is
#set. The owner (TimeMenu) manages which button in the group is pressed; this atom only reports
#its own click as a speed pick.

signal speed_selected(mode: int)

const LEFT: Array[String] = ["...#", "..##", ".###", "####", ".###", "..##", "...#"]
const BAR: Array[String] = ["##", "##", "##", "##", "##", "##", "##"]

const LABELS: Dictionary = {
	0: "Slow Down",
	1: "Pause",
	2: "Play",
	3: "Fast Forward",
	4: "Faster Fast Forward",
}

const INK_COLOR := Color(0.039216, 0.058824, 0.109804, 1)
const CREAM_COLOR := Color(0.952941, 0.917647, 0.843137, 1)

#icon is inherited from Button (redeclaring it errors: "Member icon redefined"); assigning it
#lets Button draw that texture itself, centered, instead of the glyphs below.
@export var speed_mode: ClockRunner.Speed = ClockRunner.Speed.PLAY:
	set(value):
		speed_mode = value
		_refresh()
@export var pixel_scale: int = 2:
	set(value):
		pixel_scale = value
		_refresh()


func _ready() -> void:
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	pressed.connect(_on_pressed)
	_refresh()


func _on_pressed() -> void:
	speed_selected.emit(speed_mode)


func _refresh() -> void:
	if not is_node_ready():
		return
	tooltip_text = label_for(speed_mode)
	queue_redraw()


static func label_for(mode: int) -> String:
	return String(LABELS.get(mode, ""))


static func glyph_maps(mode: int) -> Array[PackedStringArray]:
	var right: Array[String] = []
	for row: String in LEFT:
		right.append(_reverse(row))
	match mode:
		0:
			return [PackedStringArray(LEFT), PackedStringArray(LEFT)]
		1:
			return [PackedStringArray(BAR), PackedStringArray(BAR)]
		2:
			return [PackedStringArray(right)]
		3:
			return [PackedStringArray(right), PackedStringArray(right)]
		4:
			return [PackedStringArray(right), PackedStringArray(right), PackedStringArray(right)]
	return []


static func _reverse(row: String) -> String:
	var out := ""
	for i: int in range(row.length() - 1, -1, -1):
		out += row[i]
	return out


func _draw() -> void:
	if icon != null:
		var pos: Vector2 = (size - icon.get_size()) * 0.5
		draw_texture_rect(icon, Rect2(pos, icon.get_size()), false)
		return
	var maps: Array[PackedStringArray] = glyph_maps(speed_mode)
	if maps.is_empty():
		return
	var color: Color = INK_COLOR if button_pressed else CREAM_COLOR
	var total_w: int = 0
	for m: PackedStringArray in maps:
		total_w += m[0].length() * pixel_scale
	total_w += maxi(0, maps.size() - 1) * pixel_scale
	var h: int = 7 * pixel_scale
	var x: float = (size.x - total_w) * 0.5
	var y0: float = (size.y - h) * 0.5
	for m: PackedStringArray in maps:
		var w: int = m[0].length()
		for row_i: int in range(m.size()):
			var row: String = m[row_i]
			for col_i: int in range(row.length()):
				if row[col_i] == "#":
					draw_rect(Rect2(x + col_i * pixel_scale, y0 + row_i * pixel_scale,
						pixel_scale, pixel_scale), color)
		x += w * pixel_scale + pixel_scale
