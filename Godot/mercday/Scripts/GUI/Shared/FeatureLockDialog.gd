class_name FeatureLockDialog extends Control

#The "you need a bigger plan" modal: SalaryDialog's backdrop and inset-edge chrome with a gold
#ring instead of orange, a lock glyph, two copy lines and a Take Me There button that hands off
#to the Plans screen or, when the guild already holds Enterprise, to the Customize upgrade.

signal take_me_there(target: Dictionary)
signal closed

const BOX_WIDTH: float = 520.0
const BOX_INSET: float = 4.0
const BOX_BORDER: int = 4
const BOX_BG: Color = Color("#1a2b4d")
const BOX_EDGE: Color = Color("#f2d33d")
const EDGE_HI: Color = Color("#28447a")
const EDGE_LO: Color = Color("#111c33")
const EDGE_PX: float = 4.0
const ICON_SCALE: int = 3

@onready var backdrop: Panel = $Backdrop
@onready var box: PanelContainer = $Box
@onready var edges: Control = $Box/Edges
@onready var lock_icon: TextureRect = $Box/Pad/Rows/IconRow/LockIcon
@onready var line1_label: Label = $Box/Pad/Rows/Line1
@onready var line2_label: Label = $Box/Pad/Rows/Line2
@onready var take_me_there_button: Button = $Box/Pad/Rows/Buttons/TakeMeThere
@onready var close_button: Button = $Close

var _target: Dictionary = {}


func _ready() -> void:
	top_level = true
	size = get_viewport().get_visible_rect().size
	edges.draw.connect(_draw_edges)
	edges.resized.connect(edges.queue_redraw)
	_style_box()
	lock_icon.texture = GuiGlyphs.lock(BOX_EDGE, ICON_SCALE)
	lock_icon.custom_minimum_size = Vector2(GuiGlyphs.LOCK_COLS, GuiGlyphs.LOCK_ROWS) * float(ICON_SCALE)
	close_button.pressed.connect(press_close)
	take_me_there_button.pressed.connect(press_take_me_there)
	hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		GuiFrameStack.remove(self)


func open_for(lock: FeatureLock) -> void:
	if lock == null:
		return
	open({
		"feature": lock.feature,
		"plan": lock.plan,
		"upgrade": lock.upgrade,
		"upgrade_id": lock.upgrade_id,
		"tier": lock.tier,
		"tiers": lock.tiers,
		"verb": lock.verb,
		"upgrade_end": lock.upgrade_end,
	})


func open(props: Dictionary) -> void:
	var feature: String = String(props.get("feature", ""))
	var plan: String = String(props.get("plan", "Mercday Enterprise"))
	var upgrade: String = String(props.get("upgrade", ""))
	var upgrade_id: String = String(props.get("upgrade_id", ""))
	var tier: int = int(props.get("tier", 1))
	var tiers: int = int(props.get("tiers", 1))
	var verb: String = String(props.get("verb", "view"))
	var end_mark: String = String(props.get("upgrade_end", "!"))
	var lines: Array[String] = FeatureLock.build_copy(feature, plan, upgrade, upgrade_id, tier,
		tiers, verb, end_mark)
	line1_label.text = lines[0]
	line2_label.text = lines[1]
	var needs_upgrade: bool = SubscriptionManager.plan() == SubscriptionManager.Plan.ENTERPRISE \
		and upgrade_id != ""
	if needs_upgrade:
		_target = {"tab": "customize", "upgrade": upgrade_id, "tier": tier}
	else:
		_target = {"tab": "plans"}
	size = get_viewport().get_visible_rect().size
	show()
	_center()
	GuiFrameStack.push(self)


func press_take_me_there() -> void:
	var target: Dictionary = _target.duplicate()
	GameState.go_to_plans(target)
	take_me_there.emit(target)
	_dismiss()


func press_close() -> void:
	_dismiss()


func _dismiss() -> void:
	hide()
	GuiFrameStack.remove(self)
	closed.emit()


#The box carries the SalaryDialog look: deep panel fill, a solid pixel ring and the inset
#highlight the Edges child paints, with gold in place of SalaryDialog's orange.
func _style_box() -> void:
	var base: StyleBoxFlat = box.get_theme_stylebox(&"panel", &"PopupBox") as StyleBoxFlat
	var style: StyleBoxFlat
	if base != null:
		style = base.duplicate()
	else:
		style = StyleBoxFlat.new()
	style.bg_color = BOX_BG
	style.border_width_left = BOX_BORDER
	style.border_width_top = BOX_BORDER
	style.border_width_right = BOX_BORDER
	style.border_width_bottom = BOX_BORDER
	style.border_color = BOX_EDGE
	style.content_margin_left = BOX_INSET
	style.content_margin_top = BOX_INSET
	style.content_margin_right = BOX_INSET
	style.content_margin_bottom = BOX_INSET
	box.add_theme_stylebox_override(&"panel", style)


func _draw_edges() -> void:
	var span: Vector2 = edges.size
	edges.draw_rect(Rect2(0.0, 0.0, span.x, EDGE_PX), EDGE_HI)
	edges.draw_rect(Rect2(0.0, 0.0, EDGE_PX, span.y), EDGE_HI)
	edges.draw_rect(Rect2(0.0, span.y - EDGE_PX, span.x, EDGE_PX), EDGE_LO)
	edges.draw_rect(Rect2(span.x - EDGE_PX, 0.0, EDGE_PX, span.y), EDGE_LO)


func _center() -> void:
	backdrop.offset_bottom = -GuiFrameStack.bottom_reserve
	box.reset_size()
	box.position = Vector2((size.x - box.size.x) / 2.0,
		(GuiFrameStack.band_height(size.y) - box.size.y) / 2.0)
	box.position.y = maxf(box.position.y, 0.0)
	close_button.position = Vector2(box.position.x + box.size.x - close_button.size.x - 8.0,
		box.position.y + 8.0)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if GuiFrameStack.top() != self:
		return
	press_close()
	get_viewport().set_input_as_handled()
