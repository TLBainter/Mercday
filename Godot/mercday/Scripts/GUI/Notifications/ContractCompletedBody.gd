class_name ContractCompletedBody extends HBoxContainer

#The body of a contract row: the difficulty stars, then the reward behind a small orange note tile.
#The outcome is never shown here; a failed contract reads the same as a completed one.

const STARS_SCENE: String = "res://Scenes/GUI/Shared/DifficultyStars.tscn"
const STAR_SIZE: int = 1
const NOTE_COLOR: Color = Color("#0a0f1c")

@export var reward_label_path: NodePath = ^"RewardRow/RewardLabel"
@export var note_glyph_path: NodePath = ^"RewardRow/NoteBox/Center/NoteGlyph"

var _stars: DifficultyStars = null
var _reward: Label = null
var _glyph: TextureRect = null
var _row: NotificationData = null


func _ready() -> void:
	_reward = get_node_or_null(reward_label_path) as Label
	_glyph = get_node_or_null(note_glyph_path) as TextureRect
	if _glyph != null:
		_glyph.texture = Icons.tinted("note", NOTE_COLOR, 1, true)
	_build_stars()
	_refresh()


func apply(data: NotificationData) -> void:
	_row = data
	_refresh()


func stars() -> DifficultyStars:
	return _stars


func difficulty() -> float:
	if _row == null:
		return 0.0
	return float(_row.snap.get("difficulty", 0.0))


func reward_text() -> String:
	if _row == null:
		return ""
	var raw: Variant = _row.snap.get("reward", 0)
	if raw is String:
		return String(raw)
	return NotificationData.grouped(int(raw))


func _build_stars() -> void:
	if _stars != null or not ResourceLoader.exists(STARS_SCENE):
		return
	var scene: PackedScene = load(STARS_SCENE) as PackedScene
	if scene == null:
		return
	_stars = scene.instantiate() as DifficultyStars
	if _stars == null:
		return
	_stars.star_size = STAR_SIZE
	add_child(_stars)
	move_child(_stars, 0)


func _refresh() -> void:
	if _stars != null:
		_stars.rating = difficulty()
	if _reward != null:
		_reward.text = reward_text()
