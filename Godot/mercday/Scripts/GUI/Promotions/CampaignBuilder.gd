class_name CampaignBuilder extends Control

#The New Campaign modal of My Promotions: the five campaign types on the left, the name, the
#duration and the targeting on the right, and the footer that says what stops the launch and what
#it costs. The modal never moves notes itself: PromotionsManager.launch does that, and the reason
#line is the manager's own verdict, so the builder and the manager can never disagree.

signal launched(campaign: CampaignData)
signal closed
signal take_me_there(target: Dictionary)

const TYPE_ROW_SCENE: PackedScene = preload("res://Scenes/GUI/Promotions/TypeRow.tscn")
const FONT_SILK: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const FONT_BOLD: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const FONT_BODY: FontVariation = preload("res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres")
const BACKDROP: Color = Color(0.023529, 0.039216, 0.078431, 0.72)
const FRAME_BG: Color = Color("#1a2b4d")
const FRAME_RING: Color = Color("#f28c28")
const PANE_BG: Color = Color("#0e1628")
const FIELD_BG: Color = Color("#0a0f1c")
const FIELD_RING: Color = Color("#3b6fb6")
const CHIP_BG: Color = Color("#2a2410")
const CHIP_RING: Color = Color("#f2b33d")
const ORANGE: Color = Color("#f28c28")
const CREAM: Color = Color("#f3ead7")
const SKY: Color = Color("#9cc6ef")
const MUTED: Color = Color("#5e7699")
const GREEN: Color = Color("#6cc36a")
const RED: Color = Color("#e8583f")
const MODAL_SIZE: Vector2 = Vector2(1190, 628)
const RING_PX: int = 4
const FIELD_RING_PX: int = 2
const CHIP_RING_PX: int = 2
const BODY_GAP: int = 12
const COL_GAP: int = 16
const RIGHT_GAP: int = 10
const TYPE_COL_WIDTH: float = 372.0
const TYPE_GAP: int = 8
const TITLE_SIZE: int = 18
const CAPTION_SIZE: int = 9
const NAME_SIZE: int = 16
const NOTE_SIZE: int = 13
const COST_SIZE: int = 18
const CHIP_SIZE: int = 12
const LAUNCH_SIZE: int = 13
const FIELD_HEIGHT: float = 38.0
const FIELD_PAD: float = 12.0
const LAUNCH_BUTTON_SIZE: Vector2 = Vector2(220, 42)
const CHIP_PAD_X: float = 7.0
const CHIP_PAD_Y: float = 3.0
const NAME_MAX: int = 64
const DEFAULT_QTY: int = 5
const TITLE_JOB: String = "New Hiring Campaign"
const TITLE_PROMO: String = "New Guild Promo Campaign"
const TYPE_HEAD: String = "Campaign Type"
const BOOST_HEAD: String = "Marketing Agency +%d%%"
const BOOST_TIP: String = "Marketing Agency lifts every ad's effectiveness"
const NAME_CAPTION: String = "Campaign Name"
const NAME_TITLE: String = "Name Your Campaign"
const COUNT_FORMAT: String = "%d / %d"
const TARGET_JOB: String = "Mercs You Want"
const TARGET_PROMO: String = "Contracts You Want"
const JOB_NOTE: String = "Applicant level can't be targeted."
const CREW_TIP_KIND: String = "Odd Job"
const CREW_TIP: String = "Send a merc to spread the word about your guild."
const CREW_PICK_DESC: String = "Sorted by best fit for Word of Mouth."
const COST_WOM: String = "Odd Job pay, due up front"
const COST_INF: String = "%d / day x %d days"
const COST_FIXED: String = "%d / day x %d days, due up front"
const CHIP_TEXT: String = "Billed monthly, starting immediately"
const LAUNCH_TEXT: String = "Launch Campaign"
const MONTH_SUFFIX: String = " / month"

@onready var backdrop: ColorRect = $Backdrop
@onready var frame: PanelContainer = $Center/Frame
@onready var body: VBoxContainer = $Center/Frame/Pad/Body
@onready var title_label: Label = $Center/Frame/Pad/Body/Head/Title
@onready var close_button: Button = $Center/Frame/Pad/Body/Head/Close
@onready var columns: HBoxContainer = $Center/Frame/Pad/Body/Cols
@onready var type_column: VBoxContainer = $Center/Frame/Pad/Body/Cols/TypeCol
@onready var type_caption: Label = $Center/Frame/Pad/Body/Cols/TypeCol/TypeHead/Caption
@onready var boost_label: Label = $Center/Frame/Pad/Body/Cols/TypeCol/TypeHead/Boost
@onready var type_box: VBoxContainer = $Center/Frame/Pad/Body/Cols/TypeCol/Types
@onready var right_pane: PanelContainer = $Center/Frame/Pad/Body/Cols/RightPane
@onready var right_body: VBoxContainer = $Center/Frame/Pad/Body/Cols/RightPane/RightPad/Right
@onready var name_caption: Label = $Center/Frame/Pad/Body/Cols/RightPane/RightPad/Right/Name/Caption
@onready var name_field: Button = $Center/Frame/Pad/Body/Cols/RightPane/RightPad/Right/Name/Field
@onready var name_count: Label = $Center/Frame/Pad/Body/Cols/RightPane/RightPad/Right/Name/Counter
@onready var duration: DurationControl = $Center/Frame/Pad/Body/Cols/RightPane/RightPad/Right/Span
@onready var target_title: Label = $Center/Frame/Pad/Body/Cols/RightPane/RightPad/Right/TargetHead
@onready var crew: OddJobCrew = $Center/Frame/Pad/Body/Cols/RightPane/RightPad/Right/Crew
@onready var job_filters: TraitFilterPanel = $Center/Frame/Pad/Body/Cols/RightPane/RightPad/Right/Job
@onready var guild: GuildTargeting = $Center/Frame/Pad/Body/Cols/RightPane/RightPad/Right/Guild
@onready var reason_label: Label = $Center/Frame/Pad/Body/Footer/Reason
@onready var cost_note: Label = $Center/Frame/Pad/Body/Footer/CostNote
@onready var chip: PanelContainer = $Center/Frame/Pad/Body/Footer/Chip
@onready var chip_label: Label = $Center/Frame/Pad/Body/Footer/Chip/ChipLabel
@onready var cost_label: NotesLabel = $Center/Frame/Pad/Body/Footer/Cost
@onready var name_dialog: TextEntryDialog = $NameDialog

var launch_button: BevelButton = null
var _mode: String = CampaignData.MODE_JOB
var _type_key: StringName = &"flyers"
var _campaign_name: String = ""
var _team: Array[int] = []
var _per: int = 0
var _guild_sel: Dictionary = {}
var _rows: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = BACKDROP
	frame.custom_minimum_size = MODAL_SIZE
	frame.add_theme_stylebox_override(&"panel", _frame_box())
	body.add_theme_constant_override(&"separation", BODY_GAP)
	columns.add_theme_constant_override(&"separation", COL_GAP)
	type_column.custom_minimum_size = Vector2(TYPE_COL_WIDTH, 0.0)
	type_box.add_theme_constant_override(&"separation", TYPE_GAP)
	right_body.add_theme_constant_override(&"separation", RIGHT_GAP)
	right_pane.add_theme_stylebox_override(&"panel", _pane_box())
	_paint(title_label, FONT_BOLD, TITLE_SIZE, ORANGE)
	_paint(type_caption, FONT_SILK, CAPTION_SIZE, ORANGE)
	_paint(boost_label, FONT_SILK, CAPTION_SIZE, GREEN)
	_paint(name_caption, FONT_SILK, CAPTION_SIZE, SKY)
	_paint(name_count, FONT_SILK, CAPTION_SIZE, MUTED)
	_paint(target_title, FONT_BOLD, NOTE_SIZE, ORANGE)
	_paint(reason_label, FONT_BODY, NOTE_SIZE, RED)
	_paint(cost_note, FONT_BODY, NOTE_SIZE, SKY)
	_paint(chip_label, FONT_BODY, CHIP_SIZE, CHIP_RING)
	type_caption.text = TYPE_HEAD
	type_caption.size_flags_horizontal = SIZE_EXPAND_FILL
	name_caption.text = NAME_CAPTION
	boost_label.tooltip_text = BOOST_TIP
	title_label.size_flags_horizontal = SIZE_EXPAND_FILL
	reason_label.size_flags_horizontal = SIZE_EXPAND_FILL
	chip.add_theme_stylebox_override(&"panel", _chip_box())
	chip_label.text = CHIP_TEXT
	cost_label.font_size = COST_SIZE
	job_filters.size_flags_horizontal = SIZE_EXPAND_FILL
	job_filters.size_flags_vertical = SIZE_EXPAND_FILL
	job_filters.footer_note = JOB_NOTE
	guild.size_flags_horizontal = SIZE_EXPAND_FILL
	guild.size_flags_vertical = SIZE_EXPAND_FILL
	crew.size_flags_horizontal = SIZE_EXPAND_FILL
	_style_name_field()
	_style_close()
	_build_launch()
	close_button.pressed.connect(press_close)
	launch_button.pressed.connect(press_launch)
	name_field.pressed.connect(press_name)
	name_dialog.done.connect(_on_name_done)
	duration.quantity_changed.connect(_on_duration_changed.unbind(1))
	duration.unit_changed.connect(_on_duration_changed.unbind(1))
	duration.take_me_there.connect(_on_take_me_there)
	crew.team_changed.connect(_on_team_changed)
	crew.pay_changed.connect(_on_pay_changed)
	crew.take_me_there.connect(_on_take_me_there)
	job_filters.filters_changed.connect(_on_duration_changed.unbind(1))
	job_filters.take_me_there.connect(_on_take_me_there)
	guild.changed.connect(_on_guild_changed)
	guild.take_me_there.connect(_on_take_me_there)
	_build_rows()
	visible = false


#Opens the modal on the defaults of the handoff: Flyers, five days, no crew and no name.
func open_for(wanted: StringName) -> void:
	_mode = CampaignData.MODE_PROMO if String(wanted) == CampaignData.MODE_PROMO \
		else CampaignData.MODE_JOB
	_type_key = StringName(CampaignTypeDefs.TYPES[1]["key"])
	_campaign_name = ""
	_team = []
	_per = PromotionsManager.default_pay()
	_guild_sel = {}
	var ent: Dictionary = SubscriptionManager.entitlements()
	duration.set_ent(ent)
	duration.set_unit(CampaignTypeDefs.UNIT_DAYS)
	duration.set_quantity(DEFAULT_QTY)
	job_filters.set_defs(TraitFilterDefs.merc_defs(false), {}, ent)
	guild.set_sel(_guild_sel)
	guild.setup(_type_key, ent)
	crew.team = _team
	crew.per = _per
	visible = true
	GuiFrameStack.push(self)
	_apply()


func is_open() -> bool:
	return visible


func mode() -> String:
	return _mode


func title_text() -> String:
	return title_label.text if is_node_ready() else ""


func target_title_text() -> String:
	return target_title.text if is_node_ready() else ""


func type_row(key: StringName) -> TypeRow:
	return _rows.get(key, null) as TypeRow


func type_rows() -> Array[TypeRow]:
	var out: Array[TypeRow] = []
	for row: Dictionary in CampaignTypeDefs.TYPES:
		var node: TypeRow = type_row(StringName(row["key"]))
		if node != null:
			out.append(node)
	return out


func type_key() -> StringName:
	return _type_key


#Picking a method drops a target it cannot use and trims the locations it cannot reach.
func pick_type(key: StringName) -> void:
	var node: TypeRow = type_row(key)
	if node != null and not node.is_pickable():
		return
	_type_key = key
	_guild_sel.erase(GuildTargeting.TARGET_KEY)
	if _guild_sel.has(GuildTargeting.LOC_KEY):
		var places: Array[int] = []
		for entry: Variant in _guild_sel[GuildTargeting.LOC_KEY] as Array:
			places.append(int(entry))
		_guild_sel[GuildTargeting.LOC_KEY] = CampaignTypeDefs.fit_locations(key, places)
	guild.set_sel(_guild_sel)
	guild.setup(_type_key, SubscriptionManager.entitlements())
	_apply()


func campaign_name() -> String:
	return _campaign_name


func name_shown() -> String:
	return name_field.text if is_node_ready() else ""


func count_text() -> String:
	return name_count.text if is_node_ready() else ""


#Node.set_name is taken, so the name helper of the plan reads set_campaign_name here.
func set_campaign_name(text: String) -> void:
	_campaign_name = text.substr(0, NAME_MAX)
	_apply()


func press_name() -> void:
	if is_node_ready():
		name_dialog.open(NAME_TITLE, _campaign_name, NAME_MAX)


func naming() -> bool:
	return is_node_ready() and name_dialog.visible


func set_quantity(qty: int) -> void:
	duration.set_quantity(qty)
	_apply()


func pick_unit(key: StringName) -> void:
	duration.press_unit(key)


func set_filter_value(key: StringName, value: Variant) -> void:
	if _mode == CampaignData.MODE_JOB:
		job_filters.press_value(String(key), value)
		return
	guild.press_value(key, value)


func pick_target(keys: Array) -> void:
	guild.pick_target(keys)


func toggle_location(index: int) -> void:
	guild.toggle_location(index)


func set_crew(team: Array[int], pay_per: int) -> void:
	_team = team.duplicate()
	_per = maxi(0, pay_per)
	if is_node_ready():
		crew.team = _team
		crew.per = _per
	_apply()


func crew_module() -> OddJobCrew:
	return crew


func duration_control() -> DurationControl:
	return duration


func job_panel() -> TraitFilterPanel:
	return job_filters


func guild_panel() -> GuildTargeting:
	return guild


func crew_shown() -> bool:
	return is_node_ready() and crew.visible


func job_shown() -> bool:
	return is_node_ready() and job_filters.visible


func guild_shown() -> bool:
	return is_node_ready() and guild.visible


#The campaign the footer reads: a fresh, unlaunched CampaignData on every call.
func draft() -> CampaignData:
	var out := CampaignData.new()
	out.name = _campaign_name
	out.type_key = _type_key
	out.mode = _mode
	out.unit_key = duration.unit_key()
	out.infinite = duration.is_infinite()
	out.days = 0 if out.infinite else duration.days()
	if CampaignTypeDefs.is_crew_paid(_type_key):
		out.crew = _team.duplicate()
		out.pay_per = _per
	if _mode == CampaignData.MODE_JOB:
		out.filters = job_filters.filters()
		return out
	out.filters = guild.sel()
	var band: Array[float] = guild.difficulty_pair()
	out.difficulty_lo = band[0]
	out.difficulty_hi = band[1]
	out.contract_types = guild.contract_types()
	out.locations = guild.locations()
	_apply_target(out)
	return out


func cost() -> int:
	return PromotionsManager.launch_cost(draft())


func cost_text() -> String:
	return cost_label.value_text() if is_node_ready() else ""


func cost_note_text() -> String:
	return cost_note.text if is_node_ready() else ""


func chip_shown() -> bool:
	return is_node_ready() and chip.visible


func reason_text() -> String:
	return String(PromotionsManager.can_launch(draft()).get("reason", ""))


func launch_enabled() -> bool:
	return reason_text() == ""


func press_launch() -> void:
	if not launch_enabled():
		return
	var out: CampaignData = draft()
	if not PromotionsManager.launch(out):
		return
	_close()
	launched.emit(out)


func press_close() -> void:
	_close()
	closed.emit()


func _close() -> void:
	visible = false
	GuiFrameStack.remove(self)


#Only Direct Sale and Sponsorship ask who to speak to; the rest go out to everyone.
func _apply_target(out: CampaignData) -> void:
	var row: Dictionary = CampaignTypeDefs.find(_type_key)
	if String(row.get("picks", "")) == "":
		out.advertise_to = CampaignData.TO_EVERYONE
		return
	out.sponsor_target = guild.target_text()
	out.advertise_targets = guild.target_indices()
	out.sponsor_index = guild.target_index()
	var event: bool = out.sponsor_index >= TraitFilterDefs.COMPANY_COUNT
	out.advertise_to = CampaignData.TO_EVENT if event else CampaignData.TO_COMPANY


func _build_rows() -> void:
	var ent: Dictionary = SubscriptionManager.entitlements()
	for i: int in range(CampaignTypeDefs.TYPES.size()):
		var row: Dictionary = CampaignTypeDefs.TYPES[i]
		var node: TypeRow = TYPE_ROW_SCENE.instantiate() as TypeRow
		type_box.add_child(node)
		node.setup(row, ent, _mode, i)
		node.pressed_type.connect(pick_type)
		node.take_me_there.connect(_on_take_me_there)
		_rows[StringName(row["key"])] = node


func _apply() -> void:
	if not is_node_ready():
		return
	var ent: Dictionary = SubscriptionManager.entitlements()
	var job: bool = _mode == CampaignData.MODE_JOB
	var wom: bool = CampaignTypeDefs.is_crew_paid(_type_key)
	title_label.text = TITLE_JOB if job else TITLE_PROMO
	target_title.text = TARGET_JOB if job else TARGET_PROMO
	var boost: int = roundi(CampaignTypeDefs.number_of(ent, CampaignTypeDefs.BOOST_KEY))
	boost_label.text = BOOST_HEAD % boost
	boost_label.visible = boost > 0
	for i: int in range(CampaignTypeDefs.TYPES.size()):
		var row: Dictionary = CampaignTypeDefs.TYPES[i]
		var node: TypeRow = type_row(StringName(row["key"]))
		node.setup(row, ent, _mode, i)
		node.set_active(StringName(row["key"]) == _type_key)
	name_field.text = _campaign_name if _campaign_name != "" \
		else PromotionsManager.next_campaign_name()
	name_field.add_theme_color_override(&"font_color", CREAM if _campaign_name != "" else MUTED)
	name_count.text = COUNT_FORMAT % [_campaign_name.length(), NAME_MAX]
	duration.set_ent(ent)
	crew.visible = wom
	crew.max_mercs = TraitFilterDefs.tier_of(ent, "oddJobs")
	crew.locked = crew.max_mercs <= 0
	crew.candidates = CrewCandidates.from_roster(PromotionsManager.merc_fit)
	crew.default_pay = PromotionsManager.default_pay()
	crew.money = GameState.bank_notes
	crew.tip_kind = CREW_TIP_KIND
	crew.tip_text = CREW_TIP
	crew.pick_desc = CREW_PICK_DESC
	job_filters.visible = job
	guild.visible = not job
	_apply_footer(wom)


func _apply_footer(wom: bool) -> void:
	var out: CampaignData = draft()
	var per_day: int = int(CampaignTypeDefs.find(_type_key).get("per_day", 0))
	var price: int = PromotionsManager.launch_cost(out)
	var reason: String = String(PromotionsManager.can_launch(out).get("reason", ""))
	reason_label.text = reason
	reason_label.visible = reason != ""
	if wom:
		cost_note.text = COST_WOM
	elif out.infinite:
		cost_note.text = COST_INF % [per_day, CampaignTypeDefs.BILL_DAYS]
	else:
		cost_note.text = COST_FIXED % [per_day, duration.days()]
	chip.visible = out.infinite and not wom
	cost_label.amount = price
	cost_label.suffix = MONTH_SUFFIX if out.infinite and not wom else ""
	cost_label.value_color = RED if price > GameState.bank_notes else CREAM
	launch_button.disabled = reason != ""


func _style_name_field() -> void:
	name_field.custom_minimum_size = Vector2(0.0, FIELD_HEIGHT)
	name_field.focus_mode = Control.FOCUS_NONE
	name_field.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_field.add_theme_font_override(&"font", FONT_BODY)
	name_field.add_theme_font_size_override(&"font_size", NAME_SIZE)
	var box := StyleBoxFlat.new()
	box.bg_color = FIELD_BG
	box.set_border_width_all(FIELD_RING_PX)
	box.border_color = FIELD_RING
	box.content_margin_left = FIELD_PAD
	box.content_margin_right = FIELD_PAD
	var hover: StyleBoxFlat = box.duplicate() as StyleBoxFlat
	hover.border_color = ORANGE
	name_field.add_theme_stylebox_override(&"normal", box)
	name_field.add_theme_stylebox_override(&"hover", hover)
	name_field.add_theme_stylebox_override(&"pressed", hover)


func _style_close() -> void:
	close_button.focus_mode = Control.FOCUS_NONE
	CloseX.style(close_button, CloseX.SCALE_WINDOW)


#Item 11: the one core BevelButton scene, added where the scene used to hold a plain Button.
func _build_launch() -> void:
	launch_button = BevelButton.make(LAUNCH_TEXT, &"go", LAUNCH_BUTTON_SIZE)
	launch_button.focus_mode = Control.FOCUS_NONE
	launch_button.add_theme_font_override(&"font", FONT_BOLD)
	launch_button.add_theme_font_size_override(&"font_size", LAUNCH_SIZE)
	$Center/Frame/Pad/Body/Footer.add_child(launch_button)


func _frame_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = FRAME_BG
	box.set_border_width_all(RING_PX)
	box.border_color = FRAME_RING
	return box


func _pane_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PANE_BG
	return box


func _chip_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = CHIP_BG
	box.set_border_width_all(CHIP_RING_PX)
	box.border_color = CHIP_RING
	box.content_margin_left = CHIP_PAD_X
	box.content_margin_right = CHIP_PAD_X
	box.content_margin_top = CHIP_PAD_Y
	box.content_margin_bottom = CHIP_PAD_Y
	return box


func _paint(node: Label, font: FontVariation, font_size: int, tint: Color) -> void:
	node.add_theme_font_override(&"font", font)
	node.add_theme_font_size_override(&"font_size", font_size)
	node.add_theme_color_override(&"font_color", tint)


func _on_name_done(text: String) -> void:
	set_campaign_name(text)


func _on_duration_changed() -> void:
	_apply()


func _on_guild_changed(sel: Dictionary) -> void:
	_guild_sel = sel.duplicate(true)
	_apply()


func _on_team_changed(team: Array[int]) -> void:
	_team = team.duplicate()
	_apply()


func _on_pay_changed(per: int) -> void:
	_per = per
	_apply()


func _on_take_me_there(target: Dictionary) -> void:
	take_me_there.emit(target)
