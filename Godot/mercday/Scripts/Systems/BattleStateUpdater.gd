class_name BattleStateUpdater


static func update_auto_states(merc: MercenaryData, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	if state.battlefield == null:
		return lines

	var is_threatened := false
	var merc_weapon := merc.equipped_weapon
	if merc_weapon != null and (merc_weapon.is_ranged or merc_weapon.is_throwable):
		for enemy: MercenaryData in state.get_enemies(merc):
			if state.get_floor(enemy) != state.get_floor(merc):
				continue
			if state.distance_to(merc, enemy) <= 2:
				is_threatened = true
				break
	_set_auto_state(merc, ConstStates.THREATENED, is_threatened, "threatened", state, lines)

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
	_set_auto_state(merc, ConstStates.FLANKED, is_flanked, "flanked", state, lines)

	return lines


#Applies or removes an automatic state on the rising or falling edge, logging label on the rise.
static func _set_auto_state(merc: MercenaryData, state_name: String, wanted: bool, label: String,
		state: BattleState, lines: Array[String]) -> void:
	var want := wanted and not ConstStates.is_immune(merc, state_name)
	var had := ConstStates.has_state(merc, state_name)
	if want and not had:
		ConstStates.apply_state(merc, state_name, null, "", "engine:" + ConstStates.normalize_token(state_name))
		lines.append("  %s is %s!" % [BattleState.colored_name(merc, state), label])
	elif not want and had:
		ConstStates.remove_state(merc, state_name)


static func apply_dot_effects(merc: MercenaryData, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	for dot: Dictionary in ConstStates.dot_effects(merc):
		var amount: int = int(dot["amount"])
		if amount <= 0:
			continue
		var dot_state: String = str(dot["state"])
		var dot_type: String = str(dot["type"])
		var hp_before := merc.current_hp
		var taken := ExcessPool.take_hp(merc, amount)
		var dealt: int = int(taken["total"])
		LifepathTally.record_damage_taken(merc, dealt, dot_type)
		var src: MercenaryData = ConstStates.get_source(merc, dot_state)
		if src != null and state != null:
			state.record_damage_dealt(src, merc, dealt)
		var text := ""
		if dot_type == "Fire":
			text = "  %s is burning! Takes %d Fire damage." % [BattleState.colored_name(merc, state), amount]
		elif dot_state == ConstStates.SUFFOCATING:
			text = "  %s is suffocating! Takes %d damage." % [BattleState.colored_name(merc, state), amount]
		else:
			text = "  %s takes %d %s damage from %s." % [BattleState.colored_name(merc, state), amount, dot_type, dot_state]
		var ex_note := " (%d ExHP)" % int(taken["from_excess"]) if int(taken["from_excess"]) > 0 else ""
		lines.append("%s (HP [color=red]%d->%d[/color])%s" % [
			text, maxi(0, hp_before), maxi(0, merc.current_hp), ex_note])
		_check_dot_death(merc, state, lines)

	return lines


static func _check_dot_death(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	if merc.current_hp > 0:
		return
	if ConstStates.has_state(merc, ConstStates.DYING):
		merc.current_hp = 0
		merc.is_dead = true
		ConstStates.remove_state(merc, ConstStates.DYING)
		lines.append("  %s is dead!" % BattleState.colored_name(merc, state))
	else:
		merc.current_hp = 0
		ConstStates.apply_state(merc, ConstStates.DYING, null, "", "engine:dying")
		lines.append("  %s is dying!" % BattleState.colored_name(merc, state))


