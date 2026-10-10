// World scatter (MultiMesh trees, bushes, rocks, plants from the art catalog):
// the shared palette grade of hog_flat, plus wind sway, snow on upward faces,
// wetness and the dimming of locked regions. Materials come from
// ArtPalette.scatter_material(), which copies the source material's colours.
shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;

#define HOG_CUSTOM_FRAGMENT
#include "res://assets/models/materials/hog_flat_core.gdshaderinc"
#include "res://scenes/world/shaders/hog_common.gdshaderinc"

uniform float sway = 0.0;      // 0 rigid (rock, trunk), 1 leaves

varying vec3 wpos;
varying vec3 wnorm;
varying float rnd;

void vertex() {
	vec3 base_w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	rnd = fract(sin(dot(base_w.xz, vec2(12.9898, 78.233))) * 43758.5453);
	float h = max(VERTEX.y, 0.0);
	float t = TIME * 1.3 + base_w.x * 0.3 + base_w.z * 0.2;
	float s = sin(t) * 0.035 * hog_wind * sway * h;
	VERTEX.x += s;
	VERTEX.z += s * 0.6;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec4 base = albedo_color;
	if (use_texture) {
		base *= texture(albedo_texture, UV);
	}
	vec3 c = hog_grade(base.rgb) * (0.9 + 0.2 * rnd);
	float sm = hog_snow_mask(wpos, wnorm.y);
	c = mix(c, vec3(0.92, 0.94, 0.98), sm);
	c *= 1.0 - hog_wet * 0.18;
	c = hog_dim(c, hog_region_light(wpos));
	ALBEDO = c;
	ROUGHNESS = softness;
	RIM = rim_strength;
	RIM_TINT = 0.6;
}
