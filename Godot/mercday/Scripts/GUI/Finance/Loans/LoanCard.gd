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
const PORTRAIT_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/MercPortrait.tscn")

var _row: Dictionary = {}
var _specs: Array[Dictionary] = []
var _action: Button = null
var _strip: LoanPaymentCells = null
var _dot: NotificationDot = null
var _team_art: Array[MercPortrait] = []
var _overlay: Label = null


func _ready() -> void:
	add_theme_stylebox_override("panel", LoanStyle.padded(LoanStyle.NAVY, PAD_H, PAD_V, PAD_H,
		PAD_V))
	if not _row.is_empty():
		_rebuild()


func set_row(row: Dictionary) -> void:
	_row = row
	if is_node_ready():
		_rebuild()


#PanelContainer fits every visible direct child into its own content rect on this notification,
#which would otherwise pull the corner-pinned dot in to the panel's padding. Runs after the base
#class, so this always has the last word for the frame.
func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN and _dot != null:
		_dot.repin()


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
		return LoanStyle.CREAM
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
		return
	if kind() == LoanRows.KIND_OFFER:
		if expired():
			dismiss_pressed.emit(row_id())
		else:
			review_pressed.emit(row_id())
	elif kind() == LoanRows.KIND_ACTIVE:
		pay_off_pressed.emit(row_id())


func _rebuild() -> void:
	for child: Node in get_children():
		child.queue_free()
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
	var columns: HBoxContainer = LoanStyle.hbox(16)
	var left: VBoxContainer = LoanStyle.vbox(10)
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
	var label: Label = LoanStyle.text(EXPIRED_TEXT, EXPIRED_FONT_SIZE, LoanStyle.RED, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _header() -> HBoxContainer:
	var text: Dictionary = _row.get("text", {}) as Dictionary
	var line: HBoxContainer = LoanStyle.hbox(10)
	line.add_child(LoanStyle.text(String(text.get("lender", "")), 14, LoanStyle.CREAM, true))
	line.add_child(LoanStyle.notes(int(_row.get("amount", 0)), LoanStyle.SKY, 13))
	line.add_child(LoanStyle.text(String(text.get("terms", "")), 11, LoanStyle.MUTED))
	return line


func _cell_grid() -> HBoxContainer:
	var grid: HBoxContainer = LoanStyle.hbox(8)
	for spec: Dictionary in _specs:
		var value: Control = null
		if bool(spec.get("notes", false)):
			value = LoanStyle.notes(int(spec.get("amount", 0)), spec["color"] as Color, 13)
		else:
			value = LoanStyle.text(String(spec["text"]), 13, spec["color"] as Color, true)
		var cell: PanelContainer = LoanStyle.stat_cell(String(spec["caption"]), value)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sub: String = String(spec.get("sub", ""))
		if sub != "":
			var col: VBoxContainer = cell.get_child(0) as VBoxContainer
			col.add_child(LoanStyle.text(sub, 9, LoanStyle.MUTED))
		grid.add_child(cell)
	return grid


func _cell_specs(row_kind: StringName) -> Array[Dictionary]:
	var text: Dictionary = _row.get("text", {}) as Dictionary
	var monthly: Dictionary = {"caption": "Monthly Payment", "text": String(text.get("monthly",
		"")), "color": LoanStyle.CREAM, "notes": true, "amount": int(_row.get("monthly", 0))}
	if row_kind == LoanRows.KIND_OFFER:
		return [{"caption": "Offered", "text": String(text.get("amount", "")),
			"color": LoanStyle.GREEN, "notes": true, "amount": int(_row.get("amount", 0))},
			monthly,
			{"caption": "First Payment Due", "text": String(text.get("first_due", "")),
			"color": LoanStyle.CREAM},
			{"caption": "Offer Expires In", "text": String(text.get("deadline", "")),
			"color": LoanLogic.deadline_color(float(_row.get("hours", 0.0)))}]
	if row_kind == LoanRows.KIND_REQUEST:
		return [{"caption": "Requested", "text": String(text.get("amount", "")),
			"color": LoanStyle.YELLOW, "notes": true, "amount": int(_row.get("amount", 0))},
			monthly,
			{"caption": "Approval Odds", "text": String(text.get("odds", "")),
			"color": LoanLogic.odds_color(int(_row.get("odds", 0)))}]
	if row_kind == LoanRows.KIND_ACTIVE:
		return [{"caption": "Remaining", "text": String(text.get("remaining", "")),
			"color": LoanStyle.RED, "notes": true, "amount": int(_row.get("remaining", 0))},
			monthly,
			{"caption": "Next Due", "text": String(text.get("due", "")),
			"color": LoanStyle.CREAM, "sub": String(text.get("due_rel", ""))}]
	return [{"caption": "Total Paid", "text": String(text.get("total_paid", "")),
		"color": LoanStyle.CREAM, "notes": true, "amount": int(_row.get("total_paid", 0))},
		monthly,
		{"caption": "Interest Paid", "text": String(text.get("interest", "")),
		"color": LoanStyle.RED, "notes": true, "amount": int(_row.get("interest", 0))}]


func _extra_row(row_kind: StringName) -> Control:
	var text: Dictionary = _row.get("text", {}) as Dictionary
	if row_kind == LoanRows.KIND_REQUEST:
		var team: Array = _row.get("team_rows", []) as Array
		if team.is_empty():
			return LoanStyle.body(LoanRows.NO_TEAM_TEXT, 12, LoanStyle.DIM_TEXT)
		var line: HBoxContainer = LoanStyle.hbox(8)
		for raw: Variant in team:
			line.add_child(_team_module(raw as Dictionary))
		return line
	if row_kind == LoanRows.KIND_ACTIVE or row_kind == LoanRows.KIND_CLOSED:
		var col: VBoxContainer = LoanStyle.vbox(4)
		_strip = LoanPaymentCells.new()
		_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(_strip)
		_strip.set_rows(FinanceManager.payment_rows(row_id()))
		col.add_child(LoanStyle.text(String(text.get("progress", "")), 10, LoanStyle.MUTED))
		return col
	return null


func _team_module(row: Dictionary) -> PanelContainer:
	var box: PanelContainer = LoanStyle.panel(LoanStyle.NAVY2, 8, 6)
	box.custom_minimum_size = Vector2(TEAM_WIDTH, 0.0)
	var line: HBoxContainer = LoanStyle.hbox(8)
	line.add_child(_team_face(row))
	var col: VBoxContainer = LoanStyle.vbox(4)
	col.add_child(LoanStyle.text(String(row.get("name", "")), 9, LoanStyle.CREAM, true))
	var stars := FitStars.new()
	stars.cell = 1
	stars.value = float(row.get("fit", 0.5))
	col.add_child(stars)
	line.add_child(col)
	box.add_child(line)
	return box


#A team merc draws its own portrait; a row without a uid keeps the hatch placeholder.
func _team_face(row: Dictionary) -> Control:
	var uid: int = int(row.get("uid", 0))
	if uid <= 0:
		return LoanGlyphs.portrait(PORTRAIT_SIDE)
	var face: MercPortrait = PORTRAIT_SCENE.instantiate() as MercPortrait
	if face == null:
		return LoanGlyphs.portrait(PORTRAIT_SIDE)
	face.pixel_size = int(PORTRAIT_SIDE)
	face.merc_uid = uid
	face.tooltip_text = String(row.get("name", ""))
	_team_art.append(face)
	return face


func _right_column(row_kind: StringName) -> Control:
	if row_kind == LoanRows.KIND_CLOSED:
		return null
	var text: Dictionary = _row.get("text", {}) as Dictionary
	var col: VBoxContainer = LoanStyle.vbox(6)
	col.custom_minimum_size = Vector2(RIGHT_WIDTH, 0.0)
	if row_kind == LoanRows.KIND_REQUEST:
		col.add_child(LoanStyle.text(String(text.get("right", "")), 11, LoanStyle.SKY))
		return col
	var fill: Color = LoanStyle.GREEN
	if row_kind == LoanRows.KIND_OFFER:
		fill = LoanStyle.RED if expired() else LoanStyle.YELLOW
	_action = LoanStyle.button(String(text.get("right", "")), fill, LoanStyle.INK,
		BUTTON_HEIGHT)
	_action.pressed.connect(press_action)
	if not can_press():
		_action.modulate = Color(1.0, 1.0, 1.0, BLOCK_ALPHA)
		_action.tooltip_text = BLOCK_TIP
	col.add_child(_action)
	col.add_child(LoanStyle.body(String(text.get("note", "")), 12, LoanStyle.DIM_TEXT))
	return col
