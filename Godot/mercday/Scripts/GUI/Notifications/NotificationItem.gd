class_name NotificationItem extends PanelContainer

#One row of the notification list: the striped icon box, the title, the name, a body per type and
#the footer. An unread row asks the bell to open it; the X marks it read and never opens it.

signal item_pressed(data: NotificationData)
signal mark_read_pressed(data: NotificationData)

const BG_IDLE: Color = Color("#0e1628")
const BG_HOVER: Color = Color("#15223d")
const RING_IDLE: Color = Color("#1f3560")
const RING_HOVER: Color = Color("#f28c28")
const STRIPE_FILL: Color = Color("#1f3560")
const STRIPE_BACK: Color = Color("#0e1628")
const ICON_RING: Color = Color("#3b6fb6")
const LOAN_GLYPH: Color = Color("#f2b33d")
const READ_OPACITY: float = 0.55
const RING_WIDTH: int = 2
const PAD: int = 8
const ICON_SIZE: Vector2 = Vector2(56, 56)
const BANG_PATH: String = "res://Art/GUI/Icons/contract_mark_results_bang_14x14.png"
const BANG_SCALE: int = 2
const GLYPH_SCALE: int = 4
const BODY_INDEX: int = 2

const CONTRACT_BODY: String = "res://Scenes/GUI/Notifications/ContractCompletedBody.tscn"
const LOAN_BODY: String = "res://Scenes/GUI/Notifications/LoanOfferBody.tscn"
const STOCK_BODY: String = "res://Scenes/GUI/Notifications/StockMoveBody.tscn"

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
		_stripes.texture = NotifyGlyphs.stripes(STRIPE_FILL, STRIPE_BACK)
	if _ring != null:
		_ring.add_theme_stylebox_override("panel", _ring_box())
	if _mark != null and not _mark.pressed.is_connected(press_mark_read):
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
	box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
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
	var path: String = _body_path()
	if path == "" or not ResourceLoader.exists(path):
		return
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		return
	_body = scene.instantiate() as Control
	if _body == null:
		return
	_col.add_child(_body)
	_col.move_child(_body, BODY_INDEX)


func _body_path() -> String:
	if _row == null:
		return ""
	match _row.type:
		NotificationData.TYPE_CONTRACT_COMPLETED, NotificationData.TYPE_CONTRACT_FAILED:
			return CONTRACT_BODY
		NotificationData.TYPE_LOAN_OFFER:
			return LOAN_BODY
		NotificationData.TYPE_STOCK_MOVE:
			return STOCK_BODY
	return ""


func _fill_icon() -> void:
	if _center == null:
		return
	for child: Node in _center.get_children():
		_center.remove_child(child)
		child.queue_free()
	var tex: Texture2D = _icon_texture()
	if tex == null:
		return
	_center.add_child(NotifyGlyphs.shadowed(tex, NotifyGlyphs.SHADOW_STEP, _icon_draw_size(tex)))


func _icon_texture() -> Texture2D:
	if _row == null:
		return null
	match _row.type:
		NotificationData.TYPE_CONTRACT_COMPLETED, NotificationData.TYPE_CONTRACT_FAILED:
			if ResourceLoader.exists(BANG_PATH):
				return load(BANG_PATH) as Texture2D
			return null
		NotificationData.TYPE_LOAN_OFFER:
			return NotifyGlyphs.note(LOAN_GLYPH, GLYPH_SCALE)
		NotificationData.TYPE_STOCK_MOVE:
			var tint: Color = _row.title_color()
			if _row.rising():
				return NotifyGlyphs.arrow_up(tint, GLYPH_SCALE)
			return NotifyGlyphs.arrow_down(tint, GLYPH_SCALE)
	return null


#The bang art is 14 x 14 and is drawn at 2 px per art pixel; the runtime glyphs are already scaled.
func _icon_draw_size(tex: Texture2D) -> Vector2:
	if tex is ImageTexture:
		return Vector2.ZERO
	return Vector2(tex.get_size()) * float(BANG_SCALE)
