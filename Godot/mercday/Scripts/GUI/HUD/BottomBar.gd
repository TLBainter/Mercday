class_name BottomBar extends PanelContainer

#76 px strip: an orange top border over an inset 40 px row (GuiColors.ROW_FILL inside a 3 px GuiColors.INK frame)
#holding the MoneyMenu at the left and the TimeMenu at the right, each with its own divider.
#Edges draws the three inset lines that sit between the border and the row.

const EDGE_DARK: Color = GuiColors.INK
const EDGE_HI: Color = GuiColors.EDGE_HI
const EDGE_LO: Color = GuiColors.EDGE_LO
const EDGE_PX := 4.0

@export var inset_path: NodePath = ^"Pad/Inset"
@export var money_menu_path: NodePath = ^"Pad/Inset/Row/MoneyMenu"
@export var time_menu_path: NodePath = ^"Pad/Inset/Row/TimeMenu"
@export var edges_path: NodePath = ^"Edges"

var inset_panel: PanelContainer = null
var money_menu_node: MoneyMenu = null
var time_menu_node: TimeMenu = null
var edges: Control = null


func _ready() -> void:
	inset_panel = get_node_or_null(inset_path) as PanelContainer
	money_menu_node = get_node_or_null(money_menu_path) as MoneyMenu
	time_menu_node = get_node_or_null(time_menu_path) as TimeMenu
	edges = get_node_or_null(edges_path) as Control
	if edges != null:
		edges.draw.connect(_on_edges_draw)
		edges.resized.connect(edges.queue_redraw)


func money_menu() -> MoneyMenu:
	return money_menu_node


func time_menu() -> TimeMenu:
	return time_menu_node


func inset() -> PanelContainer:
	return inset_panel


func dividers() -> Array[ColorRect]:
	var out: Array[ColorRect] = []
	for holder: Node in [money_menu_node, time_menu_node]:
		if holder == null:
			continue
		var line: ColorRect = holder.get_node_or_null(^"Divider") as ColorRect
		if line != null:
			out.append(line)
	return out


func _on_edges_draw() -> void:
	var span: Vector2 = edges.size
	edges.draw_rect(Rect2(0.0, 0.0, span.x, EDGE_PX), EDGE_DARK)
	BevelButton.paint_edges(edges, Rect2(0.0, EDGE_PX, span.x, span.y - EDGE_PX), EDGE_HI, EDGE_LO, EDGE_PX,
		BevelButton.BEVEL_TOP | BevelButton.BEVEL_BOTTOM)
