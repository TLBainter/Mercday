class_name GuildTargeting extends VBoxContainer

#What a Guild Promo campaign asks for: who it speaks to, the difficulty band, the contract types
#and the locations. The rows come from TraitFilterDefs.contract_defs, so a locked Guild Promo tier
#keeps its own row shut; this screen only decides where each row sits and which locations the
#chosen method cannot reach.

signal changed(sel: Dictionary)
signal take_me_there(target: Dictionary)

const SECTION_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/FilterSection.tscn")
const FONT_BODY: FontVariation = GuiStyle.BODY
const NOTE_COLOR: Color = GuiColors.MUTED
const NOTE_SIZE: int = 10
const ROW_GAP: int = 10
const COLUMN_GAP: int = 12
const TARGET_KEY: StringName = &"target"
const DIFF_KEY: StringName = &"diff"
#The difficulty rows sit in the full width top column, so their stars draw at 32 px.
const DIFF_STAR_SCALE: int = 2
const TYPE_KEY: StringName = &"ctype"
const LOC_KEY: StringName = &"loc"
const LOCK_VERB: String = "target"
const NOTE_TEXT: String = "Level and reward can't be targeted."
const NO_RADIO: String = "No radio coverage"
const TARGET_JOIN: String = ", "

@onready var top: VBoxContainer = $Top
@onready var columns: HBoxContainer = $Columns
@onready var type_column: VBoxContainer = $Columns/TypeCol
@onready var loc_column: VBoxContainer = $Columns/LocCol
@onready var note: Label = $Note

var _type_key: StringName = &"flyers"
var _ent: Dictionary = {}
var _values: Dictionary = {}
var _sections: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override(&"separation", ROW_GAP)
	top.add_theme_constant_override(&"separation", ROW_GAP)
	columns.add_theme_constant_override(&"separation", COLUMN_GAP)
	type_column.size_flags_horizontal = SIZE_EXPAND_FILL
	loc_column.size_flags_horizontal = SIZE_EXPAND_FILL
	GuiStyle.paint(note, FONT_BODY, NOTE_SIZE, NOTE_COLOR)
	note.text = NOTE_TEXT
	_build()


#The campaign method decides which rows appear and which locations it can reach.
func setup(type_key: StringName, ent: Dictionary) -> void:
	_type_key = type_key
	_ent = ent.duplicate()
	if is_node_ready():
		_build()


func set_sel(values: Dictionary) -> void:
	_values = values.duplicate(true)
	if not is_node_ready():
		return
	for key: StringName in _sections.keys():
		var section: FilterSection = _sections[key] as FilterSection
		section.set_value(_values.get(key, null))


func sel() -> Dictionary:
	var out: Dictionary = {}
	for key: StringName in _sections.keys():
		out[key] = (_sections[key] as FilterSection).value()
	return out


func note_text() -> String:
	return note.text if is_node_ready() else NOTE_TEXT


func section_for(key: StringName) -> FilterSection:
	return _sections.get(key, null) as FilterSection


func section_keys() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: StringName in _sections.keys():
		out.append(key)
	return out


func has_target() -> bool:
	return not target_keys().is_empty()


#The picked company or event names, ordered the way the def lists its options. A pick-one def
#returns one name at most, a chips def every name that is on.
func target_keys() -> Array[String]:
	var out: Array[String] = []
	var section: FilterSection = section_for(TARGET_KEY)
	if section == null:
		return out
	var value: Variant = section.value()
	var picked: Array = []
	if value is Array:
		picked = value
	elif value != null:
		picked = [value]
	if picked.is_empty():
		return out
	for option: Variant in _def_of(TARGET_KEY).get("options", []) as Array:
		var option_name: String = String(option)
		if picked.has(option_name):
			out.append(option_name)
	return out


#The option indices of the picks, ascending.
func target_indices() -> Array[int]:
	var out: Array[int] = []
	var options: Array = _def_of(TARGET_KEY).get("options", [])
	for key: String in target_keys():
		var found: int = options.find(key)
		if found >= 0:
			out.append(found)
	out.sort()
	return out


func target_text() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for key: String in target_keys():
		parts.append(key)
	return TARGET_JOIN.join(parts)


#The first company or event index behind the pick, or CampaignData.NO_PICK when nothing is picked.
func target_index() -> int:
	var found: Array[int] = target_indices()
	return CampaignData.NO_PICK if found.is_empty() else found[0]


func difficulty_pair() -> Array[float]:
	var section: FilterSection = section_for(DIFF_KEY)
	var out: Array[float] = [TraitFilterDefs.MIN_STARS, TraitFilterDefs.MAX_STARS]
	if section == null:
		return out
	var value: Variant = section.value()
	if value is Array and (value as Array).size() >= 2:
		var pair: Array = value
		out[0] = float(pair[0])
		out[1] = float(pair[1])
	return out


func contract_types() -> Array[String]:
	return CampaignData.type_names_of(_indices(TYPE_KEY))


func locations() -> Array[int]:
	return _indices(LOC_KEY)


func press_value(key: StringName, value: Variant) -> void:
	var section: FilterSection = section_for(key)
	if section != null:
		section.press_value(value)


#Presses the Advertise To or Sponsor chips. A chips row takes every key at once; a pick-one row
#keeps the last key pressed. An empty array clears either row.
func pick_target(keys: Array) -> void:
	var section: FilterSection = section_for(TARGET_KEY)
	if section == null:
		return
	if keys.is_empty():
		section.press_value(null)
		return
	if String(_def_of(TARGET_KEY).get("kind", "")) == TraitFilterDefs.KIND_CHIPS:
		section.press_value(keys.duplicate())
		return
	for key: Variant in keys:
		section.press_value(key)


func toggle_location(index: int) -> void:
	_press_tile(LOC_KEY, index)


func toggle_type(index: int) -> void:
	_press_tile(TYPE_KEY, index)


func tile_for(key: StringName, index: int) -> ModuleTile:
	var section: FilterSection = section_for(key)
	if section == null:
		return null
	for tile: ModuleTile in section.tiles():
		if int(tile.key) == index:
			return tile
	return null


func _press_tile(key: StringName, index: int) -> void:
	var tile: ModuleTile = tile_for(key, index)
	if tile != null:
		tile.press_tile()


func _indices(key: StringName) -> Array[int]:
	var out: Array[int] = []
	var section: FilterSection = section_for(key)
	if section == null:
		return out
	var value: Variant = section.value()
	if value is Array:
		for entry: Variant in value as Array:
			out.append(int(entry))
	return out


func _def_of(key: StringName) -> Dictionary:
	return TraitFilterDefs.find(TraitFilterDefs.contract_defs(_type_key), key)


func _build() -> void:
	_clear()
	for def: Dictionary in TraitFilterDefs.contract_defs(_type_key):
		var key: StringName = StringName(def["key"])
		var parent: VBoxContainer = _parent_for(key)
		var section: FilterSection = SECTION_SCENE.instantiate() as FilterSection
		section.lock_verb = LOCK_VERB
		if key == DIFF_KEY:
			section.star_scale = DIFF_STAR_SCALE
		section.size_flags_horizontal = SIZE_EXPAND_FILL
		parent.add_child(section)
		section.setup(_patched(def), _values.get(key, null), _ent)
		section.value_changed.connect(_on_section_changed)
		section.take_me_there.connect(take_me_there.emit)
		_sections[key] = section


func _parent_for(key: StringName) -> VBoxContainer:
	if key == TYPE_KEY:
		return type_column
	if key == LOC_KEY:
		return loc_column
	return top


#Radio reaches no radio mast in three towns, and a sponsorship buys one place only.
func _patched(def: Dictionary) -> Dictionary:
	var out: Dictionary = def.duplicate(true)
	if StringName(def["key"]) != LOC_KEY:
		return out
	var row: Dictionary = CampaignTypeDefs.find(_type_key)
	out["single"] = bool(row.get("one_loc", false))
	var mods: Array = out.get("mods", [])
	for i: int in range(mods.size()):
		var mod: Dictionary = mods[i]
		if bool(mod.get("disabled", false)):
			continue
		if CampaignTypeDefs.location_allowed(_type_key, i):
			continue
		mod["disabled"] = true
		mod["disabled_reason"] = NO_RADIO
	return out


func _clear() -> void:
	GuiNodes.clear(top)
	GuiNodes.clear(type_column)
	GuiNodes.clear(loc_column)
	_sections.clear()


func _on_section_changed(key: StringName, value: Variant) -> void:
	_values[key] = value
	changed.emit(sel())
