class_name TraitTab extends HBoxContainer

#The Perks, Drawbacks and Skills tabs share this scene; kind picks the title, the accent and the
#rows it reads. Skills has no data source yet, so it shows the panel and no cards (Q15).

enum Kind {PERKS, DRAWBACKS, SKILLS}

const TITLES: Array[String] = ["Perks", "Drawbacks", "Skills"]
const ACCENTS: Array[Color] = [Color("#f28c28"), Color("#e8583f"), Color("#5aa6e8")]
const SKILLS_TEXT: String = "Not yet designed"

@export var kind: int = Kind.PERKS

@onready var panel: TraitListPanel = $Panel
@onready var detail: TraitDetail = $Detail

var view: MercView = null


func _ready() -> void:
	panel.card_selected.connect(_on_card_selected)
	panel.set_title(TITLES[kind], ACCENTS[kind])
	detail.set_accent(ACCENTS[kind])
	if kind == Kind.SKILLS:
		panel.set_empty_text(SKILLS_TEXT)


func set_view(new_view: MercView) -> void:
	view = new_view
	if not is_node_ready():
		return
	panel.set_title(TITLES[kind], ACCENTS[kind])
	detail.set_accent(ACCENTS[kind])
	if kind == Kind.SKILLS:
		panel.set_empty_text(SKILLS_TEXT)
	panel.set_rows(rows_for(view, kind))
	detail.clear()


func card_count() -> int:
	return panel.card_count() if is_node_ready() else 0


func select_card(index: int) -> void:
	if is_node_ready():
		panel.select(index)


func detail_name() -> String:
	return detail.detail_name() if is_node_ready() else ""


func empty_text() -> String:
	return panel.empty_label.text if is_node_ready() else ""


func accent() -> Color:
	return ACCENTS[kind]


static func rows_for(source: MercView, tab_kind: int) -> Array[Dictionary]:
	if source == null:
		return []
	match tab_kind:
		Kind.PERKS:
			return source.perks
		Kind.DRAWBACKS:
			return source.drawbacks
	return source.skills


func _on_card_selected(index: int) -> void:
	var shown: Array[Dictionary] = panel.shown_rows()
	if index < 0 or index >= shown.size():
		detail.clear()
		return
	detail.set_row(shown[index])
