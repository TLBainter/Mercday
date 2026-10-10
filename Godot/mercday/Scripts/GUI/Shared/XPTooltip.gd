class_name XPTooltip extends TooltipPanel

#The LevelBadge hover tooltip: the XP fraction as text plus the full bar in ten cells, the empty
#ones on the track colour and the filled ones gold with an inset highlight, below the base rows.
#The tip floats over the badge it belongs to, so every node in it refuses the pointer: a hit
#inside the tip would read as a mouse exit on the badge and the tip would flicker shut.

const CELLS: int = 10
const CELL_GAP: float = 2.0
const TRACK_COLOR := GuiColors.BLUE_HI
#XP gold; the two shades are FILL_COLOR lightened and darkened by 0.30.
const FILL_COLOR := Color("#f2d43d")
const FILL_HI_COLOR := Color("#f6e177")
const FILL_LO_COLOR := Color("#a9942b")

@export var current_xp: int = 0:
	set(value):
		current_xp = value
		_refresh()
@export var next_level_xp: int = 1:
	set(value):
		next_level_xp = value
		_refresh()

@onready var bar: Control = $Rows/Bar


func _ready() -> void:
	super._ready()
	pass_mouse_through()
	bar.draw.connect(_draw_bar)
	_refresh()


func pass_mouse_through() -> void:
	GuiNodes.ignore_mouse(self)


#Test probe: true when nothing in the tip can take the pointer.
func passes_mouse() -> bool:
	return _all_ignore(self)


func _all_ignore(node: Node) -> bool:
	var control: Control = node as Control
	if control != null and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child: Node in node.get_children():
		if not _all_ignore(child):
			return false
	return true


func set_xp(current: int, next: int) -> void:
	current_xp = current
	next_level_xp = next
	_refresh()


static func fraction(current: int, next: int) -> float:
	if next <= 0:
		return 0.0
	return clampf(float(current) / float(next), 0.0, 1.0)


#Ten decile fills: a cell reads 1.0 once the fraction passes it and holds the remainder part way.
static func cells(value: float) -> Array[float]:
	var out: Array[float] = []
	var share: float = clampf(value, 0.0, 1.0)
	for i: int in CELLS:
		out.append(clampf(share * float(CELLS) - float(i), 0.0, 1.0))
	return out


func _refresh() -> void:
	if not is_node_ready():
		return
	set_text("XP", "%d / %d" % [current_xp, next_level_xp])
	bar.queue_redraw()


func _draw_bar() -> void:
	var box: Vector2 = bar.size
	var cell_w: float = (box.x - CELL_GAP * float(CELLS - 1)) / float(CELLS)
	if cell_w <= 0.0:
		return
	var parts: Array[float] = cells(fraction(current_xp, next_level_xp))
	for i: int in CELLS:
		var left: float = float(i) * (cell_w + CELL_GAP)
		bar.draw_rect(Rect2(left, 0.0, cell_w, box.y), TRACK_COLOR)
		var fill_w: float = cell_w * parts[i]
		if fill_w <= 0.0:
			continue
		bar.draw_rect(Rect2(left, 0.0, fill_w, box.y), FILL_COLOR)
		bar.draw_rect(Rect2(left, 0.0, fill_w, 1.0), FILL_HI_COLOR)
		bar.draw_rect(Rect2(left, box.y - 1.0, fill_w, 1.0), FILL_LO_COLOR)
