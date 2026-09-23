class_name SpriteSheet
extends RefCounted
## 2D판 render/spritesheet.js. 스프라이트 시트 → frames[anim][dir] = [ {tex, img, sx, sy, sw, sh, flip}, ... ] 로 정규화.
## 시트마다 배치가 달라서 desc.type 별로 프레임 좌표를 계산한다.
##
##  - 'perDir' : 방향별 이미지가 따로 있고, 각 이미지가 (rows=애니메이션, cols=프레임) 격자
##  - 'rows'   : 이미지 하나, 행 = 방향(desc.rows[dir]), 열 = 프레임
##  - 'side'   : 이미지 하나, 행 = 애니메이션, 왼쪽 보는 그림만 있다. 오른쪽은 뒤집어 그리고 위/아래는 마지막 좌우를 따른다
##  - 'static' : 한 칸짜리 그림 (desc.cols 열 격자에서 look 번째 칸). 역시 왼쪽을 본다. 움직임은 draw_frame 이 코드로 준다

const DIRS := ["down", "left", "right", "up"]

var frames := {}      # anim → dir → [frame]
var anims := {}       # anim → { fps, loop, count }
var fw: float
var fh: float
var head = null       # dir → [x, y] (비율)
var box = null        # { x, y, w, h } 칸 안에서 그림이 실제로 차지하는 자리
var procedural := false
var scale := 1.0
var anchor := Vector2(0.5, 1)
var flying := false


## images: perDir → { down, left, right, up }, rows/side/static → { sheet }. 값은 Image
static func build(desc: Dictionary, images: Dictionary, look := 0) -> SpriteSheet:
	var s := SpriteSheet.new()
	s.fw = desc.fw; s.fh = desc.fh
	var textures := {}
	for k in images: textures[k] = ImageTexture.create_from_image(images[k])

	for name in desc.anims:
		var a: Dictionary = desc.anims[name]
		s.frames[name] = {}
		var count := 0
		for dir in DIRS:
			var list := []
			var type: String = desc.type
			if type == "side" or type == "static":
				if dir == "up" or dir == "down": continue   # Animator.frame 이 마지막 좌우 방향으로 대신한다
				var flip: bool = dir == "right"
				if type == "static":
					var cols := int(desc.cols)
					for i in int(a.get("count", 1)):
						list.append(_frame(textures.sheet, images.sheet, (look % cols) * s.fw, floori(look / float(cols)) * s.fh, s.fw, s.fh, flip))
				else:
					for i in int(a.count):
						list.append(_frame(textures.sheet, images.sheet, i * s.fw, a.row * s.fh, s.fw, s.fh, flip))
			elif type == "perDir":
				var start := int(a.get("start", 0))
				for i in int(a.count):
					list.append(_frame(textures[dir], images[dir], (start + i) * s.fw, a.row * s.fh, s.fw, s.fh, false))
			else:
				var row: float = desc.rows[dir]
				for col in a.cols:
					list.append(_frame(textures.sheet, images.sheet, col * s.fw, row * s.fh, s.fw, s.fh, false))
			if not list.is_empty():
				s.frames[name][dir] = list
				count = list.size()
		s.anims[name] = { fps = a.get("fps", 8) if a.get("fps") else 8, loop = a.get("loop", true) != false, count = count }

	s.head = desc.get("head")
	if desc.get("boxes"): s.box = desc.boxes[look]
	s.procedural = desc.type == "static"
	s.scale = desc.get("scale", 1.0) if desc.get("scale") else 1.0
	if desc.get("anchor"): s.anchor = Vector2(desc.anchor.x, desc.anchor.y)
	s.flying = bool(desc.get("flying", false))
	return s


static func _frame(tex: Texture2D, img: Image, sx: float, sy: float, sw: float, sh: float, flip: bool) -> Dictionary:
	return { tex = tex, img = img, sx = sx, sy = sy, sw = sw, sh = sh, flip = flip }


## 애니메이션 재생 상태. 엔티티마다 하나씩
class Animator:
	var sheet: SpriteSheet
	var name := "idle"
	var t := 0.0
	var done := false
	var last_dir := ""

	func _init(s: SpriteSheet) -> void:
		sheet = s

	## 같은 애니메이션이면 유지, 다르면 처음부터
	func play(n: String) -> void:
		if name == n: return
		if not sheet.anims.has(n): return
		name = n; t = 0.0; done = false

	## 원샷 애니(loop:false)가 끝났으면 base 로 복귀. 아니면 base 를 재생
	func play_base(base: String) -> void:
		var a = sheet.anims.get(name)
		if a and not a.loop and not done: return
		play(base)

	func update(dt: float) -> void:
		t += dt
		var a = sheet.anims.get(name)
		if a and not a.loop and t * a.fps >= a.count: done = true

	func frame(dir: String) -> Dictionary:
		var a: Dictionary = sheet.anims[name]
		var by_dir: Dictionary = sheet.frames[name]
		if by_dir.has(dir): last_dir = dir   # 좌우 그림만 있는 시트: 위/아래로 갈 땐 마지막 좌우를 유지
		var list: Array = by_dir[dir] if by_dir.has(dir) else by_dir[last_dir if last_dir != "" else "left"]
		var i := floori(t * a.fps)
		i = i % list.size() if a.loop else mini(i, list.size() - 1)
		return list[i]


# ---------- 실루엣(외곽선) ----------
# 용이 배경 픽셀에 묻히지 않도록, 스프라이트 뒤에 같은 모양을 한 가지 색으로 여러 번 어긋나게 깔아
# 테두리를 만든다. 색을 입힌 실루엣은 이미지마다 한 번만 만들어 두고 계속 쓴다.
static var _sil_cache := {}

static func silhouette(img: Image, color: Color) -> Texture2D:
	var key := "%d|%s" % [img.get_instance_id(), color.to_html()]
	if _sil_cache.has(key): return _sil_cache[key]
	var c: Image = img.duplicate()
	for y in c.get_height():
		for x in c.get_width():
			var a := c.get_pixel(x, y).a
			# source-in: 그려진 픽셀만 남기고 전부 한 색으로
			c.set_pixel(x, y, Color(color.r, color.g, color.b, a * color.a) if a > 0 else Color(0, 0, 0, 0))
	var tex := ImageTexture.create_from_image(c)
	_sil_cache[key] = tex
	return tex


const OUTLINE_STEPS := [[-1, 0], [1, 0], [0, -1], [0, 1], [-1, -1], [1, -1], [-1, 1], [1, 1]]

# 한 칸을 1x1 로 줄여 그리면 그 그림의 평균색이 한 픽셀에 담긴다. 테두리 색을 그 용이
# 실제로 띠는 색에서 뽑을 때 쓴다. 외형 시트는 여러 용이 한 장을 나눠 쓰므로 반드시 '그 칸'만 떠야 한다.
static var _avg_cache := {}

static func average_color(img: Image, sx: int, sy: int, sw: int, sh: int) -> Array:
	var key := "%d|%d,%d,%d,%d" % [img.get_instance_id(), sx, sy, sw, sh]
	if _avg_cache.has(key): return _avg_cache[key]
	# 캔버스의 축소는 알파를 곱한 채로 평균을 내고, getImageData 는 알파로 다시 나눠 돌려준다
	var r := 0.0; var g := 0.0; var b := 0.0; var a := 0.0
	for y in range(sy, sy + sh):
		for x in range(sx, sx + sw):
			var c := img.get_pixel(x, y)
			r += c.r8 * c.a; g += c.g8 * c.a; b += c.b8 * c.a; a += c.a
	var rgb := [0.0, 0.0, 0.0]
	if a > 0:
		rgb = [r / a, g / a, b / a]
	# 2D판은 투명한 여백이 섞여 있다며 여기서 평균 알파로 한 번 더 나눈다. 같은 색이 나오게 그대로 따른다
	var avg_a := a / (sw * sh)
	if avg_a == 0: avg_a = 1.0
	rgb = [minf(255, rgb[0] / avg_a), minf(255, rgb[1] / avg_a), minf(255, rgb[2] / avg_a)]
	_avg_cache[key] = rgb
	return rgb


# ---------- 한 장짜리 그림에 생명 넣기 ----------
# 기본 외형(looks.png)은 용 한 마리에 그림이 딱 한 장이다. 넘길 프레임이 없으니
# 그리는 순간에 몸을 주물러서 움직임을 만든다. 전부 변형이라 외곽선도 저절로 따라온다.

const BANDS := 8   # 성장 단계에 따라 몸을 주무를 때 쓰는 가로 띠 수
static var _band_cache := {}

## head(머리 쪽) ~ body(꼬리 쪽) 사이를 부드럽게 오가는 띠별 배율.
## 세로는 전체 키가 변하지 않도록 평균으로 정규화한다
static func _shape_bands(shape: Dictionary) -> Array:
	var key := "%s|%s" % [shape.head, shape.body]
	if _band_cache.has(key): return _band_cache[key]
	var k := []
	for i in BANDS:
		var t := i / float(BANDS - 1)
		k.append(shape.head + (shape.body - shape.head) * (t * t * (3 - 2 * t)))
	var avg := 0.0
	for v in k: avg += v
	avg /= BANDS
	var b := []
	for v in k: b.append([v, v / avg])
	_band_cache[key] = b
	return b


## 가로 띠로 나눠 그린다. 띠마다 폭이 달라서 자리마다 몸통 굵기가 달라진다
static func _draw_bands(ci: CanvasItem, tex: Texture2D, f: Dictionary, dx: float, dy: float, w: float, h: float, bands: Array) -> void:
	var sh: float = f.sh / BANDS
	var band_h := h / BANDS
	var y := dy
	for i in BANDS:
		var kx: float = bands[i][0]
		var ky: float = bands[i][1]
		var bw := w * kx
		# 1px 겹쳐 그려야 띠 사이가 실처럼 벌어지지 않는다
		ci.draw_texture_rect_region(tex, Rect2(dx + (w - bw) / 2, y, bw, band_h * ky + 1), Rect2(f.sx, f.sy + sh * i, f.sw, sh))
		y += band_h * ky


## anchor 기준점(발 위치)이 (x,y)에 오도록 ci 위에 그린다 (ci 의 좌표계로).
## motion:  { t, moving, attacking, hurt, shape } — 한 장짜리(procedural) 시트는 이 값으로 움직임과 몸 비율을 만든다
## outline: { color, width } — 스프라이트 둘레에 두를 테두리
static func draw_frame(ci: CanvasItem, sheet: SpriteSheet, f: Dictionary, x: float, y: float, scl := 1.0, motion = null, outline = null) -> void:
	var s := sheet.scale * scl
	var w: float = f.sw * s
	var h: float = f.sh * s
	var rot := 0.0
	var lunge := 0.0
	var shape = motion.get("shape") if motion else null

	if sheet.procedural and motion:
		var t: float = motion.t * (shape.tempo if shape else 1.0)   # 작은 몸은 빨리, 큰 몸은 느리게 숨 쉰다
		var breathe := sin(t * 2.4) * 0.02
		var hop := absf(sin(t * 9)) if motion.moving else 0.0
		y -= hop * 10 * scl
		h *= 1 + breathe + hop * 0.05 + (0.08 if motion.attacking else 0.0)
		w *= 1 - breathe + (0.06 if motion.attacking else 0.0)
		rot += sin(t * 4.5) * (0.055 if motion.moving else 0.014)   # 걸을 때 몸이 좌우로 흔들린다
		if motion.attacking:
			lunge += 7 * scl; rot -= 0.16                              # 덤빌 때 앞으로 튀어나가며 숙인다
		if motion.hurt > 0:
			lunge -= 11 * scl * motion.hurt; rot += 0.3 * motion.hurt  # 맞으면 뒤로 젖혀진다

	var dx := -w * sheet.anchor.x
	var dy := -h * sheet.anchor.y
	# 기울임·돌진은 뒤집기 다음에 건다. 그래야 오른쪽을 볼 때 저절로 반대로 적용된다
	# (원본 그림은 모두 왼쪽을 본다 — 그림 기준의 "앞"은 -x 쪽이다). 축은 발밑이라 몸이 발을 딛고 흔들린다
	var xf := Transform2D(0, Vector2(x, y))
	if f.flip: xf = xf.scaled_local(Vector2(-1, 1))
	if rot: xf = xf.rotated_local(rot)
	if lunge: xf = xf.translated_local(Vector2(-lunge, 0))
	ci.draw_set_transform_matrix(xf)

	var bands = _shape_bands(shape) if shape else null
	if outline:
		var sil := silhouette(f.img, outline.color)
		var r: float = outline.width
		for o in OUTLINE_STEPS:
			if bands: _draw_bands(ci, sil, f, dx + o[0] * r, dy + o[1] * r, w, h, bands)
			else: ci.draw_texture_rect_region(sil, Rect2(dx + o[0] * r, dy + o[1] * r, w, h), Rect2(f.sx, f.sy, f.sw, f.sh))
	if bands: _draw_bands(ci, f.tex, f, dx, dy, w, h, bands)
	else: ci.draw_texture_rect_region(f.tex, Rect2(dx, dy, w, h), Rect2(f.sx, f.sy, f.sw, f.sh))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
