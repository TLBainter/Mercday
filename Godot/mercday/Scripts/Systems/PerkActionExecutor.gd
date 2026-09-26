class_name PerkActionExecutor


static func _perk_label(perk: TraitData) -> String:
	var pieces := perk.trait_name.split("|")
	return pieces[pieces.size() - 1]


#Every abort path of execute_perk_action gives back what the token loop and spend_ap took.
static func _abort_perk_action(merc: MercenaryData, ap_before: int, excess_before: int,
		ep_excess: int, ep_real: int, rep_paid: int) -> Array[String]:
	merc.current_ap = ap_before
	merc.excess_ap = excess_before
	ExcessPool.refund_ep(merc, ep_excess, ep_real)
	merc.current_rep += rep_paid
	return []


static func execute_perk_action(
		merc: MercenaryData,
		perk: TraitData,
		target: MercenaryData,
		state: BattleState,
		enhancements: int) -> Array[String]:
	var lines: Array[String] = []
	var dsl := WeaponArmorPerkLibrary.action_dsl(perk)
	if not dsl.begins_with("action:"):
		return lines
	var parts := dsl.split(":")
	var ap_cost := int(parts[1])
	var ap_before := merc.current_ap
	var excess_before := merc.excess_ap
	state.spend_ap(merc, ap_cost)

	var effect_start := 2
	var j := 2
	var ep_excess := 0
	var ep_real := 0
	var rep_paid := 0
	while j < parts.size() - 1:
		if parts[j] == "ep":
			var ep_step := CombatApplicator.state_ep_cost(merc, int(parts[j + 1]), "reaction", 0)
			var pay := ExcessPool.pay_ep(merc, ep_step)
			ep_excess += int(pay["from_excess"])
			ep_real += int(pay["from_ep"])
			effect_start = j + 2
			j += 2
		elif parts[j] == "rep":
			var rep_step := int(parts[j + 1])
			merc.current_rep -= rep_step
			rep_paid += rep_step
			effect_start = j + 2
			j += 2
		elif parts[j] == "once_per_combat" or parts[j] == "two_handed":
			effect_start = j + 1
			j += 1
		else:
			break

	if dsl.contains("wile_check:"):
		var wile_lines := ActionDispatcher._do_wile_terror(merc, perk, ActionDispatcher._wile_spec(parts), state, enhancements)
		if wile_lines.is_empty():
			return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
		return wile_lines

	var effect := parts[effect_start] if parts.size() > effect_start else ""
	match effect:
		"attack_already_damaged":
			var attacks_taken: int = state.escalation.get(merc, {}).get("Attack", 0)
			if attacks_taken > 0 and target != null:
				lines.append_array(_perk_single_attack(
					merc, target, state, enhancements, "uses Uppercut!", "Uppercut"))
			else:
				return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
		"attack_all_adjacent_max_1":
			var adj_enemies := CombatApplicator.get_enemies_within(merc, 1, state)
			if adj_enemies.is_empty():
				return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
			lines.append_array(ActionDispatcher._perk_spin(merc, adj_enemies, state, enhancements))
		"attack_fully_loaded":
			if PerkValuation.sees_target(merc, target, state) and merc.equipped_weapon != null \
					and merc.ammo_loaded >= merc.equipped_weapon.chamber:
				lines.append_array(_perk_single_attack(
					merc, target, state, enhancements, "fires rapidly!", "Rapid-Fire"))
			else:
				return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
		"attack_plus_2":
			if target == null or not WeaponArmorPerkLibrary.is_wielding_two_handed(merc):
				return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
			var impale := _perk_attack(merc, target, state, enhancements, 0, 2, 0, _perk_announce(perk), "Impale")
			lines.append_array(impale["lines"] as Array[String])
			lines.append_array(ActionDispatcher._direct_behind(merc, target, state, str((impale["atk"] as Dictionary)["damage_type"])))
		"attack_within_1":
			if target == null or state.battlefield == null or state.distance_to(merc, target) > 1:
				return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
			var rapid := _perk_attack(merc, target, state, enhancements + 1, 0, 2, 0, _perk_announce(perk), "Rapidity")
			lines.append_array(rapid["lines"] as Array[String])
		"called_shot":
			var called_info := PerkValuation.parse_action(perk)
			if not CalledShotSystem.perk_ready(merc, target, called_info, state):
				return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
			lines.append_array(CalledShotSystem.perk_called_shot(merc, perk, target, called_info, state, enhancements))
		"dex_check":
			var suave := CheckSystem.make_check(merc, PerkValuation.dex_check_def())
			var gained := int(suave["successes"])
			merc.current_rep += gained
			merc.temp_rep += gained
			lines.append("  %s flourishes for %d ReP (%s)." % [
				BattleState.colored_name(merc, state), gained, _perk_label(perk)])
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("SUAVE: %s gains %d temp ReP" % [merc.merc_name, gained])
		"enhance_attacks_vs_target":
			if target == null:
				return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
			merc.active_states["oppress_target"] = target
			merc.active_states["oppress_until_round"] = state.round_number + 1
			lines.append("  %s singles out %s (%s)." % [
				BattleState.colored_name(merc, state), BattleState.colored_name(target, state), _perk_label(perk)])
		"after_damage":
			var dealt_before := int(state.damage_dealt_this_round.get(merc, {}).get(target, 0))
			if target == null or dealt_before <= 0:
				return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
			var wtype := WeaponArmorPerkLibrary.weapon_type_key(merc.equipped_weapon)
			var sweep_flaws := int(merc.turn_weapon_attacks.get(wtype, 0))
			var sweep := _perk_attack(merc, target, state, enhancements, sweep_flaws, 0, 0, _perk_announce(perk), "Sweep")
			lines.append_array(sweep["lines"] as Array[String])
		"weapon_stat":
			var stat_name := parts[effect_start + 1] if parts.size() > effect_start + 1 else ""
			var stat_lines := ActionDispatcher._perk_weapon_stat(merc, state, stat_name, _perk_label(perk))
			if stat_lines.is_empty():
				return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
			lines.append_array(stat_lines)
		"direct_1_all":
			var arc := PerkValuation.arc_targets(merc, state)
			if arc.size() < 2:
				return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
			var arc_amount := 2 if WeaponArmorPerkLibrary.is_level_20(merc) else 1
			var arc_type := _perk_damage_type(merc)
			lines.append("  %s sweeps a wide arc!" % BattleState.colored_name(merc, state))
			for enemy: MercenaryData in arc:
				lines.append_array(CombatApplicator.deal_direct(merc, enemy, arc_amount, arc_type, state, _perk_label(perk)))
		"spend_ep":
			var k := PerkValuation.rampage_ep(merc)
			if k < 1:
				return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
			var k_cost := CombatApplicator.state_ep_cost(merc, k, "reaction", 0)
			var k_pay := ExcessPool.pay_ep(merc, k_cost)
			ep_excess += int(k_pay["from_excess"])
			ep_real += int(k_pay["from_ep"])
			merc.active_states["rampage_bonus"] = int(merc.active_states.get("rampage_bonus", 0)) + k
			merc.active_states["rampage_until_round"] = state.round_number + 1
			lines.append("  %s works up a rampage (+%d damage, %d EP)." % [
				BattleState.colored_name(merc, state), k, k_cost])
		"move_to_target":
			var dest := WeaponReactiveSystem._pull_destination(merc, target, 3, state) if target != null \
				else WeaponReactiveSystem.NO_CELL
			if dest == WeaponReactiveSystem.NO_CELL:
				return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
			lines.append_array(ActionDispatcher._perk_stampede(merc, target, dest, state, enhancements, perk))
		"attack":
			if not PerkValuation.sees_target(merc, target, state):
				return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
			var draw := _perk_attack(merc, target, state, enhancements, 0, 0, 0, _perk_announce(perk), "Overdraw")
			lines.append_array(draw["lines"] as Array[String])
			var push := maxi(0, int((draw["atk"] as Dictionary).get("core_successes", 0)) - 1)
			if int(draw["dealt"]) >= 1 and push > 0 and BattleState._is_alive(target):
				lines.append_array(ShoveResolver.forcible_move(merc, target, push, state))
		"attack_up_to_3":
			var crowd := PerkValuation.burst_targets(merc, target, state)
			if crowd.is_empty():
				return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
			lines.append_array(_artillery_burst(merc, crowd, state, enhancements, perk))
		"15_bullets_min":
			if not PerkValuation.sees_target(merc, target, state) or merc.ammo_loaded < 15:
				return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
			var dump := int(float(merc.ammo_loaded) / 5.0)
			merc.ammo_loaded = 0
			lines.append("  %s empties the magazine into %s!" % [
				BattleState.colored_name(merc, state), BattleState.colored_name(target, state)])
			lines.append_array(CombatApplicator.deal_direct(
				merc, target, dump, _perk_damage_type(merc), state, _perk_label(perk)))
		"spend_ammo":
			var b := PerkValuation.wild_shot_bullets(merc)
			if not PerkValuation.sees_target(merc, target, state) or b < 1:
				return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
			merc.ammo_loaded -= b
			var wild := _perk_attack(merc, target, state, enhancements + b, 0, 0, b, _perk_announce(perk), "Wild-Shot")
			lines.append_array(wild["lines"] as Array[String])
		"attack_extended":
			var bow: WeaponData = merc.equipped_weapon
			if not PerkValuation.sees_target(merc, target, state) or bow == null or not bow.is_ranged or bow.string_snapped \
					or merc.ammo_loaded <= 0 or state.battlefield == null \
					or state.distance_to(merc, target) > bow.ranged_extended_range:
				return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
			lines.append_array(ActionDispatcher._perk_over_extend(merc, target, state, enhancements, perk))
		_:
			return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
	return lines


#Over-Extend on a failed shot: the merc keeps its own copy of the bow so the template stays whole.
static func _snap_bowstring(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	var own := WeaponData.instance_copy(merc.equipped_weapon)
	own.string_snapped = true
	own.repair_ap_paid = 0
	merc.equipped_weapon = own
	lines.append("  %s's bowstring snaps!" % BattleState.colored_name(merc, state))
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("SNAP: %s %s" % [merc.merc_name, own.item_name])


static func _perk_announce(perk: TraitData) -> String:
	return "uses %s!" % _perk_label(perk)


#Damage type a perk action deals: the held weapon's, or the loaded ammo's when the weapon varies.
static func _perk_damage_type(merc: MercenaryData) -> String:
	var weapon: WeaponData = merc.equipped_weapon
	var dtype := "Strike"
	if weapon != null and not weapon.damage_types_1.is_empty():
		dtype = str(weapon.damage_types_1[0])
	if dtype == "Varies" and merc.ammo_loaded_type != "":
		var ammo_data: AmmoData = DataManager.ammo.get(merc.ammo_loaded_type)
		if ammo_data != null and not ammo_data.damage_types_1.is_empty():
			dtype = str(ammo_data.damage_types_1[0])
	return dtype


#Artillery Burst: one roll, one defence per target, one bullet per target.
static func _artillery_burst(merc: MercenaryData, crowd: Array[MercenaryData], state: BattleState,
		enhancements: int, perk: TraitData) -> Array[String]:
	var lines: Array[String] = []
	var atk := AttackSystem.execute_attack(merc, enhancements, 0, crowd[0], false, state)
	CombatApplicator.note_attack(merc, crowd[0])
	state.record_action(merc, "Attack")
	lines.append("  %s fires a burst at %d target%s (%s)!" % [
		BattleState.colored_name(merc, state), crowd.size(), "s" if crowd.size() != 1 else "", _perk_label(perk)])
	lines.append_array(atk.get("window_lines", [] as Array[String]) as Array[String])
	if ActionDispatcher._attack_refused(atk):
		lines.append_array(ActionDispatcher._attack_refusal_lines(merc, null, state, atk))
		return lines
	var damage := int(atk.get("damage", 0))
	for i: int in range(crowd.size()):
		var enemy: MercenaryData = crowd[i]
		if i > 0:
			if merc.ammo_loaded <= 0:
				lines.append("  %s runs dry!" % BattleState.colored_name(merc, state))
				break
			merc.ammo_loaded -= 1
		if not BattleState._is_alive(enemy):
			continue
		if damage > 0:
			lines.append_array(CombatApplicator.apply_hit(merc, enemy, atk, damage, atk["damage_type"], state))
		else:
			lines.append("  The burst misses %s." % BattleState.colored_name(enemy, state))
	return lines


#One perk attack: bonus adds to the damage, cap limits it, and the roll goes back to the caller.
static func _perk_attack(merc: MercenaryData, target: MercenaryData, state: BattleState,
		enhancements: int, flaws: int, bonus: int, cap: int, announce: String, label: String,
		success_penalty: int = 0, cost_key: String = "Attack") -> Dictionary:
	var out: Array[String] = []
	var atk := AttackSystem.execute_attack(merc, enhancements, flaws, target, false, state, false, success_penalty)
	CombatApplicator.note_attack(merc, target)
	if announce != "":
		out.append("  %s %s" % [BattleState.colored_name(merc, state), announce])
	state.record_action(merc, cost_key)
	out.append_array(atk.get("window_lines", [] as Array[String]) as Array[String])
	var dealt := 0
	if ActionDispatcher._attack_refused(atk):
		out.append_array(ActionDispatcher._attack_refusal_lines(merc, target, state, atk))
	elif int(atk.get("damage", 0)) > 0:
		dealt = int(atk["damage"]) + bonus
		if cap > 0:
			dealt = mini(dealt, cap)
		out.append_array(CombatApplicator.apply_hit(merc, target, atk, dealt, atk["damage_type"], state))
	else:
		out.append("  %s misses with %s against %s." % [
			BattleState.colored_name(merc, state), label, BattleState.colored_name(target, state)])
	return {"lines": out, "atk": atk, "dealt": dealt}


#One perk attack against a single target; announce is the merc line, label names the miss.
static func _perk_single_attack(merc: MercenaryData, target: MercenaryData, state: BattleState,
		enhancements: int, announce: String, label: String) -> Array[String]:
	var out: Array[String] = []
	var atk := AttackSystem.execute_attack(merc, enhancements, 0, target)
	out.append("  %s %s" % [BattleState.colored_name(merc, state), announce])
	state.record_action(merc, "Attack")
	if ActionDispatcher._attack_refused(atk):
		out.append_array(ActionDispatcher._attack_refusal_lines(merc, target, state, atk))
	elif atk.get("damage", 0) > 0:
		out.append_array(CombatApplicator.apply_hit(merc, target, atk, atk["damage"], atk["damage_type"], state))
	else:
		out.append("  %s misses with %s against %s." % [BattleState.colored_name(merc, state), label, BattleState.colored_name(target, state)])
	return out
