class_name NpcActions
## 2D판 systems/npcActions.js. 마을 고정 NPC와의 고유 상호작용:
## 이야기, 선물, 동료, 대련(티아맷), 술래잡기(포코), 대장간(그론), 축복(엘더), 연애와 가족.
## 진행 중인 놀이는 GameState.activity = { type: 'SPAR' | 'TAG', npc, hp, max, time } 에 담는다.

const SPAR_HP := 140.0
const TAG_TIME := 25.0


static func _talk() -> Dictionary: return Data.get_module("npcTalk")


static func relation_tier(r: float) -> int:
	return 3 if r >= 75 else 2 if r >= 50 else 1 if r >= 25 else 0


static func close() -> void:
	GameState.isDialogueOpen = false
	GameState.currentNpc = null
	DialogueBox.current.hide_dialogue()


## 호감도를 올린다. 단계가 올라가면 그 인물의 장면을 하나 예약한다 (지금 대화가 끝난 뒤 Chronicle 이 꺼내 준다)
static func add_relation(npc, amount: float) -> void:
	var before := relation_tier(npc.relation)
	npc.relation = clampf(npc.relation + amount, 0, 100)
	var after := relation_tier(npc.relation)
	var nm: String = npc.config.name
	var bonds: Dictionary = _talk().BOND_SCENES
	if after <= before or not bonds.has(nm) or bonds[nm].size() <= after or not bonds[nm][after]: return
	var key := "%s:%d" % [nm, after]
	if not GameState.story.get("bonds"): GameState.story.bonds = []
	if GameState.story.bonds.has(key): return
	GameState.story.bonds.append(key)
	GameState.pendingBond = { name = nm, tier = after }


static func show(npc, text: String, options: Array) -> void:
	GameState.isDialogueOpen = true
	GameState.currentNpc = npc
	# 사이와 맡은 일은 이름 옆이 아니라 머리 칸에서 보여 준다 (DialogueBox)
	DialogueBox.current.show_dialogue({ name = Names.npc(npc.config.name), text = text, sheet = npc.sheet, npc = npc, on_close = close, options = options })


## Romance 에 넘겨 주는 대화 도구
static func _love_ui() -> Dictionary:
	return { show = show, close = close, play_lines = play_lines, hub = func(npc): open_hub(npc) }


## 고정 NPC의 대화 첫 화면. 이 NPC용 대화가 없으면 false.
## 선택지는 늘 네댓 개를 넘지 않게 묶는다: [용건] · [이야기] · [함께] · [마음] · [닫기].
static func open_hub(npc, skip_errand := false) -> bool:
	var nm: String = npc.config.name
	var talk = _talk().NPC_TALK.get(nm)
	if not npc.config.get("fixed") or not talk: return false
	if GameState.activity:   # 대련·술래잡기 중에는 말을 걸 수 없다
		GameState.isDialogueOpen = false
		GameState.currentNpc = null
		return true
	var tier := relation_tier(npc.relation)
	var opts := []

	# 1) 용건이 있으면 메뉴를 거치지 않고 바로 그 이야기부터 한다.
	#    순서: 보고 → 물어보려던 것 → 건네주려던 것 → 새 부탁
	var running = Quests.running_for(npc)
	# 질투 · 떠남 · 기념일은 다른 용건보다 먼저 나온다
	if not skip_errand and Romance.intercept(npc, _love_ui()): return true
	if not skip_errand:
		var report = Quests.reportable_for(npc)
		if report:
			_report_quest(npc, report)
			return true
		var ask = Quests.talk_quest_for(npc)
		if ask:
			_ask_quest(npc, ask)
			return true
		var bring = Quests.bring_quest_for(npc)
		if bring:
			_bring_to_quest(npc, bring)
			return true
		# 스승은 오늘 할 일부터 말한다
		if nm == "Kairon" and Training.pending():
			Training.open(npc, func(): open_hub(npc, true))
			return true
		var offer = Quests.offer_for(npc)
		# 토라졌거나 서먹한 용은 곁가지 부탁을 꺼내지 않는다
		if offer and not (Romance.mood_greeting(npc) and offer.get("act") != "main"):
			_hear_quest(npc, offer)
			return true

	# 2) 이야기 — 잡담·선물·받을 것
	opts.append({ label = "💬 이야기를 나눈다", on_select = func(): _talk_menu(npc) })
	# 3) 함께 — 그 용만의 것
	var mine = _own_menu(npc, nm)
	if mine: opts.append(mine)
	# 3-1) 주워 온 알 맡기기 — 촌장에게만
	if nm == "Elder" and GameState.player.carrying == "EGG":
		opts.append({ label = "🥚 알을 맡긴다", on_select = func(): _entrust_egg(npc) })
	# 4) 마음 — 짝이 될 수 있는 용만. 짝에게는 꼬리표 없는 "" 가 온다 (null 과 다르다)
	if npc.config.get("canPartner"):
		var heart = _heart_count(npc)
		if heart != null: opts.append({ label = "♥ 마음을 전한다%s" % heart, on_select = func(): _heart_menu(npc) })
	opts.append({ label = "다음에 봐", on_select = close })

	# 인사말 앞에 지금 무얼 하고 있었는지를 한 줄 깔아 둔다. 내 굴까지 따라 들어왔다면 굴 구경평부터 한다
	var text := _greeting(npc, talk, tier)
	if Den.in_my_den(): text = "%s\n\n%s" % [Den.visit_line(), text]
	elif npc.doing: text = "(%s.)\n\n%s" % [npc.doing, text]
	if running: text += "\n\n(%s: %s %d/%d)" % [running.title, Quests.step_goal_text(running), Quests.progress(running), Quests.step_total(running)]
	elif not skip_errand and Quests.held_offer(npc): text += "\n\n(하던 일부터 끝내고 오라는 눈치다.)"
	show(npc, text, opts)
	return true


## NPC 고유 행동 묶음. 없으면 null
static func _own_menu(npc, nm: String):
	var back := func(): open_hub(npc)
	var sub := []
	if nm == "Elder": return { label = "✨ 축복을 청한다", on_select = func(): _blessing(npc) }
	if nm == "Kairon": return { label = "🎓 가르침을 청한다", on_select = func(): show(npc, "무엇을 배우러 왔느냐.", Story.master_options(npc) + [{ label = "돌아간다", on_select = back }]) }
	if nm == "Tiamat": sub.append({ label = "⚔️ 대련을 신청한다", on_select = func(): _start_spar(npc) })
	if nm == "Poco": sub.append({ label = "🎾 술래잡기 하자!", on_select = func(): _start_tag(npc) })
	# 마을 아이들: 성체가 돼야 놀아 줄 수 있다. 놀아 주면 부모의 호감도 같이 오른다
	var kp = _talk().KID_NPC_PLAY.get(nm)
	if kp:
		if GameState.player.stage_index < 2:
			sub.append({ label = "🐉 등에 태워 준다 (성체부터)", on_select = func(): show(npc, kp.tooYoung, [{ label = "…", on_select = back }]) })
		else:
			var rode: bool = npc.last_ride_day == GameState.day
			sub.append({ label = "(오늘은 이미 태워 줬다)" if rode else "🐉 등에 태워 준다", on_select = func():
				if rode: back.call()
				else: _kid_play(npc, kp, "ride") })
			sub.append({ label = "📖 하늘 이야기를 들려준다", on_select = func(): _kid_play(npc, kp, "story") })
			sub.append({ label = "🎾 술래잡기 하자!", on_select = func(): _start_tag(npc) })
	if nm == "Gron": sub.append({ label = "🔨 모루 앞에 선다", on_select = func(): _open_forge(npc) })
	if nm == "Ember" and Routine.is_dead("Gron"): sub.append({ label = "🔨 모루 앞에 선다", on_select = func(): _ember_forge(npc) })
	# 동행. 짝도 오늘은 혼자 다녀오겠다고 할 수 있다. 토라진 짝은 사과가 먼저다 (마음 메뉴)
	if npc == GameState.partner and Romance.is_sulking(npc):
		pass
	elif npc == GameState.partner:
		if npc.state == "WANDER": sub.append({ label = "🤝 같이 가자", on_select = func(): _set_following(npc, true) })
		else: sub.append({ label = "👋 여기서 기다려 줄래?", on_select = func(): _set_following(npc, false) })
		# 가족 나들이: 짝이 곁에 있고 아이가 있을 때, 사흘에 한 번
		if Family.can_outing(): sub.append({ label = "🧺 다 같이 호숫가로 나들이를 간다", on_select = func():
			close()
			Family.go_outing() })
		elif GameState.kids.size() > 0 and Family.outing_wait() > 0: sub.append({ label = "(나들이는 %d일 뒤에 또 갈 수 있다)" % Family.outing_wait(), on_select = back })
	elif GameState.companion == npc:
		sub.append({ label = "이제 마을로 돌아가도 돼", on_select = func(): _set_companion(npc, false) })
	elif relation_tier(npc.relation) >= 2:
		sub.append({ label = "🤝 같이 모험을 떠나자", on_select = func(): _set_companion(npc, true) })
	if sub.is_empty(): return null
	if sub.size() == 1: return sub[0]
	return { label = "🤝 함께 하자고 한다", on_select = func(): show(npc, "뭘 같이 할까?", sub + [{ label = "돌아간다", on_select = back }]) }


## 잡담·선물 묶음
static func _talk_menu(npc) -> void:
	var p = GameState.player
	var sub := [{ label = "요즘 어때?", on_select = func(): _chat(npc) }]
	if p.inventory.meat > 0 and npc.last_gift_day != GameState.day:
		sub.append({ label = "🎁 고기를 선물한다 (고기 -1)", on_select = func(): _give_gift(npc) })
	if relation_tier(npc.relation) >= 2 and npc.last_present_day != GameState.day:
		sub.append({ label = "(뭔가 주려는 눈치다)", on_select = func(): _receive_present(npc) })
	sub.append({ label = "돌아간다", on_select = func(): open_hub(npc) })
	if sub.size() == 2:   # 잡담밖에 없으면 바로 잡담
		_chat(npc)
		return
	show(npc, "무슨 얘기를 할까?", sub)


## 데이트를 청할 수 있는 호감도. 스승·촌장·그론은 좀 더 높다
static func _date_threshold(npc) -> float:
	var gate = _talk().ROMANCE_GATES.get(npc.config.name)
	return gate.dateAt if gate else 40.0


## 연애 묶음에 붙는 꼬리표 (null = 아직 아무것도 못 한다)
static func _heart_count(npc):
	var dates: int = npc.dates
	if npc == GameState.partner: return " (토라져 있다)" if Romance.is_sulking(npc) else ""
	if Romance.heart_closed(npc): return null   # 헤어졌거나 마음을 접게 한 뒤로 한동안은 말을 꺼낼 수 없다
	var gate = _talk().ROMANCE_GATES.get(npc.config.name)
	if gate and not gate.gate.call(GameState): return null   # 아직 때가 아니다
	if dates >= 3 and npc.relation >= 80: return " (고백할 수 있다)"
	if npc.relation >= _date_threshold(npc): return " (데이트 %d/3)" % dates
	return null


static func _heart_menu(npc) -> void:
	var dates: int = npc.dates
	var sub := []
	var hub := func(): open_hub(npc)
	var ui := _love_ui()
	if npc == GameState.partner and Romance.is_sulking(npc):
		sub.append({ label = "🍖 고기 3개를 건네며 사과한다", on_select = func(): Romance.apologize(npc, ui) })
		sub.append({ label = "…우리 그만하자", on_select = func(): Romance.break_up(npc, ui) })
	elif npc == GameState.partner:
		sub.append({ label = "우리… 아이를 가질까?", on_select = func(): _family_talk(npc) })
		var hint = Romance.vow_hint(npc)
		if Romance.can_vow(npc): sub.append({ label = "💍 평생을 약속한다", on_select = func(): Romance.make_vow(npc, ui) })
		elif hint: sub.append({ label = hint, on_select = hub })
		elif Romance.vowed(npc): sub.append({ label = "(평생을 약속한 사이다)", on_select = hub })
		sub.append({ label = "…우리 그만하자", on_select = func(): Romance.break_up(npc, ui) })
	elif dates >= 3 and npc.relation >= 80:
		sub.append({ label = "♥ 마음을 고백한다", on_select = func(): _confess(npc) })
	elif npc.relation >= _date_threshold(npc) and dates < 3:
		if npc.last_date_day == GameState.day: sub.append({ label = "(오늘은 이미 함께 있었다. %d/3)" % dates, on_select = hub })
		else: sub.append({ label = "♥ 데이트를 신청한다 (%d/3)" % dates, on_select = func(): _go_on_date(npc) })
	elif dates >= 3:
		sub.append({ label = "(마음은 통한 것 같은데, 아직 한마디가 모자라다)", on_select = hub })
	sub.append({ label = "돌아간다", on_select = hub })
	if sub.size() == 2:
		sub[0].on_select.call()
		return
	show(npc, "……", sub)


## 부탁을 듣는다: 배경을 읽고 수락 여부를 고른다. 맡으면 그대로 대화를 끝낸다
static func _hear_quest(npc, q: Dictionary) -> void:
	show(npc, q.offer, [
		{ label = "📜 맡는다: %s" % q.title, on_select = func():
			close()
			Quests.accept(q) },
		{ label = "지금은 어렵겠어", on_select = close },
		{ label = "다른 얘기를 한다", on_select = func(): open_hub(npc, true) },
	])


## 물어보려던 대목. 말을 거는 순간 대목이 넘어가고 그 자리에서 장면이 난다.
## 장면이 끝나면 대화창을 다시 열어 준다 — 이어서 [승급 시험]을 청하는 식이 되게.
static func _ask_quest(npc, q: Dictionary) -> void:
	var st = Quests.cur_step(q)
	close()
	Quests.complete_step(q, true)
	if st and st.get("scene"): Chronicle.play_scene(q.title, st.scene, func(): _after_step(npc))
	else: _after_step(npc)


## 말을 걸거나 건네주는 대목이 끝난 뒤. 그게 마지막 대목이고 보고받을 용도 이 용이면 곧바로 마무리 말로 이어진다
static func _after_step(npc) -> void:
	var report = Quests.reportable_for(npc)
	if report: _report_quest(npc, report)
	else: open_hub(npc, true)


## 건네주려던 대목. 모자라면 얼마나 모자란지 알려 준다
static func _bring_to_quest(npc, q: Dictionary) -> void:
	var st: Dictionary = Quests.cur_step(q)
	var need: int = int(st.goal.get("count", 1)) if st.goal.get("count") else 1
	var have: int = GameState.player.inventory.meat
	var hint: String = st.get("hint", "") if st.get("hint") else ""
	if have < need:
		show(npc, "%s\n\n(지금 가진 고기 %d개. %d개가 더 필요하다.)" % [hint, have, need - have], [
			{ label = "더 모아 온다", on_select = close },
			{ label = "다른 얘기를 한다", on_select = func(): open_hub(npc, true) },
		])
		return
	show(npc, hint if hint else "건넬 것이 있다.", [
		{ label = "🍖 고기 %d개를 건넨다" % need, on_select = func():
			close()
			if not Quests.hand_over(q): return
			Quests.complete_step(q, true)
			if st.get("scene"): Chronicle.play_scene(q.title, st.scene, func(): _after_step(npc))
			else: _after_step(npc) },
		{ label = "아직 안 줄래", on_select = close },
	])


## 끝낸 일을 보고한다. 마무리에 고를 것이 있으면 그것부터 묻는다
static func _report_quest(npc, q: Dictionary) -> void:
	var finish := func(choice_id):
		close()
		Quests.turn_in(q, npc, choice_id)
		var nxt = Quests.offer_for(npc)
		if nxt: _hear_quest(npc, nxt)
	if not q.get("choice"):
		show(npc, q.done, [{ label = "보상을 받는다 (%s)" % q.title, on_select = func(): finish.call(null) }])
		return
	# 마무리는 한 화면에서. 보고를 받은 말 아래에 고를 것을 바로 붙인다
	show(npc, "%s\n\n%s" % [q.done, q.choice.prompt], q.choice.options.map(func(o): return { label = o.label, on_select = func(): finish.call(o.id) }))


## 인사말: 가끔은 지금 상황(날씨, 밤, 습격, 가족…)에 맞는 한마디
static func _greeting(npc, talk: Dictionary, tier: int) -> String:
	var mood = Romance.mood_greeting(npc)   # 토라졌거나 헤어진 뒤에는 평소 인사가 나오지 않는다
	if mood: return mood
	var nm: String = npc.config.name
	var fits: Array = _talk().SITUATION_LINES.filter(func(s): return s.lines.has(nm) and s.when.call(GameState, npc))
	for s in fits:
		if s.get("always"):
			var l = s.lines[nm]
			return l.pick_random() if l is Array else l
	if not fits.is_empty() and randf() < 0.55:
		var l = fits.pick_random().lines[nm]
		return l.pick_random() if l is Array else l
	return talk.greet[tier]


static func _chat(npc) -> void:
	var tier := relation_tier(npc.relation)
	# 지금 단계까지 열린 이야기 중 하나
	var pool := []
	for t in _talk().NPC_TALK[npc.config.name].topics.slice(0, tier + 1):
		if t is Array: pool.append_array(t)
		else: pool.append(t)
	if npc.last_talk_day != GameState.day:   # 하루 첫 대화는 호감이 조금 오른다
		npc.last_talk_day = GameState.day
		add_relation(npc, 3)
	show(npc, pool.pick_random(), [{ label = "그렇구나.", on_select = func(): open_hub(npc) }])


static func _give_gift(npc) -> void:
	GameState.player.inventory.meat -= 1
	npc.last_gift_day = GameState.day
	add_relation(npc, 8)
	Particles.burst(npc.x, npc.y - 60, "#ff7aa8", 1, 10)
	Hud.pop("%s에게 고기를 선물했습니다. (호감 ↑)" % Names.npc(npc.config.name), "🎁")
	show(npc, "이걸 나한테? 고마워. 잘 먹을게.", [{ label = "별말씀을.", on_select = func(): open_hub(npc) }])


static func _receive_present(npc) -> void:
	npc.last_present_day = GameState.day
	var gold := 15 + relation_tier(npc.relation) * 10
	GameState.player.gold += gold
	GameState.player.inventory.meat += 1
	Hud.pop("%s의 선물: %dG, 고기 1개" % [Names.npc(npc.config.name), gold], "🎁")
	show(npc, "오다가 주웠는데 너 주려고 가져왔어. 별건 아니야.", [{ label = "고마워!", on_select = func(): open_hub(npc) }])


## 아이와 놀아 준다. 아이의 호감이 오르고, 그 부모도 조금 좋아한다
static func _kid_play(npc, kp: Dictionary, kind: String) -> void:
	if kind == "ride": npc.last_ride_day = GameState.day
	play_lines(npc, kp[kind], func():
		add_relation(npc, 8 if kind == "ride" else 4)
		for pn in kp.parents:
			var par = World.any_npc(pn)
			if par: add_relation(par, 3)
		for i in 3: Vfx.spawn_effect("HEART", npc.x + Util.rand_range(-30, 30), npc.y - 50 - Util.rand_range(0, 30), { color = "#ffd07a", size = 1 })
		Hud.pop("%s와(과) 놀아 줬다. %s의 호감도 조금 올랐다." % [Names.npc(npc.config.name), "·".join(kp.parents.map(Names.npc))], "🐉")
		Sfx.play("quest"))


## 여러 줄짜리 장면을 차례로 보여 주고 끝나면 then
static func play_lines(npc, lines: Array, then = null) -> void:
	var i := [0]
	var step := []
	step.append(func():
		if i[0] >= lines.size():
			close()
			if then: then.call()
			return
		var line: String = lines[i[0]]
		i[0] += 1
		show(npc, line, [{ label = "▶ 다음" if i[0] < lines.size() else "▶", on_select = step[0] }]))
	step[0].call()


static func _go_on_date(npc) -> void:
	close()
	npc.last_date_day = GameState.day
	var lines: Array = _talk().DATES[npc.config.name][npc.dates]
	Hud.fade_screen("♥", func(): GameState.dayTime = minf(0.78, GameState.dayTime + 0.12), func(): play_lines(npc, lines, func():
		npc.dates += 1
		add_relation(npc, 12)
		Romance.on_date(npc)   # 다른 용이 봤을 수도 있다
		Vfx.spawn_effect("HEART", npc.x, npc.y - 80, { color = "#ff7aa8", size = 1.4 })
		Hud.pop("%s와(과) 데이트했습니다. (%d/3, 호감 ↑)" % [Names.npc(npc.config.name), npc.dates], "💕")))


static func _confess(npc) -> void:
	var hub := func(): open_hub(npc)
	if GameState.player.stage_index < 2:
		show(npc, "(아직 너무 어리다. [성체]가 되면 마음을 전하자.)", [{ label = "조금만 더 크자.", on_select = hub }])
		return
	# 지금 짝과의 일을 먼저 매듭지어야 한다
	if GameState.partner and GameState.partner != npc:
		show(npc, "(지금은 %s(이)가 짝이다. 이 말을 꺼내려면 그쪽과의 일을 먼저 매듭지어야 한다.)" % Names.npc(GameState.partner.config.name), [{ label = "…그래.", on_select = hub }])
		return
	play_lines(npc, _talk().CONFESSION[npc.config.name], func():
		if GameState.partner: GameState.partner.state = "WANDER"
		if GameState.companion == npc: GameState.companion = null
		GameState.partner = npc
		npc.state = "PARTNER_FOLLOW"
		Romance.on_partnered(npc)
		for i in 6: Vfx.spawn_effect("HEART", npc.x + Util.rand_range(-60, 60), npc.y - 60 - Util.rand_range(0, 60), { color = "#ff7aa8", size = 1.2 })
		Hud.pop("%s(이)가 짝이 되었습니다! 이제 아지트에서 함께 삽니다." % Names.npc(npc.config.name), "💞"))


static func _family_talk(npc) -> void:
	var nests: Array = GameState.entities.nests
	var nest = nests[0] if not nests.is_empty() else null
	var back := [{ label = "그래.", on_select = func(): open_hub(npc) }]
	if not GameState.den.get("built"):
		show(npc, "아직 둥지가 없잖아. 아지트에 둥지부터 짓자. (둥지에서 [T]. 나뭇가지 8, 30G)", back)
		return
	# 둥지는 내 굴 안에만 있다 (밖에서는 GameState.denNest 에 상태만 들고 다닌다)
	if not nest:
		show(npc, "여기선 좀… 우리 굴로 가자. 둥지가 있어야지.", back)
		return
	if nest.has_egg:
		show(npc, "둥지에 이미 알이 있어. 저 아이부터 잘 품어 주자.", back)
		return
	if GameState.kids.size() >= Data.get_module("core_config").MAX_KIDS:
		show(npc, "우리 집, 이미 북적북적해. 이 아이들부터 잘 키우자.", back)
		return
	if npc.last_egg_day and GameState.day - npc.last_egg_day < 7:
		show(npc, "조금만 더 있다가. 몸을 추슬러야 해. (이레에 한 번. %d일 뒤)" % (7 - (GameState.day - npc.last_egg_day)), back)
		return
	play_lines(npc, _talk().FAMILY_TALK[npc.config.name], func():
		npc.last_egg_day = GameState.day
		nest.lay_egg(GameState.player, npc)
		Vfx.spawn_effect("RING", nest.x, nest.y, { size = 1.4 })
		Hud.pop("%s(이)가 둥지에 알을 낳았습니다! 곁에서 품어 주세요." % Names.npc(npc.config.name), "🥚"))


## 주워 온 알을 촌장에게 맡긴다. 사흘 뒤 아침에 촌장이 아기를 데려온다 (Story)
static func _entrust_egg(npc) -> void:
	var back := [{ label = "그래.", on_select = func(): open_hub(npc) }]
	if GameState.eggSitting:
		show(npc, "이미 하나 품고 있잖느냐. 저 아이가 깨어난 뒤에 오거라.", back)
		return
	if GameState.kids.size() >= Data.get_module("core_config").MAX_KIDS:
		show(npc, "네 집이 이미 북적북적하다. 그 아이들부터 잘 키우고 오거라.", back)
		return
	GameState.player.carrying = null
	GameState.eggSitting = { day = GameState.day, genes = Kids.mix_genes(GameState.player, GameState.partner) }
	play_lines(npc, [
		"알이구나. 어디서 주워 왔느냐.",
		"네 몸으로는 아직 못 품는다. 알은 품는 이의 체온을 따라가거든.",
		"내가 맡으마. 사흘이면 깨어날 게다. 그때 데려다주지.",
	], func():
		Vfx.spawn_effect("RING", npc.x, npc.y, { size = 1.2 })
		Hud.pop("엘더에게 알을 맡겼습니다. 사흘 뒤 아침에 데려옵니다.", "🥚"))


## 짝을 데리고 다닐지 정한다. 짝인 것은 그대로고 따라다니기만 끈다
static func _set_following(npc, on: bool) -> void:
	close()
	npc.state = "PARTNER_FOLLOW" if on else "WANDER"
	if on: Hud.pop("%s(이)가 다시 따라나섭니다." % Names.npc(npc.config.name), "🤝")
	else: Hud.pop("%s(이)가 마을에 남습니다. 다시 부르려면 말을 거세요." % Names.npc(npc.config.name), "👋")


static func _set_companion(npc, join: bool) -> void:
	if join:
		if GameState.companion: GameState.companion.state = "WANDER"
		GameState.companion = npc
		npc.state = "COMPANION_FOLLOW"
		Hud.pop("%s(이)가 동료로 합류했습니다!" % Names.npc(npc.config.name), "🤝")
	else:
		GameState.companion = null
		npc.state = "WANDER"
		Hud.pop("%s(이)가 마을로 돌아갑니다." % Names.npc(npc.config.name), "👋")
	close()


# ---------- 엘더: 축복 ----------

static func _blessing(npc) -> void:
	if GameState.blessingDay == GameState.day:
		show(npc, "축복은 하루에 한 번이다. 욕심내지 말거라.", [{ label = "네…", on_select = func(): open_hub(npc) }])
		return
	GameState.blessingDay = GameState.day
	var p = GameState.player
	p.hp = p.max_hp
	p.hunger = 100.0
	Vfx.spawn_effect("RING", p.x, p.y - 40, { size = 2 })
	Hud.pop("엘더의 축복: 오늘 하루 경험치 +25%, 체력·허기 회복", "✨")
	show(npc, "고대의 바람이 네 날개를 밀어 주기를.", [{ label = "감사합니다.", on_select = close }])


# ---------- 그론: 대장간 ----------
# 잡은 것에서 나온 소재를 모아 직접 두드린다. 골드는 고기와, 급할 때 소재를 비싸게 사는 데만 쓴다.

static func _mat_line() -> String:
	return " · ".join(Forge.mats().keys().map(func(k): return "%s %d" % [Forge.mats()[k].name, Forge.mat_count(k)]))


## 그론이 떠난 뒤의 대장간. 사흘은 불이 안 붙고, 다시 붙는 날 그론이 만들다 만 것을 엠버가 내민다
static func _ember_forge(npc) -> void:
	var death_day: int = GameState.story.get("deathDay", {}).get("Gron", GameState.day)
	if GameState.day - death_day < 3:
		show(npc, "…부싯돌은 멀쩡한데 불이 안 붙어. 미안한데 며칠만 있다가 다시 와 줄래.", [{ label = "기다릴게.", on_select = func(): open_hub(npc) }])
		return
	if Relics.owns("GRON_PLATE"):
		_open_forge(npc)
		return
	Chronicle.play_scene("그론이 만들다 만 것", [
		{ who = "Ember", text = "왔어? 봐 봐, 오늘 아침에 드디어 불이 붙었어. 아저씨가 하던 대로 풀무를 세 번 밟고 한 번 쉬었더니 붙더라." },
		{ who = "Ember", text = "그리고 이건 아저씨가 너 주려고 만들던 거야. 화덕 옆에 진짜로 반쯤 된 채로 놓여 있더라." },
		{ who = "Ember", text = "나머지 반은 내가 마저 했어. 이음매가 좀 삐뚤어서 아저씨가 봤으면 다시 하라고 했을 텐데… 그래도 받아 줘." },
		{ who = "나", text = "(가슴에 대 보니 딱 맞는다. 한 달 전 몸집이 아니라, 지금 몸집에.)" },
		{ who = "Ember", text = "아저씨 그 양반, 네가 얼마나 클지까지 재 놨더라. 무서운 영감탱이." },
	], func(): Relics.grant("GRON_PLATE", GameState.player.x, GameState.player.y))


static func _open_forge(npc) -> void:
	var opts: Array = Forge.recipes().map(func(r):
		var cost := Forge.cost_of(r)
		var times: int = GameState.upgrades.get(r.id, 0)
		if r.get("max") and times >= r.max:
			return { label = "✔ %s (%d단, 더는 두드릴 데가 없다)" % [r.name, times], on_select = func(): _open_forge(npc) }
		var ok := Forge.can_afford(cost)
		return { label = "%s %s (%d단 → %d단) %s" % ["🔨" if ok else "🔒", r.name, times, times + 1, r.effect], on_select = func(): _forge_one(npc, r) })
	opts.append({ label = "💰 골드로 산다 (소지금 %dG)" % GameState.player.gold, on_select = func(): _open_goods(npc) })
	opts.append({ label = "돌아간다", on_select = func(): open_hub(npc) })
	var line := "불은 피워 놨으니까 재료만 가져와. 아저씨만큼은 못 해도 내가 해 볼게." if npc.config.name == "Ember" else "모루는 달궈 뒀다. 재료는 네가 가져와라."
	show(npc, "%s\n\n[가진 소재] %s" % [line, _mat_line()], opts)


static func _forge_one(npc, recipe: Dictionary) -> void:
	var cost := Forge.cost_of(recipe)
	if not Forge.can_afford(cost):
		show(npc, "재료가 모자라다. %s에는 이만큼 든다.\n\n%s\n\n(앞의 숫자가 가진 것, 뒤가 드는 것이다)" % [recipe.name, Forge.cost_text(cost)],
			[{ label = "모아 오겠다", on_select = func(): _open_forge(npc) }])
		return
	show(npc, "%s\n\n드는 재료: %s" % [recipe.flavor, Forge.cost_text(cost)], [
		{ label = "🔨 두드린다: %s" % recipe.effect, on_select = func():
			Forge.forge(recipe)
			_open_forge(npc) },
		{ label = "아직 아껴 두겠다", on_select = func(): _open_forge(npc) },
	])


static func _open_goods(npc) -> void:
	var opts: Array = Forge.goods().map(func(item): return { label = "%s: %s (%dG)" % [item.name, item.desc, item.cost], on_select = func():
		Forge.buy(item)
		_open_goods(npc) })
	opts.append({ label = "돌아간다", on_select = func(): _open_forge(npc) })
	show(npc, "돈으로 사겠다면 말리진 않는다. 비싸게 받을 뿐이지. (소지금 %dG)" % GameState.player.gold, opts)


# ---------- 티아맷: 대련 ----------
# 대련은 마을 한복판에서 느닷없이 시작되지 않는다. 수련장으로 자리를 옮겨 붙는다

static func _start_spar(npc) -> void:
	close()
	if GameState.map_id != "DOJO":
		show(npc, "여기서? 광장 한복판에서 번개를 쏘면 촌장님한테 둘 다 혼나. 수련장으로 가자.", [
			{ label = "⚔️ 수련장으로 간다", on_select = func():
				close()
				_go_spar(npc) },
			{ label = "다음에 하자", on_select = close },
		])
		return
	_begin_spar(npc)


## 티아맷과 함께 수련장으로 옮겨 가서 붙는다
static func _go_spar(npc) -> void:
	Hud.fade_screen("수련장으로", func():
		World.travel_to("DOJO")
		var spot: Vector2 = GameState.dojoSpot if GameState.dojoSpot else Vector2(GameState.player.x, GameState.player.y)
		GameState.player.x = spot.x - 120; GameState.player.y = spot.y + 40
		npc.x = spot.x + 140; npc.y = spot.y + 40
		npc.remove = false; npc.is_hidden = false; npc.walk_to = null
		if not GameState.entities.npcs.has(npc): World.add_entity("npcs", npc), func(): _begin_spar(npc))


static func _begin_spar(npc) -> void:
	GameState.activity = { type = "SPAR", npc = npc, hp = SPAR_HP, max = SPAR_HP, timer = 1.5 }
	npc.say("봐주지 않는다!")
	Hud.pop("대련 시작! 티아맷의 기력을 모두 깎으세요. (체력 25% 아래로 떨어지면 패배)", "⚔️")


# ---------- 포코: 술래잡기 ----------

static func _start_tag(npc) -> void:
	close()
	GameState.activity = { type = "TAG", npc = npc, time = TAG_TIME, max = TAG_TIME, juke = 0.0, jukeAngle = 0.0 }
	npc.say("나 잡아 봐라~!")
	Hud.pop("술래잡기! %d초 안에 %s를 잡으세요. (Shift 달리기)" % [TAG_TIME, Names.npc(npc.config.name)], "🏃")


static func _end_activity(win: bool) -> void:
	var a: Dictionary = GameState.activity
	var npc = a.npc
	var p = GameState.player
	GameState.activity = null
	Hud.current.set_boss_bar(null)
	var first: bool = npc.last_play_day != GameState.day   # 보상은 하루 첫 판이 크다
	npc.last_play_day = GameState.day
	var kp = _talk().KID_NPC_PLAY.get(npc.config.name)
	if a.type == "SPAR":
		if win:
			add_relation(npc, 10 if first else 2)
			p.gold += 40 if first else 10
			p.gain_xp(180 if first else 50)
			npc.say("졌다. 인정할게.")
			Hud.pop("대련 승리!" + (" (40G, 호감 ↑)" if first else " (10G)"), "🏆")
			Quests.notify("spar")
			Skills.learn("BLINK")   # 첫 승리 때 티아맷의 기술을 배운다
		else:
			p.hp = maxf(p.hp, p.max_hp * 0.5)
			add_relation(npc, 1)
			npc.say("아직 멀었어. 다시 와.")
			Hud.pop("대련 패배… 티아맷이 일으켜 세워 줍니다.", "💫")
	elif win:
		add_relation(npc, 8 if first else 2)
		p.gold += 25 if first else 5
		npc.say(kp.tagWin if kp else "으악 잡혔다! 한 판 더!")
		Hud.pop("%s를 잡았습니다!" % Names.npc(npc.config.name) + (" (25G, 호감 ↑)" if first else " (5G)"), "🎉")
		if kp:
			for pn in kp.parents:
				var par = World.any_npc(pn)
				if par: add_relation(par, 2)
		Quests.notify("tag")
	else:
		npc.say(kp.tagLose if kp else "헤헤, 내가 이겼다!")
		Hud.pop("시간 초과! %s가 도망쳤습니다." % Names.npc(npc.config.name), "⏱️")


## 놀이 중인 NPC의 움직임. Dragon 의 _update_npc 가 부른다
static func update_activity_npc(npc, dt: float) -> void:
	if Story.is_drill(GameState.activity):
		Story.update_drill(npc, dt)
		return
	var a: Dictionary = GameState.activity
	var p = GameState.player
	var d := Util.dist(npc, p)
	var to_player := atan2(p.y - npc.y, p.x - npc.x)

	if a.type == "SPAR":
		Hud.current.set_boss_bar("티아맷과 대련", a.hp / a.max)
		var move := to_player if d > 300 else to_player + PI if d < 180 else to_player + PI / 2
		npc.move_by(cos(move), sin(move), 170, dt)
		a.timer -= dt
		if a.timer <= 0:
			a.timer = 0.95
			for off in ([-0.25, 0.0, 0.25] if a.hp < a.max / 2 else [0.0]):
				Projectile.add(Projectile.new(npc.x, npc.y - 40, atan2(p.y - 30 - (npc.y - 40), p.x - npc.x) + off,
					{ faction = "ENEMY", element = "THUNDER", damage = 6, speed = 330, life = 2.2, scale = 0.7 }))
			npc.animator.play("attack")
		if a.hp <= 0: _end_activity(true)
		elif p.hp < p.max_hp * 0.25 or d > 1100: _end_activity(false)
		return

	# TAG: 플레이어 반대쪽으로, 가끔 방향을 꺾고, 집에서 너무 멀어지면 돌아온다
	Hud.current.set_boss_bar("포코와 술래잡기", a.time / a.max)
	a.time -= dt
	a.juke -= dt
	if a.juke <= 0:
		a.juke = Util.rand_range(0.5, 1.2)
		a.jukeAngle = Util.rand_range(-1.2, 1.2)
	var vx := cos(to_player + PI + a.jukeAngle)
	var vy := sin(to_player + PI + a.jukeAngle)
	var home := Vector2(npc.home_x, npc.home_y)
	var dh := Vector2(npc.x, npc.y).distance_to(home)
	if dh > 420:
		vx += ((home.x - npc.x) / dh) * 1.6
		vy += ((home.y - npc.y) / dh) * 1.6
	npc.move_by(vx, vy, 335, dt)
	if d < 75: _end_activity(true)
	elif a.time <= 0: _end_activity(false)
