@tool
class_name PixelKitTrees extends RefCounted

#Tree kits: conifer, broad, droop, palm and dead builders draw from the VR source in JS order.

const KH = preload("res://addons/pixel_model/PixelKitHelpers.gd")
const TREES: Array[String] = ["f_pine", "f_fir", "f_spruce", "f_snowpine", "f_snowfir", "f_juniper", "f_violetfir",
	"f_zpine", "f_oak", "f_beech", "f_maple", "f_birch", "f_cherry", "f_jacaranda", "f_wisteria", "f_wisteria_w",
	"f_willow", "f_acacia", "f_baobab", "f_palm", "f_palm2", "f_jungle", "f_kapok", "f_cypress", "f_mangrove", "f_dead",
	"f_deadc", "f_redwood", "f_emergent", "f_shadepine", "f_mushroom"]

const STATIC: Dictionary = {
	"f_zpine": [6, 6, [["trk", 2.6, 3, 2.6, 0.7, "#4a3a30"],
		["tb", 3.2, 3, 2.4, 0.6, 0.6, 2.4, "bark_g", "#4a3a30", "bark_g"], ["can", 1.8, 3, 2.6, 3.4, 3, 0.7, "#2e5a3a"],
		["can", 4, 3, 3.9, 3.4, 2.8, 0.7, "#346440"], ["can", 2.8, 3, 5.2, 2.8, 2.4, 0.6, "#3a6c46"],
		["can", 3.2, 3, 5.8, 1.4, 1.2, 0.4, "#427650"]]],
	"f_acacia": [7, 6, [["trk", 3.5, 3, 3.6, 0.5, "#6a4a30"],
		["tb", 2.4, 3, 2.2, 0.4, 0.4, 1.8, "bark_g", "#6a4a30", "bark_g"],
		["tb", 4.6, 3, 2.6, 0.4, 0.4, 1.4, "bark_g", "#6a4a30", "bark_g"], ["can", 3.5, 3, 3.8, 7, 5, 0.6, "#7a8e38"],
		["can", 3.2, 3, 4.3, 5, 3.6, 0.5, "#889c40"], ["can", 3.6, 3, 4.7, 3, 2.2, 0.4, "#96aa4a"]]],
	"f_baobab": [5, 5, [["tb", 2.5, 2.5, 0, 2.2, 2.2, 4.2, "bark_g", "#9a8a74", "bark_g"],
		["tb", 1.2, 2.5, 3.8, 1.6, 0.5, 0.5, "bark_g", "#9a8a74", "bark_g"],
		["tb", 3.8, 2.5, 4, 1.6, 0.5, 0.5, "bark_g", "#9a8a74", "bark_g"], ["can", 2.5, 2.5, 4.3, 4.8, 4.2, 0.8, "#6a8a3a"],
		["can", 2.5, 2.5, 5.1, 2.6, 2.4, 0.5, "#76963f"]]],
	"f_kapok": [9, 8, [["tb", 4.5, 4, 0, 2.2, 2.2, 1.2, "bark_g", "#8a7a64", "bark_g"], ["trk", 4.5, 4, 7.6, 1, "#8a7a64"],
		["can", 4.5, 4, 7.4, 9, 7.6, 1.2, "#2e8040"], ["can", 4.5, 4, 8.6, 6.4, 5.4, 0.9, "#3a9048"],
		["can", 4.2, 4, 9.5, 3.6, 3, 0.6, "#46a050"], ["can", 4.5, 4, 4.4, 4.4, 3.6, 0.8, "#2a7438"]]],
	"f_cypress": [4, 4, [["tb", 2, 2, 0, 1.8, 1.8, 1.2, "bark_g", "#6a5a44", "bark_g"], ["trk", 2, 2, 3.4, 0.8, "#6a5a44"],
		["can", 2, 2, 2.8, 3.4, 3.4, 2.2, "#4a6a3a"], ["can", 2, 2, 4.8, 2.6, 2.6, 2.2, "#52743f"],
		["can", 2, 2, 6.8, 1.6, 1.6, 1.6, "#5a7e44"], ["can", 2, 2, 8.2, 0.8, 0.8, 0.8, "#628848"]]],
	"f_mangrove": [6, 6, [["tb", 1.4, 1.4, 0, 0.4, 0.4, 1.8, "bark_g", "#5a4a3a", "bark_g"],
		["tb", 4.6, 1.4, 0, 0.4, 0.4, 1.8, "bark_g", "#5a4a3a", "bark_g"],
		["tb", 1.4, 4.6, 0, 0.4, 0.4, 1.8, "bark_g", "#5a4a3a", "bark_g"],
		["tb", 4.6, 4.6, 0, 0.4, 0.4, 1.8, "bark_g", "#5a4a3a", "bark_g"],
		["tb", 3, 0.8, 0, 0.4, 0.4, 1.8, "bark_g", "#5a4a3a", "bark_g"],
		["tb", 3, 5.2, 0, 0.4, 0.4, 1.8, "bark_g", "#5a4a3a", "bark_g"],
		["tb", 3, 3, 1.4, 4, 4, 0.5, "bark_g", "#5a4a3a", "bark_g"], ["trk", 3, 3, 3.6, 0.8, "#5a4a3a"],
		["can", 3, 3, 3.4, 6, 5.6, 1.4, "#3e6a36"], ["can", 3, 3, 4.8, 4, 3.8, 1, "#46763c"],
		["can", 3, 3, 5.8, 2, 2, 0.5, "#4e8042"]]],
	"f_redwood": [5, 5, [["tb", 2.5, 2.5, 0, 1.6, 1.6, 1.4, "bark_g", "#8a4a32", "bark_g"],
		["trk", 2.5, 2.5, 9, 1.2, "#8a4a32"], ["can", 2.5, 2.5, 5.6, 4.6, 4.4, 2, "#2e5e34"],
		["can", 2.5, 2.5, 7.4, 3.8, 3.6, 2, "#346838"], ["can", 2.5, 2.5, 9.2, 2.8, 2.6, 1.8, "#3a723e"],
		["can", 2.5, 2.5, 10.8, 1.6, 1.6, 1.2, "#407a44"]]],
	"f_emergent": [7, 7, [["trk", 3.5, 3.5, 8, 0.6, "#c8c0b0"],
		["tb", 4.6, 3.5, 5.6, 2, 0.4, 0.4, "bark_g", "#c8c0b0", "bark_g"],
		["tb", 5.5, 3.5, 5.6, 0.4, 0.4, 1.6, "bark_g", "#c8c0b0", "bark_g"], ["can", 3.5, 3.5, 8, 7, 6, 0.8, "#3a8a3a"],
		["can", 3.3, 3.5, 8.7, 4.6, 4, 0.6, "#46983e"], ["can", 5.5, 3.5, 7.1, 2.6, 2.4, 0.6, "#3a8a3a"]]],
	"f_mushroom": [4, 4, [["tb", 2, 2, 0, 1, 1, 3.4, "plain_white", "#e8dcc8"], ["can", 2, 2, 3.4, 4, 4, 0.9, "#c04a8a"],
		["can", 2, 2, 4.3, 2.8, 2.8, 0.6, "#d85aa0"], ["tb", 0.8, 3.2, 0, 0.5, 0.5, 1, "plain_white", "#e8dcc8"],
		["can", 0.8, 3.2, 1, 1.4, 1.4, 0.4, "#d85aa0"]]],
}

static func ids() -> Array[String]:
	return TREES.duplicate()

static func conifer(wd: float, ht: float, t0: int, cols: Array, tc: String = "#5e4430", snow: bool = false) -> PixelModel:
	var tiers: int = maxi(2, t0 + int(MapRng.jround(KH.vv(-1.0, 1.4))))
	var tp: float = KH.vv(0.52, 0.72)
	var c: float = wd / 2.0
	var base: float = ht * KH.vv(0.08, 0.18)
	var o: Array[PixelPart] = [KH.trk(c, c, base + 0.6, maxf(0.6, wd * 0.16), tc)]
	var step: float = (ht - base) / float(tiers)
	var th: float = step * KH.vv(1.3, 1.6)
	for i: int in tiers:
		var w: float = wd * (1.0 - tp * float(i) / float(tiers)) * KH.vv(0.92, 1.06)
		var y: float = base + step * float(i) * 0.92
		o.append(KH.pyr(c, c, y, w, th, cols[mini(cols.size() - 1, i)]))
		if snow:
			o.append(KH.pyr(c, c, y + th * 0.5, w * 0.54, th * 0.52, "#eef2f4"))
	return KH.model(wd, wd, o, true)

static func broad(wd: float, ht: float, cols: Array, tc: String = "#6e5032", tr: float = 0.34) -> PixelModel:
	var c: float = wd / 2.0
	var y0: float = ht * tr * KH.vv(0.85, 1.15)
	var ch: float = ht - y0
	var o: Array[PixelPart] = [KH.trk(c, c, y0 + ch * 0.2, maxf(0.6, wd * 0.14), tc),
		KH.can(c, c, y0, wd * 0.78, wd * 0.78, ch * 0.3, cols[0])]
	var a: float = wd * KH.vv(0.9, 1.0)
	var b: float = wd * KH.vv(0.86, 0.98)
	o.append(KH.can(c, c, y0 + ch * 0.22, a, b, ch * 0.42, cols[1]))
	a = c + KH.vv(-0.1, 0.1) * wd
	b = wd * KH.vv(0.6, 0.78)
	o.append(KH.can(a, c, y0 + ch * 0.6, b, wd * 0.66, ch * 0.28, cols[2]))
	a = c + KH.vv(-0.16, 0.12) * wd
	o.append(KH.can(a, c, y0 + ch * 0.85, wd * 0.38, wd * 0.36, ch * 0.15, cols[3]))
	var lobes: int = int(floor(KH.vv(0.0, 3.0)))
	for k: int in lobes:
		a = KH.vv(0.0, 6.283)
		var r: float = wd * 0.36
		var yy: float = y0 + ch * KH.vv(0.2, 0.5)
		o.append(KH.can(c + cos(a) * r, c + sin(a) * r * 0.8, yy, wd * 0.42, wd * 0.4, ch * 0.32, cols[1]))
	return KH.model(wd, wd, o, true)

static func droop(wd: float, ht: float, cols: Array, tc: String) -> PixelModel:
	var c: float = wd / 2.0
	var o: Array[PixelPart] = [KH.trk(c, c, ht * 0.55, maxf(0.6, wd * 0.12), tc),
		KH.can(c, c, ht * 0.48, wd * 0.92, wd * 0.92, ht * 0.28, cols[1]),
		KH.can(c, c, ht * 0.74, wd * 0.62, wd * 0.6, ht * 0.2, cols[2])]
	var ns: int = 6 + int(floor(KH.vv(0.0, 5.0)))
	var a0: float = KH.vv(0.0, 1.0)
	for k: int in ns:
		var a: float = float(k) * 6.283 / float(ns) + a0
		var r: float = wd * KH.vv(0.32, 0.42)
		var h: float = ht * KH.vv(0.24, 0.48)
		o.append(KH.can(c + cos(a) * r, c + sin(a) * r, ht * 0.5 - h + 0.2, 0.7, 0.7, h, cols[0]))
	return KH.model(wd, wd, o, true)

static func palm(l0: float, h0: float) -> PixelModel:
	var ln: float = l0 + KH.vv(-0.22, 0.22)
	var ht: float = h0 * KH.vv(0.85, 1.2)
	var x: float = 3.0
	var seg: float = ht / 3.0
	var o: Array[PixelPart] = []
	for i: int in 3:
		o.append(KH.tb(x, 3.0, seg * float(i), 0.6 - i * 0.05, 0.6 - i * 0.05, seg, "bark_g", "#9a7a52", "bark_g"))
		x += ln
	o.append_array([KH.can(x, 3.0, ht, 6.0, 1.0, 0.35, "#4e9a40"), KH.can(x, 3.0, ht, 1.0, 6.0, 0.35, "#4e9a40"),
		KH.can(x, 3.0, ht + 0.3, 1.6, 1.6, 0.6, "#5aa848"),
		KH.tb(x + 0.5, 3.4, ht - 0.4, 0.5, 0.5, 0.4, "plain_white", "#6a4a2a", "plain_white")])
	for dd: Vector2 in [Vector2(-2.8, 0.0), Vector2(2.8, 0.0), Vector2(0.0, -2.8), Vector2(0.0, 2.8)]:
		o.append(KH.can(x + dd.x, 3.0 + dd.y, ht - 0.6, 0.9, 0.9, 0.6, "#468e3a"))
	return KH.model(6.0, 6.0, o, true)

static func dead(c: String) -> PixelModel:
	var ht: float = KH.vv(5.0, 7.5)
	var o: Array[PixelPart] = [KH.trk(2.5, 2.5, ht, 0.7, c)]
	var n: int = 2 + int(floor(KH.vv(0.0, 3.0)))
	for k: int in n:
		var sd: float = 1.0 if (k & 1) == 1 else -1.0
		var y: float = ht * KH.vv(0.45, 0.85)
		var ln: float = KH.vv(1.2, 2.0)
		var ax: bool = k > 1 and KH.vr() > 0.5
		if ax:
			o.append(KH.tb(2.5, 2.5 + sd * ln / 2.0, y, 0.4, ln, 0.4, "bark_g", c, "bark_g"))
			o.append(KH.tb(2.5, 2.5 + sd * ln, y, 0.4, 0.4, KH.vv(0.8, 1.6), "bark_g", c, "bark_g"))
		else:
			o.append(KH.tb(2.5 + sd * ln / 2.0, 2.5, y, ln, 0.4, 0.4, "bark_g", c, "bark_g"))
			o.append(KH.tb(2.5 + sd * ln, 2.5, y, 0.4, 0.4, KH.vv(0.8, 1.6), "bark_g", c, "bark_g"))
	return KH.model(5.0, 5.0, o, true)

#varyTree in place: height step by v, drawn width and lean, crown parts jittered.
static func vary_tree(m: PixelModel, v: int) -> void:
	var hs: float = [0.82, 0.92, 1.0, 1.1, 1.24][v % 5]
	var ws: float = KH.vv(0.86, 1.14)
	var ln: float = KH.vv(-0.1, 0.1)
	var cx: float = m.W / 2.0
	var cz: float = m.D / 2.0
	var top: float = 0.0
	for p: PixelPart in m.parts:
		top = maxf(top, p.y + p.h)
	for p: PixelPart in m.parts:
		var y: float = p.y
		p.y = y * hs
		p.h = p.h * hs
		p.x = cx + (p.x - cx) * ws + ln * y
		p.z = cz + (p.z - cz) * ws
		p.w = p.w * ws
		p.d = p.d * ws
		if y > top * 0.3:
			p.x += KH.vv(-1.0, 1.0) * 0.06 * m.W
			p.z += KH.vv(-1.0, 1.0) * 0.06 * m.D
			p.w *= KH.vv(0.9, 1.1)
			p.d *= KH.vv(0.9, 1.1)
	m.W = m.W * ws
	m.D = m.D * ws

static func build(id: String) -> PixelModel:
	match id:
		"f_pine": return conifer(5.0, 10.0, 4, ["#24503a", "#2a5a40", "#2f6446", "#356e4c"])
		"f_fir": return conifer(6.0, 9.0, 3, ["#24564a", "#2a6050", "#306a58"])
		"f_spruce": return conifer(4.0, 11.0, 5, ["#1e4636", "#224c3a", "#26523e", "#2a5842", "#2e5e46"])
		"f_snowpine": return conifer(5.0, 10.0, 4, ["#2a5246", "#2e584a", "#325e4e", "#36644f"], "#5e4430", true)
		"f_snowfir": return conifer(6.0, 9.0, 3, ["#2e5a50", "#325e54", "#366458"], "#5e4430", true)
		"f_juniper": return conifer(3.0, 5.0, 3, ["#44643e", "#4a6a44", "#52724a"])
		"f_violetfir": return conifer(5.0, 9.0, 4, ["#5a3e7a", "#644688", "#6e4e94", "#7a58a2"], "#4a3a4a")
		"f_shadepine":
			return conifer(5.0, 14.0, 6, ["#16241f", "#1a2a24", "#1e2f28", "#22342c", "#263830", "#2a3c34"], "#2a2020")
		"f_oak": return broad(6.0, 8.0, ["#4a8a36", "#55963e", "#60a246", "#6cae50"])
		"f_beech": return broad(7.0, 9.0, ["#336e2e", "#3a7a34", "#42843a", "#4c9042"])
		"f_maple": return broad(6.0, 8.0, ["#b0602e", "#c0703a", "#d08440", "#e09a4a"])
		"f_birch": return broad(4.0, 8.0, ["#7ab04e", "#86bc58", "#94c862", "#a0d06c"], "#e8e4d8", 0.45)
		"f_cherry": return broad(6.0, 7.0, ["#e090ac", "#eaa6be", "#f4bcd0", "#fcd6e4"], "#4a3434", 0.38)
		"f_jacaranda": return broad(7.0, 8.0, ["#6a4cae", "#7a5abe", "#8c6cce", "#a488dc"], "#4a3a3a", 0.4)
		"f_wisteria": return droop(7.0, 7.0, ["#7a52b0", "#9068c4", "#a884d6"], "#4a3a4a")
		"f_wisteria_w": return droop(7.0, 7.0, ["#cfcae2", "#e2def0", "#f4f2fa"], "#4a3a4a")
		"f_willow": return droop(8.0, 8.0, ["#6e9a3c", "#7caa46", "#8aba50"], "#5e4a34")
		"f_palm": return palm(0.3, 7.0)
		"f_palm2": return palm(-0.35, 6.0)
		"f_dead": return dead("#7a7068")
		"f_jungle":
			var m: PixelModel = broad(7.0, 10.0, ["#226a32", "#2a7a3a", "#32883e", "#3a9646"], "#5a4430", 0.32)
			m.parts.append_array([KH.can(1.2, 1.4, 0.0, 2.0, 2.0, 1.2, "#3a9040"),
				KH.can(5.8, 5.4, 0.0, 1.6, 1.6, 0.9, "#2e8438")])
			return m
		"f_deadc":
			var m: PixelModel = dead("#3a3038")
			m.parts.append_array([KH.can(0.8, 2.5, 5.2, 0.5, 0.5, 0.4, "#9a5ac0"),
				KH.can(4.2, 2.5, 6.2, 0.5, 0.5, 0.4, "#9a5ac0")])
			return m
	return KH.from_rows(STATIC[id], true)
