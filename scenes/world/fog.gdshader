shader_type canvas_item;
// Tåge oven på skærmen: bløde, drivende skyer. "amount" styres af vejret (Sky).

uniform float amount = 0.0;
uniform float night = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = SCREEN_UV * vec2(3.0, 1.7);
	float t = TIME * 0.03;
	float n = noise(p + vec2(t, t * 0.4)) * 0.6 + noise(p * 2.3 - vec2(t * 1.7, 0.0)) * 0.3 + noise(p * 5.1 + vec2(0.0, t)) * 0.1;
	// Tættere ude i kanterne, så man stadig kan se sit skib i midten
	float edge = length(SCREEN_UV - 0.5) * 1.6;
	float a = amount * clamp(0.25 + n * 0.55 + edge * 0.45, 0.0, 1.0) * 0.85;
	vec3 col = mix(vec3(0.88, 0.92, 0.95), vec3(0.22, 0.26, 0.38), night);
	COLOR = vec4(col, a);
}
