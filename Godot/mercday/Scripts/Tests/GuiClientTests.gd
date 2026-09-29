class_name GuiClientTests

#Client Viewer: the client registry, the client list, the overview, the history and the chart.
#Run: godot --headless --path . with the user arg --gui-client-tests

const VIEWER := preload("res://Scenes/GUI/Clients/ClientViewer.tscn")
const CHART_SCENE := preload("res://Scenes/GUI/Clients/ClientStockChart.tscn")
const ACTIVE: int = GuiTypes.ContractStatus.ACTIVE
const DONE: int = GuiTypes.ContractStatus.COMPLETED
const FREE: int = GuiTypes.ContractStatus.AVAILABLE
const GONE: int = GuiTypes.ContractStatus.EXPIRED
const TURNED: int = GuiTypes.ContractStatus.REJECTED
const ORGS: StringName = &"orgs"
const PEOPLE: StringName = &"people"
const PLACES: StringName = &"places"
const TYPE_ONE: String = "Issuer Type 1"
const TYPE_TWO: String = "Issuer Type 2"


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_issuer(res)
	_case_counts(res)
	_case_tallies(res)
	_case_recent(res)
	_case_seed(res)
	_case_sorted(res)
	_case_filters(res)
	await _case_tabs(res, host)
	await _case_list(res, host)
	await _case_selection(res, host)
	await _case_query(res, host)
	await _case_overview(res, host)
	await _case_stats(res, host)
	await _case_chart(res, host)
	await _case_chart_view(res, host)
	await _case_relationship(res, host)
	await _case_locked(res, host)
	await _case_signals(res, host)
	await _case_show_client(res, host)
	await _case_from_game(res, host)
	SubscriptionManager.reset()
	return TestFixtures.summarize(res, "GUI CLIENT")


static func _view(id: int, entry_name: String, status: int, difficulty: float, reward: int,
		outcome: String) -> ContractView:
	var view := ContractView.new()
	view.entry_id = id
	view.name = entry_name
	view.status = status
	view.difficulty = difficulty
	view.reward = reward
	view.outcome = outcome
	return view


static func _companies() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({"name": "Alpha Trading", "type": TYPE_ONE, "lender": "Bank A"})
	out.append({"name": "Beta Mining", "type": TYPE_TWO, "lender": "Bank B"})
	out.append({"name": "Gamma Ferry", "type": TYPE_ONE})
	out.append({})
	return out


static func _views() -> Array[ContractView]:
	var out: Array[ContractView] = []
	out.append(_view(0, "Alpha Job", ACTIVE, 3.0, 800, ""))
	out.append(_view(12, "Alpha Done", DONE, 1.0, 200, "Succeeded"))
	out.append(_view(3, "Beta Done", DONE, 4.0, 1000, "Succeeded"))
	out.append(_view(15, "Beta Claim", DONE, 2.5, 600, "Succeeded"))
	out.append(_view(6, "Gamma Lost", DONE, 2.0, 500, "Failed"))
	out.append(_view(18, "Gamma Offer", FREE, 1.0, 100, ""))
	out.append(_view(1, "Person Job", ACTIVE, 5.0, 300, ""))
	out.append(_view(4, "", DONE, 2.0, 700, "Succeeded"))
	out.append(_view(7, "Person Offer", FREE, 1.0, 100, ""))
	out.append(_view(10, "Person Lost", DONE, 3.0, 400, "Failed"))
	out.append(_view(2, "Place Done", DONE, 1.5, 150, "Succeeded"))
	out.append(_view(5, "Place Job", ACTIVE, 4.5, 900, ""))
	out.append(_view(31, "Person Expired", GONE, 2.0, 100, ""))
	out.append(_view(55, "Person Rejected", TURNED, 2.0, 100, ""))
	return out


static func _fixture() -> ClientRegistry:
	var reg := ClientRegistry.new()
	reg.build(_views(), _companies(), [15], {12: 250}, [0, 3, 12],
		{"Bank B": 4, "Bank A": 99})
	return reg


static func _one_view(view: ContractView) -> ClientRegistry:
	var reg := ClientRegistry.new()
	var only: Array[ContractView] = [view]
	reg.build(only, _companies())
	return reg


static func _ids(rows: Array[ClientData]) -> String:
	var out := PackedStringArray()
	for row: ClientData in rows:
		out.append(str(row.index))
	return ",".join(out)


static func _order(reg: ClientRegistry, sort_key: StringName, down: bool) -> String:
	return _ids(reg.sorted(ORGS, sort_key, down))


static func _case_issuer(res: Dictionary) -> void:
	var reg: ClientRegistry = _fixture()
	TestFixtures.check(res, "the issuer kinds run orgs, people, places",
		ContractIssuer.KINDS.size() == 3 and ContractIssuer.KINDS[0] == ORGS,
		"got %s" % str(ContractIssuer.KINDS))
	var bad: Array[String] = []
	for id: int in [0, 3, 6, 12, 15, 18, 1, 4, 7, 10, 2, 5]:
		var client: ClientData = reg.issuer_of(id)
		var kind: StringName = ContractIssuer.kind_of(id)
		var want: int = ContractIssuer.index_of(id, reg.count(kind))
		if client == null or client.kind != kind or client.index != want:
			bad.append(str(id))
	TestFixtures.check(res, "every fixture entry resolves to its issuer", bad.is_empty(),
		"missed %s" % str(bad))
	TestFixtures.check(res, "the org entries land on the company the issuer names",
		reg.issuer_of(0).index == 0 and reg.issuer_of(12).index == 0
			and reg.issuer_of(3).index == 1 and reg.issuer_of(6).index == 2,
		"got %d, %d, %d, %d" % [reg.issuer_of(0).index, reg.issuer_of(12).index,
			reg.issuer_of(3).index, reg.issuer_of(6).index])
	TestFixtures.check(res, "an id past the seeded people still resolves",
		reg.issuer_of(25) != null and reg.issuer_of(25).kind == PEOPLE,
		"got %s" % str(reg.issuer_of(25)))


static func _case_counts(res: Dictionary) -> void:
	var reg: ClientRegistry = _fixture()
	TestFixtures.check(res, "people and places seed eight rows each",
		reg.count(PEOPLE) == ContractIssuer.PEOPLE and reg.count(PLACES) == ContractIssuer.PLACES,
		"got %d people and %d places" % [reg.count(PEOPLE), reg.count(PLACES)])
	TestFixtures.check(res, "orgs seed one row per stock company", reg.count(ORGS) == 4,
		"got %d orgs" % reg.count(ORGS))
	TestFixtures.check(res, "only the clients with a contract are listed",
		reg.total(ORGS) == 3 and reg.total(PEOPLE) == 4 and reg.total(PLACES) == 2,
		"got %d orgs, %d people, %d places" % [reg.total(ORGS), reg.total(PEOPLE),
			reg.total(PLACES)])
	TestFixtures.check(res, "a pinned company joins the total", reg.total(ORGS, 3) == 4,
		"got %d" % reg.total(ORGS, 3))
	TestFixtures.check(res, "a pinned row that already counts adds nothing",
		reg.total(ORGS, 0) == 3, "got %d" % reg.total(ORGS, 0))
	TestFixtures.check(res, "an unknown kind reads as people",
		reg.count(&"dragons") == reg.count(PEOPLE), "got %d" % reg.count(&"dragons"))
	TestFixtures.check(res, "an index out of range has no client", reg.client(ORGS, 9) == null,
		"got %s" % str(reg.client(ORGS, 9)))


static func _case_tallies(res: Dictionary) -> void:
	var reg: ClientRegistry = _fixture()
	var org0: ClientData = reg.client(ORGS, 0)
	var org1: ClientData = reg.client(ORGS, 1)
	var org2: ClientData = reg.client(ORGS, 2)
	TestFixtures.check(res, "an org counts both of its board entries",
		org0.offered == 2 and org0.accepted == 2,
		"got %d offered and %d accepted" % [org0.offered, org0.accepted])
	TestFixtures.check(res, "a paid result overrides the listed reward", org0.paid == 250,
		"got %d" % org0.paid)
	TestFixtures.check(res, "the average difficulty divides by the accepted count",
		is_equal_approx(org0.avg_difficulty, 2.0), "got %f" % org0.avg_difficulty)
	TestFixtures.check(res, "recency keeps the newest entry id", org0.recency == 12,
		"got %d" % org0.recency)
	TestFixtures.check(res, "an unclaimed contract counts as accepted only",
		org1.accepted == 2 and org1.succeeded == 1 and org1.paid == 1000,
		"got %d accepted, %d won, %d paid" % [org1.accepted, org1.succeeded, org1.paid])
	TestFixtures.check(res, "the unclaimed row lifts the average difficulty",
		is_equal_approx(org1.avg_difficulty, 3.25), "got %f" % org1.avg_difficulty)
	TestFixtures.check(res, "a failed contract counts as failed and pays nothing",
		org2.failed == 1 and org2.succeeded == 0 and org2.paid == 0,
		"got %d failed, %d won, %d paid" % [org2.failed, org2.succeeded, org2.paid])
	TestFixtures.check(res, "an available contract is offered but never accepted",
		org2.offered == 2 and org2.accepted == 1,
		"got %d offered and %d accepted" % [org2.offered, org2.accepted])
	var person2: ClientData = reg.client(PEOPLE, 2)
	TestFixtures.check(res, "a client with only an offer has no average",
		person2.accepted == 0 and is_zero_approx(person2.avg_difficulty)
			and person2.recency == -1,
		"got %d accepted, %f avg, %d recency" % [person2.accepted, person2.avg_difficulty,
			person2.recency])
	TestFixtures.check(res, "an offer, an expired and a rejected row all count as offered",
		person2.offered == 3 and person2.accepted == 0 and person2.recency == -1,
		"got %d offered, %d accepted, %d recency" % [person2.offered, person2.accepted,
			person2.recency])
	var gone: ClientData = _one_view(_view(31, "Person Expired", GONE, 2.0, 100, "")).client(
		PEOPLE, 2)
	TestFixtures.check(res, "an expired contract on its own raises the offer only",
		gone.offered == 1 and gone.accepted == 0 and gone.recency == -1
			and gone.recent.is_empty(),
		"got %d offered, %d accepted, %d recency" % [gone.offered, gone.accepted, gone.recency])
	var turned: ClientData = _one_view(_view(55, "Person Rejected", TURNED, 2.0, 100, "")).client(
		PEOPLE, 2)
	TestFixtures.check(res, "a rejected contract on its own raises the offer only",
		turned.offered == 1 and turned.accepted == 0 and turned.recency == -1
			and turned.recent.is_empty(),
		"got %d offered, %d accepted, %d recency" % [turned.offered, turned.accepted,
			turned.recency])
	var place0: ClientData = reg.client(PLACES, 0)
	TestFixtures.check(res, "a place keeps its own reward when no result paid out",
		place0.paid == 150 and place0.succeeded == 1,
		"got %d paid and %d won" % [place0.paid, place0.succeeded])
	TestFixtures.check(res, "a client with no contract stays empty",
		reg.client(ORGS, 3).offered == 0 and reg.client(PEOPLE, 7).offered == 0,
		"got %d and %d" % [reg.client(ORGS, 3).offered, reg.client(PEOPLE, 7).offered])


static func _case_recent(res: Dictionary) -> void:
	var reg: ClientRegistry = _fixture()
	var org0: ClientData = reg.client(ORGS, 0)
	var org1: ClientData = reg.client(ORGS, 1)
	var org2: ClientData = reg.client(ORGS, 2)
	TestFixtures.check(res, "the recent list is newest first",
		org0.recent.size() == 2 and int(org0.recent[0]["entry_id"]) == 12
			and int(org0.recent[1]["entry_id"]) == 0,
		"got %s" % str(org0.recent))
	TestFixtures.check(res, "an active contract reads Active in light blue",
		String(org0.recent[1]["result"]) == ClientRegistry.ACTIVE_TEXT
			and Color(org0.recent[1]["color"]) == ClientRegistry.ACTIVE_COLOR,
		"got %s" % str(org0.recent[1]))
	TestFixtures.check(res, "a won contract reads Completed in green",
		String(org0.recent[0]["result"]) == ClientRegistry.DONE_TEXT
			and Color(org0.recent[0]["color"]) == ClientRegistry.DONE_COLOR,
		"got %s" % str(org0.recent[0]))
	TestFixtures.check(res, "an unclaimed contract reads Complete in orange",
		String(org1.recent[0]["result"]) == ContractView.UNCLAIMED_TEXT
			and Color(org1.recent[0]["color"]) == ContractView.UNCLAIMED_COLOR,
		"got %s" % str(org1.recent[0]))
	TestFixtures.check(res, "a failed contract reads Failed in red",
		String(org2.recent[0]["result"]) == ClientRegistry.FAILED_TEXT
			and Color(org2.recent[0]["color"]) == ClientRegistry.FAILED_COLOR,
		"got %s" % str(org2.recent[0]))
	TestFixtures.check(res, "an available contract keeps out of the recent list",
		org2.recent.size() == 1, "got %s" % str(org2.recent))
	TestFixtures.check(res, "a listed contract carries the link flag",
		bool(org0.recent[0]["listed"]) and bool(org0.recent[1]["listed"]),
		"got %s" % str(org0.recent))
	TestFixtures.check(res, "an unlisted contract carries no link flag",
		not bool(org1.recent[0]["listed"]) and bool(org1.recent[1]["listed"]),
		"got %s" % str(org1.recent))
	TestFixtures.check(res, "a nameless entry falls back to its id",
		String(reg.client(PEOPLE, 1).recent[0]["name"]) == "Contract 4",
		"got %s" % str(reg.client(PEOPLE, 1).recent[0]["name"]))
	TestFixtures.check(res, "a named entry keeps its name",
		String(org1.recent[1]["name"]) == "Beta Done",
		"got %s" % str(org1.recent[1]["name"]))


static func _case_seed(res: Dictionary) -> void:
	var reg: ClientRegistry = _fixture()
	var twice: ClientRegistry = _fixture()
	var bad: Array[String] = []
	for kind: StringName in ClientRegistry.KINDS:
		for client: ClientData in reg.clients(kind):
			if client.km < ClientRegistry.KM_MIN:
				bad.append("%s km %d" % [client.key(), client.km])
			if client.km >= ClientRegistry.KM_MIN + ClientRegistry.KM_SPAN:
				bad.append("%s km %d" % [client.key(), client.km])
			if client.relationship < -5 or client.relationship > 5:
				bad.append("%s rel %d" % [client.key(), client.relationship])
			if not ClientRegistry.LOCATIONS.has(client.location):
				bad.append("%s where %s" % [client.key(), client.location])
			if client.name.is_empty() or client.sub.is_empty():
				bad.append("%s blank" % client.key())
	TestFixtures.check(res, "every seeded client stays inside its bounds", bad.is_empty(),
		TestFixtures.detail(bad, 20, "client"))
	TestFixtures.check(res, "the same build seeds the same distance",
		reg.client(ORGS, 2).km == twice.client(ORGS, 2).km
			and reg.client(PEOPLE, 0).km == twice.client(PEOPLE, 0).km,
		"got %d and %d" % [reg.client(ORGS, 2).km, twice.client(ORGS, 2).km])
	TestFixtures.check(res, "a company keeps the market name and type",
		reg.client(ORGS, 0).name == "Alpha Trading" and reg.client(ORGS, 0).sub == TYPE_ONE,
		"got %s of %s" % [reg.client(ORGS, 0).name, reg.client(ORGS, 0).sub])
	TestFixtures.check(res, "a company row with no fields falls back",
		reg.client(ORGS, 3).name == "Company 4 Name"
			and reg.client(ORGS, 3).sub == ClientRegistry.ORG_SUB,
		"got %s of %s" % [reg.client(ORGS, 3).name, reg.client(ORGS, 3).sub])
	TestFixtures.check(res, "a person and a place are named by their seat",
		reg.client(PEOPLE, 0).name == "Person 1 Name"
			and reg.client(PLACES, 1).name == "Place 2 Name",
		"got %s and %s" % [reg.client(PEOPLE, 0).name, reg.client(PLACES, 1).name])
	TestFixtures.check(res, "the lender relationship overrides the seed and clamps",
		reg.client(ORGS, 0).relationship == 5 and reg.client(ORGS, 1).relationship == 4,
		"got %d and %d" % [reg.client(ORGS, 0).relationship, reg.client(ORGS, 1).relationship])
	TestFixtures.check(res, "the org locations follow the seat walk",
		reg.client(ORGS, 0).location == "Umbra" and reg.client(ORGS, 1).location == "Zukei",
		"got %s and %s" % [reg.client(ORGS, 0).location, reg.client(ORGS, 1).location])
	TestFixtures.check(res, "the kind line names the kind and the sub type",
		reg.client(ORGS, 1).kind_line() == "Org - Issuer Type 2",
		"got %s" % reg.client(ORGS, 1).kind_line())
	TestFixtures.check(res, "the where line names the place and the distance",
		reg.client(ORGS, 1).where_text() == "Zukei - %d km away" % reg.client(ORGS, 1).km,
		"got %s" % reg.client(ORGS, 1).where_text())
	TestFixtures.check(res, "a client key joins the kind and the seat",
		reg.client(PLACES, 3).key() == "places:3", "got %s" % reg.client(PLACES, 3).key())


static func _case_sorted(res: Dictionary) -> void:
	var reg: ClientRegistry = _fixture()
	TestFixtures.check(res, "four sort keys with the recent one first",
		ClientRegistry.SORTS.size() == 4 and ClientRegistry.sort_key_at(0) == &"recent"
			and ClientRegistry.sort_labels().size() == 4,
		"got %s" % str(ClientRegistry.sort_labels()))
	TestFixtures.check(res, "an index past the sort list reads as recent",
		ClientRegistry.sort_key_at(9) == &"recent",
		"got %s" % str(ClientRegistry.sort_key_at(9)))
	TestFixtures.check(res, "most recent descending puts the newest contract first",
		_order(reg, &"recent", true) == "1,0,2", "got %s" % _order(reg, &"recent", true))
	TestFixtures.check(res, "most recent ascending reverses that order",
		_order(reg, &"recent", false) == "2,0,1", "got %s" % _order(reg, &"recent", false))
	TestFixtures.check(res, "an all tied key falls back to the seat order",
		_order(reg, &"offered", true) == "0,1,2" and _order(reg, &"offered", false) == "0,1,2",
		"got %s and %s" % [_order(reg, &"offered", true), _order(reg, &"offered", false)])
	TestFixtures.check(res, "accepted descending keeps the tie in seat order",
		_order(reg, &"accepted", true) == "0,1,2", "got %s" % _order(reg, &"accepted", true))
	TestFixtures.check(res, "accepted ascending puts the single job first",
		_order(reg, &"accepted", false) == "2,0,1", "got %s" % _order(reg, &"accepted", false))
	TestFixtures.check(res, "notes earned descending puts the richest client first",
		_order(reg, &"paid", true) == "1,0,2", "got %s" % _order(reg, &"paid", true))
	TestFixtures.check(res, "notes earned ascending puts the unpaid client first",
		_order(reg, &"paid", false) == "2,0,1", "got %s" % _order(reg, &"paid", false))
	TestFixtures.check(res, "an unknown sort key sorts by recency",
		_order(reg, &"stars", true) == _order(reg, &"recent", true),
		"got %s" % _order(reg, &"stars", true))
	var none: Array[String] = []
	TestFixtures.check(res, "a pinned company joins the sorted rows and sorts last",
		_ids(reg.sorted(ORGS, &"recent", true, none, none, 3)) == "1,0,2,3",
		"got %s" % _ids(reg.sorted(ORGS, &"recent", true, none, none, 3)))
	TestFixtures.check(res, "people sort by their own tallies",
		_ids(reg.sorted(PEOPLE, &"paid", true)) == "1,0,2,3",
		"got %s" % _ids(reg.sorted(PEOPLE, &"paid", true)))
	TestFixtures.check(res, "most recent ascending still puts the pinned company last",
		_ids(reg.sorted(ORGS, &"recent", false, none, none, 3)) == "2,0,1,3",
		"got %s" % _ids(reg.sorted(ORGS, &"recent", false, none, none, 3)))
	TestFixtures.check(res, "a person with no accepted contract sorts last going up",
		_ids(reg.sorted(PEOPLE, &"recent", false)) == "0,1,3,2",
		"got %s" % _ids(reg.sorted(PEOPLE, &"recent", false)))
	TestFixtures.check(res, "a person with no accepted contract sorts last going down",
		_ids(reg.sorted(PEOPLE, &"recent", true)) == "3,1,0,2",
		"got %s" % _ids(reg.sorted(PEOPLE, &"recent", true)))
	TestFixtures.check(res, "an unknown key puts the same person last both ways",
		_ids(reg.sorted(PEOPLE, &"stars", false)) == "0,1,3,2"
			and _ids(reg.sorted(PEOPLE, &"stars", true)) == "3,1,0,2",
		"got %s and %s" % [_ids(reg.sorted(PEOPLE, &"stars", false)),
			_ids(reg.sorted(PEOPLE, &"stars", true))])
	var pinned_people: Array[ClientData] = reg.sorted(PEOPLE, &"recent", true, none, none, 5)
	var no_offer: Array[String] = []
	for row: ClientData in pinned_people:
		if row.offered < 1:
			no_offer.append(row.key())
	TestFixtures.check(res, "a pinned seat outside the companies lists no empty client",
		pinned_people.size() == 4 and no_offer.is_empty(),
		"got %d rows, empty %s" % [pinned_people.size(), str(no_offer)])
	TestFixtures.check(res, "a pinned seat outside the companies changes no total",
		reg.total(PEOPLE, 5) == 4 and reg.total(PLACES, 5) == 2,
		"got %d people and %d places" % [reg.total(PEOPLE, 5), reg.total(PLACES, 5)])


static func _case_filters(res: Dictionary) -> void:
	var reg: ClientRegistry = _fixture()
	var subs: Array[String] = reg.sub_types(ORGS)
	TestFixtures.check(res, "the org sub types come from the listed companies only",
		subs.size() == 2 and subs.has(TYPE_ONE) and subs.has(TYPE_TWO),
		"got %s" % str(subs))
	TestFixtures.check(res, "a pinned company adds its own sub type",
		reg.sub_types(ORGS, 3).size() == 3 and reg.sub_types(ORGS, 3).has(ClientRegistry.ORG_SUB),
		"got %s" % str(reg.sub_types(ORGS, 3)))
	TestFixtures.check(res, "the people sub types cover the four listed people",
		reg.sub_types(PEOPLE).size() == 4
			and reg.sub_types(PEOPLE)[0] == ClientRegistry.PEOPLE_SUBS[0],
		"got %s" % str(reg.sub_types(PEOPLE)))
	var places: Array[String] = reg.location_names(ORGS)
	var wanted: Array[String] = ["Cyfrolaef", "Umbra", "Zukei"]
	TestFixtures.check(res, "the org locations are the listed ones sorted",
		places == wanted, "got %s" % str(places))
	TestFixtures.check(res, "a pinned company adds its own location",
		reg.location_names(ORGS, 3).size() == 4 and reg.location_names(ORGS, 3).has("Hel"),
		"got %s" % str(reg.location_names(ORGS, 3)))
	var sorted_names: Array[String] = reg.location_names(PEOPLE)
	var copy: Array[String] = sorted_names.duplicate()
	copy.sort()
	TestFixtures.check(res, "every location list comes back sorted", sorted_names == copy,
		"got %s" % str(sorted_names))
	var none: Array[String] = []
	var hide_one: Array[String] = [TYPE_ONE]
	TestFixtures.check(res, "hiding a sub type drops its clients",
		_ids(reg.sorted(ORGS, &"recent", true, hide_one, none)) == "1",
		"got %s" % _ids(reg.sorted(ORGS, &"recent", true, hide_one, none)))
	var hide_place: Array[String] = ["Zukei"]
	TestFixtures.check(res, "hiding a location drops its clients",
		_ids(reg.sorted(ORGS, &"recent", true, none, hide_place)) == "0,2",
		"got %s" % _ids(reg.sorted(ORGS, &"recent", true, none, hide_place)))
	var hide_all: Array[String] = [TYPE_ONE, TYPE_TWO]
	TestFixtures.check(res, "hiding every sub type empties the list",
		reg.sorted(ORGS, &"recent", true, hide_all, none).is_empty(),
		"got %s" % _ids(reg.sorted(ORGS, &"recent", true, hide_all, none)))
	TestFixtures.check(res, "a filter never changes the total",
		reg.total(ORGS) == 3 and reg.sorted(ORGS, &"recent", true, hide_one, none).size() == 1,
		"got %d of %d" % [reg.sorted(ORGS, &"recent", true, hide_one, none).size(),
			reg.total(ORGS)])
	var hide_pin: Array[String] = ["Hel"]
	TestFixtures.check(res, "a hidden filter still drops a pinned company",
		reg.sorted(ORGS, &"recent", true, none, hide_pin, 3).size() == 3,
		"got %d" % reg.sorted(ORGS, &"recent", true, none, hide_pin, 3).size())


static func _open(host: Node, tab: StringName) -> ClientViewer:
	var screen: ClientViewer = VIEWER.instantiate()
	screen.auto_refresh = false
	screen.start_tab = tab
	host.add_child(screen)
	await host.get_tree().process_frame
	screen.set_registry(_fixture())
	await host.get_tree().process_frame
	return screen


static func _shut(host: Node, screen: ClientViewer) -> void:
	screen.queue_free()
	await host.get_tree().process_frame


static func _row_names(screen: ClientViewer) -> String:
	var out := PackedStringArray()
	for row: ClientListItem in screen.list.rows():
		out.append(row.name_text())
	return " | ".join(out)


static func _case_tabs(res: Dictionary, host: Node) -> void:
	var screen: ClientViewer = await _open(host, ORGS)
	var tabs: Array[TabButton] = screen.tabs()
	TestFixtures.check(res, "the viewer shows one tab per client kind", tabs.size() == 3,
		"got %d tabs" % tabs.size())
	TestFixtures.check(res, "the tabs read People, Places and Orgs",
		tabs[0].label == "People" and tabs[1].label == "Places" and tabs[2].label == "Orgs",
		"got %s, %s, %s" % [tabs[0].label, tabs[1].label, tabs[2].label])
	TestFixtures.check(res, "every tab carries its seat and a description",
		tabs[0].index == 0 and tabs[2].index == 2 and not tabs[1].description.is_empty(),
		"got %d, %d, %s" % [tabs[0].index, tabs[2].index, tabs[1].description])
	TestFixtures.check(res, "the start tab opens active", screen.current_tab() == ORGS
		and tabs[2].active and not tabs[0].active,
		"got %s active %s" % [str(screen.current_tab()), str(tabs[2].active)])
	TestFixtures.check(res, "the tab row keeps the prototype height",
		int(screen.tab_row.custom_minimum_size.y) == TabButton.ACTIVE_HEIGHT,
		"got %d" % int(screen.tab_row.custom_minimum_size.y))
	tabs[0].pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "pressing a tab opens that kind",
		screen.current_tab() == PEOPLE and screen.list.title_text() == "People",
		"got %s titled %s" % [str(screen.current_tab()), screen.list.title_text()])
	TestFixtures.check(res, "the pressed tab is the only active one",
		tabs[0].active and not tabs[2].active,
		"got %s and %s" % [str(tabs[0].active), str(tabs[2].active)])
	screen.open_tab(&"dragons")
	await host.get_tree().process_frame
	TestFixtures.check(res, "an unknown tab key changes nothing",
		screen.current_tab() == PEOPLE, "got %s" % str(screen.current_tab()))
	TestFixtures.check(res, "each tab carries its atlas id",
		tabs[0].icon_id == "person" and tabs[1].icon_id == "house"
			and tabs[2].icon_id == "building",
		"got %s" % [tabs[0].icon_id])
	var tab_icon: IconRect = tabs[2].icon_rect
	var icon_mid: Vector2 = tab_icon.get_global_rect().get_center()
	var tab_mid: Vector2 = tabs[2].get_global_rect().get_center()
	TestFixtures.check(res, "each tab icon draws a 32 px cell",
		tab_icon.size == Vector2(32, 32) and tab_icon.icon_id == "building"
			and icon_mid.distance_to(tab_mid) <= 1.0,
		"icon %s id %s centre %s tab %s" % [tab_icon.size, tab_icon.icon_id, icon_mid,
			tab_mid])
	await _shut(host, screen)


static func _case_list(res: Dictionary, host: Node) -> void:
	var screen: ClientViewer = await _open(host, ORGS)
	TestFixtures.check(res, "the list shows every client with a contract",
		screen.list.rows().size() == 3, "got %d rows" % screen.list.rows().size())
	TestFixtures.check(res, "the count reads shown over total",
		screen.list.count_text() == "3/3", "got %s" % screen.list.count_text())
	TestFixtures.check(res, "the list is titled after the open tab",
		screen.list.title_text() == "Orgs", "got %s" % screen.list.title_text())
	TestFixtures.check(res, "the rows follow the sorted order",
		_row_names(screen) == "Beta Mining | Alpha Trading | Gamma Ferry",
		"got %s" % _row_names(screen))
	var first: ClientListItem = screen.list.rows()[0]
	TestFixtures.check(res, "a row names the client, the sub type and the accepted count",
		first.name_text() == "Beta Mining" and first.sub_text() == TYPE_TWO
			and first.count_text() == "2",
		"got %s, %s, %s" % [first.name_text(), first.sub_text(), first.count_text()])
	TestFixtures.check(res, "a row tooltip names where the client is",
		first.tooltip_text == screen.registry().client(ORGS, 1).where_text(),
		"got %s" % first.tooltip_text)
	TestFixtures.check(res, "the list column keeps the prototype width",
		int(screen.list.custom_minimum_size.x) == ClientList.COLUMN_WIDTH,
		"got %d" % int(screen.list.custom_minimum_size.x))
	TestFixtures.check(res, "no empty panel shows while rows exist",
		not screen.list.empty_shown(), "got %s" % str(screen.list.empty_shown()))
	screen.open_tab(PEOPLE)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the people tab lists its own clients",
		screen.list.rows().size() == 4 and screen.list.count_text() == "4/4",
		"got %d rows reading %s" % [screen.list.rows().size(), screen.list.count_text()])
	screen.set_registry(ClientRegistry.new())
	await host.get_tree().process_frame
	TestFixtures.check(res, "an empty registry shows the empty text",
		screen.list.empty_shown() and screen.list.empty_text() == ClientList.EMPTY_TEXT,
		"got %s reading %s" % [str(screen.list.empty_shown()), screen.list.empty_text()])
	TestFixtures.check(res, "an empty registry leaves no selection",
		screen.selected() == null, "got %s" % str(screen.selected()))
	await _shut(host, screen)


static func _case_selection(res: Dictionary, host: Node) -> void:
	var screen: ClientViewer = await _open(host, ORGS)
	TestFixtures.check(res, "the first row is selected on open",
		screen.selected() != null and screen.selected().index == 1,
		"got %s" % str(screen.selected()))
	TestFixtures.check(res, "the selected row carries the orange edge",
		screen.list.rows()[0].edge_color() == ClientListItem.SELECTED_EDGE
			and screen.list.rows()[1].edge_color() == ClientListItem.NORMAL_EDGE,
		"got %s and %s" % [str(screen.list.rows()[0].edge_color()),
			str(screen.list.rows()[1].edge_color())])
	var seen: Array[int] = []
	screen.client_selected.connect(func(_kind: StringName, index: int) -> void:
		seen.append(index))
	TestFixtures.check(res, "pressing a row selects that client",
		screen.list.press_row("orgs:2"), "the row was missing")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the selection signal names the pressed client",
		seen.size() == 1 and seen[0] == 2, "got %s" % str(seen))
	TestFixtures.check(res, "the pressed row is the selected one",
		screen.selected().index == 2
			and screen.list.row_for("orgs:2").edge_color() == ClientListItem.SELECTED_EDGE,
		"got %s" % str(screen.selected().index))
	TestFixtures.check(res, "a missing row key presses nothing",
		not screen.list.press_row("orgs:9"), "the row answered")
	screen.open_tab(PEOPLE)
	await host.get_tree().process_frame
	TestFixtures.check(res, "each tab keeps its own selection",
		screen.selected().kind == PEOPLE and screen.selected().index == 3,
		"got %s" % str(screen.selected().key()))
	screen.open_tab(ORGS)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the org selection survives the tab trip",
		screen.selected().index == 2, "got %d" % screen.selected().index)
	TestFixtures.check(res, "select_client opens the kind and picks the seat",
		screen.select_client(PLACES, 1) and screen.current_tab() == PLACES
			and screen.selected().index == 1,
		"got %s" % str(screen.current_tab()))
	TestFixtures.check(res, "select_client refuses a seat with no client",
		not screen.select_client(PLACES, 40), "the call answered")
	await _shut(host, screen)


static func _case_query(res: Dictionary, host: Node) -> void:
	var screen: ClientViewer = await _open(host, ORGS)
	TestFixtures.check(res, "the sort menu offers every registry sort",
		screen.list.sort_control().options.size() == 4
			and screen.list.sort_control().options[0] == "Most Recent",
		"got %s" % str(screen.list.sort_control().options))
	TestFixtures.check(res, "the viewer opens on most recent descending",
		screen.sort_key() == &"recent" and screen.descending(),
		"got %s down %s" % [str(screen.sort_key()), str(screen.descending())])
	screen.list.sort_control().pick(2)
	await host.get_tree().process_frame
	TestFixtures.check(res, "picking a sort reorders the list",
		screen.sort_key() == &"accepted"
			and _row_names(screen) == "Alpha Trading | Beta Mining | Gamma Ferry",
		"got %s by %s" % [_row_names(screen), str(screen.sort_key())])
	screen.list.dir_control().toggle()
	await host.get_tree().process_frame
	TestFixtures.check(res, "flipping the direction reverses the list",
		not screen.descending() and _row_names(screen) == "Gamma Ferry | Alpha Trading | Beta Mining",
		"got %s down %s" % [_row_names(screen), str(screen.descending())])
	screen.open_tab(PEOPLE)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the sort and the direction are shared by every tab",
		screen.list.sort_key() == &"accepted" and not screen.list.descending(),
		"got %s down %s" % [str(screen.list.sort_key()), str(screen.list.descending())])
	screen.open_tab(ORGS)
	screen.list.sort_control().pick(0)
	screen.list.dir_control().toggle()
	await host.get_tree().process_frame
	var filter: ClientFilterButton = screen.list.filter_button()
	TestFixtures.check(res, "the filter offers a row per sub type and location",
		filter.row_count() == 5, "got %d rows" % filter.row_count())
	TestFixtures.check(res, "an untouched filter looks plain",
		not filter.is_changed() and filter.fill_color() == ClientFilterButton.PLAIN_FILL
			and filter.text_color() == ClientFilterButton.PLAIN_TEXT,
		"got %s" % str(filter.fill_color()))
	filter.toggle_sub(TYPE_ONE)
	await host.get_tree().process_frame
	TestFixtures.check(res, "hiding a sub type drops its rows from the list",
		screen.list.rows().size() == 1 and screen.list.count_text() == "1/3",
		"got %d rows reading %s" % [screen.list.rows().size(), screen.list.count_text()])
	TestFixtures.check(res, "a touched filter turns orange",
		filter.is_changed() and filter.fill_color() == ClientFilterButton.CHANGED_FILL
			and filter.text_color() == ClientFilterButton.CHANGED_TEXT,
		"got %s" % str(filter.fill_color()))
	TestFixtures.check(res, "the hidden sub type is the one that was pressed",
		filter.hidden_subs().size() == 1 and filter.hidden_subs()[0] == TYPE_ONE,
		"got %s" % str(filter.hidden_subs()))
	screen.open_tab(PEOPLE)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a filter belongs to the tab that set it",
		screen.list.rows().size() == 4 and not screen.list.filter_button().is_changed(),
		"got %d rows" % screen.list.rows().size())
	screen.open_tab(ORGS)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the org filter comes back with the tab",
		screen.list.rows().size() == 1 and screen.list.filter_button().is_changed(),
		"got %d rows" % screen.list.rows().size())
	filter.toggle_sub(TYPE_TWO)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a filter that hides every client says so",
		screen.list.empty_shown() and screen.list.empty_text() == ClientList.FILTERED_TEXT
			and screen.list.count_text() == "0/3",
		"got %s reading %s" % [str(screen.list.empty_shown()), screen.list.empty_text()])
	TestFixtures.check(res, "an empty list clears the overview",
		screen.selected() == null and screen.overview.empty_shown(),
		"got %s" % str(screen.selected()))
	filter.reset()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the reset button brings every client back",
		screen.list.rows().size() == 3 and not filter.is_changed(),
		"got %d rows" % screen.list.rows().size())
	filter.toggle_location("Zukei")
	await host.get_tree().process_frame
	TestFixtures.check(res, "hiding a location drops the clients that live there",
		screen.list.rows().size() == 2 and filter.hidden_locations().size() == 1,
		"got %d rows and %s" % [screen.list.rows().size(), str(filter.hidden_locations())])
	await _shut(host, screen)


static func _case_overview(res: Dictionary, host: Node) -> void:
	var screen: ClientViewer = await _open(host, ORGS)
	var over: ClientOverview = screen.overview
	var client: ClientData = screen.registry().client(ORGS, 1)
	TestFixtures.check(res, "a selected client hides the empty text",
		not over.empty_shown() and over.empty_text() == "No client selected.",
		"got %s reading %s" % [str(over.empty_shown()), over.empty_text()])
	TestFixtures.check(res, "the header names the selected client", over.name_text() == "Beta Mining",
		"got %s" % over.name_text())
	TestFixtures.check(res, "the header names the kind and the sub type",
		over.kind_text() == "Org - Issuer Type 2", "got %s" % over.kind_text())
	TestFixtures.check(res, "the header names the place and the distance",
		over.where_text() == client.where_text(), "got %s" % over.where_text())
	TestFixtures.check(res, "an org reads Company Details",
		over.right_title() == ClientOverview.ORG_TITLE, "got %s" % over.right_title())
	TestFixtures.check(res, "the summary carries the client about line",
		over.summary_text() == client.about, "got %s" % over.summary_text())
	TestFixtures.check(res, "the history lists every accepted contract",
		over.recent_rows().size() == 2 and not over.recent_empty_shown(),
		"got %d rows" % over.recent_rows().size())
	var rows: Array[ClientRecentRow] = over.recent_rows()
	TestFixtures.check(res, "a history row names the contract and its result",
		rows[0].name_text() == "Beta Claim" and rows[0].result_text() == ContractView.UNCLAIMED_TEXT
			and rows[0].result_color() == ContractView.UNCLAIMED_COLOR,
		"got %s reading %s" % [rows[0].name_text(), rows[0].result_text()])
	TestFixtures.check(res, "the history is newest first",
		rows[1].entry_id == 3 and rows[0].entry_id == 15,
		"got %d then %d" % [rows[0].entry_id, rows[1].entry_id])
	TestFixtures.check(res, "only a listed contract offers the view link",
		rows[1].link_shown() and not rows[0].link_shown(),
		"got %s and %s" % [str(rows[1].link_shown()), str(rows[0].link_shown())])
	TestFixtures.check(res, "the view link sits in the names column under the result",
		rows[1].link_box.get_parent() == rows[1].name_label.get_parent()
			and rows[1].link_box.get_index() == rows[1].result_label.get_index() + 1,
		"got %s at %d" % [str(rows[1].link_box.get_parent()), rows[1].link_box.get_index()])
	TestFixtures.check(res, "the row height clears the stacked lines and the padding",
		float(ClientRecentRow.ROW_HEIGHT)
			>= rows[1].inner_min_height() + 2.0 * ClientRecentRow.PAD_PX,
		"got %d for %f" % [ClientRecentRow.ROW_HEIGHT, rows[1].inner_min_height()])
	screen.select_client(PEOPLE, 2)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a person reads Details",
		over.right_title() == ClientOverview.OTHER_TITLE, "got %s" % over.right_title())
	TestFixtures.check(res, "a client with no accepted contract says so",
		over.recent_rows().is_empty() and over.recent_empty_shown(),
		"got %d rows" % over.recent_rows().size())
	TestFixtures.check(res, "the person header names the seat",
		over.name_text() == "Person 3 Name", "got %s" % over.name_text())
	screen.set_registry(ClientRegistry.new())
	await host.get_tree().process_frame
	TestFixtures.check(res, "no client shows the empty text and hides the body",
		over.empty_shown() and not over.body.visible,
		"got %s" % str(over.empty_shown()))
	await _shut(host, screen)


static func _case_stats(res: Dictionary, host: Node) -> void:
	var screen: ClientViewer = await _open(host, ORGS)
	var over: ClientOverview = screen.overview
	var tiles: Array[StatTile] = over.tiles()
	TestFixtures.check(res, "the overview shows five stat tiles", tiles.size() == 5,
		"got %d tiles" % tiles.size())
	var labels := PackedStringArray()
	for tile: StatTile in tiles:
		labels.append(tile.label)
	TestFixtures.check(res, "the tiles read offered, accepted, won, lost and paid",
		",".join(labels) == "Offered,Accepted,Successful,Failed,Notes Earned",
		"got %s" % ",".join(labels))
	TestFixtures.check(res, "the tiles carry the client tallies",
		tiles[0].amount == 2 and tiles[1].amount == 2 and tiles[2].amount == 1
			and tiles[3].amount == 0 and tiles[4].amount == 1000,
		"got %d, %d, %d, %d, %d" % [tiles[0].amount, tiles[1].amount, tiles[2].amount,
			tiles[3].amount, tiles[4].amount])
	TestFixtures.check(res, "the won tile is green and the lost tile is red",
		tiles[2].value_color == ClientOverview.GREEN and tiles[3].value_color == ClientOverview.RED,
		"got %s and %s" % [str(tiles[2].value_color), str(tiles[3].value_color)])
	TestFixtures.check(res, "the paid tile is yellow and shows the notes glyph",
		tiles[4].value_color == ClientOverview.YELLOW and tiles[4].show_glyph,
		"got %s glyph %s" % [str(tiles[4].value_color), str(tiles[4].show_glyph)])
	TestFixtures.check(res, "the count tiles stay cream with no glyph",
		tiles[0].value_color == ClientOverview.CREAM and not tiles[0].show_glyph
			and not tiles[2].show_glyph,
		"got %s glyph %s" % [str(tiles[0].value_color), str(tiles[0].show_glyph)])
	TestFixtures.check(res, "the stats grid holds the six prototype cells",
		over.stats_grid.get_child_count() == 6 and over.stats_grid.columns == 3,
		"got %d cells in %d columns" % [over.stats_grid.get_child_count(),
			over.stats_grid.columns])
	TestFixtures.check(res, "the stats grid keeps the prototype height and never stretches",
		is_equal_approx(over.stats_grid.custom_minimum_size.y, float(ClientOverview.GRID_HEIGHT))
			and over.stats_grid.size_flags_vertical == Control.SIZE_SHRINK_BEGIN,
		"got %f flags %d" % [over.stats_grid.custom_minimum_size.y,
			over.stats_grid.size_flags_vertical])
	var cell_bad: Array[String] = []
	for child: Node in over.stats_grid.get_children():
		if not (child is Control):
			cell_bad.append("%s is no control" % child.name)
			continue
		var cell: Control = child as Control
		if not is_equal_approx(cell.custom_minimum_size.y, float(ClientOverview.CELL_HEIGHT)):
			cell_bad.append("%s high %f" % [cell.name, cell.custom_minimum_size.y])
		if not is_zero_approx(cell.custom_minimum_size.x):
			cell_bad.append("%s wide %f" % [cell.name, cell.custom_minimum_size.x])
		if cell.size_flags_horizontal != Control.SIZE_EXPAND_FILL:
			cell_bad.append("%s flags %d" % [cell.name, cell.size_flags_horizontal])
	TestFixtures.check(res, "every stat cell is 45 px tall and shares the column width",
		cell_bad.is_empty(), TestFixtures.detail(cell_bad, 10, "cell"))
	TestFixtures.check(res, "the average difficulty shows stars",
		over.stars_shown() and is_equal_approx(over.stars().rating, 3.5),
		"got shown %s at %f" % [str(over.stars_shown()), over.stars().rating])
	screen.select_client(PEOPLE, 2)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a client with no accepted contract shows a dash",
		not over.stars_shown() and over.avg_text() == ClientOverview.DASH_TEXT,
		"got shown %s reading %s" % [str(over.stars_shown()), over.avg_text()])
	TestFixtures.check(res, "an unaccepted client still counts its offer",
		over.tiles()[0].amount == 3 and over.tiles()[1].amount == 0,
		"got %d offered and %d accepted" % [over.tiles()[0].amount, over.tiles()[1].amount])
	await _shut(host, screen)


static func _chart(host: Node, prices: PackedFloat32Array) -> ClientStockChart:
	var chart: ClientStockChart = CHART_SCENE.instantiate()
	chart.custom_minimum_size = Vector2(300.0, 160.0)
	host.add_child(chart)
	await host.get_tree().process_frame
	chart.set_prices(2, prices)
	await host.get_tree().process_frame
	return chart


static func _case_chart(res: Dictionary, host: Node) -> void:
	var rising: ClientStockChart = await _chart(host,
		PackedFloat32Array([100.0, 110.0, 130.0]))
	TestFixtures.check(res, "the chart is titled after its range",
		rising.title_label.text == ClientStockChart.TITLE_TEXT,
		"got %s" % rising.title_label.text)
	TestFixtures.check(res, "the chart reads the last price",
		rising.price_text() == "130.00", "got %s" % rising.price_text())
	TestFixtures.check(res, "a rising chart reads a positive change",
		rising.change_text() == "+30.0%" and rising.is_up(),
		"got %s" % rising.change_text())
	TestFixtures.check(res, "a rising chart draws green",
		rising.line_color() == ClientStockChart.UP_COLOR, "got %s" % str(rising.line_color()))
	TestFixtures.check(res, "the chart plots one point per price",
		rising.points().size() == 3, "got %d points" % rising.points().size())
	TestFixtures.check(res, "the points run left to right from the inset",
		is_equal_approx(rising.points()[0].x, ClientStockChart.INSET_PX)
			and rising.points()[2].x > rising.points()[0].x,
		"got %s" % str(rising.points()))
	TestFixtures.check(res, "the chart knows the company it shows", rising.company_id == 2,
		"got %d" % rising.company_id)
	TestFixtures.check(res, "a chart with prices is visible", rising.visible,
		"got %s" % str(rising.visible))
	rising.queue_free()
	var falling: ClientStockChart = await _chart(host, PackedFloat32Array([200.0, 150.0]))
	TestFixtures.check(res, "a falling chart reads a negative change",
		falling.change_text() == "-25.0%" and not falling.is_up(),
		"got %s" % falling.change_text())
	TestFixtures.check(res, "a falling chart draws red",
		falling.line_color() == ClientStockChart.DOWN_COLOR,
		"got %s" % str(falling.line_color()))
	falling.queue_free()
	var flat: ClientStockChart = await _chart(host,
		PackedFloat32Array([100.0, 100.0, 100.0]))
	TestFixtures.check(res, "a flat chart reads no change and rides the middle",
		flat.change_text() == "+0.0%"
			and is_equal_approx(flat.points()[0].y, flat.points()[2].y),
		"got %s at %s" % [flat.change_text(), str(flat.points())])
	flat.queue_free()
	var thin: ClientStockChart = await _chart(host, PackedFloat32Array([100.0]))
	TestFixtures.check(res, "a chart under two prices hides itself",
		not thin.visible and thin.points().is_empty(),
		"got visible %s with %d points" % [str(thin.visible), thin.points().size()])
	TestFixtures.check(res, "a chart with no prices reads zero",
		ClientStockChart.MIN_PRICES == 2 and is_zero_approx(thin.change_pct()),
		"got %f" % thin.change_pct())
	thin.queue_free()
	var zero: ClientStockChart = await _chart(host, PackedFloat32Array([0.0, 5.0]))
	TestFixtures.check(res, "a chart that starts at zero reads no change",
		is_zero_approx(zero.change_pct()) and zero.price_text() == "5.00",
		"got %f reading %s" % [zero.change_pct(), zero.price_text()])
	zero.queue_free()
	await host.get_tree().process_frame


static func _case_chart_view(res: Dictionary, host: Node) -> void:
	var screen: ClientViewer = await _open(host, ORGS)
	var over: ClientOverview = screen.overview
	TestFixtures.check(res, "the overview chart follows the selected company",
		over.chart_button().company_id == 1, "got %d" % over.chart_button().company_id)
	over.set_stock(1, PackedFloat32Array([10.0, 20.0]))
	await host.get_tree().process_frame
	TestFixtures.check(res, "an org with a price history shows the chart",
		over.chart_button().visible, "got %s" % str(over.chart_button().visible))
	over.hide_stock()
	await host.get_tree().process_frame
	TestFixtures.check(res, "hiding the stock clears the chart",
		not over.chart_button().visible and over.chart_button().company_id == -1,
		"got visible %s at %d" % [str(over.chart_button().visible),
			over.chart_button().company_id])
	screen.select_client(PEOPLE, 0)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a person never shows a stock chart",
		not over.chart_button().visible and over.chart_button().company_id == -1,
		"got visible %s at %d" % [str(over.chart_button().visible),
			over.chart_button().company_id])
	await _shut(host, screen)


static func _case_relationship(res: Dictionary, host: Node) -> void:
	SubscriptionManager.reset()
	var screen: ClientViewer = await _open(host, ORGS)
	var over: ClientOverview = screen.overview
	TestFixtures.check(res, "a paid guild sees the client opinion",
		over.entitled() and not over.lock_shown(),
		"got entitled %s locked %s" % [str(over.entitled()), str(over.lock_shown())])
	TestFixtures.check(res, "the opinion reads the lender relationship",
		over.relationship_text() == "Opinion +4", "got %s" % over.relationship_text())
	TestFixtures.check(res, "the opinion takes the guild mood colour",
		over.relationship_color() == MoodFace.GUILD_COLORS[9],
		"got %s" % str(over.relationship_color()))
	TestFixtures.check(res, "the overview shows eleven mood faces",
		over.faces().size() == 11, "got %d faces" % over.faces().size())
	TestFixtures.check(res, "the filled face sits on the relationship",
		over.filled_face() == 4 and over.faces()[9].filled,
		"got %d" % over.filled_face())
	TestFixtures.check(res, "only one face is filled",
		not over.faces()[8].filled and not over.faces()[10].filled,
		"got %s and %s" % [str(over.faces()[8].filled), str(over.faces()[10].filled)])
	TestFixtures.check(res, "every face names the opinion it stands for",
		over.faces()[0].tooltip_text == "Opinion -5"
			and over.faces()[5].tooltip_text == ClientOverview.NEUTRAL_TEXT,
		"got %s and %s" % [over.faces()[0].tooltip_text, over.faces()[5].tooltip_text])
	TestFixtures.check(res, "a face is 24 px and the difficulty stars are 88 x 16 over the client unlit",
		over.faces()[0].custom_minimum_size == Vector2(24, 24)
			and over.stars().custom_minimum_size == Vector2(88, 16)
			and over.stars().empty_color == Icons.UNUSED_STAR_CLIENT,
		"face %s stars %s" % [over.faces()[0].custom_minimum_size,
			over.stars().custom_minimum_size])
	TestFixtures.check(res, "a neutral opinion reads Neutral",
		ClientOverview.relationship_line(0) == ClientOverview.NEUTRAL_TEXT
			and ClientOverview.relationship_line(-3) == "Opinion -3",
		"got %s and %s" % [ClientOverview.relationship_line(0),
			ClientOverview.relationship_line(-3)])
	screen.select_client(ORGS, 0)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a clamped lender opinion reads the top face",
		over.relationship_text() == "Opinion +5" and over.filled_face() == 5,
		"got %s at %d" % [over.relationship_text(), over.filled_face()])
	await _shut(host, screen)


static func _case_locked(res: Dictionary, host: Node) -> void:
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	var screen: ClientViewer = await _open(host, ORGS)
	var over: ClientOverview = screen.overview
	TestFixtures.check(res, "an unpaid guild cannot see the client opinion",
		not over.entitled() and over.lock_shown(),
		"got entitled %s locked %s" % [str(over.entitled()), str(over.lock_shown())])
	TestFixtures.check(res, "the lock names the upgrade that opens it",
		over.lock().upgrade_id == "customer" and over.lock().tier == 1,
		"got %s tier %d" % [over.lock().upgrade_id, over.lock().tier])
	TestFixtures.check(res, "the lock hides the opinion value and the faces",
		not over.rel_value.visible and not over.faces_row.visible,
		"got %s and %s" % [str(over.rel_value.visible), str(over.faces_row.visible)])
	TestFixtures.check(res, "the lock copy names the feature",
		over.lock().copy_lines().size() > 0
			and over.lock().feature == "client relationships",
		"got %s" % over.lock().feature)
	var sent: Array[Dictionary] = []
	var relay := func(target: Dictionary) -> void: sent.append(target)
	GameState.go_to_plans_requested.connect(relay)
	over.lock().take_me_there.emit({"upgrade": "customer"})
	await host.get_tree().process_frame
	TestFixtures.check(res, "the lock sends the guild to the plans screen",
		sent.size() == 1 and String(sent[0].get("upgrade", "")) == "customer",
		"got %s" % str(sent))
	GameState.go_to_plans_requested.disconnect(relay)
	SubscriptionManager.reset()
	await host.get_tree().process_frame
	TestFixtures.check(res, "buying the upgrade opens the opinion at once",
		not over.lock_shown() and over.rel_value.visible,
		"got locked %s" % str(over.lock_shown()))
	await _shut(host, screen)


static func _case_signals(res: Dictionary, host: Node) -> void:
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	var screen: ClientViewer = await _open(host, ORGS)
	var over: ClientOverview = screen.overview
	var asked: Array[int] = []
	var invested: Array[int] = []
	screen.contract_requested.connect(func(entry_id: int) -> void: asked.append(entry_id))
	screen.invest_requested.connect(func(company_id: int) -> void: invested.append(company_id))
	var rows: Array[ClientRecentRow] = over.recent_rows()
	rows[1].press()
	await host.get_tree().process_frame
	TestFixtures.check(res, "pressing a listed history row asks for its contract",
		asked.size() == 1 and asked[0] == 3, "got %s" % str(asked))
	TestFixtures.check(res, "the contract opens in a popup", screen.popup() != null,
		"got no popup")
	rows[0].press()
	await host.get_tree().process_frame
	TestFixtures.check(res, "an unlisted history row asks for nothing",
		asked.size() == 1, "got %s" % str(asked))
	if screen.popup() != null:
		screen.popup().close()
	await host.get_tree().process_frame
	TestFixtures.check(res, "closing the popup lets the next one open",
		screen.popup() == null, "got a popup")
	over.set_stock(1, PackedFloat32Array([10.0, 20.0]))
	await host.get_tree().process_frame
	over.chart_button().pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "pressing the chart asks to invest in that company",
		invested.size() == 1 and invested[0] == 1, "got %s" % str(invested))
	var invest_popup: ViewerPopup = screen.popup()
	TestFixtures.check(res, "pressing the chart opens the invest popup", invest_popup != null,
		"got no popup")
	var content: Node = null
	if invest_popup != null:
		content = invest_popup.current()
	TestFixtures.check(res, "the popup holds a finance viewer opened on the invest page",
		content is FinanceViewer and (content as FinanceViewer).invest_only,
		"got %s" % str(content))
	over.chart_button().pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a second press opens no second popup and asks nothing again",
		screen.popup() == invest_popup and invested.size() == 1,
		"got %s with %s" % [str(screen.popup()), str(invested)])
	if screen.popup() != null:
		screen.popup().close()
	await host.get_tree().process_frame
	TestFixtures.check(res, "closing the invest popup clears it", screen.popup() == null,
		"got a popup")
	await _shut(host, screen)


static func _case_show_client(res: Dictionary, host: Node) -> void:
	var screen: ClientViewer = await _open(host, PEOPLE)
	TestFixtures.check(res, "an unknown company cannot be shown",
		not screen.show_client(-1) and not screen.show_client(40),
		"a bad company answered")
	TestFixtures.check(res, "showing a company opens the orgs tab", screen.show_client(3),
		"the call refused")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the shown company is the selected one",
		screen.current_tab() == ORGS and screen.selected().index == 3,
		"got %s at %d" % [str(screen.current_tab()), screen.selected().index])
	TestFixtures.check(res, "a company with no contract is pinned into the list",
		screen.pinned() == 3 and screen.list.rows().size() == 4
			and screen.list.count_text() == "4/4",
		"got pin %d with %d rows" % [screen.pinned(), screen.list.rows().size()])
	var filter: ClientFilterButton = screen.list.filter_button()
	TestFixtures.check(res, "the pinned company adds its own filter rows",
		filter.row_count() == 7, "got %d rows" % filter.row_count())
	filter.toggle_sub(ClientRegistry.ORG_SUB)
	await host.get_tree().process_frame
	TestFixtures.check(res, "hiding the pinned sub type drops it again",
		screen.list.rows().size() == 3 and screen.list.count_text() == "3/4",
		"got %d rows reading %s" % [screen.list.rows().size(), screen.list.count_text()])
	TestFixtures.check(res, "showing the company again clears the filter that hid it",
		screen.show_client(3), "the call refused")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the cleared filter brings the pinned company back",
		screen.list.rows().size() == 4 and not filter.is_changed()
			and screen.selected().index == 3,
		"got %d rows changed %s" % [screen.list.rows().size(), str(filter.is_changed())])
	TestFixtures.check(res, "the pinned company keeps its fallback name",
		screen.overview.name_text() == "Company 4 Name",
		"got %s" % screen.overview.name_text())
	await _shut(host, screen)


static func _case_from_game(res: Dictionary, host: Node) -> void:
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	var reg: ClientRegistry = ClientRegistry.from_game()
	TestFixtures.check(res, "the live registry seeds one org per stock company",
		reg.count(ORGS) == StockMarket.company_count(),
		"got %d of %d" % [reg.count(ORGS), StockMarket.company_count()])
	TestFixtures.check(res, "the live registry seeds the people and the places",
		reg.count(PEOPLE) == ContractIssuer.PEOPLE and reg.count(PLACES) == ContractIssuer.PLACES,
		"got %d and %d" % [reg.count(PEOPLE), reg.count(PLACES)])
	var bad: Array[String] = []
	for entry: BoardEntry in GameState.board.entries:
		if entry == null:
			continue
		if reg.issuer_of(entry.id) == null:
			bad.append(str(entry.id))
	TestFixtures.check(res, "every board entry finds its client", bad.is_empty(),
		TestFixtures.detail(bad, 10, "entry"))
	var listed: int = 0
	for kind: StringName in ClientRegistry.KINDS:
		for client: ClientData in reg.clients(kind):
			listed += client.offered
	TestFixtures.check(res, "the live tallies cover every board entry",
		listed == GameState.board.entries.size(),
		"got %d of %d" % [listed, GameState.board.entries.size()])
	var screen: ClientViewer = VIEWER.instantiate()
	host.add_child(screen)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the viewer opens on the live game with rows",
		screen.list.rows().size() > 0 and screen.selected() != null,
		"got %d rows" % screen.list.rows().size())
	TestFixtures.check(res, "the live viewer opens on the orgs tab",
		screen.current_tab() == ORGS, "got %s" % str(screen.current_tab()))
	GameState.contracts_changed.emit()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "a board change rebuilds the registry",
		screen.list.rows().size() > 0, "got %d rows" % screen.list.rows().size())
	await _shut(host, screen)
