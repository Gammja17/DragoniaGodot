class_name Race
## 비류와 호수 경주: 나는 하늘로, 비류는 물로. 비류가 물안개로 띄운 고리를 차례로 빠져나가 첫 고리로 먼저 돌아오면 이긴다.
## 그동안 비류는 신비의 호수를 세 바퀴 헤엄친다. 구름마루 용은 날개가 없어 물을 탄다 (날개가 있는 건 유안뿐이다).
## 비류는 달맞이 모임으로 두 마을이 다시 오가게 된 뒤로 오후마다 호수에 내려와 헤엄친다 (routines.json).
## 한 판 질 때마다 물살을 새로 읽어 더 빨라진다 (세 판). 가장 빠른 기록은 일지 [기록]에 남는다.
## 달맞이 모임의 겨루기(Contest)도 같은 판을 폭포 길에서 쓴다 (course · onEnd).
##   GameState.activity = { type = "RACE", npc, course, t (음수면 출발 전), ring, target, level, onEnd }
##   GameState.story.race = { best, level (이긴 판 수), winDay }

const MAP := "LAKE"
const LAKE := Vector2(816, 1008)      # 호수 한가운데 (maps.json LAKE ponds [8, 10, 4])
const SWIM_R := 250.0                  # 비류가 헤엄치는 둘레
const LAPS := 3                        # 비류가 도는 바퀴
const RING_R := 70.0                   # 이 안으로 지나가면 고리를 빠져나간 것
const COUNT := 3.0                     # 출발 전 셈
const TIMES := [20.0, 15.0, 11.5]      # 판마다 비류가 세 바퀴를 도는 시간
## 호수 둘레의 고리 (시계 방향). 마지막에 첫 고리로 돌아오면 들어온 것
const RINGS := [[816, 330], [1350, 420], [1760, 760], [1560, 1210], [1160, 1330], [816, 1250],
	[470, 1330], [150, 1120], [170, 640], [470, 330]]
const WIN_LINES := [
	"…하, 졌다. 하늘길이 그렇게 곧을 줄이야. 다음엔 물살을 더 읽고 온다.",
	"또 졌어! 물살 읽는 법까지 새로 익혔는데. …좋아, 마지막 판이다. 이번엔 진짜 온 힘으로 간다.",
	"…인정. 구름마루에서 나를 이긴 용은 이제 너 하나야. 몸이 굳지 않게 가끔 붙어 줘.",
]


## 경주 길: 지도 · 고리 · 비류가 도는 물 한가운데와 둘레 · 막대에 적는 이름. 기본은 호수 한 바퀴
static func lake_course() -> Dictionary:
	return { map = MAP, rings = RINGS, center = LAKE, swim_r = SWIM_R, title = "비류와 경주" }


static func _r() -> Dictionary:
	if not GameState.story.has("race"): GameState.story.race = { best = 0.0, level = 0, winDay = -1 }
	return GameState.story.race


## 비류와 겨룰 수 있게 됐나: 달맞이 모임으로 두 마을이 다시 오간 뒤 (어둠의 길에서는 구름마루와 갈라선다)
static func unlocked() -> bool:
	return GameState.story.get("events", []).has("ev_gathering") and GameState.story.get("route") != "dark"


## 비류의 [함께하자] 메뉴에 붙을 한 줄. 없으면 null
static func menu_option(npc):
	if not unlocked(): return null
	var back := func(): NpcActions.open_hub(npc)
	var ok := [{ label = "…그래.", on_select = back }]
	if GameState.player.stage_index < Story._adult():
		return { label = "🏁 겨루자고 한다", on_select = func(): NpcActions.show(npc, "넌 아직 못 날잖아. 날개가 몸을 들 수 있게 되면 와. 그때 붙자.", ok) }
	if resting():
		return { label = "🏁 겨루자고 한다", on_select = func(): NpcActions.show(npc, "다리가 아직 욱신거려. 며칠만 쉬고 붙자. 폭포는 올랐으니까 됐어.", ok) }
	if GameState.map_id != MAP:
		return { label = "🏁 겨루자고 한다", on_select = func(): NpcActions.show(npc, "오후엔 아랫마을 호수에서 헤엄쳐. 거기서 붙자. 너는 하늘로, 나는 물로.", ok) }
	var lv := level()
	return { label = "🏁 호수 한 바퀴 겨루기 (%s)" % ("비류 %d판째" % (lv + 1) if lv < TIMES.size() else "기록 깨기"), on_select = func(): _offer(npc) }


## 비류가 다리를 다쳐 쉬는 중인가 (폭포를 제 눈으로 오른 대가, b1)
static func resting() -> bool: return int(GameState.story.get("biryuRest", -1)) > GameState.day


## 이긴 판 수 (0~3). 셋을 다 이기면 마지막 판 빠르기로 기록을 깬다
static func level() -> int: return int(_r().get("level", 0))


static func _offer(npc) -> void:
	var start := [{ label = "좋아, 붙자.", on_select = func(): start(npc) }, { label = "다음에.", on_select = func(): NpcActions.open_hub(npc) }]
	if not GameState.story.has("race"):
		NpcActions.show(npc, "좋아, 붙자. 너는 하늘로, 나는 물로. 호수 위에 물안개로 고리를 열 개 띄워 놨어. 차례대로 빠져나가서 첫 고리로 먼저 돌아오면 네가 이긴 거야. 그동안 나는 호수를 세 바퀴 돈다. 내려앉으면 끝이다.", start)
		return
	var lv := level()
	NpcActions.show(npc, "기록 깨러 왔어? 좋지. 이번엔 몇 초 안에 들어오나 보자." if lv >= TIMES.size() else "몸은 풀었어? 이번엔 %.1f초 안에 세 바퀴 돈다." % TIMES[lv], start)


## 출발: 첫 고리 앞에서 날아오른 채 셋을 센다. course · target · on_end(이겼나, 걸린 초)는 모임 겨루기가 넘긴다
static func start(npc, course := {}, target := 0.0, on_end = null) -> void:
	NpcActions.close()
	_r()
	if course.is_empty(): course = lake_course()
	var p = GameState.player
	if not p.flying: p.toggle_flight()
	if not p.flying: return   # 천장이 있다 · 배가 고프다
	var s := Vector2(course.rings[0][0], course.rings[0][1] + 40)
	p.x = s.x; p.y = s.y
	if not GameState.entities.npcs.has(npc):
		npc.remove = false; npc.is_hidden = false
		World.add_entity("npcs", npc)
	npc.walk_to = null
	var lv := mini(level(), TIMES.size() - 1)
	GameState.activity = { type = "RACE", npc = npc, course = course, t = -COUNT, ring = 0, target = target if target > 0 else TIMES[lv],
		level = lv, count = COUNT + 1.0, onEnd = on_end }
	_swim(npc, 0.0, 1.0, course)
	Sfx.play("splash")
	Hud.pop("비류가 물속으로 뛰어들었다! 물안개 고리를 차례로 빠져나가자. [Shift]를 누르고 있으면 더 빨리 난다.", "🏁")


## 비류의 판 (NpcActions._update_activity 가 부른다). 셈 · 고리 · 비류의 헤엄 · 끝
static func update(npc, dt: float) -> void:
	var a: Dictionary = GameState.activity
	var p = GameState.player
	var c: Dictionary = a.course
	a.t += dt
	if a.t < 0:   # 출발 전: 첫 고리 앞에 붙들어 두고 셋을 센다
		p.x = c.rings[0][0]; p.y = c.rings[0][1] + 40
		var n := ceili(-a.t)
		if n < a.count:
			a.count = n
			Vfx.spawn_text(p.x, p.y - 150, str(n), "#ffd84a", 28)
			Sfx.play("pop")
		Hud.current.set_boss_bar("%s · 곧 출발" % c.title, 1.0)
		_swim(npc, 0.0, a.target, c)
		return
	if a.count > 0:
		a.count = 0
		Vfx.spawn_text(p.x, p.y - 150, "출발!", "#ffd84a", 28)
		Sfx.play("dash")
	_swim(npc, a.t, a.target, c)
	Hud.current.set_boss_bar("%s · %.1f초" % [c.title, a.t], 1.0 - a.t / a.target)
	if not p.flying or GameState.map_id != c.map:   # 내려앉았거나 판을 떠났다
		_finish(false, "내려앉으면 끝이지. 다음엔 끝까지 날아.")
		return
	var goal := _goal(int(a.ring), c.rings)
	if Vector2(p.x - goal.x, p.y - goal.y).length() < RING_R:
		a.ring += 1
		Particles.burst(goal.x, goal.y - 60, "#bfe9ff", 0.8, 14)
		Sfx.play("ring")
		if int(a.ring) > c.rings.size():
			_finish(a.t < a.target, "")
			return
	if a.t >= a.target: _finish(false, "내가 먼저다! 하늘이 넓어도 물길이 더 곧은 법이지. 또 붙을래?")


## 다음에 빠져나갈 고리. 열 개를 다 돌면 첫 고리가 결승
static func _goal(i: int, rings: Array = RINGS) -> Vector2:
	var r: Array = rings[i % rings.size()]
	return Vector2(r[0], r[1])


## 비류는 물을 세 바퀴 돈다 (꼭대기에서 시계 방향으로). 바닥에 누운 둘레라 위아래는 납작하게
static func _swim(npc, t: float, target: float, course := {}) -> void:
	var center: Vector2 = course.get("center", LAKE)
	var r: float = course.get("swim_r", SWIM_R)
	var ang := clampf(t / target, 0.0, 1.0) * LAPS * TAU
	var nx := center.x + sin(ang) * r
	var ny := center.y - cos(ang) * r * 0.7
	npc.facing = Dragon.facing_from_vector(nx - npc.x, ny - npc.y, npc.facing)
	npc.moving = t > 0 and t < target
	npc.x = nx; npc.y = ny
	if npc.moving and randf() < 0.3: Particles.burst(nx, ny, "#bfe9ff", 0.4, 2)   # 물살


static func _finish(win: bool, line: String) -> void:
	var a: Dictionary = GameState.activity
	var npc = a.npc
	var p = GameState.player
	GameState.activity = null
	Hud.current.set_boss_bar(null)
	npc.walk_to = null
	npc.home_x = npc.x; npc.home_y = npc.y
	if a.get("onEnd"):   # 모임 겨루기: 결과는 그쪽이 맡는다
		a.onEnd.call(win, float(a.t))
		return
	var r := _r()
	if not win:
		NpcActions.add_relation(npc, 1)
		npc.say(line)
		Hud.pop("비류가 먼저 들어왔다. (%.1f초 안에 들어와야 한다)" % a.target if line.begins_with("내가") else "경주를 그만뒀다.", "🏁")
		return
	var t: float = a.t
	var fresh: bool = r.get("best", 0.0) <= 0.0 or t < float(r.best)
	if fresh: r.best = snappedf(t, 0.1)
	var lv := int(a.level)
	if level() <= lv and level() < TIMES.size():   # 이 판을 처음 이겼다: 비류가 한 판 더 빨라진다
		r.level = lv + 1
		var got := NpcActions.add_relation(npc, 15 if lv == 2 else 10)
		p.gold += [30, 50, 80][lv]
		p.gain_xp([200, 300, 400][lv])
		npc.say(WIN_LINES[lv])
		Hud.pop("비류를 이겼다! %.1f초 (%dG · %s)" % [t, [30, 50, 80][lv], NpcActions.gain_note(got)], "🏆")
	else:
		var first: bool = r.get("winDay", -1) != GameState.day   # 되풀이한 판은 하루 한 번만 조금
		if first:
			NpcActions.add_relation(npc, 2)
			p.gain_xp(50)
		npc.say("또 네가 먼저네. %s" % ("기록을 깼잖아! 다음엔 나도 깬다." if fresh else "…몸 좀 풀고 다시 붙자."))
		Hud.pop("비류를 이겼다! %.1f초%s" % [t, " (새 기록)" if fresh else ""], "🏆")
	r.winDay = GameState.day
	Vfx.spawn_effect("RING", p.x, p.y, { size = 1.4 })


## 일지 [기록]에 남는 줄: 가장 빠른 기록 · 이긴 판
static func record_line() -> Array:
	var r = GameState.story.get("race")
	if r == null: return ["비류와 호수 경주", "아직 안 겨뤘다", true]
	var best := float(r.get("best", 0.0))
	return ["비류와 호수 경주", ("가장 빠른 %.1f초 · " % best if best > 0 else "") + "%d / %d판 이김" % [int(r.get("level", 0)), TIMES.size()]]


## 고리 그리기 (효과 층): 다음 고리는 금빛으로 깜빡이고, 그다음 둘은 흐리게. 떠 있는 고리 밑에는 그림자
static func draw(ci: CanvasItem) -> void:
	var a = GameState.activity
	if a == null or a.get("type") != "RACE": return
	var rings: Array = a.course.rings
	var i := int(a.ring)
	for k in 3:
		if i + k > rings.size(): break
		var g := _goal(i + k, rings)
		var next := k == 0
		var pulse := 0.75 + sin(GameState.game_time * 8.0) * 0.25 if next else 0.35
		var col := Color("#ffd84a") if next else Color("#dff4ff")
		ci.draw_set_transform(Vector2(g.x, g.y), 0, Vector2(1, 0.35))
		ci.draw_circle(Vector2.ZERO, 40, Color(0, 0, 0, 0.18 * pulse))   # 그림자
		ci.draw_set_transform(Vector2(g.x, g.y - 60), 0, Vector2(0.55, 1))
		var rr := 66.0 if next else 58.0
		ci.draw_circle(Vector2.ZERO, rr, Color(1, 1, 1, 0.1 * pulse))   # 물안개
		ci.draw_arc(Vector2.ZERO, rr, 0, TAU, 40, Color(1, 1, 1, 0.55 * pulse), 12 if next else 7)   # 흰 테 (풀밭 위에서도 보이게)
		ci.draw_arc(Vector2.ZERO, rr, 0, TAU, 40, Color(col, 0.95 * pulse), 7 if next else 4)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	# 다음 고리가 어느 쪽인지 내 곁에 작은 화살표
	var p = GameState.player
	if a.t >= 0 and i <= rings.size():
		var g := _goal(i, rings)
		var d := Vector2(g.x - p.x, g.y - p.y)
		if d.length() > 160:
			var dir := d.normalized()
			var c := Vector2(p.x, p.y - 30) + dir * 110
			ci.draw_colored_polygon(PackedVector2Array([c + dir * 16, c + dir.orthogonal() * 9 - dir * 6, c - dir.orthogonal() * 9 - dir * 6]), Color("#ffd84a"))
