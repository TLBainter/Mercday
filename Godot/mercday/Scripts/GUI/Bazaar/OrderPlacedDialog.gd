class_name OrderPlacedDialog extends Control

#What the guild sees after the spend: the order number, the day it lands and the two ways out.
#Keep Shopping returns to the Shop tab, View Orders opens the Orders tab on All.

signal keep_pressed
signal view_pressed

const TITLE: String = "Order Placed!"
const KEEP_TEXT: String = "Keep Shopping"
const VIEW_TEXT: String = "View Orders"
const TWO_DAY_TAIL: String = " (2-Day delivery)."
const DAYS_TAIL: String = " (%d days)."
const MESSAGE_HEAD: String = "Order #%d will arrive %s"
const BOX_WIDTH: float = 460.0
const TITLE_SIZE: int = 16
const MESSAGE_SIZE: int = 12
const BUTTON_HEIGHT: float = 38.0
const ROW_GAP: int = 16

var order: OrderData = null:
	set(value):
		order = value
		refresh()

var _box: PanelContainer = null
var _rows: VBoxContainer = null
var _backdrop: Panel = null
var _centre: CenterContainer = null
var _message: Label = null
var _keep: Button = null
var _view: Button = null


func _ready() -> void:
	visible = false
	_build()
	refresh()


func open_for(placed_order: OrderData) -> void:
	order = placed_order
	visible = order != null
	if not visible:
		return
	ModalFrame.fit(self, _backdrop, _centre)
	GuiFrameStack.push(self)


func close() -> void:
	visible = false
	GuiFrameStack.remove(self)


func _exit_tree() -> void:
	GuiFrameStack.remove(self)


func is_open() -> bool:
	return visible


func press_keep() -> void:
	_on_keep_pressed()


func press_view() -> void:
	_on_view_pressed()


func keep_button() -> Button:
	return _keep


func view_button() -> Button:
	return _view


func message_text() -> String:
	return _message.text if _message != null else ""


func refresh() -> void:
	if not is_node_ready() or _message == null:
		return
	if order == null:
		_message.text = ""
		return
	var day_text: String = GuiDates.day_text(order.placed_day + order.days)
	var tail: String = TWO_DAY_TAIL if order.days == 2 else DAYS_TAIL % order.days
	_message.text = (MESSAGE_HEAD % [order.id, day_text]) + tail


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop = Panel.new()
	_backdrop.theme_type_variation = &"BackdropPanel"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)
	_centre = CenterContainer.new()
	_centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_centre)
	ModalFrame.fit(self, _backdrop, _centre)
	_box = BazaarUi.panel_box(BazaarUi.PANEL, 4, BazaarUi.GREEN, 22.0)
	_box.custom_minimum_size.x = BOX_WIDTH
	_centre.add_child(_box)
	_rows = BazaarUi.vbox(ROW_GAP)
	_box.add_child(_rows)
	_rows.add_child(BazaarUi.silk_bold(TITLE, TITLE_SIZE, BazaarUi.GREEN))
	_message = BazaarUi.body("", MESSAGE_SIZE, BazaarUi.CREAM)
	_message.custom_minimum_size.x = BOX_WIDTH - 60.0
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(_message)
	var buttons: HBoxContainer = BazaarUi.hbox(12)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	_rows.add_child(buttons)
	_keep = BazaarUi.button(KEEP_TEXT, &"ButtonNeutral", BUTTON_HEIGHT, 10)
	_keep.pressed.connect(_on_keep_pressed)
	buttons.add_child(_keep)
	_view = BazaarUi.button(VIEW_TEXT, &"ButtonGo", BUTTON_HEIGHT, 11)
	_view.pressed.connect(_on_view_pressed)
	buttons.add_child(_view)


#Esc answers this dialog only while it is the top frame of the stack.
func _unhandled_input(event: InputEvent) -> void:
	if GuiFrameStack.consume_escape(self, event):
		press_keep()


func _on_keep_pressed() -> void:
	close()
	keep_pressed.emit()


func _on_view_pressed() -> void:
	close()
	view_pressed.emit()
