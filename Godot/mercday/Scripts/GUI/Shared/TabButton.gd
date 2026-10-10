class_name TabButton extends BevelButton

#One tab of the Merc Viewer's tab bar. The active tab widens and shows its label; the rest stay
#52 px icon squares. The icon rides an IconRect child that draws one atlas id.
#lit tints the idle icon orange (new mail); the active tab keeps its two tone paint.

const ACTIVE_HEIGHT: int = 44
const IDLE_SIZE: Vector2 = Vector2(52, 38)
const HI_ACTIVE: Color = GuiColors.ORANGE_HI
const TEXT_ACTIVE: Color = GuiColors.INK
const TEXT_IDLE: Color = GuiColors.CREAM
#a tab that carries a label and no icon needs room for the word
const LABEL_PAD: float = 16.0
const BADGE_BG: Color = GuiColors.GREEN
const BADGE_TEXT: Color = GuiColors.INK
const LOCK_SCALE: int = 3
const LIT_TINT: Color = GuiColors.ORANGE

signal tab_pressed(index: int)

@export var label: String = "":
	set(value):
		label = value
		_refresh()
@export var description: String = "":
	set(value):
		description = value
		_refresh()
#The idle look is the kind palette in the colour exports; the active look swaps in the orange set.
@export var active: bool = false:
	set(value):
		active = value
		if active:
			set_colors(GuiColors.ORANGE, HI_ACTIVE, GuiColors.ORANGE_LO, TEXT_ACTIVE)
		else:
			apply_palette(kind)
		_refresh()
@export var index: int = 0
#Tabs that carry no icon keep their label up in both states.
@export var label_always: bool = false:
	set(value):
		label_always = value
		_refresh()
#The icon box is icon_cols * icon_px pixels square. A non-integer icon_px still works because
#the box size is forced here instead of riding IconRect's own integer pixel_scale.
@export var icon_cols: int = 12:
	set(value):
		icon_cols = value
		_refresh()
@export var icon_px: float = 2.0:
	set(value):
		icon_px = value
		_refresh()
#An atlas id fills the icon box with one 16 px cell at icon_scale; with none the box stays hidden.
@export var icon_id: String = "":
	set(value):
		icon_id = value
		_refresh()
@export var icon_scale: int = 2:
	set(value):
		icon_scale = maxi(1, value)
		_refresh()
#The tint mode an idle atlas tab draws in; the active tab always takes the two tone paint.
@export var idle_mode: StringName = Icons.MODE_PLAIN:
	set(value):
		idle_mode = value
		_refresh()
#Draws the lock glyph over the icon; the tab still emits tab_pressed so its owner can answer
#with a LockedPage or a FeatureLockDialog instead of the real screen.
@export var locked: bool = false:
	set(value):
		locked = value
		_refresh()
#A count pill top-right; 0 hides it. Exclusive with dot.
@export var badge: int = 0:
	set(value):
		badge = value
		_refresh()
#A NotificationDot top-right; exclusive with badge.
@export var dot: bool = false:
	set(value):
		dot = value
		_refresh()
#Tints the idle icon LIT_TINT (unread mail in the folder); the active tab ignores it.
@export var lit: bool = false:
	set(value):
		lit = value
		_refresh()
#The badge pill colour. Defaults to BADGE_BG so every tab of today keeps its look.
@export var badge_color: Color = BADGE_BG:
	set(value):
		badge_color = value
		_refresh_badge_style()

#The closed tab size; a subclass sets its own before _ready.
var idle_size: Vector2 = IDLE_SIZE

@onready var icon_rect: IconRect = $Row/Icon
@onready var text_label: Label = $Row/Text
@onready var lock_overlay: TextureRect = $Row/Icon/LockOverlay
@onready var badge_panel: PanelContainer = $Badge
@onready var badge_label: Label = $Badge/BadgeText
@onready var dot_node: NotificationDot = $Dot


func _init() -> void:
	click_move = ButtonFx.ClickMove.NONE
	click_shade = ButtonFx.ClickShade.FLASH
	hover_move = ButtonFx.HoverMove.NONE
	hover_shade = ButtonFx.HoverShade.LIGHTEN
	stay_move = ButtonFx.StayMove.NONE
	stay_shade = ButtonFx.StayShade.NONE
	active_move = ButtonFx.HoverMove.NONE
	active_shade = ButtonFx.HoverShade.RING


func _ready() -> void:
	super()
	pressed.connect(_on_pressed)
	expand_icon = false
	_refresh_badge_style()
	badge_label.add_theme_color_override("font_color", BADGE_TEXT)
	lock_overlay.texture_filter = TEXTURE_FILTER_NEAREST
	lock_overlay.texture = Icons.baked("lock", LOCK_SCALE, Icons.MODE_PLAIN, true)
	lock_overlay.modulate = GuiColors.LOCK_GOLD
	dot_node.pin(Vector2(2, 2))
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	text = ""
	text_label.text = label
	text_label.visible = active or label_always
	text_label.add_theme_color_override("font_color", TEXT_ACTIVE if active else TEXT_IDLE)
	if icon_id != "":
		icon_rect.set_id(icon_id, icon_scale, Icons.MODE_TWO_TONE if active else idle_mode)
		icon_rect.tint = LIT_TINT if lit and not active else Color.WHITE
		icon_rect.visible = true
	else:
		icon_rect.visible = false
		var box: float = float(icon_cols) * icon_px
		icon_rect.custom_minimum_size = Vector2(box, box)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_layout_lock_overlay()
	lock_overlay.visible = locked and icon_id != ""
	tooltip_text = "Locked" if locked else description
	theme_type_variation = &"TabActive" if active else &"TabIdle"
	size_flags_vertical = SIZE_SHRINK_END
	if active:
		size_flags_horizontal = SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(idle_size.x, ACTIVE_HEIGHT)
	elif label_always:
		size_flags_horizontal = SIZE_FILL
		var wide: float = text_label.get_combined_minimum_size().x + LABEL_PAD
		custom_minimum_size = Vector2(maxf(idle_size.x, wide), idle_size.y)
	else:
		size_flags_horizontal = SIZE_FILL
		custom_minimum_size = idle_size
	badge_label.text = str(badge)
	badge_panel.visible = badge > 0 and not dot
	dot_node.on = dot
	queue_redraw()


func _layout_lock_overlay() -> void:
	var art: Vector2i = Icons.size("lock") * LOCK_SCALE
	var w: float = float(art.x)
	var h: float = float(art.y)
	lock_overlay.anchor_left = 0.5
	lock_overlay.anchor_top = 0.5
	lock_overlay.anchor_right = 0.5
	lock_overlay.anchor_bottom = 0.5
	lock_overlay.offset_left = -floorf(w / 2.0)
	lock_overlay.offset_top = -floorf(h / 2.0)
	lock_overlay.offset_right = w - floorf(w / 2.0)
	lock_overlay.offset_bottom = h - floorf(h / 2.0)


func _badge_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = GuiStyle.flat(badge_color, 0, GuiColors.CLEAR, 1.0)
	style.set_corner_radius_all(6)
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	return style


func _refresh_badge_style() -> void:
	if not is_node_ready():
		return
	badge_panel.add_theme_stylebox_override(&"panel", _badge_style())


func fx_active() -> bool:
	return super() or active


func _on_pressed() -> void:
	tab_pressed.emit(index)
