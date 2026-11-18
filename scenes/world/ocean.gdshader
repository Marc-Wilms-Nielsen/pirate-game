shader_type canvas_item;
// Hav med dybde. Øerne sendes ind som data (position, radius, form, lagunestørrelse),
// så shaderen kan regne ud, hvor dybt vandet er: lavt ved stranden og dybt på åbent hav.
// Stil: "Crystal tropics" – meget klart, lyst tropisk vand.
// Lavt vand er klart som glas – man ser sandbunden, lysmønstre (caustics) og ingen store bølger.

const int MAX_ISLANDS = 32;
uniform vec4 island_a[32]; // x, y, radius, lagunestørrelse
uniform vec4 island_b[32]; // formfaser p1, p2, p3, kystdetalje
uniform int island_count = 0;
uniform int quality = 2; // 0 = lav, 1 = mellem, 2 = høj (styres fra indstillingerne)
uniform float night = 0.0; // 0 = dag, 1 = nat: selvlysende plankton i vandet (styres af Sky)
uniform float storm = 0.0; // 0..1: større bølger i stormvejr
uniform vec3 light_comp = vec3(1.0); // udligner nattens mørke, så gløden faktisk lyser
uniform vec4 glow_color : source_color = vec4(0.25, 0.95, 0.85, 1.0);

group_uniforms colors;
uniform vec4 deep_color : source_color = vec4(0.01, 0.15, 0.34, 1.0);
uniform vec4 open_color : source_color = vec4(0.03, 0.27, 0.52, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.55, 0.96, 0.90, 1.0);
uniform vec4 sand_color : source_color = vec4(0.94, 0.85, 0.62, 1.0);
uniform vec4 seagrass_color : source_color = vec4(0.30, 0.50, 0.36, 1.0);
uniform vec4 sky_color : source_color = vec4(0.95, 1.0, 1.0, 1.0);

group_uniforms waves;
uniform float wave_scale = 0.0035; // mindre = større bølger
uniform float wave_speed = 0.06;
uniform float wave_strength = 2.25;
uniform float shallow_wave_factor = 0.08; // hvor meget bølge der er helt inde ved stranden
uniform float specular_power = 80.0;
uniform float specular_amount = 0.30;
uniform vec3 light_dir = vec3(-0.25, -0.35, 0.9);

group_uniforms seabed;
uniform float clarity = 1.3; // højere = bunden forsvinder hurtigere med dybden
uniform float refraction = 25.0; // hvor meget bølgerne forvrider bunden
uniform float caustic_strength = 0.0; // lysmønstre på bunden (0 = slået fra, gav hvidt flimmer)
uniform float caustic_scale = 0.05;
uniform float seagrass_amount = 0.0; // 0 = ren sandbund, 0.6 = pletter af søgræs

// Åbent hav er let gennemsigtigt: havbunden (Seabed) skinner svagt igennem nedefra.
uniform float deep_alpha = 0.7;

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

float fbm(vec2 p, int octaves) {
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 5; i++) {
		if (i >= octaves) {
			break;
		}
		v += a * noise(p);
		p = rot * p * 2.03;
		a *= 0.5;
	}
	return v;
}

// Bølgehøjde. "warp" beregnes én gang pr. pixel og genbruges til nabopunkterne (sparer meget).
float wave_height(vec2 p, float t, vec2 warp, int big_oct, int small_oct) {
	float big = fbm(p + warp * 0.8 + vec2(t, t * 0.6), big_oct);
	if (small_oct <= 0) {
		return big;
	}
	float small = fbm(p * 3.1 - vec2(t * 1.6, t * 0.9), small_oct);
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
		if (dist > a.z * 1.47 * a.w) {
			continue;
		}
		float ang = atan(d.y, d.x);
		vec4 b = island_b[i];
		vec3 ph = b.xyz;
		float r = 1.0 + 0.16 * sin(2.0 * ang + ph.x) + 0.10 * sin(3.0 * ang + ph.y) + 0.05 * sin(5.0 * ang + ph.z);
		// Fastland: ekstra bugter og halvøer (b.w = coast_detail) – samme formel som island.gd
		r += b.w * (0.08 * sin(4.0 * ang + ph.x * 1.7 + ph.y) + 0.05 * sin(7.0 * ang + ph.z * 2.3 + ph.x) + 0.03 * sin(11.0 * ang + ph.y * 3.1));
		r *= a.z;
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
	// Bølgerne vokser først i den yderste del af lagunen, så det meste af den er helt stille.
	float calm = mix(shallow_wave_factor, 1.0, smoothstep(0.45, 1.0, depth));

	// Bølger og overfladens normal. Kvalitet: 2 = høj, 1 = mellem, 0 = lav.
	vec2 p = wp * wave_scale;
	float t = TIME * wave_speed;
	int big_oct = quality >= 2 ? 5 : (quality == 1 ? 4 : 3);
	int small_oct = quality >= 2 ? 3 : (quality == 1 ? 2 : 0);
	int warp_oct = quality >= 2 ? 3 : (quality == 1 ? 2 : 0);
	vec2 warp = vec2(0.0);
	if (warp_oct > 0) {
		warp = vec2(fbm(p * 0.5 + vec2(t * 0.3, 0.0), warp_oct), fbm(p * 0.5 + vec2(0.0, t * 0.25) + 5.2, warp_oct));
	}
	float h = wave_height(p, t, warp, big_oct, small_oct);
	vec2 grad;
	if (quality >= 2) {
		float e = 0.02;
		grad = vec2(wave_height(p + vec2(e, 0.0), t, warp, big_oct, small_oct) - h,
				wave_height(p + vec2(0.0, e), t, warp, big_oct, small_oct) - h) / e;
	} else {
		// Billig hældning ud fra nabopixlerne (skærmafledte) – ingen ekstra støjberegninger
		vec2 dp = vec2(max(abs(dFdx(p.x)), 1e-5), max(abs(dFdy(p.y)), 1e-5));
		grad = vec2(dFdx(h) / dp.x, dFdy(h) / dp.y);
	}
	vec2 slope = -grad * wave_strength * (1.0 + storm * 1.4) * 0.1 * calm;
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
		vec2 bp = wp + slope * refraction * depth;
		float grain = fbm(bp * 0.02, quality >= 1 ? 3 : 1);
		float ripple = sin(bp.x * 0.18 + bp.y * 0.1 + noise(bp * 0.01) * 6.0) * 0.5 + 0.5;
		vec3 bottom = sand_color.rgb * (0.88 + 0.10 * grain + 0.05 * ripple);
		if (seagrass_amount > 0.0) {
			float grass_mask = smoothstep(0.55, 0.70, fbm(bp * 0.008 + 3.1, 3)) * smoothstep(0.25, 0.6, depth);
			bottom = mix(bottom, seagrass_color.rgb, grass_mask * seagrass_amount);
		}
		if (caustic_strength > 0.0) {
			bottom += caustics(bp * caustic_scale, TIME * 0.5) * caustic_strength * (1.0 - depth * 0.7);
		}
		// Bunden farves turkis af vandet over den – mere jo dybere.
		vec3 tinted = bottom * mix(vec3(1.0), shallow_color.rgb * 1.15, 0.15 + depth * 0.7);
		col = mix(water, tinted, visibility);
	}

	col *= mix(1.0, 0.82 + 0.3 * diffuse, 0.3 + 0.7 * calm);
	// Ingen solglimt i det stille lavvande – det gav hvidt flimmer.
	col = mix(col, sky_color.rgb, spec * specular_amount * smoothstep(0.5, 1.0, calm));
	// Selvlysende plankton: små lysende prikker, en blød glød langs stranden og lys på bølgetoppene.
	if (night > 0.02) {
		vec2 drift = vec2(TIME * 0.6, -TIME * 0.4);
		float dots = smoothstep(0.86, 0.99, noise(wp * 0.21 + drift)) * smoothstep(0.78, 0.97, noise(wp * 0.47 - drift * 1.3 + 7.0));
		float shore = (1.0 - smoothstep(0.0, 0.14, depth)) * (0.55 + 0.45 * sin(TIME * 1.3 + wp.x * 0.01 + wp.y * 0.013));
		float crest = smoothstep(0.62, 0.78, h) * (0.4 + 0.6 * calm);
		float glow = dots * 0.45 + shore * 0.15 + crest * 0.04;
		col += glow_color.rgb * light_comp * glow * smoothstep(0.35, 0.95, night);
	}
	// Gennemsigtighed: kun ude på dybt vand. Bølgetoppe og solglimt er mindre gennemsigtige.
	float alpha = mix(1.0, deep_alpha, smoothstep(0.72, 1.0, depth));
	alpha = clamp(alpha + (h - 0.5) * 0.12 + spec * 0.5, 0.0, 1.0);
	COLOR = vec4(col, alpha);
}
