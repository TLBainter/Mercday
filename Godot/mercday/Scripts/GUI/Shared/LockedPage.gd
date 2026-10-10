class_name LockedPage extends Control

#A full locked-screen overlay: a dimmed backing over the whole view with a centred panel
#carrying the same copy rule as FeatureLock. Unlike FeatureLockDialog this is not a modal the
#guild dismisses; the parent view shows or hides it as a page state.

signal take_me_there(target: Dictionary)

const BG_COLOR: Color = Color(GuiColors.BACKDROP, 1.0)
const PANEL_WIDTH: float = 520.0
const PANEL_BORDER: int = 4
const ICON_SCALE: int = LockPanel.ICON_SCALE

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
@onready var lock_panel: LockPanel = $Panel/Pad/Lock
@onready var lock_icon: TextureRect = $Panel/Pad/Lock/IconRow/LockIcon
@onready var line1_label: Label = $Panel/Pad/Lock/Line1
@onready var line2_label: Label = $Panel/Pad/Lock/Line2
@onready var take_me_there_button: Button = $Panel/Pad/Lock/Buttons/TakeMeThere


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	backing.set_anchors_preset(Control.PRESET_FULL_RECT)
	backing.color = BG_COLOR
	backing.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override(&"panel", GuiStyle.flat(GuiColors.BOX_BG, PANEL_BORDER,
		GuiColors.LOCK_GOLD))
	panel.custom_minimum_size.x = PANEL_WIDTH
	lock_panel.take_me_there.connect(take_me_there.emit)
	resized.connect(_center_panel)
	#A hidden page never sorts, so its wrapping labels sit 1 px wide and report a tall panel until
	#the first sort after it shows; re-centre when that settles the panel's height.
	panel.minimum_size_changed.connect(_center_panel)
	_refresh()
	_center_panel()


#The Plans tab, or the Customize upgrade target when the guild already holds Enterprise.
func target() -> Dictionary:
	return FeatureLock.target(upgrade_id, tier)


func press_take_me_there() -> void:
	lock_panel.press_take_me_there()


func _refresh() -> void:
	if not is_node_ready():
		return
	lock_panel.set_lock({"feature": feature, "plan": plan, "upgrade": upgrade,
		"upgrade_id": upgrade_id, "tier": tier, "tiers": tiers, "verb": verb})


func _center_panel() -> void:
	panel.reset_size()
	panel.position = ((size - panel.size) / 2.0).round()
