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
	if not is_flanked:
		is_flanked = _saber_flanked(merc, state)
	_set_auto_state(merc, ConstStates.FLANKED, is_flanked, "flanked", state, lines)

	var aura_source: MercenaryData = null
	var aura_token := StateTokens.normalize_token(ConstStates.EMBOLDENED)
	for ally: MercenaryData in state.get_allies(merc):
		if ally.auras.is_empty() or ConstStates.has_state(ally, ConstStates.DYING) \
				or ConstStates.has_state(ally, ConstStates.UNCONSCIOUS):
			continue
		for aura: Dictionary in ally.auras:
			if StateTokens.normalize_token(str(aura.get("state", ""))) != aura_token:
				continue
			if state.distance_to(merc, ally) > int(aura.get("paces", 0)):
				continue
			if _aura_reaches(merc, ally, str(aura.get("gate", "")), state):
				aura_source = ally
				break
		if aura_source != null:
			break
	var aura_label := "emboldened"
	if aura_source != null:
		aura_label = "emboldened by %s" % aura_source.merc_name
	_set_auto_state(merc, ConstStates.EMBOLDENED, aura_source != null, aura_label, state, lines)

	return lines


#Saber Flank: an unflanked saber holder flanks every enemy standing within 1 pace of it.
static func _saber_flanked(merc: MercenaryData, state: BattleState) -> bool:
	for enemy: MercenaryData in state.get_enemies(merc):
		if not BattleState._is_alive(enemy) or enemy.off_field:
			continue
		if ConstStates.has_state(enemy, ConstStates.FLANKED):
			continue
		if state.get_floor(enemy) != state.get_floor(merc) or state.distance_to(merc, enemy) > 1:
			continue
		if not WeaponArmorPerkLibrary.has_weapon_passive(enemy, "weapon_passive:adjacent_flank_if_not_flanked"):
			continue
		return true
	return false


#Applies or removes an automatic state on the rising or falling edge, logging label on the rise.
static func _set_auto_state(merc: MercenaryData, state_name: String, wanted: bool, label: String,
		state: BattleState, lines: Array[String]) -> void:
	var want := wanted and not ConstStates.is_immune(merc, state_name)
	var had := ConstStates.has_state(merc, state_name)
	if want and not had:
		StateCascade.apply_state(merc, state_name, null, "", "engine:" + StateTokens.normalize_token(state_name))
		lines.append("  %s is %s!" % [BattleState.colored_name(merc, state), label])
	elif not want and had:
		StateCascade.remove_state(merc, state_name)


#True when merc still senses the aura source: hearing needs range only, sight needs LOS.
static func _aura_reaches(merc: MercenaryData, source: MercenaryData, gate: String,
		state: BattleState) -> bool:
	if gate != "sight" and not ConstStates.has_state(merc, ConstStates.DEAFENED):
		return true
	if gate == "hearing" or ConstStates.has_state(merc, ConstStates.BLINDED):
		return false
	return bool(LineOfSight.check(state, merc, source)["visible"])


static func apply_dot_effects(merc: MercenaryData, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	for dot: Dictionary in StateEffects.dot_effects(merc):
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
		else:
			text = "  %s takes %d %s damage from %s." % [BattleState.colored_name(merc, state), amount, dot_type, dot_state]
		var ex_note := " (%d ExHP)" % int(taken["from_excess"]) if int(taken["from_excess"]) > 0 else ""
		lines.append("%s (HP [color=red]%d->%d[/color])%s" % [
			text, maxi(0, hp_before), maxi(0, merc.current_hp), ex_note])
		check_hp_death(merc, state, lines)
		if merc.off_field:
			break

	return lines


#Dying, death or removal from the field for a merc a start-of-turn effect brought to 0 HP.
static func check_hp_death(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	if state != null and state.no_death_removal and ExcessPool.hp_total(merc) <= 1:
		remove_without_death(merc, state, lines)
		return
	if merc.current_hp > 0:
		return
	if ConstStates.has_state(merc, ConstStates.DYING):
		mark_dead(merc, "  %s is dead!" % BattleState.colored_name(merc, state), lines)
	else:
		mark_dying(merc, BattleState.colored_name(merc, state), lines)


#Pulls a merc the no-death rule keeps alive off the field, clearing Dying and its recorded source.
static func remove_without_death(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	merc.current_hp = 1
	if ConstStates.has_state(merc, ConstStates.DYING):
		StateCascade.remove_state(merc, ConstStates.DYING)
	state.dying_source.erase(merc)
	state.remove_from_field(merc, "out", lines)


#Full death tail: dead flags and death line, the verbose note, on-kill perks when asked, then the death hooks.
static func kill(merc: MercenaryData, killer: MercenaryData, state: BattleState, lines: Array[String],
		death_line: String, verbose: String, kill_perks: bool = true) -> void:
	mark_dead(merc, death_line, lines)
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose(verbose)
	state.dying_source.erase(merc)
	if kill_perks:
		lines.append_array(CombatApplicator.handle_on_kill_perks(killer, merc, state))
	TraitRuntime.on_death(merc, killer, state, lines)
	StateInfliction.release_held_by(merc, state, lines)


#Sets a merc dead at 0 HP with Dying cleared and logs death_line.
static func mark_dead(merc: MercenaryData, death_line: String, lines: Array[String]) -> void:
	merc.current_hp = 0
	merc.is_dead = true
	StateCascade.remove_state(merc, ConstStates.DYING)
	lines.append(death_line)


#Puts a merc at 0 HP into Dying and logs the line; the caller records the dying source.
static func mark_dying(merc: MercenaryData, name_text: String, lines: Array[String]) -> void:
	merc.current_hp = 0
	StateCascade.apply_state(merc, ConstStates.DYING, null, "", "engine:dying")
	lines.append("  %s is dying!" % name_text)


