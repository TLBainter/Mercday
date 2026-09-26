class_name SpecialActionSystem


static func execute(action: Dictionary, merc: MercenaryData, state: BattleState, ctx: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var action_name: String = action.get("action_name", "")
	var enhancements: int = ctx.get("enhancements", 0)
	var target: MercenaryData = action.get("target")
	var target_obs: Dictionary = action.get("target_obs", {})
	match action_name:
		"get_up":
			_pay(state, merc, "get_up", "get_up")
			if ConstStates.remove_state(merc, ConstStates.DEPOSED)["removed"]:
				StateInfliction.note_removed(merc, ConstStates.DEPOSED, state, "action")
			lines.append("  %s gets up!" % BattleState.colored_name(merc, state))
		"end_burning":
			_pay(state, merc, "Interact", "Interact")
			lines.append("  %s tries to put out the flames!" % BattleState.colored_name(merc, state))
			lines.append_array(StateInfliction.attempt_interact(merc, ConstStates.BURNING, state))
		"aid_ally":
			var aid_state := str(action.get("state_name", ""))
			if target != null and not target.is_dead and aid_state != "" \
					and ConstStates.has_state(target, aid_state) \
					and state.distance_to(merc, target) <= 1:
				_pay(state, merc, "Interact", "Interact")
				lines.append_array(StateInfliction.attempt_interact(target, aid_state, state, merc))
				if aid_state == ConstStates.TERRIFIED and target.flee_intent \
						and not ConstStates.has_state(target, ConstStates.TERRIFIED):
					lines.append_array(FleeSystem.stop(target))
				RelationshipSystem.record_aid(merc, target)
		"seek_cover":
			_do_seek_cover(merc, state, lines)
		"break_free":
			_pay(state, merc, "break_free", "break_free")
			_do_break_free(merc, state, enhancements, lines)
		"grapple":
			return do_grapple(merc, target, state)
		"aim":
			_pay(state, merc, "Aim", "Aim")
			merc.aim_active = true
			lines.append("  %s aims." % BattleState.colored_name(merc, state))
		"Interact":
			_do_interact(merc, state, lines)
		"shove":
			_pay(state, merc, "shove", "shove", 3)
			if target != null:
				lines.append_array(ShoveResolver.shove(merc, target, state, enhancements))
			elif not target_obs.is_empty():
				ShoveResolver.shove_obstacle(merc, target_obs, state, lines)
		"attack_obstacle":
			_pay(state, merc, "attack_obstacle", "attack_obstacle", AutoBattle.ATTACK_BASE_AP)
			lines.append_array(_do_attack_obstacle(merc, state, enhancements))
		"withdraw":
			_pay(state, merc, "withdraw", "withdraw")
			merc.advantage_immune = true
			FleeSystem.withdraws += 1
			lines.append("  %s withdraws!" % BattleState.colored_name(merc, state))
			var cap := ConstStates.max_paces(merc)
			var paces := 2 if cap < 0 else mini(2, cap)
			var goal: Vector3i = PathTargeter.NO_CELL
			if FleeSystem.is_fleeing(merc):
				goal = FleeSystem.escape_goal(merc, state)
			elif state.battlefield != null and target != null:
				goal = MovementExecutor.compute_move_position(merc, target, "Move Far", state, null, -1, [],
						state.get_enemies(merc))
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("WITHDRAW: %s paces %d goal (%d,%d,%d)"
						% [merc.merc_name, paces, goal.x, goal.y, goal.z])
			if paces > 0 and goal != PathTargeter.NO_CELL and goal != state.pos3(merc):
				var saved := state.get_pace_pool(merc)
				state.set_pace_pool(merc, paces)
				state.move_plan[merc] = {"moves_allowed": 1, "reserve_ap": 999}
				lines.append_array(MovementExecutor.execute_move(merc, "Move Far", target, state, null,
						enhancements, -1, false, [], [], goal))
				state.move_plan.erase(merc)
				state.set_pace_pool(merc, saved)
	return lines


#Charges the escalating cost of cost_key, records the use under label and returns the AP spent.
static func _pay(state: BattleState, merc: MercenaryData, cost_key: String, label: String,
		default_ap: int = 2) -> int:
	var cost := state.get_cost(merc, cost_key, default_ap)
	state.spend_ap(merc, cost)
	state.record_action(merc, label)
	return cost


static func _do_seek_cover(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	if state.battlefield == null:
		return
	var enemies := state.get_enemies(merc)
	var ranged := CoverSearch.ranged_enemies(enemies)
	var merc_size: int = maxi(1, int(merc.stats.get("size", 1)))
	var pace: int = maxi(1, int(merc.stats.get("pace", 1)))
	var seek_cost := state.get_cost(merc, "seek_cover", 2)
	var dest := CoverSearch.find_cover_cell(merc, enemies, state)
	if dest == PathTargeter.NO_CELL:
		var cur := CoverSearch.cover_score(state.pos3(merc), merc_size, ranged, state)
		if int(cur["full"]) > 0 or int(cur["partial"]) > 0:
			lines.append("  %s is already in cover." % BattleState.colored_name(merc, state))
		else:
			lines.append("  %s finds no reachable cover (pace=%d)." % [BattleState.colored_name(merc, state), pace])
		return
	var move_cost := state.get_cost(merc, "Move Close", AutoBattle.MOVE_BASE_AP)
	if not state.can_afford(merc, move_cost + seek_cost):
		lines.append("  %s cannot afford to reach cover." % BattleState.colored_name(merc, state))
		return
	state.spend_ap(merc, move_cost)
	state.record_action(merc, "Move Close")
	state.set_pos3(merc, dest)
	merc.aim_active = false
	state.spend_ap(merc, seek_cost)
	state.record_action(merc, "seek_cover")
	var sc_final := CoverSearch.cover_score(dest, merc_size, ranged, state)
	lines.append("  %s moves to cover at (%d,%d) F%d: full from %d, partial from %d." % [
		BattleState.colored_name(merc, state), dest.x, dest.y, dest.z, int(sc_final["full"]), int(sc_final["partial"])])


static func _do_interact(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	if state.battlefield == null:
		return
	var cell := InteractTargetFacet.find_target(merc, state)
	if cell == PathTargeter.NO_CELL:
		return
	var obs: Dictionary = state.battlefield.get_obs(Vector2i(cell.x, cell.y), cell.z)
	if obs.is_empty():
		return
	InteractionSystem.perform(merc, obs, cell, state, lines)


static func _do_attack_obstacle(merc: MercenaryData, state: BattleState, enhancements: int) -> Array[String]:
	var target_obs := pick_obstacle(merc, state)
	if target_obs.is_empty():
		return [] as Array[String]
	return attack_obstacle_at(merc, state, target_obs, enhancements)


#Rubble holding a buried ally comes first; otherwise the first adjacent obstacle a weapon can hurt.
static func pick_obstacle(merc: MercenaryData, state: BattleState) -> Dictionary:
	if state.battlefield == null:
		return {}
	var dig := CaveInSystem.dig_target(merc, state)
	if not dig.is_empty():
		return dig
	var pos := state.get_position(merc)
	var target_obs: Dictionary = {}
	for obs: Dictionary in state.battlefield.get_adjacent_obstacles(pos, state.get_floor(merc)):
		var ct: String = obs.get("cell_type", "")
		if ct == "wall":
			continue
		var d: ObstacleData = obs.get("data") as ObstacleData
		if d == null or d.passthrough or d.ramp or d.health == 0:
			continue
		if PathCost.is_interactable_door(obs) and not OpenCloseState.is_open(obs):
			continue
		#A locked door is a wall to the mover: it is picked or left alone, never smashed.
		if DungeonLocks.is_locked(obs):
			continue
		target_obs = obs
		break
	return target_obs


static func attack_obstacle_at(merc: MercenaryData, state: BattleState, target_obs: Dictionary,
		enhancements: int) -> Array[String]:
	var lines: Array[String] = []
	if state.battlefield == null or target_obs.is_empty():
		return lines
	var obs_data: ObstacleData = target_obs.get("data") as ObstacleData
	var held: WeaponData = merc.equipped_weapon
	var was_drawn: bool = merc.weapon_drawn
	var fists: bool = _harmless_against(merc, held, obs_data)
	if fists:
		merc.equipped_weapon = DataManager.fight_weapon
		merc.weapon_drawn = true
		lines.append("  %s uses bare hands against %s." % [BattleState.colored_name(merc, state),
			obs_data.obstacle_name])
	var types: Array[String] = _weapon_types(merc, merc.equipped_weapon)
	var atk_result := AttackSystem.execute_attack(merc, enhancements, 0, null, false, state)
	var dtype: String = _best_type(obs_data, types, str(atk_result.get("damage_type", "Strike")))
	if fists:
		merc.equipped_weapon = held
		merc.weapon_drawn = was_drawn
	if atk_result.get("weapon_broke", false):
		var _bn: String = merc.equipped_weapon.item_name if merc.equipped_weapon != null else "weapon"
		lines.append("  %s's %s breaks apart!" % [BattleState.colored_name(merc, state), _bn])
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("FRAGILITY: %s destroyed" % _bn)
		lines.append_array(WeaponActionExecutor.empty_main_hand(merc, state))
	var damage: int = atk_result.get("damage", 0)
	var result := ObstacleUtils.apply_damage(target_obs, damage, state, BattleState.colored_name(merc, state),
		dtype)
	lines.append_array(result["lines"] as Array)
	var drop_pos: Vector2i = result.get("drop_pos", Vector2i(-1, -1)) as Vector2i
	if drop_pos != Vector2i(-1, -1):
		merc.active_states["bfw_drop_pos"] = drop_pos
	return lines


#The held weapon's damage types, a ranged Varies entry resolved through the loaded ammo.
static func _weapon_types(merc: MercenaryData, weapon: WeaponData) -> Array[String]:
	var types: Array[String] = []
	if weapon == null:
		return types
	for dt: String in weapon.damage_types_1:
		if dt == "Varies" and weapon.is_ranged and merc.ammo_loaded_type != "":
			var ammo: AmmoData = DataManager.ammo.get(merc.ammo_loaded_type)
			if ammo != null:
				types.append_array(ammo.damage_types_1)
			continue
		types.append(dt)
	return types


#Every type the held weapon can deal is on the obstacle's Immune To list while bare hands would hurt it.
static func _harmless_against(merc: MercenaryData, weapon: WeaponData, obs_data: ObstacleData) -> bool:
	if weapon == null or obs_data == null or weapon == DataManager.fight_weapon:
		return false
	var types := _weapon_types(merc, weapon)
	if types.is_empty():
		return false
	for dt: String in types:
		if ObstacleUtils.damage_modifier(obs_data, dt) > 0.0:
			return false
	return ObstacleUtils.damage_modifier(obs_data, "Strike") > 0.0


#A weapon with more than one type swings the one the obstacle takes the most from.
static func _best_type(obs_data: ObstacleData, types: Array[String], picked: String) -> String:
	if obs_data == null:
		return picked
	var best := picked
	var best_mod := ObstacleUtils.damage_modifier(obs_data, picked)
	for dt: String in types:
		var mod := ObstacleUtils.damage_modifier(obs_data, dt)
		if mod > best_mod:
			best = dt
			best_mod = mod
	return best


#Break Free contest def: a vigor luck roll with Athletics or Power; both sides roll it.
static func break_free_def() -> Dictionary:
	return {
		"stat_keys": ["vigor"],
		"circumstances": [ConstCircumstances.ATHLETICS_VIGOR, ConstCircumstances.POWER_VIGOR],
		"knowledges": [],
		"tools": [],
		"formula": "luck",
		"flat_threshold_bonus": 0.0,
	}


#The source that contests the roll: alive, still on the field and holding the state; null when nobody does.
static func break_free_opponent(target: MercenaryData, state_name: String,
		state: BattleState) -> MercenaryData:
	var source: MercenaryData = ConstStates.get_source(target, state_name)
	if source == null or source.is_dead:
		return null
	if state != null and (not BattleState._is_alive(source) or source.off_field):
		return null
	return source


static func _do_break_free(merc: MercenaryData, state: BattleState, enhancements: int, lines: Array[String]) -> void:
	var state_name := ""
	if ConstStates.has_state(merc, ConstStates.SUFFOCATING):
		state_name = ConstStates.SUFFOCATING
	elif ConstStates.has_state(merc, ConstStates.GRAPPLED):
		state_name = ConstStates.GRAPPLED
	elif ConstStates.has_state(merc, ConstStates.INHIBITED):
		state_name = ConstStates.INHIBITED
	if state_name == "":
		return
	var check_def := break_free_def()
	check_def["enhancements"] = enhancements
	var freed := false
	var source := break_free_opponent(merc, state_name, state)
	if source != null:
		var holder_def := break_free_def()
		#Flail Grappled: the grappler's drawn flail steadies the hold.
		if WeaponArmorPerkLibrary.has_weapon_passive(source, "weapon_passive:grapple_check:+1_enhanced"):
			holder_def["enhancements"] = 1
		var duel := CheckSystem.opposed_check(merc, source, check_def, holder_def)
		freed = bool(duel["a_wins"])
		var mine: Dictionary = duel["a"]
		var theirs: Dictionary = duel["b"]
		lines.append("  BREAK FREE: %s %d successes vs %s %d -> %s" % [
			BattleState.colored_name(merc, state), int(mine["successes"]),
			BattleState.colored_name(source, state), int(theirs["successes"]),
			"breaks free" if freed else "stays held"])
	else:
		var default_spec := ConstStates.inflict_default(state_name)
		var spec: Dictionary = {}
		if not default_spec.is_empty():
			spec = StateInfliction.parse_resist(str(default_spec["inflict"]))
		if not spec.is_empty():
			var resisted := StateInfliction.resist_check(merc, spec, state_name, 0, enhancements)
			freed = bool(resisted["passed"])
			lines.append("  BREAK FREE: %s Resist %d successes vs trial %d -> %s" % [
				BattleState.colored_name(merc, state), int(resisted["successes"]),
				int(spec["trial"]), "breaks free" if freed else "stays held"])
		else:
			var plain := CheckSystem.make_check(merc, check_def)
			freed = int(plain["successes"]) > 0 or bool(plain.get("critical", false))
			lines.append("  BREAK FREE: %s %d successes, nobody holds -> %s" % [
				BattleState.colored_name(merc, state), int(plain["successes"]),
				"breaks free" if freed else "stays held"])
	if freed:
		if ConstStates.remove_state(merc, state_name)["removed"]:
			StateInfliction.note_removed(merc, state_name, state, "action")
		if state_name == ConstStates.SUFFOCATING and ConstStates.has_state(merc, ConstStates.GRAPPLED):
			if ConstStates.remove_state(merc, ConstStates.GRAPPLED)["removed"]:
				StateInfliction.note_removed(merc, ConstStates.GRAPPLED, state, "action")
		lines.append("  %s breaks free!" % BattleState.colored_name(merc, state))
	else:
		lines.append("  %s fails to break free!" % BattleState.colored_name(merc, state))
		var grappler: MercenaryData = ConstStates.get_source(merc, ConstStates.GRAPPLED)
		if grappler != null and ActionDispatcher.is_whip_grappler(grappler, merc, state):
			lines.append_array(CombatApplicator.deal_direct(grappler, merc, 1,
				AttackSystem.damage_type_of(grappler.equipped_weapon), state, "Whip Choke"))
			lines.append("  %s is choked by the whip!" % BattleState.colored_name(merc, state))
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("WHIP CHOKE: %s fails to escape %s" % [
					merc.merc_name, grappler.merc_name])


#Grapple check: a vigor luck roll that puts an adjacent target into Grappled.
static func do_grapple(merc: MercenaryData, target: MercenaryData, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	if target == null or state == null:
		return lines
	if state.distance_to(merc, target) > 1:
		return lines
	var result := CheckSystem.make_check(merc, KidnapSystem.grapple_def())
	var holds: bool = int(result["successes"]) > 0 or bool(result.get("critical", false))
	lines.append("  GRAPPLE: %s vs %s -> %s" % [merc.merc_name, target.merc_name,
		"holds" if holds else "fails"])
	if holds:
		lines.append_array(StateInfliction.inflict_default(target, ConstStates.GRAPPLED, merc, state))
	return lines
