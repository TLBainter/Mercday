class_name ConstStates

const BLINDED       := "Blinded"
const BURNING       := "Burning"
const CHARMED       := "Charmed"
const CLIMBING      := "Climbing"
const DEAFENED      := "Deafened"
const DEBILITATED   := "Debilitated"
const DEPOSED       := "Deposed"
const DRENCHED      := "Drenched"
const DYING         := "Dying"
const FATIGUED      := "Fatigued"
const FLANKED       := "Flanked"
const FLYING        := "Flying"
const GRAPPLED      := "Grappled"
const GROUNDED      := "Grounded"
const INHIBITED     := "Inhibited"
const INVISIBLE     := "Invisible"
const MADNESS       := "Madness"
const MUTE          := "Mute"
const POISONED      := "Poisoned"
const SHOCKED       := "Shocked"
const SLOWED        := "Slowed"
const SUFFOCATING   := "Suffocating"
const SURPRISED     := "Surprised"
const TERRIFIED     := "Terrified"
const THREATENED    := "Threatened"
const UNCONSCIOUS   := "Unconscious"
const VULNERABLE    := "Vulnerable"
const COVERED_FULL    := "Covered (Full)"
const COVERED_PARTIAL := "Covered (Partial)"

const STACKING_STATES: Array[String] = [FATIGUED, MADNESS]

const SOURCE_STATES: Array[String] = [GRAPPLED, INHIBITED, SUFFOCATING, CHARMED, TERRIFIED]

# When UNCONSCIOUS is applied it also forces these states
const UNCONSCIOUS_CHILDREN: Array[String] = [DEBILITATED, DEPOSED, VULNERABLE, DEAFENED, MUTE]

static var DATA: Dictionary = {}
static var ALL: Array[String] = []


static func load_from_tsv(path: String) -> void:
	DATA.clear()
	ALL.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("ConstStates: cannot open %s" % path)
		return
	var first := true
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line("\t")
		if first:
			first = false
			continue
		if row.size() < 1:
			continue
		var state_name: String = row[0].strip_edges() if row.size() > 0 else ""
		if state_name == "":
			continue
		var effects: Array[String] = []
		for col: int in [1, 2, 3]:
			var v: String = row[col].strip_edges() if col < row.size() else ""
			if v != "":
				effects.append(v)
		var removals: Array[String] = []
		for col: int in [4, 5]:
			var v: String = row[col].strip_edges() if col < row.size() else ""
			if v != "":
				removals.append(v)
		DATA[state_name] = {
			"effects":      effects,
			"removals":     removals,
			"afflict_text": row[6].strip_edges() if row.size() > 6 else "",
			"remove_text":  row[7].strip_edges() if row.size() > 7 else "",
			"special":      row[8].strip_edges() if row.size() > 8 else "",
			"is_stacking":  state_name in STACKING_STATES,
		}
		ALL.append(state_name)
	file.close()


static func has_state(merc: MercenaryData, state_name: String) -> bool:
	var entry = merc.active_states.get(state_name)
	if entry == null:
		return false
	if entry is Dictionary:
		return entry.get("count", 0) > 0
	return int(entry) > 0


static func get_count(merc: MercenaryData, state_name: String) -> int:
	var entry = merc.active_states.get(state_name)
	if entry == null:
		return 0
	if entry is Dictionary:
		return entry.get("count", 0)
	return int(entry)


static func get_source(merc: MercenaryData, state_name: String) -> MercenaryData:
	var entry = merc.active_states.get(state_name)
	if entry is Dictionary:
		return entry.get("source", null)
	return null


static func apply_state(merc: MercenaryData, state_name: String, source: MercenaryData = null) -> void:
	if state_name in STACKING_STATES:
		var current: int = get_count(merc, state_name)
		merc.active_states[state_name] = current + 1
		return

	if state_name in SOURCE_STATES:
		merc.active_states[state_name] = {"count": 1, "source": source}
	else:
		merc.active_states[state_name] = 1

	if state_name == UNCONSCIOUS:
		for child: String in UNCONSCIOUS_CHILDREN:
			apply_state(merc, child)
	elif state_name == DYING:
		apply_state(merc, UNCONSCIOUS)


static func remove_state(merc: MercenaryData, state_name: String) -> void:
	merc.active_states.erase(state_name)
	if state_name == UNCONSCIOUS:
		for child: String in UNCONSCIOUS_CHILDREN:
			merc.active_states.erase(child)
	elif state_name == DYING:
		remove_state(merc, UNCONSCIOUS)


static func reduce_state(merc: MercenaryData, state_name: String) -> void:
	var current: int = get_count(merc, state_name)
	if current <= 1:
		remove_state(merc, state_name)
	elif state_name in STACKING_STATES:
		merc.active_states[state_name] = current - 1
	else:
		merc.active_states.erase(state_name)


# Flat success-chance penalty from all active stacking/penalty states (negative = hurts merc)
static func get_threshold_penalty(merc: MercenaryData) -> float:
	var penalty: float = 0.0
	penalty -= get_count(merc, FATIGUED) * 5.0
	penalty -= get_count(merc, MADNESS) * 2.5
	if has_state(merc, POISONED):
		penalty -= 5.0
	return penalty
