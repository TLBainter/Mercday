class_name GuiViewTests

#The GUI view models: GuiTypes, MercView, ContractView, the sample loader and the run resources.
#Run: the headless harness flag gui-view-tests, after the bare argument separator.
#Every case clears the roster and the campaign tallies first, so the suite is order independent.

const SAMPLE_PATH: String = "res://Resources/GUI/sample_data.json"
const SAMPLE_MERCS: int = 10
const SAMPLE_CONTRACTS: int = 12
const SAMPLE_BANK: int = 1000


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	ContractResourceBuilder.build_all()
	_case_gui_types(res)
	_case_merc_view(res)
	_case_relationships(res)
	_case_relationship_dates(res)
	_case_contract_view(res)
	_case_local_view(res)
	_case_check_row_lists(res)
	_case_entry_status(res)
	_case_sample_data(res)
	_case_run_resources(res)
	_reset()
	return TestFixtures.summarize(res, "GuiView")


static func _reset() -> void:
	GuildRoster.reset()
	TestFixtures.reset_campaign()


static func _case_gui_types(res: Dictionary) -> void:
	TestFixtures.check(res, "seven roles with the leader first and Investigator last",
		GuiTypes.ROLES.size() == 7 and GuiTypes.ROLES[0] == "Leader" and GuiTypes.ROLES.back() == "Investigator",
		"got %d roles starting %s" % [GuiTypes.ROLES.size(), str(GuiTypes.ROLES.slice(0, 1))])
	var foot: Dictionary = GuiTypes.travel_mode("foot")
	TestFixtures.check(res, "six travel modes with the foot row intact",
		GuiTypes.TRAVEL_MODES.size() == 6 and int(foot.get("km_per_day", 0)) == 30
			and int(foot.get("rate", 0)) == 1 and bool(foot.get("per_merc", false)),
		"got %d modes, foot %s" % [GuiTypes.TRAVEL_MODES.size(), str(foot)])
	TestFixtures.check(res, "the teleport row takes no travel time",
		int(GuiTypes.travel_mode("teleport").get("km_per_day", -1)) == 0,
		"got %s" % str(GuiTypes.travel_mode("teleport").get("km_per_day", -1)))
	TestFixtures.check(res, "difficulty names run cakewalk to impossible",
		GuiTypes.difficulty_name(0.5) == "Cakewalk" and GuiTypes.difficulty_name(3.0) == "Average"
			and GuiTypes.difficulty_name(5.0) == "Impossible",
		"got %s, %s, %s" % [GuiTypes.difficulty_name(0.5), GuiTypes.difficulty_name(3.0),
			GuiTypes.difficulty_name(5.0)])
	TestFixtures.check(res, "difficulty snaps to the nearest half step",
		GuiTypes.difficulty_name(2.6) == "Manageable" and GuiTypes.difficulty_name(9.0) == "Impossible",
		"got %s and %s" % [GuiTypes.difficulty_name(2.6), GuiTypes.difficulty_name(9.0)])
	TestFixtures.check(res, "every half step has a difficulty color",
		GuiTypes.DIFFICULTY_COLORS.size() == 10 and GuiTypes.MATCH_COLORS.size() == 10,
		"got %d difficulty and %d match colors" % [GuiTypes.DIFFICULTY_COLORS.size(),
			GuiTypes.MATCH_COLORS.size()])
	TestFixtures.check(res, "the match ramp runs red to green",
		GuiTypes.match_color(0.5) == Color("#e8583f") and GuiTypes.match_color(5.0) == Color("#3fae5a"),
		"got %s and %s" % [str(GuiTypes.match_color(0.5)), str(GuiTypes.match_color(5.0))])
	TestFixtures.check(res, "contract status text",
		GuiTypes.status_text(GuiTypes.ContractStatus.AVAILABLE) == "Available"
			and GuiTypes.status_text(GuiTypes.ContractStatus.COMPLETED) == "Completed",
		"got %s and %s" % [GuiTypes.status_text(GuiTypes.ContractStatus.AVAILABLE),
			GuiTypes.status_text(GuiTypes.ContractStatus.COMPLETED)])
	TestFixtures.check(res, "merc status text names the contract state",
		GuiTypes.merc_status_text(GuiTypes.MercStatus.CONTRACT) == "On a Contract",
		"got %s" % GuiTypes.merc_status_text(GuiTypes.MercStatus.CONTRACT))
	TestFixtures.check(res, "an unknown tradition falls back to the muted color",
		GuiTypes.tradition_color("Nobody") == GuiTypes.FALLBACK_COLOR
			and GuiTypes.tradition_color("Mystech") == Color("#3fc9c0"),
		"got %s" % str(GuiTypes.tradition_color("Nobody")))
	TestFixtures.check(res, "urgency colours run green, orange, red",
		GuiTypes.URGENCY_COLORS[GuiTypes.Urgency.NONE] == Color("#6cc36a")
			and GuiTypes.URGENCY_COLORS[GuiTypes.Urgency.LOW] == Color("#f28c28")
			and GuiTypes.URGENCY_COLORS[GuiTypes.Urgency.HIGH] == Color("#e8583f"),
		"got %s, %s, %s" % [str(GuiTypes.urgency_color(GuiTypes.Urgency.NONE)),
			str(GuiTypes.urgency_color(GuiTypes.Urgency.LOW)),
			str(GuiTypes.urgency_color(GuiTypes.Urgency.HIGH))])


static func _case_merc_view(res: Dictionary) -> void:
	_reset()
	var merc: MercenaryData = _generate_merc(6)
	if merc == null:
		TestFixtures.check(res, "a merc generates for the view", false, "MercGenerator returned null")
		return
	GuildRoster.set_roster([merc] as Array[MercenaryData])
	SalarySystem.hire(merc, [] as Array[MercenaryData], 1920)
	if merc.lifepaths.is_empty():
		var seeded: Array[String] = []
		if not merc.perks.is_empty():
			seeded.append(merc.perks[0].trait_name)
		merc.lifepaths.append(_lifepath("Test", "Test Event", "A test event", seeded))
	var view: MercView = MercView.from_merc(merc, GuiTypes.MercStatus.RESTING, 7.5, 3,
		{"level_mode": "Offensive"})
	TestFixtures.check(res, "identity comes off the merc",
		view.merc == merc and view.uid == merc.merc_uid and view.name == merc.merc_name,
		"uid %d name %s" % [view.uid, view.name])
	TestFixtures.check(res, "level reads the experience system",
		view.level == ExperienceSystem.current_level(merc) and view.level == 6,
		"expected 6, got %d" % view.level)
	TestFixtures.check(res, "tradition and heritage are names, not resources",
		view.tradition == (merc.tradition.tradition_name if merc.tradition != null else "")
			and view.heritage == (merc.heritage.heritage_name if merc.heritage != null else ""),
		"tradition %s heritage %s" % [view.tradition, view.heritage])
	TestFixtures.check(res, "the salary and opinion come from the hire",
		view.monthly_salary == merc.monthly_salary and view.guild_opinion == merc.guild_opinion
			and view.monthly_salary >= 1,
		"salary %d opinion %d" % [view.monthly_salary, view.guild_opinion])
	TestFixtures.check(res, "the caller supplies the status and the months",
		view.status == GuiTypes.MercStatus.RESTING and is_equal_approx(view.status_time_left_hours, 7.5)
			and view.employment_months == 3,
		"status %d hours %s months %d" % [view.status, str(view.status_time_left_hours),
			view.employment_months])
	TestFixtures.check(res, "the level mode placeholder reads the extras",
		view.level_mode == "Offensive", "got %s" % view.level_mode)
	TestFixtures.check(res, "knowledges and tools are utility names",
		view.knowledges.size() == merc.knowledges.size() and view.tools.size() == merc.tools.size(),
		"%d knowledges, %d tools" % [view.knowledges.size(), view.tools.size()])
	TestFixtures.check(res, "the three pools carry their maxima",
		view.hp_max == int(merc.stats.get("maximum_hit_points", 0)) and view.hp_max > 0
			and view.ep_max == int(merc.stats.get("maximum_endurance_points", 0))
			and view.mp_max == int(merc.stats.get("maximum_magic_points", 0)),
		"hp %d/%d ep %d/%d mp %d/%d" % [view.hp, view.hp_max, view.ep, view.ep_max, view.mp,
			view.mp_max])
	var attrs_ok: bool = view.attributes.size() == 4
	for key: String in MercView.ATTRIBUTE_KEYS:
		var pair: Dictionary = view.attributes.get(key, {}) as Dictionary
		if int(pair.get("current", -1)) != int(merc.stats.get(key, 0)):
			attrs_ok = false
		if int(pair.get("max", -1)) != int(merc.max_stats.get("max_" + key, 0)):
			attrs_ok = false
	TestFixtures.check(res, "the four attributes carry the current value and the maximum", attrs_ok,
		"got %s" % str(view.attributes))
	TestFixtures.check(res, "traits list the perks, drawbacks and descriptors",
		view.traits.size() == merc.perks.size() + merc.drawbacks.size() + merc.descriptors.size(),
		"expected %d, got %d" % [merc.perks.size() + merc.drawbacks.size() + merc.descriptors.size(),
			view.traits.size()])
	TestFixtures.check(res, "perks, drawbacks and descriptors are rows in merc order",
		_rows_match(view.perks, merc.perks) and _rows_match(view.drawbacks, merc.drawbacks)
			and _rows_match(view.descriptors, merc.descriptors),
		"%d perks, %d drawbacks, %d descriptors" % [view.perks.size(), view.drawbacks.size(),
			view.descriptors.size()])
	TestFixtures.check(res, "the skills list is an empty placeholder", view.skills.is_empty(),
		"got %d rows" % view.skills.size())
	TestFixtures.check(res, "lifepath chips follow the merc's events",
		_chips_match(view.lifepaths, merc.lifepaths),
		"%d chips for %d events" % [view.lifepaths.size(), merc.lifepaths.size()])
	var credited: String = _first_credited_perk(merc)
	TestFixtures.check(res, "acquired names the lifepath that gave the perk",
		_acquired_ok(view, merc, credited),
		"credited %s" % ("none" if credited == "" else credited))
	_check_action_uses(res, view, merc)
	TestFixtures.check(res, "the weight bar reads the encumbrance system",
		is_equal_approx(view.weight, float(Encumbrance.carried_weight(merc)))
			and is_equal_approx(view.weight_limit, float(Encumbrance.weight_limit(merc)))
			and view.weight_limit >= 0.0,
		"%s of %s" % [str(view.weight), str(view.weight_limit)])
	var carried: int = int(merc.stats.get("weight_limit", 0))
	merc.stats["weight_limit"] = 40
	var loaded: MercView = MercView.from_merc(merc, GuiTypes.MercStatus.RESTING, 7.5, 3,
		{"level_mode": "Offensive"})
	TestFixtures.check(res, "a merc with a weight limit reads it on the bar",
		is_equal_approx(loaded.weight_limit, 40.0)
			and is_equal_approx(loaded.weight, float(Encumbrance.carried_weight(merc))),
		"%s of %s" % [str(loaded.weight), str(loaded.weight_limit)])
	merc.stats["weight_limit"] = carried
	TestFixtures.check(res, "held gear leads the equipment list", _equipment_ok(merc, view.equipment),
		"got %s" % str(view.equipment.slice(0, 3)))
	TestFixtures.check(res, "xp comes across", view.xp == merc.xp, "expected %d, got %d" % [merc.xp,
		view.xp])
	var empty: MercView = MercView.from_merc(null, GuiTypes.MercStatus.AVAILABLE, 0.0, 0)
	TestFixtures.check(res, "a null merc builds an empty view",
		empty.merc == null and empty.uid == 0 and empty.name == "", "uid %d" % empty.uid)
	for i: int in range(9):
		merc.lifepaths.append(_lifepath("Test", "Filler %d" % i, "A filler event",
			[] as Array[String]))
	var capped: MercView = MercView.from_merc(merc, GuiTypes.MercStatus.RESTING, 7.5, 3)
	TestFixtures.check(res, "the chips stop at the lifepath cap",
		capped.lifepaths.size() == LifepathProgression.MAX_EVENTS,
		"%d chips for %d events" % [capped.lifepaths.size(), merc.lifepaths.size()])


static func _case_relationships(res: Dictionary) -> void:
	_reset()
	var cases: Array[Array] = [[-1, 0], [0, 0], [2, 0], [3, 1], [4, 1], [5, 2], [7, 2], [8, 3],
		[9, 3], [10, 4]]
	var bad: Array[String] = []
	for c: Array in cases:
		if MercView.relationship_face(int(c[0])) != int(c[1]):
			bad.append("%d gave %d" % [int(c[0]), MercView.relationship_face(int(c[0]))])
	TestFixtures.check(res, "the face is the highest threshold reached", bad.is_empty(),
		TestFixtures.detail(bad, cases.size(), "values"))
	var a: MercenaryData = _uid_merc("Ada")
	var b: MercenaryData = _uid_merc("Bel")
	var c_merc: MercenaryData = _uid_merc("Cyd")
	GuildRoster.set_roster([a, b, c_merc] as Array[MercenaryData])
	CampaignKnowledge.set_relation(a.merc_uid, b.merc_uid, 9)
	var view: MercView = MercView.from_merc(a, GuiTypes.MercStatus.AVAILABLE, 0.0, 0)
	TestFixtures.check(res, "only stored pairs are listed",
		view.relationships.size() == 1 and int(view.relationships.get(b.merc_uid, -1)) == 9,
		"got %s" % str(view.relationships))
	TestFixtures.check(res, "a stored pair reads its own face",
		view.face_for(b.merc_uid) == 3, "expected 3, got %d" % view.face_for(b.merc_uid))
	TestFixtures.check(res, "a pair with no value reads as neutral",
		view.face_for(c_merc.merc_uid) == MercView.relationship_face(MercView.NEUTRAL_RELATION),
		"expected %d, got %d" % [MercView.relationship_face(MercView.NEUTRAL_RELATION),
			view.face_for(c_merc.merc_uid)])
	_reset()


#The two campaign day stamps every stored relation carries. This suite runs without a host, so the
#days are moved on CampaignClock directly instead of waiting on GameState, and the clock is put
#back at the end.
static func _case_relationship_dates(res: Dictionary) -> void:
	_reset()
	CampaignClock.reset()
	var a: MercenaryData = _uid_merc("Ada")
	var b: MercenaryData = _uid_merc("Bel")
	GuildRoster.set_roster([a, b] as Array[MercenaryData])
	CampaignClock.advance(CampaignClock.MINUTES_PER_DAY * 2)
	CampaignKnowledge.set_relation(a.merc_uid, b.merc_uid, 4)
	TestFixtures.check(res, "the first write stamps both days with the campaign day",
		CampaignKnowledge.relation_known_since(a.merc_uid, b.merc_uid) == 2
			and CampaignKnowledge.relation_last_changed(a.merc_uid, b.merc_uid) == 2,
		"known %d changed %d" % [CampaignKnowledge.relation_known_since(a.merc_uid, b.merc_uid),
			CampaignKnowledge.relation_last_changed(a.merc_uid, b.merc_uid)])
	CampaignClock.advance(CampaignClock.MINUTES_PER_DAY * 3)
	CampaignKnowledge.set_relation(a.merc_uid, b.merc_uid, 4)
	TestFixtures.check(res, "rewriting the same value leaves the change day where it was",
		CampaignKnowledge.relation_known_since(a.merc_uid, b.merc_uid) == 2
			and CampaignKnowledge.relation_last_changed(a.merc_uid, b.merc_uid) == 2,
		"known %d changed %d" % [CampaignKnowledge.relation_known_since(a.merc_uid, b.merc_uid),
			CampaignKnowledge.relation_last_changed(a.merc_uid, b.merc_uid)])
	CampaignKnowledge.set_relation(a.merc_uid, b.merc_uid, 7)
	TestFixtures.check(res, "a new value moves the change day and keeps the opening day",
		CampaignKnowledge.relation_known_since(a.merc_uid, b.merc_uid) == 2
			and CampaignKnowledge.relation_last_changed(a.merc_uid, b.merc_uid) == 5,
		"known %d changed %d" % [CampaignKnowledge.relation_known_since(a.merc_uid, b.merc_uid),
			CampaignKnowledge.relation_last_changed(a.merc_uid, b.merc_uid)])
	var view: MercView = MercView.from_merc(a, GuiTypes.MercStatus.AVAILABLE, 0.0, 0)
	TestFixtures.check(res, "the view carries both stamps for the stored pair alone",
		view.relationship_known_since.size() == 1
			and int(view.relationship_known_since.get(b.merc_uid, -1)) == 2
			and int(view.relationship_last_changed.get(b.merc_uid, -1)) == 5,
		"known %s changed %s" % [str(view.relationship_known_since),
			str(view.relationship_last_changed)])
	CampaignKnowledge.forget(b.merc_uid)
	TestFixtures.check(res, "forgetting a merc drops both of its stamps",
		CampaignKnowledge.relation_known_since(a.merc_uid, b.merc_uid) == -1
			and CampaignKnowledge.relation_last_changed(a.merc_uid, b.merc_uid) == -1,
		"known %d changed %d" % [CampaignKnowledge.relation_known_since(a.merc_uid, b.merc_uid),
			CampaignKnowledge.relation_last_changed(a.merc_uid, b.merc_uid)])
	CampaignClock.reset()
	_reset()


static func _case_contract_view(res: Dictionary) -> void:
	_reset()
	if ContractLibrary.contract_type_names().is_empty():
		TestFixtures.check(res, "contract types are on disk", false, "no .tres in Resources/Contracts")
		return
	var contract: ContractData = ContractGenerator.generate()
	if contract == null:
		TestFixtures.check(res, "a contract generates for the view", false, "generate returned null")
		return
	var entry := BoardEntry.new()
	entry.id = 4
	entry.contract = contract
	entry.posted_minute = 0
	entry.expires_minute = 60 * 30
	entry.distance_km = 48
	entry.completion_hours = 12
	entry.issuer = "Issuer 1 Name"
	entry.issuer_type = "place"
	entry.merc_min = 2
	entry.image = "placeholder"
	entry.status = "Draft"
	var view: ContractView = ContractView.from_entry(entry, 0)
	TestFixtures.check(res, "the entry id and the placeholders come off the entry",
		view.entry_id == 4 and view.distance_km == 48 and view.completion_hours == 12
			and view.issuer == "Issuer 1 Name" and view.issuer_type == "place" and view.image == "placeholder",
		"id %d distance %d issuer %s" % [view.entry_id, view.distance_km, view.issuer])
	TestFixtures.check(res, "the name is the row's Contract Name, with no place",
		view.name == (contract.contract_name if contract.contract_name != "" else contract.contract_type)
			and view.location == contract.location_a,
		"got %s" % view.name)
	var probe := ContractData.new()
	probe.contract_name = "TEST Named"
	probe.contract_type = "TEST Kind"
	probe.location_a = "Rossade"
	TestFixtures.check(res, "a posting is titled by its Contract Name",
		ContractView.posting_title(probe) == "TEST Named", "got %s" % ContractView.posting_title(probe))
	probe.contract_name = ""
	TestFixtures.check(res, "a row with no name is titled by its type, and no row gets a place",
		ContractView.posting_title(probe) == "TEST Kind" and ContractView.posting_title(null) == "",
		"got %s" % ContractView.posting_title(probe))
	var named := BoardEntry.new()
	probe.contract_name = "TEST Named"
	named.contract = probe
	TestFixtures.check(res, "the entry name is the posting title",
		GameState.entry_name(named) == "TEST Named", "got %s" % GameState.entry_name(named))
	TestFixtures.check(res, "the level, difficulty and reward come off the contract",
		view.contract == contract and view.contract_level == contract.contract_level
			and view.contract_level >= 1 and is_equal_approx(view.difficulty, contract.difficulty)
			and view.reward == contract.reward_notes,
		"level %d difficulty %s reward %d" % [view.contract_level, str(view.difficulty), view.reward])
	TestFixtures.check(res, "the crew band holds the minimum and the cap of five",
		view.merc_min == 2 and view.merc_max >= view.merc_min and view.merc_max <= ContractView.MERC_CAP,
		"%d to %d" % [view.merc_min, view.merc_max])
	TestFixtures.check(res, "hours left and urgency come from the expiry",
		is_equal_approx(view.expires_in_hours, 30.0) and view.urgency == GuiTypes.Urgency.LOW,
		"%s hours, urgency %d" % [str(view.expires_in_hours), view.urgency])
	TestFixtures.check(res, "a draft entry reads as available with no outcome",
		view.status == GuiTypes.ContractStatus.AVAILABLE and view.outcome == "",
		"status %d outcome %s" % [view.status, view.outcome])
	TestFixtures.check(res, "the recommended lists sort by the hidden bonus",
		_sorted_desc(view.recommended_knowledges) and _sorted_desc(view.recommended_tools)
			and _sorted_desc(view.recommended_traditions),
		"%d knowledges, %d tools, %d traditions" % [view.recommended_knowledges.size(),
			view.recommended_tools.size(), view.recommended_traditions.size()])
	TestFixtures.check(res, "the boosts fill the recommended lists",
		_list_matches(view.recommended_knowledges, contract.knowledge_boosts, contract, "knowledges")
			and _list_matches(view.recommended_traditions, contract.tradition_boosts, contract, "traditions"),
		"expected %d and %d" % [contract.knowledge_boosts.size(), contract.tradition_boosts.size()])
	var empty: ContractView = ContractView.from_entry(null, 0)
	TestFixtures.check(res, "a null entry builds an empty view",
		empty.contract == null and empty.entry_id == -1, "entry_id %d" % empty.entry_id)


#Card 736: ContractView.local follows the ContractData and the sample key "local", false by default.
static func _case_local_view(res: Dictionary) -> void:
	var data := ContractData.new()
	data.contract_name = "TEST Local"
	data.local = true
	var near: ContractView = ContractView.from_entry(_entry_for(data), 0)
	var plain := ContractData.new()
	plain.contract_name = "TEST Away"
	var away: ContractView = ContractView.from_entry(_entry_for(plain), 0)
	var sample_on: ContractView = ContractView.from_sample({"local": true})
	var sample_off: ContractView = ContractView.from_sample({})
	TestFixtures.check(res, "card736_view_local", near.local and not away.local and sample_on.local
		and not sample_off.local and not ContractView.new().local,
		"entry %s, plain %s, sample %s, sample default %s" % [near.local, away.local, sample_on.local,
			sample_off.local])


static func _case_check_row_lists(res: Dictionary) -> void:
	_reset()
	CheckStore.reset()
	var row: Dictionary = {}
	for key: String in CheckSheet.HEADER:
		row[key] = ""
	row[CheckSheet.HEADER[CheckSheet.NAME]] = "Get Cat from Tree"
	row[CheckSheet.HEADER[CheckSheet.ATTRIBUTES]] = "Dexterity, Wile"
	row[CheckSheet.HEADER[CheckSheet.CIRCUMSTANCES]] = (
		"Finesse (Dexterity) 0, Grace (Dexterity) 0, Intuition (Wile) 0, Presence (Wile) 0")
	row[CheckSheet.HEADER[CheckSheet.KNOWLEDGES]] = (
		"Diplomacy 10, Hunting 5, Psychology 5, Salesmanship 5, Tactics 5, Zoology 15")
	row[CheckSheet.HEADER[CheckSheet.TOOLS]] = "Scout's 5, Survivalist's 5, Tracker's 10, Trapper's 15"
	row[CheckSheet.HEADER[CheckSheet.TRADITIONS]] = ("Brave -5, Chymist +5, Divine +5, Hellion +15, Honorable +5, "
		+ "Mage -5, Mystech -15, Performer +15, Sorcerer -15, Warrior -10")
	var rows: Array[Dictionary] = [row]
	CheckStore.test_rows.assign(rows)
	var data := ContractData.new()
	data.style = "check"
	data.completion = "check:Get Cat from Tree"
	var view: ContractView = ContractView.from_entry(_entry_for(data), 0)
	var knowledges: Array[String] = _entry_names(view.recommended_knowledges)
	TestFixtures.check(res, "#721 empty contract knowledges fill from the Checks.tsv row, Zoology first",
		knowledges == ["Zoology", "Diplomacy", "Hunting", "Psychology", "Salesmanship", "Tactics"]
			and view.recommended_knowledges[0].hidden_bonus == 15 and _sorted_desc(view.recommended_knowledges),
		"got %s" % str(knowledges))
	var tools: Array[String] = _entry_names(view.recommended_tools)
	TestFixtures.check(res, "#721 empty contract tools fill from the row with the short names, Trapper's first",
		tools == ["Trapper's", "Tracker's", "Scout's", "Survivalist's"]
			and view.recommended_tools[0].hidden_bonus == 15 and _sorted_desc(view.recommended_tools),
		"got %s" % str(tools))
	var traditions: Array[String] = _entry_names(view.recommended_traditions)
	TestFixtures.check(res, "#721 the row fills traditions with positive values only",
		traditions == ["Hellion", "Performer", "Chymist", "Divine", "Honorable"]
			and view.recommended_traditions[0].hidden_bonus == 15
			and view.recommended_traditions.back().hidden_bonus == 5,
		"got %s" % str(traditions))
	var circumstances: Array[String] = []
	for entry: Dictionary in CheckStore.parse(row)["circumstances"]:
		circumstances.append(String(entry.get("name", "")))
	var leaked: Array[String] = []
	for names: Array in [knowledges, tools, traditions]:
		for name: String in names:
			if circumstances.has(name):
				leaked.append(name)
	TestFixtures.check(res, "#721 circumstances are not shown in any list",
		circumstances.size() == 4 and leaked.is_empty(),
		"%d circumstances, leaked %s" % [circumstances.size(), str(leaked)])
	data.knowledge_boosts = {"TEST Lore": 10}
	var own: ContractView = ContractView.from_entry(_entry_for(data), 0)
	TestFixtures.check(res, "#721 contract knowledge boosts win and the empty lists still fill per list",
		_entry_names(own.recommended_knowledges) == ["TEST Lore"] and own.recommended_tools.size() == 4
			and own.recommended_traditions.size() == 5,
		"got %s, %d tools" % [str(_entry_names(own.recommended_knowledges)), own.recommended_tools.size()])
	var event := ContractData.new()
	event.style = "event"
	event.completion = "check:Get Cat from Tree"
	var missing := ContractData.new()
	missing.style = "check"
	missing.completion = "check:TEST No Row"
	var event_view: ContractView = ContractView.from_entry(_entry_for(event), 0)
	var missing_view: ContractView = ContractView.from_entry(_entry_for(missing), 0)
	TestFixtures.check(res, "#721 an event style posting or a missing row leaves the lists empty",
		_lists_empty(event_view) and _lists_empty(missing_view), "event %d, missing %d knowledges" % [
			event_view.recommended_knowledges.size(), missing_view.recommended_knowledges.size()])
	var sample: ContractView = ContractView.from_sample(
		{"recommended": {"knowledges": [{"name": "TEST Lore", "hidden_bonus": 5}]}})
	TestFixtures.check(res, "#721 a sample view never reads the Checks.tsv row",
		_entry_names(sample.recommended_knowledges) == ["TEST Lore"] and sample.recommended_tools.is_empty()
			and sample.recommended_traditions.is_empty(),
		"got %s, %d tools, %d traditions" % [str(_entry_names(sample.recommended_knowledges)),
			sample.recommended_tools.size(), sample.recommended_traditions.size()])
	CheckStore.reset()


static func _case_entry_status(res: Dictionary) -> void:
	var cases: Array[Array] = [
		["Draft", GuiTypes.ContractStatus.AVAILABLE, ""],
		["Active", GuiTypes.ContractStatus.ACTIVE, ""],
		["Succeeded", GuiTypes.ContractStatus.COMPLETED, "Succeeded"],
		["Failed", GuiTypes.ContractStatus.COMPLETED, "Failed"],
		["Expired", GuiTypes.ContractStatus.EXPIRED, ""],
		["Rejected", GuiTypes.ContractStatus.REJECTED, ""],
	]
	var bad: Array[String] = []
	for c: Array in cases:
		var text: String = String(c[0])
		if ContractView.status_from_text(text) != int(c[1]) \
				or ContractView.outcome_from_text(text) != String(c[2]):
			bad.append("%s gave %d/%s" % [text, ContractView.status_from_text(text),
				ContractView.outcome_from_text(text)])
	TestFixtures.check(res, "the Q31 status map", bad.is_empty(),
		TestFixtures.detail(bad, cases.size(), "entry statuses"))
	var entry := BoardEntry.new()
	entry.expires_minute = 0
	TestFixtures.check(res, "an expired entry never reports negative hours",
		is_equal_approx(entry.hours_left(600), 0.0), "got %s" % str(entry.hours_left(600)))


static func _case_sample_data(res: Dictionary) -> void:
	var data: Dictionary = SampleDataLoader.load_file(SAMPLE_PATH)
	var mercs: Array[MercView] = data.get("mercs", [] as Array[MercView])
	var contracts: Array[ContractView] = data.get("contracts", [] as Array[ContractView])
	TestFixtures.check(res, "the seed holds ten mercs, twelve contracts and the bank",
		mercs.size() == SAMPLE_MERCS and contracts.size() == SAMPLE_CONTRACTS
			and int(data.get("bank_notes", 0)) == SAMPLE_BANK,
		"%d mercs, %d contracts, %d notes" % [mercs.size(), contracts.size(),
			int(data.get("bank_notes", 0))])
	if mercs.is_empty() or contracts.is_empty():
		return
	var first: MercView = mercs[0]
	TestFixtures.check(res, "the first sample merc reads its design prototype fields",
		first.uid == 0 and first.name == "Merc 1 Name" and first.level == 7
			and first.tradition == "Brave" and first.age_group == "Adult"
			and first.monthly_salary == 60 and first.employment_months == 14
			and first.guild_opinion == 5,
		"%s level %d salary %d" % [first.name, first.level, first.monthly_salary])
	TestFixtures.check(res, "a sample merc carries no engine record",
		first.merc == null and first.level_mode == "Auto" and first.knowledges.size() == 4
			and first.tools.size() == 3,
		"%d knowledges, %d tools" % [first.knowledges.size(), first.tools.size()])
	var resting: MercView = _find_status(mercs, GuiTypes.MercStatus.RESTING)
	TestFixtures.check(res, "a resting merc converts its days, hours and minutes",
		resting != null and is_equal_approx(resting.status_time_left_hours, 7.0 + 20.0 / 60.0),
		"got %s" % ("none" if resting == null else str(resting.status_time_left_hours)))
	var vacation: MercView = _find_status(mercs, GuiTypes.MercStatus.VACATION)
	TestFixtures.check(res, "a vacationing merc counts the whole days",
		vacation != null and is_equal_approx(vacation.status_time_left_hours,
			2.0 * 24.0 + 14.0 + 5.0 / 60.0),
		"got %s" % ("none" if vacation == null else str(vacation.status_time_left_hours)))
	TestFixtures.check(res, "an available merc has no time left",
		is_equal_approx(first.status_time_left_hours, 0.0)
			and first.status == GuiTypes.MercStatus.AVAILABLE,
		"status %d hours %s" % [first.status, str(first.status_time_left_hours)])
	var c0: ContractView = contracts[0]
	TestFixtures.check(res, "the first sample contract reads its design prototype fields",
		c0.entry_id == 0 and c0.name == "Contract 1 Name" and is_equal_approx(c0.difficulty, 3.0)
			and c0.contract_level == 10 and c0.reward == 800 and c0.distance_km == 48
			and c0.completion_hours == 48 and c0.location == "Location 1",
		"%s reward %d level %d" % [c0.name, c0.reward, c0.contract_level])
	TestFixtures.check(res, "the sample status and urgency map to the enums",
		c0.status == GuiTypes.ContractStatus.AVAILABLE and c0.urgency == GuiTypes.Urgency.LOW
			and c0.contract == null,
		"status %d urgency %d" % [c0.status, c0.urgency])
	TestFixtures.check(res, "the sample crew band keeps the cap of five",
		c0.merc_min == 1 and c0.merc_max == 3, "%d to %d" % [c0.merc_min, c0.merc_max])
	TestFixtures.check(res, "the sample recommendations load sorted",
		c0.recommended_knowledges.size() == 8 and c0.recommended_tools.size() == 8
			and c0.recommended_traditions.size() == 10 and _sorted_desc(c0.recommended_knowledges)
			and _sorted_desc(c0.recommended_traditions)
			and c0.recommended_traditions[0].hidden_bonus == 40,
		"%d knowledges, top tradition %d" % [c0.recommended_knowledges.size(),
			c0.recommended_traditions[0].hidden_bonus if not c0.recommended_traditions.is_empty() else -1])
	TestFixtures.check(res, "a missing file loads as an empty seed",
		(SampleDataLoader.load_file("res://Resources/GUI/not_here.json")["mercs"] as Array).is_empty(),
		"expected no mercs")


static func _case_run_resources(res: Dictionary) -> void:
	var bonus: BonusEntry = BonusEntry.make("Knowledge 1", 35)
	TestFixtures.check(res, "a bonus entry keeps its name and hidden percent",
		bonus.name == "Knowledge 1" and bonus.hidden_bonus == 35,
		"%s %d" % [bonus.name, bonus.hidden_bonus])
	var sorted: Array[BonusEntry] = BonusEntry.from_boosts({"A": 5, "B": 15, "C": 10})
	TestFixtures.check(res, "boosts sort highest first",
		sorted.size() == 3 and sorted[0].name == "B" and sorted[2].name == "A",
		"got %s" % str([sorted[0].name, sorted[1].name, sorted[2].name]))
	var leader := TeamMember.new()
	leader.merc_uid = 11
	leader.role = "Leader"
	leader.match = 4.5
	var guide := TeamMember.new()
	guide.merc_uid = 12
	guide.role = "Guide"
	guide.match = 3.0
	TestFixtures.check(res, "a team member holds the uid, the role and the match",
		leader.merc_uid == 11 and leader.role == "Leader" and is_equal_approx(leader.match, 4.5),
		"uid %d role %s match %s" % [leader.merc_uid, leader.role, str(leader.match)])
	var contract_run := ActiveRun.new()
	contract_run.hours = 150.0
	contract_run.reward = 2400
	contract_run.travel_cost = 300
	contract_run.odds = 62
	contract_run.team = [leader, guide] as Array[TeamMember]
	contract_run.travel_mode = "horse"
	contract_run.dispatched_minute = 1920
	contract_run.entry_id = 2
	TestFixtures.check(res, "an active run holds the dispatch agreement",
		is_equal_approx(contract_run.hours, 150.0) and contract_run.reward == 2400 and contract_run.travel_cost == 300
			and contract_run.odds == 62 and contract_run.travel_mode == "horse" and contract_run.dispatched_minute == 1920
			and contract_run.entry_id == 2,
		"odds %d reward %d entry %d" % [contract_run.odds, contract_run.reward, contract_run.entry_id])
	TestFixtures.check(res, "the run names its crew and its leader",
		contract_run.uids() == ([11, 12] as Array[int]) and contract_run.leader_uid() == 11,
		"uids %s leader %d" % [str(contract_run.uids()), contract_run.leader_uid()])
	var leaderless := ActiveRun.new()
	leaderless.team = [guide] as Array[TeamMember]
	TestFixtures.check(res, "a crew with no leader reports none",
		leaderless.leader_uid() == 0, "got %d" % leaderless.leader_uid())


static func _generate_merc(level: int) -> MercenaryData:
	TestFixtures.reset_generator_rolls()
	MercGenerator.forced_level = level
	var merc: MercenaryData = MercGenerator.generate(0)
	MercGenerator.forced_level = -1
	return merc


static func _uid_merc(name: String) -> MercenaryData:
	var merc := MercenaryData.new()
	merc.merc_name = name
	merc.merc_uid = CampaignKnowledge.next_uid()
	merc.stats = {"level": 1}
	return merc


static func _lifepath(kind: String, name: String, description: String,
		perks: Array[String]) -> LifepathData:
	var lp := LifepathData.new()
	lp.event_type = kind
	lp.event_name = name
	lp.description = description
	lp.perks = perks
	return lp


#Every row carries the four keys and the list keeps the merc's own trait order.
static func _rows_match(rows: Array[Dictionary], list: Array[TraitData]) -> bool:
	if rows.size() != list.size():
		return false
	for i: int in range(rows.size()):
		var row: Dictionary = rows[i]
		if not (row.has("name") and row.has("description") and row.has("category")
				and row.has("acquired")):
			return false
		if String(row["name"]) != list[i].trait_name:
			return false
		if String(row["category"]) != list[i].trait_category:
			return false
	return true


static func _chips_match(chips: Array[Dictionary], events: Array[LifepathData]) -> bool:
	if chips.size() != mini(events.size(), LifepathProgression.MAX_EVENTS):
		return false
	for i: int in range(chips.size()):
		if String(chips[i].get("name", "")) != events[i].event_name:
			return false
		if String(chips[i].get("kind", "")) != events[i].event_type:
			return false
	return true


#The first perk the merc holds that a lifepath event names; "" when no event gave one.
static func _first_credited_perk(merc: MercenaryData) -> String:
	for event: LifepathData in merc.lifepaths:
		for name: String in event.perks:
			for data: TraitData in merc.perks:
				if data.trait_name == name:
					return name
	return ""


static func _rows_credited(rows: Array[Dictionary], named: Dictionary) -> bool:
	for row: Dictionary in rows:
		if String(row.get("acquired", "x")) != String(named.get(row["name"], "")):
			return false
	return true


static func _acquired_ok(view: MercView, merc: MercenaryData, credited: String) -> bool:
	var named: Dictionary = {}
	for event: LifepathData in merc.lifepaths:
		for name: String in event.perks:
			if not named.has(name):
				named[name] = event.event_name
		for name: String in event.drawbacks:
			if not named.has(name):
				named[name] = event.event_name
	if not (_rows_credited(view.perks, named) and _rows_credited(view.drawbacks, named)
			and _rows_credited(view.descriptors, named)):
		return false
	if credited == "":
		return true
	for row: Dictionary in view.perks:
		if String(row["name"]) == credited:
			return String(row.get("acquired", "")) == String(named[credited])
	return false


#The first view reads an empty tally; a second reads the count the merc now carries.
static func _check_action_uses(res: Dictionary, view: MercView, merc: MercenaryData) -> void:
	if view.actions.is_empty():
		TestFixtures.check(res, "actions start at zero uses with a blank description", true,
			"the merc holds no actions")
		TestFixtures.check(res, "times_used reads the merc's action tally", true,
			"the merc holds no actions")
		return
	TestFixtures.check(res, "actions start at zero uses with a blank description",
		_actions_blank(view.actions), "got %d actions" % view.actions.size())
	var first: String = String(view.actions[0].get("name", ""))
	merc.action_uses = {first: 3}
	var used: MercView = MercView.from_merc(merc, GuiTypes.MercStatus.RESTING, 7.5, 3)
	TestFixtures.check(res, "times_used reads the merc's action tally",
		_uses_match(used.actions, first, 3), "%s of %d actions" % [first, used.actions.size()])


static func _uses_match(actions: Array[Dictionary], used: String, count: int) -> bool:
	if actions.is_empty():
		return false
	for entry: Dictionary in actions:
		var want: int = count if String(entry.get("name", "")) == used else 0
		if int(entry.get("times_used", -1)) != want:
			return false
	return true


static func _actions_blank(actions: Array[Dictionary]) -> bool:
	if actions.is_empty():
		return false
	for entry: Dictionary in actions:
		if String(entry.get("name", "")) == "" or int(entry.get("times_used", -1)) != 0 \
				or String(entry.get("description", "x")) != "":
			return false
	return true


#The armor and the two hand slots lead the list, in that order, whenever the merc holds them.
static func _equipment_ok(merc: MercenaryData, equipment: Array[Dictionary]) -> bool:
	var expected: Array[String] = []
	if merc.equipped_armor != null:
		expected.append("Armor")
	if merc.equipped_weapon != null:
		expected.append("Primary Hand")
	if merc.offhand_weapon != null:
		expected.append("Secondary Hand")
	if equipment.size() < expected.size():
		return false
	for i: int in range(expected.size()):
		if String(equipment[i].get("slot", "")) != expected[i]:
			return false
		if String(equipment[i].get("name", "")) == "":
			return false
	return true


#Empty boosts on a check posting with a Checks.tsv row expect the row's list for kind, as ContractView fills it.
static func _list_matches(list: Array[BonusEntry], boosts: Dictionary, contract: ContractData, kind: String) -> bool:
	if not boosts.is_empty():
		return list.size() == boosts.size()
	if contract.style != "check" or not contract.completion.begins_with(CheckStore.PREFIX):
		return list.is_empty()
	var parsed: Dictionary = CheckStore.parse(CheckStore.find(contract.completion))
	if parsed.is_empty():
		return list.is_empty()
	var key: String = "value" if kind == "traditions" else "percent"
	return list.size() == BonusEntry.from_parsed(parsed[kind], key, kind == "traditions").size()


static func _entry_for(data: ContractData) -> BoardEntry:
	var entry := BoardEntry.new()
	entry.contract = data
	return entry


static func _entry_names(entries: Array[BonusEntry]) -> Array[String]:
	var out: Array[String] = []
	for entry: BonusEntry in entries:
		out.append(entry.name)
	return out


static func _lists_empty(view: ContractView) -> bool:
	return (view.recommended_knowledges.is_empty() and view.recommended_tools.is_empty()
		and view.recommended_traditions.is_empty())


static func _sorted_desc(entries: Array[BonusEntry]) -> bool:
	for i: int in range(1, entries.size()):
		if entries[i - 1].hidden_bonus < entries[i].hidden_bonus:
			return false
	return true


static func _find_status(mercs: Array[MercView], status: int) -> MercView:
	for view: MercView in mercs:
		if view.status == status:
			return view
	return null
