class_name TraitRuntime

#Runtime dispatcher for the on: and while: clauses of lifepath traits.
#Cells parse once per trait name; clauses index once per merc, so a merc with no clauses costs two lookups.

const SCOPE_ROUND      := "round"
const SCOPE_TURN       := "turn"
const SCOPE_ENCOUNTER  := "encounter"
const SCOPE_CONTRACT   := "contract"
const SCOPE_PERMANENT  := "permanent"
const SCOPE_CONTINUOUS := "continuous"
#Bond scope: reverted only when the bond is renewed, never by an encounter or a contract.
const SCOPE_BOND       := "bond"

const MAX_DEPTH := 4

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

#Fallback for the max_ spellings that name a Stats.tsv row; MercGenerator's table is consulted first.
const MAX_STAT_ALIASES: Dictionary = {
	"max_hp": "maximum_hit_points", "max_mp": "maximum_magic_points",
	"max_ep": "maximum_endurance_points",
}

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
static func begin_encounter(state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	if state == null:
		return lines
	for team: Array in state.teams:
		for merc: MercenaryData in team:
			_enc_started.erase(merc)
			if not (_index_for(merc)["while"] as Array).is_empty():
				refresh_continuous(merc, state)
	return lines


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
	var key: String = ConstStates.normalize_token(state_name)
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
			trigger += ":" + ConstStates.normalize_token(parts[i])
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
			return ConstStates.normalize_token(str(ctx.get("damage_type", ""))) == arg.to_lower()
		"contract_type":
			var c: ContractData = _contract(ctx)
			return c != null and ConstStates.normalize_token(c.contract_type) == arg.to_lower()
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
		for other: MercenaryData in run.team:
			if other != null and other.merc_uid == uid:
				return true
		return false
	var state: BattleState = ctx.get("state", null)
	if state == null:
		return false
	for ally: MercenaryData in state.get_allies(merc):
		if ally != null and ally.merc_uid == uid:
			return true
	return false


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
		var key: String = ConstStates.normalize_token(display)
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
				for t: MercenaryData in _resolve_targets(arg, owner, ctx):
					_run_effect(rest, owner, t, ctx, scope, cid, mult, td, to_remove)
			"chance":
				if randi_range(1, 100) <= int(arg.trim_suffix("%")):
					_run_effect(rest, owner, target, ctx, scope, cid, mult, td, to_remove)
			"repeat":
				for _i: int in range(maxi(0, int(arg))):
					_run_effect(rest, owner, target, ctx, scope, cid, mult, td, to_remove)
			"per":
				_run_effect(rest, owner, target, ctx, scope, cid,
					mult * _count_unit(arg, owner, ctx), td, to_remove)
			"lasting":
				var next_scope: String = arg
				if not SCOPES.has(next_scope):
					_warn_once("scope:" + next_scope,
						"%s: lasting:%s has no revert point; using encounter" % [td.trait_name, next_scope])
					next_scope = SCOPE_ENCOUNTER
				_run_effect(rest, owner, target, ctx, next_scope, cid, mult, td, to_remove)
		return
	_apply_leaf(effect, owner, target, ctx, scope, cid, mult, td, to_remove)


static func _resolve_targets(word: String, owner: MercenaryData, ctx: Dictionary) -> Array:
	match word:
		"self":
			return [owner]
		"target":
			var t: MercenaryData = ctx.get("target", null)
			return [t] if t != null else []
		"allies":
			return _allies(owner, ctx)
		"enemies":
			return _enemies(owner, ctx)
		"team":
			var team: Array = _allies(owner, ctx)
			team.append(owner)
			return team
		"random_ally":
			var pool: Array = _allies(owner, ctx)
			if pool.is_empty():
				return []
			return [pool[randi() % pool.size()]]
		"random_enemy":
			var foes: Array = _enemies(owner, ctx)
			if foes.is_empty():
				return []
			return [foes[randi() % foes.size()]]
		"beau":
			var beau: MercenaryData = BeauSystem.partner(owner, ctx)
			return [beau] if beau != null else []
	_warn_once("target:" + word, "unimplemented target '%s'" % word)
	return []


static func _allies(owner: MercenaryData, ctx: Dictionary) -> Array:
	var state: BattleState = ctx.get("state", null)
	if state != null:
		var live: Array = []
		live.assign(state.get_allies(owner))
		return live
	var run: ContractRun = ctx.get("run", null)
	if run == null:
		return []
	var out: Array = []
	for m: MercenaryData in run.living_team():
		if m != owner:
			out.append(m)
	return out


static func _enemies(owner: MercenaryData, ctx: Dictionary) -> Array:
	var state: BattleState = ctx.get("state", null)
	if state == null:
		return []
	var out: Array = []
	out.assign(state.get_enemies(owner))
	return out


static func _count_unit(unit: String, owner: MercenaryData, ctx: Dictionary) -> int:
	if unit == "conscious_ally":
		var n: int = 0
		for m: MercenaryData in _allies(owner, ctx):
			if not ConstStates.has_state(m, ConstStates.DYING) \
					and not ConstStates.has_state(m, ConstStates.UNCONSCIOUS):
				n += 1
		return n
	_warn_once("per:" + unit, "unimplemented per: unit '%s'" % unit)
	return 0


static func _apply_leaf(effect: String, owner: MercenaryData, target: MercenaryData,
		ctx: Dictionary, scope: String, cid: String, mult: int,
		td: TraitData, to_remove: Array) -> void:
	if effect == "remove_self":
		if not to_remove.has(td):
			to_remove.append(td)
		return
	if effect.begins_with("stat:"):
		_apply_stat(effect, owner, target, ctx, scope, cid, mult, td)
		return
	if effect.begins_with("resource:"):
		_apply_resource(effect, target, ctx, mult, td)
		return
	if effect.begins_with("damage:"):
		_apply_damage(effect, owner, target, ctx, mult, td)
		return
	if effect.begins_with("inflict:"):
		_apply_inflict(effect, owner, target, ctx, td)
		return
	if effect.begins_with("apply:"):
		_apply_state_direct(effect, owner, target, ctx, td)
		return
	if effect.begins_with("grant:random:circumstance:"):
		_apply_circumstance_grant(effect, owner, target, ctx, scope, cid, td)
		return
	if effect.begins_with("remove:random:circumstance:"):
		_apply_circumstance_removal(effect, owner, target, scope, cid, td)
		return
	if effect.begins_with("remove:"):
		_apply_state_removal(effect, target, ctx)
		return
	if effect.begins_with("damage_dealt:"):
		ctx["damage"] = maxi(0, int(ctx.get("damage", 0)) + _amount(effect.get_slice(":", 1)) * mult)
		return
	if effect.begins_with("damage_taken:"):
		var parts: PackedStringArray = effect.split(":")
		var floor_value: int = 0
		if parts.size() >= 4 and parts[2] == "min":
			floor_value = int(parts[3])
		var taken: int = int(ctx.get("damage", 0)) + _amount(parts[1]) * mult
		if int(ctx.get("damage", 0)) > 0:
			ctx["damage"] = maxi(floor_value, taken)
		else:
			ctx["damage"] = maxi(0, taken)
		return
	if effect.begins_with("reward:"):
		_apply_reward(effect, ctx, td)
		return
	_warn_once("effect:" + effect.get_slice(":", 0),
		"%s: unimplemented effect '%s'" % [td.trait_name, effect])


static func _amount(token: String) -> int:
	var op: int = -1 if token.begins_with("-") else 1
	return int(token.trim_prefix("+").trim_prefix("-")) * op


static func _apply_stat(effect: String, owner: MercenaryData, target: MercenaryData,
		ctx: Dictionary, scope: String, cid: String, mult: int, td: TraitData) -> void:
	var parts: PackedStringArray = effect.split(":")
	if parts.size() != 3:
		_warn_once("effect:" + effect, "%s: unimplemented stat form '%s'" % [td.trait_name, effect])
		return
	var key: String = _resolve_stat_key(parts[1], ctx, td)
	if key == "":
		return
	var alias: String = str(MercGenerator.MAX_STAT_ALIASES.get(key, MAX_STAT_ALIASES.get(key, "")))
	var kind: String = "flat"
	if alias != "":
		key = alias
	elif key.begins_with("max_"):
		kind = "max"
	var value: String = parts[2]
	var sign_op: float = -1.0 if value.begins_with("-") else 1.0
	var delta: float = 0.0
	if value.ends_with("%"):
		var pct: float = float(value.trim_suffix("%").trim_prefix("+").trim_prefix("-"))
		delta = pct * sign_op * float(mult) / 100.0
		if kind == "max":
			delta = round(_stat_value(target, key) * delta)
		else:
			kind = "percent"
	else:
		delta = float(value.trim_prefix("+").trim_prefix("-")) * sign_op * float(mult)
	if is_zero_approx(delta):
		return
	var bond_max_hp: bool = scope == SCOPE_BOND and key == "maximum_hit_points"
	if bond_max_hp:
		delta = maxf(delta, 1.0 - _stat_value(target, key))
		if is_zero_approx(delta):
			return
	var applied: float = _stat_delta(target, key, kind, delta)
	if bond_max_hp:
		_follow_max_hp(target)
	if scope != SCOPE_PERMANENT and not is_zero_approx(applied):
		_record(owner, {"m": target, "kind": kind, "key": key, "delta": applied,
			"scope": scope, "cid": cid})


#A lowered maximum pulls current HP down with it, but a bond loss never kills a living merc.
static func _follow_max_hp(merc: MercenaryData) -> void:
	if merc == null or merc.current_hp <= 0:
		return
	var max_hp: int = int(_stat_value(merc, "maximum_hit_points"))
	merc.current_hp = maxi(1, mini(merc.current_hp, max_hp))


static func _resolve_stat_key(raw: String, ctx: Dictionary, td: TraitData) -> String:
	match raw:
		"contract_core":
			return _contract_core(ctx)
		"random_core":
			return CORE_STATS[randi() % CORE_STATS.size()]
		"random_stat", "random_environ", "random_creature", "random_weapon_type":
			_warn_once("stat_key:" + raw,
				"%s: key selector '%s' has no declared pool" % [td.trait_name, raw])
			return ""
	return raw


static func _stat_value(merc: MercenaryData, key: String) -> float:
	if key.begins_with("max_"):
		return float(merc.max_stats.get(key, 0))
	return float(merc.stats.get(key, 0.0))


#Writes one stat delta through StatCalculator and returns what was applied, so the revert matches.
static func _stat_delta(merc: MercenaryData, key: String, kind: String, delta: float) -> float:
	if kind == "max":
		var whole: int = int(round(delta))
		if whole == 0:
			return 0.0
		StatCalculator.prime(merc)
		merc.max_stats[key] = int(merc.max_stats.get(key, 0)) + whole
		StatCalculator.refresh(merc)
		return float(whole)
	if kind == "percent":
		StatCalculator.add_percent(merc, key, delta)
	else:
		StatCalculator.add_flat(merc, key, delta)
	StatCalculator.refresh(merc)
	return delta


static func _apply_resource(effect: String, target: MercenaryData, ctx: Dictionary, mult: int,
		td: TraitData) -> void:
	var parts: PackedStringArray = effect.split(":")
	if parts.size() != 3 or not RESOURCE_FIELDS.has(parts[1]):
		_warn_once("effect:" + effect, "%s: unimplemented resource '%s'" % [td.trait_name, effect])
		return
	if target == null:
		return
	var amount: int = _amount(parts[2]) * mult
	if parts[1] == "excess_ep_or_mp" or EXCESS_POOLS.has(parts[1]):
		_apply_excess(parts[1], target, ctx, amount, td)
		return
	var field: String = RESOURCE_FIELDS[parts[1]]
	target.set(field, maxi(0, int(target.get(field)) + amount))


#One of the three capped pools; ExcessPool holds the 0..CAP clamp and returns what it applied.
static func _apply_excess(key: String, target: MercenaryData, ctx: Dictionary, amount: int,
		td: TraitData) -> void:
	var kind: String = str(EXCESS_POOLS.get(key, ""))
	if kind == "":
		kind = ExcessPool.choose_ep_or_mp(target)
	var pool: String = "Excess " + kind.to_upper()
	var delta: int = ExcessPool.add(target, kind, amount)
	var text: String = ""
	if delta > 0:
		text = "  %s gains %d %s (%s)." % [target.merc_name, delta, pool, td.trait_name]
	elif delta < 0:
		text = "  %s loses %d %s (%s)." % [target.merc_name, -delta, pool, td.trait_name]
	elif amount > 0:
		text = "  %s already holds %d %s (%s)." % [target.merc_name,
			ExcessPool.amount(target, kind), pool, td.trait_name]
	if text == "":
		return
	var lines: Array[String] = [text]
	_emit(ctx, lines)


static func _apply_damage(effect: String, owner: MercenaryData, target: MercenaryData,
		ctx: Dictionary, mult: int, td: TraitData) -> void:
	var parts: PackedStringArray = effect.split(":")
	if parts.size() != 3:
		_warn_once("effect:" + effect, "%s: unimplemented damage form '%s'" % [td.trait_name, effect])
		return
	var type_name: String = parts[1].capitalize()
	var amount: int = int(parts[2]) * mult
	if amount <= 0 or target == null or not BattleState._is_alive(target):
		return
	var state: BattleState = ctx.get("state", null)
	if state != null:
		_emit(ctx, CombatApplicator.apply_damage(owner, target, amount, type_name, state))
		return
	#Outside an encounter only a will_hp_floor type is safe: nothing here can confirm a death.
	if not bool(ConstDamageTypes.get_type(type_name).get("will_hp_floor", false)):
		_warn_once("damage_outside:" + type_name,
			"%s: %s damage outside an encounter has no applier" % [td.trait_name, type_name])
		return
	DefenseSystem.resolve(target, amount, type_name, 0, true, true)


static func _apply_inflict(effect: String, owner: MercenaryData, target: MercenaryData,
		ctx: Dictionary, td: TraitData) -> void:
	var state: BattleState = ctx.get("state", null)
	if state == null:
		_warn_once("inflict_outside:" + effect,
			"%s: '%s' outside an encounter has no applier" % [td.trait_name, effect])
		return
	if target == null or not BattleState._is_alive(target):
		return
	var state_name: String = ConstStates.state_from_token(effect.substr(8))
	if state_name == "":
		_warn_once("effect:" + effect, "%s: unknown state in '%s'" % [td.trait_name, effect])
		return
	if not ConstStates.has_inflict_default(state_name):
		_warn_once("no_default:" + state_name,
			"%s: %s has no States.tsv Inflict Default" % [td.trait_name, state_name])
		return
	_emit(ctx, StateInfliction.inflict_default(target, state_name, owner, state))


#Puts a state on the target with no resist roll and no States.tsv Inflict Default.
static func _apply_state_direct(effect: String, owner: MercenaryData, target: MercenaryData,
		ctx: Dictionary, td: TraitData) -> void:
	if target == null or not BattleState._is_alive(target):
		return
	var parsed: Dictionary = ConstStates.parse_apply_token(effect)
	var states: Array = parsed["states"]
	if states.is_empty():
		_warn_once("effect:" + effect, "%s: apply: unknown state in '%s'" % [td.trait_name, effect])
		return
	var error: String = str(parsed["error"])
	if error == "unreadable duration":
		_warn_once("effect:" + effect, "%s: apply: unreadable duration in '%s'" % [td.trait_name, effect])
	elif error == "unknown until":
		_warn_once("effect:" + effect, "%s: apply: unknown until in '%s'" % [td.trait_name, effect])
	var duration: String = str(parsed["duration"])
	var removal: Array[String] = []
	removal.assign(parsed["removal"])
	for state_name: String in states:
		if not ConstStates.apply_state(target, state_name, owner, "", "trait:" + td.trait_name, removal):
			continue
		if duration != "":
			_set_apply_timer(target, state_name, duration, ctx)
		var lines: Array[String] = ["  %s gains %s." % [target.merc_name, state_name]]
		_emit(ctx, lines)
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("APPLY: %s %s source=%s trait=%s" % [target.merc_name,
				state_name, owner.merc_name if owner != null else "none", td.trait_name])


#Round timers need the encounter; outside one only an hour or day scale reaches the campaign clock.
static func _set_apply_timer(target: MercenaryData, state_name: String, duration: String,
		ctx: Dictionary) -> void:
	var state: BattleState = ctx.get("state", null)
	if state != null:
		state.set_state_timer(target, state_name,
			StateInfliction.expiry_round(state, StateInfliction.parse_duration(duration)), "")
		return
	if StateInfliction.campaign_minutes(duration) > 0:
		StateInfliction.set_campaign_timer(target, state_name, duration)


static func _apply_state_removal(effect: String, target: MercenaryData, ctx: Dictionary) -> void:
	var state: BattleState = ctx.get("state", null)
	for token: String in effect.substr(7).split(","):
		var state_name: String = ConstStates.state_from_token(token.strip_edges())
		if state_name == "" or not ConstStates.has_state(target, state_name):
			continue
		ConstStates.remove_state(target, state_name)
		if state != null:
			StateInfliction.note_removed(target, state_name, state, "trait")


static func _circumstance_pool(filter: String, ctx: Dictionary) -> Array:
	var pool: Array = []
	if filter == "any":
		pool.assign(ConstCircumstances.ALL)
		return pool
	if filter == "contract_relevant":
		var c: ContractData = _contract(ctx)
		if c == null:
			return pool
		for display: String in c.circumstance_boosts:
			if ConstCircumstances.DATA.has(display):
				pool.append(display)
		return pool
	for display2: String in ConstCircumstances.ALL:
		var data: Dictionary = ConstCircumstances.DATA[display2]
		var circ: String = ConstStates.normalize_token(str(data.get("circumstance_name", "")))
		var stat: String = ConstStates.normalize_token(str(data.get("stat", "")))
		if filter == circ or filter == stat or filter == circ + "_" + stat:
			pool.append(display2)
	return pool


static func _apply_circumstance_grant(effect: String, owner: MercenaryData, target: MercenaryData,
		ctx: Dictionary, scope: String, cid: String, td: TraitData) -> void:
	var parts: PackedStringArray = effect.split(":")
	if parts.size() != 5:
		_warn_once("effect:" + effect,
			"%s: unimplemented circumstance grant '%s'" % [td.trait_name, effect])
		return
	var pool: Array = _circumstance_pool(parts[3], ctx)
	var available: Array = []
	for display: String in pool:
		if not target.blocked_circumstances.has(display) \
				and not bool(target.circumstance_flags.get(display, false)):
			available.append(display)
	if available.is_empty():
		return
	available.shuffle()
	for i: int in range(mini(int(parts[4]), available.size())):
		_set_circumstance(owner, target, available[i], true, scope, cid)


static func _apply_circumstance_removal(effect: String, owner: MercenaryData, target: MercenaryData,
		scope: String, cid: String, td: TraitData) -> void:
	var parts: PackedStringArray = effect.split(":")
	var except_key: String = ""
	var count: int = 0
	if parts.size() == 5:
		count = int(parts[4])
	elif parts.size() == 7 and parts[4] == "except":
		except_key = parts[5]
		count = int(parts[6])
	else:
		_warn_once("effect:" + effect,
			"%s: unimplemented circumstance removal '%s'" % [td.trait_name, effect])
		return
	var filter: String = parts[3]
	var allowed: Array = _circumstance_pool(filter, {}) if filter != "any" else []
	var held: Array = []
	for display: String in target.circumstance_flags:
		if not bool(target.circumstance_flags[display]):
			continue
		if except_key != "" and _circumstance_pool(except_key, {}).has(display):
			continue
		if filter != "any" and not allowed.has(display):
			continue
		held.append(display)
	if held.is_empty():
		return
	held.shuffle()
	for i: int in range(mini(count, held.size())):
		_set_circumstance(owner, target, held[i], false, scope, cid)


static func _set_circumstance(owner: MercenaryData, target: MercenaryData, display: String,
		value: bool, scope: String, cid: String) -> void:
	StatCalculator.prime(target)
	target.circumstance_flags[display] = value
	StatCalculator.refresh(target)
	if scope != SCOPE_PERMANENT:
		_record(owner, {"m": target, "kind": "circ", "key": display, "delta": 1.0 if value else 0.0,
			"scope": scope, "cid": cid})


static func _apply_reward(effect: String, ctx: Dictionary, td: TraitData) -> void:
	var run: ContractRun = ctx.get("run", null)
	var parts: PackedStringArray = effect.split(":")
	if run == null or parts.size() != 3:
		_warn_once("effect:" + effect, "%s: reward: needs a contract run" % td.trait_name)
		return
	var low: float = float(parts[1].trim_suffix("%").trim_prefix("+"))
	var high: float = float(parts[2].trim_suffix("%").trim_prefix("+"))
	if high < low:
		var swap: float = low
		low = high
		high = swap
	var pct: float = randf_range(low, high)
	var before: int = run.reward_paid
	run.reward_paid = int(round(float(before) * (1.0 + pct / 100.0)))
	run.emit("CONTRACT REWARD: %s +%.0f%% (%d -> %d)" % [td.trait_name, pct, before, run.reward_paid])


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
	_stat_delta(m, str(rec["key"]), str(rec["kind"]), -float(rec["delta"]))


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
