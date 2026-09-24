class_name Sneak
## 해 질 녘 폭포: 몰래 다가가기 — "무궁화 꽃이 피었습니다" (설정집 5-0).
##
## 달맞이 모임 다음 날 아침, 포코가 귓속말을 하면(하루와 사귀는 중이면 하루가 몰래 내려와 부르면) s1 이 걸린다.
## 해 질 녘 폭포에 가면 사건(ev_tryst_dusk · ev_tryst_mine_dusk)이 판을 연다 (flag tryst_start).
##
##  · 보는 이는 이야기하다가(calm) 돌아볼 참이 되면 머리 위에 '?'를 띄우고(warn) 잠깐 돌아본다(look)
##  · 돌아볼 때: 멀리서는 움직이면 들키고(멈추면 산다), 가까이서는 바위 그늘 밖이면 멈춰 있어도 들킨다
##  · 코앞까지 걸어 들어가면 언제든 들킨다. 달리기·대시·브레스는 소리가 나서 곧바로 돌아본다
##  · 몸을 낮추고 살금살금 걷는 판이라 걸음이 느리다
##  · 엿들을 자리에 닿으면 성공. 사건 ev_tryst(하루 판은 ev_tryst_mine)를 곧바로 열고, 끝나면 flag tryst_done 으로 돌아온다
##  · 들키면 우스운 장면을 보고 호숫가로 쫓겨난다. 다음 날 해 질 녘에 다시 (들킬수록 쉬워진다)
##
## 판 하나는 SneakView 노드가 들고 있다. main 을 고치지 않고 매 프레임 돌 자리가 필요해서 붙인 노드이고,
## 판이 끝나면 치운다 (처음 화면으로 나가면 main 과 함께 사라진다).
## 오래 남기는 것은 GameState.story.tryst = { day: 마지막으로 해 본 날, fails: 들킨 횟수 } 뿐이다.
## 판이 도는 동안 GameState.activity = { type = "SNEAK" } — 말 걸기·날기·석비·포탈·다른 사건이 멈춘다.
## 자리(시작·엿들을 자리·보는 이·순찰 길)는 data/maps.json 의 FALLS.sneak (큰 칸 좌표, 소수 가능).

const MAP := "FALLS"
const VIEW := "res://scenes/sneak/sneak_view.tscn"
const NEAR := 380.0        # 이 안에서는 멈춰 있어도 보인다. 그 밖에서는 움직여야 보인다
const REACH := 900.0       # 시선이 닿는 거리
const HALF := 0.7          # 돌아볼 때 시선 부채꼴의 반각 (라디안, 약 40도)
const CLOSE := 140.0       # 코앞: 언제든 들킨다
const NOISE := 450.0       # 이 안에서 소리를 내면 곧바로 돌아본다
const LOUD := 330.0        # 이보다 빠르면 발소리가 난다 (걷기 ≈ 270 · 달리기 ≈ 410 · 대시 ≈ 900 px/초)
const STILL := 30.0        # 이보다 느리면 멈춘 셈
const CREEP := 0.55        # 살금살금: 걸음을 이만큼으로 줄인다
const LISTEN := 55.0       # 엿들을 자리의 반지름
const TURN := 0.25         # 돌아서는 동안은 아직 못 본다
const PATROL := 95.0       # 순찰 걸음 (px/초)
const HUSH := 480.0        # 이보다 멀면 말소리가 소곤소곤으로만 들린다
# 가리개: 이 소품들 뒤는 그늘이다 (반지름 px)
const COVER := { "ROCK": 40.0, "STUMP": 30.0, "TREE": 40.0, "TEMPLE": 38.0, "RUIN": 38.0, "STONE_WALL": 36.0, "WAYSTONE": 26.0 }
# 들킬수록 쉬워진다 (들킨 횟수 0 · 1 · 2 이상)
const TUNE := [
	{ calm = [1.1, 2.8], warn = 1.0, look = [1.5, 2.1], grace = 0.3 },
	{ calm = [1.4, 3.0], warn = 1.3, look = [1.3, 1.8], grace = 0.45 },
	{ calm = [1.8, 3.2], warn = 1.6, look = [1.1, 1.5], grace = 0.6 },
]
const TINT := { "Mira": Color("#ffb4d4"), "Yuan": Color("#9fd2ff") }

static var _view = null   # 지금 판 (SneakView). 판이 없으면 null


static func _state() -> Dictionary:
	if not GameState.story.has("tryst"): GameState.story.tryst = { day = -1, fails = 0 }
	return GameState.story.tryst


static func running() -> bool:
	return _view != null and is_instance_valid(_view)


## 이번 판: 하루가 불렀으면 내 밀회('mine'), 아니면 미라·유안('mira')
static func variant() -> String:
	return "mine" if GameState.story.get("events", []).has("ev_tryst_invite") else "mira"


## Story.on_flag 가 부른다
static func on_flag(flag: String) -> void:
	match flag:
		"tryst_start": start()
		"tryst_done": finish()


# ---------- 판을 열고 닫기 ----------

static func start() -> void:
	if running() or GameState.map_id != MAP: return
	var v := variant()
	var ev := _event("ev_tryst_mine_dusk" if v == "mine" else "ev_tryst_dusk")
	if ev.is_empty(): return
	_state().day = GameState.day
	# 판을 연 사건은 방아쇠일 뿐이라 본 사건으로 남기지 않는다. 그래야 들킨 다음 날 다시 열린다
	for id in ["ev_tryst_dusk", "ev_tryst_mine_dusk"]: GameState.story.events.erase(id)
	GameState.activity = { type = "SNEAK" }
	var view: SneakView = load(VIEW).instantiate()
	view.run = { variant = v, ev = ev, phase = "setup" }
	_view = view
	# 땅에 깔리는 그림이라 개체(World)보다 먼저 그린다
	var main := World.container.get_parent()
	main.add_child(view)
	main.move_child(view, World.container.get_index())
	Hud.fade_screen("", func(): _set_stage(view), func(): _brief(view), true)


static func _event(id: String) -> Dictionary:
	for e in Data.get_module("chronicle").CHRONICLE:
		if e.id == id: return e
	return {}


## 막이 덮인 사이에 자리를 잡는다: 나는 시작 자리, 보는 이는 제자리, 따라오던 짝·동료는 석비 곁
static func _set_stage(view: SneakView) -> void:
	if not is_instance_valid(view): return
	var r: Dictionary = view.run
	var s: Dictionary = Data.get_module("maps").MAPS[MAP].sneak
	r.start = World.at(s.start)
	r.listen = World.at(s.listen)
	r.last = r.start
	r.held = []
	r.watchers = []
	r.followers = []
	r.cover = []
	for pr in GameState.entities.props:
		if COVER.has(pr.type): r.cover.append({ pos = Vector2(pr.x, pr.y), r = COVER[pr.type] })
	var p = GameState.player
	p.fishing = null
	p.x = r.start.x; p.y = r.start.y
	p.facing = "right"
	if p.flying: p.land()
	if r.variant == "mira":
		var mira = _bring("Mira", World.at(s.mira))
		var yuan = _bring("Yuan", World.at(s.yuan))
		_hold(r, mira, "right")
		_hold(r, yuan, "left")
		r.watchers = [_watcher(mira, "right"), _watcher(yuan, "left")]
	else:
		var path: Array = s.patrol.map(func(c): return World.at(c))
		var yuan = _bring("Yuan", path[0])
		var mira = _bring("Mira", World.at(s.miraWait))
		var haru = _bring("Haru", r.start + Vector2(-60, 30))
		_hold(r, yuan, "right")
		var hm := _hold(r, mira, "down")
		hm.hidden = true    # 물안개 속에서 기다린다. 끝 장면에서 나온다
		mira.is_hidden = true
		# 하루는 내 곁에 붙어 따라온다 (따라오기 상태로 두면 일과가 데려가지 않는다)
		r.followers.append({ e = haru, state = haru.state })
		haru.state = "SNEAK_FOLLOW"
		haru.chat_timer = 999.0
		var w := _watcher(yuan, "right")
		w.patrol = path
		w.leg = 1
		r.watchers = [w]
	# 따라오던 짝·동료는 석비 곁에서 기다린다 (같이 몰래 다가갈 수는 없다)
	var wait := World.at(s.wait)
	for n in [GameState.partner, GameState.companion]:
		if n == null or n.state == "WANDER" or _in_run(r, n): continue
		n.x = wait.x; n.y = wait.y
		wait.x += 70
		_hold(r, n, "down")


## 판에 세울 용. 이 지도에 없으면 불러온다
static func _bring(nm: String, at: Vector2):
	var e = World.any_npc(nm)
	if e == null: return null
	if not GameState.entities.npcs.has(e): World.add_entity("npcs", e)
	e.remove = false
	e.is_hidden = false
	e.stage_alpha = 1.0
	e.down_timer = 0.0
	e.walk_to = null
	e.x = at.x; e.y = at.y
	return e


static func _in_run(r: Dictionary, e) -> bool:
	for h in r.held:
		if h.e == e: return true
	for f in r.followers:
		if f.e == e: return true
	return false


## 제자리에 붙잡아 둘 용 (_keep 이 매 프레임 묶는다)
static func _hold(r: Dictionary, e, face: String) -> Dictionary:
	var h := { e = e, face = face, hidden = false, patrol_to = null }
	e.facing = face
	e.chat_timer = 999.0   # 혼잣말 금지
	r.held.append(h)
	return h


static func _held_of(r: Dictionary, e):
	for h in r.held:
		if h.e == e: return h
	return null


static func _watcher(e, face: String) -> Dictionary:
	var nm: String = e.config.name
	return { e = e, name = nm, face = face, phase = "calm", t = 0.0, aim = 0.0, turn = 0.0, tint = TINT.get(nm, Color.WHITE), patrol = [], leg = 0 }


## 막이 걷히면 짧은 장면으로 판을 보여 주고(처음), 다음부터는 한 줄로
static func _brief(view: SneakView) -> void:
	if not is_instance_valid(view): return
	var r: Dictionary = view.run
	var lines: Array = r.ev.get("brief", []) if int(_state().fails) == 0 else r.ev.get("again", [])
	Chronicle.play_scene("", lines, func(): _begin(view))


static func _begin(view: SneakView) -> void:
	if not is_instance_valid(view): return
	var r: Dictionary = view.run
	r.phase = "play"
	r.calm = 1.0          # 첫 '?' 까지. 곧장 걸어가기만 해서는 닿기 전에 한 번은 돌아보게
	r.murmur = 0.8
	r.exposed = 0.0
	r.progress = 0.0
	r.last = Vector2(GameState.player.x, GameState.player.y)
	var who := "둘이" if r.variant == "mira" else "유안이"
	Hud.pop("%s 돌아보기 직전 머리 위에 '?'가 뜹니다. 멀리서는 멈추면 되고, 가까이서는 바위 뒤에 숨어야 합니다." % who, "👀")
	Hud.pop(("빛나는 자리까지 가면 엿들을 수 있습니다." if r.variant == "mira" else "폭포 옆 빛나는 자리까지 가면 됩니다.") + " 뛰거나 브레스를 쏘면 소리에 들킵니다.", "🤫")


## 성공 장면(ev_tryst · ev_tryst_mine)이 끝나면 (flag tryst_done)
static func finish() -> void:
	if running(): _end(_view)
	Quests.notify("event", "tryst_seen")   # s1 첫 대목


## 붙잡았던 용들을 놓아 주고 판을 치운다
static func _end(view: SneakView) -> void:
	var r: Dictionary = view.run
	r.phase = "gone"   # 치우는 프레임에 박자가 한 번 더 돌아 다시 붙잡지 않게
	for h in r.get("held", []):
		if not is_instance_valid(h.e): continue
		h.e.walk_to = null
		if h.hidden: h.e.is_hidden = false
		h.e.chat_timer = randf_range(20.0, 60.0)
	for f in r.get("followers", []):
		if not is_instance_valid(f.e): continue
		f.e.state = f.state
		f.e.chat_timer = randf_range(20.0, 60.0)
	var p = GameState.player
	if p: p.modulate = Color(1, 1, 1, p.modulate.a)
	if GameState.activity is Dictionary and GameState.activity.get("type") == "SNEAK": GameState.activity = null
	if Hud.current: Hud.current.set_boss_bar(null)
	if _view == view: _view = null
	view.queue_free()


# ---------- 매 프레임 (SneakView 가 부른다) ----------

static func tick(view: SneakView, dt: float) -> void:
	var r: Dictionary = view.run
	if r.phase == "setup" or r.phase == "gone": return
	if GameState.map_id != MAP:   # 어떤 길로든 폭포를 벗어났으면 판을 접는다 (내일 다시)
		_end(view)
		return
	if GameState.isDialogueOpen or Cutscene.on or Hud.fading(): return
	_keep(r)
	match r.phase:
		"play": _play(view, dt)
		"caught":
			_freeze(r)
			r.t -= dt
			if r.t <= 0: _scold(view)


## 붙잡아 둔 용들: 일과 걸음을 제자리에 묶는다. 일과가 한 칸 옮기려 해도 매 프레임 여기서 덮어쓴다
## (routines.json · routine.gd 를 고치지 않고 세워 두는 방법. 판이 끝나면 walk_to 를 비워 놓아 준다)
static func _keep(r: Dictionary) -> void:
	for h in r.held:
		var e = h.e
		if not is_instance_valid(e): continue
		if h.patrol_to != null:
			e.walk_to = { x = h.patrol_to.x, y = h.patrol_to.y, speed = PATROL }
		else:
			e.walk_to = { x = e.x, y = e.y }
			e.facing = h.face
		if h.hidden: e.is_hidden = true
		e.chat_timer = maxf(e.chat_timer, 5.0)


static func _freeze(r: Dictionary) -> void:
	var p = GameState.player
	p.x = r.freeze.x; p.y = r.freeze.y
	p.moving = false


static func _play(view: SneakView, dt: float) -> void:
	var r: Dictionary = view.run
	var p = GameState.player
	var raw := Vector2(p.x, p.y)
	var loud: bool = raw.distance_to(r.last) / maxf(dt, 0.001) > LOUD or _breathed(p, dt)
	# 살금살금: 몸을 낮추고 걸어서 걸음이 줄어든다
	var me: Vector2 = r.last + (raw - r.last) * CREEP
	p.x = me.x; p.y = me.y
	var speed: float = me.distance_to(r.last) / maxf(dt, 0.001)
	r.last = me
	var tune: Dictionary = TUNE[mini(int(_state().fails), TUNE.size() - 1)]
	if loud: _noise(r, me, tune)
	_director(r, me, tune, dt)
	var seen_by = null
	for w in r.watchers:
		_step(r, w, tune, dt)
		if _spots(r, w, me, speed): seen_by = w
	r.exposed = r.exposed + dt if seen_by else 0.0
	if seen_by and r.exposed >= tune.grace:
		_caught(view, seen_by)
		return
	_murmur(r, me, dt)
	_shade(r, p, me)
	r.progress = clampf(1.0 - me.distance_to(r.listen) / maxf(1.0, r.start.distance_to(r.listen)), 0.0, 1.0)
	Hud.current.set_boss_bar(_status(r), r.progress)
	if me.distance_to(r.listen) < LISTEN and seen_by == null: _heard(view)


## 이 보는 이가 지금 나를 보는가
static func _spots(r: Dictionary, w: Dictionary, me: Vector2, speed: float) -> bool:
	var o := Vector2(w.e.x, w.e.y)
	var d := o.distance_to(me)
	if covered(r, o, me): return false
	if d < CLOSE: return true                        # 코앞에서는 언제든
	if w.phase != "look" or w.turn > 0: return false
	if d > REACH or absf(angle_difference(w.aim, (me - o).angle())) > HALF: return false
	return d < NEAR or speed > STILL                 # 멀리서는 움직일 때만


## o 에서 p 를 보는 눈길을 가리개가 막는가 (시선 부채꼴 그림과 같은 셈을 쓴다)
static func covered(r: Dictionary, o: Vector2, p: Vector2) -> bool:
	var v := p - o
	var l := v.length()
	if l < 1.0: return false
	var dir := v / l
	for c in r.cover:
		var hit := _hit(o, dir, c)
		if hit > 0.0 and hit < l: return true
	return false


## o 에서 dir 로 뻗은 눈길이 가리개 c 에 처음 닿는 거리 (안 닿으면 -1)
static func _hit(o: Vector2, dir: Vector2, c: Dictionary) -> float:
	var f: Vector2 = c.pos - o
	var t := f.dot(dir)
	if t <= 0.0: return -1.0
	var h2 := f.length_squared() - t * t
	var rr: float = c.r * c.r
	if h2 >= rr: return -1.0
	return t - sqrt(rr - h2)


## 시선 부채꼴 (그림용). 가리개에 닿으면 거기서 끊겨 그 뒤가 그늘로 빈다
static func fan(r: Dictionary, o: Vector2, aim: float, reach: float) -> PackedVector2Array:
	var pts := PackedVector2Array([o])
	var n := 40
	for i in n + 1:
		var a := aim - HALF + 2.0 * HALF * i / n
		var dir := Vector2(cos(a), sin(a))
		var best := reach
		for c in r.cover:
			var hit := _hit(o, dir, c)
			if hit > 0.0 and hit < best: best = hit
		pts.append(o + dir * best)
	return pts


## 모두 이야기하는 중이면 박자를 센다. 때가 되면 한 사람이 돌아볼 참이 된다
static func _director(r: Dictionary, me: Vector2, tune: Dictionary, dt: float) -> void:
	for w in r.watchers:
		if w.phase != "calm": return
	r.calm -= dt
	if r.calm > 0: return
	_warn(r, _pick(r), me, tune.warn)


## 다음에 돌아볼 이. 유안이 조금 더 자주 보되, 한 사람이 세 번 내리 돌아보지는 않는다
static func _pick(r: Dictionary) -> Dictionary:
	var ws: Array = r.watchers
	var w: Dictionary = ws[0]
	if ws.size() > 1:
		w = ws[1] if randf() < 0.6 else ws[0]
		if r.get("lastPick") == w.name and int(r.get("streak", 0)) >= 2: w = ws[0] if w.name == ws[1].name else ws[1]
	r.streak = int(r.get("streak", 0)) + 1 if r.get("lastPick") == w.name else 1
	r.lastPick = w.name
	return w


static func _warn(r: Dictionary, w: Dictionary, me: Vector2, t: float) -> void:
	w.phase = "warn"
	w.t = t
	w.aim = (me - Vector2(w.e.x, w.e.y)).angle() + randf_range(-0.12, 0.12)
	var h = _held_of(r, w.e)
	if h: h.patrol_to = null   # 순찰하던 걸음을 멈춘다
	w.e.current_chat = null    # 말풍선이 '?' 를 가리지 않게
	w.e.chat_fade = 0.0
	w.e.emote("?")
	Sfx.play("pop")
	if r.variant == "mine": _say(r, _haru(r), "hide")


## 보는 이 한 사람의 박자: 돌아볼 참(warn) → 돌아봄(look) → 다시 이야기(calm). 순찰하는 이는 calm 동안 걷는다
static func _step(r: Dictionary, w: Dictionary, tune: Dictionary, dt: float) -> void:
	var h = _held_of(r, w.e)
	match w.phase:
		"warn":
			w.t -= dt
			if w.t <= 0:
				w.phase = "look"
				w.t = randf_range(tune.look[0], tune.look[1])
				w.turn = TURN
				if h: h.face = Dragon.facing_from_vector(cos(w.aim), sin(w.aim))
		"look":
			w.t -= dt
			w.turn -= dt
			if w.t <= 0:
				w.phase = "calm"
				if h: h.face = w.face
				r.calm = randf_range(tune.calm[0], tune.calm[1])
				if r.variant == "mine" and randf() < 0.5: _say(r, _haru(r), "go")
		"calm":
			if h and not w.patrol.is_empty():
				var to: Vector2 = w.patrol[w.leg]
				if Vector2(w.e.x, w.e.y).distance_to(to) < 60:
					w.leg = (w.leg + 1) % w.patrol.size()
					to = w.patrol[w.leg]
				h.patrol_to = to
				w.face = Dragon.facing_from_vector(to.x - w.e.x, to.y - w.e.y)


## 소리를 냈다: 가장 가까운 이가 곧바로 돌아볼 참이 된다 (이미 누가 돌아보는 중이면 그대로)
static func _noise(r: Dictionary, me: Vector2, tune: Dictionary) -> void:
	var best = null
	var bd := NOISE
	for w in r.watchers:
		if w.phase != "calm": return
		var d := me.distance_to(Vector2(w.e.x, w.e.y))
		if d < bd:
			best = w
			bd = d
	if best: _warn(r, best, me, minf(0.45, tune.warn))


## 방금 불을 뿜었나 (브레스 · 융합 브레스)
static func _breathed(p, dt: float) -> bool:
	if p.beam: return true
	for b in GameState.entities.bullets:
		if b.from_player and b.t <= dt + 0.02: return true
	return false


## 가까워질수록 말소리가 또렷해진다 (하루 판: 순찰하는 유안의 혼잣말)
static func _murmur(r: Dictionary, me: Vector2, dt: float) -> void:
	r.murmur -= dt
	if r.murmur > 0: return
	if r.variant == "mine":
		r.murmur = randf_range(4.0, 6.0)
		if r.watchers[0].phase == "calm": _say(r, r.watchers[0].e, "Yuan")
		return
	for w in r.watchers:
		if w.phase != "calm":
			r.murmur = 0.6
			return
	r.murmur = randf_range(2.2, 3.0)
	var i := int(r.get("talker", 0))
	r.talker = i + 1
	var w: Dictionary = r.watchers[i % r.watchers.size()]
	var nearest := INF
	for x in r.watchers: nearest = minf(nearest, me.distance_to(Vector2(x.e.x, x.e.y)))
	_say(r, w.e, "far" if nearest > HUSH else w.name)


## murmur 표의 한 묶음에서 차례대로 한 줄 (같은 조각이 되풀이되지 않게 앞에서부터)
static func _say(r: Dictionary, e, key: String) -> void:
	var list: Array = r.ev.get("murmur", {}).get(key, [])
	if list.is_empty() or e == null or not is_instance_valid(e): return
	if not r.has("said"): r.said = {}
	var i := int(r.said.get(key, 0))
	r.said[key] = i + 1
	e.say(list[i % list.size()])
	e.chat_fade = 1.8   # 짧게 (말풍선이 '?' 를 오래 가리지 않게)


static func _haru(r: Dictionary):
	return r.followers[0].e if not r.followers.is_empty() else null


## 모든 보는 이에게서 가려진 자리면 몸이 어둑해진다 (숨었다는 표시)
static func _shade(r: Dictionary, p, me: Vector2) -> void:
	var hid: bool = not r.watchers.is_empty()
	for w in r.watchers:
		if not covered(r, Vector2(w.e.x, w.e.y), me): hid = false
	var c := Color(0.72, 0.76, 0.9) if hid else Color.WHITE
	p.modulate = Color(c.r, c.g, c.b, p.modulate.a)


## 화면 위 막대의 글
static func _status(r: Dictionary) -> String:
	for w in r.watchers:
		var who := Util.josa(Names.npc(w.name), "이", "가")
		if w.phase == "warn": return "몰래 다가가기 · %s 돌아보려 한다" % who
		if w.phase == "look": return "몰래 다가가기 · %s 보고 있다!" % who
	return "몰래 다가가기 · " + ("둘이 이야기하는 중" if r.variant == "mira" else "유안이 순찰하는 중")


# ---------- 들켰을 때 · 엿들었을 때 ----------

static func _caught(view: SneakView, w: Dictionary) -> void:
	var r: Dictionary = view.run
	var p = GameState.player
	r.phase = "caught"
	r.t = 0.8
	r.freeze = Vector2(p.x, p.y)
	var h = _held_of(r, w.e)
	if h:
		h.patrol_to = null
		h.face = Dragon.facing_from_vector(p.x - w.e.x, p.y - w.e.y)
	w.e.emote("!")
	Sfx.play("warn")
	p.modulate = Color(1, 1, 1, p.modulate.a)
	Hud.current.set_boss_bar("몰래 다가가기 · 들켰다!", r.progress)


## 들킨 뒤의 우스운 장면. 들킨 횟수에 따라 다르다
static func _scold(view: SneakView) -> void:
	var r: Dictionary = view.run
	r.phase = "scold"
	var scenes: Array = r.ev.get("caught", [])
	var lines: Array = scenes[mini(int(_state().fails), scenes.size() - 1)] if not scenes.is_empty() else []
	Chronicle.play_scene("", lines, func(): _after_caught(view))


## 쫓기듯 폭포를 내려와 호숫가에 선다. 내일 해 질 녘에 다시
static func _after_caught(view: SneakView) -> void:
	if not is_instance_valid(view): return
	var r: Dictionary = view.run
	r.phase = "gone"
	var t := _state()
	t.fails = int(t.fails) + 1
	if r.variant == "mira":   # 물안개 속으로 달아난 유안은 막이 덮일 때까지 숨겨 둔다
		for h in r.held:
			if h.e.config.get("name") == "Yuan":
				h.hidden = true
				h.e.is_hidden = true
	Hud.current.set_boss_bar(null)
	Hud.fade_screen("", func():
		_end(view)
		World.travel_to("LAKE", "N"), func(): Save.save_game())


## 엿들을 자리에 닿았다: 성공 장면(ev_tryst · ev_tryst_mine)을 곧바로 연다. 장면이 끝나면 flag tryst_done 으로 돌아온다
static func _heard(view: SneakView) -> void:
	var r: Dictionary = view.run
	var p = GameState.player
	r.phase = "heard"
	p.modulate = Color(1, 1, 1, p.modulate.a)
	for w in r.watchers:
		w.phase = "calm"
		var h = _held_of(r, w.e)
		if h:
			h.patrol_to = null
			h.face = w.face
	_keep(r)   # 장면이 열리기 전에 제자리·얼굴을 한 번 더 맞춘다
	Hud.current.set_boss_bar(null)
	# 사건 조건을 기다리지 않고 바로 연다 (판이 도는 동안은 사건 시계가 멈춰 있다)
	Chronicle._fire(_event("ev_tryst_mine" if r.variant == "mine" else "ev_tryst"))
