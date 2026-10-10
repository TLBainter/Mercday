class_name TsvReader


static func load_tsv(path: String) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("TsvReader: cannot open %s" % path)
		return rows
	var source: String = path.get_file()
	AsciiNormalizer.reset_count()
	var row_index: int = 0
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line("\t")
		for c: int in range(row.size()):
			row[c] = AsciiNormalizer.normalize(row[c], source, row_index)
		rows.append(row)
		row_index += 1
	file.close()
	AsciiNormalizer.report_file(source)
	return rows


#Reads a TSV into one dictionary per data row, keyed by the header cell text.
static func load_header_rows(path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rows: Array[PackedStringArray] = load_tsv(path)
	if rows.size() < 2:
		return out
	var header: Array[String] = []
	for c: int in range(rows[0].size()):
		header.append(row_get(rows[0], c))
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		if row_get(row, 0) == "":
			continue
		var d: Dictionary = {}
		for c: int in range(header.size()):
			if header[c] == "":
				continue
			if d.has(header[c]):
				push_warning("TsvReader: %s duplicate column %s" % [path.get_file(), header[c]])
				continue
			d[header[c]] = row_get(row, c)
		d["_row"] = i + 1
		out.append(d)
	return out


static func split_field(value: String, sep: String = ",") -> Array[String]:
	var result: Array[String] = []
	if value.strip_edges() == "":
		return result
	for part: String in value.split(sep):
		var t: String = part.strip_edges()
		if t != "":
			result.append(t)
	return result


static func row_get(row: PackedStringArray, idx: int) -> String:
	return row[idx].strip_edges() if idx < row.size() else ""


#Typed cell reads: a blank or unparsable cell falls back to the default.
static func cell_int(row: PackedStringArray, idx: int, default_value: int) -> int:
	var raw: String = row_get(row, idx)
	return int(raw) if raw.is_valid_int() else default_value


static func cell_float(row: PackedStringArray, idx: int, default_value: float) -> float:
	var raw: String = row_get(row, idx)
	return float(raw) if raw.is_valid_float() else default_value


static func cell_bool(row: PackedStringArray, idx: int) -> bool:
	return row_get(row, idx).to_upper() == "TRUE"


#Data rows of a sheet: the header is dropped and rows with a blank key cell are skipped.
static func data_rows(path: String, key_col: int) -> Array[PackedStringArray]:
	var out: Array[PackedStringArray] = []
	var rows: Array[PackedStringArray] = load_tsv(path)
	for i: int in range(1, rows.size()):
		if row_get(rows[i], key_col) == "":
			continue
		out.append(rows[i])
	return out


#Splits an "intended/extended" range cell; the extended value falls back to the intended one.
static func parse_range(text: String) -> Array[int]:
	var parts: PackedStringArray = text.split("/")
	var intended: int = int(parts[0]) if parts.size() > 0 else 0
	var extended: int = int(parts[1]) if parts.size() > 1 else intended
	var out: Array[int] = [intended, extended]
	return out
