class_name DragonSprites
## 2D판 render/dragonSprites.js + render/tint.js.
## 종족 + 색상(+ 한 장짜리 외형 번호) 조합별로 시트를 만들고 캐시한다.

static var _raw := {}          # species → { down, left, right, up } | { sheet }  (Image)
static var _cache := {}        # "species|body|wing|look" → SpriteSheet


static func _raw_images(species: String) -> Dictionary:
	if not _raw.has(species):
		var desc: Dictionary = Data.get_module("sprites").DRAGON_SHEETS[species]
		var imgs := {}
		for k in desc.images:
			var tex: Texture2D = load("res://" + desc.images[k])
			var img := tex.get_image()
			img.convert(Image.FORMAT_RGBA8)
			imgs[k] = img
		_raw[species] = imgs
	return _raw[species]


static func get_sheet(species: String, colors: Dictionary, look := 0) -> SpriteSheet:
	var sheets: Dictionary = Data.get_module("sprites").DRAGON_SHEETS
	if not sheets.has(species): species = "WESTERN"
	var desc: Dictionary = sheets[species]
	var key := "%s|%s|%s|%d" % [species, colors.get("body"), colors.get("wing"), look]
	if _cache.has(key): return _cache[key]
	var raw := _raw_images(species)
	var images := {}
	for k in raw:
		images[k] = tint_image(raw[k], desc.zones, colors) if not desc.zones.is_empty() else raw[k]
	var sheet := SpriteSheet.build(desc, images, look)
	_cache[key] = sheet
	return sheet


static func _hue_dist(a: float, b: float) -> float:
	var d := fmod(absf(a - b), 360.0)
	return 360.0 - d if d > 180 else d


static func _hex_to_hsl(hex: String) -> Array:
	var c := Color.html(hex)
	return Util.rgb_to_hsl(c.r8, c.g8, c.b8)


## 스프라이트 색상 교체. 원본의 특정 색상대(hue 범위)를 목표 색으로 옮기되 명암은 유지한다.
## zones: [{ hue, range, refL, target }] — 원본에서 hue±range 에 드는 픽셀을 colors[target] 색으로 옮긴다.
## refL: 원본 색상대의 평균 밝기. 목표색 밝기와의 차이만큼 전체를 밝게/어둡게 해서 명암을 보존한다.
static func tint_image(src: Image, zones: Array, colors: Dictionary) -> Image:
	var img: Image = src.duplicate()
	var targets := []
	for z in zones:
		targets.append({ hue = z.hue, range = z.range, refL = z.refL, t = _hex_to_hsl(colors.get(z.target, "#ffffff")) })
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a8 < 8: continue
			var hsl := Util.rgb_to_hsl(c.r8, c.g8, c.b8)
			var s: float = hsl[1]
			var l: float = hsl[2]
			if s < 0.18 or l < 0.06 or l > 0.96: continue   # 회색/검정/흰색(눈, 발톱, 윤곽)은 그대로
			for z in targets:
				if _hue_dist(hsl[0], z.hue) > z.range: continue
				var ns := clampf(s * 0.4 + z.t[1] * 0.6, 0, 1)
				var nl := clampf(l + (z.t[2] - z.refL) * 0.8, 0, 1)
				var rgb := Util.hsl_to_rgb(z.t[0], ns, nl)
				img.set_pixel(x, y, Color8(roundi(rgb[0]), roundi(rgb[1]), roundi(rgb[2]), c.a8))
				break
	return img
