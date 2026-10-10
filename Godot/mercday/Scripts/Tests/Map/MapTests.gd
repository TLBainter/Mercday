class_name MapTests extends RefCounted

#Umbrella behind --map-tests: runs every map suite and counts one case per suite; a missing suite file fails.
#Run: godot --headless --path . -- --map-tests. Later stages append one row per suite to SUITES.

const SUITES: Array = [
	["--map-budget-tests", "res://Scripts/Tests/Map/MapBudgetTests.gd"],
	["--map-bake-tests", "res://Scripts/Tests/Map/MapBakeTests.gd"],
	["--map-terrain-tests", "res://Scripts/Tests/Map/MapTerrainTests.gd"],
	["--map-camera-tests", "res://Scripts/Tests/Map/MapCameraTests.gd"],
	["--map-highlight-tests", "res://Scripts/Tests/Map/MapHighlightTests.gd"],
	["--map-editor-tests", "res://Scripts/Tests/Map/MapEditorSafetyTests.gd"],
	["--map-world-tests", "res://Scripts/Tests/Map/MapWorldSceneTests.gd"],
	["--map-color-tests", "res://Scripts/Tests/Map/MapColorTests.gd"],
	["--pixel-model-tests", "res://Scripts/Tests/Map/PixelModelTests.gd"],
	["--pixel-ruin-tests", "res://Scripts/Tests/Map/PixelRuinTests.gd"],
	["--map-scatter-tests", "res://Scripts/Tests/Map/MapScatterTests.gd"],
	["--map-ground-tests", "res://Scripts/Tests/Map/MapGroundTests.gd"],
]


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	for entry: Array in SUITES:
		var path: String = str(entry[1])
		var suite: GDScript = (load(path) as GDScript) if ResourceLoader.exists(path) else null
		var ok: bool = false
		if suite != null:
			ok = bool(await suite.call("run", host))
		TestFixtures.check(res, "suite %s" % entry[0], ok, path if suite != null else "missing or unloadable " + path)
	return TestFixtures.summarize(res, "MAP")
