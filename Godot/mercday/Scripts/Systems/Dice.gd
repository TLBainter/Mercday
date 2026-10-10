class_name Dice


#The front of a test queue when it holds a roll, otherwise a fresh roll of 1 to 100.
static func d100(queue: Array[int]) -> int:
	if not queue.is_empty():
		return queue.pop_front()
	return randi_range(1, 100)


#The single forced slot a test set, else a fresh d100; the caller clears its own slot afterwards.
static func forced_or_d100(forced: int) -> int:
	return forced if forced >= 1 else randi_range(1, 100)
