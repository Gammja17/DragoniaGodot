extends Node
## 달맞이 모임의 겨루기: 모임 밤마다 한 판 (폭포 경주 → 낚시 → 겨루기) · 첫 모임 밤은 모임만 · 한 밤에 한 판 ·
## 폭포 경주는 폭포 길 · 낚시는 큰 고기를 먼저 · 겨루기는 유안 · 진 맞수는 한 판 더 세진다 · 일지 · 응원.
## 줄마다 [겨루기] OK/FAIL 을 찍고, 끝에 실패 수를 센다. 저장은 9번 칸만 쓴다.
##   godot --headless --path . res://tools/test_contest.tscn

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
	G.weather.type = "CLEAR"
	var p: Dragon = G.player
	p.stage_index = 2
	p.level = 16
	p.max_hp = 5000.0; p.hp = 5000.0
	# 전쟁이 끝나고 두 마을이 나란히 선 뒤 (together). 모임 장면은 이미 본 것으로
	for ev in Data.get_module("chronicle").CHRONICLE: G.story.events.append(ev.id)   # 이야기 사건이 끼어들지 않게
	G.story.eventDay = { ev_gathering = 7 }
	G.quests.done.append_array(["m4", "m5g", "m5a", "m6w", "m5b", "m5c"])
	G.story.gatherings = ["first", "after_war", "together"]

	# 첫 모임 밤은 모임만
	G.day = 7
	G.dayTime = 20.5 / 24
	await _go("FALLS")
	_check("첫 모임 밤에는 겨루기가 없다", Contest.open_now(), false)
	_check("첫 모임 밤: 일지에도 없다", Contest.tonight_note(), "")

	# 스무나흘째 밤: 폭포 경주 (비류)
	G.day = 24
	await _go("LAKE")
	await _go("FALLS")
	await _play(1.0)
	_check("모임 날마다 돌아간다: 24일은 폭포 경주", Contest.kind_tonight(), "RACE")
	_check("모임이 서면 겨룰 수 있다", Contest.open_now())
	_check("일지: 오늘 밤 겨루기와 맞수", Contest.tonight_note().contains("[폭포 경주], 맞수는 비류"))
	_check("추적창이 빈 시간에 오늘 밤 겨루기를 짚는다", str(Contest.pastime().title), "오늘 밤 모임 겨루기: 폭포 경주")
	var real_line: Callable = Quests.training.line
	Quests.training.line = func(): return { title = "(수련) 오늘의 수련", goal = "카이론을 찾아가 오늘 할 일을 듣는다." }
	_check("모임 밤에는 오늘의 수련이 남아 있어도 추적창이 겨루기를 먼저 (수련 줄을 비운다)", Quests.tracked_line(), null)
	var night := G.dayTime
	G.dayTime = 10.0 / 24
	_check("모임 날 낮에는 수련을 짚는다", Quests.tracked_line() != null)
	G.dayTime = night
	Quests.training.line = real_line
	var biryu = _here("Biryu")
	var seiran = _here("Seiran")
	_check("비류에게 [모임 겨루기: 폭포 경주]", str(Contest.menu_option(biryu).label), "🏆 모임 겨루기: 폭포 경주")
	_check("오늘 밤 맞수가 아니면 없다", Contest.menu_option(seiran), null)
	Contest.start(biryu, "RACE")
	_check("폭포 길 경주 (22초)", [G.activity.type, G.activity.course.map, G.activity.target], ["RACE", "FALLS", 22.0])
	await _play(3.3)
	var rings: Array = Contest.FALLS_COURSE.rings
	for i in rings.size() + 1:
		var g := Race._goal(i, rings)
		p.x = g.x; p.y = g.y
		await get_tree().process_frame
		if G.activity == null: break
	_check("고리 열을 돌아 모임 자리 앞으로 먼저 오면 이긴다", [G.activity, G.story.contest.wins, Contest.level_of("RACE")], [null, 1, 1])
	_check("비류의 호수 경주 기록은 그대로", Race.level(), 0)
	_check("처음 이긴 밤: 리운이 두 마을 깃발을 건넨다 (굴 살림살이)", Den.owned("KEEP_FLAG"), 1)
	_check("엘더 · 리운이 겨루기 얘기를 꺼낸다 (소식)", [_news("contestWin", "Elder"), _news("contestWin", "Riun")], [true, true])
	_check("한 밤에 한 판", [Contest.open_now(), Contest.tonight_note(), Contest.pastime()], [false, " 오늘 밤 겨루기는 끝났다.", null])

	# 서른이틀째 밤: 낚시 겨루기 (세이란). 작은 고기는 안 친다 · 큰 고기를 먼저 건지면 이긴다
	G.day = 32
	await _go("LAKE")
	await _go("FALLS")
	await _play(0.6)
	seiran = _here("Seiran")
	_check("32일은 낚시 겨루기", [Contest.kind_tonight(), Contest.menu_option(seiran) != null], ["FISH", true])
	Contest.start(seiran, "FISH")
	_check("낚시 겨루기는 덮칠 수 있게 activity 를 비워 둔다", [G.activity, Contest.fishing != null], [null, true])
	var fish: Array = DiveFish.kinds()
	DiveFish.caught(fish.filter(func(k): return not k.get("big"))[0], p)
	_check("작은 고기는 안 친다", Contest.fishing != null)
	await _play(0.3)
	DiveFish.caught(fish.filter(func(k): return k.id == "moonkoi")[0], p)
	_check("큰 고기를 먼저 건지면 이긴다", [Contest.fishing, G.story.contest.wins, Contest.level_of("FISH")], [null, 2, 1])

	# 마흔째 밤: 겨루기 (유안)
	G.day = 40
	await _go("LAKE")
	await _go("FALLS")
	await _play(0.6)
	var yuan = _here("Yuan")
	_check("40일은 겨루기", [Contest.kind_tonight(), Contest.menu_option(yuan) != null], ["DUEL", true])
	Contest.start(yuan, "DUEL")
	_check("유안과 겨룬다", [G.activity.type, G.activity.npc == yuan], ["DUEL", true])
	await _play(2.5)
	_check("불가의 용들이 응원한다", _cheered())
	G.activity.hp = 0.0
	await _play(0.3)
	_check("기력을 다 깎으면 이긴다", [G.activity, G.story.contest.wins, Contest.level_of("DUEL")], [null, 3, 1])

	# 마흔여드레째 밤: 폭포 경주 두 번째 판 — 진 비류는 연습해서 빨라졌다. 내려앉으면 진다
	G.day = 48
	await _go("LAKE")
	await _go("FALLS")
	await _play(0.6)
	biryu = _here("Biryu")
	Contest.start(biryu, "RACE")
	_check("진 맞수는 한 판 더 세진다 (16.5초)", G.activity.target, 16.5)
	await _play(3.3)
	p.land()
	await _play(0.3)
	_check("내려앉으면 진다", [G.activity, G.story.contest.losses, Contest.level_of("RACE")], [null, 1, 1])

	# 쉰엿새째 밤: 낚시 — 세이란이 먼저 건지면 진다
	G.day = 56
	await _go("LAKE")
	await _go("FALLS")
	await _play(0.6)
	seiran = _here("Seiran")
	Contest.start(seiran, "FISH")
	_check("진 세이란은 물을 더 빨리 읽는다 (55초)", Contest.fishing.target, 55.0)
	Contest.fishing.t = Contest.fishing.target - 0.01
	await _play(0.3)
	_check("세이란이 먼저 건지면 진다", [Contest.fishing, G.story.contest.losses], [null, 2])

	_check("일지 [기록]", Contest.record_line(), ["달맞이 모임 겨루기", "3승 2패"])
	_check("깃발은 처음 이긴 밤에 한 번만", Den.owned("KEEP_FLAG"), 1)
	_check("맞수들이 모임에 나와 있다 (비류 · 세이란 · 유안)", _absent, [])
	# 모임이 멈추면 겨루기도 멈춘다 (잿빛 날개 길)
	G.day = 64
	G.story.route = "dark"
	_check("모임이 멈추면 겨루기도 없다", Contest.open_now(), false)
	G.story.route = null
	Save.save_game()
	_check("저장에 남는다", Save.read(9).story.contest.wins, 3)

	print("[끝] 실패 %d" % _fails)
	get_tree().quit(1 if _fails else 0)


## 모임 자리에 와 있는 그 용 (없으면 적어 두고 불러온다)
func _here(nm: String):
	for n in GameState.entities.npcs:
		if n.config.get("name") == nm and not n.remove: return n
	_absent.append(nm)
	var n = World.any_npc(nm)
	n.remove = false; n.is_hidden = false
	n.x = GameState.player.x + 150; n.y = GameState.player.y
	World.add_entity("npcs", n)
	return n


var _said := []
var _absent := []
func _cheered() -> bool:
	return _said.any(func(s): return Contest.CHEER_WEST.has(s) or Contest.CHEER_CLOUD.has(s))


func _go(map_id: String) -> void:
	await _play(0.4)
	GameState.player.flying = false
	World.travel_to(map_id)
	await get_tree().process_frame


func _play(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000:
		await get_tree().process_frame
		if Hud.chapter_card_on(): Hud.skip_chapter_card()
		for e in GameState.entities.enemies: e.remove = true
		for b in GameState.entities.bullets:
			if b.faction == "ENEMY": b.remove = true   # 유안의 물줄기는 이 시험에서 맞지 않는다
		for n in GameState.entities.npcs:
			if n.current_chat and not _said.has(n.current_chat): _said.append(n.current_chat)


## 마을 용이 그 소식을 인사로 꺼낼 수 있나 (npcTalk 의 SITUATION_LINES)
func _news(id: String, nm: String) -> bool:
	var s: Dictionary = Data.get_module("npcTalk").SITUATION_LINES.filter(func(x): return x.get("id") == id)[0]
	return s.lines.has(nm) and s.when.call(GameState, World.any_npc(nm))


func _check(what: String, got, want = true) -> void:
	var ok: bool = str(got) == str(want)
	if not ok: _fails += 1
	print("[겨루기] %s %s%s" % ["OK  " if ok else "FAIL", what, "" if ok else "  (%s · 기대 %s)" % [str(got), str(want)]])
