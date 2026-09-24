class_name Achievements
## SKEAM(KING 동아리의 게임 상점) 도전 과제. 웹판이 SKEAM 안에서 돌 때, 이룬 과제를 SKEAM 에 알린다.
## SDK 는 export_presets.cfg 의 html/head_include 가 index.html 머리에 넣는다.
## SKEAM 밖(Pages 주소로 바로 할 때 · 편집기 · PC)에서는 아무 일도 하지 않는다.
##
## 과제는 되도록 세이브에 남는 값에서 읽는다. SKEAM 밖에서 이룬 것도 SKEAM 에서 그 판을 불러오면 그때 알린다.
## 같은 과제를 또 알려도 SKEAM 은 한 번만 센다. 이름과 설명은 SKEAM 의 game.yml 에 적는다 (docs/skeam.md, id 가 같아야 한다).
## 설정의 테스트 단추를 쓴 판(story.flags.tested)은 알리지 않는다.

const CHECK_EVERY := 1.0   # 초. 한 번에 하나만 알린다 (오래 한 판을 처음 불러와도 알림이 한꺼번에 쏟아지지 않게)
const MOON_HUNT := 20      # 붉은 달이 뜬 밤에 쓰러뜨릴 적
const REQUESTS := 6        # 들어줄 마을 용들의 부탁

static var _sent := {}
static var _timer := 0.0
static var _moon_from := -1   # 이번 붉은 달이 뜰 때까지 쓰러뜨린 적 수. 달이 없으면 -1


## 판을 새로 열 때 (Launch.reset_run)
static func reset() -> void:
	_sent = {}
	_timer = 0.0
	_moon_from = -1


## main 의 _update 가 부른다. 대화·장면 중에는 멈추니 과제는 장면이 끝난 뒤에 뜬다
static func update(dt: float) -> void:
	_timer += dt
	if _timer < CHECK_EVERY: return
	_timer = 0.0
	check()


static func check() -> void:
	if GameState.story.get("flags", {}).get("tested"): return
	for id in earned():
		if _sent.has(id): continue
		_sent[id] = true
		if OS.has_feature("web"): JavaScriptBridge.eval("window.SKEAM && SKEAM.unlock('%s')" % id)
		return


## 지금 판에서 이룬 과제 id
static func earned() -> Array:
	var G := GameState
	var s: Dictionary = G.story
	var st: Dictionary = G.stats
	var love: Dictionary = s.get("love", {})
	var kills := _kills()
	var all := {
		# 이야기
		morgath = G.bossesDefeated.has("MORGATH"),
		zalgora = G.bossesDefeated.has("ZALGORA"),
		glacia = G.bossesDefeated.has("GLACIA"),
		basil = G.bossesDefeated.has("BASIL"),
		ignar = G.bossesDefeated.has("IGNAR"),
		ending_guardian = s.get("endingSeen") == "guardian",
		ending_redeem = s.get("endingSeen") == "redeem",
		ending_dark = s.get("endingSeen") == "dark",
		# 성장
		stage_teen = G.player.stage_index >= 1,
		stage_adult = G.player.stage_index >= 2,
		stage_elder = G.player.stage_index >= 3,
		fusion = st.get("fusions", 0) >= 1,
		# 싸움
		first_kill = kills >= 1,
		many_kills = kills >= 300,
		first_elite = st.get("eliteOffer", false),
		brink = st.get("brinks", 0) >= 1,
		first_down = st.get("downs", 0) >= 1,
		raid_defender = G.raid.count - (1 if G.raid.active else 0) >= 5,   # 일지 기록의 '막아낸 습격'
		blood_moon = _moon_kills(kills) >= MOON_HUNT,
		# 생활
		nest = G.den.get("built", false),
		first_kid = not G.kids.is_empty(),
		kid_grown = G.kids.any(func(k): return k.stage == "ADULT"),
		partner = not love.get("ever", []).is_empty(),
		vow = love.get("vow") != null,
		best_friend = World.fixed_npcs().any(func(n): return n.relation >= 75),   # 일지의 '절친'
		cozy_den = Den.cozy_of(Den.MY_DEN).tier >= 4,                             # 아늑함 '내 집'
		chore_regular = st.get("chores", 0) >= 10,
		requests = _requests_done() >= REQUESTS,
		hundred_days = G.day >= 100,
		# 탐험
		waystones = Travel.stone_maps().all(func(id): return G.waystones.has(id)),
		delve_5 = _deepest() >= 5,
		delve_8 = _deepest() >= 8,
		angler = st.get("fish", 0) >= 20,
		relic_collector = G.relics.size() >= 10,
		sneak_caught = int(s.get("tryst", {}).get("fails", 0)) >= 1,
	}
	return all.keys().filter(func(id): return all[id])


static func _kills() -> int:
	var n := 0
	for k in GameState.stats.get("kills", {}): n += int(GameState.stats.kills[k])
	return n


## 이번 붉은 달이 뜬 뒤로 쓰러뜨린 적 수. 붉은 달이 아니면 0
static func _moon_kills(kills: int) -> int:
	if GameState.event != "BLOOD_MOON":
		_moon_from = -1
		return 0
	if _moon_from < 0: _moon_from = kills
	return kills - _moon_from


## 옛 굴에서 가장 깊이 내려간 층. 지금 내려가 있는 층도 센다 (굴을 나올 때에야 적히는 기록을 기다리지 않게)
static func _deepest() -> int:
	var n: int = int(GameState.dungeon.depth) if GameState.dungeon else 0
	var rec: Dictionary = GameState.story.get("delve", {})
	for id in rec: n = maxi(n, int(rec[id].best))
	return n


## 들어준 마을 용들의 부탁: 일지에서 '본 이야기' · '건네받은 속성'이 아닌 갈래 (포코 · 티아맷 · 그론 · 나라 · 미라 · 카이론)
static func _requests_done() -> int:
	var acts: Dictionary = Data.get_module("quests").ACT_NAMES
	var n := 0
	for q in Data.get_module("quests").QUESTS:
		var act: String = q.get("act", "main")
		if acts.has(act) and not ["main", "Gift"].has(act) and GameState.quests.done.has(q.id): n += 1
	return n
