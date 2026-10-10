class_name LoanPaymentCells extends Control

#The payment strip of a loan card: one cell per row of FinanceManager.payment_rows. The hovered
#cell grows, takes a ring and shows a panel with the date, the amount and what is left after it.

const GAP: float = 2.0
const STRIP_HEIGHT: float = 14.0
const CELL_HEIGHT: float = 10.0
const HOVER_HEIGHT: float = 14.0
const RING_COLOR: Color = GuiColors.CREAM
const SENT: Color = GuiColors.GREEN
const SENT_HOVER: Color = GuiColors.GREEN_HI
const FUTURE: Color = GuiColors.BLUE_LO
const FUTURE_HOVER: Color = GuiColors.BLUE
const TIP_WIDTH: float = 200.0
const TIP_GAP: float = 6.0
const EDGE_CELLS: int = 2
const DUE_TEXT: String = "Amount Due"
const SENT_TEXT: String = "Amount Sent"
const AFTER_TEXT: String = "Remaining After"

var _rows: Array[Dictionary] = []
var _hover: int = -1
var _tip: PanelContainer = null
var _tip_label: Label = null
var _tip_date: Label = null
var _tip_amount_label: Label = null
var _tip_amount: NotesLabel = null
var _tip_after: NotesLabel = null


func _ready() -> void:
	custom_minimum_size.y = STRIP_HEIGHT
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_exited.connect(_on_exit)
	_build_tip()
	queue_redraw()


func set_rows(rows: Array[Dictionary]) -> void:
	_rows = rows
	_hover = -1
	_refresh_tip()
	queue_redraw()


func cell_count() -> int:
	return _rows.size()


func hover_cell(index: int) -> void:
	var wanted: int = index if index >= 0 and index < _rows.size() else -1
	if wanted == _hover:
		return
	_hover = wanted
	_refresh_tip()
	queue_redraw()


func hovered() -> int:
	return _hover


func cell_color(index: int) -> Color:
	if index < 0 or index >= _rows.size():
		return FUTURE
	var future: bool = bool(_rows[index].get("future", false))
	if index == _hover:
		return FUTURE_HOVER if future else SENT_HOVER
	return FUTURE if future else SENT


func cell_height(index: int) -> float:
	return HOVER_HEIGHT if index == _hover else CELL_HEIGHT


func tip_text(key: String) -> String:
	if _hover < 0 or _hover >= _rows.size():
		return ""
	var row: Dictionary = _rows[_hover]
	var future: bool = bool(row.get("future", false))
	match key:
		"label":
			return String(row.get("label", ""))
		"date":
			return String(row.get("date", ""))
		"amount_label":
			return DUE_TEXT if future else SENT_TEXT
		"amount":
			return TransactionData.grouped(int(row.get("amount", 0)))
		"after_label":
			return AFTER_TEXT
		"after":
			return TransactionData.grouped(maxi(0, int(row.get("after", 0))))
	return ""


func tip_open() -> bool:
	return _tip != null and _tip.visible


func _build_tip() -> void:
	_tip = LoanStyle.panel(GuiColors.BLUE_LO, 10, 8)
	_tip.custom_minimum_size = Vector2(TIP_WIDTH, 0.0)
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	var col: VBoxContainer = GuiStyle.vbox(4)
	_tip_label = GuiStyle.label("", GuiStyle.SILK_BOLD, 10, GuiColors.SKY)
	_tip_date = GuiStyle.label("", GuiStyle.SILK, 13, GuiColors.CREAM)
	col.add_child(_tip_label)
	col.add_child(_tip_date)
	var amount_row: HBoxContainer = GuiStyle.hbox(6)
	_tip_amount_label = GuiStyle.label(DUE_TEXT, GuiStyle.SILK, 8, GuiColors.SKY)
	_tip_amount = GuiStyle.notes(0, 11, GuiColors.CREAM)
	amount_row.add_child(_tip_amount_label)
	amount_row.add_child(_tip_amount)
	col.add_child(amount_row)
	var after_row: HBoxContainer = GuiStyle.hbox(6)
	after_row.add_child(GuiStyle.label(AFTER_TEXT, GuiStyle.SILK, 8, GuiColors.SKY))
	_tip_after = GuiStyle.notes(0, 11, GuiColors.RED)
	after_row.add_child(_tip_after)
	col.add_child(after_row)
	_tip.add_child(col)
	add_child(_tip)


func _refresh_tip() -> void:
	if _tip == null:
		return
	if _hover < 0 or _hover >= _rows.size():
		_tip.visible = false
		return
	var row: Dictionary = _rows[_hover]
	var future: bool = bool(row.get("future", false))
	_tip_label.text = tip_text("label")
	_tip_label.add_theme_color_override("font_color", GuiColors.SKY if future else GuiColors.GREEN)
	_tip_date.text = tip_text("date")
	_tip_amount_label.text = tip_text("amount_label")
	_tip_amount.amount = int(row.get("amount", 0))
	_tip_after.amount = maxi(0, int(row.get("after", 0)))
	_tip.visible = true
	_place_tip()


#Left for the first two cells, right for the last two, centred for the rest, inside the strip.
func _place_tip() -> void:
	var count: int = _rows.size()
	var wanted: float = 0.0
	if _hover >= count - EDGE_CELLS and _hover >= EDGE_CELLS:
		wanted = size.x - TIP_WIDTH
	elif _hover >= EDGE_CELLS:
		wanted = _cell_rect(_hover).get_center().x - TIP_WIDTH * 0.5
	_tip.position = Vector2(clampf(wanted, minf(0.0, size.x - TIP_WIDTH), maxf(0.0,
		size.x - TIP_WIDTH)), -(_tip.get_combined_minimum_size().y + TIP_GAP))


func tip_left() -> float:
	return _tip.position.x if _tip != null else 0.0


#The strip less its gaps, shared evenly between the cells; 0 when there are none.
func _cell_width() -> float:
	var count: int = _rows.size()
	if count <= 0:
		return 0.0
	return (size.x - GAP * float(count - 1)) / float(count)


func _cell_rect(index: int) -> Rect2:
	if _rows.is_empty():
		return Rect2()
	var each: float = _cell_width()
	var h: float = cell_height(index)
	return Rect2(float(index) * (each + GAP), STRIP_HEIGHT - h, each, h)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion):
		return
	var at: Vector2 = (event as InputEventMouseMotion).position
	var each: float = _cell_width()
	if each <= 0.0:
		return
	hover_cell(clampi(int(at.x / (each + GAP)), 0, _rows.size() - 1))


func _on_exit() -> void:
	hover_cell(-1)


func _draw() -> void:
	for i: int in _rows.size():
		var rect: Rect2 = _cell_rect(i)
		draw_rect(rect, cell_color(i), true)
		if i == _hover:
			draw_rect(rect, RING_COLOR, false, 1.0)
