class_name GraphTabs extends HBoxContainer

#The three metric sources of the viewer, in the record's order. The row uses the Merc Viewer's
#TabButton: the active tab widens to its icon and label on the orange plate while the other two stay
#52 px icon squares sitting on the bottom edge, so the row reads as folder tabs on the chart panel.
#A source the subscription does not cover shows the lock over a dimmed icon and still reports its
#press, so the viewer can answer with its LockedPage.

const SOURCES: Array[String] = ["Guild", "Contract", "Merc"]
const ROW_HEIGHT: int = 44
const ICON_COLS: int = 16
const ICON_PX: float = 1.5
#The separation the TabButton Row keeps between the icon and the label.
const ROW_SEPARATION: float = 8.0
const LABEL_PAD: float = 16.0
const ACTIVE_BG := Color(0.949020, 0.549020, 0.156863, 1)
const ACTIVE_TEXT := Color(0.039216, 0.058824, 0.109804, 1)
const IDLE_BG := Color(0.168627, 0.309804, 0.541176, 1)
const IDLE_HOVER := Color(0.231373, 0.435294, 0.713725, 1)
const IDLE_TEXT := Color(0.952941, 0.917647, 0.843137, 1)
const BORDER := Color(0.039216, 0.058824, 0.109804, 1)
const BORDER_WIDTH := 3

signal tab_changed(source: String)

var _source: String = "Guild"
var _locked: Dictionary = {}


func _ready() -> void:
	for tab: TabButton in _tabs():
		tab.tab_pressed.connect(_on_tab_pressed)
	custom_minimum_size.y = float(ROW_HEIGHT)
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


#Marks the graph behind one tab as locked; the tab keeps answering presses.
func set_source_locked(source_name: String, on: bool) -> void:
	if not SOURCES.has(source_name):
		return
	if bool(_locked.get(source_name, false)) == on:
		return
	_locked[source_name] = on
	_apply()


func is_source_locked(source_name: String) -> bool:
	return bool(_locked.get(source_name, false))


#The width the active plate needs: the icon box, the Row separation, the label and the side pad.
func active_width(tab: TabButton) -> float:
	var icons: float = float(tab.icon_cols) * tab.icon_px
	return icons + ROW_SEPARATION + tab.text_label.get_combined_minimum_size().x + LABEL_PAD


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
		var source_name: String = String(tab.name)
		var shut: bool = is_source_locked(source_name)
		tab.icon_cols = ICON_COLS
		tab.icon_px = ICON_PX
		tab.description = source_name
		tab.locked = shut
		var state: int = MetricsGlyphs.TabState.IDLE
		if shut:
			state = MetricsGlyphs.TabState.LOCKED
		elif source_name == _source:
			state = MetricsGlyphs.TabState.ACTIVE
		tab.set_icon_texture(MetricsGlyphs.tab_icon(source_name, state))
		tab.active = source_name == _source
		_fit(tab)


#TabButton stretches its active tab over the whole row; the tabs pack to the left here instead, so
#the active plate takes only the width its icon and label need.
func _fit(tab: TabButton) -> void:
	tab.size_flags_horizontal = Control.SIZE_FILL
	if not tab.active:
		tab.custom_minimum_size = TabButton.IDLE_SIZE
		return
	tab.custom_minimum_size = Vector2(maxf(TabButton.IDLE_SIZE.x, active_width(tab)),
		float(ROW_HEIGHT))


func _on_tab_pressed(index: int) -> void:
	if index < 0 or index >= SOURCES.size():
		return
	select_source(SOURCES[index])
	_apply()
