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


## 호감도를 올린다. 단계가 올라가면 그 인물의 장면을 하나 예약한다 (지금 대화가 끝난 뒤 Chronicle 이 꺼내 준다).
## 호감을 올리는 곳은 모두 여기를 거친다. 그래도 단계를 건너뛴 적이 있으면 못 본 장면은 다음에 호감이 오를 때 꺼낸다
static func add_relation(npc, amount: float) -> void:
	npc.relation = clampf(npc.relation + amount, 0, 100)
	if amount > 0: _book_bond(npc)


## 지금 단계까지 열렸는데 아직 못 본 장면을 아래 단계부터 하나 예약한다. 기다리는 장면이 있으면 다음 기회에
## (예약은 한 자리뿐이라, 습격을 막고 여럿이 한꺼번에 단계를 넘으면 하나만 남고 나머지는 영영 사라졌다)
static func _book_bond(npc) -> void:
	if GameState.pendingBond: return
	var nm: String = npc.config.name
	# 장면 표는 단계("1"~"3")를 열쇠로 쓴다 (배열로 읽어서 서른 장면이 하나도 안 나오던 것)
	var scenes = _talk().BOND_SCENES.get(nm)
	if not scenes: return
	if not GameState.story.get("bonds"): GameState.story.bonds = []
	for tier in range(1, relation_tier(npc.relation) + 1):
		var key := "%s:%d" % [nm, tier]
		if not scenes.get(str(tier)) or GameState.story.bonds.has(key): continue
		GameState.story.bonds.append(key)
		GameState.pendingBond = { name = nm, tier = tier }
		return


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
	if Den.in_my_den(): text = Den.home_greeting(npc, text)
	elif npc.doing: text = "(%s.)\n\n%s" % ["자다가 부스스 눈을 뜬다" if _asleep(npc) else npc.doing, text]   # 코를 골던 용이 곧바로 멀쩡히 인사하지 않게
	if running:   # 힌트가 있으면 힌트로 ('그 자리에 가 있기 0/1' 처럼 어디인지 없는 목표 글 대신). 숫자는 셀 게 여럿일 때만
		var total := Quests.step_total(running)
		text += "\n\n(%s: %s%s)" % [running.title, Quests._hint_or_goal(running), " %d/%d" % [Quests.progress(running), total] if total > 1 else ""]
	elif not skip_errand and Quests.rest_offer(npc): text += "\n\n(할 이야기가 더 있는 눈치지만, 오늘은 그만 쉬고 내일 아침에 보자는 듯하다.)"
	elif not skip_errand and Quests.held_offer(npc): text += "\n\n(부탁할 일이 있는 눈치지만, 지금 맡은 일부터 끝내고 오라는 듯하다.)"
	show(npc, text, opts)
	return true


## 지금 자는 칸인가 (data/routines.json 에서 sleep 이 붙은 칸). 하던 일(doing) 글로 그 칸을 찾는다
static func _asleep(npc) -> bool:
	var r = Routine.routines().get(npc.config.name)
	if not r or not npc.doing: return false
	var days: Array = [r.day] + r.get("variants", []).map(func(v): return v.day)
	if r.get("after"): days.append(r.after.day)
	for d in days:
		for s in d:
			if s.get("sleep") and s.doing == npc.doing: return true
	return false


## NPC 고유 행동 묶음. 없으면 null
static func _own_menu(npc, nm: String):
	var back := func(): open_hub(npc)
	var sub := []
	# 촌장의 축복 · 스승의 가르침. 짝이 아니면 이것 하나뿐이고, 짝이면 아래의 동행 · 나들이와 한데 묶는다
	# (여기서 곧장 돌려주던 탓에 엘더나 카이론이 짝이면 동행 · 나들이 메뉴가 아예 없었다)
	var own = null
	if nm == "Elder": own = { label = "✨ 축복을 청한다", on_select = func(): _blessing(npc) }
	if nm == "Kairon": own = { label = "🎓 가르침을 청한다", on_select = func(): show(npc, "뭘 배우러 왔냐.", Story.master_options(npc) + [{ label = "돌아간다", on_select = back }]) }
	if own and npc != GameState.partner: return own
	if own: sub.append(own)
	if nm == "Tiamat": sub.append({ label = "⚔️ 대련을 신청한다", on_select = func(): _start_spar(npc) })
	if nm == "Poco": sub.append({ label = "🎾 술래잡기하자!", on_select = func(): _start_tag(npc) })
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
			sub.append({ label = "🎾 술래잡기하자!", on_select = func(): _start_tag(npc) })
	if nm == "Gron": sub.append({ label = "🔨 모루 앞에 선다", on_select = func(): _open_forge(npc) })
	if nm == "Ember" and Routine.is_dead("Gron"): sub.append({ label = "🔨 모루 앞에 선다", on_select = func(): _ember_forge(npc) })
	# 동행. 짝도 오늘은 혼자 다녀오겠다고 할 수 있다. 토라진 짝은 사과가 먼저다 (마음 메뉴).
	# 고른 칸은 하나다: 짝이 따라오면 그 자리, 아니면 고른 동료. 이야기가 데려가는 동료는 따로
	var stay := Party.stays_home(npc)
	if Party.is_story(npc):
		sub.append({ label = "(이 일이 끝날 때까지 함께 간다)", on_select = back })
	elif npc == GameState.partner and Romance.is_sulking(npc):
		pass
	elif npc == GameState.partner:
		if npc.state == "WANDER" and Party.went_home(npc): sub.append({ label = "(오늘은 쓰러져서 쉬어야 한다. 내일 다시 청하자)", on_select = back })
		elif npc.state == "WANDER" and stay != "": sub.append({ label = "🤝 같이 가자", on_select = func(): show(npc, stay, [{ label = "(고개를 끄덕인다)", on_select = back }]) })
		elif npc.state == "WANDER": sub.append({ label = "🤝 같이 가자", on_select = func(): _set_following(npc, true) })
		else: sub.append({ label = "👋 여기서 기다려 줄래?", on_select = func(): _set_following(npc, false) })
		# 가족 나들이: 짝이 곁에 있고 아이가 있을 때, 사흘에 한 번
		if Family.can_outing(): sub.append({ label = "🧺 다 같이 호숫가로 나들이를 간다", on_select = func():
			close()
			Family.go_outing() })
		elif GameState.kids.size() > 0 and Family.outing_wait() > 0: sub.append({ label = "(나들이는 %d일 뒤에 또 갈 수 있다)" % Family.outing_wait(), on_select = back })
	elif GameState.companion == npc:
		sub.append({ label = "이제 마을로 돌아가도 돼", on_select = func(): _set_companion(npc, false) })
	elif Party.went_home(npc):
		sub.append({ label = "(오늘은 쓰러져서 쉬어야 한다. 내일 다시 청하자)", on_select = back })
	elif Party.can_pick(npc):
		sub.append({ label = "🤝 같이 모험을 떠나자 (%s)" % Party.role(npc).get("name", ""), on_select = func(): _set_companion(npc, true) })
	elif not Party.member(nm).is_empty() and not Routine.is_dead(nm) and stay == "" and not Party.away(npc):
		sub.append({ label = "(같이 먼 길을 가자고 하기엔 아직 서먹하다. 호감 %d/%d)" % [floori(npc.relation), Party.join_at(nm)], on_select = back })
	if sub.is_empty(): return null
	if sub.size() == 1: return sub[0]
	return { label = "🤝 함께하자고 한다", on_select = func(): show(npc, "(무엇을 함께할까.)", sub + [{ label = "돌아간다", on_select = back }]) }


## 잡담·선물 묶음
static func _talk_menu(npc) -> void:
	var p = GameState.player
	var sub := [{ label = "💬 안부를 묻는다", on_select = func(): _chat(npc) }]
	if p.inventory.meat > 0 and npc.last_gift_day != GameState.day:
		sub.append({ label = "🎁 고기를 선물한다 (고기 -1)", on_select = func(): _give_gift(npc) })
	if relation_tier(npc.relation) >= 2 and npc.last_present_day != GameState.day:
		sub.append({ label = "(뭔가 주려는 눈치다)", on_select = func(): _receive_present(npc) })
	sub.append({ label = "돌아간다", on_select = func(): open_hub(npc) })
	if sub.size() == 2:   # 잡담밖에 없으면 바로 잡담
		_chat(npc)
		return
	show(npc, "(무슨 얘기를 꺼낼까.)", sub)


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
		if npc.last_date_day == GameState.day: sub.append({ label = "(오늘은 이미 데이트했다. 데이트 %d/3)" % dates, on_select = hub })
		else: sub.append({ label = "♥ 데이트를 신청한다 (%d/3)" % dates, on_select = func(): _go_on_date(npc) })
	elif dates >= 3:
		sub.append({ label = "(마음은 통한 것 같다. 조금 더 가까워지면 고백할 수 있겠다.)", on_select = hub })
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
		{ label = "지금은 사양한다", on_select = close },
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
	Party.sync()   # 말을 걸어 넘긴 대목이 이야기 동료를 데려갈 수 있다 (4장 티아맷)
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
		{ label = "아직 건네지 않는다", on_select = close },
	])


## 끝낸 일을 보고한다. 마무리에 고를 것이 있으면 그것부터 묻는다.
## 마무리 장면(고른 것에 딸린 장면 → 퀘스트를 닫는 장면)이 먼저 흐르고, 다음 부탁은 그 뒤에 꺼낸다
## (다음 부탁을 먼저 듣고 나서 앞 이야기의 결말이 나오던 것). 이야기의 끝(결말)은 Ending 이 받는다
static func _report_quest(npc, q: Dictionary) -> void:
	var finish := func(choice_id):
		close()
		var big := Quests.turn_in(q, npc, choice_id)
		if Ending.takes_over(q): return
		_play_queued(func():
			Save.save_game()
			if big: return   # 큰 대목을 마친 자리에서는 다음 부탁을 꺼내지 않는다. 그날은 생활할 틈이다 (Quests.resting)
			var nxt = Quests.offer_for(npc)
			if nxt and is_instance_valid(npc): _hear_quest(npc, nxt))
	if not q.get("choice"):
		show(npc, q.done, [{ label = "보상을 받는다 (%s)" % q.title, on_select = func(): finish.call(null) }])
		return
	# 마무리는 한 화면에서. 보고를 받은 말 아래에 고를 것을 바로 붙인다
	show(npc, "%s\n\n%s" % [q.done, q.choice.prompt], q.choice.options.map(func(o): return { label = o.label, on_select = func(): finish.call(o.id) }))


## 대기줄에 쌓인 장면을 이 자리에서 차례로 튼다. 다 틀면 then
static func _play_queued(then: Callable) -> void:
	var qs = Quests.take_scene()
	if qs == null:
		then.call()
		return
	Chronicle.play_scene(qs.title, qs.lines, func(): _play_queued(then), true, qs.get("place"))


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
	return _retold(npc, talk.greet[tier])


## 이야기가 흘러간 뒤 맞지 않게 된 줄은 바꿔 말한다. NPC_TALK[이름] 의 { 원래 줄: 그 뒤에 할 말 }:
## afterGron — 그론이 떠난 뒤 (그가 살아 있는 듯한 말) · afterDark — 어둠의 길 끝에 (교화의 길 기준인 말)
static func _retold(npc, line: String) -> String:
	var t: Dictionary = _talk().NPC_TALK[npc.config.name]
	if GameState.story.get("route") == "dark" and GameState.quests.done.has("m7d"): line = t.get("afterDark", {}).get(line, line)
	if Routine.is_dead("Gron"): line = t.get("afterGron", {}).get(line, line)
	return line


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
	show(npc, _retold(npc, pool.pick_random()), [{ label = "그렇구나.", on_select = func(): open_hub(npc) }])


static func _give_gift(npc) -> void:
	GameState.player.inventory.meat -= 1
	npc.last_gift_day = GameState.day
	add_relation(npc, 8)
	Particles.burst(npc.x, npc.y - 60, "#ff7aa8", 1, 10)
	Hud.pop("%s에게 고기를 선물했습니다. (호감 ↑)" % Names.npc(npc.config.name), "🎁")
	var said = _talk().NPC_TALK.get(npc.config.name, {}).get("gift")   # 받는 말은 용마다 (data/npcTalk.json 의 gift)
	show(npc, _retold(npc, said.pick_random()) if said else "이걸 나한테? 고마워. 잘 먹을게.", [{ label = "(고개를 끄덕인다)", on_select = func(): open_hub(npc) }])


static func _receive_present(npc) -> void:
	npc.last_present_day = GameState.day
	var gold := 15 + relation_tier(npc.relation) * 10
	GameState.player.gold += gold
	GameState.player.inventory.meat += 1
	Hud.pop("%s의 선물: %dG, 고기 1개" % [Names.npc(npc.config.name), gold], "🎁")
	var said = _talk().NPC_TALK.get(npc.config.name, {}).get("present")   # 건네는 말도 용마다 (present)
	show(npc, _retold(npc, said.pick_random()) if said else "오다가 주웠는데 너 주려고 가져왔어. 별건 아니야.", [{ label = "고맙다고 한다", on_select = func(): open_hub(npc) }])


## 아이와 놀아 준다. 아이의 호감이 오르고, 그 부모도 조금 좋아한다
static func _kid_play(npc, kp: Dictionary, kind: String) -> void:
	if kind == "ride": npc.last_ride_day = GameState.day
	play_lines(npc, kp[kind], func():
		add_relation(npc, 8 if kind == "ride" else 4)
		for pn in kp.parents:
			var par = World.any_npc(pn)
			if par: add_relation(par, 3)
		for i in 3: Vfx.spawn_effect("HEART", npc.x + Util.rand_range(-30, 30), npc.y - 50 - Util.rand_range(0, 30), { color = "#ffd07a", size = 1 })
		Hud.pop("%s하고 놀아 줬다. %s의 호감이 조금 올랐다." % [Names.npc(npc.config.name), "·".join(kp.parents.map(Names.npc))], "🐉")
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
		Hud.pop("%s하고 데이트했습니다. (%d/3, 호감 ↑)" % [Names.npc(npc.config.name), npc.dates], "💕")))


static func _confess(npc) -> void:
	var hub := func(): open_hub(npc)
	if GameState.player.stage_index < 2:
		show(npc, "(아직 너무 어리다. [성체]가 되면 마음을 전하자.)", [{ label = "조금만 더 크자.", on_select = hub }])
		return
	# 지금 짝과의 일을 먼저 매듭지어야 한다
	if GameState.partner and GameState.partner != npc:
		show(npc, "(지금은 %s 짝이다. 이 말을 꺼내려면 그쪽과의 일을 먼저 매듭지어야 한다.)" % Util.josa(Names.npc(GameState.partner.config.name), "이", "가"), [{ label = "…그래.", on_select = hub }])
		return
	play_lines(npc, _talk().CONFESSION[npc.config.name], func():
		if GameState.partner: GameState.partner.state = "WANDER"
		if GameState.companion == npc: GameState.companion = null
		Party.take_slot(npc)   # 새 짝이 고른 칸에 선다. 따라오던 다른 동료는 돌아간다
		GameState.partner = npc
		npc.state = "PARTNER_FOLLOW"
		Romance.on_partnered(npc)
		for i in 6: Vfx.spawn_effect("HEART", npc.x + Util.rand_range(-60, 60), npc.y - 60 - Util.rand_range(0, 60), { color = "#ff7aa8", size = 1.2 })
		Hud.pop("%s 짝이 되었습니다! 이제 내 굴에서 함께 삽니다." % Util.josa(Names.npc(npc.config.name), "이", "가"), "💞"))


static func _family_talk(npc) -> void:
	var nests: Array = GameState.entities.nests
	var nest = nests[0] if not nests.is_empty() else null
	var back := [{ label = "그래.", on_select = func(): open_hub(npc) }]
	if not GameState.den.get("built"):
		show(npc, "아직 둥지가 없잖아. 굴에 둥지부터 짓자. (내 굴 잠자리 앞에서 [E]. 나뭇가지 8개, 30G)", back)
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
		show(npc, "조금만 더 있다가. 몸을 추슬러야 해. (알은 7일에 한 번. %d일 뒤에 다시)" % (7 - (GameState.day - npc.last_egg_day)), back)
		return
	play_lines(npc, _talk().FAMILY_TALK[npc.config.name], func():
		npc.last_egg_day = GameState.day
		nest.lay_egg(GameState.player, npc)
		Vfx.spawn_effect("RING", nest.x, nest.y, { size = 1.4 })
		Hud.pop("%s 둥지에 알을 낳았습니다! 곁에서 품어 주세요." % Util.josa(Names.npc(npc.config.name), "이", "가"), "🥚"))


## 주워 온 알을 촌장에게 맡긴다. 사흘 뒤 아침에 촌장이 아기를 데려온다 (Story)
static func _entrust_egg(npc) -> void:
	var back := [{ label = "그래.", on_select = func(): open_hub(npc) }]
	if GameState.eggSitting:
		show(npc, "이미 하나 품고 있잖느냐. 저 아이가 깨어난 뒤에 오거라.", back)
		return
	if GameState.kids.size() >= Data.get_module("core_config").MAX_KIDS:
		show(npc, "네 집이 이미 북적북적하구나. 그 아이들부터 잘 키우고 오거라.", back)
		return
	GameState.player.carrying = null
	GameState.eggSitting = { day = GameState.day, genes = Kids.mix_genes(GameState.player, GameState.partner) }
	# 성체부터는 제 둥지에서 품을 수 있다 (Dragon._put_egg_in_nest). 그 뒤로는 '아직 어렵다'고 하지 않는다
	var grown: bool = GameState.player.stage_index >= 2
	play_lines(npc, [
		"알이구나. 어디서 주워 왔느냐.",
		"이제 네 몸으로도 품을 수 있을 텐데… 그래도 이 늙은이한테 맡기겠다면야, 허허." if grown else "네 몸으로는 아직 품기 어렵단다. 알은 품는 이의 체온을 닮아 가거든…",
		"내가 맡으마. 사흘이면 깰 게야. 그때 데려다주마.",
	], func():
		Vfx.spawn_effect("RING", npc.x, npc.y, { size = 1.2 })
		Hud.pop("엘더에게 알을 맡겼습니다. 사흘 뒤 아침, 깨어난 아기를 엘더가 데려옵니다.", "🥚"))


## 짝을 데리고 다닐지 정한다. 짝인 것은 그대로고 따라다니기만 끈다
static func _set_following(npc, on: bool) -> void:
	close()
	if on: Party.take_slot(npc)   # 고른 칸은 하나: 따라오던 동료는 돌아간다
	npc.state = "PARTNER_FOLLOW" if on else "WANDER"
	if on: Hud.pop("%s 다시 따라나섭니다." % Util.josa(Names.npc(npc.config.name), "이", "가"), "🤝")
	else: Hud.pop("%s 마을에 남습니다. 다시 부르려면 말을 거세요." % Util.josa(Names.npc(npc.config.name), "이", "가"), "👋")


static func _set_companion(npc, join: bool) -> void:
	if join:
		Party.take_slot(npc)   # 고른 칸은 하나: 먼저 따라오던 동료는 돌아가고, 따라오던 짝은 마을에서 기다린다
		GameState.companion = npc
		npc.state = "COMPANION_FOLLOW"
		Hud.pop("%s 동료로 합류했습니다!%s" % [Util.josa(Names.npc(npc.config.name), "이", "가"), Party.role_note(npc)], "🤝")
	else:
		GameState.companion = null
		npc.state = "WANDER"
		Hud.pop("%s 마을로 돌아갑니다." % Util.josa(Names.npc(npc.config.name), "이", "가"), "👋")
	close()


# ---------- 엘더: 축복 ----------

static func _blessing(npc) -> void:
	if GameState.blessingDay == GameState.day:
		show(npc, "축복은 하루에 한 번이란다. 욕심내지 말거라.", [{ label = "네…", on_select = func(): open_hub(npc) }])
		return
	GameState.blessingDay = GameState.day
	var p = GameState.player
	p.hp = p.max_hp
	p.hunger = 100.0
	Vfx.spawn_effect("RING", p.x, p.y - 40, { size = 2 })
	Hud.pop("엘더의 축복: 오늘 하루 경험치 +25%, 체력·배부름 가득", "✨")
	show(npc, "고대의 바람이 네 날개를 밀어 주기를.", [{ label = "감사합니다.", on_select = close }])


# ---------- 그론: 대장간 ----------
# 잡은 것에서 나온 소재를 모아 직접 두드린다. 골드는 고기와, 급할 때 소재를 비싸게 사는 데만 쓴다.

static func _mat_line() -> String:
	return " · ".join(Forge.mats().keys().map(func(k): return "%s %d" % [Forge.mats()[k].name, Forge.mat_count(k)]))


## 그론이 떠난 뒤의 대장간. 사흘은 불이 안 붙고, 다시 붙는 날 그론이 만들다 만 것을 엠버가 내민다
static func _ember_forge(npc) -> void:
	var death_day: int = GameState.story.get("deathDay", {}).get("Gron", GameState.day)
	if GameState.day - death_day < 3:
		show(npc, "…부싯돌은 멀쩡한데 불이 안 붙어. 미안한데 며칠만 있다가 다시 와 줄래?", [{ label = "기다릴게.", on_select = func(): open_hub(npc) }])
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
	show(npc, "%s\n\n[가진 재료] %s" % [line, _mat_line()], opts)


static func _forge_one(npc, recipe: Dictionary) -> void:
	var cost := Forge.cost_of(recipe)
	if not Forge.can_afford(cost):
		# 그론이 떠난 뒤로는 엠버가 모루를 맡는다. 말투도 엠버의 것으로
		var short := "재료가 모자라. %s에는 이만큼 들어." if npc.config.name == "Ember" else "재료가 모자라다. %s에는 이만큼 든다."
		show(npc, (short + "\n\n%s\n\n(앞의 숫자가 가진 것, 뒤가 드는 것이다)") % [recipe.name, Forge.cost_text(cost)],
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
	var line := "돈으로 사겠다면 안 말릴게. 좀 비싸긴 해." if npc.config.name == "Ember" else "돈으로 사겠다면 말리진 않는다. 비싸게 받을 뿐이지."
	show(npc, "%s (소지금 %dG)" % [line, GameState.player.gold], opts)


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
	npc.say("안 봐줄 거야!")
	Hud.pop("대련 시작! 티아맷의 기력을 모두 깎으세요. (내 체력이 25% 아래로 떨어지면 패배)", "⚔️")


# ---------- 포코: 술래잡기 ----------

static func _start_tag(npc) -> void:
	close()
	GameState.activity = { type = "TAG", npc = npc, time = TAG_TIME, max = TAG_TIME, juke = 0.0, jukeAngle = 0.0 }
	npc.say("나 잡아 봐라~!")
	Hud.pop("술래잡기! %d초 안에 %s 잡으세요. ([Shift]를 누르고 있으면 달린다)" % [TAG_TIME, Util.josa(Names.npc(npc.config.name), "을", "를")], "🏃")


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
		Hud.pop("%s 잡았습니다!" % Util.josa(Names.npc(npc.config.name), "을", "를") + (" (25G, 호감 ↑)" if first else " (5G)"), "🎉")
		if kp:
			for pn in kp.parents:
				var par = World.any_npc(pn)
				if par: add_relation(par, 2)
		Quests.notify("tag")
	else:
		npc.say(kp.tagLose if kp else "헤헤, 내가 이겼다!")
		Hud.pop("시간 초과! %s 도망쳤습니다." % Util.josa(Names.npc(npc.config.name), "이", "가"), "⏱️")


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
	Hud.current.set_boss_bar("%s 술래잡기" % Util.josa(Names.npc(a.npc.config.name) if a.get("npc") else Names.npc("Poco"), "과", "와"), a.time / a.max)
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
