class_name SalaryDialog extends Control

#The wage popup, shared by the Merc Viewer and the Payroll page: the merc, the eleven guild moods
#with the previewed one lit, a held stepper and the Fire link. Confirm is the only wage confirm and
#writes through BenefitsManager. It rides GuiFrameStack like the other modal frames, so Esc reaches
#the topmost one, and its box stays in the band above the bottom bar.

signal confirmed(new_salary: int, opinion_delta: int)
signal cancelled
signal fired(uid: int)

const FONT_TITLE: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const FONT_KICKER: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const FONT_BODY: FontVariation = preload("res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres")
const STYLE_FLAT: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_btn_flat.tres")
const FACE_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/MoodFace.tscn")

const KICKER_TEXT: String = "Adjust Salary"
const STEP_LABEL: String = "Monthly Salary"
const VACATION_PREFIX: String = "Vacation Days Remaining: "
const LOCK_LINE: String = "Salary can only be changed while this merc is Available or Resting."
const FIRE_TEXT: String = "Fire"
const ORANGE: Color = Color("#f28c28")
const GREEN: Color = Color("#6cc36a")
const RED: Color = Color("#e8583f")
const CREAM: Color = Color("#f3ead7")
const MUTED: Color = Color("#8a97ad")
const NOTE_YELLOW: Color = Color("#f2b33d")
const CLOSE_COLOR: Color = Color("#ff3b2f")
const BOX_WIDTH: float = 520.0
const CLOSE_SIZE: float = 56.0
const FACE_SCALE: int = 3
const DIM_ALPHA: float = 0.35
const BOX_INSET: float = 4.0
const BOX_BORDER: int = 4
const BOX_BG: Color = Color("#1a2b4d")
const BOX_EDGE: Color = Color("#f28c28")
const EDGE_HI: Color = Color("#28447a")
const EDGE_LO: Color = Color("#111c33")
const EDGE_PX: float = 4.0
#A wrapping label reports its height at its narrowest, so the box asks for a column of single
#characters unless the label carries the width it wraps at.
const WRAP_PAD: float = 60.0

@export var hold_peak_rate: float = 100.0

@onready var backdrop: Panel = $Backdrop
@onready var box: PanelContainer = $Box
@onready var edges: Control = $Box/Edges
@onready var rows: VBoxContainer = $Box/Pad/Rows
@onready var kicker: Label = $Box/Pad/Rows/Kicker
@onready var name_label: Label = $Box/Pad/Rows/MercName
@onready var employed_label: Label = $Box/Pad/Rows/Employed
@onready var vacation_label: Label = $Box/Pad/Rows/Vacation
@onready var faces_row: HBoxContainer = $Box/Pad/Rows/Faces
@onready var step_box: PayrollStepper = $Box/Pad/Rows/Step
@onready var lock_label: Label = $Box/Pad/Rows/LockLine
@onready var cancel_button: BevelButton = $Box/Pad/Rows/Buttons/Cancel
@onready var confirm_button: BevelButton = $Box/Pad/Rows/Buttons/Confirm
@onready var fire_link: LinkButton = $Box/Pad/Rows/FireRow/Fire
@onready var close_button: Button = $Box/Overlay/Close
@onready var fire_box: FireConfirmDialog = $Fire

var merc_uid: int = 0
var merc_name: String = ""
var current: int = 0
var max_payable: int = 0

var _value: int = 1
var _faces: Array[MoodFace] = []


func _ready() -> void:
	top_level = true
	size = get_viewport().get_visible_rect().size
	edges.draw.connect(_draw_edges)
	edges.resized.connect(edges.queue_redraw)
	_style_box()
	_build_faces()
	step_box.value_changed.connect(_on_step_changed)
	confirm_button.pressed.connect(press_confirm)
	cancel_button.pressed.connect(press_cancel)
	close_button.pressed.connect(press_cancel)
	fire_link.pressed.connect(press_fire)
	fire_box.confirmed.connect(_on_fire_confirmed)
	_style()
	_refresh()
	hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		GuiFrameStack.remove(self)


func open_for(view: MercView) -> void:
	if view == null:
		return
	merc_uid = view.uid
	merc_name = view.name
	current = view.monthly_salary
	max_payable = maxi(current, GameState.bank_notes)
	_apply_bounds()
	set_value(current)
	size = get_viewport().get_visible_rect().size
	show()
	_center()
	GuiFrameStack.push(self)


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
			return kicker.text
		"name":
			return name_label.text
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


func press_confirm() -> void:
	var wanted: int = _value
	var shift: int = opinion_delta()
	if is_locked() or wanted == current:
		_dismiss()
		confirmed.emit(current, 0)
		return
	var _after: int = BenefitsManager.apply_salary(merc_uid, wanted)
	current = wanted
	_dismiss()
	confirmed.emit(wanted, shift)


func press_cancel() -> void:
	_dismiss()
	cancelled.emit()


func press_fire() -> void:
	if is_locked() or not is_node_ready():
		return
	fire_box.open_for(merc_uid)


func _on_fire_confirmed(uid: int) -> void:
	_dismiss()
	fired.emit(uid)


func _on_step_changed(new_value: int) -> void:
	_value = new_value
	_refresh()


func _dismiss() -> void:
	if is_node_ready() and fire_box.is_open():
		fire_box.visible = false
	hide()
	GuiFrameStack.remove(self)


#The eleven guild moods of the row, lowest first; the previewed one keeps full opacity.
func _build_faces() -> void:
	for i: int in SalarySystem.OPINION_MAX - SalarySystem.OPINION_MIN + 1:
		var level: int = SalarySystem.OPINION_MIN + i
		var face: MoodFace = FACE_SCENE.instantiate() as MoodFace
		face.guild = true
		face.pixel_scale = FACE_SCALE
		face.opinion = level
		face.tooltip_text = PayrollLogic.mood_label(level)
		face.mouse_filter = Control.MOUSE_FILTER_PASS
		faces_row.add_child(face)
		_faces.append(face)


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
	name_label.text = merc_name
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
	var raw: Variant = seen.get("color", CREAM)
	var tint: Color = raw
	step_box.sub_color = tint
	step_box.note = String(seen.get("was", ""))
	faces_row.tooltip_text = String(seen.get("title", ""))
	var lit: int = int(seen.get("preview", 0))
	for i: int in _faces.size():
		var level: int = SalarySystem.OPINION_MIN + i
		_faces[i].modulate.a = 1.0 if level == lit else DIM_ALPHA


func _style() -> void:
	rows.add_theme_constant_override("separation", 14)
	faces_row.add_theme_constant_override("separation", 6)
	kicker.text = KICKER_TEXT
	kicker.add_theme_font_override("font", FONT_KICKER)
	kicker.add_theme_font_size_override("font_size", 11)
	kicker.add_theme_color_override("font_color", Color("#9cc6ef"))
	name_label.add_theme_font_override("font", FONT_TITLE)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", ORANGE)
	for line: Label in [employed_label, vacation_label]:
		line.add_theme_font_override("font", FONT_BODY)
		line.add_theme_font_size_override("font_size", 13)
		line.add_theme_color_override("font_color", MUTED)
	lock_label.text = LOCK_LINE
	lock_label.custom_minimum_size = Vector2(BOX_WIDTH - WRAP_PAD, 0.0)
	lock_label.add_theme_font_override("font", FONT_BODY)
	lock_label.add_theme_font_size_override("font_size", 13)
	lock_label.add_theme_color_override("font_color", NOTE_YELLOW)
	step_box.label = STEP_LABEL
	step_box.show_glyph = true
	fire_link.text = FIRE_TEXT
	fire_link.underline = LinkButton.UNDERLINE_MODE_ALWAYS
	fire_link.add_theme_font_override("font", FONT_KICKER)
	fire_link.add_theme_font_size_override("font_size", 11)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		fire_link.add_theme_color_override(key, RED)
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(CLOSE_SIZE, CLOSE_SIZE)
	close_button.add_theme_font_override("font", FONT_KICKER)
	close_button.add_theme_font_size_override("font_size", 24)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		close_button.add_theme_stylebox_override(state, STYLE_FLAT)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		close_button.add_theme_color_override(key, CLOSE_COLOR)


#The box carries the ConfirmDialog look the prototype draws it with: the deep panel fill, the four
#pixel orange frame and the inset highlight the Edges child paints.
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


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if GuiFrameStack.top() != self:
		return
	if fire_box.is_open():
		fire_box.press_cancel()
		get_viewport().set_input_as_handled()
		return
	press_cancel()
	get_viewport().set_input_as_handled()
