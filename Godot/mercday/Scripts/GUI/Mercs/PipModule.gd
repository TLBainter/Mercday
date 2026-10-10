class_name PipModule extends PanelContainer

#One level-up mode in the CoachDialog: the mode's icon in a dark box beside its name. Three states,
#all from the prototype: selected carries the orange ring, idle the blue one, and a locked row goes
#flat with a FeatureLock at the right that names the upgrade the mode's gate needs. The row is a
#panel with a flat Button under it so the lock keeps its own press, and the lock's own hover asks
#the dialog to drop the module tooltip.

signal picked(mode: StringName)
signal hover_started(module: PipModule)
signal hover_ended

const MODULE_HEIGHT: float = 44.0
const ICON_BOX: Vector2 = Vector2(30.0, 30.0)
const ICON_PX: int = 3
const PAD_LEFT: int = 8
const PAD_RIGHT: int = 10
const SELECTED_BG: Color = GuiColors.ROW_HOVER
const SELECTED_RING: Color = GuiColors.ORANGE
const SELECTED_RING_PX: int = 3
const IDLE_BG: Color = GuiColors.ROW_FILL
const IDLE_RING: Color = GuiColors.BLUE
const IDLE_RING_PX: int = 2
const LOCKED_BG: Color = GuiColors.FRAME_BG
const LOCKED_RING: Color = GuiColors.BLUE_LO
const LOCKED_ICON: Color = GuiColors.LOCK_RING
const LOCKED_NAME: Color = GuiColors.MUTED
const NAME_COLOR: Color = GuiColors.CREAM
const ICON_BG: Color = GuiColors.INK
const TAG_BG: Color = GuiColors.SKY
const TAG_TEXT: Color = GuiColors.INK
const CURRENT_TAG: String = "Current"
const CURRENT_FOOT: String = "Current plan"

@export var mode: StringName = &"":
	set(value):
		mode = value
		_refresh()
#The 8 x 8 colour art of the mode, baked at ICON_PX.
@export var icon: Texture2D = null:
	set(value):
		icon = value
		_refresh()
var _locked_art: Texture2D = null
@export var group_color: Color = GuiColors.SKY:
	set(value):
		group_color = value
		_refresh()
@export var description: String = ""
@export var selected: bool = false:
	set(value):
		selected = value
		_refresh()
@export var is_current: bool = false:
	set(value):
		is_current = value
		_refresh()
@export var locked: bool = false:
	set(value):
		locked = value
		_refresh()

@onready var hit: Button = $Hit
@onready var icon_box: Panel = $Pad/Row/IconBox
@onready var icon_rect: TextureRect = $Pad/Row/IconBox/Icon
@onready var name_label: Label = $Pad/Row/Name
@onready var lock_holder: HBoxContainer = $Pad/Row/LockHolder
@onready var tag: PanelContainer = $TagLayer/Tag
@onready var tag_label: Label = $TagLayer/Tag/TagText

var lock: FeatureLock = null


func _ready() -> void:
	custom_minimum_size.y = MODULE_HEIGHT
	hit.pressed.connect(press)
	hit.mouse_entered.connect(_on_hit_entered)
	hit.mouse_exited.connect(_on_hit_exited)
	icon_box.add_theme_stylebox_override(&"panel", _icon_style())
	tag.add_theme_stylebox_override(&"panel", _tag_style())
	tag_label.add_theme_color_override("font_color", TAG_TEXT)
	tag_label.text = CURRENT_TAG
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_refresh()


#Fills the row from one PipDefs entry and the entitlements that decide its gate.
func set_row(data: Dictionary, ent: Dictionary) -> void:
	if data.is_empty():
		return
	var key: StringName = StringName(data["mode"])
	description = String(data.get("desc", ""))
	group_color = PipDefs.group_color(String(data.get("group", "")))
	icon = MercGlyphs.pip(key)
	_locked_art = MercGlyphs.pip_locked(key)
	locked = not PipDefs.unlocked(key, ent)
	mode = key


#The name the tooltip carries.
func mode_text() -> String:
	return String(mode)


func group_title() -> String:
	return PipDefs.group_of(mode)


func foot_text() -> String:
	return CURRENT_FOOT if is_current else ""


#A locked module never answers a press; the FeatureLock beside it sells the upgrade instead.
func press() -> void:
	if locked:
		return
	picked.emit(mode)


func lock_hover_enter() -> void:
	hover_ended.emit()


func lock_hover_exit() -> void:
	hover_started.emit(self)


func _on_hit_entered() -> void:
	hover_started.emit(self)


func _on_hit_exited() -> void:
	hover_ended.emit()


#The lock lives beside the name only while the mode's gate is shut. It is made once and then kept
#in step with the mode, so a state change never churns the node.
func _sync_lock() -> void:
	if not is_node_ready():
		return
	lock_holder.visible = locked
	if not locked:
		return
	if lock == null:
		var scene: PackedScene = load(MercLocks.LOCK_SCENE_PATH) as PackedScene
		if scene == null:
			lock_holder.visible = false
			return
		lock = scene.instantiate() as FeatureLock
		lock_holder.add_child(lock)
		lock.mouse_entered.connect(lock_hover_enter)
		lock.mouse_exited.connect(lock_hover_exit)
	lock.feature = PipDefs.feature_of(mode)
	lock.plan = MercLocks.ENTERPRISE
	lock.entitlement = String(PipDefs.find(mode).get("gate", ""))
	lock.upgrade = PipDefs.upgrade_name(mode)
	lock.upgrade_id = PipDefs.upgrade_id(mode)
	lock.tier = maxi(1, PipDefs.upgrade_tier(mode))
	lock.tiers = PipDefs.upgrade_tiers(mode)
	lock.verb = "view"
	lock.height = MercLocks.LOCK_HEIGHT
	lock.always_visible = true


func _refresh() -> void:
	if not is_node_ready():
		return
	name_label.text = String(mode)
	icon_rect.texture = _locked_art if locked and _locked_art != null else icon
	icon_rect.modulate = LOCKED_ICON if locked else Color.WHITE
	var tint: Color = NAME_COLOR
	if locked:
		tint = LOCKED_NAME
	elif selected:
		tint = SELECTED_RING
	name_label.add_theme_color_override("font_color", tint)
	add_theme_stylebox_override(&"panel", _panel_style())
	tag.visible = is_current and not locked
	#The hit stays live while locked so the module keeps its own hover tooltip.
	var shape: int = Control.CURSOR_POINTING_HAND
	if locked:
		shape = Control.CURSOR_FORBIDDEN
	hit.mouse_default_cursor_shape = shape as Control.CursorShape
	_sync_lock()


func _panel_style() -> StyleBoxFlat:
	var bg: Color = IDLE_BG
	var ring: Color = IDLE_RING
	var width: int = IDLE_RING_PX
	if locked:
		bg = LOCKED_BG
		ring = LOCKED_RING
	elif selected:
		bg = SELECTED_BG
		ring = SELECTED_RING
		width = SELECTED_RING_PX
	var style: StyleBoxFlat = GuiStyle.flat(bg, width, ring, 0.0)
	style.content_margin_left = float(PAD_LEFT)
	style.content_margin_right = float(PAD_RIGHT)
	return style


func _icon_style() -> StyleBoxFlat:
	return GuiStyle.flat(ICON_BG)


func _tag_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = GuiStyle.flat(TAG_BG, 0, GuiColors.CLEAR, 1.0)
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	return style
