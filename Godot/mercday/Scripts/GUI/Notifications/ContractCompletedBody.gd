class_name ContractCompletedBody extends HBoxContainer

#The body of a contract row: the difficulty stars, then the reward behind a small orange note tile.
#The outcome is never shown here; a failed contract reads the same as a completed one.

const STAR_SIZE: int = 1
const NOTE_COLOR: Color = GuiColors.INK

@export var reward_label_path: NodePath = ^"RewardRow/RewardLabel"
@export var note_box_path: NodePath = ^"RewardRow/NoteBox"
@export var note_glyph_path: NodePath = ^"RewardRow/NoteBox/Center/NoteGlyph"

var _stars: Stars = null
var _reward: Label = null
var _glyph: TextureRect = null
var _row: NotificationData = null


func _ready() -> void:
	_reward = get_node_or_null(reward_label_path) as Label
	_glyph = get_node_or_null(note_glyph_path) as TextureRect
	#A STOP tile inside the row would drop its hover and replay it on the way back.
	var note_box: Control = get_node_or_null(note_box_path) as Control
	if note_box != null:
		note_box.mouse_filter = MOUSE_FILTER_IGNORE
	if _glyph != null:
		_glyph.texture = CrewGlyphs.note(NOTE_COLOR)
	_build_stars()
	_refresh()


func apply(data: NotificationData) -> void:
	_row = data
	_refresh()


func stars() -> Stars:
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
	return TransactionData.grouped(int(raw))


func _build_stars() -> void:
	if _stars != null:
		return
	_stars = Stars.new()
	_stars.star_px = STAR_SIZE
	#PASS keeps the difficulty tooltip while the hover carries on to the row.
	_stars.mouse_filter = MOUSE_FILTER_PASS
	add_child(_stars)
	move_child(_stars, 0)


func _refresh() -> void:
	if _stars != null:
		_stars.value = difficulty()
	if _reward != null:
		_reward.text = reward_text()
