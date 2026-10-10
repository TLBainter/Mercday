class_name ActiveRun extends Resource

#What the Dispatch Window agreed to: the crew, the travel choice, the money and the odds shown.
#GameState keeps one per active board entry.

@export var hours: float = 0.0
@export var reward: int = 0
@export var travel_cost: int = 0
@export var odds: int = 0
@export var team: Array[TeamMember] = []
@export var travel_mode: String = ""
@export var return_mode: String = "foot"
@export var dispatched_minute: int = -1
@export var entry_id: int = -1
#The minute the team leaves: the dispatch minute by day, the next 6:00 for a night dispatch.
@export var depart_minute: int = -1


func uids() -> Array[int]:
	var out: Array[int] = []
	for member: TeamMember in team:
		if member != null:
			out.append(member.merc_uid)
	return out


#The minute the run pays out: its departure (else its dispatch, else now) plus its hours.
func return_minute() -> int:
	var start: int = depart_minute if depart_minute >= 0 else dispatched_minute
	if start < 0:
		start = CampaignClock.now()
	return start + int(hours * 60.0)


func leader_uid() -> int:
	for member: TeamMember in team:
		if member != null and member.role == ContractResultData.ROLE_LEADER:
			return member.merc_uid
	return 0
