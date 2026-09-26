class_name AmbushBatch
extends RefCounted

#Runs a batch of Ambush events, a fresh party per event, and reports the Leadership aura numbers.

const EVENT_NAME := "Ambush"
const LEADER_PREFIX := "Bandit Leader"
const EMBOLD_MARK := " is emboldened"
const PARTY_MIN := 2
const PARTY_MAX := 5
const ROW_FMT := "%-5s %4s %6s %6s %6s %7s %7s %7s %8s %7s %7s %8s %10s"
const HEADINGS: Array = ["Diff", "N", "Party", "Crew", "Win%", "Rounds", "Cas/ev",
	"LdrLvl", "CrewLvl", "Bump%", "Emb/ev", "LdrDmg%", "LdrDeath%"]
const WIDTHS: Array = [5, 4, 6, 6, 6, 7, 7, 7, 8, 7, 7, 8, 10]

#The run's line callable counts the aura lines, so the tally cannot live in a local.
static var _embold: int = 0


static func run(host: Node, count: int) -> void:
	print("\n====== AMBUSH BATCH ======\n")
	var deck: Array[float] = TestFixtures.build_deck(count)
	print(TestFixtures.deck_line(deck))
	var places: Array[LocationData] = TestFixtures.wilderness_pool()
	if places.is_empty():
		print("AMBUSH BATCH: no wilderness location in DataManager.locations, nothing to run")
		host.get_tree().quit()
		return
	print("AMBUSH BATCH: %d wilderness locations" % places.size())
	var records: Array[Dictionary] = []
	var skipped: int = 0
	var no_battle: int = 0
	var total: int = deck.size()
	for i: int in range(total):
		TestFixtures.reset_generator_rolls()
		CampaignKnowledge.clear()
		MercPool.clear()
		FleeSystem.reset()
		var size: int = randi_range(PARTY_MIN, PARTY_MAX)
		var team: Array[MercenaryData] = []
		for j: int in range(size):
			team.append(HarnessRoster.roster_merc(j))
		if BattleHarness.betrayal_fresh:
			BetrayalSystem.reset()
		HarnessRoster.force_unsavory(team)
		BeauSystem.set_roster(team)
		GuildRoster.set_roster(team)
		var contract: ContractData = ContractGenerator.generate(ContractLibrary.config().default_contract_type)
		if contract == null:
			skipped += 1
			print("AMBUSH %s/%d SKIPPED: contract generation failed" % [TestFixtures.index(i, total), total])
			continue
		contract.difficulty = deck[i]
		var event: EventData = ContractLibrary.event(EVENT_NAME)
		if event == null:
			print("AMBUSH BATCH FAILED: event '%s' is missing, stopped after %d events" % [
				EVENT_NAME, records.size()])
			host.get_tree().quit()
			return
		#run.team is erased as mercs die, so the damage walk reads a copy of the deployed party.
		var deployed: Array[MercenaryData] = team.duplicate()
		var contract_run: ContractRun = ContractRun.new()
		contract_run.contract = contract
		contract_run.team = team
		contract_run.location = places[randi() % places.size()]
		contract_run.line_fn = _line_fn()
		_embold = 0
		var outcome: Dictionary = await EventRunner.run(event, contract_run)
		if int(outcome.get("enemy_count", 0)) <= 0:
			no_battle += 1
			print("AMBUSH %s/%d SKIPPED: no enemy crew was fielded" % [TestFixtures.index(i, total), total])
			continue
		var record: Dictionary = _measure(outcome, deployed, size, deck[i])
		record["departed"] = contract_run.departed.size()
		records.append(record)
		print(_event_line(i, total, record, outcome))
	print_report(records, skipped, no_battle)
	host.get_tree().quit()


static func _line_fn() -> Callable:
	var fn := func(s: String) -> void:
		print_rich(s)
		_note_line(s)
	return fn


#The aura logs only on the rising edge, so a count of the marks is a count of edges.
static func _note_line(s: String) -> void:
	_embold += s.count(EMBOLD_MARK)


static func _leader(enemies: Array[MercenaryData]) -> MercenaryData:
	if enemies.is_empty():
		return null
	if enemies[0] != null and enemies[0].merc_name.begins_with(LEADER_PREFIX):
		return enemies[0]
	for enemy: MercenaryData in enemies:
		if enemy != null and enemy.merc_name.begins_with(LEADER_PREFIX):
			return enemy
	return null


#One event reduced to the numbers the table and the aura section read; -1 marks nothing to measure.
static func _measure(outcome: Dictionary, deployed: Array[MercenaryData], party: int,
		difficulty: float) -> Dictionary:
	var enemies: Array[MercenaryData] = []
	var state: BattleState = null
	var switched: int = 0
	if BattleEventResolver.last_state != null:
		switched = BattleEventResolver.last_state.defected.size()
	#A non-battle route never enters resolve, so the statics would still hold the previous crew.
	if int(outcome.get("enemy_count", 0)) == BattleEventResolver.last_enemies.size() + switched:
		enemies = BattleEventResolver.last_enemies
		state = BattleEventResolver.last_state
	var leader: MercenaryData = _leader(enemies)
	var others: Array[MercenaryData] = []
	for enemy: MercenaryData in enemies:
		if enemy != null and enemy != leader:
			others.append(enemy)
	var crew_mean: float = -1.0
	if not others.is_empty():
		var levels: float = 0.0
		for enemy: MercenaryData in others:
			levels += float(enemy.stats.get("level", 0.0))
		crew_mean = levels / float(others.size())
	var leader_level: float = -1.0
	if leader != null:
		leader_level = float(leader.stats.get("level", 0.0))
	var bump: float = -1.0
	if leader != null and crew_mean > 0.0:
		bump = leader_level / crew_mean * 100.0
	var loyal: Array[MercenaryData] = []
	for merc: MercenaryData in deployed:
		if state == null or not state.defected.has(merc):
			loyal.append(merc)
	var damage: Dictionary = _damage_split(state, loyal, enemies, leader)
	var dealt: float = float(damage["total"])
	var share: float = -1.0
	var focus: float = -1.0
	if dealt > 0.0 and leader != null:
		share = float(damage["leader"]) / dealt * 100.0
		if not enemies.is_empty():
			focus = share / (100.0 / float(enemies.size()))
	var grunt_deaths: int = 0
	for enemy: MercenaryData in others:
		if enemy.is_dead:
			grunt_deaths += 1
	var casualties: int = 0
	var dead: Variant = outcome.get("casualties", [])
	if dead is Array:
		casualties = (dead as Array).size()
	var grunts_fled: int = 0
	var party_fled: int = 0
	if state != null:
		for enemy: MercenaryData in others:
			if state.escaped.has(enemy):
				grunts_fled += 1
		for merc: MercenaryData in loyal:
			if state.escaped.has(merc):
				party_fled += 1
	return {
		"difficulty": difficulty,
		"party": party - switched,
		"switched": switched,
		"crew": enemies.size(),
		"grunts": others.size(),
		"grunt_deaths": grunt_deaths,
		"win": bool(outcome.get("success", false)),
		"rounds": int(outcome.get("rounds", 0)),
		"casualties": casualties,
		"leader": leader != null,
		"leader_level": leader_level,
		"leader_died": leader != null and leader.is_dead,
		"crew_mean": crew_mean,
		"bump": bump,
		"embold": _embold,
		"share": share,
		"focus": focus,
		"leader_fled": leader != null and state != null and state.escaped.has(leader),
		"grunts_fled": grunts_fled,
		"party_fled": party_fled,
		"flee_checks": FleeSystem.checks_rolled,
		"withdraws": FleeSystem.withdraws,
	}


#Only the deployed mercs count as attackers, and only the ambush crew counts as targets.
static func _damage_split(state: BattleState, deployed: Array[MercenaryData],
		enemies: Array[MercenaryData], leader: MercenaryData) -> Dictionary:
	var out: Dictionary = {"leader": 0.0, "total": 0.0}
	if state == null:
		return out
	for attacker: MercenaryData in state.damage_dealt_total.keys():
		if attacker == null or not deployed.has(attacker):
			continue
		var by_target: Dictionary = state.damage_dealt_total[attacker]
		for target: MercenaryData in by_target.keys():
			if target == null or not enemies.has(target):
				continue
			var amount: float = float(by_target[target])
			out["total"] = float(out["total"]) + amount
			if leader != null and target == leader:
				out["leader"] = float(out["leader"]) + amount
	return out


static func _event_line(i: int, total: int, record: Dictionary, outcome: Dictionary) -> String:
	var leader_txt: String = "none"
	if bool(record["leader"]):
		leader_txt = "L%d" % int(roundf(float(record["leader_level"])))
	var crew_txt: String = "n/a"
	if float(record["crew_mean"]) >= 0.0:
		crew_txt = "L%.1f" % float(record["crew_mean"])
	var line: String = "AMBUSH %s/%d D%.1f party %d crew %d leader %s vs %s (%s) rounds %d %s cas %d embold %d leaddmg %s" % [
		TestFixtures.index(i, total), total, float(record["difficulty"]), int(record["party"]),
		int(record["crew"]), leader_txt, crew_txt, TestFixtures.pct(float(record["bump"])),
		int(record["rounds"]), "WIN" if bool(record["win"]) else "LOSS",
		int(record["casualties"]), int(record["embold"]), TestFixtures.pct(float(record["share"]))]
	var log_file: String = String(outcome.get("log_file", ""))
	if log_file != "":
		line += " log %s" % log_file
	return line


static func print_report(records: Array[Dictionary], skipped: int, no_battle: int) -> void:
	print("\n====== AMBUSH BATCH RESULTS ======\n")
	if skipped > 0:
		print("SKIPPED: %d event(s) lost to a failed contract generation" % skipped)
	if no_battle > 0:
		print("SKIPPED: %d event(s) that never reached a battle" % no_battle)
	if records.is_empty():
		print("AMBUSH BATCH: no event completed")
		return
	print(_row(HEADINGS))
	print(_rule())
	for difficulty: float in TestFixtures.difficulties(records):
		print(_row(_stats_row("%.1f" % difficulty, TestFixtures.at_difficulty(records, difficulty))))
	print(_row(_stats_row("ALL", records)))
	_print_betrayals(records)
	_print_flee(records)
	_print_aura(records)


static func _stats_row(label: String, rows: Array[Dictionary]) -> Array:
	return [
		label,
		str(rows.size()),
		"%.1f" % TestFixtures.mean(rows, "party"),
		"%.1f" % TestFixtures.mean(rows, "crew"),
		TestFixtures.pct(TestFixtures.rate(rows, "win")),
		"%.1f" % TestFixtures.mean(rows, "rounds"),
		"%.2f" % TestFixtures.mean(rows, "casualties"),
		TestFixtures.num(TestFixtures.mean_valid(rows, "leader_level")),
		TestFixtures.num(TestFixtures.mean_valid(rows, "crew_mean")),
		TestFixtures.pct(TestFixtures.mean_valid(rows, "bump")),
		"%.1f" % TestFixtures.mean(rows, "embold"),
		TestFixtures.pct(TestFixtures.mean_valid(rows, "share")),
		TestFixtures.pct(_leader_death_rate(rows)),
	]


static func _print_betrayals(records: Array[Dictionary]) -> void:
	var events: int = 0
	var switched: int = 0
	var wins: int = 0
	for record: Dictionary in records:
		var n: int = int(record.get("switched", 0))
		if n <= 0:
			continue
		events += 1
		switched += n
		if bool(record["win"]):
			wins += 1
	print("BETRAYALS: %d events with a switch, %d mercs switched, wins with a switch %d/%d" % [
		events, switched, wins, events])


static func _print_flee(records: Array[Dictionary]) -> void:
	var checks: int = 0
	var party_fled: int = 0
	var departed: int = 0
	var leaders: int = 0
	var leaders_fled: int = 0
	var grunts: int = 0
	var grunts_fled: int = 0
	var withdraws: int = 0
	for record: Dictionary in records:
		checks += int(record.get("flee_checks", 0))
		party_fled += int(record.get("party_fled", 0))
		departed += int(record.get("departed", 0))
		if bool(record["leader"]):
			leaders += 1
		if bool(record.get("leader_fled", false)):
			leaders_fled += 1
		grunts += int(record["grunts"])
		grunts_fled += int(record.get("grunts_fled", 0))
		withdraws += int(record.get("withdraws", 0))
	print("FLEE: checks %d, party escapes %d, party departed %d, leaders fled %d/%d, grunts fled %d/%d, withdraws %d" % [
		checks, party_fled, departed, leaders_fled, leaders, grunts_fled, grunts, withdraws])


static func _print_aura(records: Array[Dictionary]) -> void:
	var embold: int = 0
	var crew_members: int = 0
	var grunts: int = 0
	var grunt_deaths: int = 0
	var alone: int = 0
	var silent: int = 0
	for record: Dictionary in records:
		embold += int(record["embold"])
		crew_members += int(record["crew"])
		grunts += int(record["grunts"])
		grunt_deaths += int(record["grunt_deaths"])
		if int(record["crew"]) == 1:
			alone += 1
		elif int(record["embold"]) == 0:
			silent += 1
	var events: int = records.size()
	print("\n--- LEADERSHIP AURA ---\n")
	print("Emboldened rising edges: %d total, %.2f per event, %.2f per crew member" % [
		embold, _div(float(embold), float(events)), _div(float(embold), float(crew_members))])
	#The leader carries the aura and can never receive it, so the followers are the reachable set.
	print("Followers the aura can reach: %d, %.2f grants per follower" % [
		grunts, _div(float(embold), float(grunts))])
	print("Leader took %s of the merc damage, even split %s, mean per-event focus %s" % [
		TestFixtures.pct(TestFixtures.mean_valid(records, "share")), TestFixtures.pct(_even_share(records)),
		TestFixtures.ratio(TestFixtures.mean_valid(records, "focus"))])
	var grunt_rate: float = -1.0
	if grunts > 0:
		grunt_rate = float(grunt_deaths) / float(grunts) * 100.0
	print("Leader death rate: %s, grunt death rate: %s (%d of %d grunts)" % [
		TestFixtures.pct(_leader_death_rate(records)), TestFixtures.pct(grunt_rate), grunt_deaths, grunts])
	print("Crew was the leader alone: %d event(s)" % alone)
	print("No grant fired with a crew of 2 or more: %d event(s)" % silent)
	print("\nENCOUNTER LOGS: %s (%s)" % [
		EncounterLogger.LOG_DIR, ProjectSettings.globalize_path(EncounterLogger.LOG_DIR)])


static func _row(cells: Array) -> String:
	return ROW_FMT % cells


static func _rule() -> String:
	var cells: Array = []
	for width: int in WIDTHS:
		cells.append("-".repeat(width))
	return _row(cells)


#Only the events that fielded a leader can report one dying.
static func _leader_death_rate(rows: Array[Dictionary]) -> float:
	var counted: int = 0
	var died: int = 0
	for record: Dictionary in rows:
		if not bool(record["leader"]):
			continue
		counted += 1
		if bool(record["leader_died"]):
			died += 1
	if counted == 0:
		return -1.0
	return float(died) / float(counted) * 100.0


#Only the events behind the printed share mean set the baseline, so the pair covers the same rows.
static func _even_share(rows: Array[Dictionary]) -> float:
	var total: float = 0.0
	var counted: int = 0
	for record: Dictionary in rows:
		var crew: int = int(record["crew"])
		if crew <= 0 or float(record["share"]) < 0.0:
			continue
		total += 100.0 / float(crew)
		counted += 1
	if counted == 0:
		return -1.0
	return total / float(counted)


static func _div(a: float, b: float) -> float:
	if b == 0.0:
		return 0.0
	return a / b
