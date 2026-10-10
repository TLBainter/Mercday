@tool
class_name PixelAtlasEntry extends Resource

#One atlas rect. A sub (parent set) holds its rect relative to the parent rect.

@export var id: StringName
@export var rect: Rect2i
@export var parent: StringName
@export var tile: bool
@export var light: bool
@export var frames: int
@export var frame_w: int
@export var edited: bool
@export var extra: Dictionary


static func from_json(d: Dictionary) -> PixelAtlasEntry:
	var e: PixelAtlasEntry = PixelAtlasEntry.new()
	e.id = StringName(str(d.get("id", "")))
	e.rect = Rect2i(int(d.get("x", 0)), int(d.get("y", 0)), int(d.get("w", 1)), int(d.get("h", 1)))
	e.parent = StringName(str(d.get("parent", "")))
	e.tile = bool(d.get("tile", false))
	e.light = bool(d.get("light", false))
	e.frames = int(d.get("frames", 0))
	e.frame_w = int(d.get("frameW", 0))
	e.edited = bool(d.get("edited", false))
	for k: String in d:
		if not k in ["id", "x", "y", "w", "h", "parent", "tile", "light", "frames", "frameW", "edited"]:
			e.extra[k] = d[k]
	return e


func to_json() -> Dictionary:
	var d: Dictionary = {"id": String(id), "x": rect.position.x, "y": rect.position.y, "w": rect.size.x,
		"h": rect.size.y, "tile": tile, "light": light}
	if frames > 0:
		d["frames"] = frames
		d["frameW"] = frame_w
	d.merge(extra)
	if parent != &"":
		d["parent"] = String(parent)
	if edited:
		d["edited"] = true
	return d
