class_name SheetFixtures extends RefCounted

#Frozen byte copies of the fourteen sheets the contract builder reads; the builder suites copy and read these.
#A later stage that needs a new row or column replaces the sheet file and its MD5 entry in the same change.

const DIR: String = "res://Scripts/Tests/Fixtures/Sheets"
const MD5: Dictionary = {
	"Areas.tsv": "167044ff4946f8c4842ede742ce438d2",
	"Buildings.tsv": "d8507f927db8068b621d5dc8b537624a",
	"Checks.tsv": "fe9497cff63c8e7f82d397df24027e5a",
	"Circumstances.tsv": "19920f09d878736b11f577aa46ba3a9d",
	"Contracts.tsv": "378e7071cf71ac0f4eec38f2ca01dff6",
	"Descriptions.tsv": "cd6ec35378cad1abe0affbe99f4da1c7",
	"Events.tsv": "d2726b7bbe1393da76699c2aa7a08597",
	"Knowledges and Tools.tsv": "6395caf0573b79691e10112cb01f8909",
	"Locations.tsv": "19ff04cc2d32c38359bdad2b4535ed6c",
	"NPCs.tsv": "396b635869c4bf5e605016172769f6a9",
	"Organizations.tsv": "03af15fda1fe65c7692cd8c9ed45cc56",
	"Stats.tsv": "868e03bf29c57654236ad670974fae94",
	"Traditions.tsv": "1dd2725cba91f7c1a37a9fe66ac6b87e",
	"Types.tsv": "27c2da24b67ea5ceffb3a6424e8e3065",
}


#The fixture copy of one live sheet path, matched by file name.
static func path(live_path: String) -> String:
	return DIR.path_join(live_path.get_file())


#One line per missing or changed fixture sheet, in file name order; empty when every sheet is intact.
static func integrity() -> Array[String]:
	var out: Array[String] = []
	var names: Array = MD5.keys()
	names.sort()
	for file_name: String in names:
		var file_path: String = DIR.path_join(file_name)
		if not FileAccess.file_exists(file_path):
			out.append("%s: missing" % file_name)
			continue
		var got: String = FileAccess.get_md5(file_path)
		var want: String = String(MD5[file_name])
		if got != want:
			out.append("%s: md5 %s, expected %s" % [file_name, got, want])
	return out


#Points the ContractBuilderData path vars at the fixture sheets for read-only cases; callers end with reset_paths().
static func point_at_fixtures() -> void:
	ContractBuilderData.contracts_path = path(ContractBuilderData.CONTRACTS_PATH)
	ContractBuilderData.types_path = path(ContractBuilderData.TYPES_PATH)
	ContractBuilderData.organizations_path = path(ContractBuilderData.ORGANIZATIONS_PATH)
	ContractBuilderData.locations_path = path(ContractBuilderData.LOCATIONS_PATH)
	ContractBuilderData.descriptions_path = path(ContractBuilderData.DESCRIPTIONS_PATH)
	ContractBuilderData.areas_path = path(ContractBuilderData.AREAS_PATH)
	ContractBuilderData.buildings_path = path(ContractBuilderData.BUILDINGS_PATH)
	ContractBuilderData.npcs_path = path(ContractBuilderData.NPCS_PATH)
	ContractBuilderData.traditions_path = path(ContractBuilderData.TRADITIONS_PATH)
	ContractBuilderData.checks_path = path(ContractBuilderData.CHECKS_PATH)
	ContractBuilderData.stats_path = path(ContractBuilderData.STATS_PATH)
	ContractBuilderData.circumstances_path = path(ContractBuilderData.CIRCUMSTANCES_PATH)
	ContractBuilderData.knowledges_path = path(ContractBuilderData.KNOWLEDGES_PATH)
	ContractBuilderData.events_path = path(ContractBuilderData.EVENTS_PATH)
