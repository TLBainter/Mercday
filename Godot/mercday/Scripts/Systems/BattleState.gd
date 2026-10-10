class_name BattleState extends RefCounted

var teams: Array = []
var turn_queue: Array[MercenaryData] = []
var escalation: Dictionary = {}
var round_number: int = 0
var cave_in_chance: int = 1        #percent; rises per round and per Strike or Sonic roll
var cave_in_due: Array[int] = []   #round numbers whose end fires a cave-in
var cave_in_count: int = 0
var cave_in_buried: Dictionary = {}   #MercenaryData -> Vector2i cell under rubble
var cave_in_marked: Dictionary = {}   #MercenaryData -> String reason (crushed, cut_off, separated)
var kidnap_captor: Dictionary = {}    #captor MercenaryData -> captive MercenaryData
var kidnap_taken: Dictionary = {}     #captive MercenaryData -> String captor name
var kidnapped: Array[MercenaryData] = []   #left the field alive through remove_from_field, reason kidnapped
var kidnap_triggered: bool = false
var kidnap_closed: bool = false       #a failed or abandoned grapple ends kidnap rolls for this encounter
var kidnap_pending: MercenaryData = null   #the enemy whose kidnap roll passed and has not grappled yet
var kidnap_pending_target: MercenaryData = null
var battlefield: BattlefieldArea   #null = no positioning active
var positions: Dictionary = {}     #MercenaryData -> Vector2i
var heights: Dictionary = {}       #MercenaryData -> int paces above the surface of its own cell
var floors: Dictionary = {}        #MercenaryData -> int floor_num (interior maps; 0 for ground floor)
var climbing_data: Dictionary = {} #MercenaryData -> {wall_pos, current_h, target_h, top_pos}
var sunk: Dictionary = {}          #MercenaryData -> int paces below the water surface of its own cell
var los_cache: Dictionary = {}                #LOS result cache; key includes battlefield.los_version
var last_attacked: Dictionary = {}            #attacker -> last target attacked
var dying_source: Dictionary = {}             #MercenaryData -> the merc who put them into Dying
var last_ranged_targeted_round: Dictionary = {}  #target -> round_number when last targeted by a ranged attacker
var damage_dealt_this_round: Dictionary = {}  #attacker -> { target -> total dealt }
var damage_dealt_total: Dictionary = {}       #attacker -> {target -> total} for the whole encounter; never rotated
var damage_dealt_last_round: Dictionary = {}  #same, snapshot from previous round
var dropped_weapons: Dictionary = {}          #Vector2i -> Array of {weapon, ammo_loaded, ammo_loaded_type, floor}
var no_target_turns: Dictionary = {}          #MercenaryData -> consecutive turns without a valid attack target
var move_goals: Dictionary = {}              #MercenaryData -> Vector3i persistent move destination
var move_targets: Dictionary = {}            #MercenaryData -> MercenaryData current move target
var position_history: Dictionary = {}        #MercenaryData -> Array[Vector2i] (last 3 end-of-turn positions)
var no_progress_rounds: Dictionary = {}      #MercenaryData -> consecutive turns without position change
var _cached_winner: int = -2                  #set by AutoBattle.finalize() before merc reset
var _merc_team_index: Dictionary = {}         #MercenaryData -> int; populated in create()
var turn_ally_passable: Dictionary = {}       #MercenaryData -> Dictionary{Vector3i->true}; rebuilt per turn
var turn_path_dist: Dictionary = {}           #"a|b" pair key -> int path distance; rebuilt per turn
var movement_blocked: Dictionary = {}         #MercenaryData -> Dictionary{MercenaryData->true}; permanently unreachable enemies
var far_full: Dictionary = {}                #MercenaryData -> true; its approach flood runs uncapped for the rest of the battle
var team_blocked_round: Dictionary = {}      #MercenaryData (target) -> int (round of last block increment)
var team_blocked_count: Dictionary = {}      #MercenaryData (target) -> int (allies blocked on this target in that round)
var pending_interact: Dictionary = {}        #MercenaryData -> Vector3i; door cell a move stopped in front of
var pace_pool: Dictionary = {}               #MercenaryData -> int paces banked by Move actions this turn
var move_plan: Dictionary = {}               #MercenaryData -> {"moves_allowed": int, "reserve_ap": int} for the next Move
var climb_routes: Dictionary = {}            #MercenaryData -> {"link": Dictionary, "down": bool, "foot": Vector3i}
var jump_routes: Dictionary = {}             #MercenaryData -> {"to": Vector3i, "foot": Vector3i}; roof leap a walk stopped at
var roof_posts: Dictionary = {}              #MercenaryData -> RoofPostScore row, {} for none; one score per turn
var campaign_seeded: int = 0                 #knowledge tokens carried in from CampaignKnowledge at create()
var casualties: Array[MercenaryData] = []    #Filled by AutoBattle.finalize with every merc dead at the end
var defected: Array[MercenaryData] = []      #mercs that switched sides during this battle
var escaped: Array[MercenaryData] = []       #left the field alive through remove_from_field, reason fled
var removed_from_field: Array[MercenaryData] = []  #left the field alive through remove_from_field, reason out
var exited: Array[MercenaryData] = []        #walked out of a dungeon through remove_from_field, reason exit
var rescue: Dictionary = {}                  #RescueSystem bookkeeping; empty when no rescue runs
var priority_targets: Array[MercenaryData] = []    #quarries a pursuing team weighs above other targets
var pre_battle_lines: Array[String] = []     #lines written before round 1, logged after the spawns
var no_death_removal: bool = false           #when true a merc that would die leaves the field instead
var flee_enabled: bool = true                #false turns off flee checks for this battle

#Move-priced actions the pace pool never funds; they always pay their own AP.
const POOL_EXEMPT: Array[String] = ["Jump"]

var state_timers: Dictionary = {}


static func create(
		team_a: Array[MercenaryData],
		team_b: Array[MercenaryData],
		field: BattlefieldArea = null) -> BattleState:
	var state := BattleState.new()
	state.teams = [team_a, team_b]
	for _ti: int in range(state.teams.size()):
		for _tm: MercenaryData in state.teams[_ti]:
			state._merc_team_index[_tm] = _ti
	var all_mercs: Array[MercenaryData] = []
	all_mercs.assign(team_a + team_b)
	for merc: MercenaryData in all_mercs:
		for detail: String in WeaponArmorPerkLibrary.load_gear_perks(merc, WeaponArmorPerkLibrary.force_perk_load):
			state.pre_battle_lines.append("PERK LOAD: %s %s" % [merc.merc_name, detail])
		LevelUpSystem.note_armor_use(merc)
		merc.current_ap = 0
		#Excess HP, EP and MP are not reset here; they are cleared on contract return (ExcessPool.clear)
		merc.excess_ap = 0
		var campaign_snap := StateCampaign.snapshot_campaign_states(merc)
		merc.active_states = {}
		StateCampaign.restore_campaign_states(merc, campaign_snap)
		merc.death_test_hp_loss = 0
		merc.rot_hp_loss = 0
		merc.suffocation_hp_loss = 0
		merc.suffocate_rounds = 0
		merc.breath_clear_rounds = 0
		merc.crawling = false
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
		merc.off_field = false
		merc.flee_intent = false
		merc.flee_abandons = false
		merc.flee_escape_paces = 0
		merc.advantage_immune = false
		_randomize_starting_draw(merc)
	_seed_team_knowledge(state)
	_seed_campaign_knowledge(state)
	state.turn_queue = TurnOrderSystem.sort_initiative(all_mercs)
	state.battlefield = field
	if field != null:
		SpawnPlacer.assign(state, team_a, team_b)
		ReachCache.warm_jumps(state)
	return state


#Merc first name wrapped in the colour tag of its team, as every battle log line prints it.
static func colored_name(merc: MercenaryData, state: BattleState) -> String:
	var first := merc.merc_name.get_slice(" ", 0)
	if state == null:
		return first
	for i: int in range(state.teams.size()):
		if (state.teams[i] as Array).has(merc):
			return "[color=%s]%s[/color]" % ["white" if i == 0 else "yellow", first]
	return first


#Every merc starts knowing the passive immunity tokens of each teammate.
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
		WeaponArmorPerkLibrary.refresh_held_bonuses(merc)
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
	WeaponArmorPerkLibrary.refresh_held_bonuses(merc)

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
	StartingGear.equip_starting_ammo(merc)
	StartingGear.cap_carried_ammo(merc, merc.max_ammo)
	merc.equipped_weapon = prev_equipped


#Puts a merc back to full hp, ep, ap and mp, clears the death flag and the ap debt, and reloads by default.
static func restore_pools(merc: MercenaryData, ammo: bool = true) -> void:
	merc.current_hp = int(merc.stats.get("maximum_hit_points", merc.current_hp))
	merc.is_dead = false
	merc.current_ep = int(merc.stats.get("maximum_endurance_points", merc.current_ep))
	merc.current_ap = int(merc.stats.get("action_points", merc.current_ap))
	var max_mp: int = int(merc.stats.get("maximum_magic_points", 0))
	if max_mp > 0:
		merc.current_mp = max_mp
	merc.ap_debt = 0
	if ammo:
		_reset_starting_ammo(merc)


#Drops the paces, move plan and climb, jump and roof routes a merc banked for one turn.
func _clear_turn_plans(merc: MercenaryData) -> void:
	pace_pool.erase(merc)
	move_plan.erase(merc)
	climb_routes.erase(merc)
	jump_routes.erase(merc)
	roof_posts.erase(merc)


func start_of_turn(merc: MercenaryData) -> void:
	var max_ap := int(merc.stats.get("action_points", 5))
	merc.current_ap = maxi(0, max_ap - merc.ap_debt)
	merc.ap_debt = 0
	escalation[merc] = {}
	_clear_turn_plans(merc)
	merc.active_states.erase("draw_refused_turn")
	merc.active_states.erase("draw_priority_turn")


func end_of_turn(merc: MercenaryData, took_weapon_action: bool = false) -> void:
	_clear_turn_plans(merc)
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
	cost *= StateEffects.cost_multiplier(merc, "ap")
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


func spendable_ap(merc: MercenaryData) -> int:
	return merc.excess_ap + merc.current_ap


func get_enemies(merc: MercenaryData) -> Array[MercenaryData]:
	var i: int = _merc_team_index.get(merc, -1)
	if i < 0:
		return []
	var result: Array[MercenaryData] = []
	var guarded: bool = not rescue.is_empty()
	for m: MercenaryData in teams[1 - i]:
		if not _is_alive(m):
			continue
		if guarded and RescueSystem.shelters(self, m):
			continue
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
	learn_token(observer, target, "immune:" + StateTokens.normalize_token(state_name))


func clear_encounter_cache() -> void:
	turn_ally_passable.clear()
	turn_path_dist.clear()
	los_cache.clear()


static func _is_alive(merc: MercenaryData) -> bool:
	return not merc.is_dead and not merc.off_field \
		and (merc.current_hp > 0 or ConstStates.has_state(merc, ConstStates.DYING))


#Takes a living merc off the field: it stops acting, targeting and blocking but keeps its cell in positions.
func remove_from_field(merc: MercenaryData, reason: String, lines: Array[String]) -> void:
	if merc == null or merc.off_field:
		return
	var line: String = ""
	match reason:
		"fled":
			escaped.append(merc)
			line = "FLED: %s escapes the battle" % merc.merc_name
		"out":
			removed_from_field.append(merc)
			line = "%s is out of the competition!" % merc.merc_name
		"exit":
			exited.append(merc)
			line = "EXIT: %s leaves the dungeon." % merc.merc_name
		"kidnapped":
			kidnapped.append(merc)
			line = "KIDNAPPED: %s is carried off the field by %s" % [merc.merc_name,
					str(kidnap_taken.get(merc, "the enemy"))]
		_:
			push_warning("BattleState.remove_from_field: unknown reason '%s' for %s" % [reason, merc.merc_name])
			return
	merc.off_field = true
	lines.append(line)


#The only side-switch write path; the merc keeps its cell, its turn slot and its known immunities.
func switch_team(merc: MercenaryData) -> int:
	var from: int = int(_merc_team_index.get(merc, -1))
	if from < 0 or teams.size() != 2:
		return -1
	var to: int = 1 - from
	var old_side: Array = teams[from]
	var new_side: Array = teams[to]
	old_side.erase(merc)
	new_side.append(merc)
	_merc_team_index[merc] = to
	for cache: Dictionary in [move_goals, move_targets, last_attacked, movement_blocked, no_target_turns,
			team_blocked_round, team_blocked_count, pending_interact, pace_pool, move_plan,
			climb_routes, jump_routes, roof_posts, no_progress_rounds, position_history, far_full]:
		cache.erase(merc)
	for cache: Dictionary in [move_targets, last_attacked]:
		var pointing: Array = []
		for key in cache:
			if cache[key] == merc:
				pointing.append(key)
		for key in pointing:
			cache.erase(key)
	for blocked: Dictionary in movement_blocked.values():
		blocked.erase(merc)
	for side: Array in teams:
		for other: MercenaryData in side:
			if other != merc:
				other.last_known_enemy_positions.erase(merc)
	merc.last_known_enemy_positions = {}
	if not defected.has(merc):
		defected.append(merc)
	return to


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
	return int(floor(base - ground_ref)) + body_height(merc)


#A merc that sank in a pool stands this many paces below the water surface of its cell.
func is_sunk(merc: MercenaryData) -> bool:
	return int(sunk.get(merc, 0)) > 0


func sunk_depth(merc: MercenaryData) -> int:
	return int(sunk.get(merc, 0))


func set_sunk(merc: MercenaryData, depth: int) -> void:
	if depth <= 0:
		sunk.erase(merc)
	else:
		sunk[merc] = depth


#Altitude of the body above its cell surface; a sunk merc stands its pool depth below the water.
func body_height(merc: MercenaryData) -> int:
	return get_height(merc) - sunk_depth(merc)


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
	for c: Vector2i in battlefield.reserved_corridor_cells.keys():
		result[Vector3i(c.x, c.y, 0)] = true
	return result


func get_floor(merc: MercenaryData) -> int:
	return floors.get(merc, 0)


#The route stored for merc, dropped once the merc has left its foot cell.
func _route_from(routes: Dictionary, merc: MercenaryData) -> Dictionary:
	var row: Dictionary = routes.get(merc, {}) as Dictionary
	if row.is_empty():
		return {}
	if pos3(merc) != (row["foot"] as Vector3i):
		routes.erase(merc)
		return {}
	return row


#The climb link a stopped walk left pending, {} when none; a move off the foot drops the record.
func climb_route(merc: MercenaryData) -> Dictionary:
	return _route_from(climb_routes, merc)


func set_climb_route(merc: MercenaryData, link: Dictionary, down: bool, foot: Vector3i) -> void:
	climb_routes[merc] = {"link": link, "down": down, "foot": foot}


func clear_climb_route(merc: MercenaryData) -> void:
	climb_routes.erase(merc)


#The roof leap a stopped walk left pending, {} when none; a move off the take-off drops the record.
func jump_route(merc: MercenaryData) -> Dictionary:
	return _route_from(jump_routes, merc)


func set_jump_route(merc: MercenaryData, to: Vector3i, foot: Vector3i) -> void:
	jump_routes[merc] = {"to": to, "foot": foot}


func clear_jump_route(merc: MercenaryData) -> void:
	jump_routes.erase(merc)


func get_climbing_data(merc: MercenaryData) -> Dictionary:
	return climbing_data.get(merc, {}) as Dictionary


func clear_climbing(merc: MercenaryData) -> void:
	climbing_data.erase(merc)


#3D Chebyshev distance: max(|dx|, |dy|, |dz|). Returns 0 when no battlefield.
func distance_to(a: MercenaryData, b: MercenaryData) -> int:
	if battlefield == null:
		return 0
	var pa := get_position(a)
	var pb := get_position(b)
	var ea := battlefield.cell_base_elevation(pa, get_floor(a)) + float(body_height(a))
	var eb := battlefield.cell_base_elevation(pb, get_floor(b)) + float(body_height(b))
	var dz := int(round(absf(ea - eb)))
	return maxi(maxi(abs(pa.x - pb.x), abs(pa.y - pb.y)), dz)


#distance_to from a stance at `cell` with `height` to `target`; reads the target's get_height, not body_height.
func distance_from(cell: Vector3i, height: int, target: MercenaryData) -> int:
	if battlefield == null:
		return 0
	var tp := get_position(target)
	var ea := battlefield.cell_base_elevation(Vector2i(cell.x, cell.y), cell.z) + float(height)
	var eb := battlefield.cell_base_elevation(tp, get_floor(target)) + float(get_height(target))
	var dz := int(round(absf(ea - eb)))
	return maxi(maxi(abs(cell.x - tp.x), abs(cell.y - tp.y)), dz)


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


#2D horizontal-only Chebyshev distance (used for cover angle and flanking checks).
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
	if attacker == null or target == null:
		return
	if amount <= 0:
		return
	if not damage_dealt_this_round.has(attacker):
		damage_dealt_this_round[attacker] = {}
	damage_dealt_this_round[attacker][target] = damage_dealt_this_round[attacker].get(target, 0) + amount
	if attacker == target:
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


func get_dropped_weapons_at(pos: Vector2i, floor_num: int = -1) -> Array:
	return DroppedItemStore.get_dropped_weapons_at(self, pos, floor_num)


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
			if m.current_hp > 0 and not m.off_field:
				if winner >= 0:
					return -1
				winner = i
				break
	return winner


#Door opened or closed: sight lines and floods are stale, the geometry tables are not.
func on_door_changed() -> void:
	if battlefield != null:
		battlefield.los_version += 1
		battlefield.bump_door_version()
	los_cache.clear()
	MovementExecutor.clear_caches()
