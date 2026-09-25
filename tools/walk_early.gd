extends Node
## 처음 하는 사람처럼 첫 며칠을 걸어 본다 (흐름 살피기용. 맞다 · 틀리다를 가리지 않는다).
## 추적창이 가리키는 대로 움직이고, 화면에 뜬 대사 · 알림 · 배너 · 추적창을 날짜 · 시각과 함께 찍는다.
## 걷는 시간은 거리만큼 기다려서 흉내 낸다. 싸움은 한 대에 쓰러뜨린다 (보스도. 대련은 기력을 비워 이긴 셈 친다).
## 굴 탐험 · 대장간 단련 대목은 건너뛴다 (지하 몇 층 · 단련 한 번을 한 셈 친다).
## 가리키는 곳이 아직 닫힌 지도면 [막힘], 찾아간 용이 할 말이 없으면 [헛걸음] 을 찍는다.
##   godot --headless --path . res://tools/walk_early.tscn -- [며칠째까지 (기본 3)]

const WALK := 260.0   # 걷는 빠르기 (px/초)
const GATE := 12.0    # 지도를 하나 넘는 데 드는 시간 (초)

var _box: DialogueBox
var _until := 3
var _say := ""
var _track := ""
var _qb = null
var _toasts := {}
var _visiting := ""
var _idle_logged := ""
var _stage_logged := false
var _event_wait := ""


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: _until = int(a[0])
	Save.slot = 9   # 시험은 9번 칸을 쓴다 (사람이 쓰는 1~3번 칸을 건드리지 않게)
	Save.delete()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	_box = DialogueBox.current
	Engine.time_scale = 3.0
	var t0 := Time.get_ticks_msec()
	while GameState.day <= _until and Time.get_ticks_msec() - t0 < maxi(25, _until * 4) * 60 * 1000:
		await get_tree().process_frame
		_watch()
		_status()
		if DialogueBox.is_open(): await _answer()
		elif GameState.tour: _follow_poco()   # 구경 중에는 장면 사이에도 포코 곁에 붙어 선다
		elif not (GameState.prologue or Cutscene.busy() or Cutscene.on or Hud.chapter_card_on()): await _act()
	_line("[끝] 퀘스트 끝냄 %s · 맡음 %s · 레벨 %d · 단계 %d · 배운 것 %s" % [GameState.quests.done, GameState.quests.active.keys(), GameState.player.level, GameState.player.stage_index, GameState.story.lessons])
	get_tree().quit()


func _line(s: String) -> void:
	_quiet_at = GameState.game_time
	var h := fposmod(GameState.dayTime, 1.0) * 24.0
	print("[%d일 %02d:%02d %s] %s" % [GameState.day, int(h), int(fmod(h, 1.0) * 60), GameState.map_id, s])


## 화면에 새로 뜬 것을 적는다
func _watch() -> void:
	if DialogueBox.is_open():
		var key := _box._name.text + "|" + _box.shown_text()
		if key != _say:
			_say = key
			var opts: Array = _box._list.map(func(o): return str(o.label))
			var who: String = _box._name.text if _box._name.text != "" and _box._name.is_visible_in_tree() else "(해설)"
			_line("  %s: %s%s" % [who, _box.shown_text().replace("\n", " ⏎ "), "   ▸ " + " | ".join(opts) if opts.size() > 1 else ""])
	else:
		_say = ""
	var now := {}
	for t in Hud.current._toasts.get_children():
		var s: String = t.get_node("Label").text
		now[s] = true
		if not _toasts.has(s): _line("  [알림] " + s)
	_toasts = now
	var b = Hud.current._qb_now
	if b is Dictionary and not b.is_empty() and (not _qb or b.title != _qb.title or b.kind != _qb.kind): _line("  [배너] %s · %s · %s" % [b.kind, b.title, b.goal])
	_qb = b
	var key2 := ""
	var line = Quests.tracked_line()
	if line: key2 = "%s%s — %s%s" % ["(수련) " if line.get("training") else "", line.title, line.goal, "  📍" + line.where if line.get("where") else ""]
	else:
		var s = Quests.suggestion()
		if s: key2 = "(할 만한 일) %s — %s" % [s.title, s.get("goal", "")]
	var t = Guide.target()
	if t: key2 += "   ➜ " + str(t.label)
	if key2 != _track:
		_track = key2
		_line("[추적] " + (key2 if key2 != "" else "(비었다)"))


## 대화창: 읽는 척 잠깐 쉬고 고른다. 볼일 없이 연 메뉴면 닫는다
func _answer():
	await _real(0.25)
	if not DialogueBox.is_open(): return
	_box._text.visible_characters = -1
	var labels: Array = _box._list.map(func(o): return str(o.label))
	var i := 0
	if labels.size() > 1 and labels[0] == "💬 이야기를 나눈다":
		i = maxi(labels.find("다음에 봐"), 0)
		if _visiting != "": _line("  [헛걸음] %s: 용건이 없다" % _visiting)
	elif labels.has("아직 안 졸려"):
		i = labels.find("잠을 잔다 (다음 날 아침까지)") if _bedtime() else labels.find("아직 안 졸려")
		i = maxi(i, 0)
	_visiting = ""
	_box._choose(i)
	await _real(0.05)


func _bedtime() -> bool:
	var q = Quests.tracked_quest()
	if q and not Quests.is_complete(q) and Quests.cur_step(q).goal.type == "sleep": return true   # 자고 나면 넘어가는 대목 (첫 밤)
	return GameState.dayTime > 0.8 or GameState.dayTime < 0.2


# ---------- 움직이기 ----------

func _follow_poco() -> void:
	var p: Dragon = GameState.player
	var poco = World.any_npc("Poco")
	if not poco or not GameState.entities.npcs.has(poco): return
	# 포코 뒤에 붙는다 (앞에 서면 몸이 길을 막아 포코가 제자리걸음을 했다)
	var w = poco.walk_to
	var dir := Vector2(w.x - poco.x, w.y - poco.y).normalized() if w else Vector2.RIGHT
	p.x = poco.x - dir.x * 90; p.y = poco.y - dir.y * 90


## 한동안 아무것도 안 찍혔으면 지금 상태를 한 줄 찍는다 (멈춘 곳을 찾게)
var _quiet_at := 0.0
func _status() -> void:
	if GameState.game_time - _quiet_at < 90.0: return
	_quiet_at = GameState.game_time
	_line("[상태] 구경=%s 장면=%s/%s 대화=%s 활동=%s 습격=%s" % [GameState.tour, Cutscene.on, Cutscene.busy(), GameState.isDialogueOpen, GameState.activity != null, GameState.raid.active])
	var a = GameState.activity
	if a and a.get("npc"):
		var n = a.npc
		_line("[상태] 활동 %s · 상대 %s 이 지도에=%s remove=%s hidden=%s · 남은 시간 %.1f · 허수아비 %d" % [a.type, n.config.name, GameState.entities.npcs.has(n), n.remove, n.is_hidden, float(a.get("time", 0)),
			a.get("dummies", []).filter(func(x): return is_instance_valid(x) and not x.remove).size()])


func _act():
	if GameState.activity: return await _drill()
	if GameState.raid.active: return await _defend()
	var q = Quests.tracked_quest()
	var line = Quests.tracked_line()
	if q == null and line and line.get("training"): return await _training()
	if q == null:
		var s = Quests.suggestion()
		if s and s.get("who") and s.get("main"): return await _visit(s.who)
		if _bedtime(): return await _sleep()
		if s and s.get("who") and s.who != "Kairon" and not _idle_logged.contains(s.who):
			_idle_logged += s.who
			return await _visit(s.who)
		if _idle_logged != "idle":
			_line("[봇] 할 일이 없다. 해 질 때까지 기다린다")
			_idle_logged = "idle"
		return await _pass(20)
	_idle_logged = ""
	if Quests.is_complete(q): return await _visit(Quests.turn_in_npc(q))
	var st: Dictionary = Quests.cur_step(q)
	var g: Dictionary = st.goal
	match str(g.type):
		"talk", "bring": await _visit(g.target)
		"kill", "killAny", "elite": await _hunt(str(g.get("target", "")))
		"stage": await _stage()
		"raid":
			if _bedtime(): await _sleep()
			else: await _pass(20)
		"visit": await _go(g.target)
		"sleep": await _sleep()
		"boss": await _boss(str(g.id))
		"event": await _event(st)
		"spar": await _play_with("Tiamat")
		"tag": await _play_with(str(g.get("target", "Poco")))
		"delve", "upgrade":
			_line("[봇] %s 대목은 건너뛴다" % g.type)
			Quests.notify(g.type, int(g.get("count", 1)) if g.type == "delve" else null)
			await _pass(3)
		"tour": pass
		_:
			_line("[봇] 여기까지만 걷는다 (%s)" % g.type)
			_until = -1


## 그 용에게 걸어가서 말을 건다
func _visit(who: String):
	var n = World.any_npc(who)
	if not n: return await _pass(5)
	if not GameState.entities.npcs.has(n) or n.is_hidden:
		var plan = Routine.plan_for(who)
		if not plan: return await _pass(5)
		if plan.map == GameState.map_id: return await _pass(5)   # 오는 중이다
		if not await _go(plan.map): return
		return
	await _walk_to(n.x - 60, n.y)
	if DialogueBox.is_open() or Cutscene.on: return
	_visiting = who
	_line("[봇] %s에게 말을 건다" % Names.npc(who))
	Dialogue.start(n, "TALK")


func _go(map: String):
	if map == GameState.map_id: return true
	if not Chapters.map_open(GameState, map):
		_line("[막힘] %s 은 아직 닫힌 곳이다 (%s)" % [Names.map(map), Chapters.blocked_text(GameState, map)])
		await _pass(20)
		return false
	_line("[봇] %s(으)로 간다" % Names.map(map))
	await _pass(GATE)
	if _busy(): return false   # 가는 길에 장면이 열렸다. 사람은 대화 중에 지도를 넘지 못한다
	World.travel_to(map)
	await _real(0.6)
	return true


func _walk_to(x: float, y: float):
	var p = GameState.player
	var d := Vector2(p.x, p.y).distance_to(Vector2(x, y))
	await _pass(d / WALK)
	if _busy(): return   # 걷는 사이 장면이 열렸다 (장면 도중에 자리를 옮기던 것)
	p.x = x; p.y = y


func _busy() -> bool:
	return DialogueBox.is_open() or Cutscene.on or GameState.isDialogueOpen


## 그 적을 찾아 쓰러뜨린다. 없으면 사냥터로
func _hunt(target: String):
	var foes: Array = GameState.entities.enemies.filter(func(e): return not e.remove and (target == "" or e.type == target) and e.type != "PREY")
	if foes.is_empty():
		if target == "DUMMY": return await _pass(3)
		if GameState.map_id != "EAST_ROAD": await _go("EAST_ROAD")
		else: await _pass(5)
		return
	var e = foes[0]
	await _walk_to(e.x - 200, e.y)
	await _pass(1.5)
	if _busy(): return
	if is_instance_valid(e) and not e.remove: e.take_damage(99999)


## 승급 시험: 레벨이 모자라면 사냥, 차면 카이론에게 청한다
func _stage():
	var p = GameState.player
	var t = Story.next_trial()
	if t and t.blocked:   # 레벨이 모자라면 사냥, 다른 게 모자라면 (수련 · 이야기) 그날 일과를 한다
		if p.level < Story._stages()[int(t.stage)].minLevel: return await _hunt("")
		if not _stage_logged:
			_stage_logged = true
			_line("[봇] 승급 시험이 막혀 있다: %s" % t.blocked)
		return await _training()
	_stage_logged = false
	var k = World.any_npc("Kairon")
	if not k or not GameState.entities.npcs.has(k): return await _visit("Kairon")
	await _walk_to(k.x - 60, k.y)
	if _busy(): return
	_line("[봇] 카이론에게 가르침을 청한다")
	NpcActions.show(k, "뭘 배우러 왔냐.", Story.master_options(k) + [{ label = "돌아간다", on_select = NpcActions.close }])


## 오늘의 수련: 카이론에게 청하고, 받은 일을 한다
func _training():
	var plan = Training.todays_plan()
	if not plan: return await _pass(10)
	if plan.stage != "active": return await _visit("Kairon")
	match str(plan.kind):
		"HUNT_CLEAN", "HUNT_ELITE": await _hunt("")
		"TRIP": await _go(Training._def(plan).map)
		"DELVE":
			_line("[봇] 굴 탐험 수련은 건너뛴다")
			plan.reached = true
			await _pass(5)
		_:
			_line("[봇] 수련 %s 을 기다린다" % plan.kind)
			await _pass(10)


## 수련 · 시험: 허수아비는 깨고, 나머지는 잠깐 버티다 이긴 셈 친다
func _drill():
	var a: Dictionary = GameState.activity
	if a.get("type") == "TARGETS":
		for d in a.get("dummies", []):
			if is_instance_valid(d) and not d.remove:
				await _pass(1.0)
				if is_instance_valid(d) and not d.remove: d.take_damage(99999)
				return
		return await _pass(1)
	if a.get("type") in ["DODGE", "DUEL"]:
		for i in 60:   # 6초 버틴다
			GameState.player.hp = GameState.player.max_hp
			await _pass(0.1)
			if GameState.activity != a: return
		if GameState.activity == a:
			_line("[봇] %s 을 이긴 셈 친다" % a.type)
			Story._end_drill(true)
		return
	if a.get("type") == "SPAR":   # 티아맷과 대련: 기력을 비워 이긴 셈 친다
		_line("[봇] 대련을 이긴 셈 친다")
		a.hp = 0.0
		return await _pass(1)
	if a.get("type") == "TAG" and a.get("npc"):   # 술래잡기: 곁으로 가서 잡는다
		GameState.player.x = a.npc.x; GameState.player.y = a.npc.y
		return await _pass(1)
	await _pass(3)


## 대련 · 술래잡기 대목: 그 용 곁으로 가서 판을 바로 연다 (말을 걸면 메뉴가 떠서 헛걸음으로 찍히던 것)
func _play_with(who: String):
	var n = World.any_npc(who)
	if not n or not GameState.entities.npcs.has(n) or n.is_hidden: return await _visit(who)
	await _walk_to(n.x - 60, n.y)
	if _busy() or GameState.activity: return
	_line("[봇] %s와 %s" % [Names.npc(who), "대련한다" if who == "Tiamat" else "술래잡기를 한다"])
	if who == "Tiamat": NpcActions._go_spar(n)
	else: NpcActions._start_tag(n)
	await _pass(2)


## 보스: 그 둥지로 가서 깨어나기를 기다렸다가 쓰러뜨린다 (한 대에). 장면이 끼는 판은 넘기며 기다린다
func _boss(id: String):
	var at = Guide._boss_place(id)
	if at == null:
		_line("[봇] 보스 %s 의 자리를 모른다" % id)
		_until = -1
		return
	if GameState.map_id != at.map:
		await _go(at.map)
		return
	var b = null
	for x in GameState.entities.bosses:
		if x.id == id and not x.remove: b = x
	if b == null: return await _pass(5)   # 사건을 겪어야 둥지에 보스가 있다
	var p = GameState.player
	await _walk_to(b.x, b.y + 380)
	p.hp = p.max_hp
	if not b.awake or b.dying > 0 or b.lingering or not Combat.hittable(b): return await _pass(2)
	_line("[봇] %s 을 친다" % b.def.name)
	b.take_damage(b.hp + 1)
	await _pass(1)


## 그 자리에 가 있기: 대목이 가리키는 자리(where · glint)로 가서 기다린다. 자리가 없으면 그 사건이 열릴 때까지 기다린다
func _event(st: Dictionary):
	var at = st.get("where") if st.get("where") else st.get("glint")
	if at == null:
		if _event_wait != str(st.goal.target):
			_event_wait = str(st.goal.target)
			_line("[봇] 사건(%s)을 기다린다" % st.goal.target)
		return await _pass(10)
	if GameState.map_id != at.map:
		await _go(at.map)
		return
	var w := World.at(at.get("spot", at.get("at")))
	await _walk_to(w.x, w.y + 60)
	await _pass(4)


func _defend():
	var foes: Array = GameState.entities.enemies.filter(func(e): return not e.remove and e.type != "PREY" and e.type != "DUMMY")
	if foes.is_empty(): return await _pass(2)
	var e = foes[0]
	await _walk_to(e.x - 200, e.y)
	if is_instance_valid(e) and not e.remove: e.take_damage(99999)
	GameState.player.hp = GameState.player.max_hp


func _sleep():
	if GameState.map_id != "DEN_MINE":
		if not await _go("DEN_MINE"): return
	var nests = GameState.entities.nests
	if nests.is_empty(): return await _pass(5)
	await _walk_to(nests[0].x, nests[0].y + 40)
	if _busy(): return
	_line("[봇] 잠자리에 눕는다")
	Story.open_nest_menu()


# ---------- 시간 ----------

## 게임 시간으로 sec 초 (대화 · 장면이 뜨면 거기서 멈춘다)
func _pass(sec: float):
	var t0 := GameState.game_time
	while GameState.game_time - t0 < sec:
		await get_tree().process_frame
		_watch()
		if DialogueBox.is_open() or Cutscene.on or GameState.prologue: return


func _real(sec: float):
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000:
		await get_tree().process_frame
		_watch()
