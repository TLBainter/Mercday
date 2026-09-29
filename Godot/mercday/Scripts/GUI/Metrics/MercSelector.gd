class_name MercSelector extends Button

#Picks the merc whose metrics the Merc graph plots. The button shows that merc's portrait, name,
#level, tradition and tenure; pressing it opens a popup of the same rows, one per roster merc, with
#an All Mercs row on top that reads the team average. The row list mirrors GameState.roster and is
#rebuilt whenever the roster changes, keeping the picked uid while that merc is still hired.

const PORTRAIT_SCENE := preload("res://Scenes/GUI/Shared/MercPortrait.tscn")
const CLOSED_PORTRAIT := 44
const COMPACT_PORTRAIT := 36
const COMPACT_HEIGHT := 58
const CLOSED_HEIGHT := 60
const ROW_PORTRAIT := 30
const ROW_HEIGHT := 40
const SELECTED_SUB := Color(0.227451, 0.141176, 0.062745, 1)
const ROW_SUB := Color(0.611765, 0.776471, 0.937255, 1)
const TENURE_COLOR := Color(0.541176, 0.592157, 0.678431, 1)
const RING_COLOR := Color(0.949020, 0.549020, 0.156863, 1)
const RING_COMPACT := Color(0.611765, 0.776471, 0.937255, 1)
const HATCH_FILL := Color(0.082353, 0.133333, 0.239216, 1)
const HATCH_RING := Color(0.231373, 0.435294, 0.713725, 1)
const HATCH_LINE := Color(0.121569, 0.207843, 0.376471, 1)
const RING_WIDTH := 3.0
const RING_COMPACT_WIDTH := 2.0
const HATCH_STEP := 8.0
const ALL_NAME := "All Mercs"
const ALL_DETAIL := "Team average"
const ALL_HINT := "Select a merc for their metrics"
const NAME_SIZE := 12
const ROW_NAME_SIZE := 11
#The Margin around the popup list, top and bottom together.
const POPUP_PAD := 16
const SUB_SIZE := 11

signal merc_selected(uid: int)

@export var popup_width: int = 300
@export var compact: bool = false:
	set(value):
		compact = value
		_apply_compact()
@export var exclude_uid: int = -1:
	set(value):
		exclude_uid = value
		rebuild()

var _uids: Array[int] = []
var _index: int = -1

@onready var portrait_holder: Control = $Row/PortraitHolder
@onready var portrait: MercPortrait = $Row/PortraitHolder/Portrait
@onready var name_label: Label = $Row/Text/Name
@onready var level_label: Label = $Row/Text/Detail/Level
@onready var tradition_label: Label = $Row/Text/Detail/Tradition
@onready var tenure_label: Label = $Row/Text/Tenure
@onready var menu: PopupPanel = $Menu
@onready var list: VBoxContainer = $Menu/Margin/List


func _ready() -> void:
	pressed.connect(_on_pressed)
	portrait_holder.draw.connect(_draw_holder)
	if not GameState.roster_changed.is_connected(_on_roster_changed):
		GameState.roster_changed.connect(_on_roster_changed)
	_apply_compact()
	rebuild()


func rebuild() -> void:
	if not is_node_ready():
		return
	var held: int = selected_uid()
	_uids = []
	for view: MercView in GameState.roster:
		if view.uid == exclude_uid:
			continue
		_uids.append(view.uid)
	_index = _uids.find(held)
	_build_rows()
	_apply()


func item_count() -> int:
	return _uids.size()


#Index -1 is the All Mercs row; the rest index into the merc list.
func select(index: int) -> void:
	if index < -1 or index >= _uids.size() or index == _index:
		return
	_index = index
	_apply()
	merc_selected.emit(selected_uid())


func select_uid(uid: int) -> void:
	var index: int = _uids.find(uid) if uid >= 0 else -1
	if index < 0 and uid >= 0:
		return
	if index != _index:
		_index = index
		_apply()
	merc_selected.emit(selected_uid())


func selected_uid() -> int:
	return _uids[_index] if _index >= 0 and _index < _uids.size() else -1


#The closed caption's second line, "LVL 07 - Warrior", or the All Mercs note.
func detail_text() -> String:
	return ("%s %s" % [level_label.text, tradition_label.text]).strip_edges()


#"Hired today", "Hired N days ago" under a Trynn month, else "Hired N months ago"; a merc the
#record never hired prints nothing.
static func tenure_text(uid: int) -> String:
	var merc: MercenaryData = GameState.merc_by_uid(uid)
	if merc == null or merc.hired_minute < 0:
		return ""
	var days: int = int((CampaignClock.now() - merc.hired_minute) / float(CampaignClock.MINUTES_PER_DAY))
	if days <= 0:
		return "Hired today"
	if days < MetricsHistory.DAYS_PER_MONTH:
		return "Hired 1 day ago" if days == 1 else "Hired %d days ago" % days
	var months: int = int(days / float(MetricsHistory.DAYS_PER_MONTH))
	return "Hired 1 month ago" if months == 1 else "Hired %d months ago" % months


#The roster entry the list index stands for; the popup order may leave a merc out.
func _view_at(index: int) -> MercView:
	if index < 0 or index >= _uids.size():
		return null
	for view: MercView in GameState.roster:
		if view.uid == _uids[index]:
			return view
	return null


func _apply_compact() -> void:
	if not is_node_ready():
		return
	var art: int = COMPACT_PORTRAIT if compact else CLOSED_PORTRAIT
	custom_minimum_size = Vector2(custom_minimum_size.x,
		COMPACT_HEIGHT if compact else CLOSED_HEIGHT)
	portrait_holder.custom_minimum_size = Vector2(art, art)
	portrait.pixel_size = art
	portrait_holder.queue_redraw()


func _build_rows() -> void:
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()
	list.add_child(_make_row(-1))
	for i: int in _uids.size():
		list.add_child(_make_row(i))


func _make_row(index: int) -> Button:
	var row := Button.new()
	row.name = "RowAll" if index < 0 else "Row%d" % index
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.pressed.connect(_on_row_pressed.bind(index))
	var line := HBoxContainer.new()
	line.name = "Line"
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 6.0
	line.offset_right = -6.0
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 8)
	row.add_child(line)
	var holder := Control.new()
	holder.name = "PortraitHolder"
	holder.custom_minimum_size = Vector2(ROW_PORTRAIT, ROW_PORTRAIT)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(holder)
	var art: MercPortrait = PORTRAIT_SCENE.instantiate()
	art.name = "Portrait"
	art.pixel_size = ROW_PORTRAIT
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(art)
	if index < 0:
		holder.draw.connect(_draw_hatch.bind(holder))
	var text_box := VBoxContainer.new()
	text_box.name = "Text"
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_theme_constant_override("separation", 0)
	line.add_child(text_box)
	var merc_name := Label.new()
	merc_name.name = "Name"
	merc_name.theme_type_variation = &"TitleLabel"
	merc_name.add_theme_font_size_override("font_size", ROW_NAME_SIZE)
	merc_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	merc_name.clip_text = true
	text_box.add_child(merc_name)
	var sub := Label.new()
	sub.name = "Sub"
	sub.theme_type_variation = &"SmallLabel"
	sub.add_theme_font_size_override("font_size", SUB_SIZE)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.clip_text = true
	text_box.add_child(sub)
	return row


func _apply() -> void:
	var view: MercView = _view_at(_index)
	portrait.visible = view != null
	portrait.set_merc(view)
	portrait_holder.queue_redraw()
	name_label.text = view.name if view != null else ALL_NAME
	if view == null:
		level_label.text = ALL_DETAIL
		tradition_label.text = ""
	else:
		var tradition_text: String = view.tradition
		level_label.text = ("LVL %02d -" % view.level) if not tradition_text.is_empty() \
			else "LVL %02d" % view.level
		tradition_label.text = tradition_text
	tradition_label.add_theme_color_override("font_color",
		GuiTypes.tradition_color(tradition_label.text))
	tenure_label.text = ALL_HINT if view == null else tenure_text(selected_uid())
	tenure_label.add_theme_color_override("font_color", TENURE_COLOR)
	var rows: Array[Node] = list.get_children()
	for child: int in rows.size():
		var row: Button = rows[child] as Button
		if row == null:
			continue
		var index: int = child - 1
		var each: MercView = _view_at(index)
		var picked: bool = index == _index
		row.theme_type_variation = &"ButtonOrange" if picked else &""
		var art: MercPortrait = row.get_node("Line/PortraitHolder/Portrait") as MercPortrait
		art.visible = each != null
		art.set_merc(each)
		var merc_name: Label = row.get_node("Line/Text/Name") as Label
		merc_name.text = each.name if each != null else ALL_NAME
		merc_name.add_theme_color_override("font_color",
			SELECTED_SUB if picked else Color(0.952941, 0.917647, 0.843137, 1))
		var sub: Label = row.get_node("Line/Text/Sub") as Label
		if each == null:
			sub.text = ALL_DETAIL
		else:
			var tenure: String = tenure_text(_uids[index])
			sub.text = ("LVL %02d" % each.level) if tenure.is_empty() else \
				("LVL %02d - %s" % [each.level, tenure])
		sub.add_theme_color_override("font_color", SELECTED_SUB if picked else ROW_SUB)


#A ring around the picked portrait, or the hatched box that stands for the whole roster.
func _draw_holder() -> void:
	var rect := Rect2(Vector2.ZERO, portrait_holder.size)
	if _view_at(_index) == null:
		_hatch(portrait_holder, rect)
		return
	var width: float = RING_COMPACT_WIDTH if compact else RING_WIDTH
	portrait_holder.draw_rect(rect, RING_COMPACT if compact else RING_COLOR, false, width)


func _draw_hatch(holder: Control) -> void:
	_hatch(holder, Rect2(Vector2.ZERO, holder.size))


func _hatch(holder: Control, rect: Rect2) -> void:
	holder.draw_rect(rect, HATCH_FILL)
	var span: float = rect.size.x + rect.size.y
	var step: float = HATCH_STEP
	while step < span:
		var from := Vector2(rect.position.x + minf(step, rect.size.x),
			rect.position.y + maxf(0.0, step - rect.size.x))
		var to := Vector2(rect.position.x + maxf(0.0, step - rect.size.y),
			rect.position.y + minf(step, rect.size.y))
		holder.draw_line(from, to, HATCH_LINE, 2.0)
		step += HATCH_STEP
	holder.draw_rect(rect, HATCH_RING, false, RING_COMPACT_WIDTH)


#Pure geometry: the popup hangs under this selector's own button, left edges flush, so the first
#merc's list never drifts to the compare selector beside it. The width covers the button, so the
#rows read at any column width and nothing inside the popup has to scroll sideways.
func popup_rect() -> Rect2i:
	var rect: Rect2 = get_global_rect()
	var pos := Vector2i(int(rect.position.x), int(rect.end.y))
	var height: int = int(list.get_combined_minimum_size().y) + POPUP_PAD
	return Rect2i(pos, Vector2i(maxi(popup_width, int(rect.size.x)), height))


func _on_pressed() -> void:
	menu.popup(popup_rect())


func _on_row_pressed(index: int) -> void:
	menu.hide()
	select(index)


func _on_roster_changed() -> void:
	rebuild()
