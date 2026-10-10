shader_type spatial;
//Terrain chunks: palette colour by cell index, face shade, nation dim, rim and lift, then day and night.
render_mode unshaded, cull_back, depth_draw_opaque;

#include "res://Scripts/Map/Shaders/map_common.gdshaderinc"

global uniform sampler2D map_cell_index : filter_nearest;
global uniform sampler2D map_palette : filter_nearest;
//MapConst.WATER_SIDE, set in Resources/Map/Materials/terrain.tres.
uniform float water_side_mul = 1.0;
global uniform sampler2D map_nation_field : filter_linear;

//BakePalette.WATER_BASE; water classes and the grey ramp river 254 and sea 255 skip the nation dim.
const int PALETTE_WATER_MIN = 128;

varying flat vec4 v_tag;
varying vec2 v_img;
//Owner nation and not-islet flag times a top weight, then the weight; side bottom vertices carry the neighbour.
varying vec3 v_own;

void vertex() {
	vec4 tag = decode_tag(CUSTOM0);
	int face = tag_face(tag);
	v_tag = tag;
	v_img = VERTEX.xz + MAP_PAD + face_nudge(face);
	float top = (face == 0 || (VERTEX_ID % 4) < 2) ? 1.0 : 0.0;
	float rimmed = tag_islet(tag) ? 0.0 : 1.0;
	v_own = vec3(float(tag_nation(tag)) * top, top, rimmed * top);
	VERTEX.y += lift_offset(tag);
}

void fragment() {
	ivec2 cells = textureSize(map_cell_index, 0);
	ivec2 cell = clamp(ivec2(floor(v_img * 0.5)), ivec2(0), max(cells - ivec2(1), ivec2(0)));
	int index = int(texelFetch(map_cell_index, cell, 0).r * 255.0 + 0.5);
	vec3 col = texelFetch(map_palette, ivec2(index, 0), 0).rgb;
	int face = tag_face(v_tag);
	float shade = face_shade(float(face));
	col *= shade;
	if (face > 0 && tag_water_side(v_tag)) {
		col *= water_side_mul;
	}
	int nation = int(v_own.x / max(v_own.y, 0.0001) + 0.5);
	bool water = index >= PALETTE_WATER_MIN || tag_water_side(v_tag);
	if (!water) {
		col *= 1.0 - MAP_DIM * nation_dim(nation);
	}
	if (nation > 0 && v_own.z / max(v_own.y, 0.0001) > 0.5) {
		float d = texture(map_nation_field, v_img / MAP_IMG_SIZE).r * 255.0 / 16.0;
		col = nation_rim(col, nation, d, shade);
	}
	ALBEDO = srgb_to_linear(day_night(col));
}
