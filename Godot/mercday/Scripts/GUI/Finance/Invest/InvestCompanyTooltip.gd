class_name InvestCompanyTooltip extends Control

#The hover card of a roster row: the issuer type and its lender, the lender face, the contract
#counts and the last accepted contract as a button into the Contract Viewer.

const CARD_WIDTH: float = 290.0
const CARD_RESERVE: float = 330.0
const ITEM_GAP: float = 12.0
const STAT_STYLE: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/invest_stat_cell.tres")
const STAT_LABEL_SIZE: int = 7
const STAT_VALUE_SIZE: int = 16
const FACE_SCALE: int = 4
const REL_LIMIT: int = 5
const RING_WIDTH: float = 3.0
const SHADOW_STEP: float = 6.0

signal open_contract(entry_id: int)

@export var hide_delay: float = 0.22

@onready var frame: MarginContainer = $Frame
@onready var type_label: Label = $Frame/Col/TypeLabel
@onready var name_label: Label = $Frame/Col/NameLabel
@onready var face_slot: CenterContainer = $Frame/Col/FaceBox/FaceSlot
@onready var stats_row: HBoxContainer = $Frame/Col/StatsRow
@onready var taken_tile: StatTile = $Frame/Col/StatsRow/Taken
@onready var good_tile: StatTile = $Frame/Col/StatsRow/Succeeded
@onready var bad_tile: StatTile = $Frame/Col/StatsRow/Failed
@onready var accepted_label: Label = $Frame/Col/AcceptedLabel
@onready var empty_box: MarginContainer = $Frame/Col/EmptyBox
@onready var contract_row: Button = $Frame/Col/ContractRow
@onready var contract_hatch: TextureRect = $Frame/Col/ContractRow/Row/Hatch
@onready var contract_name: Label = $Frame/Col/ContractRow/Row/TextCol/NameLabel
@onready var contract_status: Label = $Frame/Col/ContractRow/Row/TextCol/StatusLabel
@onready var hide_timer: Timer = $HideTimer

var company_id: int = -1

var _entry_id: int = -1
var _face: MoodFace = null


func _ready() -> void:
	custom_minimum_size.x = CARD_WIDTH
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	contract_hatch.texture = InvestGlyphs.hatch(Vector2i(40, 40))
	hide_timer.one_shot = true
	hide_timer.timeout.connect(hide_now)
	contract_row.pressed.connect(press_contract)
	mouse_entered.connect(cancel_hide)
	mouse_exited.connect(begin_hide)
	_face = _build_face()


#Fills the card for company id and places it 12 px right of item, clamped inside the page.
func show_for(id: int, item: Control) -> void:
	company_id = id
	cancel_hide()
	_refresh()
	visible = true
	size = Vector2(CARD_WIDTH, frame.get_combined_minimum_size().y)
	if item != null:
		_place(item)
	queue_redraw()


func hide_now() -> void:
	hide_timer.stop()
	visible = false


func begin_hide() -> void:
	if not visible:
		return
	hide_timer.stop()
	hide_timer.wait_time = maxf(0.01, hide_delay)
	hide_timer.start()


func cancel_hide() -> void:
	hide_timer.stop()


func is_shown() -> bool:
	return visible


func hide_pending() -> bool:
	return not hide_timer.is_stopped()


func press_contract() -> void:
	if _entry_id < 0:
		return
	open_contract.emit(_entry_id)


func entry_id() -> int:
	return _entry_id


func type_text() -> String:
	return type_label.text


func name_text() -> String:
	return name_label.text


func stat_texts() -> PackedStringArray:
	return PackedStringArray([taken_tile.value_text, good_tile.value_text, bad_tile.value_text])


func contract_text() -> String:
	return contract_name.text


func status_text() -> String:
	return contract_status.text


func status_color() -> Color:
	return contract_status.get_theme_color("font_color")


func empty_shown() -> bool:
	return empty_box.visible


func contract_shown() -> bool:
	return contract_row.visible


func face() -> MoodFace:
	return _face


#The lender relationship behind FinanceManager, 0 when the manager or the row is missing.
func relationship() -> int:
	var manager: Node = get_node_or_null("/root/FinanceManager")
	if manager == null or not manager.has_method("lenders"):
		return 0
	var key: String = String(StockMarket.company(company_id).get("lender", ""))
	if key == "":
		return 0
	var rows: Array = manager.call("lenders")
	for row: Variant in rows:
		if not (row is Dictionary):
			continue
		var lender: Dictionary = row as Dictionary
		if String(lender.get("name", "")) == key:
			return clampi(int(lender.get("rel", 0)), -REL_LIMIT, REL_LIMIT)
	return 0


func _refresh() -> void:
	var row: Dictionary = StockMarket.company(company_id)
	type_label.text = "%s - %s" % [String(row.get("type", "")), String(row.get("lender", ""))]
	name_label.text = String(row.get("name", ""))
	if _face != null:
		_face.opinion = relationship()
	var stats: Dictionary = StockMarket.company_stats(company_id)
	_fill_tile(taken_tile, "Contracts Taken", int(stats.get("taken", 0)), InvestText.CREAM)
	_fill_tile(good_tile, "Successful", int(stats.get("succeeded", 0)), InvestText.GREEN)
	_fill_tile(bad_tile, "Failed", int(stats.get("failed", 0)), InvestText.RED)
	var accepted: Dictionary = StockMarket.last_accepted(company_id)
	_entry_id = int(accepted.get("entry_id", -1)) if not accepted.is_empty() else -1
	var has_row: bool = not accepted.is_empty()
	contract_row.visible = has_row
	empty_box.visible = not has_row
	if has_row:
		contract_name.text = String(accepted.get("name", ""))
		contract_status.text = String(accepted.get("status", ""))
		contract_status.add_theme_color_override("font_color",
			Color(String(accepted.get("color", "#f3ead7"))))


func _fill_tile(tile: StatTile, caption: String, amount: int, tint: Color) -> void:
	tile.compact = true
	tile.show_glyph = false
	tile.label = caption
	tile.value_text = str(amount)
	tile.value_color = tint
	tile.add_theme_stylebox_override("panel", STAT_STYLE)
	tile.label_text.add_theme_font_size_override("font_size", STAT_LABEL_SIZE)
	tile.value_row.font_size = STAT_VALUE_SIZE


func _build_face() -> MoodFace:
	var path: String = "res://Scenes/GUI/Shared/MoodFace.tscn"
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path) as PackedScene
	var node: MoodFace = scene.instantiate() as MoodFace
	node.guild = true
	node.pixel_scale = FACE_SCALE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face_slot.add_child(node)
	return node


#12 px right of the row, held inside the page so the whole card stays visible.
func _place(item: Control) -> void:
	var page: Control = get_parent() as Control
	var host_size: Vector2 = page.size if page != null else size
	var origin: Vector2 = Vector2.ZERO
	if page != null:
		origin = item.global_position - page.global_position
	var at := Vector2(origin.x + item.size.x + ITEM_GAP, origin.y)
	if at.y + CARD_RESERVE > host_size.y:
		at.y = host_size.y - CARD_RESERVE - 10.0
	position = Vector2(at.x, maxf(0.0, at.y))


#The card paints its own hard shadow, body and ring, and the dashed ring of the empty box, so
#every layer sits under the content nodes.
func _draw() -> void:
	var body := Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(body.position + Vector2(SHADOW_STEP, SHADOW_STEP), body.size),
		Color(0.0, 0.0, 0.0, 0.5), true)
	draw_rect(body, InvestText.PANEL, true)
	var half: float = RING_WIDTH / 2.0
	draw_rect(Rect2(half, half, maxf(0.0, size.x - RING_WIDTH), maxf(0.0, size.y - RING_WIDTH)),
		InvestText.ORANGE, false, RING_WIDTH)
	if not empty_box.visible:
		return
	var box := Rect2(empty_box.global_position - global_position, empty_box.size)
	draw_rect(box, InvestText.NAVY, true)
	InvestText.draw_dashed_border(self, box, InvestText.BLUE3)
