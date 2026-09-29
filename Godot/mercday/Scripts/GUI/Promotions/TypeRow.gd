class_name TypeRow extends Button

#One line of the builder's Campaign Type column: the pixel icon, the name and price line, the
#quality stars and the Effect value. A row the guild has not bought dims and wears a FeatureLock;
#a guild-only type dims further on the Job Ads side. Earlier rows keep a higher z_index so a lock
#tooltip opening downward stays over the rows under it.

signal pressed_type(type_key: StringName)
signal take_me_there(target: Dictionary)

const FONT_SILK: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const FONT_BOLD: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const FONT_BODY: FontVariation = preload("res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres")
const ICON_BG: Color = Color("#0e1628")
const ROW_ON_BG: Color = Color("#15223d")
const ROW_OFF_BG: Color = Color("#0e1628")
const RING_ON: Color = Color("#f28c28")
const RING_OFF: Color = Color("#1f3560")
const CREAM: Color = Color("#f3ead7")
const SKY: Color = Color("#9cc6ef")
const GREEN: Color = Color("#6cc36a")
const ICON_PX: float = 44.0
const ICON_SCALE: int = 2
const RING_ON_PX: int = 3
const RING_OFF_PX: int = 2
const NAME_SIZE: int = 11
const SUB_SIZE: int = 12
const EFF_LABEL_SIZE: int = 8
const EFF_VALUE_SIZE: int = 13
const PAD_X: float = 10.0
const PAD_Y: float = 8.0
const GAP: int = 10
const TOP_Z: int = 20
const LOCKED_ALPHA: float = 0.6
const BLOCKED_ALPHA: float = 0.4
const LOCK_PX: float = 22.0
const LOCK_FONT_SIZE: int = 9
const EFFECT_LABEL: String = "Effect"
const LOCK_VERB: String = "use"
const BLOCKED_TIP: String = "Guild Promo only"
const QUALITY_TIP: String = "Quality of mercs or contracts it attracts"
const VARIES_TIP: String = "Effectiveness varies with the mercs you send"
const EFFECT_TIP: String = "Effectiveness: base %d%%"
const BOOST_TIP: String = " x Marketing Agency +%d%%"

@onready var body: HBoxContainer = $Body
@onready var icon_box: Panel = $Body/IconBox
@onready var glyph: TextureRect = $Body/IconBox/Icon
@onready var texts: VBoxContainer = $Body/Texts
@onready var name_label: Label = $Body/Texts/TypeName
@onready var sub_label: Label = $Body/Texts/Sub
@onready var stars: FitStars = $Body/Texts/Stars
@onready var effect_box: VBoxContainer = $Body/Effect
@onready var effect_caption: Label = $Body/Effect/Caption
@onready var effect_value: Label = $Body/Effect/Value
@onready var lock: FeatureLock = $Body/Lock

var _row: Dictionary = {}
var _ent: Dictionary = {}
var _mode: String = CampaignData.MODE_JOB
var _active: bool = false


func _ready() -> void:
	body.add_theme_constant_override(&"separation", GAP)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	icon_box.add_theme_stylebox_override(&"panel", _flat(ICON_BG))
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texts.size_flags_horizontal = SIZE_EXPAND_FILL
	texts.add_theme_constant_override(&"separation", 3)
	effect_box.add_theme_constant_override(&"separation", 3)
	effect_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_paint(name_label, FONT_BOLD, NAME_SIZE, CREAM)
	_paint(sub_label, FONT_BODY, SUB_SIZE, SKY)
	_paint(effect_caption, FONT_SILK, EFF_LABEL_SIZE, SKY)
	_paint(effect_value, FONT_BOLD, EFF_VALUE_SIZE, GREEN)
	effect_caption.text = EFFECT_LABEL
	effect_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	effect_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stars.tooltip_text = QUALITY_TIP
	lock.verb = LOCK_VERB
	lock.font_size = LOCK_FONT_SIZE
	lock.min_width = LOCK_PX
	lock.height = LOCK_PX
	lock.take_me_there.connect(_on_take_me_there)
	pressed.connect(press_row)
	_apply()


#row is a CampaignTypeDefs.TYPES entry, index its place in that table.
func setup(row: Dictionary, ent: Dictionary, mode: String, index: int) -> void:
	_row = row.duplicate()
	_ent = ent.duplicate()
	_mode = mode
	z_index = TOP_Z - index
	if is_node_ready():
		_apply()


func set_active(on: bool) -> void:
	_active = on
	if is_node_ready():
		_apply_ring()


func key() -> StringName:
	return StringName(_row.get("key", &""))


func type_name() -> String:
	return String(_row.get("name", ""))


func sub_text() -> String:
	return String(_row.get("desc", ""))


func quality() -> float:
	return float(_row.get("stars", 1))


func is_locked() -> bool:
	return not _row.is_empty() and not CampaignTypeDefs.unlocked(key(), _ent)


func is_blocked() -> bool:
	return bool(_row.get("guild_only", false)) and _mode == CampaignData.MODE_JOB


func is_pickable() -> bool:
	return not _row.is_empty() and not is_locked() and not is_blocked()


func effect_line() -> String:
	if _row.is_empty():
		return ""
	return CampaignTypeDefs.effect_text(key(), _ent)


func effect_color() -> Color:
	return SKY if effect_line() == "Varies" else GREEN


func dim_alpha() -> float:
	if is_blocked():
		return BLOCKED_ALPHA
	return LOCKED_ALPHA if is_locked() else 1.0


func lock_button() -> FeatureLock:
	return lock


func press_row() -> void:
	if not is_pickable():
		return
	pressed_type.emit(key())


func _apply() -> void:
	if _row.is_empty():
		return
	glyph.texture = PromoGlyphs.type_icon(key(), ICON_SCALE, is_locked())
	glyph.modulate = PromoGlyphs.dim_modulate(is_locked())
	name_label.text = type_name()
	sub_label.text = sub_text()
	stars.value = quality()
	effect_value.text = effect_line()
	effect_value.add_theme_color_override(&"font_color", effect_color())
	effect_box.tooltip_text = _effect_tip()
	tooltip_text = BLOCKED_TIP if is_blocked() else ""
	var alpha: float = dim_alpha()
	icon_box.modulate.a = alpha
	texts.modulate.a = alpha
	effect_box.modulate.a = alpha
	lock.visible = is_locked()
	if lock.visible:
		lock.feature = type_name()
		lock.upgrade = _upgrade_name()
		lock.upgrade_id = String(_row.get("upgrade_id", ""))
		lock.entitlement = String(_row.get("gate", ""))
		lock.tier = int(_row.get("upgrade_tier", 1))
		lock.tiers = int(_row.get("upgrade_tiers", 1))
	disabled = not is_pickable()
	_apply_ring()


func _apply_ring() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = ROW_ON_BG if _active else ROW_OFF_BG
	box.set_border_width_all(RING_ON_PX if _active else RING_OFF_PX)
	box.border_color = RING_ON if _active else RING_OFF
	box.content_margin_left = PAD_X
	box.content_margin_right = PAD_X
	box.content_margin_top = PAD_Y
	box.content_margin_bottom = PAD_Y
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		add_theme_stylebox_override(state, box)


func _effect_tip() -> String:
	if _row.is_empty():
		return ""
	var base: float = float(_row.get("effect", CampaignTypeDefs.VARIES))
	if base < 0.0:
		return VARIES_TIP
	var out: String = EFFECT_TIP % roundi(base)
	var boost: int = roundi(CampaignTypeDefs.number_of(_ent, CampaignTypeDefs.BOOST_KEY))
	if boost > 0:
		out += BOOST_TIP % boost
	return out


func _upgrade_name() -> String:
	var found: String = UpgradeDefs.name_of(String(_row.get("upgrade_id", "")))
	return found if found != "" else type_name()


func _paint(node: Label, font: FontVariation, font_size: int, tint: Color) -> void:
	node.add_theme_font_override(&"font", font)
	node.add_theme_font_size_override(&"font_size", font_size)
	node.add_theme_color_override(&"font_color", tint)


func _flat(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	return box


func _on_take_me_there(target: Dictionary) -> void:
	take_me_there.emit(target)
