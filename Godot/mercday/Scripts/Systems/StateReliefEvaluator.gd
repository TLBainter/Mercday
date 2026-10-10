class_name StateReliefEvaluator

#Scores removing a state from the merc itself or from an adjacent ally against the AP it costs.
const HORIZON_ROUNDS := 3
const INTERACT_AP := 2

#Relief action key -> the removal token it satisfies and the cost key it is charged under.
const RELIEF_ACTIONS := {
	"get_up": {"token": "action:get_up", "cost_key": "get_up"},
	"break_free": {"token": "action:break_free", "cost_key": "break_free"},
	"end_burning": {"token": "interact:end_burning", "cost_key": "Interact"},
}

#merc -> {"ctx": Dictionary, "verdict": Dictionary}: the scoring pass and the dispatch pass share one scan.
static var _aid_cache: Dictionary = {}


static func clear_aid_cache() -> void:
	_aid_cache.clear()


#Share of a turn this one state costs the merc each round, 0..1.
static func per_round_hindrance(merc: MercenaryData, state_name: String, ctx: Dictionary) -> float:
	if not ConstStates.DATA.has(state_name):
		return 0.0
	var stacks := maxi(1, ConstStates.get_count(merc, state_name))
	var total := 0.0
	for token: String in ConstStates.DATA[state_name]["effects"]:
		var parts := StateTokens.token_parts(token)
		if parts.is_empty():
			continue
		var w := _token_weight(merc, parts, ctx)
		if parts.has("per_stack"):
			w *= float(stacks)
		total += w
	return clampf(total, 0.0, 1.0)


static func _token_weight(merc: MercenaryData, parts: PackedStringArray, ctx: Dictionary) -> float:
	match parts[0]:
		"skip_turn":
			return 1.0
		"block":
			return _block_weight(parts)
		"dot":
			if parts.size() < 3:
				return 0.0
			return clampf(StateTokens.num(parts, 2) / maxf(1.0, float(merc.current_hp)), 0.0, 1.0)
		"suffocate":
			return clampf(1.0 / maxf(1.0, float(merc.current_hp)), 0.0, 1.0)
		"check":
			return _check_weight(parts)
		"attack":
			return _attack_weight(merc, parts)
		"attack_vs":
			return _attack_vs_weight(merc, parts, ctx)
		"move":
			if parts.size() >= 2 and parts[1] == "max_paces":
				return 0.3
			if parts.size() >= 3 and parts[1] == "block_toward" and parts[2] == "source":
				return 0.2
			if parts.size() >= 3 and parts[1] == "away_from" and parts[2] == "source":
				return 0.1
			return 0.0
		"stat":
			if parts.size() >= 3 and parts[1] == "speed" and parts[2] == "=0":
				return 0.3
			if parts.size() >= 3 and parts[1] == "avoid" and parts[2].begins_with("-"):
				return 0.2
			return 0.0
		"cost":
			if parts.size() >= 2 and parts[1] == "ap":
				return 0.6
			if parts.size() >= 2 and parts[1] == "ep":
				return 0.2
			return 0.0
		"damage_taken":
			if parts.size() >= 2 and parts[1] == "direct":
				return 0.4
			return 0.15 * StateTokens.num(parts, 1)
		"target":
			if parts.size() >= 3 and parts[1] == "block" and parts[2] == "source":
				return 0.3
			return 0.0
		"healing":
			return 0.1
	return 0.0


static func _block_weight(parts: PackedStringArray) -> float:
	var subject := PackedStringArray()
	for i: int in range(1, parts.size()):
		if parts[i] == "except":
			break
		subject.append(parts[i])
	match ":".join(subject):
		"action:all":
			return 1.0
		"action:move":
			return 0.5
		"action:attack":
			return 0.8
		"spend:ap":
			return 1.0
		"spend:ep":
			return 0.2
	return 0.0


static func _check_weight(parts: PackedStringArray) -> float:
	if parts.size() < 3 or parts[1].begins_with("tag:"):
		return 0.0
	match parts[2]:
		"auto_fail":
			return 0.3
		"flaw":
			return 0.15 * StateTokens.num(parts, 3)
		"enhance":
			return -0.1 * StateTokens.num(parts, 3)
	return -0.005 * StateTokens.num(parts, 2)


static func _attack_weight(merc: MercenaryData, parts: PackedStringArray) -> float:
	if parts.size() < 4 or parts[2] != "flaw" or not _holds_kind(merc, parts[1]):
		return 0.0
	return 0.25 * StateTokens.num(parts, 3)


static func _attack_vs_weight(merc: MercenaryData, parts: PackedStringArray, ctx: Dictionary) -> float:
	if parts.size() < 4:
		return 0.0
	var base := 0.0
	if parts[2] == "enhance":
		base = 0.25 * StateTokens.num(parts, 3)
	elif parts[2] == "flaw":
		base = -0.1 * StateTokens.num(parts, 3)
	else:
		return 0.0
	return base * _vs_scale(merc, parts[1], ctx)


#Melee exposure counts more with an enemy in reach; ranged exposure counts nothing without a shooter.
static func _vs_scale(merc: MercenaryData, spec: String, ctx: Dictionary) -> float:
	var kinds := PackedStringArray(["melee", "ranged"]) if spec == "all" else spec.split(",")
	if kinds.is_empty():
		return 1.0
	var scale := 0.0
	for k: String in kinds:
		match k:
			"melee":
				scale = maxf(scale, 1.5 if _enemy_adjacent(merc, ctx) else 1.0)
			"ranged":
				scale = maxf(scale, 1.0 if _has_ranged_enemy(merc, ctx) else 0.0)
			_:
				scale = maxf(scale, 1.0)
	return scale


static func _holds_kind(merc: MercenaryData, spec: String) -> bool:
	if spec == "all":
		return true
	var w: WeaponData = merc.equipped_weapon
	for k: String in spec.split(","):
		match k:
			"ranged":
				if w != null and w.is_ranged:
					return true
			"thrown":
				if w != null and w.is_throwable:
					return true
			"melee":
				if w == null or not w.is_ranged:
					return true
	return false


static func _enemy_list(merc: MercenaryData, ctx: Dictionary) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	if ctx.has("enemies"):
		for e: MercenaryData in ctx["enemies"]:
			out.append(e)
		return out
	var state: BattleState = ctx.get("state")
	if state != null:
		out = state.get_enemies(merc)
	return out


static func _enemy_adjacent(merc: MercenaryData, ctx: Dictionary) -> bool:
	var state: BattleState = ctx.get("state")
	if state == null:
		return false
	for e: MercenaryData in _enemy_list(merc, ctx):
		if state.distance_to(merc, e) <= 1:
			return true
	return false


static func _has_ranged_enemy(merc: MercenaryData, ctx: Dictionary) -> bool:
	for e: MercenaryData in _enemy_list(merc, ctx):
		if e.equipped_weapon != null and e.equipped_weapon.is_ranged:
			return true
	return false


#Rounds the state is still expected to run, capped at the planning horizon.
static func rounds_left(merc: MercenaryData, state_name: String, state: BattleState) -> int:
	var timer := state.get_state_timer(merc, state_name)
	var expires := int(timer.get("expires", 0))
	if timer.is_empty() or expires <= 0:
		return HORIZON_ROUNDS
	return clampi(expires - state.round_number + 1, 1, HORIZON_ROUNDS)


#Chance the state shakes itself off at the end of a turn; 0 when it carries no End Turn resist.
static func end_turn_chance(merc: MercenaryData, state_name: String, state: BattleState) -> float:
	var timer := state.get_state_timer(merc, state_name)
	var spec := StateInfliction.parse_resist(str(timer.get("remove", "")))
	if spec.is_empty() or str(spec["attempt"]) != StateInfliction.ATTEMPT_END_TURN:
		return 0.0
	return StateInfliction.resist_chance(merc, spec, state_name)


static func hindrance(merc: MercenaryData, state_name: String, state: BattleState, ctx: Dictionary) -> float:
	var per_round := per_round_hindrance(merc, state_name, ctx)
	var p := end_turn_chance(merc, state_name, state)
	var left := rounds_left(merc, state_name, state)
	var expected := 0.0
	var carry := 1.0
	for _k: int in left:
		expected += carry
		carry *= (1.0 - p)
	return clampf(per_round * expected / float(HORIZON_ROUNDS), 0.0, 1.0)


#Chance this relief attempt ends the state; the actor is the helper when aiding.
#A state the cavern holds up ends by leaving the cell, never by an action.
static func removal_chance(actor: MercenaryData, target: MercenaryData, state_name: String,
		state: BattleState) -> float:
	if CavernRules.is_cavern_sourced(target, state_name):
		return 0.0
	if ConstStates.has_removal(state_name, "action:get_up"):
		return 1.0
	if ConstStates.has_removal(state_name, "action:break_free"):
		var check_def := SpecialActionSystem.break_free_def()
		var source := SpecialActionSystem.break_free_opponent(target, state_name, state)
		if source != null:
			return CheckSystem.opposed_win_chance(target, check_def, source,
				SpecialActionSystem.break_free_def())
		var default_spec := ConstStates.inflict_default(state_name)
		if not default_spec.is_empty():
			var spec := StateInfliction.parse_resist(str(default_spec["inflict"]))
			if not spec.is_empty():
				return StateInfliction.resist_chance(target, spec, state_name)
		return CheckSystem.expected_success_chance(target, check_def, 1)
	if ConstStates.has_removal(state_name, "interact:"):
		var spec := StateInfliction.parse_resist(
			str(state.get_state_timer(target, state_name).get("remove", "")))
		if spec.is_empty():
			return 1.0
		return StateInfliction.resist_chance(actor, spec, state_name, 0,
			StateInfliction.support_enhancements(actor, target, spec), target)
	return 0.0


#Value of the best other use of the AP the relief would spend; a quarter when that use still fits after it.
static func alternative(merc: MercenaryData, ctx: Dictionary, relief_cost: int) -> float:
	var state: BattleState = ctx.get("state")
	if state == null:
		return 0.05
	var valid: Array = ctx.get("valid_targets", [])
	var attack_cost := state.get_cost(merc, "Attack", int(ctx.get("attack_base_ap", 3)))
	if not valid.is_empty() and not StateEffects.is_blocked(merc, "action:attack") \
			and state.can_afford(merc, attack_cost):
		var best := 0.0
		for t: MercenaryData in valid:
			best = maxf(best, WeaponEvaluator.estimate_kill_likelihood(merc, t))
		var base := 0.35 + 0.35 * best
		if merc.current_ap + merc.excess_ap - relief_cost >= attack_cost:
			base *= 0.25
		return base
	if not (ctx.get("enemies", []) as Array).is_empty() and not StateEffects.is_blocked(merc, "action:move"):
		var move_cost := state.move_cost(merc, "Move Close", int(ctx.get("move_base_ap", 2)))
		if merc.current_ap + merc.excess_ap - relief_cost >= move_cost:
			return 0.25 * 0.25
		return 0.25
	return 0.05


#How the removal sets the merc up over the next rounds, -0.3..0.3.
static func setup(merc: MercenaryData, state_name: String, ctx: Dictionary) -> float:
	var state: BattleState = ctx.get("state")
	var value := 0.0
	if state_name == ConstStates.DEPOSED:
		var adjacent := 0
		if state != null:
			for e: MercenaryData in _enemy_list(merc, ctx):
				if state.distance_to(merc, e) <= 1:
					adjacent += 1
		if adjacent > 0:
			value += minf(0.15 * float(adjacent), 0.3)
		elif _has_ranged_enemy(merc, ctx):
			value -= 0.1
	elif state_name == ConstStates.GRAPPLED or state_name == ConstStates.INHIBITED \
			or state_name == ConstStates.SUFFOCATING:
		var source := ConstStates.get_source(merc, state_name)
		if source != null and BattleState._is_alive(source) and state != null \
				and state.distance_to(merc, source) <= 1:
			value += 0.2
		if state_name == ConstStates.SUFFOCATING:
			value += 0.1
	elif state_name == ConstStates.BURNING:
		var dot_amount := 0
		for d: Dictionary in StateEffects.dot_effects(merc):
			if str(d["state"]) == state_name:
				dot_amount += int(d["amount"])
		if dot_amount > 0 and merc.current_hp <= 3 * dot_amount:
			value += 0.3
		elif state != null:
			value += 0.1 * float(rounds_left(merc, state_name, state))
	if MovementDecider.is_in_danger(merc) and _has_exposure_token(state_name):
		value += 0.2
	return clampf(value, -0.3, 0.3)


static func _has_exposure_token(state_name: String) -> bool:
	if not ConstStates.DATA.has(state_name):
		return false
	for token: String in ConstStates.DATA[state_name]["effects"]:
		var parts := StateTokens.token_parts(token)
		if parts.is_empty():
			continue
		if parts[0] == "damage_taken":
			return true
		if parts[0] == "attack_vs" and parts.size() >= 3 and parts[2] == "enhance":
			return true
	return false


#Verdict on the merc removing its own state with get_up, break_free or end_burning.
static func self_relief(merc: MercenaryData, action_key: String, ctx: Dictionary) -> Dictionary:
	var state: BattleState = ctx.get("state")
	if state == null or not RELIEF_ACTIONS.has(action_key):
		return {}
	var token := str(RELIEF_ACTIONS[action_key]["token"])
	var best_name := ""
	var best_hind := -1.0
	for sname: String in ConstStates.held_state_names(merc):
		if not ConstStates.has_removal(sname, token):
			continue
		if CavernRules.is_cavern_sourced(merc, sname):
			continue
		var h := hindrance(merc, sname, state, ctx)
		if h > best_hind:
			best_hind = h
			best_name = sname
	if best_name == "":
		return {}
	var cost := state.get_cost(merc, str(RELIEF_ACTIONS[action_key]["cost_key"]), INTERACT_AP)
	if not state.can_afford(merc, cost):
		return {}
	var chance := removal_chance(merc, merc, best_name, state)
	var setup_value := setup(merc, best_name, ctx)
	var alt := alternative(merc, ctx, cost)
	var score := (best_hind + setup_value) * chance
	var verdict := {"state": best_name, "hindrance": best_hind, "chance": chance, "setup": setup_value,
		"alt": alt, "score": score, "act": score >= alt}
	log_relief(merc, verdict, action_key)
	return verdict


#Best ally whose Interact-removable state is worth this merc spending its own AP on.
static func best_aid(merc: MercenaryData, ctx: Dictionary) -> Dictionary:
	var verdict := _best_aid_verdict(merc, ctx)
	log_relief(merc, verdict, "aid_ally")
	return verdict


static func _best_aid_verdict(merc: MercenaryData, ctx: Dictionary) -> Dictionary:
	var cached: Dictionary = _aid_cache.get(merc, {})
	if is_same(cached.get("ctx"), ctx):
		var hit: Dictionary = cached["verdict"]
		return hit
	var fresh := _scan_aid_verdict(merc, ctx)
	_aid_cache[merc] = {"ctx": ctx, "verdict": fresh}
	return fresh


static func _scan_aid_verdict(merc: MercenaryData, ctx: Dictionary) -> Dictionary:
	var state: BattleState = ctx.get("state")
	if state == null:
		return {}
	if StateEffects.is_blocked(merc, "action:all") or StateEffects.is_blocked(merc, "spend:ap"):
		return {}
	var cost := state.get_cost(merc, "Interact", INTERACT_AP)
	if not state.can_afford(merc, cost):
		return {}
	var allies: Array = ctx["allies"] if ctx.has("allies") else state.get_allies(merc)
	var move_locked := StateEffects.is_blocked(merc, "action:move")
	var reach_limit := 2 * PaceBudget.pace_per_move(merc)
	var my_floor := state.get_floor(merc)
	var best: Dictionary = {}
	for ally: MercenaryData in allies:
		if ally == null or ally == merc or ally.is_dead or ally.off_field:
			continue
		if state.get_floor(ally) != my_floor:
			continue
		var dist := state.distance_to(merc, ally)
		if dist > reach_limit or (dist > 1 and move_locked):
			continue
		var max_hp := maxf(1.0, float(ally.stats.get("maximum_hit_points", 1)))
		var ally_value := clampf(0.5 + 0.5 * clampf(float(ally.current_hp) / max_hp, 0.0, 1.0), 0.0, 1.0)
		if ally.weapon_drawn and ally.equipped_weapon != null:
			ally_value = minf(ally_value * 1.2, 1.0)
		var reach := 0.0 if dist <= 1 else 0.2 + 0.05 * float(dist - 1)
		var setup_ally := 0.0
		for e: MercenaryData in _enemy_list(ally, ctx):
			if state.distance_to(ally, e) <= 1:
				setup_ally = 0.15
				break
		for sname: String in ConstStates.held_state_names(ally):
			var flee_hold := sname == ConstStates.TERRIFIED and FleeSystem.is_flee_terrified(ally)
			if not flee_hold and not ConstStates.has_removal(sname, "interact:"):
				continue
			if CavernRules.is_cavern_sourced(ally, sname):
				continue
			var h := 1.0 if flee_hold else hindrance(ally, sname, state, ctx)
			var chance := 1.0 if flee_hold else removal_chance(merc, ally, sname, state)
			var score := (h * ally_value + setup_ally) * chance - reach
			if best.is_empty() or score > float(best["score"]):
				best = {"ally": ally, "state": sname, "hindrance": h, "chance": chance,
					"reach": reach, "setup": setup_ally, "dist": dist, "score": score}
	if best.is_empty():
		return {}
	var alt := alternative(merc, ctx, cost)
	best["alt"] = alt
	best["act"] = float(best["score"]) >= alt
	best["adjacent"] = int(best["dist"]) <= 1
	return best


#The decision dict that carries out the aid: Interact when adjacent, otherwise walk to the ally.
static func aid_decision(merc: MercenaryData, ctx: Dictionary) -> Dictionary:
	var verdict := _best_aid_verdict(merc, ctx)
	if verdict.is_empty():
		return {"type": "none"}
	var state: BattleState = ctx["state"]
	var ally: MercenaryData = verdict["ally"]
	if bool(verdict["adjacent"]):
		return {"type": "special", "action_name": "aid_ally", "target": ally,
			"state_name": str(verdict["state"])}
	var cell := MovementExecutor.compute_move_position(
		merc, ally, "Move Close", state, null, 1, _enemy_list(merc, ctx))
	if cell == PathTargeter.NO_CELL:
		return {"type": "none"}
	if not state.can_afford(merc, state.move_cost(merc, "Move Close", int(ctx.get("move_base_ap", 2)))):
		return {"type": "none"}
	return {"type": "move", "action_name": "Move Close", "target": ally, "goal_cell": cell,
		"moves_allowed": 1, "reserve_ap": state.get_cost(merc, "Interact", INTERACT_AP)}


static func log_relief(merc: MercenaryData, verdict: Dictionary, kind: String) -> void:
	if verdict.is_empty() or not EncounterLogger.is_active():
		return
	var ally_text := ""
	if verdict.has("ally"):
		var ally: MercenaryData = verdict["ally"]
		ally_text = " ally=%s dist=%d" % [ally.merc_name, int(verdict.get("dist", 0))]
	EncounterLogger.log_verbose(
		"STATE RELIEF: %s %s %s%s hind=%.2f chance=%.2f setup=%.2f alt=%.2f score=%.2f -> %s" % [
			merc.merc_name, kind, str(verdict["state"]), ally_text,
			float(verdict["hindrance"]), float(verdict["chance"]), float(verdict["setup"]),
			float(verdict["alt"]), float(verdict["score"]),
			"ACT" if bool(verdict["act"]) else "SKIP"])
