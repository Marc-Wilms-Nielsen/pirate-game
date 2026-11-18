class_name WaterNoise
extends RefCounted
## Pre-baked noise textures shared by the ocean and fog shaders.
##
## Computing noise in a shader is expensive when it runs for every pixel on screen, every frame.
## Reading a texture is much cheaper, so the noise is generated once at startup into two small
## seamless (tiling) textures. Godot builds a NoiseTexture2D on a background thread, so this
## costs no loading time; the shaders just see a blank texture for the first frame or two.
##
## Both textures hold 16 x 16 noise cells per tile; the shaders read them with `p / 16.0`, where
## `p` is in noise cells (the same units the old in-shader noise() used).

const CELLS := 16.0

static var _wave: NoiseTexture2D
static var _detail: NoiseTexture2D


## 5-octave fractal noise for the waves and the sand grain (1024 x 1024, ~1 MB).
static func wave_texture() -> Texture2D:
	if _wave == null:
		_wave = _make(1024, 5, 7)
	return _wave


## Single-octave noise for dunes, plankton dots and fog (512 x 512, ~0.25 MB).
static func detail_texture() -> Texture2D:
	if _detail == null:
		_detail = _make(512, 1, 11)
	return _detail


static func _make(size: int, octaves: int, seed_value: int) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = seed_value
	noise.frequency = CELLS / size
	if octaves > 1:
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = octaves
		noise.fractal_lacunarity = 2.03
		noise.fractal_gain = 0.5
	else:
		noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	var tex := NoiseTexture2D.new()
	tex.width = size
	tex.height = size
	tex.seamless = true
	tex.normalize = true # stretch to the full 0..1 range, like the old shader noise
	tex.generate_mipmaps = true
	tex.noise = noise
	return tex
