class_name DispatchLogic

#Travel planning and the dispatch optimizer. The optimizer scores whole teams through caller supplied
#callables: the chance for a team and leader, the outbound mode it can take, and the tie-break inputs.

const LEADER_ROLE := ContractResultData.ROLE_LEADER
const SUPPORT_ROLE := "Support"
#Above this many subsets the optimizer climbs instead of enumerating.
const MAX_SUBSETS := 20000
const MAX_ROUNDS := 200
const TIME_BUDGET_MS := 800
const SEARCH_STARTS := 8
#Two chances closer than this are equal for the objective.
const P_EPSILON := 0.000000001
#Odds points a PENDING vacation over the trip costs a team at Optimize (Q66); chance_fn runs 0..1, so 20 is 0.20.
const VACATION_PENALTY := 20


#One leg of travel in minutes, read from the same table the campaign clock travels on.
static func leg_minutes(mode: Dictionary, distance_km: int) -> int:
	if mode.is_empty():
		return 0
	return GameState.travel_minutes(str(mode.get("key", "")), distance_km)


#Fare in notes; foot bills a note per billed merc per travel day and at least one day, the rest per km leg and at
#least one leg.
static func travel_cost(mode: Dictionary, team_size: int, merc_min: int, distance_km: int) -> int:
	var billed: int = maxi(team_size, merc_min)
	if str(mode.get("key", "")) == "foot":
		var days: float = float(leg_minutes(mode, distance_km)) / float(CampaignClock.MINUTES_PER_DAY)
		return maxi(1, ceili(days)) * billed
	var per_km: int = int(mode.get("per_km", 0))
	if per_km <= 0:
		return 0
	if distance_km <= 0:
		return 0
	var count: int = billed if bool(mode.get("per_merc", false)) else 1
	var legs: int = maxi(1, int(distance_km / float(per_km)))
	return legs * int(mode.get("rate", 0)) * count


#One leg of travel in hours; a mode with no speed arrives at once.
static func travel_hours(mode: Dictionary, distance_km: int) -> float:
	return float(leg_minutes(mode, distance_km)) / 60.0


#The cheapest venture among out_keys the bank can pay, then the cheapest return among ret_keys from what is left.
#Ties go to the faster mode, then table order; a side stays empty when nothing fits.
static func plan_travel(modes: Array, bank: int, team_size: int, merc_min: int, distance_km: int,
		out_keys: Array, ret_keys: Array) -> Dictionary:
	var plan: Dictionary = {"venture": {}, "ret": {}}
	var venture: int = _cheapest(modes, bank, team_size, merc_min, distance_km, out_keys)
	if venture < 0:
		return plan
	var mode: Dictionary = modes[venture]
	plan["venture"] = mode
	var spare: int = bank - travel_cost(mode, team_size, merc_min, distance_km)
	var ret: int = _cheapest(modes, spare, team_size, merc_min, distance_km, ret_keys)
	if ret >= 0:
		plan["ret"] = modes[ret]
	return plan


#The best team of lo to cap mercs: highest chance, then fewest mercs, lowest feature sum, lowest cost and
#lowest uid list. Request keys: uids, lo, cap, seed, chance_fn(team, leader_uid) -> float,
#mode_fn(team) -> {mode, cost} or {}, features_fn(uid) -> int, solo_fn(uid) -> float, name_fn(uid) -> String.
#Returns {team (leader first), leader_uid, mode, p, cost}; the team is empty when no team is valid.
static func optimize_plan(request: Dictionary) -> Dictionary:
	var empty_team: Array[int] = []
	var none: Dictionary = {"team": empty_team, "leader_uid": -1, "mode": "", "p": 0.0, "cost": 0}
	var uids: Array[int] = []
	for uid: Variant in (request.get("uids", []) as Array):
		if not uids.has(int(uid)):
			uids.append(int(uid))
	uids.sort()
	var chance_fn: Callable = request.get("chance_fn", Callable()) as Callable
	var mode_fn: Callable = request.get("mode_fn", Callable()) as Callable
	if uids.is_empty() or not chance_fn.is_valid() or not mode_fn.is_valid():
		return none
	var cap: int = mini(int(request.get("cap", uids.size())), uids.size())
	if cap < 1:
		return none
	var lo: int = clampi(int(request.get("lo", 1)), 1, cap)
	var state: Dictionary = {
		"request": request,
		"best": {},
		"seen": {},
		"per_uid": {},
		"rounds": 0,
		"deadline": Time.get_ticks_msec() + TIME_BUDGET_MS,
	}
	if _subset_count(uids.size(), lo, cap) <= MAX_SUBSETS:
		_walk(uids, lo, cap, state)
	else:
		_search(uids, lo, cap, int(request.get("seed", 0)), state)
	var best: Dictionary = state["best"]
	if best.is_empty():
		return none
	var members: Array[int] = best["team"]
	var team: Array[int] = [int(best["leader"])]
	for uid: int in members:
		if uid != int(best["leader"]):
			team.append(uid)
	return {"team": team, "leader_uid": int(best["leader"]), "mode": String(best["mode"]),
		"p": float(best["p"]), "cost": int(best["cost"])}


#The first and last day of a dispatch pressed at now: it leaves now, or at the 6:00 wake when pressed at night.
static func trip_days(now: int, total_hours: float) -> Vector2i:
	var depart: int = ContractScheduler.next_wake_minute(now) if ContractScheduler.is_night_minute(now) else now
	return Vector2i(TrynnCalendar.day_index(depart), TrynnCalendar.day_index(depart + roundi(total_hours * 60.0)))


#Optimize's vacation screen: an APPROVED or TAKEN row over the trip leaves the merc out of pool; a PENDING one keeps
#the merc in pool and lists its uid in pending. Returns {pool: Array[MercView], pending: Array[int]}.
static func vacation_screen(candidates: Array[MercView], book: VacationBook, from_day: int, to_day: int) -> Dictionary:
	var pool: Array[MercView] = []
	var pending: Array[int] = []
	var rows: Array[VacationRequest] = book.spans(from_day, to_day) if book != null else [] as Array[VacationRequest]
	for view: MercView in candidates:
		var booked: bool = false
		var asked: bool = false
		for req: VacationRequest in rows:
			if view != null and req.merc_uid == view.uid:
				asked = asked or req.state == VacationRequest.State.PENDING
				booked = booked or req.state != VacationRequest.State.PENDING
		if view == null or booked:
			continue
		pool.append(view)
		if asked:
			pending.append(view.uid)
	return {"pool": pool, "pending": pending}


#chance_fn less VACATION_PENALTY points per pending merc in the team, unclamped, as a chance_fn of the same shape.
static func vacation_odds(chance_fn: Callable, pending: Array[int]) -> Callable:
	return func(members: Array[int], leader_uid: int) -> float:
		var hits: int = 0
		for uid: int in members:
			if pending.has(uid):
				hits += 1
		return float(chance_fn.call(members, leader_uid)) - VACATION_PENALTY / 100.0 * hits


static func _spent(state: Dictionary) -> bool:
	return Time.get_ticks_msec() >= int(state["deadline"]) or int(state["rounds"]) >= MAX_ROUNDS


#Every subset of each size from lo to cap in uid order; one size is one round.
static func _walk(uids: Array[int], lo: int, cap: int, state: Dictionary) -> void:
	for size: int in range(lo, cap + 1):
		var picks: Array[int] = []
		for i: int in size:
			picks.append(i)
		while true:
			var team: Array[int] = []
			for i: int in picks:
				team.append(uids[i])
			_consider(team, state)
			if Time.get_ticks_msec() >= int(state["deadline"]):
				return
			var at: int = size - 1
			while at >= 0 and picks[at] == uids.size() - size + at:
				at -= 1
			if at < 0:
				break
			picks[at] += 1
			for i: int in range(at + 1, size):
				picks[i] = picks[i - 1] + 1
		state["rounds"] = int(state["rounds"]) + 1
		if _spent(state):
			return


#Best-improvement local search over swap, add and drop moves from seeded random starts.
static func _search(uids: Array[int], lo: int, cap: int, seed: int, state: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for _start: int in SEARCH_STARTS:
		var pool: Array[int] = uids.duplicate()
		for i: int in range(pool.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var held: int = pool[i]
			pool[i] = pool[j]
			pool[j] = held
		var team: Array[int] = pool.slice(0, rng.randi_range(lo, cap))
		var current: Dictionary = _consider(team, state)
		while not _spent(state):
			state["rounds"] = int(state["rounds"]) + 1
			var step: Dictionary = {}
			for move: Array[int] in _neighbours(team, uids, lo, cap):
				var found: Dictionary = _consider(move, state)
				if not found.is_empty() and (step.is_empty() or _better(found, step)):
					step = found
				if Time.get_ticks_msec() >= int(state["deadline"]):
					return
			if step.is_empty() or (not current.is_empty() and not _better(step, current)):
				break
			current = step
			var stepped: Array[int] = step["team"]
			team = stepped.duplicate()
		if Time.get_ticks_msec() >= int(state["deadline"]):
			return


static func _neighbours(team: Array[int], uids: Array[int], lo: int, cap: int) -> Array:
	var out: Array = []
	for i: int in team.size():
		for uid: int in uids:
			if team.has(uid):
				continue
			var swapped: Array[int] = team.duplicate()
			swapped[i] = uid
			out.append(swapped)
		if team.size() > lo:
			var dropped: Array[int] = team.duplicate()
			dropped.remove_at(i)
			out.append(dropped)
	if team.size() < cap:
		for uid: int in uids:
			if team.has(uid):
				continue
			var grown: Array[int] = team.duplicate()
			grown.append(uid)
			out.append(grown)
	return out


#The scored candidate for this team, or {} when it has no valid mode; the best one is kept in state.
static func _consider(members: Array[int], state: Dictionary) -> Dictionary:
	var team: Array[int] = members.duplicate()
	team.sort()
	var key: String = str(team)
	var seen: Dictionary = state["seen"]
	if seen.has(key):
		return seen[key]
	var request: Dictionary = state["request"]
	var found: Dictionary = {}
	var mode: Dictionary = (request["mode_fn"] as Callable).call(team.duplicate())
	if not mode.is_empty():
		var chance_fn: Callable = request["chance_fn"]
		var leader: int = -1
		var best_p: float = 0.0
		var features: int = 0
		for uid: int in team:
			var p: float = float(chance_fn.call(team.duplicate(), uid))
			if leader < 0 or p > best_p + P_EPSILON or (absf(p - best_p) <= P_EPSILON and _leads(uid, leader, state)):
				leader = uid
				best_p = p
			features += int(_uid_info(uid, state)["features"])
		found = {"team": team, "leader": leader, "p": best_p, "features": features,
			"mode": String(mode.get("mode", "")), "cost": int(mode.get("cost", 0))}
		var best: Dictionary = state["best"]
		if best.is_empty() or _better(found, best):
			state["best"] = found
	seen[key] = found
	return found


#True when a ranks above b by the objective.
static func _better(a: Dictionary, b: Dictionary) -> bool:
	var pa: float = float(a["p"])
	var pb: float = float(b["p"])
	if absf(pa - pb) > P_EPSILON:
		return pa > pb
	var ta: Array[int] = a["team"]
	var tb: Array[int] = b["team"]
	if ta.size() != tb.size():
		return ta.size() < tb.size()
	if int(a["features"]) != int(b["features"]):
		return int(a["features"]) < int(b["features"])
	if int(a["cost"]) != int(b["cost"]):
		return int(a["cost"]) < int(b["cost"])
	for i: int in ta.size():
		if ta[i] != tb[i]:
			return ta[i] < tb[i]
	return false


#Leader tie-break: the higher solo net, then the earlier name, then the lower uid.
static func _leads(a: int, b: int, state: Dictionary) -> bool:
	var ia: Dictionary = _uid_info(a, state)
	var ib: Dictionary = _uid_info(b, state)
	if not is_equal_approx(float(ia["solo"]), float(ib["solo"])):
		return float(ia["solo"]) > float(ib["solo"])
	if String(ia["name"]) != String(ib["name"]):
		return String(ia["name"]) < String(ib["name"])
	return a < b


static func _uid_info(uid: int, state: Dictionary) -> Dictionary:
	var per_uid: Dictionary = state["per_uid"]
	if per_uid.has(uid):
		return per_uid[uid]
	var request: Dictionary = state["request"]
	var features_fn: Callable = request.get("features_fn", Callable()) as Callable
	var solo_fn: Callable = request.get("solo_fn", Callable()) as Callable
	var name_fn: Callable = request.get("name_fn", Callable()) as Callable
	var info: Dictionary = {
		"features": int(features_fn.call(uid)) if features_fn.is_valid() else 0,
		"solo": float(solo_fn.call(uid)) if solo_fn.is_valid() else 0.0,
		"name": String(name_fn.call(uid)) if name_fn.is_valid() else "",
	}
	per_uid[uid] = info
	return info


#The index of the cheapest mode named in keys whose fare passes against bank, or -1.
static func _cheapest(modes: Array, bank: int, team_size: int, merc_min: int, distance_km: int,
		keys: Array) -> int:
	var best: int = -1
	var best_cost: int = 0
	var best_minutes: int = 0
	for i: int in modes.size():
		var mode: Dictionary = modes[i]
		var key: String = str(mode.get("key", ""))
		if not keys.has(key):
			continue
		var cost: int = travel_cost(mode, team_size, merc_min, distance_km)
		if not Reachability.fare_ok(key, cost, bank):
			continue
		var minutes: int = leg_minutes(mode, distance_km)
		if best < 0 or cost < best_cost or (cost == best_cost and minutes < best_minutes):
			best = i
			best_cost = cost
			best_minutes = minutes
	return best


#Subsets of size lo..cap, stopped once the count passes the enumeration limit.
static func _subset_count(total: int, lo: int, cap: int) -> int:
	var sum: int = 0
	var choose: int = 1
	for size: int in range(1, cap + 1):
		choose = int(float(choose * (total - size + 1)) / float(size))
		if size >= lo:
			sum += choose
		if sum > MAX_SUBSETS:
			return MAX_SUBSETS + 1
	return sum
