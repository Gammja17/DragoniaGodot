class_name Ending
## 이야기의 끝. 이그나르 앞에서 고른 것에 따라 결말이 갈린다 — 끝낸다(수호룡) · 데려간다(교화) · 손을 잡는다(흑화).
## 예전에는 고른 뒤에 걸어서 돌아가 보고하고, 알아서 잠까지 자야 마지막 장면이 나왔다 (안 자면 끝내 안 나왔다).
## 이제는 고르는 순간부터 한 번에 흐른다:
##   (암전) 그날 저녁 마을 → 스승과의 대화 → (암전) 다음 날 아침 · 마지막 장 → 에필로그 몇 장면 → 생활 → 크레딧 → 이어서 자유롭게
## 흐름표와 대사는 data/ending.json (SEQUENCES · SCENES · LIFE · CREDITS). 마지막 장 자체는 data/story.json SCENES 의 ending · ending_redeem.
## 생활: 내가 꾸린 짝 · 아이 · 굴 · 모임을 한 줄씩 부른다. 해당이 없는 줄은 빠진다 (어둠의 길은 두고 온 것들로).
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
	elif s.has("life"):
		_life(s)
	elif s.has("lines"):
		Chronicle.play_scene("", s.lines, _next)
	elif s.has("credits"):
		_roll_credits(str(s.credits))
	else:
		_next()


## 까맣게 덮고, 덮인 동안 때와 자리를 옮긴다 (지역 이름 배너 없이).
## 다음이 장면이면 덮인 동안 걸어 두어서, 막이 걷히면 이미 띠가 내려와 있다 (장면 사이에 HUD 가 번쩍 보이던 것)
static func _fade(s: Dictionary) -> void:
	var handoff: bool = not _steps.is_empty() and (_steps[0].has("scene") or _steps[0].has("morning") or _steps[0].has("quest") or _steps[0].has("lines"))
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


## 생활: 크레딧 앞에서 내가 꾸린 것들을 한 줄씩 부른다. 부를 게 없으면 암전도 없이 건너뛴다.
## s = { life: 암전 글, place, at, time, nextDay } (암전은 _fade 가 한다)
static func _life(s: Dictionary) -> void:
	var lines := life_lines(_route)
	if lines.is_empty():
		_next()
		return
	_steps.push_front({ lines = lines.map(func(t): return { who = "나", text = t }) })
	var f: Dictionary = s.duplicate()
	f.fade = s.life
	_fade(f)


## 생활 줄 (data/ending.json 의 LIFE). 짝 → 아이 → 굴 → 모임 → 끝까지 곁에서 싸운 용 → 들어준 이웃들 차례.
## 아이는 저마다 제 부모를 닮는다 (짝이 바뀌었어도). 어둠의 길은 결이 다르다: 두고 온 것들로
static func life_lines(route: String) -> Array:
	var dark := route == "dark"
	var L: Dictionary = _data().LIFE["dark" if dark else "home"]
	var out := []
	var partner = GameState.partner
	var love: Dictionary = GameState.story.get("love", {})
	if partner:
		if dark: out.append(L.partner)
		elif love.get("vow"): out.append(L.vow)
		elif love.get("since") != null: out.append(L.partner.replace("{days}", str(maxi(1, GameState.day - int(love.since)))))
		else: out.append(L.partner_long)
	var kids: Array = GameState.kids
	if kids.size() == 1 and dark: out.append(L.kid)
	elif kids.size() == 1:
		var k: Dictionary = kids[0]
		var parent := Kids.parent_of(k)
		var looks: String = L.looks.replace("{parent}", Names.npc(parent)) if parent != "" else ""
		var key: String = "FLY" if k.get("flies", false) else k.stage   # 나한테 나는 법을 배운 아이
		out.append(L.kid.get(key, L.kid.BABY).replace("{kid}", k.name).replace("{looks}", looks))
	elif kids.size() > 1:
		out.append(L.kids.replace("{kids}", ", ".join(PackedStringArray(kids.map(func(k): return k.name)))))
	var tier: int = Den.cozy_of(Den.MY_DEN).tier
	if dark:
		if tier >= 2: out.append(L.den)   # 저녁마다 손님이 들던 굴
		out.append(L.gathering)
	else:
		if tier >= 2: out.append(L.den[str(tier)])
		elif GameState.den.get("built", false): out.append(L.built)
		var phase := Gathering.phase()
		if L.gathering.has(phase): out.append(L.gathering[phase])
		var ally: String = GameState.story.get("ally", "")
		if ally != "" and not Routine.is_dead(ally) and not (partner and partner.config.name == ally):
			out.append(L.ally.replace("{ally}", Names.npc(ally)))
		# 들어준 이웃들의 이야기가 그 뒤로 어떻게 이어졌는지 (많으면 넷까지)
		var told := 0
		for id in L.neighbors:
			if told < 4 and GameState.quests.done.has(id):
				out.append(L.neighbors[id])
				told += 1
	var pn: String = Names.npc(partner.config.name) if partner else ""
	return out.map(func(t): return t.replace("{partner}", pn))


## 크레딧의 "내 식구": 짝과 아이들 이름. 없으면 ""
static func _family() -> String:
	var names := []
	if GameState.partner: names.append(Names.npc(GameState.partner.config.name))
	for k in GameState.kids: names.append(k.name)
	return " · ".join(PackedStringArray(names))


static func _roll_credits(end_text: String) -> void:
	var nm: String = GameState.player.config.get("name", "") if GameState.player else ""
	var hatched: bool = GameState.story.get("flags", {}).get("couple_hatched", false)
	var family := _family()
	var rows := []
	for r in _data().CREDITS:
		if r.get("family") and family == "": continue   # 식구가 없으면 "내 식구" 줄을 통째로 뺀다
		var row: Dictionary = r.duplicate()
		var t: String = str(row.get("text", ""))
		t = t.replace("{name}", nm).replace("{IseulTail}", " · %s" % Names.npc("Iseul") if hatched else "").replace("{Family}", family)
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
