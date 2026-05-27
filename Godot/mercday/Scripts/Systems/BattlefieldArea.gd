class_name BattlefieldArea extends RefCounted

const MIN_DIM := 10
const MAX_DIM := 25

# cells per area unit per density level; 0 = minimal, 4 = excessive
const COVER_DENSITY: Array[float] = [0.01, 0.03, 0.05, 0.08, 0.12]
const COVER_AMOUNT_NAMES: Array[String] = ["minimal", "some", "average", "many", "excessive"]

const SPAWN_BUFFER := 3

var width: int
var length: int
var height: int
var cover_amount: int
var obstacles: Array[Dictionary] = []   # [{pos: Vector2i, size: int}]


static func generate_random() -> BattlefieldArea:
	var f := BattlefieldArea.new()
	f.width  = randi_range(MIN_DIM, MAX_DIM)
	f.length = randi_range(MIN_DIM, MAX_DIM)
	f.height = randi_range(MIN_DIM, MAX_DIM)
	f.cover_amount = randi() % 5
	f._generate_cover()
	return f


func clamp_position(pos: Vector2i) -> Vector2i:
	return Vector2i(clamp(pos.x, 0, width - 1), clamp(pos.y, 0, length - 1))


func to_log_string() -> String:
	return "Battlefield: %d×%d (height %d) — %s cover" % [
		width, length, height, COVER_AMOUNT_NAMES[cover_amount]]


func _generate_cover() -> void:
	obstacles.clear()
	var density: float = COVER_DENSITY[cover_amount]
	var target_count: int = int(width * length * density)
	var placed := 0
	var max_attempts := target_count * 20
	for _i: int in range(max_attempts):
		if placed >= target_count:
			break
		var pos := Vector2i(randi() % width, randi() % length)
		if _in_spawn_zone(pos) or _is_obstacle_at(pos):
			continue
		obstacles.append({"pos": pos, "size": randi_range(1, 5)})
		placed += 1
	_ensure_pathability()


func _in_spawn_zone(pos: Vector2i) -> bool:
	return pos.y < SPAWN_BUFFER or pos.y >= length - SPAWN_BUFFER


func _is_obstacle_at(pos: Vector2i) -> bool:
	for obs: Dictionary in obstacles:
		if (obs["pos"] as Vector2i) == pos:
			return true
	return false


func _ensure_pathability() -> void:
	while not _is_passable() and obstacles.size() > 0:
		obstacles.remove_at(randi() % obstacles.size())


func _is_passable() -> bool:
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = []
	for x: int in range(width):
		var start := Vector2i(x, 0)
		if not _is_obstacle_at(start) and not visited.has(start):
			visited[start] = true
			queue.append(start)
	var dirs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		if curr.y == length - 1:
			return true
		for d: Vector2i in dirs:
			var nxt: Vector2i = curr + d
			if nxt.x < 0 or nxt.x >= width or nxt.y < 0 or nxt.y >= length:
				continue
			if visited.has(nxt) or _is_obstacle_at(nxt):
				continue
			visited[nxt] = true
			queue.append(nxt)
	return false


func is_obstacle(pos: Vector2i) -> bool:
	return _is_obstacle_at(pos)


func get_obstacle_at(pos: Vector2i) -> Dictionary:
	for obs: Dictionary in obstacles:
		if (obs["pos"] as Vector2i) == pos:
			return obs
	return {}


func get_adjacent_obstacles(pos: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var obs: Dictionary = get_obstacle_at(pos + Vector2i(dx, dy))
			if not obs.is_empty():
				result.append(obs)
	return result
