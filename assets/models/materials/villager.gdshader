// Villager shader: same soft toon lighting and era grade as hog_flat, but colours come from
// per-instance uniforms so every villager shares three materials (body, hair, eyes).
//
// The body mesh carries a baked region mask in COLOR (see scripts/assets/tools/bake_mask.py):
//   COLOR.r = height / body height (rest pose), COLOR.g = |x| / height * 2, COLOR.b = front.
// outfit_cut decides where the main garment covers the skin:
//   x = hem height, y = neckline height, z = sleeve reach (in COLOR.g units), w = belt height.
// outfit_style.x picks the era's tailoring: 0 = Era 1 hides (one colour, darker hem, belt,
// foot wraps); 1 = Era 2 woven clothes: a linen undershirt with long sleeves (under_color),
// hose or a long skirt (outfit_style.y = 1 covers the legs to the ankle), leather shoes,
// embroidered bands at hem, neck and cuffs (trim_color), a woven belt, and an optional
// apron (outfit_style.z = 1). outfit_style.w = undershirt sleeve reach (0.72 = wrists).
shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_back;

uniform int part = 0;   // 0 body, 1 hair, 2 eyes
uniform float softness : hint_range(0.05, 1.0) = 0.5;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.18;
uniform vec4 era_tint : source_color = vec4(1.0);
uniform float era_saturation = 1.0;

instance uniform vec4 skin_color : source_color = vec4(0.78, 0.58, 0.44, 1.0);
instance uniform vec4 hair_color : source_color = vec4(0.25, 0.17, 0.11, 1.0);
instance uniform vec4 cloth_color : source_color = vec4(0.55, 0.38, 0.24, 1.0);
instance uniform vec4 outfit_cut = vec4(0.36, 0.80, 0.28, 0.53);
instance uniform vec4 instance_tint : source_color = vec4(1.0);
instance uniform vec4 outfit_style = vec4(0.0, 0.0, 0.0, 0.72);
instance uniform vec4 trim_color : source_color = vec4(0.66, 0.26, 0.18, 1.0);
instance uniform vec4 under_color : source_color = vec4(0.91, 0.86, 0.75, 1.0);

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec3 c;
	if (part == 1) {
		c = hair_color.rgb;
	} else if (part == 2) {
		c = vec3(0.04, 0.03, 0.03);
	} else {
		float h = COLOR.r;
		float ax = COLOR.g;
		c = skin_color.rgb;
		bool torso = h > outfit_cut.x && h < outfit_cut.y;
		bool covered = torso && ax < (h > 0.70 ? outfit_cut.z : 0.26);
		if (outfit_style.x < 0.5) {
			if (covered) {
				// a little hand-made variation: darker hem and a belt
				float hem = smoothstep(outfit_cut.x + 0.025, outfit_cut.x, h);
				c = cloth_color.rgb * (1.0 - 0.25 * hem);
				if (abs(h - outfit_cut.w) < 0.012) {
					c = cloth_color.rgb * 0.45;
				}
			} else if (h < 0.055) {
				c = cloth_color.rgb * 0.5;   // hide foot wraps
			}
		} else {
			// Era 2: woven clothes in layers
			bool arm = h > 0.70 && h < 0.9 && ax > 0.26;
			bool shirt = (arm && ax < outfit_style.w) || (h > outfit_cut.x - 0.02 && h < outfit_cut.y + 0.012 && ax < 0.26);
			bool legs = h < outfit_cut.x && h > 0.055 && outfit_style.y > 0.5;
			if (h < 0.055) {
				c = vec3(0.29, 0.19, 0.13);                          // leather shoes
			} else if (covered) {
				c = cloth_color.rgb;
				float band = 0.016;
				bool trim = (h - outfit_cut.x < band) || (outfit_cut.y - h < band)
					|| (h > 0.70 && outfit_cut.z - ax < band && ax > 0.26);
				if (trim) {
					c = trim_color.rgb;
				}
				if (abs(h - outfit_cut.w) < 0.011) {
					c = mix(trim_color.rgb, cloth_color.rgb * 0.5, 0.5);   // woven belt
				}
				if (outfit_style.z > 0.5 && COLOR.b > 0.5 && ax < 0.12 && h > max(outfit_cut.x + 0.03, 0.4) && h < outfit_cut.w - 0.011) {
					c = vec3(0.93, 0.89, 0.8);                       // apron
				}
			} else if (shirt) {
				c = under_color.rgb;
			} else if (legs) {
				c = under_color.rgb * vec3(0.5, 0.46, 0.42);         // undyed wool hose
			}
		}
	}
	float l = dot(c, LUMA);
	c = mix(vec3(l), c, era_saturation) * era_tint.rgb;
	ALBEDO = c * instance_tint.rgb;
	ROUGHNESS = softness;
	RIM = rim_strength;
	RIM_TINT = 0.6;
}
