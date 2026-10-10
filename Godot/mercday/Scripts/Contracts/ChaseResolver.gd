class_name ChaseResolver

#Resolves a "Chase" event: mean side speeds, a closing gap from the area size, caught or escaped.

const DEFAULT_GAP := 18.0
const ROUNDS := 20
const FOOT_MARK := "Foot Chase"
const VEHICLE_MARK := "Vehicle Chase"
const KM_PER_SPEED := 30.0
const RESULT_CAUGHT := "caught"
const RESULT_ESCAPED := "escaped"

#Test override for the other side of the chase; reset() clears it.
static var forced_target: Array[MercenaryData] = []


static func run(contract_run: ContractRun, event: EventData, contract: ContractData) -> Dictionary:
	var out: Dictionary = EventRunner.outcome(event)
	if contract_run == null or event == null:
		return out
	var cell: String = contract_run.event_config() if contract == contract_run.contract else (
		contract.event_config if contract != null else "")
	var mode: String = EventConfig.choice_value(event.event_name, "chase", cell)
	var chasing: String = EventConfig.choice_value(event.event_name, "chasing", cell)
	var mercs_chase: bool = chasing != "target"
	var mercs: Array[MercenaryData] = contract_run.living_team()
	if mercs.is_empty():
		contract_run.emit("CHASE: no mercs standing")
		return out
	var targets: Array[MercenaryData] = []
	if not forced_target.is_empty():
		targets.assign(forced_target)
	else:
		targets.assign(OpponentGenerator.generate(ContractTarget.request(
			contract.target if contract != null else "", mercs, contract)))
	if targets.is_empty():
		contract_run.emit("CHASE: no target generated")
		out["winner"] = 1
		return out
	var bonus: float = vehicle_bonus(contract_run, mode)
	var gap: float = start_gap(contract_run, contract)
	var merc_speed: float = side_speed(mercs, bonus)
	var target_speed: float = side_speed(targets, bonus)
	var sim: Dictionary = simulate(gap, merc_speed if mercs_chase else target_speed,
		target_speed if mercs_chase else merc_speed)
	var result: String = String(sim["result"])
	var success: bool = result == RESULT_CAUGHT if mercs_chase else result == RESULT_ESCAPED
	var gaps: Array[float] = []
	gaps.assign(sim["gaps"])
	contract_run.emit("CHASE START: %s mode %s, %s chasing, start gap %.1f" % [event.event_name, mode, chasing, gap])
	contract_run.emit("CHASE SIDES: mercs %d at %.2f, target %d at %.2f (bonus %.2f)" % [mercs.size(), merc_speed,
		targets.size(), target_speed, bonus])
	for t: MercenaryData in targets:
		contract_run.emit("CHASE TARGET: %s" % ContractLog.merc_line(t))
	for i: int in range(gaps.size()):
		contract_run.emit("CHASE ROUND %d: gap %.1f" % [i + 1, gaps[i]])
	contract_run.emit("CHASE RESULT: %s after %d rounds%s -> %s" % [result, int(sim["rounds"]),
		" (timed out)" if bool(sim["timed_out"]) else "", "SUCCESS" if success else "FAIL"])
	contract_run.add_event_mark(VEHICLE_MARK if mode == "vehicle" else FOOT_MARK)
	out["success"] = success
	out["winner"] = 0 if success else 1
	out["rounds"] = int(sim["rounds"])
	out["enemies"] = contract_run.merc_names(targets)
	out["enemy_count"] = targets.size()
	out["chase"] = {
		"mode": mode,
		"chasing": chasing,
		"start_gap": gap,
		"merc_speed": merc_speed,
		"target_speed": target_speed,
		"bonus": bonus,
		"result": result,
		"timed_out": bool(sim["timed_out"]),
		"gaps": gaps,
	}
	return out


#The gap closes by the speed difference each round: 0 or less is caught, double the start is escaped.
static func simulate(gap0: float, chaser_speed: float, chased_speed: float, rounds: int = ROUNDS) -> Dictionary:
	var gaps: Array[float] = []
	if gap0 <= 0.0:
		return {"result": RESULT_CAUGHT, "rounds": 0, "gaps": gaps, "timed_out": false}
	var gap: float = gap0
	for r: int in range(1, rounds + 1):
		gap += chased_speed - chaser_speed
		gaps.append(gap)
		if gap <= 0.0:
			return {"result": RESULT_CAUGHT, "rounds": r, "gaps": gaps, "timed_out": false}
		if gap >= 2.0 * gap0:
			return {"result": RESULT_ESCAPED, "rounds": r, "gaps": gaps, "timed_out": false}
	return {"result": RESULT_ESCAPED, "rounds": rounds, "gaps": gaps, "timed_out": true}


#Mean Speed plus Pace of the living members, plus bonus; 0.0 when nobody counts.
static func side_speed(members: Array, bonus: float) -> float:
	var total: float = 0.0
	var counted: int = 0
	for member: Variant in members:
		if not (member is MercenaryData):
			continue
		var merc: MercenaryData = member as MercenaryData
		if merc.is_dead:
			continue
		total += float(merc.stats.get("speed", 0)) + float(merc.stats.get("pace", 1))
		counted += 1
	if counted == 0:
		return 0.0
	return total / float(counted) + bonus


#The drawn area's Min Size, else DEFAULT_GAP.
static func start_gap(contract_run: ContractRun, contract: ContractData) -> float:
	var loc: LocationData = contract_run.location if contract_run != null else null
	var drawn: Dictionary = ContractTerrain.draw(loc, contract)
	var area: Dictionary = drawn.get("area", {})
	var gap: float = float(area.get("min_size", DEFAULT_GAP))
	return DEFAULT_GAP if gap <= 0.0 else gap


static func vehicle_bonus(contract_run: ContractRun, mode: String) -> float:
	if mode != "vehicle" or contract_run == null:
		return 0.0
	return float(GuiTypes.travel_mode(contract_run.travel_mode).get("km_per_day", 0)) / KM_PER_SPEED


static func reset() -> void:
	forced_target = []
