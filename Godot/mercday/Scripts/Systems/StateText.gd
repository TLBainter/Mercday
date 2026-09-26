class_name StateText


#The States.tsv Remove Text for a merc outside an encounter, with a plain fallback when the cell is blank.
static func remove_line(merc: MercenaryData, state_name: String) -> String:
	var short_name: String = merc.merc_name.get_slice(" ", 0)
	var text := narrate_text(state_name, "remove_text", short_name, "", BeauSystem.beau_name(merc, {}))
	if text == "":
		text = "%s is no longer %s." % [short_name, state_name]
	return text


#Fills the [Target], [Enemy] and [Beau] placeholders of an Afflict Text or Remove Text cell.
#"" when the cell is blank, and also when the text names [Beau] and the merc has no beau.
static func narrate_text(state_name: String, key: String, target_name: String, source_name: String,
		beau_name: String = "") -> String:
	var data: Dictionary = ConstStates.DATA.get(state_name, {})
	var text := str(data.get(key, ""))
	if text == "":
		return ""
	text = text.replace("[Target]", target_name)
	text = text.replace("[Enemy]", source_name if source_name != "" else "the enemy")
	if text.contains("[Beau]"):
		if beau_name == "":
			return ""
		text = text.replace("[Beau]", beau_name)
	return text
