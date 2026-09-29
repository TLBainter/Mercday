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


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_fresh()
	await host.get_tree().process_frame
	await _case_push_read(res, host)
	await _case_listed(res, host)
	await _case_resolve(res, host)
	await _case_escalate(res, host)
	await _case_result_split(res, host)
	await _case_preview(res, host)
	await _case_settle_record(res, host)
	await _case_base_patch(res, host)
	await _case_counts(res, host)
	await _case_titles(res, host)
	_case_bell(res)
	SubscriptionManager.reset()
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


static func _ids_of(rows: Array[NotificationData]) -> Array[int]:
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
	var unread: Array[int] = _ids_of(NotificationCenter.listed(true,
		NotificationCenter.SORT_RECENCY, NotificationCenter.FILTER_ALL))
	var read_rows: Array[int] = _ids_of(NotificationCenter.listed(false,
		NotificationCenter.SORT_RECENCY, NotificationCenter.FILTER_ALL))
	TestFixtures.check(res, "the unread tab sorts by recency with the newer id first",
		unread == [1, 3, 2, 4] or unread == [1, 4, 3, 2], "got %s" % str(unread))
	TestFixtures.check(res, "the read tab holds only the row that was read",
		read_rows == [5], "got %s" % str(read_rows))
	var by_urgency: Array[int] = _ids_of(NotificationCenter.listed(true,
		NotificationCenter.SORT_URGENCY, NotificationCenter.FILTER_ALL))
	TestFixtures.check(res, "the urgency sort lifts the urgent row over the newer one",
		by_urgency == [4, 1, 3, 2], "got %s" % str(by_urgency))
	var contract_rows: Array[int] = _ids_of(NotificationCenter.listed(true,
		NotificationCenter.SORT_RECENCY, "Contract"))
	var finance_rows: Array[int] = _ids_of(NotificationCenter.listed(true,
		NotificationCenter.SORT_RECENCY, "Finance"))
	var merc_rows: Array[int] = _ids_of(NotificationCenter.listed(true,
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
		odd.net() == 880 and odd.bonus() == 88 and _pays(odd) == [29, 30, 29, 0]
			and odd.guild_share() == 792 and odd.fly_amount() == 792,
		"bonus %d, pays %s, share %d" % [odd.bonus(), str(_pays(odd)), odd.guild_share()])
	var lost_mvp: ContractResultData = _result(1000, 120, 10, false)
	lost_mvp.members = [_member(1, "Leader", 2, 10, alive), _member(2, "Guide", 7, 20, alive),
		_member(3, "Escort", 3, 30, alive), _member(4, "Driver", 9, 99, dead)]
	lost_mvp.members[3].mvp = true
	lost_mvp.assign_pay()
	TestFixtures.check(res, "with the MVP dead the remainder goes to the highest level living",
		_pays(lost_mvp) == [29, 30, 29, 0],
		"pays %s" % str(_pays(lost_mvp)))
	var tie_leader: ContractResultData = _result(1000, 130, 10, false)
	tie_leader.members = [_member(1, "Guide", 7, 10, alive), _member(2, "Leader", 7, 20, alive),
		_member(3, "Escort", 3, 30, held)]
	tie_leader.assign_pay()
	TestFixtures.check(res, "a tie at the top level pays the remainder to the Leader",
		_pays(tie_leader) == [43, 44, 0],
		"pays %s" % str(_pays(tie_leader)))
	var tie_order: ContractResultData = _result(1000, 130, 10, false)
	tie_order.members = [_member(1, "Guide", 7, 10, alive), _member(2, "Escort", 7, 20, alive),
		_member(3, "Leader", 7, 30, dead)]
	tie_order.assign_pay()
	TestFixtures.check(res, "a tie with no living Leader pays the first tied member in the list",
		_pays(tie_order) == [44, 43, 0],
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
			and failure.net() == -150 and failure.guild_share() == -150
			and failure.fly_amount() == -150,
		"bonus %d, net %d, fly %d" % [failure.bonus(), failure.net(), failure.fly_amount()])


#Case 6: the two sample results the click-through starts from.
static func _case_preview(res: Dictionary, host: Node) -> void:
	_fresh()
	await host.get_tree().process_frame
	var bank: int = GameState.bank_notes
	var roster: int = GameState.roster.size()
	var seen: Array[int] = []
	var watcher: Callable = func(id: int) -> void: seen.append(id)
	GameState.results_seen.connect(watcher)
	var ids: Array[int] = GameState.seed_results_preview()
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
		rows.size() == 2 and NotificationCenter.unread_count() == 2,
		"rows %d, unread %d" % [rows.size(), NotificationCenter.unread_count()])
	var win: ContractResultData = GameState.result_of(ids[0])
	var loss: ContractResultData = GameState.result_of(ids[1])
	var expenses: int = int(round(float(win.listed_reward)
		* float(GameState.RESULT_EXPENSE_PCT) / 100.0))
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
			and loss.members[1].hp.x == 0 and loss.fly_amount() == -loss.expenses,
		"fates %s, hp %d" % [str(fates), loss.members[1].hp.x])
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
			and NotificationCenter.unread_count() == 1,
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
		sent and steps < cap and entry.status != BoardEntry.STATUS_ACTIVE,
		"sent %s, status %s, steps %d" % [str(sent), entry.status, steps])
	if entry.status == BoardEntry.STATUS_DRAFT:
		TestFixtures.check(res, "a posting the board reopened keeps no result and no row",
			not GameState.has_result(entry.id) and recorded.is_empty()
				and NotificationCenter.rows_of(NotificationData.TYPE_CONTRACT_FAILED,
					entry.id).is_empty(),
			"status %s" % entry.status)
		GameState.results_recorded.disconnect(on_result)
		GameState.money_changed.disconnect(on_money)
		return
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
		GuiTypes.merc_status_color(GuiTypes.MercStatus.AVAILABLE) == Color("#6cc36a")
			and GuiTypes.merc_status_color(GuiTypes.MercStatus.DEAD) == Color("#e8583f")
			and GuiTypes.merc_status_color(GuiTypes.MercStatus.LOAN) == Color("#f2b33d")
			and GuiTypes.merc_status_color(GuiTypes.MercStatus.ODD_JOB) == Color("#f2b33d")
			and GuiTypes.merc_status_color(GuiTypes.MercStatus.RESTING) == Color("#f3ead7"),
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
		NotificationData.grouped(2500) == "2,500" and NotificationData.grouped(999) == "999"
			and NotificationData.grouped(1234567) == "1,234,567"
			and NotificationData.grouped(-2500) == "-2,500",
		"%s %s" % [NotificationData.grouped(2500), NotificationData.grouped(1234567)])


#Item 11 dot hand-off: the bell's unread dot sits inward from the corner, matching the stage 1
#NotificationDot default (Addendum 2), not the old outward -5, -5 offset.
static func _case_bell(res: Dictionary) -> void:
	TestFixtures.check(res, "the bell's DOT_OFFSET moved in to match NotificationDot's default",
		NotificationBell.DOT_OFFSET == Vector2(2, 2), "%s" % [NotificationBell.DOT_OFFSET])
