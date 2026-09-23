class_name Vfx
## 2D판 render/vfx.js. 한 번 재생되고 사라지는 효과들. 시트 이름이 곧 assets/vfx/ 의 파일 이름이다.
##
## 효과는 노드가 아니라 가벼운 객체로 GameState.entities.effects 에 쌓이고,
## FxLayer 가 한꺼번에 그린다 (빛을 더하는 것과 그냥 얹는 것을 층을 나눠서).

##  - 시트형: { img, fw, fh, row?, frames:[...], fps, scale, ax, ay, additive }
##  - 한 장짜리(커지며 사라짐): { img, life, from, to, spin, additive, flat?(바닥에 눕힘), rise?(떠오름) }
##  light: 조명 시스템이 읽는 값 { r, color } (조명은 6단계)
const EFFECTS := {
	"FIRE_HIT": { img = "firebolt", fw = 48, fh = 48, frames = [5, 6, 7, 8, 9, 10], fps = 20, scale = 3, ax = 0.83, ay = 0.5, additive = true, light = { r = 220, color = "#ff9a3c" } },
	"ICE_HIT": { img = "ice_hit", fw = 48, fh = 32, frames = [0, 1, 2, 3, 4, 5, 6, 7], fps = 20, scale = 3, ax = 0.5, ay = 0.5, additive = true, light = { r = 200, color = "#7fd4ff" } },
	"THUNDER_HIT": { img = "thunder_hit", fw = 32, fh = 32, frames = [0, 1, 2, 3, 4, 5], fps = 22, scale = 3.5, ax = 0.5, ay = 0.5, additive = true, light = { r = 240, color = "#ffe27a" } },
	"WATER_HIT": { img = "water_hit", fw = 64, fh = 64, frames = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], fps = 24, scale = 2.6, ax = 0.6, ay = 0.5, additive = true, light = { r = 200, color = "#7fc4ff" } },
	"WATER_SPLASH": { img = "water_splash", fw = 64, fh = 74, frames = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], fps = 20, scale = 2.4, ax = 0.5, ay = 0.95, light = { r = 180, color = "#7fc4ff" } },
	"EARTH_HIT": { img = "earth_hit", fw = 44, fh = 39, frames = [5, 6, 7, 8, 9, 10], fps = 18, scale = 3, ax = 0.5, ay = 0.5 },
	"EARTH_RISE": { img = "earth_hit", fw = 44, fh = 39, frames = [0, 1, 2, 3, 4, 5, 5, 6, 7, 8, 9, 10], fps = 18, scale = 3, ax = 0.5, ay = 0.6 },
	"GRASS_HIT": { img = "grass_hit", fw = 31, fh = 25, frames = [0, 1, 2, 3, 4, 5], fps = 18, scale = 3.4, ax = 0.5, ay = 0.6, additive = true, light = { r = 170, color = "#9fe07a" } },
	"ROOT": { img = "root", fw = 20, fh = 20, frames = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], fps = 16, scale = 4.5, ax = 0.5, ay = 0.95 },
	"SMOKE": { img = "smoke", fw = 64, fh = 64, frames = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], fps = 18, scale = 2, ax = 0.5, ay = 0.6 },
	"STAR": { img = "star", life = 0.5, from = 0.3, to = 1.6, spin = 1.5, additive = true, light = { r = 260, color = "#fff2b0" } },
	"FLAMES": { img = "flames", fw = 48, fh = 48, row = 1, frames = [0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3], fps = 10, scale = 2.4, ax = 0.5, ay = 0.85, additive = true, light = { r = 170, color = "#ff9a3c" } },
	"ICE_SPIKE": { img = "ice_spike", fw = 32, fh = 32, frames = [0, 1, 2, 3, 4, 5, 6, 7, 8, 8, 8], fps = 16, scale = 3.4, ax = 0.5, ay = 0.85, additive = true, light = { r = 160, color = "#7fd4ff" } },
	"THUNDER_BALL": { img = "thunder_ball", fw = 48, fh = 48, frames = [8, 9, 10, 11, 12, 13, 14, 15], fps = 20, scale = 3, ax = 0.5, ay = 0.5, additive = true, light = { r = 220, color = "#ffe27a" } },
	"PUFF": { img = "puff", fw = 48, fh = 32, frames = [0, 1, 2, 3, 4, 5, 6, 7, 8], fps = 22, scale = 2.2, ax = 0.5, ay = 0.7 },
	"SLASH": { img = "slash", life = 0.22, from = 0.9, to = 1.5, spin = 2.6, additive = true },
	"HIT_SPARK": { img = "flare", life = 0.16, from = 0.5, to = 1.5, spin = 0, additive = true },
	"CRIT_FLASH": { img = "star", life = 0.3, from = 0.5, to = 2.0, spin = 0.6, additive = true, light = { r = 200, color = "#ffd84a" } },
	"SPARK": { img = "spark", life = 0.25, from = 0.7, to = 1.3, spin = 0.4, additive = true },
	"MUZZLE": { img = "muzzle", life = 0.12, from = 0.5, to = 0.9, spin = 0, additive = true },
	"DUST": { img = "dirt", life = 0.5, from = 0.4, to = 1.1, spin = 0.3 },
	"SHOCKWAVE": { img = "shockwave", life = 0.45, from = 0.2, to = 3.2, spin = 0, additive = true, flat = true },
	"SCORCH": { img = "scorch", life = 2.5, from = 1.6, to = 1.7, spin = 0, flat = true },
	"GUST": { img = "twirl", life = 0.4, from = 0.8, to = 2.4, spin = 5, additive = true },
	"MAGIC_CIRCLE": { img = "circle_magic", life = 0.9, from = 1.4, to = 1.8, spin = 2.5, additive = true, flat = true },
	"HEART": { img = "heart", life = 0.9, from = 0.25, to = 0.4, spin = 0, rise = 60 },
	"AURA": { img = "aura", life = 0.8, from = 0.6, to = 1.8, spin = 1, additive = true },
	"RING": { img = "ring", life = 0.7, from = 0.2, to = 2.2, spin = 0.8, additive = true, light = { r = 300, color = "#ffe9a0" } },
	# ---- 기술 연출 재료. 크기·색은 spawn_effect 의 size·color 로 ----
	"ARC": { img = "p_arc", life = 0.26, from = 0.9, to = 1.7, spin = 2.2, additive = true },                   # 휘두른 자국
	"STREAK": { img = "p_streak", life = 0.32, from = 0.9, to = 2.0, spin = 0, additive = true },               # 바람 줄기
	"BLOOM": { img = "p_light", life = 0.34, from = 0.2, to = 0.85, spin = 0.3, additive = true, light = { r = 320, color = "#fff2b0" } },   # 확 퍼지는 빛
	"RUNE": { img = "p_rune", life = 1.1, from = 1.2, to = 1.7, spin = 1.6, additive = true, flat = true },    # 바닥 문양
	"SIGIL": { img = "p_sigil", life = 0.9, from = 0.8, to = 1.9, spin = -1.2, additive = true, flat = true },
	"HALO": { img = "p_halo", life = 0.8, from = 0.7, to = 1.1, spin = 0.8, additive = true },                 # 둘러싸는 고리 (보호막)
	"SPARKLE": { img = "p_star", life = 0.7, from = 0.35, to = 0.05, spin = 2, additive = true, rise = 90 },    # 떠오르는 반짝임
	"EMBER": { img = "p_spark", life = 0.5, from = 0.35, to = 0.9, spin = 1.5, additive = true },               # 튀는 불티
	"FALLING_STAR": { img = "p_flame", life = 0.55, from = 1.5, to = 0.8, spin = 0.4, additive = true, rise = -460, light = { r = 260, color = "#ff9a3c" } },   # 하늘에서 떨어지는 운석
	"WHIRL": { img = "p_twirl", life = 0.5, from = 0.7, to = 2.2, spin = 7, additive = true },                  # 소용돌이
	"METEOR": { img = "star", life = 0.34, from = 0.8, to = 0.12, spin = 1.2, additive = true, light = { r = 200, color = "#fff2b0" } },
}

static var _textures := {}


static func texture(key: String) -> Texture2D:
	if not _textures.has(key):
		_textures[key] = load("res://assets/vfx/%s.png" % key)
	return _textures[key]


static func _push(fx) -> void:
	GameState.entities.effects.append(fx)


## color: 한 장짜리(흰색) 효과를 물들일 색 (문자열 "#rrggbb" 또는 Color)
static func spawn_effect(name: String, x: float, y: float, opts := {}) -> void:
	var c = opts.get("color")
	_push(Effect.new(x, y, EFFECTS[name], opts.get("angle", 0.0), opts.get("size", 1.0), Color(c) if c is String else c))


static func spawn_text(x: float, y: float, text: String, color = "#fff", size := 16) -> void:
	_push(FloatText.new(x, y, text, Color(color) if color is String else color, size))


static func spawn_bolt(x1: float, y1: float, x2: float, y2: float) -> void:
	_push(Bolt.new(x1, y1, x2, y2))


static func spawn_shatter(x: float, y: float, img: Image, rect: Rect2, opts := {}) -> void:
	_push(Shatter.new(x, y, img, rect, opts))


# ---------------------------------------------------------------------------

class Effect:
	var x: float
	var y: float
	var def: Dictionary
	var color = null
	var angle: float
	var size: float
	var t := 0.0
	var remove := false
	var duration: float
	var additive: bool

	func _init(px: float, py: float, d: Dictionary, a: float, s: float, c) -> void:
		x = px; y = py; def = d; angle = a; size = s; color = c
		duration = d.frames.size() / float(d.fps) if d.has("frames") else d.life
		additive = d.get("additive", false)

	func update(dt: float) -> void:
		t += dt
		if t >= duration: remove = true

	func draw(ci: CanvasItem) -> void:
		if remove: return
		var d := def
		var img := Vfx.texture(d.img)
		var o := Vector2(roundf(x), roundf(y))
		if d.has("frames"):
			var f: int = d.frames[mini(d.frames.size() - 1, floori(t * d.fps))]
			var w: float = d.fw * d.scale * size
			var h: float = d.fh * d.scale * size
			ci.draw_set_transform(o, angle)
			ci.draw_texture_rect_region(img, Rect2(-w * d.ax, -h * d.ay, w, h), Rect2(f * d.fw, d.get("row", 0) * d.fh, d.fw, d.fh))
		else:
			var k := t / duration
			var s: float = (d.from + (d.to - d.from) * (1 - (1 - k) * (1 - k))) * 128 * size
			var xf := Transform2D(0, o)
			if d.get("rise"): xf = xf.translated_local(Vector2(0, -d.rise * k))
			if d.get("flat"): xf = xf.scaled_local(Vector2(1, 0.5))   # 바닥에 누운 원
			xf = xf.rotated_local(angle + k * d.spin)
			ci.draw_set_transform_matrix(xf)
			# 흰 그림을 color 로 물들인다 (2D판은 물들인 사본을 만들지만 곱하기로 같은 색이 나온다)
			var mod: Color = color if color != null else Color.WHITE
			mod.a = 1 - k * k
			ci.draw_texture_rect(img, Rect2(-s / 2, -s / 2, s, s), false, mod)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## 쓰러질 때 몸이 가로 띠로 쪼개져 흩날린다. 그냥 사라지면 "없어졌다"지만 조각이 날면 "부쉈다"가 된다
class Shatter:
	var x: float
	var y: float
	var img: Image
	var rect: Rect2
	var scale: float
	var flip: bool
	var color: Color
	var t := 0.0
	var life := 0.34
	var remove := false
	var bits := []
	var additive := false

	func _init(px: float, py: float, image: Image, r: Rect2, opts: Dictionary) -> void:
		x = px; y = py; img = image; rect = r
		scale = opts.get("scale", 3.0); flip = opts.get("flip", false)
		color = Color(opts.get("color", "#fff"))
		var bands: int = opts.get("bands", 6)
		# 띠마다 날아가는 방향이 다르다. 위쪽 띠가 더 멀리 튄다
		for i in bands:
			bits.append({ i = i, vx = (randf() - 0.5) * 210, vy = -60 - (bands - i) * 26 - randf() * 50, spin = (randf() - 0.5) * 7 })

	func update(dt: float) -> void:
		t += dt
		if t >= life: remove = true

	func draw(ci: CanvasItem) -> void:
		if remove: return
		var k := t / life
		var n := bits.size()
		var sh := rect.size.y / n
		var w := rect.size.x * scale
		var bh := sh * scale
		# 처음엔 하얗게 타다가 제 색으로 식으며 사라진다
		var tex: Texture2D = SpriteSheet.silhouette(img, Color.WHITE) if k < 0.45 else TileImages.get_texture("dungeon")
		var mod := Color(1, 1, 1, 1 - k * k)
		for b in bits:
			var xf := Transform2D(0, Vector2(x + b.vx * k, y - rect.size.y * scale * 0.5 + b.i * bh + b.vy * k + 340 * k * k))
			xf = xf.rotated_local(b.spin * k)
			if flip: xf = xf.scaled_local(Vector2(-1, 1))
			ci.draw_set_transform_matrix(xf)
			ci.draw_texture_rect_region(tex, Rect2(-w / 2, -bh / 2, w, bh + 1), Rect2(rect.position.x, rect.position.y + sh * b.i, rect.size.x, sh), mod)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## 번개가 튈 때 두 점을 잇는 지그재그 섬광
class Bolt:
	var x: float
	var y: float
	var t := 0.0
	var remove := false
	var points := PackedVector2Array()
	var additive := true

	func _init(x1: float, y1: float, x2: float, y2: float) -> void:
		x = (x1 + x2) / 2; y = (y1 + y2) / 2
		var n := 7
		for i in n + 1:
			var k := i / float(n)
			var jitter := 0.0 if i == 0 or i == n else 14.0
			points.append(Vector2(x1 + (x2 - x1) * k + (randf() - 0.5) * jitter * 2, y1 + (y2 - y1) * k + (randf() - 0.5) * jitter * 2))

	func update(dt: float) -> void:
		t += dt
		if t > 0.18: remove = true

	func draw(ci: CanvasItem) -> void:
		var a := maxf(0, 1 - t / 0.18)
		ci.draw_polyline(points, Color(1, 226 / 255.0, 122 / 255.0, 0.35 * a), 7, true)
		ci.draw_polyline(points, Color(1, 251 / 255.0, 224 / 255.0, a), 2.5, true)


## 떠오르며 사라지는 글자 (피해량, 획득 골드 등)
class FloatText:
	var x: float
	var y: float
	var text: String
	var color: Color
	var size: int
	var t := 0.0
	var remove := false
	var additive := false

	func _init(px: float, py: float, s: String, c: Color, sz: int) -> void:
		x = px + (randf() - 0.5) * 24; y = py
		text = s; color = c; size = sz

	func update(dt: float) -> void:
		t += dt
		y -= (60 - t * 50) * dt
		if t > 0.9: remove = true

	func draw(ci: CanvasItem) -> void:
		var a := minf(1, (0.9 - t) * 3)
		var fs := 24 if size >= 18 else 12
		var font := Fonts.bold()
		var w := Fonts.text_width(font, text, fs)
		var pos := Vector2(roundf(x - w / 2), roundf(y))
		ci.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.75 * a))
		ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(color, color.a * a))
