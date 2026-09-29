class_name CategoryBox extends Control

#One branch label of the Customize tree: the category name, its icon lit by how much of the branch
#the guild owns, and the monthly total of the upgrades billed to it. A finished branch turns green
#and glows on the shared pulse.

const BG: Color = Color("#15223d")
const DONE_BG: Color = Color("#123321")
const NAME_COLOR: Color = Color("#9cc6ef")
const TOTAL_COLOR: Color = Color("#f3ead7")
const RING_WIDTH: float = 2.0
const ICON_SCALE: int = 2
const PAD: float = 10.0
const TOTAL_DROP: float = 48.0
const NAME_FONT: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const TOTAL_FONT: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const NAME_SIZE: int = 11
const TOTAL_SIZE: int = 12
const TOTAL_PREFIX: String = "Total "
const TOTAL_SUFFIX: String = "/month"
const GLYPH_GAP: float = 2.0

@export var cat: String = ""
@export var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()
#The colour of the line coming in from Base: the ring of an unfinished box takes it.
@export var lit: Color = Color("#f28c28")

var _have: int = 0
var _total: int = 0
var _fee: int = 0
var _glow: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = TreeLayout.CAT_BOX
	size = TreeLayout.CAT_BOX
	PulseClock.pulse.connect(_on_pulse)


func setup(id: String) -> void:
	cat = id
	queue_redraw()


#Reads the owned tiers of the branch and the fee of the upgrades billed to this box.
func refresh(tiers: Dictionary, enterprise: bool) -> void:
	var counts: Vector2i = TreeLayout.category_counts(cat, tiers)
	_have = counts.x
	_total = counts.y
	_fee = TreeLayout.category_fee(cat, tiers)
	progress = TreeLayout.category_progress(cat, tiers)
	lit = TreeLayout.BASE_LINE if enterprise else TreeLayout.BASE_LINE_OFF
	queue_redraw()


func name_text() -> String:
	var def: Dictionary = TreeLayout.cat_def(cat)
	return String(def.get("name", cat))


func desc_text() -> String:
	var def: Dictionary = TreeLayout.cat_def(cat)
	return String(def.get("desc", ""))


func total_text() -> String:
	return TOTAL_PREFIX + str(_fee)


func total_suffix() -> String:
	return TOTAL_SUFFIX


func monthly_fee() -> int:
	return _fee


func progress_text() -> String:
	return str(_have) + "/" + str(_total)


func owned_text() -> String:
	return progress_text() + " upgrades owned"


func is_complete() -> bool:
	return _total > 0 and _have >= _total


func bg_color() -> Color:
	return DONE_BG if is_complete() else BG


func ring_color() -> Color:
	return GuiColors.cat_color(1.0) if is_complete() else lit


func icon_color() -> Color:
	return GuiColors.cat_color(progress)


func glow_factor() -> float:
	if not is_complete():
		return 1.0
	return 1.0 + _glow * 0.8


func _on_pulse(g: float, _sweep: PackedFloat32Array) -> void:
	if not is_complete():
		return
	_glow = g
	queue_redraw()


func _draw() -> void:
	var box: Rect2 = Rect2(Vector2.ZERO, TreeLayout.CAT_BOX)
	draw_rect(box, bg_color())
	draw_rect(box, ring_color(), false, RING_WIDTH)
	var icon: ImageTexture = TreeGlyphs.icon(cat, _lit(icon_color()))
	var side: float = float(TreeGlyphs.COLS * ICON_SCALE)
	if icon != null:
		draw_texture_rect(icon, Rect2(Vector2(PAD, (TreeLayout.CAT_BOX.y - side) / 2.0),
			Vector2(side, side)), false)
	var text_x: float = PAD + side + 8.0
	draw_string(NAME_FONT, Vector2(text_x, TreeLayout.CAT_BOX.y / 2.0 + float(NAME_SIZE) / 2.0
		- 1.0), name_text(), HORIZONTAL_ALIGNMENT_LEFT, TreeLayout.CAT_BOX.x - text_x - PAD,
		NAME_SIZE, NAME_COLOR)
	_draw_total()


#The monthly total reads as one centred run: the amount, the notes tile and glyph, then "/month".
func _draw_total() -> void:
	var amount: String = total_text()
	var suffix: String = total_suffix()
	var w1: float = TOTAL_FONT.get_string_size(amount, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		TOTAL_SIZE).x
	var w2: float = TOTAL_FONT.get_string_size(suffix, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		TOTAL_SIZE).x
	var tile: Vector2 = NoteIcon.tile_size(1)
	var run: float = w1 + GLYPH_GAP + tile.x + GLYPH_GAP + w2
	var x: float = TreeLayout.CAT_BOX.x / 2.0 - run / 2.0
	var y: float = TOTAL_DROP + float(TOTAL_SIZE)
	draw_string(TOTAL_FONT, Vector2(x, y), amount, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TOTAL_SIZE,
		TOTAL_COLOR)
	var tile_at: Vector2 = Vector2(x + w1 + GLYPH_GAP, y - tile.y + 1.0)
	draw_rect(Rect2(tile_at, tile), NoteIcon.TILE_COLOR)
	var glyph: Vector2 = NoteIcon.GLYPH_SIZE_PX
	draw_texture_rect(NoteIcon.GLYPH, Rect2(tile_at + (tile - glyph) / 2.0, glyph), false)
	draw_string(TOTAL_FONT, Vector2(x + w1 + GLYPH_GAP * 2.0 + tile.x, y), suffix,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, TOTAL_SIZE, TOTAL_COLOR)


func _lit(c: Color) -> Color:
	var k: float = glow_factor()
	return Color(minf(1.0, c.r * k), minf(1.0, c.g * k), minf(1.0, c.b * k), c.a)
