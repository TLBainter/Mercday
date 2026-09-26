class_name ExcessPool

#Excess HP, EP and MP: three capped pools every creature carries, always spent before the
#real pool the way BattleState.spend_ap already spends excess AP. Cleared on contract return.

const CAP := 3
const FIELDS: Dictionary = {"hp": "excess_hp", "ep": "excess_ep", "mp": "excess_mp"}


#Adds to one pool clamped to 0..CAP and returns the delta actually applied.
static func add(merc: MercenaryData, kind: String, value: int) -> int:
	if merc == null:
		return 0
	var field: String = String(FIELDS.get(kind, ""))
	if field == "":
		return 0
	var before: int = int(merc.get(field))
	var after: int = clampi(before + value, 0, CAP)
	merc.set(field, after)
	return after - before


static func amount(merc: MercenaryData, kind: String) -> int:
	if merc == null:
		return 0
	var field: String = String(FIELDS.get(kind, ""))
	if field == "":
		return 0
	return int(merc.get(field))


#Drains excess HP first, then current HP down to hp_floor (1 for a will_hp_floor damage type).
static func take_hp(merc: MercenaryData, damage: int, hp_floor: int = 0) -> Dictionary:
	if merc == null:
		return {"from_excess": 0, "from_hp": 0, "total": 0}
	var total: int = maxi(0, damage)
	var from_excess: int = mini(maxi(0, merc.excess_hp), total)
	merc.excess_hp -= from_excess
	var from_hp: int = mini(total - from_excess, maxi(0, merc.current_hp - hp_floor))
	merc.current_hp = mini(merc.current_hp, maxi(hp_floor, merc.current_hp - from_hp))
	return {"from_excess": from_excess, "from_hp": from_hp, "total": from_excess + from_hp}


#Largest damage a will_hp_floor type may deal before the merc would drop below 1 HP.
static func hp_cap_for_floor(merc: MercenaryData) -> int:
	if merc == null:
		return 0
	return maxi(0, merc.excess_hp + merc.current_hp - 1)


static func refund_hp(merc: MercenaryData, from_excess: int, from_hp: int) -> void:
	if merc == null:
		return
	merc.excess_hp = clampi(merc.excess_hp + maxi(0, from_excess), 0, CAP)
	merc.current_hp = maxi(0, merc.current_hp + maxi(0, from_hp))


static func hp_total(merc: MercenaryData) -> int:
	if merc == null:
		return 0
	return merc.current_hp + maxi(0, merc.excess_hp)


static func available_ep(merc: MercenaryData) -> int:
	if merc == null:
		return 0
	return merc.current_ep + merc.excess_ep


#Spends excess EP before current EP; the returned split is what a refund gives back.
static func pay_ep(merc: MercenaryData, cost: int) -> Dictionary:
	if merc == null:
		return {"from_excess": 0, "from_ep": 0}
	var total: int = maxi(0, cost)
	var from_excess: int = mini(maxi(0, merc.excess_ep), total)
	merc.excess_ep -= from_excess
	var from_ep: int = total - from_excess
	merc.current_ep -= from_ep
	return {"from_excess": from_excess, "from_ep": from_ep}


static func refund_ep(merc: MercenaryData, from_excess: int, from_ep: int) -> void:
	if merc == null:
		return
	merc.excess_ep = clampi(merc.excess_ep + maxi(0, from_excess), 0, CAP)
	merc.current_ep += maxi(0, from_ep)


static func clear(merc: MercenaryData, reason: String) -> Array[String]:
	var lines: Array[String] = []
	if merc == null:
		return lines
	var parts: Array[String] = []
	if merc.excess_hp > 0:
		parts.append("%d ExHP" % merc.excess_hp)
	if merc.excess_ep > 0:
		parts.append("%d ExEP" % merc.excess_ep)
	if merc.excess_mp > 0:
		parts.append("%d ExMP" % merc.excess_mp)
	merc.excess_hp = 0
	merc.excess_ep = 0
	merc.excess_mp = 0
	if parts.is_empty():
		return lines
	lines.append("EXCESS LOST: %s %s (%s)" % [merc.merc_name, ", ".join(parts), reason])
	return lines


static func header(merc: MercenaryData) -> String:
	if merc == null:
		return ""
	var out: String = ""
	if merc.excess_hp > 0:
		out += "  ExHP:%d" % merc.excess_hp
	if merc.excess_ep > 0:
		out += "  ExEP:%d" % merc.excess_ep
	if merc.excess_mp > 0:
		out += "  ExMP:%d" % merc.excess_mp
	return out


#An MP feature is one whose effect text prices MP the way EP is priced: spend:mp:<purpose>
#or an action token carrying an "mp" cost part. Nothing spells either yet, so this is false.
static func uses_mp(merc: MercenaryData) -> bool:
	if merc == null:
		return false
	for effect: String in merc.passive_effects:
		if _prices_mp(effect):
			return true
	var lists: Array = [merc.perks, merc.drawbacks, merc.descriptors, merc.weapon_perks, merc.armor_perks]
	for list: Array in lists:
		for entry in list:
			var td: TraitData = entry as TraitData
			if td != null and _prices_mp(td.effect_dsl):
				return true
	return false


static func _prices_mp(dsl: String) -> bool:
	if dsl == "":
		return false
	if dsl.contains("spend:mp:"):
		return true
	if not (dsl.begins_with("action:") or dsl.begins_with("reactive_action:")):
		return false
	var parts := dsl.split(":")
	for i in range(1, parts.size() - 1):
		if parts[i] == "mp" and parts[i + 1].is_valid_int():
			return true
	return false


#Zen picks the pool it can actually use: EP for a merc with no MP feature, else the deeper deficit.
static func choose_ep_or_mp(merc: MercenaryData) -> String:
	if merc == null or not uses_mp(merc):
		return "ep"
	var ep_deficit := _deficit(merc.current_ep, int(merc.stats.get("maximum_endurance_points", 0)))
	var mp_deficit := _deficit(merc.current_mp, int(merc.stats.get("maximum_magic_points", 0)))
	return "mp" if mp_deficit > ep_deficit else "ep"


static func _deficit(current: int, maximum: int) -> float:
	if maximum <= 0:
		return 0.0
	return clampf(1.0 - (float(current) / float(maximum)), 0.0, 1.0)
