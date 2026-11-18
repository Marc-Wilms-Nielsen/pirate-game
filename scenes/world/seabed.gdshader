shader_type canvas_item;
// Havbunden langt nede under det åbne hav: mørke sandklitter med svage lysmønstre.
// Tegnes UNDER hav-shaderen, som er let gennemsigtig ude på dybt vand.

uniform int quality = 2;
uniform vec4 floor_color : source_color = vec4(0.05, 0.12, 0.2, 1.0);
uniform vec4 dune_color : source_color = vec4(0.13, 0.22, 0.28, 1.0);
uniform vec4 light_color : source_color = vec4(0.35, 0.6, 0.7, 1.0);

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

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
	vec2 p = world_pos;
	// Store, bløde klitter og sandribber på tværs
	float dunes = noise(p * 0.0022) * 0.65 + noise(p * 0.006 + 3.1) * 0.35;
	float ripple = 0.0;
	if (quality >= 1) {
		float bend = noise(p * 0.004) * 8.0;
		ripple = sin(p.x * 0.045 + p.y * 0.02 + bend) * 0.5 + 0.5;
		ripple *= 0.35 + 0.65 * noise(p * 0.01 + 7.0);
	}
	vec3 col = mix(floor_color.rgb, dune_color.rgb, smoothstep(0.3, 0.85, dunes));
	col *= 0.9 + 0.18 * ripple;
	// Svage lyspletter fra overfladen, der langsomt glider hen over bunden
	if (quality >= 2) {
		vec2 q = p * 0.012 + vec2(TIME * 0.05, -TIME * 0.03);
		float l = abs(noise(q) - 0.5) + abs(noise(q * 1.7 + 4.0) - 0.5) * 0.6;
		col += light_color.rgb * pow(1.0 - clamp(l * 3.0, 0.0, 1.0), 4.0) * 0.07;
	}
	COLOR = vec4(col, 1.0);
}
