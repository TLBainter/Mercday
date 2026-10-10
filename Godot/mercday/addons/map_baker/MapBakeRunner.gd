@tool
class_name MapBakeRunner extends RefCounted

#Orders bake steps by declared keys, expands a stage to its downstream steps and runs them.
#In the editor the run sits on one WorkerThreadPool task and finished fires on the main thread.

signal finished(ok: bool, lines: PackedStringArray)

const STEPS_DIR := "res://addons/map_baker/steps/"

var ctx: MapBakeContext = MapBakeContext.new()
var busy: bool = false
var _task: int = -1


#Every step script under steps/, instanced, with step_name and stage filled from the file when left empty.
static func load_steps() -> Array[MapBakeStep]:
	var found: Array[MapBakeStep] = []
	if not DirAccess.dir_exists_absolute(STEPS_DIR):
		return found
	for file: String in DirAccess.get_files_at(STEPS_DIR):
		if file.get_extension() != "gd":
			continue
		var script: GDScript = load(STEPS_DIR + file) as GDScript
		var step: MapBakeStep = null
		if script != null and script.can_instantiate():
			step = script.new() as MapBakeStep
		if step == null:
			push_warning("map_baker: %s is not a MapBakeStep" % file)
			continue
		if step.step_name == &"":
			step.step_name = StringName(file.get_basename())
		var consts: Dictionary = script.get_script_constant_map()
		if step.stage == 0 and consts.has("STAGE"):
			step.stage = int(consts["STAGE"])
		found.append(step)
	return found


#Stage 0 runs every step; stage N runs its steps and everything downstream. Synchronous, for --map-bake=N.
static func run_headless(stage: int) -> bool:
	var runner: MapBakeRunner = MapBakeRunner.new()
	var all: Array[MapBakeStep] = load_steps()
	var picked: Array[MapBakeStep] = all
	if stage != 0:
		var own: Array[MapBakeStep] = []
		for s: MapBakeStep in all:
			if s.stage == stage:
				own.append(s)
		picked = runner.downstream_of(own, all)
	var ok: bool = runner.execute(runner.order(picked))
	if ok and Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
	return ok


func run(steps: Array[MapBakeStep], downstream: bool) -> void:
	if busy:
		return
	busy = true
	ctx = MapBakeContext.new()
	var picked: Array[MapBakeStep] = downstream_of(steps, load_steps()) if downstream else steps
	var ordered: Array[MapBakeStep] = order(picked)
	_task = WorkerThreadPool.add_task(_work.bind(ordered), false, "map_baker")


func _work(ordered: Array[MapBakeStep]) -> void:
	var ok: bool = execute(ordered)
	_finish.call_deferred(ok)


func _finish(ok: bool) -> void:
	wait()
	busy = false
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
	finished.emit(ok, ctx.lines)


#Blocks until a running editor bake task ends; the plugin calls it before it leaves the tree.
func wait() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


#Runs the ordered steps, skipping one whose manifest entry is current and whose inputs no step changed this run.
#A rerun marks an output dirty only when its bytes changed or it has no file or folder to checksum.
func execute(ordered: Array[MapBakeStep]) -> bool:
	if ctx.failed:
		return false
	if ordered.is_empty():
		ctx.log("no steps to run")
	var manifest: MapBakeManifest = MapBakeManifest.open()
	var pinned: Dictionary = _pinned(ordered)
	var dirty: Dictionary = {}
	var start: int = Time.get_ticks_msec()
	for step: MapBakeStep in ordered:
		var stale: bool = pinned.has(step) or _hits(step.reads(), PackedStringArray(dirty.keys()))
		if not stale and manifest.is_current(step, ctx):
			ctx.log("skip %s" % step.step_name)
			continue
		ctx.log("run %s" % step.step_name)
		var keys: PackedStringArray = step.outputs + step.modifies
		var before: Dictionary = {}
		for key: String in keys:
			before[key] = _key_md5(ctx, key)
		var t0: int = Time.get_ticks_msec()
		if not step.run(ctx) or ctx.failed:
			return ctx.fail("step %s" % step.step_name)
		for key: String in keys:
			var md5: String = _key_md5(ctx, key)
			if md5.is_empty() or md5 != before[key]:
				dirty[key] = true
		manifest.record(step, ctx, Time.get_ticks_msec() - t0)
	var live: PackedStringArray = PackedStringArray()
	for step: MapBakeStep in ordered:
		live.append(String(step.step_name))
	manifest.prune(live)
	manifest.absorb(ctx)
	manifest.wall_ms = Time.get_ticks_msec() - start
	var err: Error = manifest.save_to_disk()
	if err != OK:
		return ctx.fail("cannot save manifest (error %d)" % err)
	ctx.log("bake done in %d ms" % manifest.wall_ms)
	return true


#Producer, then modifiers, then readers; a reader a modifier depends on runs before it. run_last steps go after
#all others. A cycle fails the context with both step names and returns an empty list.
func order(steps: Array[MapBakeStep]) -> Array[MapBakeStep]:
	var n: int = steps.size()
	var succ: Array[Dictionary] = []
	for i: int in n:
		succ.append({})
	for p: int in n:
		for j: int in n:
			if j != p and _hits(steps[p].outputs, steps[j].reads()):
				succ[p][j] = true
	for m: int in n:
		for r: int in n:
			if r != m and _hits(steps[m].modifies, steps[r].inputs + steps[r].optional) and not _reaches(succ, r, m):
				succ[m][r] = true
	var indeg: PackedInt32Array = PackedInt32Array()
	indeg.resize(n)
	for p: int in n:
		for j: int in succ[p]:
			indeg[j] += 1
	var done: Dictionary = {}
	var result: Array[MapBakeStep] = []
	while result.size() < n:
		var best: int = -1
		for i: int in n:
			if not done.has(i) and indeg[i] == 0 and (best < 0 or _before(steps[i], steps[best])):
				best = i
		if best < 0:
			ctx.fail(_cycle(steps, succ, done))
			return []
		done[best] = true
		result.append(steps[best])
		for j: int in succ[best]:
			indeg[j] -= 1
	return result


#The given steps plus every step that reads, modifies or produces a key they write, repeated to a fixed point.
#A step in all with the name of a given step is the same step; the given instance is kept.
func downstream_of(steps: Array[MapBakeStep], all: Array[MapBakeStep]) -> Array[MapBakeStep]:
	var pool: Array[MapBakeStep] = steps.duplicate()
	var picked: Dictionary = {}
	for s: MapBakeStep in steps:
		picked[s.step_name] = true
	for s: MapBakeStep in all:
		if not picked.has(s.step_name):
			pool.append(s)
	var grew: bool = true
	while grew:
		grew = false
		for s: MapBakeStep in pool:
			if picked.has(s.step_name):
				continue
			for src: MapBakeStep in pool:
				if not picked.has(src.step_name):
					continue
				if _hits(src.outputs + src.modifies, s.reads()) or _hits(src.modifies, s.outputs):
					picked[s.step_name] = true
					grew = true
					break
	var result: Array[MapBakeStep] = []
	for s: MapBakeStep in pool:
		if picked.has(s.step_name):
			result.append(s)
	return result


#A key matches itself; "dir/*" matches every key under dir/.
static func keys_match(a: String, b: String) -> bool:
	if a == b or (a.ends_with("/*") and b.begins_with(a.trim_suffix("*"))):
		return true
	return b.ends_with("/*") and a.begins_with(b.trim_suffix("*"))


#A folder key (dir/*) sums its sorted file names and file checksums, so a byte-identical rewrite stays clean.
static func _key_md5(ctx: MapBakeContext, key: String) -> String:
	var path: String = ctx.path_of(key)
	if not DirAccess.dir_exists_absolute(path):
		return MapBakeManifest._md5(ctx, key)
	var dir: String = path.trim_suffix("/") + "/"
	var files: PackedStringArray = DirAccess.get_files_at(dir)
	files.sort()
	var parts: PackedStringArray = PackedStringArray()
	for file: String in files:
		parts.append("%s:%s" % [file, FileAccess.get_md5(dir + file)])
	return "\n".join(parts).md5_text()


static func _hits(a: PackedStringArray, b: PackedStringArray) -> bool:
	for x: String in a:
		for y: String in b:
			if keys_match(x, y):
				return true
	return false


#Modifiers, producers of modified keys and steps with no inputs always run: their outputs cannot be checksummed.
static func _pinned(ordered: Array[MapBakeStep]) -> Dictionary:
	var modified: PackedStringArray = PackedStringArray()
	for s: MapBakeStep in ordered:
		modified.append_array(s.modifies)
	var pinned: Dictionary = {}
	for s: MapBakeStep in ordered:
		if not s.modifies.is_empty() or (s.inputs + s.optional).is_empty() or _hits(s.outputs, modified):
			pinned[s] = true
	return pinned


static func _before(a: MapBakeStep, b: MapBakeStep) -> bool:
	if a.run_last != b.run_last:
		return not a.run_last
	if a.stage != b.stage:
		return a.stage < b.stage
	return String(a.step_name) < String(b.step_name)


static func _reaches(succ: Array[Dictionary], from: int, to: int) -> bool:
	var seen: Dictionary = {from: true}
	var stack: Array[int] = [from]
	while not stack.is_empty():
		var i: int = stack.pop_back()
		if i == to:
			return true
		for j: int in succ[i]:
			if not seen.has(j):
				seen[j] = true
				stack.append(j)
	return false


#Walks back through unsorted predecessors until a step repeats; that step and its successor on the walk share a cycle.
static func _cycle(steps: Array[MapBakeStep], succ: Array[Dictionary], done: Dictionary) -> String:
	var cur: int = 0
	while done.has(cur):
		cur += 1
	var seen: Dictionary = {}
	var after: int = cur
	while not seen.has(cur):
		seen[cur] = true
		after = cur
		for p: int in steps.size():
			if not done.has(p) and succ[p].has(cur):
				cur = p
				break
	return "cycle between %s and %s" % [steps[cur].step_name, steps[after].step_name]
