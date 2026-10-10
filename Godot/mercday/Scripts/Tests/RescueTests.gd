class_name RescueTests
#Run: godot --headless --path . -- --rescue-tests
#The rescue battle: the attach, stealth, the chest, the gate, the exit, the outcome and the contract.


const CREW := "Bandit Leader, Bandit Melee, Bandit Ranged"
const DEEP_D := 3.0
const SEED_TRIES := 12


class RescueFx extends RefCounted:
	var field: BattlefieldArea
	var party: Array[MercenaryData]
	var captive: MercenaryData
	var enemies: Array[MercenaryData]
	var state: BattleState


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	ContractResourceBuilder.build_all()
	var config: ContractConfig = ContractLibrary.config()
	var saved_mode: String = config.rescue_mode
	var saved_level: int = MercGenerator.forced_level
	var saved_logs: bool = EncounterLogger.suppressed
	var saved_policy: String = RescueTactics.policy
	var saved_withdraw: bool = RescueTactics.withdraw_enabled
	var saved_melee: String = RescueTactics.melee_rule
	var saved_careful: bool = RescueTactics.careful
	var saved_caged: bool = RescueTactics.caged_wounded_leave
	var saved_shelter: bool = RescueTactics.shelter_los
	var saved_tune: Dictionary = RescueTune.tune.duplicate()
	config.rescue_mode = "auto"
	MercPool.clear()
	RescueContractBuilder.pending_records.clear()
	CheckSystem.forced_rolls.clear()
	RescueTactics.policy = RescueTactics.POLICY_SMART
	RescueTactics.withdraw_enabled = true
	RescueTactics.melee_rule = RescueTactics.MELEE_SMART
	RescueTactics.careful = true
	RescueTactics.caged_wounded_leave = false
	RescueTactics.shelter_los = false
	RescueTune.reset_tune()
	var combat_fx: RescueFx = _fixture(11, RescueSystem.MODE_COMBAT, 3, 3, 5)
	_case_attach(res, combat_fx)
	_case_combat_attach(res, combat_fx)
	_case_pick_facet(res, combat_fx)
	_case_pick_lock(res, combat_fx)
	_case_pick_def(res)
	_case_kidnap_off(res, combat_fx)
	var stealth_fx: RescueFx = _fixture(21, RescueSystem.MODE_STEALTH, 3, 3, 5)
	_case_stealth_attach(res, stealth_fx)
	_case_exit(res, stealth_fx)
	_case_contest(res, stealth_fx)
	_case_loot_round_trip(res)
	_case_loot_interaction(res)
	_case_free_and_exit(res, _fixture(31, RescueSystem.MODE_STEALTH, 3, 3, 5))
	_case_end_combat(res, _fixture(41, RescueSystem.MODE_COMBAT, 3, 3, 5))
	_case_end_dead(res, _fixture(51, RescueSystem.MODE_STEALTH, 3, 3, 5))
	_case_forced_block(res)
	await _case_full_combat(res)
	await _case_full_stealth(res)
	_case_pool(res)
	_case_builder(res)
	_case_choose_mode(res)
	await _case_contract(res)
	_case_notice_scan(res, _fixture(131, RescueSystem.MODE_STEALTH, 3, 3, 5))
	_case_ally_crossing(res)
	var tac_fx: RescueFx = _fixture(141, RescueSystem.MODE_COMBAT, 3, 3, 5)
	_case_door_reasons(res, tac_fx)
	_case_gate_decision(res, tac_fx)
	_case_escort(res, tac_fx)
	_case_order(res, tac_fx)
	var post_fx: RescueFx = _fixture(151, RescueSystem.MODE_COMBAT, 3, 2, 5)
	_case_postures(res, post_fx)
	_case_captive_postures(res, post_fx)
	_case_shelter_v2(res, _fixture(181, RescueSystem.MODE_COMBAT, 3, 2, 5))
	_case_redirect(res, post_fx)
	_case_leaving(res, post_fx)
	_case_battle_continues(res, _fixture(161, RescueSystem.MODE_COMBAT, 2, 2, 5))
	_case_withdrew(res, _fixture(171, RescueSystem.MODE_COMBAT, 2, 2, 5))
	_case_blocked_decision(res)
	_case_blocked_walk(res, _fixture(191, RescueSystem.MODE_STEALTH, 3, 3, 5))
	_case_ambush_abort(res, _fixture(201, RescueSystem.MODE_STEALTH, 3, 3, 5))
	_case_untargetable(res, _fixture(211, RescueSystem.MODE_COMBAT, 3, 2, 5))
	_case_tune(res, _fixture(221, RescueSystem.MODE_COMBAT, 3, 3, 5))
	MercPool.clear()
	RescueContractBuilder.pending_records.clear()
	CheckSystem.forced_rolls.clear()
	MercGenerator.forced_level = saved_level
	EncounterLogger.suppressed = saved_logs
	config.rescue_mode = saved_mode
	RescueTactics.policy = saved_policy
	RescueTactics.withdraw_enabled = saved_withdraw
	RescueTactics.melee_rule = saved_melee
	RescueTactics.careful = saved_careful
	RescueTactics.caged_wounded_leave = saved_caged
	RescueTactics.shelter_los = saved_shelter
	RescueTune.tune = saved_tune
	randomize()
	return TestFixtures.summarize(res, "RESCUE")


static func leveled_party(level: int, n: int, start: int) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	MercGenerator.forced_level = level
	for i: int in range(n):
		var merc: MercenaryData = MercGenerator.generate(start + i)
		if merc != null:
			out.append(merc)
	MercGenerator.forced_level = -1
	return out


static func _enemies(n: int, level: int, party: Array[MercenaryData]) -> Array[MercenaryData]:
	var req := OpponentRequest.new()
	req.source = CREW
	req.count = n
	req.fixed_level = level
	req.party = party
	req.difficulty = DEEP_D
	req.tag = RescueSystem.EVENT_NAME
	var out: Array[MercenaryData] = []
	out.assign(OpponentGenerator.generate(req))
	return out


#The first seeded dungeon of this Difficulty that carries a cell block; null when none does.
static func _dungeon(seed_i: int, d: float, size_b: int) -> BattlefieldArea:
	for step: int in range(SEED_TRIES):
		var field: BattlefieldArea = _dungeon_field(seed_i + step, d, size_b)
		if field != null and not _cell_rooms(field).is_empty():
			return field
	return null


static func _dungeon_field(seed_i: int, d: float, size_b: int, min_blocks: int = 0) -> BattlefieldArea:
	seed(seed_i)
	var ctx := GenerationContext.new()
	ctx.difficulty = d
	ctx.team_size_a = 5
	ctx.team_size_b = size_b
	ctx.min_cell_blocks = min_blocks
	return BattlefieldArea.generate_random(null, ctx, "Dungeon")


static func _cell_rooms(field: BattlefieldArea) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if field == null:
		return out
	for entry: Dictionary in field.interior_rooms:
		if String(entry.get("name", "")) == DungeonGenerator.CELL_ROW:
			out.append(entry)
	return out


static func rescue_state(party: Array[MercenaryData], captive: MercenaryData,
		enemies: Array[MercenaryData], field: BattlefieldArea, mode: String,
		d: float = DEEP_D) -> BattleState:
	var side_a: Array[MercenaryData] = []
	side_a.assign(party)
	side_a.append(captive)
	var side_b: Array[MercenaryData] = []
	side_b.assign(enemies)
	var state: BattleState = BattleState.create(side_a, side_b, field)
	RescueSetup.attach(state, captive, mode, d)
	return state


#One attached rescue battle; null when no dungeon has a cell.
static func _fixture(seed_i: int, mode: String, party_n: int, enemy_n: int, level: int) -> RescueFx:
	TestFixtures.reset_generator_rolls()
	var field: BattlefieldArea = _dungeon(seed_i, DEEP_D, enemy_n)
	if field == null:
		return null
	var party: Array[MercenaryData] = leveled_party(level, party_n, 0)
	var held: Array[MercenaryData] = leveled_party(level, 1, party_n)
	var foes: Array[MercenaryData] = _enemies(enemy_n, level, party)
	if party.size() < party_n or held.is_empty() or foes.is_empty():
		return null
	var fx := RescueFx.new()
	fx.field = field
	fx.party = party
	fx.captive = held[0]
	fx.enemies = foes
	fx.state = rescue_state(party, held[0], foes, field, mode)
	return fx


static func _missing(res: Dictionary, label: String) -> void:
	TestFixtures.check(res, label, false, "no dungeon fixture with a cell block")


#False when the case fixture did not build, with the one failed check that says so already recorded.
static func _has_fx(res: Dictionary, fx: RescueFx, label: String) -> bool:
	if fx == null:
		_missing(res, label)
		return false
	return true


#A free, walkable neighbour of cell that lies outside rect; NO_CELL when the ring is full.
static func _free_neighbour(field: BattlefieldArea, state: BattleState, cell: Vector3i,
		rect: Rect2i) -> Vector3i:
	for d: Vector2i in PathCost.DIRS8:
		var pos := Vector2i(cell.x + d.x, cell.y + d.y)
		if rect.has_point(pos):
			continue
		if not field.has_walkable_surface(pos, cell.z):
			continue
		if not field.get_obs(pos, cell.z).is_empty():
			continue
		if state.is_position_occupied(pos, null, cell.z):
			continue
		return Vector3i(pos.x, pos.y, cell.z)
	return PathTargeter.NO_CELL


#Forces the stealth contest stats so one side of a Grace against Notice roll cannot lose.
static func _stat_block(merc: MercenaryData, dex: int, cog: int, luck: float) -> void:
	merc.stats["dexterity"] = dex
	merc.stats["cognition"] = cog
	merc.stats["luck"] = luck
	merc.stats["base_success_chance"] = 0.0
	merc.stats["reroll"] = 0.0
	merc.circumstance_flags = {}


static func _geared_merc(start: int) -> MercenaryData:
	var last: MercenaryData = null
	for i: int in range(8):
		var mercs: Array[MercenaryData] = leveled_party(5, 1, start + i)
		if mercs.is_empty():
			continue
		last = mercs[0]
		var weapon: WeaponData = last.equipped_weapon
		if weapon != null and not weapon.is_virtual and last.equipped_armor != null:
			return last
	return last


#True when the merc holds no weapon, armor, ammunition or items.
static func _is_bare(merc: MercenaryData) -> bool:
	return (merc.equipped_weapon == null or merc.equipped_weapon.is_virtual) \
		and merc.equipped_armor == null and merc.ammo_inventory.is_empty() \
		and merc.inventory.is_empty()


#The idle roles that are still set.
static func _idle_roles(roles: Dictionary) -> int:
	var total: int = 0
	for key: Variant in roles:
		if String(roles[key]) != "":
			total += 1
	return total


static func _loaded_chests(field: BattlefieldArea) -> int:
	var total: int = 0
	for chest: Dictionary in ChestLoot.chests(field):
		if not ChestLoot.is_empty(chest):
			total += 1
	return total


#Runs the battle to its end with the encounter log off.
static func _quiet_battle(state: BattleState) -> void:
	var saved: bool = EncounterLogger.suppressed
	EncounterLogger.suppressed = true
	await AutoBattle.run_battle(state, Callable(), "Rescue")
	EncounterLogger.suppressed = saved


static func _holds_weapon(merc: MercenaryData, weapon: WeaponData) -> bool:
	if weapon == null:
		return false
	if merc.equipped_weapon == weapon or merc.offhand_weapon == weapon:
		return true
	for entry: Dictionary in merc.inventory:
		if entry.get("type", "") == "weapon" and entry.get("data", null) == weapon:
			return true
	return false


static func _weapon_count(merc: MercenaryData) -> int:
	var total: int = 0
	if merc.equipped_weapon != null and not merc.equipped_weapon.is_virtual:
		total += 1
	if merc.offhand_weapon != null:
		total += 1
	for entry: Dictionary in merc.inventory:
		if entry.get("type", "") == "weapon":
			total += 1
	return total


static func _entries_of(entries: Array, kind: String) -> int:
	var total: int = 0
	for entry: Dictionary in entries:
		if String(entry.get("type", "")) == kind:
			total += 1
	return total


static func _line_with(lines: Array[String], prefix: String) -> bool:
	for line: String in lines:
		if line.begins_with(prefix):
			return true
	return false


static func _line_holding(lines: Array[String], text: String) -> bool:
	for line: String in lines:
		if line.contains(text):
			return true
	return false


#Unlocks the gate, stands the picker beside it and lets the rescue turn open the cell.
static func free_captive(fx: RescueFx) -> bool:
	var state: BattleState = fx.state
	var gate_cell: Vector3i = state.rescue.get("gate_cell", PathTargeter.NO_CELL)
	var picker: MercenaryData = state.rescue.get("picker", null)
	if picker == null or gate_cell == PathTargeter.NO_CELL:
		return false
	var gate: Dictionary = state.rescue.get("gate_obs", {})
	DungeonLocks.unlock(gate)
	var rect: Rect2i = state.rescue["cell_rect"]
	var spot: Vector3i = _free_neighbour(fx.field, state, gate_cell, rect)
	if spot == PathTargeter.NO_CELL:
		return false
	state.set_pos3(picker, spot)
	state.start_of_turn(picker)
	var lines: Array[String] = []
	RescueSystem.start_of_turn(picker, state, lines)
	RescueSystem.run_turn(picker, state, lines, 0)
	return bool(state.rescue.get("freed", false))


static func _case_attach(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the attach case builds a dungeon"):
		return
	var state: BattleState = fx.state
	var captive: MercenaryData = fx.captive
	var rescue: Dictionary = state.rescue
	TestFixtures.check(res, "attach fills the rescue record", not rescue.is_empty()
		and RescueSystem.is_active(state), "rescue keys %d" % rescue.size())
	if rescue.is_empty():
		return
	var team0: Array = state.teams[0]
	TestFixtures.check(res, "the caged captive leaves the team and the queue",
		not team0.has(captive) and not state.turn_queue.has(captive),
		"team %s queue %s" % [str(team0.has(captive)), str(state.turn_queue.has(captive))])
	var rect: Rect2i = rescue["cell_rect"]
	var pos: Vector3i = state.pos3(captive)
	TestFixtures.check(res, "the captive stands inside a cell",
		rect.has_point(Vector2i(pos.x, pos.y)) and pos.z == int(rescue["cell_floor"]),
		"cell %s captive (%d,%d) F%d" % [str(rect), pos.x, pos.y, pos.z])
	var gate: Dictionary = rescue["gate_obs"]
	TestFixtures.check(res, "the gate is a locked bar door",
		not gate.is_empty() and DungeonLocks.has_bars(gate) and DungeonLocks.is_locked(gate),
		"gate %s locked %s" % [str(not gate.is_empty()), str(DungeonLocks.is_locked(gate))])
	var chest: Dictionary = rescue["chest_obs"]
	var entries: Array = ChestLoot.entries(chest)
	TestFixtures.check(res, "the captive's gear waits in a chest",
		ChestLoot.is_chest(chest) and not entries.is_empty(),
		"chest %s entries %d" % [str(ChestLoot.is_chest(chest)), entries.size()])
	var bare: bool = _is_bare(captive)
	TestFixtures.check(res, "the captive carries nothing", bare,
		"weapon %s armor %s ammo %d items %d" % [
			str(captive.equipped_weapon != null), str(captive.equipped_armor != null),
			captive.ammo_inventory.size(), captive.inventory.size()])
	var lines: Array[String] = state.pre_battle_lines
	TestFixtures.check(res, "the attach reports the cell, the gate and the exit",
		_line_with(lines, "RESCUE:") and _line_with(lines, "CAPTIVE:")
		and _line_with(lines, "GATE:") and _line_with(lines, "EXIT:"),
		"%d pre battle line(s)" % lines.size())


static func _case_combat_attach(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the combat attach case builds a dungeon"):
		return
	var state: BattleState = fx.state
	var party: Array[MercenaryData] = fx.party
	var hidden: int = 0
	for merc: MercenaryData in party:
		if ConstStates.has_state(merc, RescueSystem.STATE_HIDDEN):
			hidden += 1
	if ConstStates.has_state(fx.captive, RescueSystem.STATE_HIDDEN):
		hidden += 1
	TestFixtures.check(res, "a combat rescue hides nobody", hidden == 0, "%d hidden" % hidden)
	var roles: Dictionary = state.rescue.get("roles", {})
	var idle: int = _idle_roles(roles)
	TestFixtures.check(res, "a combat rescue leaves the enemies to the normal AI", idle == 0,
		"%d idle role(s)" % idle)
	var picker: MercenaryData = state.rescue.get("picker", null)
	TestFixtures.check(res, "a combat rescue names a picker from the party",
		picker != null and party.has(picker),
		"picker %s" % ("none" if picker == null else picker.merc_name))


static func _case_stealth_attach(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the stealth attach case builds a dungeon"):
		return
	var state: BattleState = fx.state
	var party: Array[MercenaryData] = fx.party
	var enemies: Array[MercenaryData] = fx.enemies
	var seen: int = 0
	for merc: MercenaryData in party:
		if not ConstStates.has_state(merc, RescueSystem.STATE_HIDDEN):
			seen += 1
	TestFixtures.check(res, "a stealth rescue hides the whole party", seen == 0,
		"%d merc(s) unhidden" % seen)
	TestFixtures.check(res, "a stealth rescue hides the captive",
		ConstStates.has_state(fx.captive, RescueSystem.STATE_HIDDEN), "captive unhidden")
	var roles: Dictionary = state.rescue.get("roles", {})
	var missing: int = 0
	for enemy: MercenaryData in enemies:
		if String(roles.get(enemy, "")) == "":
			missing += 1
	TestFixtures.check(res, "every enemy takes an idle role", missing == 0,
		"%d of %d without a role" % [missing, enemies.size()])
	var guard: MercenaryData = null
	for enemy: MercenaryData in enemies:
		if String(roles.get(enemy, "")) == "guard":
			guard = enemy
			break
	var gate_cell: Vector3i = state.rescue.get("gate_cell", PathTargeter.NO_CELL)
	var rect: Rect2i = state.rescue["cell_rect"]
	var placed: bool = false
	if guard != null and gate_cell != PathTargeter.NO_CELL:
		var pos: Vector3i = state.pos3(guard)
		placed = pos.z == gate_cell.z and not rect.has_point(Vector2i(pos.x, pos.y)) \
			and maxi(absi(pos.x - gate_cell.x), absi(pos.y - gate_cell.y)) <= 2
	TestFixtures.check(res, "the gate guard waits outside the cell", placed,
		"guard %s" % ("none" if guard == null else guard.merc_name))
	var picker: MercenaryData = state.rescue.get("picker", null)
	TestFixtures.check(res, "a stealth rescue names a picker from the party",
		picker != null and party.has(picker),
		"picker %s" % ("none" if picker == null else picker.merc_name))


static func _case_pick_facet(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the gate facet case builds a dungeon"):
		return
	var state: BattleState = fx.state
	var field: BattlefieldArea = fx.field
	var party: Array[MercenaryData] = fx.party
	var gate: Dictionary = state.rescue.get("gate_obs", {})
	var gate_cell: Vector3i = state.rescue.get("gate_cell", PathTargeter.NO_CELL)
	var rect: Rect2i = state.rescue["cell_rect"]
	var spot: Vector3i = _free_neighbour(field, state, gate_cell, rect)
	if gate.is_empty() or gate_cell == PathTargeter.NO_CELL or spot == PathTargeter.NO_CELL \
			or party.size() < 2:
		_missing(res, "the gate facet case finds a gate")
		return
	var entrance: Vector2i = field.entrance_cells[0] if not field.entrance_cells.is_empty() \
		else Vector2i(0, 0)
	var away := Vector3i(entrance.x, entrance.y, 0)
	var home_0: Vector3i = state.pos3(party[0])
	var home_1: Vector3i = state.pos3(party[1])
	_stat_block(party[0], 6, 0, 0.0)
	for i: int in range(1, party.size()):
		_stat_block(party[i], 1, 0, 0.0)
	state.set_pos3(party[0], spot)
	state.rescue["gate_go"] = true
	TestFixtures.check(res, "the Interact facet aims at the gate beside the best hand",
		InteractTargetFacet.find_target(party[0], state) == gate_cell,
		"target %s gate %s" % [str(InteractTargetFacet.find_target(party[0], state)),
			str(gate_cell)])
	state.set_pos3(party[0], away)
	state.set_pos3(party[1], spot)
	TestFixtures.check(res, "a worse hand leaves an unjammed lock alone",
		not RescueSystem.worth_picking(party[1], state, gate)
		and InteractTargetFacet.find_target(party[1], state) != gate_cell,
		"worth %s target %s" % [str(RescueSystem.worth_picking(party[1], state, gate)),
			str(InteractTargetFacet.find_target(party[1], state))])
	gate[DungeonLocks.FAILS_KEY] = DungeonLocks.MAX_JAM
	TestFixtures.check(res, "a jammed lock is worth any hand",
		RescueSystem.worth_picking(party[1], state, gate),
		"fails %d" % DungeonLocks.lock_fails(gate))
	gate[DungeonLocks.FAILS_KEY] = 0
	state.set_pos3(party[1], home_1)
	var enemy: MercenaryData = fx.enemies[0]
	var enemy_home: Vector3i = state.pos3(enemy)
	state.set_pos3(enemy, spot)
	TestFixtures.check(res, "a captor beside the gate never targets it",
		InteractTargetFacet.find_target(enemy, state) != gate_cell
		and RescueSystem.gate_target(enemy, state) == PathTargeter.NO_CELL,
		"target %s gate %s" % [str(InteractTargetFacet.find_target(enemy, state)), str(gate_cell)])
	state.set_pos3(enemy, enemy_home)
	state.rescue["gate_go"] = false
	var named: bool = false
	var default_set: MercActionSet = load("res://Scripts/Actions/Resources/DefaultActionSet.tres")
	for action: ActionData in default_set.actions:
		if action != null and action.action_name == "Pick Lock":
			named = true
	TestFixtures.check(res, "the action set no longer carries Pick Lock", not named,
		"a Pick Lock action is still loaded")
	var lead: MercenaryData = RescueSystem.picker(state)
	TestFixtures.check(res, "the rescue keeps one named picker",
		lead != null and RescueSystem.picker(state) == lead,
		"picker %s" % ("none" if lead == null else lead.merc_name))
	if lead == null:
		state.set_pos3(party[0], home_0)
		return
	var hp: int = lead.current_hp
	lead.current_hp = 0
	lead.is_dead = true
	var heir: MercenaryData = RescueSystem.picker(state)
	TestFixtures.check(res, "a dead picker hands the job to a living merc",
		heir != null and heir != lead and BattleState._is_alive(heir),
		"heir %s" % ("none" if heir == null else heir.merc_name))
	lead.current_hp = hp
	lead.is_dead = false
	state.set_pos3(party[0], home_0)


static func _case_pick_lock(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the pick lock case builds a dungeon"):
		return
	var state: BattleState = fx.state
	var gate: Dictionary = state.rescue.get("gate_obs", {})
	var gate_cell: Vector3i = state.rescue.get("gate_cell", PathTargeter.NO_CELL)
	var rect: Rect2i = state.rescue["cell_rect"]
	var merc: MercenaryData = fx.party[0]
	var spot: Vector3i = _free_neighbour(fx.field, state, gate_cell, rect)
	if gate.is_empty() or spot == PathTargeter.NO_CELL:
		_missing(res, "the pick lock case finds a gate")
		return
	var found: int = DungeonLocks.lock_difficulty(gate)
	var merc_home: Vector3i = state.pos3(merc)
	state.set_pos3(merc, spot)
	_stat_block(merc, 3, 0, 0.0)
	gate[DungeonLocks.DIFFICULTY_KEY] = 0
	state.start_of_turn(merc)
	var ap_before: int = merc.current_ap
	var lines: Array[String] = []
	var picked: bool = InteractionSystem.perform(merc, gate, gate_cell, state, lines)
	TestFixtures.check(res, "an Interact opens a lock of no difficulty",
		picked and not DungeonLocks.is_locked(gate) and OpenCloseState.is_open(gate),
		"picked %s locked %s open %s" % [str(picked), str(DungeonLocks.is_locked(gate)),
			str(OpenCloseState.is_open(gate))])
	TestFixtures.check(res, "picking a lock costs the merc AP", merc.current_ap < ap_before,
		"AP %d of %d" % [merc.current_ap, ap_before])
	gate[DungeonLocks.LOCKED_KEY] = true
	gate[DungeonLocks.DIFFICULTY_KEY] = 99
	gate[DungeonLocks.FAILS_KEY] = 0
	OpenCloseState.set_open(gate, false)
	var third: int = 0
	for attempt: int in range(4):
		state.start_of_turn(merc)
		InteractionSystem.perform(merc, gate, gate_cell, state, lines)
		if attempt == 2:
			third = DungeonLocks.lock_difficulty(gate)
	TestFixtures.check(res, "each failed pick jams the lock one step",
		third == 102 and DungeonLocks.is_locked(gate),
		"difficulty %d locked %s" % [third, str(DungeonLocks.is_locked(gate))])
	TestFixtures.check(res, "the jam stops at three but the failures still count",
		DungeonLocks.lock_difficulty(gate) == 102 and DungeonLocks.lock_fails(gate) == 4,
		"difficulty %d fails %d" % [DungeonLocks.lock_difficulty(gate),
			DungeonLocks.lock_fails(gate)])
	TestFixtures.check(res, "the rescue counts the attempts",
		int(state.rescue.get("picks", 0)) == 5 and int(state.rescue.get("pick_fails", 0)) == 4,
		"picks %d fails %d" % [int(state.rescue.get("picks", 0)),
			int(state.rescue.get("pick_fails", 0))])
	var picks_before: int = int(state.rescue.get("picks", 0))
	var enemy: MercenaryData = fx.enemies[0]
	var enemy_home: Vector3i = state.pos3(enemy)
	state.set_pos3(merc, merc_home)
	state.set_pos3(enemy, spot)
	state.start_of_turn(enemy)
	var foe_lines: Array[String] = []
	var keyed: bool = InteractionSystem.perform(enemy, gate, gate_cell, state, foe_lines)
	TestFixtures.check(res, "a captor's key never opens the captive's gate",
		not keyed and DungeonLocks.is_locked(gate)
		and int(state.rescue.get("picks", 0)) == picks_before
		and _line_holding(foe_lines, "locked"),
		"opened %s picks %d of %d lines %d" % [str(keyed), int(state.rescue.get("picks", 0)),
			picks_before, foe_lines.size()])
	state.set_pos3(enemy, enemy_home)
	gate[DungeonLocks.LOCKED_KEY] = true
	gate[DungeonLocks.DIFFICULTY_KEY] = found
	gate[DungeonLocks.FAILS_KEY] = 0
	gate[DungeonLocks.KEEP_SHUT_KEY] = true
	OpenCloseState.set_open(gate, false)


#The pick check reads the Locksmith's tool and the Espionage knowledges.
static func _case_pick_def(res: Dictionary) -> void:
	var mercs: Array[MercenaryData] = leveled_party(5, 1, 110)
	if mercs.is_empty():
		TestFixtures.check(res, "the pick def case generates a merc", false, "no merc generated")
		return
	var merc: MercenaryData = mercs[0]
	_stat_block(merc, 3, 0, 0.0)
	merc.tools.clear()
	merc.knowledges.clear()
	var bare: float = CheckSystem.expected_successes(merc, DungeonLocks.pick_def())
	merc.tools.append(ContractFixtures.utility("Locksmith's"))
	var tooled: float = CheckSystem.expected_successes(merc, DungeonLocks.pick_def())
	TestFixtures.check(res, "the Locksmith's tools help the pick", tooled > bare,
		"bare %.4f tooled %.4f" % [bare, tooled])
	merc.knowledges.append(ContractFixtures.utility("Forensics"))
	var learned: float = CheckSystem.expected_successes(merc, DungeonLocks.pick_def())
	TestFixtures.check(res, "an Espionage knowledge helps the pick", learned > tooled,
		"tooled %.4f learned %.4f" % [tooled, learned])
	var names: Array = DungeonLocks.pick_def().get("knowledges", []) as Array
	TestFixtures.check(res, "the pick def names every Espionage knowledge",
		names.has("Reconnaissance") and names.has("Forensics"),
		"%d knowledge(s)" % names.size())
	TestFixtures.check(res, "a hopeless lock leaves almost no chance",
		DungeonLocks.pick_chance_at(merc, 99) < 0.05,
		"chance %.4f" % DungeonLocks.pick_chance_at(merc, 99))


static func _case_kidnap_off(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the kidnap case builds a dungeon"):
		return
	var saved: bool = KidnapSystem.enabled
	KidnapSystem.enabled = true
	var lines: Array[String] = []
	var took: bool = KidnapSystem.start_of_turn(fx.enemies[0], fx.state, lines)
	KidnapSystem.enabled = saved
	TestFixtures.check(res, "a rescue battle never runs a kidnap", not took,
		"start_of_turn %s" % str(took))


static func _case_exit(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the exit case builds a dungeon"):
		return
	var state: BattleState = fx.state
	var party: Array[MercenaryData] = fx.party
	var merc: MercenaryData = party[party.size() - 1]
	var exit_cell: Vector3i = state.rescue.get("exit_cell", PathTargeter.NO_CELL)
	if exit_cell == PathTargeter.NO_CELL:
		_missing(res, "the exit case finds an exit")
		return
	state.set_pos3(merc, exit_cell)
	var lines: Array[String] = []
	var early: bool = RescueSystem.start_of_turn(merc, state, lines)
	TestFixtures.check(res, "nobody leaves before the captive is freed",
		not merc.off_field and not state.exited.has(merc),
		"took %s off field %s" % [str(early), str(merc.off_field)])
	state.rescue["freed"] = true
	var took: bool = RescueSystem.start_of_turn(merc, state, lines)
	state.rescue["freed"] = false
	TestFixtures.check(res, "the rescue takes the turn of a merc on the exit", took,
		"start_of_turn false")
	TestFixtures.check(res, "a merc on the exit leaves the dungeon once the captive is freed",
		state.exited.has(merc) and merc.off_field,
		"exited %s off field %s" % [str(state.exited.has(merc)), str(merc.off_field)])


static func _case_contest(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the stealth contest case builds a dungeon"):
		return
	var state: BattleState = fx.state
	var party: Array[MercenaryData] = fx.party
	var enemies: Array[MercenaryData] = fx.enemies
	var roles: Dictionary = state.rescue.get("roles", {})
	var enemy: MercenaryData = enemies[0]
	for foe: MercenaryData in enemies:
		if String(roles.get(foe, "")) == "guard":
			enemy = foe
			break
	var hidden: MercenaryData = party[0]
	var spot: Vector3i = _free_neighbour(fx.field, state, state.pos3(hidden), Rect2i())
	if spot == PathTargeter.NO_CELL:
		_missing(res, "the stealth contest case seats an enemy")
		return
	state.set_pos3(enemy, spot)
	for merc: MercenaryData in party:
		_stat_block(merc, 20, 0, 100.0)
	_stat_block(enemy, 0, 0, 0.0)
	var lines: Array[String] = []
	state.start_of_turn(enemy)
	RescueSystem.run_turn(enemy, state, lines, 0)
	TestFixtures.check(res, "a graceful merc stays unseen",
		ConstStates.has_state(hidden, RescueSystem.STATE_HIDDEN)
		and not bool(state.rescue.get("alarm", false)),
		"hidden %s alarm %s" % [str(ConstStates.has_state(hidden, RescueSystem.STATE_HIDDEN)),
			str(state.rescue.get("alarm", false))])
	for merc: MercenaryData in party:
		_stat_block(merc, 1, 0, 0.0)
	_stat_block(enemy, 0, 20, 100.0)
	state.start_of_turn(enemy)
	RescueSystem.run_turn(enemy, state, lines, 0)
	TestFixtures.check(res, "a watchful guard spots a clumsy merc",
		bool(state.rescue.get("alarm", false)),
		"alarm round %d" % int(state.rescue.get("alarm_round", -1)))
	var still: int = 0
	for merc: MercenaryData in party:
		if ConstStates.has_state(merc, RescueSystem.STATE_HIDDEN):
			still += 1
	if ConstStates.has_state(fx.captive, RescueSystem.STATE_HIDDEN):
		still += 1
	TestFixtures.check(res, "the alarm strips Hidden from everybody", still == 0,
		"%d still hidden" % still)
	var idle: int = _idle_roles(roles)
	TestFixtures.check(res, "the alarm clears every idle role", idle == 0,
		"%d idle role(s)" % idle)
	state.start_of_turn(enemy)
	TestFixtures.check(res, "a roused enemy takes its own turn",
		not RescueSystem.start_of_turn(enemy, state, lines), "start_of_turn true")


static func _case_loot_round_trip(res: Dictionary) -> void:
	var merc: MercenaryData = _geared_merc(60)
	if merc == null:
		TestFixtures.check(res, "the loot case generates a merc", false, "no merc generated")
		return
	var weapon: WeaponData = merc.equipped_weapon
	var armor: ArmorData = merc.equipped_armor
	var ammo_before: Dictionary = merc.ammo_inventory.duplicate(true)
	var loaded_before: int = merc.ammo_loaded
	var weapons_before: int = _weapon_count(merc)
	var entries: Array[Dictionary] = ChestLoot.strip_gear(merc)
	var bare: bool = _is_bare(merc)
	TestFixtures.check(res, "strip_gear leaves the merc with nothing", bare,
		"weapon %s armor %s ammo %d items %d" % [str(merc.equipped_weapon != null),
			str(merc.equipped_armor != null), merc.ammo_inventory.size(), merc.inventory.size()])
	TestFixtures.check(res, "strip_gear lists the held weapon and the worn armor",
		_entries_of(entries, "weapon") == weapons_before
		and _entries_of(entries, "armor") == (1 if armor != null else 0),
		"%d entries, %d weapon(s) of %d, %d armor" % [entries.size(),
			_entries_of(entries, "weapon"), weapons_before, _entries_of(entries, "armor")])
	for entry: Dictionary in entries:
		ChestLoot.restore(entry, merc)
	var ammo_ok: bool = merc.ammo_loaded == loaded_before
	for key: Variant in ammo_before:
		if int(merc.ammo_inventory.get(key, 0)) != int(ammo_before[key]):
			ammo_ok = false
	TestFixtures.check(res, "restore puts the weapon and the ammo back",
		_holds_weapon(merc, weapon) and _weapon_count(merc) == weapons_before and ammo_ok,
		"weapons %d of %d loaded %d of %d" % [_weapon_count(merc), weapons_before,
			merc.ammo_loaded, loaded_before])
	var worn: bool = merc.equipped_armor == armor
	if armor != null:
		for prot: String in armor.protection:
			if not merc.passive_effects.has("protected:" + prot.to_lower()):
				worn = false
	TestFixtures.check(res, "restore wears the armor and its passives again", worn,
		"armor %s" % ("none" if merc.equipped_armor == null else merc.equipped_armor.item_name))


static func _case_loot_interaction(res: Dictionary) -> void:
	var donor: MercenaryData = _geared_merc(70)
	var takers: Array[MercenaryData] = leveled_party(5, 1, 79)
	if donor == null or takers.is_empty():
		TestFixtures.check(res, "the chest case generates mercs", false, "no merc generated")
		return
	var taker: MercenaryData = takers[0]
	ChestLoot.strip_gear(taker)
	var field: BattlefieldArea = TestFixtures.exterior_field()
	var chest: Dictionary = TestFixtures.put(field, Vector3i(5, 5, 0),
		{"data": DataManager.get_obstacle_by_name("Chest"), "height": 1.0})
	if not ChestLoot.is_chest(chest):
		TestFixtures.check(res, "the Chest obstacle row loads", false, "no Chest in Obstacles.tsv")
		return
	for entry: Dictionary in ChestLoot.strip_gear(donor):
		ChestLoot.add(chest, entry)
	var first: Dictionary = ChestLoot.entries(chest)[0] if not ChestLoot.is_empty(chest) else {}
	var count_before: int = ChestLoot.entries(chest).size()
	var side_a: Array[MercenaryData] = [taker]
	var side_b: Array[MercenaryData] = [donor]
	var state: BattleState = BattleState.create(side_a, side_b, null)
	state.battlefield = field
	TestFixtures.place(state, taker, Vector2i(5, 4))
	TestFixtures.place(state, donor, Vector2i(1, 1))
	state.start_of_turn(taker)
	var ap_before: int = taker.current_ap
	var lines: Array[String] = []
	var took: bool = InteractionSystem.perform(taker, chest, Vector3i(5, 5, 0), state, lines)
	TestFixtures.check(res, "one interact takes one entry from the chest",
		took and ChestLoot.entries(chest).size() == count_before - 1,
		"took %s entries %d of %d" % [str(took), ChestLoot.entries(chest).size(), count_before])
	TestFixtures.check(res, "the held weapon is the first thing out of the chest",
		bool(first.get("was_equipped", false))
		and _holds_weapon(taker, first.get("data", null) as WeaponData),
		"first %s equipped %s" % [String(first.get("type", "none")),
			str(first.get("was_equipped", false))])
	TestFixtures.check(res, "looting costs the merc AP", taker.current_ap < ap_before,
		"AP %d of %d" % [taker.current_ap, ap_before])
	while not ChestLoot.is_empty(chest):
		ChestLoot.take(chest, 0)
	state.start_of_turn(taker)
	var ap_empty: int = taker.current_ap
	var again: bool = InteractionSystem.perform(taker, chest, Vector3i(5, 5, 0), state, lines)
	TestFixtures.check(res, "an empty chest costs nothing",
		not again and taker.current_ap == ap_empty,
		"took %s AP %d of %d" % [str(again), taker.current_ap, ap_empty])


static func _case_free_and_exit(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the freeing case builds a dungeon"):
		return
	var state: BattleState = fx.state
	var captive: MercenaryData = fx.captive
	var freed: bool = free_captive(fx)
	TestFixtures.check(res, "the picker opens the cell", freed,
		"freed %s" % str(state.rescue.get("freed", false)))
	var team0: Array = state.teams[0]
	TestFixtures.check(res, "the freed captive rejoins the team and the queue",
		team0.has(captive) and state.turn_queue.has(captive),
		"team %s queue %s" % [str(team0.has(captive)), str(state.turn_queue.has(captive))])
	TestFixtures.check(res, "freeing records the round",
		int(state.rescue.get("freed_round", -1)) == state.round_number,
		"round %d of %d" % [int(state.rescue.get("freed_round", -1)), state.round_number])
	TestFixtures.check(res, "an unfinished rescue suspends the stalemate rule",
		RescueSystem.suspends_stalemate(state), "suspends_stalemate false")
	var exit_cell: Vector3i = state.rescue.get("exit_cell", PathTargeter.NO_CELL)
	if exit_cell == PathTargeter.NO_CELL:
		_missing(res, "the freeing case finds an exit")
		return
	state.set_pos3(captive, exit_cell)
	var lines: Array[String] = []
	RescueSystem.start_of_turn(captive, state, lines)
	RescueOutcome.on_battle_end(state, lines)
	var ro: Dictionary = RescueOutcome.outcome(state)
	TestFixtures.check(res, "a captive who walks out unseen ends a stealth rescue",
		String(ro.get("result", "")) == RescueSystem.RESULT_STEALTH
		and bool(ro.get("success", false)),
		"result %s success %s" % [String(ro.get("result", "")), str(ro.get("success", false))])
	TestFixtures.check(res, "the outcome records the exit",
		bool(ro.get("captive_exited", false)) and int(ro.get("exited", 0)) >= 1,
		"exited %s count %d" % [str(ro.get("captive_exited", false)), int(ro.get("exited", 0))])
	TestFixtures.check(res, "a finished rescue no longer suspends the stalemate rule",
		not RescueSystem.suspends_stalemate(state), "suspends_stalemate true")


static func _case_end_combat(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the cleared dungeon case builds a dungeon"):
		return
	var state: BattleState = fx.state
	var captive: MercenaryData = fx.captive
	var chest: Dictionary = state.rescue.get("chest_obs", {})
	var stripped: int = ChestLoot.entries(chest).size()
	var weapon: WeaponData = null
	var armor: ArmorData = null
	for entry: Dictionary in ChestLoot.entries(chest):
		if String(entry.get("type", "")) == "weapon" and bool(entry.get("was_equipped", false)):
			weapon = entry.get("data", null) as WeaponData
		elif String(entry.get("type", "")) == "armor":
			armor = entry.get("data", null) as ArmorData
	for enemy: MercenaryData in fx.enemies:
		enemy.is_dead = true
		enemy.current_hp = 0
	var lines: Array[String] = []
	RescueOutcome.on_battle_end(state, lines)
	var ro: Dictionary = RescueOutcome.outcome(state)
	TestFixtures.check(res, "a cleared dungeon frees the captive",
		bool(ro.get("freed", false)) and bool(ro.get("enemies_dead", false)),
		"freed %s enemies dead %s" % [str(ro.get("freed", false)),
			str(ro.get("enemies_dead", false))])
	TestFixtures.check(res, "a fought rescue succeeds as a combat rescue",
		bool(ro.get("success", false)) and String(ro.get("result", "")) == RescueSystem.RESULT_COMBAT,
		"result %s success %s" % [String(ro.get("result", "")), str(ro.get("success", false))])
	var restored: bool = _holds_weapon(captive, weapon) or weapon == null
	if armor != null and captive.equipped_armor != armor:
		restored = false
	TestFixtures.check(res, "the captive leaves with its own gear again", restored,
		"weapon %s armor %s of %d entries" % [
			str(captive.equipped_weapon != null), str(captive.equipped_armor != null), stripped])
	var full: int = _loaded_chests(fx.field)
	TestFixtures.check(res, "every chest is emptied at the end", full == 0,
		"%d chest(s) still loaded, %d item(s) restored" % [full, int(ro.get("loot_restored", 0))])


static func _case_end_dead(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the dead captive case builds a dungeon"):
		return
	var state: BattleState = fx.state
	var captive: MercenaryData = fx.captive
	var exit_cell: Vector3i = state.rescue.get("exit_cell", PathTargeter.NO_CELL)
	var walker: MercenaryData = fx.party[0]
	var lines: Array[String] = []
	if exit_cell != PathTargeter.NO_CELL:
		state.rescue["freed"] = true
		state.set_pos3(walker, exit_cell)
		RescueSystem.start_of_turn(walker, state, lines)
	captive.is_dead = true
	captive.current_hp = 0
	RescueOutcome.on_battle_end(state, lines)
	var ro: Dictionary = RescueOutcome.outcome(state)
	TestFixtures.check(res, "a dead captive fails the rescue",
		String(ro.get("result", "")) == RescueSystem.RESULT_FAILED
		and not bool(ro.get("success", false)),
		"result %s success %s" % [String(ro.get("result", "")), str(ro.get("success", false))])
	TestFixtures.check(res, "the outcome reports the captive dead",
		not bool(ro.get("captive_alive", true)), "captive_alive true")
	TestFixtures.check(res, "mercs who left the dungeon come back on the field",
		not walker.off_field, "off field %s" % str(walker.off_field))


static func _case_full_combat(res: Dictionary) -> void:
	var fx: RescueFx = _fixture(61, RescueSystem.MODE_COMBAT, 4, 2, 20)
	if not _has_fx(res, fx, "the combat battle case builds a dungeon"):
		return
	var state: BattleState = fx.state
	var captive: MercenaryData = fx.captive
	for enemy: MercenaryData in fx.enemies:
		enemy.stats["level"] = 1.0
		enemy.current_hp = 1
	await _quiet_battle(state)
	var ro: Dictionary = RescueOutcome.outcome(state)
	TestFixtures.check(res, "a strong party wins a combat rescue",
		bool(ro.get("success", false))
		and String(ro.get("result", "")) == RescueSystem.RESULT_COMBAT,
		"result %s reason %s rounds %d" % [String(ro.get("result", "")), String(ro.get("reason", "")),
			int(ro.get("rounds", 0))])
	TestFixtures.check(res, "the combat rescue ends before the round cap",
		state.round_number < AutoBattle.MAX_ROUNDS,
		"round %d of %d" % [state.round_number, AutoBattle.MAX_ROUNDS])
	TestFixtures.check(res, "the freed captive lives and carries its gear",
		not captive.is_dead and captive.current_hp > 0
		and (captive.equipped_weapon != null or captive.equipped_armor != null),
		"dead %s hp %d weapon %s" % [str(captive.is_dead), captive.current_hp,
			str(captive.equipped_weapon != null)])
	var uses: int = 0
	var bad_key: bool = false
	for merc: MercenaryData in fx.party:
		if merc.is_dead:
			continue
		for key: Variant in merc.action_uses:
			if not (key is String) or String(key) == "":
				bad_key = true
			uses += int(merc.action_uses[key])
	TestFixtures.check(res, "the battle tallies every action the party used",
		uses > 0 and not bad_key,
		"%d use(s) recorded, keys %s" % [uses, "blank or not a String" if bad_key else "named"])


static func _case_full_stealth(res: Dictionary) -> void:
	var fx: RescueFx = _fixture(71, RescueSystem.MODE_STEALTH, 3, 1, 5)
	if not _has_fx(res, fx, "the stealth battle case builds a dungeon"):
		return
	var state: BattleState = fx.state
	var captive: MercenaryData = fx.captive
	for merc: MercenaryData in fx.party:
		_stat_block(merc, 20, 0, 100.0)
	_stat_block(captive, 20, 0, 100.0)
	for enemy: MercenaryData in fx.enemies:
		_stat_block(enemy, 0, 0, 0.0)
	_post_guards(fx)
	await _quiet_battle(state)
	var ro: Dictionary = RescueOutcome.outcome(state)
	TestFixtures.check(res, "an unseen party wins a stealth rescue",
		bool(ro.get("success", false)),
		"result %s reason %s rounds %d" % [String(ro.get("result", "")), String(ro.get("reason", "")),
			int(ro.get("rounds", 0))])
	TestFixtures.check(res, "the stealth rescue ends by an exit or a cleared dungeon",
		bool(ro.get("captive_exited", false)) or bool(ro.get("enemies_dead", false)),
		"exited %s cleared %s" % [str(ro.get("captive_exited", false)),
			str(ro.get("enemies_dead", false))])
	var full: int = _loaded_chests(fx.field)
	TestFixtures.check(res, "no chest keeps the captive's gear", full == 0,
		"%d loaded chest(s)" % full)


#A guard that never notices would plug a one-wide hall for good, so each stands watch beside the chest.
static func _post_guards(fx: RescueFx) -> void:
	var state: BattleState = fx.state
	var chest_cell: Vector3i = state.rescue["chest_cell"]
	if chest_cell == PathTargeter.NO_CELL:
		return
	for enemy: MercenaryData in fx.enemies:
		var spot: Vector3i = _free_neighbour(fx.field, state, chest_cell, Rect2i())
		if spot == PathTargeter.NO_CELL:
			return
		state.set_pos3(enemy, spot)
		(state.rescue["patrol_goals"] as Dictionary).erase(enemy)


static func _case_pool(res: Dictionary) -> void:
	MercPool.clear()
	var held: Array[MercenaryData] = leveled_party(5, 1, 90)
	var gone: Array[MercenaryData] = leveled_party(5, 1, 91)
	if held.is_empty() or gone.is_empty():
		TestFixtures.check(res, "the pool case generates mercs", false, "no merc generated")
		return
	var captive: MercenaryData = held[0]
	var crew: Array[MercenaryData] = _enemies(2, 3, held)
	MercPool.add_captive(captive, "Escort", "Aerdis", "Day 1", crew, CREW)
	MercPool.add(gone[0])
	var record: Dictionary = MercPool.captive_record(captive.merc_uid)
	TestFixtures.check(res, "a captive keeps its captors and its source",
		not record.is_empty() and (record.get("crew", []) as Array).size() == crew.size()
		and String(record.get("crew_source", "")) == CREW,
		"crew %d source %s" % [(record.get("crew", []) as Array).size(),
			String(record.get("crew_source", ""))])
	var kidnapped: int = 0
	var fled: int = 0
	for entry: Dictionary in RescueContractBuilder.candidates():
		if String(entry.get("kind", "")) == RescueContractBuilder.KIND_KIDNAPPED:
			kidnapped += 1
		elif String(entry.get("kind", "")) == RescueContractBuilder.KIND_FLED:
			fled += 1
	TestFixtures.check(res, "the missing list holds both kinds", kidnapped == 1 and fled == 1,
		"kidnapped %d fled %d" % [kidnapped, fled])
	var taken: MercenaryData = MercPool.take_captive(captive.merc_uid)
	TestFixtures.check(res, "a rescued captive leaves the held list",
		taken == captive and MercPool.captive_record(captive.merc_uid).is_empty(),
		"taken %s" % ("none" if taken == null else taken.merc_name))
	MercPool.clear()


static func _case_builder(res: Dictionary) -> void:
	var mercs: Array[MercenaryData] = leveled_party(5, 1, 95)
	if mercs.is_empty():
		TestFixtures.check(res, "the builder case generates a merc", false, "no merc generated")
		return
	var merc: MercenaryData = mercs[0]
	GuildRoster.set_roster(mercs)
	var record: Dictionary = RescueContractBuilder.record_for(merc,
		RescueContractBuilder.KIND_FLED)
	var contract: ContractData = RescueContractBuilder.build(record)
	if contract == null:
		TestFixtures.check(res, "the builder makes a Rescue contract", false,
			"ContractGenerator returned null")
		return
	TestFixtures.check(res, "the builder makes a Rescue contract",
		contract.contract_type == RescueContractBuilder.CONTRACT_TYPE
		and contract.assigned_primary_event == RescueSystem.EVENT_NAME,
		"type %s event %s" % [contract.contract_type, contract.assigned_primary_event])
	TestFixtures.check(res, "the contract names the missing merc",
		contract.rescue_merc_uid == merc.merc_uid
		and contract.rescue_kind == RescueContractBuilder.KIND_FLED
		and contract.description != "",
		"uid %d kind %s" % [contract.rescue_merc_uid, contract.rescue_kind])
	TestFixtures.check(res, "the builder stages the record for the battle",
		RescueContractBuilder.pending_records.has(merc.merc_uid),
		"%d staged record(s)" % RescueContractBuilder.pending_records.size())
	RescueContractBuilder.release(merc.merc_uid)
	TestFixtures.check(res, "releasing clears the staged record",
		not RescueContractBuilder.pending_records.has(merc.merc_uid),
		"%d staged record(s)" % RescueContractBuilder.pending_records.size())


static func _case_choose_mode(res: Dictionary) -> void:
	var config: ContractConfig = ContractLibrary.config()
	var four: Array = [null, null, null, null]
	var three: Array = [null, null, null]
	var five: Array = [null, null, null, null, null]
	config.rescue_mode = RescueSystem.MODE_STEALTH
	TestFixtures.check(res, "a forced stealth mode wins",
		RescueContractBuilder.choose_mode(four, three) == RescueSystem.MODE_STEALTH,
		"mode %s" % RescueContractBuilder.choose_mode(four, three))
	config.rescue_mode = RescueSystem.MODE_COMBAT
	TestFixtures.check(res, "a forced combat mode wins",
		RescueContractBuilder.choose_mode(four, five) == RescueSystem.MODE_COMBAT,
		"mode %s" % RescueContractBuilder.choose_mode(four, five))
	config.rescue_mode = "auto"
	TestFixtures.check(res, "auto sneaks when the captors outnumber the party",
		RescueContractBuilder.choose_mode(four, five) == RescueSystem.MODE_STEALTH,
		"mode %s" % RescueContractBuilder.choose_mode(four, five))
	TestFixtures.check(res, "auto fights when the party is the larger side",
		RescueContractBuilder.choose_mode(four, three) == RescueSystem.MODE_COMBAT,
		"mode %s" % RescueContractBuilder.choose_mode(four, three))


static func _case_contract(res: Dictionary) -> void:
	MercPool.clear()
	RescueContractBuilder.pending_records.clear()
	CampaignClock.reset()
	var team: Array[MercenaryData] = leveled_party(20, 3, 100)
	var held: Array[MercenaryData] = leveled_party(20, 1, 103)
	if team.size() < 3 or held.is_empty():
		TestFixtures.check(res, "the contract case generates a team", false, "no merc generated")
		return
	var captive: MercenaryData = held[0]
	var record: Dictionary = RescueContractBuilder.record_for(captive,
		RescueContractBuilder.KIND_FLED)
	var contract: ContractData = RescueContractBuilder.build(record)
	if contract == null:
		TestFixtures.check(res, "the contract case builds a contract", false,
			"ContractGenerator returned null")
		return
	contract.rolled_mishaps.clear()
	contract.unsavory = false
	var saved: bool = EncounterLogger.suppressed
	EncounterLogger.suppressed = true
	var contract_run: ContractRun = await ContractManager.run(contract, team, Callable())
	EncounterLogger.suppressed = saved
	var found: Dictionary = {}
	for outcome: Dictionary in contract_run.outcomes:
		if String(outcome.get("event", "")) == RescueSystem.EVENT_NAME:
			found = outcome
	TestFixtures.check(res, "the contract runs the rescue event", not found.is_empty(),
		"%d outcome(s)" % contract_run.outcomes.size())
	if found.is_empty():
		RescueContractBuilder.pending_records.clear()
		return
	var ro: Dictionary = found.get("rescue", {})
	TestFixtures.check(res, "the rescue outcome reaches the contract log",
		not ro.is_empty() and String(found.get("rescue_result", "")) != "",
		"result %s" % String(found.get("rescue_result", "")))
	var success: bool = bool(found.get("success", false))
	TestFixtures.check(res, "a rescued merc comes home with the company",
		contract_run.rescued.has(captive) == success,
		"success %s rescued %d" % [str(success), contract_run.rescued.size()])
	RescueContractBuilder.pending_records.clear()
	MercPool.clear()


#A Rescue field asks the generator for one cell block, so a band 1 dungeon still holds a cell.
static func _case_forced_block(res: Dictionary) -> void:
	var blocks_ok: bool = true
	for i: int in range(20):
		if int(DungeonGenerator.size_for(1.0, 1)["blocks"]) < 1:
			blocks_ok = false
	TestFixtures.check(res, "size_for honours the block floor", blocks_ok, "a band 1 spec had no block")
	var missing: int = 0
	for step: int in range(6):
		var field: BattlefieldArea = _dungeon_field(61 + step, 1.0, 2, 1)
		if field == null or _cell_rooms(field).is_empty():
			missing += 1
	TestFixtures.check(res, "a forced block gives every band 1 rescue dungeon a cell", missing == 0,
		"%d of 6 fields had no cell room" % missing)


#The posture this merc gets and the rule number behind it, as "posture/rule".
static func _posture_call(merc: MercenaryData, state: BattleState) -> String:
	var call_row: Dictionary = RescueTactics._decide(merc, state)
	return "%s/%d" % [str(call_row["posture"]), int(call_row["rule"])]


static func _max_hp(merc: MercenaryData) -> int:
	return maxi(1, int(merc.stats.get("maximum_hit_points", 1)))


#Puts every merc on the list back to full health, the teardown every case shares.
static func _heal(list: Array[MercenaryData]) -> void:
	for merc: MercenaryData in list:
		merc.current_hp = _max_hp(merc)


static func _case_notice_scan(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the notice case builds a dungeon"):
		return
	var state: BattleState = fx.state
	var captive: MercenaryData = fx.captive
	for merc: MercenaryData in fx.party:
		if ConstStates.has_state(merc, RescueSystem.STATE_HIDDEN):
			StateCascade.remove_state(merc, RescueSystem.STATE_HIDDEN)
	var enemy: MercenaryData = fx.enemies[0]
	var spot: Vector3i = _free_neighbour(fx.field, state, state.pos3(captive), Rect2i())
	if spot == PathTargeter.NO_CELL or not ConstStates.has_state(captive, RescueSystem.STATE_HIDDEN):
		_missing(res, "the notice case seats an enemy beside the captive")
		return
	state.set_pos3(enemy, spot)
	_stat_block(captive, 1, 0, 0.0)
	_stat_block(enemy, 0, 20, 100.0)
	var lines: Array[String] = []
	RescueStealth.notice_scan(enemy, state, lines)
	TestFixtures.check(res, "a caged captive is no intruder to spot",
		not bool(state.rescue["alarm"]), "alarm %s while caged" % str(state.rescue["alarm"]))
	state.rescue["freed"] = true
	RescueStealth.notice_scan(enemy, state, lines)
	TestFixtures.check(res, "a freed captive is watched like any other intruder",
		bool(state.rescue["alarm"]), "alarm %s once freed" % str(state.rescue["alarm"]))


static func _case_ally_crossing(res: Dictionary) -> void:
	var crew: Array[MercenaryData] = leveled_party(5, 2, 200)
	var foes: Array[MercenaryData] = leveled_party(5, 1, 210)
	if crew.size() < 2 or foes.is_empty():
		TestFixtures.check(res, "the crossing case generates mercs", false, "no mercs generated")
		return
	var state: BattleState = BattleState.create(crew, foes, TestFixtures.exterior_field())
	var walker: MercenaryData = crew[0]
	var start := Vector3i(5, 5, 0)
	var mid := Vector3i(6, 5, 0)
	var goal := Vector3i(7, 5, 0)
	state.set_pos3(walker, start)
	state.set_pos3(crew[1], mid)
	state.set_pos3(foes[0], Vector3i(20, 20, 0))
	var path: Array[Vector3i] = [start, mid, goal]
	var lines: Array[String] = []
	state.set_pace_pool(walker, 3)
	var stepped: Array[Vector3i] = RescueWalk.walk(walker, state, path, 3, lines)
	TestFixtures.check(res, "a rescue walk crosses a standing ally",
		stepped.size() == 1 and state.pos3(walker) == goal,
		"%d step(s) to (%d,%d)" % [stepped.size(), state.pos3(walker).x, state.pos3(walker).y])
	TestFixtures.check(res, "crossing an ally costs its pace on landing",
		state.get_pace_pool(walker) == 1, "pool %d of 3" % state.get_pace_pool(walker))
	state.set_pos3(walker, start)
	state.set_pace_pool(walker, 1)
	var blocked: Array[Vector3i] = RescueWalk.walk(walker, state, path, 1, lines)
	TestFixtures.check(res, "a walk that cannot pay for the crossing stays put",
		blocked.is_empty() and state.pos3(walker) == start,
		"%d step(s) with one pace" % blocked.size())


#A locked door at pos; it carries the room it shuts in when one is given.
static func _locked_door(pos: Vector3i, room: Dictionary = {}) -> Dictionary:
	var door: Dictionary = {"cell_type": "door", "pos": pos}
	door[DungeonLocks.LOCKED_KEY] = true
	if not room.is_empty():
		door[DungeonLocks.ROOM_KEY] = room
	return door


static func _case_door_reasons(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the door reason case builds a dungeon"):
		return
	var state: BattleState = fx.state
	var enemies: Array[MercenaryData] = fx.enemies
	var captive: MercenaryData = fx.captive
	var rescue: Dictionary = state.rescue
	var gate: Dictionary = rescue["gate_obs"]
	var gate_cell: Vector3i = rescue["gate_cell"]
	var lead: MercenaryData = RescueSystem.picker(state)
	var chest_cell: Vector3i = rescue["chest_cell"]
	if gate.is_empty() or gate_cell == PathTargeter.NO_CELL or lead == null or enemies.is_empty():
		_missing(res, "the door reason case finds a gate")
		return
	gate[DungeonLocks.LOCKED_KEY] = true
	rescue["mode"] = RescueSystem.MODE_STEALTH
	rescue["gate_go"] = false
	TestFixtures.check(res, "the cell is wanted before any fighting starts",
		DungeonLocks.wanted_reason(lead, gate, gate_cell, state) == RescueDoors.CAPTIVE_CELL,
		"reason %s" % DungeonLocks.wanted_reason(lead, gate, gate_cell, state))
	rescue["mode"] = RescueSystem.MODE_COMBAT
	TestFixtures.check(res, "a gate nobody wants open is no door at all",
		RescueDoors.reason(lead, gate, state) == RescueDoors.BLOCKED_GATE
		and DungeonLocks.wanted_reason(lead, gate, gate_cell, state) == ""
		and RescueSystem.gate_target(lead, state) == PathTargeter.NO_CELL,
		"reason %s" % RescueDoors.reason(lead, gate, state))
	rescue["gate_go"] = true
	TestFixtures.check(res, "a Go decision makes the gate the captive's cell again",
		DungeonLocks.wanted_reason(lead, gate, gate_cell, state) == RescueDoors.CAPTIVE_CELL,
		"reason %s" % DungeonLocks.wanted_reason(lead, gate, gate_cell, state))
	var far := Vector3i(-5, -5, gate_cell.z)
	var chest_room: Dictionary = {"rect": Rect2i(chest_cell.x - 1, chest_cell.y - 1, 3, 3),
		"floor": chest_cell.z, "name": RescueSystem.STORAGE_ROOM}
	var chest_door: Dictionary = _locked_door(far, chest_room)
	var held: WeaponData = captive.equipped_weapon
	captive.equipped_weapon = null
	rescue["chest_given_up"] = false
	rescue["freed"] = true
	state.teams[0].append(captive)
	state._merc_team_index[captive] = 0
	if not RescueTactics._weapon_in_chest(state):
		ChestLoot.add(rescue["chest_obs"], {"type": "weapon", "data": WeaponData.new()})
	TestFixtures.check(res, "the captive wants the door that guards its own gear",
		DungeonLocks.wanted_reason(captive, chest_door, far, state) == RescueDoors.GEAR_CHEST,
		"reason %s" % DungeonLocks.wanted_reason(captive, chest_door, far, state))
	captive.equipped_weapon = held
	rescue["freed"] = false
	state.teams[0].erase(captive)
	state._merc_team_index.erase(captive)
	var own: Vector3i = state.pos3(lead)
	var out_room: Dictionary = {"rect": Rect2i(own.x - 1, own.y - 1, 3, 3), "floor": own.z,
		"name": RescueSystem.FOYER_ROOM}
	var out_door: Dictionary = _locked_door(far, out_room)
	TestFixtures.check(res, "a merc shut inside a room wants its way out",
		DungeonLocks.wanted_reason(lead, out_door, far, state) == DungeonLocks.REASON_WAY_OUT,
		"reason %s" % DungeonLocks.wanted_reason(lead, out_door, far, state))
	var pen := Vector3i(own.x + 30, own.y + 30, own.z)
	state.set_pos3(enemies[0], pen)
	var pen_room: Dictionary = {"rect": Rect2i(pen.x - 1, pen.y - 1, 3, 3), "floor": pen.z,
		"name": RescueSystem.FOYER_ROOM}
	var pen_door: Dictionary = _locked_door(far, pen_room)
	TestFixtures.check(res, "a room with an enemy in it is worth opening",
		DungeonLocks.wanted_reason(lead, pen_door, far, state) == DungeonLocks.REASON_ENEMY_INSIDE,
		"reason %s" % DungeonLocks.wanted_reason(lead, pen_door, far, state))
	var empty_room: Dictionary = {"rect": Rect2i(own.x + 60, own.y + 60, 3, 3), "floor": own.z,
		"name": RescueSystem.FOYER_ROOM}
	var empty_door: Dictionary = _locked_door(far, empty_room)
	var blank_door: Dictionary = _locked_door(far)
	TestFixtures.check(res, "an empty room is left shut and a nameless one is opened",
		DungeonLocks.wanted_reason(lead, empty_door, far, state) == ""
		and DungeonLocks.wanted_reason(lead, blank_door, far, state) == DungeonLocks.REASON_UNKNOWN_ROOM,
		"empty %s blank %s" % [DungeonLocks.wanted_reason(lead, empty_door, far, state),
			DungeonLocks.wanted_reason(lead, blank_door, far, state)])
	rescue["gate_go"] = false


static func _set_hp(list: Array[MercenaryData], hp: int) -> void:
	for merc: MercenaryData in list:
		merc.current_hp = hp


#Locks the gate beyond reach, sets the captive weak, seats the party east of the gate and the enemies
#west of it with the given hit points, and primes one evaluation. Empty when the fixture has no gate.
static func _stage_gate(fx: RescueFx, party_hp: int, enemy_hp: int) -> Dictionary:
	var state: BattleState = fx.state
	var rescue: Dictionary = state.rescue
	var gate: Dictionary = rescue["gate_obs"]
	var gate_cell: Vector3i = rescue["gate_cell"]
	var lead: MercenaryData = RescueSystem.picker(state)
	if gate_cell == PathTargeter.NO_CELL or lead == null or fx.party.size() < 3 \
			or fx.enemies.size() < 3:
		return {}
	var saved_d: int = DungeonLocks.lock_difficulty(gate)
	gate[DungeonLocks.LOCKED_KEY] = true
	gate[DungeonLocks.DIFFICULTY_KEY] = 99
	gate[DungeonLocks.FAILS_KEY] = 0
	fx.captive.current_hp = 5
	for i: int in range(fx.party.size()):
		_stat_block(fx.party[i], 0, 0, 0.0)
		state.set_pos3(fx.party[i], Vector3i(gate_cell.x + 1, gate_cell.y + i, gate_cell.z))
	for i: int in range(fx.enemies.size()):
		state.set_pos3(fx.enemies[i], Vector3i(gate_cell.x - 1, gate_cell.y - i, gate_cell.z))
	_set_hp(fx.party, party_hp)
	_set_hp(fx.enemies, enemy_hp)
	rescue["gate_dist"] = {state.pos3(lead): 1}
	rescue["gate_eval_round"] = -1
	return {"gate": gate, "gate_cell": gate_cell, "lead": lead, "saved_d": saved_d}


static func _case_gate_decision(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the gate decision case builds a dungeon"):
		return
	var stage: Dictionary = _stage_gate(fx, 100, 1)
	if stage.is_empty():
		_missing(res, "the gate decision case finds a gate")
		return
	var state: BattleState = fx.state
	var party: Array[MercenaryData] = fx.party
	var enemies: Array[MercenaryData] = fx.enemies
	var captive: MercenaryData = fx.captive
	var rescue: Dictionary = state.rescue
	var gate: Dictionary = stage["gate"]
	var gate_cell: Vector3i = stage["gate_cell"]
	var lead: MercenaryData = stage["lead"]
	var saved_d: int = stage["saved_d"]
	var lines: Array[String] = []
	RescueTactics.evaluate_gate(state, lines)
	TestFixtures.check(res, "a party that is winning leaves the cell shut",
		not bool(rescue["gate_go"]), "go %s" % str(rescue["gate_go"]))
	_set_hp(party, 1)
	_set_hp(enemies, 100)
	rescue["gate_eval_round"] = -1
	RescueTactics.evaluate_gate(state, lines)
	TestFixtures.check(res, "a party that is losing wants the captive in the fight",
		bool(rescue["gate_go"]), "go %s" % str(rescue["gate_go"]))
	for i: int in range(party.size()):
		if party[i] != lead:
			state.set_pos3(party[i], Vector3i(gate_cell.x + 40, gate_cell.y + i, gate_cell.z))
	rescue["gate_eval_round"] = -1
	RescueTactics.evaluate_gate(state, lines)
	TestFixtures.check(res, "enemies massed at the cell outweigh the help it would bring",
		not bool(rescue["gate_go"]), "go %s" % str(rescue["gate_go"]))
	RescueTactics.policy = RescueTactics.POLICY_ALWAYS
	rescue["gate_eval_round"] = -1
	RescueTactics.evaluate_gate(state, lines)
	var always: bool = bool(rescue["gate_go"])
	RescueTactics.policy = RescueTactics.POLICY_NEVER
	rescue["gate_eval_round"] = -1
	RescueTactics.evaluate_gate(state, lines)
	var never: bool = bool(rescue["gate_go"])
	RescueTactics.policy = RescueTactics.POLICY_SMART
	TestFixtures.check(res, "the policy switch overrides the formula both ways",
		always and not never, "always %s never %s" % [str(always), str(never)])
	gate[DungeonLocks.FAILS_KEY] = DungeonLocks.MAX_JAM
	rescue["gate_hopeless"] = false
	rescue["gate_eval_round"] = -1
	RescueTactics.evaluate_gate(state, lines)
	TestFixtures.check(res, "a gate jammed past saving is called hopeless",
		bool(rescue["gate_hopeless"]) and not bool(rescue["gate_go"]),
		"hopeless %s go %s" % [str(rescue["gate_hopeless"]), str(rescue["gate_go"])])
	TestFixtures.check(res, "every gate decision is counted for the probe",
		int(rescue["go_count"]) == 2 and int(rescue["stay_count"]) == 4,
		"go %d stay %d" % [int(rescue["go_count"]), int(rescue["stay_count"])])
	gate[DungeonLocks.FAILS_KEY] = 0
	gate[DungeonLocks.DIFFICULTY_KEY] = saved_d
	rescue["gate_hopeless"] = false
	rescue["gate_go"] = false
	captive.current_hp = _max_hp(captive)
	_heal(party)
	_heal(enemies)


static func _case_escort(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the escort case builds a dungeon"):
		return
	var state: BattleState = fx.state
	var party: Array[MercenaryData] = fx.party
	var enemies: Array[MercenaryData] = fx.enemies
	var rescue: Dictionary = state.rescue
	var gate_cell: Vector3i = rescue["gate_cell"]
	var lead: MercenaryData = RescueSystem.picker(state)
	if gate_cell == PathTargeter.NO_CELL or lead == null or party.size() < 3 or enemies.is_empty():
		_missing(res, "the escort case finds a gate")
		return
	var others: Array[MercenaryData] = []
	for m: MercenaryData in party:
		if m != lead:
			others.append(m)
	if others.size() < 2:
		_missing(res, "the escort case spares two mercs")
		return
	var lines: Array[String] = []
	RescueTactics.policy = RescueTactics.POLICY_ALWAYS
	(rescue["gate_obs"] as Dictionary)[DungeonLocks.LOCKED_KEY] = true
	state.set_pos3(lead, Vector3i(gate_cell.x + 1, gate_cell.y, gate_cell.z))
	state.set_pos3(others[0], Vector3i(gate_cell.x + 3, gate_cell.y, gate_cell.z))
	state.set_pos3(others[1], Vector3i(gate_cell.x + 5, gate_cell.y, gate_cell.z))
	for i: int in range(enemies.size()):
		state.set_pos3(enemies[i], Vector3i(gate_cell.x - 2, gate_cell.y + i, gate_cell.z))
	rescue["gate_eval_round"] = -1
	RescueTactics.evaluate_gate(state, lines)
	TestFixtures.check(res, "the nearest spare merc attends the picker",
		RescueTactics.escort(state) == others[0],
		"escort %s" % str(RescueTactics.escort(state) != null))
	others[0].is_dead = true
	others[0].current_hp = 0
	rescue["gate_eval_round"] = -1
	RescueTactics.evaluate_gate(state, lines)
	TestFixtures.check(res, "a party of two spares nobody for the picker",
		RescueTactics.escort(state) == null,
		"escort %s" % str(RescueTactics.escort(state) != null))
	others[0].is_dead = false
	others[0].current_hp = _max_hp(others[0])
	for e: MercenaryData in enemies:
		state.set_pos3(e, Vector3i(gate_cell.x + 60, gate_cell.y + 60, gate_cell.z))
	rescue["gate_eval_round"] = -1
	RescueTactics.evaluate_gate(state, lines)
	TestFixtures.check(res, "a quiet route needs no escort at all",
		RescueTactics.escort(state) == null,
		"escort %s" % str(RescueTactics.escort(state) != null))
	RescueTactics.policy = RescueTactics.POLICY_SMART
	rescue["gate_go"] = false
	rescue["escort"] = null


static func _case_order(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the action order case builds a dungeon"):
		return
	var state: BattleState = fx.state
	var field: BattlefieldArea = fx.field
	var enemies: Array[MercenaryData] = fx.enemies
	var rescue: Dictionary = state.rescue
	var gate: Dictionary = rescue["gate_obs"]
	var gate_cell: Vector3i = rescue["gate_cell"]
	var lead: MercenaryData = RescueSystem.picker(state)
	if gate.is_empty() or gate_cell == PathTargeter.NO_CELL or lead == null or enemies.is_empty():
		_missing(res, "the action order case finds a gate")
		return
	var spot: Vector3i = _free_neighbour(field, state, gate_cell, rescue["cell_rect"] as Rect2i)
	if spot == PathTargeter.NO_CELL:
		_missing(res, "the action order case seats the picker")
		return
	var saved_d: int = DungeonLocks.lock_difficulty(gate)
	var foe: MercenaryData = enemies[0]
	state.battlefield = null
	gate[DungeonLocks.LOCKED_KEY] = true
	gate[DungeonLocks.DIFFICULTY_KEY] = 99
	rescue["gate_go"] = true
	state.set_pos3(lead, spot)
	lead.current_hp = _max_hp(lead)
	for e: MercenaryData in enemies:
		e.off_field = false
		e.current_hp = _max_hp(e)
		state.set_pos3(e, Vector3i(spot.x + 30, spot.y + 30, spot.z))
	state.set_pos3(foe, Vector3i(spot.x + 1, spot.y, spot.z))
	TestFixtures.check(res, "a hopeless lock loses its slot to the enemy in reach",
		not RescueTactics.pick_first(lead, state)
		and RescueSystem.gate_target(lead, state) == PathTargeter.NO_CELL,
		"pick first %s" % str(RescueTactics.pick_first(lead, state)))
	gate[DungeonLocks.LOCKED_KEY] = false
	TestFixtures.check(res, "an open gate is worth more than a fresh enemy",
		RescueTactics.pick_first(lead, state),
		"pick first %s" % str(RescueTactics.pick_first(lead, state)))
	gate[DungeonLocks.LOCKED_KEY] = true
	for e: MercenaryData in enemies:
		e.off_field = true
	TestFixtures.check(res, "with nothing in reach the lock takes the slot",
		RescueTactics.pick_first(lead, state),
		"pick first %s" % str(RescueTactics.pick_first(lead, state)))
	foe.off_field = false
	foe.current_hp = 1
	gate[DungeonLocks.LOCKED_KEY] = false
	TestFixtures.check(res, "an enemy about to drop outranks even an open gate",
		not RescueTactics.pick_first(lead, state),
		"pick first %s" % str(RescueTactics.pick_first(lead, state)))
	gate[DungeonLocks.LOCKED_KEY] = true
	RescueTactics.melee_rule = RescueTactics.MELEE_PICK
	TestFixtures.check(res, "the melee pick rule always works the lock first",
		RescueTactics.pick_first(lead, state),
		"pick first %s" % str(RescueTactics.pick_first(lead, state)))
	RescueTactics.melee_rule = RescueTactics.MELEE_FIGHT
	var swings: bool = RescueTactics.pick_first(lead, state)
	state.set_pos3(foe, Vector3i(spot.x + 30, spot.y + 30, spot.z))
	TestFixtures.check(res, "the melee fight rule swings while an enemy is in reach",
		not swings and RescueTactics.pick_first(lead, state),
		"in reach %s alone %s" % [str(swings), str(RescueTactics.pick_first(lead, state))])
	RescueTactics.melee_rule = RescueTactics.MELEE_SMART
	state.battlefield = field
	gate[DungeonLocks.DIFFICULTY_KEY] = saved_d
	rescue["gate_go"] = false
	for e: MercenaryData in enemies:
		e.off_field = false
		e.current_hp = _max_hp(e)


static func _case_postures(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the posture case builds a dungeon"):
		return
	var state: BattleState = fx.state
	var party: Array[MercenaryData] = fx.party
	var enemies: Array[MercenaryData] = fx.enemies
	var captive: MercenaryData = fx.captive
	var rescue: Dictionary = state.rescue
	var exit_cell: Vector3i = rescue["exit_cell"]
	if exit_cell == PathTargeter.NO_CELL or party.size() < 3 or enemies.is_empty():
		_missing(res, "the posture case finds an exit")
		return
	var merc: MercenaryData = party[0]
	var foe: MercenaryData = enemies[0]
	if _max_hp(merc) < 4:
		_missing(res, "the posture case finds a merc with room to bleed")
		return
	var lines: Array[String] = []
	RescueSystem.free_captive(state, lines, null, false)
	var beside := Vector3i(exit_cell.x + 1, exit_cell.y, exit_cell.z)
	var hole := Vector3i(exit_cell.x + 2, exit_cell.y, exit_cell.z)
	var away := Vector3i(exit_cell.x + 40, exit_cell.y + 40, exit_cell.z)
	state.set_pos3(captive, hole)
	for m: MercenaryData in party:
		if m != merc:
			state.set_pos3(m, away)
	for e: MercenaryData in enemies:
		state.set_pos3(e, away)
		e.current_hp = 1
	var dist: Dictionary = {}
	dist[exit_cell] = 0
	dist[beside] = 1
	dist[hole] = 5
	dist[away] = 9
	rescue["exit_dist"] = dist
	state.set_pos3(merc, beside)
	merc.current_hp = 1
	var bled: String = _posture_call(merc, state)
	TestFixtures.check(res, "a rescuer bled white withdraws",
		bled == RescueTactics.POSTURE_WITHDRAW + "/1", bled)
	merc.current_hp = _max_hp(merc)
	for e: MercenaryData in enemies:
		e.current_hp = 1000
	var beaten: String = _posture_call(merc, state)
	TestFixtures.check(res, "a party that is being beaten withdraws",
		beaten == RescueTactics.POSTURE_WITHDRAW + "/2", beaten)
	for e: MercenaryData in enemies:
		e.current_hp = 1
	state.set_pos3(merc, exit_cell)
	var on_exit: String = _posture_call(merc, state)
	TestFixtures.check(res, "a merc already on the exit walks out instead of holding it",
		on_exit == RescueTactics.POSTURE_WITHDRAW + "/3", on_exit)
	state.set_pos3(merc, beside)
	state.set_pos3(foe, beside)
	var between: String = _posture_call(merc, state)
	TestFixtures.check(res, "a merc between the captive and the exit fights what comes",
		between == RescueTactics.POSTURE_FIGHT + "/3", between)
	state.set_pos3(foe, away)
	var ahead: String = _posture_call(merc, state)
	TestFixtures.check(res, "a merc ahead of the captive holds the way out",
		ahead == RescueTactics.POSTURE_HOLD + "/3", ahead)
	var far_dist: Dictionary = {}
	far_dist[exit_cell] = 0
	far_dist[beside] = 9
	far_dist[hole] = 5
	far_dist[away] = 12
	rescue["exit_dist"] = far_dist
	var behind: String = _posture_call(merc, state)
	TestFixtures.check(res, "a merc behind the captive with nothing in reach follows it out",
		behind == RescueTactics.POSTURE_WITHDRAW + "/4", behind)
	state.set_pos3(foe, beside)
	var winning: String = _posture_call(merc, state)
	TestFixtures.check(res, "a winning party stands and fights",
		winning == RescueTactics.POSTURE_FIGHT + "/5", winning)
	var mine: int = RescueTactics.side_hp(RescueTactics.party(state)) + maxi(0, captive.current_hp)
	foe.current_hp = mine
	var even: String = _posture_call(merc, state)
	TestFixtures.check(res, "an even fight becomes a fighting withdrawal",
		even == RescueTactics.POSTURE_FALL_BACK + "/6", even)
	for e: MercenaryData in enemies:
		e.current_hp = _max_hp(e)
		state.set_pos3(e, away)


#The careful captive rules: a safe walk out, the gear fetch, the shelter, the drive and the fall back.
static func _check_captive_careful(res: Dictionary, state: BattleState, merc: MercenaryData,
	captive: MercenaryData, enemies: Array[MercenaryData], stand: Vector3i,
	exit_cell: Vector3i) -> void:
	var rescue: Dictionary = state.rescue
	var foe: MercenaryData = enemies[0]
	var seen := Vector3i(stand.x + 5, stand.y, stand.z)
	var close := Vector3i(stand.x + 2, stand.y, stand.z)
	var path: Array[Vector3i] = ReachCache.walk_path_for(captive, state, stand, exit_cell)
	if path.is_empty():
		_missing(res, "the captive posture case finds a walk to the exit")
	else:
		TestFixtures.check(res, "an emptied dungeon leaves the captive a safe way out",
			RescueTactics.route_safe(captive, state, exit_cell),
			"%d cell(s) on the walk" % path.size())
		var safe_out: String = _posture_call(captive, state)
		TestFixtures.check(res, "a safe way out sends the freed captive walking",
			safe_out == RescueTactics.POSTURE_WITHDRAW + "/8", safe_out)
	state.set_pos3(foe, seen)
	TestFixtures.check(res, "one enemy beside the captive spoils its route",
		not RescueTactics.route_safe(captive, state, exit_cell), "the route still read safe")
	var fetched: String = _posture_call(captive, state)
	TestFixtures.check(res, "a freed captive fetches its gear while that is worth doing",
		fetched == RescueTactics.POSTURE_FIGHT + "/7", fetched)
	rescue["chest_given_up"] = true
	var sheltered: String = _posture_call(captive, state)
	TestFixtures.check(res, "an unarmed captive with no gear to fetch shelters",
		sheltered == RescueTactics.POSTURE_HOLD + "/10", sheltered)
	state.set_pos3(foe, close)
	var driven: String = _posture_call(captive, state)
	TestFixtures.check(res, "an enemy on top of the shelter drives the captive out",
		driven == RescueTactics.POSTURE_WITHDRAW + "/13", driven)
	state.set_pos3(foe, seen)
	for e: MercenaryData in enemies:
		e.current_hp = 1000
	var alone: String = _posture_call(captive, state)
	TestFixtures.check(res, "a captive with nobody left to clear the way runs for it",
		alone == RescueTactics.POSTURE_WITHDRAW + "/12", alone)
	for e: MercenaryData in enemies:
		e.current_hp = 1
	captive.equipped_weapon = WeaponData.new()
	var armed: String = _posture_call(captive, state)
	TestFixtures.check(res, "an armed captive falls back fighting",
		armed == RescueTactics.POSTURE_FALL_BACK + "/9", armed)
	rescue["captive_rule"] = 10
	var party_on: String = _posture_call(merc, state)
	TestFixtures.check(res, "the party fights on while the captive shelters",
		party_on == RescueTactics.POSTURE_FIGHT + "/11", party_on)
	rescue["captive_rule"] = 8
	var back: Dictionary = RescueTactics._decide(merc, state)
	TestFixtures.check(res, "a captive on the move hands the party its own rules back",
		int(back["rule"]) >= 3 and int(back["rule"]) <= 6, "rule %d" % int(back["rule"]))


#The plain captive rules with the careful switch off: fetch the gear, walk out, or fall back armed.
static func _check_captive_plain(res: Dictionary, state: BattleState,
	captive: MercenaryData) -> void:
	var rescue: Dictionary = state.rescue
	rescue["captive_rule"] = 0
	RescueTactics.careful = false
	rescue["chest_given_up"] = false
	captive.equipped_weapon = null
	var plain_fetch: String = _posture_call(captive, state)
	TestFixtures.check(res, "the plain captive rule still fetches the gear",
		plain_fetch == RescueTactics.POSTURE_FIGHT + "/7", plain_fetch)
	rescue["chest_given_up"] = true
	var plain_out: String = _posture_call(captive, state)
	TestFixtures.check(res, "the plain captive rule walks an unarmed captive out",
		plain_out == RescueTactics.POSTURE_WITHDRAW + "/8", plain_out)
	captive.equipped_weapon = WeaponData.new()
	var plain_armed: String = _posture_call(captive, state)
	TestFixtures.check(res, "the plain captive rule has an armed captive fall back",
		plain_armed == RescueTactics.POSTURE_FALL_BACK + "/9", plain_armed)
	RescueTactics.careful = true


#The caged wounded switch: a bled rescuer either leaves the captive caged or fights on.
static func _check_captive_caged(res: Dictionary, state: BattleState, merc: MercenaryData,
	enemies: Array[MercenaryData]) -> void:
	var rescue: Dictionary = state.rescue
	rescue["freed"] = false
	for e: MercenaryData in enemies:
		e.current_hp = 1000
	if _max_hp(merc) < 3:
		_missing(res, "the captive posture case finds a merc with room to bleed")
	else:
		merc.current_hp = 1
		RescueTactics.caged_wounded_leave = true
		var caged_on: String = _posture_call(merc, state)
		TestFixtures.check(res, "with the switch on a bled rescuer leaves the captive caged",
			caged_on == RescueTactics.POSTURE_WITHDRAW + "/1", caged_on)
		RescueTactics.caged_wounded_leave = false
		var caged_off: String = _posture_call(merc, state)
		TestFixtures.check(res, "with the switch off the same rescuer fights on",
			caged_off == RescueTactics.POSTURE_FIGHT + "/0", caged_off)
		merc.current_hp = _max_hp(merc)


#Hopeless odds pull the whole party out of the rescue.
static func _check_captive_abandon(res: Dictionary, state: BattleState,
	merc: MercenaryData) -> void:
	var rescue: Dictionary = state.rescue
	rescue["gate_go"] = false
	rescue["gate_eval_round"] = 1
	rescue["abandoned"] = false
	var quit_lines: Array[String] = []
	var call_name: String = RescueTactics.set_posture(merc, state, quit_lines)
	TestFixtures.check(res, "hopeless odds pull the whole party out",
		bool(rescue["abandoned"]) and call_name == RescueTactics.POSTURE_WITHDRAW
		and _line_holding(quit_lines, "gives up on the rescue"),
		"posture %s abandoned %s" % [call_name, str(rescue["abandoned"])])


#With the withdraw switch off no rescuer is given a posture at the start of the turn.
static func _check_captive_withdraw(res: Dictionary, state: BattleState, merc: MercenaryData,
	enemies: Array[MercenaryData]) -> void:
	var rescue: Dictionary = state.rescue
	rescue["abandoned"] = false
	rescue["freed"] = true
	rescue["gate_eval_round"] = 0
	_heal(enemies)
	(rescue["postures"] as Dictionary).clear()
	RescueTactics.withdraw_enabled = false
	var off_lines: Array[String] = []
	RescueSystem.start_of_turn(merc, state, off_lines)
	TestFixtures.check(res, "the withdraw switch leaves every rescuer fighting",
		(rescue["postures"] as Dictionary).is_empty()
		and RescueTactics.posture_of(state, merc) == RescueTactics.POSTURE_FIGHT,
		"%d posture(s) stored" % (rescue["postures"] as Dictionary).size())
	RescueTactics.withdraw_enabled = true


#A sheltering captive spends its turn keeping out of sight.
static func _check_captive_shelter(res: Dictionary, state: BattleState,
	captive: MercenaryData) -> void:
	var rescue: Dictionary = state.rescue
	var shelter: int = int(rescue.get("shelter_turns", 0))
	var hold_lines: Array[String] = []
	RescueDirector.hold_turn(captive, state, hold_lines)
	TestFixtures.check(res, "a sheltering captive keeps out of sight",
		_line_holding(hold_lines, "keeps out of sight")
		and int(rescue.get("shelter_turns", 0)) == shelter + 1,
		"%d line(s), shelter turns %d" % [hold_lines.size(), int(rescue.get("shelter_turns", 0))])


static func _case_captive_postures(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the captive posture case builds a dungeon"):
		return
	var state: BattleState = fx.state
	var party: Array[MercenaryData] = fx.party
	var enemies: Array[MercenaryData] = fx.enemies
	var captive: MercenaryData = fx.captive
	var rescue: Dictionary = state.rescue
	var chest_obs: Dictionary = rescue["chest_obs"]
	var chest_cell: Vector3i = rescue["chest_cell"]
	var exit_cell: Vector3i = rescue["exit_cell"]
	var stand: Vector3i = RescueGrid.adjacent_free_cell(state, chest_cell, captive)
	if chest_obs.is_empty() or chest_cell == PathTargeter.NO_CELL or party.is_empty() \
			or enemies.is_empty() or exit_cell == PathTargeter.NO_CELL \
			or stand == PathTargeter.NO_CELL:
		_missing(res, "the captive posture case finds a chest")
		return
	var merc: MercenaryData = party[0]
	var held: WeaponData = captive.equipped_weapon
	rescue["freed"] = true
	rescue["captive_acted"] = true
	rescue["captive_exited"] = false
	rescue["abandoned"] = false
	rescue["chest_given_up"] = false
	captive.equipped_weapon = null
	captive.current_hp = _max_hp(captive)
	merc.current_hp = _max_hp(merc)
	if not RescueTactics._weapon_in_chest(state):
		ChestLoot.add(chest_obs, {"type": "weapon", "data": WeaponData.new()})
	state.set_pos3(captive, stand)
	var far := Vector3i(exit_cell.x + 500, exit_cell.y + 500, exit_cell.z)
	for e: MercenaryData in enemies:
		state.set_pos3(e, far)
		e.current_hp = 1
	_check_captive_careful(res, state, merc, captive, enemies, stand, exit_cell)
	_check_captive_plain(res, state, captive)
	_check_captive_caged(res, state, merc, enemies)
	_check_captive_abandon(res, state, merc)
	_check_captive_withdraw(res, state, merc, enemies)
	_check_captive_shelter(res, state, captive)
	_check_open_pending(res, fx, merc)
	captive.equipped_weapon = held
	rescue["captive_rule"] = 0
	rescue["captive_acted"] = false
	rescue["chest_given_up"] = false
	state.pending_interact.erase(merc)


#The director door helper: nothing pending works nothing, a shut unlocked door beside the merc opens.
static func _check_open_pending(res: Dictionary, fx: RescueFx, merc: MercenaryData) -> void:
	var state: BattleState = fx.state
	var field: BattlefieldArea = fx.field
	var rescue: Dictionary = state.rescue
	state.pending_interact.erase(merc)
	var idle_lines: Array[String] = []
	TestFixtures.check(res, "a merc with no door pending works none",
		not RescueDirector._open_pending(merc, state, idle_lines) and idle_lines.is_empty(),
		"%d line(s)" % idle_lines.size())
	var rect: Rect2i = rescue["cell_rect"]
	var door_cell: Vector3i = PathTargeter.NO_CELL
	var door_obs: Dictionary = {}
	var door_spot: Vector3i = PathTargeter.NO_CELL
	for key: Variant in field._obs_map.keys():
		if not (key is Vector3i):
			continue
		var cell: Vector3i = key as Vector3i
		if not PathCost.is_shut_door(field, cell):
			continue
		var obs: Dictionary = field.get_obs(Vector2i(cell.x, cell.y), cell.z)
		if obs.is_empty() or DungeonLocks.is_locked(obs):
			continue
		var spot: Vector3i = _free_neighbour(field, state, cell, rect)
		if spot == PathTargeter.NO_CELL:
			continue
		door_cell = cell
		door_obs = obs
		door_spot = spot
		break
	if door_cell == PathTargeter.NO_CELL:
		_missing(res, "the captive posture case finds a shut door")
		return
	state.set_pos3(merc, door_spot)
	state.start_of_turn(merc)
	state.pending_interact[merc] = door_cell
	var opens: int = int(rescue.get("door_opens", 0))
	var door_lines: Array[String] = []
	var worked: bool = RescueDirector._open_pending(merc, state, door_lines)
	TestFixtures.check(res, "a director-led merc works the door its walk stopped at",
		worked and OpenCloseState.is_open(door_obs) and not state.pending_interact.has(merc)
		and int(rescue.get("door_opens", 0)) == opens + 1,
		"worked %s, %d door(s)" % [str(worked), int(rescue.get("door_opens", 0))])
	OpenCloseState.set_open(door_obs, false)
	field.los_version += 1
	field.bump_path_version()
	state.los_cache.clear()
	MovementExecutor.clear_caches()


#Shelter patch v2: sight, not distance, decides the threat, and a seen captive moves to cover.
static func _case_shelter_v2(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the shelter case builds a dungeon"):
		return
	var state: BattleState = fx.state
	var party: Array[MercenaryData] = fx.party
	var enemies: Array[MercenaryData] = fx.enemies
	var captive: MercenaryData = fx.captive
	var rescue: Dictionary = state.rescue
	var chest_cell: Vector3i = rescue["chest_cell"]
	var stand: Vector3i = RescueGrid.adjacent_free_cell(state, chest_cell, captive)
	if party.is_empty() or enemies.is_empty() or stand == PathTargeter.NO_CELL:
		_missing(res, "the shelter case finds a chest and a crew")
		return
	var foe: MercenaryData = enemies[0]
	var held: WeaponData = captive.equipped_weapon
	var inside: Vector3i = state.pos3(captive)
	rescue["freed"] = true
	rescue["captive_acted"] = true
	rescue["captive_exited"] = false
	rescue["abandoned"] = false
	rescue["chest_given_up"] = true
	captive.equipped_weapon = null
	captive.current_hp = _max_hp(captive)
	_heal(party)
	for e: MercenaryData in enemies:
		if e != foe:
			e.off_field = true
	foe.current_hp = 1
	RescueTactics.shelter_los = true
	var blind: Vector3i = _ring_spot(state, captive, foe, inside, false)
	state.set_pos3(foe, Vector3i(inside.x + 1, inside.y, inside.z))
	TestFixtures.check(res, "an enemy at the captive's elbow threatens it through anything",
		RescueTactics.threatened(state, captive, inside), "the neighbour read safe")
	if blind == PathTargeter.NO_CELL:
		_missing(res, "the shelter case finds a wall two cells from the captive")
	else:
		state.set_pos3(foe, blind)
		TestFixtures.check(res, "an enemy two cells off with no sight line is no threat",
			not RescueTactics.threatened(state, captive, inside),
			"enemy at (%d,%d) F%d" % [blind.x, blind.y, blind.z])
		_check_shelter_rules(res, state, captive, foe, inside, blind)
	_check_hide_posture(res, state, captive, foe, stand)
	_check_hide_switches(res, state, captive)
	RescueTactics.shelter_los = false
	for e: MercenaryData in enemies:
		e.off_field = false
		e.current_hp = _max_hp(e)
	captive.equipped_weapon = held
	state.set_pos3(captive, inside)
	rescue["freed"] = false
	rescue["captive_acted"] = false
	rescue["chest_given_up"] = false
	rescue["captive_rule"] = 0


#A cell two steps off that the one live enemy either sees or cannot see; NO_CELL when none fits.
static func _ring_spot(state: BattleState, captive: MercenaryData, foe: MercenaryData,
		cell: Vector3i, want_seen: bool) -> Vector3i:
	for dx: int in range(-2, 3):
		for dy: int in range(-2, 3):
			if maxi(absi(dx), absi(dy)) != 2:
				continue
			var spot := Vector3i(cell.x + dx, cell.y + dy, cell.z)
			state.set_pos3(foe, spot)
			var seen: bool = not RescueGrid.cell_seers(state, cell, captive).is_empty()
			if seen == want_seen:
				return spot
	return PathTargeter.NO_CELL


#Rule 13 fires on sight with the switch on, and on plain distance with it off.
static func _check_shelter_rules(res: Dictionary, state: BattleState, captive: MercenaryData,
		foe: MercenaryData, cell: Vector3i, blind: Vector3i) -> void:
	state.set_pos3(captive, cell)
	state.set_pos3(foe, blind)
	var on: Dictionary = RescueTactics._decide(captive, state)
	TestFixtures.check(res, "a blind enemy within SHELTER_THREAT no longer drives the captive out",
		int(on["rule"]) == 10 or int(on["rule"]) == 14,
		"%s/%d" % [str(on["posture"]), int(on["rule"])])
	RescueTactics.shelter_los = false
	var off: Dictionary = RescueTactics._decide(captive, state)
	RescueTactics.shelter_los = true
	TestFixtures.check(res, "with the sight switch off the old proximity rule still fires",
		str(off["posture"]) == RescueTactics.POSTURE_WITHDRAW and int(off["rule"]) == 13,
		"%s/%d" % [str(off["posture"]), int(off["rule"])])


#An enemy in sight sends the captive to cover; the same enemy far off leaves the cell alone.
static func _check_hide_posture(res: Dictionary, state: BattleState, captive: MercenaryData,
		foe: MercenaryData, stand: Vector3i) -> void:
	state.set_pos3(captive, stand)
	var seen: Vector3i = _ring_spot(state, captive, foe, stand, true)
	if seen == PathTargeter.NO_CELL:
		_missing(res, "the shelter case finds an enemy a sight line to the captive")
		return
	state.set_pos3(foe, seen)
	TestFixtures.check(res, "an enemy in sight within SHELTER_SIGHT threatens the cell",
		RescueTactics.threatened(state, captive, stand),
		"enemy at (%d,%d) F%d" % [seen.x, seen.y, seen.z])
	state.set_pos3(foe, Vector3i(stand.x + 30, stand.y + 30, stand.z))
	TestFixtures.check(res, "the same enemy past SHELTER_SIGHT leaves the cell alone",
		not RescueTactics.threatened(state, captive, stand), "the far enemy still threatened it")
	state.set_pos3(foe, seen)
	var call_row: Dictionary = RescueTactics._decide(captive, state)
	if str(call_row["posture"]) == RescueTactics.POSTURE_WITHDRAW:
		_missing(res, "the shelter case finds the captive a cell out of sight")
		return
	var goal: Vector3i = state.rescue.get("hide_goal", PathTargeter.NO_CELL)
	TestFixtures.check(res, "a captive under enemy eyes moves to cover instead of running",
		str(call_row["posture"]) == RescueTactics.POSTURE_HIDE and int(call_row["rule"]) == 13
		and goal != PathTargeter.NO_CELL and not RescueTactics.threatened(state, captive, goal),
		"%s/%d goal (%d,%d) F%d" % [str(call_row["posture"]), int(call_row["rule"]),
			goal.x, goal.y, goal.z])


#The director drives a hiding captive, and the party reads every sheltering rule as one.
static func _check_hide_switches(res: Dictionary, state: BattleState, captive: MercenaryData) -> void:
	var rescue: Dictionary = state.rescue
	var postures: Dictionary = rescue["postures"]
	postures[captive] = RescueTactics.POSTURE_HIDE
	TestFixtures.check(res, "the director takes the turn of a hiding captive",
		RescueTactics.takes_turn(captive, state), "the hide posture fell through to the loop")
	rescue["captive_rule"] = 13
	var hiding: bool = RescueTactics._captive_sheltering(state)
	postures[captive] = RescueTactics.POSTURE_WITHDRAW
	var running: bool = RescueTactics._captive_sheltering(state)
	rescue["captive_rule"] = 10
	var holding: bool = RescueTactics._captive_sheltering(state)
	rescue["captive_rule"] = 14
	var refuge: bool = RescueTactics._captive_sheltering(state)
	rescue["captive_rule"] = 8
	var walking: bool = RescueTactics._captive_sheltering(state)
	TestFixtures.check(res, "the party fights on for a captive that holds, hides or takes the cell",
		holding and refuge and hiding and not running and not walking,
		"hold %s cell %s hide %s run %s walk %s" % [str(holding), str(refuge), str(hiding),
			str(running), str(walking)])
	rescue["captive_rule"] = 0
	postures.erase(captive)


static func _case_redirect(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the fall back case builds a dungeon"):
		return
	var state: BattleState = fx.state
	var captive: MercenaryData = fx.captive
	var rescue: Dictionary = state.rescue
	var exit_cell: Vector3i = rescue["exit_cell"]
	var merc: MercenaryData = fx.party[0]
	if exit_cell == PathTargeter.NO_CELL or fx.enemies.is_empty() \
			or RescueGrid.adjacent_free_cell(state, exit_cell, merc) == PathTargeter.NO_CELL:
		_missing(res, "the fall back case finds an exit")
		return
	var stand := Vector3i(exit_cell.x + 3, exit_cell.y, exit_cell.z)
	var hole := Vector3i(exit_cell.x + 4, exit_cell.y, exit_cell.z)
	rescue["freed"] = true
	rescue["captive_exited"] = false
	rescue["abandoned"] = false
	state.set_pos3(merc, stand)
	state.set_pos3(captive, hole)
	var dist: Dictionary = {}
	dist[stand] = 3
	dist[hole] = 4
	rescue["exit_dist"] = dist
	var merc_immune: bool = merc.advantage_immune
	var captive_immune: bool = captive.advantage_immune
	merc.advantage_immune = true
	captive.advantage_immune = true
	state.start_of_turn(merc)
	var lines: Array[String] = []
	var turn: Dictionary = {}
	var before: int = int(rescue["fall_back_turns"])
	var bent: Dictionary = RescueDirector.redirect(merc, {"type": "attack"}, state, turn, lines)
	TestFixtures.check(res, "the first action of a fall back turn becomes a walk",
		str(bent.get("type", "")) == "move" and str(bent.get("action_name", "")) == "Move Far"
		and int(rescue["fall_back_turns"]) == before + 1,
		"type %s" % str(bent.get("type", "")))
	var goal: Vector3i = bent.get("goal_cell", PathTargeter.NO_CELL) as Vector3i
	TestFixtures.check(res, "a rescuer who may not leave yet stops beside the exit",
		goal != exit_cell and RescueGrid.is_adjacent(goal, exit_cell),
		"goal (%d,%d) of exit (%d,%d)" % [goal.x, goal.y, exit_cell.x, exit_cell.y])
	state.start_of_turn(captive)
	var c_turn: Dictionary = {}
	var c_bent: Dictionary = RescueDirector.redirect(captive, {"type": "attack"}, state, c_turn, lines)
	TestFixtures.check(res, "the captive aims at the exit cell itself",
		str(c_bent.get("type", "")) == "move"
		and (c_bent.get("goal_cell", PathTargeter.NO_CELL) as Vector3i) == exit_cell,
		"type %s" % str(c_bent.get("type", "")))
	var later: Dictionary = {"rescue_opened": true}
	var swing: Dictionary = RescueDirector.redirect(merc, {"type": "attack"}, state, later, lines)
	TestFixtures.check(res, "a swing still lands once the turn has been bent",
		str(swing.get("type", "")) == "attack", "type %s" % str(swing.get("type", "")))
	var step: Dictionary = RescueDirector.redirect(merc, {"type": "move", "action_name": "Move To"},
		state, later, lines)
	TestFixtures.check(res, "a later move is aimed at the exit too",
		str(step.get("action_name", "")) == "Move Far" and step.has("goal_cell"),
		"action %s" % str(step.get("action_name", "")))
	merc.advantage_immune = merc_immune
	captive.advantage_immune = captive_immune


static func _case_leaving(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the leaving case builds a dungeon"):
		return
	var state: BattleState = fx.state
	var party: Array[MercenaryData] = fx.party
	var rescue: Dictionary = state.rescue
	var exit_cell: Vector3i = rescue["exit_cell"]
	if exit_cell == PathTargeter.NO_CELL or party.size() < 2:
		_missing(res, "the leaving case finds an exit")
		return
	var first: MercenaryData = party[0]
	var second: MercenaryData = party[1]
	rescue["freed"] = true
	rescue["captive_exited"] = false
	rescue["abandoned"] = false
	rescue["party_exits"] = 0
	var postures: Dictionary = rescue["postures"]
	postures[first] = RescueTactics.POSTURE_WITHDRAW
	state.set_pos3(first, exit_cell)
	var lines: Array[String] = []
	RescueSystem.start_of_turn(first, state, lines)
	TestFixtures.check(res, "a withdrawing rescuer on the exit walks out",
		first.off_field and state.exited.has(first) and int(rescue["party_exits"]) == 1,
		"off field %s exits %d" % [str(first.off_field), int(rescue["party_exits"])])
	postures[second] = RescueTactics.POSTURE_FALL_BACK
	state.set_pos3(second, exit_cell)
	RescueSystem.start_of_turn(second, state, lines)
	TestFixtures.check(res, "a falling back rescuer holds the exit for the captive",
		not second.off_field and not state.exited.has(second),
		"off field %s" % str(second.off_field))
	rescue["captive_exited"] = true
	RescueSystem.start_of_turn(second, state, lines)
	TestFixtures.check(res, "once the captive is out the rest may follow",
		second.off_field and state.exited.has(second),
		"off field %s exits %d" % [str(second.off_field), int(rescue["party_exits"])])


static func _case_battle_continues(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the walked out case builds a dungeon"):
		return
	var state: BattleState = fx.state
	var party: Array[MercenaryData] = fx.party
	var captive: MercenaryData = fx.captive
	var rescue: Dictionary = state.rescue
	if party.size() < 2:
		_missing(res, "the walked out case finds a party")
		return
	var lines: Array[String] = []
	RescueSystem.free_captive(state, lines, null, false)
	RescueDirector.leave(captive, state, lines)
	TestFixtures.check(res, "the fight runs on after the captive is out",
		not state.is_battle_over() and bool(rescue["captive_exited"]),
		"over %s" % str(state.is_battle_over()))
	for m: MercenaryData in party:
		RescueDirector.leave(m, state, lines)
	TestFixtures.check(res, "the battle ends when the last rescuer walks out",
		state.is_battle_over(), "over %s" % str(state.is_battle_over()))
	rescue["alarm"] = true
	RescueOutcome.on_battle_end(state, lines)
	var ro: Dictionary = RescueOutcome.outcome(state)
	TestFixtures.check(res, "walking out after the alarm still wins the rescue",
		bool(ro["success"]) and str(ro["reason"]) == "exit_fight"
		and int(ro["party_exits"]) == party.size(),
		"reason %s exits %d" % [str(ro["reason"]), int(ro["party_exits"])])


static func _case_withdrew(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the pull out case builds a dungeon"):
		return
	var state: BattleState = fx.state
	var party: Array[MercenaryData] = fx.party
	var rescue: Dictionary = state.rescue
	if party.is_empty():
		_missing(res, "the pull out case finds a party")
		return
	var lines: Array[String] = []
	for m: MercenaryData in party:
		RescueDirector.leave(m, state, lines)
	TestFixtures.check(res, "a party can pull out and leave the captive caged",
		int(rescue["party_exits"]) == party.size() and not bool(rescue["freed"]),
		"exits %d freed %s" % [int(rescue["party_exits"]), str(rescue["freed"])])
	RescueOutcome.on_battle_end(state, lines)
	var ro: Dictionary = RescueOutcome.outcome(state)
	TestFixtures.check(res, "a rescue nobody finished is a failure with its own reason",
		not bool(ro["success"]) and str(ro["result"]) == RescueSystem.RESULT_FAILED
		and str(ro["reason"]) == "withdrew",
		"result %s reason %s" % [str(ro["result"]), str(ro["reason"])])


static func _case_blocked_decision(res: Dictionary) -> void:
	var detour: String = RescueWalk.blocked_decision(true, false, false, true, true, true)
	TestFixtures.check(res, "a detour beats every other answer",
		detour == RescueSystem.CALL_DETOUR, "call %s" % detour)
	var walk: String = RescueWalk.blocked_decision(false, true, false, true, true, true)
	TestFixtures.check(res, "a merc still short of the blocker keeps walking",
		walk == RescueSystem.CALL_GO, "call %s" % walk)
	var caged: String = RescueWalk.blocked_decision(false, false, true, true, true, true)
	TestFixtures.check(res, "the captive never springs an ambush",
		caged == RescueSystem.CALL_WAIT, "call %s" % caged)
	var strike: String = RescueWalk.blocked_decision(false, false, false, true, false, true)
	TestFixtures.check(res, "favorable odds spring the ambush",
		strike == RescueSystem.CALL_AMBUSH, "call %s" % strike)
	var out: String = RescueWalk.blocked_decision(false, false, false, false, true, true)
	TestFixtures.check(res, "poor odds before the cell opens pull the party out",
		out == RescueSystem.CALL_ABORT, "call %s" % out)
	var fixed: String = RescueWalk.blocked_decision(false, false, false, false, true, false)
	TestFixtures.check(res, "a fixed guard on the only way out is fought",
		fixed == RescueSystem.CALL_AMBUSH, "call %s" % fixed)
	var moving: String = RescueWalk.blocked_decision(false, false, false, false, false, false)
	TestFixtures.check(res, "a moving enemy on the only way out is waited on",
		moving == RescueSystem.CALL_WAIT, "call %s" % moving)


static func _case_blocked_walk(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the blocked walk case builds a dungeon"):
		return
	var state: BattleState = fx.state
	var enemies: Array[MercenaryData] = fx.enemies
	var rescue: Dictionary = state.rescue
	var lead: MercenaryData = RescueSystem.picker(state)
	if lead == null or enemies.is_empty():
		_missing(res, "the blocked walk case finds a picker")
		return
	var goal: Vector3i = RescueGrid.approach_cell(lead, state)
	if goal == PathTargeter.NO_CELL:
		_missing(res, "the blocked walk case finds a cell to approach")
		return
	var path: Array[Vector3i] = ReachCache.walk_path_for(lead, state, state.pos3(lead), goal)
	if path.size() < 4:
		_missing(res, "the blocked walk case finds a walk with room for a blocker")
		return
	var foe: MercenaryData = enemies[0]
	var away := Vector3i(goal.x + 500, goal.y + 500, goal.z)
	var home: Dictionary = {}
	for e: MercenaryData in enemies:
		home[e] = state.pos3(e)
		state.set_pos3(e, away)
	var saved_alarm: bool = bool(rescue["alarm"])
	var counts: Dictionary = rescue["block_waits"]
	var lines: Array[String] = []
	TestFixtures.check(res, "an empty walk has nobody blocking it",
		RescueWalk.path_blocker(state, path) == null, "%d cell(s) on the walk" % path.size())
	state.set_pos3(foe, path[2])
	var found: MercenaryData = RescueWalk.path_blocker(state, path)
	TestFixtures.check(res, "an enemy standing on the walk is found", found == foe,
		"blocker %s" % ("none" if found == null else found.merc_name))
	counts.clear()
	var open_call: String = RescueWalk.blocked_call(lead, state, goal, lines)
	TestFixtures.check(res, "a free cell before the blocker keeps the walk going",
		open_call == RescueSystem.CALL_GO, "call %s" % open_call)
	counts[lead] = RescueSystem.BLOCK_WAITS
	var around: Array[Vector3i] = RescueWalk.detour_path(lead, state, goal)
	if around.is_empty():
		_missing(res, "the blocked walk case finds a way around the blocker")
	else:
		var before: int = int(rescue["detours"])
		var turn_call: String = RescueWalk.blocked_call(lead, state, goal, lines)
		TestFixtures.check(res, "a merc out of waits takes the way around",
			turn_call == RescueSystem.CALL_DETOUR and int(rescue["detours"]) == before + 1,
			"call %s detours %d" % [turn_call, int(rescue["detours"])])
	for e: MercenaryData in enemies:
		state.set_pos3(e, away)
	var clear_call: String = RescueWalk.blocked_call(lead, state, goal, lines)
	TestFixtures.check(res, "a cleared way drops the merc's wait count",
		clear_call == RescueSystem.CALL_GO and not counts.has(lead),
		"call %s waiting %d" % [clear_call, counts.size()])
	state.set_pos3(foe, path[1])
	var detour: Array[Vector3i] = RescueWalk.detour_path(lead, state, goal)
	var sound: bool = detour.is_empty() or (detour[0] == state.pos3(lead)
		and detour[detour.size() - 1] == goal and not detour.has(path[1]))
	TestFixtures.check(res, "a way around never steps on the blocker", sound,
		"%d cell(s) around" % detour.size())
	rescue["alarm"] = false
	counts.clear()
	var exposed: bool = not RescueGrid.cell_seers(state, state.pos3(lead), lead).is_empty()
	var wait_call: String = RescueWalk.blocked_call(lead, state, goal, lines)
	if exposed:
		TestFixtures.check(res, "a merc already in sight does not stand and wait",
			(wait_call == RescueSystem.CALL_DETOUR or wait_call == RescueSystem.CALL_AMBUSH
			or wait_call == RescueSystem.CALL_ABORT) and int(counts.get(lead, 0)) == 0,
			"call %s" % wait_call)
	else:
		TestFixtures.check(res, "a blocker at the elbow makes an unseen merc wait",
			wait_call == RescueSystem.CALL_WAIT and int(counts.get(lead, 0)) == 1
			and _line_holding(lines, "waits for the way to clear (1/3)"),
			"call %s waiting %d" % [wait_call, int(counts.get(lead, 0))])
	for e: MercenaryData in enemies:
		state.set_pos3(e, home[e] as Vector3i)
	counts.clear()
	rescue["alarm"] = saved_alarm
	rescue["aborted"] = false
	rescue["detours"] = 0
	rescue["ambushes"] = 0
	rescue["block_wait_turns"] = 0


static func _case_ambush_abort(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the ambush case builds a dungeon"):
		return
	var state: BattleState = fx.state
	var party: Array[MercenaryData] = fx.party
	var enemies: Array[MercenaryData] = fx.enemies
	var captive: MercenaryData = fx.captive
	var rescue: Dictionary = state.rescue
	var lead: MercenaryData = RescueSystem.picker(state)
	if lead == null or party.is_empty() or enemies.is_empty():
		_missing(res, "the ambush case finds a picker")
		return
	var foe: MercenaryData = enemies[0]
	var lines: Array[String] = []
	RescueStealth.spring_ambush(state, lead, foe, lines)
	var hidden: int = 0
	for m: MercenaryData in state.teams[0]:
		if ConstStates.has_state(m, RescueSystem.STATE_HIDDEN):
			hidden += 1
	TestFixtures.check(res, "a sprung ambush rouses the dungeon and ends every hiding place",
		bool(rescue["alarm"]) and int(rescue["alarm_round"]) == state.round_number
		and int(rescue["ambushes"]) == 1 and hidden == 0 and _line_with(lines, "AMBUSH:"),
		"alarm %s hidden %d ambushes %d" % [str(rescue["alarm"]), hidden, int(rescue["ambushes"])])
	var said: int = lines.size()
	RescueStealth.spring_ambush(state, lead, foe, lines)
	TestFixtures.check(res, "the same ambush is never sprung twice",
		int(rescue["ambushes"]) == 1 and lines.size() == said,
		"ambushes %d line(s) %d" % [int(rescue["ambushes"]), lines.size()])
	rescue["alarm"] = false
	RescueWalk.abort(state, lines)
	TestFixtures.check(res, "a shut way and poor odds pull the party out",
		bool(rescue["aborted"]) and _line_holding(lines, "the party pulls out"),
		"aborted %s" % str(rescue["aborted"]))
	said = lines.size()
	RescueWalk.abort(state, lines)
	TestFixtures.check(res, "the party gives the captive up only once", lines.size() == said,
		"%d line(s) after the second call" % lines.size())
	var leaves: bool = RescueTactics.may_leave(party[0], state)
	rescue["aborted"] = false
	var stays: bool = RescueTactics.may_leave(party[0], state)
	rescue["aborted"] = true
	TestFixtures.check(res, "only a party that gave up walks out with the captive still caged",
		leaves and not stays, "aborted %s plain %s" % [str(leaves), str(stays)])
	TestFixtures.check(res, "the abort reason has its own plain words",
		RescueOutcome.reason_text("aborted") == "the party left unseen without the captive",
		RescueOutcome.reason_text("aborted"))
	var caged_lines: Array[String] = []
	TestFixtures.check(res, "a caged captive still spends its turn under the director",
		RescueSystem.run_turn(captive, state, caged_lines, 0)
		and _line_holding(caged_lines, "waits behind the bars"),
		"%d line(s)" % caged_lines.size())
	for m: MercenaryData in party:
		RescueDirector.leave(m, state, lines)
	RescueOutcome.on_battle_end(state, lines)
	var ro: Dictionary = RescueOutcome.outcome(state)
	TestFixtures.check(res, "a party that walked out unseen fails the rescue with the abort reason",
		not bool(ro["success"]) and str(ro["reason"]) == "aborted" and bool(ro["aborted"]),
		"reason %s success %s" % [str(ro["reason"]), str(ro["success"])])


#A freed captive inside its cell is out of reach of every enemy and holds to the cell.
static func _check_cell_shelter(res: Dictionary, state: BattleState, merc: MercenaryData,
	captive: MercenaryData, foe: MercenaryData) -> void:
	var rescue: Dictionary = state.rescue
	TestFixtures.check(res, "a freed captive inside its cell keeps out of reach",
		RescueSystem.shelters(state, captive) and not RescueSystem.shelters(state, merc),
		"captive %s rescuer %s" % [str(RescueSystem.shelters(state, captive)),
		str(RescueSystem.shelters(state, merc))])
	var targets: Array[MercenaryData] = state.get_enemies(foe)
	TestFixtures.check(res, "the enemy target list drops the sheltering captive and keeps the party",
		not targets.has(captive) and targets.has(merc), "%d target(s)" % targets.size())
	TestFixtures.check(res, "no enemy may swing at the sheltering captive",
		not AutoBattle.can_attack_target(foe, captive, state), "the attack was allowed")
	var reactions: Array = ReactiveActionSystem.get_triggered_reactions("enemy_leaves_melee_range",
		captive, Vector2i.ZERO, Vector2i.ZERO, state)
	TestFixtures.check(res, "the sheltering captive draws no reactions", reactions.is_empty(),
		"%d reaction(s)" % reactions.size())
	if RescueTactics.route_safe(captive, state, rescue["exit_cell"] as Vector3i) \
			or RescueTactics.party_leaving(state):
		_missing(res, "the untargetable case spoils the captive's way out")
	else:
		var call_row: Dictionary = RescueTactics._decide(captive, state)
		TestFixtures.check(res, "a cornered captive that has not acted keeps to its cell",
			str(call_row["posture"]) == RescueTactics.POSTURE_HOLD and int(call_row["rule"]) == 15,
			"%s/%d" % [str(call_row["posture"]), int(call_row["rule"])])
		rescue["captive_rule"] = 15
		TestFixtures.check(res, "the party reads the kept cell as shelter",
			RescueTactics._captive_sheltering(state), "rule %d" % RescueTactics.captive_rule(state))


#Stepping out of the cell makes the captive a target and stepping back in puts it out of reach.
static func _check_cell_step(res: Dictionary, state: BattleState, captive: MercenaryData,
	foe: MercenaryData, stand: Vector3i, cell: Vector3i) -> void:
	state.set_pos3(captive, stand)
	var outside: Array[MercenaryData] = state.get_enemies(foe)
	TestFixtures.check(res, "a captive that steps out of its cell can be fought",
		not RescueSystem.shelters(state, captive) and outside.has(captive),
		"%d target(s)" % outside.size())
	state.set_pos3(captive, cell)
	TestFixtures.check(res, "a captive back inside its cell is out of reach again",
		RescueSystem.shelters(state, captive), "the cell no longer sheltered")


#Gear taken by a rescuer says nothing; gear taken by the captive makes it a target where it stands.
static func _check_cell_gear(res: Dictionary, state: BattleState, merc: MercenaryData,
	captive: MercenaryData, lines: Array[String]) -> void:
	var rescue: Dictionary = state.rescue
	var said: int = lines.size()
	RescueSystem.on_gear_taken(merc, state, lines)
	TestFixtures.check(res, "a rescuer taking gear says nothing about the captive",
		not bool(rescue["captive_acted"]) and lines.size() == said,
		"acted %s line(s) %d" % [str(rescue["captive_acted"]), lines.size()])
	RescueSystem.on_gear_taken(captive, state, lines)
	TestFixtures.check(res, "gear in the captive's hands makes it a target where it stands",
		bool(rescue["captive_acted"]) and _line_holding(lines, "can be targeted")
		and not RescueSystem.shelters(state, captive), "acted %s" % str(rescue["captive_acted"]))


#The acted latch: a swing or a turn reset marks the captive and the shelter rule is not given again.
static func _check_cell_acted(res: Dictionary, state: BattleState,
	captive: MercenaryData) -> void:
	var rescue: Dictionary = state.rescue
	rescue["captive_acted"] = false
	captive.turn_attack_total = 1
	var struck: bool = RescueSystem.shelters(state, captive)
	TestFixtures.check(res, "a captive that struck this turn loses its shelter",
		not struck and bool(rescue["captive_acted"]), "acted %s" % str(rescue["captive_acted"]))
	rescue["captive_acted"] = false
	captive.turn_attack_total = 0
	RescueSystem.on_turn_reset(captive, state)
	var quiet: bool = bool(rescue["captive_acted"])
	captive.turn_attack_total = 1
	RescueSystem.on_turn_reset(captive, state)
	TestFixtures.check(res, "the turn reset latches a captive that swung and spares one that did not",
		bool(rescue["captive_acted"]) and not quiet, "quiet %s" % str(quiet))
	captive.turn_attack_total = 0
	var after: Dictionary = RescueTactics._decide(captive, state)
	TestFixtures.check(res, "a captive that has acted is never given the shelter rule again",
		int(after["rule"]) != 15, "%s/%d" % [str(after["posture"]), int(after["rule"])])


#The rescue outcome carries the new counters.
static func _check_cell_outcome(res: Dictionary, state: BattleState) -> void:
	var ro: Dictionary = RescueOutcome.outcome(state)
	TestFixtures.check(res, "the outcome carries the new rescue counters",
		ro.has("aborted") and ro.has("detours") and ro.has("ambushes")
		and ro.has("block_wait_turns") and ro.has("captive_acted"), "%d key(s)" % ro.size())


static func _case_untargetable(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the untargetable case builds a dungeon"):
		return
	var state: BattleState = fx.state
	var party: Array[MercenaryData] = fx.party
	var enemies: Array[MercenaryData] = fx.enemies
	var captive: MercenaryData = fx.captive
	var rescue: Dictionary = state.rescue
	var rect: Rect2i = rescue["cell_rect"]
	var chest_cell: Vector3i = rescue["chest_cell"]
	var stand: Vector3i = RescueGrid.adjacent_free_cell(state, chest_cell, captive)
	var inside: Array[Vector3i] = RescueGrid.free_cells(fx.field, state, rect,
		int(rescue["cell_floor"]), captive)
	if party.is_empty() or enemies.is_empty() or inside.is_empty() \
			or stand == PathTargeter.NO_CELL or rect.has_point(Vector2i(stand.x, stand.y)):
		_missing(res, "the untargetable case finds a cell and a chest")
		return
	var merc: MercenaryData = party[0]
	var foe: MercenaryData = enemies[0]
	var home: Vector3i = state.pos3(captive)
	var cell: Vector3i = inside[0]
	var lines: Array[String] = []
	RescueSystem.free_captive(state, lines, null, false)
	state.set_pos3(captive, cell)
	state.set_pos3(foe, Vector3i(cell.x + 5, cell.y, cell.z))
	captive.turn_attack_total = 0
	captive.current_hp = _max_hp(captive)
	rescue["captive_acted"] = false
	rescue["chest_given_up"] = true
	rescue["abandoned"] = false
	_heal(party)
	for e: MercenaryData in enemies:
		e.current_hp = 1
	_check_cell_shelter(res, state, merc, captive, foe)
	_check_cell_step(res, state, captive, foe, stand, cell)
	_check_cell_gear(res, state, merc, captive, lines)
	_check_cell_acted(res, state, captive)
	_check_cell_outcome(res, state)
	state.set_pos3(captive, home)
	captive.turn_attack_total = 0
	rescue["captive_acted"] = false
	rescue["captive_rule"] = 0
	rescue["chest_given_up"] = false
	_heal(enemies)


static func _case_tune(res: Dictionary, fx: RescueFx) -> void:
	if not _has_fx(res, fx, "the tune case builds a dungeon"):
		return
	var bad: bool = RescueTune.set_tune("no_such_name", 1.0)
	var good: bool = RescueTune.set_tune("go_margin", 0.25)
	TestFixtures.check(res, "only a named tunable can be set",
		not bad and good and is_equal_approx(RescueTune.tuned("go_margin"), 0.25)
		and RescueTune.tune_text().contains("go_margin"), "tune %s" % RescueTune.tune_text())
	RescueTune.reset_tune()
	TestFixtures.check(res, "a reset table reports itself plain",
		RescueTune.tune_text() == "default", "tune %s" % RescueTune.tune_text())
	TestFixtures.check(res, "the need curve runs from dire odds to none",
		is_equal_approx(RescueTactics.need(0.5), 1.0) and is_equal_approx(RescueTactics.need(1.25), 0.0),
		"need %d%% / %d%%" % [roundi(RescueTactics.need(0.5) * 100.0),
		roundi(RescueTactics.need(1.25) * 100.0)])
	RescueTune.set_tune("need_zero_odds", 2.0)
	TestFixtures.check(res, "a raised zero point keeps the party wanting the captive",
		RescueTactics.need(1.25) > 0.0, "need %d%%" % roundi(RescueTactics.need(1.25) * 100.0))
	RescueTune.reset_tune()
	var stage: Dictionary = _stage_gate(fx, 1, 100)
	if stage.is_empty():
		_missing(res, "the tune case finds a gate")
		return
	var state: BattleState = fx.state
	var party: Array[MercenaryData] = fx.party
	var enemies: Array[MercenaryData] = fx.enemies
	var captive: MercenaryData = fx.captive
	var rescue: Dictionary = state.rescue
	var gate: Dictionary = stage["gate"]
	var saved_d: int = stage["saved_d"]
	var lines: Array[String] = []
	RescueTactics.evaluate_gate(state, lines)
	TestFixtures.check(res, "the default margin lets a losing party open the cell",
		bool(rescue["gate_go"]), "go %s" % str(rescue["gate_go"]))
	RescueTune.set_tune("go_margin", 1000.0)
	rescue["gate_eval_round"] = -1
	RescueTactics.evaluate_gate(state, lines)
	TestFixtures.check(res, "a raised margin leaves the same cell shut",
		not bool(rescue["gate_go"]), "go %s" % str(rescue["gate_go"]))
	RescueTune.reset_tune()
	gate[DungeonLocks.DIFFICULTY_KEY] = saved_d
	gate[DungeonLocks.FAILS_KEY] = 0
	rescue["gate_go"] = false
	rescue["gate_hopeless"] = false
	rescue["gate_eval_round"] = 0
	captive.current_hp = _max_hp(captive)
	_heal(party)
	_heal(enemies)
