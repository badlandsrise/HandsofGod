shader_type spatial;
// Flat ground decal on a PlaneMesh: a soft disc (shadow) when ring_inner <= 0,
// otherwise a ring at ring_inner (0..1 of the plane's half size).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 0.35);
uniform float ring_inner = 0.0;
uniform float ring_width = 0.08;
uniform float dashes = 0.0;       // number of dashes around the ring (0 = solid)
uniform float spin = 0.0;         // dash rotation, radians
uniform float pulse = 0.0;        // 0..1 extra brightness

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	float a;
	if (ring_inner <= 0.0) {
		a = 1.0 - smoothstep(0.15, 1.0, r);
		a *= a;
	} else {
		a = smoothstep(ring_inner - ring_width, ring_inner, r) * (1.0 - smoothstep(ring_inner, ring_inner + ring_width, r));
		if (dashes > 0.0) {
			float ang = atan(uv.y, uv.x) + spin;
			a *= step(0.0, sin(ang * dashes));
		}
	}
	ALBEDO = color.rgb * (1.0 + pulse);
	ALPHA = clamp(color.a * a * (1.0 + pulse * 0.5), 0.0, 1.0);
}
