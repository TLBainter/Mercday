class_name PermitRequestDialog extends ModalDialog

#The modal behind a Request button on the Permits tab: the two permits of one location and the
#standing the guild holds there. It asks the shared confirm before it spends and reports the
#answer to the viewer; it never moves notes itself.

signal permit_requested(loc_id: int, kind: StringName)
signal review_pressed(kind: StringName, id: int)

const ROW_SCENE: PackedScene = preload("res://Scenes/GUI/Legal/PermitRow.tscn")
const VIOLATION_SCENE: PackedScene = preload("res://Scenes/GUI/Legal/ViolationRow.tscn")
const LIST_MAX_HEIGHT: int = 220
const KICKER_TEXT: String = "Request"
const STANDING_HEAD: String = "Good Standing"
const CLEAN_TEXT: String = "No fines or captured mercs in this location."
const CONFIRM_TITLE: String = "Request Permit"
const CONFIRM_CTA: String = "Request"
const CONFIRM_CANCEL: String = "Cancel"

var loc_id: int = -1

var standing_label: Label = null
var list: VBoxContainer = null
var list_scroll: ScrollContainer = null
var ops_row: PermitRow = null
var tele_row: PermitRow = null

var confirm: ConfirmDialog = null

var _pending: StringName = &""


func _ready() -> void:
	super()
	_build()
	LegalManager.permits_changed.connect(_on_permits_changed)


#The viewer lends its one confirm so a dialog never owns a second copy.
func set_confirm(dialog: ConfirmDialog) -> void:
	confirm = dialog
	if confirm == null:
		return
	if not confirm.shown.is_connected(_on_confirm_shown):
		confirm.shown.connect(_on_confirm_shown)
	if not confirm.dialog_hidden.is_connected(_on_confirm_hidden):
		confirm.dialog_hidden.connect(_on_confirm_hidden)
	if not confirm.confirmed.is_connected(_on_confirmed):
		confirm.confirmed.connect(_on_confirmed)
	if not confirm.cancelled.is_connected(_on_cancelled):
		confirm.cancelled.connect(_on_cancelled)


func open(new_loc_id: int) -> void:
	loc_id = new_loc_id
	_refresh()
	present()


func press_permit(kind: StringName) -> void:
	var row: PermitRow = permit_row(kind)
	if row != null:
		row.press_request()


func press_review(index: int) -> void:
	var row: ViolationRow = violation_row(index)
	if row != null:
		row.press_review()


func permit_row(kind: StringName) -> PermitRow:
	if kind == LegalManager.PERMIT_TELE:
		return tele_row
	return ops_row


func violation_count() -> int:
	return list.get_child_count() if list != null else 0


func violation_row(index: int) -> ViolationRow:
	if list == null or index < 0 or index >= list.get_child_count():
		return null
	return list.get_child(index) as ViolationRow


func standing_text() -> String:
	return standing_label.text if standing_label != null else ""


func is_clean() -> bool:
	return loc_id >= 0 and LegalManager.good_standing(loc_id)


#The body rows go between the head and the hidden button row the base keeps last.
func _build() -> void:
	rows.add_child(LegalStyle.divider(GuiColors.BLUE_LO, 2))
	ops_row = _permit_row(LegalManager.PERMIT_OPS)
	rows.add_child(ops_row)
	tele_row = _permit_row(LegalManager.PERMIT_TELE)
	rows.add_child(tele_row)
	rows.add_child(LegalStyle.divider(GuiColors.BLUE_LO, 2))
	rows.add_child(LegalStyle.head(STANDING_HEAD))
	standing_label = GuiStyle.label(CLEAN_TEXT, GuiStyle.BODY, 12, GuiColors.MUTED)
	rows.add_child(standing_label)
	list_scroll = ScrollContainer.new()
	list_scroll.name = "Violations"
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	list_scroll.custom_minimum_size = Vector2(0, 0)
	list_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	list = GuiStyle.vbox(6)
	list.name = "Rows"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(list)
	rows.add_child(list_scroll)
	rows.move_child(button_row, rows.get_child_count() - 1)


func _permit_row(kind: StringName) -> PermitRow:
	var row: PermitRow = ROW_SCENE.instantiate() as PermitRow
	row.name = "Ops" if kind == LegalManager.PERMIT_OPS else "Tele"
	row.kind = kind
	row.request_pressed.connect(_on_row_request)
	return row


func _refresh() -> void:
	var place: LegalLocationData = LegalManager.location(loc_id)
	var nation: String = place.nation if place != null else ""
	kicker = KICKER_TEXT + LegalManager.LABEL_JOIN + nation
	title = place.name if place != null else ""
	ops_row.location_id = loc_id
	tele_row.location_id = loc_id
	_fill_violations()


func _fill_violations() -> void:
	var cases: Array[Dictionary] = LegalManager.violations(loc_id) if loc_id >= 0 else []
	for made: Node in LegalListPage.sync_pool(list, cases.size(), VIOLATION_SCENE):
		var case_row: ViolationRow = made as ViolationRow
		case_row.name = "Case%d" % case_row.get_index()
		case_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		case_row.review_pressed.connect(_on_review)
	for i: int in range(cases.size()):
		var row: ViolationRow = list.get_child(i) as ViolationRow
		if row != null:
			row.entry = cases[i]
	standing_label.text = CLEAN_TEXT if cases.is_empty() else _open_text(cases.size())
	standing_label.add_theme_color_override(&"font_color",
		GuiColors.MUTED if cases.is_empty() else GuiColors.AMBER)
	list_scroll.visible = not cases.is_empty()
	list_scroll.custom_minimum_size = Vector2(0, float(mini(LIST_MAX_HEIGHT, cases.size() * 74)))


static func _open_text(n: int) -> String:
	if n == 1:
		return "1 open case in this location."
	return "%d open cases in this location." % n


func _confirm_message(kind: StringName) -> String:
	var place: LegalLocationData = LegalManager.location(loc_id)
	var where: String = place.name if place != null else "this location"
	var permit: String = LegalStyle.permit_name(kind)
	var cost: int = LegalManager.permit_cost(loc_id, kind)
	return "Request the %s for %s for %s notes?" % [permit, where,
		TransactionData.grouped(cost)]


func _on_row_request(kind: StringName) -> void:
	if confirm == null:
		permit_requested.emit(loc_id, kind)
		return
	_pending = kind
	confirm.ask(CONFIRM_TITLE, _confirm_message(kind), CONFIRM_CTA, CONFIRM_CANCEL,
		ConfirmDialog.Severity.ORANGE, ConfirmDialog.Kind.GO)


#A permit bought while this dialog stands open turns its row to the standing at once.
func _on_permits_changed() -> void:
	if visible and loc_id >= 0:
		_refresh()


#A case row inside this dialog hands the case up; the viewer swaps this dialog for the Review.
func _on_review(kind: StringName, id: int) -> void:
	review_pressed.emit(kind, id)


func _on_confirmed() -> void:
	if _pending == &"":
		return
	var kind: StringName = _pending
	_pending = &""
	permit_requested.emit(loc_id, kind)


func _on_cancelled() -> void:
	_pending = &""


#The X hides while a confirm sits over this dialog, as the design asks.
func _on_confirm_shown() -> void:
	close_button.visible = false


func _on_confirm_hidden() -> void:
	close_button.visible = true
