@tool
class_name PoolPartPage extends PoolPage

#One slot's parts as a grid of PartCells with gender and pack filters, All / None over the filtered cells and the
#slot fill odds. The body page writes body_weights and has no fill odds; every other slot writes part_weights[slot].

const BODY_SLOT: String = "body"
const ALL: String = "All"
const GENDERS: Array[String] = ["All", "F", "M", "K", "U"]
const COLUMNS: int = 8
const ODDS_STEP: float = 0.05

var slot: String = ""

var _cells: Array[PartCell] = []
var _gender: OptionButton = null
var _pack: OptionButton = null
var _odds_check: CheckBox = null
var _odds: SpinBox = null


func _init(page_slot: String = "") -> void:
	slot = page_slot


func visible_cells() -> Array[PartCell]:
	var out: Array[PartCell] = []
	for cell: PartCell in _cells:
		if cell.visible:
			out.append(cell)
	return out


func set_gender_filter(gender: String) -> void:
	ensure_built()
	_gender.select(maxi(0, GENDERS.find(gender)))
	_filter()


func tick_filtered(on: bool) -> void:
	for cell: PartCell in visible_cells():
		cell.set_state(on, cell.weight())
		_store(cell)
	edited.emit()


func _build() -> void:
	size_flags_vertical = SIZE_EXPAND_FILL
	var bar := HBoxContainer.new()
	add_child(bar)
	bar.add_child(label("Gender"))
	_gender = OptionButton.new()
	for g: String in GENDERS:
		_gender.add_item(g)
	_gender.item_selected.connect(_filter.unbind(1))
	bar.add_child(_gender)
	bar.add_child(label("Pack"))
	_pack = OptionButton.new()
	_pack.item_selected.connect(_filter.unbind(1))
	bar.add_child(_pack)
	bar.add_child(button("None", tick_filtered.bind(false)))
	bar.add_child(button("All", tick_filtered.bind(true)))
	if slot != BODY_SLOT:
		bar.add_child(VSeparator.new())
		_odds_check = CheckBox.new()
		_odds_check.text = "Override odds"
		_odds_check.toggled.connect(_on_odds_toggled)
		bar.add_child(_odds_check)
		bar.add_child(label("Fill odds"))
		_odds = weight_box(1.0, ODDS_STEP)
		_odds.value_changed.connect(_on_odds_changed)
		bar.add_child(_odds)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	scroll.add_child(grid)
	var packs: Array[String] = []
	for p: Dictionary in CharacterParts.index().get("parts", []):
		if String(p.get("slot", "")) != slot:
			continue
		var id: String = String(p.get("id", ""))
		var gender: String = String(p.get("gender", ""))
		var pack: String = String(p.get("pack", ""))
		var cell := PartCell.new()
		cell.setup(id, gender, pack, ("%s (%s)" % [id, gender]) if slot == BODY_SLOT else id)
		cell.changed.connect(_on_cell)
		grid.add_child(cell)
		_cells.append(cell)
		if not packs.has(pack):
			packs.append(pack)
	packs.sort()
	_pack.add_item(ALL)
	for pack: String in packs:
		_pack.add_item(pack)


func _load() -> void:
	var weights: Dictionary = _weights()
	for cell: PartCell in _cells:
		var w: float = float(weights.get(cell.part_id, 0.0))
		cell.set_state(w > 0.0, w if w > 0.0 else PartCell.DEFAULT_WEIGHT)
	if _odds != null:
		var has: bool = profile != null and profile.slot_odds.has(slot)
		_odds_check.set_pressed_no_signal(has)
		_odds.set_value_no_signal(float(profile.slot_odds[slot]) if has else float(CharacterOdds.UNIT_ODDS.get(CharacterOdds.unit_of(slot), 0.0)))
		_odds.editable = has


func _weights() -> Dictionary:
	if profile == null:
		return {}
	if slot == BODY_SLOT:
		return profile.body_weights
	return profile.part_weights.get(slot, {}) as Dictionary


func _store(cell: PartCell) -> void:
	if profile == null:
		return
	var weights: Dictionary = _weights()
	if cell.is_ticked():
		weights[cell.part_id] = cell.weight()
	else:
		weights.erase(cell.part_id)
	if slot == BODY_SLOT:
		return
	if weights.is_empty():
		profile.part_weights.erase(slot)
	else:
		profile.part_weights[slot] = weights


func _on_cell(cell: PartCell) -> void:
	_store(cell)
	edited.emit()


func _filter() -> void:
	var gender: String = _gender.get_item_text(_gender.selected)
	var pack: String = _pack.get_item_text(_pack.selected) if _pack.selected >= 0 else ALL
	for cell: PartCell in _cells:
		cell.visible = (gender == ALL or cell.gender == gender) and (pack == ALL or cell.pack == pack)


func _on_odds_toggled(on: bool) -> void:
	_odds.editable = on
	if profile == null:
		return
	if on:
		profile.slot_odds[slot] = _odds.value
	else:
		profile.slot_odds.erase(slot)
		_odds.set_value_no_signal(float(CharacterOdds.UNIT_ODDS.get(CharacterOdds.unit_of(slot), 0.0)))
	edited.emit()


func _on_odds_changed(value: float) -> void:
	if profile == null or not _odds_check.button_pressed:
		return
	profile.slot_odds[slot] = value
	edited.emit()
