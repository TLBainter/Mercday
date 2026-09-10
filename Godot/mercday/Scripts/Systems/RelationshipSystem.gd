class_name RelationshipSystem

#Directional merc-to-merc relationship values held on the CampaignKnowledge autoload.
#Seeded from average Wile, then moved at contract end by proximity, aid and a Wile check.

const PROXIMITY_PACES := 5
const CHECK_FORMULA := "15"
const CHECK_TRIAL := 1

static var _near: Dictionary = {}   #uid pair key -> turns ended within PROXIMITY_PACES
static var _turns: Dictionary = {}  #uid pair key -> turns counted
static var _aided: Dictionary = {}  #uid pair key -> true once either merc aided the other


static func _key(uid_a: int, uid_b: int) -> String:
	return "%d:%d" % [mini(uid_a, uid_b), maxi(uid_a, uid_b)]


static func _tracked(merc: MercenaryData) -> bool:
	return merc != null and merc.merc_uid > 0


#Both directions open at the floored average Wile; a value already stored is never reseeded.
static func seed_pair(a: MercenaryData, b: MercenaryData) -> void:
	if not _tracked(a) or not _tracked(b) or a == b:
		return
	var start := int(floor((float(a.stats.get("wile", 0.0)) + float(b.stats.get("wile", 0.0))) / 2.0))
	if not CampaignKnowledge.has_relation(a.merc_uid, b.merc_uid):
		CampaignKnowledge.set_relation(a.merc_uid, b.merc_uid, start)
	if not CampaignKnowledge.has_relation(b.merc_uid, a.merc_uid):
		CampaignKnowledge.set_relation(b.merc_uid, a.merc_uid, start)


#What viewer feels toward target, seeding the pair on first read. -1 when either has no campaign uid.
static func value(viewer: MercenaryData, target: MercenaryData) -> int:
	if not _tracked(viewer) or not _tracked(target) or viewer == target:
		return -1
	seed_pair(viewer, target)
	return CampaignKnowledge.relation(viewer.merc_uid, target.merc_uid)


static func set_value(viewer: MercenaryData, target: MercenaryData, amount: int) -> void:
	if not _tracked(viewer) or not _tracked(target) or viewer == target:
		return
	CampaignKnowledge.set_relation(viewer.merc_uid, target.merc_uid, amount)


static func adjust(viewer: MercenaryData, target: MercenaryData, delta: int) -> void:
	if not _tracked(viewer) or not _tracked(target) or viewer == target:
		return
	seed_pair(viewer, target)
	CampaignKnowledge.adjust_relation(viewer.merc_uid, target.merc_uid, delta)


#Average of the two directions, floored. -1 when the pair is not tracked.
static func mutual_value(a: MercenaryData, b: MercenaryData) -> int:
	var ab := value(a, b)
	var ba := value(b, a)
	if ab < 0 or ba < 0:
		return -1
	return int(floor((float(ab) + float(ba)) / 2.0))


#The candidate merc feels closest to. Ties go to the first candidate in order.
static func best_ally(merc: MercenaryData, candidates: Array[MercenaryData]) -> MercenaryData:
	var best: MercenaryData = null
	var best_value := -1
	for other: MercenaryData in candidates:
		if other == merc or not _tracked(other):
			continue
		var v := value(merc, other)
		if v > best_value:
			best_value = v
			best = other
	return best


static func clear_tallies() -> void:
	_near.clear()
	_turns.clear()
	_aided.clear()


static func begin_contract(run: ContractRun) -> void:
	clear_tallies()
	if run == null:
		return
	for i: int in range(run.team.size()):
		for j: int in range(i + 1, run.team.size()):
			seed_pair(run.team[i], run.team[j])


#One tally per turn end for every living ally pair; both mercs of a pair feed the same counter.
static func on_turn_end(merc: MercenaryData, state: BattleState) -> void:
	if state == null or not _tracked(merc) or merc.is_dead:
		return
	for ally: MercenaryData in state.get_allies(merc):
		if not _tracked(ally):
			continue
		var k := _key(merc.merc_uid, ally.merc_uid)
		_turns[k] = int(_turns.get(k, 0)) + 1
		if state.distance_to(merc, ally) <= PROXIMITY_PACES:
			_near[k] = int(_near.get(k, 0)) + 1


static func record_aid(helper: MercenaryData, helped: MercenaryData) -> void:
	if not _tracked(helper) or not _tracked(helped) or helper == helped:
		return
	_aided[_key(helper.merc_uid, helped.merc_uid)] = true


static func _bond_def() -> Dictionary:
	return {
		"stat_keys": ["wile"],
		"circumstances": ["Presence (Wile)", "Speech (Wile)"],
		"knowledges": [],
		"tools": [],
		"formula": CHECK_FORMULA,
	}


#Folds the pooled contract tallies and each survivor's Wile check into the stored values.
static func end_contract(run: ContractRun) -> Array[String]:
	var lines: Array[String] = []
	if run == null:
		clear_tallies()
		return lines
	var survivors: Array[MercenaryData] = []
	for merc: MercenaryData in run.living_team():
		if _tracked(merc):
			survivors.append(merc)
	for i: int in range(survivors.size()):
		for j: int in range(i + 1, survivors.size()):
			var a: MercenaryData = survivors[i]
			var b: MercenaryData = survivors[j]
			seed_pair(a, b)
			var k := _key(a.merc_uid, b.merc_uid)
			var turns := int(_turns.get(k, 0))
			var near := int(_near.get(k, 0))
			if turns > 0 and near * 2 > turns:
				adjust(a, b, 1)
				adjust(b, a, 1)
				lines.append("RELATIONSHIP: %s and %s fought side by side (%d/%d turns within %d), +1 each" % [
					a.merc_name, b.merc_name, near, turns, PROXIMITY_PACES])
			if bool(_aided.get(k, false)):
				adjust(a, b, 1)
				adjust(b, a, 1)
				lines.append("RELATIONSHIP: %s and %s helped each other, +1 each" % [a.merc_name, b.merc_name])
	for roller: MercenaryData in survivors:
		var result: Dictionary = CheckSystem.make_check(roller, _bond_def())
		if int(result["successes"]) < CHECK_TRIAL and not bool(result.get("critical", false)):
			continue
		var raised := 0
		for other: MercenaryData in survivors:
			if other == roller:
				continue
			adjust(other, roller, 1)
			raised += 1
		if raised > 0:
			lines.append("RELATIONSHIP: %s won the camp over, +1 toward them from %d merc(s)" % [
				roller.merc_name, raised])
	clear_tallies()
	return lines
