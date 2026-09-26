class_name PerkTests

#Weapon and armor perk selection, the armor rules and the perk substrate. Run with --perk-tests.

static func run() -> bool:
	seed(7777)
	var res := {"pass": 0, "fail": 0}
	_case_selection(res)
	_case_grants(res)
	_case_armor(res)
	_case_substrate(res)
	_case_reactions(res)
	_case_reactions_wounds(res)
	_case_reactions_spends(res)
	_case_reactions_criticals(res)
	_case_reactions_obliteration(res)
	_case_reactions_answers(res)
	_case_actions(res)
	_case_actions_singles(res)
	_case_actions_charges(res)
	_case_actions_magazines(res)
	_case_actions_calls(res)
	_case_over_extend(res)
	_case_passives(res)
	_case_passives_shotgun(res)
	_case_passives_reload(res)
	_case_passives_reach(res)
	_case_decisions(res)
	_case_perk_load(res)
	_case_sheet(res)
	return TestFixtures.summarize(res, "PERK")


static func _case_selection(res: Dictionary) -> void:
	if _rows(res, "the weapon perk library loads the Staff rows", ["Staff|Staff Propulsion"]).is_empty():
		return
	var merc := _armed("Selector", "Staff", "Staff|Staff Propulsion")
	TestFixtures.check(res, "a held weapon activates the perk of its own type",
		WeaponArmorPerkLibrary.get_active_weapon_perks(merc).size() == 1,
		"%d active" % WeaponArmorPerkLibrary.get_active_weapon_perks(merc).size())
	merc.equipped_weapon = TestFixtures.weapon("Glaive")
	TestFixtures.check(res, "a different weapon type leaves the perk inactive",
		WeaponArmorPerkLibrary.get_active_weapon_perks(merc).is_empty(),
		"holding %s" % merc.equipped_weapon.weapon_type)
	merc.equipped_weapon = TestFixtures.weapon("Staff")
	merc.weapon_drawn = false
	TestFixtures.check(res, "a holstered weapon carries no active perk",
		WeaponArmorPerkLibrary.get_active_weapon_perks(merc).is_empty(), "weapon_drawn false")

	var mk := _armed("Makeshift", "Staff", "Staff|Staff Propulsion")
	mk.equipped_weapon.base_weapon = TestFixtures.weapon("Club (Basic)")
	TestFixtures.check(res, "a makeshift weapon carries no perk of its own",
		WeaponArmorPerkLibrary.get_active_weapon_perks(mk).is_empty(), "no ReP spent")
	mk.active_states["makeshift_perk_active"] = "Staff|Staff Propulsion"
	TestFixtures.check(res, "the perk ReP activated is the one a makeshift weapon carries",
		WeaponArmorPerkLibrary.get_active_weapon_perks(mk).size() == 1,
		str(mk.active_states.get("makeshift_perk_active", "")))
	var mk_keys: Array = WeaponArmorPerkLibrary.held_gear_keys(mk)["weapon"]
	TestFixtures.check(res, "a makeshift weapon adds its tier Makeshift key",
		mk_keys.has("Staff") and mk_keys.has("Basic Makeshift"), str(mk_keys))

	var clad := TestFixtures.sheet_merc("Clad")
	clad.equipped_weapon = TestFixtures.weapon("Staff")
	clad.offhand_weapon = TestFixtures.weapon("Dagger")
	clad.equipped_armor = _armor("Light")
	var held: Dictionary = WeaponArmorPerkLibrary.held_gear_keys(clad)
	var weapon_keys: Array = held["weapon"]
	var armor_keys: Array = held["armor"]
	TestFixtures.check(res, "held gear keys list both hands and the worn armor",
		weapon_keys.size() == 2 and armor_keys.size() == 1 and armor_keys.has("Light"),
		"%s and %s" % [str(weapon_keys), str(armor_keys)])


static func _case_grants(res: Dictionary) -> void:
	var rows := _rows(res, "the weapon and armor perk libraries load",
		["Staff|Staff Propulsion", "Lightweight Adept"])
	if rows.is_empty():
		return
	var staff: TraitData = rows["Staff|Staff Propulsion"]
	var adept: TraitData = rows["Lightweight Adept"]
	var merc := TestFixtures.sheet_merc("Granted")
	var detail: String = WeaponArmorPerkLibrary.grant_weapon_perk(merc, staff, "test")
	var again: String = WeaponArmorPerkLibrary.grant_weapon_perk(merc, staff, "test")
	TestFixtures.check(res, "grant_weapon_perk adds the same perk only once",
		merc.weapon_perks.size() == 1 and again == "", detail)

	var wearer := TestFixtures.sheet_merc("Wearer")
	wearer.equipped_armor = _armor("Light")
	var speed_before: int = int(wearer.stats.get("speed", 0))
	WeaponArmorPerkLibrary.grant_armor_perk(wearer, adept, "test")
	var speed_once: int = int(wearer.stats.get("speed", 0))
	WeaponArmorPerkLibrary.grant_armor_perk(wearer, adept, "test")
	StatCalculator.refresh(wearer)
	TestFixtures.check(res, "an armor perk applies its permanent token once",
		speed_once == speed_before + 3 and int(wearer.stats.get("speed", 0)) == speed_once,
		"speed %d to %d to %d" % [speed_before, speed_once, int(wearer.stats.get("speed", 0))])

	var bare := TestFixtures.sheet_merc("Bare")
	var parked: bool = WeaponArmorPerkLibrary.defer_gear_grant(bare, "grant:random:weapon_perk:1", "test")
	TestFixtures.check(res, "a gear perk grant with no gear waits for the gear",
		parked and bare.deferred_gear_grants.size() == 1,
		"%d parked" % bare.deferred_gear_grants.size())
	bare.equipped_weapon = TestFixtures.weapon("Staff")
	bare.weapon_drawn = true
	WeaponArmorPerkLibrary.resolve_deferred_grants(bare)
	TestFixtures.check(res, "equipping gear resolves the parked grant",
		bare.deferred_gear_grants.is_empty() and bare.weapon_perks.size() == 1,
		"%d parked, %d perks" % [bare.deferred_gear_grants.size(), bare.weapon_perks.size()])

	var unarmored := TestFixtures.sheet_merc("Unarmored")
	unarmored.equipped_weapon = TestFixtures.weapon("Staff")
	unarmored.weapon_drawn = true
	MercGenerator.apply_dsl_to_merc(unarmored, "grant:random:armor_perk:1", "test")
	var skipped: int = 0
	for entry: Dictionary in unarmored.level_up_log:
		if str(entry.get("option", "")) == "perk_grant_skipped":
			skipped += 1
	TestFixtures.check(res, "a grant with no matching gear is logged as skipped",
		skipped == 1 and unarmored.armor_perks.is_empty(),
		"%d skipped, %d armor perks" % [skipped, unarmored.armor_perks.size()])


static func _case_armor(res: Dictionary) -> void:
	var rows := _rows(res, "the armor rule rows load", ["Weight Adjusted (Heavy)",
		"Weight Adjusted (Light)", "Heavy Crossbow|Heavy Crossbow Armor Pierce", "Maul|Maul Armor Break"])
	if rows.is_empty():
		return
	var adjusted_heavy: TraitData = rows["Weight Adjusted (Heavy)"]
	var adjusted_light: TraitData = rows["Weight Adjusted (Light)"]
	var heavy := TestFixtures.sheet_merc("Heavy")
	heavy.equipped_armor = _armor("Heavy", 9, 1, 3)
	TestFixtures.check(res, "worn armor raises the EP a spend costs",
		CombatApplicator.state_ep_cost(heavy, 1, "defend") == 2,
		"cost %d" % CombatApplicator.state_ep_cost(heavy, 1, "defend"))
	WeaponArmorPerkLibrary.grant_armor_perk(heavy, adjusted_heavy, "test")
	TestFixtures.check(res, "a Weight Adjusted perk ignores that armor's EP cost",
		CombatApplicator.state_ep_cost(heavy, 1, "defend") == 1,
		"cost %d" % CombatApplicator.state_ep_cost(heavy, 1, "defend"))

	var light := TestFixtures.sheet_merc("Light")
	light.equipped_armor = _armor("Light", 3, 0, 2)
	var carried_before: int = Encumbrance.carried_weight(light)
	WeaponArmorPerkLibrary.grant_armor_perk(light, adjusted_light, "test")
	TestFixtures.check(res, "a Weight Adjusted perk takes its armor out of the carried weight",
		carried_before == 2 and Encumbrance.carried_weight(light) == 0,
		"%d to %d" % [carried_before, Encumbrance.carried_weight(light)])

	TestFixtures.check(res, "the Armor Bonus is the extra Defend dice",
		WeaponArmorPerkLibrary.effective_armor_bonus(heavy) == 9,
		"%d dice" % WeaponArmorPerkLibrary.effective_armor_bonus(heavy))
	var plain_def: Dictionary = {"stat_keys": ["defend_reduction"], "circumstances": [],
		"knowledges": [], "tools": [], "formula": "defend", "enhancements": 0}
	var bonus_def: Dictionary = plain_def.duplicate()
	bonus_def["dice_bonus"] = 3
	var base_dice: int = int(heavy.stats.get("defend_reduction", 0))
	var plain_dice: int = int(CheckSystem._prepare(heavy, plain_def)["dice"])
	var bonus_dice: int = int(CheckSystem._prepare(heavy, bonus_def)["dice"])
	TestFixtures.check(res, "a dice bonus adds dice to a check",
		plain_dice == maxi(1, base_dice) and bonus_dice == maxi(1, base_dice + 3),
		"%d then %d from stat %d" % [plain_dice, bonus_dice, base_dice])

	var mauler := _armed("Mauler", "Maul", "Maul|Maul Armor Break")
	TestFixtures.check(res, "an Armor Break weapon reduces heavy armor",
		WeaponArmorPerkLibrary.armor_break_amount(mauler, heavy) == 1,
		"%d off" % WeaponArmorPerkLibrary.armor_break_amount(mauler, heavy))
	TestFixtures.check(res, "an Armor Break weapon leaves light armor alone",
		WeaponArmorPerkLibrary.armor_break_amount(mauler, light) == 0,
		"light armor is not heavy")
	heavy.armor_break = 1
	TestFixtures.check(res, "Armor Break takes the Armor Bonus down",
		WeaponArmorPerkLibrary.effective_armor_bonus(heavy) == 8,
		"%d dice" % WeaponArmorPerkLibrary.effective_armor_bonus(heavy))
	heavy.rest_lockout_kind = RestSystem.KIND_FURLOUGH
	heavy.rest_lockout_until = 0
	var furlough: Array[String] = RestSystem.furlough_complete(heavy, 100)
	TestFixtures.check(res, "a furlough repairs the broken armor",
		heavy.armor_break == 0 and TestFixtures.has_line(furlough, "armor repaired"),
		" | ".join(furlough))

	var shooter := _armed("Shooter", "Heavy Crossbow", "Heavy Crossbow|Heavy Crossbow Armor Pierce")
	TestFixtures.check(res, "Armor Pierce flaws the defense of a heavy armor wearer",
		WeaponArmorPerkLibrary.defense_flaws_against(shooter, heavy) == 1,
		"%d flaw" % WeaponArmorPerkLibrary.defense_flaws_against(shooter, heavy))
	TestFixtures.check(res, "Armor Pierce leaves a light armor wearer alone",
		WeaponArmorPerkLibrary.defense_flaws_against(shooter, light) == 0,
		"light armor is not heavy")


static func _case_substrate(res: Dictionary) -> void:
	var rows := _rows(res, "the substrate perk rows load",
		["Glaive|Glaive Vault", "Rifle|Rifle Long-Shot", "Rifle|Rifle Infallible"])
	if rows.is_empty():
		return
	var young := TestFixtures.sheet_merc("Young")
	TestFixtures.check(res, "is_level_20 reads the merc's level",
		not WeaponArmorPerkLibrary.is_level_20(young), "level %d" % int(young.stats.get("level", 0)))

	var walker := _armed("Walker", "Staff", "Staff|Staff Propulsion")
	var pace_before: int = int(walker.stats.get("pace", 0))
	StatCalculator.refresh(walker)
	var pace_drawn: int = int(walker.stats.get("pace", 0))
	TestFixtures.check(res, "a held staff adds its Pace to the sheet", pace_drawn == pace_before + 1,
		"pace %d to %d" % [pace_before, pace_drawn])
	walker.weapon_drawn = false
	WeaponArmorPerkLibrary.refresh_held_bonuses(walker)
	TestFixtures.check(res, "holstering the staff takes the Pace back",
		int(walker.stats.get("pace", 0)) == pace_before,
		"pace %d to %d" % [pace_drawn, int(walker.stats.get("pace", 0))])

	var vaulter := _armed("Vaulter", "Glaive", "Glaive|Glaive Vault")
	var jump_five: int = int(WeaponArmorPerkLibrary.held_stat_bonuses(vaulter).get("jump", 0))
	vaulter.stats["level"] = 20
	var jump_twenty: int = int(WeaponArmorPerkLibrary.held_stat_bonuses(vaulter).get("jump", 0))
	TestFixtures.check(res, "Glaive Vault doubles its Jump at 20th level",
		jump_five == 1 and jump_twenty == 2, "jump +%d then +%d" % [jump_five, jump_twenty])

	var sniper := _armed("Sniper", "Rifle", "Rifle|Rifle Long-Shot")
	_ranged(sniper, 10, 20)
	var plain: Dictionary = WeaponArmorPerkLibrary.ranged_ranges(sniper, sniper.equipped_weapon)
	sniper.aim_active = true
	var aimed: Dictionary = WeaponArmorPerkLibrary.ranged_ranges(sniper, sniper.equipped_weapon)
	TestFixtures.check(res, "Aim doubles the ranged bands of a Long-Shot weapon",
		int(plain["intended"]) == 10 and int(aimed["intended"]) == 20 and int(aimed["extended"]) == 40,
		"%d/%d aimed to %d/%d" % [int(plain["intended"]), int(plain["extended"]),
			int(aimed["intended"]), int(aimed["extended"])])

	var gunner := _armed("Gunner", "Rifle", "Rifle|Rifle Infallible")
	TestFixtures.check(res, "Rifle Infallible raises the attack threshold by 10",
		is_equal_approx(WeaponArmorPerkLibrary.attack_threshold_bonus(gunner), 10.0),
		"+%s" % str(WeaponArmorPerkLibrary.attack_threshold_bonus(gunner)))

	var hitter := TestFixtures.sheet_merc("Hitter")
	var victim := TestFixtures.sheet_merc("Victim")
	var team_a: Array[MercenaryData] = [hitter]
	var team_b: Array[MercenaryData] = [victim]
	var state := BattleState.create(team_a, team_b, null)
	var hp_before: int = victim.current_hp
	var ep_before: int = victim.current_ep
	var lines: Array[String] = CombatApplicator.deal_direct(hitter, victim, 3, "Strike", state, "Test Perk")
	TestFixtures.check(res, "deal_direct lands damage with no defence roll",
		victim.current_hp == hp_before - 3 and victim.current_ep == ep_before
			and TestFixtures.has_line(lines, "Test Perk"),
		"hp %d to %d, ep %d" % [hp_before, victim.current_hp, victim.current_ep])


#T3: the weapon perks that answer a trigger instead of a turn decision.
static func _case_reactions(res: Dictionary) -> void:
	if _rows(res, "the reactive weapon perk rows load", ["Colossal Sword|Colossal Sword Drag"]).is_empty():
		return
	var dragger := _armed("Dragger", "Colossal Sword", "Colossal Sword|Colossal Sword Drag")
	var dragged := TestFixtures.sheet_merc("Dragged")
	var drag_state := TestFixtures.duel(dragger, dragged)
	var drag_hp: int = dragged.current_hp
	var drag_lines: Array[String] = WeaponReactiveSystem.fire_trigger(dragger, "on_miss", dragged,
		{}, drag_state, 0)
	var drag_one: int = drag_hp - dragged.current_hp
	dragger.stats["level"] = 20
	drag_hp = dragged.current_hp
	WeaponReactiveSystem.fire_trigger(dragger, "on_miss", dragged, {}, drag_state, 0)
	var drag_two: int = drag_hp - dragged.current_hp
	TestFixtures.check(res, "Colossal Drag deals 1 direct on a miss and 2 at 20th level",
		drag_one == 1 and drag_two == 2 and not drag_lines.is_empty(),
		"%d then %d damage" % [drag_one, drag_two])

	var piker := _armed("Piker", "Pike", "Pike|Pike Manipulation")
	var pushed := TestFixtures.sheet_merc("Pushed")
	var push_state := TestFixtures.duel(piker, pushed)
	var push_from: Vector2i = push_state.get_position(pushed)
	WeaponReactiveSystem.fire_trigger(piker, "on_damage", pushed, {"damage_dealt": 1}, push_state, 0)
	var push_one: int = push_state.get_position(pushed).x - push_from.x
	piker.stats["level"] = 20
	push_from = push_state.get_position(pushed)
	WeaponReactiveSystem.fire_trigger(piker, "on_damage", pushed, {"damage_dealt": 1}, push_state, 0)
	var push_two: int = push_state.get_position(pushed).x - push_from.x
	TestFixtures.check(res, "Pike Manipulation pushes 1 pace and 2 at 20th level",
		push_one == 1 and push_two == 2, "%d then %d paces" % [push_one, push_two])

	var shifter := _armed("Shifter", "Short Sword", "Short Sword|Short Sword Shift")
	var shifted := TestFixtures.sheet_merc("Shifted")
	var shift_state := TestFixtures.duel(shifter, shifted)
	var shift_a: Vector2i = shift_state.get_position(shifter)
	var shift_b: Vector2i = shift_state.get_position(shifted)
	WeaponReactiveSystem.fire_trigger(shifter, "on_damage", shifted, {"damage_dealt": 1},
		shift_state, 0)
	TestFixtures.check(res, "Short Sword Shift trades cells with the target",
		shift_state.get_position(shifter) == shift_b and shift_state.get_position(shifted) == shift_a,
		"%s and %s" % [str(shift_state.get_position(shifter)), str(shift_state.get_position(shifted))])


#The reactive perks that take maximum HP, strike on the draw and add Dexterity to the damage.
static func _case_reactions_wounds(res: Dictionary) -> void:
	var render := _armed("Render", "Glaive", "Glaive|Glaive Rend")
	var rent := TestFixtures.sheet_merc("Rent")
	var rend_state := TestFixtures.duel(render, rent)
	var max_before: int = int(rent.stats.get("maximum_hit_points", 0))
	WeaponReactiveSystem.fire_trigger(render, "on_damage", rent, {"damage_dealt": 2}, rend_state, 0)
	var max_rent: int = int(rent.stats.get("maximum_hit_points", 0))
	rent.rest_lockout_kind = RestSystem.KIND_FURLOUGH
	rent.rest_lockout_until = 0
	var mended: Array[String] = RestSystem.furlough_complete(rent, 100)
	TestFixtures.check(res, "Glaive Rend takes maximum HP until a furlough gives it back",
		max_rent == max_before - 2 and rent.max_hp_penalty == 0
			and int(rent.stats.get("maximum_hit_points", 0)) == max_before
			and TestFixtures.has_line(mended, "max HP restored"),
		"%d to %d to %d" % [max_before, max_rent, int(rent.stats.get("maximum_hit_points", 0))])

	var blur := _armed("Blur", "Katana", "Katana|Katana Blur")
	blur.equipped_weapon.melee_range = 1
	var blurred := TestFixtures.sheet_merc("Blurred")
	var blur_state := TestFixtures.duel(blur, blurred)
	var blur_ep: int = ExcessPool.available_ep(blur)
	var blur_lines: Array[String] = WeaponReactiveSystem.fire_trigger(blur, "on_draw", blurred, {},
		blur_state, 0)
	TestFixtures.check(res, "Katana Blur attacks the moment the katana is drawn",
		not blur_lines.is_empty() and ExcessPool.available_ep(blur) < blur_ep,
		"%d line(s), EP %d to %d" % [blur_lines.size(), blur_ep, ExcessPool.available_ep(blur)])

	var headshot := _armed("Headshot", "Handgun", "Handgun|Handgun Headshot")
	_ranged(headshot)
	headshot.stats["dexterity"] = 2
	var shot := TestFixtures.sheet_merc("Shot")
	var head_state := TestFixtures.duel(headshot, shot)
	var head_hp: int = shot.current_hp
	WeaponReactiveSystem.fire_trigger(headshot, "on_damage", shot, {"damage_dealt": 1}, head_state, 0)
	TestFixtures.check(res, "Handgun Headshot adds the shooter's Dexterity to the damage",
		head_hp - shot.current_hp == 2, "%d damage" % (head_hp - shot.current_hp))


#The reactive perks that spend ReP, catch a thrown weapon and refill an empty chamber.
static func _case_reactions_spends(res: Dictionary) -> void:
	var impactor := _armed("Impactor", "Maul", "Maul|Maul Impact")
	impactor.stats["vigor"] = 4
	var dented := TestFixtures.sheet_merc("Dented")
	var impact_state := TestFixtures.duel(impactor, dented)
	impactor.current_rep = 0
	var poor: Array[String] = WeaponReactiveSystem.fire_trigger(impactor, "on_damage_2_plus", dented,
		{"damage_dealt": 2}, impact_state, 0)
	impactor.current_rep = 3
	var dent_hp: int = dented.current_hp
	var rich: Array[String] = WeaponReactiveSystem.fire_trigger(impactor, "on_damage_2_plus", dented,
		{"damage_dealt": 2}, impact_state, 0)
	TestFixtures.check(res, "Maul Impact needs 3 ReP to raise the damage to Vigor",
		poor.is_empty() and not rich.is_empty() and impactor.current_rep == 0
			and dent_hp - dented.current_hp == 2,
		"%d ReP left, %d damage" % [impactor.current_rep, dent_hp - dented.current_hp])

	var tosser := _armed("Tosser", "Mallet", "Mallet|Mallet Rebound")
	tosser.equipped_weapon.is_throwable = true
	var struck := TestFixtures.sheet_merc("Struck")
	var toss_state := TestFixtures.duel(tosser, struck)
	var caught: Array[String] = WeaponReactiveSystem.apply_on_hit(tosser, struck,
		{"is_throw": true}, toss_state)
	TestFixtures.check(res, "Mallet Rebound catches the thrown mallet back into the hand",
		bool(tosser.active_states.get("weapon_caught", false)) and TestFixtures.has_line(caught, "catches"),
		" | ".join(caught))

	var bolter := _armed("Bolter", "Hand Ballista", "Hand Ballista|Hand Ballista Reload")
	_ranged(bolter, 0, 0, 3)
	var pinned := TestFixtures.sheet_merc("Pinned")
	var bolt_state := TestFixtures.duel(bolter, pinned)
	bolter.ammo_loaded = 0
	bolter.ammo_loaded_type = "Bolt"
	bolter.ammo_inventory = {"Bolt": 5}
	WeaponReactiveSystem.fire_trigger(bolter, "on_last_shot", pinned, {}, bolt_state, 0)
	TestFixtures.check(res, "Hand Ballista Reload fills the chamber after the last shot",
		bolter.ammo_loaded == 3 and int(bolter.ammo_inventory.get("Bolt", 0)) == 2,
		"%d chambered" % bolter.ammo_loaded)


#The Hand Ballista reactions that turn a near hit critical and shove on a critical.
static func _case_reactions_criticals(res: Dictionary) -> void:
	var eliminator := _armed("Eliminator", "Hand Ballista",
		"Hand Ballista|Hand Ballista Threat Elimination")
	_ranged(eliminator)
	var threat := TestFixtures.sheet_merc("Threat")
	var crit_state := TestFixtures.duel(eliminator, threat)
	var crit_atk: Dictionary = {"damage_dealt": 1, "critical": false}
	WeaponReactiveSystem.fire_trigger(eliminator, "on_damage", threat, crit_atk, crit_state, 0)
	TestFixtures.check(res, "Threat Elimination turns a hit inside 2 paces critical",
		bool(crit_atk.get("critical", false)), str(crit_atk.get("critical", false)))

	var sharpshot := _armed("Sharpshot", "Hand Ballista", "Hand Ballista|Hand Ballista Critical")
	_ranged(sharpshot)
	var jolted := TestFixtures.sheet_merc("Jolted")
	var jolt_state := TestFixtures.duel(sharpshot, jolted)
	var jolt_from: Vector2i = jolt_state.get_position(jolted)
	var jolt_lines: Array[String] = WeaponReactiveSystem.fire_crit_passives(sharpshot, jolted,
		jolt_state)
	var jolt_paces: int = jolt_state.get_position(jolted).x - jolt_from.x
	TestFixtures.check(res, "Hand Ballista Critical shoves the target on a critical",
		jolt_paces >= 1 and jolt_paces <= 2 and not jolt_lines.is_empty(),
		"%d pace(s)" % jolt_paces)


#Great Club Obliteration and the Ethereal target it refuses.
static func _case_reactions_obliteration(res: Dictionary) -> void:
	var clubber := _armed("Clubber", "Great Club", "Great Club|Great Club Obliteration")
	var doomed := TestFixtures.sheet_merc("Doomed")
	var doom_state := TestFixtures.duel(clubber, doomed)
	doomed.current_hp = 1
	var doom_lines: Array[String] = []
	var doom_ok: bool = CombatApplicator._try_obliterate(clubber, doomed, doom_state, "Doomed",
		doom_lines)
	TestFixtures.check(res, "Obliteration kills a target left at 1 HP with no death test",
		doom_ok and doomed.is_dead and not ConstStates.has_state(doomed, ConstStates.DYING),
		" | ".join(doom_lines))
	var ghoster := _armed("Ghoster", "Great Club", "Great Club|Great Club Obliteration")
	var ghost := TestFixtures.sheet_merc("Ghost")
	ghost.creature_types.append("Ethereal")
	var ghost_state := TestFixtures.duel(ghoster, ghost)
	ghost.current_hp = 1
	var ghost_lines: Array[String] = []
	var ghost_ok: bool = CombatApplicator._try_obliterate(ghoster, ghost, ghost_state, "Ghost",
		ghost_lines)
	TestFixtures.check(res, "Obliteration refuses an Ethereal target",
		not ghost_ok and not ghost.is_dead, "%d line(s)" % ghost_lines.size())


#The reactions that answer a shove and the parry that follows a deflection.
static func _case_reactions_answers(res: Dictionary) -> void:
	var crosser := _armed("Crosser", "Light Crossbow", "Light Crossbow|Light Crossbow Shove-Shot")
	_ranged(crosser, 10, 20)
	var barged := TestFixtures.sheet_merc("Barged")
	var shove_state := TestFixtures.duel(crosser, barged)
	crosser.ammo_loaded = 4
	crosser.ammo_loaded_type = "Bolt"
	var shove_ep: int = ExcessPool.available_ep(crosser)
	var shove_lines: Array[String] = WeaponReactiveSystem.fire_shove_seen(barged, shove_state)
	TestFixtures.check(res, "Shove-Shot answers a shove inside the intended range",
		not shove_lines.is_empty() and ExcessPool.available_ep(crosser) < shove_ep,
		"EP %d to %d" % [shove_ep, ExcessPool.available_ep(crosser)])

	var parrier := _armed("Parrier", "Short Sword", "Short Sword|Short Sword Deflection")
	var parry_row: TraitData = TestFixtures.weapon_row("Short Sword|Short Sword Parry")
	if parry_row != null:
		WeaponArmorPerkLibrary.grant_weapon_perk(parrier, parry_row, "test")
	var lunger := TestFixtures.sheet_merc("Lunger")
	lunger.equipped_weapon = TestFixtures.weapon("Short Sword")
	lunger.equipped_weapon.melee_range = 1
	var parry_state := TestFixtures.duel(lunger, parrier)
	var flaws_five: int = WeaponReactiveSystem.incoming_attack_flaws(lunger, parrier, parry_state)
	parrier.stats["level"] = 20
	var flaws_twenty: int = WeaponReactiveSystem.incoming_attack_flaws(lunger, parrier, parry_state)
	TestFixtures.check(res, "Short Sword Deflection flaws the attack, twice at 20th level",
		flaws_five == 1 and flaws_twenty == 2, "+%d then +%d flaws" % [flaws_five, flaws_twenty])
	var parry_ep: int = ExcessPool.available_ep(parrier)
	var lunge_hp: int = lunger.current_hp
	WeaponReactiveSystem.after_attack_resolved(lunger, parrier, {}, parry_state)
	TestFixtures.check(res, "Short Sword Parry costs no EP after a Deflection",
		lunge_hp - lunger.current_hp == 1 and ExcessPool.available_ep(parrier) == parry_ep,
		"%d damage, EP %d to %d" % [lunge_hp - lunger.current_hp, parry_ep,
			ExcessPool.available_ep(parrier)])


#T4: the action perk rows the dispatcher scores, picks and runs.
static func _case_actions(res: Dictionary) -> void:
	var rows := _rows(res, "the action weapon perk rows load",
		["Longsword|Longsword Impale", "Auto-Rifle|Auto-Rifle Bully"])
	if rows.is_empty():
		return
	var impale_row: TraitData = rows["Longsword|Longsword Impale"]

	var impaler := _armed("Impaler", "Longsword", "Longsword|Longsword Impale")
	var speared := TestFixtures.sheet_merc("Speared")
	var lined := TestFixtures.sheet_merc("Lined")
	var impale_foes: Array[MercenaryData] = [speared, lined]
	var impale_state := _crowd(impaler, impale_foes, [Vector2i(5, 4), Vector2i(6, 4)])
	var behind_hp: int = lined.current_hp
	var impale_lines: Array[String] = PerkActionExecutor.execute_perk_action(impaler, impale_row,
		speared, impale_state, 0)
	TestFixtures.check(res, "Longsword Impale swings for +2 and puts 1 direct behind the target",
		str(PerkValuation.parse_action(impale_row)["effect"]) == "attack_plus_2"
			and behind_hp - lined.current_hp == 1 and not impale_lines.is_empty(),
		"%d behind" % (behind_hp - lined.current_hp))

	var piker := _armed("Piker", "Pike", "Pike|Pike Rapidity")
	var poked := TestFixtures.sheet_merc("Poked")
	var pike_state := TestFixtures.duel(piker, poked)
	piker.current_ap = 6
	var pike_row: TraitData = TestFixtures.weapon_row("Pike|Pike Rapidity")
	TestFixtures.place(pike_state, poked, Vector2i(7, 4))
	var pike_far := PerkValuation.action_score(piker, pike_row, poked, pike_state)
	TestFixtures.place(pike_state, poked, Vector2i(5, 4))
	var pike_near := PerkValuation.action_score(piker, pike_row, poked, pike_state)
	var pike_ap: int = piker.current_ap
	var pike_ep: int = ExcessPool.available_ep(piker)
	var pike_lines: Array[String] = PerkActionExecutor.execute_perk_action(piker, pike_row, poked,
		pike_state, 0)
	TestFixtures.check(res, "Pike Rapidity reaches 1 pace only and costs 2 AP and 1 EP",
		not bool(pike_far["ok"]) and bool(pike_near["ok"]) and pike_ap - piker.current_ap == 2
			and pike_ep - ExcessPool.available_ep(piker) == 1 and not pike_lines.is_empty(),
		"AP %d to %d, EP %d" % [pike_ap, piker.current_ap,
			pike_ep - ExcessPool.available_ep(piker)])

	var duelist := _armed("Duelist", "Rapier", "Rapier|Rapier Suave")
	var watched := TestFixtures.sheet_merc("Watched")
	var suave_state := TestFixtures.duel(duelist, watched)
	duelist.current_ap = 6
	var suave_rep: int = duelist.current_rep
	var suave_lines: Array[String] = PerkActionExecutor.execute_perk_action(duelist,
		TestFixtures.weapon_row("Rapier|Rapier Suave"), watched, suave_state, 0)
	TestFixtures.check(res, "Rapier Suave banks its flourish ReP as the temp ReP a turn end clears",
		duelist.temp_rep == duelist.current_rep - suave_rep and not suave_lines.is_empty(),
		"%d ReP, %d temp" % [duelist.current_rep - suave_rep, duelist.temp_rep])


#The action perks that single a target out, chain a swing and bank damage for EP.
static func _case_actions_singles(res: Dictionary) -> void:
	var oppressor := _armed("Oppressor", "Saber", "Saber|Saber Oppress")
	var singled := TestFixtures.sheet_merc("Singled")
	var spared := TestFixtures.sheet_merc("Spared")
	var oppress_foes: Array[MercenaryData] = [singled, spared]
	var oppress_state := _crowd(oppressor, oppress_foes, [Vector2i(5, 4), Vector2i(4, 5)])
	PerkActionExecutor.execute_perk_action(oppressor, TestFixtures.weapon_row("Saber|Saber Oppress"), singled,
		oppress_state, 0)
	var on_target: int = CombatApplicator._attack_perk_enhancements(oppressor, singled, oppress_state)
	var off_target: int = CombatApplicator._attack_perk_enhancements(oppressor, spared, oppress_state)
	TestFixtures.check(res, "Saber Oppress enhances the saber only against the singled out target",
		on_target == 1 and off_target == 0, "+%d then +%d enhanced" % [on_target, off_target])

	var colossus := _armed("Colossus", "Colossal Sword", "Colossal Sword|Colossal Sword Arc")
	var arc_left := TestFixtures.sheet_merc("Arc Left")
	var arc_right := TestFixtures.sheet_merc("Arc Right")
	var arc_foes: Array[MercenaryData] = [arc_left, arc_right]
	var arc_state := _crowd(colossus, arc_foes, [Vector2i(5, 4), Vector2i(5, 5)])
	var arc_size: int = PerkValuation.arc_targets(colossus, arc_state).size()
	var arc_left_hp: int = arc_left.current_hp
	var arc_right_hp: int = arc_right.current_hp
	PerkActionExecutor.execute_perk_action(colossus, TestFixtures.weapon_row("Colossal Sword|Colossal Sword Arc"),
		arc_left, arc_state, 0)
	TestFixtures.check(res, "Colossal Sword Arc deals 1 direct to each of the 2 chained enemies",
		arc_size == 2 and arc_left_hp - arc_left.current_hp == 1
			and arc_right_hp - arc_right.current_hp == 1, "%d target(s)" % arc_size)

	var raider := _armed("Raider", "Great Axe", "Great Axe|Great Axe Rampage")
	var hewn := TestFixtures.sheet_merc("Hewn")
	var rage_state := TestFixtures.duel(raider, hewn)
	raider.current_ap = 6
	var rage_ep: int = ExcessPool.available_ep(raider)
	PerkActionExecutor.execute_perk_action(raider, TestFixtures.weapon_row("Great Axe|Great Axe Rampage"), hewn,
		rage_state, 0)
	var rage_bonus: int = int(raider.active_states.get("rampage_bonus", 0))
	TestFixtures.check(res, "Great Axe Rampage banks 1 damage per EP, caps at 3 and never stacks",
		rage_bonus == 3 and rage_ep - ExcessPool.available_ep(raider) == 3
			and PerkValuation.rampage_ep(raider) == 0,
		"+%d damage for %d EP" % [rage_bonus, rage_ep - ExcessPool.available_ep(raider)])


#The action perks that close the distance and push the target away.
static func _case_actions_charges(res: Dictionary) -> void:
	var charger := _armed("Charger", "Great Axe", "Great Axe|Great Axe Stampede")
	var trampled := TestFixtures.sheet_merc("Trampled")
	var charge_foes: Array[MercenaryData] = [trampled]
	var charge_state := _crowd(charger, charge_foes, [Vector2i(8, 4)])
	var charge_lines: Array[String] = PerkActionExecutor.execute_perk_action(charger,
		TestFixtures.weapon_row("Great Axe|Great Axe Stampede"), trampled, charge_state, 0)
	TestFixtures.check(res, "Great Axe Stampede closes on the target and swings on arrival",
		charge_state.distance_to(charger, trampled) <= 1 and TestFixtures.has_line(charge_lines, "stampedes"),
		" | ".join(charge_lines))

	var bowman := _armed("Bowman", "Greatbow", "Greatbow|Greatbow Overdraw")
	_ranged(bowman, 20, 40, 1)
	var overdrawn := TestFixtures.sheet_merc("Overdrawn")
	var draw_foes: Array[MercenaryData] = [overdrawn]
	var draw_state := _crowd(bowman, draw_foes, [Vector2i(8, 4)])
	bowman.ammo_loaded = 3
	bowman.ammo_loaded_type = "Arrow"
	var push_from: Vector2i = draw_state.get_position(overdrawn)
	var draw_lines: Array[String] = PerkActionExecutor.execute_perk_action(bowman,
		TestFixtures.weapon_row("Greatbow|Greatbow Overdraw"), overdrawn, draw_state, 0)
	var pushed: int = draw_state.get_position(overdrawn).x - push_from.x
	TestFixtures.check(res, "Greatbow Overdraw shoots and pushes the target away, never closer",
		pushed >= 0 and draw_state.get_position(overdrawn).y == push_from.y
			and not draw_lines.is_empty(), "%d pace(s) away" % pushed)


#The action perks that empty a magazine into one target or across several.
static func _case_actions_magazines(res: Dictionary) -> void:
	var gunner := _armed("Gunner", "Artillery", "Artillery|Artillery Burst")
	_ranged(gunner, 20, 40, 6)
	var burst_a := TestFixtures.sheet_merc("Burst A")
	var burst_b := TestFixtures.sheet_merc("Burst B")
	var burst_c := TestFixtures.sheet_merc("Burst C")
	var burst_foes: Array[MercenaryData] = [burst_a, burst_b, burst_c]
	var burst_state := _crowd(gunner, burst_foes,
		[Vector2i(9, 4), Vector2i(9, 5), Vector2i(10, 4)])
	gunner.ammo_loaded = 5
	gunner.ammo_loaded_type = "Bullet"
	gunner.current_rep = 2
	var burst_count: int = PerkValuation.burst_targets(gunner, burst_a, burst_state).size()
	var burst_lines: Array[String] = PerkActionExecutor.execute_perk_action(gunner,
		TestFixtures.weapon_row("Artillery|Artillery Burst"), burst_a, burst_state, 0)
	TestFixtures.check(res, "Artillery Burst takes 3 targets for 2 ReP and one bullet each",
		burst_count == 3 and gunner.current_rep == 0 and gunner.ammo_loaded == 2
			and TestFixtures.has_line(burst_lines, "fires a burst at 3"),
		"%d target(s), %d ammo left" % [burst_count, gunner.ammo_loaded])

	var dumper := _armed("Dumper", "Auto-Rifle", "Auto-Rifle|Auto-Rifle Mag-Dump")
	_ranged(dumper, 0, 0, 20)
	var riddled := TestFixtures.sheet_merc("Riddled")
	var dump_state := TestFixtures.duel(dumper, riddled)
	dumper.current_ap = 6
	dumper.ammo_loaded = 17
	dumper.ammo_loaded_type = "Bullet"
	var riddled_hp: int = riddled.current_hp + riddled.excess_hp
	PerkActionExecutor.execute_perk_action(dumper, TestFixtures.weapon_row("Auto-Rifle|Auto-Rifle Mag-Dump"),
		riddled, dump_state, 0)
	var dumped: int = riddled_hp - (riddled.current_hp + riddled.excess_hp)
	TestFixtures.check(res, "Auto-Rifle Mag-Dump empties 17 rounds for 1 direct damage per 5",
		dumper.ammo_loaded == 0 and dumped == 3, "%d damage" % dumped)

	var wilder := _armed("Wilder", "Auto-Rifle", "Auto-Rifle|Auto-Rifle Wild-Shot")
	_ranged(wilder, 0, 0, 20)
	var strafed := TestFixtures.sheet_merc("Strafed")
	var wild_state := TestFixtures.duel(wilder, strafed)
	wilder.current_ap = 6
	wilder.ammo_loaded = 10
	wilder.ammo_loaded_type = "Bullet"
	var wild_cap: int = PerkValuation.wild_shot_bullets(wilder)
	PerkActionExecutor.execute_perk_action(wilder, TestFixtures.weapon_row("Auto-Rifle|Auto-Rifle Wild-Shot"),
		strafed, wild_state, 0)
	var wild_spent: int = 10 - wilder.ammo_loaded
	wilder.ammo_loaded = 1
	TestFixtures.check(res, "Wild-Shot spends 5 extra bullets at most and none of the last round",
		wild_cap == 5 and wild_spent == 6 and PerkValuation.wild_shot_bullets(wilder) == 0,
		"%d bullet(s) spent" % wild_spent)


#The Auto-Rifle Bully trial and the Mallet Called Shot row the library files as an action.
static func _case_actions_calls(res: Dictionary) -> void:
	var bully_row: TraitData = TestFixtures.weapon_row("Auto-Rifle|Auto-Rifle Bully")
	var bully := _armed("Bully", "Auto-Rifle", "Auto-Rifle|Auto-Rifle Bully")
	_ranged(bully)
	var cowed := TestFixtures.sheet_merc("Cowed")
	var bully_state := TestFixtures.duel(bully, cowed)
	bully.current_ap = 6
	bully.ammo_loaded = 20
	bully.ammo_loaded_type = "Bullet"
	var bully_lines: Array[String] = PerkActionExecutor.execute_perk_action(bully, bully_row, cowed,
		bully_state, 0)
	TestFixtures.check(res, "Auto-Rifle Bully empties 5 rounds into a Wile trial for Terrified",
		bully.ammo_loaded == 15 and TestFixtures.has_line(bully_lines, "empties 5 rounds"),
		" | ".join(bully_lines))

	var caller := _armed("Caller", "Mallet", "Mallet|Mallet Called Shot (Atlas Vertebra)")
	caller.current_ap = 6
	var called_row: TraitData = TestFixtures.weapon_row("Mallet|Mallet Called Shot (Atlas Vertebra)")
	var called_info: Dictionary = PerkValuation.parse_action(called_row) if called_row != null else {}
	TestFixtures.check(res, "the Mallet Called Shot row is filed as an action",
		called_row != null and WeaponArmorPerkLibrary.action_dsl(called_row).begins_with("action:")
			and WeaponArmorPerkLibrary.get_weapon_actions(caller).size() == 1
			and str(called_info.get("effect", "")) == "called_shot",
		called_row.effect_dsl.left(20) if called_row != null else "missing")


#T4b: the Recurve Bow Over-Extend action, the bowstring it snaps and the furlough that restrings it.
static func _case_over_extend(res: Dictionary) -> void:
	var rows := _rows(res, "the Over-Extend action row loads", ["Recurve Bow|Recurve Bow Over-Extend"])
	if rows.is_empty():
		return
	var over_row: TraitData = rows["Recurve Bow|Recurve Bow Over-Extend"]

	var archer := _armed("Archer", "Recurve Bow", "Recurve Bow|Recurve Bow Over-Extend")
	var hammerer := _armed("Hammerer", "Mallet", "Mallet|Mallet Called Shot (Atlas Vertebra)")
	var info: Dictionary = PerkValuation.parse_action(over_row)
	TestFixtures.check(res, "a SPECIAL Over-Extend row and a SPECIAL called shot are both actions",
		WeaponArmorPerkLibrary.get_weapon_actions(archer).has(over_row) and int(info["ap"]) == 2
			and str(info["effect"]) == "attack_extended"
			and WeaponArmorPerkLibrary.get_weapon_actions(hammerer).size() == 1,
		"ap %d, effect %s" % [int(info["ap"]), str(info["effect"])])

	var snapper := _armed("Snapper", "Recurve Bow", "Recurve Bow|Recurve Bow Over-Extend")
	var arrow_types: Array[String] = ["Pierce"]
	_ranged(snapper, 6, 10, 1)
	snapper.equipped_weapon.damage_types_1 = arrow_types
	var template: WeaponData = snapper.equipped_weapon
	var snapped_at := TestFixtures.sheet_merc("Snapped At")
	var snap_foes: Array[MercenaryData] = [snapped_at]
	var snap_state := _crowd(snapper, snap_foes, [Vector2i(8, 4)])
	var snap_lines: Array[String] = []
	PerkActionExecutor._snap_bowstring(snapper, snap_state, snap_lines)
	var own: WeaponData = snapper.equipped_weapon
	TestFixtures.check(res, "a snapped string marks the merc's own copy and leaves the template whole",
		own != template and own.string_snapped and not template.string_snapped
			and own.item_name == template.item_name and own.weapon_type == template.weapon_type
			and own.ranged_extended_range == template.ranged_extended_range
			and own.damage_types_1 == template.damage_types_1
			and TestFixtures.has_line(snap_lines, "bowstring snaps"), " | ".join(snap_lines))

	var gauge := _armed("Gauge", "Recurve Bow", "Recurve Bow|Recurve Bow Over-Extend")
	_ranged(gauge, 6, 10, 1)
	gauge.equipped_weapon.damage_formula_1 = "9d6+30"
	var ranged_at := TestFixtures.sheet_merc("Ranged At")
	var gauge_foes: Array[MercenaryData] = [ranged_at]
	var gauge_state := _crowd(gauge, gauge_foes, [Vector2i(8, 4)])
	gauge.ammo_loaded = 3
	gauge.ammo_loaded_type = "Arrow"
	gauge.equipped_weapon.string_snapped = true
	var while_snapped: bool = bool(PerkValuation.action_score(gauge, over_row, ranged_at,
		gauge_state)["ok"])
	gauge.equipped_weapon.string_snapped = false
	TestFixtures.place(gauge_state, ranged_at, Vector2i(18, 4))
	var too_far: bool = bool(PerkValuation.action_score(gauge, over_row, ranged_at, gauge_state)["ok"])
	TestFixtures.place(gauge_state, ranged_at, Vector2i(8, 4))
	var in_reach: bool = bool(PerkValuation.action_score(gauge, over_row, ranged_at, gauge_state)["ok"])
	TestFixtures.check(res, "Over-Extend is refused while snapped or past the extended range",
		not while_snapped and not too_far and in_reach,
		"snapped %s, far %s, near %s" % [str(while_snapped), str(too_far), str(in_reach)])

	var shooter := _armed("Shooter", "Recurve Bow", "Recurve Bow|Recurve Bow Over-Extend")
	_ranged(shooter, 6, 10, 1)
	shooter.equipped_weapon.damage_formula_1 = "9d6+30"
	var pained := TestFixtures.sheet_merc("Pained")
	var shot_foes: Array[MercenaryData] = [pained]
	var shot_state := _crowd(shooter, shot_foes, [Vector2i(8, 4)])
	pained.stats["pain_limit"] = 4
	pained.current_hp = 30
	pained.excess_hp = 0
	shooter.ammo_loaded = 3
	shooter.ammo_loaded_type = "Arrow"
	var shot_ap: int = shooter.current_ap
	PerkActionExecutor.execute_perk_action(shooter, over_row, pained, shot_state, 0)
	var shot_loss: int = 30 - (pained.current_hp + pained.excess_hp)
	var snapped_now: bool = shooter.equipped_weapon.string_snapped
	TestFixtures.check(res, "Over-Extend lands for the pain limit at least, or snaps the string",
		((shot_loss >= 4 and not snapped_now) or (shot_loss == 0 and snapped_now))
			and shooter.ammo_loaded == 2 and shot_ap - shooter.current_ap == 2,
		"%d damage, snapped %s, %d ammo" % [shot_loss, str(snapped_now), shooter.ammo_loaded])

	var rester := TestFixtures.sheet_merc("Rester")
	rester.equipped_weapon = WeaponData.instance_copy(TestFixtures.weapon("Recurve Bow"))
	rester.equipped_weapon.string_snapped = true
	rester.equipped_weapon.repair_ap_paid = 2
	var rest_detail: Array[String] = []
	RestSystem.restring_weapons(rester, rest_detail)
	TestFixtures.check(res, "a furlough restrings every snapped bow the merc carries",
		not rester.equipped_weapon.string_snapped and rester.equipped_weapon.repair_ap_paid == 0
			and TestFixtures.has_line(rest_detail, "bowstring restrung"), " | ".join(rest_detail))


#T5: the weapon perks that act from the sheet or the swing rather than from a trigger.
static func _case_passives(res: Dictionary) -> void:
	if _rows(res, "the passive weapon perk rows load", ["Rifle|Rifle Crook-Shot"]).is_empty():
		return
	var crook := _armed("Crook", "Rifle", "Rifle|Rifle Crook-Shot")
	var rifle: WeaponData = crook.equipped_weapon
	_ranged(crook, 10, 20)
	rifle.misc_properties.append("Two-Handed")
	var downrange := TestFixtures.sheet_merc("Downrange")
	var crook_state := TestFixtures.duel(crook, downrange)
	var both_hands: int = AttackSystem.compute_attack_flaws(crook, downrange, crook_state)
	var wide: int = int(WeaponArmorPerkLibrary.ranged_ranges(crook, rifle)["extended"])
	crook.offhand_weapon = TestFixtures.weapon("Dagger")
	var one_hand: int = AttackSystem.compute_attack_flaws(crook, downrange, crook_state)
	var narrow: int = int(WeaponArmorPerkLibrary.ranged_ranges(crook, rifle)["extended"])
	TestFixtures.check(res, "Crook-Shot flaws the one-handed rifle and cuts its extended band",
		one_hand == both_hands + 1 and wide == 20 and narrow == 10,
		"+%d flaw, %d to %d paces" % [one_hand - both_hands, wide, narrow])

	var archer := _armed("Archer", "Recurve Bow", "Recurve Bow|Recurve Sky-Shot")
	var flier := TestFixtures.sheet_merc("Flier")
	var sky_state := TestFixtures.duel(archer, flier)
	var grounded: int = CombatApplicator._attack_perk_enhancements(archer, flier, sky_state)
	flier.stats["fly"] = 4
	var airborne: int = CombatApplicator._attack_perk_enhancements(archer, flier, sky_state)
	TestFixtures.check(res, "Sky-Shot enhances the shot only while the target flies",
		grounded == 0 and airborne == 1, "+%d then +%d enhanced" % [grounded, airborne])

	var bludgeoner := _armed("Bludgeoner", "Shotgun", "Shotgun|Shotgun Bludgeon")
	var swing: Dictionary = AttackSystem.melee_makeshift(bludgeoner)
	TestFixtures.check(res, "Shotgun Bludgeon swings the gun for 2 Strike",
		str(swing.get("type", "")) == "Strike" and int(swing.get("amount", 0)) == 2, str(swing))


#The Shotgun Overcharge misfire and the Artillery Suppress splash.
static func _case_passives_shotgun(res: Dictionary) -> void:
	var overcharger := _armed("Overcharger", "Shotgun", "Shotgun|Shotgun Overcharge")
	var shell: WeaponData = overcharger.equipped_weapon
	_ranged(overcharger)
	var bystander := TestFixtures.sheet_merc("Bystander")
	var burn_state := TestFixtures.duel(overcharger, bystander)
	overcharger.inventory.append({"type": "weapon", "data": shell})
	overcharger.active_states["shotgun_overcharged"] = true
	var primed: bool = CombatApplicator._prime_overcharge(overcharger)
	var dice: Array = overcharger.active_states.get("extra_weapon_dice", []) as Array
	var burn_hp: int = overcharger.current_hp
	var burn: Array[String] = CombatApplicator._overcharge_misfire(overcharger, burn_state)
	TestFixtures.check(res, "Overcharge adds 4d4 and a misfire burns and wrecks the gun",
		primed and dice.size() == 4 and burn_hp - overcharger.current_hp == 2
			and TestFixtures.has_line(burn, "explodes"),
		"%d dice, %d damage" % [dice.size(), burn_hp - overcharger.current_hp])

	var cannoneer := _armed("Cannoneer", "Artillery", "Artillery|Artillery Suppress")
	var splashed := TestFixtures.sheet_merc("Splashed")
	var suppress_state := TestFixtures.duel(cannoneer, splashed)
	cannoneer.active_states["suppress_pending"] = true
	var splash_hp: int = splashed.current_hp
	var splash: Array[String] = CombatApplicator.resolve_suppress(cannoneer, splashed, "Pierce",
		suppress_state)
	TestFixtures.check(res, "Suppress deals 1 damage to a neighbour who can take it",
		splash_hp - splashed.current_hp == 1 and not splash.is_empty(), " | ".join(splash))
	cannoneer.active_states["suppress_pending"] = true
	splashed.current_hp = 2
	var floored: Array[String] = CombatApplicator.resolve_suppress(cannoneer, splashed, "Pierce",
		suppress_state)
	TestFixtures.check(res, "Suppress goes for Deposed on a neighbour too hurt to take it",
		splashed.current_hp == 2 and not floored.is_empty(), " | ".join(floored))


#The passives that borrow a perk for a makeshift weapon and refill a chamber for ReP.
static func _case_passives_reload(res: Dictionary) -> void:
	var improviser := _armed("Improviser", "Staff", "Staff|Staff Propulsion")
	var makeshift_row: TraitData = TestFixtures.weapon_row("Basic Makeshift|Makeshift Weapon (Basic)")
	if makeshift_row != null:
		WeaponArmorPerkLibrary.grant_weapon_perk(improviser, makeshift_row, "test")
	var scrapped := TestFixtures.sheet_merc("Scrapped")
	var scrap_state := TestFixtures.duel(improviser, scrapped)
	improviser.equipped_weapon.base_weapon = TestFixtures.weapon("Club (Basic)")
	improviser.current_rep = 2
	var scrap_lines: Array[String] = []
	var picked: String = CombatApplicator._activate_makeshift_perk(improviser, scrap_state,
		scrap_lines)
	TestFixtures.check(res, "a makeshift weapon spends 1 ReP to borrow one owned perk",
		picked == "Staff|Staff Propulsion" and improviser.current_rep == 1
			and WeaponArmorPerkLibrary.get_active_weapon_perks(improviser).size() == 1,
		"%s for %d ReP" % [picked, 2 - improviser.current_rep])

	var blower := _armed("Blower", "Blowgun", "Blowgun|Blowgun Quick Reload")
	_ranged(blower, 0, 0, 1)
	var darted := TestFixtures.sheet_merc("Darted")
	var dart_state := TestFixtures.duel(blower, darted)
	blower.ammo_loaded = 0
	blower.ammo_loaded_type = "Dart"
	blower.ammo_inventory = {"Dart": 3}
	blower.current_rep = 1
	var dart_lines: Array[String] = []
	CombatApplicator._rep_reload_free(blower, dart_state, dart_lines)
	TestFixtures.check(res, "Blowgun Quick Reload pays 1 ReP to refill the chamber",
		blower.ammo_loaded == 1 and blower.current_rep == 0 and not dart_lines.is_empty(),
		" | ".join(dart_lines))


#The passives that reach further with a Pain Response and flank from the next cell.
static func _case_passives_reach(res: Dictionary) -> void:
	var pepper := _armed("Pepper", "Shotgun", "Shotgun|Shotgun Peppering")
	var peppered := TestFixtures.sheet_merc("Peppered")
	peppered.stats["pain_limit"] = 5
	var pepper_state := TestFixtures.duel(pepper, peppered)
	TestFixtures.place(pepper_state, peppered, Vector2i(7, 4))
	var near_lines: Array[String] = []
	CombatApplicator._check_pain_and_dying(pepper, peppered, "Pierce", pepper_state, 1, false,
		"Peppered", false, near_lines)
	var short_reach: bool = peppered.active_states.has("pain_fired")
	pepper.stats["level"] = 20
	var far_lines: Array[String] = []
	CombatApplicator._check_pain_and_dying(pepper, peppered, "Pierce", pepper_state, 1, false,
		"Peppered", false, far_lines)
	TestFixtures.check(res, "Peppering forces a Pain Response at 4 paces only at 20th level",
		not short_reach and peppered.active_states.has("pain_fired"),
		"3 paces: %s then %s" % [str(short_reach), str(peppered.active_states.has("pain_fired"))])

	var saber := _armed("Saber", "Saber", "Saber|Saber Flank")
	var flanked := TestFixtures.sheet_merc("Flanked")
	var flank_state := TestFixtures.duel(saber, flanked)
	var flank_lines: Array[String] = BattleStateUpdater.update_auto_states(flanked, flank_state)
	TestFixtures.check(res, "Saber Flank flanks the creature beside its holder",
		ConstStates.has_state(flanked, ConstStates.FLANKED), " | ".join(flank_lines))


#T6: the gates that sit over the perk action, the reaction EP reserve and the perk spends.
static func _case_decisions(res: Dictionary) -> void:
	var rows := _rows(res, "the decision perk rows load",
		["Saber|Saber Oppress", "Katana|Katana Blur"])
	if rows.is_empty():
		return
	var oppress_row: TraitData = rows["Saber|Saber Oppress"]
	var blur_row: TraitData = rows["Katana|Katana Blur"]

	var chooser := _armed("Chooser", "Saber", "Saber|Saber Oppress")
	var weighed := TestFixtures.sheet_merc("Weighed")
	var choice_state := TestFixtures.duel(chooser, weighed)
	chooser.current_ap = 6
	var scored := PerkValuation.action_score(chooser, oppress_row, weighed, choice_state)
	var rich: Dictionary = {"score_per_ap": 99.0, "ok": true, "ap": 1}
	var poor: Dictionary = {"score_per_ap": -1.0, "ok": true, "ap": 1}
	TestFixtures.check(res, "a perk action is taken only while its worth per AP beats a plain attack",
		bool(scored["ok"]) and PerkValuation.beats_attack(chooser, rich, weighed, choice_state)
			and not PerkValuation.beats_attack(chooser, poor, weighed, choice_state),
		"Oppress per_ap %.2f" % float(scored["score_per_ap"]))

	var reactor := _armed("Reactor", "Katana", "Katana|Katana Blur")
	reactor.equipped_weapon.damage_formula_1 = "9d6+30"
	var first := TestFixtures.sheet_merc("First")
	var second := TestFixtures.sheet_merc("Second")
	var pair_foes: Array[MercenaryData] = [first, second]
	var pair_state := _crowd(reactor, pair_foes, [Vector2i(5, 4), Vector2i(6, 4)])
	first.current_hp = 1
	var refused: Dictionary = PerkValuation.reaction_worth(reactor, blur_row,
		{"target": first, "state": pair_state, "cost": 1, "ep_left": 0, "needs_target": true})
	TestFixtures.check(res, "a reaction is refused when the EP it costs would empty the reserve",
		not bool(refused["ok"]) and str(refused["reason"]) == "ep_reserve", str(refused))

	var lone := TestFixtures.sheet_merc("Lone")
	var lone_state := TestFixtures.duel(reactor, lone)
	lone.current_hp = 1
	var allowed: Dictionary = PerkValuation.reaction_worth(reactor, blur_row,
		{"target": lone, "state": lone_state, "cost": 1, "ep_left": 0, "needs_target": true})
	TestFixtures.check(res, "the same reaction is allowed when it takes the last enemy off the field",
		bool(allowed["ok"]), str(allowed))

	var sprayer := _armed("Sprayer", "Auto-Pistol", "Auto-Pistol|Auto-Pistol Spray")
	_ranged(sprayer)
	sprayer.current_ep = maxi(sprayer.current_ep, 8)
	sprayer.ammo_loaded = 1
	sprayer.ammo_loaded_type = "Bullet"
	var spray_thin: int = PerkValuation.spray_bullets(sprayer)
	sprayer.ammo_loaded = 4
	var spray_full: int = PerkValuation.spray_bullets(sprayer)
	TestFixtures.check(res, "Auto-Pistol Spray waits for 2 spare bullets before it spends its EP",
		spray_thin == 0 and spray_full == 3, "%d then %d bullet(s)" % [spray_thin, spray_full])

	var gate := _armed("Aim Gate", "Rifle", "Rifle|Rifle Long-Shot")
	_ranged(gate, 5, 10)
	gate.aim_active = false
	var gate_foe := TestFixtures.sheet_merc("Aim Gate Foe")
	var gate_foes: Array[MercenaryData] = [gate_foe]
	var gate_state := _crowd(gate, gate_foes, [Vector2i(19, 4)])
	var gate_ctx: Dictionary = {"state": gate_state, "attack_base_ap": AutoBattle.ATTACK_BASE_AP}
	var gate_facet := AimPayoffFacet.new()
	gate.current_ap = 6
	gate.excess_ap = 0
	var gate_rich: float = gate_facet.evaluate(gate, gate_ctx)
	gate.current_ap = 4
	var gate_poor: float = gate_facet.evaluate(gate, gate_ctx)
	gate.excess_ap = 1
	var gate_banked: float = gate_facet.evaluate(gate, gate_ctx)
	TestFixtures.check(res, "Aim passes when Aim plus the attack it sets up are affordable",
		is_equal_approx(gate_rich, 1.0), "score %.2f at 6 AP" % gate_rich)
	TestFixtures.check(res, "Aim fails when the follow-up attack is unaffordable this turn",
		is_equal_approx(gate_poor, 0.0), "score %.2f at 4 AP" % gate_poor)
	TestFixtures.check(res, "banked ExAP counts toward the aimed shot",
		is_equal_approx(gate_banked, 1.0), "score %.2f at 4 AP + 1 ExAP" % gate_banked)


#T7: the harness perk load that fills a combatant with perks for the gear it already holds.
static func _case_perk_load(res: Dictionary) -> void:
	var loaded := TestFixtures.sheet_merc("Loaded")
	loaded.equipped_weapon = TestFixtures.weapon("Staff")
	loaded.weapon_drawn = true
	loaded.equipped_armor = _armor("Light")
	var weapon_rows: int = (DataManager.weapon_trait_library.get("Staff", []) as Array).size()
	var armor_rows: int = 0
	for entry: Variant in (DataManager.armor_trait_library.get("Light", []) as Array):
		var td: TraitData = entry as TraitData
		if td != null and td.trait_type == "Perk":
			armor_rows += 1
	var want_weapon: int = mini(2, weapon_rows)
	var want_armor: int = mini(1, armor_rows)
	var details: Array[String] = MercGenerator.load_gear_perks(loaded, 2)
	TestFixtures.check(res, "the harness perk load fills the held weapon and the worn armor",
		weapon_rows > 0 and armor_rows > 0 and loaded.weapon_perks.size() == want_weapon
			and loaded.armor_perks.size() == want_armor
			and details.size() == want_weapon + want_armor,
		"%d weapon and %d armor perk(s)" % [loaded.weapon_perks.size(), loaded.armor_perks.size()])
	var again: Array[String] = MercGenerator.load_gear_perks(loaded, 2)
	TestFixtures.check(res, "a second harness perk load adds nothing to the same merc",
		again.is_empty() and loaded.weapon_perks.size() == want_weapon
			and loaded.armor_perks.size() == want_armor, "%d detail line(s)" % again.size())


static func _case_sheet(res: Dictionary) -> void:
	var rows := _rows(res, "the sheet perk rows load",
		["Staff|Staff Propulsion", "Lightweight Adept"])
	if rows.is_empty():
		return
	var staff: TraitData = rows["Staff|Staff Propulsion"]
	var adept: TraitData = rows["Lightweight Adept"]
	var merc := TestFixtures.sheet_merc("Printed")
	merc.equipped_armor = _armor("Light", 3, 0, 2)
	WeaponArmorPerkLibrary.grant_weapon_perk(merc, staff, "test")
	WeaponArmorPerkLibrary.grant_armor_perk(merc, adept, "test")
	var text: String = MercSheetPrinter.merc_to_string(merc)
	TestFixtures.check(res, "the sheet prints the weapon and armor perk lines",
		text.contains("Weapon Perks: Staff|Staff Propulsion")
			and text.contains("Armor Perks:  Lightweight Adept"), "perk lines")
	var clean: bool = not text.contains("Armor Break:")
	merc.armor_break = 2
	var broken: String = MercSheetPrinter.merc_to_string(merc)
	TestFixtures.check(res, "the sheet prints the Armor Break line",
		clean and broken.contains("Armor Break:  2"), "Armor Break line")


static func _armor_row(trait_name: String) -> TraitData:
	return TestFixtures.trait_row(DataManager.armor_trait_library, trait_name)


#The weapon or armor rows for these names keyed by name, empty once a missing row is reported.
static func _rows(res: Dictionary, label: String, names: Array) -> Dictionary:
	var out: Dictionary = {}
	var missing: Array[String] = []
	for trait_name: String in names:
		var row: TraitData = TestFixtures.weapon_row(trait_name)
		if row == null:
			row = _armor_row(trait_name)
		if row == null:
			missing.append(trait_name)
		out[trait_name] = row
	if not missing.is_empty():
		TestFixtures.check(res, label, false, "%s missing" % ", ".join(missing))
		return {}
	return out


static func _armor(armor_type: String, bonus: int = 0, ep_cost: int = 0, weight: int = 0) -> ArmorData:
	var a := ArmorData.new()
	a.item_name = armor_type + " (test)"
	a.armor_type = armor_type
	a.armor_bonus = bonus
	a.ep_cost = ep_cost
	a.weight = weight
	return a


#A merc holding a drawn weapon of weapon_type and owning one of its library perks.
static func _armed(merc_name: String, weapon_type: String, perk_name: String) -> MercenaryData:
	var m := TestFixtures.sheet_merc(merc_name)
	m.equipped_weapon = TestFixtures.weapon(weapon_type)
	m.weapon_drawn = true
	var row: TraitData = TestFixtures.weapon_row(perk_name)
	if row != null:
		WeaponArmorPerkLibrary.grant_weapon_perk(m, row, "test")
	return m


#Turns the merc's weapon ranged with these range bands and this chamber size.
static func _ranged(merc: MercenaryData, intended: int = 0, extended: int = 0, chamber: int = 0) -> void:
	var w: WeaponData = merc.equipped_weapon
	w.is_ranged = true
	w.ranged_intended_range = intended
	w.ranged_extended_range = extended
	w.chamber = chamber


#A flat field with the merc at (4,4) holding AP and EP, and one enemy per cell given.
static func _crowd(a: MercenaryData, foes: Array[MercenaryData], cells: Array) -> BattleState:
	var team_a: Array[MercenaryData] = [a]
	var state := BattleState.create(team_a, foes, null)
	state.battlefield = TestFixtures.exterior_field()
	TestFixtures.place(state, a, Vector2i(4, 4))
	for i: int in range(foes.size()):
		TestFixtures.place(state, foes[i], cells[i])
	a.weapon_drawn = a.equipped_weapon != null
	a.current_ep = maxi(a.current_ep, 8)
	a.current_ap = maxi(a.current_ap, 6)
	return state

