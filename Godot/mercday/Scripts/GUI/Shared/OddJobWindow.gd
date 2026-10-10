class_name OddJobWindow extends ModalDialog

#The modal Odd Job dialog: facts, the shared crew block, success odds and the send/cancel pair.
#Reused as-is by Legal, Promotions, Hiring and the loan request (wave 3), each supplying its own
#config. The window never spends notes; the host spends on the sent signal.

signal sent(team: Array[int], per: int)

const TITLE_COLOR: Color = GuiColors.ORANGE
const FACT_LABEL_COLOR: Color = GuiColors.SKY
const FACT_VALUE_DEFAULT: Color = GuiColors.CREAM
const FACT_STYLE: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/dark_cell.tres")
const ODDS_LABEL_COLOR: Color = GuiColors.ORANGE
const BAR_CELLS: int = 20
const FACT_GAP: int = 8
const BAR_HEIGHT: float = 16.0
const BAR_GAP: float = 2.0
const BAR_PAD: float = 2.0
const BAR_UNLIT: Color = GuiColors.BLUE_LO
const BAR_BG: Color = GuiColors.INK
const BOOST_COLOR: Color = GuiColors.GREEN
const CANCEL_BG: Color = GuiColors.BLUE
const CANCEL_HI: Color = GuiColors.BLUE_HI
const SEND_BG: Color = GuiColors.GREEN
const SEND_TEXT: Color = GuiColors.INK
const SEND_HI: Color = GuiColors.GREEN_HI
const OUTCOME_COLOR: Color = GuiColors.SKY
const DISABLED_TINT: Color = Color(0.6, 0.6, 0.6, 0.45)
const BEVEL_DROP: float = 0.35

@onready var facts_grid: GridContainer = $Box/Pad/Rows/FactsGrid
@onready var crew_node: OddJobCrew = $Box/Pad/Rows/Crew
@onready var odds_row: HBoxContainer = $Box/Pad/Rows/OddsRow
@onready var odds_label_node: Label = $Box/Pad/Rows/OddsRow/OddsLabel
@onready var odds_value_label: Label = $Box/Pad/Rows/OddsRow/OddsValue
@onready var odds_bar: Control = $Box/Pad/Rows/OddsBar
@onready var boost_label: Label = $Box/Pad/Rows/BoostText
@onready var outcome_label: Label = $Box/Pad/Rows/OutcomeText

var send_button: BevelButton = null
var _odds_fn: Callable = Callable()
var _money: int = 0
var _odds_label: String = "Success Odds"
var _last_odds: int = 0
var _last_team_empty: bool = true


func _ready() -> void:
	super()
	send_button = confirm_button
	rows.move_child(outcome_label, rows.get_child_count() - 1)
	odds_bar.draw.connect(_draw_odds_bar)
	confirmed.connect(_on_confirmed)
	crew_node.team_changed.connect(_on_team_changed)
	crew_node.pay_changed.connect(_on_pay_changed)
	_style_static()


func open(config: Dictionary) -> void:
	title = str(config.get("title", ""))
	_build_facts(config.get("facts", []))
	_odds_fn = config.get("odds", Callable())
	_odds_label = str(config.get("odds_label", "Success Odds"))
	odds_label_node.text = _odds_label
	confirm_text = str(config.get("send_label", "Send"))
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
	present()


func crew() -> OddJobCrew:
	return crew_node


func press_send() -> void:
	press_confirm()


#Test probe: writes an outcome line in green for a success or red for a failure.
func show_outcome(text: String, ok: bool) -> void:
	outcome_label.text = text
	outcome_label.add_theme_color_override(&"font_color", GuiColors.GREEN if ok else GuiColors.RED)


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
	var lit_color: Color = GuiTypes.odds_color(_last_odds)
	for i in BAR_CELLS:
		out.append(lit_color if bar_cell_lit(i) else BAR_UNLIT)
	return out


#Test probe: the odds percent last computed (0 while the team is empty).
func odds_percent() -> int:
	return _last_odds


func _on_confirm() -> bool:
	return not send_button.disabled


func _on_confirmed() -> void:
	sent.emit(crew_node.team, crew_node.per)


func _on_team_changed(_team: Array[int]) -> void:
	_refresh_odds()
	_refresh_send()
	_refit()


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
	odds_value_label.add_theme_color_override(&"font_color", GuiTypes.odds_color(odds))
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


func _build_facts(facts: Array) -> void:
	GuiNodes.clear(facts_grid)
	for row: Dictionary in facts:
		var cell := PanelContainer.new()
		cell.add_theme_stylebox_override(&"panel", CrewPanel.style(FACT_STYLE))
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var line := HBoxContainer.new()
		line.add_theme_constant_override(&"separation", FACT_GAP)
		line.add_child(GuiStyle.label(str(row.get("label", "")), GuiStyle.SILK, 9, FACT_LABEL_COLOR))
		var color: Color = row.get("color", FACT_VALUE_DEFAULT)
		var value_node: Label = GuiStyle.label(str(row.get("value", "")), GuiStyle.SILK_BOLD, 12, color)
		value_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(value_node)
		cell.add_child(line)
		facts_grid.add_child(cell)


func _style_static() -> void:
	title_label.add_theme_color_override(&"font_color", TITLE_COLOR)
	facts_grid.columns = 4
	facts_grid.add_theme_constant_override(&"h_separation", FACT_GAP)
	facts_grid.add_theme_constant_override(&"v_separation", FACT_GAP)
	odds_label_node.text = _odds_label
	GuiStyle.paint(odds_label_node, GuiStyle.SILK, 11, ODDS_LABEL_COLOR)
	odds_value_label.add_theme_font_override(&"font", GuiStyle.SILK_BOLD)
	odds_value_label.add_theme_font_size_override(&"font_size", 20)
	odds_bar.custom_minimum_size = Vector2(0.0, BAR_HEIGHT)
	boost_label.add_theme_font_size_override(&"font_size", 13)
	boost_label.add_theme_color_override(&"font_color", BOOST_COLOR)
	cancel_button.add_theme_font_override(&"font", GuiStyle.SILK)
	cancel_button.add_theme_font_size_override(&"font_size", 12)
	send_button.add_theme_font_override(&"font", GuiStyle.SILK_BOLD)
	send_button.add_theme_font_size_override(&"font_size", 13)
	outcome_label.add_theme_font_size_override(&"font_size", 13)
	outcome_label.add_theme_color_override(&"font_color", OUTCOME_COLOR)
	outcome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


#Every sync writes the kind palette back, so the pair takes its own shading after it. The colours
#go through the export set, since a BevelButton blanks every stylebox of its own in the tree.
func _sync_buttons() -> void:
	super()
	_paint_button(cancel_button, CANCEL_BG, CANCEL_HI, FACT_VALUE_DEFAULT)
	_paint_button(confirm_button, SEND_BG, SEND_HI, SEND_TEXT)


func _paint_button(host: BevelButton, bg: Color, edge_hi: Color, tint: Color) -> void:
	if host == null:
		return
	host.set_colors(bg, edge_hi, bg.darkened(BEVEL_DROP), tint)


func _draw_odds_bar() -> void:
	var span: Vector2 = odds_bar.size
	odds_bar.draw_rect(Rect2(Vector2.ZERO, span), BAR_BG)
	var inner_w: float = span.x - BAR_PAD * 2.0
	var cell_w: float = (inner_w - float(BAR_CELLS - 1) * BAR_GAP) / float(BAR_CELLS)
	CellBar.paint(odds_bar, Vector2(BAR_PAD, BAR_PAD), Vector2(cell_w, bar_cell_height()),
		cell_w + BAR_GAP, bar_cell_colors())
