class_name LaunchCouplingTests extends RefCounted

#Guards the launch path: non-test code (comments ignored) must not name test classes; every harness suite row must resolve.
#Run: godot --headless --path . -- --launch-tests

const TESTS_DIR: String = "res://Scripts/Tests"
const SCRIPTS_DIR: String = "res://Scripts"
const SCENES_DIR: String = "res://Scenes"
const SCENES_TESTS_DIR: String = "res://Scenes/Tests"
const HOOK_PATH: String = "res://Scripts/Utils/HarnessHook.gd"
const ENTRY_PATH: String = "res://Scripts/Tests/HarnessEntry.gd"
const TESTING_AREA: String = "res://Scenes/GUI/testingArea.tscn"


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_no_coupling(res)
	_case_gui_flags(res)
	_case_hook(res)
	_case_rows(res)
	_case_entry_text(res)
	return TestFixtures.summarize(res, "LAUNCH COUPLING")


static func _files(dir: String, ext: String, skip_prefix: String = "") -> Array[String]:
	var out: Array[String] = []
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return out
	for sub: String in d.get_directories():
		var sub_path: String = dir.path_join(sub)
		if skip_prefix != "" and sub_path.begins_with(skip_prefix):
			continue
		out.append_array(_files(sub_path, ext, skip_prefix))
	for f: String in d.get_files():
		if f.get_extension() == ext:
			out.append(dir.path_join(f))
	return out


static func _text(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


#Returns text with every GDScript comment removed; a # inside a quoted string does not start a comment.
static func _code(text: String) -> String:
	var out: PackedStringArray = []
	for line: String in text.split("\n"):
		var quote: String = ""
		var cut: int = line.length()
		var i: int = 0
		while i < line.length():
			var c: String = line[i]
			if quote != "":
				if c == "\\":
					i += 1
				elif c == quote:
					quote = ""
			elif c == "\"" or c == "'":
				quote = c
			elif c == "#":
				cut = i
				break
			i += 1
		out.append(line.substr(0, cut))
	return "\n".join(out)


static func _test_class_names() -> Array[String]:
	var names: Array[String] = []
	var rx: RegEx = RegEx.new()
	rx.compile(r"(?m)^class_name\s+(\w+)")
	for path: String in _files(TESTS_DIR, "gd"):
		var m: RegExMatch = rx.search(_text(path))
		if m != null:
			names.append(m.get_string(1))
	return names


static func _case_no_coupling(res: Dictionary) -> void:
	var names: Array[String] = _test_class_names()
	TestFixtures.check(res, "test class names were collected", names.size() > 50, "count %d" % names.size())
	var rxs: Array[RegEx] = []
	for n: String in names:
		var rx: RegEx = RegEx.new()
		rx.compile(r"\b%s\b" % n)
		rxs.append(rx)
	var offenders: Array[String] = []
	for path: String in _files(SCRIPTS_DIR, "gd", TESTS_DIR):
		var text: String = _text(path)
		text = _code(text)
		if path == HOOK_PATH:
			var kept: PackedStringArray = []
			for line: String in text.split("\n"):
				if not line.begins_with("const ENTRY_PATH"):
					kept.append(line)
			text = "\n".join(kept)
		for i: int in names.size():
			if rxs[i].search(text) != null:
				offenders.append("%s names %s" % [path, names[i]])
		if text.contains("res://Scripts/Tests"):
			offenders.append("%s names res://Scripts/Tests" % path)
	TestFixtures.check(res, "no script outside Scripts/Tests names a test class or path",
		offenders.is_empty(), "; ".join(offenders))
	var scene_offenders: Array[String] = []
	for path: String in _files(SCENES_DIR, "tscn", SCENES_TESTS_DIR):
		if path != TESTING_AREA and _text(path).contains("Scripts/Tests/"):
			scene_offenders.append(path)
	TestFixtures.check(res, "no scene outside Scenes/Tests references Scripts/Tests",
		scene_offenders.is_empty(), "; ".join(scene_offenders))


static func _case_gui_flags(res: Dictionary) -> void:
	TestFixtures.check(res, "HarnessHook.GUI_FLAGS equals HarnessEntry.GUI_FLAGS",
		HarnessHook.GUI_FLAGS == HarnessEntry.GUI_FLAGS,
		"hook %s entry %s" % [HarnessHook.GUI_FLAGS, HarnessEntry.GUI_FLAGS])


static func _case_hook(res: Dictionary) -> void:
	TestFixtures.check(res, "wants_harness is true inside a harness run",
		HarnessHook.wants_harness(), "args %s" % [OS.get_cmdline_user_args()])
	TestFixtures.check(res, "has_user_flags is true inside a harness run",
		HarnessHook.has_user_flags(), "args %s" % [OS.get_cmdline_user_args()])
	TestFixtures.check(res, "entry loads the harness script", HarnessHook.entry() != null, "entry null")


static func _case_rows(res: Dictionary) -> void:
	var rows: Array = HarnessEntry._suite_flags(null)
	TestFixtures.check(res, "the suite table has rows", rows.size() > 100, "rows %d" % rows.size())
	var bad: Array[String] = []
	var rx: RegEx = RegEx.new()
	rx.compile(r"static func run\(([^)]*)\)")
	for row: Array in rows:
		var callable: Callable = row[1]
		var bound: Array = callable.get_bound_arguments()
		if bound.size() != 3:
			continue
		var path: String = str(bound[0])
		var takes_host: bool = bool(bound[2])
		if not ResourceLoader.exists(path):
			bad.append("%s missing %s" % [row[0], path])
			continue
		var m: RegExMatch = rx.search(_text(path))
		if m == null:
			bad.append("%s has no static func run" % row[0])
			continue
		var has_param: bool = m.get_string(1).strip_edges() != ""
		if has_param != takes_host:
			bad.append("%s takes_host %s but run has param %s" % [row[0], takes_host, has_param])
	TestFixtures.check(res, "every suite row resolves and matches its run signature",
		bad.is_empty(), "; ".join(bad))


static func _case_entry_text(res: Dictionary) -> void:
	var strings: RegEx = RegEx.new()
	strings.compile("\"[^\"\n]*\"")
	var code: PackedStringArray = []
	for line: String in _text(ENTRY_PATH).split("\n"):
		code.append(strings.sub(line, "", true))
	var rx: RegEx = RegEx.new()
	rx.compile(r"[A-Z][A-Za-z]+(Tests|Probe)\.run")
	var m: RegExMatch = rx.search("\n".join(code))
	TestFixtures.check(res, "HarnessEntry names no suite or probe class outside strings",
		m == null, m.get_string() if m != null else "")
