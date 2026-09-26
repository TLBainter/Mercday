class_name MercHeader extends PanelContainer

#The merc card of the centre column: the title, the large portrait with its status band, the name
#block, the four lineage boxes and the salary chip pinned at the foot. The chip relays its click
#so the wage dialog opens from any tab. Tradition and level sit on Overview.

signal salary_clicked

const EMPTY_TEXT: String = "None"
const PANEL_MARGIN: float = 8.0

@onready var title_label: Label = $Rows/Title
@onready var portrait_frame: Panel = $Rows/PortraitHolder/Frame
@onready var portrait: MercPortrait = $Rows/PortraitHolder/Portrait
@onready var name_label: Label = $Rows/NameBlock/MercName
@onready var surname_label: Label = $Rows/NameBlock/Surname
@onready var heritage_label: Label = $Rows/Lineage/Heritage/Lines/Value
@onready var primary_label: Label = $Rows/Lineage/Primary/Lines/Value
@onready var secondary_label: Label = $Rows/Lineage/Secondary/Lines/Value
@onready var age_label: Label = $Rows/Lineage/Age/Lines/Value
@onready var strip: MercStatusStrip = $Rows/PortraitHolder/Status
@onready var salary: SalaryModule = $Rows/Salary

var view: MercView = null

var _full_name: String = ""


func _ready() -> void:
	var box: StyleBoxFlat = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if box != null:
		box.content_margin_left = PANEL_MARGIN
		box.content_margin_top = PANEL_MARGIN
		box.content_margin_right = PANEL_MARGIN
		box.content_margin_bottom = PANEL_MARGIN
		add_theme_stylebox_override("panel", box)
	salary.clicked.connect(_on_salary_clicked)


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
		primary_label.text = EMPTY_TEXT
		secondary_label.text = EMPTY_TEXT
		age_label.text = EMPTY_TEXT
		portrait.set_merc(null)
		strip.hide()
		salary.hide()
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
	primary_label.text = lineage_text(view, "bloodline", "ancestry")
	secondary_label.text = lineage_text(view, "recessive_bloodline", "recessive_ancestry")
	age_label.text = age_text(view)
	strip.status = view.status
	strip.time_left_minutes = int(round(view.status_time_left_hours * 60.0))
	salary.set_salary(view.monthly_salary, GameState.bank_notes)


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


func salary_chip() -> SalaryModule:
	return salary


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
	if source == null or source.merc == null:
		return ""
	var data: AncestryData = source.merc.get(field) as AncestryData
	return data.ancestry_name if data != null else ""


#"{age} {age_group}"; a sample row with no merc resource shows the band alone.
static func age_text(source: MercView) -> String:
	var band: String = source.age_group if source.age_group != "" else EMPTY_TEXT
	if source.merc == null:
		return band
	return "%d %s" % [source.merc.age, band]


func _on_salary_clicked() -> void:
	salary_clicked.emit()
