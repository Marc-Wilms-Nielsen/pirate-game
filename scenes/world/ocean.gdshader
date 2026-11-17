shader_type canvas_item;
// Hav med dybde. Øerne sendes ind som data (position, radius, form, lagunestørrelse),
// så shaderen kan regne ud, hvor dybt vandet er: lavt ved stranden og dybt på åbent hav.
// Lavt vand er klart som glas – man ser sandbunden, lysmønstre (caustics) og ingen store bølger.

const int MAX_ISLANDS = 16;
uniform vec4 island_a[16]; // x, y, radius, lagunestørrelse
uniform vec4 island_b[16]; // formfaser p1, p2, p3
uniform int island_count = 0;

group_uniforms colors;
uniform vec4 deep_color : source_color = vec4(0.02, 0.22, 0.40, 1.0);
uniform vec4 open_color : source_color = vec4(0.05, 0.38, 0.56, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.30, 0.82, 0.84, 1.0);
uniform vec4 sand_color : source_color = vec4(0.94, 0.85, 0.62, 1.0);
uniform vec4 seagrass_color : source_color = vec4(0.30, 0.50, 0.36, 1.0);
uniform vec4 sky_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);

group_uniforms waves;
uniform float wave_scale = 0.0035; // mindre = større bølger
uniform float wave_speed = 0.06;
uniform float wave_strength = 2.5;
uniform float shallow_wave_factor = 0.12; // hvor meget bølge der er helt inde ved stranden
uniform float specular_power = 80.0;
uniform float specular_amount = 0.35;
uniform vec3 light_dir = vec3(-0.25, -0.35, 0.9);

group_uniforms seabed;
uniform float clarity = 2.5; // højere = bunden forsvinder hurtigere med dybden
uniform float refraction = 25.0; // hvor meget bølgerne forvrider bunden
uniform float caustic_strength = 0.30;
uniform float caustic_scale = 0.05;

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
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
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

// 0 ved strandkanten, 1 ved lagunens yderkant og ude på åbent hav.
float water_depth(vec2 wp) {
	float depth = 1.0;
	for (int i = 0; i < MAX_ISLANDS; i++) {
		if (i >= island_count) {
			break;
		}
		vec4 a = island_a[i];
		vec2 d = wp - a.xy;
		float dist = length(d);
		if (dist > a.z * 1.32 * a.w) {
			continue;
		}
		float ang = atan(d.y, d.x);
		vec3 ph = island_b[i].xyz;
		float r = a.z * (1.0 + 0.16 * sin(2.0 * ang + ph.x) + 0.10 * sin(3.0 * ang + ph.y) + 0.05 * sin(5.0 * ang + ph.z));
		float t = clamp((dist / r - 1.0) / (a.w - 1.0), 0.0, 1.0);
		t = t * t * t * (t * (t * 6.0 - 15.0) + 10.0); // blød overgang i begge ender
		depth = min(depth, t);
	}
	return depth;
}

// Lysmønstre på bunden: to lag af "rygge" i støjen giver et netværk af lyse linjer.
float caustics(vec2 p, float t) {
	p += vec2(noise(p * 0.5 + t * 0.3), noise(p * 0.5 - t * 0.3 + 3.7)) * 1.5;
	float v1 = abs(noise(p + vec2(t * 0.6, t * 0.3)) - 0.5);
	float v2 = abs(noise(p * 1.4 - vec2(t * 0.4, -t * 0.5) + 7.3) - 0.5);
	return pow(1.0 - clamp(v1 * 5.0, 0.0, 1.0), 5.0) + pow(1.0 - clamp(v2 * 5.0, 0.0, 1.0), 5.0) * 0.6;
}

void fragment() {
	vec2 wp = world_pos;
	float depth = water_depth(wp);
	float calm = mix(shallow_wave_factor, 1.0, depth);

	// Bølger og overfladens normal
	vec2 p = wp * wave_scale;
	float t = TIME * wave_speed;
	float e = 0.02;
	float h = wave_height(p, t);
	float hx = wave_height(p + vec2(e, 0.0), t);
	float hy = wave_height(p + vec2(0.0, e), t);
	vec2 slope = vec2(h - hx, h - hy) / e * wave_strength * 0.1 * calm;
	vec3 n = normalize(vec3(slope, 1.0));
	vec3 l = normalize(light_dir);
	float diffuse = clamp(dot(n, l), 0.0, 1.0);
	float spec = pow(clamp(reflect(-l, n).z, 0.0, 1.0), specular_power);

	// Vandets egen farve: lys turkis i lagunen, blå på åbent hav
	vec3 open_water = mix(deep_color.rgb, open_color.rgb, smoothstep(0.25, 0.75, h));
	vec3 water = mix(shallow_color.rgb, open_water, smoothstep(0.0, 1.0, depth));

	// Hvor meget af bunden man kan se (1 ved stranden, 0 på åbent hav)
	float visibility = (exp(-depth * clarity) - exp(-clarity)) / (1.0 - exp(-clarity));

	vec3 col = water;
	if (visibility > 0.001) {
		vec2 bp = wp + slope * refraction * (0.3 + depth);
		float grain = fbm(bp * 0.02);
		float ripple = sin(bp.x * 0.18 + bp.y * 0.1 + fbm(bp * 0.01) * 6.0) * 0.5 + 0.5;
		vec3 bottom = sand_color.rgb * (0.88 + 0.10 * grain + 0.05 * ripple);
		float grass_mask = smoothstep(0.55, 0.70, fbm(bp * 0.008 + 3.1)) * smoothstep(0.25, 0.6, depth);
		bottom = mix(bottom, seagrass_color.rgb, grass_mask * 0.6);
		bottom += caustics(bp * caustic_scale, TIME * 0.5) * caustic_strength * (1.0 - depth * 0.7);
		// Bunden farves turkis af vandet over den – mere jo dybere.
		vec3 tinted = bottom * mix(vec3(1.0), shallow_color.rgb * 1.15, 0.15 + depth * 0.7);
		col = mix(water, tinted, visibility);
	}

	col *= mix(1.0, 0.82 + 0.3 * diffuse, 0.3 + 0.7 * calm);
	col = mix(col, sky_color.rgb, spec * specular_amount * (0.3 + 0.7 * calm));
	COLOR = vec4(col, 1.0);
}
