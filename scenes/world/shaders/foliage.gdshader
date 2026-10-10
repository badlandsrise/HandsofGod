shader_type spatial;
render_mode diffuse_lambert;
#include "res://scenes/world/shaders/hog_common.gdshaderinc"

// Trees, bushes and rocks (MultiMesh). Vertex COLOR.rgb = base, COLOR.a = 1 for leaves.
// INSTANCE_CUSTOM: r = random 0..1, g = 1 for broadleaf (turns with the seasons).
uniform bool evergreen_only = false;

varying vec3 wpos;
varying vec3 wnorm;
varying float leaf;
varying float rnd;
varying float broad;

void vertex() {
	leaf = COLOR.a;
	rnd = INSTANCE_CUSTOM.r;
	broad = INSTANCE_CUSTOM.g;
	vec3 base_w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float sway = sin(TIME * 1.3 + base_w.x * 0.3 + base_w.z * 0.2) * 0.06 * hog_wind * leaf * VERTEX.y;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.6;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = COLOR.rgb * (0.88 + 0.24 * rnd);
	if (leaf > 0.5) {
		// pines stay moss green; broadleaf takes the season's colour with variety
		vec3 pine = mix(COLOR.rgb, hog_pal_1.rgb * 0.75, 0.35);
		vec3 season = hog_leaf.rgb * (0.8 + 0.4 * rnd) * (COLOR.r / 0.3);
		season = mix(season, season * vec3(1.15, 0.8, 0.6), step(0.75, rnd) * smoothstep(0.4, 0.6, hog_leaf.r - hog_leaf.g + 0.4));
		c = mix(pine, season, broad);
	}
	float sm = hog_snow_mask(wpos, wnorm.y) * mix(1.0, 0.8, leaf);
	c = mix(c, vec3(0.92, 0.94, 0.98), sm);
	c *= 1.0 - hog_wet * 0.18;
	c = hog_dim(c, hog_region_light(wpos));
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}
