shader_type spatial;
// Translucent, softly glowing glove for the empty hand: mostly a luminous rim,
// so it never hides what is under it. Drawn after hand_depth (a depth-only
// pass of the same mesh) so only the front-most layer shows.
render_mode blend_mix, depth_draw_never, cull_back, diffuse_lambert_wrap, specular_schlick_ggx;
#include "res://assets/textures/shaders/hand_glove.gdshaderinc"

// 0 = ghost (rim only), 1 = solid
uniform float solidity : hint_range(0.0, 1.0) = 0.3;
// overall fade (under HUD panels, near screen edges)
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - ndv, rim_power);
	ALBEDO = glove_albedo(COLOR, UV2);
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;
	BACKLIGHT = glow_color.rgb * 0.25;
	EMISSION = glove_emission(ndv) * (1.0 + (1.0 - solidity) * 1.2) + ALBEDO * 0.1 * (1.0 - solidity);
	float ghost = clamp(0.16 + fres * 1.1, 0.0, 1.0);
	ALPHA = clamp(mix(ghost, 1.0, solidity), 0.0, 1.0) * opacity;
}

void light() {
	DIFFUSE_LIGHT += glove_diffuse(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
	float h = pow(clamp(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0, 1.0), 24.0);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * h * 0.08 / PI;
}
