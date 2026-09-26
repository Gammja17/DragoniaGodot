extends Node
## 하늘에서 덮치는 낚시: 물 위를 날아야 그림자가 보인다 · 작은 놈은 탁 · 큰 놈은 힘을 다 모아야 · 오래 노려보면 달아난다 ·
## 종류는 곳 · 때 · 날씨 · 그날 밤의 일에 따라 다르다 · 낚싯대로는 작은 것만 · 잡은 것은 일지의 도감에.
## 줄마다 [낚시] OK/FAIL 을 찍고, 끝에 실패 수를 센다. 저장은 9번 칸만 쓴다.
##   godot --headless --path . res://tools/test_fishing.tscn

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
	G.day = 10
	G.dayTime = 0.45
	for ev in Data.get_module("chronicle").CHRONICLE: G.story.events.append(ev.id)   # 사건이 끼어들지 않게
	var p: Dragon = G.player
	World.travel_to("LAKE")
	await get_tree().process_frame
	var lake := Vector2(GameMap.coarse_center(8), GameMap.coarse_center(10))   # 호수 한가운데 (maps.json LAKE ponds)

	# 물가에 서서는 물속이 안 보인다
	_stand_by_water()
	await _play(1.5)
	_check("물가에 서서는 그림자가 안 보인다", DiveFish.shadows.size(), 0)
	# 물 위를 날면 그림자가 떠오른다. 물 위에만
	p.flying = true
	p.x = lake.x; p.y = lake.y
	await _play(4.0)
	_check("물 위를 날면 그림자가 떠오른다 (%d)" % DiveFish.shadows.size(), DiveFish.shadows.size() > 0)
	_check("그림자는 물 위에만 있다", DiveFish.shadows.all(func(s): return Terrain.ground_at(s.x, s.y) == "WATER"))

	# 작은 놈: 발밑에 두고 탁 누르면 잡힌다 (고기 · 도감)
	DiveFish.shadows.clear()
	DiveFish.shadows.append(_shadow("minnow", p.x + 10, p.y))
	var meat0: int = p.inventory.meat
	var fish0 := int(G.stats.get("fish", 0))
	DiveFish.charge = 0.0   # 눌렀다가 곧 뗀 셈
	await _play(1.0)
	_check("작은 놈을 덮쳐 잡는다 (물고기 · 고기)", [int(G.stats.get("fish", 0)) - fish0, p.inventory.meat - meat0], [1, 1])
	_check("도감에 적힌다", int(G.stats.get("fishKinds", {}).get("minnow", 0)), 1)
	_check("처음 잡은 물고기는 알림으로", _popped("처음 잡았다: 피라미"))

	# 큰 놈: 힘이 모자라면 빠져나가고, 다 모아 덮치면 잡힌다
	DiveFish.shadows.clear()
	DiveFish.shadows.append(_shadow("oldcarp", p.x, p.y))
	DiveFish.charge = 0.3
	await _play(1.0)
	_check("힘이 모자라면 큰 놈이 빠져나간다", G.stats.get("fishKinds", {}).has("oldcarp"), false)
	_check("큰 놈을 놓치면 힘을 모으라는 알림", _popped("꾹 눌러 힘을 다 모았다가"))
	DiveFish.shadows.clear()
	DiveFish.shadows.append(_shadow("oldcarp", p.x, p.y))
	meat0 = p.inventory.meat
	DiveFish.charge = 1.0
	await _play(1.0)
	_check("힘을 다 모아 덮치면 큰 놈이 잡힌다 (고기 3)", [int(G.stats.get("fishKinds", {}).get("oldcarp", 0)), p.inventory.meat - meat0], [1, 3])

	# 너무 오래 노려보면 큰 놈이 눈치채고 달아난다
	DiveFish.shadows.clear()
	var big := _shadow("oldcarp", p.x, p.y)
	DiveFish.shadows.append(big)
	Input.action_press("confirm")
	await get_tree().process_frame
	DiveFish.charge = 0.0
	DiveFish.held = 0.0
	var spooked := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4500:
		big.x = p.x; big.y = p.y; big.next_dash = 99.0   # 발밑에 가만히 있는 큰 놈
		await get_tree().process_frame
		if big.dash > 0.5:
			spooked = true
			break
	Input.action_release("confirm")
	_check("오래 노려보면 큰 놈이 눈치채고 달아난다", spooked)
	await _play(1.0)
	_check("덮치기가 끝나면 몸이 제자리로", [DiveFish.busy(), p.dive_height], [false, 0.0])

	# 종류는 곳 · 때 · 날씨 · 그날 밤의 일에 따라 다르다
	G.weather.type = "CLEAR"; G.weather.storm = false; G.event = null
	G.dayTime = 0.45
	_check("맑은 한낮의 호수: 피라미 · 붕어 · 늙은 잉어", _ids(DiveFish.eligible(true)), ["minnow", "crucian", "oldcarp"])
	G.weather.type = "RAIN"
	_check("비가 오면 무지개송어가 올라온다", _ids(DiveFish.eligible(true)).has("rainbow"))
	G.weather.storm = true
	_check("폭풍 치는 호수에는 폭풍가오리", _ids(DiveFish.eligible(true)).has("stormray"))
	G.weather.type = "CLEAR"; G.weather.storm = false
	G.event = "BLOOD_MOON"
	G.dayTime = 22.0 / 24
	_check("붉은 달이 뜬 밤: 붉은뱀장어 · 밤의 호수: 달빛메기", [_ids(DiveFish.eligible(true)).has("bloodeel"), _ids(DiveFish.eligible(true)).has("catfish")], [true, true])
	_check("낚싯대로는 큰 놈이 안 걸린다", DiveFish.eligible(false).all(func(k): return not k.get("big")))
	G.event = null
	for i in 20:
		if DiveFish.rod_catch().get("big"): _check("낚싯대에 큰 놈이 걸렸다", false)
	G.dayTime = 0.45

	# 착지하면 그림자를 거둔다
	p.flying = false
	_stand_by_water()
	await _play(0.5)
	_check("내려앉으면 그림자가 걷힌다", DiveFish.shadows.size(), 0)
	# 낚싯대로 잡은 것도 도감에 적힌다
	var kinds0 := _book_total()
	p.interact()
	_check("물가에서 낚싯줄을 드리운다", p.fishing != null)
	if p.fishing:
		p.fishing.wait = 0.0
		await get_tree().process_frame
		await get_tree().process_frame
		p.interact()
	_check("낚싯대로 잡은 것도 도감에 적힌다", _book_total(), kinds0 + 1)
	# 하늘에서는 낚싯줄 대신 덮친다
	p.flying = true
	p.x = lake.x; p.y = lake.y
	p.interact()
	_check("날면서는 낚싯줄을 드리우지 않는다", p.fishing, null)
	p.flying = false

	# 폭포: 아침엔 폭포연어, 달맞이 모임 밤엔 달맞이잉어
	World.travel_to("FALLS")
	await get_tree().process_frame
	G.dayTime = 7.0 / 24
	_check("아침의 폭포: 폭포연어", _ids(DiveFish.eligible(true)).has("salmon"))
	G.story.eventDay = { ev_gathering = G.day }
	G.dayTime = 21.0 / 24
	_check("달맞이 모임 밤의 폭포: 달맞이잉어", _ids(DiveFish.eligible(true)).has("moonkoi"))
	G.story.erase("eventDay")

	# 일지 [기록]의 물고기 도감: 잡은 것은 이름과 마릿수, 못 잡은 것은 어디서 · 언제
	var j = Hud.current.journal
	j.toggle_tab("record")
	await get_tree().process_frame
	var texts := _texts(j)
	_check("도감 제목 (잡은 종류 / 전체)", texts.any(func(t): return t.begins_with("물고기 도감 ") and t.ends_with("/ 14")))
	_check("잡은 것: 늙은 잉어", texts.has("늙은 잉어"))
	_check("못 잡은 것은 어디서 · 언제", texts.any(func(t): return t.contains("폭풍이 치는 날, 신비의 호수에서")))

	print("[끝] 실패 %d" % _fails)
	get_tree().quit(1 if _fails else 0)


func _shadow(id: String, x: float, y: float) -> Dictionary:
	var k: Dictionary = DiveFish.kinds().filter(func(f): return f.id == id)[0]
	return { x = x, y = y, a = 0.0, kind = k, big = bool(k.get("big", false)), age = 3.0, life = 60.0, dash = 0.0, next_dash = 99.0, seed = 0.0 }


func _ids(list: Array) -> Array: return list.map(func(k): return k.id)


func _book_total() -> int:
	var n := 0
	for id in GameState.stats.get("fishKinds", {}): n += int(GameState.stats.fishKinds[id])
	return n


func _stand_by_water() -> void:
	var p: Dragon = GameState.player
	var b := Terrain.current_map_bounds()
	for y in range(200, int(b.y) - 200, 48):
		for x in range(200, int(b.x) - 200, 48):
			if Terrain.ground_at(x, y) == "WATER" or Collision.solid_at(x, y, 20): continue
			p.x = x; p.y = y
			if p._near_water() != null: return


func _play(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000:
		await get_tree().process_frame
		for e in GameState.entities.enemies: e.remove = true   # 둘레의 적은 치운다


func _texts(n: Node) -> Array:
	var out := []
	for c in n.find_children("*", "Label", true, false): out.append(c.text)
	return out


func _popped(bit: String) -> bool:
	for t in Hud.current._toasts.get_children():
		if t.get_node("Label").text.contains(bit): return true
	for t in Hud.current._toast_wait:
		if str(t).contains(bit): return true
	return false


func _check(what: String, got, want = true) -> void:
	var ok: bool = str(got) == str(want)
	if not ok: _fails += 1
	print("[낚시] %s %s%s" % ["OK  " if ok else "FAIL", what, "" if ok else "  (%s · 기대 %s)" % [str(got), str(want)]])
