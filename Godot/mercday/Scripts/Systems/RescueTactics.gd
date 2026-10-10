class_name RescueTactics extends RefCounted

#Rescue tactics: whether to free the captive now, who escorts the picker, and who pulls back to the exit.

const POLICY_SMART := "smart"
const POLICY_ALWAYS := "always"
const POLICY_NEVER := "never"

const MELEE_SMART := "smart"
const MELEE_PICK := "pick"
const MELEE_FIGHT := "fight"

static var policy: String = POLICY_SMART
static var withdraw_enabled: bool = true
static var melee_rule: String = MELEE_SMART
static var careful: bool = true
static var caged_wounded_leave: bool = false
static var shelter_los: bool = false

const MAX_PICK_ROUNDS := 6.0
const GATE_RADIUS := 8
const ESCORT_RADIUS := 6
const WITHDRAW_HP := 0.35
const LOST_ODDS := 0.4
const WINNING_ODDS := 1.5
const ABANDON_ODDS := 0.4
const NEAR_ENEMY := 8
const HOPELESS_PICK := 0.1
const GEAR_ODDS := 1.0
const SLOT_CAP := 8
const PICK_BASE := 0.4
const PRESSURE_PER_ENEMY := 0.2
const SELF_RISK := 0.3
const NO_ODDS := 99.0
const NO_ROUNDS := 99.0
const ROUTE_RADIUS := 8
const SHELTER_THREAT := 3
const SHELTER_SIGHT := 12
const HIDE_SCAN := 80

const POSTURE_FIGHT := "fight"
const POSTURE_FALL_BACK := "fall_back"      #fighting withdrawal
const POSTURE_WITHDRAW := "withdraw"
const POSTURE_HOLD := "hold"
const POSTURE_HIDE := "hide"

#The rule number logged with each posture; the captive rules are read back by name.
const RULE_CAGED := 0
const RULE_WOUNDED := 1
const RULE_ODDS_LOST := 2
const RULE_EXIT_RACE := 3
const RULE_NO_ENEMY_NEAR := 4
const RULE_WINNING := 5
const RULE_FALL_BACK := 6
const RULE_CHEST_RUN := 7
const RULE_WALK_OUT := 8
const RULE_CAPTIVE_FALL_BACK := 9
const RULE_HOLD := 10
const RULE_CLEAR_FIRST := 11
const RULE_PARTY_LEAVING := 12
const RULE_HIDE_SIGHT := 13
const RULE_REFUGE := 14
const RULE_SHELTER := 15

const PHASE_CAGED := "caged"
const PHASE_OUT := "out"
const PHASE_DONE := "done"

#True once the approach has become a fight: a combat contract, or a stealth run after the alarm.
static func fighting(state: BattleState) -> bool:
	if not RescueSystem.is_active(state):
		return false
	var rescue: Dictionary = state.rescue
	return str(rescue["mode"]) == RescueSystem.MODE_COMBAT or bool(rescue["alarm"])


#Living rescuers still on the field; the captive is counted apart from them.
static func party(state: BattleState) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	if not RescueSystem.is_active(state):
		return out
	var captive: MercenaryData = state.rescue["captive"] as MercenaryData
	for m: MercenaryData in state.teams[0]:
		if m == captive or not BattleState._is_alive(m):
			continue
		out.append(m)
	return out


static func side_hp(mercs: Array[MercenaryData]) -> int:
	var total: int = 0
	for m: MercenaryData in mercs:
		total += maxi(0, m.current_hp)
	return total


#Party hit points over enemy hit points; NO_ODDS when nothing is left to fight.
static func odds(state: BattleState) -> float:
	var rescue: Dictionary = state.rescue
	var mine: int = side_hp(party(state))
	var captive: MercenaryData = rescue["captive"] as MercenaryData
	if bool(rescue["freed"]) and captive != null and BattleState._is_alive(captive):
		mine += maxi(0, captive.current_hp)
	var foe: int = 0
	for e: MercenaryData in RescueSystem.enemy_team(state):
		if BattleState._is_alive(e):
			foe += maxi(0, e.current_hp)
	if foe <= 0:
		return NO_ODDS
	return float(mine) / float(foe)


#Probe calibration: the first and the lowest odds the party met while fighting.
static func track_odds(state: BattleState) -> void:
	var rescue: Dictionary = state.rescue
	var o: float = odds(state)
	if not rescue.has("start_odds"):
		rescue["start_odds"] = o
	rescue["min_odds"] = minf(o, float(rescue.get("min_odds", NO_ODDS)))


static func hp_frac(merc: MercenaryData) -> float:
	if merc == null:
		return 0.0
	return float(maxi(0, merc.current_hp)) / maxf(1.0, float(merc.stats.get("maximum_hit_points", 0)))


static func enemy_near(cell: Vector3i, state: BattleState, r: int) -> int:
	var n: int = 0
	for e: MercenaryData in RescueSystem.enemy_team(state):
		if BattleState._is_alive(e) and RescueGrid.near(state.pos3(e), cell, r):
			n += 1
	return n


#Walk steps from a cell to the exit, -1 when the map never reached it.
static func exit_steps(state: BattleState, cell: Vector3i) -> int:
	return int((state.rescue.get("exit_dist", {}) as Dictionary).get(cell, -1))


static func _gate_steps(state: BattleState, cell: Vector3i) -> int:
	return int((state.rescue.get("gate_dist", {}) as Dictionary).get(cell, -1))


static func _pct(v: float) -> int:
	return int(roundf(v * 100.0))


static func enemy_adjacent(merc: MercenaryData, state: BattleState) -> bool:
	return adjacent_enemies(merc, state) > 0


static func adjacent_enemies(merc: MercenaryData, state: BattleState) -> int:
	var own: Vector3i = state.pos3(merc)
	var n: int = 0
	for e: MercenaryData in RescueSystem.enemy_team(state):
		if BattleState._is_alive(e) and RescueGrid.is_adjacent(state.pos3(e), own):
			n += 1
	return n


#True when no living enemy stands within ROUTE_RADIUS of the merc or of any cell on its walk to the goal.
static func route_safe(merc: MercenaryData, state: BattleState, goal: Vector3i) -> bool:
	if merc == null or goal == PathTargeter.NO_CELL:
		return false
	var own: Vector3i = state.pos3(merc)
	if enemy_near(own, state, ROUTE_RADIUS) > 0:
		return false
	if own == goal:
		return true
	var path: Array[Vector3i] = ReachCache.walk_path_for(merc, state, own, goal)
	if path.is_empty():
		return false
	for cell: Vector3i in path:
		if enemy_near(cell, state, ROUTE_RADIUS) > 0:
			return false
	return true


#True when a living enemy stands beside the cell or sees it from within SHELTER_SIGHT.
static func threatened(state: BattleState, merc: MercenaryData, cell: Vector3i) -> bool:
	if enemy_near(cell, state, 1) > 0:
		return true
	for key: Variant in RescueGrid.cell_seers(state, cell, merc).keys():
		var e: MercenaryData = key as MercenaryData
		if e != null and RescueGrid.spread(state.pos3(e), cell) <= SHELTER_SIGHT:
			return true
	return false


#Nearest walkable free cell no enemy threatens; NO_CELL when the scan finds none.
static func hide_cell(merc: MercenaryData, state: BattleState) -> Vector3i:
	var reach: Dictionary = ReachCache.reachable_for(merc, state)
	#Packed as (cost, floor, x, y) so the plain sort ranks by walk cost and settles ties the same every run.
	var order: Array[Vector4i] = []
	for key: Variant in reach.keys():
		var cell: Vector3i = key as Vector3i
		var cost: int = int(reach[key])
		if cost > 0 and cost < PathTargeter.JUMP_COST_OFFSET:
			order.append(Vector4i(cost, cell.z, cell.x, cell.y))
	order.sort()
	var scanned: int = 0
	for packed: Vector4i in order:
		if scanned >= HIDE_SCAN:
			break
		var cell := Vector3i(packed.z, packed.w, packed.y)
		if not RescueGrid.cell_free(state.battlefield, state, cell, merc):
			continue
		scanned += 1
		if not threatened(state, merc, cell):
			return cell
	return PathTargeter.NO_CELL


#Free cell inside the prison cell when the walk there is safe; NO_CELL otherwise or when already inside.
static func _cell_refuge(merc: MercenaryData, state: BattleState, safe_cell: bool = false) -> Vector3i:
	var rescue: Dictionary = state.rescue
	var rect: Rect2i = rescue["cell_rect"] as Rect2i
	var f: int = int(rescue["cell_floor"])
	var own: Vector3i = state.pos3(merc)
	if own.z == f and rect.has_point(Vector2i(own.x, own.y)):
		return PathTargeter.NO_CELL
	var best: Vector3i = PathTargeter.NO_CELL
	var best_dist: int = 1 << 24
	for cell: Vector3i in RescueGrid.free_cells(state.battlefield, state, rect, f, merc):
		var dist: int = RescueGrid.spread(own, cell)
		if dist < best_dist:
			best_dist = dist
			best = cell
	if best == PathTargeter.NO_CELL or not route_safe(merc, state, best):
		return PathTargeter.NO_CELL
	if not safe_cell and threatened(state, merc, best):
		return PathTargeter.NO_CELL
	return best


#True when the captive holds a real weapon it can use now.
static func captive_armed(state: BattleState) -> bool:
	var captive: MercenaryData = state.rescue["captive"] as MercenaryData
	if captive == null:
		return false
	var weapon: WeaponData = captive.equipped_weapon
	if weapon == null or weapon.is_virtual:
		return false
	if not weapon.is_ranged:
		return true
	return captive.ammo_loaded > 0 or int(captive.ammo_inventory.get(captive.ammo_loaded_type, 0)) > 0


#True when nobody is left to clear the dungeon for the captive: the party is beaten, gone or pulling out.
static func party_leaving(state: BattleState) -> bool:
	var rescue: Dictionary = state.rescue
	if bool(rescue["abandoned"]) or odds(state) < LOST_ODDS:
		return true
	return party(state).is_empty()


static func captive_rule(state: BattleState) -> int:
	return int(state.rescue.get("captive_rule", 0))


#How badly the party wants the captive in the fight: 0 while winning, 1 once the odds are dire.
static func need(o: float) -> float:
	var zero: float = RescueTune.tuned("need_zero_odds")
	var full: float = RescueTune.tuned("need_full_odds")
	return clampf((zero - o) / maxf(0.01, zero - full), 0.0, 1.0)


#Where the rescue stands: the captive still caged, out and walking, or the matter settled.
static func phase(state: BattleState) -> String:
	var rescue: Dictionary = state.rescue
	var captive: MercenaryData = rescue["captive"] as MercenaryData
	if not RescueSystem.captive_alive(captive):
		return PHASE_DONE
	if not bool(rescue["freed"]):
		return PHASE_CAGED
	if bool(rescue["captive_exited"]) or captive.off_field:
		return PHASE_DONE
	return PHASE_OUT


#True while the party still wants the cell opened; RescueDoors.reason reads this.
static func gate_wanted(state: BattleState) -> bool:
	if not RescueSystem.is_active(state):
		return false
	var rescue: Dictionary = state.rescue
	if bool(rescue["done"]) or bool(rescue["freed"]):
		return false
	if not RescueSystem.captive_alive(rescue["captive"] as MercenaryData):
		return false
	if not fighting(state):
		return true
	return bool(rescue["gate_go"])


#Whether working the lock outranks swinging at what is in reach, weighed again every action slot.
static func pick_first(merc: MercenaryData, state: BattleState) -> bool:
	if merc == null or not RescueSystem.is_active(state) or not fighting(state):
		return true
	if melee_rule == MELEE_PICK:
		return true
	var adjacent: int = adjacent_enemies(merc, state)
	if melee_rule == MELEE_FIGHT:
		return adjacent == 0
	var gate_obs: Dictionary = state.rescue["gate_obs"] as Dictionary
	var p: float = 1.0
	if not gate_obs.is_empty() and DungeonLocks.is_locked(gate_obs):
		p = DungeonLocks.pick_chance(merc, gate_obs)
	var pick_value: float = p * (PICK_BASE + (1.0 - PICK_BASE) * need(odds(state)))
	var fight_value: float = _fight_value(merc, state, adjacent)
	var ok: bool = pick_value >= fight_value
	_log_order(merc, state, ok, pick_value, fight_value)
	return ok


#What a swing is worth here: the best enemy left to finish, the crowd on the merc and its own danger.
static func _fight_value(merc: MercenaryData, state: BattleState, adjacent: int) -> float:
	var best: float = 0.0
	for e: MercenaryData in RescueSystem.enemy_team(state):
		if BattleState._is_alive(e) and AutoBattle.can_attack_target(merc, e, state):
			best = maxf(best, 1.0 - hp_frac(e))
	var v: float = best + PRESSURE_PER_ENEMY * float(adjacent)
	if adjacent > 0:
		v += SELF_RISK * (1.0 - hp_frac(merc))
	return v


static func _log_order(merc: MercenaryData, state: BattleState, ok: bool, pick_value: float,
		fight_value: float) -> void:
	if not EncounterLogger.is_active():
		return
	var said: Dictionary = state.rescue["order_said"] as Dictionary
	var mark: int = state.round_number * 2 + (1 if ok else 0)
	if int(said.get(merc, -1)) == mark:
		return
	said[merc] = mark
	EncounterLogger.log_verbose("RESCUE ORDER: %s %s first (pick %d%%, fight %d%%)" % [
		merc.merc_name, "pick" if ok else "fight", _pct(pick_value), _pct(fight_value)])


#Go or Stay on the cell, re-decided at the start of every picker turn while the fight runs.
static func evaluate_gate(state: BattleState, lines: Array[String]) -> void:
	var rescue: Dictionary = state.rescue
	var lead: MercenaryData = RescueSystem.picker(state)
	if lead == null or phase(state) != PHASE_CAGED or not fighting(state):
		return
	if int(rescue["gate_eval_round"]) == state.round_number:
		return
	rescue["gate_eval_round"] = state.round_number
	var gate_obs: Dictionary = rescue["gate_obs"] as Dictionary
	var was: bool = bool(rescue["gate_go"])
	var o: float = odds(state)
	var want: float = 0.0
	var help: float = 0.0
	var cost: float = 0.0
	var danger: float = 0.0
	var go: bool = true
	if gate_obs.is_empty() or not DungeonLocks.is_locked(gate_obs):
		go = true
	elif _hopeless(state, gate_obs):
		rescue["gate_hopeless"] = true
		go = false
	elif policy == POLICY_ALWAYS:
		go = true
	elif policy == POLICY_NEVER:
		go = false
	else:
		want = need(o)
		help = want * _captive_share(state)
		cost = _gate_cost(lead, state, gate_obs)
		danger = _gate_danger(state)
		var margin: float = RescueTune.tuned("go_margin")
		if str(rescue["mode"]) == RescueSystem.MODE_STEALTH:
			margin += RescueTune.tuned("stealth_margin")
		go = help > cost + danger + margin
	rescue["gate_go"] = go
	if go:
		rescue["go_count"] = int(rescue["go_count"]) + 1
		rescue["escort"] = _choose_escort(state)
	else:
		rescue["stay_count"] = int(rescue["stay_count"]) + 1
		rescue["escort"] = null
	_log_decision(lead, go, o, want, help, cost, danger)
	if was == go:
		return
	if go:
		lines.append("  %s breaks off for the cell." % BattleState.colored_name(lead, state))
	else:
		lines.append("  %s gives up on the cell for now." % BattleState.colored_name(lead, state))


static func _log_decision(lead: MercenaryData, go: bool, o: float, want: float, help: float,
		cost: float, danger: float) -> void:
	if not EncounterLogger.is_active():
		return
	var fmt: String = "RESCUE DECISION: %s odds %d%% need %d%% help %d%% cost %d%% danger %d%%"
	fmt += " (picker %s, policy %s)"
	EncounterLogger.log_verbose(fmt % ["go" if go else "stay", _pct(o), _pct(want), _pct(help),
		_pct(cost), _pct(danger), lead.merc_name, policy])


#A gate jammed past saving that nobody left can realistically open.
static func _hopeless(state: BattleState, gate_obs: Dictionary) -> bool:
	if DungeonLocks.lock_fails(gate_obs) < DungeonLocks.MAX_JAM:
		return false
	var best: float = 0.0
	for m: MercenaryData in party(state):
		best = maxf(best, DungeonLocks.pick_chance(m, gate_obs))
	return best < HOPELESS_PICK


#How much of the party's strength the captive would add; halved when the chest holds it no weapon.
static func _captive_share(state: BattleState) -> float:
	var captive: MercenaryData = state.rescue["captive"] as MercenaryData
	var c: float = float(maxi(0, captive.current_hp)) if captive != null else 0.0
	var p: float = float(side_hp(party(state)))
	if c + p <= 0.0:
		return 0.0
	var share: float = c / (c + p)
	if not _weapon_in_chest(state):
		share *= RescueTune.tuned("share_cut")
	return share


static func _weapon_in_chest(state: BattleState) -> bool:
	var rescue: Dictionary = state.rescue
	if bool(rescue.get("chest_given_up", false)):
		return false
	var chest_obs: Dictionary = rescue["chest_obs"] as Dictionary
	if chest_obs.is_empty():
		return false
	return RescueSystem.chest_has_type(chest_obs, "weapon")


#Rounds the picker spends walking and picking, weighed by the share of the party it is.
static func _gate_cost(lead: MercenaryData, state: BattleState, gate_obs: Dictionary) -> float:
	var steps: int = _gate_steps(state, state.pos3(lead))
	var walk_rounds: float = NO_ROUNDS
	if steps >= 0:
		var per_round: int = maxi(1, PaceBudget.pace_per_move(lead) * RescueSystem.MOVES_PER_TURN)
		walk_rounds = ceilf(float(maxi(0, steps - 1)) / float(per_round))
	var pick_rounds: float = minf(MAX_PICK_ROUNDS, 1.0 / maxf(0.01, DungeonLocks.pick_chance(lead, gate_obs)))
	var share: float = float(maxi(0, lead.current_hp)) / maxf(1.0, float(side_hp(party(state))))
	return share * (walk_rounds + pick_rounds) / maxf(0.01, RescueTune.tuned("cost_rounds"))


static func _gate_danger(state: BattleState) -> float:
	var gate_cell: Vector3i = state.rescue["gate_cell"] as Vector3i
	if gate_cell == PathTargeter.NO_CELL:
		return 0.0
	var friends: int = 0
	for m: MercenaryData in party(state):
		if RescueGrid.near(state.pos3(m), gate_cell, GATE_RADIUS):
			friends += 1
	return RescueTune.tuned("danger_per_enemy") * float(maxi(0, enemy_near(gate_cell, state, GATE_RADIUS) - friends))


#The merc told off to attend the picker, dropped once it dies, leaves or the cell opens.
static func escort(state: BattleState) -> MercenaryData:
	var rescue: Dictionary = state.rescue
	var m: MercenaryData = rescue.get("escort", null) as MercenaryData
	if m == null:
		return null
	if bool(rescue["freed"]) or not BattleState._is_alive(m):
		rescue["escort"] = null
		return null
	return m


static func _choose_escort(state: BattleState) -> MercenaryData:
	var lead: MercenaryData = RescueSystem.picker(state)
	var crew: Array[MercenaryData] = party(state)
	if lead == null or crew.size() < 3 or not _escort_warranted(lead, state):
		return null
	var own: Vector3i = state.pos3(lead)
	var best: MercenaryData = null
	var best_d: int = 1 << 24
	for m: MercenaryData in crew:
		if m == lead:
			continue
		var d: int = RescueGrid.spread(state.pos3(m), own)
		if d < best_d:
			best_d = d
			best = m
	return best


#An escort is warranted when enemies stand near the gate or anywhere along the picker's route.
static func _escort_warranted(lead: MercenaryData, state: BattleState) -> bool:
	var gate_cell: Vector3i = state.rescue["gate_cell"] as Vector3i
	if gate_cell != PathTargeter.NO_CELL and enemy_near(gate_cell, state, ESCORT_RADIUS) > 0:
		return true
	var approach: Vector3i = RescueGrid.approach_cell(lead, state)
	if approach == PathTargeter.NO_CELL:
		return false
	for cell: Vector3i in ReachCache.walk_path_for(lead, state, state.pos3(lead), approach):
		if enemy_near(cell, state, ESCORT_RADIUS) > 0:
			return true
	return false


static func posture_of(state: BattleState, merc: MercenaryData) -> String:
	if not RescueSystem.is_active(state):
		return POSTURE_FIGHT
	return str((state.rescue.get("postures", {}) as Dictionary).get(merc, POSTURE_FIGHT))


static func set_posture(merc: MercenaryData, state: BattleState, lines: Array[String]) -> String:
	_check_abandon(state, lines)
	var call_row: Dictionary = _decide(merc, state)
	if merc == (state.rescue["captive"] as MercenaryData):
		state.rescue["captive_rule"] = int(call_row["rule"])
	var p: String = str(call_row["posture"])
	(state.rescue["postures"] as Dictionary)[merc] = p
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("RESCUE POSTURE: %s %s (odds %d%%, hp %d%%, phase %s, rule %d)" % [
			merc.merc_name, p, _pct(odds(state)), _pct(hp_frac(merc)), phase(state), int(call_row["rule"])])
	return p


static func _decide(merc: MercenaryData, state: BattleState) -> Dictionary:
	var rescue: Dictionary = state.rescue
	if merc == (rescue["captive"] as MercenaryData):
		return _captive_posture(merc, state)
	var ph: String = phase(state)
	var o: float = odds(state)
	if ph == PHASE_CAGED:
		if caged_wounded_leave and hp_frac(merc) <= WITHDRAW_HP and o < WINNING_ODDS:
			return {"posture": POSTURE_WITHDRAW, "rule": RULE_WOUNDED}
		return {"posture": POSTURE_WITHDRAW if bool(rescue["abandoned"]) else POSTURE_FIGHT, "rule": RULE_CAGED}
	return _party_posture(merc, state, ph, o)


#Hopeless odds or a dead-jammed gate turn the whole party out of the dungeon for good.
static func _check_abandon(state: BattleState, lines: Array[String]) -> void:
	var rescue: Dictionary = state.rescue
	if bool(rescue["abandoned"]) or phase(state) != PHASE_CAGED:
		return
	var o: float = odds(state)
	var quit_now: bool = (not bool(rescue["gate_go"]) and int(rescue["gate_eval_round"]) > 0 \
		and o < ABANDON_ODDS) or (bool(rescue["gate_hopeless"]) and o < WINNING_ODDS)
	if not quit_now:
		return
	rescue["abandoned"] = true
	lines.append("  The party gives up on the rescue and pulls out.")


static func _party_posture(merc: MercenaryData, state: BattleState, ph: String, o: float) -> Dictionary:
	var captive: MercenaryData = state.rescue["captive"] as MercenaryData
	var own: Vector3i = state.pos3(merc)
	if hp_frac(merc) <= WITHDRAW_HP:
		return {"posture": POSTURE_WITHDRAW, "rule": RULE_WOUNDED}
	if o < LOST_ODDS:
		return {"posture": POSTURE_WITHDRAW, "rule": RULE_ODDS_LOST}
	#While the freed captive shelters, the party fights on to clear; nobody holds the exit or walks out.
	if careful and ph == PHASE_OUT and _captive_sheltering(state):
		return {"posture": POSTURE_FIGHT, "rule": RULE_CLEAR_FIRST}
	if ph == PHASE_OUT and _nearer_exit(state, merc, captive):
		#The exit is one cell; a merc already standing on it walks out rather than hold it shut.
		if own == (state.rescue["exit_cell"] as Vector3i):
			return {"posture": POSTURE_WITHDRAW, "rule": RULE_EXIT_RACE}
		if enemy_near(own, state, NEAR_ENEMY) > 0 or enemy_near(state.pos3(captive), state, NEAR_ENEMY) > 0:
			return {"posture": POSTURE_FIGHT, "rule": RULE_EXIT_RACE}
		return {"posture": POSTURE_HOLD, "rule": RULE_EXIT_RACE}
	if enemy_near(own, state, NEAR_ENEMY) == 0:
		return {"posture": POSTURE_WITHDRAW, "rule": RULE_NO_ENEMY_NEAR}
	if o >= WINNING_ODDS:
		return {"posture": POSTURE_FIGHT, "rule": RULE_WINNING}
	return {"posture": POSTURE_FALL_BACK, "rule": RULE_FALL_BACK}


#True while the freed captive is staying put or moving to cover rather than walking the dungeon.
static func _captive_sheltering(state: BattleState) -> bool:
	var rule: int = captive_rule(state)
	if rule == RULE_HOLD or rule == RULE_REFUGE or rule == RULE_SHELTER:
		return true
	if not shelter_los:
		return false
	var captive: MercenaryData = state.rescue["captive"] as MercenaryData
	return rule == RULE_HIDE_SIGHT and posture_of(state, captive) == POSTURE_HIDE


static func _nearer_exit(state: BattleState, merc: MercenaryData, captive: MercenaryData) -> bool:
	var mine: int = exit_steps(state, state.pos3(merc))
	var theirs: int = exit_steps(state, state.pos3(captive))
	return mine >= 0 and theirs >= 0 and mine < theirs


#The freed captive keeps itself alive: it walks only safe routes, shelters while the party fights,
#and runs when nobody is left.
static func _captive_posture(merc: MercenaryData, state: BattleState) -> Dictionary:
	if not careful:
		return _captive_posture_plain(merc, state)
	var rescue: Dictionary = state.rescue
	var own: Vector3i = state.pos3(merc)
	var exit_cell: Vector3i = rescue["exit_cell"] as Vector3i
	if route_safe(merc, state, exit_cell):
		return {"posture": POSTURE_WITHDRAW, "rule": RULE_WALK_OUT}
	if RescueSystem.needs(state) > 0:
		if gear_worth(state):
			var chest_cell: Vector3i = rescue["chest_cell"] as Vector3i
			if RescueGrid.is_adjacent(own, chest_cell) \
					or route_safe(merc, state, RescueGrid.adjacent_free_cell(state, chest_cell, merc)):
				return {"posture": POSTURE_FIGHT, "rule": RULE_CHEST_RUN}
		else:
			rescue["chest_given_up"] = true
	if party_leaving(state):
		return {"posture": POSTURE_WITHDRAW, "rule": RULE_PARTY_LEAVING}
	if RescueSystem.shelters(state, merc):
		return {"posture": POSTURE_HOLD, "rule": RULE_SHELTER}
	if not bool(rescue.get("captive_acted", false)):
		var safe: Vector3i = _cell_refuge(merc, state, true)
		if safe != PathTargeter.NO_CELL:
			rescue["hide_goal"] = safe
			return {"posture": POSTURE_HIDE, "rule": RULE_REFUGE}
	if captive_armed(state):
		if enemy_near(own, state, NEAR_ENEMY) > 0:
			return {"posture": POSTURE_FALL_BACK, "rule": RULE_CAPTIVE_FALL_BACK}
	elif not shelter_los:
		if enemy_near(own, state, SHELTER_THREAT) > 0:
			return {"posture": POSTURE_WITHDRAW, "rule": RULE_HIDE_SIGHT}
	elif threatened(state, merc, own):
		return _hide_posture(merc, state)
	if shelter_los:
		var refuge: Vector3i = _cell_refuge(merc, state)
		if refuge != PathTargeter.NO_CELL:
			rescue["hide_goal"] = refuge
			return {"posture": POSTURE_HIDE, "rule": RULE_REFUGE}
	return {"posture": POSTURE_HOLD, "rule": RULE_HOLD}


#An unarmed captive in enemy sight breaks the sight line, else closes on an ally, else runs for the exit.
static func _hide_posture(merc: MercenaryData, state: BattleState) -> Dictionary:
	var rescue: Dictionary = state.rescue
	var goal: Vector3i = hide_cell(merc, state)
	if goal == PathTargeter.NO_CELL:
		var own: Vector3i = state.pos3(merc)
		var best_dist: int = 1 << 24
		for ally: MercenaryData in party(state):
			var spot: Vector3i = RescueGrid.adjacent_free_cell(state, state.pos3(ally), merc)
			if spot == PathTargeter.NO_CELL:
				continue
			var dist: int = RescueGrid.spread(own, spot)
			if dist < best_dist:
				best_dist = dist
				goal = spot
	if goal == PathTargeter.NO_CELL:
		return {"posture": POSTURE_WITHDRAW, "rule": RULE_HIDE_SIGHT}
	rescue["hide_goal"] = goal
	return {"posture": POSTURE_HIDE, "rule": RULE_HIDE_SIGHT}


#The freed captive fetches its gear while that is worth doing, then walks out; it never holds.
static func _captive_posture_plain(merc: MercenaryData, state: BattleState) -> Dictionary:
	if RescueSystem.needs(state) > 0:
		if gear_worth(state):
			return {"posture": POSTURE_FIGHT, "rule": RULE_CHEST_RUN}
		state.rescue["chest_given_up"] = true
	var weapon: WeaponData = merc.equipped_weapon
	if weapon == null or weapon.is_virtual or hp_frac(merc) <= WITHDRAW_HP or odds(state) < LOST_ODDS:
		return {"posture": POSTURE_WITHDRAW, "rule": RULE_WALK_OUT}
	return {"posture": POSTURE_FALL_BACK, "rule": RULE_CAPTIVE_FALL_BACK}


#True while the chest is reachable and the detour costs the captive less than it buys.
static func gear_worth(state: BattleState) -> bool:
	var rescue: Dictionary = state.rescue
	if bool(rescue.get("chest_given_up", false)):
		return false
	var captive: MercenaryData = rescue["captive"] as MercenaryData
	var chest_cell: Vector3i = rescue["chest_cell"] as Vector3i
	if captive == null or chest_cell == PathTargeter.NO_CELL:
		return false
	if RescueGrid.adjacent_free_cell(state, chest_cell, captive) == PathTargeter.NO_CELL:
		return false
	if odds(state) >= GEAR_ODDS:
		return true
	var exit_cell: Vector3i = rescue["exit_cell"] as Vector3i
	if exit_cell == PathTargeter.NO_CELL:
		return true
	var own: Vector3i = state.pos3(captive)
	return RescueGrid.spread(own, chest_cell) <= RescueGrid.spread(own, exit_cell)


#True when the rescue director drives this merc's turn instead of the normal decision loop.
static func takes_turn(merc: MercenaryData, state: BattleState) -> bool:
	if gate_run_due(merc, state) or escort_due(merc, state):
		return true
	var p: String = posture_of(state, merc)
	return p == POSTURE_WITHDRAW or p == POSTURE_HOLD or p == POSTURE_HIDE


static func gate_run_due(merc: MercenaryData, state: BattleState) -> bool:
	var rescue: Dictionary = state.rescue
	if not fighting(state) or not bool(rescue["gate_go"]) or phase(state) != PHASE_CAGED:
		return false
	if merc != RescueSystem.picker(state) or enemy_adjacent(merc, state):
		return false
	var target: Vector3i = RescueSystem.free_target_cell(state)
	if target == PathTargeter.NO_CELL or RescueGrid.is_adjacent(state.pos3(merc), target):
		return false
	return not ConstStates.has_state(merc, ConstStates.DEPOSED) \
		or state.can_afford(merc, state.get_cost(merc, "get_up", 2))


static func escort_due(merc: MercenaryData, state: BattleState) -> bool:
	var rescue: Dictionary = state.rescue
	if not fighting(state) or not bool(rescue["gate_go"]) or phase(state) != PHASE_CAGED:
		return false
	if merc != escort(state):
		return false
	var lead: MercenaryData = RescueSystem.picker(state)
	if lead == null or RescueGrid.is_adjacent(state.pos3(merc), state.pos3(lead)):
		return false
	for e: MercenaryData in state.get_enemies(merc):
		if AutoBattle.can_attack_target(merc, e, state):
			return false
	return true


#True when this merc standing on the exit cell may walk out of the dungeon now.
static func may_leave(merc: MercenaryData, state: BattleState) -> bool:
	var rescue: Dictionary = state.rescue
	if merc == (rescue["captive"] as MercenaryData):
		return bool(rescue["freed"])
	if not fighting(state):
		return bool(rescue["freed"]) or bool(rescue.get("aborted", false))
	if not withdraw_enabled:
		return false
	return posture_of(state, merc) == POSTURE_WITHDRAW or phase(state) == PHASE_DONE \
		or bool(rescue["abandoned"])

