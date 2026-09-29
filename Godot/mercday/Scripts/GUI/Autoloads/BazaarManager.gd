extends Node

#The Bazaar: the catalog the shop lists, the cart and the orders on their way. Rarity, delivery
#speed and the unlock itself come from SubscriptionManager.entitlements(); nothing here branches
#on a plan name. The catalog is generated placeholder stock until real items exist.

signal cart_changed
signal order_placed(order: OrderData)
signal order_arrived(order: OrderData)

const RARITIES: Array[Dictionary] = [
	{"name": "Ordinary", "color": "#a0a8b8", "mult": 1.0},
	{"name": "Common", "color": "#f3ead7", "mult": 2.5},
	{"name": "Uncommon", "color": "#6cc36a", "mult": 6.0},
	{"name": "Rare", "color": "#5aa6e8", "mult": 15.0},
	{"name": "Very Rare", "color": "#a36ce8", "mult": 40.0},
]
#One entry per Faster Items tier, 0 being the plain Bazaar unlock.
const DELIVERY_DAYS: Array[int] = [20, 15, 14, 11, 10, 2]
const DEPARTMENTS: Array[Dictionary] = [
	{"key": "weapons", "name": "Weapons", "base": 40,
		"subtypes": ["Swords", "Axes", "Bows", "Daggers", "Staves", "Firearms"],
		"singular": {"Swords": "Sword", "Axes": "Axe", "Bows": "Bow", "Daggers": "Dagger",
			"Staves": "Staff", "Firearms": "Firearm"}},
	{"key": "armor", "name": "Armor", "base": 50,
		"subtypes": ["Light Armor", "Medium Armor", "Heavy Armor", "Shields"],
		"singular": {"Light Armor": "Light Armor", "Medium Armor": "Medium Armor",
			"Heavy Armor": "Heavy Armor", "Shields": "Shield"}},
	{"key": "headwear", "name": "Headwear", "base": 25,
		"subtypes": ["Helmets", "Hoods", "Hats", "Circlets"],
		"singular": {"Helmets": "Helmet", "Hoods": "Hood", "Hats": "Hat",
			"Circlets": "Circlet"}},
	{"key": "containers", "name": "Containers", "base": 20,
		"subtypes": ["Backpacks", "Pouches", "Quivers", "Chests"],
		"singular": {"Backpacks": "Backpack", "Pouches": "Pouch", "Quivers": "Quiver",
			"Chests": "Chest"}},
	{"key": "tools", "name": "Tools", "base": 30,
		"subtypes": ["Kits", "Instruments", "Navigation"],
		"singular": {"Kits": "Kit", "Instruments": "Instrument", "Navigation": "Compass"}},
	{"key": "consumables", "name": "Consumables", "base": 8,
		"subtypes": ["Potions", "Rations", "Scrolls", "Bombs"],
		"singular": {"Potions": "Potion", "Rations": "Ration", "Scrolls": "Scroll",
			"Bombs": "Bomb"}},
	{"key": "trinkets", "name": "Trinkets", "base": 35,
		"subtypes": ["Rings", "Amulets", "Charms"],
		"singular": {"Rings": "Ring", "Amulets": "Amulet", "Charms": "Charm"}},
]
#hi -1 is no ceiling; a price sits in a preset while lo <= price < hi.
const PRICE_PRESETS: Array[Dictionary] = [
	{"key": &"any", "label": "Any Price", "lo": 0, "hi": -1},
	{"key": &"u50", "label": "Under 50", "lo": 0, "hi": 50},
	{"key": &"50", "label": "50 to 150", "lo": 50, "hi": 150},
	{"key": &"150", "label": "150 to 400", "lo": 150, "hi": 400},
	{"key": &"400", "label": "400 & Above", "lo": 400, "hi": -1},
]
const SORTS: Array[StringName] = [&"featured", &"price_asc", &"price_desc", &"rarity", &"name"]
const SORT_LABELS: Array[String] = ["Featured", "Price: Low to High", "Price: High to Low",
	"Rarity: Highest First", "Name: A to Z"]
const ORDER_FILTERS: Array[StringName] = [&"all", &"transit", &"delivered"]
const NO_CUSTOM_PRICE := Vector2i(-1, -1)

#PLACEHOLDER: every figure of the generated catalog. Real stock replaces this block whole.
const CATALOG_SEED := 77
const FIRST_ORDER_ID := 1001
const ITEMS_PER_SUBTYPE := 5
const RARITY_WEIGHTS: Array[int] = [30, 25, 20, 15, 10]
const PRICE_LOW := 0.7
const PRICE_HIGH := 1.3

var catalog: Array[BazaarItemData] = []
var cart: Dictionary = {}
var orders: Array[OrderData] = []
var next_order_id: int = FIRST_ORDER_ID

var _by_id: Dictionary = {}
var _sorters: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _seeded: bool = false


func _init() -> void:
	_sorters = {
		SORTS[0]: _cmp_featured,
		SORTS[1]: _cmp_price_asc,
		SORTS[2]: _cmp_price_desc,
		SORTS[3]: _cmp_rarity,
		SORTS[4]: _cmp_name,
	}


func _ready() -> void:
	GameState.roster_changed.connect(_on_roster_changed)
	GameState.day_changed.connect(_on_day_changed)
	reset()


#Rebuilds the catalog from the fixed seed and drops the cart and the orders.
func reset() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = CATALOG_SEED
	_build_catalog()
	cart.clear()
	orders.clear()
	next_order_id = FIRST_ORDER_ID
	_seeded = GameState.started
	cart_changed.emit()


func _on_roster_changed() -> void:
	_seed_if_started()


func _on_day_changed(_day_index: int) -> void:
	if _seed_if_started():
		return
	for order: OrderData in orders:
		if order.arrived or not is_delivered(order):
			continue
		#Hook: no guild storage exists, so a delivered order adds nothing to any inventory yet.
		order.arrived = true
		order_arrived.emit(order)


#Reseeds once, on the first signal after a campaign starts; true when this call did it.
func _seed_if_started() -> bool:
	if _seeded or not GameState.started:
		return false
	reset()
	return true


func _build_catalog() -> void:
	catalog.clear()
	_by_id.clear()
	var id: int = 1
	for dept: Dictionary in DEPARTMENTS:
		var base: int = int(dept["base"])
		var singular: Dictionary = dept["singular"] as Dictionary
		for subtype: String in (dept["subtypes"] as Array):
			for k: int in range(ITEMS_PER_SUBTYPE):
				var made := BazaarItemData.new()
				made.id = id
				id += 1
				made.name = "%s %d" % [str(singular.get(subtype, subtype)), k + 1]
				made.department = str(dept["key"])
				made.department_label = str(dept["name"])
				made.subtype = subtype
				made.rarity = _roll_rarity()
				var mult: float = float(RARITIES[made.rarity]["mult"])
				var jitter: float = _rng.randf_range(PRICE_LOW, PRICE_HIGH)
				made.price = maxi(1, int(round(float(base) * mult * jitter)))
				catalog.append(made)
				_by_id[made.id] = made
	_shuffle_featured()


func _roll_rarity() -> int:
	var total: int = 0
	for weight: int in RARITY_WEIGHTS:
		total += weight
	var roll: int = _rng.randi_range(1, total)
	for i: int in range(RARITY_WEIGHTS.size()):
		roll -= RARITY_WEIGHTS[i]
		if roll <= 0:
			return i
	return RARITY_WEIGHTS.size() - 1


#The Featured order: one seeded shuffle of the whole catalog, fixed until the next reset.
func _shuffle_featured() -> void:
	var order: Array[int] = []
	for i: int in range(catalog.size()):
		order.append(i)
	for i: int in range(order.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var held: int = order[i]
		order[i] = order[j]
		order[j] = held
	for rank: int in range(order.size()):
		catalog[order[rank]].featured_rank = rank


func _ent() -> Dictionary:
	return SubscriptionManager.entitlements()


func unlocked() -> bool:
	return bool(_ent().get("bazaar", false))


func delivery_days() -> int:
	var tier: int = clampi(int(_ent().get("bazaarSpeed", 0)), 0, DELIVERY_DAYS.size() - 1)
	return DELIVERY_DAYS[tier]


#The highest rarity the guild may buy at all.
func rarity_cap() -> int:
	return clampi(int(_ent().get("bazaarRarity", 0)), 0, RARITIES.size() - 1)


func available(found: BazaarItemData) -> bool:
	return found != null and found.rarity <= rarity_cap()


func item(id: int) -> BazaarItemData:
	return _by_id.get(id, null) as BazaarItemData


func add_to_cart(id: int, qty: int = 1) -> bool:
	if qty <= 0:
		return false
	return set_qty(id, int(cart.get(id, 0)) + qty)


#Writes an exact quantity; 0 or less takes the item out of the cart.
func set_qty(id: int, qty: int) -> bool:
	var found: BazaarItemData = item(id)
	if found == null or not available(found):
		return false
	if qty <= 0:
		if not cart.has(id):
			return false
		cart.erase(id)
	else:
		cart[id] = qty
	cart_changed.emit()
	return true


func remove_from_cart(id: int) -> bool:
	return set_qty(id, 0)


func clear_cart() -> void:
	if cart.is_empty():
		return
	cart.clear()
	cart_changed.emit()


#The item ids in the cart, lowest first, so every list reads the same way twice.
func cart_ids() -> Array[int]:
	var ids: Array[int] = []
	for id: Variant in cart:
		ids.append(int(id))
	ids.sort()
	return ids


func cart_count() -> int:
	var count: int = 0
	for id: int in cart_ids():
		count += int(cart[id])
	return count


func cart_total() -> int:
	var total: int = 0
	for id: int in cart_ids():
		var found: BazaarItemData = item(id)
		if found != null:
			total += found.price * int(cart[id])
	return total


func can_checkout() -> bool:
	return checkout_reason() == ""


#Why checkout is closed, in the words the Order Summary prints under the button.
func checkout_reason() -> String:
	if cart_count() <= 0:
		return "Your cart is empty."
	var short: int = cart_total() - GameState.bank_notes
	if short > 0:
		return "Not enough notes. Remove items or earn %d more." % short
	return ""


#Spends the notes, empties the cart and files the order; null when checkout is closed.
func place_order() -> OrderData:
	if not can_checkout():
		return null
	var total: int = cart_total()
	var order_id: int = next_order_id
	if not _pay(total, "bazaar", "Bazaar order #%d" % order_id):
		return null
	var order := OrderData.new()
	order.id = order_id
	next_order_id += 1
	order.placed_day = GameState.day()
	order.days = delivery_days()
	order.total = total
	for id: int in cart_ids():
		order.lines.append({"item_id": id, "qty": int(cart[id])})
	orders.append(order)
	cart.clear()
	cart_changed.emit()
	order_placed.emit(order)
	return order


func is_delivered(o: OrderData) -> bool:
	return o != null and o.placed_day + o.days <= GameState.day()


#Days until the order lands; 0 on the arrival day itself and negative once it is delivered.
func days_left(o: OrderData) -> int:
	if o == null:
		return 0
	return o.placed_day + o.days - GameState.day()


func progress(o: OrderData) -> float:
	if o == null or o.days <= 0:
		return 1.0
	return clampf(float(GameState.day() - o.placed_day) / float(o.days), 0.0, 1.0)


func in_transit_count() -> int:
	var count: int = 0
	for order: OrderData in orders:
		if not is_delivered(order):
			count += 1
	return count


#A delivered order the Orders tab has not shown yet; the tab dot reads this.
func has_unseen_delivery() -> bool:
	for order: OrderData in orders:
		if is_delivered(order) and not order.seen:
			return true
	return false


func mark_orders_seen() -> void:
	for order: OrderData in orders:
		if is_delivered(order):
			order.seen = true


#The Orders list under one of its three filters, newest first.
func orders_filtered(filter: StringName) -> Array[OrderData]:
	var out: Array[OrderData] = []
	for order: OrderData in orders:
		var done: bool = is_delivered(order)
		if filter == &"transit" and done:
			continue
		if filter == &"delivered" and not done:
			continue
		out.append(order)
	out.sort_custom(_cmp_order_newest)
	return out


func order_counts() -> Dictionary:
	var counts: Dictionary = {}
	for filter: StringName in ORDER_FILTERS:
		counts[filter] = orders_filtered(filter).size()
	return counts


#The shop list: every filter of q ANDed, then sorted by q["sort"].
func filter_items(q: Dictionary) -> Array[BazaarItemData]:
	var out: Array[BazaarItemData] = []
	for found: BazaarItemData in catalog:
		if _matches(found, q, true):
			out.append(found)
	var sort: StringName = StringName(q.get("sort", SORTS[0]))
	if _sorters.has(sort):
		out.sort_custom(_sorters[sort] as Callable)
	return out


#How many items each option of one dimension would show with the other filters applied.
#Dimensions: department (with "" for All Departments), subtype, rarity, price.
func option_counts(q: Dictionary, dimension: StringName) -> Dictionary:
	var counts: Dictionary = {}
	var reduced: Dictionary = q.duplicate(true)
	match dimension:
		&"department":
			reduced.erase("department")
			reduced.erase("subtypes")
			counts[""] = 0
			for dept: Dictionary in DEPARTMENTS:
				counts[str(dept["key"])] = 0
			for found: BazaarItemData in catalog:
				if not _matches(found, reduced, true):
					continue
				counts[""] = int(counts[""]) + 1
				counts[found.department] = int(counts.get(found.department, 0)) + 1
		&"subtype":
			reduced.erase("subtypes")
			for subtype: String in _subtypes_of(str(q.get("department", ""))):
				counts[subtype] = 0
			for found: BazaarItemData in catalog:
				if not _matches(found, reduced, true) or not counts.has(found.subtype):
					continue
				counts[found.subtype] = int(counts[found.subtype]) + 1
		&"rarity":
			reduced.erase("rarities")
			for i: int in range(RARITIES.size()):
				counts[i] = 0
			for found: BazaarItemData in catalog:
				if not _matches(found, reduced, false):
					continue
				counts[found.rarity] = int(counts[found.rarity]) + 1
		&"price":
			reduced.erase("price_preset")
			reduced.erase("price_custom")
			for preset_row: Dictionary in PRICE_PRESETS:
				var key: StringName = preset_row["key"] as StringName
				counts[key] = 0
				for found: BazaarItemData in catalog:
					if _matches(found, reduced, true) and _in_preset(found.price, preset_row):
						counts[key] = int(counts[key]) + 1
	return counts


#The subtypes of one department, or every subtype when no department is picked.
func _subtypes_of(department: String) -> Array[String]:
	var out: Array[String] = []
	for dept: Dictionary in DEPARTMENTS:
		if department != "" and not _dept_is(dept, department):
			continue
		for subtype: String in (dept["subtypes"] as Array):
			out.append(subtype)
	return out


func _dept_is(dept: Dictionary, value: String) -> bool:
	return str(dept["key"]).to_lower() == value.to_lower() \
		or str(dept["name"]).to_lower() == value.to_lower()


func _matches(found: BazaarItemData, q: Dictionary, cap: bool) -> bool:
	return _rarity_ok(found, q, cap) and _dept_ok(found, q) and _sub_ok(found, q) \
		and _price_ok(found, q) and _search_ok(found, q)


func _rarity_ok(found: BazaarItemData, q: Dictionary, cap: bool) -> bool:
	if cap and found.rarity > rarity_cap():
		return false
	var picked: Array = q.get("rarities", []) as Array
	return picked.is_empty() or picked.has(found.rarity)


#The department filter reads either the key ("weapons") or the printed name ("Weapons").
func _dept_ok(found: BazaarItemData, q: Dictionary) -> bool:
	var want: String = str(q.get("department", ""))
	if want == "":
		return true
	return found.department.to_lower() == want.to_lower() \
		or found.department_label.to_lower() == want.to_lower()


func _sub_ok(found: BazaarItemData, q: Dictionary) -> bool:
	var picked: Array = q.get("subtypes", []) as Array
	return picked.is_empty() or picked.has(found.subtype)


#A custom range wins over the preset; either of its ends may be -1 for open.
func _price_ok(found: BazaarItemData, q: Dictionary) -> bool:
	var custom: Vector2i = q.get("price_custom", NO_CUSTOM_PRICE) as Vector2i
	if custom != NO_CUSTOM_PRICE:
		if custom.x >= 0 and found.price < custom.x:
			return false
		if custom.y >= 0 and found.price > custom.y:
			return false
		return true
	return _in_preset(found.price, preset(StringName(q.get("price_preset", &"any"))))


func _in_preset(price: int, preset_row: Dictionary) -> bool:
	if preset_row.is_empty():
		return true
	var hi: int = int(preset_row["hi"])
	return price >= int(preset_row["lo"]) and (hi < 0 or price < hi)


func preset(key: StringName) -> Dictionary:
	for row: Dictionary in PRICE_PRESETS:
		if row["key"] == key:
			return row
	return PRICE_PRESETS[0]


func _search_ok(found: BazaarItemData, q: Dictionary) -> bool:
	var text: String = str(q.get("search", "")).strip_edges().to_lower()
	if text == "":
		return true
	var hay: String = "%s %s %s" % [found.name, found.subtype, found.department_label]
	return hay.to_lower().contains(text)


func _cmp_featured(a: BazaarItemData, b: BazaarItemData) -> bool:
	return a.featured_rank < b.featured_rank


func _cmp_price_asc(a: BazaarItemData, b: BazaarItemData) -> bool:
	if a.price == b.price:
		return a.id < b.id
	return a.price < b.price


func _cmp_price_desc(a: BazaarItemData, b: BazaarItemData) -> bool:
	if a.price == b.price:
		return a.id < b.id
	return a.price > b.price


func _cmp_rarity(a: BazaarItemData, b: BazaarItemData) -> bool:
	if a.rarity != b.rarity:
		return a.rarity > b.rarity
	if a.price != b.price:
		return a.price < b.price
	return a.id < b.id


func _cmp_name(a: BazaarItemData, b: BazaarItemData) -> bool:
	if a.name == b.name:
		return a.id < b.id
	return a.name.naturalnocasecmp_to(b.name) < 0


func _cmp_order_newest(a: OrderData, b: OrderData) -> bool:
	if a.placed_day == b.placed_day:
		return a.id > b.id
	return a.placed_day > b.placed_day


#The one path an order takes to the bank; the label reaches the ledger with the order id.
func _pay(amount: int, reason: String, label: String) -> bool:
	return GameState.spend(amount, reason, label)
