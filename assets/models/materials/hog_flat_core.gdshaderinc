// Hands of God shared "warm low-poly" shading core (DESIGN 12.1, 12.2, 14.4).
// Included by hog_flat.gdshader (single sided) and hog_flat_2s.gdshader (double sided).
//
// Every imported model is drawn with this shader: its source colour (flat albedo, or a
// texture such as Kenney's colormap) is graded toward the current era palette:
//   0. source_saturation tames packs with loud colours,
//   1. palette pull: the colour's chroma is pulled toward the nearest palette swatch while
//      keeping its own brightness (palette_pull 0 = untouched, 1 = fully remapped),
//   2. era saturation and a warm multiply tint (era_tint),
//   3. a per-instance tint (instance_tint) for gameplay states (picked bush, dimmed region).
// Lighting is a soft two-tone toon ramp (diffuse_toon, roughness sets the softness) with
// specular off and a faint rim, identical for every asset.
//
// The era uniforms are written by ArtPalette.apply_era() on every material it created.

const int PALETTE_SIZE = 10;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform bool use_texture = false;
uniform float palette_pull : hint_range(0.0, 1.0) = 0.3;
uniform float source_saturation : hint_range(0.0, 1.5) = 1.0;  // tames loud packs (Kenney) before the pull
uniform float softness : hint_range(0.05, 1.0) = 0.45;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.12;

uniform vec4 palette[PALETTE_SIZE] : source_color;
uniform vec4 era_tint : source_color = vec4(1.0);
uniform float era_saturation = 1.0;

instance uniform vec4 instance_tint : source_color = vec4(1.0);

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 hog_grade(vec3 c) {
	float l = dot(c, LUMA);
	c = mix(vec3(l), c, source_saturation);
	vec3 cc = c - vec3(l);
	vec3 best = c;
	float best_d = 1e9;
	for (int i = 0; i < PALETTE_SIZE; i++) {
		vec3 p = palette[i].rgb;
		if (palette[i].a < 0.5) {
			continue;
		}
		float pl = dot(p, LUMA);
		vec3 pc = p - vec3(pl);
		float d = length(cc - pc) + 0.35 * abs(l - pl);
		if (d < best_d) {
			best_d = d;
			// palette chroma, scaled to the source brightness
			best = clamp(pc * clamp(l / max(pl, 0.02), 0.4, 1.6) + vec3(l), 0.0, 1.0);
		}
	}
	vec3 g = mix(c, best, palette_pull);
	float gl = dot(g, LUMA);
	g = mix(vec3(gl), g, era_saturation);
	return g * era_tint.rgb;
}

void fragment() {
	vec4 base = albedo_color;
	if (use_texture) {
		base *= texture(albedo_texture, UV);
	}
	ALBEDO = hog_grade(base.rgb) * instance_tint.rgb;
	ROUGHNESS = softness;
	RIM = rim_strength;
	RIM_TINT = 0.6;
}
