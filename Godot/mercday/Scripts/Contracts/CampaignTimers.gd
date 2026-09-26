class_name CampaignTimers extends RefCounted


#At battle end a held campaign state becomes a campaign-minute expiry, capped by after_encounter_minutes; -1 means none.
static func export_campaign_timers(state: BattleState) -> void:
	var now: int = CampaignClock.now()
	var names: Array[String] = ConstStates.campaign_state_names()
	for team: Array in state.teams:
		for merc: MercenaryData in team:
			for state_name: String in names:
				if ConstStates.has_state(merc, state_name):
					merc.campaign_states[state_name] = _campaign_expiry(state, merc, state_name, now)
				else:
					merc.campaign_states.erase(state_name)


static func _campaign_expiry(state: BattleState, merc: MercenaryData, state_name: String, now: int) -> int:
	var expiry: int = -1
	var expires: int = int(state.get_state_timer(merc, state_name).get("expires", 0))
	if expires > 0:
		var rounds: int = expires - state.round_number
		expiry = now + maxi(1, int(ceil(float(rounds) / float(StateInfliction.ROUNDS_PER_MINUTE))))
	else:
		var minutes: int = ConstStates.removal_minutes(state_name)
		if minutes > 0:
			expiry = now + minutes
	var cap: int = ConstStates.after_encounter_minutes(state_name)
	if cap > 0 and (expiry < 0 or expiry > now + cap):
		expiry = now + cap
	return expiry


static func get_timed_states(state: BattleState, merc: MercenaryData) -> Array[String]:
	var names: Array[String] = []
	if state.state_timers.has(merc):
		for k: String in (state.state_timers[merc] as Dictionary).keys():
			names.append(k)
	return names
