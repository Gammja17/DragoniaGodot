extends Node
## 첫날의 끝을 흘려 본다: 첫 사냥 보고 → 게시판(그론) → 해 질 녘으로 건너가 '첫 밤'(엘더 · 골짜기) → '첫 밤' 대목(굴에서 잔다) → 자면 1장 아침.
## 줄마다 [첫 밤] OK/FAIL 을 찍고, 끝에 실패 수를 센다. 저장은 9번 칸만 쓴다.
##   godot --headless --path . res://tools/test_night.tscn

var _box: DialogueBox
var _seen := []
var _fails := 0
var _last := 0


func _ready() -> void:
	Save.slot = 9
	Save.delete()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.play_intro = false
	main.load_save = false
	add_child(main)
	await get_tree().process_frame
	_box = DialogueBox.current
	var G := GameState
	G.elderTutorialDone = true
	G.tutorial.finished = true
	G.tutorial.toured = true   # 해 질 녘 안내가 나올 수 있는 판
	G.raidTimer = 99999
	G.quests.done = ["m0"]
	G.day = 1
	G.dayTime = 0.45
	var p: Dragon = G.player
	var elder = World.any_npc("Elder")
	p.x = elder.x + 90; p.y = elder.y + 30

	# 첫 사냥: 슬라임 셋을 잡고 엘더에게 보고한다 (덫이 뭐냐고 묻는다)
	var m1 = Quests.by_id("m1")
	Quests.accept(m1)
	for i in 3: Quests.notify("kill", "SLIME")
	await _play_until(_idle, 20)
	_check("첫 사냥을 다 했다", Quests.is_complete(m1))
	Quests.turn_in(m1, elder, "ask")
	_check("보고한 뒤 다음에 할 일: 오늘은 여기까지", Quests.suggestion().title, "오늘은 여기까지")

	# 보고 장면 → 게시판 → (해 질 녘) 첫 밤
	await _play_until(func(): return G.quests.active.has("m1n") and _idle(), 60)
	_check("게시판 얘기를 들었다", G.story.events.has("ev_board") and _saw("판때기"))
	_check("첫 밤을 봤다", G.story.events.has("ev_first_night"))
	_check("해 질 녘으로 건너갔다 (%.2f)" % G.dayTime, G.dayTime >= NightEvents.DUSK and G.dayTime < Story.YAWN)
	_check("아직 첫날이다", G.day, 1)
	_check("엘더가 골짜기 끝으로는 가지 말라고 했다", _saw("그 끝으로는 가지 말거라"))
	_check("'첫 밤' 대목이 열렸다", G.quests.active.has("m1n"))
	var line = Quests.tracked_line()
	_check("추적창이 굴에서 자라고 한다", line != null and str(line.goal).contains("내 굴"))
	var aim = Guide._wanted()
	_check("화살표가 내 굴을 가리킨다", aim != null and aim.get("label") == "내 굴")
	_check("일지의 다음 본 이야기: 내일 아침에 이어진다", _upcoming_main(), "다음 이야기는 내일 아침에 이어진다.")
	await _wait(3.0)
	_check("해 질 녘 안내를 또 하지 않는다", G.tutorial.get("hints", {}).get("dusk", false), false)

	# 잔다 → 둘째 날 아침, 엘더가 카이론을 소개한다
	Story.sleep()
	await _play_until(func(): return G.story.scenes.has("ch1") and _idle(), 60)
	_check("둘째 날 아침", G.day, 2)
	_check("'첫 밤' 대목은 자고 나면 보고 없이 끝난다", G.quests.done.has("m1n") and not G.quests.active.has("m1n"))
	var log_ids := []
	for g in Quests.quest_log():
		for r in g.rows: log_ids.append(r.get("id", ""))
	_check("일지 [퀘스트]: 끝낸 '첫 밤'도 목록에 나온다 (마무리 글이 없어 목록이 통째로 비던 것)", log_ids.has("m1n") and log_ids.has("m1"))
	_check("아침에 엘더가 카이론을 소개한다", _saw("내 오랜 친구인데"))
	_check("다음에 할 일이 더는 '오늘은 여기까지'가 아니다", Quests.suggestion().title != "오늘은 여기까지")

	# 아침: 맡은 일이 없으면 추적창은 오늘의 수련을 보여 준다. 화살표도 스승을 가리킨다 (화살표만 엘더를 가리키던 것)
	var kept: Dictionary = G.quests.active.duplicate(true)
	var kept_tracked = G.quests.tracked
	G.quests.active = {}
	G.quests.tracked = null
	var plan = Training.todays_plan()
	_check("아침 · 오늘의 수련이 정해져 있다", plan != null and plan.stage == "offered")
	var line2 = Quests.tracked_line()
	aim = Guide._wanted()
	_check("아침 · 추적창은 오늘의 수련, 화살표는 카이론", [line2 != null and line2.get("training"), aim.get("who") if aim else null], [true, "Kairon"])
	plan.stage = "done"
	var s2 = Quests.suggestion()
	aim = Guide._wanted()
	_check("수련을 마치면 화살표는 다음에 할 만한 일(%s)을 따른다" % s2.title, aim.get("who") if aim else null, s2.get("who") if s2.get("main") else null)
	plan.stage = "offered"
	G.quests.active = kept
	G.quests.tracked = kept_tracked

	# 2장 뒤: 본 이야기가 성체 승급을 기다리면 추적창이 그렇다고 말한다 (곁가지 부탁만 가리키던 것)
	G.quests.done.append_array(["m2", "m3"])
	G.story.lessons = ["L1", "L2", "L3"]
	G.player.stage_index = 1
	G.player.level = 5
	var sug = Quests.suggestion()
	_check("레벨이 모자라면: 할 일을 짚고 성체까지 레벨 5 / 10 을 붙인다", sug.get("kind") == "trial" and (str(sug.title) + str(sug.goal)).contains("5 / 10"))
	G.player.level = 10
	sug = Quests.suggestion()
	_check("레벨이 차면: 스승에게 승급 시험을 청하자 (화살표는 카이론)", sug.get("kind") == "trial" and sug.who == "Kairon" and sug.main)

	# 습격 때: 그론이 살아 있으면 포코는 모루 밑에 숨고 쏘지 않는다. 그론을 보낸 뒤로는 어른들 곁에 선다 · 아기들은 싸우지 않는다
	var poco = World.any_npc("Poco")
	var nuri = World.any_npc("Nuri")
	G.raid.active = true
	_check("습격 · 그론이 살아 있으면 포코는 숨는다", [poco.stays_back(), Routine.plan_for("Poco").doing.contains("모루 밑")], [true, true])
	_check("습격 · 아기(누리)는 싸우지 않는다", nuri.stays_back())
	var dead_was: Array = G.story.get("dead", []).duplicate()
	G.story.dead = dead_was + ["Gron"]
	_check("습격 · 그론을 보낸 뒤로 포코는 어른들 곁에 선다", [poco.stays_back(), Routine.plan_for("Poco").doing.contains("어른들 곁")], [false, true])
	G.story.dead = dead_was
	G.raid.active = false

	# 일과가 없는 용은 사는 곳을 말한다 (뿌리골의 모스를 "마을 어딘가에 있다"고 하던 것)
	_check("모스를 찾을 곳: 뿌리골", Quests.whereabouts("Moss"), "뿌리골에 있다")

	# 5장 달맞이 모임: 사건으로 넘어가는 본 이야기 대목도 그 지도로 가는 문을 가리킨다 (걷는 봇이 마을에서 모임을 기다리던 것)
	var was: Dictionary = G.quests.active.duplicate(true)
	var was_tracked = G.quests.tracked
	G.quests.active = { m5g = { step = 0, n = 0 } }
	G.quests.tracked = "m5g"
	aim = Guide._wanted()
	_check("달맞이 모임 대목: 화살표가 구름 폭포 쪽을 가리킨다", aim != null and aim.get("map") == "FALLS" and aim.get("x") == null)
	G.quests.active = was
	G.quests.tracked = was_tracked

	# 고룡이 되는 대목: 세 마을의 속성을 받기 전에는 그 부탁부터 가리킨다 (빈 둥지를 먼저 가리키던 것)
	var done_was: Array = G.quests.done.duplicate()
	G.quests.active = { m6 = { step = 2, n = 0 } }
	G.quests.tracked = "m6"
	G.quests.done = done_was.filter(func(id): return not ["r1", "e1", "w1"].has(id)) + ["r1"]
	aim = Guide._wanted()
	_check("고룡 대목 · 아직 안 맡은 바윗골의 가람부터", [aim.get("who") if aim else null, Quests.tracked_line().where], ["Garam", "가람 · 바윗골"])
	G.quests.active.e1 = { step = 0, n = 0 }
	aim = Guide._wanted()
	_check("고룡 대목 · 맡은 부탁이면 그 대목 (바윗골의 아이 돌)", aim.get("who") if aim else null, "Dol")
	G.quests.active.erase("e1")
	G.quests.done.append_array(["e1", "w1"])
	aim = Guide._wanted()
	_check("고룡 대목 · 다 받았으면 빈 둥지", [aim.get("map") if aim else null, aim.get("label") if aim else null], ["SKY_RUINS", "빈 둥지"])
	G.quests.done = done_was
	G.quests.active = was
	G.quests.tracked = was_tracked

	# 이그나르를 꺾은 뒤: 무릎 꿇은 이그나르 곁이 대목이다 (곁의 카이론을 가리켜, 말을 걸면 결말의 선택을 건너뛰던 것)
	G.quests.active = { m6 = { step = 4, n = 0 } }
	G.quests.tracked = "m6"
	aim = Guide._wanted()
	_check("이그나르를 꺾은 뒤 · 추적창과 화살표는 정상, 카이론이 아니다",
		[str(Quests.tracked_line().goal).contains("무릎을 꿇은 이그나르"), aim.get("map") if aim else null, aim.get("who") if aim else null], [true, "IGNAR_LAIR", null])
	G.quests.active = was
	G.quests.tracked = was_tracked

	# 사이 장면은 보스 둥지에서는 미루고, 둥지를 나오면 튼다 (이그나르를 꺾은 정상에서 결말의 선택보다 먼저 끼어들던 것)
	var map_was: String = G.map_id
	G.pendingBond = { name = "Kairon", tier = 2 }
	G.map_id = "IGNAR_LAIR"
	await _wait(1.5)
	_check("보스 둥지에서는 사이 장면을 미룬다", G.pendingBond != null)
	G.map_id = map_was
	await _play_until(func(): return G.pendingBond == null and _idle(), 10)
	_check("둥지를 나오면 사이 장면을 튼다", G.pendingBond == null and _saw("스승이 자리를 뜨지 않았다"))

	# 옛 세이브: 첫 밤을 이미 본 판은 '첫 밤' 대목을 지난 것으로 친다
	Save.save_game()
	var data: Dictionary = Save.read()
	data.questLayout = 4
	data.quests.done = data.quests.done.filter(func(id): return id != "m1n")
	Save.apply(data)
	_check("옛 세이브: 첫 밤을 본 판은 '첫 밤' 대목을 지났다", G.quests.done.has("m1n"))

	print("[끝] 실패 %d" % _fails)
	get_tree().quit(1 if _fails else 0)


## 일지의 본 이야기 묶음에서 '???' 로 귀띔하는 줄
func _upcoming_main() -> String:
	for g in Quests.quest_log():
		if g.act != "main": continue
		for r in g.rows:
			if r.get("upcoming"): return r.hint
	return ""


func _check(what: String, got, want = true) -> void:
	var ok: bool = str(got) == str(want)
	if not ok: _fails += 1
	print("[첫 밤] %s %s%s" % ["OK  " if ok else "FAIL", what, "" if ok else "  (%s · 기대 %s)" % [str(got), str(want)]])


func _saw(needle: String) -> bool:
	return _seen.any(func(t): return t.contains(needle))


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000:
		await get_tree().process_frame
		_advance()


func _idle() -> bool:
	return GameState.questScenes.is_empty() and not Chronicle._playing and not DialogueBox.is_open() and not Cutscene.on and not Hud.fading()


func _play_until(cond: Callable, sec: float) -> void:
	var t := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t < sec * 1000:
		await get_tree().process_frame
		_advance()


## 장면을 넘긴다. 뜬 글은 모아 두고, 고를 것이 있으면 첫 줄을 고른다
func _advance() -> void:
	if Hud.chapter_card_on(): Hud.skip_chapter_card()
	if Time.get_ticks_msec() - _last < 120: return
	_last = Time.get_ticks_msec()
	if Cutscene.busy() and not DialogueBox.is_open():
		Cutscene.rush()
		return
	if not DialogueBox.is_open(): return
	var text: String = _box.shown_text()
	if _seen.is_empty() or _seen[-1] != text: _seen.append(text)
	_box._text.visible_characters = -1
	_box._choose(0)
