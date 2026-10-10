class_name ClientStockChart
extends BevelButton

#The year of share prices for a company client, a button that opens the invest window. The line is
#drawn from the prices the viewer hands over; nothing here reads the market itself.

const TITLE_TEXT: String = "Stock - 1Y"
const TIP_TEXT: String = "Open Invest for this company"
const UP_COLOR: Color = GuiColors.GREEN
const DOWN_COLOR: Color = GuiColors.RED
const LINK_COLOR: Color = GuiColors.ORANGE
const LINE_PX: float = 2.0
const INSET_PX: float = 6.0
const MIN_PRICES: int = 2

var company_id: int = -1

var _prices: PackedFloat32Array = PackedFloat32Array()

@onready var title_label: Label = $Rows/Top/Title
@onready var price_label: Label = $Rows/Top/Price
@onready var change_label: Label = $Rows/Top/Change
@onready var line: Control = $Rows/ChartBox/Line
@onready var arrow: TextureRect = $Rows/Bottom/Arrow


func _init() -> void:
	fill = GuiColors.ROW_FILL
	hi = GuiColors.ROW_FILL.lightened(0.18)
	lo = GuiColors.INK
	click_move = ButtonFx.ClickMove.NONE
	click_shade = ButtonFx.ClickShade.FLASH
	hover_move = ButtonFx.HoverMove.NONE
	hover_shade = ButtonFx.HoverShade.LIGHTEN
	stay_move = ButtonFx.StayMove.NONE
	stay_shade = ButtonFx.StayShade.NONE
	active_move = ButtonFx.HoverMove.NONE
	active_shade = ButtonFx.HoverShade.RING


func _ready() -> void:
	super()
	focus_mode = Control.FOCUS_NONE
	tooltip_text = TIP_TEXT
	title_label.text = TITLE_TEXT
	arrow.texture = Icons.tinted("caret_right", LINK_COLOR, 2, true)
	if not line.draw.is_connected(_draw_line):
		line.draw.connect(_draw_line)
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
	var low: float = _prices[0]
	var high: float = _prices[0]
	for i: int in n:
		low = minf(low, _prices[i])
		high = maxf(high, _prices[i])
	var span: float = high - low
	for i: int in n:
		var t: float = float(i) / float(n - 1)
		var norm: float = 0.5
		if not is_zero_approx(span):
			norm = (_prices[i] - low) / span
		out.append(Vector2(INSET_PX + t * width, INSET_PX + (1.0 - norm) * height))
	return out


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
