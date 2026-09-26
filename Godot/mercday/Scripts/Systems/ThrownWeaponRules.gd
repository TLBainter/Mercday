class_name ThrownWeaponRules
extends RefCounted

#Thrown weapon ranges, accuracy, landing prediction and the rules that allow or refuse a throw.


static func compute_thrown_accuracy(merc: MercenaryData, _weapon: WeaponData) -> float:
	#thrown_accuracy stat = max(melee_acc, ranged_acc) + merc_size*10 + any stat bonus
	return float(merc.stats.get("thrown_accuracy", 0.0))


static func compute_thrown_range(merc: MercenaryData, weapon: WeaponData) -> int:
	#thrown_range stat is baseline with object_weight=0: vigor*20 + any stat bonus
	#for weighted objects, adjust from that baseline back to (vigor-weight)*10 + bonus
	var vigor: int = int(merc.stats.get("vigor", 0))
	var stat_base: int = int(merc.stats.get("thrown_range", vigor * 20))
	var bonus: int = stat_base - vigor * 20
	var effective_weight: int = weapon.weight
	if effective_weight == 0 and weapon.base_weapon != null:
		effective_weight = weapon.base_weapon.weight
	if effective_weight > 0:
		return maxi(0, (vigor - effective_weight) * 10 + bonus)
	return maxi(0, stat_base)


#A weapon with the Thrown property throws on its own Intended/Extended; anything else is an object.
static func thrown_ranges(merc: MercenaryData, weapon: WeaponData) -> Dictionary:
	if weapon == null:
		return {"intended": 0, "extended": 0, "mode": "object", "bonus": 0}
	var bonus: int = int(merc.active_states.get("thrown_extended_range_bonus", 0))
	if weapon.range_thrown != "":
		var itd: int = weapon.thrown_intended_range
		var ext: int = weapon.thrown_extended_range
		if ext <= 0:
			ext = itd
		return {"intended": itd, "extended": maxi(itd, ext + bonus), "mode": "property", "bonus": bonus}
	return {"intended": 0, "extended": int(compute_thrown_range(merc, weapon) / 2.0),
			"mode": "object", "bonus": 0}


static func _thrown_extended_bonus_damage(merc: MercenaryData) -> int:
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
		if perk.effect_dsl.begins_with("weapon_passive:thrown_extended_bonus_damage:"):
			return int(perk.effect_dsl.get_slice(":", 2).lstrip("+"))
	return 0


static func _throw_kill(merc: MercenaryData, weapon: WeaponData, target: MercenaryData,
		state: BattleState) -> Dictionary:
	var avg := WeaponEvaluator.parse_formula_for_avg(weapon.damage_formula_1)
	var ranges := thrown_ranges(merc, weapon)
	var itd: int = int(ranges["intended"])
	if itd > 0 and state.distance_to(merc, target) > itd:
		avg += float(_thrown_extended_bonus_damage(merc))
	var acc := clampf(compute_thrown_accuracy(merc, weapon) / 100.0, 0.05, 0.95)
	var hp := maxi(1, int(target.current_hp))
	return {"lethal": avg * acc >= float(hp), "chance": acc}


static func _throw_blocks(obs: Dictionary) -> bool:
	if obs.is_empty():
		return false
	var ct := str(obs.get("cell_type", ""))
	if ct == "wall" or ct == "window":
		return true
	if ct == "door":
		return not OpenCloseState.is_open(obs)
	var d: ObstacleData = obs.get("data") as ObstacleData
	if d == null:
		return false
	return not (d.passthrough or d.ramp)


#A miss carries the weapon past the target along the throw line until a cell blocks entry.
static func predict_landing(merc: MercenaryData, weapon: WeaponData, target: MercenaryData,
		hit: bool, state: BattleState) -> Dictionary:
	var t2 := state.get_position(target)
	var floor_num := state.get_floor(target)
	var res := {"cell": t2, "floor": floor_num, "remainder": 0, "blocker": {}}
	if hit or state.battlefield == null:
		return res
	var from2 := state.get_position(merc)
	var dist := state.distance_to(merc, target)
	var ranges := thrown_ranges(merc, weapon)
	var span: int = int(ranges["intended"])
	if span <= 0 or dist > span:
		span = int(ranges["extended"])
	var remainder: int = maxi(0, span - dist)
	res["remainder"] = remainder
	if remainder <= 0 or from2 == t2:
		return res
	var len_steps: int = maxi(1, maxi(absi(t2.x - from2.x), absi(t2.y - from2.y)))
	var factor: int = int(ceil(float(len_steps + remainder) / float(len_steps)))
	var steps := LineOfSight._steps(from2, from2 + (t2 - from2) * factor)
	var idx := -1
	for i in steps.size():
		if (steps[i]["c"] as Vector2i) == t2:
			idx = i
			break
	if idx < 0:
		return res
	var last_free := t2
	var walked := 0
	for i in range(idx + 1, steps.size()):
		if walked >= remainder:
			break
		var c: Vector2i = steps[i]["c"]
		if c == last_free:
			continue
		walked += 1
		if c.x < 0 or c.y < 0 or c.x >= state.battlefield.width or c.y >= state.battlefield.length:
			break
		var obs := state.battlefield.get_obs(c, floor_num)
		if _throw_blocks(obs):
			res["blocker"] = obs
			break
		last_free = c
	res["cell"] = last_free
	return res


#The thrown weapon becomes a ground pickup and may damage whatever stopped it.
static func land_thrown_weapon(merc: MercenaryData, weapon: WeaponData, target: MercenaryData,
		hit: bool, damage: int, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	if weapon == null or target == null or state == null:
		return lines
	var land := predict_landing(merc, weapon, target, hit, state)
	var cell: Vector2i = land["cell"]
	var floor_num: int = int(land["floor"])
	var obj_name := ""
	var obj_dmg := 0
	var blocker: Dictionary = land.get("blocker", {})
	if not blocker.is_empty():
		var bd: ObstacleData = blocker.get("data") as ObstacleData
		var ct := str(blocker.get("cell_type", ""))
		if bd != null and bd.health != 0 and ct != "wall" and ObstacleUtils.get_hp(bd) > 0:
			#A miss carries no attack damage, so the impact falls back to the weapon average.
			var impact: int = damage if damage > 0 else maxi(
				1, int(round(WeaponEvaluator.parse_formula_for_avg(weapon.damage_formula_1))))
			var res := ObstacleUtils.apply_damage(blocker, impact, state, merc.merc_name,
				AttackSystem.damage_type_of(weapon))
			obj_name = bd.obstacle_name
			obj_dmg = int(res.get("damage", impact))
			lines.append_array(res.get("lines", [] as Array[String]) as Array[String])
	var stack: Array = state.dropped_weapons.get(cell, [])
	stack.append({"weapon": weapon, "ammo_loaded": 0, "ammo_loaded_type": "", "floor": floor_num})
	state.dropped_weapons[cell] = stack
	if EncounterLogger.is_active():
		var extra := ""
		if obj_name != "":
			extra = " object=%s dmg=%d" % [obj_name, obj_dmg]
		EncounterLogger.log_verbose("THROW LANDS: %s %s at (%d,%d) F%d %s remainder=%d%s" % [
			merc.merc_name, weapon.item_name, cell.x, cell.y, floor_num,
			"hit" if hit else "miss", int(land["remainder"]), extra])
	return lines


#An object throw is a last resort: nothing else can attack this turn and the weapon has no Thrown range.
static func object_throw_allowed(merc: MercenaryData, weapon: WeaponData, target: MercenaryData,
		state: BattleState) -> bool:
	if weapon == null or target == null or state == null or state.battlefield == null:
		return false
	if weapon.is_ranged or weapon.is_throwable or weapon.is_virtual:
		return false
	var dist := state.distance_to(merc, target)
	if dist <= WeaponEvaluator.melee_reach_for(merc, weapon) + WeaponEvaluator._pace_per_move(merc) * 2:
		return false
	if dist > int(thrown_ranges(merc, weapon)["extended"]):
		return false
	for w: WeaponData in WeaponEvaluator.get_available_weapons(merc):
		if w == weapon or w.is_virtual:
			continue
		if w.is_throwable:
			return false
		if w.is_ranged and WeaponEvaluator.is_ranged_usable(merc, w):
			return false
	return true


#Throwing gives the weapon away: it needs a backup, a likely kill or a safe recovery.
static func should_throw(merc: MercenaryData, weapon: WeaponData, target: MercenaryData,
		enemies: Array, state: BattleState, do_log: bool = false) -> Dictionary:
	var mode := "object" if weapon == null or weapon.range_thrown == "" else "property"
	var result := {"throw": false, "reason": "out_of_range", "mode": mode}
	if weapon == null or target == null or state == null or state.battlefield == null:
		_log_throw_refusal(merc, weapon, result, do_log)
		return result
	var dist := state.distance_to(merc, target)
	if dist <= WeaponEvaluator.melee_reach_for(merc, weapon):
		result["reason"] = "in_reach"
		_log_throw_refusal(merc, weapon, result, do_log)
		return result
	var ext: int = int(thrown_ranges(merc, weapon)["extended"])
	if ext <= 0 or dist > ext or not (LineOfSight.check(state, merc, target)["visible"] as bool):
		result["reason"] = "out_of_range"
		_log_throw_refusal(merc, weapon, result, do_log)
		return result
	var backup := WeaponEvaluator.has_backup_weapon(merc, weapon)
	var kill := _throw_kill(merc, weapon, target, state)
	var kill_likely: bool = bool(kill["lethal"])
	var paces_per_turn := WeaponEvaluator._pace_per_move(merc) * 2
	var land := predict_landing(merc, weapon, target, false, state)
	var land_cell: Vector2i = land["cell"]
	var merc_pos := state.get_position(merc)
	var recover_paces: int = maxi(absi(land_cell.x - merc_pos.x), absi(land_cell.y - merc_pos.y))
	var recover_turns: int = int(ceil(float(recover_paces) / float(maxi(1, paces_per_turn))))
	var recoverable: bool = recover_paces <= paces_per_turn * 2 \
			and int(land["floor"]) == state.get_floor(merc)
	var threat := false
	for e: MercenaryData in enemies:
		if e == target or not BattleState._is_alive(e):
			continue
		var ep := state.get_position(e)
		if recoverable and maxi(absi(ep.x - land_cell.x), absi(ep.y - land_cell.y)) < recover_paces:
			recoverable = false
		if not backup and state.distance_to(merc, e) - 1 <= WeaponEvaluator._pace_per_move(e) * 4:
			threat = true
	var gain := backup or kill_likely
	if mode == "property":
		gain = gain or recoverable
	if threat:
		result["reason"] = "no_backup_threat"
	elif not gain:
		result["reason"] = "no_gain"
	else:
		result["throw"] = true
		result["reason"] = "ok"
	if not bool(result["throw"]):
		_log_throw_refusal(merc, weapon, result, do_log)
		return result
	if do_log and EncounterLogger.is_active():
		EncounterLogger.log_verbose("THROW PLAN: %s %s -> %s dist=%d backup=%s kill=%d%% recover=%d threat=%s -> throw" % [
			merc.merc_name, weapon.item_name, target.merc_name, dist, str(backup),
			100 if kill_likely else 0, recover_turns, str(threat)])
	return result


static func _log_throw_refusal(merc: MercenaryData, weapon: WeaponData, result: Dictionary,
		do_log: bool) -> void:
	if not do_log or not EncounterLogger.is_active():
		return
	var wname: String = weapon.item_name if weapon != null else "nothing"
	EncounterLogger.log_verbose("THROW REFUSED: %s %s reason=%s" % [
		merc.merc_name, wname, str(result["reason"])])


#How much a thrown weapon is worth giving up: a spare, a nearby drop or a breakable source keeps the score up.


static func _throw_replacement_factor(merc: MercenaryData, weapon: WeaponData, state: BattleState) -> float:
	var fight := DataManager.fight_weapon
	for entry: Dictionary in merc.inventory:
		if entry.get("type") == "weapon":
			var w: WeaponData = entry.get("data") as WeaponData
			if w != null and w != weapon and w != fight:
				return 1.0
	if merc.equipped_weapon != null and merc.equipped_weapon != weapon and merc.equipped_weapon != fight:
		return 1.0
	if state.battlefield == null:
		return 0.25
	var merc_pos := state.get_position(merc)
	var pace := maxi(1, int(merc.stats.get("pace", 1)))
	for pos: Vector2i in state.dropped_weapons.keys():
		if maxi(abs(pos.x - merc_pos.x), abs(pos.y - merc_pos.y)) <= pace * 2:
			return 0.6
	for obs: Dictionary in state.battlefield.obstacles:
		if obs.get("cell_type", "") == "wall":
			continue
		var d: ObstacleData = obs.get("data") as ObstacleData
		if d == null or d.health == 0 or d.drops.is_empty():
			continue
		var raw_pos: Variant = obs.get("pos", Vector2i(-1, -1))
		var p: Vector2i = Vector2i((raw_pos as Vector3i).x, (raw_pos as Vector3i).y) if typeof(raw_pos) == TYPE_VECTOR3I else raw_pos as Vector2i
		if p.x < 0:
			continue
		if maxi(abs(p.x - merc_pos.x), abs(p.y - merc_pos.y)) <= 6:
			return 0.4
	return 0.25
