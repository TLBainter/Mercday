class_name GuiCursorTests

#The software pointer: the cursor sheet cuts, the shape to cut table, the shape walk over pass-through
#parents, the headless autoload and the LineEdit caret overlay. Run with the gui-cursor-tests harness flag.

const CURSOR_SCRIPT: GDScript = preload("res://Scripts/GUI/Autoloads/MouseCursor.gd")
const IDS: Array[String] = ["arrow", "hand", "press", "grab", "ibeam", "caret"]
const ATLAS: Rect2i = Rect2i(0, 0, 256, 640)
const BLUE_DROP: int = 32
const ORANGE_INK: Color = Color("#f28c28")
const BLUE_INK: Color = Color("#8a97ad")
const FIELD_SIZE: Vector2 = Vector2(200, 28)


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_sheet(res)
	_case_pick(res)
	_case_shape(res, host)
	_case_autoload(res)
	await _case_caret(res, host)
	return TestFixtures.summarize(res, "GUI CURSOR")


static func _json_rect(value: Variant) -> Rect2i:
	var arr: Array = value as Array
	return Rect2i(int(arr[0]), int(arr[1]), int(arr[2]), int(arr[3]))


static func _holds(img: Image, ink: Color) -> bool:
	for y: int in img.get_height():
		for x: int in img.get_width():
			var px: Color = img.get_pixel(x, y)
			if px.a > 0.0 and GuiIconTests.same_rgb(px, ink):
				return true
	return false


static func _case_sheet(res: Dictionary) -> void:
	var list: Array[String] = CursorSheet.ids()
	TestFixtures.check(res, "the cursor sheet lists the six cuts in json order", list == IDS, "%s" % [list])
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Icons.IDS_PATH)) as Dictionary
	var rows: Array = parsed.get("cursors", []) as Array
	var outside: Array[String] = []
	var pairing: Array[String] = []
	var spots: Array[String] = []
	var sizes: Array[String] = []
	var masks: Array[String] = []
	for entry: Variant in rows:
		var row: Dictionary = entry as Dictionary
		var id: String = String(row["id"])
		var orange_rect: Rect2i = _json_rect(row["orange"])
		var blue_rect: Rect2i = _json_rect(row["blue"])
		if not ATLAS.encloses(orange_rect) or not ATLAS.encloses(blue_rect):
			outside.append(id)
		if blue_rect.size != orange_rect.size or blue_rect.position != orange_rect.position + Vector2i(0, BLUE_DROP):
			pairing.append(id)
		var spot: Vector2i = CursorSheet.hotspot(id)
		if not Rect2i(Vector2i.ZERO, orange_rect.size).has_point(spot):
			spots.append("%s %s" % [id, spot])
		var orange_img: Image = CursorSheet.orange(id).get_image()
		var blue_img: Image = CursorSheet.blue(id).get_image()
		if orange_img.get_size() != CursorSheet.size(id) or blue_img.get_size() != CursorSheet.size(id):
			sizes.append(id)
		elif GuiIconTests.count_pixels(orange_img,
				func(x: int, y: int, px: Color) -> bool: return (px.a > 0.0) != (blue_img.get_pixel(x, y).a > 0.0)) > 0:
			masks.append(id)
	TestFixtures.check(res, "every orange and blue rect sits inside the atlas", outside.is_empty(),
		TestFixtures.detail(outside, rows.size(), "cursors"))
	TestFixtures.check(res, "every blue rect matches its orange size 32 px lower", pairing.is_empty(),
		TestFixtures.detail(pairing, rows.size(), "cursors"))
	TestFixtures.check(res, "every hotspot sits inside its rect", spots.is_empty(),
		TestFixtures.detail(spots, rows.size(), "cursors"))
	TestFixtures.check(res, "the baked orange and blue textures carry the rect size", sizes.is_empty(),
		TestFixtures.detail(sizes, rows.size(), "cursors"))
	TestFixtures.check(res, "the orange and blue cuts share one alpha mask", masks.is_empty(),
		TestFixtures.detail(masks, rows.size(), "cursors"))
	TestFixtures.check(res, "the arrow cuts hold the orange and blue main inks",
		_holds(CursorSheet.orange("arrow").get_image(), ORANGE_INK)
		and _holds(CursorSheet.blue("arrow").get_image(), BLUE_INK), "f28c28 and 8a97ad")
	TestFixtures.check(res, "an unknown cursor id is refused with a zero hotspot",
		not CursorSheet.has("nope") and CursorSheet.hotspot("nope") == Vector2i.ZERO,
		"has %s hotspot %s" % [CursorSheet.has("nope"), CursorSheet.hotspot("nope")])


static func _case_pick(res: Dictionary) -> void:
	var table: Array = [
		[Control.CURSOR_ARROW, false, false, "arrow"],
		[Control.CURSOR_POINTING_HAND, false, false, "hand"],
		[Control.CURSOR_POINTING_HAND, true, false, "press"],
		[Control.CURSOR_IBEAM, false, false, "ibeam"],
		[Control.CURSOR_IBEAM, true, false, "ibeam"],
		[Control.CURSOR_ARROW, false, true, "grab"],
		[Control.CURSOR_POINTING_HAND, true, true, "grab"],
		[Control.CURSOR_DRAG, false, false, "grab"],
		[Control.CURSOR_FORBIDDEN, false, false, "arrow"],
		[Control.CURSOR_CAN_DROP, false, false, "arrow"],
		[Control.CURSOR_ARROW, true, false, "arrow"],
	]
	for row: Array in table:
		var got: String = CURSOR_SCRIPT.pick(int(row[0]), bool(row[1]), bool(row[2]))
		TestFixtures.check(res, "pick shape %d pressed %s dragging %s gives %s" % [row[0], row[1], row[2], row[3]],
			got == String(row[3]), got)


static func _shape_of(c: Control) -> int:
	return CURSOR_SCRIPT.shape_at(c, c.get_global_transform_with_canvas() * (c.size / 2.0))


static func _case_shape(res: Dictionary, host: Node) -> void:
	var probe := Control.new()
	host.add_child(probe)
	var live := Button.new()
	probe.add_child(live)
	var dead := Button.new()
	dead.disabled = true
	probe.add_child(dead)
	var holder := Button.new()
	probe.add_child(holder)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.add_child(row)
	var walled := Button.new()
	probe.add_child(walled)
	var wall := Control.new()
	wall.mouse_filter = Control.MOUSE_FILTER_STOP
	walled.add_child(wall)
	var field := LineEdit.new()
	probe.add_child(field)
	var panel := Panel.new()
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	probe.add_child(panel)
	TestFixtures.check(res, "an enabled button reads the pointing hand",
		_shape_of(live) == Control.CURSOR_POINTING_HAND, "%d" % _shape_of(live))
	TestFixtures.check(res, "a disabled button reads forbidden",
		_shape_of(dead) == Control.CURSOR_FORBIDDEN, "%d" % _shape_of(dead))
	TestFixtures.check(res, "a pass-through box inside a button reads the pointing hand",
		_shape_of(row) == Control.CURSOR_POINTING_HAND, "%d" % _shape_of(row))
	TestFixtures.check(res, "a stopping control inside a button reads the arrow",
		_shape_of(wall) == Control.CURSOR_ARROW, "%d" % _shape_of(wall))
	TestFixtures.check(res, "a line edit reads the ibeam",
		_shape_of(field) == Control.CURSOR_IBEAM, "%d" % _shape_of(field))
	TestFixtures.check(res, "a panel with a hand default shape reads the pointing hand",
		_shape_of(panel) == Control.CURSOR_POINTING_HAND, "%d" % _shape_of(panel))
	var none: int = CURSOR_SCRIPT.shape_at(null, Vector2.ZERO)
	TestFixtures.check(res, "no hovered control reads the arrow", none == Control.CURSOR_ARROW, "%d" % none)
	probe.free()


static func _case_autoload(res: Dictionary) -> void:
	TestFixtures.check(res, "the cursor layer sits above the embedded windows", MouseCursor.layer == 1025,
		"%d" % MouseCursor.layer)
	TestFixtures.check(res, "the cursor stays off in a headless run",
		not MouseCursor.enabled and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"enabled %s mode %d" % [MouseCursor.enabled, Input.mouse_mode])
	TestFixtures.check(res, "the cursor processes while the tree is paused",
		MouseCursor.process_mode == Node.PROCESS_MODE_ALWAYS, "%d" % MouseCursor.process_mode)


static func _width(field: LineEdit, s: String) -> float:
	var font: Font = field.get_theme_font("font")
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, field.get_theme_font_size("font_size")).x


static func _case_caret(res: Dictionary, host: Node) -> void:
	var field := LineEdit.new()
	host.add_child(field)
	field.size = FIELD_SIZE
	field.text = "abc"
	field.caret_column = 3
	field.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var glyph: CaretGlyph = CaretGlyph.attach(field)
	var again: CaretGlyph = CaretGlyph.attach(field)
	var count: int = 0
	for child: Node in field.get_children():
		if child is CaretGlyph:
			count += 1
	TestFixtures.check(res, "attach gives one overlay that of and a second attach return",
		glyph != null and CaretGlyph.of(field) == glyph and again == glyph and count == 1, "%d overlays" % count)
	TestFixtures.check(res, "attach hides the engine caret and its blink",
		field.get_theme_color("caret_color").a == 0.0 and not field.caret_blink,
		"alpha %s blink %s" % [field.get_theme_color("caret_color").a, field.caret_blink])
	var left: float = field.get_theme_stylebox("normal").get_margin(SIDE_LEFT)
	var abc: float = _width(field, "abc")
	var want: int = int(left + abc)
	TestFixtures.check(res, "the caret sits after the text on a left field", CaretGlyph.caret_x(field) == want,
		"%d want %d" % [CaretGlyph.caret_x(field), want])
	field.caret_column = 0
	TestFixtures.check(res, "caret column 0 sits on the left margin", CaretGlyph.caret_x(field) == int(left),
		"%d want %d" % [CaretGlyph.caret_x(field), int(left)])
	field.caret_column = 3
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	want = int(floorf((FIELD_SIZE.x - abc) / 2.0) + abc)
	TestFixtures.check(res, "the caret sits after the centered text", CaretGlyph.caret_x(field) == want,
		"%d want %d" % [CaretGlyph.caret_x(field), want])
	field.text = ""
	field.placeholder_text = "Name"
	want = int(floorf((FIELD_SIZE.x - _width(field, "Name")) / 2.0))
	TestFixtures.check(res, "an empty centered field puts the caret before the placeholder",
		CaretGlyph.caret_x(field) == want, "%d want %d" % [CaretGlyph.caret_x(field), want])
	CaretGlyph.watch(host.get_tree())
	var late := LineEdit.new()
	host.add_child(late)
	await TestFixtures.frames(host, 1)
	TestFixtures.check(res, "a line edit added after watch gets an overlay", CaretGlyph.of(late) != null,
		"overlay %s" % [CaretGlyph.of(late)])
	field.queue_free()
	late.queue_free()
	await TestFixtures.frames(host, 1)
	TestFixtures.check(res, "freeing the field frees its overlay", not is_instance_valid(glyph),
		"valid %s" % is_instance_valid(glyph))
