class_name StateInfliction

#Resist specs read "Resist:Stat:N" or "Resist:Stat:N:Attempt"; durations read "N Round", "N Minute" or "N Hour".
const ROUNDS_PER_MINUTE := 6
const ROUNDS_PER_HOUR := 360
#Resist (Stat) is the flat Resist action (Actions.tsv: 15) plus the Resist (Stat) circumstance bonus when held.
const RESIST_FORMULA := "15"
#Stat added to the Resist threshold for the states ConstStates.TOLERANCE_RESIST_STATES names.
const TOLERANCE_STAT := "tolerance"
#Share of Tolerance that reaches the Resist threshold; the designer halved it on 2026-09-11.
const TOLERANCE_SHARE := 0.5
const ATTEMPT_END_TURN := "end_turn"
const ATTEMPT_INTERACT := "interact"


#Accepts "Resist:Vigor:2:End Turn" and its normalized form "resist:vigor:2:end_turn".
static func parse_resist(spec: String) -> Dictionary:
	var parts := StateTokens.normalize_token(spec).split(":")
	if parts.size() < 3 or parts[0] != "resist":
		return {}
	var stat := parts[1]
	var trial := parts[2].to_int()
	if stat == "" or trial < 1:
		return {}
	var attempt := parts[3] if parts.size() > 3 else ""
	return {"type": "resist", "stat": stat, "trial": trial, "attempt": attempt}


static func parse_duration(text: String) -> int:
	var t := text.strip_edges()
	if t == "":
		return 0
	var n := t.get_slice(" ", 0).to_int()
	var unit := t.get_slice(" ", 1).to_lower().trim_suffix("s")
	match unit:
		"round":
			return n
		"minute":
			return n * ROUNDS_PER_MINUTE
		"hour":
			return n * ROUNDS_PER_HOUR
		"day":
			return n * ROUNDS_PER_HOUR * 24
	return 0


#Round whose end of turn removes a state lasting `rounds` from the current round; 0 never expires.
static func expiry_round(state: BattleState, rounds: int) -> int:
	if rounds <= 0 or state == null:
		return 0
	return maxi(1, state.round_number) + rounds - 1


#Minutes of a duration text outside a battle; 0 for the round scale the campaign clock does not measure.
static func campaign_minutes(text: String) -> int:
	var t := text.strip_edges()
	if t == "":
		return 0
	return CampaignClock.minutes_of(t.get_slice(" ", 0).to_int(), t.get_slice(" ", 1))


#A state timed outside a battle expires on the campaign clock; -1 marks one with no timer at all.
static func set_campaign_timer(merc: MercenaryData, state_name: String, duration: String) -> int:
	var minutes: int = campaign_minutes(duration)
	var expiry: int = -1
	if minutes > 0:
		expiry = CampaignClock.now() + minutes
	merc.campaign_states[state_name] = expiry
	return expiry


static func resist_def(stat: String) -> Dictionary:
	return {
		"stat_keys": [stat],
		"circumstances": [ConstCircumstances.resist_name(stat)],
		"knowledges": [],
		"tools": [],
		"formula": RESIST_FORMULA,
	}


#resist_def plus the susceptible/protected bias for the state and any extra flaws from the source.
static func infliction_def(merc: MercenaryData, stat: String, state_name: String,
		extra_flaws: int = 0) -> Dictionary:
	var def := resist_def(stat)
	var bias := ConstStates.resist_bias(merc, state_name)
	def["enhancements"] = int(bias["enhancements"])
	def["flaws"] = int(bias["flaws"]) + maxi(0, extra_flaws)
	def["bias"] = str(bias["token"])
	if state_name in ConstStates.TOLERANCE_RESIST_STATES:
		def["flat_threshold_bonus"] = float(merc.stats.get(TOLERANCE_STAT, 0.0)) * TOLERANCE_SHARE
	return def


#A named state rolls with its bias; a critical success passes whatever the trial is.
#A subject other than the roller owns the bias and the Tolerance, as on an aid roll.
static func resist_check(merc: MercenaryData, spec: Dictionary, state_name: String = "",
		extra_flaws: int = 0, extra_enh: int = 0, subject: MercenaryData = null) -> Dictionary:
	var def := _check_def(merc, spec, state_name, extra_flaws, extra_enh, subject)
	var result := CheckSystem.make_check(merc, def)
	result["passed"] = int(result["successes"]) >= int(spec["trial"]) or bool(result.get("critical", false))
	result["bias"] = str(def.get("bias", ""))
	LifepathTally.record_check(merc, "resist", int(result["successes"]), bool(result["passed"]), false)
	return result


#Chance the same roll resist_check would make meets the spec trial, without rolling.
static func resist_chance(merc: MercenaryData, spec: Dictionary, state_name: String = "",
		extra_flaws: int = 0, extra_enh: int = 0, subject: MercenaryData = null) -> float:
	return CheckSystem.expected_success_chance(merc,
		_check_def(merc, spec, state_name, extra_flaws, extra_enh, subject), int(spec["trial"]))


static func _check_def(merc: MercenaryData, spec: Dictionary, state_name: String,
		extra_flaws: int, extra_enh: int = 0, subject: MercenaryData = null) -> Dictionary:
	var stat: String = str(spec["stat"])
	var owner: MercenaryData = subject if subject != null else merc
	var def: Dictionary = resist_def(stat) if state_name == "" else infliction_def(owner, stat, state_name, extra_flaws)
	if extra_enh != 0:
		def["enhancements"] = int(def.get("enhancements", 0)) + extra_enh
	return def


#Enhancements a helper adds to an aid roll; today only the Beau support passive raises it.
static func support_enhancements(actor: MercenaryData, target: MercenaryData, spec: Dictionary) -> int:
	if actor == null or target == null or actor == target:
		return 0
	var mult: float = BeauSystem.support_multiplier(actor, target)
	if mult <= 1.0:
		return 0
	var pool: int = int(actor.stats.get(str(spec.get("stat", "")), 0))
	return maxi(0, ceili(float(pool) * (mult - 1.0)))


#A failed infliction Resist applies the state with its expiry round and remove method.
static func inflict(merc: MercenaryData, state_name: String, inflict_spec: String, duration: String,
		remove_spec: String, source: MercenaryData, state: BattleState,
		extra_flaws: int = 0) -> Array[String]:
	var lines: Array[String] = []
	var spec := parse_resist(inflict_spec)
	if spec.is_empty():
		push_warning("StateInfliction: bad inflict spec " + inflict_spec)
		return lines
	if merc.is_dead:
		return lines
	if ConstStates.is_immune(merc, state_name):
		lines.append("  %s is immune to %s!" % [BattleState.colored_name(merc, state), state_name])
		if state != null:
			state.learn_state_immunity(source, merc, state_name)
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("INFLICT: %s %s Resist(%s) immune -> IMMUNE source=%s" % [
				merc.merc_name, state_name, str(spec["stat"]), source.merc_name if source != null else "none"])
		return lines
	var result := resist_check(merc, spec, state_name, extra_flaws)
	var passed: bool = result["passed"]
	var expires := expiry_round(state, parse_duration(duration))
	var stat_label := str(spec["stat"]).capitalize()
	if passed:
		lines.append("  %s resists %s! [Resist %s: %d]" % [
			BattleState.colored_name(merc, state), state_name, stat_label, int(result["successes"])])
	else:
		var origin: String = "inflict:" + (source.merc_name if source != null else "none")
		if ConstStates.apply_state(merc, state_name, source, "", origin) and source != null and source != merc:
			LifepathTally.record_inflicted(source, state_name)
		if state != null:
			state.set_state_timer(merc, state_name, expires, remove_spec)
		else:
			set_campaign_timer(merc, state_name, duration)
		lines.append("  %s fails to resist %s! [Resist %s: %d]" % [
			BattleState.colored_name(merc, state), state_name, stat_label, int(result["successes"])])
		var text := narrate(merc, state_name, source, state, "afflict_text")
		if text != "":
			lines.append("  " + text)
		TraitRuntime.on_state_gained(merc, state_name, state, lines)
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("INFLICT: %s %s Resist(%s) %s -> %s source=%s expires=R%d remove=%s" % [
			merc.merc_name, state_name, str(spec["stat"]), _roll_text(result, int(spec["trial"])),
			"RESISTED" if passed else "AFFLICTED", source.merc_name if source != null else "none",
			expires, remove_spec])
	return lines


#States.tsv Inflict Default for the state; an empty duration never expires, an empty remove holds.
static func inflict_default(merc: MercenaryData, state_name: String, source: MercenaryData,
		state: BattleState, extra_flaws: int = 0) -> Array[String]:
	var d := ConstStates.inflict_default(state_name)
	if d.is_empty():
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("INFLICT DEFAULT MISSING: %s" % state_name)
		return [] as Array[String]
	return inflict(merc, state_name, str(d["inflict"]), str(d["duration"]), str(d["remove"]),
		source, state, extra_flaws)


#End Turn attempts and expiries for every timed state on the merc; stale timers are dropped.
static func end_of_turn(merc: MercenaryData, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	if merc.is_dead:
		return lines
	for state_name: String in state.get_timed_states(merc):
		if not ConstStates.has_state(merc, state_name):
			state.clear_state_timer(merc, state_name)
			continue
		var timer: Dictionary = state.get_state_timer(merc, state_name)
		var spec := parse_resist(str(timer.get("remove", "")))
		if not spec.is_empty() and str(spec["attempt"]) == ATTEMPT_END_TURN:
			var result := resist_check(merc, spec, state_name)
			_log_check(merc, state_name, spec, result, ATTEMPT_END_TURN)
			if result["passed"]:
				lines.append_array(remove_timed(merc, state_name, state, "resisted",
					"Resist %s: %d" % [str(spec["stat"]).capitalize(), int(result["successes"])]))
				continue
		var expires := int(timer.get("expires", 0))
		if expires > 0 and state.round_number >= expires:
			lines.append_array(remove_timed(merc, state_name, state, "expired", "expired"))
	return lines


#An Interact removal attempt; a state whose timer carries no Resist spec ends outright.
#An actor is a helper rolling in the afflicted merc's place.
static func attempt_interact(merc: MercenaryData, state_name: String, state: BattleState,
		actor: MercenaryData = null) -> Array[String]:
	var lines: Array[String] = []
	if not ConstStates.has_state(merc, state_name):
		return lines
	var roller: MercenaryData = actor if actor != null else merc
	if actor != null:
		lines.append("  %s helps %s end %s!" % [BattleState.colored_name(actor, state), BattleState.colored_name(merc, state), state_name])
	var timer: Dictionary = state.get_state_timer(merc, state_name)
	var spec := parse_resist(str(timer.get("remove", "")))
	if spec.is_empty():
		lines.append_array(remove_timed(merc, state_name, state, "action", "action"))
		return lines
	var extra_enh: int = support_enhancements(actor, merc, spec)
	if extra_enh > 0:
		lines.append("  BEAU SUPPORT: %s +%d for %s" % [roller.merc_name, extra_enh, merc.merc_name])
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("BEAU SUPPORT: %s +%d for %s" % [
				roller.merc_name, extra_enh, merc.merc_name])
	var result := resist_check(roller, spec, state_name, 0, extra_enh, merc)
	_log_check(merc, state_name, spec, result,
		"aid" if actor != null else ATTEMPT_INTERACT,
		roller.merc_name if actor != null else "")
	var detail := "Resist %s: %d" % [str(spec["stat"]).capitalize(), int(result["successes"])]
	if result["passed"]:
		lines.append_array(remove_timed(merc, state_name, state, "action", detail))
	else:
		lines.append("  %s fails to end %s! [%s]" % [BattleState.colored_name(merc, state), state_name, detail])
	return lines


#Removes the state (one stack for stacking states), drops its timer and narrates the remove text.
#A state another root still applies keeps that source; only its timer is dropped.
static func remove_timed(merc: MercenaryData, state_name: String, state: BattleState,
		reason: String, detail: String) -> Array[String]:
	var lines: Array[String] = []
	var source: MercenaryData = ConstStates.get_source(merc, state_name)
	if state != null:
		state.clear_state_timer(merc, state_name)
	if state_name in ConstStates.STACKING_STATES:
		ConstStates.reduce_state(merc, state_name)
	elif not ConstStates.remove_state(merc, state_name)["removed"]:
		lines.append("  %s is still %s. [%s]" % [BattleState.colored_name(merc, state), state_name, detail])
		return lines
	var text := narrate(merc, state_name, source, state, "remove_text")
	if text == "":
		text = "%s is no longer %s." % [BattleState.colored_name(merc, state), state_name]
	lines.append("  %s [%s]" % [text, detail])
	_log_removed(merc, state_name, state, reason)
	return lines


#Removals done by action code elsewhere drop the timer here and log the same STATE REMOVED line.
static func note_removed(merc: MercenaryData, state_name: String, state: BattleState, reason: String) -> void:
	if state != null:
		state.clear_state_timer(merc, state_name)
	_log_removed(merc, state_name, state, reason)


#A dead source lets go: every Grappled that names it ends, and a registered kidnap pair with it.
static func release_held_by(dead: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	if dead == null or state == null:
		return
	for team: Variant in state.teams:
		for m: Variant in (team as Array):
			if not (m is MercenaryData):
				continue
			var merc := m as MercenaryData
			if merc == dead or not ConstStates.has_state(merc, ConstStates.GRAPPLED):
				continue
			if ConstStates.get_source(merc, ConstStates.GRAPPLED) != dead:
				continue
			if ConstStates.remove_state(merc, ConstStates.GRAPPLED)["removed"]:
				note_removed(merc, ConstStates.GRAPPLED, state, "source_death")
				lines.append("  %s is no longer grappled: %s is dead" % [
					BattleState.colored_name(merc, state), BattleState.colored_name(dead, state)])
	KidnapSystem.unregister(dead, state)


static func _log_removed(merc: MercenaryData, state_name: String, state: BattleState, reason: String) -> void:
	if not EncounterLogger.is_active():
		return
	var round_no: int = state.round_number if state != null else 0
	EncounterLogger.log_verbose("STATE REMOVED: %s %s reason=%s round=%d" % [
		merc.merc_name, state_name, reason, round_no])


static func narrate(merc: MercenaryData, state_name: String, source: MercenaryData,
		state: BattleState, key: String) -> String:
	var source_name: String = "" if source == null else BattleState.colored_name(source, state)
	return StateText.narrate_text(state_name, key, BattleState.colored_name(merc, state), source_name,
		BeauSystem.beau_name(merc, {"state": state}))


static func _roll_text(result: Dictionary, trial: int) -> String:
	var extra := ""
	if bool(result.get("critical", false)):
		extra += " crit"
	if str(result.get("bias", "")) != "":
		extra += " bias=" + str(result["bias"])
	return "rolls=%s vs %.0f%% -> %d success %d fail need %d%s" % [
		str(result["roll2"]), float(result["threshold"]), int(result["successes"]),
		int(result["failures"]), trial, extra]


static func _log_check(merc: MercenaryData, state_name: String, spec: Dictionary,
		result: Dictionary, attempt: String, roller_name: String = "") -> void:
	if not EncounterLogger.is_active():
		return
	EncounterLogger.log_verbose("STATE CHECK: %s %s %s Resist(%s) %s -> %s%s" % [
		merc.merc_name, state_name, attempt, str(spec["stat"]), _roll_text(result, int(spec["trial"])),
		"REMOVED" if result["passed"] else "HOLDS",
		"" if roller_name == "" else " by " + roller_name])


