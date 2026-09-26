class_name MetricList extends VBoxContainer

#The metric toggles of one source, in MetricsHistory.defs order. Each source keeps its own active
#set, so switching the graph tab back restores what was plotted there. The Contract source breaks
#its rows into titled groups; the other two stay flat.

const TOGGLE_SCENE := preload("res://Scenes/GUI/Metrics/MetricToggle.tscn")
#README metric line palette; the def index within the source picks the colour.
const PALETTE: Array[String] = ["#f28c28", "#5aa6e8", "#6cc36a", "#e8583f", "#f2d33d", "#a36ce8",
	"#3fc9c0", "#f07ab8", "#a0a8b8", "#ffb266", "#9cc6ef", "#3fae5a", "#c85a8a"]
const DEFAULT_ACTIVE := 2
const HEADER_SIZE := 9
#The group each Contract key sits under, in row order; a source that is not listed stays flat.
const GROUPS: Dictionary = {"Contract": [
	["Totals", ["count", "wins", "losses"]],
	["Contract # by Issuer Type", ["i1", "i2", "i3", "i4"]],
	["Averages", ["diff", "reward", "expense", "time"]]]}

signal metrics_changed(source: String)
signal focus_requested(key: String)

@export var source: String = "Merc":
	set(value):
		source = value
		_rebuild()

var _active: Dictionary = {}
var _focus_key: String = ""


func _ready() -> void:
	_rebuild()


#The metric keys plotted for a source, in def order; an unseen source takes its defaults first.
func active_keys(source_name: String) -> Array[String]:
	_ensure(source_name)
	var out: Array[String] = []
	out.assign(_active[source_name])
	return out


func set_active(source_name: String, key: String, on: bool) -> void:
	_ensure(source_name)
	var keys: Array[String] = _active[source_name]
	if on and not keys.has(key):
		keys.append(key)
		_order(source_name)
	elif not on:
		keys.erase(key)
	if source_name == source:
		for row: MetricToggle in _rows():
			if row.key == key and row.button_pressed != on:
				row.set_on(on)
	metrics_changed.emit(source_name)


#Switches every metric of one source on or off in one step, for the Show All and Hide All buttons.
func set_all(source_name: String, on: bool) -> void:
	_ensure(source_name)
	var keys: Array[String] = []
	if on:
		for def: MetricDef in defs_for(source_name):
			keys.append(def.key)
	_active[source_name] = keys
	if source_name == source:
		for row: MetricToggle in _rows():
			row.set_on(keys.has(row.key))
	metrics_changed.emit(source_name)


#Marks which row owns the Y axis; the others draw their Y button unlit.
func set_focus(key: String) -> void:
	_focus_key = key
	for row: MetricToggle in _rows():
		row.set_focused(row.key == key)


func focused_key() -> String:
	return _focus_key


func toggle_count() -> int:
	return _rows().size()


func toggle_at(index: int) -> MetricToggle:
	var rows: Array[MetricToggle] = _rows()
	return rows[index] if index >= 0 and index < rows.size() else null


#The group headers standing above the rows of the source on show.
func group_count() -> int:
	var count: int = 0
	for child: Node in get_children():
		if child is Label:
			count += 1
	return count


#The def list of one source, in the autoload's order.
static func defs_for(source_name: String) -> Array[MetricDef]:
	var out: Array[MetricDef] = []
	for def: MetricDef in MetricsHistory.defs:
		if def.source == source_name:
			out.append(def)
	return out


static func color_for(index: int) -> Color:
	return Color(PALETTE[index % PALETTE.size()])


#The group title one key sits under; an ungrouped source returns an empty string.
static func group_of(source_name: String, key: String) -> String:
	if not GROUPS.has(source_name):
		return ""
	for group: Array in GROUPS[source_name]:
		if (group[1] as Array).has(key):
			return String(group[0])
	return ""


func _rows() -> Array[MetricToggle]:
	var out: Array[MetricToggle] = []
	for child: Node in get_children():
		if child is MetricToggle:
			out.append(child)
	return out


func _ensure(source_name: String) -> void:
	if _active.has(source_name):
		return
	var keys: Array[String] = []
	for def: MetricDef in defs_for(source_name):
		if keys.size() < DEFAULT_ACTIVE:
			keys.append(def.key)
	_active[source_name] = keys


func _order(source_name: String) -> void:
	var wanted: Array[String] = _active[source_name]
	var sorted: Array[String] = []
	for def: MetricDef in defs_for(source_name):
		if wanted.has(def.key):
			sorted.append(def.key)
	_active[source_name] = sorted


func _header(title: String) -> Label:
	var text := Label.new()
	text.theme_type_variation = &"SmallLabel"
	text.add_theme_font_size_override("font_size", HEADER_SIZE)
	text.text = title
	return text


func _rebuild() -> void:
	if not is_node_ready():
		return
	_ensure(source)
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var keys: Array[String] = _active[source]
	var defs: Array[MetricDef] = defs_for(source)
	var last_group: String = ""
	for i: int in defs.size():
		var group: String = group_of(source, defs[i].key)
		if group != "" and group != last_group:
			add_child(_header(group))
			last_group = group
		var row: MetricToggle = TOGGLE_SCENE.instantiate()
		add_child(row)
		row.set_metric(defs[i].key, defs[i].label, color_for(i), defs[i].description)
		row.set_on(keys.has(defs[i].key))
		row.set_focused(defs[i].key == _focus_key)
		row.toggled.connect(_on_row_toggled.bind(defs[i].key))
		row.focus_requested.connect(_on_row_focus.bind(defs[i].key))


func _on_row_toggled(on: bool, key: String) -> void:
	set_active(source, key, on)


func _on_row_focus(key: String) -> void:
	focus_requested.emit(key)
