class_name PlansPage extends Control

#The Plans tab: the Mercday logo, the page title and the three plan cards side by side in the
#order of the plan table. The page owns no rules; it forwards what a card asks for.

signal switch_requested(plan: int)
signal customize_requested

const LOGO_PX: int = 36
const CARD_SEPARATION: int = 20

@onready var logo: TextureRect = $Pad/Rows/Header/Logo
@onready var title: Label = $Pad/Rows/Header/Title
@onready var cards_box: HBoxContainer = $Pad/Rows/CardsPad/Cards

var _card_scene: PackedScene = preload("res://Scenes/GUI/Subscription/PlanCard.tscn")
var _cards: Array[PlanCard] = []


func _ready() -> void:
	logo.texture = SubscriptionGlyphs.logo()
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.custom_minimum_size = Vector2.ONE * float(LOGO_PX)
	cards_box.add_theme_constant_override(&"separation", CARD_SEPARATION)
	_build_cards()


func cards() -> Array[PlanCard]:
	return _cards


#The card of one plan key ("free", "pro", "enterprise"); null when the key is unknown.
func card(plan_id: String) -> PlanCard:
	for entry: PlanCard in _cards:
		if entry.plan_id == plan_id:
			return entry
	return null


func card_of(plan: int) -> PlanCard:
	return card(UpgradeDefs.plan_key(plan))


func refresh() -> void:
	for entry: PlanCard in _cards:
		entry.refresh()


func _build_cards() -> void:
	for key: Variant in UpgradeDefs.PLANS.keys():
		var entry: PlanCard = _card_scene.instantiate() as PlanCard
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cards_box.add_child(entry)
		entry.plan_id = String(key)
		entry.switch_requested.connect(_on_card_switch)
		entry.customize_requested.connect(_on_card_customize)
		_cards.append(entry)


func _on_card_switch(plan: int) -> void:
	switch_requested.emit(plan)


func _on_card_customize() -> void:
	customize_requested.emit()
