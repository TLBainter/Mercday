class_name ContractScheduler
extends RefCounted

#Drives one contract a game-clock step at a time: travel out, the event chain, the closing rest,
#travel back. Every phase calls a ContractManager half, so a scheduled run and ContractManager.run
#emit the same lines in the same order. The caller advances the clock to next_due() before step().
#At 22:00 whatever phase is running is suspended and the party camps. A camp that begins under two
#hours before 6:00 skips the roll and the rest and breaks at 6:00; a longer camp takes the one
#respite roll of the night and rests its full six hours, so a camp begun after midnight wakes past
#6:00. The suspended phase then resumes with the minutes it had left.

enum Phase {TRAVEL_OUT, EVENT, GAP, CLOSING_REST, NIGHT, TRAVEL_BACK, DONE}

const NIGHT_START_HOUR := 22
const NIGHT_END_HOUR := 6
#A camp with less than this left before 6:00 is too short to roll or rest; the party only waits.
const SHORT_NIGHT_MINUTES := 120

var run: ContractRun = null
var phase: int = Phase.TRAVEL_OUT
var next_minute: int = 0
var travel_minutes: int = CampaignClock.TRAVEL_MINUTES
var all_dead: bool = false
var resume_phase: int = Phase.EVENT
var resume_minutes: int = 0
var mishap_index: int = 0
var events_run: int = 0
var gap_kind: String = ""
var night_active: bool = false

#Whether the camp now running takes its respite roll and its rest; false for a camp under two hours.
var night_rests: bool = true

#Minutes the phase now due was scheduled for; the CLOCK line it emits carries this delta.
var phase_minutes: int = 0

#Minutes the current camp runs, 22:00 to 6:00; kept apart so phase_minutes survives the night.
var night_minutes: int = 0


#The party leaves now: the boosts, penalties and log header land at once and travel is the first step.
static func create(contract_run: ContractRun, minutes: int, now: int) -> ContractScheduler:
	var scheduler := ContractScheduler.new()
	scheduler.run = contract_run
	scheduler.travel_minutes = maxi(0, minutes)
	ContractManager.depart(contract_run)
	scheduler.phase = Phase.TRAVEL_OUT
	scheduler.phase_minutes = scheduler.travel_minutes
	scheduler.next_minute = now + scheduler.travel_minutes
	if scheduler._is_night(now):
		scheduler._suspend()
	return scheduler


func next_due() -> int:
	if phase == Phase.NIGHT or phase == Phase.DONE:
		return next_minute
	if _should_camp():
		return CampaignClock.now()
	return mini(next_minute, _next_night_start(CampaignClock.now()))


func is_done() -> bool:
	return phase == Phase.DONE


#Settles the phase that just came due and schedules the next one; the clock is already at next_due().
func step() -> void:
	if run == null:
		phase = Phase.DONE
		return
	if _should_camp():
		_suspend()
		return
	match phase:
		Phase.TRAVEL_OUT:
			_arrive()
		Phase.EVENT:
			await _event_step()
		Phase.GAP:
			await _gap_step()
		Phase.CLOSING_REST:
			await _closing_step()
		Phase.NIGHT:
			await _wake_step()
		Phase.TRAVEL_BACK:
			_home_step()


#Night has fallen on a phase that still has minutes to run, so the party makes camp instead.
func _should_camp() -> bool:
	if phase == Phase.NIGHT or phase == Phase.DONE:
		return false
	return _is_night(CampaignClock.now()) and next_minute > CampaignClock.now()


func _arrive() -> void:
	run.emit(CampaignClock.line("travel out", travel_minutes))
	_queue(Phase.EVENT, 0)


func _event_step() -> void:
	var due: Dictionary = ContractManager.next_event(run, mishap_index)
	var name: String = String(due["name"])
	var is_primary: bool = bool(due["is_primary"])
	if bool(due["missing"]):
		if is_primary:
			run.failed_event = name if name != "" else "(no primary event)"
			run.emit("EVENT MISSING: %s" % run.failed_event)
			_head_home()
			return
		run.emit("EVENT MISSING: %s" % name)
		mishap_index += 1
		_queue(Phase.EVENT, 0)
		return
	await ContractManager.run_one_event(run, due["event"] as EventData, name, is_primary)
	events_run += 1
	if not is_primary:
		mishap_index += 1
	if run.living_team().is_empty():
		_died()
		return
	if is_primary:
		var rest: int = ContractManager.rest_minutes(run, RestSystem.KIND_RESPITE)
		if rest <= 0:
			_head_home()
			return
		_queue(Phase.CLOSING_REST, rest)
		return
	var gap: Dictionary = ContractManager.gap_minutes(run)
	gap_kind = String(gap["kind"])
	_queue(Phase.GAP, int(gap["minutes"]))


func _gap_step() -> void:
	run.emit(CampaignClock.line(ContractManager.gap_tag(gap_kind), phase_minutes))
	await ContractManager.settle_gap(run, gap_kind)
	if run.living_team().is_empty():
		_died()
		return
	_queue(Phase.EVENT, 0)


func _closing_step() -> void:
	run.emit(CampaignClock.line("respite", phase_minutes))
	await ContractManager.settle_rest(run, RestSystem.KIND_RESPITE, "respite", RestSystem.RESPITE_MINUTES)
	if run.living_team().is_empty():
		_died()
		return
	_head_home()


func _home_step() -> void:
	run.emit(CampaignClock.line("travel back", travel_minutes))
	ContractManager.arrive_home(run)
	phase = Phase.DONE
	next_minute = CampaignClock.now()


#The field camps from 22:00; the suspended phase keeps whatever minutes it had left.
func _suspend() -> void:
	var now: int = CampaignClock.now()
	resume_phase = phase
	resume_minutes = maxi(0, next_minute - now)
	night_active = true
	var wake6: int = _next_wake(now)
	night_rests = (wake6 - now) >= SHORT_NIGHT_MINUTES
	var wake: int = wake6
	if night_rests:
		wake = maxi(wake6, now + RestSystem.RESPITE_MINUTES)
	phase = Phase.NIGHT
	night_minutes = wake - now
	next_minute = wake


#Camp breaks: a camp long enough takes the night's respite roll and rest, then the phase picks up again.
func _wake_step() -> void:
	night_active = false
	run.emit(CampaignClock.line("night", night_minutes))
	if night_rests:
		await ContractManager.settle_rest(run, RestSystem.KIND_RESPITE, "night", RestSystem.RESPITE_MINUTES)
		if run.living_team().is_empty():
			_died()
			return
	phase = resume_phase
	next_minute = CampaignClock.now() + resume_minutes


func _head_home() -> void:
	_queue(Phase.TRAVEL_BACK, travel_minutes)


#Nobody left standing: the survivors never march back, so the return settles on the spot.
func _died() -> void:
	all_dead = true
	ContractManager.arrive_home(run)
	phase = Phase.DONE
	next_minute = CampaignClock.now()


func _queue(next_phase: int, minutes: int) -> void:
	phase = next_phase
	phase_minutes = maxi(0, minutes)
	next_minute = CampaignClock.now() + phase_minutes
	if _is_night(CampaignClock.now()):
		_suspend()


func _is_night(minute: int) -> bool:
	return is_night_minute(minute)


func _next_wake(minute: int) -> int:
	return next_wake_minute(minute)


#Shared with GameState: 22:00 to 6:00 is night, when nothing in the field moves.
static func is_night_minute(minute: int) -> bool:
	var hour: int = int((minute % CampaignClock.MINUTES_PER_DAY) / float(CampaignClock.MINUTES_PER_HOUR))
	return hour >= NIGHT_START_HOUR or hour < NIGHT_END_HOUR


#The next 6:00 strictly after this minute.
static func next_wake_minute(minute: int) -> int:
	var day_start: int = minute - (minute % CampaignClock.MINUTES_PER_DAY)
	var wake: int = day_start + NIGHT_END_HOUR * CampaignClock.MINUTES_PER_HOUR
	if wake <= minute:
		wake += CampaignClock.MINUTES_PER_DAY
	return wake


#The next 22:00 strictly after this minute.
func _next_night_start(minute: int) -> int:
	var day_start: int = minute - (minute % CampaignClock.MINUTES_PER_DAY)
	var start: int = day_start + NIGHT_START_HOUR * CampaignClock.MINUTES_PER_HOUR
	if start <= minute:
		start += CampaignClock.MINUTES_PER_DAY
	return start
