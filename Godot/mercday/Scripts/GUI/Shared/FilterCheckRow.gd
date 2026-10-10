class_name FilterCheckRow extends BevelButton

#One labelled check box in a filter popup: an orange ticked box or an empty pale box drawn at the
#left of the row, an optional atlas icon after it, the label held clear of both by the style's left margin.

const BOX_SIZE: float = 16.0
const BOX_LEFT: float = 2.0
const BORDER: float = 2.0
const TEXT_MARGIN: float = 27.0
const ICON_ROOM: float = 22.0
const ROW_SCENE_PATH: String = "res://Scenes/GUI/Shared/FilterCheckRow.tscn"
const ON_FILL: Color = GuiColors.ORANGE
const ON_BORDER: Color = GuiColors.ORANGE_LO
const OFF_FILL: Color = Color("#d9dee8")
const OFF_BORDER: Color = Color("#b9c2cf")
const CHECK_COLOR: Color = GuiColors.CREAM
const ROW_FONT: FontVariation = GuiStyle.BODY
const ROW_FONT_SIZE: int = 14
const ROW_COLOR: Color = GuiColors.CREAM
const HOVER_COLOR: Color = GuiColors.ORANGE
const BORDER_HOT_OFF: Color = GuiColors.ORANGE
const BORDER_HOT_ON: Color = GuiColors.ORANGE_HI

@export var label: String = "":
	set(value):
		label = value
		_refresh()
@export var on: bool = true:
	set(value):
		on = value
		if is_node_ready():
			button_pressed = value
		queue_redraw()
@export var icon_id: String = "":
	set(value):
		icon_id = value
		if is_node_ready():
			_apply_style()
		queue_redraw()


func _init() -> void:
	kind = &"neutral"
	pressed_fill = fill
	click_move = ButtonFx.ClickMove.SHRINK
	click_shade = ButtonFx.ClickShade.FLASH
	hover_move = ButtonFx.HoverMove.NONE
	hover_shade = ButtonFx.HoverShade.LIGHTEN
	stay_move = ButtonFx.StayMove.NONE
	stay_shade = ButtonFx.StayShade.NONE
	active_move = ButtonFx.HoverMove.NONE
	active_shade = ButtonFx.HoverShade.RING


func _ready() -> void:
	super()
	_apply_style()
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button_pressed = on
	toggled.connect(_on_toggled)
	mouse_entered.connect(_light.bind(true))
	mouse_exited.connect(_light.bind(false))
	_light(false)
	_refresh()


#One row from FilterCheckRow.tscn (make is BevelButton's); the caller adds it where it belongs and connects toggled.
static func make_check(row_label: String, is_on: bool, row_icon: String = "") -> FilterCheckRow:
	var scene: PackedScene = load(ROW_SCENE_PATH) as PackedScene
	var row: FilterCheckRow = scene.instantiate() as FilterCheckRow
	row.label = row_label
	row.on = is_on
	row.icon_id = row_icon
	return row


#The box border turns orange under the pointer, brighter on a ticked box.
static func border_for(is_on: bool, hot: bool) -> Color:
	if hot:
		return BORDER_HOT_ON if is_on else BORDER_HOT_OFF
	return ON_BORDER if is_on else OFF_BORDER


func _draw_face(rect: Rect2) -> void:
	super(rect)
	var box := Rect2(rect.position.x + BOX_LEFT, rect.position.y + (rect.size.y - BOX_SIZE) / 2.0,
		BOX_SIZE, BOX_SIZE)
	var hot: bool = is_hovered() and not disabled
	draw_rect(box, border_for(on, hot))
	draw_rect(box.grow(-BORDER), ON_FILL if on else OFF_FILL)
	if icon_id != "":
		Icons.draw(self, icon_id, Vector2(rect.position.x + TEXT_MARGIN,
			rect.position.y + (rect.size.y - Icons.CELL) / 2.0))
	if not on:
		return
	var tex: Texture2D = GuiGlyphs.check(CHECK_COLOR)
	draw_texture(tex, (box.position + (box.size - tex.get_size()) / 2.0).floor())


func _on_toggled(now_on: bool) -> void:
	on = now_on


func _refresh() -> void:
	if not is_node_ready():
		return
	text = label
	queue_redraw()


#Every state shares the base's empty box, so the left margin keeps the label clear of the check.
func _apply_style() -> void:
	var box: StyleBox = get_theme_stylebox(&"normal")
	box.content_margin_left = TEXT_MARGIN + (ICON_ROOM if icon_id != "" else 0.0)
	box.content_margin_top = 2.0
	box.content_margin_bottom = 2.0
	add_theme_font_override("font", ROW_FONT)
	add_theme_font_size_override("font_size", ROW_FONT_SIZE)


#The label is cream at rest and orange under the pointer, ticked or not; a caller's tint never shows.
func _light(hot: bool) -> void:
	text_color = HOVER_COLOR if hot and not disabled else ROW_COLOR
