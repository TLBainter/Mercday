class_name HarnessHook
extends RefCounted

#Launch-side door to the test harness: loads the harness entry script by path only when user flags are present,
#so a plain game launch never parses Scripts/Tests.

const ENTRY_PATH: String = "res://Scripts/Tests/HarnessEntry.gd"

#User args that belong to the GUI and never mean "run the harness".
const GUI_FLAGS: Array[String] = ["--metrics-preview", "--results-preview", "--harness"]

static var _entry: GDScript = null


#True when any user arg begins with "--".
static func has_user_flags() -> bool:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			return true
	return false


#True when any user arg asks for the harness rather than the GUI.
static func wants_harness() -> bool:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and not GUI_FLAGS.has(arg):
			return true
	return false


#The harness entry script, loaded once; null on a launch without user flags.
static func entry() -> GDScript:
	if not has_user_flags():
		return null
	if _entry == null:
		_entry = load(ENTRY_PATH) as GDScript
	return _entry


#The harness entry script's boot through the path load; false when no harness script is loaded.
static func boot(host: Node) -> bool:
	var e: GDScript = entry()
	if e == null:
		return false
	return bool(await e.call(&"boot", host))


#The harness entry script's seed_previews through the path load; does nothing without user flags.
static func seed_previews() -> void:
	var e: GDScript = entry()
	if e != null:
		e.call(&"seed_previews")


#Value of "--flag=value" among the user args, or "" when absent.
static func auto_spec(flag: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(flag + "="):
			return arg.substr(flag.length() + 1).strip_edges()
	return ""
