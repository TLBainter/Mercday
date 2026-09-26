class_name CityStreets

#Side streets and alleys of one city block. Every street is walked as a candidate list, checked whole and
#painted only when it is accepted, so nothing is ever unpainted. All geometry is heading relative.

const SIDE_W := Vector2i(2, 4)
const ALLEY_W := Vector2i(1, 2)
const SIDE_SEG := Vector2i(5, 12)
const ALLEY_SEG := Vector2i(3, 7)
const SIDE_BAND := 8
const ALLEY_BAND := 6
const SIDE_OPS: Array[int] = [50, 25, 25]
const ALLEY_OPS: Array[int] = [25, 50, 25]
const SIDE_DEAD_END := 30
const ALLEY_DEAD_END := 40
const SIDE_BUDGET := Vector2i(12, 30)
const ALLEY_BUDGET := Vector2i(6, 16)
const SIDE_MOUTH_GAP := 12
const ALLEY_MOUTH_GAP := 6
const ALLEY_PER := 800
const ALLEY_MAX := 6
const STREET_TRIES := 8
const MAX_SEGMENTS := 40
const JOG := Vector2i(1, 3)
const SIDE_CFG: Dictionary = {"kind": "side", "w": SIDE_W, "seg": SIDE_SEG, "band": SIDE_BAND,
	"pad": SIDE_BAND + 1, "ops": SIDE_OPS, "dead_pct": SIDE_DEAD_END, "budget": SIDE_BUDGET,
	"min_path": 5}
const ALLEY_CFG: Dictionary = {"kind": "alley", "w": ALLEY_W, "seg": ALLEY_SEG, "band": ALLEY_BAND,
	"pad": ALLEY_BAND, "ops": ALLEY_OPS, "dead_pct": ALLEY_DEAD_END, "budget": ALLEY_BUDGET,
	"min_path": 3}

const OP_JOG := 0
const OP_TURN := 1
const OP_CONT := 2
const OP_COUNT := 3
const PARAM_ROLLS := 4
const JUNCTION_ROWS := 3
const MOUTH_CUT := 2
#The mouth roll walks these in order, so the order is part of the roll contract.
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


#Lays the side streets of one block, then its alleys. Appends to area.city["streets"] and paints through CityGrid.
static func build(area: BattlefieldArea, block: Dictionary) -> void:
	if area == null or block.is_empty() or not area.city.has("streets"):
		return
	var rect: Rect2i = block.get("rect", Rect2i())
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var mains: Array = block.get("main_sides", [])
	var m: int = mini(rect.size.x, rect.size.y)
	var cells: int = rect.size.x * rect.size.y
	var n_side: int = 0
	if m >= 20 and not mains.is_empty():
		n_side = 1
		if cells >= 2400:
			n_side += 1
		if cells >= 4000:
			n_side += 1
	var n_alley: int = 0
	if m >= 10:
		var extra: int = int(cells / float(ALLEY_PER))
		n_alley = clampi(1 + extra, 1, ALLEY_MAX)
	var taken: Dictionary = {}
	for _i: int in range(n_side):
		_try_street(area, block, SIDE_CFG, taken)
	for _j: int in range(n_alley):
		_try_street(area, block, ALLEY_CFG, taken)


static func _try_street(area: BattlefieldArea, block: Dictionary, cfg: Dictionary, taken: Dictionary) -> void:
	for _t: int in range(STREET_TRIES):
		var start: Dictionary = _roll_mouth(area, block, cfg, taken)
		if start.is_empty():
			continue
		var st: Dictionary = _walk(area, block, cfg, start)
		if st.is_empty():
			continue
		var recs: Array[Dictionary] = _records(cfg, st)
		if _meets_dead_end(area, cfg, recs):
			continue
		if bool(st["dead_end"]) and not _dead_zone_clear(area, recs):
			continue
		_commit(area, block, cfg, st, recs, taken)
		return


#### Geometry helpers. "along" runs with the heading, "lat" across it; both are map coordinates.


static func _sign(h: Vector2i) -> int:
	return 1 if (h.x + h.y) > 0 else -1


static func _axis(h: Vector2i) -> String:
	return "x" if h.x != 0 else "y"


static func _cross_axis(h: Vector2i) -> String:
	return "y" if h.x != 0 else "x"


static func _cell(h: Vector2i, along: int, lat: int) -> Vector2i:
	return Vector2i(along, lat) if h.x != 0 else Vector2i(lat, along)


#The carriage rect of a run that starts at `along` and reaches `ln` cells along h, `w` wide from `lat`.
static func _rect_of(h: Vector2i, along: int, ln: int, lat: int, w: int) -> Rect2i:
	var lo: int = along if _sign(h) > 0 else along - ln + 1
	if h.x != 0:
		return Rect2i(lo, lat, ln, w)
	return Rect2i(lat, lo, w, ln)


static func _turn_head(h: Vector2i, d: int) -> Vector2i:
	return Vector2i(0, d) if h.x != 0 else Vector2i(d, 0)


static func _rot(h: Vector2i, d: int) -> int:
	var h2: Vector2i = _turn_head(h, d)
	return h.x * h2.y - h.y * h2.x


#Cells from `along` to one past the block edge along h, so a walk of this length always makes contact.
static func _max_len(block: Rect2i, h: Vector2i, along: int) -> int:
	if h == Vector2i(1, 0):
		return block.end.x - along + 1
	if h == Vector2i(-1, 0):
		return along - block.position.x + 2
	if h == Vector2i(0, 1):
		return block.end.y - along + 1
	return along - block.position.y + 2


static func _seg(h: Vector2i, along: int, ln: int, lat: int, w: int, cross: bool) -> Dictionary:
	return {"h": h, "along": along, "len": ln, "lat": lat, "w": w,
		"axis": _cross_axis(h) if cross else _axis(h), "width": ln if cross else w}


#### Cell tests.


#What stops a walk at one along row: "border", "street", "bad" or "" when the row is free block ground.
static func _row_state(area: BattlefieldArea, block: Rect2i, h: Vector2i, along: int, l0: int, l1: int) -> String:
	var border: bool = false
	var street: bool = false
	var bad: bool = false
	for l: int in range(l0, l1 + 1):
		var c: Vector2i = _cell(h, along, l)
		if not CityGrid.inside(area, c.x, c.y):
			border = true
			continue
		if not block.has_point(c):
			street = true
			continue
		var sf: int = CityGrid.surf(area, c.x, c.y)
		if sf == BattlefieldArea.SURF_NONE:
			continue
		if CityGrid.is_street(sf):
			street = true
		else:
			bad = true
	if border:
		return "border"
	if street:
		return "street"
	if bad:
		return "bad"
	return ""


static func _band_clear(area: BattlefieldArea, block: Rect2i, h: Vector2i, along: int, l0: int, l1: int) -> bool:
	for l: int in range(l0, l1 + 1):
		var c: Vector2i = _cell(h, along, l)
		if not block.has_point(c):
			return false
		if CityGrid.surf(area, c.x, c.y) != BattlefieldArea.SURF_NONE:
			return false
	return true


#Rows of clear block ground a dead end needs past its last cell.
static func _ahead_clear(area: BattlefieldArea, block: Rect2i, cfg: Dictionary, seg: Dictionary) -> bool:
	var h: Vector2i = seg["h"]
	var s: int = _sign(h)
	var lat: int = int(seg["lat"])
	var w: int = int(seg["w"])
	var ae: int = int(seg["along"]) + (int(seg["len"]) - 1) * s
	for k: int in range(1, int(cfg["band"]) + 1):
		if not _band_clear(area, block, h, ae + k * s, lat - CityValidator.DEAD_GROW,
				lat + w - 1 + CityValidator.DEAD_GROW):
			return false
	return true


#Rows to extend the last segment over so it reaches a carriageway; -1 when the junction is not usable.
static func _junction(area: BattlefieldArea, _block: Rect2i, cfg: Dictionary, h: Vector2i,
		ae: int, lat: int, w: int) -> int:
	var s: int = _sign(h)
	if String(cfg["kind"]) == "alley":
		for l: int in range(lat, lat + w):
			var c: Vector2i = _cell(h, ae + s, l)
			var sf: int = CityGrid.surf(area, c.x, c.y)
			if sf != BattlefieldArea.SURF_SIDEWALK and sf != BattlefieldArea.SURF_ALLEY:
				return -1
		for l2: int in [lat - 1, lat + w]:
			var c2: Vector2i = _cell(h, ae + s, l2)
			if CityGrid.is_carriage(CityGrid.surf(area, c2.x, c2.y)):
				return -1
		return 0
	for k: int in range(1, JUNCTION_ROWS + 1):
		var carriage: int = 0
		for l3: int in range(lat, lat + w):
			var c3: Vector2i = _cell(h, ae + k * s, l3)
			var sf3: int = CityGrid.surf(area, c3.x, c3.y)
			if not CityGrid.is_street(sf3):
				return -1
			if CityGrid.is_carriage(sf3):
				carriage += 1
		if carriage == w:
			return k - 1
		if carriage > 0:
			return -1
	return -1


#### Candidate placement.


#Walks one candidate run: {"ok", "len", "hit", "cut"} and "blocked" when the very first row was stopped.
static func _place(area: BattlefieldArea, block: Rect2i, cfg: Dictionary, h: Vector2i,
		along: int, want: int, lat: int, w: int) -> Dictionary:
	var s: int = _sign(h)
	var hit: String = ""
	var used: int = 0
	for i: int in range(want):
		var st: String = _row_state(area, block, h, along + i * s, lat - 1, lat + w)
		if st != "":
			hit = st
			break
		used += 1
	if used == 0:
		return {"ok": false, "blocked": true, "len": 0, "hit": hit, "cut": 0}
	if hit == "bad":
		return {"ok": false, "blocked": false, "len": 0, "hit": hit, "cut": 0}
	var pad: int = int(cfg["pad"])
	for i2: int in range(used):
		if not _band_clear(area, block, h, along + i2 * s, lat - pad, lat + w - 1 + pad):
			return {"ok": false, "blocked": false, "len": 0, "hit": "band", "cut": 0}
	var cut: int = 0
	if hit == "street":
		cut = _junction(area, block, cfg, h, along + (used - 1) * s, lat, w)
		if cut < 0:
			return {"ok": false, "blocked": false, "len": 0, "hit": "junction", "cut": 0}
	return {"ok": true, "blocked": false, "len": used, "hit": hit, "cut": cut}


#One op at a segment end: {"segs", "turn", "end", "cut"} or {} when the op does not fit here.
static func _try_op(area: BattlefieldArea, block: Rect2i, cfg: Dictionary, prev: Dictionary,
		op: int, last_turn: int) -> Dictionary:
	var h: Vector2i = prev["h"]
	var s: int = _sign(h)
	var lat: int = int(prev["lat"])
	var w: int = int(prev["w"])
	var ln: int = int(prev["len"])
	var ae: int = int(prev["along"]) + (ln - 1) * s
	var wr: Vector2i = cfg["w"]
	var sr: Vector2i = cfg["seg"]
	for _r: int in range(PARAM_ROLLS):
		if op == OP_CONT:
			var cw2: int = randi_range(wr.x, wr.y)
			var clat: int = lat if randi_range(0, 1) == 0 else lat + w - cw2
			var clen: int = randi_range(sr.x, sr.y)
			var cres: Dictionary = _place(area, block, cfg, h, ae + s, clen, clat, cw2)
			if bool(cres["ok"]):
				return {"segs": [_seg(h, ae + s, int(cres["len"]), clat, cw2, false)], "turn": last_turn,
					"end": "through" if String(cres["hit"]) != "" else "", "cut": int(cres["cut"])}
			if bool(cres["blocked"]):
				var reason: String = String(cres["hit"])
				if reason == "border":
					return {"segs": [], "turn": last_turn, "end": "through", "cut": 0}
				if reason == "street":
					var jc: int = _junction(area, block, cfg, h, ae, lat, w)
					if jc >= 0:
						return {"segs": [], "turn": last_turn, "end": "through", "cut": jc}
		elif op == OP_TURN:
			var d: int = 1 if randi_range(0, 1) == 0 else -1
			if last_turn != 0 and _rot(h, d) == last_turn:
				d = -d
			var rot: int = _rot(h, d)
			var h2: Vector2i = _turn_head(h, d)
			var tw: int = mini(randi_range(wr.x, wr.y), ln)
			if tw < wr.x:
				continue
			var tlen: int = randi_range(sr.x, sr.y)
			var tlat: int = (ae - tw + 1) if s > 0 else ae
			var talong: int = lat + w if d > 0 else lat - 1
			var tres: Dictionary = _place(area, block, cfg, h2, talong, tlen, tlat, tw)
			if bool(tres["ok"]):
				return {"segs": [_seg(h2, talong, int(tres["len"]), tlat, tw, false)], "turn": rot,
					"end": "through" if String(tres["hit"]) != "" else "", "cut": int(tres["cut"])}
		else:
			var shift: int = randi_range(JOG.x, JOG.y) * (1 if randi_range(0, 1) == 0 else -1)
			var jw: int = randi_range(wr.x, wr.y)
			var conn: int = randi_range(wr.x, wr.y)
			var ulo: int = mini(lat, lat + shift)
			var uhi: int = maxi(lat + w - 1, lat + shift + jw - 1)
			var kres: Dictionary = _place(area, block, cfg, h, ae + s, conn, ulo, uhi - ulo + 1)
			if not bool(kres["ok"]) or int(kres["len"]) != conn or String(kres["hit"]) != "":
				continue
			var jalong: int = ae + (conn + 1) * s
			var jres: Dictionary = _place(area, block, cfg, h, jalong, randi_range(sr.x, sr.y), lat + shift, jw)
			if not bool(jres["ok"]):
				continue
			return {"segs": [_seg(h, ae + s, conn, ulo, uhi - ulo + 1, true),
					_seg(h, jalong, int(jres["len"]), lat + shift, jw, false)], "turn": last_turn,
				"end": "through" if String(jres["hit"]) != "" else "", "cut": int(jres["cut"])}
	return {}


static func _roll_op(ops: Array) -> int:
	var total: int = 0
	for v: int in ops:
		total += v
	var r: int = int(randi() % maxi(total, 1))
	var acc: int = 0
	for i: int in range(ops.size()):
		acc += int(ops[i])
		if r < acc:
			return i
	return ops.size() - 1


#The rolled op first, then the other two in a rolled order.
static func _step(area: BattlefieldArea, block: Rect2i, cfg: Dictionary, prev: Dictionary,
		last_turn: int) -> Dictionary:
	var first: int = _roll_op(cfg["ops"])
	var rest: Array[int] = []
	for o: int in range(OP_COUNT):
		if o != first:
			rest.append(o)
	if randi_range(0, 1) == 1:
		rest.reverse()
	var order: Array[int] = [first]
	order.append_array(rest)
	for op: int in order:
		var res: Dictionary = _try_op(area, block, cfg, prev, op, last_turn)
		if not res.is_empty():
			return res
	return {}


#### Mouths.


static func _roll_mouth(area: BattlefieldArea, block: Dictionary, cfg: Dictionary, taken: Dictionary) -> Dictionary:
	if String(cfg["kind"]) == "side":
		return _roll_mouth_side(block, taken)
	return _roll_mouth_alley(area, block, taken)


static func _into(side: String) -> Vector2i:
	match side:
		"N":
			return Vector2i(0, 1)
		"S":
			return Vector2i(0, -1)
		"W":
			return Vector2i(1, 0)
	return Vector2i(-1, 0)


static func _entry_along(rect: Rect2i, side: String) -> int:
	match side:
		"N":
			return rect.position.y
		"S":
			return rect.end.y - 1
		"W":
			return rect.position.x
	return rect.end.x - 1


static func _roll_mouth_side(block: Dictionary, taken: Dictionary) -> Dictionary:
	var mains: Array = block.get("main_sides", [])
	if mains.is_empty():
		return {}
	var rect: Rect2i = block["rect"]
	var side: String = String(mains[randi_range(0, mains.size() - 1)])
	var h: Vector2i = _into(side)
	var lat_lo: int = rect.position.y if h.x != 0 else rect.position.x
	var lat_hi: int = rect.end.y if h.x != 0 else rect.end.x
	var w: int = randi_range(SIDE_W.x, SIDE_W.y)
	var lo: int = lat_lo + SIDE_MOUTH_GAP
	var hi: int = lat_hi - SIDE_MOUTH_GAP - w
	if hi < lo:
		return {}
	var used: Array = taken.get(side, [])
	var picks: Array[int] = []
	for l: int in range(lo, hi + 1):
		var spaced: bool = true
		for u: Vector2i in used:
			if l - (u.x + u.y) < SIDE_MOUTH_GAP and u.x - (l + w) < SIDE_MOUTH_GAP:
				spaced = false
				break
		if spaced:
			picks.append(l)
	if picks.is_empty():
		return {}
	var lat: int = picks[randi_range(0, picks.size() - 1)]
	var along: int = _entry_along(rect, side)
	return {"h": h, "along": along, "lat": lat, "w": w, "mouth": _cell(h, along, lat), "side": side}


static func _roll_mouth_alley(area: BattlefieldArea, block: Dictionary, taken: Dictionary) -> Dictionary:
	var rect: Rect2i = block["rect"]
	var spots: Array[Vector3i] = []
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if CityGrid.surf(area, x, y) != BattlefieldArea.SURF_NONE:
				continue
			for d: int in range(DIRS.size()):
				var back: Vector2i = Vector2i(x, y) - DIRS[d]
				if CityGrid.surf(area, back.x, back.y) == BattlefieldArea.SURF_SIDEWALK:
					spots.append(Vector3i(x, y, d))
	if spots.is_empty():
		return {}
	var pick: Vector3i = spots[randi_range(0, spots.size() - 1)]
	var cell := Vector2i(pick.x, pick.y)
	for u: Vector2i in taken.get("alley", []):
		if maxi(absi(u.x - cell.x), absi(u.y - cell.y)) < ALLEY_MOUTH_GAP:
			return {}
	var h: Vector2i = DIRS[pick.z]
	var along: int = _along_of(h, cell)
	var lat: int = _lat_of(h, cell)
	var w: int = randi_range(ALLEY_W.x, ALLEY_W.y)
	if w == 2:
		var low: bool = randi_range(0, 1) == 0
		var other: int = lat - 1 if low else lat + 1
		var behind: Vector2i = _cell(h, along - _sign(h), other)
		if CityGrid.surf(area, behind.x, behind.y) != BattlefieldArea.SURF_SIDEWALK:
			return {}
		if low:
			lat -= 1
	return {"h": h, "along": along, "lat": lat, "w": w, "mouth": cell, "side": ""}


static func _along_of(h: Vector2i, c: Vector2i) -> int:
	return c.x if h.x != 0 else c.y


static func _lat_of(h: Vector2i, c: Vector2i) -> int:
	return c.y if h.x != 0 else c.x


#### The walk.


#One candidate street: {"segments", "dead_end", "mouth", "side", "lat", "w"} or {} when it is discarded.
static func _walk(area: BattlefieldArea, block: Dictionary, cfg: Dictionary, start: Dictionary) -> Dictionary:
	var rect: Rect2i = block["rect"]
	var srange: Vector2i = cfg["seg"]
	var brange: Vector2i = cfg["budget"]
	var dead: bool = randi_range(1, 100) <= int(cfg["dead_pct"])
	var limit: int = randi_range(brange.x, brange.y)
	var h: Vector2i = start["h"]
	var lat: int = int(start["lat"])
	var w: int = int(start["w"])
	var along: int = int(start["along"])
	var first: Dictionary = _place(area, rect, cfg, h, along, randi_range(srange.x, srange.y), lat, w)
	if not bool(first["ok"]):
		return {}
	var segs: Array[Dictionary] = [_seg(h, along, int(first["len"]), lat, w, false)]
	var path: int = int(first["len"])
	var cut: int = int(first["cut"])
	var through: bool = String(first["hit"]) != ""
	var last_turn: int = 0
	while not through:
		if dead and path >= limit:
			var fin: Dictionary = _close_dead(area, rect, cfg, segs, path, limit)
			if fin.is_empty():
				return {}
			path = int(fin["path"])
			cut = int(fin["cut"])
			if not bool(fin["dead"]):
				dead = false
				through = true
			break
		if segs.size() >= MAX_SEGMENTS - 1:
			return {}
		var step: Dictionary = _step(area, rect, cfg, segs[segs.size() - 1], last_turn)
		if step.is_empty():
			if not dead and String(cfg["kind"]) != "alley":
				return {}
			if not _ahead_clear(area, rect, cfg, segs[segs.size() - 1]):
				return {}
			dead = true
			cut = 0
			break
		last_turn = int(step["turn"])
		for sg: Dictionary in (step["segs"] as Array):
			segs.append(sg)
			path += int(sg["len"])
		cut = int(step["cut"])
		if String(step["end"]) == "through":
			through = true
	if path < int(cfg["min_path"]):
		return {}
	if cut > 0:
		var last: Dictionary = segs[segs.size() - 1]
		last["len"] = int(last["len"]) + cut
	return {"segments": segs, "dead_end": dead and not through, "mouth": start["mouth"],
		"side": String(start["side"]), "lat": lat, "w": w}


#Cuts the last segment to the budget, then ends the street as a dead end or runs it on to the next contact.
static func _close_dead(area: BattlefieldArea, block: Rect2i, cfg: Dictionary, segs: Array[Dictionary],
		path: int, limit: int) -> Dictionary:
	var last: Dictionary = segs[segs.size() - 1]
	var p: int = path
	var over: int = p - limit
	if over > 0:
		var shorter: int = maxi(2, int(last["len"]) - over)
		if shorter < int(last["len"]):
			p -= int(last["len"]) - shorter
			last["len"] = shorter
	if _ahead_clear(area, block, cfg, last):
		return {"dead": true, "path": p, "cut": 0}
	var h: Vector2i = last["h"]
	var a0: int = int(last["along"])
	var ext: Dictionary = _place(area, block, cfg, h, a0, _max_len(block, h, a0), int(last["lat"]), int(last["w"]))
	if not bool(ext["ok"]):
		return {}
	p += int(ext["len"]) - int(last["len"])
	last["len"] = int(ext["len"])
	return {"dead": false, "path": p, "cut": int(ext["cut"])}


#### Commit.


#The segment records of a walked street, with the mouth cut on the first segment of a side street.
static func _records(cfg: Dictionary, st: Dictionary) -> Array[Dictionary]:
	var kind: String = String(cfg["kind"])
	var segs: Array = st["segments"]
	var recs: Array[Dictionary] = []
	for i: int in range(segs.size()):
		var sg: Dictionary = segs[i]
		var h: Vector2i = sg["h"]
		var along: int = int(sg["along"])
		var ln: int = int(sg["len"])
		if i == 0 and kind == "side":
			along -= MOUTH_CUT * _sign(h)
			ln += MOUTH_CUT
		recs.append({"rect": _rect_of(h, along, ln, int(sg["lat"]), int(sg["w"])),
			"axis": String(sg["axis"]), "width": int(sg["width"])})
	return recs


#True when the street would touch the far end of an earlier dead end, which would then be one no longer.
static func _meets_dead_end(area: BattlefieldArea, cfg: Dictionary, recs: Array[Dictionary]) -> bool:
	var ring: int = 1 if String(cfg["kind"]) == "side" else 0
	for entry: Dictionary in (area.city["streets"] as Array):
		if not bool(entry.get("dead_end", false)):
			continue
		var segs: Array = entry["segments"]
		var zone: Rect2i = ((segs[segs.size() - 1] as Dictionary)["rect"] as Rect2i).grow(CityValidator.DEAD_GROW)
		var mouth: Rect2i = ((segs[0] as Dictionary)["rect"] as Rect2i).grow(CityValidator.MOUTH_GROW)
		for r: Dictionary in recs:
			var hit: Rect2i = zone.intersection((r["rect"] as Rect2i).grow(ring))
			if hit.has_area() and not mouth.encloses(hit):
				return true
	return false


#False when a committed street lies inside the far end zone of this dead end candidate.
static func _dead_zone_clear(area: BattlefieldArea, recs: Array[Dictionary]) -> bool:
	var zone: Rect2i = ((recs[recs.size() - 1]["rect"]) as Rect2i).grow(CityValidator.DEAD_GROW)
	var mouth: Rect2i = ((recs[0]["rect"]) as Rect2i).grow(CityValidator.MOUTH_GROW)
	zone = zone.intersection(Rect2i(0, 0, area.width, area.length))
	for y: int in range(zone.position.y, zone.end.y):
		for x: int in range(zone.position.x, zone.end.x):
			if mouth.has_point(Vector2i(x, y)):
				continue
			if CityGrid.street_id(area, x, y) >= 0:
				return false
	return true


static func _commit(area: BattlefieldArea, block: Dictionary, cfg: Dictionary, st: Dictionary,
		recs: Array[Dictionary], taken: Dictionary) -> void:
	var kind: String = String(cfg["kind"])
	var streets: Array = area.city["streets"]
	var id: int = streets.size()
	var surf: int = BattlefieldArea.SURF_SIDE if kind == "side" else BattlefieldArea.SURF_ALLEY
	for r: Dictionary in recs:
		CityGrid.paint_rect(area, r["rect"], surf, id)
	if kind == "side":
		for r2: Dictionary in recs:
			#Sidewalk on every cell within Chebyshev distance 1 of the rect that holds no street surface yet.
			CityGrid.paint_sidewalk_ring(area, r2["rect"], id)
	streets.append({
		"id": id,
		"kind": kind,
		"axis": String(recs[0]["axis"]),
		"dead_end": bool(st["dead_end"]),
		"block": int(block.get("id", -1)),
		"mouth": st["mouth"],
		"segments": recs,
	})
	if kind == "side":
		var side: String = String(st["side"])
		if not taken.has(side):
			taken[side] = []
		(taken[side] as Array).append(Vector2i(int(st["lat"]), int(st["w"])))
	else:
		if not taken.has("alley"):
			taken["alley"] = []
		(taken["alley"] as Array).append(st["mouth"])
