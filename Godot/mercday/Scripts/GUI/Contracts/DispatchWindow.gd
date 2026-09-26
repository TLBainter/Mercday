class_name DispatchWindow extends Control

#The modal that puts a team on a posting: who goes, how they travel, what it costs and the odds
#that come out of it. It never changes the board by itself; GameState.dispatch does that.

signal dispatched(run: ActiveRun)
signal cancelled
signal failed(entry_id: int)

const SLOT_COUNT: int = 5
const WARN_ODDS: int = 25
const CAUTION_ODDS: int = 50
const LEADER_ROLE: String = "Leader"
const SUPPORT_ROLE: String = "Support"
const REWARD_UP: Color = Color("#6cc36a")
const REWARD_DOWN: Color = Color("#e8583f")
const TIME_COLOR: Color = Color("#f3ead7")

@onready var roster: DispatchRoster = $Margin/Columns/Left
@onready var summary: ContractSummary = $Margin/Columns/Centre/Summary
@onready var venture_selector: TravelSelector = $Margin/Columns/Centre/TravelPanel/Pad/Rows/Venture
@onready var return_selector: TravelSelector = $Margin/Columns/Centre/TravelPanel/Pad/Rows/Return
@onready var slot_row: HBoxContainer = $Margin/Columns/Centre/TeamPanel/Pad/Rows/Slots
@onready var action_bar: ActionBar = $Margin/Columns/Centre/Actions
@onready var meter: SuccessMeter = $Margin/Columns/Centre/Actions/Pad/Row/Odds/Meter
@onready var hint_label: Label = $Margin/Columns/Centre/Actions/Pad/Row/Odds/Hint
@onready var optimize_button: Button = $Margin/Columns/Centre/Actions/Pad/Row/Buttons/Optimize
@onready var clear_button: Button = $Margin/Columns/Centre/Actions/Pad/Row/Buttons/Clear
@onready var cancel_button: Button = $Margin/Columns/Centre/Actions/Pad/Row/Buttons/Cancel
@onready var dispatch_button: Button = $Margin/Columns/Centre/Actions/Pad/Row/Dispatch
@onready var preview_panel: ContractPreview = $Margin/Columns/Right
@onready var confirm_dialog: ConfirmDialog = $Confirm
@onready var team_title: Label = $Margin/Columns/Centre/TeamPanel/Pad/Rows/Head/Title
@onready var team_count: Label = $Margin/Columns/Centre/TeamPanel/Pad/Rows/Head/Count
@onready var picker: MercPicker = $Picker

var contract: ContractView = null
var model: OddsModel = null
var candidates: Array[MercView] = []
var slots: int = 1
var team: Array[int] = []
var roles: Array[String] = []
var venture_mode: Dictionary = {}
var return_mode: Dictionary = {}

var _pending: String = ""
var _last_run: ActiveRun = null


func _ready() -> void:
	confirm_dialog.cancelled.connect(_on_cancelled)
	confirm_dialog.chosen.connect(_on_chosen)
	action_bar.optimize_pressed.connect(_on_optimize_pressed)
	action_bar.clear_pressed.connect(_on_clear_pressed)
	action_bar.cancel_pressed.connect(_on_cancel_pressed)
	action_bar.dispatch_pressed.connect(_on_dispatch_pressed)
	venture_selector.set_leg(0, "Venture")
	return_selector.set_leg(1, "Return")
	var caption_width: float = maxf(venture_selector.caption_width(),
		return_selector.caption_width())
	venture_selector.set_caption_width(caption_width)
	return_selector.set_caption_width(caption_width)
	venture_selector.mode_selected.connect(_on_mode_selected)
	return_selector.mode_selected.connect(_on_mode_selected)
	roster.picked.connect(_on_roster_picked)
	roster.remove_requested.connect(_on_roster_remove)
	picker.picked.connect(_on_picker_picked)
	picker.removed.connect(remove_slot)
	_build_state()
	_wire_slots()
	_default_travel()
	_refresh()


func confirm() -> ConfirmDialog:
	return confirm_dialog


func roster_panel() -> DispatchRoster:
	return roster


func preview_of() -> ContractPreview:
	return preview_panel


func odds_meter() -> SuccessMeter:
	return meter


func hint_text() -> String:
	return hint_label.text


func slot_at(index: int) -> TeamSlot:
	if index < 0 or index >= slot_row.get_child_count():
		return null
	return slot_row.get_child(index) as TeamSlot


func slot_count() -> int:
	return slots


func team_uids() -> Array[int]:
	var out: Array[int] = []
	for uid: int in team:
		if uid != 0:
			out.append(uid)
	return out


func filled_count() -> int:
	return team_uids().size()


func team_size() -> int:
	return maxi(1, filled_count())


func place(uid: int, slot: int) -> bool:
	if slot < 0 or slot >= slots or uid == 0:
		return false
	if _view_of(uid) == null:
		return false
	for i: int in team.size():
		if team[i] == uid:
			team[i] = 0
	team[slot] = uid
	_refresh()
	return true


func remove_slot(slot: int) -> void:
	if slot < 0 or slot >= team.size():
		return
	team[slot] = 0
	_refresh()


#Trades two slots, both mercs and, between support slots, the roles they were given.
#Slot 0 is always the Leader, so a swap that touches it moves the mercs only.
func swap_slots(from_slot: int, to_slot: int) -> void:
	if from_slot < 0 or to_slot < 0 or from_slot >= slots or to_slot >= slots:
		return
	if from_slot == to_slot:
		return
	var uid: int = team[from_slot]
	team[from_slot] = team[to_slot]
	team[to_slot] = uid
	if from_slot > 0 and to_slot > 0:
		var role_name: String = roles[from_slot]
		roles[from_slot] = roles[to_slot]
		roles[to_slot] = role_name
	_refresh()


#Opens the merc picker over a slot; every candidate is listed, the best fit for it first.
func open_picker(slot: int) -> void:
	if picker == null or contract == null or slot < 0 or slot >= slots:
		return
	var node: TeamSlot = slot_at(slot)
	var anchor: Rect2i = Rect2i(node.get_global_rect()) if node != null else Rect2i()
	picker.open_for(slot, roles[slot], candidates, scores_for(slot), placed_slots(), anchor)


#Every placed merc against the slot holding it, for the picker in slot N note.
func placed_slots() -> Dictionary:
	var out: Dictionary = {}
	for i: int in team.size():
		if team[i] != 0:
			out[team[i]] = i
	return out


#Every candidate fit for one slot role, uid to score.
func scores_for(slot: int) -> Dictionary:
	var out: Dictionary = {}
	if contract == null or slot < 0 or slot >= roles.size():
		return out
	var share: Dictionary = _share() if slot > 0 else {}
	for view: MercView in candidates:
		out[view.uid] = DispatchLogic.score(view, contract, roles[slot], share)
	return out


#The line under the Team title: slots filled, slots available and slots the posting demands.
func team_count_text() -> String:
	if contract == null:
		return ""
	return "%d / %d, %d required" % [filled_count(), contract.merc_max, contract.merc_min]


func set_role(slot: int, role_name: String) -> void:
	if slot <= 0 or slot >= roles.size():
		return
	roles[slot] = role_name
	var node: TeamSlot = slot_at(slot)
	if node != null:
		node.set_role(role_name)
	_refresh()


func pick_travel(leg: int, key: String) -> void:
	var mode: Dictionary = GuiTypes.travel_mode(key)
	if mode.is_empty():
		return
	if leg == 0:
		if str(venture_mode.get("key", "")) == key:
			return
		venture_mode = mode
		venture_selector.select_key(key)
	else:
		if str(return_mode.get("key", "")) == key:
			return
		return_mode = mode
		return_selector.select_key(key)
	_refresh()


#Optimize picks the team on the odds, lays the roles out around the leader and books the travel.
func optimize() -> void:
	if contract == null:
		return
	var picks: Array[int] = DispatchLogic.optimize(candidates, slots,
		func(uids: Array[int]) -> int: return OddsEstimator.odds(model, uids),
		mini(contract.merc_min, slots))
	var plan: Dictionary = DispatchLogic.arrange(picks, candidates, contract,
		TeamSlot.slot_roles())
	var picked: Array[int] = plan.get("team", [] as Array[int])
	var picked_roles: Array[String] = plan.get("roles", [] as Array[String])
	for i: int in team.size():
		team[i] = 0
		roles[i] = SUPPORT_ROLE
	if not roles.is_empty():
		roles[0] = LEADER_ROLE
	for i: int in mini(picked.size(), slots):
		team[i] = picked[i]
		roles[i] = picked_roles[i]
	_fill_to_minimum()
	var trip: Dictionary = DispatchLogic.plan_travel(GuiTypes.TRAVEL_MODES, GameState.bank_notes,
		contract.reward, team_size(), contract.merc_min, contract.distance_km)
	var venture: Dictionary = trip.get("venture", {})
	if venture.is_empty():
		_default_travel()
	else:
		venture_mode = venture
		return_mode = trip.get("ret", venture)
	_refresh()


#The posting refuses a team under its required count, so Optimize tops the picks up to that floor.
func _fill_to_minimum() -> void:
	if contract == null:
		return
	var floor_count: int = mini(contract.merc_min, slots)
	while filled_count() < floor_count:
		var slot: int = _first_empty_slot()
		if slot < 0:
			return
		var uid: int = _best_unplaced(slot)
		if uid == 0:
			return
		team[slot] = uid


func _first_empty_slot() -> int:
	for i: int in team.size():
		if team[i] == 0:
			return i
	return -1


#The best fit for one slot among the mercs no slot holds yet; 0 when every candidate is placed.
func _best_unplaced(slot: int) -> int:
	var scores: Dictionary = scores_for(slot)
	var placed: Dictionary = placed_slots()
	var best_uid: int = 0
	var best_score: float = -1.0
	for view: MercView in candidates:
		if placed.has(view.uid):
			continue
		var value: float = float(scores.get(view.uid, 0.0))
		if value > best_score:
			best_score = value
			best_uid = view.uid
	return best_uid


func clear_team() -> void:
	for i: int in team.size():
		team[i] = 0
	for i: int in range(1, roles.size()):
		roles[i] = SUPPORT_ROLE
	_default_travel()
	_refresh()


func travel_total() -> int:
	if contract == null:
		return 0
	var crew_size: int = team_size()
	return DispatchLogic.travel_cost(venture_mode, crew_size, contract.merc_min,
		contract.distance_km) + DispatchLogic.travel_cost(return_mode, crew_size, contract.merc_min,
		contract.distance_km)


func current_odds() -> int:
	var uids: Array[int] = team_uids()
	if uids.is_empty() or model == null:
		return 0
	return OddsEstimator.odds(model, uids)


#Dirty means anything sits off the opening state: a filled slot, a leg off foot or a changed role.
func is_dirty() -> bool:
	for uid: int in team:
		if uid != 0:
			return true
	if str(venture_mode.get("key", "")) != "foot":
		return true
	if str(return_mode.get("key", "")) != "foot":
		return true
	for i: int in range(1, roles.size()):
		if roles[i] != SUPPORT_ROLE:
			return true
	return false


func is_ready() -> bool:
	return ready_to_dispatch()


func ready_to_dispatch() -> bool:
	if contract == null or team.is_empty():
		return false
	return team[0] != 0 and filled_count() >= contract.merc_min \
		and travel_total() <= GameState.bank_notes


#Builds the run and hands it to GameState; the answer dialog says which way it went.
func commit() -> bool:
	if contract == null:
		return false
	var run: ActiveRun = ActiveRun.new()
	run.entry_id = contract.entry_id
	run.reward = contract.reward
	run.travel_cost = travel_total()
	run.odds = current_odds()
	run.travel_mode = str(venture_mode.get("key", "foot"))
	var data: Dictionary = ContractPreview.preview(contract, venture_mode, return_mode,
		team_size())
	run.hours = roundf(float(data.get("total_hours", 0.0)))
	var members: Array[TeamMember] = []
	for i: int in team.size():
		if team[i] == 0:
			continue
		var member: TeamMember = TeamMember.new()
		member.merc_uid = team[i]
		member.role = roles[i]
		member.match = _stars_for(i)
		members.append(member)
	run.team = members
	_last_run = run
	var ok: bool = GameState.dispatch(contract.entry_id, run)
	if ok:
		_pending = "done"
		confirm_dialog.ask_buttons("Team Dispatched!", _dispatched_text(), ["OK"],
			ConfirmDialog.Severity.GREEN, [ConfirmDialog.Kind.GO])
	else:
		_pending = "failed"
		confirm_dialog.ask_buttons("Dispatch failed",
			"The posting closed or a merc is no longer available.", ["OK"],
			ConfirmDialog.Severity.INFO, [ConfirmDialog.Kind.GO])
	return ok


func _build_state() -> void:
	if contract == null:
		return
	slots = clampi(contract.merc_max, 1, SLOT_COUNT)
	team.resize(slots)
	roles.resize(slots)
	for i: int in slots:
		team[i] = 0
		roles[i] = LEADER_ROLE if i == 0 else SUPPORT_ROLE
	model = OddsEstimator.prepare(contract.contract, GameState.mercs)
	var busy: Array[int] = GameState.busy_uids()
	candidates = []
	for view: MercView in GameState.roster:
		if busy.has(view.uid) or view.status != GuiTypes.MercStatus.AVAILABLE:
			continue
		candidates.append(view)
	summary.set_contract(contract)
	roster.configure(candidates, _score_of)


func _wire_slots() -> void:
	for i: int in slot_row.get_child_count():
		var node: TeamSlot = slot_at(i)
		if node == null:
			continue
		node.set_slot(i, _caption_for(i))
		node.visible = i < slots
		node.required = contract != null and i < contract.merc_min
		node.dropped.connect(_on_slot_dropped)
		node.cleared.connect(remove_slot)
		node.clicked.connect(_on_slot_clicked)
		node.role_changed.connect(_on_slot_role_changed)
		node.swapped.connect(swap_slots)


func _caption_for(index: int) -> String:
	if index == 0:
		return "Required"
	if contract != null and index < contract.merc_min:
		return "Required"
	return "Optional"


#Both legs open on foot and stay there until the designer picks something faster.
func _default_travel() -> void:
	var foot: Dictionary = GuiTypes.travel_mode("foot")
	venture_mode = foot
	return_mode = foot


func _refresh() -> void:
	if not is_node_ready() or contract == null:
		return
	roster.set_taken(team_uids())
	_refresh_slots()
	var crew_size: int = team_size()
	var venture_cost: int = DispatchLogic.travel_cost(venture_mode, crew_size, contract.merc_min,
		contract.distance_km)
	var return_cost: int = DispatchLogic.travel_cost(return_mode, crew_size, contract.merc_min,
		contract.distance_km)
	venture_selector.select_key(str(venture_mode.get("key", "")))
	return_selector.select_key(str(return_mode.get("key", "")))
	venture_selector.configure(crew_size, contract.merc_min, contract.distance_km,
		GameState.bank_notes, return_cost)
	return_selector.configure(crew_size, contract.merc_min, contract.distance_km,
		GameState.bank_notes, venture_cost)
	preview_panel.set_preview(ContractPreview.preview(contract, venture_mode, return_mode, crew_size))
	var odds: int = current_odds()
	action_bar.set_odds(odds)
	action_bar.set_hint(_hint_for(odds))
	action_bar.set_ready(is_ready())
	action_bar.set_dirty(is_dirty())
	team_count.text = team_count_text()


func _refresh_slots() -> void:
	var share: Dictionary = _share()
	var leader: MercView = null
	if not team.is_empty():
		leader = _view_of(team[0])
	for i: int in slots:
		var node: TeamSlot = slot_at(i)
		if node == null:
			continue
		node.set_slot(i, _caption_for(i))
		if team[i] == 0:
			node.clear_member()
			continue
		var view: MercView = _view_of(team[i])
		if view == null:
			node.clear_member()
			continue
		var own: Dictionary = share if i > 0 else {}
		var stars: float = DispatchLogic.to_stars(DispatchLogic.score(view, contract,
			roles[i], own))
		#The leader lends their own top traits, rescored for the role this slot carries.
		var shared: Array[Dictionary] = []
		if i > 0 and leader != null:
			shared = DispatchLogic.top_traits(leader, contract, roles[i])
		node.set_member(view, stars, DispatchLogic.top_traits(view, contract, roles[i]), shared)
		node.set_role(roles[i])


func _hint_for(odds: int) -> String:
	if team.is_empty() or team[0] == 0:
		return "Pick a leader"
	var missing: int = contract.merc_min - filled_count()
	if missing > 0:
		return "Fill %d required slots" % missing
	if travel_total() > GameState.bank_notes:
		return "Travel costs exceed your notes"
	return "%d%% success odds" % odds


func _share() -> Dictionary:
	if team.is_empty() or team[0] == 0:
		return {}
	var leader: MercView = _view_of(team[0])
	if leader == null:
		return {}
	return DispatchLogic.leader_share(leader, contract)


func _score_of(view: MercView) -> float:
	if contract == null or view == null:
		return 0.0
	#Roster fit reads against a fixed General role; picking a role to sort by is a later feature.
	return DispatchLogic.score(view, contract, "General", _share())


func _next_open() -> int:
	for i: int in slots:
		if team[i] == 0:
			return i
	return -1


func _stars_for(index: int) -> float:
	var view: MercView = _view_of(team[index])
	if view == null:
		return 0.0
	var share: Dictionary = _share() if index > 0 else {}
	return DispatchLogic.to_stars(DispatchLogic.score(view, contract, roles[index], share))


func _view_of(uid: int) -> MercView:
	for view: MercView in candidates:
		if view.uid == uid:
			return view
	return null


func _names_text() -> String:
	var parts: Array[String] = []
	for uid: int in team_uids():
		var view: MercView = _view_of(uid)
		parts.append(view.name if view != null else "Merc %d" % uid)
	return ", ".join(parts)


func _dispatched_text() -> String:
	var text: String = "%s set out for %s." % [_names_text(), contract.name]
	if GameState.queued.has(contract.entry_id):
		text += " They leave at 6:00 AM."
	return text


func _on_picker_picked(uid: int, slot: int) -> void:
	place(uid, slot)


#An assigned roster row was clicked: the merc leaves whichever slot holds it.
func _on_roster_remove(uid: int) -> void:
	for i: int in team.size():
		if team[i] == uid:
			remove_slot(i)
			return


func _on_roster_picked(uid: int) -> void:
	var slot: int = _next_open()
	if slot >= 0:
		place(uid, slot)


func _on_slot_dropped(uid: int, slot: int) -> void:
	place(uid, slot)


func _on_slot_clicked(slot: int) -> void:
	open_picker(slot)


func _on_slot_role_changed(slot: int, role_name: String) -> void:
	set_role(slot, role_name)


func _on_mode_selected(leg: int, key: String) -> void:
	pick_travel(leg, key)


#A clean form has nothing to lose, so Optimize, Clear and Cancel only ask once something has moved.
func _on_optimize_pressed() -> void:
	if not is_dirty():
		optimize()
		return
	_pending = "optimize"
	confirm_dialog.ask_buttons("Are you sure?",
		"Optimizing will clear your current configuration. Are you sure?",
		["Go Back", "Continue"], ConfirmDialog.Severity.ORANGE,
		[ConfirmDialog.Kind.NEUTRAL, ConfirmDialog.Kind.WARN])


func _on_clear_pressed() -> void:
	if not is_dirty():
		return
	_pending = "clear"
	confirm_dialog.ask_buttons("Are you sure?", "This will clear all changes to this dispatch.",
		["Cancel", "Yes"], ConfirmDialog.Severity.RED,
		[ConfirmDialog.Kind.NEUTRAL, ConfirmDialog.Kind.BAD])


func _on_cancel_pressed() -> void:
	if not is_dirty():
		cancelled.emit()
		return
	_pending = "cancel"
	confirm_dialog.ask_buttons("Are you sure?",
		"Canceling will discard any changes you have made to this dispatch.",
		["Go Back", "Yes"], ConfirmDialog.Severity.RED,
		[ConfirmDialog.Kind.NEUTRAL, ConfirmDialog.Kind.BAD])


func _on_dispatch_pressed() -> void:
	if not ready_to_dispatch():
		return
	_ask_next_step(current_odds(), "")


#One warning at most before the recap: red under 25 percent, orange under 50 percent.
func _ask_next_step(odds: int, stage: String) -> void:
	if stage == "" and odds < WARN_ODDS:
		_pending = "warn"
		confirm_dialog.ask_buttons("Warning",
			"Chances of success are extremely low! This team is unlikely to succeed. Continue?",
			["Go Back", "Continue Anyway"], ConfirmDialog.Severity.RED,
			[ConfirmDialog.Kind.NEUTRAL, ConfirmDialog.Kind.BAD])
		return
	if stage != "final" and odds < CAUTION_ODDS:
		_pending = "caution"
		confirm_dialog.ask_buttons("Caution",
			"Chances of success are low! This team may fail the contract. Continue?",
			["Go Back", "Continue"], ConfirmDialog.Severity.ORANGE,
			[ConfirmDialog.Kind.NEUTRAL, ConfirmDialog.Kind.WARN])
		return
	_pending = "final"
	confirm_dialog.ask_recap("Dispatch This Team?", contract.name, recap_team(),
		recap_stats(odds), ["Cancel", "Let's Go!"], ConfirmDialog.Severity.GREEN,
		[ConfirmDialog.Kind.NEUTRAL, ConfirmDialog.Kind.GO])


#The recap team block: every member in slot order beside the role it takes.
func recap_team() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in team.size():
		if team[i] == 0:
			continue
		var view: MercView = _view_of(team[i])
		var merc_name: String = view.name if view != null else "Merc %d" % team[i]
		out.append({"name": merc_name, "role": roles[i]})
	return out


#The recap number block: the odds, the time it takes and the reward left after travel.
func recap_stats(odds: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if contract == null:
		return out
	var data: Dictionary = ContractPreview.preview(contract, venture_mode, return_mode,
		team_size())
	var span: String = ContractPreview.days_text(float(data.get("total_hours", 0.0)))
	var net: int = contract.reward - travel_total()
	var tint: Color = REWARD_UP if net >= 0 else REWARD_DOWN
	out.append({"label": "Success Odds", "value": "%d%%" % odds,
		"color": GuiTypes.odds_color(odds)})
	out.append({"label": "Time to Complete", "value": span, "color": TIME_COLOR})
	out.append({"label": "Expected Final Reward", "value": "%d" % net, "color": tint,
		"glyph": true})
	return out


func _on_cancelled() -> void:
	var kind: String = _pending
	_pending = ""
	_finish_receipt(kind)


#Every dispatch dialog puts the safe answer first, so only the last button carries the action on.
func _on_chosen(index: int) -> void:
	var kind: String = _pending
	_pending = ""
	if index < confirm_dialog.button_count() - 1:
		_finish_receipt(kind)
		return
	match kind:
		"optimize":
			optimize()
		"clear":
			clear_team()
		"cancel":
			cancelled.emit()
		"warn":
			_ask_next_step(current_odds(), "final")
		"caution":
			_ask_next_step(current_odds(), "final")
		"final":
			commit()
		_:
			_finish_receipt(kind)


#A receipt reports a dispatch that already happened, so Esc closes it the same way its button does.
func _finish_receipt(kind: String) -> bool:
	if kind == "done" and _last_run != null:
		dispatched.emit(_last_run)
		return true
	if kind == "failed" and contract != null:
		failed.emit(contract.entry_id)
		return true
	return false
