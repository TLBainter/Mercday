class_name BoardEntry
extends RefCounted

#One posting on the contract board: the contract plus everything the board and the views show beside it.
#The Q29 fields are placeholders rolled once at posting and never rerolled.

const STATUS_DRAFT := "Draft"
const STATUS_ACTIVE := "Active"
const STATUS_SUCCEEDED := "Succeeded"
const STATUS_FAILED := "Failed"
const STATUS_EXPIRED := "Expired"
const STATUS_REJECTED := "Rejected"

const URGENCY_NONE := 0
const URGENCY_LOW := 1
const URGENCY_HIGH := 2

const URGENCY_HIGH_HOURS := 24.0
const URGENCY_LOW_HOURS := 48.0

var id: int = 0
var contract: ContractData = null
var posted_minute: int = 0
var expires_minute: int = 0
var distance_km: int = 0
var completion_hours: int = 0
var issuer: String = ""
var issuer_type: int = 0
var merc_min: int = 1
var image: String = ""
var status: String = STATUS_DRAFT
var scheduler: ContractScheduler = null
var verdict: String = ""
var log_lines: Array[String] = []
#The minute the posting closed (Expired, Rejected or settled); -1 while it is open or active (B4).
var closed_minute: int = -1


#Hours before the posting runs out; negative once the deadline has passed.
func hours_left(now: int) -> float:
	return maxf(0.0, float(expires_minute - now) / float(CampaignClock.MINUTES_PER_HOUR))


#2 with under a day left, 1 with under two days, 0 otherwise.
func urgency(now: int) -> int:
	var left: float = hours_left(now)
	if left < URGENCY_HIGH_HOURS:
		return URGENCY_HIGH
	if left < URGENCY_LOW_HOURS:
		return URGENCY_LOW
	return URGENCY_NONE


#The most mercs this contract takes; 0 until the contract is generated.
func merc_max() -> int:
	return contract.max_mercs if contract != null else 0


func is_open() -> bool:
	return status == STATUS_DRAFT


func is_active() -> bool:
	return status == STATUS_ACTIVE


func contract_type() -> String:
	return contract.contract_type if contract != null else ""
