class_name ApplicantCard extends PanelContainer

#One applicant in the Hiring grid: portrait, tradition, level badge, the fact rows the plan owns and
#the three buttons. The card reads an applicant and never writes one: every press leaves as a signal
#so the page marks the applicant seen and opens the dialogs. An identity row only shows while its
#filter def exists and is unlocked, so a plan without hiringDiscrim hides ancestry, bloodline and age.

signal view_pressed(id: int)
signal reject_pressed(id: int)
signal offer_pressed(id: int)

const BADGE_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/LevelBadge.tscn")
const SIGIL_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/TraditionSigil.tscn")
const PORTRAIT_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/MercPortrait.tscn")

const CARD_PAD: int = 12
const CARD_GAP: int = 8
const CARD_RING_PX: int = 2
const ROW_GAP: int = 3
const ROW_PAD_X: float = 6.0
const ROW_PAD_Y: float = 4.0
const FIT_ROW_PAD_Y: float = 0.0
const FIT_STAR_CELL: int = 1
const TOP_GAP: int = 10
const PORTRAIT_SIDE: float = 52.0
const PORTRAIT_RING_PX: int = 2
const HATCH_SIDE: int = 48
const SIGIL_SIDE: float = 20.0
const BADGE_SIDE: float = 36.0
const BADGE_KICKER_SIZE: int = 7
const BADGE_VALUE_SIZE: int = 14
const BUTTON_H: float = 32.0
const VIEW_W: float = 44.0
const BUTTON_GAP: int = 8
const DOT_INSET: float = 13.0
const NAME_LINES: int = 2

const ROW_LABELS: Dictionary = {
	"salary": "Salary Request",
	"uniq": "Uniqueness",
	"fit": "Fit",
	"via": "Applied Via",
	"ancestry": "Ancestry",
	"bloodline": "Bloodline",
	"age": "Age",
	"heritage": "Heritage",
}
const IDENTITY_KEYS: Array[String] = ["ancestry", "bloodline", "age", "heritage"]
const UNIQ_TIP: String = "Traits none of your mercs have, and how rare they are"
const FIT_TIP: String = "Average fit with your available contracts that lack a good match"
const ENDED_TEXT: String = "Ended campaign"
const NONE_TEXT: String = "None"
const PENDING_TEXT: String = "Counter-offer sent..."
const REFUSED_TEXT: String = "Refused your counter-offer"
const ACCEPTED_TEXT: String = "Accepted your counter-offer"
const BLOCK_PENDING: String = "Waiting for their answer."
const BLOCK_SLOTS: String = "No free merc slots."
const VIEW_TIP: String = "View"

var _applicant: ApplicantData = null
var _defs: Array[Dictionary] = []
var _ents: Dictionary = {}
var _free: int = 0
var _keys: Array[String] = []
var _texts: Dictionary = {}
var _tints: Dictionary = {}

var _portrait_box: PanelContainer = null
var _portrait: MercPortrait = null
var _name_label: Label = null
var _sigil_box: PanelContainer = null
var _sigil: TraditionSigil = null
var _trad_label: Label = null
var _badge: LevelBadge = null
var _row_box: VBoxContainer = null
var _status_label: Label = null
var _reject: Button = null
var _view: Button = null
var _offer: Button = null
var _dot: NotificationDot = null
var _fit_stars: Stars = null


func _ready() -> void:
	add_theme_stylebox_override(&"panel", HiringStyle.box(GuiColors.ROW_FILL, CARD_RING_PX,
		GuiColors.BLUE))
	var pad := MarginContainer.new()
	pad.add_theme_constant_override(&"margin_left", CARD_PAD)
	pad.add_theme_constant_override(&"margin_right", CARD_PAD)
	pad.add_theme_constant_override(&"margin_top", CARD_PAD)
	pad.add_theme_constant_override(&"margin_bottom", CARD_PAD)
	add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", CARD_GAP)
	pad.add_child(col)
	col.add_child(_build_top())
	#An applicant has no XP to show, so the badge takes no hover and opens no tip.
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row_box = VBoxContainer.new()
	_row_box.add_theme_constant_override(&"separation", ROW_GAP)
	col.add_child(_row_box)
	_status_label = HiringStyle.label("", GuiStyle.BODY, 13, GuiColors.AMBER)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.hide()
	col.add_child(_status_label)
	col.add_child(_build_buttons())
	_build_dot()
	_rebuild_rows()
	_paint()


func _build_top() -> Control:
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", TOP_GAP)
	_portrait_box = HiringStyle.panel(GuiColors.INK, PORTRAIT_RING_PX, GuiColors.BLUE, 2.0, 2.0)
	_portrait_box.custom_minimum_size = Vector2(PORTRAIT_SIDE, PORTRAIT_SIDE)
	_portrait_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_portrait = PORTRAIT_SCENE.instantiate() as MercPortrait
	if _portrait != null:
		_portrait.pixel_size = HATCH_SIDE
		_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_portrait_box.add_child(_portrait)
	top.add_child(_portrait_box)
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override(&"separation", 4)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label = HiringStyle.label("", GuiStyle.SILK_BOLD, 11, GuiColors.CREAM)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.max_lines_visible = NAME_LINES
	_name_label.custom_minimum_size.y = _name_block_height()
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(_name_label)
	var trad_row := HBoxContainer.new()
	trad_row.add_theme_constant_override(&"separation", 4)
	_sigil_box = HiringStyle.panel(GuiColors.INK, 1, GuiColors.BLUE, 1.0, 1.0)
	_sigil_box.custom_minimum_size = Vector2(SIGIL_SIDE, SIGIL_SIDE)
	_sigil_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sigil = SIGIL_SCENE.instantiate() as TraditionSigil
	if _sigil != null:
		_sigil.pixel_scale = 1
		_sigil_box.add_child(_sigil)
	trad_row.add_child(_sigil_box)
	_trad_label = HiringStyle.label("", GuiStyle.BODY, 13, GuiColors.CREAM)
	_trad_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trad_row.add_child(_trad_label)
	mid.add_child(trad_row)
	top.add_child(mid)
	top.add_child(_build_badge())
	return top


#Every card reserves the two-line name block, so a short name never shrinks the card.
func _name_block_height() -> float:
	var font: Font = _name_label.get_theme_font(&"font")
	var font_size: int = _name_label.get_theme_font_size(&"font_size")
	var spacing: int = _name_label.get_theme_constant(&"line_spacing")
	return font.get_height(font_size) * NAME_LINES + spacing * (NAME_LINES - 1)


#A TILE plate reads its row gap from the scene when it becomes ready, so the gap is closed first.
func _build_badge() -> Control:
	_badge = BADGE_SCENE.instantiate() as LevelBadge
	(_badge.get_node(^"Row") as BoxContainer).add_theme_constant_override(&"separation", 0)
	_badge.size_mode = LevelBadge.SizeMode.TILE
	_badge.plate_size = Vector2(BADGE_SIDE, BADGE_SIDE)
	_badge.kicker_size = BADGE_KICKER_SIZE
	_badge.value_size = BADGE_VALUE_SIZE
	_badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return _badge


func _build_buttons() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", BUTTON_GAP)
	_reject = HiringStyle.button("Reject", GuiStyle.SILK, 10, GuiColors.INK, GuiColors.RAMP_RED,
		HiringStyle.RED_HI, HiringStyle.RED_LO)
	_reject.custom_minimum_size = Vector2(0.0, BUTTON_H)
	_reject.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reject.pressed.connect(press_reject)
	row.add_child(_reject)
	_view = HiringStyle.icon_button(GuiStyle.SILK, 10, GuiColors.CREAM, GuiColors.BLUE,
		GuiColors.BLUE_HI, GuiColors.BLUE_LO)
	_view.custom_minimum_size = Vector2(VIEW_W, BUTTON_H)
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.icon = Icons.tex("eye", true)
	_view.tooltip_text = VIEW_TIP
	_view.pressed.connect(press_view)
	HiringStyle.paint(_view, GuiColors.CREAM, GuiColors.BLUE, GuiColors.BLUE_HI, GuiColors.BLUE_LO,
		0, GuiColors.BLUE_HI)
	row.add_child(_view)
	_offer = HiringStyle.button("Offer", GuiStyle.SILK_BOLD, 10, GuiColors.INK, GuiColors.GREEN,
		HiringStyle.GREEN_HI, HiringStyle.GREEN_LO)
	_offer.custom_minimum_size = Vector2(0.0, BUTTON_H)
	_offer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offer.pressed.connect(press_offer)
	row.add_child(_offer)
	return row


#The unseen dot straddles the top right corner, DOT_INSET pixels out past each edge.
func _build_dot() -> void:
	_dot = NotificationDot.attach(self, Vector2(-DOT_INSET, -DOT_INSET))


func set_applicant(a: ApplicantData, defs: Array[Dictionary], ents: Dictionary,
		free_slots: int) -> void:
	_applicant = a
	_defs = defs
	_ents = ents
	_free = maxi(0, free_slots)
	_read_rows()
	if is_node_ready():
		_rebuild_rows()
		_paint()


func _read_rows() -> void:
	_keys.clear()
	_texts.clear()
	_tints.clear()
	var a: ApplicantData = _applicant
	if a == null:
		return
	_add_row("salary", "%s / mo" % TransactionData.grouped(a.ask), GuiColors.AMBER)
	if a.uniq <= 0.0:
		_add_row("uniq", NONE_TEXT, GuiColors.SKY)
	else:
		_add_row("uniq", "%d - %s" % [roundi(a.uniq), a.rarity], GuiColors.GREEN)
	_add_row("fit", "%.1f" % a.fit, Stars.color_of(a.fit, Stars.MATCH, true))
	var via: String = PromotionsManager.campaign_name(a.campaign_id)
	_add_row("via", ENDED_TEXT if via == "" else via, GuiColors.SKY)
	for key: String in IDENTITY_KEYS:
		if _def_locked(key):
			continue
		_add_row(key, _identity_text(key), GuiColors.CREAM)


func _add_row(key: String, body: String, tint: Color) -> void:
	_keys.append(key)
	_texts[key] = body
	_tints[key] = tint


func _def_locked(key: String) -> bool:
	var def: Dictionary = TraitFilterDefs.find(_defs, StringName(key))
	if def.is_empty():
		return true
	return TraitFilterDefs.locked(def, _ents)


func _identity_text(key: String) -> String:
	var a: ApplicantData = _applicant
	if a == null:
		return ""
	match key:
		"ancestry":
			return a.ancestry
		"bloodline":
			return a.bloodline
		"age":
			return str(a.age)
		"heritage":
			return a.heritage
	return ""


func _rebuild_rows() -> void:
	GuiNodes.clear(_row_box)
	for key: String in _keys:
		_row_box.add_child(_build_row(key))


func _build_row(key: String) -> Control:
	#The fit row draws stars at cell 2 (98 x 18 px); FIT_ROW_PAD_Y takes the room the taller
	#stars need from its own vertical gap, so the card keeps the outer size every other row set.
	var pad_y: float = FIT_ROW_PAD_Y if key == "fit" else ROW_PAD_Y
	var host: PanelContainer = HiringStyle.panel(GuiColors.ROW_HOVER, 0, GuiColors.CLEAR, ROW_PAD_X,
		pad_y)
	if key == "uniq":
		host.tooltip_text = UNIQ_TIP
	elif key == "fit":
		host.tooltip_text = FIT_TIP
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	host.add_child(row)
	var tag: Label = HiringStyle.label(String(ROW_LABELS.get(key, key)), GuiStyle.SILK, 7,
		GuiColors.SKY)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tag)
	if key == "fit":
		_fit_stars = Stars.fit_stars(FIT_STAR_CELL)
		_fit_stars.value = 0.5 if _applicant == null else _applicant.fit
		_fit_stars.size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
		_fit_stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(_fit_stars)
		return host
	var value: Label = HiringStyle.label(row_text(key), GuiStyle.BODY, 12, row_color(key))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.clip_text = true
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value)
	return host


func _paint() -> void:
	var a: ApplicantData = _applicant
	HiringStyle.set_ring(self, ring_color())
	_name_label.text = "" if a == null else a.name
	var trad: String = "" if a == null else a.tradition
	var trad_tint: Color = GuiTypes.tradition_color(trad)
	_trad_label.text = trad
	_trad_label.add_theme_color_override(&"font_color", trad_tint)
	HiringStyle.set_ring(_sigil_box, trad_tint)
	HiringStyle.set_ring(_portrait_box, trad_tint)
	if _sigil != null:
		_sigil.tradition = trad
		_sigil.tint = trad_tint
	_badge.level = 1 if a == null else maxi(0, a.level)
	var status: String = status_text()
	_status_label.text = status
	_status_label.add_theme_color_override(&"font_color", status_color())
	_status_label.visible = status != ""
	if _dot != null:
		_dot.on = dot_on()
	if _portrait != null:
		var face: MercView = null
		if a != null:
			face = MercView.from_applicant(a)
		_portrait.set_merc(face)
	HiringStyle.dim(_reject, is_pending(), BLOCK_PENDING if is_pending() else "")
	HiringStyle.dim(_offer, offer_block() != "", offer_block())


func applicant_id() -> int:
	return 0 if _applicant == null else _applicant.id


func is_pending() -> bool:
	return _applicant != null and _applicant.status == ApplicantData.STATUS_COUNTERED


func row_keys() -> Array[String]:
	return _keys.duplicate()


func row_text(key: String) -> String:
	return String(_texts.get(key, ""))


func row_color(key: String) -> Color:
	return _tints.get(key, GuiColors.CREAM) as Color


func level_text() -> String:
	if _applicant == null:
		return "01"
	return "%02d" % maxi(0, _applicant.level)


func name_text() -> String:
	return _name_label.text


func tradition_text() -> String:
	return _trad_label.text


func status_text() -> String:
	var a: ApplicantData = _applicant
	if a == null:
		return ""
	if is_pending():
		return PENDING_TEXT
	if a.refused_counter:
		return REFUSED_TEXT
	if a.accepted_counter and a.is_open():
		return ACCEPTED_TEXT
	return ""


func status_color() -> Color:
	var status: String = status_text()
	if status == PENDING_TEXT:
		return GuiColors.AMBER
	if status == REFUSED_TEXT:
		return GuiColors.RAMP_RED
	if status == ACCEPTED_TEXT:
		return GuiColors.GREEN
	return GuiColors.SKY


func ring_color() -> Color:
	var a: ApplicantData = _applicant
	if a == null:
		return GuiColors.BLUE
	if is_pending():
		return GuiColors.AMBER
	if a.refused_counter:
		return GuiColors.RAMP_RED
	if a.accepted_counter and a.is_open():
		return GuiColors.GREEN
	return GuiColors.BLUE


func dot_on() -> bool:
	return _applicant != null and _applicant.unseen


func offer_block() -> String:
	if is_pending():
		return BLOCK_PENDING
	if _free <= 0:
		return BLOCK_SLOTS
	return ""


func dot() -> NotificationDot:
	return _dot


func fit_stars() -> Stars:
	return _fit_stars


func portrait() -> MercPortrait:
	return _portrait


func view_button() -> Button:
	return _view


func reject_button() -> Button:
	return _reject


func offer_button() -> Button:
	return _offer


func press_view() -> void:
	view_pressed.emit(applicant_id())


func press_reject() -> void:
	if is_pending():
		UiSfx.reject_press(_reject)
		return
	reject_pressed.emit(applicant_id())


func press_offer() -> void:
	offer_pressed.emit(applicant_id())
