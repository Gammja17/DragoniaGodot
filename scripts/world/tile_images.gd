class_name TileImages
## 2D판 world/terrain.js 의 preloadTerrain + render/palette.js.
## 타일 시트를 Image 로 들고 있고, 초록 숲 시트를 다시 칠해 설원·화산·단풍·사막·구름 위를 만든다
## (키는 ground4, trees4 … 식. 뒤의 숫자가 BIOMES[].palette + 1).

const RECOLOR_NAMES := ["SNOW", "VOLCANO", "AUTUMN", "DESERT", "SKY"]

static var _images := {}
static var _textures := {}


## 그릴 때 쓰는 텍스처 (시트마다 한 번만 만든다)
static func get_texture(key: String) -> Texture2D:
	if not _textures.has(key):
		var img := get_image(key)
		if img == null: return null
		_textures[key] = ImageTexture.create_from_image(img)
	return _textures[key]


static func get_image(key: String) -> Image:
	if _images.is_empty():
		_load()
	if not _images.has(key):
		# 다시 칠한 시트는 그 바이옴에 처음 갈 때 만든다 (한꺼번에 만들면 시작이 느려진다)
		for base in ["ground", "trees", "props"]:
			var i := key.trim_prefix(base)
			if i != key and i.is_valid_int() and int(i) >= 4 and int(i) - 4 < RECOLOR_NAMES.size():
				_images[key] = recolor(_images[base], RECOLOR_NAMES[int(i) - 4], base == "ground")
	return _images.get(key)


static func _load() -> void:
	var paths: Dictionary = Data.get_module("tiles").TILE_IMAGES
	for key in paths:
		var tex: Texture2D = load("res://" + paths[key])
		var img := tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		_images[key] = img


# 원본의 색 구역: 풀·나뭇잎(hue 60~170), 흙·바위 테두리(hue 15~55), 물(hue 170~260)
static func _is_leaf(h: float) -> bool: return h >= 58 and h < 170
static func _is_earth(h: float) -> bool: return h >= 12 and h < 58
static func _is_water(h: float) -> bool: return h >= 170 and h < 265


## (h, s, l) → [h, s, l]
static func _recolor_hsl(name: String, h: float, s: float, l: float) -> Array:
	match name:
		"SNOW":       # 눈 덮인 땅, 얼어붙은 물
			if _is_leaf(h): return [205.0, s * 0.22, 0.52 + l * 0.5]
			if _is_earth(h): return [215.0, s * 0.25, 0.3 + l * 0.55]
			if _is_water(h): return [192.0, s * 0.55, 0.45 + l * 0.75]
		"VOLCANO":    # 잿빛 땅, 물 대신 용암
			if _is_leaf(h): return [8.0, s * 0.28, l * 0.42 + 0.03]
			if _is_earth(h): return [14.0, s * 0.5, l * 0.5]
			if _is_water(h): return [14.0 + l * 60.0, 1.0, 0.34 + l * 1.1]
		"AUTUMN":     # 단풍 든 숲
			if _is_leaf(h): return [max(8.0, 52.0 - (h - 58.0) * 0.42), min(1.0, s * 1.15), l]
		"DESERT":     # 모래땅, 메마른 덤불
			if _is_leaf(h): return [40.0 + (h - 58.0) * 0.05, s * 0.55, 0.3 + l * 0.72]
			if _is_earth(h): return [24.0, s * 0.8, l * 0.95]
			if _is_water(h): return [178.0, s * 0.9, 0.2 + l * 0.9]
		"SKY":        # 구름 위. 땅은 구름(흰빛), 물 자리는 뚫린 하늘(밝은 파랑)
			if _is_leaf(h): return [210.0, s * 0.12, 0.62 + l * 0.42]
			if _is_earth(h): return [215.0, s * 0.18, 0.5 + l * 0.45]
			if _is_water(h): return [205.0, 0.75, 0.5 + l * 0.5]
	return [h, s, l]


## ground: 바닥 시트인가. 나무·소품 시트의 푸른 색은 물이 아니라 그림자라서 건드리지 않는다
static func recolor(src: Image, name: String, ground := true) -> Image:
	var img: Image = src.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a8 < 8:
				continue
			var hsl := Util.rgb_to_hsl(c.r8, c.g8, c.b8)
			if hsl[1] < 0.08:
				continue   # 회색(바위, 그림자)은 그대로
			if not ground and _is_water(hsl[0]):
				continue
			var n := _recolor_hsl(name, hsl[0], hsl[1], hsl[2])
			var rgb := Util.hsl_to_rgb(n[0], clampf(n[1], 0, 1), clampf(n[2], 0, 1))
			# 캔버스의 putImageData 는 소수를 반올림해 담는다
			img.set_pixel(x, y, Color8(roundi(rgb[0]), roundi(rgb[1]), roundi(rgb[2]), c.a8))
	return img
