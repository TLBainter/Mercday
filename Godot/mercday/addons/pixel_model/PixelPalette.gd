@tool
class_name PixelPalette extends RefCounted

#Nation tint tables ported from map-elements.js PALS; unused by stage 3 meshes (Q8).
#Each style string lists key:hex pairs; a key with several colours lists them comma separated.

const BASE: String = "dome:3f9a62 roof:3f9a62 tent:2f7a4a awn:c9452f stripe:c9452f"
const PALS: Dictionary = {
	&"buern": "wall:e8a684 dome:3f9a62 roof:3f9a62 tent:2f7a4a awn:c9452f stripe:c9452f street:b48660,a87b56 "
		+ "plaza:d4b48e,c8a882",
	&"vaernebo": "wall:ead29c dome:e8b440 roof:2f8a5a tent:2f6a4a awn:3f6fb0 stripe:3f9a62 street:b09670,a48a66 "
		+ "plaza:d8c49a,ccb88e",
	&"rossade": "wall:d8c4a4 dome:4a7ac8 roof:4a7ac8 tent:2f6a4a awn:c9452f stripe:e8b440 street:9a8e80,8e8274 "
		+ "plaza:bdb2a4,b2a698",
	&"kathaya": "roof:b0583a wall:e2b88a wood:b07a4a tin:a8aeb2 boards:c8a070,a87850,d8c8a8,8a6040 "
		+ "street:c9a06a,bd9460 plaza:dcc094,d0b488",
	&"aldurstein": "roof:3e4a3c wall:ece6da falu:8a3a2a wood:6a4a32 turf:5a7040 stone:ece6da lead:7a92a8 "
		+ "tile:b0503a block:e4ded2 street:8a8680,7e7a74 plaza:b4aea4,a8a298",
	&"zukei": "roof:3c4452 wall:efece4 thatch:9a8a5c plaster:efece4 red:b0302a stone:a8a49a gray:c8c4bc "
		+ "street:a89a84,9c8e78 plaza:cfc6b4,c4baa8",
	&"suorr": "roof:3f9a62 wall:ece2cc slate:4a4e58 stucco:ece2cc terra:b85a38 soot:3a3634 iron:5a5e64 "
		+ "street:5e5a56,54504c plaza:8a8278,7e766c",
	&"miliim": "roof:3f9a62 wall:b8744a mud:b8744a thatch:c8a050 ochre:d0905a lime:ece0c4 wood:4a3220 "
		+ "street:b0703e,a46636 plaza:c8885a,bc7c4e",
	&"aerdis": "roof:3f9a62 wall:a8a69c white:f0ece0 thatch:c8a860 stone:a8a69c slate:46505c magic:5a6ad0 "
		+ "fronts:2f7a4a,b03a32,3a5a9a,e0b040,7a3a7a street:8a8a7e,7e7e72 plaza:aeae9e,a2a292",
	&"copari": "roof:3f9a62 wall:d8ccb4 plaster:d8ccb4 slate:4a5058 rust:8a5a3a iron:6a6e72 bau:f0f0ec "
		+ "terra:a85a3a pastels:a8c0b0,d8b0a0,c8c0e0,e0d0a0 street:6a6460,605a56 plaza:948c84,888078",
}

static var _cache: Dictionary = {}


static func color_of(style: StringName, key: StringName) -> Color:
	var table: Dictionary = _table(style if PALS.has(style) else &"buern")
	if not table.has(key):
		push_error("PixelPalette: no key %s in style %s" % [key, style])
		return Color.MAGENTA
	return Color.html("#" + String(table[key]).get_slice(",", 0))


static func _table(style: StringName) -> Dictionary:
	if _cache.has(style):
		return _cache[style]
	var out: Dictionary = {}
	for token: String in (BASE + " " + String(PALS[style])).split(" "):
		out[StringName(token.get_slice(":", 0))] = token.get_slice(":", 1)
	_cache[style] = out
	return out
