class_name LoanCard extends PanelContainer

#One row of the loan list. The same scene draws the four kinds a LoanRows row can carry: an
#offer, a sent request, an active loan and a closed one.

signal review_pressed(offer_id: int)
signal pay_off_pressed(loan_id: int)
signal dismiss_pressed(offer_id: int)

const PAD_H: int = 14
const PAD_V: int = 14
const RIGHT_WIDTH: float = 170.0
const BUTTON_HEIGHT: float = 40.0
const TEAM_WIDTH: float = 150.0
const PORTRAIT_SIDE: float = 32.0
const REQUEST_GREY: Color = Color(0.72, 0.76, 0.82, 1.0)
const CLOSED_ALPHA: float = 0.8
const BLOCK_ALPHA: float = 0.45
const BLOCK_TIP: String = "Not enough notes"
const EXPIRED_ALPHA: float = 0.45
const EXPIRED_TEXT: String = "EXPIRED"
const EXPIRED_FONT_SIZE: int = 20
const SCENE_PATH: String = "res://Scenes/GUI/Finance/Loans/LoanCard.tscn"

var _row: Dictionary = {}
var _specs: Array[Dictionary] = []
var _action: Button = null
var _strip: LoanPaymentCells = null
var _dot: NotificationDot = null
var _team_art: Array[MercPortrait] = []
var _overlay: Label = null


func _ready() -> void:
	add_theme_stylebox_override("panel", LoanStyle.padded(GuiColors.ROW_FILL, PAD_H, PAD_V, PAD_H,
		PAD_V))
	if not _row.is_empty():
		_rebuild()


func set_row(row: Dictionary) -> void:
	_row = row
	if is_node_ready():
		_rebuild()


func kind() -> StringName:
	return StringName(_row.get("kind", &""))


func row_id() -> int:
	return int(_row.get("id", -1))


func cell_count() -> int:
	return _specs.size()


func cell_caption(index: int) -> String:
	if index < 0 or index >= _specs.size():
		return ""
	return String(_specs[index]["caption"])


func cell_text(index: int) -> String:
	if index < 0 or index >= _specs.size():
		return ""
	return String(_specs[index]["text"])


func cell_color(index: int) -> Color:
	if index < 0 or index >= _specs.size():
		return GuiColors.CREAM
	return _specs[index]["color"] as Color


func payment_cells() -> LoanPaymentCells:
	return _strip


func action_button() -> Button:
	return _action


func team_portrait(index: int) -> MercPortrait:
	if index < 0 or index >= _team_art.size():
		return null
	return _team_art[index]


func team_face_count() -> int:
	return _team_art.size()


func dot_on() -> bool:
	return _dot != null and _dot.visible


func dot() -> NotificationDot:
	return _dot


func expired() -> bool:
	return bool(_row.get("expired", false))


func overlay() -> Label:
	return _overlay


func can_press() -> bool:
	if kind() == LoanRows.KIND_ACTIVE:
		return bool(_row.get("can_pay", false))
	return kind() == LoanRows.KIND_OFFER


func press_action() -> void:
	if not can_press():
		UiSfx.reject_press(_action)
		return
	if kind() == LoanRows.KIND_OFFER:
		if expired():
			dismiss_pressed.emit(row_id())
		else:
			review_pressed.emit(row_id())
	elif kind() == LoanRows.KIND_ACTIVE:
		pay_off_pressed.emit(row_id())


func _rebuild() -> void:
	GuiNodes.clear(self)
	_specs = []
	_team_art = []
	_action = null
	_strip = null
	_dot = null
	_overlay = null
	modulate = Color.WHITE
	var row_kind: StringName = kind()
	if row_kind == LoanRows.KIND_REQUEST:
		modulate = REQUEST_GREY
	elif row_kind == LoanRows.KIND_CLOSED:
		modulate = Color(1.0, 1.0, 1.0, CLOSED_ALPHA)
	var columns: HBoxContainer = GuiStyle.hbox(16)
	var left: VBoxContainer = GuiStyle.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_header())
	_specs = _cell_specs(row_kind)
	left.add_child(_cell_grid())
	var extra: Control = _extra_row(row_kind)
	if extra != null:
		left.add_child(extra)
	columns.add_child(left)
	var right: Control = _right_column(row_kind)
	if right != null:
		columns.add_child(right)
	if expired():
		columns.modulate = Color(1.0, 1.0, 1.0, EXPIRED_ALPHA)
	add_child(columns)
	if expired():
		_overlay = _build_overlay()
		add_child(_overlay)
	if row_kind == LoanRows.KIND_OFFER and not expired() and _action != null:
		if bool(_row.get("unread", false)):
			_dot = NotificationDot.attach(_action)


#The overlay is its own direct child of this PanelContainer, not nested in the dimmed columns
#subtree, so it fits the same content rect at its own, undimmed alpha and draws above it.
func _build_overlay() -> Label:
	var label: Label = GuiStyle.label(EXPIRED_TEXT, GuiStyle.SILK_BOLD, EXPIRED_FONT_SIZE, GuiColors.RED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _header() -> HBoxContainer:
	var text: Dictionary = _row.get("text", {}) as Dictionary
	var line: HBoxContainer = GuiStyle.hbox(10)
	line.add_child(GuiStyle.label(String(text.get("lender", "")), GuiStyle.SILK_BOLD, 14, GuiColors.CREAM))
	line.add_child(GuiStyle.notes(int(_row.get("amount", 0)), 13, GuiColors.SKY))
	line.add_child(GuiStyle.label(String(text.get("terms", "")), GuiStyle.SILK, 11, GuiColors.MUTED))
	return line


func _cell_grid() -> HBoxContainer:
	var grid: HBoxContainer = GuiStyle.hbox(8)
	for spec: Dictionary in _specs:
		var value: Control = LoanStyle.value_cell(bool(spec.get("notes", false)), 13, spec["color"] as Color)
		LoanStyle.set_value(value, String(spec.get("text", "")), int(spec.get("amount", 0)))
		var cell: PanelContainer = GuiStyle.stat_cell(String(spec["caption"]), value)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sub: String = String(spec.get("sub", ""))
		if sub != "":
			var col: VBoxContainer = cell.get_child(0) as VBoxContainer
			col.add_child(GuiStyle.label(sub, GuiStyle.SILK, 9, GuiColors.MUTED))
		grid.add_child(cell)
	return grid


func _cell_specs(row_kind: StringName) -> Array[Dictionary]:
	var text: Dictionary = _row.get("text", {}) as Dictionary
	var monthly: Dictionary = {"caption": "Monthly Payment", "text": String(text.get("monthly",
		"")), "color": GuiColors.CREAM, "notes": true, "amount": int(_row.get("monthly", 0))}
	if row_kind == LoanRows.KIND_OFFER:
		return [{"caption": "Offered", "text": String(text.get("amount", "")),
			"color": GuiColors.GREEN, "notes": true, "amount": int(_row.get("amount", 0))},
			monthly,
			{"caption": "First Payment Due", "text": String(text.get("first_due", "")),
			"color": GuiColors.CREAM},
			{"caption": "Offer Expires In", "text": String(text.get("deadline", "")),
			"color": LoanLogic.deadline_color(float(_row.get("hours", 0.0)))}]
	if row_kind == LoanRows.KIND_REQUEST:
		return [{"caption": "Requested", "text": String(text.get("amount", "")),
			"color": GuiColors.AMBER, "notes": true, "amount": int(_row.get("amount", 0))},
			monthly,
			{"caption": "Approval Odds", "text": String(text.get("odds", "")),
			"color": LoanLogic.odds_color(int(_row.get("odds", 0)))}]
	if row_kind == LoanRows.KIND_ACTIVE:
		return [{"caption": "Remaining", "text": String(text.get("remaining", "")),
			"color": GuiColors.RED, "notes": true, "amount": int(_row.get("remaining", 0))},
			monthly,
			{"caption": "Next Due", "text": String(text.get("due", "")),
			"color": GuiColors.CREAM, "sub": String(text.get("due_rel", ""))}]
	return [{"caption": "Total Paid", "text": String(text.get("total_paid", "")),
		"color": GuiColors.CREAM, "notes": true, "amount": int(_row.get("total_paid", 0))},
		monthly,
		{"caption": "Interest Paid", "text": String(text.get("interest", "")),
		"color": GuiColors.RED, "notes": true, "amount": int(_row.get("interest", 0))}]


func _extra_row(row_kind: StringName) -> Control:
	var text: Dictionary = _row.get("text", {}) as Dictionary
	if row_kind == LoanRows.KIND_REQUEST:
		var team: Array = _row.get("team_rows", []) as Array
		if team.is_empty():
			return GuiStyle.label(LoanRows.NO_TEAM_TEXT, GuiStyle.BODY, 12, GuiColors.DIM_TEXT)
		var line: HBoxContainer = GuiStyle.hbox(8)
		for raw: Variant in team:
			line.add_child(_team_module(raw as Dictionary))
		return line
	if row_kind == LoanRows.KIND_ACTIVE or row_kind == LoanRows.KIND_CLOSED:
		var col: VBoxContainer = GuiStyle.vbox(4)
		_strip = LoanPaymentCells.new()
		_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(_strip)
		_strip.set_rows(FinanceManager.payment_rows(row_id()))
		col.add_child(GuiStyle.label(String(text.get("progress", "")), GuiStyle.SILK, 10, GuiColors.MUTED))
		return col
	return null


func _team_module(row: Dictionary) -> PanelContainer:
	var module: PanelContainer = LoanStyle.envoy_card(row, PORTRAIT_SIDE, _team_art, false)
	module.custom_minimum_size = Vector2(TEAM_WIDTH, 0.0)
	return module


func _right_column(row_kind: StringName) -> Control:
	if row_kind == LoanRows.KIND_CLOSED:
		return null
	var text: Dictionary = _row.get("text", {}) as Dictionary
	var col: VBoxContainer = GuiStyle.vbox(6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.custom_minimum_size = Vector2(RIGHT_WIDTH, 0.0)
	if row_kind == LoanRows.KIND_REQUEST:
		col.add_child(GuiStyle.label(String(text.get("right", "")), GuiStyle.SILK, 11, GuiColors.SKY))
		return col
	var fill: Color = GuiColors.GREEN
	if row_kind == LoanRows.KIND_OFFER:
		fill = GuiColors.RED if expired() else GuiColors.AMBER
	_action = LoanStyle.button(String(text.get("right", "")), fill, GuiColors.INK,
		BUTTON_HEIGHT)
	_action.pressed.connect(press_action)
	if not can_press():
		_action.modulate = Color(1.0, 1.0, 1.0, BLOCK_ALPHA)
		_action.tooltip_text = BLOCK_TIP
	col.add_child(_action)
	col.add_child(GuiStyle.label(String(text.get("note", "")), GuiStyle.BODY, 12, GuiColors.DIM_TEXT))
	return col
