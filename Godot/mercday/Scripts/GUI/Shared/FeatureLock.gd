class_name FeatureLock extends Button

#A small locked-feature affordance. Icon mode is just the gold lock in a dark box; label mode
#is a full greyed button with the lock to the right of its text. Either way a press opens
#FeatureLockDialog, and the control hides itself once the guild is entitled (unless pinned
#visible for layout reasons).

signal take_me_there(target: Dictionary)

const BEVEL_PX: float = 2.0
const ICON_SCALE: int = 2
const DIALOG_SCENE_PATH: String = "res://Scenes/GUI/Shared/FeatureLockDialog.tscn"
const TOOLTIP_SCENE_PATH: String = "res://Scenes/GUI/Shared/LockTooltip.tscn"
const ROMAN: Array[String] = ["I", "II", "III", "IV", "V", "VI", "VII"]

@export var feature: String = "":
	set(value):
		feature = value
		_refresh()
@export var plan: String = "Mercday Enterprise":
	set(value):
		plan = value
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
@export var verb: String = "view":
	set(value):
		verb = value
		_refresh()
#End mark of the upgrade line: the Bazaar copy reads "upgrade!", Promotions "upgrade.".
@export var upgrade_end: String = "!":
	set(value):
		upgrade_end = value
		_refresh()
#Icon mode when empty; label mode (a full greyed button) otherwise.
@export var label: String = "":
	set(value):
		label = value
		_refresh()
@export var height: float = 28.0:
	set(value):
		height = value
		_refresh()
@export var font_size: int = 10:
	set(value):
		font_size = value
		_refresh()
#Keeps the control visible even when the feature is unlocked, for layout probes and tests.
@export var always_visible: bool = false:
	set(value):
		always_visible = value
		_refresh()
#The entitlements() key that opens this feature. A key set here decides on its own; with none the
#plan and upgrade tier below decide. Never a plan name: the screens gate on keys only.
@export var entitlement: String = "":
	set(value):
		entitlement = value
		_warned_key = false
		_refresh()
#The value a numeric entitlement must reach. Zero reads `tier` instead.
@export var entitlement_tier: int = 0:
	set(value):
		entitlement_tier = value
		_refresh()
#The plan the fallback rule needs with no entitlement key: the ranks of SubscriptionManager.Plan,
#0 Free, 1 Pro, 2 Enterprise. The `plan` export above is display text and gates nothing.
@export_enum("Free", "Pro", "Enterprise") var required_plan: int = 2:
	set(value):
		required_plan = value
		_refresh()
#A width the host asks for. Icon mode is a square of `height` and label mode takes what its text
#needs, so a host that wants more says so here instead of writing custom_minimum_size itself.
@export var min_width: float = 0.0:
	set(value):
		min_width = value
		_refresh()

@onready var text_label: Label = $Row/Text
@onready var lock_box: PanelContainer = $Row/LockBox
@onready var lock_icon: TextureRect = $Row/LockBox/LockIcon

var _dialog: FeatureLockDialog = null
var _tip: TooltipPanel = null
var _warned_key: bool = false


func _ready() -> void:
	pressed.connect(open_dialog)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	if not SubscriptionManager.changed.is_connected(_refresh):
		SubscriptionManager.changed.connect(_refresh)
	_refresh()


func _exit_tree() -> void:
	if SubscriptionManager.changed.is_connected(_refresh):
		SubscriptionManager.changed.disconnect(_refresh)


#True when the guild is not entitled to this feature. An entitlement key answers alone; without
#one the plan rank and the upgrade tier answer.
#A lock that names no key, no upgrade and no plan text gates nothing and reads open.
func locked() -> bool:
	if entitlement == "" and upgrade_id == "" and plan == "":
		return false
	if entitlement != "":
		return not _entitled()
	if SubscriptionManager.plan() < required_plan:
		return true
	if upgrade_id != "":
		return SubscriptionManager.tier_of(upgrade_id) < tier
	return false


#The tier a numeric entitlement must reach: entitlement_tier when the host set one, else tier.
func wanted_tier() -> int:
	return entitlement_tier if entitlement_tier > 0 else tier


#A flag key opens the feature when true; a number is a tier and must reach wanted_tier(). A key
#entitlements() does not carry stays locked and warns once, so a misspelling never opens a feature.
func _entitled() -> bool:
	var table: Dictionary = SubscriptionManager.entitlements()
	if not table.has(entitlement):
		if not _warned_key:
			_warned_key = true
			push_warning("FeatureLock '%s': entitlements() has no key '%s'" % [feature, entitlement])
		return false
	var value: Variant = table[entitlement]
	if value is bool:
		return bool(value)
	if value is int or value is float:
		return int(value) >= wanted_tier()
	return false


func open_dialog() -> void:
	if _dialog == null:
		var scene: PackedScene = load(DIALOG_SCENE_PATH) as PackedScene
		_dialog = scene.instantiate() as FeatureLockDialog
		add_child(_dialog)
		_dialog.take_me_there.connect(func(target: Dictionary) -> void: take_me_there.emit(target))
	_dialog.open_for(self)


func copy_lines() -> Array[String]:
	return build_copy(feature, plan, upgrade, upgrade_id, tier, tiers, verb, upgrade_end)


#Plan text when the guild's plan itself falls short; upgrade text when the plan covers
#Enterprise but the named upgrade has not reached the required tier.
static func build_copy(p_feature: String, p_plan: String, p_upgrade: String, p_upgrade_id: String,
		p_tier: int, p_tiers: int, p_verb: String, p_end: String = "!") -> Array[String]:
	var need_upgrade: bool = SubscriptionManager.plan() == SubscriptionManager.Plan.ENTERPRISE \
		and p_upgrade_id != ""
	if not need_upgrade:
		var verb_text: String = "view" if p_verb == "view" else "use"
		return ["This feature of Mercday is not available on your plan!",
			"Upgrade to %s to %s %s." % [p_plan, verb_text, p_feature]]
	var line2: String
	if p_tiers > 1:
		line2 = "It requires the Tier %s %s upgrade%s" % [roman(p_tier), p_upgrade, p_end]
	else:
		line2 = "It requires the %s upgrade%s" % [p_upgrade, p_end]
	return ["%s is locked." % p_feature, line2]


static func roman(n: int) -> String:
	if n >= 1 and n <= ROMAN.size():
		return ROMAN[n - 1]
	return str(n)


func _refresh() -> void:
	if not is_node_ready():
		return
	visible = always_visible or locked()
	text_label.visible = label != ""
	text_label.text = label
	text_label.add_theme_font_size_override("font_size", font_size)
	text_label.add_theme_color_override("font_color", GuiColors.LOCKED_TEXT)
	lock_icon.texture = GuiGlyphs.lock(GuiColors.LOCK_GOLD, ICON_SCALE)
	lock_icon.custom_minimum_size = Vector2(GuiGlyphs.LOCK_COLS, GuiGlyphs.LOCK_ROWS) * float(ICON_SCALE)
	custom_minimum_size.y = height
	custom_minimum_size.x = maxf(min_width, height if label == "" else 0.0)
	tooltip_text = "Locked" if label != "" else ""
	_apply_style()
	if _tip != null:
		_apply_tooltip_text()


func _apply_style() -> void:
	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	var box_style: StyleBoxFlat = StyleBoxFlat.new()
	if label != "":
		btn_style.bg_color = GuiColors.LOCKED_BG
		btn_style.content_margin_left = 10.0
		btn_style.content_margin_right = 10.0
		btn_style.content_margin_top = 4.0
		btn_style.content_margin_bottom = 4.0
		box_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	else:
		btn_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		box_style.bg_color = Color("#0a0f1c")
		box_style.border_width_left = 1
		box_style.border_width_top = 1
		box_style.border_width_right = 1
		box_style.border_width_bottom = 1
		box_style.border_color = GuiColors.LOCK_RING
		box_style.content_margin_left = 1.0
		box_style.content_margin_top = 1.0
		box_style.content_margin_right = 1.0
		box_style.content_margin_bottom = 1.0
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		add_theme_stylebox_override(state, btn_style)
	lock_box.add_theme_stylebox_override(&"panel", box_style)
	queue_redraw()


#Label mode carries the same top hi / bottom lo bevel bars TabButton draws for its own look.
func _draw() -> void:
	if label == "":
		return
	draw_rect(Rect2(0.0, 0.0, size.x, BEVEL_PX), GuiColors.LOCKED_HI)
	draw_rect(Rect2(0.0, size.y - BEVEL_PX, size.x, BEVEL_PX), GuiColors.LOCKED_LO)


func _on_mouse_entered() -> void:
	if label != "" or not locked():
		return
	if _tip == null:
		var scene: PackedScene = load(TOOLTIP_SCENE_PATH) as PackedScene
		_tip = scene.instantiate() as TooltipPanel
		add_child(_tip)
	_apply_tooltip_text()
	_tip.show_at(self)


func _on_mouse_exited() -> void:
	if _tip != null:
		_tip.hide_tip()


func _apply_tooltip_text() -> void:
	var lines: Array[String] = copy_lines()
	_tip.set_text("Locked", "%s\n%s" % [lines[0], lines[1]])
