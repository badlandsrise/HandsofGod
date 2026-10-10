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
// outfit_style.x = 2 is Era 3 town clothes, 3 is Era 4 work clothes and flight suits
// (see the branches below).
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
		} else if (outfit_style.x > 2.5) {
			// Era 4: the clothes of their trade. outfit_style.y picks the garment:
			// 0 = overalls (bib and braces in cloth_color over a rolled-sleeve shirt in
			// under_color, work boots), 1 = lab coat (white, to the knee, the job colour
			// showing as the shirt at the open front, a tie in trim_color), 2 = day clothes
			// (outfit_style.z = 1: a suit jacket with lapels, white shirt and tie; z = 0: a
			// dress with a white collar, a belt and shoes in trim_color), 3 = the crew's
			// flight suit (white, navy boots and gloves, orange arm bands and leg stripes in
			// trim_color, a chrome neck ring and zip, the mission patch on the chest).
			int kind = int(outfit_style.y + 0.5);
			bool front = COLOR.b > 0.5;
			bool arm = h > 0.70 && h < 0.9 && ax > 0.26;
			bool limb_or_body = h > 0.055 && h < outfit_cut.y && (ax < 0.26 || arm);
			vec3 navy = vec3(0.11, 0.16, 0.29);
			if (kind == 0) {
				bool bib = front && ax < 0.105 && h > outfit_cut.w && h < 0.785;
				bool strap = abs(ax - 0.088) < 0.014 && h > outfit_cut.w && h < outfit_cut.y;
				if (h < 0.055) {
					c = vec3(0.24, 0.16, 0.1);                          // work boots
				} else if (h < outfit_cut.w + 0.01 && ax < 0.26) {
					c = cloth_color.rgb;                                // trousers
					if (front && ax > 0.05 && ax < 0.1 && h > 0.36 && h < 0.42) {
						c = cloth_color.rgb * 0.8;                      // knee patch pocket
					}
				} else if (bib || strap) {
					c = cloth_color.rgb;
					if (front && ax < 0.05 && h > 0.66 && h < 0.72) {
						c = cloth_color.rgb * 0.82;                     // bib pocket
					}
					if (front && strap && abs(h - 0.775) < 0.009) {
						c = vec3(0.82, 0.66, 0.3);                      // brass buckles
					}
				} else if ((h > outfit_cut.w && ax < 0.26) || (arm && ax < outfit_style.w)) {
					c = under_color.rgb;                                // shirt, sleeves rolled
					if (arm && outfit_style.w - ax < 0.025) {
						c = under_color.rgb * 0.86;                     // the roll
					}
				}
			} else if (kind == 1) {
				bool coat = covered;
				if (h < 0.055) {
					c = vec3(0.12, 0.11, 0.12);
				} else if (coat) {
					c = vec3(0.95, 0.95, 0.93);                         // the white coat
					if (front && ax < 0.034 && h > outfit_cut.w + 0.06) {
						c = cloth_color.rgb;                            // shirt at the open front
						if (ax < 0.011 && h < outfit_cut.y - 0.02) {
							c = trim_color.rgb;                         // tie
						}
					}
					if (front && abs(ax - 0.045) < 0.006 && h < outfit_cut.w + 0.06 && fract(h * 30.0) < 0.3) {
						c = vec3(0.7, 0.72, 0.75);                      // buttons
					}
					if (front && ax > 0.075 && ax < 0.115 && h > 0.735 && h < 0.765) {
						c = vec3(0.86, 0.87, 0.88);                     // breast pocket
						if (ax < 0.09 && h > 0.755) {
							c = trim_color.rgb;                         // pens
						}
					}
				} else if (h < outfit_cut.x && ax < 0.26) {
					c = vec3(0.26, 0.28, 0.32);                         // grey trousers
				}
			} else if (kind == 2) {
				bool men = outfit_style.z > 0.5;
				if (h < 0.055) {
					c = men ? vec3(0.1, 0.09, 0.1) : trim_color.rgb;    // shoes
				} else if (covered) {
					c = cloth_color.rgb;
					bool open = front && h > 0.66 && ax < (h - 0.66) * 0.55;
					if (men && open) {
						c = under_color.rgb;                            // shirt between the lapels
						if (ax < 0.012) {
							c = trim_color.rgb;                         // tie
						}
					}
					if (men && front && abs(ax - (h - 0.66) * 0.55) < 0.008 && h > 0.66) {
						c = cloth_color.rgb * 0.7;                      // lapel edge
					}
					if (!men && outfit_cut.y - h < 0.024 && ax < 0.2) {
						c = under_color.rgb;                            // white collar
					}
					if (!men && abs(h - outfit_cut.w) < 0.012) {
						c = trim_color.rgb;                             // belt
					}
					if (!men && h < outfit_cut.w && fract((h + ax) * 26.0) < 0.12 && fract((h - ax) * 26.0) < 0.12) {
						c = mix(cloth_color.rgb, under_color.rgb, 0.7); // a little print on the skirt
					}
				} else if (men && h < outfit_cut.x && ax < 0.26) {
					c = cloth_color.rgb * vec3(0.55, 0.55, 0.6);        // trousers
				}
			} else {
				vec3 suit = vec3(0.93, 0.93, 0.9);
				if (h < 0.075) {
					c = navy;                                           // boots
				} else if (limb_or_body) {
					c = suit;
					if (arm && ax > outfit_cut.z) {
						c = navy;                                       // gloves
					}
					if (arm && abs(ax - 0.36) < 0.018) {
						c = trim_color.rgb;                             // arm band
					}
					if (!arm && h < outfit_cut.w && ax > 0.105 && ax < 0.13) {
						c = trim_color.rgb;                             // leg stripe
					}
					if (abs(h - outfit_cut.w) < 0.013 && ax < 0.26) {
						c = navy;                                       // belt
					}
					if (front && ax < 0.006 && h > outfit_cut.w && h < outfit_cut.y - 0.02) {
						c = vec3(0.7, 0.72, 0.76);                      // zip
					}
					float pd = length(vec2(ax * 0.5, h - 0.745));
					if (front && pd < 0.022) {
						c = pd < 0.015 ? navy : trim_color.rgb;         // mission patch
						if (pd < 0.005) {
							c = vec3(0.85, 0.68, 0.3);
						}
					}
					if (outfit_cut.y - h < 0.022 && ax < 0.26) {
						c = vec3(0.72, 0.74, 0.78);                     // neck ring
					}
				}
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
