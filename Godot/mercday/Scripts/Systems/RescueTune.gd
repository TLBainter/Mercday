class_name RescueTune extends RefCounted

#The rescue tunables table with its setter, its reset and its text for the head lines.


const TUNE_DEFAULTS: Dictionary = {
	"need_full_odds": 0.5,
	"need_zero_odds": 1.25,
	"cost_rounds": 10.0,
	"danger_per_enemy": 0.25,
	"share_cut": 0.5,
	"go_margin": 0.0,
	"stealth_margin": 0.0,
	"ambush_odds": 1.0,
}


static var tune: Dictionary = TUNE_DEFAULTS.duplicate()


static func tuned(name: String) -> float:
	return float(tune.get(name, TUNE_DEFAULTS.get(name, 0.0)))


#Sets one named tunable; false for a name the table does not hold.
static func set_tune(name: String, value: float) -> bool:
	if not TUNE_DEFAULTS.has(name):
		return false
	tune[name] = value
	return true


static func reset_tune() -> void:
	tune = TUNE_DEFAULTS.duplicate()


#Tunables that differ from their defaults, for probe and log head lines.
static func tune_text() -> String:
	var parts: Array[String] = []
	for key: Variant in TUNE_DEFAULTS.keys():
		var name: String = str(key)
		if not is_equal_approx(tuned(name), float(TUNE_DEFAULTS[name])):
			parts.append("%s %s" % [name, str(tuned(name))])
	return "default" if parts.is_empty() else ", ".join(parts)
