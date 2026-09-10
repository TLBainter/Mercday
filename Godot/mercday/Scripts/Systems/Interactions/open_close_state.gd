class_name OpenCloseState

#Reusable open/closed flag for obstacles: doors now, containers later.
#This class owns the dictionary key; nothing else may read or write it.
const KEY := "is_open"


static func is_open(obs: Dictionary) -> bool:
	return obs.get(KEY, false) as bool


static func set_open(obs: Dictionary, value: bool) -> void:
	obs[KEY] = value


#Flips the flag and returns the new value.
static func toggle(obs: Dictionary) -> bool:
	var next := not is_open(obs)
	obs[KEY] = next
	return next
