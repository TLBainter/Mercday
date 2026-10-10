class_name PoolTests
#Contract pool, provision priority, story stub and promo rolls; joined to the board suite.

const NOW: int = 480


static func add_cases(res: Dictionary) -> void:
	_case_reject_bonus(res)
	_case_return_rejected(res)
	_case_sweep(res)
	_case_pooled_status(res)
	_case_sort_keys(res)
	_case_sort_combined(res)
	_case_niche(res)
	_case_story_stub(res)
	_case_promo_chance(res)
	_case_promo_rate(res)
	_case_promo_criteria(res)
	_case_promo_chain(res)


static func _entry(value: int) -> BoardEntry:
	var entry := BoardEntry.new()
	entry.contract = ContractData.new()
	entry.contract.reward_notes = value
	entry.value = value
	entry.distance_km = 10
	entry.completion_hours = 8
	entry.merc_min = 1
	return entry


static func _no_tele(_entry_in: BoardEntry) -> bool:
	return false


static func _case_reject_bonus(res: Dictionary) -> void:
	var faces: Array[int] = [0, 1, -1, 2, -3, 5]
	var want: Array[float] = [0.0, 0.0, 0.0, 0.225, 0.45, 0.9]
	var got: Array[float] = []
	var ok: bool = true
	for i: int in faces.size():
		got.append(ContractPool.reject_bonus(faces[i]))
		ok = ok and is_equal_approx(got[i], want[i])
	TestFixtures.check(res, "pool:reject_bonus_faces", ok, "got %s" % str(got))


static func _case_return_rejected(res: Dictionary) -> void:
	var pool := ContractPool.new()
	var posting: BoardEntry = _entry(100)
	posting.id = 7
	posting.status = BoardEntry.STATUS_REJECTED
	posting.reach_warned = true
	posting.campaign_id = 3
	posting.issuer_id = 11
	posting.deadline_minute = 9000
	var back: BoardEntry = pool.return_rejected(posting, 3, NOW)
	TestFixtures.check(res, "pool:reject_value_145", back.value == 145 and back.contract.reward_notes == 145,
		"value %d notes %d" % [back.value, back.contract.reward_notes])
	TestFixtures.check(res, "pool:reject_fields", back.reject_count == 1 and back.id == 0 and not back.reach_warned
		and back.campaign_id == 3 and back.issuer_id == 11 and back.deadline_minute == 9000,
		"count %d id %d warned %s" % [back.reject_count, back.id, back.reach_warned])
	TestFixtures.check(res, "pool:reject_own_contract", back.contract != posting.contract,
		"same object %s" % str(back.contract == posting.contract))
	TestFixtures.check(res, "pool:reject_pooled", pool.entries.has(back)
		and back.status == BoardEntry.STATUS_POOLED and back.pooled_minute == NOW,
		"status %s minute %d" % [back.status, back.pooled_minute])
	TestFixtures.check(res, "pool:reject_source_unchanged", posting.value == 100
		and posting.contract.reward_notes == 100 and posting.reject_count == 0 and posting.id == 7,
		"value %d notes %d count %d" % [posting.value, posting.contract.reward_notes, posting.reject_count])


static func _case_sweep(res: Dictionary) -> void:
	var pool := ContractPool.new()
	var late: BoardEntry = _entry(50)
	late.deadline_minute = NOW + 60
	var story: BoardEntry = _entry(50)
	story.deadline_minute = NOW + 60
	story.story = true
	var open: BoardEntry = _entry(50)
	pool.add(late, NOW)
	pool.add(story, NOW)
	pool.add(open, NOW)
	var gone: Array[BoardEntry] = pool.sweep(NOW, 0, _no_tele)
	TestFixtures.check(res, "pool:sweep_drops_late", gone.size() == 1 and gone[0] == late
		and not pool.entries.has(late), "gone %d" % gone.size())
	TestFixtures.check(res, "pool:sweep_keeps_story", pool.entries.has(story) and pool.entries.has(open),
		"left %d" % pool.entries.size())


static func _case_pooled_status(res: Dictionary) -> void:
	var pool := ContractPool.new()
	var entry: BoardEntry = _entry(10)
	entry.issuer_id = 4
	pool.add(entry, NOW)
	TestFixtures.check(res, "pool:pooled_not_open_active", not entry.is_open() and not entry.is_active()
		and entry.status == BoardEntry.STATUS_POOLED, "status %s" % entry.status)
	TestFixtures.check(res, "pool:issuer_ids_types", pool.issuer_ids() == [4] and pool.types().size() == 1,
		"ids %s" % str(pool.issuer_ids()))
	pool.remove(entry)
	TestFixtures.check(res, "pool:remove", pool.entries.is_empty(), "left %d" % pool.entries.size())


static func _order(entries: Array[BoardEntry], slack: Dictionary, niche: Dictionary) -> Array[int]:
	var sorted: Array[BoardEntry] = GenPriority.sort(entries, NOW,
		func(e: BoardEntry) -> int: return int(slack.get(e, 100000)),
		func(e: BoardEntry) -> float: return float(niche.get(e, 1.0)))
	var out: Array[int] = []
	for entry: BoardEntry in sorted:
		out.append(entries.find(entry))
	return out


static func _pair() -> Array[BoardEntry]:
	var out: Array[BoardEntry] = [_entry(10), _entry(10)]
	return out


static func _case_sort_keys(res: Dictionary) -> void:
	var none: Dictionary = {}
	var e: Array[BoardEntry] = _pair()
	e[0].quality = 0.9
	e[1].story = true
	TestFixtures.check(res, "pool:sort_story_first", _order(e, none, none) == [1, 0], str(_order(e, none, none)))
	e = _pair()
	e[0].campaign_id = 1
	e[0].match_pct = 0.5
	e[1].campaign_id = 2
	e[1].match_pct = 1.0
	TestFixtures.check(res, "pool:sort_match_higher", _order(e, none, none) == [1, 0], str(_order(e, none, none)))
	e = _pair()
	e[0].campaign_id = 1
	e[1].campaign_id = 2
	var niche: Dictionary = {e[0]: 40.0, e[1]: 4.0}
	TestFixtures.check(res, "pool:sort_niche_tie", _order(e, none, niche) == [1, 0], str(_order(e, none, niche)))
	e = _pair()
	e[0].quality = 0.9
	e[1].campaign_id = 5
	TestFixtures.check(res, "pool:sort_campaign_before_plain", _order(e, none, none) == [1, 0],
		str(_order(e, none, none)))
	var three: Array[BoardEntry] = [_entry(10), _entry(10), _entry(10)]
	var slack: Dictionary = {three[0]: 60 * 60, three[1]: 30 * 60, three[2]: 10 * 60}
	TestFixtures.check(res, "pool:sort_urgency", _order(three, slack, none) == [2, 1, 0],
		str(_order(three, slack, none)))
	e = _pair()
	e[0].quality = 0.2
	e[1].quality = 0.7
	TestFixtures.check(res, "pool:sort_quality", _order(e, none, none) == [1, 0], str(_order(e, none, none)))
	e = _pair()
	e[0].pooled_minute = 900
	e[1].pooled_minute = 100
	TestFixtures.check(res, "pool:sort_older_first", _order(e, none, none) == [1, 0], str(_order(e, none, none)))
	var same: Array[BoardEntry] = [_entry(10), _entry(10), _entry(10), _entry(10)]
	TestFixtures.check(res, "pool:sort_stable", _order(same, none, none) == [0, 1, 2, 3],
		str(_order(same, none, none)))


static func _case_sort_combined(res: Dictionary) -> void:
	var e: Array[BoardEntry] = [_entry(10), _entry(10), _entry(10), _entry(10), _entry(10)]
	e[0].quality = 1.0
	e[1].campaign_id = 1
	e[1].match_pct = 0.5
	e[2].story = true
	e[2].quality = 0.0
	e[3].campaign_id = 2
	e[3].match_pct = 1.0
	e[4].quality = 0.5
	var slack: Dictionary = {e[4]: 5 * 60}
	var got: Array[int] = _order(e, slack, {})
	TestFixtures.check(res, "pool:sort_combined", got == [2, 3, 1, 4, 0], str(got))


static func _case_niche(res: Dictionary) -> void:
	var full: float = GenPriority.niche({})
	var types: int = ContractLibrary.contract_type_names().size()
	var want_full: float = float(types * GenConstants.DISTANCE_KM.size()) * (GenConstants.DIFF_MAX - GenConstants.DIFF_MIN)
	var narrow: float = GenPriority.niche({"types": ["A"], "places": ["Buern", "Zukei"], "diff_lo": 1.0, "diff_hi": 2.0})
	TestFixtures.check(res, "pool:niche_full_set", is_equal_approx(full, want_full), "full %.2f want %.2f" % [full, want_full])
	TestFixtures.check(res, "pool:niche_product", is_equal_approx(narrow, 2.0), "narrow %.2f" % narrow)


static func _case_story_stub(res: Dictionary) -> void:
	TestFixtures.check(res, "pool:story_stub_empty", GenStory.due(NOW).is_empty(), "stub")


static func _case_promo_chance(res: Dictionary) -> void:
	TestFixtures.check(res, "pool:promo_chance_effect", is_equal_approx(GenPromo.chance_of(12.0), 0.12)
		and is_equal_approx(GenPromo.chance({"effect": 9.0}), 0.09), "%.3f" % GenPromo.chance_of(12.0))
	TestFixtures.check(res, "pool:promo_chance_cap", is_equal_approx(GenPromo.chance_of(400.0), 0.95),
		"%.3f" % GenPromo.chance_of(400.0))


static func _case_promo_rate(res: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 546
	var none: Array[String] = []
	var hit: int = 0
	for i: int in 1000:
		if not GenPromo.roll(12.0, none, rng).is_empty():
			hit += 1
	TestFixtures.check(res, "pool:promo_first_hit_rate", hit >= 90 and hit <= 150, "%d of 1000" % hit)


static func _case_promo_criteria(res: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var none: Array[String] = []
	var one: Array[String] = ["places"]
	var zero_ok: bool = true
	var one_ok: bool = true
	var seen: int = 0
	for i: int in 50:
		for h: Dictionary in GenPromo.roll(95.0, none, rng):
			seen += 1
			zero_ok = zero_ok and float(h["match_pct"]) == 0.0 and (h["criteria"] as Array).is_empty()
		for h: Dictionary in GenPromo.roll(95.0, one, rng):
			one_ok = one_ok and float(h["match_pct"]) == 1.0 and (h["criteria"] as Array) == ["places"]
	TestFixtures.check(res, "pool:promo_no_active_zero", zero_ok and seen > 0, "hits %d" % seen)
	TestFixtures.check(res, "pool:promo_one_active_full", one_ok, "one active")
	var campaign: Dictionary = {"id": 9, "effect": 95.0, "types": ["Escort"], "places": [], "diff_lo": 1.0,
		"diff_hi": 3.0, "issuers": [2]}
	var keys: Array[String] = GenPromo.active(campaign)
	var hits: Array[Dictionary] = GenPromo.hits(campaign, rng)
	var tagged: bool = not hits.is_empty()
	for h: Dictionary in hits:
		var crit: Array = h["criteria"] as Array
		tagged = tagged and int(h.get("campaign_id", 0)) == 9 and crit.size() >= 1
		tagged = tagged and is_equal_approx(float(h["match_pct"]), float(crit.size()) / 3.0)
	TestFixtures.check(res, "pool:promo_active_keys", keys == ["types", "difficulty", "issuers"], str(keys))
	TestFixtures.check(res, "pool:promo_hits_tagged", tagged, "hits %d" % hits.size())


static func _case_promo_chain(res: Dictionary) -> void:
	var none: Array[String] = []
	var ok: bool = true
	var longest: int = 0
	for s: int in 200:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + s
		var count: int = GenPromo.roll(95.0, none, rng).size()
		longest = maxi(longest, count)
		var twin := RandomNumberGenerator.new()
		twin.seed = 1000 + s
		for k: int in count + 1:
			twin.randf()
		ok = ok and twin.state == rng.state
	TestFixtures.check(res, "pool:promo_chain_stops_at_miss", ok and longest > 1, "longest %d" % longest)
