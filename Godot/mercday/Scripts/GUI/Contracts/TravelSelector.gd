class_name TravelSelector extends HBoxContainer

#One leg of the journey: the caption beside the six travel tiles, one of them picked. The hovered
#tile raises the travel tip, which is the only place the hours and the notes are spelled out.

signal mode_selected(leg: int, key: String)

const BUTTON_SCENE: PackedScene = preload("res://Scenes/GUI/Contracts/TravelButton.tscn")
const BUTTON_HEIGHT: int = 32
const REASON_RED: String = "In the red: foot only"
const REASON_PERMIT: String = "No teleport permit here"
const REASON_LATE: String = "Arrives after the deadline"
const REASON_COST: String = "Costs more than you hold"

@onready var caption_label: Label = $Caption
@onready var buttons: HBoxContainer = $Buttons
@onready var tip_card: TravelTip = $Tip

var leg: int = 0
var chosen: String = ""

var _built: bool = false


func _ready() -> void:
	_build()


func set_leg(new_leg: int, caption: String) -> void:
	leg = new_leg
	if is_node_ready():
		caption_label.text = caption.to_upper()


#The guild always walks; a paid leg needs its fare out of the bank less other_cost, what the caller holds back for
#the other leg (DispatchWindow.fares_ok is the rule). Tiles outside shown are hidden. A barred tile takes its
#reasons entry first, then the deadline when it is not in in_time, then the bill.
func configure(team_size: int, merc_min: int, distance_km: int, bank: int, other_cost: int,
		shown: Array, in_time: Array, reasons: Dictionary) -> void:
	if not is_node_ready():
		return
	_build()
	var spare: int = bank - other_cost
	for child: Node in buttons.get_children():
		var button: TravelButton = child as TravelButton
		if button == null:
			continue
		var key: String = button.mode_key()
		var mode: Dictionary = GuiTypes.travel_mode(key)
		var cost: int = DispatchLogic.travel_cost(mode, team_size, merc_min, distance_km)
		var hours: float = DispatchLogic.travel_hours(mode, distance_km)
		var affordable: bool = Reachability.fare_ok(key, cost, spare)
		var reason: String = String(reasons.get(key, ""))
		if reason == "" and not in_time.has(key):
			reason = REASON_LATE
		if reason == "" and not affordable:
			reason = REASON_COST
		button.visible = shown.has(key)
		button.configure(mode, cost, hours, affordable, reason)
		button.set_picked(key == chosen)


func select_key(key: String) -> void:
	chosen = key
	if not is_node_ready():
		return
	for child: Node in buttons.get_children():
		var button: TravelButton = child as TravelButton
		if button != null:
			button.set_picked(button.mode_key() == key)


#The caption column is as wide as the longer of the two legs' captions, so neither one clips.
func caption_width() -> float:
	if not is_node_ready():
		return 0.0
	return caption_label.get_minimum_size().x


func set_caption_width(width: float) -> void:
	if not is_node_ready():
		return
	caption_label.custom_minimum_size = Vector2(width, 0.0)


func selected_key() -> String:
	return chosen


func cost_of(key: String) -> int:
	for child: Node in buttons.get_children():
		var button: TravelButton = child as TravelButton
		if button != null and button.mode_key() == key:
			return button.cost_value()
	return 0


func button_for(key: String) -> TravelButton:
	for child: Node in buttons.get_children():
		var button: TravelButton = child as TravelButton
		if button != null and button.mode_key() == key:
			return button
	return null


func tip() -> TravelTip:
	return tip_card


func _build() -> void:
	if _built:
		return
	_built = true
	for mode: Dictionary in GuiTypes.TRAVEL_MODES:
		var button: TravelButton = BUTTON_SCENE.instantiate()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, float(BUTTON_HEIGHT))
		buttons.add_child(button)
		button.configure(mode, 0, 0.0, true)
		button.mode_picked.connect(_on_mode_picked)
		button.mouse_entered.connect(_on_button_entered.bind(button))
		button.mouse_exited.connect(_on_button_exited)


func _on_mode_picked(key: String) -> void:
	select_key(key)
	mode_selected.emit(leg, key)


func _on_button_entered(button: TravelButton) -> void:
	if button.mode.is_empty():
		return
	tip_card.show_for(button)


func _on_button_exited() -> void:
	tip_card.hide_tip()
