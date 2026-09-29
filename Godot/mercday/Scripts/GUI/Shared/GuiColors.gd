class_name GuiColors

#Shared colour ramps and the locked-feature palette. tier_color runs red to yellow to green
#across a rank; cat_color and gate_color scale that ramp's brightness by a 0..1 fraction.

const RAMP_RED: Color = Color("#e8583f")
const RAMP_YELLOW: Color = Color("#f2d33d")
const RAMP_GREEN: Color = Color("#4ee06a")

const LOCKED_BG: Color = Color("#27324a")
const LOCKED_TEXT: Color = Color("#8a97ad")
const LOCKED_HI: Color = Color("#34415e")
const LOCKED_LO: Color = Color("#1c2540")
const LOCK_RING: Color = Color("#3b4d6e")
const LOCK_GOLD: Color = Color("#f2d33d")
const GRAY_ICON_BRIGHTNESS: float = 0.55


#Red at i = 0, green at i = n - 1; n <= 1 always reads as green.
static func tier_color(i: int, n: int) -> Color:
	if n <= 1:
		return RAMP_GREEN
	return _ramp(float(i) / float(n - 1))


static func cat_color(f: float) -> Color:
	return _scale(_ramp(f), 0.30 + 0.70 * clampf(f, 0.0, 1.0))


static func gate_color(f: float) -> Color:
	return _scale(_ramp(f), 0.55 + 0.45 * clampf(f, 0.0, 1.0))


static func mix(colors: Array[Color]) -> Color:
	if colors.is_empty():
		return Color.WHITE
	var r: float = 0.0
	var g: float = 0.0
	var b: float = 0.0
	var a: float = 0.0
	for c: Color in colors:
		r += c.r
		g += c.g
		b += c.b
		a += c.a
	var n: float = float(colors.size())
	return Color(r / n, g / n, b / n, a / n)


static func _ramp(f: float) -> Color:
	f = clampf(f, 0.0, 1.0)
	if f < 0.5:
		return RAMP_RED.lerp(RAMP_YELLOW, f * 2.0)
	return RAMP_YELLOW.lerp(RAMP_GREEN, (f - 0.5) * 2.0)


static func _scale(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)
