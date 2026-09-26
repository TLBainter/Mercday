class_name StateCampaign


static var _campaign_names: Array[String] = []
static var campaign_names_count: int = -1


#A state that outlives its encounter: a stacking tier, an hour or day timer, or a rest removal.
static func is_campaign_state(state_name: String) -> bool:
	if state_name in ConstStates.STACKING_STATES:
		return true
	if ConstStates.has_removal(state_name, "respite") or ConstStates.has_removal(state_name, "furlough"):
		return true
	return ConstStates.removal_minutes(state_name) > 0


static func campaign_state_names() -> Array[String]:
	if campaign_names_count != ConstStates.ALL.size():
		campaign_names_count = ConstStates.ALL.size()
		_campaign_names.clear()
		for state_name: String in ConstStates.ALL:
			if is_campaign_state(state_name):
				_campaign_names.append(state_name)
	return _campaign_names.duplicate()


#The campaign states a merc holds, with their APPLIED_BY_KEY record, so a new encounter can put them back.
static func snapshot_campaign_states(merc: MercenaryData) -> Dictionary:
	var states: Dictionary = {}
	var applied: Dictionary = {}
	var record = merc.active_states.get(ConstStates.APPLIED_BY_KEY)
	for state_name: String in campaign_state_names():
		if not merc.active_states.has(state_name):
			continue
		states[state_name] = _copy_entry(merc.active_states[state_name])
		if record is Dictionary and (record as Dictionary).has(state_name):
			applied[state_name] = _copy_entry((record as Dictionary)[state_name])
	return {"states": states, "applied": applied}


static func restore_campaign_states(merc: MercenaryData, snap: Dictionary) -> void:
	var states: Dictionary = snap.get("states", {})
	for state_name: String in states.keys():
		merc.active_states[state_name] = _copy_entry(states[state_name])
	var applied: Dictionary = snap.get("applied", {})
	if applied.is_empty():
		return
	var record := StateSources.applied_by(merc)
	for state_name: String in applied.keys():
		record[state_name] = _copy_entry(applied[state_name])


#An active_states value is a count, a {count, source} entry or an applied-by record; objects stay shared.
static func _copy_entry(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return value


#Ends every campaign state whose expiry minute has arrived; returns one Remove Text line each.
static func expire_campaign_states(merc: MercenaryData, now: int) -> Array[String]:
	var lines: Array[String] = []
	if merc.campaign_states.is_empty():
		return lines
	for state_name: String in merc.campaign_states.keys():
		if not merc.campaign_states.has(state_name):
			continue
		var expiry: int = int(merc.campaign_states[state_name])
		if expiry < 0 or expiry > now:
			continue
		if not ConstStates.has_state(merc, state_name):
			merc.campaign_states.erase(state_name)
			continue
		if not ConstStates.remove_state(merc, state_name)["removed"]:
			continue
		lines.append("  " + StateText.remove_line(merc, state_name))
	return lines
