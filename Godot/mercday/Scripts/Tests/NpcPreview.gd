@tool
class_name NpcPreview

#Review atlases: the idle frame of seeds 1..N rolled by CharacterAppearance, each cell labelled with its seed,
#and a sheet of random gear icons. Run: godot --headless --path . -- --npc-preview --preview-n=100

const DEFAULT_COUNT: int = 100
const LOG_DIR: String = "res://_logs"
const NPC_NAME: String = "npc_preview"
const GEAR_NAME: String = "gear_preview"
const COLUMNS: int = 10
const SCALE: int = 2
const GAP: int = 4
const GEAR_SEED: int = 1
const BACK: Vector3i = Vector3i(40, 40, 48)
const INK: Vector3i = Vector3i(235, 235, 235)
const GLYPH_PIXEL: int = 2
const LABEL_INSET: int = 2
#3x5 digit glyphs 0-9, rows top to bottom, "1" = ink.
const DIGITS: Array[String] = ["111101101101111", "010110010010111", "111001111100111", "111001111001111",
	"101101111001001", "111100111001111", "111100111101111", "111001001001001", "111101111101111",
	"111101111001111"]


#Harness entry for --npc-preview: writes both atlases into _logs and prints where the NPC one landed.
static func run(count: int) -> bool:
	var n: int = count if count > 0 else DEFAULT_COUNT
	var npc: Dictionary = write(n, LOG_DIR)
	var gear: Dictionary = write_gear(n, LOG_DIR)
	print("NPC PREVIEW n=%d path=%s" % [n, ProjectSettings.globalize_path(String(npc["path"]))])
	print("GEAR PREVIEW n=%d path=%s" % [int(gear["count"]), ProjectSettings.globalize_path(String(gear["path"]))])
	for line: Variant in (npc["errors"] as Array) + (gear["errors"] as Array):
		print("NPC PREVIEW: %s" % line)
	return bool(npc["ok"]) and bool(gear["ok"])


#Bakes the idle frame of seeds 1..count into <dir>/npc_preview.png and lists seed -> appearance in the json twin.
static func write(count: int, dir: String) -> Dictionary:
	var n: int = maxi(1, count)
	var errors: Array[String] = []
	var cells: Array[Image] = []
	var labels: Array[int] = []
	var listing: Dictionary = {}
	for seed_i: int in range(1, n + 1):
		var app: CharacterAppearance = CharacterAppearance.roll(seed_i)
		if app.is_empty():
			errors.append("seed %d rolled no parts" % seed_i)
		else:
			listing[str(seed_i)] = app.to_dict()
		cells.append(CharacterBaker.bake_frame(app, 0, 0))
		labels.append(seed_i)
	var path: String = "%s/%s.png" % [dir, NPC_NAME]
	var json_path: String = "%s/%s.json" % [dir, NPC_NAME]
	var sheet: Image = _sheet(cells, Vector2i(CharacterBaker.FRAME_SIZE, CharacterBaker.FRAME_SIZE) * SCALE, labels)
	_save(sheet, path, errors)
	var file: FileAccess = FileAccess.open(json_path, FileAccess.WRITE)
	if file == null:
		errors.append("cannot write %s" % json_path)
	else:
		file.store_string(JSON.stringify(listing, "\t"))
		file.close()
	return {"ok": errors.is_empty(), "path": path, "json": json_path, "count": n, "errors": errors}


#Writes count random gear icons at 2x into <dir>/gear_preview.png, drawn from one fixed rng seed.
static func write_gear(count: int, dir: String) -> Dictionary:
	var n: int = maxi(1, count)
	var errors: Array[String] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = GEAR_SEED
	var cells: Array[Image] = []
	var cell := Vector2i.ONE
	for i: int in range(n):
		var icon: Dictionary = GearIconBaker.random_icon(rng)
		var img: Image = icon.get("image") as Image
		if img == null:
			errors.append("gear %d gave no image" % (i + 1))
			continue
		cells.append(img)
		cell = cell.max(img.get_size() * SCALE)
	var path: String = "%s/%s.png" % [dir, GEAR_NAME]
	_save(_sheet(cells, cell, []), path, errors)
	return {"ok": errors.is_empty(), "path": path, "count": cells.size(), "errors": errors}


#Lays the cells out COLUMNS wide at SCALE with GAP between and around them; labels[i] is drawn on cell i.
static func _sheet(cells: Array[Image], cell: Vector2i, labels: Array[int]) -> Image:
	var cols: int = clampi(cells.size(), 1, COLUMNS)
	var rows: int = maxi(1, ceili(cells.size() / float(cols)))
	var size := Vector2i(cols * cell.x + (cols + 1) * GAP, rows * cell.y + (rows + 1) * GAP)
	var out: Image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	out.fill(Color8(BACK.x, BACK.y, BACK.z))
	for i: int in range(cells.size()):
		var src: Image = cells[i].duplicate() as Image
		if src.get_format() != Image.FORMAT_RGBA8:
			src.convert(Image.FORMAT_RGBA8)
		src.resize(src.get_width() * SCALE, src.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
		var origin := Vector2i(GAP + (i % cols) * (cell.x + GAP), GAP + floori(i / float(cols)) * (cell.y + GAP))
		var spare: Vector2i = cell - src.get_size()
		var at: Vector2i = origin + Vector2i(floori(spare.x / 2.0), floori(spare.y / 2.0))
		out.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), at)
		if i < labels.size():
			draw_number(out, labels[i], origin + Vector2i(LABEL_INSET, LABEL_INSET))
	return out


#Draws value in 3x5 glyphs scaled by GLYPH_PIXEL on a background box with its top-left corner at at.
static func draw_number(img: Image, value: int, at: Vector2i) -> void:
	var text: String = str(absi(value))
	var step: int = 4 * GLYPH_PIXEL
	var box := Rect2i(at - Vector2i.ONE * GLYPH_PIXEL,
		Vector2i(text.length() * step + GLYPH_PIXEL, 7 * GLYPH_PIXEL))
	img.fill_rect(box.intersection(Rect2i(Vector2i.ZERO, img.get_size())), Color8(BACK.x, BACK.y, BACK.z))
	var ink: Color = Color8(INK.x, INK.y, INK.z)
	for d: int in range(text.length()):
		var glyph: String = DIGITS[text.unicode_at(d) - 48]
		for bit: int in range(15):
			if glyph[bit] != "1":
				continue
			var px := Vector2i(at.x + d * step + (bit % 3) * GLYPH_PIXEL, at.y + floori(bit / 3.0) * GLYPH_PIXEL)
			img.fill_rect(Rect2i(px, Vector2i.ONE * GLYPH_PIXEL), ink)


#Saves img as a PNG with a keep import twin so the editor never turns it into a texture.
static func _save(img: Image, path: String, errors: Array[String]) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	CharacterPartsBuilder.save_png(img, path, errors)
