extends Node
## 아이에게 나는 법 가르치기: 어린 용일 때만 · 굴 안에서는 못 한다 · 날아올라 고리 넷 → 처음 자리 ·
## 너무 앞서 가면 아이가 겁을 먹고 멈춘다 · 곁으로 돌아가면 다시 따라온다 · 내려앉으면 수업이 끝난다 ·
## 배운 아이는 내가 날면 같이 난다 · 다 자라면 망루에 선다 · 결말의 생활 줄 · 저장.
## 줄마다 [날기] OK/FAIL 을 찍고, 끝에 실패 수를 센다. 저장은 9번 칸만 쓴다.
##   godot --headless --path . res://tools/test_kidfly.tscn

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
	G.day = 14
	G.dayTime = 0.45
	G.weather.type = "CLEAR"
	var p: Dragon = G.player
	p.stage_index = 2
	p.level = 12
	p.max_hp = 5000.0; p.hp = 5000.0
	p.x = 1632; p.y = 1100   # 광장 위 너른 자리

	var baby := BabyDragon.make(p.x + 40, p.y + 30, Kids.mix_genes(p, null))
	World.add_entity("babies", baby)
	var kid: Dictionary = Kids.register(baby)
	kid.personality = "SHY"
	_check("아기는 아직 못 배운다", KidFlight.can_teach(kid), false)
	baby.grow(80)
	_check("어린 용이 되면 배울 수 있다", [kid.stage, KidFlight.can_teach(kid)], ["TEEN", true])
	KidActions.open_hub(baby)
	await _frames(2)
	_check("아이와의 대화에 [나는 법을 가르친다]", _labels().has("나는 법을 가르친다"))
	KidActions._close()

	# 수업: 날아올라 고리 넷
	KidFlight.start(baby, kid)
	var a: Dictionary = G.activity
	_check("날아오른 채 수업을 시작한다", [p.flying, a.type], [true, "KIDFLY"])
	# 너무 앞서 가면 겁을 먹고 멈춘다
	p.x += 600
	await _frames(3)
	var stuck := Vector2(baby.x, baby.y)
	await _frames(10)
	_check("너무 앞서 가면 겁을 먹고 멈춘다", [a.scared, Vector2(baby.x, baby.y) == stuck], [true, true])
	# 고리는 아이가 곁에 없으면 안 지나간 것
	var g := KidFlight.goal(a)
	p.x = g.x; p.y = g.y
	await _frames(3)
	_check("아이가 곁에 없으면 고리를 지나도 안 친다", a.ring, 0)
	# 곁으로 돌아가면 다시 따라온다
	p.x = baby.x + 60; p.y = baby.y
	await _frames(3)
	_check("곁으로 돌아가면 다시 따라온다", a.scared, false)
	# 아이와 같이 고리 넷을 지나 처음 자리로
	for i in 5:
		g = KidFlight.goal(a)
		p.x = g.x; p.y = g.y
		baby.x = g.x - 50; baby.y = g.y + 20
		a.trail.clear()
		await _frames(2)
		if G.activity == null: break
	_check("고리 넷을 지나 처음 자리로 돌아오면 끝", [G.activity, kid.get("flies", false)], [null, true])
	_check("아이가 떠 있다", baby.fly_h > 0)
	_check("처음 날아오른 날의 발도장 (굴 살림살이)", Den.owned("KEEP_PRINT"), 1)
	_check("티아맷이 아이가 나는 걸 봤다 (소식)", _news("kidFlew", "Tiamat"))
	G.story.kidFlew.parent = "Tiamat"
	_check("아이의 다른 부모는 남 얘기하듯 하지 않는다", [_news("kidFlew", "Tiamat"), _news("kidFlew", "Mira")], [false, true])

	# 배운 아이는 내가 날면 같이 난다
	p.x = 1632; p.y = 1100
	await _play(1.0)
	_check("내가 날면 같이 난다", baby.fly_h > 30)
	p.x = 1900; p.y = 1250   # 내려앉을 수 있는 빈 땅 (분수 · 게시판을 피해)
	_check("내려앉을 수 있는 자리", p.can_land())
	p.land()
	baby.x = p.x + 60; baby.y = p.y + 20
	await _play(1.2)
	_check("내려앉으면 같이 내려앉는다", baby.fly_h, 0.0)

	# 둘째 아이: 수업 도중 내려앉으면 끝난다 (배운 것 없음)
	var baby2 := BabyDragon.make(p.x - 40, p.y + 30, Kids.mix_genes(p, null))
	World.add_entity("babies", baby2)
	var kid2: Dictionary = Kids.register(baby2)
	baby2.grow(80)
	KidFlight.start(baby2, kid2)
	await _frames(3)
	p.land()
	await _frames(3)
	_check("수업 도중 내려앉으면 끝 (못 배운다)", [G.activity, kid2.get("flies", false)], [null, false])
	# 굴 안에서는 가르칠 수 없다
	World.travel_to(Den.MY_DEN)
	await _play(0.4)
	if World.dens().has(G.map_id):
		baby2.x = p.x + 40; baby2.y = p.y
		KidFlight._offer(baby2, kid2, func(): pass)
		await _frames(2)
		_check("굴 안에서는 가르칠 수 없다", DialogueBox.current.shown_text().contains("밖에 나가서"))
		KidActions._close()
	World.travel_to("VILLAGE")
	await _play(0.4)

	# 다 자라면: 배운 아이는 성격과 상관없이 망루에 선다. 못 배운 아이는 성격대로
	baby.grow(80)
	baby2.grow(80)
	kid2.personality = "CALM"
	_check("둘 다 다 자랐다", [kid.stage, kid2.stage], ["ADULT", "ADULT"])
	Family.morning()
	await _close_scene()
	Family.morning()
	await _close_scene()
	_check("나는 법을 배운 수줍음쟁이는 망루 견습", kid.job, "BRAVE")
	_check("못 배운 애어른은 수련장 조수", kid2.job, "CALM")
	_check("성년식: 배운 아이의 말", _saw("저는 망루에 설래요"))
	_check("다 자라면 이제 가르칠 수 없다", KidFlight.can_teach(kid2), false)
	_check("발도장은 한 번만", Den.owned("KEEP_PRINT"), 1)

	# 결말의 생활 줄 (아이가 하나일 때)
	G.kids.erase(kid2)
	_check("결말: 나는 법을 가르친 아이", Ending.life_lines("guardian").any(func(l): return l.contains("내가 나는 법을 가르친 %s의 날갯짓" % kid.name)))
	G.kids.append(kid2)

	# 저장에 남는다
	Save.save_game()
	var back = Save.read(9)
	_check("저장에 남는다", back.kids.map(func(k): return k.get("flies")), [true, false])

	print("[끝] 실패 %d" % _fails)
	get_tree().quit(1 if _fails else 0)


func _labels() -> Array:
	return DialogueBox.current._list.map(func(o): return str(o.label))


var _seen := []
func _saw(text: String) -> bool:
	return _seen.any(func(s): return s.contains(text))


func _close_scene() -> void:
	for i in 60:
		if Hud.chapter_card_on(): Hud.skip_chapter_card()
		if Cutscene.busy() and not DialogueBox.is_open(): Cutscene.rush()
		if DialogueBox.is_open():
			var text: String = DialogueBox.current.shown_text()
			if _seen.is_empty() or _seen[-1] != text: _seen.append(text)
			DialogueBox.current._text.visible_characters = -1
			DialogueBox.current._choose(0)
		elif not Cutscene.on and not Hud.fading(): return
		for k in 3: await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
		for e in GameState.entities.enemies: e.remove = true


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
	print("[날기] %s %s%s" % ["OK  " if ok else "FAIL", what, "" if ok else "  (%s · 기대 %s)" % [str(got), str(want)]])
