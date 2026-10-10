class_name WeaponActionExecutor

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")


#Bare hands need one empty hand; Two-Handed needs both; One-Handed, Protean and unmarked weapons need one.
static func hands_needed(w: WeaponData, merc: MercenaryData = null) -> int:
	if w == null:
		return 0
	if w.is_virtual:
		return 1
	if merc != null and WeaponArmorPerkLibrary.is_protean(merc, w):
		return 1
	return 2 if w.misc_properties.has("Two-Handed") else 1


static func get_draw_cost(merc: MercenaryData, weapon: WeaponData) -> int:
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
		if perk.effect_dsl.contains("weapon_stat:draw:0"):
			return 0
	return weapon.draw


#A wanted draw that cannot happen logs once per merc per turn; only a fixable refusal raises urgency.
static func log_draw_refusal(merc: MercenaryData, weapon: WeaponData, reason: String, need: int,
		raise_urgency: bool = true) -> void:
	if bool(merc.active_states.get("draw_refused_turn", false)):
		return
	merc.active_states["draw_refused_turn"] = true
	var urgency := get_draw_urgency(merc)
	if raise_urgency:
		urgency += 1
		merc.active_states["draw_urgency"] = urgency
	if EncounterLogger.is_active():
		var wanted := weapon.item_name if weapon != null else "a weapon"
		EncounterLogger.log_verbose("DRAW REFUSED: %s wanted %s reason=%s need=%d have=%d urgency=%d" % [
			merc.merc_name, wanted, reason, need, merc.current_ap + merc.excess_ap, urgency])


static func get_draw_urgency(merc: MercenaryData) -> int:
	return int(merc.active_states.get("draw_urgency", 0))


static func execute_reload(merc: MercenaryData, state: BattleState, enhancements: int = 0,
		free: bool = false, cost_override: int = -1) -> Array[String]:
	#weapon_misfired is NOT cleared here; it resets at turn start before decisions are evaluated,
	#so reloading after a same-turn misfire is correctly allowed.
	var weapon := merc.equipped_weapon
	if weapon == null or not weapon.is_ranged:
		return []
	var ammo_type := merc.ammo_loaded_type
	if ammo_type == "":
		return []
	var available: int = merc.ammo_inventory.get(ammo_type, 0)
	if available <= 0:
		return []
	if weapon.chamber <= 0:
		if merc.ammo_loaded > 0:
			return []
		merc.ammo_loaded = available
		var lines_q: Array[String] = ["  %s restocks quiver. (%d available)" % [BattleState.colored_name(merc, state), available]]
		lines_q.append_array(_after_reload_triggers(merc, state, enhancements))
		return lines_q
	if merc.ammo_loaded >= weapon.chamber:
		return []
	var reload_cost := 0 if free else (cost_override if cost_override >= 0 else weapon.load_time)
	if not free and (reload_cost <= 0 or not state.can_afford(merc, reload_cost)):
		return []
	var to_load := mini(weapon.chamber - merc.ammo_loaded, available)
	if to_load <= 0:
		return []
	merc.ammo_loaded += to_load
	merc.ammo_inventory[ammo_type] -= to_load
	if merc.ammo_inventory[ammo_type] <= 0:
		merc.ammo_inventory.erase(ammo_type)
	if reload_cost > 0:
		state.spend_ap(merc, reload_cost)
	var remaining: int = merc.ammo_inventory.get(ammo_type, 0)
	var lines: Array[String] = ["  %s reloads. [%d+%d]" % [BattleState.colored_name(merc, state), merc.ammo_loaded, remaining]]
	lines.append_array(_after_reload_triggers(merc, state, enhancements))
	return lines


#after_reload and on_load both fire once the ammunition is in place.
static func _after_reload_triggers(merc: MercenaryData, state: BattleState, enhancements: int) -> Array[String]:
	var lines: Array[String] = []
	var foe := TargetSelector.nearest_visible_enemy(merc, state,
			TargetSelector.weapon_target_range(merc))
	lines.append_array(WeaponReactiveSystem.fire_trigger(merc, "after_reload", foe, {}, state, enhancements))
	lines.append_array(WeaponReactiveSystem.fire_on_load(merc, state))
	return lines


#A draw that leaves the hands short pays to free them first; a free hand makes the draw plain.
static func get_swap_cost(merc: MercenaryData, weapon: WeaponData, state: BattleState) -> int:
	if weapon != null and weapon == merc.offhand_weapon:
		return 0
	if not needs_free_hands(merc, weapon) and not grip_frees_main(merc, weapon, state.get_enemies(merc), state):
		return state.get_cost(merc, "Draw", get_draw_cost(merc, weapon))
	var plan := plan_free_hands(merc, weapon, state.get_enemies(merc), state, _CONFIG.attack_base_ap)
	if not bool(plan.get("ok", false)):
		return -1
	var draw := state.get_cost_after(merc, "Draw", get_draw_cost(merc, weapon), int(plan.get("stows", 0)))
	return draw + int(plan.get("cost", 0))


#True when a held weapon has to be stowed or dropped before `weapon` can be taken up.
static func needs_free_hands(merc: MercenaryData, weapon: WeaponData) -> bool:
	if weapon == null:
		return false
	if weapon == merc.offhand_weapon:
		return false
	if weapon == merc.equipped_weapon and merc.weapon_drawn:
		return false
	var capacity := 2 - hands_needed(weapon, merc)
	var equipped: WeaponData = merc.equipped_weapon
	var has_equipped := equipped != null and merc.weapon_drawn and not equipped.is_virtual
	if has_equipped and merc.offhand_weapon != null:
		return true
	if has_equipped:
		return hands_needed(equipped, merc) > capacity
	if merc.offhand_weapon != null:
		return hands_needed(merc.offhand_weapon, merc) > capacity
	return false


#True when both weapons fit the hands but `weapon` is worth more wielded two-handed than paired.
static func grip_frees_main(
		merc: MercenaryData,
		weapon: WeaponData,
		enemies: Array,
		state: BattleState,
		verbose: bool = false) -> bool:
	if weapon == null or weapon.is_virtual or weapon == merc.offhand_weapon:
		return false
	var equipped: WeaponData = merc.equipped_weapon
	if equipped == null or equipped == weapon or not merc.weapon_drawn or equipped.is_virtual:
		return false
	if merc.offhand_weapon != null or needs_free_hands(merc, weapon):
		return false
	return WeaponSwapDecider.prefer_two_hands(merc, weapon, equipped, enemies, state, verbose)


#Lists the drawn weapons that must leave the hands before `weapon` can be held, and their cost.
static func plan_free_hands(
		merc: MercenaryData,
		weapon: WeaponData,
		enemies: Array,
		state: BattleState,
		attack_base_cost: int,
		log_decisions: bool = false) -> Dictionary:
	var steps: Array[Dictionary] = []
	var total := 0
	#Hands left over once `weapon` is held; only one other weapon can stay, in the off hand.
	var capacity := 2 - hands_needed(weapon, merc)
	var equipped: WeaponData = merc.equipped_weapon
	var offhand: WeaponData = merc.offhand_weapon
	var has_equipped := equipped != null and equipped != weapon and merc.weapon_drawn \
		and not equipped.is_virtual
	var has_offhand := offhand != null and offhand != weapon
	var must_go: Array[WeaponData] = []
	if has_equipped and has_offhand:
		must_go.append(equipped)
		if hands_needed(offhand, merc) > capacity:
			must_go.append(offhand)
	elif has_equipped and hands_needed(equipped, merc) > capacity:
		must_go.append(equipped)
	elif has_offhand and hands_needed(offhand, merc) > capacity:
		must_go.append(offhand)
	#Room for both, yet two hands on `weapon` beat the pair: the main-hand weapon goes or rides along.
	var grip := false
	if must_go.is_empty() and has_equipped and not has_offhand \
			and grip_frees_main(merc, weapon, enemies, state, log_decisions):
		must_go.append(equipped)
		grip = true
	var stows := 0
	for held: WeaponData in must_go:
		var mode := WeaponSwapDecider.should_holster_vs_drop(
			merc, held, weapon, enemies, state, attack_base_cost, log_decisions, stows)
		if grip and mode == "drop" and WeaponSwapDecider.is_worth_keeping(merc, held, weapon, enemies, state):
			mode = "keep"
		if grip and mode == "keep":
			continue
		var cost := 0
		if mode == "stow":
			cost = state.get_cost_after(merc, "Draw", get_draw_cost(merc, held), stows)
			stows += 1
		elif mode == "keep" and not held.is_virtual:
			#A weapon worth keeping in hand refuses the swap outright.
			return {"steps": [] as Array[Dictionary], "cost": 0, "ok": false,
				"stows": 0, "reason": "hands_full"}
		else:
			mode = "drop"
		total += cost
		steps.append({"weapon": held, "mode": mode, "cost": cost})
	return {"steps": steps, "cost": total, "ok": true, "stows": stows}


#Runs a free-hands plan: a stow costs that weapon's Draw again, a drop costs nothing.
static func apply_free_hands(
		merc: MercenaryData,
		plan: Dictionary,
		state: BattleState,
		cause: String) -> Array[String]:
	var lines: Array[String] = []
	for step: Dictionary in (plan.get("steps", []) as Array):
		var held: WeaponData = step.get("weapon")
		if held == null:
			continue
		var cost := state.get_cost(merc, "Draw", get_draw_cost(merc, held))
		if str(step.get("mode", "drop")) == "stow" and state.can_afford(merc, cost):
			_release_hand(merc, held)
			merc.inventory.append({"type": "weapon", "data": held})
			state.spend_ap(merc, cost)
			state.record_action(merc, "Draw")
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("DRAW: %s stows %s [%dAP]" % [merc.merc_name, held.item_name, cost])
			lines.append("  %s stows %s [%dAP]" % [BattleState.colored_name(merc, state), held.item_name, cost])
		else:
			lines.append_array(_drop_from_hand(merc, held, state, cause))
	return lines


static func _release_hand(merc: MercenaryData, held: WeaponData) -> void:
	if merc.offhand_weapon == held:
		merc.offhand_weapon = null
	elif merc.equipped_weapon == held:
		merc.equipped_weapon = null
		merc.weapon_drawn = false
		WeaponArmorPerkLibrary.refresh_held_bonuses(merc)


static func _drop_from_hand(
		merc: MercenaryData,
		held: WeaponData,
		state: BattleState,
		cause: String) -> Array[String]:
	if merc.equipped_weapon == held and merc.weapon_drawn:
		return execute_drop(merc, state, cause)
	if merc.offhand_weapon != held:
		return []
	merc.offhand_weapon = null
	var pos := state.get_position(merc)
	DroppedItemStore.push(state, pos, state.get_floor(merc), held, 0, "")
	var cause_str := (" (%s)" % cause) if cause != "" else ""
	return ["  %s drops %s at (%d,%d)%s" % [BattleState.colored_name(merc, state), held.item_name, pos.x, pos.y, cause_str]]


#A weapon already held in the off hand only changes hands, which costs nothing.
static func _switch_to_offhand(merc: MercenaryData, state: BattleState, enhancements: int) -> Array[String]:
	var weapon: WeaponData = merc.offhand_weapon
	if weapon == null:
		return []
	var prev: WeaponData = merc.equipped_weapon
	merc.offhand_weapon = null
	if prev != null and merc.weapon_drawn and not prev.is_virtual:
		merc.offhand_weapon = prev
	merc.equipped_weapon = weapon
	merc.weapon_drawn = true
	WeaponArmorPerkLibrary.refresh_held_bonuses(merc)
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("HANDS: %s switches to %s" % [merc.merc_name, weapon.item_name])
	var lines: Array[String] = ["  %s switches to %s" % [BattleState.colored_name(merc, state), weapon.item_name]]
	lines.append_array(_on_draw_triggers(merc, state, enhancements))
	return lines


static func _on_draw_triggers(merc: MercenaryData, state: BattleState, enhancements: int) -> Array[String]:
	var foe := TargetSelector.nearest_visible_enemy(merc, state,
			TargetSelector.weapon_target_range(merc))
	return WeaponReactiveSystem.fire_trigger(merc, "on_draw", foe, {}, state, enhancements)


#A one-handed weapon still in hand when another is drawn moves to the free hand.
static func _keep_in_offhand(merc: MercenaryData) -> void:
	var held: WeaponData = merc.equipped_weapon
	if held == null or not merc.weapon_drawn or held.is_virtual or merc.offhand_weapon != null:
		return
	merc.offhand_weapon = held
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("HANDS: %s keeps %s in the off hand" % [merc.merc_name, held.item_name])


static func execute_draw(merc: MercenaryData, weapon: WeaponData, state: BattleState, enhancements: int = 0) -> Array[String]:
	if weapon == null:
		return []
	var draw_cost := get_swap_cost(merc, weapon, state)
	if draw_cost < 0:
		log_draw_refusal(merc, weapon, "hands_full", 0, false)
		return []
	if not state.can_afford(merc, draw_cost):
		log_draw_refusal(merc, weapon, "ap_short", draw_cost)
		return []
	if weapon == merc.offhand_weapon:
		return _switch_to_offhand(merc, state, enhancements)
	var lines: Array[String] = []
	if merc.equipped_weapon != weapon:
		if not weapon.is_virtual:
			var found := false
			for i: int in range(merc.inventory.size()):
				var entry: Dictionary = merc.inventory[i]
				if entry.get("type") == "weapon" and entry.get("data") == weapon:
					merc.inventory.remove_at(i)
					found = true
					break
			if not found:
				log_draw_refusal(merc, weapon, "not_carried", draw_cost)
				return []
	#hands are freed by the stow-or-drop economics; nothing is ever stowed for free
	if needs_free_hands(merc, weapon) or grip_frees_main(merc, weapon, state.get_enemies(merc), state):
		var plan := plan_free_hands(merc, weapon, state.get_enemies(merc), state, _CONFIG.attack_base_ap, true)
		if not bool(plan.get("ok", false)):
			if not weapon.is_virtual and merc.equipped_weapon != weapon:
				merc.inventory.append({"type": "weapon", "data": weapon})
			log_draw_refusal(merc, weapon, "hands_full", draw_cost)
			return []
		lines.append_array(apply_free_hands(merc, plan, state, "to draw %s" % weapon.item_name))
	if merc.equipped_weapon != weapon:
		_keep_in_offhand(merc)
		merc.equipped_weapon = weapon
	merc.weapon_drawn = true
	WeaponArmorPerkLibrary.refresh_held_bonuses(merc)
	var own_cost := state.get_cost(merc, "Draw", get_draw_cost(merc, weapon))
	state.spend_ap(merc, own_cost)
	state.record_action(merc, "Draw")
	RangedPlanStore.clear_plan(merc)
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("DRAW: %s draws %s [%dAP]" % [merc.merc_name, weapon.item_name, own_cost])
	lines.append("  %s draws %s [%dAP]" % [BattleState.colored_name(merc, state), weapon.item_name, own_cost])
	lines.append_array(_on_draw_triggers(merc, state, enhancements))
	return lines


static func execute_holster(merc: MercenaryData, state: BattleState) -> Array[String]:
	var weapon := merc.equipped_weapon
	if weapon == null or not merc.weapon_drawn:
		return []
	if weapon.is_virtual:
		return _swap_from_bare_hands(merc, state)
	#Stowing is the Draw action aimed at a drawn weapon: same cost key, same escalation.
	var cost := state.get_cost(merc, "Draw", get_draw_cost(merc, weapon))
	if not state.can_afford(merc, cost):
		log_draw_refusal(merc, weapon, "stow_ap_short", cost)
		return []
	merc.inventory.append({"type": "weapon", "data": weapon})
	merc.equipped_weapon = null
	merc.weapon_drawn = false
	state.spend_ap(merc, cost)
	state.record_action(merc, "Draw")
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("DRAW: %s stows %s [%dAP]" % [merc.merc_name, weapon.item_name, cost])
	var lines: Array[String] = ["  %s stows %s [%dAP]" % [BattleState.colored_name(merc, state), weapon.item_name, cost]]
	lines.append_array(promote_offhand(merc, state))
	WeaponArmorPerkLibrary.refresh_held_bonuses(merc)
	return lines


#The off hand takes over when the main hand empties, at no cost.
static func promote_offhand(merc: MercenaryData, state: BattleState) -> Array[String]:
	var oh: WeaponData = merc.offhand_weapon
	if oh == null:
		return []
	merc.offhand_weapon = null
	merc.equipped_weapon = oh
	merc.weapon_drawn = true
	WeaponArmorPerkLibrary.refresh_held_bonuses(merc)
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("HANDS: %s switches to %s" % [merc.merc_name, oh.item_name])
	return ["  %s switches to %s" % [BattleState.colored_name(merc, state), oh.item_name]]


#Clears the main hand; the off hand takes over, or bare hands when nothing is held there.
static func empty_main_hand(merc: MercenaryData, state: BattleState) -> Array[String]:
	merc.equipped_weapon = null
	merc.weapon_drawn = false
	if merc.offhand_weapon != null:
		return promote_offhand(merc, state)
	merc.equipped_weapon = DataManager.fight_weapon
	merc.weapon_drawn = DataManager.fight_weapon != null
	WeaponArmorPerkLibrary.refresh_held_bonuses(merc)
	return []


#Fight is bare hands and is never stowed: swap straight to the best carried weapon instead.
static func _swap_from_bare_hands(merc: MercenaryData, state: BattleState) -> Array[String]:
	var enemies: Array = state.get_enemies(merc)
	var best: WeaponData = null
	var best_score := -9999.0
	for entry: Dictionary in merc.inventory:
		if entry.get("type") != "weapon":
			continue
		var w: WeaponData = entry.get("data")
		if w == null or w.is_virtual:
			continue
		var s := WeaponEvaluator.score_weapon(w, merc, enemies, state)
		if s > best_score:
			best_score = s
			best = w
	if best == null:
		log_draw_refusal(merc, null, "no_weapon", 0)
		return []
	return execute_draw(merc, best, state)


static func execute_drop(merc: MercenaryData, state: BattleState, cause: String = "") -> Array[String]:
	var weapon := merc.equipped_weapon
	if weapon == null or not merc.weapon_drawn:
		return []
	var pos := state.get_position(merc)
	DroppedItemStore.drop_weapon(state, merc)
	var cause_str := (" (%s)" % cause) if cause != "" else ""
	var lines: Array[String] = ["  %s drops %s at (%d,%d)%s" % [
		BattleState.colored_name(merc, state), weapon.item_name, pos.x, pos.y, cause_str]]
	lines.append_array(empty_main_hand(merc, state))
	StatCalculator.refresh(merc)
	return lines


static func execute_pickup(
		merc: MercenaryData,
		weapon_entry: Dictionary,
		weapon_pos: Vector2i,
		state: BattleState) -> Array[String]:
	var weapon: WeaponData = weapon_entry.get("weapon")
	if weapon == null:
		return []
	var still_there := false
	for e: Dictionary in state.get_dropped_weapons_at(weapon_pos, state.get_floor(merc)):
		if e.get("weapon") == weapon:
			still_there = true
			break
	if not still_there:
		return []
	var pickup_cost := state.get_cost(merc, "Interact", 2)
	var plan := plan_free_hands(merc, weapon, state.get_enemies(merc), state, _CONFIG.attack_base_ap, true)
	if not bool(plan.get("ok", false)):
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("PICKUP SKIP: %s  -  keeps %s in hand (hands_full)" % [
				merc.merc_name, merc.equipped_weapon.item_name if merc.equipped_weapon != null else "a weapon"])
		return []
	if not state.can_afford(merc, pickup_cost + int(plan.get("cost", 0))):
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("PICKUP SKIP: %s  -  cannot free hands for %s (need=%d have=%d)" % [
				merc.merc_name, weapon.item_name, pickup_cost + int(plan.get("cost", 0)),
				state.spendable_ap(merc)])
		return []
	var lines: Array[String] = apply_free_hands(merc, plan, state, "to pick up %s" % weapon.item_name)
	DroppedItemStore.remove_dropped_weapon(state, weapon_pos, weapon_entry)
	_keep_in_offhand(merc)
	merc.equipped_weapon = weapon
	merc.weapon_drawn = true
	merc.ammo_loaded = weapon_entry.get("ammo_loaded", 0)
	merc.ammo_loaded_type = weapon_entry.get("ammo_loaded_type", "")
	state.spend_ap(merc, pickup_cost)
	state.record_action(merc, "Interact")
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("INTERACT: %s picks up %s [%dAP]" % [merc.merc_name, weapon.item_name, pickup_cost])
	lines.append("  %s picks up %s. (AP: %d)" % [BattleState.colored_name(merc, state), weapon.item_name, pickup_cost])
	StatCalculator.refresh(merc)
	return lines


#Shared tail of the turn slot arms: an executor that produced nothing ends the turn instead.
static func _run_arm(turn: Dictionary, executor_lines: Array[String],
		sets_weapon_action: bool) -> Array[String]:
	var lines: Array[String] = []
	if executor_lines.is_empty():
		turn["stop"] = true
		return lines
	lines.append_array(executor_lines)
	if sets_weapon_action:
		turn["weapon_action_taken"] = true
	return lines


#Reload arm of the turn slot loop; a reload that produces nothing ends the turn.
static func run_reload_arm(merc: MercenaryData, state: BattleState, enhancements: int,
		turn: Dictionary) -> Array[String]:
	var cost := ReloadDecision.reload_ap_cost(merc, merc.equipped_weapon, state)
	return _run_arm(turn, execute_reload(merc, state, enhancements, false, cost), false)


#Repair arm: AP goes into a snapped bowstring until the 4 AP of work is done.
static func run_repair_arm(merc: MercenaryData, state: BattleState, turn: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var weapon := merc.equipped_weapon
	if weapon == null or not weapon.string_snapped:
		turn["stop"] = true
		return lines
	var owed := ReloadDecision.REPAIR_AP - weapon.repair_ap_paid
	var pay := mini(owed, state.spendable_ap(merc))
	if pay <= 0:
		turn["stop"] = true
		return lines
	state.spend_ap(merc, pay)
	weapon.repair_ap_paid += pay
	if weapon.repair_ap_paid >= ReloadDecision.REPAIR_AP:
		weapon.string_snapped = false
		weapon.repair_ap_paid = 0
		lines.append("  %s restrings the %s." % [BattleState.colored_name(merc, state), weapon.item_name])
	else:
		lines.append("  %s works on the bowstring. [%d/%d]" % [
			BattleState.colored_name(merc, state), weapon.repair_ap_paid, ReloadDecision.REPAIR_AP])
	turn["weapon_action_taken"] = true
	return lines


#Draw arm of the turn slot loop.
static func run_draw_arm(merc: MercenaryData, decision: Dictionary, state: BattleState,
		enhancements: int, turn: Dictionary) -> Array[String]:
	return _run_arm(turn, execute_draw(merc, decision["weapon"], state, enhancements), true)


#Holster arm of the turn slot loop.
static func run_holster_arm(merc: MercenaryData, state: BattleState, turn: Dictionary) -> Array[String]:
	return _run_arm(turn, execute_holster(merc, state), true)


#Drop arm of the turn slot loop, with the optional swap draw that follows it.
static func run_drop_arm(merc: MercenaryData, decision: Dictionary, state: BattleState,
		enhancements: int, turn: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	lines.append_array(execute_drop(merc, state, decision.get("cause", "")))
	var _swap_to: WeaponData = decision.get("swap_weapon")
	if _swap_to != null:
		lines.append_array(execute_draw(merc, _swap_to, state, enhancements))
	turn["weapon_action_taken"] = true
	return lines


#Puts down the packed item the pickup decision chose to shed; free, and the ground keeps no ammo.
static func _apply_shed(merc: MercenaryData, shed: Dictionary, state: BattleState) -> Array[String]:
	if shed.is_empty():
		return []
	var shed_name: String = str(shed.get("name", ""))
	var weight: int = int(shed.get("weight", 0))
	var done := false
	if str(shed.get("slot", "")) == "reserve":
		done = DroppedItemStore.drop_ammo_bundle(merc, str(shed.get("ammo", ""))) > 0
	else:
		done = DroppedItemStore.drop_packed_weapon(state, merc, shed.get("weapon") as WeaponData)
	if not done:
		return []
	StatCalculator.refresh(merc)
	return ["  %s drops %s (wt %d, over weight)" % [BattleState.colored_name(merc, state), shed_name, weight]]


#Pickup arm of the turn slot loop.
static func run_pickup_arm(merc: MercenaryData, decision: Dictionary, state: BattleState,
		turn: Dictionary) -> Array[String]:
	var pu_lines := execute_pickup(merc, decision["weapon_entry"], decision["weapon_pos"], state)
	var lines := _run_arm(turn, pu_lines, true)
	if lines.is_empty():
		return lines
	lines.append_array(_apply_shed(merc, decision.get("shed", {}) as Dictionary, state))
	merc.active_states.erase("bfw_drop_pos")
	merc.active_states.erase("target_weapon_pos")
	return lines
