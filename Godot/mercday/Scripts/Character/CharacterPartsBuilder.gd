@tool
class_name CharacterPartsBuilder extends RefCounted

#Builds the parts library from the RPG Maker SV generator folders: one sheet per part (base at x 0,
#mask twin at x 576), deduped gradient palettes, parts_index.json, keep import twins, and a copy of the
#item icon atlases with their index.

const CELL: Vector2i = Vector2i(576, 384)
const SOURCE_DIR: String = "U:/Game Design/MyProjects/MercManager/Art/RPG Maker/Character"
const ITEMS_DIR: String = "U:/Game Design/MyProjects/MercManager/Art/RPG Maker Atlases/Items"
const ITEMS_INDEX: String = "U:/Game Design/MyProjects/MercManager/Art/RPG Maker Atlases/atlas_index_items.json"
const KEEP_IMPORT: String = "[remap]\n\nimporter=\"keep\"\n"
const NAME_PATTERN: String = "^([A-Za-z0-9]+)_([FMKU])_SV_(.+)_p(\\d+)$"
const SLOTS: Array[String] = ["body", "ears", "beast_ears", "tail", "wings", "facial_mark", "hair_front",
	"hair_back", "beard", "clothing1", "clothing2", "cloak1", "cloak2", "hat", "headband", "mask", "glasses",
	"neck", "accessory"]
const SLOT_FOLDERS: Dictionary = {
	"body": "Body/Body", "ears": "Body/Ears", "beast_ears": "Body/Beast Ears", "tail": "Body/Tail",
	"wings": "Body/Wings", "facial_mark": "Body/Facial Mark", "hair_front": "Hair/Hair Front",
	"hair_back": "Hair/Hair Back", "beard": "Hair/Beard", "clothing1": "Clothing/Clothing 1",
	"clothing2": "Clothing/Clothing 2", "cloak1": "Clothing/Cloak 1", "cloak2": "Clothing/Cloak 2",
	"hat": "Clothing/Hat", "headband": "Clothing/Headband and Horns", "mask": "Clothing/Mask",
	"glasses": "Clothing/Glasses", "neck": "Clothing/Neck", "accessory": "Clothing/Other Accessory",
}
const KEY_GROUPS: Dictionary = {
	"249,193,157": "skin", "44,128,203": "eyes", "252,203,10": "hair", "79,65,60": "hair",
	"100,87,82": "hair", "184,146,197": "hair", "211,206,199": "hair", "230,214,189": "hair",
	"250,249,249": "hair",
}
const PALETTE_SOURCES: Dictionary = {
	"skin": ["HC9_grad_skin.png"], "hair": ["MZ_grad_hair.png"], "eyes": ["MZ_grad_eyes.png"],
	"common": ["MZ_grad_common.png", "MZ_gradients.png"],
}
const NEAR_WHITE: int = 247
const WHITE_PX: int = -1
const WHITE_RGB: int = 0xFFFFFF
#RGB distance within which a leftover mask key folds into the part's nearest real key.
const STRAY_FOLD: int = 64


static func build(source_dir: String, items_dir: String, items_index: String,
		out_dir: String = "res://Art/Character/Parts", items_out: String = "res://Art/Items/Atlases") -> Dictionary:
	var started: int = Time.get_ticks_msec()
	var errors: Array[String] = []
	var out_abs: String = ProjectSettings.globalize_path(out_dir)
	var counts: Dictionary = {}
	var parts: Array[Dictionary] = []
	var masked: int = 0
	var name_re: RegEx = RegEx.create_from_string(NAME_PATTERN)
	for slot: String in SLOTS:
		var dir_path: String = source_dir.path_join(SLOT_FOLDERS[slot])
		var slot_abs: String = out_abs.path_join(slot)
		DirAccess.make_dir_recursive_absolute(slot_abs)
		var tally: Dictionary = {}
		var files: PackedStringArray = DirAccess.get_files_at(dir_path)
		files.sort()
		for f: String in files:
			var stem: String = f.get_basename()
			if f.get_extension().to_lower() != "png" or f.contains("(1)") or stem.ends_with("_c"):
				continue
			var m: RegExMatch = name_re.search(stem)
			if m == null:
				errors.append("bad name %s/%s" % [slot, f])
				continue
			var base: Image = _load_rgba(dir_path.path_join(f))
			if base == null:
				errors.append("bad base %s/%s" % [slot, f])
				continue
			var mask: Image = null
			var mask_path: String = dir_path.path_join(stem + "_c.png")
			if FileAccess.file_exists(mask_path):
				mask = _load_rgba(mask_path)
				if mask == null:
					errors.append("bad mask %s/%s" % [slot, stem + "_c.png"])
			var regions: Array = []
			var sheet: Image = Image.create_empty(CELL.x * 2, CELL.y, false, Image.FORMAT_RGBA8)
			sheet.blit_rect(base, Rect2i(Vector2i.ZERO, CELL), Vector2i.ZERO)
			if mask != null:
				mask = _fold_strays(base, _clean_mask(mask))
				regions = _regions(base, mask)
				sheet.blit_rect(mask, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x, 0))
				masked += 1
			var rel: String = slot.path_join(stem + ".png")
			if not save_png(sheet, out_abs.path_join(rel), errors):
				continue
			var gender: String = m.get_string(2)
			parts.append({"id": stem, "slot": slot, "pack": m.get_string(1), "gender": gender, "file": rel,
				"has_mask": mask != null, "regions": regions})
			tally[gender] = int(tally.get(gender, 0)) + 1
		counts[slot] = tally
	var palettes: Dictionary = _write_palettes(source_dir.path_join("Palettes"), out_abs, errors)
	_write_index(out_abs, parts, palettes, errors)
	var items: int = _copy_items(items_dir, items_index, ProjectSettings.globalize_path(items_out), errors)
	return {"ok": errors.is_empty(), "parts": parts.size(), "masked": masked, "counts": counts,
		"palettes": palettes, "items": items, "errors": errors,
		"seconds": float(Time.get_ticks_msec() - started) / 1000.0}


#Rows of a gradient sheet, each 256 wide; drops a row equal to the last kept one and near-white separators.
static func gradient_rows(img: Image) -> Array[PackedColorArray]:
	var src: Image = img.duplicate() as Image
	src.convert(Image.FORMAT_RGBA8)
	var rows: Array[PackedColorArray] = []
	for y: int in src.get_height():
		var row: PackedColorArray = PackedColorArray()
		row.resize(src.get_width())
		var white: bool = true
		for x: int in src.get_width():
			var c: Color = src.get_pixel(x, y)
			row[x] = c
			if c.r8 < NEAR_WHITE or c.g8 < NEAR_WHITE or c.b8 < NEAR_WHITE:
				white = false
		if white or (not rows.is_empty() and rows.back() == row):
			continue
		rows.append(row)
	return rows


static func _load_rgba(path: String) -> Image:
	var img: Image = Image.load_from_file(path)
	if img == null or img.is_empty() or img.get_size() != CELL:
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


#Transparent mask pixels read as white (no recolor).
static func _clean_mask(mask: Image) -> Image:
	var px: PackedInt32Array = mask.get_data().to_int32_array()
	var changed: bool = false
	for i: int in px.size():
		if (px[i] >> 24) & 0xFF == 0:
			px[i] = WHITE_PX
			changed = true
	if not changed:
		return mask
	return Image.create_from_data(CELL.x, CELL.y, false, Image.FORMAT_RGBA8, px.to_byte_array())


#A key whose every visible pixel copies the base color is an unpainted leftover. When the part has real keys it
#folds into the nearest one if that key is shared or within STRAY_FOLD, else it turns white.
static func _fold_strays(base: Image, mask: Image) -> Image:
	var bpx: PackedInt32Array = base.get_data().to_int32_array()
	var mpx: PackedInt32Array = mask.get_data().to_int32_array()
	var copies: Dictionary = {}
	for i: int in mpx.size():
		var rgb: int = mpx[i] & WHITE_RGB
		if rgb == WHITE_RGB or (bpx[i] >> 24) & 0xFF == 0:
			continue
		copies[rgb] = bool(copies.get(rgb, true)) and (bpx[i] & WHITE_RGB) == rgb
	var real: Array[int] = []
	var strays: Array[int] = []
	for rgb: int in copies:
		if copies[rgb] and not KEY_GROUPS.has(_key_text(rgb)):
			strays.append(rgb)
		else:
			real.append(rgb)
	if strays.is_empty() or real.is_empty():
		return mask
	var target: Dictionary = {}
	for rgb: int in strays:
		var near: int = real[0]
		for r: int in real:
			if _dist_sq(r, rgb) < _dist_sq(near, rgb):
				near = r
		var fold: bool = KEY_GROUPS.has(_key_text(near)) or _dist_sq(near, rgb) <= STRAY_FOLD * STRAY_FOLD
		target[rgb] = near if fold else WHITE_RGB
	for i: int in mpx.size():
		var rgb: int = mpx[i] & WHITE_RGB
		if target.has(rgb):
			mpx[i] = (mpx[i] & ~WHITE_RGB) | int(target[rgb])
	return Image.create_from_data(CELL.x, CELL.y, false, Image.FORMAT_RGBA8, mpx.to_byte_array())


static func _key_text(rgb: int) -> String:
	return "%d,%d,%d" % [rgb & 0xFF, (rgb >> 8) & 0xFF, (rgb >> 16) & 0xFF]


static func _dist_sq(a: int, b: int) -> int:
	var total: int = 0
	for shift: int in [0, 8, 16]:
		var d: int = ((a >> shift) & 0xFF) - ((b >> shift) & 0xFF)
		total += d * d
	return total


#Non-white mask keys under visible base pixels, most pixels first.
static func _regions(base: Image, mask: Image) -> Array:
	var bpx: PackedInt32Array = base.get_data().to_int32_array()
	var mpx: PackedInt32Array = mask.get_data().to_int32_array()
	var tally: Dictionary = {}
	for i: int in mpx.size():
		var rgb: int = mpx[i] & WHITE_RGB
		if rgb == WHITE_RGB or (bpx[i] >> 24) & 0xFF == 0:
			continue
		tally[rgb] = int(tally.get(rgb, 0)) + 1
	var keys: Array = tally.keys()
	keys.sort_custom(func(a: int, b: int) -> bool: return tally[a] > tally[b] or (tally[a] == tally[b] and a < b))
	var out: Array = []
	for k: int in keys:
		out.append({"key": [k & 0xFF, (k >> 8) & 0xFF, (k >> 16) & 0xFF], "group": KEY_GROUPS.get(_key_text(k), "common")})
	return out


static func _write_palettes(pal_dir: String, out_abs: String, errors: Array[String]) -> Dictionary:
	var info: Dictionary = {}
	DirAccess.make_dir_recursive_absolute(out_abs.path_join("palettes"))
	for group: String in PALETTE_SOURCES:
		var rows: Array[PackedColorArray] = []
		for f: String in PALETTE_SOURCES[group]:
			var img: Image = Image.load_from_file(pal_dir.path_join(f))
			if img == null or img.is_empty():
				errors.append("bad palette %s" % f)
				continue
			for row: PackedColorArray in gradient_rows(img):
				if rows.is_empty() or rows.back() != row:
					rows.append(row)
		if rows.is_empty():
			continue
		var out: Image = Image.create_empty(256, rows.size(), false, Image.FORMAT_RGBA8)
		for y: int in rows.size():
			for x: int in 256:
				out.set_pixel(x, y, rows[y][mini(x, rows[y].size() - 1)])
		var rel: String = "palettes/%s.png" % group
		if save_png(out,out_abs.path_join(rel), errors):
			info[group] = {"file": rel, "rows": rows.size()}
	return info


#One part per line so the committed index diffs cleanly.
static func _write_index(out_abs: String, parts: Array[Dictionary], palettes: Dictionary,
		errors: Array[String]) -> void:
	var lines: PackedStringArray = PackedStringArray()
	for p: Dictionary in parts:
		lines.append(" " + JSON.stringify(p, "", false))
	var head: String = "{\"version\": 1, \"cell\": [%d, %d], \"frame\": [64, 64], \"grid\": [9, 6],\n" % [CELL.x, CELL.y]
	head += " \"slots\": %s,\n \"palettes\": %s,\n \"parts\": [\n" % [JSON.stringify(SLOTS),
		JSON.stringify(palettes, "", false)]
	var text: String = head + ",\n".join(lines) + "\n]}\n"
	var fa: FileAccess = FileAccess.open(out_abs.path_join("parts_index.json"), FileAccess.WRITE)
	if fa == null:
		errors.append("cannot write parts_index.json")
		return
	fa.store_string(text)
	fa.close()


static func _copy_items(items_dir: String, items_index: String, items_out: String, errors: Array[String]) -> int:
	var copied: int = 0
	var root_out: String = items_out.path_join(items_dir.get_file())
	var pending: Array[String] = [""]
	while not pending.is_empty():
		var rel: String = pending.pop_back()
		var src: String = items_dir.path_join(rel)
		DirAccess.make_dir_recursive_absolute(root_out.path_join(rel))
		for d: String in DirAccess.get_directories_at(src):
			pending.append(rel.path_join(d))
		for f: String in DirAccess.get_files_at(src):
			if f.get_extension().to_lower() != "png":
				continue
			var dst: String = root_out.path_join(rel).path_join(f)
			if DirAccess.copy_absolute(src.path_join(f), dst) != OK:
				errors.append("cannot copy %s" % rel.path_join(f))
				continue
			_write_keep(dst, errors)
			copied += 1
	if DirAccess.copy_absolute(items_index, items_out.path_join(items_index.get_file())) != OK:
		errors.append("cannot copy %s" % items_index.get_file())
	return copied


static func save_png(img: Image, path: String, errors: Array[String]) -> bool:
	if img.save_png(path) != OK:
		errors.append("cannot save %s" % path)
		return false
	return _write_keep(path, errors)


static func _write_keep(path: String, errors: Array[String]) -> bool:
	var fa: FileAccess = FileAccess.open(path + ".import", FileAccess.WRITE)
	if fa == null:
		errors.append("cannot write %s.import" % path)
		return false
	fa.store_string(KEEP_IMPORT)
	fa.close()
	return true
