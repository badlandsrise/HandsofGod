shader_type spatial;
// The hand: soft, warm, slightly translucent skin with a fresnel rim glow.
// glow_color is set per era (amber, gold, white, pale blue).
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 skin_color : source_color = vec4(0.98, 0.84, 0.70, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.66, 0.30, 1.0);
uniform float glow_strength : hint_range(0.0, 4.0) = 1.0;
uniform float rim_power : hint_range(0.5, 8.0) = 2.2;
uniform float alpha : hint_range(0.0, 1.0) = 0.8;
uniform float inner_glow : hint_range(0.0, 1.0) = 0.10;
// Forearm fade: alpha falls to 0 between fade_from and fade_to along the
// mesh's local Y axis (off when fade_to <= fade_from).
uniform float fade_from = 0.0;
uniform float fade_to = 0.0;
varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - ndv, rim_power);
	ALBEDO = skin_color.rgb;
	ROUGHNESS = 0.55;
	SPECULAR = 0.3;
	EMISSION = glow_color.rgb * (fres * 2.4 + inner_glow) * glow_strength;
	float a = clamp(alpha + fres * 0.25, 0.0, 1.0);
	if (fade_to > fade_from) {
		a *= 1.0 - smoothstep(fade_from, fade_to, local_y);
	}
	ALPHA = a;
}
