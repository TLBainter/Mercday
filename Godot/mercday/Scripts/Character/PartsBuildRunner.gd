extends SceneTree

#Headless parts library build: <exe> --headless --path . -s res://Scripts/Character/PartsBuildRunner.gd

const BUILDER := preload("res://Scripts/Character/CharacterPartsBuilder.gd")


func _initialize() -> void:
	var res: Dictionary = BUILDER.build(BUILDER.SOURCE_DIR, BUILDER.ITEMS_DIR, BUILDER.ITEMS_INDEX)
	var counts: Dictionary = res["counts"]
	for slot: String in counts:
		var tally: Dictionary = counts[slot]
		var bits: PackedStringArray = PackedStringArray()
		for g: String in ["F", "M", "K", "U"]:
			if tally.has(g):
				bits.append("%s=%d" % [g, int(tally[g])])
		print("PARTS %s %s" % [slot, " ".join(bits)])
	for g: String in res["palettes"]:
		print("PALETTE %s rows=%d" % [g, int(res["palettes"][g]["rows"])])
	var errors: Array = res["errors"]
	for e: String in errors.slice(0, 40):
		print("ERROR " + e)
	print("PARTS BUILD parts=%d masked=%d items=%d errors=%d seconds=%.1f" % [int(res["parts"]),
		int(res["masked"]), int(res["items"]), errors.size(), float(res["seconds"])])
	quit(0 if errors.is_empty() else 1)
