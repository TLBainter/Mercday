class_name GenExpense
#Expected travel expense of a posting: the tier mode by level, the round-trip fare and the travel add.


static func tier_mode(avg_level: float) -> String:
	return str(GenConstants.EXPENSE_TIERS[_tier_index(avg_level)]["mode"])


#The tier mode, stepped down to the fastest tier mode the distance gate allows at km.
static func mode_for(avg_level: float, km: int) -> String:
	var i: int = _tier_index(avg_level)
	while i > 0 and not Reachability.distance_ok(str(GenConstants.EXPENSE_TIERS[i]["mode"]), km):
		i -= 1
	return str(GenConstants.EXPENSE_TIERS[i]["mode"])


#Round-trip fare for the team, never less than one day of travel in that mode.
static func expense(mode_key: String, km: int, team_size: int) -> int:
	var round_trip: int = 2 * Reachability.outbound_cost(mode_key, km, team_size)
	var per_day: int = int(GuiTypes.travel_mode(mode_key).get("km_per_day", 0))
	return maxi(round_trip, Reachability.outbound_cost(mode_key, per_day, team_size))


static func travel_add(expense_notes: int, quality: float) -> int:
	return roundi(float(expense_notes) * lerpf(GenConstants.TRAVEL_ADD_LO, GenConstants.TRAVEL_ADD_HI, quality))


static func _tier_index(avg_level: float) -> int:
	var last: int = GenConstants.EXPENSE_TIERS.size() - 1
	for i: int in last:
		if avg_level <= float(GenConstants.EXPENSE_TIERS[i]["max_level"]):
			return i
	return last
