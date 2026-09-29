class_name PromotionsViewer extends Control

#The My Promotions screen: the Job Ads and Guild Ads tabs over one campaign panel. The viewer keeps
#the filter and the sort the reader picked, asks PromotionsManager which campaigns those leave
#standing and hands them to CampaignList; it never sorts a list itself. A tab the guild has not
#bought yet puts its ModeLock block up in place of the grid, with no toolbar and no new button.

signal view_applicants(campaign_id: int)
signal campaign_launched(campaign: CampaignData)
signal campaign_ended(campaign_id: int)

enum Tab {JOB, GUILD}

const FONT_BOLD: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const FONT_BODY: FontVariation = preload("res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres")
const TITLE_COLOR: Color = Color("#f28c28")
const DESC_COLOR: Color = Color("#9cc6ef")
const NOTICE_BG: Color = Color("#0e1628")
const NOTICE_GREEN: Color = Color("#6cc36a")
const TITLE_SIZE: int = 16
const DESC_SIZE: int = 14
const NOTICE_SIZE: int = 14
const NOTICE_RING_PX: int = 3
const NOTICE_PAD_X: float = 14.0
const NOTICE_PAD_Y: float = 8.0
const NOTICE_SECONDS: float = 3.2
const NOTICE_TOP: float = 10.0
const TAB_ICON_SCALE: int = 2
const TAB_GAP: int = 6
const ROW_GAP: int = 12
const HEAD_GAP: int = 14
const JOB_KEY: StringName = &"job"
const PROMO_KEY: StringName = &"promo"
const JOB_TITLE: String = "Job Ads"
const PROMO_TITLE: String = "Guild Ads"
const JOB_DESC: String = "Post jobs to attract mercs to apply to your guild."
const PROMO_DESC: String = "Promote your guild to attract new contracts."
const JOB_TIP: String = "Ads that bring mercs to your door"
const PROMO_TIP: String = "Ads that bring contracts to your door"
const END_TITLE: String = "End %s?"
const END_REFUND: String = "The campaign stops now. You get %s notes back for the %d unused %s%s."
const END_WOM: String = "The campaign stops now. Odd Job pay already given to your mercs is not refunded."
const END_PLAIN: String = "The campaign stops now."
const END_CTA_REFUND: String = "End - Refund %s n"
const END_CTA_PLAIN: String = "End Campaign"
const END_CANCEL: String = "Cancel"
const DAY_WORD: String = "day"
const DAYS_WORD: String = "days"
const MONTH_TAIL: String = " left in this month"
const LAUNCH_NOTICE: String = "%s launched."
const ENDED_NOTICE: String = "%s ended. %s notes refunded."

@export var start_tab: Tab = Tab.JOB
@export var mode: StringName = JOB_KEY

@onready var tabs: HBoxContainer = $Body/Rows/Tabs
@onready var job_tab: TabButton = $Body/Rows/Tabs/Job
@onready var guild_tab: TabButton = $Body/Rows/Tabs/Guild
@onready var mode_title: Label = $Body/Rows/Head/Titles/ModeTitle
@onready var mode_desc: Label = $Body/Rows/Head/Titles/ModeDesc
@onready var toolbar_node: AdsToolbar = $Body/Rows/Head/Toolbar
@onready var list_node: CampaignList = $Body/Rows/List
@onready var notice: PanelContainer = $Notice
@onready var notice_label: Label = $Notice/NoticeText
@onready var notice_timer: Timer = $NoticeTimer
@onready var builder_node: CampaignBuilder = $Builder
@onready var dialog: ConfirmDialog = $EndDialog

var sort_key: StringName = PromotionsManager.CAMPAIGN_SORT_DEFAULT
var ascending: bool = PromotionsManager.CAMPAIGN_ASCENDING_DEFAULT
var show_concluded: bool = AdsToolbar.DEFAULT_CONCLUDED
var show_infinite: bool = AdsToolbar.DEFAULT_INFINITE

#The campaign the End dialog is asking about, and what ending it hands back.
var _pending_id: int = 0
var _pending_refund: int = 0
var _pending_name: String = ""


func _ready() -> void:
	tabs.add_theme_constant_override(&"separation", TAB_GAP)
	tabs.alignment = BoxContainer.ALIGNMENT_BEGIN
	_setup_tab(job_tab, Tab.JOB, JOB_TITLE, JOB_TIP)
	_setup_tab(guild_tab, Tab.GUILD, PROMO_TITLE, PROMO_TIP)
	_style_label(mode_title, FONT_BOLD, TITLE_SIZE, TITLE_COLOR)
	_style_label(mode_desc, FONT_BODY, DESC_SIZE, DESC_COLOR)
	_style_notice()
	notice.visible = false
	notice_timer.one_shot = true
	notice_timer.wait_time = NOTICE_SECONDS
	notice_timer.timeout.connect(_hide_notice)
	toolbar_node.set_filter(show_concluded, show_infinite)
	toolbar_node.set_direction(ascending)
	toolbar_node.filter_changed.connect(_on_filter_changed)
	toolbar_node.sort_changed.connect(_on_sort_changed)
	toolbar_node.direction_changed.connect(_on_direction_changed)
	list_node.view_applicants.connect(_on_view)
	list_node.end_pressed.connect(press_end)
	list_node.new_pressed.connect(press_new)
	list_node.take_me_there.connect(_on_take_me_there)
	builder_node.launched.connect(_on_launched)
	builder_node.take_me_there.connect(_on_take_me_there)
	dialog.confirmed.connect(_on_end_confirmed)
	PromotionsManager.campaigns_changed.connect(refresh)
	SubscriptionManager.changed.connect(refresh)
	GameState.day_changed.connect(_on_day_changed)
	open_tab(key_of(start_tab))


#Moves to a tab by its PromotionsManager mode key, &"job" or &"promo".
func open_tab(key: StringName) -> void:
	mode = PROMO_KEY if key == PROMO_KEY else JOB_KEY
	refresh()


func current_tab() -> int:
	return Tab.GUILD if mode == PROMO_KEY else Tab.JOB


func key_of(tab: int) -> StringName:
	return PROMO_KEY if tab == Tab.GUILD else JOB_KEY


func mode_key() -> String:
	return String(mode)


func title_text() -> String:
	return PROMO_TITLE if mode == PROMO_KEY else JOB_TITLE


func desc_text() -> String:
	return PROMO_DESC if mode == PROMO_KEY else JOB_DESC


func mode_locked() -> bool:
	return not PromotionsManager.mode_unlocked(mode_key(), SubscriptionManager.entitlements())


#Draws the header, the toolbar count and the cards of the tab that is up.
func refresh() -> void:
	if not is_node_ready():
		return
	var key: String = mode_key()
	mode_title.text = title_text()
	mode_desc.text = desc_text()
	job_tab.active = mode == JOB_KEY
	guild_tab.active = mode == PROMO_KEY
	if mode_locked():
		toolbar_node.visible = false
		list_node.show_lock(PromotionsManager.mode_lock(key))
		return
	toolbar_node.visible = true
	var today: int = GameState.day()
	var total: int = PromotionsManager.campaign_count(key)
	var kept: Array[CampaignData] = PromotionsManager.campaigns_filtered(key, show_concluded,
		show_infinite, today)
	var shown: Array[CampaignData] = PromotionsManager.campaigns_sorted(kept, sort_key,
		ascending, today)
	toolbar_node.set_count(shown.size(), total)
	list_node.set_new_label(CampaignList.NEW_PROMO if mode == PROMO_KEY else CampaignList.NEW_JOB)
	list_node.set_new_visible(true)
	list_node.set_cards(shown, _empty_line(total))


func press_tab(key: StringName) -> void:
	open_tab(key)


func tab_button(tab: int) -> TabButton:
	return guild_tab if tab == Tab.GUILD else job_tab


func tab_active(tab: int) -> bool:
	return tab_button(tab).active


func toolbar() -> AdsToolbar:
	return toolbar_node


func toolbar_shown() -> bool:
	return is_node_ready() and toolbar_node.visible


func campaign_list() -> CampaignList:
	return list_node


func builder() -> CampaignBuilder:
	return builder_node


func confirm() -> ConfirmDialog:
	return dialog


func card_count() -> int:
	return list_node.card_count() if is_node_ready() else 0


func card_names() -> Array[String]:
	return list_node.card_names() if is_node_ready() else []


func shown_text() -> String:
	return toolbar_node.shown_text() if is_node_ready() else ""


func empty_text() -> String:
	return list_node.empty_text() if is_node_ready() else ""


func lock_block() -> ModeLock:
	return list_node.mode_lock()


func lock_shown() -> bool:
	return is_node_ready() and list_node.lock_shown()


func new_shown() -> bool:
	return is_node_ready() and list_node.new_visible()


func new_label() -> String:
	return list_node.new_label() if is_node_ready() else ""


func pick_sort(key: StringName) -> void:
	toolbar_node.pick_sort(key)


func toggle_direction() -> void:
	toolbar_node.toggle_direction()


func set_filter(concluded: bool, infinite: bool) -> void:
	show_concluded = concluded
	show_infinite = infinite
	toolbar_node.set_filter(concluded, infinite)
	refresh()


func press_new() -> void:
	if mode_locked():
		return
	builder_node.open_for(mode)


func press_view(campaign_id: int) -> void:
	var card: CampaignCard = list_node.card_for(campaign_id)
	if card == null:
		return
	card.press_view()


#Opens the End dialog for one campaign. A campaign that already ran out cannot be ended.
func press_end(campaign_id: int) -> void:
	var preview: Dictionary = PromotionsManager.end_preview(campaign_id)
	if not bool(preview.get("ok", false)):
		return
	_pending_id = campaign_id
	_pending_refund = int(preview.get("refund", 0))
	_pending_name = PromotionsManager.campaign_name(campaign_id)
	dialog.ask(END_TITLE % _pending_name, end_body(preview), end_cta(preview), END_CANCEL,
		ConfirmDialog.Severity.RED, ConfirmDialog.Kind.BAD)


func end_body(preview: Dictionary) -> String:
	var refund: int = int(preview.get("refund", 0))
	if refund > 0:
		var unused: int = int(preview.get("unused", 0))
		var word: String = DAY_WORD if unused == 1 else DAYS_WORD
		var tail: String = MONTH_TAIL if bool(preview.get("infinite", false)) else ""
		return END_REFUND % [NotesLabel.format_amount(refund), unused, word, tail]
	if bool(preview.get("crew_paid", false)):
		return END_WOM
	return END_PLAIN


func end_cta(preview: Dictionary) -> String:
	var refund: int = int(preview.get("refund", 0))
	if refund <= 0:
		return END_CTA_PLAIN
	return END_CTA_REFUND % NotesLabel.format_amount(refund)


func press_confirm() -> void:
	dialog.press(1)


func press_cancel() -> void:
	dialog.press(0)


func notice_text() -> String:
	return notice_label.text if is_node_ready() else ""


func notice_shown() -> bool:
	return is_node_ready() and notice.visible


func _setup_tab(button: TabButton, tab: int, caption: String, tip: String) -> void:
	button.label = caption
	button.description = tip
	button.index = tab
	button.icon_id = PromoGlyphs.tab_id(key_of(tab))
	button.icon_scale = TAB_ICON_SCALE
	button.tab_pressed.connect(_on_tab_pressed)


func _empty_line(total: int) -> String:
	if total > 0:
		return CampaignList.EMPTY_FILTERS
	return CampaignList.EMPTY_PROMO if mode == PROMO_KEY else CampaignList.EMPTY_JOB


func _style_label(node: Label, font: FontVariation, font_size: int, tint: Color) -> void:
	node.add_theme_font_override(&"font", font)
	node.add_theme_font_size_override(&"font_size", font_size)
	node.add_theme_color_override(&"font_color", tint)


func _style_notice() -> void:
	notice.grow_horizontal = Control.GROW_DIRECTION_BOTH
	notice.offset_top = NOTICE_TOP
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_label.add_theme_font_override(&"font", FONT_BODY)
	notice_label.add_theme_font_size_override(&"font_size", NOTICE_SIZE)
	notice_label.add_theme_color_override(&"font_color", NOTICE_GREEN)
	notice.add_theme_stylebox_override(&"panel", _notice_box(NOTICE_GREEN))


func _notice_box(tint: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = NOTICE_BG
	box.set_border_width_all(NOTICE_RING_PX)
	box.border_color = tint
	box.content_margin_left = NOTICE_PAD_X
	box.content_margin_right = NOTICE_PAD_X
	box.content_margin_top = NOTICE_PAD_Y
	box.content_margin_bottom = NOTICE_PAD_Y
	return box


#The one line the screen flashes after a launch or an end, gone again a few seconds later.
func _flash(line: String, tint: Color) -> void:
	notice_label.text = line
	notice_label.add_theme_color_override(&"font_color", tint)
	notice.add_theme_stylebox_override(&"panel", _notice_box(tint))
	notice.visible = true
	if is_inside_tree():
		notice_timer.start(NOTICE_SECONDS)


func _hide_notice() -> void:
	notice.visible = false


func _on_tab_pressed(tab: int) -> void:
	open_tab(key_of(tab))


func _on_filter_changed(concluded: bool, infinite: bool) -> void:
	show_concluded = concluded
	show_infinite = infinite
	refresh()


func _on_sort_changed(key: StringName) -> void:
	sort_key = key
	refresh()


func _on_direction_changed(up: bool) -> void:
	ascending = up
	refresh()


func _on_view(campaign_id: int) -> void:
	view_applicants.emit(campaign_id)


func _on_launched(campaign: CampaignData) -> void:
	if campaign == null:
		return
	_flash(LAUNCH_NOTICE % campaign.name, NOTICE_GREEN)
	campaign_launched.emit(campaign)
	refresh()


func _on_end_confirmed() -> void:
	var campaign_id: int = _pending_id
	if campaign_id == 0:
		return
	var refund: int = _pending_refund
	var label: String = _pending_name
	_pending_id = 0
	_pending_refund = 0
	_pending_name = ""
	if not PromotionsManager.end(campaign_id):
		return
	if refund > 0:
		_flash(ENDED_NOTICE % [label, NotesLabel.format_amount(refund)], NOTICE_GREEN)
	campaign_ended.emit(campaign_id)
	refresh()


func _on_day_changed(_day_index: int) -> void:
	refresh()


func _on_take_me_there(target: Dictionary) -> void:
	GameState.go_to_plans(target)
