class_name SkyMarks extends Control
## Screen-space marks over the night sky: the old handprint from the cave wall,
## in ochre, drawn round the light when it blinks twice (DESIGN 9.2 beat 8: the
## crowd recognises it as the old hand-sign from the cave painting).

const OCHRE := Color("#c4702a")

var at: Vector2 = Vector2.ZERO
var amount: float = 0.0        # 0..1 visibility
var size_px: float = 150.0
var _jitter: Array = []

func _init() -> void:
	name = "SkyMarks"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in 64:
		_jitter.append(Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)))

func _process(_d: float) -> void:
	if amount > 0.0 or visible:
		queue_redraw()

func _draw() -> void:
	if amount <= 0.005:
		return
	var s := size_px / 100.0
	var c := Color(OCHRE, 0.55 * amount)
	var soft := Color(OCHRE, 0.16 * amount)
	var o := at + Vector2(0, 18.0 * s)    # the palm sits a little below the light
	var j := 0
	# the palm: overlapping dabs, like ochre blown on rock
	for p in [Vector2(0, 0), Vector2(-14, -6), Vector2(14, -6), Vector2(-10, 12), Vector2(10, 12), Vector2(0, 16), Vector2(0, -14)]:
		var q: Vector2 = o + (p + _jitter[j] * 2.5) * s
		draw_circle(q, 21.0 * s, soft)
		draw_circle(q, 15.0 * s, c)
		j += 1
	# four fingers fanned, and the thumb
	var fingers := [[Vector2(-17, -22), -0.32, 30.0], [Vector2(-6, -27), -0.1, 36.0], [Vector2(6, -27), 0.1, 38.0], [Vector2(17, -22), 0.3, 31.0]]
	for f in fingers:
		var base: Vector2 = o + (f[0] as Vector2) * s
		var dir := Vector2(sin(f[1]), -cos(f[1]))
		_dab_line(base, base + dir * float(f[2]) * s, 6.2 * s, c, soft, j)
		j += 4
	var tb := o + Vector2(-20, 6) * s
	_dab_line(tb, tb + Vector2(-0.82, -0.58) * 30.0 * s, 6.6 * s, c, soft, j)

func _dab_line(a: Vector2, b: Vector2, r: float, c: Color, soft: Color, j: int) -> void:
	var n := 5
	for i in n:
		var q: Vector2 = a.lerp(b, float(i) / float(n - 1)) + _jitter[(j + i) % _jitter.size()] * r * 0.15
		draw_circle(q, r * 1.45, soft)
		draw_circle(q, r, c)
