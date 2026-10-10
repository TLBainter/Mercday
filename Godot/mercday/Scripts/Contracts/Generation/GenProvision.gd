class_name GenProvision
#Moves pooled entries onto the roster in priority order, one per issuer, up to the room (proposal 5.15, 5.16).


#Posted count; skips an issuer with an open posting and a reject pooled at now; a story entry gets a fresh deadline.
static func provision(ctx: Dictionary, board: ContractBoard, now: int, room: int) -> int:
	var centre: float = float(ctx["level_centre"])
	var niches: Dictionary = {}
	for campaign: Dictionary in ctx["campaigns"]:
		niches[int(campaign["id"])] = GenPriority.niche(campaign)
	var slack_fn: Callable = func(e: BoardEntry) -> int:
		return e.deadline_minute - now - GenPosting.expected_minutes(e, centre)
	var niche_fn: Callable = func(e: BoardEntry) -> float: return float(niches.get(e.campaign_id, 0.0))
	var busy: Array[int] = busy_issuers(board)
	var posted: int = 0
	for entry: BoardEntry in GenPriority.sort(board.pool.entries.duplicate(), now, slack_fn, niche_fn):
		if posted >= room:
			break
		if (entry.issuer_id >= 0 and busy.has(entry.issuer_id)) or (entry.reject_count > 0 and entry.pooled_minute == now):
			continue
		if entry.story:
			entry.deadline_minute = GenPosting.fresh_deadline(entry, now, centre)
		board.post_pooled(entry, now)
		busy.append(entry.issuer_id)
		posted += 1
	return posted


#Issuer seats with an open roster posting.
static func busy_issuers(board: ContractBoard) -> Array[int]:
	var out: Array[int] = []
	for entry: BoardEntry in board.available():
		out.append(entry.issuer_id)
	return out
