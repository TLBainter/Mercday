@tool
class_name PaletteRamp extends RefCounted

#A 256x1 ramp for one flat color following a template row's light-to-dark curve: hue of the color, saturation
#and value scaled by the template's ratio to its own middle pixel (x 128), clamped 0..1.

const WIDTH: int = 256
const MID_X: int = 128


static func generate(template: Image, color: Color) -> Image:
	var out: Image = Image.create_empty(WIDTH, 1, false, Image.FORMAT_RGBA8)
	if template == null or template.is_empty():
		out.fill(Color(color, 1.0))
		return out
	var row: Image = template.duplicate() as Image
	row.convert(Image.FORMAT_RGBA8)
	if row.get_width() != WIDTH or row.get_height() != 1:
		row.resize(WIDTH, 1, Image.INTERPOLATE_NEAREST)
	var mid: Color = mid_color(row)
	for x: int in range(WIDTH):
		var t: Color = row.get_pixel(x, 0)
		var s: float = color.s if mid.s <= 0.0 else clampf(color.s * t.s / mid.s, 0.0, 1.0)
		var v: float = color.v if mid.v <= 0.0 else clampf(color.v * t.v / mid.v, 0.0, 1.0)
		out.set_pixel(x, 0, Color.from_hsv(color.h, s, v, 1.0))
	out.set_pixel(MID_X, 0, Color(color, 1.0))
	return out


static func mid_color(row: Image) -> Color:
	if row == null or row.is_empty():
		return Color.BLACK
	return row.get_pixel(clampi(MID_X, 0, row.get_width() - 1), 0)
