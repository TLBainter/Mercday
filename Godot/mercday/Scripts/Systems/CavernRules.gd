class_name CavernRules

#Water, crawling and the breath countdown of a cavern map.
#Every state this system applies carries an engine source, so no rest, Break Free or Get Up ends it;
#the cell the merc stands in does, through on_enter_cell, stand or on_surface.
const ENGINE_KIND := "engine"
const WATER_SOURCE := "water"
const CRAWL_SOURCE := "crawl"
const RUBBLE_SOURCE := "rubble"
#Paces a cell of water costs a merc whose armour cannot swim; it sinks on entry, so this only steers pathing.
const SINK_PACE_COST := 10


static func can_swim(merc: MercenaryData) -> bool:
	return float(merc.stats.get("swim", 0.0)) > 0.0


static func halves_swim(merc: MercenaryData) -> bool:
	return merc.equipped_armor != null and merc.equipped_armor.halve_swim


static func sinks(merc: MercenaryData) -> bool:
	return merc.equipped_armor != null and merc.equipped_armor.cannot_swim


static func water_pace_cost(merc: MercenaryData) -> int:
	if sinks(merc):
		return SINK_PACE_COST
	if can_swim(merc) and not halves_swim(merc):
		return 1
	return 2


#Run after the merc's position is updated to to_cell; true halts the walk because the merc sank.
static func on_enter_cell(merc: MercenaryData, from_cell: Vector2i, to_cell: Vector2i,
		state: BattleState, lines: Array[String]) -> bool:
	if state == null or state.battlefield == null:
		return false
	var field := state.battlefield
	var was_water := field.is_water(from_cell)
	var now_water := field.is_water(to_cell)
	if now_water and not was_water:
		apply(merc, ConstStates.DRENCHED, WATER_SOURCE)
		if not can_swim(merc) or sinks(merc):
			apply(merc, ConstStates.INHIBITED, WATER_SOURCE)
		if sinks(merc):
			var depth := field.water_depth(to_cell)
			state.set_sunk(merc, depth)
			apply(merc, ConstStates.DROWNING, WATER_SOURCE)
			lines.append("  %s sinks to the bottom of the pool (depth %d)!" % [
				BattleState.colored_name(merc, state), depth])
			return true
		if can_swim(merc):
			lines.append("  %s swims into the water." % BattleState.colored_name(merc, state))
		else:
			lines.append("  %s wades into the water, Inhibited." % BattleState.colored_name(merc, state))
	elif was_water and not now_water and not state.is_sunk(merc):
		release(merc, ConstStates.INHIBITED, WATER_SOURCE, state, "cause")
		lines.append("  %s climbs out of the water." % BattleState.colored_name(merc, state))
	if state.is_sunk(merc):
		return false
	var size := merc.unit_size()
	if field.clearance(to_cell) < float(size):
		if not merc.crawling:
			start_crawl(merc, state, lines)
	elif merc.crawling:
		stand(merc, state, lines)
	return false


#A climb out of a pool onto a dry cell; the merc is on the surface again whether it sank or swam.
static func on_surface(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	if state == null:
		return
	var was_sunk := state.is_sunk(merc)
	state.set_sunk(merc, 0)
	var dropped := release(merc, ConstStates.DROWNING, WATER_SOURCE, state, "cause")
	var unbound := release(merc, ConstStates.INHIBITED, WATER_SOURCE, state, "cause")
	if was_sunk or dropped or unbound:
		lines.append("  %s hauls out of the water." % BattleState.colored_name(merc, state))


#Deposed by choice, so immunity does not refuse it; the pace cap and the Get Up action are exempt while crawling.
static func start_crawl(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	merc.crawling = true
	apply(merc, ConstStates.DEPOSED, CRAWL_SOURCE, true)
	lines.append("  %s drops prone and crawls." % BattleState.colored_name(merc, state))


static func stand(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	merc.crawling = false
	if release(merc, ConstStates.DEPOSED, CRAWL_SOURCE, state, "stand"):
		lines.append("  %s stands up." % BattleState.colored_name(merc, state))


#Suffocating and Drowning share one countdown: Vigor rounds of breath, then 1 Maximum HP a turn.
#Vigor rounds clear of both restore the whole loss.
static func breath_turn_start(merc: MercenaryData, state: BattleState,
		lines: Array[String] = []) -> Array[String]:
	if merc.is_dead:
		return lines
	var vigor := maxi(1, int(merc.stats.get("vigor", 1)))
	if StateEffects.is_suffocating(merc):
		merc.suffocate_rounds += 1
		merc.breath_clear_rounds = 0
		if merc.suffocate_rounds > vigor:
			merc.suffocation_hp_loss += 1
			var cap := effective_max_hp(merc)
			merc.current_hp = mini(merc.current_hp, cap)
			lines.append("  %s cannot breathe! Maximum HP reduced by 1 (%d)." % [
				BattleState.colored_name(merc, state), cap])
			if merc.current_hp <= 0:
				BattleStateUpdater.check_hp_death(merc, state, lines)
		return lines
	if merc.suffocation_hp_loss <= 0 and merc.suffocate_rounds <= 0:
		return lines
	merc.breath_clear_rounds += 1
	if merc.breath_clear_rounds < vigor:
		return lines
	merc.suffocation_hp_loss = 0
	merc.suffocate_rounds = 0
	merc.breath_clear_rounds = 0
	lines.append("  %s breathes freely again; Maximum HP restored." % BattleState.colored_name(merc, state))
	return lines


static func effective_max_hp(merc: MercenaryData) -> int:
	var max_hp := int(merc.stats.get("maximum_hit_points", 1))
	return maxi(0, max_hp - merc.rot_hp_loss - merc.suffocation_hp_loss)


#True when only this system's water, crawl or rubble sources hold the state, so no action can end it.
static func is_cavern_sourced(merc: MercenaryData, state_name: String) -> bool:
	var sources := StateSources.state_sources(merc, state_name)
	if sources.is_empty():
		return false
	for src: Dictionary in sources:
		if str(src.get("kind", "")) != ENGINE_KIND:
			return false
		var name := str(src.get("name", ""))
		if name != WATER_SOURCE and name != CRAWL_SOURCE and name != RUBBLE_SOURCE:
			return false
	return true


static func apply(merc: MercenaryData, state_name: String, source_name: String,
		chosen: bool = false) -> bool:
	return StateCascade.apply_state(merc, state_name, null, "", ENGINE_KIND + ":" + source_name,
		StateCascade.until_removal("none"), chosen)


#Ends a state this system applied; when something else holds it up only the engine source is forgotten.
static func release(merc: MercenaryData, state_name: String, source_name: String,
		state: BattleState, reason: String) -> bool:
	if not ConstStates.has_state(merc, state_name):
		return false
	if not _engine_only(merc, state_name, source_name):
		StateSources.drop_source(merc, state_name, ENGINE_KIND, source_name)
		return false
	if not bool(StateCascade.remove_state(merc, state_name)["removed"]):
		return false
	StateInfliction.note_removed(merc, state_name, state, reason)
	return true


static func _engine_only(merc: MercenaryData, state_name: String, source_name: String) -> bool:
	var sources := StateSources.state_sources(merc, state_name)
	if sources.size() != 1:
		return false
	var src: Dictionary = sources[0]
	return str(src.get("kind", "")) == ENGINE_KIND and str(src.get("name", "")) == source_name
