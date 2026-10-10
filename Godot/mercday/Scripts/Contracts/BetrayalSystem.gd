class_name BetrayalSystem

#Before an NPC battle a qualifying merc may switch sides; after the first betrayal a campaign gate roll comes first.

#Test hook: each entry is popped as the next d100 before any random roll.
static var forced_rolls: Array[int] = []
#Campaign tallies for this process: betrayals so far and the gate percent that lets a roll happen at all.
static var betrayals: int = 0
static var gate_percent: float = 0.0


static func reset() -> void:
	forced_rolls.clear()
	betrayals = 0
	gate_percent = 0.0


static func _standing(merc: MercenaryData) -> bool:
	return merc != null and not merc.is_dead and merc.current_hp > 0 \
		and not ConstStates.has_state(merc, ConstStates.DYING)


static func qualifies(merc: MercenaryData, run: ContractRun) -> bool:
	if not _standing(merc):
		return false
	var cfg: ContractConfig = ContractLibrary.config()
	var u: float = float(merc.stats.get("unsavory", 0.0))
	if u >= cfg.betrayal_unsavory_bar:
		return true
	if run != null and run.contract != null and run.contract.unsavory and u < cfg.betrayal_clean_max:
		return true
	return false


#Split the way OpponentGenerator reads a crew cell: comma terms, each stripped.
static func is_npc_battle(event: EventData) -> bool:
	if event == null or not event.is_battle():
		return false
	var cell: String = event.enemy.strip_edges()
	if cell == "":
		return false
	if cell == "Mercs":
		return true
	for raw: String in cell.split(","):
		var term: String = raw.strip_edges()
		if term == "" or not DataManager.npc_templates.has(term):
			return false
	return true


static func should_run(event: EventData, opts: Dictionary) -> bool:
	return bool(opts.get("betrayal", true)) and is_npc_battle(event)


static func run_pre_battle(run: ContractRun, state: BattleState, roster: Array[MercenaryData]) -> Array[MercenaryData]:
	var switched: Array[MercenaryData] = []
	var cands: Array[MercenaryData] = []
	for merc: MercenaryData in roster:
		if qualifies(merc, run):
			cands.append(merc)
	if cands.is_empty():
		return switched
	cands.shuffle()
	var cfg: ContractConfig = ContractLibrary.config()
	var gated: bool = betrayals > 0
	if gated:
		var g: int = Dice.d100(forced_rolls)
		var open: bool = float(g) <= gate_percent
		_say(run, state, "BETRAYAL GATE: d100 %d vs %.0f%% -> %s" % [g, gate_percent, "open" if open else "shut"])
		if not open:
			return switched
	var luck: float = PartyStats.average_stat(roster, "luck")
	var attempted: int = 0
	for merc: MercenaryData in cands:
		var standing: int = -switched.size()
		for m: MercenaryData in roster:
			if _standing(m):
				standing += 1
		if standing < 2:
			_say(run, state, "BETRAYAL SKIPPED: %s (no loyal merc would remain)" % merc.merc_name)
			continue
		attempted += 1
		var u: float = float(merc.stats.get("unsavory", 0.0))
		var threshold: float = luck - u
		var r: int = Dice.d100(forced_rolls)
		var fires: bool = float(r) > threshold
		_say(run, state, "BETRAYAL ROLL: %s d100 %d vs Luck %.1f minus Unsavory %.1f = %.1f -> %s" % [
			merc.merc_name, r, luck, u, threshold, "betrays" if fires else "holds"])
		if not fires:
			continue
		state.switch_team(merc)
		switched.append(merc)
		if not run.betrayers.has(merc):
			run.betrayers.append(merc)
		run.add_event_mark("Betrayal")
		_say(run, state, "BETRAYAL: %s turns on the party!" % merc.merc_name)
	if not switched.is_empty():
		betrayals += switched.size()
		gate_percent = cfg.betrayal_gate_start
	elif gated and attempted > 0:
		gate_percent = minf(cfg.betrayal_gate_cap, gate_percent * 2.0)
		_say(run, state, "BETRAYAL GATE: every roll held, next gate %.0f%%" % gate_percent)
	return switched


#run.emit prints and logs the line now; AutoBattle.setup writes pre_battle_lines to the encounter log after the spawns.
static func _say(run: ContractRun, state: BattleState, line: String) -> void:
	run.emit(line)
	state.pre_battle_lines.append(line)


static func foes(enemies: Array[MercenaryData], state: BattleState) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	out.assign(enemies)
	for merc: MercenaryData in state.defected:
		if not out.has(merc):
			out.append(merc)
	return out


static func loyal(roster: Array[MercenaryData], state: BattleState) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	for merc: MercenaryData in roster:
		if not state.defected.has(merc):
			out.append(merc)
	return out


#A dead traitor is still in the roster, so it counts as a casualty of the party.
static func dead_of(state: BattleState, roster: Array[MercenaryData]) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	for merc: MercenaryData in state.casualties:
		if roster.has(merc):
			out.append(merc)
	return out


#Moves every living traitor still on the team to run.defectors; returns the lines for the resolver to emit.
#A defector leaves before BattleEventResolver.stabilize reads the team, so settle stabilizes it here.
static func settle(run: ContractRun, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	var switched: Array[MercenaryData] = []
	switched.assign(state.defected)
	for merc: MercenaryData in switched:
		if merc == null or merc.is_dead or state.casualties.has(merc) or not run.team.has(merc):
			continue
		if merc.current_hp <= 0:
			BattleEventResolver.stabilize_merc(merc)
		lines.append_array(run.depart(merc, run.defectors))
		lines.append("DEFECTED: %s" % merc.merc_name)
	return lines
