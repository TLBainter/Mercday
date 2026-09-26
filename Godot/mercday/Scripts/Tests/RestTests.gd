class_name RestTests

#Breather, Respite and Furlough behaviour. Run: godot --headless --path . -- --rest-tests
#Every case resets the campaign clock first, so the suite is order independent.


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_breather(res)
	_case_rate(res)
	_case_respite(res)
	_case_respite_excess(res)
	_case_respite_expiry(res)
	_case_after_encounter_cap(res)
	_case_clear_by_verb(res)
	_case_furlough(res)
	_case_triggers(res)
	_case_contract_end(res)
	_case_contract_end_kidnapped(res)
	_case_sources(res)
	_case_rest_sources(res)
	_case_apply_until(res)
	_case_snapshot(res)
	_case_action_pools(res)
	_case_action_realign(res)
	_case_action_respite(res)
	_case_action_furlough(res)
	_case_action_training(res)
	_case_action_picker(res)
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


#One recorded source of the state; an empty dictionary when that tier is missing.
static func _src(merc: MercenaryData, state_name: String, index: int) -> Dictionary:
	var list: Array[Dictionary] = StateSources.state_sources(merc, state_name)
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


#A whole furlough for one merc: start it, wait out its time, complete it.
static func _furlough(merc: MercenaryData) -> Array[String]:
	RestSystem.furlough_start(merc)
	CampaignClock.advance_to(merc.rest_lockout_until)
	return RestSystem.furlough_complete(merc)


static func _respite(merc: MercenaryData) -> Array[String]:
	var party: Array[MercenaryData] = [merc]
	return RestSystem.respite(party, null)


static func _case_breather(res: Dictionary) -> void:
	CampaignClock.reset()
	var low := _merc("Bree", 10, 8, 0, 0.0)
	low.current_ep = 3
	low.current_hp = 4
	var lines: Array[String] = RestSystem.breather(low, null)
	TestFixtures.check(res, "breather tops EP to the cap and Stretch adds one", low.current_ep == 5,
		"expected 5, got %d" % low.current_ep)
	TestFixtures.check(res, "breather leaves HP alone", low.current_hp == 4,
		"expected 4, got %d" % low.current_hp)
	TestFixtures.check(res, "breather line names the change",
		TestFixtures.has_line(lines, "BREATHER: Bree EP 3 -> 4, MP 0 -> 0 (cap 50%)"), "lines %s" % str(lines))
	var above := _merc("Ova", 10, 8, 0, 0.0)
	above.current_ep = 5
	RestSystem.breather(above, null)
	TestFixtures.check(res, "breather never lowers a pool", above.current_ep == 6,
		"expected 6, got %d" % above.current_ep)
	var near_full := _merc("Fenn", 10, 8, 0, 0.0)
	near_full.current_ep = 7
	var skipped: Array[String] = RestSystem.breather(near_full, null)
	TestFixtures.check(res, "breather skipped inside the deficit bar",
		near_full.current_ep == 7 and TestFixtures.has_line(skipped, "BREATHER SKIPPED: Fenn (EP 7/8, MP 0/0)"),
		"ep %d lines %s" % [near_full.current_ep, str(skipped)])
	var dead := _merc("Gone", 10, 8, 0, 0.0)
	dead.current_ep = 0
	dead.is_dead = true
	TestFixtures.check(res, "breather ignores the dead", RestSystem.breather(dead, null).is_empty(),
		"expected no lines for a corpse")
	var party: Array[MercenaryData] = [low, near_full]
	var party_lines: Array[String] = RestSystem.breather_party(party, 0.0, null)
	TestFixtures.check(res, "breather_party covers every merc", party_lines.size() == 3,
		"expected 3 lines, got %d" % party_lines.size())


#Rest Recovery is a signed percent of rest time saved; the slowest living merc sets a party's time.
static func _case_rate(res: Dictionary) -> void:
	CampaignClock.reset()
	var fast := _merc("Fasta", 10, 8, 0, 50.0)
	TestFixtures.check(res, "+50 shortens a Respite to 3 h",
		RestSystem.rest_minutes(fast, RestSystem.RESPITE_MINUTES) == 180,
		"expected 180, got %d" % RestSystem.rest_minutes(fast, RestSystem.RESPITE_MINUTES))
	TestFixtures.check(res, "+50 shortens a Furlough to 5 d",
		RestSystem.rest_minutes(fast, RestSystem.FURLOUGH_MINUTES) == 7200,
		"expected 7200, got %d" % RestSystem.rest_minutes(fast, RestSystem.FURLOUGH_MINUTES))
	var slow := _merc("Slo", 10, 8, 0, -100.0)
	TestFixtures.check(res, "-100 doubles a Breather",
		RestSystem.rest_minutes(slow, RestSystem.BREATHER_MINUTES) == 20,
		"expected 20, got %d" % RestSystem.rest_minutes(slow, RestSystem.BREATHER_MINUTES))
	TestFixtures.check(res, "-100 doubles a Respite",
		RestSystem.rest_minutes(slow, RestSystem.RESPITE_MINUTES) == 720,
		"expected 720, got %d" % RestSystem.rest_minutes(slow, RestSystem.RESPITE_MINUTES))
	TestFixtures.check(res, "-100 doubles a Furlough to 20 d",
		RestSystem.rest_minutes(slow, RestSystem.FURLOUGH_MINUTES) == 28800,
		"expected 28800, got %d" % RestSystem.rest_minutes(slow, RestSystem.FURLOUGH_MINUTES))
	var dire := _merc("Dira", 10, 8, 0, -150.0)
	TestFixtures.check(res, "-150 keeps growing",
		RestSystem.rest_minutes(dire, RestSystem.FURLOUGH_MINUTES) == 36000,
		"expected 36000, got %d" % RestSystem.rest_minutes(dire, RestSystem.FURLOUGH_MINUTES))
	var odd := _merc("Odda", 10, 8, 0, -33.0)
	TestFixtures.check(res, "rest_minutes rounds to the nearest minute",
		RestSystem.rest_minutes(odd, RestSystem.BREATHER_MINUTES) == 13,
		"expected 13, got %d" % RestSystem.rest_minutes(odd, RestSystem.BREATHER_MINUTES))
	var blur := _merc("Blur", 10, 8, 0, 100.0)
	TestFixtures.check(res, "a Breather never drops below one minute",
		RestSystem.rest_minutes(blur, RestSystem.BREATHER_MINUTES) == RestSystem.MIN_REST_MINUTES,
		"expected %d, got %d" % [RestSystem.MIN_REST_MINUTES,
		RestSystem.rest_minutes(blur, RestSystem.BREATHER_MINUTES)])
	TestFixtures.check(res, "a Furlough never drops below one day",
		RestSystem.rest_minutes(blur, RestSystem.FURLOUGH_MINUTES) == RestSystem.FURLOUGH_MIN_MINUTES,
		"expected %d, got %d" % [RestSystem.FURLOUGH_MIN_MINUTES,
		RestSystem.rest_minutes(blur, RestSystem.FURLOUGH_MINUTES)])
	var keen := _merc("Kena", 10, 8, 0, 99.0)
	TestFixtures.check(res, "a Respite never drops below one hour",
		RestSystem.rest_minutes(keen, RestSystem.RESPITE_MINUTES) == RestSystem.RESPITE_MIN_MINUTES,
		"expected %d, got %d" % [RestSystem.RESPITE_MIN_MINUTES,
		RestSystem.rest_minutes(keen, RestSystem.RESPITE_MINUTES)])
	var over := _merc("Ovra", 10, 8, 0, 150.0)
	TestFixtures.check(res, "a value above 100 rests at the minimum",
		RestSystem.rest_minutes(over, RestSystem.BREATHER_MINUTES) == RestSystem.MIN_REST_MINUTES,
		"expected %d, got %d" % [RestSystem.MIN_REST_MINUTES,
		RestSystem.rest_minutes(over, RestSystem.BREATHER_MINUTES)])
	var bare := _merc("Bara", 10, 8, 0, 0.0)
	bare.stats.erase("rest_recovery")
	bare.current_ep = 0
	TestFixtures.check(res, "a missing rest_recovery rests at the base",
		RestSystem.rest_minutes(bare, RestSystem.RESPITE_MINUTES) == RestSystem.RESPITE_MINUTES,
		"expected %d, got %d" % [RestSystem.RESPITE_MINUTES,
		RestSystem.rest_minutes(bare, RestSystem.RESPITE_MINUTES)])
	var zero := _merc("Zeno", 10, 8, 0, 0.0)
	TestFixtures.check(res, "0 rests at the base",
		RestSystem.rest_minutes(zero, RestSystem.RESPITE_MINUTES) == RestSystem.RESPITE_MINUTES,
		"expected %d, got %d" % [RestSystem.RESPITE_MINUTES,
		RestSystem.rest_minutes(zero, RestSystem.RESPITE_MINUTES)])
	var gone := _merc("Gonn", 10, 8, 0, -300.0)
	gone.is_dead = true
	var party: Array[MercenaryData] = [fast, slow, gone]
	TestFixtures.check(res, "the slowest living merc sets the party time",
		RestSystem.party_rest_minutes(party, RestSystem.RESPITE_MINUTES) == 720,
		"expected 720, got %d" % RestSystem.party_rest_minutes(party, RestSystem.RESPITE_MINUTES))
	var slowest: MercenaryData = RestSystem.party_slowest(party, RestSystem.RESPITE_MINUTES)
	TestFixtures.check(res, "party_slowest names the slowest", slowest == slow,
		"got %s" % ("null" if slowest == null else slowest.merc_name))
	var none: Array[MercenaryData] = []
	TestFixtures.check(res, "an empty party rests at the base",
		RestSystem.party_rest_minutes(none, RestSystem.RESPITE_MINUTES) == RestSystem.RESPITE_MINUTES,
		"expected %d, got %d" % [RestSystem.RESPITE_MINUTES,
		RestSystem.party_rest_minutes(none, RestSystem.RESPITE_MINUTES)])
	var want_line: String = "REST TIME: respite 12 h (slowest Slo, rest recovery -100%)"
	var got_line: String = RestSystem.party_line("respite", party, RestSystem.RESPITE_MINUTES)
	TestFixtures.check(res, "party_line names the slowest merc", got_line == want_line,
		"got %s" % got_line)
	var brisk := _merc("Brix", 10, 8, 0, 75.0)
	brisk.current_ep = 0
	RestSystem.breather(brisk, null)
	var lax := _merc("Laxa", 10, 8, 0, -100.0)
	lax.current_ep = 0
	RestSystem.breather(lax, null)
	TestFixtures.check(res, "the breather cap ignores rest_recovery",
		brisk.current_ep == 5 and lax.current_ep == 5,
		"fast %d slow %d" % [brisk.current_ep, lax.current_ep])
	RestSystem.breather(bare, null)
	TestFixtures.check(res, "the plain cap tops 8 EP to 4 before Stretch", bare.current_ep == 5,
		"expected 5, got %d" % bare.current_ep)


#The Respite is deferred: the start stamps a lockout and the clock pays the recovery.
static func _case_respite(res: Dictionary) -> void:
	CampaignClock.reset()
	var m := _merc("Cara", 10, 8, 4, 0.0)
	m.current_hp = 1
	m.current_ep = 0
	m.current_mp = 0
	ConstStates.apply_state(m, ConstStates.FATIGUED)
	ConstStates.apply_state(m, ConstStates.FATIGUED)
	var hale := _merc("Hale", 10, 8, 0, 50.0)
	hale.current_hp = 1
	var party: Array[MercenaryData] = [m, hale]
	var lines: Array[String] = RestSystem.respite_start(party, null)
	TestFixtures.check(res, "respite_start stamps the lockout",
		m.rest_lockout_until == RestSystem.RESPITE_MINUTES and m.rest_lockout_kind == "respite"
		and TestFixtures.has_line(lines, "RESPITE LOCKOUT: Cara until D1 06:00 (6 h)"),
		"until %d kind %s" % [m.rest_lockout_until, m.rest_lockout_kind])
	TestFixtures.check(res, "a faster merc gets a shorter lockout",
		hale.rest_lockout_until == 180 and TestFixtures.has_line(lines, "RESPITE LOCKOUT: Hale until D1 03:00 (3 h)"),
		"until %d lines %s" % [hale.rest_lockout_until, str(lines)])
	TestFixtures.check(res, "respite_start pays no recovery",
		m.current_hp == 1 and m.current_ep == 0
		and ConstStates.get_count(m, ConstStates.FATIGUED) == 2,
		"hp %d ep %d tier %d" % [m.current_hp, m.current_ep,
		ConstStates.get_count(m, ConstStates.FATIGUED)])
	TestFixtures.check(res, "a locked out merc is undeployable", not RestSystem.is_deployable(m),
		"is_deployable true at minute %d" % CampaignClock.now())
	TestFixtures.check(res, "respite_complete refuses before the time",
		TestFixtures.has_line(RestSystem.respite_complete(m), "RESPITE REFUSED: Cara (not until D1 06:00)"),
		"early completion allowed")
	CampaignClock.advance_to(240)
	var early: Array[String] = RestSystem.complete_due_rests(party, CampaignClock.now())
	TestFixtures.check(res, "the shorter lockout completes on its own clock",
		hale.current_hp == 6 and m.current_hp == 1 and TestFixtures.has_line(early, "RESPITE: Hale"),
		"hale %d cara %d lines %s" % [hale.current_hp, m.current_hp, str(early)])
	CampaignClock.advance_to(RestSystem.RESPITE_MINUTES)
	var done: Array[String] = RestSystem.complete_due_rests(party, CampaignClock.now())
	TestFixtures.check(res, "the respite tops HP to the partial cap and fills EP and MP",
		m.current_hp == 5 and m.current_ep == 8 and m.current_mp == 4,
		"hp %d ep %d mp %d" % [m.current_hp, m.current_ep, m.current_mp])
	TestFixtures.check(res, "the respite drops one Fatigued tier and Deep Sleep the next",
		ConstStates.get_count(m, ConstStates.FATIGUED) == 0 and TestFixtures.has_line(done, "Fatigued 2 -> 1"),
		"tier %d lines %s" % [ConstStates.get_count(m, ConstStates.FATIGUED), str(done)])
	TestFixtures.check(res, "completion releases the lockout",
		m.rest_lockout_until == 0 and m.rest_lockout_kind == "" and RestSystem.is_deployable(m),
		"until %d kind %s" % [m.rest_lockout_until, m.rest_lockout_kind])
	var whole := _merc("Ilse", 10, 8, 0, 0.0)
	var full_party: Array[MercenaryData] = [whole]
	TestFixtures.check(res, "party_lost_hp is false at full HP", not RestSystem.party_lost_hp(full_party),
		"expected false at %d/%d" % [whole.current_hp, 10])
	whole.current_hp = 9
	TestFixtures.check(res, "party_lost_hp sees one wound", RestSystem.party_lost_hp(full_party),
		"expected true at %d/%d" % [whole.current_hp, 10])


static func _case_respite_excess(res: Dictionary) -> void:
	CampaignClock.reset()
	var m := _merc("Dax", 10, 8, 0, 0.0)
	m.current_hp = 1
	m.excess_hp = 2
	m.excess_ep = 1
	var party: Array[MercenaryData] = [m]
	RestSystem.respite(party, null)
	TestFixtures.check(res, "respite never clears excess", m.excess_hp == 2 and m.excess_ep == 1,
		"expected 2 and 1, got %d and %d" % [m.excess_hp, m.excess_ep])
	TestFixtures.check(res, "respite without lockout leaves the merc free",
		m.rest_lockout_until == 0 and RestSystem.is_deployable(m),
		"until %d" % m.rest_lockout_until)


#A rest never ends a timer early; the clock does, and a rest verb reaches its state at completion.
static func _case_respite_expiry(res: Dictionary) -> void:
	CampaignClock.reset()
	var m := _merc("Dree", 10, 8, 0, 0.0)
	ConstStates.apply_state(m, ConstStates.DRENCHED)
	m.campaign_states[ConstStates.DRENCHED] = CampaignClock.now() + CampaignClock.MINUTES_PER_HOUR
	var party: Array[MercenaryData] = [m]
	RestSystem.respite_start(party, null)
	TestFixtures.check(res, "a lockout leaves a later timer running",
		ConstStates.has_state(m, ConstStates.DRENCHED)
		and m.rest_lockout_until == RestSystem.RESPITE_MINUTES,
		"held %s until %d" % [str(ConstStates.has_state(m, ConstStates.DRENCHED)), m.rest_lockout_until])
	RestSystem.respite(party, null)
	TestFixtures.check(res, "a respite whose time the caller paid leaves a later timer",
		ConstStates.has_state(m, ConstStates.DRENCHED), "Drenched ended early")
	CampaignClock.advance(CampaignClock.MINUTES_PER_HOUR)
	var expired: Array[String] = StateCampaign.expire_campaign_states(m, CampaignClock.now())
	TestFixtures.check(res, "the clock ends the hour timer",
		not ConstStates.has_state(m, ConstStates.DRENCHED) and TestFixtures.has_line(expired, "Dree dried up."),
		"held %s lines %s" % [str(ConstStates.has_state(m, ConstStates.DRENCHED)), str(expired)])
	TestFixtures.check(res, "the expired timer is erased",
		not m.campaign_states.has(ConstStates.DRENCHED), "timers %s" % str(m.campaign_states))
	var f := _merc("Fera", 10, 8, 0, 0.0)
	ConstStates.apply_state(f, ConstStates.FATIGUED)
	var held: Array[MercenaryData] = [f]
	var started: Array[String] = RestSystem.respite_start(held, null)
	TestFixtures.check(res, "the start of a respite holds a rest verb state",
		ConstStates.get_count(f, ConstStates.FATIGUED) == 1 and not TestFixtures.has_line(started, "RESPITE: Fera"),
		"tier %d lines %s" % [ConstStates.get_count(f, ConstStates.FATIGUED), str(started)])
	CampaignClock.advance_to(f.rest_lockout_until)
	var done: Array[String] = RestSystem.complete_due_rests(held, CampaignClock.now())
	TestFixtures.check(res, "completion drops the tier the rest verb reaches",
		ConstStates.get_count(f, ConstStates.FATIGUED) == 0 and TestFixtures.has_line(done, "RESPITE: Fera"),
		"tier %d lines %s" % [ConstStates.get_count(f, ConstStates.FATIGUED), str(done)])


#A state in ConstStates.AFTER_ENCOUNTER_MINUTES may not outlast the battle by more than its cap.
static func _case_after_encounter_cap(res: Dictionary) -> void:
	CampaignClock.reset()
	CampaignClock.advance(100)
	var wet := _merc("Wex", 10, 8, 0, 0.0)
	var cold := _merc("Cole", 10, 8, 0, 0.0)
	var team_a: Array[MercenaryData] = [wet]
	var team_b: Array[MercenaryData] = [cold]
	var st := BattleState.create(team_a, team_b, null)
	st.round_number = 3
	ConstStates.apply_state(wet, ConstStates.DRENCHED)
	st.export_campaign_timers()
	var capped: int = int(wet.campaign_states.get(ConstStates.DRENCHED, 0))
	TestFixtures.check(res, "a held Drenched ends one Breather after the encounter",
		capped == CampaignClock.now() + 10,
		"expected %d, got %d" % [CampaignClock.now() + 10, capped])
	ConstStates.apply_state(wet, ConstStates.DRENCHED)
	st.set_state_timer(wet, ConstStates.DRENCHED, st.round_number + 1, "")
	st.export_campaign_timers()
	var early: int = int(wet.campaign_states.get(ConstStates.DRENCHED, 0))
	TestFixtures.check(res, "an earlier in-battle expiry stays below the cap",
		early == CampaignClock.now() + 1,
		"expected %d, got %d" % [CampaignClock.now() + 1, early])
	ConstStates.apply_state(cold, "Frostbite")
	st.export_campaign_timers()
	var full: int = int(cold.campaign_states.get("Frostbite", 0))
	TestFixtures.check(res, "a state without a cap keeps its full hour",
		full == CampaignClock.now() + 60,
		"expected %d, got %d" % [CampaignClock.now() + 60, full])


static func _case_clear_by_verb(res: Dictionary) -> void:
	CampaignClock.reset()
	var m := _merc("Hex", 10, 8, 0, 0.0)
	ConstStates.apply_state(m, "Heat Exhaustion")
	var lines: Array[String] = RestSystem.clear_by_verb(m, "respite")
	TestFixtures.check(res, "the respite verb clears Heat Exhaustion",
		not ConstStates.has_state(m, "Heat Exhaustion") and TestFixtures.has_line(lines, "Hex has cooled down."),
		"held %s lines %s" % [str(ConstStates.has_state(m, "Heat Exhaustion")), str(lines)])
	var keeper := _merc("Kip", 10, 8, 0, 0.0)
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
	var m := _merc("Fira", 12, 8, 0, 0.0)
	m.current_hp = 1
	m.current_ep = 0
	ConstStates.apply_state(m, ConstStates.FATIGUED)
	ConstStates.apply_state(m, ConstStates.FATIGUED)
	ConstStates.apply_state(m, ConstStates.MADNESS)
	ConstStates.apply_state(m, ConstStates.MADNESS)
	var started: Array[String] = RestSystem.furlough_start(m)
	TestFixtures.check(res, "furlough_start stamps ten days",
		m.rest_lockout_until == RestSystem.FURLOUGH_MINUTES and m.rest_lockout_kind == "furlough"
		and TestFixtures.has_line(started, "FURLOUGH START: Fira until D11 00:00 (10 d)"),
		"until %d lines %s" % [m.rest_lockout_until, str(started)])
	TestFixtures.check(res, "furlough_start refuses a resting merc",
		TestFixtures.has_line(RestSystem.furlough_start(m), "FURLOUGH REFUSED: Fira (resting)"), "second start allowed")
	TestFixtures.check(res, "furlough_complete refuses before the time",
		TestFixtures.has_line(RestSystem.furlough_complete(m), "FURLOUGH REFUSED: Fira (not until D11 00:00)"),
		"early completion allowed")
	var busy := _merc("Onn", 10, 8, 0, 0.0)
	busy.on_contract = true
	TestFixtures.check(res, "furlough_start refuses a deployed merc",
		TestFixtures.has_line(RestSystem.furlough_start(busy), "FURLOUGH REFUSED: Onn (on contract)"),
		"start allowed while on contract")
	var rooted := _merc("Mads", 10, 8, 0, 0.0)
	ConstStates.apply_state(rooted, ConstStates.TERRIFIED)
	ConstStates.apply_state(rooted, ConstStates.MADNESS, null, ConstStates.TERRIFIED)
	ConstStates.apply_state(rooted, ConstStates.MADNESS, null, ConstStates.TERRIFIED)
	RestSystem.furlough_start(rooted)
	var quin := _merc("Quin", 10, 8, 0, 50.0)
	var quin_started: Array[String] = RestSystem.furlough_start(quin)
	TestFixtures.check(res, "a faster merc takes a shorter furlough",
		quin.rest_lockout_until == 7200
		and TestFixtures.has_line(quin_started, "FURLOUGH START: Quin until D6 00:00 (5 d)"),
		"until %d lines %s" % [quin.rest_lockout_until, str(quin_started)])
	CampaignClock.advance_to(quin.rest_lockout_until)
	var quin_done: Array[String] = RestSystem.furlough_complete(quin)
	var early: Array[String] = RestSystem.furlough_complete(m)
	TestFixtures.check(res, "the shorter furlough completes on its own clock",
		TestFixtures.has_line(quin_done, "FURLOUGH COMPLETE: Quin")
		and TestFixtures.has_line(early, "FURLOUGH REFUSED: Fira (not until D11 00:00)"),
		"quin %s fira %s" % [str(quin_done), str(early)])
	CampaignClock.advance_to(m.rest_lockout_until)
	var done: Array[String] = RestSystem.furlough_complete(m)
	TestFixtures.check(res, "furlough_complete fills every pool",
		m.current_hp == 12 and m.current_ep == 8, "hp %d ep %d" % [m.current_hp, m.current_ep])
	TestFixtures.check(res, "furlough_complete clears Fatigued",
		ConstStates.get_count(m, ConstStates.FATIGUED) == 0 and TestFixtures.has_line(done, "Fatigued cleared"),
		"tier %d lines %s" % [ConstStates.get_count(m, ConstStates.FATIGUED), str(done)])
	TestFixtures.check(res, "furlough_complete drops one Madness tier",
		ConstStates.get_count(m, ConstStates.MADNESS) == 1 and TestFixtures.has_line(done, "Madness 2 -> 1"),
		"tier %d" % ConstStates.get_count(m, ConstStates.MADNESS))
	TestFixtures.check(res, "furlough_complete releases the lockout",
		m.rest_lockout_until == 0 and m.rest_lockout_kind == "" and RestSystem.is_deployable(m),
		"until %d kind %s" % [m.rest_lockout_until, m.rest_lockout_kind])
	var kept: Array[String] = RestSystem.furlough_complete(rooted)
	TestFixtures.check(res, "an ongoing source keeps the Madness tier",
		ConstStates.get_count(rooted, ConstStates.MADNESS) == 2
		and TestFixtures.has_line(kept, "Madness 2 kept (ongoing source)"),
		"tier %d lines %s" % [ConstStates.get_count(rooted, ConstStates.MADNESS), str(kept)])
	var ended: Dictionary = ConstStates.remove_state(rooted, ConstStates.TERRIFIED)
	var dropped: Array = ended["cascade"]
	TestFixtures.check(res, "ending the root cascades every Madness tier",
		ConstStates.get_count(rooted, ConstStates.MADNESS) == 0 and dropped.has(ConstStates.MADNESS),
		"tier %d cascade %s" % [ConstStates.get_count(rooted, ConstStates.MADNESS), str(dropped)])


static func _case_triggers(res: Dictionary) -> void:
	CampaignClock.reset()
	TraitRuntime.clear_all()
	var m := _merc("Zena", 10, 8, 0, 0.0)
	m.current_ep = 0
	m.perks.append(_trait("TEST Rest Hooks",
		"on:rest_start:always:resource:excess_hp:+1|on:rest_complete:always:resource:excess_ep:+1"))
	RestSystem.breather(m, null)
	TestFixtures.check(res, "rest_start fires on a breather", m.excess_hp == 1,
		"expected 1 Excess HP, got %d" % m.excess_hp)
	TestFixtures.check(res, "rest_complete fires on a breather", m.excess_ep == 1,
		"expected 1 Excess EP, got %d" % m.excess_ep)
	var zen := _merc("Zed", 10, 8, 0, 0.0)
	zen.current_hp = 1
	zen.perks.append(_trait("TEST Zen Cell", "on:rest_complete:always:resource:excess_ep_or_mp:+1"))
	var party: Array[MercenaryData] = [zen]
	RestSystem.respite(party, null)
	TestFixtures.check(res, "the Zen cell grants Excess EP after a respite",
		zen.excess_ep == 1 and zen.excess_mp == 0,
		"ep %d mp %d" % [zen.excess_ep, zen.excess_mp])
	var fur := _merc("Furl", 10, 8, 0, 0.0)
	fur.current_ep = 0
	fur.perks.append(_trait("TEST Furlough Hooks",
		"on:rest_start:always:resource:excess_hp:+1|on:rest_complete:always:resource:excess_ep:+1"))
	RestSystem.furlough_start(fur)
	TestFixtures.check(res, "rest_start fires when a furlough starts",
		fur.excess_hp == 1 and fur.excess_ep == 0,
		"hp %d ep %d" % [fur.excess_hp, fur.excess_ep])
	CampaignClock.advance_to(fur.rest_lockout_until)
	RestSystem.furlough_complete(fur)
	TestFixtures.check(res, "rest_complete fires when a furlough completes", fur.excess_ep == 1,
		"expected 1 Excess EP, got %d" % fur.excess_ep)
	TestFixtures.check(res, "a furlough fires rest_start once", fur.excess_hp == 3,
		"expected 1 Excess HP plus 2 from Meditate, got %d" % fur.excess_hp)


#Contract end defers the Respite: the return stamps the lockout, the clock pays the recovery.
static func _case_contract_end(res: Dictionary) -> void:
	CampaignClock.reset()
	BeauSystem.reset()
	var m := _merc("Cass", 10, 8, 0, 0.0)
	m.current_hp = 1
	m.current_ep = 0
	m.excess_hp = 2
	m.excess_ep = 1
	m.on_contract = true
	var contract_run := ContractRun.new()
	contract_run.contract = ContractData.new()
	contract_run.team.append(m)
	ContractManager.end(contract_run)
	TestFixtures.check(res, "the return travel costs eight hours",
		CampaignClock.now() == CampaignClock.TRAVEL_MINUTES,
		"expected %d, got %d" % [CampaignClock.TRAVEL_MINUTES, CampaignClock.now()])
	TestFixtures.check(res, "contract end defers the recovery",
		m.current_hp == 1 and m.current_ep == 0, "hp %d ep %d" % [m.current_hp, m.current_ep])
	TestFixtures.check(res, "contract end clears excess",
		m.excess_hp == 0 and m.excess_ep == 0
		and TestFixtures.has_line(contract_run.log_lines, "EXCESS LOST: Cass 2 ExHP, 1 ExEP (contract return)"),
		"hp %d ep %d" % [m.excess_hp, m.excess_ep])
	TestFixtures.check(res, "contract end logs the lockout and no rest",
		TestFixtures.has_line(contract_run.log_lines, "RESPITE LOCKOUT: Cass until D1 14:00 (6 h)")
		and not TestFixtures.has_line(contract_run.log_lines, "RESPITE: Cass"), "lines %s" % str(contract_run.log_lines))
	TestFixtures.check(res, "contract end locks the merc out",
		m.rest_lockout_kind == "respite"
		and m.rest_lockout_until == CampaignClock.TRAVEL_MINUTES
		+ RestSystem.rest_minutes(m, RestSystem.RESPITE_MINUTES),
		"until %d kind %s" % [m.rest_lockout_until, m.rest_lockout_kind])
	TestFixtures.check(res, "contract end takes the merc off contract", not m.on_contract,
		"on_contract still true")
	var party: Array[MercenaryData] = [m]
	CampaignClock.advance_to(m.rest_lockout_until)
	var done: Array[String] = RestSystem.complete_due_rests(party, CampaignClock.now())
	TestFixtures.check(res, "the deferred respite lands on the clock",
		m.current_hp == 6 and m.current_ep == 8
		and TestFixtures.has_line(done, "RESPITE: Cass HP 1 -> 5 (cap 50%)"),
		"hp %d ep %d lines %s" % [m.current_hp, m.current_ep, str(done)])


#A kidnapped merc leaves run.team, so the return has to take that merc off contract from its own list.
static func _case_contract_end_kidnapped(res: Dictionary) -> void:
	CampaignClock.reset()
	BeauSystem.reset()
	var m := _merc("Vess", 10, 8, 0, 0.0)
	m.on_contract = true
	var contract_run := ContractRun.new()
	contract_run.contract = ContractData.new()
	contract_run.kidnapped.append(m)
	ContractManager.end(contract_run)
	TestFixtures.check(res, "contract end takes a kidnapped merc off contract", not m.on_contract,
		"on_contract still true")

#Every applied state records where it came from and which rest may lift it.
static func _case_sources(res: Dictionary) -> void:
	CampaignClock.reset()
	var m := _merc("Sorn", 10, 8, 0, 0.0)
	ConstStates.apply_state(m, ConstStates.FATIGUED)
	var fat: Dictionary = _src(m, ConstStates.FATIGUED, 0)
	TestFixtures.check(res, "a bare apply records an engine source",
		str(fat.get("kind", "")) == "engine" and str(fat.get("name", "?")) == "",
		"source %s" % _src_text(fat))
	TestFixtures.check(res, "the Fatigued source carries the sheet verbs",
		_verbs(fat) == "respite,furlough", "source %s" % _src_text(fat))
	ConstStates.apply_state(m, ConstStates.MADNESS)
	var mad: Dictionary = _src(m, ConstStates.MADNESS, 0)
	TestFixtures.check(res, "a Madness tier carries the sheet verbs",
		_verbs(mad) == "cause,furlough", "source %s" % _src_text(mad))
	var t := _merc("Tarn", 10, 8, 0, 0.0)
	ConstStates.apply_state(t, ConstStates.SURPRISED, null, "", "trait:Echoes of Ruin")
	var from_trait: Dictionary = _src(t, ConstStates.SURPRISED, 0)
	TestFixtures.check(res, "a trait origin splits into kind and name",
		str(from_trait.get("kind", "")) == "trait"
		and str(from_trait.get("name", "")) == "Echoes of Ruin",
		"source %s" % _src_text(from_trait))
	var b := _merc("Bram", 10, 8, 0, 0.0)
	ConstStates.apply_state(b, ConstStates.SURPRISED, null, "", "bogus")
	var odd: Dictionary = _src(b, ConstStates.SURPRISED, 0)
	TestFixtures.check(res, "an unknown origin kind reads as engine",
		str(odd.get("kind", "")) == "engine" and str(odd.get("name", "")) == "bogus",
		"source %s" % _src_text(odd))
	var copy: Dictionary = _src(m, ConstStates.FATIGUED, 0)
	copy["kind"] = "tampered"
	var loose: Array = copy.get("removal", [])
	loose.append("nonsense")
	var after: Dictionary = _src(m, ConstStates.FATIGUED, 0)
	TestFixtures.check(res, "state_sources hands back a copy",
		str(after.get("kind", "")) == "engine" and _verbs(after) == "respite,furlough",
		"source %s" % _src_text(after))
	var d := _merc("Dorn", 10, 8, 0, 0.0)
	var only_respite: Array[String] = ["respite"]
	ConstStates.apply_state(d, ConstStates.DRENCHED, null, "", "", only_respite)
	var forced: Dictionary = _src(d, ConstStates.DRENCHED, 0)
	TestFixtures.check(res, "the removal parameter overrides the sheet verbs",
		_verbs(forced) == "respite", "source %s" % _src_text(forced))


#A rest lifts a state only when a recorded source names that rest.
static func _case_rest_sources(res: Dictionary) -> void:
	CampaignClock.reset()
	var only_furlough: Array[String] = ["furlough"]
	var only_cause: Array[String] = ["cause"]
	var only_respite: Array[String] = ["respite"]
	var f := _merc("Fenna", 10, 8, 0, 0.0)
	ConstStates.apply_state(f, ConstStates.FATIGUED, null, "", "", only_furlough)
	var rested: Array[String] = _respite(f)
	TestFixtures.check(res, "a furlough-only tier survives a respite",
		ConstStates.get_count(f, ConstStates.FATIGUED) == 1
		and TestFixtures.has_line(rested, "Fatigued 1 kept (no respite source)"),
		"tier %d lines %s" % [ConstStates.get_count(f, ConstStates.FATIGUED), str(rested)])
	var freed: Array[String] = _furlough(f)
	TestFixtures.check(res, "the furlough clears the furlough-only tier",
		ConstStates.get_count(f, ConstStates.FATIGUED) == 0 and TestFixtures.has_line(freed, "Fatigued cleared"),
		"tier %d lines %s" % [ConstStates.get_count(f, ConstStates.FATIGUED), str(freed)])
	var mc := _merc("Mira", 10, 8, 0, 0.0)
	ConstStates.apply_state(mc, ConstStates.MADNESS, null, "", "", only_cause)
	var kept: Array[String] = _furlough(mc)
	TestFixtures.check(res, "a cause-only Madness tier is kept by a furlough",
		ConstStates.get_count(mc, ConstStates.MADNESS) == 1
		and TestFixtures.has_line(kept, "Madness 1 kept (no furlough source)"),
		"tier %d lines %s" % [ConstStates.get_count(mc, ConstStates.MADNESS), str(kept)])
	var two := _merc("Tova", 10, 8, 0, 0.0)
	ConstStates.apply_state(two, ConstStates.MADNESS, null, "", "", only_cause)
	ConstStates.apply_state(two, ConstStates.MADNESS)
	var first: Array[String] = _furlough(two)
	TestFixtures.check(res, "the furlough drops the newest tier it may",
		ConstStates.get_count(two, ConstStates.MADNESS) == 1 and TestFixtures.has_line(first, "Madness 2 -> 1"),
		"tier %d lines %s" % [ConstStates.get_count(two, ConstStates.MADNESS), str(first)])
	var second: Array[String] = _furlough(two)
	TestFixtures.check(res, "the second furlough keeps the cause-only tier",
		ConstStates.get_count(two, ConstStates.MADNESS) == 1
		and TestFixtures.has_line(second, "Madness 1 kept (no furlough source)"),
		"tier %d lines %s" % [ConstStates.get_count(two, ConstStates.MADNESS), str(second)])
	var wet := _merc("Wend", 10, 8, 0, 0.0)
	ConstStates.apply_state(wet, ConstStates.DRENCHED, null, "", "", only_respite)
	var dried: Array[String] = _respite(wet)
	TestFixtures.check(res, "a respite source clears Drenched",
		not ConstStates.has_state(wet, ConstStates.DRENCHED) and TestFixtures.has_line(dried, "Wend dried up."),
		"held %s lines %s" % [str(ConstStates.has_state(wet, ConstStates.DRENCHED)), str(dried)])
	var damp := _merc("Dane", 10, 8, 0, 0.0)
	ConstStates.apply_state(damp, ConstStates.DRENCHED)
	var still: Array[String] = _respite(damp)
	TestFixtures.check(res, "a Drenched no rest verb reaches is left alone",
		ConstStates.has_state(damp, ConstStates.DRENCHED) and not TestFixtures.has_line(still, "STATE HELD"),
		"held %s lines %s" % [str(ConstStates.has_state(damp, ConstStates.DRENCHED)), str(still)])
	var hot := _merc("Hale", 10, 8, 0, 0.0)
	ConstStates.apply_state(hot, ConstStates.FATIGUED)
	ConstStates.apply_state(hot, "Heat Exhaustion")
	var before_tiers: int = ConstStates.get_count(hot, ConstStates.FATIGUED)
	ConstStates.remove_state(hot, "Heat Exhaustion")
	TestFixtures.check(res, "ending the root drops only the tier it applied",
		before_tiers == 2 and ConstStates.get_count(hot, ConstStates.FATIGUED) == 1,
		"tiers %d -> %d" % [before_tiers, ConstStates.get_count(hot, ConstStates.FATIGUED)])
	var left: Dictionary = _src(hot, ConstStates.FATIGUED, 0)
	TestFixtures.check(res, "the direct tier keeps its engine source",
		str(left.get("kind", "")) == "engine", "source %s" % _src_text(left))


#An until: tail on a trait apply: token names the rest that may lift the state.
static func _case_apply_until(res: Dictionary) -> void:
	CampaignClock.reset()
	TraitRuntime.clear_all()
	var m := _merc("Nell", 10, 8, 0, 0.0)
	m.perks.append(_trait("TEST Until None", "on:rest_start:always:apply:madness:until:none"))
	_respite(m)
	var mad: Dictionary = _src(m, ConstStates.MADNESS, 0)
	TestFixtures.check(res, "a trait until:none records a cause-only tier",
		ConstStates.get_count(m, ConstStates.MADNESS) == 1 and str(mad.get("kind", "")) == "trait"
		and str(mad.get("name", "")) == "TEST Until None" and _verbs(mad) == "cause",
		"tier %d source %s" % [ConstStates.get_count(m, ConstStates.MADNESS), _src_text(mad)])
	var f := _merc("Orla", 10, 8, 0, 0.0)
	f.perks.append(_trait("TEST Until Furlough", "on:rest_start:always:apply:fatigued:until:furlough"))
	var rested: Array[String] = _respite(f)
	var fat: Dictionary = _src(f, ConstStates.FATIGUED, 0)
	TestFixtures.check(res, "until:furlough records the furlough verb",
		ConstStates.get_count(f, ConstStates.FATIGUED) == 1 and _verbs(fat) == "furlough",
		"tier %d source %s lines %s" % [ConstStates.get_count(f, ConstStates.FATIGUED),
		_src_text(fat), str(rested)])
	var b := _merc("Pike", 10, 8, 0, 0.0)
	b.perks.append(_trait("TEST Until Bogus", "on:rest_start:always:apply:madness:until:bogus"))
	_respite(b)
	var odd: Dictionary = _src(b, ConstStates.MADNESS, 0)
	TestFixtures.check(res, "an unknown until still applies with the sheet verbs",
		ConstStates.get_count(b, ConstStates.MADNESS) == 1 and _verbs(odd) == "cause,furlough",
		"tier %d source %s" % [ConstStates.get_count(b, ConstStates.MADNESS), _src_text(odd)])
	var plain: Dictionary = StateTokens.parse_apply_token("apply:fatigued")
	var plain_states: Array = plain.get("states", [])
	TestFixtures.check(res, "a plain apply token has no duration and no until",
		plain_states.size() == 1 and plain_states.has(ConstStates.FATIGUED)
		and str(plain.get("duration", "?")) == "" and _join(plain.get("removal", [])) == ""
		and str(plain.get("error", "?")) == "", "parsed %s" % str(plain))
	var timed: Dictionary = StateTokens.parse_apply_token("apply:surprised:1:round")
	TestFixtures.check(res, "a duration tail reads as n unit",
		str(timed.get("duration", "")) == "1 round" and _join(timed.get("removal", [])) == ""
		and str(timed.get("error", "?")) == "", "parsed %s" % str(timed))
	var both: Dictionary = StateTokens.parse_apply_token("apply:surprised:1:round:until:respite")
	TestFixtures.check(res, "a duration and an until tail read together",
		str(both.get("duration", "")) == "1 round" and _join(both.get("removal", [])) == "respite"
		and str(both.get("error", "?")) == "", "parsed %s" % str(both))
	var none_tail: Dictionary = StateTokens.parse_apply_token("apply:surprised:until:none")
	TestFixtures.check(res, "until:none reads as the cause verb",
		_join(none_tail.get("removal", [])) == "cause" and str(none_tail.get("duration", "?")) == ""
		and str(none_tail.get("error", "?")) == "", "parsed %s" % str(none_tail))
	var broken: Dictionary = StateTokens.parse_apply_token("apply:surprised:1")
	TestFixtures.check(res, "a half duration is unreadable",
		str(broken.get("error", "")) == "unreadable duration", "parsed %s" % str(broken))
	var unknown: Dictionary = StateTokens.parse_apply_token("apply:surprised:until:never")
	TestFixtures.check(res, "an unknown until verb is reported",
		str(unknown.get("error", "")) == "unknown until"
		and _join(unknown.get("removal", [])) == "", "parsed %s" % str(unknown))


#Sources travel with the campaign snapshot a new encounter restores.
static func _case_snapshot(res: Dictionary) -> void:
	CampaignClock.reset()
	var m := _merc("Sable", 10, 8, 0, 0.0)
	ConstStates.apply_state(m, ConstStates.TERRIFIED)
	ConstStates.apply_state(m, ConstStates.MADNESS, null, ConstStates.TERRIFIED)
	ConstStates.apply_state(m, ConstStates.FATIGUED)
	var snap: Dictionary = StateCampaign.snapshot_campaign_states(m)
	var back := _merc("Sable", 10, 8, 0, 0.0)
	StateCampaign.restore_campaign_states(back, snap)
	TestFixtures.check(res, "the tier counts survive a snapshot",
		ConstStates.get_count(back, ConstStates.MADNESS) == 1
		and ConstStates.get_count(back, ConstStates.FATIGUED) == 1,
		"madness %d fatigued %d" % [ConstStates.get_count(back, ConstStates.MADNESS),
		ConstStates.get_count(back, ConstStates.FATIGUED)])
	var mad: Dictionary = _src(back, ConstStates.MADNESS, 0)
	TestFixtures.check(res, "the rooted Madness source survives a snapshot",
		str(mad.get("kind", "")) == "state" and str(mad.get("name", "")) == ConstStates.TERRIFIED
		and _verbs(mad) == "cause,furlough", "source %s" % _src_text(mad))
	var fat: Dictionary = _src(back, ConstStates.FATIGUED, 0)
	TestFixtures.check(res, "the direct Fatigued source survives a snapshot",
		str(fat.get("kind", "")) == "engine" and _verbs(fat) == "respite,furlough",
		"source %s" % _src_text(fat))


#Rest actions

static func _utility(kind: String, name: String) -> UtilityTraitData:
	var u := UtilityTraitData.new()
	u.utility_type = kind
	u.utility_name = name
	return u


static func _case_action_pools(res: Dictionary) -> void:
	CampaignClock.reset()
	var m := _merc("Poole", 10, 8, 4, 0.0)
	m.current_hp = 6
	m.current_ep = 5
	m.current_mp = 2
	TestFixtures.check(res, "Stretch clears one EP",
		RestActions.apply("Stretch", m) == "EP 5 -> 6" and m.current_ep == 6, "ep %d" % m.current_ep)
	TestFixtures.check(res, "Manifest clears one MP",
		RestActions.apply("Manifest", m) == "MP 2 -> 3" and m.current_mp == 3, "mp %d" % m.current_mp)
	TestFixtures.check(res, "Brief Meditation clears one HP",
		RestActions.apply("Brief Meditation", m) == "HP 6 -> 7" and m.current_hp == 7, "hp %d" % m.current_hp)
	TestFixtures.check(res, "Manifest waits on an MP feature",
		is_zero_approx(RestActions.score("Manifest", m)), "score %.2f" % RestActions.score("Manifest", m))
	var full := _merc("Fulla", 10, 8, 4, 0.0)
	TestFixtures.check(res, "a full pool pays nothing and scores nothing",
		RestActions.apply("Stretch", full) == "" and full.current_ep == 8
		and is_zero_approx(RestActions.score("Stretch", full)), "ep %d" % full.current_ep)


static func _case_action_realign(res: Dictionary) -> void:
	CampaignClock.reset()
	var m := TestFixtures.sheet_merc("Ali")
	m.max_ep_penalty = 3
	StatCalculator.refresh(m)
	var before: int = int(m.stats.get("maximum_endurance_points", 0))
	var detail: String = RestActions.apply("Realign", m)
	TestFixtures.check(res, "Realign lifts one point of the EP reduction",
		detail == "max EP reduction 3 -> 2" and m.max_ep_penalty == 2
		and int(m.stats.get("maximum_endurance_points", 0)) == before + 1,
		"detail %s penalty %d ep %d" % [detail, m.max_ep_penalty,
		int(m.stats.get("maximum_endurance_points", 0))])
	var tie := _merc("Tye", 10, 8, 4, 0.0)
	tie.max_hp_penalty = 2
	tie.max_ep_penalty = 2
	tie.max_mp_penalty = 2
	TestFixtures.check(res, "Realign takes HP first on a tie", RestActions.realign_target(tie) == "hp",
		"target %s" % RestActions.realign_target(tie))
	tie.max_hp_penalty = 0
	TestFixtures.check(res, "then EP", RestActions.realign_target(tie) == "ep",
		"target %s" % RestActions.realign_target(tie))
	tie.max_ep_penalty = 0
	TestFixtures.check(res, "then MP", RestActions.realign_target(tie) == "mp",
		"target %s" % RestActions.realign_target(tie))
	TestFixtures.check(res, "a reduction scores Realign",
		is_equal_approx(RestActions.score("Realign", tie), RestActions.REALIGN_SCORE),
		"score %.2f" % RestActions.score("Realign", tie))
	var clean := _merc("Clea", 10, 8, 4, 0.0)
	TestFixtures.check(res, "no reduction, no Realign",
		RestActions.realign_target(clean) == "" and is_zero_approx(RestActions.score("Realign", clean))
		and RestActions.apply("Realign", clean) == "", "target %s" % RestActions.realign_target(clean))


static func _case_action_respite(res: Dictionary) -> void:
	CampaignClock.reset()
	var m := _merc("Doze", 10, 8, 0, 0.0)
	ConstStates.apply_state(m, ConstStates.FATIGUED)
	TestFixtures.check(res, "Deep Sleep removes one Fatigued tier",
		RestActions.apply("Deep Sleep", m) == "Fatigued 1 -> 0"
		and ConstStates.get_count(m, ConstStates.FATIGUED) == 0,
		"tier %d" % ConstStates.get_count(m, ConstStates.FATIGUED))
	var deep := _merc("Deep", 10, 8, 0, 0.0)
	for _i: int in range(4):
		ConstStates.apply_state(deep, ConstStates.FATIGUED)
	var deep_lines: Array[String] = _respite(deep)
	TestFixtures.check(res, "a respite with four tiers drops one and Deep Sleep one more",
		ConstStates.get_count(deep, ConstStates.FATIGUED) == 2
		and TestFixtures.has_line(deep_lines, "Fatigued 4 -> 3") and TestFixtures.has_line(deep_lines, "Deep Sleep Fatigued 3 -> 2"),
		"tier %d lines %s" % [ConstStates.get_count(deep, ConstStates.FATIGUED), str(deep_lines)])
	var held := _merc("Hold", 10, 8, 0, 0.0)
	ConstStates.apply_state(held, ConstStates.TERRIFIED)
	ConstStates.apply_state(held, ConstStates.FATIGUED, null, ConstStates.TERRIFIED)
	TestFixtures.check(res, "an ongoing source scores Deep Sleep at zero",
		is_zero_approx(RestActions.score("Deep Sleep", held)),
		"score %.2f" % RestActions.score("Deep Sleep", held))
	var push := TestFixtures.sheet_merc("Pusha")
	var full_hp: int = int(push.stats.get("maximum_hit_points", 1))
	var full_ep: int = int(push.stats.get("maximum_endurance_points", 1))
	push.current_hp = 1
	var push_score: float = RestActions.score("Push Onward", push)
	var detail: String = RestActions.apply("Push Onward", push)
	TestFixtures.check(res, "Push Onward trades 2 maximum EP for full HP",
		detail == "max EP %d -> %d, HP 1 -> %d" % [full_ep, full_ep - RestActions.PUSH_EP_COST, full_hp]
		and push.max_ep_penalty == RestActions.PUSH_EP_COST
		and push.current_ep == full_ep - RestActions.PUSH_EP_COST and push.current_hp == full_hp,
		"detail %s ep %d hp %d" % [detail, push.current_ep, push.current_hp])
	TestFixtures.check(res, "Push Onward scores on the HP missing",
		is_equal_approx(push_score,
		float(full_hp - 1) * RestActions.PUSH_HP_WEIGHT - RestActions.PUSH_HP_OFFSET),
		"score %.2f" % push_score)
	var frail := _merc("Frail", 12, 3, 0, 0.0)
	frail.current_hp = 1
	TestFixtures.check(res, "a small EP pool blocks Push Onward",
		is_zero_approx(RestActions.score("Push Onward", frail)),
		"score %.2f" % RestActions.score("Push Onward", frail))
	var armored := _merc("Plate", 10, 8, 0, 0.0)
	armored.equipped_armor = ArmorData.new()
	armored.armor_break = 2
	TestFixtures.check(res, "Repair takes one point of Armor Break",
		RestActions.apply("Repair", armored) == "armor reduction 2 -> 1" and armored.armor_break == 1
		and is_equal_approx(RestActions.score("Repair", armored), RestActions.REPAIR_SCORE),
		"break %d" % armored.armor_break)
	var unarmored := _merc("Plain", 10, 8, 0, 0.0)
	unarmored.armor_break = 2
	TestFixtures.check(res, "no armor, no Repair",
		is_zero_approx(RestActions.score("Repair", unarmored)),
		"score %.2f" % RestActions.score("Repair", unarmored))


static func _case_action_furlough(res: Dictionary) -> void:
	CampaignClock.reset()
	var m := _merc("Excy", 12, 8, 4, 0.0)
	TestFixtures.check(res, "Meditate banks 2 excess HP",
		RestActions.apply("Meditate", m) == "excess HP 0 -> 2" and m.excess_hp == 2,
		"excess %d" % m.excess_hp)
	TestFixtures.check(res, "Relax banks 1 excess EP",
		RestActions.apply("Relax", m) == "excess EP 0 -> 1" and m.excess_ep == 1,
		"excess %d" % m.excess_ep)
	TestFixtures.check(res, "Prepare banks 1 excess MP",
		RestActions.apply("Prepare", m) == "excess MP 0 -> 1" and m.excess_mp == 1,
		"excess %d" % m.excess_mp)
	m.excess_ep = ExcessPool.CAP
	TestFixtures.check(res, "a capped excess pool pays nothing",
		RestActions.apply("Relax", m) == "" and is_zero_approx(RestActions.score("Relax", m)),
		"excess %d" % m.excess_ep)
	var fur := _merc("Furla", 12, 8, 4, 0.0)
	fur.max_hp_penalty = 1
	fur.max_ep_penalty = 2
	fur.max_mp_penalty = 1
	fur.circumstance_flags[ConstCircumstances.ATTACK_DEXTERITY] = true
	fur.excess_hp = ExcessPool.CAP
	fur.excess_ep = ExcessPool.CAP
	StatCalculator.prime(fur)
	StatCalculator.refresh(fur)
	RestActions.apply("Train", fur)
	var lines: Array[String] = _furlough(fur)
	TestFixtures.check(res, "a furlough restores every maximum",
		fur.max_hp_penalty == 0 and fur.max_ep_penalty == 0 and fur.max_mp_penalty == 0
		and TestFixtures.has_line(lines, "max EP restored") and TestFixtures.has_line(lines, "max MP restored"),
		"hp %d ep %d mp %d lines %s" % [fur.max_hp_penalty, fur.max_ep_penalty, fur.max_mp_penalty,
		str(lines)])
	TestFixtures.check(res, "a furlough ends the training it granted and trains once more",
		TestFixtures.has_line(lines, "training ended (%s)" % ConstCircumstances.ATTACK_DEXTERITY)
		and fur.trained_bonus.size() == 1
		and is_equal_approx(float(fur.circumstance_additional_bonus.get(
		ConstCircumstances.ATTACK_DEXTERITY, 0.0)), RestActions.TRAIN_PERCENT),
		"bonus %s lines %s" % [str(fur.circumstance_additional_bonus), str(lines)])


static func _case_action_training(res: Dictionary) -> void:
	CampaignClock.reset()
	CheckSystem.forced_rolls.clear()
	GuildRoster.reset()
	var m := _merc("Trainee", 10, 8, 0, 0.0)
	m.stats["dexterity"] = 1
	m.circumstance_flags[ConstCircumstances.ATTACK_DEXTERITY] = true
	var def: Dictionary = {"stat_keys": ["dexterity"], "formula": "0",
		"circumstances": [ConstCircumstances.ATTACK_DEXTERITY]}
	CheckSystem.forced_rolls.assign([10])
	var plain: Dictionary = CheckSystem.make_check(m, def)
	var detail: String = RestActions.apply("Train", m)
	CheckSystem.forced_rolls.assign([10])
	var trained: Dictionary = CheckSystem.make_check(m, def)
	TestFixtures.check(res, "training a Circumstance adds 7 to the threshold",
		detail == "%s +7%%" % ConstCircumstances.ATTACK_DEXTERITY
		and is_equal_approx(float(trained["threshold"]) - float(plain["threshold"]),
		RestActions.TRAIN_PERCENT),
		"detail %s plain %.2f trained %.2f" % [detail, float(plain["threshold"]),
		float(trained["threshold"])])
	TestFixtures.check(res, "a real check counts the Circumstance use",
		int(m.use_counts.get("circumstance:" + ConstCircumstances.ATTACK_DEXTERITY, 0)) == 2,
		"counts %s" % str(m.use_counts))
	var sage := _merc("Sage", 10, 8, 0, 0.0)
	sage.stats["dexterity"] = 1
	sage.knowledges.append(_utility("Knowledge", "Toxicology"))
	sage.tools.append(_utility("Tool", "Alchemist's Kit"))
	var kdef: Dictionary = {"stat_keys": ["dexterity"], "formula": "0",
		"knowledges": ["Toxicology"], "tools": ["Alchemist's"]}
	CheckSystem.forced_rolls.assign([10])
	var owned: Dictionary = CheckSystem.make_check(sage, kdef)
	TestFixtures.check(res, "an owned Knowledge and Tool each give one die",
		int(owned["k_bonus"]) == 1 and int(owned["t_bonus"]) == 1,
		"k %d t %d" % [int(owned["k_bonus"]), int(owned["t_bonus"])])
	sage.trained_bonus["knowledge:Toxicology"] = 1
	sage.trained_bonus["tool:Alchemist's Kit"] = 1
	CheckSystem.forced_rolls.assign([10])
	var doubled: Dictionary = CheckSystem.make_check(sage, kdef)
	TestFixtures.check(res, "training doubles the Knowledge and Tool dice",
		int(doubled["k_bonus"]) == 2 and int(doubled["t_bonus"]) == 2,
		"k %d t %d" % [int(doubled["k_bonus"]), int(doubled["t_bonus"])])
	CheckSystem.forced_rolls.clear()
	var unnamed: Dictionary = CheckSystem.make_check(sage, {"stat_keys": ["dexterity"], "formula": "0"})
	TestFixtures.check(res, "a check naming neither gains nothing",
		int(unnamed["k_bonus"]) == 0 and int(unnamed["t_bonus"]) == 0,
		"k %d t %d" % [int(unnamed["k_bonus"]), int(unnamed["t_bonus"])])
	var counted: int = int(sage.use_counts.get("knowledge:Toxicology", 0))
	CheckSystem.expected_success_chance(sage, kdef, 1)
	TestFixtures.check(res, "the estimator never counts a use",
		counted == 2 and int(sage.use_counts.get("knowledge:Toxicology", 0)) == 2,
		"counts %s" % str(sage.use_counts))
	var scout := _merc("Scout", 10, 8, 0, 0.0)
	scout.knowledges.append(_utility("Knowledge", "Reconnaissance"))
	var ranger := _merc("Ranger", 10, 8, 0, 0.0)
	ranger.knowledges.append(_utility("Knowledge", "Reconnaissance"))
	var solo: Array[MercenaryData] = [scout]
	GuildRoster.set_roster(solo)
	var alone: float = RestActions.train_score(scout, "knowledge:Reconnaissance")
	var both: Array[MercenaryData] = [scout, ranger]
	GuildRoster.set_roster(both)
	var shared: float = RestActions.train_score(scout, "knowledge:Reconnaissance")
	TestFixtures.check(res, "GuildRoster counts the other holders",
		GuildRoster.holders("knowledge:Reconnaissance", scout) == 1
		and GuildRoster.holders("knowledge:Reconnaissance", ranger) == 1,
		"holders %d" % GuildRoster.holders("knowledge:Reconnaissance", scout))
	TestFixtures.check(res, "a second holder drops the unique term",
		RestActions.demand("knowledge:Reconnaissance") > 0.0
		and is_equal_approx(alone - shared, RestActions.TRAIN_UNIQUE_WEIGHT),
		"alone %.2f shared %.2f demand %.2f" % [alone, shared,
		RestActions.demand("knowledge:Reconnaissance")])
	TestFixtures.check(res, "a Secondary event feeds the demand table",
		RestActions.demand("knowledge:Salesmanship") > 0.0,
		"demand %.2f" % RestActions.demand("knowledge:Salesmanship"))
	GuildRoster.reset()
	CheckSystem.forced_rolls.clear()


static func _case_action_picker(res: Dictionary) -> void:
	CampaignClock.reset()
	var br := _merc("Bree", 10, 8, 0, 0.0)
	br.current_ep = 4
	br.max_hp_penalty = 1
	var lines: Array[String] = []
	RestActions.take(RestSystem.KIND_BREATHER, br, lines)
	TestFixtures.check(res, "a breather Realign outranks Stretch",
		lines.size() == 1 and lines[0].begins_with(
		"REST ACTION: Bree breather Realign max HP reduction 1 -> 0 [")
		and lines[0].contains("Take Watch todo"), "lines %s" % str(lines))
	var idle := _merc("Idle", 10, 8, 0, 0.0)
	var idle_lines: Array[String] = []
	RestActions.take(RestSystem.KIND_BREATHER, idle, idle_lines)
	TestFixtures.check(res, "an untouched merc takes no rest action",
		RestActions.choose(RestSystem.KIND_BREATHER, idle) == ""
		and TestFixtures.has_line(idle_lines, "REST ACTION: Idle breather none"), "lines %s" % str(idle_lines))
	var rp := _merc("Rest", 10, 8, 0, 0.0)
	ConstStates.apply_state(rp, ConstStates.FATIGUED)
	TestFixtures.check(res, "a respite picks Deep Sleep first",
		RestActions.choose(RestSystem.KIND_RESPITE, rp) == "Deep Sleep",
		"picked %s" % RestActions.choose(RestSystem.KIND_RESPITE, rp))
	var fu := _merc("Feast", 12, 8, 0, 0.0)
	TestFixtures.check(res, "a furlough with nothing to train picks Meditate",
		RestActions.choose(RestSystem.KIND_FURLOUGH, fu) == "Meditate",
		"picked %s" % RestActions.choose(RestSystem.KIND_FURLOUGH, fu))
	TestFixtures.check(res, "a todo action never scores",
		RestActions.is_todo("Take Watch") and RestActions.is_todo("Repute")
		and is_zero_approx(RestActions.score("Take Watch", rp))
		and is_zero_approx(RestActions.score("Repute", rp)), "a todo action scored")
	var skip := _merc("Skip", 10, 8, 0, 0.0)
	skip.current_ep = 7
	var skip_lines: Array[String] = RestSystem.breather(skip, null)
	TestFixtures.check(res, "a skipped breather takes no rest action",
		not TestFixtures.has_line(skip_lines, "REST ACTION"), "lines %s" % str(skip_lines))
