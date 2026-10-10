class_name ResultMemberData extends RefCounted

#One merc's line on the contract results panel: how they came home, what they gained and what they are paid.
#The bar fields hold the value at the end of the contract; the _before fields hold the value at departure.

enum Fate {ALIVE, DEAD, CAPTURED, DEPARTED, DEFECTED}

const FATE_NAMES: Array[String] = ["Alive", "Deceased", "Captured", "Departed", "Defected"]

var uid: int = 0
var name: String = ""
var role: String = ""
var tradition: String = ""
var fate: int = Fate.ALIVE
var level_before: int = 0
var level_after: int = 0
#Progress inside level_before when the team left, and how much of the next level is needed.
var xp_before: int = 0
var xp_need: int = 0
var xp_gained: int = 0
#The need of the level gained, used by the carry over fill; 0 keeps xp_need.
var xp_need_after: int = 0
#Each bar is (value at return, maximum).
var hp: Vector2i = Vector2i.ZERO
var ep: Vector2i = Vector2i.ZERO
var mp: Vector2i = Vector2i.ZERO
var hp_before: int = 0
var ep_before: int = 0
var mp_before: int = 0
var mvp: bool = false
var pay: int = 0
#The bonus share held for a captured or departed merc; internal, the panel never shows it.
var owed: int = 0


func fate_name() -> String:
	return FATE_NAMES[clampi(fate, 0, FATE_NAMES.size() - 1)]


func alive() -> bool:
	return fate == Fate.ALIVE


#Taken, fled or switched sides: not home to be paid.
func away() -> bool:
	return fate == Fate.CAPTURED or fate == Fate.DEPARTED or fate == Fate.DEFECTED


#Counted in the bonus split: the living are paid, the captured and the departed are owed their share.
func earns() -> bool:
	return alive() or fate == Fate.CAPTURED or fate == Fate.DEPARTED


#A defector gives up their share and leaves the roster.
func forfeits() -> bool:
	return fate == Fate.DEFECTED


func levelled() -> bool:
	return level_after > level_before


#The merc's live view: the roster's, else one built from the record, so a dead or captive member
#still shows a portrait; null when no record knows the uid.
func merc_view() -> MercView:
	var view: MercView = BenefitsManager.view_of(uid)
	if view != null:
		return view
	var merc: MercenaryData = GameState.merc_by_uid(uid)
	if merc == null:
		var record: RemovedMercRecord = GameState.removed_by_uid(uid)
		if record != null and record.merc != null:
			var status: int = record.status
			if record.reason == GameState.REMOVED_DEFECTED:
				status = GuiTypes.MercStatus.DEFECTED
			return MercView.from_merc(record.merc, status, 0.0,
					GameState.employment_months(record.merc))
		return null
	var state: Dictionary = GameState.merc_status(merc)
	var live: MercView = MercView.from_merc(merc, int(state["status"]), float(state["hours_left"]),
			GameState.employment_months(merc))
	live.status_fraction_left = float(state["fraction"])
	return live
