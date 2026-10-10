class_name CalledShotSystem

#Called Shot options: value = successes removed; state options carry rounds (0 = no timer).
const OPTIONS: Dictionary = {
	"calf": {"label": "Calf", "value": 1, "state": "Hobbled", "rounds": 1},
	"ear": {"label": "Ear", "value": 1, "state": "Deafened", "rounds": 1},
	"eye": {"label": "Eye", "value": 2, "state": "Blinded", "rounds": 1},
	"face": {"label": "Face", "value": 4, "lifepath": "Scarred"},
	"heel": {"label": "Heel", "value": 3, "state": "Deposed", "rounds": 0},
	"mouth": {"label": "Mouth", "value": 2, "state": "Mute", "rounds": 1},
	"throat": {"label": "Throat", "value": 5, "state": "Vulnerable", "rounds": 1},
	"vital_organ": {"label": "Vital Organ", "value": 3, "state": "Shocked", "rounds": 1},
	"wing": {"label": "Wing", "value": 2, "state": "Grounded", "rounds": 1, "flyer_only": true},
	"wound": {"label": "Wound", "value": 4, "crit": true},
	"wrist": {"label": "Wrist", "value": 2, "drop": true},
}

const ORIGIN := "engine:called_shot"
const DROP_VALUE := 2.0
const WOUND_VALUE := 1.0

#Face is never chosen by the AI; it buys a lifepath event and nothing the battle can use.
const AI_OPTIONS: Array[String] = ["calf", "ear", "eye", "heel", "mouth", "throat",
	"vital_organ", "wing", "wound", "wrist"]

static var force_every := false
static var force_option := ""
static var calls_made := 0
static var calls_landed := 0


static func value(key: String) -> int:
	var opt: Dictionary = OPTIONS.get(key, {})
	return int(opt.get("value", 0))


static func label(key: String) -> String:
	var opt: Dictionary = OPTIONS.get(key, {})
	return str(opt.get("label", ""))


#Whether this option can do anything to this target right now.
static func is_valid(merc: MercenaryData, target: MercenaryData, key: String, state: BattleState) -> bool:
	if not OPTIONS.has(key):
		return false
	if target == null or target.is_dead or target.off_field:
		return false
	var opt: Dictionary = OPTIONS[key]
	var state_name := str(opt.get("state", ""))
	if state_name != "":
		if ConstStates.has_state(target, state_name):
			return false
		if state != null and CombatApplicator.known_immune(merc, target, state_name, str(opt.get("label", ""))):
			return false
	if bool(opt.get("flyer_only", false)) and not PathTargeter.is_flying(target):
		return false
	if bool(opt.get("drop", false)):
		return target.weapon_drawn and target.equipped_weapon != null and not target.equipped_weapon.is_virtual
	if str(opt.get("lifepath", "")) != "":
		return not LifepathProgression.has_event(target, str(opt["lifepath"]))
	return true


static func call_line(merc: MercenaryData, key: String, state: BattleState) -> String:
	return call_line_text(merc, label(key), value(key), state)


static func call_line_text(merc: MercenaryData, text: String, v: int, state: BattleState) -> String:
	return "  %s calls the shot: %s (%d)!" % [BattleState.colored_name(merc, state), text, v]


static func hp_total(target: MercenaryData) -> int:
	return ExcessPool.hp_total(target)


#A critical always lands; otherwise the target must mark HP past the defence, not the min 1 floor alone,
#and one core success must be left over after the called shot cost.
static func landed(atk: Dictionary, hp_before: int, target: MercenaryData) -> bool:
	if bool(atk.get("critical", false)):
		return true
	if atk.has("core_successes") and int(atk["core_successes"]) < 1:
		return false
	if bool(atk.get("min_1_only", false)):
		return false
	return hp_before - hp_total(target) >= 1


static func after_hit(merc: MercenaryData, target: MercenaryData, key: String, atk: Dictionary,
		hp_before: int, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	if not OPTIONS.has(key) or target == null:
		return lines
	if not landed(atk, hp_before, target):
		var no_core := atk.has("core_successes") and int(atk["core_successes"]) < 1
		if no_core and EncounterLogger.is_active():
			EncounterLogger.log_verbose("CALLED SHOT CORE: %s vs %s no core success left, no effect" % [
				merc.merc_name if merc != null else "?", target.merc_name])
		elif bool(atk.get("min_1_only", false)) and EncounterLogger.is_active():
			EncounterLogger.log_verbose("CALLED SHOT FLOOR: %s vs %s min 1 mark only, no effect" % [
				merc.merc_name if merc != null else "?", target.merc_name])
		lines.append("  The called shot to the %s has no effect." % label(key).to_lower())
		return lines
	calls_landed += 1
	if target.is_dead or target.off_field:
		return lines
	lines.append_array(apply_effect(merc, target, key, atk, state))
	return lines


static func apply_effect(merc: MercenaryData, target: MercenaryData, key: String, atk: Dictionary,
		state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	var opt: Dictionary = OPTIONS.get(key, {})
	if opt.is_empty():
		return lines
	var state_name := str(opt.get("state", ""))
	if state_name != "":
		var applied := _apply_state(merc, target, state_name, int(opt.get("rounds", 0)), state, lines)
		if applied and bool(opt.get("flyer_only", false)) and state != null:
			var h := state.get_height(target)
			if h > 0:
				state.set_height(target, 0)
				lines.append_array(FallResolver.resolve_fall(target, h, state))
		return lines
	if bool(opt.get("crit", false)):
		lines.append("  %s strikes a grievous wound!" % BattleState.colored_name(merc, state))
		if not bool(atk.get("critical", false)):
			lines.append_array(WeaponReactiveSystem.fire_trigger(merc, "on_crit", target, atk, state,
				int(atk.get("enhancements", 0))))
		return lines
	if bool(opt.get("drop", false)):
		if target.weapon_drawn and target.equipped_weapon != null and not target.equipped_weapon.is_virtual:
			lines.append_array(WeaponActionExecutor.execute_drop(target, state, "called shot"))
		else:
			lines.append("  %s has nothing to drop." % BattleState.colored_name(target, state))
		return lines
	var event_name := str(opt.get("lifepath", ""))
	if event_name != "":
		lines.append("  %s is scarred!" % BattleState.colored_name(target, state))
		lines.append_array(LifepathProgression.force(target, event_name))
	return lines


#Applies one state outside the resist cascade; returns false when the target shrugged it off.
static func _apply_state(merc: MercenaryData, target: MercenaryData, state_name: String, rounds: int,
		state: BattleState, lines: Array[String]) -> bool:
	if not StateCascade.apply_state(target, state_name, merc, "", ORIGIN):
		lines.append("  %s is immune to %s!" % [BattleState.colored_name(target, state), state_name])
		if state != null:
			state.learn_state_immunity(merc, target, state_name)
		return false
	if rounds > 0 and state != null:
		state.set_state_timer(target, state_name, StateInfliction.expiry_round(state, rounds), "")
	var text := StateInfliction.narrate(target, state_name, merc, state, "afflict_text")
	if text != "":
		lines.append("  " + text)
	LifepathTally.record_inflicted(merc, state_name)
	TraitRuntime.on_state_gained(target, state_name, state, lines)
	return true


#The needs_head stat; true when the stat is absent.
static func needs_head(merc: MercenaryData) -> bool:
	if merc == null:
		return false
	return bool(merc.stats.get("needs_head", true))


#True when the merc stands behind the target: its facing is where it last struck, else where it last moved.
static func faces_away(target: MercenaryData, merc: MercenaryData, state: BattleState) -> bool:
	if target == null or merc == null or state == null or state.battlefield == null:
		return false
	var facing := Vector2i.ZERO
	var focus: MercenaryData = state.last_attacked.get(target) as MercenaryData
	if focus != null and focus != merc and BattleState._is_alive(focus) and not focus.off_field:
		facing = state.get_position(focus) - state.get_position(target)
	elif (state.escalation.get(target, {}) as Dictionary).has("last_move_from"):
		var from3: Vector3i = state.escalation[target]["last_move_from"]
		facing = state.get_position(target) - Vector2i(from3.x, from3.y)
	else:
		return false
	if facing == Vector2i.ZERO:
		return false
	var to_merc := state.get_position(merc) - state.get_position(target)
	return to_merc.x * facing.x + to_merc.y * facing.y < 0


#The perk rows that make a called shot of their own (Atlas Vertebra, Skull Splitter).
static func perk_ready(merc: MercenaryData, target: MercenaryData, info: Dictionary,
		state: BattleState) -> bool:
	if merc == null or target == null or state == null or state.battlefield == null:
		return false
	if not BattleState._is_alive(target) or target.off_field:
		return false
	if not PerkValuation.sees_target(merc, target, state):
		return false
	if state.distance_to(merc, target) > 1:
		return false
	var parts: PackedStringArray = info.get("parts", PackedStringArray())
	var flags := _perk_flags(info)
	if flags.has("two_handed") and not WeaponArmorPerkLibrary.is_wielding_two_handed(merc):
		return false
	if flags.has("neck_facing_away") and not faces_away(target, merc, state):
		return false
	return parts.size() > int(info.get("effect_start", 2)) + 1


static func perk_value(merc: MercenaryData, target: MercenaryData, info: Dictionary,
		state: BattleState) -> float:
	if merc == null or target == null:
		return 0.0
	var parts: PackedStringArray = info.get("parts", PackedStringArray())
	var start := int(info.get("effect_start", 2))
	if parts.size() <= start + 1:
		return 0.0
	var v := int(parts[start + 1])
	var weapon: WeaponData = merc.equipped_weapon
	var p_land := float(CalledShotOdds.expected_marked(CalledShotOdds.marked_context(merc, target, state, 0), v)["land"])
	var raw := PerkValuation.raw_damage(merc, weapon, 0)
	var defense := PerkValuation.expected_defense(target)
	var pain := float(target.stats.get("pain_limit", 0))
	var hp := float(maxi(1, hp_total(target)))
	var flags := _perk_flags(info)
	var worth := 0.0
	if flags.has("damage") and flags.has("pain_limit"):
		worth = maxf(pain, raw - float(v))
		if pain >= hp:
			worth += PerkValuation.kill_value(target, state)
	else:
		worth = maxf(0.0, raw - float(v) - defense)
		if raw - float(v) >= pain and pain > 0.0 and needs_head(target):
			worth += PerkValuation.kill_value(target, state)
	return p_land * worth


static func perk_called_shot(merc: MercenaryData, perk: TraitData, target: MercenaryData,
		info: Dictionary, state: BattleState, enhancements: int) -> Array[String]:
	var lines: Array[String] = []
	var parts: PackedStringArray = info.get("parts", PackedStringArray())
	var start := int(info.get("effect_start", 2))
	if parts.size() <= start + 1:
		return lines
	var v := int(parts[start + 1])
	var flags := _perk_flags(info)
	lines.append("  %s %s" % [BattleState.colored_name(merc, state), PerkActionExecutor._perk_announce(perk)])
	lines.append(call_line_text(merc, _perk_label(perk), v, state))
	calls_made += 1
	var hp_before := hp_total(target)
	target.active_states.erase("pain_fired")
	var res := PerkActionExecutor._perk_attack(merc, target, state, enhancements, 0, 0, 0, "",
		_perk_label(perk), v, "CalledShot")
	lines.append_array(res["lines"] as Array[String])
	if not landed(res["atk"] as Dictionary, hp_before, target):
		lines.append("  The called shot to the %s has no effect." % _perk_label(perk).to_lower())
		return lines
	calls_landed += 1
	if flags.has("damage") and flags.has("pain_limit"):
		var pain := int(target.stats.get("pain_limit", 0))
		var dealt := hp_before - hp_total(target)
		if pain > dealt and BattleState._is_alive(target):
			lines.append_array(CombatApplicator.deal_direct(merc, target, pain - dealt,
				PerkActionExecutor._perk_damage_type(merc), state, "Atlas Vertebra"))
	if flags.has("debilitated_on_1hp") and BattleState._is_alive(target) and hp_total(target) <= 1:
		_apply_state(merc, target, "Debilitated", 0, state, lines)
	if flags.has("instant_kill_on_pain") and BattleState._is_alive(target) \
			and bool(target.active_states.get("pain_fired", false)):
		if needs_head(target):
			lines.append_array(CombatApplicator.slay(merc, target, state, "  %s splits the skull of %s!"))
		else:
			lines.append("  %s survives without a head!" % BattleState.colored_name(target, state))
	return lines


#The trait name in parentheses ("Atlas Vertebra"), else the trailing trait name.
static func _perk_label(perk: TraitData) -> String:
	if perk == null:
		return ""
	var name := WeaponArmorPerkLibrary.perk_display_name(perk)
	var open := name.find("(")
	var close := name.rfind(")")
	if open >= 0 and close > open + 1:
		return name.substr(open + 1, close - open - 1)
	return name


static func _perk_flags(info: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var parts: PackedStringArray = info.get("parts", PackedStringArray())
	var start := int(info.get("effect_start", 2)) + 2
	for i: int in range(start, parts.size()):
		out.append(parts[i])
	return out
