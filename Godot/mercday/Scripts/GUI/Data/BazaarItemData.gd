class_name BazaarItemData extends RefCounted

#One Bazaar catalog item. department is the filter key ("weapons") and department_label the name
#the screens print ("Weapons"). rarity indexes BazaarManager.RARITIES and featured_rank is the
#fixed shuffle position the Featured sort reads.

var id: int = 0
var name: String = ""
var department: String = ""
var department_label: String = ""
var subtype: String = ""
var rarity: int = 0
var price: int = 0
var featured_rank: int = 0


static func from_dict(d: Dictionary) -> BazaarItemData:
	var item := BazaarItemData.new()
	item.id = int(d.get("id", 0))
	item.name = str(d.get("name", ""))
	item.department = str(d.get("department", ""))
	item.department_label = str(d.get("department_label", ""))
	item.subtype = str(d.get("subtype", ""))
	item.rarity = int(d.get("rarity", 0))
	item.price = int(d.get("price", 0))
	item.featured_rank = int(d.get("featured_rank", 0))
	return item


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "department": department,
		"department_label": department_label, "subtype": subtype, "rarity": rarity,
		"price": price, "featured_rank": featured_rank}
