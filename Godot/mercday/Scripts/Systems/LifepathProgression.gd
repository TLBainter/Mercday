class_name LifepathProgression

#Lifepath events gained after character creation. A merc qualifies for events during a contract,
#then rolls for one on every level up against a chance that doubles until it lands.
#Buddy and In Love bind two mercs; their forced counterparts stand in when the bond breaks.

const MAX_EVENTS := 8
const BASE_CHANCE := 5
const DECIDE_CHANCE := 5
const BUDDY := "Buddy"
const IN_LOVE := "In Love"
const BUDDYS_PASSING := "Buddy's Passing"
const FOREVER_YEARNING := "Forever Yearning"
#Events whose payoff lives in this file rather than in a trait effect cell.
const CODED_EVENTS: Array[String] = [BUDDY, IN_LOVE]
#Forced event -> the event it stands in for when that bond breaks.
const FORCED_REPLACES: Dictionary = {
	BUDDYS_PASSING: BUDDY,
	FOREVER_YEARNING: IN_LOVE,
}

static var _team: Array[MercenaryData] = []


static func clear() -> void:
	_team.clear()


static func begin_contract(run: ContractRun) -> void:
	_team.clear()
	if run == null:
		return
	_team.assign(run.team)


#Pools every event each surviving merc newly qualifies for, then settles the two paired bonds.
static func end_contract(run: ContractRun) -> Array[String]:
	var lines: Array[String] = []
	if run == null:
		return lines
	_team.clear()
	_team.assign(run.team)
	for merc: MercenaryData in run.team:
		lines.append_array(refresh_pool(merc, run))
	for merc: MercenaryData in run.team:
		lines.append_array(_settle_buddy(merc, run))
	for merc: MercenaryData in run.team:
		lines.append_array(_settle_beau(merc, run))
	return lines


static func refresh_pool(merc: MercenaryData, run: ContractRun) -> Array[String]:
	var lines: Array[String] = []
	if merc == null or merc.merc_uid <= 0:
		return lines
	var pool: Array = DataManager.lifepaths_by_category.get("Experienced", []) as Array
	for lp: LifepathData in pool:
		if merc.lifepath_pool.has(lp.event_name) or not eligible(merc, lp, run):
			continue
		merc.lifepath_pool.append(lp.event_name)
		lines.append("LIFEPATH POOL: %s now qualifies for %s" % [merc.merc_name, lp.event_name])
	return lines


static func eligible(merc: MercenaryData, lp: LifepathData, run: ContractRun) -> bool:
	if lp == null or lp.event_type != "Experienced":
		return false
	if has_event(merc, lp.event_name) or not has_payoff(lp):
		return false
	if not LifepathRequirements.is_supported(lp):
		return false
	return LifepathRequirements.allows(merc, lp, run)


#An event pays off when this file handles it or one of its traits carries a real effect cell.
#A [COLUMN] trait name pays off when any Types.tsv variant of it carries a DSL cell.
static func has_payoff(lp: LifepathData) -> bool:
	if lp == null:
		return false
	if CODED_EVENTS.has(lp.event_name):
		return true
	var names: Array[String] = []
	names.append_array(lp.perks)
	names.append_array(lp.drawbacks)
	for trait_name: String in names:
		if trait_name.contains("["):
			for variant: String in MercGenerator.placeholder_variants(trait_name):
				var vt: TraitData = DataManager.traits.get(variant, null) as TraitData
				if vt != null and vt.effect_dsl != "" and not vt.effect_dsl.begins_with("SPECIAL:"):
					return true
			continue
		var td: TraitData = MercGenerator._lookup_trait(trait_name)
		if td != null and td.effect_dsl != "" and not td.effect_dsl.begins_with("SPECIAL:"):
			return true
	return false


static func has_event(merc: MercenaryData, event_name: String) -> bool:
	if merc == null:
		return false
	for lp: LifepathData in merc.lifepaths:
		if lp != null and lp.event_name == event_name:
			return true
	return false


#5 percent doubling per level gained without an event, with the merc's Luck added after.
static func chance_for(merc: MercenaryData) -> int:
	if merc == null:
		return 0
	var base: int = BASE_CHANCE * int(pow(2.0, float(maxi(0, merc.lifepath_roll_step))))
	base = mini(base, 100)
	return clampi(base + int(merc.stats.get("luck", 0)), 0, 100)


#Draws one pool name through the same rarity table every other pool roll uses.
static func draw(pool: Array[String]) -> String:
	var items: Array[Dictionary] = []
	for event_name: String in pool:
		var lp: LifepathData = _find(event_name)
		if lp == null:
			continue
		items.append({"name": event_name, "rarity": lp.rarity})
	if items.is_empty():
		return ""
	return WeightedTable.roll(items)


#Called once per level gained. An empty pool still advances the step so the chance keeps doubling.
static func on_level_up(merc: MercenaryData) -> Array[String]:
	var lines: Array[String] = []
	if merc == null or merc.merc_uid <= 0:
		return lines
	var chance := chance_for(merc)
	if randi_range(1, 100) > chance:
		merc.lifepath_roll_step += 1
		return lines
	if merc.lifepath_pool.is_empty():
		merc.lifepath_roll_step += 1
		return lines
	var pick: String = draw(merc.lifepath_pool)
	if pick == "":
		merc.lifepath_roll_step += 1
		return lines
	lines.append("LIFEPATH ROLL: %s hit %d%% and draws %s" % [merc.merc_name, chance, pick])
	var gained := grant(merc, pick)
	if gained.is_empty():
		merc.lifepath_roll_step += 1
		return lines
	merc.lifepath_roll_step = 0
	lines.append_array(gained)
	return lines


#Adds an Experienced event and runs its pairing, returning empty when no slot could be freed.
static func grant(merc: MercenaryData, event_name: String) -> Array[String]:
	var lines: Array[String] = []
	var lp: LifepathData = _find(event_name)
	if merc == null or lp == null or has_event(merc, event_name):
		return lines
	if not _make_room(merc, false, lines):
		return lines
	merc.lifepath_pool.erase(event_name)
	_apply(merc, lp)
	lines.append("LIFEPATH GAINED: %s takes %s" % [merc.merc_name, event_name])
	match event_name:
		BUDDY:
			lines.append_array(_pair_buddy(merc))
		IN_LOVE:
			lines.append_array(_pair_beau(merc))
	return lines


#Adds a Forced event, replacing the event it stands in for when the merc holds it.
static func force(merc: MercenaryData, event_name: String) -> Array[String]:
	var lines: Array[String] = []
	var lp: LifepathData = _find(event_name)
	if merc == null or lp == null or has_event(merc, event_name):
		return lines
	var replaces: String = str(FORCED_REPLACES.get(event_name, ""))
	if replaces != "" and has_event(merc, replaces):
		_remove(merc, replaces)
		lines.append("LIFEPATH REPLACED: %s loses %s" % [merc.merc_name, replaces])
	elif not _make_room(merc, true, lines):
		return lines
	_apply(merc, lp)
	lines.append("LIFEPATH FORCED: %s takes %s" % [merc.merc_name, event_name])
	return lines


#Frees a slot when the list is full. Forced events evict the oldest Experienced event,
#falling back to the oldest Forced one only when no Experienced event is left.
static func _make_room(merc: MercenaryData, is_forced: bool, lines: Array[String]) -> bool:
	if merc.lifepaths.size() < MAX_EVENTS:
		return true
	if not is_forced:
		return false
	var victim: LifepathData = _oldest_of(merc, "Experienced")
	if victim == null:
		victim = _oldest_of(merc, "Forced")
	if victim == null:
		return false
	merc.lifepaths.erase(victim)
	_strip_traits(merc, victim)
	lines.append("LIFEPATH DISPLACED: %s loses %s" % [merc.merc_name, victim.event_name])
	return true


static func _oldest_of(merc: MercenaryData, event_type: String) -> LifepathData:
	for lp: LifepathData in merc.lifepaths:
		if lp != null and lp.event_type == event_type:
			return lp
	return null


static func _find(event_name: String) -> LifepathData:
	for category: String in DataManager.lifepaths_by_category:
		for lp: LifepathData in DataManager.lifepaths_by_category[category] as Array:
			if lp != null and lp.event_name == event_name:
				return lp
	return DataManager.starting_lifepaths.get(event_name, null) as LifepathData


static func _remove(merc: MercenaryData, event_name: String) -> void:
	for lp: LifepathData in merc.lifepaths:
		if lp != null and lp.event_name == event_name:
			merc.lifepaths.erase(lp)
			_strip_traits(merc, lp)
			return


#Records what the event moved so a later displacement can put the stats back exactly.
static func _apply(merc: MercenaryData, lp: LifepathData) -> void:
	merc.lifepaths.append(lp)
	var flat_before: Dictionary = merc.stat_flat_bonuses.duplicate(true)
	var mult_before: Dictionary = merc.stat_multipliers.duplicate(true)
	var resolved: Array[String] = []
	for trait_name: String in _trait_names(lp):
		var td: TraitData = MercGenerator._lookup_trait(trait_name)
		if td == null:
			continue
		MercGenerator._assign_trait(merc, td)
		MercGenerator._apply_dsl_to_merc(merc, td.effect_dsl)
		resolved.append(td.trait_name)
	MercGenerator._apply_stat_bonus_5pct(merc, lp.stat_bonus_5pct)
	merc.lifepath_stat_deltas[lp.event_name] = {
		"flat": _delta(flat_before, merc.stat_flat_bonuses),
		"mult": _delta(mult_before, merc.stat_multipliers),
		"traits": resolved,
	}
	StatCalculator.refresh(merc)


static func _delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in after:
		var moved: float = float(after[key]) - float(before.get(key, 0.0))
		if not is_zero_approx(moved):
			out[key] = moved
	return out


#Undoes the recorded stat change and drops the traits; granted knowledges and circumstances stay.
static func _strip_traits(merc: MercenaryData, lp: LifepathData) -> void:
	var record: Dictionary = merc.lifepath_stat_deltas.get(lp.event_name, {}) as Dictionary
	var granted: Array = record.get("traits", []) as Array
	if granted.is_empty():
		for trait_name: String in _trait_names(lp):
			var td: TraitData = MercGenerator._lookup_trait(trait_name)
			if td == null:
				continue
			merc.perks.erase(td)
			merc.drawbacks.erase(td)
			merc.descriptors.erase(td)
	else:
		for name: String in granted:
			_erase_named(merc, name)
	_unwind(merc.stat_flat_bonuses, record.get("flat", {}) as Dictionary)
	_unwind(merc.stat_multipliers, record.get("mult", {}) as Dictionary)
	merc.lifepath_stat_deltas.erase(lp.event_name)
	StatCalculator.refresh(merc)


#A placeholder trait resolves to a different row on every lookup, so drop it by the recorded name.
static func _erase_named(merc: MercenaryData, trait_name: String) -> void:
	for store: Array in [merc.perks, merc.drawbacks, merc.descriptors]:
		for i: int in range(store.size() - 1, -1, -1):
			var td: TraitData = store[i] as TraitData
			if td != null and td.trait_name == trait_name:
				store.remove_at(i)
				return


static func _unwind(store: Dictionary, moved: Dictionary) -> void:
	for key: String in moved:
		var left: float = float(store.get(key, 0.0)) - float(moved[key])
		if is_zero_approx(left):
			store.erase(key)
		else:
			store[key] = left


static func _trait_names(lp: LifepathData) -> Array[String]:
	var names: Array[String] = []
	names.append_array(lp.perks)
	names.append_array(lp.drawbacks)
	return names


#The merc feels closest to gets Buddy back, so the bond always reads the same from both sides.
static func _pair_buddy(merc: MercenaryData) -> Array[String]:
	var lines: Array[String] = []
	var pal: MercenaryData = RelationshipSystem.best_ally(merc, _team)
	if pal == null:
		return lines
	merc.buddy_uid = pal.merc_uid
	lines.append("BUDDY: %s pairs with %s" % [merc.merc_name, pal.merc_name])
	if has_event(pal, BUDDY):
		return lines
	var mirror := grant(pal, BUDDY)
	if mirror.is_empty():
		lines.append("BUDDY: %s has no room to return it" % pal.merc_name)
		return lines
	pal.buddy_uid = merc.merc_uid
	lines.append_array(mirror)
	return lines


#In Love is one-sided at first; the beau decides for themselves after a later shared contract.
static func _pair_beau(merc: MercenaryData) -> Array[String]:
	var lines: Array[String] = []
	var beau: MercenaryData = RelationshipSystem.best_ally(merc, _team)
	if beau == null:
		return lines
	merc.beau_uid = beau.merc_uid
	lines.append("IN LOVE: %s pines for %s" % [merc.merc_name, beau.merc_name])
	return lines


#A dead buddy turns Buddy into Buddy's Passing.
static func _settle_buddy(merc: MercenaryData, run: ContractRun) -> Array[String]:
	var lines: Array[String] = []
	if merc == null or merc.buddy_uid <= 0 or not has_event(merc, BUDDY):
		return lines
	var lost := false
	for dead: MercenaryData in run.casualties:
		if dead != null and dead.merc_uid == merc.buddy_uid:
			lost = true
			break
	if not lost:
		return lines
	merc.buddy_uid = 0
	lines.append_array(force(merc, BUDDYS_PASSING))
	return lines


#Each shared contract gives the beau a chance to decide; a rejection turns In Love into yearning.
static func _settle_beau(merc: MercenaryData, run: ContractRun) -> Array[String]:
	var lines: Array[String] = []
	if merc == null or merc.beau_uid <= 0 or not has_event(merc, IN_LOVE):
		return lines
	var beau: MercenaryData = _in_team(run, merc.beau_uid)
	if beau == null or has_event(beau, IN_LOVE):
		return lines
	var decide := clampi(DECIDE_CHANCE + int(beau.stats.get("luck", 0)), 0, 100)
	if randi_range(1, 100) > decide:
		return lines
	var window: int = RelationshipSystem.mutual_value(beau, merc) * 10
	if randi_range(1, 100) <= window:
		var mirror := grant(beau, IN_LOVE)
		if mirror.is_empty():
			return lines
		beau.beau_uid = merc.merc_uid
		lines.append_array(mirror)
		lines.append("IN LOVE: %s returns it to %s" % [beau.merc_name, merc.merc_name])
		return lines
	merc.beau_uid = 0
	lines.append("IN LOVE: %s turns %s down" % [beau.merc_name, merc.merc_name])
	lines.append_array(force(merc, FOREVER_YEARNING))
	return lines


static func _in_team(run: ContractRun, uid: int) -> MercenaryData:
	for merc: MercenaryData in run.team:
		if merc != null and merc.merc_uid == uid:
			return merc
	return null


#The merc a bond points at, resolved against the current contract team.
static func partner(merc: MercenaryData, uid: int) -> MercenaryData:
	if merc == null or uid <= 0:
		return null
	for other: MercenaryData in _team:
		if other != null and other.merc_uid == uid:
			return other
	return null
