class_name RestActions

#One Rest Action per completed rest: the table of what each rest kind offers, the score that picks
#one by the merc's situation, and the effect it pays. Take Watch and Repute wait on the ReP system,
#so they are listed and never picked.

const BREATHER_ACTIONS: Array[String] = ["Manifest", "Stretch", "Realign", "Take Watch"]
const RESPITE_ACTIONS: Array[String] = ["Brief Meditation", "Deep Sleep", "Push Onward", "Realign",
	"Repair", "Repute", "Take Watch"]
const FURLOUGH_ACTIONS: Array[String] = ["Meditate", "Prepare", "Relax", "Train"]
const TODO_ACTIONS: Array[String] = ["Take Watch", "Repute"]

const POOL_BASE_SCORE := 1.0
const REALIGN_SCORE := 2.0
const DEEP_SLEEP_SCORE := 2.5
const REPAIR_SCORE := 1.8
const PUSH_HP_WEIGHT := 0.6
const PUSH_HP_OFFSET := 3.0
const PUSH_EP_COST := 2
const PUSH_EP_FLOOR := 2
const MEDITATE_SCALE := 12.0
const PREPARE_SCALE := 6.0
const RELAX_SCALE := 8.0
const TRAIN_BASE := 1.5
const TRAIN_USE_WEIGHT := 1.0
const TRAIN_DEMAND_WEIGHT := 1.0
const TRAIN_UNIQUE_WEIGHT := 0.75
const TRAIN_DICE := 1
const TRAIN_PERCENT := 7.0

#Demand per key, built once: contract boost percent / 5 plus 1 for every authored event naming it.
static var _demand_table: Dictionary = {}
static var _demand_max: float = 0.0
static var _demand_built: bool = false


static func options(kind: String) -> Array[String]:
	if kind == RestSystem.KIND_BREATHER:
		return BREATHER_ACTIONS.duplicate()
	if kind == RestSystem.KIND_RESPITE:
		return RESPITE_ACTIONS.duplicate()
	if kind == RestSystem.KIND_FURLOUGH:
		return FURLOUGH_ACTIONS.duplicate()
	return []


static func is_todo(action: String) -> bool:
	return TODO_ACTIONS.has(action)


#The rest action this merc wants most; ties keep the list order and an all-zero table picks none.
static func choose(kind: String, merc: MercenaryData) -> String:
	return _pick(kind, _score_all(kind, merc, {}))


#Every option of the kind scored once; picked takes the Train key the Train score resolved.
static func _score_all(kind: String, merc: MercenaryData, picked: Dictionary) -> Dictionary:
	var scores: Dictionary = {}
	for action: String in options(kind):
		if is_todo(action):
			continue
		scores[action] = score(action, merc, picked)
	return scores


#The highest scoring option of the kind; ties keep the list order and an all-zero table picks none.
static func _pick(kind: String, scores: Dictionary) -> String:
	var best: String = ""
	var best_score: float = 0.0
	for action: String in options(kind):
		var value: float = float(scores.get(action, 0.0))
		if value > best_score:
			best_score = value
			best = action
	return best


#Chooses, applies and logs one rest action; a merc that took no rest never reaches here.
static func take(kind: String, merc: MercenaryData, lines: Array[String]) -> void:
	if merc == null or merc.is_dead:
		return
	var picked: Dictionary = {}
	var scores: Dictionary = _score_all(kind, merc, picked)
	var listing: String = _score_text(kind, scores)
	var action: String = _pick(kind, scores)
	if action == "":
		lines.append("REST ACTION: %s %s none [%s]" % [merc.merc_name, kind, listing])
		return
	var detail: String = apply(action, merc, str(picked.get("train", "")))
	if detail == "":
		lines.append("REST ACTION: %s %s %s [%s]" % [merc.merc_name, kind, action, listing])
		return
	lines.append("REST ACTION: %s %s %s %s [%s]" % [merc.merc_name, kind, action, detail, listing])


static func _score_text(kind: String, scores: Dictionary) -> String:
	var parts: Array[String] = []
	for action: String in options(kind):
		if is_todo(action):
			parts.append("%s todo" % action)
		else:
			parts.append("%s %.2f" % [action, float(scores.get(action, 0.0))])
	return ", ".join(parts)


#How badly this merc wants the action right now; 0.0 means it is unavailable or waiting on ReP.
#picked, when given, takes the Train key this score resolved so the effect does not resolve it again.
static func score(action: String, merc: MercenaryData, picked: Dictionary = {}) -> float:
	if merc == null or merc.is_dead or is_todo(action):
		return 0.0
	match action:
		"Stretch":
			return _pool_score(merc, merc.current_ep, RestSystem.MAX_EP)
		"Manifest":
			if not ExcessPool.uses_mp(merc):
				return 0.0
			return _pool_score(merc, merc.current_mp, RestSystem.MAX_MP)
		"Brief Meditation":
			return _pool_score(merc, merc.current_hp, RestSystem.MAX_HP)
		"Realign":
			return REALIGN_SCORE if realign_target(merc) != "" else 0.0
		"Deep Sleep":
			if ConstStates.get_count(merc, ConstStates.FATIGUED) <= 0:
				return 0.0
			if StateSources.held_reason(merc, ConstStates.FATIGUED, RestSystem.KIND_RESPITE) != "":
				return 0.0
			return DEEP_SLEEP_SCORE
		"Push Onward":
			var max_ep: int = max_of(merc, RestSystem.MAX_EP)
			if max_ep - PUSH_EP_COST < PUSH_EP_FLOOR:
				return 0.0
			var missing: int = _missing(merc, merc.current_hp, RestSystem.MAX_HP)
			return maxf(0.0, float(missing) * PUSH_HP_WEIGHT - PUSH_HP_OFFSET)
		"Repair":
			if merc.equipped_armor == null or merc.armor_break <= 0:
				return 0.0
			return REPAIR_SCORE
		"Meditate":
			var gain: int = mini(2, ExcessPool.CAP - merc.excess_hp)
			if gain <= 0:
				return 0.0
			return float(gain) * clampf(MEDITATE_SCALE / float(maxi(1, max_of(merc, RestSystem.MAX_HP))), 0.6, 1.6)
		"Prepare":
			var max_mp: int = max_of(merc, RestSystem.MAX_MP)
			if max_mp <= 0 or merc.excess_mp >= ExcessPool.CAP or not ExcessPool.uses_mp(merc):
				return 0.0
			return clampf(PREPARE_SCALE / float(max_mp), 0.5, 2.0)
		"Relax":
			var max_ep_now: int = max_of(merc, RestSystem.MAX_EP)
			if max_ep_now <= 0 or merc.excess_ep >= ExcessPool.CAP:
				return 0.0
			return clampf(RELAX_SCALE / float(max_ep_now), 0.5, 2.0)
		"Train":
			var key: String = train_target(merc)
			picked["train"] = key
			return 0.0 if key == "" else TRAIN_BASE + train_score(merc, key)
	return 0.0


#Pays the action and reports what moved; "" when nothing changed.
#train_key, when given, is the Train target the score already resolved.
static func apply(action: String, merc: MercenaryData, train_key: String = "") -> String:
	if merc == null:
		return ""
	match action:
		"Stretch":
			return _fill_one(merc, "current_ep", RestSystem.MAX_EP, "EP")
		"Manifest":
			return _fill_one(merc, "current_mp", RestSystem.MAX_MP, "MP")
		"Brief Meditation":
			return _fill_one(merc, "current_hp", RestSystem.MAX_HP, "HP")
		"Realign":
			return _realign(merc)
		"Deep Sleep":
			return _deep_sleep(merc)
		"Push Onward":
			return _push_onward(merc)
		"Repair":
			if merc.armor_break <= 0:
				return ""
			merc.armor_break -= 1
			return "armor reduction %d -> %d" % [merc.armor_break + 1, merc.armor_break]
		"Meditate":
			return _excess(merc, "hp", 2, "HP")
		"Prepare":
			return _excess(merc, "mp", 1, "MP")
		"Relax":
			return _excess(merc, "ep", 1, "EP")
		"Train":
			return _train(merc, train_key)
	return ""


#The maximum reduction worth lifting first; ties go HP, then EP, then MP.
static func realign_target(merc: MercenaryData) -> String:
	if merc == null:
		return ""
	var best: String = ""
	var most: int = 0
	for entry: Array in [["hp", merc.max_hp_penalty], ["ep", merc.max_ep_penalty], ["mp", merc.max_mp_penalty]]:
		var amount: int = int(entry[1])
		if amount > most:
			most = amount
			best = str(entry[0])
	return best


#The Knowledge, Tool or Circumstance a Furlough should train; "" when the merc has nothing left.
static func train_target(merc: MercenaryData) -> String:
	var best: String = ""
	var best_score: float = -1.0
	for key: String in _train_candidates(merc):
		var value: float = train_score(merc, key)
		if value > best_score:
			best_score = value
			best = key
	return best


#Use share, contract demand share and a bonus when nobody else in the guild holds it.
static func train_score(merc: MercenaryData, key: String) -> float:
	if merc == null or key == "":
		return 0.0
	var total: int = 0
	for value: Variant in merc.use_counts.values():
		total += int(value)
	var use_share: float = float(int(merc.use_counts.get(key, 0))) / float(maxi(1, total))
	var want: float = demand(key)
	var demand_share: float = 0.0 if _demand_max <= 0.0 else want / _demand_max
	var unique: float = 1.0 if want > 0.0 and GuildRoster.holders(key, merc) == 0 else 0.0
	return TRAIN_USE_WEIGHT * use_share + TRAIN_DEMAND_WEIGHT * demand_share + TRAIN_UNIQUE_WEIGHT * unique


#How much the contract library asks for this key; 0.0 when nothing names it.
static func demand(key: String) -> float:
	_build_demand()
	return float(_demand_table.get(key, 0.0))


#Ends every training a Furlough granted and gives back what a Circumstance was lent.
static func end_training(merc: MercenaryData) -> String:
	if merc == null or merc.trained_bonus.is_empty():
		return ""
	var names: Array[String] = []
	for key: String in merc.trained_bonus.keys():
		var parts: PackedStringArray = GuildRoster.split_key(key)
		var name: String = parts[1]
		if parts[0] == "circumstance":
			var held: float = float(merc.circumstance_additional_bonus.get(name, 0.0))
			merc.circumstance_additional_bonus[name] = maxf(0.0, held - float(merc.trained_bonus[key]))
		names.append(name)
	merc.trained_bonus.clear()
	return "training ended (%s)" % ", ".join(names)


#Effects

static func _fill_one(merc: MercenaryData, field: String, max_key: String, label: String) -> String:
	var before: int = int(merc.get(field))
	var maximum: int = max_of(merc, max_key)
	if before >= maximum:
		return ""
	merc.set(field, before + 1)
	return "%s %d -> %d" % [label, before, before + 1]


static func _realign(merc: MercenaryData) -> String:
	var target: String = realign_target(merc)
	if target == "":
		return ""
	var field: String = "max_%s_penalty" % target
	var before: int = int(merc.get(field))
	merc.set(field, before - 1)
	StatCalculator.refresh(merc)
	return "max %s reduction %d -> %d" % [target.to_upper(), before, before - 1]


static func _deep_sleep(merc: MercenaryData) -> String:
	var before: int = ConstStates.get_count(merc, ConstStates.FATIGUED)
	if before <= 0:
		return ""
	return RestSystem.fatigue_text(merc, before, RestSystem.reduce_fatigue(merc, RestSystem.KIND_RESPITE))


static func _push_onward(merc: MercenaryData) -> String:
	var ep_before: int = max_of(merc, RestSystem.MAX_EP)
	merc.max_ep_penalty += PUSH_EP_COST
	StatCalculator.refresh(merc)
	var hp_before: int = merc.current_hp
	merc.current_hp = max_of(merc, RestSystem.MAX_HP)
	return "max EP %d -> %d, HP %d -> %d" % [ep_before, max_of(merc, RestSystem.MAX_EP),
		hp_before, merc.current_hp]


static func _excess(merc: MercenaryData, kind: String, amount: int, label: String) -> String:
	var before: int = ExcessPool.amount(merc, kind)
	if ExcessPool.add(merc, kind, amount) == 0:
		return ""
	return "excess %s %d -> %d" % [label, before, ExcessPool.amount(merc, kind)]


static func _train(merc: MercenaryData, train_key: String = "") -> String:
	var key: String = train_key if train_key != "" else train_target(merc)
	if key == "":
		return ""
	var parts: PackedStringArray = GuildRoster.split_key(key)
	var name: String = parts[1]
	if parts[0] == "circumstance":
		merc.trained_bonus[key] = TRAIN_PERCENT
		merc.circumstance_additional_bonus[name] = float(
			merc.circumstance_additional_bonus.get(name, 0.0)) + TRAIN_PERCENT
		return "%s +%d%%" % [name, int(TRAIN_PERCENT)]
	merc.trained_bonus[key] = TRAIN_DICE
	return "%s %d dice" % [name, 1 + TRAIN_DICE]


#Scoring and key helpers

static func _pool_score(merc: MercenaryData, current: int, max_key: String) -> float:
	var maximum: int = max_of(merc, max_key)
	if maximum <= 0 or current >= maximum:
		return 0.0
	return POOL_BASE_SCORE + clampf(1.0 - float(current) / float(maximum), 0.0, 1.0)


static func _missing(merc: MercenaryData, current: int, max_key: String) -> int:
	return maxi(0, max_of(merc, max_key) - current)


static func max_of(merc: MercenaryData, max_key: String) -> int:
	if merc == null:
		return 0
	return int(merc.stats.get(max_key, 0))


#Everything this merc could still train, in Circumstance, Knowledge, Tool order.
static func _train_candidates(merc: MercenaryData) -> Array[String]:
	var out: Array[String] = []
	if merc == null:
		return out
	for display: String in merc.circumstance_flags.keys():
		if bool(merc.circumstance_flags[display]):
			out.append("circumstance:" + display)
	for k: UtilityTraitData in merc.knowledges:
		if k != null:
			out.append("knowledge:" + k.utility_name)
	for t: UtilityTraitData in merc.tools:
		if t != null:
			out.append("tool:" + t.utility_name)
	var left: Array[String] = []
	for key: String in out:
		if not merc.trained_bonus.has(key):
			left.append(key)
	return left


static func _build_demand() -> void:
	if _demand_built:
		return
	_demand_built = true
	for row_name: String in ContractLibrary.row_names():
		var data: ContractData = ContractLibrary.contract(row_name)
		if data == null:
			continue
		_add_boosts("knowledge", data.knowledge_boosts)
		_add_boosts("tool", data.tool_boosts)
		_add_boosts("circumstance", data.circumstance_boosts)
	for event_name: String in ContractLibrary.event_names():
		var event: EventData = ContractLibrary.event(event_name)
		if event == null:
			continue
		_add_names("knowledge", event.knowledges)
		_add_names("tool", event.tools)
		_add_names("circumstance", event.circumstances)
	for value: Variant in _demand_table.values():
		_demand_max = maxf(_demand_max, float(value))


static func _add_boosts(prefix: String, boosts: Dictionary) -> void:
	for name: Variant in boosts:
		_bump(prefix + ":" + str(name), float(boosts[name]) / 5.0)


static func _add_names(prefix: String, names: Array[String]) -> void:
	for name: String in names:
		_bump(prefix + ":" + name, 1.0)


static func _bump(key: String, amount: float) -> void:
	_demand_table[key] = float(_demand_table.get(key, 0.0)) + amount
