extends Node
## 해 질 녘 폭포: 몰래 다가가기 (세션 D) 한 바퀴
##   godot --headless --path . res://tools/test_sneak.tscn
## 시험은 저장 9번 칸만 쓴다.
##
##  1) 모임 다음 날 아침 마을 → 포코의 귓속말 → s1
##  2) 해 질 녘 폭포 → 판이 열린다 (보는 이 둘 · 시작 자리)
##  3) 곧장 걸어가면 들킨다 → 우스운 장면 → 호숫가. 같은 날은 다시 안 열린다
##  4) 다음 날 → 판이 다시 열린다. 규칙대로 움직이는 봇은 엿들을 자리에 닿는다 → 성공 장면 · 고름 → s1 둘째 대목
##  5) 자고 나서 미라를 만나면 고백 → 보고 → s1 끝
##  6) 하루와 사귀는 판: 하루의 초대 → 유안의 순찰 피하기 → 서로 들킨 저녁 → s1 둘째 대목
##  판이 끝날 때마다 붙잡았던 용이 풀리고, 막대 · 놀이 상태가 비워졌는지 본다

const WALK := 270.0   # 봇의 걸음 (걷기. 살금살금은 Sneak 이 줄인다)

var _box: DialogueBox
var _bad := 0


func _ready() -> void:
	Save.slot = 9
	Save.delete()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.play_intro = false
	main.load_save = false
	add_child(main)
	await get_tree().process_frame
	_box = DialogueBox.current

	# ---------- 미라 · 유안 판 ----------
	_after_gathering(0)
	await _morning_in_village()
	_check("귓속말 뒤 s1 을 받는다", GameState.quests.active.has("s1"))
	_check("포코 판 (하루 초대 아님)", GameState.story.events.has("ev_tryst_rumor") and not GameState.story.events.has("ev_tryst_invite"))

	await _dusk_at_falls()
	_check("판이 열린다", Sneak.running() and GameState.activity is Dictionary and GameState.activity.type == "SNEAK")
	var r: Dictionary = Sneak._view.run if Sneak.running() else {}
	_check("보는 이 둘 (미라 · 유안)", r.get("watchers", []).size() == 2)
	var mira = World.any_npc("Mira")
	var yuan = World.any_npc("Yuan")
	_check("미라가 연못가에 서 있다", mira and Vector2(mira.x, mira.y).distance_to(_spot("mira")) < 20)

	# 곧장 걸어가면 들킨다
	var result: String = await _walk_straight(20.0)
	_check("곧장 걸어가면 들킨다 (%s)" % result, result == "caught")
	await _wait_until(func(): return DialogueBox.is_open(), 4)
	print("[들킴] ", _say())
	await _play_scene(40)
	await _wait_until(func(): return not Hud.fading() and GameState.map_id == "LAKE", 8)
	await _wait(0.3)
	_check("쫓겨나 호숫가에 선다", GameState.map_id == "LAKE")
	_check("들킨 횟수 1", int(GameState.story.tryst.fails) == 1)
	_released("들킨 뒤")

	# 같은 날에는 다시 열리지 않는다
	World._travel_lock = 0
	World.travel_to("FALLS", "S")
	await _wait(4.5)
	_check("같은 날은 다시 안 열린다", not Sneak.running() and not DialogueBox.is_open())

	# 다음 날: 다시 열리고, 규칙대로 움직이면 엿들을 자리에 닿는다
	GameState.day += 1
	await _dusk_at_falls()
	_check("다음 날 다시 열린다", Sneak.running())
	result = await _sneak_bot(60.0)
	_check("규칙대로 움직이면 성공한다 (%s)" % result, result == "heard")
	await _wait_until(func(): return DialogueBox.is_open(), 4)
	print("[엿들음] ", _say())
	await _play_scene(40)   # 성공 장면 → 고름(첫째: 불 뿜어 눈 돌리기) → 그 장면
	await _wait(0.5)
	_check("고른 것이 남는다", GameState.story.get("choices", {}).get("ev_tryst") == "divert")
	_check("s1 둘째 대목 (하룻밤 자기)", int(GameState.quests.active.get("s1", { step = -1 }).step) == 1)
	_released("성공 뒤")
	await _wait(1.0)
	_check("미라를 더는 제자리에 묶어 두지 않는다", mira.walk_to == null or Vector2(mira.walk_to.x, mira.walk_to.y).distance_to(Vector2(mira.x, mira.y)) > 5)

	# 굴에 들어가 자고, 다음 날 미라를 만나면 고백 → 보고
	World._travel_lock = 0
	World.travel_to("DEN_MINE")
	await _wait(0.5)
	Story.sleep()
	await _wait_until(func(): return not Hud.fading(), 8)
	await _play_scene(20)
	_check("잠 → s1 셋째 대목 (미라)", int(GameState.quests.active.get("s1", { step = -1 }).step) == 2)
	GameState.dayTime = 8.0 / 24.0
	World._travel_lock = 0
	World.travel_to("VILLAGE")
	await _wait_until(func(): return DialogueBox.is_open(), 10)
	var first := _say()
	await _play_scene(30)
	_check("미라가 먼저 다가와 털어놓는다 (%s)" % first.left(30), first.contains("미라가 먼저 다가왔다"))
	var s1 = Quests.by_id("s1")
	_check("보고만 남는다", Quests.is_complete(s1) and Quests.reportable_for(mira) == s1)
	Quests.turn_in(s1, mira, "cover")
	await _wait(0.3)
	_check("s1 끝", GameState.quests.done.has("s1"))

	# ---------- 하루와 사귀는 판 ----------
	_after_gathering(1)
	await _morning_in_village()
	_check("하루가 부른다 (초대 → s1)", GameState.story.events.has("ev_tryst_invite") and GameState.quests.active.has("s1"))
	await _dusk_at_falls()
	_check("하루 판이 열린다", Sneak.running() and Sneak._view.run.variant == "mine")
	var haru = World.any_npc("Haru")
	_check("하루가 곁에 붙는다", haru.state == "SNEAK_FOLLOW")
	_check("미라는 물안개 속에 숨어 있다", mira.is_hidden)
	result = await _sneak_bot(60.0)
	_check("순찰을 피해 폭포 옆 바위에 닿는다 (%s)" % result, result == "heard")
	await _wait_until(func(): return DialogueBox.is_open(), 4)
	print("[서로 들킴] ", _say())
	await _play_scene(40)
	await _wait(0.5)
	_check("s1 둘째 대목 (하룻밤 자기)", int(GameState.quests.active.get("s1", { step = -1 }).step) == 1)
	_check("하루가 제 일과로 돌아간다", haru.state == "WANDER")
	_check("미라가 다시 보인다", not mira.is_hidden)
	_released("하루 판 뒤")

	Save.save_game()
	print("[끝] 틀린 것 %d개" % _bad)
	get_tree().quit()


# ---------- 판 차리기 ----------

## 5장 달맞이 모임을 막 치른 판. 그 밖의 사건 · 아침 장면은 본 것으로 둔다 (다른 장면이 끼어들지 않게)
func _after_gathering(haru_dates: int) -> void:
	var p: Dragon = GameState.player
	GameState.quests.done = ["m0", "m1", "m2", "m3", "m4", "m5", "m5g"]
	GameState.quests.active = {}
	GameState.quests.tracked = null
	GameState.quests.choices = {}
	GameState.questScenes = []
	GameState.bossesDefeated = { MORGATH = true, ZALGORA = true }
	var events := []
	for e in Data.get_module("chronicle").CHRONICLE:
		if not e.id.begins_with("ev_tryst"): events.append(e.id)
	GameState.story.events = events
	GameState.story.scenes = Data.get_module("story").SCENES.map(func(s): return s.id)
	GameState.story.erase("tryst")
	GameState.story.eventDay = { ev_gathering = GameState.day }
	GameState.tutorial.finished = true
	GameState.elderTutorialDone = true
	GameState.raid.count = 0
	p.stage_index = 2
	p.level = 10
	p.hp = p.max_hp
	GameState.partner = null
	World.any_npc("Haru").dates = haru_dates
	GameState.day += 1
	var ch := Chapters.current(GameState)
	GameState.story.chapter = ch.id
	GameState.story.chapterTitle = ch.title


## 아침 마을: 귓속말(또는 하루의 초대)이 나와 s1 을 받을 때까지
func _morning_in_village() -> void:
	GameState.dayTime = 8.0 / 24.0
	World._travel_lock = 0
	World.travel_to("VILLAGE")
	var t0 := Time.get_ticks_msec()
	while not GameState.quests.active.has("s1") and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().process_frame
		if DialogueBox.is_open():
			print("[아침] ", _say())
			await _play_scene(20)


## 해 질 녘 폭포: 판을 여는 한 줄 → 막이 덮였다 걷힘 → 판을 보여 주는 짧은 장면 → 판이 돈다
func _dusk_at_falls() -> void:
	GameState.dayTime = 18.1 / 24.0
	GameState.weather.type = "CLEAR"
	World._travel_lock = 0
	World.travel_to("FALLS", "S")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000:
		await get_tree().process_frame
		if Sneak.running() and Sneak._view.run.phase == "play": return
		if DialogueBox.is_open():
			print("[해 질 녘] ", _say())
			await _play_scene(1)


func _spot(key: String) -> Vector2:
	return World.at(Data.get_module("maps").MAPS.FALLS.sneak[key])


## 판이 끝난 뒤: 붙잡았던 용이 풀리고 막대 · 놀이 상태가 비워졌다
func _released(label: String) -> void:
	_check("%s: 판이 치워졌다" % label, not Sneak.running())
	_check("%s: 놀이 상태가 비워졌다" % label, GameState.activity == null)
	_check("%s: 막대가 사라졌다" % label, not Hud.current._boss_bar.visible)
	_check("%s: 내 몸빛이 돌아왔다" % label, GameState.player.modulate.r > 0.99)


# ---------- 걷는 봇 ----------

## 아무것도 안 보고 엿들을 자리로 곧장 걷는다
func _walk_straight(limit: float) -> String:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < limit * 1000:
		await get_tree().process_frame
		if not Sneak.running(): return "ended"
		var r: Dictionary = Sneak._view.run
		if r.phase != "play": return "caught" if r.phase in ["caught", "scold"] else r.phase
		if GameState.isDialogueOpen: continue
		_step_toward(r.listen, get_process_delta_time())
	return "timeout"


## 사람처럼: 둘이 이야기하는 사이에 다음 그늘로 옮겨 가고, 돌아보려 하면 멀리서는 멈추고 가까이서는 그늘로 서두른다.
## 그늘에 닿으면 한 번 돌아보고 난 뒤에 다시 나선다
func _sneak_bot(limit: float) -> String:
	var r: Dictionary = Sneak._view.run
	var path := _hides(r)
	path.append(r.listen)
	print("[봇] 길: ", path.map(func(v): return "(%d,%d)" % [v.x, v.y]))
	var i := 0
	var moving := true
	var was_alert := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < limit * 1000:
		await get_tree().process_frame
		if not Sneak.running(): return "ended"
		if r.phase != "play": return "caught" if r.phase in ["caught", "scold"] else r.phase
		if GameState.isDialogueOpen: continue
		var p = GameState.player
		var me := Vector2(p.x, p.y)
		var alert := false
		var nearest := INF
		for w in r.watchers:
			if w.phase != "calm": alert = true
			nearest = minf(nearest, me.distance_to(Vector2(w.e.x, w.e.y)))
		var fresh := was_alert and not alert   # 방금 돌아보기가 끝났다
		was_alert = alert
		if not moving:
			if fresh: moving = true
			continue
		if alert and nearest > Sneak.NEAR: continue   # 멀리서는 멈춘다
		_step_toward(path[i], get_process_delta_time())
		if Vector2(p.x, p.y).distance_to(path[i]) < 8:
			i += 1
			if i >= path.size(): i = path.size() - 1
			moving = false
	return "timeout"


func _step_toward(to: Vector2, dt: float) -> void:
	var p = GameState.player
	var v := to - Vector2(p.x, p.y)
	if v.length() < 1: return
	var step := minf(v.length() / Sneak.CREEP, WALK * dt)   # 살금살금으로 줄어들 것을 헤아려 넘치지 않게
	var n := v.normalized()
	p.x += n.x * step
	p.y += n.y * step


## 판에 새로 둔 바위마다, 보는 이 모두에게서 가려지는 자리 가운데 엿들을 자리에 가장 가까운 곳
func _hides(r: Dictionary) -> Array:
	var eyes := []
	for w in r.watchers:
		if w.patrol.is_empty(): eyes.append(Vector2(w.e.x, w.e.y))
		else:
			for k in 5: eyes.append(w.patrol[0].lerp(w.patrol[1], k / 4.0))
	var out := []
	for c in Data.get_module("maps").MAPS.FALLS.fixtures:
		if c.t != "PROP" or c.type != "ROCK": continue
		var rock := World.at(c.at)
		if rock.distance_to(r.listen) < 70: continue   # 엿들을 바위는 엿들을 자리가 곧 그늘이다
		var best = null
		for a in range(0, 360, 15):
			for rad in [40.0, 55.0, 70.0]:
				var q: Vector2 = rock + Vector2(cos(deg_to_rad(a)), sin(deg_to_rad(a))) * rad
				if Collision.solid_at(q.x, q.y, 18): continue
				if not eyes.all(func(o): return Sneak.covered(r, o, q)): continue
				if best == null or q.distance_to(r.listen) < best.distance_to(r.listen): best = q
		if best != null: out.append(best)
	out.sort_custom(func(a, b): return a.distance_to(r.start) < b.distance_to(r.start))
	return out


# ---------- 공용 ----------

func _check(label: String, ok: bool) -> void:
	if not ok: _bad += 1
	print("[%s] %s" % ["OK" if ok else "틀림", label])


func _say() -> String:
	if not DialogueBox.is_open(): return "(대화창 없음)"
	var opts: Array = _box._list.map(func(o): return o.label)
	return "%s | %s | %s" % [_box._name.text, _box._text.text.left(60).replace("\n", " "), opts]


## 장면을 끝까지 넘긴다 (고름이 뜨면 첫째). 대화창이 닫히고 연출 박자도 멈추면 돌아온다
func _play_scene(limit: int) -> void:
	for i in limit:
		await _wait(0.12)
		var t := Time.get_ticks_msec()
		while (Cutscene.busy() or Hud.fading()) and not DialogueBox.is_open() and Time.get_ticks_msec() - t < 8000:
			await get_tree().process_frame
		if not DialogueBox.is_open(): return
		_box._text.visible_characters = -1
		_box._choose(0)


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000: await get_tree().process_frame


func _wait_until(cond: Callable, sec: float) -> void:
	var t := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t < sec * 1000: await get_tree().process_frame
