//Shared map shader code: CUSTOM0 tag decode, face shade, group state lookup, lift, day and night, nation rim, sRGB decode.
//Values mirror MapConst (FACE_*, LIFT, DIM, NIGHT_MUL, RIM_*, PAD_L, PAD_T, IMG_W, IMG_H).

global uniform vec3 map_daylight;
global uniform float map_night;
global uniform int map_anim_frame;
global uniform float map_wind;
global uniform sampler2D map_group_state;
global uniform sampler2D map_nation_glow;
global uniform sampler2D map_nation_rim;

const int KIND_NATION = 0;
const int ISLET_BIT = 128;
const int NATION_MASK = 127;
const int FACE_MASK = 7;
const int WATER_SIDE_BIT = 8;
const float MAP_LIFT = 10.0;
const float MAP_DIM = 0.25;
const vec2 MAP_PAD = vec2(800.0, 500.0);
const vec2 MAP_IMG_SIZE = vec2(5696.0, 2960.0);
const vec3 MAP_NIGHT_MUL = vec3(0.30, 0.34, 0.55);
const float RIM_CORE_LO = 0.3;
const float RIM_CORE_HI = 1.0;
const float RIM_GLOW_K = 0.9;
const float RIM_SIDE_BASE = 0.55;
const float RIM_SIDE_SHADE = 0.45;

//x nation byte (bit 7 = islet), y group kind, z group index, w face code bits 0-2, water bit 3, sway bits 4-7.
vec4 decode_tag(vec4 custom0) {
	return floor(custom0 * 255.0 + 0.5);
}

int tag_nation(vec4 tag) {
	return int(tag.x) & NATION_MASK;
}

bool tag_islet(vec4 tag) {
	return (int(tag.x) & ISLET_BIT) != 0;
}

int tag_face(vec4 tag) {
	return int(tag.w) & FACE_MASK;
}

bool tag_water_side(vec4 tag) {
	return (int(tag.w) & WATER_SIDE_BIT) != 0;
}

//0 top, 1 S, 2 W, 3 E, 4 N.
float face_shade(float face_code) {
	int f = int(face_code);
	if (f == 1) {
		return 0.62;
	}
	if (f == 2) {
		return 0.78;
	}
	if (f == 3) {
		return 0.50;
	}
	if (f == 4) {
		return 0.45;
	}
	return 1.0;
}

//Half a block (1 map px) from a side face back into the block that owns it.
vec2 face_nudge(int face) {
	if (face == 1) {
		return vec2(0.0, -1.0);
	}
	if (face == 2) {
		return vec2(1.0, 0.0);
	}
	if (face == 3) {
		return vec2(-1.0, 0.0);
	}
	if (face == 4) {
		return vec2(0.0, 1.0);
	}
	return vec2(0.0);
}

//R highlight, G lift, B dim, A select; index 0 is none.
vec4 group_state(int kind, int index) {
	if (index <= 0) {
		return vec4(0.0);
	}
	return texelFetch(map_group_state, ivec2(clamp(index, 0, 255), clamp(kind, 0, 7)), 0);
}

float group_lift(int kind, int index) {
	return group_state(kind, index).g * MAP_LIFT;
}

//Max of the nation row and the group row; islets never lift.
float lift_offset(vec4 tag) {
	if (tag_islet(tag)) {
		return 0.0;
	}
	return max(group_lift(KIND_NATION, tag_nation(tag)), group_lift(int(tag.y), int(tag.z)));
}

vec3 day_night(vec3 albedo) {
	return albedo * map_daylight * mix(vec3(1.0), MAP_NIGHT_MUL, map_night);
}

//Palette, rim and shading math runs on sRGB values like the reference; the result is decoded once for ALBEDO.
vec3 srgb_to_linear(vec3 c) {
	vec3 lo = c / 12.92;
	vec3 hi = pow((c + 0.055) / 1.055, vec3(2.4));
	return mix(hi, lo, lessThanEqual(c, vec3(0.04045)));
}

vec3 light_emissive(vec3 light_rgb) {
	return light_rgb * map_night;
}

//d is the nation_field distance in half res texels; strength is the nation lift G.
vec3 nation_rim(vec3 col, int nation, float d, float side_shade) {
	float strength = group_state(KIND_NATION, nation).g;
	if (strength <= 0.0) {
		return col;
	}
	vec3 rim = texelFetch(map_nation_rim, ivec2(clamp(nation, 0, 255), 0), 0).rgb;
	if (side_shade < 0.99) {
		rim *= RIM_SIDE_BASE + RIM_SIDE_SHADE * side_shade;
	}
	float core = 1.0 - smoothstep(RIM_CORE_LO, RIM_CORE_HI, d);
	float glow = exp(-RIM_GLOW_K * d) * (1.0 - core);
	return mix(col, rim, strength * clamp(core * 0.95 + glow * 0.55, 0.0, 1.0));
}

//Unclaimed land has no state texel; any two nations hold the shared dim, since at most one is focused.
float nation_dim(int nation) {
	if (nation > 0) {
		return group_state(KIND_NATION, nation).b;
	}
	return max(group_state(KIND_NATION, 1).b, group_state(KIND_NATION, 2).b);
}
