class_name ModalDialog extends GuiModal

#The shared dialog chrome: a boxed column centred in the band above the bottom bar, a pixel ring
#in ring_color with the inset bevel of Edges, a kicker and title head, a close X on the corner
#and a cancel and confirm pair at the foot. Rows an inherited scene adds under Rows sit between
#Head and Buttons. A button or a head line with no text stays hidden.

signal cancelled
signal confirmed

const BOX_INSET: float = 4.0
const BOX_BORDER: int = 4
const CLOSE_RIM: float = 3.0

@export var kicker: String = "":
	set(value):
		kicker = value
		_sync_head()
@export var title: String = "":
	set(value):
		title = value
		_sync_head()
#0 lets the content decide the width.
@export var box_width: float = 600.0
@export var ring_color: Color = GuiColors.ORANGE:
	set(value):
		ring_color = value
		_sync_box()
#Null builds the BOX_BG box ringed in ring_color.
@export var box_style: StyleBox = null
#Null keeps the BackdropPanel look of the theme.
@export var backdrop_style: StyleBox = null
#0 hides Edges.
@export var edge_px: int = 4
@export var show_close: bool = true
@export var close_inset: float = 10.0
@export var cancel_text: String = "":
	set(value):
		cancel_text = value
		_sync_buttons()
@export var confirm_text: String = "":
	set(value):
		confirm_text = value
		_sync_buttons()
@export var cancel_kind: StringName = &"blue":
	set(value):
		cancel_kind = value
		_sync_buttons()
@export var confirm_kind: StringName = &"orange":
	set(value):
		confirm_kind = value
		_sync_buttons()

@onready var box: PanelContainer = $Box
@onready var rows: VBoxContainer = $Box/Pad/Rows
@onready var head: VBoxContainer = $Box/Pad/Rows/Head
@onready var kicker_label: Label = $Box/Pad/Rows/Head/Kicker
@onready var title_label: Label = $Box/Pad/Rows/Head/TitleRow/Title
@onready var button_row: HBoxContainer = $Box/Pad/Rows/Buttons
@onready var edges: BevelEdges = $Box/Edges
@onready var close_button: Button = $Close

var cancel_button: BevelButton = null
var confirm_button: BevelButton = null
var _base_box: StyleBoxFlat = null
var _dim: ColorRect = null


func _ready() -> void:
	super()
	cancel_button = button_row.get_node_or_null(^"Cancel") as BevelButton
	confirm_button = button_row.get_node_or_null(^"Confirm") as BevelButton
	rows.move_child(button_row, rows.get_child_count() - 1)
	if box_width > 0.0:
		box.custom_minimum_size.x = box_width
	if backdrop_style != null:
		backdrop.add_theme_stylebox_override(&"panel", backdrop_style)
	_base_box = box.get_theme_stylebox(&"panel", &"PopupBox") as StyleBoxFlat
	_sync_box()
	edges.px = edge_px
	edges.visible = edge_px > 0
	CloseX.style(close_button, CloseX.SCALE_WINDOW)
	CloseX.pin(close_button, box, CloseX.SCALE_WINDOW, close_inset - CLOSE_RIM)
	close_button.visible = show_close
	close_button.pressed.connect(press_close)
	if cancel_button != null:
		cancel_button.pressed.connect(press_cancel)
	if confirm_button != null:
		confirm_button.pressed.connect(press_confirm)
	box.minimum_size_changed.connect(_refit, CONNECT_DEFERRED)
	_sync_head()
	_sync_buttons()


func kicker_text() -> String:
	return kicker_label.text


func title_text() -> String:
	return title_label.text


func close_visible() -> bool:
	return close_button.visible


#Closes before the signal goes out, so a handler may open the next dialog straight away.
func press_cancel() -> void:
	close()
	cancelled.emit()


func press_confirm() -> void:
	if not _on_confirm():
		return
	close()
	confirmed.emit()


func press_close() -> void:
	press_cancel()


#Dims the whole dialog while a confirm of its own sits on top of it.
func set_dimmed(on: bool) -> void:
	if _dim == null:
		if not on:
			return
		_dim = ColorRect.new()
		_dim.color = GuiColors.BACKDROP
		_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.offset_bottom = -GuiFrameStack.bottom_reserve
	_dim.visible = on


func dimmed() -> bool:
	return _dim != null and _dim.visible


func panel_rect() -> Rect2:
	return box.get_global_rect()


#False keeps the dialog open, for a confirm whose input is not ready yet.
func _on_confirm() -> bool:
	return true


func _layout() -> void:
	box.reset_size()
	ModalFrame.fit(self, backdrop, box)


#A wrapped line measured before its width settles grows the box; it shrinks back once it has.
func _refit() -> void:
	if visible:
		_layout()


func _sync_head() -> void:
	if not is_node_ready():
		return
	kicker_label.text = kicker
	kicker_label.visible = kicker != ""
	title_label.text = title
	title_label.visible = title != ""
	head.visible = kicker != "" or title != "" or title_label.get_parent().get_child_count() > 1


func _sync_buttons() -> void:
	if not is_node_ready():
		return
	_sync_button(cancel_button, cancel_text, cancel_kind)
	_sync_button(confirm_button, confirm_text, confirm_kind)


func _sync_button(button: BevelButton, text: String, kind: StringName) -> void:
	if button == null or not is_instance_valid(button):
		return
	button.text = text
	button.kind = kind
	button.visible = text != ""


#The box wears box_style when one is set, else the PopupBox frame recoloured to BOX_BG with a
#ring of ring_color.
func _sync_box() -> void:
	if not is_node_ready():
		return
	if box_style != null:
		box.add_theme_stylebox_override(&"panel", box_style)
		return
	var style: StyleBoxFlat = _base_box.duplicate() if _base_box != null else StyleBoxFlat.new()
	style.bg_color = GuiColors.BOX_BG
	style.set_border_width_all(BOX_BORDER)
	style.border_color = ring_color
	style.set_content_margin_all(BOX_INSET)
	box.add_theme_stylebox_override(&"panel", style)
