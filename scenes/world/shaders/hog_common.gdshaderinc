// Shared world look: era palette, season, weather and the locked-region dim.
// Globals are registered at runtime by scripts/world/look.gd (Look.register_globals).
global uniform vec4 hog_pal_0;        // era colour 0 (Era 1: ochre)
global uniform vec4 hog_pal_1;        // era colour 1 (Era 1: moss green)
global uniform vec4 hog_pal_2;        // era colour 2 (Era 1: charcoal)
global uniform vec4 hog_pal_3;        // era colour 3 (Era 1: firelight orange)
global uniform vec4 hog_grass;        // season grass colour
global uniform vec4 hog_leaf;         // season broadleaf colour
global uniform float hog_snow;        // 0..1 winter snow cover on upward faces
global uniform float hog_frost;       // 0..1 cold-snap frost
global uniform float hog_wet;         // 0..1 rain wetness
global uniform float hog_wind;        // wind strength
global uniform sampler2D hog_region_mask : filter_linear, repeat_disable;   // r = 1 open, 0 locked
global uniform vec4 hog_map_rect;     // x0, z0, width, depth of the mask

float hog_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hog_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hog_hash(i);
	float b = hog_hash(i + vec2(1.0, 0.0));
	float c = hog_hash(i + vec2(0.0, 1.0));
	float d = hog_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float hog_region_light(vec3 wpos) {
	vec2 uv = (wpos.xz - hog_map_rect.xy) / hog_map_rect.zw;
	vec2 o = 1.25 / vec2(textureSize(hog_region_mask, 0));   // soft edges between regions
	float l = texture(hog_region_mask, uv).r * 0.4;
	l += texture(hog_region_mask, uv + vec2(o.x, o.y)).r * 0.15;
	l += texture(hog_region_mask, uv + vec2(-o.x, o.y)).r * 0.15;
	l += texture(hog_region_mask, uv + vec2(o.x, -o.y)).r * 0.15;
	l += texture(hog_region_mask, uv + vec2(-o.x, -o.y)).r * 0.15;
	return smoothstep(0.0, 1.0, l);
}

// Locked regions sink into a pale, cool haze (the mist sheets of
// scripts/world/regions.gd hang over it): desaturated, low-contrast shapes.
vec3 hog_dim(vec3 c, float lit) {
	float g = dot(c, vec3(0.3, 0.55, 0.15));
	vec3 locked = mix(vec3(g), c, 0.35);
	locked = mix(locked, vec3(0.62, 0.66, 0.72), 0.55);
	return mix(locked, c, smoothstep(0.0, 1.0, lit));
}

// Snow that settles on upward faces. `up` is the world normal's y.
float hog_snow_mask(vec3 wpos, float up) {
	float n = hog_noise(wpos.xz * 0.35) * 0.35 + hog_noise(wpos.xz * 0.05) * 0.4;
	float cover = max(hog_snow, hog_frost * 0.55);
	float s = smoothstep(0.45, 0.8, up) * smoothstep(1.0 - cover, 1.15 - cover, n + 0.25);
	float peaks = smoothstep(62.0, 85.0, wpos.y + n * 10.0) * smoothstep(0.35, 0.7, up);
	return clamp(max(s * step(0.01, cover), peaks), 0.0, 1.0);
}
