class_name FireConfirmDialog extends Control

#The last word before a merc is let go: who they are, what the guild would be left without and what
#the mood costs. It is drawn over the salary dialog, so the overlay covers that box too. Confirm
#calls BenefitsManager.fire once; a refused firing closes this box and leaves the salary dialog up.

const FONT_TITLE: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const FONT_KICKER: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const FONT_BODY: FontVariation = preload("res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres")
const STYLE_OVERLAY: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_overlay.tres")
const STYLE_BOX: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_fire_box.tres")
const STYLE_NOTE: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_note_row.tres")

const CREAM: Color = Color("#f3ead7")
const SKY: Color = Color("#9cc6ef")
const MUTED: Color = Color("#8a97ad")
const RED: Color = Color("#e8583f")
const DARK: Color = Color("#0a0f1c")
const KICKER_TEXT: String = "Fire Merc"
const EMPLOYED_TEXT: String = "Employed For"
const CANCEL_TEXT: String = "Cancel"
const CONFIRM_TEXT: String = "Confirm"
const BODY_TEXT: String = "This merc will leave the guild and be removed from your roster. " \
	+ "Their opinion of the guild will drop sharply."
const BOX_WIDTH: float = 500.0
#A wrapping label reports its height at its narrowest, so the box asks for a column of single
#characters unless the label carries the width it wraps at.
const WRAP_PAD: float = 60.0
const BUTTON_HEIGHT: float = 36.0
const PLATE: int = 70
const SQUARE: float = 6.0

signal confirmed(uid: int)
signal cancelled

@onready var overlay: Panel = $Overlay
@onready var box: PanelContainer = $Center/Box
@onready var rows: VBoxContainer = $Center/Box/Rows
@onready var kicker: Label = $Center/Box/Rows/Kicker
@onready var name_label: Label = $Center/Box/Rows/NameLabel
@onready var head: HBoxContainer = $Center/Box/Rows/Head
@onready var sigil_box: Control = $Center/Box/Rows/Head/SigilBox
@onready var sigil: TraditionSigil = $Center/Box/Rows/Head/SigilBox/Sigil
@onready var badge: PayrollBadge = $Center/Box/Rows/Head/Badge
@onready var face: MoodFace = $Center/Box/Rows/Head/Face
@onready var employed_head: Label = $Center/Box/Rows/EmployedRow/EmployedHead
@onready var employed_text: Label = $Center/Box/Rows/EmployedRow/EmployedText
@onready var note_list: VBoxContainer = $Center/Box/Rows/Notes
@onready var body_label: Label = $Center/Box/Rows/Body
@onready var cancel_button: BevelButton = $Center/Box/Rows/Buttons/Cancel
@onready var confirm_button: BevelButton = $Center/Box/Rows/Buttons/Confirm

var _uid: int = 0
var _notes: Array[Dictionary] = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_theme_stylebox_override("panel", STYLE_OVERLAY)
	box.add_theme_stylebox_override("panel", STYLE_BOX)
	box.custom_minimum_size = Vector2(BOX_WIDTH, 0.0)
	cancel_button.pressed.connect(press_cancel)
	confirm_button.pressed.connect(press_confirm)
	_style()
	ModalFrame.fit(self, overlay, $Center as Control)


func open_for(merc_uid: int) -> void:
	_uid = merc_uid
	visible = true
	ModalFrame.fit(self, overlay, $Center as Control)
	GuiFrameStack.push(self)
	_fill()


func is_open() -> bool:
	return visible


func uid() -> int:
	return _uid


func note_count() -> int:
	return _notes.size()


func note_text(index: int) -> String:
	if index < 0 or index >= _notes.size():
		return ""
	return String(_notes[index].get("text", ""))


func note_color(index: int) -> Color:
	if index < 0 or index >= _notes.size():
		return CREAM
	var raw: Variant = _notes[index].get("color", CREAM)
	var out: Color = raw
	return out


func text(key: String) -> String:
	if not is_node_ready():
		return ""
	match key:
		"kicker":
			return kicker.text
		"name":
			return name_label.text
		"employed":
			return employed_text.text
		"body":
			return body_label.text
		"level":
			return badge.text()
		_:
			return ""


func press_confirm() -> void:
	if not visible:
		return
	var target: int = _uid
	var done: bool = BenefitsManager.fire(target)
	visible = false
	GuiFrameStack.remove(self)
	if done:
		confirmed.emit(target)


func press_cancel() -> void:
	if not visible:
		return
	visible = false
	GuiFrameStack.remove(self)
	cancelled.emit()


func _exit_tree() -> void:
	GuiFrameStack.remove(self)


func _fill() -> void:
	if not is_node_ready():
		return
	var summary: Dictionary = BenefitsManager.fire_summary(_uid)
	name_label.text = String(summary.get("name", ""))
	employed_text.text = String(summary.get("employed_text", ""))
	var tradition: String = String(summary.get("tradition", ""))
	sigil.tradition = tradition
	sigil.tint = GuiTypes.tradition_color(tradition)
	var view: MercView = BenefitsManager.view_of(_uid)
	badge.level = view.level if view != null else 0
	face.guild = true
	face.opinion = int(summary.get("opinion", 0))
	_notes = _note_rows(summary)
	_build_notes()


func _note_rows(summary: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in BenefitsManager.fire_notes(_uid):
		out.append(row)
	var raw: Variant = summary.get("friends_color", MUTED)
	var tint: Color = raw
	out.append({"text": String(summary.get("friends_text", "")), "color": tint})
	return out


func _build_notes() -> void:
	for child: Node in note_list.get_children():
		note_list.remove_child(child)
		child.queue_free()
	for i: int in _notes.size():
		note_list.add_child(_note_row(note_text(i), note_color(i)))


func _note_row(body: String, tint: Color) -> PanelContainer:
	var holder: PanelContainer = PanelContainer.new()
	holder.add_theme_stylebox_override("panel", STYLE_NOTE)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(line)
	var mark := ColorRect.new()
	mark.color = tint
	mark.custom_minimum_size = Vector2(SQUARE, SQUARE)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(mark)
	var label: Label = Label.new()
	label.text = body
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT_BODY)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", tint)
	line.add_child(label)
	return holder


func _style() -> void:
	rows.add_theme_constant_override("separation", 14)
	head.add_theme_constant_override("separation", 14)
	note_list.add_theme_constant_override("separation", 8)
	kicker.text = KICKER_TEXT
	kicker.add_theme_font_override("font", FONT_KICKER)
	kicker.add_theme_font_size_override("font_size", 11)
	kicker.add_theme_color_override("font_color", SKY)
	name_label.add_theme_font_override("font", FONT_TITLE)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", RED)
	sigil_box.custom_minimum_size = Vector2(PLATE, PLATE)
	sigil.pixel_scale = 4
	badge.plate = PLATE
	badge.kicker_size = 9
	badge.value_size = 24
	face.pixel_scale = 4
	employed_head.text = EMPLOYED_TEXT
	employed_head.add_theme_font_override("font", FONT_KICKER)
	employed_head.add_theme_font_size_override("font_size", 10)
	employed_head.add_theme_color_override("font_color", SKY)
	employed_text.add_theme_font_override("font", FONT_BODY)
	employed_text.add_theme_font_size_override("font_size", 14)
	employed_text.add_theme_color_override("font_color", CREAM)
	body_label.text = BODY_TEXT
	body_label.custom_minimum_size = Vector2(BOX_WIDTH - WRAP_PAD, 0.0)
	body_label.add_theme_font_override("font", FONT_BODY)
	body_label.add_theme_font_size_override("font_size", 14)
	body_label.add_theme_color_override("font_color", MUTED)
	cancel_button.text = CANCEL_TEXT
	cancel_button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	cancel_button.add_theme_font_override("font", FONT_KICKER)
	cancel_button.add_theme_font_size_override("font_size", 12)
	cancel_button.text_color = DARK
	confirm_button.text = CONFIRM_TEXT
	confirm_button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	confirm_button.add_theme_font_override("font", FONT_KICKER)
	confirm_button.add_theme_font_size_override("font_size", 12)
	confirm_button.text_color = CREAM


#Esc answers this dialog only while it is the top frame of the stack.
func _unhandled_input(event: InputEvent) -> void:
	if GuiFrameStack.consume_escape(self, event):
		press_cancel()
