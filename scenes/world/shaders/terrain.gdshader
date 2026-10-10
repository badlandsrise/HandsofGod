shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
#include "res://scenes/world/shaders/hog_common.gdshaderinc"

// COLOR = splat weights: r grass, g dirt, b rock, a sand.
varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec4 w = COLOR;
	float n = hog_noise(wpos.xz * 0.21);
	float n2 = hog_noise(wpos.xz * 0.033);
	vec3 grass = hog_grass.rgb * (0.82 + 0.3 * n) * mix(0.9, 1.08, n2);
	vec3 dirt = mix(hog_pal_0.rgb * 0.78, vec3(0.42, 0.32, 0.22), 0.45) * (0.9 + 0.2 * n);
	vec3 rock = mix(hog_pal_2.rgb, vec3(0.56, 0.53, 0.5), 0.55) * (0.85 + 0.25 * n2 + 0.1 * n);
	vec3 sand = vec3(0.74, 0.66, 0.5) * (0.92 + 0.12 * n);
	// break up the splat edges with noise
	float sum = w.r + w.g + w.b + w.a + 0.0001;
	vec3 c = (grass * w.r + dirt * w.g + rock * w.b + sand * w.a) / sum;
	float sm = hog_snow_mask(wpos, wnorm.y);
	c = mix(c, vec3(0.9, 0.93, 0.98), sm);
	c *= 1.0 - hog_wet * 0.22;
	c = hog_dim(c, hog_region_light(wpos));
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.55, hog_wet * (1.0 - w.r * 0.5));
	SPECULAR = 0.3;
}
