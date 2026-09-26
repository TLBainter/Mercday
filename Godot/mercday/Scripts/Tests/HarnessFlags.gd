class_name HarnessFlags
extends RefCounted

#Reads the harness command line flags.


#"--auto-forget": every automated encounter starts with an empty campaign knowledge store.
static func auto_forget() -> bool:
	return OS.get_cmdline_user_args().has("--auto-forget")


#Reads a state name from an "--auto-state=Name" user arg; "" when absent or unknown.
static func auto_state_name() -> String:
	var state_name := auto_spec("--auto-state")
	if state_name == "" or ConstStates.ALL.has(state_name):
		return state_name
	print("auto-state: unknown state %s" % state_name)
	return ""


#Reads a state or damage type name from an "--auto-immune=Name" user arg; "" when absent or unknown.
static func auto_immune_name() -> String:
	var name := auto_spec("--auto-immune")
	if name == "" or ConstStates.ALL.has(name) or not ConstDamageTypes.get_type(name).is_empty():
		return name
	print("auto-immune: unknown name %s" % name)
	return ""


#"--auto-inflict=Spec" and "--auto-remove=Spec" replace the harness resist specs; "" when absent.
static func auto_spec(flag: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(flag + "="):
			return arg.substr(flag.length() + 1).strip_edges()
	return ""


#"--probe-levels=1,9" picks the levels a probe runs; the caller's fallback when the flag is absent.
static func probe_levels(fallback: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for part: String in auto_spec("--probe-levels").split(",", false):
		var value := part.strip_edges().to_int()
		if value > 0:
			out.append(value)
	return fallback if out.is_empty() else out


#Whole number behind a "--flag=N" command line argument; the fallback when the flag is absent.
static func arg_int(flag: String, fallback: int) -> int:
	var spec := auto_spec(flag)
	return fallback if spec == "" else spec.to_int()


#"--auto-difficulty=D" sizes the harness dungeon; 0 leaves the generator to roll its own.
static func auto_difficulty() -> float:
	var spec: String = auto_spec("--auto-difficulty")
	return float(spec) if spec.is_valid_float() else 0.0


#"--auto-building=Name" picks one Buildings.tsv row for the interior harness; {} keeps the draw.
static func auto_building_data() -> Dictionary:
	var want: String = auto_spec("--auto-building")
	if want == "":
		return {}
	var data: Dictionary = DataManager.get_area_by_name(want)
	if data.is_empty() or not data.has("building"):
		print("AUTO BUILDING: unknown building '%s'" % want)
		return {}
	return data


#"--furlough": the first deployable roster merc takes ten days off before the next test contract.
static func furlough_flag() -> bool:
	return OS.get_cmdline_user_args().has("--furlough")
