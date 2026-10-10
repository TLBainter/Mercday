class_name SampleDataLoader

#Reads the design prototype seed at Resources/GUI/sample_data.json into the same view models the live
#engine fills, so a screen can be built and looked at before GameState runs.

const DEFAULT_PATH: String = "res://Resources/GUI/sample_data.json"


static func load_file(path: String) -> Dictionary:
	var out: Dictionary = {"mercs": [] as Array[MercView], "contracts": [] as Array[ContractView],
		"bank_notes": 0}
	var root: Dictionary = _read_json(path)
	if root.is_empty():
		return out
	var mercs: Array[MercView] = []
	for row: Variant in (root.get("mercs", []) as Array):
		if row is Dictionary:
			mercs.append(MercView.from_sample(row))
	var contracts: Array[ContractView] = []
	for row: Variant in (root.get("contracts", []) as Array):
		if row is Dictionary:
			contracts.append(ContractView.from_sample(row))
	out["mercs"] = mercs
	out["contracts"] = contracts
	out["bank_notes"] = int(root.get("bank_notes", 0))
	return out


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("SampleDataLoader: no file at %s" % path)
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("SampleDataLoader: %s is not a JSON object" % path)
		return {}
	return parsed
