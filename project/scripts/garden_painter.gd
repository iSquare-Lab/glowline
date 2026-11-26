class_name GardenPainter
extends RefCounted
## Drawing for the garden look, shared by the board and the menu logo: vines with leaves, the sun,
## paper lanterns and fireflies. Every function draws on `item` at its current transform.

const VINE_DARK := Color("6e5444")
const VINE_EDGE := Color("3e2d26")
const VINE_LIT := Color("ffc66a")
const VINE_FLASH := Color("fff4dc")
const GLOW := Color(1.0, 0.74, 0.36, 0.22)
const LEAF_DARK := Color("587045")
const LEAF_LIT := Color("a3c96f")
const SUN := Color("ffcf70")
const SUN_CORE := Color("fff3d1")
const SUN_RAY := Color(1.0, 0.8, 0.45, 0.6)
const PAPER_DARK := Color("8a766b")
const RIB_DARK := Color("6a5850")
const PAPER_LIT := Color("ffad4a")
const PAPER_INNER := Color("ffe3a6")
const RIB_LIT := Color("e0832c")
const CAP := Color("3a2420")


## A vine from `from` to `to`, `width` thick. `from` is always round; `to` is round unless `round_to` is false
## (a vine ending at a tile's edge, where the next tile's vine carries on). `edge` draws a darker outline first.
static func vine(item: CanvasItem, from: Vector2, to: Vector2, width: float, color: Color, edge: bool, round_to: bool = true) -> void:
	if edge:
		item.draw_line(from, to, VINE_EDGE, width + 3.0)
		item.draw_circle(from, (width + 3.0) / 2.0, VINE_EDGE)
		if round_to:
			item.draw_circle(to, (width + 3.0) / 2.0, VINE_EDGE)
	item.draw_line(from, to, color, width)
	item.draw_circle(from, width / 2.0, color)
	if round_to:
		item.draw_circle(to, width / 2.0, color)


## An almond-shaped leaf growing from `at` in direction `angle`.
static func leaf(item: CanvasItem, at: Vector2, angle: float, length: float, color: Color) -> void:
	var along := Vector2.from_angle(angle)
	var across := along.orthogonal()
	var points := PackedVector2Array()
	for k in 9:
		var u := k / 8.0
		points.append(at + along * length * u + across * length * 0.32 * sin(u * PI))
	for k in range(7, 0, -1):
		var u := k / 8.0
		points.append(at + along * length * u - across * length * 0.32 * sin(u * PI))
	item.draw_colored_polygon(points, color)


## The sun: a warm disc with short rays turned by `spin`, a halo that grows with `pulse` (0-1).
static func sun(item: CanvasItem, center: Vector2, r: float, spin: float, pulse: float) -> void:
	item.draw_circle(center, r * (1.9 + pulse * 0.35), Color(1.0, 0.78, 0.35, 0.12))
	item.draw_circle(center, r * 1.45, Color(1.0, 0.78, 0.35, 0.2))
	for k in 8:
		var a := spin + k * TAU / 8.0
		var tip := center + Vector2.from_angle(a) * r * 1.55
		var side := Vector2.from_angle(a + PI / 2.0) * r * 0.22
		var base := center + Vector2.from_angle(a) * r * 0.9
		item.draw_colored_polygon(PackedVector2Array([base + side, tip, base - side]), SUN_RAY)
	item.draw_circle(center, r, SUN)
	item.draw_circle(center, r * 0.55, SUN_CORE)


## A paper lantern about 2.4 × `r` tall, centred on `center`, hanging from a point above it and swung by
## `swing` radians. `glow` (0-1) is how lit it is; `flash` (0-1) brightens it for a moment.
static func lantern(item: CanvasItem, center: Vector2, r: float, glow: float, swing: float, flash: float = 0.0) -> void:
	var top := center + Vector2(0, -r * 1.25)
	item.draw_set_transform(top, swing, Vector2.ONE)
	var body := Vector2(0, r * 1.25)
	if glow > 0.0:
		item.draw_circle(body, r * (1.9 + flash * 0.5), Color(1.0, 0.7, 0.3, 0.2 * glow))
	var paper := PAPER_DARK.lerp(PAPER_LIT, glow).lerp(VINE_FLASH, flash * 0.5)
	var rib := RIB_DARK.lerp(RIB_LIT, glow)
	item.draw_colored_polygon(_ellipse(body, r * 0.92, r * 1.05, 20), paper)
	if glow > 0.0:
		item.draw_colored_polygon(_ellipse(body + Vector2(-r * 0.2, -r * 0.15), r * 0.38, r * 0.62, 14), Color(PAPER_INNER, glow * 0.9))
	var line := maxf(1.0, r * 0.1)
	item.draw_polyline(_ellipse(body, r * 0.45, r * 1.05, 20, true), rib, line, true)
	item.draw_line(body + Vector2(0, -r * 1.05), body + Vector2(0, r * 1.05), rib, line, true)
	item.draw_rect(Rect2(Vector2(-r * 0.5, -r * 0.08), Vector2(r, r * 0.3)), CAP)
	item.draw_rect(Rect2(Vector2(-r * 0.4, r * 2.18), Vector2(r * 0.8, r * 0.26)), CAP)
	item.draw_line(Vector2(0, r * 2.44), Vector2(0, r * 2.75), CAP, line, true)
	item.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A firefly: a soft halo and a bright core; `blink` (0-1) is how bright it is now.
static func firefly(item: CanvasItem, at: Vector2, r: float, blink: float) -> void:
	item.draw_circle(at, r * 2.4, Color(1.0, 0.86, 0.5, 0.1 * blink))
	item.draw_circle(at, r, Color(1.0, 0.86, 0.5, 0.25 + 0.5 * blink))
	item.draw_circle(at, r * 0.5, Color(1.0, 0.97, 0.85, 0.6 + 0.4 * blink))


static func _ellipse(center: Vector2, rx: float, ry: float, steps: int, closed: bool = false) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in steps + (1 if closed else 0):
		var a := TAU * k / steps
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return points
