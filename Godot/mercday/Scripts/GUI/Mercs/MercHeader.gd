class_name MercHeader extends PanelContainer

#The merc card of the centre column: the title, the large portrait with its status band, the name
#block, the lineage boxes and the salary chip pinned at the foot. The chip relays its click so the
#wage dialog opens from any tab. Tradition and level sit on Overview. Six lineage halves are sold by
#an upgrade, so each keeps its caption and swaps its value for a lock, and the band takes its colour
#from GuiTypes so one table rules every status the guild reads.

signal salary_clicked

const EMPTY_TEXT: String = "None"
const PANEL_MARGIN: float = 8.0
const APPLICANT_TEXT: String = "Applicant"
const APPLICANT_COLOR: Color = GuiColors.AMBER
const GREY_TINT: Color = GuiColors.GREY_TINT_FADED

@onready var title_label: Label = $Rows/Title
@onready var portrait_frame: Panel = $Rows/PortraitHolder/Frame
@onready var portrait: MercPortrait = $Rows/PortraitHolder/Portrait
@onready var name_label: Label = $Rows/NameBlock/MercName
@onready var surname_label: Label = $Rows/NameBlock/Surname
@onready var note_label: Label = $Rows/Note
@onready var heritage_field: InfoField = $Rows/Scroll/Lineage/Heritage
@onready var primary_field: InfoField = $Rows/Scroll/Lineage/Primary
@onready var primary_blood_lock: FeatureLock = $Rows/Scroll/Lineage/Primary/Rows/BloodLock
@onready var primary_ancestry_lock: FeatureLock = $Rows/Scroll/Lineage/Primary/Rows/AncestryLock
@onready var secondary_field: InfoField = $Rows/Scroll/Lineage/Secondary
@onready var secondary_blood_lock: FeatureLock = $Rows/Scroll/Lineage/Secondary/Rows/BloodLock
@onready var secondary_ancestry_lock: FeatureLock = $Rows/Scroll/Lineage/Secondary/Rows/AncestryLock
@onready var age_field: InfoField = $Rows/Scroll/Lineage/Age
@onready var criminality_field: InfoField = $Rows/Scroll/Lineage/Criminality
@onready var strip: MercStatusStrip = $Rows/PortraitHolder/Status
@onready var time_tag: Label = $Rows/PortraitHolder/TimeLeft
@onready var salary: SalaryModule = $Rows/Salary

var view: MercView = null
#An applicant has no wage on the books and no status of their own.
var applicant_mode: bool = false

var _full_name: String = ""
var _salary_filter: int = Control.MOUSE_FILTER_STOP
#Keyless: each lineage half reads its own key, so the gate only carries the plan change.
var _gate: LockGate = LockGate.new()


func _init() -> void:
	add_child(_gate, false, Node.INTERNAL_MODE_FRONT)


func _ready() -> void:
	var box: StyleBoxFlat = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if box != null:
		box.content_margin_left = PANEL_MARGIN
		box.content_margin_top = PANEL_MARGIN
		box.content_margin_right = PANEL_MARGIN
		box.content_margin_bottom = PANEL_MARGIN
		add_theme_stylebox_override("panel", box)
	_salary_filter = salary.mouse_filter
	salary.clicked.connect(_on_salary_clicked)
	_gate.changed.connect(_apply_locks)
	_apply_locks()


func set_view(new_view: MercView) -> void:
	view = new_view
	if not is_node_ready():
		return
	if view == null:
		_full_name = EMPTY_TEXT
		name_label.text = EMPTY_TEXT
		surname_label.text = ""
		surname_label.hide()
		heritage_field.value = EMPTY_TEXT
		age_field.value = EMPTY_TEXT
		criminality_field.value = EMPTY_TEXT
		portrait.set_merc(null)
		note_label.hide()
		strip.hide()
		salary.hide()
		_apply_locks()
		return
	strip.show()
	salary.show()
	portrait.set_merc(view)
	_full_name = view.name
	var parts: Array[String] = split_name(view.name)
	name_label.text = parts[0]
	surname_label.text = parts[1]
	surname_label.visible = parts[1] != ""
	heritage_field.value = view.heritage if view.heritage != "" else EMPTY_TEXT
	age_field.value = age_text(view)
	criminality_field.value = view.criminality if view.criminality != "" else EMPTY_TEXT
	salary.set_salary(view.monthly_salary, GameState.bank_notes)
	_apply_locks()
	_apply_status()


#The applicant view keeps the card whole: the band renames and the wage chip goes out of reach.
func set_applicant_mode(on: bool) -> void:
	applicant_mode = on
	if not is_node_ready():
		return
	salary.modulate = GREY_TINT if on else Color.WHITE
	salary.mouse_filter = Control.MOUSE_FILTER_IGNORE if on else _salary_filter
	_apply_status()


func merc_name() -> String:
	return _full_name if is_node_ready() else ""


func first_name() -> String:
	return name_label.text if is_node_ready() else ""


func surname() -> String:
	return surname_label.text if is_node_ready() else ""


func primary_text() -> String:
	return primary_field.value if is_node_ready() else ""


func secondary_text() -> String:
	return secondary_field.value if is_node_ready() else ""


func age_line() -> String:
	return age_field.value if is_node_ready() else ""


func criminality_line() -> String:
	return criminality_field.value if is_node_ready() else ""


func status_line() -> String:
	return strip.text if is_node_ready() else ""


func status_color() -> Color:
	return strip.get_theme_color("font_color") if is_node_ready() else Color.WHITE


func note_text() -> String:
	return note_label.text if is_node_ready() and note_label.visible else ""


func salary_chip() -> SalaryModule:
	return salary


#The status the band reads: an away merc shows where they are.
func shown_status() -> int:
	return GuiTypes.MercStatus.AVAILABLE if view == null else view.shown_status()


#The first name stays large; everything after the first space drops to the small white line.
static func split_name(full: String) -> Array[String]:
	var parts: PackedStringArray = full.split(" ", false, 1)
	var out: Array[String] = ["", ""]
	if parts.size() > 0:
		out[0] = parts[0]
	if parts.size() > 1:
		out[1] = parts[1]
	return out


static func ancestry_name(source: MercView, field: String) -> String:
	if source == null:
		return ""
	if source.merc == null:
		return _flat_lineage(source, field)
	var data: AncestryData = source.merc.get(field) as AncestryData
	return data.ancestry_name if data != null else ""


#A view with no engine merc, an applicant or a sample row, carries one ancestry and one bloodline,
#so the Primary row prints them and the Secondary row has nothing to print.
static func _flat_lineage(source: MercView, field: String) -> String:
	match field:
		"ancestry":
			return source.ancestry_text
		"bloodline":
			return source.bloodline_text
	return ""


#"{age} {age_group}"; a sample or applicant row with no merc resource shows the band alone.
static func age_text(source: MercView) -> String:
	var band: String = source.age_group if source.age_group != "" else EMPTY_TEXT
	if source.merc == null:
		return band
	return "%d %s" % [source.merc.age, band]


func _apply_status() -> void:
	if not is_node_ready() or view == null:
		return
	if applicant_mode:
		strip.status = GuiTypes.MercStatus.AVAILABLE
		strip.text = APPLICANT_TEXT.to_upper() if strip.band else APPLICANT_TEXT
		strip.add_theme_color_override("font_color", APPLICANT_COLOR)
		MercStatusStrip.dress_time_tag(time_tag, 0)
		note_label.hide()
		return
	var shown: int = shown_status()
	strip.status = shown
	strip.add_theme_color_override("font_color", GuiTypes.merc_status_color(shown))
	MercStatusStrip.dress_time_tag(time_tag, int(round(view.status_time_left_hours * 60.0)))
	var note: String = view.loan_note(shown)
	note_label.text = note
	note_label.visible = note != ""


func _apply_locks() -> void:
	if not is_node_ready():
		return
	var ent: Dictionary = SubscriptionManager.entitlements()
	_gate_lineage(primary_field, primary_blood_lock, primary_ancestry_lock, "bloodline",
		"ancestry", ent)
	_gate_lineage(secondary_field, secondary_blood_lock, secondary_ancestry_lock,
		"recessive_bloodline", "recessive_ancestry", ent)


#Each lineage row is two halves under two gates, so a met half still prints beside a shut one.
#The field hides a blank value, so a row with both halves shut shows only its two locks.
func _gate_lineage(field: InfoField, blood_lock: FeatureLock, ancestry_lock: FeatureLock,
		blood_field: String, ancestry_field: String, ent: Dictionary) -> void:
	var blood_ok: bool = MercLocks.entitled(MercLocks.K_BLOODLINE, ent)
	var ancestry_ok: bool = MercLocks.entitled(MercLocks.K_ANCESTRY, ent)
	var parts: Array[String] = []
	if blood_ok:
		var blood: String = ancestry_name(view, blood_field)
		if blood != "":
			parts.append(blood)
	if ancestry_ok:
		var stock: String = ancestry_name(view, ancestry_field)
		if stock != "":
			parts.append(stock)
	if not (blood_ok or ancestry_ok):
		field.value = ""
	else:
		field.value = EMPTY_TEXT if parts.is_empty() else " ".join(parts)
	MercLocks.apply(blood_lock, MercLocks.K_BLOODLINE, MercLocks.LOCK_HEIGHT,
		MercLocks.feature_of(MercLocks.K_BLOODLINE))
	MercLocks.apply(ancestry_lock, MercLocks.K_ANCESTRY, MercLocks.LOCK_HEIGHT,
		MercLocks.feature_of(MercLocks.K_ANCESTRY))
	blood_lock.visible = not blood_ok
	ancestry_lock.visible = not ancestry_ok


func _on_salary_clicked() -> void:
	salary_clicked.emit()
