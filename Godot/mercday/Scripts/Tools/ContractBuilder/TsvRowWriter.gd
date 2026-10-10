@tool
class_name TsvRowWriter extends RefCounted

#Writes one row, the rows under a set of keys, or one cell of a column into a TSV sheet in place. The file keeps its
#line ending (LF or CRLF) and every line the call leaves alone, and never gains a trailing newline. Cells are written
#raw: get_csv_line reads a double quote specially, so no cell may hold one. Every check runs first; a refused call
#writes nothing.

const TAB: String = "\t"
const CRLF: String = "\r\n"
const LF: String = "\n"


#{"ok", "error", "eol", "lines", "width"}: lines lack the trailing newline; width is the header's cell count.
static func read_table(path: String) -> Dictionary:
	var out: Dictionary = {"ok": false, "error": "", "eol": LF, "lines": PackedStringArray(), "width": 0}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		out["error"] = "cannot read %s: %s" % [path, error_string(FileAccess.get_open_error())]
		return out
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	var text: String = bytes.get_string_from_utf8()
	#A byte order mark or a bad UTF-8 byte would not survive the rewrite, so such a file is refused.
	if text.to_utf8_buffer() != bytes:
		out["error"] = "%s is not plain UTF-8 text" % path
		return out
	var eol: String = CRLF if text.contains(CRLF) else LF
	var bare: String = text.replace(CRLF, "")
	if bare.contains("\r"):
		out["error"] = "%s holds a CR outside a CRLF line ending" % path
		return out
	if eol == CRLF and bare.contains(LF):
		out["error"] = "%s mixes CRLF and LF line endings" % path
		return out
	if text.ends_with(eol):
		text = text.left(text.length() - eol.length())
	if text == "":
		out["error"] = "%s has no header line" % path
		return out
	var lines: PackedStringArray = text.split(eol)
	out["ok"] = true
	out["eol"] = eol
	out["lines"] = lines
	out["width"] = lines[0].split(TAB).size()
	return out


#"" when the cells fit a row of width cells, else the first reason; cells count from 0.
static func check_cells(cells: Array[String], width: int) -> String:
	if cells.size() != width:
		return "expected %d cells, got %d" % [width, cells.size()]
	for i: int in range(cells.size()):
		var bad: String = _bad_character(cells[i])
		if bad != "":
			return "cell %d holds %s" % [i, bad]
	return ""


#{"ok", "error", "line"}: line is the 0-based index of the written line, -1 on a refusal.
static func append_row(path: String, cells: Array[String]) -> Dictionary:
	var table: Dictionary = read_table(path)
	if not bool(table["ok"]):
		return _result(false, String(table["error"]), -1)
	var reason: String = check_cells(cells, int(table["width"]))
	if reason != "":
		return _result(false, reason, -1)
	var lines: PackedStringArray = table["lines"]
	lines.append(TAB.join(PackedStringArray(cells)))
	return _write(path, String(table["eol"]), lines, lines.size() - 1)


#The first data line whose key_column cell, read as TsvReader reads it (ASCII-mapped, trimmed), equals key, else -1;
#an empty key or an unreadable file gives -1.
static func find_row(path: String, key_column: int, key: String) -> int:
	var table: Dictionary = read_table(path)
	if not bool(table["ok"]):
		return -1
	return _find(table["lines"], key_column, key, path.get_file())


static func replace_row(path: String, key_column: int, key: String, cells: Array[String]) -> Dictionary:
	var table: Dictionary = read_table(path)
	if not bool(table["ok"]):
		return _result(false, String(table["error"]), -1)
	var reason: String = check_cells(cells, int(table["width"]))
	if reason != "":
		return _result(false, reason, -1)
	var lines: PackedStringArray = table["lines"]
	var line: int = _find(lines, key_column, key, path.get_file())
	if line < 0:
		return _result(false, "no row whose column %d is %s" % [key_column, key], -1)
	lines[line] = TAB.join(PackedStringArray(cells))
	return _write(path, String(table["eol"]), lines, line)


#Mirror rule: removes every data line whose key cell is one of keys; rows go in at the first removed line, else at the end.
static func replace_rows(path: String, key_column: int, keys: Array[String],
		rows: Array[PackedStringArray]) -> Dictionary:
	var table: Dictionary = read_table(path)
	if not bool(table["ok"]):
		return _rows_result(_result(false, String(table["error"]), -1), 0)
	var added: PackedStringArray = PackedStringArray()
	for r: int in range(rows.size()):
		var cells: Array[String] = []
		for value: String in rows[r]:
			cells.append(value)
		var reason: String = check_cells(cells, int(table["width"]))
		if reason != "":
			return _rows_result(_result(false, "row %d: %s" % [r, reason], -1), 0)
		added.append(TAB.join(rows[r]))
	var wanted: Array[String] = []
	for key: String in keys:
		if key.strip_edges() != "":
			wanted.append(key.strip_edges())
	var lines: PackedStringArray = table["lines"]
	var kept: PackedStringArray = PackedStringArray([lines[0]])
	var slot: int = -1
	for i: int in range(1, lines.size()):
		if not _key_matches(_cell(lines[i], key_column), wanted, path, i):
			kept.append(lines[i])
		elif slot < 0:
			slot = kept.size()
	var removed: int = lines.size() - kept.size()
	if removed == 0 and added.is_empty():
		return _rows_result(_result(true, "", -1), 0)
	if slot < 0:
		slot = kept.size()
	var out: PackedStringArray = kept.slice(0, slot)
	out.append_array(added)
	out.append_array(kept.slice(slot))
	var written: Dictionary = _write(path, String(table["eol"]), out, slot if not added.is_empty() else -1)
	return _rows_result(written, removed if bool(written["ok"]) else 0)


#Puts the trimmed value in the first blank cell under column_title, padding a short line to width; with no blank
#cell a new line of width blank cells carries it. The character check reads the untrimmed value.
static func set_column_cell(path: String, column_title: String, value: String) -> Dictionary:
	var table: Dictionary = read_table(path)
	if not bool(table["ok"]):
		return _result(false, String(table["error"]), -1)
	var text: String = value.strip_edges()
	if text == "":
		return _result(false, "empty value", -1)
	var bad: String = _bad_character(value)
	if bad != "":
		return _result(false, "value holds %s" % bad, -1)
	var lines: PackedStringArray = table["lines"]
	var column: int = _title_column(lines[0], column_title)
	if column < 0:
		return _result(false, "no column %s in %s" % [column_title, path.get_file()], -1)
	var target: int = -1
	for i: int in range(1, lines.size()):
		var cell: String = _cell(lines[i], column)
		if cell == text:
			return _result(false, "%s is already in column %s" % [text, column_title], -1)
		if cell == "" and target < 0:
			target = i
	var cells: PackedStringArray = PackedStringArray()
	if target < 0:
		target = lines.size()
		lines.append("")
	else:
		cells = lines[target].split(TAB)
	while cells.size() < int(table["width"]):
		cells.append("")
	cells[column] = text
	lines[target] = TAB.join(cells)
	return _write(path, String(table["eol"]), lines, target)


static func _find(lines: PackedStringArray, key_column: int, key: String, source: String) -> int:
	if key == "":
		return -1
	var keys: Array[String] = [key]
	for i: int in range(1, lines.size()):
		if _key_matches(_cell(lines[i], key_column), keys, source, i):
			return i
	return -1


#The cell read as TsvReader reads it (ASCII-mapped, trimmed) equals one of keys; path names the sheet in warnings.
static func _key_matches(cell: String, keys: Array[String], path: String, line: int) -> bool:
	return keys.has(AsciiNormalizer.normalize(cell, path.get_file(), line).strip_edges())


static func _cell(line: String, column: int) -> String:
	var cells: PackedStringArray = line.split(TAB)
	return cells[column].strip_edges() if column >= 0 and column < cells.size() else ""


static func _title_column(header_line: String, title: String) -> int:
	if title.strip_edges() == "":
		return -1
	var cells: PackedStringArray = header_line.split(TAB)
	for c: int in range(cells.size()):
		if cells[c].strip_edges() == title:
			return c
	return -1


static func _bad_character(text: String) -> String:
	for i: int in range(text.length()):
		var code: int = text.unicode_at(i)
		match code:
			9:
				return "a tab"
			34:
				return "a double quote"
			13:
				return "a CR"
			10:
				return "an LF"
		if code < 32 or code > 126:
			return "a character outside ASCII 32 to 126"
	return ""


static func _write(path: String, eol: String, lines: PackedStringArray, line: int) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _result(false, "cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())], -1)
	var stored: bool = file.store_string(eol.join(lines))
	file.close()
	if not stored:
		return _result(false, "writing %s failed; the file may be cut short" % path, -1)
	return _result(true, "", line)


static func _result(ok: bool, error: String, line: int) -> Dictionary:
	return {"ok": ok, "error": error, "line": line}


static func _rows_result(result: Dictionary, removed: int) -> Dictionary:
	result["removed"] = removed
	return result
