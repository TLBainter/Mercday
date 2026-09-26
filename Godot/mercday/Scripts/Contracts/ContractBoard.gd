class_name ContractBoard
extends RefCounted

#The posting board: what is on offer, what the guild took and what ran out of time.
#It never touches money; the travel debit and the reward credit belong to the caller.
#Every number it posts with lives in ContractConfig, read through _cfg() at each use.

var entries: Array[BoardEntry] = []
var next_id: int = 1


#The tuned board numbers: the target, the refill hour, the two ranges, the gap and the merc floor.
static func _cfg() -> ContractConfig:
	return ContractLibrary.config()


#The opening board: every contract type at least once, the remaining slots drawn at random.
func launch(now: int) -> void:
	entries.clear()
	next_id = 1
	var types: Array[String] = ContractLibrary.contract_type_names()
	if types.is_empty():
		return
	var picks: Array[String] = []
	picks.assign(types)
	picks.shuffle()
	while picks.size() < _cfg().board_target:
		picks.append(types[randi() % types.size()])
	picks.resize(_cfg().board_target)
	for name: String in picks:
		var contract: ContractData = ContractGenerator.generate(name)
		if contract != null:
			post(contract, now)


#Tops the open postings back up to TARGET; returns only what was added.
func refill(now: int) -> Array[BoardEntry]:
	var added: Array[BoardEntry] = []
	var types: Array[String] = ContractLibrary.contract_type_names()
	if types.is_empty():
		return added
	while available().size() < _cfg().board_target:
		var contract: ContractData = ContractGenerator.generate(types[randi() % types.size()])
		if contract == null:
			break
		added.append(post(contract, now))
	return added


#The next 8:00 strictly after this minute.
func next_refill_minute(now: int) -> int:
	var day_start: int = now - (now % CampaignClock.MINUTES_PER_DAY)
	var at: int = day_start + _cfg().board_refill_hour * CampaignClock.MINUTES_PER_HOUR
	if at <= now:
		at += CampaignClock.MINUTES_PER_DAY
	return at


#One posting with its Q29 placeholders rolled once.
func post(contract: ContractData, now: int) -> BoardEntry:
	var item := BoardEntry.new()
	item.id = next_id
	next_id += 1
	item.contract = contract
	item.posted_minute = now
	var hours: int = randi_range(_cfg().board_expiry_min_hours, _cfg().board_expiry_max_hours)
	item.expires_minute = now + hours * CampaignClock.MINUTES_PER_HOUR
	item.distance_km = randi_range(_cfg().board_distance_min_km, _cfg().board_distance_max_km)
	item.completion_hours = _completion_hours(contract)
	item.issuer = "%s Issuer" % contract.contract_type if contract != null else "Issuer"
	item.issuer_type = _issuer_type(contract)
	item.merc_min = _cfg().board_merc_min
	item.image = ""
	item.status = BoardEntry.STATUS_DRAFT
	item.closed_minute = -1
	if contract != null:
		contract.status = "Draft"
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


#Sends a team: the run is built as ContractManager.run builds it, then the scheduler departs.
func activate(id: int, team: Array[MercenaryData], travel_minutes: int, now: int,
		line_fn: Callable) -> ContractScheduler:
	var target: BoardEntry = entry(id)
	if target == null or not target.is_open() or team.is_empty():
		return null
	var run := ContractRun.new()
	run.contract = target.contract
	run.team.assign(team)
	run.line_fn = line_fn
	if target.contract != null and target.contract.location_a != "":
		run.location = DataManager.locations.get(target.contract.location_a, null) as LocationData
	target.log_lines.clear()
	target.verdict = ""
	target.status = BoardEntry.STATUS_ACTIVE
	target.closed_minute = -1
	target.scheduler = ContractScheduler.create(run, travel_minutes, now)
	return target.scheduler


#Closes a finished run; an all-dead failure returns to the board while its deadline holds (G12).
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
	var returns: bool = scheduler.all_dead and run.verdict == BoardEntry.STATUS_FAILED \
		and now < entry_done.expires_minute and available().size() < _cfg().board_target
	if returns:
		entry_done.status = BoardEntry.STATUS_DRAFT
		entry_done.closed_minute = -1
		if entry_done.contract != null:
			entry_done.contract.team_uids.clear()
			entry_done.contract.status = "Draft"
		return entry_done.verdict
	entry_done.status = entry_done.verdict
	entry_done.closed_minute = now
	return entry_done.verdict


#Event hours plus the six-hour gaps between them (Q29 placeholder).
func _completion_hours(contract: ContractData) -> int:
	if contract == null:
		return 0
	var events: int = contract.rolled_mishaps.size()
	if contract.assigned_primary_event != "":
		events += 1
	if events <= 0:
		return 0
	return events + (events - 1) * _cfg().board_gap_hours


#A stable 1..4 per contract type until the issuer table exists (Q29 placeholder).
func _issuer_type(contract: ContractData) -> int:
	if contract == null or contract.contract_type == "":
		return 1
	return absi(hash(contract.contract_type)) % _cfg().board_issuer_types + 1
