class_name ContractGenerator

#Builds one contract instance from a contract type: locations, description, primary event and mishaps.

const MAX_LOCATION_ROLLS := 100
#The contract level is drawn this far either side of the guild average; every step doubles the difficulty.
const LEVEL_SPREAD_LOW := 0.75
const LEVEL_SPREAD_HIGH := 1.25
const LEVEL_SPREAD_STEP := 0.25
const MIN_DIFFICULTY := 0.5
const MAX_DIFFICULTY := 5.0
const EVENT_PREFIX := "event:"

#Above 0 every draw takes this difficulty instead of the roll; GameState sets it for the opening posting.
static var forced_difficulty: float = 0.0
#The last level gate line printed; tests read it.
static var gate_line: String = ""
#Re-picks a build path tries among the rows that fit the level it drew.
const GATE_RETRIES: int = 8


#A row fits a level inside its Level Min and Level Max; 0 at either end is no bound at that end.
static func level_ok(contract: ContractData, level: int) -> bool:
	if contract == null:
		return false
	return (contract.level_min <= 0 or contract.level_min <= level) \
		and (contract.level_max <= 0 or level <= contract.level_max)


static func note_no_row(level: int) -> void:
	gate_line = "BOARD: no row eligible at level %d" % level
	print(gate_line)


static func generate(contract_type_name: String = "") -> ContractData:
	var config: ContractConfig = ContractLibrary.config()
	var name: String = contract_type_name if contract_type_name != "" else config.default_contract_type
	var anywhere: Array[String] = []
	return _build(config, ContractLibrary.contract_type(name), "contract type '%s'" % name, anywhere)


#One contract row by its row name, built like generate().
static func generate_named(row: String) -> ContractData:
	var anywhere: Array[String] = []
	return _build(ContractLibrary.config(), ContractLibrary.contract(row), "contract row '%s'" % row, anywhere)


#Guild Ads work: a row drawn among the rows of type_names (every listed row when none is known), location A from
#location_pool() of location_names and the row's Possible Locations (else anywhere), and the difficulty held inside
#[diff_lo, diff_hi], then inside the row's own Difficulty Min and Max.
static func generate_for(type_names: Array[String], location_names: Array[String], diff_lo: float,
		diff_hi: float) -> ContractData:
	var known: Array[String] = ContractLibrary.contract_type_names()
	var types: Array[String] = []
	for type_name: String in type_names:
		if known.has(type_name) and not types.has(type_name):
			types.append(type_name)
	if types.is_empty():
		types = known
	var pool: Array[ContractData] = []
	for type_name: String in types:
		pool.append_array(ContractLibrary.contracts_for_type(type_name))
	if pool.is_empty():
		push_error("ContractGenerator: no contract types to draw from")
		return null
	var row: ContractData = pool[randi() % pool.size()]
	var contract: ContractData = _build(ContractLibrary.config(), row,
		"contract row '%s'" % ContractLibrary.row_name(row), location_names)
	if contract != null and not level_ok(contract, contract.contract_level):
		var level: int = contract.contract_level
		var fits: Array[ContractData] = []
		fits.assign(pool.filter(func(r: ContractData) -> bool: return level_ok(r, level)))
		if fits.is_empty():
			note_no_row(level)
			return null
		contract = null
		for _i: int in range(GATE_RETRIES):
			row = fits[randi() % fits.size()]
			contract = _build(ContractLibrary.config(), row, "contract row '%s'" % ContractLibrary.row_name(row),
				location_names, level)
			if contract != null:
				break
	if contract != null:
		contract.difficulty = snap_half(clampf(contract.difficulty, minf(diff_lo, diff_hi), maxf(diff_lo, diff_hi)))
		clamp_to_row(contract)
	return contract


#Every build step generate(), generate_named() and generate_for() share; label names a null contract in the error.
#When the caller names no location, the row's Possible Locations narrows location A; a blank row then leaves it to
#pick_location_a(). The description is a random one of the row's descriptions (else the template) with the location
#tokens and the %target%, %location% and %requestor% tags filled.
static func _build(config: ContractConfig, contract: ContractData, label: String,
		location_names: Array[String], level: int = 0) -> ContractData:
	if contract == null:
		push_error("ContractGenerator: unknown %s" % label)
		return null
	var average_level: float = GuildRoster.average_level()
	var level_drawn: int = level if level > 0 else roll_contract_level(average_level)
	return _finish(config, contract, level_drawn, -1.0, average_level, location_names)


#The daily round's path: a copy of row built at the given level and difficulty, location A among place when it can host.
static func generate_row(row: ContractData, level: int, difficulty: float, place: String) -> ContractData:
	if row == null:
		return null
	var places: Array[String] = []
	if place != "":
		places.append(place)
	return _finish(ContractLibrary.config(), row.duplicate(true) as ContractData, level, difficulty, 0.0, places)


#A set Max Mercs or Min Mercs is clamped to 1..MERC_CAP, a blank one takes the config default; min never passes max.
static func set_merc_range(config: ContractConfig, contract: ContractData) -> void:
	var cap: int = ContractDataValidator.MERC_CAP
	var high: int = clampi(contract.max_mercs, 1, cap) if contract.max_mercs > 0 else config.default_max_mercs
	var low: int = clampi(contract.min_mercs, 1, cap) if contract.min_mercs > 0 else config.board_merc_min
	contract.max_mercs = high
	contract.min_mercs = clampi(low, 1, maxi(1, high))


#A difficulty above 0 is set as given; otherwise apply_difficulty bends the row's own to the level; then clamp_to_row.
static func _finish(config: ContractConfig, contract: ContractData, level: int, difficulty: float,
		average_level: float, location_names: Array[String]) -> ContractData:
	var name: String = contract.contract_name
	contract.reward_notes = config.default_reward_notes
	set_merc_range(config, contract)
	contract.contract_level = level
	if difficulty > 0.0:
		contract.difficulty = difficulty
	else:
		apply_difficulty(contract, average_level)
	clamp_to_row(contract)
	var home: Array[String] = [GenConstants.GUILD_HOME]
	var a: LocationData = pick_location_among(home if contract.local else location_pool(contract, location_names))
	var b: LocationData = pick_location_b(a)
	contract.location_a = a.location_name if a != null else ""
	contract.location_b = b.location_name if b != null else ""
	contract.target_name = target_name(contract, a)
	contract.requestor_name = requestor_name(contract, a)
	contract.description = fill_tags(fill_description(pick_description(contract), a, b), contract.target_name,
		_place_name(a), contract.requestor_name)
	var primary: String = ""
	if contract.style == "check" and contract.completion.begins_with(CheckStore.PREFIX):
		primary = contract.completion
	elif contract.style == "event" and contract.completion.begins_with(EVENT_PREFIX):
		primary = contract.completion.substr(EVENT_PREFIX.length()).strip_edges()
	elif contract.style == "timeline":
		primary = TimelineRunner.PRIMARY_PREFIX + contract.contract_name
	elif config.test_primary_event != "" and contract.primary_event_pool.has(config.test_primary_event):
		primary = config.test_primary_event
	elif not contract.primary_event_pool.is_empty():
		primary = contract.primary_event_pool[randi() % contract.primary_event_pool.size()]
	else:
		push_warning("ContractGenerator: %s has no primary event" % name)
	contract.assigned_primary_event = primary
	contract.rolled_mishaps.assign(MishapRoller.roll(contract, config))
	contract.team_uids.clear()
	contract.status = BoardEntry.STATUS_DRAFT
	return contract


#A forced difficulty wins outright; else an authored cell or a roll is the base, bent to the level drawn at.
static func apply_difficulty(contract: ContractData, average_level: float) -> void:
	if contract == null:
		return
	if forced_difficulty > 0.0:
		contract.difficulty = snap_half(clampf(forced_difficulty, MIN_DIFFICULTY, MAX_DIFFICULTY))
		return
	var base: float = contract.difficulty if contract.difficulty > 0.0 else roll_difficulty()
	var ratio: float = 1.0 if average_level <= 0.0 else float(contract.contract_level) / average_level
	contract.difficulty = snap_half(clampf(base * difficulty_multiplier(ratio),
		MIN_DIFFICULTY, MAX_DIFFICULTY))


#A row with Difficulty Min and Max holds the difficulty inside them on the 0.5 grid.
static func clamp_to_row(contract: ContractData) -> void:
	if contract == null:
		return
	var lo: float = contract.difficulty_min
	var hi: float = contract.difficulty_max
	if lo > 0.0 and hi > 0.0 and hi >= lo:
		contract.difficulty = snap_half(clampf(contract.difficulty, lo, hi))


#0.5 to 5 in steps of 0.5, uniform over the ten values, until Difficulty is authored.
static func roll_difficulty() -> float:
	return float(randi_range(1, 10)) / 2.0


#The guild level the work is written for: a triangular draw a quarter either side of the roster average.
static func roll_contract_level(average_level: float) -> int:
	return maxi(1, int(roundf(OpponentGenerator.triangular(average_level * LEVEL_SPREAD_LOW,
		average_level, average_level * LEVEL_SPREAD_HIGH))))


#Work drawn above the guild's level is harder and work drawn below it is easier; each quarter doubles.
static func difficulty_multiplier(ratio: float) -> float:
	return pow(2.0, (ratio - 1.0) / LEVEL_SPREAD_STEP)


static func snap_half(x: float) -> float:
	return roundf(x * 2.0) / 2.0


static func pick_location_a() -> LocationData:
	var keys: Array = DataManager.locations.keys()
	if keys.is_empty():
		return null
	for _i: int in range(MAX_LOCATION_ROLLS):
		var loc: LocationData = DataManager.locations[keys[randi() % keys.size()]] as LocationData
		if loc != null and ContractTerrain.has_terrain(loc) and _hosts_contracts(loc):
			return loc
	push_error("ContractGenerator: no location with terrain after %d rolls" % MAX_LOCATION_ROLLS)
	for key: String in keys:
		var loc: LocationData = DataManager.locations[key] as LocationData
		if loc != null and ContractTerrain.has_terrain(loc) and _hosts_contracts(loc):
			return loc
	return null


#Location A's pool: the caller's names in the row's Possible Locations, else the row's list; a blank row keeps the caller's.
static func location_pool(contract: ContractData, location_names: Array[String]) -> Array[String]:
	if contract == null or contract.possible_locations.is_empty():
		return location_names
	var pool: Array[String] = []
	for location_name: String in location_names:
		if contract.possible_locations.has(location_name):
			pool.append(location_name)
	if pool.is_empty():
		return contract.possible_locations
	return pool


#Location A among the named places that can host a contract; pick_location_a() when none of them can.
static func pick_location_among(location_names: Array[String]) -> LocationData:
	if location_names.is_empty():
		return pick_location_a()
	var pool: Array[LocationData] = []
	for key: String in DataManager.locations.keys():
		var loc: LocationData = DataManager.locations[key] as LocationData
		if loc == null or not location_names.has(loc.location_name):
			continue
		if ContractTerrain.has_terrain(loc) and _hosts_contracts(loc):
			pool.append(loc)
	if pool.is_empty():
		return pick_location_a()
	return pool[randi() % pool.size()]


#Domains never host a contract for now.
static func _hosts_contracts(loc: LocationData) -> bool:
	if loc == null:
		return false
	return loc.location_type == "Country" or loc.location_type == "Settlement"


static func pick_location_b(a: LocationData) -> LocationData:
	var countries: Array[LocationData] = []
	for key: String in DataManager.locations.keys():
		var loc: LocationData = DataManager.locations[key] as LocationData
		if loc == null or loc.location_type != "Country" or loc.demonym == "":
			continue
		countries.append(loc)
	var candidates: Array[LocationData] = []
	for loc: LocationData in countries:
		if a != null:
			if loc.location_name == a.location_name or loc.demonym == a.demonym:
				continue
			if a.parent != null and loc.demonym == a.parent.demonym:
				continue
		candidates.append(loc)
	if not candidates.is_empty():
		return candidates[randi() % candidates.size()]
	push_warning("ContractGenerator: no opponent country for '%s'" % (a.location_name if a != null else ""))
	if not countries.is_empty():
		return countries[randi() % countries.size()]
	return null


static func fill_description(template: String, a: LocationData, b: LocationData) -> String:
	var name_a: String = _display_name(a)
	var name_b: String = _display_name(b)
	var text: String = template.replace("[location_a.demonym]", name_a)
	text = text.replace("[location_b.demonym]", name_b)
	text = text.replace("[location_a.name]", _place_name(a))
	return text.replace("[location_b.name]", _place_name(b))


#A random non-blank entry of the row's Descriptions.tsv texts, else its Description Template.
static func pick_description(contract: ContractData) -> String:
	var texts: Array[String] = []
	for text: String in contract.descriptions:
		if text.strip_edges() != "":
			texts.append(text)
	if texts.is_empty():
		return contract.description_template
	return texts[randi() % texts.size()]


#The %requestor% name: a person named for location A, else the place or organization of the Issuer cell.
static func requestor_name(contract: ContractData, a: LocationData) -> String:
	match contract.issuer_type:
		"person":
			return NameGenerator.generate(a) if a != null else ""
		"place", "org":
			return contract.issuer.strip_edges()
	return ""


#The %target% name; an npc Target gets a first name drawn for location A the way NPCGenerator names an NPC.
static func target_name(contract: ContractData, a: LocationData) -> String:
	var first: String = ""
	if a != null and str(ContractTarget.parse(contract.target)["source"]) == ContractTarget.SOURCE_NPC:
		var full: String = NameGenerator.generate(a)
		if full != "Unknown":
			first = full.split(" ")[0]
	return ContractTarget.display_name(contract.target, first)


#A blank value renders "Unknown", the _place_name convention.
static func fill_tags(text: String, target: String, place: String, requestor: String) -> String:
	var out: String = text.replace("%target%", _or_unknown(target))
	out = out.replace("%location%", _or_unknown(place))
	return out.replace("%requestor%", _or_unknown(requestor))


#The plain place name for the [location_?.name] tokens; the demonym tokens keep _display_name.
static func _place_name(loc: LocationData) -> String:
	if loc == null or loc.location_name == "":
		return "Unknown"
	return loc.location_name


static func _display_name(loc: LocationData) -> String:
	if loc == null:
		return "Unknown"
	if loc.demonym != "":
		return loc.demonym
	return loc.location_name


static func _or_unknown(value: String) -> String:
	var clean: String = value.strip_edges()
	return clean if clean != "" else "Unknown"
