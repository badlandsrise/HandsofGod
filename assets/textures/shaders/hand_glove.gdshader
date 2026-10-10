shader_type spatial;
// Solid glove (holding, about to grab). See hand_glove.gdshaderinc.
render_mode cull_back, diffuse_lambert_wrap, specular_schlick_ggx;
#include "res://assets/textures/shaders/hand_glove.gdshaderinc"

void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = glove_albedo(COLOR, UV2);
	ROUGHNESS = 0.85;
	SPECULAR = 0.18;
	// a touch of light bleeding through the cloth at grazing angles
	BACKLIGHT = glow_color.rgb * 0.18;
	EMISSION = glove_emission(ndv);
}

void light() {
	DIFFUSE_LIGHT += glove_diffuse(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
	float h = pow(clamp(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0, 1.0), 24.0);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * h * 0.08 / PI;
}
