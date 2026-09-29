class_name LockedPage extends Control

#A full locked-screen overlay: a dimmed backing over the whole view with a centred panel
#carrying the same copy rule as FeatureLock. Unlike FeatureLockDialog this is not a modal the
#guild dismisses; the parent view shows or hides it as a page state.

signal take_me_there(target: Dictionary)

const BG_COLOR: Color = Color(0.023529, 0.039216, 0.078431, 0.84)
const PANEL_WIDTH: float = 520.0
const PANEL_BORDER: int = 4
const PANEL_BG: Color = Color("#1a2b4d")
const PANEL_EDGE: Color = Color("#f2d33d")
const ICON_SCALE: int = 6

@export var feature: String = "":
	set(value):
		feature = value
		_refresh()
@export var plan: String = "Mercday Pro":
	set(value):
		plan = value
		_refresh()
@export var verb: String = "view":
	set(value):
		verb = value
		_refresh()
@export var upgrade: String = "":
	set(value):
		upgrade = value
		_refresh()
@export var upgrade_id: String = "":
	set(value):
		upgrade_id = value
		_refresh()
@export var tier: int = 1:
	set(value):
		tier = value
		_refresh()
@export var tiers: int = 1:
	set(value):
		tiers = value
		_refresh()

@onready var backing: ColorRect = $Backing
@onready var panel: PanelContainer = $Panel
@onready var lock_icon: TextureRect = $Panel/Pad/Rows/IconRow/LockIcon
@onready var line1_label: Label = $Panel/Pad/Rows/Line1
@onready var line2_label: Label = $Panel/Pad/Rows/Line2
@onready var take_me_there_button: Button = $Panel/Pad/Rows/Buttons/TakeMeThere


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	backing.set_anchors_preset(Control.PRESET_FULL_RECT)
	backing.color = BG_COLOR
	backing.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_width_left = PANEL_BORDER
	style.border_width_top = PANEL_BORDER
	style.border_width_right = PANEL_BORDER
	style.border_width_bottom = PANEL_BORDER
	style.border_color = PANEL_EDGE
	panel.add_theme_stylebox_override(&"panel", style)
	panel.custom_minimum_size.x = PANEL_WIDTH
	lock_icon.texture = GuiGlyphs.lock(PANEL_EDGE, ICON_SCALE)
	lock_icon.custom_minimum_size = Vector2(GuiGlyphs.LOCK_COLS, GuiGlyphs.LOCK_ROWS) * float(ICON_SCALE)
	take_me_there_button.pressed.connect(press_take_me_there)
	resized.connect(_center_panel)
	_refresh()
	_center_panel()


#The Plans tab, or the Customize upgrade target when the guild already holds Enterprise.
func target() -> Dictionary:
	if SubscriptionManager.plan() == SubscriptionManager.Plan.ENTERPRISE and upgrade_id != "":
		return {"tab": "customize", "upgrade": upgrade_id, "tier": tier}
	return {"tab": "plans"}


func press_take_me_there() -> void:
	var t: Dictionary = target()
	GameState.go_to_plans(t)
	take_me_there.emit(t)


func _refresh() -> void:
	if not is_node_ready():
		return
	var lines: Array[String] = FeatureLock.build_copy(feature, plan, upgrade, upgrade_id, tier, tiers, verb)
	line1_label.text = lines[0]
	line2_label.text = lines[1]


func _center_panel() -> void:
	panel.reset_size()
	panel.position = ((size - panel.size) / 2.0).round()
