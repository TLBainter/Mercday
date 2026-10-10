class_name FireConfirmDialog extends ModalDialog

#The last word before a merc is let go: who they are, what the guild would be left without and what
#the mood costs. It is drawn over the salary dialog, so the backdrop covers that box too. Confirm
#calls BenefitsManager.fire once; a refused firing closes this box and leaves the salary dialog up.

const STYLE_NOTE: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_note_row.tres")

const KICKER_TEXT: String = "Fire Merc"
const EMPLOYED_TEXT: String = "Employed For"
const BODY_TEXT: String = "This merc will leave the guild and be removed from your roster. " \
	+ "Their opinion of the guild will drop sharply."
const BOX_WIDTH: float = 500.0
#A wrapping label reports its height at its narrowest, so the box asks for a column of single
#characters unless the label carries the width it wraps at.
const WRAP_PAD: float = 60.0
const PLATE: int = 70
const SQUARE: float = 6.0

@onready var sigil_box: Control = $Box/Pad/Rows/Plates/SigilBox
@onready var sigil: TraditionSigil = $Box/Pad/Rows/Plates/SigilBox/Sigil
@onready var badge: LevelBadge = $Box/Pad/Rows/Plates/Badge
@onready var face: MoodFace = $Box/Pad/Rows/Plates/Face
@onready var employed_head: Label = $Box/Pad/Rows/EmployedRow/EmployedHead
@onready var employed_text: Label = $Box/Pad/Rows/EmployedRow/EmployedText
@onready var note_list: VBoxContainer = $Box/Pad/Rows/Notes
@onready var body_label: Label = $Box/Pad/Rows/Body

var _uid: int = 0
var _notes: Array[Dictionary] = []


func _ready() -> void:
	box_width = BOX_WIDTH
	super()
	kicker = KICKER_TEXT
	_style()


func open_for(merc_uid: int) -> void:
	_uid = merc_uid
	present()
	_fill()


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
		return GuiColors.CREAM
	return _notes[index].get("color", GuiColors.CREAM) as Color


func text(key: String) -> String:
	if not is_node_ready():
		return ""
	match key:
		"kicker":
			return kicker_text()
		"name":
			return title_text()
		"employed":
			return employed_text.text
		"body":
			return body_label.text
		"level":
			return badge.number_label.text
		_:
			return ""


#Replaces the base confirm because confirmed carries the merc uid, and only after a firing lands.
func press_confirm() -> void:
	if not visible:
		return
	var target: int = _uid
	var done: bool = BenefitsManager.fire(target)
	close()
	if done:
		confirmed.emit(target)


func _fill() -> void:
	if not is_node_ready():
		return
	var summary: Dictionary = BenefitsManager.fire_summary(_uid)
	title = String(summary.get("name", ""))
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
	var tint: Color = summary.get("friends_color", GuiColors.DIM_TEXT) as Color
	out.append({"text": String(summary.get("friends_text", "")), "color": tint})
	return out


func _build_notes() -> void:
	GuiNodes.clear(note_list)
	for i: int in _notes.size():
		note_list.add_child(_note_row(note_text(i), note_color(i)))


func _note_row(body: String, tint: Color) -> PanelContainer:
	var holder: PanelContainer = PanelContainer.new()
	holder.add_theme_stylebox_override("panel", STYLE_NOTE)
	var line: HBoxContainer = GuiStyle.hbox(10)
	holder.add_child(line)
	var mark := ColorRect.new()
	mark.color = tint
	mark.custom_minimum_size = Vector2(SQUARE, SQUARE)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(mark)
	var label: Label = GuiStyle.label(body, GuiStyle.BODY, 14, tint)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	GuiNodes.ignore_mouse(holder)
	return holder


func _style() -> void:
	GuiStyle.paint(kicker_label, GuiStyle.SILK, 11, GuiColors.SKY)
	GuiStyle.paint(title_label, GuiStyle.SILK_BOLD, 18, GuiColors.RED)
	sigil_box.custom_minimum_size = Vector2(PLATE, PLATE)
	sigil.pixel_scale = 4
	badge.plate_size = Vector2(PLATE, PLATE)
	badge.kicker_size = 9
	badge.value_size = 24
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.pixel_scale = 4
	employed_head.text = EMPLOYED_TEXT
	GuiStyle.paint(employed_head, GuiStyle.SILK, 10, GuiColors.SKY)
	GuiStyle.paint(employed_text, GuiStyle.BODY, 14, GuiColors.CREAM)
	body_label.text = BODY_TEXT
	body_label.custom_minimum_size = Vector2(BOX_WIDTH - WRAP_PAD, 0.0)
	GuiStyle.paint(body_label, GuiStyle.BODY, 14, GuiColors.DIM_TEXT)
	for button: BevelButton in [cancel_button, confirm_button]:
		button.add_theme_font_override("font", GuiStyle.SILK)
		button.add_theme_font_size_override("font_size", 12)
	cancel_button.text_color = GuiColors.INK
