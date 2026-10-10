class_name CheckEventResolver
extends RefCounted

#Resolves a "check:" primary event from its Checks.tsv row: roller, boosts, rival, retries, consequences and Time.

const _MAX_KEYS: Dictionary = {
	"hp": "maximum_hit_points",
	"ep": "maximum_endurance_points",
	"mp": "maximum_magic_points",
}


static func resolve(event: EventData, contract_run: ContractRun, role: String = "") -> Dictionary:
	var out: Dictionary = EventRunner.outcome(event)
	var bare: String = CheckStore.bare_name(event.event_name)
	var consequences: Array[String] = []
	out["check"] = bare
	out["roller"] = -1
	out["successes"] = 0
	out["needed"] = 0
	out["attempts"] = 0
	out["rival_successes"] = -1
	out["consequences"] = consequences
	out["minutes"] = 0
	var parsed: Dictionary = CheckStore.parse(CheckStore.find(event.event_name))
	if parsed.is_empty():
		contract_run.emit("CHECK MISSING: %s" % bare)
		return out
	var team: Array[MercenaryData] = contract_run.living_team()
	if team.is_empty():
		contract_run.emit("CHECK: no merc can attempt %s" % bare)
		contract_run.add_event_mark(bare)
		return out
	var multiplier: float = float(parsed["multiplier"])
	var minutes: int = int(parsed["minutes"])
	var points: float = CheckStore.difficulty_points(contract_run.contract)
	var def: Dictionary = CheckStore.check_def(parsed, points)
	var leader: MercenaryData = contract_run.leader()
	var pool: Array[MercenaryData] = team
	if role != "":
		var held: Array[MercenaryData] = contract_run.holders(role)
		if held.is_empty():
			contract_run.emit("CHECK: no living %s for %s, best suited rolls" % [role, bare])
		else:
			pool = held
	var roller: MercenaryData = CheckStore.rank_roller(pool, parsed, leader, points)
	contract_run.emit("CHECK: %s roller %s (attributes %s, multiplier %.1f, time %d min)" % [
		bare, roller.merc_name, ", ".join(PackedStringArray(parsed["attributes"])), multiplier, minutes])
	var stars: float = contract_run.contract.difficulty if contract_run.contract != null else 0.0
	contract_run.emit("CHECK DIFFICULTY: %.1f stars %+.1f points" % [stars, points])

	var info: Dictionary = OverallSuccess.for_merc(contract_run.contract, team, roller, event, leader)
	var base0: float = float(info["base"])
	var delta_a: float = float(info["delta"])
	OverallSuccess.apply_delta(roller, delta_a)
	contract_run.emit(OverallSuccess.describe(roller, info))
	var record: Dictionary = CheckStore.apply_boosts(roller, parsed, base0, delta_a)
	contract_run.emit_all(record["lines"])

	var needed: int = CheckStore.needed(multiplier)
	if bool(parsed["opposed"]):
		var rival: MercenaryData = CheckStore.make_rival(team, contract_run.contract)
		if rival == null:
			contract_run.emit("CHECK RIVAL: none")
		else:
			var rival_roll: Dictionary = CheckSystem.make_check(rival, CheckStore.rival_def(parsed))
			var rival_successes: int = int(rival_roll["successes"])
			out["rival_successes"] = rival_successes
			needed = CheckStore.opposed_needed(rival_successes, multiplier)
			contract_run.emit("CHECK RIVAL: %s rolls %d successes; %s needs %d" % [
				rival.merc_name, rival_successes, roller.merc_name, needed])

	var raw: float = CheckSystem.threshold_for(roller, def)
	var first: Dictionary = CheckSystem.make_check(roller, def)
	var roll: Dictionary = first
	var attempts: int = 1
	var passed: bool = _passes(roll, needed)
	contract_run.emit("CHECK ROLL 1: %s %s %s" % [roller.merc_name, roll["stat_used"], _roll_text(roll, needed, passed)])
	var contract_cc: Dictionary = CheckSheet.parse_consequence(
		contract_run.contract.consequence if contract_run.contract != null and contract_run.contract.style != "timeline"
			else "")
	var row_cc: Dictionary = parsed["consequence"]
	var retries: int = absi(int(row_cc.get("retry", 0))) + absi(int(contract_cc.get("retry", 0)))
	if not passed and retries > 0:
		var half: Dictionary = CheckStore.half_def(def, raw, float(first["threshold"]))
		var i: int = 0
		while not passed and i < retries:
			i += 1
			roll = CheckSystem.make_check(roller, half)
			attempts += 1
			passed = _passes(roll, needed)
			contract_run.emit("CHECK RETRY %d/%d: %s %s" % [i, retries, roller.merc_name,
				_roll_text(roll, needed, passed)])

	contract_run.emit_all(CheckStore.revert_boosts(record))
	OverallSuccess.revert_event_delta({roller: delta_a})

	if not passed:
		fire_consequences(contract_run, roller, row_cc, "CHECK CONSEQUENCE:", consequences)
		fire_consequences(contract_run, roller, contract_cc, "CONTRACT CONSEQUENCE:", consequences)

	out["success"] = passed
	out["winner"] = roller.merc_uid
	out["roller"] = roller.merc_uid
	out["successes"] = int(roll["successes"])
	out["needed"] = needed
	out["attempts"] = attempts
	out["rounds"] = attempts
	out["minutes"] = minutes * attempts
	contract_run.add_event_mark(bare)
	contract_run.emit("CHECK RESULT: %s %s after %d attempt(s), %d minutes" % [
		bare, "SUCCESS" if passed else "FAILED", attempts, minutes * attempts])
	return out


#A critical auto-passes whatever the count.
static func _passes(roll: Dictionary, needed: int) -> bool:
	return int(roll["successes"]) >= needed or bool(roll.get("critical", false))


static func _roll_text(roll: Dictionary, needed: int, passed: bool) -> String:
	return "%d/%d successes, threshold %.1f%s -> %s" % [int(roll["successes"]), needed, float(roll["threshold"]),
		" CRITICAL" if bool(roll.get("critical", false)) else "", "PASS" if passed else "FAIL"]


#One consequence set in CONSEQUENCE_KINDS order; retry is spent by the caller; a null roller skips hp, ep and mp.
static func fire_consequences(contract_run: ContractRun, roller: MercenaryData, values: Dictionary, prefix: String,
		into: Array[String]) -> void:
	for kind: String in CheckSheet.CONSEQUENCE_KINDS:
		var n: int = int(values.get(kind, 0))
		if kind == "retry" or n == 0:
			continue
		if roller == null and kind != "guild":
			continue
		var lines: Array[String] = []
		if kind == "guild":
			var living: Array[MercenaryData] = contract_run.living_team()
			lines.append("%s guild opinion %d for %d mercs" % [prefix, n, living.size()])
			for merc: MercenaryData in living:
				var old: int = merc.guild_opinion
				var now: int = SalarySystem.adjust_opinion(merc, n)
				lines.append("%s %s guild opinion %d -> %d" % [prefix, merc.merc_name, old, now])
		else:
			lines.append("%s %s" % [prefix, _drain(roller, kind, n)])
		for line: String in lines:
			contract_run.emit(line)
			into.append(line)


#Takes a tenth of the maximum per point (at least 1); HP stops at 1, EP and MP at 0.
static func _drain(merc: MercenaryData, kind: String, n: int) -> String:
	var label: String = kind.to_upper()
	var maximum: int = int(merc.stats.get(_MAX_KEYS[kind], 0))
	if maximum <= 0:
		return "%s %s none (no maximum)" % [merc.merc_name, label]
	var loss: int = maxi(1, ceili(maximum * absi(n) / 10.0))
	var floor_value: int = 1 if kind == "hp" else 0
	var old: int = _current(merc, kind)
	var now: int = maxi(mini(floor_value, old), old - loss)
	match kind:
		"hp":
			merc.current_hp = now
		"ep":
			merc.current_ep = now
		"mp":
			merc.current_mp = now
	return "%s loses %d %s (%d -> %d)" % [merc.merc_name, loss, label, old, now]


static func _current(merc: MercenaryData, kind: String) -> int:
	match kind:
		"hp":
			return merc.current_hp
		"ep":
			return merc.current_ep
	return merc.current_mp
