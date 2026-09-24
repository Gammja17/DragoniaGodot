class_name Ambush
## 2D판 systems/ambush.js. 사냥꾼 대장 베르단의 포위. 마을 밖 길에서 혼자(혹은 짝과) 둘러싸인다.
##
##   1페  둘러싼 궁수와 기사. 대장은 뒤에서 지휘한다
##   2페  (대장 60%) 그물꾼이 합류하고 대장이 앞으로 나선다
##   3페  (대장 30%) 대장이 부하를 물리고 혼자 돌진한다. 간발로 피하면 비틀거리고, 그동안 두 배로 맞는다
##
## GameState.ambush = { phase, captain, t, waveT, first } · 없으면 없는 것

const CAPTAIN_NAME := "사냥꾼 대장 베르단"
const RING := 400.0


static func active() -> bool: return GameState.ambush != null


## 포위가 시작된다. first: 이야기로 처음 만나는 날 (Chronicle 의 ev_ambush)
static func start(first := false) -> void:
	var p = GameState.player
	var n: int = GameState.story.get("ambushes", 0)
	var cap := Human.make(p.x, p.y - RING, "CAPTAIN")
	cap.max_hp = roundf((700 + p.level * 45) * (1 + n * 0.25))
	cap.hp = cap.max_hp
	cap.power = 1 + n * 0.15
	cap.hold_back = true   # 1페: 뒤에서 지휘만 한다
	World.add_entity("humans", cap)
	_ring(["ARCHER", "KNIGHT", "ARCHER", "KNIGHT", "ARCHER", "KNIGHT"], cap.power)
	GameState.ambush = { phase = 1, captain = cap, t = 0.0, waveT = 0.0, first = first }
	Hud.current.set_boss_bar(CAPTAIN_NAME, 1)
	Hud.pop("둘러싸였다! 사냥꾼 대장이 직접 나왔다." if first else "베르단이 또 길을 막았다. 둘러싸였다!", "⚠️")
	Sfx.play("warn")
	GameCamera.current.shake(8)
	Save.save_game()


static func _ring(types: Array, power: float) -> void:
	var p = GameState.player
	for i in types.size():
		var a := (i / float(types.size())) * TAU + PI / 6
		var h := Human.make(p.x + cos(a) * RING, p.y + sin(a) * RING, types[i])
		h.power = power
		World.add_entity("humans", h)
		Vfx.spawn_effect("PUFF", h.x, h.y - 10)


static func update(dt: float) -> void:
	var a = GameState.ambush
	if not a: return
	var cap = a.captain
	var p = GameState.player
	a.t += dt

	# 다른 지도로 달아났다: 이번에는 놓아 준다. 며칠 뒤 또 온다 (포탈을 넘으면 대장 노드가 먼저 사라진다)
	if not is_instance_valid(cap) or not GameState.entities.humans.has(cap):
		if is_instance_valid(cap) and cap.remove and cap.hp <= 0: return   # die 가 처리했다
		_end(false)
		return

	Hud.current.set_boss_bar(CAPTAIN_NAME + (" · 최후의 돌진" if a.phase == 3 else " · 그물" if a.phase == 2 else ""), maxf(0, cap.hp / cap.max_hp))

	if a.phase == 1 and cap.hp <= cap.max_hp * 0.6:
		a.phase = 2
		cap.hold_back = false
		cap.say("그물을 쳐라! 날개부터 묶어!")
		_ring(["TRAPPER", "TRAPPER", "ARCHER"], cap.power)
		_clear_arrows()
		Sfx.play("warn")
		GameCamera.current.shake(6)
	elif a.phase == 2 and cap.hp <= cap.max_hp * 0.3:
		a.phase = 3
		cap.say("다들 물러서라. 이건 내가 직접 끝낸다.")
		for h in GameState.entities.humans:
			if h != cap: h.fleeing = true
		_clear_arrows()
		cap.hp = maxf(cap.hp, cap.max_hp * 0.3)
		Sfx.play("warn")
		GameCamera.current.shake(10)

	# 3페: 돌진을 되풀이한다. 간발로 피하면 비틀거린다 (Human 의 charge)
	if a.phase == 3 and not cap.charge and not cap.stagger > 0:
		a.waveT -= dt
		if a.waveT <= 0:
			a.waveT = 2.2
			cap.charge = { windup = 0.75, dir = atan2(p.y - cap.y, p.x - cap.x), t = 0.55, speed = 820, hit = false }
			Vfx.spawn_text(cap.x, cap.y - 90, "돌진!", "#ff6b5e", 16)
	# 1~2페: 부하가 다 죽으면 대장이 새로 부른다
	if a.phase < 3:
		a.waveT -= dt
		var alive: int = GameState.entities.humans.filter(func(h): return h != cap and not h.remove).size()
		if alive == 0 and a.waveT <= 0:
			a.waveT = 6.0
			cap.say("다음 조, 앞으로!")
			_ring(["KNIGHT", "ARCHER", "KNIGHT"] if a.phase == 1 else ["TRAPPER", "KNIGHT", "ARCHER"], cap.power)


static func _clear_arrows() -> void:
	for b in GameState.entities.bullets:
		if b.faction == "ENEMY": b.remove = true


## 대장이 쓰러졌다 (Human 의 die)
static func on_captain_down(cap) -> void:
	var a = GameState.ambush
	if not a or a.captain != cap: return
	for h in GameState.entities.humans:
		if h != cap: h.fleeing = true
	GameState.story.ambushes = GameState.story.get("ambushes", 0) + 1
	GameState.story.lastAmbushDay = GameState.day
	Hud.current.set_boss_bar(null)
	var first: bool = a.first
	GameState.ambush = null
	var lines := [
		{ who = "나", text = "(베르단이 무릎을 꿇었다. 부하들이 그를 끌고 물러난다. 떨어뜨리고 간 가죽 두루마리를 펼쳐 보니 우리 마을이 그려져 있다.)" },
		{ who = "나", text = "(집 하나하나, 망루, 굴 입구까지 다 맞다. 전에 티아맷이 짚은 대로, 이것도 하늘에서 내려다보고 그린 것이다. 그때 주운 것보다 훨씬 자세하다.)" },
		{ who = "나", text = "(구석에 인간의 글자가 아닌 것이 적혀 있다. 발톱으로 긁은 자국 같은데, 무슨 뜻인지는 모르겠다.)" },
	] if first else [
		{ who = "나", text = "(베르단이 또 물러났다. 부하들이 끌고 가면서 이쪽을 노려본다. 저 자는 포기할 줄을 모르는 것 같다.)" },
	]
	Chronicle.play_scene("사냥꾼 대장", lines, func():
		if first:
			Chronicle.add_clue("map")
			Hud.pop("일지 [기록]에 단서가 적혔다: 하늘에서 본 지도", "📖")
		if not Relics.owns("CAPTAIN_HORN"): Relics.grant("CAPTAIN_HORN", GameState.player.x, GameState.player.y)
		else: RelicOffer.offer("베르단이 떨어뜨리고 간 짐에서")
		GameState.raidTimer = maxf(GameState.raidTimer, 180)   # 대장이 다쳤으니 한동안 습격이 뜸하다
		Save.save_game())


static func _end(_win: bool) -> void:
	Hud.current.set_boss_bar(null)
	GameState.ambush = null
	for h in GameState.entities.humans: h.fleeing = true
	GameState.story.lastAmbushDay = GameState.day
	Hud.pop("사냥꾼들을 따돌렸다. 베르단은 다시 올 것이다.", "💨")


## 지도에 들어설 때 (World). 처음 만난 뒤로는 닷새마다 한 번쯤 길에서 다시 마주친다
static func maybe(map_id: String) -> void:
	if GameState.ambush or not GameState.story.get("ambushes", 0) > 0 or Ending.seen(): return
	if not ["EAST_ROAD", "SOUTH_ROAD", "LAKE", "HOLLOW", "DESERT"].has(map_id): return
	if GameState.dayTime < 0.25 or GameState.dayTime > 0.8 or GameState.raid.active or GameState.activity: return
	if GameState.day - GameState.story.get("lastAmbushDay", 0) < 5: return
	if randf() < 0.35:
		Skills.later(1500, func():
			if GameState.map_id == map_id and not GameState.isDialogueOpen: start(false))
