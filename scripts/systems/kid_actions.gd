class_name KidActions
## 2D판 systems/kidActions.js. 자식과의 대화. 성격(personality)과 애정도에 따라 말투가 달라지고,
## 놀아 주기·훈련은 하루 한 번, 숨결 가르치기는 청소년부터.


static func _close() -> void:
	GameState.isDialogueOpen = false
	GameState.currentNpc = null
	DialogueBox.current.hide_dialogue()


static func _show(baby, kid: Dictionary, text: String, options: Array) -> void:
	GameState.isDialogueOpen = true
	var title := "%s · %s · %s" % [kid.name, Data.get_module("npcTalk").KID_PERSONALITIES[kid.personality], "♥".repeat(maxi(1, roundi(kid.affection / 20.0)))]
	DialogueBox.current.show_dialogue({ name = title, text = text, sheet = baby.sheet, on_close = _close, options = options })


## 애정 단계(0~2)에 맞는 대사 하나
static func _line(kid: Dictionary, kind: String) -> String:
	var talk: Dictionary = Data.get_module("npcTalk").KID_TALK[kid.personality]
	var tier := 2 if kid.affection >= 60 else 1 if kid.affection >= 25 else 0
	return talk[kind][mini(tier, talk[kind].size() - 1)].pick_random()


static func open_hub(baby) -> void:
	var kid = Kids.find(baby)
	if not kid: return
	var p = GameState.player
	var back := func(): open_hub(baby)
	var opts := [
		{ label = "이야기를 나눈다", on_select = func(): _show(baby, kid, _line(kid, "chat"), [{ label = "그랬구나.", on_select = back }]) },
		{ label = "쓰다듬어 준다", on_select = func(): _show(baby, kid, _line(kid, "pet") if baby.pet() else "(방금 쓰다듬어 줘서 시큰둥하다.)", [{ label = "귀여워.", on_select = back }]) },
	]
	# 하루에 두 번까지. 배가 부르면 더 안 먹는다 (고기를 연타해서 키우던 것)
	var fed: int = kid.get("fedCount", 0) if kid.get("fedDay") == GameState.day else 0
	if p.inventory.meat > 0 and fed < 2:
		opts.append({ label = "고기를 먹인다 (고기 -1, 오늘 %d/2)" % fed, on_select = func():
			p.inventory.meat -= 1
			kid.fedDay = GameState.day
			kid.fedCount = fed + 1
			baby.feed()
			_show(baby, kid, _line(kid, "feed"), [{ label = "많이 먹어.", on_select = back }]) })
	elif p.inventory.meat > 0: opts.append({ label = "(오늘은 배가 불러서 더 안 먹는다)", on_select = back })
	if kid.get("lastPlayDay") != GameState.day: opts.append({ label = "놀아 준다 (하루 한 번)", on_select = func(): _play(baby, kid, back) })
	if kid.get("lastTrainDay") != GameState.day and kid.stage != "ADULT": opts.append({ label = "훈련시킨다 (하루 한 번)", on_select = func(): _train(baby, kid, back) })
	if kid.stage != "BABY" and baby.element != p.element:
		var el: Dictionary = Data.get_module("elements").ELEMENTS[p.element]
		opts.append({ label = "%s 숨결을 가르친다" % el.name, on_select = func():
			baby.element = p.element
			Particles.burst(baby.x, baby.y - 30, el.color, 1, 16)
			_show(baby, kid, _line(kid, "learn"), [{ label = "잘했어!", on_select = back }]) })
	if kid.stage != "ADULT":
		opts.append({ label = "둥지를 지키고 있으렴" if kid.mode == "FOLLOW" else "같이 가자", on_select = func():
			Kids.toggle_mode(kid)
			_close() })
	opts.append({ label = "이름을 지어 준다", on_select = func():
		NameInput.ask("아이의 새 이름 (12자까지)", kid.name, func(n: String):
			Kids.rename(kid, n)
			back.call(), 12) })
	opts.append({ label = "다음에 또 놀자", on_select = _close })
	# 부모 사이에 일이 있으면 그 얘기부터 꺼낸다. 일을 맡은 아이는 무슨 일을 하는지 한 줄
	var mood = Family.kid_mood_line(kid)
	var greet: String = mood if mood else _line(kid, "greet")
	var text := "(요즘은 [%s] 일을 한다.)\n\n%s" % [Data.get_module("family").KID_JOBS[kid.job].name, greet] if kid.get("job") else greet
	_show(baby, kid, text, opts)


static func _play(baby, kid: Dictionary, back: Callable) -> void:
	kid.lastPlayDay = GameState.day
	Kids.add_affection(baby, 12)
	baby.play_time = 4.0   # 신나서 빙글빙글
	Particles.burst(baby.x, baby.y - 30, "#ffd84a", 1, 14)
	_show(baby, kid, _line(kid, "play"), [{ label = "하하, 재밌다!", on_select = back }])


static func _train(baby, kid: Dictionary, back: Callable) -> void:
	kid.lastTrainDay = GameState.day
	Kids.add_affection(baby, 4)
	baby.grow(15)
	Hud.pop("%s의 훈련: 성장 +15" % kid.name, "💪")
	_show(baby, kid, _line(kid, "train"), [{ label = "대견하구나.", on_select = back }])
