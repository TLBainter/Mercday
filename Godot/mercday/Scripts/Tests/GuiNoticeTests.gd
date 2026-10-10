class_name GuiNoticeTests
extends RefCounted

#The notification center and the contract results GameState records when a posting settles: the
#row list, the read and resolve paths, the escalation rule, the bonus split, the seeded preview
#and one real contract driven to its end, plus the counts and the row titles the panel reads.

const OFFER_TYPE := &"loanOffer"
const MOOD_TYPE := &"mercMood"
const HOURS_OPEN: float = 200.0
const HOURS_EDGE: float = 72.0
const HOURS_URGENT: float = 71.0
const SHIFT: int = 480
const DAY_CAP: int = 60
const MONTH_CAP: int = 45
const TRAVEL_COST: int = 10
const BONUS_PCT: int = 10
const SETTLE_REWARD: int = 1234
#BONUS_PCT of SETTLE_REWARD, rounded down.
const SETTLE_BONUS: int = 123
#SETTLE_BONUS over one present and one departed merc, rounded down; the present merc also takes the remainder.
#The bank debits the whole SETTLE_BONUS either way.
const SETTLE_SHARE: int = 61
const POSTINGS_FREED: int = 2
#The settle case sends the first merc, has the second depart and the third defect.
const SETTLE_ROSTER: int = 3


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_fresh()
	await host.get_tree().process_frame
	await _case_push_read(res, host)
	await _case_listed(res, host)
	await _case_resolve(res, host)
	await _case_escalate(res, host)
	await _case_result_split(res, host)
	await _case_bonus_owed(res, host)
	await _case_preview(res, host)
	await _case_settle_record(res, host)
	await _case_base_patch(res, host)
	await _case_counts(res, host)
	await _case_titles(res, host)
	await _case_alerted(res, host)
	await _case_settle_bonus(res, host)
	await _case_settle_owed(res, host)
	await _case_postings(res, host)
	_case_bell(res)
	SubscriptionManager.max_out()
	NotificationCenter.reset()
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	TestFixtures.reset_campaign()
	CampaignClock.reset()
	return TestFixtures.summarize(res, "GUI NOTICE")


static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()


static func _open_entry() -> BoardEntry:
	var open: Array[BoardEntry] = GameState.board.available()
	return null if open.is_empty() else open[0]


#An ActiveRun the Dispatch Window would hand over: a walking team and the cost already priced.
static func _run_for(uids: Array[int], cost: int) -> ActiveRun:
	var sent := ActiveRun.new()
	sent.travel_mode = "foot"
	sent.travel_cost = cost
	for i: int in uids.size():
		var member := TeamMember.new()
		member.merc_uid = uids[i]
		member.role = ContractResultData.ROLE_LEADER if i == 0 else "Guide"
		sent.team.append(member)
	return sent


static func ids_of(rows: Array[NotificationData]) -> Array[int]:
	var out: Array[int] = []
	for row: NotificationData in rows:
		out.append(row.id)
	return out


static func _listed_ids() -> Array[int]:
	var out: Array[int] = []
	for view: ContractView in GameState.contracts:
		out.append(view.entry_id)
	return out


#Case 1: pushing a row, the id counter, the kind table and the read flag.
static func _case_push_read(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	NotificationCenter.reset()
	var hits: Array[int] = []
	var watcher: Callable = func() -> void: hits.append(1)
	NotificationCenter.changed.connect(watcher)
	var now: int = CampaignClock.now()
	var snap: Dictionary = {"lender": "House"}
	var first: NotificationData = NotificationCenter.push(
		NotificationData.TYPE_CONTRACT_COMPLETED, 11)
	var second: NotificationData = NotificationCenter.push(OFFER_TYPE, 101, snap)
	var third: NotificationData = NotificationCenter.push(MOOD_TYPE, 7, {},
		NotificationData.Urgency.IMPORTANT, "Mercenary")
	TestFixtures.check(res, "push assigns rising ids and stamps the minute",
		first.id == 1 and second.id == 2 and third.id == 3 and first.minute == now
			and hits.size() == 3,
		"ids %d %d %d, minute %d, changed %d" % [first.id, second.id, third.id, first.minute,
			hits.size()])
	TestFixtures.check(res, "the kind reads the type table and falls back to the caller",
		first.kind == "Contract" and second.kind == "Finance" and third.kind == "Mercenary",
		"kinds %s, %s, %s" % [first.kind, second.kind, third.kind])
	snap["lender"] = "Bank"
	TestFixtures.check(res, "a row starts unread with the urgency it was pushed at",
		not first.read and first.urgency == NotificationData.Urgency.INFORMATIONAL
			and third.urgency == NotificationData.Urgency.IMPORTANT
			and String(second.snap["lender"]) == "House"
			and NotificationCenter.unread_count() == 3 and NotificationCenter.has_unread(),
		"unread %d, snap %s" % [NotificationCenter.unread_count(), second.snap["lender"]])
	NotificationCenter.mark_read(first.id)
	var after_read: int = hits.size()
	NotificationCenter.mark_read(first.id)
	TestFixtures.check(res, "mark_read flips one row once and reports once",
		first.read and after_read == 4 and hits.size() == 4
			and NotificationCenter.unread_count() == 2,
		"changed %d, unread %d" % [hits.size(), NotificationCenter.unread_count()])
	NotificationCenter.mark_read(second.id)
	NotificationCenter.mark_read(third.id)
	TestFixtures.check(res, "with every row read the bell goes quiet",
		not NotificationCenter.has_unread() and NotificationCenter.unread_count() == 0,
		"unread %d" % NotificationCenter.unread_count())
	TestFixtures.check(res, "urgency names and colours come off the row",
		third.urgency_name() == "Important"
			and third.urgency_color() == NotificationData.URGENCY_COLORS[1],
		"name %s" % third.urgency_name())
	NotificationCenter.changed.disconnect(watcher)


#Case 2: the two tabs, the kind filter and both sort orders.
static func _case_listed(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	NotificationCenter.reset()
	var base: int = CampaignClock.now()
	var late: NotificationData = NotificationCenter.push(NotificationData.TYPE_CONTRACT_COMPLETED, 1)
	late.minute = base + 30
	var offer: NotificationData = NotificationCenter.push(OFFER_TYPE, 2)
	offer.minute = base + 10
	var failed: NotificationData = NotificationCenter.push(NotificationData.TYPE_CONTRACT_FAILED, 3)
	failed.minute = base + 10
	var stock: NotificationData = NotificationCenter.push(NotificationData.TYPE_STOCK_MOVE, 4, {},
		NotificationData.Urgency.URGENT)
	stock.minute = base + 20
	var mood: NotificationData = NotificationCenter.push(MOOD_TYPE, 5, {},
		NotificationData.Urgency.IMPORTANT, "Mercenary")
	mood.minute = base
	NotificationCenter.mark_read(mood.id)
	var unread: Array[int] = ids_of(NotificationCenter.listed(true,
		NotificationCenter.SORT_RECENCY, NotificationCenter.FILTER_ALL))
	var read_rows: Array[int] = ids_of(NotificationCenter.listed(false,
		NotificationCenter.SORT_RECENCY, NotificationCenter.FILTER_ALL))
	TestFixtures.check(res, "the unread tab sorts by recency with the newer id first",
		unread == [1, 3, 2, 4] or unread == [1, 4, 3, 2], "got %s" % str(unread))
	TestFixtures.check(res, "the read tab holds only the row that was read",
		read_rows == [5], "got %s" % str(read_rows))
	var by_urgency: Array[int] = ids_of(NotificationCenter.listed(true,
		NotificationCenter.SORT_URGENCY, NotificationCenter.FILTER_ALL))
	TestFixtures.check(res, "the urgency sort lifts the urgent row over the newer one",
		by_urgency == [4, 1, 3, 2], "got %s" % str(by_urgency))
	var contract_rows: Array[int] = ids_of(NotificationCenter.listed(true,
		NotificationCenter.SORT_RECENCY, "Contract"))
	var finance_rows: Array[int] = ids_of(NotificationCenter.listed(true,
		NotificationCenter.SORT_RECENCY, "Finance"))
	var merc_rows: Array[int] = ids_of(NotificationCenter.listed(true,
		NotificationCenter.SORT_RECENCY, "Mercenary"))
	TestFixtures.check(res, "the kind filter keeps only its own rows",
		contract_rows == [1, 3] and finance_rows == [4, 2] and merc_rows.is_empty(),
		"contract %s, finance %s, merc %s" % [str(contract_rows), str(finance_rows),
			str(merc_rows)])


#Case 3: resolving by trigger reads one posting's rows and leaves every other row alone.
static func _case_resolve(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	NotificationCenter.reset()
	var hits: Array[int] = []
	var watcher: Callable = func() -> void: hits.append(1)
	var done: NotificationData = NotificationCenter.push(
		NotificationData.TYPE_CONTRACT_COMPLETED, 5)
	var lost: NotificationData = NotificationCenter.push(NotificationData.TYPE_CONTRACT_FAILED, 5)
	var other: NotificationData = NotificationCenter.push(
		NotificationData.TYPE_CONTRACT_COMPLETED, 6)
	var first_offer: NotificationData = NotificationCenter.push(OFFER_TYPE, 101)
	var second_offer: NotificationData = NotificationCenter.push(OFFER_TYPE, 102)
	NotificationCenter.changed.connect(watcher)
	GameState.results_seen.emit(0)
	NotificationCenter.read_contract(5)
	TestFixtures.check(res, "read_contract reads both contract rows of one posting once",
		done.read and lost.read and not other.read and hits.size() == 1
			and NotificationCenter.unread_count() == 3,
		"changed %d, unread %d" % [hits.size(), NotificationCenter.unread_count()])
	NotificationCenter.read_contract(5)
	TestFixtures.check(res, "reading the same posting again reports nothing",
		hits.size() == 1, "changed %d" % hits.size())
	NotificationCenter.read_offer(101)
	TestFixtures.check(res, "read_offer reads one offer and leaves the other",
		first_offer.read and not second_offer.read and hits.size() == 2,
		"unread %d" % NotificationCenter.unread_count())
	NotificationCenter.resolve(NotificationData.TYPE_CONTRACT_COMPLETED, 6)
	TestFixtures.check(res, "resolve reads the rows of one type and trigger",
		other.read and not second_offer.read and NotificationCenter.unread_count() == 1,
		"unread %d" % NotificationCenter.unread_count())
	NotificationCenter.changed.disconnect(watcher)


#Case 4: a deadline inside 72 hours goes urgent once, then re-fires only after it was read.
static func _case_escalate(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	NotificationCenter.reset()
	var table: Dictionary = {7: HOURS_EDGE, 8: HOURS_OPEN}
	var open_fn: Callable = func() -> Array: return table.keys()
	var hours_fn: Callable = func(id: int) -> float: return float(table.get(id, HOURS_OPEN))
	var make_fn: Callable = func(id: int) -> Dictionary: return {"offer": id}
	var quiet: NotificationData = NotificationCenter.push(OFFER_TYPE, 7)
	var far: NotificationData = NotificationCenter.push(OFFER_TYPE, 8)
	NotificationCenter.add_rule(OFFER_TYPE, {"open": open_fn, "hours_left": hours_fn,
		"make": make_fn, "kind": "Finance"})
	var now: int = CampaignClock.now()
	var edge: bool = NotificationCenter.escalate(now)
	TestFixtures.check(res, "a deadline exactly 72 hours out is left alone",
		not edge and NotificationCenter.latest(OFFER_TYPE, 7) == quiet
			and quiet.urgency == NotificationData.Urgency.INFORMATIONAL,
		"escalated %s" % str(edge))
	table[7] = HOURS_URGENT
	var raised: bool = NotificationCenter.escalate(now)
	var urgent: NotificationData = NotificationCenter.latest(OFFER_TYPE, 7)
	TestFixtures.check(res, "inside 72 hours one urgent row replaces the quiet one",
		raised and urgent != null and urgent != quiet
			and NotificationCenter.rows_of(OFFER_TYPE, 7).size() == 1
			and urgent.urgency == NotificationData.Urgency.URGENT and not urgent.read
			and urgent.minute == now and int(urgent.snap["offer"]) == 7,
		"raised %s, rows %d" % [str(raised), NotificationCenter.rows_of(OFFER_TYPE, 7).size()])
	TestFixtures.check(res, "the far deadline keeps the row it had",
		NotificationCenter.latest(OFFER_TYPE, 8) == far
			and far.urgency == NotificationData.Urgency.INFORMATIONAL,
		"rows %d" % NotificationCenter.rows_of(OFFER_TYPE, 8).size())
	TestFixtures.check(res, "an unread urgent row is never pushed twice",
		not NotificationCenter.escalate(now)
			and NotificationCenter.rows_of(OFFER_TYPE, 7).size() == 1,
		"rows %d" % NotificationCenter.rows_of(OFFER_TYPE, 7).size())
	NotificationCenter.mark_read(urgent.id)
	var early: int = now + NotificationCenter.REFIRE_MINUTES - 1
	TestFixtures.check(res, "a read row waits the full eight hours",
		not NotificationCenter.escalate(early)
			and NotificationCenter.latest(OFFER_TYPE, 7) == urgent,
		"rows %d" % NotificationCenter.rows_of(OFFER_TYPE, 7).size())
	var due: int = now + NotificationCenter.REFIRE_MINUTES
	var refired: bool = NotificationCenter.escalate(due)
	var fresh_row: NotificationData = NotificationCenter.latest(OFFER_TYPE, 7)
	TestFixtures.check(res, "after eight hours one fresh urgent row replaces the read one",
		refired and fresh_row != urgent and not fresh_row.read and fresh_row.minute == due
			and NotificationCenter.rows_of(OFFER_TYPE, 7).size() == 1,
		"refired %s, rows %d" % [str(refired), NotificationCenter.rows_of(OFFER_TYPE, 7).size()])
	table.erase(7)
	TestFixtures.check(res, "a trigger that closed is never touched again",
		not NotificationCenter.escalate(due + NotificationCenter.REFIRE_MINUTES)
			and NotificationCenter.latest(OFFER_TYPE, 7) == fresh_row,
		"rows %d" % NotificationCenter.rows_of(OFFER_TYPE, 7).size())
	NotificationCenter.remove_rule(OFFER_TYPE)
	table[8] = 1.0
	TestFixtures.check(res, "a removed rule escalates nothing",
		not NotificationCenter.escalate(due + NotificationCenter.REFIRE_MINUTES)
			and far.urgency == NotificationData.Urgency.INFORMATIONAL
			and NotificationCenter.rules.is_empty(),
		"rules %d" % NotificationCenter.rules.size())


static func _member(uid: int, role: String, level: int, xp: int, fate: int) -> ResultMemberData:
	var member := ResultMemberData.new()
	member.uid = uid
	member.name = "M%d" % uid
	member.role = role
	member.level_before = level
	member.level_after = level
	member.xp_gained = xp
	member.fate = fate
	return member


static func _result(reward: int, expenses: int, pct: int, failed: bool) -> ContractResultData:
	var result := ContractResultData.new()
	result.entry_id = 1
	result.reward = reward
	result.listed_reward = reward
	result.expenses = expenses
	result.bonus_pct = pct
	result.failed = failed
	return result


static func _pays(result: ContractResultData) -> Array[int]:
	var out: Array[int] = []
	for member: ResultMemberData in result.members:
		out.append(member.pay)
	return out


static func _owed(result: ContractResultData) -> Array[int]:
	var out: Array[int] = []
	for member: ResultMemberData in result.members:
		out.append(member.owed)
	return out


#Every pay and owed share on a result; together they make the pool.
static func _handed(result: ContractResultData) -> int:
	var total: int = 0
	for member: ResultMemberData in result.members:
		total += member.pay + member.owed
	return total


#Case 5: the money a result pays out and who the remainder goes to.
static func _case_result_split(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	var alive: int = ResultMemberData.Fate.ALIVE
	var dead: int = ResultMemberData.Fate.DEAD
	var held: int = ResultMemberData.Fate.CAPTURED
	var even: ContractResultData = _result(1000, 0, 10, false)
	even.members = [_member(1, "Leader", 2, 10, alive), _member(2, "Guide", 2, 20, alive),
		_member(3, "Escort", 2, 30, alive), _member(4, "Driver", 2, 40, alive)]
	even.pick_mvp()
	even.assign_pay()
	TestFixtures.check(res, "a bonus that divides evenly pays every living member the same",
		even.net() == 1000 and even.bonus() == 100 and _pays(even) == [25, 25, 25, 25]
			and even.mvp_member() == even.members[3],
		"net %d, bonus %d, pays %s" % [even.net(), even.bonus(), str(_pays(even))])
	var odd: ContractResultData = _result(1000, 120, 10, false)
	odd.members = [_member(1, "Leader", 2, 10, alive), _member(2, "Guide", 2, 50, alive),
		_member(3, "Escort", 2, 30, alive), _member(4, "Driver", 2, 5, dead)]
	odd.pick_mvp()
	odd.assign_pay()
	TestFixtures.check(res, "the remainder of a split goes to the MVP",
		odd.bonus() == 100 and _pays(odd) == [33, 34, 33, 0],
		"bonus %d, pays %s" % [odd.bonus(), str(_pays(odd))])
	TestFixtures.check(res, "the bonus comes off the reward and the fly leaves the expenses out",
		odd.net() == 880 and odd.guild_share() == 780 and odd.outcome_amount() == 780
			and odd.fly_amount() == 900,
		"net %d, share %d, fly %d" % [odd.net(), odd.guild_share(), odd.fly_amount()])
	var lost_mvp: ContractResultData = _result(1000, 120, 10, false)
	lost_mvp.members = [_member(1, "Leader", 2, 10, alive), _member(2, "Guide", 7, 20, alive),
		_member(3, "Escort", 3, 30, alive), _member(4, "Driver", 9, 99, dead)]
	lost_mvp.members[3].mvp = true
	lost_mvp.assign_pay()
	TestFixtures.check(res, "with the MVP dead the remainder goes to the highest level living",
		_pays(lost_mvp) == [33, 34, 33, 0],
		"pays %s" % str(_pays(lost_mvp)))
	#A 1010 reward pays a bonus of 101; the captured member counts, so a three-way split leaves 2 to place.
	var tie_leader: ContractResultData = _result(1010, 130, 10, false)
	tie_leader.members = [_member(1, "Guide", 7, 10, alive), _member(2, "Leader", 7, 20, alive),
		_member(3, "Escort", 3, 30, held)]
	tie_leader.assign_pay()
	TestFixtures.check(res, "a tie at the top level pays the remainder to the Leader",
		_pays(tie_leader) == [33, 35, 0],
		"pays %s" % str(_pays(tie_leader)))
	TestFixtures.check(res, "a captured member is owed its share and the bonus is the whole pool",
		_owed(tie_leader) == [0, 0, 33] and _handed(tie_leader) == 101 and tie_leader.bonus() == 101,
		"owed %s, handed %d, bonus %d" % [str(_owed(tie_leader)), _handed(tie_leader),
			tie_leader.bonus()])
	var tie_order: ContractResultData = _result(1010, 130, 10, false)
	tie_order.members = [_member(1, "Guide", 7, 10, alive), _member(2, "Escort", 7, 20, alive),
		_member(3, "Leader", 7, 30, dead)]
	tie_order.assign_pay()
	TestFixtures.check(res, "a tie with no living Leader pays the first tied member in the list",
		_pays(tie_order) == [51, 50, 0],
		"pays %s" % str(_pays(tie_order)))
	var ties_xp: ContractResultData = _result(1000, 0, 10, false)
	ties_xp.members = [_member(1, "Leader", 2, 40, alive), _member(2, "Guide", 2, 40, alive)]
	ties_xp.pick_mvp()
	TestFixtures.check(res, "an experience tie names the earlier member MVP",
		ties_xp.mvp_member() == ties_xp.members[0],
		"mvp %s" % str(ties_xp.mvp_member() == null))
	var failure: ContractResultData = _result(0, 150, 20, true)
	failure.members = [_member(1, "Leader", 2, 10, alive), _member(2, "Guide", 2, 20, dead),
		_member(3, "Escort", 2, 0, held)]
	failure.pick_mvp()
	failure.assign_pay()
	TestFixtures.check(res, "a failure pays no bonus and names no MVP",
		failure.bonus() == 0 and failure.mvp_member() == null and _pays(failure) == [0, 0, 0]
			and failure.net() == -150 and failure.guild_share() == -150,
		"bonus %d, net %d" % [failure.bonus(), failure.net()])
	TestFixtures.check(res, "a failure flies nothing and still owes its expenses",
		failure.fly_amount() == 0 and failure.outcome_amount() == -150,
		"fly %d, outcome %d" % [failure.fly_amount(), failure.outcome_amount()])


#Case 5b: the captured and departed count in the split and are owed their share; the dead and defectors do not.
static func _case_bonus_owed(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	var alive: int = ResultMemberData.Fate.ALIVE
	var gone: int = ResultMemberData.Fate.DEPARTED
	var turned: int = ResultMemberData.Fate.DEFECTED
	var dead: int = ResultMemberData.Fate.DEAD
	var held: int = ResultMemberData.Fate.CAPTURED
	#A 1030 reward pays a bonus of 103 over three counted members: a share of 34 and a remainder of 1.
	var mixed: ContractResultData = _result(1030, 0, 10, false)
	mixed.members = [_member(1, "Leader", 2, 10, alive), _member(2, "Guide", 2, 20, gone),
		_member(3, "Escort", 2, 30, turned), _member(4, "Driver", 2, 40, dead),
		_member(5, "Scout", 2, 50, held)]
	mixed.pick_mvp()
	mixed.assign_pay()
	var names: Array[String] = []
	var away: Array[bool] = []
	for member: ResultMemberData in mixed.members:
		names.append(member.fate_name())
		away.append(member.away())
	TestFixtures.check(res, "the departed and the defected read their own fates and count as away",
		names == ["Alive", "Departed", "Defected", "Deceased", "Captured"]
			and away == [false, true, true, false, true],
		"fates %s, away %s" % [str(names), str(away)])
	var earns: Array[bool] = []
	var forfeits: Array[bool] = []
	for member: ResultMemberData in mixed.members:
		earns.append(member.earns())
		forfeits.append(member.forfeits())
	TestFixtures.check(res, "only the defector forfeits; the living, departed and captured earn a share",
		earns == [true, true, false, false, true] and forfeits == [false, false, true, false, false],
		"earns %s, forfeits %s" % [str(earns), str(forfeits)])
	TestFixtures.check(res, "the dead and the defector are not counted; the departed and captured are owed a share",
		mixed.pool() == 103 and mixed.counted().size() == 3 and mixed.share() == 34
			and _owed(mixed) == [0, 34, 0, 0, 34],
		"pool %d, counted %d, share %d, owed %s" % [mixed.pool(), mixed.counted().size(),
			mixed.share(), str(_owed(mixed))])
	TestFixtures.check(res, "the living member takes a share and the remainder; the bonus is the whole pool",
		_pays(mixed) == [35, 0, 0, 0, 0] and mixed.owed_total() == 68 and mixed.bonus() == 103
			and _handed(mixed) == mixed.pool(),
		"pays %s, owed %d, bonus %d" % [str(_pays(mixed)), mixed.owed_total(), mixed.bonus()])
	TestFixtures.check(res, "the fly and the guild share take off the whole pool",
		mixed.fly_amount() == 1030 - 103 and mixed.guild_share() == 1030 - 103,
		"fly %d, guild %d" % [mixed.fly_amount(), mixed.guild_share()])
	var first_pays: Array[int] = _pays(mixed)
	var first_owed: Array[int] = _owed(mixed)
	mixed.assign_pay()
	TestFixtures.check(res, "a second split gives the same pays and owed shares",
		_pays(mixed) == first_pays and _owed(mixed) == first_owed and _handed(mixed) == 103,
		"pays %s, owed %s" % [str(_pays(mixed)), str(_owed(mixed))])
	var all_away: ContractResultData = _result(1030, 0, 10, false)
	all_away.members = [_member(1, "Leader", 2, 10, held), _member(2, "Guide", 2, 20, gone)]
	all_away.pick_mvp()
	all_away.assign_pay()
	TestFixtures.check(res, "a success with nobody alive and free pays and owes nothing",
		all_away.pool() == 0 and all_away.bonus() == 0 and all_away.owed_total() == 0
			and _pays(all_away) == [0, 0] and _owed(all_away) == [0, 0],
		"pool %d, bonus %d, owed %s" % [all_away.pool(), all_away.bonus(), str(_owed(all_away))])
	var lost: ContractResultData = _result(0, 150, 10, true)
	lost.members = [_member(1, "Leader", 2, 10, alive), _member(2, "Guide", 2, 20, gone),
		_member(3, "Escort", 2, 30, turned)]
	lost.pick_mvp()
	lost.assign_pay()
	TestFixtures.check(res, "a failure owes the away nothing",
		lost.pool() == 0 and lost.bonus() == 0 and _owed(lost) == [0, 0, 0] and _pays(lost) == [0, 0, 0],
		"pool %d, owed %s" % [lost.pool(), str(_owed(lost))])
	var off: Array[String] = []
	var t: float = ResultsTimeline.TOLD
	for fate: int in [gone, turned]:
		var row: ResultMemberData = _member(9, "Guide", 2, 0, fate)
		if ResultsTimeline.status_color(row, t) != ResultsTimeline.CAPTURED:
			off.append("%s status" % row.fate_name())
		if ResultsTimeline.ring_color(row, t, false) != ResultsTimeline.RING_CAPTURED:
			off.append("%s ring" % row.fate_name())
		if (ResultsTimeline.portrait_gray(row, t) != ResultsTimeline.GRAY_CAPTURED
				or ResultsTimeline.portrait_brightness(row, t) != ResultsTimeline.BRIGHT_CAPTURED):
			off.append("%s filter" % row.fate_name())
		var bars: Texture2D = ResultsGlyphs.overlay_for(ResultMemberData.Fate.CAPTURED)
		var want: Texture2D = ResultsGlyphs.missing() if fate == gone else ResultsGlyphs.bandit()
		if ResultsGlyphs.overlay_for(fate) != want or want == bars:
			off.append("%s overlay" % row.fate_name())
	TestFixtures.check(res, "the results screen tints the departed and the defected like the captured, the departed wear the missing icon, the defected the bandit",
		off.is_empty(), "off %s" % str(off))


#Case 6: the two sample results the click-through starts from.
static func _case_preview(res: Dictionary, host: Node) -> void:
	_fresh()
	await host.get_tree().process_frame
	var bank: int = GameState.bank_notes
	var roster: int = GameState.roster.size()
	var unread: int = NotificationCenter.unread_count()
	var seen: Array[int] = []
	var watcher: Callable = func(id: int) -> void: seen.append(id)
	GameState.results_seen.connect(watcher)
	var ids: Array[int] = ResultsPreview.seed_results()
	TestFixtures.check(res, "the preview seeds two unclaimed results",
		ids.size() == 2 and GameState.has_result(ids[0]) and GameState.has_result(ids[1])
			and GameState.is_unclaimed(ids[0]) and GameState.is_unclaimed(ids[1])
			and GameState.unclaimed_ids().size() == 2,
		"ids %s" % str(ids))
	if ids.size() < 2:
		GameState.results_seen.disconnect(watcher)
		return
	var dead: Array[String] = []
	for merc: MercenaryData in GameState.mercs:
		if merc.is_dead:
			dead.append(merc.merc_name)
	TestFixtures.check(res, "the preview costs nothing and hurts nobody",
		GameState.bank_notes == bank and GameState.roster.size() == roster and dead.is_empty(),
		"bank %d, roster %d, dead %s" % [GameState.bank_notes, GameState.roster.size(),
			str(dead)])
	var rows: Array[NotificationData] = NotificationCenter.listed(true,
		NotificationCenter.SORT_RECENCY, "Contract")
	TestFixtures.check(res, "each sample result rings the bell once",
		rows.size() == 2 and NotificationCenter.unread_count() == unread + 2,
		"rows %d, unread %d of %d" % [rows.size(), NotificationCenter.unread_count(), unread])
	var win: ContractResultData = GameState.result_of(ids[0])
	var loss: ContractResultData = GameState.result_of(ids[1])
	var expenses: int = int(round(float(win.listed_reward)
		* float(ResultsPreview.EXPENSE_PCT) / 100.0))
	TestFixtures.check(res, "the success sample pays its listed reward less the expenses",
		not win.failed and win.preview and win.reward == win.listed_reward
			and win.expenses == expenses and win.net() == win.reward - expenses
			and win.members.size() == mini(4, roster),
		"reward %d, expenses %d of %d" % [win.reward, win.expenses, win.listed_reward])
	var leader: ResultMemberData = win.members[0]
	TestFixtures.check(res, "the first sample member leads the team and levels up",
		leader.role == ContractResultData.ROLE_LEADER and leader.levelled()
			and leader.xp_before + leader.xp_gained >= leader.xp_need,
		"role %s, %d to %d" % [leader.role, leader.level_before, leader.level_after])
	var fates: Array[int] = []
	for member: ResultMemberData in loss.members:
		fates.append(member.fate)
	var want: Array[int] = [ResultMemberData.Fate.ALIVE, ResultMemberData.Fate.DEAD,
		ResultMemberData.Fate.CAPTURED, ResultMemberData.Fate.ALIVE]
	TestFixtures.check(res, "the failure sample loses one merc and has one taken",
		loss.failed and loss.reward == 0 and loss.bonus() == 0 and loss.mvp_member() == null
			and fates == want.slice(0, loss.members.size())
			and loss.members[1].hp.x == 0 and loss.fly_amount() == 0
			and loss.outcome_amount() == -loss.expenses,
		"fates %s, hp %d, fly %d" % [str(fates), loss.members[1].hp.x, loss.fly_amount()])
	var bars: Array[String] = []
	for member: ResultMemberData in win.members:
		if member.hp_before < member.hp.x or member.ep_before < member.ep.x:
			bars.append(member.name)
	TestFixtures.check(res, "every sample bar stood higher at departure", bars.is_empty(),
		TestFixtures.detail(bars, win.members.size(), "member"))
	var listed: Array[int] = _listed_ids()
	TestFixtures.check(res, "both sample postings stay on the contract list",
		listed.has(ids[0]) and listed.has(ids[1]), "listed %s of %s" % [str(ids), str(listed)])
	var first: bool = GameState.mark_seen(ids[0])
	var again: bool = GameState.mark_seen(ids[0])
	TestFixtures.check(res, "opening a result claims it once and reads its row",
		first and not again and seen == [ids[0]] and not GameState.is_unclaimed(ids[0])
			and NotificationCenter.unread_count() == unread + 1,
		"first %s, again %s, seen %s" % [str(first), str(again), str(seen)])
	GameState.results_seen.disconnect(watcher)


#Case 7: one real contract driven to its end, from the departure snapshot to the claimed result.
static func _case_settle_record(res: Dictionary, host: Node) -> void:
	_fresh()
	await host.get_tree().process_frame
	var entry: BoardEntry = _open_entry()
	if entry == null:
		TestFixtures.check(res, "the board opened a posting to drive", false, "no open posting")
		return
	var uids: Array[int] = [GameState.mercs[0].merc_uid, GameState.mercs[1].merc_uid]
	var recorded: Array[int] = []
	var track: Dictionary = {"last": GameState.bank_notes, "gains": []}
	var on_result: Callable = func(id: int) -> void: recorded.append(id)
	var on_money: Callable = func(notes: int) -> void:
		(track["gains"] as Array).append(notes - int(track["last"]))
		track["last"] = notes
	GameState.results_recorded.connect(on_result)
	GameState.money_changed.connect(on_money)
	var sent: bool = GameState.dispatch(entry.id, _run_for(uids, TRAVEL_COST))
	var cap: int = int(float(DAY_CAP * CampaignClock.MINUTES_PER_DAY) / float(SHIFT))
	var steps: int = 0
	while entry.status == BoardEntry.STATUS_ACTIVE and steps < cap:
		await GameState.process_until(CampaignClock.now() + SHIFT)
		steps += 1
	TestFixtures.check(res, "the team went out and the run finished",
		sent and steps < cap and entry.status in [BoardEntry.STATUS_SUCCEEDED, BoardEntry.STATUS_FAILED],
		"sent %s, status %s, steps %d" % [str(sent), entry.status, steps])
	var success: bool = entry.status == BoardEntry.STATUS_SUCCEEDED
	var result: ContractResultData = GameState.result_of(entry.id)
	TestFixtures.check(res, "a settled posting records one result",
		result != null and recorded == [entry.id] and GameState.is_unclaimed(entry.id),
		"recorded %s" % str(recorded))
	if result == null:
		GameState.results_recorded.disconnect(on_result)
		GameState.money_changed.disconnect(on_money)
		return
	var order: Array[int] = []
	for member: ResultMemberData in result.members:
		order.append(member.uid)
	TestFixtures.check(res, "the result holds the dispatched team in the order it was sent",
		order == uids and result.members[0].role == ContractResultData.ROLE_LEADER,
		"order %s of %s" % [str(order), str(uids)])
	var reward: int = entry.contract.reward_notes if success else 0
	TestFixtures.check(res, "the result carries the reward paid and the travel cost",
		result.reward == reward and result.expenses == TRAVEL_COST
			and result.listed_reward == entry.contract.reward_notes
			and result.failed == (not success) and not result.preview,
		"reward %d of %d, expenses %d" % [result.reward, reward, result.expenses])
	var gains: Array = track["gains"]
	TestFixtures.check(res, "the bank took the reward as it settled",
		gains.has(reward) if success else not gains.has(reward),
		"gains %s, reward %d" % [str(gains), reward])
	var notice_type: StringName = NotificationData.TYPE_CONTRACT_COMPLETED
	if not success:
		notice_type = NotificationData.TYPE_CONTRACT_FAILED
	var row: NotificationData = NotificationCenter.latest(notice_type, entry.id)
	TestFixtures.check(res, "one unread row names the posting that settled",
		row != null and not row.read and row.kind == "Contract"
			and String(row.snap["name"]) == result.name
			and int(row.snap["reward"]) == result.listed_reward,
		"row %s" % str(row == null))
	var bad: Array[String] = []
	for member: ResultMemberData in result.members:
		if member.xp_need != ExperienceSystem.XP_PER_LEVEL or member.xp_gained < 0:
			bad.append("%s xp %d of %d" % [member.name, member.xp_gained, member.xp_need])
		if member.hp.y <= 0 or member.level_after < member.level_before:
			bad.append("%s hp %s level %d" % [member.name, str(member.hp), member.level_after])
	TestFixtures.check(res, "every member reads a level, an experience need and a full bar",
		bad.is_empty(), TestFixtures.detail(bad, result.members.size(), "member"))
	var month: int = int(TrynnCalendar.date_of(CampaignClock.now())["month"])
	var days: int = 0
	while int(TrynnCalendar.date_of(CampaignClock.now())["month"]) == month and days < MONTH_CAP:
		await GameState.process_until(CampaignClock.now() + CampaignClock.MINUTES_PER_DAY)
		days += 1
	TestFixtures.check(res, "an unclaimed result keeps its posting listed past the month end",
		days < MONTH_CAP and _listed_ids().has(entry.id) and GameState.is_unclaimed(entry.id),
		"days %d, listed %s" % [days, str(_listed_ids().has(entry.id))])
	var claimed: bool = GameState.mark_seen(entry.id)
	GameState.refresh_views()
	TestFixtures.check(res, "claiming the result drops the posting off the list",
		claimed and not GameState.is_unclaimed(entry.id) and not _listed_ids().has(entry.id)
			and row.read,
		"claimed %s, listed %s" % [str(claimed), str(_listed_ids().has(entry.id))])
	GameState.results_recorded.disconnect(on_result)
	GameState.money_changed.disconnect(on_money)


#Case 8: the base patch additions: new status values, colours and the money_moved reasons.
static func _case_base_patch(res: Dictionary, host: Node) -> void:
	_fresh()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the new merc and contract status values keep their order",
		GuiTypes.MercStatus.LOAN == 4 and GuiTypes.MercStatus.CAPTURED == 8
			and GuiTypes.MercStatus.ODD_JOB == 9 and GuiTypes.ContractStatus.FAILED == 5,
		"loan %d, captured %d, odd_job %d, failed %d" % [GuiTypes.MercStatus.LOAN,
			GuiTypes.MercStatus.CAPTURED, GuiTypes.MercStatus.ODD_JOB, GuiTypes.ContractStatus.FAILED])
	TestFixtures.check(res, "the status tables name every new value",
		String(GuiTypes.MERC_STATUS_NAMES[GuiTypes.MercStatus.LOAN]) == "Pursuing a Loan"
			and String(GuiTypes.MERC_STATUS_NAMES[GuiTypes.MercStatus.DEAD]) == "Dead"
			and String(GuiTypes.MERC_STATUS_NAMES[GuiTypes.MercStatus.FIRED]) == "Fired"
			and String(GuiTypes.MERC_STATUS_NAMES[GuiTypes.MercStatus.MISSING]) == "Missing"
			and String(GuiTypes.MERC_STATUS_NAMES[GuiTypes.MercStatus.CAPTURED]) == "Captured"
			and String(GuiTypes.MERC_STATUS_NAMES[GuiTypes.MercStatus.ODD_JOB]) == "On an Odd Job"
			and String(GuiTypes.STATUS_NAMES[GuiTypes.ContractStatus.FAILED]) == "Failed",
		"names %s" % str(GuiTypes.MERC_STATUS_NAMES))
	TestFixtures.check(res, "merc_status_color reads the ramp for the named statuses",
		GuiTypes.merc_status_color(GuiTypes.MercStatus.AVAILABLE) == GuiColors.GREEN
			and GuiTypes.merc_status_color(GuiTypes.MercStatus.DEAD) == GuiColors.RED
			and GuiTypes.merc_status_color(GuiTypes.MercStatus.LOAN) == GuiColors.AMBER
			and GuiTypes.merc_status_color(GuiTypes.MercStatus.ODD_JOB) == GuiColors.AMBER
			and GuiTypes.merc_status_color(GuiTypes.MercStatus.RESTING) == GuiColors.CREAM,
		"resting color %s" % str(GuiTypes.merc_status_color(GuiTypes.MercStatus.RESTING)))
	var moves: Array = []
	var watcher: Callable = func(delta: int, reason: String) -> void: moves.append([delta, reason])
	GameState.money_moved.connect(watcher)
	var bank: int = GameState.bank_notes
	var spent: bool = GameState.spend(5, "x")
	TestFixtures.check(res, "spend with a reason emits money_moved with that reason and returns true",
		spent and moves.size() == 1 and moves[0][0] == -5 and moves[0][1] == "x"
			and GameState.bank_notes == bank - 5,
		"moves %s" % str(moves))
	moves.clear()
	var over: bool = GameState.spend(bank + 1000, "y")
	TestFixtures.check(res, "a spend past the bank is refused and emits nothing",
		not over and moves.is_empty(), "moves %s" % str(moves))
	GameState.refund(5, "y")
	TestFixtures.check(res, "refund emits money_moved with its reason",
		moves.size() == 1 and moves[0][0] == 5 and moves[0][1] == "y",
		"moves %s" % str(moves))
	moves.clear()
	GameState.spend(5)
	TestFixtures.check(res, "spend with no reason emits an empty reason",
		moves.size() == 1 and moves[0][0] == -5 and moves[0][1] == "",
		"moves %s" % str(moves))
	GameState.money_moved.disconnect(watcher)
#Case 9: the read and unread counts per kind, the id lookup and mark_all_read.
static func _case_counts(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	NotificationCenter.reset()
	var done: NotificationData = NotificationCenter.push(
		NotificationData.TYPE_CONTRACT_COMPLETED, 21, {"name": "Ridge"})
	var offer: NotificationData = NotificationCenter.push(OFFER_TYPE, 22, {"lender": "House"})
	var stock: NotificationData = NotificationCenter.push(NotificationData.TYPE_STOCK_MOVE, 23,
		{"company": "Ironvein", "pct": 1.5, "band": 1})
	var mood: NotificationData = NotificationCenter.push(MOOD_TYPE, 24, {},
		NotificationData.Urgency.IMPORTANT, "Mercenary")
	TestFixtures.check(res, "unread_count counts every row and one kind at a time",
		NotificationCenter.unread_count() == 4
			and NotificationCenter.unread_count("Contract") == 1
			and NotificationCenter.unread_count("Finance") == 2
			and NotificationCenter.unread_count("Mercenary") == 1
			and NotificationCenter.unread_count("Metrics") == 0,
		"all %d finance %d" % [NotificationCenter.unread_count(),
			NotificationCenter.unread_count("Finance")])
	TestFixtures.check(res, "read_count starts at zero and follows the same filter",
		NotificationCenter.read_count() == 0 and NotificationCenter.read_count("Finance") == 0,
		"read %d" % NotificationCenter.read_count())
	NotificationCenter.mark_read(offer.id)
	TestFixtures.check(res, "reading one row moves it between the two counts",
		NotificationCenter.read_count() == 1 and NotificationCenter.read_count("Finance") == 1
			and NotificationCenter.unread_count("Finance") == 1
			and NotificationCenter.unread_count() == 3,
		"read %d unread %d" % [NotificationCenter.read_count(),
			NotificationCenter.unread_count()])
	TestFixtures.check(res, "by_id finds a row and answers null for an id that is gone",
		NotificationCenter.by_id(done.id) == done and NotificationCenter.by_id(stock.id) == stock
			and NotificationCenter.by_id(999) == null,
		"found %s" % str(NotificationCenter.by_id(done.id) == done))
	var hits: Array[int] = []
	var watcher: Callable = func() -> void: hits.append(1)
	NotificationCenter.changed.connect(watcher)
	NotificationCenter.mark_all_read("Finance")
	TestFixtures.check(res, "mark_all_read of one kind reads that kind alone and reports once",
		stock.read and not done.read and not mood.read and hits.size() == 1
			and NotificationCenter.unread_count() == 2,
		"unread %d changed %d" % [NotificationCenter.unread_count(), hits.size()])
	NotificationCenter.mark_all_read("Finance")
	TestFixtures.check(res, "marking a kind that is already read reports nothing",
		hits.size() == 1, "changed %d" % hits.size())
	NotificationCenter.mark_all_read()
	TestFixtures.check(res, "mark_all_read with no kind quiets the bell",
		done.read and mood.read and not NotificationCenter.has_unread()
			and NotificationCenter.read_count() == 4 and hits.size() == 2,
		"read %d changed %d" % [NotificationCenter.read_count(), hits.size()])
	NotificationCenter.changed.disconnect(watcher)


#Case 10: the panel title, its colour and the name and date lines every screen reads.
static func _case_titles(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	NotificationCenter.reset()
	var done: NotificationData = NotificationCenter.push(
		NotificationData.TYPE_CONTRACT_COMPLETED, 31, {"name": "Ridge Patrol", "reward": 2500})
	var lost: NotificationData = NotificationCenter.push(NotificationData.TYPE_CONTRACT_FAILED, 31,
		{"name": "Ridge Patrol"})
	var offer: NotificationData = NotificationCenter.push(OFFER_TYPE, 32, {"lender": "House"})
	var up: NotificationData = NotificationCenter.push(NotificationData.TYPE_STOCK_MOVE, 33,
		{"company": "Ironvein", "pct": 12.5, "band": 2})
	var down: NotificationData = NotificationCenter.push(NotificationData.TYPE_STOCK_MOVE, 34,
		{"company": "Saltworks", "pct": -3.0, "band": -1})
	var odd: NotificationData = NotificationCenter.push(MOOD_TYPE, 35, {"name": "Mood"},
		NotificationData.Urgency.IMPORTANT, "Mercenary")
	TestFixtures.check(res, "a failed contract titles itself like a completed one",
		done.title_text() == "Contract Complete" and lost.title_text() == "Contract Complete"
			and done.title_color() == NotificationData.TITLE_CONTRACT
			and lost.title_color() == NotificationData.TITLE_CONTRACT,
		"%s / %s" % [done.title_text(), lost.title_text()])
	TestFixtures.check(res, "a loan offer titles itself in budget yellow",
		offer.title_text() == "Loan Offer Received"
			and offer.title_color() == NotificationData.TITLE_LOAN,
		"%s %s" % [offer.title_text(), str(offer.title_color())])
	TestFixtures.check(res, "a stock title reads the band as five percent steps",
		up.title_text() == "Stock Up 10%" and down.title_text() == "Stock Down 5%",
		"%s / %s" % [up.title_text(), down.title_text()])
	TestFixtures.check(res, "a rise titles in green and a fall in red",
		up.title_color() == NotificationData.TITLE_STOCK_UP
			and down.title_color() == NotificationData.TITLE_STOCK_DOWN
			and up.rising() and not down.rising(),
		"%s / %s" % [str(up.title_color()), str(down.title_color())])
	TestFixtures.check(res, "an unknown type titles itself from its type in cream",
		odd.title_text() == String(MOOD_TYPE)
			and odd.title_color() == NotificationData.TITLE_UNKNOWN,
		"%s %s" % [odd.title_text(), str(odd.title_color())])
	TestFixtures.check(res, "the name line reads the contract, the lender or the company",
		done.name_text() == "Ridge Patrol" and offer.name_text() == "House"
			and up.name_text() == "Ironvein",
		"%s / %s / %s" % [done.name_text(), offer.name_text(), up.name_text()])
	var want: String = TrynnCalendar.date_text(done.minute) + " - "
	want += TrynnCalendar.time_text(done.minute)
	TestFixtures.check(res, "the date line follows the game calendar",
		done.when_text() == want, done.when_text())
	TestFixtures.check(res, "grouped prints thousands separators around a signed number",
		TransactionData.grouped(2500) == "2,500" and TransactionData.grouped(999) == "999"
			and TransactionData.grouped(1234567) == "1,234,567"
			and TransactionData.grouped(-2500) == "-2,500",
		"%s %s" % [TransactionData.grouped(2500), TransactionData.grouped(1234567)])


#Case 11: the alerted signal fires once per arrival; the first raise of a seeded trigger arrives already alerted.
static func _case_alerted(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	var probe := &"alertProbe"
	var saved: Dictionary = NotificationCenter.rules.duplicate()
	NotificationCenter.rules.clear()
	NotificationCenter.reset()
	var alerts: Array[int] = []
	var pushes: Array[int] = []
	var on_alert: Callable = func(alerted_row: NotificationData) -> void: alerts.append(alerted_row.id)
	var on_push: Callable = func(pushed_row: NotificationData) -> void: pushes.append(pushed_row.id)
	NotificationCenter.alerted.connect(on_alert)
	NotificationCenter.pushed.connect(on_push)
	var loud: NotificationData = NotificationCenter.push(MOOD_TYPE, 1)
	var quiet: NotificationData = NotificationCenter.push(MOOD_TYPE, 2, {}, NotificationData.Urgency.URGENT, "", true)
	TestFixtures.check(res, "a fresh push alerts once and a push already alerted only lists",
		loud.alerted and quiet.alerted and alerts.size() == 1 and alerts[0] == loud.id
			and pushes.size() == 2, "alerts %s, pushes %s" % [alerts, pushes])
	var table: Dictionary = {7: HOURS_URGENT, 9: HOURS_URGENT}
	var open_fn: Callable = func() -> Array: return table.keys()
	var hours_fn: Callable = func(id: int) -> float: return float(table.get(id, HOURS_OPEN))
	NotificationCenter.add_rule(probe, {"open": open_fn, "hours_left": hours_fn, "kind": "Finance"})
	NotificationCenter.mark_seeded(probe, 9)
	alerts.clear()
	var now: int = CampaignClock.now()
	NotificationCenter.escalate(now)
	var raised: NotificationData = NotificationCenter.latest(probe, 7)
	var seeded: NotificationData = NotificationCenter.latest(probe, 9)
	TestFixtures.check(res, "a raise alerts while the first raise of a seeded trigger arrives alerted in silence",
		raised != null and seeded != null and raised.alerted and seeded.alerted
			and alerts.size() == 1 and alerts[0] == raised.id, "alerts %s" % [alerts])
	alerts.clear()
	var later: int = now + NotificationCenter.REFIRE_MINUTES
	NotificationCenter.escalate(later)
	var unread_quiet: bool = alerts.is_empty()
	if raised != null and seeded != null:
		NotificationCenter.mark_read(raised.id)
		NotificationCenter.mark_read(seeded.id)
	NotificationCenter.escalate(later)
	var again_7: NotificationData = NotificationCenter.latest(probe, 7)
	var again_9: NotificationData = NotificationCenter.latest(probe, 9)
	TestFixtures.check(res, "unread rows never re-alert and every read re-fire alerts, the seeded trigger too",
		unread_quiet and again_7 != null and again_9 != null and alerts.size() == 2
			and alerts.has(again_7.id) and alerts.has(again_9.id), "alerts %s" % [alerts])
	NotificationCenter.mark_seeded(probe, 11)
	NotificationCenter.reset()
	table[11] = HOURS_URGENT
	alerts.clear()
	NotificationCenter.escalate(later)
	TestFixtures.check(res, "a reset forgets the seeded triggers, so every open deadline alerts",
		alerts.size() == 3, "alerts %s" % [alerts])
	NotificationCenter.remove_rule(probe)
	for key: Variant in saved.keys():
		NotificationCenter.add_rule(StringName(key), saved[key])
	NotificationCenter.alerted.disconnect(on_alert)
	NotificationCenter.pushed.disconnect(on_push)
	NotificationCenter.reset()


#Sends the first merc to the first open posting and marks the run finished with the verdict.
static func _forced_done(verdict: String) -> BoardEntry:
	var entry: BoardEntry = _open_entry()
	if entry == null or GameState.mercs.is_empty():
		return null
	var team: Array[MercenaryData] = [GameState.mercs[0]]
	var scheduler: ContractScheduler = GameState.board.activate(entry.id, team, 0,
		CampaignClock.now(), Callable())
	if scheduler == null:
		return null
	scheduler.phase = ContractScheduler.Phase.DONE
	scheduler.all_dead = false
	scheduler.run.verdict = verdict
	scheduler.run.reward_paid = SETTLE_REWARD if verdict == BoardEntry.STATUS_SUCCEEDED else 0
	return entry


#Settles a finished run the way process_until does, then brings the merc home.
static func _settle_now(entry: BoardEntry) -> void:
	GameState._clock_depth += 1
	GameState._settle(entry)
	GameState._clock_depth -= 1
	GameState.mercs[0].on_contract = false


static func _ledger_since(count: int) -> Array[TransactionData]:
	var out: Array[TransactionData] = []
	for i: int in range(count, FinanceLedger.transactions.size()):
		out.append(FinanceLedger.transactions[i])
	return out


#Case 12: a settled success banks the reward, then pays the merc bonus out of it on a ledger line
#of its own; a failure, or a success with no member alive and free, pays nothing.
static func _case_settle_bonus(res: Dictionary, host: Node) -> void:
	_fresh()
	GuiSortTests._fill_board()
	await host.get_tree().process_frame
	BenefitsManager.set_benefit("contract", BONUS_PCT)
	var won: BoardEntry = _forced_done(BoardEntry.STATUS_SUCCEEDED)
	if won == null:
		TestFixtures.check(res, "the board opened a posting to settle", false, "no open posting")
		BenefitsManager.reset()
		return
	var bank: int = GameState.bank_notes
	var ledger: int = FinanceLedger.transactions.size()
	_settle_now(won)
	TestFixtures.check(res, "a settled success banks the reward less the merc bonus",
		won.status == BoardEntry.STATUS_SUCCEEDED
			and GameState.bank_notes == bank + SETTLE_REWARD - SETTLE_BONUS,
		"status %s, bank %d from %d" % [won.status, GameState.bank_notes, bank])
	var rows: Array[TransactionData] = _ledger_since(ledger)
	var reward_at: int = -1
	var bonus_at: int = -1
	for i: int in rows.size():
		if rows[i].reason == GameState.REASON_CONTRACT and rows[i].amount == SETTLE_REWARD:
			reward_at = i
		if rows[i].reason == GameState.REASON_BONUS:
			bonus_at = i
	var line: TransactionData = rows[bonus_at] if bonus_at >= 0 else null
	var shown: String = "none" if line == null else "%s %d" % [line.label, line.amount]
	TestFixtures.check(res, "the merc bonus leaves after the reward on a ledger line of its own",
		reward_at >= 0 and bonus_at > reward_at and line.amount == -SETTLE_BONUS
			and line.label.ends_with("Merc Bonus")
			and line.label == GameState.LABEL_BONUS % GameState.entry_name(won),
		"reward at %d, bonus at %d, line %s" % [reward_at, bonus_at, shown])
	TestFixtures.check(res, "the merc bonus ledger row files under Benefit",
		line != null and FinanceLedger.category_of(line.reason) == "Benefit",
		"category %s" % ("none" if line == null else FinanceLedger.category_of(line.reason)))
	var result: ContractResultData = GameState.result_of(won.id)
	TestFixtures.check(res, "the recorded result splits the same bonus the bank paid out",
		result != null and result.bonus_pct == BONUS_PCT and result.bonus() == SETTLE_BONUS
			and result.fly_amount() == SETTLE_REWARD - SETTLE_BONUS,
		"recorded %s" % str(result != null))
	var lost: BoardEntry = _forced_done(BoardEntry.STATUS_FAILED)
	if lost == null:
		TestFixtures.check(res, "the board opened a second posting to settle", false,
			"no open posting")
		BenefitsManager.reset()
		return
	var bank_lost: int = GameState.bank_notes
	var ledger_lost: int = FinanceLedger.transactions.size()
	_settle_now(lost)
	var bonus_lines: Array[String] = []
	for row: TransactionData in _ledger_since(ledger_lost):
		if row.reason == GameState.REASON_BONUS:
			bonus_lines.append("%s %d" % [row.label, row.amount])
	TestFixtures.check(res, "a settled failure debits no bonus and logs no bonus line",
		lost.status == BoardEntry.STATUS_FAILED and GameState.bank_notes == bank_lost
			and bonus_lines.is_empty(),
		"status %s, bank %d from %d, lines %s" % [lost.status, GameState.bank_notes, bank_lost,
			str(bonus_lines)])
	var taken: BoardEntry = _forced_done(BoardEntry.STATUS_SUCCEEDED)
	if taken == null:
		TestFixtures.check(res, "the board opened a third posting to settle", false, "no open posting")
		BenefitsManager.reset()
		return
	taken.scheduler.run.kidnapped.append(GameState.mercs[0])
	var bank_taken: int = GameState.bank_notes
	var ledger_taken: int = FinanceLedger.transactions.size()
	_settle_now(taken)
	var unpaid: ContractResultData = GameState.result_of(taken.id)
	var taken_lines: int = 0
	for row: TransactionData in _ledger_since(ledger_taken):
		if row.reason == GameState.REASON_BONUS:
			taken_lines += 1
	TestFixtures.check(res, "a success whose whole crew was taken banks the reward and debits no bonus",
		GameState.bank_notes == bank_taken + SETTLE_REWARD and taken_lines == 0 and unpaid != null
			and unpaid.living().is_empty() and unpaid.bonus() == 0
			and unpaid.fly_amount() == SETTLE_REWARD,
		"bank %d from %d, lines %d, bonus %d" % [GameState.bank_notes, bank_taken, taken_lines,
			-1 if unpaid == null else unpaid.bonus()])
	BenefitsManager.reset()


#Case 12b: a merc who departed mid-contract is owed a share on the merc at settlement; the bank debits the
#whole pool, a failure owes nothing, and a defector forfeits the share and leaves the roster.
static func _case_settle_owed(res: Dictionary, host: Node) -> void:
	_fresh()
	GuiSortTests._fill_board()
	TestFixtures.add_mercs(SETTLE_ROSTER - GameState.mercs.size())
	await host.get_tree().process_frame
	BenefitsManager.set_benefit("contract", BONUS_PCT)
	var won: BoardEntry = _forced_done(BoardEntry.STATUS_SUCCEEDED)
	if won == null or GameState.mercs.size() < 3:
		TestFixtures.check(res, "the board opened a posting to settle with a departed merc", false,
			"no open posting or fewer than three mercs")
		BenefitsManager.reset()
		return
	var gone: MercenaryData = GameState.mercs[1]
	var owed_before: int = gone.bonus_owed
	var paid: int = SETTLE_BONUS - SETTLE_SHARE
	won.scheduler.run.departed.append(gone)
	var bank: int = GameState.bank_notes
	var ledger: int = FinanceLedger.transactions.size()
	_settle_now(won)
	var debits: Array[int] = []
	for row: TransactionData in _ledger_since(ledger):
		if row.reason == GameState.REASON_BONUS:
			debits.append(row.amount)
	TestFixtures.check(res, "a success with a departed merc debits the whole pool",
		GameState.bank_notes == bank + SETTLE_REWARD - SETTLE_BONUS and debits == [-SETTLE_BONUS],
		"bank %d from %d, bonus rows %s" % [GameState.bank_notes, bank, str(debits)])
	var result: ContractResultData = GameState.result_of(won.id)
	var away: ResultMemberData = null if result == null else result.member_of(gone.merc_uid)
	var home: ResultMemberData = null if result == null else result.member_of(GameState.mercs[0].merc_uid)
	TestFixtures.check(res, "the departed merc reads Departed and its share is owed on the merc, not paid",
		away != null and home != null and away.fate == ResultMemberData.Fate.DEPARTED and away.pay == 0
			and away.owed == SETTLE_SHARE and home.pay == paid
			and gone.bonus_owed == owed_before + SETTLE_SHARE
			and gone.back_owed() == gone.backpay + gone.bonus_owed,
		"fate %s, owed %d, merc owes %d" % ["none" if away == null else away.fate_name(),
			-1 if away == null else away.owed, gone.bonus_owed])
	TestFixtures.check(res, "the departed merc stays on the roster holding its owed share",
		GameState.merc_by_uid(gone.merc_uid) == gone and gone.bonus_owed - owed_before == SETTLE_SHARE
			and GameState.removed_by_uid(gone.merc_uid) == null,
		"on roster %s, owes %d" % [str(GameState.merc_by_uid(gone.merc_uid) != null), gone.bonus_owed])
	var again: BoardEntry = _forced_done(BoardEntry.STATUS_SUCCEEDED)
	if again == null:
		TestFixtures.check(res, "the board opened a second posting with a departed merc", false, "no open posting")
		BenefitsManager.reset()
		return
	again.scheduler.run.departed.append(gone)
	_settle_now(again)
	TestFixtures.check(res, "a second departure adds a second owed share",
		gone.bonus_owed == owed_before + 2 * SETTLE_SHARE,
		"owes %d from %d" % [gone.bonus_owed, owed_before])
	var lost: BoardEntry = _forced_done(BoardEntry.STATUS_FAILED)
	if lost == null:
		TestFixtures.check(res, "the board opened a third posting with a departed merc", false, "no open posting")
		BenefitsManager.reset()
		return
	lost.scheduler.run.departed.append(gone)
	var bank_lost: int = GameState.bank_notes
	_settle_now(lost)
	var unpaid: ContractResultData = GameState.result_of(lost.id)
	var left: ResultMemberData = null if unpaid == null else unpaid.member_of(gone.merc_uid)
	TestFixtures.check(res, "a failure with a departed merc owes nothing more and moves no money",
		gone.bonus_owed == owed_before + 2 * SETTLE_SHARE and GameState.bank_notes == bank_lost
			and left != null and left.fate == ResultMemberData.Fate.DEPARTED and left.owed == 0,
		"owes %d, bank %d from %d" % [gone.bonus_owed, GameState.bank_notes, bank_lost])
	_settle_defector(res)
	BenefitsManager.reset()


#Case 12c: a defector is paid and owed nothing, the bank still debits the whole pool and the merc leaves
#the roster for the defector pool.
static func _settle_defector(res: Dictionary) -> void:
	var turned: BoardEntry = _forced_done(BoardEntry.STATUS_SUCCEEDED)
	if turned == null:
		TestFixtures.check(res, "the board opened a posting with a defector", false, "no open posting")
		return
	var rat: MercenaryData = GameState.mercs[2]
	var uid: int = rat.merc_uid
	var owed_before: int = rat.bonus_owed
	turned.scheduler.run.defectors.append(rat)
	var bank: int = GameState.bank_notes
	var ledger: int = FinanceLedger.transactions.size()
	_settle_now(turned)
	var debits: Array[int] = []
	for line: TransactionData in _ledger_since(ledger):
		if line.reason == GameState.REASON_BONUS:
			debits.append(line.amount)
	var result: ContractResultData = GameState.result_of(turned.id)
	var row: ResultMemberData = null if result == null else result.member_of(uid)
	var home: ResultMemberData = null if result == null else result.member_of(GameState.mercs[0].merc_uid)
	TestFixtures.check(res, "a defector forfeits its share and the living merc takes the whole pool",
		row != null and home != null and row.fate == ResultMemberData.Fate.DEFECTED and row.pay == 0
			and row.owed == 0 and home.pay == SETTLE_BONUS and result.counted().size() == 1
			and rat.bonus_owed == owed_before,
		"fate %s, pay %d, owed %d, home %d" % ["none" if row == null else row.fate_name(),
			-1 if row == null else row.pay, -1 if row == null else row.owed,
			-1 if home == null else home.pay])
	TestFixtures.check(res, "a success with a defector debits the whole pool",
		GameState.bank_notes == bank + SETTLE_REWARD - SETTLE_BONUS and debits == [-SETTLE_BONUS],
		"bank %d from %d, bonus rows %s" % [GameState.bank_notes, bank, str(debits)])
	TestFixtures.check(res, "a settled defector leaves the roster and the payroll",
		GameState.merc_by_uid(uid) == null and not GameState.mercs.has(rat)
			and not GameState.payroll_mercs().has(rat),
		"on roster %s, on payroll %s" % [str(GameState.mercs.has(rat)),
			str(GameState.payroll_mercs().has(rat))])
	TestFixtures.check(res, "a settled defector row still has a portrait view",
		row != null and row.merc_view() != null, "view missing")
	var pool_uids: Array[int] = []
	for filed: RemovedMercRecord in GameState.defectors():
		pool_uids.append(filed.uid)
	var record: RemovedMercRecord = GameState.removed_by_uid(uid)
	TestFixtures.check(res, "the defector is filed in the defector pool under the defected reason",
		record != null and record.reason == GameState.REMOVED_DEFECTED and record.merc == rat
			and pool_uids == [uid],
		"reason %s, pool %s" % ["none" if record == null else record.reason, str(pool_uids)])


#Case 13: an 8:00 refill posts in silence and counts what it posted on one bell row for the day.
static func _case_postings(res: Dictionary, host: Node) -> void:
	_fresh()
	GuiSortTests._fill_board()
	await host.get_tree().process_frame
	var freed: int = 0
	for entry: BoardEntry in GameState.board.available():
		if freed < POSTINGS_FREED and GameState.reject(entry.id):
			freed += 1
	var posted: Array[int] = []
	var on_posted: Callable = func(added: int) -> void: posted.append(added)
	GameState.contracts_posted.connect(on_posted)
	var due: int = GameState.board.next_refill_minute(CampaignClock.now())
	await GameState.process_until(due)
	GameState.contracts_posted.disconnect(on_posted)
	var total: int = 0
	for step: int in posted:
		total += step
	var rows: Array[NotificationData] = []
	for row: NotificationData in NotificationCenter.items:
		if row.type == NotificationData.TYPE_NEW_POSTINGS:
			rows.append(row)
	var counted: int = rows[0].count() if rows.size() == 1 else -1
	TestFixtures.check(res, "an 8:00 refill rings one new postings row counting every posting",
		freed == POSTINGS_FREED and total >= freed and rows.size() == 1 and counted == total
			and rows[0].trigger_id == TrynnCalendar.day_index(due) and rows[0].kind == "Contract",
		"freed %d, posted %s, rows %d, count %d" % [freed, str(posted), rows.size(), counted])
	if rows.size() == 1:
		TestFixtures.check(res, "the new postings row reads its count in the title",
			rows[0].title_text() == "%d new contracts on the board" % total, rows[0].title_text())


#Item 11 dot hand-off: the bell's unread dot sits inward from the corner, matching the stage 1
#NotificationDot default (Addendum 2), not the old outward -5, -5 offset.
static func _case_bell(res: Dictionary) -> void:
	TestFixtures.check(res, "the bell's DOT_OFFSET moved in to match NotificationDot's default",
		NotificationBell.DOT_OFFSET == Vector2(2, 2), "%s" % [NotificationBell.DOT_OFFSET])
