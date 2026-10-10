class_name ButtonFx extends RefCounted

#The catalog of button animations. A click plays once, a hover holds while the cursor is over the
#button and a stay loops while it rests there; each of the three picks a move and a shade. KIND
#follows the preset of the button kind and NONE turns the slot off. Every timing and size is here.
#An active button (a pressed toggle, or disabled with disabled_solid) plays the active pair instead of hover and stay.

const KIND: int = -1
enum ClickMove {KIND = -1, NONE = 0, SHRINK = 1, SQUASH = 2, POP = 3, DROP = 4, RATTLE = 5, ROCK = 6, BOUNCE = 7}
enum ClickShade {KIND = -1, NONE = 0, FLASH = 1, INVERT = 2, INK = 3, HALO = 4, BLAZE = 5, LABEL = 6, FADE = 7}
enum HoverMove {KIND = -1, NONE = 0, LIFT = 1, RAISE = 2, TILT = 3}
enum HoverShade {KIND = -1, NONE = 0, LIGHTEN = 1, GLOW = 2, RING = 3, SPARK = 4, TINT = 5, DARKEN = 6, PING = 7}
enum StayMove {KIND = -1, NONE = 0, PULSE = 1, SWAY = 2, FLOAT = 3}
enum StayShade {KIND = -1, NONE = 0, SHIMMER = 1, BREATHE = 2, BEACON = 3}
const SLOTS: Array[StringName] = [&"click_move", &"click_shade", &"hover_move", &"hover_shade", &"stay_move",
	&"stay_shade", &"active_move", &"active_shade"]
const PRESETS: Dictionary = {
	&"go": {&"click_move": ClickMove.POP, &"click_shade": ClickShade.FLASH, &"hover_move": HoverMove.LIFT,
		&"hover_shade": HoverShade.GLOW, &"stay_move": StayMove.PULSE, &"stay_shade": StayShade.SHIMMER,
		&"active_move": HoverMove.NONE, &"active_shade": HoverShade.RING},
	&"danger": {&"click_move": ClickMove.RATTLE, &"click_shade": ClickShade.INK, &"hover_move": HoverMove.RAISE,
		&"hover_shade": HoverShade.DARKEN, &"stay_move": StayMove.NONE, &"stay_shade": StayShade.NONE,
		&"active_move": HoverMove.NONE, &"active_shade": HoverShade.RING},
	&"orange": {&"click_move": ClickMove.BOUNCE, &"click_shade": ClickShade.HALO, &"hover_move": HoverMove.TILT,
		&"hover_shade": HoverShade.TINT, &"stay_move": StayMove.FLOAT, &"stay_shade": StayShade.BEACON,
		&"active_move": HoverMove.NONE, &"active_shade": HoverShade.RING},
	&"blue": {&"click_move": ClickMove.DROP, &"click_shade": ClickShade.INVERT, &"hover_move": HoverMove.LIFT,
		&"hover_shade": HoverShade.LIGHTEN, &"stay_move": StayMove.NONE, &"stay_shade": StayShade.NONE,
		&"active_move": HoverMove.NONE, &"active_shade": HoverShade.RING},
	&"neutral": {&"click_move": ClickMove.SHRINK, &"click_shade": ClickShade.FADE, &"hover_move": HoverMove.NONE,
		&"hover_shade": HoverShade.LIGHTEN, &"stay_move": StayMove.NONE, &"stay_shade": StayShade.NONE,
		&"active_move": HoverMove.NONE, &"active_shade": HoverShade.RING},
}
#Seconds of the hover ease in and of the release; EXIT stays at least three times faster than ENTER.
const ENTER: float = 0.12
const EXIT: float = 0.03
const RING_PX: float = 2.0
const EDGE_TO: Color = GuiColors.CREAM
const RING_TO: Color = GuiColors.CREAM
const LABEL_TO: Color = GuiColors.SKY
const INK_TO: Color = GuiColors.INK
const TINT_TO: Color = GuiColors.CREAM
#Every Layer field the tweens drive, at its resting value.
const IDENTITY: Dictionary = {"scale": Vector2.ONE, "offset": Vector2.ZERO, "angle": 0.0, "whole": 1.0,
	"alpha": 1.0, "body_mix": 0.0, "edge_mix": 0.0, "invert": 0.0, "label_mix": 0.0, "ring_alpha": 0.0}


#What one layer adds to the button: angle in degrees, offset in pixels, whole and alpha scale the
#modulate, the mixes pull a colour toward body_to, EDGE_TO and LABEL_TO, invert swaps the bevel bands.
class Layer extends RefCounted:
	var scale: Vector2 = Vector2.ONE
	var offset: Vector2 = Vector2.ZERO
	var angle: float = 0.0
	var whole: float = 1.0
	var alpha: float = 1.0
	var body_mix: float = 0.0
	var edge_mix: float = 0.0
	var invert: float = 0.0
	var label_mix: float = 0.0
	var ring_alpha: float = 0.0
	var body_to: Color = INK_TO
	var move: Tween = null
	var shade: Tween = null

	func reset() -> void:
		for field: String in IDENTITY:
			set(field, IDENTITY[field])

	func is_identity() -> bool:
		for field: String in IDENTITY:
			if get(field) != IDENTITY[field]:
				return false
		return true

	func running() -> bool:
		for tween: Tween in [move, shade]:
			if tween != null and tween.is_valid() and tween.is_running():
				return true
		return false

	func kill() -> void:
		for tween: Tween in [move, shade]:
			if tween != null:
				tween.kill()
		move = null
		shade = null


static func preset(kind: StringName) -> Dictionary:
	return PRESETS.get(kind, PRESETS[&"blue"])


#Each builder appends one animation to a fresh tween the rig made; which is never NONE or KIND.
static func click_move(tween: Tween, layer: Layer, which: int) -> void:
	match which:
		ClickMove.SHRINK:
			_peak(tween, layer, "scale", Vector2(0.92, 0.92), 0.06, 0.08)
		ClickMove.SQUASH:
			tween.tween_property(layer, "scale", Vector2(1.08, 0.88), 0.07)
			tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(layer, "scale", Vector2.ONE, 0.15)
		ClickMove.POP:
			_peak(tween, layer, "scale", Vector2(1.10, 1.10), 0.06, 0.10)
		ClickMove.DROP:
			_peak(tween, layer, "offset", Vector2(0.0, 2.0), 0.05, 0.07)
		ClickMove.RATTLE:
			for x: float in [3.0, -3.0, 2.0, -2.0, 0.0]:
				tween.tween_property(layer, "offset", Vector2(x, 0.0), 0.036)
		ClickMove.ROCK:
			tween.tween_property(layer, "angle", -3.0, 0.07)
			tween.tween_property(layer, "angle", 3.0, 0.07)
			tween.tween_property(layer, "angle", 0.0, 0.06)
		ClickMove.BOUNCE:
			_ease_out(tween, layer, "offset", Vector2(0.0, -4.0), 0.10)
			_peak(tween, layer, "offset", Vector2(0.0, 1.0), 0.08, 0.10)


static func click_shade(tween: Tween, layer: Layer, which: int) -> void:
	match which:
		ClickShade.FLASH:
			_peak(tween, layer, "whole", 1.5, 0.05, 0.13)
		ClickShade.INVERT:
			tween.tween_property(layer, "invert", 1.0, 0.0)
			tween.tween_interval(0.12)
			tween.tween_property(layer, "invert", 0.0, 0.0)
		ClickShade.INK:
			layer.body_to = INK_TO
			_peak(tween, layer, "body_mix", 0.6, 0.05, 0.11)
		ClickShade.HALO:
			_peak(tween, layer, "ring_alpha", 0.9, 0.04, 0.26)
		ClickShade.BLAZE:
			_peak(tween, layer, "edge_mix", 1.0, 0.05, 0.20)
		ClickShade.LABEL:
			_peak(tween, layer, "label_mix", 1.0, 0.05, 0.15)
		ClickShade.FADE:
			_peak(tween, layer, "alpha", 0.6, 0.08, 0.12)


static func hover_move(tween: Tween, layer: Layer, which: int) -> void:
	match which:
		HoverMove.LIFT:
			_ease_out(tween, layer, "scale", Vector2(1.04, 1.04), ENTER)
		HoverMove.RAISE:
			_ease_out(tween, layer, "offset", Vector2(0.0, -2.0), ENTER)
		HoverMove.TILT:
			_ease_out(tween, layer, "angle", 1.5, ENTER)


#SPARK and PING play once; the others hold until the release.
static func hover_shade(tween: Tween, layer: Layer, which: int) -> void:
	match which:
		HoverShade.LIGHTEN:
			_ease_out(tween, layer, "whole", 1.15, ENTER)
		HoverShade.GLOW:
			_ease_out(tween, layer, "edge_mix", 0.6, ENTER)
		HoverShade.RING:
			_ease_out(tween, layer, "ring_alpha", 0.8, ENTER)
		HoverShade.SPARK:
			_peak(tween, layer, "whole", 1.5, 0.05, 0.20)
		HoverShade.TINT:
			layer.body_to = TINT_TO
			_ease_out(tween, layer, "body_mix", 0.35, ENTER)
		HoverShade.DARKEN:
			_ease_out(tween, layer, "whole", 0.85, ENTER)
		HoverShade.PING:
			_peak(tween, layer, "ring_alpha", 0.9, 0.04, 0.36)


static func stay_move(tween: Tween, layer: Layer, which: int) -> void:
	tween.set_loops().set_trans(Tween.TRANS_SINE)
	match which:
		StayMove.PULSE:
			_peak(tween, layer, "scale", Vector2(1.03, 1.03), 0.45, 0.45)
		StayMove.SWAY:
			tween.tween_property(layer, "angle", -1.0, 0.30)
			tween.tween_property(layer, "angle", 1.0, 0.60)
			tween.tween_property(layer, "angle", 0.0, 0.30)
		StayMove.FLOAT:
			_peak(tween, layer, "offset", Vector2(0.0, -2.0), 0.50, 0.50)


static func stay_shade(tween: Tween, layer: Layer, which: int) -> void:
	tween.set_loops().set_trans(Tween.TRANS_SINE)
	match which:
		StayShade.SHIMMER:
			_peak(tween, layer, "edge_mix", 0.5, 0.50, 0.50)
		StayShade.BREATHE:
			_peak(tween, layer, "whole", 1.15, 0.60, 0.60)
		StayShade.BEACON:
			_peak(tween, layer, "ring_alpha", 0.6, 0.40, 0.40)


#Every field the layer holds away from rest goes back at once over EXIT. The layer must not be at
#rest, since a tween given no tweeners errors.
static func release(tween: Tween, layer: Layer) -> void:
	tween.set_parallel(true)
	for field: String in IDENTITY:
		if layer.get(field) != IDENTITY[field]:
			tween.tween_property(layer, field, IDENTITY[field], EXIT)


#field goes to peak over rise, then back to rest over fall.
static func _peak(tween: Tween, layer: Layer, field: String, peak: Variant, rise: float, fall: float) -> void:
	tween.tween_property(layer, field, peak, rise)
	tween.tween_property(layer, field, IDENTITY[field], fall)


static func _ease_out(tween: Tween, layer: Layer, field: String, to: Variant, seconds: float) -> void:
	tween.tween_property(layer, field, to, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
