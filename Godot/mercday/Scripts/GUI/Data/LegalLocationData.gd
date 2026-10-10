class_name LegalLocationData extends RefCounted

#One place the guild can buy permits for. scope is the Operations Permits tier the location needs
#(1 most nations, 2 all nations, 3 another Domain) and relationship is the location's opinion of
#the guild on the standard -5 to +5 meter. The engine already owns the name LocationData.

var id: int = 0
var name: String = ""
var nation: String = ""
var scope: int = 1
var ops_cost: int = 0
var tele_cost: int = 0
var avg_difficulty: float = 0.0
var relationship: int = 0
var rules: Array[String] = []


static func from_dict(d: Dictionary) -> LegalLocationData:
	var loc := LegalLocationData.new()
	loc.id = int(d.get("id", 0))
	loc.name = str(d.get("name", ""))
	loc.nation = str(d.get("nation", ""))
	loc.scope = int(d.get("scope", 1))
	loc.ops_cost = int(d.get("ops_cost", 0))
	loc.tele_cost = int(d.get("tele_cost", 0))
	loc.avg_difficulty = float(d.get("avg_difficulty", 0.0))
	loc.relationship = int(d.get("relationship", 0))
	loc.rules.assign(d.get("rules", []))
	return loc


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "nation": nation, "scope": scope, "ops_cost": ops_cost,
		"tele_cost": tele_cost, "avg_difficulty": avg_difficulty, "relationship": relationship,
		"rules": rules.duplicate()}
