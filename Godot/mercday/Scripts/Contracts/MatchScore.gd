class_name MatchScore

#One match score for display and run: matched boost rows, the leader's share, per-merc and team nets, stars.

const SHARE_ROWS := 2
const STAR_ANCHORS: Array[float] = [0.1, 5.0, 15.0, 30.0, 46.0]
const KIND_ORDER: Array[String] = ["knowledge", "tool", "tradition"]


#Every knowledge, tool and tradition boost row of the contract, strongest first.
static func rows(contract: ContractData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if contract == null:
		return out
	for name: String in contract.knowledge_boosts:
		out.append({"kind": "knowledge", "name": name, "pct": float(contract.knowledge_boosts[name])})
	for name: String in contract.tool_boosts:
		out.append({"kind": "tool", "name": name, "pct": float(contract.tool_boosts[name])})
	for name: String in contract.tradition_boosts:
		out.append({"kind": "tradition", "name": name, "pct": float(contract.tradition_boosts[name])})
	out.sort_custom(_stronger)
	return out


#The leader's two strongest matched knowledge or tool rows; tradition rows are never shared.
static func leader_rows(contract: ContractData, leader: MercenaryData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if leader == null:
		return out
	for row: Dictionary in ContractModifiers.matched_rows(contract, leader):
		if String(row["kind"]) != "tradition":
			out.append(row)
	out.sort_custom(_stronger)
	return out.slice(0, SHARE_ROWS)


static func merc_rows(contract: ContractData, merc: MercenaryData, leader: MercenaryData = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var own: Array[Dictionary] = ContractModifiers.matched_rows(contract, merc)
	for row: Dictionary in own:
		var mine: Dictionary = row.duplicate()
		mine["shared"] = false
		out.append(mine)
	if merc == null or leader == null or leader == merc:
		return out
	for row: Dictionary in leader_rows(contract, leader):
		if ContractModifiers.has_row(own, row):
			continue
		var lent: Dictionary = row.duplicate()
		lent["shared"] = true
		out.append(lent)
	return out


#The run's net for this merc on the contract's primary event, with the contract boosts on as the run has them.
static func merc_net(contract: ContractData, team: Array[MercenaryData], merc: MercenaryData,
		leader: MercenaryData = null) -> float:
	if merc == null:
		return 0.0
	var solo: Array[MercenaryData] = [merc]
	var record: Dictionary = ContractModifiers.apply(contract, solo)
	var net: float = OverallSuccess.net_percent(contract, team, merc, primary_event(contract), leader)
	ContractModifiers.revert(record)
	return net


static func team_net(contract: ContractData, team: Array[MercenaryData], leader: MercenaryData = null) -> float:
	var total: float = 0.0
	var count: int = 0
	for merc: MercenaryData in team:
		if merc == null:
			continue
		total += merc_net(contract, team, merc, leader)
		count += 1
	return total / float(count) if count > 0 else 0.0


static func solo_net(contract: ContractData, merc: MercenaryData) -> float:
	var solo: Array[MercenaryData] = [merc]
	return merc_net(contract, solo, merc, null)


#An anchor gives its half star; a net strictly between two anchors gives the whole star between them.
static func stars(net: float) -> float:
	for i: int in range(STAR_ANCHORS.size()):
		if is_equal_approx(net, STAR_ANCHORS[i]):
			return 0.5 + float(i)
	if net > STAR_ANCHORS[STAR_ANCHORS.size() - 1]:
		return 5.0
	var whole: int = 0
	for anchor: float in STAR_ANCHORS:
		if net > anchor:
			whole += 1
	return float(whole)


#Highest solo net; ties by name, then uid; null for an empty team.
static func default_leader(contract: ContractData, team: Array[MercenaryData]) -> MercenaryData:
	var best: MercenaryData = null
	var best_net: float = 0.0
	for merc: MercenaryData in team:
		if merc == null:
			continue
		var net: float = solo_net(contract, merc)
		if best == null or net > best_net or (is_equal_approx(net, best_net) and _before(merc, best)):
			best = merc
			best_net = net
	return best


static func feature_count(merc: MercenaryData, contracts: Array[ContractData]) -> int:
	var count: int = 0
	for contract: ContractData in contracts:
		count += ContractModifiers.matched_rows(contract, merc).size()
	return count


static func primary_event(contract: ContractData) -> EventData:
	if contract == null or contract.assigned_primary_event == "":
		return null
	return ContractLibrary.event(contract.assigned_primary_event)


static func _stronger(a: Dictionary, b: Dictionary) -> bool:
	if not is_equal_approx(float(a["pct"]), float(b["pct"])):
		return float(a["pct"]) > float(b["pct"])
	var ka: int = KIND_ORDER.find(String(a["kind"]))
	var kb: int = KIND_ORDER.find(String(b["kind"]))
	if ka != kb:
		return ka < kb
	return String(a["name"]) < String(b["name"])


static func _before(a: MercenaryData, b: MercenaryData) -> bool:
	if a.merc_name != b.merc_name:
		return a.merc_name < b.merc_name
	return a.merc_uid < b.merc_uid
