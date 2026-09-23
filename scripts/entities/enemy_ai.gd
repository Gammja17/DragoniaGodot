class_name EnemyAI
## 2D판 entities/enemyAI.js. 적의 행동.
##
## 모든 공격은 예고(tell) → 발동(act) → 숨 고르기(recover) 를 거친다. 예고를 보고 피하는 게 전투의 알맹이다.
##
##   chase   어슬렁 다가와 덤빈다. 덤비기 전 0.5초 움츠린다
##   charge  멀리서 몸을 낮추고(0.6초, 바닥에 선) 직선으로 돌진. 빗나가면 벽에 박혀 기절
##   flank   무리가 나를 둘러싸고, 한 마리씩 차례로 덤빈다
##   kite    거리를 두고 세 발씩 쏜다. 쏘기 전 조준선. 다가가면 옆으로 빠진다
##   burrow  땅속에 숨어 발밑으로 온다. 흙더미가 0.7초 솟은 뒤 튀어나온다
##   guard   앞을 막는다. 정면에서 오는 탄을 튕겨낸다 — 옆이나 뒤에서 때려야 한다
##   summon  뒤에서 8초마다 졸개를 부른다. 먼저 잡는 게 답이다
##   swarm   약하고 많고 빠르다. 흔들리며 몰려온다
##   flee    사냥감. 도망만 다닌다
##
## 각 행동은 fsm 하나: e.ai = { s: 상태, t: 남은 시간, ... }

const RING := 120             # flank: 링 반지름 (150 이면 달려들어도 몸에 안 닿았다)
const LUNGE_RANGE := 78       # chase/flank: 덤비는 거리
const REACH := 46             # 맞았다고 치는 거리
const LEASH := 1100           # 이보다 멀어지면 쫓기를 그만두고 제자리로 돌아간다
# 어그로 반경. 이 안에 들어가거나 먼저 때려야 덤빈다. 그 전엔 제 자리 근처를 어슬렁거린다
const AGGRO := { "chase": 300, "charge": 380, "flank": 320, "kite": 380, "ranged": 380, "burrow": 240, "guard": 270, "summon": 320, "swarm": 290, "erratic": 290, "flee": 0 }


static func init_ai(e) -> void:
	e.ai = { s = "idle", t = 0.0, dir = 0.0, cd = Util.rand_range(0.4, 1.4), wt = Util.rand_range(0.5, 2.5), wdir = Util.rand_range(0, TAU), wmove = false, hit = false, reach = 0.0, shots = 0, side = 0 }
	e.home = Vector2(e.x, e.y)
	e.aggro = e.def.move == "flee"   # 사냥감은 늘 제 행동(도망)을 한다
	if e.def.move == "burrow":
		e.ai.s = "hidden"; e.is_hidden = true


## 한 방. 예고 있는 공격만 피해를 준다
static func strike(e, mult := 1.0) -> bool:
	var p = GameState.player
	if p.flying and not e.def.get("flying"): return false   # 하늘에 있는 놈은 발톱이 안 닿는다
	var base: float = e.def.hit if e.def.get("hit") != null else e.def.damage * 2
	var dmg: float = base * float(e.power) * (1.5 if e.elite else 1.0) * (1.35 if e.frenzied else 1.0) * mult
	if Util.dist(e, p) < REACH + (16 if e.elite else 0) + e.ai.reach:
		p.take_damage(dmg)
		return true
	return false


static func face(e, tx: float, ty: float) -> void:
	e.angle = atan2(ty - e.y, tx - e.x)


static func move(e, a: float, speed: float, dt: float) -> void:
	if e.def.get("flying"):
		e.x += cos(a) * speed * dt; e.y += sin(a) * speed * dt
	else:
		Collision.slide_move(e, e.x + cos(a) * speed * dt, e.y + sin(a) * speed * dt, 14)


# ---------- 행동들 ----------

static func chase(e, dt: float, d: float, speed: float) -> void:
	var p = GameState.player
	var a: Dictionary = e.ai
	match a.s:
		"idle", "approach":
			face(e, p.x, p.y)
			if d > LUNGE_RANGE:
				move(e, e.angle, speed, dt); a.s = "approach"
			elif a.cd <= 0:
				a.s = "tell"; a.t = 0.5; a.dir = e.angle
		"tell":
			a.t -= dt
			if a.t <= 0:
				a.s = "act"; a.t = 0.18; a.dir = atan2(p.y - e.y, p.x - e.x); a.hit = false
		"act":
			a.t -= dt
			move(e, a.dir, speed * 4.2, dt)
			if not a.hit and strike(e): a.hit = true
			if a.t <= 0:
				a.s = "recover"; a.t = 0.6; a.cd = Util.rand_range(0.9, 1.6)
		"recover":
			a.t -= dt
			if a.t <= 0: a.s = "approach"


static func swarm(e, dt: float, d: float, speed: float) -> void:
	var p = GameState.player
	var a: Dictionary = e.ai
	face(e, p.x, p.y)
	var wob := sin(GameState.game_time * 5 + e.phase) * 1.1
	if a.s == "act":
		a.t -= dt
		move(e, a.dir, speed * 2.6, dt)
		if not a.hit and strike(e, 0.8): a.hit = true
		if a.t <= 0:
			a.s = "idle"; a.cd = Util.rand_range(1.0, 1.8)
		return
	if d > 60: move(e, e.angle + wob, speed, dt)
	elif a.cd <= 0:
		a.s = "act"; a.t = 0.22; a.dir = e.angle; a.hit = false


static func charge(e, dt: float, d: float, speed: float) -> void:
	var p = GameState.player
	var a: Dictionary = e.ai
	match a.s:
		"idle", "approach":
			face(e, p.x, p.y)
			if d > 340: move(e, e.angle, speed, dt)
			elif d < 90: move(e, e.angle + PI, speed * 0.7, dt)   # 너무 붙으면 물러나 거리를 잡는다
			elif a.cd <= 0:
				a.s = "tell"; a.t = 0.6; a.dir = e.angle; Sfx.play("ui")
		"tell":
			a.t -= dt
			a.dir = atan2(p.y - e.y, p.x - e.x)   # 예고 중에는 계속 겨눈다 — 마지막 순간에 비켜야 한다
			if a.t <= 0:
				a.s = "act"; a.t = 0.55; a.hit = false; a.reach = 10.0
		"act":
			a.t -= dt
			var bx: float = e.x
			var by: float = e.y
			move(e, a.dir, speed * 3.4, dt)
			var moved := Vector2(e.x - bx, e.y - by).length()
			if not a.hit and strike(e, 1):
				a.hit = true; GameCamera.current.shake(6)
			# 벽에 박혔다 — 기절
			if moved < speed * 3.4 * dt * 0.25 and not e.def.get("flying"):
				a.s = "stun"; a.t = 1.1; Particles.burst(e.x, e.y - 10, "#ddd", 0.6, 8); GameCamera.current.shake(4)
				return
			if a.t <= 0:
				a.s = "recover"; a.t = 0.5; a.cd = Util.rand_range(1.4, 2.4); a.reach = 0.0
		"stun":
			a.t -= dt
			if a.t <= 0:
				a.s = "approach"; a.cd = 0.6; a.reach = 0.0
		"recover":
			a.t -= dt
			if a.t <= 0: a.s = "approach"


## 같은 지도에서 나를 둘러싸는 무리 (포위 행동인 것들)
static func packmates() -> Array:
	return GameState.entities.enemies.filter(func(o): return not o.remove and o.def.move == "flank" and Util.dist(o, GameState.player) < 520)


static func flank(e, dt: float, d: float, speed: float) -> void:
	var p = GameState.player
	var a: Dictionary = e.ai
	if a.s == "act":
		a.t -= dt
		move(e, a.dir, speed * 3.2, dt)
		if not a.hit and strike(e): a.hit = true
		if a.t <= 0:
			a.s = "recover"; a.t = 0.7; a.cd = Util.rand_range(1.6, 2.6); GameState.packTurn = GameState.game_time + 0.9
		return
	if a.s == "tell":
		a.t -= dt
		a.dir = atan2(p.y - e.y, p.x - e.x)
		if a.t <= 0:
			a.s = "act"; a.t = 0.30; a.hit = false
		return
	if a.s == "recover":
		a.t -= dt
		if a.t <= 0: a.s = "ring"
		return
	# 링 위의 제 자리로 간다. 자리는 무리 안에서의 순번으로 정한다
	var mates := packmates()
	var i := maxi(0, mates.find(e))
	var n := maxi(1, mates.size())
	var base := atan2(e.y - p.y, e.x - p.x)
	var slot := base if n == 1 else (i / float(n)) * TAU + GameState.game_time * 0.25
	var tx: float = p.x + cos(slot) * RING
	var ty: float = p.y + sin(slot) * RING
	var dd := Vector2(tx - e.x, ty - e.y).length()
	face(e, p.x, p.y)
	if dd > 18: move(e, atan2(ty - e.y, tx - e.x), speed * (1.0 if dd > 120 else 0.6), dt)
	a.s = "ring"
	# 한 마리씩 차례로 덤빈다
	var turn_free := not (GameState.packTurn > GameState.game_time)
	if turn_free and a.cd <= 0 and d < RING + 60:
		GameState.packTurn = GameState.game_time + 1.3
		a.s = "tell"; a.t = 0.55; a.dir = e.angle


static func kite(e, dt: float, d: float, speed: float) -> void:
	var p = GameState.player
	var a: Dictionary = e.ai
	face(e, p.x, p.y)
	if a.s == "tell":
		a.t -= dt
		if a.t <= 0:
			a.s = "act"; a.t = 0.0; a.shots = 3
		return
	if a.s == "act":
		a.t -= dt
		if a.t <= 0 and a.shots > 0:
			a.shots -= 1; a.t = 0.16
			var aim := atan2(p.y - 30 - (e.y - 16), p.x - e.x) + Util.rand_range(-0.06, 0.06)
			var base: float = e.def.hit if e.def.get("hit") != null else e.def.damage
			Projectile.add(Projectile.new(e.x, e.y - 16, aim, { faction = "ENEMY", element = e.def.get("element"), damage = base * float(e.power) * (1.5 if e.elite else 1.0), speed = 330, life = 2.4, scale = 0.7 }))
			Sfx.play("shoot")
		if a.shots <= 0 and a.t <= 0:
			a.s = "idle"; a.cd = Util.rand_range(1.8, 2.8)
		return
	# 거리 유지: 가까우면 옆으로 빠지며 물러난다
	if d < 240:
		if not a.side: a.side = 1 if randf() < 0.5 else -1
		move(e, e.angle + PI + a.side * 0.9, speed * 1.15, dt)
	elif d > 400: move(e, e.angle, speed, dt)
	elif a.cd <= 0 and d < 520:
		a.s = "tell"; a.t = 0.45


static func burrow(e, dt: float, d: float, speed: float) -> void:
	var p = GameState.player
	var a: Dictionary = e.ai
	match a.s:
		"hidden":
			e.is_hidden = true
			# 땅속에서는 곧장 발밑으로 다가온다 (보이지 않는다)
			if d > 40:
				face(e, p.x, p.y); move(e, e.angle, speed * 1.4, dt)
			elif a.cd <= 0:
				a.s = "tell"; a.t = 0.7
		"tell":
			a.t -= dt
			if a.t <= 0:
				a.s = "act"; a.t = 0.2; e.is_hidden = false; a.reach = 30.0
				Particles.burst(e.x, e.y, "#a0793a", 0.9, 12); GameCamera.current.shake(5); Sfx.play("dieBig")
				strike(e, 1)
		"act":
			a.t -= dt
			if a.t <= 0:
				a.s = "surface"; a.t = Util.rand_range(2.2, 3.4); a.reach = 0.0
		"surface":     # 잠깐 땅 위에서 어슬렁거린다 — 이때 때려야 한다
			a.t -= dt
			face(e, p.x, p.y)
			if d > 70: move(e, e.angle, speed * 0.7, dt)
			elif randf() < dt * 1.5:
				a.s = "tell2"; a.t = 0.4
			if a.t <= 0:
				a.s = "hidden"; a.cd = Util.rand_range(1.2, 2.0); Particles.burst(e.x, e.y, "#a0793a", 0.6, 8)
		"tell2":       # 땅 위에서의 짧은 물기
			a.t -= dt
			if a.t <= 0:
				strike(e, 0.7); a.s = "surface"; a.t = maxf(a.t, 0.8)


static func guard(e, dt: float, d: float, speed: float) -> void:
	var p = GameState.player
	var a: Dictionary = e.ai
	face(e, p.x, p.y)
	e.guard_angle = e.angle       # 이쪽에서 오는 탄을 막는다 (Projectile 이 본다)
	if a.s == "act":
		a.t -= dt
		move(e, a.dir, speed * 2.8, dt)
		if not a.hit and strike(e, 1.2): a.hit = true
		if a.t <= 0:
			a.s = "recover"; a.t = 0.9; a.cd = Util.rand_range(1.8, 2.8)
		return
	if a.s == "tell":
		a.t -= dt
		if a.t <= 0:
			a.s = "act"; a.t = 0.22; a.dir = e.angle; a.hit = false
		return
	if a.s == "recover":
		a.t -= dt
		if a.t <= 0: a.s = "idle"
		return
	if d > 90: move(e, e.angle, speed * 0.85, dt)      # 느리게, 방패를 앞세우고
	elif a.cd <= 0:
		a.s = "tell"; a.t = 0.6


static func summon(e, dt: float, d: float, speed: float) -> void:
	var p = GameState.player
	var a: Dictionary = e.ai
	face(e, p.x, p.y)
	if a.s == "tell":
		a.t -= dt
		if a.t <= 0:
			a.s = "idle"; a.cd = 8.0
			var kind: String = e.def.get("minion", "SLIME")
			var alive: int = GameState.entities.enemies.filter(func(o): return not o.remove and o.summoned_by == e).size()
			for i in 2:
				if alive + i >= 4: break
				var ang := Util.rand_range(0, TAU)
				var m := Enemy.make(e.x + cos(ang) * 60, e.y + sin(ang) * 60, kind)
				m.summoned_by = e
				m.aggro = true
				World.add_entity("enemies", m)
				Particles.burst(m.x, m.y, e.def.color, 0.8, 8)
			Sfx.play("relic")
		return
	if d < 200: move(e, e.angle + PI, speed, dt)
	elif d > 420: move(e, e.angle, speed * 0.8, dt)
	if a.cd <= 0 and d < 560:
		a.s = "tell"; a.t = 1.0


static func flee(e, dt: float, d: float, speed: float) -> void:
	var p = GameState.player
	if d < 300: e.angle = atan2(e.y - p.y, e.x - p.x) + sin(GameState.game_time * 3 + e.phase) * 0.6
	elif randf() < dt * 0.5: e.angle = randf() * 6.28
	move(e, e.angle, speed if d < 300 else speed * 0.25, dt)


## 매 프레임. 상태별로 알맞은 행동을 돌린다
static func update(e, dt: float, speed: float) -> void:
	if e.ai.cd > 0: e.ai.cd -= dt
	var d := Util.dist(e, GameState.player)
	# 어그로가 없으면 덤비지 않는다. 반경 안에 들어오면 알아채고, 멀어지면 잊는다
	if not e.aggro:
		var range: float = AGGRO.get(e.def.move, 240) * (1.15 if e.elite else 1.0)
		if range and d < range and not GameState.player.invisible: alert(e)
		else:
			_wander(e, dt, speed)
			return
	elif d > LEASH:
		e.aggro = false
		e.ai.s = "hidden" if e.def.move == "burrow" else "idle"
		if e.def.move == "burrow": e.is_hidden = true
		return
	match e.def.move:
		"erratic", "swarm": swarm(e, dt, d, speed)
		"charge": charge(e, dt, d, speed)
		"flank": flank(e, dt, d, speed)
		"kite", "ranged": kite(e, dt, d, speed)
		"burrow": burrow(e, dt, d, speed)
		"guard": guard(e, dt, d, speed)
		"summon": summon(e, dt, d, speed)
		"flee": flee(e, dt, d, speed)
		_: chase(e, dt, d, speed)


## 알아챘다. 같은 무리(가까이 있는 놈들)도 같이 돌아본다
static func alert(e, chain := true) -> void:
	if e.aggro or e.remove or e.def.move == "none": return
	e.aggro = true
	Vfx.spawn_text(e.x, e.y - (100 if e.elite else 70), "!", "#ffd84a", 16)
	if not chain: return
	for o in GameState.entities.enemies:
		if o != e and not o.aggro and Util.dist(o, e) < 220: alert(o, false)


## 어그로 전: 제 자리 근처를 느릿느릿 오간다. 잠복형은 땅속에 그대로
static func _wander(e, dt: float, speed: float) -> void:
	var a: Dictionary = e.ai
	if e.def.move == "burrow": return
	a.wt -= dt
	if a.wt <= 0:
		a.wmove = not a.wmove
		a.wt = Util.rand_range(0.6, 1.4) if a.wmove else Util.rand_range(1.5, 4)
		# 집에서 멀어졌으면 돌아오는 쪽으로
		var far: bool = Util.dist(e, e.home) > 160
		a.wdir = atan2(e.home.y - e.y, e.home.x - e.x) if far else Util.rand_range(0, TAU)
	if a.wmove:
		e.angle = a.wdir; move(e, a.wdir, speed * 0.35, dt)


## 정면 방패: 이 각도에서 온 탄은 막힌다 (guard 행동만)
static func blocks_from(e, from_x: float, from_y: float) -> bool:
	if not (e is Enemy) or e.def.move != "guard": return false
	if e.ai.s == "act" or e.ai.s == "recover": return false
	if e.guard_angle == null: return false
	var da: float = atan2(from_y - e.y, from_x - e.x) - e.guard_angle
	da = atan2(sin(da), cos(da))
	return absf(da) < PI * 0.42


## 예고를 바닥에 그린다 (개체보다 먼저, 바닥 층에서). 보고 피할 수 있어야 하니까 크고 분명하게
static func draw_tell(ci: CanvasItem, e) -> void:
	var a: Dictionary = e.ai
	var t := GameState.game_time
	var mv: String = e.def.move
	if a.s == "tell" or a.s == "tell2":
		var k := 1 - maxf(0, a.t) / (0.6 if mv == "charge" else 0.7 if mv == "burrow" else 0.5)
		if mv == "charge":
			# 돌진 선
			var from := Vector2(e.x, e.y)
			ci.draw_dashed_line(from, from + Vector2(cos(a.dir), sin(a.dir)) * 330, Color(1, 90 / 255.0, 60 / 255.0, 0.35 + k * 0.5), 6 + k * 8, 16)
		elif mv == "burrow" and a.s == "tell":
			# 흙더미
			ci.draw_set_transform(Vector2(e.x, e.y), 0, Vector2(1, (12 + k * 9) / (22 + k * 18)))
			ci.draw_circle(Vector2.ZERO, 22 + k * 18, Color(120 / 255.0, 85 / 255.0, 40 / 255.0, 0.5 + k * 0.4))
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)
			for i in 5:
				var q := t * 9 + i * 1.3
				ci.draw_rect(Rect2(e.x + cos(q) * 14 * k - 2, e.y - 4 - absf(sin(q)) * 14 * k, 4, 4), Color(70 / 255.0, 45 / 255.0, 20 / 255.0, 0.6))
		elif mv == "kite" or mv == "ranged":
			# 조준선
			var p = GameState.player
			ci.draw_dashed_line(Vector2(e.x, e.y - 16), Vector2(p.x, p.y - 30), Color(1, 220 / 255.0, 120 / 255.0, 0.25 + k * 0.45), 2, 6)
		else:
			# 덤빔: 발밑 고리가 조여든다
			_ellipse(ci, e.x, e.y, 34 - k * 10, 17 - k * 5, Color(1, 120 / 255.0, 80 / 255.0, 0.4 + k * 0.5), 3)
	if a.s == "stun":
		# 기절 별
		for i in 3:
			Fonts.draw_centered(ci, ThemeDB.fallback_font, "★", e.x + cos(t * 6 + i * 2.1) * 20, e.y - 44 + sin(t * 6 + i * 2.1) * 6, 16, Color("#ffe27a"))
	if mv == "guard" and a.s != "act" and e.guard_angle != null:
		# 방패 호
		ci.draw_arc(Vector2(e.x, e.y - 14), 30, e.guard_angle - 1.25, e.guard_angle + 1.25, 24, Color(180 / 255.0, 200 / 255.0, 230 / 255.0, 0.8), 5)


static func _ellipse(ci: CanvasItem, x: float, y: float, rx: float, ry: float, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 41:
		var a := TAU * i / 40.0
		pts.append(Vector2(x + cos(a) * rx, y + sin(a) * ry))
	ci.draw_polyline(pts, color, width, true)
