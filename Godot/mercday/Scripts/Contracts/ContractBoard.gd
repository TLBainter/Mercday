class_name ContractBoard
extends RefCounted

#The posting board: what is on offer, what the guild took and what ran out of time.
#It never touches money; the travel debit and the reward credit belong to the caller.
#Every number it posts with lives in ContractConfig, read through ContractLibrary.config() at each use.

var entries: Array[BoardEntry] = []
var next_id: int = 1
#Generated contracts waiting for roster room; the daily round fills it and provisions from it.
var pool: ContractPool = ContractPool.new()


#The opening board: count postings (-1 posts board_target), every contract row once before any repeats.
func launch(now: int, count: int = -1) -> void:
	entries.clear()
	next_id = 1
	var rows: Array[String] = ContractLibrary.row_names()
	if rows.is_empty():
		return
	var target: int = ContractLibrary.config().board_target if count < 0 else count
	_open_with(rows, target, now)


#Posts target openings from rows, each row once before any repeats; fresh draws make up for a null draw.
func _open_with(rows: Array[String], target: int, now: int) -> void:
	var picks: Array[String] = []
	picks.assign(rows)
	picks.shuffle()
	while picks.size() < target:
		picks.append(rows[randi() % rows.size()])
	picks.resize(target)
	for name: String in picks:
		var contract: ContractData = ContractGenerator.generate_named(name)
		if contract != null and ContractGenerator.level_ok(contract, contract.contract_level):
			post(contract, now)
	if entries.size() < target:
		_post_drawn(target - entries.size(), now, rows.duplicate())


#Retired from the clock (DailyContractRound posts at 8:00); kept as a plain top-up for previews and test fixtures.
func refill(now: int, cap: int = -1) -> Array[BoardEntry]:
	return _post_drawn(board_room(cap), now, ContractLibrary.row_names())


#Posts up to room fresh draws from rows; a row whose draw comes back null leaves rows for this call.
func _post_drawn(room: int, now: int, rows: Array[String]) -> Array[BoardEntry]:
	var added: Array[BoardEntry] = []
	var gated: int = 0
	while room > 0 and not rows.is_empty():
		var pick: int = randi() % rows.size()
		var contract: ContractData = ContractGenerator.generate_named(rows[pick])
		if contract != null and not ContractGenerator.level_ok(contract, contract.contract_level):
			gated = contract.contract_level
			contract = null
		if contract == null:
			rows.remove_at(pick)
			continue
		added.append(post(contract, now))
		room -= 1
	if room > 0 and gated > 0:
		ContractGenerator.note_no_row(gated)
	return added


#Open slots under the target, or under cap when cap is lower; campaign postings sit on top and never take one.
func board_room(cap: int = -1) -> int:
	var target: int = ContractLibrary.config().board_target
	if cap >= 0:
		target = mini(target, cap)
	return target - own_open()


#The board's own open postings; campaign postings are not counted.
func own_open() -> int:
	var own: int = 0
	for item: BoardEntry in entries:
		if item.is_open() and item.campaign_id == 0:
			own += 1
	return own


#The next 8:00 strictly after this minute.
func next_refill_minute(now: int) -> int:
	return ContractScheduler.next_hour_after(now, ContractLibrary.config().board_refill_hour)


#The contract's Min Mercs when set, else board_merc_min.
static func merc_min_for(contract: ContractData) -> int:
	if contract != null and contract.min_mercs > 0:
		return contract.min_mercs
	return ContractLibrary.config().board_merc_min


#One posting with its Q29 placeholders rolled once.
func post(contract: ContractData, now: int) -> BoardEntry:
	var item := BoardEntry.new()
	item.id = next_id
	next_id += 1
	item.contract = contract
	var cfg: ContractConfig = ContractLibrary.config()
	item.posted_minute = now
	var hours: int = randi_range(cfg.board_expiry_min_hours, cfg.board_expiry_max_hours)
	item.expires_minute = now + hours * CampaignClock.MINUTES_PER_HOUR
	item.distance_km = randi_range(cfg.board_distance_min_km, cfg.board_distance_max_km)
	if contract != null and contract.local:
		item.distance_km = 0
	item.completion_hours = completion_hours(contract)
	item.issuer_id = seat_for_row(contract, item.id)
	item.issuer = issuer_text(contract, item.issuer_id)
	item.issuer_type = issuer_word(contract, item.issuer_id)
	item.deadline_minute = _placeholder_deadline(item)
	item.merc_min = merc_min_for(contract)
	item.image = ""
	item.status = BoardEntry.STATUS_DRAFT
	item.closed_minute = -1
	if contract != null:
		contract.status = BoardEntry.STATUS_DRAFT
	entries.append(item)
	return item


#Every Draft posting whose deadline has passed; each one leaves the offer list.
func expire_due(now: int) -> Array[BoardEntry]:
	var out: Array[BoardEntry] = []
	for item: BoardEntry in entries:
		if item.is_open() and item.expires_minute <= now:
			item.status = BoardEntry.STATUS_EXPIRED
			item.closed_minute = now
			out.append(item)
	return out


#The soonest deadline still standing; -1 when nothing is on offer.
func next_expiry_minute(_now: int) -> int:
	var soonest: int = -1
	for item: BoardEntry in entries:
		if not item.is_open():
			continue
		if soonest < 0 or item.expires_minute < soonest:
			soonest = item.expires_minute
	return soonest


func available() -> Array[BoardEntry]:
	var out: Array[BoardEntry] = []
	for item: BoardEntry in entries:
		if item.is_open():
			out.append(item)
	return out


func active_entries() -> Array[BoardEntry]:
	var out: Array[BoardEntry] = []
	for item: BoardEntry in entries:
		if item.is_active():
			out.append(item)
	return out


func entry(id: int) -> BoardEntry:
	for candidate: BoardEntry in entries:
		if candidate.id == id:
			return candidate
	return null


func reject(id: int) -> bool:
	var target: BoardEntry = entry(id)
	if target == null or not target.is_open():
		return false
	target.status = BoardEntry.STATUS_REJECTED
	target.closed_minute = CampaignClock.now()
	return true


#Moves a pooled entry onto the board: a fresh id, Draft, posted now, offered until its auto-reject minute.
func post_pooled(item: BoardEntry, now: int) -> BoardEntry:
	if item == null:
		return null
	pool.remove(item)
	item.id = next_id
	next_id += 1
	item.status = BoardEntry.STATUS_DRAFT
	item.posted_minute = now
	item.closed_minute = -1
	var reject_at: int = Reachability.auto_reject_minute(item, Reachability.MODES, now)
	if reject_at >= 0:
		item.expires_minute = reject_at
	if item.contract != null:
		item.contract.status = BoardEntry.STATUS_DRAFT
	entries.append(item)
	return item


#Sends a team: the run is built by ContractRun.make with the travel mode, then the scheduler departs.
func activate(id: int, team: Array[MercenaryData], travel_minutes: int, now: int,
		line_fn: Callable, leader_uid: int = -1, mode: String = "foot",
		roles: Dictionary = {}) -> ContractScheduler:
	var target: BoardEntry = entry(id)
	if target == null or not target.is_open() or team.is_empty():
		return null
	var run := ContractRun.make(target.contract, team, line_fn, leader_uid)
	run.travel_mode = mode if mode != "" else "foot"
	run.roles = roles.duplicate()
	run.deadline_minute = target.deadline_minute
	run.completion_minutes = Reachability.completion_minutes(target)
	target.log_lines.clear()
	target.verdict = ""
	target.status = BoardEntry.STATUS_ACTIVE
	target.closed_minute = -1
	target.scheduler = ContractScheduler.create(run, travel_minutes, now)
	return target.scheduler


#Closes a finished run. A failed story posting returns to the pool as a pooled copy; any other failure stays closed.
func settle(entry_done: BoardEntry, now: int) -> String:
	if entry_done == null or entry_done.scheduler == null:
		return ""
	var scheduler: ContractScheduler = entry_done.scheduler
	if not scheduler.is_done():
		return ""
	var run: ContractRun = scheduler.run
	entry_done.log_lines.assign(run.log_lines)
	entry_done.verdict = run.verdict
	entry_done.scheduler = null
	entry_done.status = entry_done.verdict
	entry_done.closed_minute = now
	if entry_done.story and run.verdict == BoardEntry.STATUS_FAILED and entry_done.contract != null:
		var copy: BoardEntry = pool.return_rejected(entry_done, 0, now)
		copy.reject_count = entry_done.reject_count
		copy.value = entry_done.value
		copy.contract.reward_notes = entry_done.contract.reward_notes
	return entry_done.verdict


#Wave 1 placeholder: the rolled window is the time to leave on foot; GenDeadline replaces it.
func _placeholder_deadline(item: BoardEntry) -> int:
	return Reachability.arrival_minute(item.expires_minute,
		Reachability.base_minutes(Reachability.FOOT, item.distance_km)) + Reachability.completion_minutes(item)


#Event hours (a check primary counts its Checks.tsv Time, an event style primary its row Time) plus the gaps;
#a timeline sums its success path.
static func completion_hours(contract: ContractData) -> int:
	if contract == null:
		return 0
	var events: int = contract.rolled_mishaps.size()
	var primary_hours: int = 0
	if contract.style == "timeline":
		events += 1
		primary_hours = timeline_hours(contract.completion)
	elif contract.assigned_primary_event != "":
		events += 1
		primary_hours = 1
		if CheckStore.is_check_name(contract.assigned_primary_event):
			primary_hours = CheckStore.hours(CheckStore.parse(CheckStore.find(contract.assigned_primary_event)))
		elif contract.style == "event" and contract.time_minutes > 0:
			primary_hours = maxi(1, ceili(contract.time_minutes / 60.0))
	if events <= 0:
		return 0
	return events + (primary_hours - mini(primary_hours, 1)) + (events - 1) * ContractLibrary.config().board_gap_hours


#Hours of a timeline cell's all-success path: check rows' Time, event steps' time; 1 for a broken cell.
static func timeline_hours(cell: String) -> int:
	if TimelineGrammar.error(cell) != "":
		return 1
	var steps: Array = TimelineGrammar.parse(cell)
	var ended: Dictionary = {}
	var total: int = 0
	for index: int in range(steps.size()):
		if not TimelineGrammar.runs(steps, index, ended):
			continue
		var step: TimelineGrammar.Step = steps[index]
		if step.kind == "check":
			total += CheckStore.hours(CheckStore.parse(CheckStore.find(step.name)))
		else:
			total += maxi(1, ceili(float(step.time) / 60.0))
		ended[step.id] = "success"
	return maxi(1, total)


#A row's Issuer Type word and the seat group it takes.
const ISSUER_GROUPS: Dictionary = {"person": "people", "place": "places", "org": "orgs"}


static func group_of_word(word: String) -> String:
	return String(ISSUER_GROUPS.get(word, ""))


static func word_of_group(group: String) -> String:
	for word: String in ISSUER_GROUPS:
		if ISSUER_GROUPS[word] == group:
			return word
	return ""


#The row's Issuer Type when set, else the seat's kind.
static func issuer_word(contract: ContractData, seat: int) -> String:
	if contract != null and ISSUER_GROUPS.has(contract.issuer_type):
		return contract.issuer_type
	return word_of_group(ContractIssuer.kind_of_seat(seat))


#A person row names its requestor (else its class); place and org rows name their Issuer cell; else the seat.
static func issuer_text(contract: ContractData, seat: int) -> String:
	var cell: String = contract.issuer.strip_edges() if contract != null else ""
	var word: String = contract.issuer_type if contract != null else ""
	if word == "person":
		var requestor: String = contract.requestor_name.strip_edges()
		if requestor != "" and requestor != "Unknown":
			return requestor
		if cell != "":
			return cell
	elif (word == "place" or word == "org") and cell != "":
		return cell
	if IssuerOpinion.seat_count() > 0:
		return IssuerOpinion.name_of(seat)
	return "%s Issuer" % contract.contract_type if contract != null else "Issuer"


#A typed row takes the seat of its group the entry id names; a blank row keeps the legacy entry id rule.
static func seat_for_row(contract: ContractData, entry_id: int) -> int:
	var group: String = group_of_word(contract.issuer_type) if contract != null else ""
	if group == "":
		return IssuerOpinion.seat_for_entry(entry_id)
	return ContractIssuer.seat_id(group, posmod(entry_id - 1, ContractIssuer.group_size(group)))
