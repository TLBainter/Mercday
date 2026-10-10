@tool
class_name CharacterBuilderWindow extends Window

#The Character Builder window, built in code. Character tab: roll or bake a seed, the idle frame at 4x and the
#full sheet, save the sheet, rebuild the parts library, bake the NPC preview atlas. Gear tab: random gear icons.

const PREVIEW_DIR: String = "res://Art/Character/Previews"
const NPC_PREVIEW: String = "res://Scripts/Tests/NpcPreview.gd"
const WINDOW_SIZE: Vector2i = Vector2i(1000, 640)
const IDLE_SCALE: int = 4
const GEAR_COUNT: int = 20
const GEAR_SCALE: int = 2

var _seed_box: SpinBox = null
var _count_box: SpinBox = null
var _idle_rect: TextureRect = null
var _sheet_rect: TextureRect = null
var _parts_label: Label = null
var _status: Label = null
var _gear_grid: GridContainer = null
var _save_dialog: FileDialog = null
var _sheet: Image = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	title = "Character Builder"
	visible = false
	var ui_scale: float = maxf(1.0, EditorInterface.get_editor_scale())
	size = Vector2i(Vector2(WINDOW_SIZE) * ui_scale)
	min_size = WINDOW_SIZE
	_rng.randomize()
	var tabs := TabContainer.new()
	tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tabs)
	tabs.add_child(_character_tab())
	tabs.add_child(_gear_tab())
	_save_dialog = FileDialog.new()
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_save_dialog.filters = PackedStringArray(["*.png ; PNG Image"])
	_save_dialog.file_selected.connect(_save_sheet)
	add_child(_save_dialog)


func _character_tab() -> Control:
	var page := VBoxContainer.new()
	page.name = "Character"
	var bar := HBoxContainer.new()
	page.add_child(bar)
	bar.add_child(_label("Seed"))
	_seed_box = SpinBox.new()
	_seed_box.min_value = 0
	_seed_box.max_value = CharacterAppearance.SEED_MAX
	_seed_box.value = 1
	_seed_box.custom_minimum_size.x = 140
	bar.add_child(_seed_box)
	bar.add_child(_button("Roll", _roll))
	bar.add_child(_button("Bake", _bake))
	bar.add_child(_button("Save Sheet PNG", _ask_save))
	bar.add_child(VSeparator.new())
	bar.add_child(_button("Rebuild Parts Library", _rebuild))
	bar.add_child(VSeparator.new())
	bar.add_child(_label("NPCs"))
	_count_box = SpinBox.new()
	_count_box.min_value = 1
	_count_box.max_value = 1000
	_count_box.value = 100
	bar.add_child(_count_box)
	bar.add_child(_button("Bake NPC Preview", _bake_preview))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	var left := VBoxContainer.new()
	body.add_child(left)
	_idle_rect = _image_rect(Vector2(CharacterBaker.FRAME_SIZE, CharacterBaker.FRAME_SIZE) * IDLE_SCALE)
	left.add_child(_idle_rect)
	_parts_label = _label("")
	_parts_label.custom_minimum_size.x = CharacterBaker.FRAME_SIZE * IDLE_SCALE
	_parts_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	left.add_child(_parts_label)
	_sheet_rect = _image_rect(Vector2(CharacterBaker.SHEET_SIZE))
	_sheet_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet_rect.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_child(_sheet_rect)
	_status = _label("")
	page.add_child(_status)
	return page


func _gear_tab() -> Control:
	var page := VBoxContainer.new()
	page.name = "Gear"
	page.add_child(_button("Reroll", _reroll_gear))
	_gear_grid = GridContainer.new()
	_gear_grid.columns = 10
	page.add_child(_gear_grid)
	return page


func _ready() -> void:
	_bake()
	_reroll_gear()


func _roll() -> void:
	_seed_box.value = _rng.randi_range(1, CharacterAppearance.SEED_MAX)
	_bake()


func _bake() -> void:
	var app: CharacterAppearance = CharacterAppearance.roll(int(_seed_box.value))
	if app.is_empty():
		_set_status("seed %d rolled nothing; rebuild the parts library" % app.rng_seed)
		return
	var started: int = Time.get_ticks_msec()
	_sheet = CharacterBaker.bake_sheet(app)
	var idle: Image = CharacterBaker.bake_frame(app, 0, 0)
	_sheet_rect.texture = ImageTexture.create_from_image(_sheet) if _sheet != null else null
	_idle_rect.texture = ImageTexture.create_from_image(idle) if idle != null else null
	var lines: PackedStringArray = PackedStringArray(["gender %s" % app.gender])
	for slot: String in app.slots():
		lines.append("%s: %s" % [slot, app.part_id(slot)])
	_parts_label.text = "\n".join(lines)
	_set_status("seed %d baked in %d ms" % [app.rng_seed, Time.get_ticks_msec() - started])


func _ask_save() -> void:
	if _sheet == null:
		_set_status("nothing baked to save")
		return
	_save_dialog.current_file = "character_%d.png" % int(_seed_box.value)
	_save_dialog.popup_centered_ratio(0.6)


func _save_sheet(path: String) -> void:
	var err: Error = _sheet.save_png(path)
	_set_status("saved %s" % path if err == OK else "cannot save %s (error %d)" % [path, err])


func _rebuild() -> void:
	_set_status("rebuilding the parts library...")
	var out: Dictionary = CharacterPartsBuilder.build(CharacterPartsBuilder.SOURCE_DIR, CharacterPartsBuilder.ITEMS_DIR,
		CharacterPartsBuilder.ITEMS_INDEX)
	CharacterParts.reset()
	CharacterBaker.reset()
	GearIconBaker.reset()
	EditorInterface.get_resource_filesystem().scan()
	var errors: Array = out.get("errors", []) as Array
	for line: Variant in errors:
		push_warning("character_builder: %s" % str(line))
	_set_status("rebuilt: %s" % JSON.stringify(out.get("counts", out)) if errors.is_empty()
		else "rebuilt with %d errors; see the Output panel" % errors.size())
	_bake()


func _bake_preview() -> void:
	var npc: GDScript = load(NPC_PREVIEW) as GDScript
	if npc == null:
		_set_status("cannot load %s" % NPC_PREVIEW)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PREVIEW_DIR))
	var out: Dictionary = npc.call("write", int(_count_box.value), PREVIEW_DIR) as Dictionary
	EditorInterface.get_resource_filesystem().scan()
	var errors: Array = out.get("errors", []) as Array
	_set_status("wrote %s" % str(out.get("path", "")) if errors.is_empty()
		else "preview errors: %s" % str(errors[0]))


func _reroll_gear() -> void:
	for child: Node in _gear_grid.get_children():
		child.queue_free()
	for _i: int in range(GEAR_COUNT):
		var icon: Dictionary = GearIconBaker.random_icon(_rng)
		var img: Image = icon.get("image") as Image
		if img == null:
			continue
		var rect: TextureRect = _image_rect(Vector2(img.get_size() * GEAR_SCALE))
		rect.texture = ImageTexture.create_from_image(img)
		rect.tooltip_text = "%s %s" % [str(icon.get("atlas", "")), str(icon.get("rect", ""))]
		_gear_grid.add_child(rect)


func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text


static func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


static func _button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_press)
	return button


static func _image_rect(min_size_px: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = min_size_px
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return rect
