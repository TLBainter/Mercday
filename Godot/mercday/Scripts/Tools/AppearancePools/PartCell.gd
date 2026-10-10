@tool
class_name PartCell extends VBoxContainer

#One part in an Appearance Pools grid: frame 0 recolored with palette row 0 of each region group, the caption,
#a tick and a weight that is editable only while ticked.

signal changed(cell: PartCell)

const THUMB: int = 64
const WEIGHT_MAX: float = 10.0
const WEIGHT_STEP: float = 0.1
const DEFAULT_WEIGHT: float = 1.0

var part_id: String = ""
var gender: String = ""
var pack: String = ""

var _check: CheckBox = null
var _weight: SpinBox = null


func setup(id: String, part_gender: String, part_pack: String, caption: String) -> void:
	part_id = id
	gender = part_gender
	pack = part_pack
	tooltip_text = id
	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(THUMB, THUMB)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	thumb.texture = thumbnail(id)
	add_child(thumb)
	var name_label: Label = PoolPage.label(caption)
	name_label.clip_text = true
	name_label.custom_minimum_size.x = THUMB
	add_child(name_label)
	_check = CheckBox.new()
	_check.toggled.connect(_on_toggled)
	add_child(_check)
	_weight = PoolPage.weight_box(WEIGHT_MAX, WEIGHT_STEP)
	_weight.value = DEFAULT_WEIGHT
	_weight.editable = false
	_weight.value_changed.connect(_on_weight)
	add_child(_weight)


func set_state(ticked: bool, w: float) -> void:
	_check.set_pressed_no_signal(ticked)
	_weight.set_value_no_signal(w)
	_weight.editable = ticked


#Ticks or unticks as a click would, emitting changed.
func set_ticked(on: bool) -> void:
	_check.button_pressed = on


func is_ticked() -> bool:
	return _check.button_pressed


func weight() -> float:
	return _weight.value


func _on_toggled(on: bool) -> void:
	_weight.editable = on
	changed.emit(self)


func _on_weight(_value: float) -> void:
	if is_ticked():
		changed.emit(self)


static func thumbnail(id: String) -> Texture2D:
	var pair: Array[Image] = CharacterParts.load_pair(id)
	if pair.is_empty() or pair[0] == null:
		return null
	var rows: Dictionary = {}
	for region: Dictionary in CharacterParts.part(id).get("regions", []):
		var key_text: String = CharacterAppearance.region_key(region.get("key", []))
		var row: Image = CharacterParts.palette_row(String(region.get("group", CharacterParts.DEFAULT_GROUP)), 0)
		if not key_text.is_empty() and row != null:
			rows[key_text] = row
	var mask: Image = pair[1] if pair.size() > 1 else null
	return ImageTexture.create_from_image(CharacterBaker.recolor(pair[0], mask, Rect2i(0, 0, THUMB, THUMB), rows))
