class_name SoundLibrary extends Resource

#A set of interchangeable sounds for one cue; each play picks one of them at random.

@export var sounds: Array[AudioStream] = []


func is_empty() -> bool:
	return sounds.is_empty()


func pick() -> AudioStream:
	if sounds.is_empty():
		return null
	return sounds.pick_random()
