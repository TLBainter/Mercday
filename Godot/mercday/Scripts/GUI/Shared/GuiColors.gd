class_name GuiColors

#The one GUI palette, the shared colour ramps and the locked-feature palette. tier_color runs red to yellow to green
#across a rank; cat_color and gate_color scale that ramp's brightness by a 0..1 fraction.

const INK: Color = Color("#0a0f1c")
const CREAM: Color = Color("#f3ead7")
const SKY: Color = Color("#9cc6ef")
const MUTED: Color = Color("#5e7699")
const GREEN: Color = Color("#6cc36a")
const RED: Color = Color("#e8583f")
const ORANGE: Color = Color("#f28c28")
const ORANGE_HI: Color = Color("#ffb266")
const ORANGE_LO: Color = Color("#b85a12")
const BLUE: Color = Color("#2b4f8a")
const BLUE_HI: Color = Color("#3b6fb6")
const BLUE_LO: Color = Color("#1f3560")
#No colour at all: the unset fill, ring or border default.
const CLEAR: Color = Color(0, 0, 0, 0)
const DIM_TEXT: Color = Color("#8a97ad")
const GRAY: Color = Color("#a0a8b8")
#The score ramp steps between the palette hues that the difficulty, match, odds, status and mood colours share.
const RED_ORANGE: Color = Color("#ec6a36")
const DARK_ORANGE: Color = Color("#ef7c2f")
const LIGHT_ORANGE: Color = Color("#f2a033")
const AMBER: Color = Color("#f2b33d")
const LIGHT_BLUE: Color = Color("#5aa6e8")
const TEAL: Color = Color("#5fb0b8")
const SEA_GREEN: Color = Color("#64b98c")
const DEEP_GREEN: Color = Color("#3fae5a")
const GO_FILL: Color = Color("#3f9a4a")
const GO_HI: Color = GREEN
const GO_LO: Color = Color("#2a6b32")
const DANGER_FILL: Color = Color("#b8402e")
const DANGER_HI: Color = RED
const DANGER_LO: Color = Color("#7a2a1e")
#Modal chrome: the dialog box fill and its two tone inset edge.
const BOX_BG: Color = Color("#1a2b4d")
const EDGE_HI: Color = Color("#28447a")
const EDGE_LO: Color = Color("#111c33")
#List rows: the idle fill, the hover fill and the dark edge under a selected row.
const ROW_FILL: Color = Color("#0e1628")
const ROW_HOVER: Color = Color("#15223d")
const ROW_EDGE_LO: Color = INK
const NEUTRAL_FILL: Color = BLUE_LO
const NEUTRAL_HI: Color = BLUE
const NEUTRAL_LO: Color = ROW_HOVER
#The one dim laid behind every modal and host window.
const BACKDROP: Color = Color(0.023529, 0.039216, 0.078431, 0.82)
#The dark well behind a framed page, a locked module and an invalid field.
const FRAME_BG: Color = Color("#101a30")
#Bevel edges of a green or red button, and the toggle switch track.
const GREEN_HI: Color = Color("#9be29a")
const GREEN_LO: Color = Color("#3f8a3e")
const RED_HI: Color = Color("#ff8a70")
const SWITCH_BG: Color = Color("#0f1a30")
const SWITCH_OFF: Color = Color("#4a6588")
#The neutral grey of a stock order that neither filled nor failed.
const PALE_GRAY: Color = Color("#9aa0a8")
#The pale text of a next-tier line.
const PALE_SKY: Color = Color("#c8d3e6")
const SLATE: Color = Color("#5e6b82")
const DONE_GREEN_BG: Color = Color("#123321")
const TUBE_BG: Color = Color("#05080f")
const NAVY_ROW: Color = Color("#16233f")

const RAMP_RED: Color = RED
const RAMP_YELLOW: Color = Color("#f2d33d")
const RAMP_GREEN: Color = Color("#4ee06a")

const LOCKED_BG: Color = Color("#27324a")
const LOCKED_TEXT: Color = DIM_TEXT
const LOCKED_HI: Color = Color("#34415e")
const LOCKED_LO: Color = Color("#1c2540")
const LOCK_RING: Color = Color("#3b4d6e")
const LOCK_GOLD: Color = Color("#f2d33d")
const GRAY_ICON_BRIGHTNESS: float = 0.55
#A greyed icon tint at GRAY_ICON_BRIGHTNESS; the faded form is the locked or unavailable portrait.
const GREY_TINT: Color = Color(GRAY_ICON_BRIGHTNESS, GRAY_ICON_BRIGHTNESS, GRAY_ICON_BRIGHTNESS)
const GREY_TINT_FADED: Color = Color(GRAY_ICON_BRIGHTNESS, GRAY_ICON_BRIGHTNESS, GRAY_ICON_BRIGHTNESS, 0.4)


#Red at i = 0, green at i = n - 1; n <= 1 always reads as green.
static func tier_color(i: int, n: int) -> Color:
	if n <= 1:
		return RAMP_GREEN
	return ramp_color(float(i) / float(n - 1))


static func cat_color(f: float) -> Color:
	return scale(ramp_color(f), 0.30 + 0.70 * clampf(f, 0.0, 1.0))


static func gate_color(f: float) -> Color:
	return scale(ramp_color(f), 0.55 + 0.45 * clampf(f, 0.0, 1.0))


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


#Red at f = 0, yellow at 0.5, green at 1; f is clamped to 0..1.
static func ramp_color(f: float) -> Color:
	f = clampf(f, 0.0, 1.0)
	if f < 0.5:
		return RAMP_RED.lerp(RAMP_YELLOW, f * 2.0)
	return RAMP_YELLOW.lerp(RAMP_GREEN, (f - 0.5) * 2.0)


static func scale(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


#The colour with its alpha multiplied by a.
static func fade(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


#The colour with each channel multiplied by gain and capped at 1; alpha is kept.
static func brighter(c: Color, gain: float) -> Color:
	return Color(minf(c.r * gain, 1.0), minf(c.g * gain, 1.0), minf(c.b * gain, 1.0), c.a)
