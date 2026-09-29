class_name ApplicantData extends RefCounted

#One merc who applied to the guild, for the Hiring list and the applicant Merc Viewer. The trait
#fields hold the placeholder option names the filter chips carry, so one matcher reads both sides.
#uniq counts the traits no roster merc has and rarity says how rare they are; fit is the average
#fit with the open contracts that lack a good match. campaign_id is WALK_IN for an applicant who
#arrived on their own.

const STATUS_OPEN: String = "open"
const STATUS_HIRED: String = "hired"
const STATUS_REJECTED: String = "rejected"
const STATUS_COUNTERED: String = "countered"
const RARITIES: Array[String] = ["Common", "Uncommon", "Rare", "Very Rare"]
const STAT_KEYS: Array[String] = ["speed", "cognition", "vigor", "dexterity", "wile"]
const WALK_IN: int = -1

var id: int = 0
var name: String = ""
var tradition: String = ""
var level: int = 1
var ask: int = 0
var uniq: float = 0.0
var rarity: String = "Common"
var fit: float = 0.5
var campaign_id: int = WALK_IN
var unseen: bool = true
var ancestry: String = ""
var bloodline: String = ""
var age: int = 16
var heritage: String = ""
var criminality: String = ""
#Stat key to value, one entry per STAT_KEYS name.
var stats: Dictionary = {}
var tools: Array[String] = []
var knowledges: Array[String] = []
var status: String = STATUS_OPEN
#The counter-offer in flight: what was offered, the day it went out and the odds it went at.
var counter_offer: int = 0
var counter_day: int = -1
var counter_odds: int = 0
#The Odd Job crew sent with the counter-offer, by merc uid; empty when none went.
var counter_team: Array[int] = []
#How the last counter-offer landed; both stay false until one resolves.
var accepted_counter: bool = false
var refused_counter: bool = false


func rarity_rank() -> int:
	return maxi(0, RARITIES.find(rarity))


func is_walk_in() -> bool:
	return campaign_id == WALK_IN


func is_open() -> bool:
	return status == STATUS_OPEN


func stat(key: String) -> int:
	return int(stats.get(key, 0))


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "tradition": tradition, "level": level, "ask": ask,
		"uniq": uniq, "rarity": rarity, "fit": fit, "campaign_id": campaign_id,
		"unseen": unseen, "ancestry": ancestry, "bloodline": bloodline, "age": age,
		"heritage": heritage, "criminality": criminality, "stats": stats.duplicate(),
		"tools": tools.duplicate(), "knowledges": knowledges.duplicate(), "status": status,
		"counter_offer": counter_offer, "counter_day": counter_day,
		"counter_odds": counter_odds, "accepted_counter": accepted_counter,
		"refused_counter": refused_counter, "counter_team": counter_team.duplicate()}


static func from_dict(d: Dictionary) -> ApplicantData:
	var out := ApplicantData.new()
	out.id = int(d.get("id", 0))
	out.name = String(d.get("name", ""))
	out.tradition = String(d.get("tradition", ""))
	out.level = int(d.get("level", 1))
	out.ask = int(d.get("ask", 0))
	out.uniq = float(d.get("uniq", 0.0))
	out.rarity = String(d.get("rarity", "Common"))
	out.fit = float(d.get("fit", 0.5))
	out.campaign_id = int(d.get("campaign_id", WALK_IN))
	out.unseen = bool(d.get("unseen", true))
	out.ancestry = String(d.get("ancestry", ""))
	out.bloodline = String(d.get("bloodline", ""))
	out.age = int(d.get("age", 16))
	out.heritage = String(d.get("heritage", ""))
	out.criminality = String(d.get("criminality", ""))
	out.stats = (d.get("stats", {}) as Dictionary).duplicate()
	out.tools.assign(d.get("tools", []))
	out.knowledges.assign(d.get("knowledges", []))
	out.status = String(d.get("status", STATUS_OPEN))
	out.counter_offer = int(d.get("counter_offer", 0))
	out.counter_day = int(d.get("counter_day", -1))
	out.counter_odds = int(d.get("counter_odds", 0))
	out.accepted_counter = bool(d.get("accepted_counter", false))
	out.refused_counter = bool(d.get("refused_counter", false))
	out.counter_team.assign(d.get("counter_team", []))
	return out
