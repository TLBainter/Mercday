class_name GraphTabs extends HBoxContainer

#The three metric sources of the viewer, in the record's order. The row uses the Merc Viewer's
#TabButton, so the active tab is the wide orange plate and the rest stay blue with their labels up.

const SOURCES: Array[String] = ["Guild", "Contract", "Merc"]
const ACTIVE_BG := Color(0.949020, 0.549020, 0.156863, 1)
const ACTIVE_TEXT := Color(0.039216, 0.058824, 0.109804, 1)
const IDLE_BG := Color(0.168627, 0.309804, 0.541176, 1)
const IDLE_HOVER := Color(0.231373, 0.435294, 0.713725, 1)
const IDLE_TEXT := Color(0.952941, 0.917647, 0.843137, 1)
const BORDER := Color(0.039216, 0.058824, 0.109804, 1)
const BORDER_WIDTH := 3

signal tab_changed(source: String)

var _source: String = "Guild"


func _ready() -> void:
	for tab: TabButton in _tabs():
		tab.tab_pressed.connect(_on_tab_pressed)
	_apply()


func current() -> String:
	return _source


func tab_count() -> int:
	return _buttons().size()


func select_source(source_name: String) -> void:
	if not SOURCES.has(source_name) or source_name == _source:
		return
	_source = source_name
	_apply()
	tab_changed.emit(_source)


func button_for(source_name: String) -> Button:
	for button: Button in _buttons():
		if String(button.name) == source_name:
			return button
	return null


func _buttons() -> Array[Button]:
	var out: Array[Button] = []
	for child: Node in get_children():
		if child is Button:
			out.append(child)
	return out


func _tabs() -> Array[TabButton]:
	var out: Array[TabButton] = []
	for child: Node in get_children():
		if child is TabButton:
			out.append(child)
	return out


static func box(bg: Color) -> StyleBoxFlat:
	var out := StyleBoxFlat.new()
	out.bg_color = bg
	out.border_color = BORDER
	out.set_border_width_all(BORDER_WIDTH)
	return out


func _apply() -> void:
	for tab: TabButton in _tabs():
		tab.active = String(tab.name) == _source


func _on_tab_pressed(index: int) -> void:
	if index < 0 or index >= SOURCES.size():
		return
	select_source(SOURCES[index])
	_apply()
