class_name Surfaces
extends RefCounted
## Procedural materials for the greybox-turned-house. Textures are drawn once
## at startup and tiled in world space, so every box shows the same grain
## at the same scale no matter its size.

const SIZE := 128

static var _cache: Dictionary = {}

static func wallpaper() -> StandardMaterial3D:
	return _cached("wallpaper", func() -> StandardMaterial3D:
		var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
		var noise := _noise(3, 0.05)
		for y in SIZE:
			for x in SIZE:
				var base := Color(0.40, 0.37, 0.31)
				if (x / 16) % 2 == 0:
					base = base.lightened(0.06)
				var motif := 0.0
				if (x % 32 == 16) and (y % 32 > 12) and (y % 32 < 20):
					motif = 0.07
				var grain := noise.get_noise_2d(x, y) * 0.08
				img.set_pixel(x, y, base.lightened(grain + motif))
		return _material(img, Vector3(0.5, 0.5, 0.5), 1.0))

static func floor_boards() -> StandardMaterial3D:
	return _cached("floor", func() -> StandardMaterial3D:
		var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
		var noise := _noise(9, 0.02)
		var rng := RandomNumberGenerator.new()
		rng.seed = 21
		var tones: Array[float] = []
		for i in 8:
			tones.append(rng.randf_range(-0.07, 0.05))
		for y in SIZE:
			for x in SIZE:
				var plank := y / 16
				var base := Color(0.25, 0.17, 0.11).lightened(tones[plank])
				var grain := noise.get_noise_2d(x * 0.15, y * 3.0) * 0.18
				var color := base.lightened(grain)
				if y % 16 == 0:
					color = color.darkened(0.55)
				if (x + plank * 37) % SIZE == 0:
					color = color.darkened(0.4)
				img.set_pixel(x, y, color)
		return _material(img, Vector3(0.45, 0.45, 0.45), 0.7))

static func ceiling() -> StandardMaterial3D:
	return _cached("ceiling", func() -> StandardMaterial3D:
		var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
		var noise := _noise(5, 0.08)
		for y in SIZE:
			for x in SIZE:
				img.set_pixel(x, y, Color(0.55, 0.53, 0.5).lightened(noise.get_noise_2d(x, y) * 0.1))
		return _material(img, Vector3(0.4, 0.4, 0.4), 1.0))

static func fabric(color: Color) -> StandardMaterial3D:
	return _cached("fabric%s" % color.to_html(), func() -> StandardMaterial3D:
		var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
		var noise := _noise(13, 0.6)
		for y in SIZE:
			for x in SIZE:
				var weave := 0.05 if (x + y) % 4 < 2 else -0.03
				img.set_pixel(x, y, color.lightened(noise.get_noise_2d(x, y) * 0.1 + weave))
		return _material(img, Vector3(1.2, 1.2, 1.2), 1.0))

static func wood(color: Color) -> StandardMaterial3D:
	return _cached("wood%s" % color.to_html(), func() -> StandardMaterial3D:
		var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
		var noise := _noise(17, 0.02)
		for y in SIZE:
			for x in SIZE:
				img.set_pixel(x, y, color.lightened(noise.get_noise_2d(x * 4.0, y * 0.4) * 0.22))
		return _material(img, Vector3(0.8, 0.8, 0.8), 0.6))

static func plain(color: Color, roughness: float = 1.0) -> StandardMaterial3D:
	return _cached("plain%s%s" % [color.to_html(), roughness], func() -> StandardMaterial3D:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		return material)

static func glow(color: Color, energy: float = 1.5) -> StandardMaterial3D:
	return _cached("glow%s%s" % [color.to_html(), energy], func() -> StandardMaterial3D:
		var material := StandardMaterial3D.new()
		material.albedo_color = color.darkened(0.6)
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = energy
		return material)

static func glass() -> StandardMaterial3D:
	return _cached("glass", func() -> StandardMaterial3D:
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.25, 0.32, 0.4, 0.18)
		material.roughness = 0.1
		material.metallic_specular = 1.0
		return material)

static func _cached(key: String, build: Callable) -> StandardMaterial3D:
	if not _cache.has(key):
		_cache[key] = build.call()
	return _cache[key]

static func _noise(seed_value: int, frequency: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	return noise

static func _material(img: Image, scale: Vector3, roughness: float) -> StandardMaterial3D:
	img.generate_mipmaps()
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(img)
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = scale
	material.roughness = roughness
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material
