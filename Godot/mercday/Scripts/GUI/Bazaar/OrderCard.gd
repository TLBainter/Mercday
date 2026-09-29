class_name OrderCard extends PanelContainer

#One order: the head strip, the status line, the twenty cell progress bar and one chip per line of
#the order. Delivery, elapsed days and progress are read from BazaarManager; the card only draws.

const HEAD_LABELS: Array[String] = ["Order Placed", "Total", "Items", "Order #"]
const DELIVERED_SUB: String = "Delivered to Guild Storage"
const ORDERED_PREFIX: String = "Ordered "
const ARRIVES_PREFIX: String = "Arrives "
const DELIVERED_PREFIX: String = "Delivered "
const ARRIVING_TITLE: String = "Arriving %s"
const DELIVERED_TITLE: String = "Delivered %s"
const PROGRESS_CELLS: int = 20
const CELL_HEIGHT: int = 10
const CELL_GAP: int = 2
const CHIP_PX: float = 32.0
const HEAD_SIZE: int = 9
const HEAD_VALUE_SIZE: int = 12
const TITLE_SIZE: int = 13
const SUB_SIZE: int = 11
const FOOT_SIZE: int = 10
const CHIP_NAME_SIZE: int = 11
const CHIP_META_SIZE: int = 10
const ROW_GAP: int = 10

var order: OrderData = null:
	set(value):
		order = value
		refresh()

var _rows: VBoxContainer = null
var _placed_value: Label = null
var _total_value: NotesLabel = null
var _items_value: Label = null
var _id_value: Label = null
var _title: Label = null
var _sub: Label = null
var _bar: CellBar = null
var _ordered: Label = null
var _arrives: Label = null
var _chips: HFlowContainer = null


func _ready() -> void:
	add_theme_stylebox_override("panel", BazaarUi.flat(BazaarUi.NAVY, 2, BazaarUi.BLUE, 12.0))
	_build()
	refresh()


func order_id() -> int:
	return order.id if order != null else -1


func title_text() -> String:
	return _title.text if _title != null else ""


func sub_text() -> String:
	return _sub.text if _sub != null else ""


func filled_cells() -> int:
	return _bar.filled if _bar != null else 0


func chip_count() -> int:
	return _chips.get_child_count() if _chips != null else 0


func refresh() -> void:
	if not is_node_ready() or _rows == null:
		return
	if order == null:
		_title.text = ""
		_sub.text = ""
		return
	var done: bool = BazaarManager.is_delivered(order)
	var end_day: int = order.placed_day + order.days
	var left: int = BazaarManager.days_left(order)
	var elapsed: int = clampi(GameState.day() - order.placed_day, 0, order.days)
	_placed_value.text = GuiDates.short_text(order.placed_day)
	_total_value.amount = order.total
	_items_value.text = str(order.item_count())
	_id_value.text = str(order.id)
	_title.text = (DELIVERED_TITLE if done else ARRIVING_TITLE) % GuiDates.day_text(end_day)
	_title.add_theme_color_override("font_color", BazaarUi.GREEN if done else BazaarUi.ORANGE)
	if done:
		_sub.text = DELIVERED_SUB
	else:
		_sub.text = "%s left - Day %d of %d" % [GuiDates.days_text(maxi(left, 0)), elapsed,
			order.days]
	_bar.fill_color = BazaarUi.GREEN if done else BazaarUi.ORANGE
	_bar.set_ratio(BazaarManager.progress(order))
	_ordered.text = ORDERED_PREFIX + GuiDates.short_text(order.placed_day)
	_arrives.text = (DELIVERED_PREFIX if done else ARRIVES_PREFIX) + GuiDates.day_text(end_day)
	_build_chips()


func _build() -> void:
	_rows = BazaarUi.vbox(ROW_GAP)
	add_child(_rows)
	var head: PanelContainer = BazaarUi.panel_box(BazaarUi.NAVY2, 0, BazaarUi.NAVY2, 8.0)
	_rows.add_child(head)
	var head_row: HBoxContainer = BazaarUi.hbox(16)
	head.add_child(head_row)
	_placed_value = BazaarUi.silk_bold("", HEAD_VALUE_SIZE, BazaarUi.CREAM)
	head_row.add_child(_head_block(HEAD_LABELS[0], _placed_value))
	_total_value = BazaarUi.notes(0, HEAD_VALUE_SIZE, BazaarUi.CREAM)
	head_row.add_child(_head_block(HEAD_LABELS[1], _total_value))
	_items_value = BazaarUi.silk_bold("", HEAD_VALUE_SIZE, BazaarUi.CREAM)
	head_row.add_child(_head_block(HEAD_LABELS[2], _items_value))
	_id_value = BazaarUi.silk_bold("", HEAD_VALUE_SIZE, BazaarUi.SKY)
	head_row.add_child(_head_block(HEAD_LABELS[3], _id_value))
	_title = BazaarUi.silk_bold("", TITLE_SIZE, BazaarUi.ORANGE)
	_rows.add_child(_title)
	_sub = BazaarUi.body("", SUB_SIZE, BazaarUi.MUTED)
	_rows.add_child(_sub)
	_bar = BazaarUi.cell_bar(PROGRESS_CELLS, CELL_HEIGHT, CELL_GAP)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_child(_bar)
	var foot: HBoxContainer = BazaarUi.hbox(10)
	_rows.add_child(foot)
	_ordered = BazaarUi.body("", FOOT_SIZE, BazaarUi.MUTED)
	_ordered.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_ordered)
	_arrives = BazaarUi.body("", FOOT_SIZE, BazaarUi.MUTED)
	foot.add_child(_arrives)
	_chips = HFlowContainer.new()
	_chips.add_theme_constant_override("h_separation", 8)
	_chips.add_theme_constant_override("v_separation", 8)
	_rows.add_child(_chips)


func _head_block(caption: String, value: Control) -> VBoxContainer:
	var block: VBoxContainer = BazaarUi.vbox(2)
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_child(BazaarUi.silk(caption, HEAD_SIZE, BazaarUi.SKY))
	block.add_child(value)
	return block


func _build_chips() -> void:
	for child: Node in _chips.get_children():
		_chips.remove_child(child)
		child.queue_free()
	for line: Dictionary in order.lines:
		var found: BazaarItemData = BazaarManager.item(int(line.get("item_id", -1)))
		if found == null:
			continue
		_chips.add_child(_chip(found, int(line.get("qty", 0))))


func _chip(found: BazaarItemData, qty: int) -> PanelContainer:
	var chip: PanelContainer = BazaarUi.panel_box(BazaarUi.NAVY2, 0, BazaarUi.NAVY2, 6.0)
	var row: HBoxContainer = BazaarUi.hbox(8)
	chip.add_child(row)
	var slot: ContractImageBox = ContractImageBox.new()
	slot.custom_minimum_size = Vector2(CHIP_PX, CHIP_PX)
	slot.stripe_color = BazaarUi.BLUE
	slot.ring_px = 2
	slot.ring_color = BazaarUi.rarity_color(found.rarity)
	row.add_child(slot)
	var text_rows: VBoxContainer = BazaarUi.vbox(2)
	text_rows.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text_rows)
	text_rows.add_child(BazaarUi.silk_bold(found.name, CHIP_NAME_SIZE, BazaarUi.CREAM))
	var meta: Label = BazaarUi.body("%s - x%d" % [BazaarUi.rarity_name(found.rarity), qty],
		CHIP_META_SIZE, BazaarUi.MUTED)
	meta.add_theme_color_override("font_color", BazaarUi.rarity_color(found.rarity))
	text_rows.add_child(meta)
	return chip
