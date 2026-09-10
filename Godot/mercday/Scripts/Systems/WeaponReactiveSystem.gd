class_name WeaponReactiveSystem

#Tokens that sit between the trigger and the verb in a reactive_action DSL string.
const KNOWN_CONDITIONS: PackedStringArray = [
	"any", "surprised", "deposed", "vulnerable", "two_handed",
	"size_5_or_less", "size_gte_self", "size_lte_self", "thrown",
	"within_2", "melee", "intended_range", "once_per_combat", "1hp",
]

const NO_CELL := Vector3i(-1, -1, -1)


static func fire_trigger(attacker: MercenaryData, trigger: String, target: MercenaryData, atk: Dictionary, state: BattleState, enhancements: int) -> Array[String]:
	return _fire_weapon_reactive(attacker, trigger, target, atk, state, enhancements)


#Extra damage from on_hit perks, added to the hit before defense. Charges 1 EP per perk.
static func on_hit_damage_bonus(
		attacker: MercenaryData,
		target: MercenaryData,
		atk: Dictionary,
		state: BattleState,
		lines: Array[String]) -> int:
	if attacker == null or target == null:
		return 0
	var total := 0
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_actions(attacker):
		var tok := _token_for(perk, "on_hit")
		if tok.is_empty() or str(tok["verb"]) != "damage":
			continue
		if not _conditions_met(tok["conds"], attacker, target, atk, state):
			continue
		var args: Array = tok["args"]
		var val_str: String = str(args[0]) if args.size() > 0 else "+0"
		var bonus: int = int(target.stats.get("pain_limit", 0)) if val_str == "pain_limit" else int(val_str)
		if bonus <= 0:
			continue
		if not _charge_reaction(attacker):
			continue
		total += bonus
		lines.append("  %s activates %s (+%d damage)!" % [BattleState.colored_name(attacker, state), _perk_label(perk), bonus])
	return total


#Non-damage on_hit reactions, run after the damage has landed.
static func apply_on_hit(
		attacker: MercenaryData,
		target: MercenaryData,
		atk: Dictionary,
		state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	if attacker == null or target == null or state == null or state.battlefield == null:
		return lines
	if target.is_dead or (target.current_hp <= 0 and not ConstStates.has_state(target, ConstStates.DYING)):
		return lines
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_actions(attacker):
		var tok := _token_for(perk, "on_hit")
		if tok.is_empty():
			continue
		var verb: String = str(tok["verb"])
		if verb == "damage":
			continue
		if not _conditions_met(tok["conds"], attacker, target, atk, state):
			continue
		var args: Array = tok["args"]
		var paces: int = maxi(1, int(str(args[0]))) if args.size() > 0 else 1
		match verb:
			"pull_self":
				var self_dest := _pull_destination(attacker, target, paces, state)
				if self_dest == NO_CELL or not _charge_reaction(attacker):
					continue
				lines.append("  %s closes in with %s!" % [BattleState.colored_name(attacker, state), _perk_label(perk)])
				lines.append_array(_relocate(attacker, self_dest, state))
			"pull_target":
				var tgt_dest := _pull_destination(target, attacker, paces, state)
				if tgt_dest == NO_CELL or not _charge_reaction(attacker):
					continue
				lines.append("  %s drags %s in with %s!" % [
					BattleState.colored_name(attacker, state), BattleState.colored_name(target, state), _perk_label(perk)])
				lines.append_array(_relocate(target, tgt_dest, state))
			"move_target":
				if not _charge_reaction(attacker):
					continue
				lines.append("  %s activates %s!" % [BattleState.colored_name(attacker, state), _perk_label(perk)])
				lines.append_array(ShoveResolver.forcible_move(attacker, target, paces, state))
			_:
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("REACTIVE SKIP: %s %s" % [attacker.merc_name, verb])
	return lines


static func _fire_weapon_reactive(
		attacker: MercenaryData,
		trigger: String,
		target: MercenaryData,
		atk: Dictionary,
		state: BattleState,
		enhancements: int) -> Array[String]:
	var lines: Array[String] = []
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_actions(attacker):
		var tok := _token_for(perk, trigger)
		if tok.is_empty():
			continue
		if not _conditions_met(tok["conds"], attacker, target, atk, state):
			continue
		var ep_cost := CombatApplicator.state_ep_cost(attacker, 1, "reaction")
		if ep_cost < 0 or ExcessPool.available_ep(attacker) < ep_cost:
			continue
		var args: Array = tok["args"]
		match str(tok["verb"]):
			"damage":
				if target == null:
					continue
				ExcessPool.pay_ep(attacker, ep_cost)
				var val_str: String = str(args[0]) if args.size() > 0 else "+0"
				var bonus: int
				if val_str == "pain_limit":
					bonus = int(target.stats.get("pain_limit", 0))
				else:
					bonus = int(val_str)
				if bonus > 0:
					lines.append_array(CombatApplicator.apply_damage(attacker, target, bonus, atk.get("damage_type", "Strike"), state))
					lines.append("  %s activates %s!" % [BattleState.colored_name(attacker, state), _perk_label(perk)])
			"throw_attack":
				if target == null:
					continue
				ExcessPool.pay_ep(attacker, ep_cost)
				var thrown_atk := AttackSystem.execute_attack(attacker, enhancements, 0, target)
				lines.append("  %s throws weapon (reactive)!" % BattleState.colored_name(attacker, state))
				if thrown_atk.get("damage", 0) > 0:
					lines.append_array(CombatApplicator.apply_hit(attacker, target, thrown_atk, thrown_atk["damage"], thrown_atk["damage_type"], state))
			"attack_same_target":
				if target == null:
					continue
				ExcessPool.pay_ep(attacker, ep_cost)
				var extra_atk := AttackSystem.execute_attack(attacker, enhancements, 0, target)
				var dmg_mod: int = int(str(args[1])) if args.size() > 1 else 0
				lines.append("  %s makes a reactive attack!" % BattleState.colored_name(attacker, state))
				if extra_atk.get("damage", 0) > 0:
					var final_d := maxi(0, extra_atk["damage"] + dmg_mod)
					lines.append_array(CombatApplicator.apply_hit(attacker, target, extra_atk, final_d, extra_atk["damage_type"], state))
			"attack":
				if target == null:
					continue
				ExcessPool.pay_ep(attacker, ep_cost)
				var solo_atk := AttackSystem.execute_attack(attacker, enhancements, 0, target)
				var dtype: String = str(solo_atk.get("damage_type", "Strike"))
				if args.size() > 0 and ConstDamageTypes.DAMAGE_TYPES.has(str(args[0]).capitalize()):
					dtype = str(args[0]).capitalize()
				if solo_atk.get("damage", 0) > 0:
					solo_atk["damage_type"] = dtype
					lines.append_array(CombatApplicator.apply_hit(attacker, target, solo_atk, solo_atk["damage"], dtype, state))
			"reload":
				ExcessPool.pay_ep(attacker, ep_cost)
				lines.append_array(WeaponActionExecutor.execute_reload(attacker, state, enhancements))
			"attack_new_target":
				pass
			_:
				pass
	return lines


#Parsed DSL for a reactive perk on this trigger; empty when the perk does not match.
static func _token_for(perk: TraitData, trigger: String) -> Dictionary:
	var dsl := perk.effect_dsl
	if not dsl.begins_with("reactive_action:"):
		return {}
	var tok := _split_token(dsl.split(":"))
	if str(tok["trigger"]) != trigger:
		return {}
	return tok


#reactive_action:<trigger>:<cond>*:<verb>[:<args>...]
static func _split_token(parts: PackedStringArray) -> Dictionary:
	var conds: Array[String] = []
	var args: Array[String] = []
	var out: Dictionary = {"trigger": "", "conds": conds, "verb": "", "args": args}
	if parts.size() < 2:
		return out
	out["trigger"] = parts[1]
	var i := 2
	while i < parts.size() and _is_condition(parts[i]):
		conds.append(parts[i])
		i += 1
	if i < parts.size():
		out["verb"] = parts[i]
		i += 1
	while i < parts.size():
		args.append(parts[i])
		i += 1
	return out


static func _is_condition(token: String) -> bool:
	if token == "":
		return false
	for piece: String in token.split(","):
		if not KNOWN_CONDITIONS.has(piece.strip_edges()):
			return false
	return true


static func _conditions_met(
		conds: Array,
		attacker: MercenaryData,
		target: MercenaryData,
		atk: Dictionary,
		state: BattleState) -> bool:
	for cond: String in conds:
		if not _condition_met(cond, attacker, target, atk, state):
			return false
	return true


#A comma inside a condition token means any of the listed conditions is enough.
static func _condition_met(
		cond: String,
		attacker: MercenaryData,
		target: MercenaryData,
		atk: Dictionary,
		state: BattleState) -> bool:
	for piece: String in cond.split(","):
		if _single_condition(piece.strip_edges(), attacker, target, atk, state):
			return true
	return false


static func _single_condition(
		cond: String,
		attacker: MercenaryData,
		target: MercenaryData,
		atk: Dictionary,
		state: BattleState) -> bool:
	match cond:
		"any":
			return true
		"surprised":
			return target != null and ConstStates.has_state(target, ConstStates.SURPRISED)
		"deposed":
			return target != null and ConstStates.has_state(target, ConstStates.DEPOSED)
		"vulnerable":
			return target != null and ConstStates.has_state(target, ConstStates.VULNERABLE)
		"two_handed":
			return WeaponArmorPerkLibrary.is_wielding_two_handed(attacker)
		"size_5_or_less":
			return target != null and int(target.stats.get("size", 1)) <= 5
		"size_gte_self":
			return target != null and int(target.stats.get("size", 1)) >= int(attacker.stats.get("size", 1))
		"size_lte_self":
			return target != null and int(target.stats.get("size", 1)) <= int(attacker.stats.get("size", 1))
		"thrown":
			return bool(atk.get("is_throw", false))
		"within_2":
			if target == null or state == null or state.battlefield == null:
				return false
			return state.distance_to(attacker, target) <= 2
		"melee":
			var m_weapon: WeaponData = attacker.equipped_weapon
			return m_weapon == null or not m_weapon.is_ranged
		"intended_range", "once_per_combat", "1hp":
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("REACTIVE COND: %s unhandled %s" % [attacker.merc_name, cond])
			return false
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("REACTIVE COND: %s unknown %s" % [attacker.merc_name, cond])
	return false


static func _charge_reaction(attacker: MercenaryData) -> bool:
	var cost := CombatApplicator.state_ep_cost(attacker, 1, "reaction")
	if cost < 0 or ExcessPool.available_ep(attacker) < cost:
		return false
	ExcessPool.pay_ep(attacker, cost)
	return true


#Moves a pulled merc the way a forcible move does: aim drops and a terrain drop of 1 or more is a fall.
static func _relocate(mover: MercenaryData, dest: Vector3i, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	var old_pos := state.get_position(mover)
	state.set_pos3(mover, dest)
	mover.aim_active = false
	var drop := state.battlefield.get_terrain_height(old_pos) - state.battlefield.get_terrain_height(Vector2i(dest.x, dest.y))
	if drop >= 1.0:
		lines.append_array(CombatApplicator.resolve_fall(mover, int(floor(drop)), state))
	return lines


#Nearest free cell adjacent to anchor that the mover can reach in max_paces, or NO_CELL.
static func _pull_destination(
		mover: MercenaryData,
		anchor: MercenaryData,
		max_paces: int,
		state: BattleState) -> Vector3i:
	var field: BattlefieldArea = state.battlefield
	if field == null or ConstStates.has_state(mover, ConstStates.CLIMBING):
		return NO_CELL
	var floor_num := state.get_floor(anchor)
	if state.get_floor(mover) != floor_num:
		return NO_CELL
	var anchor_pos := state.get_position(anchor)
	var from := state.get_position(mover)
	if maxi(abs(anchor_pos.x - from.x), abs(anchor_pos.y - from.y)) <= 1:
		return NO_CELL
	var best := NO_CELL
	var best_d := 9999
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var cell := anchor_pos + Vector2i(dx, dy)
			if field.clamp_position(cell) != cell:
				continue
			var dist := maxi(abs(cell.x - from.x), abs(cell.y - from.y))
			if dist == 0 or dist > max_paces or dist >= best_d:
				continue
			var obs := field.get_obstacle_at_3d(Vector3i(cell.x, cell.y, floor_num))
			if not obs.is_empty():
				var od: ObstacleData = obs.get("data") as ObstacleData
				if od == null or not od.passthrough:
					continue
			if state.is_position_occupied(cell, mover, floor_num):
				continue
			best = Vector3i(cell.x, cell.y, floor_num)
			best_d = dist
	return best


static func _perk_label(perk: TraitData) -> String:
	var pieces := perk.trait_name.split("|")
	return pieces[pieces.size() - 1]


