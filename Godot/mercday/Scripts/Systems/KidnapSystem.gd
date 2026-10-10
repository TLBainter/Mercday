class_name KidnapSystem

#A losing humanoid enemy near the map edge may grab a merc and drag it off the field instead of just running.
const MARK := "Kidnapped"
const HOMINID := "hominid"
const DRAG_KEY := "_kidnap_drag_size"
const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")

static var enabled: bool = true
static var force_every: bool = false      #harness: an eligible enemy turn draws the lowest d100
static var forced_rolls: Array[int] = []  #test hook: each entry is popped as the next d100
static var rolls_made: int = 0
static var kidnaps_total: int = 0


static func reset() -> void:
	forced_rolls.clear()
	rolls_made = 0
	kidnaps_total = 0
	force_every = false
	enabled = true


static func _d100() -> int:
	if force_every and forced_rolls.is_empty():
		return 1
	return Dice.d100(forced_rolls)


static func is_humanoid(merc: MercenaryData) -> bool:
	if merc == null:
		return false
	for entry: String in merc.creature_types:
		if StateTokens.normalize_token(entry) == HOMINID:
			return true
	return false


#The number the flee d100 is rolled against: sheet plus the battle swing plus the ally spread.
static func flee_chance(merc: MercenaryData, state: BattleState) -> float:
	if merc == null:
		return 0.0
	return clampf(float(merc.stats.get("flee", 0.0)) + FleeSystem.swing(merc, state)
			+ FleeSystem.spread(merc, state), 0.0, 100.0)


#Zero for a merc the flee gate would never let roll, so it drags the team average down.
static func gate_aware_chance(merc: MercenaryData, state: BattleState) -> float:
	if merc == null:
		return 0.0
	var sheet := float(merc.stats.get("flee", 0.0))
	var sw := FleeSystem.swing(merc, state)
	if sw <= 0.0 or sheet + sw < _CONFIG.flee_gate:
		return 0.0
	return flee_chance(merc, state)


#Mean gate-aware flee chance of the living humanoid enemies; a Terrified-immune enemy is left out.
static func team_flee_average(state: BattleState, team_index: int) -> float:
	if state == null or team_index < 0 or team_index >= state.teams.size():
		return 0.0
	var team: Array = state.teams[team_index]
	var total := 0.0
	var count := 0
	for merc: MercenaryData in team:
		if not BattleState._is_alive(merc) or state.escaped.has(merc) or not is_humanoid(merc):
			continue
		if ConstStates.is_immune(merc, ConstStates.TERRIFIED):
			continue
		total += gate_aware_chance(merc, state)
		count += 1
	if count == 0:
		return 0.0
	return total / float(count)


static func team_ready(merc: MercenaryData, state: BattleState) -> bool:
	if state == null or merc == null or not state._merc_team_index.has(merc):
		return false
	return team_flee_average(state, int(state._merc_team_index[merc])) > _CONFIG.kidnap_flee_average


#1.0 on the border, 0.0 half the longer map side away from every edge.
static func edge_closeness(merc: MercenaryData, state: BattleState) -> float:
	if state == null or state.battlefield == null:
		return 1.0
	var field := state.battlefield
	var p := state.get_position(merc)
	var paces := mini(mini(p.x, p.y), mini(field.width - 1 - p.x, field.length - 1 - p.y))
	var denominator := maxf(1.0, float(maxi(field.width, field.length)) / 2.0)
	return clampf(1.0 - float(paces) / denominator, 0.0, 1.0)


#Chance a Grapple lands: the attacker check times the target failing the Grappled Resist.
static func grapple_estimate(attacker: MercenaryData, target: MercenaryData, state: BattleState) -> float:
	if attacker == null or target == null:
		return 0.0
	if ConstStates.has_state(target, ConstStates.GRAPPLED):
		if ConstStates.get_source(target, ConstStates.GRAPPLED) == attacker:
			return 1.0
		return 0.0
	if state != null and BattleState.knows(attacker, target,
			"immune:" + StateTokens.normalize_token(ConstStates.GRAPPLED)):
		return 0.0
	var default_spec := ConstStates.inflict_default(ConstStates.GRAPPLED)
	var spec := StateInfliction.parse_resist(str(default_spec.get("inflict", "")))
	var resist := 0.0
	if not spec.is_empty():
		resist = StateInfliction.resist_chance(target, spec, ConstStates.GRAPPLED)
	var lands := CheckSystem.expected_success_chance(attacker, SpecialActionSystem.grapple_def(), 1)
	return clampf(lands * (1.0 - resist), 0.0, 1.0)


#The merc this enemy would grab: the one it already holds, else the best estimate within reach.
static func best_target(attacker: MercenaryData, state: BattleState) -> Dictionary:
	if attacker == null or state == null:
		return {"merc": null, "chance": 0.0, "grappling": false}
	var held := held_by(attacker, state)
	if held != null:
		return {"merc": held, "chance": 1.0, "grappling": true}
	var best: MercenaryData = null
	var best_chance := 0.0
	for foe: MercenaryData in state.get_enemies(attacker):
		if state.distance_to(attacker, foe) > _CONFIG.kidnap_reach_paces:
			continue
		var chance := grapple_estimate(attacker, foe, state)
		if chance < 0.5 or chance <= best_chance:
			continue
		best = foe
		best_chance = chance
	return {"merc": best, "chance": best_chance, "grappling": false}


#Why a ready team drew no roll: the best in-reach estimate and the nearest foe.
static func scan_line(attacker: MercenaryData, state: BattleState) -> String:
	var best := 0.0
	var nearest := -1
	for foe: MercenaryData in state.get_enemies(attacker):
		var d := state.distance_to(attacker, foe)
		if nearest < 0 or d < nearest:
			nearest = d
		if d <= _CONFIG.kidnap_reach_paces:
			best = maxf(best, grapple_estimate(attacker, foe, state))
	var average := team_flee_average(state, int(state._merc_team_index.get(attacker, -1)))
	return "KIDNAP SCAN: %s team avg %.1f no target (best %.0f%% in reach, nearest %d paces)" % [
			attacker.merc_name, average, best * 100.0, nearest]


static func kidnap_bonus(attacker: MercenaryData, target: MercenaryData, state: BattleState,
		grappling: bool) -> float:
	var likelihood: float = 1.0 if grappling else grapple_estimate(attacker, target, state)
	var ceiling: float = _CONFIG.kidnap_bonus_max
	return minf(ceiling, ceiling * likelihood * edge_closeness(attacker, state))


static func kidnap_chance(attacker: MercenaryData, target: MercenaryData, state: BattleState,
		grappling: bool) -> float:
	return clampf(flee_chance(attacker, state) + kidnap_bonus(attacker, target, state, grappling), 0.0, 100.0)


#True when this turn belongs to the kidnapper: the captor carrying its captive or the pending grabber.
static func start_of_turn(merc: MercenaryData, state: BattleState, lines: Array[String]) -> bool:
	if not enabled or merc == null or state == null or not BattleState._is_alive(merc):
		return false
	if RescueSystem.is_active(state):
		return false
	if int(state._merc_team_index.get(merc, -1)) != 1:
		return false
	if state.kidnap_triggered:
		return holds(merc, state) or state.kidnap_pending == merc
	if state.kidnap_closed or FleeSystem.is_fleeing(merc):
		return false
	if not is_humanoid(merc) or ConstStates.is_immune(merc, ConstStates.TERRIFIED):
		return false
	if not team_ready(merc, state):
		return false
	var pick := best_target(merc, state)
	var target := pick.get("merc") as MercenaryData
	if target == null:
		EncounterLogger.log_verbose(scan_line(merc, state))
		return false
	var grappling := bool(pick.get("grappling", false))
	var flee := flee_chance(merc, state)
	var bonus := kidnap_bonus(merc, target, state, grappling)
	var chance := kidnap_chance(merc, target, state, grappling)
	rolls_made += 1
	var roll := _d100()
	var head := "  KIDNAP ROLL: %s d100 %d vs %.1f%% (flee %.1f + bonus %.1f) target %s" % [
			merc.merc_name, roll, chance, flee, bonus, target.merc_name]
	if float(roll) > chance:
		lines.append(head + " -> tries")
		return false
	lines.append(head + " -> passes")
	state.kidnap_triggered = true
	state.kidnap_pending = merc
	state.kidnap_pending_target = target
	if grappling:
		register(merc, target, state)
	force_team_flee(state, merc, lines)
	return true


static func run_turn(merc: MercenaryData, state: BattleState, lines: Array[String], enhancements: int) -> void:
	if merc == null or state == null:
		return
	if holds(merc, state):
		var captive := captive_of(merc, state)
		lines.append("  KIDNAP FLEE: %s carries %s toward the edge (%d/%d paces)" % [
				merc.merc_name, captive.merc_name, merc.flee_escape_paces,
				_CONFIG.kidnap_escape_paces])
		FleeMover.run_turn(merc, state, lines, enhancements)
		return
	var target: MercenaryData = state.kidnap_pending_target
	if target == null or not BattleState._is_alive(target) \
			or state.distance_to(merc, target) > _CONFIG.kidnap_reach_paces:
		give_up(merc, state, lines, "out of reach")
		FleeMover.run_turn(merc, state, lines, enhancements)
		return
	if state.distance_to(merc, target) > 1:
		lines.append_array(MovementExecutor.run_move_arm(merc, {"type": "move", "action_name": "Move Close",
				"target": target, "moves_allowed": 2, "reserve_ap": 0}, state, enhancements,
				AutoBattle.new_turn(merc, state)))
		if not BattleState._is_alive(merc) or state.distance_to(merc, target) > 1:
			return
	var cost := state.get_cost(merc, "grapple", 2)
	if not state.can_afford(merc, cost):
		return
	state.spend_ap(merc, cost)
	state.record_action(merc, "grapple")
	lines.append_array(SpecialActionSystem.do_grapple(merc, target, state))
	if ConstStates.has_state(target, ConstStates.GRAPPLED) \
			and ConstStates.get_source(target, ConstStates.GRAPPLED) == merc:
		register(merc, target, state)
		state.kidnap_pending = null
		state.kidnap_pending_target = null
		FleeMover.run_turn(merc, state, lines, enhancements)
		return
	give_up(merc, state, lines, "grapple failed")


#Ends the attempt and every later kidnap roll of this encounter.
static func give_up(captor: MercenaryData, state: BattleState, lines: Array[String], why: String) -> void:
	if captor == null or state == null:
		return
	var target: MercenaryData = state.kidnap_pending_target
	var who: String = target.merc_name if target != null else "its target"
	state.kidnap_closed = true
	state.kidnap_pending = null
	state.kidnap_pending_target = null
	lines.append("  KIDNAP GRAPPLE: %s gives up on %s (%s)" % [captor.merc_name, who, why])


static func register(captor: MercenaryData, target: MercenaryData, state: BattleState) -> void:
	if captor == null or target == null or state == null:
		return
	state.kidnap_captor[captor] = target
	captor.active_states[DRAG_KEY] = target.unit_size()
	kidnaps_total += 1


static func unregister(captor: MercenaryData, state: BattleState) -> void:
	if captor == null:
		return
	if state != null:
		state.kidnap_captor.erase(captor)
	captor.active_states.erase(DRAG_KEY)


static func captive_of(captor: MercenaryData, state: BattleState) -> MercenaryData:
	if captor == null or state == null:
		return null
	return state.kidnap_captor.get(captor) as MercenaryData


#A merc this enemy already holds in Grappled, whatever put it there; nothing is registered here.
static func held_by(captor: MercenaryData, state: BattleState) -> MercenaryData:
	if captor == null or state == null:
		return null
	for foe: MercenaryData in state.get_enemies(captor):
		if ConstStates.has_state(foe, ConstStates.GRAPPLED) \
				and ConstStates.get_source(foe, ConstStates.GRAPPLED) == captor:
			return foe
	return null


#True while the registered pair still stands; a broken grapple unregisters it here.
static func holds(captor: MercenaryData, state: BattleState) -> bool:
	var captive := captive_of(captor, state)
	if captive == null:
		return false
	if not BattleState._is_alive(captive) or captive.off_field \
			or not ConstStates.has_state(captive, ConstStates.GRAPPLED) \
			or ConstStates.get_source(captive, ConstStates.GRAPPLED) != captor:
		unregister(captor, state)
		return false
	return true


static func drag_size(captor: MercenaryData) -> int:
	if captor == null:
		return 0
	return int(captor.active_states.get(DRAG_KEY, 0))


#Pulls the captive into the cell the captor just left; a taken cell leaves it where it stands.
static func drag(captor: MercenaryData, state: BattleState, from_cell: Vector3i) -> void:
	if not holds(captor, state):
		return
	if from_cell == state.pos3(captor):
		return
	var captive := captive_of(captor, state)
	if captive == null:
		return
	if state.is_position_occupied(Vector2i(from_cell.x, from_cell.y), captive, from_cell.z):
		return
	state.set_pos3(captive, from_cell)
	state.set_pace_pool(captive, 0)
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("KIDNAP DRAG: %s pulls %s to (%d,%d) F%d" % [
				captor.merc_name, captive.merc_name, from_cell.x, from_cell.y, from_cell.z])


#Breaks off the whole crew with no gate, no roll and no Terrified, so immune enemies run too.
static func force_team_flee(state: BattleState, captor: MercenaryData, lines: Array[String]) -> void:
	if state == null or captor == null:
		return
	var index: int = int(state._merc_team_index.get(captor, -1))
	if index < 0 or index >= state.teams.size():
		return
	var team: Array = state.teams[index]
	var allies := 0
	for other: MercenaryData in team:
		if not BattleState._is_alive(other):
			continue
		other.flee_intent = true
		other.flee_abandons = true
		other.flee_escape_paces = 0
		FleeSystem.forced[other] = true
		if other != captor:
			allies += 1
	lines.append("  KIDNAP FLEE: %s and %d allies break off" % [captor.merc_name, allies])


#The captor has just banked its way off the map; the captive goes with it.
static func on_escape(captor: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	if captor == null or state == null:
		return
	if not holds(captor, state):
		return
	var captive := captive_of(captor, state)
	state.kidnap_taken[captive] = captor.merc_name
	state.remove_from_field(captive, "kidnapped", lines)
	unregister(captor, state)


static func settle(run: ContractRun, state: BattleState, roster: Array[MercenaryData],
		crew_source: String = "") -> Array[String]:
	var out: Array[String] = []
	if run == null or state == null:
		return out
	for merc: MercenaryData in roster:
		if not state.kidnapped.has(merc):
			continue
		var crew: Array[MercenaryData] = []
		for foe: MercenaryData in state.get_enemies(merc):
			if foe != null and not foe.is_dead and foe.current_hp > 0:
				crew.append(foe)
		out.append_array(take_captive(run, merc, str(state.kidnap_taken.get(merc, "")), crew,
			crew_source))
	return out


#Takes the merc out of the party for good: mark, lifepath refresh, captives register, scope wipe.
static func take_captive(run: ContractRun, merc: MercenaryData, captor_name: String,
		crew: Array = [], crew_source: String = "") -> Array[String]:
	var out: Array[String] = []
	if run == null or merc == null:
		return out
	run.add_merc_mark(merc, MARK)
	out.append("KIDNAP MARK: %s (%s)" % [merc.merc_name, captor_name])
	out.append_array(LifepathProgression.refresh_pool(merc, run))
	var contract_type: String = run.contract.contract_type if run.contract != null else ""
	var place: String = run.location.location_name if run.location != null else ""
	MercPool.add_captive(merc, contract_type, place, CampaignClock.stamp(), crew, crew_source)
	out.append_array(run.depart(merc, run.kidnapped))
	out.append("KIDNAPPED: %s taken by %s" % [merc.merc_name, captor_name])
	return out
