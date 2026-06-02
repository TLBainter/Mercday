class_name TargetSelector


static func pick_target(
		attacker: MercenaryData,
		enemies: Array,
		state: BattleState = null,
		_weights: Dictionary = {}) -> MercenaryData:
	if enemies.is_empty():
		return null
	var weapon := attacker.equipped_weapon
	var is_ranged := weapon != null and weapon.is_ranged
	var avoid_key := "avoid_ranged" if is_ranged else "avoid_melee"

	var most_damage_dealer: MercenaryData = null
	if is_ranged and state != null:
		var max_dmg := 0
		for enemy: MercenaryData in enemies:
			var dmg := int(state.damage_dealt_last_round.get(enemy, {}).get(attacker, 0))
			if dmg <= 0:
				continue
			var in_range := _enemy_in_intended_range(attacker, enemy, weapon, state)
			if in_range and dmg > max_dmg:
				max_dmg = dmg
				most_damage_dealer = enemy

	var allies := state.get_allies(attacker) if state != null else []

	var weights: Array[int] = []
	for enemy: MercenaryData in enemies:
		var avoid_val := float(enemy.stats.get(avoid_key, 0))
		if ConstStates.has_state(enemy, ConstStates.FLANKED):
			avoid_val = maxf(0.0, avoid_val - 15.0)
		var base := maxi(1, 100 - int(avoid_val))
		var mult := 1.0

		if state != null and state.battlefield != null and weapon != null:
			var dist := state.distance_to(attacker, enemy)
			if is_ranged:
				if weapon.ranged_intended_range <= 0 or dist <= weapon.ranged_intended_range:
					mult += 0.5
			else:
				if dist <= weapon.melee_range:
					mult += 0.5 + 1.0

		if is_ranged and state != null and state.last_attacked.get(attacker) == enemy:
			mult += 0.5

		if is_ranged and enemy == most_damage_dealer:
			mult += 0.25

		if ConstStates.has_state(enemy, ConstStates.FLANKED):
			mult += 0.5

		if state != null and _flank_ally_at_current_pos(attacker, enemy, allies, state) != null:
			mult += 0.25

		if state != null and state.battlefield != null:
			var att_pos := state.get_position(attacker)
			var emy_pos := state.get_position(enemy)
			var to_enemy := Vector2(float(emy_pos.x - att_pos.x), float(emy_pos.y - att_pos.y))
			var emy_dist := to_enemy.length()
			for other: MercenaryData in enemies:
				if other == enemy:
					continue
				var other_pos := state.get_position(other)
				var to_other := Vector2(float(other_pos.x - att_pos.x), float(other_pos.y - att_pos.y))
				var other_dist := to_other.length()
				if emy_dist >= other_dist:
					continue
				if emy_dist < 0.5:
					continue
				var dot := to_enemy.normalized().dot(to_other.normalized())
				if dot >= 0.7:
					mult += 0.4
					break

		if weapon != null and not weapon.damage_types_1.is_empty():
			var all_types: Array = weapon.damage_types_1.duplicate()
			all_types.append_array(weapon.damage_types_2)
			mult += score_type_vs_enemy(all_types, enemy)

		weights.append(maxi(1, int(base * mult)))

	var total := 0
	for w: int in weights:
		total += w
	var roll := randi() % total
	var cumulative := 0
	for i: int in range(enemies.size()):
		cumulative += weights[i]
		if roll < cumulative:
			return enemies[i]
	return enemies[-1]


static func find_flankable_target(
		mover: MercenaryData,
		enemies: Array,
		allies: Array,
		state: BattleState) -> Dictionary:
	var mover_size := int(mover.stats.get("size", 1))
	var best_enemy: MercenaryData = null
	var best_ally: MercenaryData = null
	var best_dist := 999999
	for enemy: MercenaryData in enemies:
		var target_size := int(enemy.stats.get("size", 1))
		if mover_size < target_size - 1:
			continue
		var enemy_pos := state.get_position(enemy)
		for ally: MercenaryData in allies:
			if int(ally.stats.get("size", 1)) < target_size - 1:
				continue
			var ally_pos := state.get_position(ally)
			var da_x := ally_pos.x - enemy_pos.x
			var da_y := ally_pos.y - enemy_pos.y
			if da_x == 0 and da_y == 0:
				continue
			var d := state.distance_to(mover, enemy)
			if d < best_dist:
				best_dist = d
				best_enemy = enemy
				best_ally = ally
			break
	return {"target": best_enemy, "ally": best_ally}


static func _enemy_in_intended_range(
		attacker: MercenaryData,
		enemy: MercenaryData,
		weapon: WeaponData,
		state: BattleState) -> bool:
	if state.battlefield == null or weapon == null:
		return true
	if weapon.ranged_intended_range <= 0:
		return true
	return state.distance_to(attacker, enemy) <= weapon.ranged_intended_range


# Returns a [-1.0, ~0.8] score for how well damage_types exploit this enemy's profile.
# Negative = bad matchup (immune, protected by state); positive = good matchup.
# Averages across all types in the list so multi-type weapons aren't over-rewarded.
static func score_type_vs_enemy(damage_types: Array, enemy: MercenaryData) -> float:
	if damage_types.is_empty():
		return 0.0
	var total := 0.0
	for dtype: String in damage_types:
		total += _score_single_type(dtype, enemy)
	return total / float(damage_types.size())


static func _score_single_type(dtype: String, enemy: MercenaryData) -> float:
	var score := 0.0
	var type_lower := dtype.to_lower()

	# Passive effects (traits, armor protection): immune / susceptible / protected
	for effect: String in enemy.passive_effects:
		if effect == "immune:" + type_lower:
			return -1.0
		elif effect == "susceptible:" + type_lower:
			score += 0.6
		elif effect == "protected:" + type_lower:
			score -= 0.3

	# State-based interactions
	match dtype:
		"Toxic":
			if ConstStates.has_state(enemy, ConstStates.POISONED):
				score += 0.5   # +1 damage bonus kicks in
		"Sonic":
			if ConstStates.has_state(enemy, ConstStates.DEAFENED):
				score -= 0.4   # Deafened grants Protected from Sonic
		"Fire":
			if ConstStates.has_state(enemy, ConstStates.DRENCHED):
				score -= 0.3   # Drenched grants Protected from Fire
		"Will":
			# Will can't reduce HP below 1  -  bad for finishing off low-HP targets
			var max_hp := int(enemy.stats.get("maximum_hit_points", 1))
			if float(enemy.current_hp) / float(maxi(1, max_hp)) < 0.25:
				score -= 0.5

	# Defense-profile manipulation: reward types that counter how this enemy actually defends
	var defend := float(enemy.stats.get("defend_reduction", 0))
	var dodge := float(enemy.stats.get("dodge_reduction", 0))
	var total_def := defend + dodge
	if total_def > 0.0:
		var defend_ratio := defend / total_def   # 1.0 = pure blocker
		var dodge_ratio  := dodge  / total_def   # 1.0 = pure dodger
		match dtype:
			"Acid":     score += 0.4  * defend_ratio   # removes block entirely
			"Holy":     score += 0.4  * dodge_ratio    # removes dodge entirely
			"Strike":   score += 0.25 * defend_ratio   # halves block successes
			"Impale":   score += 0.2  * defend_ratio   # block can't reduce below 1
			"Lacerate": score += 0.2  * dodge_ratio    # dodge can't reduce below 1

	return score


static func _flank_ally_at_current_pos(
		attacker: MercenaryData,
		target: MercenaryData,
		allies: Array,
		state: BattleState) -> MercenaryData:
	var target_size := int(target.stats.get("size", 1))
	if int(attacker.stats.get("size", 1)) < target_size - 1:
		return null
	var target_pos := state.get_position(target)
	var attacker_pos := state.get_position(attacker)
	var am_x := attacker_pos.x - target_pos.x
	var am_y := attacker_pos.y - target_pos.y
	for ally: MercenaryData in allies:
		if int(ally.stats.get("size", 1)) < target_size - 1:
			continue
		var ally_pos := state.get_position(ally)
		var da_x := ally_pos.x - target_pos.x
		var da_y := ally_pos.y - target_pos.y
		if am_y < 0 and da_y > 0:
			return ally
		if am_y > 0 and da_y < 0:
			return ally
		if am_x < 0 and da_x > 0:
			return ally
		if am_x > 0 and da_x < 0:
			return ally
	return null
