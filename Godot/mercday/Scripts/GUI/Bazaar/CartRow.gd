class_name CartRow extends PanelContainer

#One line of the cart: the image, the name block with Remove, the stepper and the line total.
#The row writes the quantity to BazaarManager and reports it; the page rebuilds from the manager.

signal qty_changed(new_qty: int)
signal removed

const QUANTITY_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/QuantityStepper.tscn")
const IMAGE_PX: float = 64.0
const NAME_SIZE: int = 12
const META_SIZE: int = 11
const ETA_SIZE: int = 10
const TOTAL_SIZE: int = 14
const EACH_SIZE: int = 10
const LINK_SIZE: int = 9
const ROW_GAP: int = 12
const TEXT_GAP: int = 4

var item: BazaarItemData = null:
	set(value):
		item = value
		_refresh()
var qty: int = 1:
	set(value):
		qty = maxi(0, value)
		_refresh()

var _slot: ContractImageBox = null
var _name: Label = null
var _meta: Label = null
var _eta: Label = null
var _remove: Button = null
var _stepper: QuantityStepper = null
var _total: NotesLabel = null
var _each: Label = null


func _ready() -> void:
	add_theme_stylebox_override("panel",
		GuiStyle.flat(GuiColors.ROW_HOVER, 0, GuiColors.ROW_HOVER, 8.0))
	_build()
	_refresh()


func press_remove() -> void:
	_on_remove_pressed()


func press_plus() -> void:
	if _stepper != null:
		_stepper.press_plus()


func press_minus() -> void:
	if _stepper != null:
		_stepper.press_minus()


func item_id() -> int:
	return item.id if item != null else -1


func line_total() -> int:
	return item.price * qty if item != null else 0


func stepper() -> QuantityStepper:
	return _stepper


func each_text() -> String:
	return _each.text


func _build() -> void:
	var row: HBoxContainer = GuiStyle.hbox(ROW_GAP)
	add_child(row)
	_slot = BazaarUi.image_slot(item, IMAGE_PX)
	row.add_child(_slot)
	var text_rows: VBoxContainer = GuiStyle.vbox(TEXT_GAP)
	text_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_rows.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text_rows)
	_name = GuiStyle.label("", GuiStyle.SILK_BOLD, NAME_SIZE, GuiColors.CREAM)
	text_rows.add_child(_name)
	_meta = GuiStyle.label("", GuiStyle.BODY, META_SIZE, GuiColors.MUTED)
	text_rows.add_child(_meta)
	_eta = GuiStyle.label("", GuiStyle.BODY, ETA_SIZE, GuiColors.GREEN)
	text_rows.add_child(_eta)
	_remove = BazaarUi.link("Remove", GuiColors.RED, LINK_SIZE)
	_remove.pressed.connect(_on_remove_pressed)
	text_rows.add_child(_remove)
	var right: VBoxContainer = GuiStyle.vbox(TEXT_GAP)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)
	_stepper = QUANTITY_SCENE.instantiate() as QuantityStepper
	_stepper.min_value = 0
	_stepper.value_changed.connect(_on_qty_changed)
	right.add_child(BazaarUi.ringed_stepper(_stepper))
	_total = GuiStyle.notes(0, TOTAL_SIZE, GuiColors.CREAM)
	_total.bold = true
	_total.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(_total)
	_each = GuiStyle.label("", GuiStyle.BODY, EACH_SIZE, GuiColors.MUTED)
	_each.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_each)


func _refresh() -> void:
	if not is_node_ready() or _name == null:
		return
	if item == null:
		_name.text = ""
		_meta.text = ""
		_eta.text = ""
		_each.text = ""
		return
	_slot.ring_color = BazaarUi.rarity_color(item.rarity)
	_name.text = item.name
	_meta.text = "%s - %s - %s" % [BazaarUi.rarity_name(item.rarity), item.subtype,
		item.department_label]
	_eta.text = "Arrives %s" % BazaarUi.eta_text(BazaarManager.delivery_days(), GameState.day())
	_stepper.set_value_silent(qty)
	_total.amount = line_total()
	_each.text = "%s each" % TransactionData.grouped(item.price)


func _on_remove_pressed() -> void:
	if item == null:
		return
	BazaarManager.remove_from_cart(item.id)
	removed.emit()


func _on_qty_changed(new_value: int) -> void:
	if item == null:
		return
	BazaarManager.set_qty(item.id, new_value)
	if new_value <= 0:
		removed.emit()
	else:
		qty_changed.emit(new_value)
