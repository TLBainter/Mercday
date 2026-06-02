class_name TerrainGenerator


static func generate(width: int, length: int, unevenness: int, terrain_heights: Dictionary) -> void:
	var h_range: Vector2 = BattlefieldArea.UNEVENNESS_RANGE[unevenness]
	var spawn_buffer: int = BattlefieldArea.SPAWN_BUFFER
	var n_seeds: int = 3 + unevenness * 3
	for _s: int in range(n_seeds):
		var sx: int = randi() % width
		var sy: int = randi_range(spawn_buffer, length - spawn_buffer - 1)
		var peak: float = randf_range(h_range.x, h_range.y)
		var radius: float = float(randi_range(3, 8))
		for y: int in range(length):
			for x: int in range(width):
				var pos := Vector2i(x, y)
				var dist: float = Vector2(float(x - sx), float(y - sy)).length()
				var influence: float = maxf(0.0, 1.0 - dist / radius)
				terrain_heights[pos] = terrain_heights.get(pos, 0.0) + peak * influence

	for y: int in range(length):
		for x: int in range(width):
			var pos := Vector2i(x, y)
			terrain_heights[pos] = clampf(terrain_heights.get(pos, 0.0), h_range.x, h_range.y)

	for _p: int in range(1 + unevenness):
		smooth(terrain_heights, width, length)

	for x: int in range(width):
		for y: int in range(spawn_buffer + 2):
			var pos := Vector2i(x, y)
			terrain_heights[pos] = clampf(terrain_heights.get(pos, 0.0), 0.0, 0.25)
		for y: int in range(length - spawn_buffer - 2, length):
			var pos := Vector2i(x, y)
			terrain_heights[pos] = clampf(terrain_heights.get(pos, 0.0), 0.0, 0.25)
		for y: int in range(spawn_buffer + 2, spawn_buffer + 6):
			var pos := Vector2i(x, y)
			terrain_heights[pos] = clampf(terrain_heights.get(pos, 0.0), -0.5, 1.0)
		for y: int in range(length - spawn_buffer - 6, length - spawn_buffer - 2):
			var pos := Vector2i(x, y)
			terrain_heights[pos] = clampf(terrain_heights.get(pos, 0.0), -0.5, 1.0)


static func smooth(terrain_heights: Dictionary, width: int, length: int) -> void:
	var smoothed: Dictionary = {}
	var cardinal: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	for y: int in range(length):
		for x: int in range(width):
			var pos := Vector2i(x, y)
			var sum: float = terrain_heights.get(pos, 0.0)
			var count: int = 1
			for dir: Vector2i in cardinal:
				var nb: Vector2i = pos + dir
				if nb.x >= 0 and nb.x < width and nb.y >= 0 and nb.y < length:
					sum += terrain_heights.get(nb, 0.0)
				count += 1
			smoothed[pos] = sum / float(count)
	for key: Vector2i in smoothed.keys():
		terrain_heights[key] = smoothed[key]
