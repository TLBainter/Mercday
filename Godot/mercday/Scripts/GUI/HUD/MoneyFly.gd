class_name MoneyFly extends Control

#Sixteen note tiles arc between the screen and the HUD money counter over 1.6 s.
#Display only: the counter value itself always follows GameState.money_changed.
#A positive amount flies into the counter, a negative one flies out of it.

signal finished(amount: int)

const NOTE_COUNT: int = 16
const DURATION: float = 1.6
const NOTE_SPAN: float = 0.65
const NOTE_STAGGER: float = 0.045
const ARC_HEIGHT: float = 90.0
const NOTE_SIZE := Vector2(16.0, 20.0)
const START_ORIGIN := Vector2(800.0, 230.0)
const START_STEP := Vector2(14.0, 12.0)
const START_COLUMNS: int = 4
const COUNTER_POINT := Vector2(64.0, 660.0)
const TILE_COLOR := Color("#f28c28")
const TILE_HI := Color("#ffb266")
const TILE_LO := Color("#b85a12")
const TILE_RING := Color("#0a0f1c")
const BEVEL_PX: float = 2.0
const RING_PX: float = 2.0
const GLYPH_SIZE := Vector2(7.0, 9.0)
const GLYPH_PATH: String = "res://Art/GUI/Icons/icon_note_currency.png"

var _amount: int = 0
var _time: float = 0.0
var _running: bool = false
var _counter: MoneyMenu = null
var _glyph: Texture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glyph = _load_glyph()
	set_process(false)
	visible = false


func _load_glyph() -> Texture2D:
	if ResourceLoader.exists(GLYPH_PATH):
		var art: Texture2D = load(GLYPH_PATH) as Texture2D
		if art != null:
			return art
	return HudGlyphs.note()


#Starts a fly; a zero amount is ignored so a settle with no change draws nothing.
func play(p_amount: int) -> void:
	if p_amount == 0:
		return
	_amount = p_amount
	_time = 0.0
	_running = true
	visible = true
	set_process(true)
	queue_redraw()


func is_flying() -> bool:
	return _running


func amount() -> int:
	return _amount


func time() -> float:
	return _time


#Test seam: places the fly at one point in its run without waiting on frames.
func set_time(value: float) -> void:
	_time = clampf(value, 0.0, DURATION)
	queue_redraw()


func finish_now() -> void:
	if not _running:
		return
	_time = DURATION
	_stop()


func set_counter(menu: MoneyMenu) -> void:
	_counter = menu


func counter() -> MoneyMenu:
	return _counter


#The counter centre in local space, or the design constant before the bar is laid out.
func counter_point() -> Vector2:
	if _counter != null and _counter.is_inside_tree():
		var point: Vector2 = _counter.counter_point()
		if point != Vector2.ZERO:
			return point - global_position
	return COUNTER_POINT


func note_start(index: int) -> Vector2:
	var col: float = float(index % START_COLUMNS)
	var row: float = floorf(float(index) / float(START_COLUMNS))
	return START_ORIGIN + Vector2(col * START_STEP.x, row * START_STEP.y)


func note_progress(index: int) -> float:
	return clampf((_time - float(index) * NOTE_STAGGER) / NOTE_SPAN, 0.0, 1.0)


func note_position(index: int) -> Vector2:
	var p: float = note_progress(index)
	var from: Vector2 = note_start(index)
	var to: Vector2 = counter_point()
	if _amount < 0:
		var swap: Vector2 = from
		from = to
		to = swap
	var pos: Vector2 = from + (to - from) * p
	pos.y -= ARC_HEIGHT * sin(PI * p)
	return pos


func note_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in NOTE_COUNT:
		out.append(note_position(i))
	return out


#A note shows only while it is travelling, so the pile never sits at either end.
func note_opacity(index: int) -> float:
	var p: float = note_progress(index)
	if p <= 0.0 or p >= 1.0:
		return 0.0
	return 1.0


func _process(delta: float) -> void:
	if not _running:
		return
	_time += delta
	if _time >= DURATION:
		_time = DURATION
		_stop()
		return
	queue_redraw()


func _stop() -> void:
	_running = false
	set_process(false)
	visible = false
	queue_redraw()
	finished.emit(_amount)


func _draw() -> void:
	if not _running:
		return
	for i in NOTE_COUNT:
		if note_opacity(i) <= 0.0:
			continue
		_draw_note(note_position(i))


func _draw_note(at: Vector2) -> void:
	var box := Rect2(at - NOTE_SIZE * 0.5, NOTE_SIZE)
	var ring := Vector2(RING_PX, RING_PX)
	draw_rect(Rect2(box.position - ring, box.size + ring * 2.0), TILE_RING)
	draw_rect(box, TILE_COLOR)
	draw_rect(Rect2(box.position, Vector2(box.size.x, BEVEL_PX)), TILE_HI)
	draw_rect(Rect2(box.position, Vector2(BEVEL_PX, box.size.y)), TILE_HI)
	var low := box.position + Vector2(0.0, box.size.y - BEVEL_PX)
	draw_rect(Rect2(low, Vector2(box.size.x, BEVEL_PX)), TILE_LO)
	var right := box.position + Vector2(box.size.x - BEVEL_PX, 0.0)
	draw_rect(Rect2(right, Vector2(BEVEL_PX, box.size.y)), TILE_LO)
	if _glyph == null:
		return
	var origin: Vector2 = box.position + (box.size - GLYPH_SIZE) * 0.5
	draw_texture_rect(_glyph, Rect2(origin, GLYPH_SIZE), false)
