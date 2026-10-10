@tool
class_name ShareBalance extends RefCounted

#Keeps percent shares within a total: the moved share stays, the largest other shares give way down to a floor.

const TOTAL: int = 100
const FLOOR: int = 1


#The moved value clamps so every other entry keeps the floor; then the largest other entry above the floor loses 1
#until the sum fits (ties: the lowest index). A moved index out of range makes every entry an other.
static func rebalance(values: Array[int], moved: int, total: int = TOTAL, floor_value: int = FLOOR) -> Array[int]:
	var out: Array[int] = []
	out.assign(values)
	if out.is_empty() or out.size() * floor_value > total:
		return out
	if moved >= 0 and moved < out.size():
		out[moved] = clampi(out[moved], floor_value, total - floor_value * (out.size() - 1))
	var sum: int = _sum(out)
	while sum > total:
		var pick: int = -1
		for i: int in range(out.size()):
			if i == moved or out[i] <= floor_value:
				continue
			if pick < 0 or out[i] > out[pick]:
				pick = i
		if pick < 0:
			break
		out[pick] -= 1
		sum -= 1
	return out


#Walking in order, each entry keeps what still fits in the total; entries past the total come back 0.
static func clip(values: Array[int], total: int = TOTAL) -> Array[int]:
	var out: Array[int] = []
	var kept: int = 0
	for v: int in values:
		var share: int = mini(maxi(v, 0), total - kept)
		out.append(share)
		kept += share
	return out


static func remainder(values: Array[int], total: int = TOTAL) -> int:
	return maxi(total - _sum(values), 0)


static func _sum(values: Array[int]) -> int:
	var total: int = 0
	for v: int in values:
		total += v
	return total
