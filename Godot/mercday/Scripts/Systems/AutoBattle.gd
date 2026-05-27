class_name AutoBattle

const ATTACK_BASE_AP := 3
const MOVE_BASE_AP := 2
const DRAW_BASE_AP := 0   # base is 0; actual cost = weapon.draw via get_cost()
const MELEE_RANGE := 1
const MAX_ROUNDS := 100

static var _stale_rounds: int = 0


static func run_battle(state: BattleState, line_fn: Callable = Callable(), encounter_type: String = "encounter") -> Dictionary:
	setup(state, line_fn, encounter_type)
	while step_round(state, line_fn):
		pass
	return {"winner": state.get_winner(), "rounds": state.round_number}


# Emits the battlefield header/visual and begins the encounter logger.
# Call once before the first step_round().
static func setup(state: BattleState, line_fn: Callable = Callable(), encounter_type: String = "encounter") -> void:
	_stale_rounds = 0
	EncounterLogger.begin(encounter_type, state)
	if state.battlefield != null:
		_emit(line_fn, "[color=gray]%s[/color]" % state.battlefield.to_header_string())
		_emit(line_fn, state.battlefield.to_visual_string())
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
	for merc: MercenaryData in state.turn_queue:
		if not BattleState._is_alive(merc):
			continue
		if state.is_battle_over():
			break
		if ConstStates.has_state(merc, ConstStates.DYING):
			for line: String in _execute_dying_turn(merc, state):
				_emit(line_fn, line)
		else:
			for line: String in _execute_turn(merc, state):
				_emit(line_fn, line)
	if state.is_battle_over() or state.round_number >= MAX_ROUNDS:
		_finalize(state, line_fn)
		return false
	var any_acted := false
	for merc: MercenaryData in state.turn_queue:
		if not BattleState._is_alive(merc):
			continue
		if not (state.escalation.get(merc, {}) as Dictionary).is_empty():
			any_acted = true
			break
	if not any_acted:
		_stale_rounds += 1
		if _stale_rounds >= 2:
			_emit(line_fn, "[color=red]Error: no actions taken for 2 consecutive rounds — stalemate.[/color]")
			_finalize(state, line_fn)
			return false
	else:
		_stale_rounds = 0
	return true


static func _finalize(state: BattleState, _line_fn: Callable) -> void:
	if not state.dropped_weapons.is_empty():
		for team in state.teams:
			for merc: MercenaryData in team:
				state.retrieve_dropped_weapons_for(merc)
	var result := {"winner": state.get_winner(), "rounds": state.round_number}
	EncounterLogger.end(result)


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

	if EncounterLogger.is_active():
		var _log_w := merc.equipped_weapon
		if _log_w != null:
			var _log_wtype := "ranged" if _log_w.is_ranged else ("throwable" if _log_w.is_throwable else "melee")
			var _log_ammo := " [%d/%d %s]" % [merc.ammo_loaded, _log_w.chamber, merc.ammo_loaded_type] if _log_w.is_ranged else ""
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

	if not skip_actions:
		var current_target: MercenaryData = null
		var movement_blocked := false
		var weapon_action_taken := false
		var _action_slot := 0

		while true:
			_action_slot += 1
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("-- ACTION SLOT %d (AP=%d ExAP=%d) --" % [
					_action_slot, merc.current_ap, merc.excess_ap])
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

			# Check perk-defined actions first
			var perk_action := _choose_perk_action(merc, current_target, state)
			if perk_action != null:
				var perk_lines := _execute_perk_action(merc, perk_action, current_target, state, enhancements)
				if not perk_lines.is_empty():
					lines.append_array(perk_lines)
					continue

			var decision := _choose_from_action_set(
				merc, enemies, valid_targets, allies, current_target, state, movement_blocked, weapon_action_taken)

			match decision["type"]:
				"move":
					var move_lines := _execute_move(merc, decision["action_name"], decision["target"], state,
						decision.get("flank_ally"), enhancements, decision.get("move_stop_dist", -1))
					if move_lines.is_empty():
						movement_blocked = true
					else:
						lines.append_array(move_lines)
						movement_blocked = false
						current_target = decision["target"]
				"special":
					var spec_lines := _execute_special(merc, decision["action_name"], state, enhancements, decision.get("target"))
					lines.append_array(spec_lines)
					if spec_lines.is_empty():
						break
				"reload":
					var reload_lines := _execute_reload(merc, state, enhancements)
					if reload_lines.is_empty():
						break
					lines.append_array(reload_lines)
				"attack":
					current_target = decision["target"]
					state.last_attacked[merc] = current_target
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
					var atk := AttackSystem.execute_attack(merc, enhancements + aim_bonus + weapon_enh, atk_flaws, current_target)
					merc.aim_active = false
					state.spend_ap(merc, atk_cost)
					state.record_action(merc, "Attack")
					if EncounterLogger.is_active() and not atk.get("misfired", false) and not atk.get("no_ammo", false):
						var cr: Dictionary = atk["check_result"]
						EncounterLogger.log_verbose("ATTACK ROLL: %s vs %.0f%% -> %d hit %d miss  dmg=%d %s" % [
							str(cr["roll2"]), cr["threshold"],
							cr["successes"], cr["failures"],
							atk["damage"], atk["damage_type"]])
					if atk.get("misfired", false):
						lines.append("  %s misfires!" % _cn(merc, state))
					elif atk.get("no_ammo", false):
						lines.append("  %s has no ammo loaded!" % _cn(merc, state))
						break
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
						# on_hit: weapon perk dispatch — runs before normal _apply_damage
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
						# spend:rep:1:reload_free (Blowgun Quick Reload) — after hit
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
											lines.append("  %s reloads for free (1 ReP)!" % _cn(merc, state))
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
							current_target = null
					else:
						lines.append("  %s misses against %s." % [_cn(merc, state), _cn(current_target, state)])
						# spend:rep:1:reload_free (Blowgun Quick Reload) — also triggers on miss
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
											lines.append("  %s reloads for free (1 ReP)!" % _cn(merc, state))
								break
						lines.append_array(_fire_weapon_reactive(merc, "on_miss", current_target, atk, state, enhancements))
					lines.append_array(_fire_weapon_reactive(merc, "after_attack", current_target, atk, state, enhancements))
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

	# Whip Choke: spend:ap:1:direct:1:grappled_target — spend 1 AP for 1 Direct damage to whip-grappled target
	lines.append_array(_do_whip_choke_ap_spend(merc, state))

	state.end_of_turn(merc)
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
		target: MercenaryData = null) -> Array[String]:
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
	return lines


static func _do_seek_cover(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	if state.battlefield == null:
		return
	var merc_pos := state.get_position(merc)
	var raw_obs := state.battlefield.get_adjacent_obstacles(merc_pos)
	var adj_obs: Array[Dictionary] = []
	for obs: Dictionary in raw_obs:
		if not (obs.get("cell_type", "") == "door" and obs.get("door_open", false)):
			adj_obs.append(obs)
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
	var obs_data: ObstacleData = best_obs.get("data") as ObstacleData
	var is_narrow: bool = obs_data != null and obs_data.narrow
	var cover_type: String = ConstStates.COVERED_PARTIAL if is_narrow \
		else (ConstStates.COVERED_FULL if obs_size > merc_size else ConstStates.COVERED_PARTIAL)
	state.set_cover(merc, obs_pos, obs_size, cover_type)
	var covered_names: Array[String] = []
	for enemy: MercenaryData in ranged_enemies:
		if state.is_covered_from(merc, enemy, cover_type):
			covered_names.append(_cn(enemy, state))
	var vs_str := ", ".join(covered_names) if not covered_names.is_empty() else "no ranged enemies"
	var obs_name: String = obs_data.obstacle_name if obs_data != null else "obstacle"
	lines.append("  %s takes cover behind %s (%s) vs %s." % [_cn(merc, state), obs_name, cover_type, vs_str])


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


static func _do_forcible_move(
		shover: MercenaryData,
		shoved: MercenaryData,
		paces: int,
		state: BattleState) -> Array[String]:
	var lines: Array[String] = []
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
#       Currently no code in AutoBattle initiates GRAPPLED state; this is the planned entry point.
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
		stop_dist_override: int = -1) -> Array[String]:
	if move_target == null:
		return []

	var old_pos := state.get_position(merc)
	var goal := _compute_move_position(merc, move_target, action_name, state, flank_ally, stop_dist_override)
	var new_pos := goal
	var path_harms: Array[Dictionary] = []
	var field := state.battlefield
	if field != null:
		goal = _nearest_passable_to(goal, field)
		var path := Pathfinder.find_path(old_pos, goal, field)
		if path.is_empty():
			new_pos = old_pos
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("MOVE BLOCKED: no path (%d,%d)->(%d,%d)" % [
					old_pos.x, old_pos.y, goal.x, goal.y])
		elif path.size() > 1:
			var pace := maxi(1, int(merc.stats.get("pace", 1)))
			if ConstStates.has_state(merc, ConstStates.DEPOSED):
				pace = mini(pace, 1)
			var budget := pace
			var last := old_pos
			var traversed: Array[Vector2i] = [old_pos]
			for i: int in range(1, path.size()):
				var cell: Vector2i = path[i]
				var cost := Pathfinder.cell_pace_cost(path[i - 1], cell, field)
				if cost < 0 or budget - cost < 0:
					break
				budget -= cost
				last = cell
				traversed.append(cell)
				var path_obs: Dictionary = field.get_obstacle_at(cell)
				if not path_obs.is_empty():
					var d: ObstacleData = path_obs.get("data") as ObstacleData
					if d != null and d.passthrough and d.passthrough_enter_harm > 0:
						path_harms.append({"damage": d.passthrough_enter_harm, "type": d.passthrough_harm_type, "name": d.obstacle_name})
			new_pos = last
			if EncounterLogger.is_active() and traversed.size() > 1:
				var parts: Array[String] = []
				for c: Vector2i in traversed:
					parts.append("(%d,%d)" % [c.x, c.y])
				EncounterLogger.log_verbose("MOVE PATH: %s  budget %d/%d used" % [
					" -> ".join(parts), pace - budget, pace])

	if new_pos == old_pos:
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
	state.set_position(merc, new_pos)
	merc.aim_active = false
	state.clear_cover(merc)

	# Sync battle height to terrain elevation
	if field != null:
		state.set_height(merc, int(round(field.get_terrain_height(new_pos))))

	# Fall detection for terrain drop-offs (normally blocked by pathfinder, edge-case guard)
	if field != null:
		var terrain_drop := field.get_terrain_height(old_terrain_pos) - field.get_terrain_height(new_pos)
		if terrain_drop >= 1.0:
			move_lines.append_array(_resolve_fall(merc, int(floor(terrain_drop)), state))

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
	lines.append("  %s attempts to Break their Fall! [%s Check: %d success%s]" % [
		_cn(merc, state), formula_label, successes, "es" if successes != 1 else ""])
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
	var threshold := clampf(formula_val + circ_bonus + bsc, 0.0, 100.0)
	var p_reroll := clampf(float(merc.stats.get("reroll", 0.0)) / 100.0, 0.0, 1.0)
	var p_base := threshold / 100.0
	var p_eff := p_base + (1.0 - p_base) * p_reroll * p_base
	return (maxi(1, int(merc.stats.get(stat_key, 0))) + k_bonus) * p_eff


static func _compute_move_position(
		merc: MercenaryData,
		move_target: MercenaryData,
		action_name: String,
		state: BattleState,
		flank_ally: MercenaryData = null,
		stop_dist_override: int = -1) -> Vector2i:
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
	if stop_dist_override >= 0:
		stop_dist = stop_dist_override
	else:
		var weapon := merc.equipped_weapon
		if weapon != null:
			if not weapon.is_ranged:
				stop_dist = weapon.melee_range
			elif weapon.ranged_intended_range > 0:
				if action_name == "Move Close" and CombatDecision.is_melee_preferred(merc):
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


# Returns `pos` if it is passable from any cardinal neighbour, otherwise
# searches outward in expanding rings (max radius 3) for the nearest cell
# that can be entered.  Keeps goal-redirect cheap while handling walls,
# closed doors, and steep terrain that _compute_move_position ignores.
static func _nearest_passable_to(pos: Vector2i, field: BattlefieldArea) -> Vector2i:
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
			if Pathfinder.cell_pace_cost(nb, cell, field) >= 0:
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
		# TODO: wire extended range check here — thrown_extended_range_bonus extends the no-flaw zone
		var thrown_range_bonus: int = attacker.active_states.get("thrown_extended_range_bonus", 0)
		if dist > weapon.thrown_intended_range + thrown_range_bonus and not ignore_ext_range:
			return 1
	return 0


static func _execute_reload(merc: MercenaryData, state: BattleState, enhancements: int = 0) -> Array[String]:
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
	var lines: Array[String] = ["  %s reloads. (%d in chamber, %d remaining)" % [_cn(merc, state), merc.ammo_loaded, remaining]]
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
	var lines: Array[String] = ["  %s draws %s. (AP: %d)" % [_cn(merc, state), weapon.item_name, draw_cost]]
	lines.append_array(_fire_weapon_reactive(merc, "on_draw", null, {}, state, enhancements))
	return lines


static func _execute_holster(merc: MercenaryData, state: BattleState) -> Array[String]:
	var weapon := merc.equipped_weapon
	if weapon == null or not merc.weapon_drawn:
		return []
	var cost := state.get_cost(merc, "Holster", _get_draw_cost(merc, weapon))
	if not state.can_afford(merc, cost):
		return []
	merc.inventory.append({"type": "weapon", "data": weapon})
	merc.equipped_weapon = null
	merc.weapon_drawn = false
	state.spend_ap(merc, cost)
	state.record_action(merc, "Holster")
	return ["  %s holsters %s. (AP: %d)" % [_cn(merc, state), weapon.item_name, cost]]


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
		var thrown_range_bonus: int = attacker.active_states.get("thrown_extended_range_bonus", 0)
		return weapon.thrown_extended_range <= 0 or dist <= weapon.thrown_extended_range + thrown_range_bonus
	return dist <= WeaponArmorPerkLibrary.get_effective_melee_range(attacker)


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
	var defended: bool = res["ep_spent"] > 0
	var res_type := "ExAP" if used_excess_ap else "EP"
	var res_amount: int = excess_needed if used_excess_ap else res["ep_spent"]

	lines.append("  %s [color=red][%d][/color] %s v %s" % [atk_name, in_dmg, damage_type, def_name])
	if defended or used_excess_ap:
		var def_label := "Dodge" if res.get("reduction_source", "") == "dodge" else "Defend"
		lines.append("  %s -%d %s, %s [color=red][%d][/color]" % [def_name, res_amount, res_type, def_label, in_dmg - final_dmg])
	if final_dmg > 0:
		lines.append("  %s: HP [color=red]%d[/color]" % [def_name, defender.current_hp])
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("HP RESULT: %s hp=%d (final_dmg=%d free_def=%s)" % [
				defender.merc_name, defender.current_hp, final_dmg, str(free_def)])

	var pain_limit := int(defender.stats.get("pain_limit", 0))
	if not was_dying and pain_limit > 0 and final_dmg >= pain_limit:
		var num_checks := 1 + (final_dmg - pain_limit)
		lines.append_array(_apply_pain_limit_checks(defender, num_checks, def_name))
		lines.append_array(_handle_on_pain_perks(attacker, defender, num_checks, state))
	elif not was_dying and pain_limit > 0 and final_dmg > 0:
		# weapon_passive:force_pain_response_within:N — force pain check even below pain_limit
		for _perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(attacker):
			if _perk.effect_dsl.begins_with("weapon_passive:force_pain_response_within:"):
				var _range: int = int(_perk.effect_dsl.get_slice(":", 2))
				if state.battlefield == null or state.distance_to(attacker, defender) <= _range:
					lines.append_array(_apply_pain_limit_checks(defender, 1, def_name))
				break

	if final_dmg >= 1 and was_dying:
		defender.current_hp = -1
		ConstStates.remove_state(defender, ConstStates.DYING)
		lines.append("  %s is dead!" % def_name)
		lines.append_array(_handle_on_kill_perks(attacker, defender, state))
	elif defender.current_hp <= 0 and not was_dying:
		defender.current_hp = 0
		ConstStates.apply_state(defender, ConstStates.DYING)
		lines.append("  %s is dying!" % def_name)

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

	for _i in range(num_checks):
		if randi_range(1, 100) > tolerance:
			if defender.excess_ap > 0:
				defender.excess_ap -= 1
				excess_ap_lost += 1
			elif defender.current_ap > 0:
				defender.current_ap -= 1
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
			# Club Uppercut — valid only if merc has already attacked this turn
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
				# Precondition not met — refund AP and return empty so loop continues normally
				merc.current_ap += ap_cost
				return []
		"attack_all_adjacent_max_1":
			# Flail/Staff Spin — attack all adjacent enemies, cap damage at 1 per hit
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
			# Handgun Rapid-Fire — attack only if weapon is fully loaded
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
					# Not fully loaded — refund and skip
					merc.current_ap += ap_cost
					return []
			else:
				merc.current_ap += ap_cost
				return []
		_:
			# Unimplemented action — refund AP so it does not silently eat resources
			merc.current_ap += ap_cost
			return []
	return lines


static func _handle_on_pain_perks(
		attacker: MercenaryData,
		defender: MercenaryData,
		_num_checks: int,
		state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	# on_pain:direct:N:timing — queue deferred damage to fire at named timing
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
	# reactive_action:on_pain:repeat_pain_response — spend 1 EP to trigger pain again
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
		weapon_action_taken: bool = false) -> Dictionary:
	if merc.action_set == null:
		return CombatDecision.decide_next_action(
			merc, enemies, valid_targets, allies, current_target, state,
			ATTACK_BASE_AP, MOVE_BASE_AP, {}, movement_blocked, weapon_action_taken)

	var ctx := {
		"enemies": enemies, "allies": allies, "valid_targets": valid_targets,
		"state": state, "current_target": current_target,
		"movement_blocked": movement_blocked,
		"attack_base_ap": ATTACK_BASE_AP, "move_base_ap": MOVE_BASE_AP
	}

	var sorted_actions: Array = merc.action_set.actions.duplicate()
	sorted_actions.sort_custom(func(a: ActionData, b: ActionData) -> bool: return a.priority < b.priority)

	var injected_pre_move := false
	var injected_pre_aim := false

	for action: ActionData in sorted_actions:
		if action.is_reactive:
			continue

		# Before priority 40: reload if empty, then weapon management (draw/holster/switch/pickup)
		if not injected_pre_move and action.priority >= 40:
			injected_pre_move = true
			if merc.ammo_loaded == 0 and CombatDecision._should_reload(merc, enemies, valid_targets, state):
				return {"type": "reload", "action_name": "reload", "target": null}
			if not weapon_action_taken:
				var wp := CombatDecision._decide_weapon_action(merc, enemies, state, ATTACK_BASE_AP, movement_blocked)
				if wp["type"] != "none":
					return wp
				var pu := CombatDecision._decide_pickup_action(merc, enemies, state, ATTACK_BASE_AP, MOVE_BASE_AP)
				if pu["type"] != "none":
					return pu

		# Before priority 60: pre-attack reload (ranged strategy)
		if not injected_pre_aim and action.priority >= 60:
			injected_pre_aim = true
			if merc.ammo_loaded > 0 and CombatDecision._should_reload(merc, enemies, valid_targets, state):
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
					return action.to_decision_dict(merc, ctx)
			else:
				var score: float = action.decision.evaluate(merc, ctx)
				if score >= action.decision.threshold:
					return action.to_decision_dict(merc, ctx)

	return {"type": "pass", "action_name": "", "target": null}
