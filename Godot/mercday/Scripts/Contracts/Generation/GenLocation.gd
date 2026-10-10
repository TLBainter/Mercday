class_name GenLocation
#Where a generated posting takes place: permitted, reachable places, the distance band and the jittered distance.


#A DISTANCE_KM name gives itself, a settlement or area its parent country, an unknown name "".
static func country_of(place: String) -> String:
	if GenConstants.DISTANCE_KM.has(place):
		return place
	var loc: LocationData = DataManager.locations.get(place, null) as LocationData
	while loc != null:
		if GenConstants.DISTANCE_KM.has(loc.location_name) or loc.location_type == "Country":
			return loc.location_name
		loc = loc.parent
	return ""


#One {"name", "km", "ops", "tele"} per DISTANCE_KM row; the callables take the country name.
static func places(ops_held: Callable, tele_held: Callable) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for place: String in GenConstants.DISTANCE_KM:
		var ops: bool = place == GenConstants.GUILD_HOME or bool(ops_held.call(place))
		out.append({"name": place, "km": int(GenConstants.DISTANCE_KM[place]), "ops": ops,
				"tele": bool(tele_held.call(place))})
	return out


#Permitted, reachable places the row allows; "shown" is the name the posting shows.
static func candidates(row: ContractData, places: Array[Dictionary]) -> Array[Dictionary]:
	var by_name: Dictionary = {}
	for place: Dictionary in places:
		by_name[str(place["name"])] = place
	var wanted: Array[String] = []
	if row != null and not row.possible_locations.is_empty():
		wanted = row.possible_locations
	else:
		wanted.assign(by_name.keys())
	var out: Array[Dictionary] = []
	for shown: String in wanted:
		var place: Dictionary = by_name.get(country_of(shown), {})
		if place.is_empty() or not bool(place["ops"]) or not _reachable(int(place["km"]), bool(place["tele"])):
			continue
		var cand: Dictionary = place.duplicate()
		cand["shown"] = shown
		out.append(cand)
	return out


static func band(near_share: float, far_share: float) -> String:
	if far_share > GenConstants.BALANCE_SHARE:
		return "near"
	if near_share > GenConstants.BALANCE_SHARE:
		return "far"
	return "any"


static func pick(row: ContractData, places: Array[Dictionary], near_share: float, far_share: float,
		rng: RandomNumberGenerator) -> Dictionary:
	if row != null and row.local:
		return {"place": GenConstants.GUILD_HOME, "country": GenConstants.GUILD_HOME, "km": 0}
	var all: Array[Dictionary] = candidates(row, places)
	var want: String = band(near_share, far_share)
	var pool: Array[Dictionary] = []
	for cand: Dictionary in all:
		var km: int = int(cand["km"])
		if want == "any" or (want == "near" and km <= GenConstants.NEAR_KM) \
				or (want == "far" and km >= GenConstants.FAR_KM):
			pool.append(cand)
	if pool.is_empty():
		pool = all
	var shown: String = GenConstants.GUILD_HOME
	var country: String = GenConstants.GUILD_HOME
	if not pool.is_empty():
		var cand: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		shown = str(cand["shown"])
		country = str(cand["name"])
	var base: float = float(GenConstants.DISTANCE_KM[country])
	var jitter: float = rng.randf_range(-GenConstants.DISTANCE_JITTER, GenConstants.DISTANCE_JITTER)
	return {"place": shown, "country": country, "km": maxi(1, roundi(base * (1.0 + jitter)))}


static func _reachable(km: int, tele: bool) -> bool:
	if tele:
		return true
	for key: String in Reachability.MODES:
		if key != Reachability.TELEPORT and Reachability.distance_ok(key, km):
			return true
	return false
