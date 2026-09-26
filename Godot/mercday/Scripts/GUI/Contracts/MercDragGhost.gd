class_name MercDragGhost extends Control

#What the cursor carries while a merc is dragged: a copy of the roster row on its own panel, faded,
#hung off the point the drag was grabbed at so the row stays under the pointer instead of jumping its
#corner there. Godot parks the preview's origin on the cursor every motion, so the row rides a
#negative offset. The source row or slot dims itself while this is out.

const GHOST_ALPHA: float = 0.9
const ROW_SCENE: PackedScene = preload("res://Scenes/GUI/Contracts/DispatchRosterItem.tscn")
const BOX_BG: Color = Color("#1a2b4d")
const BOX_RING: Color = Color("#3b6fb6")
const BOX_RING_WIDTH: int = 2

var _row: DispatchRosterItem = null
var _box: StyleBoxFlat = null


#row_size below the row scene's own minimum falls back to that minimum; grab is clamped into it.
static func build(view: MercView, stars: float, row_size: Vector2, grab: Vector2) -> MercDragGhost:
	var ghost := MercDragGhost.new()
	ghost.name = "MercDragGhost"
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.modulate = Color(1.0, 1.0, 1.0, GHOST_ALPHA)
	var carried: DispatchRosterItem = ROW_SCENE.instantiate()
	carried.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wanted := Vector2(maxf(row_size.x, carried.custom_minimum_size.x),
		maxf(row_size.y, carried.custom_minimum_size.y))
	ghost._row = carried
	ghost._box = _make_box()
	ghost.custom_minimum_size = wanted
	ghost.add_child(carried)
	carried.set_merc(view, stars, false)
	carried.set_status_visible(false)
	carried.size = wanted
	carried.position = -Vector2(clampf(grab.x, 0.0, wanted.x), clampf(grab.y, 0.0, wanted.y))
	return ghost


func row() -> DispatchRosterItem:
	return _row


func box() -> StyleBoxFlat:
	return _box


#The ghost is the parent, so the panel lands under the row it carries.
func _draw() -> void:
	if _row == null or _box == null:
		return
	draw_style_box(_box, Rect2(_row.position, _row.size))


static func _make_box() -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = BOX_BG
	panel.border_color = BOX_RING
	panel.border_width_left = BOX_RING_WIDTH
	panel.border_width_top = BOX_RING_WIDTH
	panel.border_width_right = BOX_RING_WIDTH
	panel.border_width_bottom = BOX_RING_WIDTH
	panel.content_margin_left = 0.0
	panel.content_margin_top = 0.0
	panel.content_margin_right = 0.0
	panel.content_margin_bottom = 0.0
	return panel
