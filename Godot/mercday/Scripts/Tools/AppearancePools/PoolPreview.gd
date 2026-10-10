@tool
class_name PoolPreview extends VBoxContainer

#Mercs rolled from an ancestry, bloodline and tradition stack: one large sprite at 3x and eight at 2x in a 4x2
#grid. The edited profile's own picker is fixed; the other two choose the stack it is previewed over.

const CHARACTER_SCENE: PackedScene = preload("res://Scenes/characterScene.tscn")
const NONE: String = "(none)"
const REFRESH_ICON: String = "refresh"
const LARGE_SCALE: int = 3
const SMALL_SCALE: int = 2
const GRID_COLUMNS: int = 4
const GRID_COUNT: int = 8
const GRID_GAP: int = 4
#Four 2x frames do not fit the 300 px column, so each small cell clips the frame to its middle 36 px.
const SMALL_CELL: Vector2 = Vector2(72, 128)

var sprites: Array[CharacterSprite] = []
var seeds: Array[int] = []

var _pickers: Dictionary = {}
var _sizes: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


#lists is AppearancePoolsData.load_lists().
func setup(lists: Dictionary) -> void:
	_sizes = lists.get("sizes", {}) as Dictionary
	_rng.randomize()
	var form := GridContainer.new()
	form.columns = 2
	add_child(form)
	for kind: String in AppearanceProfile.KINDS:
		form.add_child(PoolPage.label(kind.capitalize()))
		var picker := OptionButton.new()
		picker.size_flags_horizontal = SIZE_EXPAND_FILL
		picker.add_item(NONE)
		for item: Variant in lists.get(kind, []):
			picker.add_item(String(item))
		picker.item_selected.connect(refresh.unbind(1))
		form.add_child(picker)
		_pickers[kind] = picker
	var refresh_button := Button.new()
	if Icons.has(REFRESH_ICON):
		refresh_button.icon = Icons.tex(REFRESH_ICON)
		refresh_button.tooltip_text = "Refresh"
	else:
		refresh_button.text = "Refresh"
	refresh_button.pressed.connect(reroll)
	add_child(refresh_button)
	var large := CenterContainer.new()
	add_child(large)
	large.add_child(_holder(LARGE_SCALE, Vector2.ONE * CharacterBaker.FRAME_SIZE * LARGE_SCALE))
	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override(&"h_separation", GRID_GAP)
	grid.add_theme_constant_override(&"v_separation", GRID_GAP)
	add_child(grid)
	for _i: int in range(GRID_COUNT):
		grid.add_child(_holder(SMALL_SCALE, SMALL_CELL))
	_new_seeds()


#Fixes the picker of the edited profile's kind to its name; a bloodline also preselects its parent ancestry.
func fix(kind: String, profile_name: String, parent_ancestry: String = "") -> void:
	for k: String in _pickers:
		(_pickers[k] as OptionButton).disabled = k == kind
	_pick(kind, profile_name)
	if not parent_ancestry.is_empty():
		_pick("ancestry", parent_ancestry)


func picked(kind: String) -> String:
	var picker: OptionButton = _pickers.get(kind) as OptionButton
	if picker == null or picker.selected <= 0:
		return ""
	return picker.get_item_text(picker.selected)


func pool() -> ResolvedPool:
	var ancestry: String = picked("ancestry")
	var body_size: int = int(_sizes.get(ancestry, AppearancePoolsData.DEFAULT_SIZE))
	return AppearanceRules.resolve_names(ancestry, picked("bloodline"), picked("tradition"), "", "", body_size)


func refresh() -> void:
	var stack: ResolvedPool = pool()
	for i: int in range(sprites.size()):
		sprites[i].set_appearance(CharacterAppearance.roll(seeds[i], true, stack))


func reroll() -> void:
	_new_seeds()
	refresh()


func _new_seeds() -> void:
	seeds.clear()
	for _i: int in range(sprites.size()):
		seeds.append(_rng.randi_range(1, CharacterAppearance.SEED_MAX))


func _pick(kind: String, item: String) -> void:
	var picker: OptionButton = _pickers.get(kind) as OptionButton
	if picker == null:
		return
	for i: int in range(picker.item_count):
		if picker.get_item_text(i) == item:
			picker.select(i)
			return


func _holder(sprite_scale: int, box: Vector2) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = box
	holder.clip_contents = true
	var sprite: CharacterSprite = CHARACTER_SCENE.instantiate() as CharacterSprite
	sprite.idle_only = true
	sprite.scale = Vector2.ONE * sprite_scale
	sprite.position = box / 2.0
	holder.add_child(sprite)
	sprites.append(sprite)
	return holder
