class_name SimPolicy
#The playability sim's 8:00 decisions: dispatch by optimize odds, hire the cheapest ask, buy tiers, step the plan up.


static func act(c: Dictionary) -> void:
	dispatch_all(c)
	if GameState.bank_notes < 0:
		return
	_hire(c)
	_tiers(c)
	_plan(c)


#Roster mercs free to go: not busy and shown Available, as the Dispatch window lists them.
static func candidates(roster: Array[MercView], busy: Array[int]) -> Array[MercView]:
	var out: Array[MercView] = []
	for view: MercView in roster:
		if view != null and view.merc != null and not busy.has(view.uid) \
				and view.status == GuiTypes.MercStatus.AVAILABLE:
			out.append(view)
	return out


#The optimize_plan request DispatchWindow.optimize_request builds for this posting and candidate pool.
static func request_for(view: ContractView, pool: Array[MercView], keys: Array[String], bank: int,
		open: Array[ContractData]) -> Dictionary:
	var slots: int = clampi(view.merc_max, 1, DispatchWindow.SLOT_COUNT)
	var uids: Array[int] = []
	var by_uid: Dictionary = {}
	for merc_view: MercView in pool:
		uids.append(merc_view.uid)
		by_uid[merc_view.uid] = merc_view
	var contract: ContractData = view.contract
	var model: OddsModel = OddsEstimator.prepare(contract, GameState.mercs)
	return {
		"uids": uids,
		"lo": mini(view.merc_min, slots),
		"cap": slots,
		"seed": view.entry_id,
		"chance_fn": func(members: Array[int], leader_uid: int) -> float:
			return OddsEstimator.chance(model, members, leader_uid),
		"mode_fn": func(members: Array[int]) -> Dictionary:
			return _outbound_for(view, maxi(1, members.size()), keys, bank),
		"features_fn": func(uid: int) -> int:
			return MatchScore.feature_count((by_uid[uid] as MercView).merc, open) if by_uid.has(uid) else 0,
		"solo_fn": func(uid: int) -> float:
			return MatchScore.solo_net(contract, (by_uid[uid] as MercView).merc) if by_uid.has(uid) else 0.0,
		"name_fn": func(uid: int) -> String:
			return (by_uid[uid] as MercView).name if by_uid.has(uid) else "",
		"model": model,
	}


static func _outbound_for(view: ContractView, size: int, keys: Array[String], bank: int) -> Dictionary:
	var trip: Dictionary = DispatchLogic.plan_travel(GuiTypes.TRAVEL_MODES, bank, size, view.merc_min,
		view.distance_km, keys, [])
	var venture: Dictionary = trip.get("venture", {})
	if venture.is_empty():
		return {}
	return {"mode": str(venture.get("key", "")),
		"cost": DispatchLogic.travel_cost(venture, size, view.merc_min, view.distance_km)}


#Dispatches the best eligible posting, re-optimizes the rest with the smaller pool, until none qualifies.
static func dispatch_all(c: Dictionary) -> void:
	var skipped: Dictionary = {}
	while true:
		var best: Dictionary = _best_choice(c, skipped)
		if best.is_empty():
			return
		var run: ActiveRun = best["run"]
		if GameState.dispatch(run.entry_id, run):
			c["dispatched"] = int(c["dispatched"]) + 1
			SimCounters.sample_bank(c)
		else:
			tally(c, "dispatch_failed")
		skipped[run.entry_id] = true


static func _best_choice(c: Dictionary, skipped: Dictionary) -> Dictionary:
	var now: int = CampaignClock.now()
	var bank: int = GameState.bank_notes
	var pool: Array[MercView] = candidates(GameState.roster, GameState.busy_uids())
	var open: Array[ContractData] = []
	for entry: BoardEntry in GameState.board.available():
		if entry != null and entry.contract != null:
			open.append(entry.contract)
	var best: Dictionary = {}
	if pool.is_empty():
		tally(c, "no_pool")
		return best
	for entry: BoardEntry in SimCounters.open_postings(GameState.board):
		if skipped.has(entry.id) or entry.contract == null:
			continue
		var choice: Dictionary = _choice_for(c, entry, pool, open, now, bank)
		if not choice.is_empty() and (best.is_empty() or float(choice["p"]) > float(best["p"])):
			best = choice
	return best


#The run one posting would get, or {} when its odds, mode or fares rule it out; c counts the reason.
static func _choice_for(c: Dictionary, entry: BoardEntry, pool: Array[MercView], open: Array[ContractData], now: int,
		bank: int) -> Dictionary:
	tally(c, "evaluated")
	var view: ContractView = _view_for(entry, now)
	var tele: bool = GameState.tele_permit_for(entry)
	var keys: Array[String] = Reachability.modes_in_time(entry, now, bank, tele)
	var request: Dictionary = request_for(view, pool, keys, bank, open)
	var plan: Dictionary = DispatchLogic.optimize_plan(request)
	var team: Array[int] = plan.get("team", [] as Array[int])
	var p: float = float(plan.get("p", 0.0))
	c["p_max"] = maxf(float(c["p_max"]), p)
	if team.is_empty() or str(plan.get("mode", "")) == "":
		tally(c, "no_team")
		return {}
	if p < SimThresholds.DISPATCH_P:
		tally(c, "low_p")
		return {}
	var size: int = team.size()
	var trip: Dictionary = DispatchLogic.plan_travel(GuiTypes.TRAVEL_MODES, bank, size, view.merc_min,
		view.distance_km, keys, Reachability.offered_modes(entry, bank, tele))
	var venture: Dictionary = GuiTypes.travel_mode(str(plan["mode"]))
	var ret: Dictionary = trip.get("ret", {})
	if ret.is_empty():
		ret = GuiTypes.travel_mode(Reachability.FOOT)
	var out_cost: int = ContractPreview.leg_cost(view, venture, size)
	var back_cost: int = ContractPreview.leg_cost(view, ret, size)
	if not Reachability.fare_ok(str(venture.get("key", "")), out_cost, bank) \
			or not Reachability.fare_ok(str(ret.get("key", "")), back_cost, bank - out_cost):
		tally(c, "no_fare")
		return {}
	var run: ActiveRun = ActiveRun.new()
	run.entry_id = view.entry_id
	run.reward = view.reward
	run.travel_cost = out_cost + back_cost
	run.odds = OddsEstimator.odds(request["model"] as OddsModel, team, team[0])
	run.travel_mode = str(venture.get("key", Reachability.FOOT))
	run.return_mode = str(ret.get("key", Reachability.FOOT))
	run.hours = roundf(float(ContractPreview.preview(view, venture, ret, size).get("total_hours", 0.0)))
	run.team = _members(view.contract, team, pool)
	return {"p": p, "run": run}


static func tally(c: Dictionary, key: String) -> void:
	c[key] = int(c[key]) + 1


static func _view_for(entry: BoardEntry, now: int) -> ContractView:
	for view: ContractView in GameState.contracts:
		if view.entry_id == entry.id:
			return view
	return ContractView.from_entry(entry, now)


#TeamMember rows in team order, slot 0 the leader, each with its stars inside this team.
static func _members(contract: ContractData, team: Array[int], pool: Array[MercView]) -> Array[TeamMember]:
	var mercs: Array[MercenaryData] = []
	for uid: int in team:
		for view: MercView in pool:
			if view.uid == uid:
				mercs.append(view.merc)
	var leader: MercenaryData = mercs[0] if not mercs.is_empty() else null
	var out: Array[TeamMember] = []
	for i: int in mercs.size():
		var member: TeamMember = TeamMember.new()
		member.merc_uid = mercs[i].merc_uid
		member.role = ContractResultData.ROLE_LEADER if i == 0 else DispatchWindow.SUPPORT_ROLE
		member.match = MatchScore.stars(MatchScore.merc_net(contract, mercs, mercs[i], leader))
		out.append(member)
	return out


#The lowest open ask, hired when the bank holds HIRE_BANK_FACTOR times it and a seat is free.
static func _hire(c: Dictionary) -> void:
	if GameState.is_in_red() or PromotionsManager.free_slots() <= 0:
		return
	var pick: ApplicantData = null
	for applicant: ApplicantData in PromotionsManager.applicants:
		if not applicant.is_open():
			continue
		if pick == null or applicant.ask < pick.ask or (applicant.ask == pick.ask and applicant.id < pick.id):
			pick = applicant
	if pick == null or GameState.bank_notes < SimThresholds.HIRE_BANK_FACTOR * pick.ask:
		return
	if PromotionsManager.hire(pick.id, pick.ask):
		c["hired"] = int(c["hired"]) + 1
		SimCounters.sample_bank(c)


static func _tiers(c: Dictionary) -> void:
	for id: String in SimThresholds.TIER_IDS:
		if not SubscriptionManager.can_raise(id):
			continue
		var price: int = SubscriptionManager.tier_price(id, SubscriptionManager.tier_of(id) + 1)
		if GameState.bank_notes >= SimThresholds.TIER_BANK_FACTOR * price and SubscriptionManager.buy_tier(id):
			c["tiers"] = int(c["tiers"]) + 1
			SimCounters.sample_bank(c)


#Assumption A1: step up one plan when the bank holds PLAN_BANK_FACTOR times the fee rise.
static func _plan(c: Dictionary) -> void:
	var current: int = SubscriptionManager.plan()
	var next: int = current + 1
	if next > SubscriptionManager.Plan.ENTERPRISE or not SubscriptionManager.can_switch(next):
		return
	var rise: int = SubscriptionManager.service_fee(next) - SubscriptionManager.service_fee(current)
	if GameState.bank_notes >= SimThresholds.PLAN_BANK_FACTOR * rise and SubscriptionManager.switch_plan(next):
		c["switches"] = int(c["switches"]) + 1
		SimCounters.sample_bank(c)
