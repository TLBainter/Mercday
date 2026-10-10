class_name GenTune
#Per-run overrides of the GenConstants numbers (--gen-set): parse, apply, report and reset.

const CONSTANTS: GDScript = preload("res://Scripts/Contracts/Generation/GenConstants.gd")
const TUNABLE_KEYS: Array[String] = [
	"LIKELY_BASE", "LIKELY_SLOPE", "LIKELY_MIN", "LIKELY_MAX", "CHAIN_DECAY", "STORY_INTERVAL_DAYS",
	"PROMO_CHANCE_SCALE", "PROMO_CHAIN_DECAY", "PROMO_CHANCE_CAP", "ISSUER_MIN_WEIGHT", "ISSUER_GROUP_BASE",
	"LEVEL_W_ALL", "LEVEL_W_AVAILABLE", "LEVEL_W_RESTING", "LEVEL_LO", "LEVEL_HI", "LEVEL_CAP",
	"DIFF_CENTRE", "DIFF_SLOPE", "DIFF_MIN", "DIFF_MAX", "DIFF_SNAP",
	"MATCH_BASE", "MATCH_SLOPE", "MATCH_MIN", "MATCH_MAX", "TYPE_REPEAT_FACTOR", "BALANCE_SHARE",
	"LONG_HOURS", "NEAR_KM", "FAR_KM", "DISTANCE_JITTER", "TRAVEL_ADD_LO", "TRAVEL_ADD_HI",
	"QUALITY_W_NEAR", "QUALITY_W_SHORT", "QUALITY_W_GENEROUS", "QUALITY_W_MATCH", "QUALITY_KM_SPAN",
	"QUALITY_HOURS_SPAN", "QUALITY_MATCH_FULL", "PROMO_QUALITY_LIFT",
	"CSAT_POINTS", "TIME_POINTS_PER_8H", "URGENCY_POINTS", "EXPENSE_WEIGHT", "VALUE_MEAN_FACE",
	"VALUE_MEAN_DIFFICULTY", "VALUE_MEAN_HOURS", "VALUE_MEAN_URGENCY", "VALUE_MEAN_KM", "VALUE_MEAN_TEAM",
	"QUALITY_MULT_LO", "QUALITY_MULT_HI", "VALUE_TRIM",
	"REJECT_VALUE_STEP", "SLACK_LO", "SLACK_HI", "SLACK_OPINION_H", "DEADLINE_MIN_H", "URGENT_H", "SOON_H",
]

static var _defaults: Dictionary = {}


static func keys() -> Array[String]:
	return TUNABLE_KEYS.duplicate()


#NAN for a key that is not tunable.
static func value(key: String) -> float:
	return float(CONSTANTS.get(key)) if TUNABLE_KEYS.has(key) else NAN


#False for an unknown key or a fraction on an int key.
static func set_value(key: String, new_value: float) -> bool:
	if not TUNABLE_KEYS.has(key) or (_is_int(key) and new_value != floorf(new_value)):
		return false
	_snapshot()
	CONSTANTS.set(key, int(new_value) if _is_int(key) else new_value)
	return true


#"KEY:VALUE,KEY:VALUE"; every pair is checked before any is applied, so one bad pair applies nothing.
static func apply_spec(spec: String) -> Array[String]:
	var errors: Array[String] = []
	var pairs: Array[Array] = []
	for part: String in spec.split(",", false):
		var bits: PackedStringArray = part.split(":")
		var key: String = bits[0].strip_edges()
		var text: String = bits[1].strip_edges() if bits.size() == 2 else ""
		if not TUNABLE_KEYS.has(key):
			errors.append("GEN SET: unknown key %s" % key)
		elif not text.is_valid_float() or (_is_int(key) and text.to_float() != floorf(text.to_float())):
			errors.append("GEN SET: bad value for %s" % key)
		else:
			pairs.append([key, text.to_float()])
	if errors.is_empty():
		for pair: Array in pairs:
			set_value(pair[0], pair[1])
	return errors


static func reset() -> void:
	_snapshot()
	for key: String in TUNABLE_KEYS:
		CONSTANTS.set(key, _defaults[key])


static func report_lines() -> Array[String]:
	_snapshot()
	var out: Array[String] = []
	for key: String in TUNABLE_KEYS:
		if CONSTANTS.get(key) != _defaults[key]:
			out.append("GEN SET: %s %s -> %s" % [key, str(_defaults[key]), str(CONSTANTS.get(key))])
	return out


static func _is_int(key: String) -> bool:
	return typeof(CONSTANTS.get(key)) == TYPE_INT


static func _snapshot() -> void:
	if _defaults.is_empty():
		for key: String in TUNABLE_KEYS:
			_defaults[key] = CONSTANTS.get(key)
