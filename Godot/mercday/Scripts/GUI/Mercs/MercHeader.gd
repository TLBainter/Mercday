class_name MercHeader extends PanelContainer

#The merc card of the centre column: the title, the large portrait with its status band, the name
#block, the lineage boxes and the salary chip pinned at the foot. The chip relays its click so the
#wage dialog opens from any tab. Tradition and level sit on Overview. Six lineage halves are sold by
#an upgrade, so each keeps its caption and swaps its value for a lock, and the band takes its colour
#from GuiTypes so one table rules every status the guild reads.

signal salary_clicked

const EMPTY_TEXT: String = "None"
const PANEL_MARGIN: float = 8.0
const LOCK_HEIGHT: float = 20.0
const APPLICANT_TEXT: String = "Applicant"
const APPLICANT_COLOR: Color = Color("#f2b33d")
const FINANCE_PATH: String = "/root/FinanceManager"
const GREY_TINT: Color = Color(GuiColors.GRAY_ICON_BRIGHTNESS, GuiColors.GRAY_ICON_BRIGHTNESS,
	GuiColors.GRAY_ICON_BRIGHTNESS, 0.4)

@onready var title_label: Label = $Rows/Title
@onready var portrait_frame: Panel = $Rows/PortraitHolder/Frame
@onready var portrait: MercPortrait = $Rows/PortraitHolder/Portrait
@onready var name_label: Label = $Rows/NameBlock/MercName
@onready var surname_label: Label = $Rows/NameBlock/Surname
@onready var note_label: Label = $Rows/Note
@onready var heritage_label: Label = $Rows/Scroll/Lineage/Heritage/Lines/Value
@onready var heritage_lock: FeatureLock = $Rows/Scroll/Lineage/Heritage/Lines/Lock
@onready var primary_label: Label = $Rows/Scroll/Lineage/Primary/Lines/Value
@onready var primary_blood_lock: FeatureLock = $Rows/Scroll/Lineage/Primary/Lines/BloodLock
@onready var primary_ancestry_lock: FeatureLock = $Rows/Scroll/Lineage/Primary/Lines/AncestryLock
@onready var secondary_label: Label = $Rows/Scroll/Lineage/Secondary/Lines/Value
@onready var secondary_blood_lock: FeatureLock = $Rows/Scroll/Lineage/Secondary/Lines/BloodLock
@onready var secondary_ancestry_lock: FeatureLock = $Rows/Scroll/Lineage/Secondary/Lines/AncestryLock
@onready var age_label: Label = $Rows/Scroll/Lineage/Age/Lines/Value
@onready var age_lock: FeatureLock = $Rows/Scroll/Lineage/Age/Lines/Lock
@onready var criminality_label: Label = $Rows/Scroll/Lineage/Criminality/Lines/Value
@onready var criminality_lock: FeatureLock = $Rows/Scroll/Lineage/Criminality/Lines/Lock
@onready var strip: MercStatusStrip = $Rows/PortraitHolder/Status
@onready var salary: SalaryModule = $Rows/Salary

var view: MercView = null
#An applicant has no wage on the books and no status of their own.
var applicant_mode: bool = false

var _full_name: String = ""
var _salary_filter: int = Control.MOUSE_FILTER_STOP


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
	if not SubscriptionManager.changed.is_connected(_apply_locks):
		SubscriptionManager.changed.connect(_apply_locks)
	_apply_locks()


func _exit_tree() -> void:
	if SubscriptionManager.changed.is_connected(_apply_locks):
		SubscriptionManager.changed.disconnect(_apply_locks)


func set_view(new_view: MercView) -> void:
	view = new_view
	if not is_node_ready():
		return
	if view == null:
		_full_name = EMPTY_TEXT
		name_label.text = EMPTY_TEXT
		surname_label.text = ""
		surname_label.hide()
		heritage_label.text = EMPTY_TEXT
		age_label.text = EMPTY_TEXT
		criminality_label.text = EMPTY_TEXT
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
	heritage_label.text = view.heritage if view.heritage != "" else EMPTY_TEXT
	age_label.text = age_text(view)
	criminality_label.text = view.criminality if view.criminality != "" else EMPTY_TEXT
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
	return primary_label.text if is_node_ready() else ""


func secondary_text() -> String:
	return secondary_label.text if is_node_ready() else ""


func age_line() -> String:
	return age_label.text if is_node_ready() else ""


func criminality_line() -> String:
	return criminality_label.text if is_node_ready() else ""


func status_line() -> String:
	return strip.text if is_node_ready() else ""


func status_color() -> Color:
	return strip.get_theme_color("font_color") if is_node_ready() else Color.WHITE


func note_text() -> String:
	return note_label.text if is_node_ready() and note_label.visible else ""


func salary_chip() -> SalaryModule:
	return salary


func status_strip() -> MercStatusStrip:
	return strip


func locks() -> Array[FeatureLock]:
	var out: Array[FeatureLock] = []
	if not is_node_ready():
		return out
	out.append(heritage_lock)
	out.append(primary_blood_lock)
	out.append(primary_ancestry_lock)
	out.append(secondary_blood_lock)
	out.append(secondary_ancestry_lock)
	out.append(age_lock)
	out.append(criminality_lock)
	return out


#The status the band reads: an away merc shows where they are once GameState knows how to say.
func shown_status() -> int:
	if view == null:
		return GuiTypes.MercStatus.AVAILABLE
	if GameState.has_method("is_away") and GameState.has_method("away_status"):
		if bool(GameState.call("is_away", view.uid)):
			return int(GameState.call("away_status", view.uid))
	return view.status


#The loan line under the name, when the ledger has one to give.
func loan_note(uid: int, status: int) -> String:
	if status != GuiTypes.MercStatus.LOAN:
		return ""
	var finance: Node = get_node_or_null(FINANCE_PATH)
	if finance == null or not finance.has_method("loan_note"):
		return ""
	return String(finance.call("loan_note", uid))


#The first name stays large; everything after the first space drops to the small white line.
static func split_name(full: String) -> Array[String]:
	var parts: PackedStringArray = full.split(" ", false, 1)
	var out: Array[String] = ["", ""]
	if parts.size() > 0:
		out[0] = parts[0]
	if parts.size() > 1:
		out[1] = parts[1]
	return out


#"{bloodline} {ancestry}" off the merc resource; a row with neither half reads as EMPTY_TEXT.
static func lineage_text(source: MercView, bloodline_key: String, ancestry_key: String) -> String:
	var parts: Array[String] = []
	var line: String = ancestry_name(source, bloodline_key)
	if line != "":
		parts.append(line)
	var stock: String = ancestry_name(source, ancestry_key)
	if stock != "":
		parts.append(stock)
	return EMPTY_TEXT if parts.is_empty() else " ".join(parts)


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
		strip.time_left_minutes = 0
		strip.text = APPLICANT_TEXT.to_upper() if strip.band else APPLICANT_TEXT
		strip.add_theme_color_override("font_color", APPLICANT_COLOR)
		note_label.hide()
		return
	var shown: int = shown_status()
	strip.status = shown
	strip.time_left_minutes = int(round(view.status_time_left_hours * 60.0))
	strip.add_theme_color_override("font_color", GuiTypes.merc_status_color(shown))
	var note: String = loan_note(view.uid, shown)
	note_label.text = note
	note_label.visible = note != ""


func _apply_locks() -> void:
	if not is_node_ready():
		return
	var ent: Dictionary = SubscriptionManager.entitlements()
	_gate(heritage_label, heritage_lock, MercLocks.K_HERITAGE, ent)
	_gate(age_label, age_lock, MercLocks.K_AGE, ent)
	_gate(criminality_label, criminality_lock, MercLocks.K_CRIMINALITY, ent)
	_gate_lineage(primary_label, primary_blood_lock, primary_ancestry_lock, "bloodline",
		"ancestry", ent)
	_gate_lineage(secondary_label, secondary_blood_lock, secondary_ancestry_lock,
		"recessive_bloodline", "recessive_ancestry", ent)


#A sold row keeps its caption and shows the lock where the value would read.
func _gate(label: Label, lock: FeatureLock, key: String, ent: Dictionary) -> void:
	var ok: bool = MercLocks.entitled(key, ent)
	label.visible = ok
	MercLocks.apply(lock, key, LOCK_HEIGHT)
	lock.visible = not ok


#Each lineage row is two halves under two gates, so a met half still prints beside a shut one.
func _gate_lineage(label: Label, blood_lock: FeatureLock, ancestry_lock: FeatureLock,
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
	label.text = EMPTY_TEXT if parts.is_empty() else " ".join(parts)
	label.visible = blood_ok or ancestry_ok
	MercLocks.apply(blood_lock, MercLocks.K_BLOODLINE, LOCK_HEIGHT,
		MercLocks.feature_of(MercLocks.K_BLOODLINE))
	MercLocks.apply(ancestry_lock, MercLocks.K_ANCESTRY, LOCK_HEIGHT,
		MercLocks.feature_of(MercLocks.K_ANCESTRY))
	blood_lock.visible = not blood_ok
	ancestry_lock.visible = not ancestry_ok


func _on_salary_clicked() -> void:
	salary_clicked.emit()
