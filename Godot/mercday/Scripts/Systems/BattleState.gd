class_name BattleState extends RefCounted

var teams: Array = []
var turn_queue: Array[MercenaryData] = []
var escalation: Dictionary = {}
var round_number: int = 0
var battlefield: BattlefieldArea   # null = no positioning active
var positions: Dictionary = {}     # MercenaryData -> Vector2i
var heights: Dictionary = {}       # MercenaryData -> int  (0 = ground, >0 = flying altitude)
# plain int/String fields only; no Vector2i to avoid Variant-inference warnings
var merc_cover: Dictionary = {}
var last_attacked: Dictionary = {}            # attacker -> last target attacked
var damage_dealt_this_round: Dictionary = {}  # attacker -> { target -> total dealt }
var damage_dealt_last_round: Dictionary = {}  # same, snapshot from previous round
var dropped_weapons: Dictionary = {}          # Vector2i -> Array[WeaponData]


static func create(
		team_a: Array[MercenaryData],
		team_b: Array[MercenaryData],
		field: BattlefieldArea = null) -> BattleState:
	var state := BattleState.new()
	state.teams = [team_a, team_b]
	var all_mercs: Array[MercenaryData] = []
	all_mercs.assign(team_a + team_b)
	for merc: MercenaryData in all_mercs:
		merc.current_hp = int(merc.stats.get("maximum_hit_points", 1))
		merc.current_ep = int(merc.stats.get("maximum_endurance_points", 1))
		# TODO: apply ArmorData.ep_cost penalty here once the mechanic is implemented.
		# Guard with: if merc.equipped_armor and not WeaponArmorPerkLibrary.has_armor_perk_active(merc, "armor_ep_ignore:" + merc.equipped_armor.armor_class.to_lower()):
		#     merc.current_ep -= merc.equipped_armor.ep_cost
		# TODO: apply ArmorData.fatigue penalty here once the mechanic is implemented.
		# Guard with: if merc.equipped_armor and not WeaponArmorPerkLibrary.has_armor_perk_active(merc, "armor_fatigue_zero:" + merc.equipped_armor.armor_class.to_lower()):
		#     merc.current_ep -= merc.equipped_armor.fatigue
		merc.current_mp = int(merc.stats.get("maximum_magic_points", 0))
		merc.current_ap = 0
		merc.excess_ap = 0
		merc.active_states = {}
		merc.death_test_hp_loss = 0
		merc.aim_active = false
		_randomize_starting_draw(merc)
	state.turn_queue = TurnOrderSystem.sort_initiative(all_mercs)
	state.battlefield = field
	if field != null:
		_assign_starting_positions(state, team_a, team_b)
	return state


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


static func _assign_starting_positions(
		state: BattleState,
		team_a: Array[MercenaryData],
		team_b: Array[MercenaryData]) -> void:
	var field := state.battlefield
	var center_a := Vector2i(field.width >> 1, 2)
	var center_b := Vector2i(field.width >> 1, field.length - 3)
	for merc: MercenaryData in team_a:
		var offset := Vector2i(randi_range(-2, 2), randi_range(-2, 2))
		var pos := field.clamp_position(center_a + offset)
		pos = _find_free_cell(field, pos, center_a)
		state.positions[merc] = pos
		state.heights[merc] = 0
	for merc: MercenaryData in team_b:
		var offset := Vector2i(randi_range(-2, 2), randi_range(-2, 2))
		var pos := field.clamp_position(center_b + offset)
		pos = _find_free_cell(field, pos, center_b)
		state.positions[merc] = pos
		state.heights[merc] = 0


static func _find_free_cell(field: BattlefieldArea, start: Vector2i, fallback: Vector2i) -> Vector2i:
	if not field.is_obstacle(start):
		return start
	for radius: int in range(1, 5):
		for dx: int in range(-radius, radius + 1):
			for dy: int in range(-radius, radius + 1):
				var candidate := field.clamp_position(start + Vector2i(dx, dy))
				if not field.is_obstacle(candidate):
					return candidate
	return fallback


func start_of_turn(merc: MercenaryData) -> void:
	merc.current_ap = int(merc.stats.get("action_points", 5))
	escalation[merc] = {}


func end_of_turn(merc: MercenaryData) -> void:
	merc.excess_ap = merc.current_ap
	merc.current_ap = 0


func get_cost(merc: MercenaryData, action_name: String, base_cost: int) -> int:
	var times_used: int = 0
	if escalation.has(merc):
		times_used = escalation[merc].get(action_name, 0)
	var cost := base_cost + times_used
	if ConstStates.has_state(merc, ConstStates.SLOWED):
		cost *= 2
	return cost


func record_action(merc: MercenaryData, action_name: String) -> void:
	if not escalation.has(merc):
		escalation[merc] = {}
	escalation[merc][action_name] = escalation[merc].get(action_name, 0) + 1


func spend_ap(merc: MercenaryData, amount: int) -> void:
	var from_excess := mini(merc.excess_ap, amount)
	merc.excess_ap -= from_excess
	merc.current_ap -= (amount - from_excess)


func can_afford(merc: MercenaryData, cost: int) -> bool:
	return (merc.excess_ap + merc.current_ap) >= cost


func get_enemies(merc: MercenaryData) -> Array[MercenaryData]:
	for i: int in range(teams.size()):
		var team: Array = teams[i]
		if team.has(merc):
			var result: Array[MercenaryData] = []
			for m: MercenaryData in teams[1 - i]:
				if _is_alive(m):
					result.append(m)
			return result
	return []


func get_allies(merc: MercenaryData) -> Array[MercenaryData]:
	for i: int in range(teams.size()):
		var team: Array = teams[i]
		if team.has(merc):
			var result: Array[MercenaryData] = []
			for m: MercenaryData in team:
				if m != merc and _is_alive(m):
					result.append(m)
			return result
	return []


static func _is_alive(merc: MercenaryData) -> bool:
	return merc.current_hp > 0 or ConstStates.has_state(merc, ConstStates.DYING)


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


func set_height(merc: MercenaryData, h: int) -> void:
	var max_h := battlefield.height - 1 if battlefield != null else 0
	heights[merc] = clamp(h, 0, max_h)


# 3D Chebyshev distance: max(|dx|, |dy|, |dz|). Returns 0 when no battlefield.
func distance_to(a: MercenaryData, b: MercenaryData) -> int:
	if battlefield == null:
		return 0
	var pa := get_position(a)
	var pb := get_position(b)
	var dz := absi(get_height(a) - get_height(b))
	return maxi(maxi(abs(pa.x - pb.x), abs(pa.y - pb.y)), dz)


# 2D horizontal-only Chebyshev distance (used for cover angle and flanking checks).
func distance_2d(a: MercenaryData, b: MercenaryData) -> int:
	if battlefield == null:
		return 0
	var pa := get_position(a)
	var pb := get_position(b)
	return maxi(abs(pa.x - pb.x), abs(pa.y - pb.y))


func set_cover(merc: MercenaryData, obstacle_pos: Vector2i, obstacle_size: int, cover_type: String) -> void:
	var merc_pos := get_position(merc)
	var raw := obstacle_pos - merc_pos
	var dir_x := signi(raw.x)
	var dir_y := signi(raw.y)
	merc_cover[merc] = {
		"obstacle_pos_x": obstacle_pos.x,
		"obstacle_pos_y": obstacle_pos.y,
		"obstacle_size":  obstacle_size,
		"cover_type":     cover_type,
		"cover_dir_x":    dir_x,
		"cover_dir_y":    dir_y,
	}
	ConstStates.apply_state(merc, cover_type)


func clear_cover(merc: MercenaryData) -> void:
	if not merc_cover.has(merc):
		return
	var cover_type: String = str(merc_cover[merc].get("cover_type", ""))
	ConstStates.remove_state(merc, cover_type)
	merc_cover.erase(merc)


func get_cover_info(merc: MercenaryData) -> Dictionary:
	if not merc_cover.has(merc):
		return {}
	return merc_cover[merc]


# Automatic cover from standing on higher terrain (no Seek Cover required).
# Full cover if terrain_diff >= merc size; partial if terrain_diff >= 1 pace.
func _check_terrain_cover(merc: MercenaryData, attacker: MercenaryData, cover_type: String) -> bool:
	var def_pos := get_position(merc)
	var atk_pos := get_position(attacker)
	var terrain_diff := battlefield.get_terrain_height(def_pos) - battlefield.get_terrain_height(atk_pos)
	if terrain_diff < 1.0:
		return false
	var atk_fly := get_height(attacker)
	if atk_fly > 0:
		var horiz_dist := maxi(abs(atk_pos.x - def_pos.x), abs(atk_pos.y - def_pos.y))
		if atk_fly >= int(terrain_diff) + horiz_dist:
			return false
	var merc_size := maxi(1, int(merc.stats.get("size", 1)))
	match cover_type:
		ConstStates.COVERED_FULL:
			return terrain_diff >= float(merc_size)
		ConstStates.COVERED_PARTIAL:
			return true
	return false


# Flying attackers bypass cover when their height >= obstacle_size + horizontal_distance_to_obstacle.
func is_covered_from(merc: MercenaryData, attacker: MercenaryData, cover_type: String) -> bool:
	if battlefield != null and _check_terrain_cover(merc, attacker, cover_type):
		return true
	if not ConstStates.has_state(merc, cover_type):
		return false
	if not merc_cover.has(merc):
		return false

	var atk_height := get_height(attacker)
	if atk_height > 0:
		var obs_x: int = 0
		var obs_y: int = 0
		obs_x = merc_cover[merc].get("obstacle_pos_x", -999)
		obs_y = merc_cover[merc].get("obstacle_pos_y", -999)
		var obs_size: int = 5
		obs_size = merc_cover[merc].get("obstacle_size", 5)
		var atk_pos := get_position(attacker)
		var horiz_dist := maxi(abs(atk_pos.x - obs_x), abs(atk_pos.y - obs_y))
		if atk_height >= obs_size + horiz_dist:
			return false

	var dir_x: int = 0
	var dir_y: int = 0
	dir_x = merc_cover[merc].get("cover_dir_x", 0)
	dir_y = merc_cover[merc].get("cover_dir_y", 0)
	var atk_pos2 := get_position(attacker)
	var def_pos  := get_position(merc)
	var to_atk   := atk_pos2 - def_pos
	if dir_x != 0 and sign(to_atk.x) != dir_x:
		return false
	if dir_y != 0 and sign(to_atk.y) != dir_y:
		return false
	return true


func record_damage_dealt(attacker: MercenaryData, target: MercenaryData, amount: int) -> void:
	if amount <= 0:
		return
	if not damage_dealt_this_round.has(attacker):
		damage_dealt_this_round[attacker] = {}
	damage_dealt_this_round[attacker][target] = damage_dealt_this_round[attacker].get(target, 0) + amount


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
	})
	merc.equipped_weapon = null
	merc.weapon_drawn = false
	merc.ammo_loaded = 0
	merc.ammo_loaded_type = ""


func retrieve_dropped_weapons_for(merc: MercenaryData) -> void:
	if dropped_weapons.is_empty():
		return
	var merc_pos := get_position(merc)
	for pos: Vector2i in dropped_weapons.keys().duplicate():
		if maxi(abs(pos.x - merc_pos.x), abs(pos.y - merc_pos.y)) <= 1:
			for entry: Dictionary in dropped_weapons[pos]:
				merc.inventory.append({"type": "weapon", "data": entry["weapon"]})
			dropped_weapons.erase(pos)


func get_dropped_weapons_at(pos: Vector2i) -> Array:
	return dropped_weapons.get(pos, [])


func remove_dropped_weapon(pos: Vector2i, entry: Dictionary) -> void:
	if not dropped_weapons.has(pos):
		return
	(dropped_weapons[pos] as Array).erase(entry)
	if (dropped_weapons[pos] as Array).is_empty():
		dropped_weapons.erase(pos)


func get_winner() -> int:
	var winner := -1
	for i: int in range(teams.size()):
		for m: MercenaryData in teams[i]:
			if m.current_hp > 0:
				if winner >= 0:
					return -1
				winner = i
				break
	return winner
