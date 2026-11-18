shader_type canvas_item;
// Fog over the screen: soft, drifting clouds. "amount" is set by the weather (Sky).
// Reads the pre-baked noise texture (water_noise.gd) instead of computing noise per pixel.

uniform float amount = 0.0;
uniform float night = 0.0;
uniform sampler2D detail_tex : repeat_enable, filter_linear_mipmap;

float n(vec2 p) {
	return texture(detail_tex, p * (1.0 / 16.0)).r;
}

void fragment() {
	vec2 p = SCREEN_UV * vec2(3.0, 1.7);
	float t = TIME * 0.03;
	float v = n(p + vec2(t, t * 0.4)) * 0.6 + n(p * 2.3 - vec2(t * 1.7, 0.0)) * 0.3 + n(p * 5.1 + vec2(0.0, t)) * 0.1;
	// Thicker towards the edges, so you can still see your ship in the middle
	float edge = length(SCREEN_UV - 0.5) * 1.6;
	float a = amount * clamp(0.25 + v * 0.55 + edge * 0.45, 0.0, 1.0) * 0.85;
	vec3 col = mix(vec3(0.88, 0.92, 0.95), vec3(0.22, 0.26, 0.38), night);
	COLOR = vec4(col, a);
}
