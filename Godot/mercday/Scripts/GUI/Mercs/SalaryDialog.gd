class_name SalaryDialog extends ModalDialog

#The wage popup, shared by the Merc Viewer and the Payroll page: the merc, the eleven guild moods
#with the previewed one lit, a held stepper and the Fire link. Confirm is the only wage confirm and
#writes through BenefitsManager. It rides GuiFrameStack like the other modal frames, so Esc reaches
#the topmost one, and its box stays in the band above the bottom bar.

signal fired(uid: int)

const FONT_KICKER: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const FONT_BODY: FontVariation = preload("res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres")

const KICKER_TEXT: String = "Adjust Salary"
const STEP_LABEL: String = "Monthly Salary"
const VACATION_PREFIX: String = "Vacation Days Remaining: "
const LOCK_LINE: String = "Salary can only be changed while this merc is Available or Resting."
const FIRE_TEXT: String = "Fire"
const BOX_WIDTH: float = 520.0
const DIM_ALPHA: float = 0.35
#A wrapping label reports its height at its narrowest, so the box asks for a column of single
#characters unless the label carries the width it wraps at.
const WRAP_PAD: float = 60.0

@export var hold_peak_rate: float = 100.0

@onready var employed_label: Label = $Box/Pad/Rows/Employed
@onready var vacation_label: Label = $Box/Pad/Rows/Vacation
@onready var faces_row: MoodMeter = $Box/Pad/Rows/Faces
@onready var step_box: PayrollStepper = $Box/Pad/Rows/Step
@onready var lock_label: Label = $Box/Pad/Rows/LockLine
@onready var fire_link: LinkButton = $Box/Pad/Rows/FireRow/Fire
@onready var fire_box: FireConfirmDialog = $Fire

var merc_uid: int = 0
var merc_name: String = ""
var current: int = 0
var max_payable: int = 0

var _value: int = 1


func _ready() -> void:
	box_width = BOX_WIDTH
	super()
	#The Fire link row stays under the buttons, which the base moves to the end of Rows.
	rows.move_child(fire_link.get_parent(), rows.get_child_count() - 1)
	kicker = KICKER_TEXT
	step_box.value_changed.connect(_on_step_changed)
	fire_link.pressed.connect(press_fire)
	fire_box.confirmed.connect(_on_fire_confirmed)
	_style()
	_refresh()


func open_for(view: MercView) -> void:
	if view == null:
		return
	merc_uid = view.uid
	merc_name = view.name
	current = view.monthly_salary
	max_payable = maxi(current, GameState.bank_notes)
	_apply_bounds()
	set_value(current)
	present()


func open_for_uid(uid: int) -> void:
	open_for(BenefitsManager.view_of(uid))


func set_value(v: int) -> void:
	_value = clampi(v, 1, maxi(1, max_payable))
	if is_node_ready():
		step_box.set_value_silent(_value)
	_refresh()


func step(delta: int) -> void:
	if delta == 0 or not is_node_ready():
		return
	var up: bool = delta > 0
	for _i: int in absi(delta):
		var before: int = step_box.value
		if up:
			step_box.press_plus()
		else:
			step_box.press_minus()
		if step_box.value == before:
			break


func value() -> int:
	return _value


func is_locked() -> bool:
	return BenefitsManager.salary_locked(merc_uid)


func preview() -> Dictionary:
	return BenefitsManager.salary_preview(merc_uid, _value)


func opinion_delta() -> int:
	return int(preview().get("shift", 0))


#Only players with the "instant" Guild Survey tier see the meter move before confirming.
func _live_opinion_unlocked() -> bool:
	return String(SubscriptionManager.entitlements().get("surveyRefresh", "none")) == "instant"


func lit_level() -> int:
	return int(preview().get("preview", 0))


func face_tip() -> String:
	return String(preview().get("title", ""))


func stepper() -> PayrollStepper:
	return step_box


func fire_dialog() -> FireConfirmDialog:
	return fire_box


func text(key: String) -> String:
	if not is_node_ready():
		return ""
	match key:
		"kicker":
			return kicker_label.text
		"name":
			return title_label.text
		"employed":
			return employed_label.text
		"vacation":
			return vacation_label.text
		"lock":
			return lock_label.text if lock_label.visible else ""
		"sub":
			return step_box.sub
		"note":
			return step_box.note
		_:
			return ""


#Replaces the base confirm because confirmed carries the new salary and the opinion shift.
func press_confirm() -> void:
	var wanted: int = _value
	var shift: int = opinion_delta()
	if is_locked() or wanted == current:
		close()
		confirmed.emit(current, 0)
		return
	var _after: int = BenefitsManager.apply_salary(merc_uid, wanted)
	current = wanted
	close()
	confirmed.emit(wanted, shift)


func close() -> void:
	if is_node_ready() and fire_box.is_open():
		fire_box.visible = false
	super()


func press_fire() -> void:
	if is_locked() or not is_node_ready():
		return
	fire_box.open_for(merc_uid)


func _on_fire_confirmed(uid: int) -> void:
	close()
	fired.emit(uid)


func _on_step_changed(new_value: int) -> void:
	_value = new_value
	_refresh()


#The stepper never offers a wage the bank cannot cover; a press past the edge flashes instead.
func _apply_bounds() -> void:
	if not is_node_ready():
		return
	step_box.min_value = 1
	step_box.max_value = maxi(1, max_payable)


func _refresh() -> void:
	if not is_node_ready():
		return
	_apply_bounds()
	title = merc_name
	employed_label.text = BenefitsManager.employed_text(merc_uid)
	vacation_label.text = VACATION_PREFIX + str(BenefitsManager.vacation_days_left(merc_uid))
	var locked: bool = is_locked()
	lock_label.visible = locked
	step_box.disabled = locked
	step_box.disabled_text = BenefitsManager.LOCK_TEXT if locked else ""
	fire_link.modulate.a = DIM_ALPHA if locked else 1.0
	fire_link.tooltip_text = BenefitsManager.LOCK_TEXT if locked else ""
	var seen: Dictionary = preview()
	step_box.sub = String(seen.get("delta_text", ""))
	var raw: Variant = seen.get("color", GuiColors.CREAM)
	var tint: Color = raw
	step_box.sub_color = tint
	step_box.note = String(seen.get("was", ""))
	var unlocked: bool = _live_opinion_unlocked()
	faces_row.visible = unlocked
	if unlocked:
		faces_row.tooltip_text = face_tip()
		var lit: int = lit_level()
		for face: MoodFace in faces_row.faces:
			face.modulate.a = 1.0 if face.opinion == lit else DIM_ALPHA


func _style() -> void:
	#Every guild mood stays filled with its own tip; the previewed one is lit by opacity instead.
	for face: MoodFace in faces_row.faces:
		face.filled = true
		face.tooltip_text = PayrollLogic.mood_label(face.opinion)
		face.mouse_filter = Control.MOUSE_FILTER_PASS
	for line: Label in [employed_label, vacation_label]:
		GuiStyle.paint(line, FONT_BODY, 13, GuiColors.DIM_TEXT)
	lock_label.text = LOCK_LINE
	lock_label.custom_minimum_size = Vector2(BOX_WIDTH - WRAP_PAD, 0.0)
	GuiStyle.paint(lock_label, FONT_BODY, 13, GuiColors.AMBER)
	step_box.label = STEP_LABEL
	step_box.show_glyph = true
	fire_link.text = FIRE_TEXT
	fire_link.underline = LinkButton.UNDERLINE_MODE_ALWAYS
	GuiStyle.paint(fire_link, FONT_KICKER, 11, GuiColors.RED)
	for key: String in ["font_hover_color", "font_pressed_color"]:
		fire_link.add_theme_color_override(key, GuiColors.RED)
