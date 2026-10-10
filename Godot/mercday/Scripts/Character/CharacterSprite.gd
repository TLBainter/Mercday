@tool
class_name CharacterSprite extends Node2D

#Root script of characterScene.tscn: shows one CharacterAppearance as its baked 9x6 SV sheet on the Sheet
#sprite. SV motion m lives in row m % 6, columns (m / 6) * 3 .. +2.

const HFRAMES: int = CharacterBaker.SHEET_SIZE.x / CharacterBaker.FRAME_SIZE
const VFRAMES: int = CharacterBaker.SHEET_SIZE.y / CharacterBaker.FRAME_SIZE
const MOTION_FRAMES: int = CharacterBaker.MOTION_FRAMES
const MOTIONS: int = 18

#Portraits show motion 0 only, so they bake just its frames.
@export var idle_only: bool = false

@export var appearance: CharacterAppearance = null:
	set(value):
		appearance = value
		_apply()

#The flip lives on this root node only; the Sheet sprite keeps flip_h off.
@export var face_right: bool = true:
	set(value):
		face_right = value
		_apply_facing()

var _frame: int = 0

@onready var sheet: Sprite2D = $Sheet


func _ready() -> void:
	_apply_facing()
	_apply()


func set_appearance(app: CharacterAppearance) -> void:
	appearance = app


#The baked sheet and the facing flip are shown live in the editor but never saved into the scene file.
func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE and sheet != null:
		sheet.texture = null
		scale.x = absf(scale.x)
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_apply_facing()
		_apply()


func set_motion(motion: int, frame: int) -> void:
	_frame = frame_index(motion, frame)
	if sheet != null:
		sheet.frame = _frame


func idle() -> void:
	set_motion(0, 0)


static func frame_index(motion: int, frame: int) -> int:
	var m: int = clampi(motion, 0, MOTIONS - 1)
	var col: int = floori(m / float(VFRAMES)) * MOTION_FRAMES + clampi(frame, 0, MOTION_FRAMES - 1)
	return (m % VFRAMES) * HFRAMES + col


func _apply() -> void:
	if sheet == null:
		return
	sheet.hframes = HFRAMES
	sheet.vframes = VFRAMES
	sheet.texture = CharacterBaker.texture(appearance, idle_only) if appearance != null else null
	sheet.frame = _frame


func _apply_facing() -> void:
	scale.x = -absf(scale.x) if face_right else absf(scale.x)
