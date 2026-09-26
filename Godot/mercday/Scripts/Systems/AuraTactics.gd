class_name AuraTactics

#Target priority and sense-denial worth for enemies projecting a morale aura.

const LEADER_BASE := 0.5
const LEADER_PER_FOLLOWER := 0.15
const LEADER_MAX := 1.25
const DENY_SOURCE := 1.0
const DENY_EMBOLDENED := 0.5
const DENY_MAX := 2.0


static func is_aura_source(merc: MercenaryData) -> bool:
	return merc != null and not merc.auras.is_empty()


#The widest aura radius in paces this merc projects; 0 when it carries none.
static func aura_reach(merc: MercenaryData) -> int:
	if merc == null:
		return 0
	var reach := 0
	for aura: Dictionary in merc.auras:
		reach = maxi(reach, int(aura.get("paces", 0)))
	return reach


#Extra pick_target multiplier for an aura source, scaled by the allies it is currently holding up.
static func leader_bonus(enemy: MercenaryData, state: BattleState) -> float:
	if not is_aura_source(enemy):
		return 0.0
	return minf(LEADER_MAX, LEADER_BASE + float(_followers(enemy, state)) * LEADER_PER_FOLLOWER)


#Worth of blinding or deafening this target; a sense cut costs it the aura it gives or receives.
static func sense_denial_value(target: MercenaryData, state: BattleState) -> float:
	if target == null:
		return 0.0
	var value := 0.0
	if is_aura_source(target):
		value += DENY_SOURCE + float(_followers(target, state)) * LEADER_PER_FOLLOWER
	if ConstStates.has_state(target, ConstStates.EMBOLDENED):
		value += DENY_EMBOLDENED
	return minf(DENY_MAX, value)


static func _followers(merc: MercenaryData, state: BattleState) -> int:
	if state == null:
		return 0
	var count := 0
	for ally: MercenaryData in state.get_allies(merc):
		if ConstStates.has_state(ally, ConstStates.EMBOLDENED):
			count += 1
	return count
