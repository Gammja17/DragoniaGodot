extends Node
## 4단계 시스템을 처음부터 한 바퀴 돈다:
## 프롤로그 → 장 카드 → 촌장과의 첫 대화 → 포코의 마을 구경 → 마을 용 대화 → 게시판 · 석비 →
## 굴(보금자리) → 둥지 짓기 · 잠 → 알 · 아이 → 굴 탐험 → 저장 · 불러오기
##   godot --headless --path . res://tools/test_story.tscn

var _box: DialogueBox


func _ready() -> void:
	Save.slot = 9   # 시험은 9번 칸을 쓴다 (사람이 쓰는 1~3번 칸을 건드리지 않게)
	Save.delete()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	_box = DialogueBox.current
	var p: Dragon = GameState.player

	# 1) 프롤로그: 떨어지고, 포코와 엘더가 온다
	await _wait(1.0)
	print("[프롤로그] ", GameState.prologue != null, " step=", GameState.prologue.step if GameState.prologue else "-")
	await _wait_until(func(): return GameState.prologue and GameState.prologue.step == "poco", 8)
	print("[프롤로그] 포코 장면: ", _say())
	Prologue.skip()
	await _wait(1.0)
	print("[장 카드] ", Hud.chapter_card_on())
	await _wait_until(func(): return DialogueBox.is_open(), 8)
	print("[첫 대화] 컷씬=%s %s" % [Cutscene.on, _say()])
	await _click_through(20)
	print("[첫 대화 뒤] 튜토리얼 끝=%s 고기=%d 구경=%s m0=%s" % [GameState.elderTutorialDone, p.inventory.meat, GameState.tour, GameState.quests.active.get("m0")])

	# 2) 포코를 따라 마을을 돈다 (포코 곁에 붙어 서서 장면마다 넘긴다)
	var t0 := Time.get_ticks_msec()
	var scenes := 0
	while GameState.tour and Time.get_ticks_msec() - t0 < 90000:
		await get_tree().process_frame
		var poco = World.any_npc("Poco")
		if poco:
			p.x = poco.x - 60; p.y = poco.y
		if DialogueBox.is_open():
			scenes += 1
			await _click_through(12)
	print("[구경] 끝=%s 장면 %d번, %.1f초, m0=%s" % [GameState.tour == null, scenes, (Time.get_ticks_msec() - t0) / 1000.0, GameState.quests.active.get("m0")])

	# 3) 마을 용 대화 메뉴
	for nm in ["Gron", "Tiamat", "Kairon", "Nara", "Poco"]:
		var npc = World.any_npc(nm)
		if not npc or not GameState.entities.npcs.has(npc): continue
		p.x = npc.x - 60; p.y = npc.y
		Dialogue.start(npc, "TALK")
		await get_tree().process_frame
		print("[%s] %s" % [nm, _say()])
		Dialogue.close()
	# 대장간 메뉴
	var gron = World.any_npc("Gron")
	NpcActions._open_forge(gron)
	print("[대장간] ", _say())
	Dialogue.close()

	# 4) 게시판 · 석비
	Chores.open_board()
	print("[게시판] ", _say())
	Dialogue.close()
	var stone = null
	for pr in GameState.entities.props:
		if pr.type == "WAYSTONE": stone = pr
	if stone:
		Travel.open_menu(stone)
		print("[석비] ", _say())
		Dialogue.close()

	# 5) 내 굴: 들어가서 둥지를 짓고 잔다
	World.travel_to("DEN_MINE")
	await _wait(0.5)
	print("[굴] 지도=%s 둥지=%d 살림살이=%d 방=%s" % [GameState.map_id, GameState.entities.nests.size(),
		GameState.entities.props.filter(func(x): return x.type == "FURNITURE").size(), Terrain.active is RoomMap])
	DenPanel.open()
	print("[꾸미기] ", _say())
	Dialogue.close()
	GameState.den.twigs = 8
	p.gold += 30
	var nest = GameState.entities.nests[0]
	p.x = nest.x; p.y = nest.y + 40
	Story.open_nest_menu()
	print("[둥지] ", _say())
	_box._choose(1)   # 둥지를 짓는다
	await _wait(0.3)
	await _click_through(3)
	print("[둥지 뒤] 지었나=%s" % GameState.den.built)
	var day0 := GameState.day
	Story.sleep()
	await _wait(3.0)
	await _click_through(20)
	await _wait(1.0)
	print("[잠] 날짜 %d → %d, 시각 %.2f, 지도 %s" % [day0, GameState.day, GameState.dayTime, GameState.map_id])
	if GameState.map_id != "DEN_MINE":
		World.travel_to("DEN_MINE")
		await _wait(0.5)

	# 6) 알 → 아이 (자고 나면 굴을 새로 깔아서 둥지도 새것이다)
	nest = GameState.entities.nests[0]
	nest.lay_egg(p, null)
	nest.progress = 100.5
	await _wait(0.5)
	print("[부화 전] 대화=%s 카드=%s 지도=%s 둥지 알=%s 진행=%.1f" % [GameState.isDialogueOpen, Hud.chapter_card_on(), GameState.map_id, nest.has_egg, nest.progress])
	await _click_through(10)
	await _wait(0.5)
	print("[부화] 아이 %d명 %s" % [GameState.kids.size(), GameState.kids.map(func(k): return k.name)])
	if not GameState.entities.babies.is_empty():
		KidActions.open_hub(GameState.entities.babies[0])
		print("[아이] ", _say())
		Dialogue.close()

	# 7) 굴 탐험: 들어가서 한 층 내려갔다 나온다
	World.travel_to("EAST_ROAD")
	await _wait(0.5)
	Delve.enter("FOREST_HOLE")
	await _wait(2.0)
	print("[굴 탐험] %s 적 %d 파수꾼 %d" % [Delve.dungeon_name(), GameState.entities.enemies.size(), GameState.entities.enemies.filter(func(e): return e.is_guardian).size()])
	for e in GameState.entities.enemies:
		if e.is_guardian: e.take_damage(99999)
	await _wait(0.3)
	Delve.descend()
	await _wait(2.0)
	print("[굴 탐험] 내려감: ", Delve.dungeon_name())
	Delve.leave()
	await _wait(4.0)
	print("[굴 탐험] 나옴: 지도=%s 굴=%s 기록=%s" % [GameState.map_id, GameState.dungeon, GameState.story.get("delve")])
	await _click_through(10)

	# 8) 저장 · 불러오기
	Save.save_game()
	var data = Save.read()
	print("[저장] 읽힘=%s 지도=%s 날짜=%s 아이=%d 퀘스트=%s" % [data != null, data.mapId, data.day, data.kids.size(), data.quests.active.keys()])
	print("[끝] 오류가 없으면 여기까지 온다")
	get_tree().quit()


func _say() -> String:
	if not DialogueBox.is_open(): return "(대화창 없음)"
	var opts: Array = _box._list.map(func(o): return o.label)
	return "%s | %s | %s" % [_box._name.text, _box._text.text.left(60).replace("\n", " "), opts]


## 대화창이 떠 있으면 첫 줄을 골라 넘긴다. 닫히면 멈춘다
func _click_through(limit: int) -> void:
	for i in limit:
		await _wait(0.15)
		if not DialogueBox.is_open(): return
		_box._choose(0)


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000: await get_tree().process_frame


func _wait_until(cond: Callable, sec: float) -> void:
	var t := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t < sec * 1000: await get_tree().process_frame
