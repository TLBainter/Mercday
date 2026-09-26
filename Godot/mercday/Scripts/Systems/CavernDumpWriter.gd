class_name CavernDumpWriter
extends RefCounted


#Chambers, tunnels, entrances and the two per-cell grids of a cavern map.
static func append_cavern(field: BattlefieldArea, lines: Array[String]) -> void:
	lines.append("=== Cavern ===")
	lines.append("ENTRANCES: %d" % field.entrance_cells.size())
	for ec: Vector2i in field.entrance_cells:
		lines.append("entrance (%d,%d)" % [ec.x, ec.y])
	for ci: int in range(field.cavern_chambers.size()):
		var ch: Dictionary = field.cavern_chambers[ci]
		var rect: Rect2i = ch.get("rect", Rect2i()) as Rect2i
		var peak: Vector2i = ch.get("peak", Vector2i.ZERO) as Vector2i
		var surface: float = float(ch.get("level", 0.0))
		if bool(ch.get("flooded", false)):
			surface = float(ch.get("surface", ch.get("level", 0.0)))
		var pool_floor: float = surface - float(int(ch.get("depth", 0)))
		lines.append("chamber %d [%s] pos=(%d,%d) size=%dx%d level=%.2f peak=(%d,%d) size=%d clearance=%.2f depth=%d surface=%.2f floor=%.2f" % [
			ci, str(ch.get("name", "")), rect.position.x, rect.position.y, rect.size.x, rect.size.y,
			float(ch.get("level", 0.0)), peak.x, peak.y, int(ch.get("peak_size", 1)),
			float(ch.get("peak_clearance", 0.0)), int(ch.get("depth", 0)), surface, pool_floor])
	for ti: int in range(field.cavern_tunnels.size()):
		var tun: Dictionary = field.cavern_tunnels[ti]
		var tcells: Array = tun.get("cells", []) as Array
		lines.append("tunnel %d %s %d->%d width=%d height=%d length=%d" % [
			ti, str(tun.get("kind", "")), int(tun.get("from", -1)), int(tun.get("to", -1)),
			int(tun.get("width", 1)), int(tun.get("height", 1)), tcells.size()])
	lines.append("SPAWN: A=(%d,%d) B=(%d,%d)" % [
		field.spawn_center_a.x, field.spawn_center_a.y,
		field.spawn_center_b.x, field.spawn_center_b.y])
	lines.append("")
	lines.append("--- Clearance (rock # water ~ paces 1-9 A-C) ---")
	for y: int in range(field.length):
		var row := ""
		for x: int in range(field.width):
			row += _clearance_glyph(field, Vector2i(x, y))
		lines.append(row)
	lines.append("")
	lines.append("--- Height (quarter paces, rock #, water ~) ---")
	for hy: int in range(field.length):
		var hrow := ""
		for hx: int in range(field.width):
			hrow += _height_glyph(field, Vector2i(hx, hy))
		lines.append(hrow)


static func _clearance_glyph(field: BattlefieldArea, pos: Vector2i) -> String:
	if field.rock_cells.has(pos):
		return "#"
	if field.is_water(pos):
		return "~"
	return _digit(int(round(field.clearance(pos))))


static func _height_glyph(field: BattlefieldArea, pos: Vector2i) -> String:
	if field.rock_cells.has(pos):
		return "#"
	if field.is_water(pos):
		return "~"
	return _digit(int(round(field.get_terrain_height(pos) * 4.0)))


static func _digit(value: int) -> String:
	if value < 0 or value >= LevelDumpWriter.GRID_DIGITS.length():
		return "*"
	return LevelDumpWriter.GRID_DIGITS[value]
