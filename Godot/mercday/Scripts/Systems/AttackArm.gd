class_name AttackArm


#Attack arm of the turn slot loop: the swing, the on_hit perk dispatch and the after-attack reactives.
static func run_attack_arm(merc: MercenaryData, decision: Dictionary, state: BattleState,
		enhancements: int, attack_ap_reduction: int, turn: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var current_target: MercenaryData = decision["target"]
	if current_target == null:
		turn["stop"] = true
		return lines
	var called: String = str(decision.get("called_shot", ""))
	if called != "" and not CalledShotSystem.OPTIONS.has(called):
		called = ""
	turn["current_target"] = current_target
	state.last_attacked[merc] = current_target
	if state.battlefield != null:
		merc.last_seen_position = state.pos3(current_target)
	if merc.equipped_weapon != null and merc.equipped_weapon.is_ranged:
		state.record_ranged_targeted(current_target)
	var cost_key := "CalledShot" if called != "" else "Attack"
	var atk_cost := maxi(0, state.get_cost(merc, cost_key, AutoBattle.ATTACK_BASE_AP) - attack_ap_reduction)
	var _is_throw_action: bool = decision["action_name"] == "AttackThrow"
	var pre := _pay_pre_roll(merc, current_target, state, _is_throw_action, lines)
	var _throw_tgt: MercenaryData = current_target
	if not _is_throw_action and (merc.equipped_weapon == null or not merc.equipped_weapon.is_ranged) \
			and TraitRuntime.has(current_target, "targeted_melee"):
		TraitRuntime.fire("targeted_melee", current_target,
			{"state": state, "target": merc, "lines": lines})
	var _ammo_before: int = merc.ammo_loaded
	var _bludgeon: bool = _use_melee_override(merc, current_target, state)
	var atk := AttackSystem.execute_attack(merc, enhancements + int(pre["enh"]), int(pre["flaws"]), current_target,
		_is_throw_action, state, _bludgeon, CalledShotSystem.value(called))
	CombatApplicator.note_attack(merc, current_target)
	if merc.equipped_weapon != null and merc.equipped_weapon.is_ranged and not _bludgeon \
			and _ammo_before > 0 and merc.ammo_loaded == 0:
		lines.append_array(WeaponReactiveSystem.fire_trigger(merc, "on_last_shot", current_target, atk, state, enhancements))
	var _throw_hit: bool = not atk.get("misfired", false) and int(atk["damage"]) > 0
	var _throw_dmg: int = int(atk["damage"])
	merc.aim_active = false
	lines.append_array(atk.get("window_lines", [] as Array[String]) as Array[String])
	if atk.get("no_los", false):
		turn["stop"] = true
		return lines
	if atk.get("no_ammo", false):
		lines.append("  %s has no ammo loaded!" % BattleState.colored_name(merc, state))
		turn["stop"] = true
		return lines
	if not atk.get("misfired", false):
		merc.active_states["last_target"] = current_target
	if called != "":
		lines.append(CalledShotSystem.call_line(merc, called, state))
		CalledShotSystem.calls_made += 1
	state.spend_ap(merc, atk_cost)
	state.record_action(merc, cost_key)
	merc.combat_idle_rounds = 0
	turn["weapon_action_taken"] = true
	if atk.get("weapon_broke", false):
		var _broke_name: String = merc.equipped_weapon.item_name if merc.equipped_weapon != null else "weapon"
		lines.append("  %s's %s breaks apart!" % [BattleState.colored_name(merc, state), _broke_name])
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("FRAGILITY: %s destroyed" % _broke_name)
		lines.append_array(WeaponActionExecutor.empty_main_hand(merc, state))
	if EncounterLogger.is_active() and not atk.get("misfired", false) \
			and not (atk["check_result"] as Dictionary).is_empty():
		var cr: Dictionary = atk["check_result"]
		var _called_note := ""
		if int(atk.get("success_penalty", 0)) > 0:
			_called_note = " called=-%d" % int(atk["success_penalty"])
		EncounterLogger.log_verbose("ATTACK ROLL: %s vs %.0f%% -> %d hit %d miss  dmg=%d %s%s" % [
			str(cr["roll2"]), cr["threshold"],
			cr["successes"], cr["failures"],
			atk["damage"], atk["damage_type"], _called_note])
	if atk.get("misfired", false):
		lines.append("  %s misfires!" % BattleState.colored_name(merc, state))
	elif atk["damage"] > 0:
		_resolve_attack_hit(merc, current_target, state, atk, called, _is_throw_action, enhancements, lines)
		if not BattleState._is_alive(current_target):
			merc.last_seen_position = Vector3i(-1, -1, -1)
			current_target = null
			turn["current_target"] = null
	else:
		lines.append("  %s misses against %s." % [BattleState.colored_name(merc, state),
			BattleState.colored_name(current_target, state)])
		if called != "":
			lines.append("  The called shot to the %s misses." % CalledShotSystem.label(called).to_lower())
		if TraitRuntime.has(merc, "miss_dealt"):
			TraitRuntime.fire("miss_dealt", merc,
				{"state": state, "target": current_target, "lines": lines})
		#spend:rep:1:reload_free (Blowgun Quick Reload); also triggers on miss
		_rep_reload_free(merc, state, lines)
		lines.append_array(WeaponReactiveSystem.fire_trigger(merc, "on_miss", current_target, atk, state,
				int(atk.get("enhancements", 0))))
		lines.append_array(WeaponReactiveSystem.after_attack_resolved(merc, current_target, atk, state))
	if atk.get("misfired", false) and bool(pre["overcharged"]):
		lines.append_array(_overcharge_misfire(merc, state))
	lines.append_array(WeaponReactiveSystem.fire_trigger(merc, "after_attack", current_target, atk, state,
			int(atk.get("enhancements", 0))))
	if str(pre["makeshift"]) != "":
		merc.active_states.erase("makeshift_perk_active")
	lines.append_array(CombatApplicator.resolve_suppress(merc, _throw_tgt, str(atk.get("damage_type", "Strike")), state))
	if _is_throw_action and merc.equipped_weapon != null:
		var _thrown_w: WeaponData = merc.equipped_weapon
		var _thrown_name: String = _thrown_w.item_name
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("THROW: %s throws %s - weapon leaves hand" % [merc.merc_name, _thrown_name])
		lines.append("  %s throws %s! Weapon leaves their hand." % [BattleState.colored_name(merc, state), _thrown_name])
		#Mallet Rebound caught the weapon back into the hand, so it never leaves and never lands.
		if bool(merc.active_states.get("weapon_caught", false)):
			merc.active_states.erase("weapon_caught")
		else:
			lines.append_array(WeaponActionExecutor.empty_main_hand(merc, state))
			lines.append_array(ThrownWeaponRules.land_thrown_weapon(
				merc, _thrown_w, _throw_tgt, _throw_hit, _throw_dmg, state))
	return lines


#Pre-roll perk payments in order; returns the flaws, the bonus enhancements, the makeshift perk and the overcharge flag.
static func _pay_pre_roll(merc: MercenaryData, current_target: MercenaryData, state: BattleState,
		is_throw: bool, lines: Array[String]) -> Dictionary:
	#spend:ep:1:weapon_stat:thrown_extended_range:+10:until_turn_end (Spear Launcher)
	var _sl_w: WeaponData = merc.equipped_weapon
	if _sl_w != null and _sl_w.is_throwable and not _sl_w.is_ranged:
		for _sl_perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
			if "weapon_stat:thrown_extended_range:+10" in _sl_perk.effect_dsl:
				var _sl_cost := CombatApplicator.state_ep_cost(merc, 1, "reaction", 0)
				if _sl_cost > 0 and ExcessPool.available_ep(merc) >= _sl_cost:
					ExcessPool.pay_ep(merc, _sl_cost)
					merc.active_states["thrown_extended_range_bonus"] = 10
					lines.append("  %s extends throw range (%d EP)." % [BattleState.colored_name(merc, state), _sl_cost])
				break
	_pay_reach_extension(merc, current_target, state, lines)
	var atk_flaws := AttackSystem.compute_attack_flaws(merc, current_target, state)
	var aim_bonus := 1 if merc.aim_active else 0
	var weapon_enh := AttackSystem.get_weapon_enhance_bonus(merc)
	var perk_enh := _attack_perk_enhancements(merc, current_target, state)
	perk_enh += _pay_auto_pistol_spray(merc, is_throw, state, lines)
	_pay_suppress(merc, current_target, state, lines)
	var makeshift := _activate_makeshift_perk(merc, state, lines)
	var overcharged: bool = _prime_overcharge(merc)
	return {"flaws": atk_flaws, "enh": aim_bonus + weapon_enh + perk_enh, "makeshift": makeshift,
		"overcharged": overcharged}


#A landed swing: damage bonuses, the on_hit perks, the hit itself, then the crit, called shot and reload follow-ups.
static func _resolve_attack_hit(merc: MercenaryData, current_target: MercenaryData, state: BattleState,
		atk: Dictionary, called: String, is_thrown: bool, enhancements: int, lines: Array[String]) -> void:
	var _w: WeaponData = merc.equipped_weapon
	var hp_before: int = ExcessPool.hp_total(current_target)
	var two_handed_bonus: int = WeaponArmorPerkLibrary.get_two_handed_damage_bonus(merc, is_thrown)
	if two_handed_bonus > 0 and EncounterLogger.is_active():
		EncounterLogger.log_verbose("TWO_HANDED_BONUS: %s +%d" % [merc.merc_name, two_handed_bonus])
	var final_damage: int = atk["damage"] + two_handed_bonus
	#Great Axe Rampage: the EP worked up before the swing lands with it and is spent.
	var rampage_bonus: int = int(merc.active_states.get("rampage_bonus", 0))
	if rampage_bonus > 0:
		merc.active_states.erase("rampage_bonus")
		merc.active_states.erase("rampage_until_round")
		final_damage += rampage_bonus
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("RAMPAGE: %s +%d damage" % [merc.merc_name, rampage_bonus])
	var is_crit: bool = bool(atk.get("critical", false))
	if is_crit:
		final_damage += on_crit_damage_bonus(merc, lines)
	final_damage += _apply_damage_per_enhancement(merc, atk)
	final_damage += _apply_thrown_bonus(merc, current_target, state, is_thrown, _w)
	final_damage += WeaponReactiveSystem.on_hit_damage_bonus(merc, current_target, atk, state, lines)
	#on_hit: weapon perk dispatch; runs before normal _apply_damage
	var used_perk_effect := _run_on_hit_dsl(merc, current_target, state, atk, final_damage, lines)
	lines.append_array(resolve_hit(merc, current_target, atk, final_damage, used_perk_effect, hp_before, state, enhancements))
	if is_crit and BattleState._is_alive(current_target):
		lines.append_array(WeaponReactiveSystem.fire_trigger(merc, "on_crit", current_target, atk, state,
				int(atk.get("enhancements", 0))))
	if called != "":
		lines.append_array(CalledShotSystem.after_hit(merc, current_target, called, atk, hp_before, state))
	#spend:rep:1:reload_free (Blowgun Quick Reload); after hit
	_rep_reload_free(merc, state, lines)


#weapon_passive:damage_per_enhancement:N:max:cap; the damage the enhancements on the roll add.
static func _apply_damage_per_enhancement(merc: MercenaryData, atk: Dictionary) -> int:
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
		if perk.effect_dsl.begins_with("weapon_passive:damage_per_enhancement:"):
			var parts := perk.effect_dsl.split(":")
			if parts.size() >= 5:
				return mini(int(atk.get("enhancements", 0)) * int(parts[2]), int(parts[4]))
			break
	return 0


#weapon_passive:thrown_extended_bonus_damage:+N; the bonus a throw past its intended range adds.
static func _apply_thrown_bonus(merc: MercenaryData, target: MercenaryData, state: BattleState,
		is_thrown: bool, weapon: WeaponData) -> int:
	if not is_thrown or weapon == null or weapon.thrown_intended_range <= 0:
		return 0
	if state.battlefield == null or state.distance_to(merc, target) <= weapon.thrown_intended_range:
		return 0
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
		if perk.effect_dsl.begins_with("weapon_passive:thrown_extended_bonus_damage:"):
			return int(perk.effect_dsl.get_slice(":", 2).lstrip("+"))
	return 0


#The on_hit weapon perk dispatch; true when a perk arm replaced the normal damage.
static func _run_on_hit_dsl(merc: MercenaryData, current_target: MercenaryData, state: BattleState,
		atk: Dictionary, final_damage: int, lines: Array[String]) -> bool:
	var used_perk_effect := false
	var total_successes: int = int(atk["core_successes"]) + int(atk["weapon_die_successes"])
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
		var dsl: String = perk.effect_dsl
		if not dsl.begins_with("on_hit:"):
			continue
		var parts := dsl.split(":")
		if parts.size() < 3:
			continue
		var condition: String = parts[1]
		var meets_condition := false
		if condition == "any":
			meets_condition = true
		elif condition == "4_successes":
			meets_condition = total_successes >= 4
		elif condition == "size_5_or_less":
			meets_condition = int(current_target.stats.get("size", 1)) <= 5
		if not meets_condition:
			continue
		var verb: String = parts[2]
		if verb == "choose":
			if parts.size() < 4:
				continue
			var choices := parts[3].split(",")
			var alt: String = choices[0] if choices.size() >= 1 else ""
			var prefer_alt := false
			match alt:
				"grapple":
					var tgt_w: WeaponData = current_target.equipped_weapon
					prefer_alt = not ConstStates.has_state(current_target, ConstStates.GRAPPLED) \
						and not CombatApplicator.known_immune(merc, current_target, ConstStates.GRAPPLED, alt) \
						and (final_damage <= 2 or (tgt_w != null and tgt_w.is_ranged))
				"shove_1":
					prefer_alt = _prefer_shove(merc, current_target, final_damage, state)
				"disarm":
					prefer_alt = true
				"trip_deposed":
					prefer_alt = int(current_target.stats.get("size", 1)) <= 5 \
						and not ConstStates.has_state(current_target, ConstStates.DEPOSED) \
						and not CombatApplicator.known_immune(merc, current_target, ConstStates.DEPOSED, alt)
				"direct_1_strike_slowed_until_turn_end":
					prefer_alt = not ConstStates.has_state(current_target, ConstStates.SLOWED) \
						and not CombatApplicator.known_immune(merc, current_target, ConstStates.SLOWED, alt)
			if prefer_alt:
				match alt:
					"grapple":
						lines.append("  %s tries to grapple %s instead of dealing damage!" % [
							BattleState.colored_name(merc, state), BattleState.colored_name(current_target, state)])
						lines.append_array(StateInfliction.inflict_default(current_target, ConstStates.GRAPPLED, merc, state))
						used_perk_effect = true
					"shove_1":
						var shove_paces: int = 2 if int(merc.stats.get("level", 0)) >= 20 else 1
						lines.append("  %s shoves %s instead of dealing damage!" % [
							BattleState.colored_name(merc, state), BattleState.colored_name(current_target, state)])
						lines.append_array(ShoveResolver.forcible_move(merc, current_target, shove_paces, state))
						used_perk_effect = true
					"disarm":
						_on_hit_disarm(merc, current_target, state, lines)
						used_perk_effect = true
					"trip_deposed":
						lines.append("  %s tries to trip %s instead of dealing damage!" % [
							BattleState.colored_name(merc, state), BattleState.colored_name(current_target, state)])
						lines.append_array(StateInfliction.inflict_default(current_target, ConstStates.DEPOSED, merc, state))
						used_perk_effect = true
					"direct_1_strike_slowed_until_turn_end":
						_on_hit_strike_slow(merc, current_target, state, lines)
						used_perk_effect = true
		elif verb == "spend_3_successes":
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
	return used_perk_effect


#on_hit disarm: a drawn real weapon is dropped, otherwise the offhand weapon is promoted.
static func _on_hit_disarm(merc: MercenaryData, target: MercenaryData, state: BattleState,
		lines: Array[String]) -> void:
	lines.append("  %s disarms %s!" % [BattleState.colored_name(merc, state),
		BattleState.colored_name(target, state)])
	if (target.weapon_drawn and target.equipped_weapon != null
			and not target.equipped_weapon.is_virtual):
		lines.append_array(WeaponActionExecutor.execute_drop(target, state, "disarmed"))
	else:
		lines.append_array(WeaponActionExecutor.promote_offhand(target, state))


#on_hit strike and slow: 1 Strike damage, then Slowed until the end of the turn unless the target is immune.
static func _on_hit_strike_slow(merc: MercenaryData, target: MercenaryData, state: BattleState,
		lines: Array[String]) -> void:
	lines.append_array(CombatApplicator.apply_damage(merc, target, 1, "Strike", state))
	if StateCascade.apply_state(target, ConstStates.SLOWED, null, "", "engine:perk"):
		state.set_state_timer(target, ConstStates.SLOWED, state.round_number, "")
		lines.append("  %s is slowed until end of turn!" % BattleState.colored_name(target, state))
	else:
		lines.append("  %s is immune to Slowed!" % BattleState.colored_name(target, state))
		state.learn_state_immunity(merc, target, ConstStates.SLOWED)


#D6: Auto-Pistol Spray buys enhancements with bullets and 1 EP before the shot.
static func _pay_auto_pistol_spray(merc: MercenaryData, is_throw: bool, state: BattleState,
		lines: Array[String]) -> int:
	var weapon: WeaponData = merc.equipped_weapon
	if weapon == null or not weapon.is_ranged or is_throw:
		return 0
	if not WeaponArmorPerkLibrary.has_weapon_passive(merc, "before_attack:spend_ammo:+1_enhanced_per_bullet"):
		return 0
	var extra := PerkValuation.spray_bullets(merc)
	if extra < 2:
		return 0
	var cost := CombatApplicator.state_ep_cost(merc, 1, "reaction", 0)
	if cost <= 0 or ExcessPool.available_ep(merc) < cost:
		return 0
	ExcessPool.pay_ep(merc, cost)
	merc.ammo_loaded -= extra
	lines.append("  %s sprays %d extra rounds (+%d Enhanced, %d EP)." % [
		BattleState.colored_name(merc, state), extra, extra, cost])
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("SPRAY: %s spends %d bullets for +%d" % [merc.merc_name, extra, extra])
	return extra


#D6: Artillery Suppress pays 2 ReP before the shell when it would catch 2 or more enemies.
static func _pay_suppress(merc: MercenaryData, target: MercenaryData, state: BattleState,
		lines: Array[String]) -> void:
	var weapon: WeaponData = merc.equipped_weapon
	if weapon == null or not weapon.is_ranged or target == null:
		return
	if bool(merc.active_states.get("suppress_pending", false)):
		return
	if not WeaponArmorPerkLibrary.has_weapon_passive(merc, "suppress_aoe") \
			or not PerkValuation.suppress_worth(merc, target, state):
		return
	merc.current_rep -= 2
	merc.active_states["suppress_pending"] = true
	lines.append("  %s calls a suppressing shell on %s (2 ReP)." % [
		BattleState.colored_name(merc, state), BattleState.colored_name(target, state)])
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("SUPPRESS: %s primes the shell (2 ReP)" % merc.merc_name)


#Halberd Extension: 1 EP buys one extra pace of reach for this swing only.
static func _pay_reach_extension(merc: MercenaryData, target: MercenaryData,
		state: BattleState, lines: Array[String]) -> void:
	if target == null or state.battlefield == null:
		return
	var weapon: WeaponData = merc.equipped_weapon
	if weapon == null or weapon.is_ranged:
		return
	if not WeaponArmorPerkLibrary.has_weapon_passive(merc, "weapon_stat:melee_range:+1"):
		return
	var reach := WeaponArmorPerkLibrary.get_effective_melee_range(merc)
	if state.distance_to(merc, target) != reach + 1:
		return
	var cost := CombatApplicator.state_ep_cost(merc, 1, "reaction", 0)
	if cost <= 0 or ExcessPool.available_ep(merc) < cost:
		return
	ExcessPool.pay_ep(merc, cost)
	merc.active_states["weapon_stat_melee_range_bonus"] = \
		int(merc.active_states.get("weapon_stat_melee_range_bonus", 0)) + 1
	lines.append("  %s extends their reach (%d EP)." % [BattleState.colored_name(merc, state), cost])


#Enhancements weapon perks add to this one swing: Recurve Sky-Shot and Saber Oppress.
static func _attack_perk_enhancements(merc: MercenaryData, target: MercenaryData,
		state: BattleState) -> int:
	if target == null:
		return 0
	var bonus := 0
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
		if perk.effect_dsl.contains("weapon_passive:flying_target:+1_enhanced") \
				and PathTargeter.is_flying(target):
			bonus += 1
	if merc.active_states.get("oppress_target") == target \
			and state.round_number <= int(merc.active_states.get("oppress_until_round", -1)):
		bonus += 1
	return bonus


#W9: a makeshift weapon borrows one owned perk of its base weapon type for a single attack.
static func _activate_makeshift_perk(merc: MercenaryData, state: BattleState,
		lines: Array[String]) -> String:
	var weapon: WeaponData = merc.equipped_weapon
	if weapon == null or weapon.base_weapon == null or merc.current_rep < 1:
		return ""
	if merc.active_states.has("makeshift_perk_active"):
		return ""
	var tier := WeaponArmorPerkLibrary.weapon_tier(weapon.base_weapon)
	if not WeaponArmorPerkLibrary.MAKESHIFT_TIERS.has(tier):
		return ""
	var allowed := false
	for owned: TraitData in merc.weapon_perks:
		if owned != null and owned.effect_dsl == "spend:rep:1:activate_perk:%s" % tier:
			allowed = true
			break
	if not allowed:
		return ""
	var pick := PerkValuation.pick_makeshift_perk(merc, weapon)
	if pick == null:
		return ""
	merc.current_rep -= 1
	merc.active_states["makeshift_perk_active"] = pick.trait_name
	lines.append("  %s improvises %s (1 ReP)." % [BattleState.colored_name(merc, state), pick.trait_name])
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("MAKESHIFT PERK: %s %s (1 ReP)" % [merc.merc_name, pick.trait_name])
	return pick.trait_name


#Shotgun Overcharge: the primed shell adds 4d4 to the shot it is spent on.
static func _prime_overcharge(merc: MercenaryData) -> bool:
	if not bool(merc.active_states.get("shotgun_overcharged", false)):
		return false
	merc.active_states.erase("shotgun_overcharged")
	merc.active_states["extra_weapon_dice"] = [4, 4, 4, 4]
	return true


#An overcharged shell that misfires burns the shooter and wrecks a non-magical gun.
static func _overcharge_misfire(merc: MercenaryData, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	merc.active_states.erase("extra_weapon_dice")
	var weapon: WeaponData = merc.equipped_weapon
	lines.append_array(CombatApplicator.deal_direct(merc, merc, 2, "Fire", state, "Overcharge"))
	if weapon != null and weapon.resonance == "":
		lines.append("  %s's %s explodes!" % [BattleState.colored_name(merc, state), weapon.item_name])
		for entry: Dictionary in merc.inventory.duplicate():
			if entry.get("data") == weapon:
				merc.inventory.erase(entry)
		lines.append_array(WeaponActionExecutor.empty_main_hand(merc, state))
	return lines


#Shotgun Bludgeon: the gun is swung when it cannot shoot or the holder is crowded.
static func _use_melee_override(merc: MercenaryData, target: MercenaryData, state: BattleState) -> bool:
	var weapon: WeaponData = merc.equipped_weapon
	if weapon == null or not weapon.is_ranged or target == null:
		return false
	if AttackSystem.melee_makeshift(merc).is_empty():
		return false
	if state.battlefield != null and state.distance_to(merc, target) > 1:
		return false
	return merc.ammo_loaded <= 0 or merc.weapon_misfired \
		or ConstStates.has_state(merc, ConstStates.THREATENED)


#spend:rep:1:reload_free (Blowgun Quick Reload): pays 1 ReP to refill the chamber after a hit or a miss.
static func _rep_reload_free(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
		if perk.effect_dsl != "spend:rep:1:reload_free":
			continue
		if merc.current_rep >= 1 and merc.equipped_weapon != null:
			var w := merc.equipped_weapon
			if w.is_ranged and merc.ammo_loaded < w.chamber:
				var ammo := merc.ammo_loaded_type
				var avail: int = merc.ammo_inventory.get(ammo, 0)
				var count := mini(w.chamber - merc.ammo_loaded, avail)
				if count > 0:
					merc.current_rep -= 1
					merc.ammo_loaded += count
					merc.ammo_inventory[ammo] -= count
					var remaining: int = merc.ammo_inventory.get(ammo, 0)
					lines.append("  %s reloads for free (1 ReP)! [%dc+%dr]" % [BattleState.colored_name(merc, state),
						merc.ammo_loaded, remaining])
		break


#A weak hit is worth trading for a shove when the shove buys enough position.
static func _prefer_shove(merc: MercenaryData, target: MercenaryData, damage: int, state: BattleState) -> bool:
	if state == null or state.battlefield == null or target == null:
		return false
	var score := ShoveOutcomeFacet.single_pace_score(merc, target, state, state.get_allies(merc))
	var result := false
	if damage <= 1:
		result = score >= 0.2
	elif damage == 2:
		result = score >= 0.45
	else:
		result = score >= 0.7
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("SHOVE INSTEAD: %s vs %s dmg=%d score=%.2f -> %s" % [
			merc.merc_name, target.merc_name, damage, score, str(result)])
	return result


#Damage unless a choose arm replaced it, then the on_hit reactives, then the on_damage reactives gated on the damage dealt.
static func resolve_hit(merc: MercenaryData, target: MercenaryData, atk: Dictionary, final_damage: int,
		used_perk_effect: bool, hp_before: int, state: BattleState, enhancements: int) -> Array[String]:
	var lines: Array[String] = []
	if not used_perk_effect:
		lines.append_array(CombatApplicator.apply_hit(merc, target, atk, final_damage, atk["damage_type"], state, 0))
	var dealt_raw: int = final_damage if not used_perk_effect else hp_before - ExcessPool.hp_total(target)
	if used_perk_effect:
		atk["damage_dealt"] = maxi(0, dealt_raw)
	if BattleState._is_alive(target):
		lines.append_array(WeaponReactiveSystem.apply_on_hit(merc, target, atk, state))
	if dealt_raw > 0 and BattleState._is_alive(target):
		lines.append_array(WeaponReactiveSystem.fire_trigger(merc, "on_damage", target, atk, state,
				int(atk.get("enhancements", 0))))
		if dealt_raw >= 2:
			lines.append_array(WeaponReactiveSystem.fire_trigger(merc, "on_damage_2_plus", target, atk, state, enhancements))
	return lines


#Returns extra damage from on_crit weapon perks and applies their side effects.
static func on_crit_damage_bonus(merc: MercenaryData, lines: Array[String]) -> int:
	var bonus: int = 0
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
		if "on_crit:spend_ammo_5s" in perk.effect_dsl:
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
