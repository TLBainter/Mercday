shader_type canvas_item;

//Devil faces: slow value noise mixes purple and red over the outline alpha. Placeholder colours and speed.
uniform vec4 purple : source_color = vec4(0.541, 0.243, 0.784, 1.0);
uniform vec4 red : source_color = vec4(0.910, 0.345, 0.247, 1.0);
uniform float speed = 0.6;
uniform float grain = 4.0;

varying vec2 local;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x);
	float b = mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x);
	return mix(a, b, u.y);
}

void vertex() {
	local = VERTEX;
}

void fragment() {
	float n = value_noise(local / grain + vec2(TIME * speed, TIME * speed * 0.7));
	COLOR = vec4(mix(purple.rgb, red.rgb, n), COLOR.a);
}
