class_name MenuLogo
extends Control
## The sun and three paper lanterns on lit vines, drawn like the board. The lanterns sway gently
## unless the player prefers less motion.

const ENDS: Array[Vector2] = [Vector2(-92, 6), Vector2(92, 6), Vector2(0, -34)]

var _t := 0.0


func _process(delta: float) -> void:
	if is_visible_in_tree() and not Ui.reduced_motion():
		_t += delta
		queue_redraw()


func _draw() -> void:
	var c := size / 2.0 + Vector2(0, 8)
	var glow := 0.5 + 0.5 * sin(_t * 2.0)
	var width := 11.0
	for e in ENDS:
		draw_line(c, c + e, GardenPainter.GLOW, width * 2.6)
	for e in ENDS:
		GardenPainter.vine(self, c, c + e, width, GardenPainter.VINE_LIT, true)
	for k in ENDS.size():
		var e := ENDS[k]
		var side := PI / 2.6 if k % 2 == 0 else -PI / 2.6
		GardenPainter.leaf(self, c + e * 0.55, e.angle() + side, 18.0, GardenPainter.LEAF_LIT)
	GardenPainter.sun(self, c, 26.0, _t * 0.25, glow)
	for k in ENDS.size():
		GardenPainter.lantern(self, c + ENDS[k], 15.0, 1.0, sin(_t * 1.7 + k * 1.9) * 0.08, glow * 0.25)
