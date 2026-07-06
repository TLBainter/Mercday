class_name AutoBattle

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")
static var ATTACK_BASE_AP: int:
	get: return _CONFIG.attack_base_ap
static var MOVE_BASE_AP: int:
	get: return _CONFIG.move_base_ap
static var DRAW_BASE_AP: int:
	get: return _CONFIG.draw_base_ap
static var MELEE_RANGE: int:
	get: return _CONFIG.melee_range
static var MAX_ROUNDS: int:
	get: return _CONFIG.max_rounds

static var _stale_rounds: int = 0
static var _no_target_rounds: int = 0


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
	MovementExecutor.clear_caches()
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
	MovementExecutor._near_passable_cache.clear()
	_emit(line_fn, "[color=gray]=== Round %d ===[/color]" % state.round_number)
	var _any_attacked := false
	var any_acted := false
	for merc: MercenaryData in state.turn_queue:
		if not BattleState._is_alive(merc):
			if EncounterLogger.is_active():
				if merc.current_hp == 0 and not ConstStates.has_state(merc, ConstStates.DYING):
					EncounterLogger.log_verbose("Skipping dead merc %s (hp=0, no Dying state - cheat death was not triggered)" % merc.merc_name)
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
	return -1 if BattleStateUpdater.check_stalemate(state) else -1


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
	# Drain deferred effects queued for this merc's turn start (e.g. Dagger Bleedout)
	var _remaining_effects: Array = []
	for _eff in merc.deferred_effects:
		if _eff["timing"] == "self_turn_start":
			var _tgt := _eff["target"] as MercenaryData
			if BattleState._is_alive(_tgt):
				lines.append_array(CombatApplicator.apply_damage(merc, _tgt, _eff["damage"], _eff["type"], state))
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
	lines.append_array(BattleStateUpdater.update_auto_states(merc, state))
	merc.active_states.erase("blocked_pickup_pos")

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
		var _mb_r: int = merc.active_states.get("_move_blocked_round", -1) as int
		var _no_prog: int = state.no_progress_rounds.get(merc, 0) as int
		var movement_blocked := _mb_r >= state.round_number - 1 or _no_prog >= 3
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
			MovementExecutor._turn_path_cache.erase(merc)

		while true:
			_action_slot += 1
			if _action_slot > 50:
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("WARNING: action slot cap reached - ending turn")
				break
			if merc.current_ap <= 0 and merc.excess_ap <= 0:
				break
			if not _skip_await:
				await Engine.get_main_loop().process_frame
			_skip_await = false
			MovementExecutor.last_move_heavy = false
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
						if _vt_weapon != null and _vt_weapon.is_throwable:
							var _vt_computed := WeaponEvaluator.compute_thrown_range(merc, _vt_weapon)
							_vt_reason = "unknown (throwable computed_range=%d)" % _vt_computed
						else:
							_vt_reason = "unknown"
					EncounterLogger.log_verbose("NO_VALID_TARGET: %s rejected %s - %s" % [
						merc.merc_name, e.merc_name, _vt_reason])

			var allies := state.get_allies(merc)

			# All enemies proven unreachable this turn and nothing in attack range -- end turn
			var _no_tgt_turns: int = (state.no_target_turns.get(merc, 0) as int)
			var _is_stuck_or_alone: bool = (state.no_progress_rounds.get(merc, 0) as int) >= 2 \
					or state.get_allies(merc).is_empty() or _no_tgt_turns >= 5
			if valid_targets.is_empty() and (
					(not blocked_targets.is_empty() and blocked_targets.size() >= enemies.size())
					or (movement_blocked and not _is_stuck_or_alone)):
				break

			var perk_action := ActionDispatcher.choose_perk_action(merc, current_target, state)
			if perk_action != null:
				var perk_lines := ActionDispatcher.execute_perk_action(merc, perk_action, current_target, state, enhancements)
				if not perk_lines.is_empty():
					lines.append_array(perk_lines)
					continue

			var decision := ActionDispatcher.choose_from_action_set(
				merc, enemies, valid_targets, allies, current_target, state, movement_blocked, weapon_action_taken, has_moved, seeking_failed, blocked_targets)

			match decision["type"]:
				"move":
					var _is_seeking: bool = decision.get("seeking", false)
					var move_lines := MovementExecutor.execute_move(merc, decision["action_name"], decision["target"], state,
						decision.get("flank_ally"), enhancements, decision.get("move_stop_dist", -1), _is_seeking)
					if move_lines.is_empty():
						movement_blocked = true
						state.record_action(merc, decision["action_name"])
						if not MovementExecutor.last_move_heavy:
							_skip_await = true
						if _is_seeking:
							seeking_failed = true
							var _bt: MercenaryData = decision.get("target")
							if _bt != null:
								blocked_targets[_bt] = true
					else:
						lines.append_array(move_lines)
						movement_blocked = false
						merc.active_states.erase("_move_blocked_round")
						has_moved = true
						blocked_targets.clear()
						current_target = decision["target"]
				"jump":
					var jump_pos: Vector2i = decision.get("jump_target_pos", Vector2i(-1, -1))
					var jump_lines := MovementExecutor.execute_jump(merc, jump_pos, decision["action_name"], state, enhancements)
					if jump_lines.is_empty():
						movement_blocked = true
					else:
						lines.append_array(jump_lines)
						movement_blocked = false
						merc.active_states.erase("_move_blocked_round")
						has_moved = true
						blocked_targets.clear()
						current_target = decision["target"]
				"climb":
					var climb_lines := MovementExecutor.execute_climb(merc, decision, decision["action_name"], state)
					if climb_lines.is_empty():
						movement_blocked = true
					else:
						lines.append_array(climb_lines)
						movement_blocked = false
						merc.active_states.erase("_move_blocked_round")
						has_moved = true
						blocked_targets.clear()
				"special":
					var _spec_ctx := {"enhancements": enhancements}
					var spec_lines := SpecialActionSystem.execute(decision, merc, state, _spec_ctx)
					lines.append_array(spec_lines)
					if spec_lines.is_empty():
						break
					if decision["action_name"] == "aim":
						weapon_action_taken = true
				"reload":
					var reload_lines := WeaponActionExecutor.execute_reload(merc, state, enhancements)
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
					var atk_flaws := MovementExecutor.compute_attack_flaws(merc, current_target, state)
					var aim_bonus := 1 if merc.aim_active else 0
					var weapon_enh := MovementExecutor.get_weapon_enhance_bonus(merc)
					var _is_throw_action: bool = decision["action_name"] == "AttackThrow"
					var atk := AttackSystem.execute_attack(merc, enhancements + aim_bonus + weapon_enh, atk_flaws, current_target, _is_throw_action, state)
					merc.aim_active = false
					if atk.get("no_ammo", false):
						lines.append("  %s has no ammo loaded!" % _cn(merc, state))
						break
					if not atk.get("misfired", false):
						merc.active_states["last_target"] = current_target
					state.spend_ap(merc, atk_cost)
					state.record_action(merc, "Attack")
					merc.combat_idle_rounds = 0
					weapon_action_taken = true
					if atk.get("weapon_broke", false):
						var _broke_name: String = merc.equipped_weapon.item_name if merc.equipped_weapon != null else "weapon"
						lines.append("  %s's %s breaks apart!" % [_cn(merc, state), _broke_name])
						if EncounterLogger.is_active():
							EncounterLogger.log_verbose("FRAGILITY: %s destroyed" % _broke_name)
						merc.equipped_weapon = DataManager.fight_weapon
						merc.weapon_drawn = DataManager.fight_weapon != null
					if EncounterLogger.is_active() and not atk.get("misfired", false) \
							and not (atk["check_result"] as Dictionary).is_empty():
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
						if two_handed_bonus > 0 and EncounterLogger.is_active():
							EncounterLogger.log_verbose("TWO_HANDED_BONUS: %s +%d" % [merc.merc_name, two_handed_bonus])
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
											lines.append_array(CombatApplicator.apply_damage(merc, current_target, 1, "Strike", state))
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
											lines.append_array(CombatApplicator.apply_damage(merc, enemy, 1, atk["damage_type"], state))
									used_perk_effect = true
							if used_perk_effect:
								break
						if not used_perk_effect:
							lines.append_array(CombatApplicator.apply_damage(merc, current_target, final_damage, atk["damage_type"], state, 0))
						if final_damage > 0 and BattleState._is_alive(current_target):
							lines.append_array(WeaponReactiveSystem.apply_on_damage(merc, current_target, merc.equipped_weapon, atk, state))
							if final_damage >= 2:
								lines.append_array(WeaponReactiveSystem.fire_trigger(merc, "on_damage_2_plus", current_target, atk, state, enhancements))
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
									lines.append("  %s calls Artillery Support (3 ReP) - up to 2 allies may move toward %s without AP or AoO!" % [
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
						lines.append_array(WeaponReactiveSystem.apply_on_miss(merc, current_target, merc.equipped_weapon, atk, state))
					lines.append_array(WeaponReactiveSystem.apply_after_attack(merc, current_target, merc.equipped_weapon, atk, state))
					if _is_throw_action and merc.equipped_weapon != null:
						var _thrown_name: String = merc.equipped_weapon.item_name
						merc.equipped_weapon = DataManager.fight_weapon
						merc.weapon_drawn = DataManager.fight_weapon != null
						if EncounterLogger.is_active():
							EncounterLogger.log_verbose("THROW: %s throws %s - weapon leaves hand" % [merc.merc_name, _thrown_name])
						lines.append("  %s throws %s! Weapon leaves their hand." % [_cn(merc, state), _thrown_name])
				"draw":
					var draw_lines := WeaponActionExecutor.execute_draw(merc, decision["weapon"], state, enhancements)
					if draw_lines.is_empty():
						break
					lines.append_array(draw_lines)
					weapon_action_taken = true
				"holster":
					var holster_lines := WeaponActionExecutor.execute_holster(merc, state)
					if holster_lines.is_empty():
						break
					lines.append_array(holster_lines)
					weapon_action_taken = true
				"drop":
					lines.append_array(WeaponActionExecutor.execute_drop(merc, state, decision.get("cause", "")))
					weapon_action_taken = true
				"pickup":
					var pu_lines := WeaponActionExecutor.execute_pickup(merc, decision["weapon_entry"], decision["weapon_pos"], state)
					if pu_lines.is_empty():
						break
					lines.append_array(pu_lines)
					merc.active_states.erase("bfw_drop_pos")
					merc.active_states.erase("target_weapon_pos")
					weapon_action_taken = true
				"move_to_pickup":
					var mv_lines := MovementExecutor.execute_move_to_pos(merc, decision["weapon_pos"], state, enhancements)
					if mv_lines.is_empty():
						movement_blocked = true
						merc.active_states["blocked_pickup_pos"] = decision["weapon_pos"]
					else:
						lines.append_array(mv_lines)
						movement_blocked = false
						weapon_action_taken = true
				"move_to_obstacle":
					var mo_lines := MovementExecutor.execute_move_to_pos(merc, decision["obstacle_pos"], state, enhancements)
					if mo_lines.is_empty():
						movement_blocked = true
					else:
						lines.append_array(mo_lines)
						movement_blocked = false
						weapon_action_taken = true
				_:
					break

		if had_valid_targets:
			state.no_target_turns.erase(merc)
		else:
			state.no_target_turns[merc] = state.no_target_turns.get(merc, 0) + 1

	# Whip Choke: spend:ap:1:direct:1:grappled_target -- spend 1 AP for 1 Direct damage to whip-grappled target
	lines.append_array(ActionDispatcher.do_whip_choke_ap_spend(merc, state))

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

	lines.append_array(BattleStateUpdater.apply_dot_effects(merc, state))

	return false


static func _run_death_test(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	var max_hp := int(merc.stats.get("maximum_hit_points", 1))
	var effective_max: int = max_hp - merc.death_test_hp_loss - merc.rot_hp_loss
	if effective_max <= 0:
		merc.current_hp = -1
		ConstStates.remove_state(merc, ConstStates.DYING)
		lines.append("  %s dies!" % _cn(merc, state))
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("DEATH CONFIRMED: %s - max HP exhausted by death test failures" % merc.merc_name)
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
		var new_effective: int = max_hp - merc.death_test_hp_loss - merc.rot_hp_loss
		if new_effective <= 0:
			merc.current_hp = -1
			ConstStates.remove_state(merc, ConstStates.DYING)
			lines.append("  %s dies!" % _cn(merc, state))
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("DEATH CONFIRMED: %s - cheat death failed, max HP exhausted (total failures=%d)" % [
					merc.merc_name, merc.death_test_hp_loss])
		else:
			lines.append("  %s is still dying! (Max HP reduced to %d)" % [_cn(merc, state), new_effective])


# Whip Choke AP-spend (spend:ap:1:direct:1:grappled_target): after the action loop, spend remaining
# AP 1 at a time for 1 Direct damage per point to the whip-grappled target.

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
			EncounterLogger.log_verbose("COVER CHECK: %s->%s dist=%d melee=%s melee_range=%d - applying cover check" % [
				attacker.merc_name, target.merc_name, dist, str(is_melee), melee_range])
		if state.is_covered_from(target, attacker, ConstStates.COVERED_FULL):
			return false
	else:
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("COVER CHECK: %s->%s dist=%d melee=%s melee_range=%d - BYPASSED (adjacent melee)" % [
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
		var computed_range := WeaponEvaluator.compute_thrown_range(attacker, weapon) + thrown_range_bonus
		if computed_range <= 0:
			return false
		if weapon.thrown_extended_range > 0:
			computed_range = mini(computed_range, weapon.thrown_extended_range)
		return dist <= computed_range
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("RANGE CHECK: %s->%s dist=%d vs range=%d - %s" % [
			attacker.merc_name, target.merc_name, dist, melee_range,
			"OK" if dist <= melee_range else "out_of_range"])
	return dist <= melee_range




static func _cn(merc: MercenaryData, state: BattleState) -> String:
	var first := merc.merc_name.get_slice(" ", 0)
	for i: int in range(state.teams.size()):
		if (state.teams[i] as Array).has(merc):
			return "[color=%s]%s[/color]" % ["white" if i == 0 else "yellow", first]
	return first




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
