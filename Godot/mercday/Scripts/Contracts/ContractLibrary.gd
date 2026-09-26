class_name ContractLibrary

#Loads the generated ContractData and EventData resources; every load returns a mutable duplicate.

const _CONFIG := preload("res://Scripts/Contracts/Resources/ContractConfig.tres")


static func config() -> ContractConfig:
	return _CONFIG


#Loads one generated resource; null with a pushed error when it is missing.
static func _load(path: String, kind: String) -> Resource:
	if not ResourceLoader.exists(path):
		push_error("ContractLibrary: missing %s resource %s" % [kind, path])
		return null
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)


static func contract_type(name: String) -> ContractData:
	var path: String = ContractResourceBuilder.contract_path(name)
	var res: Resource = _load(path, "contract")
	if not (res is ContractData):
		if res != null:
			push_error("ContractLibrary: %s is not a ContractData" % path)
		return null
	return (res as ContractData).duplicate(true) as ContractData


static func event(name: String) -> EventData:
	var path: String = ContractResourceBuilder.event_path(name)
	var res: Resource = _load(path, "event")
	if not (res is EventData):
		if res != null:
			push_error("ContractLibrary: %s is not an EventData" % path)
		return null
	return (res as EventData).duplicate(true) as EventData


static func contract_type_names() -> Array[String]:
	return _names_in(ContractResourceBuilder.CONTRACT_DIR, "contract_type")


static func event_names() -> Array[String]:
	return _names_in(ContractResourceBuilder.EVENT_DIR, "event_name")


#Every .tres in one generated directory, sorted by the named field; a row without that field is skipped.
static func _names_in(dir_path: String, field: String) -> Array[String]:
	var out: Array[String] = []
	for file_name: String in _tres_files(dir_path):
		var res: Resource = ResourceLoader.load(dir_path + "/" + file_name, "",
			ResourceLoader.CACHE_MODE_IGNORE)
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

