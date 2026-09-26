extends Node

#The Phase 1 subscription stub: what the guild has paid to see. The metrics screen reads
#merc_slots to decide whether the Merc Comparison picker is offered. Nothing draws a lock yet.

signal changed

const PHASE1: Dictionary = {"metrics": true, "contract_metrics": true, "merc_metrics": 3,
	"guild_opinion": true, "client_opinion": true}

var _entitlements: Dictionary = PHASE1.duplicate()


func entitlements() -> Dictionary:
	return _entitlements.duplicate()


#Merges the keys given and leaves the rest standing.
func set_entitlements(d: Dictionary) -> void:
	for key: Variant in d:
		_entitlements[key] = d[key]
	changed.emit()


func reset() -> void:
	_entitlements = PHASE1.duplicate()
	changed.emit()


#How many mercs may be plotted at once; two or more opens the comparison picker.
func merc_slots() -> int:
	return int(_entitlements.get("merc_metrics", 0))
