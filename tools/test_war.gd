extends Node
## 6장 전쟁(H)을 처음부터 끝까지 흘려 본다 (docs/lore.md 6-1).
## 폭포의 대치 → 나라를 막아선다 → 유안과 겨루기 → 잿빛 비늘 → 베르단의 습격 · 그론 → 장례 → 티아맷의 발톱 자국 → 두 촌장 · 이그나르의 이름.
## 줄마다 [6장] OK/FAIL 을 찍고, 끝에 실패 수를 센다. 저장은 9번 칸만 쓴다.
##   godot --headless --path . res://tools/test_war.tscn

var _box: DialogueBox
var _seen := []
var _fails := 0
var _last := 0
var _want := ""   # 고를 것이 뜨면 이 글로 시작하는 줄을 고른다 (없으면 첫 줄)


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
	G.raidTimer = 99999
	# 여기서 볼 사건만 남기고 모두 본 것으로 둔다 (다른 사건이 끼어들지 않게)
	for ev in Data.get_module("chronicle").CHRONICLE:
		if not ev.id in ["ev_border", "ev_ash_scale"]: G.story.events.append(ev.id)
	G.quests.done = ["m0", "m1", "m2", "m3", "m4", "m5", "m5g", "m5a", "p1", "s1"]
	G.quests.choices = { p1 = "told", m3 = "press" }
	G.story.trystDay = 1
	G.player.stage_index = 2
	G.player.max_hp = 5000.0; G.player.hp = 5000.0
	for nm in Data.get_module("npcTalk").BOND_SCENES:
		for tier in [1, 2, 3]: G.story.bonds.append("%s:%d" % [nm, tier])
	var m6w = Quests.by_id("m6w")
	Quests.accept(m6w)
	await _wait(0.5)

	# ---- 다친 티아맷 ----
	Quests.notify("talk", "Tiamat")
	await _play_until(_idle, 20)
	_check("티아맷: 누가 뒤에서 물었어", _saw("누가 뒤에서 물었어"))
	_check("다음은 폭포", _step(), 1)

	# ---- 폭포의 대치: 부딪히고, 갈라서고, 나라를 막아선다 ----
	World.travel_to("FALLS")
	G.dayTime = 0.4
	_want = "나라를 막아선다"
	await _play_until(func(): return G.activity != null, 40)
	_check("대치: 두 줄이 부딪힌다 (목은 안 문다)", _saw("목을 무는 용은 없다"))
	_check("대치: 리운과 카이론이 갈라놓는다", _saw("구름마루는 뒤로 물러나라") and _saw("쓰러진 애들부터 끌어내"))
	_check("대치: 나라가 쳐들어가자고 한다", _saw("구름마루로, 오늘 밤에요"))
	_check("대치: 막아선 줄 (stop)", _saw("아랫마을 꼬맹이가 저러는데") and not _saw("그렇지! 가자!"))
	_check("대치에서 고른 것을 적는다", G.story.get("choices", {}).get("ev_border"), "stop")
	_check("대치에서는 습격이 오지 않는다", G.raid.active, false)
	var a = G.activity
	_check("겨루기: 상대는 유안", a.npc.config.name if a else "-", "Yuan")
	_check("겨루기: 유안의 이름패 · 물", [a.get("label"), a.get("element")] if a else [], ["구름마루의 유안", "WATER"])
	_check("겨루기: 유안이 이 지도에 있다", G.entities.npcs.has(a.npc) if a else false)
	_check("겨루기 대목", _step(), 2)
	# 이긴다
	if a: a.hp = 0.0
	await _play_until(func(): return _step() == 3 and _idle(), 30)
	_check("겨루기 뒤: 유안 '같은 자세라 수가 다 읽혔겠지'", _saw("수가 다 읽혔겠지"))
	_check("겨루기 뒤: 저쪽 아이도 등을 물렸다", _saw("등을 물렸다고"))
	_check("다음은 싸움터 살피기 (화살표 없음)", [_step(), Guide._wanted() == null], [3, true])

	# ---- 잿빛 비늘: 멀리서는 안 보이고, 반짝이는 자리 가까이 가야 ----
	var spot := World.at(Quests.cur_step(m6w).glint.at)
	_check("비늘 자리는 걸어갈 수 있는 곳", not Collision.solid_at(spot.x, spot.y, 18))
	G.player.x = spot.x - 900; G.player.y = spot.y
	await _wait(2.5)
	_check("멀리서는 비늘을 못 찾는다", G.story.events.has("ev_ash_scale"), false)
	G.player.x = spot.x - 60; G.player.y = spot.y
	await _play_until(func(): return G.raid.active, 30)
	_check("비늘: 두 마을 어느 쪽 것도 아니다", _saw("구름마루 용 비늘은 물빛이다"))
	_check("비늘: 단서 ash", G.story.clues.has("ash") and Data.get_module("chronicle").CLUES.has("ash"))
	_check("나팔: 마을로 돌아와 전쟁 습격", [G.map_id, G.raid.get("kind")], ["VILLAGE", "war"])
	_check("습격 대목", _step(), 4)

	# ---- 베르단의 습격 · 그론 ----
	var t := Time.get_ticks_msec()
	while G.raid.active and Time.get_ticks_msec() - t < 30000:
		for h in G.entities.humans:
			if not h.remove: h.take_damage(99999)
		await get_tree().process_frame
		_advance()
	await _play_until(func(): return _step() == 5 and _idle(), 40)
	_check("습격 끝: 베르단이 물러간다", _saw("베르단의 뿔피리"))
	_check("그론이 포코를 덮었다", _saw("아저씨가 나 덮었어") and G.story.get("dead", []).has("Gron"))

	# ---- 장례 ----
	Story.sleep()
	await _play_until(func(): return _step() == 6 and _idle(), 60)
	_check("장례: 카이론 '다시는 마을을 비우지 않겠소'", _saw("다시는 마을을 비우지 않겠소"))
	_check("장례 뒤: 티아맷에게 비늘을 보인다", _step(), 6)

	# ---- 티아맷: 지도의 발톱 자국 ----
	Quests.notify("talk", "Tiamat")
	await _play_until(_idle, 30)
	_check("티아맷: 발톱 자국과 비늘 크기", _saw("비늘이 이만하면 발톱도"))
	_check("티아맷: 지도를 그린 놈 = 뒤에서 문 놈", _saw("같은 놈이라고"))
	_check("보고만 남는다", Quests.is_complete(m6w))

	# ---- 두 촌장 · 이그나르의 이름 ----
	Quests.turn_in(m6w, World.any_npc("Elder"), null)
	await _play_until(func(): return G.quests.done.has("m6w") and _idle(), 60)
	_check("두 촌장은 폭포에서", G.map_id, "FALLS")
	_check("리운: 같은 놈한테 물린 것", _saw("같은 놈한테 물린 것이구려"))
	_check("리운: 막아선 걸 안다 (stop)", _saw("막아섰다고 유안이") and not _saw("쳐들어가자고 한 거, 저예요"))
	_check("엘더가 이름을 말한다", _saw("내가 말한 예외가 그 아이란다"))
	_check("p1 · m3=press 를 읽는다", _saw("이제는 이르지 않구나") and _saw("이름만은 묻지 말아 달라고"))
	_check("두 마을이 발톱을 거둔다", _saw("발톱을 거두겠소"))
	_check("다음은 사막 (불탄 도시)", _saw("사막 너머에 그 아이가 태운 도시가"))

	# ---- 6장 요약 (일지): 고른 줄만 ----
	var recap: Array = []
	for c in Data.get_module("chapters").CHAPTERS:
		if c.id == "c6": recap = c.recap.filter(func(l): return Chronicle._chosen(l)).map(func(l): return l.text)
	var all := " ".join(recap)
	_check("요약: 막아선 줄만", all.contains("나는 나라를 막아섰다") and not all.contains("나는 나라 곁에 섰다"))
	_check("요약: 비늘과 발톱 자국", all.contains("잿빛 비늘") and all.contains("발톱 자국"))

	# ---- 옛 세이브: 대목 번호를 옮긴다 ----
	Save.save_game()
	_check("새 세이브에는 표시가 있다 (3)", Save.read().get("questLayout"), 3)
	for case in [
		{ what = "옛 m6w 대치(1) → 새 1", old = 1, want = 1 },
		{ what = "옛 m6w 습격(2) → 새 4", old = 2, want = 4 },
		{ what = "옛 m6w 장례(3) → 새 5", old = 3, want = 5 },
		{ what = "옛 m6w 보고만 남음(4) → 새 티아맷(6)", old = 4, want = 6 },
	]:
		_check(case.what, _load_old(case.old), case.want)
	print("[끝] 실패 %d" % _fails)
	get_tree().quit()


func _step() -> int:
	var e = GameState.quests.active.get("m6w")
	return int(e.step) if e else -1


## 옛 세이브(questLayout 2)처럼 꾸며 불러오고 m6w 의 대목 번호를 돌려준다
func _load_old(step: int) -> int:
	var data: Dictionary = Save.read()
	data.questLayout = 2
	data.quests.active = { m6w = { step = step, n = 0 } }
	data.quests.done = ["m0", "m1", "m2", "m3", "m4", "m5", "m5g", "m5a"]
	data.story.events = data.story.events.filter(func(id): return not id in ["ev_border", "ev_ash_scale"])   # 옛 판은 새 사건을 본 적이 없다
	Save.apply(data)
	return int(GameState.quests.active.get("m6w", { step = -1 }).step)


func _check(what: String, got, want = true) -> void:
	var ok: bool = str(got) == str(want)
	if not ok: _fails += 1
	print("[6장] %s %s%s" % ["OK  " if ok else "FAIL", what, "" if ok else "  (%s · 기대 %s)" % [str(got), str(want)]])


func _saw(needle: String) -> bool:
	return _seen.any(func(t): return t.contains(needle))


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000:
		await get_tree().process_frame
		_advance()


func _idle() -> bool:
	return GameState.questScenes.is_empty() and not Chronicle._playing and not DialogueBox.is_open() and not Cutscene.on


func _play_until(cond: Callable, sec: float) -> void:
	var t := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t < sec * 1000:
		await get_tree().process_frame
		_advance()


## 장면을 넘긴다. 뜬 글은 모아 두고, 고를 것이 있으면 _want 로 시작하는 줄(없으면 첫 줄)을 고른다
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
	var pick := 0
	for i in _box._list.size():
		if _want != "" and str(_box._list[i].label).begins_with(_want): pick = i
	_box._choose(pick)
