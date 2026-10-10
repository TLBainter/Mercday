class_name AimPayoffFacet extends DecisionFacet

#Passes only when aiming would flip a failed attack into a passing one.
#Blocks aim when: unaimed attack already passes (wasted AP), or aimed attack still fails.
#Fails when Aim plus the follow-up Attack are unaffordable this turn (ExAP counts).
func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var weapon := merc.equipped_weapon
	if weapon == null or not weapon.is_ranged:
		return 0.0
	var afford_state: BattleState = ctx.get("state")
	if afford_state != null:
		var attack_cost := maxi(1, afford_state.get_cost(merc, "Attack", int(ctx.get("attack_base_ap", 3)))
			- int(merc.active_states.get("attack_ap_reduction", 0)))
		if not afford_state.can_afford(merc, afford_state.get_cost(merc, "Aim", 2) + attack_cost):
			return 0.0
	#Long-Shot: aiming doubles the bands, so it pays when only the wide band reaches an enemy.
	if not merc.aim_active and weapon.ranged_extended_range > 0 \
			and WeaponArmorPerkLibrary.has_weapon_passive(merc, "aimed_doubled_range"):
		var state: BattleState = ctx.get("state")
		if state != null \
				and TargetSelector.nearest_visible_enemy(merc, state, weapon.ranged_extended_range) == null \
				and TargetSelector.nearest_visible_enemy(merc, state, weapon.ranged_extended_range * 2) != null:
			return 1.0
	if weapon.misfire <= 0:
		return 0.0  #non-firearms have reliability=1.0; unaimed attack already passes
	var reliability := FirearmReliabilityFacet.compute(merc)
	if FirearmReliabilityFacet.unaimed_viable_at(reliability):
		return 0.0  #Unaimed attack already clears the threshold; aiming wastes AP
	if not FirearmReliabilityFacet.aimed_viable_at(reliability):
		return 0.0  #Aimed score still below the threshold; aiming accomplishes nothing
	return 1.0
