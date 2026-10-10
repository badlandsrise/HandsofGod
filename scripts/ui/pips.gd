class_name UiPips extends Control
## A row of drawn pips (dots) or stars: filled / total. Drawn, not text, so it
## doesn't depend on font glyphs.

@export var total: int = 3:
	set(v): total = maxi(v, 0); _resize()
@export var filled: int = 0:
	set(v): filled = v; queue_redraw()
@export var stars: bool = false:
	set(v): stars = v; queue_redraw()
@export var radius: float = 6.0:
	set(v): radius = v; _resize()
@export var on_color: Color = UiTheme.ACCENT
@export var off_color: Color = Color(1, 1, 1, 0.25)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resize()

func setup(f: int, t: int) -> void:
	filled = f
	total = t

func _resize() -> void:
	custom_minimum_size = Vector2(maxf(float(total) * radius * 2.6, 1.0), radius * 2.4)
	queue_redraw()

func _draw() -> void:
	var cy := size.y * 0.5
	for i in total:
		var c := Vector2(radius * 1.3 + float(i) * radius * 2.6, cy)
		var on := i < filled
		if stars:
			var pts := PackedVector2Array()
			for k in 10:
				var r := radius if k % 2 == 0 else radius * 0.45
				var a := -PI / 2 + TAU * float(k) / 10.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, on_color if on else off_color)
		elif on:
			draw_circle(c, radius, on_color)
		else:
			draw_arc(c, radius - 1.0, 0, TAU, 20, off_color.lightened(0.3), 2.0, true)
