shader_type spatial;
//Pixel model props: atlas texel per model unit through the rect wrap, prop face shade, nation dim and rim, sway.
render_mode unshaded, cull_disabled, depth_draw_opaque;

#include "res://Scripts/Map/Shaders/map_common.gdshaderinc"

global uniform sampler2D map_prop_atlas : filter_nearest;
global uniform sampler2D map_prop_light : filter_nearest;
//World units of sway at the model top.
uniform float sway_amp = 1.5;
uniform float rim_r = 0.0;

//Face codes 0 top, 1 s, 2 w, 3 e, 4 n, 5 rs.
const float PROP_SHADE[6] = float[6](1.0, 0.9, 0.96, 0.76, 0.82, 0.98);

varying flat vec4 v_tag;
//Atlas rect in texels: x, y origin, z width, w height.
varying flat vec4 v_rect;

void vertex() {
	vec4 tag = decode_tag(CUSTOM0);
	v_tag = tag;
	v_rect = CUSTOM1;
	VERTEX.y += lift_offset(tag);
	float sway = float(int(tag.w) >> 4);
	VERTEX.x += sway / 15.0 * map_wind * sway_amp * UV2.x * sin(TIME * 1.3 + UV2.y);
}

void fragment() {
	vec4 rect = v_rect;
	vec2 tx = rect.xy + vec2(mod(floor(UV.x), rect.z), rect.w - 1.0 - mod(floor(UV.y), rect.w));
	vec4 col = texelFetch(map_prop_atlas, ivec2(tx), 0);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA = col.a;
	int nation = tag_nation(v_tag);
	vec3 rgb = col.rgb * COLOR.rgb * PROP_SHADE[clamp(tag_face(v_tag), 0, 5)];
	rgb *= 1.0 - MAP_DIM * nation_dim(nation);
	vec3 rim = texelFetch(map_nation_rim, ivec2(clamp(nation, 0, 255), 0), 0).rgb;
	rgb = mix(rgb, rim, rim_r * group_state(KIND_NATION, nation).r);
	bool lit = texelFetch(map_prop_light, ivec2(tx), 0).r > 0.5;
	ALBEDO = srgb_to_linear(lit ? light_emissive(rgb) : day_night(rgb));
}
