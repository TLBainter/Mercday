class_name SimCounters
#Playability sim counts: board and pool snapshots after each policy pass, diffed at the next 8:00 round.


static func new_state(first_day: int) -> Dictionary:
	return {"first_day": first_day, "seen": {}, "pool": {}, "board": {}, "next_id": 0,
		"generated": 0, "provisioned": 0, "pool_expired": 0, "auto_rejected": 0, "rejected": 0, "posted": 0,
		"succeeded": 0, "failed": 0, "deaths": 0, "dead_last": 0, "wins_base": 0, "losses_base": 0,
		"dispatched": 0, "hired": 0, "tiers": 0, "switches": 0, "evaluated": 0, "no_pool": 0, "low_p": 0, "no_team": 0,
		"no_fare": 0, "dispatch_failed": 0, "p_max": 0.0, "gen_by_day": {}, "bank": [], "roster_open": [], "mercs": [],
		"levels": [], "values": [], "qualities": [], "kms": [], "weeks": []}


#Keys are instance ids: a pooled entry has id 0 until the board posts it, and posting keeps the same object.
static func snapshot(c: Dictionary, pool: Array[BoardEntry], board: Array[BoardEntry], next_id: int) -> void:
	var pool_map: Dictionary = {}
	for entry: BoardEntry in pool:
		var key: int = entry.get_instance_id()
		pool_map[key] = int((c["pool"] as Dictionary).get(key, entry.expires_minute))
		c["seen"][key] = true
	var board_map: Dictionary = {}
	for entry: BoardEntry in board:
		var key: int = entry.get_instance_id()
		var first: int = entry.expires_minute
		if (c["board"] as Dictionary).has(key):
			first = int(c["board"][key]["expires"])
		board_map[key] = {"id": entry.id, "status": entry.status, "expires": first}
		c["seen"][key] = true
	c["pool"] = pool_map
	c["board"] = board_map
	c["next_id"] = next_id


#What changed since the last snapshot: {generated: Array[BoardEntry], provisioned, pool_expired, auto_rejected}.
static func diff(c: Dictionary, pool: Array[BoardEntry], board: Array[BoardEntry]) -> Dictionary:
	var generated: Array[BoardEntry] = []
	var out: Dictionary = {"generated": generated, "provisioned": 0, "pool_expired": 0, "auto_rejected": 0}
	var seen: Dictionary = c["seen"]
	var old_pool: Dictionary = c["pool"]
	var old_board: Dictionary = c["board"]
	var now_pool: Dictionary = {}
	var now_board: Dictionary = {}
	for entry: BoardEntry in pool:
		now_pool[entry.get_instance_id()] = entry
		if not seen.has(entry.get_instance_id()):
			generated.append(entry)
	for entry: BoardEntry in board:
		var key: int = entry.get_instance_id()
		now_board[key] = entry
		if not seen.has(key):
			generated.append(entry)
		if not old_board.has(key):
			out["provisioned"] = int(out["provisioned"]) + 1
	for key: int in old_pool:
		if not now_pool.has(key) and not now_board.has(key):
			out["pool_expired"] = int(out["pool_expired"]) + 1
	for key: int in old_board:
		var row: Dictionary = old_board[key]
		if str(row["status"]) != BoardEntry.STATUS_DRAFT or not now_board.has(key):
			continue
		var entry: BoardEntry = now_board[key]
		if entry.status == BoardEntry.STATUS_EXPIRED and entry.expires_minute < int(row["expires"]):
			out["auto_rejected"] = int(out["auto_rejected"]) + 1
	return out


#Folds one diff into the totals; centre is the roster level centre the round used for these entries.
static func add_round(c: Dictionary, change: Dictionary, day_index: int, centre: float) -> void:
	var generated: Array[BoardEntry] = change["generated"]
	for key: String in ["provisioned", "pool_expired", "auto_rejected"]:
		c[key] = int(c[key]) + int(change[key])
	c["generated"] = int(c["generated"]) + generated.size()
	c["gen_by_day"][day_index] = int((c["gen_by_day"] as Dictionary).get(day_index, 0)) + generated.size()
	for entry: BoardEntry in generated:
		(c["values"] as Array).append(entry.value)
		(c["levels"] as Array).append(centre)
		(c["qualities"] as Array).append(entry.quality)
		(c["kms"] as Array).append(entry.distance_km)
		c["seen"][entry.get_instance_id()] = true


#The 8:00 pass after the round: board diff, results, deaths, roster open, living mercs and the bank.
static func after_round(c: Dictionary) -> void:
	var board: ContractBoard = GameState.board
	var now: int = CampaignClock.now()
	var centre: float = float(DailyContractRound.context(board, now)["level_centre"])
	add_round(c, diff(c, board.pool.entries, board.entries), TrynnCalendar.day_index(now), centre)
	c["succeeded"] = GuildRecord.guild.successes - int(c["wins_base"])
	c["failed"] = GuildRecord.guild.failures - int(c["losses_base"])
	var dead: int = int(GameState.get("_dead_counted"))
	if dead > int(c["dead_last"]):
		c["deaths"] = int(c["deaths"]) + dead - int(c["dead_last"])
	c["dead_last"] = dead
	(c["roster_open"] as Array).append(open_postings(board).size())
	(c["mercs"] as Array).append(living_mercs().size())
	sample_bank(c)


static func end_of_day(c: Dictionary) -> void:
	var board: ContractBoard = GameState.board
	snapshot(c, board.pool.entries, board.entries, board.next_id)


static func sample_bank(c: Dictionary) -> void:
	(c["bank"] as Array).append(GameState.bank_notes)


static func open_postings(board: ContractBoard) -> Array[BoardEntry]:
	var out: Array[BoardEntry] = []
	if board == null:
		return out
	for entry: BoardEntry in board.entries:
		if entry.status == BoardEntry.STATUS_DRAFT and entry.is_open():
			out.append(entry)
	return out


static func living_mercs() -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	for merc: MercenaryData in GameState.mercs:
		if merc != null and not merc.is_dead:
			out.append(merc)
	return out


static func mean_level() -> float:
	var living: Array[MercenaryData] = living_mercs()
	if living.is_empty():
		return 0.0
	var total: int = 0
	for merc: MercenaryData in living:
		total += ExperienceSystem.current_level(merc)
	return float(total) / float(living.size())


#Generated count of one calendar week (day indexes key * 10 to key * 10 + 9).
static func week_generated(c: Dictionary, week_key: int) -> int:
	var days: int = TrynnCalendar.WEEKDAYS.size()
	var total: int = 0
	for day: int in range(week_key * days, (week_key + 1) * days):
		total += int((c["gen_by_day"] as Dictionary).get(day, 0))
	return total
