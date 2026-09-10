class_name RestSystem

#The three rests: Breather, Respite and Furlough. A rest tops a pool up to a fraction of its
#maximum and never lowers one. Rests never touch the excess pools; those are cleared on contract
#return by ExcessPool.clear. Only a Respite or a Furlough stamps a deployment lockout.

const BREATHER_MINUTES := 10
const RESPITE_MINUTES := 360
const FURLOUGH_MINUTES := 14400
const PARTIAL_CAP := 0.5
const BREATHER_MIN_DEFICIT := 0.25

const KIND_BREATHER := "breather"
const KIND_RESPITE := "respite"
const KIND_FURLOUGH := "furlough"

const MAX_HP := "maximum_hit_points"
const MAX_EP := "maximum_endurance_points"
const MAX_MP := "maximum_magic_points"


#Stats.tsv Rest Recovery; a missing or non-positive value rests at the ordinary rate.
static func rest_recovery(merc: MercenaryData) -> float:
	if merc == null:
		return 1.0
	var value: float = float(merc.stats.get("rest_recovery", 1.0))
	if value <= 0.0:
		return 1.0
	return value


static func cap_fraction(merc: MercenaryData, base: float) -> float:
	return clampf(base * rest_recovery(merc), 0.0, 1.0)


#A merc missing a quarter or more of its EP or MP wants a Breather; urgency raises that bar.
static func wants_breather(merc: MercenaryData, urgency: float) -> bool:
	if merc == null or merc.is_dead:
		return false
	var ep_deficit: float = _deficit(merc.current_ep, _max_of(merc, MAX_EP))
	var mp_deficit: float = _deficit(merc.current_mp, _max_of(merc, MAX_MP))
	var deficit: float = maxf(ep_deficit, mp_deficit)
	if deficit < BREATHER_MIN_DEFICIT:
		return false
	return deficit >= clampf(urgency, 0.0, 1.0)


static func breather(merc: MercenaryData, run: ContractRun, urgency: float = 0.0) -> Array[String]:
	var lines: Array[String] = []
	if merc == null or merc.is_dead:
		return lines
	if not wants_breather(merc, urgency):
		lines.append("BREATHER SKIPPED: %s (EP %d/%d, MP %d/%d)" % [merc.merc_name,
			merc.current_ep, _max_of(merc, MAX_EP), merc.current_mp, _max_of(merc, MAX_MP)])
		return lines
	TraitRuntime.fire_rest("rest_start", KIND_BREATHER, merc, run, lines)
	var fraction: float = cap_fraction(merc, PARTIAL_CAP)
	var ep_before: int = merc.current_ep
	var mp_before: int = merc.current_mp
	_top_up(merc, "current_ep", MAX_EP, fraction)
	_top_up(merc, "current_mp", MAX_MP, fraction)
	TraitRuntime.fire_rest("rest_complete", KIND_BREATHER, merc, run, lines)
	lines.append("BREATHER: %s EP %d -> %d, MP %d -> %d (%s)" % [merc.merc_name,
		ep_before, merc.current_ep, mp_before, merc.current_mp, _cap_text(fraction)])
	return lines


#The whole party breathes at once; the between-events gap already paid the ten minutes.
static func breather_party(party: Array[MercenaryData], urgency: float, run: ContractRun) -> Array[String]:
	var lines: Array[String] = []
	for merc: MercenaryData in party:
		lines.append_array(breather(merc, run, urgency))
	return lines


static func respite(party: Array[MercenaryData], run: ContractRun, lockout: bool) -> Array[String]:
	var lines: Array[String] = []
	for merc: MercenaryData in party:
		if merc == null or merc.is_dead:
			continue
		TraitRuntime.fire_rest("rest_start", KIND_RESPITE, merc, run, lines)
		var fraction: float = cap_fraction(merc, PARTIAL_CAP)
		var hp_before: int = merc.current_hp
		var fatigue_before: int = ConstStates.get_count(merc, ConstStates.FATIGUED)
		_top_up(merc, "current_ep", MAX_EP, 1.0)
		_top_up(merc, "current_mp", MAX_MP, 1.0)
		_top_up(merc, "current_hp", MAX_HP, fraction)
		var fatigue_kept: String = ""
		if fatigue_before > 0:
			var dropped: Dictionary = ConstStates.reduce_state_by(merc, ConstStates.FATIGUED, KIND_RESPITE)
			if not bool(dropped["removed"]):
				fatigue_kept = str(dropped["reason"])
		var keep: Array[String] = [ConstStates.FATIGUED]
		var removed: Array[String] = clear_by_verb(merc, KIND_RESPITE, keep)
		removed.append_array(ConstStates.expire_campaign_states(merc, CampaignClock.now() + RESPITE_MINUTES))
		var detail: Array[String] = ["HP %d -> %d (%s)" % [hp_before, merc.current_hp, _cap_text(fraction)]]
		detail.append(_pool_text(merc, "EP", merc.current_ep, MAX_EP))
		detail.append(_pool_text(merc, "MP", merc.current_mp, MAX_MP))
		if fatigue_before > 0:
			if fatigue_kept == "":
				detail.append("Fatigued %d -> %d" % [fatigue_before, ConstStates.get_count(merc, ConstStates.FATIGUED)])
			else:
				detail.append("Fatigued %d kept (%s)" % [fatigue_before, fatigue_kept])
		lines.append("RESPITE: %s %s" % [merc.merc_name, ", ".join(detail)])
		lines.append_array(removed)
		if lockout:
			merc.rest_lockout_until = CampaignClock.now() + RESPITE_MINUTES
			merc.rest_lockout_kind = KIND_RESPITE
			lines.append("RESPITE LOCKOUT: %s until %s" % [merc.merc_name, CampaignClock.stamp(merc.rest_lockout_until)])
		TraitRuntime.fire_rest("rest_complete", KIND_RESPITE, merc, run, lines)
	return lines


#Player choice at the tavern: ten days undeployable, with every recovery paid at completion.
static func furlough_start(merc: MercenaryData) -> Array[String]:
	var lines: Array[String] = []
	if merc == null:
		return lines
	var reason: String = ""
	if merc.is_dead:
		reason = "dead"
	elif is_resting(merc):
		reason = "resting"
	elif merc.on_contract:
		reason = "on contract"
	if reason != "":
		lines.append("FURLOUGH REFUSED: %s (%s)" % [merc.merc_name, reason])
		return lines
	merc.rest_lockout_until = CampaignClock.now() + FURLOUGH_MINUTES
	merc.rest_lockout_kind = KIND_FURLOUGH
	lines.append("FURLOUGH START: %s until %s" % [merc.merc_name, CampaignClock.stamp(merc.rest_lockout_until)])
	return lines


static func furlough_complete(merc: MercenaryData, now: int = -1) -> Array[String]:
	var lines: Array[String] = []
	if merc == null:
		return lines
	var minute: int = CampaignClock.now() if now < 0 else now
	var reason: String = ""
	if merc.is_dead:
		reason = "dead"
	elif merc.rest_lockout_kind != KIND_FURLOUGH:
		reason = "no furlough"
	elif minute < merc.rest_lockout_until:
		reason = "not until " + CampaignClock.stamp(merc.rest_lockout_until)
	if reason != "":
		lines.append("FURLOUGH REFUSED: %s (%s)" % [merc.merc_name, reason])
		return lines
	TraitRuntime.fire_rest("rest_start", KIND_FURLOUGH, merc, null, lines)
	var fatigue_before: int = ConstStates.get_count(merc, ConstStates.FATIGUED)
	_top_up(merc, "current_hp", MAX_HP, 1.0)
	_top_up(merc, "current_ep", MAX_EP, 1.0)
	_top_up(merc, "current_mp", MAX_MP, 1.0)
	var keep: Array[String] = [ConstStates.MADNESS]
	var removed: Array[String] = clear_by_verb(merc, KIND_FURLOUGH, keep)
	removed.append_array(ConstStates.expire_campaign_states(merc, minute))
	var fatigue_held: String = ""
	while ConstStates.get_count(merc, ConstStates.FATIGUED) > 0:
		var tier: Dictionary = ConstStates.reduce_state_by(merc, ConstStates.FATIGUED, KIND_FURLOUGH)
		if not bool(tier["removed"]):
			fatigue_held = str(tier["reason"])
			break
	var detail: Array[String] = [_pool_text(merc, "HP", merc.current_hp, MAX_HP)]
	detail.append(_pool_text(merc, "EP", merc.current_ep, MAX_EP))
	detail.append(_pool_text(merc, "MP", merc.current_mp, MAX_MP))
	var fatigue_after: int = ConstStates.get_count(merc, ConstStates.FATIGUED)
	if fatigue_before > 0:
		if fatigue_after == 0:
			detail.append("Fatigued cleared")
		else:
			detail.append("Fatigued %d -> %d (held: %s)" % [fatigue_before, fatigue_after, fatigue_held])
	var madness_before: int = ConstStates.get_count(merc, ConstStates.MADNESS)
	if madness_before > 0:
		var madness_tier: Dictionary = ConstStates.reduce_state_by(merc, ConstStates.MADNESS, KIND_FURLOUGH)
		if bool(madness_tier["removed"]):
			detail.append("Madness %d -> %d" % [madness_before, ConstStates.get_count(merc, ConstStates.MADNESS)])
		else:
			detail.append("Madness %d kept (%s)" % [madness_before, str(madness_tier["reason"])])
	merc.rest_lockout_until = 0
	merc.rest_lockout_kind = ""
	lines.append("FURLOUGH COMPLETE: %s %s" % [merc.merc_name, ", ".join(detail)])
	lines.append_array(removed)
	TraitRuntime.fire_rest("rest_complete", KIND_FURLOUGH, merc, null, lines)
	return lines


static func complete_due_furloughs(mercs: Array[MercenaryData], now: int) -> Array[String]:
	var lines: Array[String] = []
	for merc: MercenaryData in mercs:
		if merc == null or merc.is_dead or merc.rest_lockout_kind != KIND_FURLOUGH:
			continue
		if merc.rest_lockout_until > now:
			continue
		lines.append_array(furlough_complete(merc, now))
	return lines


#Ends every held state the rest verb may end; a state it may not end reports a STATE HELD line.
#A tiered state outside skip loses at most one tier per call.
static func clear_by_verb(merc: MercenaryData, verb: String, skip: Array[String] = []) -> Array[String]:
	var lines: Array[String] = []
	if merc == null:
		return lines
	var names: Array = merc.active_states.keys()
	for state_name: String in names:
		if state_name == ConstStates.APPLIED_BY_KEY or state_name in skip:
			continue
		if not ConstStates.DATA.has(state_name) or not ConstStates.has_state(merc, state_name):
			continue
		if not _verb_applies(merc, state_name, verb):
			continue
		var result: Dictionary = ConstStates.reduce_state_by(merc, state_name, verb)
		if bool(result["removed"]):
			lines.append("  " + ConstStates.remove_line(merc, state_name))
		else:
			lines.append("  STATE HELD: %s %s rest=%s (%s)" % [merc.merc_name, state_name,
				verb, str(result["reason"])])
	return lines


#The rest reaches the state when its Removal cells name the verb or a recorded source does.
static func _verb_applies(merc: MercenaryData, state_name: String, verb: String) -> bool:
	if ConstStates.has_removal(state_name, verb):
		return true
	for src: Dictionary in ConstStates.state_sources(merc, state_name):
		if ConstStates.source_allows(src, verb):
			return true
	return false


#Another state still applies the Madness, so a Furlough cannot lift a tier of it.
static func madness_source_ongoing(merc: MercenaryData) -> bool:
	if merc == null:
		return false
	return ConstStates.held_reason(merc, ConstStates.MADNESS, KIND_FURLOUGH) == "ongoing source"


static func is_resting(merc: MercenaryData) -> bool:
	if merc == null:
		return false
	return CampaignClock.now() < merc.rest_lockout_until


static func is_deployable(merc: MercenaryData) -> bool:
	return merc != null and not merc.is_dead and not is_resting(merc)


static func party_lost_hp(party: Array[MercenaryData]) -> bool:
	for merc: MercenaryData in party:
		if merc == null or merc.is_dead:
			continue
		if merc.current_hp < _max_of(merc, MAX_HP):
			return true
	return false


#Raises a pool to floor(max * fraction) and returns the gain; a pool already above it is left alone.
static func _top_up(merc: MercenaryData, field: String, max_key: String, fraction: float) -> int:
	var target: int = int(floor(float(_max_of(merc, max_key)) * fraction))
	var current: int = int(merc.get(field))
	var gain: int = maxi(0, target - current)
	if gain > 0:
		merc.set(field, current + gain)
	return gain


static func _max_of(merc: MercenaryData, max_key: String) -> int:
	if merc == null:
		return 0
	return int(merc.stats.get(max_key, 0))


static func _deficit(current: int, maximum: int) -> float:
	if maximum <= 0:
		return 0.0
	return clampf(1.0 - float(current) / float(maximum), 0.0, 1.0)


static func _pool_text(merc: MercenaryData, label: String, current: int, max_key: String) -> String:
	return "%s %d/%d" % [label, current, _max_of(merc, max_key)]


static func _cap_text(fraction: float) -> String:
	return "cap %d%%" % int(round(fraction * 100.0))
