class_name GuiCalendarHelpCases
extends RefCounted

#Case 1 of --gui-calendar-tests (the CalendarButton in TimeMenu) and the calendar help tags; GuiCalendarTests runs them.

const CAL_IDS: Array[StringName] = [&"cal_nav", &"cal_grid", &"cal_detail", &"cal_filter"]
const HUD_ID: StringName = &"hud_calendar"


static func button(res: Dictionary, menu: TimeMenu) -> void:
	var at: int = menu.calendar_button().get_index()
	TestFixtures.check(res, "calendar button sits between TimeLabel and Divider",
		menu.time_label().get_index() == at - 1 and menu.get_child(at + 1).name == &"Divider", "index %d" % at)
	TestFixtures.check(res, "calendar button is not in the speed group", menu.calendar_button().button_group == null,
		str(menu.calendar_button().button_group))


#The open dialog is the scope of the four calendar tags, each with a live control, also after the filter rows are rebuilt.
static func tags(res: Dictionary, host: Node, dialog: CalendarDialog, menu: TimeMenu) -> void:
	dialog.open_on(GameState.day())
	await host.get_tree().process_frame
	var first: Array[String] = _missing(host, dialog)
	dialog.filter.build(dialog.sources)
	await host.get_tree().process_frame
	var again: Array[String] = _missing(host, dialog)
	TestFixtures.check(res, "the calendar frame scope holds cal_nav, cal_grid, cal_detail and cal_filter, also after a rebuild",
		first.is_empty() and again.is_empty(), "missing %s then %s" % [first, again])
	print("GUI CALENDAR help tags live (tags, live, outside the test menu): %s" % _live(host, menu))
	dialog.close()


static func _missing(host: Node, dialog: CalendarDialog) -> Array[String]:
	var scan: Dictionary = HintScope.collect(host)
	var out: Array[String] = []
	if scan["root"] != dialog:
		out.append("scope %s" % scan["root"])
	var want: Array[Control] = [dialog.nav, dialog.grid, dialog.detail, dialog.filter]
	for i: int in CAL_IDS.size():
		var id: StringName = CAL_IDS[i]
		var links: Array = _links(host, id).filter(func(link: HelpTarget) -> bool: return dialog.is_ancestor_of(link))
		var box: Control = (links[0] as HelpTarget).control() if links.size() == 1 else null
		if box == null or box != want[i] or not box.is_inside_tree() or not (scan["present"] as Array).has(id) \
				or (scan["controls"] as Dictionary).get(id) != want[i]:
			out.append(String(id))
	return out


#Per id: how many tags, how many are in the tree with a hint and a control, how many sit outside the test's own menu.
static func _live(host: Node, menu: TimeMenu) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var ids: Array[StringName] = [HUD_ID]
	ids.append_array(CAL_IDS)
	for id: StringName in ids:
		var links: Array = _links(host, id)
		var live: int = links.filter(func(link: HelpTarget) -> bool:
			return link.is_inside_tree() and link.hint != null and link.control() != null).size()
		var outside: int = links.filter(func(link: HelpTarget) -> bool: return not menu.is_ancestor_of(link)).size()
		parts.append("%s %d %d %d" % [id, links.size(), live, outside])
	return ", ".join(parts)


static func _links(host: Node, id: StringName) -> Array[HelpTarget]:
	var out: Array[HelpTarget] = []
	for node: Node in host.get_tree().get_nodes_in_group(HelpTarget.GROUP):
		var link: HelpTarget = node as HelpTarget
		if link != null and link.hint_id() == id:
			out.append(link)
	return out
