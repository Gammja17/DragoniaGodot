class_name Prologue
## 2D판 systems/prologue.js. 프롤로그: 하늘에서 떨어지던 그 밤.
##
##   하늘  깊은 밤의 광장. 아직 아무도 없다
##   낙하  빛 하나가 비스듬히 꼬리를 끌며 내려온다 (아직 용으로 안 보인다)
##   충돌  섬광·흔들림·충격파. 연기가 걷히면 빛이 아니라 쓰러진 용이다
##   포코  포코가 걸어 들어와 발견한다
##   엘더  포코가 데려온 엘더가 알아본다
##   끝    「사흘 뒤」 로 넘기고 첫 대화("깼구나. 사흘 잤다.")에 잇는다
##
## 새 게임에서만 돌고, 아무 때나 Esc 로 건너뛸 수 있다. 진행 상태는 GameState.prologue 에 둔다 —
## Dragon 이 이걸 보고 조작을 막고, 낙하 중에는 용을 감춘다.

const NIGHT := 0.04      # 프롤로그 동안의 시각 (깊은 밤)
const SKY := 1.4         # 떨어지기 전의 정적
const FALL := 1.6        # 떨어지는 데 걸리는 시간
const SETTLE := 2.4      # 연기가 걷힐 때까지
const START_H := 0.5     # 어디서부터 그어 내려올까 (화면 높이의 몇 할 위)
const SLANT := 220.0     # 얼마나 비스듬히 그어 내려올까 (px)


static func active() -> bool: return GameState.prologue != null


## 새 게임 시작 직후. done: 프롤로그가 끝나면 부를 것 (보통 엘더와의 첫 대화)
static func start(done: Callable) -> void:
	var p = GameState.player
	GameState.prologue = { step = "sky", t = 0.0, dayTime = GameState.dayTime, puff = 0.0, trail = 0.0, done = done }
	GameState.dayTime = NIGHT
	p.is_hidden = true         # 떨어지는 동안에는 빛으로만 보인다
	_hide_village(true)        # 한밤중이다. 불려 나온 이 말고는 아무도 없어야 한다
	Cutscene.begin("")         # 제목 없이 위아래 띠만


## 마을 용들을 감춘다. 풀 때는 캐시된 용 전부를 푼다 (감춰진 사이에 문을 나선 용이 투명인간으로 남지 않게)
static func _hide_village(hide: bool) -> void:
	for n in (GameState.entities.npcs if hide else World.fixed_npcs()): n.is_hidden = hide


## main 에서 매 프레임. 대화창이 떠 있어도 돌아야 한다
static func update(dt: float) -> void:
	var s = GameState.prologue
	if not s: return
	s.t += dt
	var p = GameState.player
	if s.step == "sky":
		if s.t >= SKY:
			s.step = "fall"
			s.t = 0.0
	elif s.step == "fall":
		# 뒤로 갈수록 빨라진다. 빛덩이 하나가 화면 위에서 비스듬히 그어 내려온다
		var k := minf(1, s.t / FALL)
		var x: float = p.x + (1 - k) * SLANT
		var y: float = p.y - (1 - k * k) * GameCamera.current.h * START_H
		s.trail -= dt
		if s.trail <= 0:
			Vfx.spawn_effect("METEOR", x, y)
			s.trail = 0.04
		Particles.burst(x, y, "#ffe9a0", 0.45, 1)
		if k >= 1: _land(p, s)
	elif s.step == "settle":
		s.puff -= dt
		if s.t < SETTLE * 0.7 and s.puff <= 0:
			Vfx.spawn_effect("SMOKE", p.x + Util.rand_range(-34, 34), p.y - Util.rand_range(0, 14))
			s.puff = 0.4
		if s.t >= SETTLE:
			s.step = "poco"
			_talk("Poco", Data.get_module("story").PROLOGUE.poco, func(): _meet_elder(s))


## 광장 한복판에 꽂힌다
static func _land(p, s: Dictionary) -> void:
	p.is_hidden = false
	p.down_timer = 999.0       # 쓰러져 누운 모습으로 그려진다
	Feedback.flash(0.85, Color8(255, 236, 176))
	GameCamera.current.shake(17)
	Feedback.hit_stop(0.12)
	Sfx.play("boom")
	Vfx.spawn_effect("SHOCKWAVE", p.x, p.y)
	Vfx.spawn_effect("SCORCH", p.x, p.y)
	Vfx.spawn_effect("SMOKE", p.x, p.y - 10, { size = 2 })
	Particles.burst(p.x, p.y, "#ffd98a", 1.1, 30)
	s.step = "settle"
	s.t = 0.0
	s.puff = 0.0


## 포코가 엘더를 데려온다
static func _meet_elder(s: Dictionary) -> void:
	s.step = "elder"
	_talk("Elder", Data.get_module("story").PROLOGUE.elder, func(): _finish(s))


## 한 사람이 죽 말한다. cinematic 을 끄고 무대는 여기서 직접 세운다 —
## play_scene 에 맡기면 장면이 끝날 때 컷씬까지 걷어 버려서 우리 띠가 먼저 걷힌다.
static func _talk(who: String, lines: Array, then: Callable) -> void:
	var npc = World.any_npc(who)
	if not npc:   # 그 용이 마을에 없으면 조용히 건너뛴다
		then.call()
		return
	npc.is_hidden = false        # 이 사람만 밤 속에서 걸어 나온다
	Cutscene.focus_on(npc)       # 화면 밖에서 걸어 들어온다
	Chronicle.play_scene("", lines, then, false)


## 「사흘 뒤」 로 넘기고 첫 대화에 잇는다
static func _finish(s: Dictionary) -> void:
	s.step = "fading"   # 이제부터는 건너뛸 게 없다 (Esc 가 끝을 두 번 부르던 것)
	Hud.fade_screen("사흘 뒤", func():
		GameState.dayTime = s.dayTime
		GameState.player.down_timer = 0.0
		_hide_village(false)
		Cutscene.finish(), func():
		var done: Callable = s.done
		GameState.prologue = null
		done.call())


## Esc: 어느 대목이든 건너뛰고 첫 대화로
static func skip() -> void:
	var s = GameState.prologue
	if not s or s.step == "fading": return
	Chronicle._current = null   # 끊긴 포코·엘더의 말이 다음 Esc 에 되살아나지 않게
	var p = GameState.player
	DialogueBox.current.hide_dialogue()
	GameState.isDialogueOpen = false
	GameState.dayTime = s.dayTime
	p.is_hidden = false
	p.down_timer = 0.0
	_hide_village(false)
	Cutscene.finish()
	var done: Callable = s.done
	GameState.prologue = null
	# 같은 프레임에 대화를 열면 건너뛴 그 Esc 가 그 대화까지 그대로 닫는다. 한 박자 둔다
	Skills.later(400, done)
