class_name AutoBattle

const ATTACK_BASE_AP := 3
const MOVE_BASE_AP := 2
const MELEE_RANGE := 1
const MAX_ROUNDS := 100


static func run_battle(state: BattleState, line_fn: Callable = Callable()) -> Dictionary:
	if state.battlefield != null:
		_emit(line_fn, "[color=gray]%s[/color]" % state.battlefield.to_log_string())
	while not state.is_battle_over() and state.round_number < MAX_ROUNDS:
		state.round_number += 1
		state.rotate_round_damage()
		_emit(line_fn, "[color=gray]=== Round %d ===[/color]" % state.round_number)
		for merc: MercenaryData in state.turn_queue:
			if not BattleState._is_alive(merc):
				continue
			if state.is_battle_over():
				break
			for line: String in _execute_turn(merc, state):
				_emit(line_fn, line)
	return {
		"winner": state.get_winner(),
		"rounds": state.round_number,
	}


static func _emit(line_fn: Callable, line: String) -> void:
	if line_fn.is_valid():
		line_fn.call(line)


static func _execute_turn(merc: MercenaryData, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	state.start_of_turn(merc)
	merc.weapon_misfired = false
	if ConstStates.has_state(merc, ConstStates.DEBILITATED):
		merc.current_ap = 0
		merc.excess_ap = 0
	_update_auto_states(merc, state, lines)

	var enhancements: int = maxi(0, state.round_number - 1)
	var excess_str := "  ExAP:[color=purple]%d[/color]" % merc.excess_ap if merc.excess_ap > 0 else ""
	var enh_str := "  Enh:[color=cyan]%d[/color]" % enhancements if enhancements > 0 else ""
	var pos_str := ""
	if state.battlefield != null:
		var p := state.get_position(merc)
		var h := state.get_height(merc)
		pos_str = "  [color=orange](%d,%d h%d)[/color]" % [p.x, p.y, h + 1]
	lines.append("%s  HP:[color=red]%d[/color]  EP:[color=green]%d[/color]%s%s%s" % [
		_cn(merc, state), merc.current_hp, merc.current_ep, excess_str, enh_str, pos_str])

	var skip_actions := _process_start_of_turn_states(merc, state, lines)

	if not skip_actions:
		var current_target: MercenaryData = null
		var movement_blocked := false

		while true:
			var enemies := state.get_enemies(merc)
			if enemies.is_empty():
				break

			if current_target != null and not enemies.has(current_target):
				current_target = null

			var valid_targets: Array[MercenaryData] = []
			for e: MercenaryData in enemies:
				if _can_attack_target(merc, e, state):
					valid_targets.append(e)

			var allies := state.get_allies(merc)
			var decision := CombatDecision.decide_next_action(
				merc, enemies, valid_targets, allies, current_target, state,
				ATTACK_BASE_AP, MOVE_BASE_AP, {}, movement_blocked)

			match decision["type"]:
				"move":
					var move_lines := _execute_move(merc, decision["action_name"], decision["target"], state,
						decision.get("flank_ally"))
					if move_lines.is_empty():
						# Move was a no-op (wall, already in position); fall through to attack
						movement_blocked = true
						continue
					lines.append_array(move_lines)
					movement_blocked = false
				"special":
					var spec_lines := _execute_special(merc, decision["action_name"], state, enhancements)
					lines.append_array(spec_lines)
					if spec_lines.is_empty():
						break
				"reload":
					var reload_lines := _execute_reload(merc, state)
					if reload_lines.is_empty():
						break
					lines.append_array(reload_lines)
				"attack":
					current_target = decision["target"]
					state.last_attacked[merc] = current_target
					var atk_cost := state.get_cost(merc, "Attack", ATTACK_BASE_AP)
					var atk_flaws := _compute_attack_flaws(merc, current_target, state)
					var atk := AttackSystem.execute_attack(merc, enhancements, atk_flaws, current_target)
					state.spend_ap(merc, atk_cost)
					state.record_action(merc, "Attack")
					if atk.get("misfired", false):
						lines.append("  %s's weapon misfires!" % _cn(merc, state))
					elif atk.get("no_ammo", false):
						lines.append("  %s has no ammo loaded!" % _cn(merc, state))
						break
					elif atk["damage"] > 0:
						lines.append_array(_apply_damage(merc, current_target, atk["damage"], atk["damage_type"], state, enhancements))
						if not BattleState._is_alive(current_target):
							current_target = null
					else:
						lines.append("  %s misses against %s." % [_cn(merc, state), _cn(current_target, state)])
				_:
					break

	state.end_of_turn(merc)
	if merc.excess_ap > 0:
		lines.append("  %s carries over [color=purple]%d[/color] excess AP.\n" % [_cn(merc, state), merc.excess_ap])
	else:
		lines.append("")
	return lines


static func _process_start_of_turn_states(merc: MercenaryData, state: BattleState, lines: Array[String]) -> bool:
	if ConstStates.has_state(merc, ConstStates.SURPRISED):
		lines.append("  %s is surprised and cannot act!" % _cn(merc, state))
		if state.round_number > 1:
			ConstStates.remove_state(merc, ConstStates.SURPRISED)
		return true

	if ConstStates.has_state(merc, ConstStates.DYING):
		_run_death_test(merc, state, lines)
		return ConstStates.has_state(merc, ConstStates.DYING)

	if ConstStates.has_state(merc, ConstStates.BURNING):
		var hp_before := merc.current_hp
		merc.current_hp = maxi(0, merc.current_hp - 1)
		lines.append("  %s is burning! Takes 1 Fire damage. (HP [color=red]%d→%d[/color])" % [
			_cn(merc, state), hp_before, merc.current_hp])
		_check_dot_death(merc, state, lines)

	if ConstStates.has_state(merc, ConstStates.SUFFOCATING):
		var hp_before := merc.current_hp
		merc.current_hp = maxi(0, merc.current_hp - 1)
		lines.append("  %s is suffocating! Takes 1 damage. (HP [color=red]%d→%d[/color])" % [
			_cn(merc, state), hp_before, merc.current_hp])
		_check_dot_death(merc, state, lines)

	return false


static func _run_death_test(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	var max_hp := int(merc.stats.get("maximum_hit_points", 1))
	var effective_max := max_hp - merc.death_test_hp_loss
	if effective_max <= 0:
		merc.current_hp = -1
		ConstStates.remove_state(merc, ConstStates.DYING)
		lines.append("  %s succumbs to their wounds!" % _cn(merc, state))
		return
	var cheat_death := floorf(float(merc.stats.get("cheat_death", 0.0)))
	var any_success := false
	var new_failures := 0
	for _i: int in range(effective_max):
		if float(randi_range(1, 100)) <= cheat_death:
			any_success = true
		else:
			new_failures += 1
	merc.death_test_hp_loss += new_failures
	if any_success:
		merc.current_hp = 1
		ConstStates.remove_state(merc, ConstStates.DYING)
		lines.append("  %s makes a miraculous recovery!" % _cn(merc, state))
	else:
		var new_effective := max_hp - merc.death_test_hp_loss
		if new_effective <= 0:
			merc.current_hp = -1
			ConstStates.remove_state(merc, ConstStates.DYING)
			lines.append("  %s succumbs to their wounds!" % _cn(merc, state))
		else:
			lines.append("  %s is still dying! (Max HP reduced to %d)" % [_cn(merc, state), new_effective])


static func _check_dot_death(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	if merc.current_hp > 0:
		return
	if ConstStates.has_state(merc, ConstStates.DYING):
		merc.current_hp = -1
		ConstStates.remove_state(merc, ConstStates.DYING)
		lines.append("  %s is dead!" % _cn(merc, state))
	else:
		merc.current_hp = 0
		ConstStates.apply_state(merc, ConstStates.DYING)
		lines.append("  %s is dying!" % _cn(merc, state))


static func _update_auto_states(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	if state.battlefield == null:
		return

	var is_threatened := false
	var merc_weapon := merc.equipped_weapon
	if merc_weapon != null and (merc_weapon.is_ranged or merc_weapon.is_throwable):
		for enemy: MercenaryData in state.get_enemies(merc):
			if state.distance_to(merc, enemy) <= 2:
				is_threatened = true
				break
	var was_threatened := ConstStates.has_state(merc, ConstStates.THREATENED)
	if is_threatened and not was_threatened:
		ConstStates.apply_state(merc, ConstStates.THREATENED)
		lines.append("  %s is threatened!" % _cn(merc, state))
	elif not is_threatened and was_threatened:
		ConstStates.remove_state(merc, ConstStates.THREATENED)

	var merc_size := int(merc.stats.get("size", 1))
	var merc_pos := state.get_position(merc)
	var has_north := false
	var has_south := false
	var has_west := false
	var has_east := false
	for enemy: MercenaryData in state.get_enemies(merc):
		var flanker_size := int(enemy.stats.get("size", 1))
		if flanker_size < merc_size - 1:
			continue
		var epos := state.get_position(enemy)
		var dy := epos.y - merc_pos.y
		var dx := epos.x - merc_pos.x
		if dy < 0:
			has_north = true
		elif dy > 0:
			has_south = true
		if dx < 0:
			has_west = true
		elif dx > 0:
			has_east = true
	var is_flanked := (has_north and has_south) or (has_west and has_east)
	var was_flanked := ConstStates.has_state(merc, ConstStates.FLANKED)
	if is_flanked and not was_flanked:
		ConstStates.apply_state(merc, ConstStates.FLANKED)
		lines.append("  %s is flanked!" % _cn(merc, state))
	elif not is_flanked and was_flanked:
		ConstStates.remove_state(merc, ConstStates.FLANKED)


static func _execute_special(
		merc: MercenaryData,
		action_name: String,
		state: BattleState,
		enhancements: int) -> Array[String]:
	var lines: Array[String] = []
	match action_name:
		"get_up":
			var cost := state.get_cost(merc, "get_up", 2)
			state.spend_ap(merc, cost)
			state.record_action(merc, "get_up")
			ConstStates.remove_state(merc, ConstStates.DEPOSED)
			lines.append("  %s gets up!" % _cn(merc, state))
		"seek_cover":
			var cost := state.get_cost(merc, "seek_cover", 2)
			state.spend_ap(merc, cost)
			state.record_action(merc, "seek_cover")
			_do_seek_cover(merc, state, lines)
		"break_free":
			var cost := state.get_cost(merc, "break_free", 2)
			state.spend_ap(merc, cost)
			state.record_action(merc, "break_free")
			_do_break_free(merc, state, enhancements, lines)
	return lines


static func _do_seek_cover(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	if state.battlefield == null:
		return
	var merc_pos := state.get_position(merc)
	var adj_obs := state.battlefield.get_adjacent_obstacles(merc_pos)
	if adj_obs.is_empty():
		lines.append("  %s looks for cover but finds none adjacent!" % _cn(merc, state))
		return
	var all_enemies := state.get_enemies(merc)
	var ranged_enemies: Array[MercenaryData] = []
	for e: MercenaryData in all_enemies:
		if e.equipped_weapon != null and e.equipped_weapon.is_ranged:
			ranged_enemies.append(e)
	var merc_size: int = int(merc.stats.get("size", 1))
	var best_obs: Dictionary = adj_obs[0]
	var best_size := -1
	var best_covers_enemy := false
	for obs: Dictionary in adj_obs:
		var op: Vector2i = obs["pos"] as Vector2i
		var os: int = int(obs["size"])
		var raw := op - merc_pos
		var dir_x := signi(raw.x)
		var dir_y := signi(raw.y)
		var covers_enemy := false
		for enemy: MercenaryData in ranged_enemies:
			var epos := state.get_position(enemy)
			var to_e := epos - merc_pos
			var ok_x := dir_x == 0 or signi(to_e.x) == dir_x
			var ok_y := dir_y == 0 or signi(to_e.y) == dir_y
			if ok_x and ok_y:
				covers_enemy = true
				break
		if (covers_enemy and not best_covers_enemy) \
				or (covers_enemy == best_covers_enemy and os > best_size):
			best_obs = obs
			best_size = os
			best_covers_enemy = covers_enemy
	var obs_pos: Vector2i = best_obs["pos"] as Vector2i
	var obs_size: int = int(best_obs["size"])
	var cover_type: String = ConstStates.COVERED_FULL if obs_size > merc_size else ConstStates.COVERED_PARTIAL
	state.set_cover(merc, obs_pos, obs_size, cover_type)
	var covered_names: Array[String] = []
	for enemy: MercenaryData in ranged_enemies:
		if state.is_covered_from(merc, enemy, cover_type):
			covered_names.append(_cn(enemy, state))
	var vs_str := ", ".join(covered_names) if not covered_names.is_empty() else "no ranged enemies"
	lines.append("  %s takes %s (size %d) vs %s." % [_cn(merc, state), cover_type, obs_size, vs_str])


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
	var source: MercenaryData = ConstStates.get_source(merc, state_name)
	var source_vigor := 0
	if source != null:
		source_vigor = int(source.stats.get("vigor", 0))
	var check_def := {
		"stat_keys":          ["vigor"],
		"circumstances":      [],
		"knowledges":         [],
		"tools":              [],
		"formula":            "luck",
		"enhancements":       enhancements,
		"flat_threshold_bonus": float(-source_vigor * 10),
	}
	var result := CheckSystem.make_check(merc, check_def)
	if int(result["successes"]) > 0:
		ConstStates.remove_state(merc, state_name)
		if state_name == ConstStates.SUFFOCATING:
			ConstStates.remove_state(merc, ConstStates.GRAPPLED)
		lines.append("  %s breaks free!" % _cn(merc, state))
	else:
		lines.append("  %s fails to break free!" % _cn(merc, state))


static func _execute_move(
		merc: MercenaryData,
		action_name: String,
		move_target: MercenaryData,
		state: BattleState,
		flank_ally: MercenaryData = null) -> Array[String]:
	if move_target == null:
		return []

	var old_pos := state.get_position(merc)
	var new_pos := _compute_move_position(merc, move_target, action_name, state, flank_ally)

	if new_pos == old_pos:
		return []

	var move_cost := state.get_cost(merc, action_name, MOVE_BASE_AP)
	state.spend_ap(merc, move_cost)
	state.record_action(merc, action_name)
	state.set_position(merc, new_pos)
	state.clear_cover(merc)

	var move_lines: Array[String] = []
	var verb := "moves away from" if action_name == "Move Far" else "moves toward"
	move_lines.append("  %s %s %s.  ([color=orange]%d,%d → %d,%d[/color])" % [
		_cn(merc, state), verb, _cn(move_target, state),
		old_pos.x, old_pos.y, new_pos.x, new_pos.y])

	var can_fly := int(merc.stats.get("fly", 0)) > 0 and not ConstStates.has_state(merc, ConstStates.GROUNDED)
	if can_fly and state.battlefield != null:
		var pace := maxi(1, int(merc.stats.get("pace", 1)))
		var horiz_steps := maxi(abs(old_pos.x - new_pos.x), abs(old_pos.y - new_pos.y))
		var remaining_pace := maxi(0, pace - horiz_steps)
		if remaining_pace > 0:
			var current_h := state.get_height(merc)
			var target_h := current_h
			if action_name == "Move Close":
				var cover_info := state.get_cover_info(move_target)
				if not cover_info.is_empty():
					var obs_x: int = int(cover_info.get("obstacle_pos_x", 0))
					var obs_y: int = int(cover_info.get("obstacle_pos_y", 0))
					var obs_size: int = int(cover_info.get("obstacle_size", 0))
					var horiz_to_obs := maxi(abs(new_pos.x - obs_x), abs(new_pos.y - obs_y))
					target_h = obs_size + horiz_to_obs + 1
			var delta := mini(remaining_pace, maxi(0, target_h - current_h))
			if delta > 0:
				state.set_height(merc, current_h + delta)
				move_lines.append("  %s ascends to height %d." % [_cn(merc, state), state.get_height(merc)])

	return move_lines


static func _compute_move_position(
		merc: MercenaryData,
		move_target: MercenaryData,
		action_name: String,
		state: BattleState,
		flank_ally: MercenaryData = null) -> Vector2i:
	var from := state.get_position(merc)
	var to := state.get_position(move_target)
	var pace := maxi(1, int(merc.stats.get("pace", 1)))
	if ConstStates.has_state(merc, ConstStates.DEPOSED):
		pace = mini(pace, 1)
	var field := state.battlefield

	var dx := to.x - from.x
	var dy := to.y - from.y
	if dx == 0 and dy == 0:
		return from

	var step := Vector2i(signi(dx), signi(dy))

	if action_name == "Move Far":
		return field.clamp_position(from - step * pace)

	var stop_dist := MELEE_RANGE
	var weapon := merc.equipped_weapon
	if weapon != null and not weapon.is_ranged:
		stop_dist = weapon.melee_range

	if flank_ally != null:
		var ally_pos := state.get_position(flank_ally)
		var flank_step := Vector2i(signi(to.x - ally_pos.x), signi(to.y - ally_pos.y))
		if flank_step != Vector2i.ZERO:
			var flank_target := to + flank_step * stop_dist
			dx = flank_target.x - from.x
			dy = flank_target.y - from.y
			step = Vector2i(signi(dx), signi(dy))

	var dist_to_target := maxi(abs(dx), abs(dy))
	var max_steps := maxi(0, dist_to_target - stop_dist)
	var actual_steps := mini(pace, max_steps)
	if actual_steps == 0:
		return from
	var ranged_enemies: Array[MercenaryData] = []
	for e: MercenaryData in state.get_enemies(merc):
		if e.equipped_weapon != null and e.equipped_weapon.is_ranged:
			ranged_enemies.append(e)
	if not ranged_enemies.is_empty():
		for s: int in range(actual_steps, 0, -1):
			var candidate := field.clamp_position(from + step * s)
			if _position_has_cover_from(candidate, ranged_enemies, state):
				return candidate
	return field.clamp_position(from + step * actual_steps)


static func _position_has_cover_from(
		pos: Vector2i,
		ranged_enemies: Array[MercenaryData],
		state: BattleState) -> bool:
	var field := state.battlefield
	for obs: Dictionary in field.get_adjacent_obstacles(pos):
		var obs_pos: Vector2i = obs["pos"]
		var cover_dir := Vector2i(signi(obs_pos.x - pos.x), signi(obs_pos.y - pos.y))
		for enemy: MercenaryData in ranged_enemies:
			var ep := state.get_position(enemy)
			var atk_dir := Vector2i(signi(ep.x - pos.x), signi(ep.y - pos.y))
			var covered := true
			if cover_dir.x != 0 and cover_dir.x != atk_dir.x:
				covered = false
			if cover_dir.y != 0 and cover_dir.y != atk_dir.y:
				covered = false
			if covered:
				return true
	return false


static func _compute_attack_flaws(
		attacker: MercenaryData,
		target: MercenaryData,
		state: BattleState) -> int:
	if state.battlefield == null:
		return 0
	var weapon := attacker.equipped_weapon
	if weapon == null:
		return 0
	var dist := state.distance_to(attacker, target)
	if weapon.is_ranged and weapon.ranged_intended_range > 0:
		if dist > weapon.ranged_intended_range:
			return 1
	elif weapon.is_throwable and weapon.thrown_intended_range > 0:
		if dist > weapon.thrown_intended_range:
			return 1
	return 0


static func _execute_reload(merc: MercenaryData, state: BattleState) -> Array[String]:
	var weapon := merc.equipped_weapon
	if weapon == null or not weapon.is_ranged:
		return []
	if merc.ammo_loaded >= weapon.chamber:
		return []
	var ammo_type := merc.ammo_loaded_type
	if ammo_type == "":
		return []
	var available: int = merc.ammo_inventory.get(ammo_type, 0)
	if available <= 0:
		return []
	var reload_cost := weapon.load_time
	if reload_cost <= 0 or not state.can_afford(merc, reload_cost):
		return []
	var to_load := mini(weapon.chamber - merc.ammo_loaded, available)
	if to_load <= 0:
		return []
	merc.ammo_loaded += to_load
	merc.ammo_inventory[ammo_type] -= to_load
	if merc.ammo_inventory[ammo_type] <= 0:
		merc.ammo_inventory.erase(ammo_type)
	state.spend_ap(merc, reload_cost)
	var remaining: int = merc.ammo_inventory.get(ammo_type, 0)
	return ["  %s reloads. (%d in chamber, %d remaining)" % [_cn(merc, state), merc.ammo_loaded, remaining]]


static func _can_attack_target(
		attacker: MercenaryData,
		target: MercenaryData,
		state: BattleState) -> bool:
	if state.battlefield != null and state.is_covered_from(target, attacker, ConstStates.COVERED_FULL):
		return false
	if state.battlefield == null:
		return true
	var weapon := attacker.equipped_weapon
	var dist := state.distance_to(attacker, target)
	if weapon == null:
		return dist <= MELEE_RANGE
	if weapon.is_ranged:
		if attacker.ammo_loaded <= 0:
			return false
		if attacker.weapon_misfired:
			return false
		return weapon.ranged_extended_range <= 0 or dist <= weapon.ranged_extended_range
	if weapon.is_throwable:
		return weapon.thrown_extended_range <= 0 or dist <= weapon.thrown_extended_range
	return dist <= weapon.melee_range


static func _apply_damage(
		attacker: MercenaryData,
		defender: MercenaryData,
		damage: int,
		damage_type: String,
		state: BattleState,
		extra_enhancements: int = 0) -> Array[String]:
	var lines: Array[String] = []
	var hp_before := defender.current_hp
	var was_dying := ConstStates.has_state(defender, ConstStates.DYING)
	var used_excess_ap := false

	var free_def := false
	if state.battlefield != null:
		free_def = state.is_covered_from(defender, attacker, ConstStates.COVERED_PARTIAL)

	# Slowed defenders need 2 excess AP to substitute for EP
	var excess_needed := 2 if ConstStates.has_state(defender, ConstStates.SLOWED) else 1
	if defender.current_ep <= 0 and defender.excess_ap >= excess_needed \
			and not ConstStates.has_state(defender, ConstStates.DEBILITATED) \
			and CombatDecision.should_use_excess_ap_to_defend(defender, damage, damage_type):
		defender.excess_ap -= excess_needed
		defender.current_ep = 1  # temporarily; DefenseSystem will spend it back to 0
		used_excess_ap = true

	var res := DefenseSystem.resolve(defender, damage, damage_type, extra_enhancements, free_def)
	var atk_name := _cn(attacker, state)
	var def_name := _cn(defender, state)

	if res["is_immune"]:
		lines.append("  %s is immune to %s." % [def_name, damage_type])
		return lines

	var in_dmg: int = res["modified_damage"]
	var final_dmg: int = res["final_damage"]
	var defended: bool = res["ep_spent"] > 0
	var excess_note := " (using excess AP)" if used_excess_ap else ""

	var sentence: String
	if defended or used_excess_ap:
		if final_dmg == 0:
			sentence = "  %s deals [color=red]%d[/color] %s to %s, but %s defends%s and negates it." % [
				atk_name, in_dmg, damage_type, def_name, def_name, excess_note]
		else:
			sentence = "  %s deals [color=red]%d[/color] %s to %s, but %s defends%s, reducing it to [color=red]%d[/color].  (%s: HP [color=red]%d[/color]→[color=red]%d[/color])" % [
				atk_name, in_dmg, damage_type, def_name,
				def_name, excess_note, final_dmg,
				def_name, hp_before, defender.current_hp]
	else:
		sentence = "  %s deals [color=red]%d[/color] %s to %s.  (%s: HP [color=red]%d[/color]→[color=red]%d[/color])" % [
			atk_name, in_dmg, damage_type, def_name,
			def_name, hp_before, defender.current_hp]
	lines.append(sentence)

	if final_dmg >= 1 and was_dying:
		defender.current_hp = -1
		ConstStates.remove_state(defender, ConstStates.DYING)
		lines.append("  %s is dead!" % def_name)
	elif defender.current_hp <= 0 and not was_dying:
		defender.current_hp = 0
		ConstStates.apply_state(defender, ConstStates.DYING)
		lines.append("  %s is dying!" % def_name)

	state.record_damage_dealt(attacker, defender, final_dmg)
	return lines


static func _cn(merc: MercenaryData, state: BattleState) -> String:
	var first := merc.merc_name.get_slice(" ", 0)
	for i: int in range(state.teams.size()):
		if (state.teams[i] as Array).has(merc):
			return "[color=%s]%s[/color]" % ["white" if i == 0 else "yellow", first]
	return first
