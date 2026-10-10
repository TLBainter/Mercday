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
#Held in the contract pool off the board; a pooled entry has id 0.
const STATUS_POOLED := "Pooled"

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
#person, place or org: the row's Issuer Type, else the seat kind.
var issuer_type: String = ""
var merc_min: int = 1
var image: String = ""
var status: String = STATUS_DRAFT
var scheduler: ContractScheduler = null
var verdict: String = ""
var log_lines: Array[String] = []
#The minute the posting closed (Expired, Rejected or settled); -1 while it is open or active.
var closed_minute: int = -1
#The Guild Ads campaign that brought the posting in; 0 for the board's own draws.
var campaign_id: int = 0
#Seat in IssuerOpinion; -1 before a seat is picked.
var issuer_id: int = -1
#Campaign minute the contract must be complete by; 0 = unbounded.
var deadline_minute: int = 0
#Score 0..1 from distance, completion time, issuer satisfaction and matched elements.
var quality: float = 0.0
#How closely the posting meets its promo campaign's criteria; 0 for a board draw or a criterion-free campaign.
var match_pct: float = 0.0
#The 24 h expiry warning went out.
var reach_warned: bool = false
#The fastest affordable mode that still reaches in time, written by the GameState sweep.
var best_mode: String = ""
#A story contract: a failure returns it to the pool instead of retiring it.
var story: bool = false
#The round's value for the posting; equals contract.reward_notes once the round has built the entry.
var value: int = 0
var reject_count: int = 0
#Minute the entry entered the pool; -1 while it has never been pooled.
var pooled_minute: int = -1


#Hours before the posting runs out; 0 once the deadline has passed.
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


func is_open() -> bool:
	return status == STATUS_DRAFT


func is_active() -> bool:
	return status == STATUS_ACTIVE


func contract_type() -> String:
	return contract.contract_type if contract != null else ""
