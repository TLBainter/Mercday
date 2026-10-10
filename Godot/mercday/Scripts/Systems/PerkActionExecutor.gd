class_name PerkActionExecutor


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
		var wile_lines := _do_wile_terror(merc, perk, wile_spec(parts), state, enhancements)
		if wile_lines.is_empty():
			return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
		return wile_lines

	var effect := parts[effect_start] if parts.size() > effect_start else ""
	match effect:
		"attack_already_damaged":
			var attacks_taken: int = state.escalation.get(merc, {}).get("Attack", 0)
			if attacks_taken > 0 and target != null:
				var uppercut := _perk_attack(merc, target, state, enhancements, 0, 0, 0, "uses Uppercut!", "Uppercut")
				lines.append_array(uppercut["lines"] as Array[String])
			else:
				return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
		"attack_all_adjacent_max_1":
			var adj_enemies := CombatApplicator.get_enemies_within(merc, 1, state)
			if adj_enemies.is_empty():
				return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
			lines.append_array(_perk_spin(merc, adj_enemies, state, enhancements))
		"attack_fully_loaded":
			if PerkValuation.sees_target(merc, target, state) and merc.equipped_weapon != null \
					and merc.ammo_loaded >= merc.equipped_weapon.chamber:
				var rapid_fire := _perk_attack(merc, target, state, enhancements, 0, 0, 0, "fires rapidly!", "Rapid-Fire")
				lines.append_array(rapid_fire["lines"] as Array[String])
			else:
				return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
		"attack_plus_2":
			if target == null or not WeaponArmorPerkLibrary.is_wielding_two_handed(merc):
				return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
			var impale := _perk_attack(merc, target, state, enhancements, 0, 2, 0, _perk_announce(perk), "Impale")
			lines.append_array(impale["lines"] as Array[String])
			lines.append_array(_direct_behind(merc, target, state, str((impale["atk"] as Dictionary)["damage_type"])))
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
				BattleState.colored_name(merc, state), gained, WeaponArmorPerkLibrary.perk_display_name(perk)])
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("SUAVE: %s gains %d temp ReP" % [merc.merc_name, gained])
		"enhance_attacks_vs_target":
			if target == null:
				return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
			merc.active_states["oppress_target"] = target
			merc.active_states["oppress_until_round"] = state.round_number + 1
			lines.append("  %s singles out %s (%s)." % [
				BattleState.colored_name(merc, state), BattleState.colored_name(target, state), WeaponArmorPerkLibrary.perk_display_name(perk)])
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
			var stat_lines := _perk_weapon_stat(merc, state, stat_name, WeaponArmorPerkLibrary.perk_display_name(perk))
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
				lines.append_array(CombatApplicator.deal_direct(merc, enemy, arc_amount, arc_type, state, WeaponArmorPerkLibrary.perk_display_name(perk)))
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
			var dest := WeaponReactiveSystem.pull_destination(merc, target, 3, state) if target != null \
				else WeaponReactiveSystem.NO_CELL
			if dest == WeaponReactiveSystem.NO_CELL:
				return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
			lines.append_array(_perk_stampede(merc, target, dest, state, enhancements, perk))
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
				merc, target, dump, _perk_damage_type(merc), state, WeaponArmorPerkLibrary.perk_display_name(perk)))
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
			lines.append_array(_perk_over_extend(merc, target, state, enhancements, perk))
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
	return "uses %s!" % WeaponArmorPerkLibrary.perk_display_name(perk)


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
		BattleState.colored_name(merc, state), crowd.size(), "s" if crowd.size() != 1 else "", WeaponArmorPerkLibrary.perk_display_name(perk)])
	lines.append_array(atk.get("window_lines", [] as Array[String]) as Array[String])
	if _attack_refused(atk):
		lines.append_array(_attack_refusal_lines(merc, null, state, atk))
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
	if _attack_refused(atk):
		out.append_array(_attack_refusal_lines(merc, target, state, atk))
	elif int(atk.get("damage", 0)) > 0:
		dealt = int(atk["damage"]) + bonus
		if cap > 0:
			dealt = mini(dealt, cap)
		out.append_array(CombatApplicator.apply_hit(merc, target, atk, dealt, atk["damage_type"], state))
	else:
		out.append("  %s misses with %s against %s." % [
			BattleState.colored_name(merc, state), label, BattleState.colored_name(target, state)])
	return {"lines": out, "atk": atk, "dealt": dealt}


#Trial, Terrified duration, target radius and cost form of a "wile_check" action perk.
static func wile_spec(parts: PackedStringArray) -> Dictionary:
	var spec := {"trial": 0, "duration": "", "radius": 0, "on_draw": false,
		"spend_ammo": false, "flaw_per_5": false, "once": false}
	for i: int in range(parts.size()):
		match parts[i]:
			"wile_check":
				if i + 1 < parts.size():
					spec["trial"] = int(parts[i + 1])
			"terrified":
				if i + 1 < parts.size() and parts[i + 1].contains("_"):
					var dur: String = parts[i + 1].replace("_", " ")
					spec["duration"] = "%s %s" % [dur.get_slice(" ", 0), dur.get_slice(" ", 1).capitalize()]
			"on_draw":
				spec["on_draw"] = true
				spec["radius"] = 5
			"spend_ammo_5s":
				spec["spend_ammo"] = true
				spec["radius"] = 300
			"+1_flawed_per_5":
				spec["flaw_per_5"] = true
			"once_per_combat":
				spec["once"] = true
	return spec


#Enemies in range of a wile action that are neither Terrified already nor known to be immune to it.
static func wile_targets(merc: MercenaryData, spec: Dictionary, state: BattleState) -> Array[MercenaryData]:
	var result: Array[MercenaryData] = []
	var token := "immune:" + StateTokens.normalize_token(ConstStates.TERRIFIED)
	for enemy: MercenaryData in CombatApplicator.get_enemies_within(merc, int(spec["radius"]), state):
		if ConstStates.has_state(enemy, ConstStates.TERRIFIED) or BattleState.knows(merc, enemy, token):
			continue
		result.append(enemy)
	return result


#Great Club Terrorize and Auto-Rifle Bully: a Wile trial that leaves every failure Terrified.
static func _do_wile_terror(merc: MercenaryData, perk: TraitData, spec: Dictionary,
		state: BattleState, enhancements: int) -> Array[String]:
	var lines: Array[String] = []
	var targets := wile_targets(merc, spec, state)
	if targets.is_empty():
		return lines
	var bullets := 0
	if bool(spec["spend_ammo"]):
		bullets = ActionDispatcher.bully_bullets(merc.ammo_loaded, targets.size())
		if bullets < 5:
			return lines
	if bool(spec["on_draw"]) and not merc.weapon_drawn:
		var draw_lines := WeaponActionExecutor.execute_draw(merc, merc.equipped_weapon, state, enhancements)
		if draw_lines.is_empty():
			return lines
		lines.append_array(draw_lines)
	var extra_flaws := 0
	if bullets > 0:
		merc.ammo_loaded -= bullets
		if bool(spec["flaw_per_5"]):
			extra_flaws = int(float(bullets) / 5.0)
		lines.append("  %s empties %d round%s with %s!" % [
			BattleState.colored_name(merc, state), bullets, "s" if bullets != 1 else "", WeaponArmorPerkLibrary.perk_display_name(perk)])
	else:
		lines.append("  %s uses %s!" % [BattleState.colored_name(merc, state), WeaponArmorPerkLibrary.perk_display_name(perk)])
	if bool(spec["once"]):
		merc.active_states[ActionDispatcher.perk_used_key(perk)] = true
	var resist_spec := "Resist:Wile:%d" % int(spec["trial"])
	for enemy: MercenaryData in targets:
		if CombatApplicator.known_immune(merc, enemy, ConstStates.TERRIFIED, "terrified"):
			continue
		lines.append_array(StateInfliction.inflict(enemy, ConstStates.TERRIFIED, resist_spec,
			str(spec["duration"]), "", merc, state, extra_flaws))
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("TERRIFY: %s %s trial=%d targets=%d flaws=%d bullets=%d" % [
			merc.merc_name, WeaponArmorPerkLibrary.perk_display_name(perk), int(spec["trial"]), targets.size(), extra_flaws, bullets])
	return lines


#Spin arm: one roll per adjacent enemy for 1 damage each, stopping at the first misfire.
static func _perk_spin(merc: MercenaryData, adj_enemies: Array[MercenaryData], state: BattleState,
		enhancements: int) -> Array[String]:
	var out: Array[String] = []
	out.append("  %s spins!" % BattleState.colored_name(merc, state))
	for enemy: MercenaryData in adj_enemies:
		var atk := AttackSystem.execute_attack(merc, enhancements, 0, enemy)
		state.record_action(merc, "Attack")
		if atk.get("misfired", false):
			out.append("  %s misfires!" % BattleState.colored_name(merc, state))
			break
		elif atk.get("damage", 0) > 0:
			out.append_array(CombatApplicator.apply_hit(merc, enemy, atk, 1, atk["damage_type"], state))
		else:
			out.append("  %s misses %s with the spin." % [BattleState.colored_name(merc, state), BattleState.colored_name(enemy, state)])
	return out


#Weapon stat arm: the reach or mow window the perk holds open; empty lines mean an unknown stat.
static func _perk_weapon_stat(merc: MercenaryData, state: BattleState, stat_name: String,
		label: String) -> Array[String]:
	var out: Array[String] = []
	if stat_name == "melee_range":
		merc.active_states["weapon_stat_melee_range_bonus"] = \
			int(merc.active_states.get("weapon_stat_melee_range_bonus", 0)) + 1
		merc.active_states["reach_bonus_until_round"] = state.round_number + 1
		out.append("  %s overextends their reach (%s)." % [BattleState.colored_name(merc, state), label])
	elif stat_name == "extend":
		merc.active_states["weapon_extend_active"] = true
		merc.active_states["weapon_extend_until_round"] = state.round_number + 1
		out.append("  %s sets the scythe to mow (%s)." % [BattleState.colored_name(merc, state), label])
	return out


#Stampede arm: the merc closes on the pulled cell and swings with a bonus per pace crossed.
static func _perk_stampede(merc: MercenaryData, target: MercenaryData, dest: Vector3i,
		state: BattleState, enhancements: int, perk: TraitData) -> Array[String]:
	var out: Array[String] = []
	var from := state.get_position(merc)
	var paces := maxi(1, maxi(absi(dest.x - from.x), absi(dest.y - from.y)))
	state.set_pos3(merc, dest)
	merc.aim_active = false
	out.append("  %s stampedes %d pace%s at %s!" % [
		BattleState.colored_name(merc, state), paces, "s" if paces != 1 else "",
		BattleState.colored_name(target, state)])
	var charge := _perk_attack(merc, target, state, enhancements + paces, 0, 0, 0, _perk_announce(perk), "Stampede")
	out.append_array(charge["lines"] as Array[String])
	return out


#Over-Extend arm: the long shot tops its hit up to the pain limit, or snaps the string on a miss.
static func _perk_over_extend(merc: MercenaryData, target: MercenaryData, state: BattleState,
		enhancements: int, perk: TraitData) -> Array[String]:
	var out: Array[String] = []
	var taken_before := int(state.damage_dealt_this_round.get(merc, {}).get(target, 0))
	var over := _perk_attack(merc, target, state, enhancements, 0, 0, 0, _perk_announce(perk), "Over-Extend")
	out.append_array(over["lines"] as Array[String])
	var over_atk: Dictionary = over["atk"]
	if bool(over_atk.get("no_ammo", false)) or bool(over_atk.get("no_los", false)):
		return out
	var over_dealt := int(state.damage_dealt_this_round.get(merc, {}).get(target, 0)) - taken_before
	if over_dealt >= 1:
		var extra := int(target.stats.get("pain_limit", 0)) - over_dealt
		if extra > 0 and BattleState._is_alive(target):
			out.append_array(CombatApplicator.deal_direct(
				merc, target, extra, _perk_damage_type(merc), state, "Recurve Bow Over-Extend"))
	else:
		_snap_bowstring(merc, state, out)
	return out


#Longsword Impale: the cell straight behind the target takes 1 direct, ally or enemy.
static func _direct_behind(merc: MercenaryData, target: MercenaryData, state: BattleState,
		damage_type: String) -> Array[String]:
	var lines: Array[String] = []
	if target == null or state.battlefield == null:
		return lines
	var from := state.get_position(merc)
	var at := state.get_position(target)
	var behind := at + Vector2i(signi(at.x - from.x), signi(at.y - from.y))
	if behind == at:
		return lines
	var floor_num := state.get_floor(target)
	var pool: Array[MercenaryData] = []
	pool.append_array(state.get_enemies(merc))
	pool.append_array(state.get_allies(merc))
	for other: MercenaryData in pool:
		if other == merc or other == target or not BattleState._is_alive(other) or other.off_field:
			continue
		if state.get_floor(other) != floor_num or state.get_position(other) != behind:
			continue
		lines.append_array(CombatApplicator.deal_direct(merc, other, 1, damage_type, state, "Longsword Impale"))
		break
	return lines


#True when the roll never happened: no ammo, a misfire or no line of sight to the target.
static func _attack_refused(atk: Dictionary) -> bool:
	return bool(atk.get("misfired", false)) or bool(atk.get("no_ammo", false)) \
			or bool(atk.get("no_los", false))


#The log lines a refused attack leaves; the no line of sight line needs a named target.
static func _attack_refusal_lines(merc: MercenaryData, target: MercenaryData, state: BattleState,
		atk: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if atk.get("misfired", false):
		out.append("  %s misfires!" % BattleState.colored_name(merc, state))
	elif atk.get("no_ammo", false):
		out.append("  %s has no ammo loaded!" % BattleState.colored_name(merc, state))
	elif atk.get("no_los", false) and target != null:
		out.append("  %s cannot see %s." % [BattleState.colored_name(merc, state), BattleState.colored_name(target, state)])
	return out
