class_name Ending
## 이야기의 끝. 이그나르 앞에서 고른 것에 따라 결말이 갈린다 — 끝낸다(수호룡) · 데려간다(교화) · 손을 잡는다(흑화).
## 예전에는 고른 뒤에 걸어서 돌아가 보고하고, 알아서 잠까지 자야 마지막 장면이 나왔다 (안 자면 끝내 안 나왔다).
## 이제는 고르는 순간부터 한 번에 흐른다:
##   (암전) 그날 저녁 마을 → 스승과의 대화 → (암전) 다음 날 아침 · 마지막 장 → 에필로그 몇 장면 → 크레딧 → 이어서 자유롭게
## 흐름표와 대사는 data/ending.json (SEQUENCES · SCENES · CREDITS). 마지막 장 자체는 data/story.json SCENES 의 ending · ending_redeem.
## 결말을 본 뒤로 세상이 달라진다 (습격이 멈춘다 — 지도를 흘리던 이가 없다. Raid.wanted 참고).

static var playing := false
static var _route := ""
static var _steps := []


static func _data() -> Dictionary: return Data.get_module("ending")


## 결말을 이미 봤는가 (어느 길로든)
static func seen() -> bool:
	return GameState.story.get("endingSeen", "") != ""


## 보고가 이야기의 끝이면(m6 · m7d) 여기서 받는다 (NpcActions._report_quest). 받았으면 true.
## 옛 세이브처럼 걸어서 돌아와 보고한 경우: 저녁 장면(스승과의 대화)은 방금 했으니 건너뛴다
static func takes_over(q: Dictionary) -> bool:
	if playing: return true
	if seen(): return false
	if q.id == "m6":
		var r = GameState.story.get("route")
		start("redeem" if r == "redeem" else "guardian", true)
		return true
	if q.id == "m7d":
		start("dark", true)
		return true
	return false


## 결말을 튼다. route: guardian | redeem | dark
static func start(route: String, from_report := false) -> void:
	if playing: return
	playing = true
	_route = route
	GameState.story.route = route
	var seq: Array = _data().SEQUENCES[route].duplicate(true)
	if from_report: seq = seq.filter(func(s): return not s.get("evening", false))
	_steps = seq
	_close_quests()
	_next()


## 본 이야기 퀘스트를 조용히 닫는다 (보고·보상은 받되 배너와 장면은 결말이 대신한다)
static func _close_quests() -> void:
	var id := "m7d" if _route == "dark" else "m6"
	var q = Quests.by_id(id)
	if q and GameState.quests.active.has(id):
		for guard in 8:
			if Quests.is_complete(q): break
			Quests.complete_step(q, true)
		Quests.turn_in(q, World.any_npc(Quests.turn_in_npc(q)), null)
	GameState.questScenes.clear()   # 결말이 직접 튼다
	if Hud.current: Hud.current.clear_quest_banners()
	Quests.changed()


static func _next() -> void:
	if _steps.is_empty():
		_finish()
		return
	var s: Dictionary = _steps.pop_front()
	if s.has("fade"): _fade(s)
	elif s.has("scene"):
		var sc: Dictionary = _data().SCENES[s.scene]
		Chronicle.play_scene(sc.get("title", ""), sc.lines, _next)
	elif s.has("morning"):
		for sc in Data.get_module("story").SCENES:
			if sc.id == s.morning:
				if not GameState.story.scenes.has(sc.id): GameState.story.scenes.append(sc.id)   # 아침에 또 나오지 않게
				Chronicle.play_scene(sc.title, sc.lines, _next)
				return
		_next()
	elif s.has("quest"):
		_quest_end(str(s.quest))
	elif s.has("credits"):
		_roll_credits(str(s.credits))
	else:
		_next()


## 까맣게 덮고, 덮인 동안 때와 자리를 옮긴다 (지역 이름 배너 없이).
## 다음이 장면이면 덮인 동안 걸어 두어서, 막이 걷히면 이미 띠가 내려와 있다 (장면 사이에 HUD 가 번쩍 보이던 것)
static func _fade(s: Dictionary) -> void:
	var handoff: bool = not _steps.is_empty() and (_steps[0].has("scene") or _steps[0].has("morning") or _steps[0].has("quest"))
	Hud.fade_screen(str(s.fade), func():
		if s.get("nextDay", false): GameState.day += 1
		if s.has("time"): GameState.dayTime = float(s.time)
		GameState.weather.type = "CLEAR"
		GameState.event = null
		var place = s.get("place")
		if place and place != GameState.map_id: World.enter_map(place)
		var p = GameState.player
		if s.has("at"):
			var at := World.at(s.at)
			p.x = at.x; p.y = at.y
		p.flying = false
		if GameCamera.current:
			GameCamera.current.cam_x = p.x - GameCamera.current.w / 2
			GameCamera.current.cam_y = p.y - GameCamera.current.h / 2
		if handoff: _next.call_deferred(), func(): if not handoff: _next(), handoff)


## 퀘스트를 닫는 말과 장면을 그 자리에서 (어둠의 길: 엘더에게 하는 보고)
static func _quest_end(id: String) -> void:
	var q = Quests.by_id(id)
	if not q:
		_next()
		return
	var lines := []
	if q.get("done"): lines.append({ who = Quests.turn_in_npc(q), text = q.done, do = [{ bgm = "bloodmoon" }, { tone = "dread" }] })
	var r: Dictionary = q.get("reward", {})
	for l in r.get("scene", []): lines.append(l)
	Chronicle.play_scene(q.title, lines, _next)


static func _roll_credits(end_text: String) -> void:
	var nm: String = GameState.player.config.get("name", "") if GameState.player else ""
	var hatched: bool = GameState.story.get("flags", {}).get("couple_hatched", false)
	var rows := []
	for r in _data().CREDITS:
		var row: Dictionary = r.duplicate()
		var t: String = str(row.get("text", ""))
		t = t.replace("{name}", nm).replace("{IseulTail}", " · %s" % Names.npc("Iseul") if hatched else "")
		# {Elder} 같은 자리에는 그 용의 이름 (지어 준 이름이 있으면 그것)
		var re := RegEx.new()
		re.compile("\\{([A-Za-z]+)\\}")
		for m in re.search_all(t): t = t.replace(m.get_string(0), Names.npc(m.get_string(1)))
		row.text = t
		rows.append(row)
	Cutscene.music = "title"   # 처음 화면의 곡이 다시 흐른다
	Credits.current.roll(rows, end_text, func():
		Cutscene.music = ""
		_next())


static func _finish() -> void:
	playing = false
	GameState.story.endingSeen = _route
	if not GameState.story.has("flags"): GameState.story.flags = {}
	GameState.story.flags.ending = true
	GameState.raidTimer = maxf(GameState.raidTimer, 300)
	GameState.bannerUntil = GameState.play_time + 25   # 끝난 뒤 한동안은 사건 장면을 띄우지 않는다 (숨 돌릴 틈)
	Hud.pop("결말을 보았다. 여기서부터는 마음 가는 대로 — 마을의 하루는 계속된다.", "🌅")   # 마지막 장의 끝줄을 되풀이하지 않는다
	Quests.changed()
	Save.save_game()
