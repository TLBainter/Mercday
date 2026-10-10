class_name TooltipPanel extends PanelContainer

#Base of every hover tooltip: a top level panel that opens on one side of an anchor and stays inside
#its bounds. A viewer keeps one instance and moves it between anchors; subclasses add rows under Rows.

const GAP: int = 4
#A tooltip is the top of the whole z order: above every frame of GuiFrameStack and above the
#money flight at 200.
const TOOLTIP_Z: int = 250
const LINE_GAP_H: int = 10
const LINE_GAP_V: int = 2
const LINE_VARIATION: StringName = &"SmallLabel"

#The side of the anchor the tip opens on: &"below", &"above", &"left" or &"right".
@export var side: StringName = &"below"
#Room kept clear between the tip and every edge of its bounds.
@export var edge_pad: float = 0.0
#Holds the body copy at least this wide, so a long body wraps there; 0 keeps the width of the label.
@export var body_width: float = 0.0

@onready var title_label: Label = $Rows/Title
@onready var body_label: Label = $Rows/Body

var _anchor_rect: Rect2 = Rect2()
var _bounds: Rect2 = Rect2()
#The optional label and amount grid under the title; built on the first set_lines call.
var _lines: GridContainer = null
var _line_texts: Array[String] = []


func _ready() -> void:
	top_level = true
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = TOOLTIP_Z
	if body_width > 0.0:
		body_label.custom_minimum_size.x = body_width
	minimum_size_changed.connect(_on_minimum_size_changed)
	hide()


func set_text(title: String, body: String) -> void:
	title_label.text = title
	title_label.visible = title != ""
	body_label.text = body
	body_label.visible = body != ""
	_line_texts.clear()
	if _lines != null:
		GuiNodes.clear(_lines)
		_lines.visible = false


#The title over a list of {"label", "amount"} lines, with footer as the body under them; an amount
#below 0 prints its label alone, as a heading.
func set_lines(title: String, lines: Array, footer: String = "") -> void:
	set_text(title, footer)
	var grid: GridContainer = _lines_grid()
	for item: Variant in lines:
		var row: Dictionary = item as Dictionary
		var amount: int = int(row.get("amount", 0))
		var label: String = String(row.get("label", ""))
		var value: String = "" if amount < 0 else line_amount_text(amount)
		_line_label(grid, label, false)
		_line_label(grid, value, true)
		_line_texts.append(label if value == "" else "%s: %s" % [label, value])
	grid.visible = not lines.is_empty()


#Each line as "label: amount", or the label alone for a heading; empty while the body text shows.
func line_texts() -> Array[String]:
	return _line_texts.duplicate()


static func line_amount_text(amount: int) -> String:
	return "%s N" % TransactionData.grouped(amount)


func _lines_grid() -> GridContainer:
	if _lines != null:
		return _lines
	_lines = GridContainer.new()
	_lines.name = "Lines"
	_lines.columns = 2
	_lines.add_theme_constant_override("h_separation", LINE_GAP_H)
	_lines.add_theme_constant_override("v_separation", LINE_GAP_V)
	var rows: Node = title_label.get_parent()
	rows.add_child(_lines)
	rows.move_child(_lines, title_label.get_index() + 1)
	return _lines


static func _line_label(grid: GridContainer, text: String, right: bool) -> void:
	var label := Label.new()
	label.theme_type_variation = LINE_VARIATION
	label.text = text
	if right:
		label.size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	grid.add_child(label)


func show_at(anchor: Control, bounds: Rect2 = Rect2()) -> void:
	reset_size()
	place(anchor.get_global_rect(), bounds)
	show()


#Moves the tip next to a global anchor rect; an empty bounds means the visible viewport.
func place(anchor_rect: Rect2, bounds: Rect2 = Rect2()) -> void:
	_anchor_rect = anchor_rect
	_bounds = bounds
	if bounds.size == Vector2.ZERO:
		bounds = get_viewport().get_visible_rect()
	var inner: Rect2 = bounds.grow(-edge_pad)
	global_position = tip_position(anchor_rect, get_combined_minimum_size(), inner, side)


#A tip shown for the first time has not sorted its wrapping body label yet, so the minimum size
#place() first measured can be wrong; once the real size settles this re-centres on it.
func _on_minimum_size_changed() -> void:
	if not visible:
		return
	reset_size()
	place(_anchor_rect, _bounds)


#Where a box of size wanted opens on on_side of anchor inside inner. It flips to the opposite side
#when it would leave inner there; along the other axis it lines up with the anchor start, clamped.
static func tip_position(anchor: Rect2, wanted: Vector2, inner: Rect2, on_side: StringName) -> Vector2:
	var along: int = 0 if on_side == &"left" or on_side == &"right" else 1
	var across: int = 1 - along
	var after: float = anchor.end[along] + GAP
	var before: float = anchor.position[along] - GAP - wanted[along]
	var pos := Vector2.ZERO
	if on_side == &"above" or on_side == &"left":
		pos[along] = before if before >= inner.position[along] else minf(inner.end[along] - wanted[along], after)
	else:
		pos[along] = after if after + wanted[along] <= inner.end[along] else maxf(inner.position[along], before)
	var far: float = maxf(inner.position[across], inner.end[across] - wanted[across])
	pos[across] = clampf(anchor.position[across], inner.position[across], far)
	return pos


func hide_tip() -> void:
	hide()
