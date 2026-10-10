class_name AutoBattle

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")
static var ATTACK_BASE_AP: int:
	get: return _CONFIG.attack_base_ap
static var MOVE_BASE_AP: int:
	get: return _CONFIG.move_base_ap
static var MELEE_RANGE: int:
	get: return _CONFIG.melee_range
static var MAX_ROUNDS: int:
	get: return _CONFIG.max_rounds

static var _stale_rounds: int = 0
static var _no_target_rounds: int = 0
static var _last_yield_msec: int = 0


static func run_battle(state: BattleState, line_fn: Callable = Callable(), encounter_type: String = "encounter") -> Dictionary:
	setup(state, line_fn, encounter_type)
	while await step_round(state, line_fn):
		pass
	return {"winner": state.get_winner(), "rounds": state.round_number}


#Emits the battlefield header/visual and begins the encounter logger.
static func setup(state: BattleState, line_fn: Callable = Callable(), encounter_type: String = "encounter") -> void:
	_stale_rounds = 0
	_no_target_rounds = 0
	_last_yield_msec = Time.get_ticks_msec()
	CriticalSuccessSystem.banking = true
	CoverSearch.clear_scan_cache()
	MovementExecutor.clear_caches()
	FleeSystem.begin_battle(state)
	EncounterLogger.begin(encounter_type, state)
	if EncounterLogger.is_active() and state.battlefield != null:
		HtmlWireframeGenerator.save(state.battlefield, EncounterLogger.current_log_path().get_basename())
	for l: String in CaveInSystem.on_battle_start(state):
		_emit(line_fn, l)
	if state.campaign_seeded > 0 and EncounterLogger.is_active():
		EncounterLogger.log_verbose("CAMPAIGN KNOWLEDGE: %d tokens seeded" % state.campaign_seeded)
	if state.battlefield != null:
		_emit(line_fn, "[color=gray]%s[/color]" % BattlefieldRender.to_header_string(state.battlefield))
		EncounterLogger.log_line(BattlefieldRender.to_visual_string(state.battlefield))
		EncounterLogger.log_generation(state.battlefield)
		if EncounterLogger.is_active():
			LevelDumpWriter.save(state.battlefield, EncounterLogger.current_log_path().get_basename())
		_log_spawns(state)
	if EncounterLogger.is_active():
		for pre_line: String in state.pre_battle_lines:
			EncounterLogger.log_line(pre_line)
	TraitRuntime.begin_encounter(state)


#Yields one frame only when the configured wall-time slice has passed since the last yield.
static func _yield_if_due() -> void:
	var slice: int = _CONFIG.battle_yield_msec
	if slice > 0 and Time.get_ticks_msec() - _last_yield_msec < slice:
		return
	await Engine.get_main_loop().process_frame
	_last_yield_msec = Time.get_ticks_msec()


#One line per merc naming the team, floor and cell it starts the battle on.
static func _log_spawns(state: BattleState) -> void:
	if not EncounterLogger.is_active():
		return
	for i: int in state.teams.size():
		for m: MercenaryData in state.teams[i]:
			var sp := state.get_position(m)
			EncounterLogger.log_verbose("SPAWN: Team %d F%d (%d,%d) %s" % [
				i, state.get_floor(m), sp.x, sp.y, m.merc_name])
	EncounterLogger.log_spawn_map(state)


#Processes exactly one round and emits its lines.
#Returns true if the battle is still ongoing; false when it ends (also finalizes).
static func step_round(state: BattleState, line_fn: Callable = Callable()) -> bool:
	if state.is_battle_over() or state.round_number >= MAX_ROUNDS:
		finalize(state, line_fn)
		return false
	state.round_number += 1
	var round_lines: Array[String] = []
	TraitRuntime.on_round_start(state, round_lines)
	CaveInSystem.start_of_round(state, round_lines)
	state.rotate_round_damage()
	for round_line: String in round_lines:
		_emit(line_fn, round_line)
	_emit(line_fn, "[color=gray]=== Round %d ===[/color]" % state.round_number)
	var _any_attacked := false
	var any_acted := false
	for merc: MercenaryData in state.turn_queue:
		if merc.off_field:
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("Skipping off-field merc %s" % merc.merc_name)
			continue
		if not BattleState._is_alive(merc):
			if EncounterLogger.is_active():
				if not merc.is_dead and merc.current_hp == 0 and not ConstStates.has_state(merc, ConstStates.DYING):
					EncounterLogger.log_verbose("Skipping dead merc %s (hp=0, no Dying state - cheat death was not triggered)" % merc.merc_name)
				else:
					EncounterLogger.log_verbose("Skipping dead merc %s (hp=%d)" % [merc.merc_name, maxi(0, merc.current_hp)])
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
		await _yield_if_due()
	for l: String in CaveInSystem.end_of_round(state):
		_emit(line_fn, l)
	EncounterLogger.flush()
	if state.is_battle_over() or state.round_number >= MAX_ROUNDS:
		finalize(state, line_fn)
		return false
	#A rescue still under way is progress even while nobody attacks.
	if RescueSystem.suspends_stalemate(state):
		_no_target_rounds = 0
		_stale_rounds = 0
	if _any_attacked:
		_no_target_rounds = 0
	else:
		_no_target_rounds += 1
		if _no_target_rounds >= 10:
			_end_by_stalemate(state, line_fn, "[color=red]Stalemate: no target found for 10 consecutive rounds.[/color]")
			return false
	if not any_acted and not state.any_timed_state_pending():
		_stale_rounds += 1
		if _stale_rounds >= 2:
			_end_by_stalemate(state, line_fn, "[color=red]Stalemate: no actions for 2 consecutive rounds.[/color]")
			return false
	else:
		_stale_rounds = 0
	return true


#Emits the stalemate reason, awards a default win when one side has the advantage, then finalizes.
static func _end_by_stalemate(state: BattleState, line_fn: Callable, reason_line: String) -> void:
	_emit(line_fn, reason_line)
	var winner: int = _stalemate_winner(state)
	if winner >= 0:
		state._cached_winner = winner
		_emit(line_fn, "[color=orange]Win by default: Team %d (HP/skill advantage).[/color]" % winner)
	finalize(state, line_fn)


static func finalize(state: BattleState, line_fn: Callable) -> void:
	if RescueSystem.is_active(state):
		var rescue_lines: Array[String] = []
		RescueOutcome.on_battle_end(state, rescue_lines)
		for rescue_line: String in rescue_lines:
			_emit(line_fn, rescue_line)
	CampaignTimers.export_campaign_timers(state)
	TraitRuntime.end_encounter(state)
	state.clear_encounter_cache()
	if not state.dropped_weapons.is_empty():
		for team in state.teams:
			for merc: MercenaryData in team:
				if DroppedItemStore.retrieve_dropped_weapons_for(state, merc) > 0:
					StatCalculator.refresh(merc)
	for team in state.teams:
		for merc: MercenaryData in team:
			for line: String in LoadoutDecision.settle(merc):
				_emit(line_fn, line)
	if state.get_winner() < 0 and state._cached_winner == -2:
		var _dw: int = _stalemate_winner(state)
		if _dw >= 0:
			state._cached_winner = _dw
	var result := {"winner": state.get_winner(), "rounds": state.round_number}
	state._cached_winner = result["winner"]
	_apply_banked_crit_rewards(state)
	var log_stem := EncounterLogger.current_log_path().get_basename() if EncounterLogger.is_active() else ""
	EncounterLogger.end(result)
	if log_stem != "" and state.battlefield != null:
		HtmlWireframeGenerator.save_to(state.battlefield, log_stem + "_end.html")
	var all_mercs: Array[MercenaryData] = []
	for team in state.teams:
		for merc: MercenaryData in team:
			all_mercs.append(merc)
	state.casualties.clear()
	for merc: MercenaryData in all_mercs:
		if merc.is_dead:
			state.casualties.append(merc)


#Applies the crit rewards banked during the encounter, then turns banking back off.
static func _apply_banked_crit_rewards(state: BattleState) -> void:
	for team: Array in state.teams:
		for merc: MercenaryData in team:
			for line: String in CriticalSuccessSystem.apply_pending(merc):
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("CRIT REWARD APPLIED: %s %s" % [merc.merc_name, line])
	CriticalSuccessSystem.banking = false


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
			if m.current_hp > 0 and not m.off_field:
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


static func _emit(line_fn: Callable, line: String) -> void:
	if line_fn.is_valid():
		line_fn.call(line)
	EncounterLogger.log_line(line)


static func _execute_dying_turn(merc: MercenaryData, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	run_death_test(merc, state, lines)
	_run_dying_perks(merc, state, lines)
	lines.append("")
	return lines


static func _run_dying_perks(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	#Dying Perks: weapon/armor perks prefixed with "dying_perk:" fire once per turn while merc is Dying.
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
		if perk.effect_dsl.begins_with("dying_perk:"):
			lines.append("  %s (Dying Perk: %s)" % [BattleState.colored_name(merc, state), perk.trait_name])


#Every flag an action arm may read or write during this turn; a block holds only for its own round.
static func new_turn(merc: MercenaryData, state: BattleState) -> Dictionary:
	var mb_r: int = merc.active_states.get("_move_blocked_round", -1) as int
	var turn: Dictionary = {
		"current_target": null,
		"movement_blocked": mb_r == state.round_number,
		"has_moved": false,
		"seeking_failed": false,
		"weapon_action_taken": false,
		"blocked_targets": {},
		"pool_move_cell": Vector3i(-9999, -9999, -9999),
		"action_slot": 0,
		"stop": false,
	}
	StateReliefEvaluator.clear_aid_cache()
	if state.battlefield != null:
		state.turn_ally_passable.erase(merc)
		state.turn_path_dist.clear()
		state.ally_passable_3d(merc)
		MovementExecutor._turn_path_cache.erase(merc)
	return turn


static func _execute_turn(merc: MercenaryData, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	var enhancements := _begin_turn(merc, state, lines)
	var skip_actions := process_start_of_turn_states(merc, state, lines)
	if not skip_actions and state.cave_in_buried.has(merc):
		lines.append_array(CaveInSystem.buried_turn(merc, state, enhancements))
		skip_actions = true
	if not skip_actions and KidnapSystem.start_of_turn(merc, state, lines):
		KidnapSystem.run_turn(merc, state, lines, enhancements)
		skip_actions = true
	if not skip_actions and FleeSystem.start_of_turn(merc, state, lines):
		FleeMover.run_turn(merc, state, lines, enhancements)
		skip_actions = true
	if not skip_actions and RescueSystem.start_of_turn(merc, state, lines):
		skip_actions = RescueSystem.run_turn(merc, state, lines, enhancements)

	#spend:ep:1:ap_cost_attack:-1:until_turn_end (Longbow Quick-Shot)
	merc.active_states.erase("attack_ap_reduction")
	if not skip_actions:
		for _qs_perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
			if "ap_cost_attack:-1:until_turn_end" in _qs_perk.effect_dsl:
				var _qs_cost := CombatApplicator.state_ep_cost(merc, 1, "reaction", 0)
				var _qs_amount := 2 if WeaponArmorPerkLibrary.is_level_20(merc) else 1
				if _qs_cost > 0 and ExcessPool.available_ep(merc) >= _qs_cost \
						and PerkValuation.quick_shot_worth(merc, state, _qs_amount, _qs_cost):
					ExcessPool.pay_ep(merc, _qs_cost)
					merc.active_states["attack_ap_reduction"] = int(
						merc.active_states.get("attack_ap_reduction", 0)) + _qs_amount
					lines.append("  %s activates Quick-Shot (-%d AP attacks)." % [
						BattleState.colored_name(merc, state), _qs_amount])
				break

	var weapon_action_taken := false
	if not skip_actions:
		var turn: Dictionary = new_turn(merc, state)
		var had_valid_targets := false
		var _action_slot := 0

		while true:
			if merc.off_field:
				break
			_action_slot += 1
			if _action_slot > 50:
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("WARNING: action slot cap reached - ending turn")
				break
			if merc.current_ap <= 0 and merc.excess_ap <= 0 and state.get_pace_pool(merc) <= 0:
				break
			var _cheapest := ActionDispatcher.cheapest_action_cost(merc, state)
			if _cheapest > 0 and state.get_pace_pool(merc) <= 0 and not state.can_afford(merc, _cheapest):
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("SLOT %d: AP %d below cheapest affordable action (cost %d), banking" % [
						_action_slot, state.spendable_ap(merc), _cheapest])
				break
			await _yield_if_due()
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("-- ACTION SLOT %d (AP=%d ExAP=%d pool=%d) --" % [
					_action_slot, merc.current_ap, merc.excess_ap, state.get_pace_pool(merc)])
			#Threatened and Flanked follow the positions as they stand before each action.
			lines.append_array(BattleStateUpdater.update_auto_states(merc, state))
			var enemies := state.get_enemies(merc)
			if enemies.is_empty():
				break

			var current_target: MercenaryData = turn["current_target"]
			if current_target != null and not enemies.has(current_target):
				merc.last_seen_position = Vector3i(-1, -1, -1)
				current_target = null
				turn["current_target"] = null

			var valid_targets: Array[MercenaryData] = []
			for e: MercenaryData in enemies:
				if can_attack_target(merc, e, state):
					valid_targets.append(e)

			if not valid_targets.is_empty():
				had_valid_targets = true

			if state.battlefield != null:
				for k: MercenaryData in merc.last_known_enemy_positions.keys():
					if not enemies.has(k):
						merc.last_known_enemy_positions.erase(k)
				for e: MercenaryData in valid_targets:
					merc.last_known_enemy_positions[e] = state.pos3(e)

			if EncounterLogger.is_active() and valid_targets.is_empty() and not enemies.is_empty():
				_log_no_valid_targets(merc, enemies, state)

			var allies := state.get_allies(merc)

			#All enemies proven unreachable this turn and nothing in attack range; end turn
			var _stuck_alone: bool = ActionDispatcher.is_desperate(merc, state)
			var blocked_targets: Dictionary = turn["blocked_targets"]
			if valid_targets.is_empty() and (
					(not blocked_targets.is_empty() and blocked_targets.size() >= enemies.size())
					or (bool(turn["movement_blocked"]) and not _stuck_alone)):
				break

			var perk_action := ActionDispatcher.choose_perk_action(merc, current_target, state, not valid_targets.is_empty())
			if not perk_action.is_empty():
				#D4: the perk action has to beat what the same AP would buy as a plain attack.
				var _plain_target: MercenaryData = current_target if valid_targets.has(current_target) else null
				if PerkValuation.beats_attack(merc, perk_action, _plain_target, state, enhancements,
						int(merc.active_states.get("attack_ap_reduction", 0))):
					var perk_lines := PerkActionExecutor.execute_perk_action(
						merc, perk_action["perk"] as TraitData, current_target, state, enhancements)
					if not perk_lines.is_empty():
						_count_action_use(merc, {
							"action_name": (perk_action["perk"] as TraitData).trait_name,
							"type": "perk"})
						lines.append_array(perk_lines)
						continue
				elif EncounterLogger.is_active():
					EncounterLogger.log_verbose("PERK ACTION SKIP: %s per_ap=%.2f below a plain attack" % [
						merc.merc_name, float(perk_action["score_per_ap"])])

			var decision := ActionDispatcher.choose_from_action_set(
				merc, enemies, valid_targets, allies, current_target, state, bool(turn["movement_blocked"]),
				bool(turn["weapon_action_taken"]), bool(turn["has_moved"]), bool(turn["seeking_failed"]), blocked_targets)

			decision = RescueSystem.adjust_decision(merc, decision, state, turn, lines)
			_count_action_use(merc, decision)

			turn["action_slot"] = _action_slot
			if not _run_slot(merc, decision, state, enhancements, turn, lines):
				break
			if bool(turn["stop"]):
				break

		weapon_action_taken = turn["weapon_action_taken"]
		if had_valid_targets:
			state.no_target_turns.erase(merc)
		else:
			state.no_target_turns[merc] = state.no_target_turns.get(merc, 0) + 1

	_end_turn(merc, state, lines, weapon_action_taken)
	return lines


#Turn-start resets, deferred effects, perk window expiry and the turn header; returns the enhancements.
static func _begin_turn(merc: MercenaryData, state: BattleState, lines: Array[String]) -> int:
	state.start_of_turn(merc)
	TraitRuntime.on_turn_start(merc, state, lines)
	merc.combat_idle_rounds += 1
	#Drain deferred effects queued for this merc's turn start (e.g. Dagger Bleedout)
	var _remaining_effects: Array = []
	for _eff in merc.deferred_effects:
		if _eff["timing"] == "self_turn_start":
			var _tgt := _eff["target"] as MercenaryData
			if BattleState._is_alive(_tgt):
				lines.append_array(CombatApplicator.apply_damage(merc, _tgt, _eff["damage"], _eff["type"], state))
		else:
			_remaining_effects.append(_eff)
	merc.deferred_effects = _remaining_effects
	if merc.weapon_misfired and EncounterLogger.is_active():
		EncounterLogger.log_verbose("  [MISFIRE RESET] %s: weapon_misfired cleared at turn start" % merc.merc_name)
	merc.weapon_misfired = false
	if StateEffects.is_blocked(merc, "spend:ap"):
		merc.current_ap = 0
		merc.excess_ap = 0
		merc.ap_debt = 0
	merc.active_states.erase("blocked_pickup_pos")
	#Perk windows that say "until the start of your next turn" close here.
	if state.round_number >= int(merc.active_states.get("reach_bonus_until_round", 99999)):
		merc.active_states.erase("reach_bonus_until_round")
		var _reach_left := int(merc.active_states.get("weapon_stat_melee_range_bonus", 0)) - 1
		if _reach_left > 0:
			merc.active_states["weapon_stat_melee_range_bonus"] = _reach_left
		else:
			merc.active_states.erase("weapon_stat_melee_range_bonus")
	if state.round_number >= int(merc.active_states.get("weapon_extend_until_round", 99999)):
		merc.active_states.erase("weapon_extend_until_round")
		merc.active_states.erase("weapon_extend_active")
	if state.round_number >= int(merc.active_states.get("rampage_until_round", 99999)):
		merc.active_states.erase("rampage_until_round")
		merc.active_states.erase("rampage_bonus")
	merc.active_states.erase("oppress_target")
	merc.active_states.erase("oppress_until_round")
	RescueSystem.on_turn_reset(merc, state)
	merc.turn_attacks.clear()
	merc.turn_attack_total = 0
	merc.turn_weapon_attacks.clear()
	_prune_last_target(merc, state)

	var enhancements: int = maxi(0, state.round_number - 1)
	var excess_str := "  ExAP:[color=purple]%d[/color]" % merc.excess_ap if merc.excess_ap > 0 else ""
	excess_str += ExcessPool.header(merc)
	var enh_str := "  Enh:[color=cyan]%d[/color]" % enhancements if enhancements > 0 else ""
	var pos_str := ""
	if state.battlefield != null:
		var p := state.get_position(merc)
		var h := state.absolute_height(merc)
		pos_str = "  [color=orange](%d,%d h%d F%d)[/color]" % [p.x, p.y, h, state.get_floor(merc)]
	EncounterLogger.log_line("%s  HP:[color=red]%d[/color]  EP:[color=green]%d[/color]%s%s%s" % [
		BattleState.colored_name(merc, state), maxi(0, merc.current_hp), merc.current_ep, excess_str, enh_str, pos_str])

	if EncounterLogger.is_active():
		var _log_w := merc.equipped_weapon
		if _log_w != null:
			var _log_wtype := "ranged" if _log_w.is_ranged else ("throwable" if _log_w.is_throwable else "melee")
			var _log_ammo := " [%dc+%dr %s]" % [merc.ammo_loaded, merc.ammo_inventory.get(merc.ammo_loaded_type, 0), merc.ammo_loaded_type] if _log_w.is_ranged else ""
			var _log_oh := " offhand=%s" % merc.offhand_weapon.item_name if merc.offhand_weapon != null else ""
			EncounterLogger.log_verbose("WEAPON: %s (%s) range=%d dmg=%s%s%s" % [
				_log_w.item_name, _log_wtype,
				_log_w.ranged_intended_range if _log_w.is_ranged else _log_w.melee_range,
				_log_w.damage_formula_1, _log_ammo, _log_oh])
		else:
			EncounterLogger.log_verbose("WEAPON: unarmed")
		EncounterLogger.log_verbose("STATS: melee_acc=%.0f%% ranged_acc=%.0f%% pace=%d pain_limit=%d" % [
			float(merc.stats.get("melee_accuracy", 0.0)),
			float(merc.stats.get("ranged_accuracy", 0.0)),
			int(merc.stats.get("pace", 1)),
			int(merc.stats.get("pain_limit", 0))])
	return enhancements


#Runs the arm the decision names; false when no action passed its threshold and the turn ends.
static func _run_slot(merc: MercenaryData, decision: Dictionary, state: BattleState, enhancements: int,
		turn: Dictionary, lines: Array[String]) -> bool:
	match decision["type"]:
		"move":
			lines.append_array(MovementExecutor.run_move_arm(merc, decision, state, enhancements, turn))
		"jump":
			lines.append_array(MovementExecutor.run_jump_arm(merc, decision, state, enhancements, turn))
		"climb":
			lines.append_array(MovementExecutor.run_climb_arm(merc, decision, state, turn))
		"special":
			lines.append_array(ActionDispatcher.run_special_arm(merc, decision, state, enhancements, turn))
		"reload":
			lines.append_array(WeaponActionExecutor.run_reload_arm(merc, state, enhancements, turn))
		"repair":
			lines.append_array(WeaponActionExecutor.run_repair_arm(merc, state, turn))
		"attack":
			decision = CalledShotOdds.upgrade(merc, decision, state, enhancements)
			lines.append_array(AttackArm.run_attack_arm(merc, decision, state, enhancements,
				int(merc.active_states.get("attack_ap_reduction", 0)), turn))
		"draw":
			lines.append_array(WeaponActionExecutor.run_draw_arm(merc, decision, state, enhancements, turn))
		"holster":
			lines.append_array(WeaponActionExecutor.run_holster_arm(merc, state, turn))
		"drop":
			lines.append_array(WeaponActionExecutor.run_drop_arm(merc, decision, state, enhancements, turn))
		"pickup":
			lines.append_array(WeaponActionExecutor.run_pickup_arm(merc, decision, state, turn))
		"move_to_pickup":
			lines.append_array(MovementExecutor.run_move_to_pickup_arm(merc, decision, state, enhancements, turn))
		"move_to_obstacle":
			lines.append_array(MovementExecutor.run_move_to_obstacle_arm(merc, decision, state, enhancements, turn))
		"rescue_retry":
			pass
		_:
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("SLOT %d: no action passed its threshold, banking %d AP" % [
					int(turn["action_slot"]), state.spendable_ap(merc)])
			return false
	return true


#Whip Choke and the end-of-turn bookkeeping that close the merc's turn.
static func _end_turn(merc: MercenaryData, state: BattleState, lines: Array[String],
		weapon_action_taken: bool) -> void:
	#Whip Choke: spend:ap:1:direct:1:grappled_target; spend 1 AP for 1 Direct damage to whip-grappled target
	lines.append_array(ActionDispatcher.do_whip_choke_ap_spend(merc, state))

	merc.active_states.erase("attack_ap_reduction")
	#Great Axe Overextension holds its pace of reach open until the merc's next turn start.
	if not merc.active_states.has("reach_bonus_until_round"):
		merc.active_states.erase("weapon_stat_melee_range_bonus")
	merc.active_states.erase("thrown_extended_range_bonus")
	if merc.temp_rep > 0:
		merc.current_rep -= mini(merc.current_rep, merc.temp_rep)
		merc.temp_rep = 0
	FleeSystem.hold(merc, state)
	lines.append_array(StateInfliction.end_of_turn(merc, state))
	state.end_of_turn(merc, weapon_action_taken)
	if merc.excess_ap > 0:
		lines.append("  %s +[color=purple]%d[/color] ExAP" % [BattleState.colored_name(merc, state), merc.excess_ap])
	lines.append("")


#Verbose only: names why each enemy failed the attack test when nothing could be targeted.
static func _log_no_valid_targets(merc: MercenaryData, enemies: Array[MercenaryData],
		state: BattleState) -> void:
	for e: MercenaryData in enemies:
		EncounterLogger.log_verbose("NO_VALID_TARGET: %s rejected %s - %s" % [
			merc.merc_name, e.merc_name, _attack_block_reason(merc, e, state)])


#Tallies the action the merc chose by its action_name, for the Merc Viewer's times used column.
static func _count_action_use(merc: MercenaryData, decision: Dictionary) -> void:
	var name: String = String(decision.get("action_name", ""))
	var type: String = String(decision.get("type", ""))
	if name == "" or type == "pass" or type == "none" or type == "rescue_retry":
		return
	merc.action_uses[name] = int(merc.action_uses.get(name, 0)) + 1


static func process_start_of_turn_states(merc: MercenaryData, state: BattleState, lines: Array[String]) -> bool:
	merc.advantage_immune = false
	var skip_states: Array[String] = _skip_turn_states(merc)
	if not skip_states.is_empty():
		lines.append("  %s is %s and cannot act!" % [
			BattleState.colored_name(merc, state), skip_states[0].to_lower()])
		for skip_name: String in skip_states:
			if state.get_state_timer(merc, skip_name).is_empty():
				StateCascade.remove_state(merc, skip_name)
				StateInfliction.note_removed(merc, skip_name, state, "time")
		return true

	if ConstStates.has_state(merc, ConstStates.DYING):
		run_death_test(merc, state, lines)
		return ConstStates.has_state(merc, ConstStates.DYING) or merc.is_dead

	lines.append_array(CavernRules.breath_turn_start(merc, state))
	lines.append_array(BattleStateUpdater.apply_dot_effects(merc, state))

	if not merc.off_field and StateEffects.is_blocked(merc, "action:all"):
		lines.append("  %s is %s and cannot act!" % [
			BattleState.colored_name(merc, state), _all_block_state(merc).to_lower()])
		return true
	return merc.off_field


#The held state whose block token stops every action; "shocked" when none names itself.
static func _all_block_state(merc: MercenaryData) -> String:
	for effect: Dictionary in StateEffects.active_effects(merc, "block"):
		var token: String = str(effect["token"])
		if token.begins_with("block:action:all"):
			return str(effect["state"])
	return "shocked"


#Names of the held states that carry skip_turn, in the order the merc holds them.
static func _skip_turn_states(merc: MercenaryData) -> Array[String]:
	var out: Array[String] = []
	for effect: Dictionary in StateEffects.active_effects(merc, "skip_turn"):
		var state_name: String = str(effect["state"])
		if not out.has(state_name):
			out.append(state_name)
	return out


static func run_death_test(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	var max_hp := int(merc.stats.get("maximum_hit_points", 1))
	var effective_max: int = max_hp - merc.death_test_hp_loss - merc.rot_hp_loss - merc.suffocation_hp_loss
	var killer: MercenaryData = state.dying_source.get(merc, null)
	if effective_max <= 0:
		BattleStateUpdater.kill(merc, killer, state, lines, "  %s dies!" % BattleState.colored_name(merc, state),
			"DEATH CONFIRMED: %s - max HP exhausted by death test failures" % merc.merc_name, false)
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
	LifepathTally.record_cheat_death(merc, successes, any_success)
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("CHEAT DEATH ROLL (%s): rolls=%s vs %.0f%% -> %d success %d fail -> %s" % [
			BattleState.colored_name(merc, state), str(rolls), cheat_death,
			successes, new_failures,
			"PASS" if any_success else "FAIL"])
	merc.death_test_hp_loss += new_failures
	if any_success:
		merc.current_hp = 1
		StateCascade.remove_state(merc, ConstStates.DYING)
		StateInfliction.note_removed(merc, ConstStates.DYING, state, "death_test")
		state.dying_source.erase(merc)
		lines.append("  %s makes a miraculous recovery!" % BattleState.colored_name(merc, state))
	else:
		var new_effective: int = max_hp - merc.death_test_hp_loss - merc.rot_hp_loss - merc.suffocation_hp_loss
		if new_effective <= 0:
			BattleStateUpdater.kill(merc, killer, state, lines, "  %s dies!" % BattleState.colored_name(merc, state),
				"DEATH CONFIRMED: %s - cheat death failed, max HP exhausted (total failures=%d)" % [
					merc.merc_name, merc.death_test_hp_loss], false)
		else:
			lines.append("  %s is still dying! (Max HP reduced to %d)" % [BattleState.colored_name(merc, state), new_effective])


static func can_attack_target(
		attacker: MercenaryData,
		target: MercenaryData,
		state: BattleState) -> bool:
	return _attack_block_reason(attacker, target, state, true) == ""


#Why attacker cannot attack target now, empty when it can; log_checks writes the RANGE CHECK verbose line.
static func _attack_block_reason(attacker: MercenaryData, target: MercenaryData, state: BattleState,
		log_checks: bool = false) -> String:
	if RescueSystem.shelters(state, target):
		return "sheltered"
	if state.battlefield == null:
		return ""
	var weapon := attacker.equipped_weapon
	var dist := state.distance_to(attacker, target)
	var melee_range := WeaponArmorPerkLibrary.melee_reach(attacker)
	var mode := "melee"
	if weapon != null and weapon.is_ranged:
		mode = "ranged" if attacker.ammo_loaded > 0 else "no_ammo_melee"
	elif weapon != null and weapon.is_throwable and dist > melee_range:
		mode = "thrown"
	var los: Dictionary = LineOfSight.check(state, attacker, target)
	if not (los["visible"] as bool):
		_log_range_check(log_checks, attacker, target, dist, 0, mode, "no_los")
		var floors := ""
		if state.get_floor(attacker) != state.get_floor(target):
			floors = " floor a=%d t=%d" % [state.get_floor(attacker), state.get_floor(target)]
		return "no_los blocker=%s%s" % [str(los["blocker"]), floors]
	if weapon == null:
		_log_range_check(log_checks, attacker, target, dist, MELEE_RANGE, "melee",
			"OK" if dist <= MELEE_RANGE else "out_of_range")
		if dist <= MELEE_RANGE:
			return ""
		return "out_of_range dist=%d range=%d" % [dist, MELEE_RANGE]
	if weapon.string_snapped:
		_log_range_check(log_checks, attacker, target, dist, 0, mode, "string_snapped")
		return "string_snapped"
	if weapon.is_ranged:
		if attacker.ammo_loaded <= 0:
			_log_range_check(log_checks, attacker, target, dist, melee_range, "no_ammo_melee",
				"OK" if dist <= melee_range else "out_of_range")
			return "" if dist <= melee_range else "no_ammo"
		if attacker.weapon_misfired:
			_log_range_check(log_checks, attacker, target, dist, 0, "ranged", "misfired")
			return "misfired"
		var r_bands := WeaponArmorPerkLibrary.ranged_ranges(attacker, weapon)
		var ranged_range: int = int(r_bands["extended"])
		#An overcharged shell cannot reach past the intended band.
		if bool(attacker.active_states.get("shotgun_overcharged", false)):
			ranged_range = int(r_bands["intended"])
		var ranged_ok: bool = ranged_range <= 0 or dist <= ranged_range
		_log_range_check(log_checks, attacker, target, dist, maxi(0, ranged_range), "ranged",
			"OK" if ranged_ok else "out_of_range")
		if ranged_ok:
			return ""
		return "out_of_range dist=%d intended=%d max=%d" % [dist, int(r_bands["intended"]), ranged_range]
	if weapon.is_throwable:
		if dist <= melee_range:
			_log_range_check(log_checks, attacker, target, dist, melee_range, "melee", "OK")
			return ""
		var t_ranges := ThrownWeaponRules.thrown_ranges(attacker, weapon)
		var throw_ext: int = int(t_ranges["extended"])
		var throw_max: int = throw_ext
		if throw_max > 0:
			throw_max += WeaponArmorPerkLibrary.perk_throw_bonus(attacker)
		var throw_ok: bool = throw_max > 0 and dist <= throw_max
		_log_range_check(log_checks, attacker, target, dist, maxi(0, throw_max), "thrown",
			"OK" if throw_ok else "out_of_range")
		if throw_ok:
			return ""
		if throw_ext > 0:
			return "out_of_throw_range dist=%d intended=%d max=%d" % [dist, int(t_ranges["intended"]), throw_ext]
		return "no_throw_plan dist=%d max=%d" % [dist, throw_ext]
	if dist > melee_range and ThrownWeaponRules.object_throw_allowed(attacker, weapon, target, state) \
			and bool(ThrownWeaponRules.should_throw(
				attacker, weapon, target, state.get_enemies(attacker), state, false)["throw"]):
		_log_range_check(log_checks, attacker, target, dist,
			int(ThrownWeaponRules.thrown_ranges(attacker, weapon)["extended"]), "object_throw", "OK")
		return ""
	_log_range_check(log_checks, attacker, target, dist, melee_range, "melee",
		"OK" if dist <= melee_range else "out_of_range")
	if dist <= melee_range:
		return ""
	return "out_of_range dist=%d range=%d" % [dist, melee_range]


static func _log_range_check(enabled: bool, attacker: MercenaryData, target: MercenaryData, dist: int,
		range_paces: int, mode: String, result: String) -> void:
	if not enabled or not EncounterLogger.is_active():
		return
	EncounterLogger.log_verbose("RANGE CHECK: %s->%s dist=%d vs range=%d mode=%s - %s" % [
		attacker.merc_name, target.merc_name, dist, range_paces, mode, result])


#Drops last_target at turn start once that merc is gone from the live enemy list.
static func _prune_last_target(merc: MercenaryData, state: BattleState) -> void:
	var last: MercenaryData = merc.active_states.get("last_target") as MercenaryData
	if last == null:
		return
	for enemy: MercenaryData in state.get_enemies(merc):
		if enemy == last and BattleState._is_alive(enemy):
			return
	merc.active_states.erase("last_target")
