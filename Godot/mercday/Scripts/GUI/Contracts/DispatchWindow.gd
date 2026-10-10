class_name DispatchWindow extends Control

#The modal that puts a team on a posting: who goes, how they travel, what it costs and the odds
#that come out of it. It never changes the board by itself; GameState.dispatch does that.

signal dispatched(run: ActiveRun)
signal cancelled
signal failed(entry_id: int)

const SLOT_COUNT: int = 5
const WARN_ODDS: int = 25
const CAUTION_ODDS: int = 50
const SUPPORT_ROLE: String = "Support"
const REWARD_UP: Color = GuiColors.GREEN
const REWARD_DOWN: Color = GuiColors.RED
const TIME_COLOR: Color = GuiColors.CREAM

@onready var roster: DispatchRoster = $Margin/Columns/Left
@onready var summary: ContractSummary = $Margin/Columns/Centre/Summary
@onready var venture_selector: TravelSelector = $Margin/Columns/Centre/TravelPanel/Pad/Rows/Venture
@onready var return_selector: TravelSelector = $Margin/Columns/Centre/TravelPanel/Pad/Rows/Return
@onready var slot_row: HBoxContainer = $Margin/Columns/Centre/TeamPanel/Pad/Rows/Slots
@onready var action_bar: ActionBar = $Margin/Columns/Centre/Actions
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
var offered_roles: Array[String] = []
var venture_mode: Dictionary = {}
var return_mode: Dictionary = {}
#The last optimize_plan result: {team, leader_uid, mode, p, cost}.
var last_plan: Dictionary = {}
#Optimize's vacation screen {pool, pending} while Optimize runs; empty for manual placement.
var _screen: Dictionary = {}

var _pending: String = ""
var _last_run: ActiveRun = null
#The uid each slot held at the last refresh; _build_state seeds it with the empty team, so the opening refresh is silent.
var _slot_uids: Array[int] = []


func _ready() -> void:
	add_child(TimeHold.new())
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
	venture_selector.mode_selected.connect(pick_travel)
	return_selector.mode_selected.connect(pick_travel)
	roster.picked.connect(_on_roster_picked)
	roster.remove_requested.connect(_on_roster_remove)
	picker.picked.connect(place)
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
	var scores: Dictionary = scores_for(slot)
	var placed: Dictionary = placed_slots()
	var rows: Array[Dictionary] = []
	for view: MercView in candidates:
		rows.append({"id": view.uid, "name": view.name, "fit": float(scores.get(view.uid, 0.0)),
			"view": view, "where": MercPicker.where_text(view, placed, slot)})
	rows.sort_custom(CrewCandidates.by_fit_then_name)
	for row: Dictionary in rows:
		row["fit"] = MatchScore.stars(float(row["fit"]))
	picker.title = "Select Leader" if slot == 0 else "Select %s" % roles[slot]
	picker.open_for(slot, rows, MercPicker.holds_slot(placed, slot))


#Every placed merc against the slot holding it, for the picker in slot N note.
func placed_slots() -> Dictionary:
	var out: Dictionary = {}
	for i: int in team.size():
		if team[i] != 0:
			out[team[i]] = i
	return out


#Every candidate's solo net percent, uid to net; a role is a label only, so every slot reads the same.
func scores_for(slot: int) -> Dictionary:
	var out: Dictionary = {}
	if contract == null or slot < 0 or slot >= roles.size():
		return out
	for view: MercView in candidates:
		out[view.uid] = _score_of(view)
	return out


#The line under the Team title: slots filled, slots available and slots the posting demands.
func team_count_text() -> String:
	if contract == null:
		return ""
	return "%d / %d, %d required" % [filled_count(), contract.merc_max, contract.merc_min]


func set_role(slot: int, role_name: String) -> void:
	if slot <= 0 or slot >= roles.size():
		return
	if not offered_roles.has(role_name):
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


#Optimize takes one optimize_plan result: the team with its leader in slot 0, the venture and the odds.
func optimize() -> void:
	if contract == null:
		return
	var hours: float = float(ContractPreview.preview(contract, venture_mode, return_mode, team_size()).get("total_hours", 0.0))
	var trip_span: Vector2i = DispatchLogic.trip_days(CampaignClock.now(), hours)
	_screen = DispatchLogic.vacation_screen(candidates, BenefitsManager.book, trip_span.x, trip_span.y)
	var request: Dictionary = optimize_request()
	var pool_uids: Array[int] = []
	for view: MercView in (_screen["pool"] as Array[MercView]):
		pool_uids.append(view.uid)
	var pending: Array[int] = _screen["pending"]
	var plain: Callable = request["chance_fn"]
	request["uids"] = pool_uids
	request["chance_fn"] = DispatchLogic.vacation_odds(plain, pending)
	last_plan = DispatchLogic.optimize_plan(request)
	var picked: Array[int] = last_plan.get("team", [] as Array[int])
	if not pending.is_empty() and not picked.is_empty():
		last_plan["p"] = float(plain.call(picked.duplicate(), int(last_plan["leader_uid"])))
	for i: int in team.size():
		team[i] = 0
		roles[i] = SUPPORT_ROLE
	if not roles.is_empty():
		roles[0] = ContractResultData.ROLE_LEADER
	for i: int in mini(picked.size(), slots):
		team[i] = picked[i]
	_fill_to_minimum()
	_screen = {}
	var trip: Dictionary = DispatchLogic.plan_travel(GuiTypes.TRAVEL_MODES, GameState.bank_notes,
		team_size(), contract.merc_min, contract.distance_km, venture_keys(), return_keys())
	var venture: Dictionary = trip.get("venture", {})
	var chosen: Dictionary = GuiTypes.travel_mode(String(last_plan.get("mode", "")))
	if not chosen.is_empty() and not picked.is_empty():
		venture = chosen
	if venture.is_empty():
		_default_travel()
	else:
		venture_mode = venture
		var ret: Dictionary = trip.get("ret", {})
		return_mode = GuiTypes.travel_mode(Reachability.FOOT) if ret.is_empty() else ret
	_refresh()


#The optimize_plan request for this posting: available candidates, the size bounds and the window's callables.
func optimize_request() -> Dictionary:
	var uids: Array[int] = []
	for view: MercView in candidates:
		uids.append(view.uid)
	var open: Array[ContractData] = _open_postings()
	var keys: Array[String] = venture_keys()
	return {
		"uids": uids,
		"lo": mini(contract.merc_min, slots),
		"cap": slots,
		"seed": contract.entry_id,
		"chance_fn": func(members: Array[int], leader_uid: int) -> float:
			return OddsEstimator.chance(model, members, leader_uid),
		"mode_fn": func(members: Array[int]) -> Dictionary:
			return _outbound_for(members.size(), keys),
		"features_fn": func(uid: int) -> int:
			return MatchScore.feature_count(_merc_of(uid), open),
		"solo_fn": func(uid: int) -> float:
			return _score_of(_view_of(uid)),
		"name_fn": func(uid: int) -> String:
			var view: MercView = _view_of(uid)
			return view.name if view != null else "",
	}


#The cheapest in-time outbound mode the bank pays for a team this size, as {mode, cost}, or {} when none.
func _outbound_for(size: int, keys: Array[String]) -> Dictionary:
	var crew_size: int = maxi(1, size)
	var trip: Dictionary = DispatchLogic.plan_travel(GuiTypes.TRAVEL_MODES, GameState.bank_notes,
		crew_size, contract.merc_min, contract.distance_km, keys, [])
	var venture: Dictionary = trip.get("venture", {})
	if venture.is_empty():
		return {}
	return {"mode": str(venture.get("key", "")),
		"cost": DispatchLogic.travel_cost(venture, crew_size, contract.merc_min, contract.distance_km)}


func _open_postings() -> Array[ContractData]:
	var out: Array[ContractData] = []
	if GameState.board == null:
		return out
	for entry: BoardEntry in GameState.board.available():
		if entry != null and entry.contract != null:
			out.append(entry.contract)
	return out


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


#The free merc with the highest solo net, however low (card 659); a tie keeps pool order. During Optimize the pool is
#the vacation pool and a pending merc goes only when no other is left. 0 only when the pool has no free merc.
func _best_unplaced(slot: int) -> int:
	var scores: Dictionary = scores_for(slot)
	var placed: Dictionary = placed_slots()
	var pending: Array[int] = _screen.get("pending", [] as Array[int])
	var best_uid: int = 0
	var best_score: float = -INF
	var late_uid: int = 0
	var late_score: float = -INF
	for view: MercView in (_screen.get("pool", candidates) as Array[MercView]):
		if placed.has(view.uid):
			continue
		var value: float = float(scores.get(view.uid, 0.0))
		if pending.has(view.uid):
			if value > late_score:
				late_score = value
				late_uid = view.uid
		elif value > best_score:
			best_score = value
			best_uid = view.uid
	return best_uid if best_uid != 0 else late_uid


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
	return ContractPreview.leg_cost(contract, venture_mode, crew_size) \
		+ ContractPreview.leg_cost(contract, return_mode, crew_size)


func current_odds() -> int:
	var uids: Array[int] = team_uids()
	if uids.is_empty() or model == null:
		return 0
	return OddsEstimator.odds(model, uids, team[0] if team[0] != 0 else -1)


#The team match percent: the mean member net with slot 0 as the leader.
func team_match_percent() -> float:
	if contract == null:
		return 0.0
	return MatchScore.team_net(contract.contract, _team_mercs(), _leader_merc())


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


func ready_to_dispatch() -> bool:
	if contract == null or team.is_empty():
		return false
	return team[0] != 0 and filled_count() >= contract.merc_min \
		and venture_keys().has(str(venture_mode.get("key", ""))) and fares_ok()


#The board entry behind the posting, or null when the view is not on the board.
func board_entry() -> BoardEntry:
	if contract == null or GameState.board == null:
		return null
	return GameState.board.entry(contract.entry_id)


#The venture modes offered now that still reach the posting before its deadline.
func venture_keys() -> Array[String]:
	var entry: BoardEntry = _gate_entry()
	return Reachability.modes_in_time(entry, CampaignClock.now(), GameState.bank_notes,
		GameState.tele_permit_for(entry))


#The return modes offered; the way home is never held to the deadline.
func return_keys() -> Array[String]:
	var entry: BoardEntry = _gate_entry()
	return Reachability.offered_modes(entry, GameState.bank_notes, GameState.tele_permit_for(entry))


#Both legs paid from the bank in turn: foot passes at any bank; a paid leg needs its fare in hand.
func fares_ok() -> bool:
	if contract == null:
		return false
	var crew_size: int = team_size()
	var bank: int = GameState.bank_notes
	var out_cost: int = ContractPreview.leg_cost(contract, venture_mode, crew_size)
	var back_cost: int = ContractPreview.leg_cost(contract, return_mode, crew_size)
	return Reachability.fare_ok(str(venture_mode.get("key", "")), out_cost, bank) \
		and Reachability.fare_ok(str(return_mode.get("key", "")), back_cost, bank - out_cost)


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
	run.return_mode = str(return_mode.get("key", "foot"))
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
		UiSfx.reject_press()
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
		roles[i] = ContractResultData.ROLE_LEADER if i == 0 else SUPPORT_ROLE
	_slot_uids.assign(team)
	model = OddsEstimator.prepare(contract.contract, GameState.mercs)
	var busy: Array[int] = GameState.busy_uids()
	candidates = []
	for view: MercView in GameState.roster:
		if busy.has(view.uid) or view.status != GuiTypes.MercStatus.AVAILABLE:
			continue
		candidates.append(view)
	summary.set_contract(contract)
	roster.configure(candidates, _score_of)


#Support always, then the contract's Roles (Guide included) in GuiTypes.ROLES order; the leader is never offered.
static func roles_for(data: ContractData) -> Array[String]:
	if data == null:
		return TeamSlot.slot_roles()
	var out: Array[String] = [SUPPORT_ROLE]
	for role_name: String in GuiTypes.ROLES:
		if role_name != ContractResultData.ROLE_LEADER and not out.has(role_name) and data.roles.has(role_name):
			out.append(role_name)
	return out


func _wire_slots() -> void:
	offered_roles = roles_for(contract.contract if contract != null else null)
	for i: int in slot_row.get_child_count():
		var node: TeamSlot = slot_at(i)
		if node == null:
			continue
		node.set_slot(i, _caption_for(i))
		node.visible = i < slots
		node.required = contract != null and i < contract.merc_min
		node.set_offered(offered_roles)
		node.dropped.connect(place)
		node.cleared.connect(remove_slot)
		node.clicked.connect(open_picker)
		node.role_changed.connect(set_role)
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
	var venture_cost: int = ContractPreview.leg_cost(contract, venture_mode, crew_size)
	var return_cost: int = ContractPreview.leg_cost(contract, return_mode, crew_size)
	venture_selector.select_key(str(venture_mode.get("key", "")))
	return_selector.select_key(str(return_mode.get("key", "")))
	var entry: BoardEntry = _gate_entry()
	var shown: Array[String] = _shown_keys(entry)
	var bars: Dictionary = _bars(entry)
	var return_hold: int = 0 if str(return_mode.get("key", "")) == Reachability.FOOT else return_cost
	venture_selector.configure(crew_size, contract.merc_min, contract.distance_km,
		GameState.bank_notes, return_hold, shown, venture_keys(), bars)
	return_selector.configure(crew_size, contract.merc_min, contract.distance_km,
		GameState.bank_notes, venture_cost, shown, shown, bars)
	preview_panel.set_preview(ContractPreview.preview(contract, venture_mode, return_mode, crew_size))
	var odds: int = current_odds()
	action_bar.set_odds(odds)
	action_bar.set_hint(_hint_for(odds))
	action_bar.set_ready(ready_to_dispatch())
	action_bar.set_dirty(is_dirty())
	team_count.text = team_count_text()


func _refresh_slots() -> void:
	_play_slot_sound()
	var leader: MercenaryData = _leader_merc()
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
		var own: Array[Dictionary] = []
		var shared: Array[Dictionary] = []
		for row: Dictionary in MatchScore.merc_rows(contract.contract, view.merc, leader):
			if bool(row["shared"]):
				shared.append(row)
			else:
				own.append(row)
		node.set_member(view, _stars_for(i), own, shared)
		node.set_role(roles[i])


#A slot that gained a merc plays equip, a swap or a move included; slots that only emptied play unequip.
func _play_slot_sound() -> void:
	var gained: bool = false
	var lost: bool = false
	for i: int in team.size():
		if team[i] != 0 and team[i] != _slot_uids[i]:
			gained = true
		elif team[i] == 0 and _slot_uids[i] != 0:
			lost = true
	_slot_uids.assign(team)
	if gained:
		UiSfx.play_equip()
	elif lost:
		UiSfx.play_unequip()


func _hint_for(odds: int) -> String:
	if team.is_empty() or team[0] == 0:
		return "Pick a leader"
	var missing: int = contract.merc_min - filled_count()
	if missing > 0:
		return "Fill %d required slots" % missing
	var in_time: Array[String] = venture_keys()
	if in_time.is_empty():
		return "No venture reaches in time"
	var key: String = str(venture_mode.get("key", ""))
	if not in_time.has(key):
		return String(_bars(_gate_entry()).get(key, TravelSelector.REASON_LATE))
	if not fares_ok():
		return "Travel costs exceed your notes"
	return "%d%% success odds" % odds


#The posting's board entry; a view off the board stands in as an unbounded posting at its own distance.
func _gate_entry() -> BoardEntry:
	var entry: BoardEntry = board_entry()
	if entry != null or contract == null:
		return entry
	var stand_in: BoardEntry = BoardEntry.new()
	stand_in.id = contract.entry_id
	stand_in.contract = contract.contract
	stand_in.distance_km = contract.distance_km
	stand_in.completion_hours = contract.completion_hours
	return stand_in


#The tiles the distance allows, in table order; a mode too near for its gate has no tile.
func _shown_keys(entry: BoardEntry) -> Array[String]:
	var out: Array[String] = []
	var km: int = entry.distance_km if entry != null else 0
	for mode: Dictionary in GuiTypes.TRAVEL_MODES:
		var key: String = String(mode["key"])
		if Reachability.distance_ok(key, km):
			out.append(key)
	return out


#The bars that come before time and cost: in the red only foot walks; teleport needs the place's permit.
func _bars(entry: BoardEntry) -> Dictionary:
	var bars: Dictionary = {}
	var in_red: bool = GameState.bank_notes < 0
	var permit: bool = GameState.tele_permit_for(entry)
	for mode: Dictionary in GuiTypes.TRAVEL_MODES:
		var key: String = String(mode["key"])
		if in_red and key != Reachability.FOOT:
			bars[key] = TravelSelector.REASON_RED
		elif key == Reachability.TELEPORT and not permit:
			bars[key] = TravelSelector.REASON_PERMIT
	return bars


#The merc's solo net on the posting; a view with no merc behind it nets 0.
func _score_of(view: MercView) -> float:
	if contract == null or view == null or view.merc == null:
		return 0.0
	return MatchScore.solo_net(contract.contract, view.merc)


#The stars for the merc in one slot: their net in the current team with slot 0 as the leader.
func _stars_for(index: int) -> float:
	var merc: MercenaryData = _merc_of(team[index])
	if contract == null or merc == null:
		return 0.0
	return MatchScore.stars(MatchScore.merc_net(contract.contract, _team_mercs(), merc, _leader_merc()))


func _team_mercs() -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	for uid: int in team_uids():
		var merc: MercenaryData = _merc_of(uid)
		if merc != null:
			out.append(merc)
	return out


func _leader_merc() -> MercenaryData:
	if team.is_empty() or team[0] == 0:
		return null
	return _merc_of(team[0])


func _merc_of(uid: int) -> MercenaryData:
	var view: MercView = _view_of(uid)
	return view.merc if view != null else null


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


#An assigned roster row was clicked: the merc leaves whichever slot holds it.
func _on_roster_remove(uid: int) -> void:
	for i: int in team.size():
		if team[i] == uid:
			remove_slot(i)
			return


func _on_roster_picked(uid: int) -> void:
	var slot: int = _first_empty_slot()
	if slot < 0:
		UiSfx.reject_press()
		return
	place(uid, slot)


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
		UiSfx.reject_press(action_bar.dispatch_button)
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
		"warn", "caution":
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
