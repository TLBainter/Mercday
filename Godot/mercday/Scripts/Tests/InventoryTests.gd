class_name InventoryTests

#Encumbrance and loadout decisions. Run: godot --headless --path . -- --inventory-tests
#Every case builds its own merc, so the suite is order independent.


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_carried_weight(res)
	_case_ammo_weight(res)
	_case_penalties(res)
	_case_propagation(res)
	_case_refresh_follows_weight(res)
	_case_settle(res)
	_case_pickup_burden(res)
	_case_text(res)
	_case_generated_under_limit(res)
	_case_tiny_limit_pools(res)
	_case_drop_order(res)
	_case_pool_draws(res)
	_case_tiny_limit_leaves_no_reserve(res)
	_clear_test_ammo()
	return TestFixtures.summarize(res, "INVENTORY")


#Helpers

#Ammo names registered in DataManager for the suite; erased again when the run ends.
static var _test_ammo: Array[String] = []


#A merc whose stats come from the real Stats.tsv formulas: weight limit 6, pace 6, dodge 49.
static func _merc(name: String) -> MercenaryData:
	var m := MercenaryData.new()
	m.merc_name = name
	m.max_stats = {"max_vigor": 8, "max_dexterity": 8, "max_cognition": 8, "max_wile": 8, "size": 1}
	m.luck_roll = 5.0
	m.stats = {"level": 5}
	m.stats = StatCalculator.calculate_all(m)
	m.stats_baseline = StatCalculator.calculate_all(m)
	return m


static func _weapon(name: String, weight: int, formula: String, wtype: String = "Sword") -> WeaponData:
	var w := WeaponData.new()
	w.item_name = name
	w.weapon_type = wtype
	w.weight = weight
	w.damage_formula_1 = formula
	return w


static func _armor(name: String, weight: int) -> ArmorData:
	var a := ArmorData.new()
	a.item_name = name
	a.weight = weight
	return a


static func _ammo(name: String, weight: int, amount: int, compatible: Array) -> AmmoData:
	var a := AmmoData.new()
	a.item_name = name
	a.weight = weight
	a.amount = amount
	a.compatible.assign(compatible)
	DataManager.ammo[name] = a
	if not _test_ammo.has(name):
		_test_ammo.append(name)
	return a


static func _clear_test_ammo() -> void:
	for name: String in _test_ammo:
		DataManager.ammo.erase(name)
	_test_ammo.clear()


static func _pack(merc: MercenaryData, w: WeaponData) -> void:
	merc.inventory.append({"type": "weapon", "data": w})


#Drops every weight 0 ranged weapon and armor, so no gear roll can fit under a limit of 1.
static func _install_heavy_pools() -> Dictionary:
	var saved: Dictionary = {
		"ordinary_ranged": DataManager.weapons_ordinary_ranged,
		"common_ranged": DataManager.weapons_common_ranged,
		"armor": DataManager.armor_ordinary_common,
	}
	var ordinary: Array[WeaponData] = []
	for w: WeaponData in saved["ordinary_ranged"]:
		if w.weight > 0:
			ordinary.append(w)
	var common: Array[WeaponData] = []
	for w: WeaponData in saved["common_ranged"]:
		if w.weight > 0:
			common.append(w)
	var armor: Array = []
	for a: ArmorData in saved["armor"]:
		if a.weight > 0:
			armor.append(a)
	DataManager.weapons_ordinary_ranged = ordinary
	DataManager.weapons_common_ranged = common
	DataManager.armor_ordinary_common = armor
	return saved


static func _restore_pools(saved: Dictionary) -> void:
	var ordinary: Array[WeaponData] = []
	ordinary.assign(saved.get("ordinary_ranged", []))
	DataManager.weapons_ordinary_ranged = ordinary
	var common: Array[WeaponData] = []
	common.assign(saved.get("common_ranged", []))
	DataManager.weapons_common_ranged = common
	DataManager.armor_ordinary_common = saved.get("armor", [])


#Holds the generator level and tradition overrides aside and clears them; the saved pair comes back.
static func _push_overrides() -> Array:
	var saved: Array = [MercGenerator.forced_level, MercGenerator.forced_tradition]
	MercGenerator.forced_level = -1
	MercGenerator.forced_tradition = ""
	return saved


#Puts the held level and tradition overrides back.
static func _pop_overrides(saved: Array) -> void:
	MercGenerator.forced_level = int(saved[0])
	MercGenerator.forced_tradition = String(saved[1])


#A merc straight out of the generator, taken without the harness level and tradition overrides.
static func _generated(index: int) -> MercenaryData:
	var saved: Array = _push_overrides()
	var m: MercenaryData = MercGenerator.generate(index)
	_pop_overrides(saved)
	return m


static func _tiny_limit_merc(index: int, limit: float = 1.0) -> MercenaryData:
	var m: MercenaryData = _generated(index)
	m.stats["weight_limit"] = limit
	if m.stats_baseline.has("weight_limit"):
		m.stats_baseline["weight_limit"] = limit
	return m


static func _packed_weapons(merc: MercenaryData) -> int:
	var count: int = 0
	for entry: Dictionary in merc.inventory:
		if entry.get("type") == "weapon":
			count += 1
	return count


static func _has_ranged(merc: MercenaryData) -> bool:
	var held: Array[WeaponData] = [merc.equipped_weapon, merc.offhand_weapon]
	for entry: Dictionary in merc.inventory:
		if entry.get("type") == "weapon":
			held.append(entry.get("data") as WeaponData)
	for w: WeaponData in held:
		if w != null and w.is_ranged:
			return true
	return false


#Cases

static func _case_carried_weight(res: Dictionary) -> void:
	var m := _merc("Bram")
	TestFixtures.check(res, "an empty loadout weighs nothing", Encumbrance.carried_weight(m) == 0,
		"expected 0, got %d" % Encumbrance.carried_weight(m))
	m.equipped_weapon = _weapon("Blade", 3, "1d6")
	m.offhand_weapon = _weapon("Dirk", 2, "1d4")
	_pack(m, _weapon("Maul", 4, "1d8"))
	m.equipped_armor = _armor("Jack", 5)
	TestFixtures.check(res, "carried weight sums both hands the pack and the armor",
		Encumbrance.carried_weight(m) == 14,
		"expected 3 + 2 + 4 + 5 = 14, got %d" % Encumbrance.carried_weight(m))
	var fight := _weapon("Fight", 7, "1d2")
	fight.is_virtual = true
	_pack(m, fight)
	TestFixtures.check(res, "the virtual Fight weapon weighs nothing",
		Encumbrance.carried_weight(m) == 14,
		"expected 14 with a weight 7 virtual weapon packed, got %d" % Encumbrance.carried_weight(m))
	m.offhand_weapon = null
	TestFixtures.check(res, "an empty hand weighs nothing",
		Encumbrance.carried_weight(m) == 12,
		"expected 12 without the weight 2 offhand, got %d" % Encumbrance.carried_weight(m))


static func _case_ammo_weight(res: Dictionary) -> void:
	var m := _merc("Cass")
	_ammo("Test Rounds", 1, 10, ["Pistol"])
	_ammo("Test Feathers", 0, 10, ["Bow"])
	m.ammo_inventory["Test Rounds"] = 15
	TestFixtures.check(res, "fifteen rounds of a ten round bundle weigh two",
		Encumbrance.ammo_weight(m) == 2, "expected 2, got %d" % Encumbrance.ammo_weight(m))
	m.ammo_loaded_type = "Test Rounds"
	m.ammo_loaded = 6
	TestFixtures.check(res, "loaded rounds count toward the bundles",
		Encumbrance.ammo_weight(m) == 3,
		"expected 3 bundles for 15 reserve and 6 loaded, got %d" % Encumbrance.ammo_weight(m))
	m.ammo_inventory["Test Feathers"] = 30
	TestFixtures.check(res, "weightless ammo adds nothing",
		Encumbrance.ammo_weight(m) == 3,
		"expected 3 after 30 weight 0 rounds, got %d" % Encumbrance.ammo_weight(m))
	m.ammo_inventory["Ghost Rounds"] = 50
	TestFixtures.check(res, "an unknown ammo name is skipped",
		Encumbrance.ammo_weight(m) == 3,
		"expected 3 with an unregistered ammo name, got %d" % Encumbrance.ammo_weight(m))
	TestFixtures.check(res, "carried weight includes the ammo",
		Encumbrance.carried_weight(m) == 3,
		"expected 3 with no weapon or armor, got %d" % Encumbrance.carried_weight(m))


static func _case_penalties(res: Dictionary) -> void:
	var under: Dictionary = Encumbrance.penalties_for(3, 6)
	TestFixtures.check(res, "below the limit costs nothing",
		int(under["pace"]) == 0 and int(under["dodge"]) == 0 and int(under["action_points"]) == 0,
		"got pace %d, dodge %d, AP %d" % [int(under["pace"]), int(under["dodge"]), int(under["action_points"])])
	var at: Dictionary = Encumbrance.penalties_for(6, 6)
	TestFixtures.check(res, "exactly at the limit costs one pace only",
		int(at["pace"]) == 1 and int(at["dodge"]) == 0 and int(at["action_points"]) == 0,
		"got pace %d, dodge %d, AP %d" % [int(at["pace"]), int(at["dodge"]), int(at["action_points"])])
	var over: Dictionary = Encumbrance.penalties_for(8, 6)
	TestFixtures.check(res, "over by two costs three pace two dodge and two action points",
		int(over["pace"]) == 3 and int(over["dodge"]) == 2 and int(over["action_points"]) == 2,
		"got pace %d, dodge %d, AP %d" % [int(over["pace"]), int(over["dodge"]), int(over["action_points"])])


static func _case_propagation(res: Dictionary) -> void:
	var m := _merc("Dara")
	var limit: int = Encumbrance.weight_limit(m)
	var unladen: Dictionary = StatCalculator.calculate_all(m)
	m.equipped_armor = _armor("Load", limit)
	var at: Dictionary = StatCalculator.calculate_all(m)
	TestFixtures.check(res, "at the limit the merc loses exactly one pace",
		int(at["pace"]) == int(unladen["pace"]) - 1 and int(at["dodge"]) == int(unladen["dodge"])
		and int(at["action_points"]) == int(unladen["action_points"]),
		"pace %d to %d, dodge %d to %d, AP %d to %d" % [int(unladen["pace"]), int(at["pace"]),
		int(unladen["dodge"]), int(at["dodge"]), int(unladen["action_points"]), int(at["action_points"])])
	m.equipped_armor = _armor("Load", limit + 2)
	var over: Dictionary = StatCalculator.calculate_all(m)
	TestFixtures.check(res, "over by two costs three pace two dodge and two action points",
		int(over["pace"]) == int(unladen["pace"]) - 3 and int(over["dodge"]) == int(unladen["dodge"]) - 2
		and int(over["action_points"]) == int(unladen["action_points"]) - 2,
		"pace %d to %d, dodge %d to %d, AP %d to %d" % [int(unladen["pace"]), int(over["pace"]),
		int(unladen["dodge"]), int(over["dodge"]), int(unladen["action_points"]), int(over["action_points"])])
	TestFixtures.check(res, "the dodge loss carries into avoid",
		is_equal_approx(float(over["avoid"]), float(unladen["avoid"]) - 1.0),
		"expected %.2f, got %.2f" % [float(unladen["avoid"]) - 1.0, float(over["avoid"])])
	TestFixtures.check(res, "the avoid loss leaves healthiness and rest recovery unchanged",
		is_equal_approx(float(over["healthiness"]), float(unladen["healthiness"]))
		and is_equal_approx(float(over["rest_recovery"]), float(unladen["rest_recovery"])),
		"healthiness %.2f to %.2f, rest recovery %.3f to %.3f" % [float(unladen["healthiness"]),
		float(over["healthiness"]), float(unladen["rest_recovery"]), float(over["rest_recovery"])])
	m.equipped_armor = _armor("Load", limit + 100)
	var crushed: Dictionary = StatCalculator.calculate_all(m)
	TestFixtures.check(res, "pace and action points never go below zero",
		int(crushed["pace"]) == 0 and int(crushed["action_points"]) == 0,
		"got pace %d and AP %d at 100 over the limit" % [int(crushed["pace"]), int(crushed["action_points"])])


static func _case_refresh_follows_weight(res: Dictionary) -> void:
	var m := _merc("Elin")
	var unladen_pace: int = int(m.stats.get("pace", 0))
	var limit: int = Encumbrance.weight_limit(m)
	_pack(m, _weapon("Anvil", limit + 2, "1d4"))
	StatCalculator.refresh(m)
	TestFixtures.check(res, "a packed weapon over the limit cuts pace on refresh",
		int(m.stats.get("pace", 0)) == unladen_pace - 3,
		"expected %d, got %d" % [unladen_pace - 3, int(m.stats.get("pace", 0))])
	m.inventory.clear()
	StatCalculator.refresh(m)
	TestFixtures.check(res, "dropping the weight restores pace on refresh",
		int(m.stats.get("pace", 0)) == unladen_pace,
		"expected %d, got %d" % [unladen_pace, int(m.stats.get("pace", 0))])


static func _case_settle(res: Dictionary) -> void:
	var m := _merc("Fen")
	m.equipped_weapon = _weapon("Sabre", 2, "2d6")
	m.equipped_armor = _armor("Brigandine", 2)
	_pack(m, _weapon("Bent Rail", 3, "1d2"))
	_ammo("Test Rounds", 1, 10, ["Pistol"])
	m.ammo_inventory["Test Rounds"] = 10
	TestFixtures.check(res, "the loaded merc starts two over its limit",
		Encumbrance.carried_weight(m) == 8 and Encumbrance.weight_limit(m) == 6,
		"carried %d against a limit of %d" % [Encumbrance.carried_weight(m), Encumbrance.weight_limit(m)])
	var lines: Array[String] = LoadoutDecision.settle(m)
	TestFixtures.check(res, "settle drops the heavy packed weapon first",
		lines.size() == 2 and lines[0].begins_with("LOADOUT DROP: Fen drops Bent Rail")
		and lines[0].ends_with("-> 5/6"), "got %s" % " | ".join(lines))
	TestFixtures.check(res, "settle never drops the armor",
		m.equipped_armor != null and not TestFixtures.has_line(lines, "Brigandine"),
		"armor %s" % ("kept" if m.equipped_armor != null else "gone"))
	TestFixtures.check(res, "settle keeps the weapon in hand",
		m.equipped_weapon != null and m.equipped_weapon.item_name == "Sabre",
		"holding %s" % ("nothing" if m.equipped_weapon == null else m.equipped_weapon.item_name))
	var solo := _merc("Gale")
	solo.equipped_weapon = _weapon("Great Maul", 8, "2d8")
	var solo_lines: Array[String] = LoadoutDecision.settle(solo)
	TestFixtures.check(res, "a merc keeps its only weapon and stays over",
		solo.equipped_weapon != null and solo_lines.size() == 1 and solo_lines[0].contains("over by 2"),
		"got %s" % " | ".join(solo_lines))
	var gunner := _merc("Hale")
	gunner.equipped_weapon = _weapon("Hand Cannon", 1, "1d6", "Pistol")
	gunner.equipped_armor = _armor("Plate", 5)
	_ammo("Test Rounds", 1, 10, ["Pistol"])
	_ammo("Test Slugs", 1, 10, ["Cannon"])
	gunner.ammo_inventory["Test Rounds"] = 10
	gunner.ammo_inventory["Test Slugs"] = 10
	var gun_lines: Array[String] = LoadoutDecision.settle(gunner)
	TestFixtures.check(res, "ammo no carried weapon can fire goes first",
		gun_lines.size() >= 2 and gun_lines[0].contains("drops Test Slugs")
		and gun_lines[1].contains("drops Test Rounds"), "got %s" % " | ".join(gun_lines))
	var light := _merc("Isen")
	light.equipped_weapon = _weapon("Knife", 1, "1d4")
	TestFixtures.check(res, "settle says nothing under the limit",
		LoadoutDecision.settle(light).is_empty(),
		"carried %d against a limit of %d" % [Encumbrance.carried_weight(light), Encumbrance.weight_limit(light)])
	TestFixtures.check(res, "the rules line prints the burden constants",
		Encumbrance.loadout_rules_line().contains("at limit 1.0"), Encumbrance.loadout_rules_line())


static func _case_pickup_burden(res: Dictionary) -> void:
	var m := _merc("Jory")
	m.equipped_armor = _armor("Coat", 2)
	var unladen: float = LoadoutDecision.pickup_burden(m, _weapon("Rod", 2, "1d4"))
	var at: float = LoadoutDecision.pickup_burden(m, _weapon("Bar", 4, "1d4"))
	var one: float = LoadoutDecision.pickup_burden(m, _weapon("Beam", 5, "1d4"))
	var two: float = LoadoutDecision.pickup_burden(m, _weapon("Block", 6, "1d4"))
	TestFixtures.check(res, "a pickup that stays under the limit costs nothing",
		is_zero_approx(unladen), "expected 0.0, got %.2f" % unladen)
	TestFixtures.check(res, "a pickup that lands on the limit costs the at limit burden",
		is_equal_approx(at, LoadoutDecision.AT_LIMIT_BURDEN),
		"expected %.2f, got %.2f" % [LoadoutDecision.AT_LIMIT_BURDEN, at])
	TestFixtures.check(res, "each point over the limit adds the per point burden",
		is_equal_approx(one - at, LoadoutDecision.PER_POINT_BURDEN)
		and is_equal_approx(two - one, LoadoutDecision.PER_POINT_BURDEN),
		"burdens %.2f, %.2f, %.2f" % [at, one, two])
	var packed := _merc("Kell")
	packed.equipped_armor = _armor("Coat", 1)
	packed.equipped_weapon = _weapon("Sabre", 2, "2d6")
	_pack(packed, _weapon("Bent Rail", 3, "1d2"))
	var shed: Dictionary = LoadoutDecision.shed_for(packed, _weapon("Halberd", 2, "1d10"))
	TestFixtures.check(res, "shed_for offers the packed weapon",
		not shed.is_empty() and str(shed.get("name", "")) == "Bent Rail",
		"got %s" % str(shed.get("name", "nothing")))
	TestFixtures.check(res, "shed_for never offers a weapon in hand",
		str(shed.get("slot", "")) == "inventory", "slot %s" % str(shed.get("slot", "none")))
	var bare := _merc("Lune")
	bare.equipped_weapon = _weapon("Knife", 1, "1d4")
	TestFixtures.check(res, "shed_for is empty when nothing packed is worth dropping",
		LoadoutDecision.shed_for(bare, _weapon("Twig", 1, "1d2")).is_empty(),
		"carried %d against a limit of %d" % [Encumbrance.carried_weight(bare), Encumbrance.weight_limit(bare)])


static func _case_text(res: Dictionary) -> void:
	var m := _merc("Mira")
	m.equipped_armor = _armor("Coat", 3)
	TestFixtures.check(res, "the loadout line reads under the limit",
		Encumbrance.line(m) == "LOADOUT: Mira 3/6 under", Encumbrance.line(m))
	TestFixtures.check(res, "the gear note reads under the limit",
		Encumbrance.short_text(m) == "wt 3/6", Encumbrance.short_text(m))
	m.equipped_armor = _armor("Coat", 6)
	TestFixtures.check(res, "the loadout line reads at the limit",
		Encumbrance.line(m) == "LOADOUT: Mira 6/6 at limit (pace -1)", Encumbrance.line(m))
	TestFixtures.check(res, "the gear note reads at the limit",
		Encumbrance.short_text(m) == "wt 6/6 (at limit)", Encumbrance.short_text(m))
	m.equipped_armor = _armor("Coat", 8)
	TestFixtures.check(res, "the loadout line reads over the limit",
		Encumbrance.line(m) == "LOADOUT: Mira 8/6 over by 2 (pace -3, dodge -2, AP -2)", Encumbrance.line(m))
	TestFixtures.check(res, "the gear note reads over the limit",
		Encumbrance.short_text(m) == "wt 8/6 (over by 2)", Encumbrance.short_text(m))


static func _case_generated_under_limit(res: Dictionary) -> void:
	var saved: Array = _push_overrides()
	seed(4242)
	TestFixtures.reset_generator_rolls()
	var over: Array[String] = []
	var geared: Array[String] = []
	for i: int in range(30):
		var m: MercenaryData = MercGenerator.generate(i)
		var limit: int = Encumbrance.weight_limit(m)
		var carried: int = Encumbrance.carried_weight(m)
		if carried >= maxi(limit, 1):
			over.append("%s %d/%d" % [m.merc_name, carried, limit])
		if limit < 1 and (m.equipped_armor != null or _has_ranged(m)):
			geared.append("%s %d/%d" % [m.merc_name, carried, limit])
	randomize()
	_pop_overrides(saved)
	TestFixtures.check(res, "every generated merc carries less than its weight limit, or nothing at a limit of 0",
		over.is_empty(), "over the limit: %s" % " | ".join(over))
	TestFixtures.check(res, "a merc with a weight limit of 0 gets no armor and no ranged weapon",
		geared.is_empty(), "geared at limit 0: %s" % " | ".join(geared))


static func _case_tiny_limit_pools(res: Dictionary) -> void:
	var m: MercenaryData = _tiny_limit_merc(0)
	var pools: Dictionary = _install_heavy_pools()
	var heavy_ranged: int = DataManager.weapons_ordinary_ranged.size() + DataManager.weapons_common_ranged.size()
	var none: Array[String] = []
	StartingGear.clear_gear(m, none)
	var before: Array[String] = m.passive_effects.duplicate()
	var drawn: Array[String] = StartingGear.step_gear(m)
	_restore_pools(pools)
	TestFixtures.check(res, "the test pools keep a ranged weapon no tiny limit can fit",
		heavy_ranged > 0, "%d ranged weapons left in the pools" % heavy_ranged)
	TestFixtures.check(res, "a limit of one draws the melee category only",
		drawn.size() == 1 and drawn[0] == "melee", "drew %s" % " | ".join(drawn))
	TestFixtures.check(res, "the melee only draw leaves the merc carrying nothing",
		Encumbrance.carried_weight(m) == 0, "carried %d" % Encumbrance.carried_weight(m))
	TestFixtures.check(res, "the melee only draw equips no armor", m.equipped_armor == null,
		"wearing %s" % ("nothing" if m.equipped_armor == null else m.equipped_armor.item_name))
	TestFixtures.check(res, "the melee only draw equips no ranged weapon", not _has_ranged(m),
		"holding %s" % ("nothing" if m.equipped_weapon == null else m.equipped_weapon.item_name))
	TestFixtures.check(res, "the melee only draw leaves no armor effect behind",
		m.passive_effects == before, "effects %s" % " | ".join(m.passive_effects))


static func _case_drop_order(res: Dictionary) -> void:
	var m: MercenaryData = _tiny_limit_merc(2, 2.0)
	var pools: Dictionary = _install_heavy_pools()
	var none: Array[String] = []
	StartingGear.clear_gear(m, none)
	var drawn: Array[String] = StartingGear.step_gear(m)
	_restore_pools(pools)
	TestFixtures.check(res, "the ranged weapon is dropped before the armor",
		drawn.size() == 2 and drawn.has("armor") and drawn.has("melee"), "drew %s" % " | ".join(drawn))
	TestFixtures.check(res, "the kept armor is worn", m.equipped_armor != null,
		"wearing %s" % ("nothing" if m.equipped_armor == null else m.equipped_armor.item_name))
	TestFixtures.check(res, "no ranged weapon survives the drop", not _has_ranged(m),
		"holding %s" % ("nothing" if m.equipped_weapon == null else m.equipped_weapon.item_name))
	TestFixtures.check(res, "the kept loadout stays below a limit of two",
		Encumbrance.carried_weight(m) <= 1, "carried %d" % Encumbrance.carried_weight(m))


static func _case_pool_draws(res: Dictionary) -> void:
	var saved: Array = _push_overrides()
	seed(4242)
	TestFixtures.reset_generator_rolls()
	var heavy: Array[String] = []
	var with_armor: int = 0
	var with_ranged: int = 0
	var with_all: int = 0
	for i: int in range(40):
		var m: MercenaryData = MercGenerator.generate(i)
		var none: Array[String] = []
		StartingGear.clear_gear(m, none)
		m.stats["weight_limit"] = 4.0
		if m.stats_baseline.has("weight_limit"):
			m.stats_baseline["weight_limit"] = 4.0
		var drawn: Array[String] = StartingGear.step_gear(m)
		var carried: int = Encumbrance.carried_weight(m)
		if carried > 3:
			heavy.append("%s %d" % [m.merc_name, carried])
		if m.equipped_armor != null:
			with_armor += 1
		if _has_ranged(m) and m.ammo_loaded > 0:
			with_ranged += 1
		if drawn.size() == 3:
			with_all += 1
	randomize()
	_pop_overrides(saved)
	TestFixtures.check(res, "a weight limit of four keeps every drawn loadout at three or less",
		heavy.is_empty(), "over the budget: %s" % " | ".join(heavy))
	TestFixtures.check(res, "the fitted draw still reaches the armor pool", with_armor > 0,
		"%d of 40 wear armor" % with_armor)
	TestFixtures.check(res, "the fitted draw still reaches the ranged pool with ammo", with_ranged > 0,
		"%d of 40 carry a loaded ranged weapon" % with_ranged)
	TestFixtures.check(res, "a fitted loadout can hold all three categories", with_all > 0,
		"%d of 40 drew all three" % with_all)


static func _case_tiny_limit_leaves_no_reserve(res: Dictionary) -> void:
	var m: MercenaryData = _tiny_limit_merc(1)
	var pools: Dictionary = _install_heavy_pools()
	var none: Array[String] = []
	StartingGear.clear_gear(m, none)
	StartingGear.step_gear(m)
	_restore_pools(pools)
	TestFixtures.check(res, "a tiny limit leaves no weapon in the pack",
		_packed_weapons(m) == 0, "%d packed weapons" % _packed_weapons(m))
	TestFixtures.check(res, "no ammo in reserve",
		m.ammo_inventory.is_empty(), "reserve %s" % str(m.ammo_inventory))
	TestFixtures.check(res, "no ammo loaded",
		m.ammo_loaded == 0, "%d rounds of %s loaded" % [m.ammo_loaded, m.ammo_loaded_type])
