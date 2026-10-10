class_name GenPlaceTests
#GenLocation, GenExpense, GenQuality, GenValue and GenDeadline rules; runs inside --reach-tests.

const HOUR := CampaignClock.MINUTES_PER_HOUR


static func add_cases(res: Dictionary) -> void:
	_case_anchor(res)
	_case_value(res)
	_case_quality(res)
	_case_deadline(res)
	_case_expense(res)
	_case_tier_mode(res)
	_case_location(res)
	_case_pick(res)
	_case_local(res)


static func _check(res: Dictionary, label: String, passed: bool, why: String) -> void:
	TestFixtures.check(res, "gen place: " + label, passed, why)


static func _row(names: Array[String]) -> ContractData:
	var row: ContractData = ContractData.new()
	row.possible_locations = names
	return row


static func _all_places(blocked: String = "") -> Array[Dictionary]:
	return GenLocation.places(func(p: String) -> bool: return p != blocked, func(_p: String) -> bool: return false)


static func _rng() -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 546
	return rng


static func _case_anchor(res: Dictionary) -> void:
	var levels: Array[int] = [1, 10, 15, 20, 25, 30, 35, 40, 45, 0]
	var want: Array[float] = [10.0, 50.0, 62.5, 75.0, 100.0, 250.0, 275.0, 500.0, 500.0, 10.0]
	for i: int in levels.size():
		var got: float = GenValue.anchor(levels[i])
		_check(res, "anchor at level %d is %s" % [levels[i], want[i]], is_equal_approx(got, want[i]), "got %s" % got)


static func _case_value(res: Dictionary) -> void:
	for level: int in [1, 10, 20, 25, 30, 35, 40]:
		var got: int = GenValue.value(level, GenValue.mean_raw(level), 0.5, 0)
		_check(res, "a mean posting at level %d pays the anchor" % level, got == roundi(GenValue.anchor(level)),
				"got %d" % got)
	var mean: float = GenValue.mean_raw(20)
	var low: int = GenValue.value(20, mean, 0.0, 0)
	var high: int = GenValue.value(20, mean, 1.0, 0)
	var added: int = GenValue.value(20, mean, 1.0, 10)
	_check(res, "quality 0 pays 0.75 of the anchor", low == roundi(75.0 * 0.75), "got %d" % low)
	_check(res, "quality 1 pays 1.25 of the anchor", high == roundi(75.0 * 1.25), "got %d" % high)
	_check(res, "the travel add lands after the multiplier", added == high + 10, "got %d" % added)


static func _case_quality(res: Dictionary) -> void:
	var best: float = GenQuality.score(0, 0.0, 100, 3)
	var worst: float = GenQuality.score(120, 40.0, 0, 0)
	var mid: float = GenQuality.score(60, 20.0, 50, 0)
	_check(res, "quality 1.0 at home, no hours, full satisfaction, 3 matches", is_equal_approx(best, 1.0), str(best))
	_check(res, "quality 0.0 at 120 km, 40 hours, no satisfaction or match", is_equal_approx(worst, 0.0), str(worst))
	_check(res, "quality 0.35 at 60 km, 20 hours, satisfaction 50", is_equal_approx(mid, 0.35), str(mid))
	var lifted: float = GenQuality.promo_lift(0.4, 1.0)
	_check(res, "a full promo match lifts 0.4 to 0.85", is_equal_approx(lifted, 0.85), str(lifted))
	_check(res, "no promo match leaves quality alone", is_equal_approx(GenQuality.promo_lift(0.3, 0.0), 0.3), "moved")


static func _case_deadline(res: Dictionary) -> void:
	var floor_slack: int = GenDeadline.slack_minutes(60, 0.0, 0)
	_check(res, "slack never drops under 12 hours", floor_slack == 12 * HOUR, "got %d" % floor_slack)
	var lo: int = GenDeadline.slack_minutes(10000, 0.0, 0)
	var hi: int = GenDeadline.slack_minutes(10000, 1.0, 0)
	_check(res, "quality 0 leaves 10% of expected", lo == 1000, "got %d" % lo)
	_check(res, "quality 1 leaves 100% of expected", hi == 10000, "got %d" % hi)
	var kind: int = GenDeadline.slack_minutes(10000, 0.0, 3)
	var cold: int = GenDeadline.slack_minutes(10000, 0.0, -3)
	_check(res, "face 3 adds 12 hours of slack", kind == 1000 + 12 * HOUR, "got %d" % kind)
	_check(res, "face -3 adds no slack", cold == 1000, "got %d" % cold)
	var expected: int = GenDeadline.expected_minutes("foot", 30, 8 * HOUR)
	_check(res, "expected is one foot day plus 8 hours of work", expected == 32 * HOUR, "got %d" % expected)
	_check(res, "deadline is now plus expected plus slack", GenDeadline.deadline(100, 200, 300) == 600, "wrong sum")
	var tiers: Array[int] = [GenDeadline.urgency(23 * HOUR), GenDeadline.urgency(47 * HOUR),
			GenDeadline.urgency(48 * HOUR)]
	_check(res, "urgency 2 under 24 hours, 1 under 48, else 0", tiers == [2, 1, 0], str(tiers))


static func _case_expense(res: Dictionary) -> void:
	var foot_zero: int = GenExpense.expense("foot", 0, 2)
	_check(res, "0 km on foot still charges one day", foot_zero >= Reachability.outbound_cost("foot", 0, 2)
			and foot_zero > 0, "got %d" % foot_zero)
	var cart_zero: int = GenExpense.expense("caravan", 0, 2)
	_check(res, "0 km by caravan charges one day of caravan travel",
			cart_zero == Reachability.outbound_cost("caravan", 45, 2) and cart_zero > 0, "got %d" % cart_zero)
	for key: String in ["foot", "horse", "train"]:
		var near: int = GenExpense.expense(key, 100, 2)
		var far: int = GenExpense.expense(key, 200, 2)
		_check(res, "%s at 200 km costs at least 100 km" % key, far >= near, "%d < %d" % [far, near])
	_check(res, "travel add is 25% at quality 0", GenExpense.travel_add(100, 0.0) == 25, "wrong")
	_check(res, "travel add is 175% at quality 1", GenExpense.travel_add(100, 1.0) == 175, "wrong")


static func _case_tier_mode(res: Dictionary) -> void:
	var levels: Array[int] = [1, 9, 10, 19, 20, 29, 30, 39, 40]
	var want: Array[String] = ["foot", "foot", "caravan", "caravan", "horse", "horse", "train", "train", "airship"]
	for i: int in levels.size():
		var got: String = GenExpense.tier_mode(float(levels[i]))
		_check(res, "level %d travels by %s" % [levels[i], want[i]], got == want[i], got)
	var steps: Array[String] = [GenExpense.mode_for(40.0, 200), GenExpense.mode_for(40.0, 100),
			GenExpense.mode_for(30.0, 50), GenExpense.mode_for(40.0, 10)]
	_check(res, "mode_for steps down when the gate refuses the tier mode",
			steps == ["airship", "train", "horse", "foot"], str(steps))


static func _case_location(res: Dictionary) -> void:
	var names: Array[String] = []
	for cand: Dictionary in GenLocation.candidates(null, _all_places("Aerdis")):
		names.append(str(cand["shown"]))
	_check(res, "a place without ops is never a candidate", not names.has("Aerdis") and names.has("Zukei"),
			str(names))
	var none: Array[Dictionary] = GenLocation.places(func(_p: String) -> bool: return false,
			func(_p: String) -> bool: return false)
	var home_only: Array[Dictionary] = GenLocation.candidates(null, none)
	_check(res, "the home place is a candidate without any permit",
			home_only.size() == 1 and str(home_only[0]["name"]) == GenConstants.GUILD_HOME, str(home_only))
	_check(res, "a settlement resolves to its country", GenLocation.country_of("Beldapor") == "Buern"
			and GenLocation.country_of("Cathistii") == "Aerdis", GenLocation.country_of("Beldapor"))
	_check(res, "a country gives itself and an unknown name gives none", GenLocation.country_of("Copari") == "Copari"
			and GenLocation.country_of("Nowhere") == "", GenLocation.country_of("Nowhere"))
	var bands: Array[String] = [GenLocation.band(0.6, 0.2), GenLocation.band(0.2, 0.6), GenLocation.band(0.5, 0.5)]
	_check(res, "band far, near, any by the roster shares", bands == ["far", "near", "any"], str(bands))


static func _case_pick(res: Dictionary) -> void:
	var rng: RandomNumberGenerator = _rng()
	var places: Array[Dictionary] = _all_places()
	var near_ok: bool = true
	var far_ok: bool = true
	for i: int in 200:
		var near: Dictionary = GenLocation.pick(null, places, 0.0, 1.0, rng)
		near_ok = near_ok and int(GenConstants.DISTANCE_KM[near["country"]]) <= GenConstants.NEAR_KM
		var far: Dictionary = GenLocation.pick(null, places, 1.0, 0.0, rng)
		far_ok = far_ok and int(GenConstants.DISTANCE_KM[far["country"]]) >= GenConstants.FAR_KM
	_check(res, "the near band picks only places within NEAR_KM", near_ok, "a far place")
	_check(res, "the far band picks only places from FAR_KM", far_ok, "a near place")
	var fallback: Dictionary = GenLocation.pick(_row(["Miliim"]), places, 0.0, 1.0, rng)
	_check(res, "an empty band falls back to every candidate", fallback["place"] == "Miliim", str(fallback))
	var homeless: Dictionary = GenLocation.pick(_row(["Aerdis"]), _all_places("Aerdis"), 0.0, 0.0, rng)
	_check(res, "no candidate gives the home place", homeless["place"] == GenConstants.GUILD_HOME, str(homeless))
	var town: Dictionary = GenLocation.pick(_row(["Beldapor"]), places, 0.0, 0.0, rng)
	_check(res, "a settlement posting shows the town and prices its country",
			town["place"] == "Beldapor" and town["country"] == "Buern", str(town))
	var lo: int = 9999
	var hi: int = 0
	for i: int in 1000:
		var km: int = int(GenLocation.pick(_row(["Rossade"]), places, 0.0, 0.0, rng)["km"])
		lo = mini(lo, km)
		hi = maxi(hi, km)
	_check(res, "70 km jitters inside +-20% over 1000 draws", lo >= 56 and hi <= 84 and lo < hi,
			"%d..%d" % [lo, hi])


#Card 736: a Local row posts at the guild home with 0 km in every band; a non-local row keeps its own place and km.
static func _case_local(res: Dictionary) -> void:
	var rng: RandomNumberGenerator = _rng()
	var places: Array[Dictionary] = _all_places()
	var local_row: ContractData = _row(["Rossade"])
	local_row.local = true
	var home_ok: bool = true
	var seen: Array[String] = []
	for shares: Array in [[0.0, 1.0], [1.0, 0.0], [0.0, 0.0]]:
		var spot: Dictionary = GenLocation.pick(local_row, places, float(shares[0]), float(shares[1]), rng)
		home_ok = home_ok and spot["place"] == GenConstants.GUILD_HOME and spot["country"] == GenConstants.GUILD_HOME \
			and int(spot["km"]) == 0
		seen.append(str(spot))
	_check(res, "local:pick_home_zero_km near, far and any", home_ok, str(seen))
	var plain_row: ContractData = _row(["Rossade"])
	var plain: Dictionary = GenLocation.pick(plain_row, places, 0.0, 0.0, rng)
	_check(res, "local:non_local_keeps_place", not plain_row.local and plain["country"] == "Rossade"
			and int(plain["km"]) >= 56 and int(plain["km"]) <= 84, str(plain))
