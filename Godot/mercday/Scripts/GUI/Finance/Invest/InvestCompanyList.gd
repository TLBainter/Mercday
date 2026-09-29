class_name InvestCompanyList extends PanelContainer

#The Invest roster: the header with the company count and the only scroll of the page, one
#InvestCompanyItem per company in StockMarket order.

const ITEM_SCENE: String = "res://Scenes/GUI/Finance/Invest/InvestCompanyItem.tscn"
const COLUMN_WIDTH: float = 272.0

signal company_picked(id: int)
signal company_hovered(id: int, item: Control)
signal company_unhovered(id: int)

@onready var title_label: Label = $Col/Header/TitleLabel
@onready var count_label: Label = $Col/Header/CountLabel
@onready var items_box: VBoxContainer = $Col/Scroll/Pad/Items

var _items: Array[InvestCompanyItem] = []
var _selected: int = -1


func _ready() -> void:
	custom_minimum_size.x = COLUMN_WIDTH
	title_label.text = "Companies"
	_build()
	refresh(_selected)


func refresh(selected: int) -> void:
	_selected = selected
	if not is_node_ready():
		return
	_build()
	count_label.text = "%d listed" % _items.size()
	for row: InvestCompanyItem in _items:
		row.refresh()
		row.set_selected(row.company_id == selected)


func item(id: int) -> InvestCompanyItem:
	for row: InvestCompanyItem in _items:
		if row.company_id == id:
			return row
	return null


func item_count() -> int:
	return _items.size()


func count_text() -> String:
	return count_label.text


#What a click on a row does; the button handler calls the same helper.
func press_item(id: int) -> void:
	if item(id) == null:
		return
	company_picked.emit(id)


func _build() -> void:
	if _items.size() == StockMarket.company_count():
		return
	for row: InvestCompanyItem in _items:
		row.queue_free()
	_items.clear()
	var scene: PackedScene = load(ITEM_SCENE) as PackedScene
	if scene == null:
		return
	for k: int in StockMarket.company_count():
		var row: InvestCompanyItem = scene.instantiate() as InvestCompanyItem
		items_box.add_child(row)
		row.setup(k)
		row.pressed.connect(press_item.bind(k))
		row.mouse_entered.connect(_on_item_in.bind(k))
		row.mouse_exited.connect(_on_item_out.bind(k))
		_items.append(row)


func _on_item_in(k: int) -> void:
	var row: InvestCompanyItem = item(k)
	if row != null:
		company_hovered.emit(k, row)


func _on_item_out(k: int) -> void:
	company_unhovered.emit(k)
