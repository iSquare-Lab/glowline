class_name Fireflies
extends Control
## Small warm lights drifting slowly upward: over the menu, and over the board once it is solved.
## They stay hidden when the player prefers less motion.

var _flies: Array[Vector4] = []
var _t := 0.0


## `amount` fireflies, placed the same way every time for `seed_value`.
func _init(amount: int = 14, seed_value: int = 7) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for n in amount:
		# x and y as a share of the size, a phase, and a speed.
		_flies.append(Vector4(rng.randf(), rng.randf(), rng.randf() * TAU, rng.randf_range(0.6, 1.4)))


func set_active(on: bool) -> void:
	visible = on and not Ui.reduced_motion()


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _draw() -> void:
	for fly in _flies:
		var x := fly.x + 0.035 * sin(_t * 0.31 * fly.w + fly.z)
		var y := fposmod(fly.y - _t * 0.012 * fly.w + 0.03 * sin(_t * 0.23 * fly.w + fly.z * 1.7), 1.0)
		var blink := 0.5 + 0.5 * sin(_t * 1.3 * fly.w + fly.z * 3.0)
		GardenPainter.firefly(self, Vector2(x, y) * size, 3.0, blink)
