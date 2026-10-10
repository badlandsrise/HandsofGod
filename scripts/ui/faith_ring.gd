class_name FaithRing extends Control
## The faith glow ring: available faith in the middle, the ring fills toward
## the cheapest power you can't yet afford, and glows when one is affordable.

var available: float = 0.0
var next_cost: float = 0.0
var affordable: bool = false
var _pulse: float = 0.0
var _shown: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(92, 92)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Events.faith_changed.connect(func(_t): _pulse = 1.0)

func _process(_d: float) -> void:
	var dt := Clock.real_delta
	_pulse = maxf(_pulse - dt * 1.5, 0.0)
	_shown = lerpf(_shown, available, minf(6.0 * dt, 1.0))
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 6.0
	var t := Time.get_ticks_msec() * 0.001
	var glow := 0.35 + 0.65 * _pulse + (0.25 + 0.15 * sin(t * 3.0) if affordable else 0.0)
	for i in 4:
		draw_circle(c, r + 2.0 + float(i) * 2.5, Color(UiTheme.ACCENT, 0.06 * glow))
	draw_circle(c, r, Color(0.14, 0.09, 0.06, 0.92))
	draw_arc(c, r - 4.0, 0, TAU, 48, Color(1, 1, 1, 0.12), 6.0, true)
	var frac := 1.0 if next_cost <= 0.0 else clampf(_shown / next_cost, 0.0, 1.0)
	if frac > 0.0:
		draw_arc(c, r - 4.0, -PI / 2, -PI / 2 + TAU * frac, 64, UiTheme.ACCENT.lightened(0.2 * glow), 6.0, true)
	var f := get_theme_default_font()
	var s := str(int(floor(_shown + 0.001)))
	var fs := 26
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, c + Vector2(-w * 0.5, 6), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.TEXT)
	var lab := "faith"
	var w2 := f.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(f, c + Vector2(-w2 * 0.5, 24), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiTheme.TEXT_DIM)
