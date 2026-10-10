@tool
class_name ContractRebuild extends RefCounted

#Rebuilds the contract and event resources in a headless child Godot run with --contract-build, so the editor
#never runs ContractResourceBuilder itself; inside the editor a filesystem scan then picks up the new files.

const SUMMARY_PREFIX: String = "CONTRACT BUILDER:"
const BUILD_FLAG: String = "--contract-build"
const OUTPUT_TAIL: int = 2000
const ERROR_CHARS: int = 160


#{"ok", "contracts", "events", "warnings"} from the first line that starts with SUMMARY_PREFIX.
static func parse_summary(text: String) -> Dictionary:
	var out: Dictionary = {"ok": false, "contracts": 0, "events": 0, "warnings": 0}
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if not line.begins_with(SUMMARY_PREFIX):
			continue
		var pattern: RegEx = RegEx.new()
		pattern.compile("^%s ([0-9]+) contracts, ([0-9]+) events, ([0-9]+) warnings$" % SUMMARY_PREFIX)
		var found: RegExMatch = pattern.search(line)
		if found != null:
			out["ok"] = true
			out["contracts"] = int(found.get_string(1))
			out["events"] = int(found.get_string(2))
			out["warnings"] = int(found.get_string(3))
		break
	return out


#Blocks until the child quits. The parse_summary result gains "exit_code", "output" (the last
#OUTPUT_TAIL characters of stdout and stderr) and "error", a one-line reason; the Output panel gets the tail.
static func run() -> Dictionary:
	var args: PackedStringArray = PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--quit", "--", BUILD_FLAG])
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	var text: String = ""
	for chunk: Variant in output:
		text += str(chunk)
	var out: Dictionary = parse_summary(text)
	out["exit_code"] = code
	out["output"] = text.right(OUTPUT_TAIL)
	out["error"] = ""
	if code != 0 or not bool(out["ok"]):
		var reason: String = "exit code %d" % code if code != 0 else "no %s line" % SUMMARY_PREFIX
		var hint: String = _error_line(text)
		out["ok"] = false
		out["error"] = reason if hint == "" else "%s: %s" % [reason, hint]
		push_warning("ContractRebuild: %s\n%s" % [reason, String(out["output"])])
		return out
	_rescan()
	return out


static func summary_text(result: Dictionary) -> String:
	if bool(result.get("ok", false)):
		return "rebuild: %d contracts, %d events, %d warnings" % [int(result.get("contracts", 0)),
			int(result.get("events", 0)), int(result.get("warnings", 0))]
	return "rebuild failed: %s" % String(result.get("error", ""))


#The first line naming an ERROR, else the last non-blank line, cut to ERROR_CHARS characters.
static func _error_line(text: String) -> String:
	var last: String = ""
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line.contains("ERROR"):
			return line.left(ERROR_CHARS)
		if line != "":
			last = line
	return last.left(ERROR_CHARS)


#Inside the editor the rewritten .tres files show only after a scan; EditorInterface is reached by name.
static func _rescan() -> void:
	if not Engine.is_editor_hint() or not Engine.has_singleton(&"EditorInterface"):
		return
	var editor: Object = Engine.get_singleton(&"EditorInterface")
	var filesystem: Object = editor.call(&"get_resource_filesystem") as Object
	if filesystem != null:
		filesystem.call(&"scan")
