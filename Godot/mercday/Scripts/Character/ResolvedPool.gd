@tool
class_name ResolvedPool extends RefCounted

#The merged appearance weights for one character, built by AppearanceRules. Empty dicts mean pure random.

#part family -> weight
var bodies: Dictionary = {}
#roll unit -> fill chance 0..1
var slot_odds: Dictionary = {}
#slot -> {part family or CharacterOdds.NONE_ID: weight}
var parts: Dictionary = {}
#group -> {row: weight}
var colors: Dictionary = {}
#"weapon" | "armor" -> {item_name: weight}
var gear: Dictionary = {}
var force_kid: bool = false
#A unit the pool does not set stays empty; an unset color group still rolls random.
var strict: bool = false


#Keys in sorted order so a seed is stable; zero and negative weights never win. "" when nothing can be picked.
static func weighted_pick(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var keys: Array = []
	for key: Variant in weights:
		if float(weights[key]) > 0.0:
			keys.append(key)
	if keys.is_empty():
		return ""
	keys.sort()
	var w := PackedFloat32Array()
	for key: Variant in keys:
		w.append(float(weights[key]))
	return str(keys[rng.rand_weighted(w)])
