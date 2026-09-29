class_name PermitRequestDialog extends Control

#The modal behind a Request button on the Permits tab: the two permits of one location and the
#standing the guild holds there. It asks the shared confirm before it spends and reports the
#answer to the viewer; it never moves notes itself.

signal permit_requested(loc_id: int, kind: StringName)
signal review_pressed(kind: StringName, id: int)
signal closed

const ROW_SCENE: PackedScene = preload("res://Scenes/GUI/Legal/PermitRow.tscn")
const VIOLATION_SCENE: PackedScene = preload("res://Scenes/GUI/Legal/ViolationRow.tscn")
const BOX_WIDTH: int = 520
const LIST_MAX_HEIGHT: int = 220
#The close art sits CLOSE_INSET in from the box corner, 30 px of art past a 3 px outline ring.
const CLOSE_INSET: float = 10.0
const KICKER_TEXT: String = "Request"
const STANDING_HEAD: String = "Good Standing"
const CLEAN_TEXT: String = "No fines or captured mercs in this location."
const CONFIRM_TITLE: String = "Request Permit"
const CONFIRM_CTA: String = "Request"
const CONFIRM_CANCEL: String = "Cancel"
const OPS_NAME: String = "Operations Permit"
const TELE_NAME: String = "Teleportation Permit"

var loc_id: int = -1

var box: PanelContainer = null
var kicker_label: Label = null
var title_label: Label = null
var standing_label: Label = null
var list: VBoxContainer = null
var list_scroll: ScrollContainer = null
var close_button: Button = null
var ops_row: PermitRow = null
var tele_row: PermitRow = null

var confirm: ConfirmDialog = null

var _pending: StringName = &""

#The backdrop and the centring frame ModalFrame keeps over the whole viewport.
var _backdrop: ColorRect = null
var _centre: CenterContainer = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()
	ModalFrame.fit(self, _backdrop, _centre)
	LegalManager.permits_changed.connect(_on_permits_changed)


func _exit_tree() -> void:
	GuiFrameStack.remove(self)


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
	_build()
	_refresh()
	visible = true
	ModalFrame.fit(self, _backdrop, _centre)
	GuiFrameStack.push(self)


func close() -> void:
	if not visible:
		return
	visible = false
	GuiFrameStack.remove(self)
	closed.emit()


func press_close() -> void:
	if close_button != null and close_button.visible:
		close_button.pressed.emit()


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


func kicker_text() -> String:
	return kicker_label.text if kicker_label != null else ""


func title_text() -> String:
	return title_label.text if title_label != null else ""


func standing_text() -> String:
	return standing_label.text if standing_label != null else ""


func is_clean() -> bool:
	return loc_id >= 0 and LegalManager.good_standing(loc_id)


func close_visible() -> bool:
	return close_button != null and close_button.visible


func _build() -> void:
	if box != null:
		return
	_backdrop = LegalStyle.backdrop()
	add_child(_backdrop)
	_centre = CenterContainer.new()
	_centre.name = "Centre"
	_centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_centre)
	box = PanelContainer.new()
	box.name = "Box"
	box.custom_minimum_size = Vector2(BOX_WIDTH, 0)
	box.add_theme_stylebox_override(&"panel", LegalStyle.dialog_style())
	_centre.add_child(box)
	var rows: VBoxContainer = LegalStyle.vbox(10)
	rows.name = "Rows"
	box.add_child(rows)
	kicker_label = LegalStyle.text(KICKER_TEXT, 12, LegalStyle.SKY)
	rows.add_child(kicker_label)
	title_label = LegalStyle.pixel("", 18, LegalStyle.CREAM, true)
	rows.add_child(title_label)
	rows.add_child(LegalStyle.divider(LegalStyle.BLUE, 2))
	ops_row = _permit_row(LegalManager.PERMIT_OPS)
	rows.add_child(ops_row)
	tele_row = _permit_row(LegalManager.PERMIT_TELE)
	rows.add_child(tele_row)
	rows.add_child(LegalStyle.divider(LegalStyle.BLUE, 2))
	rows.add_child(LegalStyle.head(STANDING_HEAD))
	standing_label = LegalStyle.text(CLEAN_TEXT, 12, LegalStyle.MUTED)
	rows.add_child(standing_label)
	list_scroll = ScrollContainer.new()
	list_scroll.name = "Violations"
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	list_scroll.custom_minimum_size = Vector2(0, 0)
	list_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	list = LegalStyle.vbox(6)
	list.name = "Rows"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(list)
	rows.add_child(list_scroll)
	_add_close()


func _permit_row(kind: StringName) -> PermitRow:
	var row: PermitRow = ROW_SCENE.instantiate() as PermitRow
	row.name = "Ops" if kind == LegalManager.PERMIT_OPS else "Tele"
	row.kind = kind
	row.request_pressed.connect(_on_row_request)
	return row


#A Container would stretch the X, so the overlay that holds it is a plain Control.
func _add_close() -> void:
	var overlay := Control.new()
	overlay.name = "Overlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	close_button = CloseX.make(CloseX.SCALE_WINDOW)
	close_button.name = "CloseX"
	close_button.tooltip_text = "Close"
	close_button.pressed.connect(close)
	overlay.add_child(close_button)
	add_child(overlay)
	_place_close()


func _place_close() -> void:
	if close_button == null or box == null:
		return
	close_button.global_position = box.global_position + Vector2(
		box.size.x - CLOSE_INSET - 30.0 - 3.0, CLOSE_INSET - 3.0)


func _refresh() -> void:
	if box == null:
		return
	var place: LegalLocationData = LegalManager.location(loc_id)
	var nation: String = place.nation if place != null else ""
	kicker_label.text = KICKER_TEXT + LegalManager.LABEL_JOIN + nation
	title_label.text = place.name if place != null else ""
	ops_row.location_id = loc_id
	tele_row.location_id = loc_id
	_fill_violations()
	_place_close()


func _fill_violations() -> void:
	var rows: Array[Dictionary] = LegalManager.violations(loc_id) if loc_id >= 0 else []
	while list.get_child_count() > rows.size():
		var last: Node = list.get_child(list.get_child_count() - 1)
		list.remove_child(last)
		last.queue_free()
	while list.get_child_count() < rows.size():
		var made: ViolationRow = VIOLATION_SCENE.instantiate() as ViolationRow
		made.name = "Case%d" % list.get_child_count()
		made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		made.review_pressed.connect(_on_review)
		list.add_child(made)
	for i: int in range(rows.size()):
		var row: ViolationRow = list.get_child(i) as ViolationRow
		if row != null:
			row.entry = rows[i]
	standing_label.text = CLEAN_TEXT if rows.is_empty() else _open_text(rows.size())
	standing_label.add_theme_color_override(&"font_color",
		LegalStyle.MUTED if rows.is_empty() else LegalStyle.AMBER)
	list_scroll.visible = not rows.is_empty()
	list_scroll.custom_minimum_size = Vector2(0, float(mini(LIST_MAX_HEIGHT, rows.size() * 74)))


static func _open_text(n: int) -> String:
	if n == 1:
		return "1 open case in this location."
	return "%d open cases in this location." % n


func _confirm_message(kind: StringName) -> String:
	var place: LegalLocationData = LegalManager.location(loc_id)
	var where: String = place.name if place != null else "this location"
	var permit: String = TELE_NAME if kind == LegalManager.PERMIT_TELE else OPS_NAME
	var cost: int = LegalManager.permit_cost(loc_id, kind)
	return "Request the %s for %s for %s notes?" % [permit, where,
		NotesLabel.format_amount(cost)]


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
	if close_button != null:
		close_button.visible = false


func _on_confirm_hidden() -> void:
	if close_button != null:
		close_button.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if GuiFrameStack.consume_escape(self, event):
		close()
