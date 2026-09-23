class_name Lighting
extends Node2D
## 2D판 render/lighting.js. 조명.
## 절반 해상도의 "빛 지도"(Map)를 시간대별 주변광 색으로 채우고, 광원마다 밝은 원을 더한 뒤 화면에 곱한다(Multiply).
## 흰색 = 원래 색 그대로. 불처럼 스스로 빛나는 것은 그 위에 은은히 한 번 더 번지고(Emissive), 밤엔 반딧불이가 난다.
## 개체는 light() → { r, color, intensity?, emissive?, dy? } 만 내놓으면 된다 (없으면 null).
## 가장자리 어둠(비네트)은 후처리 셰이더가 맡는다 (render/post_fx.gd).

const LM_SCALE := 0.5
# [하루 중 시각(0~1), 주변광 RGB]
const AMBIENT_KEYS := [
	[0.00, [58, 72, 140]],    # 밤
	[0.20, [58, 72, 140]],
	[0.27, [255, 178, 142]],  # 새벽
	[0.36, [255, 246, 228]],  # 낮 (살짝 따뜻하게)
	[0.68, [255, 246, 228]],
	[0.76, [255, 150, 112]],  # 해질녘
	[0.84, [58, 72, 140]],
	[1.00, [58, 72, 140]],
]
const CAVE_AMBIENT := [26, 26, 38]   # 굴 속: 횃불과 제 몸의 불빛만 보인다
const CLOUD_SPAN := 4200.0           # 구름이 흘러가는 범위 (지도 한 장보다 넉넉하게)
const GROUPS := ["props", "nests", "npcs", "babies", "enemies", "bosses", "hazards", "bullets", "effects"]

var camera: GameCamera

var _clouds := []
var _fireflies := []
# 이번 프레임에 계산한 것 (세 그림이 같이 쓴다)
var _ambient := Color.WHITE
var _dark := 0.0
var _lights := []

@onready var _map: SubViewport = $Map
@onready var _base: Node2D = $Map/Base
@onready var _glows: Node2D = $Map/Glows
@onready var _multiply: TextureRect = $Multiply
@onready var _emissive: Node2D = $Emissive


func _ready() -> void:
	for i in 10:
		_clouds.append({ x = i * (CLOUD_SPAN / 10) + (i % 2) * 300, y = (i * 977) % 2400, r = 380 + (i * 53) % 160 })
	for i in 40:
		_fireflies.append({ x = randf() * 4000, y = randf() * 4000, phase = randf() * 6.28, speed = 0.5 + randf() })
	_multiply.texture = _map.get_texture()
	_base.draw.connect(_draw_base)
	_glows.draw.connect(_draw_glows)
	_emissive.draw.connect(_draw_emissive)


## 2D판 ambient(). 굴 속이면 늘 어둡고, 밖이면 하루 시각을 따라 이어 붙인다
static func ambient_rgb() -> Array:
	if GameState.dungeon or GameState.indoors: return CAVE_AMBIENT
	var t := GameState.dayTime
	var i := 1
	while AMBIENT_KEYS[i][0] < t: i += 1
	var a: Array = AMBIENT_KEYS[i - 1][1]
	var b: Array = AMBIENT_KEYS[i][1]
	var t0: float = AMBIENT_KEYS[i - 1][0]
	var t1: float = AMBIENT_KEYS[i][0]
	var k := (t - t0) / (t1 - t0) if t1 > t0 else 0.0
	return [a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k]


## 지금 어둠 (0 낮 ~ 0.7 밤). 테스트가 읽는다
func darkness() -> float: return _dark


func _process(_dt: float) -> void:
	if camera == null: return
	var view := get_viewport_rect().size
	var lm_size := Vector2i(ceili(view.x * LM_SCALE), ceili(view.y * LM_SCALE))
	if _map.size != lm_size: _map.size = lm_size
	_multiply.size = view

	# 비가 오면 푸르스름하게 어두워진다
	var wet: float = GameState.weather.get("intensity", 0.0)
	var amb := ambient_rgb()
	var r: float = amb[0] * (1 - wet * 0.34)
	var g: float = amb[1] * (1 - wet * 0.28)
	var b: float = amb[2] * (1 - wet * 0.16)
	if GameState.event == "BLOOD_MOON":   # 어두울수록 붉게
		var k := minf(1, (1 - (r + g + b) / 765.0) * 1.6)
		r += (170 - r) * k; g += (48 - g) * k; b += (70 - b) * k
	# 화면 효과 판의 "밤의 어둠": 0 이면 늘 낮처럼 흰빛
	var night: float = ScreenFx.value("night")
	_ambient = Color.WHITE.lerp(Color(r / 255.0, g / 255.0, b / 255.0), night)
	_dark = 1 - (0.3 * _ambient.r + 0.59 * _ambient.g + 0.11 * _ambient.b)

	_lights = _collect(view / camera.zoom.x)
	_base.queue_redraw()
	_glows.queue_redraw()
	_emissive.queue_redraw()


## 화면 안의 광원만 (월드 좌표)
func _collect(view_world: Vector2) -> Array:
	var cx := camera.position.x
	var cy := camera.position.y
	var E: Dictionary = GameState.entities
	var sources := []
	for gname in GROUPS: sources.append_array(E.get(gname, []))
	if GameState.player: sources.append(GameState.player)
	var out := []
	for e in sources:
		if not e.has_method("light"): continue
		var l = e.light()
		if l == null: continue
		var x: float = e.x
		var y: float = e.y + l.get("dy", 0)
		var rr: float = l.r
		if x + rr < cx or x - rr > cx + view_world.x or y + rr < cy or y - rr > cy + view_world.y: continue
		out.append({ x = x, y = y, r = rr, color = Color(l.color) if l.color is String else l.color, intensity = l.get("intensity", 1.0), emissive = l.get("emissive", false) })
	return out


func _inside() -> bool: return GameState.dungeon != null or GameState.indoors


## 빛 지도 1: 주변광으로 채우고, 낮에는 구름 그림자가 천천히 지나간다 (굴 속엔 없다)
func _draw_base() -> void:
	_base.draw_rect(Rect2(Vector2.ZERO, Vector2(_map.size)), _ambient)
	var cloud_a := 0.0 if _inside() or not ScreenFx.value("clouds") else 0.3 * maxf(0, 1 - _dark * 2.5)
	if cloud_a <= 0.01: return
	var s := camera.zoom.x * LM_SCALE
	var tex := Pixel.glow_texture()
	var t := GameState.game_time
	for c in _clouds:
		var x: float = fmod(c.x + t * 14, CLOUD_SPAN) - 600
		var y: float = c.y + sin(t * 0.05 + c.r) * 80
		_base.draw_texture_rect(tex, Rect2((x - c.r - camera.position.x) * s, (y - c.r * 0.7 - camera.position.y) * s, c.r * 2 * s, c.r * 1.4 * s), false, Color(Color("#141c3a"), cloud_a))


## 빛 지도 2: 광원마다 밝은 원을 더한다 (Glows 는 더하기 합성)
func _draw_glows() -> void:
	var power := minf(1, _dark * 1.7)
	if power <= 0.001: return
	var s := camera.zoom.x * LM_SCALE
	for l in _lights:
		Pixel.draw_glow(_glows, (l.x - camera.position.x) * s, (l.y - camera.position.y) * s, l.r * s, l.color, minf(1, l.intensity * power))


## 곱한 뒤 위에 더한다: 스스로 빛나는 것들은 낮에도 은은하게 번지고, 밤엔 반딧불이 (굴 속엔 없다)
func _draw_emissive() -> void:
	var z := camera.zoom.x
	var cam := camera.position
	for l in _lights:
		if l.emissive: Pixel.draw_glow(_emissive, (l.x - cam.x) * z, (l.y - cam.y) * z, l.r * 0.45 * z, l.color, (0.16 + _dark * 0.3) * l.intensity)
	var night := 0.0 if _inside() or not ScreenFx.value("clouds") else clampf((_dark - 0.3) * 3, 0, 1)
	if night <= 0: return
	var view := get_viewport_rect().size / z
	var t0 := GameState.game_time
	for f in _fireflies:
		var t: float = t0 * f.speed + f.phase
		var x := fposmod(f.x + sin(t * 0.7) * 60 - cam.x, view.x)
		var y := fposmod(f.y + cos(t * 0.9) * 40 - cam.y, view.y)
		var blink := 0.5 + 0.5 * sin(t * 3)
		Pixel.draw_glow(_emissive, x * z, y * z, 9 * z, Color("#d8ff7a"), night * blink)
