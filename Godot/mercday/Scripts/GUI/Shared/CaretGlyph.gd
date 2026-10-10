class_name CaretGlyph extends Control

#The text caret of one LineEdit: hides the engine caret and draws the small I-beam cut of the cursor
#sheet at the caret column, blinking while the field has focus and is editable.

const ID := "caret"
const BLINK := 0.65

var field: LineEdit
var on: bool = true

var _phase: float = 0.0
var _focused: bool = false
var _seen: Array = []


static func attach(target: LineEdit) -> CaretGlyph:
	var existing: CaretGlyph = of(target)
	if existing != null:
		return existing
	target.caret_blink = false
	target.add_theme_color_override("caret_color", Color(0, 0, 0, 0))
	var glyph := CaretGlyph.new()
	glyph.field = target
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(glyph)
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return glyph


static func of(target: LineEdit) -> CaretGlyph:
	for child: Node in target.get_children():
		if child is CaretGlyph:
			return child as CaretGlyph
	return null


static func watch(tree: SceneTree) -> void:
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)


#Deferred, since a node cannot take a child while it is still entering the tree.
static func _on_node_added(node: Node) -> void:
	if node is LineEdit:
		_attach_live.call_deferred(node)


static func _attach_live(node: Variant) -> void:
	if is_instance_valid(node) and (node as LineEdit).is_inside_tree():
		attach(node as LineEdit)


static func caret_x(target: LineEdit) -> int:
	var style: StyleBox = target.get_theme_stylebox("normal")
	var font: Font = target.get_theme_font("font")
	var font_size: int = target.get_theme_font_size("font_size")
	var shown: String = target.text if target.text != "" else target.placeholder_text
	var full: float = font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var ahead: float = 0.0
	if target.text != "":
		ahead = font.get_string_size(target.text.substr(0, target.caret_column), HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size).x
	var left: float = style.get_margin(SIDE_LEFT)
	var right: float = style.get_margin(SIDE_RIGHT)
	var scroll: float = target.get_scroll_offset()
	var x: float = left
	if target.alignment == HORIZONTAL_ALIGNMENT_CENTER:
		x = left if scroll != 0.0 else maxf(left, floorf((target.size.x - full) / 2.0))
	elif target.alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		x = maxf(left, target.size.x - right - full)
	return int(x + ahead - scroll)


func _process(delta: float) -> void:
	var focused: bool = field.has_focus()
	if focused and not _focused:
		on = true
		_phase = 0.0
	_focused = focused
	var flipped: bool = false
	if focused:
		_phase += delta
		flipped = _phase >= BLINK
		if flipped:
			_phase = fmod(_phase, BLINK)
			on = not on
	var now: Array = [field.caret_column, field.get_scroll_offset(), field.text, focused, field.editable]
	if flipped or now != _seen:
		_seen = now
		queue_redraw()


func _draw() -> void:
	if not (field.has_focus() and field.editable and on):
		return
	var top: float = floorf((size.y - CursorSheet.size(ID).y) / 2.0)
	draw_texture(CursorSheet.orange(ID), Vector2(caret_x(field) - CursorSheet.hotspot(ID).x, top))
