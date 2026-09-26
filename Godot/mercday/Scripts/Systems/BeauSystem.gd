class_name BeauSystem

#The bond between two mercs: who is with whom, how long they have been apart, and what a sighting resets.
#Time is campaign minutes. A sighting is the pair on one contract team, or both idle in the tavern.

const TICK_MINUTES := 14400
const SUPPORT_BONUS := 0.5
const PASSIVE_SUPPORT_PREFIX := "grant:passive:always:none:support_given:beau"

static var roster: Array[MercenaryData] = []


#Distinct from GuildRoster.mercs, which answers who in the guild holds a Knowledge, Tool or Circumstance.
#The mercs time apart is measured against; the harness and the campaign set it before any tick.
static func set_roster(mercs: Array[MercenaryData]) -> void:
	roster.clear()
	for merc: MercenaryData in mercs:
		if merc != null:
			roster.append(merc)


static func reset() -> void:
	roster.clear()


#The merc this one is In Love with, looked up in the contract team, then the battlefield, then the roster.
static func partner(merc: MercenaryData, ctx: Dictionary) -> MercenaryData:
	if merc == null or merc.beau_uid <= 0:
		return null
	var run: ContractRun = ctx.get("run", null)
	if run != null:
		var on_team: MercenaryData = _by_uid(run.team, merc.beau_uid)
		if on_team != null:
			return on_team
	var state: BattleState = ctx.get("state", null)
	if state != null:
		for team: Array in state.teams:
			var on_field: MercenaryData = _by_uid(team, merc.beau_uid)
			if on_field != null:
				return on_field
	return _by_uid(roster, merc.beau_uid)


#The name a [Beau] placeholder takes; "" when the merc has no beau and the line is dropped.
static func beau_name(merc: MercenaryData, ctx: Dictionary) -> String:
	var beau: MercenaryData = partner(merc, ctx)
	if beau == null:
		return ""
	var state: BattleState = ctx.get("state", null)
	if state != null:
		return BattleState.colored_name(beau, state)
	return beau.merc_name


#Deployment sightings: a pair on the same team meet, a merc deployed without their beau is apart.
static func begin_contract(run: ContractRun) -> Array[String]:
	var lines: Array[String] = []
	if run == null:
		return lines
	for merc: MercenaryData in run.team:
		if merc == null or merc.beau_uid <= 0:
			continue
		var beau: MercenaryData = _by_uid(run.team, merc.beau_uid)
		if beau == null:
			merc.beau_together = false
			var away: MercenaryData = _by_uid(roster, merc.beau_uid)
			if away != null:
				away.beau_together = false
			continue
		if not merc.beau_together:
			lines.append_array(meet(merc, beau, {"run": run}))
		merc.beau_together = true
	return lines


#One campaign pass: accrues time apart, lands each 10-day block, and meets on a reunion.
static func tick(now: int) -> Array[String]:
	var lines: Array[String] = []
	for merc: MercenaryData in roster:
		if merc == null or merc.beau_uid <= 0:
			continue
		var beau: MercenaryData = _by_uid(roster, merc.beau_uid)
		if beau == null:
			continue
		#A dead partner ends the accrual; no sighting can revert the bond scope after this.
		if beau.is_dead:
			merc.beau_together = false
			merc.beau_last_tick_minute = now
			continue
		var delta: int = 0
		if merc.beau_last_tick_minute >= 0:
			delta = maxi(0, now - merc.beau_last_tick_minute)
		merc.beau_last_tick_minute = now
		var together_now: bool = _together(merc, beau)
		if not merc.beau_together:
			merc.beau_apart_minutes += delta
			while merc.beau_apart_minutes >= TICK_MINUTES:
				merc.beau_apart_minutes -= TICK_MINUTES
				merc.beau_hp_ticks += 1
				lines.append_array(_apart_block(merc, beau))
		if together_now and not merc.beau_together:
			lines.append_array(meet(merc, beau, {}))
		merc.beau_together = together_now
	return lines


#A sighting: the counters reset, every bond-scoped loss reverts at once, and beau_seen fires.
static func meet(merc: MercenaryData, beau: MercenaryData, ctx: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if merc == null or beau == null:
		return lines
	merc.beau_apart_minutes = 0
	merc.beau_last_seen_minute = CampaignClock.now()
	merc.beau_hp_ticks = 0
	TraitRuntime.revert_scope(merc, TraitRuntime.SCOPE_BOND)
	var on_contract: bool = ctx.get("run", null) != null
	var source: String = "contract" if on_contract else "tavern"
	lines.append("BEAU SEEN: %s sees %s (%s)" % [merc.merc_name, beau.merc_name, source])
	if TraitRuntime.has(merc, "beau_seen"):
		var fire_ctx: Dictionary = ctx.duplicate()
		fire_ctx["target"] = beau
		#A tavern sighting has no run to emit through, so the clause lines ride back here.
		if not on_contract:
			fire_ctx["lines"] = lines
		TraitRuntime.fire("beau_seen", merc, fire_ctx)
	return lines


#1.5 when the helper carries the support token and the target is their beau; 1.0 for everyone else.
static func support_multiplier(helper: MercenaryData, target: MercenaryData) -> float:
	if helper == null or target == null:
		return 1.0
	if target.merc_uid <= 0 or helper.beau_uid != target.merc_uid:
		return 1.0
	for effect: String in helper.passive_effects:
		if effect.begins_with(PASSIVE_SUPPORT_PREFIX):
			return 1.0 + SUPPORT_BONUS
	return 1.0


#One completed block apart: the trait takes the max HP, or the floor line says it cannot.
static func _apart_block(merc: MercenaryData, beau: MercenaryData) -> Array[String]:
	var lines: Array[String] = []
	if not TraitRuntime.has(merc, "beau_apart"):
		return lines
	var days: int = int(TICK_MINUTES / float(CampaignClock.MINUTES_PER_DAY))
	if int(merc.stats.get("maximum_hit_points", 0)) <= 1:
		lines.append("BEAU FLOOR: %s max HP already 1, no loss" % merc.merc_name)
		return lines
	TraitRuntime.fire("beau_apart", merc, {"target": beau, "days": days})
	lines.append("BEAU APART: %s %d days without %s, max HP -1 (%d blocks)"
		% [merc.merc_name, days, beau.merc_name, merc.beau_hp_ticks])
	return lines


#Together when both are on the same deployment, or both are home and neither is resting.
static func _together(merc: MercenaryData, beau: MercenaryData) -> bool:
	if merc.is_dead or beau.is_dead:
		return false
	if merc.on_contract and beau.on_contract:
		return true
	if merc.on_contract or beau.on_contract:
		return false
	return not RestSystem.is_resting(merc) and not RestSystem.is_resting(beau)


static func _by_uid(pool: Array, uid: int) -> MercenaryData:
	if uid <= 0:
		return null
	for entry in pool:
		var merc: MercenaryData = entry as MercenaryData
		if merc != null and merc.merc_uid == uid:
			return merc
	return null
