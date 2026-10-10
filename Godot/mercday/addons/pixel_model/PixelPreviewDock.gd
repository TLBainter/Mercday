@tool
class_name PixelPreviewDock extends VBoxContainer

#Editor dock: pick a kit model, variant and nation, toggle night and wind, rebuild the kit resources.

const STYLE: StringName = &"buern"
const NATIONS_JSON: String = "res://Art/Map/Source/map-nations.json"

var _id: StringName = &""
var _variant: int = -1
var _model: PixelModel

@onready var _pick: OptionButton = $Bar/ModelPick
@onready var _spin: SpinBox = $Bar/Variant
@onready var _nation: OptionButton = $Bar/NationPick
@onready var _night: CheckButton = $Bar/DayNight
@onready var _wind: CheckButton = $Bar/Wind
@onready var _rebuild: Button = $Bar/Rebuild
@onready var _view: SubViewportContainer = $View
@onready var _scene: PixelPreviewScene = $View/Viewport/Scene
@onready var _counts: Label = $Counts


func _ready() -> void:
	_fill_nations()
	_pick.item_selected.connect(_on_pick)
	_spin.value_changed.connect(_on_variant)
	_nation.item_selected.connect(func(_i: int) -> void: _show())
	_night.toggled.connect(_scene.set_night)
	_wind.toggled.connect(_scene.set_wind)
	_rebuild.pressed.connect(func() -> void: PixelKitBuilder.build_all(); refresh())
	_view.gui_input.connect(_on_view_input)
	visibility_changed.connect(_scene.apply_update_mode)
	refresh()


func set_atlas(a: PixelAtlas) -> void:
	($View/Viewport/Scene as PixelPreviewScene).set_atlas(a)


func redraw() -> void:
	if _id != &"":
		_show()


func select(id: StringName) -> void:
	var i: int = _index_of(String(id))
	if i >= 0:
		_pick.select(i)
		_on_pick(i)


func refresh() -> void:
	var keep: String = _pick.get_item_text(_pick.selected) if _pick.selected >= 0 else ""
	_fill_models()
	if keep != "":
		select(StringName(keep))
	elif _pick.item_count > 0:
		_on_pick(0)


func _fill_models() -> void:
	_pick.clear()
	var sorted: Array = Array(PixelKitBuilder.ids())
	sorted.sort()
	for s: Variant in sorted:
		_pick.add_item(String(s))
		for v: int in PixelKitBuilder.variant_count(StringName(s)):
			_pick.add_item("%s#%d" % [s, v])


func _fill_nations() -> void:
	_nation.clear()
	_nation.add_item("0", 0)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(NATIONS_JSON))
	if not (data is Dictionary):
		return
	for n: Variant in (data as Dictionary).get("nations", []):
		var d: Dictionary = n as Dictionary
		_nation.add_item("%d %s" % [int(d.get("id", 0)), d.get("name", "")], int(d.get("id", 0)))


func _on_pick(index: int) -> void:
	var text: String = _pick.get_item_text(index)
	var cut: int = text.find("#")
	_id = StringName(text if cut < 0 else text.substr(0, cut))
	_variant = -1 if cut < 0 else int(text.substr(cut + 1))
	_spin.set_value_no_signal(float(_variant))
	_rebuild_model()


func _on_variant(value: float) -> void:
	_variant = int(value)
	var i: int = _index_of(String(_id) if _variant < 0 else "%s#%d" % [_id, _variant])
	if i >= 0:
		_pick.select(i)
	_rebuild_model()


func _index_of(text: String) -> int:
	for i: int in _pick.item_count:
		if _pick.get_item_text(i) == text:
			return i
	return -1


func _on_view_input(event: InputEvent) -> void:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_scene.orbit(mm.relative)
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_scene.zoom(1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1)


func _rebuild_model() -> void:
	if _model != null and _model.changed.is_connected(_show):
		_model.changed.disconnect(_show)
	_model = PixelKitBuilder.build(_id, STYLE, 0.4, _variant)
	if _model != null:
		_model.changed.connect(_show)
	_show()


func _show() -> void:
	if _model != null:
		_model.invalidate()
	_scene.show_model(_model, _nation.get_selected_id())
	var c: Vector2i = _scene.counts()
	_counts.text = "%d verts, %d parts" % [c.x, c.y]
