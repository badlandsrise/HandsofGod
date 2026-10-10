shader_type spatial;
// Writes the hand's depth and nothing else, so the translucent ghost pass that
// follows only draws the front-most surface (no doubled fingers).
render_mode blend_mix, depth_draw_always, cull_back, unshaded, shadows_disabled;

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
