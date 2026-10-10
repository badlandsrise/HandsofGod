shader_type spatial;
render_mode diffuse_lambert, cull_disabled;
#include "res://scenes/world/shaders/hog_common.gdshaderinc"

// Grass tufts (MultiMesh). COLOR.a = 1 at the blade tip; COLOR.rgb = per-blade shade.
// INSTANCE_CUSTOM.r = random 0..1. The colour patches match the ground shader's
// (same noise and palette, set by scripts/world/foliage.gd), so tufts sit in their patch.
uniform sampler2D noise_large : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_fine : filter_linear_mipmap, repeat_enable;
uniform vec4 grass_deep : source_color = vec4(0.25, 0.42, 0.17, 1.0);
uniform vec4 grass_lush : source_color = vec4(0.36, 0.52, 0.21, 1.0);
uniform vec4 grass_yellow : source_color = vec4(0.58, 0.62, 0.26, 1.0);
uniform vec4 grass_bleached : source_color = vec4(0.70, 0.66, 0.40, 1.0);

varying vec3 wpos;
varying vec3 base_w;
varying float tip;
varying float rnd;

void vertex() {
	tip = COLOR.a;
	rnd = INSTANCE_CUSTOM.r;
	base_w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float t = TIME * 1.8 + base_w.x * 0.25 + base_w.z * 0.18;
	float gust = 0.6 + 0.4 * sin(TIME * 0.4 + base_w.x * 0.02);
	VERTEX.x += sin(t) * 0.14 * hog_wind * gust * tip;
	VERTEX.z += cos(t * 0.8) * 0.09 * hog_wind * gust * tip;
	// snow buries the grass
	VERTEX.y *= 1.0 - clamp(hog_snow, 0.0, 1.0) * 0.85;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec2 xz = base_w.xz;
	float nl = texture(noise_large, xz * 0.0035).r;
	float nl2 = texture(noise_large, xz * 0.011 + vec2(0.31, 0.77)).r;
	float nf = texture(noise_fine, xz * 0.35).r;
	vec3 g = mix(grass_deep.rgb, grass_lush.rgb, smoothstep(0.3, 0.6, nl));
	g = mix(g, grass_yellow.rgb, smoothstep(0.55, 0.75, nl2) * 0.8);
	g *= hog_grass.rgb / vec3(0.36, 0.55, 0.23);
	g *= 0.85 + 0.3 * rnd;
	g = mix(g, g * vec3(1.15, 1.1, 0.75), smoothstep(0.7, 0.95, rnd) * 0.6);   // a few straw blades
	vec3 c = g * mix(0.9, 1.3, tip) * (COLOR.rgb / 0.8);
	c = mix(c, vec3(0.9, 0.93, 0.98), clamp(hog_frost * 0.6 + hog_snow, 0.0, 1.0) * tip);
	c *= 1.0 - hog_wet * 0.2;
	c = hog_dim(c, hog_region_light(wpos));
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
	BACKLIGHT = vec3(0.25, 0.3, 0.1) * tip;
}
