shader_type spatial;
render_mode diffuse_lambert, cull_disabled;
#include "res://scenes/world/shaders/hog_common.gdshaderinc"

// Grass tufts (MultiMesh). COLOR.a = 1 at the blade tip.
varying vec3 wpos;
varying float tip;

void vertex() {
	tip = COLOR.a;
	vec3 base_w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float t = TIME * 1.8 + base_w.x * 0.25 + base_w.z * 0.18;
	VERTEX.x += sin(t) * 0.12 * hog_wind * tip;
	VERTEX.z += cos(t * 0.8) * 0.08 * hog_wind * tip;
	// snow buries the grass
	VERTEX.y *= 1.0 - clamp(hog_snow, 0.0, 1.0) * 0.85;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	float n = hog_noise(wpos.xz * 0.21);
	vec3 c = hog_grass.rgb * (0.82 + 0.3 * n) * mix(0.75, 1.25, tip) * COLOR.rgb / 0.68;
	c = mix(c, vec3(0.9, 0.93, 0.98), clamp(hog_frost * 0.6 + hog_snow, 0.0, 1.0) * tip);
	c *= 1.0 - hog_wet * 0.2;
	c = hog_dim(c, hog_region_light(wpos));
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
