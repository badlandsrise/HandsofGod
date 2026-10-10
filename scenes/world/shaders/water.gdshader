shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx, depth_draw_opaque, cull_disabled;
#include "res://scenes/world/shaders/hog_common.gdshaderinc"

uniform vec4 shallow : source_color = vec4(0.32, 0.6, 0.62, 1.0);
uniform vec4 deep : source_color = vec4(0.1, 0.3, 0.42, 1.0);
uniform float flow_speed = 0.6;
uniform vec2 flow_dir = vec2(1.0, 0.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(TIME * 1.2 + wpos.x * 0.3 + wpos.z * 0.2) * 0.04;
}

void fragment() {
	vec2 p = wpos.xz * 0.25 - flow_dir * TIME * flow_speed;
	float n1 = hog_noise(p);
	float n2 = hog_noise(p * 2.3 + vec2(TIME * 0.2, 0.0));
	vec3 nrm = normalize(vec3((n1 - 0.5) * 0.6, 1.0, (n2 - 0.5) * 0.6));
	NORMAL = (VIEW_MATRIX * vec4(nrm, 0.0)).xyz;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 c = mix(deep.rgb, shallow.rgb, 0.4 + 0.3 * n1);
	c = mix(c, vec3(0.75, 0.82, 0.86), fres * 0.5);
	// foam flecks and rain rings
	float fl = hog_noise(wpos.xz * 1.7 - flow_dir * TIME * flow_speed * 3.0);
	c += vec3(smoothstep(0.86, 0.97, fl * n2 * 1.6)) * 0.12;
	c = mix(c, vec3(0.86, 0.9, 0.95), hog_frost * 0.15);
	c = hog_dim(c, hog_region_light(wpos));
	ALBEDO = c;
	ROUGHNESS = 0.18 + hog_wet * 0.2;
	METALLIC = 0.0;
	SPECULAR = 0.35;
	ALPHA = 0.82;
}
