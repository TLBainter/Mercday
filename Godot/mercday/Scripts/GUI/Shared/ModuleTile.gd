class_name ModuleTile extends BevelButton

#One picker module of a mods filter section, drawn as a fixed square: the image top left, the checkbox top
#right with the relationship face under it, the module name, then the Received / Completed / Failed counts
#or the blocked note in their place. A module with a disabled_reason stays visible but dim and inert.

signal pressed_tile(key: Variant)

const IMAGE_PX: float = 64.0
const CHECK_PX: float = 16.0
const TILE_SIDE: float = 152.0
const PAD_PX: float = 8.0
const NAME_SIZE: int = 11
const NOTE_SIZE: int = 11
const STAT_LABEL_SIZE: int = 7
const STAT_VALUE_SIZE: int = 10
const IMAGE_LABEL_SIZE: int = 7
const BLOCKED_ALPHA: float = 0.4
#Stands for a module that carries no relationship at all, so neither the face nor the lock shows.
const NO_RELATION: int = -2147483648
const STAT_LABELS: Array[String] = ["Received", "Completed", "Failed"]
const STAT_COLORS: Array[Color] = [GuiColors.CREAM, GuiColors.GREEN, GuiColors.RED]
const REL_UPGRADE_ID: String = "customer"
const REL_ENTITLEMENT: String = "clientOpinion"
const REL_FEATURE: String = "Relationships"
const FACE_SCALE: int = 2
#The side of the face slot; the lock of a closed relationship fills the same square.
const FACE_PX: float = MoodFace.FACE_ART.y * float(FACE_SCALE)
const LABEL_COLOR: Color = GuiColors.SKY
const NAME_COLOR: Color = GuiColors.CREAM
const NOTE_COLOR: Color = GuiColors.RED
const IMAGE_LABEL_COLOR: Color = GuiColors.MUTED
const STYLE_STAT: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/filter_tile_stat.tres")
const STYLE_CHECK_ON: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/filter_check_on.tres")
const STYLE_CHECK_OFF: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/filter_check_off.tres")
const FONT_LABEL: Font = GuiStyle.SILK
const FONT_VALUE: Font = GuiStyle.SILK_BOLD
const FONT_NOTE: Font = GuiStyle.BODY
const LOCK_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/FeatureLock.tscn")

@export var label: String = ""
@export var image: Texture2D = null
#The placeholder caption a module without art shows inside its image box.
@export var image_note: String = ""
@export var received: int = 0
@export var completed: int = 0
@export var failed: int = 0
@export var relationship: int = NO_RELATION
#False shows the upgrade lock in the face slot instead of the relationship face.
@export var relationship_open: bool = true
#Non empty means the module cannot be picked; the text shows as the note and the tooltip.
@export var disabled_reason: String = ""
#A single pick module tells the section to replace the pick instead of adding to it.
@export var single: bool = false
@export var selected: bool = false

#What the section stores when this module is picked.
var key: Variant = null

@onready var rows: VBoxContainer = $Rows
@onready var image_box: PanelContainer = $Rows/Top/ImageBox
@onready var image_label: Label = $Rows/Top/ImageBox/ImageLabel
@onready var image_rect: TextureRect = $Rows/Top/ImageBox/Image
@onready var stats: VBoxContainer = $Rows/Stats
@onready var side_box: VBoxContainer = $Rows/Top/Side
@onready var check_box: Panel = $Rows/Top/Side/Check
@onready var check_mark: TextureRect = $Rows/Top/Side/Check/Mark
@onready var name_label: Label = $Rows/TileName
@onready var note_label: Label = $Rows/Note

var _stat_values: Array[Label] = []
var _face: MoodFace = null
var _rel_lock: FeatureLock = null


func _init() -> void:
	fill = GuiColors.ROW_FILL
	click_move = ButtonFx.ClickMove.SHRINK
	click_shade = ButtonFx.ClickShade.FLASH
	hover_move = ButtonFx.HoverMove.LIFT
	hover_shade = ButtonFx.HoverShade.GLOW
	stay_move = ButtonFx.StayMove.NONE
	stay_shade = ButtonFx.StayShade.NONE
	active_move = ButtonFx.HoverMove.NONE
	active_shade = ButtonFx.HoverShade.RING


func _ready() -> void:
	super()
	custom_minimum_size = Vector2(TILE_SIDE, TILE_SIDE)
	focus_mode = Control.FOCUS_NONE
	text = ""
	image_box.custom_minimum_size = Vector2(IMAGE_PX, IMAGE_PX)
	check_box.custom_minimum_size = Vector2(CHECK_PX, CHECK_PX)
	check_mark.texture = GuiGlyphs.check(GuiColors.INK)
	GuiStyle.paint(name_label, FONT_VALUE, NAME_SIZE, NAME_COLOR)
	GuiStyle.paint(note_label, FONT_NOTE, NOTE_SIZE, NOTE_COLOR)
	GuiStyle.paint(image_label, FONT_LABEL, IMAGE_LABEL_SIZE, IMAGE_LABEL_COLOR)
	_build_stats()
	_build_side()
	#Deferred so the face and lock rules land after the lock's own refresh on a subscription change.
	SubscriptionManager.changed.connect(refresh, CONNECT_DEFERRED)
	pressed.connect(press_tile)
	refresh()


func _exit_tree() -> void:
	if SubscriptionManager.changed.is_connected(refresh):
		SubscriptionManager.changed.disconnect(refresh)


func is_blocked() -> bool:
	return disabled_reason != ""


#The press path a headless test takes; a blocked module never reports a press.
func press_tile() -> void:
	if is_blocked():
		return
	pressed_tile.emit(key)


func set_selected(on: bool) -> void:
	selected = on
	refresh()


func fx_active() -> bool:
	return super() or selected


func relationship_lock() -> FeatureLock:
	return _rel_lock


func relationship_face() -> MoodFace:
	return _face


func refresh() -> void:
	if not is_node_ready():
		return
	if selected:
		set_colors(fill, GuiColors.ORANGE, GuiColors.ORANGE_LO, text_color)
	else:
		set_colors(fill, GuiColors.BLUE_LO, GuiColors.ROW_EDGE_LO, text_color)
	modulate.a = BLOCKED_ALPHA if is_blocked() else 1.0
	var inert: bool = is_blocked()
	click_move = ButtonFx.ClickMove.NONE if inert else ButtonFx.ClickMove.SHRINK
	click_shade = ButtonFx.ClickShade.NONE if inert else ButtonFx.ClickShade.FLASH
	hover_move = ButtonFx.HoverMove.NONE if inert else ButtonFx.HoverMove.LIFT
	hover_shade = ButtonFx.HoverShade.NONE if inert else ButtonFx.HoverShade.GLOW
	hover_fill = fill if inert else GuiColors.CLEAR
	pressed_fill = fill if inert else GuiColors.CLEAR
	mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if is_blocked() \
		else Control.CURSOR_POINTING_HAND
	tooltip_text = disabled_reason
	check_box.add_theme_stylebox_override(&"panel", STYLE_CHECK_ON if selected else STYLE_CHECK_OFF)
	check_mark.visible = selected
	image_rect.texture = image
	image_rect.visible = image != null
	image_label.visible = image == null
	image_label.text = image_note
	name_label.text = label
	note_label.text = disabled_reason
	note_label.visible = is_blocked()
	stats.visible = not is_blocked()
	var counts: Array[int] = [received, completed, failed]
	for i: int in range(_stat_values.size()):
		_stat_values[i].text = str(counts[i])
	var related: bool = relationship != NO_RELATION
	_face.visible = related and relationship_open
	_rel_lock.visible = related and not relationship_open
	if related:
		_face.opinion = relationship


func _build_stats() -> void:
	for i: int in range(STAT_LABELS.size()):
		var panel: PanelContainer = _stat_panel(STAT_LABELS[i])
		var value: Label = _value_label()
		value.add_theme_color_override(&"font_color", STAT_COLORS[i])
		(panel.get_child(0) as HBoxContainer).add_child(value)
		_stat_values.append(value)


func _build_side() -> void:
	_face = MoodFace.new()
	_face.name = "Face"
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.guild = true
	_face.pixel_scale = FACE_SCALE
	side_box.add_child(_face)
	_rel_lock = LOCK_SCENE.instantiate() as FeatureLock
	_rel_lock.name = "Lock"
	_rel_lock.size_flags_horizontal = Control.SIZE_SHRINK_END
	side_box.add_child(_rel_lock)
	_rel_lock.feature = REL_FEATURE
	_rel_lock.upgrade = UpgradeDefs.name_of(REL_UPGRADE_ID)
	_rel_lock.upgrade_id = REL_UPGRADE_ID
	_rel_lock.entitlement = REL_ENTITLEMENT
	_rel_lock.tier = 1
	_rel_lock.tiers = 1
	_rel_lock.verb = "view"
	_rel_lock.label = ""
	_rel_lock.height = FACE_PX
	_rel_lock.min_width = FACE_PX
	_rel_lock.always_visible = true


func _stat_panel(row_name: String) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = row_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(&"panel", STYLE_STAT)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 4)
	panel.add_child(row)
	var key_label: Label = Label.new()
	key_label.name = "Key"
	key_label.text = row_name
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GuiStyle.paint(key_label, FONT_LABEL, STAT_LABEL_SIZE, LABEL_COLOR)
	key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(key_label)
	stats.add_child(panel)
	return panel


func _value_label() -> Label:
	var value: Label = Label.new()
	value.name = "Value"
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.add_theme_font_override(&"font", FONT_VALUE)
	value.add_theme_font_size_override(&"font_size", STAT_VALUE_SIZE)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return value
