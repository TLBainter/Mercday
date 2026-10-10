class_name TraitEffects


static func resolve_targets(word: String, owner: MercenaryData, ctx: Dictionary) -> Array:
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
	TraitRuntime._warn_once("target:" + word, "unimplemented target '%s'" % word)
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


static func count_unit(unit: String, owner: MercenaryData, ctx: Dictionary) -> int:
	if unit == "conscious_ally":
		var n: int = 0
		for m: MercenaryData in _allies(owner, ctx):
			if not ConstStates.has_state(m, ConstStates.DYING) \
					and not ConstStates.has_state(m, ConstStates.UNCONSCIOUS):
				n += 1
		return n
	TraitRuntime._warn_once("per:" + unit, "unimplemented per: unit '%s'" % unit)
	return 0


static func apply_leaf(effect: String, owner: MercenaryData, target: MercenaryData,
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
		_apply_circumstance_removal(effect, owner, target, ctx, scope, cid, td)
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
	TraitRuntime._warn_once("effect:" + effect.get_slice(":", 0),
		"%s: unimplemented effect '%s'" % [td.trait_name, effect])


static func _amount(token: String) -> int:
	var op: int = -1 if token.begins_with("-") else 1
	return int(token.trim_prefix("+").trim_prefix("-")) * op


#The three part split a leaf effect needs; warns and reports an empty array when the form is wrong.
static func _split3(effect: String, td: TraitData, noun: String) -> PackedStringArray:
	var parts: PackedStringArray = effect.split(":")
	if parts.size() != 3:
		TraitRuntime._warn_once("effect:" + effect, "%s: unimplemented %s '%s'" % [td.trait_name, noun, effect])
		return PackedStringArray()
	return parts


static func _apply_stat(effect: String, owner: MercenaryData, target: MercenaryData,
		ctx: Dictionary, scope: String, cid: String, mult: int, td: TraitData) -> void:
	var parts: PackedStringArray = _split3(effect, td, "stat form")
	if parts.is_empty():
		return
	var key: String = _resolve_stat_key(parts[1], ctx, td)
	if key == "":
		return
	var alias: String = str(TraitDSL.MAX_STAT_ALIASES.get(key, ""))
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
	var bond_max_hp: bool = scope == TraitRuntime.SCOPE_BOND and key == "maximum_hit_points"
	if bond_max_hp:
		delta = maxf(delta, 1.0 - _stat_value(target, key))
		if is_zero_approx(delta):
			return
	var applied: float = stat_delta(target, key, kind, delta)
	if bond_max_hp:
		_follow_max_hp(target)
	if scope != TraitRuntime.SCOPE_PERMANENT and not is_zero_approx(applied):
		TraitRuntime._record(owner, {"m": target, "kind": kind, "key": key, "delta": applied,
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
			return TraitRuntime._contract_core(ctx)
		"random_core":
			return TraitRuntime.CORE_STATS[randi() % TraitRuntime.CORE_STATS.size()]
		"random_stat", "random_environ", "random_creature", "random_weapon_type":
			TraitRuntime._warn_once("stat_key:" + raw,
				"%s: key selector '%s' has no declared pool" % [td.trait_name, raw])
			return ""
	return raw


static func _stat_value(merc: MercenaryData, key: String) -> float:
	if key.begins_with("max_"):
		return float(merc.max_stats.get(key, 0))
	return float(merc.stats.get(key, 0.0))


#Writes one stat delta through StatCalculator and returns what was applied, so the revert matches.
static func stat_delta(merc: MercenaryData, key: String, kind: String, delta: float) -> float:
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
	var parts: PackedStringArray = _split3(effect, td, "resource")
	if parts.is_empty():
		return
	if not TraitRuntime.RESOURCE_FIELDS.has(parts[1]):
		TraitRuntime._warn_once("effect:" + effect, "%s: unimplemented resource '%s'" % [td.trait_name, effect])
		return
	if target == null:
		return
	var amount: int = _amount(parts[2]) * mult
	if parts[1] == "excess_ep_or_mp" or TraitRuntime.EXCESS_POOLS.has(parts[1]):
		_apply_excess(parts[1], target, ctx, amount, td)
		return
	var field: String = TraitRuntime.RESOURCE_FIELDS[parts[1]]
	target.set(field, maxi(0, int(target.get(field)) + amount))


#One of the three capped pools; ExcessPool holds the 0..CAP clamp and returns what it applied.
static func _apply_excess(key: String, target: MercenaryData, ctx: Dictionary, amount: int,
		td: TraitData) -> void:
	var kind: String = str(TraitRuntime.EXCESS_POOLS.get(key, ""))
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
	TraitRuntime._emit(ctx, lines)


static func _apply_damage(effect: String, owner: MercenaryData, target: MercenaryData,
		ctx: Dictionary, mult: int, td: TraitData) -> void:
	var parts: PackedStringArray = _split3(effect, td, "damage form")
	if parts.is_empty():
		return
	var type_name: String = parts[1].capitalize()
	var amount: int = int(parts[2]) * mult
	if amount <= 0 or target == null or not BattleState._is_alive(target):
		return
	var state: BattleState = ctx.get("state", null)
	if state != null:
		TraitRuntime._emit(ctx, CombatApplicator.apply_damage(owner, target, amount, type_name, state))
		return
	#Outside an encounter only a will_hp_floor type is safe: nothing here can confirm a death.
	if not bool(ConstDamageTypes.get_type(type_name).get("will_hp_floor", false)):
		TraitRuntime._warn_once("damage_outside:" + type_name,
			"%s: %s damage outside an encounter has no applier" % [td.trait_name, type_name])
		return
	DefenseSystem.resolve(target, amount, type_name, 0, true, true)


#Inside a battle the state gets a round timer; outside one the Inflict Default duration becomes a campaign timer.
static func _apply_inflict(effect: String, owner: MercenaryData, target: MercenaryData,
		ctx: Dictionary, td: TraitData) -> void:
	var state: BattleState = ctx.get("state", null)
	if target == null or not BattleState._is_alive(target):
		return
	var state_name: String = ConstStates.state_from_token(effect.substr(8))
	if state_name == "":
		TraitRuntime._warn_once("effect:" + effect, "%s: unknown state in '%s'" % [td.trait_name, effect])
		return
	if not ConstStates.has_inflict_default(state_name):
		TraitRuntime._warn_once("no_default:" + state_name,
			"%s: %s has no States.tsv Inflict Default" % [td.trait_name, state_name])
		return
	TraitRuntime._emit(ctx, StateInfliction.inflict_default(target, state_name, owner, state))


#Puts a state on the target with no resist roll and no States.tsv Inflict Default.
static func _apply_state_direct(effect: String, owner: MercenaryData, target: MercenaryData,
		ctx: Dictionary, td: TraitData) -> void:
	if target == null or not BattleState._is_alive(target):
		return
	var parsed: Dictionary = StateTokens.parse_apply_token(effect)
	var states: Array = parsed["states"]
	if states.is_empty():
		TraitRuntime._warn_once("effect:" + effect, "%s: apply: unknown state in '%s'" % [td.trait_name, effect])
		return
	var error: String = str(parsed["error"])
	if error == "unreadable duration":
		TraitRuntime._warn_once("effect:" + effect, "%s: apply: unreadable duration in '%s'" % [td.trait_name, effect])
	elif error == "unknown until":
		TraitRuntime._warn_once("effect:" + effect, "%s: apply: unknown until in '%s'" % [td.trait_name, effect])
	var duration: String = str(parsed["duration"])
	var removal: Array[String] = []
	removal.assign(parsed["removal"])
	for state_name: String in states:
		if not StateCascade.apply_state(target, state_name, owner, "", "trait:" + td.trait_name, removal):
			continue
		if duration != "":
			_set_apply_timer(target, state_name, duration, ctx)
		var lines: Array[String] = ["  %s gains %s." % [target.merc_name, state_name]]
		TraitRuntime._emit(ctx, lines)
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
		StateCascade.remove_state(target, state_name)
		if state != null:
			StateInfliction.note_removed(target, state_name, state, "trait")


static func _circumstance_pool(filter: String, ctx: Dictionary) -> Array:
	var pool: Array = []
	if filter == "any":
		pool.assign(ConstCircumstances.ALL)
		return pool
	if filter == "contract_relevant":
		var c: ContractData = TraitRuntime._contract(ctx)
		if c == null:
			return pool
		for display: String in c.circumstance_boosts:
			if ConstCircumstances.DATA.has(display):
				pool.append(display)
		return pool
	for display2: String in ConstCircumstances.ALL:
		var data: Dictionary = ConstCircumstances.DATA[display2]
		var circ: String = StateTokens.normalize_token(str(data.get("circumstance_name", "")))
		var stat: String = StateTokens.normalize_token(str(data.get("stat", "")))
		if filter == circ or filter == stat or filter == circ + "_" + stat:
			pool.append(display2)
	return pool


static func _apply_circumstance_grant(effect: String, owner: MercenaryData, target: MercenaryData,
		ctx: Dictionary, scope: String, cid: String, td: TraitData) -> void:
	var parts: PackedStringArray = effect.split(":")
	if parts.size() != 5:
		TraitRuntime._warn_once("effect:" + effect,
			"%s: unimplemented circumstance grant '%s'" % [td.trait_name, effect])
		return
	var pool: Array = _circumstance_pool(parts[3], ctx)
	var available: Array = TraitDSL.available_circumstances(target, pool)
	if available.is_empty():
		return
	available.shuffle()
	for i: int in range(mini(int(parts[4]), available.size())):
		_set_circumstance(owner, target, available[i], true, scope, cid)


static func _apply_circumstance_removal(effect: String, owner: MercenaryData, target: MercenaryData,
		ctx: Dictionary, scope: String, cid: String, td: TraitData) -> void:
	var parts: PackedStringArray = effect.split(":")
	var except_key: String = ""
	var count: int = 0
	if parts.size() == 5:
		count = int(parts[4])
	elif parts.size() == 7 and parts[4] == "except":
		except_key = parts[5]
		count = int(parts[6])
	else:
		TraitRuntime._warn_once("effect:" + effect,
			"%s: unimplemented circumstance removal '%s'" % [td.trait_name, effect])
		return
	var filter: String = parts[3]
	var allowed: Array = _circumstance_pool(filter, ctx) if filter != "any" else []
	var held: Array = []
	for display: String in target.circumstance_flags:
		if not bool(target.circumstance_flags[display]):
			continue
		if except_key != "" and _circumstance_pool(except_key, ctx).has(display):
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
	if scope != TraitRuntime.SCOPE_PERMANENT:
		TraitRuntime._record(owner, {"m": target, "kind": "circ", "key": display, "delta": 1.0 if value else 0.0,
			"scope": scope, "cid": cid})


static func _apply_reward(effect: String, ctx: Dictionary, td: TraitData) -> void:
	var run: ContractRun = ctx.get("run", null)
	var parts: PackedStringArray = effect.split(":")
	if run == null or parts.size() != 3:
		TraitRuntime._warn_once("effect:" + effect, "%s: reward: needs a contract run" % td.trait_name)
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
