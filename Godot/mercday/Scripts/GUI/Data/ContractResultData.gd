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
#The percent of the reward the crew splits as a bonus, stamped when the posting settles.
var bonus_pct: int = 0
var closed_minute: int = 0
var preview: bool = false
var members: Array[ResultMemberData] = []


#One closed posting: the head comes from the board entry, then the MVP and the pay split are settled.
static func from_entry(entry: BoardEntry, entry_name: String, lost: bool, paid: int, cost: int,
		crew: Array[ResultMemberData], pct: int = 0) -> ContractResultData:
	var result := ContractResultData.new()
	result.entry_id = entry.id
	result.name = entry_name
	result.failed = lost
	result.closed_minute = entry.closed_minute
	if entry.contract != null:
		result.difficulty = entry.contract.difficulty
		result.listed_reward = entry.contract.reward_notes
	result.reward = 0 if lost else paid
	result.expenses = cost
	result.bonus_pct = pct
	result.members = crew
	result.pick_mvp()
	result.assign_pay()
	return result


func net() -> int:
	return reward - expenses


#The whole bonus the reward funds: nothing on a failure or with no member alive and free.
func pool() -> int:
	if failed or living().is_empty():
		return 0
	return bonus_of(reward, bonus_pct)


#What GameState debits at settlement: the whole pool, the shares owed to the away included.
func bonus() -> int:
	return pool()


#One member's share of the pool, rounded down.
func share() -> int:
	var heads: int = counted().size()
	var total: int = pool()
	if total <= 0 or heads == 0:
		return 0
	return floori(float(total) / float(heads))


#The shares held for the captured and the departed; nothing when the pool is empty.
func owed_total() -> int:
	var away_count: int = 0
	for member: ResultMemberData in members:
		if member != null and member.away() and member.earns():
			away_count += 1
	return share() * away_count


#The bonus a reward pays at a percent, rounded down.
static func bonus_of(paid: int, pct: int) -> int:
	if paid <= 0 or pct <= 0:
		return 0
	return floori(float(paid) * float(pct) / 100.0)


func guild_share() -> int:
	return net() - bonus()


#The notes the HUD counter flies in: the reward less the bonus. Expenses left at dispatch, and a
#failure brings nothing in.
func fly_amount() -> int:
	if failed:
		return 0
	return reward - bonus()


#What the posting left the guild with: its share of a success, or the expenses a failure lost.
func outcome_amount() -> int:
	if failed:
		return -expenses
	return guild_share()


func living() -> Array[ResultMemberData]:
	var out: Array[ResultMemberData] = []
	for member: ResultMemberData in members:
		if member != null and member.alive():
			out.append(member)
	return out


#The members the pool divides over: the living, the captured and the departed; the dead and defectors are not.
func counted() -> Array[ResultMemberData]:
	var out: Array[ResultMemberData] = []
	for member: ResultMemberData in members:
		if member != null and member.earns():
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


#An even share of the pool per counted member: the living are paid with the remainder to the MVP, the
#captured and departed are owed their share and defectors get nothing. Pays plus owed equal the pool.
func assign_pay() -> void:
	for member: ResultMemberData in members:
		member.pay = 0
		member.owed = 0
	var alive_rows: Array[ResultMemberData] = living()
	var total: int = pool()
	if alive_rows.is_empty() or total <= 0:
		return
	var cut: int = share()
	var heads: Array[ResultMemberData] = counted()
	for member: ResultMemberData in heads:
		if member.alive():
			member.pay = cut
		else:
			member.owed = cut
	var rest: int = total - cut * heads.size()
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
