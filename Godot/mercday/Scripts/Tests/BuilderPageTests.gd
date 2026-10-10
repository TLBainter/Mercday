class_name BuilderPageTests

#Contract builder page 1, OverviewPage, hosted in the scene tree: the widgets, the name and level filters, the type
#suggestions and template copy, the issuer lists, the Load existing pick, completeness and the draft round trip.
#Page 2, LocationPage, in the same host: the row lists, the buttons, unknown rows, the shares and the row sync.
#Pages 3 and 5, TargetPage and DescriptionPage: the source panels and the Target cell, the entries and the tags.
#Page 4, CompletionPage: the Style panels, the check pick, the CheckBuilder modal and its widgets, the event pick,
#the Event Config panel, Time and Consequence; then the shell scene gates Next on pages 2, 4 and 5, walks on to the
#review and gates page 4 again under the event Style.
#The pages read user:// copies of the fourteen fixture sheets (SheetFixtures); tsv_guard checks the res:// sheets kept
#their bytes, fixture_integrity and fixture_untouched check the fixtures.
#Run: godot --headless --path . -- --builder-page-tests

const SCRATCH_DIR: String = "user://builder_page_tests"
const HOST_SIZE: Vector2 = Vector2(1280.0, 720.0)
const WIDGETS: Array[String] = ["load_dropdown", "name_edit", "name_count", "level_slider", "level_min_edit",
	"level_max_edit", "merc_slider", "merc_label", "local_row", "type_edit", "type_caption", "suggestion_box", "issuer_group",
	"issuer_dropdown", "org_row", "org_edit", "org_add", "difficulty_picker", "story_row", "style_group"]
const TEMPLATE_KEYS: Array[String] = ["boosts", "description_template", "target_category", "possible_traits",
	"possible_locations", "terrain_odds"]
const LONG_NAME: int = 30
const PERSON_COUNT: int = 4
const PLACE_COUNT: int = 22
const PERSON_PICK: StringName = &"Noble"
const ORG_NAME: String = "Guild of Lamps"
const TEMPLATE_TYPE: String = "Rescue"
const NEW_TYPE: String = "Heist"
const LOCATION_WIDGETS: Array[String] = ["deselect_all", "select_nations", "select_all", "primary_scroll",
	"sub_scroll"]
const USED_PLACES: Array[String] = ["Aerdis", "Cathistii", "Okun"]
const USED_AREAS: Array[String] = ["Cavern", "Dungeon", "Tavern"]
const AREA_TYPES: Dictionary = {"Exterior": 2, "Cavern": 1, "Dungeon": 1, "City": 2, "TBD": 10, "Interior": 26}
const NATION_COUNT: int = 11
const AREA_COUNT: int = 42
const UNKNOWN_NAME: String = "Atlantis"
const NEW_PLACE: String = "Testland"
const BUILDER_SCENE: String = "res://Scenes/Tools/ContractBuilder.tscn"
const TARGET_WIDGETS: Array[String] = ["source_group", "radio_npc", "radio_monster", "radio_random", "radio_none",
	"npc_panel", "monster_panel", "random_panel", "unknown_label", "npc_dropdown", "type_dropdown", "pick_dropdown",
	"level_group", "radio_level_fixed", "radio_level_party", "radio_level_range", "level_fixed_row", "level_edit",
	"level_range_row", "level_slider", "level_min_edit", "level_max_edit", "count_group", "radio_count_fixed",
	"radio_count_party", "count_edit", "count_suffix", "tradition_dropdown", "skew_dropdown", "creature_dropdown"]
const NPC_TITLES: Array[String] = ["Taverngoer", "Bandit Melee", "Bandit Ranged", "Bandit Leader"]
const CREATURE_COUNT: int = 12
const TRADITION_COUNT: int = 10
const TARGET_LEVEL_MIN: int = 5
const TARGET_LEVEL_MAX: int = 30
const LOADED_RANDOM: String = "random:level=10-20, count=party+1, tradition=Warrior, skew=Vigor, type=Beast"
const ANY_NONE_RANDOM: String = "random:level=party, count=party, tradition=any, type=none"
const ROUND_TRIP_TARGETS: Array[String] = ["", "npc:Bandit Leader", "monster:Beast:all",
	"random:level=party, count=party", LOADED_RANDOM]
const DESCRIPTION_WIDGETS: Array[String] = ["scroll", "entries_box", "add_button"]
const TAG_TEXTS: String = "%target%,%location%,%requestor%"
const COMPLETION_WIDGETS: Array[String] = ["check_panel", "event_panel", "timeline_panel", "check_dropdown",
	"build_button", "pending_label"]
const POISON_VIAL: String = "Poison Vial"
const EVENT_NAMES: Array[String] = ["Poison the Target", "Put on a Show", "Deliver the Prisoner",
	"Identify the Killer", "Assist with the Skirmish", "Slay the Monster", "Save the Trapped Civilian",
	"Dig up the Buried Treasure", "Battle", "Competition", "Rescue the Captive"]
const POISON_ROW: Array[String] = ["Poison Vial", "Dexterity, Wile", "", "", "", "", "1", "60", "No", "", ""]
const BUILT_NAME: String = "Trial of Wit"
const BUILT_ROW: Array[String] = ["Trial of Wit", "Cognition", "Clever (Cognition) 10", "", "", "Mage +15", "1.5",
	"120", "Yes", "", "hp -2"]
const CLEVER: String = "Clever (Cognition)"
const RESERVED_NAMES: Array[String] = ["none", "new:Foo", "unknown:Bar"]
const TL_VALID: String = "a=event:Battle time=60 ; b=check:Poison Vial fail"
const TL_WAIT: String = "a=event:Battle time=60 ; b=event:Battle if a.failure time=60 ; c=check:Poison Vial fail"
const TL_LOOSE: String = "b=event:Battle time=60 ; a=check:Poison Vial fail"
const TL_BAD: String = "a=event:Battle time=60 ; garbage"
const TL_BAD_NAME: String = "Bad; Name"
const TL_STEP_BAD: String = "Wit; Grit"
const PICK_ENTRIES: Array[Dictionary] = [{"key": "Clever (Cognition)", "label": "Clever", "group": "Cognition"},
	{"key": "Notice (Cognition)", "label": "Notice", "group": "Cognition"},
	{"key": "Attack (Dexterity)", "label": "Attack", "group": "Dexterity"},
	{"key": "Endure (Vigor)", "label": "Endure", "group": "Vigor"}]
const SORT_ENTRIES: Array[Dictionary] = [
	{"key": "Rope", "label": "Rope", "group": "", "category": "Gear", "rarity": "Common"},
	{"key": "Atlas", "label": "Atlas", "group": "", "category": "Books", "rarity": "Rare"},
	{"key": "Lockpick", "label": "Lockpick", "group": "", "category": "Gear", "rarity": "Uncommon"},
	{"key": "Codex", "label": "Codex", "group": "", "category": "Books", "rarity": "Legendary"},
	{"key": "Charm", "label": "Charm", "group": "", "category": "", "rarity": "Very Rare"},
	{"key": "Zither", "label": "Zither", "group": "", "category": "Music", "rarity": ""}]

#The share cases tally into these; _case_location_shares reports them as share_load_silent and share_total.
static var _share_bad: Array[String] = []
static var _share_steps: int = 0
static var _share_load_hits: int = 0
static var _share_raw_bad: Array[String] = []


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	var sums: Dictionary = _sheet_sums()
	_case_fixture_check(res, "fixture_integrity")
	var reason: String = _scratch_setup()
	if reason == "":
		await _hosted_cases(res)
	else:
		TestFixtures.check(res, "scratch_setup", false, reason)
	ContractBuilderData.reset_paths()
	_case_tsv_guard(res, sums)
	_case_fixture_check(res, "fixture_untouched")
	return TestFixtures.summarize(res, "BUILDER PAGE")


#The fourteen fixture sheets hold the bytes SheetFixtures.MD5 names.
static func _case_fixture_check(res: Dictionary, key: String) -> void:
	var problems: Array[String] = SheetFixtures.integrity()
	TestFixtures.check(res, key, problems.is_empty(),
		TestFixtures.detail(problems, SheetFixtures.MD5.size(), "fixture sheets off", 3))


static func _hosted_cases(res: Dictionary) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	#run() starts inside the main scene's _ready, where the root refuses add_child until a frame passes.
	await tree.process_frame
	var host: Control = Control.new()
	host.name = "BuilderPageHost"
	host.size = HOST_SIZE
	tree.root.add_child(host)
	if not host.is_inside_tree():
		TestFixtures.check(res, "host_tree", false, "the root did not take the host")
		host.free()
		return
	var page: OverviewPage = OverviewPage.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(page)
	await TestFixtures.frames(host)
	if _case_builds(res, page):
		_case_name_filter(res, page)
		_case_level(res, page)
		_case_type(res, page)
		_case_issuer(res, page)
		_case_difficulty(res, page)
		_case_story_style_roles(res, page)
		_case_load_existing(res, page)
		_case_complete(res, page)
		_case_round_trip(res, page)
		_case_mercs(res, page)
		_case_local(res, page)
		_case_notify(res, page)
	page.queue_free()
	var location: LocationPage = LocationPage.new()
	location.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(location)
	await TestFixtures.frames(host)
	if _case_location_builds(res, location):
		_case_location_buttons(res, location)
		_case_location_store_order(res, location)
		_case_location_unknown(res, location)
		_case_sub_default(res, location)
		_case_sub_slider_edit(res, location)
		_case_sub_load_template(res, location)
		_case_sub_unknown(res, location)
		_case_location_complete(res, location)
		_case_location_round_trip(res, location)
		_case_location_notify(res, location)
		_case_location_shares(res, location)
		_case_location_sync(res, location)
	location.queue_free()
	var target: TargetPage = TargetPage.new()
	target.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(target)
	await TestFixtures.frames(host)
	if _case_target_builds(res, target):
		_case_target_npc(res, target)
		_case_target_monster(res, target)
		_case_target_random_default(res, target)
		_case_target_random_fields(res, target)
		_case_target_load(res, target)
		_case_target_unknown_values(res, target)
		_case_target_unparseable(res, target)
		_case_target_complete(res, target)
		_case_target_round_trip(res, target)
		_case_target_notify(res, target)
	target.queue_free()
	var description: DescriptionPage = DescriptionPage.new()
	description.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(description)
	await TestFixtures.frames(host)
	if _case_description_builds(res, description):
		_case_description_add_remove(res, description)
		await _case_description_tag_insert(res, description)
		_case_description_store_collapse(res, description)
		_case_description_load(res, description)
		_case_description_complete(res, description)
		_case_description_round_trip(res, description)
		await _case_description_notify(res, description)
	description.queue_free()
	_case_completion_check_row(res)
	var completion: CompletionPage = CompletionPage.new()
	completion.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(completion)
	await TestFixtures.frames(host)
	if _case_completion_builds(res, completion):
		_case_completion_event_pick(res, completion)
		_case_completion_check_empty(res, completion)
		_case_completion_pick_existing(res, completion)
		_case_completion_load_unknown(res, completion)
		await _case_completion_build_new(res, completion)
		_case_completion_builder_rejects(res, completion)
		_case_completion_edit_new(res, completion)
		_case_completion_pick_drops_new(res, completion)
		_case_completion_style_mismatch(res, completion)
		_case_completion_cancel(res, completion)
		_case_completion_notify(res, completion)
		_case_completion_reserved_names(res, completion)
		_case_event_panel_rows(res, completion)
		_case_event_pick_fresh(res, completion)
		_case_event_planned(res, completion)
		_case_event_chase(res, completion)
		_case_event_time(res, completion)
		_case_event_consequence(res, completion)
		_case_event_load_round_trip(res, completion)
		_case_event_unknown_loaded(res, completion)
		_case_event_bad_config_loaded(res, completion)
		_case_event_none(res, completion)
		_case_event_style_mismatch(res, completion)
		_case_event_check_untouched(res, completion)
		_case_event_notify(res, completion)
		_case_event_time_unshown(res, completion)
		_case_event_consequence_bad(res, completion)
		_case_event_completion_text(res, completion)
		_case_event_sheet_unknown_name(res, completion)
		_case_check_builder_lists(res, completion)
		_case_tl_fresh_two_steps(res, completion)
		_case_tl_unnamed_step_survives_previous(res, completion)
		_case_tl_add_step_moves_fail(res, completion)
		_case_tl_add_step_disabled_at_max(res, completion)
		_case_tl_add_branch_failure(res, completion)
		_case_tl_add_branch_success_when_flagged(res, completion)
		_case_tl_add_branch_disabled_on_last(res, completion)
		_case_tl_remove_resets_when(res, completion)
		_case_tl_remove_min_disabled(res, completion)
		_case_tl_remove_last_new_last_fails(res, completion)
		_case_tl_remove_no_waiter_no_note(res, completion)
		_case_tl_move_refused(res, completion)
		_case_tl_move_into_last_refused(res, completion)
		_case_tl_move_ok_renumber(res, completion)
		_case_tl_last_fail_locked(res, completion)
		_case_tl_fail_on_with_failure_dependents(res, completion)
		_case_tl_when_options_earlier_only(res, completion)
		_case_tl_when_hides_dead_branch(res, completion)
		_case_tl_kind_switch_clears(res, completion)
		_case_tl_event_pick_time_default(res, completion)
		_case_tl_event_step_no_time_shows_default(res, completion)
		_case_tl_cfg_per_step(res, completion)
		_case_tl_cons_per_step(res, completion)
		_case_tl_role_list(res, completion)
		_case_tl_role_stale_blocks(res, completion)
		_case_tl_unknown_names_pass(res, completion)
		_case_tl_name_disabled_rule(res, completion)
		_case_tl_load_valid_verbatim(res, completion)
		_case_tl_first_edit_canonical(res, completion)
		_case_tl_load_rule_error_kept(res, completion)
		_case_tl_load_bad_kept(res, completion)
		_case_tl_start_over(res, completion)
		_case_tl_next_gate(res, completion)
		_case_tl_status_lines_joined(res, completion)
		_case_tl_one_notify_per_action(res, completion)
		_case_tl_load_silent(res, completion)
		_case_tl_clear_to_check(res, completion)
		_case_tl_clear_to_event(res, completion)
		_case_tl_clear_to_blank(res, completion)
		_case_tl_clear_keeps_plain_text(res, completion)
		_case_tl_clear_row_time(res, completion)
		_case_tl_clear_row_time_after_check(res, completion)
		_case_tl_unused_pending_dropped(res, completion)
		_case_tl_pending_kept_while_unreadable(res, completion)
		_case_tl_id_type_ok(res, completion)
		_case_tl_id_refused_keeps_old(res, completion)
		_case_tl_id_clear_returns_auto(res, completion)
		_case_tl_id_rename_updates_when(res, completion)
		_case_tl_id_typed_survives_renumber(res, completion)
		_case_tl_id_load_typed_kept(res, completion)
		_case_tl_id_commit_one_notify(res, completion)
		_case_tl_id_unsubmitted_commits_on_select(res, completion)
		_case_tl_build_check_step(res, completion)
		_case_tl_build_keeps_cell(res, completion)
		_case_tl_build_two_checks(res, completion)
		_case_tl_build_shared_check(res, completion)
		_case_tl_edit_check_renames_all_steps(res, completion)
		_case_tl_build_dup_refused(res, completion)
		_case_tl_build_name_rule_refused(res, completion)
		_case_tl_check_style_builder_unaffected(res, completion)
		_case_review_timeline_new_checks(res)
	_close_builder(completion.builder())
	completion.queue_free()
	_case_tradition_balance(res)
	_case_duration_control(res, host)
	_case_consequence_steppers(res, host)
	_case_percent_pick_list(res, host)
	_case_pick_check_floor(res, host)
	_case_pick_sort_name(res, host)
	_case_pick_sort_category(res, host)
	_case_pick_sort_rarity(res, host)
	_case_pick_sort_picked(res, host)
	_case_pick_sort_unknown(res, host)
	_case_pick_sort_keeps_binding(res, host)
	_case_pick_hide(res, host)
	_case_pick_view_silent(res, host)
	_case_pick_view_kept(res, host)
	_case_pick_caption(res, host)
	_case_pick_marks(res, host)
	_case_pick_colors(res)
	_case_pick_search_marks(res, host)
	_case_pick_check_width(res, host)
	_case_hide_menu(res, host)
	_case_hide_menu_marks(res, host)
	await _case_shell(res, host)
	host.queue_free()
	await tree.process_frame


static func _case_builds(res: Dictionary, page: OverviewPage) -> bool:
	var missing: Array[String] = []
	for key: String in WIDGETS:
		if page.get(key) == null:
			missing.append(key)
	if page.issuer_buttons.size() != OverviewPage.ISSUER_KEYS.size():
		missing.append("issuer_buttons")
	if page.style_buttons.size() != OverviewPage.STYLE_KEYS.size():
		missing.append("style_buttons")
	if page.role_rows.size() != OverviewPage.FIXED_ROLES.size() + OverviewPage.OPTIONAL_ROLES.size():
		missing.append("role_rows")
	TestFixtures.check(res, "builds_widgets", missing.is_empty(),
		TestFixtures.detail(missing, WIDGETS.size() + 3, "widgets missing"))
	if not missing.is_empty():
		return false
	var loads: int = page.load_dropdown.options.size()
	var names: int = ContractBuilderData.contract_names().size()
	TestFixtures.check(res, "builds_new_draft", not page.is_complete() and page.name_count.text == "0 / 24"
		and loads == names + 1 and page.load_dropdown.button_text() == OverviewPage.NEW_LABEL,
		"complete %s, count '%s', %d load options for %d names, shown '%s'" % [page.is_complete(),
			page.name_count.text, loads, names, page.load_dropdown.button_text()])
	return true


static func _case_name_filter(res: Dictionary, page: OverviewPage) -> void:
	page.load_draft(ContractDraft.new())
	_type_into(page.name_edit, "Res\tcue \"x\"")
	TestFixtures.check(res, "name_filter_chars", page.name_edit.text == "Rescue x"
		and page.name_edit.caret_column == 8 and page.name_count.text == "8 / 24",
		"text '%s', caret %d, count '%s'" % [page.name_edit.text, page.name_edit.caret_column, page.name_count.text])
	page.load_draft(ContractDraft.new())
	var long: String = "A".repeat(LONG_NAME)
	_type_into(page.name_edit, long)
	var cut: String = long.left(ContractDraft.NAME_MAX)
	TestFixtures.check(res, "name_filter_cut", page.name_edit.text == cut and page.name_count.text == "24 / 24",
		"%d characters, count '%s'" % [page.name_edit.text.length(), page.name_count.text])
	_type_into(page.name_edit, cut + "B")
	TestFixtures.check(res, "name_filter_full", page.name_edit.text == cut,
		"%d characters after one more" % page.name_edit.text.length())
	var tagged: String = "%target% Rescue"
	_type_into(page.name_edit, tagged)
	TestFixtures.check(res, "name_filter_tag", page.name_edit.text == tagged
		and ContractDraft.name_length(tagged) == 7 and page.name_count.text == "7 / 24",
		"text '%s', count '%s'" % [page.name_edit.text, page.name_count.text])
	var draft: ContractDraft = ContractDraft.new()
	page.store_draft(draft)
	TestFixtures.check(res, "name_store", draft.contract_name == tagged, "stored '%s'" % draft.contract_name)


static func _case_level(res: Dictionary, page: OverviewPage) -> void:
	page.load_draft(ContractDraft.new())
	TestFixtures.check(res, "level_new_draft", _levels(page) == "0-240 shown 0-240", _levels(page))
	page.level_slider.set_range_silent(10.0, 50.0)
	page.level_slider.range_changed.emit(page.level_slider.low, page.level_slider.high)
	TestFixtures.check(res, "level_slide", _levels(page) == "10-50 shown 10-50", _levels(page))
	_submit(page.level_max_edit, "300")
	TestFixtures.check(res, "level_max_clamp", _levels(page) == "10-240 shown 10-240", _levels(page))
	_submit(page.level_max_edit, "60")
	_submit(page.level_min_edit, "80")
	TestFixtures.check(res, "level_min_above_max", _levels(page) == "60-60 shown 60-60", _levels(page))
	_type_into(page.level_min_edit, "2x5")
	var typed: String = page.level_min_edit.text
	page.level_min_edit.focus_exited.emit()
	TestFixtures.check(res, "level_digits_only", typed == "25" and _levels(page) == "25-60 shown 25-60",
		"typed '%s', %s" % [typed, _levels(page)])
	_submit(page.level_min_edit, "")
	TestFixtures.check(res, "level_blank_reverts", _levels(page) == "25-60 shown 25-60", _levels(page))
	var draft: ContractDraft = ContractDraft.new()
	page.store_draft(draft)
	TestFixtures.check(res, "level_store", draft.level_min == 25 and draft.level_max == 60,
		"stored %d-%d" % [draft.level_min, draft.level_max])
	page.load_draft(ContractDraft.new())
	TestFixtures.check(res, "level_reload_new", _levels(page) == "0-240 shown 0-240", _levels(page))


static func _case_type(res: Dictionary, page: OverviewPage) -> void:
	page.load_draft(ContractDraft.new())
	var all: int = mini(OverviewPage.SUGGESTION_MAX, ContractBuilderData.contract_type_names().size())
	TestFixtures.check(res, "type_all_listed", _shown(page).size() == all and not page.type_caption.visible,
		"%d of %d shown, caption '%s'" % [_shown(page).size(), all, page.type_caption.text])
	_type_into(page.type_edit, "res")
	var pick: BevelButton = _suggestion(page, TEMPLATE_TYPE)
	TestFixtures.check(res, "type_suggest", pick != null, "shown %s" % str(_shown(page)))
	if pick == null:
		return
	pick.pressed.emit()
	TestFixtures.check(res, "type_pick", page.type_edit.text == TEMPLATE_TYPE and not page.type_caption.visible,
		"text '%s', caption '%s'" % [page.type_edit.text, page.type_caption.text])
	var draft: ContractDraft = ContractDraft.new()
	page.store_draft(draft)
	var want: ContractDraft = ContractDraft.new()
	want.apply_template(ContractBuilderData.template_row(TEMPLATE_TYPE))
	var bad: Array[String] = _diff(want.to_dict(), draft.to_dict(), TEMPLATE_KEYS)
	TestFixtures.check(res, "type_template", draft.contract_type == TEMPLATE_TYPE and bad.is_empty()
		and not want.boosts.is_empty(), TestFixtures.detail(bad, TEMPLATE_KEYS.size(), "template cells differ"))
	_type_into(page.type_edit, NEW_TYPE)
	TestFixtures.check(res, "type_new_caption", page.type_caption.visible
		and page.type_caption.text == "New type: " + NEW_TYPE, "caption '%s'" % page.type_caption.text)
	page.store_draft(draft)
	var kept: Array[String] = _diff(ContractDraft.new().to_dict(), draft.to_dict(), TEMPLATE_KEYS)
	TestFixtures.check(res, "type_new_clears", draft.contract_type == NEW_TYPE and kept.is_empty(),
		TestFixtures.detail(kept, TEMPLATE_KEYS.size(), "template cells kept"))


static func _case_issuer(res: Dictionary, page: OverviewPage) -> void:
	page.load_draft(ContractDraft.new())
	var draft: ContractDraft = ContractDraft.new()
	page.issuer_buttons[0].button_pressed = true
	var people: Array[String] = _keys(page.issuer_dropdown)
	page.issuer_dropdown.select(PERSON_PICK, true)
	page.store_draft(draft)
	TestFixtures.check(res, "issuer_person", people == ContractBuilderData.person_issuers()
		and people.size() == PERSON_COUNT and not page.org_row.visible and draft.issuer_type == "person"
		and draft.issuer == String(PERSON_PICK), "options %s, stored '%s' / '%s'" % [str(people),
			draft.issuer_type, draft.issuer])
	page.issuer_buttons[1].button_pressed = true
	var places: Array[String] = _keys(page.issuer_dropdown)
	TestFixtures.check(res, "issuer_place", places == ContractBuilderData.place_names() and places.size() == PLACE_COUNT
		and page.issuer_dropdown.selected == &"" and not page.org_row.visible,
		"%d options, selected '%s'" % [places.size(), page.issuer_dropdown.selected])
	page.issuer_dropdown.open_popup()
	var menu: DropPanel = page.issuer_dropdown.menu
	var shown: Rect2i = Rect2i(menu.get_global_rect())
	var area: Rect2i = Rect2i(page.get_viewport().get_visible_rect())
	var inside: bool = page.issuer_dropdown.popup_open() and area.encloses(shown)
	page.issuer_dropdown.close_popup()
	TestFixtures.check(res, "issuer_place_menu_inside", inside, "menu %s in %s" % [shown, area])
	page.issuer_buttons[2].button_pressed = true
	var orgs: Array[String] = _keys(page.issuer_dropdown)
	TestFixtures.check(res, "issuer_org", orgs.is_empty() and orgs == ContractBuilderData.organization_names()
		and page.org_row.visible, "options %s, row shown %s" % [str(orgs), page.org_row.visible])
	_type_into(page.org_edit, "Bad \"name\"")
	var refused: bool = page.org_add.disabled
	_type_into(page.org_edit, ORG_NAME)
	var allowed: bool = not page.org_add.disabled
	page.org_add.pressed.emit()
	TestFixtures.check(res, "issuer_org_add", refused and allowed and page.org_edit.text == ""
		and page.issuer_dropdown.selected == StringName(ORG_NAME) and page.issuer_dropdown.button_text() == ORG_NAME,
		"refused %s, allowed %s, selected '%s', shown '%s'" % [refused, allowed, page.issuer_dropdown.selected,
			page.issuer_dropdown.button_text()])
	page.store_draft(draft)
	TestFixtures.check(res, "issuer_org_store", draft.issuer_type == "org" and draft.issuer == ORG_NAME,
		"stored '%s' / '%s'" % [draft.issuer_type, draft.issuer])
	page.issuer_buttons[0].button_pressed = true
	page.store_draft(draft)
	TestFixtures.check(res, "issuer_switch_clears", draft.issuer_type == "person" and draft.issuer == ""
		and page.issuer_dropdown.selected == &"" and not page.org_row.visible,
		"stored '%s' / '%s', selected '%s'" % [draft.issuer_type, draft.issuer, page.issuer_dropdown.selected])


static func _case_difficulty(res: Dictionary, page: OverviewPage) -> void:
	page.difficulty_picker.set_range(2.0, 3.0)
	page.load_draft(ContractDraft.new())
	var picker: ToolStarRangePicker = page.difficulty_picker
	TestFixtures.check(res, "difficulty_new_draft", picker.low == StarRangePicker.MIN_VALUE
		and picker.high == StarRangePicker.MAX_VALUE, "loaded %.1f-%.1f" % [picker.low, picker.high])
	picker.set_range(1.0, 3.5)
	picker.range_changed.emit(picker.low, picker.high)
	var draft: ContractDraft = ContractDraft.new()
	page.store_draft(draft)
	TestFixtures.check(res, "difficulty_store", draft.difficulty_min == 1.0 and draft.difficulty_max == 3.5,
		"stored %.1f-%.1f" % [draft.difficulty_min, draft.difficulty_max])
	picker.press_star(StarRangePicker.ROW_MAX, 4.0)
	page.store_draft(draft)
	TestFixtures.check(res, "difficulty_star", draft.difficulty_min == 1.0 and draft.difficulty_max == 4.0,
		"stored %.1f-%.1f" % [draft.difficulty_min, draft.difficulty_max])


static func _case_story_style_roles(res: Dictionary, page: OverviewPage) -> void:
	page.load_draft(ContractDraft.new())
	page.story_row.on = true
	page.style_buttons[1].button_pressed = true
	_role_row(page, "Driver").on = true
	_role_row(page, "Assassin").on = true
	var draft: ContractDraft = ContractDraft.new()
	page.store_draft(draft)
	var picked: Array[String] = ["Assassin", "Driver"]
	TestFixtures.check(res, "story_store", draft.story, "stored %s" % draft.story)
	TestFixtures.check(res, "style_store", draft.style == "event", "stored '%s'" % draft.style)
	TestFixtures.check(res, "roles_store", draft.roles == picked, "stored %s" % str(draft.roles))
	var fixed: Array[String] = []
	for i: int in range(OverviewPage.FIXED_ROLES.size()):
		var row: ToolFilterCheckRow = page.role_rows[i]
		if row.label != OverviewPage.FIXED_ROLES[i] or not row.button_pressed or not row.disabled:
			fixed.append(row.label)
	TestFixtures.check(res, "roles_fixed", fixed.is_empty(),
		TestFixtures.detail(fixed, OverviewPage.FIXED_ROLES.size(), "fixed rows off or enabled"))
	var loaded: ContractDraft = ContractDraft.new()
	loaded.roles = ["Guide", "Driver"]
	page.load_draft(loaded)
	var stored: ContractDraft = ContractDraft.new()
	page.store_draft(stored)
	var kept: Array[String] = ["Driver", "Guide"]
	TestFixtures.check(res, "roles_extra_kept", stored.roles == kept and not stored.story and stored.style == "",
		"stored %s, story %s, style '%s'" % [str(stored.roles), stored.story, stored.style])


static func _case_load_existing(res: Dictionary, page: OverviewPage) -> void:
	page.load_draft(ContractDraft.new())
	var draft: ContractDraft = ContractDraft.new()
	page.load_dropdown.select(StringName(TEMPLATE_TYPE), true)
	page.store_draft(draft)
	TestFixtures.check(res, "load_pick", draft.contract_name == TEMPLATE_TYPE and draft.source_name == TEMPLATE_TYPE
		and draft.contract_type == TEMPLATE_TYPE, "name '%s', source '%s', type '%s'" % [draft.contract_name,
			draft.source_name, draft.contract_type])
	TestFixtures.check(res, "load_pick_shown", page.name_edit.text == TEMPLATE_TYPE
		and page.type_edit.text == TEMPLATE_TYPE and page.load_dropdown.selected == StringName(TEMPLATE_TYPE)
		and page.name_count.text == "6 / 24", "name '%s', type '%s', load '%s', count '%s'" % [page.name_edit.text,
			page.type_edit.text, page.load_dropdown.selected, page.name_count.text])
	page.load_dropdown.select(&"", true)
	page.store_draft(draft)
	TestFixtures.check(res, "load_clear", draft.contract_name == "" and draft.source_name == ""
		and draft.contract_type == "" and page.name_edit.text == "" and page.type_edit.text == ""
		and page.load_dropdown.selected == &"", "name '%s', source '%s', shown '%s', load '%s'" % [
			draft.contract_name, draft.source_name, page.name_edit.text, page.load_dropdown.selected])


static func _case_complete(res: Dictionary, page: OverviewPage) -> void:
	page.load_draft(ContractDraft.new())
	var empty: bool = page.is_complete()
	_type_into(page.name_edit, "Lamp Run")
	_type_into(page.type_edit, TEMPLATE_TYPE)
	page.issuer_buttons[0].button_pressed = true
	page.issuer_dropdown.select(PERSON_PICK, true)
	var no_style: bool = page.is_complete()
	page.style_buttons[0].button_pressed = true
	var done: bool = page.is_complete()
	_type_into(page.name_edit, "   ")
	var blank: bool = page.is_complete()
	TestFixtures.check(res, "complete", not empty and not no_style and done and not blank,
		"new %s, without style %s, set %s, blank name %s" % [empty, no_style, done, blank])


static func _case_round_trip(res: Dictionary, page: OverviewPage) -> void:
	var places: Array[String] = ContractBuilderData.place_names()
	var full: ContractDraft = ContractDraft.new()
	full.contract_name = "Night Lamp %target%"
	full.contract_type = TEMPLATE_TYPE
	full.apply_template(ContractBuilderData.template_row(TEMPLATE_TYPE))
	full.level_min = 12
	full.level_max = 80
	full.issuer_type = "place"
	full.issuer = places[0] if not places.is_empty() else "Nowhere"
	full.difficulty_min = 1.5
	full.difficulty_max = 4.0
	full.story = true
	full.style = "timeline"
	full.roles = ["Driver", "Escort", "Guide"]
	full.target = "Kidnapped Heir"
	full.completion = "Return"
	full.event_config = "Ambush"
	full.time = 3
	full.consequence = "Lost Favor"
	full.descriptions = ["The heir was taken."]
	full.page = 0
	full.source_name = TEMPLATE_TYPE
	var before: Dictionary = full.to_dict()
	page.load_draft(full)
	page.store_draft(full)
	var bad: Array[String] = _diff(before, full.to_dict(), before.keys())
	TestFixtures.check(res, "round_trip", bad.is_empty() and page.is_complete(),
		TestFixtures.detail(bad, before.size(), "fields changed"))


#Card 285: the Merc Range slider shows the draft's ends, keeps blank cells blank until moved and saves a moved range.
static func _case_mercs(res: Dictionary, page: OverviewPage) -> void:
	var cfg: ContractConfig = ContractLibrary.config()
	var blank: ContractDraft = ContractDraft.new()
	page.load_draft(blank)
	var shown: String = "%d to %d" % [int(page.merc_slider.low), int(page.merc_slider.high)]
	page.store_draft(blank)
	var solo: ContractDraft = ContractDraft.new()
	solo.merc_min = 1
	solo.merc_max = 1
	page.load_draft(solo)
	var solo_shown: String = page.merc_label.text
	page.store_draft(solo)
	page.merc_slider.set_range_silent(2.0, 4.0)
	page.merc_slider.range_changed.emit(page.merc_slider.low, page.merc_slider.high)
	var moved: ContractDraft = ContractDraft.new()
	page.store_draft(moved)
	var ok: bool = (shown == "%d to %d" % [cfg.board_merc_min, cfg.default_max_mercs] and blank.merc_min == 0
		and blank.merc_max == 0 and solo_shown == "1 to 1" and solo.merc_min == 1 and solo.merc_max == 1
		and moved.merc_min == 2 and moved.merc_max == 4 and page.merc_label.text == "2 to 4")
	TestFixtures.check(res, "card285_overview_mercs", ok,
		"blank %s saved %d to %d, solo %s saved %d to %d, moved %d to %d"
		% [shown, blank.merc_min, blank.merc_max, solo_shown, solo.merc_min, solo.merc_max, moved.merc_min, moved.merc_max])
	page.load_draft(ContractDraft.new())


#Card 736: the Local check row shows the draft's flag, saves a toggle and loads a local draft back as on.
static func _case_local(res: Dictionary, page: OverviewPage) -> void:
	var hits: Array[int] = [0]
	var counter: Callable = func() -> void: hits[0] += 1
	page.changed.connect(counter)
	var blank: ContractDraft = ContractDraft.new()
	page.load_draft(blank)
	var shown_off: bool = page.local_row.button_pressed
	page.local_row.on = true
	var saved: ContractDraft = ContractDraft.new()
	page.store_draft(saved)
	var notified: int = hits[0]
	page.load_draft(ContractDraft.new())
	var cleared: bool = page.local_row.button_pressed
	page.load_draft(saved)
	var shown_on: bool = page.local_row.button_pressed
	var again: ContractDraft = ContractDraft.new()
	page.store_draft(again)
	page.changed.disconnect(counter)
	TestFixtures.check(res, "card736_overview_local", not shown_off and saved.local and notified >= 1 and not cleared
		and shown_on and again.local and page.local_row.label == OverviewPage.LOCAL_TEXT,
		"blank shown %s, saved %s, notified %d, cleared shown %s, loaded shown %s, again %s"
		% [shown_off, saved.local, notified, cleared, shown_on, again.local])
	page.load_draft(ContractDraft.new())


static func _case_notify(res: Dictionary, page: OverviewPage) -> void:
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	page.load_draft(ContractDraft.new())
	var loaded: int = hits[0]
	_type_into(page.name_edit, "Lamp")
	var typed: int = hits[0]
	page.store_draft(ContractDraft.new())
	var stored: int = hits[0]
	page.changed.disconnect(count)
	TestFixtures.check(res, "notify", loaded == 0 and typed == 1 and stored == 1,
		"after load %d, after an edit %d, after store %d" % [loaded, typed, stored])


static func _case_location_builds(res: Dictionary, page: LocationPage) -> bool:
	var missing: Array[String] = []
	for key: String in LOCATION_WIDGETS:
		if page.get(key) == null:
			missing.append(key)
	for place: String in USED_PLACES:
		if _primary_row(page, place) == null:
			missing.append(place)
	for area: String in USED_AREAS:
		if _sub_index(page, area) < 0:
			missing.append(area)
	TestFixtures.check(res, "location_builds_widgets", missing.is_empty(), TestFixtures.detail(missing,
		LOCATION_WIDGETS.size() + USED_PLACES.size() + USED_AREAS.size(), "widgets or rows missing"))
	if not missing.is_empty():
		return false
	page.load_draft(ContractDraft.new())
	var kinds: Array[String] = []
	for i: int in range(PLACE_COUNT):
		kinds.append(LocationPage.NATION_TYPE if i < NATION_COUNT else ContractBuilderData.PLACE_TYPES[1])
	var twelfth: String = page.primary_names[NATION_COUNT] if page.primary_names.size() > NATION_COUNT else ""
	TestFixtures.check(res, "location_builds_places", page.primary_rows.size() == PLACE_COUNT
		and page.primary_names.size() == PLACE_COUNT and page.primary_types == kinds
		and page.primary_names[0] == "Aerdis" and twelfth == "Cathistii", "%d rows, first '%s', 12th '%s', %d nations" % [
			page.primary_rows.size(), page.primary_names[0], twelfth, page.primary_types.count(LocationPage.NATION_TYPE)])
	var counts: Dictionary = {}
	for kind: String in page.sub_types:
		counts[kind] = int(counts.get(kind, 0)) + 1
	TestFixtures.check(res, "location_builds_areas", page.sub_rows.size() == AREA_COUNT
		and page.sub_names.size() == AREA_COUNT and page.sub_sliders.size() == AREA_COUNT
		and page.sub_edits.size() == AREA_COUNT and counts == AREA_TYPES, "%d rows, %d sliders, %d edits, types %s" % [
			page.sub_rows.size(), page.sub_sliders.size(), page.sub_edits.size(), str(counts)])
	var line: Control = page.sub_rows[0].get_parent() as Control
	TestFixtures.check(res, "location_builds_new_draft", not page.is_complete(),
		"complete %s; rows %d and %d px high; scrolls %s and %s; nations button %s" % [page.is_complete(),
			int(page.primary_rows[0].size.y), int(line.size.y), page.primary_scroll.size, page.sub_scroll.size,
			page.select_nations.size])
	return true


static func _case_location_buttons(res: Dictionary, page: LocationPage) -> void:
	page.load_draft(ContractDraft.new())
	page.select_all.pressed.emit()
	var all: int = _checked(page).size()
	var all_complete: bool = page.is_complete()
	page.deselect_all.pressed.emit()
	var none: int = _checked(page).size()
	TestFixtures.check(res, "location_select_all", all == PLACE_COUNT and all_complete and none == 0
		and not page.is_complete(), "select all %d on, complete %s; deselect all %d on, complete %s" % [all,
			all_complete, none, page.is_complete()])
	_primary_row(page, "Okun").button_pressed = true
	page.select_nations.pressed.emit()
	var with_okun: Array[String] = _checked(page)
	page.deselect_all.pressed.emit()
	page.select_nations.pressed.emit()
	var nations: Array[String] = _checked(page)
	var want: Array[String] = []
	for i: int in range(page.primary_names.size()):
		if page.primary_types[i] == LocationPage.NATION_TYPE:
			want.append(page.primary_names[i])
	TestFixtures.check(res, "location_select_nations", with_okun.size() == NATION_COUNT + 1 and with_okun.has("Okun")
		and want.size() == NATION_COUNT and nations == want, "with Okun %d on; alone %d on: %s" % [with_okun.size(),
			nations.size(), ", ".join(nations)])


static func _case_location_store_order(res: Dictionary, page: LocationPage) -> void:
	page.load_draft(ContractDraft.new())
	_primary_row(page, "Okun").button_pressed = true
	_primary_row(page, "Aerdis").button_pressed = true
	var draft: ContractDraft = ContractDraft.new()
	page.store_draft(draft)
	var want: Array[String] = ["Aerdis", "Okun"]
	TestFixtures.check(res, "location_store_order", draft.possible_locations == want,
		"stored %s" % str(draft.possible_locations))


static func _case_location_unknown(res: Dictionary, page: LocationPage) -> void:
	var draft: ContractDraft = ContractDraft.new()
	draft.possible_locations = ["Okun", UNKNOWN_NAME, "Okun"]
	page.load_draft(draft)
	var last: int = page.primary_rows.size() - 1
	var both: Array[String] = ["Okun", UNKNOWN_NAME]
	var shown: Array[String] = _checked(page)
	TestFixtures.check(res, "location_unknown_load", page.primary_rows.size() == PLACE_COUNT + 1
		and page.primary_names[last] == UNKNOWN_NAME and page.primary_types[last] == LocationPage.UNKNOWN_TYPE
		and shown == both, "%d rows, last '%s' type '%s', on %s" % [page.primary_rows.size(), page.primary_names[last],
			page.primary_types[last], str(shown)])
	var stored: ContractDraft = ContractDraft.new()
	page.store_draft(stored)
	var first: Array[String] = stored.possible_locations
	page.primary_rows[last].button_pressed = false
	page.store_draft(stored)
	var okun: Array[String] = ["Okun"]
	TestFixtures.check(res, "location_unknown_store", first == both and stored.possible_locations == okun,
		"stored %s, then %s with the row off" % [str(first), str(stored.possible_locations)])
	page.load_draft(ContractDraft.new())
	TestFixtures.check(res, "location_unknown_drop", page.primary_rows.size() == PLACE_COUNT
		and page.primary_names.size() == PLACE_COUNT and _checked(page).is_empty(), "%d rows, %d on" % [
			page.primary_rows.size(), _checked(page).size()])


static func _case_sub_default(res: Dictionary, page: LocationPage) -> void:
	page.load_draft(ContractDraft.new())
	var bad: Array[String] = []
	for i: int in range(page.sub_rows.size()):
		if (not page.sub_sliders[i].disabled or int(page.sub_sliders[i].value) != LocationPage.DEFAULT_PERCENT
				or page.sub_edits[i].text != str(LocationPage.DEFAULT_PERCENT) or page.sub_edits[i].editable):
			bad.append(page.sub_names[i])
	TestFixtures.check(res, "sub_default_off", bad.is_empty(), TestFixtures.detail(bad, page.sub_rows.size(),
		"rows enabled or not at %d" % LocationPage.DEFAULT_PERCENT))
	var at: int = _sub_index(page, "Cavern")
	page.sub_rows[at].button_pressed = true
	var enabled: bool = not page.sub_sliders[at].disabled and page.sub_edits[at].editable
	var draft: ContractDraft = ContractDraft.new()
	page.store_draft(draft)
	var on_cell: String = draft.terrain_odds
	page.sub_sliders[at]._apply(30.0)
	page.sub_rows[at].button_pressed = false
	page.store_draft(draft)
	var disabled: bool = (page.sub_sliders[at].disabled and not page.sub_edits[at].editable
		and int(page.sub_sliders[at].value) == LocationPage.DEFAULT_PERCENT)
	TestFixtures.check(res, "sub_default_toggle", enabled and on_cell == "Cavern %d" % LocationPage.DEFAULT_PERCENT
		and draft.terrain_odds == "" and disabled, "enabled %s, stored '%s', then '%s' and disabled at default %s" % [
			enabled, on_cell, draft.terrain_odds, disabled])


static func _case_sub_slider_edit(res: Dictionary, page: LocationPage) -> void:
	page.load_draft(ContractDraft.new())
	var at: int = _sub_index(page, "Cavern")
	var slider: ToolPixelSlider = page.sub_sliders[at]
	var edit: LineEdit = page.sub_edits[at]
	page.sub_rows[at].button_pressed = true
	slider._apply(15.0)
	var draft: ContractDraft = ContractDraft.new()
	page.store_draft(draft)
	TestFixtures.check(res, "sub_slider_edit_text", edit.text == "15" and draft.terrain_odds == "Cavern 15",
		"edit '%s', stored '%s'" % [edit.text, draft.terrain_odds])
	_submit(edit, "0")
	var low: int = int(slider.value)
	_submit(edit, "250")
	var high: int = int(slider.value)
	_submit(edit, "abc")
	TestFixtures.check(res, "sub_edit_clamps", low == 1 and high == 100 and int(slider.value) == 100
		and edit.text == "100", "0 gives %d, 250 gives %d, abc leaves %d shown '%s'" % [low, high, int(slider.value),
			edit.text])
	_type_into(edit, "2x5")
	var typed: String = edit.text
	edit.focus_exited.emit()
	page.sub_rows[_sub_index(page, "Dungeon")].button_pressed = true
	page.store_draft(draft)
	TestFixtures.check(res, "sub_edit_digits", typed == "25" and int(slider.value) == 25
		and draft.terrain_odds == "Cavern 25, Dungeon %d" % LocationPage.DEFAULT_PERCENT,
		"typed '%s', slider %d, stored '%s'" % [typed, int(slider.value), draft.terrain_odds])


static func _case_sub_load_template(res: Dictionary, page: LocationPage) -> void:
	var draft: ContractDraft = ContractDraft.new()
	draft.apply_template(ContractBuilderData.template_row(TEMPLATE_TYPE))
	var cell: String = draft.terrain_odds
	page.load_draft(draft)
	var shown: Array[String] = _sub_on(page)
	var stored: ContractDraft = ContractDraft.new()
	page.store_draft(stored)
	var want: Array[String] = ["Cavern 15", "Dungeon 85"]
	var status: String = page.status_text()
	TestFixtures.check(res, "sub_load_template", cell == "Cavern 15, Dungeon 100" and shown == want
		and stored.terrain_odds == "Cavern 15, Dungeon 85" and status.contains("Dungeon lowered to 85"),
		"cell '%s', on %s, stored '%s', status '%s'" % [cell, str(shown), stored.terrain_odds, status])
	_share_total(page, "sub_load_template")
	draft.terrain_odds = "Dungeon, Cavern 150, Cavern 20"
	page.load_draft(draft)
	shown = _sub_on(page)
	page.store_draft(stored)
	status = page.status_text()
	var first: Array[String] = ["Cavern 100"]
	TestFixtures.check(res, "sub_load_first_wins", shown == first and stored.terrain_odds == "Cavern 100"
		and status.contains("Dungeon has no valid percent") and status.contains("Cavern is listed twice")
		and status.contains("Cavern lowered to 100"), "on %s, stored '%s', status '%s'" % [str(shown),
			stored.terrain_odds, status.replace("\n", "; ")])


static func _case_sub_unknown(res: Dictionary, page: LocationPage) -> void:
	var draft: ContractDraft = ContractDraft.new()
	draft.terrain_odds = "Tavern 25, %s 30" % UNKNOWN_NAME
	page.load_draft(draft)
	var last: int = page.sub_rows.size() - 1
	var tavern: int = _sub_index(page, "Tavern")
	var shown: Array[String] = _sub_on(page)
	var want: Array[String] = ["Tavern 25", UNKNOWN_NAME + " 30"]
	var stored: ContractDraft = ContractDraft.new()
	page.store_draft(stored)
	TestFixtures.check(res, "sub_unknown_load", page.sub_rows.size() == AREA_COUNT + 1
		and page.sub_names[last] == UNKNOWN_NAME and page.sub_types[last] == LocationPage.UNKNOWN_TYPE
		and page.sub_types[tavern] == ContractBuilderData.INTERIOR_TYPE and not page.sub_sliders[last].disabled
		and page.sub_edits[last].editable and shown == want and stored.terrain_odds == draft.terrain_odds,
		"%d rows, last '%s' type '%s', on %s, stored '%s'" % [page.sub_rows.size(), page.sub_names[last],
			page.sub_types[last], str(shown), stored.terrain_odds])
	page.load_draft(ContractDraft.new())
	TestFixtures.check(res, "sub_unknown_drop", page.sub_rows.size() == AREA_COUNT
		and page.sub_sliders.size() == AREA_COUNT and page.sub_edits.size() == AREA_COUNT and _sub_on(page).is_empty(),
		"%d rows, %d on" % [page.sub_rows.size(), _sub_on(page).size()])


static func _case_location_complete(res: Dictionary, page: LocationPage) -> void:
	page.load_draft(ContractDraft.new())
	var empty: bool = page.is_complete()
	_primary_row(page, "Aerdis").button_pressed = true
	var known: bool = page.is_complete()
	var draft: ContractDraft = ContractDraft.new()
	draft.possible_locations = [UNKNOWN_NAME]
	page.load_draft(draft)
	var only: Array[String] = [UNKNOWN_NAME]
	var unknown: bool = page.is_complete() and _checked(page) == only
	TestFixtures.check(res, "location_complete", not empty and known and unknown,
		"new %s, one row %s, only an unknown row %s" % [empty, known, unknown])


static func _case_location_round_trip(res: Dictionary, page: LocationPage) -> void:
	var draft: ContractDraft = ContractDraft.new()
	draft.possible_locations = ["Aerdis", "Okun"]
	draft.terrain_odds = "Cavern 15, Dungeon 85"
	var before: Dictionary = draft.to_dict()
	page.load_draft(draft)
	page.store_draft(draft)
	var bad: Array[String] = _diff(before, draft.to_dict(), before.keys())
	if page.status_text() != "":
		bad.append("status '%s'" % page.status_text())
	TestFixtures.check(res, "location_round_trip", bad.is_empty() and page.is_complete(),
		TestFixtures.detail(bad, before.size(), "fields changed"))


static func _case_location_notify(res: Dictionary, page: LocationPage) -> void:
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	var draft: ContractDraft = ContractDraft.new()
	draft.terrain_odds = "Cavern 15"
	page.load_draft(draft)
	var loaded: int = hits[0]
	_primary_row(page, "Aerdis").button_pressed = true
	var clicked: int = hits[0]
	page.select_all.pressed.emit()
	var selected: int = hits[0]
	page.sub_sliders[_sub_index(page, "Cavern")]._apply(40.0)
	var slid: int = hits[0]
	page.store_draft(ContractDraft.new())
	var stored: int = hits[0]
	page.changed.disconnect(count)
	TestFixtures.check(res, "location_notify", loaded == 0 and clicked == 1 and selected == 2 and slid == 3
		and stored == 3, "after load %d, a click %d, select all %d, a slide %d, store %d" % [loaded, clicked, selected,
			slid, stored])


#D91-D93: the shares and the remainder total 100; every step of these cases adds to share_total.
static func _case_location_shares(res: Dictionary, page: LocationPage) -> void:
	_share_bad.clear()
	_share_steps = 0
	_share_load_hits = 0
	_share_raw_bad.clear()
	_case_share_check(res, page)
	_case_share_slider(res, page)
	_case_share_typed(res, page)
	_case_share_load(res, page)
	_case_share_remainder(res, page)
	_case_share_tbd(res, page)
	_case_share_notify(res, page)
	TestFixtures.check(res, "share_load_silent", _share_load_hits == 0 and _share_raw_bad.is_empty(),
		"%d notifies on load, raw cells changed %s" % [_share_load_hits, str(_share_raw_bad)])
	TestFixtures.check(res, "share_total", _share_bad.is_empty() and _share_steps > 0,
		TestFixtures.detail(_share_bad, _share_steps, "steps off 100"))


static func _case_share_check(res: Dictionary, page: LocationPage) -> void:
	var d: int = LocationPage.DEFAULT_PERCENT
	_share_load(page, "")
	page.sub_rows[_sub_index(page, "Cavern")].button_pressed = true
	_share_total(page, "check Cavern")
	var one: String = _share_cell(page)
	var left_one: int = page.remainder()
	page.sub_rows[_sub_index(page, "Dungeon")].button_pressed = true
	_share_total(page, "check Dungeon")
	var two: String = _share_cell(page)
	var left_two: int = page.remainder()
	TestFixtures.check(res, "share_check_takes_remainder", one == "Cavern %d" % d and left_one == 100 - d
		and two == "Cavern %d, Dungeon %d" % [d, d] and left_two == 100 - d - d, "'%s' left %d, then '%s' left %d" % [
			one, left_one, two, left_two])
	_share_load(page, "Cavern 60, Dungeon 40")
	page.sub_rows[_sub_index(page, "Tavern")].button_pressed = true
	_share_total(page, "check Tavern when full")
	var full: String = _share_cell(page)
	TestFixtures.check(res, "share_check_when_full", full == "Cavern 50, Dungeon 40, Tavern 10", "stored '%s'" % full)
	_share_load(page, "Cavern 60, Dungeon 40")
	var cavern: int = _sub_index(page, "Cavern")
	page.sub_rows[cavern].button_pressed = false
	_share_total(page, "uncheck Cavern")
	var freed: String = _share_cell(page)
	TestFixtures.check(res, "share_uncheck_frees", freed == "Dungeon 40" and page.remainder() == 60
		and int(page.sub_sliders[cavern].value) == d and page.sub_sliders[cavern].disabled,
		"stored '%s', left %d, Cavern slider %d disabled %s" % [freed, page.remainder(),
			int(page.sub_sliders[cavern].value), page.sub_sliders[cavern].disabled])


static func _case_share_slider(res: Dictionary, page: LocationPage) -> void:
	_share_load(page, "Cavern 60, Dungeon 30")
	page.sub_sliders[_sub_index(page, "Dungeon")]._apply(50.0)
	_share_total(page, "Dungeon to 50")
	var largest: String = _share_cell(page)
	TestFixtures.check(res, "share_slider_takes_largest", largest == "Cavern 50, Dungeon 50" and page.remainder() == 0,
		"stored '%s', left %d" % [largest, page.remainder()])
	_share_load(page, "Cavern 60, Dungeon 30")
	page.sub_sliders[_sub_index(page, "Dungeon")]._apply(40.0)
	_share_total(page, "Dungeon to 40")
	var first: String = _share_cell(page)
	TestFixtures.check(res, "share_slider_takes_remainder_first", first == "Cavern 60, Dungeon 40", "stored '%s'" % first)
	_share_load(page, "Cavern 50, Dungeon 10")
	var slider: ToolPixelSlider = page.sub_sliders[_sub_index(page, "Cavern")]
	slider._apply(100.0)
	_share_total(page, "Cavern to 100")
	var clamped: String = _share_cell(page)
	TestFixtures.check(res, "share_slider_clamps_moved", clamped == "Cavern 99, Dungeon 1", "stored '%s'" % clamped)
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	slider._apply(100.0)
	page.changed.disconnect(count)
	_share_total(page, "Cavern to 100 again")
	TestFixtures.check(res, "share_slider_clamps_repeat", hits[0] == 0 and int(slider.value) == 99
		and _share_cell(page) == clamped, "%d notifies, slider %d, stored '%s'" % [hits[0], int(slider.value),
			_share_cell(page)])


static func _case_share_typed(res: Dictionary, page: LocationPage) -> void:
	_share_load(page, "Cavern 50, Dungeon 50")
	_submit(page.sub_edits[_sub_index(page, "Cavern")], "70")
	_share_total(page, "typed Cavern 70")
	var typed: String = _share_cell(page)
	var dungeon: String = page.sub_edits[_sub_index(page, "Dungeon")].text
	TestFixtures.check(res, "share_typed", typed == "Cavern 70, Dungeon 30" and dungeon == "30",
		"stored '%s', Dungeon edit '%s'" % [typed, dungeon])


static func _case_share_load(res: Dictionary, page: LocationPage) -> void:
	var d: int = LocationPage.DEFAULT_PERCENT
	_share_load(page, "Cavern 70, Dungeon 50, Tavern 20")
	var clip: String = _share_cell(page)
	var status: String = page.status_text()
	var tavern: bool = page.sub_rows[_sub_index(page, "Tavern")].button_pressed
	TestFixtures.check(res, "share_load_clip", clip == "Cavern 70, Dungeon 30" and status.contains("Dungeon lowered to 30")
		and status.contains("Tavern does not fit in 100") and not tavern, "stored '%s', status '%s', Tavern on %s" % [
			clip, status.replace("\n", "; "), tavern])
	page.sub_sliders[_sub_index(page, "Dungeon")]._apply(20.0)
	_share_total(page, "Dungeon to 20 after a clip load")
	TestFixtures.check(res, "share_notes_clear", page.status_text() == "" and _share_cell(page) == "Cavern 70, Dungeon 20",
		"status '%s', stored '%s'" % [page.status_text(), _share_cell(page)])
	_share_load(page, "Cavern 100, Dungeon 50")
	var dungeon: int = _sub_index(page, "Dungeon")
	var dropped: String = _share_cell(page)
	TestFixtures.check(res, "share_load_dropped", dropped == "Cavern 100"
		and page.status_text().contains("Dungeon does not fit in 100") and not page.sub_rows[dungeon].button_pressed
		and int(page.sub_sliders[dungeon].value) == d, "stored '%s', status '%s', Dungeon on %s at %d" % [dropped,
			page.status_text(), page.sub_rows[dungeon].button_pressed, int(page.sub_sliders[dungeon].value)])
	_share_load(page, "Cavern, Dungeon 20")
	var none: String = _share_cell(page)
	TestFixtures.check(res, "share_load_no_percent", none == "Dungeon 20"
		and page.status_text().contains("Cavern has no valid percent"), "stored '%s', status '%s'" % [none,
			page.status_text()])
	_share_load(page, "Cavern 0, Dungeon 20")
	var zero: String = _share_cell(page)
	TestFixtures.check(res, "share_load_zero_percent", zero == "Dungeon 20"
		and page.status_text().contains("Cavern has no valid percent"), "stored '%s', status '%s'" % [zero,
			page.status_text()])
	_share_load(page, "%s, Dungeon 20" % UNKNOWN_NAME)
	var unknown: String = _share_cell(page)
	TestFixtures.check(res, "share_load_unknown_no_percent", unknown == "Dungeon 20" and page.sub_rows.size() == AREA_COUNT
		and page.status_text().contains("%s has no valid percent" % UNKNOWN_NAME), "stored '%s', %d rows, status '%s'" % [
			unknown, page.sub_rows.size(), page.status_text()])
	var cavern: int = _sub_index(page, "Cavern")
	for cell: String in ["Cavern, Cavern 20", "Cavern 20, Cavern"]:
		_share_load(page, cell)
		var kept: String = _share_cell(page)
		var key: String = "share_load_twice_" + ("percent_last" if cell.begins_with("Cavern,") else "percent_first")
		TestFixtures.check(res, key, page.sub_rows[cavern].button_pressed and int(page.sub_sliders[cavern].value) == 20
			and page.status_text() == LocationPage.NOTE_TWICE_PERCENT % "Cavern" and kept == "Cavern 20",
			"cell '%s': Cavern on %s at %d, stored '%s', status '%s'" % [cell, page.sub_rows[cavern].button_pressed,
				int(page.sub_sliders[cavern].value), kept, page.status_text().replace("\n", "; ")])


static func _case_share_remainder(res: Dictionary, page: LocationPage) -> void:
	var row: Node = page.body.get_node_or_null("Columns/Sub/" + LocationPage.REMAINDER_NODE)
	var slider: ToolPixelSlider = page.remainder_slider
	var outside: bool = row != null and not page.sub_scroll.is_ancestor_of(row)
	TestFixtures.check(res, "share_remainder_row", outside and slider != null and slider.disabled
		and int(slider.min_value) == 0 and int(slider.max_value) == 100, "row found %s outside the scroll %s, slider %s" % [
			row != null, outside, "none" if slider == null else "disabled %s, %d-%d" % [slider.disabled,
				int(slider.min_value), int(slider.max_value)]])
	_share_load(page, "Cavern 15")
	var some: String = "%d '%s'" % [int(slider.value), page.remainder_value.text]
	_share_load(page, "")
	var all: String = "%d '%s'" % [int(slider.value), page.remainder_value.text]
	TestFixtures.check(res, "share_remainder_value", some == "85 '85'" and all == "100 '100'",
		"after Cavern 15: %s; with none: %s" % [some, all])


static func _case_share_tbd(res: Dictionary, page: LocationPage) -> void:
	_share_load(page, "")
	var label: Label = page.body.get_node_or_null("Columns/Sub/" + LocationPage.STATUS_NODE) as Label
	var blank: bool = label != null and not label.visible and page.status_text() == ""
	var forest: int = _sub_index(page, "Forest")
	page.sub_rows[forest].button_pressed = true
	_share_total(page, "check Forest")
	var on_text: String = page.status_text()
	var on_shown: bool = label != null and label.visible
	page.sub_rows[forest].button_pressed = false
	_share_total(page, "uncheck Forest")
	var off_text: String = page.status_text()
	var off_hidden: bool = label != null and not label.visible
	TestFixtures.check(res, "share_tbd_note", page.sub_types[forest] == LocationPage.TBD_TYPE
		and on_text.contains("Forest is TBD") and on_shown and off_text == "", "type '%s', on '%s' shown %s, off '%s'" % [
			page.sub_types[forest], on_text, on_shown, off_text])
	TestFixtures.check(res, "share_tbd_status_hidden", blank and off_hidden,
		"label found %s, hidden blank %s, after %s" % [label != null, blank, off_hidden])


static func _case_share_notify(res: Dictionary, page: LocationPage) -> void:
	_share_load(page, "Cavern 50, Dungeon 30")
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	var tavern: int = _sub_index(page, "Tavern")
	var dungeon: LineEdit = page.sub_edits[_sub_index(page, "Dungeon")]
	page.sub_rows[tavern].button_pressed = true
	var checked: int = hits[0]
	page.sub_rows[tavern].button_pressed = false
	var unchecked: int = hits[0]
	page.sub_sliders[_sub_index(page, "Cavern")]._apply(40.0)
	var slid: int = hits[0]
	_submit(dungeon, "35")
	var typed: int = hits[0]
	dungeon.focus_exited.emit()
	var left: int = hits[0]
	page.changed.disconnect(count)
	_share_total(page, "notify steps")
	TestFixtures.check(res, "share_notify_counts", checked == 1 and unchecked == 2 and slid == 3 and typed == 4,
		"check %d, uncheck %d, slide %d, typed %d" % [checked, unchecked, slid, typed])
	TestFixtures.check(res, "share_notify_focus_exit", left == typed and _share_cell(page) == "Cavern 40, Dungeon 35",
		"focus exit %d after %d, stored '%s'" % [left, typed, _share_cell(page)])


#Loads a draft with this Terrain Odds cell; counts the notifies of the load and checks the draft keeps its raw cell.
static func _share_load(page: LocationPage, cell: String) -> void:
	var draft: ContractDraft = ContractDraft.new()
	draft.terrain_odds = cell
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	page.load_draft(draft)
	page.changed.disconnect(count)
	_share_load_hits += hits[0]
	if draft.terrain_odds != cell:
		_share_raw_bad.append(cell)
	_share_total(page, "load '%s'" % cell)


static func _share_cell(page: LocationPage) -> String:
	var draft: ContractDraft = ContractDraft.new()
	page.store_draft(draft)
	return draft.terrain_odds


static func _share_total(page: LocationPage, step: String) -> void:
	_share_steps += 1
	var sum: int = page.remainder()
	for i: int in range(page.sub_rows.size()):
		if page.sub_rows[i].button_pressed:
			sum += int(page.sub_sliders[i].value)
	if sum != 100:
		_share_bad.append("%s gives %d" % [step, sum])


#Appends a Country row to the user:// copy of Locations.tsv, then puts the copy back; no res:// sheet is written.
static func _case_location_sync(res: Dictionary, page: LocationPage) -> void:
	var path: String = ContractBuilderData.locations_path
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var sum: String = FileAccess.get_md5(path)
	var text: String = bytes.get_string_from_utf8()
	var cells: PackedStringArray = PackedStringArray()
	cells.resize(maxi(text.get_slice("\n", 0).split("\t").size(), ContractBuilderData.LOCATIONS_TYPE_COLUMN + 1))
	cells[ContractBuilderData.LOCATIONS_NAME_COLUMN] = NEW_PLACE
	cells[ContractBuilderData.LOCATIONS_TYPE_COLUMN] = LocationPage.NATION_TYPE
	var grown: String = text + ("" if text.ends_with("\n") else "\n") + "\t".join(cells)
	if bytes.is_empty() or not path.begins_with(SCRATCH_DIR) or not _store_bytes(path, grown.to_utf8_buffer()):
		print("SKIPPED location_sync: cannot rewrite the copy %s" % path)
		return
	page.load_draft(ContractDraft.new())
	var rows: int = page.primary_rows.size()
	var twelfth: String = page.primary_names[NATION_COUNT] if rows > NATION_COUNT else ""
	var restored: bool = _store_bytes(path, bytes) and FileAccess.get_md5(path) == sum
	page.load_draft(ContractDraft.new())
	TestFixtures.check(res, "location_sync", rows == PLACE_COUNT + 1 and twelfth == NEW_PLACE and restored
		and page.primary_rows.size() == PLACE_COUNT and page.primary_names[NATION_COUNT] == "Cathistii",
		"%d rows with %s, 12th '%s'; copy restored %s, then %d rows" % [rows, NEW_PLACE, twelfth, restored,
			page.primary_rows.size()])


static func _case_target_builds(res: Dictionary, page: TargetPage) -> bool:
	var missing: Array[String] = []
	for key: String in TARGET_WIDGETS:
		if page.get(key) == null:
			missing.append(key)
	TestFixtures.check(res, "target_builds_widgets", missing.is_empty(),
		TestFixtures.detail(missing, TARGET_WIDGETS.size(), "widgets missing"))
	if not missing.is_empty():
		return false
	page.load_draft(ContractDraft.new())
	var bad: Array[String] = []
	for radio: BevelButton in [page.radio_npc, page.radio_monster, page.radio_random, page.radio_none]:
		if radio.button_group != page.source_group:
			bad.append("%s outside source_group" % radio.text)
	_expect(bad, "group buttons", page.source_group.get_buttons().size(), 4)
	_expect(bad, "pressed", _target_radio(page), "none")
	_expect(bad, "panels", _target_panels(page), "")
	_expect(bad, "unknown_label visible", page.unknown_label.visible, false)
	_expect(bad, "complete", page.is_complete(), true)
	_expect(bad, "store", _stored_target(page), "")
	_verdict(res, "target_builds", bad)
	bad.clear()
	var types: Array[String] = _keys(page.type_dropdown)
	_expect(bad, "npc", ",".join(_keys(page.npc_dropdown)), ",".join(NPC_TITLES))
	_expect(bad, "type", "%d %s" % [types.size(), types[0] if not types.is_empty() else ""],
		"%d Assembly" % CREATURE_COUNT)
	_expect(bad, "tradition", "%d %s" % [page.tradition_dropdown.options.size(), _head(page.tradition_dropdown)],
		"%d /Any" % (TRADITION_COUNT + 1))
	_expect(bad, "skew", "%s | %s" % [_head(page.skew_dropdown), ",".join(_keys(page.skew_dropdown))],
		"/None | ,Cognition,Dexterity,Vigor,Wile")
	_expect(bad, "creature", "%d %s" % [page.creature_dropdown.options.size(), _head(page.creature_dropdown)],
		"%d /None" % (CREATURE_COUNT + 1))
	_expect(bad, "heads shown", "%s|%s|%s" % [page.tradition_dropdown.button_text(), page.skew_dropdown.button_text(),
		page.creature_dropdown.button_text()], "Any|None|None")
	_expect(bad, "pick", "%d %s" % [page.pick_dropdown.options.size(), page.pick_dropdown.disabled], "1 true")
	_verdict(res, "target_builds_lists", bad)
	return true


static func _case_target_npc(res: Dictionary, page: TargetPage) -> void:
	page.load_draft(_target_draft(""))
	page.radio_npc.button_pressed = true
	var bad: Array[String] = []
	_expect(bad, "panels", _target_panels(page), "npc")
	_expect(bad, "store", _stored_target(page), "npc:Taverngoer")
	page.npc_dropdown.select(&"Bandit Leader", true)
	_expect(bad, "store after select", _stored_target(page), "npc:Bandit Leader")
	_verdict(res, "target_npc", bad)


static func _case_target_monster(res: Dictionary, page: TargetPage) -> void:
	page.load_draft(_target_draft(""))
	page.radio_monster.button_pressed = true
	var bad: Array[String] = []
	_expect(bad, "panels", _target_panels(page), "monster")
	_expect(bad, "store", _stored_target(page), "monster:Assembly:all")
	page.type_dropdown.select(&"Beast", true)
	_expect(bad, "store after select", _stored_target(page), "monster:Beast:all")
	_verdict(res, "target_monster", bad)


static func _case_target_random_default(res: Dictionary, page: TargetPage) -> void:
	page.load_draft(_target_draft(""))
	page.radio_random.button_pressed = true
	var bad: Array[String] = []
	_expect(bad, "panels", _target_panels(page), "random")
	_expect(bad, "modes", "%s %s" % [page.radio_level_party.button_pressed, page.radio_count_party.button_pressed],
		"true true")
	_expect(bad, "level rows", "%s %s" % [page.level_fixed_row.visible, page.level_range_row.visible], "false false")
	_expect(bad, "count", "%s|%s" % [page.count_edit.text, page.count_suffix.text], "0|added to the party size")
	_expect(bad, "store", _stored_target(page), "random:level=party, count=party")
	_verdict(res, "target_random_default", bad)


static func _case_target_random_fields(res: Dictionary, page: TargetPage) -> void:
	page.load_draft(_target_draft(""))
	page.radio_random.button_pressed = true
	page.radio_level_fixed.button_pressed = true
	var bad: Array[String] = []
	_expect(bad, "fixed row", "%s %s" % [page.level_fixed_row.visible, page.level_edit.text], "true 5")
	_submit(page.level_edit, "250")
	_expect(bad, "level 250", page.level_edit.text, "240")
	_expect(bad, "store fixed", _stored_target(page), "random:level=240, count=party")
	page.radio_level_range.button_pressed = true
	_expect(bad, "range row", "%s %s %s" % [page.level_range_row.visible, page.level_fixed_row.visible,
		_range_text(page)], "true false 5-30")
	_submit(page.level_min_edit, "10")
	_submit(page.level_max_edit, "20")
	_expect(bad, "store range", _stored_target(page), "random:level=10-20, count=party")
	_submit(page.level_min_edit, "25")
	_expect(bad, "min 25", _range_text(page), "25-25")
	_submit(page.level_max_edit, "20")
	_expect(bad, "max 20", _range_text(page), "20-20")
	_submit(page.level_max_edit, "abc")
	_expect(bad, "max abc", _range_text(page), "20-20")
	page.radio_count_fixed.button_pressed = true
	_expect(bad, "count fixed", "%s|%s" % [page.count_edit.text, page.count_suffix.text], "1|")
	_submit(page.count_edit, "0")
	_expect(bad, "count 0", page.count_edit.text, "1")
	_submit(page.count_edit, "150")
	_expect(bad, "count 150", page.count_edit.text, "99")
	page.radio_count_party.button_pressed = true
	_submit(page.count_edit, "3")
	_expect(bad, "store plus 3", _stored_target(page), "random:level=20-20, count=party+3")
	_submit(page.count_edit, "12")
	_expect(bad, "plus 12", page.count_edit.text, "9")
	page.tradition_dropdown.select(&"Warrior", true)
	page.skew_dropdown.select(&"Dexterity", true)
	page.creature_dropdown.select(&"Undead", true)
	_expect(bad, "store lists", _stored_target(page),
		"random:level=20-20, count=party+9, tradition=Warrior, skew=Dexterity, type=Undead")
	_type_into(page.level_edit, "2x4")
	_expect(bad, "level filter", page.level_edit.text, "24")
	_verdict(res, "target_random_fields", bad)


static func _case_target_load(res: Dictionary, page: TargetPage) -> void:
	var bad: Array[String] = []
	page.load_draft(_target_draft(LOADED_RANDOM))
	_expect(bad, "random radios", "%s %s %s" % [_target_radio(page), page.radio_level_range.button_pressed,
		page.radio_count_party.button_pressed], "random true true")
	_expect(bad, "random edits", "%s|%s" % [_range_text(page), page.count_edit.text], "10-20|1")
	_expect(bad, "random lists", "%s %s %s" % [page.tradition_dropdown.selected, page.skew_dropdown.selected,
		page.creature_dropdown.selected], "Warrior Vigor Beast")
	_expect(bad, "random store", _stored_target(page), LOADED_RANDOM)
	page.load_draft(_target_draft("npc:Bandit Leader"))
	_expect(bad, "npc", "%s %s" % [_target_radio(page), page.npc_dropdown.selected], "npc Bandit Leader")
	page.load_draft(_target_draft("monster:Beast:all"))
	_expect(bad, "monster", "%s %s %s" % [_target_radio(page), page.type_dropdown.selected,
		page.pick_dropdown.selected], "monster Beast all")
	page.load_draft(_target_draft("monster:Beast:Dire Wolf"))
	_expect(bad, "pick", "%d %s %s" % [page.pick_dropdown.options.size(), page.pick_dropdown.selected,
		page.pick_dropdown.disabled], "2 Dire Wolf false")
	_expect(bad, "pick store", _stored_target(page), "monster:Beast:Dire Wolf")
	page.load_draft(_target_draft("monster:Beast"))
	_expect(bad, "no pick store", _stored_target(page), "monster:Beast:all")
	page.load_draft(_target_draft("random:count=3, level=12"))
	_expect(bad, "token order store", _stored_target(page), "random:level=12, count=3")
	page.load_draft(_target_draft(""))
	_expect(bad, "blank", _target_radio(page), "none")
	_verdict(res, "target_load", bad)


static func _case_target_unknown_values(res: Dictionary, page: TargetPage) -> void:
	var bad: Array[String] = []
	page.load_draft(_target_draft("npc:Mayor"))
	_expect(bad, "npc", "%s %d %s" % [_target_radio(page), page.npc_dropdown.options.size(),
		page.npc_dropdown.selected], "npc 5 Mayor")
	_expect(bad, "npc label", page.npc_dropdown.button_text(), "Mayor (not in sheet)")
	_expect(bad, "npc store", _stored_target(page), "npc:Mayor")
	page.load_draft(ContractDraft.new())
	_expect(bad, "npc reload", page.npc_dropdown.options.size(), NPC_TITLES.size())
	page.load_draft(_target_draft("random:tradition=Monk"))
	_expect(bad, "tradition", "%d %s" % [page.tradition_dropdown.options.size(), page.tradition_dropdown.selected],
		"%d Monk" % (TRADITION_COUNT + 2))
	_expect(bad, "tradition label", page.tradition_dropdown.button_text(), "Monk (not in sheet)")
	_expect(bad, "tradition store", _stored_target(page), "random:level=party, count=party, tradition=Monk")
	page.load_draft(ContractDraft.new())
	_expect(bad, "tradition reload", page.tradition_dropdown.options.size(), TRADITION_COUNT + 1)
	page.load_draft(_target_draft(ANY_NONE_RANDOM))
	_expect(bad, "any none", "%d %s %d %s" % [page.tradition_dropdown.options.size(), page.tradition_dropdown.selected,
		page.creature_dropdown.options.size(), page.creature_dropdown.selected],
		"%d any %d none" % [TRADITION_COUNT + 2, CREATURE_COUNT + 2])
	_expect(bad, "any none labels", "%s|%s" % [page.tradition_dropdown.button_text(),
		page.creature_dropdown.button_text()], "any (not in sheet)|none (not in sheet)")
	_expect(bad, "any none store", _stored_target(page), ANY_NONE_RANDOM)
	page.load_draft(_target_draft("monster:Kraken:all"))
	_expect(bad, "type", "%s %d %s" % [_target_radio(page), page.type_dropdown.options.size(),
		page.type_dropdown.selected], "monster %d Kraken" % (CREATURE_COUNT + 1))
	_expect(bad, "type label", page.type_dropdown.button_text(), "Kraken (not in sheet)")
	_expect(bad, "type store", _stored_target(page), "monster:Kraken:all")
	page.load_draft(_target_draft("random:type=Kraken"))
	_expect(bad, "creature", "%d %s" % [page.creature_dropdown.options.size(), page.creature_dropdown.selected],
		"%d Kraken" % (CREATURE_COUNT + 2))
	_expect(bad, "creature label", page.creature_dropdown.button_text(), "Kraken (not in sheet)")
	_expect(bad, "creature store", _stored_target(page), "random:level=party, count=party, type=Kraken")
	page.load_draft(ContractDraft.new())
	_expect(bad, "type reload", "%d %d" % [page.type_dropdown.options.size(), page.creature_dropdown.options.size()],
		"%d %d" % [CREATURE_COUNT, CREATURE_COUNT + 1])
	_verdict(res, "target_unknown_values", bad)


static func _case_target_unparseable(res: Dictionary, page: TargetPage) -> void:
	var bad: Array[String] = []
	page.load_draft(_target_draft("bogus"))
	_expect(bad, "radio", _target_radio(page), "")
	_expect(bad, "panels", _target_panels(page), "")
	_expect(bad, "label", "%s %s" % [page.unknown_label.visible, page.unknown_label.text],
		"true Not a target cell: bogus")
	_expect(bad, "complete", page.is_complete(), false)
	_expect(bad, "store", _stored_target(page), "bogus")
	page.radio_none.button_pressed = true
	_expect(bad, "none", "%s %s '%s'" % [page.unknown_label.visible, page.is_complete(), _stored_target(page)],
		"false true ''")
	page.load_draft(_target_draft("random:skew=melee"))
	_expect(bad, "skew", "%s %s %s" % [_target_radio(page), page.unknown_label.visible, _stored_target(page)],
		" true random:skew=melee")
	_verdict(res, "target_unparseable", bad)


static func _case_target_complete(res: Dictionary, page: TargetPage) -> void:
	page.load_draft(_target_draft(""))
	var got: Array[String] = ["none %s" % page.is_complete()]
	page.radio_npc.button_pressed = true
	got.append("npc %s" % page.is_complete())
	page.radio_monster.button_pressed = true
	got.append("monster %s" % page.is_complete())
	page.radio_random.button_pressed = true
	got.append("random %s" % page.is_complete())
	page.load_draft(_target_draft("bogus"))
	got.append("bogus %s" % page.is_complete())
	var shown: String = ", ".join(got)
	TestFixtures.check(res, "target_complete", shown == "none true, npc true, monster true, random true, bogus false",
		shown)


static func _case_target_round_trip(res: Dictionary, page: TargetPage) -> void:
	var changed: Array[String] = []
	for cell: String in ROUND_TRIP_TARGETS:
		var draft: ContractDraft = _target_draft(cell)
		var before: Dictionary = draft.to_dict()
		page.load_draft(draft)
		page.store_draft(draft)
		for line: String in _diff(before, draft.to_dict(), before.keys()):
			changed.append("'%s' %s" % [cell, line])
	TestFixtures.check(res, "target_round_trip", changed.is_empty(),
		TestFixtures.detail(changed, ROUND_TRIP_TARGETS.size(), "cells changed"))


static func _case_target_notify(res: Dictionary, page: TargetPage) -> void:
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	var marks: Array[int] = []
	page.load_draft(_target_draft(""))
	marks.append(hits[0])
	page.radio_npc.button_pressed = true
	marks.append(hits[0])
	page.npc_dropdown.select(&"Bandit Leader", true)
	marks.append(hits[0])
	page.load_draft(_target_draft("random:level=10-20, count=party+1"))
	marks.append(hits[0])
	_submit(page.level_min_edit, "12")
	marks.append(hits[0])
	_submit(page.level_min_edit, "12")
	marks.append(hits[0])
	page.radio_level_fixed.button_pressed = true
	marks.append(hits[0])
	_submit(page.level_edit, "15")
	marks.append(hits[0])
	page.radio_level_range.button_pressed = true
	marks.append(hits[0])
	page.level_slider.set_range_silent(14.0, 18.0)
	page.level_slider.range_changed.emit(14.0, 18.0)
	marks.append(hits[0])
	page.radio_count_fixed.button_pressed = true
	marks.append(hits[0])
	_submit(page.count_edit, "4")
	marks.append(hits[0])
	page.count_edit.text = "6"
	page.count_edit.focus_exited.emit()
	marks.append(hits[0])
	page.count_edit.focus_exited.emit()
	marks.append(hits[0])
	page.tradition_dropdown.select(&"Warrior", true)
	marks.append(hits[0])
	page.skew_dropdown.select(&"Dexterity", true)
	marks.append(hits[0])
	page.creature_dropdown.select(&"Undead", true)
	marks.append(hits[0])
	var random_cell: String = _stored_target(page)
	page.load_draft(_target_draft("monster:Beast:Dire Wolf"))
	marks.append(hits[0])
	page.type_dropdown.select(&"Undead", true)
	marks.append(hits[0])
	page.pick_dropdown.select(&"all", true)
	marks.append(hits[0])
	page.store_draft(_target_draft(""))
	marks.append(hits[0])
	page.changed.disconnect(count)
	var steps: String = _steps(marks)
	TestFixtures.check(res, "target_notify", steps == "0 1 1 0 1 0 1 1 1 1 1 1 1 0 1 1 1 0 1 1 0"
		and random_cell == "random:level=14-18, count=6, tradition=Warrior, skew=Dexterity, type=Undead",
		("per step (load, radio, select, load, submit, same submit, level fixed, level submit, level range, slider,"
		+ " count fixed, count submit, focus exit, same focus exit, tradition, skew, creature, load, type, pick,"
		+ " store): %s; random cell %s") % [steps, random_cell])


static func _case_description_builds(res: Dictionary, page: DescriptionPage) -> bool:
	var missing: Array[String] = []
	for key: String in DESCRIPTION_WIDGETS:
		if page.get(key) == null:
			missing.append(key)
	if page.tag_buttons.size() != ContractDraft.NAME_TAGS.size():
		missing.append("tag_buttons")
	page.load_draft(ContractDraft.new())
	if page.entry_edits.size() != 1 or page.remove_buttons.size() != 1:
		missing.append("one entry row")
	TestFixtures.check(res, "description_builds_widgets", missing.is_empty(),
		TestFixtures.detail(missing, DESCRIPTION_WIDGETS.size() + 2, "widgets missing"))
	if not missing.is_empty():
		return false
	var edit: TextEdit = page.entry_edits[0]
	var bad: Array[String] = []
	_expect(bad, "text", edit.text, "")
	_expect(bad, "tags", ",".join(_texts(page.tag_buttons)), TAG_TEXTS)
	_expect(bad, "remove disabled", page.remove_buttons[0].disabled, true)
	_expect(bad, "active", page.active_index, 0)
	_expect(bad, "complete", page.is_complete(), false)
	_expect(bad, "font", edit.get_theme_font(&"font") == page.get_theme_font(&"font", &"LineEdit"), true)
	_expect(bad, "normal", edit.get_theme_stylebox(&"normal") == page.get_theme_stylebox(&"normal", &"LineEdit"),
		true)
	_verdict(res, "description_builds", bad)
	return true


static func _case_description_add_remove(res: Dictionary, page: DescriptionPage) -> void:
	page.load_draft(ContractDraft.new())
	page.add_button.pressed.emit()
	var added: String = "%d entries, Remove disabled %s" % [page.entry_edits.size(), _disabled(page.remove_buttons)]
	if page.entry_edits.size() != 2:
		TestFixtures.check(res, "description_add_remove", false, added)
		return
	page.entry_edits[0].text = "A"
	page.entry_edits[1].text = "B"
	page.remove_buttons[0].pressed.emit()
	var left: String = "%d entries, texts %s, Remove disabled %s" % [page.entry_edits.size(),
		"|".join(_edit_texts(page)), _disabled(page.remove_buttons)]
	TestFixtures.check(res, "description_add_remove", added == "2 entries, Remove disabled false,false"
		and left == "1 entries, texts B, Remove disabled true", "%s; then %s" % [added, left])


#Add would make its new entry active, so the second entry comes from _add_entry and focus stays on entry 0.
static func _case_description_tag_insert(res: Dictionary, page: DescriptionPage) -> void:
	page.load_draft(ContractDraft.new())
	var first: TextEdit = page.entry_edits[0]
	first.text = "Find  here"
	first.set_caret_line(0)
	first.set_caret_column(5)
	first.grab_focus()
	await TestFixtures.frames(page, 1)
	var bad: Array[String] = []
	_expect(bad, "focus", "%s %d" % [first.has_focus(), page.active_index], "true 0")
	page.tag_buttons[0].pressed.emit()
	_expect(bad, "first press", first.text, "Find %target% here")
	page._add_entry("")
	page.tag_buttons[1].pressed.emit()
	var second: String = page.entry_edits[1].text if page.entry_edits.size() == 2 else "<missing>"
	_expect(bad, "second press", "%s|%s" % [first.text.contains("%location%"), second], "true|")
	var draft: ContractDraft = ContractDraft.new()
	draft.descriptions = ["One", "Two"]
	page.load_draft(draft)
	_expect(bad, "loaded carets", "%d %d" % [page.entry_edits[0].get_caret_column(),
		page.entry_edits[1].get_caret_column()], "3 3")
	page.tag_buttons[2].pressed.emit()
	_expect(bad, "after load", "|".join(_edit_texts(page)), "One|Two%requestor%")
	_verdict(res, "description_tag_insert", bad)


static func _case_description_store_collapse(res: Dictionary, page: DescriptionPage) -> void:
	var draft: ContractDraft = ContractDraft.new()
	draft.descriptions = ["x", "y", "z"]
	page.load_draft(draft)
	page.entry_edits[0].text = "  First\nline\ttab  "
	page.entry_edits[1].text = "   "
	page.entry_edits[2].text = "Second"
	var out: ContractDraft = ContractDraft.new()
	page.store_draft(out)
	var bad: Array[String] = []
	_expect(bad, "stored", "|".join(out.descriptions), "First line tab|Second")
	_expect(bad, "widget text", page.entry_edits[0].text, "  First\nline\ttab  ")
	_expect(bad, "collapse", DescriptionPage.collapse("a\r\nb"), "a b")
	_verdict(res, "description_store_collapse", bad)


static func _case_description_load(res: Dictionary, page: DescriptionPage) -> void:
	var draft: ContractDraft = ContractDraft.new()
	draft.descriptions = ["A", "B"]
	page.load_draft(draft)
	var two: String = "%d %s %s active %d" % [page.entry_edits.size(), "|".join(_edit_texts(page)),
		"|".join(page.entry_texts), page.active_index]
	page.load_draft(ContractDraft.new())
	var one: String = "%d '%s'" % [page.entry_edits.size(), "|".join(_edit_texts(page))]
	TestFixtures.check(res, "description_load", two == "2 A|B A|B active 1" and one == "1 ''",
		"%s; new draft %s" % [two, one])


static func _case_description_complete(res: Dictionary, page: DescriptionPage) -> void:
	page.load_draft(ContractDraft.new())
	var got: Array[String] = ["new %s" % page.is_complete()]
	page.entry_edits[0].text = "x"
	got.append("x %s" % page.is_complete())
	page.entry_edits[0].text = "  \n "
	got.append("blank %s" % page.is_complete())
	var shown: String = ", ".join(got)
	TestFixtures.check(res, "description_complete", shown == "new false, x true, blank false", shown)


static func _case_description_round_trip(res: Dictionary, page: DescriptionPage) -> void:
	var draft: ContractDraft = ContractDraft.new()
	draft.descriptions = ["Rescue %target% from %location%", "Ask %requestor%"]
	var before: Dictionary = draft.to_dict()
	page.load_draft(draft)
	page.store_draft(draft)
	var changed: Array[String] = _diff(before, draft.to_dict(), before.keys())
	TestFixtures.check(res, "description_round_trip", changed.is_empty(),
		TestFixtures.detail(changed, before.size(), "keys changed"))


#The frames before counting let the deferred text_changed calls of the earlier cases run out.
static func _case_description_notify(res: Dictionary, page: DescriptionPage) -> void:
	await TestFixtures.frames(page)
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	var marks: Array[int] = []
	page.load_draft(ContractDraft.new())
	await TestFixtures.frames(page)
	marks.append(hits[0])
	_type_text(page.entry_edits[0], "Typed")
	await TestFixtures.frames(page, 1)
	marks.append(hits[0])
	page.add_button.pressed.emit()
	marks.append(hits[0])
	page.remove_buttons[1].pressed.emit()
	marks.append(hits[0])
	page.tag_buttons[0].pressed.emit()
	await TestFixtures.frames(page, 1)
	marks.append(hits[0])
	page.store_draft(ContractDraft.new())
	marks.append(hits[0])
	page.changed.disconnect(count)
	var steps: String = _steps(marks)
	TestFixtures.check(res, "description_notify", steps == "0 1 1 1 1 0",
		"per step (load and two frames, typing, Add, Remove, tag press, store): %s" % steps)


#Appends the Poison Vial row to the scratch Checks copy; the completion cases and the shell pick it.
static func _case_completion_check_row(res: Dictionary) -> void:
	var path: String = ContractBuilderData.checks_path
	if not path.begins_with(SCRATCH_DIR):
		TestFixtures.check(res, "completion_check_row", false, "checks_path %s is not a scratch copy" % path)
		return
	var cells: Array[String] = []
	cells.assign(POISON_ROW)
	var result: Dictionary = TsvRowWriter.append_row(path, cells)
	var names: Array[String] = ContractBuilderData.check_names()
	TestFixtures.check(res, "completion_check_row", bool(result.get("ok", false)) and names.has(POISON_VIAL),
		"append ok %s '%s'; names %s" % [result.get("ok", false), result.get("error", ""), str(names)])


static func _case_completion_builds(res: Dictionary, page: CompletionPage) -> bool:
	var missing: Array[String] = []
	for key: String in COMPLETION_WIDGETS:
		if page.get(key) == null:
			missing.append(key)
	if page.builder() == null:
		missing.append("builder")
	TestFixtures.check(res, "completion_builds_widgets", missing.is_empty(),
		TestFixtures.detail(missing, COMPLETION_WIDGETS.size() + 1, "widgets missing"))
	if not missing.is_empty():
		return false
	var bad: Array[String] = []
	page.load_draft(_completion_draft("", "", []))
	_expect(bad, "check panel", page.check_panel.visible, false)
	_expect(bad, "event panel", page.event_panel.visible, false)
	_expect(bad, "timeline panel", page.timeline_panel.visible, false)
	_expect(bad, "status mentions Style", page.status_text().contains("Style"), true)
	_expect(bad, "complete", page.is_complete(), true)
	_expect(bad, "builder hidden", page.builder().visible, false)
	_expect(bad, "builder top_level", page.builder().top_level, true)
	_verdict(res, "completion_builds", bad)
	return true


static func _case_completion_event_pick(res: Dictionary, page: CompletionPage) -> void:
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	page.load_draft(_event_draft("event", "event:Battle", "", 0, ""))
	page.changed.disconnect(count)
	var dropdown: ToolOptionDropdown = page.event_dropdown()
	_same(res, "completion_event_pick", "%s / %s" % [dropdown.selected, dropdown.button_text()], "Battle / Battle")
	var panel: EventConfigPanel = page.config_panel()
	var note: Label = (panel.get_child(0) as Label) if panel.get_child_count() == 1 else null
	_same(res, "completion_event_pick_panel", "%s %s %s" % [panel.visible, panel.has_fields(),
		note.text if note != null else "no single Label"],
		"true false No options for Battle. Set Time and Consequence.")
	_same(res, "completion_event_pick_complete", "%s '%s'" % [page.is_complete(), page.status_text()], "true ''")
	_same(res, "completion_event_pick_panels", "%s %s" % [page.event_panel.visible, page.check_panel.visible],
		"true false")
	_same(res, "completion_event_pick_silent", hits[0], 0)
	_same(res, "completion_event_pick_store", _stored_event(page), "event:Battle |  | 60 | ")
	page.load_draft(_completion_draft("timeline", "", []))
	_same(res, "completion_event_pick_timeline", "%s %s %s" % [page.timeline_panel.visible, page.event_panel.visible,
		page.is_complete()], "true false false")


static func _case_completion_check_empty(res: Dictionary, page: CompletionPage) -> void:
	var bad: Array[String] = []
	page.load_draft(_completion_draft("check", "", []))
	_expect(bad, "check panel", page.check_panel.visible, true)
	_expect(bad, "selected", page.check_dropdown.selected, &"none")
	_expect(bad, "complete", page.is_complete(), false)
	_expect(bad, "button text", page.build_button.text, "Build new")
	_expect(bad, "pending label", page.pending_label.visible, false)
	_expect(bad, "status", page.status_text(), "")
	_verdict(res, "completion_check_empty", bad)


static func _case_completion_pick_existing(res: Dictionary, page: CompletionPage) -> void:
	var bad: Array[String] = []
	page.load_draft(_completion_draft("check", "", []))
	var labels: Array[String] = _option_labels(page.check_dropdown)
	_expect(bad, "options %s" % str(labels), labels.size() > 1 and labels[0] == "(none)" and labels.has(POISON_VIAL), true)
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	page.pick(_sheet_key(POISON_VIAL))
	page.changed.disconnect(count)
	_expect(bad, "completion", page.completion_text(), "check:" + POISON_VIAL)
	_expect(bad, "selected", page.check_dropdown.selected, _sheet_key(POISON_VIAL))
	_expect(bad, "complete", page.is_complete(), true)
	_expect(bad, "emissions", hits[0], 1)
	var out: ContractDraft = ContractDraft.new()
	page.store_draft(out)
	_expect(bad, "stored completion", out.completion, "check:" + POISON_VIAL)
	_expect(bad, "stored check_row", out.check_row.size(), 0)
	_verdict(res, "completion_pick_existing", bad)


static func _case_completion_load_unknown(res: Dictionary, page: CompletionPage) -> void:
	var bad: Array[String] = []
	page.load_draft(_completion_draft("check", "check:Ghost", []))
	_expect(bad, "selected", page.check_dropdown.selected, &"unknown:Ghost")
	_expect(bad, "shown", page.check_dropdown.button_text(), "Ghost (not in sheet)")
	_expect(bad, "complete", page.is_complete(), true)
	_expect(bad, "status mentions Checks.tsv", page.status_text().contains("Checks.tsv"), true)
	page.pick(&"unknown:Ghost")
	var out: ContractDraft = ContractDraft.new()
	page.store_draft(out)
	_expect(bad, "stored completion", out.completion, "check:Ghost")
	page.load_draft(_completion_draft("check", "check:poison vial", []))
	_expect(bad, "case selected", page.check_dropdown.selected, &"unknown:poison vial")
	var status: String = page.status_text()
	_expect(bad, "case status '%s'" % status, status.contains("letter case") and status.contains(POISON_VIAL), true)
	_verdict(res, "completion_load_unknown", bad)


#The modal is top_level under the page body; one frame after present() its box has a laid-out rect.
static func _case_completion_build_new(res: Dictionary, page: CompletionPage) -> void:
	var bad: Array[String] = []
	page.load_draft(_completion_draft("check", "", []))
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	page.press_build()
	await TestFixtures.frames(page, 1)
	var builder: CheckBuilder = page.builder()
	_expect(bad, "builder visible", builder.visible, true)
	_expect(bad, "blank form", builder.name_edit.text, "")
	var box: Rect2 = builder.box.get_global_rect()
	var view: Rect2 = page.get_viewport_rect()
	_expect(bad, "box %s inside %s" % [box, view], view.encloses(box) and box.size.y > 0.0, true)
	_fill_trial(builder)
	_expect(bad, "no emission while filling", hits[0], 0)
	builder.press_confirm()
	page.changed.disconnect(count)
	_expect(bad, "builder hidden", builder.visible, false)
	_expect(bad, "pending", page.pending(), BUILT_ROW)
	_expect(bad, "completion", page.completion_text(), "check:" + BUILT_NAME)
	_expect(bad, "dropdown text", page.check_dropdown.button_text(), BUILT_NAME + " (new)")
	_expect(bad, "button text", page.build_button.text, "Edit new")
	_expect(bad, "pending label", page.pending_label.visible and page.pending_label.text.contains(BUILT_NAME), true)
	_expect(bad, "complete", page.is_complete(), true)
	_expect(bad, "emissions", hits[0], 1)
	var out: ContractDraft = _completion_draft("check", "", [])
	page.store_draft(out)
	_expect(bad, "stored row", out.check_row, BUILT_ROW)
	_expect(bad, "stored completion", out.completion, "check:" + BUILT_NAME)
	_expect(bad, "pending_check", ContractRowWriter.pending_check(out), true)
	_close_builder(builder)
	_verdict(res, "completion_build_new", bad)


#Each D64 rule keeps the modal open with its status; nothing reaches the page.
static func _case_completion_builder_rejects(res: Dictionary, page: CompletionPage) -> void:
	var bad: Array[String] = []
	page.load_draft(_completion_draft("check", "", []))
	page.press_build()
	var builder: CheckBuilder = page.builder()
	builder.press_confirm()
	_expect(bad, "blank name open", builder.visible, true)
	_expect(bad, "blank name status", builder.status_text().contains("empty"), true)
	_type_into(builder.name_edit, BUILT_NAME)
	builder.press_confirm()
	_expect(bad, "no attribute open", builder.visible, true)
	_expect(bad, "no attribute status", builder.status_text().contains("Attribute"), true)
	var cognition: ToolFilterCheckRow = builder.attribute_row("Cognition")
	if cognition == null:
		bad.append("no Cognition row")
	else:
		cognition.button_pressed = true
	builder.press_confirm()
	_expect(bad, "no opposed open", builder.visible, true)
	_expect(bad, "no opposed status", builder.status_text().contains("Opposed"), true)
	builder.opposed_no.button_pressed = true
	_type_into(builder.name_edit, POISON_VIAL)
	builder.press_confirm()
	_expect(bad, "taken open", builder.visible, true)
	_expect(bad, "taken status", builder.status_text().contains("already exists"), true)
	_type_into(builder.name_edit, "Caf" + String.chr(233))
	builder.press_confirm()
	_expect(bad, "non-ASCII open", builder.visible, true)
	_expect(bad, "non-ASCII status", builder.status_text().contains("ASCII"), true)
	_expect(bad, "pending", page.pending().size(), 0)
	_expect(bad, "completion", page.completion_text(), "")
	builder.press_cancel()
	_expect(bad, "closed", builder.visible, false)
	_close_builder(builder)
	_verdict(res, "completion_builder_rejects", bad)


static func _case_completion_edit_new(res: Dictionary, page: CompletionPage) -> void:
	var bad: Array[String] = []
	page.load_draft(_completion_draft("check", "", []))
	page.press_build()
	var builder: CheckBuilder = page.builder()
	_fill_trial(builder)
	builder.press_confirm()
	_expect(bad, "built", page.pending(), BUILT_ROW)
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	page.press_build()
	_expect(bad, "open", builder.visible, true)
	_expect(bad, "name", builder.name_edit.text, BUILT_NAME)
	_expect(bad, "editing", builder.editing_name(), BUILT_NAME)
	var cognition: ToolFilterCheckRow = builder.attribute_row("Cognition")
	_expect(bad, "Cognition on", cognition != null and cognition.button_pressed, true)
	var clever: ToolPixelSlider = builder.circumstance_list.slider_for(CLEVER)
	_expect(bad, "Clever", roundi(clever.value) if clever != null else -1, 10)
	var mage: ToolPixelSlider = builder.tradition_slider("Mage")
	_expect(bad, "Mage", roundi(mage.value) if mage != null else -1, 15)
	var multiplier: float = builder.multiplier_slider.value
	_expect(bad, "multiplier %s" % multiplier, is_equal_approx(multiplier, 1.5), true)
	_expect(bad, "duration", _duration_text(builder.duration), "2 hours")
	_expect(bad, "Yes pressed", builder.opposed_yes.button_pressed, true)
	_expect(bad, "hp", int(builder.consequences.values().get("hp", 0)), -2)
	_expect(bad, "same cells", builder.built_cells(), BUILT_ROW)
	_type_into(builder.name_edit, BUILT_NAME + " 2")
	builder.press_confirm()
	page.changed.disconnect(count)
	var got: Array[String] = page.pending()
	_expect(bad, "closed", builder.visible, false)
	_expect(bad, "pending name", got[0] if not got.is_empty() else "", BUILT_NAME + " 2")
	_expect(bad, "completion", page.completion_text(), "check:" + BUILT_NAME + " 2")
	_expect(bad, "dropdown text", page.check_dropdown.button_text(), BUILT_NAME + " 2 (new)")
	_expect(bad, "emissions", hits[0], 1)
	_close_builder(builder)
	_verdict(res, "completion_edit_new", bad)


static func _case_completion_pick_drops_new(res: Dictionary, page: CompletionPage) -> void:
	var bad: Array[String] = []
	page.load_draft(_completion_draft("check", "check:" + BUILT_NAME, BUILT_ROW))
	_expect(bad, "loaded pending", page.pending(), BUILT_ROW)
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	page.pick(_sheet_key(POISON_VIAL))
	page.changed.disconnect(count)
	_expect(bad, "pending", page.pending().size(), 0)
	_expect(bad, "completion", page.completion_text(), "check:" + POISON_VIAL)
	_expect(bad, "status names the dropped check", page.status_text().contains(BUILT_NAME), true)
	_expect(bad, "new option gone", _option_labels(page.check_dropdown).has(BUILT_NAME + " (new)"), false)
	_expect(bad, "button text", page.build_button.text, "Build new")
	_expect(bad, "emissions", hits[0], 1)
	_verdict(res, "completion_pick_drops_new", bad)


static func _case_completion_style_mismatch(res: Dictionary, page: CompletionPage) -> void:
	var bad: Array[String] = []
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	page.load_draft(_completion_draft("event", "check:" + BUILT_NAME, BUILT_ROW))
	var out: ContractDraft = _completion_draft("event", "check:" + BUILT_NAME, BUILT_ROW)
	page.store_draft(out)
	_expect(bad, "stored completion", out.completion, "")
	_expect(bad, "stored check_row", out.check_row.size(), 0)
	_expect(bad, "status mentions cleared", page.status_text().contains("cleared"), true)
	_expect(bad, "event panel", page.event_panel.visible, true)
	page.load_draft(_completion_draft("", "check:" + POISON_VIAL, []))
	_expect(bad, "blank style", page.status_text().contains("Style is blank"), true)
	_expect(bad, "blank style completion", page.completion_text(), "")
	page.changed.disconnect(count)
	_expect(bad, "emissions", hits[0], 0)
	_verdict(res, "completion_style_mismatch", bad)


static func _case_completion_cancel(res: Dictionary, page: CompletionPage) -> void:
	var bad: Array[String] = []
	page.load_draft(_completion_draft("check", "check:" + BUILT_NAME, BUILT_ROW))
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	page.build_button.grab_focus()
	var focused: bool = page.build_button.has_focus()
	page.press_build()
	var builder: CheckBuilder = page.builder()
	_expect(bad, "open", builder.visible, true)
	_expect(bad, "button focus before and after", "%s %s" % [focused, page.build_button.has_focus()], "true false")
	_type_into(builder.name_edit, "Trial of Nerve")
	page.press_build()
	_expect(bad, "press while open keeps the form", builder.name_edit.text, "Trial of Nerve")
	builder.press_cancel()
	page.changed.disconnect(count)
	_expect(bad, "hidden", builder.visible, false)
	_expect(bad, "pending", page.pending(), BUILT_ROW)
	_expect(bad, "completion", page.completion_text(), "check:" + BUILT_NAME)
	_expect(bad, "emissions", hits[0], 0)
	_close_builder(builder)
	_verdict(res, "completion_cancel", bad)


#Steps between marks: load, a dropdown pick, the same pick again, an add, a drop by pick, none, a load that clears.
static func _case_completion_notify(res: Dictionary, page: CompletionPage) -> void:
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	var marks: Array[int] = []
	page.load_draft(_completion_draft("check", "", []))
	marks.append(hits[0])
	page.check_dropdown.select(_sheet_key(POISON_VIAL), true)
	marks.append(hits[0])
	page.check_dropdown.select(_sheet_key(POISON_VIAL), true)
	marks.append(hits[0])
	page.press_build()
	_fill_trial(page.builder())
	page.builder().press_confirm()
	marks.append(hits[0])
	page.pick(_sheet_key(POISON_VIAL))
	marks.append(hits[0])
	page.check_dropdown.select(&"none", true)
	marks.append(hits[0])
	page.load_draft(_completion_draft("event", "check:" + POISON_VIAL, []))
	marks.append(hits[0])
	page.changed.disconnect(count)
	_close_builder(page.builder())
	TestFixtures.check(res, "completion_notify", _steps(marks) == "0 1 0 1 1 1 0", "steps %s" % _steps(marks))


#Sheet rows named like the reserved keys (none, new:Foo, unknown:Bar) pick, show and load as sheet checks.
static func _case_completion_reserved_names(res: Dictionary, page: CompletionPage) -> void:
	var path: String = ContractBuilderData.checks_path
	if not path.begins_with(SCRATCH_DIR):
		TestFixtures.check(res, "completion_reserved_names", false, "checks_path %s is not a scratch copy" % path)
		return
	var bad: Array[String] = []
	for check_name: String in RESERVED_NAMES:
		var cells: Array[String] = []
		cells.assign(POISON_ROW)
		cells[CheckSheet.NAME] = check_name
		var result: Dictionary = TsvRowWriter.append_row(path, cells)
		_expect(bad, "append %s" % check_name, bool(result.get("ok", false)), true)
	page.load_draft(_completion_draft("check", "", []))
	var labels: Array[String] = _option_labels(page.check_dropdown)
	_expect(bad, "(none) options", labels.count("(none)"), 1)
	_expect(bad, "sheet labels", labels.has("none") and labels.has("new:Foo") and labels.has("unknown:Bar"), true)
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	page.check_dropdown.select(_sheet_key("none"), true)
	_expect(bad, "none completion", page.completion_text(), "check:none")
	_expect(bad, "none complete", page.is_complete(), true)
	_expect(bad, "none shown", page.check_dropdown.button_text(), "none")
	page.check_dropdown.select(&"none", true)
	_expect(bad, "(none) completion", page.completion_text(), "")
	page.check_dropdown.select(_sheet_key("new:Foo"), true)
	_expect(bad, "new:Foo completion", page.completion_text(), "check:new:Foo")
	_expect(bad, "new:Foo shown", page.check_dropdown.button_text(), "new:Foo")
	page.changed.disconnect(count)
	_expect(bad, "emissions", hits[0], 3)
	page.load_draft(_completion_draft("check", "check:" + BUILT_NAME, BUILT_ROW))
	page.pick(_sheet_key("new:Foo"))
	_expect(bad, "new:Foo over a pending check", page.completion_text(), "check:new:Foo")
	_expect(bad, "pending dropped", page.pending().size(), 0)
	page.load_draft(_completion_draft("check", "check:unknown:Bar", []))
	_expect(bad, "unknown:Bar selected", page.check_dropdown.selected, _sheet_key("unknown:Bar"))
	_expect(bad, "unknown:Bar status", page.status_text(), "")
	page.load_draft(_completion_draft("check", "check:none", []))
	_expect(bad, "none loaded", page.check_dropdown.selected, _sheet_key("none"))
	_expect(bad, "none loaded complete", page.is_complete(), true)
	_verdict(res, "completion_reserved_names", bad)


static func _case_event_panel_rows(res: Dictionary, page: CompletionPage) -> void:
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	page.load_draft(_event_draft("event", "", "", 0, ""))
	page.changed.disconnect(count)
	_same(res, "event_panel_rows", "%s %s %s" % [page.event_panel.visible, page.check_panel.visible,
		page.timeline_panel.visible], "true false false")
	var want: Array[String] = ["none"]
	want.append_array(EVENT_NAMES)
	want.append_array(EventConfig.PLANNED)
	var dropdown: ToolOptionDropdown = page.event_dropdown()
	_same(res, "event_panel_rows_keys", ", ".join(_keys(dropdown)), ", ".join(want))
	var labels: Array[String] = _option_labels(dropdown)
	_same(res, "event_panel_rows_labels", "%s | %s | %s" % [labels[0], labels[1],
		", ".join(labels.slice(1 + EVENT_NAMES.size()))], "(none) | Poison the Target | Fight Bandits (planned), "
		+ "Military Battle (planned), Prison Break (planned), Chase (planned)")
	_same(res, "event_panel_rows_shown", dropdown.button_text(), "(none)")
	_same(res, "event_panel_rows_incomplete", page.is_complete(), false)
	_same(res, "event_panel_rows_config", "%s %s" % [page.config_panel().visible, page.config_panel().has_fields()],
		"false false")
	_same(res, "event_panel_rows_duration", "%s = %d" % [_duration_text(page.duration()),
		page.duration().minutes()], "1 hours = 60")
	_same(res, "event_panel_rows_steppers", CheckSheet.format_consequence(page.steppers().values()), "")
	_same(res, "event_panel_rows_status", page.status_text(), "")
	_same(res, "event_panel_rows_silent", hits[0], 0)


static func _case_event_pick_fresh(res: Dictionary, page: CompletionPage) -> void:
	page.load_draft(_event_draft("event", "", "", 0, ""))
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	page.pick_event(&"Battle")
	_same(res, "event_pick_fresh", _cells(page), "event:Battle |  | 60 | ")
	_same(res, "event_pick_fresh_emits", hits[0], 1)
	page.pick_event(&"Battle")
	_same(res, "event_pick_fresh_repeat", "%d %s" % [hits[0], page.event_text()], "1 Battle")
	page.pick_event(&"Not An Event")
	_same(res, "event_pick_fresh_unlisted", "%d %s" % [hits[0], page.completion_text()], "1 event:Battle")
	page.changed.disconnect(count)
	_same(res, "event_pick_fresh_store", _stored_event(page), "event:Battle |  | 60 | ")


static func _case_event_planned(res: Dictionary, page: CompletionPage) -> void:
	page.load_draft(_event_draft("event", "", "", 0, ""))
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	page.pick_event(&"Fight Bandits")
	_same(res, "event_planned", page.status_text(), _planned_text("Fight Bandits"))
	_same(res, "event_planned_complete", page.is_complete(), true)
	_same(res, "event_planned_config", page.config_text(), "bandits=1")
	_same(res, "event_planned_label", page.event_dropdown().button_text(), "Fight Bandits (planned)")
	var slider: ToolPixelSlider = page.config_panel().slider("bandits")
	if slider == null:
		TestFixtures.check(res, "event_planned_slider", false, "no bandits slider")
		page.changed.disconnect(count)
		return
	_same(res, "event_planned_slider", "%s..%s step %s at %s" % [EventConfig.format_number(slider.min_value),
		EventConfig.format_number(slider.max_value), EventConfig.format_number(slider.step),
		EventConfig.format_number(slider.value)], "0.5..4 step 0.5 at 1")
	slider._apply(2.0)
	var shown: Label = slider.get_parent().get_child(2) as Label
	_same(res, "event_planned_move", "%s, %d, %s" % [page.config_text(), hits[0], shown.text], "bandits=2, 2, x2")
	slider._apply(1.5)
	_same(res, "event_planned_half", "%s, %s" % [page.config_text(), shown.text], "bandits=1.5, x1.5")
	slider._apply(1.5)
	page.changed.disconnect(count)
	_same(res, "event_planned_emits", "%d '%s'" % [hits[0], _stored_event(page)],
		"3 'event:Fight Bandits | bandits=1.5 | 60 | '")


static func _case_event_chase(res: Dictionary, page: CompletionPage) -> void:
	page.load_draft(_event_draft("event", "", "", 0, ""))
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	page.pick_event(&"Chase")
	var panel: EventConfigPanel = page.config_panel()
	_same(res, "event_chase", page.config_text(), "chase=foot; chasing=mercs")
	var foot: ToolBevelButton = panel.button("chase", "foot")
	var vehicle: ToolBevelButton = panel.button("chase", "vehicle")
	var mercs: ToolBevelButton = panel.button("chasing", "mercs")
	var target: ToolBevelButton = panel.button("chasing", "target")
	if foot == null or vehicle == null or mercs == null or target == null:
		TestFixtures.check(res, "event_chase_buttons", false, "a Chase button is missing")
		page.changed.disconnect(count)
		return
	var row: Array[BevelButton] = [foot, vehicle, mercs, target]
	_same(res, "event_chase_buttons", "%s | %s" % [", ".join(_texts(row)), _pressed(panel)],
		"Foot, Vehicle, Mercs, Target | chase=foot, chasing=mercs")
	_same(res, "event_chase_order", "%s %s" % [foot.get_index() < vehicle.get_index(),
		mercs.get_index() < target.get_index()], "true true")
	_click(vehicle)
	_same(res, "event_chase_vehicle", "%s | %d | %s" % [page.config_text(), hits[0], _pressed(panel)],
		"chase=vehicle; chasing=mercs | 2 | chase=vehicle, chasing=mercs")
	_click(vehicle)
	_same(res, "event_chase_repress", "%s | %d | %s" % [page.config_text(), hits[0], _pressed(panel)],
		"chase=vehicle; chasing=mercs | 3 | chase=vehicle, chasing=mercs")
	_click(target)
	_same(res, "event_chase_target", "%s | %d" % [page.config_text(), hits[0]], "chase=vehicle; chasing=target | 4")
	foot.button_pressed = true
	_same(res, "event_chase_toggle", "%s | %d" % [page.config_text(), hits[0]], "chase=foot; chasing=target | 5")
	page.changed.disconnect(count)
	_same(res, "event_chase_store", _stored_event(page), "event:Chase | chase=foot; chasing=target | 60 | ")


static func _case_event_time(res: Dictionary, page: CompletionPage) -> void:
	page.load_draft(_event_draft("event", "event:Battle", "", 60, ""))
	var duration: ToolDuration = page.duration()
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	duration.stepper._move(1)
	_same(res, "event_time", "%s = %d, %d" % [_duration_text(duration), page.time_minutes(), hits[0]],
		"2 hours = 120, 1")
	duration.dropdown.select(&"days", true)
	_same(res, "event_time_days", "%d, %d" % [page.time_minutes(), hits[0]], "2880, 2")
	duration.dropdown.select(&"hours", true)
	_same(res, "event_time_hours", "%d, %d" % [page.time_minutes(), hits[0]], "120, 3")
	duration.dropdown.select(&"hours", true)
	page.changed.disconnect(count)
	_same(res, "event_time_same_unit", hits[0], 3)
	_same(res, "event_time_store", _stored_event(page), "event:Battle |  | 120 | ")


static func _case_event_consequence(res: Dictionary, page: CompletionPage) -> void:
	page.load_draft(_event_draft("event", "event:Battle", "", 60, ""))
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	page.steppers().stepper("hp")._move(-2)
	_same(res, "event_consequence_hp", "%s | %d" % [page.consequence_text(), hits[0]], "hp -2 | 1")
	page.steppers().stepper("guild")._move(-1)
	_same(res, "event_consequence", "%s | %d" % [page.consequence_text(), hits[0]], "hp -2, guild -1 | 2")
	page.changed.disconnect(count)
	var out: ContractDraft = _event_draft("event", "", "", 0, "")
	page.store_draft(out)
	_same(res, "event_consequence_store", out.consequence, "hp -2, guild -1")
	page.load_draft(_event_draft("event", "event:Battle", "", 60, ""))
	page.load_draft(out)
	_same(res, "event_consequence_reload", "%s | %s" % [CheckSheet.format_consequence(page.steppers().values()),
		page.consequence_text()], "hp -2, guild -1 | hp -2, guild -1")


static func _case_event_load_round_trip(res: Dictionary, page: CompletionPage) -> void:
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	page.load_draft(_event_draft("event", "event:Chase", "chase=vehicle; chasing=target", 90, "guild -1"))
	page.changed.disconnect(count)
	_same(res, "event_load_round_trip", _stored_event(page),
		"event:Chase | chase=vehicle; chasing=target | 90 | guild -1")
	_same(res, "event_load_round_trip_buttons", _pressed(page.config_panel()), "chase=vehicle, chasing=target")
	_same(res, "event_load_round_trip_duration", _duration_text(page.duration()), "90 minutes")
	_same(res, "event_load_round_trip_steppers", CheckSheet.format_consequence(page.steppers().values()), "guild -1")
	_same(res, "event_load_round_trip_complete", "%s %s" % [page.is_complete(), page.status_text()],
		"true " + _planned_text("Chase"))
	_same(res, "event_load_round_trip_silent", hits[0], 0)


static func _case_event_unknown_loaded(res: Dictionary, page: CompletionPage) -> void:
	page.load_draft(_event_draft("event", "event:Ghost", "", 30, ""))
	var dropdown: ToolOptionDropdown = page.event_dropdown()
	_same(res, "event_unknown_loaded", "%s / %s" % [dropdown.selected, dropdown.button_text()],
		"unknown:Ghost / Ghost (not in sheet)")
	_same(res, "event_unknown_loaded_complete", page.is_complete(), true)
	_same(res, "event_unknown_loaded_status", page.status_text(), "Event Ghost is not in Events.tsv")
	_same(res, "event_unknown_loaded_store", _stored_event(page), "event:Ghost |  | 30 | ")
	_same(res, "event_unknown_loaded_panel", "%s %s" % [page.config_panel().visible,
		page.config_panel().has_fields()], "true false")
	page.pick_event(&"Battle")
	_same(res, "event_unknown_loaded_dropped", "%s %d" % [_keys(dropdown).has("unknown:Ghost"),
		_keys(dropdown).size()], "false %d" % (1 + EVENT_NAMES.size() + EventConfig.PLANNED.size()))


static func _case_event_bad_config_loaded(res: Dictionary, page: CompletionPage) -> void:
	page.load_draft(_event_draft("event", "event:Chase", "chase=horse", 60, ""))
	_same(res, "event_bad_config_loaded", page.status_text(),
		_planned_text("Chase") + "\nEvent Config for Chase: chase must be foot or vehicle")
	_same(res, "event_bad_config_incomplete", page.is_complete(), false)
	_same(res, "event_bad_config_buttons", _pressed(page.config_panel()), "chase=foot, chasing=mercs")
	_same(res, "event_bad_config_store", _stored_event(page), "event:Chase | chase=horse | 60 | ")
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	var foot: ToolBevelButton = page.config_panel().button("chase", "foot")
	if foot != null:
		_click(foot)
	_same(res, "event_bad_config_shown_pick", "%s | %s | %d | %s" % [page.config_text(), page.is_complete(), hits[0],
		page.status_text()], "chase=foot; chasing=mercs | true | 1 | " + _planned_text("Chase"))
	page.load_draft(_event_draft("event", "event:Chase", "chase=horse", 60, ""))
	hits[0] = 0
	var vehicle: ToolBevelButton = page.config_panel().button("chase", "vehicle")
	if vehicle != null:
		_click(vehicle)
	page.changed.disconnect(count)
	_same(res, "event_bad_config_fixed", "%s | %s | %d | %s" % [page.config_text(), page.is_complete(), hits[0],
		page.status_text()], "chase=vehicle; chasing=mercs | true | 1 | " + _planned_text("Chase"))
	page.load_draft(_event_draft("event", "event:Fight Bandits", "bandits=1.3", 60, ""))
	var slider: ToolPixelSlider = page.config_panel().slider("bandits")
	_same(res, "event_bad_config_slider", "%s | %s | %s" % [EventConfig.format_number(slider.value)
		if slider != null else "none", page.is_complete(),
		page.status_text().contains("Event Config for Fight Bandits: bandits must be 0.5 to 4 in steps of 0.5")],
		"1 | false | true")


static func _case_event_none(res: Dictionary, page: CompletionPage) -> void:
	page.load_draft(_event_draft("event", "", "", 120, "hp -1"))
	page.pick_event(&"Chase")
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	page.pick_event(&"none")
	page.changed.disconnect(count)
	_same(res, "event_none", "%s | %s | %s" % [page.completion_text(), page.config_text(), page.event_text()],
		" |  | ")
	_same(res, "event_none_incomplete", page.is_complete(), false)
	_same(res, "event_none_panel", "%s %s" % [page.config_panel().visible, page.event_dropdown().button_text()],
		"false (none)")
	_same(res, "event_none_time", _stored_event(page), " |  | 120 | hp -1")
	_same(res, "event_none_emits", hits[0], 1)


static func _case_event_style_mismatch(res: Dictionary, page: CompletionPage) -> void:
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	page.load_draft(_event_draft("check", "event:Battle", "", 90, "hp -2"))
	_same(res, "event_style_mismatch", _stored_event(page), " |  | 0 | ")
	_same(res, "event_style_mismatch_status", page.status_text(), "Completion cleared: Style is check")
	page.load_draft(_event_draft("timeline", "", "bandits=1", 30, "guild -1"))
	_same(res, "event_style_mismatch_timeline", "%s / %s" % [_stored_event(page), page.status_text()],
		" |  | 0 |  / Event Config, Time and Consequence cleared: Style is timeline")
	page.load_draft(_event_draft("check", "check:" + POISON_VIAL, "bandits=1", 120, "hp -2"))
	_same(res, "event_style_mismatch_check_kept", "%s / %s / %s" % [_stored_event(page), page.is_complete(),
		page.status_text()], "check:Poison Vial |  | 0 |  / true / Event Config, Time and Consequence cleared: Style is check")
	page.load_draft(_event_draft("", "event:Chase", "chase=foot", 60, ""))
	_same(res, "event_style_mismatch_blank", "%s / %s" % [_stored_event(page),
		page.status_text().contains("Completion cleared: Style is blank")], " |  | 0 |  / true")
	page.changed.disconnect(count)
	_same(res, "event_style_mismatch_silent", hits[0], 0)


static func _case_event_check_untouched(res: Dictionary, page: CompletionPage) -> void:
	page.load_draft(_event_draft("check", "check:" + POISON_VIAL, "", 120, ""))
	_same(res, "event_check_untouched", _stored_event(page), "check:Poison Vial |  | 120 | ")
	_same(res, "event_check_untouched_status", "%s '%s'" % [page.check_dropdown.selected, page.status_text()],
		"sheet:Poison Vial ''")


static func _case_event_notify(res: Dictionary, page: CompletionPage) -> void:
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	var marks: Array[int] = []
	page.load_draft(_event_draft("event", "", "", 0, ""))
	marks.append(hits[0])
	page.pick_event(&"Fight Bandits")
	marks.append(hits[0])
	var slider: ToolPixelSlider = page.config_panel().slider("bandits")
	if slider != null:
		slider._apply(3.0)
	marks.append(hits[0])
	page.pick_event(&"Chase")
	marks.append(hits[0])
	var vehicle: ToolBevelButton = page.config_panel().button("chase", "vehicle")
	if vehicle != null:
		_click(vehicle)
	marks.append(hits[0])
	page.duration().stepper._move(1)
	marks.append(hits[0])
	page.steppers().stepper("ep")._move(-1)
	marks.append(hits[0])
	page.load_draft(_event_draft("event", "event:Chase", "chase=vehicle", 60, "ep -1"))
	marks.append(hits[0])
	page.changed.disconnect(count)
	TestFixtures.check(res, "event_notify", _steps(marks) == "0 1 1 1 1 1 1 0", "steps %s" % _steps(marks))


#Time the Time row cannot show (1441 is 11 x 131 minutes) is kept with a status line until the row changes.
static func _case_event_time_unshown(res: Dictionary, page: CompletionPage) -> void:
	page.load_draft(_event_draft("event", "event:Battle", "", 1441, ""))
	_same(res, "event_time_unshown", "%s | %s | %s | %s" % [_stored_event(page), _duration_text(page.duration()),
		page.is_complete(), page.status_text()], "event:Battle |  | 1441 |  | 999 minutes | true | "
		+ "Time 1441 minutes cannot be shown in the Time row; it is kept until the row changes")
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	page.duration().stepper._move(-1)
	page.changed.disconnect(count)
	_same(res, "event_time_unshown_moved", "%d | %d | '%s'" % [page.time_minutes(), hits[0], page.status_text()],
		"998 | 1 | ''")


#A Consequence the steppers cannot show is kept with a status line and leaves the page incomplete until a stepper moves.
static func _case_event_consequence_bad(res: Dictionary, page: CompletionPage) -> void:
	page.load_draft(_event_draft("event", "event:Battle", "", 60, "hp 2"))
	_same(res, "event_consequence_bad", "%s | %s | %s" % [_stored_event(page), page.is_complete(), page.status_text()],
		"event:Battle |  | 60 | hp 2 | false | Consequence: bad token hp 2; the cell is kept until a stepper changes")
	page.load_draft(_event_draft("event", "event:Battle", "", 60, "guild -1, hp -10"))
	_same(res, "event_consequence_bad_clamped", "%s | %s" % [CheckSheet.format_consequence(page.steppers().values()),
		page.status_text()], "hp -9, guild -1 | Consequence: bad token hp -10; the cell is kept until a stepper changes")
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	page.steppers().stepper("hp")._move(1)
	page.changed.disconnect(count)
	_same(res, "event_consequence_bad_moved", "%s | %s | %d | '%s'" % [page.consequence_text(), page.is_complete(),
		hits[0], page.status_text()], "hp -8, guild -1 | true | 1 | ''")


#Under Style event a completion other than event:<name> is named in the status; inner spaces load as the plain name.
static func _case_event_completion_text(res: Dictionary, page: CompletionPage) -> void:
	page.load_draft(_event_draft("event", "Event:Battle", "", 60, ""))
	_same(res, "event_completion_expected", "%s | %s | %s" % [page.event_dropdown().selected, page.is_complete(),
		page.status_text()], "none | false | Completion: expected event:<name> under Style event, got Event:Battle")
	page.load_draft(_event_draft("event", "event:  Battle", "", 60, ""))
	_same(res, "event_completion_spaces", "%s | %s | '%s'" % [_stored_event(page), page.event_text(),
		page.status_text()], "event:Battle |  | 60 |  | Battle | ''")


#An Events.tsv row named unknown:Bar keeps its plain key: one option, complete, no status line; the copy is put back.
static func _case_event_sheet_unknown_name(res: Dictionary, page: CompletionPage) -> void:
	var event_name: String = "unknown:Bar"
	var path: String = ContractBuilderData.events_path
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var error: String = "the copy is empty" if bytes.is_empty() else _append_event(event_name)
	if error != "":
		TestFixtures.check(res, "event_sheet_unknown_name", false, "cannot append %s: %s" % [event_name, error])
		return
	page.load_draft(_event_draft("event", "event:" + event_name, "", 60, ""))
	var dropdown: ToolOptionDropdown = page.event_dropdown()
	var got: String = "%s | %d | %s | '%s'" % [dropdown.selected, _keys(dropdown).count(event_name),
		page.is_complete(), page.status_text()]
	var restored: bool = _store_bytes(path, bytes)
	page.load_draft(_event_draft("event", "", "", 0, ""))
	_same(res, "event_sheet_unknown_name", got, "unknown:Bar | 1 | true | ''")
	_same(res, "event_sheet_unknown_restored", "%s %s" % [restored,
		ContractBuilderData.event_names().has(event_name)], "true false")


#Appends a Primary row named event_name to the scratch Events.tsv copy; returns why it could not, else "".
static func _append_event(event_name: String) -> String:
	var path: String = ContractBuilderData.events_path
	if not path.begins_with(SCRATCH_DIR):
		return "events_path %s is not a scratch copy" % path
	var table: Dictionary = TsvRowWriter.read_table(path)
	if not bool(table["ok"]):
		return String(table["error"])
	var lines: PackedStringArray = table["lines"]
	var cells: Array[String] = []
	for title: String in lines[0].split(TsvRowWriter.TAB):
		if title.strip_edges() == ContractBuilderData.EVENTS_NAME_COLUMN:
			cells.append(event_name)
		elif title.strip_edges() == ContractBuilderData.EVENTS_TYPE_COLUMN:
			cells.append(ContractBuilderData.EVENTS_PRIMARY_TYPE)
		else:
			cells.append("")
	if not cells.has(event_name) or not cells.has(ContractBuilderData.EVENTS_PRIMARY_TYPE):
		return "no %s or %s column" % [ContractBuilderData.EVENTS_NAME_COLUMN, ContractBuilderData.EVENTS_TYPE_COLUMN]
	return String(TsvRowWriter.append_row(path, cells).get("error", ""))


static func _case_tl_fresh_two_steps(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, "")
	_same(res, "tl_fresh_two_steps", "%s | %s | %s %s %s | %s | %s '%s' | %s" % [_tl_ids(tl), tl.is_fresh(),
		tl.fail_box(0).button_pressed, tl.fail_box(1).button_pressed, tl.fail_box(1).disabled,
		tl.name_dropdown(0).selected, page.is_complete(), page.completion_text(), page.status_text()],
		"a b | true | false true true | none | false '' | " + CompletionPage.TIMELINE_EMPTY_TEXT)


static func _case_tl_unnamed_step_survives_previous(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, "")
	tl.name_dropdown(1).select(&"Battle", true)
	_same(res, "tl_unnamed_step_survives_previous", "%s | %s | %s" % [page.completion_text(), page.is_complete(),
		page.status_text()], "a=event: ; b=event:Battle fail time=60 | false | Timeline: Step a: pick an event or a check")


static func _case_tl_add_step_moves_fail(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, TL_VALID)
	tl.add_button().pressed.emit()
	_same(res, "tl_add_step_moves_fail", "%s | %s %s %s %s | %d" % [page.completion_text(),
		tl.fail_box(1).button_pressed, tl.fail_box(1).disabled, tl.fail_box(2).button_pressed, tl.fail_box(2).disabled,
		tl.selected_index()], "a=event:Battle time=60 ; b=check:Poison Vial fail ; c=event: fail | true false true true | 2")


static func _case_tl_add_step_disabled_at_max(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, _tl_chain(11))
	var below: bool = tl.add_button().disabled
	var full: String = _tl_chain(12)
	tl = _tl_load(page, full)
	var at_max: bool = tl.add_button().disabled
	tl.add_button().pressed.emit()
	_same(res, "tl_add_step_disabled_at_max", "%s %s %d %s" % [below, at_max, tl.steps().size(),
		page.completion_text() == full], "false true 12 true")


static func _case_tl_add_branch_failure(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, TL_VALID)
	var bad: Array[String] = []
	tl.branch_button().pressed.emit()
	_expect(bad, "first", page.completion_text(),
		"a=event:Battle time=60 ; b=event: if a.failure ; c=check:Poison Vial fail")
	_expect(bad, "first when", tl.when_dropdown(1).selected, &"if:a.failure")
	tl.select_step(0)
	tl.branch_button().pressed.emit()
	_expect(bad, "second", page.completion_text(),
		"a=event:Battle time=60 ; b1=event: if a.failure ; b2=event: if a.failure ; c=check:Poison Vial fail")
	_expect(bad, "selected", tl.selected_index(), 2)
	_verdict(res, "tl_add_branch_failure", bad)


static func _case_tl_add_branch_success_when_flagged(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, "a=event:Battle fail time=60 ; b=check:Poison Vial fail")
	tl.branch_button().pressed.emit()
	_same(res, "tl_add_branch_success_when_flagged", "%s | %s" % [page.completion_text(),
		tl.when_dropdown(1).button_text()],
		"a=event:Battle fail time=60 ; b=event: if a.success ; c=check:Poison Vial fail | a succeeds")


static func _case_tl_add_branch_disabled_on_last(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, TL_VALID)
	var first: bool = tl.branch_button().disabled
	tl.select_step(1)
	var last: bool = tl.branch_button().disabled
	tl.branch_button().pressed.emit()
	_same(res, "tl_add_branch_disabled_on_last", "%s %s %s" % [first, last, page.completion_text() == TL_VALID],
		"false true true")


static func _case_tl_remove_resets_when(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, TL_WAIT)
	tl.remove_button().pressed.emit()
	_same(res, "tl_remove_resets_when", "%s | %s | %s" % [page.completion_text(), tl.when_dropdown(0).selected,
		page.status_text()], "a=event:Battle time=60 ; b=check:Poison Vial fail | always | "
		+ CompletionPage.REMOVED_TEXT % "a")


static func _case_tl_remove_min_disabled(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, TL_VALID)
	var at_min: bool = tl.remove_button().disabled
	tl.remove_button().pressed.emit()
	var kept: bool = page.completion_text() == TL_VALID
	tl.add_button().pressed.emit()
	_same(res, "tl_remove_min_disabled", "%s %s %s" % [at_min, kept, tl.remove_button().disabled], "true true false")


static func _case_tl_remove_last_new_last_fails(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, TL_WAIT)
	tl.select_step(2)
	tl.remove_button().pressed.emit()
	_same(res, "tl_remove_last_new_last_fails", "%s | %s %s | %s" % [page.completion_text(),
		tl.fail_box(1).button_pressed, tl.fail_box(1).disabled, page.status_text()],
		"a=event:Battle time=60 ; b=event:Battle fail time=60 | true true | "
		+ CompletionPage.LAST_MOVED_TEXT % ["c", "b"])


static func _case_tl_remove_no_waiter_no_note(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, TL_WAIT)
	tl.select_step(1)
	tl.remove_button().pressed.emit()
	_same(res, "tl_remove_no_waiter_no_note", "%s | %s" % [page.completion_text(),
		page.status_text().contains(CompletionPage.REMOVED_TEXT % "b")],
		"a=event:Battle time=60 ; b=check:Poison Vial fail | false")


static func _case_tl_move_refused(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, TL_WAIT)
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	tl.select_step(1)
	tl.up_button().pressed.emit()
	var up_note: String = page.status_text()
	tl.select_step(0)
	tl.down_button().pressed.emit()
	page.changed.disconnect(count)
	var want: String = CompletionPage.MOVE_REFUSED_TEXT % ["b", "a"]
	_same(res, "tl_move_refused", "%s | %s | %s %d" % [up_note, page.status_text(), page.completion_text() == TL_WAIT,
		hits[0]], "%s | %s | true 0" % [want, want])


static func _case_tl_move_into_last_refused(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, TL_WAIT)
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	tl.select_step(1)
	tl.down_button().pressed.emit()
	page.changed.disconnect(count)
	_same(res, "tl_move_into_last_refused", "%s | %s %d" % [page.status_text(), page.completion_text() == TL_WAIT,
		hits[0]], "%s | true 0" % (CompletionPage.LAST_IF_REFUSED_TEXT % ["b", "a"]))


static func _case_tl_move_ok_renumber(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, "a=event:Battle time=60 ; b=check:Poison Vial ; c=event:Battle fail time=120")
	var bad: Array[String] = []
	tl.down_button().pressed.emit()
	_expect(bad, "down", page.completion_text(),
		"a=check:Poison Vial ; b=event:Battle time=60 ; c=event:Battle fail time=120")
	_expect(bad, "down selected", tl.selected_index(), 1)
	tl.select_step(2)
	tl.up_button().pressed.emit()
	_expect(bad, "last up", page.completion_text(),
		"a=check:Poison Vial ; b=event:Battle fail time=120 ; c=event:Battle fail time=60")
	_expect(bad, "old last free", "%s %s" % [tl.fail_box(1).button_pressed, tl.fail_box(1).disabled], "true false")
	_expect(bad, "new last locked", "%s %s" % [tl.fail_box(2).button_pressed, tl.fail_box(2).disabled], "true true")
	_verdict(res, "tl_move_ok_renumber", bad)


static func _case_tl_last_fail_locked(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, TL_VALID)
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	tl.fail_box(1).button_pressed = false
	page.changed.disconnect(count)
	_same(res, "tl_last_fail_locked", "%s %s | %s %s | %s %d" % [tl.fail_box(1).button_pressed, tl.fail_box(1).disabled,
		tl.when_dropdown(1).disabled, tl.when_dropdown(1).selected, page.completion_text() == TL_VALID, hits[0]],
		"true true | true always | true 0")


static func _case_tl_fail_on_with_failure_dependents(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, TL_WAIT)
	var bad: Array[String] = []
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	tl.fail_box(0).button_pressed = true
	_expect(bad, "refused", page.status_text(), CompletionPage.FAIL_REFUSED_TEXT % ["b", "a", "a"])
	_expect(bad, "box", tl.fail_box(0).button_pressed, false)
	_expect(bad, "cell", page.completion_text(), TL_WAIT)
	_expect(bad, "silent", hits[0], 0)
	tl.when_dropdown(1).select(&"if:a.success", true)
	tl.fail_box(0).button_pressed = true
	_expect(bad, "success waiter", page.completion_text(),
		"a=event:Battle fail time=60 ; b=event:Battle if a.success time=60 ; c=check:Poison Vial fail")
	_expect(bad, "notifies", hits[0], 2)
	page.changed.disconnect(count)
	_verdict(res, "tl_fail_on_with_failure_dependents", bad)


static func _case_tl_when_options_earlier_only(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, "a=event:Battle time=60 ; b=event:Battle time=60 ; c=check:Poison Vial fail")
	_same(res, "tl_when_options_earlier_only", "%s | %s | %s" % [", ".join(_keys(tl.when_dropdown(0))),
		", ".join(_option_labels(tl.when_dropdown(1))), ", ".join(_keys(tl.when_dropdown(2)))],
		"always | Always, a succeeds, a fails | always, if:a.success, if:a.failure, if:b.success, if:b.failure")


static func _case_tl_when_hides_dead_branch(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, "a=event:Battle fail time=60 ; b=event:Battle time=60 ; c=check:Poison Vial fail")
	_same(res, "tl_when_hides_dead_branch", "%s | %s" % [", ".join(_keys(tl.when_dropdown(1))),
		", ".join(_keys(tl.when_dropdown(2)))], "always, if:a.success | always, if:a.success, if:b.success, if:b.failure")


static func _case_tl_kind_switch_clears(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, "a=event:Battle role=Leader time=90 cons=hp -1 ; b=check:Poison Vial fail")
	tl.kind_button(0, "check").button_pressed = true
	_same(res, "tl_kind_switch_clears", "%s | %s %s" % [page.completion_text(), tl.name_dropdown(0).selected,
		tl.kind_button(0, "check").button_pressed], "a=check: role=Leader ; b=check:Poison Vial fail | none true")


static func _case_tl_event_pick_time_default(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, "")
	var bad: Array[String] = []
	tl.name_dropdown(0).select(&"Battle", true)
	_expect(bad, "battle", page.completion_text(), "a=event:Battle time=60 ; b=event: fail")
	_expect(bad, "shown", tl.duration().minutes(), 60)
	tl.duration().stepper._move(1)
	tl.name_dropdown(0).select(&"Chase", true)
	_expect(bad, "kept time", page.completion_text(), "a=event:Chase time=120 ; b=event: fail")
	_verdict(res, "tl_event_pick_time_default", bad)


static func _case_tl_event_step_no_time_shows_default(res: Dictionary, page: CompletionPage) -> void:
	var cell: String = "a=event:Battle ; b=check:Poison Vial fail"
	var tl: TimelineEditor = _tl_load(page, cell)
	var loaded: String = "%d %d %s %s" % [(tl.steps()[0] as TimelineGrammar.Step).time, tl.duration().minutes(),
		page.completion_text() == cell, page.is_complete()]
	tl.role_dropdown().select(&"Leader", true)
	_same(res, "tl_event_step_no_time_shows_default", "%s | %s" % [loaded, page.completion_text()],
		"60 60 true true | a=event:Battle role=Leader time=60 ; b=check:Poison Vial fail")


static func _case_tl_cfg_per_step(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, "a=event:Chase time=60 ; b=event:Chase fail time=60")
	var bad: Array[String] = []
	var vehicle: ToolBevelButton = tl.config_panel().button("chase", "vehicle")
	if vehicle != null:
		_click(vehicle)
	_expect(bad, "first", page.completion_text(),
		"a=event:Chase time=60 cfg=chase=vehicle,chasing=mercs ; b=event:Chase fail time=60")
	tl.select_step(1)
	var foot: ToolBevelButton = tl.config_panel().button("chase", "foot")
	_expect(bad, "second shows default", foot != null and foot.button_pressed, true)
	var target: ToolBevelButton = tl.config_panel().button("chasing", "target")
	if target != null:
		_click(target)
	_expect(bad, "second", page.completion_text(),
		"a=event:Chase time=60 cfg=chase=vehicle,chasing=mercs ; b=event:Chase fail time=60 cfg=chase=foot,chasing=target")
	tl.select_step(0)
	_expect(bad, "first shown", tl.config_panel().config(), "chase=vehicle; chasing=mercs")
	_verdict(res, "tl_cfg_per_step", bad)


static func _case_tl_cons_per_step(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, "a=event:Battle time=60 ; b=event:Battle fail time=60")
	tl.steppers().stepper("hp")._move(-1)
	var first: String = page.completion_text()
	tl.select_step(1)
	var second: int = int(tl.steppers().values().get("hp", 0))
	tl.select_step(0)
	_same(res, "tl_cons_per_step", "%s | %d %d" % [first, second, int(tl.steppers().values().get("hp", 0))],
		"a=event:Battle time=60 cons=hp -1 ; b=event:Battle fail time=60 | 0 -1")


static func _case_tl_role_list(res: Dictionary, page: CompletionPage) -> void:
	var roles: Array[String] = ["Support", "Assassin", "Bogus", "Guide", "Leader"]
	page.load_draft(_tl_draft(TL_VALID, roles, []))
	var dropdown: ToolOptionDropdown = page.timeline().role_dropdown()
	_same(res, "tl_role_list", "%s | %s" % [", ".join(_keys(dropdown)), dropdown.button_text()],
		"any, Leader, Support, Assassin, Guide | Any (best suited)")


static func _case_tl_role_stale_blocks(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, "a=event:Battle role=Driver time=60 ; b=check:Poison Vial fail")
	var bad: Array[String] = []
	_expect(bad, "selected", tl.role_dropdown().selected, &"stale:Driver")
	_expect(bad, "shown", tl.role_dropdown().button_text(), "Driver (not on page 1)")
	_expect(bad, "blocked", page.is_complete(), false)
	_expect(bad, "status", page.status_text(), CompletionPage.STALE_ROLE_TEXT % ["a", "Driver"])
	tl.role_dropdown().select(&"Leader", true)
	_expect(bad, "picked", "%s | %s" % [page.completion_text(), page.is_complete()],
		"a=event:Battle role=Leader time=60 ; b=check:Poison Vial fail | true")
	_verdict(res, "tl_role_stale_blocks", bad)


static func _case_tl_unknown_names_pass(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, "a=event:Mystery time=60 ; b=check:Nothing Here fail")
	_same(res, "tl_unknown_names_pass", "%s | %s %s | %s | %s" % [page.is_complete(), tl.name_dropdown(0).selected,
		tl.name_dropdown(0).button_text(), tl.name_dropdown(1).selected, page.status_text()],
		"true | unknown:Mystery Mystery (not in sheet) | unknown:Nothing Here | "
		+ CompletionPage.STEP_EVENT_UNKNOWN_TEXT % ["a", "Mystery"] + "\n"
		+ CompletionPage.STEP_CHECK_UNKNOWN_TEXT % ["b", "Nothing Here"])


#A Checks.tsv row whose name holds ";" is listed disabled with its reason and cannot be picked (D140).
static func _case_tl_name_disabled_rule(res: Dictionary, page: CompletionPage) -> void:
	var path: String = ContractBuilderData.checks_path
	if not path.begins_with(SCRATCH_DIR):
		TestFixtures.check(res, "tl_name_disabled_rule", false, "checks_path %s is not a scratch copy" % path)
		return
	var bad: Array[String] = []
	var result: Dictionary = TsvRowWriter.append_row(path, _tl_row(TL_BAD_NAME))
	_expect(bad, "append", bool(result.get("ok", false)), true)
	var cell: String = "a=check:Poison Vial ; b=event:Battle fail time=60"
	var tl: TimelineEditor = _tl_load(page, cell)
	var opt: Dictionary = {}
	for item: Dictionary in tl.name_dropdown(0).options:
		if StringName(item.get("key", &"")) == _sheet_key(TL_BAD_NAME):
			opt = item
	_expect(bad, "listed", "%s | %s" % [opt.get("enabled", true), opt.get("reason", "")],
		"false | Cannot be a step: holds ;")
	tl.name_dropdown(0).select(_sheet_key(TL_BAD_NAME), true)
	_expect(bad, "refused", "%s | %s" % [tl.name_dropdown(0).selected, page.completion_text() == cell],
		"sheet:Poison Vial | true")
	_verdict(res, "tl_name_disabled_rule", bad)


static func _case_tl_load_valid_verbatim(res: Dictionary, page: CompletionPage) -> void:
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	_tl_load(page, TL_LOOSE)
	page.changed.disconnect(count)
	var out: ContractDraft = ContractDraft.new()
	page.store_draft(out)
	_same(res, "tl_load_valid_verbatim", "%s | %s | %s %d | %s" % [page.completion_text(), out.completion,
		page.is_complete(), hits[0], page.status_text()],
		"%s | %s | true 0 | %s" % [TL_LOOSE, TL_LOOSE, CompletionPage.LAST_STEP_TEXT % "a"])


static func _case_tl_first_edit_canonical(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, TL_LOOSE)
	tl.role_dropdown().select(&"Leader", true)
	_same(res, "tl_first_edit_canonical", page.completion_text(),
		"a=event:Battle role=Leader time=60 ; b=check:Poison Vial fail")


static func _case_tl_load_rule_error_kept(res: Dictionary, page: CompletionPage) -> void:
	var cell: String = "a=event:Battle time=60 ; b=event:Battle if c.success time=60 ; c=check:Poison Vial fail"
	var tl: TimelineEditor = _tl_load(page, cell)
	var out: ContractDraft = ContractDraft.new()
	page.store_draft(out)
	_same(res, "tl_load_rule_error_kept", "%s %s | %s | %s %s | %s" % [out.completion == cell, page.is_complete(),
		tl.when_dropdown(1).selected, tl.when_dropdown(1).button_text(), tl.when_dropdown(1).disabled,
		page.status_text()], "true false | invalid:c.success | c succeeds (invalid) false | "
		+ CompletionPage.TIMELINE_ERROR_TEXT % "Step b: if names c, which is not an earlier step")


static func _case_tl_load_bad_kept(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, TL_BAD)
	var out: ContractDraft = ContractDraft.new()
	page.store_draft(out)
	_same(res, "tl_load_bad_kept", "%s %s | %s %s %s | %s" % [out.completion == TL_BAD, page.is_complete(),
		tl.start_button().visible, tl.add_button().disabled, tl.remove_button().disabled, page.status_text()],
		"true false | true true true | " + CompletionPage.TIMELINE_BAD_TEXT % [TL_BAD,
		TimelineGrammar.syntax_error(TL_BAD)])


static func _case_tl_start_over(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, TL_BAD)
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	tl.start_button().pressed.emit()
	page.changed.disconnect(count)
	_same(res, "tl_start_over", "'%s' %d | %s %s %s | %s" % [page.completion_text(), hits[0], _tl_ids(tl),
		tl.is_fresh(), tl.start_button().visible, page.status_text()],
		"'' 1 | a b true false | " + CompletionPage.TIMELINE_EMPTY_TEXT)


static func _case_tl_next_gate(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, "")
	var marks: Array[String] = [str(page.is_complete())]
	tl.name_dropdown(0).select(&"Battle", true)
	marks.append(str(page.is_complete()))
	tl.kind_button(1, "check").button_pressed = true
	marks.append(str(page.is_complete()))
	tl.name_dropdown(1).select(_sheet_key(POISON_VIAL), true)
	marks.append(str(page.is_complete()))
	_same(res, "tl_next_gate", "%s | %s" % [" ".join(marks), page.completion_text()],
		"false false false true | a=event:Battle time=60 ; b=check:Poison Vial fail")


static func _case_tl_status_lines_joined(res: Dictionary, page: CompletionPage) -> void:
	_tl_load(page, "a=event:Chase time=60 ; b=event:Mystery role=Driver time=1441 ; c=check:Nothing fail")
	var want: Array[String] = [CompletionPage.STEP_PLANNED_TEXT % ["a", "Chase"],
		CompletionPage.STEP_EVENT_UNKNOWN_TEXT % ["b", "Mystery"], CompletionPage.STALE_ROLE_TEXT % ["b", "Driver"],
		CompletionPage.STEP_TIME_TEXT % ["b", 1441], CompletionPage.STEP_CHECK_UNKNOWN_TEXT % ["c", "Nothing"]]
	var joined: String = page.status_text()
	_tl_load(page, TL_VALID)
	_same(res, "tl_status_lines_joined", "%s | %s" % [joined == "\n".join(want), page.status_text()],
		"true | " + CompletionPage.LAST_STEP_TEXT % "b")


static func _case_tl_one_notify_per_action(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, "")
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	var marks: Array[int] = []
	tl.name_dropdown(0).select(&"Battle", true)
	marks.append(hits[0])
	tl.add_button().pressed.emit()
	marks.append(hits[0])
	tl.select_step(0)
	tl.branch_button().pressed.emit()
	marks.append(hits[0])
	tl.remove_button().pressed.emit()
	marks.append(hits[0])
	tl.up_button().pressed.emit()
	marks.append(hits[0])
	tl.kind_button(0, "check").button_pressed = true
	marks.append(hits[0])
	tl.role_dropdown().select(&"Leader", true)
	marks.append(hits[0])
	tl.select_step(1)
	tl.duration().stepper._move(1)
	marks.append(hits[0])
	tl.steppers().stepper("hp")._move(-1)
	marks.append(hits[0])
	tl.fail_box(2).button_pressed = false
	marks.append(hits[0])
	page.changed.disconnect(count)
	_same(res, "tl_one_notify_per_action", "%s | %s" % [_steps(marks), page.completion_text()],
		"1 1 1 1 1 1 1 1 1 0 | a=check: fail role=Leader ; b=event:Battle time=120 cons=hp -1 ; c=event: fail")


static func _case_tl_load_silent(res: Dictionary, page: CompletionPage) -> void:
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	for cell: String in ["", TL_VALID, TL_WAIT, TL_BAD, "a=event:Battle ; b=event:Battle if c.success fail"]:
		_tl_load(page, cell)
	page.changed.disconnect(count)
	_same(res, "tl_load_silent", hits[0], 0)


static func _case_tl_clear_to_check(res: Dictionary, page: CompletionPage) -> void:
	var draft: ContractDraft = _tl_draft(TL_VALID, [], [_tl_row("Interrogate")])
	draft.style = "check"
	page.load_draft(draft)
	var out: ContractDraft = _tl_draft("stale", [], [_tl_row("Stale")])
	page.store_draft(out)
	_same(res, "tl_clear_to_check", "'%s' %d %d | %s" % [out.completion, page.timeline_checks().size(),
		out.timeline_checks.size(), page.status_text()], "'' 0 0 | " + CompletionPage.TIMELINE_CLEARED_TEXT % "check")


static func _case_tl_clear_to_event(res: Dictionary, page: CompletionPage) -> void:
	page.load_draft(_event_draft("event", TL_VALID, "", 0, ""))
	_same(res, "tl_clear_to_event", "%s | %s" % [_stored_event(page),
		page.status_text().begins_with(CompletionPage.TIMELINE_CLEARED_TEXT % "event")], " |  | 0 |  | true")


static func _case_tl_clear_to_blank(res: Dictionary, page: CompletionPage) -> void:
	page.load_draft(_completion_draft("", TL_VALID, []))
	_same(res, "tl_clear_to_blank", "'%s' | %s" % [page.completion_text(), page.status_text()],
		"'' | %s\n%s" % [CompletionPage.TIMELINE_CLEARED_TEXT % "blank", CompletionPage.NO_STYLE_TEXT])


static func _case_tl_clear_keeps_plain_text(res: Dictionary, page: CompletionPage) -> void:
	page.load_draft(_event_draft("event", "Event:Battle", "", 60, ""))
	_same(res, "tl_clear_keeps_plain_text", "%s | %s" % [page.completion_text(),
		page.status_text().contains("Timeline cleared")], "Event:Battle | false")


static func _case_tl_clear_row_time(res: Dictionary, page: CompletionPage) -> void:
	page.load_draft(_event_draft("timeline", "", "", 90, "hp -1"))
	_same(res, "tl_clear_row_time", "%s | %s" % [_stored_event(page), page.status_text()],
		" |  | 0 |  | " + CompletionPage.ROW_CLEARED_TEXT)


static func _case_tl_clear_row_time_after_check(res: Dictionary, page: CompletionPage) -> void:
	page.load_draft(_event_draft("timeline", "check:" + POISON_VIAL, "", 120, "hp -1"))
	_same(res, "tl_clear_row_time_after_check", "%s | %s" % [_stored_event(page), page.status_text()],
		" |  | 0 |  | " + CompletionPage.CLEARED_TEXT % "timeline")


static func _case_tl_unused_pending_dropped(res: Dictionary, page: CompletionPage) -> void:
	page.load_draft(_tl_draft("a=event:Battle time=60 ; b=check:Interrogate fail", [],
		[_tl_row("Interrogate"), _tl_row("Unused")]))
	var tl: TimelineEditor = page.timeline()
	var out: ContractDraft = ContractDraft.new()
	page.store_draft(out)
	_same(res, "tl_unused_pending_dropped", "%s %s | %s | %s" % [tl.name_dropdown(1).selected,
		tl.name_dropdown(1).button_text(), _tl_row_names(out.timeline_checks), page.status_text()],
		"new:Interrogate Interrogate (new) | Interrogate | " + CompletionPage.LAST_STEP_TEXT % "b")


static func _case_tl_pending_kept_while_unreadable(res: Dictionary, page: CompletionPage) -> void:
	page.load_draft(_tl_draft(TL_BAD, [], [_tl_row("Interrogate"), _tl_row("Unused")]))
	var out: ContractDraft = ContractDraft.new()
	page.store_draft(out)
	_same(res, "tl_pending_kept_while_unreadable", "%s | %s" % [out.completion == TL_BAD,
		_tl_row_names(out.timeline_checks)], "true | Interrogate, Unused")


static func _case_tl_id_type_ok(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, TL_VALID)
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	_submit(tl.id_edit(), "fight")
	page.changed.disconnect(count)
	_same(res, "tl_id_type_ok", "%s | %s %s %d" % [page.completion_text(), tl.id_label(0).text, tl.id_edit().text,
		hits[0]], "fight=event:Battle time=60 ; a=check:Poison Vial fail | fight fight 1")


static func _case_tl_id_unsubmitted_commits_on_select(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, TL_VALID)
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	tl.id_edit().text = "fight"
	tl.select_step(1)
	page.changed.disconnect(count)
	_same(res, "tl_id_unsubmitted_commits_on_select", "%s | %d %d" % [page.completion_text(), tl.selected_index(),
		hits[0]], "fight=event:Battle time=60 ; a=check:Poison Vial fail | 1 1")


static func _case_tl_id_refused_keeps_old(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, TL_VALID)
	var bad: Array[String] = []
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	_submit(tl.id_edit(), "if")
	_expect(bad, "reserved", page.status_text(), CompletionPage.ID_REFUSED_TEXT % ["if", "if is a reserved word", "a"])
	_expect(bad, "field", tl.id_edit().text, "a")
	_submit(tl.id_edit(), "c")
	_expect(bad, "auto", page.status_text(), CompletionPage.ID_REFUSED_TEXT % ["c",
		TimelineGrammar.ID_AUTO_TEXT % "c", "a"])
	_submit(tl.id_edit(), "x y")
	_expect(bad, "form", page.status_text(), CompletionPage.ID_REFUSED_TEXT % ["x y", TimelineGrammar.ID_FORM_TEXT,
		"a"])
	page.changed.disconnect(count)
	_expect(bad, "cell", page.completion_text(), TL_VALID)
	_expect(bad, "silent", hits[0], 0)
	_verdict(res, "tl_id_refused_keeps_old", bad)


static func _case_tl_id_clear_returns_auto(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, "fight=event:Battle time=60 ; a=check:Poison Vial fail")
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	_submit(tl.id_edit(), "")
	page.changed.disconnect(count)
	_same(res, "tl_id_clear_returns_auto", "%s | %s %d" % [page.completion_text(), tl.id_edit().text, hits[0]],
		TL_VALID + " | a 1")


static func _case_tl_id_rename_updates_when(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, TL_WAIT)
	_submit(tl.id_edit(), "fight")
	_same(res, "tl_id_rename_updates_when", "%s | %s %s | %s" % [page.completion_text(), tl.when_dropdown(1).selected,
		tl.when_dropdown(1).button_text(), _option_labels(tl.when_dropdown(2)).has("fight succeeds")],
		"fight=event:Battle time=60 ; a=event:Battle if fight.failure time=60 ; b=check:Poison Vial fail"
		+ " | if:fight.failure fight fails | true")


static func _case_tl_id_typed_survives_renumber(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, TL_VALID)
	var bad: Array[String] = []
	_submit(tl.id_edit(), "fight")
	tl.add_button().pressed.emit()
	_expect(bad, "add", page.completion_text(), "fight=event:Battle time=60 ; a=check:Poison Vial fail ; b=event: fail")
	tl.up_button().pressed.emit()
	_expect(bad, "move", page.completion_text(), "fight=event:Battle time=60 ; a=event: fail ; b=check:Poison Vial fail")
	tl.remove_button().pressed.emit()
	_expect(bad, "remove", page.completion_text(), "fight=event:Battle time=60 ; a=check:Poison Vial fail")
	_verdict(res, "tl_id_typed_survives_renumber", bad)


static func _case_tl_id_load_typed_kept(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, "fight=event:Battle time=60 ; z=check:Poison Vial fail")
	var typed: String = "%s %s" % [(tl.steps()[0] as TimelineGrammar.Step).typed,
		(tl.steps()[1] as TimelineGrammar.Step).typed]
	tl.add_button().pressed.emit()
	_same(res, "tl_id_load_typed_kept", "%s | %s" % [typed, page.completion_text()],
		"true false | fight=event:Battle time=60 ; a=check:Poison Vial fail ; b=event: fail")


static func _case_tl_id_commit_one_notify(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, TL_VALID)
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	_submit(tl.id_edit(), "fight")
	tl.id_edit().focus_exited.emit()
	page.changed.disconnect(count)
	_same(res, "tl_id_commit_one_notify", "%d | %s" % [hits[0], page.completion_text()],
		"1 | fight=event:Battle time=60 ; a=check:Poison Vial fail")


static func _case_tl_build_check_step(res: Dictionary, page: CompletionPage) -> void:
	var bad: Array[String] = []
	var tl: TimelineEditor = _tl_load(page, TL_VALID)
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	var builder: CheckBuilder = _tl_build(page, 1)
	_expect(bad, "open", builder.visible, true)
	_expect(bad, "blank form", builder.name_edit.text, "")
	_fill_trial(builder)
	builder.press_confirm()
	page.changed.disconnect(count)
	_expect(bad, "closed", builder.visible, false)
	_expect(bad, "cell", page.completion_text(), "a=event:Battle time=60 ; b=check:%s fail" % BUILT_NAME)
	_expect(bad, "rows", _tl_row_names(page.timeline_checks()), BUILT_NAME)
	_expect(bad, "name option", tl.name_dropdown(1).button_text(), BUILT_NAME + " (new)")
	_expect(bad, "button", tl.build_button().text, CompletionPage.EDIT_TEXT)
	_expect(bad, "status", page.status_text(), CompletionPage.LAST_STEP_TEXT % "b")
	_expect(bad, "complete", page.is_complete(), true)
	_expect(bad, "emissions", hits[0], 1)
	_close_builder(builder)
	_verdict(res, "tl_build_check_step", bad)


static func _case_tl_build_keeps_cell(res: Dictionary, page: CompletionPage) -> void:
	_tl_load(page, TL_VALID)
	var builder: CheckBuilder = _tl_build(page, 1)
	_fill_trial(builder)
	builder.press_confirm()
	var out: ContractDraft = _completion_draft("timeline", "", [])
	page.store_draft(out)
	_close_builder(builder)
	_same(res, "tl_build_keeps_cell", "%s | %d | %s | %s | %s | %s" % [out.completion, out.check_row.size(),
		_tl_row_names(out.timeline_checks), ContractRowWriter.pending_check(out),
		_tl_row_names(ContractRowWriter.pending_timeline_checks(out)), page.timeline_panel.visible],
		"a=event:Battle time=60 ; b=check:%s fail | 0 | %s | false | %s | true" % [BUILT_NAME, BUILT_NAME, BUILT_NAME])


static func _case_tl_build_two_checks(res: Dictionary, page: CompletionPage) -> void:
	_tl_load(page, "a=check:Poison Vial ; b=check:Poison Vial fail")
	var builder: CheckBuilder = _tl_build(page, 0)
	_fill_trial(builder)
	builder.press_confirm()
	builder = _tl_build(page, 1)
	var blank: String = builder.name_edit.text
	_fill_trial(builder)
	_type_into(builder.name_edit, "Trial of Nerve")
	builder.press_confirm()
	var out: ContractDraft = _completion_draft("timeline", "", [])
	page.store_draft(out)
	_close_builder(builder)
	_same(res, "tl_build_two_checks", "[%s] | %s | %s" % [blank, out.completion, _tl_row_names(out.timeline_checks)],
		"[] | a=check:%s ; b=check:Trial of Nerve fail | %s, Trial of Nerve" % [BUILT_NAME, BUILT_NAME])


static func _case_tl_build_shared_check(res: Dictionary, page: CompletionPage) -> void:
	var tl: TimelineEditor = _tl_load(page, "a=check:Poison Vial ; b=check:Poison Vial fail")
	var builder: CheckBuilder = _tl_build(page, 0)
	_fill_trial(builder)
	builder.press_confirm()
	tl.name_dropdown(1).select(StringName(CompletionPage.NEW_PREFIX + BUILT_NAME), true)
	var out: ContractDraft = _completion_draft("timeline", "", [])
	page.store_draft(out)
	_close_builder(builder)
	_same(res, "tl_build_shared_check", "%s | %s | %s" % [out.completion, _tl_row_names(out.timeline_checks),
		tl.name_dropdown(1).button_text()],
		"a=check:%s ; b=check:%s fail | %s | %s (new)" % [BUILT_NAME, BUILT_NAME, BUILT_NAME, BUILT_NAME])


static func _case_tl_edit_check_renames_all_steps(res: Dictionary, page: CompletionPage) -> void:
	var bad: Array[String] = []
	var tl: TimelineEditor = _tl_load(page, "a=check:Poison Vial ; b=event:Battle time=60 ; c=check:Poison Vial fail")
	var builder: CheckBuilder = _tl_build(page, 0)
	_fill_trial(builder)
	builder.press_confirm()
	tl.name_dropdown(2).select(StringName(CompletionPage.NEW_PREFIX + BUILT_NAME), true)
	builder = _tl_build(page, 2)
	_expect(bad, "loaded name", builder.name_edit.text, BUILT_NAME)
	_expect(bad, "editing", builder.editing_name(), BUILT_NAME)
	_type_into(builder.name_edit, "Trial of Grit")
	builder.press_confirm()
	_expect(bad, "closed", builder.visible, false)
	_expect(bad, "cell", page.completion_text(),
		"a=check:Trial of Grit ; b=event:Battle time=60 ; c=check:Trial of Grit fail")
	_expect(bad, "rows", _tl_row_names(page.timeline_checks()), "Trial of Grit")
	var rows: Array = page.timeline_checks()
	var row: Array = rows[0] if rows.size() == 1 else []
	_expect(bad, "row cells", row.size() == CheckSheet.WIDTH and row[CheckSheet.ATTRIBUTES] == "Cognition", true)
	_expect(bad, "selected", tl.selected_index(), 2)
	_close_builder(builder)
	_verdict(res, "tl_edit_check_renames_all_steps", bad)


#D159: the CB:183 text for a Checks.tsv clash and for a clash with another pending timeline check.
static func _case_tl_build_dup_refused(res: Dictionary, page: CompletionPage) -> void:
	var bad: Array[String] = []
	_tl_load(page, "a=check:Poison Vial ; b=check:Poison Vial fail")
	var builder: CheckBuilder = _tl_build(page, 0)
	_fill_trial(builder)
	_type_into(builder.name_edit, POISON_VIAL)
	builder.press_confirm()
	_expect(bad, "sheet open", builder.visible, true)
	_expect(bad, "sheet status", builder.status_text(), "Check Poison Vial already exists in Checks.tsv")
	_type_into(builder.name_edit, BUILT_NAME)
	builder.press_confirm()
	builder = _tl_build(page, 1)
	_fill_trial(builder)
	_type_into(builder.name_edit, "trial of wit")
	builder.press_confirm()
	_expect(bad, "pending open", builder.visible, true)
	_expect(bad, "pending status", builder.status_text(), "Check trial of wit already exists in Checks.tsv")
	builder.press_cancel()
	_expect(bad, "cell", page.completion_text(), "a=check:%s ; b=check:Poison Vial fail" % BUILT_NAME)
	_expect(bad, "rows", _tl_row_names(page.timeline_checks()), BUILT_NAME)
	_close_builder(builder)
	_verdict(res, "tl_build_dup_refused", bad)


static func _case_tl_build_name_rule_refused(res: Dictionary, page: CompletionPage) -> void:
	_tl_load(page, TL_VALID)
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	page.changed.connect(count)
	var builder: CheckBuilder = _tl_build(page, 1)
	_fill_trial(builder)
	_type_into(builder.name_edit, TL_STEP_BAD)
	builder.press_confirm()
	var shown: String = "%s | %s" % [builder.visible, builder.status_text()]
	builder.press_cancel()
	page.changed.disconnect(count)
	_close_builder(builder)
	_same(res, "tl_build_name_rule_refused", "%s | %s | %d | %d" % [shown, page.completion_text(),
		page.timeline_checks().size(), hits[0]],
		"true | Check Name %s cannot be a step: holds ; | %s | 0 | 0" % [TL_STEP_BAD, TL_VALID])


static func _case_tl_check_style_builder_unaffected(res: Dictionary, page: CompletionPage) -> void:
	_tl_load(page, TL_VALID)
	var builder: CheckBuilder = _tl_build(page, 1)
	var opened: bool = builder.visible
	builder.press_cancel()
	var kept: String = page.completion_text()
	page.load_draft(_completion_draft("check", "", []))
	page.press_build()
	_fill_trial(builder)
	_type_into(builder.name_edit, TL_STEP_BAD)
	builder.press_confirm()
	var pending: Array[String] = page.pending()
	var shown: String = "%s %s %s | %s | %s | %s" % [opened, kept == TL_VALID, builder.visible, builder.status_text(),
		page.completion_text(), pending[CheckSheet.NAME] if pending.size() == CheckSheet.WIDTH else ""]
	_close_builder(builder)
	_same(res, "tl_check_style_builder_unaffected", shown,
		"true true false |  | check:%s | %s" % [TL_STEP_BAD, TL_STEP_BAD])


#5.4: per pending timeline row a step names, the NEW_CHECK line and the summary lines indented by two spaces.
static func _case_review_timeline_new_checks(res: Dictionary) -> void:
	var draft: ContractDraft = _tl_draft("a=check:Interrogate ; b=event:Battle time=60 ; c=check:Deliver fail", [],
		[_tl_row("Deliver"), _tl_row("Unused"), _tl_row("Interrogate")])
	var review: String = ReviewPage.review_text(draft)
	var want: Array[String] = []
	for check_name: String in ["Interrogate", "Deliver"]:
		want.append(ReviewPage.NEW_CHECK % check_name)
		for line: String in CheckSheet.summary(_tl_row(check_name)).split("\n", false):
			want.append("  " + line)
	_same(res, "review_timeline_new_checks", "%s %s %s" % [review.contains("\n".join(want)), review.contains("Unused"),
		want.size() > 2], "true false true")


#Selects the step and presses its Build new or Edit new; the page opens its one CheckBuilder (D162).
static func _tl_build(page: CompletionPage, index: int) -> CheckBuilder:
	page.timeline().select_step(index)
	page.timeline().build_button().pressed.emit()
	return page.builder()


static func _tl_load(page: CompletionPage, cell: String) -> TimelineEditor:
	page.load_draft(_completion_draft("timeline", cell, []))
	return page.timeline()


static func _tl_draft(cell: String, roles: Array[String], rows: Array) -> ContractDraft:
	var draft: ContractDraft = _completion_draft("timeline", cell, [])
	draft.roles.assign(roles)
	draft.timeline_checks = rows.duplicate(true)
	return draft


static func _tl_row(check_name: String) -> Array[String]:
	var cells: Array[String] = []
	cells.assign(POISON_ROW)
	cells[CheckSheet.NAME] = check_name
	return cells


#Steps a, b, ... each event:Battle time=60; the last carries fail.
static func _tl_chain(count: int) -> String:
	var parts: Array[String] = []
	for i: int in range(count):
		parts.append("%s=event:Battle%s time=60" % [char(97 + i), " fail" if i == count - 1 else ""])
	return " ; ".join(parts)


static func _tl_ids(tl: TimelineEditor) -> String:
	var out: Array[String] = []
	for step: TimelineGrammar.Step in tl.steps():
		out.append(step.id)
	return " ".join(out)


static func _tl_row_names(rows: Array) -> String:
	var out: Array[String] = []
	for row: Variant in rows:
		out.append(String((row as Array)[CheckSheet.NAME]))
	return ", ".join(out)


static func _completion_draft(style: String, completion: String, row: Array[String]) -> ContractDraft:
	var draft: ContractDraft = ContractDraft.new()
	draft.style = style
	draft.completion = completion
	draft.check_row.assign(row)
	return draft


static func _event_draft(style: String, completion: String, config: String, minutes: int,
		consequence: String) -> ContractDraft:
	var draft: ContractDraft = _completion_draft(style, completion, [])
	draft.event_config = config
	draft.time = minutes
	draft.consequence = consequence
	return draft


#Completion, Event Config, Time and Consequence as the page holds them.
static func _cells(page: CompletionPage) -> String:
	return "%s | %s | %d | %s" % [page.completion_text(), page.config_text(), page.time_minutes(),
		page.consequence_text()]


#The same four cells as store_draft writes them into a draft that held other values.
static func _stored_event(page: CompletionPage) -> String:
	var out: ContractDraft = _event_draft("event", "stale", "stale", -5, "stale")
	page.store_draft(out)
	return "%s | %s | %d | %s" % [out.completion, out.event_config, out.time, out.consequence]


#The pressed option of every choice row, "key=option" in the event's key order.
static func _pressed(panel: EventConfigPanel) -> String:
	var out: Array[String] = []
	for field: Dictionary in EventConfig.fields(panel.event_name()):
		for option: String in field["options"]:
			var radio: ToolBevelButton = panel.button(String(field["key"]), option)
			if radio != null and radio.button_pressed:
				out.append("%s=%s" % [String(field["key"]), option])
	return ", ".join(out)


#A click as the engine sends it: toggled(true) again on the pressed radio, else the group swap; then pressed.
static func _click(radio: BaseButton) -> void:
	if radio.button_pressed:
		radio.toggled.emit(true)
	else:
		radio.button_pressed = true
	radio.pressed.emit()


static func _planned_text(event: String) -> String:
	return "Event %s is planned for stage 6; its Events.tsv row does not exist yet" % event


static func _same(res: Dictionary, label: String, got: Variant, want: Variant) -> void:
	var passed: bool = typeof(got) == typeof(want) and got == want
	TestFixtures.check(res, label, passed, "'%s'" % str(got) if passed else "'%s' not '%s'" % [str(got), str(want)])


#The 4.6 fill through the widgets the user moves.
static func _fill_trial(builder: CheckBuilder) -> void:
	_type_into(builder.name_edit, BUILT_NAME)
	var cognition: ToolFilterCheckRow = builder.attribute_row("Cognition")
	if cognition != null:
		cognition.button_pressed = true
	var clever: ToolFilterCheckRow = builder.circumstance_list.check_for(CLEVER)
	if clever != null:
		clever.button_pressed = true
		builder.circumstance_list.slider_for(CLEVER)._apply(10.0)
	var mage: ToolPixelSlider = builder.tradition_slider("Mage")
	if mage != null:
		mage._apply(15.0)
	builder.multiplier_slider._apply(1.5)
	builder.duration.stepper._move(1)
	builder.opposed_yes.button_pressed = true
	builder.consequences.stepper("hp")._move(-2)


static func _close_builder(builder: CheckBuilder) -> void:
	if builder != null and builder.visible:
		builder.press_cancel()


static func _sheet_key(check_name: String) -> StringName:
	return StringName(CompletionPage.SHEET_PREFIX + check_name)


static func _option_labels(dropdown: OptionDropdown) -> Array[String]:
	var out: Array[String] = []
	for opt: Dictionary in dropdown.options:
		out.append(String(opt.get("label", "")))
	return out


static func _duration_text(duration: ToolDuration) -> String:
	return "%d %s" % [duration.value(), duration.unit()]


static func _pick_text(picks: Array[Dictionary]) -> String:
	var out: Array[String] = []
	for entry: Dictionary in picks:
		out.append("%s %d" % [String(entry.get("name", "")), int(entry.get("percent", 0))])
	return ", ".join(out)


static func _case_tradition_balance(res: Dictionary) -> void:
	var bad: Array[String] = []
	var example: Array[int] = [15, 0, 5, 15, 0, 15, 0, 0, 0, 15]
	var example_want: Array[int] = [10, 0, 5, 15, 0, 10, 0, 0, 0, 10]
	_expect(bad, "D59 example", TraditionBalance.rebalance(example, 3), example_want)
	var start: Array[int] = [-15, -15, -15, 0, 0, 0, 0, 0, 0, -15]
	var want: Array[int] = [-10, -10, -15, 0, 0, 0, 0, 0, 0, -15]
	_expect(bad, "negative side", TraditionBalance.rebalance(start, 9), want)
	var kept: Array[int] = [-15, -15, -15, 0, 0, 0, 0, 0, 0, -15]
	_expect(bad, "input kept", start, kept)
	var at_cap: Array[int] = [20, 15, 15, 0, 0, 0, 0, 0, 0, 0]
	_expect(bad, "a side at 50", TraditionBalance.rebalance(at_cap, 0), at_cap)
	var mixed: Array[int] = [30, 25, -40, -20, 0, 0, 0, 0, 0, 0]
	var mixed_want: Array[int] = [30, 20, -40, -20, 0, 0, 0, 0, 0, 0]
	_expect(bad, "opposite side untouched", TraditionBalance.rebalance(mixed, 0), mixed_want)
	_expect(bad, "moved value 0", TraditionBalance.rebalance(start, 3), kept)
	_verdict(res, "tradition_balance", bad)


static func _case_duration_control(res: Dictionary, host: Control) -> void:
	var bad: Array[String] = []
	var duration: ToolDuration = ToolDuration.new()
	host.add_child(duration)
	_expect(bad, "default minutes", duration.minutes(), 60)
	_expect(bad, "default unit", duration.unit(), &"hours")
	_expect(bad, "default value", duration.value(), 1)
	duration.set_minutes(90)
	_expect(bad, "90", _duration_text(duration), "90 minutes")
	duration.set_minutes(2880)
	_expect(bad, "2880", _duration_text(duration), "2 days")
	duration.set_minutes(0)
	_expect(bad, "0", duration.minutes(), 60)
	duration.set_minutes(60000)
	_expect(bad, "60000", _duration_text(duration), "999 minutes")
	duration.set_minutes(60)
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	duration.changed.connect(count)
	duration.set_minutes(120)
	_expect(bad, "set_minutes silent", hits[0], 0)
	duration.stepper._move(1)
	duration.dropdown.select(&"days", true)
	_expect(bad, "3 days", "%s = %d" % [_duration_text(duration), duration.minutes()], "3 days = 4320")
	duration.dropdown.select(&"days", true)
	duration.changed.disconnect(count)
	_expect(bad, "emissions", hits[0], 2)
	duration.queue_free()
	_verdict(res, "duration_control", bad)


static func _case_consequence_steppers(res: Dictionary, host: Control) -> void:
	var bad: Array[String] = []
	var steppers: ConsequenceSteppers = ConsequenceSteppers.new()
	host.add_child(steppers)
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	steppers.changed.connect(count)
	steppers.set_values({"hp": -2, "guild": -1})
	var got: Dictionary = steppers.values()
	_expect(bad, "kinds", ",".join(PackedStringArray(got.keys())), "retry,hp,ep,mp,guild")
	_expect(bad, "hp", int(got.get("hp", 0)), -2)
	_expect(bad, "guild", int(got.get("guild", 0)), -1)
	_expect(bad, "cell", CheckSheet.format_consequence(got), "hp -2, guild -1")
	_expect(bad, "set_values silent", hits[0], 0)
	var rejects: Array[int] = [0]
	var reject_count: Callable = func(_side: int) -> void: rejects[0] += 1
	var hp: ToolQuantityStepper = steppers.stepper("hp")
	hp.rejected.connect(reject_count)
	hp._move(-20)
	_expect(bad, "floor", hp.value, CheckSheet.CONSEQUENCE_MIN)
	hp._move(-1)
	_expect(bad, "still the floor", hp.value, CheckSheet.CONSEQUENCE_MIN)
	hp.rejected.disconnect(reject_count)
	steppers.changed.disconnect(count)
	_expect(bad, "rejected", rejects[0], 2)
	_expect(bad, "changed", hits[0], 1)
	steppers.queue_free()
	_verdict(res, "consequence_steppers", bad)


static func _case_percent_pick_list(res: Dictionary, host: Control) -> void:
	var bad: Array[String] = []
	var list: PercentPickList = PercentPickList.new()
	host.add_child(list)
	list.set_entries(PICK_ENTRIES)
	_expect(bad, "all shown", ",".join(list.visible_keys()), ",".join(_entry_keys()))
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	list.changed.connect(count)
	var picks: Array[Dictionary] = [{"name": "Attack (Dexterity)", "percent": 10}, {"name": CLEVER, "percent": 5}]
	list.set_picked(picks)
	_expect(bad, "set_picked silent", hits[0], 0)
	_expect(bad, "picked in entry order", _pick_text(list.picked()), "Clever (Cognition) 5, Attack (Dexterity) 10")
	var groups: Array[String] = ["Cognition"]
	list.set_groups_visible(groups)
	_expect(bad, "groups", ",".join(list.visible_keys()), "Clever (Cognition),Notice (Cognition)")
	_expect(bad, "Attack off", list.check_for("Attack (Dexterity)").button_pressed, false)
	_expect(bad, "group drop emits once", hits[0], 1)
	list.set_filter("cle")
	_expect(bad, "filter", ",".join(list.visible_keys()), CLEVER)
	list.set_filter("")
	list.check_for("Notice (Cognition)").button_pressed = true
	list.slider_for("Notice (Cognition)")._apply(15.0)
	_expect(bad, "picked", _pick_text(list.picked()), "Clever (Cognition) 5, Notice (Cognition) 15")
	_expect(bad, "user moves emit", hits[0], 3)
	list.changed.disconnect(count)
	list.queue_free()
	_verdict(res, "percent_pick_list", bad)


static func _entry_keys() -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in PICK_ENTRIES:
		out.append(String(entry.get("key", "")))
	return out


static func _sort_list(host: Control) -> PercentPickList:
	var list: PercentPickList = PercentPickList.new()
	host.add_child(list)
	list.set_entries(SORT_ENTRIES)
	return list


static func _keys_text(keys: Array[String]) -> String:
	return ",".join(keys)


#D86: a check starts at 5, a checked row snaps up to 5 and emits only when its value moved; a load keeps 0.
static func _case_pick_check_floor(res: Dictionary, host: Control) -> void:
	var list: PercentPickList = _sort_list(host)
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	list.changed.connect(count)
	var rope: ToolFilterCheckRow = list.check_for("Rope")
	var slider: ToolPixelSlider = list.slider_for("Rope")
	var bad: Array[String] = []
	rope.button_pressed = true
	_expect(bad, "slider", roundi(slider.value), 5)
	_expect(bad, "picked", _pick_text(list.picked()), "Rope 5")
	_expect(bad, "emits", hits[0], 1)
	_verdict(res, "pick_check_floor_check", bad)
	bad = []
	slider._apply(0.0)
	_expect(bad, "drag to 0", "%d %d" % [roundi(slider.value), hits[0]], "5 1")
	slider._apply(10.0)
	_expect(bad, "drag to 10", "%d %d" % [roundi(slider.value), hits[0]], "10 2")
	slider._apply(0.0)
	_expect(bad, "drag 10 to 0", "%d %d" % [roundi(slider.value), hits[0]], "5 3")
	_verdict(res, "pick_check_floor_drag", bad)
	bad = []
	rope.button_pressed = false
	_expect(bad, "uncheck", "%d %s %d" % [roundi(slider.value), slider.disabled, hits[0]], "0 true 4")
	_verdict(res, "pick_check_floor_uncheck", bad)
	bad = []
	var loaded: Array[Dictionary] = [{"name": "Rope", "percent": 0}]
	list.set_picked(loaded)
	_expect(bad, "on at 0", "%s %d" % [rope.button_pressed, roundi(slider.value)], "true 0")
	_expect(bad, "silent", hits[0], 4)
	_expect(bad, "picked", _pick_text(list.picked()), "Rope 0")
	_verdict(res, "pick_check_floor_load", bad)
	list.changed.disconnect(count)
	list.queue_free()


static func _case_pick_sort_name(res: Dictionary, host: Control) -> void:
	var list: PercentPickList = _sort_list(host)
	var bad: Array[String] = []
	_expect(bad, "mode", list.sort_mode(), PercentPickList.SORT_NAME)
	_expect(bad, "display", _keys_text(list.display_keys()), "Atlas,Charm,Codex,Lockpick,Rope,Zither")
	_expect(bad, "entry order", _keys_text(list.visible_keys()), "Rope,Atlas,Lockpick,Codex,Charm,Zither")
	var first_row: Node = list.list.get_child(0)
	_expect(bad, "first row node", first_row == list.check_for("Atlas").get_parent(), true)
	_verdict(res, "pick_sort_name", bad)
	list.queue_free()


static func _case_pick_sort_category(res: Dictionary, host: Control) -> void:
	var list: PercentPickList = _sort_list(host)
	var bad: Array[String] = []
	list.set_sort(PercentPickList.SORT_CATEGORY)
	_expect(bad, "display", _keys_text(list.display_keys()), "Atlas,Codex,Lockpick,Rope,Zither,Charm")
	_verdict(res, "pick_sort_category", bad)
	list.queue_free()


static func _case_pick_sort_rarity(res: Dictionary, host: Control) -> void:
	var list: PercentPickList = _sort_list(host)
	var bad: Array[String] = []
	list.set_sort(PercentPickList.SORT_RARITY)
	_expect(bad, "display", _keys_text(list.display_keys()), "Rope,Lockpick,Atlas,Charm,Codex,Zither")
	_verdict(res, "pick_sort_rarity", bad)
	list.queue_free()


static func _case_pick_sort_picked(res: Dictionary, host: Control) -> void:
	var list: PercentPickList = _sort_list(host)
	var bad: Array[String] = []
	var picks: Array[Dictionary] = [{"name": "Rope", "percent": 5}, {"name": "Codex", "percent": 10}]
	list.set_picked(picks)
	list.set_sort(PercentPickList.SORT_PICKED)
	_expect(bad, "display", _keys_text(list.display_keys()), "Codex,Rope,Atlas,Charm,Lockpick,Zither")
	_expect(bad, "picked", _pick_text(list.picked()), "Rope 5, Codex 10")
	_verdict(res, "pick_sort_picked", bad)
	list.queue_free()


static func _case_pick_sort_unknown(res: Dictionary, host: Control) -> void:
	var list: PercentPickList = _sort_list(host)
	var bad: Array[String] = []
	list.set_sort(PercentPickList.SORT_RARITY)
	list.set_sort(&"nope")
	_expect(bad, "mode", list.sort_mode(), PercentPickList.SORT_NAME)
	_expect(bad, "shown", list.sort_dropdown.button_text(), "Sort: Name")
	_verdict(res, "pick_sort_unknown", bad)
	list.queue_free()


#A user toggle never moves a row; the row arrays stay bound by entry index.
static func _case_pick_sort_keeps_binding(res: Dictionary, host: Control) -> void:
	var list: PercentPickList = _sort_list(host)
	var bad: Array[String] = []
	list.set_sort(PercentPickList.SORT_RARITY)
	list.check_for("Atlas").button_pressed = true
	_expect(bad, "picked", _pick_text(list.picked()), "Atlas 5")
	_expect(bad, "unchanged", _keys_text(list.display_keys()), "Rope,Lockpick,Atlas,Charm,Codex,Zither")
	list.set_sort(PercentPickList.SORT_PICKED)
	_expect(bad, "picked sort", _keys_text(list.display_keys()), "Atlas,Charm,Codex,Lockpick,Rope,Zither")
	_expect(bad, "slider bound", roundi(list.slider_for("Atlas").value), 5)
	_verdict(res, "pick_sort_keeps_binding", bad)
	list.queue_free()


static func _case_pick_hide(res: Dictionary, host: Control) -> void:
	var list: PercentPickList = _sort_list(host)
	var bad: Array[String] = []
	var gear: Array[String] = ["Gear"]
	var legendary: Array[String] = ["Legendary"]
	var none: Array[String] = []
	list.set_hidden(gear, legendary)
	_expect(bad, "display", _keys_text(list.display_keys()), "Atlas,Charm,Zither")
	_expect(bad, "categories", _keys_text(list.hidden_categories()), "Gear")
	_expect(bad, "rarities", _keys_text(list.hidden_rarities()), "Legendary")
	_expect(bad, "menu filtering", list.hide_menu.is_filtering(), true)
	_verdict(res, "pick_hide", bad)
	bad = []
	var rope: Array[Dictionary] = [{"name": "Rope", "percent": 5}]
	list.set_picked(rope)
	_expect(bad, "checked shows", _keys_text(list.display_keys()), "Atlas,Charm,Rope,Zither")
	list.set_filter("ch")
	_expect(bad, "text filter", _keys_text(list.display_keys()), "Charm")
	list.set_filter("")
	_verdict(res, "pick_hide_checked", bad)
	bad = []
	var nope: Array[String] = ["Nope"]
	list.set_hidden(nope, none)
	_expect(bad, "unknown dropped", "%d %d" % [list.hidden_categories().size(), list.hidden_rarities().size()], "0 0")
	_expect(bad, "all shown", list.display_keys().size(), 6)
	var blank: Array[String] = [""]
	list.set_hidden(blank, blank)
	_expect(bad, "blank values", _keys_text(list.display_keys()), "Atlas,Codex,Lockpick,Rope")
	_verdict(res, "pick_hide_values", bad)
	list.queue_free()


static func _case_pick_view_silent(res: Dictionary, host: Control) -> void:
	var list: PercentPickList = _sort_list(host)
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	list.changed.connect(count)
	var bad: Array[String] = []
	var gear: Array[String] = ["Gear"]
	var none: Array[String] = []
	list.set_sort(PercentPickList.SORT_RARITY)
	list.set_hidden(gear, none)
	list.set_category_caption("Kind")
	list.set_hidden(none, none)
	list.set_sort(PercentPickList.SORT_NAME)
	list.sort_dropdown.select(&"rarity", true)
	_expect(bad, "picked mode", list.sort_mode(), PercentPickList.SORT_RARITY)
	_expect(bad, "picked sorts", _keys_text(list.display_keys()), "Rope,Lockpick,Atlas,Charm,Codex,Zither")
	_expect(bad, "emits", hits[0], 0)
	_verdict(res, "pick_view_silent", bad)
	list.changed.disconnect(count)
	list.queue_free()


static func _case_pick_view_kept(res: Dictionary, host: Control) -> void:
	var list: PercentPickList = _sort_list(host)
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	list.changed.connect(count)
	var bad: Array[String] = []
	var none: Array[String] = []
	list.set_sort(PercentPickList.SORT_RARITY)
	var legendary: Array[String] = ["Legendary"]
	list.set_hidden(none, legendary)
	list.set_entries(SORT_ENTRIES)
	list.clear()
	_expect(bad, "mode", list.sort_mode(), PercentPickList.SORT_RARITY)
	_expect(bad, "hidden", _keys_text(list.hidden_rarities()), "Legendary")
	_expect(bad, "display", _keys_text(list.display_keys()), "Rope,Lockpick,Atlas,Charm,Zither")
	_expect(bad, "emits", hits[0], 0)
	_verdict(res, "pick_view_kept", bad)
	bad = []
	var fewer: Array[Dictionary] = []
	for entry: Dictionary in SORT_ENTRIES:
		if String(entry["key"]) != "Codex":
			fewer.append(entry)
	list.set_entries(fewer)
	_expect(bad, "dropped", list.hidden_rarities().size(), 0)
	_expect(bad, "mode", list.sort_mode(), PercentPickList.SORT_RARITY)
	_verdict(res, "pick_view_dropped", bad)
	list.changed.disconnect(count)
	list.queue_free()


static func _case_pick_caption(res: Dictionary, host: Control) -> void:
	var list: PercentPickList = _sort_list(host)
	var bad: Array[String] = []
	_expect(bad, "default sections", _keys_text(list.hide_menu.section_keys()), "category,rarity")
	list.set_sort(PercentPickList.SORT_CATEGORY)
	list.set_category_caption("Stat", false)
	_expect(bad, "option", _option_labels(list.sort_dropdown)[1], "Sort: Stat")
	_expect(bad, "mode kept", list.sort_mode(), PercentPickList.SORT_CATEGORY)
	_expect(bad, "shown", list.sort_dropdown.button_text(), "Sort: Stat")
	_expect(bad, "sections", _keys_text(list.hide_menu.section_keys()), "rarity")
	_verdict(res, "pick_caption", bad)
	list.queue_free()


#Each row: the category block first, then the check with the rarity dot; the tag text moved to the check tooltip.
static func _case_pick_marks(res: Dictionary, host: Control) -> void:
	var list: PercentPickList = _sort_list(host)
	var bad: Array[String] = []
	var row: Node = list.check_for("Rope").get_parent()
	_expect(bad, "block first", row.get_child(0) == list.block_for("Rope"), true)
	_expect(bad, "check second", row.get_child(1) == list.check_for("Rope"), true)
	_expect(bad, "block width", list.block_for("Rope").custom_minimum_size.x, PercentPickList.BLOCK_WIDTH)
	_expect(bad, "block mouse", list.block_for("Rope").mouse_filter, Control.MOUSE_FILTER_PASS)
	_expect(bad, "Atlas block", list.block_for("Atlas").color, PercentPickList.category_color("Books"))
	_expect(bad, "Rope block tip", list.block_for("Rope").tooltip_text, "Gear")
	_expect(bad, "Charm block tip", list.block_for("Charm").tooltip_text, PercentPickList.NONE_LABEL)
	_expect(bad, "Charm block", list.block_for("Charm").color, PercentPickList.FALLBACK_COLOR)
	_expect(bad, "Rope dot", list.dot_color_for("Rope"), Color("#f3ead7"))
	_expect(bad, "Codex dot", list.dot_color_for("Codex"), GuiColors.AMBER)
	_expect(bad, "Zither no dot", list.check_for("Zither").has_dot(), false)
	_expect(bad, "unknown key", list.dot_color_for("Nope"), ToolFilterCheckRow.NO_DOT)
	_expect(bad, "Rope tip", list.check_for("Rope").tooltip_text, "Rope\nGear, Common")
	_expect(bad, "Charm tip", list.check_for("Charm").tooltip_text, "Charm\nVery Rare")
	_expect(bad, "Zither tip", list.check_for("Zither").tooltip_text, "Zither\nMusic")
	_verdict(res, "pick_marks", bad)
	bad = []
	var grouped: Array[Dictionary] = [{"key": CLEVER, "label": CLEVER, "group": "Cognition", "category": "Cognition",
		"rarity": "Uncommon"}, {"key": "Pack", "category": "Gear", "rarity": "Common"},
		{"key": "Kit", "category": "gear", "rarity": "very RARE"}, {"key": "Bare"}]
	list.set_entries(grouped)
	_expect(bad, "group tip", list.check_for(CLEVER).tooltip_text, CLEVER + "\nUncommon")
	_expect(bad, "stat block", list.block_for(CLEVER).color, Color("#5aa6e8"))
	_expect(bad, "spellings", list.check_for("Kit").tooltip_text, "Kit\nGear, Very Rare")
	_expect(bad, "spelled dot", list.dot_color_for("Kit"), Color("#a36ce8"))
	_expect(bad, "bare tip", list.check_for("Bare").tooltip_text, "Bare")
	_expect(bad, "one category row", list.hide_menu.row_for(PercentPickList.HIDE_CATEGORY, "gear") == null, true)
	_verdict(res, "pick_marks_group", bad)
	list.queue_free()


#The rarity dots match the Bazaar rarity colors and the amber of Legendary; categories ignore letter case.
static func _case_pick_colors(res: Dictionary) -> void:
	var bad: Array[String] = []
	var wanted: Array[String] = ["#f3ead7", "#6cc36a", "#5aa6e8", "#a36ce8", "#f2b33d"]
	for k: int in range(PercentPickList.RARITY_ORDER.size()):
		var rarity: String = PercentPickList.RARITY_ORDER[k]
		_expect(bad, rarity, PercentPickList.rarity_color(rarity), Color(wanted[k]))
	var matched: int = 0
	for entry: Dictionary in BazaarManager.RARITIES:
		var bazaar_name: String = String(entry["name"])
		if PercentPickList.RARITY_ORDER.has(bazaar_name):
			matched += 1
			_expect(bad, "bazaar " + bazaar_name, PercentPickList.rarity_color(bazaar_name), Color(String(entry["color"])))
	_expect(bad, "bazaar names", matched, 4)
	_expect(bad, "amber", PercentPickList.rarity_color("Legendary"), GuiColors.AMBER)
	_expect(bad, "case", PercentPickList.rarity_color("very rare"), Color("#a36ce8"))
	_expect(bad, "other", PercentPickList.rarity_color("Mythic"), PercentPickList.FALLBACK_COLOR)
	_expect(bad, "blank", PercentPickList.rarity_color(" "), ToolFilterCheckRow.NO_DOT)
	_verdict(res, "pick_colors_rarity", bad)
	bad = []
	_expect(bad, "Arcana", PercentPickList.category_color("Arcana"), Color("#b07cf0"))
	_expect(bad, "case", PercentPickList.category_color("cORPORATE"), Color("#cdb38a"))
	_expect(bad, "stat", PercentPickList.category_color("Wile"), Color("#b07cf0"))
	_expect(bad, "unlisted", PercentPickList.category_color("Gear"), Color("#a0a8b8"))
	_expect(bad, "blank", PercentPickList.category_color(""), Color("#a0a8b8"))
	_verdict(res, "pick_colors_category", bad)


#Search matches part of the name or the category, or the whole rarity name, in any letter case; the tooltip names the
#category caption.
static func _case_pick_search_marks(res: Dictionary, host: Control) -> void:
	var list: PercentPickList = _sort_list(host)
	var bad: Array[String] = []
	list.set_filter("BOOKS")
	_expect(bad, "category", _keys_text(list.visible_keys()), "Atlas,Codex")
	list.set_filter("legendary")
	_expect(bad, "rarity", _keys_text(list.visible_keys()), "Codex")
	list.set_filter("rare")
	_expect(bad, "rare", _keys_text(list.visible_keys()), "Atlas")
	list.set_filter("very rare")
	_expect(bad, "very rare", _keys_text(list.visible_keys()), "Charm")
	list.set_filter("legend")
	_expect(bad, "part of a rarity", _keys_text(list.visible_keys()), "")
	list.set_filter("LEGENDARY")
	_expect(bad, "upper case", _keys_text(list.visible_keys()), "Codex")
	list.set_filter("ope")
	_expect(bad, "name", _keys_text(list.visible_keys()), "Rope")
	_expect(bad, "tip", list.filter_edit.tooltip_text, "Matches name or category, or a full rarity name")
	list.set_category_caption("Stat", false)
	_expect(bad, "stat tip", list.filter_edit.tooltip_text, "Matches name or stat, or a full rarity name")
	_verdict(res, "pick_search_marks", bad)
	list.queue_free()


#The check is wide enough for NAME_ROOM after both margins; a dot row's margin never moves a row without a dot.
static func _case_pick_check_width(res: Dictionary, host: Control) -> void:
	var list: PercentPickList = _sort_list(host)
	var bad: Array[String] = []
	var dotted: ToolFilterCheckRow = list.check_for("Rope")
	var plain: ToolFilterCheckRow = list.check_for("Zither")
	var dot_box: StyleBox = dotted.get_theme_stylebox(&"normal")
	var plain_box: StyleBox = plain.get_theme_stylebox(&"normal")
	_expect(bad, "min width", dotted.custom_minimum_size.x, PercentPickList.CHECK_WIDTH)
	_expect(bad, "room", PercentPickList.CHECK_WIDTH - dot_box.get_margin(SIDE_LEFT) - dot_box.get_margin(SIDE_RIGHT),
		PercentPickList.NAME_ROOM)
	_expect(bad, "dot margin", dot_box.get_margin(SIDE_LEFT), FilterCheckRow.TEXT_MARGIN + ToolFilterCheckRow.DOT_ROOM)
	_expect(bad, "plain margin", plain_box.get_margin(SIDE_LEFT), FilterCheckRow.TEXT_MARGIN)
	_expect(bad, "own boxes", dot_box == plain_box, false)
	_expect(bad, "rooms", "%d %d" % [roundi(ToolFilterCheckRow.DOT_ROOM), roundi(PercentPickList.NAME_ROOM)], "14 150")
	_verdict(res, "pick_check_width", bad)
	bad = []
	var art: AtlasTexture = Icons.tex("dot", true)
	var art_size: Vector2 = art.get_size() if art != null else Vector2.ZERO
	_expect(bad, "art", art_size, Vector2(8, 8))
	_expect(bad, "scale", ToolFilterCheckRow.DOT_SCALE, 1)
	_expect(bad, "outline", ToolFilterCheckRow.DOT_OUTLINE, 1.0)
	_expect(bad, "slot", ToolFilterCheckRow.DOT_ROOM, art_size.x + 2.0 * ToolFilterCheckRow.DOT_OUTLINE + 4.0)
	_verdict(res, "pick_dot_small", bad)
	bad = []
	var row: ToolFilterCheckRow = ToolFilterCheckRow.make_row("Loose", false)
	var neighbour: ToolFilterCheckRow = ToolFilterCheckRow.make_row("Next", false)
	host.add_child(row)
	host.add_child(neighbour)
	row.dot_color = Color("#5aa6e8")
	_expect(bad, "set after ready", row.get_theme_stylebox(&"normal").get_margin(SIDE_LEFT),
		FilterCheckRow.TEXT_MARGIN + ToolFilterCheckRow.DOT_ROOM)
	_expect(bad, "neighbour kept", neighbour.get_theme_stylebox(&"normal").get_margin(SIDE_LEFT),
		FilterCheckRow.TEXT_MARGIN)
	row.dot_color = ToolFilterCheckRow.NO_DOT
	_expect(bad, "cleared", row.get_theme_stylebox(&"normal").get_margin(SIDE_LEFT), FilterCheckRow.TEXT_MARGIN)
	_verdict(res, "pick_margin_per_row", bad)
	row.queue_free()
	neighbour.queue_free()
	list.queue_free()


#Category rows of the Filter popup sit right of a color block; rarity rows carry the dot. Plain options stay plain.
static func _case_hide_menu_marks(res: Dictionary, host: Control) -> void:
	var list: PercentPickList = _sort_list(host)
	var bad: Array[String] = []
	var gear: ToolFilterCheckRow = list.hide_menu.row_for(PercentPickList.HIDE_CATEGORY, "Gear")
	var line: Node = gear.get_parent()
	var block: ColorRect = line.get_child(0) as ColorRect
	_expect(bad, "block", block != null and block.color == PercentPickList.category_color("Gear"), true)
	_expect(bad, "block width", block.custom_minimum_size.x if block != null else 0.0, ToolHideMenu.BLOCK_WIDTH)
	_expect(bad, "row second", line.get_child(1) == gear, true)
	var blank: ToolFilterCheckRow = list.hide_menu.row_for(PercentPickList.HIDE_CATEGORY, "")
	_expect(bad, "none block", (blank.get_parent().get_child(0) as ColorRect).color, PercentPickList.FALLBACK_COLOR)
	_expect(bad, "category no dot", gear.has_dot(), false)
	var rare_row: ToolFilterCheckRow = list.hide_menu.row_for(PercentPickList.HIDE_RARITY, "Rare")
	_expect(bad, "rare dot", rare_row.dot_color, Color("#5aa6e8"))
	_expect(bad, "legendary dot", list.hide_menu.row_for(PercentPickList.HIDE_RARITY, "Legendary").dot_color,
		GuiColors.AMBER)
	_expect(bad, "blank rarity", list.hide_menu.row_for(PercentPickList.HIDE_RARITY, "").has_dot(), false)
	_expect(bad, "rarity row parent", rare_row.get_parent() is VBoxContainer, true)
	list.queue_free()
	var menu: ToolHideMenu = ToolHideMenu.new()
	host.add_child(menu)
	var books: Array[String] = ["Books"]
	var rare: Array[String] = ["Rare"]
	menu.set_sections(_hide_sections(books, rare))
	_expect(bad, "plain parent", menu.row_for("category", "Books").get_parent() is VBoxContainer, true)
	_expect(bad, "plain no dot", menu.row_for("rarity", "Rare").has_dot(), false)
	_verdict(res, "hide_menu_marks", bad)
	menu.queue_free()


static func _hide_sections(categories: Array[String], rarities: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pair: Array in [["category", "Category", categories], ["rarity", "Rarity", rarities]]:
		var options: Array[Dictionary] = []
		for value: String in pair[2]:
			options.append({"key": value, "label": value})
		out.append({"key": pair[0], "title": pair[1], "options": options})
	return out


static func _case_hide_menu(res: Dictionary, host: Control) -> void:
	var menu: ToolHideMenu = ToolHideMenu.new()
	host.add_child(menu)
	var bad: Array[String] = []
	_expect(bad, "disabled empty", menu.toggle.disabled, true)
	var books_gear: Array[String] = ["Books", "Gear"]
	var common_rare: Array[String] = ["Common", "Rare"]
	menu.set_sections(_hide_sections(books_gear, common_rare))
	_expect(bad, "enabled", menu.toggle.disabled, false)
	_expect(bad, "normal look", menu.toggle.fill, BevelButton.palette(ToolHideMenu.NORMAL_KIND)["fill"])
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	menu.changed.connect(count)
	menu.row_for("category", "Gear").button_pressed = false
	_expect(bad, "toggle emits", hits[0], 1)
	_expect(bad, "hidden", _keys_text(menu.hidden("category")), "Gear")
	_expect(bad, "filtering", menu.is_filtering(), true)
	_expect(bad, "active look", menu.toggle.fill, BevelButton.palette(ToolHideMenu.ACTIVE_KIND)["fill"])
	_expect(bad, "unknown row", menu.row_for("category", "Nope") == null, true)
	_verdict(res, "hide_menu_toggle", bad)
	bad = []
	var rare: Array[String] = ["Rare", "Zzz"]
	menu.set_hidden("rarity", rare)
	_expect(bad, "set_hidden silent", hits[0], 1)
	_expect(bad, "set_hidden drops", _keys_text(menu.hidden("rarity")), "Rare")
	menu.none_button().pressed.emit()
	_expect(bad, "None", "%s|%s|%d" % [_keys_text(menu.hidden("category")), _keys_text(menu.hidden("rarity")),
		hits[0]], "Books,Gear|Common,Rare|2")
	menu.none_button().pressed.emit()
	_expect(bad, "second None", hits[0], 2)
	menu.all_button().pressed.emit()
	_expect(bad, "All", "%d %s %d" % [menu.hidden("category").size(), menu.is_filtering(), hits[0]], "0 false 3")
	_verdict(res, "hide_menu_none_all", bad)
	bad = []
	menu.set_hidden("category", books_gear)
	var books: Array[String] = ["Books"]
	menu.set_sections(_hide_sections(books, common_rare))
	_expect(bad, "stale dropped", _keys_text(menu.hidden("category")), "Books")
	_expect(bad, "row off", menu.row_for("category", "Books").on, false)
	_expect(bad, "filtering", menu.is_filtering(), true)
	var none: Array[String] = []
	menu.set_hidden("category", none)
	_expect(bad, "cleared", menu.is_filtering(), false)
	_expect(bad, "silent", hits[0], 3)
	_verdict(res, "hide_menu_sections", bad)
	menu.changed.disconnect(count)
	menu.queue_free()
	bad = []
	var list: PercentPickList = _sort_list(host)
	var list_hits: Array[int] = [0]
	var list_count: Callable = func() -> void: list_hits[0] += 1
	list.changed.connect(list_count)
	list.hide_menu.row_for(PercentPickList.HIDE_CATEGORY, "Gear").button_pressed = false
	_expect(bad, "display", _keys_text(list.display_keys()), "Atlas,Charm,Codex,Zither")
	_expect(bad, "hidden", _keys_text(list.hidden_categories()), "Gear")
	_expect(bad, "rarity order", _keys_text(_hide_values(list.hide_menu, PercentPickList.HIDE_RARITY)),
		"Common,Uncommon,Rare,Very Rare,Legendary,")
	_expect(bad, "no list emit", list_hits[0], 0)
	_verdict(res, "hide_menu_in_list", bad)
	list.changed.disconnect(list_count)
	list.queue_free()


#Every option key of one hide section, in menu order, read through None.
static func _hide_values(menu: ToolHideMenu, section: String) -> Array[String]:
	var before: Array[String] = menu.hidden(section)
	var quiet: Array[String] = []
	menu.set_hidden(section, quiet)
	var all: Array[String] = []
	for key: String in ["Common", "Uncommon", "Rare", "Very Rare", "Legendary", ""]:
		if menu.row_for(section, key) != null:
			all.append(key)
	menu.set_hidden(section, all)
	var out: Array[String] = menu.hidden(section)
	menu.set_hidden(section, before)
	return out


#The real setters through a Build press on the fixture copies; a second press keeps each list's sort mode.
static func _case_check_builder_lists(res: Dictionary, page: CompletionPage) -> void:
	page.load_draft(_completion_draft("check", "", []))
	page.press_build()
	var builder: CheckBuilder = page.builder()
	var knowledges: PercentPickList = builder.knowledge_list
	var tools: PercentPickList = builder.tool_list
	var circumstances: PercentPickList = builder.circumstance_list
	var none: Array[String] = []
	for each: PercentPickList in [knowledges, tools, circumstances]:
		each.set_hidden(none, none)
		each.set_sort(PercentPickList.SORT_NAME)
	var bad: Array[String] = []
	var keys: Array[String] = knowledges.display_keys()
	_expect(bad, "rows", keys.size(), 121)
	_expect(bad, "first", _keys_text(keys.slice(0, 3)), "Aerdis,Aerial,Aeromancy")
	_expect(bad, "last", keys.back() if not keys.is_empty() else "", "Zukei")
	knowledges.set_sort(PercentPickList.SORT_CATEGORY)
	keys = knowledges.display_keys()
	_expect(bad, "category first", keys[0] if not keys.is_empty() else "", "Aeromancy")
	var location: Array[String] = ["Location"]
	knowledges.set_hidden(location, none)
	_expect(bad, "Location hidden", knowledges.display_keys().size(), 95)
	knowledges.set_hidden(none, none)
	_verdict(res, "check_builder_knowledges", bad)
	bad = []
	keys = tools.display_keys()
	_expect(bad, "rows", keys.size(), 72)
	_expect(bad, "name first", keys[0] if not keys.is_empty() else "", "Air Vehicles")
	tools.set_sort(PercentPickList.SORT_RARITY)
	keys = tools.display_keys()
	_expect(bad, "rarity first", keys[0] if not keys.is_empty() else "", "Armorer's")
	_verdict(res, "check_builder_tools", bad)
	bad = []
	for attribute: String in CheckBuilder.FALLBACK_ATTRIBUTES:
		var row: ToolFilterCheckRow = builder.attribute_row(attribute)
		if row != null:
			row.button_pressed = attribute == "Cognition"
	circumstances.set_sort(PercentPickList.SORT_RARITY)
	keys = circumstances.display_keys()
	_expect(bad, "rows", keys.size(), 6)
	_expect(bad, "first", keys[0] if not keys.is_empty() else "", "Spellcast (Cognition)")
	_expect(bad, "last", keys.back() if not keys.is_empty() else "", "Notice (Cognition)")
	_expect(bad, "sort option", _option_labels(circumstances.sort_dropdown)[1], "Sort: Stat")
	_expect(bad, "sections", _keys_text(circumstances.hide_menu.section_keys()), "rarity")
	_expect(bad, "dot", circumstances.dot_color_for("Notice (Cognition)"), PercentPickList.rarity_color("Rare"))
	_expect(bad, "stat block", circumstances.block_for("Notice (Cognition)").color,
		PercentPickList.category_color("Cognition"))
	_expect(bad, "tip", circumstances.check_for("Notice (Cognition)").tooltip_text, "Notice (Cognition)\nRare")
	_verdict(res, "check_builder_circumstances", bad)
	bad = []
	var named: Array[Dictionary] = ContractBuilderData.knowledge_rows()
	named.append_array(ContractBuilderData.tool_rows())
	for row: Dictionary in named:
		if not PercentPickList.CATEGORY_COLORS.has(String(row.get("category", "")).strip_edges().to_lower()):
			bad.append("no color for category '%s' (%s)" % [String(row.get("category", "")), String(row.get("name", ""))])
	for row: Dictionary in ContractBuilderData.circumstance_rows():
		if not PercentPickList.CATEGORY_COLORS.has(String(row.get("stat", "")).strip_edges().to_lower()):
			bad.append("no color for stat '%s'" % String(row.get("stat", "")))
	for each: PercentPickList in [knowledges, tools]:
		for key: String in each.display_keys():
			if each.block_for(key).color == PercentPickList.FALLBACK_COLOR or not each.check_for(key).has_dot():
				bad.append("marks of " + key)
	_expect(bad, "rows marked", knowledges.display_keys().size() + tools.display_keys().size(), 193)
	_verdict(res, "check_builder_marks", bad)
	bad = []
	builder.press_cancel()
	page.press_build()
	builder = page.builder()
	_expect(bad, "knowledge mode", builder.knowledge_list.sort_mode(), PercentPickList.SORT_CATEGORY)
	_expect(bad, "tool mode", builder.tool_list.sort_mode(), PercentPickList.SORT_RARITY)
	_expect(bad, "circumstance mode", builder.circumstance_list.sort_mode(), PercentPickList.SORT_RARITY)
	keys = builder.knowledge_list.display_keys()
	_expect(bad, "knowledge order", keys[0] if not keys.is_empty() else "", "Aeromancy")
	_verdict(res, "check_builder_rebuild", bad)
	for each: PercentPickList in [builder.knowledge_list, builder.tool_list, builder.circumstance_list]:
		each.set_sort(PercentPickList.SORT_NAME)
	_close_builder(builder)


#The shell scene in the host: page 1 filled through the draft, Next on page 2 waits for a Primary Location, on page 4
#for a check pick and on page 5 for a description; after the review, page 4 under the event Style waits for an event pick.
#A draft the designer left in DRAFT_PATH is put back afterwards.
static func _case_shell(res: Dictionary, host: Control) -> void:
	var had_draft: bool = FileAccess.file_exists(ContractBuilder.DRAFT_PATH)
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(ContractBuilder.DRAFT_PATH) if had_draft else PackedByteArray()
	if had_draft:
		DirAccess.remove_absolute(ContractBuilder.DRAFT_PATH)
	var scene: PackedScene = load(BUILDER_SCENE) as PackedScene
	var node: Node = scene.instantiate() if scene != null else null
	var shell: ContractBuilder = node as ContractBuilder
	if shell == null:
		TestFixtures.check(res, "shell_scene", false, "cannot instance %s as ContractBuilder" % BUILDER_SCENE)
		if node != null:
			node.free()
	else:
		shell.hosted = true
		shell.rebuild_on_confirm = false
		host.add_child(shell)
		await TestFixtures.frames(host)
		await _shell_checks(res, shell)
		shell.queue_free()
		await host.get_tree().process_frame
	if FileAccess.file_exists(ContractBuilder.DRAFT_PATH):
		DirAccess.remove_absolute(ContractBuilder.DRAFT_PATH)
	if had_draft and not _store_bytes(ContractBuilder.DRAFT_PATH, saved):
		TestFixtures.check(res, "shell_draft_restore", false, "cannot put back %s" % ContractBuilder.DRAFT_PATH)


static func _shell_checks(res: Dictionary, shell: ContractBuilder) -> void:
	var filled: ContractDraft = ContractDraft.new()
	filled.contract_name = "Lamp Run"
	filled.contract_type = TEMPLATE_TYPE
	filled.issuer_type = "person"
	filled.issuer = String(PERSON_PICK)
	filled.style = "check"
	shell.draft.from_dict(filled.to_dict())
	shell.show_page(0)
	var first: bool = shell.pages[0].is_complete()
	shell.show_page(1)
	var next: BevelButton = shell.get_node_or_null("Margin/Column/BottomBar/Next") as BevelButton
	var location: LocationPage = shell.pages[1] as LocationPage
	if next == null or location == null:
		TestFixtures.check(res, "shell_next_gate", false, "Next found %s, page 2 a LocationPage %s" % [next != null,
			location != null])
		return
	var gated: bool = next.disabled
	location.select_all.pressed.emit()
	var stored: int = shell.draft.possible_locations.size()
	TestFixtures.check(res, "shell_next_gate", first and gated and not next.disabled and stored == PLACE_COUNT,
		"page 1 complete %s; Next disabled %s, then %s after Select all; %d stored" % [first, gated, next.disabled,
			stored])
	shell.go_next()
	TestFixtures.check(res, "shell_go_next", shell.index == 2, "index %d" % shell.index)
	var target: TargetPage = shell.pages[2] as TargetPage if shell.pages.size() > 2 else null
	TestFixtures.check(res, "shell_target_page", target != null and target.visible, "a TargetPage %s, visible %s" % [
		target != null, target != null and target.visible])
	if target == null:
		return
	TestFixtures.check(res, "shell_target_next", not next.disabled, "Next disabled %s on a blank target" % next.disabled)
	target.radio_npc.button_pressed = true
	shell.go_next()
	var completion: CompletionPage = shell.pages[3] as CompletionPage if shell.pages.size() > 3 else null
	var panel_shown: bool = completion != null and completion.check_panel.visible
	TestFixtures.check(res, "shell_completion_page", shell.index == 3 and panel_shown and next.disabled,
		"index %d, a CompletionPage %s, check panel %s, Next disabled %s" % [shell.index, completion != null,
			panel_shown, next.disabled])
	if completion == null:
		return
	completion.pick(_sheet_key(POISON_VIAL))
	var picked: bool = shell.draft.completion == "check:" + POISON_VIAL
	TestFixtures.check(res, "shell_completion_next", picked and not next.disabled,
		"Next disabled %s, completion '%s'" % [next.disabled, shell.draft.completion])
	shell.go_next()
	var description: DescriptionPage = shell.pages[4] as DescriptionPage if shell.pages.size() > 4 else null
	TestFixtures.check(res, "shell_description_gate", shell.index == 4 and next.disabled and description != null,
		"index %d, Next disabled %s, a DescriptionPage %s" % [shell.index, next.disabled, description != null])
	if description == null:
		return
	_type_text(description.entry_edits[0], "Lamp text")
	await TestFixtures.frames(shell)
	TestFixtures.check(res, "shell_description_next", not next.disabled, "Next disabled %s, stored %s" % [
		next.disabled, str(shell.draft.descriptions)])
	shell.go_next()
	var review: String = ReviewPage.review_text(shell.draft)
	TestFixtures.check(res, "shell_review_description", shell.index == 5 and review.contains("Description: Lamp text")
		and review.contains("Target: "), "index %d, Description line %s, Target line %s" % [shell.index,
			review.contains("Description: Lamp text"), review.contains("Target: ")])
	shell.draft.style = "event"
	shell.draft.completion = ""
	shell.show_page(3)
	var event_shown: bool = completion.event_panel.visible
	TestFixtures.check(res, "shell_completion_event", shell.index == 3 and event_shown and next.disabled,
		"index %d, event panel %s, Next disabled %s" % [shell.index, event_shown, next.disabled])
	completion.pick_event(&"Battle")
	var event_cell: String = "%s, %d" % [shell.draft.completion, shell.draft.time]
	TestFixtures.check(res, "shell_completion_event_next", not next.disabled and event_cell == "event:Battle, 60",
		"Next disabled %s, completion and time '%s'" % [next.disabled, event_cell])


static func _case_tsv_guard(res: Dictionary, sums: Dictionary) -> void:
	var changed: Array[String] = []
	for path: String in _sheet_paths():
		var sum: String = FileAccess.get_md5(path)
		if sum == "" or sum != String(sums.get(path, "")):
			changed.append(path.get_file())
	TestFixtures.check(res, "tsv_guard", changed.is_empty(), TestFixtures.detail(changed, _sheet_paths().size(),
		"sheets changed"))


#LineEdit.text does not emit text_changed, so a typed edit sets the text and the caret and then emits it.
static func _type_into(edit: LineEdit, text: String) -> void:
	edit.text = text
	edit.caret_column = text.length()
	edit.text_changed.emit(text)


static func _submit(edit: LineEdit, text: String) -> void:
	edit.text = text
	edit.caret_column = text.length()
	edit.text_submitted.emit(text)


static func _levels(page: OverviewPage) -> String:
	return "%d-%d shown %s-%s" % [int(page.level_slider.low), int(page.level_slider.high),
		page.level_min_edit.text, page.level_max_edit.text]


static func _shown(page: OverviewPage) -> Array[String]:
	var out: Array[String] = []
	for child: Node in page.suggestion_box.get_children():
		var pick: BevelButton = child as BevelButton
		if pick != null and pick.visible:
			out.append(pick.text)
	return out


static func _suggestion(page: OverviewPage, title: String) -> BevelButton:
	for child: Node in page.suggestion_box.get_children():
		var pick: BevelButton = child as BevelButton
		if pick != null and pick.visible and pick.text == title:
			return pick
	return null


static func _keys(dropdown: OptionDropdown) -> Array[String]:
	var out: Array[String] = []
	for opt: Dictionary in dropdown.options:
		out.append(String(opt.get("key", &"")))
	return out


static func _role_row(page: OverviewPage, role: String) -> ToolFilterCheckRow:
	for row: ToolFilterCheckRow in page.role_rows:
		if row.label == role:
			return row
	return null


static func _primary_row(page: LocationPage, place: String) -> ToolFilterCheckRow:
	var at: int = page.primary_names.find(place)
	return page.primary_rows[at] if at >= 0 and at < page.primary_rows.size() else null


static func _sub_index(page: LocationPage, area: String) -> int:
	return page.sub_names.find(area)


static func _checked(page: LocationPage) -> Array[String]:
	var out: Array[String] = []
	for i: int in range(page.primary_rows.size()):
		if page.primary_rows[i].button_pressed:
			out.append(page.primary_names[i])
	return out


#"<name> <percent>" per sub row that is on, in page order, read from the rows and sliders.
static func _sub_on(page: LocationPage) -> Array[String]:
	var out: Array[String] = []
	for i: int in range(page.sub_rows.size()):
		if page.sub_rows[i].button_pressed:
			out.append("%s %d" % [page.sub_names[i], int(page.sub_sliders[i].value)])
	return out


#The keys whose values differ between two ContractDraft.to_dict() results, each with both values.
static func _diff(before: Dictionary, after: Dictionary, keys: Array) -> Array[String]:
	var out: Array[String] = []
	for key: Variant in keys:
		var was: Variant = before.get(key)
		var now: Variant = after.get(key)
		if typeof(was) != typeof(now) or was != now:
			out.append("%s %s vs %s" % [str(key), str(was), str(now)])
	return out


#TextEdit.text set from code emits no text_changed; select_all and insert_text_at_caret emit it one frame later.
static func _type_text(edit: TextEdit, text: String) -> void:
	edit.select_all()
	edit.insert_text_at_caret(text)


#A draft with level_min 5 and level_max 30 and the given Target cell.
static func _target_draft(cell: String) -> ContractDraft:
	var draft: ContractDraft = ContractDraft.new()
	draft.level_min = TARGET_LEVEL_MIN
	draft.level_max = TARGET_LEVEL_MAX
	draft.target = cell
	return draft


static func _stored_target(page: TargetPage) -> String:
	var draft: ContractDraft = _target_draft("")
	page.store_draft(draft)
	return draft.target


static func _target_radio(page: TargetPage) -> String:
	var out: Array[String] = []
	if page.radio_npc.button_pressed:
		out.append("npc")
	if page.radio_monster.button_pressed:
		out.append("monster")
	if page.radio_random.button_pressed:
		out.append("random")
	if page.radio_none.button_pressed:
		out.append("none")
	return ",".join(out)


static func _target_panels(page: TargetPage) -> String:
	var out: Array[String] = []
	if page.npc_panel.visible:
		out.append("npc")
	if page.monster_panel.visible:
		out.append("monster")
	if page.random_panel.visible:
		out.append("random")
	return ",".join(out)


static func _range_text(page: TargetPage) -> String:
	return "%s-%s" % [page.level_min_edit.text, page.level_max_edit.text]


#"<key>/<label>" of the first option.
static func _head(dropdown: OptionDropdown) -> String:
	if dropdown.options.is_empty():
		return ""
	var first: Dictionary = dropdown.options[0]
	return "%s/%s" % [String(first.get("key", &"")), str(first.get("label", ""))]


static func _texts(buttons: Array[BevelButton]) -> Array[String]:
	var out: Array[String] = []
	for button: BevelButton in buttons:
		out.append(button.text)
	return out


static func _disabled(buttons: Array[BevelButton]) -> String:
	var out: Array[String] = []
	for button: BevelButton in buttons:
		out.append(str(button.disabled))
	return ",".join(out)


static func _edit_texts(page: DescriptionPage) -> Array[String]:
	var out: Array[String] = []
	for edit: TextEdit in page.entry_edits:
		out.append(edit.text)
	return out


#The changed count each step added, from the running count taken after every step.
static func _steps(marks: Array[int]) -> String:
	var out: Array[String] = []
	var last: int = 0
	for mark: int in marks:
		out.append(str(mark - last))
		last = mark
	return " ".join(out)


static func _expect(bad: Array[String], label: String, got: Variant, want: Variant) -> void:
	if typeof(got) != typeof(want) or got != want:
		bad.append("%s '%s' not '%s'" % [label, str(got), str(want)])


static func _verdict(res: Dictionary, label: String, bad: Array[String]) -> void:
	TestFixtures.check(res, label, bad.is_empty(), "; ".join(bad) if not bad.is_empty() else "all as expected")


#The fourteen sheets the builder reads, as their res:// constants.
static func _sheet_paths() -> Array[String]:
	var out: Array[String] = [ContractBuilderData.CONTRACTS_PATH, ContractBuilderData.TYPES_PATH,
		ContractBuilderData.ORGANIZATIONS_PATH, ContractBuilderData.LOCATIONS_PATH, ContractBuilderData.DESCRIPTIONS_PATH,
		ContractBuilderData.AREAS_PATH, ContractBuilderData.BUILDINGS_PATH, ContractBuilderData.NPCS_PATH,
		ContractBuilderData.TRADITIONS_PATH, ContractBuilderData.CHECKS_PATH, ContractBuilderData.STATS_PATH,
		ContractBuilderData.CIRCUMSTANCES_PATH, ContractBuilderData.KNOWLEDGES_PATH, ContractBuilderData.EVENTS_PATH]
	return out


static func _scratch(res_path: String) -> String:
	return SCRATCH_DIR + "/" + res_path.get_file()


static func _sheet_sums() -> Dictionary:
	var out: Dictionary = {}
	for path: String in _sheet_paths():
		out[path] = FileAccess.get_md5(path)
	return out


#Copies the fourteen fixture sheets (SheetFixtures) to SCRATCH_DIR and points the ContractBuilderData path vars at
#the copies.
static func _scratch_setup() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCRATCH_DIR))
	for path: String in _sheet_paths():
		var source: String = SheetFixtures.path(path)
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(source)
		if bytes.is_empty() or not _store_bytes(_scratch(path), bytes):
			return "cannot copy %s to %s" % [source, SCRATCH_DIR]
		if FileAccess.get_md5(_scratch(path)) != String(SheetFixtures.MD5.get(path.get_file(), "")):
			return "the copy of %s differs from the fixture" % source
	ContractBuilderData.contracts_path = _scratch(ContractBuilderData.CONTRACTS_PATH)
	ContractBuilderData.types_path = _scratch(ContractBuilderData.TYPES_PATH)
	ContractBuilderData.organizations_path = _scratch(ContractBuilderData.ORGANIZATIONS_PATH)
	ContractBuilderData.locations_path = _scratch(ContractBuilderData.LOCATIONS_PATH)
	ContractBuilderData.descriptions_path = _scratch(ContractBuilderData.DESCRIPTIONS_PATH)
	ContractBuilderData.areas_path = _scratch(ContractBuilderData.AREAS_PATH)
	ContractBuilderData.buildings_path = _scratch(ContractBuilderData.BUILDINGS_PATH)
	ContractBuilderData.npcs_path = _scratch(ContractBuilderData.NPCS_PATH)
	ContractBuilderData.traditions_path = _scratch(ContractBuilderData.TRADITIONS_PATH)
	ContractBuilderData.checks_path = _scratch(ContractBuilderData.CHECKS_PATH)
	ContractBuilderData.stats_path = _scratch(ContractBuilderData.STATS_PATH)
	ContractBuilderData.circumstances_path = _scratch(ContractBuilderData.CIRCUMSTANCES_PATH)
	ContractBuilderData.knowledges_path = _scratch(ContractBuilderData.KNOWLEDGES_PATH)
	ContractBuilderData.events_path = _scratch(ContractBuilderData.EVENTS_PATH)
	return ""


static func _store_bytes(path: String, bytes: PackedByteArray) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("BuilderPageTests: cannot write %s" % path)
		return false
	var stored: bool = bytes.is_empty() or file.store_buffer(bytes)
	file.close()
	return stored
