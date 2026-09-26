class_name BossShow
## 보스와의 만남과 끝을 '장면'으로 찍는다 (Boss 가 부른다).
##   intro(b)      깨어나는 순간: 소리가 걷히고 카메라가 보스에게 건너간다. 포효와 함께 이름패가 뜨고, 싸움이 시작된다
##   phase(b, ph)  판이 바뀌는 순간: 세상이 아주 잠깐 느려지고, 보스의 한마디가 자막으로 뜬다 (싸움은 멈추지 않는다)
##   finale(b)     쓰러지는 순간: 흰 빛, 세상이 느려지고 음악이 끊긴다. 보스가 빛가루로 흩어진 뒤 이야기 장면으로
##   revive(b)     되살아나는 순간 (모르가스): 세상이 느려지고, 무너진 몸이 다시 맞춰지며 한마디
##   yield_to(b)   싸움을 멈추고 장면으로 (phases 의 yield. 글라시아: 카이론이 그이의 말을 전한다). 장면이 끝나면 잠든다
##   phase_scene(b, i)  판 사이의 장면 (phases 의 scene. 이그나르: 카이론이 내려앉는다). 장면이 끝나면 그 판으로
##   ally_joined(e)     장면에서 불러온 용이 남아 함께 싸운다 ({ stay = "Kairon" })
##   act(what)     장면 속 보스 박자 { boss = "frost" | "rise" | "home" | "wrap" } (Cutscene 이 부른다)
## 보스마다 등장을 따로 짤 수 있다: BOSSES[id].stagedIntro 가 참이면 intro 의 줄(박자 포함)만으로 등장한다.
## 결투장의 서리·도깨비불은 lair_alpha 로 보스의 상태를 따라 번지고 사라진다 (Prop 이 부른다).
## 느려짐은 Engine.time_scale 로 건다 (세상 전체가 느려진다). 되돌리는 시계는 실시간으로 잰다.

const SLOW_FINALE := 0.22     # 쓰러지는 순간의 빠르기
const SLOW_FINALE_SEC := 1.3  # 실시간으로 이만큼
const SLOW_PHASE := 0.4
const SLOW_PHASE_SEC := 0.45
const SAY_SEC := 3.2          # 자막 한 줄이 떠 있는 시간. 여러 줄이면 이 간격으로 잇는다
const FROST_SPEED := 520.0    # 서리가 번지는 빠르기 (px/초)
const THAW_SEC := 4.0         # 보스가 잠든 뒤 서리가 다 녹는 데 걸리는 시간

static var _slow_until := 0


static func _el_color(b) -> String:
	return str(Data.get_module("elements").ELEMENTS[b.def.element].color)


## 세상을 잠깐 느리게. 실시간 sec 초 뒤 제 빠르기로
static func slow(scale: float, sec: float) -> void:
	Engine.time_scale = minf(Engine.time_scale, scale)
	_slow_until = maxi(_slow_until, Time.get_ticks_msec() + int(sec * 1000))
	_arm(sec)


## 시계는 프레임 단위로 재서 조금 일찍 울 수 있다. 남은 시간이 있으면 다시 건다 (더 긴 느려짐이 뒤에 걸린 경우도)
static func _arm(sec: float) -> void:
	(Engine.get_main_loop() as SceneTree).create_timer(sec, true, false, true).timeout.connect(func():
		var left := _slow_until - Time.get_ticks_msec()
		if left > 40: _arm(left / 1000.0)
		else: Engine.time_scale = 1.0)


## 판을 접거나 처음 화면으로 갈 때 (느려진 채로 남지 않게)
static func reset() -> void:
	Engine.time_scale = 1.0
	_slow_until = 0


## 깨어나는 순간. 이그나르처럼 먼저 말을 거는 보스는 그 장면이 대신한다 (ev_ignar_meet)
static func intro(b) -> void:
	if b.def.get("stagedIntro"):
		# 보스마다 짠 등장: 카메라·소리·이름패까지 data/enemies BOSSES[id].intro 에 박자로 적혀 있다
		Chronicle.play_scene("", b.def.intro.duplicate(true), func():
			b.finish_rise()   # 장면을 건너뛰어도 몸은 다 일어선 채로 싸운다
			Hud.pop("%s — 싸움이 시작된다" % b.def.name, "⚔️"))
		return
	var col := _el_color(b)
	var lines := [{ do = [
		{ bgm = "none" },
		{ cam = b, zoom = 1.08, time = 0.9 },
		{ wait = 0.25 },
		{ cry = b.id }, { shake = 14 }, { flash = col, a = 0.35 },
		{ fx = "SHOCKWAVE", at = b, size = 3.4, color = col },
		{ card = b.def.name, sub = b.def.title, time = 2.0 },
		{ bgm = "boss" },
	] }]
	# 보스마다 한마디가 있으면 (data/enemies BOSSES[id].intro)
	for l in b.def.get("intro", []): lines.append(l)
	Chronicle.play_scene("", lines, func(): Hud.pop("%s — 싸움이 시작된다" % b.def.name, "⚔️"))


## 판이 바뀌는 순간
static func phase(b, ph: Dictionary) -> void:
	slow(SLOW_PHASE, SLOW_PHASE_SEC)
	if ph.get("say"): say(b, ph.say)
	else: Cutscene.say_over("", "— %s —" % ph.name, 2.2)


## 싸우는 중에 보스가 하는 말. 여러 줄이면 SAY_SEC 간격으로 잇는다 (그 사이 쓰러지거나 떠나면 거기서 그친다)
static func say(b, lines) -> void:
	var who: String = b.def.name.split(" ")[-1]
	var list: Array = lines if lines is Array else [lines]
	var wb: WeakRef = weakref(b)   # 두 번째 줄이 뜨기 전에 결투장을 떠나면 보스는 이미 사라지고 없다 (붙잡고 있으면 엔진이 오류를 찍는다)
	for i in list.size():
		var text: String = list[i]
		var by := "" if text.begins_with("(") else who   # "(모래가 끓는다.)" 같은 서술에는 이름을 붙이지 않는다
		if i == 0:
			Cutscene.say_over(by, text, SAY_SEC + 0.2)
			continue
		(Engine.get_main_loop() as SceneTree).create_timer(SAY_SEC * i, true, false, true).timeout.connect(func():
			var bb = wb.get_ref()
			if bb and bb.awake and bb.dying <= 0 and not bb.remove: Cutscene.say_over(by, text, SAY_SEC + 0.2))


## 되살아나는 순간 (BOSSES[id].revive). 무너진 몸이 다시 맞춰지는 동안은 맞지도 때리지도 않는다
static func revive(b) -> void:
	slow(SLOW_PHASE, 0.7)
	GameCamera.current.shake(12)
	Sfx.play("thud")
	BossVoice.cry(b.id, "revive")
	Vfx.spawn_effect("MAGIC_CIRCLE", b.x, b.y, { size = 3, color = _el_color(b) })
	if b.def.get("reviveSay"): say(b, b.def.reviveSay)
	if b.def.get("rise"): b.collapse()


## 싸움을 멈추고 장면으로 넘어간다. 날아오던 탄과 장판을 걷고, 장면(BOSSES[id].yieldScene)이 끝나면 잠든다 (쓰러짐과 같은 보상·이야기)
static func yield_to(b) -> void:
	b.yielding = true
	b.charge = null; b.spiral = null; b.beam = null; b.burrow = null; b.blizzard = null; b.tell = null
	for x in GameState.entities.bullets:
		if x.faction == "ENEMY": x.remove = true
	for h in GameState.entities.hazards:
		if h.get("faction") == "ENEMY": h.remove = true
	Hud.current.set_boss_bar(null)
	Chronicle.play_scene("", b.def.yieldScene.duplicate(true), func(): b.die())


## 판 사이의 장면. 그동안은 싸움이 멈추고, 장면이 끝나면 그 판을 시작한다
static func phase_scene(b, i: int) -> void:
	b.yielding = true
	b.charge = null; b.spiral = null; b.beam = null; b.burrow = null; b.blizzard = null; b.tell = null
	for x in GameState.entities.bullets:
		if x.faction == "ENEMY": x.remove = true
	for h in GameState.entities.hazards:
		if h.get("faction") == "ENEMY": h.remove = true
	Chronicle.play_scene("", b.def.phases[i].scene.duplicate(true), func():
		if not is_instance_valid(b) or b.dying > 0 or b.remove: return
		b.yielding = false
		b.start_phase(i))


## 장면에서 불러온 용이 남아 함께 싸운다. 나를 따라다니며 곁의 적을 친다 (일과가 문 밖으로 데려가지 않게 WANDER 가 아닌 상태로).
## 보스가 결투장을 떠날 때(Boss._exit_tree) 되돌린다
static func ally_joined(e) -> void:
	var b = here()
	if b == null: return
	b.ally = e
	b._ally_home = Vector2(e.home_x, e.home_y)
	b._ally_state = e.state if e.state != "ALLY" else "WANDER"   # 짝으로 따라다니던 용이면 떠날 때 되돌려 준다
	e.home_x = e.x; e.home_y = e.y
	e.walk_to = null
	e.state = "ALLY"
	e.passive = false


## 쓰러지는 순간. 보스는 dying 동안 빛가루로 흩어지고, 다 흩어지면 Boss 가 보상과 이야기를 연다
static func finale(b) -> void:
	slow(SLOW_FINALE, SLOW_FINALE_SEC)
	Feedback.flash(0.95, Color(b.def.get("finaleFlash", "#fff6e0")))   # 모르가스는 서리 빛으로
	Feedback.hit_stop(0.18)
	GameCamera.current.shake(20)
	Cutscene.music = "none"          # 음악을 걷는다. 이야기 장면이 다음 곡을 고른다
	Sfx.play("dieBig")
	Sfx.play("stinger")
	var id: String = b.id   # 0.35초 뒤에는 보스가 이미 치워졌을 수 있다 (걷는 봇이 쓰러뜨리자마자 지도를 떠나자 오류가 났다)
	(Engine.get_main_loop() as SceneTree).create_timer(0.35, true, false, true).timeout.connect(func(): BossVoice.cry(id, "fall"))   # 쿵 소리가 가라앉은 뒤에
	var fallen: String = b.def.get("fallen", "쓰러뜨렸다")
	Cutscene.show_card(b.def.name, fallen, 2.6)
	(Engine.get_main_loop() as SceneTree).create_timer(3.2, true, false, true).timeout.connect(func():
		if not Cutscene.on and Cutscene.music == "none": Cutscene.music = "")


## 이 지도에서 싸우는 보스 (없으면 null)
static func here():
	for b in GameState.entities.bosses:
		if is_instance_valid(b) and not b.remove: return b
	return null


## 장면 속 보스 박자. { wait: 기다릴 초, rush: 건너뛸 때 부를 것 } 을 돌려준다
static func act(what: String) -> Dictionary:
	var b = here()
	if b == null: return {}
	match what:
		"frost":   # 무덤에서부터 서리가 번진다 (결투장의 FROST 가 lair_alpha 로 따라 짙어진다)
			b.frost_at = GameState.game_time
			Sfx.play("freeze")
			return { wait = 0.9 }
		"rise":    # 흩어져 있던 뼈가 맞춰지며 일어선다
			b.start_rise()
			return { wait = Boss.RISE_TIME, rush = func(): b.finish_rise() }
		"home":    # 제자리로 (장면이 까맣게 덮인 사이에. 어디서 싸우다 멈춰도 같은 구도로)
			b.x = b.home.x; b.y = b.home.y
			b.facing = "down"
			return {}
		"wrap":    # 지키던 것 앞으로 가서 등을 돌리고 몸을 만다 (글라시아)
			var g = b._guard()
			if g == null: return {}
			b.wrap_to = g + Vector2(0, 150)
			return { wait = 1.6, rush = func():
				if b.wrap_to != null:
					b.x = b.wrap_to.x; b.y = b.wrap_to.y
					b.wrap_to = null
					b.facing = "up" }
	push_warning("모르는 보스 박자: %s" % what)
	return {}


## 이 결투장의 보스 id (지도에 놓인 BOSS). 없으면 ""
static func lair_boss_id() -> String:
	for f in World.maps().get(GameState.map_id, {}).get("fixtures", []):
		if f.t == "BOSS": return f.id
	return ""


## 결투장의 서리·도깨비불이 얼마나 짙은가 (0~1). 보스를 보내기 전에는 늘 있고, 보낸 뒤에는 녹아 사라진다.
##   base: 보스가 잠들어 있을 때의 짙기. spread: 참이면 보스가 깨어날 때 무덤에서부터 번져 짙어진다
static func lair_alpha(px: float, py: float, base: float, spread := false) -> float:
	var b = here()
	if b == null: return 0.0 if GameState.bossesDefeated.get(lair_boss_id(), false) else base
	var now := GameState.game_time
	if b.thaw_at >= 0: return clampf(1.0 - (now - b.thaw_at) / THAW_SEC, 0.0, 1.0) * (1.0 if spread else base)
	if not spread or b.frost_at < 0: return base
	var reach: float = (now - b.frost_at) * FROST_SPEED
	return clampf(base + (reach - Vector2(px - b.home.x, py - b.home.y).length()) / 180.0, base, 1.0)
