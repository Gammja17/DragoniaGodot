class_name DiveFish
## 하늘에서 덮치는 낚시. 성체가 되어 물 위를 날면 물속 물고기 그림자가 보인다 (물가에 서서는 물빛에 가려 안 보인다).
## 내 그림자를 물고기 그림자에 겹치고 [Space](또는 [E])를 눌렀다 떼면 내리꽂아 잡는다.
## 큰 그림자는 꾹 눌러 힘을 다 모았다가 떼야 잡힌다. 너무 오래 노려보면 큰 놈이 눈치채고 달아난다.
## 물고기 종류(data/fishing.json)는 지도 · 시각 · 날씨 · 그날 밤의 일(붉은 달 · 유성우 · 달맞이 모임)에 따라 다르다.
## 낚싯대(Dragon.interact)로는 작은 물고기만 올라온다 (큰 놈은 줄을 끊는다).
## 잡아 본 종류는 GameState.stats.fishKinds { id: 마리 } 에 쌓여 일지 [기록]의 물고기 도감이 된다.
## 그림자는 저장하지 않는다. 날아오를 때마다 새로 떠오른다.

const CHARGE_TIME := 0.9      # 힘이 다 모이는 데 걸리는 시간 (초)
const SPOOK_TIME := 2.6       # 큰 놈 위에서 이보다 오래 노려보면 눈치채고 달아난다
const PLUNGE := 0.5           # 물낯까지 내리꽂았다 다시 떠오르는 시간
const REACH_SMALL := 64.0     # 발밑 고리의 크기. 이 안에 든 그림자를 잡는다
const REACH_BIG := 80.0
const FLAT := 0.6             # 바닥에 누운 고리 · 그림자의 납작한 정도
const CHARGE_MOVE := 0.35     # 힘을 모으는 동안은 느릿느릿 따라간다
const SHADOW := Color(0.03, 0.07, 0.14)

static var shadows := []      # { x, y, a, kind, big, age, life, dash, next_dash, seed }
static var charge := -1.0     # 힘을 모으는 중이면 0 이상 (1 이면 다 모였다)
static var held := 0.0        # 누르고 있은 시간 (큰 놈이 눈치채는 데 쓴다)
static var plunge = null      # 내리꽂는 중 { t, total, full, hit }
static var _spawn_t := 0.0
static var _map := ""
static var _who = null        # 새 판이면 지난 판의 그림자를 버린다
static var _told_big := false


static func kinds() -> Array: return Data.get_module("fishing").FISH


static func busy() -> bool: return charge >= 0 or plunge != null


## 힘을 모으는 동안 움직이는 빠르기 배율
static func move_mult() -> float: return CHARGE_MOVE if charge >= 0 else 1.0


static func reset() -> void:
	shadows.clear()
	charge = -1.0
	held = 0.0
	plunge = null


## 매 프레임 (내 용의 조작 뒤). 날지 않으면 그림자를 거둔다
static func update(p, dt: float) -> void:
	if p != _who or GameState.map_id != _map:
		reset()
		_who = p
		_map = GameState.map_id
	if plunge: _update_plunge(p, dt)
	if not p.flying or GameState.dungeon or GameState.indoors or Terrain.active_biome() == "VOLCANO":
		shadows.clear()
		charge = -1.0
		return
	_update_shadows(dt)
	_spawn_t -= dt
	if _spawn_t <= 0:
		_spawn_t = Util.rand_range(0.8, 1.8)
		if shadows.size() < (6 if GameState.map_id == "LAKE" else 4): _spawn(p)
	_update_charge(p, dt)


static func over_water(p) -> bool: return Terrain.ground_at(p.x, p.y) == "WATER"


## 머리 위 안내 ("Space 덮친다"). 할 게 없으면 ""
static func tip(p) -> String:
	if not p.flying or plunge or not over_water(p): return ""
	if charge >= 0: return "Space 지금 뗀다!" if charge >= 1 else "Space 힘을 모은다…"
	var s = _under(p)
	if not s: return ""
	return "Space 꾹 눌러 힘을 모았다가 뗀다" if s.big else "Space 덮친다"


# ---------- 그림자 ----------

static func _update_shadows(dt: float) -> void:
	for s in shadows:
		s.age += dt
		s.dash -= dt
		s.next_dash -= dt
		if s.next_dash <= 0:   # 가끔 확 방향을 틀며 내달린다. 큰 놈이 더 자주 튄다
			s.next_dash = Util.rand_range(2.5, 5.0) if s.big else Util.rand_range(4.0, 8.0)
			s.dash = 0.6
			s.a += Util.rand_range(-1.4, 1.4)
		s.a += sin(s.age * 0.8 + s.seed) * dt * 0.9   # 느긋하게 굽이친다
		var spd: float = (110.0 if s.dash > 0 else 24.0) if s.big else (130.0 if s.dash > 0 else 36.0)
		var nx: float = s.x + cos(s.a) * spd * dt
		var ny: float = s.y + sin(s.a) * spd * dt * FLAT
		if _deep(nx + cos(s.a) * 20, ny + sin(s.a) * 12):
			s.x = nx
			s.y = ny
		else: s.a += PI * Util.rand_range(0.7, 1.3)   # 물가에 닿으면 돌아선다
	shadows = shadows.filter(func(s): return s.age < s.life)


static func _spawn(p) -> void:
	var pool := eligible(true)
	if pool.is_empty(): return
	for i in 16:
		var a := randf() * TAU
		var r := Util.rand_range(90, 640)
		var wx: float = p.x + cos(a) * r
		var wy: float = p.y + sin(a) * r * 0.7
		if not _deep(wx, wy): continue
		var k: Dictionary = _pick(pool)
		shadows.append({ x = wx, y = wy, a = randf() * TAU, kind = k, big = bool(k.get("big", false)), age = 0.0,
			life = Util.rand_range(16, 30), dash = 0.0, next_dash = Util.rand_range(2.0, 5.0), seed = randf() * TAU })
		return


## 물가에서 한 뼘은 떨어진 물 (그림자가 뭍에 걸치지 않게)
static func _deep(x: float, y: float) -> bool:
	for o in [Vector2.ZERO, Vector2(36, 0), Vector2(-36, 0), Vector2(0, 26), Vector2(0, -26)]:
		if Terrain.ground_at(x + o.x, y + o.y) != "WATER": return false
	return true


## 발밑 고리 안에 든 그림자 가운데 가장 가까운 것
static func _under(p):
	var best = null
	var bd := 2.0
	for s in shadows:
		var R: float = REACH_BIG if s.big else REACH_SMALL
		var d := Vector2((s.x - p.x) / R, (s.y - p.y) / (R * FLAT)).length()
		if d <= 1.0 and d < bd:
			bd = d
			best = s
	return best


# ---------- 덮치기 ----------

static func _update_charge(p, dt: float) -> void:
	var down: bool = GameInput.down("confirm") or GameInput.down("interact")
	if charge < 0:
		var tapped: bool = GameInput.pressed("confirm") or GameInput.pressed("interact")
		if tapped and not plunge and not GameState.activity and over_water(p):
			charge = 0.0
			held = 0.0
		return
	if down:
		charge = minf(1.0, charge + dt / CHARGE_TIME)
		held += dt
		if held > SPOOK_TIME:   # 너무 오래 노려보면 큰 놈이 눈치챈다
			var s = _under(p)
			if s and s.big:
				_flee(s, p)
				Vfx.spawn_text(s.x, s.y - 30, "눈치챘다!", "#ffd84a", 14)
				held = 0.0
		return
	# 뗐다: 내리꽂는다
	plunge = { t = 0.0, total = PLUNGE * (1.2 if charge >= 1 else 1.0), full = charge >= 1, hit = false }
	charge = -1.0
	Sfx.play("dash")


static func _update_plunge(p, dt: float) -> void:
	plunge.t += dt
	var k: float = minf(1.0, plunge.t / plunge.total)
	p.dive_height = p.fly_lift * sin(k * PI)   # 몸이 물낯까지 내려갔다가 다시 떠오른다
	if not plunge.hit and k >= 0.5:
		plunge.hit = true
		_strike(p, plunge.full)
	if k >= 1:
		p.dive_height = 0.0
		plunge = null


static func _strike(p, full: bool) -> void:
	Vfx.spawn_effect("WATER_SPLASH", p.x, p.y + 6, { size = 1.3 if full else 1.0 })
	Particles.burst(p.x, p.y - 10, "#bfe9ff", 0.9 if full else 0.6, 16 if full else 10)
	Sfx.play("splash")
	if full: GameCamera.current.shake(4)
	var s = _under(p)
	if s == null:
		Vfx.spawn_text(p.x, p.y - 90, "첨벙!", "#bfe9ff", 14)
	elif s.big and not full:
		_flee(s, p)
		Vfx.spawn_text(s.x, s.y - 30, "힘이 모자랐다!", "#ffd84a", 14)
		if not _told_big:
			_told_big = true
			Hud.pop("큰 놈은 발톱을 뿌리치고 빠져나간다. 꾹 눌러 힘을 다 모았다가 떼야 잡힌다.", "🐟")
	else:
		shadows.erase(s)
		caught(s.kind, p)
	for o in shadows:   # 물이 튀면 곁의 물고기는 흩어진다
		if Util.dist(o, p) < 220: _flee(o, p)


static func _flee(s: Dictionary, p) -> void:
	s.a = atan2(s.y - p.y, s.x - p.x) + Util.rand_range(-0.4, 0.4)
	s.dash = 0.9


# ---------- 잡은 것 ----------

## 물고기 한 마리를 잡았다 (덮치기 · 낚싯대 둘 다). 도감에 적고 고기와 경험치를 받는다
static func caught(kind: Dictionary, p) -> void:
	var st: Dictionary = GameState.stats
	var book: Dictionary = st.get("fishKinds", {})
	var first := not book.has(kind.id)
	book[kind.id] = int(book.get(kind.id, 0)) + 1
	st.fishKinds = book
	st.fish = int(st.get("fish", 0)) + 1   # 낚은 물고기 수 (SKEAM 도전 과제)
	var meat := int(kind.get("meat", 1))
	p.inventory.meat += meat
	p.gain_xp((20 if kind.get("big") else 6) + (30 if first else 0))
	Vfx.spawn_text(p.x, p.y - 100 * p.stage.scale, "%s · 고기 +%d" % [kind.name, meat], "#9fe3ff", 16)
	if kind.get("bite"):   # 이빨고기는 잡히면서도 문다
		p.hp = maxf(1.0, p.hp - float(kind.bite))
		p.hurt_flash = 0.2
		Vfx.spawn_text(p.x, p.y - 70, "물렸다!", "#ff8a7a", 14)
	if first: Hud.pop("처음 잡았다: %s. %s" % [kind.name, kind.note], "🐟")
	Quests.notify("fish", GameState.map_id)
	Contest.on_catch(kind)   # 모임의 낚시 겨루기: 큰 고기를 먼저 건지면 이긴다


## 낚싯대에 걸린 물고기: 지금 여기서 사는 작은 물고기 가운데 하나
static func rod_catch() -> Dictionary:
	var pool := eligible(false)
	return _pick(pool) if not pool.is_empty() else kinds()[0]


## 지금 여기서 잡히는 종류. dive 가 아니면(낚싯대) 큰 놈은 빠진다
static func eligible(dive: bool) -> Array:
	return kinds().filter(func(k): return (dive or not k.get("big")) and _fits(k))


static func _fits(k: Dictionary) -> bool:
	var where: Array = k.get("where", [])
	if not where.is_empty() and not (where.has(GameState.map_id) or where.has("biome:" + Terrain.active_biome())): return false
	var h = k.get("hours")
	if h:
		var now := GameState.dayTime * 24.0
		var inside: bool = (now >= h[0] and now < h[1]) if h[0] < h[1] else (now >= h[0] or now < h[1])   # 자정을 넘기는 때
		if not inside: return false
	var w: String = k.get("weather", "")
	if w == "RAIN" and (GameState.weather.type != "RAIN" or not Weather.rain_falls_here()): return false
	if w == "STORM" and not (Weather.stormy() and Weather.rain_falls_here()): return false
	var night: String = k.get("night", "")
	if (night == "BLOOD_MOON" or night == "METEOR") and GameState.event != night: return false
	if night == "GATHER" and not Gathering.is_gather_now(): return false
	return true


static func _pick(pool: Array) -> Dictionary:
	var total := 0.0
	for k in pool: total += float(k.get("weight", 1))
	var r := randf() * total
	for k in pool:
		r -= float(k.get("weight", 1))
		if r <= 0: return k
	return pool[-1]


# ---------- 그리기 (바닥 층, 개체들 밑) ----------

static func draw(ci: CanvasItem) -> void:
	var p = GameState.player
	if not p: return
	for s in shadows: _draw_shadow(ci, s)
	if p.flying and over_water(p) and not Cutscene.on: _draw_ring(ci, p)


static func _draw_shadow(ci: CanvasItem, s: Dictionary) -> void:
	var a := clampf(minf(s.age, s.life - s.age) / 1.2, 0, 1) * (0.42 if s.big else 0.34)
	var L := 34.0 if s.big else 16.0   # 몸 길이의 반
	var W := 11.0 if s.big else 5.5
	ci.draw_set_transform_matrix(Transform2D(0, Vector2(1, FLAT), 0, Vector2(s.x, s.y)) * Transform2D(s.a, Vector2.ZERO))
	if s.kind.get("glow"): ci.draw_circle(Vector2.ZERO, L * 1.2, Color(Color(s.kind.glow), a * 0.45))   # 빛을 머금은 물고기
	var body := PackedVector2Array()
	for i in 20:
		var t := TAU * i / 20.0
		body.append(Vector2(cos(t) * L, sin(t) * W))
	ci.draw_colored_polygon(body, Color(SHADOW, a))
	var wag := sin(s.age * (14.0 if s.dash > 0 else 5.0) + s.seed) * W * 0.8   # 꼬리
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-L * 0.8, 0), Vector2(-L * 1.45, -W * 0.9 + wag), Vector2(-L * 1.45, W * 0.9 + wag)]), Color(SHADOW, a))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## 내 그림자 둘레의 고리: 이 안에 든 물고기를 덮친다. 물고기가 들면 금빛, 힘을 모으면 바깥 테가 찬다
static func _draw_ring(ci: CanvasItem, p) -> void:
	var s = _under(p)
	var R := REACH_BIG if s and s.big else REACH_SMALL
	var col := Color("#ffd84a") if s else Color(1, 1, 1)
	ci.draw_set_transform(Vector2(p.x, p.y), 0, Vector2(1, FLAT))
	ci.draw_arc(Vector2.ZERO, R, 0, TAU, 40, Color(col, 0.6 if s else 0.22), 2.5)
	if charge >= 0:
		var pulse := 0.6 + sin(GameState.game_time * 14) * 0.4 if charge >= 1 else 1.0
		ci.draw_arc(Vector2.ZERO, R + 7, -PI / 2, -PI / 2 + TAU * charge, 40, Color(Color("#ffd84a"), 0.9 * pulse), 5)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
