class_name TraditionModule extends PanelContainer

#The one panel that shows a tradition anywhere in the game: the sigil in its ringed box, the name
#beside it and the blue band along the bottom. TITLE is the Merc Overview header; ROW is the list
#line that stands as tall as a SlotChip; COMPACT is the dispatch team slot, where the name must fit
#unclipped in 74 px. The ring takes the tradition colour; an empty tradition reads the empty text in
#the fallback colour.

enum SizeMode { TITLE, ROW, COMPACT }

const TITLE_BAND_COLOR: Color = Color("#2b4f8a")
const TITLE_BAND_PX: float = 4.0
const ROW_BAND_PX: float = 2.0
const COMPACT_BAND_PX: float = 2.0
const TITLE_BOX: Vector2 = Vector2(40, 40)
const ROW_BOX: Vector2 = Vector2(28, 28)
const COMPACT_BOX: Vector2 = Vector2(20, 20)
const TITLE_FONT_PX: int = 18
const ROW_FONT_PX: int = 14
#Honorable, the longest name, measures 87 px at 11 and 80 px at 10; only 9 fits the 74 px the slot
#leaves beside the 20 px box.
const COMPACT_FONT_PX: int = 9
const TITLE_SEPARATION: int = 14
const ROW_SEPARATION: int = 8
const COMPACT_SEPARATION: int = 6
const TITLE_RING_PX: int = 2
const ROW_RING_PX: int = 2
const COMPACT_RING_PX: int = 1
const TITLE_MARGIN: Vector2 = Vector2(14, 10)
const ROW_MARGIN: Vector2 = Vector2(6, 2)
const COMPACT_MARGIN: Vector2 = Vector2(4, 2)
const SIGIL_SCALE: int = 2
#The sigil cell is 16 px, so the 20 px compact box takes it unscaled.
const COMPACT_SIGIL_SCALE: int = 1
#The 28 px row box holds the same unscaled cell inside its 2 px ring.
const ROW_SIGIL_SCALE: int = 1

@export var tradition: String = "":
	set(value):
		tradition = value
		_refresh()
@export var empty_text: String = "None":
	set(value):
		empty_text = value
		_refresh()
@export var size_mode: SizeMode = SizeMode.TITLE:
	set(value):
		size_mode = value
		_apply_size()
		_refresh()

var _panel_style: StyleBoxFlat = null
var _sigil_style: StyleBoxFlat = null


func _ready() -> void:
	_panel_style = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	add_theme_stylebox_override("panel", _panel_style)
	_sigil_style = sigil_box().get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	sigil_box().add_theme_stylebox_override("panel", _sigil_style)
	_apply_size()
	_refresh()


func sigil() -> TraditionSigil:
	return $Row/SigilBox/Center/Sigil as TraditionSigil


func sigil_box() -> PanelContainer:
	return $Row/SigilBox as PanelContainer


func name_label() -> Label:
	return $Row/Name as Label


func row_box() -> HBoxContainer:
	return $Row as HBoxContainer


func ring_color() -> Color:
	return GuiTypes.tradition_color(tradition)


func band_px() -> float:
	match size_mode:
		SizeMode.ROW:
			return ROW_BAND_PX
		SizeMode.COMPACT:
			return COMPACT_BAND_PX
	return TITLE_BAND_PX


func is_title() -> bool:
	return size_mode == SizeMode.TITLE


#The three modes differ only in their measurements; the colours and the parts are the same.
func _apply_size() -> void:
	if not is_node_ready():
		return
	var margin: Vector2 = TITLE_MARGIN
	var ring: int = TITLE_RING_PX
	var box: Vector2 = TITLE_BOX
	var separation: int = TITLE_SEPARATION
	var font_px: int = TITLE_FONT_PX
	var sigil_scale: int = SIGIL_SCALE
	match size_mode:
		SizeMode.ROW:
			margin = ROW_MARGIN
			ring = ROW_RING_PX
			box = ROW_BOX
			separation = ROW_SEPARATION
			font_px = ROW_FONT_PX
			sigil_scale = ROW_SIGIL_SCALE
		SizeMode.COMPACT:
			margin = COMPACT_MARGIN
			ring = COMPACT_RING_PX
			box = COMPACT_BOX
			separation = COMPACT_SEPARATION
			font_px = COMPACT_FONT_PX
			sigil_scale = COMPACT_SIGIL_SCALE
	if _panel_style != null:
		_panel_style.content_margin_left = margin.x
		_panel_style.content_margin_right = margin.x
		_panel_style.content_margin_top = margin.y
		_panel_style.content_margin_bottom = margin.y
	if _sigil_style != null:
		_sigil_style.set_border_width_all(ring)
	sigil_box().custom_minimum_size = box
	sigil().pixel_scale = sigil_scale
	row_box().add_theme_constant_override("separation", separation)
	name_label().add_theme_font_size_override("font_size", font_px)
	name_label().clip_text = size_mode != SizeMode.COMPACT


func _refresh() -> void:
	if not is_node_ready():
		return
	sigil().tradition = tradition
	name_label().text = tradition if tradition != "" else empty_text
	if _sigil_style != null:
		_sigil_style.border_color = ring_color()
		sigil_box().add_theme_stylebox_override("panel", _sigil_style)
	queue_redraw()


#The prototype carries a blue band under the panel; a stylebox has no second edge colour.
func _draw() -> void:
	var band: float = band_px()
	draw_rect(Rect2(0.0, size.y - band, size.x, band), TITLE_BAND_COLOR)
