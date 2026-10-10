class_name FleeSettlement


#Party mercs that fled: returners are marked, abandoners take Coward's Way Out and leave for the MercPool.
static func settle(run: ContractRun, state: BattleState, roster: Array[MercenaryData]) -> Array[String]:
	var out: Array[String] = []
	var fled: Array[MercenaryData] = []
	fled.assign(state.escaped)
	for merc: MercenaryData in fled:
		if merc == null or not roster.has(merc):
			continue
		run.add_merc_mark(merc, "Fled")
		if not merc.flee_abandons:
			out.append("RETURNED: %s rejoins the party" % merc.merc_name)
			continue
		var forced := LifepathProgression.force(merc, "Coward's Way Out")
		out.append_array(forced)
		var took := false
		for line: String in forced:
			if line.begins_with("LIFEPATH FORCED"):
				took = true
		if not took and not LifepathProgression.has_event(merc, "Coward's Way Out"):
			out.append("LIFEPATH REFUSED: %s Coward's Way Out" % merc.merc_name)
		MercPool.add(merc)
		merc.missing_since = CampaignClock.now()
		out.append_array(run.depart(merc, run.departed))
		out.append("DEPARTED: %s abandons the party" % merc.merc_name)
	for team: Variant in state.teams:
		for m: Variant in team as Array:
			if m is MercenaryData:
				FleeSystem.clear_merc(m as MercenaryData)
	FleeSystem.goal_cache.clear()
	return out
