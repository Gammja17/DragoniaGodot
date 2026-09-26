extends Node
## 마을 이웃 이야기를 흘려 본다.
##   도란 "큰 놈"(dr1): 물고기 셋 → 한낮엔 큰 놈이 안 올라온다 → 해 뜰 무렵에 올라온다(진짜 낚시로) → 그론 → 보고 → 도란의 낚싯대
##   단네 식구 "누리의 첫 숲길"(sn1): 해 지면 저녁상 → 다음 날 숲 어귀 → 소이에게 보고
##   하루 "아래 세상 돌멩이"(hr1) · 세이란 "고인 물"(sr1) · 유안 "누이의 알"(yu1) · 엠버 "아저씨의 규칙"(em1)
##   그리고 바늘을 보여 줄 그론이 먼저 떠나면 그 대목을 거두는지.
## 줄마다 [이웃] OK/FAIL 을 찍고, 끝에 실패 수를 센다. 저장은 9번 칸만 쓴다.
##   godot --headless --path . res://tools/test_neighbors.tscn

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
	G.day = 5
	G.dayTime = 0.5
	G.weather.type = "CLEAR"
	G.story.scenes = ["ch1"]
	G.quests.done = ["m0", "m1", "m1n", "m2", "m3", "m4"]
	G.visited.append("LAKE")
	for ev in Data.get_module("chronicle").CHRONICLE:
		if not ev.id in ["ev_nuri_dinner", "ev_nuri_forest", "ev_haru_pebble", "ev_haru_stones", "ev_seiran_pool", "ev_yuan_egg", "ev_yuan_tower", "ev_miru_nest", "ev_doran_sorry"]: G.story.events.append(ev.id)
	G.tutorial.hints = {}
	for h in Tutorial._hints(): G.tutorial.hints[h.id] = true   # 안내가 끼어들어 자리를 옮기지 않게
	var p: Dragon = G.player
	p.max_hp = 5000.0; p.hp = 5000.0
	var doran = World.any_npc("Doran")
	var gron = World.any_npc("Gron")
	var soi = World.any_npc("Soi")

	# ---------- 도란: 큰 놈 ----------
	var offer = Quests.offer_for(doran)
	_check("도란이 '큰 놈'을 꺼낸다", offer.id if offer else "", "dr1")
	Quests.accept(Quests.by_id("dr1"))
	await _travel("LAKE")
	_stand_by_water()
	for i in 3: await _fish()
	await _play_until(_idle, 20)
	_check("세 마리 낚으면 큰 놈 얘기를 듣는다", _saw("해 뜰 무렵에만 올라와"))
	_check("다음 대목: 큰 놈", _step("dr1"), 1)
	# 한낮: 큰 놈이 아니다
	G.dayTime = 0.5
	var big_noon := await _fish()
	_check("한낮에는 큰 놈이 안 올라온다", big_noon, false)
	_check("여전히 큰 놈 대목이다", _step("dr1"), 1)
	# 해 뜰 무렵 (여섯 시)
	G.dayTime = 0.25
	var big_dawn := await _fish()
	_check("해 뜰 무렵에는 큰 놈이 문다", big_dawn, true)
	await _play_until(_idle, 20)
	_check("큰 놈 주둥이에 낡은 바늘", _saw("낡은 낚싯바늘이 걸려 있다"))
	_check("다음 대목: 그론에게", _step("dr1"), 2)
	await _travel("VILLAGE")
	await _talk(gron)
	_check("그론이 제 바늘을 알아본다", _saw("내가 벼린 게 맞다"))
	await _talk(doran)
	_check("도란에게 보고하고 끝낸다", G.quests.done.has("dr1"))
	_check("도란의 낚싯대를 받는다", _saw("이 낚싯대 가져가게"))
	# 낚싯대: 입질이 더 오래 기다려 준다
	await _travel("LAKE")
	_stand_by_water()
	p.interact()
	p.fishing.wait = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	_check("낚싯대가 있으면 입질이 1.6초 기다려 준다 (%.2f)" % p.fishing.bite, p.fishing.bite > 1.4)
	p.fishing = null

	# ---------- 단네 식구: 누리의 첫 숲길 ----------
	await _travel("VILLAGE")
	offer = Quests.offer_for(soi)
	_check("소이가 저녁상 얘기를 꺼낸다", offer.id if offer else "", "sn1")
	Quests.accept(Quests.by_id("sn1"))
	G.dayTime = 0.4   # 한낮에는 저녁상이 없다
	p.x = 26 * 96 + 48; p.y = 19 * 96 + 48 + 120
	await _play_until(func(): return false, 3)
	_check("한낮에 가면 아직 저녁상이 없다", _step("sn1"), 0)
	G.dayTime = 0.76   # 저녁 여섯 시 무렵
	p.x = 26 * 96 + 48; p.y = 19 * 96 + 48 + 120
	await _play_until(func(): return _step("sn1") == 1 and _idle(), 30)
	_check("해 지면 저녁상이 차려진다", _saw("내 그릇이 빌 때마다"))
	_check("단이 내일 숲에 데려가겠다고 한다", _saw("누리는 내 옆에서 한 발짝도 떨어지지 말고"))
	# 같은 날 숲에 가면 아직이다 ("내일")
	await _travel("EAST_ROAD")
	G.dayTime = 0.5
	await _play_until(func(): return false, 3)
	_check("같은 날에는 숲 장면이 안 열린다", _step("sn1"), 1)
	G.day += 1
	G.dayTime = 0.4
	await _play_until(func(): return Quests.is_complete(Quests.by_id("sn1")) and _idle(), 30)
	_check("다음 날 숲 어귀에서 단이 아버지 얘기를 한다", _saw("골짜기 끝으로 마른 나무를 베러 갔다가"))
	_check("단: 무서웠던 거다", _saw("무서웠던 거다"))
	await _travel("VILLAGE")
	await _talk(soi)
	_check("소이에게 보고하고 끝낸다", G.quests.done.has("sn1"))
	_check("누리가 보물을 준다", _saw("제일 반짝이는 거래"))
	_check("누리의 조약돌이 굴 꾸미기 물건으로 들어온다", Den.owned("PEBBLE_NURI"), 1)

	# ---------- 뒷장의 넷: 하루 · 세이란 · 유안 · 엠버 ----------
	G.quests.done.append_array(["m5", "m5g", "m5a", "m6w", "m5b", "m5c"])
	G.bossesDefeated.GLACIA = true
	var haru = World.any_npc("Haru")
	var seiran = World.any_npc("Seiran")
	var yuan = World.any_npc("Yuan")
	var ember = World.any_npc("Ember")
	var kairon = World.any_npc("Kairon")
	var tiamat = World.any_npc("Tiamat")

	# 하루: 분수의 조약돌 → 하루에게 → 낮에 폭포 아래 징검돌 → 보고
	offer = Quests.offer_for(haru)
	_check("하루가 돌멩이를 부탁한다", offer.id if offer else "", "hr1")
	Quests.accept(Quests.by_id("hr1"))
	G.dayTime = 0.5
	p.x = 17 * 96 + 48; p.y = 12 * 96 + 48 + 150
	await _play_until(func(): return _step("hr1") == 1 and _idle(), 20)
	_check("분수에서 조약돌을 고른다 (포코가 끼어든다)", _saw("포코 돌"))
	await _talk(haru)
	_check("하루가 징검돌 얘기를 한다", _saw("아래 돌 하나, 위 돌 하나"))
	await _travel("FALLS")
	await _play_until(func(): return Quests.is_complete(Quests.by_id("hr1")) and _idle(), 30)
	_check("폭포 아래 징검돌 여섯 개", _saw("징검돌 여섯 개"))
	_check("하루가 폭포의 일을 사과한다", _saw("미안했어"))
	await _talk(haru)
	_check("하루의 부탁을 마친다", G.quests.done.has("hr1"))

	# 세이란: 한낮엔 샘이 조용하다 → 밤에 구름마루 샘 → 보고
	offer = Quests.offer_for(seiran)
	_check("세이란이 밤에 샘으로 오라고 한다", offer.id if offer else "", "sr1")
	Quests.accept(Quests.by_id("sr1"))
	await _travel("CLOUDTOP")
	G.dayTime = 0.5
	await _play_until(func(): return false, 3)
	_check("한낮에는 샘 장면이 안 열린다", _step("sr1"), 0)
	G.dayTime = 0.9
	await _play_until(func(): return Quests.is_complete(Quests.by_id("sr1")) and _idle(), 30)
	_check("세이란이 처음 물을 읽은 얘기를 한다", _saw("여섯 살 때였어"))
	_check("세이란이 제 앞날을 읽는다", _saw("앞날이 안 보이는 게 이렇게 편한 줄 몰랐네"))
	await _talk(seiran)
	_check("세이란의 부탁을 마친다", G.quests.done.has("sr1"))

	# 유안: 봉우리의 알 벽 → 낮에 폭포 아래 망루 자리 (티아맷) → 보고
	offer = Quests.offer_for(yuan)
	_check("유안이 봉우리에 같이 가 달라고 한다", offer.id if offer else "", "yu1")
	Quests.accept(Quests.by_id("yu1"))
	await _travel("GLACIA_LAIR")
	await _play_until(func(): return _step("yu1") == 1 and _idle(), 30)
	_check("유안이 누이 알 앞에 창을 둔다", _saw("이제 여기 둔다"))
	G.dayTime = 0.5
	await _travel("FALLS")
	await _play_until(func(): return Quests.is_complete(Quests.by_id("yu1")) and _idle(), 30)
	_check("티아맷과 유안이 망루를 같이 세운다", _saw("망루는 둘이 서면 덜 추워"))
	await _talk(yuan)
	_check("유안의 부탁을 마친다", G.quests.done.has("yu1"))
	_check("하루의 돌이 굴 꾸미기 물건으로 들어온다", Den.owned("STONE_HARU"), 1)
	# 이야기 흔적: 다시 폭포에 오면 징검돌과 망루가 서 있다
	await _travel("VILLAGE")
	await _travel("FALLS")
	var stones: Array = G.entities.props.filter(func(x): return x.type == "STEPSTONE")
	_check("폭포 아래 징검돌 여섯 (그림 하나에 돌 셋)", stones.size(), 2)
	_check("폭포 아래 망루", G.entities.props.any(func(x): return x.type == "TOWER"))

	# 엠버: 카이론에게 까닭을 묻고 → 엠버 → 티아맷에게 방패 → 보고
	await _travel("VILLAGE")
	offer = Quests.offer_for(ember)
	_check("엠버가 창 부탁 얘기를 꺼낸다", offer.id if offer else "", "em1")
	Quests.accept(Quests.by_id("em1"))
	await _talk(kairon)
	_check("카이론이 그론의 창 얘기를 한다", _saw("무기를 쥐여 주면 그놈이 앞에 선다고"))
	await _talk(ember)
	_check("엠버가 창 대신 방패를 만든다", _saw("망루에 세울 방패를 만들 거야"))
	await _talk(tiamat)
	_check("티아맷이 방패를 받는다", _saw("이제는 엠버답다고 해야 하나"))
	await _talk(ember)
	_check("엠버의 부탁을 마친다", G.quests.done.has("em1"))

	# ---------- 도란의 사과: 그론을 보낸 뒤 저녁에 도란네 앞을 지나면 ----------
	G.dayTime = 0.75
	p.x = 6 * 96 + 48; p.y = 10 * 96 + 48 + 150
	await _play_until(func(): return G.story.events.has("ev_doran_sorry") and _idle(), 30)
	_check("저녁에 도란네 앞을 지나면 도란이 사과한다", _saw("처음 꺼낸 게 나여"))
	_check("미루가 늘 받던 자리의 고기", _saw("미루가 늘 받던 그 자리"))

	# ---------- 미루 "옛 둥지": 새 알이 생긴 뒤 ----------
	Story.on_flag("couple_egg")
	G.story.restUntil = G.day + 1   # 큰 대목을 마친 날
	var rest_goal := str(Quests.suggestion().goal)
	print("  쉬는 날 추적창: ", rest_goal)
	_check("쉬는 날 추적창이 그날 들을 이웃 이야기를 같이 알려 준다", rest_goal.contains("할 말이 있는 눈치다"))
	G.story.erase("restUntil")
	var miru = World.any_npc("Miru")
	offer = Quests.offer_for(miru)
	_check("미루가 옛 둥지 얘기를 꺼낸다", offer.id if offer else "", "mi1")
	Quests.accept(Quests.by_id("mi1"))
	await _play_until(func(): return Quests.is_complete(Quests.by_id("mi1")) and _idle(), 30)
	_check("옛 둥지는 포코와 누리의 비밀 기지였다", _saw("여기 우리 비밀 기지인데"))
	await _talk(doran)
	_check("도란이 스무 해 만에 예쁘다고 한다", _saw("오늘 좀… 예쁘구먼"))
	_check("미루의 옛 둥지를 마친다", G.quests.done.has("mi1"))

	# ---------- 바늘을 보여 줄 그론이 먼저 떠나면 ----------
	G.quests.done.erase("dr1")
	G.quests.active.dr1 = { step = 2, n = 0 }
	Story._kill_npc("Gron")
	_check("그론이 떠나면 바늘 대목을 거둔다", G.quests.active.has("dr1"), false)
	_check("그론이 떠난 뒤로는 '큰 놈'을 꺼내지 않는다", Quests._ready_quest(Quests.by_id("dr1")), false)

	# 결말의 "그 뒤로": 들어준 이웃들의 이야기가 이어진다 (많으면 넷까지, 어둠의 길은 빼고)
	G.quests.done.append_array(["dr1"])
	var life: Array = Ending.life_lines("guardian")
	var told := life.filter(func(t): return t.contains("새 망루에서도") or t.contains("징검돌은") or t.contains("창 대신 방패") or t.contains("숲 어귀까지") or t.contains("큰 놈의 새끼") or t.contains("별비늘"))
	_check("결말에 이웃 이야기가 넷 이어진다", told.size(), 4)
	_check("어둠의 길 결말에는 없다", Ending.life_lines("dark").any(func(t): return t.contains("징검돌")), false)

	print("[끝] 실패 %d" % _fails)
	get_tree().quit(1 if _fails else 0)


## 물가 가까이 선다: 이 지도에서 물에서 110px 안쪽의 뭍을 찾는다
func _stand_by_water() -> void:
	var p: Dragon = GameState.player
	var b := Terrain.current_map_bounds()
	for y in range(200, int(b.y) - 200, 48):
		for x in range(200, int(b.x) - 200, 48):
			if Terrain.ground_at(x, y) == "WATER" or Collision.solid_at(x, y, 20): continue
			p.x = x; p.y = y
			if p._near_water() != null: return


## 한 번 낚는다: 줄을 드리우고, 입질이 오면 당긴다. 큰 놈이었으면 true
func _fish() -> bool:
	var p: Dragon = GameState.player
	_calm()
	p.interact()
	if p.fishing == null: return false
	var big: bool = p.fishing.get("big", false)
	p.fishing.wait = 0.0
	var t := Time.get_ticks_msec()
	while p.fishing != null and p.fishing.bite <= 0 and Time.get_ticks_msec() - t < 3000:
		await get_tree().process_frame
		_advance()
	if p.fishing == null or p.fishing.bite <= 0:
		print("  (입질이 안 왔다: 대화 %s 장면 %s)" % [GameState.isDialogueOpen, Cutscene.on])
		return false
	p.interact()
	for i in 3: await get_tree().process_frame
	return big


## 지도를 옮긴다 (막 옮긴 참이면 잠깐 기다린다: 포탈을 되밟지 않게 0.35초 동안은 옮기지 않는다)
func _travel(id: String) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 400: await get_tree().process_frame
	World.travel_to(id)
	await get_tree().process_frame


func _step(id: String) -> int:
	var e = GameState.quests.active.get(id)
	return int(e.step) if e else -1


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
	print("[이웃] %s %s%s" % ["OK  " if ok else "FAIL", what, "" if ok else "  (%s · 기대 %s)" % [str(got), str(want)]])


func _saw(needle: String) -> bool:
	return _seen.any(func(t): return t.contains(needle))


func _idle() -> bool:
	return GameState.questScenes.is_empty() and not Chronicle._playing and not DialogueBox.is_open() and not Cutscene.on and not Hud.fading()


func _play_until(cond: Callable, sec: float) -> void:
	var t := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t < sec * 1000:
		await get_tree().process_frame
		_calm()
		_advance()


## 둘레의 적을 치운다 (싸우는 중에는 장면이 기다린다)
func _calm() -> void:
	for e in GameState.entities.enemies:
		if e.type != "DUMMY": e.remove = true


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
	if labels.size() > 1 and labels[0] == "💬 이야기를 나눈다":
		NpcActions.close()
		return
	_box._choose(0)
