@tool
class_name ContractBuilder extends Control

#The Contract Builder shell: six pages walked only with Previous and Next, one ContractDraft, and an
#autosave of that draft. Confirm writes the row (ContractRowWriter), rebuilds the contract resources
#(ContractRebuild), clears the draft and shows page 1.

const DRAFT_PATH: String = "user://contract_builder_draft.json"
const PAGE_KEYS: Array[StringName] = [&"overview", &"location", &"target", &"completion",
	&"description", &"review"]
const STATUS_SAVED: String = "Draft saved"
const STATUS_RESTORED: String = "Draft restored"
const STATUS_CLEARED: String = "Cleared"
const STATUS_WROTE: String = "Wrote %s"
const STATUS_REPLACED: String = "Replaced %s"
const STATUS_REBUILD_SKIPPED: String = "rebuild skipped"
const BUTTON_SCENE: PackedScene = preload("res://Scenes/Tools/Shared/ToolBevelButton.tscn")
const BUTTON_SIZE: Vector2 = Vector2(120, 36)

#The plugin sets this before the scene enters the tree. Inside the editor an unhosted copy is the scene
#open for editing, so it builds no pages and leaves the draft file alone.
var hosted: bool = false
#Tests turn this off so Confirm skips the child Godot that rebuilds the contract resources.
var rebuild_on_confirm: bool = true
var draft: ContractDraft = ContractDraft.new()
var pages: Array[BuilderPage] = []
var index: int = 0

var _previous: BevelButton = null
var _next: BevelButton = null
var _confirm: BevelButton = null

@onready var _page_count: Label = get_node("Margin/Column/TitleRow/PageCount") as Label
@onready var _tabs: TabStrip = get_node("Margin/Column/Tabs") as TabStrip
@onready var _host: Container = get_node("Margin/Column/PageHost") as Container
@onready var _bar: HBoxContainer = get_node("Margin/Column/BottomBar") as HBoxContainer
@onready var _status: Label = get_node("Margin/Column/BottomBar/Status") as Label


func _ready() -> void:
	if Engine.is_editor_hint() and not hosted:
		return
	_build_buttons()
	_build_pages()
	restore_draft()
	show_page(draft.page, false)


#The buttons are made here because the scene editor runs a tool button's code: a save from it would
#write the runtime overrides and palette colours of the buttons into ContractBuilder.tscn.
func _build_buttons() -> void:
	_previous = _make_button("Previous", &"neutral", 0)
	_next = _make_button("Next", &"blue", 2)
	_confirm = _make_button("Confirm", &"go", 3)
	_previous.pressed.connect(go_previous)
	_next.pressed.connect(go_next)
	_confirm.pressed.connect(confirm)


func _make_button(label: String, look: StringName, at: int) -> BevelButton:
	var button: BevelButton = BUTTON_SCENE.instantiate() as BevelButton
	button.name = label
	button.text = label
	button.kind = look
	button.min_size = BUTTON_SIZE
	_bar.add_child(button)
	_bar.move_child(button, at)
	return button


func _build_pages() -> void:
	var made: Array[BuilderPage] = [OverviewPage.new(), LocationPage.new(), TargetPage.new(),
		CompletionPage.new(), DescriptionPage.new(), ReviewPage.new()]
	for i: int in range(made.size()):
		var page: BuilderPage = made[i]
		page.name = String(PAGE_KEYS[i]).capitalize()
		page.visible = false
		page.changed.connect(_on_page_changed)
		_host.add_child(page)
		pages.append(page)


func show_page(i: int, autosave: bool = true) -> void:
	if pages.is_empty():
		return
	index = clampi(i, 0, pages.size() - 1)
	draft.page = index
	for p: int in range(pages.size()):
		pages[p].visible = p == index
	pages[index].load_draft(draft)
	var key: StringName = PAGE_KEYS[index]
	_tabs.set_active(key)
	for other: StringName in PAGE_KEYS:
		_tabs.set_locked(other, other != key)
	_page_count.text = "Page %d of %d" % [index + 1, pages.size()]
	_refresh_nav()
	if autosave:
		save_draft()


func go_next() -> void:
	if pages.is_empty() or index >= pages.size() - 1 or not pages[index].is_complete():
		return
	pages[index].store_draft(draft)
	show_page(index + 1)


func go_previous() -> void:
	if pages.is_empty() or index <= 0:
		return
	pages[index].store_draft(draft)
	show_page(index - 1)


#Saved before the write, so a refused or failed write leaves the draft on disk and in the pages.
func confirm() -> void:
	if pages.is_empty() or index != pages.size() - 1 or not pages[index].is_complete():
		return
	pages[index].store_draft(draft)
	save_draft()
	var written: Dictionary = ContractRowWriter.write(draft)
	if not bool(written["ok"]):
		_set_status(String(written["error"]))
		return
	var done: String = STATUS_WROTE % String(written["name"])
	if bool(written["replaced"]):
		done = STATUS_REPLACED % draft.source_name
	var rebuild: String = STATUS_REBUILD_SKIPPED
	if rebuild_on_confirm:
		rebuild = ContractRebuild.summary_text(ContractRebuild.run())
	clear_draft()
	show_page(0, false)
	_set_status("%s; %s" % [done, rebuild])


func clear_draft() -> void:
	draft.clear()
	if FileAccess.file_exists(DRAFT_PATH):
		var err: Error = DirAccess.remove_absolute(DRAFT_PATH)
		if err != OK:
			push_warning("Contract Builder: cannot delete %s (%s)" % [DRAFT_PATH, error_string(err)])
	for page: BuilderPage in pages:
		page.load_draft(draft)


func save_draft() -> bool:
	draft.page = index
	var file: FileAccess = FileAccess.open(DRAFT_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Contract Builder: cannot write %s (%s)"
			% [DRAFT_PATH, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(draft.to_dict(), "\t"))
	file.close()
	_set_status(STATUS_SAVED)
	return true


func restore_draft() -> bool:
	if not FileAccess.file_exists(DRAFT_PATH):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DRAFT_PATH))
	if not (parsed is Dictionary):
		push_warning("Contract Builder: %s holds no draft" % DRAFT_PATH)
		return false
	draft.from_dict(parsed as Dictionary)
	for page: BuilderPage in pages:
		page.load_draft(draft)
	_set_status(STATUS_RESTORED)
	return true


func _on_page_changed() -> void:
	if pages.is_empty():
		return
	pages[index].store_draft(draft)
	_refresh_nav()
	save_draft()


func _refresh_nav() -> void:
	var last: bool = index == pages.size() - 1
	var complete: bool = pages[index].is_complete()
	_previous.visible = index > 0
	_next.visible = not last
	_next.disabled = not complete
	_confirm.visible = last
	_confirm.disabled = not complete


func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text
