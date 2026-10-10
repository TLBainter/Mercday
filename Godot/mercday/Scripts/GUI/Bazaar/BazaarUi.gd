class_name BazaarUi extends RefCounted

#The looks only the Bazaar screens use: the heading, the Silkscreen buttons and links, the inset
#panel and the shared atoms set up for the shop. Nothing here holds state; it reads
#BazaarManager.RARITIES and DEPARTMENTS only, for the rarity name and colour and the department
#name. Colours and the shared builders come from GuiColors and GuiStyle.

const CELL_BAR_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/CellBar.tscn")
const FEATURE_LOCK_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/FeatureLock.tscn")
const DROPDOWN_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/OptionDropdown.tscn")

const DIM: float = 0.4


#A section heading of the filter panel and of every card strip.
static func heading(body_text: String) -> Label:
	return GuiStyle.label(body_text, GuiStyle.SILK, 11, GuiColors.ORANGE)


#A bevelled button in Silkscreen; kind is a BevelButton palette name.
static func button(body_text: String, kind: StringName, height: float, font_size: int) -> Button:
	var made: BevelButton = GuiStyle.button(body_text, kind, height)
	made.add_theme_font_override("font", GuiStyle.SILK)
	made.add_theme_font_size_override("font_size", font_size)
	return made


#The underlined text buttons: Clear all filters and Remove.
static func link(body_text: String, tint: Color, font_size: int) -> Button:
	var made: Button = Button.new()
	made.text = body_text
	made.focus_mode = Control.FOCUS_NONE
	made.flat = true
	made.add_theme_font_override("font", GuiStyle.SILK)
	made.add_theme_font_size_override("font_size", font_size)
	made.add_theme_color_override("font_color", tint)
	made.add_theme_color_override("font_hover_color", GuiColors.CREAM)
	made.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	made.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	made.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	made.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return made


static func panel_box(fill: Color, border_px: int, border: Color, pad: float) -> PanelContainer:
	var made: PanelContainer = PanelContainer.new()
	made.add_theme_stylebox_override("panel", GuiStyle.flat(fill, border_px, border, pad))
	return made


#A caption that fills the row and its value on the right, both centred on the row height.
static func pair_row(caption: Control, value: Control) -> HBoxContainer:
	var row: HBoxContainer = GuiStyle.hbox(8)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	row.add_child(value)
	return row


#The centred block a page shows when it has nothing to list: the title, the note and one button,
#each on its own line. The caller keeps the note label and wires the button.
static func empty_state(title: String, note: Label, action: Button) -> VBoxContainer:
	var box: VBoxContainer = GuiStyle.vbox(10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lines: Array[Control] = [GuiStyle.label(title, GuiStyle.SILK_BOLD, 13, GuiColors.CREAM),
		note, action]
	for inner: Control in lines:
		var row: HBoxContainer = GuiStyle.hbox(0)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(inner)
		box.add_child(row)
	return box


#The square striped image slot of a shop card, cart line or order chip, ringed in the item's rarity.
#A null item leaves the ring for the caller to set once the item is known.
static func image_slot(item: BazaarItemData, side: float) -> ContractImageBox:
	var slot: ContractImageBox = ContractImageBox.new()
	slot.custom_minimum_size = Vector2(side, side)
	slot.stripe_color = GuiColors.BLUE_LO
	slot.ring_px = 2
	if item != null:
		slot.ring_color = rarity_color(item.rarity)
	return slot


#Wraps a quantity stepper in the ink box with the green ring and returns the box.
static func ringed_stepper(stepper: QuantityStepper) -> PanelContainer:
	var ring: PanelContainer = panel_box(GuiColors.INK, 2, GuiColors.GREEN, 2.0)
	ring.add_child(stepper)
	return ring


static func cell_bar(cells: int, height: int, gap: int) -> CellBar:
	var made: CellBar = CELL_BAR_SCENE.instantiate() as CellBar
	made.cells = cells
	made.cell_height = height
	made.gap = gap
	return made


static func dropdown() -> OptionDropdown:
	return DROPDOWN_SCENE.instantiate() as OptionDropdown


#A greyed locked control that opens the FeatureLock dialog; the caller adds it to its own row.
static func feature_lock(body_text: String, upgrade: String, upgrade_id: String, tier: int,
		tiers: int, height: float) -> FeatureLock:
	var made: FeatureLock = FEATURE_LOCK_SCENE.instantiate() as FeatureLock
	made.verb = "use"
	made.feature = body_text
	made.label = body_text
	made.upgrade = upgrade
	made.upgrade_id = upgrade_id
	made.tier = tier
	made.tiers = tiers
	made.height = height
	made.always_visible = true
	return made


static func rarity_name(rarity: int) -> String:
	var rows: Array[Dictionary] = BazaarManager.RARITIES
	return str(rows[clampi(rarity, 0, rows.size() - 1)]["name"])


static func rarity_color(rarity: int) -> Color:
	var rows: Array[Dictionary] = BazaarManager.RARITIES
	return Color(str(rows[clampi(rarity, 0, rows.size() - 1)]["color"]))


#The display name of a department key; an unknown key reads as itself.
static func dept_label(key: String) -> String:
	for dept: Dictionary in BazaarManager.DEPARTMENTS:
		if str(dept["key"]) == key:
			return str(dept["name"])
	return key


#"Arrives 4 Daith 212 (2-Day)" for the shop and cart lines; days come from the manager.
static func eta_text(days: int, day_index: int) -> String:
	var tail: String = "2-Day" if days == 2 else GuiDates.days_text(days)
	return "%s (%s)" % [GuiDates.day_text(day_index + days), tail]


static func plural(count: int, one: String, many: String) -> String:
	return "%d %s" % [count, one if count == 1 else many]
