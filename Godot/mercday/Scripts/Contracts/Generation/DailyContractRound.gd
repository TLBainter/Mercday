class_name DailyContractRound
#The 8:00 round: generate into the pool, sweep it, then provision the roster in priority order (proposal 3.2, 5.4).


static func context(_board: ContractBoard, now: int) -> Dictionary:
	var living: Array[MercenaryData] = []
	var available: Array[MercenaryData] = []
	var resting: Array[MercenaryData] = []
	for merc: MercenaryData in GameState.mercs:
		var status: int = int(GameState.merc_status(merc)["status"])
		if status != GuiTypes.MercStatus.DEAD:
			living.append(merc)
		if status == GuiTypes.MercStatus.AVAILABLE:
			available.append(merc)
		elif status == GuiTypes.MercStatus.RESTING:
			resting.append(merc)
	var rows_by_type: Dictionary = {}
	for type_name: String in ContractLibrary.contract_type_names():
		rows_by_type[type_name] = ContractLibrary.contracts_for_type(type_name)
	var rates: Dictionary = GenRecord.rates(GuildRecord.guild, now)
	return {"roster_max": SubscriptionManager.max_contracts(), "living": living, "available": available,
		"resting": resting, "level_centre": GenLevel.centre(living, available, resting),
		"diff_centre": GenDifficulty.centre(float(rates["blended"])), "bank": GameState.bank_notes,
		"campaigns": PromotionsManager.contract_campaigns(), "rates": rates, "rows_by_type": rows_by_type,
		"places": GenLocation.places(LegalManager.ops_held_at, LegalManager.tele_held_at),
		"tele_fn": GameState.tele_permit_for}


static func run(board: ContractBoard, now: int, rng: RandomNumberGenerator) -> Dictionary:
	return run_with(context(board, now), board, now, rng)


static func run_with(ctx: Dictionary, board: ContractBoard, now: int, rng: RandomNumberGenerator) -> Dictionary:
	var room: int = GenRoom.room(board, int(ctx["roster_max"]))
	var out: Dictionary = {"room": room, "generated": 0, "promo": 0, "provisioned": 0, "expired": 0}
	var story: Array[BoardEntry] = GenStory.due(now)
	if room <= 0 and story.is_empty():
		out["stop"] = "no room"
		return out
	for entry: BoardEntry in story:
		board.pool.add(entry, now)
	var jobs: Array[Dictionary] = []
	for i: int in GenLikelihood.count(float(ctx["rates"]["blended"]), rng):
		jobs.append({})
	for campaign: Dictionary in ctx["campaigns"]:
		for hit: Dictionary in GenPromo.hits(campaign, rng):
			jobs.append({"hit": hit, "campaign": campaign})
	for job: Dictionary in jobs:
		var excluded: Array[int] = GenProvision.busy_issuers(board)
		excluded.append_array(board.pool.issuer_ids())
		var campaign: Dictionary = job.get("campaign", {})
		var applied: Array[String] = []
		if not campaign.is_empty():
			applied = GenPick.criteria(job["hit"], campaign, ctx, excluded)
			if not (job["hit"]["criteria"] as Array).is_empty() and applied.is_empty():
				continue
		var only: Array[int] = []
		if applied.has("issuers"):
			only.assign(campaign["issuers"])
		var issuer: int = GenIssuer.pick(excluded, now, rng, only)
		if issuer < 0 and only.is_empty():
			break
		if issuer < 0:
			continue
		var entry: BoardEntry = GenPosting.generate_one(ctx, board, now, rng, issuer, applied, campaign)
		if entry == null:
			continue
		board.pool.add(entry, now)
		out["generated"] += 1
		if not campaign.is_empty():
			out["promo"] += 1
			PromotionsManager.credit_contract(int(campaign["id"]))
	out["expired"] = board.pool.sweep(now, int(ctx["bank"]), ctx["tele_fn"]).size()
	out["provisioned"] = GenProvision.provision(ctx, board, now, room)
	return out
