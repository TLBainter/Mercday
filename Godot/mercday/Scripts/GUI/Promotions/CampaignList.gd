class_name CampaignList extends VBoxContainer

#The campaign panel of a My Promotions tab: a three column grid of CampaignCard inside the only
#scroll box of the screen, the empty line when the filters leave nothing, the ModeLock block when
#the tab is not sold yet, and the new-campaign button under the panel. The list never sorts or
#filters; it draws the campaigns it is handed.

signal view_applicants(campaign_id: int)
signal end_pressed(campaign_id: int)
signal new_pressed
signal take_me_there(target: Dictionary)

const CARD_SCENE: PackedScene = preload("res://Scenes/GUI/Promotions/CampaignCard.tscn")
const FONT_SILK_BOLD: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const FONT_BODY: FontVariation = preload("res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres")
const PANEL_BG: Color = Color("#15223d")
const PANEL_RING: Color = Color("#1f3560")
const EMPTY_COLOR: Color = Color("#9cc6ef")
const COLUMNS: int = 3
const GRID_GAP: int = 14
const PAD_LEFT: float = 14.0
const PAD_RIGHT: float = 20.0
const PAD_TOP: float = 14.0
const PAD_BOTTOM: float = 14.0
const RING_PX: int = 2
const EMPTY_SIZE: int = 15
const NEW_SIZE: int = 12
const NEW_HEIGHT: float = 40.0
const ROW_GAP: int = 12
const EMPTY_FILTERS: String = "No campaigns match your filters."
const EMPTY_JOB: String = "No job ads running."
const EMPTY_PROMO: String = "No guild ads running."
const NEW_JOB: String = "+ New Hiring Campaign"
const NEW_PROMO: String = "+ New Guild Promo Campaign"

@onready var frame: PanelContainer = $Frame
@onready var scroll: ScrollContainer = $Frame/Scroll
@onready var grid: GridContainer = $Frame/Scroll/Pad/Inner/Grid
@onready var lock: ModeLock = $Frame/Lock
@onready var empty: Label = $Frame/Empty
@onready var actions: HBoxContainer = $Actions

var new_button: BevelButton = null
var cards: Array[CampaignCard] = []


func _ready() -> void:
	add_theme_constant_override(&"separation", ROW_GAP)
	frame.size_flags_vertical = SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override(&"panel", _panel_box())
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	grid.columns = COLUMNS
	grid.add_theme_constant_override(&"h_separation", GRID_GAP)
	grid.add_theme_constant_override(&"v_separation", GRID_GAP)
	empty.add_theme_font_override(&"font", FONT_BODY)
	empty.add_theme_font_size_override(&"font_size", EMPTY_SIZE)
	empty.add_theme_color_override(&"font_color", EMPTY_COLOR)
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty.visible = false
	lock.visible = false
	lock.take_me_there.connect(_on_take_me_there)
	_build_new()
	new_button.pressed.connect(press_new)


#The cards the panel draws, in the order they arrive. An empty list puts the empty line up.
func set_cards(list: Array[CampaignData], empty_line: String) -> void:
	if not is_node_ready():
		return
	lock.visible = false
	scroll.visible = true
	_clear()
	for campaign: CampaignData in list:
		var card: CampaignCard = CARD_SCENE.instantiate()
		grid.add_child(card)
		card.campaign = campaign
		card.view_applicants.connect(_on_view)
		card.end_pressed.connect(_on_end)
		cards.append(card)
	empty.text = empty_line
	empty.visible = cards.is_empty()


#Puts the lock block up in place of the grid: no cards and no new-campaign button.
func show_lock(row: Dictionary) -> void:
	if not is_node_ready():
		return
	_clear()
	lock.setup(row)
	lock.visible = true
	scroll.visible = false
	empty.visible = false
	set_new_visible(false)


func set_new_label(text: String) -> void:
	if is_node_ready():
		new_button.text = text


func set_new_visible(shown: bool) -> void:
	if is_node_ready():
		actions.visible = shown


func new_label() -> String:
	return new_button.text if is_node_ready() else ""


func new_visible() -> bool:
	return is_node_ready() and actions.visible


func card_count() -> int:
	return cards.size()


func card_at(index: int) -> CampaignCard:
	if index < 0 or index >= cards.size():
		return null
	return cards[index]


func card_for(campaign_id: int) -> CampaignCard:
	for card: CampaignCard in cards:
		if card.campaign_id() == campaign_id:
			return card
	return null


func card_names() -> Array[String]:
	var out: Array[String] = []
	for card: CampaignCard in cards:
		out.append(card.campaign.name if card.campaign != null else "")
	return out


func empty_text() -> String:
	return empty.text if is_node_ready() else ""


func empty_shown() -> bool:
	return is_node_ready() and empty.visible


func lock_shown() -> bool:
	return is_node_ready() and lock.visible


func mode_lock() -> ModeLock:
	return lock


func press_new() -> void:
	new_pressed.emit()


func _clear() -> void:
	for card: CampaignCard in cards:
		grid.remove_child(card)
		card.queue_free()
	cards.clear()


func _panel_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_BG
	box.set_border_width_all(RING_PX)
	box.border_color = PANEL_RING
	box.content_margin_left = PAD_LEFT
	box.content_margin_right = PAD_RIGHT
	box.content_margin_top = PAD_TOP
	box.content_margin_bottom = PAD_BOTTOM
	return box


#Item 11: the one core BevelButton scene, added where the scene used to hold a plain Button.
func _build_new() -> void:
	new_button = BevelButton.make("", &"orange", Vector2(0.0, NEW_HEIGHT))
	new_button.add_theme_font_override(&"font", FONT_SILK_BOLD)
	new_button.add_theme_font_size_override(&"font_size", NEW_SIZE)
	actions.add_child(new_button)


func _on_view(campaign_id: int) -> void:
	view_applicants.emit(campaign_id)


func _on_end(campaign_id: int) -> void:
	end_pressed.emit(campaign_id)


func _on_take_me_there(target: Dictionary) -> void:
	take_me_there.emit(target)
