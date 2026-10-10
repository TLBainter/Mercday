class_name GenTuneTests
#GenTune checks and the seeded chance pins of stage G (daily roll count, promo decay chain); run from GenTests.

const TRIALS: int = 1000
const COUNT_TOLERANCE: float = 0.08
const PROMO_SEED: int = 7
const PROMO_CAMPAIGN: Dictionary = {
	"id": 9, "effect": 90.0, "types": ["Escort"], "places": ["Buern"], "issuers": ["Guild Hall"],
}
const PROMO_PINNED: Array[String] = ["types+places+issuers", "types+places+issuers", "places+issuers"]


static func run(res: Dictionary) -> void:
	var before: Dictionary = {}
	for key: String in GenTune.keys():
		before[key] = GenTune.value(key)
	GenTune.reset()
	_case_keys(res)
	_case_unknown_key(res)
	_case_parse(res)
	_case_int_fraction(res)
	_case_atomic(res)
	_case_report_reset(res)
	_case_step_reads(res)
	_case_roll_count(res)
	_case_promo_chain(res)
	_case_promo_tuned(res)
	GenTune.reset()
	for key: String in before:
		GenTune.set_value(key, before[key])


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func _case_keys(res: Dictionary) -> void:
	var keys: Array[String] = GenTune.keys()
	var ok: bool = keys.size() == 62 and keys.has("LIKELY_BASE") and keys.has("LEVEL_CAP") \
		and not keys.has("DISTANCE_KM") and not keys.has("VALUE_ANCHORS")
	TestFixtures.check(res, "gen tune: 62 tunable keys, tables stay const", ok, "%d keys" % keys.size())


static func _case_unknown_key(res: Dictionary) -> void:
	var errors: Array[String] = GenTune.apply_spec("NOPE:1")
	var ok: bool = not GenTune.set_value("NOPE", 1.0) and not GenTune.set_value("GUILD_HOME", 1.0) \
		and errors == ["GEN SET: unknown key NOPE"] and is_nan(GenTune.value("NOPE"))
	TestFixtures.check(res, "gen tune: unknown key refused", ok, str(errors))


static func _case_parse(res: Dictionary) -> void:
	var errors: Array[String] = GenTune.apply_spec(" LIKELY_BASE : 0.9 , LEVEL_CAP:30")
	var ok: bool = errors.is_empty() and is_equal_approx(GenConstants.LIKELY_BASE, 0.9) \
		and GenConstants.LEVEL_CAP == 30 and typeof(GenConstants.LEVEL_CAP) == TYPE_INT
	TestFixtures.check(res, "gen tune: float and int values parse and apply", ok,
		"errors %s base %s cap %s" % [str(errors), str(GenConstants.LIKELY_BASE), str(GenConstants.LEVEL_CAP)])
	GenTune.reset()


static func _case_int_fraction(res: Dictionary) -> void:
	var errors: Array[String] = GenTune.apply_spec("LEVEL_CAP:30.5")
	errors.append_array(GenTune.apply_spec("LIKELY_BASE:abc"))
	var ok: bool = not GenTune.set_value("LEVEL_CAP", 30.5) and GenConstants.LEVEL_CAP == 40 \
		and is_equal_approx(GenConstants.LIKELY_BASE, 0.60) \
		and errors == ["GEN SET: bad value for LEVEL_CAP", "GEN SET: bad value for LIKELY_BASE"]
	TestFixtures.check(res, "gen tune: fraction on an int key and a non-number refused", ok, str(errors))


static func _case_atomic(res: Dictionary) -> void:
	var errors: Array[String] = GenTune.apply_spec("LIKELY_BASE:0.9,NOPE:2,LEVEL_CAP:30")
	var ok: bool = errors.size() == 1 and is_equal_approx(GenConstants.LIKELY_BASE, 0.60) \
		and GenConstants.LEVEL_CAP == 40 and GenTune.report_lines().is_empty()
	TestFixtures.check(res, "gen tune: one bad pair applies nothing", ok,
		"errors %s base %s cap %d" % [str(errors), str(GenConstants.LIKELY_BASE), GenConstants.LEVEL_CAP])


static func _case_report_reset(res: Dictionary) -> void:
	GenTune.set_value("LIKELY_BASE", 0.9)
	var lines: Array[String] = GenTune.report_lines()
	GenTune.reset()
	var ok: bool = lines == ["GEN SET: LIKELY_BASE 0.6 -> 0.9"] \
		and is_equal_approx(GenConstants.LIKELY_BASE, 0.60) and GenTune.report_lines().is_empty()
	TestFixtures.check(res, "gen tune: report names the tuned key, reset restores the default", ok, str(lines))


#The loop of GenLikelihood.count with an explicit chance.
static func _mirror_count(seed_value: int, p: float) -> int:
	var rng: RandomNumberGenerator = _rng(seed_value)
	var hits: int = 0
	while rng.randf() < p * pow(GenConstants.CHAIN_DECAY, hits):
		hits += 1
	return hits


static func _case_step_reads(res: Dictionary) -> void:
	GenTune.set_value("LIKELY_BASE", 0.9)
	var chance: float = GenLikelihood.chance(0.5)
	var same: int = 0
	var differs: int = 0
	for s: int in range(1, 51):
		var got: int = GenLikelihood.count(0.5, _rng(s))
		same += 1 if got == _mirror_count(s, 0.9) else 0
		differs += 1 if got != _mirror_count(s, 0.6) else 0
	GenTune.reset()
	var ok: bool = is_equal_approx(chance, 0.9) and same == 50 and differs > 0
	TestFixtures.check(res, "gen tune: GenLikelihood.count reads LIKELY_BASE 0.90 (seeds 1..50 match the mirror)", ok,
		"chance %.2f, %d/50 match p 0.90, %d differ from p 0.60" % [chance, same, differs])


#E[count] = sum over k >= 1 of p^k x decay^(k(k-1)/2).
static func _expected_count(p: float, decay: float) -> float:
	var total: float = 0.0
	var term: float = 1.0
	for k: int in range(1, 30):
		term *= p * pow(decay, k - 1)
		total += term
	return total


static func _case_roll_count(res: Dictionary) -> void:
	var expected: float = _expected_count(GenLikelihood.chance(0.5), GenConstants.CHAIN_DECAY)
	var total: int = 0
	for s: int in range(1, TRIALS + 1):
		total += GenLikelihood.count(0.5, _rng(s))
	var mean: float = float(total) / float(TRIALS)
	var ok: bool = absf(mean - expected) <= COUNT_TOLERANCE and is_equal_approx(snappedf(expected, 0.001), 0.809)
	TestFixtures.check(res, "gen seeded: roll count at blended 0.5, seeds 1..1000, mean within 0.08 of 0.809", ok,
		"mean %.3f expected %.4f" % [mean, expected])


#The draw order of GenPromo.roll and _hit, one string of applied criteria per hit.
static func _mirror_promo(seed_value: int, decay: float) -> Array[String]:
	var rng: RandomNumberGenerator = _rng(seed_value)
	var active: Array[String] = ["types", "places", "issuers"]
	var p: float = minf(GenConstants.PROMO_CHANCE_CAP, float(PROMO_CAMPAIGN["effect"]) / 100.0)
	var chance: float = p
	var out: Array[String] = []
	while rng.randf() < chance:
		var pick: int = rng.randi_range(0, active.size() - 1)
		var applied: Array[String] = []
		for i: int in active.size():
			if i == pick or rng.randf() < p:
				applied.append(active[i])
		out.append("+".join(applied))
		chance *= decay
	return out


static func _promo_seq() -> Array[String]:
	var out: Array[String] = []
	for hit: Dictionary in GenPromo.hits(PROMO_CAMPAIGN, _rng(PROMO_SEED)):
		var criteria: Array[String] = []
		criteria.assign(hit["criteria"])
		out.append("+".join(criteria) if int(hit["campaign_id"]) == 9 else "bad id")
	return out


static func _case_promo_chain(res: Dictionary) -> void:
	var seq: Array[String] = _promo_seq()
	var ok: bool = seq == PROMO_PINNED and seq == _mirror_promo(PROMO_SEED, 0.75)
	TestFixtures.check(res, "gen seeded: promo decay chain on seed 7 equals the pinned sequence", ok, str(seq))


static func _case_promo_tuned(res: Dictionary) -> void:
	GenTune.set_value("PROMO_CHAIN_DECAY", 1.0)
	var tuned: Array[String] = _promo_seq()
	GenTune.reset()
	var restored: Array[String] = _promo_seq()
	var ok: bool = tuned == _mirror_promo(PROMO_SEED, 1.0) and tuned.size() > PROMO_PINNED.size() \
		and tuned.slice(0, PROMO_PINNED.size()) == PROMO_PINNED
	TestFixtures.check(res, "gen seeded: PROMO_CHAIN_DECAY 1.0 extends the seed 7 chain as the mirror predicts", ok,
		"%s vs pinned %s" % [str(tuned), str(PROMO_PINNED)])
	TestFixtures.check(res, "gen seeded: reset restores the seed 7 promo chain", restored == PROMO_PINNED,
		str(restored))
