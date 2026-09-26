class_name TraitListPanel extends PanelContainer

#The card grid of a trait tab: a titled header with the filter and sort button over three columns
#of cards. Rank, Tier, Severity and Major or Minor have no data source and are left out.

const CARD_SCENE: PackedScene = preload("res://Scenes/GUI/Mercs/TraitCard.tscn")

const SORT_OPTIONS: Array[String] = ["Name A-Z", "Type"]
const FILTER_OPTIONS: Array[String] = ["All", "Ancestral", "Broad", "Spell", "Tradition",
	"Heritage", "Lifepath"]
const SORT_TYPE: int = 1

signal card_selected(index: int)

@onready var title_label: Label = $Rows/Head/Title
@onready var count_label: Label = $Rows/Head/Count
@onready var filter_button: FilterSortButton = $Rows/Head/FilterSort
@onready var card_box: GridContainer = $Rows/Scroll/Cards
@onready var empty_label: Label = $Rows/Empty

var rows: Array[Dictionary] = []
var selected_index: int = -1
var empty_text: String = "Nothing matches this filter."
var accent: Color = Color("#f28c28")


func _ready() -> void:
	filter_button.sort_options = SORT_OPTIONS.duplicate()
	filter_button.filter_options = FILTER_OPTIONS.duplicate()
	filter_button.changed.connect(_on_changed)
	_rebuild()


func set_title(text: String, new_accent: Color) -> void:
	accent = new_accent
	if not is_node_ready():
		return
	title_label.text = text.to_upper()
	title_label.add_theme_color_override("font_color", accent)
	for card: TraitCard in cards():
		card.accent = accent


func set_empty_text(text: String) -> void:
	empty_text = text
	if is_node_ready():
		empty_label.text = text


func set_rows(new_rows: Array[Dictionary]) -> void:
	rows = new_rows.duplicate()
	selected_index = -1
	_rebuild()


func cards() -> Array[TraitCard]:
	var out: Array[TraitCard] = []
	if not is_node_ready():
		return out
	for child: Node in card_box.get_children():
		if child is TraitCard:
			out.append(child as TraitCard)
	return out


func card_count() -> int:
	return cards().size()


func columns() -> int:
	return card_box.columns if is_node_ready() else 0


func select(index: int) -> void:
	var list: Array[TraitCard] = cards()
	if index < 0 or index >= list.size():
		return
	selected_index = index
	for i: int in list.size():
		list[i].active = i == index
	card_selected.emit(index)


func shown_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var wanted: String = ""
	if is_node_ready() and filter_button.filter_index > 0:
		wanted = FILTER_OPTIONS[filter_button.filter_index]
	for row: Dictionary in rows:
		if wanted != "" and String(row.get("category", "")) != wanted:
			continue
		out.append(row)
	var mode: int = filter_button.sort_index if is_node_ready() else 0
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _before(a, b, mode))
	return out


static func _before(a: Dictionary, b: Dictionary, mode: int) -> bool:
	if mode == SORT_TYPE:
		var ca: String = String(a.get("category", ""))
		var cb: String = String(b.get("category", ""))
		if ca != cb:
			return ca.naturalnocasecmp_to(cb) < 0
	return String(a.get("name", "")).naturalnocasecmp_to(String(b.get("name", ""))) < 0


func _rebuild() -> void:
	if not is_node_ready():
		return
	for child: Node in card_box.get_children():
		card_box.remove_child(child)
		child.queue_free()
	var list: Array[Dictionary] = shown_rows()
	for i: int in list.size():
		var card: TraitCard = CARD_SCENE.instantiate()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_box.add_child(card)
		card.accent = accent
		card.set_row(list[i], i)
		card.card_selected.connect(select)
	count_label.text = "%d/%d" % [list.size(), rows.size()]
	empty_label.text = empty_text
	empty_label.visible = list.is_empty()


func _on_changed(_sort_index: int, _filter_index: int) -> void:
	_rebuild()
