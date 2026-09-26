class_name MercCount extends Control

#Five merc silhouettes: required orange, up to allowed cream, the rest a hollow blue outline.

const SILHOUETTE_MAP: PackedStringArray = [
	"...####...",
	"..######..",
	"..######..",
	"..######..",
	"..######..",
	"...####...",
	"..........",
	"..######..",
	".########.",
	"##########",
	"##########",
	"##########",
	"##########",
	"##########",
]
const SIL_SIZE_PX: Vector2 = Vector2(10, 14)
const GAP_PX: int = 2
const COUNT: int = 5
const ORANGE: Color = Color("#f28c28")
const CREAM: Color = Color("#f3ead7")
const HOLLOW_COLOR: Color = Color("#3b6fb6")

static var _hollow_cache: PackedStringArray = PackedStringArray()

@export var required: int = 1:
	set(value):
		required = value
		_refresh()
@export var allowed: int = 1:
	set(value):
		allowed = value
		_refresh()
@export var pixel_scale: int = 2:
	set(value):
		pixel_scale = value
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	custom_minimum_size = Vector2((COUNT * SIL_SIZE_PX.x + (COUNT - 1) * GAP_PX) * pixel_scale,
		SIL_SIZE_PX.y * pixel_scale)
	var noun: String = "merc" if allowed == 1 else "mercs"
	tooltip_text = "Requires %d, up to %d %s" % [required, allowed, noun]
	queue_redraw()


func _draw() -> void:
	var stride: float = (SIL_SIZE_PX.x + GAP_PX) * pixel_scale
	for i: int in COUNT:
		var solid: bool = i < allowed
		var map: PackedStringArray = SILHOUETTE_MAP if solid else hollow_map()
		var slot_color: Color = color_at(i, required, allowed)
		var x0: float = i * stride
		for row: int in map.size():
			var line: String = map[row]
			for c: int in line.length():
				if line[c] != "#":
					continue
				draw_rect(Rect2(x0 + c * pixel_scale, row * pixel_scale, pixel_scale, pixel_scale),
					slot_color)


static func color_at(i: int, required_value: int, allowed_value: int) -> Color:
	if i < required_value:
		return ORANGE
	if i < allowed_value:
		return CREAM
	return HOLLOW_COLOR


static func hollow_map() -> PackedStringArray:
	if _hollow_cache.is_empty():
		_hollow_cache = _compute_hollow_map()
	return _hollow_cache


static func _compute_hollow_map() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for row: int in SILHOUETTE_MAP.size():
		var line: String = SILHOUETTE_MAP[row]
		var result_line: String = ""
		for c: int in line.length():
			if line[c] != "#":
				result_line += "."
				continue
			result_line += "#" if _on_edge(row, c, line.length()) else "."
		out.append(result_line)
	return out


static func _on_edge(row: int, col: int, width: int) -> bool:
	var offsets: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for d: Vector2i in offsets:
		var nr: int = row + d.y
		var nc: int = col + d.x
		if nr < 0 or nr >= SILHOUETTE_MAP.size() or nc < 0 or nc >= width:
			return true
		if SILHOUETTE_MAP[nr][nc] == ".":
			return true
	return false
