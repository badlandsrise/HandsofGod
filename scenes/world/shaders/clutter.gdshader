shader_type spatial;
render_mode diffuse_lambert, cull_disabled;
#include "res://scenes/world/shaders/hog_common.gdshaderinc"

// Ground clutter (MultiMesh): clover, leaf litter, tiny flowers. Vertex COLOR is the
// colour; INSTANCE_CUSTOM.r shifts it a little.
varying vec3 wpos;
varying float rnd;

void vertex() {
	rnd = INSTANCE_CUSTOM.r;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = COLOR.rgb * (0.85 + 0.3 * rnd);
	c = mix(c, vec3(0.9, 0.93, 0.98), clamp(hog_snow, 0.0, 1.0));
	c *= 1.0 - hog_wet * 0.2;
	c = hog_dim(c, hog_region_light(wpos));
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
}
