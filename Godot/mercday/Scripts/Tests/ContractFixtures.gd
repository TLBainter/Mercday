class_name ContractFixtures
extends RefCounted

#Parties, contract runs and small readers the contract event suites and the event batches share.


#Empties the records and the flee state a fresh party starts from.
static func reset_party_state() -> void:
	CampaignKnowledge.clear()
	MercPool.clear()
	FleeSystem.reset()


#count roster mercs, registered as both the Beau roster and the guild roster.
static func roster_team(count: int) -> Array[MercenaryData]:
	var team: Array[MercenaryData] = []
	for i: int in range(count):
		team.append(HarnessRoster.roster_merc(i))
	BeauSystem.set_roster(team)
	GuildRoster.set_roster(team)
	return team


#Generated mercs of one level, registered as the guild roster.
static func generated_team(size: int, level: int) -> Array[MercenaryData]:
	var team: Array[MercenaryData] = []
	for i: int in range(size):
		var merc: MercenaryData = MercGenerator.generate(i)
		TestFixtures.set_level(merc, level)
		team.append(merc)
	GuildRoster.set_roster(team)
	return team


#A run on contract at location; team is copied into the run, so deaths in the run leave the caller's array whole.
static func contract_run(contract: ContractData, team: Array[MercenaryData], site: LocationData = null,
		line_fn: Callable = Callable()) -> ContractRun:
	var run := ContractRun.new()
	run.contract = contract
	run.team.assign(team)
	run.location = site
	run.line_fn = line_fn
	return run


#A run on an empty contract with this difficulty and unsavory flag; team is copied into the run.
static func bare_run(team: Array[MercenaryData], difficulty: float = 0.0, unsavory: bool = false) -> ContractRun:
	var contract := ContractData.new()
	contract.difficulty = difficulty
	contract.unsavory = unsavory
	return contract_run(contract, team)


#The loaded location of that name, or null.
static func location(location_name: String) -> LocationData:
	return DataManager.locations.get(location_name, null) as LocationData


#A run at the loaded location of that name whose team is the given array itself.
static func run_at(team: Array[MercenaryData], location_name: String) -> ContractRun:
	var run := ContractRun.new()
	run.location = location(location_name)
	run.team = team
	return run


#The contract's own place when it has a terrain, else a wilderness place: a random one or the first.
static func contract_location(contract: ContractData, places: Array[LocationData], pick_random: bool) -> LocationData:
	var loc: LocationData = location(contract.location_a)
	if loc != null and ContractTerrain.has_terrain(loc):
		return loc
	if places.is_empty():
		return loc
	return places[randi() % places.size()] if pick_random else places[0]


#Index of the first line that starts with prefix, or -1.
static func index_of_prefix(lines: Array[String], prefix: String) -> int:
	for i: int in range(lines.size()):
		if lines[i].begins_with(prefix):
			return i
	return -1


static func utility(utility_name: String) -> UtilityTraitData:
	var u := UtilityTraitData.new()
	u.utility_name = utility_name
	return u


static func trad_name(merc: MercenaryData) -> String:
	if merc == null or merc.tradition == null:
		return "null"
	return merc.tradition.tradition_name


static func event_name(event: EventData) -> String:
	return "null" if event == null else event.event_name
