class_name Training
## 2D판 systems/training.js. 카이론과의 하루 (data/training.json).
##
## 아침마다 그날의 일과가 하나 정해지고, 일지와 추적창에 "오늘의 수련"으로 뜬다.
## 스승을 찾아가 말을 걸면 메뉴를 거치지 않고 바로 그 얘기부터 나온다.
##
## GameState.story.plan = { day, kind, stage: 'offered' | 'active' | 'done', n, ... }
##   kind: 'DRILL' | 'HUNT_CLEAN' | 'HUNT_ELITE' | 'DELVE' | 'RACE' | 'WATCH' | 'TRIP' | 'REST'
## GameState.story.planLog = { count, last, trips: [], rests: [] }

# 여덟 번의 기본기는 스승의 일정 안에 날짜가 박혀 있다: n번째 기본기는 일과를 이만큼 받은 뒤에야 나온다.
# 그날이 와도 레벨이 모자라면 다른 일과로 넘어가고, 레벨이 차는 대로 바로 다음 날 나온다.
const LESSON_DAYS := [0, 1, 2, 4, 6, 8, 10, 12]   # 하루가 길어진 만큼 (DAY_LENGTH 360)

static var _shown := ""


static func _d() -> Dictionary: return Data.get_module("training")
static func _master(): return World.any_npc("Kairon")


static func _log() -> Dictionary:
	if not GameState.story.get("planLog"): GameState.story.planLog = { count = 0, last = null, trips = [], rests = [] }
	return GameState.story.planLog


static func _next_trip():
	for t in _d().TRIPS:
		if not _log().trips.has(t.id) and t.when.call(GameState) and Chapters.map_open(GameState, t.map): return t
	return null


static func _next_rest():
	for r in _d().RESTS:
		if not _log().rests.has(r.id) and r.when.call(GameState): return r
	return null


## 오늘의 일과 하나를 고른다. 무엇을 할지는 스승이 정한다
static func _choose():
	var p = GameState.player
	var L: int = GameState.story.lessons.size()
	var last = _log().last
	var lesson = Story.next_lesson()
	var can_drill: bool = lesson != null and p.level >= lesson.level and _log().count >= (LESSON_DAYS[L] if L < LESSON_DAYS.size() else 0)
	if L == 0: return "DRILL" if can_drill else null      # 첫 수련은 늘 기본기다

	# 어제 습격을 막았거나 날이 궂으면 쉬어 간다
	var rough: bool = GameState.story.get("yesterday", {}).get("raid", false) or ["RAIN", "SNOW"].has(GameState.weather.type)
	if rough and last != "REST" and _next_rest(): return "REST"
	if can_drill and (last != "DRILL" or L < 3): return "DRILL"   # 처음 세 기본기는 이어서 배워도 된다

	var others := ["HUNT_CLEAN"]
	if _next_trip(): others.append("TRIP")
	others.append("RACE")
	if p.level >= 3: others.append("HUNT_ELITE")
	if _next_rest(): others.append("REST")
	if p.level >= 3 and L >= 2: others.append("DELVE")
	if L >= 2 and not _log().get("watched"): others.append("WATCH")
	var list := others.filter(func(k): return k != last)
	if list.is_empty(): return "DRILL" if can_drill else "HUNT_CLEAN"
	return list[int(_log().count) % list.size()]


## 오늘의 일과. 스승을 소개받기 전(ch1)이면 null
static func todays_plan():
	if not GameState.story.scenes.has("ch1"): return null
	var plan = GameState.story.get("plan")
	if plan and plan.day == GameState.day: return plan
	if plan and plan.stage == "active": _end_company()       # 어제 것을 못 끝내고 날이 넘어갔다
	var kind = _choose()
	if not kind:
		GameState.story.plan = null
		return null
	plan = { day = GameState.day, kind = kind, stage = "offered", n = 0 }
	GameState.story.plan = plan
	if kind == "TRIP": plan.trip = _next_trip().id
	if kind == "REST": plan.rest = _next_rest().id
	_log().count += 1
	return plan


static func _def(plan: Dictionary) -> Dictionary:
	if plan.kind == "TRIP":
		for t in _d().TRIPS:
			if t.id == plan.trip: return t
	if plan.kind == "REST":
		for r in _d().RESTS:
			if r.id == plan.rest: return r
	return _d().PLANS[plan.kind]


static func _plan_title(plan: Dictionary) -> String:
	if plan.kind == "DRILL":
		var l = Story.next_lesson()
		return l.title if l else _d().PLANS.DRILL.title
	return _def(plan).title


# ---------- 스승에게 말을 걸었을 때 (NpcActions) ----------

## 오늘 일과를 아직 안 받았으면 true — 대화가 메뉴 대신 그 얘기부터 시작한다
static func pending() -> bool:
	var plan = todays_plan()
	return plan != null and plan.stage == "offered" and not GameState.activity and not GameState.raid.active


static func _close() -> void:
	GameState.isDialogueOpen = false
	GameState.currentNpc = null
	DialogueBox.current.hide_dialogue()


static func _ask(npc, text: String, options: Array) -> void:
	GameState.isDialogueOpen = true
	DialogueBox.current.show_dialogue({ name = Names.npc(npc.config.name), text = text, sheet = npc.sheet, on_close = _close, options = options })


## 스승이 오늘 할 일을 말해 준다. other: 다른 용건으로 넘어갈 때 부른다
static func open(npc, other: Callable) -> void:
	var plan: Dictionary = todays_plan()
	var lesson = Story.next_lesson()
	var options := [
		{ label = "따라나선다", on_select = func():
			_close()
			_begin(npc, plan) },
		{ label = "조금 이따 오겠습니다", on_select = _close },
		{ label = "다른 얘기를 한다", on_select = other },
	]
	if plan.kind == "DRILL":
		_ask(npc, "오늘은 기본기다. %s." % lesson.title, options)
		return
	# 제안은 한 줄씩 넘기다가, 마지막 줄에서 따라나설지 고른다 (나라가 받아치고 끝나는 제안도 있다)
	var lines: Array = _def(plan).offer
	var say := []
	say.append(func(i: int):
		var who = World.any_npc(lines[i].who)
		_ask(who if who else npc, lines[i].text, [{ label = "다음", on_select = func(): say[0].call(i + 1) }] if i < lines.size() - 1 else options))
	say[0].call(0)


static func _begin(npc, plan: Dictionary) -> void:
	plan.stage = "active"
	_log().last = plan.kind
	var d := _def(plan)
	match plan.kind:
		"DRILL":
			Story.start_lesson(npc, Story.next_lesson())
			return
		"REST":
			_rest(npc, plan, d)
			return
		"WATCH":
			_watch(npc, plan, d)
			return
		"RACE":
			_race(npc, plan, d)
			return
	# 나머지는 스승이 따라나선다
	if GameState.companion and GameState.companion != npc: GameState.companion.state = "WANDER"
	GameState.companion = npc
	npc.state = "COMPANION_FOLLOW"
	plan.lastHp = GameState.player.hp
	Hud.pop("오늘의 수련: %s. %s 따라나선다." % [d.title, Util.josa(Names.npc("Kairon"), "이", "가")], "🎓")
	Sfx.play("quest")
	Save.save_game()


## 스승이 제자리로 돌아간다 (다음에 그 지도에 들르면 일과대로 서 있다)
static func _end_company() -> void:
	var npc = _master()
	if npc and GameState.companion == npc:
		GameState.companion = null
		npc.state = "WANDER"
		npc.passive = false


static func _finish(plan: Dictionary, lines) -> void:
	plan.stage = "done"
	var p = GameState.player
	var npc = _master()
	var reward := func():
		_end_company()
		p.gain_xp(30 + p.level * 15)
		if npc: npc.relation = minf(100, npc.relation + 4)
		Hud.pop("오늘의 수련을 마쳤다: %s" % _plan_title(plan), "🎓")
		Sfx.play("quest")
		Save.save_game()
	if lines: Chronicle.play_scene(_plan_title(plan), lines, reward)
	else: reward.call()


# ---------- 쉬는 날 · 구경하는 날 · 내기 ----------

static func _rest(_npc, plan: Dictionary, d: Dictionary) -> void:
	_log().rests.append(d.id)
	Hud.fade_screen(d.fade, func():
		var p = GameState.player
		GameState.dayTime = minf(0.78, GameState.dayTime + 0.12)
		p.hp = p.max_hp
		p.hunger = minf(100, p.hunger + 30)
		for k in p.cooldowns: p.cooldowns[k] = 0.0, func():
		Chronicle.play_scene(d.title, d.lines, func(): _finish(plan, null), true, d.get("place")))


static func _watch(npc, plan: Dictionary, d: Dictionary) -> void:
	_log().watched = true
	var cheer := func(nm: String):
		_close()
		Chronicle.play_scene(d.title, d.cheer[nm] + d.done, func():
			var who = World.any_npc(nm)
			if who: who.relation = minf(100, who.relation + 5)
			_finish(plan, null))
	_ask(npc, d.prompt, [
		{ label = "%s 응원한다" % Util.josa(Names.npc("Nara"), "을", "를"), on_select = func(): cheer.call("Nara") },
		{ label = "%s을 응원한다" % Names.npc("Tiamat"), on_select = func(): cheer.call("Tiamat") },
	])


static func _race(npc, plan: Dictionary, d: Dictionary) -> void:
	# 나라가 이 지도에 없으면 불러온다 (수련이 끝나면 일과대로 제 갈 길을 간다)
	var nara = World.any_npc("Nara")
	if not GameState.entities.npcs.has(nara):
		nara.x = npc.x + 90; nara.y = npc.y + 40
		nara.remove = false; nara.is_hidden = false
		World.add_entity("npcs", nara)
	var hp: float = 40 + GameState.player.level * 14
	Story.start_drill(npc, { type = "TARGETS", count = d.dummies, hp = hp, time = 60 }, {
		rival = nara, rivalKills = 0, rivalDps = hp / 5,
		onEnd = func(won): Chronicle.play_scene(d.title, d.win if won else d.lose, func(): _finish(plan, null)),
	})


# ---------- 매 프레임 (main) ----------

static func update() -> void:
	var plan = todays_plan()
	# 추적창은 퀘스트가 바뀔 때만 다시 그려진다. 일과가 바뀐 것도 알려 준다
	var sig := "%s|%s|%s|%s|%s" % [plan.day, plan.kind, plan.stage, plan.n, plan.get("reached")] if plan else ""
	if sig != _shown:
		_shown = sig
		Quests.changed()
	if not plan or plan.stage != "active" or GameState.isDialogueOpen: return
	var p = GameState.player
	var npc = _master()
	var d := _def(plan)

	# 기본기는 Story 가 굴린다. 끝났는지만 본다
	if plan.kind == "DRILL":
		if not GameState.activity: plan.stage = "done" if GameState.story.get("lessonDay") == GameState.day else "offered"
		return
	if not npc or GameState.companion != npc: return
	# 구경만 하는 날: 제자가 죽게 생겼을 때만 나선다
	npc.passive = bool(d.get("passive", false)) and p.hp > p.max_hp * 0.35

	if plan.kind == "HUNT_CLEAN":
		if p.hp < plan.lastHp - 0.5 and plan.n > 0:
			plan.n = 0
			npc.say(d.onHit.pick_random())
		plan.lastHp = p.hp
	if plan.kind == "HUNT_ELITE" and not plan.get("spawned") and _is_wild(GameState.map_id):
		plan.spawned = true
		var a := Util.rand_range(0, TAU)
		World.add_entity("enemies", Enemy.make(p.x + cos(a) * 520, p.y + sin(a) * 380, World.map_enemies()[0], true))
		npc.say(d.spotted)
	if plan.kind == "TRIP" and GameState.map_id == d.map and not GameState.dungeon:
		_log().trips.append(d.id)
		_finish(plan, d.done)
	# 굴에서는 장면을 틀지 않는다. 밖에 나오면 마무리한다
	if plan.kind == "DELVE" and plan.get("reached") and not GameState.dungeon: _finish(plan, d.done.slice(1))


static func _is_wild(id: String) -> bool:
	var spec = World.maps().get(id)
	return id != "VILLAGE" and spec != null and spec.get("enemyCap") and not spec.get("safe")


# ---------- 퀘스트 쪽에 끼워 넣는 것 (추적창 · 일지 · 머리 위 표시 · 통지) ----------

static func _on_notify(type: String, target) -> void:
	var plan = GameState.story.get("plan")
	if not plan or plan.stage != "active": return
	var npc = _master()
	var d := _def(plan)
	if not npc or GameState.companion != npc: return
	if plan.kind == "HUNT_CLEAN" and type == "kill" and target != "PREY" and target != "DUMMY":
		plan.n += 1
		if plan.n >= d.count: _finish(plan, d.done)
		else: npc.say(d.count1 if plan.n == 1 else d.count2)
	if plan.kind == "HUNT_ELITE" and type == "elite": _finish(plan, d.done)
	# 굴 속에서는 장면을 틀지 않는다. 한마디만 하고, 밖에 나오면 마무리 장면이 나온다
	if plan.kind == "DELVE" and type == "delve" and target is int and target >= d.depth and not plan.get("reached"):
		plan.reached = true
		npc.say(d.done[0].text)


static func _where() -> String:
	var at = Routine.plan_for("Kairon")
	return " (지금 %s)" % at.mapName if at else ""


static func _hint_of(plan: Dictionary) -> String:
	if plan.stage == "offered": return "%s을 찾아가 오늘 할 일을 듣는다.%s" % [Names.npc("Kairon"), _where()]
	if plan.kind == "DRILL": return "스승이 낸 과제를 해낸다."
	if plan.kind == "DELVE" and plan.get("reached"): return "굴 밖으로 나온다."
	return _def(plan).hint


static func _progress_of(plan: Dictionary) -> String:
	if plan.stage != "active": return ""
	if plan.kind == "HUNT_CLEAN": return "%d / %d" % [plan.n, _def(plan).count]
	return ""


## Quests 에 훅을 건다 (main 이 한 번 부른다)
static func install() -> void:
	Quests.training = {
		notify = _on_notify,
		# 추적 중인 퀘스트가 없을 때 추적창에 뜬다
		line = func():
			var plan = todays_plan()
			if not plan or plan.stage == "done": return null
			var title: String = "오늘의 수련" if plan.stage == "offered" else "오늘의 수련: %s" % _plan_title(plan)
			return { title = title, goal = _hint_of(plan), text = _progress_of(plan), complete = false, more = 0 },
		# 일지 [퀘스트] 맨 위 한 줄
		row = func():
			var plan = todays_plan()
			if not plan: return null
			var done: bool = plan.stage == "done"
			var prog: String = "완료" if done else ((_progress_of(plan) if _progress_of(plan) else "진행 중") if plan.stage == "active" else "스승에게 가자")
			return {
				id = "training", title = "오늘은 무엇을 할까" if plan.stage == "offered" else _plan_title(plan), giver = Names.npc("Kairon"),
				summary = "스승은 하루에 하나만 가르친다. 무엇을 할지는 그날 스승이 정한다.",
				hint = "오늘 수련은 끝났다. 자고 나면 내일 것이 정해진다." if done else _hint_of(plan),
				goal = "-" if done else _hint_of(plan), reward = "경험치 · 스승의 호감",
				progress = prog, chapter = "", done = done, complete = false, tracked = false,
			},
		marker = func(npc): return "!" if npc.config.name == "Kairon" and pending() else null,
	}
