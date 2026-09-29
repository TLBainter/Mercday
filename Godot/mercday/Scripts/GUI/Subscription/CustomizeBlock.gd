class_name CustomizeBlock extends Control

#One module of the Customize tree: the upgrade icon in its tier colour, the tier chunks in an inset
#tube, and the name and monthly fee under the square. An unavailable module dims to 0.45 and
#refuses the click; a fully owned one glows on the shared pulse and its chunks shine left to right.
#The Base module carries the My Mercday logo and tracks the progress of the whole tree.

signal pressed_block(id: String)

const BASE_ID: String = "base"
const BASE_NAME: String = "Base Plan"
const BASE_DESC: String = "The root of your Enterprise customizations. Every branch starts here."
const BASE_KIND: String = "Enterprise"
const BG: Color = Color("#2b4f8a")
const BG_MAX: Color = Color("#1f3560")
const HI: Color = Color("#3b6fb6")
const HI_MAX: Color = Color("#2b4f8a")
const LO: Color = Color("#111c33")
const BASE_BG: Color = Color("#0a0f1c")
const BASE_HI: Color = Color("#1a2b4d")
const BASE_LO: Color = Color("#000000")
const RING: Color = Color("#f28c28")
const RING_MAX: Color = Color("#f2d33d")
const RING_OFF: Color = Color("#1f3560")
const RING_BASE_OFF: Color = Color("#3b6fb6")
const NAME_COLOR: Color = Color("#f3ead7")
const FEE_COLOR: Color = Color("#f3ead7")
const FEE_OFF: Color = Color("#5e7699")
const MUTED_ICON: Color = Color("#5e7699")
const TUBE_BG: Color = Color("#05080f")
const TUBE_HI: Color = Color("#3b6fb6")
const TUBE_LO: Color = Color("#1f3560")
const CHUNK_BG: Color = Color("#15223d")
const CHUNK_HI: Color = Color("#1f3560")
const CHUNK_LO: Color = Color("#0e1628")
const LL_COLOR: Color = Color("#e8583f")
const DIM_ALPHA: float = 0.45
const BEVEL: float = 2.0
const RING_WIDTH: float = 2.0
const ICON_SCALE: int = 4
const ICON_TOP: float = 12.0
const PIP_H: float = 8.0
const PIP_W: float = 7.0
const PIP_W_TIGHT: float = 6.0
const PIP_GAP: float = 2.0
const PIP_PAD_X: float = 3.0
const PIP_PAD_Y: float = 2.0
const PIP_LIFT: float = 8.0
const TUBE_TIGHT_MAX: int = 8
const NAME_DROP: float = 6.0
const FEE_DROP: float = 24.0
const LABEL_WIDTH: float = 140.0
const SUFFIX: String = "/month"
const NAME_FONT: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const FEE_FONT: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const NAME_SIZE: int = 10
const FEE_SIZE: int = 12

@export var upgrade_id: String = ""

var _tier: int = 0
var _max: int = 1
var _fee: int = 0
var _progress: float = 0.0
var _usable: bool = true
var _enterprise: bool = true
var _gated: bool = false
var _glow: float = 0.0
var _sweep: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_PASS
	_apply_size()
	PulseClock.pulse.connect(_on_pulse)


func setup(id: String) -> void:
	upgrade_id = id
	_max = maxi(1, UpgradeDefs.tier_count(id)) if id != BASE_ID else 1
	_apply_size()
	queue_redraw()


func is_base() -> bool:
	return upgrade_id == BASE_ID


#Reads one tree state: the owned tier, the fee it bills, and whether the module can be clicked.
func refresh(tiers: Dictionary, enterprise: bool) -> void:
	_enterprise = enterprise
	if is_base():
		_tier = 0
		_max = 1
		_progress = TreeLayout.base_progress(tiers)
		_fee = SubscriptionManager.service_fee(SubscriptionManager.Plan.ENTERPRISE)
		_gated = false
		_usable = false
		queue_redraw()
		return
	_max = maxi(1, UpgradeDefs.tier_count(upgrade_id))
	_tier = clampi(int(tiers.get(upgrade_id, 0)), 0, _max)
	_fee = UpgradeDefs.monthly_of(upgrade_id, _tier)
	_progress = float(_tier) / float(_max)
	_gated = not UpgradeDefs.requirement_met(upgrade_id, tiers)
	_usable = enterprise and not _gated
	queue_redraw()


func tier() -> int:
	return _tier


func max_tier() -> int:
	return _max


func is_maxed() -> bool:
	return not is_base() and _tier >= _max


func is_usable() -> bool:
	return _usable


func is_gated() -> bool:
	return _gated


func name_text() -> String:
	return BASE_NAME if is_base() else UpgradeDefs.name_of(upgrade_id)


func desc_text() -> String:
	if is_base():
		return BASE_DESC
	return String(UpgradeDefs.of(upgrade_id).get("desc", ""))


func kind_text() -> String:
	if is_base():
		return BASE_KIND
	return TreeLayout.cat_label(UpgradeDefs.category_of(upgrade_id))


func monthly_fee() -> int:
	return _fee


func fee_text() -> String:
	return str(_fee)


func fee_color() -> Color:
	if is_base():
		return FEE_COLOR
	return FEE_COLOR if _tier > 0 else FEE_OFF


func bg_color() -> Color:
	if is_base():
		return BASE_BG
	return BG_MAX if is_maxed() else BG


func hi_color() -> Color:
	if is_base():
		return BASE_HI
	return HI_MAX if is_maxed() else HI


func lo_color() -> Color:
	return BASE_LO if is_base() else LO


func ring_color() -> Color:
	if is_base():
		return RING if _enterprise else RING_BASE_OFF
	if not _enterprise:
		return RING_OFF
	return RING_MAX if is_maxed() else RING


func icon_color() -> Color:
	if is_base():
		return GuiColors.cat_color(_progress)
	if _tier <= 0:
		return MUTED_ICON
	return GuiColors.tier_color(_tier - 1, _max)


func alpha_value() -> float:
	if is_base():
		return 1.0
	return 1.0 if _usable else DIM_ALPHA


#The fill of one tier chunk: its own rank colour when owned, else the empty tube colour.
func pip_color(i: int) -> Color:
	if i < _tier:
		return GuiColors.tier_color(i, _max)
	return CHUNK_BG


func glow_factor() -> float:
	if not is_maxed():
		return 1.0
	return 1.0 + _glow * 0.8


#Chunk i shines a step behind chunk i minus one once every tier is owned.
func pip_glow(i: int) -> float:
	if not is_maxed() or _sweep.is_empty():
		return 1.0
	return 1.0 + _sweep[i % _sweep.size()] * 0.9


#The click a headless run makes; a drag on the canvas suppresses the real one.
func press() -> void:
	if not _usable:
		return
	pressed_block.emit(upgrade_id)


func _apply_size() -> void:
	var side: float = TreeLayout.block_size(upgrade_id)
	custom_minimum_size = Vector2(side, side)
	size = Vector2(side, side)


func _on_pulse(g: float, sweep: PackedFloat32Array) -> void:
	if not is_maxed():
		return
	_glow = g
	_sweep = sweep
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT or click.pressed:
		return
	press()


func _draw() -> void:
	var side: float = TreeLayout.block_size(upgrade_id)
	var box: Rect2 = Rect2(Vector2.ZERO, Vector2(side, side))
	var a: float = alpha_value()
	draw_rect(box, _fade(bg_color(), a))
	draw_rect(Rect2(0.0, 0.0, side, BEVEL), _fade(hi_color(), a))
	draw_rect(Rect2(0.0, 0.0, BEVEL, side), _fade(hi_color(), a))
	draw_rect(Rect2(0.0, side - BEVEL, side, BEVEL), _fade(lo_color(), a))
	draw_rect(Rect2(side - BEVEL, 0.0, BEVEL, side), _fade(lo_color(), a))
	draw_rect(box, _fade(ring_color(), a), false, RING_WIDTH)
	_draw_icon(side, a)
	if not is_base():
		_draw_pips(side, a)
		_draw_mask(side, a)
	_draw_labels(side, a)


func _draw_icon(side: float, a: float) -> void:
	var span: float = float(TreeGlyphs.COLS * ICON_SCALE)
	var tint: Color = _lit(icon_color(), glow_factor())
	var icon: ImageTexture = TreeGlyphs.logo(tint) if is_base() else TreeGlyphs.icon(upgrade_id,
		tint)
	if icon == null:
		return
	var top: float = (side - span) / 2.0 if is_base() else ICON_TOP
	draw_texture_rect(icon, Rect2(Vector2((side - span) / 2.0, top), Vector2(span, span)), false,
		Color(1.0, 1.0, 1.0, a))


func _draw_pips(side: float, a: float) -> void:
	var w: float = PIP_W_TIGHT if _max > TUBE_TIGHT_MAX else PIP_W
	var inner: float = float(_max) * w + float(maxi(0, _max - 1)) * PIP_GAP
	var tube: Rect2 = Rect2((side - inner - PIP_PAD_X * 2.0) / 2.0,
		side - PIP_LIFT - PIP_H - PIP_PAD_Y * 2.0, inner + PIP_PAD_X * 2.0,
		PIP_H + PIP_PAD_Y * 2.0)
	draw_rect(tube, _fade(TUBE_BG, a))
	draw_rect(Rect2(tube.position, Vector2(tube.size.x, 1.0)), _fade(TUBE_LO, a))
	draw_rect(Rect2(tube.position + Vector2(0.0, tube.size.y - 1.0), Vector2(tube.size.x, 1.0)),
		_fade(TUBE_HI, a))
	for i: int in range(_max):
		var at: Vector2 = tube.position + Vector2(PIP_PAD_X + float(i) * (w + PIP_GAP), PIP_PAD_Y)
		var c: Color = _lit(pip_color(i), pip_glow(i))
		draw_rect(Rect2(at, Vector2(w, PIP_H)), _fade(c, a))
		var hi: Color = c.lerp(Color.WHITE, 0.4) if i < _tier else CHUNK_HI
		var lo: Color = c.lerp(Color.BLACK, 0.35) if i < _tier else CHUNK_LO
		draw_rect(Rect2(at, Vector2(w, 1.0)), _fade(hi, a))
		draw_rect(Rect2(at + Vector2(0.0, PIP_H - 1.0), Vector2(w, 1.0)), _fade(lo, a))


#Upgrades that also sit in Less Legal carry the bandit mask in the corner.
func _draw_mask(side: float, a: float) -> void:
	if not UpgradeDefs.in_category(upgrade_id, "lessLegal"):
		return
	if UpgradeDefs.category_of(upgrade_id) == "lessLegal":
		return
	var mask: ImageTexture = TreeGlyphs.icon("lessLegal", LL_COLOR)
	if mask == null:
		return
	var span: float = float(TreeGlyphs.COLS)
	draw_texture_rect(mask, Rect2(Vector2(side - span - 4.0, 4.0), Vector2(span, span)), false,
		Color(1.0, 1.0, 1.0, a))


func _draw_labels(side: float, a: float) -> void:
	var left: float = (side - LABEL_WIDTH) / 2.0
	draw_string(NAME_FONT, Vector2(left, side + NAME_DROP + float(NAME_SIZE)), name_text(),
		HORIZONTAL_ALIGNMENT_CENTER, LABEL_WIDTH, NAME_SIZE, _fade(NAME_COLOR, a))
	var amount: String = fee_text()
	var w1: float = FEE_FONT.get_string_size(amount, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FEE_SIZE).x
	var w2: float = FEE_FONT.get_string_size(SUFFIX, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FEE_SIZE).x
	var tile: Vector2 = NoteIcon.tile_size(1)
	var total: float = w1 + 2.0 + tile.x + 2.0 + w2
	var x: float = side / 2.0 - total / 2.0
	var y: float = side + FEE_DROP + float(FEE_SIZE)
	var color: Color = _fade(fee_color(), a)
	draw_string(FEE_FONT, Vector2(x, y), amount, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FEE_SIZE, color)
	var tile_at: Vector2 = Vector2(x + w1 + 2.0, y - tile.y + 1.0)
	draw_rect(Rect2(tile_at, tile), _fade(NoteIcon.TILE_COLOR, a))
	var glyph: Vector2 = NoteIcon.GLYPH_SIZE_PX
	draw_texture_rect(NoteIcon.GLYPH, Rect2(tile_at + (tile - glyph) / 2.0, glyph), false,
		Color(1.0, 1.0, 1.0, a))
	draw_string(FEE_FONT, Vector2(x + w1 + 4.0 + tile.x, y), SUFFIX, HORIZONTAL_ALIGNMENT_LEFT,
		-1.0, FEE_SIZE, color)


func _fade(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


func _lit(c: Color, k: float) -> Color:
	return Color(minf(1.0, c.r * k), minf(1.0, c.g * k), minf(1.0, c.b * k), c.a)
