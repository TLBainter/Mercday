class_name NotesEarned extends PanelContainer

#The money box of the results panel: reward, expenses, the notes earned and the merc bonus, each
#counting from the one clock. The net row is where the flying notes leave from.

const TILE_SIZE: Vector2 = Vector2(16.0, 20.0)
const DIVIDER_PX: float = 2.0
const DIVIDER_COLOR: Color = GuiColors.BLUE_LO
const MINUS: String = "-"

@onready var reward_label: Label = $Rows/RewardRow/Key
@onready var reward_value: Label = $Rows/RewardRow/Value/Amount
@onready var reward_glyph: TextureRect = $Rows/RewardRow/Value/Glyph
@onready var expense_value: Label = $Rows/ExpenseRow/Value/Amount
@onready var expense_glyph: TextureRect = $Rows/ExpenseRow/Value/Glyph
@onready var net_box: MarginContainer = $Rows/NetBox
@onready var net_label: Label = $Rows/NetBox/NetRow/Key
@onready var net_tile: Control = $Rows/NetBox/NetRow/Value/Tile
@onready var net_value: Label = $Rows/NetBox/NetRow/Value/Amount
@onready var bonus_row: HBoxContainer = $Rows/BonusRow
@onready var bonus_label: Label = $Rows/BonusRow/Key
@onready var bonus_value: Label = $Rows/BonusRow/Value/Amount
@onready var bonus_glyph: TextureRect = $Rows/BonusRow/Value/Glyph

var _result: ContractResultData = null
var _bonus_shown: bool = false


func _ready() -> void:
	net_box.draw.connect(_on_net_box_draw)
	net_tile.draw.connect(_on_tile_draw)
	expense_glyph.texture = CrewGlyphs.note(ResultsTimeline.FAILURE)
	bonus_glyph.texture = CrewGlyphs.note(GuiColors.RAMP_YELLOW)
	reward_glyph.texture = CrewGlyphs.note(GuiColors.CREAM)
	apply_time(0.0)


func set_result(result: ContractResultData) -> void:
	_result = result
	apply_time(0.0)


func apply_time(t: float) -> void:
	if not is_node_ready():
		return
	var state: Dictionary = ResultsTimeline.money_state(_result, t)
	var reward_color: Color = state["reward_color"] as Color
	reward_label.text = String(state["reward_label"])
	reward_value.text = "%d" % int(state["reward"])
	reward_value.add_theme_color_override("font_color", reward_color)
	reward_glyph.texture = CrewGlyphs.note(reward_color)
	expense_value.text = MINUS + "%d" % int(state["expenses"])
	net_label.text = String(state["net_label"])
	net_value.text = "%d" % int(state["net"])
	net_value.add_theme_color_override("font_color", state["net_color"] as Color)
	bonus_label.text = String(state["bonus_label"])
	bonus_value.text = MINUS + "%d" % int(state["bonus"])
	_bonus_shown = bool(state["bonus_visible"])
	bonus_row.modulate.a = 1.0 if _bonus_shown else 0.0


#The centre of the net row in global coordinates: the notes fly out of it.
func net_anchor() -> Vector2:
	return net_box.get_global_rect().get_center()


func reward_text() -> String:
	return reward_value.text


func expense_text() -> String:
	return expense_value.text


func net_text() -> String:
	return net_value.text


func bonus_text() -> String:
	return bonus_value.text


func reward_label_text() -> String:
	return reward_label.text


func net_label_text() -> String:
	return net_label.text


func bonus_label_text() -> String:
	return bonus_label.text


func bonus_shown() -> bool:
	return _bonus_shown


func net_color() -> Color:
	return net_value.get_theme_color("font_color")


func _on_net_box_draw() -> void:
	net_box.draw_rect(Rect2(0.0, 0.0, net_box.size.x, DIVIDER_PX), DIVIDER_COLOR)


func _on_tile_draw() -> void:
	NoteIcon.draw_tile(net_tile, Rect2(Vector2.ZERO, TILE_SIZE), true)
