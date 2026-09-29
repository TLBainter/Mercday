class_name ContractPreview extends PanelContainer

#The right column of the Dispatch Window: how long the journey runs, what it costs and what is
#left of the reward. preview() is static so the numbers can be read without a scene.

const GREEN: Color = Color("#6cc36a")
const RED: Color = Color("#e8583f")
const BLUE: Color = Color("#9cc6ef")
const GOLD: Color = Color("#f2d33d")
const CREAM: Color = Color("#f3ead7")

@onready var travel_to_row: PreviewRow = $Rows/TravelTo
@onready var completion_row: PreviewRow = $Rows/Completion
@onready var return_row: PreviewRow = $Rows/Return
@onready var total_days_row: PreviewRow = $Rows/TotalDays
@onready var travel_costs_row: PreviewRow = $Rows/TravelCosts
@onready var final_reward_row: PreviewRow = $Rows/FinalReward
@onready var merc_bonus_row: PreviewRow = $Rows/MercBonus
@onready var guild_cut_row: PreviewRow = $Rows/GuildCut

var data: Dictionary = {}


func _ready() -> void:
	_refresh()


func set_preview(new_data: Dictionary) -> void:
	data = new_data
	_refresh()


func values() -> Dictionary:
	return data


func row(row_name: String) -> PreviewRow:
	return $Rows.get_node(row_name) as PreviewRow


func rows() -> Array[PreviewRow]:
	var out: Array[PreviewRow] = []
	for child: Node in $Rows.get_children():
		if child is PreviewRow:
			out.append(child)
	return out


func row_count() -> int:
	return rows().size()


func _refresh() -> void:
	if not is_node_ready() or data.is_empty():
		return
	var travel_cost: int = int(data.get("travel_cost", 0))
	var final_reward: int = int(data.get("final_reward", 0))
	var pct: int = bonus_pct()
	var merc_bonus: int = int(data.get("merc_bonus", 0))
	var guild_cut: int = int(data.get("guild_cut", final_reward))
	var reward_tint: Color = GREEN if final_reward >= 0 else RED
	var cut_tint: Color = GREEN if guild_cut >= 0 else RED
	var bonus_tint: Color = GOLD if merc_bonus > 0 else BLUE
	travel_to_row.set_row("Travel To", days_text(float(data.get("travel_to_hours", 0.0))),
		CREAM, false)
	completion_row.set_row("Completion", days_text(float(data.get("completion_hours", 0.0))),
		CREAM, false)
	return_row.set_row("Return", days_text(float(data.get("return_hours", 0.0))), CREAM, false)
	total_days_row.set_row("Total Days", "%d" % int(data.get("total_days", 0)), CREAM, false)
	travel_costs_row.set_row("Travel Costs", "-%d" % travel_cost, RED, true)
	final_reward_row.set_row("Final Reward", "%d" % final_reward, reward_tint, true)
	merc_bonus_row.set_row("Mercenary Bonus (%d%%)" % pct, "%d" % merc_bonus, bonus_tint, true)
	guild_cut_row.set_row("Guild Cut", "%d" % guild_cut, cut_tint, true)


static func bonus_pct() -> int:
	return BenefitsManager.DEFAULT_BONUS_PCT


static func preview(contract: ContractView, venture: Dictionary, ret: Dictionary,
		team_size: int) -> Dictionary:
	if contract == null:
		return {}
	var distance: int = contract.distance_km
	var out_hours: float = DispatchLogic.travel_hours(venture, distance)
	var back_hours: float = DispatchLogic.travel_hours(ret, distance)
	var work_hours: float = float(contract.completion_hours)
	var total: float = out_hours + work_hours + back_hours
	var cost: int = DispatchLogic.travel_cost(venture, team_size, contract.merc_min, distance) \
		+ DispatchLogic.travel_cost(ret, team_size, contract.merc_min, distance)
	var final_reward: int = contract.reward - cost
	var pct: int = bonus_pct()
	var merc_bonus: int = floori(final_reward * pct / 100.0) if final_reward > 0 else 0
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


static func days_text(hours: float) -> String:
	if hours <= 0.0:
		return "Instant"
	return "%d Days, %d Hours" % [floori(hours / 24.0), floori(hours) % 24]
