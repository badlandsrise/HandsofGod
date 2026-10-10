shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, specular_disabled, shadows_disabled;
#include "res://scenes/world/shaders/hog_common.gdshaderinc"

// The mist over land the people cannot reach yet (scripts/world/regions.gd).
// A terrain-following sheet; visible only where hog_region_mask is dark, thin
// at the edge of the open land and thickening over ~25 m, in slow drifting wisps.

uniform float opacity : hint_range(0.0, 1.0) = 0.8;
uniform float drift = 1.0;
uniform vec4 haze : source_color = vec4(0.80, 0.83, 0.88, 1.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

float wide_light(vec2 xz) {
	vec2 uv = (xz - hog_map_rect.xy) / hog_map_rect.zw;
	vec2 o = 2.2 / vec2(textureSize(hog_region_mask, 0));
	float l = texture(hog_region_mask, uv).r * 0.28;
	l += texture(hog_region_mask, uv + vec2(o.x, 0.0)).r * 0.09;
	l += texture(hog_region_mask, uv - vec2(o.x, 0.0)).r * 0.09;
	l += texture(hog_region_mask, uv + vec2(0.0, o.y)).r * 0.09;
	l += texture(hog_region_mask, uv - vec2(0.0, o.y)).r * 0.09;
	l += texture(hog_region_mask, uv + o).r * 0.09;
	l += texture(hog_region_mask, uv - o).r * 0.09;
	l += texture(hog_region_mask, uv + vec2(o.x, -o.y)).r * 0.09;
	l += texture(hog_region_mask, uv + vec2(-o.x, o.y)).r * 0.09;
	return l;
}

void fragment() {
	float locked = 1.0 - wide_light(wpos.xz);
	if (locked < 0.01) {
		discard;
	}
	vec2 flow = vec2(TIME * 0.6, TIME * 0.25) * drift;
	float n = hog_noise((wpos.xz + flow) * 0.045) * 0.6 + hog_noise((wpos.xz - flow * 1.7) * 0.13) * 0.4;
	float edge = smoothstep(0.05, 0.75, locked);
	float a = edge * mix(0.55, 1.0, smoothstep(0.25, 0.75, n)) * opacity;
	ALBEDO = haze.rgb * (0.92 + 0.12 * n);
	ALPHA = clamp(a, 0.0, 1.0);
	ROUGHNESS = 1.0;
}
