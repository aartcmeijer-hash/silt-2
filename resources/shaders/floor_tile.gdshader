shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float uv_scale : hint_range(0.001, 0.1) = 0.01;
uniform float normal_scale : hint_range(0.0, 4.0) = 1.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Returns 4 random offsets for the 4 corners of a UV cell
vec4 hash4(vec2 p) {
	return fract(sin(vec4(
		dot(p, vec2(127.1, 311.7)),
		dot(p, vec2(269.5, 183.3)),
		dot(p, vec2(419.2, 371.9)),
		dot(p, vec2(761.3, 497.1))
	)) * 43758.5453);
}

// Samples a texture without visible tiling by randomly offsetting each cell
vec4 texture_no_tile(sampler2D tex, vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);

	vec4 ofa = hash4(i + vec2(0.0, 0.0));
	vec4 ofb = hash4(i + vec2(1.0, 0.0));
	vec4 ofc = hash4(i + vec2(0.0, 1.0));
	vec4 ofd = hash4(i + vec2(1.0, 1.0));

	// Smooth blend between the 4 corners
	vec2 blend = f * f * (3.0 - 2.0 * f);

	return mix(
		mix(texture(tex, uv + ofa.xy), texture(tex, uv + ofb.xy), blend.x),
		mix(texture(tex, uv + ofc.xy), texture(tex, uv + ofd.xy), blend.x),
		blend.y
	);
}

void fragment() {
	if (world_normal.y > 0.5) {
		// Top face — textured
		vec2 uv = world_pos.xz * uv_scale;
		ALBEDO = texture_no_tile(albedo_texture, uv).rgb;
		ROUGHNESS = texture_no_tile(roughness_texture, uv).r;
		NORMAL_MAP = texture_no_tile(normal_texture, uv).rgb;
		NORMAL_MAP_DEPTH = normal_scale;
	} else {
		// Side faces — solid dark grey
		ALBEDO = vec3(0.15, 0.15, 0.15);
		ROUGHNESS = 0.9;
		METALLIC = 0.0;
	}
}
