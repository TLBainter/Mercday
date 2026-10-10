class_name TraitRuntime

#Runtime dispatcher for the on: and while: clauses of lifepath traits.
#Cells parse once per trait name; the clause index is cached per merc, and every call walks the merc
#perks and drawbacks for the signature that validates that cache, so a merc with no clauses pays the walk.

const SCOPE_ROUND      := "round"
const SCOPE_TURN       := "turn"
const SCOPE_ENCOUNTER  := "encounter"
const SCOPE_CONTRACT   := "contract"
const SCOPE_PERMANENT  := "permanent"
const SCOPE_CONTINUOUS := "continuous"
#Bond scope: reverted only when the bond is renewed, never by an encounter or a contract.
const SCOPE_BOND       := "bond"

const MAX_DEPTH := 4

#Seeded picks index this order; StatCalculator.CORE_STATS keeps its alphabetical order for its own picks.
const CORE_STATS: Array[String] = ["vigor", "dexterity", "cognition", "wile"]
const SCOPES: Array[String] = [SCOPE_ROUND, SCOPE_TURN, SCOPE_ENCOUNTER, SCOPE_CONTRACT,
	SCOPE_PERMANENT, SCOPE_BOND]
const ARG_CONDITIONS: Array[String] = ["wielding", "damage_type", "contract_type", "contract_stat",
	"location", "has_trait"]
const ARG_TRIGGERS: Array[String] = ["state_gained", "ally_state_gained"]
#excess_ep_or_mp carries no field: the pool is chosen per target through ExcessPool.
const RESOURCE_FIELDS: Dictionary = {
	"hp": "current_hp", "ep": "current_ep", "mp": "current_mp",
	"ap": "current_ap", "rep": "current_rep", "excess_ap": "excess_ap",
	"excess_hp": "excess_hp", "excess_ep": "excess_ep", "excess_mp": "excess_mp",
	"excess_ep_or_mp": "",
}
const EXCESS_POOLS: Dictionary = {"excess_hp": "hp", "excess_ep": "ep", "excess_mp": "mp"}

static var _clauses: Dictionary = {}    #trait_name -> Array[Dictionary]; never cleared, cells are static
static var _index: Dictionary = {}      #MercenaryData -> {n, on, while}
static var _reverts: Dictionary = {}    #MercenaryData -> Array of revert records
static var _while_on: Dictionary = {}   #MercenaryData -> {clause_id: bool}
static var _enc_started: Dictionary = {} #MercenaryData -> true once encounter_start has fired
static var _warned: Dictionary = {}
static var _depth: int = 0


#True when the merc holds at least one on: clause for that trigger; the guard every hook site uses.
static func has(merc: MercenaryData, trigger: String) -> bool:
	if merc == null:
		return false
	var on: Dictionary = _index_for(merc)["on"]
	return not on.is_empty() and on.has(trigger)


static func fire(trigger: String, merc: MercenaryData, ctx: Dictionary) -> void:
	if merc == null:
		return
	var on: Dictionary = _index_for(merc)["on"]
	if on.is_empty():
		return
	if not on.has(trigger):
		return
	var bucket: Array = on[trigger]
	if bucket.is_empty():
		return
	if _depth >= MAX_DEPTH:
		_warn_once("depth:" + trigger, "effect recursion stopped at depth %d on %s" % [_depth, trigger])
		return
	_depth += 1
	var to_remove: Array = []
	for entry: Dictionary in bucket:
		var clause: Dictionary = entry["c"]
		if not _condition_passes(str(clause["cond"]), merc, ctx):
			continue
		_run_effect(str(clause["effect"]), merc, merc, ctx, str(clause["scope"]), "", 1,
			entry["t"], to_remove)
	_depth -= 1
	for td: TraitData in to_remove:
		_remove_trait(merc, td)


#Re-evaluates every while: clause; a clause that flips off is reverted, one that flips on is re-applied.
static func refresh_continuous(merc: MercenaryData, state: BattleState) -> void:
	if merc == null:
		return
	var clauses: Array = _index_for(merc)["while"]
	if clauses.is_empty():
		return
	var ctx: Dictionary = {"state": state}
	var active: Dictionary = _while_on.get(merc, {})
	var to_remove: Array = []
	for entry: Dictionary in clauses:
		var clause: Dictionary = entry["c"]
		var cid: String = clause["id"]
		var on_now: bool = _condition_passes(str(clause["cond"]), merc, ctx)
		var was_on: bool = bool(active.get(cid, false))
		#A per: clause is recomputed every pass because its multiplier moves with the ally count.
		if on_now == was_on and not (on_now and bool(clause["dyn"])):
			continue
		if was_on:
			_revert_cid(merc, cid)
			active[cid] = false
			was_on = false
		if on_now and not was_on:
			_run_effect(str(clause["effect"]), merc, merc, ctx, SCOPE_CONTINUOUS, cid, 1,
				entry["t"], to_remove)
			active[cid] = true
	_while_on[merc] = active
	for td: TraitData in to_remove:
		_remove_trait(merc, td)


#Encounter and turn entry points

#Seeds the while: clauses for every merc on the field; encounter_start waits for that merc's first turn.
static func begin_encounter(state: BattleState) -> void:
	if state == null:
		return
	for team: Array in state.teams:
		for merc: MercenaryData in team:
			_enc_started.erase(merc)
			if not (_index_for(merc)["while"] as Array).is_empty():
				refresh_continuous(merc, state)


#Fires encounter_start once per merc per encounter, after start_of_turn has written the turn's AP.
static func on_turn_start(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	if merc == null or _enc_started.has(merc):
		return
	_enc_started[merc] = true
	if has(merc, "encounter_start"):
		fire("encounter_start", merc, {"state": state, "lines": lines})


static func end_encounter(state: BattleState) -> void:
	if state == null:
		return
	for team: Array in state.teams:
		for merc: MercenaryData in team:
			revert_scope(merc, SCOPE_TURN)
			revert_scope(merc, SCOPE_ROUND)
			revert_scope(merc, SCOPE_CONTINUOUS)
			revert_scope(merc, SCOPE_ENCOUNTER)
			_while_on.erase(merc)
			_enc_started.erase(merc)
			_index.erase(merc)


static func on_round_start(state: BattleState, lines: Array[String] = []) -> void:
	if state == null:
		return
	for team: Array in state.teams:
		for merc: MercenaryData in team:
			if not _reverts.is_empty():
				revert_scope(merc, SCOPE_ROUND)
			refresh_continuous(merc, state)
	#Fired after every revert and refresh, so a clause reads the round's settled stats.
	for team2: Array in state.teams:
		for merc2: MercenaryData in team2:
			if BattleState._is_alive(merc2) and has(merc2, "round_start"):
				fire("round_start", merc2, {"state": state, "lines": lines})


static func on_turn_end(merc: MercenaryData, state: BattleState) -> void:
	if merc == null:
		return
	if not _reverts.is_empty():
		revert_scope(merc, SCOPE_TURN)
	refresh_continuous(merc, state)


#The killer's kill clauses and the ally_death broadcast for one confirmed death.
static func on_death(dead: MercenaryData, killer: MercenaryData, state: BattleState,
		lines: Array[String]) -> void:
	if dead == null or state == null:
		return
	if killer != null and killer != dead and has(killer, "kill"):
		fire("kill", killer, {"state": state, "target": dead, "lines": lines})
	for ally: MercenaryData in state.get_allies(dead):
		if has(ally, "ally_death"):
			fire("ally_death", ally, {"state": state, "target": dead, "lines": lines})


#A state that was just applied: the holder's clauses first, then every living ally's.
static func on_state_gained(merc: MercenaryData, state_name: String, state: BattleState,
		lines: Array[String]) -> void:
	if merc == null or state == null:
		return
	var key: String = StateTokens.normalize_token(state_name)
	if has(merc, "state_gained:" + key):
		fire("state_gained:" + key, merc, {"state": state, "lines": lines})
	var ally_key: String = "ally_state_gained:" + key
	for ally: MercenaryData in state.get_allies(merc):
		if has(ally, ally_key):
			fire(ally_key, ally, {"state": state, "target": merc, "lines": lines})


#Contract entry points

static func begin_contract(run: ContractRun) -> void:
	if run == null:
		return
	for merc: MercenaryData in run.team:
		if has(merc, "contract_start"):
			fire("contract_start", merc, {"run": run})


#One contract combat has ended; only mercs still standing after the stabilize pass qualify.
static func on_combat_complete(run: ContractRun, event_name: String) -> void:
	if run == null:
		return
	for merc: MercenaryData in run.living_team():
		if has(merc, "contract_complete_combat"):
			fire("contract_complete_combat", merc, {"run": run, "event": event_name})


#lines catches the clause output of a rest taken with no contract in play; a run emits its own.
static func fire_rest(trigger: String, kind: String, merc: MercenaryData, run: ContractRun,
		lines: Array[String] = []) -> void:
	if merc == null or not has(merc, trigger):
		return
	var ctx: Dictionary = {"kind": kind, "run": run}
	if run == null:
		ctx["lines"] = lines
	fire(trigger, merc, ctx)


static func revert_contract(run: ContractRun) -> void:
	if run == null or _reverts.is_empty():
		return
	for merc: MercenaryData in run.team:
		revert_scope(merc, SCOPE_CONTRACT)


static func end_contract(run: ContractRun) -> void:
	if run == null:
		return
	for merc: MercenaryData in run.team:
		if has(merc, "contract_complete"):
			fire("contract_complete", merc, {"run": run})
	var verdict_trigger: String = ""
	if run.verdict == "Succeeded":
		verdict_trigger = "contract_success"
	elif run.verdict == "Failed":
		verdict_trigger = "contract_failed"
	if verdict_trigger == "":
		return
	for merc: MercenaryData in run.team:
		if has(merc, verdict_trigger):
			fire(verdict_trigger, merc, {"run": run})


#Parsing

static func _index_for(merc: MercenaryData) -> Dictionary:
	var n: int = _trait_sig(merc)
	var cached: Variant = _index.get(merc)
	if cached != null and int((cached as Dictionary)["n"]) == n:
		return cached
	var idx: Dictionary = {"n": n, "on": {}, "while": []}
	_index_traits(merc.perks, idx)
	_index_traits(merc.drawbacks, idx)
	_index[merc] = idx
	return idx


#Identity of the held trait set, so swapping one trait for another still invalidates the index.
static func _trait_sig(merc: MercenaryData) -> int:
	var sig: int = 0
	for td: TraitData in merc.perks:
		sig = sig * 31 + (td.get_instance_id() if td != null else 0)
	for td2: TraitData in merc.drawbacks:
		sig = sig * 31 + (td2.get_instance_id() if td2 != null else 0)
	return sig


static func _index_traits(list: Array[TraitData], idx: Dictionary) -> void:
	for td: TraitData in list:
		if td == null or td.effect_dsl == "":
			continue
		for clause: Dictionary in _cell_clauses(td):
			if str(clause["kind"]) == "on":
				var on: Dictionary = idx["on"]
				var bucket: Array = on.get(clause["trigger"], [])
				bucket.append({"t": td, "c": clause})
				on[clause["trigger"]] = bucket
			else:
				(idx["while"] as Array).append({"t": td, "c": clause})


static func _cell_clauses(td: TraitData) -> Array:
	if _clauses.has(td.trait_name):
		return _clauses[td.trait_name]
	var out: Array = []
	if td.effect_dsl.contains("on:") or td.effect_dsl.contains("while:"):
		for raw: String in td.effect_dsl.split("|"):
			var clause: Dictionary = _parse_clause(raw.strip_edges(), td)
			if not clause.is_empty():
				out.append(clause)
	_clauses[td.trait_name] = out
	return out


static func _parse_clause(text: String, td: TraitData) -> Dictionary:
	if text.begins_with("on:"):
		var parts: PackedStringArray = text.split(":")
		var i: int = 1
		if i >= parts.size():
			return {}
		var trigger: String = parts[i]
		i += 1
		if ARG_TRIGGERS.has(trigger):
			if i >= parts.size():
				return {}
			trigger += ":" + StateTokens.normalize_token(parts[i])
			i += 1
		var cond: Dictionary = _read_condition(parts, i)
		if cond.is_empty():
			_warn_once("clause:" + text, "%s: unreadable condition in '%s'" % [td.trait_name, text])
			return {}
		i = int(cond["next"])
		if i >= parts.size():
			_warn_once("clause:" + text, "%s: on: clause has no effect" % td.trait_name)
			return {}
		return {"kind": "on", "trigger": trigger, "cond": str(cond["cond"]),
			"effect": ":".join(parts.slice(i)), "scope": _default_scope(trigger)}
	if text.begins_with("while:"):
		var wparts: PackedStringArray = text.split(":")
		var wcond: Dictionary = _read_condition(wparts, 1)
		if wcond.is_empty():
			_warn_once("clause:" + text, "%s: unreadable condition in '%s'" % [td.trait_name, text])
			return {}
		var j: int = int(wcond["next"])
		if j >= wparts.size():
			_warn_once("clause:" + text, "%s: while: clause has no effect" % td.trait_name)
			return {}
		var weffect: String = ":".join(wparts.slice(j))
		return {"kind": "while", "cond": str(wcond["cond"]), "id": td.trait_name + "#" + text,
			"effect": weffect, "dyn": weffect.contains("per:")}
	return {}


static func _read_condition(parts: PackedStringArray, i: int) -> Dictionary:
	if i >= parts.size():
		return {}
	var word: String = parts[i]
	if ARG_CONDITIONS.has(word):
		if i + 1 >= parts.size():
			return {}
		return {"cond": word + ":" + parts[i + 1], "next": i + 2}
	return {"cond": word, "next": i + 1}


static func _default_scope(trigger: String) -> String:
	if trigger == "contract_start":
		return SCOPE_CONTRACT
	if trigger.begins_with("contract_"):
		return SCOPE_PERMANENT
	if trigger.begins_with("rest_") or trigger.begins_with("beau_"):
		return SCOPE_PERMANENT
	return SCOPE_ENCOUNTER


#Conditions

static func _condition_passes(cond: String, merc: MercenaryData, ctx: Dictionary) -> bool:
	if cond == "always":
		return true
	#A compound condition: every "+"-joined part must pass.
	if cond.contains("+"):
		for part: String in cond.split("+"):
			if not _condition_passes(part.strip_edges(), merc, ctx):
				return false
		return true
	var head: String = cond.get_slice(":", 0)
	var arg: String = cond.substr(head.length() + 1) if cond.length() > head.length() else ""
	var state: BattleState = ctx.get("state", null)
	match head:
		"first_round":
			return state != null and state.round_number <= 1
		"unarmed":
			var w: WeaponData = merc.equipped_weapon
			return w == null or w.is_virtual
		"wielding":
			return _wielding(merc, arg)
		"self_conscious":
			return BattleState._is_alive(merc) \
				and not ConstStates.has_state(merc, ConstStates.DYING) \
				and not ConstStates.has_state(merc, ConstStates.UNCONSCIOUS)
		"all_enemies_surprised":
			if state == null:
				return false
			var enemies: Array[MercenaryData] = state.get_enemies(merc)
			if enemies.is_empty():
				return false
			for e: MercenaryData in enemies:
				if not ConstStates.has_state(e, ConstStates.SURPRISED):
					return false
			return true
		"enemy_faster":
			if state == null:
				return false
			var speed: float = float(merc.stats.get("speed", 0.0))
			for e2: MercenaryData in state.get_enemies(merc):
				if float(e2.stats.get("speed", 0.0)) > speed:
					return true
			return false
		"damage_type":
			return StateTokens.normalize_token(str(ctx.get("damage_type", ""))) == arg.to_lower()
		"contract_type":
			var c: ContractData = _contract(ctx)
			return c != null and StateTokens.normalize_token(c.contract_type) == arg.to_lower()
		"contract_stat":
			return _contract_core(ctx) == arg.to_lower()
		"location":
			var run: ContractRun = ctx.get("run", null)
			return run != null and run.location != null \
				and LifepathRequirements._location_tokens(run.location).has(arg.to_lower())
		"has_trait":
			return _has_trait(merc, arg)
		"buddy_present":
			return _bond_present(merc, merc.buddy_uid, ctx)
		"buddy_absent":
			return not _bond_present(merc, merc.buddy_uid, ctx)
		"beau_present":
			return _bond_present(merc, merc.beau_uid, ctx)
		"beau_absent":
			return merc.beau_uid > 0 and not _bond_present(merc, merc.beau_uid, ctx)
	_warn_once("cond:" + head, "unimplemented condition '%s'" % cond)
	return false


#True when the merc this bond names is on the contract, or on the field when no run is in play.
static func _bond_present(merc: MercenaryData, uid: int, ctx: Dictionary) -> bool:
	if merc == null or uid <= 0:
		return false
	var run: ContractRun = ctx.get("run", null)
	if run != null:
		return GuildRoster.by_uid(run.team, uid) != null
	var state: BattleState = ctx.get("state", null)
	if state == null:
		return false
	return GuildRoster.by_uid(state.get_allies(merc), uid) != null


static func _wielding(merc: MercenaryData, tag: String) -> bool:
	var w: WeaponData = merc.equipped_weapon
	if w == null:
		return false
	match tag:
		"makeshift":
			return w.fragility > 0
		"melee":
			return not w.is_ranged
		"ranged":
			return w.is_ranged
		"thrown":
			return w.is_throwable
	_warn_once("wielding:" + tag, "unimplemented wielding tag '%s'" % tag)
	return false


static func _has_trait(merc: MercenaryData, name: String) -> bool:
	for td: TraitData in merc.perks:
		if td != null and td.trait_name == name:
			return true
	for td2: TraitData in merc.drawbacks:
		if td2 != null and td2.trait_name == name:
			return true
	return false


static func _contract(ctx: Dictionary) -> ContractData:
	var run: ContractRun = ctx.get("run", null)
	return run.contract if run != null else null


#The core stat a contract is scored on: the highest-weighted core in its stat boosts.
static func _contract_core(ctx: Dictionary) -> String:
	var c: ContractData = _contract(ctx)
	if c == null:
		return ""
	var best: String = ""
	var best_pct: float = -1.0
	for display: String in c.stat_boosts:
		var key: String = StateTokens.normalize_token(display)
		if not CORE_STATS.has(key):
			continue
		var pct: float = float(c.stat_boosts[display])
		if pct > best_pct:
			best_pct = pct
			best = key
	if best == "":
		_warn_once("contract_core:" + c.contract_type,
			"contract type %s declares no core stat boost" % c.contract_type)
	return best


#Effects

static func _run_effect(effect: String, owner: MercenaryData, target: MercenaryData,
		ctx: Dictionary, scope: String, cid: String, mult: int,
		td: TraitData, to_remove: Array) -> void:
	if effect == "" or mult <= 0:
		return
	var head: String = effect.get_slice(":", 0)
	if head == "to" or head == "chance" or head == "repeat" or head == "per" or head == "lasting":
		var arg: String = effect.get_slice(":", 1)
		var rest: String = effect.substr(head.length() + arg.length() + 2)
		if rest == "":
			_warn_once("wrapper:" + effect, "%s: %s: wrapper has no effect" % [td.trait_name, head])
			return
		match head:
			"to":
				for t: MercenaryData in TraitEffects.resolve_targets(arg, owner, ctx):
					_run_effect(rest, owner, t, ctx, scope, cid, mult, td, to_remove)
			"chance":
				if randi_range(1, 100) <= int(arg.trim_suffix("%")):
					_run_effect(rest, owner, target, ctx, scope, cid, mult, td, to_remove)
			"repeat":
				for _i: int in range(maxi(0, int(arg))):
					_run_effect(rest, owner, target, ctx, scope, cid, mult, td, to_remove)
			"per":
				_run_effect(rest, owner, target, ctx, scope, cid,
					mult * TraitEffects.count_unit(arg, owner, ctx), td, to_remove)
			"lasting":
				var next_scope: String = arg
				if not SCOPES.has(next_scope):
					_warn_once("scope:" + next_scope,
						"%s: lasting:%s has no revert point; using encounter" % [td.trait_name, next_scope])
					next_scope = SCOPE_ENCOUNTER
				_run_effect(rest, owner, target, ctx, next_scope, cid, mult, td, to_remove)
		return
	TraitEffects.apply_leaf(effect, owner, target, ctx, scope, cid, mult, td, to_remove)


#Reverts

static func _record(owner: MercenaryData, rec: Dictionary) -> void:
	var recs: Array = _reverts.get(owner, [])
	recs.append(rec)
	_reverts[owner] = recs


static func revert_scope(merc: MercenaryData, scope: String) -> void:
	if merc == null:
		return
	_revert_where(merc, "scope", scope)


static func _revert_cid(merc: MercenaryData, cid: String) -> void:
	_revert_where(merc, "cid", cid)


#Undoes this merc's revert records whose key holds value, newest first.
static func _revert_where(merc: MercenaryData, key: String, value: String) -> void:
	var recs: Array = _reverts.get(merc, [])
	if recs.is_empty():
		return
	for i: int in range(recs.size() - 1, -1, -1):
		var rec: Dictionary = recs[i]
		if str(rec[key]) != value:
			continue
		_undo(rec)
		recs.remove_at(i)
	if recs.is_empty():
		_reverts.erase(merc)


static func _undo(rec: Dictionary) -> void:
	var m: MercenaryData = rec["m"]
	if m == null:
		return
	if str(rec["kind"]) == "circ":
		StatCalculator.prime(m)
		m.circumstance_flags[rec["key"]] = not (float(rec["delta"]) > 0.0)
		StatCalculator.refresh(m)
		return
	TraitEffects.stat_delta(m, str(rec["key"]), str(rec["kind"]), -float(rec["delta"]))


static func _remove_trait(merc: MercenaryData, td: TraitData) -> void:
	if merc.perks.has(td):
		merc.perks.erase(td)
	elif merc.drawbacks.has(td):
		merc.drawbacks.erase(td)
	else:
		return
	_index.erase(merc)
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("TRAIT REMOVED: %s %s" % [merc.merc_name, td.trait_name])


static func _emit(ctx: Dictionary, lines: Array[String]) -> void:
	if lines.is_empty():
		return
	var sink: Variant = ctx.get("lines", null)
	if sink is Array:
		(sink as Array).append_array(lines)
		return
	var run: ContractRun = ctx.get("run", null)
	if run == null:
		return
	for line: String in lines:
		run.emit(line)


static func _warn_once(key: String, message: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning("TraitRuntime: " + message)
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("TRAIT UNIMPLEMENTED: " + message)


#Drops every per-merc record; for tests and a full campaign reset.
static func clear_all() -> void:
	_index.clear()
	_reverts.clear()
	_while_on.clear()
	_enc_started.clear()
