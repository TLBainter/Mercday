class_name OddJobWindow extends Control

#The modal Odd Job dialog: facts, the shared crew block, success odds and the send/cancel pair.
#Reused as-is by Legal, Promotions, Hiring and the loan request (wave 3), each supplying its own
#config. The window never spends notes; the host spends on the sent signal.

signal sent(team: Array[int], per: int)
signal cancelled

const BOX_WIDTH: float = 1000.0
const TITLE_COLOR: Color = Color("#f28c28")
const FACT_LABEL_COLOR: Color = Color("#9cc6ef")
const FACT_VALUE_DEFAULT: Color = Color("#f3ead7")
const ODDS_LABEL_COLOR: Color = Color("#f28c28")
const GREEN: Color = Color("#6cc36a")
const YELLOW: Color = Color("#f2b33d")
const RED: Color = Color("#e8583f")
const EDGE_HI: Color = Color("#28447a")
const EDGE_LO: Color = Color("#111c33")
const EDGE_PX: float = 4.0
const BAR_CELLS: int = 20
const FACT_GAP: int = 8
const BAR_HEIGHT: float = 16.0
const BAR_GAP: float = 2.0
const BAR_PAD: float = 2.0
const BAR_UNLIT: Color = Color("#1f3560")
const BAR_BG: Color = Color("#0a0f1c")
const BOOST_COLOR: Color = Color("#6cc36a")
const CANCEL_BG: Color = Color("#2b4f8a")
const CANCEL_HI: Color = Color("#3b6fb6")
const SEND_BG: Color = Color("#6cc36a")
const SEND_TEXT: Color = Color("#0a0f1c")
const SEND_HI: Color = Color("#9be29a")
const OUTCOME_COLOR: Color = Color("#9cc6ef")
const DISABLED_TINT: Color = Color(0.6, 0.6, 0.6, 0.45)
const BEVEL_DROP: float = 0.35

const FONT_BOLD: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const FONT_REGULAR: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")

@onready var backdrop: Panel = $Backdrop
@onready var box: PanelContainer = $Box
@onready var edges: Control = $Box/Edges
@onready var rows: VBoxContainer = $Box/Pad/Rows
@onready var title_label: Label = $Box/Pad/Rows/Title
@onready var facts_grid: GridContainer = $Box/Pad/Rows/FactsGrid
@onready var crew_node: OddJobCrew = $Box/Pad/Rows/Crew
@onready var odds_row: HBoxContainer = $Box/Pad/Rows/OddsRow
@onready var odds_label_node: Label = $Box/Pad/Rows/OddsRow/OddsLabel
@onready var odds_value_label: Label = $Box/Pad/Rows/OddsRow/OddsValue
@onready var odds_bar: Control = $Box/Pad/Rows/OddsBar
@onready var boost_label: Label = $Box/Pad/Rows/BoostText
@onready var buttons_grid: GridContainer = $Box/Pad/Rows/ButtonsGrid
@onready var cancel_button: Button = $Box/Pad/Rows/ButtonsGrid/CancelButton
@onready var send_button: Button = $Box/Pad/Rows/ButtonsGrid/SendButton
@onready var outcome_label: Label = $Box/Pad/Rows/OutcomeText

var _odds_fn: Callable = Callable()
var _money: int = 0
var _send_label: String = "Send"
var _odds_label: String = "Success Odds"
var _last_odds: int = 0
var _last_team_empty: bool = true


func _ready() -> void:
	top_level = true
	hide()
	edges.draw.connect(_draw_edges)
	edges.resized.connect(edges.queue_redraw)
	odds_bar.draw.connect(_draw_odds_bar)
	cancel_button.pressed.connect(press_cancel)
	send_button.pressed.connect(press_send)
	crew_node.team_changed.connect(_on_team_changed)
	crew_node.pay_changed.connect(_on_pay_changed)
	_style_static()


func open(config: Dictionary) -> void:
	title_label.text = str(config.get("title", ""))
	_build_facts(config.get("facts", []))
	_odds_fn = config.get("odds", Callable())
	_odds_label = str(config.get("odds_label", "Success Odds"))
	odds_label_node.text = _odds_label
	_send_label = str(config.get("send_label", "Send"))
	_money = int(config.get("money", 0))
	boost_label.text = str(config.get("boost_text", ""))
	boost_label.visible = not boost_label.text.is_empty()
	outcome_label.text = str(config.get("outcome_text", ""))
	outcome_label.add_theme_color_override(&"font_color", OUTCOME_COLOR)
	var max_mercs: int = int(config.get("max_mercs", 0))
	var candidates_in: Array[Dictionary] = []
	for c: Variant in config.get("candidates", []):
		candidates_in.append(c as Dictionary)
	crew_node.candidates = candidates_in
	crew_node.default_pay = int(config.get("default_pay", 0))
	crew_node.money = _money
	crew_node.tip_kind = str(config.get("tip_kind", "Odd Job"))
	crew_node.tip_text = str(config.get("tip_text", "Send a merc on this Odd Job."))
	crew_node.pick_desc = str(config.get("pick_desc", "Sorted by best fit."))
	crew_node.max_mercs = max_mercs
	crew_node.locked = max_mercs <= 0
	var initial_team: Array[int] = []
	for v: Variant in config.get("team", []):
		initial_team.append(int(v))
	crew_node.team = initial_team
	crew_node.per = int(config.get("per", crew_node.default_pay))
	_refresh_odds()
	_refresh_send()
	show()
	_place_box()
	GuiFrameStack.push(self)


func crew() -> OddJobCrew:
	return crew_node


func press_send() -> void:
	if send_button.disabled:
		return
	var team: Array[int] = crew_node.team
	var per: int = crew_node.per
	_dismiss()
	sent.emit(team, per)


func press_cancel() -> void:
	_dismiss()
	cancelled.emit()


func show_outcome(text: String, ok: bool) -> void:
	outcome_label.text = text
	outcome_label.add_theme_color_override(&"font_color", GREEN if ok else RED)


#Test accessor: whether the odds bar's cell i (0-based) is lit at the odds last computed.
func bar_cell_lit(i: int) -> bool:
	if _last_team_empty:
		return false
	return (i + 1) * 5 <= _last_odds + 2


#Test accessor: the height each odds cell is drawn with inside the bar.
func bar_cell_height() -> float:
	return BAR_HEIGHT - BAR_PAD * 2.0


#Test accessor: the colour of every odds cell in draw order; _draw_odds_bar() paints these.
func bar_cell_colors() -> PackedColorArray:
	var out := PackedColorArray()
	var lit_color: Color = _odds_color(_last_odds)
	for i in BAR_CELLS:
		out.append(lit_color if bar_cell_lit(i) else BAR_UNLIT)
	return out


#Test accessor: the odds percent last computed (0 while the team is empty).
func odds_percent() -> int:
	return _last_odds


func _dismiss() -> void:
	hide()
	GuiFrameStack.remove(self)


func _on_team_changed(_team: Array[int]) -> void:
	_refresh_odds()
	_refresh_send()
	_place_box()


func _on_pay_changed(_v: int) -> void:
	_refresh_send()


func _refresh_odds() -> void:
	_last_team_empty = crew_node.team.is_empty()
	if _last_team_empty:
		_last_odds = 0
		odds_value_label.text = "-"
		odds_value_label.add_theme_color_override(&"font_color", FACT_VALUE_DEFAULT)
		odds_bar.queue_redraw()
		return
	var odds: int = 0
	if _odds_fn.is_valid():
		odds = int(_odds_fn.call(crew_node.team))
	odds = clampi(odds, 0, 100)
	_last_odds = odds
	odds_value_label.text = "%d%%" % odds
	odds_value_label.add_theme_color_override(&"font_color", _odds_color(odds))
	odds_bar.queue_redraw()


func _refresh_send() -> void:
	var empty_team: bool = crew_node.team.is_empty()
	var over_budget: bool = crew_node.total() > _money
	var disabled: bool = empty_team or over_budget
	send_button.disabled = disabled
	if empty_team:
		send_button.tooltip_text = "Add at least one merc."
	elif over_budget:
		send_button.tooltip_text = "Not enough notes."
	else:
		send_button.tooltip_text = ""
	send_button.modulate = DISABLED_TINT if disabled else Color(1.0, 1.0, 1.0, 1.0)
	send_button.text = _send_label


func _build_facts(facts: Array) -> void:
	for child: Node in facts_grid.get_children():
		facts_grid.remove_child(child)
		child.queue_free()
	for row: Dictionary in facts:
		var cell := PanelContainer.new()
		cell.add_theme_stylebox_override(&"panel", _fact_style())
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var line := HBoxContainer.new()
		line.add_theme_constant_override(&"separation", FACT_GAP)
		var label_node := Label.new()
		label_node.text = str(row.get("label", ""))
		label_node.add_theme_font_override(&"font", FONT_REGULAR)
		label_node.add_theme_font_size_override(&"font_size", 9)
		label_node.add_theme_color_override(&"font_color", FACT_LABEL_COLOR)
		line.add_child(label_node)
		var value_node := Label.new()
		value_node.text = str(row.get("value", ""))
		value_node.add_theme_font_override(&"font", FONT_BOLD)
		value_node.add_theme_font_size_override(&"font_size", 12)
		var color: Color = row.get("color", FACT_VALUE_DEFAULT)
		value_node.add_theme_color_override(&"font_color", color)
		value_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(value_node)
		cell.add_child(line)
		facts_grid.add_child(cell)


func _style_static() -> void:
	title_label.add_theme_font_override(&"font", FONT_BOLD)
	title_label.add_theme_font_size_override(&"font_size", 18)
	title_label.add_theme_color_override(&"font_color", TITLE_COLOR)
	facts_grid.columns = 4
	facts_grid.add_theme_constant_override(&"h_separation", FACT_GAP)
	facts_grid.add_theme_constant_override(&"v_separation", FACT_GAP)
	odds_label_node.text = _odds_label
	odds_label_node.add_theme_font_override(&"font", FONT_REGULAR)
	odds_label_node.add_theme_font_size_override(&"font_size", 11)
	odds_label_node.add_theme_color_override(&"font_color", ODDS_LABEL_COLOR)
	odds_value_label.add_theme_font_override(&"font", FONT_BOLD)
	odds_value_label.add_theme_font_size_override(&"font_size", 20)
	odds_bar.custom_minimum_size = Vector2(0.0, BAR_HEIGHT)
	boost_label.add_theme_font_size_override(&"font_size", 13)
	boost_label.add_theme_color_override(&"font_color", BOOST_COLOR)
	buttons_grid.columns = 2
	buttons_grid.add_theme_constant_override(&"h_separation", 12)
	buttons_grid.add_theme_constant_override(&"v_separation", 12)
	cancel_button.custom_minimum_size = Vector2(0.0, 42.0)
	cancel_button.text = "Cancel"
	cancel_button.add_theme_font_override(&"font", FONT_REGULAR)
	cancel_button.add_theme_font_size_override(&"font_size", 12)
	_paint_button(cancel_button, CANCEL_BG, CANCEL_HI, FACT_VALUE_DEFAULT)
	send_button.custom_minimum_size = Vector2(0.0, 42.0)
	send_button.add_theme_font_override(&"font", FONT_BOLD)
	send_button.add_theme_font_size_override(&"font_size", 13)
	_paint_button(send_button, SEND_BG, SEND_HI, SEND_TEXT)
	outcome_label.add_theme_font_size_override(&"font_size", 13)
	outcome_label.add_theme_color_override(&"font_color", OUTCOME_COLOR)
	outcome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


#Both action buttons are BevelButtons: the colours go through the export set, since the button
#blanks every stylebox of its own the moment it enters the tree.
func _paint_button(host: Button, bg: Color, edge_hi: Color, tint: Color) -> void:
	var face: BevelButton = host as BevelButton
	if face == null:
		return
	face.set_colors(bg, edge_hi, bg.darkened(BEVEL_DROP), tint)


func _fact_style() -> StyleBoxFlat:
	var path: String = "res://Resources/GUI/Theme/Styles/crew_fact_cell.tres"
	return (load(path) as StyleBoxFlat).duplicate() as StyleBoxFlat


func _place_box() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	backdrop.offset_bottom = -GuiFrameStack.bottom_reserve
	box.reset_size()
	box.position = Vector2((view.x - box.size.x) / 2.0,
		(GuiFrameStack.band_height(view.y) - box.size.y) / 2.0)
	box.position.y = maxf(box.position.y, 0.0)


func _draw_edges() -> void:
	var span: Vector2 = edges.size
	edges.draw_rect(Rect2(0.0, 0.0, span.x, EDGE_PX), EDGE_HI)
	edges.draw_rect(Rect2(0.0, 0.0, EDGE_PX, span.y), EDGE_HI)
	edges.draw_rect(Rect2(0.0, span.y - EDGE_PX, span.x, EDGE_PX), EDGE_LO)
	edges.draw_rect(Rect2(span.x - EDGE_PX, 0.0, EDGE_PX, span.y), EDGE_LO)


func _draw_odds_bar() -> void:
	var span: Vector2 = odds_bar.size
	odds_bar.draw_rect(Rect2(Vector2.ZERO, span), BAR_BG)
	var inner_w: float = span.x - BAR_PAD * 2.0
	var cell_w: float = (inner_w - float(BAR_CELLS - 1) * BAR_GAP) / float(BAR_CELLS)
	var cell_h: float = bar_cell_height()
	var fills: PackedColorArray = bar_cell_colors()
	for i in BAR_CELLS:
		var x: float = BAR_PAD + float(i) * (cell_w + BAR_GAP)
		odds_bar.draw_rect(Rect2(x, BAR_PAD, cell_w, cell_h), fills[i])


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if GuiFrameStack.top() != self:
		return
	press_cancel()
	get_viewport().set_input_as_handled()


static func _odds_color(odds: int) -> Color:
	if odds >= 60:
		return GREEN
	if odds >= 40:
		return YELLOW
	return RED
