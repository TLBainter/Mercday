class_name ContractResultData extends RefCounted

#What one closed posting paid, what it cost and how the team came home.
#GameState builds one of these when a posting settles; the results screen only reads it.

const ROLE_LEADER: String = "Leader"

var entry_id: int = 0
var name: String = ""
var difficulty: float = 0.0
var failed: bool = false
#What the board listed, kept for the failure line where nothing was paid.
var listed_reward: int = 0
var reward: int = 0
var expenses: int = 0
#The share of the net the crew splits, written by the finance layer before the screen reads it.
var bonus_pct: int = 0
var closed_minute: int = 0
var preview: bool = false
var members: Array[ResultMemberData] = []


func net() -> int:
	return reward - expenses


func bonus() -> int:
	if failed or net() <= 0 or bonus_pct <= 0:
		return 0
	return int(floor(float(net()) * float(bonus_pct) / 100.0))


func guild_share() -> int:
	return net() - bonus()


func fly_amount() -> int:
	if failed:
		return -expenses
	return guild_share()


func living() -> Array[ResultMemberData]:
	var out: Array[ResultMemberData] = []
	for member: ResultMemberData in members:
		if member != null and member.alive():
			out.append(member)
	return out


func member_of(uid: int) -> ResultMemberData:
	for member: ResultMemberData in members:
		if member != null and member.uid == uid:
			return member
	return null


func mvp_member() -> ResultMemberData:
	for member: ResultMemberData in members:
		if member != null and member.mvp:
			return member
	return null


#PLACEHOLDER rule: the living member with the most experience gained, no MVP on a failure.
#ContractResolver will name the MVP from the fight itself.
func pick_mvp() -> void:
	for member: ResultMemberData in members:
		member.mvp = false
	if failed:
		return
	var best: ResultMemberData = null
	for member: ResultMemberData in living():
		if best == null or member.xp_gained > best.xp_gained:
			best = member
	if best != null:
		best.mvp = true


#An even split of the bonus over the living; the remainder goes to the MVP.
func assign_pay() -> void:
	for member: ResultMemberData in members:
		member.pay = 0
	var alive_rows: Array[ResultMemberData] = living()
	var total: int = bonus()
	if alive_rows.is_empty() or total <= 0:
		return
	var share: int = int(floor(float(total) / float(alive_rows.size())))
	var rest: int = total - share * alive_rows.size()
	for member: ResultMemberData in alive_rows:
		member.pay = share
	if rest <= 0:
		return
	var taker: ResultMemberData = _remainder_taker(alive_rows)
	if taker != null:
		taker.pay += rest


func _remainder_taker(alive_rows: Array[ResultMemberData]) -> ResultMemberData:
	if alive_rows.is_empty():
		return null
	for member: ResultMemberData in alive_rows:
		if member.mvp:
			return member
	var top: int = -1
	for member: ResultMemberData in alive_rows:
		top = maxi(top, member.level_after)
	var tied: Array[ResultMemberData] = []
	for member: ResultMemberData in alive_rows:
		if member.level_after == top:
			tied.append(member)
	if tied.size() > 1:
		for member: ResultMemberData in tied:
			if member.role == ROLE_LEADER:
				return member
	return tied[0]
