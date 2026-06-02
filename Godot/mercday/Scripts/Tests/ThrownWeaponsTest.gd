# TEMP TEST  -  thrown accuracy and thrown range system verification
# To delete: remove this file, the ThrownTest button node from testingArea.tscn,
#            and the _on_thrown_test() handler + its _ready() line from MercTest.gd

class_name ThrownWeaponsTest

const THROWN_ACCURACY_BONUS := 10
const THROWN_RANGE_BONUS    := 20
const THROWABLE_WEAPONS_PER_MERC := 5


static func create_state() -> BattleState:
	var team_a: Array[MercenaryData] = []
	var team_b: Array[MercenaryData] = []
	for i: int in range(2):
		team_a.append(MercGenerator.generate(i))
	for i: int in range(2):
		team_b.append(MercGenerator.generate(i + 2))
	var all_mercs: Array[MercenaryData] = []
	all_mercs.append_array(team_a)
	all_mercs.append_array(team_b)
	var throwables := _get_throwable_weapons()
	for merc: MercenaryData in all_mercs:
		_strip_weapons(merc)
		_apply_bonuses(merc)
		_give_throwable_weapons(merc, throwables)
	var field := _make_field()
	return BattleState.create(team_a, team_b, field)


static func _strip_weapons(merc: MercenaryData) -> void:
	merc.equipped_weapon = null
	merc.weapon_drawn = false
	merc.ammo_loaded = 0
	merc.ammo_loaded_type = ""
	merc.ammo_inventory.clear()
	var keep: Array[Dictionary] = []
	for entry: Dictionary in merc.inventory:
		if entry.get("type") != "weapon":
			keep.append(entry)
	merc.inventory.clear()
	merc.inventory.append_array(keep)


static func _apply_bonuses(merc: MercenaryData) -> void:
	merc.stat_bonuses["thrown_accuracy"] = int(merc.stat_bonuses.get("thrown_accuracy", 0)) + THROWN_ACCURACY_BONUS
	merc.stat_bonuses["thrown_range"] = int(merc.stat_bonuses.get("thrown_range", 0)) + THROWN_RANGE_BONUS
	merc.stats = StatCalculator.calculate_all(merc)


static func _give_throwable_weapons(merc: MercenaryData, throwables: Array[WeaponData]) -> void:
	if throwables.is_empty():
		print("[THROWN TEST] No throwable weapons found in DataManager.weapons")
		return
	var pool := throwables.duplicate()
	pool.shuffle()
	var count := mini(THROWABLE_WEAPONS_PER_MERC, pool.size())
	for i: int in range(count):
		var w: WeaponData = pool[i]
		merc.inventory.append({"type": "weapon", "data": w})


static func _get_throwable_weapons() -> Array[WeaponData]:
	var result: Array[WeaponData] = []
	for w: WeaponData in DataManager.weapons.values():
		if w.is_throwable and not w.is_virtual:
			result.append(w)
	return result


static func _make_field() -> BattlefieldArea:
	var f := BattlefieldArea.new()
	f.width = 15
	f.length = 15
	f.height = 20
	f.cover_amount = 1
	f.unevenness = 0
	f._generate_cover()
	return f
