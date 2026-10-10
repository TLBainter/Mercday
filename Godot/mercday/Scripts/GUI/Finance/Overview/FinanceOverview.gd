class_name FinanceOverview
extends FinancePage

#The Overview page of the Finance window: the four stat tiles over the Projection on the left,
#the Monthly Expenses box over the Recent Transactions list on the right. Every number comes from
#FinanceLedger; a hidden page only marks itself dirty and catches up when the tab is shown again.

const TILE_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/StatTile.tscn")
const STAT_GAP: int = 10
const TILE_TOLERANCE: float = 0.5

@onready var stats: HBoxContainer = $Columns/Left/Stats
@onready var projection_box: FinanceProjection = $Columns/Left/Projection
@onready var expenses_box: FinanceExpenses = $Columns/Right/Expenses
@onready var transactions_box: FinanceTransactions = $Columns/Right/Transactions

var _tiles: Dictionary = {}
var _order: Array[String] = []


func _ready() -> void:
	stats.add_theme_constant_override("separation", STAT_GAP)
	stats.resized.connect(_fit_tiles)
	visibility_changed.connect(_on_visibility_changed)
	FinanceLedger.changed.connect(_on_books_changed)
	GameState.money_changed.connect(_on_money_changed)
	GameState.day_changed.connect(_on_day_changed)
	SubscriptionManager.changed.connect(_on_books_changed)
	_refresh()


#The Overview writes itself on every show, dirty or not.
func page_shown() -> void:
	_refresh()


func stat_tile(key: String) -> StatTile:
	return _tiles.get(key, null) as StatTile


func stat_count() -> int:
	return _order.size()


func stat_keys() -> Array[String]:
	return _order.duplicate()


func projection() -> FinanceProjection:
	return projection_box


func expenses() -> FinanceExpenses:
	return expenses_box


func transactions() -> FinanceTransactions:
	return transactions_box


func refresh() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	super()
	_fill_stats()
	projection_box.refresh()
	expenses_box.refresh()
	transactions_box.refresh()


func _fill_stats() -> void:
	var cards: Array[Dictionary] = FinanceLedger.stat_cards()
	for i: int in cards.size():
		var row: Dictionary = cards[i]
		var key: String = String(row["key"])
		var tile: StatTile = _tiles.get(key, null) as StatTile
		if tile == null:
			tile = _make_tile(key)
		tile.set_stat({"label": String(row["label"]), "text": String(row["value"]),
			"color": row["color"], "sub": String(row["sub"])})
	_fit_tiles()


func _make_tile(key: String) -> StatTile:
	var tile: StatTile = TILE_SCENE.instantiate()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_child(tile)
	var sub: Label = tile.sub_text
	if sub != null:
		sub.clip_text = false
		sub.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tiles[key] = tile
	_order.append(key)
	return tile


#The four tiles share the width of the row; the tiles hold their own texts to that width.
func _fit_tiles() -> void:
	if _order.is_empty():
		return
	var gaps: float = float(STAT_GAP * (_order.size() - 1))
	var want: float = floorf(maxf(0.0, stats.size.x - gaps) / float(_order.size()))
	for key: String in _order:
		var tile: StatTile = _tiles[key] as StatTile
		if absf(tile.custom_minimum_size.x - want) >= TILE_TOLERANCE:
			tile.custom_minimum_size = Vector2(want, tile.custom_minimum_size.y)


func _on_books_changed() -> void:
	mark_dirty()


func _on_money_changed(_bank_notes: int) -> void:
	mark_dirty()


func _on_day_changed(_day_index: int) -> void:
	mark_dirty()
