// The god hand as a classic white cartoon glove: soft matte cloth with a slight
// warm tint, wrapped soft shading, a gentle era-coloured rim light, and three
// dark stitch lines on the back. Shared by hand_glove (solid) and
// hand_glove_ghost (translucent, glowing) so they always match.
//   COLOR.r  back-of-hand mask (stitches only draw there), COLOR.g cuff
//   UV2      rest-pose (y, z) on the back of the hand, in skeleton metres

uniform vec4 cloth_color : source_color = vec4(0.9, 0.88, 0.84, 1.0);
uniform vec4 cuff_color : source_color = vec4(0.26, 0.23, 0.25, 1.0);   // the cap inside the cuff
uniform vec4 stitch_color : source_color = vec4(0.13, 0.1, 0.09, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.66, 0.30, 1.0);
uniform float glow_strength : hint_range(0.0, 4.0) = 1.0;
uniform float rim_power : hint_range(0.5, 8.0) = 2.6;
uniform float rim_amount : hint_range(0.0, 2.0) = 0.45;
uniform float inner_glow : hint_range(0.0, 1.0) = 0.03;
// stitch lines: lateral positions (skeleton Y) and the run along Z
uniform vec3 stitch_y = vec3(0.0128, -0.0047, -0.0215);
uniform vec2 stitch_z = vec2(-0.058, -0.012);
uniform float stitch_width = 0.0008;

float stitch_mask(vec2 rest, float back) {
	float m = 0.0;
	float along = smoothstep(stitch_z.x, stitch_z.x + 0.006, rest.y) * (1.0 - smoothstep(stitch_z.y - 0.006, stitch_z.y, rest.y));
	for (int i = 0; i < 3; i++) {
		float d = abs(rest.x - stitch_y[i]);
		float w = fwidth(rest.x) + 1e-6;
		m = max(m, 1.0 - smoothstep(stitch_width - w, stitch_width + w, d));
	}
	return m * along * smoothstep(0.55, 0.8, back);
}

vec3 glove_albedo(vec4 col, vec2 rest) {
	vec3 base = mix(cloth_color.rgb, cuff_color.rgb, col.g);
	return mix(base, stitch_color.rgb, stitch_mask(rest, col.r) * (1.0 - col.g));
}

vec3 glove_emission(float ndv) {
	float fres = pow(1.0 - ndv, rim_power);
	return glow_color.rgb * (fres * rim_amount + inner_glow) * glow_strength;
}

// Soft cartoon cloth light: a wide, warm-lit to cool-shadowed ramp.
uniform vec4 shadow_tint : source_color = vec4(0.52, 0.5, 0.66, 1.0);
vec3 glove_diffuse(vec3 n, vec3 l, vec3 light_color, float att) {
	float ndl = dot(n, l);
	float shade = smoothstep(-0.45, 0.7, ndl) * mix(0.35, 1.0, att);
	vec3 ramp = mix(shadow_tint.rgb, vec3(1.0, 0.97, 0.92), shade);
	return (light_color * ramp * shade * 0.9 + light_color * shadow_tint.rgb * 0.12) / PI;
}
