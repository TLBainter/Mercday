class_name ClientStockChart
extends Button

#The year of share prices for a company client, a button that opens the invest window. The line is
#drawn from the prices the viewer hands over; nothing here reads the market itself.

const TITLE_TEXT: String = "Stock - 1Y"
const TIP_TEXT: String = "Open Invest for this company"
const OPEN_TEXT: String = "Open Invest"
const UP_COLOR: Color = Color("#6cc36a")
const DOWN_COLOR: Color = Color("#e8583f")
const FILL: Color = Color("#0e1628")
const IDLE_EDGE: Color = Color("#0a0f1c")
const HOVER_EDGE: Color = Color("#f28c28")
const LINK_COLOR: Color = Color("#f28c28")
const EDGE_PX: int = 3
const LINE_PX: float = 2.0
const INSET_PX: float = 6.0
const PAD_X: float = 12.0
const PAD_Y: float = 10.0
const MIN_PRICES: int = 2

var company_id: int = -1

var _prices: PackedFloat32Array = PackedFloat32Array()

@onready var title_label: Label = $Rows/Top/Title
@onready var price_label: Label = $Rows/Top/Price
@onready var change_label: Label = $Rows/Top/Change
@onready var chart_box: Panel = $Rows/ChartBox
@onready var line: Control = $Rows/ChartBox/Line
@onready var arrow: TextureRect = $Rows/Bottom/Arrow


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	tooltip_text = TIP_TEXT
	title_label.text = TITLE_TEXT
	arrow.texture = Icons.tinted("caret_right", LINK_COLOR, 2, true)
	if not line.draw.is_connected(_draw_line):
		line.draw.connect(_draw_line)
	_apply_boxes()
	_render()


func set_prices(id: int, values: PackedFloat32Array) -> void:
	company_id = id
	_prices = values.duplicate()
	visible = _prices.size() >= MIN_PRICES
	if is_node_ready():
		_render()


func prices() -> PackedFloat32Array:
	return _prices.duplicate()


func price_text() -> String:
	if _prices.is_empty():
		return "0.00"
	return "%.2f" % _prices[_prices.size() - 1]


func change_text() -> String:
	return "%+.1f%%" % change_pct()


func change_pct() -> float:
	if _prices.size() < MIN_PRICES:
		return 0.0
	var first: float = _prices[0]
	var last: float = _prices[_prices.size() - 1]
	if is_zero_approx(first):
		return 0.0
	return (last - first) / first * 100.0


func is_up() -> bool:
	if _prices.size() < MIN_PRICES:
		return true
	return _prices[_prices.size() - 1] >= _prices[0]


func line_color() -> Color:
	return UP_COLOR if is_up() else DOWN_COLOR


func points() -> PackedVector2Array:
	var out := PackedVector2Array()
	var n: int = _prices.size()
	if n < MIN_PRICES or not is_node_ready():
		return out
	var area: Vector2 = line.size
	var width: float = maxf(area.x - INSET_PX * 2.0, 1.0)
	var height: float = maxf(area.y - INSET_PX * 2.0, 1.0)
	var lo: float = _prices[0]
	var hi: float = _prices[0]
	for i: int in n:
		lo = minf(lo, _prices[i])
		hi = maxf(hi, _prices[i])
	var span: float = hi - lo
	for i: int in n:
		var t: float = float(i) / float(n - 1)
		var norm: float = 0.5
		if not is_zero_approx(span):
			norm = (_prices[i] - lo) / span
		out.append(Vector2(INSET_PX + t * width, INSET_PX + (1.0 - norm) * height))
	return out


static func box(fill: Color, edge: Color, edge_px: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_width_left = edge_px
	style.border_width_top = edge_px
	style.border_width_right = edge_px
	style.border_width_bottom = edge_px
	style.border_color = edge
	return style


func _apply_boxes() -> void:
	var idle: StyleBoxFlat = box(FILL, IDLE_EDGE, EDGE_PX)
	idle.content_margin_left = PAD_X
	idle.content_margin_top = PAD_Y
	idle.content_margin_right = PAD_X
	idle.content_margin_bottom = PAD_Y
	add_theme_stylebox_override(&"normal", idle)
	add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	var hot: StyleBoxFlat = box(FILL, HOVER_EDGE, EDGE_PX)
	hot.content_margin_left = PAD_X
	hot.content_margin_top = PAD_Y
	hot.content_margin_right = PAD_X
	hot.content_margin_bottom = PAD_Y
	add_theme_stylebox_override(&"hover", hot)
	add_theme_stylebox_override(&"pressed", hot)


func _render() -> void:
	var tint: Color = line_color()
	price_label.text = price_text()
	change_label.text = change_text()
	price_label.add_theme_color_override(&"font_color", tint)
	change_label.add_theme_color_override(&"font_color", tint)
	line.queue_redraw()


func _draw_line() -> void:
	var pts: PackedVector2Array = points()
	if pts.size() < MIN_PRICES:
		return
	line.draw_polyline(pts, line_color(), LINE_PX)
