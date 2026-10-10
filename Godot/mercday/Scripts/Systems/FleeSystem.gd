class_name FleeSystem

#A losing merc whose flee value reaches the gate may break and run for the map edge; abandoners leave the party after it.

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")

static var enabled: bool = true
#Test hook: each entry is popped as the next d100 before any random roll.
static var forced_rolls: Array[int] = []
static var forced: Dictionary = {}   #merc -> true; kidnap forces flee with no gate, roll or Terrified
static var checks_rolled: int = 0
static var withdraws: int = 0
static var goal_cache: Dictionary = {}     #MercenaryData -> {"round": int, "goal": Vector3i}
static var _immune_logged: Dictionary = {}  #MercenaryData -> true


static func reset() -> void:
	forced_rolls.clear()
	checks_rolled = 0
	withdraws = 0
	forced.clear()
	goal_cache.clear()
	_immune_logged.clear()
	enabled = true


static func begin_battle(_state: BattleState) -> void:
	goal_cache.clear()
	_immune_logged.clear()


static func _team_index(merc: MercenaryData, state: BattleState) -> int:
	if state == null:
		return -1
	for i: int in range(state.teams.size()):
		if (state.teams[i] as Array).has(merc):
			return i
	return -1


#Percent of the team's summed maximum HP that is gone; escaped members are left out of both sums.
static func missing_percent(team: Array, state: BattleState) -> float:
	var total := 0.0
	var missing := 0.0
	for m: Variant in team:
		if not (m is MercenaryData) or state.escaped.has(m):
			continue
		var merc := m as MercenaryData
		var mx := maxf(1.0, float(merc.stats.get("maximum_hit_points", 0)))
		total += mx
		if merc.is_dead or merc.current_hp <= 0 or state.removed_from_field.has(merc):
			missing += mx
		else:
			missing += clampf(mx - float(merc.current_hp), 0.0, mx)
	return missing / maxf(1.0, total) * 100.0


static func swing(merc: MercenaryData, state: BattleState) -> float:
	if state == null or state.teams.size() < 2:
		return 0.0
	var i := _team_index(merc, state)
	if i == -1:
		return 0.0
	return missing_percent(state.teams[i] as Array, state) - missing_percent(state.teams[1 - i] as Array, state)


static func spread(merc: MercenaryData, state: BattleState) -> float:
	var i := _team_index(merc, state)
	if i == -1:
		return 0.0
	var team := state.teams[i] as Array
	var count := 0
	for m: Variant in team:
		if m == merc or not (m is MercenaryData):
			continue
		if is_fleeing(m as MercenaryData) or state.escaped.has(m):
			count += 1
	return count / float(team.size()) * 100.0


#True when this turn is a flee turn: a merc already fleeing keeps running, or a new check sends it running.
static func start_of_turn(merc: MercenaryData, state: BattleState, lines: Array[String]) -> bool:
	if state == null or not BattleState._is_alive(merc) or ConstStates.has_state(merc, ConstStates.DYING):
		return false
	if forced.has(merc) and merc.flee_intent:
		return true
	if merc.flee_intent:
		if ConstStates.has_state(merc, ConstStates.TERRIFIED):
			state.clear_state_timer(merc, ConstStates.TERRIFIED)
			return true
		lines.append_array(stop(merc))
	if not enabled or not state.flee_enabled:
		return false
	var sheet := float(merc.stats.get("flee", 0.0))
	var sw := swing(merc, state)
	var v := sheet + sw
	if sw <= 0.0 or v < _CONFIG.flee_gate:
		return false
	if ConstStates.is_immune(merc, ConstStates.TERRIFIED):
		if not _immune_logged.has(merc):
			_immune_logged[merc] = true
			lines.append("  FLEE IMMUNE: %s" % merc.merc_name)
		return false
	var sp := spread(merc, state)
	checks_rolled += 1
	var a := Dice.d100(forced_rolls)
	var head := "  FLEE CHECK: %s flee %.1f (sheet %.1f swing %.1f spread %.1f) d100 %d" % [
			merc.merc_name, v + sp, sheet, sw, sp, a]
	if float(a) > v + sp:
		lines.append(head + " -> stays")
		return false
	var b := Dice.d100(forced_rolls)
	var abandons := float(b) <= v / 2.0
	lines.append(head + " -> runs; d100 %d vs %.1f -> %s" % [b, v / 2.0, "abandons" if abandons else "returns"])
	merc.flee_intent = true
	merc.flee_abandons = abandons
	merc.flee_escape_paces = 0
	var rm: Array[String] = ["interact"]
	var ok := StateCascade.apply_state(merc, ConstStates.TERRIFIED, ConstStates.get_source(merc, ConstStates.TERRIFIED),
			"", "engine:flee", rm)
	if not ok:
		_reset_flee_fields(merc)
		return false
	state.clear_state_timer(merc, ConstStates.TERRIFIED)
	lines.append("  %s breaks and runs!" % BattleState.colored_name(merc, state))
	return true


static func is_flee_terrified(merc: MercenaryData) -> bool:
	for src: Dictionary in StateSources.state_sources(merc, ConstStates.TERRIFIED):
		if str(src.get("kind", "")) == "engine" and str(src.get("name", "")) == "flee":
			return true
	return false


static func is_fleeing(merc: MercenaryData) -> bool:
	return merc != null and merc.flee_intent \
		and (forced.has(merc) or ConstStates.has_state(merc, ConstStates.TERRIFIED))


static func hold(merc: MercenaryData, state: BattleState) -> void:
	if state != null and is_fleeing(merc):
		state.clear_state_timer(merc, ConstStates.TERRIFIED)


static func _reset_flee_fields(merc: MercenaryData) -> void:
	merc.flee_intent = false
	merc.flee_abandons = false
	merc.flee_escape_paces = 0


static func stop(merc: MercenaryData) -> Array[String]:
	_reset_flee_fields(merc)
	goal_cache.erase(merc)
	forced.erase(merc)
	var out: Array[String] = ["  FLEE ENDED: %s" % merc.merc_name]
	return out


static func escaping_bonus(enemy: MercenaryData, state: BattleState) -> float:
	if state == null or not is_fleeing(enemy):
		return 0.0
	if not AuraTactics.is_aura_source(enemy) and not state.priority_targets.has(enemy):
		return 0.0
	return minf(1.25, 0.5 + 0.05 * float(enemy.flee_escape_paces))


static func pursuit_paces(enemy: MercenaryData, state: BattleState) -> float:
	return escaping_bonus(enemy, state) * float(_CONFIG.flee_pursuit_paces)


static func has_better_quarry(cur: MercenaryData, valid: Array, state: BattleState) -> bool:
	if state == null:
		return false
	var own := escaping_bonus(cur, state)
	for other: Variant in valid:
		if other is MercenaryData and other != cur and escaping_bonus(other as MercenaryData, state) > own:
			return true
	return false


static func clear_merc(merc: MercenaryData) -> void:
	if is_flee_terrified(merc):
		StateCascade.remove_state(merc, ConstStates.TERRIFIED)
	merc.off_field = false
	_reset_flee_fields(merc)
	forced.erase(merc)
	merc.advantage_immune = false
