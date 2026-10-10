shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
#include "res://scenes/world/shaders/hog_common.gdshaderinc"

// The valley ground: a stylised, painterly blend of grass, dirt paths, rock, mud and
// forest floor. Procedural by default; every layer also has an optional texture slot
// (albedo + normal) sampled in world space with anti-repetition, which can be pulled
// toward the flat style with posterise / softness / palette-tint.
//
// Inputs baked by scripts/world/terrain.gd:
//   COLOR  r grass, g worn dirt (paths), b rock, a bank (mud, or sand on the coast)
//   UV2    x shore band (1 at the waterline), y coast (1 = sandy beach, 0 = river mud)
//   ground_mask over mask_rect (world x, z, width, depth):
//          r contact shadow at the feet of trees, rocks and props, g canopy (forest
//          floor and leaf litter), b moss (cliff foot, boulders)

uniform sampler2D noise_large : filter_linear_mipmap, repeat_enable;   // big colour patches
uniform sampler2D noise_mid : filter_linear_mipmap, repeat_enable;     // clumps, transitions
uniform sampler2D noise_fine : filter_linear_mipmap, repeat_enable;    // mottling
uniform sampler2D ground_mask : filter_linear, repeat_disable, hint_default_black;
uniform vec4 mask_rect = vec4(-220.0, -110.0, 440.0, 250.0);

// --- procedural palette (season tint comes from hog_grass on top)
uniform vec4 grass_deep : source_color = vec4(0.25, 0.42, 0.17, 1.0);
uniform vec4 grass_lush : source_color = vec4(0.36, 0.52, 0.21, 1.0);
uniform vec4 grass_yellow : source_color = vec4(0.55, 0.56, 0.26, 1.0);
uniform vec4 grass_bleached : source_color = vec4(0.70, 0.66, 0.40, 1.0);
uniform vec4 dirt_color : source_color = vec4(0.52, 0.38, 0.24, 1.0);
uniform vec4 dirt_light : source_color = vec4(0.66, 0.53, 0.36, 1.0);
uniform vec4 rock_color : source_color = vec4(0.50, 0.48, 0.45, 1.0);
uniform vec4 mud_color : source_color = vec4(0.26, 0.21, 0.15, 1.0);
uniform vec4 sand_color : source_color = vec4(0.76, 0.68, 0.50, 1.0);
uniform vec4 forest_color : source_color = vec4(0.24, 0.27, 0.14, 1.0);
uniform vec4 litter_color : source_color = vec4(0.55, 0.36, 0.17, 1.0);
uniform vec4 moss_color : source_color = vec4(0.30, 0.42, 0.14, 1.0);
uniform float ao_strength : hint_range(0.0, 1.0) = 0.55;
uniform float transition_noise : hint_range(0.0, 1.0) = 0.55;

// --- optional texture layers (world-space, anti-repetition)
uniform bool use_grass_tex = false;
uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_dirt_tex = false;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_rock_tex = false;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_mud_tex = false;
uniform sampler2D mud_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_forest_tex = false;
uniform sampler2D forest_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tex_tiling = vec4(0.25, 0.3, 0.12, 0.3);   // metres^-1: grass, dirt, rock, mud
uniform float forest_tiling = 0.25;
uniform float posterize_steps : hint_range(0.0, 32.0) = 0.0;     // 0 = off
uniform float detail_softness : hint_range(0.0, 6.0) = 0.0;      // mip bias: blurs photo detail
uniform float palette_tint : hint_range(0.0, 1.0) = 0.5;         // pull textures to the procedural colour
uniform float normal_strength : hint_range(0.0, 2.0) = 0.6;

// --- desire paths (scripts/world/paths.gd): r = wear / CAP, g = paved
global uniform sampler2D hog_wear : filter_linear, repeat_disable;
global uniform vec4 hog_wear_rect;
// thresholds on the blurred wear: worn grass, dirt track, dirt road
uniform vec3 wear_levels = vec3(0.026, 0.094, 0.24);
uniform vec4 worn_color : source_color = vec4(0.58, 0.55, 0.32, 1.0);
uniform vec4 paving_color : source_color = vec4(0.62, 0.58, 0.52, 1.0);

varying vec3 wpos;
varying vec3 wnorm;

// The wear map with a little blur, so a trail reads as a soft-edged ribbon.
vec2 wear_at(vec2 xz) {
	vec2 uv = (xz - hog_wear_rect.xy) / hog_wear_rect.zw;
	if (uv.x <= 0.0 || uv.y <= 0.0 || uv.x >= 1.0 || uv.y >= 1.0) {
		return vec2(0.0);
	}
	vec2 o = 0.8 / hog_wear_rect.zw;
	vec2 c = texture(hog_wear, uv).rg * 0.36;
	c += texture(hog_wear, uv + vec2(o.x, o.y)).rg * 0.16;
	c += texture(hog_wear, uv + vec2(-o.x, o.y)).rg * 0.16;
	c += texture(hog_wear, uv + vec2(o.x, -o.y)).rg * 0.16;
	c += texture(hog_wear, uv + vec2(-o.x, -o.y)).rg * 0.16;
	return c;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float nz(sampler2D t, vec2 p) {
	return texture(t, p).r;
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// Two samples at different rotations and offsets, blended by a low-frequency noise,
// so a tiling texture does not show its grid.
vec4 sample_anti(sampler2D t, vec2 uv, float blend) {
	float bias = detail_softness;
	vec2 uv2 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * uv * 0.87 + vec2(0.37, 0.71);
	vec4 a = texture(t, uv, bias);
	vec4 b = texture(t, uv2, bias);
	return mix(a, b, smoothstep(0.35, 0.65, blend));
}

// A texture pulled toward the flat style: posterised, then tinted to the procedural colour.
vec3 styled(vec3 tex, vec3 proc) {
	if (posterize_steps > 0.5) {
		tex = floor(tex * posterize_steps + 0.5) / posterize_steps;
	}
	vec3 tinted = proc * clamp(luma(tex) / max(luma(proc), 0.05), 0.5, 1.6);
	return mix(tex, tinted, palette_tint);
}

void fragment() {
	vec2 xz = wpos.xz;
	float nl = nz(noise_large, xz * 0.0035);
	float nl2 = nz(noise_large, xz * 0.011 + vec2(0.31, 0.77));
	float nm = nz(noise_mid, xz * 0.045);
	float nf = nz(noise_fine, xz * 0.35);
	float nf2 = nz(noise_fine, xz * 1.3 + vec2(0.5, 0.2));
	vec2 muv = (xz - mask_rect.xy) / mask_rect.zw;
	vec3 mask = vec3(0.0);
	if (muv.x > 0.0 && muv.y > 0.0 && muv.x < 1.0 && muv.y < 1.0) {
		mask = texture(ground_mask, muv).rgb;
	}

	// ---- layer weights with soft, noisy edges
	vec4 w = COLOR;
	float tn = (nm - 0.5) * transition_noise + (nf - 0.5) * transition_noise * 0.5;
	float grass_w = clamp(w.r + tn * 0.8, 0.0, 1.0);
	float dirt_w = clamp(w.g * 1.15 - tn * 0.9 - 0.12, 0.0, 1.0);
	float rock_w = clamp(w.b * 1.3 + (nm - 0.5) * 0.6, 0.0, 1.0);
	float bank_w = clamp(w.a * 1.2 + (nf - 0.5) * 0.4, 0.0, 1.0);
	float forest_w = clamp(mask.g * 1.2 + (nm - 0.5) * 0.5, 0.0, 1.0) * (1.0 - rock_w) * (1.0 - dirt_w * 0.7);
	// sharpen a little: painterly patches rather than smooth gradients
	grass_w = smoothstep(0.1, 0.75, grass_w);
	dirt_w = smoothstep(0.15, 0.7, dirt_w);
	rock_w = smoothstep(0.2, 0.65, rock_w);
	bank_w = smoothstep(0.15, 0.7, bank_w);
	forest_w = smoothstep(0.15, 0.75, forest_w);

	// ---- grass: several greens in big patches, mottled
	float season = clamp(dot(hog_grass.rgb, vec3(1.0)) , 0.0, 3.0);
	vec3 g = mix(grass_deep.rgb, grass_lush.rgb, smoothstep(0.3, 0.6, nl));
	g = mix(g, grass_yellow.rgb, smoothstep(0.55, 0.75, nl2) * 0.8);
	g = mix(g, grass_bleached.rgb, smoothstep(0.68, 0.82, nl * 0.6 + nm * 0.4) * 0.6);
	g *= 0.88 + 0.22 * nf + 0.08 * (nf2 - 0.5);
	// season tint: hog_grass is spring green, summer gold, autumn rust, winter grey
	g *= hog_grass.rgb / vec3(0.36, 0.55, 0.23);
	g = mix(g, g * 0.82, smoothstep(0.62, 0.8, nf2) * 0.6);        // clumps in shadow
	vec3 grass = g;

	// ---- dirt: warm, dusty in the middle of a path, with pebble speckles
	vec3 dirt = mix(dirt_color.rgb, dirt_light.rgb, smoothstep(0.3, 0.8, nm) * 0.6 + w.g * 0.25);
	dirt *= 0.9 + 0.2 * nf;
	dirt = mix(dirt, dirt_light.rgb * 1.1, smoothstep(0.82, 0.9, nf2) * 0.7);   // pebbles
	dirt = mix(dirt, dirt * 0.75, smoothstep(0.1, 0.0, nf2) * 0.6);

	// ---- rock: grey strata
	float strata = sin(wpos.y * 2.2 + nm * 6.0) * 0.5 + 0.5;
	vec3 rock = rock_color.rgb * (0.82 + 0.18 * strata + 0.12 * (nf - 0.5));
	rock = mix(rock, hog_pal_2.rgb * 1.6, smoothstep(0.65, 0.85, nm) * 0.25);

	// ---- bank: mud on the river, sand on the coast
	vec3 mud = mud_color.rgb * (0.85 + 0.25 * nf);
	vec3 sand = sand_color.rgb * (0.92 + 0.12 * nf);
	vec3 bank = mix(mud, sand, UV2.y);

	// ---- forest floor: dark loam with leaf litter
	vec3 forest = forest_color.rgb * (0.85 + 0.3 * nf);
	forest = mix(forest, litter_color.rgb, smoothstep(0.55, 0.8, nf2) * 0.65);
	forest = mix(forest, g * 0.7, smoothstep(0.6, 0.85, nm) * 0.4);

	// ---- optional textures
	vec2 uvg = xz * tex_tiling.x;
	if (use_grass_tex) grass = styled(sample_anti(grass_albedo, uvg, nl2).rgb, grass);
	if (use_dirt_tex) dirt = styled(sample_anti(dirt_albedo, xz * tex_tiling.y, nl2).rgb, dirt);
	if (use_rock_tex) {
		// triplanar for steep faces
		vec3 bw = pow(abs(wnorm), vec3(4.0));
		bw /= (bw.x + bw.y + bw.z);
		vec3 rx = texture(rock_albedo, wpos.zy * tex_tiling.z, detail_softness).rgb;
		vec3 ry = sample_anti(rock_albedo, wpos.xz * tex_tiling.z, nl2).rgb;
		vec3 rz = texture(rock_albedo, wpos.xy * tex_tiling.z, detail_softness).rgb;
		rock = styled(rx * bw.x + ry * bw.y + rz * bw.z, rock);
	}
	if (use_mud_tex) bank = styled(sample_anti(mud_albedo, xz * tex_tiling.w, nl2).rgb, bank);
	if (use_forest_tex) forest = styled(sample_anti(forest_albedo, xz * forest_tiling, nl2).rgb, forest);

	// ---- desire paths: worn grass, a dirt track, a beaten road, paving
	vec2 wr = wear_at(xz);
	float wv = wr.r + (nm - 0.5) * 0.035 + (nf - 0.5) * 0.025;
	float worn_k = smoothstep(wear_levels.x, wear_levels.x + 0.05, wv);
	float track_k = smoothstep(wear_levels.y - 0.015, wear_levels.y + 0.05, wv);
	float road_k = smoothstep(wear_levels.z - 0.03, wear_levels.z + 0.08, wv);
	float paved_k = smoothstep(0.25, 0.6, wr.g);
	forest_w *= 1.0 - track_k;
	grass = mix(grass, mix(grass, worn_color.rgb, 0.6 + 0.4 * nf), worn_k * 0.75 * (1.0 - track_k));
	dirt_w = max(dirt_w, track_k * mix(0.6, 0.95, smoothstep(0.3, 0.7, nf2)));
	dirt_w = max(dirt_w, road_k);
	// a beaten road: packed and pale in the middle, darker ruts at its edges
	vec3 road_dirt = mix(dirt, dirt_light.rgb * (0.95 + 0.1 * nf), road_k * 0.55);
	road_dirt *= 1.0 - (track_k - road_k) * 0.12;
	dirt = mix(dirt, road_dirt, track_k);

	// ---- blend: grass base, then forest floor, dirt, bank, rock on top
	vec3 c = grass;
	c = mix(c, forest, forest_w);
	c = mix(c, dirt, dirt_w);
	if (paved_k > 0.001) {
		// cobbles: offset rows of rounded setts with dark joints
		vec2 q = xz * vec2(1.7, 2.3);
		q.x += step(1.0, mod(floor(q.y), 2.0)) * 0.5;
		vec2 f = fract(q);
		float joint = smoothstep(0.03, 0.13, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
		float shade = 0.82 + 0.3 * hog_hash(floor(q));
		vec3 sett = paving_color.rgb * shade * (0.92 + 0.12 * nf);
		vec3 paving = mix(dirt * 0.55, sett, joint);
		c = mix(c, paving, paved_k);
	}
	c = mix(c, bank, bank_w);
	c = mix(c, rock, rock_w);
	// moss creeping over rock edges, boulders and the cliff foot
	float moss = clamp(mask.b * 1.3 + rock_w * (1.0 - rock_w) * 2.4 * smoothstep(0.4, 0.7, nm), 0.0, 1.0);
	moss *= smoothstep(0.35, 0.6, nf * 0.5 + nm * 0.5 + 0.1);
	c = mix(c, moss_color.rgb * (0.85 + 0.3 * nf), moss * 0.85);

	// ---- shoreline: a lighter wet band right at the waterline
	float shore = UV2.x;
	c = mix(c, c * 0.7, smoothstep(0.0, 0.6, shore) * 0.5);                     // damp soil
	c = mix(c, mix(c, vec3(0.78, 0.74, 0.62), 0.45), smoothstep(0.75, 1.0, shore) * (0.6 + 0.4 * nf));

	// ---- fake contact AO at the feet of trees, rocks and props, and under canopy
	float ao = clamp(mask.r * 1.1 + mask.g * 0.25, 0.0, 1.0);
	c *= 1.0 - ao * ao_strength;

	// ---- weather, snow and locked regions
	float sm = hog_snow_mask(wpos, wnorm.y);
	// trodden snow: the village's paths stay as packed, muddied ribbons
	float trod = max(track_k, worn_k * 0.3);
	vec3 snow_c = mix(vec3(0.9, 0.93, 0.98), mix(c, vec3(0.7, 0.68, 0.66), 0.55), trod * 0.8);
	c = mix(c, snow_c, sm * (1.0 - road_k * 0.3 - paved_k * 0.45));
	c *= 1.0 - hog_wet * 0.22;
	c = hog_dim(c, hog_region_light(wpos));
	ALBEDO = c;

	// ---- normals from the texture layers (if any)
	if (use_grass_tex || use_dirt_tex || use_rock_tex || use_mud_tex || use_forest_tex) {
		vec3 n = vec3(0.5, 0.5, 1.0);
		vec3 acc = vec3(0.0);
		float tot = 0.0;
		float wg = (1.0 - forest_w) * (1.0 - dirt_w) * (1.0 - bank_w) * (1.0 - rock_w);
		if (use_grass_tex) { acc += sample_anti(grass_normal, uvg, nl2).rgb * wg; tot += wg; }
		if (use_dirt_tex) { acc += sample_anti(dirt_normal, xz * tex_tiling.y, nl2).rgb * dirt_w; tot += dirt_w; }
		if (use_rock_tex) { acc += sample_anti(rock_normal, xz * tex_tiling.z, nl2).rgb * rock_w; tot += rock_w; }
		if (use_mud_tex) { acc += sample_anti(mud_normal, xz * tex_tiling.w, nl2).rgb * bank_w; tot += bank_w; }
		if (use_forest_tex) { acc += sample_anti(forest_normal, xz * forest_tiling, nl2).rgb * forest_w; tot += forest_w; }
		if (tot > 0.001) {
			n = mix(vec3(0.5, 0.5, 1.0), acc / tot, clamp(tot, 0.0, 1.0));
		}
		NORMAL_MAP = n;
		NORMAL_MAP_DEPTH = normal_strength;
	}
	ROUGHNESS = mix(0.95, 0.5, max(hog_wet * (1.0 - grass_w * 0.5), smoothstep(0.7, 1.0, shore) * 0.6));
	SPECULAR = 0.25;
}
