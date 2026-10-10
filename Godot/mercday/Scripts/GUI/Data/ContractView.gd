class_name ContractView extends RefCounted

#Everything the Contract Viewer, the list and the Dispatch Window read about one board entry.
#The expiry, the distance and the issuer live on the entry, the rest on the contract it carries.
#Sample rows fill only the design prototype fields and leave contract null.

#Hard cap on the crew a contract may take (Q37).
const MERC_CAP: int = 5
#What a settled posting reads as while its results sit unopened (README I5).
const UNCLAIMED_TEXT: String = "Complete"
const UNCLAIMED_COLOR: Color = GuiColors.ORANGE
#Issuer type words, in ClientRegistry.KIND_LABELS order.
const KIND_WORDS: Array[String] = ["person", "place", "org"]

var entry_id: int = -1
var name: String = ""
var type: String = ""
var difficulty: float = 0.0
var contract_level: int = 0
var reward: int = 0
var distance_km: int = 0
var completion_hours: int = 0
var expires_in_hours: float = 0.0
#The campaign minute the posting closes; -1 when the view has no deadline.
var expires_minute: int = -1
var status: int = GuiTypes.ContractStatus.AVAILABLE
var urgency: int = GuiTypes.Urgency.NONE
var merc_min: int = 1
var merc_max: int = MERC_CAP
var description: String = ""
var location: String = ""
var issuer: String = ""
var issuer_type: String = ""
#The person class of a person row; blank otherwise.
var issuer_class: String = ""
var story: bool = false
#A Local contract runs at the guild home: distance 0, no travel and no field respite.
var local: bool = false
var image: String = ""
var recommended_knowledges: Array[BonusEntry] = []
var recommended_tools: Array[BonusEntry] = []
var recommended_traditions: Array[BonusEntry] = []
#"" while the contract is still open, else "Succeeded" or "Failed".
var outcome: String = ""
#The minute the posting closed; -1 while it is open or active.
var closed_minute: int = -1
#The Guild Ads campaign that posted the contract; 0 for the board's own draws.
var campaign_id: int = 0
var contract: ContractData = null


static func from_entry(entry: BoardEntry, now: int) -> ContractView:
	var view := ContractView.new()
	if entry == null:
		return view
	view.entry_id = entry.id
	view.distance_km = entry.distance_km
	view.completion_hours = entry.completion_hours
	view.expires_in_hours = entry.hours_left(now)
	view.expires_minute = entry.expires_minute
	view.urgency = entry.urgency(now)
	view.merc_min = maxi(1, entry.merc_min)
	view.issuer = entry.issuer
	view.issuer_type = entry.issuer_type
	view.image = entry.image
	view.status = status_from_text(entry.status)
	view.outcome = outcome_from_text(entry.status)
	view.closed_minute = entry.closed_minute
	view.campaign_id = entry.campaign_id
	var data: ContractData = entry.contract
	if data == null:
		return view
	view.contract = data
	view.type = data.contract_type
	view.story = data.story
	view.local = data.local
	view.issuer_class = data.issuer.strip_edges() if data.issuer_type == "person" else ""
	view.location = data.location_a
	view.name = posting_title(data)
	view.difficulty = data.difficulty
	view.contract_level = data.contract_level
	view.reward = data.reward_notes
	view.description = data.description
	view.merc_max = clampi(data.max_mercs, view.merc_min, MERC_CAP)
	view.recommended_knowledges = BonusEntry.from_boosts(data.knowledge_boosts)
	view.recommended_tools = BonusEntry.from_boosts(data.tool_boosts)
	view.recommended_traditions = BonusEntry.from_boosts(data.tradition_boosts)
	_fill_from_check_row(view, data)
	return view


#D4 (#721): a check style posting fills each empty list from its Checks.tsv row; positive traditions only.
static func _fill_from_check_row(view: ContractView, data: ContractData) -> void:
	if data.style != "check" or not data.completion.begins_with(CheckStore.PREFIX):
		return
	var parsed: Dictionary = CheckStore.parse(CheckStore.find(data.completion))
	if parsed.is_empty():
		return
	if view.recommended_knowledges.is_empty():
		view.recommended_knowledges = BonusEntry.from_parsed(parsed["knowledges"], "percent", false)
	if view.recommended_tools.is_empty():
		view.recommended_tools = BonusEntry.from_parsed(parsed["tools"], "percent", false)
	if view.recommended_traditions.is_empty():
		view.recommended_traditions = BonusEntry.from_parsed(parsed["traditions"], "value", true)


#Reads a sample_data.json contract row; the sample type is a placeholder number, not a type name.
static func from_sample(d: Dictionary) -> ContractView:
	var view := ContractView.new()
	view.entry_id = int(d.get("id", -1))
	view.name = str(d.get("name", ""))
	view.type = str(d.get("type", ""))
	view.difficulty = float(d.get("difficulty", 0.0))
	view.contract_level = int(d.get("recommended_level", 0))
	view.reward = int(d.get("reward", 0))
	view.distance_km = int(d.get("distance_km", 0))
	view.completion_hours = int(d.get("completion_hours", 0))
	view.expires_in_hours = float(d.get("expires_in_hours", 0.0))
	view.expires_minute = int(d.get("expires_minute", -1))
	view.status = status_from_text(str(d.get("status", "Available")))
	view.outcome = outcome_from_text(str(d.get("status", "")))
	view.urgency = urgency_from_text(str(d.get("urgency", "None")))
	view.merc_min = maxi(1, int(d.get("merc_min", 1)))
	view.merc_max = clampi(int(d.get("merc_max", MERC_CAP)), view.merc_min, MERC_CAP)
	view.description = str(d.get("description", ""))
	view.location = str(d.get("location", ""))
	view.issuer = str(d.get("issuer", ""))
	view.issuer_type = kind_word(d.get("issuer_type", ""))
	view.story = bool(d.get("story", false))
	view.local = bool(d.get("local", false))
	view.image = str(d.get("image", ""))
	view.closed_minute = int(d.get("closed_minute", -1))
	view.campaign_id = int(d.get("campaign_id", 0))
	var rec: Dictionary = d.get("recommended", {}) as Dictionary
	view.recommended_knowledges = BonusEntry.from_samples(rec.get("knowledges", []) as Array)
	view.recommended_tools = BonusEntry.from_samples(rec.get("tools", []) as Array)
	view.recommended_traditions = BonusEntry.from_samples(rec.get("traditions", []) as Array)
	return view


#A KIND_WORDS word; a sample number maps 1 person, 2 place, 3 org, then repeats; anything else is "".
static func kind_word(value: Variant) -> String:
	if value is String:
		return value if KIND_WORDS.has(value) else ""
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		return KIND_WORDS[posmod(int(value) - 1, 3)]
	return ""


#Q27, D107: a posting is titled by its Contract Name alone; a blank name reads as its type.
static func posting_title(data: ContractData) -> String:
	if data == null:
		return ""
	return data.contract_name if data.contract_name != "" else data.contract_type


#Q31: a finished contract is Completed whichever way it went; the verdict lives in outcome.
static func status_from_text(text: String) -> int:
	match text.strip_edges():
		"Active":
			return GuiTypes.ContractStatus.ACTIVE
		"Succeeded", "Failed", "Completed":
			return GuiTypes.ContractStatus.COMPLETED
		"Expired":
			return GuiTypes.ContractStatus.EXPIRED
		"Rejected":
			return GuiTypes.ContractStatus.REJECTED
	return GuiTypes.ContractStatus.AVAILABLE


static func outcome_from_text(text: String) -> String:
	var trimmed: String = text.strip_edges()
	return trimmed if trimmed == "Succeeded" or trimmed == "Failed" else ""


static func urgency_from_text(text: String) -> int:
	match text.strip_edges():
		"Low":
			return GuiTypes.Urgency.LOW
		"High":
			return GuiTypes.Urgency.HIGH
	return GuiTypes.Urgency.NONE


func status_text() -> String:
	return GuiTypes.status_text(status)


#A settled posting nobody has opened the results of, whichever way it went (README I5). The seen
#set lives on GameState, so a sample row and an open posting are never unclaimed.
func is_unclaimed() -> bool:
	if entry_id < 0 or status != GuiTypes.ContractStatus.COMPLETED:
		return false
	return GameState.is_unclaimed(entry_id)


#The status every screen draws. The game never stores FAILED: it is the display status of a
#posting that was failed and whose results the player has already claimed.
func shown_status() -> int:
	if status == GuiTypes.ContractStatus.COMPLETED and outcome == "Failed" and not is_unclaimed():
		return GuiTypes.ContractStatus.FAILED
	return status


func shown_status_text() -> String:
	return UNCLAIMED_TEXT if is_unclaimed() else GuiTypes.status_text(shown_status())


func shown_status_color() -> Color:
	return UNCLAIMED_COLOR if is_unclaimed() else GuiTypes.status_color(shown_status())


#The mark the list row and the detail portrait wear for this posting.
func shown_mark() -> int:
	return StatusMark.Mark.BANG if is_unclaimed() else StatusMark.mark_for(shown_status())


func difficulty_name() -> String:
	return GuiTypes.difficulty_name(difficulty)


func difficulty_color() -> Color:
	return GuiTypes.difficulty_color(difficulty)
