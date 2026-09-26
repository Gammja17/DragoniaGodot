extends Node
## 나라 줄기를 흘려 본다: 스승님의 제자(n3) — 카이론의 거절 → 엘더의 고백 → 수련장에서 약속을 거둠 → 나라와 겨루기(숨결로) → 보고.
## 그리고 전적(내기 · 겨루기)이 8장 떠나기 전날 밤의 한 줄과 내기 대사를 가르는지, 제자가 된 뒤 둘이 받는 수련이 도는지.
## 줄마다 [나라] OK/FAIL 을 찍고, 끝에 실패 수를 센다. 저장은 9번 칸만 쓴다.
##   godot --headless --path . res://tools/test_nara.tscn

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
	G.day = 6
	G.dayTime = 0.4
	G.story.scenes = ["ch1"]
	G.story.lessons = ["L1", "L2"]
	G.story.lessonDay = 5
	G.quests.done = ["m0", "m1", "m1n", "n1", "n2"]
	# 여기서 볼 사건만 남기고 모두 본 것으로 둔다 (다른 사건이 끼어들지 않게)
	for ev in Data.get_module("chronicle").CHRONICLE:
		if ev.id != "ev_nara_trial": G.story.events.append(ev.id)
	var p: Dragon = G.player
	p.max_hp = 5000.0; p.hp = 5000.0
	var nara = World.any_npc("Nara")
	var kairon = World.any_npc("Kairon")
	var elder = World.any_npc("Elder")

	# 나라가 부탁을 꺼낸다
	var offer = Quests.offer_for(nara)
	_check("둘째 부탁 뒤에 나라가 셋째 부탁을 꺼낸다", offer.id if offer else "", "n3")
	Quests.accept(Quests.by_id("n3"))

	# 카이론: "안 된다" → 영감한테 물어봐라
	await _talk(kairon)
	_check("카이론이 거절하고 엘더에게 미룬다", _saw("영감한테 물어봐라"))
	_check("다음 대목: 엘더에게 묻기", _step(), 1)

	# 엘더: 나라 어미 · 부탁 · 약속을 거둔다
	await _talk(elder)
	_check("엘더가 부탁한 까닭을 털어놓는다", _saw("나라만은 제자로 받지 말아 달라고") and _saw("그 약속은 내가 거둬야겠구나"))
	_check("다음 대목: 수련장으로", _step(), 2)
	_check("추적창이 수련장으로 가라고 한다", str(Quests.tracked_line().goal).contains("수련장"))

	# 수련장: 엘더가 약속을 거두고, 카이론이 나와 붙인다 → 곧바로 겨루기
	World.travel_to("DOJO")
	await _play_until(func(): return G.activity != null, 40)
	_check("수련장에서 엘더가 약속을 거둔다", _saw("오늘로 거두마") and _saw("네 또래부터 넘어 봐라"))
	_check("나라와 겨루기가 시작된다", G.activity != null and G.activity.type == "DUEL" and G.activity.npc == nara)
	_check("다음 대목: 나라와 겨룬다", _step(), 3)
	_check("엘더가 남아서 지켜본다", G.entities.npcs.has(elder))

	# 숨결로 이긴다 (기력을 코드로 깎지 않는다)
	var t0 := Time.get_ticks_msec()
	while G.activity != null and Time.get_ticks_msec() - t0 < 60000:
		GameInput.mouse_inside = true
		GameInput.mouse_down = true
		GameInput.mouse_pos = (Vector2(nara.x, nara.y - 20) - GameCamera.current.position) * GameCamera.current.zoom.x
		p.hp = p.max_hp
		await get_tree().process_frame
	GameInput.mouse_down = false
	print("  나라와 겨루기: %.1f초" % ((Time.get_ticks_msec() - t0) / 1000.0))
	await _play_until(func(): return _idle() and Quests.is_complete(Quests.by_id("n3")), 30)
	_check("시험에서 이겼다", G.story.get("choices", {}).get("nara_trial"), "win")
	_check("카이론이 졌어도 받아 준다", _saw("끝까지 안 물러섰으면 된 거다"))
	_check("전적: 나 1 : 0 나라", "%d:%d" % [G.story.nara.me, G.story.nara.her], "1:0")

	# 나라에게 보고한다
	await _talk(nara)
	_check("스승님의 제자를 마쳤다", G.quests.done.has("n3"))
	_check("나라가 아빠 얘기로 끝맺는다", _saw("아빠 바보"))

	# 제자가 된 뒤: 둘이 받는 수련이 일과에 든다
	var kinds := {}
	G.weather.type = "CLEAR"
	G.story.yesterday = {}
	for i in 12:
		Training._log().count = i
		Training._log().last = null
		var k = Training._choose()
		if k: kinds[k] = true
	_check("일과에 '허수아비 나눠 맡기'가 든다", kinds.has("PAIR"))
	_check("일과에 '나라와 겨루기'가 든다", kinds.has("DUEL_NARA"))

	# 허수아비 나눠 맡기: 나라가 깬 것도 우리 몫이다
	var d: Dictionary = Training._def({ kind = "PAIR" })
	var plan := { day = G.day, kind = "PAIR", stage = "active", n = 0 }
	G.story.plan = plan
	Training._pair(kairon, plan, d)
	await get_tree().process_frame
	var a: Dictionary = G.activity
	_check("한 편 수련이 선다", a != null and a.get("team") == true and a.dummies.size() == 12)
	for dm in a.dummies:
		if is_instance_valid(dm) and not dm.remove: dm.take_damage(99999)
	await _play_until(func(): return plan.stage == "done" and _idle(), 20)
	_check("둘이 다 깨면 이긴다", _saw("손발은 좀 맞는군"))

	# 전적 → 8장 한 줄 · 내기 대사
	_check("아직 한 번도 겨루지 않은 판: 붙어 보지도 못했단", _nara_ch6(), "붙어 보지도")
	Story.nara_result(false)
	_check("한 번씩 이기면 비겼다", G.story.choices.nara_record, "even")
	_check("8장: 비긴 채로 도망가는 게 어딨어", _nara_ch6(), "비긴 채로")
	Story.nara_result(false)
	_check("나라가 앞서면 ahead", G.story.choices.nara_record, "ahead")
	_check("8장: 진 채로 도망가는 게 어딨어", _nara_ch6(), "진 채로")
	var race: Dictionary = Training._def({ kind = "RACE" })
	_check("나라가 지난번에 이겼으면 청소 얘기부터", Training._race_offer(race)[1].text.contains("청소 누가 했더라"))
	for i in 3: Story.nara_result(true)
	_check("내리 지면 '봐주지 마'", Training._race_offer(race)[1].text.contains("내리 졌다고"))
	_check("내리 지면 다음 판이 세진다 (%.2f)" % Story.nara_form(), Story.nara_form() > 1.0)

	# 끊긴 시험 잇기: 대련은 저장되지 않는다. 시험 대목에서 수련장에 오면 나라가 마저 하자고 한다
	G.quests.done.erase("n3")
	G.quests.active.n3 = { step = 3, n = 0 }
	_check("시험 대목에서 수련장에 오면 나라가 마저 하자고 한다", Chronicle._resume_duel())
	await _play_until(func(): return G.activity != null, 20)
	_check("다시 겨루기가 선다", G.activity != null and G.activity.npc == nara)

	print("[끝] 실패 %d" % _fails)
	get_tree().quit(1 if _fails else 0)


func _step() -> int:
	var e = GameState.quests.active.get("n3")
	return int(e.step) if e else -1


## 8장 떠나기 전날 밤에 나라가 하는 한 줄 (지금 전적으로 걸러진 것). 맞는 조각이 들어 있으면 그 조각을 돌려준다
func _nara_ch6() -> String:
	var ch6 = Data.get_module("story").SCENES.filter(func(s): return s.id == "ch6")[0]
	var lines: Array = ch6.lines.filter(func(l): return l.who == "Nara" and l.text.begins_with("돌아와") and Chronicle._chosen(l))
	if lines.size() != 1: return "줄이 %d개" % lines.size()
	for key in ["붙어 보지도", "비긴 채로", "진 채로", "이긴 채로"]:
		if lines[0].text.contains(key): return key
	return lines[0].text


## 그 용에게 말을 건다. 이어지는 장면과 대화를 다 넘긴다
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
	print("[나라] %s %s%s" % ["OK  " if ok else "FAIL", what, "" if ok else "  (%s · 기대 %s)" % [str(got), str(want)]])


func _saw(needle: String) -> bool:
	return _seen.any(func(t): return t.contains(needle))


func _idle() -> bool:
	return GameState.questScenes.is_empty() and not Chronicle._playing and not DialogueBox.is_open() and not Cutscene.on and not Hud.fading()


func _play_until(cond: Callable, sec: float) -> void:
	var t := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t < sec * 1000:
		await get_tree().process_frame
		_advance()


## 장면을 넘긴다. 뜬 글은 모아 두고, 고를 것이 있으면 첫 줄을 고른다 (대화창의 '돌아간다' 같은 줄로는 나가지 않게, 볼일이 끝난 메뉴는 닫는다)
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
	# 말을 걸고 난 뒤 열리는 메뉴(이야기를 나눈다 …)는 닫는다
	if labels.size() > 1 and labels[0] == "💬 이야기를 나눈다":
		NpcActions.close()
		return
	_box._choose(0)
