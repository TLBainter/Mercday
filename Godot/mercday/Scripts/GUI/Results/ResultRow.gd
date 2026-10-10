class_name ResultRow extends PanelContainer

#One member of the team: portrait and fate, name and level, the experience column, the three
#resource bars and the status with the bonus paid. Every value comes from the one clock.

const PORTRAIT_PX: float = 48.0
const PORTRAIT_RING: float = 2.0
const PORTRAIT_RING_COLOR: Color = GuiColors.BLUE_HI
const STRIPE_PX: float = 4.0
const STRIPE_A: Color = GuiColors.BLUE_LO
const STRIPE_B: Color = GuiColors.ROW_FILL
const BAR_TRACK: Color = GuiColors.INK
const BAR_RING: Color = GuiColors.BLUE_LO
const BAR_RING_PX: float = 2.0
const XP_SEGMENT: float = 16.0
const XP_SEGMENT_GAP: float = 2.0
const XP_HI: Color = Color(1.0, 1.0, 1.0, 0.3)
const XP_LO: Color = Color(0.0, 0.0, 0.0, 0.25)
const XP_HI_PX: float = 3.0
const RES_HI_PX: float = 2.0
const RES_LO: Color = Color(0.0, 0.0, 0.0, 0.3)
const LEVEL_BEVEL: float = 2.0
const LEVEL_HI: Color = GuiColors.ORANGE_HI
const LEVEL_LO: Color = GuiColors.ORANGE_LO
const MVP_HI: Color = Color("#fff08a")
const MVP_LO: Color = Color("#b89a1a")
const MVP_BEVEL: float = 2.0
const HP_COLOR: Color = GuiColors.RED
const EP_COLOR: Color = GuiColors.GREEN
const MP_COLOR: Color = GuiColors.LIGHT_BLUE
const ROLE_JOIN: String = " - "
const BAR_KEYS: Array[String] = ["HP", "EP", "MP"]

@onready var portrait_box: Control = $Grid/Portrait
@onready var plate: Control = $Grid/Portrait/Plate
@onready var portrait: MercPortrait = $Grid/Portrait/Portrait
@onready var fate_overlay: TextureRect = $Grid/Portrait/Overlay
@onready var name_label: Label = $Grid/Ident/TopRow/Name
@onready var mvp_label: Label = $Grid/Ident/TopRow/Mvp
@onready var level_label: Label = $Grid/Ident/BotRow/Level
@onready var plus_label: Label = $Grid/Ident/BotRow/Plus
@onready var tradition_label: Label = $Grid/Ident/BotRow/Tradition
@onready var role_label: Label = $Grid/Ident/BotRow/Role
@onready var xp_value: Label = $Grid/XpCol/XpHead/Value
@onready var xp_bar: Control = $Grid/XpCol/XpBar
@onready var xp_number: Label = $Grid/XpCol/XpNumber
@onready var bars_col: VBoxContainer = $Grid/BarsCol
@onready var status_label: Label = $Grid/StatusCol/Status
@onready var pay_label: Label = $Grid/StatusCol/PayRow/Pay
@onready var pay_glyph: TextureRect = $Grid/StatusCol/PayRow/Glyph

var _member: ResultMemberData = null
var _index: int = 0
var _failed: bool = false
var _ring: Color = ResultsTimeline.RING_IDLE
var _fill: float = 0.0
var _fill_color: Color = ResultsTimeline.XP_FILL
var _glow: bool = false
var _bars: Array[Dictionary] = []
var _style: StyleBoxFlat = null


func _ready() -> void:
	_style = (get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	add_theme_stylebox_override("panel", _style)
	plate.clip_contents = true
	plate.draw.connect(_on_portrait_draw)
	xp_bar.draw.connect(_on_xp_draw)
	level_label.draw.connect(_on_level_draw)
	mvp_label.draw.connect(_on_mvp_draw)
	_place_overlay()
	fate_overlay.visible = false
	_collect_bars()
	apply_time(0.0)


func set_member(data: ResultMemberData, index: int, failed: bool,
		view: MercView = null) -> void:
	_member = data
	_index = index
	_failed = failed
	if data == null:
		return
	name_label.text = data.name
	name_label.tooltip_text = data.name
	tradition_label.text = data.tradition
	tradition_label.add_theme_color_override("font_color",
			GuiTypes.tradition_color(data.tradition))
	role_label.text = ROLE_JOIN + data.role
	if view != null:
		portrait.set_merc(view)
	portrait.visible = view != null
	fate_overlay.texture = ResultsGlyphs.overlay_for(data.fate)
	_place_overlay()
	apply_time(0.0)


#The fate art sits on whole pixels: the trimmed skull goes at the floored centre of the 48 px
#portrait and the pivot keeps the reveal pop growing from that centre.
func _place_overlay() -> void:
	var box: Vector2 = Vector2(PORTRAIT_PX, PORTRAIT_PX)
	var art: Vector2 = box if fate_overlay.texture == null else fate_overlay.texture.get_size()
	var spot: Vector2 = ((box - art) / 2.0).floor()
	fate_overlay.position = spot
	fate_overlay.size = art
	fate_overlay.pivot_offset = box / 2.0 - spot


func apply_time(t: float) -> void:
	if not is_node_ready():
		return
	var state: Dictionary = ResultsTimeline.xp_state(_member, t)
	_fill = float(state["fill"])
	_fill_color = state["fill_color"] as Color
	_glow = bool(state["glow"])
	level_label.text = "%02d" % int(state["level"])
	plus_label.visible = bool(state["plus"])
	xp_value.text = String(state["text"])
	xp_value.add_theme_color_override("font_color", state["color"] as Color)
	xp_number.text = String(state["number"])
	status_label.text = ResultsTimeline.status_text(_member, t)
	status_label.add_theme_color_override("font_color",
			ResultsTimeline.status_color(_member, t))
	var pay_color: Color = ResultsTimeline.pay_color(_member, _index, t, _failed)
	pay_label.text = ResultsTimeline.pay_text(_member, _index, t, _failed)
	pay_label.add_theme_color_override("font_color", pay_color)
	pay_glyph.texture = CrewGlyphs.note(pay_color)
	_ring = ResultsTimeline.ring_color(_member, t, _failed)
	_style.border_color = _ring
	_apply_filter(t)
	var shown: bool = ResultsTimeline.fates_on(t) and fate_overlay.texture != null
	fate_overlay.visible = shown
	var badge_on: bool = _badge_on()
	if portrait.show_badge != badge_on:
		portrait.show_badge = badge_on
	if shown:
		var pop: float = ResultsTimeline.fate_scale(t)
		fate_overlay.scale = Vector2(pop, pop)
	mvp_label.visible = ResultsTimeline.mvp_on(_member, t, _failed)
	for row: Dictionary in _bars:
		var stats: Vector3i = _stats(String(row["key"]))
		var value: float = ResultsTimeline.bar_value(stats.z, stats.x, t)
		row["fill"] = clampf(value / maxf(1.0, float(stats.y)), 0.0, 1.0)
		(row["value"] as Label).text = "%d/%d" % [int(round(value)), stats.y]
		(row["bar"] as Control).queue_redraw()
	xp_bar.queue_redraw()
	level_label.queue_redraw()
	plate.queue_redraw()


#A row with a fate overlay shows no badge.
func _badge_on() -> bool:
	if _member == null:
		return true
	return fate_overlay.texture == null


#The centre of the pay cell in global coordinates: the flying notes land here.
func pay_anchor() -> Vector2:
	return pay_label.get_global_rect().get_center()


func member() -> ResultMemberData:
	return _member


func status_text() -> String:
	return status_label.text


func pay_text() -> String:
	return pay_label.text


func xp_text() -> String:
	return xp_value.text


func xp_number_text() -> String:
	return xp_number.text


func xp_fill() -> float:
	return _fill


func level_text() -> String:
	return level_label.text


func plus_shown() -> bool:
	return plus_label.visible


func mvp_shown() -> bool:
	return mvp_label.visible


func overlay_shown() -> bool:
	return fate_overlay.visible


func badge_id() -> String:
	return portrait.badge_id()


func portrait_shown() -> bool:
	return portrait.visible


func ring_color() -> Color:
	return _ring


func filtered() -> bool:
	return plate.material != null


func bar_fill(key: String) -> float:
	for row: Dictionary in _bars:
		if String(row["key"]) == key:
			return float(row["fill"])
	return 0.0


func bar_text(key: String) -> String:
	for row: Dictionary in _bars:
		if String(row["key"]) == key:
			return (row["value"] as Label).text
	return ""


func _apply_filter(t: float) -> void:
	var gray: float = ResultsTimeline.portrait_gray(_member, t)
	var bright: float = ResultsTimeline.portrait_brightness(_member, t)
	var filter: ShaderMaterial = null
	if gray > 0.0 or bright < 1.0:
		filter = ResultsGlyphs.portrait_material(gray, bright)
	plate.material = filter
	portrait.material = filter


func _collect_bars() -> void:
	if not _bars.is_empty():
		return
	var colors: Array[Color] = [HP_COLOR, EP_COLOR, MP_COLOR]
	for i: int in BAR_KEYS.size():
		var holder: HBoxContainer = bars_col.get_child(i) as HBoxContainer
		if holder == null:
			continue
		var bar: Control = holder.get_node("Bar") as Control
		var row: Dictionary = {
			"key": BAR_KEYS[i],
			"color": colors[i],
			"bar": bar,
			"value": holder.get_node("Value") as Label,
			"fill": 0.0,
		}
		_bars.append(row)
		bar.draw.connect(_on_res_draw.bind(row))


#Now, max and the value before the contract for one bar, read off the member fields named after
#its key (HP reads hp and hp_before).
func _stats(key: String) -> Vector3i:
	if _member == null:
		return Vector3i.ZERO
	var field: String = key.to_lower()
	var pool: Vector2i = _member.get(field)
	return Vector3i(pool.x, pool.y, int(_member.get(field + "_before")))


func _on_portrait_draw() -> void:
	var side: float = PORTRAIT_PX
	plate.draw_rect(Rect2(0.0, 0.0, side, side), STRIPE_B)
	var offset: float = -side
	while offset < side:
		var points := PackedVector2Array([
			Vector2(offset, 0.0),
			Vector2(offset + STRIPE_PX, 0.0),
			Vector2(offset + STRIPE_PX + side, side),
			Vector2(offset + side, side),
		])
		plate.draw_colored_polygon(points, STRIPE_A)
		offset += STRIPE_PX * 2.0
	BevelButton.paint_edges(plate, Rect2(0.0, 0.0, side, side), PORTRAIT_RING_COLOR,
		PORTRAIT_RING_COLOR, PORTRAIT_RING)


func _on_xp_draw() -> void:
	var rect := Rect2(Vector2.ZERO, xp_bar.size)
	xp_bar.draw_rect(rect, BAR_TRACK)
	var width: float = rect.size.x * clampf(_fill, 0.0, 1.0)
	if width > 0.0:
		xp_bar.draw_rect(Rect2(0.0, 0.0, width, rect.size.y), _fill_color)
		BevelButton.paint_edges(xp_bar, Rect2(0.0, 0.0, width, rect.size.y), XP_HI, XP_LO, XP_HI_PX,
			BevelButton.BEVEL_TOP | BevelButton.BEVEL_BOTTOM)
	var x: float = XP_SEGMENT - XP_SEGMENT_GAP
	while x < rect.size.x:
		xp_bar.draw_rect(Rect2(x, 0.0, XP_SEGMENT_GAP, rect.size.y), BAR_TRACK)
		x += XP_SEGMENT
	BevelButton.paint_edges(xp_bar, rect, BAR_RING, BAR_RING, BAR_RING_PX)
	BevelButton.paint_ring(xp_bar, rect, BAR_TRACK, BAR_RING_PX)
	if _glow:
		BevelButton.paint_ring(xp_bar, rect, MVP_HI, BAR_RING_PX)


func _on_res_draw(row: Dictionary) -> void:
	var bar: Control = row["bar"] as Control
	var rect := Rect2(Vector2.ZERO, bar.size)
	bar.draw_rect(rect, BAR_TRACK)
	var width: float = rect.size.x * clampf(float(row["fill"]), 0.0, 1.0)
	if width > 0.0:
		bar.draw_rect(Rect2(0.0, 0.0, width, rect.size.y), row["color"] as Color)
		BevelButton.paint_edges(bar, Rect2(0.0, 0.0, width, rect.size.y), XP_HI, RES_LO, RES_HI_PX,
			BevelButton.BEVEL_TOP | BevelButton.BEVEL_BOTTOM)
	BevelButton.paint_edges(bar, rect, BAR_RING, BAR_RING, BAR_RING_PX)


func _on_level_draw() -> void:
	var rect := Rect2(Vector2.ZERO, level_label.size)
	BevelButton.paint_edges(level_label, rect, LEVEL_HI, LEVEL_LO, LEVEL_BEVEL)
	if _glow:
		BevelButton.paint_ring(level_label, rect, MVP_HI, LEVEL_BEVEL)


func _on_mvp_draw() -> void:
	var rect := Rect2(Vector2.ZERO, mvp_label.size)
	BevelButton.paint_edges(mvp_label, rect, MVP_HI, MVP_LO, MVP_BEVEL)
