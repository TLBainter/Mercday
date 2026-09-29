class_name CapturedRow extends PanelContainer

#One line of the Bailout tab: the held merc, where and what, how much of the sentence is served
#and left, the bail owed now and the Review button.

signal review_pressed(id: int)

const PORTRAIT_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/MercPortrait.tscn")
const COL_FACE: int = 56
const COL_SERVED: int = 120
const COL_LEFT: int = 130
const COL_BAIL: int = 130
const COL_ACTION: int = 150
const PORTRAIT_PX: int = 48
const REVIEW_WIDTH: int = 96
const REVIEW_HEIGHT: int = 30
const REVIEW_TEXT: String = "Review"

var entry: CaptureData = null:
	set(value):
		entry = value
		_refresh()

var face_box: PanelContainer = null
var portrait: MercPortrait = null
var title_label: Label = null
var served_label: Label = null
var left_label: Label = null
var bail_label: NotesLabel = null
var review_button: Button = null
var dot: NotificationDot = null


func _ready() -> void:
	_build()
	_refresh()


func press_review() -> void:
	if review_button != null and not review_button.disabled:
		review_button.pressed.emit()


#PanelContainer fits every visible direct child into its own content rect on this notification,
#which would otherwise pull the corner-pinned dot in to the panel's padding. Runs after the base
#class, so this always has the last word for the frame.
func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN and dot != null:
		dot.repin()


func row_id() -> int:
	return entry.id if entry != null else -1


func merc_uid() -> int:
	return entry.merc_uid if entry != null else 0


#"Bram - Saltmarsh - Smuggling": merc, location and crime on one line.
func title_text() -> String:
	if entry == null:
		return ""
	return LegalStyle.merc_name(entry.merc_uid) + LegalManager.LABEL_JOIN \
		+ LegalStyle.location_name(entry.location_id) + LegalManager.LABEL_JOIN + entry.crime


func served_days() -> int:
	return entry.served(GameState.day()) if entry != null else 0


func remaining_days() -> int:
	return entry.remaining(GameState.day()) if entry != null else 0


func served_text() -> String:
	return GuiDates.days_text(served_days()) if entry != null else ""


func remaining_text() -> String:
	if entry == null:
		return ""
	if remaining_days() <= 0:
		return "Released today"
	return GuiDates.days_text(remaining_days())


func bail_amount() -> int:
	return LegalManager.bail_due(entry) if entry != null else 0


func _build() -> void:
	if title_label != null:
		return
	add_theme_stylebox_override(&"panel", LegalStyle.row_style(LegalStyle.BLUE))
	var row: HBoxContainer = LegalStyle.hbox(10)
	row.name = "Row"
	row.add_child(_face_holder())
	title_label = LegalStyle.pixel("", 11, LegalStyle.CREAM, true)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	row.add_child(title_label)
	served_label = LegalStyle.pixel("", 11, LegalStyle.SKY)
	served_label.custom_minimum_size = Vector2(COL_SERVED, 0)
	row.add_child(served_label)
	left_label = LegalStyle.pixel("", 11, LegalStyle.AMBER)
	left_label.custom_minimum_size = Vector2(COL_LEFT, 0)
	row.add_child(left_label)
	bail_label = LegalStyle.notes(0, 13, LegalStyle.CREAM)
	bail_label.custom_minimum_size = Vector2(COL_BAIL, 0)
	row.add_child(bail_label)
	var action: Control = Control.new()
	action.name = "Action"
	action.custom_minimum_size = Vector2(COL_ACTION, REVIEW_HEIGHT)
	review_button = LegalStyle.button(REVIEW_TEXT, &"ButtonNeutral", REVIEW_HEIGHT)
	review_button.name = "Review"
	review_button.custom_minimum_size = Vector2(REVIEW_WIDTH, REVIEW_HEIGHT)
	review_button.pressed.connect(_on_review)
	action.add_child(review_button)
	row.add_child(action)
	add_child(row)
	dot = NotificationDot.attach(self, Vector2(2, 2), CORNER_TOP_LEFT)
	dot.on = false


func _face_holder() -> PanelContainer:
	face_box = LegalStyle.cell(LegalStyle.NAVY2)
	face_box.name = "Face"
	face_box.custom_minimum_size = Vector2(COL_FACE, COL_FACE)
	portrait = PORTRAIT_SCENE.instantiate() as MercPortrait
	portrait.name = "Portrait"
	portrait.pixel_size = PORTRAIT_PX
	face_box.add_child(portrait)
	return face_box


func _refresh() -> void:
	if title_label == null:
		return
	title_label.text = title_text()
	served_label.text = served_text()
	left_label.text = remaining_text()
	bail_label.amount = bail_amount()
	dot.on = entry != null and entry.unread
	portrait.set_merc(LegalStyle.merc_view(merc_uid()))


func _on_review() -> void:
	review_pressed.emit(row_id())
