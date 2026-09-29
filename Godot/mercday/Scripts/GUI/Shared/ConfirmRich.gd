class_name ConfirmRich extends RefCounted

#Data carried into ConfirmDialog.ask_rich(): the kicker line, the crew and money rows, and the
#outcome box shown under them. Every field is optional; an empty array or string skips its block.

var kicker: String = ""
var crew: Array[Dictionary] = []
var money: Array[Dictionary] = []
var outcome: String = ""
var outcome_ok: bool = true
