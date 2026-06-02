class_name BattleStateUpdater


static func update_auto_states(merc: MercenaryData, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	if state.battlefield == null:
		return lines

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

	return lines


static func apply_dot_effects(merc: MercenaryData, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
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

	return lines


static func check_stalemate(state: BattleState) -> bool:
	if state.teams.size() < 2:
		return false
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
	if team_hp[0] != team_hp[1]:
		return false
	if not is_equal_approx(team_accuracy[0], team_accuracy[1]):
		return false
	if not is_equal_approx(team_pace[0], team_pace[1]):
		return false
	return true


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


static func _cn(merc: MercenaryData, state: BattleState) -> String:
	var first := merc.merc_name.get_slice(" ", 0)
	for i: int in range(state.teams.size()):
		if (state.teams[i] as Array).has(merc):
			return "[color=%s]%s[/color]" % ["white" if i == 0 else "yellow", first]
	return first
