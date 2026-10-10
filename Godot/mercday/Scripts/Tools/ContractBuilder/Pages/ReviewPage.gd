@tool
class_name ReviewPage extends BuilderPage

#What Confirm writes: a new or a replaced row, every set cell as "Header: value" in Contracts.tsv order, the
#description lines and the pending checks, then the follow-ups a new type or a new organization leaves in other sheets.

const EMPTY_TEXT: String = "No field is set yet."
const WRITE_NEW: String = "Write: new row"
const WRITE_REPLACE: String = "Write: replace row %s"
const RENAME: String = "Rename: %s to %s"
const FOLLOW_UPS: String = "Follow-ups:"
const TYPE_FOLLOW_UPS: Array[String] = ["Stats.tsv derived stat for %s", "Events.tsv event pool for %s"]
const ORG_FOLLOW_UP: String = "New organization %s: fill Type and Home in Organizations.tsv"
const NEW_CHECK: String = "New check: %s"

var _fields: Label = null


func _init() -> void:
	page_title = "Review"
	summary = "The full row as a recap. Confirm writes the row and rebuilds the contract resources."


func _build() -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_fields = Label.new()
	_fields.name = "Fields"
	_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fields.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fields.text = EMPTY_TEXT
	scroll.add_child(_fields)


func load_draft(draft: ContractDraft) -> void:
	_fields.text = review_text(draft)


#The write line (ContractRowWriter.replaces decides), a Rename line when a loaded row changes its name, a blank
#line, the cells, the description lines and each pending check's lines (Style check, then the timeline rows), then
#the follow-ups after a blank line.
static func review_text(draft: ContractDraft) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var title: String = draft.contract_name.strip_edges()
	if ContractRowWriter.replaces(draft):
		lines.append(WRITE_REPLACE % draft.source_name)
		if title != draft.source_name:
			lines.append(RENAME % [draft.source_name, title])
	else:
		lines.append(WRITE_NEW)
	lines.append("")
	var shown: int = lines.size()
	var header: Array[String] = ContractBuilderData.header()
	var cells: Array[String] = draft.row_cells(header)
	for i: int in range(header.size()):
		if cells[i] != "":
			lines.append("%s: %s" % [header[i], cells[i]])
	for line: String in draft.descriptions:
		lines.append("Description: %s" % line)
	if ContractRowWriter.pending_check(draft):
		lines.append_array(_check_lines(draft.check_row))
	for row: Variant in ContractRowWriter.pending_timeline_checks(draft):
		var timeline_row: Array[String] = []
		timeline_row.assign(row)
		lines.append_array(_check_lines(timeline_row))
	if lines.size() == shown:
		lines.append(EMPTY_TEXT)
	var follow_ups: PackedStringArray = PackedStringArray()
	if ContractRowWriter.adds_type(draft):
		for text: String in TYPE_FOLLOW_UPS:
			follow_ups.append(text % draft.contract_type.strip_edges())
	if ContractRowWriter.adds_org(draft):
		follow_ups.append(ORG_FOLLOW_UP % draft.issuer.strip_edges())
	if not follow_ups.is_empty():
		lines.append("")
		lines.append(FOLLOW_UPS)
		lines.append_array(follow_ups)
	return "\n".join(lines)


#The NEW_CHECK line and the row's CheckSheet.summary lines indented by two spaces.
static func _check_lines(row: Array[String]) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray([NEW_CHECK % row[CheckSheet.NAME].strip_edges()])
	for line: String in CheckSheet.summary(row).split("\n", false):
		out.append("  " + line)
	return out
