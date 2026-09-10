class_name RestTests

#Breather, Respite and Furlough behaviour. Run: godot --headless --path . -- --rest-tests
#Every case resets the campaign clock first, so the suite is order independent.


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_breather(res)
	_case_cap(res)
	_case_respite(res)
	_case_respite_excess(res)
	_case_respite_expiry(res)
	_case_clear_by_verb(res)
	_case_furlough(res)
	_case_triggers(res)
	_case_contract_end(res)
	_case_sources(res)
	_case_rest_sources(res)
	_case_apply_until(res)
	_case_snapshot(res)
	CampaignClock.reset()
	TraitRuntime.clear_all()
	return TestFixtures.summarize(res, "REST")


#Helpers

#A merc carrying only the stats a rest reads, so every cap is exact instead of formula derived.
static func _merc(name: String, hp: int, ep: int, mp: int, recovery: float) -> MercenaryData:
	var m := MercenaryData.new()
	m.merc_name = name
	m.stats = {"maximum_hit_points": hp, "maximum_endurance_points": ep,
		"maximum_magic_points": mp, "rest_recovery": recovery}
	m.current_hp = hp
	m.current_ep = ep
	m.current_mp = mp
	return m


static func _trait(name: String, dsl: String) -> TraitData:
	var td := TraitData.new()
	td.trait_name = name
	td.trait_type = "Perk"
	td.trait_source = "Merc"
	td.effect_dsl = dsl
	return td


static func _has(lines: Array[String], text: String) -> bool:
	for line: String in lines:
		if line.contains(text):
			return true
	return false


#One recorded source of the state; an empty dictionary when that tier is missing.
static func _src(merc: MercenaryData, state_name: String, index: int) -> Dictionary:
	var list: Array[Dictionary] = ConstStates.state_sources(merc, state_name)
	if index < 0 or index >= list.size():
		return {}
	return list[index]


static func _join(list: Array) -> String:
	var out: PackedStringArray = PackedStringArray()
	for value: Variant in list:
		out.append(str(value))
	return ",".join(out)


static func _verbs(src: Dictionary) -> String:
	return _join(src.get("removal", []))


static func _src_text(src: Dictionary) -> String:
	return "%s=%s removal=[%s]" % [str(src.get("kind", "")), str(src.get("name", "")), _verbs(src)]


#A whole furlough for one merc: start it, wait out the ten days, complete it.
static func _furlough(merc: MercenaryData) -> Array[String]:
	RestSystem.furlough_start(merc)
	CampaignClock.advance(RestSystem.FURLOUGH_MINUTES)
	return RestSystem.furlough_complete(merc)


static func _respite(merc: MercenaryData) -> Array[String]:
	var party: Array[MercenaryData] = [merc]
	return RestSystem.respite(party, null, false)


static func _case_breather(res: Dictionary) -> void:
	CampaignClock.reset()
	var low := _merc("Bree", 10, 8, 0, 1.0)
	low.current_ep = 3
	low.current_hp = 4
	var lines: Array[String] = RestSystem.breather(low, null)
	TestFixtures.check(res, "breather tops EP to the cap", low.current_ep == 4,
		"expected 4, got %d" % low.current_ep)
	TestFixtures.check(res, "breather leaves HP alone", low.current_hp == 4,
		"expected 4, got %d" % low.current_hp)
	TestFixtures.check(res, "breather line names the change",
		_has(lines, "BREATHER: Bree EP 3 -> 4, MP 0 -> 0 (cap 50%)"), "lines %s" % str(lines))
	var above := _merc("Ova", 10, 8, 0, 1.0)
	above.current_ep = 5
	RestSystem.breather(above, null)
	TestFixtures.check(res, "breather never lowers a pool", above.current_ep == 5,
		"expected 5, got %d" % above.current_ep)
	var near_full := _merc("Fenn", 10, 8, 0, 1.0)
	near_full.current_ep = 7
	var skipped: Array[String] = RestSystem.breather(near_full, null)
	TestFixtures.check(res, "breather skipped inside the deficit bar",
		near_full.current_ep == 7 and _has(skipped, "BREATHER SKIPPED: Fenn (EP 7/8, MP 0/0)"),
		"ep %d lines %s" % [near_full.current_ep, str(skipped)])
	var dead := _merc("Gone", 10, 8, 0, 1.0)
	dead.current_ep = 0
	dead.is_dead = true
	TestFixtures.check(res, "breather ignores the dead", RestSystem.breather(dead, null).is_empty(),
		"expected no lines for a corpse")
	var party: Array[MercenaryData] = [low, near_full]
	var party_lines: Array[String] = RestSystem.breather_party(party, 0.0, null)
	TestFixtures.check(res, "breather_party covers every merc", party_lines.size() == 2,
		"expected 2 lines, got %d" % party_lines.size())


static func _case_cap(res: Dictionary) -> void:
	CampaignClock.reset()
	var half := _merc("Halle", 10, 8, 0, 0.5)
	half.current_ep = 0
	TestFixtures.check(res, "rest_recovery 0.5 halves the cap",
		is_equal_approx(RestSystem.cap_fraction(half, RestSystem.PARTIAL_CAP), 0.25),
		"expected 0.25, got %s" % str(RestSystem.cap_fraction(half, RestSystem.PARTIAL_CAP)))
	RestSystem.breather(half, null)
	TestFixtures.check(res, "a quarter cap tops 8 EP to 2", half.current_ep == 2,
		"expected 2, got %d" % half.current_ep)
	var big := _merc("Boone", 10, 8, 0, 3.0)
	big.current_ep = 0
	TestFixtures.check(res, "rest_recovery 3.0 clamps the cap at 100%",
		is_equal_approx(RestSystem.cap_fraction(big, RestSystem.PARTIAL_CAP), 1.0),
		"expected 1.0, got %s" % str(RestSystem.cap_fraction(big, RestSystem.PARTIAL_CAP)))
	RestSystem.breather(big, null)
	TestFixtures.check(res, "a full cap fills the EP pool", big.current_ep == 8,
		"expected 8, got %d" % big.current_ep)
	var bare := _merc("Bara", 10, 8, 0, 1.0)
	bare.stats.erase("rest_recovery")
	bare.current_ep = 0
	TestFixtures.check(res, "a missing rest_recovery reads 1.0",
		is_equal_approx(RestSystem.rest_recovery(bare), 1.0),
		"expected 1.0, got %s" % str(RestSystem.rest_recovery(bare)))
	RestSystem.breather(bare, null)
	TestFixtures.check(res, "the plain cap tops 8 EP to 4", bare.current_ep == 4,
		"expected 4, got %d" % bare.current_ep)
	var zero := _merc("Zeno", 10, 8, 0, 0.0)
	TestFixtures.check(res, "a non-positive rest_recovery reads 1.0",
		is_equal_approx(RestSystem.rest_recovery(zero), 1.0),
		"expected 1.0, got %s" % str(RestSystem.rest_recovery(zero)))


static func _case_respite(res: Dictionary) -> void:
	CampaignClock.reset()
	var m := _merc("Cara", 10, 8, 4, 1.0)
	m.current_hp = 1
	m.current_ep = 0
	m.current_mp = 0
	ConstStates.apply_state(m, ConstStates.FATIGUED)
	ConstStates.apply_state(m, ConstStates.FATIGUED)
	var party: Array[MercenaryData] = [m]
	var lines: Array[String] = RestSystem.respite(party, null, true)
	TestFixtures.check(res, "respite tops HP to the partial cap", m.current_hp == 5,
		"expected 5, got %d" % m.current_hp)
	TestFixtures.check(res, "respite fills EP and MP", m.current_ep == 8 and m.current_mp == 4,
		"expected 8 and 4, got %d and %d" % [m.current_ep, m.current_mp])
	TestFixtures.check(res, "respite drops one Fatigued tier",
		ConstStates.get_count(m, ConstStates.FATIGUED) == 1 and _has(lines, "Fatigued 2 -> 1"),
		"tier %d lines %s" % [ConstStates.get_count(m, ConstStates.FATIGUED), str(lines)])
	TestFixtures.check(res, "respite stamps the lockout",
		m.rest_lockout_until == RestSystem.RESPITE_MINUTES and m.rest_lockout_kind == "respite"
		and _has(lines, "RESPITE LOCKOUT: Cara until D1 06:00"),
		"until %d kind %s" % [m.rest_lockout_until, m.rest_lockout_kind])
	TestFixtures.check(res, "a locked out merc is undeployable", not RestSystem.is_deployable(m),
		"is_deployable true at minute %d" % CampaignClock.now())
	CampaignClock.advance(RestSystem.RESPITE_MINUTES)
	TestFixtures.check(res, "the lockout ends on the clock", RestSystem.is_deployable(m),
		"is_deployable false at minute %d" % CampaignClock.now())
	var whole := _merc("Ilse", 10, 8, 0, 1.0)
	var full_party: Array[MercenaryData] = [whole]
	TestFixtures.check(res, "party_lost_hp is false at full HP", not RestSystem.party_lost_hp(full_party),
		"expected false at %d/%d" % [whole.current_hp, 10])
	whole.current_hp = 9
	TestFixtures.check(res, "party_lost_hp sees one wound", RestSystem.party_lost_hp(full_party),
		"expected true at %d/%d" % [whole.current_hp, 10])


static func _case_respite_excess(res: Dictionary) -> void:
	CampaignClock.reset()
	var m := _merc("Dax", 10, 8, 0, 1.0)
	m.current_hp = 1
	m.excess_hp = 2
	m.excess_ep = 1
	var party: Array[MercenaryData] = [m]
	RestSystem.respite(party, null, false)
	TestFixtures.check(res, "respite never clears excess", m.excess_hp == 2 and m.excess_ep == 1,
		"expected 2 and 1, got %d and %d" % [m.excess_hp, m.excess_ep])
	TestFixtures.check(res, "respite without lockout leaves the merc free",
		m.rest_lockout_until == 0 and RestSystem.is_deployable(m),
		"until %d" % m.rest_lockout_until)


static func _case_respite_expiry(res: Dictionary) -> void:
	CampaignClock.reset()
	var m := _merc("Dree", 10, 8, 0, 1.0)
	ConstStates.apply_state(m, ConstStates.DRENCHED)
	m.campaign_states[ConstStates.DRENCHED] = CampaignClock.now() + CampaignClock.MINUTES_PER_HOUR
	var party: Array[MercenaryData] = [m]
	var lines: Array[String] = RestSystem.respite(party, null, false)
	TestFixtures.check(res, "an hour timer expires across the respite",
		not ConstStates.has_state(m, ConstStates.DRENCHED) and _has(lines, "Dree dried up."),
		"held %s lines %s" % [str(ConstStates.has_state(m, ConstStates.DRENCHED)), str(lines)])
	TestFixtures.check(res, "the expired timer is erased",
		not m.campaign_states.has(ConstStates.DRENCHED), "timers %s" % str(m.campaign_states))


static func _case_clear_by_verb(res: Dictionary) -> void:
	CampaignClock.reset()
	var m := _merc("Hex", 10, 8, 0, 1.0)
	ConstStates.apply_state(m, "Heat Exhaustion")
	var lines: Array[String] = RestSystem.clear_by_verb(m, "respite")
	TestFixtures.check(res, "the respite verb clears Heat Exhaustion",
		not ConstStates.has_state(m, "Heat Exhaustion") and _has(lines, "Hex has cooled down."),
		"held %s lines %s" % [str(ConstStates.has_state(m, "Heat Exhaustion")), str(lines)])
	var keeper := _merc("Kip", 10, 8, 0, 1.0)
	ConstStates.apply_state(keeper, ConstStates.FATIGUED)
	ConstStates.apply_state(keeper, "Heat Exhaustion")
	var skip: Array[String] = [ConstStates.FATIGUED]
	RestSystem.clear_by_verb(keeper, "respite", skip)
	TestFixtures.check(res, "the skip list keeps the tiered state",
		ConstStates.has_state(keeper, ConstStates.FATIGUED)
		and not ConstStates.has_state(keeper, "Heat Exhaustion"),
		"fatigued %d" % ConstStates.get_count(keeper, ConstStates.FATIGUED))


static func _case_furlough(res: Dictionary) -> void:
	CampaignClock.reset()
	var m := _merc("Fira", 12, 8, 0, 1.0)
	m.current_hp = 1
	m.current_ep = 0
	ConstStates.apply_state(m, ConstStates.FATIGUED)
	ConstStates.apply_state(m, ConstStates.FATIGUED)
	ConstStates.apply_state(m, ConstStates.MADNESS)
	ConstStates.apply_state(m, ConstStates.MADNESS)
	var started: Array[String] = RestSystem.furlough_start(m)
	TestFixtures.check(res, "furlough_start stamps ten days",
		m.rest_lockout_until == RestSystem.FURLOUGH_MINUTES and m.rest_lockout_kind == "furlough"
		and _has(started, "FURLOUGH START: Fira until D11 00:00"),
		"until %d lines %s" % [m.rest_lockout_until, str(started)])
	TestFixtures.check(res, "furlough_start refuses a resting merc",
		_has(RestSystem.furlough_start(m), "FURLOUGH REFUSED: Fira (resting)"), "second start allowed")
	TestFixtures.check(res, "furlough_complete refuses before the time",
		_has(RestSystem.furlough_complete(m), "FURLOUGH REFUSED: Fira (not until D11 00:00)"),
		"early completion allowed")
	var busy := _merc("Onn", 10, 8, 0, 1.0)
	busy.on_contract = true
	TestFixtures.check(res, "furlough_start refuses a deployed merc",
		_has(RestSystem.furlough_start(busy), "FURLOUGH REFUSED: Onn (on contract)"),
		"start allowed while on contract")
	var rooted := _merc("Mads", 10, 8, 0, 1.0)
	ConstStates.apply_state(rooted, ConstStates.TERRIFIED)
	ConstStates.apply_state(rooted, ConstStates.MADNESS, null, ConstStates.TERRIFIED)
	ConstStates.apply_state(rooted, ConstStates.MADNESS, null, ConstStates.TERRIFIED)
	RestSystem.furlough_start(rooted)
	CampaignClock.advance(RestSystem.FURLOUGH_MINUTES)
	var done: Array[String] = RestSystem.furlough_complete(m)
	TestFixtures.check(res, "furlough_complete fills every pool",
		m.current_hp == 12 and m.current_ep == 8, "hp %d ep %d" % [m.current_hp, m.current_ep])
	TestFixtures.check(res, "furlough_complete clears Fatigued",
		ConstStates.get_count(m, ConstStates.FATIGUED) == 0 and _has(done, "Fatigued cleared"),
		"tier %d lines %s" % [ConstStates.get_count(m, ConstStates.FATIGUED), str(done)])
	TestFixtures.check(res, "furlough_complete drops one Madness tier",
		ConstStates.get_count(m, ConstStates.MADNESS) == 1 and _has(done, "Madness 2 -> 1"),
		"tier %d" % ConstStates.get_count(m, ConstStates.MADNESS))
	TestFixtures.check(res, "furlough_complete releases the lockout",
		m.rest_lockout_until == 0 and m.rest_lockout_kind == "" and RestSystem.is_deployable(m),
		"until %d kind %s" % [m.rest_lockout_until, m.rest_lockout_kind])
	var kept: Array[String] = RestSystem.furlough_complete(rooted)
	TestFixtures.check(res, "an ongoing source keeps the Madness tier",
		ConstStates.get_count(rooted, ConstStates.MADNESS) == 2
		and _has(kept, "Madness 2 kept (ongoing source)"),
		"tier %d lines %s" % [ConstStates.get_count(rooted, ConstStates.MADNESS), str(kept)])
	var ended: Dictionary = ConstStates.remove_state(rooted, ConstStates.TERRIFIED)
	var dropped: Array = ended["cascade"]
	TestFixtures.check(res, "ending the root cascades every Madness tier",
		ConstStates.get_count(rooted, ConstStates.MADNESS) == 0 and dropped.has(ConstStates.MADNESS),
		"tier %d cascade %s" % [ConstStates.get_count(rooted, ConstStates.MADNESS), str(dropped)])


static func _case_triggers(res: Dictionary) -> void:
	CampaignClock.reset()
	TraitRuntime.clear_all()
	var m := _merc("Zena", 10, 8, 0, 1.0)
	m.current_ep = 0
	m.perks.append(_trait("TEST Rest Hooks",
		"on:rest_start:always:resource:excess_hp:+1|on:rest_complete:always:resource:excess_ep:+1"))
	RestSystem.breather(m, null)
	TestFixtures.check(res, "rest_start fires on a breather", m.excess_hp == 1,
		"expected 1 Excess HP, got %d" % m.excess_hp)
	TestFixtures.check(res, "rest_complete fires on a breather", m.excess_ep == 1,
		"expected 1 Excess EP, got %d" % m.excess_ep)
	var zen := _merc("Zed", 10, 8, 0, 1.0)
	zen.current_hp = 1
	zen.perks.append(_trait("TEST Zen Cell", "on:rest_complete:always:resource:excess_ep_or_mp:+1"))
	var party: Array[MercenaryData] = [zen]
	RestSystem.respite(party, null, false)
	TestFixtures.check(res, "the Zen cell grants Excess EP after a respite",
		zen.excess_ep == 1 and zen.excess_mp == 0,
		"ep %d mp %d" % [zen.excess_ep, zen.excess_mp])


static func _case_contract_end(res: Dictionary) -> void:
	CampaignClock.reset()
	BeauSystem.reset()
	var m := _merc("Cass", 10, 8, 0, 1.0)
	m.current_hp = 1
	m.current_ep = 0
	m.excess_hp = 2
	m.excess_ep = 1
	m.on_contract = true
	var run := ContractRun.new()
	run.contract = ContractData.new()
	run.team.append(m)
	ContractManager.end(run)
	TestFixtures.check(res, "the return travel costs eight hours",
		CampaignClock.now() == CampaignClock.TRAVEL_MINUTES,
		"expected %d, got %d" % [CampaignClock.TRAVEL_MINUTES, CampaignClock.now()])
	TestFixtures.check(res, "contract end rests instead of restoring",
		m.current_hp == 5 and m.current_ep == 8, "hp %d ep %d" % [m.current_hp, m.current_ep])
	TestFixtures.check(res, "contract end clears excess",
		m.excess_hp == 0 and m.excess_ep == 0
		and _has(run.log_lines, "EXCESS LOST: Cass 2 ExHP, 1 ExEP (contract return)"),
		"hp %d ep %d" % [m.excess_hp, m.excess_ep])
	TestFixtures.check(res, "contract end logs the respite",
		_has(run.log_lines, "RESPITE: Cass HP 1 -> 5 (cap 50%)"), "no RESPITE line in the log")
	TestFixtures.check(res, "contract end locks the merc out",
		m.rest_lockout_kind == "respite"
		and m.rest_lockout_until == CampaignClock.TRAVEL_MINUTES + RestSystem.RESPITE_MINUTES,
		"until %d kind %s" % [m.rest_lockout_until, m.rest_lockout_kind])
	TestFixtures.check(res, "contract end takes the merc off contract", not m.on_contract,
		"on_contract still true")
