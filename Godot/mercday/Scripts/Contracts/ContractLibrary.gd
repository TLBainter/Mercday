class_name ContractLibrary

#Loads the generated ContractData and EventData resources; every load returns a mutable duplicate.
#After a harness build_all with writes off, the builder's memory dictionaries stand in for the .tres files.

const _CONFIG := preload("res://Scripts/Contracts/Resources/ContractConfig.tres")

#Test harness only: when not empty, only these row names count as contract rows.
static var pinned_names: Array[String] = []


static func config() -> ContractConfig:
	return _CONFIG


#True while the last build_all kept its rows in memory instead of the .tres files.
static func _in_memory() -> bool:
	return not ContractResourceBuilder.memory_contracts.is_empty()


#The memory dictionary that stands in for one generated directory.
static func _memory_for(dir_path: String) -> Dictionary:
	if dir_path == ContractResourceBuilder.event_dir:
		return ContractResourceBuilder.memory_events
	return ContractResourceBuilder.memory_contracts


#Loads one generated resource, the memory row of that name first; null with a pushed error when it is missing.
static func _load(path: String, kind: String, name: String = "") -> Resource:
	if _in_memory():
		var held: Dictionary = _memory_for(path.get_base_dir())
		if held.has(name):
			return held[name] as Resource
	if not ResourceLoader.exists(path):
		push_error("ContractLibrary: missing %s resource %s" % [kind, path])
		return null
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)


#The template row of a type: the row named after it, else its first row by name; null when no listed row has it.
static func contract_type(name: String) -> ContractData:
	var held: bool = ContractResourceBuilder.memory_contracts.has(name) if _in_memory() \
		else ResourceLoader.exists(ContractResourceBuilder.contract_path(name))
	if held:
		var named: ContractData = contract(name)
		if named != null and named.contract_type == name and _listed(named):
			return named
	var best: ContractData = null
	for data: ContractData in contracts_for_type(name):
		if best == null or row_name(data) < row_name(best):
			best = data
	if best == null:
		push_error("ContractLibrary: no contract row of type %s" % name)
	return best


#One generated contract by its Contract Name.
static func contract(name: String) -> ContractData:
	var path: String = ContractResourceBuilder.contract_path(name)
	var res: Resource = _load(path, "contract", name)
	if not (res is ContractData):
		if res != null:
			push_error("ContractLibrary: %s is not a ContractData" % path)
		return null
	return (res as ContractData).duplicate(true) as ContractData


#A "check:" name returns a Checks.tsv stand-in, or null when no row has it; a "timeline:" name its stand-in.
static func event(name: String) -> EventData:
	if name.begins_with(CheckStore.PREFIX):
		return CheckStore.stand_in(name)
	if name.begins_with(TimelineRunner.PRIMARY_PREFIX):
		return TimelineRunner.stand_in(name)
	var path: String = ContractResourceBuilder.event_path(name)
	var res: Resource = _load(path, "event", name)
	if not (res is EventData):
		if res != null:
			push_error("ContractLibrary: %s is not an EventData" % path)
		return null
	return (res as EventData).duplicate(true) as EventData


#True when a generated event row has this name; never pushes an error.
static func has_event(name: String) -> bool:
	if name == "" or name.begins_with(CheckStore.PREFIX) or name.begins_with(TimelineRunner.PRIMARY_PREFIX):
		return false
	var path: String = ContractResourceBuilder.event_path(name)
	if _in_memory() and _memory_for(path.get_base_dir()).has(name):
		return true
	return ResourceLoader.exists(path)


#The row name of one contract: its contract_name, else its contract_type; "" for null.
static func row_name(data: ContractData) -> String:
	if data == null:
		return ""
	return data.contract_name if data.contract_name != "" else data.contract_type


#True when a contract counts as a contract row: it has a type and the pin allows its row name.
static func _listed(data: ContractData) -> bool:
	return data != null and data.contract_type != "" and (pinned_names.is_empty() or pinned_names.has(row_name(data)))


#Distinct row names of the generated contracts that the pin allows, sorted.
static func row_names() -> Array[String]:
	var out: Array[String] = []
	for data: ContractData in _all_contracts():
		var name: String = row_name(data)
		if _listed(data) and not out.has(name):
			out.append(name)
	out.sort()
	return out


#Distinct contract_type values of the listed contract rows, sorted.
static func contract_type_names() -> Array[String]:
	var out: Array[String] = []
	for data: ContractData in _all_contracts():
		if _listed(data) and not out.has(data.contract_type):
			out.append(data.contract_type)
	out.sort()
	return out


#contract_name of every generated contract, sorted; a blank name reads as its contract_type.
static func contract_names() -> Array[String]:
	var out: Array[String] = []
	for data: ContractData in _all_contracts():
		out.append(data.contract_name if data.contract_name != "" else data.contract_type)
	out.sort()
	return out


#Every listed contract row of one type, in file order.
static func contracts_for_type(type_name: String) -> Array[ContractData]:
	var out: Array[ContractData] = []
	for data: ContractData in _all_contracts():
		if data.contract_type == type_name and _listed(data):
			out.append(data)
	return out


#Uncached loads, so each one is already a mutable copy; memory rows are duplicated, in file name order.
static func _all_contracts() -> Array[ContractData]:
	var out: Array[ContractData] = []
	if _in_memory():
		for res: Resource in _memory_rows(ContractResourceBuilder.memory_contracts):
			out.append(res.duplicate(true) as ContractData)
		return out
	var dir_path: String = ContractResourceBuilder.contract_dir
	for file_name: String in _tres_files(dir_path):
		var res: Resource = ResourceLoader.load(dir_path + "/" + file_name, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res is ContractData:
			out.append(res as ContractData)
	return out


static func event_names() -> Array[String]:
	return _names_in(ContractResourceBuilder.event_dir, "event_name")


#Every .tres in one generated directory, sorted by the named field; a row without that field is skipped.
static func _names_in(dir_path: String, field: String) -> Array[String]:
	var out: Array[String] = []
	var rows: Array[Resource] = []
	if _in_memory():
		rows = _memory_rows(_memory_for(dir_path))
	else:
		for file_name: String in _tres_files(dir_path):
			rows.append(ResourceLoader.load(dir_path + "/" + file_name, "", ResourceLoader.CACHE_MODE_IGNORE))
	for res: Resource in rows:
		if res == null:
			continue
		var value: Variant = res.get(field)
		if value is String and String(value) != "":
			out.append(String(value))
	out.sort()
	return out


static func events_for(contract_type_name: String, event_type: String) -> Array[EventData]:
	var out: Array[EventData] = []
	var contract: ContractData = contract_type(contract_type_name)
	if contract == null:
		return out
	var pool: Array[String] = contract.mishap_pool if event_type == "Mishap" else contract.primary_event_pool
	for name: String in pool:
		var data: EventData = event(name)
		if data == null:
			push_warning("ContractLibrary: %s pool references missing event %s" % [contract_type_name, name])
			continue
		out.append(data)
	return out


#The resources of one memory dictionary in the order _tres_files lists their files.
static func _memory_rows(held: Dictionary) -> Array[Resource]:
	var by_file: Dictionary = {}
	for name: String in held:
		by_file[ContractResourceBuilder.file_stem(name) + ".tres"] = held[name]
	var files: Array[String] = []
	files.assign(by_file.keys())
	files.sort()
	var out: Array[Resource] = []
	for file_name: String in files:
		out.append(by_file[file_name] as Resource)
	return out


static func _tres_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(dir_path):
		return out
	for file_name: String in DirAccess.get_files_at(dir_path):
		var name: String = file_name.trim_suffix(".remap")
		if name.get_extension() == "tres":
			out.append(name)
	out.sort()
	return out


#Runs one fully substituted expression; null with the pushed message when it fails to parse or run.
static func eval_expression(expr: String, message: String) -> Variant:
	var e := Expression.new()
	if e.parse(expr) != OK:
		push_error(message)
		return null
	var result: Variant = e.execute([])
	if e.has_execute_failed():
		push_error(message)
		return null
	return result

