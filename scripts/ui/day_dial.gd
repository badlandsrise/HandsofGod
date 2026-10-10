class_name DayDial extends Control
## Day/night dial (day arc gold, night arc blue, a marker for now) with the
## season drawn as a small icon in the middle.

func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 4.0
	var full := maxf(Clock.day_seconds + Clock.night_seconds, 0.01)
	var day_frac := Clock.day_seconds / full
	var start := -PI / 2
	draw_circle(c, r + 2.0, Color(0.1, 0.07, 0.05, 0.9))
	draw_arc(c, r - 3.0, start, start + TAU * day_frac, 40, Color(1.0, 0.78, 0.35, 0.85), 5.0, true)
	draw_arc(c, r - 3.0, start + TAU * day_frac, start + TAU, 24, Color(UiTheme.NIGHT, 0.9), 5.0, true)
	var a := start + TAU * Clock.day_fraction()
	var m := c + Vector2(cos(a), sin(a)) * (r - 3.0)
	draw_circle(m, 5.5, Color(1, 1, 1))
	draw_circle(m, 3.5, Color(1.0, 0.85, 0.4) if not Clock.is_night else Color(0.8, 0.86, 1.0))
	_draw_season(c, r * 0.42, Clock.season)

func _draw_season(c: Vector2, r: float, s: int) -> void:
	match s:
		Clock.Season.SPRING:
			for k in 4:
				var a := TAU * float(k) / 4.0 + PI / 4
				draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.55, r * 0.45, Color(1.0, 0.75, 0.85))
			draw_circle(c, r * 0.35, Color(1.0, 0.9, 0.4))
		Clock.Season.SUMMER:
			for k in 8:
				var a := TAU * float(k) / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * r * 0.75, c + Vector2(cos(a), sin(a)) * r * 1.15, Color(1.0, 0.82, 0.3), 2.0, true)
			draw_circle(c, r * 0.6, Color(1.0, 0.8, 0.3))
		Clock.Season.AUTUMN:
			var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.75, 0), c + Vector2(0, r), c + Vector2(-r * 0.75, 0)])
			draw_colored_polygon(pts, Color(0.95, 0.5, 0.2))
			draw_line(c + Vector2(0, -r * 0.7), c + Vector2(0, r * 1.1), Color(0.5, 0.25, 0.1), 1.5, true)
		_:
			for k in 3:
				var a := PI * float(k) / 3.0
				var d := Vector2(cos(a), sin(a)) * r
				draw_line(c - d, c + d, Color(0.85, 0.93, 1.0), 2.0, true)
			draw_circle(c, r * 0.2, Color(0.9, 0.96, 1.0))
