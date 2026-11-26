class_name LockIcon
extends Control
## A small padlock: on locked tiles (drawn by the board with draw_lock) and on levels not open yet.

const COLOR := Color("f3e2cc")


func _init(icon_size: float = 18.0) -> void:
	custom_minimum_size = Vector2(icon_size, icon_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := size.y / 1.3
	draw_lock(self, Vector2(size.x / 2.0, size.y / 2.0 - s * 0.15), s, COLOR)


## Draws a padlock about 1.2 × `s` tall around `at` (the top of its body) on `item`.
static func draw_lock(item: CanvasItem, at: Vector2, s: float, color: Color) -> void:
	item.draw_arc(at + Vector2(0, -s * 0.1), s * 0.36, PI, TAU, 12, color, maxf(1.5, s * 0.18), true)
	item.draw_rect(Rect2(at + Vector2(-s * 0.55, -s * 0.1), Vector2(s * 1.1, s * 0.85)), color)
