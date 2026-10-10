class_name PaceBudget extends RefCounted

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")


#Paces one Move action banks for this mover.
static func pace_per_move(merc: MercenaryData) -> int:
	var pace := maxi(1, int(merc.stats.get("pace", 1)))
	var drag := KidnapSystem.drag_size(merc)
	if drag > 0:
		pace = maxi(1, pace - drag)
	pace = maxi(1, pace + StateEffects.pace_modifier(merc))
	var cap := StateEffects.max_paces(merc)
	if cap == 0:
		return 0
	if cap > 0:
		pace = mini(pace, cap)
	return pace


#Paces the mover can still walk this turn: the pool plus every Move it can buy while keeping reserve_ap.
static func turn_paces(merc: MercenaryData, state: BattleState, reserve_ap: int = 0, max_moves: int = 2) -> Dictionary:
	var pool := state.get_pace_pool(merc)
	var ap := merc.current_ap + merc.excess_ap
	var moves := 0
	var spent := 0
	while moves < max_moves:
		var cost := state.get_cost_after(merc, "Move Close", _CONFIG.move_base_ap, moves)
		if ap - spent - cost < reserve_ap:
			break
		spent += cost
		moves += 1
	return {"paces": pool + moves * pace_per_move(merc), "moves": moves, "ap": spent, "pool": pool}


#Buys one Move action: charges its AP, escalates it and banks its paces.
static func buy_move(merc: MercenaryData, state: BattleState, action_name: String) -> int:
	var cost := state.get_cost(merc, action_name, _CONFIG.move_base_ap)
	state.spend_ap(merc, cost)
	state.record_action(merc, action_name)
	var paces := pace_per_move(merc)
	state.set_pace_pool(merc, state.get_pace_pool(merc) + paces)
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("MOVE BUY: %s %s [%dAP] pool=%d" % [
			merc.merc_name, action_name, cost, state.get_pace_pool(merc)])
	return paces


#Moves the plan must buy so `budget` can pay `cost`; -1 with buy["why"] when it cannot afford them.
static func fund_need(merc: MercenaryData, state: BattleState, buy: Dictionary, budget: int, cost: int) -> int:
	if budget >= cost:
		return 0
	var pp := pace_per_move(merc)
	var need := int(ceil(float(cost - budget) / float(maxi(1, pp))))
	if need > int(buy["left"]):
		buy["why"] = "moves_spent"
		return -1
	var bought := int(buy["bought"])
	var action_name: String = str(buy["action_name"])
	var total := 0
	#Moves a real walk bought are already recorded; a dry run prices past the ones it simulated.
	var ahead: int = bought if bool(buy.get("dry", false)) else 0
	for k: int in range(need):
		total += state.get_cost_after(merc, action_name, _CONFIG.move_base_ap, ahead + k)
	#A dry run books the AP of the Moves it already simulated in buy["sim_ap"].
	var ap := merc.current_ap + merc.excess_ap - int(buy.get("sim_ap", 0))
	#The first Move of an empty-pool walk was priced by the decision; every later one keeps the reserve.
	var keeps_reserve := bought > 0 or int(buy.get("pool_start", 0)) > 0
	var reserve: int = int(buy["reserve"]) if keeps_reserve else 0
	#AP the shut doors within this purchase's reach need for their Interact; every Move keeps it.
	var door_reserve: int = int(buy.get("door_reserve", 0))
	if ap < total:
		buy["why"] = "ap_short"
		return -1
	if ap - total < reserve + door_reserve:
		buy["why"] = "door_reserve" if (door_reserve > 0 and ap - total >= reserve) else "reserve"
		return -1
	buy["need_ap"] = total
	return need


#Raises `budget` until it can pay `cost`, buying Moves the plan still allows. -1 when it cannot.
static func fund_step(merc: MercenaryData, state: BattleState, buy: Dictionary, budget: int, cost: int) -> int:
	var need := fund_need(merc, state, buy, budget, cost)
	if need < 0:
		return -1
	for k: int in range(need):
		budget += buy_move(merc, state, str(buy["action_name"]))
		buy["bought"] = int(buy["bought"]) + 1
		buy["left"] = int(buy["left"]) - 1
	return budget


#Paces the walk holds once it buys the Moves that let `budget` pay `cost`.
static func purchase_reach(merc: MercenaryData, budget: int, cost: int) -> int:
	var pp := maxi(1, pace_per_move(merc))
	return budget + int(ceil(float(cost - budget) / float(pp))) * pp
