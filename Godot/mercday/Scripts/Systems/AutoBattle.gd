class_name AutoBattle

const ATTACK_BASE_AP := 3
const MOVE_BASE_AP := 2
const DRAW_BASE_AP := 0   # actual cost = weapon.draw via get_cost()
const MELEE_RANGE := 1
const MAX_ROUNDS := 100

static var _stale_rounds: int = 0
static var _no_target_rounds: int = 0
static var _turn_path_cache: Dictionary = {}  # merc -> {goal, path, idx} — cleared each turn
static var _blocked_path_goals: Dictionary = {}  # goal -> round_number; evicted when round changes
static var _near_passable_cache: Dictionary = {}  # raw goal -> adjusted goal; terrain-static per encounter
static var _last_move_heavy: bool = false  # true when oscillation flanking BFS ran; suppresses _skip_await


static func run_battle(state: BattleState, line_fn: Callable = Callable(), encounter_type: String = "encounter") -> Dictionary:
	setup(state, line_fn, encounter_type)
	while await step_round(state, line_fn):
		pass
	return {"winner": state.get_winner(), "rounds": state.round_number}


# Emits the battlefield header/visual and begins the encounter logger.
# Call once before the first step_round().
static func setup(state: BattleState, line_fn: Callable = Callable(), encounter_type: String = "encounter") -> void:
	_stale_rounds = 0
	_no_target_rounds = 0
	CoverNearbyFacet._scan_cache.clear()
	_turn_path_cache.clear()
	_blocked_path_goals.clear()
	_near_passable_cache.clear()
	EncounterLogger.begin(encounter_type, state)
	if state.battlefield != null:
		_emit(line_fn, "[color=gray]%s[/color]" % state.battlefield.to_header_string())
		EncounterLogger.log_line(state.battlefield.to_visual_string())
		EncounterLogger.log_generation(state.battlefield)


# Processes exactly one round and emits its lines.
# Returns true if the battle is still ongoing; false when it ends (also finalizes).
static func step_round(state: BattleState, line_fn: Callable = Callable()) -> bool:
	if state.is_battle_over() or state.round_number >= MAX_ROUNDS:
		_finalize(state, line_fn)
		return false
	state.round_number += 1
	state.rotate_round_damage()
	_emit(line_fn, "[color=gray]=== Round %d ===[/color]" % state.round_number)
	var _any_attacked := false
	var any_acted := false
	for merc: MercenaryData in state.turn_queue:
		if not BattleState._is_alive(merc):
			if EncounterLogger.is_active():
				if merc.current_hp == 0 and not ConstStates.has_state(merc, ConstStates.DYING):
					EncounterLogger.log_verbose("Skipping dead merc %s (hp=0, no Dying state — cheat death was not triggered)" % merc.merc_name)
				else:
					EncounterLogger.log_verbose("Skipping dead merc %s (hp=%d)" % [merc.merc_name, merc.current_hp])
			continue
		if state.is_battle_over():
			break
		var turn_lines: Array[String]
		if ConstStates.has_state(merc, ConstStates.DYING):
			turn_lines = _execute_dying_turn(merc, state)
		else:
			turn_lines = await _execute_turn(merc, state)
			var _esc := state.escalation.get(merc, {}) as Dictionary
			if _esc.get("Attack", 0) > 0:
				_any_attacked = true
			if not _esc.is_empty():
				any_acted = true
		for line: String in turn_lines:
			EncounterLogger.log_line(line)
		if line_fn.is_valid() and not turn_lines.is_empty():
			line_fn.call("\n".join(turn_lines))
		EncounterLogger.flush()
		await Engine.get_main_loop().process_frame
	if state.is_battle_over() or state.round_number >= MAX_ROUNDS:
		_finalize(state, line_fn)
		return false
	if _any_attacked:
		_no_target_rounds = 0
	else:
		_no_target_rounds += 1
		if _no_target_rounds >= 10:
			_emit(line_fn, "[color=red]Stalemate: no target found for 10 consecutive rounds.[/color]")
			var _dw1: int = _stalemate_winner(state)
			if _dw1 >= 0:
				state._cached_winner = _dw1
				_emit(line_fn, "[color=orange]Win by default: Team %d (HP/skill advantage).[/color]" % _dw1)
			_finalize(state, line_fn)
			return false
	if not any_acted:
		_stale_rounds += 1
		if _stale_rounds >= 2:
			_emit(line_fn, "[color=red]Stalemate: no actions for 2 consecutive rounds.[/color]")
			var _dw2: int = _stalemate_winner(state)
			if _dw2 >= 0:
				state._cached_winner = _dw2
				_emit(line_fn, "[color=orange]Win by default: Team %d (HP/skill advantage).[/color]" % _dw2)
			_finalize(state, line_fn)
			return false
	else:
		_stale_rounds = 0
	return true


static func _finalize(state: BattleState, _line_fn: Callable) -> void:
	state.clear_encounter_cache()
	if not state.dropped_weapons.is_empty():
		for team in state.teams:
			for merc: MercenaryData in team:
				state.retrieve_dropped_weapons_for(merc)
	if state.get_winner() < 0 and state._cached_winner == -2:
		var _dw: int = _stalemate_winner(state)
		if _dw >= 0:
			state._cached_winner = _dw
	var result := {"winner": state.get_winner(), "rounds": state.round_number}
	state._cached_winner = result["winner"]
	EncounterLogger.end(result)
	var all_mercs: Array[MercenaryData] = []
	for team in state.teams:
		for merc: MercenaryData in team:
			all_mercs.append(merc)
	_reset_mercs_after_battle(all_mercs)


static func _stalemate_winner(state: BattleState) -> int:
	var team_hp: Array[int] = []
	var team_accuracy: Array[float] = []
	var team_pace: Array[float] = []
	for i: int in range(state.teams.size()):
		var hp := 0
		var acc := 0.0
		var spd := 0.0
		var alive := 0
		for m: MercenaryData in state.teams[i]:
			if m.current_hp > 0:
				hp += m.current_hp
				acc += maxf(float(m.stats.get("melee_accuracy", 0)), float(m.stats.get("ranged_accuracy", 0)))
				spd += float(m.stats.get("pace", 1))
				alive += 1
		team_hp.append(hp)
		team_accuracy.append(acc / maxf(1.0, float(alive)))
		team_pace.append(spd / maxf(1.0, float(alive)))
	if state.teams.size() < 2:
		return 0
	if team_hp[0] != team_hp[1]:
		return 0 if team_hp[0] > team_hp[1] else 1
	if not is_equal_approx(team_accuracy[0], team_accuracy[1]):
		return 0 if team_accuracy[0] > team_accuracy[1] else 1
	if not is_equal_approx(team_pace[0], team_pace[1]):
		return 0 if team_pace[0] > team_pace[1] else 1
	return -1


# TEMP: post-battle stat reset for testing
static func _reset_mercs_after_battle(mercs: Array) -> void:
	for merc: MercenaryData in mercs:
		merc.current_hp = int(merc.stats.get("maximum_hit_points", merc.current_hp))
		merc.current_ep = int(merc.stats.get("maximum_endurance_points", merc.current_ep))
		merc.current_ap = int(merc.stats.get("action_points", merc.current_ap))
		var max_mp: int = int(merc.stats.get("maximum_magic_points", 0))
		if max_mp > 0:
			merc.current_mp = max_mp
		merc.ap_debt = 0
		BattleState._reset_starting_ammo(merc)


static func _emit(line_fn: Callable, line: String) -> void:
	if line_fn.is_valid():
		line_fn.call(line)
	EncounterLogger.log_line(line)


static func _execute_dying_turn(merc: MercenaryData, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	_run_death_test(merc, state, lines)
	_run_dying_perks(merc, state, lines)
	lines.append("")
	return lines


static func _run_dying_perks(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	# Dying Perks: weapon/armor perks prefixed with "dying_perk:" fire once per turn while merc is Dying.
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
		if perk.effect_dsl.begins_with("dying_perk:"):
			lines.append("  %s (Dying Perk: %s)" % [_cn(merc, state), perk.trait_name])


static func _execute_turn(merc: MercenaryData, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	state.start_of_turn(merc)
	merc.combat_idle_rounds += 1
	if merc.combat_idle_rounds >= 3:
		state.position_history.erase(merc)
	# Drain deferred effects queued for this merc's turn start (e.g. Dagger Bleedout)
	var _remaining_effects: Array = []
	for _eff in merc.deferred_effects:
		if _eff["timing"] == "self_turn_start":
			var _tgt := _eff["target"] as MercenaryData
			if BattleState._is_alive(_tgt):
				lines.append_array(_apply_damage(merc, _tgt, _eff["damage"], _eff["type"], state))
		else:
			_remaining_effects.append(_eff)
	merc.deferred_effects = _remaining_effects
	if merc.weapon_misfired:
		merc.weapon_misfired = false
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("  [MISFIRE RESET] %s: weapon_misfired cleared at turn start" % merc.merc_name)
	else:
		merc.weapon_misfired = false
	if ConstStates.has_state(merc, ConstStates.DEBILITATED):
		merc.current_ap = 0
		merc.excess_ap = 0
		merc.ap_debt = 0
	_update_auto_states(merc, state, lines)

	var enhancements: int = maxi(0, state.round_number - 1)
	var excess_str := "  ExAP:[color=purple]%d[/color]" % merc.excess_ap if merc.excess_ap > 0 else ""
	var enh_str := "  Enh:[color=cyan]%d[/color]" % enhancements if enhancements > 0 else ""
	var pos_str := ""
	if state.battlefield != null:
		var p := state.get_position(merc)
		var h := state.get_height(merc)
		pos_str = "  [color=orange](%d,%d h%d)[/color]" % [p.x, p.y, h + 1]
	EncounterLogger.log_line("%s  HP:[color=red]%d[/color]  EP:[color=green]%d[/color]%s%s%s" % [
		_cn(merc, state), merc.current_hp, merc.current_ep, excess_str, enh_str, pos_str])

	if EncounterLogger.is_active():
		var _log_w := merc.equipped_weapon
		if _log_w != null:
			var _log_wtype := "ranged" if _log_w.is_ranged else ("throwable" if _log_w.is_throwable else "melee")
			var _log_ammo := " [%dc+%dr %s]" % [merc.ammo_loaded, merc.ammo_inventory.get(merc.ammo_loaded_type, 0), merc.ammo_loaded_type] if _log_w.is_ranged else ""
			EncounterLogger.log_verbose("WEAPON: %s (%s) range=%d dmg=%s%s" % [
				_log_w.item_name, _log_wtype,
				_log_w.ranged_intended_range if _log_w.is_ranged else _log_w.melee_range,
				_log_w.damage_formula_1, _log_ammo])
		else:
			EncounterLogger.log_verbose("WEAPON: unarmed")
		EncounterLogger.log_verbose("STATS: melee_acc=%.0f%% ranged_acc=%.0f%% pace=%d pain_limit=%d" % [
			float(merc.stats.get("melee_accuracy", 0.0)),
			float(merc.stats.get("ranged_accuracy", 0.0)),
			int(merc.stats.get("pace", 1)),
			int(merc.stats.get("pain_limit", 0))])

	var skip_actions := _process_start_of_turn_states(merc, state, lines)

	# spend:ep:1:ap_cost_attack:-1:until_turn_end (Longbow Quick-Shot)
	var attack_ap_reduction := 0
	if not skip_actions:
		for _qs_perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
			if "ap_cost_attack:-1:until_turn_end" in _qs_perk.effect_dsl:
				if merc.current_ep >= 1:
					merc.current_ep -= 1
					attack_ap_reduction += 1
					lines.append("  %s activates Quick-Shot (-1 AP attacks)." % _cn(merc, state))
				break

	var weapon_action_taken := false
	if not skip_actions:
		var current_target: MercenaryData = null
		var movement_blocked := false
		var has_moved := false
		var had_valid_targets := false
		var seeking_failed := false
		var blocked_targets: Dictionary = {}
		var _action_slot := 0
		var _skip_await := false

		if state.battlefield != null:
			var _ap_cache: Dictionary = {}
			for _a: MercenaryData in state.get_allies(merc):
				if BattleState._is_alive(_a) and not ConstStates.has_state(_a, ConstStates.DEPOSED):
					var _apos: Vector2i = state.positions.get(_a, Vector2i(-1, -1))
					if _apos != Vector2i(-1, -1):
						_ap_cache[_apos] = true
			_ap_cache.merge(state.battlefield.get_nav_passable_cells())
			state.turn_ally_passable[merc] = _ap_cache
			_turn_path_cache.erase(merc)

		while true:
			_action_slot += 1
			if _action_slot > 50:
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("WARNING: action slot cap reached — ending turn")
				break
			if merc.current_ap <= 0 and merc.excess_ap <= 0:
				break
			if not _skip_await:
				await Engine.get_main_loop().process_frame
			_skip_await = false
			_last_move_heavy = false
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("-- ACTION SLOT %d (AP=%d ExAP=%d) --" % [
					_action_slot, merc.current_ap, merc.excess_ap])
			var enemies := state.get_enemies(merc)
			if enemies.is_empty():
				break

			if current_target != null and not enemies.has(current_target):
				merc.last_seen_position = Vector2i(-1, -1)
				current_target = null

			var valid_targets: Array[MercenaryData] = []
			for e: MercenaryData in enemies:
				if _can_attack_target(merc, e, state):
					valid_targets.append(e)

			if not valid_targets.is_empty():
				had_valid_targets = true

			if state.battlefield != null:
				for e: MercenaryData in valid_targets:
					merc.last_known_enemy_positions[e] = state.get_position(e)

			if EncounterLogger.is_active() and valid_targets.is_empty() and not enemies.is_empty():
				for e: MercenaryData in enemies:
					var _vt_weapon := merc.equipped_weapon
					var _vt_dist := state.distance_to(merc, e) if state.battlefield != null else -1
					var _vt_is_melee := _vt_weapon == null or (not _vt_weapon.is_ranged and not _vt_weapon.is_throwable)
					var _vt_range := WeaponArmorPerkLibrary.get_effective_melee_range(merc) if _vt_weapon != null else MELEE_RANGE
					var _vt_covered := state.battlefield != null and state.is_covered_from(e, merc, ConstStates.COVERED_FULL)
					var _vt_reason: String
					if state.battlefield == null:
						_vt_reason = "no battlefield"
					elif _vt_covered and not (_vt_is_melee and _vt_dist <= _vt_range):
						_vt_reason = "covered_full"
					elif _vt_is_melee and _vt_dist > _vt_range:
						_vt_reason = "out_of_range dist=%d range=%d" % [_vt_dist, _vt_range]
					elif _vt_weapon != null and _vt_weapon.is_ranged and merc.ammo_loaded <= 0:
						_vt_reason = "no_ammo"
					elif _vt_weapon != null and _vt_weapon.is_ranged and merc.weapon_misfired:
						_vt_reason = "misfired"
					elif _vt_weapon != null and _vt_weapon.is_ranged \
							and _vt_weapon.ranged_extended_range > 0 \
							and _vt_dist > _vt_weapon.ranged_extended_range:
						_vt_reason = "out_of_range dist=%d intended=%d max=%d" % [_vt_dist, _vt_weapon.ranged_intended_range, _vt_weapon.ranged_extended_range]
					elif _vt_weapon != null and _vt_weapon.is_throwable \
							and _vt_weapon.thrown_extended_range > 0 \
							and _vt_dist > _vt_weapon.thrown_extended_range:
						_vt_reason = "out_of_throw_range dist=%d intended=%d max=%d" % [_vt_dist, _vt_weapon.thrown_intended_range, _vt_weapon.thrown_extended_range]
					else:
						_vt_reason = "unknown"
					EncounterLogger.log_verbose("NO_VALID_TARGET: %s rejected %s — %s" % [
						merc.merc_name, e.merc_name, _vt_reason])

			var allies := state.get_allies(merc)

			# All enemies proven unreachable this turn and nothing in attack range → end turn
			if valid_targets.is_empty() and (
					(not blocked_targets.is_empty() and blocked_targets.size() >= enemies.size())
					or movement_blocked):
				break

			var perk_action := _choose_perk_action(merc, current_target, state)
			if perk_action != null:
				var perk_lines := _execute_perk_action(merc, perk_action, current_target, state, enhancements)
				if not perk_lines.is_empty():
					lines.append_array(perk_lines)
					continue

			var decision := _choose_from_action_set(
				merc, enemies, valid_targets, allies, current_target, state, movement_blocked, weapon_action_taken, has_moved, seeking_failed, blocked_targets)

			match decision["type"]:
				"move":
					var _is_seeking: bool = decision.get("seeking", false)
					var move_lines := _execute_move(merc, decision["action_name"], decision["target"], state,
						decision.get("flank_ally"), enhancements, decision.get("move_stop_dist", -1), _is_seeking)
					if move_lines.is_empty():
						movement_blocked = true
						state.record_action(merc, decision["action_name"])
						if not _last_move_heavy:
							_skip_await = true
						if _is_seeking:
							seeking_failed = true
							var _bt: MercenaryData = decision.get("target")
							if _bt != null:
								blocked_targets[_bt] = true
					else:
						lines.append_array(move_lines)
						movement_blocked = false
						has_moved = true
						blocked_targets.clear()
						current_target = decision["target"]
				"jump":
					var jump_pos: Vector2i = decision.get("jump_target_pos", Vector2i(-1, -1))
					var jump_lines := _execute_jump(merc, jump_pos, decision["action_name"], state, enhancements)
					if jump_lines.is_empty():
						movement_blocked = true
					else:
						lines.append_array(jump_lines)
						movement_blocked = false
						has_moved = true
						blocked_targets.clear()
						current_target = decision["target"]
				"climb":
					var climb_lines := _execute_climb(merc, decision, decision["action_name"], state)
					if climb_lines.is_empty():
						movement_blocked = true
					else:
						lines.append_array(climb_lines)
						movement_blocked = false
						has_moved = true
						blocked_targets.clear()
				"special":
					var spec_lines := _execute_special(merc, decision["action_name"], state, enhancements, decision.get("target"), decision.get("target_obs", {}))
					lines.append_array(spec_lines)
					if spec_lines.is_empty():
						break
					if decision["action_name"] == "aim":
						weapon_action_taken = true
				"reload":
					var reload_lines := _execute_reload(merc, state, enhancements)
					if reload_lines.is_empty():
						break
					lines.append_array(reload_lines)
				"attack":
					current_target = decision["target"]
					state.last_attacked[merc] = current_target
					if state.battlefield != null:
						merc.last_seen_position = state.get_position(current_target)
					if merc.equipped_weapon != null and merc.equipped_weapon.is_ranged:
						state.record_ranged_targeted(current_target)
					var atk_cost := maxi(0, state.get_cost(merc, "Attack", ATTACK_BASE_AP) - attack_ap_reduction)
					# spend:ep:1:weapon_stat:thrown_extended_range:+10:until_turn_end (Spear Launcher)
					var _sl_w: WeaponData = merc.equipped_weapon
					if _sl_w != null and _sl_w.is_throwable and not _sl_w.is_ranged:
						for _sl_perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
							if "weapon_stat:thrown_extended_range:+10" in _sl_perk.effect_dsl:
								if merc.current_ep >= 1:
									merc.current_ep -= 1
									merc.active_states["thrown_extended_range_bonus"] = 10
									lines.append("  %s extends throw range (1 EP)." % _cn(merc, state))
								break
					var atk_flaws := _compute_attack_flaws(merc, current_target, state)
					var aim_bonus := 1 if merc.aim_active else 0
					var weapon_enh := _get_weapon_enhance_bonus(merc)
					var _is_throw_action: bool = decision["action_name"] == "AttackThrow"
					var atk := AttackSystem.execute_attack(merc, enhancements + aim_bonus + weapon_enh, atk_flaws, current_target, _is_throw_action, state)
					merc.aim_active = false
					if atk.get("no_ammo", false):
						lines.append("  %s has no ammo loaded!" % _cn(merc, state))
						break
					state.spend_ap(merc, atk_cost)
					state.record_action(merc, "Attack")
					merc.combat_idle_rounds = 0
					weapon_action_taken = true
					if EncounterLogger.is_active() and not atk.get("misfired", false):
						var cr: Dictionary = atk["check_result"]
						EncounterLogger.log_verbose("ATTACK ROLL: %s vs %.0f%% -> %d hit %d miss  dmg=%d %s" % [
							str(cr["roll2"]), cr["threshold"],
							cr["successes"], cr["failures"],
							atk["damage"], atk["damage_type"]])
					if atk.get("misfired", false):
						lines.append("  %s misfires!" % _cn(merc, state))
					elif atk["damage"] > 0:
						var _w: WeaponData = merc.equipped_weapon
						var _is_thrown: bool = _w != null and _w.is_throwable and not _w.is_ranged
						var two_handed_bonus: int = WeaponArmorPerkLibrary.get_two_handed_damage_bonus(merc, _is_thrown)
						var final_damage: int = atk["damage"] + two_handed_bonus
						var is_crit: bool = CriticalSuccessSystem.is_critical_success(atk["check_result"], merc)
						if is_crit:
							final_damage += _get_on_crit_damage_bonus(merc, lines)
						# weapon_passive:damage_per_enhancement:N:max:cap
						for _perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
							if _perk.effect_dsl.begins_with("weapon_passive:damage_per_enhancement:"):
								var _parts := _perk.effect_dsl.split(":")
								if _parts.size() >= 5:
									var _n: int = int(_parts[2])
									var _cap: int = int(_parts[4])
									final_damage += mini(int(atk["core_successes"]) * _n, _cap)
								break
						# weapon_passive:thrown_extended_bonus_damage:+N
						if _is_thrown and _w != null and _w.thrown_intended_range > 0 \
								and state.battlefield != null \
								and state.distance_to(merc, current_target) > _w.thrown_intended_range:
							for _perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
								if _perk.effect_dsl.begins_with("weapon_passive:thrown_extended_bonus_damage:"):
									var _val_str: String = _perk.effect_dsl.get_slice(":", 2).lstrip("+")
									final_damage += int(_val_str)
									break
						# on_hit: weapon perk dispatch -- runs before normal _apply_damage
						var used_perk_effect := false
						var total_successes: int = int(atk["core_successes"]) + int(atk["weapon_die_successes"])
						for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
							var dsl: String = perk.effect_dsl
							if not dsl.begins_with("on_hit:"):
								continue
							var parts := dsl.split(":")
							# parts[0]="on_hit" parts[1]=condition parts[2]=verb parts[3...]=args
							if parts.size() < 3:
								continue
							var condition: String = parts[1]
							var meets_condition := false
							if condition == "any":
								meets_condition = true
							elif condition == "4_successes":
								meets_condition = total_successes >= 4
							if not meets_condition:
								continue
							var verb: String = parts[2]
							if verb == "choose":
								# parts[3] = "alt,damage"
								if parts.size() < 4:
									continue
								var choices := parts[3].split(",")
								var alt: String = choices[0] if choices.size() >= 1 else ""
								var prefer_alt := false
								match alt:
									"grapple":
										var pain_limit := int(current_target.stats.get("pain_limit", 0))
										prefer_alt = pain_limit > 0 and current_target.current_hp > pain_limit
									"disarm":
										prefer_alt = true
									"trip_deposed":
										prefer_alt = not ConstStates.has_state(current_target, ConstStates.DEPOSED)
									"direct_1_strike_slowed_until_turn_end":
										prefer_alt = not ConstStates.has_state(current_target, ConstStates.SLOWED)
								if prefer_alt:
									match alt:
										"grapple":
											ConstStates.apply_state(current_target, ConstStates.GRAPPLED, merc)
											lines.append("  %s grapples %s!" % [_cn(merc, state), _cn(current_target, state)])
											used_perk_effect = true
										"disarm":
											current_target.weapon_drawn = false
											if current_target.equipped_weapon != null:
												current_target.inventory.append({"type": "weapon", "data": current_target.equipped_weapon})
											lines.append("  %s disarms %s!" % [_cn(merc, state), _cn(current_target, state)])
											used_perk_effect = true
										"trip_deposed":
											ConstStates.apply_state(current_target, ConstStates.DEPOSED)
											lines.append("  %s trips %s!" % [_cn(merc, state), _cn(current_target, state)])
											used_perk_effect = true
										"direct_1_strike_slowed_until_turn_end":
											lines.append_array(_apply_damage(merc, current_target, 1, "Strike", state))
											ConstStates.apply_state(current_target, ConstStates.SLOWED)
											lines.append("  %s is slowed until end of turn!" % _cn(current_target, state))
											used_perk_effect = true
							elif verb == "spend_3_successes":
								# parts[3] = effect token
								if parts.size() < 4:
									continue
								var effect: String = parts[3]
								if effect == "direct_1_each_in_reach":
									var weapon_range := 1
									if merc.equipped_weapon != null:
										weapon_range = merc.equipped_weapon.melee_range
									for enemy: MercenaryData in state.get_enemies(merc):
										if enemy == current_target:
											continue
										if state.distance_to(merc, enemy) <= weapon_range:
											lines.append_array(_apply_damage(merc, enemy, 1, atk["damage_type"], state))
									used_perk_effect = true
							if used_perk_effect:
								break
						if not used_perk_effect:
							lines.append_array(_apply_damage(merc, current_target, final_damage, atk["damage_type"], state, enhancements))
						if final_damage > 0 and BattleState._is_alive(current_target):
							lines.append_array(_fire_weapon_reactive(merc, "on_damage", current_target, atk, state, enhancements))
							if final_damage >= 2:
								lines.append_array(_fire_weapon_reactive(merc, "on_damage_2_plus", current_target, atk, state, enhancements))
						# spend:rep:1:reload_free (Blowgun Quick Reload) -- after hit
						for _rr_perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
							if _rr_perk.effect_dsl == "spend:rep:1:reload_free":
								if merc.current_rep >= 1 and merc.equipped_weapon != null:
									var _rr_w := merc.equipped_weapon
									if _rr_w.is_ranged and merc.ammo_loaded < _rr_w.chamber:
										merc.current_rep -= 1
										var _rr_ammo := merc.ammo_loaded_type
										var _rr_avail: int = merc.ammo_inventory.get(_rr_ammo, 0)
										var _rr_load := mini(_rr_w.chamber - merc.ammo_loaded, _rr_avail)
										if _rr_load > 0:
											merc.ammo_loaded += _rr_load
											merc.ammo_inventory[_rr_ammo] -= _rr_load
											var _rr_remaining: int = merc.ammo_inventory.get(_rr_ammo, 0)
											lines.append("  %s reloads for free (1 ReP)! [%dc+%dr]" % [_cn(merc, state), merc.ammo_loaded, _rr_remaining])
								break
						# spend:rep:3:after_attack:ally_move_pace:2:no_ap_no_advantage (Artillery Support)
						for _as_perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
							if _as_perk.effect_dsl == "spend:rep:3:after_attack:ally_move_pace:2:no_ap_no_advantage":
								if merc.current_rep >= 3 and not state.get_allies(merc).is_empty():
									merc.current_rep -= 3
									lines.append("  %s calls Artillery Support (3 ReP) — up to 2 allies may move toward %s without AP or AoO!" % [
										_cn(merc, state), _cn(current_target, state)])
									# TODO: wire ally movement here once state.move_merc_toward is implemented
								break
						if not BattleState._is_alive(current_target):
							merc.last_seen_position = Vector2i(-1, -1)
							current_target = null
					else:
						lines.append("  %s misses against %s." % [_cn(merc, state), _cn(current_target, state)])
						# spend:rep:1:reload_free (Blowgun Quick Reload) -- also triggers on miss
						for _rr_perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
							if _rr_perk.effect_dsl == "spend:rep:1:reload_free":
								if merc.current_rep >= 1 and merc.equipped_weapon != null:
									var _rr_w := merc.equipped_weapon
									if _rr_w.is_ranged and merc.ammo_loaded < _rr_w.chamber:
										merc.current_rep -= 1
										var _rr_ammo := merc.ammo_loaded_type
										var _rr_avail: int = merc.ammo_inventory.get(_rr_ammo, 0)
										var _rr_load := mini(_rr_w.chamber - merc.ammo_loaded, _rr_avail)
										if _rr_load > 0:
											merc.ammo_loaded += _rr_load
											merc.ammo_inventory[_rr_ammo] -= _rr_load
											var _rr_remaining: int = merc.ammo_inventory.get(_rr_ammo, 0)
											lines.append("  %s reloads for free (1 ReP)! [%dc+%dr]" % [_cn(merc, state), merc.ammo_loaded, _rr_remaining])
								break
						lines.append_array(_fire_weapon_reactive(merc, "on_miss", current_target, atk, state, enhancements))
					lines.append_array(_fire_weapon_reactive(merc, "after_attack", current_target, atk, state, enhancements))
					if _is_throw_action and merc.equipped_weapon != null:
						var _thrown_name: String = merc.equipped_weapon.item_name
						merc.equipped_weapon = null
						merc.weapon_drawn = false
						if EncounterLogger.is_active():
							EncounterLogger.log_verbose("THROW: %s throws %s — weapon leaves hand" % [merc.merc_name, _thrown_name])
						lines.append("  %s throws %s! Weapon leaves their hand." % [_cn(merc, state), _thrown_name])
				"draw":
					var draw_lines := _execute_draw(merc, decision["weapon"], state, enhancements)
					if draw_lines.is_empty():
						break
					lines.append_array(draw_lines)
					weapon_action_taken = true
				"holster":
					var holster_lines := _execute_holster(merc, state)
					if holster_lines.is_empty():
						break
					lines.append_array(holster_lines)
					weapon_action_taken = true
				"drop":
					lines.append_array(_execute_drop(merc, state, decision.get("cause", "")))
					weapon_action_taken = true
				"pickup":
					var pu_lines := _execute_pickup(merc, decision["weapon_entry"], decision["weapon_pos"], state)
					if pu_lines.is_empty():
						break
					lines.append_array(pu_lines)
					weapon_action_taken = true
				"move_to_pickup":
					var mv_lines := _execute_move_to_pos(merc, decision["weapon_pos"], state, enhancements)
					if mv_lines.is_empty():
						movement_blocked = true
					else:
						lines.append_array(mv_lines)
						movement_blocked = false
						weapon_action_taken = true
				_:
					break

		if had_valid_targets:
			state.no_target_turns.erase(merc)
		else:
			state.no_target_turns[merc] = state.no_target_turns.get(merc, 0) + 1

	# Whip Choke: spend:ap:1:direct:1:grappled_target -- spend 1 AP for 1 Direct damage to whip-grappled target
	lines.append_array(_do_whip_choke_ap_spend(merc, state))

	state.end_of_turn(merc, weapon_action_taken)
	if merc.excess_ap > 0:
		lines.append("  %s +[color=purple]%d[/color] ExAP" % [_cn(merc, state), merc.excess_ap])
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
		return ConstStates.has_state(merc, ConstStates.DYING) or merc.current_hp < 0

	if ConstStates.has_state(merc, ConstStates.BURNING):
		var hp_before := merc.current_hp
		merc.current_hp = maxi(0, merc.current_hp - 1)
		lines.append("  %s is burning! Takes 1 Fire damage. (HP [color=red]%d->%d[/color])" % [
			_cn(merc, state), hp_before, merc.current_hp])
		_check_dot_death(merc, state, lines)

	if ConstStates.has_state(merc, ConstStates.SUFFOCATING):
		var hp_before := merc.current_hp
		merc.current_hp = maxi(0, merc.current_hp - 1)
		lines.append("  %s is suffocating! Takes 1 damage. (HP [color=red]%d->%d[/color])" % [
			_cn(merc, state), hp_before, merc.current_hp])
		_check_dot_death(merc, state, lines)

	return false


static func _run_death_test(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	var max_hp := int(merc.stats.get("maximum_hit_points", 1))
	var effective_max := max_hp - merc.death_test_hp_loss
	if effective_max <= 0:
		merc.current_hp = -1
		ConstStates.remove_state(merc, ConstStates.DYING)
		lines.append("  %s dies!" % _cn(merc, state))
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("DEATH CONFIRMED: %s — max HP exhausted by death test failures" % merc.merc_name)
		return
	var cheat_death := floorf(float(merc.stats.get("cheat_death", 0.0)))
	var any_success := false
	var new_failures := 0
	var rolls: Array[int] = []
	for _i: int in range(effective_max):
		var roll := randi_range(1, 100)
		rolls.append(roll)
		if float(roll) <= cheat_death:
			any_success = true
		else:
			new_failures += 1
	var successes := effective_max - new_failures
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("CHEAT DEATH ROLL (%s): rolls=%s vs %.0f%% -> %d success %d fail -> %s" % [
			_cn(merc, state), str(rolls), cheat_death,
			successes, new_failures,
			"PASS" if any_success else "FAIL"])
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
			lines.append("  %s dies!" % _cn(merc, state))
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("DEATH CONFIRMED: %s — cheat death failed, max HP exhausted (total failures=%d)" % [
					merc.merc_name, merc.death_test_hp_loss])
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
		if abs(dx) > 1 or abs(dy) > 1:
			continue
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
		enhancements: int,
		target: MercenaryData = null,
		target_obs: Dictionary = {}) -> Array[String]:
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
		"aim":
			var cost := state.get_cost(merc, "Aim", 2)
			state.spend_ap(merc, cost)
			state.record_action(merc, "Aim")
			merc.aim_active = true
			lines.append("  %s aims." % _cn(merc, state))
		"open_door":
			var cost := state.get_cost(merc, "open_door", 2)
			state.spend_ap(merc, cost)
			state.record_action(merc, "open_door")
			_do_open_door(merc, state, lines)
		"shove":
			var cost := state.get_cost(merc, "shove", 3)
			state.spend_ap(merc, cost)
			state.record_action(merc, "shove")
			if target != null:
				lines.append_array(_do_shove(merc, target, state, enhancements))
			elif not target_obs.is_empty():
				_do_shove_obstacle(merc, target_obs, state, lines)
		"attack_obstacle":
			var atk_cost := state.get_cost(merc, "attack_obstacle", ATTACK_BASE_AP)
			state.spend_ap(merc, atk_cost)
			state.record_action(merc, "attack_obstacle")
			lines.append_array(_do_attack_obstacle(merc, state, enhancements))
	return lines


static func _do_seek_cover(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	if state.battlefield == null:
		return
	var merc_pos := state.get_position(merc)
	var pace: int = maxi(1, int(merc.stats.get("pace", 1)))
	var merc_size: int = int(merc.stats.get("size", 1))

	var all_enemies := state.get_enemies(merc)
	var ranged_enemies: Array[MercenaryData] = []
	for e: MercenaryData in all_enemies:
		if e.equipped_weapon != null and e.equipped_weapon.is_ranged:
			ranged_enemies.append(e)

	var nearest_enemy: MercenaryData = null
	var nearest_dist: float = INF
	for e: MercenaryData in ranged_enemies:
		var d := float((state.get_position(e) - merc_pos).length())
		if d < nearest_dist:
			nearest_dist = d
			nearest_enemy = e
	var to_enemy := Vector2.ZERO
	if nearest_enemy != null:
		var ep := state.get_position(nearest_enemy)
		to_enemy = Vector2(float(ep.x - merc_pos.x), float(ep.y - merc_pos.y))

	var _hp_ratio_sc: float = clampf(float(merc.current_hp) / float(maxi(1, int(merc.stats.get("maximum_hit_points", 1)))), 0.1, 1.0)
	var _best_break_fall_sc: float = maxf(
		clampf(float(merc.stats.get("parkour", 0.0)) / 100.0, 0.0, 1.0),
		clampf(float(merc.stats.get("tolerance", 0.0)) / 100.0, 0.0, 1.0))
	var fall_tolerance_sc: float = clampf(_hp_ratio_sc + _best_break_fall_sc, 0.2, 2.0)

	var candidates: Array = []
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]

	for obs: Dictionary in state.battlefield.obstacles:
		if obs.get("cell_type", "") == "door" and obs.get("door_open", false):
			continue
		var obs_data_sc: ObstacleData = obs.get("data") as ObstacleData
		if obs_data_sc != null and not obs_data_sc.provides_cover:
			continue
		var loop_obs_pos: Vector2i = obs["pos"] as Vector2i
		var delta := loop_obs_pos - merc_pos
		var dist: int = maxi(absi(delta.x), absi(delta.y))
		if dist == 0 or dist > pace:
			continue
		if nearest_enemy != null:
			var to_cover := Vector2(float(delta.x), float(delta.y))
			if to_cover.dot(to_enemy) <= 0.0:
				continue
		var is_narrow_sc: bool = obs_data_sc != null and obs_data_sc.narrow
		var obs_size_sc: int = int(obs.get("size", 1))
		var is_full_sc: bool = not is_narrow_sc and obs_size_sc > merc_size
		candidates.append({"obs": obs, "is_full": is_full_sc, "dist": dist})

	# Sort: full cover before partial, then closest
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["is_full"] != b["is_full"]:
			return a["is_full"]
		return a["dist"] < b["dist"])

	if candidates.is_empty():
		lines.append("  %s finds no reachable cover (pace=%d)." % [_cn(merc, state), pace])
		return

	var field: BattlefieldArea = state.battlefield

	for entry: Dictionary in candidates:
		var obs: Dictionary = entry["obs"]
		var obs_pos: Vector2i = obs["pos"] as Vector2i
		var dist: int = entry["dist"]
		var obs_size: int = int(obs["size"])
		var obs_data: ObstacleData = obs.get("data") as ObstacleData
		var is_narrow: bool = obs_data != null and obs_data.narrow
		var cover_type: String = ConstStates.COVERED_PARTIAL if is_narrow \
			else (ConstStates.COVERED_FULL if obs_size > merc_size else ConstStates.COVERED_PARTIAL)
		var obs_name: String = obs_data.obstacle_name if obs_data != null else "obstacle"

		if dist > 1:
			var delta := obs_pos - merc_pos
			var preferred_pos := obs_pos - Vector2i(clampi(delta.x, -1, 1), clampi(delta.y, -1, 1))
			var new_pos := preferred_pos
			if state.is_position_occupied(new_pos, merc):
				new_pos = Vector2i(-1, -1)
				for d: Vector2i in dirs:
					var adj := obs_pos + d
					if adj == obs_pos:
						continue
					if adj.x < 0 or adj.x >= field.width \
							or adj.y < 0 or adj.y >= field.length:
						continue
					if field.is_obstacle(adj):
						continue
					if not state.is_position_occupied(adj, merc):
						new_pos = adj
						break
			if new_pos == Vector2i(-1, -1):
				continue
			var path := Pathfinder.find_path(merc_pos, new_pos, field, {}, fall_tolerance_sc)
			if path.is_empty():
				continue
			var move_cost := state.get_cost(merc, "Move Close", MOVE_BASE_AP)
			state.spend_ap(merc, move_cost)
			state.record_action(merc, "Move Close")
			state.set_position(merc, new_pos)
			merc.aim_active = false
			state.clear_cover(merc)
			var seek_cost := state.get_cost(merc, "seek_cover", 2)
			state.spend_ap(merc, seek_cost)
			state.record_action(merc, "seek_cover")
			state.set_cover(merc, obs_pos, obs_size, cover_type)
			lines.append("  %s moves to cover behind %s. (%s -> %s)" % [
				_cn(merc, state), obs_name,
				"(%d,%d)" % [merc_pos.x, merc_pos.y],
				"(%d,%d)" % [new_pos.x, new_pos.y]])
			return
		else:
			var seek_cost := state.get_cost(merc, "seek_cover", 2)
			state.spend_ap(merc, seek_cost)
			state.record_action(merc, "seek_cover")
			state.set_cover(merc, obs_pos, obs_size, cover_type)
			lines.append("  %s takes cover behind %s." % [_cn(merc, state), obs_name])
			return

	lines.append("  %s finds no free adjacent cover cell (all occupied)." % _cn(merc, state))


static func _do_open_door(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	if state.battlefield == null:
		return
	var merc_pos := state.get_position(merc)
	for obs: Dictionary in state.battlefield.get_adjacent_obstacles(merc_pos):
		if obs.get("cell_type", "") == "door" and not obs.get("door_open", false):
			obs["door_open"] = true
			lines.append("  %s opens the Door." % _cn(merc, state))
			return
	lines.append("  %s finds no adjacent closed door!" % _cn(merc, state))


static func _do_attack_obstacle(merc: MercenaryData, state: BattleState, enhancements: int) -> Array[String]:
	var lines: Array[String] = []
	if state.battlefield == null:
		return lines
	var pos := state.get_position(merc)
	var target_obs: Dictionary = {}
	for obs: Dictionary in state.battlefield.get_adjacent_obstacles(pos):
		var ct: String = obs.get("cell_type", "")
		if ct == "wall":
			continue
		var d: ObstacleData = obs.get("data") as ObstacleData
		if d == null or d.passthrough or d.is_stairs:
			continue
		target_obs = obs
		break
	if target_obs.is_empty():
		return lines
	var obs_data: ObstacleData = target_obs.get("data") as ObstacleData
	var obs_name: String = obs_data.obstacle_name if obs_data != null else "obstacle"
	var obs_hp_max: int = _get_obstacle_hp(obs_data)
	if not target_obs.has("current_hp"):
		target_obs["current_hp"] = obs_hp_max
	var atk_result := AttackSystem.execute_attack(merc, enhancements, 0, null)
	var damage: int = atk_result.get("damage", 0)
	if damage <= 0:
		lines.append("  %s strikes %s but deals no damage." % [_cn(merc, state), obs_name])
		return lines
	target_obs["current_hp"] = int(target_obs["current_hp"]) - damage
	var hp_remaining: int = maxi(0, int(target_obs["current_hp"]))
	lines.append("  %s attacks %s! [%d] -> %d/%d" % [
		_cn(merc, state), obs_name, damage, hp_remaining, obs_hp_max])
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("  %s attacks %s! [%d] -> %d/%d" % [
			_cn(merc, state), obs_name, damage, hp_remaining, obs_hp_max])
	if hp_remaining <= 0:
		var obs_pos: Vector2i = target_obs.get("pos", Vector2i.ZERO) as Vector2i
		var obs_cells: Array = target_obs.get("cells", [])
		if obs_data.obstacle_name == "Window":
			var broken: ObstacleData = DataManager.get_obstacle_by_name("Broken Window")
			if broken != null:
				target_obs["data"] = broken
				target_obs["size"] = broken.size
				target_obs.erase("current_hp")
				lines.append("  The Window shatters! Broken glass remains.")
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("  Window at %s broken -> Broken Window" % str(obs_pos))
		else:
			state.battlefield.obstacles.erase(target_obs)
			if obs_cells.is_empty():
				state.battlefield.terrain_heights[obs_pos] = 0.0
			else:
				for cell in obs_cells:
					state.battlefield.terrain_heights[cell as Vector2i] = 0.0
			lines.append("  %s is destroyed!" % obs_name)
			lines.append("  %s collapses — terrain at %s cleared." % [obs_name, str(obs_pos)])
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("  %s is destroyed!" % obs_name)
	return lines


static func _get_obstacle_hp(obs_data: ObstacleData) -> int:
	if obs_data == null:
		return 3
	if obs_data.health > 1:
		return obs_data.health
	if obs_data.obstacle_name == "Window":
		return 1
	if obs_data.is_building or obs_data.obstacle_type == "Structure":
		return 20
	match obs_data.obstacle_type:
		"Vegetation":
			return maxi(2, obs_data.size)
		"Furniture":
			return maxi(2, obs_data.size)
		"Terrain":
			return maxi(4, obs_data.size * 2)
	return maxi(3, obs_data.size)


static func _do_shove(
		shover: MercenaryData,
		shoved: MercenaryData,
		state: BattleState,
		enhancements: int) -> Array[String]:
	var lines: Array[String] = []
	var atk_def := {
		"stat_keys": ["dexterity", "vigor"],
		"formula": "melee_accuracy",
		"circumstances": ["Attack", "Grace", "Athletics", "Power"],
		"enhancements": enhancements,
	}
	var atk_result := CheckSystem.make_check(shover, atk_def)
	var shover_successes: int = atk_result["successes"]
	var shoved_successes := 0
	if _should_accept_shove(shoved, shover, state):
		lines.append("  %s doesn't resist the shove!" % _cn(shoved, state))
	else:
		var def_def := {
			"stat_keys": ["dexterity", "vigor"],
			"formula": "melee_accuracy",
			"circumstances": ["Grace", "Athletics", "Power", "Resist"],
		}
		var def_result := CheckSystem.make_check(shoved, def_def)
		shoved_successes = def_result["successes"]
	lines.append("  %s shoves %s! [Shover: %d | Shoved: %d successes]" % [
		_cn(shover, state), _cn(shoved, state), shover_successes, shoved_successes])
	var shover_size := int(shover.stats.get("size", 1))
	var shoved_size := int(shoved.stats.get("size", 1))
	var shove_dist := maxi(0, (shover_size + shover_successes) - (shoved_size + shoved_successes))
	if shove_dist == 0:
		lines.append("  %s holds their ground!" % _cn(shoved, state))
		return lines
	lines.append_array(_do_forcible_move(shover, shoved, shove_dist, state))
	return lines


static func _do_shove_obstacle(
		shover: MercenaryData,
		obs_dict: Dictionary,
		state: BattleState,
		lines: Array[String]) -> void:
	var obs_data: ObstacleData = obs_dict.get("data") as ObstacleData
	if obs_data == null or not obs_data.moveable:
		lines.append("  %s cannot be moved." % (obs_data.obstacle_name if obs_data != null else "obstacle"))
		return
	# TODO: multi-cell footprint tracking
	var cells_occupied := 1
	var target_number: int = obs_data.size * cells_occupied
	var result := CheckSystem.make_check(shover, {
		"stat_keys": ["vigor", "raw_power"],
		"formula": "melee_accuracy",
		"circumstances": ["Attack", "Power"],
	})
	lines.append("  %s shoves %s! [%d successes, need >%d]" % [
		_cn(shover, state), obs_data.obstacle_name, result["successes"], target_number])
	if result["successes"] <= target_number:
		lines.append("  Shove failed — insufficient successes.")
		return
	var shove_distance: int = result["successes"] - target_number
	var obs_pos := obs_dict["pos"] as Vector2i
	var shover_pos := state.get_position(shover)
	var raw_dx := obs_pos.x - shover_pos.x
	var raw_dy := obs_pos.y - shover_pos.y
	var push_dir := Vector2i(signi(raw_dx), signi(raw_dy))
	if push_dir == Vector2i.ZERO:
		push_dir = Vector2i(1, 0)
	var current := obs_pos
	var moved := 0
	for _i: int in shove_distance:
		var next := state.battlefield.clamp_position(current + push_dir)
		if next == current:
			break
		var blocking_obs: Dictionary = state.battlefield.get_obstacle_at(next)
		if not blocking_obs.is_empty():
			var bd: ObstacleData = blocking_obs.get("data") as ObstacleData
			if bd == null or not bd.passthrough:
				break
		var occupant_found := false
		for m: MercenaryData in state.positions.keys():
			if state.get_position(m) == next:
				occupant_found = true
				break
		if occupant_found:
			break
		current = next
		moved += 1
	if moved == 0:
		lines.append("  %s cannot be moved!" % obs_data.obstacle_name)
		return
	obs_dict["pos"] = current
	lines.append("  %s shoved %d Pace%s!  ([color=orange]%d,%d -> %d,%d[/color])" % [
		obs_data.obstacle_name, moved, "s" if moved != 1 else "",
		obs_pos.x, obs_pos.y, current.x, current.y])


static func _do_forcible_move(
		shover: MercenaryData,
		shoved: MercenaryData,
		paces: int,
		state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	if ConstStates.has_state(shoved, ConstStates.CLIMBING):
		lines.append("  %s is knocked off the wall!" % _cn(shoved, state))
		lines.append_array(_fall_from_wall(shoved, state))
		return lines
	if state.battlefield == null:
		lines.append("  %s is forcibly moved %d Pace%s." % [
			_cn(shoved, state), paces, "s" if paces != 1 else ""])
		return lines
	var old_pos := state.get_position(shoved)
	var shover_pos := state.get_position(shover)
	var dx := old_pos.x - shover_pos.x
	var dy := old_pos.y - shover_pos.y
	var dir := Vector2i(signi(dx), signi(dy))
	if dir == Vector2i.ZERO:
		dir = Vector2i(1, 0)
	var current := old_pos
	var paces_moved := 0
	for _i: int in paces:
		var next := state.battlefield.clamp_position(current + dir)
		if next == current:
			break
		var obs: Dictionary = state.battlefield.get_obstacle_at(next)
		if not obs.is_empty():
			var d: ObstacleData = obs.get("data") as ObstacleData
			if d == null or not d.passthrough:
				break
		var occupant_found := false
		for m: MercenaryData in state.positions.keys():
			if m != shoved and state.get_position(m) == next:
				occupant_found = true
				break
		if occupant_found:
			break
		current = next
		paces_moved += 1
	var paces_failed := paces - paces_moved
	if paces_failed > 0:
		lines.append("  %s slams into an obstacle and takes %d Strike!" % [
			_cn(shoved, state), paces_failed])
		lines.append_array(_apply_damage(shover, shoved, paces_failed, "Strike", state))
	if paces_moved > 0:
		state.set_position(shoved, current)
		shoved.aim_active = false
		state.clear_cover(shoved)
		var terrain_drop := state.battlefield.get_terrain_height(old_pos) - state.battlefield.get_terrain_height(current)
		if terrain_drop >= 1.0:
			lines.append_array(_resolve_fall(shoved, int(floor(terrain_drop)), state))
		lines.append("  %s is pushed %d Pace%s!  ([color=orange]%d,%d -> %d,%d[/color])" % [
			_cn(shoved, state), paces_moved, "s" if paces_moved != 1 else "",
			old_pos.x, old_pos.y, current.x, current.y])
	else:
		lines.append("  %s cannot be moved!" % _cn(shoved, state))
	if paces_moved >= int(shoved.stats.get("size", 1)):
		if not ConstStates.has_state(shoved, ConstStates.DEPOSED):
			ConstStates.apply_state(shoved, ConstStates.DEPOSED)
			lines.append("  %s is knocked down and [b]Deposed[/b]!" % _cn(shoved, state))
	return lines


static func _should_accept_shove(
		shoved: MercenaryData,
		shover: MercenaryData,
		state: BattleState) -> bool:
	if state.battlefield == null:
		return ConstStates.has_state(shoved, ConstStates.FLANKED)

	var shover_size := int(shover.stats.get("size", 1))
	var shoved_size := int(shoved.stats.get("size", 1))

	# Resistance is futile if size gap is large enough that no contest roll helps
	if shover_size - shoved_size >= 4:
		return true

	# Simulate push path to evaluate destination
	var shoved_pos := state.get_position(shoved)
	var shover_pos := state.get_position(shover)
	var dx := shoved_pos.x - shover_pos.x
	var dy := shoved_pos.y - shover_pos.y
	var dir := Vector2i(signi(dx), signi(dy))
	if dir == Vector2i.ZERO:
		dir = Vector2i(1, 0)
	var current := shoved_pos
	var paces_moved := 0
	var slammed := false
	for _i: int in shover_size:
		var next := state.battlefield.clamp_position(current + dir)
		if next == current:
			slammed = true
			break
		var obs := state.battlefield.get_obstacle_at(next)
		if not obs.is_empty():
			var d: ObstacleData = obs.get("data") as ObstacleData
			if d == null or not d.passthrough:
				slammed = true
				break
		var blocked := false
		for m: MercenaryData in state.positions.keys():
			if m != shoved and state.get_position(m) == next:
				slammed = true
				blocked = true
				break
		if blocked:
			break
		current = next
		paces_moved += 1
	var dest := current

	# Fall at destination is bad
	var terrain_drop := state.battlefield.get_terrain_height(shoved_pos) - state.battlefield.get_terrain_height(dest)
	if terrain_drop >= 1.0:
		return false

	# Collision damage is bad
	if slammed and (shover_size - paces_moved) >= 1:
		return false

	# Evaluate enemy positions at destination
	var melee_near_dest := 0
	var ranged_total := 0
	for e: MercenaryData in state.get_enemies(shoved):
		var w: WeaponData = e.equipped_weapon
		if w != null and w.is_ranged:
			ranged_total += 1
		var e_pos := state.get_position(e)
		if maxi(abs(e_pos.x - dest.x), abs(e_pos.y - dest.y)) <= 1:
			if w == null or not w.is_ranged:
				melee_near_dest += 1

	# Landing near melee enemies is dangerous
	if melee_near_dest >= 1:
		return false

	# Accept only if ranged enemies are present, no melee near dest, and shove is likely small
	if ranged_total > 0 and melee_near_dest == 0 and shoved_size >= shover_size - 1:
		return true

	return false


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
		# Clear whip-grapple marker when escaping any grapple state
		if state_name == ConstStates.GRAPPLED or state_name == ConstStates.SUFFOCATING:
			merc.active_states.erase("whip_grappled_by")
		lines.append("  %s breaks free!" % _cn(merc, state))
	else:
		lines.append("  %s fails to break free!" % _cn(merc, state))
		# Whip Choke (on_grapple:size_5_or_less:use_whip): deal 1 Direct damage on escape failure
		if merc.active_states.has("whip_grappled_by"):
			var grappler := merc.active_states["whip_grappled_by"] as MercenaryData
			if grappler != null and BattleState._is_alive(grappler):
				lines.append_array(_apply_damage(grappler, merc, 1, "Direct", state))
				lines.append("  Whip choke tightens — %s deals 1 Direct damage!" % _cn(grappler, state))


# Called after a grapple is successfully applied to handle state and whip-grapple marking.
# TODO: call this from wherever grapple initiation is implemented (weapon action, special attack, etc.).
# Currently no code in AutoBattle initiates GRAPPLED state; this is the planned entry point.
static func _apply_grapple(attacker: MercenaryData, target: MercenaryData, state: BattleState, _enhancements: int, lines: Array[String]) -> void:
	ConstStates.apply_state(target, ConstStates.GRAPPLED, attacker)
	lines.append("  %s grapples %s!" % [_cn(attacker, state), _cn(target, state)])
	# Whip Choke perk (on_grapple:size_5_or_less:use_whip:...): mark target for whip-grapple effects
	var target_size := int(target.stats.get("size", 1))
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(attacker):
		if perk.effect_dsl.begins_with("on_grapple:"):
			var parts := perk.effect_dsl.split(":")
			if parts.size() >= 3 and parts[1] == "size_5_or_less" and target_size <= 5:
				target.active_states["whip_grappled_by"] = attacker
				lines.append("  %s grapples with their whip!" % _cn(attacker, state))
				break


# Whip Choke AP-spend (spend:ap:1:direct:1:grappled_target): after the action loop, spend remaining
# AP 1 at a time for 1 Direct damage per point to the whip-grappled target.
static func _do_whip_choke_ap_spend(merc: MercenaryData, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	# Find a living enemy currently whip-grappled by this merc
	var whip_target: MercenaryData = null
	for enemy: MercenaryData in state.get_enemies(merc):
		if enemy.active_states.get("whip_grappled_by") == merc and BattleState._is_alive(enemy):
			whip_target = enemy
			break
	if whip_target == null:
		return lines
	# Verify the merc still has the Whip Choke perk active (weapon with the perk must be equipped)
	var has_whip_choke := false
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
		if perk.effect_dsl.begins_with("on_grapple:"):
			has_whip_choke = true
			break
	if not has_whip_choke:
		return lines
	# Spend 1 AP per hit for as long as AP allows
	while state.can_afford(merc, 1):
		state.spend_ap(merc, 1)
		lines.append_array(_apply_damage(merc, whip_target, 1, "Direct", state))
		lines.append("  %s tightens the whip choke for 1 Direct damage!" % _cn(merc, state))
		if not BattleState._is_alive(whip_target):
			whip_target.active_states.erase("whip_grappled_by")
			break
	return lines


static func _execute_move(
		merc: MercenaryData,
		action_name: String,
		move_target: MercenaryData,
		state: BattleState,
		flank_ally: MercenaryData = null,
		enhancements: int = 0,
		stop_dist_override: int = -1,
		seeking: bool = false,
		valid_targets: Array[MercenaryData] = [],
		enemies: Array[MercenaryData] = []) -> Array[String]:
	if move_target == null:
		return []
	if ConstStates.has_state(merc, ConstStates.CLIMBING):
		return []  # lateral movement blocked while on a wall; use Climb action to progress

	var old_pos := state.get_position(merc)
	var goal := _compute_move_position(merc, move_target, action_name, state, flank_ally, stop_dist_override, valid_targets, enemies)
	var new_pos := goal
	var path_harms: Array[Dictionary] = []
	var body_traverse_lines: Array[String] = []
	var field := state.battlefield
	if field != null:
		var _hp_ratio: float = clampf(float(merc.current_hp) / float(merc.stats.get("maximum_hit_points", 1)), 0.1, 1.0)
		var _best_break_fall: float = maxf(
			clampf(float(merc.stats.get("parkour", 0.0)) / 100.0, 0.0, 1.0),
			clampf(float(merc.stats.get("tolerance", 0.0)) / 100.0, 0.0, 1.0))
		var fall_tolerance: float = clampf(_hp_ratio + _best_break_fall, 0.2, 2.0)
		var can_climb: bool = int(merc.stats.get("size", 0)) > 0
		var jump_stat: int = int(merc.stats.get("jump", 0))
		var _raw_goal := goal
		var _npc_key: Array = [_raw_goal, int(fall_tolerance * 10), int(can_climb)]
		if _near_passable_cache.has(_npc_key):
			goal = _near_passable_cache[_npc_key] as Vector2i
		else:
			goal = _nearest_passable_to(_raw_goal, field, fall_tolerance, can_climb)
			_near_passable_cache[_npc_key] = goal
		if _blocked_path_goals.has(goal):
			if (_blocked_path_goals[goal] as int) >= state.round_number:
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("MOVE BLOCKED: cached unreachable (%d,%d)" % [goal.x, goal.y])
				return []
			else:
				_blocked_path_goals.erase(goal)
		var ally_passable: Dictionary
		if state.turn_ally_passable.has(merc):
			ally_passable = state.turn_ally_passable[merc] as Dictionary
		else:
			ally_passable = {}
			for _ally: MercenaryData in state.get_allies(merc):
				if BattleState._is_alive(_ally) and not ConstStates.has_state(_ally, ConstStates.DEPOSED):
					var _ap: Vector2i = state.positions.get(_ally, Vector2i(-1, -1))
					if _ap != Vector2i(-1, -1):
						ally_passable[_ap] = true
			ally_passable.merge(field.get_nav_passable_cells())
		var path: Array[Vector2i] = []
		var path_start_idx := 0
		if not seeking:
			var _cached_tp = _turn_path_cache.get(merc)
			if _cached_tp != null:
				var _ctp := _cached_tp as Dictionary
				if (_ctp.get("goal") as Vector2i) == goal:
					var _cpath: Array[Vector2i] = _ctp.get("path", []) as Array[Vector2i]
					var _cidx: int = _ctp.get("idx", 0)
					for _cj in range(_cidx, _cpath.size()):
						if _cpath[_cj] == old_pos:
							path = _cpath
							path_start_idx = _cj
							break
		if path.is_empty():
			path = Pathfinder.find_path(old_pos, goal, field, ally_passable, fall_tolerance, false, can_climb)
			if path.is_empty():
				if seeking:
					var seek_path := Pathfinder.find_path_toward(old_pos, goal, field, ally_passable, fall_tolerance, false, can_climb, jump_stat)
					if not seek_path.is_empty():
						path = seek_path
						if EncounterLogger.is_active():
							EncounterLogger.log_verbose("SEEK MOVE: partial path (%d,%d)->(%d,%d) advancing to (%d,%d)" % [
								old_pos.x, old_pos.y, goal.x, goal.y,
								seek_path[-1].x, seek_path[-1].y])
					else:
						new_pos = old_pos
						_blocked_path_goals[goal] = state.round_number
						if EncounterLogger.is_active():
							EncounterLogger.log_verbose("SEEK MOVE BLOCKED: no reachable cell toward (%d,%d)" % [goal.x, goal.y])
				else:
					var toward_path := Pathfinder.find_path_toward(old_pos, goal, field, ally_passable, fall_tolerance, false, can_climb, jump_stat)
					if not toward_path.is_empty():
						path = toward_path
						if EncounterLogger.is_active():
							EncounterLogger.log_verbose("MOVE PARTIAL: no exact path (%d,%d)->(%d,%d), advancing to (%d,%d)" % [
								old_pos.x, old_pos.y, goal.x, goal.y,
								toward_path[-1].x, toward_path[-1].y])
					else:
						var _alt_path: Array[Vector2i] = []
						var _alt_best_dist := 999999
						var _dirs8: Array[Vector2i] = [
							Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
							Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
						for _ad: Vector2i in _dirs8:
							var _ag: Vector2i = _raw_goal + _ad
							if _ag.x < 0 or _ag.x >= field.width or _ag.y < 0 or _ag.y >= field.length:
								continue
							if _blocked_path_goals.has(_ag) and (_blocked_path_goals[_ag] as int) >= state.round_number:
								continue
							var _ap: Array[Vector2i] = Pathfinder.find_path_toward(old_pos, _ag, field, ally_passable, fall_tolerance, false, can_climb, jump_stat)
							if not _ap.is_empty():
								var _ad_dist := maxi(abs(_ap[-1].x - _raw_goal.x), abs(_ap[-1].y - _raw_goal.y))
								if _ad_dist < _alt_best_dist:
									_alt_best_dist = _ad_dist
									_alt_path = _ap
						if not _alt_path.is_empty():
							path = _alt_path
							if EncounterLogger.is_active():
								EncounterLogger.log_verbose("MOVE REROUTED: (%d,%d)->(%d,%d) blocked, advancing via (%d,%d)" % [
									old_pos.x, old_pos.y, goal.x, goal.y, _alt_path[-1].x, _alt_path[-1].y])
						else:
							new_pos = old_pos
							var _static_path := Pathfinder.find_path_toward(
								old_pos, _raw_goal, field, field.get_nav_passable_cells(),
								fall_tolerance, false, can_climb, jump_stat)
							_blocked_path_goals[goal] = state.round_number + (1000 if _static_path.is_empty() else 0)
							if EncounterLogger.is_active():
								EncounterLogger.log_verbose("MOVE BLOCKED: no path (%d,%d)->(%d,%d)" % [
									old_pos.x, old_pos.y, goal.x, goal.y])
			if not path.is_empty() and not seeking:
				_turn_path_cache[merc] = {"goal": goal, "path": path, "idx": 0}
		if not path.is_empty() and path.size() > path_start_idx + 1:
			var pace := maxi(1, int(merc.stats.get("pace", 1)))
			if ConstStates.has_state(merc, ConstStates.DEPOSED):
				pace = mini(pace, 1)
			var budget := pace
			var last := old_pos
			var traversed: Array[Vector2i] = [old_pos]
			var merc_size := int(merc.stats.get("size", 1))
			for i: int in range(path_start_idx + 1, path.size()):
				var from_cell: Vector2i = path[i - 1]
				var cell: Vector2i = path[i]
				var cost := Pathfinder.cell_pace_cost(from_cell, cell, field, {}, fall_tolerance, false, can_climb)
				if cost < 0:
					break
				# Backward step (away from goal) costs 1 extra pace to discourage dead-end detours.
				var _cell_d := maxi(abs(cell.x - goal.x), abs(cell.y - goal.y))
				var _from_d := maxi(abs(from_cell.x - goal.x), abs(from_cell.y - goal.y))
				if _cell_d > _from_d:
					cost += 1
				var dead_body := _get_dead_body_at(from_cell, state)
				if dead_body != null and int(dead_body.stats.get("size", 1)) >= merc_size:
					cost += 1
				var deposed_merc := _get_deposed_merc_at(from_cell, state)
				if deposed_merc != null and int(deposed_merc.stats.get("size", 1)) >= merc_size:
					cost += 1
				if budget - cost < 0:
					break
				budget -= cost
				if dead_body != null and int(dead_body.stats.get("size", 1)) >= merc_size:
					body_traverse_lines.append("  %s moves through the body of %s." % [_cn(merc, state), dead_body.merc_name])
				if deposed_merc != null:
					body_traverse_lines.append("  %s steps over the prone %s." % [_cn(merc, state), deposed_merc.merc_name])
				var traversed_ally := _get_standing_ally_at(from_cell, merc, state)
				if traversed_ally != null:
					body_traverse_lines.append("  %s passes through %s's position." % [_cn(merc, state), traversed_ally.merc_name])
				last = cell
				traversed.append(cell)
				var path_obs: Dictionary = field.get_obstacle_at(cell)
				if not path_obs.is_empty():
					var d: ObstacleData = path_obs.get("data") as ObstacleData
					if d != null and d.passthrough and d.passthrough_enter_harm > 0:
						path_harms.append({"damage": d.passthrough_enter_harm, "type": d.passthrough_harm_type, "name": d.obstacle_name})
			for k: int in range(traversed.size() - 1, 0, -1):
				if not state.is_position_occupied(traversed[k], merc):
					last = traversed[k]
					break
			new_pos = last
			if _turn_path_cache.has(merc):
				var _cti: int = path_start_idx
				for _ctj in range(path_start_idx, path.size()):
					if path[_ctj] == new_pos:
						_cti = _ctj
						break
				(_turn_path_cache[merc] as Dictionary)["idx"] = _cti
			if EncounterLogger.is_active() and traversed.size() > 1:
				var parts: Array[String] = []
				for c: Vector2i in traversed:
					parts.append("(%d,%d)" % [c.x, c.y])
				EncounterLogger.log_verbose("MOVE PATH: %s  budget %d/%d used" % [
					" -> ".join(parts), pace - budget, pace])

	if new_pos == old_pos:
		return []

	# Anti-oscillation: block moves to cells the merc ended recent turns at.
	# Seeking moves are exempt so a truly stuck merc can still inch forward.
	if not seeking:
		var _hist: Array = state.position_history.get(merc, []) as Array
		if _hist.has(new_pos):
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("OSCILLATION BLOCKED: %s would return to recently visited (%d,%d)" % [
					merc.merc_name, new_pos.x, new_pos.y])
			# Try flanking: offset goal 90° left then right and re-path
			var _flank_ok := false
			if field != null:
				var _delta := Vector2i(goal.x - old_pos.x, goal.y - old_pos.y)
				var _len_f := maxf(1.0, Vector2(float(_delta.x), float(_delta.y)).length())
				var _perp := Vector2i(roundi(-float(_delta.y) / _len_f * 4.0), roundi(float(_delta.x) / _len_f * 4.0))
				var _ally_pass: Dictionary = state.turn_ally_passable.get(merc, {}) as Dictionary
				var _fall_tol: float = clampf(float(merc.current_hp) / float(maxi(1, int(merc.stats.get("maximum_hit_points", 1)))) + maxf(
					clampf(float(merc.stats.get("parkour", 0.0)) / 100.0, 0.0, 1.0),
					clampf(float(merc.stats.get("tolerance", 0.0)) / 100.0, 0.0, 1.0)), 0.2, 2.0)
				var _can_cl: bool = int(merc.stats.get("size", 0)) > 0
				var _jmp: int = int(merc.stats.get("jump", 0))
				_last_move_heavy = true
				for _side: int in [1, -1]:
					var _fg := field.clamp_position(goal + _perp * _side)
					var _fp := Pathfinder.find_path_toward(old_pos, _fg, field, _ally_pass, _fall_tol, false, _can_cl, _jmp)
					if _fp.is_empty():
						continue
					var _fb := maxi(1, int(merc.stats.get("pace", 1)))
					if ConstStates.has_state(merc, ConstStates.DEPOSED):
						_fb = mini(_fb, 1)
					var _fn := old_pos
					var _ft: Array[Vector2i] = [old_pos]
					for _fi: int in range(1, _fp.size()):
						var _fc := Pathfinder.cell_pace_cost(_fp[_fi - 1], _fp[_fi], field, {}, _fall_tol, false, _can_cl)
						if _fc < 0 or _fb - _fc < 0:
							break
						_fb -= _fc
						_ft.append(_fp[_fi])
						_fn = _fp[_fi]
					if _fn == old_pos or _hist.has(_fn):
						continue
					new_pos = _fn
					body_traverse_lines.clear()
					_flank_ok = true
					if EncounterLogger.is_active():
						EncounterLogger.log_verbose("OSCILLATION FLANK: %s flanking to (%d,%d)" % [merc.merc_name, new_pos.x, new_pos.y])
					break
			if not _flank_ok:
				_blocked_path_goals[goal] = state.round_number
				return []

	var move_cost := state.get_cost(merc, action_name, MOVE_BASE_AP)
	state.spend_ap(merc, move_cost)
	state.record_action(merc, action_name)

	var move_lines: Array[String] = []

	var triggered: Array = ReactiveActionSystem.get_triggered_reactions(
		"enemy_leaves_melee_range", merc, old_pos, new_pos, state)
	for entry in triggered:
		var reactor: MercenaryData = entry["reactor"]
		var def = entry["reaction"]
		reactor.current_ep -= def.ep_cost
		state.last_attacked[reactor] = merc
		if reactor.equipped_weapon != null and reactor.equipped_weapon.is_ranged:
			state.record_ranged_targeted(merc)
		var atk_flaws := _compute_attack_flaws(reactor, merc, state)
		var weapon_enh := _get_weapon_enhance_bonus(reactor)
		var atk := AttackSystem.execute_attack(reactor, enhancements + weapon_enh, atk_flaws, merc)
		move_lines.append("  %s takes an Advantage Attack against %s!" % [_cn(reactor, state), _cn(merc, state)])
		if atk.get("misfired", false):
			move_lines.append("  %s misfires!" % _cn(reactor, state))
		elif atk.get("no_ammo", false):
			move_lines.append("  %s has no ammo!" % _cn(reactor, state))
			reactor.current_ep += def.ep_cost
		elif atk["damage"] > 0:
			move_lines.append_array(_apply_damage(reactor, merc, atk["damage"], atk["damage_type"], state, enhancements))
		else:
			move_lines.append("  %s misses %s with the Advantage Attack." % [_cn(reactor, state), _cn(merc, state)])

	var old_terrain_pos := old_pos
	state.escalation[merc]["last_move_from"] = old_pos
	state.set_position(merc, new_pos)
	merc.aim_active = false
	state.clear_cover(merc)

	var _goal_after_move: Vector2i = state.move_goals.get(merc, Vector2i(-1, -1)) as Vector2i
	if _goal_after_move != Vector2i(-1, -1) and new_pos == _goal_after_move:
		state.move_goals.erase(merc)

	# Sync battle height to terrain elevation
	if field != null:
		var old_h := state.get_height(merc)
		var new_h := int(round(field.get_terrain_height(new_pos)))
		state.set_height(merc, new_h)
		if new_h != old_h and EncounterLogger.is_active():
			EncounterLogger.log_verbose("HEIGHT SYNC: %s terrain elevation h%d -> h%d at (%d,%d)" % [
				merc.merc_name, old_h, new_h, new_pos.x, new_pos.y])

	# Fall detection for terrain drop-offs (normally blocked by pathfinder, edge-case guard)
	if field != null:
		var terrain_drop := field.get_terrain_height(old_terrain_pos) - field.get_terrain_height(new_pos)
		if terrain_drop >= 1.0:
			move_lines.append_array(_resolve_fall(merc, int(floor(terrain_drop)), state))

	move_lines.append_array(body_traverse_lines)
	for harm: Dictionary in path_harms:
		move_lines.append("  %s moves through %s." % [_cn(merc, state), harm["name"]])
		move_lines.append_array(_apply_damage(merc, merc, harm["damage"], harm["type"], state))

	var arrow := "<-" if action_name == "Move Far" else "->"
	move_lines.append("  %s %s %s ([color=orange]%d,%d -> %d,%d[/color])" % [
		_cn(merc, state), arrow, _cn(move_target, state),
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


static func _execute_jump(
		merc: MercenaryData,
		jump_target_pos: Vector2i,
		action_name: String,
		state: BattleState,
		enhancements: int = 0) -> Array[String]:
	if jump_target_pos == Vector2i(-1, -1):
		return []
	if ConstStates.has_state(merc, ConstStates.CLIMBING):
		return []  # can't jump while climbing
	if state.is_position_occupied(jump_target_pos, merc):
		return []

	var lines: Array[String] = []
	var old_pos := state.get_position(merc)
	var field := state.battlefield

	var triggered: Array = ReactiveActionSystem.get_triggered_reactions(
		"enemy_leaves_melee_range", merc, old_pos, jump_target_pos, state)
	for entry: Dictionary in triggered:
		var reactor: MercenaryData = entry["reactor"]
		var def: ActionData = entry["reaction"]
		reactor.current_ep -= def.ep_cost
		state.last_attacked[reactor] = merc
		if reactor.equipped_weapon != null and reactor.equipped_weapon.is_ranged:
			state.record_ranged_targeted(merc)
		var atk_flaws := _compute_attack_flaws(reactor, merc, state)
		var weapon_enh := _get_weapon_enhance_bonus(reactor)
		var atk := AttackSystem.execute_attack(reactor, enhancements + weapon_enh, atk_flaws, merc)
		lines.append("  %s takes an Advantage Attack against %s!" % [_cn(reactor, state), _cn(merc, state)])
		if atk.get("misfired", false):
			lines.append("  %s misfires!" % _cn(reactor, state))
		elif atk.get("no_ammo", false):
			lines.append("  %s has no ammo!" % _cn(reactor, state))
			reactor.current_ep += def.ep_cost
		elif atk["damage"] > 0:
			lines.append_array(_apply_damage(reactor, merc, atk["damage"], atk["damage_type"], state, enhancements))
		else:
			lines.append("  %s misses %s with the Advantage Attack." % [_cn(reactor, state), _cn(merc, state)])

	state.spend_ap(merc, state.get_cost(merc, action_name, MOVE_BASE_AP))
	state.record_action(merc, action_name)
	state.set_position(merc, jump_target_pos)
	merc.aim_active = false
	state.clear_cover(merc)

	if field != null:
		var new_h := int(round(field.get_terrain_height(jump_target_pos)))
		state.set_height(merc, new_h)
		var terrain_drop := field.get_terrain_height(old_pos) - field.get_terrain_height(jump_target_pos)
		if terrain_drop >= 1.0:
			lines.append_array(_resolve_fall(merc, int(floor(terrain_drop)), state))

	lines.append("  %s leaps! ([color=orange]%d,%d -> %d,%d[/color])" % [
		_cn(merc, state), old_pos.x, old_pos.y, jump_target_pos.x, jump_target_pos.y])

	return lines


static func _resolve_fall(merc: MercenaryData, fall_distance: int, state: BattleState) -> Array[String]:
	if fall_distance <= 0:
		return []
	var lines: Array[String] = []
	lines.append("  %s falls %d Pace%s!" % [_cn(merc, state), fall_distance, "s" if fall_distance != 1 else ""])
	var damage := fall_distance
	var break_fall_attempted := false
	if merc.action_set != null:
		for action: ActionData in merc.action_set.actions:
			if action.is_reactive and action.trigger == "merc_falls":
				if merc.current_ep >= action.ep_cost:
					var ctx := {
						"state": state,
						"fall_distance": fall_distance,
						"allies": state.get_allies(merc),
						"enemies": state.get_enemies(merc),
						"valid_targets": [],
						"current_target": null,
						"attack_base_ap": ATTACK_BASE_AP,
						"move_base_ap": MOVE_BASE_AP,
					}
					if action.decision.evaluate(merc, ctx) >= action.decision.threshold:
						merc.current_ep -= action.ep_cost
						damage = _do_break_fall(merc, fall_distance, state, lines)
						break_fall_attempted = true
				break
	if damage > 0:
		if EncounterLogger.is_active() and not break_fall_attempted:
			EncounterLogger.log_verbose("Fall damage: %d raw (no break fall attempt)" % fall_distance)
		lines.append_array(_apply_damage(merc, merc, damage, "Fall", state))
		var size := int(merc.stats.get("size", 1))
		if EncounterLogger.is_active():
			if damage >= size:
				EncounterLogger.log_verbose("Deposed check: final_damage (%d) >= size (%d) -> Deposed" % [damage, size])
			else:
				EncounterLogger.log_verbose("Deposed check: final_damage (%d) < size (%d) -> no Deposed" % [damage, size])
		if damage >= size:
			if not ConstStates.has_state(merc, ConstStates.DEPOSED):
				ConstStates.apply_state(merc, ConstStates.DEPOSED)
				lines.append("  %s lands hard and is [b]Deposed[/b]!" % _cn(merc, state))
	return lines


static func _do_break_fall(merc: MercenaryData, fall_distance: int, state: BattleState, lines: Array[String]) -> int:
	if int(merc.stats.get("fly", 0)) > 0 and not ConstStates.has_state(merc, ConstStates.GROUNDED):
		lines.append("  %s uses their flight to land safely!" % _cn(merc, state))
		return 0
	var dex_def := {
		"stat_keys": ["dexterity"],
		"circumstances": ["Resist (Dexterity)", "Grace (Dexterity)"],
		"knowledges": ["Urban", "Colosseum"],
		"formula": "parkour",
	}
	var vig_def := {
		"stat_keys": ["vigor"],
		"circumstances": ["Athletics (Vigor)"],
		"knowledges": ["Urban", "Colosseum"],
		"formula": "tolerance",
	}
	var chosen_def: Dictionary = dex_def if _break_fall_expected(merc, dex_def) >= _break_fall_expected(merc, vig_def) else vig_def
	var result := CheckSystem.make_check(merc, chosen_def)
	var successes: int = result["successes"]
	var formula_label := "Parkour" if str(chosen_def["formula"]) == "parkour" else "Tolerance"
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("BREAK FALL (%s): rolls=%s vs %.0f%% -> %d success %d fail" % [
			_cn(merc, state), str(result["roll2"]), result["threshold"],
			successes, result["failures"]])
	lines.append("  %s Break Fall [%s: %d]" % [_cn(merc, state), formula_label, successes])
	var final_damage := maxi(0, fall_distance - successes)
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("Fall damage: %d raw - %d reduced = %d final" % [
			fall_distance, mini(successes, fall_distance), final_damage])
	return final_damage


static func _break_fall_expected(merc: MercenaryData, def: Dictionary) -> float:
	var stat_key := str((def["stat_keys"] as Array)[0])
	var formula_key := str(def.get("formula", ""))
	var bsc := clampf(float(merc.stats.get("base_success_chance", 0.0)), 0.0, 100.0)
	var formula_val := clampf(float(merc.stats.get(formula_key, 0.0)), 0.0, 100.0)
	var circ_bonus := 0.0
	for circ: String in def.get("circumstances", []):
		if circ.ends_with("(" + stat_key.capitalize() + ")") and merc.circumstance_flags.get(circ, false):
			circ_bonus = 15.0 + merc.circumstance_additional_bonus.get(circ, 0.0)
			break
	var k_bonus := 0
	for kname: String in def.get("knowledges", []):
		for k: UtilityTraitData in merc.knowledges:
			if k.utility_name == kname:
				k_bonus = 1
				break
		if k_bonus > 0:
			break
	var threshold := clampf(formula_val + circ_bonus + bsc, 0.01, 100.0)
	var p_reroll := clampf(float(merc.stats.get("reroll", 0.0)) / 100.0, 0.0, 1.0)
	var p_base := threshold / 100.0
	var p_eff := p_base + (1.0 - p_base) * p_reroll * p_base
	return (maxi(1, int(merc.stats.get(stat_key, 0))) + k_bonus) * p_eff


static func _fall_from_wall(merc: MercenaryData, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	var cd: Dictionary = state.get_climbing_data(merc)
	var fall_h := int(cd.get("current_h", 0))
	state.clear_climbing(merc)
	ConstStates.remove_state(merc, ConstStates.CLIMBING)
	var ground_h := int(round(state.battlefield.get_terrain_height(state.get_position(merc)))) if state.battlefield != null else 0
	state.set_height(merc, ground_h)
	if fall_h > 0:
		lines.append_array(_resolve_fall(merc, fall_h, state))
	return lines


static func _execute_climb(
		merc: MercenaryData,
		decision: Dictionary,
		action_name: String,
		state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	var field := state.battlefield
	var is_continuing: bool = ConstStates.has_state(merc, ConstStates.CLIMBING)

	if not is_continuing:
		# --- Initiation ---
		var target_pos: Vector2i = decision.get("climb_target_pos", Vector2i(-1, -1))
		if target_pos == Vector2i(-1, -1) or field == null:
			return []
		var merc_size := int(merc.stats.get("size", 0))
		if merc_size <= 0:
			return []
		var init_target_h := int(round(field.get_terrain_height(target_pos)))
		var grab_h := merc_size
		state.set_climbing_data(merc, {
			"wall_pos": target_pos,
			"current_h": grab_h,
			"target_h": init_target_h,
			"top_pos": target_pos,
		})
		ConstStates.apply_state(merc, ConstStates.CLIMBING)
		state.set_height(merc, grab_h)
		state.spend_ap(merc, state.get_cost(merc, action_name, MOVE_BASE_AP))
		state.record_action(merc, action_name)
		merc.aim_active = false
		state.clear_cover(merc)
		lines.append("  %s grabs the wall and begins climbing! (h%d/%d)" % [
			_cn(merc, state), grab_h, init_target_h])
		if grab_h >= init_target_h:
			_complete_climb(merc, state, lines)
		return lines

	# --- Progression ---
	var cd: Dictionary = state.get_climbing_data(merc)
	var current_h := int(cd.get("current_h", 0))
	var target_h := int(cd.get("target_h", 0))

	var has_climb_stat := int(merc.stats.get("climb", 0)) > 0
	var has_athletics: bool = merc.circumstance_flags.get(ConstCircumstances.ATHLETICS_VIGOR, false)
	var pace := maxi(1, int(merc.stats.get("pace", 1)))
	var climb_budget: int
	if has_climb_stat:
		climb_budget = pace
	elif has_athletics:
		climb_budget = 2
	else:
		climb_budget = 1
	if ConstStates.has_state(merc, ConstStates.DEPOSED):
		climb_budget = mini(climb_budget, 1)

	var new_h := mini(current_h + climb_budget, target_h)
	cd["current_h"] = new_h
	state.set_climbing_data(merc, cd)
	state.set_height(merc, new_h)

	state.spend_ap(merc, state.get_cost(merc, action_name, MOVE_BASE_AP))
	state.record_action(merc, action_name)
	merc.aim_active = false
	state.clear_cover(merc)

	if new_h >= target_h:
		_complete_climb(merc, state, lines)
	else:
		lines.append("  %s climbs to height %d/%d." % [_cn(merc, state), new_h, target_h])
	return lines


static func _complete_climb(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	var cd: Dictionary = state.get_climbing_data(merc)
	var top_pos: Vector2i = cd.get("top_pos", state.get_position(merc)) as Vector2i
	state.clear_climbing(merc)
	ConstStates.remove_state(merc, ConstStates.CLIMBING)
	if not state.is_position_occupied(top_pos, merc):
		state.set_position(merc, top_pos)
	if state.battlefield != null:
		state.set_height(merc, int(round(state.battlefield.get_terrain_height(top_pos))))
	lines.append("  %s hauls themselves up!" % _cn(merc, state))


static func _compute_move_position(
		merc: MercenaryData,
		move_target: MercenaryData,
		action_name: String,
		state: BattleState,
		flank_ally: MercenaryData = null,
		stop_dist_override: int = -1,
		valid_targets: Array[MercenaryData] = [],
		enemies: Array[MercenaryData] = []) -> Vector2i:
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
		if field == null:
			return from

		var _pre_goal: Vector2i = state.move_goals.get(merc, Vector2i(-1, -1)) as Vector2i
		if _pre_goal != Vector2i(-1, -1):
			if state.is_position_occupied(_pre_goal, merc) or field.is_obstacle(_pre_goal):
				state.move_goals.erase(merc)

		var all_enemies_mf := state.get_enemies(merc)
		var allies_mf := state.get_allies(merc)
		var max_ally_dist: int = 20  # SAFE_DISTANCE * 2; keep in sync with CombatDecision.SAFE_DISTANCE

		var retreat_dirs: Array[Vector2i] = [
			Vector2i(-step.x, -step.y),
			Vector2i(-step.x, 0), Vector2i(0, -step.y),
			Vector2i(-step.x, step.y), Vector2i(step.x, -step.y),
			Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
			Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1),
		]
		var candidates: Array[Vector2i] = []
		for rd: Vector2i in retreat_dirs:
			if rd == Vector2i.ZERO:
				continue
			candidates.append(field.clamp_position(from + rd * pace))
			if pace > 1:
				candidates.append(field.clamp_position(from + rd * (pace >> 1)))

		var _seen_mf: Dictionary = {}
		var unique_candidates: Array[Vector2i] = []
		for c: Vector2i in candidates:
			if c == from or _seen_mf.has(c):
				continue
			_seen_mf[c] = true
			unique_candidates.append(c)

		var _scored_mf: Array[Dictionary] = []
		for candidate: Vector2i in unique_candidates:
			if not allies_mf.is_empty():
				var closest_ally_d := 999999
				for ally: MercenaryData in allies_mf:
					var ally_pos := state.get_position(ally)
					var d := maxi(abs(candidate.x - ally_pos.x), abs(candidate.y - ally_pos.y))
					if d < closest_ally_d:
						closest_ally_d = d
				if closest_ally_d > max_ally_dist:
					continue

			var nearest_enemy_dist: float = INF
			for e: MercenaryData in all_enemies_mf:
				var ep := state.get_position(e)
				var d: float = float(maxi(absi(candidate.x - ep.x), absi(candidate.y - ep.y)))
				if d < nearest_enemy_dist:
					nearest_enemy_dist = d

			var cover_count: float = 0.0
			for obs: Dictionary in field.obstacles:
				if obs.get("cell_type", "") == "door" and obs.get("door_open", false):
					continue
				var obs_data_mf: ObstacleData = obs.get("data") as ObstacleData
				if obs_data_mf != null and not obs_data_mf.provides_cover:
					continue
				var op: Vector2i = obs["pos"] as Vector2i
				if maxi(absi(op.x - candidate.x), absi(op.y - candidate.y)) <= 2:
					cover_count += 1.0

			var edge_penalty: float = 0.0
			if candidate.x < 3 or candidate.x >= field.width - 3 \
					or candidate.y < 3 or candidate.y >= field.length - 3:
				edge_penalty = 2.0

			var los_bonus := 0.0
			if valid_targets.is_empty() and merc.equipped_weapon != null and merc.equipped_weapon.is_ranged:
				for enemy_mf: MercenaryData in enemies:
					if not state.is_covered_from_pos(enemy_mf, candidate):
						los_bonus = 1.5
						break

			var height_bonus := 0.0
			var merc_h := field.get_terrain_height(from)
			var candidate_h := field.get_terrain_height(candidate)
			height_bonus = clampf(float(candidate_h - merc_h) * 0.5, 0.0, 1.0)

			var last_from_penalty := 0.0
			var _esc_mf: Dictionary = state.escalation.get(merc, {}) as Dictionary
			var _last_from: Vector2i = _esc_mf.get("last_move_from", Vector2i(-1, -1)) as Vector2i
			if _last_from != Vector2i(-1, -1) and candidate == _last_from:
				last_from_penalty = 2.0

			var goal_bonus := 0.0
			var _stored_goal: Vector2i = state.move_goals.get(merc, Vector2i(-1, -1)) as Vector2i
			if _stored_goal != Vector2i(-1, -1) and candidate == _stored_goal:
				goal_bonus = 1.5

			var score: float = nearest_enemy_dist * 1.0 + cover_count * 1.5 - edge_penalty + los_bonus + height_bonus - last_from_penalty + goal_bonus
			_scored_mf.append({"pos": candidate, "score": score})

		_scored_mf.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))

		if _scored_mf.is_empty():
			return field.clamp_position(from - step * pace)

		var _hp_ratio_mf: float = clampf(float(merc.current_hp) / float(merc.stats.get("maximum_hit_points", 1)), 0.1, 1.0)
		var _best_break_fall_mf: float = maxf(
			clampf(float(merc.stats.get("parkour", 0.0)) / 100.0, 0.0, 1.0),
			clampf(float(merc.stats.get("tolerance", 0.0)) / 100.0, 0.0, 1.0))
		var fall_tolerance_mf: float = clampf(_hp_ratio_mf + _best_break_fall_mf, 0.2, 2.0)
		var ally_passable_mf: Dictionary
		if state.turn_ally_passable.has(merc):
			ally_passable_mf = state.turn_ally_passable[merc] as Dictionary
		else:
			ally_passable_mf = {}
			for _ally_mf: MercenaryData in allies_mf:
				if BattleState._is_alive(_ally_mf) and not ConstStates.has_state(_ally_mf, ConstStates.DEPOSED):
					var _ap_mf: Vector2i = state.positions.get(_ally_mf, Vector2i(-1, -1))
					if _ap_mf != Vector2i(-1, -1):
						ally_passable_mf[_ap_mf] = true
			ally_passable_mf.merge(field.get_nav_passable_cells())

		var _chosen_mf := Vector2i(-1, -1)
		for entry: Dictionary in _scored_mf:
			var candidate: Vector2i = entry["pos"] as Vector2i
			if not Pathfinder.find_path(from, candidate, field, ally_passable_mf, fall_tolerance_mf).is_empty():
				_chosen_mf = candidate
				break
		if _chosen_mf == Vector2i(-1, -1):
			_chosen_mf = _scored_mf[0]["pos"] as Vector2i

		var _existing_goal: Vector2i = state.move_goals.get(merc, Vector2i(-1, -1)) as Vector2i
		if _existing_goal != Vector2i(-1, -1) and _existing_goal != _chosen_mf:
			var _goal_entry_mf: Dictionary = {}
			for _e: Dictionary in _scored_mf:
				if (_e["pos"] as Vector2i) == _existing_goal:
					_goal_entry_mf = _e
					break
			var _best_score: float = float(_scored_mf[0]["score"])
			var _goal_score: float = float(_goal_entry_mf.get("score", -INF))
			if _best_score - _goal_score > 2.0:
				state.move_goals[merc] = _chosen_mf
		else:
			state.move_goals[merc] = _chosen_mf

		return _chosen_mf

	var stop_dist := MELEE_RANGE
	if stop_dist_override >= 0:
		stop_dist = stop_dist_override
	else:
		var weapon := merc.equipped_weapon
		if weapon != null:
			if not weapon.is_ranged:
				stop_dist = weapon.melee_range
			elif weapon.ranged_intended_range > 0:
				if action_name == "Move Close":
					stop_dist = MELEE_RANGE
				else:
					stop_dist = weapon.ranged_intended_range
		# Moving toward an ally (reposition): close full distance without weapon-range stopping
		if state.get_allies(merc).has(move_target):
			stop_dist = 0

	if flank_ally != null:
		var ally_pos := state.get_position(flank_ally)
		var flank_step := Vector2i(signi(to.x - ally_pos.x), signi(to.y - ally_pos.y))
		if flank_step != Vector2i.ZERO:
			var flank_target := to + flank_step * stop_dist
			dx = flank_target.x - from.x
			dy = flank_target.y - from.y
			step = Vector2i(signi(dx), signi(dy))

	# 3D Chebyshev: a pure-height gap (same 2D cell, different height) must count as real distance.
	var dist_to_target: int
	if flank_ally == null and field != null:
		dist_to_target = state.distance_to(merc, move_target)
	else:
		dist_to_target = maxi(abs(dx), abs(dy))
	var max_steps := maxi(0, dist_to_target - stop_dist)
	var actual_steps := mini(pace, max_steps)
	if actual_steps == 0:
		return from
	if valid_targets.is_empty() and not enemies.is_empty() and field != null:
		var _perp := Vector2i(-step.y, step.x)
		for _fk_dir: Vector2i in [_perp, Vector2i(-_perp.x, -_perp.y)]:
			var _fk := field.clamp_position(to + _fk_dir)
			if _fk != from and _fk != to:
				return _fk
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


# Returns `pos` if it is passable from any cardinal neighbour, otherwise
# searches outward in expanding rings (max radius 3) for the nearest cell
# that can be entered.  Keeps goal-redirect cheap while handling walls,
# closed doors, and steep terrain that _compute_move_position ignores.
static func _nearest_passable_to(pos: Vector2i, field: BattlefieldArea,
		p_fall_tolerance: float = 1.0, p_can_climb: bool = false) -> Vector2i:
	var cardinals: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
	]
	var all_dirs: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	# Inner helper: true when `cell` can be entered from at least one cardinal neighbour.
	var _is_passable := func(cell: Vector2i) -> bool:
		for cd: Vector2i in cardinals:
			var nb: Vector2i = cell + cd
			if nb.x < 0 or nb.x >= field.width or nb.y < 0 or nb.y >= field.length:
				continue
			if Pathfinder.cell_pace_cost(nb, cell, field, {}, p_fall_tolerance, false, p_can_climb) >= 0:
				return true
		return false

	if _is_passable.call(pos):
		return pos

	var visited: Dictionary = {pos: true}
	var queue: Array[Vector2i] = [pos]
	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		for d: Vector2i in all_dirs:
			var nb: Vector2i = curr + d
			if nb.x < 0 or nb.x >= field.width or nb.y < 0 or nb.y >= field.length:
				continue
			if visited.has(nb):
				continue
			visited[nb] = true
			if _is_passable.call(nb):
				return nb
			if maxi(abs(nb.x - pos.x), abs(nb.y - pos.y)) < 3:
				queue.append(nb)
	return pos  # no passable cell found within radius 3; pathfinder will report blocked


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
	var ignore_ext_range: bool = WeaponArmorPerkLibrary.has_weapon_passive(attacker, "weapon_passive:ignore_flaw_extended_range")
	if weapon.is_ranged and weapon.ranged_intended_range > 0:
		if dist > weapon.ranged_intended_range and not ignore_ext_range:
			return 1
	elif weapon.is_throwable and weapon.thrown_intended_range > 0:
		# TODO: wire extended range check here -- thrown_extended_range_bonus extends the no-flaw zone
		var thrown_range_bonus: int = attacker.active_states.get("thrown_extended_range_bonus", 0)
		if dist > weapon.thrown_intended_range + thrown_range_bonus and not ignore_ext_range:
			return 1
	return 0


static func _execute_reload(merc: MercenaryData, state: BattleState, enhancements: int = 0) -> Array[String]:
	# Note: weapon_misfired is NOT cleared here. It is reset at the start of each turn
	# (_execute_turn line ~124) before any decisions are evaluated, so reloading after a
	# misfire on the same turn is correctly allowed -- the flag was already cleared.
	var weapon := merc.equipped_weapon
	if weapon == null or not weapon.is_ranged:
		return []
	var ammo_type := merc.ammo_loaded_type
	if ammo_type == "":
		return []
	var available: int = merc.ammo_inventory.get(ammo_type, 0)
	if available <= 0:
		return []
	# Quiver weapons (chamber=0): resync ammo_loaded from inventory; no AP cost
	if weapon.chamber <= 0:
		if merc.ammo_loaded > 0:
			return []
		merc.ammo_loaded = available
		var lines_q: Array[String] = ["  %s restocks quiver. (%d available)" % [_cn(merc, state), available]]
		lines_q.append_array(_fire_weapon_reactive(merc, "after_reload", null, {}, state, enhancements))
		return lines_q
	if merc.ammo_loaded >= weapon.chamber:
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
	var lines: Array[String] = ["  %s reloads. [%d+%d]" % [_cn(merc, state), merc.ammo_loaded, remaining]]
	lines.append_array(_fire_weapon_reactive(merc, "after_reload", null, {}, state, enhancements))
	return lines


static func _get_draw_cost(merc: MercenaryData, weapon: WeaponData) -> int:
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
		if perk.effect_dsl.contains("weapon_stat:draw:0"):
			return 0
	return weapon.draw


static func _execute_draw(merc: MercenaryData, weapon: WeaponData, state: BattleState, enhancements: int = 0) -> Array[String]:
	if weapon == null:
		return []
	var draw_cost := state.get_cost(merc, "Draw", _get_draw_cost(merc, weapon))
	if not state.can_afford(merc, draw_cost):
		return []
	if merc.equipped_weapon != weapon:
		if weapon.is_virtual:
			merc.equipped_weapon = weapon
		else:
			var found := false
			for i: int in range(merc.inventory.size()):
				var entry: Dictionary = merc.inventory[i]
				if entry.get("type") == "weapon" and entry.get("data") == weapon:
					merc.inventory.remove_at(i)
					found = true
					break
			if not found:
				return []
			merc.equipped_weapon = weapon
	merc.weapon_drawn = true
	state.spend_ap(merc, draw_cost)
	state.record_action(merc, "Draw")
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("DRAW: %s draws %s [%dAP]" % [merc.merc_name, weapon.item_name, draw_cost])
	var lines: Array[String] = ["  %s draws %s [%dAP]" % [_cn(merc, state), weapon.item_name, draw_cost]]
	lines.append_array(_fire_weapon_reactive(merc, "on_draw", null, {}, state, enhancements))
	return lines


static func _execute_holster(merc: MercenaryData, state: BattleState) -> Array[String]:
	var weapon := merc.equipped_weapon
	if weapon == null or not merc.weapon_drawn:
		return []
	var cost := state.get_cost(merc, "Holster", _get_draw_cost(merc, weapon))
	if not state.can_afford(merc, cost):
		return []
	if not weapon.is_virtual:
		merc.inventory.append({"type": "weapon", "data": weapon})
	merc.equipped_weapon = null
	merc.weapon_drawn = false
	state.spend_ap(merc, cost)
	state.record_action(merc, "Holster")
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("HOLSTER: %s holsters %s [%dAP]" % [merc.merc_name, weapon.item_name, cost])
	return ["  %s holsters %s [%dAP]" % [_cn(merc, state), weapon.item_name, cost]]


static func _execute_drop(merc: MercenaryData, state: BattleState, cause: String = "") -> Array[String]:
	var weapon := merc.equipped_weapon
	if weapon == null or not merc.weapon_drawn:
		return []
	var pos := state.get_position(merc)
	state.drop_weapon(merc)
	var cause_str := (" (%s)" % cause) if cause != "" else ""
	return ["  %s drops %s at (%d,%d)%s" % [_cn(merc, state), weapon.item_name, pos.x, pos.y, cause_str]]


static func _execute_pickup(
		merc: MercenaryData,
		weapon_entry: Dictionary,
		weapon_pos: Vector2i,
		state: BattleState) -> Array[String]:
	var weapon: WeaponData = weapon_entry.get("weapon")
	if weapon == null:
		return []
	var still_there := false
	for e: Dictionary in state.get_dropped_weapons_at(weapon_pos):
		if e.get("weapon") == weapon:
			still_there = true
			break
	if not still_there:
		return []
	var pickup_cost := state.get_cost(merc, "PickUp", 1 + weapon.draw)
	if not state.can_afford(merc, pickup_cost):
		return []
	if merc.equipped_weapon != null and merc.weapon_drawn:
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("HOLSTER: %s holsters %s to pick up %s" % [merc.merc_name, merc.equipped_weapon.item_name, weapon.item_name])
		merc.inventory.append({"type": "weapon", "data": merc.equipped_weapon})
		merc.equipped_weapon = null
		merc.weapon_drawn = false
	state.remove_dropped_weapon(weapon_pos, weapon_entry)
	merc.equipped_weapon = weapon
	merc.weapon_drawn = true
	merc.ammo_loaded = weapon_entry.get("ammo_loaded", 0)
	merc.ammo_loaded_type = weapon_entry.get("ammo_loaded_type", "")
	state.spend_ap(merc, pickup_cost)
	state.record_action(merc, "PickUp")
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("DRAW: %s picks up %s [%dAP]" % [merc.merc_name, weapon.item_name, pickup_cost])
	return ["  %s picks up %s. (AP: %d)" % [_cn(merc, state), weapon.item_name, pickup_cost]]


static func _execute_move_to_pos(
		merc: MercenaryData,
		target_pos: Vector2i,
		state: BattleState,
		enhancements: int = 0) -> Array[String]:
	if state.battlefield == null:
		return []
	var old_pos := state.get_position(merc)
	if old_pos == target_pos:
		return []
	var pace := maxi(1, int(merc.stats.get("pace", 1)))
	if ConstStates.has_state(merc, ConstStates.DEPOSED):
		pace = mini(pace, 1)
	var dx := target_pos.x - old_pos.x
	var dy := target_pos.y - old_pos.y
	var step := Vector2i(signi(dx), signi(dy))
	var dist := maxi(abs(dx), abs(dy))
	var steps := mini(pace, dist)
	var new_pos := state.battlefield.clamp_position(old_pos + step * steps)
	if new_pos == old_pos:
		return []
	while new_pos != old_pos and state.is_position_occupied(new_pos, merc):
		steps -= 1
		if steps <= 0:
			return []
		new_pos = state.battlefield.clamp_position(old_pos + step * steps)
	if state.is_position_occupied(new_pos, merc):
		return []
	var move_cost := state.get_cost(merc, "Move Close", MOVE_BASE_AP)
	state.spend_ap(merc, move_cost)
	state.record_action(merc, "Move Close")
	var move_lines: Array[String] = []
	var triggered: Array = ReactiveActionSystem.get_triggered_reactions(
		"enemy_leaves_melee_range", merc, old_pos, new_pos, state)
	for entry: Dictionary in triggered:
		var reactor: MercenaryData = entry["reactor"]
		var def: ActionData = entry["reaction"]
		reactor.current_ep -= def.ep_cost
		state.last_attacked[reactor] = merc
		if reactor.equipped_weapon != null and reactor.equipped_weapon.is_ranged:
			state.record_ranged_targeted(merc)
		var atk_flaws := _compute_attack_flaws(reactor, merc, state)
		var weapon_enh := _get_weapon_enhance_bonus(reactor)
		var atk := AttackSystem.execute_attack(reactor, enhancements + weapon_enh, atk_flaws, merc)
		move_lines.append("  %s takes an Advantage Attack against %s!" % [_cn(reactor, state), _cn(merc, state)])
		if atk.get("misfired", false):
			move_lines.append("  %s misfires!" % _cn(reactor, state))
		elif atk.get("no_ammo", false):
			move_lines.append("  %s has no ammo!" % _cn(reactor, state))
			reactor.current_ep += def.ep_cost
		elif atk["damage"] > 0:
			move_lines.append_array(_apply_damage(reactor, merc, atk["damage"], atk["damage_type"], state, enhancements))
		else:
			move_lines.append("  %s misses %s with the Advantage Attack." % [_cn(reactor, state), _cn(merc, state)])
	state.set_position(merc, new_pos)
	merc.aim_active = false
	state.clear_cover(merc)
	move_lines.append("  %s -> weapon ([color=orange]%d,%d -> %d,%d[/color])" % [
		_cn(merc, state), old_pos.x, old_pos.y, new_pos.x, new_pos.y])
	return move_lines


static func _can_attack_target(
		attacker: MercenaryData,
		target: MercenaryData,
		state: BattleState) -> bool:
	if state.battlefield == null:
		return true
	var weapon := attacker.equipped_weapon
	var dist := state.distance_to(attacker, target)
	var is_melee := weapon == null or (not weapon.is_ranged and not weapon.is_throwable)
	var melee_range := MELEE_RANGE if weapon == null \
		else WeaponArmorPerkLibrary.get_effective_melee_range(attacker)
	# Cover only blocks ranged/thrown; a melee attacker within reach can strike
	# regardless of terrain elevation difference between their tiles.
	if not (is_melee and dist <= melee_range):
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("COVER CHECK: %s->%s dist=%d melee=%s melee_range=%d — applying cover check" % [
				attacker.merc_name, target.merc_name, dist, str(is_melee), melee_range])
		if state.is_covered_from(target, attacker, ConstStates.COVERED_FULL):
			return false
	else:
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("COVER CHECK: %s->%s dist=%d melee=%s melee_range=%d — BYPASSED (adjacent melee)" % [
				attacker.merc_name, target.merc_name, dist, str(is_melee), melee_range])
	if weapon == null:
		return dist <= MELEE_RANGE
	if weapon.is_ranged:
		if attacker.ammo_loaded <= 0:
			return dist <= melee_range
		if attacker.weapon_misfired:
			return false
		return weapon.ranged_extended_range <= 0 or dist <= weapon.ranged_extended_range
	if weapon.is_throwable:
		var thrown_range_bonus: int = attacker.active_states.get("thrown_extended_range_bonus", 0)
		return weapon.thrown_extended_range <= 0 or dist <= weapon.thrown_extended_range + thrown_range_bonus
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("RANGE CHECK: %s->%s dist=%d vs range=%d — %s" % [
			attacker.merc_name, target.merc_name, dist, melee_range,
			"OK" if dist <= melee_range else "out_of_range"])
	return dist <= melee_range


static func _apply_damage(
		attacker: MercenaryData,
		defender: MercenaryData,
		damage: int,
		damage_type: String,
		state: BattleState,
		extra_enhancements: int = 0) -> Array[String]:
	var lines: Array[String] = []
	if defender == null:
		push_error("_apply_damage: defender is null (attacker=%s damage=%d type=%s)" % [
			attacker.merc_name if attacker != null else "null", damage, damage_type])
		return lines
	var was_dying := ConstStates.has_state(defender, ConstStates.DYING)
	var used_excess_ap := false

	var free_def := false
	if state.battlefield != null:
		free_def = state.is_covered_from(defender, attacker, ConstStates.COVERED_PARTIAL)
		if free_def and EncounterLogger.is_active():
			EncounterLogger.log_verbose("FREE DEF: %s has terrain/cover advantage over %s" % [
				defender.merc_name, attacker.merc_name])

	# Slowed defenders need 2 excess AP to substitute for EP
	var excess_needed := 2 if ConstStates.has_state(defender, ConstStates.SLOWED) else 1

	var worth_defending := free_def or CombatDecision.should_attempt_defense(defender, damage, damage_type)

	if worth_defending and not free_def:
		if defender.excess_ap >= excess_needed \
				and not ConstStates.has_state(defender, ConstStates.DEBILITATED):
			defender.excess_ap -= excess_needed
			used_excess_ap = true
		# else: DefenseSystem will spend EP if available

	var defense_free := free_def or used_excess_ap
	var res := DefenseSystem.resolve(defender, damage, damage_type, extra_enhancements, defense_free, not worth_defending)
	if EncounterLogger.is_active():
		for key: String in ["defend_result", "dodge_result"]:
			if res.has(key) and not (res[key] as Dictionary).is_empty():
				var dr: Dictionary = res[key]
				EncounterLogger.log_verbose("DEFENSE ROLL (%s): %s vs %.0f%% -> %d hit %d miss  blocked=%d" % [
					key.replace("_result", ""), str(dr["roll2"]), dr["threshold"],
					dr["successes"], dr["failures"],
					int(res.get("defend_reduction" if key == "defend_result" else "dodge_reduction", 0))])
		if res["final_damage"] == 0 and res["modified_damage"] > 0:
			EncounterLogger.log_verbose("DAMAGE BLOCKED: %d %s fully blocked by defense (free_def=%s)" % [
				res["modified_damage"], damage_type, str(free_def)])
	var atk_name := _cn(attacker, state)
	var def_name := _cn(defender, state)

	if res["is_immune"]:
		lines.append("  %s is immune to %s." % [def_name, damage_type])
		return lines

	var in_dmg: int = res["modified_damage"]
	var final_dmg: int = res["final_damage"]
	if final_dmg > 0:
		defender.aim_active = false
		defender.combat_idle_rounds = 0
	var defended: bool = res["ep_spent"] > 0
	var res_type := "ExAP" if used_excess_ap else "EP"
	var res_amount: int = excess_needed if used_excess_ap else res["ep_spent"]

	lines.append("  %s [color=red][%d][/color] %s v %s" % [atk_name, in_dmg, damage_type, def_name])
	if defended or used_excess_ap:
		var def_label := "Dodge" if res.get("reduction_source", "") == "dodge" else "Defend"
		lines.append("  %s -%d %s, %s [color=red][%d][/color]" % [def_name, res_amount, res_type, def_label, in_dmg - final_dmg])
	if final_dmg > 0:
		lines.append("  %s: HP [color=red]%d[/color]" % [def_name, defender.current_hp])

	var pain_limit := int(defender.stats.get("pain_limit", 0))
	if not was_dying and pain_limit > 0 and final_dmg >= pain_limit:
		var num_checks := 1 + (final_dmg - pain_limit)
		var _eap_pre := defender.excess_ap; var _ap_pre := defender.current_ap
		var _ep_pre := defender.current_ep; var _hp_pre := defender.current_hp
		lines.append_array(_apply_pain_limit_checks(defender, num_checks, def_name))
		lines.append_array(_handle_on_pain_perks(attacker, defender, num_checks, state))
		if ConstStates.has_state(defender, ConstStates.CLIMBING):
			var _pain_failed := (defender.excess_ap != _eap_pre or defender.current_ap != _ap_pre
				or defender.current_ep != _ep_pre or defender.current_hp != _hp_pre)
			if _pain_failed:
				lines.append("  %s loses their grip from the pain!" % def_name)
				lines.append_array(_fall_from_wall(defender, state))
	elif not was_dying and pain_limit > 0 and final_dmg > 0:
		# weapon_passive:force_pain_response_within:N -- force pain check even below pain_limit
		for _perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(attacker):
			if _perk.effect_dsl.begins_with("weapon_passive:force_pain_response_within:"):
				var _range: int = int(_perk.effect_dsl.get_slice(":", 2))
				if state.battlefield == null or state.distance_to(attacker, defender) <= _range:
					var _eap_pre2 := defender.excess_ap; var _ap_pre2 := defender.current_ap
					var _ep_pre2 := defender.current_ep; var _hp_pre2 := defender.current_hp
					lines.append_array(_apply_pain_limit_checks(defender, 1, def_name))
					if ConstStates.has_state(defender, ConstStates.CLIMBING):
						var _pain_failed2 := (defender.excess_ap != _eap_pre2 or defender.current_ap != _ap_pre2
							or defender.current_ep != _ep_pre2 or defender.current_hp != _hp_pre2)
						if _pain_failed2:
							lines.append("  %s loses their grip from the pain!" % def_name)
							lines.append_array(_fall_from_wall(defender, state))
				break

	if final_dmg >= 1 and was_dying:
		defender.current_hp = -1
		ConstStates.remove_state(defender, ConstStates.DYING)
		lines.append("  %s is dead!" % def_name)
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("DEATH CONFIRMED: %s — struck while Dying (final_dmg=%d)" % [
				defender.merc_name, final_dmg])
		lines.append_array(_handle_on_kill_perks(attacker, defender, state))
	elif defender.current_hp <= 0 and not was_dying:
		defender.current_hp = 0
		ConstStates.apply_state(defender, ConstStates.DYING)
		lines.append("  %s is dying!" % def_name)
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("DYING STATE: %s — hp reached 0, cheat death roll pending next turn" % defender.merc_name)

	if final_dmg > 0 and EncounterLogger.is_active():
		EncounterLogger.log_verbose("HP RESULT: %s hp=%d (final_dmg=%d free_def=%s)" % [
			defender.merc_name, defender.current_hp, final_dmg, str(free_def)])

	state.record_damage_dealt(attacker, defender, final_dmg)
	return lines


static func _apply_pain_limit_checks(
		defender: MercenaryData,
		num_checks: int,
		def_name: String) -> Array[String]:
	var lines: Array[String] = []
	var tolerance := clampf(float(defender.stats.get("tolerance", 0.0)), 0.0, 100.0)
	var excess_ap_lost := 0
	var ap_lost := 0
	var ep_lost := 0
	var hp_lost := 0

	var max_ap := int(defender.stats.get("action_points", 5))
	for _i in range(num_checks):
		if randi_range(1, 100) > tolerance:
			if defender.excess_ap > 0:
				defender.excess_ap -= 1
				excess_ap_lost += 1
			elif defender.current_ap > 0:
				defender.current_ap -= 1
				ap_lost += 1
			elif defender.ap_debt < max_ap:
				defender.ap_debt += 1
				ap_lost += 1
			elif defender.current_ep > 0:
				defender.current_ep -= 1
				ep_lost += 1
			else:
				defender.current_hp -= 1
				hp_lost += 1

	var total_failures := excess_ap_lost + ap_lost + ep_lost + hp_lost
	if total_failures == 0:
		lines.append("  %s passes %d pain." % [def_name, num_checks])
	else:
		var lost_parts: Array[String] = []
		if excess_ap_lost > 0: lost_parts.append("%d ExAP" % excess_ap_lost)
		if ap_lost > 0: lost_parts.append("%d AP" % ap_lost)
		if ep_lost > 0: lost_parts.append("%d EP" % ep_lost)
		if hp_lost > 0: lost_parts.append("%d HP" % hp_lost)
		lines.append("  %s fails %d/%d pain: -%s." % [
			def_name, total_failures, num_checks, ", ".join(lost_parts)])
	return lines


static func _cn(merc: MercenaryData, state: BattleState) -> String:
	var first := merc.merc_name.get_slice(" ", 0)
	for i: int in range(state.teams.size()):
		if (state.teams[i] as Array).has(merc):
			return "[color=%s]%s[/color]" % ["white" if i == 0 else "yellow", first]
	return first


static func _get_dead_body_at(pos: Vector2i, state: BattleState) -> MercenaryData:
	for m: MercenaryData in state.positions.keys():
		if m.current_hp < 0 and state.positions[m] == pos:
			return m
	return null


static func _get_deposed_merc_at(pos: Vector2i, state: BattleState) -> MercenaryData:
	for m: MercenaryData in state.positions.keys():
		if BattleState._is_alive(m) and ConstStates.has_state(m, ConstStates.DEPOSED) and state.positions[m] == pos:
			return m
	return null


static func _get_standing_ally_at(pos: Vector2i, merc: MercenaryData, state: BattleState) -> MercenaryData:
	for ally: MercenaryData in state.get_allies(merc):
		if BattleState._is_alive(ally) \
				and not ConstStates.has_state(ally, ConstStates.DEPOSED) \
				and state.positions.get(ally) == pos:
			return ally
	return null


static func _get_weapon_enhance_bonus(merc: MercenaryData) -> int:
	var total: int = 0
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
		if perk.effect_dsl.begins_with("weapon_enhance:"):
			var value_str: String = perk.effect_dsl.substr(len("weapon_enhance:"))
			total += value_str.to_int()
	return total


# Returns extra damage from on_crit weapon perks and applies their side effects.
# Currently handles: on_crit:spend_ammo_5s:damage_per_5:+1
static func _get_on_crit_damage_bonus(merc: MercenaryData, lines: Array[String]) -> int:
	var bonus: int = 0
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
		if perk.effect_dsl == "on_crit:spend_ammo_5s:damage_per_5:+1":
			var extra: int = maxi(0, merc.ammo_loaded - 1)
			var multiples: int = floori(extra / 5.0)
			if multiples <= 0:
				continue
			var spent: int = multiples * 5
			merc.ammo_loaded -= spent
			bonus += multiples
			lines.append("  %s spends %d extra bullets (Burst), adding %d damage." % [
				merc.merc_name.get_slice(" ", 0), spent, multiples])
	return bonus


static func _get_enemies_within(merc: MercenaryData, paces: int, state: BattleState) -> Array[MercenaryData]:
	var result: Array[MercenaryData] = []
	for enemy: MercenaryData in state.get_enemies(merc):
		if not BattleState._is_alive(enemy):
			continue
		if state.battlefield == null or state.distance_to(merc, enemy) <= paces:
			result.append(enemy)
	return result


static func _handle_on_kill_perks(
		attacker: MercenaryData, defender: MercenaryData,
		state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	var two_handed := WeaponArmorPerkLibrary.is_wielding_two_handed(attacker)
	var target_size := int(defender.stats.get("size", 1))

	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(attacker):
		if not perk.effect_dsl.begins_with("on_kill:"):
			continue
		var parts := perk.effect_dsl.split(":")
		# on_kill:two_handed:size_1_plus:gain_rep:1
		var cond    := parts[1] if parts.size() > 1 else ""
		var subcond := parts[2] if parts.size() > 2 else ""
		var effect  := parts[3] if parts.size() > 3 else ""
		var val     := parts[4] if parts.size() > 4 else "0"
		if cond == "two_handed" and not two_handed:
			continue
		if subcond == "size_1_plus" and target_size < 1:
			continue
		if effect == "gain_rep":
			attacker.current_rep += int(val)
			lines.append("  %s gains %s ReP (Severance)!" % [_cn(attacker, state), val])

	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_actions(attacker):
		if not perk.effect_dsl.begins_with("reactive_action:on_kill:"):
			continue
		var parts := perk.effect_dsl.split(":")
		# reactive_action:on_kill:two_handed:attack_new_target:within_2
		# reactive_action:on_kill:1hp:destroy_body
		if parts.size() < 4:
			continue
		var kill_cond   := parts[2]  # e.g. "two_handed" or "1hp"
		var kill_effect := parts[3]  # e.g. "attack_new_target" or "destroy_body"
		if kill_cond == "two_handed" and not two_handed:
			continue
		# "1hp" condition is satisfied by any confirmed kill (hp already set to -1)
		if attacker.current_ep < 1:
			continue
		if kill_effect == "attack_new_target":
			var nearby := _get_enemies_within(attacker, 2, state)
			nearby.erase(defender)
			if nearby.is_empty():
				continue
			attacker.current_ep -= 1
			var new_target := nearby[0] as MercenaryData
			var atk := AttackSystem.execute_attack(attacker, 0, 0, new_target)
			lines.append("  %s spends 1 EP (Chain) to attack %s!" % [_cn(attacker, state), _cn(new_target, state)])
			if atk.get("damage", 0) > 0:
				lines.append_array(_apply_damage(attacker, new_target, atk["damage"], atk["damage_type"], state))
			else:
				lines.append("  %s misses %s." % [_cn(attacker, state), _cn(new_target, state)])
		elif kill_effect == "destroy_body":
			attacker.current_ep -= 1
			lines.append("  %s spends 1 EP (Obliteration) and destroys the body!" % _cn(attacker, state))

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
		var dsl := perk.effect_dsl
		if not dsl.begins_with("reactive_action:"):
			continue
		var parts := dsl.split(":")
		if parts.size() < 2:
			continue
		var perk_trigger := parts[1]
		if perk_trigger != trigger:
			continue
		if attacker.current_ep < 1:
			continue
		var effect := parts[2] if parts.size() > 2 else ""
		match effect:
			"damage":
				if target == null:
					continue
				attacker.current_ep -= 1
				var val_str := parts[3] if parts.size() > 3 else "+0"
				var bonus: int
				if val_str == "pain_limit":
					bonus = int(target.stats.get("pain_limit", 0))
				else:
					bonus = int(val_str)
				if bonus > 0:
					lines.append_array(_apply_damage(attacker, target, bonus, atk.get("damage_type", "Strike"), state))
					lines.append("  %s activates %s!" % [_cn(attacker, state), perk.trait_name.split("|")[-1]])
			"throw_attack":
				if target == null:
					continue
				attacker.current_ep -= 1
				var thrown_atk := AttackSystem.execute_attack(attacker, enhancements, 0, target)
				lines.append("  %s throws weapon (reactive)!" % _cn(attacker, state))
				if thrown_atk.get("damage", 0) > 0:
					lines.append_array(_apply_damage(attacker, target, thrown_atk["damage"], thrown_atk["damage_type"], state))
			"attack_same_target":
				if target == null:
					continue
				attacker.current_ep -= 1
				var extra_atk := AttackSystem.execute_attack(attacker, enhancements, 0, target)
				var dmg_mod := int(parts[4]) if parts.size() > 4 else 0
				lines.append("  %s makes a reactive attack!" % _cn(attacker, state))
				if extra_atk.get("damage", 0) > 0:
					var final_d := maxi(0, extra_atk["damage"] + dmg_mod)
					lines.append_array(_apply_damage(attacker, target, final_d, extra_atk["damage_type"], state))
			"attack":
				if target == null:
					continue
				attacker.current_ep -= 1
				var extra_atk := AttackSystem.execute_attack(attacker, enhancements, 0, target)
				var dtype: String = parts[3] if parts.size() > 3 else str(extra_atk.get("damage_type", "Strike"))
				if extra_atk.get("damage", 0) > 0:
					lines.append_array(_apply_damage(attacker, target, extra_atk["damage"], dtype, state))
			"reload":
				attacker.current_ep -= 1
				lines.append_array(_execute_reload(attacker, state, enhancements))
			"attack_new_target":
				pass
			_:
				pass
	return lines


# Returns an affordable perk action for merc, or null if none applies.
# Prioritizes AoE actions when 2+ enemies are adjacent.
static func _choose_perk_action(merc: MercenaryData, target: MercenaryData, state: BattleState) -> TraitData:
	if target == null:
		return null
	var best: TraitData = null
	var best_is_aoe := false
	var adj_enemy_count := _get_enemies_within(merc, 1, state).size()
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_actions(merc):
		var dsl := perk.effect_dsl
		if not dsl.begins_with("action:"):
			continue
		var parts := dsl.split(":")
		var ap_cost := int(parts[1]) if parts.size() > 1 else 99
		if not state.can_afford(merc, ap_cost):
			continue
		var ep_cost := 0
		var rep_cost := 0
		for idx in range(2, parts.size() - 1):
			if parts[idx] == "ep":
				ep_cost = int(parts[idx + 1])
			elif parts[idx] == "rep":
				rep_cost = int(parts[idx + 1])
		if merc.current_ep < ep_cost or merc.current_rep < rep_cost:
			continue
		# Find the effect token to determine if this is AoE
		var effect_start := 2
		for idx in range(2, parts.size()):
			if parts[idx] in ["ep", "rep", "once_per_combat"]:
				if idx + 1 < parts.size():
					effect_start = idx + 2
		var effect := parts[effect_start] if parts.size() > effect_start else ""
		var is_aoe := effect == "attack_all_adjacent_max_1"
		# Prefer AoE when 2+ enemies adjacent; otherwise take first affordable perk
		if best == null or (is_aoe and not best_is_aoe and adj_enemy_count >= 2):
			best = perk
			best_is_aoe = is_aoe
	return best


# Executes a perk-defined action, spending AP/EP/ReP and applying the effect.
# Returns log lines, or empty if the action is unimplemented (AP is refunded).
static func _execute_perk_action(
		merc: MercenaryData,
		perk: TraitData,
		target: MercenaryData,
		state: BattleState,
		enhancements: int) -> Array[String]:
	var lines: Array[String] = []
	var dsl := perk.effect_dsl
	var parts := dsl.split(":")
	var ap_cost := int(parts[1])
	state.spend_ap(merc, ap_cost)

	# Consume optional EP/ReP costs and find where the effect token begins
	var effect_start := 2
	var j := 2
	while j < parts.size() - 1:
		if parts[j] == "ep":
			merc.current_ep -= int(parts[j + 1])
			effect_start = j + 2
			j += 2
		elif parts[j] == "rep":
			merc.current_rep -= int(parts[j + 1])
			effect_start = j + 2
			j += 2
		elif parts[j] == "once_per_combat":
			effect_start = j + 1
			j += 1
		else:
			break

	var effect := parts[effect_start] if parts.size() > effect_start else ""
	match effect:
		"attack_already_damaged":
			# Club Uppercut -- valid only if merc has already attacked this turn
			var attacks_taken: int = state.escalation.get(merc, {}).get("Attack", 0)
			if attacks_taken > 0 and target != null:
				var atk := AttackSystem.execute_attack(merc, enhancements, 0, target)
				lines.append("  %s uses Uppercut!" % _cn(merc, state))
				state.record_action(merc, "Attack")
				if atk.get("misfired", false):
					lines.append("  %s misfires!" % _cn(merc, state))
				elif atk.get("no_ammo", false):
					lines.append("  %s has no ammo loaded!" % _cn(merc, state))
				elif atk.get("damage", 0) > 0:
					lines.append_array(_apply_damage(merc, target, atk["damage"], atk["damage_type"], state))
				else:
					lines.append("  %s misses with Uppercut against %s." % [_cn(merc, state), _cn(target, state)])
			else:
				# Precondition not met -- refund AP and return empty so loop continues normally
				merc.current_ap += ap_cost
				return []
		"attack_all_adjacent_max_1":
			# Flail/Staff Spin -- attack all adjacent enemies, cap damage at 1 per hit
			var adj_enemies := _get_enemies_within(merc, 1, state)
			if not adj_enemies.is_empty():
				lines.append("  %s spins!" % _cn(merc, state))
				for enemy: MercenaryData in adj_enemies:
					var atk := AttackSystem.execute_attack(merc, enhancements, 0, enemy)
					state.record_action(merc, "Attack")
					if atk.get("misfired", false):
						lines.append("  %s misfires!" % _cn(merc, state))
						break
					elif atk.get("damage", 0) > 0:
						lines.append_array(_apply_damage(merc, enemy, 1, atk["damage_type"], state))
					else:
						lines.append("  %s misses %s with the spin." % [_cn(merc, state), _cn(enemy, state)])
			else:
				merc.current_ap += ap_cost
				return []
		"attack_fully_loaded":
			# Handgun Rapid-Fire -- attack only if weapon is fully loaded
			if target != null and merc.equipped_weapon != null:
				var w := merc.equipped_weapon
				if merc.ammo_loaded >= w.chamber:
					var atk := AttackSystem.execute_attack(merc, enhancements, 0, target)
					lines.append("  %s fires rapidly!" % _cn(merc, state))
					state.record_action(merc, "Attack")
					if atk.get("misfired", false):
						lines.append("  %s misfires!" % _cn(merc, state))
					elif atk.get("no_ammo", false):
						lines.append("  %s has no ammo loaded!" % _cn(merc, state))
					elif atk.get("damage", 0) > 0:
						lines.append_array(_apply_damage(merc, target, atk["damage"], atk["damage_type"], state))
					else:
						lines.append("  %s misses with Rapid-Fire against %s." % [_cn(merc, state), _cn(target, state)])
				else:
					# Not fully loaded -- refund and skip
					merc.current_ap += ap_cost
					return []
			else:
				merc.current_ap += ap_cost
				return []
		_:
			# Unimplemented action -- refund AP so it does not silently eat resources
			merc.current_ap += ap_cost
			return []
	return lines


static func _handle_on_pain_perks(
		attacker: MercenaryData,
		defender: MercenaryData,
		_num_checks: int,
		state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	# on_pain:direct:N:timing -- queue deferred damage to fire at named timing
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(attacker):
		if perk.effect_dsl.begins_with("on_pain:direct:"):
			var parts := perk.effect_dsl.split(":")
			if parts.size() >= 4:
				var amt: int = int(parts[2])
				var timing: String = parts[3]
				attacker.deferred_effects.append({
					"target": defender, "damage": amt,
					"type": "Direct", "timing": timing
				})
				lines.append("  %s will take %d Direct damage at %s (bleedout)." % [
					_cn(defender, state), amt, timing])
	# reactive_action:on_pain:repeat_pain_response -- spend 1 EP to trigger pain again
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_actions(attacker):
		if perk.effect_dsl.begins_with("reactive_action:on_pain:repeat_pain_response"):
			if attacker.current_ep >= 1:
				attacker.current_ep -= 1
				lines.append("  %s spends 1 EP — Pain repeats!" % _cn(attacker, state))
				lines.append_array(_apply_pain_limit_checks(defender, 1, _cn(defender, state)))
			break
	return lines


static func _choose_from_action_set(
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		valid_targets: Array[MercenaryData],
		allies: Array[MercenaryData],
		current_target: MercenaryData,
		state: BattleState,
		movement_blocked: bool,
		weapon_action_taken: bool = false,
		has_moved: bool = false,
		seeking_failed: bool = false,
		blocked_targets: Dictionary = {}) -> Dictionary:
	if merc.action_set == null:
		return CombatDecision.decide_next_action(
			merc, enemies, valid_targets, allies, current_target, state,
			ATTACK_BASE_AP, MOVE_BASE_AP, {}, movement_blocked, weapon_action_taken)

	var ctx := {
		"enemies": enemies, "allies": allies, "valid_targets": valid_targets,
		"state": state, "current_target": current_target,
		"movement_blocked": movement_blocked, "has_moved": has_moved,
		"seeking_mode": (state.no_target_turns.get(merc, 0) as int) >= 1,
		"seeking_failed": seeking_failed,
		"blocked_targets": blocked_targets,
		"attack_base_ap": ATTACK_BASE_AP, "move_base_ap": MOVE_BASE_AP
	}
	var snap := _build_decision_snapshot(merc, enemies, valid_targets)

	# Reload before anything else when chamber is empty; _should_reload handles the in-danger case
	if merc.ammo_loaded == 0 and CombatDecision._should_reload(merc, enemies, valid_targets, state):
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("INJECTED [reload]: %s (chamber empty)" % merc.merc_name)
		return {"type": "reload", "action_name": "reload", "target": null}

	var _stuck_rounds := (state.no_progress_rounds.get(merc, 0) as int)
	var _fighting_alone := state.get_allies(merc).is_empty()
	var _is_desperate := _stuck_rounds >= 2 or _fighting_alone
	if _is_desperate and EncounterLogger.is_active():
		var _esc_reason := ("stuck %d rounds" % _stuck_rounds) if _stuck_rounds >= 2 else "last remaining"
		EncounterLogger.log_verbose("[escalation] %s — %s" % [merc.merc_name, _esc_reason])
	if _is_desperate and movement_blocked:
		var _obs_result := CombatDecision.decide_obstacle_or_flank(merc, enemies, valid_targets, state, movement_blocked)
		if EncounterLogger.is_active():
			var _obs_type: String = _obs_result.get("type", "pass")
			if _obs_type != "pass":
				EncounterLogger.log_verbose("    obstacle/flank: %s selected" % _obs_result.get("action_name", _obs_type))
			else:
				EncounterLogger.log_verbose("    obstacle/flank: no valid target found")
		if _obs_result.get("type", "pass") != "pass":
			return _obs_result

	var sorted_actions: Array = merc.action_set.actions.duplicate()
	sorted_actions.sort_custom(func(a: ActionData, b: ActionData) -> bool: return a.priority < b.priority)

	var affordable_actions: Array = sorted_actions.filter(
		func(a: ActionData) -> bool: return a.can_execute(merc, ctx))
	if affordable_actions.is_empty():
		return {"type": "pass", "action_name": "", "target": null}

	var injected_pre_move := false
	var injected_pre_aim := false

	for action: ActionData in sorted_actions:
		if action.is_reactive:
			continue
		if not action.snap_require.is_empty() and not _snap_passes(snap, action.snap_require):
			continue
		if _is_desperate and action.action_name == "seek_cover":
			var _eq := merc.equipped_weapon
			var _weapon_ok := true
			if _eq != null and merc.weapon_drawn and _eq.is_ranged:
				if merc.ammo_loaded <= 0:
					_weapon_ok = false
					for _sv in merc.ammo_inventory.values():
						if int(_sv) > 0:
							_weapon_ok = true
							break
				elif _eq.misfire > 0 and (FirearmReliabilityFacet.compute(merc) * 2.5 + 2.0) / 4.5 < 0.50:
					_weapon_ok = false
			if _weapon_ok:
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("    seek_cover suppressed by escalation")
				continue

		# Before priority 40: reload if empty, then weapon management (draw/holster/switch/pickup)
		if not injected_pre_move and action.priority >= 40:
			injected_pre_move = true
			if merc.ammo_loaded == 0 and CombatDecision._should_reload(merc, enemies, valid_targets, state):
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("INJECTED [reload]: %s (chamber empty, pre-40)" % merc.merc_name)
				return {"type": "reload", "action_name": "reload", "target": null}
			if not weapon_action_taken:
				var wp := CombatDecision._decide_weapon_action(merc, enemies, state, ATTACK_BASE_AP, movement_blocked)
				if wp["type"] != "none":
					return wp
				var pu := CombatDecision._decide_pickup_action(merc, enemies, state, ATTACK_BASE_AP, MOVE_BASE_AP)
				if pu["type"] != "none":
					if EncounterLogger.is_active():
						EncounterLogger.log_verbose("INJECTED [%s]: %s -> %s" % [
							pu["action_name"], merc.merc_name,
							str(pu.get("weapon_pos", pu.get("weapon_entry", {}).get("weapon", "")))])
					return pu

		# Before priority 60: pre-attack reload (ranged strategy)
		if not injected_pre_aim and action.priority >= 60:
			injected_pre_aim = true
			if merc.ammo_loaded > 0 and CombatDecision._should_reload(merc, enemies, valid_targets, state):
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("INJECTED [reload]: %s (pre-attack tactical)" % merc.merc_name)
				return {"type": "reload", "action_name": "reload", "target": null}

		if action.can_execute(merc, ctx):
			if EncounterLogger.is_active():
				var verbose: Dictionary = action.decision.evaluate_verbose(merc, ctx)
				EncounterLogger.log_verbose("DECISION [%s]: score=%.2f threshold=%.2f -> %s" % [
					action.action_name, verbose["score"], action.decision.threshold,
					"PASS" if verbose["passed"] and verbose["score"] >= action.decision.threshold else "fail"])
				for fd: Dictionary in verbose["facets"]:
					var weight_str := "req" if fd["required"] else "w=%.1f" % fd["weight"]
					EncounterLogger.log_verbose("    %s [%s]: %.2f" % [fd["name"], weight_str, fd["score"]])
				if verbose["passed"] and verbose["score"] >= action.decision.threshold:
					if action.action_name == "attack_obstacle":
						return CombatDecision.decide_obstacle_or_flank(merc, enemies, valid_targets, state, movement_blocked)
					return action.to_decision_dict(merc, ctx)
			else:
				var score: float = action.decision.evaluate(merc, ctx)
				if score >= action.decision.threshold:
					if action.action_name == "attack_obstacle":
						return CombatDecision.decide_obstacle_or_flank(merc, enemies, valid_targets, state, movement_blocked)
					return action.to_decision_dict(merc, ctx)

	return {"type": "pass", "action_name": "", "target": null}


static func _build_decision_snapshot(merc: MercenaryData, enemies: Array[MercenaryData], valid_targets: Array) -> Dictionary:
	var weapon := merc.equipped_weapon
	var weapon_drawn := weapon != null and merc.weapon_drawn
	var ranged_enemy := false
	for e: MercenaryData in enemies:
		if e.equipped_weapon != null and e.equipped_weapon.is_ranged:
			ranged_enemy = true
			break
	return {
		"weapon_drawn": weapon_drawn,
		"weapon_is_ranged": weapon != null and merc.weapon_drawn and weapon.is_ranged,
		"has_ammo": merc.ammo_loaded > 0,
		"has_valid_target": not valid_targets.is_empty(),
		"ranged_enemy_present": ranged_enemy,
	}


static func _snap_passes(snap: Dictionary, requirements: Dictionary) -> bool:
	for key: String in requirements:
		if snap.get(key) != requirements[key]:
			return false
	return true
