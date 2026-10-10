shader_type spatial;
//Ground cover and sea ice MultiMesh: kit colour factor and mode, instance base colour, nation lift and dim, day and night.
render_mode unshaded, cull_disabled;

#include "res://Scripts/Map/Shaders/map_common.gdshaderinc"

varying flat vec4 v_tag;
varying flat vec3 v_base;

void vertex() {
	v_base = INSTANCE_CUSTOM.rgb;
	int nation = int(INSTANCE_CUSTOM.a + 0.5) & NATION_MASK;
	v_tag = vec4(float(nation), float(KIND_NATION), float(nation), 0.0);
	VERTEX.y += lift_offset(v_tag);
}

void fragment() {
	vec3 cf = COLOR.rgb * 2.0;
	int md = int(COLOR.a * 2.0 + 0.5);
	vec3 col;
	if (md == 1) {
		col = cf;
	} else if (md == 2) {
		float gr = (v_base.r + v_base.g + v_base.b) / 3.0;
		col = min((v_base * 0.6 + gr * 0.4) * cf, vec3(1.0));
	} else {
		col = min(v_base * cf, vec3(1.0));
	}
	col *= 1.0 - MAP_DIM * nation_dim(tag_nation(v_tag));
	ALBEDO = srgb_to_linear(day_night(col));
}
