class_name UpgradeTierDialog extends PanelContainer

#The 400 by 400 popover of one Enterprise customization: what the guild owns, what the next tier
#costs today and every month, and one row per tier. Plus buys a tier through SubscriptionManager and
#minus drops one; a refusal plays the reject state and prints the reason. The rows are built in code,
#so the scene file holds nothing but the root.

signal go_to_plans_pressed

const BOX: Vector2 = Vector2(400.0, 400.0)
const MARGIN: float = 8.0
const PAD_SIDE: int = 16
const PAD_TOP: int = 14
const PAD_BOTTOM: int = 12
const GAP: int = 10
const REJECT_MS: int = 420
const BAR_UP: float = 0.6
const BAR_DOWN: float = 0.45
const PLUS_POP: float = 0.5
const MINUS_POP: float = 0.35
const REJECT_FX: float = 0.4
const FLASH_COUNT: int = 3
const FLASH_SCALE: float = 1.2
const GLOW: Color = Color(1.4, 1.4, 1.4, 1.0)
const FLASH_SECONDS: float = REJECT_MS / 1000.0
#A held plus or minus steps once on the press, waits HOLD_DELAY seconds, then steps HOLD_RATE times a second.
const HOLD_DELAY: float = 0.35
const HOLD_RATE: float = 6.0
const BUTTON_BOX: Vector2 = Vector2(56.0, 56.0)
#The X sits this far in from the box's top right corner, past its outline ring.
const CLOSE_INSET: float = 6.0
const CHUNK_H: float = 18.0
const CHUNK_GAP: float = 4.0
const BAR_PAD: float = 4.0
const BEVEL: float = 3.0
const ROW_ICON: float = 38.0
const WARN_MARGIN: float = 0.15
const STYLE: StyleBox = preload("res://Resources/GUI/Theme/Styles/tree_dialog.tres")
const HAVE_STYLE: StyleBox = preload("res://Resources/GUI/Theme/Styles/tree_row_have.tres")
const NEXT_STYLE: StyleBox = preload("res://Resources/GUI/Theme/Styles/tree_row_next.tres")
const LOCKED_STYLE: StyleBox = preload("res://Resources/GUI/Theme/Styles/tree_row_locked.tres")
const HEAD_FONT: FontVariation = GuiStyle.SILK
const BOLD_FONT: FontVariation = GuiStyle.SILK_BOLD
const BODY_FONT: FontVariation = GuiStyle.BODY
const INK: Color = GuiColors.INK
const CHUNK_OFF: Color = GuiColors.ROW_HOVER
const CHUNK_OFF_HI: Color = GuiColors.BLUE_LO
const CHUNK_OFF_LO: Color = GuiColors.ROW_FILL
const HEAD_COLOR: Color = GuiColors.SKY
const NAME_COLOR: Color = GuiColors.ORANGE
const CREAM: Color = GuiColors.CREAM
const YELLOW: Color = GuiColors.RAMP_YELLOW
const GREEN: Color = GuiColors.GREEN
const RED: Color = GuiColors.RED
const BUDGET_YELLOW: Color = GuiColors.AMBER
const NEXT_TEXT: Color = GuiColors.PALE_SKY
const LOCKED_TEXT: Color = GuiColors.MUTED
const LOCKED_LABEL: Color = GuiColors.LOCK_RING
const PLUS_BG: Color = GuiColors.GREEN
const PLUS_BG_MAX: Color = GuiColors.LOCKED_BG
const MINUS_BG: Color = GuiColors.RED
const HEAD_TEXT: String = "Enterprise Customization"
const TODAY_SUFFIX: String = " today"
const MONTH_SUFFIX: String = "/month starting "
const MAX_TEXT: String = "Fully Upgraded"
const MAX_GAP: String = "   "
const FEE_SUFFIX: String = "/month"
const GLYPH_SCALE: int = 1
const INCOME_LABEL: String = "Monthly Income"
const NEXT_LABEL: String = "Next Tier"
const EXIT_TEXT: String = "Exit"
const SEATS_LINE: String = "Can't go below Tier %d: %d mercs are using those seats."
const BOARD_LINE: String = "Can't go below Tier %d: %d contracts are on your board."
const PLANS_TEXT: String = "Take Me There"

var _id: String = ""
var _rej_until: int = 0
var _rej_kind: String = ""
var _reason: String = ""
var _sweep: PackedFloat32Array = PackedFloat32Array()
var _name: Label = null
var _desc: Label = null
var _tier_label: Label = null
var _bar: Control = null
var _minus: Button = null
var _plus: Button = null
var _today: NotesLabel = null
var _monthly: NotesLabel = null
var _max_note: NotesLabel = null
var _income: Label = null
var _in_use: Label = null
var _rows: VBoxContainer = null
var _plans: BevelButton = null
var _close: Button = null
var _rows_dirty: bool = false
var _want_tier: int = 0
var _hold_dir: int = 0
var _hold_time: float = 0.0
var _hold_carry: float = 0.0
var _flash_left: float = 0.0


func _ready() -> void:
	custom_minimum_size = BOX
	size = BOX
	add_theme_stylebox_override("panel", STYLE)
	_build()
	resized.connect(_keep_in_band)
	minimum_size_changed.connect(_fit_box, CONNECT_DEFERRED)
	resized.connect(_fit_box, CONNECT_DEFERRED)
	SubscriptionManager.changed.connect(_on_changed)
	PulseClock.pulse.connect(_on_pulse)
	set_process(false)
	hide()


#Opens the popover on one upgrade at a frame position; the caller has already clamped it.
func open_for(id: String, at: Vector2 = Vector2(440.0, 160.0)) -> void:
	if not UpgradeDefs.has_id(id):
		return
	_id = id
	_rej_until = 0
	_rej_kind = ""
	_reason = ""
	_flash_left = 0.0
	_apply_flash()
	position = at
	refresh()
	if not visible:
		UiSfx.play_summon()
	show()
	size = BOX
	_keep_in_band()
	GuiFrameStack.push(self)


func close() -> void:
	_flash_left = 0.0
	_apply_flash()
	hold_end()
	_rej_until = 0
	_rej_kind = ""
	_reason = ""
	if visible:
		UiSfx.play_dismiss()
	hide()
	GuiFrameStack.remove(self)


func _exit_tree() -> void:
	hold_end()
	GuiFrameStack.remove(self)


#Hiding a held button drops its press without a button_up, so the hold stops with the popover.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		hold_end()


#Esc closes this popover only while it is the top frame of the stack.
func _unhandled_input(event: InputEvent) -> void:
	if GuiFrameStack.consume_escape(self, event):
		close()


#A left press outside the popover closes it. The press is not accepted, so a click on another
#module still reaches that module and opens its popover.
func _input(event: InputEvent) -> void:
	if not is_open():
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if not get_global_rect().has_point(click.position):
		close()


func press_close() -> void:
	close()


func close_button() -> Button:
	return _close


#The band is the viewport above the bottom bar; the whole box stays inside it wherever it opens.
func band_rect() -> Rect2:
	var view: Vector2 = get_viewport_rect().size
	return Rect2(Vector2.ZERO, Vector2(view.x, GuiFrameStack.band_height(view.y)))


#A wrapped label measured before its width settles grows the box; the box goes back to BOX after.
func _fit_box() -> void:
	if not visible or not is_inside_tree():
		return
	if not size.is_equal_approx(BOX):
		size = BOX
	_keep_in_band()


func _keep_in_band() -> void:
	if not visible or not is_inside_tree():
		return
	var band: Rect2 = band_rect()
	#A wrapped label can stretch the box for a frame before _fit_box; the clamp uses the settled BOX.
	var rect: Rect2 = Rect2(global_position, BOX)
	var x: float = clampf(rect.position.x, band.position.x, maxf(band.position.x, band.end.x - rect.size.x))
	var y: float = clampf(rect.position.y, band.position.y, maxf(band.position.y, band.end.y - rect.size.y))
	if not is_equal_approx(x, rect.position.x) or not is_equal_approx(y, rect.position.y):
		global_position = Vector2(x, y)


func press_plus() -> void:
	if _id == "":
		return
	if SubscriptionManager.can_raise(_id):
		_reason = ""
		if SubscriptionManager.buy_tier(_id):
			_play("up")
			UiSfx.play_upgrade(upgrade_ratio())
			return
	_reason = SubscriptionManager.raise_reason(_id)
	_reject("up")


func press_minus() -> void:
	if _id == "":
		return
	if SubscriptionManager.can_lower(_id):
		_reason = ""
		if SubscriptionManager.lower_tier(_id):
			_play("down")
			UiSfx.play_upgrade(upgrade_ratio())
			return
	_reason = SubscriptionManager.lower_reason(_id)
	_reject("down")


#A press steps once right away and arms the repeat; a refused first step leaves nothing armed.
func hold_begin(dir: int) -> void:
	_hold_dir = signi(dir)
	_hold_time = 0.0
	_hold_carry = 0.0
	_hold_step()
	set_process(_hold_dir != 0 or is_flashing())


func hold_end() -> void:
	_hold_dir = 0
	_hold_time = 0.0
	_hold_carry = 0.0
	set_process(is_flashing())


func is_holding() -> bool:
	return _hold_dir != 0


#One slice of a held button: nothing before HOLD_DELAY, then one step per 1 / HOLD_RATE seconds.
func step_hold(delta: float) -> void:
	if _hold_dir == 0:
		return
	var before: float = _hold_time
	_hold_time += delta
	if _hold_time < HOLD_DELAY:
		return
	_hold_carry += (_hold_time - maxf(before, HOLD_DELAY)) * HOLD_RATE
	while _hold_carry >= 1.0 and _hold_dir != 0:
		_hold_carry -= 1.0
		_hold_step()


func _hold_step() -> void:
	if _hold_dir > 0:
		press_plus()
	elif _hold_dir < 0:
		press_minus()


func _process(delta: float) -> void:
	step_hold(delta)
	step_flash(delta)
	if _hold_dir == 0 and not is_flashing():
		set_process(false)


#The income number pulses FLASH_COUNT times inside the refusal window, for an income refusal only.
func is_flashing() -> bool:
	return _flash_left > 0.0


func flash_phase() -> float:
	if not is_flashing():
		return 0.0
	return fmod((1.0 - _flash_left / FLASH_SECONDS) * float(FLASH_COUNT), 1.0)


func flash_scale() -> float:
	return 1.0 + (FLASH_SCALE - 1.0) * sin(PI * flash_phase())


func flash_glow() -> Color:
	return Color.WHITE.lerp(GLOW, sin(PI * flash_phase()))


func step_flash(seconds: float) -> void:
	if not is_flashing():
		return
	_flash_left = maxf(0.0, _flash_left - maxf(0.0, seconds))
	_apply_flash()
	if not is_flashing():
		_income.add_theme_color_override("font_color", income_color())


func income_scale() -> float:
	return _income.scale.x


func income_glow() -> Color:
	return _income.modulate


func _apply_flash() -> void:
	if _income == null:
		return
	_income.scale = Vector2.ONE * flash_scale()
	_income.modulate = flash_glow()


func press_plans() -> void:
	go_to_plans_pressed.emit()


func upgrade_id() -> String:
	return _id


func is_open() -> bool:
	return visible


func is_rejecting() -> bool:
	return Time.get_ticks_msec() < _rej_until


func reject_kind() -> String:
	return _rej_kind if is_rejecting() else ""


func reason_text() -> String:
	return _reason


func tier() -> int:
	return SubscriptionManager.tier_of(_id)


func max_tier() -> int:
	return SubscriptionManager.max_tier(_id)


func is_max() -> bool:
	return tier() >= max_tier()


func upgrade_ratio() -> float:
	return float(tier()) / float(maxi(1, max_tier()))


func tier_label_text() -> String:
	return "Tier " + str(tier()) + " / " + str(max_tier())


#What raising one tier costs right now: nothing when this cycle already paid for it.
func charge_today() -> int:
	if is_max():
		return 0
	return SubscriptionManager.upgrade_charge_today(_id, tier() + 1)


func today_text() -> String:
	return str(charge_today()) + TODAY_SUFFIX


func next_fee() -> int:
	if is_max():
		return 0
	return SubscriptionManager.tier_price(_id, tier() + 1)


func monthly_text() -> String:
	return "+" + str(next_fee()) + MONTH_SUFFIX + bill_date_text()


func max_note_text() -> String:
	return str(SubscriptionManager.upgrade_fee(_id)) + FEE_SUFFIX


#The next bill day on the game calendar: the first three letters of its month, then the day.
func bill_date_text() -> String:
	var ahead: int = SubscriptionManager.days_to_bill() * TrynnCalendar.MINUTES_PER_DAY
	var date: Dictionary = TrynnCalendar.date_of(CampaignClock.now() + ahead)
	return String(date.get("month_name", "")).substr(0, 3) + " " + TrynnCalendar.ordinal(SubscriptionManager.BILL_DAY)


#What is left of the monthly income once every bill the guild holds now is paid.
func income_value() -> int:
	return SubscriptionManager.budget_available() - SubscriptionManager.service_fee() \
		- SubscriptionManager.upgrade_fee()


func income_color() -> Color:
	var left: int = income_value()
	if left < 0 or is_flashing():
		return RED
	if float(left) < float(SubscriptionManager.budget_available()) * WARN_MARGIN:
		return BUDGET_YELLOW
	return GREEN


func income_text() -> String:
	return str(income_value())


#The line that names what holds a tier in place, shown whenever a floor exists.
func in_use_text() -> String:
	var floor_tier: int = SubscriptionManager.min_tier(_id)
	if floor_tier <= 0:
		return ""
	if _id == "seats":
		return SEATS_LINE % [floor_tier, SubscriptionManager.employed()]
	if _id == "contracts":
		return BOARD_LINE % [floor_tier, SubscriptionManager.board_count()]
	return ""


func row_count() -> int:
	return _rows.get_child_count()


#Where one tier row sits inside the scrolled list.
func row_offset(i: int) -> int:
	if i < 0 or i >= _rows.get_child_count():
		return 0
	var row: Control = _rows.get_child(i) as Control
	if row == null:
		return 0
	return int(row.position.y)


#How far the tier list is scrolled right now.
func tier_scroll() -> int:
	var scroll: ScrollContainer = _rows.get_parent() as ScrollContainer
	if scroll == null:
		return 0
	return scroll.scroll_vertical


#Brings one tier row into view; the deep link asks for the tier a locked feature wants. Rows added
#this frame carry no offset yet, so the scroll waits for the sort that lays them out.
func scroll_to_tier(wanted: int) -> void:
	if _rows.get_child_count() == 0:
		return
	if _rows_dirty:
		_want_tier = wanted
		return
	_apply_scroll(wanted)


#The sort signal arrives before the box places its rows, so the scroll is applied once the
#frame has laid them out and row.position.y is the offset the list really uses.
func _on_rows_sorted() -> void:
	_rows_dirty = false
	var wanted: int = _want_tier
	_want_tier = 0
	if wanted > 0 and is_inside_tree():
		_apply_scroll.call_deferred(wanted)


func _apply_scroll(wanted: int) -> void:
	var scroll: ScrollContainer = _rows.get_parent() as ScrollContainer
	if scroll == null or _rows.get_child_count() == 0:
		return
	var index: int = clampi(wanted - 1, 0, _rows.get_child_count() - 1)
	var row: Control = _rows.get_child(index) as Control
	if row == null:
		return
	scroll.set_deferred("scroll_vertical", int(row.position.y))


#"have" below the owned tier, "next" on the one for sale, "locked" above it.
func row_state(i: int) -> String:
	if i < tier():
		return "have"
	if i == tier():
		return "next"
	return "locked"


func row_label(i: int) -> String:
	if row_state(i) == "next":
		return NEXT_LABEL
	return "Tier " + SubscriptionManager.roman(i + 1)


func row_text(i: int) -> String:
	return UpgradeDefs.tier_text(_id, i + 1)


func row_label_color(i: int) -> Color:
	var state: String = row_state(i)
	if state == "next":
		return NAME_COLOR
	if state == "locked":
		return LOCKED_LABEL
	return GuiColors.tier_color(i, max_tier())


func row_text_color(i: int) -> Color:
	var state: String = row_state(i)
	if state == "have":
		return CREAM
	if state == "next":
		return NEXT_TEXT
	return LOCKED_TEXT


func row_style(i: int) -> StyleBox:
	var state: String = row_state(i)
	if state == "have":
		return HAVE_STYLE
	if state == "next":
		return NEXT_STYLE
	return LOCKED_STYLE


#Brightness of one chunk: flat until the upgrade is maxed, then the shared left to right sweep.
func chunk_glow(i: int) -> float:
	if not is_max():
		return 1.0
	return PulseClock.sweep_of(_sweep, i)


func refresh() -> void:
	if _id == "":
		return
	var top: int = max_tier()
	var maxed: bool = is_max()
	_name.text = UpgradeDefs.name_of(_id)
	_desc.text = String(UpgradeDefs.of(_id).get("desc", ""))
	_tier_label.text = tier_label_text()
	_today.text_override = str(charge_today())
	_today.visible = not maxed
	_monthly.text_override = "+" + str(next_fee())
	_monthly.suffix = MONTH_SUFFIX + bill_date_text()
	_monthly.visible = not maxed
	_max_note.text_override = str(SubscriptionManager.upgrade_fee(_id))
	_max_note.visible = maxed
	_income.text = income_text()
	_income.add_theme_color_override("font_color", income_color())
	_in_use.text = in_use_text()
	_in_use.visible = _in_use.text != ""
	_plus.modulate = Color.WHITE
	_minus.modulate = Color.WHITE
	_plus.add_theme_color_override("font_color", INK)
	_minus.add_theme_color_override("font_color", INK)
	_tint(_plus, PLUS_BG_MAX if maxed else PLUS_BG)
	_tint(_minus, MINUS_BG)
	_plans.visible = SubscriptionManager.plan() != SubscriptionManager.Plan.ENTERPRISE
	_fill_rows(top)
	_bar.queue_redraw()


func _on_changed() -> void:
	if visible:
		refresh()


func _on_pulse(_g: float, sweep: PackedFloat32Array) -> void:
	if not visible or not is_max():
		return
	_sweep = sweep
	_bar.queue_redraw()


func _play(kind: String) -> void:
	_rej_until = 0
	_rej_kind = ""
	_flash_left = 0.0
	_apply_flash()
	refresh()
	var seconds: float = BAR_UP if kind == "up" else BAR_DOWN
	var tween: Tween = create_tween()
	tween.tween_property(_bar, "modulate", GLOW, seconds * 0.25)
	tween.tween_property(_bar, "modulate", Color.WHITE, seconds * 0.75)
	var node: Button = _plus if kind == "up" else _minus
	var pop: float = PLUS_POP if kind == "up" else MINUS_POP
	var bump: Tween = create_tween()
	bump.tween_property(node, "modulate", Color(1.3, 1.3, 1.3, 1.0), pop * 0.3)
	bump.tween_property(node, "modulate", Color.WHITE, pop * 0.7)


func _reject(kind: String) -> void:
	hold_end()
	_rej_kind = kind
	_rej_until = Time.get_ticks_msec() + REJECT_MS
	_flash_left = FLASH_SECONDS if kind == "up" and _reason == SubscriptionManager.INCOME_REASON else 0.0
	_apply_flash()
	set_process(is_flashing())
	refresh()
	GameSfx.play_reject()
	var node: Button = _plus if kind == "up" else _minus
	var tween: Tween = create_tween()
	tween.tween_property(node, "modulate", RED, REJECT_FX * 0.5)
	tween.tween_property(node, "modulate", Color.WHITE, REJECT_FX * 0.5)


func _fill_rows(top: int) -> void:
	while _rows.get_child_count() > top:
		var extra: Node = _rows.get_child(_rows.get_child_count() - 1)
		_rows.remove_child(extra)
		extra.queue_free()
		_rows_dirty = true
	while _rows.get_child_count() < top:
		_rows.add_child(_new_row())
		_rows_dirty = true
	for i: int in top:
		var row: PanelContainer = _rows.get_child(i) as PanelContainer
		row.add_theme_stylebox_override("panel", row_style(i))
		var icon: IconRect = row.get_node("Line/Icon") as IconRect
		var c: Color = row_label_color(i)
		icon.set_id(TreeIcons.id_of(_id), 2)
		icon.tint = Color(c.r, c.g, c.b, 0.5 if row_state(i) == "next" else 1.0)
		var label: Label = row.get_node("Line/Text/Label") as Label
		label.text = row_label(i)
		label.add_theme_color_override("font_color", row_label_color(i))
		var body: Label = row.get_node("Line/Text/Body") as Label
		body.text = row_text(i)
		body.add_theme_color_override("font_color", row_text_color(i))


func _new_row() -> PanelContainer:
	var row: PanelContainer = PanelContainer.new()
	row.custom_minimum_size = Vector2(0.0, ROW_ICON)
	var line: HBoxContainer = HBoxContainer.new()
	line.name = "Line"
	line.add_theme_constant_override("separation", 8)
	row.add_child(line)
	var icon: IconRect = IconRect.new()
	icon.name = "Icon"
	icon.pixel_scale = 2
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	line.add_child(icon)
	var text: VBoxContainer = VBoxContainer.new()
	text.name = "Text"
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 4)
	line.add_child(text)
	text.add_child(_label("Label", BOLD_FONT, 10, CREAM))
	var body: Label = _label("Body", BODY_FONT, 12, CREAM)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(body)
	return row


func _build() -> void:
	var pad: MarginContainer = MarginContainer.new()
	pad.name = "Pad"
	pad.add_theme_constant_override("margin_left", PAD_SIDE)
	pad.add_theme_constant_override("margin_right", PAD_SIDE)
	pad.add_theme_constant_override("margin_top", PAD_TOP)
	pad.add_theme_constant_override("margin_bottom", PAD_BOTTOM)
	add_child(pad)
	var col: VBoxContainer = VBoxContainer.new()
	col.name = "Col"
	col.add_theme_constant_override("separation", GAP)
	pad.add_child(col)
	var head: Label = _label("Head", HEAD_FONT, 8, HEAD_COLOR)
	head.text = HEAD_TEXT
	col.add_child(head)
	_name = _label("Name", BOLD_FONT, 14, NAME_COLOR)
	col.add_child(_name)
	_desc = _label("Desc", BODY_FONT, 12, HEAD_COLOR)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_desc)
	_tier_label = _label("TierLabel", BOLD_FONT, 11, CREAM)
	col.add_child(_tier_label)
	_bar = Control.new()
	_bar.name = "Bar"
	_bar.custom_minimum_size = Vector2(0.0, CHUNK_H + BAR_PAD * 2.0)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	col.add_child(_bar)
	col.add_child(_controls())
	UiSfx.override_click(_plus, null)
	UiSfx.override_click(_minus, null)
	_in_use = _label("InUse", BODY_FONT, 13, RED)
	_in_use.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_in_use)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Tiers"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(_rows)
	_rows.sort_children.connect(_on_rows_sorted)
	_plans = _nav_button("Plans", PLANS_TEXT, 11)
	_plans.pressed.connect(press_plans)
	col.add_child(_plans)
	_close = CloseX.make(CloseX.SCALE_WINDOW)
	_close.name = "CloseX"
	_close.tooltip_text = EXIT_TEXT
	_close.pressed.connect(press_close)
	CloseX.pin(_close, self, CloseX.SCALE_WINDOW, CLOSE_INSET)


func _controls() -> HBoxContainer:
	var line: HBoxContainer = HBoxContainer.new()
	line.name = "Controls"
	line.add_theme_constant_override("separation", GAP)
	_minus = _button("Minus", "minus", MINUS_BG)
	_minus.custom_minimum_size = BUTTON_BOX
	_minus.button_down.connect(hold_begin.bind(-1))
	_minus.button_up.connect(hold_end)
	line.add_child(_minus)
	#A plain Control reports no child minimum, so a long fee line clips instead of widening the box.
	var clip: Control = Control.new()
	clip.name = "Clip"
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip.custom_minimum_size = Vector2(0.0, BUTTON_BOX.y)
	line.add_child(clip)
	var middle: VBoxContainer = VBoxContainer.new()
	middle.name = "Middle"
	middle.set_anchors_preset(Control.PRESET_FULL_RECT)
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override("separation", 6)
	clip.add_child(middle)
	_today = _money_line("Today", 13, CREAM, TODAY_SUFFIX)
	middle.add_child(_today)
	_monthly = _money_line("Monthly", 11, YELLOW, MONTH_SUFFIX)
	middle.add_child(_monthly)
	_max_note = _money_line("MaxNote", 14, GREEN, FEE_SUFFIX)
	_max_note.prefix = MAX_TEXT + MAX_GAP
	middle.add_child(_max_note)
	var income_line: HBoxContainer = HBoxContainer.new()
	income_line.name = "Income"
	income_line.add_theme_constant_override("separation", 6)
	middle.add_child(income_line)
	var tag: Label = _label("Tag", HEAD_FONT, 9, HEAD_COLOR)
	tag.text = INCOME_LABEL
	income_line.add_child(tag)
	_income = _label("Value", BOLD_FONT, 11, GREEN)
	_income.pivot_offset_ratio = Vector2(0.5, 0.5)
	income_line.add_child(_income)
	_plus = _button("Plus", "plus", PLUS_BG)
	_plus.custom_minimum_size = BUTTON_BOX
	_plus.button_down.connect(hold_begin.bind(1))
	_plus.button_up.connect(hold_end)
	line.add_child(_plus)
	return line


func _draw_bar() -> void:
	var top: int = max_tier()
	if top <= 0:
		return
	var box: Rect2 = Rect2(Vector2.ZERO, _bar.size)
	_bar.draw_rect(box, INK)
	var span: float = _bar.size.x - BAR_PAD * 2.0 - CHUNK_GAP * float(top - 1)
	var width: float = maxf(2.0, span / float(top))
	for i: int in top:
		var at: Vector2 = Vector2(BAR_PAD + (width + CHUNK_GAP) * float(i), BAR_PAD)
		var cell: Rect2 = Rect2(at, Vector2(width, CHUNK_H))
		var on: bool = i < tier()
		var body: Color = GuiColors.tier_color(i, top) if on else CHUNK_OFF
		var hi: Color = body.lightened(0.4) if on else CHUNK_OFF_HI
		var lo: Color = body.darkened(0.35) if on else CHUNK_OFF_LO
		var k: float = chunk_glow(i)
		_bar.draw_rect(cell, GuiColors.brighter(body, k))
		_bar.draw_rect(Rect2(at, Vector2(width, BEVEL)), GuiColors.brighter(hi, k))
		_bar.draw_rect(Rect2(at + Vector2(0.0, CHUNK_H - BEVEL), Vector2(width, BEVEL)),
			GuiColors.brighter(lo, k))


#One money line in bold: an amount, the notes tile and the suffix.
func _money_line(label: String, size_px: int, tint: Color, suffix: String) -> NotesLabel:
	var line: NotesLabel = GuiStyle.notes(0, size_px, tint)
	line.name = label
	line.separation = 2
	line.glyph_scale = GLYPH_SCALE
	line.suffix = suffix
	return line


func _label(label: String, font: FontVariation, size_px: int, tint: Color) -> Label:
	var out: Label = GuiStyle.label("", font, size_px, tint)
	out.name = label
	return out


#Plans and Exit are the shared BevelButton scene, both in the same blue kind the old EXIT_BG fill used.
func _nav_button(label: String, text: String, size_px: int) -> BevelButton:
	var out: BevelButton = BevelButton.make(text, &"blue")
	out.name = label
	out.add_theme_font_override("font", BOLD_FONT)
	out.add_theme_font_size_override("font_size", size_px)
	return out


func _button(label: String, id: String, bg: Color) -> Button:
	var out: Button = Button.new()
	out.name = label
	out.text = ""
	out.expand_icon = false
	out.icon = Icons.baked(id, 2, Icons.MODE_PLAIN, true)
	out.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	out.add_theme_color_override("icon_normal_color", GuiColors.CREAM)
	out.add_theme_color_override("icon_hover_color", Color.WHITE)
	out.add_theme_color_override("icon_pressed_color", GuiColors.INK)
	out.add_theme_color_override("icon_disabled_color", GuiColors.MUTED)
	_tint(out, bg)
	return out


func _tint(node: Button, tint: Color) -> void:
	GuiStyle.set_all_boxes(node, GuiStyle.flat(tint, 2, INK), [&"normal", &"hover", &"pressed", &"disabled"])
