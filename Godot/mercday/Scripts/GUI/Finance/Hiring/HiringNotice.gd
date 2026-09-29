class_name HiringNotice extends PanelContainer

#The banner over the Hiring columns: one line in the colour of the news, held for hold_seconds. A new
#flash replaces the old one and restarts the hold; the banner never takes the mouse.

const BG: Color = Color("#0e1628")
const RING_PX: int = 3
const PAD_X: float = 14.0
const PAD_Y: float = 8.0
const TEXT_SIZE: int = 14
const DEFAULT_COLOR: Color = Color("#6cc36a")
const MIN_HOLD: float = 0.01

@export var hold_seconds: float = 3.2

var _body: Label = null
var _timer: Timer = null
var _tint: Color = DEFAULT_COLOR


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override(&"panel", HiringStyle.box(BG, RING_PX, _tint, PAD_X, PAD_Y))
	_body = HiringStyle.label("", HiringStyle.FONT_BODY, TEXT_SIZE, _tint)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(clear)
	add_child(_timer)
	hide()


func flash(body: String, tint: Color) -> void:
	if _body == null or _timer == null:
		return
	_tint = tint
	_body.text = body
	_body.add_theme_color_override(&"font_color", tint)
	HiringStyle.set_ring(self, tint)
	show()
	_timer.stop()
	_timer.start(maxf(MIN_HOLD, hold_seconds))


func text() -> String:
	return "" if _body == null else _body.text


func color() -> Color:
	return _tint


func showing() -> bool:
	return visible


func clear() -> void:
	if _timer != null:
		_timer.stop()
	if _body != null:
		_body.text = ""
	hide()
