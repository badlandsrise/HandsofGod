class_name TitleLogo extends Control
## The "Hands of God" title treatment, drawn over the live valley: a round
## ochre seal holding the hand mark (the handprint from the cave wall), the
## title in IM Fell English with a small italic "of" tucked between the two
## big words, an ink outline and a soft shadow so it reads over any sky, a
## flourished rule, and the tagline. Fades in with `reveal` (0..1).

const CREAM := Color("#f6ead0")
const SHADOW := Color(0.08, 0.04, 0.02, 0.55)
const OUTLINE := Color(0.18, 0.1, 0.05, 0.75)

var reveal: float = 1.0:
	set(v):
		reveal = clampf(v, 0.0, 1.0)
		queue_redraw()
var tagline: String = "a valley that grows in your palm"
var big: int = 116

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(620, 300)

func _draw() -> void:
	var a := reveal
	if a <= 0.0:
		return
	var f_big := UiTheme.font(&"title")
	var f_of := UiTheme.font(&"title_italic")
	var f_tag := UiTheme.font(&"italic")
	var small := int(big * 0.46)
	var w_hands := f_big.get_string_size("Hands", HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	var w_of := f_of.get_string_size("of", HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
	var w_god := f_big.get_string_size("God", HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	var gap := big * 0.12
	var total := w_hands + gap + w_of + gap + w_god
	var seal_r := big * 0.42
	var x0 := (size.x - total) * 0.5
	var base := seal_r * 2.0 + big * 0.95
	# the seal: an ochre disc, a cream ring, the hand mark, small rays
	var sc := Vector2(size.x * 0.5, seal_r + 6.0 - (1.0 - a) * 10.0)
	draw_circle(sc + Vector2(2, 4), seal_r + 4.0, Color(SHADOW, SHADOW.a * a))
	draw_circle(sc, seal_r + 3.0, Color(CREAM, a))
	draw_circle(sc, seal_r - 1.0, Color(UiTheme.OCHRE, a))
	draw_arc(sc, seal_r - 6.0, 0.0, TAU, 64, Color(CREAM, 0.55 * a), 1.4, true)
	for i in 12:
		var ang := TAU * float(i) / 12.0 - PI * 0.5
		var d := Vector2(cos(ang), sin(ang))
		draw_line(sc + d * (seal_r + 9.0), sc + d * (seal_r + 9.0 + (9.0 if i % 2 == 0 else 5.0)), Color(CREAM, 0.7 * a), 2.0, true)
	PortraitFrame.draw_hand_mark(self, sc + Vector2(2, seal_r * 0.18), seal_r * 1.08, Color(CREAM, a))
	# the title: outline + shadow, then the cream face
	var y := base - (1.0 - a) * 8.0
	var parts := [["Hands", f_big, big, x0, y], ["of", f_of, small, x0 + w_hands + gap, y - big * 0.22], ["God", f_big, big, x0 + w_hands + gap + w_of + gap, y]]
	for p in parts:
		var pos := Vector2(p[3], p[4])
		draw_string(p[1], pos + Vector2(3, 5), p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, p[2], Color(SHADOW, SHADOW.a * a))
		draw_string_outline(p[1], pos, p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, p[2], maxi(int(big * 0.07), 4), Color(OUTLINE, OUTLINE.a * a))
	for p in parts:
		var col := CREAM if p[0] != "of" else Color("#f0b46a")
		draw_string(p[1], Vector2(p[3], p[4]), p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, p[2], Color(col, a))
	# a flourished rule with a diamond, then the tagline
	var ry := y + big * 0.3
	var m := size.x * 0.5
	var half := total * 0.42
	var rc := Color(CREAM, 0.8 * a)
	draw_line(Vector2(m - half, ry + 1.5), Vector2(m - 14, ry + 1.5), Color(SHADOW, 0.5 * a), 2.0, true)
	draw_line(Vector2(m - half, ry), Vector2(m - 14, ry), rc, 1.6, true)
	draw_line(Vector2(m + 14, ry), Vector2(m + half, ry), rc, 1.6, true)
	draw_colored_polygon(PackedVector2Array([Vector2(m, ry - 6), Vector2(m + 7, ry), Vector2(m, ry + 6), Vector2(m - 7, ry)]), Color(UiTheme.GOLD, a))
	draw_circle(Vector2(m - half - 5, ry), 2.0, rc)
	draw_circle(Vector2(m + half + 5, ry), 2.0, rc)
	var ts := int(big * 0.22)
	var tw := f_tag.get_string_size(tagline, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
	var tp := Vector2(m - tw * 0.5, ry + ts * 1.5)
	draw_string(f_tag, tp + Vector2(1.5, 2.5), tagline, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(SHADOW, SHADOW.a * a))
	draw_string(f_tag, tp, tagline, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(CREAM, 0.92 * a))

## Height the drawing needs, for layout.
func needed_height() -> float:
	return big * 0.42 * 2.0 + big * 0.95 + big * 0.3 + big * 0.22 * 2.2 + 10.0
