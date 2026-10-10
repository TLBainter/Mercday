class_name BuilderTests

#Contract builder stage 1: the Contracts.tsv schema, new cell parsing and checks, name keyed files and pruning,
#ContractLibrary name lookups, the header-only tables, the Urban and TBD areas and Terrain Odds forcing.
#Stage 2: TsvRowWriter, ContractDraft row loads and the issuer readers, on user:// copies of the five sheets;
#ContractRowWriter, ContractRebuild, the Review page text and Confirm on the real scene.
#Stage 3: the place and area row readers and ToolPixelSlider; the copies and the md5 guard add Areas.tsv and Buildings.tsv.
#Stage 4A: TsvRowWriter.replace_rows, the NPC title, creature type and tradition readers, and the Descriptions.tsv rows
#ContractRowWriter writes; the copies and the md5 guard add NPCs.tsv and Traditions.tsv.
#Stage 4B-1: CheckSheet, the Checks, Stats, Circumstances and Knowledges and Tools readers, ContractDraft.check_row,
#the check rules and the Checks.tsv row ContractRowWriter appends; the copies and the md5 guard add those four sheets.
#Stage 4B-2: EventConfig, the Events.tsv readers, the event rules of ContractRowWriter and the event row it writes;
#the copies and the md5 guard add Events.tsv.
#Stage 4B-3: TimelineGrammar, the timeline rules of ContractRowWriter and ContractDataValidator, the pending timeline
#check rows ContractRowWriter appends and ContractDraft.timeline_checks.
#Run: godot --headless --path . -- --builder-tests

const CONTRACTS_TSV := "res://TSVs/Contracts.tsv"
const CONTRACTS_OLD_TSV := "res://TSVs/Contracts_OLD.tsv"
const NEW_COLUMNS: Array[String] = ["Level Min", "Level Max", "Issuer Type", "Issuer", "Difficulty Min",
	"Difficulty Max", "Story", "Style", "Roles", "Target", "Completion", "Event Config", "Time", "Consequence",
	"Min Mercs", "Max Mercs", "Local"]
const TEMPLATE_NAMES: Array[String] = ["Assassinate", "Entertain", "Escort", "Investigate", "Military",
	"Monster Hunt", "Rescue", "Treasure Hunt"]
const TBD_AREAS: Array[String] = ["Desert", "Forest", "Marsh", "Mountain", "Plain", "Sea", "Sky", "Snowy",
	"Tropical", "Volcanic"]
const AREA_ROW_TYPES: Array[String] = ["Exterior", "Cavern", "Dungeon", "City", "TBD", "Interior"]
const ODDS_LOCATION := "Rossade"
const DRAWS := 20
#Stage 2 cases write only to sheet copies in SCRATCH_DIR; tsv_guard checks the res:// sheets kept their bytes.
const SCRATCH_DIR: String = "user://builder_tests"
#The build, prune and .tres text cases write here instead of the tracked Resources folders.
const DISK_DIR: String = "user://builder_test"
const LIST_COLUMNS: Array[String] = ["Possible Traits", "Possible Locations", "Roles"]
const TEMPLATE_LIST_COLUMNS: Array[String] = ["Possible Traits", "Possible Locations"]
const TEMPLATE_TEXT_COLUMNS: Array[String] = ["Description Template", "Target Category", "Terrain Odds"]
const TEMPLATE_KEYS: Array[String] = ["boosts", "description_template", "target_category", "possible_traits",
	"possible_locations", "terrain_odds"]
const FULL_NAME: String = "Caravan Watch at Rossade"
const BUILDER_SCENE: String = "res://Scenes/Tools/ContractBuilder.tscn"
#The Checks.tsv row the check cases write, Knowledges, Tools and Opposed Check left blank, and its summary lines.
const CHECK_NAME: String = "Trial of Wit"
const CHECK_CELLS: Array[String] = ["Trial of Wit", "Cognition", "Clever (Cognition) 10", "", "", "Mage +15", "1.5",
	"120", "Yes", "", "hp -2"]
const CHECK_SUMMARY: Array[String] = ["Attributes: Cognition", "Circumstances: Clever (Cognition) 10",
	"Traditions: Mage +15", "Multiplier: 1.5", "Time: 120", "Opposed: Yes", "Consequence: hp -2"]
#The P:78 timeline example in canonical form.
const TL_P78: String = ("a=event:Fight Bandits time=120 ; b1=event:Chase if a.failure cfg=chase=vehicle,chasing=mercs ; "
	+ "b2=check:Interrogate if a.success role=Leader ; c=check:Deliver fail")


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_fixture_check(res, "fixture_integrity")
	var sums: Dictionary = _sheet_sums()
	_case_tsv_header(res)
	_case_rows_named(res)
	_case_build_counts(res)
	_case_parse(res)
	_case_validate(res)
	_case_merc_count(res)
	_case_duplicate(res)
	_case_library(res)
	_case_prune(res)
	_case_tres_text(res)
	_case_memory_build(res)
	_case_new_tables(res)
	_case_areas(res)
	_case_odds_allowed(res)
	_case_draw(res)
	_case_odds_validator(res)
	_scratch_case(res, "writer_append_lf", _case_writer_append_lf)
	_scratch_case(res, "writer_append_crlf", _case_writer_append_crlf)
	_scratch_case(res, "writer_replace", _case_writer_replace)
	_scratch_case(res, "writer_refuse", _case_writer_refuse)
	_scratch_case(res, "writer_column", _case_writer_column)
	_scratch_case(res, "writer_orgs", _case_writer_orgs)
	_scratch_case(res, "draft_round_trip", _case_draft_round_trip)
	_scratch_case(res, "draft_template", _case_draft_template)
	_case_draft_name_length(res)
	_case_data_readers(res)
	_case_place_rows(res)
	_case_area_rows(res)
	_case_reset_paths(res)
	_case_pixel_slider(res)
	_scratch_case(res, "data_npc_titles", _case_data_npc_titles)
	_case_data_creature_types(res)
	_case_data_tradition_names(res)
	_scratch_case(res, "writer_replace_rows_lf", _case_writer_replace_rows_lf)
	_scratch_case(res, "writer_replace_rows_crlf", _case_writer_replace_rows_crlf)
	_scratch_case(res, "writer_replace_rows_keys", _case_writer_replace_rows_keys)
	_scratch_case(res, "writer_replace_rows_refuse", _case_writer_replace_rows_refuse)
	_scratch_case(res, "row_writer_check", _case_row_writer_check)
	_scratch_case(res, "card285_row_writer_mercs", _case_row_writer_mercs)
	_scratch_case(res, "card285_draft_mercs", _case_draft_mercs)
	_scratch_case(res, "card736_draft_local", _case_draft_local)
	_scratch_case(res, "card736_row_writer_local", _case_row_writer_local)
	_scratch_case(res, "card745_help_rows_author", _case_help_rows_author)
	_scratch_case(res, "row_writer_append", _case_row_writer_append)
	_scratch_case(res, "row_writer_replace", _case_row_writer_replace)
	_scratch_case(res, "row_writer_mapped_name", _case_row_writer_mapped_name)
	_scratch_case(res, "row_writer_new_type", _case_row_writer_new_type)
	_scratch_case(res, "row_writer_new_org", _case_row_writer_new_org)
	_scratch_case(res, "row_writer_descriptions", _case_row_writer_descriptions)
	_scratch_case(res, "row_writer_check_description", _case_row_writer_check_description)
	_scratch_case(res, "row_writer_descriptions_sheet", _case_row_writer_descriptions_sheet)
	_case_rebuild_parse(res)
	_case_rebuild_run(res)
	_scratch_case(res, "review_text", _case_review_text)
	_case_check_sheet_lists(res)
	_case_check_sheet_percents(res)
	_case_check_sheet_signed(res)
	_case_check_sheet_scalars(res)
	_case_check_sheet_summary(res)
	_case_check_sheet_ascii(res)
	_scratch_case(res, "data_check_readers", _case_data_check_readers)
	_case_draft_check_row(res)
	_scratch_case(res, "row_writer_check_rules", _case_row_writer_check_rules)
	_scratch_case(res, "writer_check_completion", _case_writer_check_completion)
	_case_share_balance(res)
	_scratch_case(res, "row_writer_check_append", _case_row_writer_check_append)
	_scratch_case(res, "row_writer_check_sheet", _case_row_writer_check_sheet)
	_scratch_case(res, "review_text_check", _case_review_text_check)
	await _case_confirm_flow(res)
	_case_event_config_parse(res)
	_case_event_config_compose(res)
	_case_event_config_fields(res)
	_case_event_config_validate(res)
	_case_event_config_numbers(res)
	_scratch_case(res, "builder_data_events", _case_builder_data_events)
	_scratch_case(res, "writer_event_rules", _case_writer_event_rules)
	_scratch_case(res, "writer_event_round_trip", _case_writer_event_round_trip)
	_case_timeline_parse(res)
	_case_timeline_errors(res)
	_case_timeline_names(res)
	_case_timeline_walk(res)
	_case_timeline_ids(res)
	_scratch_case(res, "writer_timeline_rules", _case_writer_timeline_rules)
	_scratch_case(res, "writer_timeline_pending", _case_writer_timeline_pending)
	_scratch_case(res, "writer_timeline_sheet", _case_writer_timeline_sheet)
	_case_validator_timeline(res)
	_case_draft_timeline_checks(res)
	_scratch_case(res, "draft_from_row_timeline", _case_draft_from_row_timeline)
	_case_live_headers(res)
	_case_tsv_guard(res, sums)
	_case_fixture_check(res, "fixture_untouched")
	return TestFixtures.summarize(res, "BUILDER")


#The fourteen fixture sheets hold the bytes SheetFixtures.MD5 names.
static func _case_fixture_check(res: Dictionary, key: String) -> void:
	var problems: Array[String] = SheetFixtures.integrity()
	TestFixtures.check(res, key, problems.is_empty(),
		TestFixtures.detail(problems, SheetFixtures.MD5.size(), "fixture sheets off", 3))


#The distinct contract keys build_all writes from the live rows: nonblank row names, one per file stem.
static func _live_contract_count() -> int:
	var seen: Dictionary = {}
	for row: Dictionary in DataManager.contract_rows:
		var row_name: String = ContractResourceBuilder.row_name(row)
		if row_name != "":
			seen[ContractResourceBuilder.file_stem(row_name).to_lower()] = true
	return seen.size()


#The live Events.tsv rows build_all writes: every row with a nonblank Event Name, repeats kept.
static func _live_event_count() -> int:
	var count: int = 0
	for row: Dictionary in DataManager.event_rows:
		if String(row.get("Event Name", "")) != "":
			count += 1
	return count


#The tsv_ labels check the template sheet (Contracts_OLD.tsv); the live_tsv_ labels check the live sheet.
static func _case_tsv_header(res: Dictionary) -> void:
	_check_sheet_shape(res, CONTRACTS_OLD_TSV, "tsv_", TEMPLATE_NAMES.size() + 1)
	_check_sheet_shape(res, CONTRACTS_TSV, "live_tsv_", 2)


static func _check_sheet_shape(res: Dictionary, path: String, prefix: String, min_lines: int) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	var lines: PackedStringArray = text.split("\n")
	TestFixtures.check(res, prefix + "lines", lines.size() >= min_lines, "%d lines" % lines.size())
	var header: PackedStringArray = lines[0].split("\t")
	TestFixtures.check(res, prefix + "header_cells", header.size() == 42, "%d cells" % header.size())
	TestFixtures.check(res, prefix + "name_then_type", header.size() > 1 and header[0] == "Contract Name"
		and header[1] == "Contract Type", "first cells %s" % ", ".join(header.slice(0, 2)))
	var tail: String = ", ".join(header.slice(maxi(0, header.size() - NEW_COLUMNS.size())))
	TestFixtures.check(res, prefix + "new_columns", tail == ", ".join(NEW_COLUMNS), "last cells %s" % tail)
	TestFixtures.check(res, prefix + "no_cr", text.find("\r") < 0, "first CR at %d" % text.find("\r"))
	TestFixtures.check(res, prefix + "no_trailing_newline", text != "" and not text.ends_with("\n"),
		"%d characters" % text.length())


#contract_rows (in a harness run the live sheet plus Contracts_OLD.tsv) holds every template row, each named for
#its type; rows the designer added are not checked here.
static func _case_rows_named(res: Dictionary) -> void:
	var bad: Array[String] = []
	var names: Array[String] = []
	for row: Dictionary in DataManager.contract_rows:
		var row_name: String = String(row.get("Contract Name", ""))
		names.append(ContractResourceBuilder.row_name(row))
		if TEMPLATE_NAMES.has(row_name) and row_name != String(row.get("Contract Type", "")):
			bad.append("row %d" % int(row.get("_row", 0)))
	var missing: Array[String] = []
	for template: String in TEMPLATE_NAMES:
		if not names.has(template):
			missing.append(template)
	var count: int = DataManager.contract_rows.size()
	TestFixtures.check(res, "rows_count", count >= TEMPLATE_NAMES.size() and missing.is_empty(),
		"%d rows" % count if missing.is_empty() else "%d rows; missing: %s" % [count, ", ".join(missing)])
	TestFixtures.check(res, "rows_name_is_type", bad.is_empty(), TestFixtures.detail(bad, TEMPLATE_NAMES.size(), "rows"))


#Counts follow the live rows; a second build prunes nothing; a warning may name only a row the designer added.
static func _case_build_counts(res: Dictionary) -> void:
	var builder_state: Array = _disk_begin()
	var out: Dictionary = ContractResourceBuilder.build_all()
	var warnings: Array[String] = ContractResourceBuilder.last_warnings.duplicate()
	var again: Dictionary = ContractResourceBuilder.build_all()
	_disk_end(builder_state)
	var contracts: int = _live_contract_count()
	TestFixtures.check(res, "build_contracts", int(out.get("contracts", -1)) == contracts,
		"out %s, want %d" % [str(out), contracts])
	var events: int = _live_event_count()
	TestFixtures.check(res, "build_events", int(out.get("events", -1)) == events, "out %s, want %d" % [str(out), events])
	TestFixtures.check(res, "build_pruned", int(again.get("pruned", -1)) == 0, "second build %s" % str(again))
	var off: Array[String] = _off_warnings(DataManager.contract_rows, warnings)
	TestFixtures.check(res, "build_warnings", off.is_empty(), TestFixtures.detail(off, warnings.size(), "warnings", 3))
	var rows: Array[Dictionary] = [{"Contract Name": "Rescue", "Contract Type": "Rescue", "_row": 8},
		{"Contract Name": "", "Contract Type": "Rescue", "_row": 30}]
	var template_warning: String = ContractDataValidator.contract_warning(8, "Time", "unreadable time x")
	var crafted: Array[String] = [ContractDataValidator.contract_warning(30, "Contract Name", "blank name, using type"),
		ContractDataValidator.contract_warning(30, "Contract Name", "duplicate Contract Name Rescue, row skipped"),
		template_warning]
	var crafted_off: Array[String] = _off_warnings(rows, crafted)
	TestFixtures.check(res, "build_warnings_blank_name_row", crafted_off.size() == 1 and crafted_off[0] == template_warning,
		TestFixtures.detail(crafted_off, crafted.size(), "warnings", 3))


#The warnings that name no row whose Contract Name is outside TEMPLATE_NAMES; a blank name is a designer row.
static func _off_warnings(rows: Array[Dictionary], warnings: Array[String]) -> Array[String]:
	var prefixes: Array[String] = []
	for row: Dictionary in rows:
		if not TEMPLATE_NAMES.has(String(row.get("Contract Name", "")).strip_edges()):
			prefixes.append("ContractResourceBuilder: Contracts.tsv row %d column " % int(row.get("_row", 0)))
	var off: Array[String] = []
	for text: String in warnings:
		var allowed: bool = false
		for prefix: String in prefixes:
			allowed = allowed or text.begins_with(prefix)
		if not allowed:
			off.append(text)
	return off


static func _full_row() -> Dictionary:
	return {"Contract Name": "TEST Parse", "Contract Type": "Escort", "Level Min": "10", "Level Max": "120",
		"Issuer Type": "person", "Issuer": "Noble", "Difficulty Min": "1.5", "Difficulty Max": "3.0",
		"Story": "TRUE", "Style": "event", "Roles": "Driver, Escort", "Target": "npc:Bandit Leader",
		"Completion": "event:Fight Bandits", "Event Config": "bandits=1.5", "Time": "90", "Consequence": "hp -3, retry",
		"_row": 90}


static func _build(row: Dictionary) -> ContractData:
	var events: Array[EventData] = []
	return ContractResourceBuilder.build_contract(row, events)


static func _case_parse(res: Dictionary) -> void:
	var saved: Array[Dictionary] = DataManager.description_rows
	var texts: Array[Dictionary] = [{"Contract Name": "TEST Parse", "Description": "First"},
		{"Contract Name": "Escort", "Description": "Other"}, {"Contract Name": "TEST Parse", "Description": ""},
		{"Contract Name": "TEST Parse", "Description": "Second"}]
	DataManager.description_rows = texts
	var d: ContractData = _build(_full_row())
	DataManager.description_rows = saved
	TestFixtures.check(res, "parse_name", d.contract_name == "TEST Parse" and d.contract_type == "Escort",
		"%s / %s" % [d.contract_name, d.contract_type])
	TestFixtures.check(res, "parse_levels", d.level_min == 10 and d.level_max == 120, "%d to %d" % [d.level_min, d.level_max])
	TestFixtures.check(res, "parse_issuer", d.issuer_type == "person" and d.issuer == "Noble",
		"%s %s" % [d.issuer_type, d.issuer])
	TestFixtures.check(res, "parse_difficulty_range", d.difficulty_min == 1.5 and d.difficulty_max == 3.0,
		"%s to %s" % [str(d.difficulty_min), str(d.difficulty_max)])
	TestFixtures.check(res, "parse_story", d.story, "story %s" % str(d.story))
	TestFixtures.check(res, "parse_style", d.style == "event", d.style)
	TestFixtures.check(res, "parse_roles", ", ".join(d.roles) == "Driver, Escort", ", ".join(d.roles))
	TestFixtures.check(res, "parse_target", d.target == "npc:Bandit Leader", d.target)
	TestFixtures.check(res, "parse_completion", d.completion == "event:Fight Bandits", d.completion)
	TestFixtures.check(res, "parse_event_config", d.event_config == "bandits=1.5", d.event_config)
	TestFixtures.check(res, "parse_time", d.time_minutes == 90, "%d minutes" % d.time_minutes)
	TestFixtures.check(res, "parse_consequence", d.consequence == "hp -3, retry", d.consequence)
	TestFixtures.check(res, "parse_descriptions", ", ".join(d.descriptions) == "First, Second",
		"%d texts: %s" % [d.descriptions.size(), ", ".join(d.descriptions)])
	var changed: Array[String] = _changed_fields(_build({}))
	TestFixtures.check(res, "parse_blank_defaults", changed.is_empty(), "changed: %s" % ", ".join(changed))
	TestFixtures.check(res, "parse_story_case", _build({"Story": "true"}).story and not _build({"Story": "no"}).story,
		"true reads true, no reads false")
	var before: int = ContractResourceBuilder.last_warnings.size()
	var junk: ContractData = _build({"Level Min": "ten", "Time": "1.5", "Difficulty Max": "hard", "Difficulty": "x",
		"_row": 91})
	var added: Array[String] = []
	for i: int in range(before, ContractResourceBuilder.last_warnings.size()):
		added.append(ContractResourceBuilder.last_warnings[i])
	TestFixtures.check(res, "parse_unreadable_zero", junk.level_min == 0 and junk.time_minutes == 0
		and junk.difficulty_max == 0.0 and junk.difficulty == 0.0, "level %d time %d" % [junk.level_min, junk.time_minutes])
	var unread_ok: bool = added.size() == 4 and _has_warning(added, "Level Min", "unreadable level min ten") \
		and _has_warning(added, "Time", "unreadable time 1.5") \
		and _has_warning(added, "Difficulty Max", "unreadable difficulty max hard") \
		and _has_warning(added, "Difficulty", "unreadable difficulty x")
	TestFixtures.check(res, "parse_unreadable_warns", unread_ok, TestFixtures.detail(added, added.size(), "warnings", 4))


#The builder fields of data that differ from a fresh ContractData.
static func _changed_fields(data: ContractData) -> Array[String]:
	var fresh := ContractData.new()
	var out: Array[String] = []
	for field: String in ["contract_name", "level_min", "level_max", "issuer_type", "issuer", "difficulty_min",
			"difficulty_max", "story", "style", "roles", "target", "completion", "event_config", "time_minutes",
			"consequence", "descriptions"]:
		if data.get(field) != fresh.get(field):
			out.append(field)
	return out


static func _has_warning(warnings: Array[String], column: String, part: String) -> bool:
	for text: String in warnings:
		if text.contains("column %s: " % column) and text.contains(part):
			return true
	return false


static func _column_count(warnings: Array[String], column: String) -> int:
	var count: int = 0
	for text: String in warnings:
		if text.contains("column %s: " % column):
			count += 1
	return count


static func _warnings_of(row: Dictionary) -> Array[String]:
	return ContractDataValidator.validate_contract(_build(row), row)


#Card 285: Min Mercs and Max Mercs parse from the row, the generator resolves and clamps them, the validator warns.
static func _case_merc_count(res: Dictionary) -> void:
	var config: ContractConfig = ContractLibrary.config()
	var solo: ContractData = _build({"Contract Name": "TEST Solo", "Min Mercs": "1", "Max Mercs": "1", "_row": 96})
	var blank: ContractData = _build({"Contract Name": "TEST Crew", "_row": 97})
	TestFixtures.check(res, "card285_parse_mercs", solo.min_mercs == 1 and solo.max_mercs == 1 and blank.min_mercs == 0
		and blank.max_mercs == 0, "solo %d to %d, blank %d to %d" % [solo.min_mercs, solo.max_mercs, blank.min_mercs,
		blank.max_mercs])
	ContractGenerator.set_merc_range(config, solo)
	ContractGenerator.set_merc_range(config, blank)
	TestFixtures.check(res, "card285_solo_range", solo.min_mercs == 1 and solo.max_mercs == 1,
		"%d to %d" % [solo.min_mercs, solo.max_mercs])
	TestFixtures.check(res, "card285_blank_range", blank.min_mercs == config.board_merc_min
		and blank.max_mercs == config.default_max_mercs, "%d to %d" % [blank.min_mercs, blank.max_mercs])
	var wide: ContractData = _build({"Min Mercs": "9", "Max Mercs": "8", "_row": 98})
	var flipped: ContractData = _build({"Min Mercs": "4", "Max Mercs": "2", "_row": 98})
	ContractGenerator.set_merc_range(config, wide)
	ContractGenerator.set_merc_range(config, flipped)
	TestFixtures.check(res, "card285_clamped_range", wide.max_mercs == 5 and wide.min_mercs == 5
		and flipped.max_mercs == 2 and flipped.min_mercs == 2,
		"wide %d to %d, flipped %d to %d" % [wide.min_mercs, wide.max_mercs, flipped.min_mercs, flipped.max_mercs])
	var order: Array[String] = _warnings_of({"Min Mercs": "4", "Max Mercs": "2", "_row": 99})
	TestFixtures.check(res, "card285_warns_min_above_max", _has_warning(order, "Min Mercs", "4 is above Max Mercs 2"),
		"; ".join(order))
	var big: Array[String] = _warnings_of({"Max Mercs": "7", "_row": 99})
	TestFixtures.check(res, "card285_warns_out_of_range", _has_warning(big, "Max Mercs", "expected 1 to 5, got 7"),
		"; ".join(big))
	var lone: Array[String] = _warnings_of({"Min Mercs": "4", "_row": 99})
	TestFixtures.check(res, "card285_warns_min_above_default", _has_warning(lone, "Min Mercs",
		"4 is above Max Mercs %d" % config.default_max_mercs), "; ".join(lone))
	var fine: Dictionary = _full_row()
	fine["Min Mercs"] = "1"
	fine["Max Mercs"] = "1"
	var quiet: Array[String] = _warnings_of(fine)
	TestFixtures.check(res, "card285_valid_mercs_silent", quiet.is_empty(),
		TestFixtures.detail(quiet, quiet.size(), "warnings", 3))


static func _case_validate(res: Dictionary) -> void:
	var bad: Array[String] = _warnings_of({"Contract Name": "TEST Bad", "Contract Type": "Escort", "Level Min": "300",
		"Level Max": "20", "Difficulty Min": "1.25", "Difficulty Max": "1", "Issuer Type": "guild", "Style": "quest",
		"Roles": "Driver, Chef", "Target": "foo:bar", "Completion": "later", "Time": "-5",
		"Consequence": "hp -12, retry", "_row": 92})
	var expect: Array = [["level_range", "Level Min", "expected 0 to 240, got 300"],
		["level_order", "Level Min", "300 is above Level Max 20"],
		["difficulty_step", "Difficulty Min", "in steps of 0.5, got 1.25"],
		["difficulty_order", "Difficulty Min", "is above Difficulty Max"],
		["issuer_type", "Issuer Type", "got guild"], ["style", "Style", "got quest"],
		["roles", "Roles", "unknown role Chef"], ["target", "Target", "got foo:bar"],
		["completion", "Completion", "got later"], ["time", "Time", "got -5"],
		["consequence", "Consequence", "bad token hp -12"]]
	for entry: Array in expect:
		TestFixtures.check(res, "warns_" + String(entry[0]), _has_warning(bad, String(entry[1]), String(entry[2])),
			"%s: %s" % [String(entry[1]), String(entry[2])])
	TestFixtures.check(res, "warns_only_bad_tokens", _column_count(bad, "Roles") == 1
		and _column_count(bad, "Consequence") == 1 and _column_count(bad, "Level Max") == 0,
		"Roles %d, Consequence %d" % [_column_count(bad, "Roles"), _column_count(bad, "Consequence")])
	var king: Array[String] = _warnings_of({"Issuer Type": "person", "Issuer": "King", "_row": 93})
	TestFixtures.check(res, "warns_person_issuer", _has_warning(king, "Issuer", "got King"), "; ".join(king))
	var half: Array[String] = _warnings_of({"Difficulty Min": "2", "_row": 94})
	TestFixtures.check(res, "warns_one_difficulty_end", _has_warning(half, "Difficulty Max", "blank while"), "; ".join(half))
	var valid: Array[String] = _warnings_of(_full_row())
	TestFixtures.check(res, "valid_row_silent", valid.is_empty(), TestFixtures.detail(valid, valid.size(), "warnings", 3))
	var home: Array[String] = _warnings_of({"Issuer Type": "place", "Issuer": ODDS_LOCATION, "_row": 95})
	var lost: Array[String] = _warnings_of({"Issuer Type": "place", "Issuer": "TEST Nowhere", "_row": 95})
	TestFixtures.check(res, "place_issuer", home.is_empty() and _has_warning(lost, "Issuer", "unknown location TEST Nowhere"),
		"%d and %d warnings" % [home.size(), lost.size()])
	var org_row: Dictionary = {"Issuer Type": "org", "Issuer": "TEST Guild", "_row": 95}
	var unchecked: Array[String] = _warnings_of(org_row)
	var saved: Array[Dictionary] = DataManager.organization_rows
	var orgs: Array[Dictionary] = [{"Name": "TEST Lodge", "Type": "Guild", "Home": ODDS_LOCATION, "_row": 2}]
	DataManager.organization_rows = orgs
	var missing: Array[String] = _warnings_of(org_row)
	var found: Array[String] = _warnings_of({"Issuer Type": "org", "Issuer": "TEST Lodge", "_row": 95})
	DataManager.organization_rows = saved
	TestFixtures.check(res, "org_issuer", unchecked.is_empty() and found.is_empty()
		and _has_warning(missing, "Issuer", "unknown organization TEST Guild"),
		"empty table %d, missing %d, found %d" % [unchecked.size(), missing.size(), found.size()])
	var tokens_ok: bool = ContractDataValidator.consequence_token_ok("guild") \
		and ContractDataValidator.consequence_token_ok("mp -9") and ContractDataValidator.consequence_token_ok("retry -1") \
		and not ContractDataValidator.consequence_token_ok("ep 0") and not ContractDataValidator.consequence_token_ok("xp -1") \
		and not ContractDataValidator.consequence_token_ok("retry -10") \
		and not ContractDataValidator.consequence_token_ok("hp -1 -2")
	TestFixtures.check(res, "consequence_tokens", tokens_ok,
		"guild, mp -9, retry -1 pass; ep 0, xp -1, retry -10, hp -1 -2 fail")
	var forms_ok: bool = ContractDataValidator.completion_ok("") and ContractDataValidator.completion_ok("check:Scout") \
		and ContractDataValidator.completion_ok("0=check:Scout, 30=event:Ambush") \
		and not ContractDataValidator.completion_ok("check:") and not ContractDataValidator.completion_ok("later")
	TestFixtures.check(res, "completion_forms", forms_ok, "blank, check:, event: and timelines pass; check: alone fails")


#Sheet lines through the Contracts.tsv loader plus the template rows; the closing build_all prunes the test files.
static func _case_duplicate(res: Dictionary) -> void:
	var sheet: Array[PackedStringArray] = [PackedStringArray(["Contract Name", "Contract Type"]),
		PackedStringArray(["TEST Dup", "Military"]), PackedStringArray(["TEST Dup", "Escort"]),
		PackedStringArray(["", "TEST Fallback"]), PackedStringArray(["", ""])]
	var extra: Array[Dictionary] = DataManager.contract_rows_from(sheet)
	var kept: Array[String] = []
	for row: Dictionary in extra:
		kept.append("row %d %s" % [int(row.get("_row", 0)), ContractResourceBuilder.row_name(row)])
	TestFixtures.check(res, "load_keeps_blank_name", kept.has("row 4 TEST Fallback"), ", ".join(kept))
	TestFixtures.check(res, "load_drops_blank_line", kept.size() == 3, ", ".join(kept))
	var live_count: int = _live_contract_count()
	var builder_state: Array = _disk_begin()
	ContractResourceBuilder.build_all()
	var live_warnings: int = ContractResourceBuilder.last_warnings.size()
	var saved: Array[Dictionary] = DataManager.contract_rows
	var rows: Array[Dictionary] = []
	rows.append_array(saved)
	rows.append_array(extra)
	DataManager.contract_rows = rows
	var out: Dictionary = ContractResourceBuilder.build_all()
	var dup_warnings: int = 0
	var fallback_warned: bool = false
	for text: String in ContractResourceBuilder.last_warnings:
		if text.contains("row 3 column Contract Name: duplicate Contract Name TEST Dup, row skipped"):
			dup_warnings += 1
		fallback_warned = fallback_warned or text.contains("row 4 column Contract Name: blank name, using type")
	var warning_count: int = ContractResourceBuilder.last_warnings.size()
	DataManager.contract_rows = saved
	var dup: ContractData = ContractLibrary.contract("TEST Dup")
	var fallback: ContractData = ContractLibrary.contract("TEST Fallback")
	TestFixtures.check(res, "dup_written_once", int(out.get("contracts", -1)) == live_count + 2 and dup != null
		and dup.contract_type == "Military", "out %s, kept type %s" % [str(out), "none" if dup == null else dup.contract_type])
	TestFixtures.check(res, "dup_warned_once", dup_warnings == 1 and warning_count == live_warnings + 2,
		"%d duplicate warnings, %d in all, %d from the live rows" % [dup_warnings, warning_count, live_warnings])
	TestFixtures.check(res, "dup_fallback_name", fallback_warned and fallback != null
		and fallback.contract_name == "TEST Fallback", "warned %s" % str(fallback_warned))
	var restored: Dictionary = ContractResourceBuilder.build_all()
	var gone: bool = not FileAccess.file_exists(ContractResourceBuilder.contract_path("TEST Dup")) \
		and not FileAccess.file_exists(ContractResourceBuilder.contract_path("TEST Fallback"))
	TestFixtures.check(res, "dup_cleanup", gone and int(restored.get("pruned", -1)) == 2
		and int(restored.get("contracts", -1)) == live_count, "out %s, want %d" % [str(restored), live_count])
	_disk_end(builder_state)


static func _case_library(res: Dictionary) -> void:
	var rescue: ContractData = ContractLibrary.contract("Rescue")
	TestFixtures.check(res, "library_contract", rescue != null and rescue.contract_name == "Rescue"
		and rescue.contract_type == "Rescue", "null" if rescue == null else rescue.contract_name)
	var by_type: ContractData = ContractLibrary.contract_type("Rescue")
	TestFixtures.check(res, "library_contract_type", by_type != null and by_type.contract_type == "Rescue",
		"null" if by_type == null else by_type.contract_type)
	var names: Array[String] = ContractLibrary.contract_names()
	TestFixtures.check(res, "library_names", names.size() == _live_contract_count() and _templates_only(names),
		", ".join(names))
	TestFixtures.check(res, "library_for_type", ContractLibrary.contracts_for_type("Rescue").size() == 1
		and ContractLibrary.contracts_for_type("TEST None").is_empty(),
		"%d Rescue rows" % ContractLibrary.contracts_for_type("Rescue").size())
	var type_names: Array[String] = ContractLibrary.contract_type_names()
	TestFixtures.check(res, "library_type_names", _templates_only(type_names), ", ".join(type_names))


#Every template name is listed and no TEST row the cases wrote is left.
static func _templates_only(names: Array[String]) -> bool:
	for template: String in TEMPLATE_NAMES:
		if not names.has(template):
			return false
	for listed: String in names:
		if listed.begins_with("TEST "):
			return false
	return true


static func _case_prune(res: Dictionary) -> void:
	var builder_state: Array = _disk_begin()
	ContractResourceBuilder.build_all()
	var stale := ContractData.new()
	stale.contract_name = "Stale Row"
	stale.contract_type = "Stale Row"
	var path: String = ContractResourceBuilder.contract_path("Stale Row")
	ResourceTextWriter.save(stale, path, "ContractData", ContractResourceBuilder.CONTRACT_SCRIPT)
	var written: bool = FileAccess.file_exists(path)
	var out: Dictionary = ContractResourceBuilder.build_all()
	TestFixtures.check(res, "prune_stub_written", written, path)
	TestFixtures.check(res, "prune_contract_stub", not FileAccess.file_exists(path) and int(out.get("pruned", -1)) == 1,
		"out %s" % str(out))
	var stub_event := EventData.new()
	stub_event.event_name = "TEST Stale Event"
	var event_file: String = ContractResourceBuilder.event_path(stub_event.event_name)
	ResourceTextWriter.save(stub_event, event_file, "EventData", ContractResourceBuilder.EVENT_SCRIPT)
	var event_written: bool = FileAccess.file_exists(event_file)
	var again: Dictionary = ContractResourceBuilder.build_all()
	TestFixtures.check(res, "prune_event_stub", event_written and not FileAccess.file_exists(event_file)
		and int(again.get("pruned", -1)) == 1 and int(again.get("events", -1)) == _live_event_count(),
		"out %s" % str(again))
	_disk_end(builder_state)


static func _case_tres_text(res: Dictionary) -> void:
	var builder_state: Array = _disk_begin()
	ContractResourceBuilder.build_all()
	var text: String = FileAccess.get_file_as_string(ContractResourceBuilder.contract_path("Rescue"))
	_disk_end(builder_state)
	TestFixtures.check(res, "tres_contract_name", text.contains("\ncontract_name = \"Rescue\""),
		"%d characters" % text.length())
	var fields: Array[String] = []
	for field: String in ["level_min", "issuer_type", "difficulty_max", "story", "roles", "time_minutes", "consequence",
			"descriptions"]:
		if not text.contains("\n%s = " % field):
			fields.append(field)
	TestFixtures.check(res, "tres_new_fields", fields.is_empty(), "missing: %s" % ", ".join(fields))


#Writes off with the folders pointed at DISK_DIR: the build fills memory, creates no folder, and the library reads it.
static func _case_memory_build(res: Dictionary) -> void:
	var builder_state: Array = _disk_begin()
	ContractResourceBuilder.write_enabled = false
	var out: Dictionary = ContractResourceBuilder.build_all()
	var no_files: bool = not DirAccess.dir_exists_absolute(DISK_DIR)
	TestFixtures.check(res, "memory_build_no_files", no_files and int(out.get("pruned", -1)) == 0
		and ContractResourceBuilder.memory_contracts.size() == int(out.get("contracts", -1))
		and ContractResourceBuilder.memory_contracts.size() == _live_contract_count()
		and not ContractResourceBuilder.memory_events.is_empty(),
		"out %s, folder %s, %d held" % [str(out), "absent" if no_files else "present",
		ContractResourceBuilder.memory_contracts.size()])
	var rescue: ContractData = ContractLibrary.contract("Rescue")
	var held: ContractData = ContractResourceBuilder.memory_contracts.get("Rescue") as ContractData
	var events: Array[String] = ContractLibrary.event_names()
	TestFixtures.check(res, "memory_build_library", rescue != null and held != null and rescue != held
		and rescue.contract_type == held.contract_type and events.size() == ContractResourceBuilder.memory_events.size(),
		"Rescue %s, %d event names" % ["null" if rescue == null else rescue.contract_type, events.size()])
	_disk_end(builder_state)


#Points the builder at DISK_DIR with writes on; returns what _disk_end puts back.
static func _disk_begin() -> Array:
	var kept: Array = [ContractResourceBuilder.write_enabled, ContractResourceBuilder.contract_dir,
		ContractResourceBuilder.event_dir]
	ContractResourceBuilder.write_enabled = true
	ContractResourceBuilder.contract_dir = DISK_DIR + "/Contracts"
	ContractResourceBuilder.event_dir = DISK_DIR + "/Events"
	return kept


#Restores the builder, deletes DISK_DIR and rebuilds so the library reads the live rows again.
static func _disk_end(kept: Array) -> void:
	ContractResourceBuilder.write_enabled = bool(kept[0])
	ContractResourceBuilder.contract_dir = String(kept[1])
	ContractResourceBuilder.event_dir = String(kept[2])
	_remove_tree(DISK_DIR)
	ContractResourceBuilder.build_all()


static func _remove_tree(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	for sub: String in DirAccess.get_directories_at(dir_path):
		_remove_tree(dir_path + "/" + sub)
	for file_name: String in DirAccess.get_files_at(dir_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir_path + "/" + file_name))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir_path))


#DataManager loads the three tables as a fresh read of the live sheets does; the header widths are a format check.
static func _case_new_tables(res: Dictionary) -> void:
	var loaded: Array = [["checks_loaded", DataManager.check_rows, ContractBuilderData.CHECKS_PATH],
		["descriptions_loaded", DataManager.description_rows, ContractBuilderData.DESCRIPTIONS_PATH],
		["organizations_loaded", DataManager.organization_rows, ContractBuilderData.ORGANIZATIONS_PATH]]
	for item: Array in loaded:
		var held: int = (item[1] as Array).size()
		var fresh: int = TsvReader.load_header_rows(String(item[2])).size()
		TestFixtures.check(res, String(item[0]), held == fresh, "%d rows held, %d in the sheet" % [held, fresh])
	var cells: Array[String] = []
	for path: String in [ContractBuilderData.CHECKS_PATH, ContractBuilderData.DESCRIPTIONS_PATH,
			ContractBuilderData.ORGANIZATIONS_PATH]:
		var first: String = FileAccess.get_file_as_string(path).replace("\r", "").split("\n")[0]
		cells.append(str(first.split("\t").size()))
	TestFixtures.check(res, "new_tsv_headers", ", ".join(cells) == "11, 2, 3", "header cells %s" % ", ".join(cells))


static func _area_type(area_name: String) -> String:
	return String(DataManager.get_area_by_name(area_name).get("type", ""))


static func _case_areas(res: Dictionary) -> void:
	TestFixtures.check(res, "area_urban_city", _area_type("Urban") == "City", _area_type("Urban"))
	TestFixtures.check(res, "area_forest_tbd", _area_type("Forest") == "TBD", _area_type("Forest"))
	var missing: Array[String] = []
	var loaded: Array[String] = []
	for area_name: String in TBD_AREAS:
		if _area_type(area_name) != "TBD":
			missing.append(area_name)
			continue
		var area: Dictionary = DataManager.get_area_by_name(area_name)
		var weight: int = 0
		for w: Variant in area.get("weights", []) as Array:
			weight += int(w)
		if weight != 0 or not (area.get("environments", {}) as Dictionary).is_empty():
			loaded.append(area_name)
	TestFixtures.check(res, "area_tbd_all", missing.is_empty(), TestFixtures.detail(missing, TBD_AREAS.size(), "TBD names"))
	TestFixtures.check(res, "area_tbd_inert", loaded.is_empty(), TestFixtures.detail(loaded, TBD_AREAS.size(), "TBD rows"))
	TestFixtures.check(res, "area_tavern_interior", _area_type("Tavern") == "Interior", _area_type("Tavern"))
	var seen: Dictionary = {}
	var dups: Array[String] = []
	for area: Dictionary in DataManager.areas_pool:
		var area_name: String = String(area.get("name", ""))
		if seen.has(area_name):
			dups.append(area_name)
		seen[area_name] = true
	TestFixtures.check(res, "area_no_duplicates", dups.is_empty(),
		TestFixtures.detail(dups, DataManager.areas_pool.size(), "areas"))
	var urban: Dictionary = DataManager.get_area_by_name("Urban")
	var block: Dictionary = DataManager.get_area_by_name("City Block")
	var differ: Array[String] = []
	for key: Variant in block:
		if String(key) != "name" and String(key) != "row" and str(block[key]) != str(urban.get(key)):
			differ.append(String(key))
	TestFixtures.check(res, "area_urban_copies_city_block", not block.is_empty() and differ.is_empty(),
		"differs in %s" % ", ".join(differ))


static func _case_odds_allowed(res: Dictionary) -> void:
	var refused: Array[String] = []
	for area_name: String in ["Desert Plain", "Cavern", "Dungeon", "Urban", "City Block", "Tavern"]:
		if not ContractTerrain.odds_allowed(DataManager.get_area_by_name(area_name)):
			refused.append(area_name)
	TestFixtures.check(res, "odds_allowed_types", refused.is_empty(), "refused %s" % ", ".join(refused))
	TestFixtures.check(res, "odds_allowed_not_tbd", not ContractTerrain.odds_allowed(DataManager.get_area_by_name("Forest")),
		"Forest")
	var drawn: Array[String] = []
	for area_name: String in ["Urban", "City Block", "Tavern", "Forest"]:
		if ContractTerrain.drawable(DataManager.get_area_by_name(area_name)):
			drawn.append(area_name)
	var kept: bool = ContractTerrain.drawable(DataManager.get_area_by_name("Desert Plain")) \
		and ContractTerrain.drawable(DataManager.get_area_by_name("Cavern")) \
		and ContractTerrain.drawable(DataManager.get_area_by_name("Dungeon"))
	TestFixtures.check(res, "drawable_unchanged", drawn.is_empty() and kept, "drawable %s" % ", ".join(drawn))
	var listed: Array[String] = []
	for loc_name: String in DataManager.locations:
		var loc: LocationData = DataManager.locations[loc_name] as LocationData
		for entry: Dictionary in ContractTerrain.candidates(loc):
			if String((entry["area"] as Dictionary).get("type", "")) == "TBD":
				listed.append(loc_name)
	TestFixtures.check(res, "candidates_no_tbd", listed.is_empty(),
		TestFixtures.detail(listed, DataManager.locations.size(), "locations"))


#How many of DRAWS draws at loc land on area_name when the contract forces it at 100%.
static func _forced_hits(loc: LocationData, area_name: String) -> int:
	var contract := ContractData.new()
	contract.contract_type = "TEST Odds"
	var odds: Array[Dictionary] = [{"area": area_name, "percent": 100}]
	contract.terrain_odds = odds
	var hits: int = 0
	for _i: int in range(DRAWS):
		var picked: Dictionary = ContractTerrain.draw(loc, contract)
		if String((picked.get("area", {}) as Dictionary).get("name", "")) == area_name:
			hits += 1
	return hits


static func _case_draw(res: Dictionary) -> void:
	var loc: LocationData = DataManager.locations.get(ODDS_LOCATION, null) as LocationData
	if loc == null or not ContractTerrain.has_terrain(loc):
		TestFixtures.check(res, "draw_location", false, "%s is missing or has no terrain candidates" % ODDS_LOCATION)
		return
	var forest: int = _forced_hits(loc, "Forest")
	TestFixtures.check(res, "draw_skips_tbd", forest == 0, "%d of %d draws landed on Forest" % [forest, DRAWS])
	var urban: int = _forced_hits(loc, "Urban")
	TestFixtures.check(res, "draw_forces_city", urban == DRAWS, "%d of %d draws landed on Urban" % [urban, DRAWS])
	var tavern: int = _forced_hits(loc, "Tavern")
	TestFixtures.check(res, "draw_forces_interior", tavern == DRAWS, "%d of %d draws landed on Tavern" % [tavern, DRAWS])


static func _odds_warnings(cell: String) -> Array[String]:
	var out: Array[String] = []
	for text: String in _warnings_of({"Contract Name": "TEST Odds", "Contract Type": "Escort", "Terrain Odds": cell,
			"_row": 96}):
		if text.contains("column Terrain Odds"):
			out.append(text)
	return out


static func _case_odds_validator(res: Dictionary) -> void:
	var tbd: Array[String] = _odds_warnings("Forest 50")
	TestFixtures.check(res, "odds_tbd_silent", tbd.is_empty(), "; ".join(tbd))
	var unknown: Array[String] = _odds_warnings("Nowhere 50")
	TestFixtures.check(res, "odds_unknown_warns", unknown.size() == 1 and unknown[0].contains("unknown area Nowhere"),
		"; ".join(unknown))
	var forced: Array[String] = _odds_warnings("Urban 50, Tavern 25")
	TestFixtures.check(res, "odds_city_interior_silent", forced.is_empty(), "; ".join(forced))


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


#Copies the fourteen fixture sheets (SheetFixtures) to SCRATCH_DIR, points the ContractBuilderData path vars at the
#copies and runs body; the path vars end back at the res:// constants either way.
static func _scratch_case(res: Dictionary, label: String, body: Callable) -> void:
	var reason: String = _scratch_setup()
	if reason == "":
		body.call(res)
	else:
		TestFixtures.check(res, label + "_setup", false, reason)
	ContractBuilderData.reset_paths()


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
		push_error("BuilderTests: cannot write %s" % path)
		return false
	var stored: bool = bytes.is_empty() or file.store_buffer(bytes)
	file.close()
	return stored


static func _store_text(path: String, text: String) -> bool:
	return _store_bytes(path, text.to_utf8_buffer())


static func _bytes_of(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path)


static func _text_of(path: String) -> String:
	return FileAccess.get_file_as_bytes(path).get_string_from_utf8()


#A row of width blank cells whose first cell is first.
static func _cells(width: int, first: String) -> Array[String]:
	var out: Array[String] = []
	for i: int in range(width):
		out.append(first if i == 0 else "")
	return out


static func _joined(cells: Array[String]) -> String:
	return "\t".join(PackedStringArray(cells))


static func _result_text(result: Dictionary) -> String:
	return "ok %s, line %d, error %s" % [str(result.get("ok", false)), int(result.get("line", -1)),
		String(result.get("error", ""))]


static func _case_writer_append_lf(res: Dictionary) -> void:
	var path: String = ContractBuilderData.contracts_path
	var before: String = _text_of(path)
	var cells: Array[String] = _cells(39, "TEST Append")
	cells[1] = "Escort"
	var result: Dictionary = TsvRowWriter.append_row(path, cells)
	TestFixtures.check(res, "writer_append_lf_ok", bool(result["ok"]) and int(result["line"]) == 9, _result_text(result))
	var after: String = _text_of(path)
	TestFixtures.check(res, "writer_append_lf_text", after == before + "\n" + _joined(cells),
		"%d characters, was %d" % [after.length(), before.length()])
	TestFixtures.check(res, "writer_append_lf_ending", not after.ends_with("\n") and not after.contains("\r"),
		"%d LF, %d CR" % [after.count("\n"), after.count("\r")])
	var rows: Array[Dictionary] = TsvReader.load_header_rows(path)
	var last: String = String(rows[rows.size() - 1].get("Contract Name", "")) if not rows.is_empty() else ""
	TestFixtures.check(res, "writer_append_lf_rows", rows.size() == 9 and last == "TEST Append",
		"%d rows, last %s" % [rows.size(), last])


static func _case_writer_append_crlf(res: Dictionary) -> void:
	var path: String = ContractBuilderData.types_path
	var before: String = _text_of(path)
	var cells: Array[String] = _cells(33, "TEST Creature")
	var result: Dictionary = TsvRowWriter.append_row(path, cells)
	TestFixtures.check(res, "writer_append_crlf_ok", bool(result["ok"]) and int(result["line"]) == 37,
		_result_text(result))
	var after: String = _text_of(path)
	TestFixtures.check(res, "writer_append_crlf_text", after == before + "\r\n" + _joined(cells),
		"%d characters, was %d" % [after.length(), before.length()])
	TestFixtures.check(res, "writer_append_crlf_endings", after.count("\r\n") == 37 and after.count("\n") == 37
		and not after.ends_with("\n"), "%d CRLF, %d LF" % [after.count("\r\n"), after.count("\n")])


static func _case_writer_replace(res: Dictionary) -> void:
	var path: String = ContractBuilderData.contracts_path
	var before: PackedStringArray = _text_of(path).split("\n")
	var want: int = -1
	for i: int in range(1, before.size()):
		if before[i].get_slice("\t", 0) == "Rescue":
			want = i
			break
	var found: int = TsvRowWriter.find_row(path, 0, "Rescue")
	TestFixtures.check(res, "writer_find_row", want > 0 and found == want and TsvRowWriter.find_row(path, 0, "Nope") == -1
		and TsvRowWriter.find_row(path, 0, "") == -1, "Rescue at %d, sheet line %d" % [found, want])
	var cells: Array[String] = _cells(39, "Rescue")
	cells[1] = "Rescue"
	cells[38] = "TEST Consequence"
	var result: Dictionary = TsvRowWriter.replace_row(path, 0, "Rescue", cells)
	TestFixtures.check(res, "writer_replace_ok", bool(result["ok"]) and int(result["line"]) == want, _result_text(result))
	var after: PackedStringArray = _text_of(path).split("\n")
	var changed: Array[String] = []
	for i: int in range(mini(before.size(), after.size())):
		var expected: String = _joined(cells) if i == want else before[i]
		if after[i] != expected:
			changed.append("line %d" % i)
	TestFixtures.check(res, "writer_replace_lines", after.size() == before.size() and changed.is_empty(),
		"%d lines, was %d; %s" % [after.size(), before.size(), TestFixtures.detail(changed, after.size(), "lines off")])
	var bytes: PackedByteArray = _bytes_of(path)
	var miss: Dictionary = TsvRowWriter.replace_row(path, 0, "Nope", cells)
	TestFixtures.check(res, "writer_replace_missing", not bool(miss["ok"])
		and String(miss["error"]) == "no row whose column 0 is Nope" and _bytes_of(path) == bytes, _result_text(miss))


static func _case_writer_refuse(res: Dictionary) -> void:
	var path: String = ContractBuilderData.contracts_path
	var quoted: String = "say " + char(34) + "hi" + char(34)
	_refused(res, "writer_refuse_width", path, _cells(38, "Rescue"), "expected 39 cells, got 38")
	_refused(res, "writer_refuse_tab", path, _bad_row("a\tb"), "cell 2 holds a tab")
	_refused(res, "writer_refuse_quote", path, _bad_row(quoted), "cell 2 holds a double quote")
	_refused(res, "writer_refuse_cr", path, _bad_row("a\rb"), "cell 2 holds a CR")
	_refused(res, "writer_refuse_lf", path, _bad_row("a\nb"), "cell 2 holds an LF")
	_refused(res, "writer_refuse_ascii", path, _bad_row("caf" + char(233)),
		"cell 2 holds a character outside ASCII 32 to 126")
	_refused(res, "writer_refuse_control", path, _bad_row("a" + char(7)),
		"cell 2 holds a character outside ASCII 32 to 126")
	var odd: String = SCRATCH_DIR + "/odd.tsv"
	_table_refused(res, "writer_refuse_bare_cr", odd, "A\tB\rC\nx\ty".to_utf8_buffer(),
		"holds a CR outside a CRLF line ending")
	_table_refused(res, "writer_refuse_mixed", odd, "A\tB\r\nx\ty\nz\tw".to_utf8_buffer(),
		"mixes CRLF and LF line endings")
	_table_refused(res, "writer_refuse_empty", odd, PackedByteArray(), "has no header line")
	_table_refused(res, "writer_refuse_bom", odd, PackedByteArray([239, 187, 191]) + "A\tB".to_utf8_buffer(),
		"is not plain UTF-8 text")
	var missing: String = SCRATCH_DIR + "/missing.tsv"
	if FileAccess.file_exists(missing):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(missing))
	var lost: Dictionary = TsvRowWriter.append_row(missing, _cells(2, "x"))
	TestFixtures.check(res, "writer_refuse_missing", not bool(lost["ok"]) and String(lost["error"]).begins_with("cannot read")
		and TsvRowWriter.find_row(missing, 0, "x") == -1 and not FileAccess.file_exists(missing), _result_text(lost))


#A Contracts row keyed Rescue whose cell 2 holds text.
static func _bad_row(text: String) -> Array[String]:
	var cells: Array[String] = _cells(39, "Rescue")
	cells[2] = text
	return cells


#check_cells, append_row and replace_row all give reason and the file stays byte-identical.
static func _refused(res: Dictionary, label: String, path: String, cells: Array[String], reason: String) -> void:
	var bytes: PackedByteArray = _bytes_of(path)
	var checked: String = TsvRowWriter.check_cells(cells, int(TsvRowWriter.read_table(path)["width"]))
	var appended: Dictionary = TsvRowWriter.append_row(path, cells)
	var replaced: Dictionary = TsvRowWriter.replace_row(path, 0, "Rescue", cells)
	TestFixtures.check(res, label, checked == reason and not bool(appended["ok"]) and not bool(replaced["ok"])
		and String(appended["error"]) == reason and String(replaced["error"]) == reason and int(appended["line"]) == -1
		and _bytes_of(path) == bytes, "check %s; append %s; replace %s" % [checked, _result_text(appended),
		_result_text(replaced)])


#read_table refuses the file with a reason holding part; append_row and set_column_cell refuse it unchanged.
static func _table_refused(res: Dictionary, label: String, path: String, bytes: PackedByteArray, part: String) -> void:
	if not _store_bytes(path, bytes):
		TestFixtures.check(res, label, false, "cannot write %s" % path)
		return
	var table: Dictionary = TsvRowWriter.read_table(path)
	var appended: Dictionary = TsvRowWriter.append_row(path, _cells(2, "x"))
	var column: Dictionary = TsvRowWriter.set_column_cell(path, "A", "v")
	TestFixtures.check(res, label, not bool(table["ok"]) and String(table["error"]).contains(part)
		and not bool(appended["ok"]) and String(appended["error"]).contains(part) and not bool(column["ok"])
		and _bytes_of(path) == bytes, "read %s; append %s" % [String(table["error"]), _result_text(appended)])


static func _case_writer_column(res: Dictionary) -> void:
	var path: String = ContractBuilderData.types_path
	var title: String = ContractBuilderData.TYPES_COLUMN
	var before: PackedStringArray = _text_of(path).split("\r\n")
	var column: int = before[0].split("\t").find(title)
	var first: Dictionary = TsvRowWriter.set_column_cell(path, title, "Heist")
	TestFixtures.check(res, "writer_column_ok", bool(first["ok"]) and int(first["line"]) == 9, _result_text(first))
	var text: String = _text_of(path)
	var lines: PackedStringArray = text.split("\r\n")
	var changed: Array[String] = []
	for i: int in range(mini(before.size(), lines.size())):
		if i != 9 and lines[i] != before[i]:
			changed.append("line %d" % i)
	TestFixtures.check(res, "writer_column_lines", lines.size() == 37 and changed.is_empty() and text.count("\r\n") == 36
		and text.count("\n") == 36 and text.ends_with("\t"), "%d lines, %d CRLF, %d LF; %s" % [lines.size(),
		text.count("\r\n"), text.count("\n"), TestFixtures.detail(changed, lines.size(), "lines changed")])
	var cells: PackedStringArray = lines[9].split("\t") if lines.size() > 9 else PackedStringArray()
	var was: PackedStringArray = before[9].split("\t")
	var moved: Array[String] = []
	for c: int in range(mini(cells.size(), was.size())):
		if c != column and cells[c] != was[c]:
			moved.append("cell %d" % c)
	TestFixtures.check(res, "writer_column_cells", column == 17 and cells.size() == 33 and cells[column] == "Heist"
		and moved.is_empty(), "%d cells, column %d; %s" % [cells.size(), column, ", ".join(moved)])
	var second: Dictionary = TsvRowWriter.set_column_cell(path, title, "Smuggle")
	TestFixtures.check(res, "writer_column_second", bool(second["ok"]) and int(second["line"]) == 10,
		_result_text(second))
	var bytes: PackedByteArray = _bytes_of(path)
	var taken: Dictionary = TsvRowWriter.set_column_cell(path, title, "Rescue")
	TestFixtures.check(res, "writer_column_duplicate", not bool(taken["ok"])
		and String(taken["error"]) == "Rescue is already in column CONTRACT" and _bytes_of(path) == bytes,
		_result_text(taken))
	var refusals: Array[String] = []
	_column_refusal(refusals, path, title, "Heist", "Heist is already in column CONTRACT")
	_column_refusal(refusals, path, "NOPE", "Caper", "no column NOPE in Types.tsv")
	_column_refusal(refusals, path, title, "", "empty value")
	_column_refusal(refusals, path, title, "  ", "empty value")
	_column_refusal(refusals, path, title, "a\tb", "value holds a tab")
	_column_refusal(refusals, path, title, "say " + char(34) + "hi" + char(34), "value holds a double quote")
	_column_refusal(refusals, path, title, "caf" + char(233), "value holds a character outside ASCII 32 to 126")
	TestFixtures.check(res, "writer_column_refusals", refusals.is_empty() and _bytes_of(path) == bytes,
		"%d refusals off: %s" % [refusals.size(), "; ".join(refusals)])
	var misses: Array[String] = []
	for i: int in range(11, 37):
		var fill: Dictionary = TsvRowWriter.set_column_cell(path, title, "TEST Fill %d" % i)
		if not bool(fill["ok"]) or int(fill["line"]) != i:
			misses.append("value %d: %s" % [i, _result_text(fill)])
	TestFixtures.check(res, "writer_column_fill", misses.is_empty(), TestFixtures.detail(misses, 26, "fills missed"))
	var over: Dictionary = TsvRowWriter.set_column_cell(path, title, "TEST Overflow")
	var full: String = _text_of(path)
	var full_lines: PackedStringArray = full.split("\r\n")
	var expected: Array[String] = _cells(33, "")
	expected[17] = "TEST Overflow"
	TestFixtures.check(res, "writer_column_overflow", bool(over["ok"]) and int(over["line"]) == 37
		and full_lines.size() == 38 and full_lines[full_lines.size() - 1] == _joined(expected)
		and full.count("\r\n") == 37 and full.count("\n") == 37 and not full.ends_with("\n"),
		"%s; %d lines, %d CRLF" % [_result_text(over), full_lines.size(), full.count("\r\n")])
	TestFixtures.check(res, "writer_column_type_exists", ContractBuilderData.type_exists("Heist")
		and ContractBuilderData.contract_type_names().has("Smuggle"), "the redirected Types copy names Heist and Smuggle")
	var short: String = SCRATCH_DIR + "/short.tsv"
	var padded: Dictionary = {}
	if _store_text(short, "A\tB\tC\nx"):
		padded = TsvRowWriter.set_column_cell(short, "C", " v ")
	TestFixtures.check(res, "writer_column_pads", bool(padded.get("ok", false)) and int(padded.get("line", -1)) == 1
		and _text_of(short) == "A\tB\tC\nx\t\tv", "%s; %s" % [_result_text(padded), _text_of(short).c_escape()])


static func _column_refusal(out: Array[String], path: String, title: String, value: String, reason: String) -> void:
	var result: Dictionary = TsvRowWriter.set_column_cell(path, title, value)
	if bool(result["ok"]) or String(result["error"]) != reason:
		out.append("%s: %s" % [value.c_escape(), _result_text(result)])


static func _case_writer_orgs(res: Dictionary) -> void:
	var path: String = ContractBuilderData.organizations_path
	var cells: Array[String] = ["Guild of Lamps", "", ""]
	var result: Dictionary = TsvRowWriter.append_row(path, cells)
	TestFixtures.check(res, "writer_orgs_ok", bool(result["ok"]) and int(result["line"]) == 1, _result_text(result))
	var text: String = _text_of(path)
	TestFixtures.check(res, "writer_orgs_text", text == "Name\tType\tHome\nGuild of Lamps\t\t", text.c_escape())
	var names: Array[String] = ContractBuilderData.organization_names()
	TestFixtures.check(res, "writer_orgs_names", names.size() == 1 and names[0] == "Guild of Lamps"
		and ContractBuilderData.organization_exists("Guild of Lamps") and ContractBuilderData.issuer_options("org") == names,
		", ".join(names))


static func _case_draft_round_trip(res: Dictionary) -> void:
	var header: Array[String] = ContractBuilderData.header()
	var rows: Array[Dictionary] = ContractBuilderData.contract_rows()
	var bad: Array[String] = []
	for row: Dictionary in rows:
		var loaded: ContractDraft = ContractDraft.new()
		loaded.from_row(row)
		var loaded_cells: Array[String] = loaded.row_cells(header)
		for c: int in range(header.size()):
			var want: String = String(row.get(header[c], ""))
			var same: bool = loaded_cells[c] == want
			if LIST_COLUMNS.has(header[c]):
				same = TsvReader.split_field(loaded_cells[c]) == TsvReader.split_field(want)
			if not same:
				bad.append("%s %s: %s, want %s" % [loaded.contract_name, header[c], loaded_cells[c], want])
	TestFixtures.check(res, "draft_rows_round_trip", rows.size() == 8 and bad.is_empty(),
		"%d rows; %s" % [rows.size(), TestFixtures.detail(bad, rows.size() * header.size(), "cells differ")])
	var synthetic: Dictionary = _synthetic_row(header)
	var draft: ContractDraft = ContractDraft.new()
	draft.page = 2
	draft.from_row(synthetic)
	var cells: Array[String] = draft.row_cells(header)
	var off: Array[String] = []
	for c: int in range(header.size()):
		if cells[c] != String(synthetic[header[c]]):
			off.append("%s: %s, want %s" % [header[c], cells[c], String(synthetic[header[c]])])
	TestFixtures.check(res, "draft_synthetic_round_trip", header.size() == 39 and off.is_empty(),
		TestFixtures.detail(off, header.size(), "cells differ"))
	var fields: Array[String] = []
	if draft.level_min != 3 or draft.level_max != 40 or draft.time != 90:
		fields.append("levels %d to %d, time %d" % [draft.level_min, draft.level_max, draft.time])
	if not is_equal_approx(draft.difficulty_min, 1.5) or not is_equal_approx(draft.difficulty_max, 4.0):
		fields.append("difficulty %.2f to %.2f" % [draft.difficulty_min, draft.difficulty_max])
	if not draft.story or ", ".join(draft.roles) != "Driver, Guide" or ", ".join(draft.possible_traits) != "A, B":
		fields.append("story %s, roles %s, traits %s" % [str(draft.story), ", ".join(draft.roles),
			", ".join(draft.possible_traits)])
	if draft.boosts.size() != ContractDraft.BOOST_HEADERS.size() or draft.page != 2:
		fields.append("%d boosts, page %d" % [draft.boosts.size(), draft.page])
	TestFixtures.check(res, "draft_synthetic_fields", fields.is_empty(), "; ".join(fields))
	TestFixtures.check(res, "draft_source_name", draft.source_name == "TEST Synthetic" and not draft.is_new(),
		"source_name %s" % draft.source_name)
	var copy: ContractDraft = ContractDraft.new()
	copy.from_dict(draft.to_dict())
	TestFixtures.check(res, "draft_dict_source_name", copy.source_name == "TEST Synthetic"
		and copy.to_dict() == draft.to_dict(), "source_name %s" % copy.source_name)
	draft.clear()
	TestFixtures.check(res, "draft_clear_is_new", draft.is_new() and draft.source_name == "" and draft.contract_name == "",
		"source_name %s" % draft.source_name)
	var stored: bool = _store_text(ContractBuilderData.descriptions_path,
		"Contract Name\tDescription\nRescue\tFirst\nEscort\tOther\nRescue\t\nRescue\tSecond")
	var rescue: ContractDraft = ContractDraft.new()
	rescue.from_row(ContractBuilderData.contract_row("Rescue"))
	TestFixtures.check(res, "draft_descriptions", stored and ", ".join(rescue.descriptions) == "First, Second"
		and rescue.source_name == "Rescue", ", ".join(rescue.descriptions))


#Every column set: boosts and lists "A, B", numbers in the form ContractDraft writes back.
static func _synthetic_row(header: Array[String]) -> Dictionary:
	var row: Dictionary = {}
	for column: String in header:
		row[column] = "A, B"
	row["Contract Name"] = "TEST Synthetic"
	row["Contract Type"] = "Escort"
	row["Description Template"] = "Guard the %target% on the road to %location%"
	row["Target Category"] = "Cargo"
	row["Terrain Odds"] = "Urban 50, Tavern 25"
	row["Level Min"] = "3"
	row["Level Max"] = "40"
	row["Issuer Type"] = "person"
	row["Issuer"] = "Noble"
	row["Difficulty Min"] = "1.5"
	row["Difficulty Max"] = "4.0"
	row["Story"] = "TRUE"
	row["Style"] = "timeline"
	row["Roles"] = "Driver, Guide"
	row["Target"] = "Caravan"
	row["Completion"] = "Arrive"
	row["Event Config"] = "Ambush"
	row["Time"] = "90"
	row["Consequence"] = "Reputation"
	return row


static func _case_draft_template(res: Dictionary) -> void:
	var template: Dictionary = ContractBuilderData.template_row("Rescue")
	var draft: ContractDraft = ContractDraft.new()
	draft.from_row(_synthetic_row(ContractBuilderData.header()))
	draft.page = 3
	var before: Dictionary = draft.to_dict()
	draft.apply_template(template)
	var off: Array[String] = []
	for column: String in ContractDraft.BOOST_HEADERS + TEMPLATE_TEXT_COLUMNS:
		if draft.cell(column) != String(template.get(column, "")):
			off.append(column)
	for column: String in TEMPLATE_LIST_COLUMNS:
		if TsvReader.split_field(draft.cell(column)) != TsvReader.split_field(String(template.get(column, ""))):
			off.append(column)
	TestFixtures.check(res, "draft_template_copies", not template.is_empty() and off.is_empty(),
		"columns off: %s" % ", ".join(off))
	var kept: Array[String] = _changed_keys(before, draft.to_dict())
	TestFixtures.check(res, "draft_template_keeps", kept.is_empty(), "changed: %s" % ", ".join(kept))
	draft.apply_template({})
	var left: Array[String] = []
	for column: String in ContractDraft.BOOST_HEADERS + TEMPLATE_TEXT_COLUMNS:
		if draft.cell(column) != "":
			left.append(column)
	if not draft.possible_traits.is_empty() or not draft.possible_locations.is_empty():
		left.append("lists")
	left.append_array(_changed_keys(before, draft.to_dict()))
	TestFixtures.check(res, "draft_template_clears", left.is_empty(), "left or changed: %s" % ", ".join(left))


#to_dict keys outside TEMPLATE_KEYS whose value differs.
static func _changed_keys(before: Dictionary, after: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key: String in before.keys():
		if not TEMPLATE_KEYS.has(key) and before[key] != after.get(key):
			out.append(key)
	return out


static func _case_draft_name_length(res: Dictionary) -> void:
	var tagged: int = ContractDraft.name_length("Rescue %target%")
	TestFixtures.check(res, "draft_name_tagged", tagged == 7, "%d characters" % tagged)
	var tags_only: int = ContractDraft.name_length("%target%%location%%requestor%")
	TestFixtures.check(res, "draft_name_tags_only", tags_only == 0, "%d characters" % tags_only)
	var full: int = ContractDraft.name_length(FULL_NAME)
	TestFixtures.check(res, "draft_name_full", FULL_NAME.length() == ContractDraft.NAME_MAX
		and full == ContractDraft.NAME_MAX, "%d characters" % full)


static func _case_data_readers(res: Dictionary) -> void:
	SheetFixtures.point_at_fixtures()
	var people: Array[String] = ContractBuilderData.person_issuers()
	TestFixtures.check(res, "data_person_issuers", people == ContractDataValidator.PERSON_ISSUERS
		and ContractBuilderData.issuer_options("person") == people, ", ".join(people))
	var places: Array[String] = ContractBuilderData.place_names()
	var other_types: Array[String] = ["Domain", "Area"]
	var others: Array[String] = _location_names(other_types)
	var wrong: Array[String] = []
	for place: String in places:
		if place == "" or others.has(place):
			wrong.append(place)
	TestFixtures.check(res, "data_place_names", places.size() == 22 and wrong.is_empty() and not others.is_empty()
		and ContractBuilderData.issuer_options("place") == places, "%d places, %d Domain or Area names; wrong: %s"
		% [places.size(), others.size(), ", ".join(wrong)])
	var orgs: Array[String] = ContractBuilderData.organization_names()
	TestFixtures.check(res, "data_organizations_empty", orgs.is_empty() and ContractBuilderData.issuer_options("org") == orgs
		and not ContractBuilderData.organization_exists("Guild of Lamps"), "%d names" % orgs.size())
	TestFixtures.check(res, "data_issuer_unknown", ContractBuilderData.issuer_options("nope").is_empty()
		and ContractBuilderData.issuer_options("").is_empty(), "an unknown issuer type lists nothing")
	var template: Dictionary = ContractBuilderData.template_row("Rescue")
	TestFixtures.check(res, "data_template_row", String(template.get("Contract Type", "")) == "Rescue"
		and ContractBuilderData.template_row("Nope").is_empty(), "type %s" % String(template.get("Contract Type", "")))
	var named: Dictionary = ContractBuilderData.contract_row("Rescue")
	TestFixtures.check(res, "data_contract_row", ContractBuilderData.contract_row("Nope").is_empty()
		and String(named.get("Contract Name", "")) == "Rescue", "name %s" % String(named.get("Contract Name", "")))
	TestFixtures.check(res, "data_type_exists", ContractBuilderData.type_exists("Rescue")
		and not ContractBuilderData.type_exists("Heist") and not ContractBuilderData.type_exists("rescue")
		and not ContractBuilderData.type_exists(""), "only the exact Types.tsv names count")
	var lines: Array[String] = ContractBuilderData.descriptions_for("Rescue")
	TestFixtures.check(res, "data_descriptions_empty", lines.is_empty(), "%d lines" % lines.size())
	ContractBuilderData.contracts_path = SCRATCH_DIR + "/a.tsv"
	ContractBuilderData.types_path = SCRATCH_DIR + "/b.tsv"
	ContractBuilderData.organizations_path = SCRATCH_DIR + "/c.tsv"
	ContractBuilderData.locations_path = SCRATCH_DIR + "/d.tsv"
	ContractBuilderData.descriptions_path = SCRATCH_DIR + "/e.tsv"
	ContractBuilderData.reset_paths()
	var paths: Array[String] = [ContractBuilderData.contracts_path, ContractBuilderData.types_path,
		ContractBuilderData.organizations_path, ContractBuilderData.locations_path, ContractBuilderData.descriptions_path,
		ContractBuilderData.areas_path, ContractBuilderData.buildings_path, ContractBuilderData.npcs_path,
		ContractBuilderData.traditions_path, ContractBuilderData.checks_path, ContractBuilderData.stats_path,
		ContractBuilderData.circumstances_path, ContractBuilderData.knowledges_path, ContractBuilderData.events_path]
	TestFixtures.check(res, "data_reset_paths", paths == _sheet_paths(), ", ".join(paths))


#Locations.tsv names whose Location Type is one of types.
static func _location_names(types: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var rows: Array[PackedStringArray] = TsvReader.load_tsv(ContractBuilderData.locations_path)
	for i: int in range(1, rows.size()):
		if types.has(TsvReader.row_get(rows[i], ContractBuilderData.LOCATIONS_TYPE_COLUMN)):
			out.append(TsvReader.row_get(rows[i], ContractBuilderData.LOCATIONS_NAME_COLUMN))
	return out


static func _case_place_rows(res: Dictionary) -> void:
	SheetFixtures.point_at_fixtures()
	var rows: Array[Dictionary] = ContractBuilderData.place_rows()
	var names: Array[String] = _row_values(rows, "name")
	var types: Array[String] = _row_values(rows, "type")
	TestFixtures.check(res, "place_rows_count", rows.size() == 22, "%d rows" % rows.size())
	TestFixtures.check(res, "place_rows_nations", types.slice(0, 11).count("Country") == 11 and names[0] == "Aerdis"
		and names[10] == "Cyfrolaef", ", ".join(names.slice(0, 11)))
	TestFixtures.check(res, "place_rows_settlements", rows.size() == 22 and types.slice(11).count("Settlement") == 11
		and names[11] == "Cathistii" and names[21] == "Undercity", ", ".join(names.slice(11)))
	var repeats: Array[String] = _repeats(names)
	TestFixtures.check(res, "place_rows_distinct", repeats.is_empty(),
		TestFixtures.detail(repeats, names.size(), "names repeat"))
	var places: Array[String] = ContractBuilderData.place_names()
	TestFixtures.check(res, "place_rows_place_names", places.size() == 22, "%d names" % places.size())
	ContractBuilderData.reset_paths()


static func _case_area_rows(res: Dictionary) -> void:
	SheetFixtures.point_at_fixtures()
	var rows: Array[Dictionary] = ContractBuilderData.area_rows()
	var names: Array[String] = _row_values(rows, "name")
	var types: Array[String] = _row_values(rows, "type")
	TestFixtures.check(res, "area_rows_count", rows.size() == 42, "%d rows" % rows.size())
	var first: Dictionary = rows[0] if rows.size() > 0 else {}
	TestFixtures.check(res, "area_rows_first", first == {"name": "Desert Plain", "type": "Exterior"}, str(first))
	var off: Array[String] = []
	for pair: Array in [["Cavern", "Cavern"], ["Dungeon", "Dungeon"], ["Urban", "City"], ["Forest", "TBD"]]:
		var at: int = names.find(String(pair[0]))
		if at < 0 or types[at] != String(pair[1]):
			off.append("%s %s" % [String(pair[0]), "missing" if at < 0 else types[at]])
	TestFixtures.check(res, "area_rows_types", off.is_empty(), TestFixtures.detail(off, 4, "areas off"))
	var market: Dictionary = rows[16] if rows.size() > 16 else {}
	var last: Dictionary = rows[rows.size() - 1] if rows.size() > 0 else {}
	TestFixtures.check(res, "area_rows_buildings", market == {"name": "Market Stall", "type": "Interior"}
		and last == {"name": "Tavern", "type": "Interior"}, "row 17 %s, last %s" % [str(market), str(last)])
	var repeats: Array[String] = _repeats(names)
	TestFixtures.check(res, "area_rows_distinct", repeats.is_empty(),
		TestFixtures.detail(repeats, names.size(), "names repeat"))
	var odd: Array[String] = []
	for i: int in range(rows.size()):
		if not AREA_ROW_TYPES.has(types[i]):
			odd.append("%s %s" % [names[i], types[i]])
	TestFixtures.check(res, "area_rows_known_types", odd.is_empty(),
		TestFixtures.detail(odd, rows.size(), "rows of another type"))
	ContractBuilderData.reset_paths()


static func _case_reset_paths(res: Dictionary) -> void:
	ContractBuilderData.areas_path = "user://x.tsv"
	ContractBuilderData.buildings_path = "user://x.tsv"
	ContractBuilderData.npcs_path = "user://x.tsv"
	ContractBuilderData.traditions_path = "user://x.tsv"
	ContractBuilderData.checks_path = "user://x.tsv"
	ContractBuilderData.stats_path = "user://x.tsv"
	ContractBuilderData.circumstances_path = "user://x.tsv"
	ContractBuilderData.knowledges_path = "user://x.tsv"
	ContractBuilderData.reset_paths()
	TestFixtures.check(res, "reset_paths_areas_buildings", ContractBuilderData.areas_path == ContractBuilderData.AREAS_PATH
		and ContractBuilderData.buildings_path == ContractBuilderData.BUILDINGS_PATH,
		"%s, %s" % [ContractBuilderData.areas_path, ContractBuilderData.buildings_path])
	TestFixtures.check(res, "reset_paths_npcs_traditions", ContractBuilderData.npcs_path == ContractBuilderData.NPCS_PATH
		and ContractBuilderData.traditions_path == ContractBuilderData.TRADITIONS_PATH,
		"%s, %s" % [ContractBuilderData.npcs_path, ContractBuilderData.traditions_path])
	var sheets: Array[String] = [ContractBuilderData.checks_path, ContractBuilderData.stats_path,
		ContractBuilderData.circumstances_path, ContractBuilderData.knowledges_path]
	var want: Array[String] = [ContractBuilderData.CHECKS_PATH, ContractBuilderData.STATS_PATH,
		ContractBuilderData.CIRCUMSTANCES_PATH, ContractBuilderData.KNOWLEDGES_PATH]
	TestFixtures.check(res, "reset_paths_checks_sheets", sheets == want, ", ".join(sheets))


#A duplicate Taverngoer line and a copy of it with the Title cell blanked add no title. TsvReader drops a line whose
#column 0 is blank, so a sheet with Title in column 1 tests the blank skip. The copy is put back after.
static func _case_data_npc_titles(res: Dictionary) -> void:
	var want: Array[String] = ["Taverngoer", "Bandit Melee", "Bandit Ranged", "Bandit Leader"]
	var titles: Array[String] = ContractBuilderData.npc_titles()
	TestFixtures.check(res, "data_npc_titles", titles == want, ", ".join(titles))
	var path: String = ContractBuilderData.npcs_path
	var bytes: PackedByteArray = _bytes_of(path)
	var text: String = _text_of(path)
	var eol: String = "\r\n" if text.contains("\r\n") else "\n"
	var lines: PackedStringArray = text.replace("\r", "").split("\n")
	var column: int = lines[0].split("\t").find(ContractBuilderData.NPCS_TITLE_COLUMN)
	var first: String = lines[1] if lines.size() > 1 else ""
	var blanked: PackedStringArray = first.split("\t")
	if column >= 0 and column < blanked.size():
		blanked[column] = ""
	var stored: bool = _store_text(path, text + eol + first + eol + "\t".join(blanked))
	var again: Array[String] = ContractBuilderData.npc_titles()
	var rows: int = TsvReader.load_tsv(path).size()
	TestFixtures.check(res, "data_npc_titles_distinct", stored and column >= 0 and rows == lines.size() + 2
		and again == want, "column %d, %d rows; %s" % [column, rows, ", ".join(again)])
	var keyed: Array[String] = ["Taverngoer"]
	stored = _store_text(path, "Key\tTitle\r\nk1\tTaverngoer\r\nk2\t \r\nk3\tTaverngoer")
	var second: Array[String] = ContractBuilderData.npc_titles()
	TestFixtures.check(res, "data_npc_titles_blank_title", stored and second == keyed, ", ".join(second))
	TestFixtures.check(res, "data_npc_titles_restore", _store_bytes(path, bytes) and _bytes_of(path) == bytes
		and ContractBuilderData.npc_titles() == want, "%d bytes" % _bytes_of(path).size())


static func _case_data_creature_types(res: Dictionary) -> void:
	SheetFixtures.point_at_fixtures()
	var want: Array[String] = ["Assembly", "Beast", "Daemon", "Elemental", "Ethereal", "Fey", "Hominid", "Immortal",
		"Mire", "Myth", "Plant", "Undead"]
	var types: Array[String] = ContractBuilderData.creature_types()
	var ends: bool = types.size() == 12 and types[0] == "Assembly" and types[11] == "Undead"
	TestFixtures.check(res, "data_creature_types", ends and _repeats(types).is_empty() and types == want,
		", ".join(types))
	ContractBuilderData.reset_paths()


static func _case_data_tradition_names(res: Dictionary) -> void:
	SheetFixtures.point_at_fixtures()
	var want: Array[String] = ["Brave", "Chymist", "Divine", "Hellion", "Honorable", "Mage", "Mystech", "Performer",
		"Sorcerer", "Warrior"]
	var names: Array[String] = ContractBuilderData.tradition_names()
	TestFixtures.check(res, "data_tradition_names", names == want, ", ".join(names))
	ContractBuilderData.reset_paths()


static func _rows_ok(result: Dictionary, removed: int, line: int) -> bool:
	return bool(result["ok"]) and int(result.get("removed", -1)) == removed and int(result["line"]) == line


static func _rows_text(result: Dictionary) -> String:
	return "%s, removed %d" % [_result_text(result), int(result.get("removed", -1))]


static func _case_writer_replace_rows_lf(res: Dictionary) -> void:
	var path: String = ContractBuilderData.descriptions_path
	var header: String = "Contract Name\tDescription"
	var keys: Array[String] = ["Lamp Run"]
	var two: Array[PackedStringArray] = [PackedStringArray(["Lamp Run", "A"]), PackedStringArray(["Lamp Run", "B"])]
	var added: Dictionary = TsvRowWriter.replace_rows(path, 0, keys, two)
	TestFixtures.check(res, "writer_replace_rows_lf_add", _rows_ok(added, 0, 1)
		and _bytes_of(path) == (header + "\nLamp Run\tA\nLamp Run\tB").to_ascii_buffer(), _rows_text(added))
	var one: Array[PackedStringArray] = [PackedStringArray(["Lamp Run", "C"])]
	var replaced: Dictionary = TsvRowWriter.replace_rows(path, 0, keys, one)
	TestFixtures.check(res, "writer_replace_rows_lf_replace", _rows_ok(replaced, 2, 1)
		and _bytes_of(path) == (header + "\nLamp Run\tC").to_ascii_buffer(), _rows_text(replaced))
	var none: Array[PackedStringArray] = []
	var removed: Dictionary = TsvRowWriter.replace_rows(path, 0, keys, none)
	TestFixtures.check(res, "writer_replace_rows_lf_remove", _rows_ok(removed, 1, -1)
		and _bytes_of(path) == header.to_ascii_buffer(), _rows_text(removed))
	var nobody: Array[String] = ["Nobody"]
	var nothing: Dictionary = TsvRowWriter.replace_rows(path, 0, nobody, none)
	TestFixtures.check(res, "writer_replace_rows_lf_nothing", _rows_ok(nothing, 0, -1)
		and _bytes_of(path) == header.to_ascii_buffer(), _rows_text(nothing))


static func _case_writer_replace_rows_crlf(res: Dictionary) -> void:
	var path: String = SCRATCH_DIR + "/rows_crlf.tsv"
	if not _store_text(path, "H1\tH2\r\nx\t1\r\ny\t2\r\nx\t3"):
		TestFixtures.check(res, "writer_replace_rows_crlf_setup", false, "cannot write %s" % path)
		return
	var x: Array[String] = ["x"]
	var nine: Array[PackedStringArray] = [PackedStringArray(["x", "9"])]
	var first: Dictionary = TsvRowWriter.replace_rows(path, 0, x, nine)
	TestFixtures.check(res, "writer_replace_rows_crlf_first", _rows_ok(first, 2, 1)
		and _bytes_of(path) == "H1\tH2\r\nx\t9\r\ny\t2".to_ascii_buffer(), _rows_text(first))
	var y: Array[String] = ["y"]
	var pair: Array[PackedStringArray] = [PackedStringArray(["y", "7"]), PackedStringArray(["z", "8"])]
	var second: Dictionary = TsvRowWriter.replace_rows(path, 0, y, pair)
	TestFixtures.check(res, "writer_replace_rows_crlf_second", _rows_ok(second, 1, 2)
		and _bytes_of(path) == "H1\tH2\r\nx\t9\r\ny\t7\r\nz\t8".to_ascii_buffer(), _rows_text(second))


#The CRLF shape plus a line whose key cell is blank, which the blank key must leave alone.
static func _case_writer_replace_rows_keys(res: Dictionary) -> void:
	var path: String = SCRATCH_DIR + "/rows_keys.tsv"
	var none: Array[PackedStringArray] = []
	var blank_and_x: Array[String] = ["", "x"]
	var stored: bool = _store_text(path, "H1\tH2\r\nx\t1\r\ny\t2\r\nx\t3\r\n\t4")
	var blank: Dictionary = TsvRowWriter.replace_rows(path, 0, blank_and_x, none)
	TestFixtures.check(res, "writer_replace_rows_keys_blank", stored and _rows_ok(blank, 2, -1)
		and _bytes_of(path) == "H1\tH2\r\ny\t2\r\n\t4".to_ascii_buffer(), _rows_text(blank))
	var padded: Array[String] = [" x "]
	stored = _store_text(path, "H1\tH2\r\nx\t1\r\ny\t2")
	var trimmed: Dictionary = TsvRowWriter.replace_rows(path, 0, padded, none)
	TestFixtures.check(res, "writer_replace_rows_keys_trim", stored and _rows_ok(trimmed, 1, -1)
		and _bytes_of(path) == "H1\tH2\r\ny\t2".to_ascii_buffer(), _rows_text(trimmed))


#A bad row after a good one refuses the whole call and the file keeps its bytes.
static func _case_writer_replace_rows_refuse(res: Dictionary) -> void:
	var path: String = SCRATCH_DIR + "/rows_refuse.tsv"
	var shape: String = "H1\tH2\r\nx\t1\r\ny\t2\r\nx\t3"
	var keys: Array[String] = ["x"]
	var cases: Array = [["ascii", PackedStringArray(["x", "caf" + char(233)])],
		["tab", PackedStringArray(["x", "a\tb"])], ["width", PackedStringArray(["x", "1", "2"])]]
	for item: Array in cases:
		var stored: bool = _store_text(path, shape)
		var rows: Array[PackedStringArray] = [PackedStringArray(["x", "fine"]), item[1] as PackedStringArray]
		var refused: Dictionary = TsvRowWriter.replace_rows(path, 0, keys, rows)
		TestFixtures.check(res, "writer_replace_rows_refuse_" + String(item[0]), stored and not bool(refused["ok"])
			and String(refused["error"]) != "" and int(refused["line"]) == -1 and int(refused["removed"]) == 0
			and _bytes_of(path) == shape.to_ascii_buffer(), _rows_text(refused))


#Game mode, so _apply takes the PixelSlider path; the slider never enters the tree.
static func _case_pixel_slider(res: Dictionary) -> void:
	var slider: ToolPixelSlider = ToolPixelSlider.make()
	TestFixtures.check(res, "pixel_slider_make", slider.custom_minimum_size == Vector2(120, 21)
		and slider.size_flags_horizontal == Control.SIZE_EXPAND_FILL and slider.mouse_filter == Control.MOUSE_FILTER_PASS,
		"size %s, flags %d, mouse %d" % [str(slider.custom_minimum_size), slider.size_flags_horizontal, slider.mouse_filter])
	slider.min_value = 1.0
	slider.max_value = 100.0
	var heard: Array[float] = []
	slider.value_changed.connect(func(v: float) -> void: heard.append(v))
	slider._apply(15.0)
	TestFixtures.check(res, "pixel_slider_apply", heard.size() == 1 and is_equal_approx(heard[0], 15.0)
		and is_equal_approx(slider.value, 15.0), "value %.1f, heard %s" % [slider.value, str(heard)])
	slider.set_value_silent(40.0)
	TestFixtures.check(res, "pixel_slider_silent", heard.size() == 1 and is_equal_approx(slider.value, 40.0),
		"value %.1f, heard %s" % [slider.value, str(heard)])
	slider.free()


static func _row_values(rows: Array[Dictionary], key: String) -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in rows:
		out.append(String(row.get(key, "")))
	return out


static func _repeats(values: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for i: int in range(values.size()):
		if values.find(values[i]) < i:
			out.append(values[i])
	return out


#A draft check() passes: a new Escort contract with every field page 1 requires and a Completion naming CHECK_NAME,
#with no pending check row.
static func _writer_draft(title: String) -> ContractDraft:
	var draft: ContractDraft = ContractDraft.new()
	draft.contract_name = title
	draft.contract_type = "Escort"
	draft.issuer_type = "person"
	draft.issuer = "Noble"
	draft.style = "check"
	draft.completion = "check:" + CHECK_NAME
	draft.level_min = 0
	draft.level_max = 240
	draft.difficulty_min = 0.5
	draft.difficulty_max = 5.0
	return draft


static func _written_text(written: Dictionary) -> String:
	return "ok %s, line %d, replaced %s, new_type %s, new_org %s, error %s" % [str(written.get("ok", false)),
		int(written.get("line", -1)), str(written.get("replaced", false)), str(written.get("new_type", false)),
		str(written.get("new_org", false)), String(written.get("error", ""))]


#The lines of after that differ from before, where line want must read row instead.
static func _lines_off(before: PackedStringArray, after: PackedStringArray, want: int, row: String) -> Array[String]:
	var off: Array[String] = []
	if after.size() != before.size():
		off.append("%d lines, was %d" % [after.size(), before.size()])
		return off
	for i: int in range(after.size()):
		var expected: String = row if i == want else before[i]
		if after[i] != expected:
			off.append("line %d" % i)
	return off


static func _case_row_writer_check(res: Dictionary) -> void:
	var blank: String = ContractRowWriter.check(ContractDraft.new())
	TestFixtures.check(res, "row_writer_check_blank", blank == ContractRowWriter.NAME_EMPTY, blank)
	var draft: ContractDraft = _writer_draft("Caravan Watch")
	var reason: String = ContractRowWriter.check(draft)
	TestFixtures.check(res, "row_writer_check_pass", reason == "", reason)
	var missed: Array[String] = []
	for title: String in ["Rescue", "Res'cue", "rescue", " Rescue "]:
		draft.contract_name = title
		reason = ContractRowWriter.check(draft)
		if not reason.ends_with("the row Rescue"):
			missed.append("%s: %s" % [title, reason])
	TestFixtures.check(res, "row_writer_check_collision", missed.is_empty(), TestFixtures.detail(missed, 4, "names pass"))
	draft.contract_name = "Rescue"
	draft.source_name = "Rescue"
	reason = ContractRowWriter.check(draft)
	TestFixtures.check(res, "row_writer_check_source", reason == "", reason)
	draft.source_name = "Escort"
	reason = ContractRowWriter.check(draft)
	TestFixtures.check(res, "row_writer_check_other_source", reason.ends_with("the row Rescue"), reason)
	var quoted: String = "say " + char(34) + "hi" + char(34)
	var cases: Array = [["contract_name", FULL_NAME + "x", "Contract Name is 25 characters; the limit is 24"],
		["contract_type", " ", ContractRowWriter.TYPE_EMPTY],
		["issuer_type", "guild", "Issuer Type must be person, place or org"],
		["issuer", " ", ContractRowWriter.ISSUER_EMPTY],
		["style", "", "Style must be check, event or timeline"],
		["level_min", 241, "Level Min 241 is above Level Max 240"],
		["difficulty_min", 5.5, "Difficulty Min 5.5 is above Difficulty Max 5.0"],
		["description_template", quoted, "Description Template holds a double quote"]]
	var wrong: Array[String] = []
	for item: Array in cases:
		var broken: ContractDraft = _writer_draft("Caravan Watch")
		broken.set(StringName(String(item[0])), item[1])
		var got: String = ContractRowWriter.check(broken)
		if got != String(item[2]):
			wrong.append("%s: %s" % [String(item[0]), got])
	TestFixtures.check(res, "row_writer_check_reasons", wrong.is_empty(),
		TestFixtures.detail(wrong, cases.size(), "reasons off"))
	var file_off: Array[String] = []
	var forbidden: String = "\\/:*?<>|"
	for i: int in range(forbidden.length()):
		var refused: ContractDraft = _writer_draft("Hunt%sWolves" % forbidden[i])
		var got: String = ContractRowWriter.check(refused)
		if got != "Contract Name holds %s, which a file name cannot hold" % forbidden[i]:
			file_off.append("%s: %s" % [refused.contract_name, got])
	for title: String in ["Con", "C'on", "nul", "Aux.Two", "COM0", "lpt9"]:
		var got: String = ContractRowWriter.check(_writer_draft(title))
		if not got.ends_with("which Windows reserves"):
			file_off.append("%s: %s" % [title, got])
	for title: String in ["Console", "COM10", "Mr. Fox", "Null"]:
		var got: String = ContractRowWriter.check(_writer_draft(title))
		if got != "":
			file_off.append("%s: %s" % [title, got])
	TestFixtures.check(res, "row_writer_check_file_name", file_off.is_empty(),
		TestFixtures.detail(file_off, 18, "names off"))


#Card 285: the row writer refuses a merc end outside 1..5 and Min Mercs above Max Mercs; 0 is a blank cell.
static func _case_row_writer_mercs(res: Dictionary) -> void:
	var cases: Array = [["solo", 1, 1, ""], ["range", 2, 5, ""], ["blank", 0, 0, ""],
		["min_above_max", 4, 2, "Min Mercs 4 is above Max Mercs 2"], ["min_above_default", 4, 0, "Min Mercs 4 is above Max Mercs 3"],
		["max_7", 0, 7, "Max Mercs must be 1 to 5, got 7"],
		["min_7", 7, 0, "Min Mercs must be 1 to 5, got 7"], ["min_negative", -1, 3, "Min Mercs must be 1 to 5, got -1"]]
	for item: Array in cases:
		var draft: ContractDraft = _writer_draft("Caravan Watch")
		draft.merc_min = int(item[1])
		draft.merc_max = int(item[2])
		var got: String = ContractRowWriter.check(draft)
		TestFixtures.check(res, "card285_row_writer_mercs_" + String(item[0]), got == String(item[3]), got)


#Card 285: Min Mercs and Max Mercs survive from_row, cell, to_dict and from_dict; a 0 writes a blank cell.
static func _case_draft_mercs(res: Dictionary) -> void:
	var draft: ContractDraft = ContractDraft.new()
	draft.from_row({"Contract Name": "TEST Mercs", "Min Mercs": "2", "Max Mercs": "4"})
	var header: Array[String] = ["Contract Name", "Min Mercs", "Max Mercs"]
	var cells: Array[String] = draft.row_cells(header)
	var copy: ContractDraft = ContractDraft.new()
	copy.from_dict(draft.to_dict())
	var blank: Array[String] = ContractDraft.new().row_cells(header)
	TestFixtures.check(res, "card285_draft_round_trip", ", ".join(cells) == "TEST Mercs, 2, 4" and copy.merc_min == 2
		and copy.merc_max == 4 and blank[1] == "" and blank[2] == "",
		"cells %s, copy %d to %d" % [", ".join(cells), copy.merc_min, copy.merc_max])


#Card 736: Local survives from_row, cell, to_dict and from_dict; TRUE in any case sets it, anything else clears it.
static func _case_draft_local(res: Dictionary) -> void:
	var draft: ContractDraft = ContractDraft.new()
	draft.from_row({"Contract Name": "TEST Local", "Local": " true "})
	var header: Array[String] = ["Contract Name", "Local"]
	var cells: Array[String] = draft.row_cells(header)
	var copy: ContractDraft = ContractDraft.new()
	copy.from_dict(draft.to_dict())
	var off: Array[String] = []
	for raw: String in ["", "FALSE", "yes"]:
		var other: ContractDraft = ContractDraft.new()
		other.from_row({"Contract Name": "TEST Away", "Local": raw})
		if other.local or other.row_cells(header)[1] != "":
			off.append(raw)
	TestFixtures.check(res, "card736_draft_local_round_trip", draft.local and ", ".join(cells) == "TEST Local, TRUE"
		and copy.local and bool(draft.to_dict()["local"]) and off.is_empty(),
		"cells %s, copy %s, off %s" % [", ".join(cells), str(copy.local), ", ".join(PackedStringArray(off))])


#Card 736: on a 42 column sheet the row writer puts TRUE in the Local column for a local draft and leaves it blank
#otherwise. The scratch fixture has 39 columns, so its header gains the three tail columns first.
static func _case_row_writer_local(res: Dictionary) -> void:
	var path: String = ContractBuilderData.contracts_path
	var lines: PackedStringArray = _text_of(path).split("\n")
	lines[0] += "\tMin Mercs\tMax Mercs\tLocal"
	var stored: bool = _store_text(path, "\n".join(lines))
	var header: Array[String] = ContractBuilderData.header()
	TestFixtures.check(res, "card736_row_writer_local_header", stored and header.size() == 42
		and header[41] == "Local", "%d cells, stored %s" % [header.size(), str(stored)])
	var near: ContractDraft = _writer_draft("Caravan Watch")
	near.local = true
	var away: ContractDraft = _writer_draft("Lamp Watch")
	var first: Dictionary = ContractRowWriter.write(near)
	var second: Dictionary = ContractRowWriter.write(away)
	var rows: PackedStringArray = _text_of(path).split("\n")
	var near_cells: PackedStringArray = rows[int(first["line"])].split("\t") if bool(first["ok"]) else PackedStringArray()
	var away_cells: PackedStringArray = rows[int(second["line"])].split("\t") if bool(second["ok"]) else PackedStringArray()
	TestFixtures.check(res, "card736_row_writer_local_true", near_cells.size() == 42 and near_cells[41] == "TRUE"
		and near_cells[0] == "Caravan Watch", "%s; %d cells" % [_written_text(first), near_cells.size()])
	TestFixtures.check(res, "card736_row_writer_local_blank", away_cells.size() == 42 and away_cells[41] == ""
		and away_cells[0] == "Lamp Watch", "%s; %d cells" % [_written_text(second), away_cells.size()])


#Card 745: HelpRowsAuthor writes five Cat-copy rows, their checks and descriptions, then skips them all on a rerun.
#The scratch Types.tsv gains Help first, as the live sheet has it, so the writer adds no type.
static func _case_help_rows_author(res: Dictionary) -> void:
	var path: String = ContractBuilderData.contracts_path
	var lines: PackedStringArray = _text_of(path).split("\n")
	lines[0] += "\tMin Mercs\tMax Mercs\tLocal"
	var stored: bool = _store_text(path, "\n".join(lines))
	var typed: Dictionary = TsvRowWriter.set_column_cell(ContractBuilderData.types_path,
		ContractBuilderData.TYPES_COLUMN, "Help")
	var header: Array[String] = ContractBuilderData.header()
	TestFixtures.check(res, "card745_help_setup", stored and bool(typed["ok"]) and header.size() == 42,
		"stored %s, typed %s, %d header cells" % [str(stored), str(typed["ok"]), header.size()])
	var watched: Array[String] = [path, ContractBuilderData.checks_path, ContractBuilderData.descriptions_path,
		ContractBuilderData.types_path, ContractBuilderData.organizations_path]
	var before: Array[PackedByteArray] = []
	for sheet: String in watched:
		before.append(_bytes_of(sheet))
	var rows_before: int = _text_of(path).split("\n").size()
	var checks_before: int = _text_of(ContractBuilderData.checks_path).split("\n").size()
	var descriptions_before: int = _text_of(ContractBuilderData.descriptions_path).split("\n").size()
	var records: Array[Dictionary] = HelpRowsAuthor.author()
	var bad: Array[String] = []
	for record: Dictionary in records:
		if not bool(record["ok"]) or not bool(record["check"]) or bool(record["exists"]):
			bad.append("%s %s" % [String(record["name"]), String(record["error"])])
	TestFixtures.check(res, "card745_help_records", records.size() == 5 and bad.is_empty(),
		"%d records; off %s" % [records.size(), "; ".join(PackedStringArray(bad))])
	var after: PackedStringArray = _text_of(path).split("\n")
	var want: Array[String] = _help_expected_cells(header)
	var completion: int = header.find("Completion")
	var off: Array[String] = []
	var completions: Array[String] = []
	for i: int in range(rows_before, after.size()):
		var cells: PackedStringArray = after[i].split("\t")
		if cells.size() != 42:
			off.append("line %d has %d cells" % [i, cells.size()])
			continue
		completions.append(cells[completion].trim_prefix(ContractRowWriter.CHECK_PREFIX))
		for c: int in range(42):
			if c != 0 and c != completion and cells[c] != want[c]:
				off.append("line %d %s %s" % [i, header[c], cells[c]])
	TestFixtures.check(res, "card745_help_contract_rows", after.size() == rows_before + 5 and off.is_empty(),
		"%d lines, was %d; %s" % [after.size(), rows_before, "; ".join(PackedStringArray(off))])
	var cat: Dictionary = {}
	for row: Dictionary in TsvReader.load_header_rows(ContractBuilderData.CONTRACTS_PATH):
		if String(row.get("Contract Name", "")) == "Cat Stuck in Tree!":
			cat = row
	var cat_off: Array[String] = []
	for c: int in range(42):
		if not cat.is_empty() and c != 0 and c != completion and String(cat.get(header[c], "")).strip_edges() != want[c]:
			cat_off.append(header[c])
	TestFixtures.check(res, "card745_help_matches_cat", not cat.is_empty() and cat_off.is_empty(),
		"live Cat row %s; differs at %s" % ["found" if not cat.is_empty() else "absent", ", ".join(PackedStringArray(cat_off))])
	var checks: PackedStringArray = _text_of(ContractBuilderData.checks_path).split("\n")
	var names: Array[String] = []
	var widths: Array[int] = []
	for i: int in range(checks_before, checks.size()):
		var cells: PackedStringArray = checks[i].split("\t")
		names.append(cells[0])
		widths.append(cells.size())
	TestFixtures.check(res, "card745_help_check_rows", checks.size() == checks_before + 5
		and widths.count(CheckSheet.WIDTH) == 5 and names == completions,
		"names %s, completions %s" % [", ".join(PackedStringArray(names)), ", ".join(PackedStringArray(completions))])
	var descriptions: int = _text_of(ContractBuilderData.descriptions_path).split("\n").size()
	TestFixtures.check(res, "card745_help_descriptions", descriptions == descriptions_before + 10,
		"%d lines, was %d" % [descriptions, descriptions_before])
	TestFixtures.check(res, "card745_help_other_sheets", _bytes_of(watched[3]) == before[3]
		and _bytes_of(watched[4]) == before[4], "the Types and Organizations copies keep their bytes")
	var written: Array[PackedByteArray] = []
	for sheet: String in watched:
		written.append(_bytes_of(sheet))
	var again: Array[Dictionary] = HelpRowsAuthor.author()
	var fresh: int = again.filter(func(r: Dictionary) -> bool: return not bool(r["exists"])).size()
	var changed: Array[String] = []
	for k: int in range(watched.size()):
		if _bytes_of(watched[k]) != written[k]:
			changed.append(watched[k].get_file())
	TestFixtures.check(res, "card745_help_rerun_exists", again.size() == 5 and fresh == 0 and changed.is_empty(),
		"%d records, %d not existing, changed %s" % [again.size(), fresh, ", ".join(PackedStringArray(changed))])


#The Cat Stuck in Tree! row cells every Help row repeats; Contract Name and Completion are left blank.
static func _help_expected_cells(header: Array[String]) -> Array[String]:
	var known: Dictionary = {"Contract Type": "Help", "Possible Locations": ", ".join(PackedStringArray(
		HelpRowsAuthor.LOCATIONS)), "Terrain Odds": "Urban 70, Forest 30", "Level Max": "4", "Issuer Type": "person",
		"Issuer": "Commoner", "Difficulty Min": "0.5", "Difficulty Max": "0.5", "Style": "check", "Min Mercs": "1",
		"Max Mercs": "1", "Local": "TRUE"}
	var out: Array[String] = []
	for column: String in header:
		out.append(String(known.get(column, "")))
	return out


static func _case_row_writer_append(res: Dictionary) -> void:
	var path: String = ContractBuilderData.contracts_path
	var header: Array[String] = ContractBuilderData.header()
	var draft: ContractDraft = _writer_draft("Caravan Watch")
	var written: Dictionary = ContractRowWriter.write(draft)
	TestFixtures.check(res, "row_writer_append_ok", bool(written["ok"]) and int(written["line"]) == 9
		and not bool(written["replaced"]) and not bool(written["new_type"]) and not bool(written["new_org"])
		and String(written["name"]) == "Caravan Watch", _written_text(written))
	var lines: PackedStringArray = _text_of(path).split("\n")
	var rows: int = ContractBuilderData.contract_rows().size()
	TestFixtures.check(res, "row_writer_append_cells", rows == 9 and lines.size() == 10
		and lines[lines.size() - 1] == _joined(draft.row_cells(header)), "%d rows, %d lines" % [rows, lines.size()])
	TestFixtures.check(res, "row_writer_append_sheets",
		_bytes_of(ContractBuilderData.types_path) == _bytes_of(SheetFixtures.path(ContractBuilderData.TYPES_PATH))
		and _bytes_of(ContractBuilderData.organizations_path)
		== _bytes_of(SheetFixtures.path(ContractBuilderData.ORGANIZATIONS_PATH)),
		"the Types and Organizations copies keep their bytes")
	var bytes: PackedByteArray = _bytes_of(path)
	var again: Dictionary = ContractRowWriter.write(draft)
	TestFixtures.check(res, "row_writer_append_collision", not bool(again["ok"]) and int(again["line"]) == -1
		and String(again["error"]).ends_with("the row Caravan Watch") and _bytes_of(path) == bytes, _written_text(again))


static func _case_row_writer_replace(res: Dictionary) -> void:
	var path: String = ContractBuilderData.contracts_path
	var header: Array[String] = ContractBuilderData.header()
	var before: PackedStringArray = _text_of(path).split("\n")
	var want: int = TsvRowWriter.find_row(path, 0, "Rescue")
	var draft: ContractDraft = ContractDraft.new()
	draft.from_row(ContractBuilderData.contract_row("Rescue"))
	#The sheet's Rescue row leaves Issuer Type, Issuer, Style and Completion blank, and check() refuses those.
	draft.issuer_type = "person"
	draft.issuer = "Noble"
	draft.style = "check"
	draft.completion = "check:" + CHECK_NAME
	draft.difficulty_min = 2.0
	draft.difficulty_max = 4.0
	var written: Dictionary = ContractRowWriter.write(draft)
	TestFixtures.check(res, "row_writer_replace_ok", want > 0 and bool(written["ok"]) and bool(written["replaced"])
		and int(written["line"]) == want and not bool(written["new_type"]) and not bool(written["new_org"]),
		_written_text(written))
	var cells: Array[String] = draft.row_cells(header)
	var off: Array[String] = _lines_off(before, _text_of(path).split("\n"), want, _joined(cells))
	var rows: int = ContractBuilderData.contract_rows().size()
	TestFixtures.check(res, "row_writer_replace_lines", rows == 8 and off.is_empty() and cells.has("2.0")
		and cells.has("4.0"), "%d rows; %s" % [rows, TestFixtures.detail(off, before.size(), "lines off")])
	draft.contract_name = "Rescue Caravan"
	written = ContractRowWriter.write(draft)
	off = _lines_off(before, _text_of(path).split("\n"), want, _joined(draft.row_cells(header)))
	rows = ContractBuilderData.contract_rows().size()
	TestFixtures.check(res, "row_writer_rename", bool(written["ok"]) and bool(written["replaced"])
		and int(written["line"]) == want and String(written["name"]) == "Rescue Caravan" and off.is_empty() and rows == 8
		and ContractBuilderData.contract_row("Rescue").is_empty()
		and not ContractBuilderData.contract_row("Rescue Caravan").is_empty(),
		"%s; %d rows; %s" % [_written_text(written), rows, TestFixtures.detail(off, before.size(), "lines off")])


#A sheet name holding a character AsciiNormalizer maps loads in its ASCII form, and Confirm still replaces that row.
static func _case_row_writer_mapped_name(res: Dictionary) -> void:
	var path: String = ContractBuilderData.contracts_path
	var want: int = TsvRowWriter.find_row(path, 0, "Rescue")
	var before: PackedStringArray = _text_of(path).split("\n")
	if want < 0 or not before[want].begins_with("Rescue\t"):
		TestFixtures.check(res, "row_writer_mapped_setup", false, "no Rescue line at %d" % want)
		return
	before[want] = "Res" + char(0x2019) + "cue Two" + before[want].trim_prefix("Rescue")
	if not _store_text(path, "\n".join(before)):
		TestFixtures.check(res, "row_writer_mapped_setup", false, "cannot write %s" % path)
		return
	var found: int = TsvRowWriter.find_row(path, 0, "Res'cue Two")
	var draft: ContractDraft = ContractDraft.new()
	draft.from_row(ContractBuilderData.contract_row("Res'cue Two"))
	draft.issuer_type = "person"
	draft.issuer = "Noble"
	draft.style = "check"
	draft.completion = "check:" + CHECK_NAME
	var replacing: bool = ContractRowWriter.replaces(draft)
	var written: Dictionary = ContractRowWriter.write(draft)
	var row: String = _joined(draft.row_cells(ContractBuilderData.header()))
	var off: Array[String] = _lines_off(before, _text_of(path).split("\n"), want, row)
	var rows: int = ContractBuilderData.contract_rows().size()
	TestFixtures.check(res, "row_writer_mapped_name", found == want and draft.source_name == "Res'cue Two"
		and replacing and bool(written["ok"]) and bool(written["replaced"]) and int(written["line"]) == want
		and rows == 8 and off.is_empty(), "found %d at line %d, source %s, replaces %s; %s; %d rows; %s" % [found,
		want, draft.source_name, str(replacing), _written_text(written), rows,
		TestFixtures.detail(off, before.size(), "lines off")])


static func _case_row_writer_new_type(res: Dictionary) -> void:
	var path: String = ContractBuilderData.types_path
	var crlf: String = char(13) + char(10)
	var before_text: String = _text_of(path)
	var before: PackedStringArray = before_text.split(crlf)
	var column: int = before[0].split("\t").find(ContractBuilderData.TYPES_COLUMN)
	var draft: ContractDraft = _writer_draft("Night Heist")
	draft.contract_type = "Heist"
	var written: Dictionary = ContractRowWriter.write(draft)
	TestFixtures.check(res, "row_writer_new_type_ok", bool(written["ok"]) and bool(written["new_type"])
		and not bool(written["new_org"]) and int(written["line"]) == 9, _written_text(written))
	var after_text: String = _text_of(path)
	var cells: PackedStringArray = before[9].split("\t") if before.size() > 9 else PackedStringArray()
	while cells.size() < before[0].split("\t").size():
		cells.append("")
	if column >= 0:
		cells[column] = "Heist"
	var off: Array[String] = _lines_off(before, after_text.split(crlf), 9, "\t".join(cells))
	TestFixtures.check(res, "row_writer_new_type_cell", column >= 0 and off.is_empty(),
		"column %d; %s" % [column, TestFixtures.detail(off, before.size(), "lines off")])
	var bare: int = after_text.count("\n") - after_text.count(crlf)
	TestFixtures.check(res, "row_writer_new_type_crlf", after_text.count(crlf) == before_text.count(crlf) and bare == 0
		and not after_text.ends_with("\n"), "%d CRLF, was %d; %d bare LF" % [after_text.count(crlf),
		before_text.count(crlf), bare])
	var second: ContractDraft = _writer_draft("Day Heist")
	second.contract_type = "Heist"
	var again: Dictionary = ContractRowWriter.write(second)
	TestFixtures.check(res, "row_writer_known_type", bool(again["ok"]) and not bool(again["new_type"])
		and int(again["line"]) == 10 and _text_of(path) == after_text, _written_text(again))


static func _case_row_writer_new_org(res: Dictionary) -> void:
	var path: String = ContractBuilderData.organizations_path
	var draft: ContractDraft = _writer_draft("Lamp Watch")
	draft.issuer_type = "org"
	draft.issuer = "Guild of Lamps"
	var written: Dictionary = ContractRowWriter.write(draft)
	var text: String = _text_of(path)
	TestFixtures.check(res, "row_writer_new_org_ok", bool(written["ok"]) and bool(written["new_org"])
		and not bool(written["new_type"]) and text == "Name\tType\tHome\nGuild of Lamps\t\t",
		"%s; %s" % [_written_text(written), text.c_escape()])
	var second: ContractDraft = _writer_draft("Lamp Guard")
	second.issuer_type = "org"
	second.issuer = "Guild of Lamps"
	var again: Dictionary = ContractRowWriter.write(second)
	TestFixtures.check(res, "row_writer_known_org", bool(again["ok"]) and not bool(again["new_org"])
		and _text_of(path) == text, _written_text(again))


static func _case_row_writer_descriptions(res: Dictionary) -> void:
	var path: String = ContractBuilderData.descriptions_path
	var header: String = "Contract Name\tDescription"
	var draft: ContractDraft = _writer_draft("Lamp Run")
	var texts: Array[String] = ["First %target%", " ", "Second"]
	draft.descriptions = texts
	var written: Dictionary = ContractRowWriter.write(draft)
	TestFixtures.check(res, "row_writer_descriptions_ok", bool(written["ok"]) and int(written["descriptions"]) == 2
		and int(written["descriptions_removed"]) == 0, _described_text(written))
	TestFixtures.check(res, "row_writer_descriptions_rows", _bytes_of(path)
		== (header + "\nLamp Run\tFirst %target%\nLamp Run\tSecond").to_ascii_buffer(), _text_of(path).c_escape())
	draft.source_name = "Lamp Run"
	draft.contract_name = "Lamp Run Two"
	var only: Array[String] = ["Only"]
	draft.descriptions = only
	written = ContractRowWriter.write(draft)
	TestFixtures.check(res, "row_writer_descriptions_rename", bool(written["ok"]) and bool(written["replaced"])
		and int(written["descriptions"]) == 1 and int(written["descriptions_removed"]) == 2
		and ContractBuilderData.descriptions_for("Lamp Run").is_empty()
		and ContractBuilderData.descriptions_for("Lamp Run Two") == only
		and _bytes_of(path) == (header + "\nLamp Run Two\tOnly").to_ascii_buffer(),
		"%s; %s" % [_described_text(written), _text_of(path).c_escape()])
	#Loading the renamed row again sets source_name to the new name, as from_row does.
	draft.source_name = "Lamp Run Two"
	var empty: Array[String] = []
	draft.descriptions = empty
	written = ContractRowWriter.write(draft)
	TestFixtures.check(res, "row_writer_descriptions_cleared", bool(written["ok"]) and int(written["descriptions"]) == 0
		and int(written["descriptions_removed"]) == 1 and _bytes_of(path) == header.to_ascii_buffer()
		and not ContractBuilderData.contract_row("Lamp Run Two").is_empty()
		and ContractBuilderData.contract_row("Lamp Run").is_empty(),
		"%s; %s" % [_described_text(written), _text_of(path).c_escape()])


static func _case_row_writer_check_description(res: Dictionary) -> void:
	var draft: ContractDraft = _writer_draft("Lamp Run")
	var bad: Array[String] = ["ok", "bad" + char(233)]
	draft.descriptions = bad
	var reason: String = ContractRowWriter.check(draft)
	TestFixtures.check(res, "row_writer_check_description", reason.begins_with("Description 2 "), reason)
	var blank_first: Array[String] = ["", "fine"]
	draft.descriptions = blank_first
	reason = ContractRowWriter.check(draft)
	TestFixtures.check(res, "row_writer_check_description_blank", reason == "", reason)


#A Descriptions copy step 4 cannot write (a third column, mixed line endings, swapped columns, a byte order mark)
#refuses the draft in check(), with or without descriptions, so write() keeps both copies' bytes; the same draft writes
#once the copy is put back.
static func _case_row_writer_descriptions_sheet(res: Dictionary) -> void:
	var path: String = ContractBuilderData.descriptions_path
	var refusal: String = "cannot write Descriptions.tsv: "
	var good: PackedByteArray = _bytes_of(path)
	var contracts: PackedByteArray = _bytes_of(ContractBuilderData.contracts_path)
	var draft: ContractDraft = _writer_draft("Lamp Run")
	var texts: Array[String] = ["A"]
	var empty: Array[String] = []
	var sheets: Array = [["width", "Contract Name\tDescription\tNotes".to_utf8_buffer()],
		["mixed", "Contract Name\tDescription\r\nOld Run\tx\nOld Run\ty".to_utf8_buffer()],
		["order", "Description\tContract Name\nOld text\tLamp Run".to_utf8_buffer()],
		["bom", PackedByteArray([239, 187, 191]) + "Contract Name\tDescription".to_utf8_buffer()]]
	for item: Array in sheets:
		var bytes: PackedByteArray = item[1]
		var off: Array[String] = []
		if not _store_bytes(path, bytes):
			off.append("cannot write the copy")
		var reason: String = ""
		for count: int in [1, 0]:
			draft.descriptions = texts if count == 1 else empty
			reason = ContractRowWriter.check(draft)
			var written: Dictionary = ContractRowWriter.write(draft)
			if not reason.begins_with(refusal) or bool(written["ok"]) or String(written["error"]) != reason:
				off.append("%d descriptions: %s; %s" % [count, reason, _described_text(written)])
		if _bytes_of(path) != bytes or _bytes_of(ContractBuilderData.contracts_path) != contracts:
			off.append("a copy changed")
		TestFixtures.check(res, "row_writer_descriptions_sheet_" + String(item[0]), off.is_empty(),
			reason if off.is_empty() else "; ".join(PackedStringArray(off)))
	draft.descriptions = texts
	var restored: bool = _store_bytes(path, good)
	var retried: Dictionary = ContractRowWriter.write(draft)
	TestFixtures.check(res, "row_writer_descriptions_sheet_retry", restored and bool(retried["ok"])
		and int(retried["descriptions"]) == 1 and ContractBuilderData.descriptions_for("Lamp Run") == texts,
		_described_text(retried))


static func _described_text(written: Dictionary) -> String:
	return "%s, descriptions %d, removed %d" % [_written_text(written), int(written.get("descriptions", -1)),
		int(written.get("descriptions_removed", -1))]


static func _case_rebuild_parse(res: Dictionary) -> void:
	var good: Dictionary = ContractRebuild.parse_summary("x\nCONTRACT BUILDER: 8 contracts, 19 events, 0 warnings\ny")
	TestFixtures.check(res, "rebuild_parse_line", bool(good["ok"]) and int(good["contracts"]) == 8
		and int(good["events"]) == 19 and int(good["warnings"]) == 0, str(good))
	var crlf: Dictionary = ContractRebuild.parse_summary("a\r\nCONTRACT BUILDER: 1 contracts, 2 events, 3 warnings\r\n")
	TestFixtures.check(res, "rebuild_parse_crlf", bool(crlf["ok"]) and int(crlf["contracts"]) == 1
		and int(crlf["events"]) == 2 and int(crlf["warnings"]) == 3, str(crlf))
	var texts: Array[String] = ["nothing", "", "CONTRACT BUILDER: many contracts, 1 events, 0 warnings",
		"CONTRACT BUILDER: 1 contracts\nCONTRACT BUILDER: 8 contracts, 19 events, 0 warnings",
		"x CONTRACT BUILDER: 8 contracts, 19 events, 0 warnings"]
	var parsed: Array[String] = []
	for text: String in texts:
		if bool(ContractRebuild.parse_summary(text)["ok"]):
			parsed.append(text.c_escape())
	TestFixtures.check(res, "rebuild_parse_refused", parsed.is_empty(),
		TestFixtures.detail(parsed, texts.size(), "texts parse"))
	var done: String = ContractRebuild.summary_text({"ok": true, "contracts": 8, "events": 19, "warnings": 0})
	var failed: String = ContractRebuild.summary_text({"ok": false, "error": "exit code 1"})
	TestFixtures.check(res, "rebuild_summary_text", done == "rebuild: 8 contracts, 19 events, 0 warnings"
		and failed == "rebuild failed: exit code 1", "%s | %s" % [done, failed])


#Spawns the headless --contract-build child; DRY_BUILD_ENV keeps it from writing the tracked .tres files.
static func _case_rebuild_run(res: Dictionary) -> void:
	var started: int = Time.get_ticks_msec()
	OS.set_environment(HarnessEntry.DRY_BUILD_ENV, "1")
	var result: Dictionary = ContractRebuild.run()
	OS.unset_environment(HarnessEntry.DRY_BUILD_ENV)
	var seconds: float = float(Time.get_ticks_msec() - started) / 1000.0
	#The child is not a harness run, so it builds the live sheet rows only.
	var live: int = DataManager.contract_rows_from(TsvReader.load_tsv(CONTRACTS_TSV)).size()
	TestFixtures.check(res, "rebuild_run", bool(result["ok"]) and int(result["contracts"]) == live and live >= 1
		and int(result["exit_code"]) == 0 and String(result["error"]) == ""
		and String(result["output"]).length() <= ContractRebuild.OUTPUT_TAIL,
		"%s in %.1f s" % [ContractRebuild.summary_text(result), seconds])


static func _case_review_text(res: Dictionary) -> void:
	var blank: String = ReviewPage.review_text(ContractDraft.new())
	TestFixtures.check(res, "review_text_blank", blank == "%s\n\n%s" % [ReviewPage.WRITE_NEW, ReviewPage.EMPTY_TEXT],
		blank.c_escape())
	var plain: PackedStringArray = ReviewPage.review_text(_writer_draft("Caravan Watch")).split("\n")
	TestFixtures.check(res, "review_text_new", plain[0] == ReviewPage.WRITE_NEW and plain[1] == ""
		and plain.has("Contract Name: Caravan Watch") and plain.has("Issuer: Noble") and not plain.has(ReviewPage.FOLLOW_UPS),
		" | ".join(plain))
	var draft: ContractDraft = ContractDraft.new()
	draft.from_row(ContractBuilderData.contract_row("Rescue"))
	var loaded: PackedStringArray = ReviewPage.review_text(draft).split("\n")
	TestFixtures.check(res, "review_text_replace", loaded[0] == "Write: replace row Rescue" and loaded[1] == ""
		and loaded.has("Contract Name: Rescue") and not loaded.has(ReviewPage.FOLLOW_UPS), " | ".join(loaded))
	draft.contract_name = "Rescue Caravan"
	var renamed: PackedStringArray = ReviewPage.review_text(draft).split("\n")
	TestFixtures.check(res, "review_text_rename", renamed[0] == "Write: replace row Rescue"
		and renamed[1] == "Rename: Rescue to Rescue Caravan" and renamed[2] == ""
		and renamed.has("Contract Name: Rescue Caravan"), " | ".join(renamed))
	draft.source_name = "Gone"
	var gone: String = ReviewPage.review_text(draft)
	TestFixtures.check(res, "review_text_missing_source", gone.begins_with(ReviewPage.WRITE_NEW + "\n\n"),
		gone.left(60).c_escape())
	var fresh: ContractDraft = _writer_draft("Night Heist")
	fresh.contract_type = "Heist"
	fresh.issuer_type = "org"
	fresh.issuer = "Guild of Lamps"
	var lines: PackedStringArray = ReviewPage.review_text(fresh).split("\n")
	var want: PackedStringArray = PackedStringArray([ReviewPage.FOLLOW_UPS, "Stats.tsv derived stat for Heist",
		"Events.tsv event pool for Heist", "New organization Guild of Lamps: fill Type and Home in Organizations.tsv"])
	var tail: PackedStringArray = lines.slice(lines.size() - want.size())
	TestFixtures.check(res, "review_text_follow_ups", tail == want and lines[lines.size() - want.size() - 1] == "",
		" | ".join(tail))


static func _case_check_sheet_lists(res: Dictionary) -> void:
	var names: Array[String] = ["Cognition", "Wile"]
	var text: String = CheckSheet.format_names(names)
	TestFixtures.check(res, "check_sheet_lists_format", text == "Cognition, Wile", text)
	var parsed: Array[String] = CheckSheet.parse_names("Cognition, Wile,, ")
	var blank: Array[String] = CheckSheet.parse_names("")
	TestFixtures.check(res, "check_sheet_lists_parse", parsed == names and blank.is_empty(),
		"%s; %d from a blank cell" % [", ".join(parsed), blank.size()])


static func _case_check_sheet_percents(res: Dictionary) -> void:
	var entries: Array[Dictionary] = [{"name": "Clever (Cognition)", "percent": 10},
		{"name": "Notice (Cognition)", "percent": 0}]
	var text: String = CheckSheet.format_percents(entries)
	TestFixtures.check(res, "check_sheet_percents_format", text == "Clever (Cognition) 10, Notice (Cognition) 0", text)
	var parsed: Array[Dictionary] = CheckSheet.parse_percents(text)
	var bare: Array[Dictionary] = CheckSheet.parse_percents("Lore")
	var lore: Array[Dictionary] = [{"name": "Lore", "percent": 0}]
	TestFixtures.check(res, "check_sheet_percents_parse", parsed == entries and bare == lore
		and CheckSheet.parse_percents("").is_empty(), "%s; %s" % [str(parsed), str(bare)])


#format_signed over the ten traditions in sheet order keeps the nonzero ones, each with its sign.
static func _case_check_sheet_signed(res: Dictionary) -> void:
	SheetFixtures.point_at_fixtures()
	var values: Dictionary = {"Mage": -5, "Warrior": 15}
	var entries: Array[Dictionary] = []
	for tradition: String in ContractBuilderData.tradition_names():
		entries.append({"name": tradition, "value": int(values.get(tradition, 0))})
	var text: String = CheckSheet.format_signed(entries)
	TestFixtures.check(res, "check_sheet_signed_format", entries.size() == 10 and text == "Mage -5, Warrior +15",
		"%d traditions: %s" % [entries.size(), text])
	var parsed: Array[Dictionary] = CheckSheet.parse_signed(text)
	var want: Array[Dictionary] = [{"name": "Mage", "value": -5}, {"name": "Warrior", "value": 15}]
	var brave: Array[Dictionary] = [{"name": "Brave", "value": 0}]
	TestFixtures.check(res, "check_sheet_signed_parse", parsed == want and CheckSheet.parse_signed("Brave") == brave,
		str(parsed))
	ContractBuilderData.reset_paths()


static func _case_check_sheet_scalars(res: Dictionary) -> void:
	var shown: Array[String] = [CheckSheet.format_multiplier(1.0), CheckSheet.format_multiplier(1.5),
		CheckSheet.format_multiplier(4.0)]
	var shown_want: Array[String] = ["1", "1.5", "4"]
	var reads: Array[float] = [CheckSheet.parse_multiplier(""), CheckSheet.parse_multiplier("1.5"),
		CheckSheet.parse_multiplier("x"), CheckSheet.parse_multiplier("9")]
	var reads_want: Array[float] = [1.0, 1.5, 1.0, 4.0]
	TestFixtures.check(res, "check_sheet_multiplier", shown == shown_want and reads == reads_want,
		"%s; %s" % [", ".join(shown), str(reads)])
	var times: Array[int] = [CheckSheet.parse_time("90"), CheckSheet.parse_time(""), CheckSheet.parse_time("-5")]
	var times_want: Array[int] = [90, 0, 0]
	TestFixtures.check(res, "check_sheet_time", CheckSheet.format_time(60) == "60" and CheckSheet.format_time(0) == ""
		and times == times_want, "%s; %s" % [CheckSheet.format_time(60), str(times)])
	TestFixtures.check(res, "check_sheet_opposed", CheckSheet.format_opposed(true) == "Yes"
		and CheckSheet.format_opposed(false) == "No" and CheckSheet.parse_opposed("yes")
		and not CheckSheet.parse_opposed("No") and not CheckSheet.parse_opposed(""), "Yes and No")
	var values: Dictionary = {"retry": 0, "hp": -2, "ep": 0, "mp": 0, "guild": -1}
	var zeros: Dictionary = {"retry": 0, "hp": 0, "ep": 0, "mp": 0, "guild": 0}
	var text: String = CheckSheet.format_consequence(values)
	TestFixtures.check(res, "check_sheet_consequence_format", text == "hp -2, guild -1"
		and CheckSheet.format_consequence(zeros) == "", text)
	var parsed: Dictionary = CheckSheet.parse_consequence(text)
	var capped: Dictionary = CheckSheet.parse_consequence("hp -20, nope -1")
	var bare: Dictionary = CheckSheet.parse_consequence("retry")
	TestFixtures.check(res, "check_sheet_consequence_parse", parsed == values and capped.size() == 5
		and int(capped.get("hp", 0)) == -9 and not capped.has("nope") and int(bare.get("retry", 0)) == -1,
		"%s; %s; %s" % [str(parsed), str(capped), str(bare)])


#The summary skips the name and the blank columns; blank_row and HEADER match the sheet's eleven columns.
static func _case_check_sheet_summary(res: Dictionary) -> void:
	var text: String = CheckSheet.summary(CHECK_CELLS)
	TestFixtures.check(res, "check_sheet_summary", text == "\n".join(PackedStringArray(CHECK_SUMMARY)), text.c_escape())
	var blank: Array[String] = CheckSheet.blank_row()
	var first: String = _text_of(ContractBuilderData.CHECKS_PATH).replace("\r", "").split("\n")[0]
	var header: PackedStringArray = first.split("\t")
	TestFixtures.check(res, "check_sheet_header", blank.size() == 11 and blank.count("") == 11 and header.size() == 11
		and header == PackedStringArray(CheckSheet.HEADER), "%d blank cells; %s" % [blank.size(), " | ".join(header)])


#is_ascii keeps to what TsvRowWriter writes into a cell: a double quote, a tab, a control code, 127 and above fail.
static func _case_check_sheet_ascii(res: Dictionary) -> void:
	var refused: Array[String] = ["Trial \"of\" Wit", "Trial\tof Wit", "Trial" + char(127), "Trial" + char(1),
		"Cogniti" + char(243) + "n"]
	var passed: Array[String] = []
	for text: String in refused:
		if CheckSheet.is_ascii(text):
			passed.append(text.c_escape())
	TestFixtures.check(res, "check_sheet_ascii", CheckSheet.is_ascii("Trial of Wit, ~!") and passed.is_empty(),
		TestFixtures.detail(passed, refused.size(), "refused texts pass"))


#A writable copy of CHECK_CELLS; a const array is read-only.
static func _check_cells() -> Array[String]:
	var out: Array[String] = []
	out.assign(CHECK_CELLS)
	return out


#The nonblank cells of one column, header skipped and repeats kept.
static func _column_cells(path: String, column: int) -> Array[String]:
	var out: Array[String] = []
	var rows: Array[PackedStringArray] = TsvReader.load_tsv(path)
	for i: int in range(1, rows.size()):
		var cell: String = TsvReader.row_get(rows[i], column)
		if cell != "":
			out.append(cell)
	return out


static func _check_text(written: Dictionary) -> String:
	return "ok %s, check %s, error %s" % [str(written.get("ok", false)), str(written.get("check", false)),
		String(written.get("error", ""))]


#The readers on the copies: the header-only Checks sheet, then one appended row; the core stats of the sheet, of a
#reordered copy and of a header-only copy; the circumstances in sheet order; the knowledge and tool columns.
static func _case_data_check_readers(res: Dictionary) -> void:
	var names: Array[String] = ContractBuilderData.check_names()
	var rows: Array[PackedStringArray] = ContractBuilderData.check_rows()
	TestFixtures.check(res, "data_check_empty", names.is_empty() and rows.is_empty(),
		"%d names, %d rows" % [names.size(), rows.size()])
	var appended: Dictionary = TsvRowWriter.append_row(ContractBuilderData.checks_path, _check_cells())
	names = ContractBuilderData.check_names()
	rows = ContractBuilderData.check_rows()
	var named: Array[String] = [CHECK_NAME]
	TestFixtures.check(res, "data_check_appended", bool(appended["ok"]) and names == named and rows.size() == 1
		and rows[0].size() == CheckSheet.WIDTH, "%s; %s; %d rows" % [_result_text(appended), ", ".join(names),
		rows.size()])
	var core: Array[String] = ["Cognition", "Dexterity", "Vigor", "Wile"]
	var attributes: Array[String] = ContractBuilderData.attribute_names()
	var stats: String = ContractBuilderData.stats_path
	var header: String = "Stats\tCalculation\tRound\tType\tExplanation"
	var stored: bool = _store_text(stats, header + "\r\nWile\t\t\tcore\t\r\nHealth\tVigor\t\tderived\t\r\nVigor\t\t\tcore\t")
	var reordered: Array[String] = ContractBuilderData.attribute_names()
	stored = _store_text(stats, header) and stored
	var fallback: Array[String] = ContractBuilderData.attribute_names()
	var moved: Array[String] = ["Wile", "Vigor"]
	TestFixtures.check(res, "data_attribute_names", attributes == core and stored and reordered == moved
		and fallback == core, "%s; %s; %s" % [", ".join(attributes), ", ".join(reordered), ", ".join(fallback)])
	var circumstances: Array[Dictionary] = ContractBuilderData.circumstance_rows()
	var attack: Array[String] = []
	for row: Dictionary in circumstances:
		if String(row.get("name", "")) == "Attack":
			attack.append(String(row.get("stat", "")))
	var first: Dictionary = circumstances[0] if not circumstances.is_empty() else {}
	var athletics: Dictionary = {"name": "Athletics", "stat": "Vigor", "rarity": "Uncommon"}
	var attack_want: Array[String] = ["Dexterity", "Vigor"]
	TestFixtures.check(res, "data_circumstance_rows", circumstances.size() == 24 and first == athletics
		and attack == attack_want, "%d rows, first %s, Attack under %s" % [circumstances.size(), str(first),
		", ".join(attack)])
	var path: String = ContractBuilderData.knowledges_path
	var knowledges: Array[String] = ContractBuilderData.knowledge_names()
	var cells: Array[String] = _column_cells(path, ContractBuilderData.KNOWLEDGES_NAME_COLUMN)
	TestFixtures.check(res, "data_knowledge_names", knowledges.size() == 121 and cells.size() == 121
		and not knowledges.has(""), "%d names from %d cells; repeats: %s" % [knowledges.size(), cells.size(),
		", ".join(_repeats(cells))])
	var tools: Array[String] = ContractBuilderData.tool_names()
	var tool_cells: Array[String] = _column_cells(path, ContractBuilderData.TOOLS_NAME_COLUMN)
	TestFixtures.check(res, "data_tool_names", tools.size() == 72 and tool_cells.size() == 72 and not tools.has(""),
		"%d names from %d cells; repeats: %s" % [tools.size(), tool_cells.size(), ", ".join(_repeats(tool_cells))])
	var keyed: int = 0
	for row: Dictionary in circumstances:
		if row.size() == 3 and row.has("name") and row.has("stat") and row.has("rarity"):
			keyed += 1
	TestFixtures.check(res, "data_circumstance_keys", keyed == 24, "%d of %d rows keyed" % [keyed, circumstances.size()])
	var knowledge_rows: Array[Dictionary] = ContractBuilderData.knowledge_rows()
	var knowledge_first: Dictionary = knowledge_rows[0] if not knowledge_rows.is_empty() else {}
	var aerdis: Dictionary = {"name": "Aerdis", "category": "Location", "rarity": "Common"}
	TestFixtures.check(res, "data_knowledge_rows", knowledge_rows.size() == 121 and knowledge_first == aerdis,
		"%d rows, first %s" % [knowledge_rows.size(), str(knowledge_first)])
	var tool_rows: Array[Dictionary] = ContractBuilderData.tool_rows()
	var tool_first: Dictionary = tool_rows[0] if not tool_rows.is_empty() else {}
	var alchemist: Dictionary = {"name": "Alchemist's", "category": "Science", "rarity": "Uncommon"}
	TestFixtures.check(res, "data_tool_rows", tool_rows.size() == 72 and tool_first == alchemist,
		"%d rows, first %s" % [tool_rows.size(), str(tool_first)])
	var blanks: Array[String] = _blank_parts(knowledge_rows) + _blank_parts(tool_rows)
	TestFixtures.check(res, "data_rows_filled", blanks.is_empty(), "blank: %s" % ", ".join(blanks))
	TestFixtures.check(res, "data_rows_match_names", _row_names(knowledge_rows) == knowledges
		and _row_names(tool_rows) == tools, "%d and %d rows" % [knowledge_rows.size(), tool_rows.size()])


#The names of the rows with a blank category or rarity.
static func _blank_parts(rows: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in rows:
		if String(row.get("category", "")) == "" or String(row.get("rarity", "")) == "":
			out.append(String(row.get("name", "")))
	return out


static func _row_names(rows: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in rows:
		out.append(String(row.get("name", "")))
	return out


#check_row survives to_dict, JSON and from_dict; a key of another shape, a missing key, from_row and clear give [].
static func _case_draft_check_row(res: Dictionary) -> void:
	SheetFixtures.point_at_fixtures()
	var draft: ContractDraft = _writer_draft("Lamp Run")
	draft.check_row = _check_cells()
	var copy: ContractDraft = ContractDraft.new()
	copy.from_dict(draft.to_dict())
	var parsed: Variant = JSON.parse_string(JSON.stringify(draft.to_dict()))
	var loaded: ContractDraft = ContractDraft.new()
	if parsed is Dictionary:
		loaded.from_dict(parsed as Dictionary)
	TestFixtures.check(res, "draft_check_row_round_trip", copy.check_row == draft.check_row
		and loaded.check_row == draft.check_row and draft.check_row.size() == CheckSheet.WIDTH,
		" | ".join(loaded.check_row))
	var shapes: Array = [["five cells", ["a", "b", "c", "d", "e"]], ["a String", CHECK_NAME],
		["a number cell", [CHECK_NAME, "", "", "", "", "", "", "", "", "", 4]]]
	var kept: Array[String] = []
	for shape: Array in shapes:
		var d: Dictionary = draft.to_dict()
		d["check_row"] = shape[1]
		copy.from_dict(draft.to_dict())
		copy.from_dict(d)
		if not copy.check_row.is_empty():
			kept.append(String(shape[0]))
	var missing: Dictionary = draft.to_dict()
	missing.erase("check_row")
	copy.from_dict(draft.to_dict())
	copy.from_dict(missing)
	if not copy.check_row.is_empty():
		kept.append("no key")
	TestFixtures.check(res, "draft_check_row_malformed", kept.is_empty(), TestFixtures.detail(kept, 4, "shapes kept"))
	var row: ContractDraft = ContractDraft.new()
	row.check_row = _check_cells()
	row.from_row(ContractBuilderData.contract_row("Rescue"))
	var cleared: ContractDraft = ContractDraft.new()
	cleared.check_row = _check_cells()
	cleared.clear()
	TestFixtures.check(res, "draft_check_row_resets", row.check_row.is_empty() and row.contract_name == "Rescue"
		and cleared.check_row.is_empty(), "%d cells after from_row, %d after clear" % [row.check_row.size(),
		cleared.check_row.size()])
	ContractBuilderData.reset_paths()


#D90: one check per call; the balance arithmetic uses the literal numbers of the plan.
static func _case_share_balance(res: Dictionary) -> void:
	var rebalances: Array = [[[50, 50], 0, [50, 50]], [[60, 50], 0, [60, 40]], [[10, 50, 50], 0, [10, 45, 45]],
		[[100, 30, 20], 0, [98, 1, 1]], [[1, 1, 1], 1, [1, 1, 1]], [[0, 40], 0, [1, 40]],
		[[70, 30, 10], 2, [60, 30, 10]], [[60, 50], -1, [50, 50]]]
	for k: int in range(rebalances.size()):
		var item: Array = rebalances[k]
		var given: Array[int] = []
		given.assign(item[0])
		var want: Array[int] = []
		want.assign(item[2])
		var got: Array[int] = ShareBalance.rebalance(given, int(item[1]))
		TestFixtures.check(res, "share_balance_rebalance_%d" % (k + 1), got == want, "%s moved %d gives %s" % [
			str(given), int(item[1]), str(got)])
	var crowd: Array[int] = []
	crowd.resize(101)
	crowd.fill(5)
	var crowd_out: Array[int] = ShareBalance.rebalance(crowd, 0)
	TestFixtures.check(res, "share_balance_rebalance_9", crowd_out == crowd, "101 entries of 5 changed: %d entries back" %
		crowd_out.size())
	var input: Array[int] = [100, 30, 20]
	var copy: Array[int] = input.duplicate()
	ShareBalance.rebalance(input, 0)
	TestFixtures.check(res, "share_balance_rebalance_10", input == copy, "input after %s" % str(input))
	var clips: Array = [[[15, 100], [15, 85]], [[150, 20], [100, 0]], [[50, 50, 10], [50, 50, 0]], [[30, 20], [30, 20]],
		[[-5, 20], [0, 20]]]
	for k: int in range(clips.size()):
		var given: Array[int] = []
		given.assign(clips[k][0])
		var want: Array[int] = []
		want.assign(clips[k][1])
		var got: Array[int] = ShareBalance.clip(given)
		TestFixtures.check(res, "share_balance_clip_%d" % (k + 1), got == want, "%s gives %s" % [str(given), str(got)])
	var remainders: Array = [[[15, 85], 0], [[10], 90], [[], 100]]
	for k: int in range(remainders.size()):
		var given: Array[int] = []
		given.assign(remainders[k][0])
		var got: int = ShareBalance.remainder(given)
		TestFixtures.check(res, "share_balance_remainder_%d" % (k + 1), got == int(remainders[k][1]),
			"%s leaves %d" % [str(given), got])


#D94: under Style check a Completion other than check:<name> or event:<name> is refused with its text.
static func _case_writer_check_completion(res: Dictionary) -> void:
	var misjudged: Array[String] = []
	for text: String in ["Battle", "x=1:2"]:
		var draft: ContractDraft = _writer_draft("Lamp Run")
		draft.completion = text
		var reason: String = ContractRowWriter.check(draft)
		if reason != ContractRowWriter.CHECK_COMPLETION_EXPECTED % text:
			misjudged.append("[%s]: %s" % [text, reason])
	TestFixtures.check(res, "writer_check_completion_expected", misjudged.is_empty(),
		TestFixtures.detail(misjudged, 2, "completions misjudged"))
	misjudged.clear()
	for text: String in ["check:", " check:  "]:
		var draft: ContractDraft = _writer_draft("Lamp Run")
		draft.completion = text
		var reason: String = ContractRowWriter.check(draft)
		if reason != ContractRowWriter.COMPLETION_EMPTY:
			misjudged.append("[%s]: %s" % [text, reason])
	TestFixtures.check(res, "writer_check_completion_blank", misjudged.is_empty(),
		TestFixtures.detail(misjudged, 2, "completions misjudged"))
	var event: ContractDraft = _writer_draft("Lamp Run")
	event.completion = "event:Battle"
	var event_reason: String = ContractRowWriter.check(event)
	TestFixtures.check(res, "writer_check_completion_event",
		event_reason == "Completion names an event but Style is check", event_reason)
	var plain: String = ContractRowWriter.check(_writer_draft("Lamp Run"))
	TestFixtures.check(res, "writer_check_completion_default", plain == "", plain)


#check() runs the check rules after the others: Style check needs a Completion, a check Completion needs Style check,
#and a pending row needs eleven writable cells and a name Checks.tsv does not hold, compared without letter case.
static func _case_row_writer_check_rules(res: Dictionary) -> void:
	var draft: ContractDraft = _writer_draft("Lamp Run")
	draft.completion = ""
	var reason: String = ContractRowWriter.check(draft)
	TestFixtures.check(res, "row_writer_check_completion", reason == ContractRowWriter.COMPLETION_EMPTY, reason)
	draft.style = "event"
	draft.completion = "check:X"
	reason = ContractRowWriter.check(draft)
	TestFixtures.check(res, "row_writer_check_style", reason == "Completion names a check but Style is event", reason)
	draft.style = "check"
	draft.completion = "check:" + CHECK_NAME
	draft.check_row = _check_cells()
	reason = ContractRowWriter.check(draft)
	TestFixtures.check(res, "row_writer_check_row_pass", reason == "" and ContractRowWriter.pending_check(draft), reason)
	var short: Array[String] = _check_cells()
	short.resize(10)
	draft.check_row = short
	reason = ContractRowWriter.check(draft)
	TestFixtures.check(res, "row_writer_check_row_width", reason == "Check row: expected 11 cells, got 10", reason)
	var accented: Array[String] = _check_cells()
	accented[CheckSheet.ATTRIBUTES] = "Cogniti" + char(243) + "n"
	draft.check_row = accented
	reason = ContractRowWriter.check(draft)
	TestFixtures.check(res, "row_writer_check_row_ascii", reason.begins_with("Check row: cell 1 holds "), reason)
	var unnamed: Array[String] = _check_cells()
	unnamed[CheckSheet.NAME] = " "
	draft.check_row = unnamed
	reason = ContractRowWriter.check(draft)
	TestFixtures.check(res, "row_writer_check_row_name", reason == ContractRowWriter.CHECK_NAME_EMPTY, reason)
	var appended: Dictionary = TsvRowWriter.append_row(ContractBuilderData.checks_path, _check_cells())
	draft.check_row = _check_cells()
	reason = ContractRowWriter.check(draft)
	var lower: Array[String] = _check_cells()
	lower[CheckSheet.NAME] = "trial of wit"
	draft.check_row = lower
	draft.completion = "check:trial of wit"
	var again: String = ContractRowWriter.check(draft)
	TestFixtures.check(res, "row_writer_check_row_exists", bool(appended["ok"])
		and reason == "Check Trial of Wit already exists in Checks.tsv"
		and again == "Check trial of wit already exists in Checks.tsv", "%s | %s" % [reason, again])
	var empty: Array[String] = []
	draft.check_row = empty
	draft.completion = "check:" + CHECK_NAME
	reason = ContractRowWriter.check(draft)
	TestFixtures.check(res, "row_writer_check_named", reason == "" and not ContractRowWriter.pending_check(draft), reason)


#Step 5 appends the pending row; a Completion naming a check with no pending row, or a row it does not name, leaves
#the Checks copy alone; a read-only Checks copy fails step 5, and the error names only the steps that wrote.
static func _case_row_writer_check_append(res: Dictionary) -> void:
	var path: String = ContractBuilderData.checks_path
	var header: String = _text_of(path)
	var draft: ContractDraft = _writer_draft("Lamp Run")
	draft.check_row = _check_cells()
	var written: Dictionary = ContractRowWriter.write(draft)
	TestFixtures.check(res, "row_writer_check_append_ok", header == "\t".join(PackedStringArray(CheckSheet.HEADER))
		and bool(written["ok"]) and bool(written["check"])
		and _bytes_of(path) == (header + "\n" + _joined(CHECK_CELLS)).to_ascii_buffer()
		and not ContractBuilderData.contract_row("Lamp Run").is_empty(),
		"%s; %s" % [_check_text(written), _text_of(path).c_escape()])
	var bytes: PackedByteArray = _bytes_of(path)
	written = ContractRowWriter.write(_writer_draft("Lamp Walk"))
	TestFixtures.check(res, "row_writer_check_append_named", bool(written["ok"]) and not bool(written["check"])
		and _bytes_of(path) == bytes, _check_text(written))
	var other: ContractDraft = _writer_draft("Lamp Hike")
	var cells: Array[String] = _check_cells()
	cells[CheckSheet.NAME] = "Other"
	other.check_row = cells
	written = ContractRowWriter.write(other)
	TestFixtures.check(res, "row_writer_check_append_unnamed", bool(written["ok"]) and not bool(written["check"])
		and _bytes_of(path) == bytes, _check_text(written))
	var nerve: ContractDraft = _check_draft("Lamp Trek", "Trial of Nerve")
	var grit: ContractDraft = _check_draft("Lamp Roam", "Trial of Grit")
	var texts: Array[String] = ["A"]
	grit.descriptions = texts
	var locked: bool = FileAccess.set_read_only_attribute(path, true) == OK
	var failed: Dictionary = ContractRowWriter.write(nerve)
	var described: Dictionary = ContractRowWriter.write(grit)
	var unlocked: bool = FileAccess.set_read_only_attribute(path, false) == OK
	var said: String = String(failed["error"])
	TestFixtures.check(res, "row_writer_check_append_fail", locked and unlocked and not bool(failed["ok"])
		and not bool(failed["check"]) and said.begins_with(ContractRowWriter.STEP_CHECK + ": cannot write ")
		and said.ends_with("; already written, not rolled back: Contracts.tsv row") and _bytes_of(path) == bytes
		and not ContractBuilderData.contract_row("Lamp Trek").is_empty(), said)
	said = String(described["error"])
	TestFixtures.check(res, "row_writer_check_append_fail_described", not bool(described["ok"])
		and not bool(described["check"])
		and said.ends_with("; already written, not rolled back: Contracts.tsv row, Descriptions.tsv rows")
		and ContractBuilderData.descriptions_for("Lamp Roam") == texts, said)


#_writer_draft(title) with a pending check row named check_name.
static func _check_draft(title: String, check_name: String) -> ContractDraft:
	var draft: ContractDraft = _writer_draft(title)
	var cells: Array[String] = _check_cells()
	cells[CheckSheet.NAME] = check_name
	draft.check_row = cells
	draft.completion = "check:" + check_name
	return draft


#A pending check refuses a Checks copy that cannot be read or whose trimmed header is not exactly CheckSheet.HEADER,
#so write() leaves every copy alone; a draft without a pending check passes; the restored copy takes the row.
static func _case_row_writer_check_sheet(res: Dictionary) -> void:
	var path: String = ContractBuilderData.checks_path
	var refusal: String = "cannot write Checks.tsv: "
	var good: PackedByteArray = _bytes_of(path)
	var header: String = _joined(CheckSheet.HEADER)
	var swapped: Array[String] = []
	swapped.assign(CheckSheet.HEADER)
	swapped[CheckSheet.ATTRIBUTES] = CheckSheet.HEADER[CheckSheet.CIRCUMSTANCES]
	swapped[CheckSheet.CIRCUMSTANCES] = CheckSheet.HEADER[CheckSheet.ATTRIBUTES]
	var sheets: Array = [["width", (header + "\tNotes").to_utf8_buffer()], ["order", _joined(swapped).to_utf8_buffer()],
		["mixed", (header + "\r\nOld Check\nOlder Check").to_utf8_buffer()],
		["bom", PackedByteArray([239, 187, 191]) + header.to_utf8_buffer()], ["empty", PackedByteArray()]]
	var draft: ContractDraft = _check_draft("Lamp Run", CHECK_NAME)
	var plain: ContractDraft = _writer_draft("Lamp Walk")
	var contracts: PackedByteArray = _bytes_of(ContractBuilderData.contracts_path)
	var descriptions: PackedByteArray = _bytes_of(ContractBuilderData.descriptions_path)
	for item: Array in sheets:
		var bytes: PackedByteArray = item[1]
		var off: Array[String] = []
		if not _store_bytes(path, bytes):
			off.append("cannot write the copy")
		var reason: String = ContractRowWriter.check(draft)
		var written: Dictionary = ContractRowWriter.write(draft)
		if not reason.begins_with(refusal) or bool(written["ok"]) or String(written["error"]) != reason:
			off.append("pending: %s; %s" % [reason, _check_text(written)])
		var other: String = ContractRowWriter.check(plain)
		if other != "":
			off.append("no pending check: " + other)
		if _bytes_of(path) != bytes or _bytes_of(ContractBuilderData.contracts_path) != contracts \
				or _bytes_of(ContractBuilderData.descriptions_path) != descriptions:
			off.append("a copy changed")
		TestFixtures.check(res, "row_writer_check_sheet_" + String(item[0]), off.is_empty(),
			reason if off.is_empty() else "; ".join(PackedStringArray(off)))
	var restored: bool = _store_bytes(path, good)
	var retried: Dictionary = ContractRowWriter.write(draft)
	var names: Array[String] = ContractBuilderData.check_names()
	var named: Array[String] = [CHECK_NAME]
	TestFixtures.check(res, "row_writer_check_sheet_retry", restored and bool(retried["ok"]) and bool(retried["check"])
		and names == named, "%s; %s" % [_check_text(retried), ", ".join(names)])


#A pending check adds "New check: <name>" and its summary lines, indented, right after the description lines.
static func _case_review_text_check(res: Dictionary) -> void:
	var draft: ContractDraft = _writer_draft("Lamp Run")
	var texts: Array[String] = ["First %target%", "Second"]
	draft.descriptions = texts
	draft.check_row = _check_cells()
	var lines: PackedStringArray = ReviewPage.review_text(draft).split("\n")
	var want: PackedStringArray = PackedStringArray([ReviewPage.NEW_CHECK % CHECK_NAME])
	for line: String in CHECK_SUMMARY:
		want.append("  " + line)
	var at: int = lines.find("Description: Second")
	var shown: PackedStringArray = lines.slice(at + 1) if at >= 0 else PackedStringArray()
	TestFixtures.check(res, "review_text_check", at >= 0 and shown == want, " | ".join(lines))
	var empty: Array[String] = []
	draft.check_row = empty
	var bare: String = ReviewPage.review_text(draft)
	draft.check_row = _check_cells()
	draft.completion = "check:Other"
	var unnamed: String = ReviewPage.review_text(draft)
	TestFixtures.check(res, "review_text_check_none", not bare.contains("New check")
		and not unnamed.contains("New check"), "%s | %s" % [bare.c_escape(), unnamed.c_escape()])


#Confirm on the real scene, paths on the copies. The body awaits frames, so it sets and resets the paths itself;
#a draft the designer left in DRAFT_PATH is put back afterwards.
static func _case_confirm_flow(res: Dictionary) -> void:
	var reason: String = _scratch_setup()
	if reason != "":
		TestFixtures.check(res, "confirm_flow_setup", false, reason)
		ContractBuilderData.reset_paths()
		return
	var had_draft: bool = FileAccess.file_exists(ContractBuilder.DRAFT_PATH)
	var saved: PackedByteArray = _bytes_of(ContractBuilder.DRAFT_PATH) if had_draft else PackedByteArray()
	if had_draft:
		DirAccess.remove_absolute(ContractBuilder.DRAFT_PATH)
	var scene: PackedScene = load(BUILDER_SCENE) as PackedScene
	var node: Node = null
	if scene != null:
		node = scene.instantiate()
	var shell: ContractBuilder = node as ContractBuilder
	if shell == null:
		TestFixtures.check(res, "confirm_flow_scene", false, "cannot instance %s as ContractBuilder" % BUILDER_SCENE)
		if node != null:
			node.free()
	else:
		shell.hosted = true
		shell.rebuild_on_confirm = false
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		#run() starts inside the main scene's _ready, where the root refuses add_child until a frame passes.
		await tree.process_frame
		tree.root.add_child(shell)
		if shell.is_inside_tree():
			await TestFixtures.frames(shell)
			_confirm_checks(res, shell)
			shell.queue_free()
			await tree.process_frame
		else:
			TestFixtures.check(res, "confirm_flow_tree", false, "the root did not take the shell")
			shell.free()
	if FileAccess.file_exists(ContractBuilder.DRAFT_PATH):
		DirAccess.remove_absolute(ContractBuilder.DRAFT_PATH)
	if had_draft and not _store_bytes(ContractBuilder.DRAFT_PATH, saved):
		TestFixtures.check(res, "confirm_flow_draft_restore", false, "cannot put back %s" % ContractBuilder.DRAFT_PATH)
	ContractBuilderData.reset_paths()


static func _confirm_checks(res: Dictionary, shell: ContractBuilder) -> void:
	var status: Label = shell.get_node("Margin/Column/BottomBar/Status") as Label
	var path: String = ContractBuilderData.contracts_path
	var last: int = shell.pages.size() - 1
	var draft: ContractDraft = _writer_draft("Caravan Watch")
	var texts: Array[String] = ["Guard the caravan to %location%", "Keep %target% from the road"]
	draft.descriptions = texts
	draft.check_row = _check_cells()
	shell.draft.from_dict(draft.to_dict())
	shell.show_page(last)
	shell.confirm()
	var lines: PackedStringArray = _text_of(path).split("\n")
	var said: String = status.text if status != null else ""
	TestFixtures.check(res, "confirm_flow_write", lines.size() == 10
		and lines[lines.size() - 1] == _joined(draft.row_cells(ContractBuilderData.header())), "%d lines" % lines.size())
	var kept: bool = FileAccess.file_exists(ContractBuilder.DRAFT_PATH)
	TestFixtures.check(res, "confirm_flow_cleared", shell.draft.is_new() and shell.draft.contract_name == ""
		and shell.index == 0 and not kept, "index %d, name %s, draft file %s" % [shell.index,
		shell.draft.contract_name, str(kept)])
	TestFixtures.check(res, "confirm_flow_status", said == "Wrote Caravan Watch; rebuild skipped", said)
	var described: Array[String] = ContractBuilderData.descriptions_for("Caravan Watch")
	var described_lines: int = _text_of(ContractBuilderData.descriptions_path).split("\n").size()
	TestFixtures.check(res, "confirm_flow_descriptions", described.size() == 2 and described == draft.descriptions
		and described_lines == 3, "%d rows, %d lines: %s" % [described.size(), described_lines, " | ".join(described)])
	var checks: Array[String] = ContractBuilderData.check_names()
	var checked: Array[String] = [CHECK_NAME]
	var check_rows: int = ContractBuilderData.check_rows().size()
	TestFixtures.check(res, "confirm_flow_check", check_rows == 1 and checks == checked,
		"%d rows: %s" % [check_rows, ", ".join(checks)])
	var bytes: PackedByteArray = _bytes_of(path)
	shell.draft.from_dict(_writer_draft("Rescue").to_dict())
	shell.show_page(last)
	shell.confirm()
	said = status.text if status != null else ""
	TestFixtures.check(res, "confirm_flow_refused", said.ends_with("the row Rescue") and _bytes_of(path) == bytes
		and shell.draft.contract_name == "Rescue" and shell.draft.issuer == "Noble" and shell.index == last
		and FileAccess.file_exists(ContractBuilder.DRAFT_PATH), "%s; index %d" % [said, shell.index])
	shell.draft.from_row(ContractBuilderData.contract_row("Rescue"))
	shell.draft.issuer_type = "person"
	shell.draft.issuer = "Noble"
	shell.draft.style = "check"
	shell.draft.completion = "check:" + CHECK_NAME
	shell.show_page(last)
	shell.confirm()
	said = status.text if status != null else ""
	var rows: int = ContractBuilderData.contract_rows().size()
	TestFixtures.check(res, "confirm_flow_replace", said == "Replaced Rescue; rebuild skipped" and rows == 9
		and shell.draft.is_new() and shell.index == 0, "%s; %d rows" % [said, rows])
	check_rows = ContractBuilderData.check_rows().size()
	TestFixtures.check(res, "confirm_flow_check_once", check_rows == 1, "%d Checks.tsv rows" % check_rows)


#The fourteen sheets hash the same at the end of run() as at its start.
static func _case_tsv_guard(res: Dictionary, sums: Dictionary) -> void:
	var changed: Array[String] = []
	for path: String in _sheet_paths():
		var sum: String = FileAccess.get_md5(path)
		if sum == "" or sum != String(sums.get(path, "")):
			changed.append(path.get_file())
	TestFixtures.check(res, "tsv_guard", changed.is_empty(),
		TestFixtures.detail(changed, _sheet_paths().size(), "sheets changed"))


#Each live header still holds what its fixture header holds: by name for the sheets read by column name, as a leading
#run of cells for the sheets read by column index. A live column added where the reader allows passes.
static func _case_live_headers(res: Dictionary) -> void:
	var by_name: Array[String] = [ContractBuilderData.CONTRACTS_PATH, ContractBuilderData.TYPES_PATH,
		ContractBuilderData.ORGANIZATIONS_PATH, ContractBuilderData.NPCS_PATH, ContractBuilderData.TRADITIONS_PATH,
		ContractBuilderData.EVENTS_PATH]
	for path: String in _sheet_paths():
		var live: PackedStringArray = _header_cells(path)
		var fixture: PackedStringArray = _header_cells(SheetFixtures.path(path))
		var off: String = ""
		if by_name.has(path):
			var missing: Array[String] = []
			for cell: String in fixture:
				if cell == "":
					continue
				if live.count(cell) < fixture.count(cell) and not missing.has(cell):
					missing.append(cell)
			if not missing.is_empty():
				off = "%s lacks column %s" % [path.get_file(), ", ".join(missing)]
		else:
			for i: int in range(fixture.size()):
				var got: String = live[i] if i < live.size() else "(none)"
				if got != fixture[i]:
					off = "%s cell %d is %s, fixture %s" % [path.get_file(), i, got, fixture[i]]
					break
		var key: String = "live_headers_" + path.get_file().get_basename().to_lower().replace(" ", "_")
		TestFixtures.check(res, key, fixture.size() > 0 and off == "",
			off if off != "" else "%d live cells, %d fixture cells" % [live.size(), fixture.size()])


#The first line of a sheet split on tab, each cell stripped as TsvReader.row_get does; empty when the file cannot be read.
static func _header_cells(path: String) -> PackedStringArray:
	var text: String = FileAccess.get_file_as_string(path)
	var cells: PackedStringArray = PackedStringArray()
	if text == "":
		return cells
	for cell: String in text.split("\n")[0].split("\t"):
		cells.append(cell.strip_edges())
	return cells


#EventConfig.parse: blank pairs and keys skipped, keys lowered, an inner ", " list kept, a pair without "=" kept blank.
static func _case_event_config_parse(res: Dictionary) -> void:
	var blank: Dictionary = EventConfig.parse("")
	TestFixtures.check(res, "event_config_parse_blank", blank.is_empty(), str(blank))
	var one: Dictionary = EventConfig.parse("bandits=1.5")
	TestFixtures.check(res, "event_config_parse_one", one == {"bandits": "1.5"}, str(one))
	var two: Dictionary = EventConfig.parse("chase=foot; chasing=mercs")
	TestFixtures.check(res, "event_config_parse_order", two.keys() == ["chase", "chasing"]
		and two.values() == ["foot", "mercs"], str(two))
	var listed: Dictionary = EventConfig.parse(" types=Beast, Undead ;monsters=all")
	TestFixtures.check(res, "event_config_parse_list", listed == {"types": "Beast, Undead", "monsters": "all"},
		str(listed))
	var upper: Dictionary = EventConfig.parse("BANDITS=2")
	TestFixtures.check(res, "event_config_parse_lower", upper == {"bandits": "2"}, str(upper))
	var bad: Dictionary = EventConfig.parse("oops")
	TestFixtures.check(res, "event_config_parse_bad_pair", bad == {"oops": ""}, str(bad))
	var empty: Dictionary = EventConfig.parse(";;")
	TestFixtures.check(res, "event_config_parse_separators", empty.is_empty(), str(empty))
	var keyless: Dictionary = EventConfig.parse("=5; bandits=2; = ")
	TestFixtures.check(res, "event_config_parse_blank_key", keyless == {"bandits": "2"}, str(keyless))


#EventConfig.compose: the order keys first, blank values left out, other keys after; default_cell from the defaults.
static func _case_event_config_compose(res: Dictionary) -> void:
	var order: Array[String] = ["bandits"]
	var one: String = EventConfig.compose({"bandits": "2"}, order)
	TestFixtures.check(res, "event_config_compose_one", one == "bandits=2", one)
	var chase_order: Array[String] = ["chase", "chasing"]
	var skipped: String = EventConfig.compose({"chase": " ", "chasing": "target"}, chase_order)
	TestFixtures.check(res, "event_config_compose_blank", skipped == "chasing=target", skipped)
	var extra: String = EventConfig.compose({"zeta": "1", "chasing": "mercs", "chase": "foot"}, chase_order)
	TestFixtures.check(res, "event_config_compose_extra", extra == "chase=foot; chasing=mercs; zeta=1", extra)
	var chase: String = EventConfig.compose(EventConfig.defaults("Chase"), EventConfig.keys("Chase"))
	TestFixtures.check(res, "event_config_compose_defaults", chase == "chase=foot; chasing=mercs"
		and EventConfig.default_cell("Chase") == chase, chase)
	var bandits: String = EventConfig.default_cell("Fight Bandits")
	TestFixtures.check(res, "event_config_default_cell", bandits == "bandits=1" and EventConfig.default_cell("Battle") == ""
		and EventConfig.default_cell("Prison Break") == "", bandits)
	var again: String = EventConfig.compose(EventConfig.parse("chasing=target; chase=vehicle"), chase_order)
	TestFixtures.check(res, "event_config_compose_parsed", again == "chase=vehicle; chasing=target", again)


#EventConfig.fields, keys and PLANNED: the table per event, and copies a caller may change freely.
static func _case_event_config_fields(res: Dictionary) -> void:
	var bandits: Array[Dictionary] = EventConfig.fields("Fight Bandits")
	var field: Dictionary = bandits[0] if bandits.size() == 1 else {}
	TestFixtures.check(res, "event_config_fields_bandits", String(field.get("key", "")) == "bandits"
		and String(field.get("kind", "")) == EventConfig.KIND_MULTIPLIER and String(field.get("default", "")) == "1"
		and is_equal_approx(float(field.get("min", 0.0)), 0.5) and is_equal_approx(float(field.get("max", 0.0)), 4.0)
		and is_equal_approx(float(field.get("step", 0.0)), 0.5), str(bandits))
	var soldiers: Array[Dictionary] = EventConfig.fields("Military Battle")
	TestFixtures.check(res, "event_config_fields_soldiers", soldiers.size() == 1
		and String(soldiers[0]["key"]) == "soldiers" and String(soldiers[0]["label"]) == "Soldier multiplier",
		str(soldiers))
	var chase: Array[Dictionary] = EventConfig.fields("Chase")
	var kinds: Array[String] = []
	for one: Dictionary in chase:
		kinds.append("%s %s %s" % [String(one["key"]), String(one["kind"]), String(one["default"])])
	var want: Array[String] = ["chase choice foot", "chasing choice mercs"]
	TestFixtures.check(res, "event_config_fields_chase", kinds == want, ", ".join(kinds))
	TestFixtures.check(res, "event_config_fields_empty", EventConfig.fields("Prison Break").is_empty()
		and EventConfig.fields("Nope").is_empty() and EventConfig.keys("Nope").is_empty(),
		"Prison Break and Nope list no fields")
	var keys: Array[String] = EventConfig.keys("Chase")
	var key_order: Array[String] = ["chase", "chasing"]
	TestFixtures.check(res, "event_config_keys_order", keys == key_order, ", ".join(keys))
	var planned: Array[String] = ["Fight Bandits", "Military Battle", "Prison Break", "Chase"]
	TestFixtures.check(res, "event_config_planned", EventConfig.PLANNED == planned
		and EventConfig.FIELDS.has("Prison Break") and not EventConfig.FIELDS.has("Fight Monsters"),
		", ".join(EventConfig.PLANNED))
	if chase.size() == 2:
		chase[0]["default"] = "vehicle"
		(chase[1]["options"] as Array).append("nobody")
	chase.clear()
	var fresh: Array[Dictionary] = EventConfig.fields("Chase")
	TestFixtures.check(res, "event_config_fields_copy", fresh.size() == 2 and String(fresh[0]["default"]) == "foot"
		and (fresh[1]["options"] as Array).size() == 2, str(fresh))


#EventConfig.validate: the cells that pass, then one failure per reason with its exact text.
static func _case_event_config_validate(res: Dictionary) -> void:
	var passing: Array = [["Fight Bandits", ""], ["Fight Bandits", "bandits=1"], ["Fight Bandits", "bandits=2.5"],
		["Chase", "chase=vehicle"], ["Chase", "chase=foot; chasing=target"], ["Chase", "chasing=mercs"],
		["Military Battle", " soldiers = 4 ;"], ["Nope", ""], ["Prison Break", " "], ["Prison Break", ";"],
		["Nope", " ; "]]
	var refused: Array[String] = []
	for item: Array in passing:
		var reason: String = EventConfig.validate(String(item[0]), String(item[1]))
		if reason != "":
			refused.append("%s [%s]: %s" % [String(item[0]), String(item[1]), reason])
	TestFixtures.check(res, "event_config_validate_ok", refused.is_empty(),
		TestFixtures.detail(refused, passing.size(), "cells refused"))
	var range_text: String = "must be 0.5 to 4 in steps of 0.5"
	var failing: Array = [["pair", "Fight Bandits", "bandits=1; oops", "bad pair oops"],
		["key", "Fight Bandits", "bandits=2; monsters=all", "Fight Bandits has no option monsters"],
		["no_fields", "Prison Break", "guards=2", "Prison Break takes no Event Config"],
		["unknown_event", "Nope", "bandits=1", "Nope takes no Event Config"],
		["number", "Fight Bandits", "bandits=many", "bandits " + range_text],
		["below", "Fight Bandits", "bandits=0", "bandits " + range_text],
		["above", "Military Battle", "soldiers=4.5", "soldiers " + range_text],
		["grid", "Fight Bandits", "bandits=1.3", "bandits " + range_text],
		["choice", "Chase", "chase=horse", "chase must be foot or vehicle"],
		["choice_second", "Chase", "chase=foot; chasing=nobody", "chasing must be mercs or target"],
		["no_fields_pair", "Prison Break", "oops", "bad pair oops"],
		["unknown_event_pair", "Nope", "oops", "Nope takes no Event Config"],
		["blank_key", "Fight Bandits", "=5", "bad pair =5"],
		["repeat", "Fight Bandits", "bandits=1; bandits=2", "repeated option bandits"],
		["repeat_case", "Chase", "chase=foot; CHASE=foot", "repeated option chase"],
		["near_grid", "Fight Bandits", "bandits=1.000001", "bandits " + range_text],
		["exponent", "Fight Bandits", "bandits=1e", "bandits " + range_text],
		["plus", "Military Battle", "soldiers=+2", "soldiers " + range_text],
		["bare_point", "Fight Bandits", "bandits=1.", "bandits " + range_text]]
	for item: Array in failing:
		var got: String = EventConfig.validate(String(item[1]), String(item[2]))
		TestFixtures.check(res, "event_config_validate_" + String(item[0]), got == String(item[3]), got)


#EventConfig.format_number and parse_number, and the value readers, which fall back to the field default.
static func _case_event_config_numbers(res: Dictionary) -> void:
	var texts: Array[String] = [EventConfig.format_number(1.0), EventConfig.format_number(1.5),
		EventConfig.format_number(2.0), EventConfig.format_number(0.5)]
	var want: Array[String] = ["1", "1.5", "2", "0.5"]
	TestFixtures.check(res, "event_config_format_number", texts == want, ", ".join(texts))
	var parsed: float = EventConfig.parse_number("2.5")
	TestFixtures.check(res, "event_config_parse_number", is_equal_approx(parsed, 2.5)
		and is_nan(EventConfig.parse_number("x")) and is_nan(EventConfig.parse_number("")), str(parsed))
	var loose: Array[String] = []
	for text: String in ["1e", "+2", "1.", ".5", "1e0", "0x2", "inf", "nan", "2,5"]:
		if not is_nan(EventConfig.parse_number(text)):
			loose.append(text)
	TestFixtures.check(res, "event_config_parse_number_plain", loose.is_empty()
		and EventConfig.parse_number("-1.5") == -1.5 and EventConfig.parse_number(" 4 ") == 4.0,
		"read as numbers: %s" % ", ".join(loose))
	var near: float = EventConfig.multiplier_value("Fight Bandits", "bandits", "bandits=1.000001")
	var half: float = EventConfig.multiplier_value("Military Battle", "soldiers", "soldiers=0.5")
	TestFixtures.check(res, "event_config_multiplier_grid", near == 1.0 and half == 0.5, "%s, %s" % [near, half])
	var good: float = EventConfig.multiplier_value("Fight Bandits", "bandits", "bandits=2.5")
	var fallback: float = EventConfig.multiplier_value("Fight Bandits", "bandits", "bandits=9")
	var missing: float = EventConfig.multiplier_value("Military Battle", "soldiers", "")
	TestFixtures.check(res, "event_config_multiplier_value", is_equal_approx(good, 2.5)
		and is_equal_approx(fallback, 1.0) and is_equal_approx(missing, 1.0), "%s, %s, %s" % [good, fallback, missing])
	var picked: String = EventConfig.choice_value("Chase", "chasing", "chase=foot; chasing=target")
	var bad_choice: String = EventConfig.choice_value("Chase", "chase", "chase=horse")
	var unset: String = EventConfig.choice_value("Chase", "chasing", "")
	TestFixtures.check(res, "event_config_choice_value", picked == "target" and bad_choice == "foot" and unset == "mercs",
		"%s, %s, %s" % [picked, bad_choice, unset])
	TestFixtures.check(res, "event_config_value_other_kind",
		is_nan(EventConfig.multiplier_value("Chase", "chase", "chase=foot"))
		and EventConfig.choice_value("Fight Bandits", "bandits", "bandits=2") == "",
		"a key of the other kind reads as NAN or blank")


#The Events.tsv readers on the copy: the Primary names in sheet order, the planned names after them, is_planned, an
#appended Primary row read at the end, a repeated name kept once, and reset_paths back on the res:// constant.
static func _case_builder_data_events(res: Dictionary) -> void:
	var names: Array[String] = ContractBuilderData.event_names()
	var primary: Array[String] = ["Poison the Target", "Put on a Show", "Deliver the Prisoner", "Identify the Killer",
		"Assist with the Skirmish", "Slay the Monster", "Save the Trapped Civilian", "Dig up the Buried Treasure",
		"Battle", "Competition", "Rescue the Captive"]
	TestFixtures.check(res, "builder_data_event_names", names == primary, ", ".join(names))
	var other: Array[String] = []
	for row: Dictionary in TsvReader.load_header_rows(ContractBuilderData.events_path):
		var row_name: String = String(row.get("Event Name", ""))
		if String(row.get("Event Type", "")) != "Primary" and row_name != "":
			other.append(row_name)
	var leaked: Array[String] = []
	for row_name: String in other:
		if names.has(row_name):
			leaked.append(row_name)
	TestFixtures.check(res, "builder_data_event_primary_only", other.size() == 8 and leaked.is_empty(),
		"%d other rows; leaked: %s" % [other.size(), ", ".join(leaked)])
	var options: Array[String] = ContractBuilderData.event_options()
	var head: Array[String] = []
	head.assign(options.slice(0, names.size()))
	var tail: Array[String] = []
	tail.assign(options.slice(names.size()))
	TestFixtures.check(res, "builder_data_event_options", head == names and tail == EventConfig.PLANNED,
		", ".join(tail))
	TestFixtures.check(res, "builder_data_is_planned", ContractBuilderData.is_planned("Chase")
		and not ContractBuilderData.is_planned("Battle") and not ContractBuilderData.is_planned("Ghost"),
		"Chase planned; Battle and Ghost not")
	var cells: Array[String] = _cells(13, "Test Event")
	cells[1] = "Primary"
	var appended: Dictionary = TsvRowWriter.append_row(ContractBuilderData.events_path, cells)
	var after: Array[String] = ContractBuilderData.event_names()
	TestFixtures.check(res, "builder_data_event_appended", bool(appended["ok"]) and after.size() == 12
		and after[after.size() - 1] == "Test Event" and ContractBuilderData.event_options().size() == 16,
		"%s; %s" % [_result_text(appended), ", ".join(after)])
	var repeat: Array[String] = _cells(13, "Battle")
	repeat[1] = "Primary"
	var repeated: Dictionary = TsvRowWriter.append_row(ContractBuilderData.events_path, repeat)
	var kept: Array[String] = ContractBuilderData.event_names()
	TestFixtures.check(res, "builder_data_event_repeat", bool(repeated["ok"]) and kept == after,
		"%s; %d names" % [_result_text(repeated), kept.size()])
	ContractBuilderData.events_path = SCRATCH_DIR + "/f.tsv"
	ContractBuilderData.reset_paths()
	TestFixtures.check(res, "builder_data_events_reset", ContractBuilderData.events_path == ContractBuilderData.EVENTS_PATH,
		ContractBuilderData.events_path)


#A _writer_draft under Style event with the Completion, Time and Consequence the event cases pass with.
static func _event_draft(title: String) -> ContractDraft:
	var draft: ContractDraft = _writer_draft(title)
	draft.style = "event"
	draft.completion = "event:Battle"
	draft.time = 90
	draft.consequence = "hp -2, guild -1"
	return draft


#check() runs the event rules after the check rules: each failure with its text, the first rule first, a Completion
#other than event:<name> refused and not written, then the drafts that pass, an event name Events.tsv lacks among them.
static func _case_writer_event_rules(res: Dictionary) -> void:
	var draft: ContractDraft = _event_draft("Lamp Event")
	draft.completion = ""
	var reason: String = ContractRowWriter.check(draft)
	TestFixtures.check(res, "writer_event_completion_empty", reason == ContractRowWriter.EVENT_COMPLETION_EMPTY
		and reason == "Completion is empty: Style event needs an event", reason)
	draft.time = -1
	draft.consequence = "hp -10"
	reason = ContractRowWriter.check(draft)
	TestFixtures.check(res, "writer_event_first_rule", reason == ContractRowWriter.EVENT_COMPLETION_EMPTY, reason)
	var expected: String = "Completion: expected event:<name> under Style event, got "
	var malformed: Array = [["event:", ContractRowWriter.EVENT_COMPLETION_EMPTY],
		[" event:  ", ContractRowWriter.EVENT_COMPLETION_EMPTY], ["Battle", expected + "Battle"],
		["EVENT:Chase", expected + "EVENT:Chase"], ["a=1:2", expected + "a=1:2"],
		["Fight Bandits", expected + "Fight Bandits"]]
	var misjudged: Array[String] = []
	for item: Array in malformed:
		draft = _event_draft("Lamp Event")
		draft.completion = String(item[0])
		draft.event_config = "bandits=2"
		reason = ContractRowWriter.check(draft)
		if reason != String(item[1]):
			misjudged.append("[%s]: %s" % [String(item[0]), reason])
	TestFixtures.check(res, "writer_event_completion_malformed", misjudged.is_empty(),
		TestFixtures.detail(misjudged, malformed.size(), "completions misjudged"))
	draft = _event_draft("Lamp Event")
	draft.completion = "Battle"
	var sheet_before: PackedByteArray = _bytes_of(ContractBuilderData.contracts_path)
	var refused: Dictionary = ContractRowWriter.write(draft)
	TestFixtures.check(res, "writer_event_completion_write_refused", not bool(refused["ok"])
		and String(refused["error"]) == ContractRowWriter.EVENT_COMPLETION_EXPECTED % "Battle"
		and _bytes_of(ContractBuilderData.contracts_path) == sheet_before, _written_text(refused))
	draft = _event_draft("Lamp Event")
	draft.style = "check"
	reason = ContractRowWriter.check(draft)
	TestFixtures.check(res, "writer_event_style", reason == "Completion names an event but Style is check", reason)
	draft.style = "timeline"
	reason = ContractRowWriter.check(draft)
	TestFixtures.check(res, "writer_event_style_timeline", reason == "Completion names an event but Style is timeline",
		reason)
	draft = _event_draft("Lamp Event")
	draft.completion = "event:Chase"
	draft.event_config = "chase=horse"
	reason = ContractRowWriter.check(draft)
	TestFixtures.check(res, "writer_event_config", reason == "Event Config: chase must be foot or vehicle", reason)
	draft.completion = "event:Battle"
	draft.event_config = "bandits=1"
	reason = ContractRowWriter.check(draft)
	TestFixtures.check(res, "writer_event_config_no_fields", reason == "Event Config: Battle takes no Event Config", reason)
	draft = _writer_draft("Lamp Event")
	draft.event_config = "bandits=1"
	reason = ContractRowWriter.check(draft)
	TestFixtures.check(res, "writer_event_config_style", reason == "Event Config is set but Style is check", reason)
	draft = _event_draft("Lamp Event")
	draft.time = -1
	reason = ContractRowWriter.check(draft)
	TestFixtures.check(res, "writer_event_time", reason == ContractRowWriter.TIME_NEGATIVE
		and reason == "Time must be 0 or more minutes", reason)
	draft = _event_draft("Lamp Event")
	draft.consequence = "hp -10"
	reason = ContractRowWriter.check(draft)
	TestFixtures.check(res, "writer_event_consequence", reason == "Consequence: bad token hp -10", reason)
	draft = _event_draft("Lamp Event")
	reason = ContractRowWriter.check(draft)
	TestFixtures.check(res, "writer_event_pass_battle", reason == "", reason)
	draft.completion = "event:Ghost"
	reason = ContractRowWriter.check(draft)
	TestFixtures.check(res, "writer_event_pass_unknown", reason == "", reason)
	draft.completion = "event:Fight Bandits"
	draft.event_config = "bandits=2"
	reason = ContractRowWriter.check(draft)
	TestFixtures.check(res, "writer_event_pass_planned", reason == "", reason)


#The passing event draft written to the copies: its four event cells read back, from_row restores them, no Checks.tsv
#row is appended and the res:// sheets keep their bytes.
static func _case_writer_event_round_trip(res: Dictionary) -> void:
	var sums: Dictionary = _sheet_sums()
	var checks: PackedByteArray = _bytes_of(ContractBuilderData.checks_path)
	var check_rows: int = ContractBuilderData.check_rows().size()
	var lines: int = _text_of(ContractBuilderData.contracts_path).split("\n", false).size()
	var written: Dictionary = ContractRowWriter.write(_event_draft("Lamp Event"))
	TestFixtures.check(res, "writer_event_round_trip_ok", bool(written["ok"]) and int(written["line"]) == lines
		and TsvRowWriter.find_row(ContractBuilderData.contracts_path, 0, "Lamp Event") == lines
		and not bool(written["check"]), "%s; want line %d" % [_written_text(written), lines])
	var row: Dictionary = ContractBuilderData.contract_row("Lamp Event")
	var cells: Array[String] = [String(row.get("Completion", "")), String(row.get("Event Config", "")),
		String(row.get("Time", "")), String(row.get("Consequence", ""))]
	var want: Array[String] = ["event:Battle", "", "90", "hp -2, guild -1"]
	TestFixtures.check(res, "writer_event_round_trip_cells", cells == want, " | ".join(cells))
	var back: ContractDraft = ContractDraft.new()
	back.from_row(row)
	TestFixtures.check(res, "writer_event_round_trip_draft", back.time == 90 and back.consequence == "hp -2, guild -1"
		and back.completion == "event:Battle" and back.style == "event" and back.event_config == "",
		"time %d, consequence %s" % [back.time, back.consequence])
	var rows_after: int = ContractBuilderData.check_rows().size()
	TestFixtures.check(res, "writer_event_round_trip_no_check", _bytes_of(ContractBuilderData.checks_path) == checks
		and rows_after == check_rows, "%d Checks.tsv rows, %d before" % [rows_after, check_rows])
	TestFixtures.check(res, "writer_event_round_trip_res", _sheet_sums() == sums
		and ContractBuilderData.contracts_path != ContractBuilderData.CONTRACTS_PATH, "the res:// sheets keep their bytes")


#Each entry [name, [[cell, wanted TimelineGrammar.error], ...]] is one check that passes when every cell gives its text.
static func _tl_table(res: Dictionary, table: Array) -> void:
	for entry: Array in table:
		var off: Array[String] = []
		for pair: Array in (entry[1] as Array):
			var got: String = TimelineGrammar.error(String(pair[0]))
			if got != String(pair[1]):
				off.append("[%s]: %s" % [String(pair[0]), got])
		TestFixtures.check(res, String(entry[0]), off.is_empty(),
			TestFixtures.detail(off, (entry[1] as Array).size(), "cells misjudged"))


#Every field of every step, typed included, for field-by-field compares.
static func _tl_fields(steps: Array) -> String:
	var parts: PackedStringArray = []
	for item: Variant in steps:
		var s: TimelineGrammar.Step = item
		parts.append("%s|%s|%s|%s|%s|%s|%s|%d|%s|%s|%s" % [s.id, s.kind, s.name, s.if_id, s.if_outcome, str(s.fail),
			s.role, s.time, s.cons, s.cfg, str(s.typed)])
	return " / ".join(parts)


static func _tl_format(cell: String) -> String:
	return TimelineGrammar.format(TimelineGrammar.parse(cell))


#The parse of single cells and the P78 example, canonical format, round trips, and cons and cfg normalizing.
static func _case_timeline_parse(res: Dictionary) -> void:
	var one: Array = TimelineGrammar.parse("a=event:Fight Bandits")
	TestFixtures.check(res, "tl_parse_single", _tl_fields(one) == "a|event|Fight Bandits|||false||0|||false"
		and TimelineGrammar.syntax_error("a=event:Fight Bandits") == "", _tl_fields(one))
	var p78: Array = TimelineGrammar.parse(TL_P78)
	var shaped: bool = p78.size() == 4
	if shaped:
		var a: TimelineGrammar.Step = p78[0]
		var b1: TimelineGrammar.Step = p78[1]
		var b2: TimelineGrammar.Step = p78[2]
		var c: TimelineGrammar.Step = p78[3]
		shaped = a.id == "a" and a.name == "Fight Bandits" and a.time == 120 and b1.id == "b1" and b1.if_id == "a" \
			and b1.if_outcome == "failure" and b1.cfg == "chase=vehicle; chasing=mercs" and b2.kind == "check" \
			and b2.role == "Leader" and b2.if_outcome == "success" and c.kind == "check" and c.name == "Deliver" \
			and c.fail and not c.typed
	var literal: String = ("a=event:Fight Bandits; b1=event:Chase if a.failure; b2=check:Interrogate if a.success role=Leader; "
		+ "c=check:Deliver fail")
	var literal_ids: Array[String] = []
	for item: Variant in TimelineGrammar.parse(literal):
		var step: TimelineGrammar.Step = item
		if not step.typed:
			literal_ids.append(step.id)
	shaped = shaped and TimelineGrammar.error(literal) == "" and literal_ids == ["a", "b1", "b2", "c"]
	TestFixtures.check(res, "tl_parse_example_p78", shaped and TimelineGrammar.error(TL_P78) == "", _tl_fields(p78))
	var shuffled: String = "a=event:Chase cfg=chase=vehicle time=30 ; b=check:Deliver role=Leader fail"
	var ordered: String = _tl_format(shuffled)
	TestFixtures.check(res, "tl_parse_any_token_order", TimelineGrammar.error(shuffled) == ""
		and ordered == "a=event:Chase time=30 cfg=chase=vehicle,chasing=mercs ; b=check:Deliver fail role=Leader", ordered)
	TestFixtures.check(res, "tl_format_canonical", _tl_format(TL_P78) == TL_P78, _tl_format(TL_P78))
	var messy: String = ("a=event:Fight Bandits  time=120;b1=event:Chase   if a.failure cfg=chasing=target ;  "
		+ "c=check:Deliver fail")
	var tidy: String = _tl_format(messy)
	TestFixtures.check(res, "tl_round_trip_idempotent", _tl_format(tidy) == tidy and tidy == "a=event:Fight Bandits "
		+ "time=120 ; b1=event:Chase if a.failure cfg=chase=foot,chasing=target ; c=check:Deliver fail", tidy)
	TestFixtures.check(res, "tl_round_trip_fields", _tl_fields(TimelineGrammar.parse(messy))
		== _tl_fields(TimelineGrammar.parse(tidy)) and _tl_fields(p78) == _tl_fields(TimelineGrammar.parse(_tl_format(TL_P78))),
		_tl_fields(TimelineGrammar.parse(tidy)))
	var reordered: String = "a=event:A cons=guild, hp -2 ; b=event:B fail"
	var cons_out: String = _tl_format(reordered)
	var cons_steps: Array = TimelineGrammar.parse(reordered)
	TestFixtures.check(res, "tl_round_trip_cons_reorder", cons_out == "a=event:A cons=hp -2, guild -1 ; b=event:B fail"
		and _tl_format(cons_out) == cons_out and (cons_steps[0] as TimelineGrammar.Step).cons == "hp -2, guild -1", cons_out)
	var partial: String = "a=event:Chase cfg=chasing=target ; b=event:B fail"
	var partial_out: String = _tl_format(partial)
	var partial_steps: Array = TimelineGrammar.parse(partial)
	TestFixtures.check(res, "tl_round_trip_cfg_partial", partial_out == "a=event:Chase cfg=chase=foot,chasing=target ; "
		+ "b=event:B fail" and _tl_format(partial_out) == partial_out
		and (partial_steps[0] as TimelineGrammar.Step).cfg == "chase=foot; chasing=target", partial_out)
	var blank: String = "a=event: ; b=event: fail"
	var blank_steps: Array = TimelineGrammar.parse(blank)
	TestFixtures.check(res, "tl_parse_empty_name_round_trip", TimelineGrammar.syntax_error(blank) == ""
		and blank_steps.size() == 2 and (blank_steps[1] as TimelineGrammar.Step).name == ""
		and (blank_steps[1] as TimelineGrammar.Step).fail and _tl_format(blank) == blank
		and TimelineGrammar.rule_error(blank_steps) == "Step a: pick an event or a check", _tl_format(blank))
	var multi: String = "a=event:A cons=retry -1, hp -2, ep, mp -9, guild -3 ; b=event:B fail"
	var multi_steps: Array = TimelineGrammar.parse(multi)
	var multi_cons: String = (multi_steps[0] as TimelineGrammar.Step).cons if multi_steps.size() == 2 else ""
	TestFixtures.check(res, "tl_cons_multi_kind", TimelineGrammar.error(multi) == ""
		and multi_cons == "retry -1, hp -2, ep -1, mp -9, guild -3", multi_cons)
	var defaults: Array[String] = [_tl_format("a=event:Chase cfg=chase=foot,chasing=mercs ; b=event:B fail"),
		_tl_format("a=event:Chase cfg=chase=foot ; b=event:B fail")]
	TestFixtures.check(res, "tl_cfg_default_omitted", defaults[0] == "a=event:Chase ; b=event:B fail"
		and defaults[1] == defaults[0], " | ".join(defaults))


#Every syntax and rule text of TimelineGrammar.error, one check per name.
static func _case_timeline_errors(res: Dictionary) -> void:
	var tail: String = " ; b=event:B fail"
	var bad_id: String = "Step %d: bad id %s (1 to 12 letters, digits or _, starting with a letter)"
	var shape: String = "Step 1: expected <id>=<kind>:<name>, got %s"
	var time_text: String = "Step a: time must be whole minutes from 1 to 1438560, got %s"
	var if_text: String = "Step b: if must be <id>.success or <id>.failure, got %s"
	var table: Array = [
		["tl_err_empty", [["", "Timeline is empty"], ["   ", "Timeline is empty"]]],
		["tl_err_empty_step", [["a=event:A ; ; b=event:B fail", "Step 2 is empty"], ["a=event:A ;", "Step 2 is empty"]]],
		["tl_err_shape", [["a event:A" + tail, shape % "a event:A"], ["a=eventA" + tail, shape % "a=eventA"]]],
		["tl_err_spaces_in_head", [["a =event:A" + tail, shape % "a =event:A"],
			["a=event :A" + tail, shape % "a=event :A"]]],
		["tl_err_bad_id", [["1a=event:A" + tail, bad_id % [1, "1a"]], ["a=event:A ; b-c=event:B fail", bad_id % [2, "b-c"]]]],
		["tl_err_reserved_id", [["if=event:A" + tail, "Step 1: id if is a reserved word"],
			["a=event:A ; cfg=event:B fail", "Step 2: id cfg is a reserved word"]]],
		["tl_err_dup_id", [["a=event:A ; a=event:B fail", "Step id a is used twice"]]],
		["tl_err_kind", [["a=quest:A" + tail, "Step a: kind must be check or event, got quest"]]],
		["tl_err_kind_case", [["a=Event:A" + tail, "Step a: kind must be check or event, got Event"]]],
		["tl_err_unknown_token", [["a=event:A fail extra" + tail, "Step a: unknown token extra"]]],
		["tl_err_repeat_token", [["a=event:A time=5 time=6" + tail, "Step a: repeated token time"],
			["a=event:A ; b=event:B fail fail", "Step b: repeated token fail"]]],
		["tl_err_role_form", [["a=event:A role=Lead_er" + tail, "Step a: role must be one word of letters, got Lead_er"],
			["a=event:A role=Lead er" + tail, "Step a: unknown token er"]]],
		["tl_err_if_form", [["a=event:A ; b=event:B if a.maybe ; c=event:C fail", if_text % "a.maybe"],
			["a=event:A ; b=event:B if ; c=event:C fail", if_text % "nothing"]]],
		["tl_err_if_forward", [["a=event:A if b.success ; b=event:B fail",
			"Step a: if names b, which is not an earlier step"]]],
		["tl_err_if_self", [["a=event:A ; b=event:B if b.success ; c=event:C fail",
			"Step b: if names b, which is not an earlier step"]]],
		["tl_err_time_zero", [["a=event:A time=0" + tail, time_text % "0"], ["a=event:A time=012" + tail, time_text % "012"]]],
		["tl_err_time_text", [["a=event:A time=abc" + tail, time_text % "abc"], ["a=event:A time=-5" + tail, time_text % "-5"],
			["a=event:A time=+5" + tail, time_text % "+5"], ["a=event:A time=1.5" + tail, time_text % "1.5"]]],
		["tl_err_time_max", [["a=event:A time=1438561" + tail, time_text % "1438561"], ["a=event:A time=1438560" + tail, ""]]],
		["tl_err_cons_token", [["a=event:A cons=hp -10" + tail, "Step a: bad consequence token hp -10"],
			["a=event:A cons=xp -1" + tail, "Step a: bad consequence token xp -1"],
			["a=event:A cons=hp 0" + tail, "Step a: bad consequence token hp 0"]]],
		["tl_err_cons_repeat_kind", [["a=event:A cons=hp -1, hp -2" + tail, "Step a: repeated consequence kind hp"]]],
		["tl_err_check_time", [["a=check:Scout time=30" + tail,
			"Step a: a check step takes no time (the check row carries it)"],
			["a=check:Scout cons=hp -1" + tail, "Step a: a check step takes no cons (the check row carries it)"]]],
		["tl_err_check_cfg", [["a=check:Scout cfg=bandits=2" + tail, "Step a: a check step takes no cfg"],
			["a=check:Chase cfg=chase=foot" + tail, "Step a: a check step takes no cfg"]]],
		["tl_cfg_validate", [["a=event:Chase cfg=chase=horse" + tail, "Step a: Event Config: chase must be foot or vehicle"],
			["a=event:Battle cfg=bandits=2" + tail, "Step a: Event Config: Battle takes no Event Config"],
			["a=event:Fight Bandits cfg=bandits=2" + tail, ""]]],
		["tl_err_cfg_shape", [["a=event:Chase cfg=chase" + tail, "Step a: bad cfg chase"],
			["a=event:Chase cfg=chase=" + tail, "Step a: bad cfg chase="],
			["a=event:Chase cfg=chase=foot,chase=vehicle" + tail, "Step a: bad cfg chase=foot,chase=vehicle"]]],
		["tl_err_min_steps", [["a=event:A fail", "Timeline needs at least 2 steps, has 1"]]],
		["tl_err_last_if", [["a=event:A ; b=event:B if a.success fail", "The last step b must not wait on another step"]]],
		["tl_err_last_fail", [["a=event:A ; b=event:B", "The last step b must carry fail"]]],
		["tl_err_dead_branch", [["a=event:A fail ; b=event:B if a.failure ; c=event:C fail",
			"Step b waits on a.failure, but a fails the contract"],
			["a=event:A fail ; b=event:B if a.success ; c=event:C fail", ""]]],
		["tl_rule_name_empty", [["a=event:" + tail, "Step a: pick an event or a check"],
			["a=event:A ; b=check: fail", "Step b: pick an event or a check"],
			["a=event:x=y" + tail, "Step a: name x=y cannot be a step (holds =)"]]],
		["tl_err_id_too_long", [["abcdefghijklm=event:A" + tail, bad_id % [1, "abcdefghijklm"]]]],
		["tl_err_reserved_id_new_words", [["event=event:A" + tail, "Step 1: id event is a reserved word"],
			["check=event:A" + tail, "Step 1: id check is a reserved word"],
			["success=event:A" + tail, "Step 1: id success is a reserved word"],
			["failure=event:A" + tail, "Step 1: id failure is a reserved word"]]],
		["tl_id_case_sensitive_unique", [["A=event:X ; a=event:Y fail", ""]]],
	]
	_tl_table(res, table)
	var steps: PackedStringArray = []
	for i: int in range(1, 13):
		steps.append("s%d=event:E%d" % [i, i])
	steps.append("z=event:Z fail")
	var thirteen: String = TimelineGrammar.SEP.join(steps)
	steps.remove_at(0)
	var twelve: String = TimelineGrammar.SEP.join(steps)
	TestFixtures.check(res, "tl_err_max_steps", TimelineGrammar.error(thirteen) == "Timeline holds 13 steps; the most is 12"
		and TimelineGrammar.error(twelve) == "", "%s | %s" % [TimelineGrammar.error(thirteen), TimelineGrammar.error(twelve)])


#name_reason and the names the tokenizer ends or keeps.
static func _case_timeline_names(res: Dictionary) -> void:
	var reasons: Array[String] = [TimelineGrammar.name_reason("A;B"), TimelineGrammar.name_reason("A=B"),
		TimelineGrammar.name_reason("Go if ready"), TimelineGrammar.name_reason("Do or fail"),
		TimelineGrammar.name_reason("Plain")]
	TestFixtures.check(res, "tl_name_reason_four", " | ".join(reasons) == "holds ; | holds = | holds the word if | "
		+ "holds the word fail | ", " | ".join(reasons))
	var ends: String = TimelineGrammar.error("a=event:Stop if ; b=event:X fail")
	TestFixtures.check(res, "tl_name_ends_with_if", TimelineGrammar.name_reason("Stop if") == "holds the word if"
		and ends == "Step a: if must be <id>.success or <id>.failure, got nothing", ends)
	var safe: String = TimelineGrammar.error("a=event:Failsafe ; b=event:Fail fail")
	TestFixtures.check(res, "tl_name_failsafe_ok", safe == "" and TimelineGrammar.name_reason("Failsafe") == ""
		and TimelineGrammar.name_reason("fails") == "", safe)
	var cased: String = TimelineGrammar.error("a=event:Stop If ; b=event:X fail")
	TestFixtures.check(res, "tl_name_case_if_ok", cased == "" and TimelineGrammar.name_reason("Stop If") == "", cased)


#renumber over branch runs and the walk of runs() (D156).
static func _case_timeline_walk(res: Dictionary) -> void:
	var branches: Array = TimelineGrammar.parse("a=event:A ; q=event:B if a.success ; r=event:C if a.failure ; s=event:D fail")
	TimelineGrammar.renumber(branches)
	var renumbered: String = TimelineGrammar.format(branches)
	TestFixtures.check(res, "tl_renumber_branches",
		renumbered == "a=event:A ; b1=event:B if a.success ; b2=event:C if a.failure ; c=event:D fail", renumbered)
	var plain: Array = TimelineGrammar.parse("a=event:A ; b=event:B ; c=event:C fail")
	var plain_runs: Array[bool] = [TimelineGrammar.runs(plain, 0, {}), TimelineGrammar.runs(plain, 1, {"a": "success"}),
		TimelineGrammar.runs(plain, 1, {"a": "failure"}), TimelineGrammar.runs(plain, 2, {"a": "failure", "b": "failure"})]
	TestFixtures.check(res, "tl_runs_default_path", not plain_runs.has(false), str(plain_runs))
	var branch: Array = TimelineGrammar.parse("a=event:A ; b=event:B ; c=event:C if a.failure ; d=event:D fail")
	var failed: Dictionary = {"a": "failure", "b": "success"}
	var passed: Dictionary = {"a": "success", "b": "success"}
	var branch_runs: Array[bool] = [TimelineGrammar.runs(branch, 1, {"a": "failure"}), TimelineGrammar.runs(branch, 2, failed),
		TimelineGrammar.runs(branch, 3, {"a": "failure", "b": "success", "c": "success"}),
		not TimelineGrammar.runs(branch, 2, passed), TimelineGrammar.runs(branch, 3, passed)]
	TestFixtures.check(res, "tl_runs_branch_failure", not branch_runs.has(false), str(branch_runs))
	var flagged: Array = TimelineGrammar.parse("a=event:A fail ; b=event:B ; c=event:C fail")
	var flagged_runs: Array[bool] = [not TimelineGrammar.runs(flagged, 1, {"a": "failure"}),
		not TimelineGrammar.runs(flagged, 2, {"a": "failure"}), TimelineGrammar.runs(flagged, 1, {"a": "success"})]
	TestFixtures.check(res, "tl_runs_flagged_failure_ends", not flagged_runs.has(false), str(flagged_runs))


#Typed and auto ids (D141, J4): the typed flag on parse, renumber skips, set_id rewrites, refusals and clearing.
static func _case_timeline_ids(res: Dictionary) -> void:
	var typed: Array = TimelineGrammar.parse("Fight=event:A ; Chase_2=event:B ; abcdefghijkl=event:C fail")
	var all_typed: bool = typed.size() == 3
	for item: Variant in typed:
		all_typed = all_typed and (item as TimelineGrammar.Step).typed
	for item: Variant in TimelineGrammar.parse(TL_P78):
		all_typed = all_typed and not (item as TimelineGrammar.Step).typed
	TestFixtures.check(res, "tl_parse_typed_ids", all_typed
		and TimelineGrammar.error("Fight=event:A ; Chase_2=event:B ; abcdefghijkl=event:C fail") == "", _tl_fields(typed))
	var flags: Array[bool] = []
	for item: Variant in TimelineGrammar.parse("fight=event:A ; b2=event:B ; z=event:C fail"):
		flags.append((item as TimelineGrammar.Step).typed)
	TestFixtures.check(res, "tl_parse_typed_flag", str(flags) == str([true, false, false]), str(flags))
	var intro: Array = TimelineGrammar.parse("a=event:A ; Intro=event:B ; x=event:C ; y=event:D if x.success ; "
		+ "z=event:E if x.failure ; w=event:F fail")
	TimelineGrammar.renumber(intro)
	var zero: Array = TimelineGrammar.parse("a0=event:A ; x=event:B ; y=event:C fail")
	TimelineGrammar.renumber(zero)
	var skipped: Array[String] = [TimelineGrammar.format(intro), TimelineGrammar.format(zero)]
	TestFixtures.check(res, "tl_renumber_skips_typed", " | ".join(skipped) == "a=event:A ; Intro=event:B ; b=event:C ; "
		+ "c1=event:D if b.success ; c2=event:E if b.failure ; d=event:F fail | a0=event:A ; b=event:B ; c=event:C fail",
		" | ".join(skipped))
	var base: String = "a=event:A ; b1=event:B if a.success ; b2=event:C if a.failure ; c=event:D fail"
	var steps: Array = TimelineGrammar.parse(base)
	var set_reason: String = TimelineGrammar.set_id(steps, 0, "Intro")
	var named: String = TimelineGrammar.format(steps)
	TestFixtures.check(res, "tl_set_id_rewrites_refs", set_reason == "" and (steps[0] as TimelineGrammar.Step).typed
		and named == "Intro=event:A ; a1=event:B if Intro.success ; a2=event:C if Intro.failure ; b=event:D fail",
		"%s; %s" % [set_reason, named])
	var cleared: String = TimelineGrammar.set_id(steps, 0, "")
	TestFixtures.check(res, "tl_set_id_clear_returns_auto", cleared == "" and TimelineGrammar.format(steps) == base
		and not (steps[0] as TimelineGrammar.Step).typed, TimelineGrammar.format(steps))
	var held: Array = TimelineGrammar.parse("a=event:A ; Intro=event:B ; c=event:D fail")
	var before: String = TimelineGrammar.format(held)
	var refusals: Array = [["reserved", "fail", "fail is a reserved word"], ["used", "Intro", "Intro is used by step 2"],
		["form", "a-b", "use 1 to 12 letters, digits or _, starting with a letter"],
		["auto", "z", "z is an automatic id; leave the field blank for automatic numbering"]]
	for item: Array in refusals:
		var refused: String = TimelineGrammar.set_id(held, 0, String(item[1]))
		TestFixtures.check(res, "tl_set_id_refused_" + String(item[0]), refused == String(item[2])
			and TimelineGrammar.format(held) == before and not (held[0] as TimelineGrammar.Step).typed, refused)


#A _writer_draft under Style timeline whose Completion passes the timeline rules, with no pending timeline row.
static func _timeline_draft(title: String) -> ContractDraft:
	var draft: ContractDraft = _writer_draft(title)
	draft.style = "timeline"
	draft.completion = "a=event:Fight Bandits ; b=check:" + CHECK_NAME + " fail"
	return draft


#CHECK_CELLS renamed to check_name.
static func _timeline_row(check_name: String) -> Array[String]:
	var cells: Array[String] = _check_cells()
	cells[CheckSheet.NAME] = check_name
	return cells


static func _timeline_text(written: Dictionary) -> String:
	return "ok %s, check %s, timeline_checks %d, error %s" % [str(written.get("ok", false)), str(written.get("check", false)),
		int(written.get("timeline_checks", -1)), String(written.get("error", ""))]


#check() under Style timeline: each rule with its text, unknown names passing, then a clean draft written.
static func _case_writer_timeline_rules(res: Dictionary) -> void:
	var draft: ContractDraft = _timeline_draft("Lamp Path")
	draft.completion = ""
	var reason: String = ContractRowWriter.check(draft)
	TestFixtures.check(res, "writer_timeline_blank", reason == ContractRowWriter.TIMELINE_COMPLETION_EMPTY
		and reason == "Completion is empty: Style timeline needs at least 2 steps", reason)
	var grammar: Array = [["a=event:Fight Bandits", "Completion: Timeline needs at least 2 steps, has 1"],
		["if=event:A ; b=event:B fail", "Completion: Step 1: id if is a reserved word"],
		["a=event:A ; a=event:B fail", "Completion: Step id a is used twice"]]
	var off: Array[String] = []
	for item: Array in grammar:
		draft.completion = String(item[0])
		reason = ContractRowWriter.check(draft)
		if reason != String(item[1]):
			off.append("[%s]: %s" % [String(item[0]), reason])
	TestFixtures.check(res, "writer_timeline_grammar", off.is_empty(), TestFixtures.detail(off, grammar.size(), "misjudged"))
	draft.completion = "a=event: ; b=check:" + CHECK_NAME + " fail"
	reason = ContractRowWriter.check(draft)
	TestFixtures.check(res, "writer_timeline_name_empty", reason == "Completion: Step a: pick an event or a check", reason)
	draft.completion = "a=event:No Such Event ; b=check:No Such Check fail"
	reason = ContractRowWriter.check(draft)
	TestFixtures.check(res, "writer_timeline_unknown_names_pass", reason == "", reason)
	var roles: Array = [["Driver", [], "Completion: step a role Driver is not a role of this contract"],
		["Driver", ["Driver"], ""], ["Leader", [], ""], ["Support", [], ""],
		["Chef", ["Chef"], "Completion: step a role Chef is not a role of this contract"]]
	off.clear()
	for item: Array in roles:
		draft = _timeline_draft("Lamp Path")
		draft.completion = "a=event:Fight Bandits role=%s ; b=check:%s fail" % [String(item[0]), CHECK_NAME]
		var named: Array[String] = []
		named.assign(item[1])
		draft.roles = named
		reason = ContractRowWriter.check(draft)
		if reason != String(item[2]):
			off.append("%s with %s: %s" % [String(item[0]), str(item[1]), reason])
	TestFixtures.check(res, "writer_timeline_role_off_contract", off.is_empty(),
		TestFixtures.detail(off, roles.size(), "roles misjudged"))
	draft = _timeline_draft("Lamp Path")
	draft.time = 30
	reason = ContractRowWriter.check(draft)
	TestFixtures.check(res, "writer_timeline_row_time", reason == ContractRowWriter.TIMELINE_TIME
		and reason == "Time is set but Style is timeline", reason)
	draft = _timeline_draft("Lamp Path")
	draft.consequence = "hp -2"
	reason = ContractRowWriter.check(draft)
	TestFixtures.check(res, "writer_timeline_row_consequence", reason == ContractRowWriter.TIMELINE_CONSEQUENCE
		and reason == "Consequence is set but Style is timeline", reason)
	draft = _timeline_draft("Lamp Path")
	var checks: PackedByteArray = _bytes_of(ContractBuilderData.checks_path)
	var written: Dictionary = ContractRowWriter.write(draft)
	var row: Dictionary = ContractBuilderData.contract_row("Lamp Path")
	TestFixtures.check(res, "writer_timeline_ok", bool(written["ok"]) and not bool(written["check"])
		and int(written["timeline_checks"]) == 0 and String(row.get("Completion", "")) == draft.completion
		and String(row.get("Style", "")) == "timeline" and _bytes_of(ContractBuilderData.checks_path) == checks,
		_timeline_text(written))


#The pending timeline rows: those the steps name are appended once each in step order; two rows of one name refused.
static func _case_writer_timeline_pending(res: Dictionary) -> void:
	var names: Array[String] = ContractBuilderData.check_names()
	var draft: ContractDraft = _timeline_draft("Lamp Path")
	draft.completion = "a=check:Trial of Nerve ; b=event:Fight Bandits ; c=check:Trial of Grit fail"
	draft.timeline_checks = [_timeline_row("Trial of Grit"), _timeline_row("Trial of Nerve")]
	var written: Dictionary = ContractRowWriter.write(draft)
	var want: Array[String] = names.duplicate()
	want.append("Trial of Nerve")
	want.append("Trial of Grit")
	var now: Array[String] = ContractBuilderData.check_names()
	TestFixtures.check(res, "writer_timeline_pending_written", bool(written["ok"]) and not bool(written["check"])
		and int(written["timeline_checks"]) == 2 and now == want, "%s; %s" % [_timeline_text(written), ", ".join(now)])
	draft = _timeline_draft("Lamp Lane")
	draft.timeline_checks = [_timeline_row("Trial of Luck"), _timeline_row(CHECK_NAME)]
	written = ContractRowWriter.write(draft)
	want.append(CHECK_NAME)
	now = ContractBuilderData.check_names()
	TestFixtures.check(res, "writer_timeline_pending_unused_skipped", bool(written["ok"])
		and int(written["timeline_checks"]) == 1 and now == want, "%s; %s" % [_timeline_text(written), ", ".join(now)])
	draft = _timeline_draft("Lamp Road")
	draft.completion = "a=check:Trial of Pace ; b=check:Trial of Pace fail"
	draft.timeline_checks = [_timeline_row("Trial of Pace")]
	written = ContractRowWriter.write(draft)
	want.append("Trial of Pace")
	now = ContractBuilderData.check_names()
	TestFixtures.check(res, "writer_timeline_pending_shared_once", bool(written["ok"])
		and int(written["timeline_checks"]) == 1 and now == want, "%s; %s" % [_timeline_text(written), ", ".join(now)])
	draft = _timeline_draft("Lamp Way")
	draft.completion = "a=check:Trial of Calm ; b=check:trial of calm fail"
	draft.timeline_checks = [_timeline_row("Trial of Calm"), _timeline_row("trial of calm")]
	var checks: PackedByteArray = _bytes_of(ContractBuilderData.checks_path)
	var reason: String = ContractRowWriter.check(draft)
	written = ContractRowWriter.write(draft)
	TestFixtures.check(res, "writer_timeline_pending_dup", reason == "Check trial of calm is built twice"
		and not bool(written["ok"]) and String(written["error"]) == reason
		and _bytes_of(ContractBuilderData.checks_path) == checks and ContractBuilderData.contract_row("Lamp Way").is_empty(),
		"%s; %s" % [reason, _timeline_text(written)])


#A pending row whose name Checks.tsv holds is refused; a bad Checks.tsv header refuses only a draft with a pending row.
static func _case_writer_timeline_sheet(res: Dictionary) -> void:
	var path: String = ContractBuilderData.checks_path
	var header: String = _joined(CheckSheet.HEADER)
	var stored: bool = _store_text(path, header + "\n" + _joined(CHECK_CELLS))
	var draft: ContractDraft = _timeline_draft("Lamp Trail")
	draft.completion = "a=event:Fight Bandits ; b=check:trial of wit fail"
	draft.timeline_checks = [_timeline_row("trial of wit")]
	var reason: String = ContractRowWriter.check(draft)
	TestFixtures.check(res, "writer_timeline_pending_sheet_clash", stored
		and reason == "Check trial of wit already exists in Checks.tsv", reason)
	var bad: PackedByteArray = (header + "\tNotes").to_utf8_buffer()
	var guarded: bool = _store_bytes(path, bad)
	draft = _timeline_draft("Lamp Trail")
	draft.completion = "a=event:Fight Bandits ; b=check:Trial of Luck fail"
	draft.timeline_checks = [_timeline_row("Trial of Luck")]
	var pending: String = ContractRowWriter.check(draft)
	var written: Dictionary = ContractRowWriter.write(draft)
	var unused: ContractDraft = _timeline_draft("Lamp Trail")
	unused.timeline_checks = [_timeline_row("Trial of Luck")]
	var plain: String = ContractRowWriter.check(unused)
	TestFixtures.check(res, "writer_timeline_header_guard", guarded and pending.begins_with("cannot write Checks.tsv: ")
		and not bool(written["ok"]) and _bytes_of(path) == bad and plain == ""
		and ContractBuilderData.contract_row("Lamp Trail").is_empty(), "%s; unused row: %s" % [pending, plain])


#D147: one Completion warning "timeline: <reason>" under Style timeline; other styles keep the completion_ok warning.
static func _case_validator_timeline(res: Dictionary) -> void:
	var short: Array[String] = _warnings_of({"Style": "timeline", "Completion": "a=event:A", "_row": 96})
	TestFixtures.check(res, "validator_timeline_warning",
		_has_warning(short, "Completion", "timeline: Timeline needs at least 2 steps, has 1"), "; ".join(short))
	var shaped: Array[String] = _warnings_of({"Style": "timeline", "Completion": "a=event", "_row": 96})
	TestFixtures.check(res, "validator_timeline_single_warning", _column_count(shaped, "Completion") == 1
		and _has_warning(shaped, "Completion", "timeline: Step 1: expected <id>=<kind>:<name>, got a=event"),
		"; ".join(shaped))
	var chef: Array[String] = _warnings_of({"Style": "timeline", "Completion": "a=event:A role=Chef ; b=event:B fail",
		"_row": 96})
	TestFixtures.check(res, "validator_timeline_role_unknown",
		_has_warning(chef, "Completion", "timeline: step a role Chef is not a contract role")
		and _column_count(chef, "Completion") == 1, "; ".join(chef))
	var unlisted: Array[String] = _warnings_of({"Style": "timeline",
		"Completion": "a=event:A role=Driver ; b=event:B fail", "_row": 96})
	TestFixtures.check(res, "validator_timeline_role_not_listed",
		_has_warning(unlisted, "Completion", "timeline: step a role Driver is not a contract role")
		and _column_count(unlisted, "Completion") == 1, "; ".join(unlisted))
	var listed: Array[String] = _warnings_of({"Style": "timeline",
		"Completion": "a=event:A role=Driver ; b=event:B fail", "Roles": "Driver", "_row": 96})
	TestFixtures.check(res, "validator_timeline_role_listed", _column_count(listed, "Completion") == 0,
		"; ".join(listed))
	var clean: Array[String] = _warnings_of({"Style": "timeline", "Completion": TL_P78, "_row": 96})
	TestFixtures.check(res, "validator_timeline_ok", _column_count(clean, "Completion") == 0, "; ".join(clean))
	var as_event: Array[String] = _warnings_of({"Style": "event", "Completion": "a=event:A", "_row": 96})
	var as_check: Array[String] = _warnings_of({"Style": "check", "Completion": "a=event", "_row": 96})
	TestFixtures.check(res, "validator_timeline_other_style_silent", _column_count(as_event, "Completion") == 0
		and _column_count(as_check, "Completion") == 1 and _has_warning(as_check, "Completion", "got a=event")
		and not _has_warning(as_check, "Completion", "timeline: "), "%s | %s" % ["; ".join(as_event), "; ".join(as_check)])


#timeline_checks survives to_dict, from_dict and JSON; the dict holds its own rows; bad entries are dropped.
static func _case_draft_timeline_checks(res: Dictionary) -> void:
	var draft: ContractDraft = _timeline_draft("Lamp Path")
	draft.timeline_checks = [_timeline_row("Trial of Nerve"), _timeline_row("Trial of Grit")]
	var d: Dictionary = draft.to_dict()
	var copy: ContractDraft = ContractDraft.new()
	copy.from_dict(d)
	var parsed: Variant = JSON.parse_string(JSON.stringify(d))
	var loaded: ContractDraft = ContractDraft.new()
	if parsed is Dictionary:
		loaded.from_dict(parsed as Dictionary)
	var inner: Array = (d["timeline_checks"] as Array)[0]
	inner[0] = "Changed"
	var first: String = String((draft.timeline_checks[0] as Array)[0])
	TestFixtures.check(res, "draft_timeline_checks_round_trip", str(copy.timeline_checks) == str(draft.timeline_checks)
		and str(loaded.timeline_checks) == str(draft.timeline_checks) and copy.timeline_checks.size() == 2
		and first == "Trial of Nerve", "%s; first %s" % [str(loaded.timeline_checks), first])
	var mixed: Dictionary = draft.to_dict()
	mixed["timeline_checks"] = [_timeline_row("Trial of Pace"), ["a", "b"], "junk",
		[CHECK_NAME, "", "", "", "", "", "", "", "", "", 4]]
	copy.from_dict(mixed)
	var kept: int = copy.timeline_checks.size()
	mixed["timeline_checks"] = "junk"
	copy.from_dict(mixed)
	TestFixtures.check(res, "draft_timeline_checks_round_trip_drops", kept == 1 and copy.timeline_checks.is_empty(),
		"%d kept from four entries, %d from a String" % [kept, copy.timeline_checks.size()])


static func _case_draft_from_row_timeline(res: Dictionary) -> void:
	var draft: ContractDraft = _timeline_draft("Lamp Path")
	draft.timeline_checks = [_timeline_row("Trial of Nerve")]
	draft.from_row({"Contract Name": "Lamp Path", "Style": "timeline", "Completion": "a=event:A ; b=event:B fail"})
	TestFixtures.check(res, "draft_from_row_clears_timeline_checks", draft.timeline_checks.is_empty()
		and draft.style == "timeline", str(draft.timeline_checks))
