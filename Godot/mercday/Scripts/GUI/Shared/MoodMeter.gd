class_name MoodMeter extends HBoxContainer

#A row of MoodFace atoms it spawns itself, lowest first; the lit one is filled, the rest show the
#outline only. The mood row holds the five merc moods and names the lit one in its tooltip; a guild
#row holds one face per opinion from min_opinion to max_opinion and lights opinion.
#set_from_relationship reads a merc pair's relationship value off MercView.

@export var mood: int = 2:
	set(value):
		mood = value
		_refresh()
@export var face_colors: Array[Color] = MoodFace.MOOD_COLORS.duplicate():
	set(value):
		face_colors = value
		_refresh()
@export var guild: bool = false:
	set(value):
		guild = value
		_rebuild()
@export var min_opinion: int = -5:
	set(value):
		min_opinion = value
		_rebuild()
@export var max_opinion: int = 5:
	set(value):
		max_opinion = value
		_rebuild()
#The guild level a guild row lights, held inside min_opinion to max_opinion.
@export var opinion: int = 0:
	set(value):
		opinion = value
		_refresh()
@export var pixel_scale: int = 2:
	set(value):
		pixel_scale = maxi(1, value)
		_rebuild()

var faces: Array[MoodFace] = []


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_node_ready():
		return
	GuiNodes.clear(self)
	faces.clear()
	var count: int = max_opinion - min_opinion + 1 if guild else MoodFace.MOOD_NAMES.size()
	for i: int in maxi(0, count):
		var face: MoodFace = MoodFace.new()
		face.name = "Face%d" % i
		face.guild = guild
		if guild:
			face.opinion = min_opinion + i
		else:
			face.mood = i
		face.pixel_scale = pixel_scale
		add_child(face)
		faces.append(face)
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	var lit: int = clampi(opinion, min_opinion, max_opinion) - min_opinion if guild else mood
	for i: int in faces.size():
		faces[i].filled = i == lit
		if not guild and i < face_colors.size():
			faces[i].fill_color = face_colors[i]
	if not guild and mood >= 0 and mood < MoodFace.MOOD_NAMES.size():
		tooltip_text = MoodFace.MOOD_NAMES[mood]


func set_from_relationship(value: int) -> void:
	mood = MercView.relationship_face(value)
