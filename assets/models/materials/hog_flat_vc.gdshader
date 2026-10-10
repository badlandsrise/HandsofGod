// hog_flat with vertex colours (sRGB) multiplied into the albedo: the wild animals'
// belly, back and muzzle shading. See hog_flat_core.gdshaderinc.
shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_back;

#define HOG_CUSTOM_FRAGMENT
#include "res://assets/models/materials/hog_flat_core.gdshaderinc"

varying vec3 v_col;

void vertex() {
	// sRGB -> linear, like the albedo uniform
	v_col = mix(COLOR.rgb / 12.92, pow((COLOR.rgb + 0.055) / 1.055, vec3(2.4)), step(0.04045, COLOR.rgb));
}

void fragment() {
	vec4 base = albedo_color;
	if (use_texture) {
		base *= texture(albedo_texture, UV);
	}
	ALBEDO = hog_grade(base.rgb * v_col) * instance_tint.rgb;
	ROUGHNESS = softness;
	RIM = rim_strength;
	RIM_TINT = 0.6;
}
