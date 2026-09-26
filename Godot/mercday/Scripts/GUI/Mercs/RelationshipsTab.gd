class_name RelationshipsTab extends VBoxContainer

#The guild card over a three wide grid of coworker cards. The sort key is the only control; a pair
#with no recorded history reads neutral (G9) and carries no date stamps.

const CARD_SCENE: PackedScene = preload("res://Scenes/GUI/Mercs/RelationshipCard.tscn")

const SORT_OPTIONS: Array[String] = ["Highest", "Lowest", "Longest Known", "Recently Changed"]
const SORT_HIGHEST: int = 0
const SORT_LOWEST: int = 1
const SORT_LONGEST: int = 2
const SORT_RECENT: int = 3
const GRID_COLUMNS: int = 3
const LAST_KEY: int = 1 << 30

@onready var guild: GuildRelationshipCard = $GuildCard
@onready var count_label: Label = $Head/Count
@onready var sort_button: SortButton = $Head/Sort
@onready var grid: GridContainer = $Scroll/Grid

var view: MercView = null


func _ready() -> void:
	grid.columns = GRID_COLUMNS
	sort_button.options = SORT_OPTIONS.duplicate()
	sort_button.selected = SORT_HIGHEST
	sort_button.sort_changed.connect(_on_sorted)


func set_view(new_view: MercView) -> void:
	view = new_view
	_rebuild()


func cards() -> Array[RelationshipCard]:
	var out: Array[RelationshipCard] = []
	if not is_node_ready():
		return out
	for child: Node in grid.get_children():
		if child is RelationshipCard:
			out.append(child as RelationshipCard)
	return out


func card_count() -> int:
	return cards().size()


func guild_card() -> GuildRelationshipCard:
	return guild if is_node_ready() else null


func _rebuild() -> void:
	if not is_node_ready():
		return
	for child: Node in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	if view == null:
		count_label.text = "0"
		return
	guild.set_opinion(view.guild_opinion)
	var rows: Array[Dictionary] = _rows()
	for row: Dictionary in rows:
		var card: RelationshipCard = CARD_SCENE.instantiate()
		grid.add_child(card)
		card.set_card(row.get("view") as MercView, int(row.get("value", 0)),
			int(row.get("known", RelationshipCard.NO_DAY)),
			int(row.get("changed", RelationshipCard.NO_DAY)))
	count_label.text = str(rows.size())


func _rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for other: MercView in GameState.roster:
		if other == null or other.uid == view.uid:
			continue
		var value: int = int(view.relationships.get(other.uid, MercView.NEUTRAL_RELATION))
		out.append({"view": other, "value": value,
			"known": int(view.relationship_known_since.get(other.uid, RelationshipCard.NO_DAY)),
			"changed": int(view.relationship_last_changed.get(other.uid,
				RelationshipCard.NO_DAY))})
	var mode: int = sort_button.selected
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _before(a, b, mode))
	return out


#A day stamp the sort can read; a pair with no stamp sorts to the end of either date order.
static func day_key(day: int) -> int:
	return day if day >= 0 else LAST_KEY


static func _before(a: Dictionary, b: Dictionary, mode: int) -> bool:
	var av: MercView = a.get("view") as MercView
	var bv: MercView = b.get("view") as MercView
	if mode == SORT_LONGEST:
		var ak: int = day_key(int(a.get("known", RelationshipCard.NO_DAY)))
		var bk: int = day_key(int(b.get("known", RelationshipCard.NO_DAY)))
		if ak != bk:
			return ak < bk
		return av.name.naturalnocasecmp_to(bv.name) < 0
	if mode == SORT_RECENT:
		var ac: int = int(a.get("changed", RelationshipCard.NO_DAY))
		var bc: int = int(b.get("changed", RelationshipCard.NO_DAY))
		if ac != bc:
			return ac > bc
		return av.name.naturalnocasecmp_to(bv.name) < 0
	var x: int = int(a.get("value", 0))
	var y: int = int(b.get("value", 0))
	if x != y:
		return x < y if mode == SORT_LOWEST else x > y
	return av.name.naturalnocasecmp_to(bv.name) < 0


func _on_sorted(_index: int) -> void:
	_rebuild()
