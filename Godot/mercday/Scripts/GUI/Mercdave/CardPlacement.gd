class_name CardPlacement

#Where the MercDave card opens: beside the box of the open frame (right, then left) when it fits
#without covering the box. Free placement first tries beside the current target (right, left, below,
#above; DOCK_W wide, DOCK_GAP away, inside the band, never over the target, skipped when it covers more
#than HEAVY_COVER of another marked box), then the six spots; every candidate is scored by cover plus
#its gap to the target divided by NEAR_UNIT, lowest wins, ties keep the earlier candidate. A target below
#the band (a bottom bar item) gets the card's bottom on the band's bottom edge (the bar top), its left
#edge on the target, whatever that covers. Only the free placements keep the MIN_H reserve.

const DOCK_W: float = 344.0
const FREE_W: float = 384.0
const DOCK_GAP: float = 16.0
const MIN_H: float = 158.0
const CURRENT_WEIGHT: float = 3.0
const CONTROL_COST: float = 0.5
const NEAR_UNIT: float = 150.0
const HEAVY_COVER: float = 0.5
const SPOTS: Array[Vector2] = [Vector2(880, 474), Vector2(16, 474), Vector2(880, 16), Vector2(16, 16),
	Vector2(448, 474), Vector2(448, 16)]


static func band(view: Vector2) -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(view.x, GuiFrameStack.band_height(view.y)))


#The box a card docks beside: the panel of a GuiModal, the rect of another frame, empty for the HUD.
static func box_of(root: Control) -> Rect2:
	if root == null:
		return Rect2()
	if root is GuiModal:
		return (root as GuiModal).panel_rect()
	return root.get_global_rect()


#The card rect. marks are the rects of the marked targets; current indexes the shown one (-1: none).
static func place(card_h: float, box: Rect2, marks: Array[Rect2], current: int, controls: Array[Rect2],
		area: Rect2) -> Rect2:
	if box.has_area():
		var wanted: Vector2 = Vector2(DOCK_W, card_h)
		var gap: float = DOCK_GAP - TooltipPanel.GAP
		var docked: Rect2 = Rect2(TooltipPanel.tip_position(box.grow_individual(gap, 0.0, gap, 0.0), wanted,
			area, &"right"), wanted)
		if not docked.intersects(box):
			return clamp_top(docked, area)
	var current_rect: Rect2 = marks[current] if 0 <= current and current < marks.size() else Rect2()
	if current_rect.has_area() and current_rect.position.y >= area.end.y:
		return above_bar(current_rect, card_h, area)
	var options: Array[Rect2] = []
	if current_rect.has_area():
		for rect: Rect2 in beside(current_rect, card_h, area):
			if not heavy(rect, marks, current):
				options.append(rect)
	for spot: Vector2 in SPOTS:
		options.append(Rect2(spot, Vector2(FREE_W, card_h)))
	var best: Rect2 = options[0]
	var best_score: float = INF
	for rect: Rect2 in options:
		var value: float = score(rect, marks, current, controls) + gap(rect, current_rect) / NEAR_UNIT
		if value < best_score - 0.01:
			best = rect
			best_score = value
	return clamp_top(best, area)


#The rects beside target, DOCK_GAP from it after the top clamp, that fit the band: right, left, below, above.
static func beside(target: Rect2, card_h: float, area: Rect2) -> Array[Rect2]:
	var size: Vector2 = Vector2(DOCK_W, card_h)
	var tries: Array[Rect2] = [Rect2(Vector2(target.end.x + DOCK_GAP, target.position.y), size),
		Rect2(Vector2(target.position.x - DOCK_GAP - size.x, target.position.y), size),
		Rect2(Vector2(target.position.x, target.end.y + DOCK_GAP), size),
		Rect2(Vector2(target.position.x, target.position.y - DOCK_GAP - size.y), size)]
	var out: Array[Rect2] = []
	for i: int in tries.size():
		var rect: Rect2 = tries[i]
		if i < 2:
			rect.position.y = clampf(rect.position.y, area.position.y, area.end.y - size.y)
		else:
			rect.position.x = clampf(rect.position.x, area.position.x, area.end.x - size.x)
		rect = clamp_top(rect, area)
		if area.encloses(rect) and not rect.intersects(target) and gap(rect, target) <= DOCK_GAP + 0.5:
			out.append(rect)
	return out


#A target below the band (a bottom bar item): the card sits on the band's bottom edge, its left edge on the
#target, moved left only as far as the band needs; the real card height, no MIN_H reserve.
static func above_bar(target: Rect2, card_h: float, area: Rect2) -> Rect2:
	var size: Vector2 = Vector2(DOCK_W, card_h)
	var x: float = clampf(target.position.x, area.position.x, area.end.x - size.x)
	var top: float = maxf(area.position.y, area.end.y - card_h)
	return Rect2(Vector2(x, top), size)


#The shortest distance between two rects; 0 when they touch, overlap or target has no area.
static func gap(card: Rect2, target: Rect2) -> float:
	if not target.has_area():
		return 0.0
	var dx: float = maxf(0.0, maxf(target.position.x - card.end.x, card.position.x - target.end.x))
	var dy: float = maxf(0.0, maxf(target.position.y - card.end.y, card.position.y - target.end.y))
	return Vector2(dx, dy).length()


#The covered share of each marked target (the current one weighs 3) plus 0.5 per covered control.
static func score(card: Rect2, marks: Array[Rect2], current: int, controls: Array[Rect2]) -> float:
	var total: float = 0.0
	for i: int in marks.size():
		var mark: Rect2 = marks[i]
		if mark.has_area():
			var share: float = card.intersection(mark).get_area() / mark.get_area()
			total += share * (CURRENT_WEIGHT if i == current else 1.0)
	for rect: Rect2 in controls:
		if card.intersects(rect):
			total += CONTROL_COST
	return total


#True when card covers more than HEAVY_COVER of any marked box other than the current one.
static func heavy(card: Rect2, marks: Array[Rect2], current: int) -> bool:
	for i: int in marks.size():
		var mark: Rect2 = marks[i]
		if i != current and mark.has_area() and card.intersection(mark).get_area() / mark.get_area() > HEAVY_COVER:
			return true
	return false


static func clamp_top(card: Rect2, area: Rect2) -> Rect2:
	var out: Rect2 = card
	out.position.y = maxf(area.position.y, minf(out.position.y, area.end.y - maxf(MIN_H, out.size.y)))
	return out
