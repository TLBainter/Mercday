class_name LocationCard extends PanelContainer

#One location of the Permits strip: placeholder art, name and nation, the average difficulty of
#its contracts, its house rules and the three permissions the guild holds there. The card only
#reports its Request press; the page owns the dialog.

signal request_pressed(loc_id: int)

const STARS_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/DifficultyStars.tscn")
const LOCK_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/FeatureLock.tscn")
const CARD_WIDTH: int = 330
const ICON_SPAN: Vector2 = Vector2(84, 84)
const CHIP_SPAN: Vector2 = Vector2(44, 15)
const CHIP_AT: Vector2 = Vector2(4, 4)
const MARK_SPAN: Vector2 = Vector2(24, 24)
const MARK_SCALE: int = 2
const BULLET_SPAN: Vector2 = Vector2(6, 6)
const REQUEST_HEIGHT: int = 34
const GOOD_STANDING: String = "Good Standing"
const CLEAN_TEXT: String = "No fines and no mercs in custody here."
const SCOPE_TIERS: int = 3

var location: LegalLocationData = null:
	set(value):
		location = value
		_refresh()

var name_label: Label = null
var nation_label: Label = null
var stars: DifficultyStars = null
var rules_box: VBoxContainer = null
var permissions_box: VBoxContainer = null
var request_button: Button = null
var chip: PanelContainer = null
var icon_box: PanelContainer = null
var _states: Array[int] = []


func _ready() -> void:
	_build()
	_refresh()


func press_request() -> void:
	if location == null:
		return
	request_pressed.emit(location.id)


func is_home() -> bool:
	return location != null and location.id == LegalManager.HOME_LOCATION


func name_text() -> String:
	return name_label.text if name_label != null else ""


func nation_text() -> String:
	return nation_label.text if nation_label != null else ""


func rule_count() -> int:
	return rules_box.get_child_count() - 1 if rules_box != null else 0


func permission_count() -> int:
	return permissions_box.get_child_count() - 1 if permissions_box != null else 0


#The mark one permission row shows: STATE_NONE, STATE_ACTIVE or STATE_INACTIVE.
func permission_state(i: int) -> int:
	if i < 0 or i >= _states.size():
		return LegalManager.STATE_NONE
	return _states[i]


func permission_locked(i: int) -> bool:
	var row: Node = _permission_row_at(i)
	if row == null:
		return false
	return row.get_node_or_null(^"Lock") != null


func home_tag_visible() -> bool:
	return chip != null and chip.visible


func ring_color() -> Color:
	var flat: StyleBoxFlat = get_theme_stylebox(&"panel") as StyleBoxFlat
	return flat.border_color if flat != null else Color.BLACK


func _build() -> void:
	if name_label != null:
		return
	custom_minimum_size = Vector2(float(CARD_WIDTH), 0.0)
	add_theme_stylebox_override(&"panel", LegalStyle.card_style(LegalStyle.BLUE))
	var body: VBoxContainer = LegalStyle.vbox(9)
	body.name = "Body"
	var head_row: HBoxContainer = LegalStyle.hbox(12)
	head_row.name = "Head"
	head_row.add_child(_icon_holder())
	var head: VBoxContainer = LegalStyle.vbox(3)
	head.name = "Text"
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label = LegalStyle.pixel("", 15, LegalStyle.CREAM, true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	nation_label = LegalStyle.text("", 13, LegalStyle.SKY)
	nation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(name_label)
	head.add_child(nation_label)
	head.add_child(_difficulty_box())
	head_row.add_child(head)
	body.add_child(head_row)
	body.add_child(LegalStyle.divider(LegalStyle.BLUE, 2))
	rules_box = LegalStyle.vbox(6)
	rules_box.name = "Rules"
	rules_box.add_child(LegalStyle.head("Rules"))
	body.add_child(rules_box)
	permissions_box = LegalStyle.vbox(9)
	permissions_box.name = "Permissions"
	permissions_box.add_child(LegalStyle.head("Your Permissions"))
	body.add_child(permissions_box)
	body.add_child(LegalStyle.spacer())
	request_button = LegalStyle.button("Request", &"ButtonOrange", REQUEST_HEIGHT, 11)
	request_button.name = "Request"
	request_button.pressed.connect(press_request)
	body.add_child(request_button)
	add_child(body)


func _difficulty_box() -> VBoxContainer:
	var box: VBoxContainer = LegalStyle.vbox(4)
	box.name = "Difficulty"
	var caption: Label = LegalStyle.head("Average Difficulty")
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(caption)
	stars = STARS_SCENE.instantiate() as DifficultyStars
	stars.name = "Stars"
	stars.star_size = 2
	stars.size_flags_horizontal = Control.SIZE_SHRINK_END
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(stars)
	return box


#A plain Control holds the art so the Home chip sits over its corner instead of being laid out.
func _icon_holder() -> Control:
	var holder := Control.new()
	holder.name = "Icon"
	holder.custom_minimum_size = ICON_SPAN
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box = LegalStyle.hatch_box(ICON_SPAN, LegalStyle.BLUE3)
	icon_box.name = "Art"
	icon_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(icon_box)
	chip = PanelContainer.new()
	chip.name = "HomeTag"
	chip.custom_minimum_size = CHIP_SPAN
	chip.position = CHIP_AT
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override(&"panel",
		LegalStyle.box_style(LegalStyle.ORANGE, LegalStyle.ORANGE_LO, 1, 2))
	var chip_label: Label = LegalStyle.pixel("Home", 8, LegalStyle.INK)
	chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(chip_label)
	chip.visible = false
	holder.add_child(chip)
	return holder


func _refresh() -> void:
	if name_label == null:
		return
	if location == null:
		name_label.text = ""
		nation_label.text = ""
		_clear_after(rules_box)
		_clear_after(permissions_box)
		_states.clear()
		return
	name_label.text = location.name
	nation_label.text = location.nation
	stars.rating = location.avg_difficulty
	chip.visible = is_home()
	_fill_rules()
	_fill_permissions()
	var live: bool = LegalManager.permit_state(location.id,
		LegalManager.PERMIT_OPS) == LegalManager.STATE_ACTIVE
	add_theme_stylebox_override(&"panel",
		LegalStyle.card_style(LegalStyle.GREEN_EDGE if live else LegalStyle.BLUE))


func _fill_rules() -> void:
	_clear_after(rules_box)
	for rule: String in location.rules:
		var row: HBoxContainer = LegalStyle.hbox(8)
		var bullet := ColorRect.new()
		bullet.color = LegalStyle.SKY
		bullet.custom_minimum_size = BULLET_SPAN
		bullet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bullet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bullet)
		var text: Label = LegalStyle.text(rule, 13, LegalStyle.CREAM)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(text)
		rules_box.add_child(row)


func _fill_permissions() -> void:
	_clear_after(permissions_box)
	_states.clear()
	permissions_box.add_child(_permission_row(LegalManager.PERMIT_OPS, "Operations Permit",
		PermitRow.OPS_DESC))
	permissions_box.add_child(_permission_row(LegalManager.PERMIT_TELE, "Teleportation Permit",
		PermitRow.TELE_DESC))
	permissions_box.add_child(_standing_row())


func _permission_row(kind: StringName, title: String, desc: String) -> Control:
	var state: int = LegalManager.permit_state(location.id, kind)
	var home: bool = is_home() and kind == LegalManager.PERMIT_OPS
	var short: bool = not home and LegalManager.permit_tier(kind) < location.scope
	_states.append(state)
	return _mark_row(state, title, desc, short, kind)


func _standing_row() -> Control:
	var open: Array[Dictionary] = LegalManager.violations(location.id)
	var clean: bool = open.is_empty()
	_states.append(LegalManager.STATE_ACTIVE if clean else LegalManager.STATE_NONE)
	var desc: String = CLEAN_TEXT
	if not clean:
		desc = "%s on file in this location." % _violation_text(open.size())
	return _mark_row(_states[_states.size() - 1], GOOD_STANDING, desc, false, &"")


func _mark_row(state: int, title: String, desc: String, short: bool,
		kind: StringName) -> Control:
	var row: HBoxContainer = LegalStyle.hbox(9)
	row.name = title.replace(" ", "")
	if short:
		row.add_child(_row_lock(kind))
	else:
		row.add_child(LegalStyle.icon(_mark_texture(state), MARK_SPAN))
	var stack: VBoxContainer = LegalStyle.vbox(2)
	stack.name = "Text"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head: Label = LegalStyle.pixel(title, 10,
		GuiColors.LOCKED_TEXT if short else _state_color(state), true)
	var body: Label = LegalStyle.text(desc, 12, LegalStyle.SKY)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(head)
	stack.add_child(body)
	row.add_child(stack)
	return row


func _row_lock(kind: StringName) -> FeatureLock:
	var tele: bool = kind == LegalManager.PERMIT_TELE
	var lock: FeatureLock = LOCK_SCENE.instantiate() as FeatureLock
	lock.name = "Lock"
	lock.height = MARK_SPAN.y
	lock.verb = "hold"
	lock.tiers = SCOPE_TIERS
	lock.tier = location.scope
	lock.upgrade_id = "teleport" if tele else "opspermit"
	lock.entitlement = PermitRow.TELE_KEY if tele else PermitRow.OPS_KEY
	lock.upgrade = "Teleportation Permit" if tele else "Operations Permits"
	lock.feature = "%ss in %s" % [
		"Teleportation Permit" if tele else "Operations Permit",
		PermitRow.scope_text(location.scope)]
	lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return lock


func _permission_row_at(i: int) -> Node:
	if permissions_box == null or i < 0 or i + 1 >= permissions_box.get_child_count():
		return null
	return permissions_box.get_child(i + 1)


#The permission mark is colour art, so the 12 x 12 window of the cell is baked with no tint.
static func _mark_texture(state: int) -> ImageTexture:
	var id: String = "x_sm"
	if state == LegalManager.STATE_ACTIVE:
		id = "check_sm"
	elif state == LegalManager.STATE_INACTIVE:
		id = "alert"
	return Icons.baked(id, MARK_SCALE, Icons.MODE_PLAIN, false, Icons.centered_box(12, 12))


static func _state_color(state: int) -> Color:
	if state == LegalManager.STATE_ACTIVE:
		return LegalStyle.GREEN
	if state == LegalManager.STATE_INACTIVE:
		return LegalStyle.AMBER
	return LegalStyle.CREAM


static func _violation_text(n: int) -> String:
	return "1 violation" if n == 1 else "%d violations" % n


static func _clear_after(box: VBoxContainer) -> void:
	if box == null:
		return
	while box.get_child_count() > 1:
		var last: Node = box.get_child(box.get_child_count() - 1)
		box.remove_child(last)
		last.queue_free()
