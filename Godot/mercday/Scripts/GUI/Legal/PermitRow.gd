class_name PermitRow extends PanelContainer

#One permit of one location inside the request dialog: what it grants, what it costs and the one
#control that fits its state. A permit already on file shows its standing instead of a price, and
#a permit the plan does not reach shows the FeatureLock that names the upgrade.

signal request_pressed(kind: StringName)

const LOCK_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/FeatureLock.tscn")
const NOTES_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/NotesLabel.tscn")
const OPS_DESC: String = "Grants the right to conduct business in this location."
const TELE_DESC: String = ("Grants the right to use a teleportation circle to venture to/from "
	+ "this location.")
const INACTIVE_NOTE: String = "Permit kept on file. Usable again once the upgrade is restored."
const SCOPE_TEXT: Array[String] = ["most nations", "all nations", "other Domains"]
const UPGRADE_TIERS: int = 3
const LOCK_WIDTH: int = 150
#The entitlement keys the permit tiers stand behind.
const OPS_KEY: String = "opsPermits"
const TELE_KEY: String = "teleport"
const LOCK_HEIGHT: float = 36.0
const BUTTON_WIDTH: int = 96
const BUTTON_HEIGHT: int = 32
const RIGHT_WIDTH: int = 160

@export var location_id: int = -1:
	set(value):
		location_id = value
		_refresh()
@export var kind: StringName = &"":
	set(value):
		kind = value
		_refresh()

var title_label: Label = null
var desc_label: Label = null
var note_label: Label = null
var owned_label: Label = null
var price_notes: NotesLabel = null
var request_button: Button = null
var reason_label: Label = null
var lock: FeatureLock = null


func _ready() -> void:
	_build()
	_refresh()


func press_request() -> void:
	if request_button == null or request_button.disabled or not request_button.visible:
		return
	request_pressed.emit(kind)


func is_tele() -> bool:
	return kind == LegalManager.PERMIT_TELE


func title_text() -> String:
	return title_label.text if title_label != null else ""


func owned_text() -> String:
	if owned_label == null or not owned_label.visible:
		return ""
	return owned_label.text


func price_amount() -> int:
	return price_notes.amount if price_notes != null else 0


func request_visible() -> bool:
	return request_button != null and request_button.visible


func request_enabled() -> bool:
	return request_button != null and request_button.visible and not request_button.disabled


func reason_text() -> String:
	if reason_label == null or not reason_label.visible:
		return ""
	return reason_label.text


func lock_node() -> FeatureLock:
	return lock


func lock_visible() -> bool:
	return lock != null and lock.visible


func _build() -> void:
	if title_label != null:
		return
	add_theme_stylebox_override(&"panel", LegalStyle.row_style(LegalStyle.BLUE))
	var row: HBoxContainer = LegalStyle.hbox(14)
	row.name = "Row"
	var text_box: VBoxContainer = LegalStyle.vbox(3)
	text_box.name = "Text"
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label = LegalStyle.pixel("", 12, LegalStyle.CREAM, true)
	desc_label = LegalStyle.text("", 13, LegalStyle.SKY)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_label = LegalStyle.text(INACTIVE_NOTE, 12, LegalStyle.SKY)
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_label.visible = false
	text_box.add_child(title_label)
	text_box.add_child(desc_label)
	text_box.add_child(note_label)
	row.add_child(text_box)
	var right: VBoxContainer = LegalStyle.vbox(4)
	right.name = "Right"
	right.custom_minimum_size = Vector2(float(RIGHT_WIDTH), 0.0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	owned_label = LegalStyle.pixel("", 10, LegalStyle.GREEN)
	owned_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	owned_label.visible = false
	right.add_child(owned_label)
	price_notes = NOTES_SCENE.instantiate() as NotesLabel
	price_notes.name = "Price"
	price_notes.font_size = 14
	price_notes.bold = true
	price_notes.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(price_notes)
	request_button = LegalStyle.button("Request", &"ButtonGo", BUTTON_HEIGHT, 11)
	request_button.name = "Request"
	request_button.custom_minimum_size = Vector2(float(BUTTON_WIDTH), float(BUTTON_HEIGHT))
	request_button.add_theme_color_override(&"font_color", LegalStyle.CREAM)
	request_button.pressed.connect(press_request)
	right.add_child(request_button)
	reason_label = LegalStyle.text("", 11, LegalStyle.RED)
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason_label.visible = false
	right.add_child(reason_label)
	lock = LOCK_SCENE.instantiate() as FeatureLock
	lock.name = "Lock"
	lock.min_width = float(LOCK_WIDTH)
	lock.height = LOCK_HEIGHT
	lock.font_size = 11
	lock.verb = "request"
	lock.tiers = UPGRADE_TIERS
	lock.label = "Request"
	lock.size_flags_horizontal = Control.SIZE_FILL
	right.add_child(lock)
	row.add_child(right)
	add_child(row)


func _refresh() -> void:
	if title_label == null:
		return
	var tele: bool = is_tele()
	title_label.text = "Teleportation Permit" if tele else "Operations Permit"
	desc_label.text = TELE_DESC if tele else OPS_DESC
	var place: LegalLocationData = LegalManager.location(location_id)
	if place == null or kind == &"":
		_show_only(false, false, false)
		return
	var state: int = LegalManager.permit_state(location_id, kind)
	var home: bool = location_id == LegalManager.HOME_LOCATION and not tele
	var short: bool = not home and LegalManager.permit_tier(kind) < place.scope
	if state != LegalManager.STATE_NONE:
		_show_only(true, false, false)
		owned_label.text = _owned_text(state, home)
		owned_label.add_theme_color_override(&"font_color",
			LegalStyle.GREEN if state == LegalManager.STATE_ACTIVE else LegalStyle.YELLOW)
		note_label.visible = state == LegalManager.STATE_INACTIVE
		return
	note_label.visible = false
	if short:
		_show_only(false, false, true)
		lock.feature = "%ss in %s" % [title_label.text, scope_text(place.scope)]
		lock.upgrade = "Teleportation Permit" if tele else "Operations Permits"
		lock.upgrade_id = "teleport" if tele else "opspermit"
		lock.entitlement = TELE_KEY if tele else OPS_KEY
		lock.tier = place.scope
		lock.plan = "Mercday Enterprise"
		lock.required_plan = SubscriptionManager.Plan.ENTERPRISE
		return
	_show_only(false, true, false)
	price_notes.amount = LegalManager.permit_cost(location_id, kind)
	var gate: Dictionary = LegalManager.can_request(location_id, kind)
	var ok: bool = bool(gate.get("ok", false))
	request_button.disabled = not ok
	price_notes.value_color = LegalStyle.CREAM if ok else LegalStyle.RED
	reason_label.visible = not ok
	reason_label.text = str(gate.get("reason", ""))


func _show_only(owned: bool, price: bool, locked: bool) -> void:
	owned_label.visible = owned
	price_notes.visible = price
	request_button.visible = price
	reason_label.visible = false
	if not locked:
		lock.upgrade_id = ""
		lock.entitlement = ""
		lock.required_plan = SubscriptionManager.Plan.FREE
		lock.plan = "Mercday Free"
	if not owned:
		note_label.visible = false


func _owned_text(state: int, home: bool) -> String:
	if home:
		return "Home"
	if state == LegalManager.STATE_ACTIVE:
		return "Active"
	return "Owned%sInactive" % LegalManager.LABEL_JOIN


static func scope_text(scope: int) -> String:
	var i: int = clampi(scope - 1, 0, SCOPE_TEXT.size() - 1)
	return SCOPE_TEXT[i]
