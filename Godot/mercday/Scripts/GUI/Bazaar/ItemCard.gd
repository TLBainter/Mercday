class_name ItemCard extends PanelContainer

#One shop card: the rarity ringed image slot, the name, the price and either Add to Cart or the
#minus, number, plus control. The card writes the quantity straight to BazaarManager, which owns
#the rule; qty_in_cart is only what it draws.

signal add_pressed
signal remove_pressed

const CARD_FILL: Color = BazaarUi.NAVY
const CARD_BORDER: Color = BazaarUi.BLUE
const SLOT_PX: float = 110.0
const SLOT_STRIPE: Color = BazaarUi.BLUE
const NAME_SIZE: int = 11
const META_SIZE: int = 11
const PRICE_SIZE: int = 16
const ETA_SIZE: int = 10
const TAG_SIZE: int = 8
const ADD_HEIGHT: float = 30.0
const ADD_TEXT: String = "Add to Cart"
const ROW_GAP: int = 6
const QUANTITY_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/QuantityStepper.tscn")

var item: BazaarItemData = null:
	set(value):
		item = value
		_refresh()
var qty_in_cart: int = 0:
	set(value):
		qty_in_cart = maxi(0, value)
		_refresh()

var _rows: VBoxContainer = null
var _slot: ContractImageBox = null
var _tag: Label = null
var _name: Label = null
var _meta: Label = null
var _price: NotesLabel = null
var _eta: Label = null
var _add: Button = null
var _qty_box: PanelContainer = null
var _stepper: QuantityStepper = null


func _ready() -> void:
	add_theme_stylebox_override("panel", BazaarUi.flat(CARD_FILL, 2, CARD_BORDER, 8.0))
	_build()
	_refresh()


func press_add() -> void:
	_on_add_pressed()


func press_plus() -> void:
	if _stepper != null and _qty_box.visible:
		_stepper.press_plus()


func press_minus() -> void:
	if _stepper != null and _qty_box.visible:
		_stepper.press_minus()


func item_id() -> int:
	return item.id if item != null else -1


func add_button() -> Button:
	return _add


func stepper() -> QuantityStepper:
	return _stepper


func eta_label() -> Label:
	return _eta


func _build() -> void:
	_rows = BazaarUi.vbox(ROW_GAP)
	add_child(_rows)
	var frame: AspectRatioContainer = AspectRatioContainer.new()
	frame.ratio = 1.0
	frame.custom_minimum_size = Vector2(0.0, SLOT_PX)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_child(frame)
	_slot = ContractImageBox.new()
	_slot.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
	_slot.stripe_color = SLOT_STRIPE
	_slot.ring_px = 2
	frame.add_child(_slot)
	_tag = BazaarUi.silk("", TAG_SIZE, BazaarUi.CREAM)
	_tag.position = Vector2(5.0, 4.0)
	_slot.add_child(_tag)
	_name = BazaarUi.silk_bold("", NAME_SIZE, BazaarUi.CREAM)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(_name)
	_meta = BazaarUi.body("", META_SIZE, BazaarUi.MUTED)
	_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(_meta)
	_price = BazaarUi.notes(0, PRICE_SIZE, BazaarUi.CREAM)
	_price.bold = true
	_rows.add_child(_price)
	_eta = BazaarUi.body("", ETA_SIZE, BazaarUi.GREEN)
	_eta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(_eta)
	_add = BazaarUi.button(ADD_TEXT, &"ButtonOrange", ADD_HEIGHT, 10)
	_add.pressed.connect(_on_add_pressed)
	_rows.add_child(_add)
	_qty_box = BazaarUi.panel_box(BazaarUi.INK, 2, BazaarUi.GREEN, 2.0)
	_rows.add_child(_qty_box)
	_stepper = QUANTITY_SCENE.instantiate() as QuantityStepper
	_stepper.min_value = 0
	_stepper.value_changed.connect(_on_qty_changed)
	_qty_box.add_child(_stepper)


func _refresh() -> void:
	if not is_node_ready() or _rows == null:
		return
	var found: BazaarItemData = item
	if found == null:
		_name.text = ""
		_meta.text = ""
		_eta.text = ""
		_add.visible = false
		_qty_box.visible = false
		return
	_slot.ring_color = BazaarUi.rarity_color(found.rarity)
	_tag.text = BazaarUi.rarity_name(found.rarity)
	_tag.add_theme_color_override("font_color", BazaarUi.rarity_color(found.rarity))
	_name.text = found.name
	_meta.text = "%s - %s" % [found.subtype, found.department_label]
	_price.amount = found.price
	_eta.text = "Arrives %s" % BazaarUi.eta_text(BazaarManager.delivery_days(), GameState.day())
	var in_cart: bool = qty_in_cart > 0
	_add.visible = not in_cart
	_qty_box.visible = in_cart
	if in_cart:
		_stepper.set_value_silent(qty_in_cart)


func _on_add_pressed() -> void:
	if item == null:
		return
	if BazaarManager.add_to_cart(item.id, 1):
		add_pressed.emit()


func _on_qty_changed(new_value: int) -> void:
	if item == null:
		return
	BazaarManager.set_qty(item.id, new_value)
	if new_value <= 0:
		remove_pressed.emit()
