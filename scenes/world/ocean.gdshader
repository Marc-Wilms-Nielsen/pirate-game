shader_type canvas_item;
// Ocean with depth, seabed and night glow in a single full-screen pass.
//
// Performance: every pixel used to compute ~30 noise functions per frame. The noise is now
// pre-baked into two small tiling textures (see water_noise.gd), and the shader just reads
// and scrolls them: 1 texture read on Low, 2 on Medium, 8 on High.
// The seabed (sand dunes, rocks, wrecks) used to be a second full-screen pass drawn under the
// water. Now the dunes are computed here and the rocks/wrecks come from `seabed_tex`, a small
// off-screen image drawn by WaterLayers (scenes/world/water_layers.gd).
//
// Islands are sent in as data (position, radius, shape, lagoon size) so the shader knows how
// deep the water is: shallow and glass-clear at the beach, deep blue in the open sea.

const int MAX_ISLANDS = 32;
const float TILE = 1.0 / 16.0; // both noise textures hold 16 x 16 noise cells per tile

uniform vec4 island_a[32]; // x, y, radius, lagoon size
uniform vec4 island_b[32]; // shape phases p1, p2, p3, coast detail
uniform vec4 island_c[32]; // a city's straight waterfront: direction x, y, distance (0 = none)
uniform int island_count = 0;
uniform int quality = 2; // 0 = low, 1 = medium, 2 = high (from Settings)
uniform float night = 0.0; // 0 = day, 1 = night: glowing plankton in the water (set by Sky)
uniform float storm = 0.0; // 0..1: bigger waves in storms
uniform vec3 light_comp = vec3(1.0); // undoes the night darkening so the glow actually glows
uniform vec4 glow_color : source_color = vec4(0.25, 0.95, 0.85, 1.0);

uniform sampler2D wave_tex : repeat_enable, filter_linear_mipmap; // fbm noise, 5 octaves
uniform sampler2D detail_tex : repeat_enable, filter_linear_mipmap; // single-octave noise
uniform sampler2D seabed_tex : hint_default_transparent, filter_linear; // rocks and wrecks, screen-aligned

group_uniforms colors;
uniform vec4 deep_color : source_color = vec4(0.01, 0.15, 0.34, 1.0);
uniform vec4 open_color : source_color = vec4(0.03, 0.27, 0.52, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.55, 0.96, 0.90, 1.0);
uniform vec4 sand_color : source_color = vec4(0.94, 0.85, 0.62, 1.0);
uniform vec4 seagrass_color : source_color = vec4(0.30, 0.50, 0.36, 1.0);
uniform vec4 sky_color : source_color = vec4(0.95, 1.0, 1.0, 1.0);

group_uniforms waves;
uniform float wave_scale = 0.0035; // smaller = bigger waves
uniform float wave_speed = 0.06;
uniform float wave_strength = 2.25;
uniform float shallow_wave_factor = 0.08; // how much wave there is right at the beach
uniform float specular_power = 80.0;
uniform float specular_amount = 0.30;
uniform vec3 light_dir = vec3(-0.25, -0.35, 0.9);

group_uniforms seabed;
uniform float clarity = 1.3; // higher = the sand bottom fades faster with depth
uniform float refraction = 25.0; // how much the waves bend the view of the bottom
uniform float seagrass_amount = 0.0; // 0 = clean sand, 0.6 = patches of seagrass
uniform vec4 floor_color : source_color = vec4(0.05, 0.12, 0.2, 1.0);
uniform vec4 dune_color : source_color = vec4(0.13, 0.22, 0.28, 1.0);
uniform vec4 floor_light_color : source_color = vec4(0.35, 0.6, 0.7, 1.0);
// The deep seabed sits a bit "further away" than the surface (parallax): world position
// wp maps to seabed position (wp - floor_offset) / floor_scale. Set every frame by WaterLayers.
uniform vec2 floor_offset = vec2(0.0);
uniform float floor_scale = 0.94;
// Open sea is slightly see-through: this much of the surface colour covers the seabed.
uniform float deep_alpha = 0.7;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float wtex(vec2 p) {
	return texture(wave_tex, p * TILE).r;
}

float dtex(vec2 p) {
	return texture(detail_tex, p * TILE).r;
}

// Slope step for the wave normals, in noise cells (~3 texels). The baked texture only has
// 256 height levels, so measuring the slope over a single texel gives visible stair-steps
// (blocky sun glints); a few texels smooths that out.
const float SLOPE_STEP = 0.05;
// The baked noise is stretched to the full 0..1 range, so it is about twice as steep as the old
// in-shader noise. This brings the glints back to the old, softer look.
const float SLOPE_MATCH = 0.45;

// Wave height (x) and its slope (yz) from two scrolling layers of the baked noise.
// Texture reads: Low 3, Medium 4, High 6 (+2 for the warp).
vec3 waves(vec2 p, float t, vec2 warp) {
	vec2 bp = p + warp * 0.8 + vec2(t, t * 0.6);
	float big = wtex(bp);
	vec2 grad = vec2(wtex(bp + vec2(SLOPE_STEP, 0.0)) - big, wtex(bp + vec2(0.0, SLOPE_STEP)) - big) / SLOPE_STEP;
	if (quality <= 0) {
		return vec3(big, grad);
	}
	vec2 sp = p * 3.1 - vec2(t * 1.6, t * 0.9) + 0.37;
	float small = wtex(sp);
	grad *= 0.75;
	if (quality >= 2) {
		// d/dp of wtex(p * 3.1) is 3.1 x the texture slope
		float s3 = SLOPE_STEP * 3.1;
		grad += vec2(wtex(sp + vec2(s3, 0.0)) - small, wtex(sp + vec2(0.0, s3)) - small) / SLOPE_STEP * 0.25;
	}
	return vec3(big * 0.75 + small * 0.25, grad);
}

// 0 at the beach, 1 at the outer edge of the lagoon and in the open sea.
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
		// Mainland: extra bays and headlands (b.w = coast_detail) – same formula as island.gd
		r += b.w * (0.08 * sin(4.0 * ang + ph.x * 1.7 + ph.y) + 0.05 * sin(7.0 * ang + ph.z * 2.3 + ph.x) + 0.03 * sin(11.0 * ang + ph.y * 3.1));
		r *= a.z;
		float t = clamp((dist / r - 1.0) / (a.w - 1.0), 0.0, 1.0);
		vec4 c = island_c[i];
		if (c.z > 0.0) { // a city's straight quay (c.z out from the middle): deep water within c.w px (same as island.gd)
			t = max(t, clamp((dot(d, c.xy) - c.z) / c.w, 0.0, 1.0));
		}
		t = t * t * t * (t * (t * 6.0 - 15.0) + 10.0); // soft at both ends
		depth = min(depth, t);
	}
	return depth;
}

// The deep seabed: dark sand dunes, faint light patches, plus the rocks and wrecks image.
vec3 deep_floor(vec2 wp, vec2 screen_uv) {
	vec2 p = (wp - floor_offset) / floor_scale;
	float dunes = dtex(p * 0.0022) * 0.65 + dtex(p * 0.006 + 3.1) * 0.35;
	float ripple = 0.0;
	if (quality >= 1) {
		float bend = dtex(p * 0.004) * 8.0;
		ripple = sin(p.x * 0.045 + p.y * 0.02 + bend) * 0.5 + 0.5;
		ripple *= 0.35 + 0.65 * dtex(p * 0.01 + 7.0);
	}
	vec3 col = mix(floor_color.rgb, dune_color.rgb, smoothstep(0.3, 0.85, dunes));
	col *= 0.9 + 0.18 * ripple;
	if (quality >= 2) {
		vec2 q = p * 0.012 + vec2(TIME * 0.05, -TIME * 0.03);
		float l = abs(dtex(q) - 0.5) + abs(dtex(q * 1.7 + 4.0) - 0.5) * 0.6;
		col += floor_light_color.rgb * pow(1.0 - clamp(l * 3.0, 0.0, 1.0), 4.0) * 0.07;
	}
	// The seabed image is premultiplied (drawn on a transparent background).
	vec4 things = texture(seabed_tex, screen_uv);
	return col * (1.0 - things.a) + things.rgb;
}

void fragment() {
	vec2 wp = world_pos;
	float depth = water_depth(wp);
	// Waves only grow in the outer part of the lagoon, so most of it is perfectly calm.
	float calm = mix(shallow_wave_factor, 1.0, smoothstep(0.45, 1.0, depth));

	vec2 p = wp * wave_scale;
	float t = TIME * wave_speed;
	vec2 warp = vec2(0.0);
	if (quality >= 2) {
		warp = vec2(wtex(p * 0.5 + vec2(t * 0.3, 0.0)), wtex(p * 0.5 + vec2(0.0, t * 0.25) + 5.2));
	}
	vec3 w = waves(p, t, warp);
	float h = w.x;
	vec2 grad = w.yz * SLOPE_MATCH;
	vec2 slope = -grad * wave_strength * (1.0 + storm * 1.4) * 0.1 * calm;
	vec3 n = normalize(vec3(slope, 1.0));
	vec3 l = normalize(light_dir);
	float diffuse = clamp(dot(n, l), 0.0, 1.0);
	float spec = pow(clamp(reflect(-l, n).z, 0.0, 1.0), specular_power);

	// The water's own colour: light turquoise in the lagoon, blue in the open sea
	vec3 open_water = mix(deep_color.rgb, open_color.rgb, smoothstep(0.25, 0.75, h));
	vec3 water = mix(shallow_color.rgb, open_water, smoothstep(0.0, 1.0, depth));

	// How much of the sand bottom you can see (1 at the beach, 0 in the open sea)
	float visibility = (exp(-depth * clarity) - exp(-clarity)) / (1.0 - exp(-clarity));

	vec3 col = water;
	if (visibility > 0.001) {
		vec2 bp = wp + slope * refraction * depth;
		float grain = quality >= 1 ? wtex(bp * 0.02) : 0.5;
		float ripple = sin(bp.x * 0.18 + bp.y * 0.1 + dtex(bp * 0.01) * 6.0) * 0.5 + 0.5;
		vec3 bottom = sand_color.rgb * (0.88 + 0.10 * grain + 0.05 * ripple);
		if (seagrass_amount > 0.0) {
			float grass_mask = smoothstep(0.55, 0.70, wtex(bp * 0.008 + 3.1)) * smoothstep(0.25, 0.6, depth);
			bottom = mix(bottom, seagrass_color.rgb, grass_mask * seagrass_amount);
		}
		// The bottom is tinted turquoise by the water above it – more the deeper it is.
		vec3 tinted = bottom * mix(vec3(1.0), shallow_color.rgb * 1.15, 0.15 + depth * 0.7);
		col = mix(water, tinted, visibility);
	}

	col *= mix(1.0, 0.82 + 0.3 * diffuse, 0.3 + 0.7 * calm);
	// No sun glints in the calm shallows – they caused white flicker.
	col = mix(col, sky_color.rgb, spec * specular_amount * smoothstep(0.5, 1.0, calm));
	// Glowing plankton: small bright dots, a soft glow along the beach and light on the wave crests.
	if (night > 0.02) {
		vec2 drift = vec2(TIME * 0.6, -TIME * 0.4);
		// Thresholds are lower than with the old value noise: the baked simplex noise rarely
		// reaches its extremes, so the old ones left almost no dots.
		float dots = smoothstep(0.74, 0.9, dtex(wp * 0.21 + drift)) * smoothstep(0.66, 0.86, dtex(wp * 0.47 - drift * 1.3 + 7.0));
		float shore = (1.0 - smoothstep(0.0, 0.14, depth)) * (0.55 + 0.45 * sin(TIME * 1.3 + wp.x * 0.01 + wp.y * 0.013));
		float crest = smoothstep(0.62, 0.78, h) * (0.4 + 0.6 * calm);
		float glow = dots * 0.45 + shore * 0.15 + crest * 0.04;
		col += glow_color.rgb * light_comp * glow * smoothstep(0.35, 0.95, night);
	}
	// See-through only in deep water: there the seabed shows through. Crests and glints cover more.
	float alpha = mix(1.0, deep_alpha, smoothstep(0.72, 1.0, depth));
	alpha = clamp(alpha + (h - 0.5) * 0.12 + spec * 0.5, 0.0, 1.0);
	if (alpha < 0.999) {
		col = mix(deep_floor(wp, SCREEN_UV), col, alpha);
	}
	COLOR = vec4(col, 1.0);
}
