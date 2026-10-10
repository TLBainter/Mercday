class_name ShopPage extends Control

#The Shop tab: the filter panel, the search and sort bar, the breadcrumb with the result count and
#the five column card grid. The page owns the search text and the sort key, the panel owns the
#filters, and BazaarManager turns the two of them into the list.

signal take_me_there(target: Dictionary)

const CARD_SCENE: PackedScene = preload("res://Scenes/GUI/Bazaar/ItemCard.tscn")
const PANEL_SCENE: PackedScene = preload("res://Scenes/GUI/Bazaar/FilterPanel.tscn")
const SEARCH_HINT: String = "Search the Bazaar"
const SORT_CAPTION: String = "Sort by"
const ALL_CRUMB: String = "All Departments"
const EMPTY_TITLE: String = "No items match your filters"
const EMPTY_NOTE: String = "Try a different department, price, or rarity."
const CLEAR_TEXT: String = "Clear all filters"
const CRUMB_JOIN: String = " > "
const GRID_COLUMNS: int = 5
const GRID_GAP: int = 12
const COLUMN_GAP: int = 16
const ROW_GAP: int = 10
const SEARCH_HEIGHT: float = 36.0
const SEARCH_WIDTH: float = 300.0
const SEARCH_BOX_PAD: float = 3.0
const SEARCH_BTN_W: float = 44.0
#The orange search button holds 28 px of art: these margins make it 44x30, the field box interior.
const SEARCH_BTN_H: float = 30.0
const SEARCH_PAD_X: float = 8.0
const SEARCH_PAD_Y: float = 1.0
const MINI_CLOSE: float = 18.0
const SEARCH_ICON_INK: Color = GuiColors.INK
const SEARCH_ICON_SCALE: int = 2
const CRUMB_SIZE: int = 11
const COUNT_SIZE: int = 11
const EMPTY_NOTE_SIZE: int = 11
const EMPTY_HEIGHT: float = 30.0

var _filters: FilterPanel = null
var _search: LineEdit = null
var _clear_x: Button = null
var _search_button: Button = null
var _sort: OptionDropdown = null
var _crumb: Label = null
var _count: Label = null
var _scroll: ScrollContainer = null
var _grid: GridContainer = null
var _empty: VBoxContainer = null
var _empty_note: Label = null
var _search_text: String = ""
var _sort_key: StringName = BazaarManager.SORTS[0]


func _ready() -> void:
	_build()
	refresh()


func filter_panel() -> FilterPanel:
	return _filters


func search_field() -> LineEdit:
	return _search


func sort_dropdown() -> OptionDropdown:
	return _sort


func grid() -> GridContainer:
	return _grid


func breadcrumb_text() -> String:
	return _crumb.text


func result_text() -> String:
	return _count.text


func empty_visible() -> bool:
	return _empty.visible


func empty_note_color() -> Color:
	return _empty_note.get_theme_color("font_color")


func search_text() -> String:
	return _search_text


func sort_key() -> StringName:
	return _sort_key


#The filter half of the query plus the search text and the sort key of this page.
func query() -> Dictionary:
	var q: Dictionary = _filters.query()
	q["search"] = _search_text
	q["sort"] = _sort_key
	return q


func results() -> Array[BazaarItemData]:
	return BazaarManager.filter_items(query())


func result_count() -> int:
	return results().size()


func cards() -> Array[ItemCard]:
	var out: Array[ItemCard] = []
	for child: Node in _grid.get_children():
		if child is ItemCard:
			out.append(child as ItemCard)
	return out


func card_count() -> int:
	return cards().size()


func card_for(item_id: int) -> ItemCard:
	for card: ItemCard in cards():
		if card.item_id() == item_id:
			return card
	return null


func first_card() -> ItemCard:
	var found: Array[ItemCard] = cards()
	return found[0] if not found.is_empty() else null


func pick_department(key: StringName) -> void:
	_filters.pick_department(key)


func toggle_subtype(key: String) -> void:
	_filters.toggle_subtype(key)


func pick_price(key: StringName) -> void:
	_filters.pick_price(key)


func set_custom_price(low: int, high: int) -> void:
	_filters.set_custom_price(low, high)


func toggle_rarity(index: int) -> void:
	_filters.toggle_rarity(index)


#The link of the panel and the link of the empty grid both land here: filters and search go.
func clear_filters() -> void:
	_search_text = ""
	_search.text = ""
	_filters.clear_filters()
	refresh()


func set_search(body_text: String) -> void:
	_search_text = body_text.strip_edges()
	_search.text = body_text
	refresh()


func pick_sort(key: StringName) -> void:
	if not BazaarManager.SORTS.has(key):
		return
	_sort_key = key
	_sort.select(key)
	refresh()


#Writes the cart quantity into the cards without rebuilding the grid.
func sync_cart() -> void:
	if not is_node_ready() or _grid == null:
		return
	for card: ItemCard in cards():
		card.qty_in_cart = int(BazaarManager.cart.get(card.item_id(), 0))


func refresh() -> void:
	if not is_node_ready() or _grid == null:
		return
	var q: Dictionary = query()
	_filters.refresh(q)
	var found: Array[BazaarItemData] = BazaarManager.filter_items(q)
	GuiNodes.clear(_grid)
	for entry: BazaarItemData in found:
		var card: ItemCard = CARD_SCENE.instantiate() as ItemCard
		card.item = entry
		card.qty_in_cart = int(BazaarManager.cart.get(entry.id, 0))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(card)
	_crumb.text = _crumb_text()
	_count.text = BazaarUi.plural(found.size(), "result", "results")
	_empty.visible = found.is_empty()
	_scroll.visible = not found.is_empty()
	_clear_x.visible = _search.text != ""


func _build() -> void:
	var columns: HBoxContainer = GuiStyle.hbox(COLUMN_GAP)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(columns)
	_filters = PANEL_SCENE.instantiate() as FilterPanel
	_filters.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_filters.filters_changed.connect(_on_filters_changed)
	_filters.clear_all_requested.connect(clear_filters)
	_filters.take_me_there.connect(take_me_there.emit)
	columns.add_child(_filters)
	var right: VBoxContainer = GuiStyle.vbox(ROW_GAP)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	right.add_child(_build_top_bar())
	_trim_search_box()
	right.add_child(_build_crumb_row())
	_scroll = GuiStyle.scroll()
	right.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", GRID_GAP)
	_grid.add_theme_constant_override("v_separation", GRID_GAP)
	_scroll.add_child(_grid)
	_empty = _build_empty()
	right.add_child(_empty)


func _build_top_bar() -> HBoxContainer:
	var bar: HBoxContainer = GuiStyle.hbox(10)
	var field_box: PanelContainer = BazaarUi.panel_box(GuiColors.INK, 2, GuiColors.BLUE_HI,
		SEARCH_BOX_PAD)
	field_box.custom_minimum_size = Vector2(SEARCH_WIDTH, SEARCH_HEIGHT)
	bar.add_child(field_box)
	var field_row: HBoxContainer = GuiStyle.hbox(4)
	field_box.add_child(field_row)
	_search = LineEdit.new()
	_search.placeholder_text = SEARCH_HINT
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_search.add_theme_font_override("font", GuiStyle.BODY)
	_search.add_theme_font_size_override("font_size", 13)
	_search.add_theme_color_override("font_color", GuiColors.CREAM)
	_search.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_search.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_search.text_submitted.connect(_on_search_submitted)
	field_row.add_child(_search)
	_clear_x = CloseX.make(CloseX.SCALE_MINI)
	_clear_x.custom_minimum_size = Vector2(MINI_CLOSE, MINI_CLOSE)
	_clear_x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_clear_x.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_clear_x.tooltip_text = "Clear search"
	_clear_x.pressed.connect(_on_clear_x_pressed)
	field_row.add_child(_clear_x)
	_search_button = BazaarUi.button("", &"orange", SEARCH_BTN_H, 10)
	_search_button.icon = Icons.tinted("magnifier", SEARCH_ICON_INK, SEARCH_ICON_SCALE, true)
	_search_button.expand_icon = false
	_search_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_search_button.add_theme_color_override("icon_normal_color", Color.WHITE)
	_search_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_search_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_search_button.pressed.connect(_on_search_pressed)
	field_row.add_child(_search_button)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)
	_sort = BazaarUi.dropdown()
	_sort.label = SORT_CAPTION
	_sort.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sort.set_options(_sort_options())
	_sort.selected = _sort_key
	_sort.option_selected.connect(_on_sort_selected)
	bar.add_child(_sort)
	return bar


#BevelButton pads every state by 8 by 6, which would make the 28 px search art a 44x40 button and
#grow the 36 px field box to 46. This box trims it to the 30 px interior of that field. It runs
#after the button is in the tree, where BevelButton._ready writes its own boxes.
func _trim_search_box() -> void:
	var box := StyleBoxEmpty.new()
	box.content_margin_left = SEARCH_PAD_X
	box.content_margin_right = SEARCH_PAD_X
	box.content_margin_top = SEARCH_PAD_Y
	box.content_margin_bottom = SEARCH_PAD_Y
	for state: StringName in BevelButton.STATES:
		_search_button.add_theme_stylebox_override(state, box)
	_search_button.custom_minimum_size = Vector2(SEARCH_BTN_W, SEARCH_BTN_H)


func _build_crumb_row() -> HBoxContainer:
	var row: HBoxContainer = GuiStyle.hbox(10)
	_crumb = GuiStyle.label(ALL_CRUMB, GuiStyle.BODY, CRUMB_SIZE, GuiColors.SKY)
	_crumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_crumb)
	_count = GuiStyle.label("", GuiStyle.BODY, COUNT_SIZE, GuiColors.MUTED)
	row.add_child(_count)
	return row


func _build_empty() -> VBoxContainer:
	_empty_note = GuiStyle.label(EMPTY_NOTE, GuiStyle.BODY, EMPTY_NOTE_SIZE, GuiColors.SKY)
	var link: Button = BazaarUi.button(CLEAR_TEXT, &"neutral", EMPTY_HEIGHT, 10)
	link.pressed.connect(clear_filters)
	return BazaarUi.empty_state(EMPTY_TITLE, _empty_note, link)


func _sort_options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in range(BazaarManager.SORTS.size()):
		out.append({"key": BazaarManager.SORTS[i], "label": BazaarManager.SORT_LABELS[i],
			"enabled": true})
	return out


func _crumb_text() -> String:
	var parts: Array[String] = []
	var dept: String = _filters.department_key()
	parts.append(ALL_CRUMB if dept == "" else BazaarUi.dept_label(dept))
	var picked: Array[String] = _filters.checked_subtypes()
	if not picked.is_empty():
		parts.append(", ".join(picked))
	if _search_text != "":
		parts.append("\"%s\"" % _search_text)
	return CRUMB_JOIN.join(parts)


func _on_filters_changed() -> void:
	refresh()


func _on_search_submitted(submitted: String) -> void:
	set_search(submitted)


func _on_search_pressed() -> void:
	set_search(_search.text)


func _on_clear_x_pressed() -> void:
	set_search("")


func _on_sort_selected(key: StringName) -> void:
	pick_sort(key)
