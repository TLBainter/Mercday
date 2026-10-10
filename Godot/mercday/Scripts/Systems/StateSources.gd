class_name StateSources


static func source_record(state_name: String, root: String, origin: String,
		removal: Array[String]) -> Dictionary:
	var kind: String = "engine"
	var name: String = ""
	if root != "":
		kind = "state"
		name = root
	elif origin != "":
		var split_at: int = origin.find(":")
		var head: String = origin.substr(0, split_at) if split_at >= 0 else origin
		if ConstStates.SOURCE_KINDS.has(head):
			kind = head
			name = origin.substr(split_at + 1) if split_at >= 0 else ""
		else:
			name = origin
	var verbs: Array[String] = []
	if removal.is_empty():
		verbs = StateCascade.removal_verbs(state_name)
	else:
		verbs.assign(removal)
	return {"kind": kind, "name": name, "removal": verbs}


static func record_entry(merc: MercenaryData, state_name: String, direct: bool) -> Dictionary:
	var record := applied_by(merc)
	if not record.has(state_name):
		record[state_name] = {"direct": direct, "roots": [], "sources": []}
	return record[state_name]


#One entry per kind and name; a repeat application only refreshes the removal verbs of the entry it matches.
static func add_source(merc: MercenaryData, state_name: String, src: Dictionary, direct: bool) -> void:
	var entry := record_entry(merc, state_name, direct)
	var sources: Array = entry["sources"]
	for held: Dictionary in sources:
		if str(held.get("kind", "")) == str(src["kind"]) and str(held.get("name", "")) == str(src["name"]):
			held["removal"] = src["removal"]
			return
	sources.append(src)


#True when a root not yet listed for the state was recorded.
static func record_source(merc: MercenaryData, state_name: String, root: String, was_active: bool) -> bool:
	if root == "":
		var existing = merc.active_states.get(ConstStates.APPLIED_BY_KEY)
		if existing is Dictionary and existing.has(state_name):
			existing[state_name]["direct"] = true
		return false
	var record := applied_by(merc)
	if not record.has(state_name):
		record[state_name] = {"direct": was_active, "roots": [], "sources": []}
	var roots: Array = record[state_name]["roots"]
	if root in roots:
		return false
	roots.append(root)
	return true


static func applied_by(merc: MercenaryData) -> Dictionary:
	if not (merc.active_states.get(ConstStates.APPLIED_BY_KEY) is Dictionary):
		merc.active_states[ConstStates.APPLIED_BY_KEY] = {}
	return merc.active_states[ConstStates.APPLIED_BY_KEY]


#The live record entry of a state; {} when nothing was recorded, and no record is created.
static func applied_entry(merc: MercenaryData, state_name: String) -> Dictionary:
	var record = merc.active_states.get(ConstStates.APPLIED_BY_KEY)
	if not (record is Dictionary):
		return {}
	var entry = (record as Dictionary).get(state_name)
	if not (entry is Dictionary):
		return {}
	return entry


#Copies of the source records of a held state; the caller cannot reach the record through them.
static func state_sources(merc: MercenaryData, state_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for src in sources_ref(merc, state_name):
		if src is Dictionary:
			out.append((src as Dictionary).duplicate(true))
	return out


#Forgets the source recorded for a kind and name; true when one went, the state itself is untouched.
static func drop_source(merc: MercenaryData, state_name: String, kind: String, name: String) -> bool:
	var sources: Array = sources_ref(merc, state_name)
	for i: int in range(sources.size() - 1, -1, -1):
		var src: Dictionary = sources[i]
		if str(src.get("kind", "")) == kind and str(src.get("name", "")) == name:
			sources.remove_at(i)
			return true
	return false


static func source_allows(src: Dictionary, verb: String) -> bool:
	var verbs: Array = src.get("removal", [])
	return verbs.has(verb)


#A cascade source lasts as long as the root state does; every other kind is spent once it is recorded.
static func source_ongoing(merc: MercenaryData, src: Dictionary) -> bool:
	return str(src.get("kind", "")) == "state" and ConstStates.has_state(merc, str(src.get("name", "")))


#A state held before the sources existed answers as one engine source with its own Removal verbs.
static func effective_sources(merc: MercenaryData, state_name: String) -> Array[Dictionary]:
	var out := state_sources(merc, state_name)
	if out.is_empty():
		out.append({"kind": "engine", "name": "", "removal": StateCascade.removal_verbs(state_name)})
	return out


#The live source array of a held state; [] when nothing was recorded, and no record is created.
static func sources_ref(merc: MercenaryData, state_name: String) -> Array:
	var sources = applied_entry(merc, state_name).get("sources")
	if not (sources is Array):
		return []
	return sources


#Why a rest with this verb leaves the state alone; "" when it takes a tier or the whole state.
static func held_reason(merc: MercenaryData, state_name: String, verb: String) -> String:
	if not ConstStates.has_state(merc, state_name):
		return ""
	var allowed: int = 0
	var free: int = 0
	for src: Dictionary in effective_sources(merc, state_name):
		if not source_allows(src, verb):
			continue
		allowed += 1
		if not source_ongoing(merc, src):
			free += 1
	if allowed == 0:
		return "no %s source" % verb
	if free == 0:
		return "ongoing source"
	var roots := StateCascade.applied_roots(merc, state_name)
	if not roots.is_empty():
		return "kept by %s" % ",".join(PackedStringArray(roots))
	return ""


#Drops every cascade source naming this root and answers how many tiers went with it.
static func drop_state_sources(entry: Dictionary, root: String) -> int:
	var sources: Array = entry.get("sources", [])
	var dropped: int = 0
	for i: int in range(sources.size() - 1, -1, -1):
		var src: Dictionary = sources[i]
		if str(src.get("kind", "")) == "state" and str(src.get("name", "")) == root:
			sources.remove_at(i)
			dropped += 1
	return dropped


#Drops the newest recorded source of a state, the tier a plain reduce_state takes.
static func pop_source(merc: MercenaryData, state_name: String) -> void:
	var sources: Array = sources_ref(merc, state_name)
	if not sources.is_empty():
		sources.remove_at(sources.size() - 1)
