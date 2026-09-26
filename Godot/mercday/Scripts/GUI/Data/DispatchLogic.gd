class_name DispatchLogic

#Match rating, top traits, travel planning and the dispatch optimizer, ported from
#dispatch_scoring.js. The recommendation lists come from the contract instead of the prototype's
#seeded tables, the role rotation uses GuiTypes.ROLES with Leader unrotated, and the optimizer
#scores whole teams through a caller supplied odds function instead of the prototype's formula.

const LEADER_ROLE := "Leader"
const SUPPORT_ROLE := "Support"
const KNOWLEDGE_WEIGHT := 0.40
const TOOL_WEIGHT := 0.35
const TRADITION_WEIGHT := 0.25
#Above this many subsets the optimizer climbs instead of enumerating.
const MAX_SUBSETS := 20000
const MAX_ROUNDS := 200
const TIME_BUDGET_MS := 800


#The 0..1 match rating of one merc in one role; share carries the leader's top traits.
static func score(merc: MercView, contract: ContractView, role: String, share: Dictionary) -> float:
	var recs: Dictionary = _recs_for(contract, role)
	var knowledges: Array[String] = _merged(merc.knowledges, share.get("know", []))
	var tools: Array[String] = _merged(merc.tools, share.get("tools", []))
	return KNOWLEDGE_WEIGHT * _top2(recs["know"], knowledges) \
		+ TOOL_WEIGHT * _top2(recs["tools"], tools) \
		+ TRADITION_WEIGHT * _weight(recs["trads"], merc.tradition)


#A rating as a half star count from 0.5 to 5.0.
static func to_stars(value: float) -> float:
	return maxf(0.5, minf(5.0, round(value * 10.0) / 2.0))


#The merc's two strongest recommended traits for this contract and role.
static func top_traits(merc: MercView, contract: ContractView, role: String) -> Array[Dictionary]:
	var recs: Dictionary = _recs_for(contract, role)
	var found: Array[Dictionary] = []
	for name: String in merc.knowledges:
		found.append({"name": name, "kind": "know", "value": _weight(recs["know"], name),
			"order": found.size()})
	for name: String in merc.tools:
		found.append({"name": name, "kind": "tool", "value": _weight(recs["tools"], name),
			"order": found.size()})
	found.sort_custom(_by_value)
	found.resize(mini(2, found.size()))
	var out: Array[Dictionary] = []
	for entry: Dictionary in found:
		out.append({"name": str(entry["name"]), "kind": str(entry["kind"]),
			"value": float(entry["value"])})
	return out


#The leader's top traits, which every other slot also counts.
static func leader_share(leader: MercView, contract: ContractView) -> Dictionary:
	var know: Array[String] = []
	var tools: Array[String] = []
	for entry: Dictionary in top_traits(leader, contract, "Leader"):
		if str(entry["kind"]) == "know":
			know.append(str(entry["name"]))
		else:
			tools.append(str(entry["name"]))
	return {"know": know, "tools": tools}


#One leg of travel in minutes, read from the same table the campaign clock travels on.
static func leg_minutes(mode: Dictionary, distance_km: int) -> int:
	if mode.is_empty():
		return 0
	return GameState.travel_minutes(str(mode.get("key", "")), distance_km)


#One leg of travel in notes; foot bills a note per billed merc per travel day, the rest bill by km.
static func travel_cost(mode: Dictionary, team_size: int, merc_min: int, distance_km: int) -> int:
	var billed: int = maxi(team_size, merc_min)
	if str(mode.get("key", "")) == "foot":
		var days: float = float(leg_minutes(mode, distance_km)) / float(CampaignClock.MINUTES_PER_DAY)
		return ceili(days) * billed
	var per_km: int = int(mode.get("per_km", 0))
	if per_km <= 0:
		return 0
	var count: int = billed if bool(mode.get("per_merc", false)) else 1
	return int(distance_km / float(per_km)) * int(mode.get("rate", 0)) * count


#One leg of travel in hours; a mode with no speed arrives at once.
static func travel_hours(mode: Dictionary, distance_km: int) -> float:
	return float(leg_minutes(mode, distance_km)) / 60.0


#The fastest venture whose round trip fits a tenth of the reward, else the cheapest affordable pair.
static func plan_travel(modes: Array[Dictionary], bank: int, reward: int, team_size: int,
		merc_min: int, distance_km: int) -> Dictionary:
	var empty: Dictionary = {"venture": {}, "ret": {}}
	if modes.is_empty():
		return empty
	var cap: float = float(reward) * 0.1
	var costs: Array[int] = []
	var hours: Array[float] = []
	for mode: Dictionary in modes:
		costs.append(travel_cost(mode, team_size, merc_min, distance_km))
		hours.append(travel_hours(mode, distance_km))
	var by_time: Array[int] = _order(modes.size(), func(a: int, b: int) -> bool:
		return hours[a] < hours[b] if hours[a] != hours[b] else a < b)
	var by_cost: Array[int] = _order(modes.size(), func(a: int, b: int) -> bool:
		if costs[a] != costs[b]:
			return costs[a] < costs[b]
		return hours[a] < hours[b] if hours[a] != hours[b] else a < b)
	for venture: int in by_time:
		for ret: int in by_cost:
			var total: int = costs[venture] + costs[ret]
			if total <= bank and float(total) <= cap:
				return {"venture": modes[venture], "ret": modes[ret]}
	var best: int = -1
	var best_total: int = 0
	var best_ret: int = -1
	for venture: int in by_time:
		for ret: int in modes.size():
			var total: int = costs[venture] + costs[ret]
			if total <= bank and (best < 0 or total < best_total):
				best = venture
				best_ret = ret
				best_total = total
	if best < 0:
		return empty
	return {"venture": modes[best], "ret": modes[best_ret]}


#The team of min_size to slots mercs with the highest odds; ties go to the smaller team.
static func optimize(candidates: Array[MercView], slots: int, odds_fn: Callable,
		min_size: int = 1) -> Array[int]:
	var uids: Array[int] = []
	for merc: MercView in candidates:
		uids.append(merc.uid)
	if uids.is_empty() or not odds_fn.is_valid() or slots < 1:
		return []
	var cap: int = mini(slots, uids.size())
	var lo: int = clampi(min_size, 1, cap)
	var current: Array[int] = []
	var state: Dictionary = {"odds": -1, "set": current.duplicate()}
	var deadline: int = Time.get_ticks_msec() + TIME_BUDGET_MS
	if _subset_count(uids.size(), lo, cap) <= MAX_SUBSETS:
		_walk(uids, 0, lo, cap, current, odds_fn, deadline, state)
	else:
		_climb(uids, lo, cap, odds_fn, deadline, state)
	var best: Array[int] = state["set"]
	return best


#The leader and the role every other slot carries, picked for the highest summed fit; the leader
#lends their top traits to the rest, so the roles are scored the way the slots show their stars.
static func arrange(team: Array[int], candidates: Array[MercView], contract: ContractView,
		roles: Array[String]) -> Dictionary:
	var views: Array[MercView] = []
	for uid: int in team:
		var view: MercView = _view_in(candidates, uid)
		if view != null:
			views.append(view)
	var best_team: Array[int] = []
	var best_roles: Array[String] = []
	var best_fit: float = 0.0
	var best_lead: float = 0.0
	if views.is_empty() or contract == null:
		return {"team": best_team, "roles": best_roles, "fit": 0.0}
	var pool: Array[String] = roles.duplicate()
	if pool.is_empty():
		pool.append(SUPPORT_ROLE)
	for lead: int in views.size():
		var lead_fit: float = score(views[lead], contract, LEADER_ROLE, {})
		var share: Dictionary = leader_share(views[lead], contract)
		var picked: Array[int] = [views[lead].uid]
		var picked_roles: Array[String] = [LEADER_ROLE]
		var total: float = lead_fit
		for i: int in views.size():
			if i == lead:
				continue
			var role_name: String = pool[0]
			var role_fit: float = score(views[i], contract, pool[0], share)
			for r: int in range(1, pool.size()):
				var value: float = score(views[i], contract, pool[r], share)
				if value > role_fit:
					role_name = pool[r]
					role_fit = value
			picked.append(views[i].uid)
			picked_roles.append(role_name)
			total += role_fit
		var better: bool = best_team.is_empty()
		if not better:
			if is_equal_approx(total, best_fit):
				better = lead_fit > best_lead
			else:
				better = total > best_fit
		if better:
			best_team = picked
			best_roles = picked_roles
			best_fit = total
			best_lead = lead_fit
	return {"team": best_team, "roles": best_roles, "fit": best_fit}


#The contract's recommendation names, rotated by two places per role; Leader reads them unrotated.
static func _recs_for(contract: ContractView, role: String) -> Dictionary:
	var steps: int = maxi(0, GuiTypes.ROLES.find(role)) * 2
	return {
		"know": _rotate(_names(contract.recommended_knowledges), steps),
		"tools": _rotate(_names(contract.recommended_tools), steps),
		"trads": _rotate(_names(contract.recommended_traditions), steps),
	}


static func _names(entries: Array[BonusEntry]) -> Array[String]:
	var out: Array[String] = []
	for entry: BonusEntry in entries:
		if entry != null and not out.has(entry.name):
			out.append(entry.name)
	return out


static func _rotate(list: Array[String], steps: int) -> Array[String]:
	if list.is_empty():
		return list
	var cut: int = steps % list.size()
	return list.slice(cut) + list.slice(0, cut)


#How high a name ranks in a recommendation list; 1.0 at the top, 0.0 when it is absent.
static func _weight(list: Array[String], name: String) -> float:
	var at: int = list.find(name)
	if at < 0 or list.is_empty():
		return 0.0
	return float(list.size() - at) / float(list.size())


#The mean of the two best weights, counting a missing second entry as zero.
static func _top2(list: Array[String], names: Array[String]) -> float:
	var best: float = 0.0
	var second: float = 0.0
	for name: String in names:
		var value: float = _weight(list, name)
		if value > best:
			second = best
			best = value
		elif value > second:
			second = value
	return (best + second) / 2.0


static func _merged(own: Array[String], shared: Array) -> Array[String]:
	var out: Array[String] = own.duplicate()
	for name: Variant in shared:
		if not out.has(str(name)):
			out.append(str(name))
	return out


static func _view_in(candidates: Array[MercView], uid: int) -> MercView:
	for view: MercView in candidates:
		if view.uid == uid:
			return view
	return null


static func _by_value(a: Dictionary, b: Dictionary) -> bool:
	if float(a["value"]) != float(b["value"]):
		return float(a["value"]) > float(b["value"])
	return int(a["order"]) < int(b["order"])


#Indices 0..size-1 ordered by a comparator, so sorting never moves the source arrays.
static func _order(size: int, less: Callable) -> Array[int]:
	var out: Array[int] = []
	for i: int in size:
		out.append(i)
	out.sort_custom(less)
	return out


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


static func _walk(uids: Array[int], start: int, lo: int, cap: int, current: Array[int],
		odds_fn: Callable, deadline: int, state: Dictionary) -> void:
	if current.size() >= lo:
		_consider(current, odds_fn, state)
	if current.size() >= cap or Time.get_ticks_msec() >= deadline:
		return
	for i: int in range(start, uids.size()):
		current.append(uids[i])
		_walk(uids, i + 1, lo, cap, current, odds_fn, deadline, state)
		current.resize(current.size() - 1)
		if Time.get_ticks_msec() >= deadline:
			return


#Steepest ascent from the best single mercs: one swap, one drop or one addition per round.
static func _climb(uids: Array[int], lo: int, cap: int, odds_fn: Callable, deadline: int,
		state: Dictionary) -> void:
	var ranked: Array[int] = _order(uids.size(), func(a: int, b: int) -> bool:
		var first: Array[int] = [uids[a]]
		var second: Array[int] = [uids[b]]
		var one: int = int(odds_fn.call(first))
		var two: int = int(odds_fn.call(second))
		return one > two if one != two else a < b)
	var team: Array[int] = []
	for i: int in mini(cap, ranked.size()):
		team.append(uids[ranked[i]])
	_consider(team, odds_fn, state)
	for _round: int in MAX_ROUNDS:
		if Time.get_ticks_msec() >= deadline:
			return
		var before: int = int(state["odds"])
		for i: int in team.size():
			for uid: int in uids:
				if team.has(uid):
					continue
				var swapped: Array[int] = team.duplicate()
				swapped[i] = uid
				_consider(swapped, odds_fn, state)
			if team.size() > lo:
				var dropped: Array[int] = team.duplicate()
				dropped.remove_at(i)
				_consider(dropped, odds_fn, state)
			if Time.get_ticks_msec() >= deadline:
				return
		if team.size() < cap:
			for uid: int in uids:
				if team.has(uid):
					continue
				var grown: Array[int] = team.duplicate()
				grown.append(uid)
				_consider(grown, odds_fn, state)
		if int(state["odds"]) <= before:
			return
		var found: Array[int] = state["set"]
		team = found.duplicate()


static func _consider(team: Array[int], odds_fn: Callable, state: Dictionary) -> void:
	var value: int = int(odds_fn.call(team.duplicate()))
	var best: Array[int] = state["set"]
	if value > int(state["odds"]) or (value == int(state["odds"]) and team.size() < best.size()):
		state["odds"] = value
		state["set"] = team.duplicate()
