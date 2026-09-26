extends Node
## 비류 "폭포를 한 번에"(b1): 호수 경주를 세 판 다 이긴 뒤에 · 새벽 폭포 아래 · 말없이 지켜보면 떨어진 비류를 건지고,
## 비류는 제 눈으로 오르지만 다리를 다쳐 사흘 쉰다 (호수 경주 · 그 사이 폭포 경주 밤도 쉰다) · 보고 · 일러 주는 길은 대가 없이.
## 줄마다 [비류] OK/FAIL 을 찍고, 끝에 실패 수를 센다. 저장은 9번 칸만 쓴다.
##   godot --headless --path . res://tools/test_biryu.tscn

var _fails := 0
var _seen := []
var _last := 0


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
	G.day = 23
	G.dayTime = 14.0 / 24
	var p: Dragon = G.player
	p.stage_index = 2
	p.level = 16
	p.max_hp = 5000.0; p.hp = 5000.0
	# 이 사건 말고는 다 본 것으로 (다른 사건이 끼어들지 않게)
	for ev in Data.get_module("chronicle").CHRONICLE:
		if ev.id != "ev_biryu_falls": G.story.events.append(ev.id)
	G.story.eventDay = { ev_gathering = 7 }
	G.quests.done.append_array(["m4", "m5g", "m5a", "m6w", "m5b", "m5c"])
	var biryu = World.any_npc("Biryu")

	# 호수 경주를 세 판 다 이긴 뒤에 부탁한다
	G.story.race = { best = 12.0, level = 2, winDay = -1 }
	_check("두 판만 이긴 판에는 부탁이 없다", _offer_id(biryu), "")
	G.story.race.level = 3
	_check("세 판을 다 이기면 '폭포를 한 번에'", _offer_id(biryu), "b1")
	Quests.accept(Quests.by_id("b1"))

	# 낮에는 아무 일도 없다. 새벽에 폭포 아래로
	await _travel("FALLS")
	await _play(1.0)
	_check("낮에는 사건이 없다", G.story.events.has("ev_biryu_falls"), false)
	await _travel("LAKE")
	G.day = 24
	G.dayTime = 6.0 / 24
	await _travel("FALLS")
	await _play_until(func(): return G.story.events.has("ev_biryu_falls") and _idle(), 40)
	_check("새벽 폭포 아래: 사건이 열렸다", G.story.events.has("ev_biryu_falls"))
	_check("비류: 꼭대기 밑에서 잘못 골랐다", _saw("어릴 때 거기서 잘못 골랐어"))
	_check("말없이 지켜봤다", G.story.get("choices", {}).get("ev_biryu_falls"), "watch")
	_check("떨어진 비류를 건진다", _saw("떨어지는 비류의 목덜미를 물고"))
	_check("비류가 제 눈으로 오른다", _saw("올랐다! 내 눈으로!"))
	_check("유안이 보고 있었다", _saw("넌 그때도 지금도 무모하다"))
	var news: Dictionary = Data.get_module("npcTalk").SITUATION_LINES.filter(func(x): return x.get("id") == "biryuFalls")[0]
	_check("하루가 비류 얘기를 꺼낸다 (소식)", news.when.call(G, World.any_npc("Haru")))

	# 대가: 사흘 동안 경주를 쉰다 (호수 경주 · 그 사이 폭포 경주 밤)
	_check("다리를 다쳐 쉰다 (사흘)", [Race.resting(), int(G.story.biryuRest)], [true, 27])
	_check("호수 경주: 며칠 쉬자고 한다", str(Race.menu_option(biryu).label), "🏁 겨루자고 한다")
	_check("폭포 경주 밤: 겨루기도 쉰다", [Contest.kind_tonight(), Contest.open_now(), Contest.pastime()], ["RACE", false, null])
	_check("일지: 오늘 밤 겨루기는 쉰다", Contest.tonight_note().contains("비류가 다리를 다쳤다"))
	G.day = 27
	_check("사흘이 지나면 다시 겨룬다", Race.resting(), false)
	G.day = 24

	# 보고
	await _talk(biryu)
	_check("비류에게 보고하고 끝낸다", G.quests.done.has("b1"))
	_check("비류: 폭포 위에서 본 아랫마을", _saw("너는 맨날 이런 걸 보는 거였구나"))

	# 일러 주는 길: 대가 없이 사이만 오른다 (선택지 자료)
	var ev: Dictionary = Data.get_module("chronicle").CHRONICLE.filter(func(e): return e.id == "ev_biryu_falls")[0]
	var told: Dictionary = ev.choice.options[0]
	_check("일러 주는 길: 다치지 않는다 · 사이 +10", [told.id, told.get("flag"), int(told.relation.Biryu)], ["told", null, 10])

	print("[끝] 실패 %d" % _fails)
	get_tree().quit(1 if _fails else 0)


func _offer_id(npc) -> String:
	var o = Quests.offer_for(npc)
	return o.id if o else ""


func _travel(id: String) -> void:
	await _play(0.4)
	GameState.player.flying = false
	World.travel_to(id)
	await _play(0.4)


func _talk(npc) -> void:
	var p: Dragon = GameState.player
	if not GameState.entities.npcs.has(npc):
		npc.remove = false; npc.is_hidden = false
		World.add_entity("npcs", npc)
	npc.x = p.x + 80; npc.y = p.y
	NpcActions.open_hub(npc)
	await _play_until(_idle, 30)


func _saw(needle: String) -> bool:
	return _seen.any(func(t): return t.contains(needle))


func _idle() -> bool:
	return GameState.questScenes.is_empty() and not Chronicle._playing and not DialogueBox.is_open() and not Cutscene.on and not Hud.fading()


func _play(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000:
		await get_tree().process_frame
		for e in GameState.entities.enemies: e.remove = true


func _play_until(cond: Callable, sec: float) -> void:
	var t := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t < sec * 1000:
		await get_tree().process_frame
		for e in GameState.entities.enemies: e.remove = true
		_advance()


## 대화를 넘긴다. 사건 끝의 선택에서는 '말없이 지켜본다'를 고른다
func _advance() -> void:
	if Hud.chapter_card_on(): Hud.skip_chapter_card()
	if Time.get_ticks_msec() - _last < 120: return
	_last = Time.get_ticks_msec()
	if Cutscene.busy() and not DialogueBox.is_open():
		Cutscene.rush()
		return
	if not DialogueBox.is_open(): return
	var box = DialogueBox.current
	var text: String = box.shown_text()
	if _seen.is_empty() or _seen[-1] != text: _seen.append(text)
	box._text.visible_characters = -1
	var labels: Array = box._list.map(func(o): return str(o.label))
	if labels.has("말없이 지켜본다"):
		box._choose(labels.find("말없이 지켜본다"))
		return
	if labels.size() > 1 and labels[0] == "💬 이야기를 나눈다":
		NpcActions.close()
		return
	box._choose(0)


func _check(what: String, got, want = true) -> void:
	var ok: bool = str(got) == str(want)
	if not ok: _fails += 1
	print("[비류] %s %s%s" % ["OK  " if ok else "FAIL", what, "" if ok else "  (%s · 기대 %s)" % [str(got), str(want)]])
