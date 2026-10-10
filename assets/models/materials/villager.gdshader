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
// outfit_style.x = 2 is Era 3 town clothes (see the branch below).
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
		} else if (outfit_style.x > 1.5) {
			// Era 3: town clothes. Men (outfit_style.y = 1): a coat with turned-back cuffs
			// over breeches, white stockings and buckled black shoes; women: a bodice and
			// full skirt with a hem band over a white chemise. outfit_style.z: 1 = waistcoat
			// (men, brass buttons) or laced stomacher (women) in trim_color, 2 = apron
			// (leather for men, white for women). A white collar or cravat at the neck.
			bool men = outfit_style.y > 0.5;
			bool front = COLOR.b > 0.5;
			bool arm = h > 0.70 && h < 0.9 && ax > 0.26;
			bool shirt = (arm && ax < outfit_style.w) || (h > outfit_cut.x - 0.02 && h < outfit_cut.y + 0.012 && ax < 0.26);
			if (h < 0.055) {
				c = vec3(0.11, 0.1, 0.11);                            // black shoes
				if (men && front && h > 0.03 && h < 0.045) {
					c = vec3(0.78, 0.63, 0.3);                        // brass buckles
				}
			} else if (covered) {
				c = cloth_color.rgb;
				bool cuff = h > 0.70 && ax > 0.26 && outfit_cut.z - ax < 0.045;
				bool hem = !men && h - outfit_cut.x < 0.03;
				if (cuff || hem) {
					c = trim_color.rgb;
				}
				if (outfit_cut.y - h < 0.022 && ax < 0.26) {
					c = under_color.rgb;                              // collar, cravat
				}
				bool panel = front && h > outfit_cut.w - 0.13 && h < outfit_cut.y - 0.022;
				if (outfit_style.z > 0.5 && outfit_style.z < 1.5 && panel && ax < 0.085) {
					c = trim_color.rgb;                               // waistcoat / stomacher
					if (ax < 0.014) {
						float f = fract(h * 48.0);
						if (men && f < 0.3) {
							c = vec3(0.82, 0.66, 0.3);                // brass buttons
						} else if (!men && f < 0.4) {
							c = vec3(0.92, 0.88, 0.8);                // lacing
						}
					}
				}
				if (men && front && h < outfit_cut.w - 0.03 && ax < 0.045) {
					c = cloth_color.rgb * vec3(0.42, 0.4, 0.42);      // the coat opens over the breeches
				}
				if (outfit_style.z > 1.5 && front && ax < 0.14 && h > max(outfit_cut.x + 0.03, 0.22) && h < outfit_cut.w + 0.02) {
					c = men ? vec3(0.42, 0.28, 0.18) : vec3(0.95, 0.93, 0.88);   // apron
				}
			} else if (shirt) {
				c = under_color.rgb;
				if (arm && outfit_style.w - ax < 0.03) {
					c = vec3(1.0, 0.98, 0.94);                         // lace frill
				}
			} else if (men && h < outfit_cut.x) {
				c = h > 0.27 ? cloth_color.rgb * vec3(0.42, 0.4, 0.42)   // breeches
					: vec3(0.9, 0.88, 0.84);                        // stockings
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
