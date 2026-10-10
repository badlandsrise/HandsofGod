shader_type spatial;
// Cartoon ink outline: the back faces of the glove pushed out along their
// normals. Width is in mesh units (skeleton metres for the glove).
render_mode blend_mix, depth_draw_never, cull_front, unshaded, shadows_disabled;

uniform vec4 line_color : source_color = vec4(0.16, 0.11, 0.09, 1.0);
uniform float width = 0.0011;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = line_color.rgb;
	ALPHA = line_color.a * opacity;
}
