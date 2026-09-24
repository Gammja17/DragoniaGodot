extends Node
## 생활을 한 바퀴 확인한다: 굴 잠금 · 상자 알 · 아이의 부모 · 둥지 지키는 아이 · 짝과 사는 굴 · 굴 입구 ·
## 굴 손님 · 달맞이 모임 · 비 오는 날 습격. 줄마다 OK / FAIL 을 찍고 끝에 실패 수를 센다.
##   godot --headless --path . res://tools/test_life.tscn

var _box: DialogueBox
var _fails := 0


func _ready() -> void:
	Save.slot = 9   # 시험은 9번 칸을 쓴다 (사람이 쓰는 1~3번 칸을 건드리지 않게)
	Save.delete()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	_box = DialogueBox.current
	await _wait(1.0)
	await _wait_until(func(): return GameState.prologue and GameState.prologue.step == "poco", 8)
	Prologue.skip()
	await _wait(1.0)
	await _wait_until(func(): return DialogueBox.is_open(), 8)
	await _click_through(20)
	GameState.tour = null
	GameState.tutorial.finished = true
	GameState.player.stage_index = 2   # 아기 용은 밤이 깊으면 알아서 잠들어 버린다
	GameState.raidTimer = 99999
	GameState.story.events.append_array(["ev_falls", "ev_cloudtop"])

	await _den_lock()
	await _chest_eggs()
	await _parents()
	await _staying_kids()
	await _partner_home()
	await _den_doors()
	await _guests()
	await _gathering()
	_rain_raid()
	print("[끝] 실패 %d" % _fails)
	get_tree().quit()


func _check(what: String, ok: bool, detail = "") -> void:
	if not ok:
		_fails += 1
		print("     (지금: done=%s active=%s boss=%s map=%s 대화창=%s)" % [GameState.quests.done, GameState.quests.active.keys(), GameState.bossesDefeated.keys(), GameState.map_id, DialogueBox.is_open()])
	print("%s %s%s" % ["OK  " if ok else "FAIL", what, "  (%s)" % detail if str(detail) != "" else ""])


# ---------- 굴 잠금: 주인이 딴 지도에 있어도 호감을 본다 ----------
func _den_lock() -> void:
	var elder = World.any_npc("Elder")
	await _go("DOJO")
	await _wait(0.3)
	_check("굴 잠금: 엘더가 딴 지도에 있다", not GameState.entities.npcs.has(elder))
	elder.relation = 5
	_check("굴 잠금: 호감 5면 잠긴다", Den.locked_reason("DEN_ELDER") != null)
	elder.relation = 100
	_check("굴 잠금: 호감 100이면 주인이 집을 비워도 열린다", Den.locked_reason("DEN_ELDER") == null)
	elder.relation = 0


# ---------- 상자에서 알이 나오지 않는다 ----------
func _chest_eggs() -> void:
	var p = GameState.player
	var chests := []
	for i in 200:
		var c = Prop.new().setup(p.x, p.y, "CHEST")
		c.open()
		chests.append(c)
	var eggs: int = GameState.entities.items.filter(func(it): return it.type == "EGG").size()
	_check("상자 200개(성체)에서 알이 안 나온다", eggs == 0, "알 %d개" % eggs)
	for it in GameState.entities.items: it.remove = true
	World.prune()
	for c in chests: c.free()
	GameState.furniture = {}
	await _click_through(3)


# ---------- 아이의 부모 ----------
func _parents() -> void:
	var p = GameState.player
	var poco = World.any_npc("Poco")
	var kairon = World.any_npc("Kairon")
	var elder = World.any_npc("Elder")
	GameState.partner = poco
	var kid := _new_kid(Kids.mix_genes(p, poco))
	GameState.partner = kairon
	_check("아이 부모: 짝이 바뀌어도 그대로", Kids.parent_of(kid) == "Poco", Kids.parent_of(kid))
	kid.personality = "SHY"; kid.affection = 30
	var kid2 := _new_kid(Kids.mix_genes(p, kairon))
	kid2.personality = "SHY"; kid2.affection = 30
	var hits := 0
	var hits2 := 0
	for i in 200:
		if KidActions._line(kid, "chat").contains("포코"): hits += 1
		if KidActions._line(kid2, "chat").contains("포코"): hits2 += 1
	_check("아이 대사: 포코의 아이는 '포코 삼촌'이라 안 부른다", hits == 0 and hits2 > 0, "포코의 아이 %d/200 · 카이론의 아이 %d/200" % [hits, hits2])
	kid.personality = "PLAYFUL"; kid.affection = 80
	var learn := KidActions._line(kid, "learn")
	_check("아이 대사: 한 줄뿐인 단계에서 빠지면 한 단계 아래 줄", not learn.contains("포코"), learn)
	var old := BabyDragon.make(p.x - 40, p.y + 40, { species = p.species, colors = p.colors.duplicate(), look = p.look })
	World.add_entity("babies", old)
	var kid3 := Kids.register(old)
	GameState.partner = poco
	_check("옛 세이브의 아이: 불러올 때의 짝을 부모로 한 번 적는다", Kids.parent_of(kid3) == "Kairon", Kids.parent_of(kid3))
	Hud.current.kids.refresh()
	var rows: Array = Hud.current.kids.get_node("Frame/Lines/Body/Scroll/List").get_children()
	var first: String = rows[0].get_node("Row/Info/Stage").text if not rows.is_empty() else ""
	_check("가족 창: 아이 줄에 부모", first.ends_with("포코와 낳은 아이"), first)
	# 성년식: 엘더와 낳은 장난꾸러기는 지금 짝이 포코여도 '아빠'
	var kid4 := _new_kid(Kids.mix_genes(p, elder))
	kid4.personality = "PLAYFUL"; kid4.stage = "ADULT"
	Family.morning()
	var seen := ""
	for i in 5:
		await _wait(0.3)
		var t := Time.get_ticks_msec()
		while Cutscene.busy() and not DialogueBox.is_open() and Time.get_ticks_msec() - t < 8000: await get_tree().process_frame
		if not DialogueBox.is_open(): break
		seen += _box._text.text
		_box._text.visible_characters = -1
		_box._choose(0)
	_check("성년식: 엘더의 아이는 '아빠'라고 부른다", seen.contains("아빠가 방금 웃었으니까"))
	GameState.partner = null
	_clear_kids()


# ---------- 둥지 지키는 아이 (성체 · '둥지 지키기')는 따라오지 않고 굴에 있다 ----------
func _staying_kids() -> void:
	var p = GameState.player
	await _go("DEN_MINE")
	await _wait(0.3)
	var follow := _new_kid(Kids.mix_genes(p, null))
	var stay := _new_kid(Kids.mix_genes(p, null))
	Kids.toggle_mode(stay)
	var grown := _new_kid(Kids.mix_genes(p, null))
	grown.stage = "ADULT"
	await _go("VILLAGE")
	await _wait(0.3)
	var B: Array = GameState.entities.babies
	_check("따라오는 아이는 마을로 따라온다", B.has(follow.entity))
	_check("'둥지 지키기' 아이는 굴에 남는다", not B.has(stay.entity))
	_check("다 자란 아이는 굴에 남는다", not B.has(grown.entity))
	await _go("DEN_MINE")
	await _wait(0.5)
	B = GameState.entities.babies
	var nest = GameState.entities.nests[0]
	_check("굴에 들어가면 셋 다 있다", B.has(follow.entity) and B.has(stay.entity) and B.has(grown.entity))
	_check("둥지 지키는 아이는 둥지 곁에 있다", Util.dist(stay.entity, nest) < 220, "%.0f" % Util.dist(stay.entity, nest))
	_clear_kids()


# ---------- 짝과 사는 굴 ----------
func _partner_home() -> void:
	var elder = World.any_npc("Elder")
	var tiamat = World.any_npc("Tiamat")
	GameState.partner = elder
	elder.state = "WANDER"
	_check("짝 엘더: 1시에는 내 굴", _map("Elder", 1) == "DEN_MINE", _where("Elder", 1))
	_check("짝 엘더: 12시에는 제 일", _map("Elder", 12) == "VILLAGE", _where("Elder", 12))
	_check("짝 엘더: 23시 반에는 내 굴", _map("Elder", 23.5) == "DEN_MINE")
	GameState.weather.type = "RAIN"
	_check("짝 엘더: 비가 와도 내 굴에서 잔다", _map("Elder", 1) == "DEN_MINE")
	GameState.weather.type = "CLEAR"
	Romance.L().mood["Elder"] = { kind = "SULK", day = GameState.day }
	_check("토라진 짝은 제 굴에서 잔다", _map("Elder", 1) == "DEN_ELDER")
	Romance.L().mood.erase("Elder")
	GameState.partner = tiamat
	tiamat.state = "WANDER"
	_check("짝 티아맷: 1시에는 망루", _map("Tiamat", 1) == "VILLAGE", _where("Tiamat", 1))
	_check("짝 티아맷: 8시에는 내 굴에서 잔다", _map("Tiamat", 8) == "DEN_MINE", _where("Tiamat", 8))
	_check("짝이 아닌 엘더는 제 굴", _map("Elder", 1) == "DEN_ELDER")
	GameState.partner = elder
	# 모임 밤은 모임이 먼저
	GameState.story.events.append("ev_gathering")
	GameState.day = 8
	GameState.dayTime = 21.0 / 24
	_check("모임 밤에는 짝도 모임에", Routine.plan_for("Elder").map == "FALLS")
	GameState.story.events.erase("ev_gathering")
	GameState.day = 9
	# 내 굴에서 말 걸기
	GameState.dayTime = 1.0 / 24
	await _go("DEN_MINE")
	await _wait(0.5)
	_check("1시 내 굴에 짝이 있다", GameState.entities.npcs.has(elder), elder.doing)
	var t := await _greet(elder)
	_check("자고 있던 짝: 깨는 줄", t.begins_with("(굴 한쪽에서 자고 있다가"), t.left(40))
	elder.state = "PARTNER_FOLLOW"
	t = await _greet(elder)
	_check("같이 들어온 짝: 아늑함 줄", t.begins_with("(잠자리 한쪽을 벌써"), t.left(40))
	elder.state = "WANDER"
	GameState.partner = null


# ---------- 굴 입구로 드나들기 ----------
func _den_doors() -> void:
	var elder = World.any_npc("Elder")
	GameState.dayTime = 22.9 / 24
	await _go("VILLAGE")
	await _wait(1.5)
	var mouth = null
	for pr in GameState.entities.props:
		if pr.type == "DEN_MOUTH" and pr.den_id == "DEN_ELDER": mouth = pr
	GameState.dayTime = 23.05 / 24
	await _wait(1.5)
	var w = elder.walk_to
	_check("23시 촌장은 제 굴 입구로 걸어간다", w != null and Vector2(w.x - mouth.x, w.y - mouth.y).length() < 1, str(w))
	await _wait_until(func(): return elder.remove or not GameState.entities.npcs.has(elder), 60)
	_check("촌장이 굴로 들어갔다", elder.remove or not GameState.entities.npcs.has(elder))
	GameState.dayTime = 5.9 / 24
	await _wait(1.5)
	GameState.dayTime = 6.05 / 24
	var fresh = null
	var t := Time.get_ticks_msec()
	while fresh == null and Time.get_ticks_msec() - t < 3000:
		await get_tree().process_frame
		for n in GameState.entities.npcs:
			if n.config.get("name") == "Elder" and not n.remove: fresh = n
	_check("6시 촌장은 제 굴 입구에서 나온다", fresh != null and Vector2(fresh.x - mouth.x, fresh.y - mouth.y).length() < 60)


# ---------- 굴 손님 ----------
func _guests() -> void:
	var poco = World.any_npc("Poco")
	var tiamat = World.any_npc("Tiamat")
	var haru = World.any_npc("Haru")
	poco.relation = 60; tiamat.relation = 60; haru.relation = 90
	await _evening(3)
	_check("살 만하다(8점)에는 손님이 없다", _guest() == "", _guest())
	GameState.denDecor.append({ id = "FIREPLACE", tx = 15, ty = 1 })
	await _evening(4)
	_check("아늑하다(14점)면 친한 용이 온다 (폭포 위 용은 첫 모임 전이라 빠진다)", _guest() == "Poco", _guest())
	_check("손님은 내 굴에 와 있다", _map("Poco", 19) == "DEN_MINE")
	await _go("DEN_MINE")
	await _wait(1.5)
	var r0: float = poco.relation
	var t := await _greet(poco)
	_check("처음 온 날의 줄", t.contains("내가 풀 깔아 줄 때랑"), t.left(60))
	t = await _greet(poco)
	_check("그 뒤의 줄", t.contains("나 또 왔어"), t.left(60))
	_check("반겨 맞으면 호감 +5 (한 번만)", poco.relation == r0 + 5, "%.0f → %.0f" % [r0, poco.relation])
	GameState.dayTime = 21.2 / 24
	await _wait(1.5)
	_check("21시에 돌아간다", Routine.plan_for("Poco").map != "DEN_MINE")
	await _evening(5)
	_check("사흘에 한 번: 5일은 없다", _guest() == "")
	await _evening(7)
	_check("사흘에 한 번: 7일은 다음 용", _guest() == "Tiamat", _guest())
	GameState.story.events.append("ev_gathering")
	await _evening(16)
	_check("모임 날에는 안 온다", _guest() == "")
	GameState.quests.active["m5a"] = { step = 0 }
	await _evening(18)
	_check("봉우리에 눈이 내린 동안은 안 온다", _guest() == "")
	GameState.quests.active.erase("m5a")
	GameState.quests.done.append("m5a")
	await _evening(20)
	_check("전쟁 중에는 안 온다", _guest() == "")
	GameState.quests.done.append("m6w")
	await _evening(22)
	_check("전쟁 뒤: 첫 모임을 본 뒤라 폭포 위 하루도 온다", _guest() == "Haru", _guest())
	GameState.day = 24
	GameState.dayTime = 22.5 / 24
	await _wait(1.5)
	_check("22시 반에 들어오면 그날은 정하지 않는다", int(GameState.story.guests.day) == 22)
	GameState.quests.done.erase("m5a")
	GameState.quests.done.erase("m6w")


# ---------- 달맞이 모임 ----------
func _gathering() -> void:
	var Q: Dictionary = GameState.quests
	if not GameState.story.events.has("ev_gathering"): GameState.story.events.append("ev_gathering")
	_check("첫 모임 뒤: first", Gathering.phase() == "first", Gathering.phase())
	Q.active["m5a"] = { step = 0 }
	_check("봉우리에 눈: 모임이 서지 않는다", Gathering.phase() == "" and not Gathering.is_gather_day(8))
	Q.active.erase("m5a"); Q.done.append("m5a")
	_check("전쟁: 모임이 서지 않는다", Gathering.phase() == "" and Gathering.paused())
	Q.done.append("m6w")
	Story._kill_npc("Gron")
	_check("전쟁 뒤: after_war · 그론 자리 없음 · 엠버 자리", Gathering.phase() == "after_war" and Gathering.spot_of("Gron") == null and Gathering.spot_of("Ember") != null)
	Q.done.append_array(["m5b", "m5c"])
	_check("불탄 도시 뒤: together", Gathering.phase() == "together")
	Q.done.append("m6")
	GameState.story.route = "guardian"
	_check("지키는 길 끝: peace", Gathering.phase() == "peace")
	GameState.story.route = "redeem"
	_check("데려온 길 끝: redeem · 이그나르 자리", Gathering.phase() == "redeem" and Gathering.spot_of("Ignar") != null)
	GameState.story.route = "dark"
	_check("잿빛 날개 길: 서지 않는다", Gathering.phase() == "" and Gathering.paused())
	# 자리가 바위·나무에 박히지 않았나
	await _go("FALLS")
	await _wait(0.5)
	var bad := []
	var phases: Dictionary = Data.get_module("gathering").PHASES
	for ph in phases:
		for nm in phases[ph].spots:
			var s: Array = phases[ph].spots[nm]
			if Collision.solid_at(GameMap.coarse_center(s[0]), GameMap.coarse_center(s[1]), 20): bad.append("%s:%s" % [ph, nm])
	_check("모임 자리가 막히지 않았다", bad.is_empty(), str(bad))
	# 전쟁 뒤 첫 밤: 장면 한 번 · 말풍선
	GameState.story.route = null
	Q.done.erase("m6"); Q.done.erase("m5c"); Q.done.erase("m5b")
	await _go("LAKE")
	GameState.day = 32
	GameState.dayTime = 20.5 / 24
	await _wait(0.5)
	await _go("FALLS")
	await _wait_until(func(): return DialogueBox.is_open(), 15)   # 장 제목 카드가 떠 있는 6초 동안은 장면이 기다린다
	var lines := await _read_scene()
	_check("전쟁 뒤 첫 밤: 장면 '다시 선 모임'", lines >= 9 and GameState.story.get("gatherings", []).has("after_war"), "%d줄" % lines)
	var said := {}
	var t := Time.get_ticks_msec()
	while said.is_empty() and Time.get_ticks_msec() - t < 45000:
		await get_tree().process_frame
		for x in GameState.entities.npcs:
			if x.current_chat and x.chat_fade > 2.9: said[x.config.name] = x.current_chat
	_check("모임에서 말풍선을 주고받는다", not said.is_empty(), str(said))
	await _go("LAKE")
	await _wait(0.5)
	await _go("FALLS")
	await _wait(2.0)
	_check("다시 와도 장면은 한 번뿐", not DialogueBox.is_open())
	# 데려온 길 끝: 이그나르의 첫 모임
	Q.done.append_array(["m5b", "m5c", "m6"])
	GameState.story.route = "redeem"
	await _go("LAKE")
	GameState.day = 40
	GameState.dayTime = 20.5 / 24
	await _wait(0.5)
	await _go("FALLS")
	await _wait_until(func(): return DialogueBox.is_open(), 15)   # 장 제목 카드가 떠 있는 6초 동안은 장면이 기다린다
	lines = await _read_scene()
	_check("데려온 길 첫 모임: 장면 '처음 온 용' · 이그나르가 와 있다", lines >= 8 and GameState.story.gatherings.has("redeem") \
		and GameState.entities.npcs.any(func(x): return x.config.name == "Ignar"), "%d줄" % lines)


# ---------- 비 오는 날 습격: 습격 자리가 먼저다 ----------
func _rain_raid() -> void:
	GameState.partner = null
	GameState.dayTime = 12.0 / 24   # 모임 시간이 아니게
	GameState.weather.type = "RAIN"
	GameState.raid.active = true
	var d: String = Routine.plan_for("Elder").doing
	GameState.raid.active = false
	_check("비 오는 날 습격: 촌장은 분수 앞에서 지휘한다", d == "분수 앞에서 마을을 지휘한다", d)
	d = Routine.plan_for("Elder", 12).doing
	_check("비 오는 날 (습격 없음): 처마 밑", d == "처마 밑에서 비를 바라보고 있다", d)
	GameState.weather.type = "CLEAR"


# ---------- 도구 ----------

## 지도를 옮긴다. World.travel_to 는 옮긴 뒤 0.35초 동안 다시 옮기지 않으니, 그만큼 기다렸다가 옮긴다
func _go(map_id: String) -> void:
	await _wait(0.4)
	World.travel_to(map_id)
	await get_tree().process_frame


func _new_kid(genes: Dictionary) -> Dictionary:
	var p = GameState.player
	var baby := BabyDragon.make(p.x + Util.rand_range(-40, 40), p.y + 40, genes)
	World.add_entity("babies", baby)
	return Kids.register(baby)


func _clear_kids() -> void:
	for b in GameState.entities.babies: b.remove = true
	GameState.kids.clear()
	World.prune()


func _map(nm: String, hour: float) -> String:
	var p = Routine.plan_for(nm, hour)
	return p.map if p else ""


func _where(nm: String, hour: float) -> String:
	var p = Routine.plan_for(nm, hour)
	return "%s · %s" % [p.map, p.doing] if p else "없음"


func _guest() -> String:
	return str(GameState.story.get("guests", {}).get("name", ""))


func _evening(day: int) -> void:
	GameState.day = day
	GameState.dayTime = 17.9 / 24
	await _wait(1.2)
	GameState.dayTime = 18.1 / 24
	await _wait(1.5)


## 말을 걸어 첫 화면 글을 읽고 닫는다
func _greet(npc) -> String:
	Dialogue.start(npc, "TALK")
	await get_tree().process_frame
	var t := _box._text.text.replace("\n", " ")
	Dialogue.close()
	return t


## 떠 있는 장면을 끝까지 넘기며 줄 수를 센다
func _read_scene() -> int:
	var n := 0
	while DialogueBox.is_open() and n < 20:
		n += 1
		await _click_through(1)
	await _wait(0.5)
	return n


func _click_through(limit: int) -> void:
	for i in limit:
		await _wait(0.15)
		var t := Time.get_ticks_msec()
		while Cutscene.busy() and not DialogueBox.is_open() and Time.get_ticks_msec() - t < 8000: await get_tree().process_frame
		if not DialogueBox.is_open(): return
		_box._text.visible_characters = -1
		_box._choose(0)


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000: await get_tree().process_frame


func _wait_until(cond: Callable, sec: float) -> void:
	var t := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t < sec * 1000: await get_tree().process_frame
