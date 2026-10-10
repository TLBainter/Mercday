class_name GridMenuButton extends BevelButton

#A 160x160 dashboard tile: an icon over a label strip. Named GridMenuButton because MenuButton
#is a built-in Godot class (SCENES.md calls this atom MenuButton). locked greys the tile out and
#swaps its click for locked_pressed; dot adds a NotificationDot above or below the lock badge.

signal opened(scene: PackedScene)
signal locked_pressed

const HOVER_COLOR := GuiColors.ORANGE
const NORMAL_COLOR := GuiColors.CREAM
const GRAY_TINT: Color = GuiColors.GREY_TINT
const LOCK_BADGE_SIZE: Vector2 = Vector2(36, 40)
const LOCK_BADGE_INSET: Vector2 = Vector2(10, 10)
const DOT_INSET: float = 2.0
const LOCK_ICON_SCALE: int = 4
const DOT_GAP: float = 4.0

#icon is inherited from Button (redeclaring it errors: "Member icon redefined"). set_icon()
#below forwards a texture to the child IconRect, then clears the inherited field so Button
#never draws its own small icon over this tile.
@export var label: String = "":
	set(value):
		label = value
		_refresh()
@export var window_scene: PackedScene = null
@export var description: String = "":
	set(value):
		description = value
		_refresh()
@export var locked: bool = false:
	set(value):
		locked = value
		_refresh()
@export var locked_tooltip: String = "":
	set(value):
		locked_tooltip = value
		_refresh()
@export var dot: bool = false:
	set(value):
		dot = value
		_refresh()

@onready var icon_rect: IconRect = $Icon
@onready var text_label: Label = $Strip/Text
@onready var lock_badge: PanelContainer = $LockBadge
@onready var lock_icon: TextureRect = $LockBadge/LockIcon
@onready var dot_node: NotificationDot = $Dot

var _hovered: bool = false


func _init() -> void:
	click_sfx = preload("res://Resources/Audio/Libraries/big_button_click.tres")
	click_move = ButtonFx.ClickMove.POP
	click_shade = ButtonFx.ClickShade.FLASH
	hover_move = ButtonFx.HoverMove.LIFT
	hover_shade = ButtonFx.HoverShade.GLOW
	stay_move = ButtonFx.StayMove.NONE
	stay_shade = ButtonFx.StayShade.NONE
	active_move = ButtonFx.HoverMove.NONE
	active_shade = ButtonFx.HoverShade.RING


func _ready() -> void:
	super()
	mouse_entered.connect(func() -> void: hover(true))
	mouse_exited.connect(func() -> void: hover(false))
	pressed.connect(_on_pressed)
	if icon != null:
		set_icon(icon)
	lock_badge.add_theme_stylebox_override(&"panel", _lock_badge_style())
	lock_icon.texture = GuiGlyphs.lock(GuiColors.LOCK_GOLD, LOCK_ICON_SCALE)
	_refresh()


func _on_pressed() -> void:
	if locked:
		locked_pressed.emit()
		return
	opened.emit(window_scene)


#Test seam: a headless synthetic click never reaches a Button, so a test presses here.
func press() -> void:
	if disabled:
		return
	pressed.emit()


func _refresh() -> void:
	if not is_node_ready():
		return
	text_label.text = label
	tooltip_text = locked_tooltip if locked else description
	icon_rect.tint = GRAY_TINT if locked else Color.WHITE
	text_label.add_theme_color_override("font_color",
		GuiColors.LOCKED_TEXT if locked else (HOVER_COLOR if _hovered else NORMAL_COLOR))
	if locked:
		set_colors(GuiColors.LOCKED_BG, GuiColors.LOCKED_HI, GuiColors.LOCKED_LO, GuiColors.LOCKED_TEXT)
	else:
		apply_palette(kind)
	_position_indicators()


func set_icon(tex: Texture2D) -> void:
	icon_rect.set_icon(tex)
	icon = null


func hover(on: bool) -> void:
	_hovered = on
	if not locked:
		text_label.add_theme_color_override("font_color", HOVER_COLOR if on else NORMAL_COLOR)


func caption_color() -> Color:
	return text_label.get_theme_color("font_color")


#Lock badge sits inset from the top-right corner; the dot sits at that same corner when the
#badge is hidden, or a gap below it when both show.
func _position_indicators() -> void:
	lock_badge.visible = locked
	lock_badge.anchor_left = 1.0
	lock_badge.anchor_top = 0.0
	lock_badge.anchor_right = 1.0
	lock_badge.anchor_bottom = 0.0
	lock_badge.offset_right = -LOCK_BADGE_INSET.x
	lock_badge.offset_left = lock_badge.offset_right - LOCK_BADGE_SIZE.x
	lock_badge.offset_top = LOCK_BADGE_INSET.y
	lock_badge.offset_bottom = lock_badge.offset_top + LOCK_BADGE_SIZE.y
	var top: float = lock_badge.offset_bottom + DOT_GAP if locked else DOT_INSET
	dot_node.pin(Vector2(DOT_INSET, top))
	dot_node.on = dot


func _lock_badge_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = GuiColors.INK
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = GuiColors.LOCK_RING
	var art: Vector2i = Icons.size("lock") * LOCK_ICON_SCALE
	var badge_pad_x: float = (LOCK_BADGE_SIZE.x - float(art.x)) / 2.0
	var badge_pad_y: float = (LOCK_BADGE_SIZE.y - float(art.y)) / 2.0
	style.content_margin_left = badge_pad_x
	style.content_margin_right = badge_pad_x
	style.content_margin_top = badge_pad_y
	style.content_margin_bottom = badge_pad_y
	return style

