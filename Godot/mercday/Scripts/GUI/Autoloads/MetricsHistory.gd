extends Node

#One sample per in-game day for the metrics viewer. GameState sets the three source callables and
#calls record_day once per day boundary; each callable returns a Dictionary of key to float for
#that day. Keys are opaque: the Merc source prefixes "<merc uid>/" and the Contract source prefixes
#"<contract type>/" and repeats the totals under the bare key. An EVENT_AVG metric stores the day
#sum under its key and the day count under "<key>_n". seed_preview fills a second, separate store
#with the deterministic sample history of metrics_history_generator.js; use_preview picks which of
#the two stores days(), first_day(), series() and combined_series() read, and the live campaign
#keeps recording into its own store either way.

const SOURCES: Array[String] = ["Guild", "Contract", "Merc"]
#Trynn week and the mean Trynn month (330 days over 10 months); a quarter is three months.
const DAYS_PER_WEEK := 10
const DAYS_PER_MONTH := 33
const DAYS_PER_QUARTER := 99
#Sample history constants of metrics_history_generator.js, matched to sample_data.json.
const EMPLOYMENT: Array[int] = [14, 3, 27, 8, 19, 1, 11, 6, 22, 4]
const LEVELS: Array[int] = [7, 12, 3, 9, 15, 5, 11, 2, 8, 4]
const SALARIES: Array[int] = [60, 150, 1200, 80, 300, 40, 90, 1500, 70, 120]
const GHOSTS: Array[Array] = [[0, 200], [0, 410], [60, 700]]

var defs: Array[MetricDef] = []
var merc_source: Callable = Callable()
var contract_source: Callable = Callable()
var guild_source: Callable = Callable()

var _rows: Dictionary = {}
var _first_day: int = -1
var _preview_rows: Dictionary = {}
var _preview_first: int = -1
var _use_preview: bool = false


func _init() -> void:
	defs = _build_defs()
	clear()
	clear_preview()


#Empties the live store; the preview store keeps whatever seed_preview left in it.
func clear() -> void:
	_rows = _blank()
	_first_day = -1


#Empties the preview store and hands the reads back to the live one.
func clear_preview() -> void:
	_preview_rows = _blank()
	_preview_first = -1
	_use_preview = false


#Test hook: picks which store days(), first_day(), series() and combined_series() read.
func use_preview(on: bool) -> void:
	_use_preview = on


func using_preview() -> bool:
	return _use_preview


static func _blank() -> Dictionary:
	var store: Dictionary = {}
	for source: String in SOURCES:
		var rows: Array[Dictionary] = []
		store[source] = rows
	return store


func _store() -> Dictionary:
	return _preview_rows if _use_preview else _rows


#Appends one day of samples from the three sources.
func record_day(day_index: int) -> void:
	if _first_day < 0:
		_first_day = day_index
	_append("Merc", merc_source, day_index)
	_append("Contract", contract_source, day_index)
	_append("Guild", guild_source, day_index)


func days() -> int:
	return (_store()["Guild"] as Array[Dictionary]).size()


#The day index of the first recorded day; -1 while nothing is recorded.
func first_day() -> int:
	return _preview_first if _use_preview else _first_day


#The scales the viewer may offer for a history that many days long.
func scales(day_count: int) -> Array[String]:
	var out: Array[String] = ["Days"]
	if day_count >= 10 * DAYS_PER_WEEK:
		out.append("Weeks")
	if day_count >= 10 * DAYS_PER_MONTH:
		out.append("Months")
	if day_count >= 100 * DAYS_PER_MONTH:
		out.append("Quarters")
	return out


#Buckets one key of one source into {day, value} points; day is the first recorded day of the
#bucket, counted from the start of the record. An EVENT_AVG bucket with no events carries the
#previous value forward, and leading empty buckets take the first value that exists. day_count
#windows the read to that many recorded days from from_day; -1 reads to the end of the record.
func series(source: String, key: String, from_day: int, bucket_days: int,
		day_count: int = -1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var store: Dictionary = _store()
	if not store.has(source):
		return out
	var keys: Array[String] = [key]
	return _bucketed(store[source], keys, _agg_for(source, key), from_day, bucket_days, day_count)


#The same buckets over several contract types at once, plotted when more than one type is picked.
#SUM and LAST add the per type keys together. AVG divides the summed values by the summed
#"<key>_n" counts when the record keeps them, else by one weight per type present in the row per
#day (a type the row does not carry adds no weight), which makes it the plain mean of the per
#type averages that are present. EVENT_AVG divides the summed values by the summed
#"<key>_n" counts and carries the previous bucket value forward when a bucket holds none.
func combined_series(source: String, key: String, types: Array[String], from_day: int,
		bucket_days: int, day_count: int = -1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var store: Dictionary = _store()
	if not store.has(source):
		return out
	var keys: Array[String] = []
	for type_name: String in types:
		keys.append("%s/%s" % [type_name, key])
	if keys.is_empty():
		keys.append(key)
	return _bucketed(store[source], keys, _agg_for(source, key), from_day, bucket_days, day_count)


#The distinct merc uids the Merc keys of the store on show carry, ascending.
func merc_uids() -> Array[int]:
	var seen: Dictionary = {}
	var rows: Array[Dictionary] = _store()["Merc"]
	for row: Dictionary in rows:
		for key: String in row:
			var cut: int = key.find("/")
			if cut <= 0:
				continue
			var head: String = key.substr(0, cut)
			if head.is_valid_int():
				seen[int(head)] = true
	var out: Array[int] = []
	for uid: int in seen:
		out.append(uid)
	out.sort()
	return out


#The first recorded day this merc drew a wage on; -1 while the record never held one.
func hire_day(uid: int) -> int:
	var key: String = "%d/salary" % uid
	var rows: Array[Dictionary] = _store()["Merc"]
	for day: int in rows.size():
		if _cell(rows[day], key) > 0.0:
			return day
	return -1


#The mean of one merc metric over the mercs employed in each bucket, bucketed like series(). A
#bucket no merc was hired in yet carries NAN, and exclude_uid is left out of the mean.
func team_average(key: String, from_day: int, bucket_days: int, exclude_uid: int = -1,
		day_count: int = -1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var size: int = maxi(1, bucket_days)
	var lists: Array[Array] = []
	var hires: Array[int] = []
	for uid: int in merc_uids():
		if uid == exclude_uid:
			continue
		lists.append(series("Merc", "%d/%s" % [uid, key], from_day, size, day_count))
		hires.append(hire_day(uid))
	var count: int = 0
	for list: Array in lists:
		count = maxi(count, list.size())
	for i: int in count:
		var sum: float = 0.0
		var seen: int = 0
		var day: int = 0
		for j: int in lists.size():
			var list: Array = lists[j]
			if i >= list.size():
				continue
			day = int((list[i] as Dictionary).get("day", 0))
			if hires[j] < 0 or hires[j] >= day + size:
				continue
			sum += float((list[i] as Dictionary).get("value", 0.0))
			seen += 1
		var value: float = NAN
		if seen > 0:
			value = sum / float(seen)
		out.append({"day": day, "value": value})
	return out


func _bucketed(rows: Array[Dictionary], keys: Array[String], agg: String, from_day: int,
		bucket_days: int, day_count: int = -1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var size: int = maxi(1, bucket_days)
	var start: int = clampi(from_day, 0, rows.size())
	var end: int = rows.size()
	if day_count >= 0:
		end = mini(rows.size(), start + maxi(0, day_count))
	var folds: Dictionary = {"EVENT_AVG": _event_avg_of, "AVG": _avg_of, "LAST": _last_of}
	var fold: Callable = folds.get(agg, _sum_of)
	var previous: Variant = null
	var missing: Array[int] = []
	var bucket: int = start
	while bucket < end:
		var stop: int = mini(end, bucket + size)
		var value: Variant = fold.call(rows, keys, bucket, stop)
		if value != null:
			previous = value
		elif previous != null:
			value = previous
		else:
			missing.append(out.size())
			value = 0.0
		out.append({"day": bucket, "value": float(value)})
		bucket += size
	if not missing.is_empty() and missing.size() < out.size():
		var first: float = float(out[missing.size()]["value"])
		for i: int in missing:
			out[i]["value"] = first
	return out


#EVENT_AVG: the summed values of a bucket over its summed event counts; null when the counts sum to zero.
func _event_avg_of(rows: Array[Dictionary], keys: Array[String], bucket: int, stop: int) -> Variant:
	var sum: float = 0.0
	var count: float = 0.0
	for d: int in range(bucket, stop):
		for key: String in keys:
			sum += _cell(rows[d], key)
			count += _cell(rows[d], key + "_n")
	if count > 0.0:
		return sum / count
	return null


#AVG: the mean of the cells a bucket holds, each weighted by its _n cell or else by one; null when the weights sum to zero.
func _avg_of(rows: Array[Dictionary], keys: Array[String], bucket: int, stop: int) -> Variant:
	var sum: float = 0.0
	var count: float = 0.0
	for d: int in range(bucket, stop):
		for key: String in keys:
			if not rows[d].has(key):
				continue
			var weight: float = _cell(rows[d], key + "_n") if rows[d].has(key + "_n") else 1.0
			sum += _cell(rows[d], key) * weight
			count += weight
	if count > 0.0:
		return sum / count
	return null


#LAST: the keys summed on the last day of a bucket.
func _last_of(rows: Array[Dictionary], keys: Array[String], _bucket: int, stop: int) -> Variant:
	var last: float = 0.0
	for key: String in keys:
		last += _cell(rows[stop - 1], key)
	return last


#Any other agg: the keys summed over every day of a bucket.
func _sum_of(rows: Array[Dictionary], keys: Array[String], bucket: int, stop: int) -> Variant:
	var sum: float = 0.0
	for d: int in range(bucket, stop):
		for key: String in keys:
			sum += _cell(rows[d], key)
	return sum


#Fills the preview store with the deterministic sample history; days is the whole span in in-game
#days. uids renames the ten preview mercs onto real roster uids, so a live viewer reads its own
#keys. The live store is untouched and the reads switch to the preview until clear_preview().
func seed_preview(day_count: int, uids: Array[int] = []) -> void:
	_preview_rows = _blank()
	_preview_first = -1
	_use_preview = true
	var span: int = maxi(1, day_count)
	var rng := Rng.new(17 + int(span / 30.0))
	var hire: Array[int] = []
	for months: int in EMPLOYMENT:
		hire.append(maxi(0, span - months * 30))
	var ghosts: Array[Array] = []
	for ghost: Array in GHOSTS:
		if int(ghost[1]) < span:
			ghosts.append(ghost)
	var guild: Dictionary = {}
	for key: String in ["bank", "exp", "count", "dead", "mop", "cop", "port"]:
		guild[key] = _zeros(span)
	var type_names: Array[String] = ContractLibrary.contract_type_names()
	var type_count: int = maxi(1, type_names.size())
	var types: Array[Dictionary] = []
	for _t: int in type_count:
		var row: Dictionary = {}
		for key: String in ["count", "i1", "i2", "i3", "i4", "wins", "losses",
				"diff", "diff_n", "reward", "reward_n", "expense", "expense_n", "time", "time_n"]:
			row[key] = _zeros(span)
		types.append(row)
	var mercs: Array[Dictionary] = []
	for _m: int in LEVELS.size():
		var row: Dictionary = {}
		for key: String in ["salary", "xp", "level", "wins", "losses", "kills", "op",
				"vac", "sRoll", "sRoll_n", "fRoll", "fRoll_n"]:
			row[key] = _zeros(span)
		mercs.append(row)
	_seed_opinions(mercs, hire, span, rng)
	_seed_salaries(mercs, hire, span)
	var cash: Array[float] = _zeros(span)
	var client_opinion: float = 1.0
	for day: int in span:
		var live: Array[int] = []
		for i: int in hire.size():
			if day >= hire[i]:
				live.append(i)
		var ghost_count: int = 0
		for ghost: Array in ghosts:
			if day >= int(ghost[0]) and day < int(ghost[1]):
				ghost_count += 1
			if int(ghost[1]) == day:
				guild["dead"][day] += 1.0
		guild["count"][day] = float(live.size() + ghost_count)
		for i: int in live:
			mercs[i]["xp"][day] += 2.0 + float(floori(rng.next() * 4.0))
		if guild["count"][day] > 0.0 and rng.next() < minf(0.7, 0.2 + 0.05 * float(guild["count"][day])):
			client_opinion += 0.35 if _seed_contract(types, mercs, guild, cash, live, day, span, rng,
				type_count) else -0.8
		if day % 30 == 29:
			var pay: float = float(ghost_count) * 60.0
			for i: int in live:
				pay += mercs[i]["salary"][day]
			cash[day] -= pay
			guild["exp"][day] += pay
		client_opinion = maxf(-5.0, minf(5.0, client_opinion * 0.99))
		guild["cop"][day] = client_opinion
		if not live.is_empty():
			var sum: float = 0.0
			for i: int in live:
				sum += mercs[i]["op"][day]
			guild["mop"][day] = sum / float(live.size())
	_seed_bank(guild["bank"], cash, span)
	_seed_portfolio(guild["port"], guild["bank"], span, rng)
	_seed_vacations(mercs, hire, span, rng)
	_seed_levels(mercs, hire, span)
	_store_preview(guild, types, mercs, span, type_names, uids)


#The mulberry32 generator of the sample scripts, kept bit exact on 32 bit words.
class Rng:
	var _state: int = 0

	func _init(seed_value: int) -> void:
		_state = (seed_value * 2654435761) & 0xFFFFFFFF

	func next() -> float:
		_state = (_state + 0x6D2B79F5) & 0xFFFFFFFF
		var t: int = _imul(_state ^ (_state >> 15), _state | 1)
		t = (t ^ ((t + _imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF
		return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0

	static func _imul(x: int, y: int) -> int:
		var a: int = x & 0xFFFFFFFF
		var b: int = y & 0xFFFFFFFF
		return ((a & 0xFFFF) * b + ((((a >> 16) * b) & 0xFFFF) << 16)) & 0xFFFFFFFF


static func _zeros(size: int) -> Array[float]:
	var out: Array[float] = []
	out.resize(size)
	return out


#JavaScript Math.round: halves go up, not away from zero.
static func _js_round(value: float) -> float:
	return float(floori(value + 0.5))


static func _shuffle(source: Array[int], rng: Rng) -> Array[int]:
	var out: Array[int] = source.duplicate()
	for i: int in range(out.size() - 1, 0, -1):
		var j: int = floori(rng.next() * float(i + 1))
		var held: int = out[i]
		out[i] = out[j]
		out[j] = held
	return out


func _seed_opinions(mercs: Array[Dictionary], hire: Array[int], span: int, rng: Rng) -> void:
	for i: int in mercs.size():
		var opinion: int = (i * 4 + 10) % 11 - 5
		var day: int = span - 1
		while day >= hire[i]:
			mercs[i]["op"][day] = float(opinion)
			if rng.next() < 0.035:
				opinion = clampi(opinion + (-1 if rng.next() < 0.5 else 1), -5, 5)
			day -= 1


func _seed_salaries(mercs: Array[Dictionary], hire: Array[int], span: int) -> void:
	for i: int in mercs.size():
		var served: int = span - hire[i]
		var steps: int = int(served / 180.0)
		for day: int in range(hire[i], span):
			var reached: int = floori(float(day - hire[i]) / float(served) * float(steps + 1))
			mercs[i]["salary"][day] = _js_round(float(SALARIES[i]) * (1.0 - 0.12 * float(steps - reached)))


#Rolls one sample contract into the day and reports whether it succeeded.
func _seed_contract(types: Array[Dictionary], mercs: Array[Dictionary], guild: Dictionary,
		cash: Array[float], live: Array[int], day: int, span: int, rng: Rng,
		type_count: int) -> bool:
	var difficulty: float = maxf(0.5, minf(5.0,
		_js_round((0.5 + rng.next() * 3.0 + float(day) / float(span) * 1.5) * 2.0) / 2.0))
	var reward: float = _js_round(difficulty * 150.0 * (0.6 + rng.next() * 0.8))
	var expense: float = _js_round(reward * (0.06 + rng.next() * 0.12))
	var won: bool = rng.next() < 0.92 - difficulty * 0.08
	var type: Dictionary = types[floori(rng.next() * float(type_count))]
	type["count"][day] += 1.0
	type["i%d" % (1 + floori(rng.next() * 4.0))][day] += 1.0
	_add_event(type, "diff", day, difficulty)
	_add_event(type, "reward", day, reward)
	_add_event(type, "expense", day, expense)
	_add_event(type, "time", day, (12.0 + difficulty * 20.0 * (0.5 + rng.next())) / 24.0)
	type["wins" if won else "losses"][day] += 1.0
	cash[day] += (reward if won else 0.0) - expense
	guild["exp"][day] += expense
	var team: Array[int] = _shuffle(live, rng)
	team.resize(mini(team.size(), 1 + floori(rng.next() * float(mini(4, live.size())))))
	for i: int in team:
		mercs[i]["xp"][day] += _js_round(40.0 + difficulty * 30.0 * (1.0 if won else 0.5))
		mercs[i]["wins" if won else "losses"][day] += 1.0
		_add_event(mercs[i], "sRoll", day, 2.0 + rng.next() * 3.0 + (2.0 if won else 0.0))
		_add_event(mercs[i], "fRoll", day, 1.0 + rng.next() * 2.0 + (0.0 if won else 2.0))
		mercs[i]["kills"][day] += float(floori(rng.next() * difficulty * 2.5))
	return won


func _seed_bank(bank: Array[float], cash: Array[float], span: int) -> void:
	var balance: float = 500.0
	var lowest: float = INF
	for day: int in span:
		balance += cash[day]
		bank[day] = balance
		lowest = minf(lowest, balance)
	if lowest < 100.0:
		for day: int in span:
			bank[day] += 100.0 - lowest


#A slow walk of the invested value, held between nothing and about five percent of the bank.
func _seed_portfolio(port: Array[float], bank: Array[float], span: int, rng: Rng) -> void:
	var value: float = 0.0
	for day: int in span:
		var cap: float = maxf(0.0, bank[day] * 0.05)
		value = clampf(value + (rng.next() - 0.45) * maxf(1.0, cap * 0.06), 0.0, cap)
		port[day] = value


#Two or three holidays of three to six days each, taken after the merc was hired.
func _seed_vacations(mercs: Array[Dictionary], hire: Array[int], span: int, rng: Rng) -> void:
	for i: int in mercs.size():
		var served: int = span - hire[i]
		if served <= 7:
			continue
		var runs: int = 2 + floori(rng.next() * 2.0)
		for _run: int in runs:
			var length: int = 3 + floori(rng.next() * 4.0)
			var start: int = hire[i] + floori(rng.next() * float(maxi(1, served - length)))
			for day: int in range(start, mini(span, start + length)):
				mercs[i]["vac"][day] = 1.0


func _seed_levels(mercs: Array[Dictionary], hire: Array[int], span: int) -> void:
	for i: int in mercs.size():
		var served: int = span - hire[i]
		var start: int = maxi(1, LEVELS[i] - maxi(1, int(served / 90.0)))
		var total: float = 0.0
		for day: int in range(hire[i], span):
			total += mercs[i]["xp"][day]
		var gained: float = 0.0
		for day: int in range(hire[i], span):
			gained += mercs[i]["xp"][day]
			mercs[i]["level"][day] = float(start
				+ floori(float(LEVELS[i] - start) * gained / (total if total != 0.0 else 1.0)))


func _store_preview(guild: Dictionary, types: Array[Dictionary], mercs: Array[Dictionary],
		span: int, type_names: Array[String], uids: Array[int] = []) -> void:
	var tags: Array[String] = []
	for i: int in mercs.size():
		tags.append(str(uids[i]) if i < uids.size() else str(i))
	var type_tags: Array[String] = []
	for t: int in types.size():
		type_tags.append(type_names[t] if t < type_names.size() else str(t + 1))
	for day: int in span:
		var guild_row: Dictionary = {}
		for key: String in guild:
			guild_row[key] = float(guild[key][day])
		var merc_row: Dictionary = {}
		for i: int in mercs.size():
			for key: String in mercs[i]:
				merc_row["%s/%s" % [tags[i], key]] = float(mercs[i][key][day])
		var contract_row: Dictionary = {}
		for t: int in types.size():
			for key: String in types[t]:
				var value: float = float(types[t][key][day])
				contract_row["%s/%s" % [type_tags[t], key]] = value
				contract_row[key] = float(contract_row.get(key, 0.0)) + value
		(_preview_rows["Merc"] as Array[Dictionary]).append(merc_row)
		(_preview_rows["Contract"] as Array[Dictionary]).append(contract_row)
		(_preview_rows["Guild"] as Array[Dictionary]).append(guild_row)
	_preview_first = 0


static func _add_event(row: Dictionary, key: String, day: int, value: float) -> void:
	row[key][day] += value
	row[key + "_n"][day] += 1.0


func _append(source: String, callable: Callable, day_index: int) -> void:
	var row: Dictionary = {}
	if callable.is_valid():
		row = callable.call(day_index)
	(_rows[source] as Array[Dictionary]).append(row)


static func _cell(row: Dictionary, key: String) -> float:
	return float(row.get(key, 0.0))


#The aggregation of the metric behind a stored key; the "<uid>/" or "<type>/" prefix is dropped.
func _agg_for(source: String, key: String) -> String:
	var bare: String = key.substr(key.rfind("/") + 1)
	for def: MetricDef in defs:
		if def.source == source and def.key == bare:
			return def.agg
	return "SUM"


func _build_defs() -> Array[MetricDef]:
	var out: Array[MetricDef] = []
	for row: Array in [
		["salary", "Salary", "Merc", "LAST", true,
			"The monthly wage this merc was owed on the last day of the bucket.", "money"],
		["xp", "Experience Gain", "Merc", "SUM", false,
			"Experience this merc earned over the bucket, from contracts and from daily gain.", "int"],
		["level", "Level", "Merc", "LAST", true,
			"The level this merc held on the last day of the bucket.", "int"],
		["wins", "Successful Contracts", "Merc", "SUM", true,
			"Contracts this merc worked that the guild completed successfully in the bucket.", "int"],
		["losses", "Failed Contracts", "Merc", "SUM", false,
			"Contracts this merc worked that ended in failure in the bucket.", "int"],
		["sRoll", "Successes Rolled (Avg / Contract)", "Merc", "EVENT_AVG", false,
			"Successes this merc rolled per contract worked, averaged over the bucket.", "float"],
		["fRoll", "Failures Rolled (Avg / Contract)", "Merc", "EVENT_AVG", false,
			"Failures this merc rolled per contract worked, averaged over the bucket.", "float"],
		["kills", "Enemies Defeated", "Merc", "SUM", false,
			"Enemies this merc put down over the bucket.", "int"],
		["op", "Guild Opinion", "Merc", "AVG", false,
			"How this merc felt about the guild, averaged over the bucket, from -5 to 5.", "op",
			"guildOpinion", "survey"],
		["vac", "Vacation Days Taken", "Merc", "SUM", false,
			"Days this merc spent on vacation over the bucket.", "int"],
		["count", "Contract #", "Contract", "SUM", true,
			"Contracts of the selected types the guild took on over the bucket.", "int"],
		["wins", "Successful Contracts", "Contract", "SUM", true,
			"Contracts of the selected types the guild completed successfully in the bucket.", "int"],
		["losses", "Failed Contracts", "Contract", "SUM", true,
			"Contracts of the selected types the guild failed in the bucket.", "int"],
		["i1", "Issuer Type 1", "Contract", "SUM", false,
			"Contracts in the bucket handed out by an issuer of the first type.", "int"],
		["i2", "Issuer Type 2", "Contract", "SUM", false,
			"Contracts in the bucket handed out by an issuer of the second type.", "int"],
		["i3", "Issuer Type 3", "Contract", "SUM", false,
			"Contracts in the bucket handed out by an issuer of the third type.", "int"],
		["i4", "Issuer Type 4", "Contract", "SUM", false,
			"Contracts in the bucket handed out by an issuer of the fourth type.", "int"],
		["diff", "Average Difficulty", "Contract", "EVENT_AVG", false,
			"Average difficulty of the contracts taken in the bucket, on the half star scale.",
			"float"],
		["reward", "Average Reward", "Contract", "EVENT_AVG", false,
			"Average coin paid out per contract taken in the bucket.", "money"],
		["expense", "Average Expense", "Contract", "EVENT_AVG", false,
			"Average coin the guild spent per contract taken in the bucket.", "money"],
		["time", "Average Time (incl. Travel)", "Contract", "EVENT_AVG", false,
			"Average days a contract took in the bucket, travel time included.", "float"],
		["bank", "Guild Bank Value", "Guild", "LAST", true,
			"Coin in the guild bank on the last day of the bucket.", "money"],
		["exp", "Guild Expenses", "Guild", "SUM", true,
			"Coin the guild paid out over the bucket, wages and contract costs together.", "money"],
		["count", "Mercenary #", "Guild", "LAST", false,
			"Mercs on the roster on the last day of the bucket.", "int"],
		["dead", "Merc Casualties", "Guild", "SUM", false,
			"Mercs the guild lost over the bucket.", "int"],
		["mop", "Merc Guild Opinion", "Guild", "AVG", false,
			"How the roster felt about the guild, averaged over the bucket, from -5 to 5.", "op",
			"guildOpinion", "survey"],
		["cop", "Client Guild Opinion", "Guild", "AVG", false,
			"How clients felt about the guild, averaged over the bucket, from -5 to 5.", "op",
			"clientOpinion", "customer"],
		["port", "Investment Portfolio", "Guild", "LAST", false,
			"Market value of the guild's held shares at the close of the bucket's last day.",
			"money"],
	]:
		var lock_text: String = str(row[7]) if row.size() > 7 else ""
		var upgrade_text: String = str(row[8]) if row.size() > 8 else ""
		out.append(MetricDef.make(str(row[0]), str(row[1]), str(row[2]), str(row[3]), bool(row[4]),
			str(row[5]), str(row[6]), lock_text, upgrade_text))
	return out
