shader_type canvas_item;
// Glat, animeret hav i world space. Bølgehøjden bruges til at beregne en normal,
// så overfladen belyses af solen (blød skygge på bølgerne + glans).

uniform vec4 deep_color : source_color = vec4(0.07, 0.30, 0.48, 1.0);
uniform vec4 mid_color : source_color = vec4(0.13, 0.45, 0.62, 1.0);
uniform vec4 sky_color : source_color = vec4(0.80, 0.92, 1.0, 1.0);
uniform float wave_scale = 0.0035; // mindre = større bølger
uniform float wave_speed = 0.06;
uniform float wave_strength = 2.5; // hvor tydeligt bølgerne belyses
uniform float specular_power = 80.0;
uniform float specular_amount = 0.35;
uniform vec3 light_dir = vec3(-0.25, -0.35, 0.9);

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
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0); // quintic: blødere overgange
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = rot * p * 2.03;
		a *= 0.5;
	}
	return v;
}

float wave_height(vec2 p, float t) {
	vec2 warp = vec2(fbm(p * 0.5 + vec2(t * 0.3, 0.0)), fbm(p * 0.5 + vec2(0.0, t * 0.25) + 5.2));
	float big = fbm(p + warp * 0.8 + vec2(t, t * 0.6));
	float small = fbm(p * 3.1 - vec2(t * 1.6, t * 0.9));
	return big * 0.75 + small * 0.25;
}

void fragment() {
	vec2 p = world_pos * wave_scale;
	float t = TIME * wave_speed;

	float e = 0.02;
	float h = wave_height(p, t);
	float hx = wave_height(p + vec2(e, 0.0), t);
	float hy = wave_height(p + vec2(0.0, e), t);
	vec3 n = normalize(vec3((h - hx) / e * wave_strength * 0.1, (h - hy) / e * wave_strength * 0.1, 1.0));
	vec3 l = normalize(light_dir);

	float diffuse = clamp(dot(n, l), 0.0, 1.0);
	vec3 r = reflect(-l, n);
	float spec = pow(clamp(r.z, 0.0, 1.0), specular_power);

	vec3 col = mix(deep_color.rgb, mid_color.rgb, smoothstep(0.25, 0.75, h));
	col *= 0.80 + 0.35 * diffuse;
	col = mix(col, sky_color.rgb, spec * specular_amount);
	COLOR = vec4(col, 1.0);
}
