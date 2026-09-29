class_name FitStars extends Control

#Five 9x9 pixel stars showing a fit value from 0.5 to 5.0 in half steps.
#Star i is full at value >= i + 1, half (left five columns only) at value >= i + 0.5.
#The lit colour comes from the whole value, not per star; unlit pixels are always the same blue.

const STAR_COUNT: int = 5
const STAR_SIZE: int = 9
const UNLIT: Color = Color("#1f3560")
const FALLBACK: Color = Color("#f28c28")

const STAR_MAP: Array[String] = [
	"....#....",
	"...###...",
	"...###...",
	"#########",
	".#######.",
	"..#####..",
	"..#####..",
	".###.###.",
	".##...##.",
]

const COLOR_TABLE: Dictionary = {
	0.5: Color("#e8583f"),
	1.0: Color("#ec6a36"),
	1.5: Color("#ef7c2f"),
	2.0: Color("#f28c28"),
	2.5: Color("#f2a033"),
	3.0: Color("#f2b33d"),
	3.5: Color("#5aa6e8"),
	4.0: Color("#5fb0b8"),
	4.5: Color("#64b98c"),
	5.0: Color("#3fae5a"),
}

@export var value: float = 0.5:
	set(v):
		value = clampf(roundf(v * 2.0) / 2.0, 0.5, 5.0)
		if is_node_ready():
			queue_redraw()

@export var cell: int = 1:
	set(v):
		cell = maxi(1, v)
		if is_node_ready():
			update_minimum_size()
			queue_redraw()


static func color_of(value_in: float) -> Color:
	var half_step: float = clampf(roundf(value_in * 2.0) / 2.0, 0.5, 5.0)
	return COLOR_TABLE.get(half_step, FALLBACK)


func _ready() -> void:
	update_minimum_size()
	queue_redraw()


func _get_minimum_size() -> Vector2:
	var c: float = float(cell)
	return Vector2((STAR_COUNT * STAR_SIZE + (STAR_COUNT - 1)) * c, STAR_SIZE * c)


func _draw() -> void:
	var c: float = float(cell)
	var lit: Color = color_of(value)
	for i in STAR_COUNT:
		var x0: float = float(i * (STAR_SIZE + 1)) * c
		var full: bool = value >= float(i + 1)
		var half: bool = not full and value >= float(i) + 0.5
		for r in STAR_SIZE:
			var row: String = STAR_MAP[r]
			for col in STAR_SIZE:
				if row[col] != "#":
					continue
				var color: Color = UNLIT
				if full:
					color = lit
				elif half and col <= 4:
					color = lit
				draw_rect(Rect2(x0 + float(col) * c, float(r) * c, c, c), color)
