class_name InvestText

#Every number and colour the Invest page prints. A price product (price, position value,
#portfolio value, gain, New Position Value) carries two decimals; notes that move through the
#bank (the fee, a total, a dividend) are whole notes.

const INK: Color = GuiColors.INK
const NAVY: Color = GuiColors.ROW_FILL
const NAVY2: Color = GuiColors.ROW_HOVER
const PANEL: Color = GuiColors.BOX_BG
const BLUE: Color = GuiColors.BLUE_LO
const BLUE2: Color = GuiColors.BLUE
const BLUE3: Color = GuiColors.BLUE_HI
const ORANGE: Color = GuiColors.ORANGE
const ORANGE_HI: Color = GuiColors.ORANGE_HI
const ORANGE_LO: Color = GuiColors.ORANGE_LO
const CREAM: Color = GuiColors.CREAM
const SKY: Color = GuiColors.SKY
const MUTED: Color = GuiColors.MUTED
const GREEN: Color = GuiColors.GREEN
const GREEN_HI: Color = GuiColors.GREEN_HI
const GREEN_LO: Color = GuiColors.GREEN_LO
const RED: Color = GuiColors.RED
const RED_HI: Color = GuiColors.RED_HI
const RED_LO: Color = Color("#a83a28")
const YELLOW: Color = GuiColors.RAMP_YELLOW
const SWITCH_OFF: Color = GuiColors.SWITCH_OFF

#A change this small prints in cream: the PROTO treats it as flat.
const FLAT_LIMIT: float = 0.05

#The caption child of a painted Button.
const CAPTION_NAME: String = "Caption"


#Two decimals, no thousands grouping: "112.40".
static func price_text(v: float) -> String:
	return "%.2f" % v


#Two decimals grouped by thousands: "1,204.50".
static func value_text(v: float) -> String:
	var body: float = absf(v)
	var whole: int = int(floor(body))
	var cents: int = int(round((body - float(whole)) * 100.0))
	if cents >= 100:
		whole += 1
		cents -= 100
	var out: String = "%s.%02d" % [TransactionData.grouped(whole), cents]
	return ("-" + out) if v < 0.0 else out


#Whole notes grouped by thousands: "1,204".
static func notes_text(n: int) -> String:
	return TransactionData.grouped(n)


static func sign_text(v: float) -> String:
	return "-" if v < 0.0 else "+"


#"+4.5%", "-12.0%".
static func change_text(pct: float) -> String:
	return "%s%.1f%%" % [sign_text(pct), absf(pct)]


static func change_color(pct: float) -> Color:
	if absf(pct) < FLAT_LIMIT:
		return CREAM
	return GREEN if pct > 0.0 else RED


static func gain_color(v: float) -> Color:
	return GREEN if v >= 0.0 else RED


#"+1.23 (+4.5%)": an absolute move with two decimals and its percent with one.
static func move_text(delta: float, pct: float) -> String:
	return "%s%s (%s)" % [sign_text(delta), value_text(absf(delta)), change_text(pct)]


#Set once a negative share count has been warned about, so the log carries only one line per run.
static var _warned_negative_shares: bool = false


#"25 shares", "1 share", "" at 0. A negative count cannot happen (shorting is not part of this
#game); it is a data bug, so it prints as "0 shares" once and logs a warning instead of a minus.
static func shares_text(n: int) -> String:
	if n < 0:
		if not _warned_negative_shares:
			push_warning("InvestText.shares_text: negative share count %d" % n)
			_warned_negative_shares = true
		return "0 shares"
	if n == 0:
		return ""
	return "%s share%s" % [notes_text(n), "" if n == 1 else "s"]


#The date a holding's first purchase happened, in the same wording as the other cards' date lines.
static func since_text(day: int) -> String:
	return TrynnCalendar.date_text(day * CampaignClock.MINUTES_PER_DAY)


#Godot paints the built-in text of a Button before the script _draw, so a bevel fill covers it.
#The caption of a painted button therefore rides in a child Label, which paints after the fill.
static func caption_label(host: Button) -> Label:
	var found: Label = host.get_node_or_null(NodePath(CAPTION_NAME)) as Label
	if found != null:
		return found
	var made := Label.new()
	made.name = CAPTION_NAME
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	made.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	made.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	host.add_child(made)
	made.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	copy_button_font(host, made)
	return made


#The font, the size and the colour the Button carries, written as Label overrides; no text outline.
static func copy_button_font(host: Button, target: Label) -> void:
	var face: Font = host.get_theme_font("font")
	if face != null:
		target.add_theme_font_override("font", face)
	target.add_theme_font_size_override("font_size", host.get_theme_font_size("font_size"))
	target.add_theme_color_override("font_color", host.get_theme_color("font_color"))


#The dashed ring of the empty tooltip box.
static func draw_dashed_border(target: CanvasItem, box: Rect2, color: Color,
		width: float = 2.0, dash: float = 6.0) -> void:
	var step: float = dash * 2.0
	var x: float = box.position.x
	while x < box.end.x:
		var run: float = minf(dash, box.end.x - x)
		target.draw_rect(Rect2(x, box.position.y, run, width), color, true)
		target.draw_rect(Rect2(x, box.end.y - width, run, width), color, true)
		x += step
	var y: float = box.position.y
	while y < box.end.y:
		var run_y: float = minf(dash, box.end.y - y)
		target.draw_rect(Rect2(box.position.x, y, width, run_y), color, true)
		target.draw_rect(Rect2(box.end.x - width, y, width, run_y), color, true)
		y += step
