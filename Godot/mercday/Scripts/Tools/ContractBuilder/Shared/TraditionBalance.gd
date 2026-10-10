@tool
class_name TraditionBalance extends RefCounted

#Keeps each sign's tradition total within the cap: the other entries on the moved value's side step toward 0.


#The largest other entry on the moved side steps first (ties: the lowest index); a zero moved value changes nothing.
static func rebalance(values: Array[int], moved: int, cap: int = 50, step: int = 5) -> Array[int]:
	var out: Array[int] = []
	out.assign(values)
	if moved < 0 or moved >= out.size() or out[moved] == 0 or step <= 0:
		return out
	var side: int = signi(out[moved])
	while _side_sum(out, side) > cap:
		var pick: int = -1
		for i: int in range(out.size()):
			if i == moved or signi(out[i]) != side:
				continue
			if pick < 0 or absi(out[i]) > absi(out[pick]):
				pick = i
		if pick < 0:
			break
		out[pick] = side * maxi(absi(out[pick]) - step, 0)
	return out


static func _side_sum(values: Array[int], side: int) -> int:
	var total: int = 0
	for v: int in values:
		if signi(v) == side:
			total += absi(v)
	return total
