class_name GuildRelationshipCard extends PanelContainer

#The full width card over the Relationships grid: the merc's opinion of the guild as the one lit
#face on the eleven step opinion row, with the orange left edge and the mood coloured bottom edge.

const TITLE: String = "GUILD"
const CAPTION: String = "GUILD OPINION"
const VALUE_TEXT: String = "%+d"
const PANEL_FILL: Color = GuiColors.ROW_FILL
const LEFT_EDGE_COLOR: Color = GuiColors.ORANGE
const EDGE_PX: float = 4.0
const MIN_OPINION: int = -5
const MAX_OPINION: int = 5

@export var opinion: int = 0:
	set(value):
		opinion = value
		_refresh()

@onready var portrait_box: Control = $Row/PortraitBox
@onready var title_label: Label = $Row/Names/Title
@onready var caption_label: Label = $Row/Names/Caption
@onready var value_label: Label = $Row/Names/Value
@onready var faces_row: MoodMeter = $Row/Faces


func _ready() -> void:
	portrait_box.draw.connect(_draw_portrait)
	add_theme_stylebox_override(&"panel", _card_box())
	_refresh()


func set_opinion(value: int) -> void:
	opinion = value


#The lit face, the one whose opinion step the merc sits on.
func face() -> MoodFace:
	for entry: MoodFace in faces_row.faces:
		if entry.filled:
			return entry
	return null


func mood_color() -> Color:
	return MoodFace.GUILD_COLORS[clampi(opinion, MIN_OPINION, MAX_OPINION) - MIN_OPINION]


func _refresh() -> void:
	if not is_node_ready():
		return
	title_label.text = TITLE
	caption_label.text = CAPTION
	caption_label.add_theme_color_override("font_color", mood_color())
	value_label.text = VALUE_TEXT % opinion
	faces_row.opinion = opinion
	portrait_box.queue_redraw()
	queue_redraw()


static func _card_box() -> StyleBoxFlat:
	var box: StyleBoxFlat = GuiStyle.flat(PANEL_FILL, 0, GuiColors.CLEAR, 10.0)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	return box


#StyleBoxFlat carries one border colour, so the two edges are drawn over the panel instead.
func _draw() -> void:
	BevelButton.paint_edges(self, Rect2(Vector2.ZERO, size), LEFT_EDGE_COLOR, mood_color(), EDGE_PX,
		BevelButton.BEVEL_LEFT | BevelButton.BEVEL_BOTTOM)


func _draw_portrait() -> void:
	EquipSlot.draw_hatch_box(portrait_box, EquipSlot.ICON_FILL, LEFT_EDGE_COLOR)
