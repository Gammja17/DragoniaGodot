class_name KidFlight
## 내 아이에게 나는 법을 가르친다. 어린 용(TEEN)일 때 [나는 법을 가르친다]: 내가 앞에서 날고 아이가 내 뒤를 따라 난다.
## 고리 넷을 차례로 지나 처음 자리로 돌아오면 끝. 너무 앞서 가면 아이가 겁을 먹고 멈춘다. 곁으로 돌아가 줘야 다시 따라온다.
## 배운 아이는 내가 날면 같이 날고, 다 자라면 망루에 선다 (Family.morning). 어린 용일 때 가르치지 않고 다 자라면 그걸로 끝이다.
##   GameState.activity = { type = "KIDFLY", baby, kid, ring, home, rings, scared, trail, t }
##   kid.flies = true (배웠다)

const RINGS := [[0, -300], [340, -90], [0, 230], [-340, -90]]   # 처음 자리에서 (px). 한 바퀴 돌아 처음 자리로
const RING_R := 80.0          # 이 안으로 지나가면 고리를 지난 것
const SCARED_AT := 400.0      # 아이와 이만큼 멀어지면 겁을 먹고 멈춘다
const CALM_AT := 170.0        # 이만큼 곁으로 돌아가면 다시 따라온다
const WITH := 280.0           # 고리를 지날 때 아이가 이만큼 안에 있어야 같이 지난 것
const SPEED := 250.0          # 아이가 나는 빠르기
const LAG := 0.45             # 아이는 내가 지나간 길을 이만큼(초) 뒤에서 따라 난다
const FLY_H := 44.0           # 나는 아이가 떠 있는 높이


static func _lines(kid: Dictionary) -> Dictionary: return Data.get_module("family").FAMILY_LINES[kid.personality]


## 이 아이에게 지금 나는 법을 가르칠 수 있나 (어린 용이고, 아직 못 날고, 내가 날 수 있다)
static func can_teach(kid: Dictionary) -> bool:
	return kid.stage == "TEEN" and not kid.get("flies", false) and GameState.player.stage_index >= Story._adult()


## 아이와의 대화 메뉴에 붙는 한 줄
static func option(baby, kid: Dictionary, back: Callable) -> Dictionary:
	return { label = "나는 법을 가르친다", on_select = func(): _offer(baby, kid, back) }


static func _offer(baby, kid: Dictionary, back: Callable) -> void:
	if GameState.dungeon or GameState.indoors or World.dens().has(GameState.map_id):
		KidActions._show(baby, kid, "(여기서는 날개를 펼 수가 없다. 밖에 나가서 가르치자.)", [{ label = "그래.", on_select = back }])
		return
	KidActions._show(baby, kid, _lines(kid).flyAsk, [
		{ label = "좋아, 내 뒤를 따라와.", on_select = func(): start(baby, kid) },
		{ label = "다음에.", on_select = back },
	])


## 날아올라 첫 고리부터. 고리는 처음 자리를 둘러 한 바퀴
static func start(baby, kid: Dictionary) -> void:
	KidActions._close()
	var p = GameState.player
	if not p.flying: p.toggle_flight()
	if not p.flying: return   # 배가 고프다 · 천장이 있다
	var m := World.get_map(GameState.map_id)
	var home := Vector2(p.x, p.y)
	var rings := []
	for r in RINGS:
		rings.append(Vector2(clampf(home.x + r[0], 150, m.w - 150), clampf(home.y + r[1], 150, m.h - 150)))
	baby.x = p.x - 60; baby.y = p.y + 30
	GameState.activity = { type = "KIDFLY", baby = baby, kid = kid, ring = 0, home = home, rings = rings, scared = false, trail = [], t = 0.0 }
	Hud.pop("고리를 차례로 지나 처음 자리로 돌아오자. %s 내 뒤를 따라온다. 너무 앞서 가면 겁을 먹는다." % Family.iga(kid.name), "🪽")


## 다음에 지날 곳. 고리 넷을 다 지나면 처음 자리
static func goal(a: Dictionary) -> Vector2:
	return a.rings[a.ring] if a.ring < a.rings.size() else a.home


## 배우는 동안 아이의 한 프레임 (BabyDragon.update 가 부른다)
static func update(baby, dt: float) -> void:
	var a: Dictionary = GameState.activity
	var p = GameState.player
	a.t += dt
	baby.fly_h = move_toward(baby.fly_h, FLY_H, dt * 90)
	if not p.flying or not GameState.entities.babies.has(baby):   # 내려앉았거나 지도를 떠났다
		_finish(false)
		return
	a.trail.append([a.t, Vector2(p.x, p.y)])
	while a.trail.size() > 2 and a.trail[1][0] < a.t - LAG: a.trail.pop_front()
	var d := Vector2(p.x - baby.x, p.y - baby.y).length()
	if not a.scared and d > SCARED_AT:
		a.scared = true
		baby.say(_lines(a.kid).flyScared)
		Hud.pop("%s 겁을 먹고 멈췄다. 곁으로 돌아가 주자." % Family.iga(a.kid.name), "🪽")
	elif a.scared and d < CALM_AT:
		a.scared = false
		baby.say("…응, 다시 해 볼게.")
	if not a.scared:   # 내가 조금 전에 지나간 자리를 따라 난다
		var to: Vector2 = a.trail[0][1]
		var step := to - Vector2(baby.x, baby.y)
		if step.length() > 1: step = step.limit_length(SPEED * dt)
		baby.x += step.x; baby.y += step.y
	var g := goal(a)
	if Vector2(p.x - g.x, p.y - g.y).length() < RING_R and not a.scared and d < WITH:
		if a.ring >= a.rings.size():
			_finish(true)
			return
		a.ring += 1
		Particles.burst(g.x, g.y - 60, "#bfe9ff", 0.8, 14)
		Sfx.play("pickup")


static func _finish(win: bool) -> void:
	var a: Dictionary = GameState.activity
	GameState.activity = null
	var baby = a.baby
	var kid: Dictionary = a.kid
	if not win:
		Hud.pop("날기 수업을 멈췄다. %s 다음에 다시 가르치자." % Family.iga(kid.name), "🪽")
		return
	kid.flies = true
	Kids.add_affection(baby, 15)
	baby.grow(10)
	baby.say(_lines(kid).flyDone)
	Particles.burst(baby.x, baby.y - 30 - baby.fly_h, "#ffd84a", 1, 18)
	Sfx.play("relic")
	Hud.pop("%s 날 줄 알게 됐다! 이제 내가 날면 같이 난다." % Family.iga(kid.name), "🪽")
	Save.save_game()


## 고리 그리기 (효과 층): 다음 고리는 금빛, 그다음은 흐리게. 다 지났으면 처음 자리에 둥근 표시
static func draw(ci: CanvasItem) -> void:
	var a = GameState.activity
	if a == null or a.get("type") != "KIDFLY": return
	var i := int(a.ring)
	for k in 2:
		if i + k > a.rings.size(): break
		var g: Vector2 = a.rings[i + k] if i + k < a.rings.size() else a.home
		var next := k == 0
		var pulse := 0.75 + sin(GameState.game_time * 8.0) * 0.25 if next else 0.35
		var col := Color("#ffd84a") if next else Color("#dff4ff")
		ci.draw_set_transform(g, 0, Vector2(1, 0.35))
		ci.draw_circle(Vector2.ZERO, 40, Color(0, 0, 0, 0.18 * pulse))   # 그림자
		ci.draw_set_transform(g + Vector2(0, -60), 0, Vector2(0.55, 1))
		var rr := 62.0 if next else 54.0
		ci.draw_arc(Vector2.ZERO, rr, 0, TAU, 40, Color(1, 1, 1, 0.55 * pulse), 11 if next else 6)
		ci.draw_arc(Vector2.ZERO, rr, 0, TAU, 40, Color(col, 0.95 * pulse), 6 if next else 3)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
