class_name CheckRow extends HBoxContainer

#One "included feature" line: the atlas check mark plus a wrapping label. It carries no
#input, so it never takes the mouse; plan cards and tooltips add one row per feature.

const MARK_PX: int = 12
const DEFAULT_COLOR: Color = GuiColors.GREEN
const TEXT_COLOR: Color = GuiColors.CREAM
const FONT_SIZE: int = 14
const ROW_SEPARATION: int = 10

@export var text: String = "":
	set(value):
		text = value
		_refresh()
@export var checked: bool = true:
	set(value):
		checked = value
		_refresh()
@export var color: Color = DEFAULT_COLOR:
	set(value):
		color = value
		_refresh()

@onready var mark: TextureRect = $MarkPad/Mark
@onready var text_label: Label = $Text


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", ROW_SEPARATION)
	mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.custom_minimum_size = Vector2.ONE * float(MARK_PX)
	text_label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	text_label.add_theme_color_override(&"font_color", TEXT_COLOR)
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	text_label.text = text
	mark.texture = Icons.tinted("check_sm", color, 1, false,
		Icons.centered_box(MARK_PX, MARK_PX))
	mark.visible = checked
