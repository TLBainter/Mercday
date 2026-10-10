class_name HiringTab extends FinancePage

#The Hiring page of the Finance viewer: the shared filter column on the left, the applicant cards on
#the right. The page filters and sorts through PromotionsManager.applicants_filtered and never by
#itself; every card press marks the applicant seen and opens a modal on the modal host of the shell.
#A refresh while the page is hidden only marks it dirty, so the shell can leave it built and cold.
#A page held to fixed_campaign hides the filter column and lists that one campaign's applicants.

const CARD_SCENE: PackedScene = preload("res://Scenes/GUI/Finance/Hiring/ApplicantCard.tscn")
const DIALOG_SCENE: PackedScene = preload("res://Scenes/GUI/Finance/Hiring/HireOfferDialog.tscn")
const NOTICE_SCENE: PackedScene = preload("res://Scenes/GUI/Finance/Hiring/HiringNotice.tscn")
const PANEL_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/TraitFilterPanel.tscn")
const DROPDOWN_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/OptionDropdown.tscn")
const CONFIRM_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/ConfirmDialog.tscn")
const SORT_DIR_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/SortDirToggle.tscn")

const COLUMN_GAP: int = 16
const RIGHT_GAP: int = 10
const FILTER_WIDTH: int = 290
const FILTER_PAD: float = 12.0
const FILTER_GAP: int = 10
const FILTER_RING_PX: int = 3
const HEADER_GAP: int = 10
const SORT_SIZE: Vector2 = Vector2(160.0, 32.0)
const GRID_COLUMNS: int = 3
const GRID_GAP: int = 12
const LIST_MARGIN_TOP: int = 14
const LIST_MARGIN_RIGHT: int = 16
const LIST_MARGIN_BOTTOM: int = 4
const LIST_MARGIN_LEFT: int = 4
const NOTICE_TOP: int = 10
#How far the Finance window holds a page in from its edge: the window margin, page border and page pad.
const SHELL_INSET: int = 32

const TITLE_TEXT: String = "Applicants"
const TITLE_FIXED_FMT: String = TITLE_TEXT + ": %s"
const SORT_TEXT: String = "Sort"
const COUNT_FMT: String = "%d of %d applicants shown"
const COUNT_FIXED_FMT: String = "%d applicants"
const EMPTY_FILTERED: String = "No applicants match your filters."
const EMPTY_NONE: String = "No applicants yet. Run a Job Posting to attract mercs."
const EMPTY_FIXED: String = "No applicants from this posting."
const REJECT_TITLE: String = "Reject %s?"
const REJECT_BODY: String = "Their application is removed."
const REJECT_YES: String = "Reject"
const CANCEL_TEXT: String = "Cancel"
const HIRE_TITLE: String = "Hire %s?"
const HIRE_BODY: String = "Salary: %s notes / month. Uses 1 merc slot."
const HIRE_YES: String = "Hire"
const NOTICE_HIRED: String = "%s joined your guild."
const NOTICE_REFUSED: String = "%s refused your counter-offer."
const NOTICE_ACCEPTED: String = "%s accepted your counter-offer."
const VALUE_GROUP: String = "Value"
const LOCK_VERB: String = "filter by"
const KIND_REJECT: String = "reject"
const KIND_HIRE: String = "hire"
const NO_FIXED: int = FinanceViewer.NO_FIXED

#Set before the page enters the tree; NO_FIXED lists every applicant.
var fixed_campaign: int = NO_FIXED

var _sort: StringName = &"fit"
var _desc: bool = true
var _shown: Array[int] = []
var _pending: Dictionary = {}

var _filter_column: PanelContainer = null
var _panel: TraitFilterPanel = null
var _title: Label = null
var _count: Label = null
var _sort_pick: OptionDropdown = null
var _sort_dir: SortDirToggle = null
var _grid: GridContainer = null
var _empty: Label = null
var _notice: HiringNotice = null
var _dialog: HireOfferDialog = null
var _confirm: ConfirmDialog = null
var _popup: ViewerPopup = null
var _cards: Dictionary = {}


func _ready() -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", COLUMN_GAP)
	add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.add_child(_build_filter_column())
	columns.add_child(_build_right_column())
	_build_notice()
	_build_modals()
	_wire()
	_reset_defs()
	refresh()


func _build_filter_column() -> Control:
	_filter_column = HiringStyle.panel(GuiColors.ROW_FILL, FILTER_RING_PX, GuiColors.INK, FILTER_PAD,
		FILTER_PAD)
	_filter_column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", FILTER_GAP)
	_filter_column.add_child(col)
	_panel = PANEL_SCENE.instantiate() as TraitFilterPanel
	if _panel != null:
		_panel.panel_width = FILTER_WIDTH
		_panel.show_clear = true
		_panel.lock_verb = LOCK_VERB
		_panel.footer_note = ""
		_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(_panel)
	_filter_column.visible = not is_fixed()
	return _filter_column


func _build_right_column() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", RIGHT_GAP)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_build_header())
	col.add_child(_build_list())
	return col


#A fixed page has no tab row above it, so its header stops one close reserve short of the window edge.
func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", HEADER_GAP)
	var left := VBoxContainer.new()
	left.add_theme_constant_override(&"separation", 2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title = HiringStyle.label(title_text(), GuiStyle.SILK_BOLD, 16, GuiColors.ORANGE)
	left.add_child(_title)
	_count = HiringStyle.label("", GuiStyle.BODY, 14, GuiColors.SKY)
	left.add_child(_count)
	row.add_child(left)
	var tag: Label = HiringStyle.label(SORT_TEXT, GuiStyle.SILK, 9, GuiColors.SKY)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tag)
	_sort_pick = DROPDOWN_SCENE.instantiate() as OptionDropdown
	if _sort_pick != null:
		_sort_pick.custom_minimum_size = SORT_SIZE
		_sort_pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(_sort_pick)
	_sort_dir = SORT_DIR_SCENE.instantiate() as SortDirToggle
	_sort_dir.descending = _desc
	_sort_dir.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_sort_dir)
	if not is_fixed():
		return row
	var pad := MarginContainer.new()
	pad.add_theme_constant_override(&"margin_right", int(SubWindow.CLOSE_RESERVE) - SHELL_INSET)
	pad.add_child(row)
	return pad


func _build_list() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pad := MarginContainer.new()
	pad.add_theme_constant_override(&"margin_top", LIST_MARGIN_TOP)
	pad.add_theme_constant_override(&"margin_right", LIST_MARGIN_RIGHT)
	pad.add_theme_constant_override(&"margin_bottom", LIST_MARGIN_BOTTOM)
	pad.add_theme_constant_override(&"margin_left", LIST_MARGIN_LEFT)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", GRID_GAP)
	pad.add_child(col)
	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override(&"h_separation", GRID_GAP)
	_grid.add_theme_constant_override(&"v_separation", GRID_GAP)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_grid)
	_empty = HiringStyle.label("", GuiStyle.BODY, 15, GuiColors.SKY)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_empty.hide()
	col.add_child(_empty)
	return scroll


func _build_notice() -> void:
	var layer := MarginContainer.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_theme_constant_override(&"margin_top", NOTICE_TOP)
	add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	layer.add_child(row)
	_notice = NOTICE_SCENE.instantiate() as HiringNotice
	if _notice != null:
		row.add_child(_notice)


func _build_modals() -> void:
	var host: Control = modal_host()
	_dialog = DIALOG_SCENE.instantiate() as HireOfferDialog
	if _dialog != null:
		host.add_child(_dialog)
	_confirm = CONFIRM_SCENE.instantiate() as ConfirmDialog
	if _confirm != null:
		host.add_child(_confirm)
		_confirm.hide()


func _wire() -> void:
	if _panel != null:
		_panel.filters_changed.connect(_on_filters_changed)
		_panel.take_me_there.connect(_on_take_me_there)
	if _sort_pick != null:
		_sort_pick.option_selected.connect(set_sort)
	if _sort_dir != null:
		_sort_dir.direction_changed.connect(set_descending)
	if _dialog != null:
		_dialog.hire_requested.connect(_on_hire_requested)
		_dialog.counter_sent.connect(_on_counter_sent)
		_dialog.take_me_there.connect(_on_take_me_there)
	if _confirm != null:
		_confirm.confirmed.connect(_on_confirmed)
		_confirm.cancelled.connect(_on_confirm_cancelled)
	PromotionsManager.applicants_changed.connect(refresh)
	PromotionsManager.campaigns_changed.connect(_on_campaigns_changed)
	PromotionsManager.applicant_hired.connect(_on_applicant_hired)
	PromotionsManager.counter_resolved.connect(_on_counter_resolved)
	SubscriptionManager.changed.connect(_on_campaigns_changed)
	GameState.roster_changed.connect(refresh)
	GameState.money_changed.connect(_on_money_changed)
	visibility_changed.connect(_on_visibility_changed)


func _exit_tree() -> void:
	_drop_popup()
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
		_dialog = null
	if _confirm != null and is_instance_valid(_confirm):
		_confirm.queue_free()
		_confirm = null


#The filter a Plans hand-off asked for lands first, then the page redraws whether or not it was dirty.
#A fixed page leaves the hand-off for the Finance window.
func page_shown() -> void:
	var wanted: Dictionary = {} if is_fixed() else GameState.take_hire_filter()
	if not wanted.is_empty() and _panel != null:
		_panel.clear()
		for key: Variant in wanted.keys():
			_panel.set_value(String(key), wanted[key])
		_open_value_group()
	mark_dirty()


func refresh() -> void:
	mark_dirty()


func _refresh() -> void:
	super()
	if _panel == null or _grid == null:
		return
	_sync_sort_options()
	var via: Array[int] = []
	var picks: Dictionary = {}
	if is_fixed():
		via.append(fixed_campaign)
	else:
		picks = _panel.filters()
	var list: Array[ApplicantData] = PromotionsManager.applicants_filtered(picks, via, _sort, _desc)
	var defs: Array[Dictionary] = _panel.defs()
	var ents: Dictionary = SubscriptionManager.entitlements()
	var free: int = PromotionsManager.free_slots()
	_shown.clear()
	_clear_cards()
	for a: ApplicantData in list:
		_shown.append(a.id)
		var card: ApplicantCard = CARD_SCENE.instantiate() as ApplicantCard
		if card == null:
			continue
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_grid.add_child(card)
		card.set_applicant(a, defs, ents, free)
		card.view_pressed.connect(press_view)
		card.reject_pressed.connect(press_reject)
		card.offer_pressed.connect(press_offer)
		_cards[a.id] = card
	_count.text = count_text()
	_empty.text = empty_text()
	_empty.visible = list.is_empty()
	_grid.visible = not list.is_empty()


func _clear_cards() -> void:
	GuiNodes.clear(_grid)
	_cards.clear()


func _sync_sort_options() -> void:
	if _sort_pick == null:
		return
	var opts: Array[Dictionary] = []
	for row: Dictionary in PromotionsManager.SORTS:
		opts.append({"key": row.get("key", &""), "label": String(row.get("label", "")),
			"enabled": true})
	if _sort_pick.options.size() != opts.size():
		_sort_pick.set_options(opts)
	if _sort_pick.selected != _sort:
		_sort_pick.select(_sort, false)


func sort_key() -> StringName:
	return _sort


func set_sort(key: StringName) -> void:
	_sort = key
	if _sort_pick != null and _sort_pick.selected != key:
		_sort_pick.select(key, false)
	refresh()


func descending() -> bool:
	return _desc


func set_descending(flag: bool) -> void:
	_desc = flag
	if _sort_dir != null and _sort_dir.descending != flag:
		_sort_dir.descending = flag
	refresh()


func shown_count() -> int:
	return _shown.size()


func total_count() -> int:
	return PromotionsManager.applicants.size()


func count_text() -> String:
	if is_fixed():
		return COUNT_FIXED_FMT % shown_count()
	return COUNT_FMT % [shown_count(), total_count()]


func empty_text() -> String:
	if not _shown.is_empty():
		return ""
	if is_fixed():
		return EMPTY_FIXED
	return EMPTY_FILTERED if total_count() > 0 else EMPTY_NONE


func is_fixed() -> bool:
	return fixed_campaign != NO_FIXED


func title_text() -> String:
	if is_fixed():
		return TITLE_FIXED_FMT % PromotionsManager.campaign_name(fixed_campaign)
	return TITLE_TEXT


func card_ids() -> Array[int]:
	return _shown.duplicate()


func card_of(id: int) -> ApplicantCard:
	var card: ApplicantCard = _cards.get(id, null) as ApplicantCard
	if card == null or not is_instance_valid(card):
		return null
	return card


func press_view(id: int) -> void:
	var a: ApplicantData = PromotionsManager.applicant_of(id)
	if a == null:
		return
	PromotionsManager.mark_applicant_seen(id)
	_close_modals()
	_popup = ViewerPopup.show_applicant(modal_host(), a)
	if _popup != null:
		_popup.closed.connect(_on_popup_closed)


func press_reject(id: int) -> void:
	var a: ApplicantData = PromotionsManager.applicant_of(id)
	if a == null or a.status == ApplicantData.STATUS_COUNTERED:
		var card: ApplicantCard = card_of(id)
		UiSfx.reject_press(card.reject_button() if card != null else null)
		return
	var who: String = a.name
	PromotionsManager.mark_applicant_seen(id)
	_close_modals()
	if _confirm == null:
		return
	_pending = {"kind": KIND_REJECT, "id": id, "amount": 0}
	_confirm.ask(REJECT_TITLE % who, REJECT_BODY, REJECT_YES, CANCEL_TEXT,
		ConfirmDialog.Severity.ORANGE, ConfirmDialog.Kind.BAD)


func press_offer(id: int) -> void:
	var a: ApplicantData = PromotionsManager.applicant_of(id)
	if a == null:
		return
	var blocked: bool = a.status == ApplicantData.STATUS_COUNTERED
	if PromotionsManager.free_slots() <= 0:
		blocked = true
	PromotionsManager.mark_applicant_seen(id)
	if blocked:
		var card: ApplicantCard = card_of(id)
		UiSfx.reject_press(card.offer_button() if card != null else null)
		return
	if _dialog == null:
		return
	_close_modals()
	_dialog.open_for(a)


func press_clear() -> void:
	if _panel != null:
		_panel.press_clear()


func filter_panel() -> TraitFilterPanel:
	return _panel


func filter_column() -> PanelContainer:
	return _filter_column


func sort_dropdown() -> OptionDropdown:
	return _sort_pick


func sort_toggle() -> SortDirToggle:
	return _sort_dir


func card_grid() -> GridContainer:
	return _grid


func title_label() -> Label:
	return _title


func empty_label() -> Label:
	return _empty


func offer_dialog() -> HireOfferDialog:
	return _dialog


func confirm_dialog() -> ConfirmDialog:
	return _confirm


func applicant_popup() -> ViewerPopup:
	if _popup != null and is_instance_valid(_popup):
		return _popup
	return null


func notice() -> HiringNotice:
	return _notice


func _open_value_group() -> void:
	if _panel == null:
		return
	_panel.open_group(VALUE_GROUP)


func _reset_defs() -> void:
	if _panel == null:
		return
	var held: Dictionary = _panel.filters()
	_panel.set_defs(PromotionsManager.hiring_defs(), held, SubscriptionManager.entitlements())
	_open_value_group()


func _close_modals() -> void:
	_drop_popup()
	if _dialog != null and _dialog.is_open():
		_dialog.close()
	if _confirm != null and _confirm.visible:
		_confirm.hide()
		_pending = {}


func _drop_popup() -> void:
	if _popup == null:
		return
	if is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null


#A red flash reports a refusal, so it carries the reject cue; a refused press passes its button so its click drops.
func _flash(body: String, tint: Color, pressed: Control = null) -> void:
	if _notice == null or not is_visible_in_tree():
		return
	if tint == GuiColors.RAMP_RED:
		if pressed != null:
			UiSfx.reject_press(pressed)
		else:
			GameSfx.play_reject()
	_notice.flash(body, tint)


func _on_popup_closed() -> void:
	_popup = null


func _on_filters_changed(_filters: Dictionary) -> void:
	refresh()


func _on_take_me_there(target: Dictionary) -> void:
	if _dialog != null and _dialog.is_open():
		_dialog.close()
	GameState.go_to_plans(target)


func _on_campaigns_changed() -> void:
	_reset_defs()
	refresh()


func _on_money_changed(_notes: int) -> void:
	refresh()


func _on_hire_requested(id: int, salary: int) -> void:
	var a: ApplicantData = PromotionsManager.applicant_of(id)
	if a == null or _confirm == null:
		return
	var who: String = a.name
	if _dialog != null:
		_dialog.close()
	_pending = {"kind": KIND_HIRE, "id": id, "amount": salary}
	_confirm.ask(HIRE_TITLE % who, HIRE_BODY % TransactionData.grouped(salary), HIRE_YES,
		CANCEL_TEXT, ConfirmDialog.Severity.ORANGE, ConfirmDialog.Kind.GO)


func _on_counter_sent(id: int, offer: int) -> void:
	if _dialog == null:
		return
	var crew: Array[int] = _dialog.team()
	var per: int = _dialog.pay_per()
	_dialog.close()
	if PromotionsManager.counter(id, offer, crew, per):
		return
	var verdict: Dictionary = PromotionsManager.can_counter(id, offer, crew, per)
	_flash(String(verdict.get("reason", "")), GuiColors.RAMP_RED, _dialog.action_button())


func _on_confirm_cancelled() -> void:
	_pending = {}


func _on_confirmed() -> void:
	var kind: String = String(_pending.get("kind", ""))
	var id: int = int(_pending.get("id", 0))
	var amount: int = int(_pending.get("amount", 0))
	_pending = {}
	if kind == KIND_REJECT:
		PromotionsManager.reject(id)
		GameSfx.play_reject()
		return
	if kind != KIND_HIRE:
		return
	if PromotionsManager.hire(id, amount):
		return
	var verdict: Dictionary = PromotionsManager.can_hire(id, amount)
	_flash(String(verdict.get("reason", "")), GuiColors.RAMP_RED, _confirm.confirm_button)


func _on_applicant_hired(a: ApplicantData, _salary: int, _delta: int) -> void:
	if a == null:
		return
	_flash(NOTICE_HIRED % a.name, GuiColors.GREEN)


func _on_counter_resolved(id: int, accepted: bool) -> void:
	var a: ApplicantData = PromotionsManager.applicant_of(id)
	if a == null:
		return
	if accepted:
		_flash(NOTICE_ACCEPTED % a.name, GuiColors.GREEN)
		return
	_flash(NOTICE_REFUSED % a.name, GuiColors.RAMP_RED)
