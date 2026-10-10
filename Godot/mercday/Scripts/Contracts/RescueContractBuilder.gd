class_name RescueContractBuilder

#Turns a missing merc into a Rescue contract and hands its battle the captive, the captors and the mode.

const CONTRACT_TYPE := "Rescue"
const KIND_KIDNAPPED := "kidnapped"
const KIND_FLED := "fled"
const KIND_PRISONER := "prisoner"
const PRISON_EVENT := "Prison Break"

#uid to record for callers that cannot reach the ContractRun before ContractManager builds it.
static var pending_records: Dictionary = {}


#Every held captive plus every pooled merc, newest pool entries last.
static func candidates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in MercPool.captives():
		out.append(entry)
	for merc: MercenaryData in MercPool.list():
		out.append(record_for(merc, KIND_FLED))
	return out


static func record_for(merc: MercenaryData, kind: String) -> Dictionary:
	var crew: Array[MercenaryData] = []
	return {
		"merc": merc,
		"kind": kind,
		"contract_type": "",
		"location": "",
		"stamp": "",
		"crew": crew,
		"crew_source": "",
	}


static func build(record: Dictionary) -> ContractData:
	var merc: MercenaryData = record.get("merc", null)
	if merc == null:
		return null
	if merc.merc_uid <= 0:
		merc.merc_uid = CampaignKnowledge.next_uid()
	var contract: ContractData = ContractGenerator.generate(CONTRACT_TYPE)
	if contract == null:
		return null
	var kind: String = String(record.get("kind", KIND_FLED))
	contract.assigned_primary_event = RescueSystem.EVENT_NAME
	contract.rescue_merc_uid = merc.merc_uid
	contract.rescue_kind = kind
	contract.rescue_merc_name = merc.merc_name
	var place: String = contract.location_a if contract.location_a != "" else "parts unknown"
	contract.description = "Rescue %s, %s, from the dungeon beneath %s." % [merc.merc_name,
		kind_words(kind), place]
	pending_records[merc.merc_uid] = record
	return contract


static func kind_words(kind: String) -> String:
	if kind == KIND_KIDNAPPED:
		return "kidnapped by bandits"
	return "who fled a battle"


#The captive, its captors and the mode for one rescue battle; {} when the uid names nobody.
static func battle_setup(run: ContractRun, event: EventData = null) -> Dictionary:
	if run == null or run.contract == null:
		return {}
	var record: Dictionary = find_record(run, run.contract.rescue_merc_uid)
	if record.is_empty():
		return {}
	var captive: MercenaryData = record.get("merc", null)
	if captive == null:
		return {}
	var row: EventData = event if event != null else ContractLibrary.event(RescueSystem.EVENT_NAME)
	var kind: String = String(record.get("kind", KIND_FLED))
	var enemies: Array[MercenaryData] = captors(row, run, record, kind)
	if enemies.is_empty():
		return {}
	captive.off_field = false
	var mode: String = choose_mode(run.living_team(), enemies)
	return {"captive": captive, "mode": mode, "enemies": enemies, "kind": kind, "record": record}


#A generated prisoner, the event's captors and the mode for one prison break battle; {} when nothing was built.
static func prison_setup(run: ContractRun, contract: ContractData, event: EventData) -> Dictionary:
	if run == null or event == null:
		return {}
	var req: OpponentRequest = ContractTarget.request(contract.target if contract != null else "",
		run.living_team(), contract)
	req.count = 1
	req.tag = PRISON_EVENT
	var made: Array[MercenaryData] = OpponentGenerator.generate(req)
	if made.is_empty():
		return {}
	var captive: MercenaryData = made[0]
	var enemies: Array[MercenaryData] = EnemyTeamBuilder.build(event, run, 0)
	if enemies.is_empty():
		return {}
	captive.off_field = false
	var mode: String = choose_mode(run.living_team(), enemies)
	run.emit("PRISON BREAK: %s held; %d captors, %s mode" % [captive.merc_name, enemies.size(), mode])
	return {"captive": captive, "mode": mode, "enemies": enemies, "kind": KIND_PRISONER, "record": {}}


#The pool first, then a pooled merc with that uid, then whatever the caller staged.
static func find_record(run: ContractRun, uid: int) -> Dictionary:
	if uid <= 0:
		return {}
	var held: Dictionary = MercPool.captive_record(uid)
	if not held.is_empty():
		return held
	for merc: MercenaryData in MercPool.list():
		if merc != null and merc.merc_uid == uid:
			return record_for(merc, KIND_FLED)
	if run != null and not run.rescue_record.is_empty():
		return run.rescue_record
	if pending_records.has(uid):
		return pending_records[uid]
	return {}


#Kept captors fill the front of the team and fresh bandits make up the event's counter.
static func captors(event: EventData, run: ContractRun, record: Dictionary,
		kind: String) -> Array[MercenaryData]:
	var crew: Array[MercenaryData] = []
	for member: Variant in record.get("crew", []):
		if member is MercenaryData and not (member as MercenaryData).is_dead:
			crew.append(member)
	var built: Array[MercenaryData] = []
	if event != null:
		built.assign(EnemyTeamBuilder.build(event, run, 0))
	if kind != KIND_KIDNAPPED or crew.is_empty():
		return built
	for member: MercenaryData in crew:
		heal(member)
	if built.size() <= crew.size():
		return crew
	var out: Array[MercenaryData] = []
	out.assign(crew)
	for i: int in range(crew.size(), built.size()):
		out.append(built[i])
	return out


#Kept captors fight fresh; campaign states are left where they are.
static func heal(merc: MercenaryData) -> void:
	if merc == null:
		return
	merc.off_field = false
	BattleState.restore_pools(merc, false)


static func choose_mode(team: Array, enemies: Array) -> String:
	var config: ContractConfig = ContractLibrary.config()
	var forced: String = config.rescue_mode if config != null else ""
	if forced == RescueSystem.MODE_COMBAT or forced == RescueSystem.MODE_STEALTH:
		return forced
	if enemies.size() > team.size():
		return RescueSystem.MODE_STEALTH
	return RescueSystem.MODE_COMBAT


static func complete(run: ContractRun, ro: Dictionary, kind: String = "") -> void:
	if run == null or ro.is_empty():
		return
	var captive: MercenaryData = ro.get("captive", null)
	if captive == null:
		return
	if kind == KIND_PRISONER:
		if bool(ro.get("success", false)):
			run.emit("PRISONER FREED: %s" % captive.merc_name)
		elif not bool(ro.get("captive_alive", true)):
			run.emit("PRISONER LOST: %s died in the dungeon." % captive.merc_name)
		else:
			run.emit("PRISONER HELD: %s remains imprisoned." % captive.merc_name)
		return
	if bool(ro.get("success", false)):
		release(captive.merc_uid)
		if not run.rescued.has(captive):
			run.rescued.append(captive)
		run.emit("RESCUED: %s rejoins the company." % captive.merc_name)
		return
	if not bool(ro.get("captive_alive", true)):
		release(captive.merc_uid)
		run.emit("LOST: %s died in the dungeon." % captive.merc_name)
		return
	run.emit("RESCUE FAILED: %s remains captive." % captive.merc_name)


#Off the missing lists either way; a harness record is in neither and that is no error.
static func release(uid: int) -> void:
	pending_records.erase(uid)
	var back: MercenaryData = null
	if MercPool.captive_record(uid).is_empty():
		back = MercPool.take(uid)
	else:
		back = MercPool.take_captive(uid)
	RestSystem.idle_restart(back, CampaignClock.now())
