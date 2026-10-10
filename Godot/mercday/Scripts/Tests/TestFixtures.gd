class_name TestFixtures

#Shared helpers for the deterministic test suites. Printed text must stay byte identical.


const DECK_SIZE := 100
#Difficulty then copies per 100 cards, in the order the designer set them.
const DECK_CARDS: Array = [[3.0, 50], [2.5, 7], [3.5, 6], [2.0, 6], [4.0, 6],
	[1.5, 10], [4.5, 10], [1.0, 3], [5.0, 2]]
#The seed every Hiring suite pins the applicant draws to, so a reset lays down the same levels.
const APPLICANT_SEED := 7
#The label on the ledger row fund_budget credits.
const INCOME_LABEL := "Fixture Income"


#Counts one case into res and prints its PASS or FAIL line.
static func check(res: Dictionary, label: String, passed: bool, why: String) -> void:
	if passed:
		res["pass"] = int(res["pass"]) + 1
		print("PASS %s | %s" % [label, why])
	else:
		res["fail"] = int(res["fail"]) + 1
		print("FAIL %s | %s" % [label, why])


#Prints the suite summary line and reports whether every case passed; a suite that ran no check fails.
static func summarize(res: Dictionary, suite: String) -> bool:
	var total: int = int(res["pass"]) + int(res["fail"])
	if total == 0:
		print("%s TESTS SUMMARY: 0/0 passed, 0 failed (no checks: FAIL)" % suite)
		return false
	print("%s TESTS SUMMARY: %d/%d passed, %d failed" % [suite, int(res["pass"]), total, int(res["fail"])])
	return int(res["fail"]) == 0


#The failure detail string of a report case: the count and the first cap offenders.
static func detail(bad: Array[String], total: int, unit: String, cap: int = 5) -> String:
	if bad.is_empty():
		return "0 of %d %s" % [total, unit]
	var head: Array[String] = []
	for i: int in range(mini(cap, bad.size())):
		head.append(bad[i])
	return "%d of %d %s: %s" % [bad.size(), total, unit, "; ".join(head)]


#Waits count process frames of the tree host is in.
static func frames(host: Node, count: int = 2) -> void:
	for _i: int in count:
		await host.get_tree().process_frame


#Empties the campaign state the sheet suites fill, so each case starts from nothing.
static func reset_campaign() -> void:
	CampaignKnowledge.clear()
	RelationshipSystem.clear_tallies()
	LifepathTally.clear()
	LifepathProgression.clear()
	CheckSystem.forced_rolls.clear()


#Opens a loan on FinanceManager's books the way an accepted offer does, without the payout or the
#offer; bill_day -1 takes the day the start date picks. first_due is held to what an offer can carry.
static func add_loan(lender: String, principal: int, rate: float, months: int, bill_day: int = -1,
		first_due: int = LoanLogic.FIRST_DUE_FAIR) -> LoanData:
	var loan: LoanData = FinanceManager._make_loan(FinanceManager._next_loan_id, lender, principal, rate,
		months, clampi(first_due, LoanLogic.FIRST_DUE_MIN, LoanLogic.FIRST_DUE_MAX), CampaignClock.now(), bill_day)
	FinanceManager._next_loan_id += 1
	FinanceManager.loans.append(loan)
	FinanceManager.loans_changed.emit()
	return loan


#Tops the monthly income up to target so a buy clears the income gate; it can only raise the budget.
static func fund_budget(target: int) -> void:
	var short: int = target - SubscriptionManager.budget_available()
	if short > 0:
		FinanceLedger.record(short, GameState.REASON_CONTRACT, INCOME_LABEL)


#Launches a campaign through PromotionsManager.launch, as the builder does; null when it is refused. spec keys:
#type, mode, days, infinite, name, traditions (Array[String]), ctypes, locs, crew, target (sponsor index).
static func launch_campaign(spec: Dictionary) -> CampaignData:
	var c := CampaignData.new()
	c.type_key = StringName(spec.get("type", &"flyers"))
	c.mode = String(spec.get("mode", CampaignData.MODE_JOB))
	c.infinite = bool(spec.get("infinite", false))
	c.days = 0 if c.infinite else int(spec.get("days", 30))
	c.unit_key = CampaignTypeDefs.UNIT_INFINITE if c.infinite else CampaignTypeDefs.UNIT_DAYS
	c.name = String(spec.get("name", ""))
	c.crew.assign(spec.get("crew", []))
	c.contract_types = CampaignData.type_names_of(spec.get("ctypes", []))
	c.locations.assign(spec.get("locs", []))
	var traditions: Array = spec.get("traditions", [])
	if not traditions.is_empty():
		var picked: Array[String] = []
		picked.assign(traditions)
		c.filters[&"tradition"] = picked
	var tiles: Array = spec.get("ctypes", [])
	if not tiles.is_empty():
		c.filters[&"ctype"] = tiles.duplicate()
	if not c.locations.is_empty():
		c.filters[&"loc"] = c.locations.duplicate()
	c.sponsor_index = int(spec.get("target", CampaignData.NO_PICK))
	if c.sponsor_index >= 0:
		var row: Dictionary = TraitFilterDefs.find(TraitFilterDefs.contract_defs(c.type_key), &"target")
		c.sponsor_target = String((row["options"] as Array)[c.sponsor_index])
		c.filters[&"target"] = c.sponsor_target
	return c if PromotionsManager.launch(c) else null


#Moves the clock on count days, emitting GameState.day_changed for each one, so bills and arrivals land.
static func pass_days(count: int) -> void:
	for _i: int in count:
		var next: int = GameState.day() + 1
		CampaignClock.advance_to(next * TrynnCalendar.MINUTES_PER_DAY + 8 * TrynnCalendar.MINUTES_PER_HOUR)
		GameState.day_changed.emit(next)


#Pins the applicant draws; call it before the game reset that lays the applicants down.
static func fix_applicant_seed() -> void:
	PromotionsManager.fixed_seed = APPLICANT_SEED


#Empties the rolling penalties of both generators; long probe and batch runs call it once per trial.
static func reset_generator_rolls() -> void:
	RollingPenalties.clear_all()


#Flat exterior field dim cells square and 24 high.
static func exterior_field(dim: int = 24) -> BattlefieldArea:
	var f := BattlefieldArea.new()
	f.width = dim
	f.length = dim
	f.height = 24
	f.is_interior_map = false
	return f


#Interior shell 24x24x24 with a 10x10 building at the origin and these floor elevations.
static func interior_field(elevations: Dictionary) -> BattlefieldArea:
	var f := BattlefieldArea.new()
	f.width = 24
	f.length = 24
	f.height = 24
	f.is_interior_map = true
	f.building_footprint = Rect2i(0, 0, 10, 10)
	f.interior_floor_elevations = elevations
	return f


#A cavern built by hand: each cell of `ceilings` is open at that clear height, every other cell is rock.
static func cavern_field(w: int, l: int, ceilings: Dictionary) -> BattlefieldArea:
	var f := BattlefieldArea.new()
	f.width = w
	f.length = l
	f.height = 20
	f.is_interior_map = false
	f.is_cavern = true
	f.unevenness = 0
	for y: int in range(l):
		for x: int in range(w):
			var cell := Vector2i(x, y)
			if ceilings.has(cell):
				f.terrain_heights[cell] = 0.0
				f.ground_heights[cell] = 0.0
				f.cavern_ceiling[cell] = float(ceilings[cell])
			else:
				f.rock_cells[cell] = true
	f.bump_path_version()
	return f


#Armor that halves the swim stat, forbids swimming outright, or does neither.
static func swim_armor(halve: bool, cannot: bool) -> ArmorData:
	var a := ArmorData.new()
	a.halve_swim = halve
	a.cannot_swim = cannot
	return a


#A state on a hand-built field; the field is set after create, so no spawn placement runs.
static func field_state(field: BattlefieldArea, mercs: Array[MercenaryData]) -> BattleState:
	var team_b: Array[MercenaryData] = []
	var st := BattleState.create(mercs, team_b, null)
	st.battlefield = field
	return st


#True when one of the lines contains text.
static func has_line(lines: Array[String], text: String) -> bool:
	for line: String in lines:
		if line.contains(text):
			return true
	return false


#How many of the lines contain needle, or start with it when prefix_only is set.
static func count_lines(lines: Array[String], needle: String, prefix_only: bool = false) -> int:
	var n: int = 0
	for line: String in lines:
		var hit: bool = line.begins_with(needle) if prefix_only else line.contains(needle)
		if hit:
			n += 1
	return n


#Appends one obstacle dict to the field at cell and maps it.
static func put(f: BattlefieldArea, cell: Vector3i, obs: Dictionary) -> Dictionary:
	obs["pos"] = cell
	obs["floor"] = cell.z
	return attach(f, obs, false)


#Appends one obstacle dict at its own pos and floor and maps it; bump also stales sight and path caches.
static func attach(f: BattlefieldArea, obs: Dictionary, bump: bool = true) -> Dictionary:
	var pos: Variant = obs["pos"]
	f.obstacles.append(obs)
	f._obs_map[f.obs_key(Vector2i(pos.x, pos.y), int(obs.get("floor", 0)))] = obs
	if bump:
		f.los_version += 1
		f.bump_path_version()
	return obs


#Removes one attached obstacle dict and stales sight and path caches.
static func detach(f: BattlefieldArea, obs: Dictionary) -> void:
	var pos: Variant = obs["pos"]
	f.obstacles.erase(obs)
	f._obs_map.erase(f.obs_key(Vector2i(pos.x, pos.y), int(obs.get("floor", 0))))
	f.los_version += 1
	f.bump_path_version()


#Floods each cell to depth: the water and a floor sunk that far, then stales path caches.
static func flood(f: BattlefieldArea, cells: Array, depth: int) -> void:
	for cell: Vector2i in cells:
		f.water_cells[cell] = depth
		f.terrain_heights[cell] = -float(depth)
		f.ground_heights[cell] = -float(depth)
	f.bump_path_version()


#Puts a merc on the ground floor at pos.
static func place(state: BattleState, merc: MercenaryData, pos: Vector2i) -> void:
	state.positions[merc] = pos
	state.heights[merc] = 0
	state.floors[merc] = 0


#A bare weapon of this type, named after it.
static func weapon(weapon_type: String) -> WeaponData:
	var w := WeaponData.new()
	w.item_name = weapon_type + " (test)"
	w.weapon_type = weapon_type
	return w


#The library row with this trait_name, or null.
static func trait_row(library: Dictionary, trait_name: String) -> TraitData:
	for key: String in library:
		for entry: Variant in (library[key] as Array):
			var td: TraitData = entry as TraitData
			if td != null and td.trait_name == trait_name:
				return td
	return null


#The weapon trait library row with this trait_name, or null.
static func weapon_row(trait_name: String) -> TraitData:
	return trait_row(DataManager.weapon_trait_library, trait_name)


#A flat field with the two mercs one pace apart, weapons drawn and EP enough for a reaction.
static func duel(a: MercenaryData, b: MercenaryData) -> BattleState:
	var team_a: Array[MercenaryData] = [a]
	var team_b: Array[MercenaryData] = [b]
	var state := BattleState.create(team_a, team_b, null)
	state.battlefield = exterior_field()
	place(state, a, Vector2i(4, 4))
	place(state, b, Vector2i(5, 4))
	for m: MercenaryData in [a, b]:
		m.weapon_drawn = m.equipped_weapon != null
		m.current_ep = maxi(m.current_ep, 8)
	return state


#A city map of this tier grown from seed_i, on the Areas.tsv row named area_row.
static func city_gen(tier: String, seed_i: int, area_row: String) -> BattlefieldArea:
	seed(seed_i)
	var ctx := GenerationContext.new()
	ctx.city_tier = tier
	return BattlefieldArea.generate_random(null, ctx, "City", DataManager.get_area_by_name(area_row))


#Caverns rolled from seeds 1..count, so every case that reads them sees the same maps.
static func seeded_caverns(count: int) -> Array[BattlefieldArea]:
	var out: Array[BattlefieldArea] = []
	for i: int in range(count):
		seed(i + 1)
		var ctx := GenerationContext.new()
		out.append(BattlefieldArea.generate_random(null, ctx, "Cavern"))
	return out


#A tavern interior grown from seed_i.
static func seeded_tavern(seed_i: int) -> BattlefieldArea:
	seed(seed_i)
	var ctx := GenerationContext.new()
	var area_data: Dictionary = DataManager.get_area_by_name("Tavern")
	return BattlefieldArea.generate_random(null, ctx, String(area_data.get("type", "Interior")), area_data)


static func index(i: int, total: int) -> String:
	return str(i + 1).pad_zeros(str(maxi(1, total)).length())


static func difficulties(records: Array[Dictionary]) -> Array[float]:
	var out: Array[float] = []
	for record: Dictionary in records:
		var difficulty: float = float(record["difficulty"])
		if not out.has(difficulty):
			out.append(difficulty)
	out.sort()
	return out


static func at_difficulty(records: Array[Dictionary], difficulty: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for record: Dictionary in records:
		if is_equal_approx(float(record["difficulty"]), difficulty):
			out.append(record)
	return out


static func mean(rows: Array[Dictionary], key: String) -> float:
	if rows.is_empty():
		return 0.0
	var total: float = 0.0
	for record: Dictionary in rows:
		total += float(record[key])
	return total / float(rows.size())


#A record carrying -1 in this column had nothing to measure and stays out of the mean.
static func mean_valid(rows: Array[Dictionary], key: String) -> float:
	var total: float = 0.0
	var counted: int = 0
	for record: Dictionary in rows:
		var value: float = float(record[key])
		if value < 0.0:
			continue
		total += value
		counted += 1
	if counted == 0:
		return -1.0
	return total / float(counted)


static func rate(rows: Array[Dictionary], key: String) -> float:
	if rows.is_empty():
		return -1.0
	var hits: int = 0
	for record: Dictionary in rows:
		if bool(record[key]):
			hits += 1
	return float(hits) / float(rows.size()) * 100.0


static func pct(value: float) -> String:
	if value < 0.0:
		return "n/a"
	return "%d%%" % int(roundf(value))


static func num(value: float) -> String:
	if value < 0.0:
		return "n/a"
	return "%.1f" % value


static func ratio(value: float) -> String:
	if value < 0.0:
		return "n/a"
	return "%.2f" % value


#Makes the encounter log folder and the batch subfolder that holds the dumps.
static func ensure_gen_dir(sub_dir: String) -> void:
	EncounterLogger.ensure_dir()
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(EncounterLogger.LOG_DIR + "/" + sub_dir))


#Writes the viewer page and the level dump of map i into the batch subfolder.
static func dump_gen(field: BattlefieldArea, sub_dir: String, i: int) -> void:
	var stem: String = "%s/%s/%s_%03d" % [EncounterLogger.LOG_DIR, sub_dir, sub_dir, i]
	HtmlWireframeGenerator.save(field, stem)
	LevelDumpWriter.save(field, stem)


#One line per dumped map beside the dumps themselves.
static func write_gen_index(sub_dir: String, label: String, lines: PackedStringArray) -> void:
	var path: String = "%s/%s/index.txt" % [EncounterLogger.LOG_DIR, sub_dir]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("%s: could not write %s" % [label, path])
		return
	f.store_string("\n".join(lines) + "\n")
	f.close()


#A walker with hand-set stats and no weapon; overrides land on top of the shared dictionary.
static func flat_merc(merc_name: String, overrides: Dictionary = {}) -> MercenaryData:
	var m := MercenaryData.new()
	m.merc_name = merc_name
	m.merc_uid = CampaignKnowledge.next_uid()
	var s: Dictionary = {"level": 5.0, "luck": 5.0, "size": 1, "maximum_hit_points": 20,
		"maximum_endurance_points": 5, "speed": 3.0, "dexterity": 2, "vigor": 3,
		"pain_limit": 0, "pace": 3, "swim": 0.0, "climb": 1}
	s.merge(overrides, true)
	m.stats = s
	m.current_hp = 20
	return m


#A walker with hand-set stats, no weapon and melee accuracy.
static func city_melee(merc_name: String) -> MercenaryData:
	return flat_merc(merc_name, {"melee_accuracy": 8.0, "ranged_accuracy": 1.0})


#The same walker holding a drawn bow with ranged accuracy and six arrows.
static func city_ranged(merc_name: String) -> MercenaryData:
	var m: MercenaryData = city_melee(merc_name)
	m.stats["melee_accuracy"] = 1.0
	m.stats["ranged_accuracy"] = 12.0
	var w := WeaponData.new()
	w.item_name = merc_name + " bow (test)"
	w.weapon_type = "Bow"
	w.is_ranged = true
	w.misfire = 0
	w.damage_formula_1 = "1d6"
	w.damage_types_1 = ["Impale"] as Array[String]
	m.equipped_weapon = w
	m.weapon_drawn = true
	m.ammo_loaded = 6
	m.ammo_loaded_type = "Arrow"
	return m


#A shuffled difficulty deck of count cards, drawn from whole copies of DECK_CARDS.
static func build_deck(count: int) -> Array[float]:
	var cards: Array[float] = []
	var copies: int = maxi(1, ceili(float(count) / float(DECK_SIZE)))
	for _copy: int in range(copies):
		for card: Array in DECK_CARDS:
			for _i: int in range(int(card[1])):
				cards.append(float(card[0]))
	cards.shuffle()
	var out: Array[float] = []
	out.assign(cards.slice(0, maxi(0, count)))
	return out


#The batch header line naming every difficulty in the deck and how many cards carry it.
static func deck_line(deck: Array[float]) -> String:
	var values: Array[float] = []
	for card: float in deck:
		if not values.has(card):
			values.append(card)
	values.sort()
	var parts: Array[String] = []
	for value: float in values:
		parts.append("%.1f x%d" % [value, deck.count(value)])
	return "DECK: %d cards, %s" % [deck.size(), "  ".join(parts)]


#The terrain test matches ContractGenerator.pick_location_a, so the batch fights where contracts do.
static func wilderness_pool() -> Array[LocationData]:
	var out: Array[LocationData] = []
	for key: String in DataManager.locations.keys():
		var loc: LocationData = DataManager.locations[key] as LocationData
		if EventTrigger.is_wilderness(loc) and ContractTerrain.has_terrain(loc):
			out.append(loc)
	return out


#The loaded lifepath with this event name, or null.
static func lifepath(event_name: String) -> LifepathData:
	for category: String in DataManager.lifepaths_by_category:
		for lp: LifepathData in DataManager.lifepaths_by_category[category] as Array:
			if lp != null and lp.event_name == event_name:
				return lp
	return null


#One requirement cell as DataManager stores it; conj joins this entry to the next.
static func req(subject: String, op: String, value: String, conj: String = "") -> Dictionary:
	return {"subject": subject, "op": op, "value": value, "conj": conj}


#A lifepath built in code, for requirement shapes no Lifepaths.tsv row carries.
static func hand(reqs: Array[Dictionary]) -> LifepathData:
	var lp := LifepathData.new()
	lp.event_type = "Experienced"
	lp.event_name = "TEST Hand"
	lp.requirements.assign(reqs)
	return lp


static func ok(merc: MercenaryData, run: ContractRun, subject: String, op: String, value: String) -> bool:
	var single: Array[Dictionary] = [req(subject, op, value)]
	return LifepathRequirements.allows(merc, hand(single), run)


#Whether the merc carries a trait of this name among its perks, drawbacks or descriptors.
static func holds_trait(merc: MercenaryData, trait_name: String) -> bool:
	if trait_name == "":
		return false
	for store: Array in [merc.perks, merc.drawbacks, merc.descriptors]:
		for i: int in range(store.size()):
			var td: TraitData = store[i] as TraitData
			if td != null and td.trait_name == trait_name:
				return true
	return false


#The display names of the circumstance flags that are set on the merc.
static func true_flags(merc: MercenaryData) -> Array[String]:
	var out: Array[String] = []
	for display: String in merc.circumstance_flags:
		if bool(merc.circumstance_flags[display]):
			out.append(display)
	return out


#A battle state for the two sides, on field when one is given and on a flat field otherwise.
static func battle_state(a: Array[MercenaryData], b: Array[MercenaryData],
		field: BattlefieldArea = null) -> BattleState:
	var st: BattleState = BattleState.create(a, b, null)
	st.battlefield = field if field != null else exterior_field()
	return st


#A hand merc with an explicit stat dictionary, so every check threshold is arithmetic.
static func fixed_merc(merc_name: String, extras: Dictionary = {}) -> MercenaryData:
	var m := MercenaryData.new()
	m.merc_name = merc_name
	m.merc_uid = CampaignKnowledge.next_uid()
	var s: Dictionary = {"level": 5.0, "luck": 0.0, "size": 1, "maximum_hit_points": 20,
		"maximum_endurance_points": 5, "speed": 3.0, "dexterity": 2, "vigor": 2, "cognition": 2,
		"wile": 2, "pain_limit": 0, "pace": 3, "flee": 0.0, "base_success_chance": 0.0,
		"reroll": 0.0}
	s.merge(extras, true)
	m.stats = s
	m.current_hp = int(s.get("maximum_hit_points", 20))
	m.current_ep = int(s.get("maximum_endurance_points", 5))
	return m


#Recomputes the stats from the sheet with no pain limit and stores them as the baseline.
static func recalc(m: MercenaryData) -> void:
	m.stats = StatCalculator.calculate_all(m)
	m.stats["pain_limit"] = 0
	m.stats_baseline = StatCalculator.calculate_all(m)


#Hands the same roster to BeauSystem and GuildRoster.
static func set_roster(mercs: Array[MercenaryData]) -> void:
	BeauSystem.set_roster(mercs)
	GuildRoster.set_roster(mercs)


#A perk carrying this effect cell; TraitRuntime caches clauses by name, so names must be unique.
static func perk(trait_name: String, dsl: String, source: String = "") -> TraitData:
	var td := TraitData.new()
	td.trait_name = trait_name
	td.trait_type = "Perk"
	td.trait_source = source
	td.effect_dsl = dsl
	return td


#An ArmorData with each given field set on it.
static func armor(fields: Dictionary) -> ArmorData:
	var a := ArmorData.new()
	for key: String in fields:
		a.set(key, fields[key])
	return a


#Hands the merc a drawn weapon of weapon_type and grants it one of the weapon's library perks.
static func arm(m: MercenaryData, weapon_type: String, perk_name: String, has_light: bool = false) -> MercenaryData:
	m.equipped_weapon = weapon(weapon_type)
	if has_light:
		m.equipped_weapon.has_light = true
	m.weapon_drawn = true
	var row: TraitData = weapon_row(perk_name)
	if row != null:
		PerkGrants.grant_weapon_perk(m, row, "test")
	return m


#A sheet merc holding a drawn weapon of weapon_type and owning one of its library perks.
static func armed(merc_name: String, weapon_type: String, perk_name: String) -> MercenaryData:
	return arm(sheet_merc(merc_name), weapon_type, perk_name)


#A flat field with the merc at (4,4) and one enemy per cell; top_up gives it 8 EP and 6 AP at least.
static func crowd(a: MercenaryData, foes: Array[MercenaryData], cells: Array, draw_foes: bool = false,
		top_up: bool = false) -> BattleState:
	var team_a: Array[MercenaryData] = [a]
	var state := BattleState.create(team_a, foes, null)
	state.battlefield = exterior_field()
	place(state, a, Vector2i(4, 4))
	for i: int in range(foes.size()):
		place(state, foes[i], cells[i])
	a.weapon_drawn = a.equipped_weapon != null
	if draw_foes:
		for foe: MercenaryData in foes:
			foe.weapon_drawn = foe.equipped_weapon != null
	if top_up:
		a.current_ep = maxi(a.current_ep, 8)
		a.current_ap = maxi(a.current_ap, 6)
	return state


#A level 5 merc with 8 in every max stat and these overrides on top, at full hit points.
static func _stat_merc(merc_name: String, luck: float, overrides: Dictionary, with_uid: bool) -> MercenaryData:
	var m := MercenaryData.new()
	m.merc_name = merc_name
	if with_uid:
		m.merc_uid = CampaignKnowledge.next_uid()
	var maxes: Dictionary = {"max_vigor": 8, "max_dexterity": 8, "max_cognition": 8, "max_wile": 8, "size": 1}
	maxes.merge(overrides, true)
	m.max_stats = maxes
	m.luck_roll = luck
	m.stats = {"level": 5}
	recalc(m)
	return m


#A level 5 merc with 8 in every max stat, luck 5.0, full hit points and no endurance spent.
static func level_merc(merc_name: String, with_uid: bool = true, with_xp: bool = false) -> MercenaryData:
	var m := _stat_merc(merc_name, 5.0, {}, with_uid)
	m.current_hp = int(m.stats.get("maximum_hit_points", 1))
	m.current_ep = 0
	if with_xp:
		m.xp = ExperienceSystem.xp_for_level(5)
	return m


#A contract run carrying this team, the contract with its location_a and the verdict.
static func run_for(team: Array[MercenaryData], contract: ContractData = null, verdict: String = "") -> ContractRun:
	var run := ContractRun.new()
	run.team.assign(team)
	run.contract = contract
	run.verdict = verdict
	if contract != null and contract.location_a != "":
		run.location = DataManager.locations.get(contract.location_a, null) as LocationData
	return run


#A merc whose stats come from TSVs/Stats.tsv through StatCalculator.
static func sheet_merc(merc_name: String, luck: float = 5.0, overrides: Dictionary = {}) -> MercenaryData:
	var m := _stat_merc(merc_name, luck, overrides, true)
	StatCalculator.refresh(m)
	m.current_hp = int(m.stats.get("maximum_hit_points", 1))
	m.current_ep = int(m.stats.get("maximum_endurance_points", 0))
	return m


static func set_level(merc: MercenaryData, level: int) -> void:
	if merc == null:
		return
	StatCalculator.prime(merc)
	merc.stats["level"] = float(level)
	merc.xp = ExperienceSystem.xp_for_level(level)
	StatCalculator.refresh(merc)


#Generated mercs set to this level; catch_up also resolves their level-up picks.
static func generated_team(size: int, level: int, catch_up: bool = false) -> Array[MercenaryData]:
	var team: Array[MercenaryData] = []
	for i: int in range(size):
		var merc: MercenaryData = MercGenerator.generate(i)
		set_level(merc, level)
		if catch_up:
			LevelUpSystem.catch_up(merc)
		team.append(merc)
	return team


#Hires count more generated mercs at this level the way start_new_game signs its own and returns them; state is a
#GameState instance a suite runs on its own, the autoload when null.
static func add_mercs(count: int, level: int = 1, state: Node = null) -> Array[MercenaryData]:
	var target: Node = state if state != null else GameState
	var added: Array[MercenaryData] = []
	if count <= 0:
		return added
	var previous_level: int = MercGenerator.forced_level
	for _i: int in range(count):
		MercGenerator.forced_level = level
		var merc: MercenaryData = MercGenerator.generate(int(target.mercs.size()))
		MercGenerator.forced_level = previous_level
		target.hire(merc)
		added.append(merc)
	GuildRoster.set_roster(target.mercs)
	BeauSystem.set_roster(target.mercs)
	return added


#An Experienced lifepath built in code with this rarity and these requirements.
static func lifepath_stub(event_name: String, rarity: String = "", reqs: Array[Dictionary] = []) -> LifepathData:
	var lp := LifepathData.new()
	lp.event_type = "Experienced"
	lp.event_name = event_name
	lp.rarity = rarity
	lp.requirements.assign(reqs)
	return lp


#Adds the lifepath to the Experienced pool so grant, force and the pools can find it by name.
static func register_stub(lp: LifepathData) -> LifepathData:
	if not DataManager.lifepaths_by_category.has("Experienced"):
		DataManager.lifepaths_by_category["Experienced"] = []
	(DataManager.lifepaths_by_category["Experienced"] as Array).append(lp)
	return lp


static func unregister_stub(lp: LifepathData) -> void:
	(DataManager.lifepaths_by_category.get("Experienced", []) as Array).erase(lp)
