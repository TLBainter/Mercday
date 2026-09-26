class_name RestSystem

#The three rests: Breather, Respite and Furlough. A rest tops a pool up to a fraction of its
#maximum and never lowers one. Stats.tsv Rest Recovery is a signed percent of rest time saved
#(healthiness by default): +25 rests 25% faster, -100 takes twice as long, and each rest has a
#minimum (1 min, 1 h, 1 d). On a contract the slowest merc sets the party's time. Rests never touch
#the excess pools. Only a Respite or a Furlough locks out, and a locked out rest completes on the
#clock; a rest never ends a timer early. A completed rest also takes one RestActions rest action of
#its kind. Maximum HP, EP and MP reductions and any Furlough training last until the next Furlough
#completes, which restores all three and ends the training.

const BREATHER_MINUTES := 10
const RESPITE_MINUTES := 360
const FURLOUGH_MINUTES := 14400
const PARTIAL_CAP := 0.5
const BREATHER_MIN_DEFICIT := 0.25
const MIN_REST_MINUTES := 1
const RESPITE_MIN_MINUTES := 60
const FURLOUGH_MIN_MINUTES := 1440

const KIND_BREATHER := "breather"
const KIND_RESPITE := "respite"
const KIND_FURLOUGH := "furlough"

const MAX_HP := "maximum_hit_points"
const MAX_EP := "maximum_endurance_points"
const MAX_MP := "maximum_magic_points"


#Stats.tsv Rest Recovery: the signed percent of rest time saved; a missing value reads 0.
static func rest_recovery(merc: MercenaryData) -> float:
	if merc == null:
		return 0.0
	return float(merc.stats.get("rest_recovery", 0.0))


#The shortest a rest of base_minutes may ever take.
static func min_minutes(base_minutes: int) -> int:
	if base_minutes == FURLOUGH_MINUTES:
		return FURLOUGH_MIN_MINUTES
	if base_minutes == RESPITE_MINUTES:
		return RESPITE_MIN_MINUTES
	return MIN_REST_MINUTES


#Whole minutes one merc needs for a rest; a higher Rest Recovery rests faster, never below the minimum.
static func rest_minutes(merc: MercenaryData, base_minutes: int) -> int:
	return maxi(min_minutes(base_minutes), int(round(float(base_minutes) * (1.0 - rest_recovery(merc) / 100.0))))


#The slowest living merc; null for an empty or dead party.
static func party_slowest(party: Array[MercenaryData], base_minutes: int) -> MercenaryData:
	var slowest: MercenaryData = null
	var most: int = -1
	for merc: MercenaryData in party:
		if merc == null or merc.is_dead:
			continue
		var minutes: int = rest_minutes(merc, base_minutes)
		if minutes > most:
			most = minutes
			slowest = merc
	return slowest


#On a contract the party rests at the slowest merc's pace; an empty or dead party rests at the base.
static func party_rest_minutes(party: Array[MercenaryData], base_minutes: int) -> int:
	var slowest: MercenaryData = party_slowest(party, base_minutes)
	if slowest == null:
		return base_minutes
	return rest_minutes(slowest, base_minutes)


#"REST TIME: respite 3 h (slowest Fira, rest recovery +50%)"
static func party_line(kind: String, party: Array[MercenaryData], base_minutes: int) -> String:
	var slowest: MercenaryData = party_slowest(party, base_minutes)
	var minutes: int = base_minutes if slowest == null else rest_minutes(slowest, base_minutes)
	var span: String = CampaignClock.delta_text(minutes).trim_prefix("+")
	if slowest == null:
		return "REST TIME: %s %s" % [kind, span]
	return "REST TIME: %s %s (slowest %s, rest recovery %+d%%)" % [kind, span, slowest.merc_name,
		int(round(rest_recovery(slowest)))]


#A merc missing a quarter or more of its EP or MP wants a Breather; urgency raises that bar.
static func wants_breather(merc: MercenaryData, urgency: float) -> bool:
	if merc == null or merc.is_dead:
		return false
	var ep_deficit: float = _deficit(merc.current_ep, RestActions.max_of(merc, MAX_EP))
	var mp_deficit: float = _deficit(merc.current_mp, RestActions.max_of(merc, MAX_MP))
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
			merc.current_ep, RestActions.max_of(merc, MAX_EP), merc.current_mp, RestActions.max_of(merc, MAX_MP)])
		return lines
	TraitRuntime.fire_rest("rest_start", KIND_BREATHER, merc, run, lines)
	var fraction: float = PARTIAL_CAP
	var ep_before: int = merc.current_ep
	var mp_before: int = merc.current_mp
	_top_up(merc, "current_ep", MAX_EP, fraction)
	_top_up(merc, "current_mp", MAX_MP, fraction)
	lines.append("BREATHER: %s EP %d -> %d, MP %d -> %d (%s)" % [merc.merc_name,
		ep_before, merc.current_ep, mp_before, merc.current_mp, _cap_text(fraction)])
	RestActions.take(KIND_BREATHER, merc, lines)
	TraitRuntime.fire_rest("rest_complete", KIND_BREATHER, merc, run, lines)
	return lines


#The whole party breathes at once; the caller has already paid the party's Breather time.
static func breather_party(party: Array[MercenaryData], urgency: float, run: ContractRun) -> Array[String]:
	var lines: Array[String] = []
	for merc: MercenaryData in party:
		lines.append_array(breather(merc, run, urgency))
	return lines


#The paid Respite: the caller has already spent the party's rest time on the clock.
static func respite(party: Array[MercenaryData], run: ContractRun) -> Array[String]:
	var lines: Array[String] = []
	for merc: MercenaryData in party:
		if merc == null or merc.is_dead:
			continue
		TraitRuntime.fire_rest("rest_start", KIND_RESPITE, merc, run, lines)
		_respite_recover(merc, lines)
		TraitRuntime.fire_rest("rest_complete", KIND_RESPITE, merc, run, lines)
	return lines


#The deferred Respite: the lockout is stamped now and the recovery lands when the clock reaches it.
static func respite_start(party: Array[MercenaryData], run: ContractRun) -> Array[String]:
	var lines: Array[String] = []
	for merc: MercenaryData in party:
		if merc == null or merc.is_dead:
			continue
		TraitRuntime.fire_rest("rest_start", KIND_RESPITE, merc, run, lines)
		var minutes: int = rest_minutes(merc, RESPITE_MINUTES)
		merc.rest_lockout_until = CampaignClock.now() + minutes
		merc.rest_lockout_kind = KIND_RESPITE
		lines.append("RESPITE LOCKOUT: %s until %s (%s)" % [merc.merc_name,
			CampaignClock.stamp(merc.rest_lockout_until), CampaignClock.delta_text(minutes).trim_prefix("+")])
	return lines


#The refusal a due rest may meet; appends the REFUSED line and reports true when the rest cannot run.
static func _lockout_refusal(merc: MercenaryData, kind: String, minute: int, lines: Array[String]) -> bool:
	var reason: String = ""
	if merc.is_dead:
		reason = "dead"
	elif merc.rest_lockout_kind != kind:
		reason = "no " + kind
	elif minute < merc.rest_lockout_until:
		reason = "not until " + CampaignClock.stamp(merc.rest_lockout_until)
	if reason == "":
		return false
	lines.append("%s REFUSED: %s (%s)" % [kind.to_upper(), merc.merc_name, reason])
	return true


static func respite_complete(merc: MercenaryData, now: int = -1) -> Array[String]:
	var lines: Array[String] = []
	if merc == null:
		return lines
	var minute: int = CampaignClock.now() if now < 0 else now
	if _lockout_refusal(merc, KIND_RESPITE, minute, lines):
		return lines
	_respite_recover(merc, lines)
	merc.rest_lockout_until = 0
	merc.rest_lockout_kind = ""
	TraitRuntime.fire_rest("rest_complete", KIND_RESPITE, merc, null, lines)
	return lines


#Every recovery a Respite pays, with its RESPITE line and the lines of the states it ended.
static func _respite_recover(merc: MercenaryData, lines: Array[String]) -> void:
	var fraction: float = PARTIAL_CAP
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
	RestActions.take(KIND_RESPITE, merc, lines)


#Player choice at the tavern: undeployable for the merc's own Furlough time, every recovery paid at completion.
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
	TraitRuntime.fire_rest("rest_start", KIND_FURLOUGH, merc, null, lines)
	var minutes: int = rest_minutes(merc, FURLOUGH_MINUTES)
	merc.rest_lockout_until = CampaignClock.now() + minutes
	merc.rest_lockout_kind = KIND_FURLOUGH
	lines.append("FURLOUGH START: %s until %s (%s)" % [merc.merc_name,
		CampaignClock.stamp(merc.rest_lockout_until), CampaignClock.delta_text(minutes).trim_prefix("+")])
	return lines


static func furlough_complete(merc: MercenaryData, now: int = -1) -> Array[String]:
	var lines: Array[String] = []
	if merc == null:
		return lines
	var minute: int = CampaignClock.now() if now < 0 else now
	if _lockout_refusal(merc, KIND_FURLOUGH, minute, lines):
		return lines
	var fatigue_before: int = ConstStates.get_count(merc, ConstStates.FATIGUED)
	var restored: Array[String] = _furlough_restore(merc)
	var keep: Array[String] = [ConstStates.MADNESS, ConstStates.FATIGUED]
	var removed: Array[String] = clear_by_verb(merc, KIND_FURLOUGH, keep)
	removed.append_array(StateCampaign.expire_campaign_states(merc, minute))
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
	detail.append_array(restored)
	_furlough_upkeep(merc, detail)
	merc.rest_lockout_until = 0
	merc.rest_lockout_kind = ""
	lines.append("FURLOUGH COMPLETE: %s %s" % [merc.merc_name, ", ".join(detail)])
	lines.append_array(removed)
	RestActions.take(KIND_FURLOUGH, merc, lines)
	TraitRuntime.fire_rest("rest_complete", KIND_FURLOUGH, merc, null, lines)
	return lines


#Refills every pool and lifts the maximum reductions; reports the restore entries the log prints.
static func _furlough_restore(merc: MercenaryData) -> Array[String]:
	var hp_penalty: int = merc.max_hp_penalty
	var ep_penalty: int = merc.max_ep_penalty
	var mp_penalty: int = merc.max_mp_penalty
	if hp_penalty > 0 or ep_penalty > 0 or mp_penalty > 0:
		merc.max_hp_penalty = 0
		merc.max_ep_penalty = 0
		merc.max_mp_penalty = 0
		StatCalculator.refresh(merc)
	_top_up(merc, "current_hp", MAX_HP, 1.0)
	_top_up(merc, "current_ep", MAX_EP, 1.0)
	_top_up(merc, "current_mp", MAX_MP, 1.0)
	var restored: Array[String] = []
	if hp_penalty > 0:
		restored.append("max HP restored")
	if ep_penalty > 0:
		restored.append("max EP restored")
	if mp_penalty > 0:
		restored.append("max MP restored")
	return restored


#The gear a Furlough puts right: broken armor, a snapped bowstring and the training it ends.
static func _furlough_upkeep(merc: MercenaryData, detail: Array[String]) -> void:
	if merc.armor_break > 0:
		detail.append("armor repaired")
		merc.armor_break = 0
	restring_weapons(merc, detail)
	var training: String = RestActions.end_training(merc)
	if training != "":
		detail.append(training)


#A furlough restrings every snapped bow the merc carries, the way it repairs broken armor.
static func restring_weapons(merc: MercenaryData, detail: Array[String]) -> void:
	if merc == null:
		return
	var carried: Array[WeaponData] = []
	if merc.equipped_weapon != null:
		carried.append(merc.equipped_weapon)
	if merc.offhand_weapon != null:
		carried.append(merc.offhand_weapon)
	for entry: Dictionary in merc.inventory:
		if entry.get("type") != "weapon":
			continue
		var stowed: WeaponData = entry.get("data") as WeaponData
		if stowed != null:
			carried.append(stowed)
	var restrung: bool = false
	for weapon: WeaponData in carried:
		if not weapon.string_snapped:
			continue
		weapon.string_snapped = false
		weapon.repair_ap_paid = 0
		restrung = true
	if restrung:
		detail.append("bowstring restrung")


#Every locked out merc whose rest has come due; the clock ends a rest, never a caller.
static func complete_due_rests(mercs: Array[MercenaryData], now: int) -> Array[String]:
	var lines: Array[String] = []
	for merc: MercenaryData in mercs:
		if merc == null or merc.is_dead:
			continue
		if merc.rest_lockout_until > now:
			continue
		if merc.rest_lockout_kind == KIND_FURLOUGH:
			lines.append_array(furlough_complete(merc, now))
		elif merc.rest_lockout_kind == KIND_RESPITE:
			lines.append_array(respite_complete(merc, now))
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
			lines.append("  " + StateText.remove_line(merc, state_name))
		else:
			lines.append("  STATE HELD: %s %s rest=%s (%s)" % [merc.merc_name, state_name,
				verb, str(result["reason"])])
	return lines


#The rest reaches the state when its Removal cells name the verb or a recorded source does.
static func _verb_applies(merc: MercenaryData, state_name: String, verb: String) -> bool:
	if ConstStates.has_removal(state_name, verb):
		return true
	for src: Dictionary in StateSources.state_sources(merc, state_name):
		if StateSources.source_allows(src, verb):
			return true
	return false


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
		if merc.current_hp < RestActions.max_of(merc, MAX_HP):
			return true
	return false


#Raises a pool to floor(max * fraction) and returns the gain; a pool already above it is left alone.
static func _top_up(merc: MercenaryData, field: String, max_key: String, fraction: float) -> int:
	var target: int = int(floor(float(RestActions.max_of(merc, max_key)) * fraction))
	var current: int = int(merc.get(field))
	var gain: int = maxi(0, target - current)
	if gain > 0:
		merc.set(field, current + gain)
	return gain


static func _deficit(current: int, maximum: int) -> float:
	if maximum <= 0:
		return 0.0
	return clampf(1.0 - float(current) / float(maximum), 0.0, 1.0)


static func _pool_text(merc: MercenaryData, label: String, current: int, max_key: String) -> String:
	return "%s %d/%d" % [label, current, RestActions.max_of(merc, max_key)]


static func _cap_text(fraction: float) -> String:
	return "cap %d%%" % int(round(fraction * 100.0))
