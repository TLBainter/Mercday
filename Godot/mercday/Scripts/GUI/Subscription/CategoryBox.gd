class_name CategoryBox extends Control

#One branch label of the Customize tree: the category name, its icon lit by how much of the branch
#the guild owns, and the monthly total of the upgrades billed to it. A finished branch turns green
#and glows on the shared pulse.

const BG: Color = GuiColors.ROW_HOVER
const DONE_BG: Color = GuiColors.DONE_GREEN_BG
const NAME_COLOR: Color = GuiColors.SKY
const TOTAL_COLOR: Color = GuiColors.CREAM
const RING_WIDTH: float = 2.0
const ICON_SCALE: int = 2
const PAD: float = 10.0
const NAME_FONT: FontVariation = GuiStyle.SILK
const TOTAL_FONT: FontVariation = GuiStyle.SILK_BOLD
const NAME_SIZE: int = 11
const TOTAL_SIZE: int = 12
const TOTAL_PREFIX: String = "Total "
const TOTAL_SUFFIX: String = "/month"

@export var cat: String = ""
@export var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()
#The colour of the line coming in from Base: the ring of an unfinished box takes it.
@export var lit: Color = GuiColors.ORANGE

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
	return progress_text() + TreeLayout.OWNED_SUFFIX


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
	return PulseClock.glow_of(_glow)


func _on_pulse(g: float, _sweep: PackedFloat32Array) -> void:
	if not is_complete():
		return
	_glow = g
	queue_redraw()


func _draw() -> void:
	var box: Rect2 = Rect2(Vector2.ZERO, TreeLayout.CAT_BOX)
	draw_rect(box, bg_color())
	draw_rect(box, ring_color(), false, RING_WIDTH)
	var side: float = 16.0 * float(ICON_SCALE)
	var icon_id: String = TreeIcons.id_of(cat)
	if icon_id != "":
		Icons.draw(self, icon_id, Vector2(PAD, (TreeLayout.CAT_BOX.y - side) / 2.0), ICON_SCALE,
			GuiColors.brighter(icon_color(), glow_factor()), false)
	var text_x: float = PAD + side + 8.0
	draw_string(NAME_FONT, Vector2(text_x, TreeLayout.CAT_BOX.y / 2.0 + float(NAME_SIZE) / 2.0
		- 1.0), name_text(), HORIZONTAL_ALIGNMENT_LEFT, TreeLayout.CAT_BOX.x - text_x - PAD,
		NAME_SIZE, NAME_COLOR)
	_draw_total()


#The monthly total reads as one centred run: the amount, the notes tile and glyph, then "/month".
func _draw_total() -> void:
	NoteIcon.draw_run(self, TOTAL_FONT, TOTAL_SIZE, total_text(), total_suffix(),
		TreeLayout.CAT_BOX.x / 2.0, total_baseline(), TOTAL_COLOR)


#The total sits centred in the gap TreeLayout leaves between the box stub and the resumed line.
static func total_baseline() -> float:
	var gap_top: float = TreeLayout.CAT_BOX.y + TreeLayout.CAT_STUB
	var gap_bottom: float = TreeLayout.CAT_BOX.y / 2.0 + TreeLayout.CAT_TOTAL_DROP
	var mid: float = (gap_top + gap_bottom) / 2.0
	return mid + (TOTAL_FONT.get_ascent(TOTAL_SIZE) - TOTAL_FONT.get_descent(TOTAL_SIZE)) / 2.0
