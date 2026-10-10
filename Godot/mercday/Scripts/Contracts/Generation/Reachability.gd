class_name Reachability

#Whether a posting can still be reached before its deadline by each travel mode, and which modes a venture may use.

const CARAVAN_MIN_KM: int = 15
const HORSE_MIN_KM: int = 22
const TRAIN_MIN_KM: int = 60
const AIRSHIP_MIN_KM: int = 125
const TELEPORT_MIN_KM: int = 125
const DEFAULT_COMPLETION_MINUTES: int = 480
const WARNING_MINUTES: int = 1440
const FOOT: String = "foot"
const TELEPORT: String = "teleport"
#Every travel mode key, in GuiTypes.TRAVEL_MODES order.
const MODES: Array[String] = ["foot", "caravan", "horse", "train", "airship", "teleport"]


#One leg in minutes, the numbers GameState.travel_minutes gives; an unknown mode takes the flat default.
static func base_minutes(mode_key: String, km: int) -> int:
	var mode: Dictionary = GuiTypes.travel_mode(mode_key)
	if mode.is_empty():
		return CampaignClock.TRAVEL_MINUTES
	var per_day: float = float(mode["km_per_day"])
	if per_day <= 0.0:
		return 0
	return int(ceil(float(km) / per_day * float(CampaignClock.MINUTES_PER_DAY)))


#A night order waits for the 6:00 wake, as the dispatch queue does.
static func departure_minute(now: int) -> int:
	if ContractScheduler.is_night_minute(now):
		return ContractScheduler.next_wake_minute(now)
	return now


#Walks the field clock like ContractScheduler: travel halts at 22:00 and resumes when the camp breaks.
static func arrival_minute(depart: int, minutes: int) -> int:
	var t: int = depart
	var left: int = maxi(0, minutes)
	while left > 0:
		if ContractScheduler.is_night_minute(t):
			t = _camp_wake(t)
		var leg: int = mini(left, ContractScheduler.next_hour_after(t, ContractScheduler.NIGHT_START_HOUR) - t)
		t += leg
		left -= leg
	return t


static func completion_minutes(entry: BoardEntry) -> int:
	if entry == null or entry.completion_hours <= 0:
		return DEFAULT_COMPLETION_MINUTES
	return entry.completion_hours * CampaignClock.MINUTES_PER_HOUR


static func distance_ok(mode_key: String, km: int) -> bool:
	if mode_key == FOOT:
		return true
	var gate: int = _gate_km(mode_key)
	return gate >= 0 and km > gate


#The venture modes in table order: far enough, teleport only with the permit, and only foot in the red.
static func offered_modes(entry: BoardEntry, bank: int, tele_permit: bool) -> Array[String]:
	var out: Array[String] = []
	if entry == null:
		return out
	if bank < 0:
		out.append(FOOT)
		return out
	for key: String in MODES:
		if key == TELEPORT and not tele_permit:
			continue
		if distance_ok(key, entry.distance_km):
			out.append(key)
	return out


#The guild always walks: foot passes at any bank; a paid mode needs the fare in hand.
static func fare_ok(mode_key: String, cost: int, bank: int) -> bool:
	return mode_key == FOOT or cost <= bank


static func outbound_cost(mode_key: String, km: int, team_size: int) -> int:
	return DispatchLogic.travel_cost(GuiTypes.travel_mode(mode_key), team_size, 0, km)


static func can_reach(entry: BoardEntry, mode_key: String, now: int) -> bool:
	if entry == null:
		return false
	if entry.deadline_minute <= 0:
		return true
	var arrive: int = arrival_minute(departure_minute(now), base_minutes(mode_key, entry.distance_km))
	return arrive + completion_minutes(entry) <= entry.deadline_minute


#The last minute this mode can still leave in time; -1 when the posting is unbounded or already out of reach.
static func last_reach_minute(entry: BoardEntry, mode_key: String, now: int) -> int:
	if entry == null or entry.deadline_minute <= 0:
		return -1
	if not can_reach(entry, mode_key, now):
		return -1
	var lo: int = now
	var hi: int = maxi(now, entry.deadline_minute)
	while lo < hi:
		var mid: int = lo + ((hi - lo + 1) >> 1)
		if can_reach(entry, mode_key, mid):
			lo = mid
		else:
			hi = mid - 1
	return lo


#One past the latest minute any of these modes can leave and still meet the deadline: the auto-reject minute.
#now when none of them can; -1 when the posting is unbounded.
static func auto_reject_minute(entry: BoardEntry, modes: Array[String], now: int) -> int:
	if entry == null or entry.deadline_minute <= 0:
		return -1
	var last: int = -1
	for key: String in modes:
		last = maxi(last, last_reach_minute(entry, key, now))
	return now if last < 0 else last + 1


static func modes_in_time(entry: BoardEntry, now: int, bank: int, tele_permit: bool) -> Array[String]:
	var out: Array[String] = []
	for key: String in offered_modes(entry, bank, tele_permit):
		if can_reach(entry, key, now):
			out.append(key)
	return out


#The fastest in-time mode the bank can pay one way; "" when none.
static func best_mode(entry: BoardEntry, now: int, bank: int, tele_permit: bool, team_size: int) -> String:
	var best: String = ""
	var best_speed: float = -1.0
	if entry == null:
		return best
	for key: String in modes_in_time(entry, now, bank, tele_permit):
		if not fare_ok(key, outbound_cost(key, entry.distance_km, team_size), bank):
			continue
		var speed: float = _speed(key)
		if speed > best_speed:
			best = key
			best_speed = speed
	return best


#The minute the posting goes out of reach for the best mode; -1 when unbounded.
static func expiry_minute(entry: BoardEntry, now: int, bank: int, tele_permit: bool, team_size: int) -> int:
	if entry == null or entry.deadline_minute <= 0:
		return -1
	var best: String = best_mode(entry, now, bank, tele_permit, team_size)
	if best == "":
		return now
	return last_reach_minute(entry, best, now) + 1


static func warning_minute(expiry: int) -> int:
	return expiry - WARNING_MINUTES


#Mirrors ContractScheduler._suspend: a short night wakes at 6:00, a long one also waits out the respite.
static func _camp_wake(t: int) -> int:
	var wake6: int = ContractScheduler.next_wake_minute(t)
	if wake6 - t < ContractScheduler.SHORT_NIGHT_MINUTES:
		return wake6
	return maxi(wake6, t + RestSystem.RESPITE_MINUTES)


static func _gate_km(mode_key: String) -> int:
	match mode_key:
		"caravan":
			return CARAVAN_MIN_KM
		"horse":
			return HORSE_MIN_KM
		"train":
			return TRAIN_MIN_KM
		"airship":
			return AIRSHIP_MIN_KM
		"teleport":
			return TELEPORT_MIN_KM
	return -1


static func _speed(mode_key: String) -> float:
	if mode_key == TELEPORT:
		return INF
	return float(GuiTypes.travel_mode(mode_key).get("km_per_day", 0))
