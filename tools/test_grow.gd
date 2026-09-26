extends Node
## 같이 자라기: 포코는 그론을 보낸 뒤 카이론의 성체 시험(p3), 하루는 징검돌(hr1) 뒤 구름마루 샘의 성년례(hr2).
## 자라기 전에는 짝을 맺지 않고, 나만 먼저 어른이면 데이트도 쉰다 · 불러와도 어른 모습 · 아이는 마을 용 부모의 어릴 적 모습.
## 줄마다 [자람] OK/FAIL 을 찍고, 끝에 실패 수를 센다. 저장은 9번 칸만 쓴다.
##   godot --headless --path . res://tools/test_grow.tscn

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
	G.tutorial.toured = true
	G.raidTimer = 99999
	G.day = 20
	G.dayTime = 0.45
	G.weather.type = "CLEAR"
	G.story.scenes = ["ch1"]
	G.quests.done = ["m0", "m1", "m1n", "m2", "m3", "m4", "m5h", "m5", "m5g", "m5a", "m6w", "p1", "p2", "hr1"]
	for ev in Data.get_module("chronicle").CHRONICLE:
		if not ev.id in ["ev_poco_trial", "ev_haru_rite"]: G.story.events.append(ev.id)
	G.tutorial.hints = {}
	for h in Tutorial._hints(): G.tutorial.hints[h.id] = true   # 안내가 끼어들어 자리를 옮기지 않게
	var p: Dragon = G.player
	p.max_hp = 5000.0; p.hp = 5000.0
	var poco = World.any_npc("Poco")
	var haru = World.any_npc("Haru")

	# 둘 다 아이일 때는 데이트할 수 있다 (고백은 둘 다 어른이 된 뒤에)
	p.stage_index = 0
	poco.relation = 50.0
	poco.dates = 0
	_check("둘 다 아이: 포코와 데이트할 수 있다", NpcActions._heart_count(poco), " (데이트 0/3)")
	# 나만 어른이 되면 포코가 자랄 때까지 데이트도 쉰다
	p.stage_index = 2
	_check("나만 어른: 마음 메뉴가 없다 (데이트한 적 없음)", NpcActions._heart_count(poco), null)
	poco.dates = 2
	_check("나만 어른: 데이트한 사이면 '자랄 때까지'", NpcActions._heart_count(poco), " (자랄 때까지)")
	_check("아직 어린 포코와는 평생을 약속하지 않는다", Story.still_kid(poco), true)
	# 예전 세이브에서 아이인 채 짝이 되었어도 알은 없다
	G.partner = poco
	NpcActions._family_talk(poco)
	await _play_until(_idle, 5)
	_check("짝이어도 아이면 알 얘기는 어른이 되고 나서", _saw("어른이 되고 나서 얘기하자"))
	G.partner = null

	# 그론을 보낸 다음 날부터 포코가 성체 시험을 청한다
	Story._kill_npc("Gron")
	var offer = Quests.offer_for(poco)
	_check("그론을 보낸 그날에는 아직 아니다", offer.id if offer else "", "")
	G.day += 1
	offer = Quests.offer_for(poco)
	_check("다음 날 포코가 '모루 밑'을 꺼낸다", offer.id if offer else "", "p3")
	var p3 = Quests.by_id("p3")
	Quests.accept(p3)
	await _travel("DOJO")
	G.dayTime = 0.45
	await _play_until(func(): return Quests.is_complete(p3) and _idle(), 40)
	_check("카이론: 쓰러지면 일어나라", _saw("쓰러지면 일어나라"))
	_check("포코: 나 이제 어른이야", _saw("나 이제 어른이야"))
	_check("포코가 자랐다 (어른 칸 34 · 크기 0.95)", [poco.look, poco.config.scale], [34, 0.95])
	_check("어른 초상화", poco.sheet.portrait, "poco_adult")
	_check("이야기에 적힌다", G.story.get("grown", []).has("Poco"))
	await _talk(poco)
	_check("포코에게 보고하고 끝낸다", G.quests.done.has("p3"))
	_check("포코: 앞으로 뛸 거야", _saw("나도 앞으로 뛸 거야"))
	# 자란 뒤에는 다시 사귈 수 있다
	poco.dates = 3
	poco.relation = 85.0
	_check("자란 포코에게는 고백할 수 있다", NpcActions._heart_count(poco), " (고백할 수 있다)")

	# 불러오면 마을 용의 설정은 처음 것으로 돌아온다. 이야기에 적힌 대로 다시 어른 모습을 입힌다
	poco.set_look(2)
	poco.config.scale = 0.8
	Story.apply_growth()
	_check("불러온 뒤에도 어른 포코", [poco.look, poco.config.scale], [34, 0.95])

	# 하루: 징검돌 뒤 구름마루 샘의 성년례
	offer = Quests.offer_for(haru)
	_check("하루가 성년례 얘기를 꺼낸다", offer.id if offer else "", "hr2")
	var hr2 = Quests.by_id("hr2")
	Quests.accept(hr2)
	await _travel("CLOUDTOP")
	G.dayTime = 0.45
	await _play_until(func(): return Quests.is_complete(hr2) and _idle(), 40)
	_check("리운: 부끄러운 일이 아니오", _saw("부끄러운 일이 아니오"))
	_check("하루가 자랐다 (어른 칸 35)", haru.look, 35)
	await _talk(haru)
	_check("하루에게 보고하고 끝낸다", G.quests.done.has("hr2"))

	# 아이의 모습: 마을 용 부모를 닮으면 그 용의 어릴 적 그림 (칸 번호 없이 섞여 엘더 모습으로 태어나던 것)
	var looks := {}
	for i in 40:
		var g: Dictionary = Kids.mix_genes(p, poco)
		if g.species == "CAST": looks[int(g.look)] = true
	_check("자란 포코를 닮은 아이는 어릴 적 포코(2번 칸)", looks.keys(), [2])
	var keep_species: String = p.species
	var keep_colors: Dictionary = p.colors
	p.species = "WESTERN"
	p.colors = { body = "#aa3322", wing = "#ffcc00" }
	looks = {}
	var no_look := 0
	for i in 40:
		var g: Dictionary = Kids.mix_genes(p, poco)
		if not g.has("look"): no_look += 1
		elif g.species == "CAST": looks[int(g.look)] = true
	_check("섞은 아이에게도 칸 번호가 있다", no_look, 0)
	_check("섞어도 포코 쪽을 닮으면 어릴 적 포코", looks.keys().all(func(k): return k == 2))
	p.species = keep_species
	p.colors = keep_colors

	print("[끝] 실패 %d" % _fails)
	get_tree().quit(1 if _fails else 0)


func _travel(id: String) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 400: await get_tree().process_frame
	World.travel_to(id)
	await get_tree().process_frame


func _talk(npc) -> void:
	var p: Dragon = GameState.player
	if not GameState.entities.npcs.has(npc):
		npc.remove = false; npc.is_hidden = false
		World.add_entity("npcs", npc)
	npc.x = p.x + 80; npc.y = p.y
	NpcActions.open_hub(npc)
	await _play_until(_idle, 30)


func _check(what: String, got, want = true) -> void:
	var ok: bool = str(got) == str(want)
	if not ok: _fails += 1
	print("[자람] %s %s%s" % ["OK  " if ok else "FAIL", what, "" if ok else "  (%s · 기대 %s)" % [str(got), str(want)]])


func _saw(needle: String) -> bool:
	return _seen.any(func(t): return t.contains(needle))


func _idle() -> bool:
	return GameState.questScenes.is_empty() and not Chronicle._playing and not DialogueBox.is_open() and not Cutscene.on and not Hud.fading()


func _play_until(cond: Callable, sec: float) -> void:
	var t := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t < sec * 1000:
		await get_tree().process_frame
		for e in GameState.entities.enemies:
			if e.type != "DUMMY": e.remove = true
		_advance()


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
	var labels: Array = _box._list.map(func(o): return str(o.label))
	if labels.size() > 1 and labels[0] == "💬 이야기를 나눈다":
		NpcActions.close()
		return
	_box._choose(0)
