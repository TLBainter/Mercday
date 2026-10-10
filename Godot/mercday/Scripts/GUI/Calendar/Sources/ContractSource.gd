class_name ContractSource extends CalendarSource

#Contract returns: one event per active run on the day it is due back, and one per settled result on
#the day it closed. A night dispatch sits in queued as well, so queued only changes the sub line.


func events_between(d0: int, d1: int) -> Array[CalendarEvent]:
	var out: Array[CalendarEvent] = []
	for entry_id: Variant in GameState.active_contracts:
		var run: ActiveRun = GameState.active_contracts[entry_id] as ActiveRun
		if run == null:
			continue
		var day: int = TrynnCalendar.day_index(run.return_minute())
		if within(day, d0, d1):
			out.append(make_event(day, crew_text(run.uids().size()), _run_sub(run), run))
	for entry_id: Variant in GameState.results:
		var result: ContractResultData = GameState.results[entry_id] as ContractResultData
		if result == null or result.preview:
			continue
		var day: int = TrynnCalendar.day_index(result.closed_minute)
		if within(day, d0, d1):
			out.append(make_event(day, result.name, "Failed" if result.failed else "Returned", result))
	return out


#"1 merc returns", "2 mercs return".
static func crew_text(count: int) -> String:
	return "%d %s" % [count, "merc returns" if count == 1 else "mercs return"]


#The posted name of the run's contract, read through GameState.contract_view.
static func contract_name(run: ActiveRun) -> String:
	var view: ContractView = GameState.contract_view(run.entry_id)
	return view.name if view != null else "Contract %d Name" % (run.entry_id + 1)


func _run_sub(run: ActiveRun) -> String:
	var when: String = "queued, estimated" if GameState.queued.has(run.entry_id) else "estimated"
	return "%s - %s" % [contract_name(run), when]


#The crew coming home or the crew that came home, in the calendar's ReturningCrewTooltip.
func hover(event: CalendarEvent, row: Control, dialog: Node) -> void:
	var calendar: CalendarDialog = dialog as CalendarDialog
	if calendar == null:
		return
	var run: ActiveRun = event.ref as ActiveRun
	var result: ContractResultData = event.ref as ContractResultData
	if run != null:
		calendar.crew_tip.show_run(run, contract_name(run), row)
	elif result != null:
		calendar.crew_tip.show_result(result, row)


func change_signals() -> Array[Signal]:
	return [GameState.contracts_changed, GameState.dispatched, GameState.results_recorded]
