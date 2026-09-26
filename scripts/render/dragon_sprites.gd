class_name DragonSprites
## 2D판 render/dragonSprites.js + render/tint.js.
## 종족 + 색상(+ 한 장짜리 외형 번호) 조합별로 시트를 만들고 캐시한다.

const MARK_MIN := 4            # 눈 · 문양 덩어리의 최소 픽셀 수 (윤곽의 회색 점과 가르려고)

static var _raw := {}          # species → { down, left, right, up } | { sheet }  (Image)
static var _cache := {}        # "species|body|wing|mark|look" → SpriteSheet


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


## keep=false: 담아 두지 않는다 (새 용 만들기에서 색을 끄는 동안의 미리보기. 스치는 색마다 쌓이지 않게)
static func get_sheet(species: String, colors: Dictionary, look := 0, keep := true) -> SpriteSheet:
	var sheets: Dictionary = Data.get_module("sprites").DRAGON_SHEETS
	if not sheets.has(species): species = "WESTERN"
	var desc: Dictionary = sheets[species]
	var key := "%s|%s|%s|%s|%d" % [species, colors.get("body"), colors.get("wing"), colors.get("mark"), look]   # 문양 · 눈 색이 빠져 있어 그 색만 바꾸면 옛 그림이 나왔다
	if _cache.has(key): return _cache[key]
	var raw := _raw_images(species)
	var sheet: SpriteSheet
	if desc.type == "static" and not desc.zones.is_empty():
		# 한 칸짜리 그림(주인공 프리셋): 쓸 칸만 잘라서 칠한다. 한 장을 통째로 칠해 담아 두면
		# 새 용 만들기에서 색을 고를 때마다 멈추고, 색마다 큰 그림이 쌓인다
		var cols := int(desc.cols)
		var cell := Rect2i((look % cols) * int(desc.fw), floori(look / float(cols)) * int(desc.fh), int(desc.fw), int(desc.fh))
		var one: Dictionary = desc.duplicate()
		one.cols = 1
		if desc.get("boxes"): one.boxes = [desc.boxes[look]]
		sheet = SpriteSheet.build(one, { sheet = tint_image(raw.sheet.get_region(cell), desc.zones, colors) }, 0)
	else:
		var images := {}
		for k in raw:
			images[k] = tint_image(raw[k], desc.zones, colors) if not desc.zones.is_empty() else raw[k]
		sheet = SpriteSheet.build(desc, images, look)
	if species == "CAST": sheet.portrait = Data.get_module("sprites").CAST_NAMES[look]
	if species == "BOSS": sheet.portrait = Data.get_module("sprites").BOSS_NAMES[look]
	if keep: _cache[key] = sheet
	return sheet


static func _hue_dist(a: float, b: float) -> float:
	var d := fmod(absf(a - b), 360.0)
	return 360.0 - d if d > 180 else d


static func _hex_to_hsl(hex: String) -> Array:
	var c := Color.html(hex)
	return Util.rgb_to_hsl(c.r8, c.g8, c.b8)


## 스프라이트 색상 교체. zones: [{ hue, range, ref, target, belly?, marks? }] — 목표색은 colors[target].
##   색조 구역(몸 · 날개): 원본에서 hue±range 에 드는 픽셀을, 구역 기준색(ref)에서 비켜 있던 만큼(색조 · 채도 · 밝기)
##   목표색 둘레로 옮긴다. 그래서 기본 색이면 원본 그대로이고, 흰색 · 검은색을 고르면 정말 희고 검다
##   (예전에는 원래 채도를 40% 남겨서 흰색이 분홍, 검은색이 남색이 됐다). 구역 사이는 부드럽게 섞는다.
##   belly: 밝고 옅은 픽셀(배의 크림 · 분홍 그늘)도 이 구역이 맡는다. 예전에는 배가 몸 색 · 날개 색으로 갈라졌다.
##   marks: 눈 · 문양. 원본에서는 회색 · 카키라 색조로는 못 찾는다(예전에는 파란 픽셀 아홉 개만 바뀌었다).
##   머리 쪽에 뭉친 회색 · 카키 덩어리를 찾아 목표색을 입힌다 (_find_marks).
## 목표색을 정하지 않은 구역(옛 기록)은 원본 그대로 둔다. 같은 색이 수없이 되풀이되니 (색 → 새 색)은 한 번만 계산한다.
static func tint_image(src: Image, zones: Array, colors: Dictionary) -> Image:
	var hue_zones := []
	var mark_zone = null
	for z in zones:
		if not colors.has(z.target): continue
		var zz := { hue = float(z.get("hue", 0)), range = float(z.get("range", 0)), belly = z.get("belly", false),
			ref = _hex_to_hsl(z.ref), t = _hex_to_hsl(colors[z.target]) }
		if z.get("marks", false): mark_zone = zz
		else: hue_zones.append(zz)
	var belly_on := hue_zones.any(func(z): return z.belly)
	var w := src.get_width()
	var h := src.get_height()
	var data := src.get_data()
	# 눈 · 문양은 문양 색이 없어도 찾아 둔다: 몸 색을 따라 물들지 않고 원본대로 남게
	var marks := _find_marks(data, w, h) if zones.any(func(z): return z.get("marks", false)) else {}
	var lut := {}
	for i in range(0, data.size(), 4):
		if data[i + 3] < 8: continue
		var key := (data[i] << 16) | (data[i + 1] << 8) | data[i + 2]
		if marks.has(i): key |= 1 << 24
		var c: int
		if lut.has(key): c = lut[key]
		elif key >> 24:
			c = _mark_color(key & 0xffffff, mark_zone) if mark_zone else key & 0xffffff
			lut[key] = c
		else:
			c = _zone_color(key, hue_zones, belly_on)
			lut[key] = c
		data[i] = c >> 16
		data[i + 1] = (c >> 8) & 255
		data[i + 2] = c & 255
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)


static func _zone_color(rgb: int, zones: Array, belly_on: bool) -> int:
	var r := rgb >> 16
	var g := (rgb >> 8) & 255
	var b := rgb & 255
	var hsl := Util.rgb_to_hsl(r, g, b)
	var hue: float = hsl[0]
	var s: float = hsl[1]
	var l: float = hsl[2]
	if l < 0.08 or (l > 0.86 and s < 0.3): return rgb   # 검은 윤곽 · 눈동자 · 흰 반짝임
	var belly := 0.0
	if belly_on:   # 밝고 옅은(채도 × 밝기 폭이 작은) 픽셀 = 배. 몸의 밝은 쪽은 진해서 여기 안 든다
		belly = smoothstep(0.62, 0.74, l) * (1.0 - smoothstep(0.32, 0.48, s * (1.0 - absf(2.0 * l - 1.0))))
	var acc := Vector3.ZERO
	var total := 0.0
	for z in zones:
		var wt := 1.0 - smoothstep(z.range - 7.0, z.range + 7.0, _hue_dist(hue, z.hue))
		wt = maxf(wt, belly) if z.belly else wt * (1.0 - belly)
		if wt <= 0.001: continue
		var ref: Array = z.ref
		var t: Array = z.t
		var d := fposmod(hue - ref[0] + 180.0, 360.0) - 180.0
		var c := Util.hsl_to_rgb(t[0] + d, clampf(minf(s / maxf(ref[1], 0.01), 1.3) * t[1], 0, 1), _remap_l(l, ref[2], t[2]))
		acc += Vector3(c[0], c[1], c[2]) * wt
		total += wt
	if total <= 0.001: return rgb
	if total > 1.0: acc /= total
	else: acc += Vector3(r, g, b) * (1.0 - total)
	return _pack(acc.x, acc.y, acc.z)


## 눈 · 문양은 원본의 명암만 따르고 색은 목표색 그대로
static func _mark_color(rgb: int, z: Dictionary) -> int:
	var hsl := Util.rgb_to_hsl(rgb >> 16, (rgb >> 8) & 255, rgb & 255)
	var t: Array = z.t
	var c := Util.hsl_to_rgb(t[0], t[1] * 0.9, _remap_l(hsl[2], z.ref[2], t[2]))
	return _pack(c[0], c[1], c[2])


## 밝기: 원본의 기준 밝기(rl)가 목표 밝기(tl)에 오도록 늘이거나 줄이되, 가장 어두운 곳 · 가장 밝은 곳은 제자리에 둔다
## (밝기 차이를 그냥 더하면 흰색 · 검은색에서 명암이 다 날아갔다). 너무 희거나 검은 목표에도 명암이 남게 0.14~0.86 으로 묶는다
static func _remap_l(l: float, rl: float, tl: float) -> float:
	tl = clampf(tl, 0.14, 0.86)
	return l / rl * tl if l <= rl else tl + (l - rl) / (1.0 - rl) * (1.0 - tl)


static func _pack(r: float, g: float, b: float) -> int:
	return (clampi(roundi(r), 0, 255) << 16) | (clampi(roundi(g), 0, 255) << 8) | clampi(roundi(b), 0, 255)


## 눈 · 문양 픽셀 (data 의 바이트 위치 → true). 회색 · 카키가 4픽셀 이상 뭉쳤고, 반 넘게 그림 가장자리에 걸치지 않았고,
## 무게중심이 앞쪽 위(왼쪽 55%. 주인공 그림은 모두 왼쪽을 본다)인 덩어리만 친다. 회색은 목 아래 무늬까지(위 58%. 이야기에
## 나오는 그 무늬다), 카키는 머리만(위 42%. 배 비늘 그늘이 카키라서). 그래야 윤곽의 회색 점, 배 비늘 그늘이 빠진다
static func _find_marks(data: PackedByteArray, w: int, h: int) -> Dictionary:
	var cand := {}    # Vector2i → 1 회색 · 2 카키
	var kinds := {}   # 색 → 0 아님 · 1 회색 · 2 카키
	var top := h
	var bot := -1
	var left := w
	var right := -1
	for y in h:
		for x in w:
			var i := (y * w + x) * 4
			if data[i + 3] < 8: continue
			top = mini(top, y); bot = maxi(bot, y); left = mini(left, x); right = maxi(right, x)
			var key := (data[i] << 16) | (data[i + 1] << 8) | data[i + 2]
			if not kinds.has(key):
				var hsl := Util.rgb_to_hsl(data[i], data[i + 1], data[i + 2])
				var s: float = hsl[1]
				var l: float = hsl[2]
				kinds[key] = 0 if l < 0.12 or l > 0.86 else 1 if s < 0.22 else 2 if hsl[0] >= 15.0 and hsl[0] <= 60.0 and s < 0.5 and l < 0.62 else 0
			if kinds[key]: cand[Vector2i(x, y)] = kinds[key]
	var out := {}
	var seen := {}
	for p in cand:
		if seen.has(p): continue
		seen[p] = true
		var comp := [p]
		var k := 0
		while k < comp.size():
			var q: Vector2i = comp[k]
			k += 1
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var n: Vector2i = q + Vector2i(dx, dy)
					if cand.has(n) and not seen.has(n):
						seen[n] = true
						comp.append(n)
		if comp.size() < MARK_MIN: continue
		var edge := 0
		var sum := Vector2i.ZERO
		for q in comp:
			sum += q
			if _touches_clear(data, w, h, q): edge += 1
		if edge * 2 > comp.size(): continue
		var gray := comp.all(func(q): return cand[q] == 1)
		if sum.y > comp.size() * (top + (bot - top) * (0.58 if gray else 0.42)) or sum.x > comp.size() * (left + (right - left) * 0.55): continue
		for q in comp: out[(q.y * w + q.x) * 4] = true
	return out


static func _touches_clear(data: PackedByteArray, w: int, h: int, p: Vector2i) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var x: int = p.x + dx
			var y: int = p.y + dy
			if x < 0 or y < 0 or x >= w or y >= h or data[(y * w + x) * 4 + 3] < 8: return true
	return false
