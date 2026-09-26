class_name MoodMeter extends HBoxContainer

#Five MoodFace atoms in mood order; the one matching the current mood is filled, the rest show
#the outline only. set_from_relationship reads a merc pair's relationship value off MercView.

@export var mood: int = 2:
	set(value):
		mood = value
		_refresh()
@export var face_colors: Array[Color] = MoodFace.MOOD_COLORS.duplicate():
	set(value):
		face_colors = value
		_refresh()

@onready var faces: Array[MoodFace] = [$Face0, $Face1, $Face2, $Face3, $Face4]


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	for i: int in range(faces.size()):
		faces[i].filled = (i == mood)
		if i < face_colors.size():
			faces[i].fill_color = face_colors[i]
	if mood >= 0 and mood < MoodFace.MOOD_NAMES.size():
		tooltip_text = MoodFace.MOOD_NAMES[mood]


func set_from_relationship(value: int) -> void:
	mood = MercView.relationship_face(value)
