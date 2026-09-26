extends Node
## 비류와 호수 경주: 모임 뒤 오후엔 비류가 호수에서 헤엄친다 · 못 날면 겨루지 않는다 · 셋을 센 뒤 출발 ·
## 비류는 물 위를 돈다 · 고리를 차례로 빠져나가 첫 고리로 돌아오면 이긴다 · 비류가 먼저 들어오거나 내려앉으면 진다.
## 줄마다 [경주] OK/FAIL 을 찍고, 끝에 실패 수를 센다. 저장은 9번 칸만 쓴다.
##   godot --headless --path . res://tools/test_race.tscn

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
	G.dayTime = 14.0 / 24
	G.weather.type = "CLEAR"
	for ev in Data.get_module("chronicle").CHRONICLE: G.story.events.append(ev.id)
	var p: Dragon = G.player
	p.stage_index = 2
	p.level = 12
	p.max_hp = 5000.0; p.hp = 5000.0
	var biryu = World.any_npc("Biryu")

	# 비류의 일과: 모임으로 두 마을이 다시 오간 뒤로 오후엔 호수에서 헤엄친다
	_check("오후의 비류는 호수에서 헤엄친다", Routine.plan_for("Biryu").map, "LAKE")
	G.story.events.erase("ev_gathering")
	_check("모임 전에는 구름마루를 떠나지 않는다", Routine.plan_for("Biryu").map, "CLOUDTOP")
	_check("모임 전에는 겨루자는 말이 없다", Race.menu_option(biryu), null)
	G.story.events.append("ev_gathering")
	World.travel_to("LAKE")
	await get_tree().process_frame
	_check("호수에 비류가 있다", G.entities.npcs.has(biryu))
	p.stage_index = 1
	_check("못 날면: 겨루자고만 하고 날개가 자라면 오라고 한다", Race.menu_option(biryu).label, "🏁 겨루자고 한다")
	p.stage_index = 2
	_check("호수에서: 호수 한 바퀴 겨루기 (비류 1판째)", str(Race.menu_option(biryu).label).contains("1판째"))

	# 첫 판: 셋을 세는 동안 첫 고리 앞에 붙들린다
	Race.start(biryu)
	_check("날아오른 채 출발 준비", [p.flying, G.activity.type if G.activity else ""], [true, "RACE"])
	await _play(1.0)
	_check("셋을 세는 동안 첫 고리 앞", Vector2(p.x, p.y).distance_to(Vector2(Race.RINGS[0][0], Race.RINGS[0][1] + 40)) < 5)
	await _play(2.5)
	_check("출발했다", G.activity != null and float(G.activity.t) > 0)
	_check("비류는 물 위를 헤엄친다", Terrain.ground_at(biryu.x, biryu.y), "WATER")
	# 고리를 차례로 빠져나가 첫 고리로 돌아온다
	for i in Race.RINGS.size() + 1:
		var g := Race._goal(i)
		p.x = g.x; p.y = g.y
		await get_tree().process_frame
		if G.activity == null: break
	_check("첫 고리로 돌아와 판이 끝났다", G.activity, null)
	_check("첫 판을 이겼다 · 기록이 남는다", [Race.level(), float(G.story.race.best) > 0], [1, true])
	_check("도란 · 세이란이 경주 얘기를 꺼낸다 (소식)", [_news("raceWin", "Doran"), _news("raceWin", "Seiran")], [true, true])
	G.day += 5
	_check("닷새가 지나면 더는 소식이 아니다", _news("raceWin", "Doran"), false)
	G.day -= 5
	_check("일지 기록 줄", str(Race.record_line()[1]).contains("1 / 3판"))

	# 둘째 판: 비류가 먼저 들어오면 진다
	Race.start(biryu)
	await _play(3.3)
	G.activity.t = float(G.activity.target) - 0.01
	await _play(0.4)
	_check("비류가 먼저 들어오면 진다 (판은 그대로)", [G.activity, Race.level()], [null, 1])
	# 내려앉으면 진다
	Race.start(biryu)
	await _play(3.3)
	p.land()
	await _play(0.3)
	_check("내려앉으면 판이 끝난다", G.activity, null)

	print("[끝] 실패 %d" % _fails)
	get_tree().quit(1 if _fails else 0)


func _play(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000:
		await get_tree().process_frame
		for e in GameState.entities.enemies: e.remove = true


## 마을 용이 그 소식을 인사로 꺼낼 수 있나 (npcTalk 의 SITUATION_LINES)
func _news(id: String, nm: String) -> bool:
	var s: Dictionary = Data.get_module("npcTalk").SITUATION_LINES.filter(func(x): return x.get("id") == id)[0]
	return s.lines.has(nm) and s.when.call(GameState, World.any_npc(nm))


func _check(what: String, got, want = true) -> void:
	var ok: bool = str(got) == str(want)
	if not ok: _fails += 1
	print("[경주] %s %s%s" % ["OK  " if ok else "FAIL", what, "" if ok else "  (%s · 기대 %s)" % [str(got), str(want)]])
