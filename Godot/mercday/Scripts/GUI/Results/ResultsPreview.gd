class_name ResultsPreview
extends RefCounted

#PLACEHOLDER: the contract accounting a finance layer will own. Expenses run at a flat percent of
#the reward, a failure pays a fraction of the experience and the experience itself is a flat draw.
const EXPENSE_PCT: int = 12
const FAIL_XP_PCT: int = 35
const XP_BASE: int = 40
const XP_PER_DIFF: int = 30
#PLACEHOLDER: sample roles and bar levels for the preview results; no real run reads them.
const PREVIEW_ROLES: Array[String] = ["Guide", "Escort", "Driver", "Assassin", "Support"]
const AFTER_PCT: int = 55
const GAP_PCT: int = 30


#Two closed postings for the results click-through: one success, one failure, nobody really hurt.
static func seed_results() -> Array[int]:
	var out: Array[int] = []
	if GameState.board == null:
		return out
	var now: int = CampaignClock.now()
	if GameState.board.available().size() < 2:
		GameState.board.refill(now)
	var open_entries: Array[BoardEntry] = GameState.board.available()
	if open_entries.size() < 2:
		return out
	out.append(_settle_open(open_entries[0], false, now))
	out.append(_settle_open(open_entries[1], true, now))
	GameState.refresh_views()
	GameState.contracts_changed.emit()
	return out


#Closes one open posting with the first four of the roster and rings the bell for it.
static func _settle_open(entry: BoardEntry, failed: bool, now: int) -> int:
	var crew: Array[ResultMemberData] = []
	for i: int in mini(4, GameState.roster.size()):
		crew.append(_member(GameState.roster[i], i, failed, _difficulty(entry),
			_preview_fate(i, failed)))
	GameState.publish_result(_close(entry, failed, now, crew))
	return entry.id


#Closes one posting on paper only: no merc is touched and no money moves.
static func _close(entry: BoardEntry, failed: bool, now: int,
		crew: Array[ResultMemberData]) -> ContractResultData:
	var status: String = BoardEntry.STATUS_FAILED if failed else BoardEntry.STATUS_SUCCEEDED
	GameState.set_entry_status(entry, status)
	entry.verdict = status
	entry.closed_minute = now
	var listed: int = entry.contract.reward_notes if entry.contract != null else 0
	var result := ContractResultData.from_entry(entry, GameState.entry_name(entry), failed, listed,
		int(round(float(listed) * float(EXPENSE_PCT) / 100.0)), crew)
	result.preview = true
	return result


static func _difficulty(entry: BoardEntry) -> float:
	return entry.contract.difficulty if entry.contract != null else 0.0


#The sample fates: on a failure the second member dies and the third is taken.
static func _preview_fate(index: int, failed: bool) -> int:
	if failed and index == 1:
		return ResultMemberData.Fate.DEAD
	if failed and index == 2:
		return ResultMemberData.Fate.CAPTURED
	return ResultMemberData.Fate.ALIVE


static func _member(view: MercView, index: int, failed: bool, difficulty: float,
		fate: int) -> ResultMemberData:
	var member := ResultMemberData.new()
	member.uid = view.uid
	member.name = view.name
	member.tradition = view.tradition
	member.role = ContractResultData.ROLE_LEADER
	if index > 0:
		member.role = PREVIEW_ROLES[(index - 1) % PREVIEW_ROLES.size()]
	member.fate = fate
	var earned: int = XP_BASE + int(round(difficulty * float(XP_PER_DIFF)))
	if failed:
		earned = int(round(float(earned) * float(FAIL_XP_PCT) / 100.0))
	member.xp_gained = earned if member.alive() else 0
	member.xp_need = ExperienceSystem.XP_PER_LEVEL
	member.level_before = view.level
	if index == 0:
		member.xp_before = maxi(0, member.xp_need - member.xp_gained)
	member.level_after = member.level_before + \
		int(floor(float(member.xp_before + member.xp_gained) / float(member.xp_need)))
	var hp_bar: Vector2i = _bar(view.hp_max)
	var ep_bar: Vector2i = _bar(view.ep_max)
	var mp_bar: Vector2i = _bar(view.mp_max)
	member.hp = Vector2i(hp_bar.x, view.hp_max)
	if member.fate == ResultMemberData.Fate.DEAD:
		member.hp = Vector2i(0, view.hp_max)
	member.ep = Vector2i(ep_bar.x, view.ep_max)
	member.mp = Vector2i(mp_bar.x, view.mp_max)
	member.hp_before = hp_bar.y
	member.ep_before = ep_bar.y
	member.mp_before = mp_bar.y
	return member


#A sample bar: (value at return, value at departure) with the departure value the higher one.
static func _bar(maximum: int) -> Vector2i:
	if maximum <= 0:
		return Vector2i.ZERO
	var after: int = maxi(1, int(round(float(maximum) * float(AFTER_PCT) / 100.0)))
	var gap: int = int(round(float(maximum) * float(GAP_PCT) / 100.0))
	return Vector2i(after, mini(maximum, after + maxi(1, gap)))
