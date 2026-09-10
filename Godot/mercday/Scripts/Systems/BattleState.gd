class_name BattleState extends RefCounted

var teams: Array = []
var turn_queue: Array[MercenaryData] = []
var escalation: Dictionary = {}
var round_number: int = 0
var battlefield: BattlefieldArea   # null = no positioning active
var positions: Dictionary = {}     # MercenaryData -> Vector2i
var heights: Dictionary = {}       #MercenaryData -> int paces above the surface of its own cell
var floors: Dictionary = {}        # MercenaryData -> int floor_num (interior maps; 0 for ground floor)
var climbing_data: Dictionary = {} # MercenaryData -> {wall_pos, current_h, target_h, top_pos}
# plain int/String fields only; no Vector2i to avoid Variant-inference warnings
var los_cache: Dictionary = {}                #LOS result cache; key includes battlefield.los_version
var last_attacked: Dictionary = {}            # attacker -> last target attacked
var dying_source: Dictionary = {}             #MercenaryData -> the merc who put them into Dying
var last_ranged_targeted_round: Dictionary = {}  # target -> round_number when last targeted by a ranged attacker
var damage_dealt_this_round: Dictionary = {}  # attacker -> { target -> total dealt }
var damage_dealt_total: Dictionary = {}       #attacker -> {target -> total} for the whole encounter; never rotated
var damage_dealt_last_round: Dictionary = {}  # same, snapshot from previous round
var dropped_weapons: Dictionary = {}          # Vector2i -> Array[WeaponData]
var no_target_turns: Dictionary = {}          # MercenaryData -> consecutive turns without a valid attack target
var move_goals: Dictionary = {}              #MercenaryData -> Vector3i persistent move destination
var move_targets: Dictionary = {}            # MercenaryData -> MercenaryData current move target
var position_history: Dictionary = {}        # MercenaryData -> Array[Vector2i] (last 3 end-of-turn positions)
var no_progress_rounds: Dictionary = {}      # MercenaryData -> consecutive turns without position change
var _cached_winner: int = -2                  # set by AutoBattle._finalize() before merc reset
var _merc_team_index: Dictionary = {}         # MercenaryData -> int; populated in create()
var turn_ally_passable: Dictionary = {}       #MercenaryData -> Dictionary{Vector3i->true}; rebuilt per turn
var turn_path_dist: Dictionary = {}           #"a|b" pair key -> int path distance; rebuilt per turn
var movement_blocked: Dictionary = {}         # MercenaryData -> Dictionary{MercenaryData->true}; permanently unreachable enemies
var team_blocked_round: Dictionary = {}      # MercenaryData (target) -> int (round of last block increment)
var team_blocked_count: Dictionary = {}      # MercenaryData (target) -> int (allies blocked on this target in that round)
var pending_interact: Dictionary = {}        #MercenaryData -> Vector3i; door cell a move stopped in front of
var pace_pool: Dictionary = {}               #MercenaryData -> int paces banked by Move actions this turn
var move_plan: Dictionary = {}               #MercenaryData -> {"moves_allowed": int, "reserve_ap": int} for the next Move
var campaign_seeded: int = 0                 #knowledge tokens carried in from CampaignKnowledge at create()
var casualties: Array[MercenaryData] = []    #Filled by AutoBattle._finalize with every merc dead at the end
var carry_resources: bool = false            #When true create() keeps current hp, ep, mp and is_dead so damage carries between events

#Move-priced actions the pace pool never funds; they always pay their own AP.
const POOL_EXEMPT: Array[String] = ["Jump"]

var state_timers: Dictionary = {}


static func create(
		team_a: Array[MercenaryData],
		team_b: Array[MercenaryData],
		field: BattlefieldArea = null,
		carry: bool = false) -> BattleState:
	var state := BattleState.new()
	state.carry_resources = carry
	state.teams = [team_a, team_b]
	for _ti: int in range(state.teams.size()):
		for _tm: MercenaryData in state.teams[_ti]:
			state._merc_team_index[_tm] = _ti
	var all_mercs: Array[MercenaryData] = []
	all_mercs.assign(team_a + team_b)
	for merc: MercenaryData in all_mercs:
		if not carry:
			merc.current_hp = int(merc.stats.get("maximum_hit_points", 1))
			merc.is_dead = false
			merc.current_ep = int(merc.stats.get("maximum_endurance_points", 1))
			# TODO: apply ArmorData.ep_cost penalty here once the mechanic is implemented.
			# Guard: if equipped_armor and not has_perk_active(merc, "armor_ep_ignore:" + armor_class):
			# merc.current_ep -= merc.equipped_armor.ep_cost
			# TODO: apply ArmorData.fatigue penalty here once the mechanic is implemented.
			# Guard: if equipped_armor and not has_perk_active(merc, "armor_fatigue_zero:" + armor_class):
			# merc.current_ep -= merc.equipped_armor.fatigue
			merc.current_mp = int(merc.stats.get("maximum_magic_points", 0))
		merc.current_ap = 0
		#Excess HP, EP and MP are not reset here; they are cleared on contract return (ExcessPool.clear)
		merc.excess_ap = 0
		var campaign_snap := ConstStates.snapshot_campaign_states(merc)
		merc.active_states = {}
		ConstStates.restore_campaign_states(merc, campaign_snap)
		merc.death_test_hp_loss = 0
		merc.rot_hp_loss = 0
		merc.aim_active = false
		merc.weapon_misfired = false
		if merc.offhand_weapon != null:
			merc.inventory.append({"type": "weapon", "data": merc.offhand_weapon})
			merc.offhand_weapon = null
		merc.last_known_enemy_positions = {}
		merc.known_immunities = {}
		merc.last_seen_position = Vector3i(-1, -1, -1)
		merc.combat_idle_rounds = 0
		merc.ap_debt = 0
		_randomize_starting_draw(merc)
	_seed_team_knowledge(state)
	_seed_campaign_knowledge(state)
	state.turn_queue = TurnOrderSystem.sort_initiative(all_mercs)
	state.battlefield = field
	if field != null:
		SpawnPlacer.assign(state, team_a, team_b)
	return state


#Every merc starts knowing the passive immunity tokens of each teammate.
#Merc first name wrapped in the colour tag of its team, as every battle log line prints it.
static func colored_name(merc: MercenaryData, state: BattleState) -> String:
	var first := merc.merc_name.get_slice(" ", 0)
	if state == null:
		return first
	for i: int in range(state.teams.size()):
		if (state.teams[i] as Array).has(merc):
			return "[color=%s]%s[/color]" % ["white" if i == 0 else "yellow", first]
	return first


static func _seed_team_knowledge(state: BattleState) -> void:
	for team: Array in state.teams:
		for viewer: MercenaryData in team:
			for ally: MercenaryData in team:
				if ally == viewer:
					continue
				var tokens: Array = []
				for effect: String in ally.passive_effects:
					if is_knowledge_token(effect):
						tokens.append(effect)
				if not tokens.is_empty():
					viewer.known_immunities[ally] = tokens


#Carries campaign memory into this encounter; a token the target no longer holds is dropped.
static func _seed_campaign_knowledge(state: BattleState) -> void:
	var all_mercs: Array[MercenaryData] = []
	for team: Array in state.teams:
		for merc: MercenaryData in team:
			all_mercs.append(merc)
	var seeded: int = 0
	for viewer: MercenaryData in all_mercs:
		if viewer.merc_uid <= 0:
			continue
		for target: MercenaryData in all_mercs:
			if target == viewer or target.merc_uid <= 0:
				continue
			for token: String in CampaignKnowledge.known(viewer.merc_uid, target.merc_uid):
				if not target.passive_effects.has(token):
					continue
				var known: Array = viewer.known_immunities.get(target, [])
				if known.has(token):
					continue
				known.append(token)
				viewer.known_immunities[target] = known
				seeded += 1
	state.campaign_seeded = seeded


static func is_knowledge_token(token: String) -> bool:
	return token.begins_with("immune:") or token.begins_with("protected:") or token.begins_with("susceptible:")


#True when the viewer's team has seen the token on the target; a merc always knows its own tokens.
static func knows(viewer: MercenaryData, target: MercenaryData, token: String) -> bool:
	if viewer == null or target == null:
		return false
	if viewer == target:
		return true
	var known: Array = viewer.known_immunities.get(target, [])
	return known.has(token)


static func _randomize_starting_draw(merc: MercenaryData) -> void:
	var all_weapons: Array[WeaponData] = []
	if merc.equipped_weapon != null:
		all_weapons.append(merc.equipped_weapon)
	for entry: Dictionary in merc.inventory:
		if entry.get("type") == "weapon":
			var w: WeaponData = entry.get("data")
			if w != null and not all_weapons.has(w):
				all_weapons.append(w)

	if all_weapons.is_empty():
		merc.weapon_drawn = false
		merc.equipped_weapon = null
		return

	var preferred: WeaponData = null
	for w: WeaponData in all_weapons:
		if w.is_ranged and merc.ammo_loaded > 0:
			var temp := merc.equipped_weapon
			merc.equipped_weapon = w
			var viable := FirearmReliabilityFacet.aimed_viable(merc)
			merc.equipped_weapon = temp
			if viable:
				preferred = w
				break
	if preferred == null:
		for w: WeaponData in all_weapons:
			if not w.is_ranged and not w.is_throwable:
				preferred = w
				break
	if preferred != null:
		all_weapons.erase(preferred)
		all_weapons.shuffle()
		all_weapons.push_front(preferred)
	else:
		all_weapons.shuffle()
	merc.equipped_weapon = all_weapons[0]
	merc.weapon_drawn = true

	var new_inventory: Array = []
	for entry: Dictionary in merc.inventory:
		if entry.get("type") != "weapon":
			new_inventory.append(entry)
	for i: int in range(1, all_weapons.size()):
		new_inventory.append({"type": "weapon", "data": all_weapons[i]})
	merc.inventory = new_inventory


static func _reset_starting_ammo(merc: MercenaryData) -> void:
	var ranged_w: WeaponData = null
	if merc.equipped_weapon != null and merc.equipped_weapon.is_ranged:
		ranged_w = merc.equipped_weapon
	if ranged_w == null:
		for entry: Dictionary in merc.inventory:
			if entry.get("type") == "weapon":
				var w: WeaponData = entry.get("data")
				if w != null and w.is_ranged:
					ranged_w = w
					break
	merc.ammo_loaded = 0
	merc.ammo_loaded_type = ""
	merc.ammo_inventory = {}
	if ranged_w == null:
		return
	var prev_equipped := merc.equipped_weapon
	merc.equipped_weapon = ranged_w
	MercGenerator._equip_starting_ammo(merc)
	merc.equipped_weapon = prev_equipped


func start_of_turn(merc: MercenaryData) -> void:
	var max_ap := int(merc.stats.get("action_points", 5))
	merc.current_ap = maxi(0, max_ap - merc.ap_debt)
	merc.ap_debt = 0
	escalation[merc] = {}
	pace_pool.erase(merc)
	move_plan.erase(merc)
	merc.active_states.erase("draw_refused_turn")
	merc.active_states.erase("draw_priority_turn")


func end_of_turn(merc: MercenaryData, took_weapon_action: bool = false) -> void:
	pace_pool.erase(merc)
	move_plan.erase(merc)
	#Unspent AP is next turn's excess; excess still left from the previous turn is dropped.
	merc.excess_ap = maxi(0, merc.current_ap)
	merc.current_ap = 0
	TraitRuntime.on_turn_end(merc, self)
	RelationshipSystem.on_turn_end(merc, self)
	#Ending the turn with a real weapon in hand clears the escalating draw priority.
	if merc.equipped_weapon != null and merc.weapon_drawn and not merc.equipped_weapon.is_virtual:
		merc.active_states["draw_urgency"] = 0
	var hist: Array = position_history.get(merc, []) as Array
	var old_pos: Vector2i = hist[0] as Vector2i if not hist.is_empty() else Vector2i(-1, -1)
	hist.append(get_position(merc))
	if hist.size() > 3:
		hist.pop_front()
	position_history[merc] = hist
	var new_pos: Vector2i = get_position(merc)
	if not took_weapon_action and old_pos != Vector2i(-1, -1) and new_pos == old_pos:
		no_progress_rounds[merc] = (no_progress_rounds.get(merc, 0) as int) + 1
	else:
		no_progress_rounds.erase(merc)


#Both Moves price as one action: the second Move of a turn costs more whichever way it goes.
static func _cost_key(action_name: String) -> String:
	return "Move" if action_name.begins_with("Move ") else action_name


func get_cost(merc: MercenaryData, action_name: String, base_cost: int) -> int:
	return get_cost_after(merc, action_name, base_cost, 0)


#Cost of `action_name` once it has been taken `extra_uses` more times this turn.
func get_cost_after(merc: MercenaryData, action_name: String, base_cost: int, extra_uses: int) -> int:
	var times_used: int = extra_uses
	if escalation.has(merc):
		times_used += escalation[merc].get(_cost_key(action_name), 0)
	var cost := base_cost + times_used
	cost *= ConstStates.cost_multiplier(merc, "ap")
	return cost


func get_pace_pool(merc: MercenaryData) -> int:
	return int(pace_pool.get(merc, 0))


#Timed states: merc -> {state_name: {"expires": round, "remove": spec}}; expires 0 never runs out.
func set_state_timer(merc: MercenaryData, state_name: String, expires_round: int, remove_spec: String) -> void:
	if not state_timers.has(merc):
		state_timers[merc] = {}
	state_timers[merc][state_name] = {"expires": expires_round, "remove": remove_spec}


func get_state_timer(merc: MercenaryData, state_name: String) -> Dictionary:
	if not state_timers.has(merc):
		return {}
	return (state_timers[merc] as Dictionary).get(state_name, {})


func clear_state_timer(merc: MercenaryData, state_name: String) -> void:
	if state_timers.has(merc):
		(state_timers[merc] as Dictionary).erase(state_name)


#True while a living merc still holds a state whose timer has not run out.
func any_timed_state_pending() -> bool:
	for merc: MercenaryData in state_timers.keys():
		if not _is_alive(merc):
			continue
		for state_name: String in (state_timers[merc] as Dictionary).keys():
			if not ConstStates.has_state(merc, state_name):
				continue
			var expires := int((state_timers[merc][state_name] as Dictionary).get("expires", 0))
			if expires == 0 or expires > round_number:
				return true
	return false


#At battle end every held campaign state becomes a campaign-minute expiry; -1 marks one with no timer.
func export_campaign_timers() -> void:
	var now: int = CampaignClock.now()
	var names: Array[String] = ConstStates.campaign_state_names()
	for team: Array in teams:
		for merc: MercenaryData in team:
			for state_name: String in names:
				if ConstStates.has_state(merc, state_name):
					merc.campaign_states[state_name] = _campaign_expiry(merc, state_name, now)
				else:
					merc.campaign_states.erase(state_name)


func _campaign_expiry(merc: MercenaryData, state_name: String, now: int) -> int:
	var expires: int = int(get_state_timer(merc, state_name).get("expires", 0))
	if expires > 0:
		var rounds: int = expires - round_number
		return now + maxi(1, int(ceil(float(rounds) / float(StateInfliction.ROUNDS_PER_MINUTE))))
	var minutes: int = ConstStates.removal_minutes(state_name)
	if minutes > 0:
		return now + minutes
	return -1


func get_timed_states(merc: MercenaryData) -> Array[String]:
	var names: Array[String] = []
	if state_timers.has(merc):
		for k: String in (state_timers[merc] as Dictionary).keys():
			names.append(k)
	return names


func set_pace_pool(merc: MercenaryData, paces: int) -> void:
	pace_pool[merc] = maxi(0, paces)


#A Move funded by banked paces costs no AP and does not escalate.
func move_cost(merc: MercenaryData, action_name: String, base_cost: int) -> int:
	if get_pace_pool(merc) > 0 and not POOL_EXEMPT.has(action_name):
		return 0
	return get_cost(merc, action_name, base_cost)


func record_action(merc: MercenaryData, action_name: String) -> void:
	if not escalation.has(merc):
		escalation[merc] = {}
	var key := _cost_key(action_name)
	escalation[merc][key] = escalation[merc].get(key, 0) + 1


func spend_ap(merc: MercenaryData, amount: int) -> void:
	var available := maxi(0, merc.excess_ap) + merc.current_ap
	var actual := mini(amount, maxi(0, available))
	var from_excess := mini(maxi(0, merc.excess_ap), actual)
	merc.excess_ap -= from_excess
	merc.current_ap -= (actual - from_excess)


func can_afford(merc: MercenaryData, cost: int) -> bool:
	return (merc.excess_ap + merc.current_ap) >= cost


func get_enemies(merc: MercenaryData) -> Array[MercenaryData]:
	var i: int = _merc_team_index.get(merc, -1)
	if i < 0:
		return []
	var result: Array[MercenaryData] = []
	for m: MercenaryData in teams[1 - i]:
		if _is_alive(m):
			result.append(m)
	return result


func get_allies(merc: MercenaryData) -> Array[MercenaryData]:
	var i: int = _merc_team_index.get(merc, -1)
	if i < 0:
		return []
	var result: Array[MercenaryData] = []
	for m: MercenaryData in teams[i]:
		if m != merc and _is_alive(m):
			result.append(m)
	return result


#The observer and every living ally record the token for the target; logged once per event.
func learn_token(observer: MercenaryData, target: MercenaryData, token: String) -> void:
	if observer == null or target == null or token == "":
		return
	var learners: Array[MercenaryData] = [observer]
	learners.append_array(get_allies(observer))
	var count := 0
	for viewer: MercenaryData in learners:
		if viewer == target:
			continue
		var known: Array = viewer.known_immunities.get(target, [])
		if known.has(token):
			continue
		known.append(token)
		viewer.known_immunities[target] = known
		CampaignKnowledge.learn(viewer.merc_uid, target.merc_uid, token)
		count += 1
	if count > 0 and EncounterLogger.is_active():
		EncounterLogger.log_verbose("IMMUNITY LEARNED: %s %s %s learners=%d" % [
			observer.merc_name, target.merc_name, token, count])


#Records a passive state immunity the observer just saw; state-granted immunities are not recorded.
func learn_state_immunity(observer: MercenaryData, target: MercenaryData, state_name: String) -> void:
	if ConstStates.immune_source(target, state_name) != "passive":
		return
	learn_token(observer, target, "immune:" + ConstStates.normalize_token(state_name))


func clear_encounter_cache() -> void:
	turn_ally_passable.clear()
	turn_path_dist.clear()
	los_cache.clear()


static func _is_alive(merc: MercenaryData) -> bool:
	return not merc.is_dead and (merc.current_hp > 0 or ConstStates.has_state(merc, ConstStates.DYING))


func get_position(merc: MercenaryData) -> Vector2i:
	if not positions.has(merc):
		return Vector2i(-1, -1)
	return positions[merc]


func set_position(merc: MercenaryData, pos: Vector2i) -> void:
	positions[merc] = pos


func get_height(merc: MercenaryData) -> int:
	if not heights.has(merc):
		return 0
	return heights[merc]


#Altitude above the mover's own cell surface, not an absolute elevation.
func set_height(merc: MercenaryData, h: int) -> void:
	var max_h := battlefield.height - 1 if battlefield != null else 0
	heights[merc] = clamp(h, 0, max_h)


#Elevation in paces with 0 at ground level; basement floors are negative.
func absolute_height(merc: MercenaryData) -> int:
	if battlefield == null:
		return get_height(merc)
	var ground_ref: float = battlefield.floor_base_elevation(0) if battlefield.is_interior_map else 0.0
	var base: float = battlefield.cell_base_elevation(get_position(merc), get_floor(merc))
	return int(floor(base - ground_ref)) + get_height(merc)


#Full 3D path node for a merc: grid cell plus floor index.
func pos3(merc: MercenaryData) -> Vector3i:
	var p := get_position(merc)
	return Vector3i(p.x, p.y, get_floor(merc))


func set_pos3(merc: MercenaryData, p: Vector3i) -> void:
	positions[merc] = Vector2i(p.x, p.y)
	floors[merc] = p.z


#Nodes a merc may path through that would otherwise be blocked: living allies plus
#the generator's reserved corridor cells (ground floor only).
func ally_passable_3d(merc: MercenaryData) -> Dictionary:
	if turn_ally_passable.has(merc):
		return turn_ally_passable[merc] as Dictionary
	var result: Dictionary = {}
	for ally: MercenaryData in get_allies(merc):
		if not _is_alive(ally) or ConstStates.has_state(ally, ConstStates.DEPOSED):
			continue
		if not positions.has(ally):
			continue
		result[pos3(ally)] = true
	result.merge(nav_passable_3d())
	turn_ally_passable[merc] = result
	return result


#Carved exterior corridor cells as floor 0 nodes; interior corridor cells are 2D across floors, so none there.
func nav_passable_3d() -> Dictionary:
	var result: Dictionary = {}
	if battlefield == null or battlefield.is_interior_map:
		return result
	for c: Vector2i in battlefield.get_nav_passable_cells().keys():
		result[Vector3i(c.x, c.y, 0)] = true
	return result


func get_floor(merc: MercenaryData) -> int:
	return floors.get(merc, 0)


func get_climbing_data(merc: MercenaryData) -> Dictionary:
	return climbing_data.get(merc, {}) as Dictionary


func clear_climbing(merc: MercenaryData) -> void:
	climbing_data.erase(merc)


# 3D Chebyshev distance: max(|dx|, |dy|, |dz|). Returns 0 when no battlefield.
func distance_to(a: MercenaryData, b: MercenaryData) -> int:
	if battlefield == null:
		return 0
	var pa := get_position(a)
	var pb := get_position(b)
	var ea := battlefield.cell_base_elevation(pa, get_floor(a)) + float(get_height(a))
	var eb := battlefield.cell_base_elevation(pb, get_floor(b)) + float(get_height(b))
	var dz := int(round(absf(ea - eb)))
	return maxi(maxi(abs(pa.x - pb.x), abs(pa.y - pb.y)), dz)


#A* walking distance between two mercs in pace cost. 9999 when no route exists.
#Cached per turn; cleared alongside turn_ally_passable.
func path_distance_to(a: MercenaryData, b: MercenaryData) -> int:
	if battlefield == null:
		return 0
	var key := "%d|%d" % [a.get_instance_id(), b.get_instance_id()]
	if turn_path_dist.has(key):
		return turn_path_dist[key] as int
	var path := Pathfinder.find_path(pos3(a), pos3(b), battlefield, ally_passable_3d(a), 1.0, PathTargeter.is_flying(a), true, int(a.stats.get("size", 1)), get_height(a))
	var result := 9999 if path.is_empty() else path.size() - 1
	turn_path_dist[key] = result
	return result


# 2D horizontal-only Chebyshev distance (used for cover angle and flanking checks).
func distance_2d(a: MercenaryData, b: MercenaryData) -> int:
	if battlefield == null:
		return 0
	var pa := get_position(a)
	var pb := get_position(b)
	return maxi(abs(pa.x - pb.x), abs(pa.y - pb.y))


#Cover is derived from line of sight; no stored cover state.
#COVERED_FULL: the attacker cannot see the target at all.
#COVERED_PARTIAL: the attacker sees the target only through a grazing line.
func is_covered_from(merc: MercenaryData, attacker: MercenaryData, cover_type: String) -> bool:
	if battlefield == null or attacker == null or merc == null:
		return false
	var los := LineOfSight.check(self, attacker, merc)
	match cover_type:
		ConstStates.COVERED_FULL:
			return not (los["visible"] as bool)
		ConstStates.COVERED_PARTIAL:
			return str(los["cover"]) == "partial"
	return false


#Would the target be fully covered from a hypothetical attacker of from_size at from_pos?
func is_covered_from_pos(target: MercenaryData, from_pos: Vector3i, from_size: int = 1) -> bool:
	if battlefield == null or target == null:
		return false
	return not (LineOfSight.check_from(self, from_pos, 0, maxi(1, from_size), target)["visible"] as bool)


func record_ranged_targeted(target: MercenaryData) -> void:
	last_ranged_targeted_round[target] = round_number


func record_damage_dealt(attacker: MercenaryData, target: MercenaryData, amount: int) -> void:
	if amount <= 0:
		return
	if not damage_dealt_this_round.has(attacker):
		damage_dealt_this_round[attacker] = {}
	damage_dealt_this_round[attacker][target] = damage_dealt_this_round[attacker].get(target, 0) + amount
	if attacker == null or target == null or attacker == target:
		return
	if int(_merc_team_index.get(attacker, -1)) == int(_merc_team_index.get(target, -2)):
		return
	if not damage_dealt_total.has(attacker):
		damage_dealt_total[attacker] = {}
	damage_dealt_total[attacker][target] = damage_dealt_total[attacker].get(target, 0) + amount


func rotate_round_damage() -> void:
	damage_dealt_last_round = damage_dealt_this_round
	damage_dealt_this_round = {}


func is_battle_over() -> bool:
	for team: Array in teams:
		var any_capable := false
		for m: MercenaryData in team:
			if _is_alive(m):
				any_capable = true
				break
		if not any_capable:
			return true
	return false


func drop_weapon(merc: MercenaryData) -> void:
	var weapon := merc.equipped_weapon
	if weapon == null:
		return
	var pos := get_position(merc)
	if not dropped_weapons.has(pos):
		dropped_weapons[pos] = []
	(dropped_weapons[pos] as Array).append({
		"weapon": weapon,
		"ammo_loaded": merc.ammo_loaded,
		"ammo_loaded_type": merc.ammo_loaded_type,
		"floor": get_floor(merc),
	})
	merc.equipped_weapon = null
	merc.weapon_drawn = false
	merc.ammo_loaded = 0
	merc.ammo_loaded_type = ""


func retrieve_dropped_weapons_for(merc: MercenaryData) -> void:
	if dropped_weapons.is_empty():
		return
	var merc_pos := get_position(merc)
	var merc_floor := get_floor(merc)
	for pos: Vector2i in dropped_weapons.keys().duplicate():
		if maxi(abs(pos.x - merc_pos.x), abs(pos.y - merc_pos.y)) <= 1:
			var kept: Array = []
			for entry: Dictionary in dropped_weapons[pos]:
				if int(entry.get("floor", merc_floor)) != merc_floor:
					kept.append(entry)
					continue
				merc.inventory.append({"type": "weapon", "data": entry["weapon"]})
			if kept.is_empty():
				dropped_weapons.erase(pos)
			else:
				dropped_weapons[pos] = kept


#floor_num -1 keeps every entry; otherwise entries tagged with another floor are hidden.
func get_dropped_weapons_at(pos: Vector2i, floor_num: int = -1) -> Array:
	var stack: Array = dropped_weapons.get(pos, [])
	if floor_num < 0 or stack.is_empty():
		return stack
	var out: Array = []
	for entry: Dictionary in stack:
		if int(entry.get("floor", floor_num)) == floor_num:
			out.append(entry)
	return out


func remove_dropped_weapon(pos: Vector2i, entry: Dictionary) -> void:
	if not dropped_weapons.has(pos):
		return
	(dropped_weapons[pos] as Array).erase(entry)
	if (dropped_weapons[pos] as Array).is_empty():
		dropped_weapons.erase(pos)


func is_position_occupied(pos: Vector2i, exclude_merc: MercenaryData, floor_num: int) -> bool:
	for m: MercenaryData in positions.keys():
		if m == exclude_merc:
			continue
		if not _is_alive(m):
			continue
		if get_floor(m) != floor_num:
			continue
		if positions[m] == pos:
			return true
	return false


func get_winner() -> int:
	if _cached_winner != -2:
		return _cached_winner
	var winner := -1
	for i: int in range(teams.size()):
		for m: MercenaryData in teams[i]:
			if m.current_hp > 0:
				if winner >= 0:
					return -1
				winner = i
				break
	return winner
