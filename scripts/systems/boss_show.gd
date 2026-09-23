class_name BossShow
## 보스와의 만남과 끝을 '장면'으로 찍는다 (Boss 가 부른다).
##   intro(b)      깨어나는 순간: 소리가 걷히고 카메라가 보스에게 건너간다. 포효와 함께 이름패가 뜨고, 싸움이 시작된다
##   phase(b, ph)  판이 바뀌는 순간: 세상이 아주 잠깐 느려지고, 보스의 한마디가 자막으로 뜬다 (싸움은 멈추지 않는다)
##   finale(b)     쓰러지는 순간: 흰 빛, 세상이 느려지고 음악이 끊긴다. 보스가 빛가루로 흩어진 뒤 이야기 장면으로
## 느려짐은 Engine.time_scale 로 건다 (세상 전체가 느려진다). 되돌리는 시계는 실시간으로 잰다.

const SLOW_FINALE := 0.22     # 쓰러지는 순간의 빠르기
const SLOW_FINALE_SEC := 1.3  # 실시간으로 이만큼
const SLOW_PHASE := 0.4
const SLOW_PHASE_SEC := 0.45

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
	var col := _el_color(b)
	var lines := [{ do = [
		{ bgm = "none" },
		{ cam = b, zoom = 1.08, time = 0.9 },
		{ wait = 0.25 },
		{ sfx = "roar" }, { shake = 14 }, { flash = col, a = 0.35 },
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
	if ph.get("say"): Cutscene.say_over(b.def.name.split(" ")[-1], ph.say, 3.4)
	else: Cutscene.say_over("", "— %s —" % ph.name, 2.2)


## 쓰러지는 순간. 보스는 dying 동안 빛가루로 흩어지고, 다 흩어지면 Boss 가 보상과 이야기를 연다
static func finale(b) -> void:
	slow(SLOW_FINALE, SLOW_FINALE_SEC)
	Feedback.flash(0.95, Color8(255, 246, 224))
	Feedback.hit_stop(0.18)
	GameCamera.current.shake(20)
	Cutscene.music = "none"          # 음악을 걷는다. 이야기 장면이 다음 곡을 고른다
	Sfx.play("dieBig")
	Sfx.play("stinger")
	var fallen: String = b.def.get("fallen", "쓰러뜨렸다")
	Cutscene.show_card(b.def.name, fallen, 2.6)
	(Engine.get_main_loop() as SceneTree).create_timer(3.2, true, false, true).timeout.connect(func():
		if not Cutscene.on and Cutscene.music == "none": Cutscene.music = "")
