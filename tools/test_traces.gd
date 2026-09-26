extends Node
## 하늘에서만 보이는 옛 흔적: 걸어서는 못 찾는다 · 날아서 한가운데를 지나가면 살펴본다 · 속말 · 일지 [기록] ·
## 들은 이야기에 따라 달라지는 줄 · 뒤에 이어지는 짐작 · 달빛 골짜기의 굴 마을 자리에는 나무가 없다 · 저장.
## 줄마다 [흔적] OK/FAIL 을 찍고, 끝에 실패 수를 센다. 저장은 9번 칸만 쓴다.
##   godot --headless --path . res://tools/test_traces.tscn

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
	G.day = 9
	G.dayTime = 0.45
	G.weather.type = "CLEAR"
	var p: Dragon = G.player
	p.stage_index = 2
	p.level = 10
	p.max_hp = 5000.0; p.hp = 5000.0
	var fall: Dictionary = Traces.LIST[0]

	# 걸어서는 못 찾는다
	p.flying = false
	p.x = fall.at[0]; p.y = fall.at[1]
	await _play(0.4)
	_check("걸어서 지나가면 모른다", Traces.found("fall"), false)
	_check("일지: 못 찾은 것은 어디쯤인지만", Traces.journal_rows()[0], ["???", "웨스턴 마을 어딘가. 위에서 내려다봐야 보인다.", true])
	_check("안 가 본 곳은 이름도 없다", Traces.journal_rows()[4][1], "아직 가 보지 못한 곳")

	# 날아서 한가운데를 지나가면 살펴본다
	p.x = fall.at[0] + 500; p.y = fall.at[1]
	p.flying = true
	await _play(0.3)
	_check("날면 가까운 흔적이 보인다 (안내가 본다)", Traces.near_unfound(700.0))
	p.x = fall.at[0]; p.y = fall.at[1]
	await _play(0.3)
	_check("날아서 지나가면 살펴본다", Traces.found("fall"))
	await _close_scene()
	_check("속말이 뜬다", _saw("내가 떨어진 자리다"))
	_check("일지에 적힌다", Traces.journal_rows()[0], ["광장의 금", "광장 바닥돌의 금. 내가 떨어진 자리다."])
	_check("포코가 그 얘기를 꺼낸다 (소식)", _news("traceFall", "Poco"))
	var again: bool = await _saw_after(0.4)
	_check("한 번 찾은 것은 다시 뜨지 않는다", [again, G.story.traces.size()], [false, 1])

	# 수련장 마당: 엘더에게 떨어진 아이 얘기를 들었으면 그 말을 떠올린다. 카이론의 형 얘기를 들은 뒤로는 짐작이 붙는다
	G.quests.done.append("p1")
	await _find_at("DOJO", "old_fall")
	await _close_scene()
	_check("수련장 마당: 할아버지 말을 떠올린다", _saw("하늘에서 떨어진 아이가 하나 있었다고"))
	var dojo: Dictionary = Traces.LIST[1]
	_check("카이론의 이야기 전에는 본 것만", Traces.note_of(dojo).contains("카이론"), false)
	G.quests.done.append("m5c")
	_check("카이론의 이야기 뒤에는 짐작이 붙는다", Traces.note_of(dojo).contains("형을 부모님이 거둬 길렀다고"))

	# 달빛 골짜기의 굴 마을: 둥근 마당에는 나무가 없고, 서쪽 끝이 옛 굴 입구다
	await _travel("HOLLOW")
	var dens: Dictionary = Traces.LIST[2]
	var c := Vector2(dens.at[0], dens.at[1])
	var trees: Array = G.entities.props.filter(func(x): return x.type == "TREE" and Vector2(x.x, x.y).distance_to(c) < 240)
	_check("굴 마을 마당에는 나무가 없다", trees.size(), 0)
	var cave = G.entities.props.filter(func(x): return x.type == "CAVE" and x.cave_id == "HOLLOW_BARROW")
	var west := c + Vector2(-float(dens.r), 0)
	_check("서쪽 끝이 옛 굴 입구다", cave.any(func(x): return Vector2(x.x, x.y).distance_to(west) < 90))
	await _find_at("HOLLOW", "dens")
	await _close_scene()

	# 폭포 아래 둥근 돌: 첫 모임 뒤로는 모임 자리였다는 짐작이 붙는다
	await _find_at("FALLS", "circle")
	await _close_scene()
	var circle: Dictionary = Traces.LIST[3]
	_check("모임 전에는 본 것만", Traces.note_of(circle).contains("달맞이"), false)
	_check("모임 전: 엘더가 둥근 돌 얘기를 꺼내고 나중에 하자고 미룬다", _news("traceCircle", "Elder"))
	G.story.events.append("ev_gathering")
	_check("모임 뒤에는 미루지 않는다 (그 얘기는 모임이 받는다)", _news("traceCircle", "Elder"), false)
	_check("첫 모임 뒤에는 모임 자리였다", Traces.note_of(circle).contains("달맞이 모임 자리였다"))

	# 불탄 도시: 모르가스 어른을 떠올린다
	await _find_at("ASH_CITY", "shadow")
	await _close_scene()
	_check("불탄 도시: 모르가스 어른을 떠올린다", _saw("모르가스가 예순 해 전에 끝내 막지 못했다는"))
	_check("다섯을 다 찾았다", [Traces.found_count(), Traces.LIST.size()], [5, 5])
	_check("다섯 곳을 다 보면 굴에 그려 둔다 (살림살이)", [_saw("잊기 전에 굴에 그려 두자"), Den.owned("KEEP_MAP")], [true, 1])

	# 내려앉으면 흔적이 스러진다 (그리기)
	p.land()
	await _play(0.8)
	_check("내려앉으면 흔적이 스러진다", Traces._show, 0.0)

	# 저장에 남는다
	Save.save_game()
	var back = Save.read(9)
	_check("저장에 남는다", back.story.traces, ["fall", "old_fall", "dens", "circle", "shadow"])

	print("[끝] 실패 %d" % _fails)
	get_tree().quit(1 if _fails else 0)


## 그 지도로 가서 그 흔적 위를 날아 지나간다
func _find_at(map: String, id: String) -> void:
	if GameState.map_id != map: await _travel(map)
	var t: Dictionary = Traces.LIST.filter(func(x): return x.id == id)[0]
	var p = GameState.player
	if not p.flying: p.toggle_flight()
	p.x = t.at[0]; p.y = t.at[1]
	await _play(0.3)
	_check("%s: 날아서 찾는다" % t.title, Traces.found(id))


func _travel(id: String) -> void:
	var p = GameState.player
	p.flying = false
	World.travel_to(id)
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 400: await get_tree().process_frame


## 속말을 끝까지 넘긴다 (넘기며 본 줄을 적어 둔다)
func _close_scene() -> void:
	for i in 60:
		if not DialogueBox.is_open(): return
		_note_line()
		DialogueBox.current._text.visible_characters = -1
		DialogueBox.current._choose(0)
		for k in 3: await get_tree().process_frame


var _seen := []
func _saw(text: String) -> bool:
	return _seen.any(func(s): return s.contains(text))


func _note_line() -> void:
	if not DialogueBox.is_open(): return
	var text: String = DialogueBox.current.shown_text()
	if _seen.is_empty() or _seen[-1] != text: _seen.append(text)


## 한동안 가만히 두고 새 대화가 뜨는지
func _saw_after(sec: float) -> bool:
	await _play(sec)
	return DialogueBox.is_open()


func _play(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000:
		await get_tree().process_frame
		for e in GameState.entities.enemies: e.remove = true
		_note_line()


## 마을 용이 그 소식을 인사로 꺼낼 수 있나 (npcTalk 의 SITUATION_LINES)
func _news(id: String, nm: String) -> bool:
	var s: Dictionary = Data.get_module("npcTalk").SITUATION_LINES.filter(func(x): return x.get("id") == id)[0]
	return s.lines.has(nm) and s.when.call(GameState, World.any_npc(nm))


func _check(what: String, got, want = true) -> void:
	var ok: bool = str(got) == str(want)
	if not ok: _fails += 1
	print("[흔적] %s %s%s" % ["OK  " if ok else "FAIL", what, "" if ok else "  (%s · 기대 %s)" % [str(got), str(want)]])
