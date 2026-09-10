class_name ContractGenerator

#Builds one contract instance from a contract type: locations, description, primary event and mishaps.

const SAVE_DIR := "user://contracts"
const MAX_LOCATION_ROLLS := 100


static func generate(contract_type_name: String = "") -> ContractData:
	var config: ContractConfig = ContractLibrary.config()
	var name: String = contract_type_name if contract_type_name != "" else config.default_contract_type
	var contract: ContractData = ContractLibrary.contract_type(name)
	if contract == null:
		push_error("ContractGenerator: unknown contract type '%s'" % name)
		return null
	contract.reward_notes = config.default_reward_notes
	contract.max_mercs = config.default_max_mercs
	if contract.difficulty <= 0.0:
		contract.difficulty = roll_difficulty()
	var a: LocationData = pick_location_a()
	var b: LocationData = pick_location_b(a)
	contract.location_a = a.location_name if a != null else ""
	contract.location_b = b.location_name if b != null else ""
	contract.description = fill_description(contract.description_template, a, b)
	var primary: String = ""
	if config.test_primary_event != "" and contract.primary_event_pool.has(config.test_primary_event):
		primary = config.test_primary_event
	elif not contract.primary_event_pool.is_empty():
		primary = contract.primary_event_pool[randi() % contract.primary_event_pool.size()]
	else:
		push_warning("ContractGenerator: %s has no primary event" % name)
	contract.assigned_primary_event = primary
	contract.rolled_mishaps.assign(MishapRoller.roll(contract, config))
	contract.team_uids.clear()
	contract.status = "Draft"
	return contract


#1 to 5 in steps of 0.5, uniform over the nine values, until Difficulty is authored.
static func roll_difficulty() -> float:
	return float(randi_range(2, 10)) / 2.0


static func pick_location_a() -> LocationData:
	var keys: Array = DataManager.locations.keys()
	if keys.is_empty():
		return null
	for _i: int in range(MAX_LOCATION_ROLLS):
		var loc: LocationData = DataManager.locations[keys[randi() % keys.size()]] as LocationData
		if loc != null and ContractTerrain.area_name_for(loc) != "":
			return loc
	push_error("ContractGenerator: no location with terrain after %d rolls" % MAX_LOCATION_ROLLS)
	for key: String in keys:
		var loc: LocationData = DataManager.locations[key] as LocationData
		if loc != null and ContractTerrain.area_name_for(loc) != "":
			return loc
	return null


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
	return template.replace("[location_a.demonym]", name_a).replace("[location_b.demonym]", name_b)


#Writes the instance to path, or to the first free user://contracts/contract_<n>.tres when path is empty.
static func save_instance(contract: ContractData, path: String = "") -> String:
	if contract == null or not ContractLibrary.config().save_generated_contracts:
		return ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	var target: String = path
	if target == "":
		var n: int = 1
		while FileAccess.file_exists("%s/contract_%d.tres" % [SAVE_DIR, n]):
			n += 1
		target = "%s/contract_%d.tres" % [SAVE_DIR, n]
	var err: int = ResourceSaver.save(contract, target)
	if err != OK:
		push_warning("ContractGenerator: could not save %s (error %d)" % [target, err])
		return ""
	return ProjectSettings.globalize_path(target)


static func _display_name(loc: LocationData) -> String:
	if loc == null:
		return "Unknown"
	if loc.demonym != "":
		return loc.demonym
	return loc.location_name
