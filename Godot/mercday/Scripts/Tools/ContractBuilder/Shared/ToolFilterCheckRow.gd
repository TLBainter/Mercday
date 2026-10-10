@tool
class_name ToolFilterCheckRow extends FilterCheckRow

#FilterCheckRow for editor tools, made in code by make_row() with the FilterCheckRow.tscn root properties.
#No scene swaps the script, so the exports FilterCheckRow._init sets survive; the row reaches no autoload.
#A dot_color with alpha above 0 draws the outlined notification dot art in a DOT_ROOM slot between the box and the label.

#The painted dot is 10 px (8 px dot art at scale 1 and a 1 px outline each side), so the slot leaves 2 px clear each side.
const DOT_ROOM: float = 14.0
const DOT_SCALE: int = 1
const DOT_OUTLINE: float = 1.0
const NO_DOT: Color = Color(0, 0, 0, 0)

var dot_color: Color = NO_DOT:
	set(value):
		dot_color = value
		if is_node_ready():
			_apply_style()
		queue_redraw()


static func make_row(text: String, is_on: bool) -> ToolFilterCheckRow:
	var row: ToolFilterCheckRow = ToolFilterCheckRow.new()
	row.custom_minimum_size = Vector2(0, 20)
	row.toggle_mode = true
	row.flat = true
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.label = text
	row.on = is_on
	return row


func has_dot() -> bool:
	return dot_color.a > 0.0


#BevelButton gives a clipped label the width less twice the left margin; the wider face makes it the width less both
#margins, as the minimum size counts it. The box and the dot use the real rect.
func _draw_face(rect: Rect2) -> void:
	var face: Rect2 = rect
	if clip_text:
		face.size.x += _pad() - get_theme_stylebox(&"normal").get_margin(SIDE_RIGHT)
	super(face)
	if not has_dot():
		return
	var art: AtlasTexture = Icons.tex("dot", true)
	if art == null:
		return
	var half: Vector2 = art.get_size() * float(DOT_SCALE) / 2.0
	var centre: Vector2 = Vector2(rect.position.x + TEXT_MARGIN + DOT_ROOM / 2.0, rect.position.y + rect.size.y / 2.0)
	var at: Vector2 = (centre - half).floor()
	var edges: Array[Vector2] = [Vector2(-DOT_OUTLINE, 0.0), Vector2(DOT_OUTLINE, 0.0),
		Vector2(0.0, -DOT_OUTLINE), Vector2(0.0, DOT_OUTLINE)]
	for shift: Vector2 in edges:
		Icons.draw(self, "dot", at + shift, DOT_SCALE, NotificationDot.OUTLINE_COLOR, true)
	Icons.draw(self, "dot", at, DOT_SCALE, dot_color, true)


func _apply_style() -> void:
	super()
	if has_dot():
		get_theme_stylebox(&"normal").content_margin_left += DOT_ROOM
	update_minimum_size()
