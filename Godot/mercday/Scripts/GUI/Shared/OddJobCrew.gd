class_name OddJobCrew extends Control

#The shared crew block: Send Mercs (EnvoySlot rows), Pay Mercs and the merc picker modal, wired
#together. Wave 3 screens configure this one widget rather than rebuilding crew UI of their own.

signal team_changed(team: Array[int])
signal pay_changed(per: int)
signal take_me_there(target: Dictionary)

@export var max_mercs: int = 0:
	set(v):
		max_mercs = v
		var cap: int = maxi(1, max_mercs)
		if team.size() > cap:
			team = team.slice(0, cap)
		if is_node_ready():
			_rebuild()
@export var team: Array[int] = []:
	set(v):
		var cap: int = maxi(1, max_mercs)
		team = v.slice(0, cap) if v.size() > cap else v.duplicate()
		if is_node_ready():
			_rebuild()
		team_changed.emit(team)
@export var candidates: Array[Dictionary] = []:
	set(v):
		candidates = v
		if is_node_ready():
			_rebuild()
@export var per: int = 0:
	set(v):
		per = v
		if is_node_ready():
			pay_panel.per = per
		pay_changed.emit(per)
@export var default_pay: int = 0:
	set(v):
		default_pay = v
		if is_node_ready():
			pay_panel.default_pay = default_pay
@export var money: int = 0:
	set(v):
		money = v
		if is_node_ready():
			pay_panel.money = money
@export var tip_kind: String = "Odd Job":
	set(v):
		tip_kind = v
		if is_node_ready():
			_rebuild()
@export var tip_text: String = "Send a merc on this Odd Job.":
	set(v):
		tip_text = v
		if is_node_ready():
			_rebuild()
@export var pick_desc: String = "Sorted by best fit.":
	set(v):
		pick_desc = v
		if is_node_ready():
			picker_node.subtitle = pick_desc
@export var locked: bool = false:
	set(v):
		locked = v
		if is_node_ready():
			send_panel.locked = locked

@onready var pad: MarginContainer = $Pad
@onready var cols: HBoxContainer = $Pad/Cols
@onready var send_panel: SendMercsPanel = $Pad/Cols/SendMercsPanel
@onready var pay_col: MarginContainer = $Pad/Cols/PayCol
@onready var pay_panel: PayMercsPanel = $Pad/Cols/PayCol/PayMercsPanel
@onready var picker_node: MercPicker = $Picker


func _ready() -> void:
	send_panel.slot_pressed.connect(open_picker)
	send_panel.remove_pressed.connect(_remove_at)
	send_panel.take_me_there.connect(func(target: Dictionary) -> void: take_me_there.emit(target))
	picker_node.picked.connect(_on_picker_picked)
	picker_node.removed.connect(_on_picker_removed)
	pay_panel.pay_changed.connect(_on_pay_changed)
	pay_panel.per = per
	pay_panel.default_pay = default_pay
	pay_panel.money = money
	picker_node.subtitle = pick_desc
	send_panel.locked = locked
	_rebuild()


func total() -> int:
	return per * team.size()


func add_merc(id: int) -> void:
	if team.has(id):
		return
	var cap: int = maxi(1, max_mercs)
	if team.size() >= cap:
		return
	var new_team: Array[int] = team.duplicate()
	new_team.append(id)
	team = new_team


func remove_merc(id: int) -> void:
	var pos: int = team.find(id)
	if pos == -1:
		return
	_remove_at(pos)


#Test probe: sets the pay each merc gets.
func set_pay(per_in: int) -> void:
	per = per_in


func open_picker(slot_index: int) -> void:
	var filled: bool = slot_index < team.size()
	picker_node.open_for(slot_index, _picker_rows(slot_index), filled)


func picker() -> MercPicker:
	return picker_node


func _remove_at(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= team.size():
		return
	var new_team: Array[int] = team.duplicate()
	new_team.remove_at(slot_index)
	team = new_team


func _on_picker_picked(id: int, slot_index: int) -> void:
	var new_team: Array[int] = team.duplicate()
	var existing_pos: int = new_team.find(id)
	var target: int = slot_index
	if existing_pos != -1:
		new_team.remove_at(existing_pos)
		if existing_pos < target:
			target -= 1
	if target < new_team.size():
		new_team[target] = id
	else:
		new_team.append(id)
	team = new_team


func _on_picker_removed(slot_index: int) -> void:
	_remove_at(slot_index)


func _on_pay_changed(v: int) -> void:
	per = v


func _lookup(id: int) -> Dictionary:
	for c: Dictionary in candidates:
		if int(c.get("id", -1)) == id:
			return c
	var md: MercenaryData = GameState.merc_by_uid(id)
	if md != null:
		return {"id": id, "name": md.merc_name, "fit": 0.5}
	return {"id": id, "name": "", "fit": 0.5}


func _slot_rows() -> Array[Dictionary]:
	var cap: int = maxi(1, max_mercs)
	var shown: int = mini(cap, team.size() + 1)
	var rows: Array[Dictionary] = []
	for i: int in shown:
		if i < team.size():
			var info: Dictionary = _lookup(team[i])
			rows.append({"index": i, "merc_id": team[i], "merc_name": info.get("name", ""),
				"fit": info.get("fit", 0.5)})
		else:
			rows.append({"index": i, "merc_id": -1, "merc_name": "", "fit": 0.5})
	return rows


func _picker_rows(slot_index: int) -> Array[Dictionary]:
	var exclude: Array[int] = []
	for i: int in team.size():
		if i != slot_index:
			exclude.append(team[i])
	var rows: Array[Dictionary] = []
	for c: Dictionary in candidates:
		if not exclude.has(int(c.get("id", -1))):
			rows.append(c)
	rows.sort_custom(CrewCandidates.by_fit_then_name)
	return rows


func _rebuild() -> void:
	send_panel.locked = locked
	send_panel.tip_kind = tip_kind
	send_panel.tip_text = tip_text
	send_panel.set_slots(_slot_rows())
	pay_panel.team_size = team.size()
	update_minimum_size()


func _get_minimum_size() -> Vector2:
	if pad == null:
		return Vector2.ZERO
	return pad.get_combined_minimum_size()
