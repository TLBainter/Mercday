class_name ClientRegistry
extends RefCounted
#Placeholder client layer: the contract board and the stock companies stand in for a real
#issuer system, so every client name, sub type, location and distance here is filler.

const KINDS: Array[StringName] = [&"people", &"places", &"orgs"]
const ORG_KIND: StringName = &"orgs"
const KIND_LABELS: Array[String] = ["Person", "Place", "Org"]
const PEOPLE_SUBS: Array[String] = ["Commoner", "Aristocrat", "Mercenary", "Noble"]
const PLACE_SUBS: Array[String] = ["Town", "Village", "Fort", "Port", "Temple", "Mine", "Keep",
	"Outpost"]
const ORG_SUB: String = "Company"
const LOCATIONS: Array[String] = ["Buern", "Aerdis", "Aldurstein", "Zukei", "Rossade", "Copari",
	"Miliim", "Vaernebo", "Cyfrolaef", "Gledd Sea", "Marric Ocean", "Weird", "Umbra", "Hel"]
const ABOUT: Array[String] = ["person desc.", "place desc.", "org desc."]
const SORTS: Array[Dictionary] = [
	{"key": &"recent", "label": "Most Recent"},
	{"key": &"offered", "label": "Contracts Offered"},
	{"key": &"accepted", "label": "Contracts Accepted"},
	{"key": &"paid", "label": "Notes Earned"},
]
const KM_MIN: int = 40
const KM_SPAN: int = 860
const REL_MIN: int = -5
const REL_MAX: int = 5
#Seat seed steps per seat index and per kind index (people 0, places 1, orgs 2): the two rolls, then the location.
const SEED_INDEX_STEP: int = 17
const SEED_KIND_STEP: int = 101
const LOC_INDEX_STEP: int = 5
const LOC_KIND_STEP: int = 3
const ACTIVE_TEXT: String = "Active"
const DONE_TEXT: String = "Completed"
const FAILED_TEXT: String = "Failed"
const SUCCESS_TEXT: String = "Succeeded"
const ACTIVE_COLOR: Color = GuiColors.LIGHT_BLUE
const DONE_COLOR: Color = GuiColors.GREEN
const FAILED_COLOR: Color = GuiColors.RED

var _people: Array[ClientData] = []
var _places: Array[ClientData] = []
var _orgs: Array[ClientData] = []


#seats maps an entry id to its issuer {"kind", "index"}; a view whose id it does not name goes by issuer_of.
func build(views: Array[ContractView], companies: Array[Dictionary],
		unclaimed: Array[int] = [], paid: Dictionary = {}, listed: Array[int] = [],
		lender_rel: Dictionary = {}, seats: Dictionary = {}) -> void:
	_people = _seed_list(&"people", ContractIssuer.PEOPLE, companies, lender_rel)
	_places = _seed_list(&"places", ContractIssuer.PLACES, companies, lender_rel)
	_orgs = _seed_list(&"orgs", companies.size(), companies, lender_rel)
	var rows: Array[ContractView] = views.duplicate()
	rows.sort_custom(_newest_first)
	for view: ContractView in rows:
		if view == null:
			continue
		var target: ClientData = _route(view.entry_id, seats)
		if target == null:
			continue
		_tally(target, view, unclaimed.has(view.entry_id), paid, listed)
	for kind: StringName in KINDS:
		for row: ClientData in _list_of(kind):
			if row.accepted > 0:
				row.avg_difficulty = row.avg_difficulty / float(row.accepted)
			else:
				row.avg_difficulty = 0.0


func clients(kind: StringName) -> Array[ClientData]:
	var out: Array[ClientData] = _list_of(kind).duplicate()
	return out


func client(kind: StringName, index: int) -> ClientData:
	var rows: Array[ClientData] = _list_of(kind)
	if index < 0 or index >= rows.size():
		return null
	return rows[index]


func count(kind: StringName) -> int:
	return _list_of(kind).size()


#The client an entry belongs to, the one placeholder issuer rule StockMarket also uses.
func issuer_of(entry_id: int) -> ClientData:
	var kind: StringName = ContractIssuer.kind_of(entry_id)
	var n: int = count(kind)
	if n < 1:
		return null
	return client(kind, ContractIssuer.index_of(entry_id, n))


#An entry's issuer as {"kind", "index", "seat"}: the seat it carries, else the id rule mapped onto the seat layout.
static func issuer_of_entry(entry: BoardEntry) -> Dictionary:
	if entry == null:
		return {}
	var seat: int = entry.issuer_id
	if ContractIssuer.kind_of_seat(seat).is_empty():
		seat = IssuerOpinion.seat_for_entry(entry.id)
	return {"kind": StringName(ContractIssuer.kind_of_seat(seat)), "index": ContractIssuer.index_of_seat(seat),
		"seat": seat}


func sorted(kind: StringName, sort_key: StringName, descending: bool,
		hidden_subs: Array[String] = [], hidden_locations: Array[String] = [],
		pinned: int = -1) -> Array[ClientData]:
	var out: Array[ClientData] = []
	for row: ClientData in _list_of(kind):
		if not _kept(row, pinned):
			continue
		if hidden_subs.has(row.sub) or hidden_locations.has(row.location):
			continue
		out.append(row)
	var down: bool = descending
	var key: StringName = sort_key
	out.sort_custom(func(a: ClientData, b: ClientData) -> bool: return _before(a, b, key, down))
	return out


func total(kind: StringName, pinned: int = -1) -> int:
	var n: int = 0
	for row: ClientData in _list_of(kind):
		if _kept(row, pinned):
			n += 1
	return n


func sub_types(kind: StringName, pinned: int = -1) -> Array[String]:
	var out: Array[String] = []
	for row: ClientData in _list_of(kind):
		if not _kept(row, pinned):
			continue
		if not row.sub.is_empty() and not out.has(row.sub):
			out.append(row.sub)
	return out


func location_names(kind: StringName, pinned: int = -1) -> Array[String]:
	var out: Array[String] = []
	for row: ClientData in _list_of(kind):
		if not _kept(row, pinned):
			continue
		if not row.location.is_empty() and not out.has(row.location):
			out.append(row.location)
	out.sort()
	return out


static func sort_labels() -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in SORTS:
		out.append(String(row.get("label", "")))
	return out


static func sort_key_at(index: int) -> StringName:
	if index < 0 or index >= SORTS.size():
		return &"recent"
	return StringName(SORTS[index].get("key", &"recent"))


static func kind_index(kind: StringName) -> int:
	return KINDS.find(kind)


static func kind_label(kind: StringName) -> String:
	var i: int = KINDS.find(kind)
	if i < 0:
		return ""
	return KIND_LABELS[i]


#Everything the live game can tell us about clients today: board entries, stock companies and
#the lender relationships, each one reached only when the build carries it.
static func from_game() -> ClientRegistry:
	var reg := ClientRegistry.new()
	var views: Array[ContractView] = []
	var listed: Array[int] = []
	var paid: Dictionary = {}
	var seats: Dictionary = {}
	var now: int = CampaignClock.now()
	if GameState.board != null:
		for entry: BoardEntry in GameState.board.entries:
			if entry == null:
				continue
			var view: ContractView = ContractView.from_entry(entry, now)
			views.append(view)
			seats[view.entry_id] = issuer_of_entry(entry)
			if GameState.has_result(view.entry_id):
				var res: ContractResultData = GameState.result_of(view.entry_id)
				if res != null:
					paid[view.entry_id] = res.reward
	for view: ContractView in GameState.contracts:
		listed.append(view.entry_id)
	reg.build(views, market_companies(), GameState.unclaimed_ids(), paid, listed,
		lender_relationships(), seats)
	if IssuerOpinion.seat_count() > 0:
		reg._apply_faces()
	return reg


#The stock companies when the build carries the market autoload, else no company at all.
static func market_companies() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var market: Node = autoload_node(&"StockMarket")
	if market == null or not market.has_method("company_count"):
		return out
	if not market.has_method("company"):
		return out
	var n: int = int(market.call("company_count"))
	for k: int in range(n):
		var row: Variant = market.call("company", k)
		if row is Dictionary:
			out.append(row)
	return out


#Lender name to relationship, so a company that also lends keeps one opinion of the guild.
static func lender_relationships() -> Dictionary:
	var out: Dictionary = {}
	var finance: Node = autoload_node(&"FinanceManager")
	if finance == null or not finance.has_method("lenders"):
		return out
	var rows: Variant = finance.call("lenders")
	if not (rows is Array):
		return out
	for row: Variant in rows:
		if not (row is Dictionary):
			continue
		var d: Dictionary = row
		var lender: String = String(d.get("name", ""))
		if lender.is_empty() or not d.has("rel"):
			continue
		out[lender] = int(d["rel"])
	return out


static func autoload_node(node_name: StringName) -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	var tree: SceneTree = loop
	if tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(node_name))


#The relationship a seat starts at: the lender's own rel for an org whose company lends, else the seeded roll.
static func seed_relationship(kind: String, index: int, companies: Array, lender_rel: Dictionary) -> int:
	if StringName(kind) == ORG_KIND:
		var lender: String = String(_company(companies, index).get("lender", ""))
		if not lender.is_empty() and lender_rel.has(lender):
			return clampi(int(lender_rel[lender]), REL_MIN, REL_MAX)
	return clampi(roundi(_seat_rolls(kind, index)[1] * 10.0 - 4.0), REL_MIN, REL_MAX)


#A seat's display name: the company's own name for an org the market carries, else the filler name.
static func seat_name(kind: String, index: int, companies: Array) -> String:
	if StringName(kind) == ORG_KIND:
		var company_name: String = String(_company(companies, index).get("name", ""))
		if not company_name.is_empty():
			return company_name
		return "%s %d Name" % [ORG_SUB, index + 1]
	if StringName(kind) == &"places":
		return "%s %d Name" % [KIND_LABELS[1], index + 1]
	return "%s %d Name" % [KIND_LABELS[0], index + 1]


func _list_of(kind: StringName) -> Array[ClientData]:
	if kind == &"places":
		return _places
	if kind == &"orgs":
		return _orgs
	return _people


func _seed_list(kind: StringName, n: int, companies: Array[Dictionary],
		lender_rel: Dictionary) -> Array[ClientData]:
	var out: Array[ClientData] = []
	for i: int in range(maxi(n, 0)):
		out.append(_seed_client(kind, i, companies, lender_rel))
	return out


func _seed_client(kind: StringName, index: int, companies: Array[Dictionary],
		lender_rel: Dictionary) -> ClientData:
	var row := ClientData.new()
	row.kind = kind
	row.index = index
	row.kind_label = kind_label(kind)
	var kind_at: int = maxi(kind_index(kind), 0)
	row.about = ABOUT[kind_at]
	row.location = LOCATIONS[posmod(index * LOC_INDEX_STEP + kind_at * LOC_KIND_STEP,
		LOCATIONS.size())]
	row.km = KM_MIN + int(_seat_rolls(String(kind), index)[0] * float(KM_SPAN))
	row.relationship = seed_relationship(String(kind), index, companies, lender_rel)
	row.name = seat_name(String(kind), index, companies)
	if kind == &"orgs":
		row.sub = _org_sub(index, companies)
	elif kind == &"places":
		row.sub = PLACE_SUBS[posmod(index, PLACE_SUBS.size())]
	else:
		row.sub = PEOPLE_SUBS[posmod(index, PEOPLE_SUBS.size())]
	return row


#A seat's two seeded draws in order: distance, then relationship.
static func _seat_rolls(kind: String, index: int) -> Array[float]:
	var rng := RandomNumberGenerator.new()
	rng.seed = index * SEED_INDEX_STEP + maxi(kind_index(StringName(kind)), 0) * SEED_KIND_STEP
	var out: Array[float] = [rng.randf()]
	out.append(rng.randf())
	return out


static func _company(companies: Array, index: int) -> Dictionary:
	if index < 0 or index >= companies.size() or not (companies[index] is Dictionary):
		return {}
	return companies[index]


#An org's sub type: its company's type when the market carries one, else ORG_SUB.
static func _org_sub(index: int, companies: Array) -> String:
	var company_type: String = String(_company(companies, index).get("type", ""))
	if company_type.is_empty():
		return ORG_SUB
	return company_type


#The client a view belongs to: the seat the seats map gives its entry, else the id rule.
func _route(entry_id: int, seats: Dictionary) -> ClientData:
	var seat: Variant = seats.get(entry_id, null)
	if not (seat is Dictionary):
		return issuer_of(entry_id)
	var at: Dictionary = seat
	return client(StringName(at.get("kind", &"")), int(at.get("index", -1)))


#Every client row whose seat the opinion store holds reads that seat's face instead of its seeded roll.
func _apply_faces() -> void:
	for kind: StringName in KINDS:
		for row: ClientData in _list_of(kind):
			var seat: int = ContractIssuer.seat_id(String(kind), row.index)
			if IssuerOpinion.has_seat(seat):
				row.relationship = IssuerOpinion.face(seat)


func _tally(row: ClientData, view: ContractView, unclaimed: bool, paid: Dictionary,
		listed: Array[int]) -> void:
	row.offered += 1
	var is_active: bool = view.status == GuiTypes.ContractStatus.ACTIVE
	var is_done: bool = view.status == GuiTypes.ContractStatus.COMPLETED
	if not is_active and not is_done:
		return
	row.accepted += 1
	row.avg_difficulty += view.difficulty
	if row.recency < view.entry_id:
		row.recency = view.entry_id
	var result: String = ACTIVE_TEXT
	var color: Color = ACTIVE_COLOR
	if unclaimed:
		result = ContractView.UNCLAIMED_TEXT
		color = ContractView.UNCLAIMED_COLOR
	elif is_done:
		if view.outcome == FAILED_TEXT:
			result = FAILED_TEXT
			color = FAILED_COLOR
			row.failed += 1
		else:
			result = DONE_TEXT
			color = DONE_COLOR
			if view.outcome == SUCCESS_TEXT:
				row.succeeded += 1
				row.paid += int(paid.get(view.entry_id, view.reward))
	var row_name: String = view.name
	if row_name.is_empty():
		row_name = "Contract %d" % view.entry_id
	row.recent.append(ClientData.recent_row(view.entry_id, row_name, result, color,
		listed.has(view.entry_id)))


static func _kept(row: ClientData, pinned: int) -> bool:
	if row.offered > 0:
		return true
	return row.kind == ORG_KIND and row.index == pinned


static func _newest_first(a: ContractView, b: ContractView) -> bool:
	return a.entry_id > b.entry_id


static func _before(a: ClientData, b: ClientData, sort_key: StringName, down: bool) -> bool:
	if _reads_recency(sort_key) and (a.recency < 0) != (b.recency < 0):
		return b.recency < 0
	var av: float = _value(a, sort_key)
	var bv: float = _value(b, sort_key)
	if is_equal_approx(av, bv):
		return a.index < b.index
	if down:
		return av > bv
	return av < bv


#The recent key and every key _value does not know read recency, where a client that accepted
#nothing carries -1 and belongs at the end of the list in both directions.
static func _reads_recency(sort_key: StringName) -> bool:
	return sort_key != &"offered" and sort_key != &"accepted" and sort_key != &"paid"


static func _value(row: ClientData, sort_key: StringName) -> float:
	if sort_key == &"offered":
		return float(row.offered)
	if sort_key == &"accepted":
		return float(row.accepted)
	if sort_key == &"paid":
		return float(row.paid)
	return float(row.recency)
