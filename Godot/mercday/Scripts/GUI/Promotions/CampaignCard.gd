class_name CampaignCard extends PanelContainer

#One running or concluded campaign in the My Promotions grid: the type icon and name, the three
#money cells, the time bar, what the campaign brought in and the two actions. A concluded card
#greys its name and icon and drops the End link, so the View button takes the whole row.

signal view_applicants(campaign_id: int)
signal view_contracts(campaign_id: int)
signal end_pressed(campaign_id: int)

const FONT_SILK: FontVariation = GuiStyle.SILK
const FONT_BOLD: FontVariation = GuiStyle.SILK_BOLD
const FONT_BODY: FontVariation = GuiStyle.BODY
const CARD_BG: Color = GuiColors.BOX_BG
const CARD_RING: Color = GuiColors.BLUE_LO
const ICON_BG: Color = GuiColors.ROW_FILL
const RING_LIVE: Color = GuiColors.BLUE_HI
const RING_DONE: Color = GuiColors.BLUE_LO
const CREAM: Color = GuiColors.CREAM
const MUTED: Color = GuiColors.MUTED
const CAPTION: Color = GuiColors.SKY
const BUDGET: Color = GuiColors.AMBER
const END_COLOR: Color = Color("#ff3b2f")
const END_HOVER: Color = Color("#ff6a55")
const ICON_PX: float = 48.0
const ICON_SCALE: int = 2
const CARD_RING_PX: int = 2
const ICON_RING_PX: int = 2
const BAR_CELLS: int = 20
const NAME_SIZE: int = 13
const METHOD_SIZE: int = 11
const CAPTION_SIZE: int = 9
const VALUE_SIZE: int = 11
const END_SIZE: int = 10
const VIEW_SIZE: int = 11
const ROW_GAP: int = 10
const PAD: float = 14.0
const CARD_WIDTH: float = 330.0
const TODAY_TEXT: String = "Today"
const CONCLUDED_TEXT: String = "Concluded"
const INFINITE_TEXT: String = "Infinite"
const BILLED_LABEL: String = "Billed Monthly"
const LEFT_LABEL: String = "Time Remaining"
const STARTED_LABEL: String = "Started"
const SPENT_LABEL: String = "Spent so Far"
const BUDGET_LABEL: String = "Budget Remaining"
const JOB_RESULTS: String = "Applicants"
const PROMO_RESULTS: String = "Contracts Received"
const VIEW_TEXT: String = "View Applicants"
const VIEW_CONTRACTS_TEXT: String = "View Contracts"
const END_TEXT: String = "End Campaign"

var campaign: CampaignData = null:
	set(value):
		campaign = value
		refresh()

@onready var rows: VBoxContainer = $Rows
@onready var icon_box: Panel = $Rows/Header/IconBox
@onready var icon: TextureRect = $Rows/Header/IconBox/Icon
@onready var name_label: Label = $Rows/Header/Titles/CardName
@onready var method_label: Label = $Rows/Header/Titles/Method
@onready var started_tile: StatTile = $Rows/Stats/Started
@onready var spent_tile: StatTile = $Rows/Stats/Spent
@onready var budget_tile: StatTile = $Rows/Stats/Budget
@onready var left_label: Label = $Rows/TimeBox/Head/LeftLabel
@onready var left_value: Label = $Rows/TimeBox/Head/LeftValue
@onready var bar: CellBar = $Rows/TimeBox/Bar
@onready var results_label: Label = $Rows/Results/ResLabel
@onready var results_value: Label = $Rows/Results/ResValue
@onready var actions: HBoxContainer = $Rows/Actions
@onready var end_button: LinkButton = $Rows/Actions/End

var view_button: BevelButton = null


func _ready() -> void:
	custom_minimum_size.x = CARD_WIDTH
	add_theme_stylebox_override(&"panel", _card_box())
	rows.add_theme_constant_override(&"separation", ROW_GAP)
	icon_box.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	for tile: StatTile in [started_tile, spent_tile, budget_tile]:
		tile.compact = true
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	GuiStyle.paint(name_label, FONT_BOLD, NAME_SIZE, CREAM)
	GuiStyle.paint(method_label, FONT_BODY, METHOD_SIZE, CAPTION)
	GuiStyle.paint(left_label, FONT_SILK, CAPTION_SIZE, CAPTION)
	GuiStyle.paint(left_value, FONT_BODY, VALUE_SIZE, CREAM)
	GuiStyle.paint(results_label, FONT_SILK, CAPTION_SIZE, CAPTION)
	GuiStyle.paint(results_value, FONT_BOLD, VALUE_SIZE, CREAM)
	left_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	results_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	left_label.size_flags_horizontal = SIZE_EXPAND_FILL
	results_label.size_flags_horizontal = SIZE_EXPAND_FILL
	bar.cells = BAR_CELLS
	_build_view()
	_style_end()
	view_button.pressed.connect(press_view)
	end_button.pressed.connect(press_end)
	refresh()


func refresh() -> void:
	if not is_node_ready():
		return
	if campaign == null:
		visible = false
		return
	visible = true
	var done: bool = is_concluded()
	var today: int = _today()
	icon.texture = PromoGlyphs.type_icon(campaign.type_key, ICON_SCALE, done)
	icon.modulate = PromoGlyphs.dim_modulate(done)
	icon_box.add_theme_stylebox_override(&"panel", _icon_box(done))
	name_label.text = campaign.name
	name_label.add_theme_color_override(&"font_color", MUTED if done else CREAM)
	method_label.text = method_text()
	started_tile.set_stat({"label": STARTED_LABEL, "text": started_text(), "glyph": false,
		"color": CREAM})
	started_tile.tooltip_text = started_tooltip()
	spent_tile.set_stat({"label": SPENT_LABEL, "text": "", "glyph": true,
		"amount": campaign.spent_so_far(today), "color": CREAM})
	budget_tile.set_stat({"label": BUDGET_LABEL, "text": "", "glyph": true,
		"amount": campaign.budget_remaining(today), "color": MUTED if done else BUDGET})
	left_label.text = left_caption()
	left_value.text = left_text()
	left_value.add_theme_color_override(&"font_color", MUTED if done else CREAM)
	bar.set_ratio(ratio())
	results_label.text = results_caption()
	results_value.text = results_text()
	view_button.text = view_text()
	view_button.visible = true
	end_button.visible = not done


func campaign_id() -> int:
	return campaign.id if campaign != null else -1


func is_concluded() -> bool:
	return campaign != null and campaign.is_concluded(_today())


func method_text() -> String:
	if campaign == null:
		return ""
	return String(CampaignTypeDefs.find(campaign.type_key).get("name", ""))


func started_text() -> String:
	if campaign == null:
		return ""
	var used: int = maxi(0, _today() - campaign.day_started)
	if used <= 0:
		return TODAY_TEXT
	return "%s ago" % GuiDates.days_text(used)


func started_tooltip() -> String:
	if campaign == null:
		return ""
	return GuiDates.day_text(campaign.day_started)


func left_caption() -> String:
	if campaign == null:
		return LEFT_LABEL
	return BILLED_LABEL if campaign.infinite else LEFT_LABEL


func left_text() -> String:
	if campaign == null:
		return ""
	if campaign.infinite:
		return INFINITE_TEXT
	if is_concluded():
		return CONCLUDED_TEXT
	return GuiDates.days_text(campaign.days_left(_today()))


func ratio() -> float:
	if campaign == null:
		return 0.0
	if campaign.infinite:
		return 1.0
	if campaign.days <= 0:
		return 0.0
	return clampf(float(campaign.days_left(_today())) / float(campaign.days), 0.0, 1.0)


func filled_cells() -> int:
	return CellBar.cells_for(ratio(), BAR_CELLS)


func results_caption() -> String:
	if campaign == null:
		return JOB_RESULTS
	return JOB_RESULTS if campaign.mode == CampaignData.MODE_JOB else PROMO_RESULTS


func results_text() -> String:
	return str(PromotionsManager.results_of(campaign))


#A job ad views the applicants it sent; a Guild Promo views the contracts it brought in.
func view_text() -> String:
	if campaign != null and campaign.mode == CampaignData.MODE_PROMO:
		return VIEW_CONTRACTS_TEXT
	return VIEW_TEXT


func has_view() -> bool:
	return is_node_ready() and view_button.visible


func has_end() -> bool:
	return is_node_ready() and end_button.visible


func press_view() -> void:
	if campaign == null:
		return
	if campaign.mode == CampaignData.MODE_PROMO:
		PromotionsManager.view_contracts(campaign.id)
		view_contracts.emit(campaign.id)
		return
	view_applicants.emit(campaign.id)


func press_end() -> void:
	if campaign == null or is_concluded():
		return
	end_pressed.emit(campaign.id)


func _today() -> int:
	return GameState.day()


func _card_box() -> StyleBoxFlat:
	return GuiStyle.flat(CARD_BG, CARD_RING_PX, CARD_RING, PAD)


func _icon_box(done: bool) -> StyleBoxFlat:
	return GuiStyle.flat(ICON_BG, ICON_RING_PX, RING_DONE if done else RING_LIVE)


#Builds the blue View button as the first action.
func _build_view() -> void:
	view_button = BevelButton.make(VIEW_TEXT, &"blue")
	view_button.add_theme_font_override(&"font", FONT_SILK)
	view_button.add_theme_font_size_override(&"font_size", VIEW_SIZE)
	view_button.size_flags_horizontal = SIZE_EXPAND_FILL
	actions.add_child(view_button)
	actions.move_child(view_button, 0)


func _style_end() -> void:
	end_button.text = END_TEXT
	end_button.underline = LinkButton.UNDERLINE_MODE_ALWAYS
	GuiStyle.paint(end_button, FONT_SILK, END_SIZE, END_COLOR)
	end_button.add_theme_color_override(&"font_hover_color", END_HOVER)
	end_button.add_theme_color_override(&"font_pressed_color", END_HOVER)
	end_button.add_theme_constant_override(&"underline_spacing", 4)
