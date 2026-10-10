class_name NotificationItem extends PanelContainer

#One row of the notification list: the striped icon box, the title, the name, a body per type and
#the footer. An unread row asks the bell to open it; the X marks it read and never opens it.

signal item_pressed(data: NotificationData)
signal mark_read_pressed(data: NotificationData)
#UiSfx hooks the row through these; only an unread row clicks and hovers.
signal pressed
signal sfx_hovered

const BG_IDLE: Color = GuiColors.ROW_FILL
const BG_HOVER: Color = GuiColors.ROW_HOVER
const RING_IDLE: Color = GuiColors.BLUE_LO
const RING_HOVER: Color = GuiColors.ORANGE
const STRIPE_FILL: Color = GuiColors.BLUE_LO
const STRIPE_BACK: Color = GuiColors.ROW_FILL
const ICON_RING: Color = GuiColors.BLUE_HI
const LOAN_GLYPH: Color = GuiColors.AMBER
const READ_OPACITY: float = 0.55
const RING_WIDTH: int = 2
const PAD: int = 8
const ICON_SIZE: Vector2 = Vector2(56, 56)
const MARK_SCALE: int = 2
const GLYPH_SCALE: int = 4
const BODY_INDEX: int = 2

const CONTRACT_BODY: PackedScene = preload("res://Scenes/GUI/Notifications/ContractCompletedBody.tscn")
const LOAN_BODY: PackedScene = preload("res://Scenes/GUI/Notifications/LoanOfferBody.tscn")
const STOCK_BODY: PackedScene = preload("res://Scenes/GUI/Notifications/StockMoveBody.tscn")

@export var stripes_path: NodePath = ^"Row/IconBox/Stripes"
@export var icon_ring_path: NodePath = ^"Row/IconBox/Ring"
@export var icon_center_path: NodePath = ^"Row/IconBox/Center"
@export var title_label_path: NodePath = ^"Row/TextCol/TitleWrap/TitleLabel"
@export var name_label_path: NodePath = ^"Row/TextCol/NameLabel"
@export var text_col_path: NodePath = ^"Row/TextCol"
@export var footer_path: NodePath = ^"Row/TextCol/Footer"
@export var mark_button_path: NodePath = ^"Overlay/MarkRead"

var _stripes: TextureRect = null
var _ring: Panel = null
var _center: CenterContainer = null
var _title: Label = null
var _name: Label = null
var _col: VBoxContainer = null
var _footer: NotificationFooter = null
var _mark: Button = null
var _body: Control = null
var _row: NotificationData = null
var _hovered: bool = false


func _ready() -> void:
	_stripes = get_node_or_null(stripes_path) as TextureRect
	_ring = get_node_or_null(icon_ring_path) as Panel
	_center = get_node_or_null(icon_center_path) as CenterContainer
	_title = get_node_or_null(title_label_path) as Label
	_name = get_node_or_null(name_label_path) as Label
	_col = get_node_or_null(text_col_path) as VBoxContainer
	_footer = get_node_or_null(footer_path) as NotificationFooter
	_mark = get_node_or_null(mark_button_path) as Button
	if _stripes != null:
		_stripes.texture = GuiGlyphs.hatch(STRIPE_FILL, STRIPE_BACK, NotifyGlyphs.STRIPE_BAND,
			Vector2i(NotifyGlyphs.STRIPE_TILE, NotifyGlyphs.STRIPE_TILE))
	if _ring != null:
		_ring.add_theme_stylebox_override("panel", _ring_box())
	if _mark != null:
		CloseX.style(_mark, CloseX.SCALE_MINI)
		if not _mark.pressed.is_connected(press_mark_read):
			_mark.pressed.connect(press_mark_read)
	if not mouse_entered.is_connected(_on_enter):
		mouse_entered.connect(_on_enter)
		mouse_exited.connect(_on_exit)
	_refresh()


func apply(row_data: NotificationData) -> void:
	_row = row_data
	_build_body()
	_refresh()


func data() -> NotificationData:
	return _row


func row_id() -> int:
	if _row == null:
		return 0
	return _row.id


func body() -> Control:
	return _body


func mark_button() -> Button:
	return _mark


func footer() -> NotificationFooter:
	return _footer


#The glyph plate inside the striped icon box, or null when the type has no icon.
func icon_glyph() -> Control:
	if _center == null or _center.get_child_count() == 0:
		return null
	return _center.get_child(0) as Control


func title_text() -> String:
	if _row == null:
		return ""
	return _row.title_text()


func name_text() -> String:
	if _row == null:
		return ""
	return _row.name_text()


func bg_color() -> Color:
	if _row != null and not _row.read and _hovered:
		return BG_HOVER
	return BG_IDLE


func ring_color() -> Color:
	if _row != null and not _row.read and _hovered:
		return RING_HOVER
	return RING_IDLE


func set_hovered(on: bool) -> void:
	_hovered = on
	_refresh()


func hovered() -> bool:
	return _hovered


#A click on an unread row asks the bell to open it; a read row does nothing.
func press() -> void:
	if _row == null or _row.read:
		return
	pressed.emit()
	item_pressed.emit(_row)


#The X marks the row read here and never opens it.
func press_mark_read() -> void:
	if _row == null or _row.read:
		return
	NotificationCenter.mark_read(_row.id)
	mark_read_pressed.emit(_row)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	press()
	accept_event()


func _on_enter() -> void:
	set_hovered(true)
	if _row != null and not _row.read:
		sfx_hovered.emit()


func _on_exit() -> void:
	set_hovered(false)


func _refresh() -> void:
	add_theme_stylebox_override("panel", _panel_box())
	var read: bool = _row != null and _row.read
	modulate.a = READ_OPACITY if read else 1.0
	mouse_default_cursor_shape = Control.CURSOR_ARROW if read else Control.CURSOR_POINTING_HAND
	if _mark != null:
		_mark.visible = _row != null and not read
	if _title != null:
		_title.text = title_text()
		var tint: Color = RING_HOVER if _row == null else _row.title_color()
		_title.add_theme_color_override("font_color", tint)
	if _name != null:
		_name.text = name_text()
	if _footer != null:
		_footer.apply(_row)
	if _body != null and _body.has_method("apply"):
		_body.call("apply", _row)
	_fill_icon()


func _panel_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg_color()
	box.border_color = ring_color()
	box.set_border_width_all(RING_WIDTH)
	box.set_corner_radius_all(0)
	box.content_margin_left = PAD
	box.content_margin_top = PAD
	box.content_margin_right = PAD
	box.content_margin_bottom = PAD
	return box


func _ring_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = GuiColors.CLEAR
	box.border_color = ICON_RING
	box.set_border_width_all(RING_WIDTH)
	box.set_corner_radius_all(0)
	return box


func _build_body() -> void:
	if _col == null:
		return
	if _body != null:
		_col.remove_child(_body)
		_body.queue_free()
		_body = null
	var scene: PackedScene = _body_scene()
	if scene == null:
		return
	_body = scene.instantiate() as Control
	_col.add_child(_body)
	_col.move_child(_body, BODY_INDEX)


func _body_scene() -> PackedScene:
	if _row == null:
		return null
	match _row.type:
		NotificationData.TYPE_CONTRACT_COMPLETED, NotificationData.TYPE_CONTRACT_FAILED:
			return CONTRACT_BODY
		NotificationData.TYPE_EXPIRY_WARNING, NotificationData.TYPE_EXPIRED:
			return CONTRACT_BODY
		NotificationData.TYPE_LOAN_OFFER:
			return LOAN_BODY
		NotificationData.TYPE_STOCK_MOVE:
			return STOCK_BODY
	return null


func _fill_icon() -> void:
	if _center == null:
		return
	GuiNodes.clear(_center)
	var tex: Texture2D = _icon_texture()
	if tex == null:
		return
	_center.add_child(NotifyGlyphs.shadowed(tex, NotifyGlyphs.SHADOW_STEP, _icon_tint()))


#The atlas art of the row type: the alert cell for a contract, the orange scroll for new postings, the
#note for a loan and the two separate trend arrows for a stock move, which take their colour from _icon_tint.
func _icon_texture() -> Texture2D:
	if _row == null:
		return null
	match _row.type:
		NotificationData.TYPE_CONTRACT_COMPLETED, NotificationData.TYPE_CONTRACT_FAILED:
			return Icons.baked("alert", MARK_SCALE, Icons.MODE_PLAIN)
		NotificationData.TYPE_EXPIRY_WARNING:
			return Icons.baked("alert", MARK_SCALE, Icons.MODE_PLAIN)
		NotificationData.TYPE_EXPIRED:
			return Icons.baked("scroll", MARK_SCALE, Icons.MODE_GRAY, true)
		NotificationData.TYPE_NEW_POSTINGS:
			return Icons.tinted("scroll", NotificationData.TITLE_CONTRACT, MARK_SCALE, true)
		NotificationData.TYPE_LOAN_OFFER:
			return CrewGlyphs.note(LOAN_GLYPH, GLYPH_SCALE)
		NotificationData.TYPE_STOCK_MOVE:
			var id: String = "trend_up" if _row.rising() else "trend_down"
			return Icons.baked(id, GLYPH_SCALE, Icons.MODE_GRAY, true)
	return null


func _icon_tint() -> Color:
	if _row == null:
		return Color.WHITE
	if _row.type == NotificationData.TYPE_STOCK_MOVE:
		return _row.title_color()
	return Color.WHITE
