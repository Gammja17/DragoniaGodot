extends Node
## 빈 시간: 본 이야기가 멈춘 동안 추적창이 지금 할 수 있는 것 하나를 짚는다 (부탁한 용 → 게시판 새 쪽지 → 물고기 도감),
## 레벨을 기다리는 동안에도 그 일로 레벨이 오른다고 붙인다 · 굴 잠자리의 낮잠 (한낮까지 · 해 질 녘까지).
## 줄마다 [빈 시간] OK/FAIL 을 찍고, 끝에 실패 수를 센다. 저장은 9번 칸만 쓴다.
##   godot --headless --path . res://tools/test_idle.tscn

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
	G.tutorial.toured = true
	G.raidTimer = 99999
	G.day = 5
	G.dayTime = 0.45
	G.story.scenes = ["ch1"]
	G.quests.done = ["m0", "m1", "m1n", "m2", "m3"]
	G.story.lessons = ["L1", "L2", "L3"]
	G.visited.append("LAKE")
	for ev in Data.get_module("chronicle").CHRONICLE: G.story.events.append(ev.id)
	var p: Dragon = G.player
	p.stage_index = 1
	p.level = 6

	# 성체를 기다리는 동안: 부탁한 용을 짚고, 그 일로도 레벨이 오른다고 붙인다
	var sug = Quests.suggestion()
	var side = Quests._side_hint()
	_check("부탁이 있는 용이 있다 (%s)" % (side.title if side else "없음"), side != null)
	_check("추적창: 그 용 · 성체까지 레벨 6 / 10", [sug.title, sug.get("kind"), str(sug.goal).contains("6 / 10")], [side.title if side else "", "trial", true])
	# 부탁을 다 들어줬으면 게시판의 새 쪽지
	for q in Quests.all():
		if q.act != "main" and not G.quests.done.has(q.id): G.quests.done.append(q.id)
	sug = Quests.suggestion()
	var note = Chores.fresh_note()
	_check("부탁이 없으면 게시판 새 쪽지 (%s)" % (note.title if note else "없음"), str(sug.title), "게시판에 새 쪽지: %s" % (note.title if note else ""))
	_check("쪽지의 값이 붙는다", str(sug.goal).contains("경험치"))
	# 쪽지를 두 장 다 떼어 왔으면 물고기 도감
	var c: Dictionary = Chores.refresh_board()
	for id in c.offers.slice(0, Chores.MAX_TAKEN): c.taken[id] = 0
	sug = Quests.suggestion()
	_check("쪽지를 다 떼어 왔으면 물고기 도감 (0 / 14)", str(sug.title), "물고기 도감 채우기 (0 / 14)")
	# 도감까지 다 채웠으면 원래대로 레벨만
	var book := {}
	for k in DiveFish.kinds(): book[k.id] = 1
	G.stats.fishKinds = book
	sug = Quests.suggestion()
	_check("할 거리가 없으면: 성체까지 자라기 (레벨 6 / 10)", str(sug.title).contains("6 / 10"))
	# 날 수 있게 된 뒤에는 하늘에서만 보이는 흔적도 할 거리 (결말 뒤에도 남는다)
	p.stage_index = 2
	_check("날 수 있으면: 하늘에서 본 것 (0 / 5)", str(Quests._pastime(false).title), "하늘에서 본 것 (0 / 5)")
	p.stage_index = 1

	# 굴 잠자리: 낮에는 낮잠 두 가지, 밤에는 밤잠만
	G.dayTime = 10.0 / 24
	Story.open_nest_menu()
	var labels: Array = DialogueBox.current._list.map(func(o): return str(o.label))
	_check("아침: 한숨 · 낮잠 · 밤잠", [labels.has("한숨 잔다 (한낮까지)"), labels.has("낮잠을 잔다 (해 질 녘까지)"), labels.has("잠을 잔다 (다음 날 아침까지)")], [true, true, true])
	Story._close()
	G.dayTime = 14.0 / 24
	Story.open_nest_menu()
	labels = DialogueBox.current._list.map(func(o): return str(o.label))
	_check("오후: 한낮까지는 없다", [labels.has("한숨 잔다 (한낮까지)"), labels.has("낮잠을 잔다 (해 질 녘까지)")], [false, true])
	Story._close()
	G.dayTime = 22.0 / 24
	Story.open_nest_menu()
	labels = DialogueBox.current._list.map(func(o): return str(o.label))
	_check("밤: 낮잠은 없다", labels.any(func(l): return l.contains("낮잠") or l.contains("한숨")), false)
	Story._close()
	# 낮잠을 자면 그날 해 질 녘에 깬다. 날은 넘어가지 않고, 체력이 찬다
	G.dayTime = 10.0 / 24
	var day0: int = G.day
	p.hp = p.max_hp * 0.3
	Story.nap(18.0)
	var t := Time.get_ticks_msec()
	while (Hud.fading() or G.isDialogueOpen) and Time.get_ticks_msec() - t < 8000: await get_tree().process_frame
	_check("해 질 녘(18시)에 깬다 · 날은 그대로", [roundi(G.dayTime * 24), G.day], [18, day0])
	_check("쉰 만큼 체력이 찬다", p.hp > p.max_hp * 0.9)

	print("[끝] 실패 %d" % _fails)
	get_tree().quit(1 if _fails else 0)


func _check(what: String, got, want = true) -> void:
	var ok: bool = str(got) == str(want)
	if not ok: _fails += 1
	print("[빈 시간] %s %s%s" % ["OK  " if ok else "FAIL", what, "" if ok else "  (%s · 기대 %s)" % [str(got), str(want)]])
