class_name GuiIconTests

#The icon atlas engine: the id table, the atlas cuts, the tint passes, the star row and the
#IconRect bake. Run with the gui-icon-tests harness flag.

const ID_COUNT: int = 175
const LOOSE_ART: Vector2i = Vector2i(16, 16)
const SETTINGS_SCENE: String = "res://Scenes/GUI/HUD/SettingsButton.tscn"
const BELL_ORANGE: Color = Color("#f28c28")
const BELL_GRAY: int = 159
const CHANNEL_EPS: float = 1.0 / 255.0
const X_REDS: Array[Color] = [Color("#ff8a70"), Color("#ff3b2f"), Color("#a83a28")]


#A Control that runs the three draw helpers inside a real draw pass.
class DrawProbe extends Control:
	var painted: int = 0
	var star_width: int = 0

	func _draw() -> void:
		painted += 1
		Icons.draw(self, "mercs", Vector2(3.7, 2.2), 2)
		Icons.draw_texture(self, Icons.baked("gear", 2), Vector2.ZERO, 1)
		star_width = Icons.draw_stars(self, Vector2(0, 40), 2, 3.5)


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await _case_ids(res, host)
	await _case_atlas(res, host)
	await _case_regions(res, host)
	await _case_cache(res, host)
	await _case_bbox(res, host)
	await _case_gray(res, host)
	await _case_two_tone(res, host)
	await _case_solid(res, host)
	await _case_stars(res, host)
	await _case_star_color(res, host)
	await _case_star_fills(res, host)
	await _case_draw(res, host)
	await _case_bake(res, host)
	await _case_icon_rect(res, host)
	await _case_helpers(res, host)
	await _case_close(res, host)
	await _case_tinted(res, host)
	return TestFixtures.summarize(res, "GUI ICON")


static func _same_rgb(a: Color, b: Color) -> bool:
	return a.r8 == b.r8 and a.g8 == b.g8 and a.b8 == b.b8


static func _same_image(a: Image, b: Image) -> bool:
	return a.get_size() == b.get_size() and a.get_data() == b.get_data()


#A texture that never came from the atlas, so the legacy source path of Icons and IconRect has
#something to bake without a loose png on disk.
static func _loose_texture() -> ImageTexture:
	var img := Image.create(LOOSE_ART.x, LOOSE_ART.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	img.fill_rect(Rect2i(3, 3, 10, 10), Color.WHITE)
	return ImageTexture.create_from_image(img)


static func _bbox(img: Image, origin: Vector2i) -> Rect2i:
	var min_x: int = Icons.CELL
	var min_y: int = Icons.CELL
	var max_x: int = -1
	var max_y: int = -1
	for y: int in Icons.CELL:
		for x: int in Icons.CELL:
			if img.get_pixel(origin.x + x, origin.y + y).a <= 0.0:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2i(0, 0, 0, 0)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


static func _case_ids(res: Dictionary, _host: Node) -> void:
	var list: Array[String] = Icons.ids()
	TestFixtures.check(res, "the id table holds every icon of the sheet", list.size() == ID_COUNT,
		"%d ids" % list.size())
	var seen: Dictionary = {}
	var bad: Array[String] = []
	for id: String in list:
		if seen.has(id):
			bad.append("duplicate %s" % id)
		seen[id] = true
		if id.to_ascii_buffer().size() != id.length():
			bad.append("non ascii %s" % id)
		var at: Vector2i = Icons.cell(id)
		if at.x < 0 or at.y < 0 or at.x >= Icons.COLS or at.y >= Icons.ROWS:
			bad.append("cell %s %s" % [id, at])
		var off: Vector2i = Icons.offset(id)
		var box: Vector2i = Icons.size(id)
		if off.x < 0 or off.y < 0 or off.x + box.x > Icons.CELL or off.y + box.y > Icons.CELL:
			bad.append("box %s %s %s" % [id, off, box])
	TestFixtures.check(res, "every id is ascii, unique and inside the grid", bad.is_empty(),
		TestFixtures.detail(bad, list.size(), "ids"))
	TestFixtures.check(res, "has answers for a known id and refuses an unknown one",
		Icons.has("mercs") and not Icons.has("nope"),
		"mercs %s nope %s" % [Icons.has("mercs"), Icons.has("nope")])


static func _case_atlas(res: Dictionary, _host: Node) -> void:
	var img: Image = Icons.atlas_image()
	TestFixtures.check(res, "the atlas image is 256 by 640",
		img.get_width() == 256 and img.get_height() == 640,
		"%d x %d" % [img.get_width(), img.get_height()])
	var soft: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			var a: int = img.get_pixel(x, y).a8
			if a != 0 and a != 255:
				soft += 1
	TestFixtures.check(res, "every atlas pixel is fully clear or fully opaque", soft == 0,
		"%d soft pixels" % soft)
	TestFixtures.check(res, "the atlas texture is the sheet under Art GUI Icons",
		Icons.atlas() != null and Icons.atlas().resource_path == Icons.ATLAS_PATH,
		Icons.ATLAS_PATH if Icons.atlas() == null else Icons.atlas().resource_path)


static func _case_regions(res: Dictionary, _host: Node) -> void:
	var want: Dictionary = {
		"mercs": Rect2(0, 0, 16, 16),
		"star_set": Rect2(0, 208, 16, 16),
		"star_unused": Rect2(16, 208, 16, 16),
		"sigil_divine": Rect2(0, 224, 16, 16),
		"bell": Rect2(144, 0, 16, 16),
	}
	var bad: Array[String] = []
	for id: String in want:
		var got: Rect2 = Icons.tex(id).region
		if got != (want[id] as Rect2):
			bad.append("%s %s" % [id, got])
	TestFixtures.check(res, "a full cut covers the whole cell of its id", bad.is_empty(),
		TestFixtures.detail(bad, want.size(), "cells"))
	var tight: Dictionary = {
		"note": Rect2(229, 35, 5, 9),
		"skull": Rect2(131, 34, 11, 13),
		"x_sm": Rect2(35, 35, 10, 10),
		"lock": Rect2(244, 35, 8, 9),
	}
	bad = []
	for id: String in tight:
		var got: Rect2 = Icons.tex(id, true).region
		if got != (tight[id] as Rect2):
			bad.append("%s %s" % [id, got])
	TestFixtures.check(res, "a trimmed cut covers the tight box of its id", bad.is_empty(),
		TestFixtures.detail(bad, tight.size(), "boxes"))
	TestFixtures.check(res, "cell, offset and size agree with the cuts",
		Icons.cell("note") == Vector2i(14, 2) and Icons.offset("note") == Vector2i(5, 3)
			and Icons.size("note") == Vector2i(5, 9) and Icons.cell("skull") == Vector2i(8, 2)
			and Icons.offset("skull") == Vector2i(3, 2) and Icons.size("skull") == Vector2i(11, 13),
		"note %s %s %s" % [Icons.cell("note"), Icons.offset("note"), Icons.size("note")])


static func _case_cache(res: Dictionary, _host: Node) -> void:
	var first: AtlasTexture = Icons.tex("mercs")
	TestFixtures.check(res, "the same id and trim hand back the same cut",
		first == Icons.tex("mercs") and first != Icons.tex("mercs", true),
		"full %d trimmed %d" % [first.get_instance_id(), Icons.tex("mercs", true).get_instance_id()])
	var win: AtlasTexture = Icons.window("mercs", Rect2i(4, 4, 8, 8))
	TestFixtures.check(res, "a window cuts its box out of the cell and is cached",
		win.region == Rect2(4, 4, 8, 8) and win == Icons.window("mercs", Rect2i(4, 4, 8, 8)),
		"region %s" % win.region)
	TestFixtures.check(res, "a centred box sits in the middle of the cell",
		Icons.centered_box(8, 8) == Rect2i(4, 4, 8, 8)
			and Icons.centered_box(12, 12) == Rect2i(2, 2, 12, 12),
		"%s %s" % [Icons.centered_box(8, 8), Icons.centered_box(12, 12)])
	Icons.clear_cache()
	TestFixtures.check(res, "clearing the cache builds a fresh cut", Icons.tex("mercs") != first,
		"same %s" % str(Icons.tex("mercs") == first))


static func _case_bbox(res: Dictionary, _host: Node) -> void:
	var img: Image = Icons.atlas_image()
	var bad: Array[String] = []
	for id: String in Icons.ids():
		var origin: Vector2i = Icons.cell(id) * Icons.CELL
		var box: Rect2i = _bbox(img, origin)
		if box.position != Icons.offset(id) or box.size != Icons.size(id):
			bad.append("%s %s against %s %s" % [id, box, Icons.offset(id), Icons.size(id)])
	TestFixtures.check(res, "every trimmed box equals the alpha bounds of its cell", bad.is_empty(),
		TestFixtures.detail(bad, ID_COUNT, "ids", 1))


static func _case_gray(res: Dictionary, _host: Node) -> void:
	var src: Image = Icons.image("bell")
	var gray: Image = Icons.gray_image(src)
	var bad: int = 0
	var orange_gray: int = -1
	for y: int in src.get_height():
		for x: int in src.get_width():
			var was: Color = src.get_pixel(x, y)
			var now: Color = gray.get_pixel(x, y)
			if (was.a > 0.0) != (now.a > 0.0):
				bad += 1
				continue
			if was.a <= 0.0:
				continue
			if now.r8 != now.g8 or now.g8 != now.b8:
				bad += 1
			if _same_rgb(was, BELL_ORANGE):
				orange_gray = now.r8
	TestFixtures.check(res, "the grey pass keeps the alpha mask and flattens every opaque pixel",
		bad == 0, "%d offenders" % bad)
	TestFixtures.check(res, "the grey pass weighs the channels of the bell orange",
		orange_gray == BELL_GRAY, "got %d wanted %d" % [orange_gray, BELL_GRAY])


static func _case_two_tone(res: Dictionary, _host: Node) -> void:
	var src: Image = Icons.image("bell")
	var tone: Image = Icons.two_tone_image(src)
	var ink: int = 0
	var bad: int = 0
	for y: int in src.get_height():
		for x: int in src.get_width():
			var was: Color = src.get_pixel(x, y)
			var now: Color = tone.get_pixel(x, y)
			if (was.a > 0.0) != (now.a > 0.0):
				bad += 1
				continue
			if was.a <= 0.0:
				continue
			if _same_rgb(now, Icons.TAB_ON_INK):
				ink += 1
			elif not _same_rgb(now, Icons.TAB_ON_LIGHT) and not _same_rgb(now, Icons.TAB_ON_MID):
				bad += 1
			if _same_rgb(was, Color.WHITE) and not _same_rgb(now, Icons.TAB_ON_LIGHT):
				bad += 1
	TestFixtures.check(res, "the tab pass paints only the three tab colours and keeps the mask",
		bad == 0, "%d offenders" % bad)
	TestFixtures.check(res, "the tab pass sinks every saturated pixel of the bell to ink",
		ink == 12, "%d ink pixels" % ink)


static func _case_solid(res: Dictionary, _host: Node) -> void:
	var made: ImageTexture = Icons.solid_outlined("x_sm", Color.WHITE, Color.BLACK, 1, true)
	var img: Image = made.get_image()
	var src: Image = Icons.image("x_sm", true)
	var opaque: int = 0
	for y: int in src.get_height():
		for x: int in src.get_width():
			if src.get_pixel(x, y).a > 0.0:
				opaque += 1
	var white: int = 0
	var lonely: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			var px: Color = img.get_pixel(x, y)
			if px.a <= 0.0:
				continue
			if _same_rgb(px, Color.WHITE):
				white += 1
				continue
			var near: bool = false
			for step: Vector2i in Icons.NEIGHBOURS:
				var at: Vector2i = Vector2i(x, y) + step
				if at.x < 0 or at.y < 0 or at.x >= img.get_width() or at.y >= img.get_height():
					continue
				if _same_rgb(img.get_pixel(at.x, at.y), Color.WHITE) \
						and img.get_pixel(at.x, at.y).a > 0.0:
					near = true
			if not near:
				lonely += 1
	TestFixtures.check(res, "the outlined fill grows one pixel a side around the trimmed art",
		img.get_size() == Vector2i(12, 12), str(img.get_size()))
	TestFixtures.check(res, "every opaque source pixel became fill and every ring pixel touches one",
		white == opaque and lonely == 0 and img.get_pixel(0, 0).a <= 0.0,
		"fill %d of %d lonely %d" % [white, opaque, lonely])
	var big: ImageTexture = Icons.solid_outlined("x_sm", Color.WHITE, Color.BLACK, 3, true)
	TestFixtures.check(res, "the outlined fill scales by whole art pixels",
		big.get_image().get_size() == Vector2i(36, 36), str(big.get_image().get_size()))
	var kept: ImageTexture = Icons.outlined("x_sm", Color.BLACK, 1, true)
	var kept_img: Image = kept.get_image()
	var reds: int = 0
	var strange: int = 0
	for y: int in kept_img.get_height():
		for x: int in kept_img.get_width():
			var px: Color = kept_img.get_pixel(x, y)
			if px.a <= 0.0:
				continue
			if _same_rgb(px, Color.BLACK):
				continue
			var known: bool = false
			for red: Color in X_REDS:
				if _same_rgb(px, red):
					known = true
			if known:
				reds += 1
			else:
				strange += 1
	TestFixtures.check(res, "the kept outline leaves the art its own colours",
		reds == opaque and strange == 0, "reds %d of %d strangers %d" % [reds, opaque, strange])
	TestFixtures.check(res, "the kept outline scales whole and caches its texture",
		Icons.outlined("x_sm", Color.BLACK, 3, true).get_image().get_size() == Vector2i(36, 36)
			and kept == Icons.outlined("x_sm", Color.BLACK, 1, true),
		str(Icons.outlined("x_sm", Color.BLACK, 3, true).get_image().get_size()))


static func _case_stars(res: Dictionary, _host: Node) -> void:
	var set_src: Image = Icons.image("star_set")
	var full: Image = Icons.star_image(1.0, Color.WHITE)
	var bad: int = 0
	for y: int in full.get_height():
		for x: int in full.get_width():
			var was: Color = set_src.get_pixel(x, y)
			var now: Color = full.get_pixel(x, y)
			if (was.a > 0.0) != (now.a > 0.0):
				bad += 1
			elif now.a > 0.0 and (now.r8 != now.g8 or now.g8 != now.b8):
				bad += 1
	TestFixtures.check(res, "a set star keeps the mask of its art and is grey before the tint",
		bad == 0, "%d offenders" % bad)
	var empty: Image = Icons.star_image(0.0, Color.WHITE, Color.WHITE)
	TestFixtures.check(res, "an unused star in white is the grey pass over its art",
		_same_image(empty, Icons.gray_image(Icons.image("star_unused"))),
		"size %s" % str(empty.get_size()))
	var half: Image = Icons.star_image(0.5, Color.RED, Color.BLUE)
	var red: Image = Icons.star_image(1.0, Color.RED)
	var blue: Image = Icons.star_image(0.0, Color.WHITE, Color.BLUE)
	bad = 0
	for y: int in half.get_height():
		for x: int in half.get_width():
			var want: Color = red.get_pixel(x, y) if x < 8 else blue.get_pixel(x, y)
			if not half.get_pixel(x, y).is_equal_approx(want):
				bad += 1
	TestFixtures.check(res, "a half star is the set art on the left and the unused art on the right",
		bad == 0, "%d offenders" % bad)
	var art: ImageTexture = Icons.star(1.0, Color.RED, Icons.UNUSED_STAR, 2)
	TestFixtures.check(res, "a star texture scales by whole art pixels and is cached",
		art.get_size() == Vector2(32, 32) and art == Icons.star(1.0, Color.RED, Icons.UNUSED_STAR, 2),
		"size %s" % str(art.get_size()))


static func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= CHANNEL_EPS and absf(a.g - b.g) <= CHANNEL_EPS \
		and absf(a.b - b.b) <= CHANNEL_EPS


static func _case_star_color(res: Dictionary, _host: Node) -> void:
	var bad: Array[String] = []
	var want: Array = [[0.5, false, "#29e029"], [3.0, false, "#e3d83b"], [5.0, false, "#e03829"],
		[5.0, true, "#29e029"], [0.5, true, "#e03829"], [9.0, false, "#e03829"],
		[0.0, false, "#29e029"]]
	for row: Array in want:
		var got: Color = Icons.star_color(float(row[0]), bool(row[1]))
		if not _near(got, Color(String(row[2]))):
			bad.append("%s %s got %s" % [row[0], row[1], got.to_html(false)])
	TestFixtures.check(res, "the star gradient lands on its own stops at both ends", bad.is_empty(),
		TestFixtures.detail(bad, want.size(), "stops"))
	var mid: Color = Icons.star_color(1.75)
	var low: Color = Color("#77e029")
	var high: Color = Color("#a6e33b")
	var inside: bool = mid.r >= low.r - CHANNEL_EPS and mid.r <= high.r + CHANNEL_EPS \
		and mid.g >= low.g - CHANNEL_EPS and mid.g <= high.g + CHANNEL_EPS \
		and mid.b >= low.b - CHANNEL_EPS and mid.b <= high.b + CHANNEL_EPS
	TestFixtures.check(res, "a value between two stops reads between them on every channel", inside,
		mid.to_html(false))


static func _case_star_fills(res: Dictionary, _host: Node) -> void:
	TestFixtures.check(res, "a rating fills whole stars, then a half, then nothing",
		Icons.star_fills(3.5) == [1.0, 1.0, 1.0, 0.5, 0.0] and Icons.star_fills(0.0) ==
			[0.0, 0.0, 0.0, 0.0, 0.0] and Icons.star_fills(5.0) == [1.0, 1.0, 1.0, 1.0, 1.0],
		"%s" % [Icons.star_fills(3.5)])
	TestFixtures.check(res, "a value under the next half star leaves that star empty",
		Icons.star_fills(2.25) == [1.0, 1.0, 0.0, 0.0, 0.0]
			and Icons.star_fills(7.0) == [1.0, 1.0, 1.0, 1.0, 1.0],
		"%s" % [Icons.star_fills(2.25)])
	TestFixtures.check(res, "the star row is five cells wide plus the gaps between them",
		Icons.stars_width(1) == 88 and Icons.stars_width(2) == 176,
		"%d %d" % [Icons.stars_width(1), Icons.stars_width(2)])


static func _case_draw(res: Dictionary, host: Node) -> void:
	var probe := DrawProbe.new()
	probe.custom_minimum_size = Vector2(200.0, 100.0)
	host.add_child(probe)
	await host.get_tree().process_frame
	probe.queue_redraw()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "the icon and star painters run inside a draw pass",
		probe.painted > 0, "painted %d" % probe.painted)
	TestFixtures.check(res, "a drawn star row reports the width it covered",
		probe.star_width == 176, "width %d" % probe.star_width)
	probe.queue_free()


static func _case_bake(res: Dictionary, _host: Node) -> void:
	var big: ImageTexture = Icons.baked("mercs", 3)
	TestFixtures.check(res, "a baked icon is the cell at whole art pixels",
		big.get_size() == Vector2(48, 48), str(big.get_size()))
	var src: Image = Icons.image("mercs")
	var out: Image = big.get_image()
	var spot: Vector2i = Vector2i(-1, -1)
	for y: int in src.get_height():
		for x: int in src.get_width():
			if spot.x < 0 and src.get_pixel(x, y).a > 0.0:
				spot = Vector2i(x, y)
	var want: Color = src.get_pixel(spot.x, spot.y)
	TestFixtures.check(res, "every art pixel fills its whole block in the baked icon",
		spot.x >= 0 and out.get_pixel(spot.x * 3, spot.y * 3).is_equal_approx(want)
			and out.get_pixel(spot.x * 3 + 2, spot.y * 3 + 2).is_equal_approx(want),
		"spot %s" % spot)
	TestFixtures.check(res, "a baked tab icon matches the tab pass over its art",
		_same_image(Icons.baked("bell", 1, Icons.MODE_TWO_TONE).get_image(),
			Icons.two_tone_image(Icons.image("bell"))), "two tone")
	var gray: Image = Icons.baked("bell", 2, Icons.MODE_GRAY).get_image()
	var flat: bool = gray.get_size() == Vector2i(32, 32)
	for y: int in gray.get_height():
		for x: int in gray.get_width():
			var px: Color = gray.get_pixel(x, y)
			if px.a > 0.0 and (px.r8 != px.g8 or px.g8 != px.b8):
				flat = false
	TestFixtures.check(res, "a baked grey icon scales and holds no colour", flat,
		str(gray.get_size()))
	TestFixtures.check(res, "a bake of nothing is nothing", Icons.bake(null, 2) == null, "null")
	var loose: Texture2D = _loose_texture()
	var legacy: ImageTexture = Icons.bake(loose, 3)
	TestFixtures.check(res, "a bake of a loose texture scales it the same way and is cached",
		legacy.get_size() == Vector2(LOOSE_ART * 3) and legacy == Icons.bake(loose, 3),
		"%s against %s" % [str(legacy.get_size()), str(loose.get_size())])


static func _case_icon_rect(res: Dictionary, host: Node) -> void:
	var rect := IconRect.new()
	host.add_child(rect)
	await host.get_tree().process_frame
	rect.set_id("mercs", 2)
	TestFixtures.check(res, "an atlas id bakes the cell at its whole pixel scale",
		rect.texture is ImageTexture and rect.texture.get_size() == Vector2(32, 32)
			and rect.custom_minimum_size == Vector2(32, 32)
			and rect.source() == Icons.tex("mercs") and rect.icon_size() == Vector2i(16, 16),
		"texture %s min %s" % [str(rect.texture.get_size()), str(rect.custom_minimum_size)])
	TestFixtures.check(res, "the rect centres its art at whole pixels and never scales it",
		rect.stretch_mode == TextureRect.STRETCH_KEEP_CENTERED
			and rect.expand_mode == TextureRect.EXPAND_KEEP_SIZE
			and rect.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"stretch %d expand %d filter %d" % [rect.stretch_mode, rect.expand_mode,
			rect.texture_filter])
	rect.trimmed = true
	rect.set_id("note", 1)
	TestFixtures.check(res, "a trimmed id bakes the tight box alone",
		rect.texture.get_size() == Vector2(5, 9), str(rect.texture.get_size()))
	rect.window = Rect2i(4, 4, 8, 8)
	rect.set_id("pip_auto")
	TestFixtures.check(res, "a window bakes that part of the cell alone",
		rect.texture.get_size() == Vector2(8, 8)
			and rect.source() == Icons.window("pip_auto", Rect2i(4, 4, 8, 8)),
		str(rect.texture.get_size()))
	var before: Texture2D = rect.texture
	rect.set_mode(Icons.MODE_GRAY)
	TestFixtures.check(res, "a new tint mode bakes the art again at the same size",
		rect.texture != before and rect.texture.get_size() == Vector2(8, 8),
		"changed %s" % str(rect.texture != before))
	rect.window = Rect2i()
	rect.set_mode(Icons.MODE_PLAIN)
	rect.set_pixel_scale(3)
	var loose: Texture2D = _loose_texture()
	rect.set_icon(loose)
	TestFixtures.check(res, "a loose texture drops the atlas id and bakes at the same scale",
		rect.icon_id == "" and rect.texture.get_size() == Vector2(LOOSE_ART * 3),
		"id '%s' size %s" % [rect.icon_id, str(rect.texture.get_size())])
	rect.tint = Color.RED
	TestFixtures.check(res, "the tint rides modulate", rect.modulate.is_equal_approx(Color.RED),
		str(rect.modulate))
	rect.set_icon(null)
	TestFixtures.check(res, "no art leaves the rect empty and claims no room",
		rect.texture == null and rect.custom_minimum_size == Vector2.ZERO,
		"texture %s min %s" % [rect.texture, str(rect.custom_minimum_size)])
	rect.queue_free()
	var btn: SettingsButton = (load(SETTINGS_SCENE) as PackedScene).instantiate()
	host.add_child(btn)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the settings button reads its gear from the atlas at 32 x 32",
		btn.icon_rect.icon_id == "gear" and btn.icon_rect.texture != null
			and btn.icon_rect.texture.get_size() == Vector2(32.0, 32.0),
		"id '%s' size %s" % [btn.icon_rect.icon_id, "none" if btn.icon_rect.texture == null
			else str(btn.icon_rect.texture.get_size())])
	btn.queue_free()


static func _case_helpers(res: Dictionary, _host: Node) -> void:
	var faces: Array[String] = [Icons.face_id(-5), Icons.face_id(0), Icons.face_id(3, true),
		Icons.face_id(9), Icons.face_id(-9, true)]
	var want: Array[String] = ["face_m5", "face_0", "face_p3_o", "face_unselected",
		"face_unselected_o"]
	var bad: Array[String] = []
	for i: int in faces.size():
		if faces[i] != want[i] or not Icons.has(faces[i]):
			bad.append("%s against %s" % [faces[i], want[i]])
	TestFixtures.check(res, "every face level names a cell of the two face rows", bad.is_empty(),
		TestFixtures.detail(bad, want.size(), "faces"))
	TestFixtures.check(res, "a mood index reads its face level",
		Icons.mood_level(0) == -5 and Icons.mood_level(1) == -3 and Icons.mood_level(2) == 0
			and Icons.mood_level(3) == 3 and Icons.mood_level(4) == 5 and Icons.mood_level(9) == 5,
		"%d %d" % [Icons.mood_level(0), Icons.mood_level(9)])
	TestFixtures.check(res, "a tradition names its sigil and an unknown one names nothing",
		Icons.sigil_id("Divine") == "sigil_divine" and Icons.sigil_id("Warrior") == "sigil_warrior"
			and Icons.sigil_id("Nope") == "",
		"%s %s" % [Icons.sigil_id("Divine"), Icons.sigil_id("Nope")])
	TestFixtures.check(res, "the tint mode of an id comes from the sheet",
		Icons.is_mono("gear") and not Icons.is_mono("mercs"),
		"gear %s mercs %s" % [Icons.is_mono("gear"), Icons.is_mono("mercs")])


static func _case_close(res: Dictionary, host: Node) -> void:
	TestFixtures.check(res, "the close art measures twelve art pixels a side at every scale",
		CloseX.size(3) == Vector2(36, 36) and CloseX.size(1) == Vector2(12, 12),
		"%s %s" % [CloseX.size(3), CloseX.size(1)])
	var art: ImageTexture = CloseX.icon(3)
	TestFixtures.check(res, "the close icon bakes once and hands the same texture back",
		art.get_size() == Vector2(36, 36) and art == CloseX.icon(3), str(art.get_size()))
	var btn: Button = Button.new()
	btn.text = "X"
	btn.add_theme_font_size_override("font_size", 18)
	host.add_child(btn)
	CloseX.style(btn, 3)
	await host.get_tree().process_frame
	TestFixtures.check(res, "styling a close button swaps the letter for the art",
		btn.text == "" and btn.icon == CloseX.icon(3)
			and not btn.has_theme_font_size_override("font_size"),
		"text '%s' icon %s font %s" % [btn.text, btn.icon != null,
			btn.has_theme_font_size_override("font_size")])
	TestFixtures.check(res, "a styled close button measures the art and nothing more",
		btn.custom_minimum_size == Vector2(36, 36)
			and btn.get_combined_minimum_size() == Vector2(36, 36),
		"min %s combined %s" % [btn.custom_minimum_size, btn.get_combined_minimum_size()])
	TestFixtures.check(res, "a styled close button lights up on hover",
		btn.get_theme_color("icon_hover_color") == CloseX.HOVER,
		str(btn.get_theme_color("icon_hover_color")))
	var mini: Button = CloseX.make(1)
	TestFixtures.check(res, "a mini close comes out at one pixel an art pixel",
		mini.custom_minimum_size == Vector2(12, 12), str(mini.custom_minimum_size))
	mini.free()
	var img: Image = art.get_image()
	var middle: Color = img.get_pixel(18, 18)
	var edge: Color = img.get_pixel(1, 18)
	TestFixtures.check(res, "the close art keeps its red heart inside an ink rim",
		middle.r > 0.6 and middle.g < 0.6
			and (edge.a <= 0.0 or _same_rgb(edge, Icons.TAB_ON_INK)),
		"middle %s edge %s" % [middle, edge])
	btn.queue_free()


#The art of the lock is mono but shaded (white and a gray), so a tint multiplies rather than flattens.
static func _case_tinted(res: Dictionary, _host: Node) -> void:
	var white: ImageTexture = Icons.tinted("lock", Color.WHITE, 3, true)
	TestFixtures.check(res, "a tinted icon measures its art at the asked scale",
		white.get_size() == Vector2(24, 27), str(white.get_size()))
	var art: Image = Icons.image("lock", true)
	var img: Image = white.get_image()
	var lit: int = 0
	var pure: int = 0
	var bad: Array[String] = []
	for y: int in img.get_height():
		for x: int in img.get_width():
			var px: Color = img.get_pixel(x, y)
			if px.a <= 0.0:
				continue
			lit += 1
			if _same_rgb(px, Color.WHITE):
				pure += 1
			if not _same_rgb(px, art.get_pixel(x / 3, y / 3)):
				bad.append("%d,%d %s" % [x, y, px.to_html(false)])
	TestFixtures.check(res, "a white tint keeps the art and lights its full pixels",
		lit > 0 and pure > 0 and bad.is_empty(), TestFixtures.detail(bad, lit, "pixels"))
	var red: Image = Icons.tinted("lock", Color(1.0, 0.0, 0.0), 3, true).get_image()
	var reds: int = 0
	var spill: int = 0
	for y: int in red.get_height():
		for x: int in red.get_width():
			var px: Color = red.get_pixel(x, y)
			if px.a <= 0.0:
				continue
			if _same_rgb(px, Color(1.0, 0.0, 0.0)):
				reds += 1
			if px.g8 > 0 or px.b8 > 0:
				spill += 1
	TestFixtures.check(res, "a red tint multiplies every channel of the art",
		reds > 0 and spill == 0, "%d red, %d spill" % [reds, spill])
	var flat: Image = Icons.tinted("lock", Color.WHITE, 1, true).get_image()
	var holes: int = 0
	for y: int in art.get_height():
		for x: int in art.get_width():
			if flat.get_pixel(x, y).a8 != art.get_pixel(x, y).a8:
				holes += 1
	TestFixtures.check(res, "a tint leaves the alpha of the art alone",
		flat.get_size() == art.get_size() and holes == 0,
		"%s, %d pixels differ" % [flat.get_size(), holes])
	TestFixtures.check(res, "the same tint comes back as the same texture",
		Icons.tinted("lock", Color.WHITE, 3, true) == white, "the art was built twice")
	TestFixtures.check(res, "another tint is another texture",
		Icons.tinted("lock", Color(1.0, 0.0, 0.0), 3, true) != white, "the tint missed the key")
	var boxed: ImageTexture = Icons.tinted("check_sm", Color.WHITE, 1, false,
		Icons.centered_box(12, 12))
	TestFixtures.check(res, "a tinted window measures the box it was cut to",
		boxed.get_size() == Vector2(12, 12), str(boxed.get_size()))
