class_name MapWorldSceneTests extends RefCounted
#World.tscn as loaded: node set, Terrain and Camera setup, bake outputs stay under Baked/, a bake never rewrites scenes.
#Run: godot --headless --path . -- --map-world-tests

const CHILDREN: Array[String] = ["Env", "Camera", "Terrain", "Foliage", "Ground", "Water", "Placements"]
const START_TARGET: Vector2 = Vector2(2848, 1580)
const VIEW_SCENE: String = "res://Scenes/Map/MapView.tscn"
const DEAD_STEPS: Array[StringName] = [&"MapSourceImport", &"BakeWorldScene"]


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	var baked: bool = MapTestFixtures.require_baked(res, "terrain/index.tres")
	await _case_instance(res, host, baked)
	_case_step_outputs(res)
	if baked:
		_case_bake_keeps_scenes(res)
	return TestFixtures.summarize(res, "MAP WORLD")


static func _case_instance(res: Dictionary, host: Node, baked: bool) -> void:
	var packed: PackedScene = load(MapData.WORLD_SCENE) as PackedScene
	TestFixtures.check(res, "World.tscn loads as a PackedScene", packed != null, MapData.WORLD_SCENE)
	if packed == null:
		return
	var root: Node = packed.instantiate()
	TestFixtures.check(res, "World.tscn instantiates", root != null, "")
	if root == null:
		return
	host.add_child(root)
	await host.get_tree().process_frame
	TestFixtures.check(res, "world root is MapWorld", root is MapWorld, root.get_class())
	var names: Array[String] = []
	for child: Node in root.get_children():
		names.append(String(child.name))
	TestFixtures.check(res, "world children are the seven nodes in order", names == CHILDREN, str(names))
	var terrain: MapLayer = root.get_node_or_null("Terrain") as MapLayer
	var t_ok: bool = terrain != null and terrain.index_path == MapData.TERRAIN_INDEX
	TestFixtures.check(res, "Terrain is a MapLayer on the terrain index", t_ok, terrain.index_path if terrain else "")
	var mat: String = terrain.material.resource_path if terrain != null and terrain.material != null else ""
	TestFixtures.check(res, "Terrain material is terrain.tres", mat == MapData.TERRAIN_MATERIAL, mat)
	var kids: int = terrain.get_child_count(true) if terrain != null else -1
	TestFixtures.check(res, "Terrain holds no chunk before a view rect", kids == 0, "%d children" % kids)
	var cam: MapCamera = root.get_node_or_null("Camera") as MapCamera
	var c_ok: bool = cam != null and cam.start_target == START_TARGET
	TestFixtures.check(res, "Camera is a MapCamera at the start target", c_ok, str(cam.start_target) if cam else "")
	if baked:
		var water: Node3D = root.get_node_or_null("Water") as Node3D
		var gap: float = water.position.distance_to(MapWorldBind.water_position()) if water != null else INF
		TestFixtures.check(res, "Water sits at the bound water position", gap < 0.001, "%f" % gap)
	host.remove_child(root)
	root.free()


static func _case_step_outputs(res: Dictionary) -> void:
	var steps: Array[MapBakeStep] = MapBakeRunner.load_steps()
	var ctx: MapBakeContext = MapBakeContext.new()
	var outside: Array[String] = []
	var dead: Array[String] = []
	for step: MapBakeStep in steps:
		if DEAD_STEPS.has(step.step_name):
			dead.append(String(step.step_name))
		for key: String in step.outputs + step.modifies:
			if not ctx.path_of(key).begins_with(MapData.BAKED_DIR):
				outside.append("%s %s" % [step.step_name, key])
	TestFixtures.check(res, "bake steps load", not steps.is_empty(), "")
	TestFixtures.check(res, "every step writes under Baked/", outside.is_empty(),
		TestFixtures.detail(outside, steps.size(), "steps"))
	TestFixtures.check(res, "no import or world scene step", dead.is_empty(), str(dead))


#N6: a full headless bake leaves the hand-owned scenes byte for byte.
static func _case_bake_keeps_scenes(res: Dictionary) -> void:
	var world_md5: String = FileAccess.get_md5(MapData.WORLD_SCENE)
	var view_md5: String = FileAccess.get_md5(VIEW_SCENE)
	print("MAP WORLD: running the full headless bake (about 12 s)")
	var ok: bool = MapBakeRunner.run_headless(0)
	TestFixtures.check(res, "headless bake succeeds", ok, "")
	var world_same: bool = not world_md5.is_empty() and FileAccess.get_md5(MapData.WORLD_SCENE) == world_md5
	TestFixtures.check(res, "bake leaves World.tscn unchanged", world_same, world_md5)
	var view_same: bool = not view_md5.is_empty() and FileAccess.get_md5(VIEW_SCENE) == view_md5
	TestFixtures.check(res, "bake leaves MapView.tscn unchanged", view_same, view_md5)
