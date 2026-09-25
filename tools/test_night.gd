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
	_check("아침에 엘더가 카이론을 소개한다", _saw("내 오랜 친구인데"))
	_check("다음에 할 일이 더는 '오늘은 여기까지'가 아니다", Quests.suggestion().title != "오늘은 여기까지")

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
