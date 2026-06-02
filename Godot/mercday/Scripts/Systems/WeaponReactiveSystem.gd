class_name WeaponReactiveSystem


static func fire_trigger(attacker: MercenaryData, trigger: String, target: MercenaryData, atk: Dictionary, state: BattleState, enhancements: int) -> Array[String]:
	return _fire_weapon_reactive(attacker, trigger, target, atk, state, enhancements)


static func apply_on_hit(merc: MercenaryData, target: MercenaryData, _weapon, result: Dictionary, state: BattleState) -> Array[String]:
	return _fire_weapon_reactive(merc, "on_hit", target, result, state, result.get("enhancements", 0))


static func apply_on_miss(merc: MercenaryData, target: MercenaryData, _weapon, result: Dictionary, state: BattleState) -> Array[String]:
	return _fire_weapon_reactive(merc, "on_miss", target, result, state, result.get("enhancements", 0))


static func apply_on_damage(merc: MercenaryData, target: MercenaryData, _weapon, result: Dictionary, state: BattleState) -> Array[String]:
	return _fire_weapon_reactive(merc, "on_damage", target, result, state, result.get("enhancements", 0))


static func apply_after_attack(merc: MercenaryData, target: MercenaryData, _weapon, result: Dictionary, state: BattleState) -> Array[String]:
	return _fire_weapon_reactive(merc, "after_attack", target, result, state, result.get("enhancements", 0))


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
					lines.append_array(CombatApplicator.apply_damage(attacker, target, bonus, atk.get("damage_type", "Strike"), state))
					lines.append("  %s activates %s!" % [_cn(attacker, state), perk.trait_name.split("|")[-1]])
			"throw_attack":
				if target == null:
					continue
				attacker.current_ep -= 1
				var thrown_atk := AttackSystem.execute_attack(attacker, enhancements, 0, target)
				lines.append("  %s throws weapon (reactive)!" % _cn(attacker, state))
				if thrown_atk.get("damage", 0) > 0:
					lines.append_array(CombatApplicator.apply_damage(attacker, target, thrown_atk["damage"], thrown_atk["damage_type"], state))
			"attack_same_target":
				if target == null:
					continue
				attacker.current_ep -= 1
				var extra_atk := AttackSystem.execute_attack(attacker, enhancements, 0, target)
				var dmg_mod := int(parts[4]) if parts.size() > 4 else 0
				lines.append("  %s makes a reactive attack!" % _cn(attacker, state))
				if extra_atk.get("damage", 0) > 0:
					var final_d := maxi(0, extra_atk["damage"] + dmg_mod)
					lines.append_array(CombatApplicator.apply_damage(attacker, target, final_d, extra_atk["damage_type"], state))
			"attack":
				if target == null:
					continue
				attacker.current_ep -= 1
				var extra_atk := AttackSystem.execute_attack(attacker, enhancements, 0, target)
				var dtype: String = parts[3] if parts.size() > 3 else str(extra_atk.get("damage_type", "Strike"))
				if extra_atk.get("damage", 0) > 0:
					lines.append_array(CombatApplicator.apply_damage(attacker, target, extra_atk["damage"], dtype, state))
			"reload":
				attacker.current_ep -= 1
				lines.append_array(WeaponActionExecutor.execute_reload(attacker, state, enhancements))
			"attack_new_target":
				pass
			_:
				pass
	return lines


static func _cn(merc: MercenaryData, state: BattleState) -> String:
	var first := merc.merc_name.get_slice(" ", 0)
	for i: int in range(state.teams.size()):
		if (state.teams[i] as Array).has(merc):
			return "[color=%s]%s[/color]" % ["white" if i == 0 else "yellow", first]
	return first
