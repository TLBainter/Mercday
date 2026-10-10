class_name SimReport
#Playability sim output: header, one row per calendar week, the value band table and the threshold table.

const ROW_HEAD: String = "WEEK  day  verdict  wk_gen  bank  mercs  avg_lvl  open  gen  prov  pool_exp  auto_rej  rej  won  lost  dead"


static func header_lines(days: int, seed_value: int, plan_name: String) -> Array[String]:
	var out: Array[String] = ["PLAYABILITY SIM: days=%d seed=%d plan=%s" % [days, seed_value, plan_name]]
	var tuned: Array[String] = GenTune.report_lines()
	if tuned.is_empty():
		out.append("GEN SET: none")
	else:
		out.append_array(tuned)
	out.append("pinned rows: none")
	out.append(ROW_HEAD)
	return out


#One week row; verdict is "ok", "LOW" or "partial", counts cumulative, the rest point values at the sample.
static func row(c: Dictionary, week_key: int, day_no: int, verdict: String) -> String:
	var bank: Array = c["bank"]
	return "%s  %d  %s  %d  %d  %d  %.1f  %d  %d  %d  %d  %d  %d  %d  %d  %d" % [_week_label(week_key), day_no, verdict,
		SimCounters.week_generated(c, week_key), int(bank[bank.size() - 1]) if not bank.is_empty() else 0,
		SimCounters.living_mercs().size(), SimCounters.mean_level(),
		SimCounters.open_postings(GameState.board).size(), int(c["generated"]), int(c["provisioned"]),
		int(c["pool_expired"]), int(c["auto_rejected"]), int(c["rejected"]), int(c["succeeded"]), int(c["failed"]),
		int(c["deaths"])]


static func _week_label(week_key: int) -> String:
	var minute: int = week_key * TrynnCalendar.WEEKDAYS.size() * TrynnCalendar.MINUTES_PER_DAY
	var date: Dictionary = TrynnCalendar.date_of(minute)
	return "%s_%d-%d" % [str(date["month_name"]), int(date["day"]), int(date["day"]) + TrynnCalendar.WEEKDAYS.size() - 1]


static func band_of(level: float) -> int:
	var lvl: int = maxi(1, roundi(level))
	for i: int in SimThresholds.BANDS.size():
		var band: Vector2i = SimThresholds.BANDS[i]
		if lvl >= band.x and (lvl <= band.y or i == SimThresholds.BANDS.size() - 1):
			return i
	return 0


#Per band {name, n, mean, anchor, delta, mean_q, mean_km}; anchor is GenValue.anchor at the band's mean level.
static func band_rows(values: Array, levels: Array, qualities: Array = [], kms: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in SimThresholds.BANDS.size():
		var band: Vector2i = SimThresholds.BANDS[i]
		var name: String = "%d+" % band.x if i == SimThresholds.BANDS.size() - 1 else "%d-%d" % [band.x, band.y]
		out.append({"name": name, "n": 0, "sum": 0.0, "level_sum": 0.0, "mean": 0.0, "anchor": 0.0, "delta": 0.0,
			"q_sum": 0.0, "km_sum": 0.0, "mean_q": 0.0, "mean_km": 0.0})
	for k: int in mini(values.size(), levels.size()):
		var row: Dictionary = out[band_of(float(levels[k]))]
		row["n"] = int(row["n"]) + 1
		row["sum"] = float(row["sum"]) + float(values[k])
		row["level_sum"] = float(row["level_sum"]) + float(levels[k])
		row["q_sum"] = float(row["q_sum"]) + (float(qualities[k]) if k < qualities.size() else 0.0)
		row["km_sum"] = float(row["km_sum"]) + (float(kms[k]) if k < kms.size() else 0.0)
	for row: Dictionary in out:
		var n: int = int(row["n"])
		if n <= 0:
			continue
		row["mean"] = float(row["sum"]) / float(n)
		row["mean_q"] = float(row["q_sum"]) / float(n)
		row["mean_km"] = float(row["km_sum"]) / float(n)
		row["anchor"] = GenValue.anchor(roundi(float(row["level_sum"]) / float(n)))
		if float(row["anchor"]) > 0.0:
			row["delta"] = (float(row["mean"]) - float(row["anchor"])) / float(row["anchor"])
	return out


#Longest run of consecutive zeros in a daily series.
static func longest_zero_run(series: Array) -> int:
	var best: int = 0
	var run: int = 0
	for value: Variant in series:
		run = run + 1 if int(value) == 0 else 0
		best = maxi(best, run)
	return best


#Each rule as {name, held, text}. series: bank, weeks ({gen, partial}), roster_open, mercs, succeeded, failed,
#values, levels; every list is per sample or per run day.
static func thresholds(series: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var bank: Array = series["bank"]
	var low: int = bank.min() if not bank.is_empty() else SimThresholds.BANK_FLOOR
	out.append(_rule("BANK_FLOOR %d" % SimThresholds.BANK_FLOOR, low >= SimThresholds.BANK_FLOOR,
		"lowest sample %d" % low))
	var full: int = 0
	var short: int = 0
	for week: Dictionary in (series["weeks"] as Array):
		if bool(week["partial"]):
			continue
		full += 1
		if int(week["gen"]) < SimThresholds.GEN_MIN_PER_WEEK:
			short += 1
	out.append(_rule("GEN_MIN_PER_WEEK %d" % SimThresholds.GEN_MIN_PER_WEEK, short == 0,
		"%d of %d full weeks short" % [short, full] if full > 0 else "n/a (no full week)"))
	var empty_run: int = longest_zero_run(series["roster_open"])
	out.append(_rule("ROSTER_EMPTY_MAX_DAYS %d" % SimThresholds.ROSTER_EMPTY_MAX_DAYS,
		empty_run <= SimThresholds.ROSTER_EMPTY_MAX_DAYS, "longest empty run %d days" % empty_run))
	var won: int = int(series["succeeded"])
	var settled: int = won + int(series["failed"])
	var rate: float = float(won) / float(settled) if settled > 0 else 0.0
	var rate_ok: bool = settled < SimThresholds.SUCCESS_MIN_SETTLED \
		or (rate >= SimThresholds.SUCCESS_LO and rate <= SimThresholds.SUCCESS_HI)
	out.append(_rule("SUCCESS %d%%-%d%%" % [roundi(SimThresholds.SUCCESS_LO * 100.0), roundi(SimThresholds.SUCCESS_HI * 100.0)],
		rate_ok, "n/a (%d settled)" % settled if settled < SimThresholds.SUCCESS_MIN_SETTLED
		else "%d of %d settled = %d%%" % [won, settled, roundi(rate * 100.0)]))
	var mercs: Array = series["mercs"]
	var mercs_text: String = "n/a (run shorter than %d days)" % SimThresholds.MERCS_BY_DAY
	var mercs_ok: bool = true
	if mercs.size() >= SimThresholds.MERCS_BY_DAY:
		var most: int = mercs.slice(0, SimThresholds.MERCS_BY_DAY).max()
		mercs_ok = most >= SimThresholds.MERCS_TARGET
		mercs_text = "most by day %d: %d" % [SimThresholds.MERCS_BY_DAY, most]
	out.append(_rule("MERCS %d by day %d" % [SimThresholds.MERCS_TARGET, SimThresholds.MERCS_BY_DAY], mercs_ok, mercs_text))
	var off: Array[String] = []
	var checked: int = 0
	for row: Dictionary in band_rows(series["values"], series["levels"]):
		if int(row["n"]) < SimThresholds.BAND_MIN_SAMPLES:
			continue
		checked += 1
		if absf(float(row["delta"])) > SimThresholds.BAND_TOLERANCE:
			off.append("%s %+d%%" % [str(row["name"]), roundi(float(row["delta"]) * 100.0)])
	out.append(_rule("BAND_TOLERANCE %d%%" % roundi(SimThresholds.BAND_TOLERANCE * 100.0), off.is_empty(),
		"n/a (no band with %d samples)" % SimThresholds.BAND_MIN_SAMPLES if checked == 0
		else ("%d bands checked" % checked if off.is_empty() else ", ".join(off))))
	return out


static func _rule(name: String, held: bool, text: String) -> Dictionary:
	return {"name": name, "held": held, "text": text}


static func series_of(c: Dictionary) -> Dictionary:
	return {"bank": c["bank"], "weeks": c["weeks"], "roster_open": c["roster_open"], "mercs": c["mercs"],
		"succeeded": c["succeeded"], "failed": c["failed"], "values": c["values"], "levels": c["levels"]}


#Prints the band and threshold tables and the summary line; true when every threshold held.
static func finish(c: Dictionary) -> bool:
	print("BAND  samples  mean  anchor  delta  mean_q  mean_km")
	for row: Dictionary in band_rows(c["values"], c["levels"], c["qualities"], c["kms"]):
		var n: int = int(row["n"])
		if n < SimThresholds.BAND_MIN_SAMPLES:
			print("%s  %d  n/a" % [str(row["name"]), n])
		else:
			print("%s  %d  %.1f  %.1f  %+d%%  %.2f  %.1f" % [str(row["name"]), n, float(row["mean"]), float(row["anchor"]),
				roundi(float(row["delta"]) * 100.0), float(row["mean_q"]), float(row["mean_km"])])
	print("THRESHOLD  held  detail")
	var rules: Array[Dictionary] = thresholds(series_of(c))
	var held: int = 0
	for rule: Dictionary in rules:
		held += 1 if bool(rule["held"]) else 0
		print("%s  %s  %s" % [str(rule["name"]), "yes" if bool(rule["held"]) else "NO", str(rule["text"])])
	print(("POLICY: dispatched=%d hired=%d tiers=%d plan_switches=%d posted_signal=%d evaluated=%d no_pool=%d"
		+ " no_team=%d low_p=%d no_fare=%d dispatch_failed=%d p_max=%.2f") % [int(c["dispatched"]), int(c["hired"]),
		int(c["tiers"]), int(c["switches"]), int(c["posted"]), int(c["evaluated"]), int(c["no_pool"]),
		int(c["no_team"]), int(c["low_p"]), int(c["no_fare"]), int(c["dispatch_failed"]), float(c["p_max"])])
	print("PLAYABILITY SUMMARY: %d/%d thresholds held" % [held, rules.size()])
	return held == rules.size()
