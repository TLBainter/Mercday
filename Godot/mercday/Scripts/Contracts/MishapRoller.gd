class_name MishapRoller

#Rolls the contract's mishap pool; each success draws one event that has not been picked yet.


static func roll(contract: ContractData, config: ContractConfig) -> Array[String]:
	var picked: Array[String] = []
	if contract == null or config == null:
		return picked
	for _i: int in range(maxi(0, config.max_mishaps)):
		if randf() * 100.0 >= config.mishap_chance:
			continue
		var candidates: Array[String] = []
		for name: String in contract.mishap_pool:
			if not picked.has(name):
				candidates.append(name)
		if candidates.is_empty():
			break
		picked.append(candidates[randi() % candidates.size()])
	return picked
