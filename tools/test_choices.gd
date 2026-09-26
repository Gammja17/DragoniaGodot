extends Node
## 고른 것의 대가: 밀회(s1) · 폭포 대치(ev_border) · 옛 둥지(mi1) · 어둠에서 돌아옴 · 이그나르를 살리는 조건(k2) · 포코의 귀띔(p1) · 나라의 요령(n1).
## 줄마다 [선택] OK/FAIL 을 찍고, 끝에 실패 수를 센다. 저장은 9번 칸만 쓴다.
##   godot --headless --path . res://tools/test_choices.tscn

var _fails := 0


func _ready() -> void:
	Save.slot = 9
	Save.delete()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.play_intro = false
	main.load_save = false
	add_child(main)
	await get_tree().process_frame
	var G := GameState
	G.elderTutorialDone = true
	G.tutorial.finished = true
	G.raidTimer = 99999
	G.day = 12
	G.dayTime = 0.45
	for ev in Data.get_module("chronicle").CHRONICLE: G.story.events.append(ev.id)   # 사건이 끼어들지 않게

	# 밀회를 감싸면 미라와 가까워진다 (하루 상한과 상관없이) · 장례 날 티아맷이 알아챈다
	var mira = World.any_npc("Mira")
	var before: float = mira.relation
	var s1 = Quests.by_id("s1")
	G.quests.active.s1 = { step = Quests.steps(s1).size(), n = 0 }
	Quests.turn_in(s1, mira, "cover")
	_check("밀회를 감쌌다: 미라 +15 (보고 몫 +10 에 더해)", roundi(mira.relation - before), 10 + 15)
	var funeral: Array = Quests.by_id("m6w").steps[5].scene
	var knew: Array = funeral.filter(func(l): return l.text.contains("알고 있었구나") and Chronicle._chosen(l))
	_check("장례 날 티아맷이 '알고 있었구나' (사이가 멀어지는 박자)", knew.size() == 1 and knew[0].do[0].get("relation") == "Tiamat")
	G.quests.choices.s1 = "tell"
	knew = funeral.filter(func(l): return l.text.contains("알고 있었구나") and Chronicle._chosen(l))
	_check("알렸으면 티아맷은 모른 척하지 않는다", knew.size(), 0)

	# 폭포 대치: 나라 곁에 섰으면 유안이 더 독하게, 막아섰으면 한 수 접는다
	var p = G.player
	for pick in [["follow", 1.2], ["stop", 0.8]]:
		G.story.choices = G.story.get("choices", {})
		G.story.choices.ev_border = pick[0]
		Story._yuan_duel()
		var a = G.activity
		_check("대치에서 %s → 유안의 기세 ×%.1f" % pick, a != null and is_equal_approx(float(a.max), (600 + p.level * 18) * pick[1]))
		G.activity = null
	var border: Array = Data.get_module("chronicle").CHRONICLE.filter(func(e): return e.id == "ev_border")[0].choice.options
	_check("대치 선택지에 사이의 대가", [int(border[0].relation.Nara), int(border[1].relation.Nara), int(border[1].relation.Riun)], [10, -10, 10])

	# 나라의 요령: 전해 주면 나라가 한 박자 기다릴 줄 안다 (더 세진다)
	var plain := Story.nara_form()
	G.quests.choices.n1 = "tip"
	_check("나라에게 요령을 전했다: 기세 +0.1", is_equal_approx(Story.nara_form() - plain, 0.1))

	# 이그나르를 살리는 길은 카이론의 옛이야기(k2)를 들어야 열린다
	var fall = Data.get_module("chronicle").CHRONICLE.filter(func(e): return e.id == "ev_ignar_fall")[0]
	var spare = fall.choice.options.filter(func(o): return o.id == "spare")[0]
	G.story.clues = ["mark", "breath", "seiran", "sky", "city", "brother"]
	_check("단서가 여섯이어도 k2 없이는 '같이 가자'가 없다", spare.when.call(Chronicle.context()), false)
	G.quests.done.append("k2")
	_check("k2 를 들었으면 '같이 가자'", spare.when.call(Chronicle.context()), true)

	# 어둠의 길에서 돌아오면 이그나르가 기억하고, 사흘 동안 수련장이 닫힌다
	G.story.choices.turned_back = "yes"
	var remember: Array = fall.lines.filter(func(l): return l.get("chose") == "turned_back:*" and Chronicle._chosen(l))
	_check("이그나르: 한 번은 내 손을 잡았던 네가", remember.size(), 1)
	G.story.scenes.append("ch1")
	G.story.lessons = ["L1", "L2", "L3", "L4"]
	G.story.erase("plan")
	G.story.turnedBackDay = G.day
	_check("돌아온 날부터 사흘은 수련이 없다", Training.todays_plan(), null)
	G.day += 3
	_check("사흘 뒤에는 수련이 다시 정해진다", Training.todays_plan() != null)

	# 옛 둥지: 늘 하던 대로(fish)면 도란이 이름을 벌써 지었다 (이름 짓기 창이 뜨지 않는다)
	G.quests.choices.mi1 = "fish"
	var hatch = Data.get_module("chronicle").CHRONICLE.filter(func(e): return e.id == "ev_couple_hatch")[0]
	var shown: Array = hatch.lines.filter(func(l): return Chronicle._chosen(l)).map(func(l): return l.text)
	_check("아기 이름: 도란이 지었다", [shown.any(func(t): return t.contains("이름은 내가 벌써 지었구먼")), shown.any(func(t): return t.contains("네가 이름을 지어 줘"))], [true, false])
	Quests.raise_flag("couple_hatched")
	_check("이름 짓기 창이 뜨지 않는다", NameInput.is_open(), false)

	# 포코의 귀띔: 맞았다고 해 줬으면 밀회 소문 때 먼저 알려 준다
	G.quests.choices.p1 = "told"
	var rumor = Data.get_module("chronicle").CHRONICLE.filter(func(e): return e.id == "ev_tryst_rumor")[0]
	_check("포코가 약속대로 먼저 귀띔한다", rumor.lines.any(func(l): return l.get("chose") == "p1:told" and Chronicle._chosen(l)))

	print("[끝] 실패 %d" % _fails)
	get_tree().quit(1 if _fails else 0)


func _check(what: String, got, want = true) -> void:
	var ok: bool = str(got) == str(want)
	if not ok: _fails += 1
	print("[선택] %s %s%s" % ["OK  " if ok else "FAIL", what, "" if ok else "  (%s · 기대 %s)" % [str(got), str(want)]])
