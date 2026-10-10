class_name ContractPreview extends PanelContainer

#The right column of the Dispatch Window: how long the journey runs, what it costs and what is
#left of the reward. preview() is static so the numbers can be read without a scene.

const ROW_FONT: String = "res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres"
const CAPTION_SIZE: int = 10
const VALUE_SIZE: int = 13

@onready var travel_to_row: InfoField = $Rows/TravelTo
@onready var completion_row: InfoField = $Rows/Completion
@onready var return_row: InfoField = $Rows/Return
@onready var total_days_row: InfoField = $Rows/TotalDays
@onready var travel_costs_row: InfoField = $Rows/TravelCosts
@onready var final_reward_row: InfoField = $Rows/FinalReward
@onready var merc_bonus_row: InfoField = $Rows/MercBonus
@onready var guild_cut_row: InfoField = $Rows/GuildCut

var data: Dictionary = {}


func _ready() -> void:
	var font: Font = load(ROW_FONT) as Font
	for field: InfoField in rows():
		field.size_flags_horizontal = SIZE_EXPAND_FILL
		field.caption_label.uppercase = true
		GuiStyle.paint(field.caption_label, font, CAPTION_SIZE, GuiColors.SKY)
		field.value_label.add_theme_font_override("font", font)
		field.value_label.add_theme_font_size_override("font_size", VALUE_SIZE)
	_refresh()


func set_preview(new_data: Dictionary) -> void:
	data = new_data
	_refresh()


func values() -> Dictionary:
	return data


func row(row_name: String) -> InfoField:
	return $Rows.get_node(row_name) as InfoField


func rows() -> Array[InfoField]:
	var out: Array[InfoField] = []
	for child: Node in $Rows.get_children():
		if child is InfoField:
			out.append(child)
	return out


func row_count() -> int:
	return rows().size()


func _refresh() -> void:
	if not is_node_ready() or data.is_empty():
		return
	var travel_cost: int = int(data.get("travel_cost", 0))
	var final_reward: int = int(data.get("final_reward", 0))
	var pct: int = int(data.get("bonus_pct", bonus_pct()))
	var merc_bonus: int = int(data.get("merc_bonus", 0))
	var guild_cut: int = int(data.get("guild_cut", final_reward))
	var reward_tint: Color = GuiColors.GREEN if final_reward >= 0 else GuiColors.RED
	var cut_tint: Color = GuiColors.GREEN if guild_cut >= 0 else GuiColors.RED
	var bonus_tint: Color = GuiColors.RAMP_YELLOW if merc_bonus > 0 else GuiColors.SKY
	_fill_row(travel_to_row, "Travel To", days_text(float(data.get("travel_to_hours", 0.0))),
		GuiColors.CREAM, false)
	_fill_row(completion_row, "Completion", days_text(float(data.get("completion_hours", 0.0))),
		GuiColors.CREAM, false)
	_fill_row(return_row, "Return", days_text(float(data.get("return_hours", 0.0))),
		GuiColors.CREAM, false)
	_fill_row(total_days_row, "Total Days", "%d" % int(data.get("total_days", 0)),
		GuiColors.CREAM, false)
	_fill_row(travel_costs_row, "Travel Costs", "-%d" % travel_cost, GuiColors.RED, true)
	_fill_row(final_reward_row, "Final Reward", "%d" % final_reward, reward_tint, true)
	_fill_row(merc_bonus_row, "Mercenary Bonus (%d%%)" % pct, "%d" % merc_bonus, bonus_tint, true)
	_fill_row(guild_cut_row, "Guild Cut", "%d" % guild_cut, cut_tint, true)


func _fill_row(field: InfoField, caption: String, value: String, tint: Color, note: bool) -> void:
	field.set_field(caption, value)
	field.value_color = tint
	field.show_note = note


static func bonus_pct() -> int:
	return BenefitsManager.per_contract


#The notes one leg of the trip costs for a crew of team_size.
static func leg_cost(contract: ContractView, mode: Dictionary, team_size: int) -> int:
	return DispatchLogic.travel_cost(mode, team_size, contract.merc_min, contract.distance_km)


static func preview(contract: ContractView, venture: Dictionary, ret: Dictionary,
		team_size: int) -> Dictionary:
	if contract == null:
		return {}
	var distance: int = contract.distance_km
	var out_hours: float = DispatchLogic.travel_hours(venture, distance)
	var back_hours: float = DispatchLogic.travel_hours(ret, distance)
	var work_hours: float = float(contract.completion_hours)
	var total: float = out_hours + work_hours + back_hours
	var cost: int = leg_cost(contract, venture, team_size) + leg_cost(contract, ret, team_size)
	var final_reward: int = contract.reward - cost
	var pct: int = bonus_pct()
	var merc_bonus: int = ContractResultData.bonus_of(contract.reward, pct)
	var guild_cut: int = final_reward - merc_bonus
	return {
		"travel_to_hours": out_hours,
		"completion_hours": work_hours,
		"return_hours": back_hours,
		"total_hours": total,
		"total_days": int(ceil(total / 24.0)),
		"travel_cost": cost,
		"final_reward": final_reward,
		"bonus_pct": pct,
		"merc_bonus": merc_bonus,
		"guild_cut": guild_cut,
	}


#"2 Days, 1 Hours" the way the design prototype spells it; a span with no time in it arrives at once.
static func days_text(hours: float) -> String:
	if hours <= 0.0:
		return "Instant"
	return GuiDates.duration_text(hours)
