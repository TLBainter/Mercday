class_name GuiMercTests

#Stage 2 Merc Viewer: the roster list, the merc header, the eight tabs and the salary dialog.
#Run: godot --headless --path . -- --gui-merc-tests

const MERC_VIEWER := preload("res://Scenes/GUI/Mercs/MercViewer.tscn")
const SUBWINDOW_SCENE := preload("res://Scenes/GUI/Shared/SubWindow.tscn")
const TRAIT_CARD_SCENE := preload("res://Scenes/GUI/Mercs/TraitCard.tscn")
const CENTRE_WIDTH: int = 208


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await _case_list(res, host)
	await _case_tabs(res, host)
	await _case_overview(res, host)
	await _case_header(res, host)
	await _case_salary(res, host)
	await _case_equipment(res, host)
	await _case_relationships(res, host)
	await _case_actions(res, host)
	await _case_traits(res, host)
	await _case_metrics(res, host)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	CampaignClock.reset()
	return TestFixtures.summarize(res, "GUI MERC")


static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()


static func _tradition_text(view: MercView) -> String:
	return view.tradition if view.tradition != "" else OverviewTab.EMPTY_TEXT


static func _open(host: Node) -> MercViewer:
	_fresh()
	var screen: MercViewer = MERC_VIEWER.instantiate()
	host.add_child(screen)
	await host.get_tree().process_frame
	return screen


static func _push_escape(host: Node) -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	host.get_viewport().push_input(event)


static func _salary_of(uid: int) -> int:
	for view: MercView in GameState.roster:
		if view.uid == uid:
			return view.monthly_salary
	return -1


static func _names(list: Array[MercView]) -> Array[String]:
	var out: Array[String] = []
	for view: MercView in list:
		out.append(view.name)
	return out


static func _case_list(res: Dictionary, host: Node) -> void:
	var screen: MercViewer = await _open(host)
	var roster: Array[MercView] = GameState.roster
	TestFixtures.check(res, "the list holds one row per roster merc",
		screen.list.row_count() == roster.size(),
		"rows %d roster %d" % [screen.list.row_count(), roster.size()])
	var first: MercView = screen.list.order()[0]
	TestFixtures.check(res, "the first row opens selected and the header matches",
		screen.selected() != null and screen.selected().uid == first.uid
			and screen.header.first_name() == MercHeader.split_name(first.name)[0],
		"selected '%s' header '%s'" % [screen.selected().name, screen.header.first_name()])
	var first_row: MercListItem = screen.list.rows()[0]
	TestFixtures.check(res, "a roster row carries the first name alone",
		first_row.name_label.text == MercHeader.split_name(first.name)[0]
			and not first_row.name_label.text.contains(" "),
		"row '%s' full '%s'" % [first_row.name_label.text, first.name])
	await host.get_tree().process_frame
	TestFixtures.check(res, "the list head reads Mercs and shown/total",
		screen.list.title_label.text == "Mercs"
			and screen.list.count_label.text == "%d/%d" % [roster.size(), roster.size()],
		"title '%s' count '%s'" % [screen.list.title_label.text, screen.list.count_label.text])
	var row: MercListItem = screen.list.rows()[0]
	var holder_rect: Rect2 = row.portrait_holder.get_global_rect()
	var strip_rect: Rect2 = row.strip.get_global_rect()
	TestFixtures.check(res, "a roster row wears the 56 px portrait cell with the band on top",
		row.portrait_holder.custom_minimum_size == Vector2(56, 56) and row.strip.band
			and absf(strip_rect.position.y - holder_rect.position.y) <= 1.0
			and is_equal_approx(strip_rect.size.y, 14.0),
		"holder %s strip %s band %s" % [holder_rect, strip_rect, row.strip.band])
	TestFixtures.check(res, "a roster row uses the tile badge",
		row.badge.size_mode == LevelBadge.SizeMode.TILE
			and row.badge.custom_minimum_size == Vector2(48, 56),
		"mode %d min %s" % [row.badge.size_mode, row.badge.custom_minimum_size])
	var other: MercListItem = screen.list.rows()[1]
	var sel_box: StyleBoxFlat = row.get_theme_stylebox("normal") as StyleBoxFlat
	var idle_box: StyleBoxFlat = other.get_theme_stylebox("normal") as StyleBoxFlat
	TestFixtures.check(res, "the selected row wears the orange ring and the others the ink ring",
		row.is_selected and sel_box != null and idle_box != null
			and sel_box.border_color == Color("#f28c28") and sel_box.bg_color == Color("#15223d")
			and idle_box.border_color == Color("#0a0f1c")
			and idle_box.bg_color == Color("#0e1628"),
		"selected %s %s idle %s %s" % [sel_box.border_color, sel_box.bg_color,
			idle_box.border_color, idle_box.bg_color])
	TestFixtures.check(res, "the sort row is 26 high",
		int(screen.list.sort_button.custom_minimum_size.y) == 26
			and int(screen.list.dir_toggle.custom_minimum_size.y) == 26
			and int(screen.list.dir_toggle.custom_minimum_size.x) == 40,
		"sort %s dir %s" % [screen.list.sort_button.custom_minimum_size,
			screen.list.dir_toggle.custom_minimum_size])
	var filter_btn: FilterButton = screen.list.filter_button()
	TestFixtures.check(res, "the sort row carries the filter button",
		filter_btn != null and filter_btn.text == "FILTER"
			and int(filter_btn.custom_minimum_size.y) == 26,
		"filter %s" % ("null" if filter_btn == null else filter_btn.text))
	TestFixtures.check(res, "the roster rows sit 1 px apart",
		screen.list.items.get_theme_constant("separation") == 1,
		"separation %d" % screen.list.items.get_theme_constant("separation"))
	TestFixtures.check(res, "the sort list spells out the guild and employment options",
		screen.list.sort_button.options[MercList.Sort.GUILD] == "Guild Opinion"
			and screen.list.sort_button.options[MercList.Sort.EMPLOYMENT] == "Employment Length",
		"options %s" % str(screen.list.sort_button.options))
	screen.show_merc(roster[3].uid)
	TestFixtures.check(res, "show_merc moves the selection",
		screen.selected().uid == roster[3].uid,
		"wanted %d got %d" % [roster[3].uid, screen.selected().uid])
	var by_level: Array[MercView] = MercList.sorted(roster, MercList.Sort.LEVEL, true)
	var falling: bool = true
	for i: int in range(1, by_level.size()):
		if by_level[i].level > by_level[i - 1].level:
			falling = false
	TestFixtures.check(res, "sorted by level descending never rises", falling,
		"levels %s" % str(by_level.map(func(v: MercView) -> int: return v.level)))
	var by_name: Array[MercView] = MercList.sorted(roster, MercList.Sort.NAME, false)
	var climbing: bool = true
	for i: int in range(1, by_name.size()):
		if by_name[i].name.naturalnocasecmp_to(by_name[i - 1].name) < 0:
			climbing = false
	TestFixtures.check(res, "sorted by name ascending is alphabetical", climbing,
		"names %s" % str(_names(by_name)))
	screen.list.sort_button.pick(MercList.Sort.NAME)
	var before: Array[String] = _names(screen.list.order())
	screen.list.dir_toggle.toggle()
	var after: Array[String] = _names(screen.list.order())
	before.reverse()
	TestFixtures.check(res, "the direction toggle reverses the name order",
		before == after, "got %s" % str(after))
	screen.hide_roster = true
	TestFixtures.check(res, "hide_roster drops the list and narrows the screen",
		not screen.list.visible and int(screen.custom_minimum_size.x) == MercViewer.NO_ROSTER_WIDTH,
		"visible %s width %d" % [screen.list.visible, int(screen.custom_minimum_size.x)])
	screen.queue_free()


static func _case_tabs(res: Dictionary, host: Node) -> void:
	var screen: MercViewer = await _open(host)
	await host.get_tree().process_frame
	var tabs: Array[TabButton] = screen.tabs()
	var content: VBoxContainer = screen.get_node("Margin/Columns/Content") as VBoxContainer
	var active_end: float = tabs[0].get_global_rect().end.y
	var body_top: float = screen.body.get_global_rect().position.y
	TestFixtures.check(res, "the tab bar joins the body",
		content.get_theme_constant("separation") == 0
			and screen.tab_row.get_theme_constant("separation") == 8
			and absf(active_end - body_top) <= 1.0,
		"sep %d row %d tab %f body %f" % [content.get_theme_constant("separation"),
			screen.tab_row.get_theme_constant("separation"), active_end, body_top])
	TestFixtures.check(res, "the active tab is 44 high and idle tabs 52x38",
		tabs[0].active and is_equal_approx(tabs[0].size.y, 44.0)
			and tabs[1].size == Vector2(52, 38),
		"active %s idle %s" % [tabs[0].size, tabs[1].size])
	var icon_rect: IconRect = tabs[1].icon_rect
	var icon_centre: Vector2 = icon_rect.get_global_rect().get_center()
	var tab_centre: Vector2 = tabs[1].get_global_rect().get_center()
	TestFixtures.check(res, "an idle tab centres a 24 px icon",
		icon_rect.size == Vector2(24, 24)
			and icon_rect.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			and icon_centre.distance_to(tab_centre) <= 1.0,
		"icon %s centre %s tab %s" % [icon_rect.size, icon_centre, tab_centre])
	TestFixtures.check(res, "the active tab shows its label beside the icon",
		tabs[0].text_label.visible and tabs[0].text_label.text == MercViewer.TAB_LABELS[0]
			and not tabs[1].text_label.visible and tabs[0].text == "" and tabs[1].text == "",
		"active '%s' idle %s button '%s'" % [tabs[0].text_label.text,
			tabs[1].text_label.visible, tabs[0].text])
	TestFixtures.check(res, "tabs wear the tab variations",
		tabs[0].theme_type_variation == &"TabActive"
			and tabs[1].theme_type_variation == &"TabIdle",
		"active %s idle %s" % [tabs[0].theme_type_variation, tabs[1].theme_type_variation])
	var wired: bool = screen.body.draw.is_connected(Callable(screen, "_draw_body_edges"))
	TestFixtures.check(res, "the body draws the orange top edge",
		wired and MercViewer.BODY_TOP_COLOR == Color("#f28c28"),
		"connected %s colour %s" % [wired, MercViewer.BODY_TOP_COLOR])
	screen.queue_free()


static func _case_overview(res: Dictionary, host: Node) -> void:
	var screen: MercViewer = await _open(host)
	var view: MercView = screen.selected()
	var tab: OverviewTab = screen.overview()
	var boxes: Array[AttributeBox] = tab.attribute_boxes()
	var bad: Array[String] = []
	for box: AttributeBox in boxes:
		var entry: Dictionary = view.attributes.get(box.attribute_key, {})
		if box.current != int(entry.get("current", 0)):
			bad.append(box.attribute_key)
	TestFixtures.check(res, "the four attribute boxes read the view",
		boxes.size() == 4 and bad.is_empty(), "boxes %d bad %s" % [boxes.size(), str(bad)])
	TestFixtures.check(res, "the HP bar reads hp and hp_max",
		tab.hp_bar.current == view.hp and tab.hp_bar.max_value == maxi(1, view.hp_max),
		"bar %d/%d view %d/%d" % [tab.hp_bar.current, tab.hp_bar.max_value, view.hp, view.hp_max])
	var chips: Array[SlotChip] = tab.lifepath_chips()
	TestFixtures.check(res, "the lifepath row holds eight chips with the filled ones first",
		chips.size() == OverviewTab.LIFEPATH_SLOTS
			and tab.filled_count(chips) == view.lifepaths.size(),
		"chips %d filled %d lifepaths %d"
			% [chips.size(), tab.filled_count(chips), view.lifepaths.size()])
	TestFixtures.check(res, "employment length opens at zero months",
		tab.employment_field.value == "0 months", "got '%s'" % tab.employment_field.value)
	TestFixtures.check(res, "the overview badge reads the level and the next level xp",
		tab.badge.level == view.level
			and tab.badge.next_level_xp == ExperienceSystem.xp_for_level(view.level + 1),
		"level %d next %d" % [tab.badge.level, tab.badge.next_level_xp])
	TestFixtures.check(res, "the overview badge is the 112 px tile",
		tab.badge.size_mode == LevelBadge.SizeMode.LARGE
			and tab.badge.custom_minimum_size == Vector2(112, 112),
		"mode %d min %s" % [tab.badge.size_mode, tab.badge.custom_minimum_size])
	var sigil_box: StyleBoxFlat = tab.sigil_box.get_theme_stylebox("panel") as StyleBoxFlat
	TestFixtures.check(res, "the title row reads the tradition beside the sigil",
		tab.tradition_label.text == _tradition_text(view) and tab.sigil.tradition == view.tradition
			and sigil_box != null
			and sigil_box.border_color == GuiTypes.tradition_color(view.tradition),
		"label '%s' sigil '%s' edge %s" % [tab.tradition_label.text, tab.sigil.tradition,
			sigil_box.border_color if sigil_box != null else Color.BLACK])
	TestFixtures.check(res, "the section heads count the filled chips",
		tab.lifepath_count.text == "%d/8" % view.lifepaths.size()
			and tab.knowledge_count.text == "%d/6" % tab.filled_count(tab.knowledge_chips())
			and tab.tool_count.text == "%d/6" % tab.filled_count(tab.tool_chips()),
		"lifepath '%s' knowledges '%s' tools '%s'" % [tab.lifepath_count.text,
			tab.knowledge_count.text, tab.tool_count.text])
	await host.get_tree().process_frame
	_check_chip_palettes(res, tab)
	var kg: Rect2 = tab.knowledge_grid.get_global_rect()
	var tg: Rect2 = tab.tool_grid.get_global_rect()
	TestFixtures.check(res, "knowledges and tools sit side by side",
		absf(kg.position.y - tg.position.y) <= 1.0 and kg.end.x <= tg.position.x,
		"knowledges %s tools %s" % [kg, tg])
	var badge_rect: Rect2 = tab.badge.get_global_rect()
	var mode_rect: Rect2 = tab.mode_list.get_global_rect()
	TestFixtures.check(res, "the mode list sits under the level badge in the same column",
		mode_rect.position.y >= badge_rect.end.y - 1.0
			and absf(mode_rect.position.x - badge_rect.position.x) <= 8.0,
		"mode %s badge %s" % [mode_rect, badge_rect])
	TestFixtures.check(res, "the level, the bars and the lifepath share one middle row",
		tab.middle.get_child_count() == 3
			and tab.get_node_or_null("Rows/Lifepath") == null,
		"children %d" % tab.middle.get_child_count())
	TestFixtures.check(res, "the mode list and the lifepath chips scroll in place",
		tab.mode_list.get_parent() is ScrollContainer
			and tab.lifepath_list.get_parent() is ScrollContainer,
		"mode parent '%s' chips parent '%s'" % [tab.mode_list.get_parent().name,
			tab.lifepath_list.get_parent().name])
	TestFixtures.check(res, "the info grid drops heritage and reads three columns",
		tab.fields.columns == 3 and tab.fields.get_node_or_null("Heritage") == null,
		"columns %d heritage %s" % [tab.fields.columns,
			tab.fields.get_node_or_null("Heritage")])
	var rows_box: VBoxContainer = tab.get_node("Rows") as VBoxContainer
	TestFixtures.check(res, "the overview page fits without a vertical scroll bar",
		rows_box.get_combined_minimum_size().y <= tab.size.y
			and not tab.get_v_scroll_bar().visible,
		"rows %f page %f bar %s" % [rows_box.get_combined_minimum_size().y, tab.size.y,
			tab.get_v_scroll_bar().visible])
	TestFixtures.check(res, "the three resource bars carry the answered fill colours",
		tab.hp_bar.fill_color == OverviewTab.HP_COLOR
			and tab.ep_bar.fill_color == OverviewTab.EP_COLOR
			and tab.mp_bar.fill_color == OverviewTab.MP_COLOR
			and OverviewTab.HP_COLOR == Color("#d6453d")
			and OverviewTab.EP_COLOR == Color("#6cc36a")
			and OverviewTab.MP_COLOR == Color("#5aa6e8"),
		"hp %s ep %s mp %s" % [tab.hp_bar.fill_color, tab.ep_bar.fill_color,
			tab.mp_bar.fill_color])
	var uid: int = view.uid
	tab.mode_list.pick_mode("Offensive")
	var extras: Dictionary = GameState.merc_extras.get(uid, {})
	TestFixtures.check(res, "picking a level mode writes it to merc_extras",
		String(extras.get("level_mode", "")) == "Offensive",
		"got '%s'" % String(extras.get("level_mode", "")))
	tab.set_view(null)
	TestFixtures.check(res, "set_view(null) clears the overview title row and badge",
		tab.tradition_label.text == OverviewTab.EMPTY_TEXT and tab.sigil.tradition == ""
			and tab.badge.level == 1,
		"tradition '%s' sigil '%s' level %d" % [tab.tradition_label.text, tab.sigil.tradition,
			tab.badge.level])
	screen.queue_free()


#The filled half is skipped when the opening roster hands this page no filled chip.
static func _check_chip_palettes(res: Dictionary, tab: OverviewTab) -> void:
	var filled_chip: SlotChip = null
	var empty_chip: SlotChip = null
	var heights_ok: bool = true
	for chip: SlotChip in tab.lifepath_chips():
		if int(chip.custom_minimum_size.y) != 32:
			heights_ok = false
		if chip.is_filled() and filled_chip == null:
			filled_chip = chip
		if not chip.is_filled() and empty_chip == null:
			empty_chip = chip
	var filled_ok: bool = true
	var empty_ok: bool = true
	var detail: String = "heights %s" % heights_ok
	if filled_chip != null:
		var box: StyleBoxFlat = filled_chip.get_theme_stylebox("panel") as StyleBoxFlat
		filled_ok = box != null and box.bg_color == Color("#2b4f8a")
		detail += " filled %s" % (box.bg_color if box != null else Color.BLACK)
	else:
		detail += " filled half skipped, no filled chip"
	if empty_chip != null:
		var box2: StyleBoxFlat = empty_chip.get_theme_stylebox("panel") as StyleBoxFlat
		empty_ok = box2 != null and box2.bg_color == Color("#0e1628")
		if empty_ok and box2.border_color != Color("#1f3560"):
			empty_ok = false
		detail += " empty %s" % (box2.bg_color if box2 != null else Color.BLACK)
	else:
		detail += " empty half skipped, no empty chip"
	TestFixtures.check(res, "chips wear the empty and filled palettes",
		heights_ok and filled_ok and empty_ok, detail)


static func _case_header(res: Dictionary, host: Node) -> void:
	var screen: MercViewer = await _open(host)
	var view: MercView = screen.selected()
	var head: MercHeader = screen.header
	var merc: MercenaryData = view.merc
	var page: OverviewTab = screen.overview()
	TestFixtures.check(res, "the header names the merc, the heritage and the tradition",
		head.merc_name() == view.name and page.tradition_label.text == _tradition_text(view)
			and head.heritage_label.text == (view.heritage if view.heritage != ""
				else MercHeader.EMPTY_TEXT),
		"name '%s' heritage '%s' tradition '%s'"
			% [head.merc_name(), head.heritage_label.text, page.tradition_label.text])
	TestFixtures.check(res, "the name block splits the first name from the rest",
		head.first_name() == MercHeader.split_name(view.name)[0]
			and head.surname() == MercHeader.split_name(view.name)[1]
			and head.surname_label.visible == (head.surname() != ""),
		"first '%s' rest '%s' shown %s" % [head.first_name(), head.surname(),
			head.surname_label.visible])
	TestFixtures.check(res, "split_name cuts at the first space only",
		MercHeader.split_name("Ada Vell") == ["Ada", "Vell"]
			and MercHeader.split_name("Merc 1 Name") == ["Merc", "1 Name"]
			and MercHeader.split_name("Solo") == ["Solo", ""],
		"got %s %s %s" % [MercHeader.split_name("Ada Vell"),
			MercHeader.split_name("Merc 1 Name"), MercHeader.split_name("Solo")])
	var heritage_caption: Label = head.get_node("Rows/Lineage/Heritage/Lines/Caption") as Label
	var age_caption: Label = head.get_node("Rows/Lineage/Age/Lines/Caption") as Label
	TestFixtures.check(res, "heritage and age wear the lineage box with a caption",
		heritage_caption.text == "Heritage" and age_caption.text == "Age"
			and head.get_node_or_null("Rows/Heritage") == null
			and head.get_node_or_null("Rows/Age") == null,
		"captions '%s' '%s'" % [heritage_caption.text, age_caption.text])
	var stock: String = merc.ancestry.ancestry_name if merc.ancestry != null else ""
	var blood: String = merc.bloodline.ancestry_name if merc.bloodline != null else ""
	var wanted: String = (blood + " " + stock).strip_edges()
	if wanted == "":
		wanted = MercHeader.EMPTY_TEXT
	TestFixtures.check(res, "the primary lineage row reads the bloodline and the ancestry",
		head.primary_text() == wanted, "row '%s' wanted '%s'" % [head.primary_text(), wanted])
	var r_stock: String = merc.recessive_ancestry.ancestry_name if merc.recessive_ancestry != null else ""
	var r_blood: String = merc.recessive_bloodline.ancestry_name if merc.recessive_bloodline != null else ""
	var r_wanted: String = (r_blood + " " + r_stock).strip_edges()
	if r_wanted == "":
		r_wanted = MercHeader.EMPTY_TEXT
	TestFixtures.check(res, "the secondary lineage row reads the recessive line or None",
		head.secondary_text() == r_wanted,
		"row '%s' wanted '%s'" % [head.secondary_text(), r_wanted])
	TestFixtures.check(res, "the age line reads the years and the band",
		merc.age > 0 and head.age_line() == "%d %s" % [merc.age, view.age_group],
		"line '%s' age %d band '%s'" % [head.age_line(), merc.age, view.age_group])
	TestFixtures.check(res, "the header chip reads the wage in the colour of the bank",
		head.salary_chip().value_label.text == str(view.monthly_salary)
			and head.salary_chip().color() == SalaryModule.color_for(view.monthly_salary,
				GameState.bank_notes),
		"text '%s' wage %d colour %s"
			% [head.salary_chip().value_label.text, view.monthly_salary,
				head.salary_chip().color()])
	TestFixtures.check(res, "the chip colour warns as the wage eats the bank",
		SalaryModule.color_for(5, 100) == SalaryModule.GREEN
			and SalaryModule.color_for(20, 100) == SalaryModule.ORANGE
			and SalaryModule.color_for(150, 100) == SalaryModule.RED,
		"5 %s 20 %s 150 %s" % [SalaryModule.color_for(5, 100), SalaryModule.color_for(20, 100),
			SalaryModule.color_for(150, 100)])
	TestFixtures.check(res, "the chip bevel is drawn, not laid out as a child",
		head.salary_chip().get_node_or_null("EdgeHi") == null
			and head.salary_chip().get_node_or_null("EdgeLo") == null
			and is_equal_approx(SalaryModule.EDGE_PX, 3.0),
		"edges %s %s px %f" % [head.salary_chip().get_node_or_null("EdgeHi"),
			head.salary_chip().get_node_or_null("EdgeLo"), SalaryModule.EDGE_PX])
	await host.get_tree().process_frame
	TestFixtures.check(res, "the header fits the 208 px centre column",
		head.get_combined_minimum_size().x <= CENTRE_WIDTH,
		"width %f limit %d" % [head.get_combined_minimum_size().x, CENTRE_WIDTH])
	var chip_rect: Rect2 = head.salary_chip().get_global_rect()
	var chip_row: Rect2 = head.salary_chip().get_node("Row").get_global_rect()
	var icon_rect: Rect2 = head.salary_chip().get_node("Row/IconBox").get_global_rect()
	var cap_rect: Rect2 = head.salary_chip().get_node("Row/Text/Caption").get_global_rect()
	var wage_rect: Rect2 = head.salary_chip().value_label.get_global_rect()
	TestFixtures.check(res, "the salary row centres with the caption and the wage at the edges",
		absf((chip_row.position.x - chip_rect.position.x)
			- (chip_rect.end.x - chip_row.end.x)) <= 2.0
			and absf(cap_rect.position.y - icon_rect.position.y) <= 2.0
			and absf(wage_rect.end.y - icon_rect.end.y) <= 2.0,
		"chip %s row %s icon %s caption %s wage %s"
			% [chip_rect, chip_row, icon_rect, cap_rect, wage_rect])
	var portrait_holder: Control = head.get_node("Rows/PortraitHolder") as Control
	TestFixtures.check(res, "item 39 the enlarged portrait fills its 196 px holder",
		head.portrait.pixel_size == 192 and int(portrait_holder.custom_minimum_size.y) == 196,
		"pixel_size %d holder %d"
			% [head.portrait.pixel_size, int(portrait_holder.custom_minimum_size.y)])
	TestFixtures.check(res, "the header carries the Merc View title",
		head.title_label.text == "Merc View", "title '%s'" % head.title_label.text)
	var frame_box: StyleBoxFlat = head.portrait_frame.get_theme_stylebox("panel") as StyleBoxFlat
	TestFixtures.check(res, "the portrait box wears the orange ring",
		frame_box != null and frame_box.border_color.is_equal_approx(Color("#f28c28"))
			and frame_box.border_width_top == 4,
		"edge %s" % [frame_box.border_color if frame_box != null else Color.BLACK])
	var head_strip: Rect2 = head.strip.get_global_rect()
	var head_holder: Rect2 = portrait_holder.get_global_rect()
	TestFixtures.check(res, "the status band sits at the top of the portrait box",
		head.strip.band and absf(head_strip.position.y - head_holder.position.y) <= 5.0
			and is_equal_approx(head_strip.size.y, 24.0),
		"strip %s holder %s" % [head_strip, head_holder])
	GuiFrameStack.clear()
	screen.select_tab(MercViewer.TAB_PERKS)
	head.salary_chip().clicked.emit()
	await host.get_tree().process_frame
	var dialog: SalaryDialog = screen.salary_dialog()
	TestFixtures.check(res, "the header chip opens the wage dialog from any tab",
		dialog.visible and dialog.merc_uid == view.uid
			and screen.current_tab() == MercViewer.TAB_PERKS,
		"visible %s uid %d tab %d" % [dialog.visible, dialog.merc_uid, screen.current_tab()])
	dialog.press_cancel()
	GuiFrameStack.clear()
	head.set_view(null)
	TestFixtures.check(res, "set_view(null) hides the strip and the salary and clears the portrait",
		head.merc_name() == MercHeader.EMPTY_TEXT and not head.salary_chip().visible
			and not head.strip.visible and head.portrait.merc_uid == 0,
		"name '%s' chip %s strip %s portrait %d"
			% [head.merc_name(), head.salary_chip().visible, head.strip.visible,
				head.portrait.merc_uid])
	screen.queue_free()


static func _case_salary(res: Dictionary, host: Node) -> void:
	var screen: MercViewer = await _open(host)
	GameState.bank_notes = 10000
	var view: MercView = screen.selected()
	var uid: int = view.uid
	var opening: int = view.monthly_salary
	var opinion: int = view.guild_opinion
	var dialog: SalaryDialog = screen.salary_dialog()
	var confirm: ConfirmDialog = screen.confirm
	var got: Array = []
	dialog.confirmed.connect(func(v: int, d: int) -> void: got.append([v, d]))
	GuiFrameStack.clear()
	dialog.open_for(view)
	TestFixtures.check(res, "the open wage dialog is the top frame",
		GuiFrameStack.top() == dialog and GuiFrameStack.depth() == 1,
		"top %s depth %d" % [GuiFrameStack.top(), GuiFrameStack.depth()])
	dialog.set_value(opening * 2)
	TestFixtures.check(res, "doubling the wage previews a four point rise",
		dialog.opinion_label.text == "Opinion +4" and dialog.opinion_delta() == 4,
		"label '%s' delta %d" % [dialog.opinion_label.text, dialog.opinion_delta()])
	dialog.press_confirm()
	await host.get_tree().process_frame
	TestFixtures.check(res, "confirm emits the value and delta",
		got.size() == 1 and int(got[0][0]) == opening * 2 and int(got[0][1]) == 4,
		"emitted %s" % str(got))
	TestFixtures.check(res, "a raise asks first in green with the wage and the delta",
		confirm.visible and confirm.title == MercViewer.RAISE_TITLE
			and confirm.message == MercViewer.SALARY_MESSAGE % [opening * 2, 4]
			and confirm.severity() == ConfirmDialog.Severity.GREEN,
		"title '%s' message '%s' severity %d"
			% [confirm.title, confirm.message, confirm.severity()])
	confirm.press(1)
	await host.get_tree().process_frame
	var after: MercView = screen.selected()
	TestFixtures.check(res, "confirming the raise writes the wage and moves the opinion",
		after.uid == uid and after.monthly_salary == opening * 2
			and after.guild_opinion == clampi(opinion + 4, SalarySystem.OPINION_MIN,
				SalarySystem.OPINION_MAX),
		"salary %d opinion %d from %d" % [after.monthly_salary, after.guild_opinion, opinion])
	var raised: int = after.monthly_salary
	dialog.open_for(screen.selected())
	dialog.set_value(opening)
	var cut_delta: int = dialog.opinion_delta()
	dialog.press_confirm()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a cut asks first in red with the negative delta",
		cut_delta < 0 and confirm.visible and confirm.title == MercViewer.CUT_TITLE
			and confirm.message == MercViewer.SALARY_MESSAGE % [opening, cut_delta]
			and confirm.severity() == ConfirmDialog.Severity.RED,
		"delta %d title '%s' message '%s' severity %d"
			% [cut_delta, confirm.title, confirm.message, confirm.severity()])
	confirm.press(0)
	await host.get_tree().process_frame
	TestFixtures.check(res, "refusing the ask leaves the wage where the raise put it",
		screen.selected().monthly_salary == raised,
		"salary %d wanted %d" % [screen.selected().monthly_salary, raised])
	dialog.open_for(screen.selected())
	dialog.set_value(raised)
	dialog.press_confirm()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the wage the merc already earns asks nothing",
		not confirm.visible and screen.selected().monthly_salary == raised,
		"asking %s salary %d" % [confirm.visible, screen.selected().monthly_salary])
	GameState.bank_notes = 100
	dialog.open_for(screen.selected())
	dialog.set_value(GameState.bank_notes + 50)
	TestFixtures.check(res, "the wage clamps to the notes in the bank",
		dialog.value() == GameState.bank_notes,
		"value %d notes %d" % [dialog.value(), GameState.bank_notes])
	dialog.set_value(1)
	dialog.step(-1)
	TestFixtures.check(res, "one note a month is the floor", dialog.value() == 1,
		"value %d" % dialog.value())
	var cancels: Array = []
	dialog.cancelled.connect(func() -> void: cancels.append(1))
	var held: int = screen.selected().monthly_salary
	dialog.set_value(held + 25)
	dialog.press_cancel()
	await host.get_tree().process_frame
	TestFixtures.check(res, "cancel closes the dialog and changes nothing",
		cancels.size() == 1 and not dialog.visible
			and screen.selected().monthly_salary == held,
		"cancels %d salary %d wanted %d"
			% [cancels.size(), screen.selected().monthly_salary, held])
	var pending_before: int = screen.selected().monthly_salary
	var probe_wage: int = 1 if pending_before != 1 else 2
	dialog.open_for(screen.selected())
	dialog.set_value(probe_wage)
	dialog.press_confirm()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the wage change asks before the confirm cancel test runs",
		confirm.visible, "visible %s" % confirm.visible)
	confirm.press(0)
	await host.get_tree().process_frame
	TestFixtures.check(res, "cancelling the confirm dialog leaves the salary unchanged",
		not confirm.visible and screen.selected().monthly_salary == pending_before,
		"visible %s salary %d wanted %d"
			% [confirm.visible, screen.selected().monthly_salary, pending_before])
	confirm.confirmed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a confirm emitted after the cancel writes no wage",
		screen.selected().monthly_salary == pending_before,
		"salary %d wanted %d" % [screen.selected().monthly_salary, pending_before])
	dialog.open_for(screen.selected())
	dialog.set_value(probe_wage)
	dialog.press_confirm()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a second confirm after a cancelled one still asks",
		confirm.visible, "visible %s" % confirm.visible)
	confirm.press(0)
	await host.get_tree().process_frame
	GameState.bank_notes = 10000
	var uid_a: int = screen.selected().uid
	var uid_b: int = 0
	for other: MercView in GameState.roster:
		if other.uid != uid_a:
			uid_b = other.uid
			break
	var a_before: int = _salary_of(uid_a)
	var b_before: int = _salary_of(uid_b)
	var swap_wage: int = a_before + 7
	dialog.open_for(screen.selected())
	dialog.set_value(swap_wage)
	dialog.press_confirm()
	await host.get_tree().process_frame
	screen.show_merc(uid_b)
	await host.get_tree().process_frame
	confirm.press(1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the wage lands on the merc the dialog was opened for",
		uid_b > 0 and _salary_of(uid_a) == swap_wage and _salary_of(uid_b) == b_before,
		"a %d wanted %d b %d wanted %d"
			% [_salary_of(uid_a), swap_wage, _salary_of(uid_b), b_before])
	var c_before: int = _salary_of(uid_a)
	var d_before: int = _salary_of(uid_b)
	var swap_wage2: int = c_before + 3
	if swap_wage2 == d_before:
		swap_wage2 += 5
	screen.show_merc(uid_a)
	await host.get_tree().process_frame
	#B's wage moves above the probe so the probe is a raise for A and a cut for B; a title read
	#against B instead of A flips CUT_TITLE in, catching a roster-change mixup the value swap alone
	#would miss.
	GameState.set_salary(uid_b, swap_wage2 + 50)
	d_before = _salary_of(uid_b)
	dialog.open_for(screen.selected())
	dialog.set_value(swap_wage2)
	screen.show_merc(uid_b)
	await host.get_tree().process_frame
	dialog.press_confirm()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a roster change under the open dialog still asks for the merc it opened for",
		confirm.visible and confirm.title == MercViewer.RAISE_TITLE
			and _salary_of(uid_a) == c_before and _salary_of(uid_b) == d_before,
		"confirm %s title %s a %d wanted %d b %d wanted %d"
			% [confirm.visible, confirm.title, _salary_of(uid_a), c_before, _salary_of(uid_b), d_before])
	confirm.press(1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "confirming after the roster change writes A's wage and leaves B's",
		_salary_of(uid_a) == swap_wage2 and _salary_of(uid_b) == d_before,
		"a %d wanted %d b %d wanted %d"
			% [_salary_of(uid_a), swap_wage2, _salary_of(uid_b), d_before])
	GuiFrameStack.clear()
	screen.queue_free()
	await host.get_tree().process_frame
	await _case_salary_escape(res, host)


#Item 34: the wage dialog is a frame like the rest, so Esc closes it and stops at the window under
#it instead of closing the Merc Viewer with it.
static func _case_salary_escape(res: Dictionary, host: Node) -> void:
	GuiFrameStack.clear()
	var win: SubWindow = SUBWINDOW_SCENE.instantiate()
	host.add_child(win)
	await host.get_tree().process_frame
	var screen: MercViewer = win.open(MERC_VIEWER) as MercViewer
	await host.get_tree().process_frame
	var dialog: SalaryDialog = screen.salary_dialog()
	dialog.open_for(screen.selected())
	TestFixtures.check(res, "the wage dialog stacks above the window it opened in",
		GuiFrameStack.top() == dialog and GuiFrameStack.depth() == 2,
		"top %s depth %d" % [GuiFrameStack.top(), GuiFrameStack.depth()])
	_push_escape(host)
	await host.get_tree().process_frame
	TestFixtures.check(res, "escape closes the wage dialog and leaves the viewer open",
		not dialog.visible and win.is_open() and GuiFrameStack.top() == win,
		"dialog %s window %s top %s" % [dialog.visible, win.is_open(), GuiFrameStack.top()])
	win.close()
	GuiFrameStack.clear()
	win.queue_free()
	await host.get_tree().process_frame


static func _case_equipment(res: Dictionary, host: Node) -> void:
	var screen: MercViewer = await _open(host)
	screen.select_tab(MercViewer.TAB_EQUIPMENT)
	var view: MercView = screen.selected()
	var tab: EquipmentTab = screen.page(MercViewer.TAB_EQUIPMENT) as EquipmentTab
	TestFixtures.check(res, "the three sections hold thirty two slots",
		tab.slot_count() == EquipmentTab.SLOT_COUNT and tab.worn_slots().size() == 8
			and tab.container_slots().size() == 8 and tab.carried_slots().size() == 16,
		"slots %d worn %d held %d carried %d" % [tab.slot_count(), tab.worn_slots().size(),
			tab.container_slots().size(), tab.carried_slots().size()])
	TestFixtures.check(res, "the slots carry their own names",
		tab.worn_slots()[0].caption == EquipmentTab.WORN_SLOTS[0]
			and tab.container_slots()[6].caption == EquipmentTab.CONTAINER_SLOTS[6]
			and tab.carried_slots()[0].caption_text() == "CARRIED 1",
		"worn '%s' held '%s' carried '%s'" % [tab.worn_slots()[0].caption,
			tab.container_slots()[6].caption, tab.carried_slots()[0].caption_text()])
	var edged: int = 0
	for slot: EquipSlot in tab.container_slots():
		if slot.container:
			edged += 1
	TestFixtures.check(res, "every container slot carries the blue edge", edged == 8,
		"edged %d" % edged)
	TestFixtures.check(res, "the filled slots match the view's gear",
		tab.filled_count() + tab.dropped == view.equipment.size(),
		"filled %d dropped %d gear %d" % [tab.filled_count(), tab.dropped,
			view.equipment.size()])
	var held: String = ""
	for row: Dictionary in view.equipment:
		if String(row.get("slot", "")) == EquipmentTab.WORN_SLOTS[0]:
			held = String(row.get("name", ""))
	TestFixtures.check(res, "the held weapon lands in the primary hand",
		tab.worn_slots()[0].item_name == held,
		"slot '%s' gear '%s'" % [tab.worn_slots()[0].item_name, held])
	TestFixtures.check(res, "the weight bar reads the load and the limit",
		is_equal_approx(tab.weight_bar.current_wt, view.weight)
			and is_equal_approx(tab.weight_bar.capacity, maxf(1.0, view.weight_limit)),
		"bar %.2f/%.2f view %.2f/%.2f" % [tab.weight_bar.current_wt, tab.weight_bar.capacity,
			view.weight, view.weight_limit])
	screen.queue_free()


static func _case_relationships(res: Dictionary, host: Node) -> void:
	var screen: MercViewer = await _open(host)
	screen.select_tab(MercViewer.TAB_RELATIONSHIPS)
	var view: MercView = screen.selected()
	var tab: RelationshipsTab = screen.page(MercViewer.TAB_RELATIONSHIPS) as RelationshipsTab
	TestFixtures.check(res, "one card per coworker",
		tab.card_count() == GameState.roster.size() - 1,
		"cards %d roster %d" % [tab.card_count(), GameState.roster.size()])
	TestFixtures.check(res, "the guild card reads the merc's opinion of the guild",
		tab.guild_card() != null and tab.guild_card().face() != null
			and tab.guild_card().face().opinion == view.guild_opinion,
		"face %d view %d" % [tab.guild_card().face().opinion if tab.guild_card().face() != null
			else 99, view.guild_opinion])
	var lit: int = 0
	for entry: MoodFace in tab.guild_card().faces:
		if entry.filled:
			lit += 1
	TestFixtures.check(res, "the guild row shows every opinion step and lights one",
		tab.guild_card().faces.size() == 11 and lit == 1,
		"faces %d lit %d" % [tab.guild_card().faces.size(), lit])
	TestFixtures.check(res, "the grid runs three cards wide",
		tab.grid.columns == RelationshipsTab.GRID_COLUMNS, "columns %d" % tab.grid.columns)
	TestFixtures.check(res, "the sort button offers the four relationship keys",
		tab.sort_button.options == RelationshipsTab.SORT_OPTIONS
			and tab.sort_button.selected == RelationshipsTab.SORT_HIGHEST,
		"options %s selected %d" % [str(tab.sort_button.options), tab.sort_button.selected])
	var order: Array[RelationshipCard] = tab.cards()
	TestFixtures.check(res, "the highest sort runs the warmest card first",
		order.size() < 2 or order[0].mood() >= order[order.size() - 1].mood(),
		"first %d last %d" % [order[0].mood(), order[order.size() - 1].mood()])
	var other: MercView = null
	for row: MercView in GameState.roster:
		if row.uid != view.uid:
			other = row
			break
	view.relationships[other.uid] = 10
	view.relationship_known_since[other.uid] = 3
	view.relationship_last_changed[other.uid] = 9
	tab.set_view(view)
	await host.get_tree().process_frame
	var found: RelationshipCard = null
	for card: RelationshipCard in tab.cards():
		if card.other_uid == other.uid:
			found = card
	TestFixtures.check(res, "a ten point bond reads the happiest face",
		found != null and found.mood() == 4,
		"mood %d" % [found.mood() if found != null else -1])
	TestFixtures.check(res, "the card names the mood under the first name",
		found != null and found.mood_label.text == MoodFace.MOOD_NAMES[4].to_upper()
			and found.name_label.text == RelationshipCard.first_name(other.name).to_upper(),
		"mood '%s' name '%s'" % [found.mood_label.text if found != null else "",
			found.name_label.text if found != null else ""])
	TestFixtures.check(res, "the card dates the first meeting and the last change",
		found != null and found.known_label.text == RelationshipCard.KNOWN_TEXT
				% RelationshipCard.day_text(3)
			and found.changed_label.text == RelationshipCard.CHANGED_TEXT
				% RelationshipCard.day_text(9)
			and found.tooltip_text.contains(found.known_label.text),
		"known '%s' changed '%s'" % [found.known_label.text if found != null else "",
			found.changed_label.text if found != null else ""])
	var blank: RelationshipCard = null
	for card: RelationshipCard in tab.cards():
		if card.other_uid != other.uid:
			blank = card
			break
	TestFixtures.check(res, "a coworker with no stored history carries no date lines",
		blank != null and blank.known_label.text == "" and blank.changed_label.text == ""
			and blank.known_since == RelationshipCard.NO_DAY
			and blank.last_changed == RelationshipCard.NO_DAY,
		"known %s changed %s" % [blank.known_since if blank != null else 0,
			blank.last_changed if blank != null else 0])
	screen.queue_free()


static func _case_actions(res: Dictionary, host: Node) -> void:
	var screen: MercViewer = await _open(host)
	screen.select_tab(MercViewer.TAB_ACTIONS)
	var view: MercView = screen.selected()
	var tab: ActionsTab = screen.page(MercViewer.TAB_ACTIONS) as ActionsTab
	TestFixtures.check(res, "one row per action the merc knows",
		tab.row_count() == view.actions.size(),
		"rows %d actions %d" % [tab.row_count(), view.actions.size()])
	var bad: Array[String] = []
	for row: ActionRow in tab.reactive_rows():
		if not row.is_reactive:
			bad.append(row.action_name)
	TestFixtures.check(res, "every row of the reactive group is reactive", bad.is_empty(),
		TestFixtures.detail(bad, tab.reactive_rows().size(), "rows"))
	TestFixtures.check(res, "the tab splits the actions into a turn column and a reactive column",
		tab.turn_list != tab.reactive_list
			and tab.turn_rows().size() + tab.reactive_rows().size() == tab.row_count(),
		"turn %d reactive %d" % [tab.turn_rows().size(), tab.reactive_rows().size()])
	TestFixtures.check(res, "the turn column is priced in AP and the reactive one in EP",
		tab.turn_unit.text == ActionsTab.TURN_UNIT
			and tab.reactive_unit.text == ActionsTab.REACTIVE_UNIT,
		"turn '%s' reactive '%s'" % [tab.turn_unit.text, tab.reactive_unit.text])
	var priced: Array[String] = []
	for row: ActionRow in tab.reactive_rows():
		var data: ActionData = tab.action_data(row.action_name)
		if data == null or row.cost_text() != "%d" % data.ep_cost:
			priced.append(row.action_name)
	TestFixtures.check(res, "a reactive row prices itself in the action's EP cost",
		priced.is_empty(), TestFixtures.detail(priced, tab.reactive_rows().size(), "rows"))
	TestFixtures.check(res, "the actions tab sorts on four keys and filters on none",
		tab.sort_button.options == ActionsTab.SORT_OPTIONS and tab.sort_button.selected == 0,
		"options %d selected %d" % [tab.sort_button.options.size(), tab.sort_button.selected])
	screen.queue_free()


static func _case_traits(res: Dictionary, host: Node) -> void:
	var screen: MercViewer = await _open(host)
	for row: MercView in GameState.roster:
		if not row.perks.is_empty():
			screen.show_merc(row.uid)
			break
	var view: MercView = screen.selected()
	screen.select_tab(MercViewer.TAB_PERKS)
	var perks: TraitTab = screen.page(MercViewer.TAB_PERKS) as TraitTab
	TestFixtures.check(res, "the perks tab holds one card per perk",
		perks.card_count() == view.perks.size(),
		"cards %d perks %d" % [perks.card_count(), view.perks.size()])
	TestFixtures.check(res, "the perk cards sit in a grid three wide",
		perks.panel.columns() == 3, "columns %d" % perks.panel.columns())
	TestFixtures.check(res, "the perks page is orange",
		perks.accent() == Color("#f28c28"), "accent %s" % perks.accent().to_html(false))
	TestFixtures.check(res, "the detail drops the rarity and acquired lines",
		perks.detail.get_node_or_null("Rows/Rarity") == null
			and perks.detail.get_node_or_null("Rows/Acquired") == null,
		"rarity %s acquired %s" % [perks.detail.get_node_or_null("Rows/Rarity"),
			perks.detail.get_node_or_null("Rows/Acquired")])
	if perks.card_count() > 0:
		var shown: Array[Dictionary] = perks.panel.shown_rows()
		perks.select_card(0)
		TestFixtures.check(res, "selecting the first card reads it into the detail",
			perks.detail_name() == String(shown[0].get("name", "")),
			"detail '%s' wanted '%s'" % [perks.detail_name(), String(shown[0].get("name", ""))])
		var first: TraitCard = perks.panel.cards()[0]
		TestFixtures.check(res, "the detail pill repeats the card's category",
			perks.detail.pill_label.text == first.category.to_upper() and perks.detail.pill.visible,
			"pill '%s' card '%s'" % [perks.detail.pill_label.text, first.category])
	screen.select_tab(MercViewer.TAB_DRAWBACKS)
	var drawbacks: TraitTab = screen.page(MercViewer.TAB_DRAWBACKS) as TraitTab
	TestFixtures.check(res, "the drawbacks tab holds one card per drawback",
		drawbacks.card_count() == view.drawbacks.size(),
		"cards %d drawbacks %d" % [drawbacks.card_count(), view.drawbacks.size()])
	screen.select_tab(MercViewer.TAB_SKILLS)
	var skills: TraitTab = screen.page(MercViewer.TAB_SKILLS) as TraitTab
	TestFixtures.check(res, "the skills tab says it is not designed yet",
		skills.card_count() == 0 and skills.empty_text() == TraitTab.SKILLS_TEXT,
		"cards %d text '%s'" % [skills.card_count(), skills.empty_text()])
	var card: TraitCard = TRAIT_CARD_SCENE.instantiate()
	card.custom_minimum_size.x = 176
	card.size.x = 176
	host.add_child(card)
	card.trait_name = "Legend in the Making and Beyond the Horizon"
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "a long name wraps and grows its card",
		card.name_label.get_line_count() >= 2 and card.size.y > 74.0,
		"lines %d height %s" % [card.name_label.get_line_count(), card.size.y])
	card.queue_free()
	screen.queue_free()


static func _case_metrics(res: Dictionary, host: Node) -> void:
	var screen: MercViewer = await _open(host)
	screen.select_tab(MercViewer.TAB_METRICS)
	var tab: MetricsTab = screen.page(MercViewer.TAB_METRICS) as MetricsTab
	TestFixtures.check(res, "the metrics tab shows when it is picked",
		screen.current_tab() == MercViewer.TAB_METRICS and tab.visible,
		"tab %d visible %s" % [screen.current_tab(), tab.visible])
	var absent: bool = not ResourceLoader.exists(MetricsTab.METRICS_SCENE)
	TestFixtures.check(res, "an absent metrics viewer falls back to the placeholder",
		tab.embed() != null and tab.is_placeholder() == absent,
		"placeholder %s scene absent %s" % [tab.is_placeholder(), absent])
	TestFixtures.check(res, "the tab fills the preview store when the campaign has no history",
		MetricsHistory.using_preview() and tab.seeded_preview()
			and MetricsHistory.days() == MetricsTab.PREVIEW_DAYS,
		"preview %s days %d" % [MetricsHistory.using_preview(), MetricsHistory.days()])
	var viewer: MetricsViewer = tab.embed() as MetricsViewer
	var points: int = viewer.chart.point_count(0) if viewer != null else 0
	TestFixtures.check(res, "the embedded chart draws a series for the locked merc",
		viewer != null and viewer.chart.series_count() > 0 and points > 0,
		"series %d points %d" % [viewer.chart.series_count() if viewer != null else 0, points])
	MetricsHistory.clear_preview()
	screen.queue_free()
