shader_type canvas_item;
// Animeret hav i world space, så mønsteret står stille, mens kameraet bevæger sig.

uniform vec4 deep_color : source_color = vec4(0.10, 0.34, 0.52, 1.0);
uniform vec4 mid_color : source_color = vec4(0.15, 0.47, 0.64, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform float wave_scale = 0.006;
uniform float wave_speed = 0.12;
uniform float pixel_size = 2.0;
uniform float color_steps = 14.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 wp = floor(world_pos / pixel_size) * pixel_size;
	vec2 p = wp * wave_scale;
	float t = TIME * wave_speed;

	float n1 = fbm(p + vec2(t, t * 0.6));
	float n2 = fbm(p * 1.7 - vec2(t * 0.8, t * 0.3) + n1 * 1.5);

	vec3 col = mix(deep_color.rgb, mid_color.rgb, smoothstep(0.3, 0.7, (n1 + n2) * 0.5));

	// Bølgetoppe: tynde lyse bånd
	float crest = smoothstep(0.60, 0.64, n2) * (1.0 - smoothstep(0.64, 0.70, n2));
	// Glimt fra solen
	float glint = step(0.94, noise(wp * 0.12 + vec2(TIME * 0.6, -TIME * 0.35))) * smoothstep(0.45, 0.6, n1);

	col = mix(col, highlight_color.rgb, crest * 0.3 + glint * 0.55);
	col = floor(col * color_steps) / color_steps;
	COLOR = vec4(col, 1.0);
}
