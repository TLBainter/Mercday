shader_type spatial;
//Flat sea plane at WATER_H: one colour through day and night; no waves or animation in stage 1.
render_mode unshaded, depth_draw_opaque;

#include "res://Scripts/Map/Shaders/map_common.gdshaderinc"

uniform vec4 water_color = vec4(0.149, 0.243, 0.384, 1.0);

void fragment() {
	ALBEDO = srgb_to_linear(day_night(water_color.rgb));
}
