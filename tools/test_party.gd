extends Node
## 원정대: 따라나선 용이 같이 싸우는지 본다 (docs/tasks/README.md 의 G 카드).
##   godot --headless --path . res://tools/test_party.tscn

var _bad := 0


func _ready() -> void:
	Save.slot = 9   # 시험은 9번 칸을 쓴다 (사람이 쓰는 1~3번 칸을 건드리지 않게)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.play_intro = false
	main.load_save = false
	add_child(main)
	for i in 5: await get_tree().process_frame
	# 사건이 저절로 끼어들지 않게 모두 본 것으로 둔다
	for ev in Data.get_module("chronicle").CHRONICLE: GameState.story.events.append(ev.id)
	_firepower()
	await _reach()
	await _targets()
	await _boss()
	await _dodge()
	await _roles()
	await _down_home()
	await _zalgora()
	await _slot()
	await _story()
	await _story_load()
	await _menu()
	await _alone()
	await _kairon()
	await _records()
	await _scenes()
	await _envoys()
	await _panel()
	await _player_down()
	_hittable()
	print("[끝] 틀린 곳 %d" % _bad)
	get_tree().quit()


## 동료 화력: 내 브레스의 3~4할 (호감 50 → 3할, 100 → 4할). 역할이 조금 더하고 뺀다
func _firepower() -> void:
	var p: Dragon = GameState.player
	var want := ["17.8", "44.4", "86.7", "113.3"]
	for st in 4:
		p.stage_index = st
		_check("내 피해 · %s" % p.stage.name, "%.1f" % Party.player_dps(), want[st])
	p.stage_index = 2   # 이제부터 성체
	_check("몫 · 호감 0 (이야기가 데려온 서먹한 용)", "%.2f" % Party.share(0), "0.20")
	_check("몫 · 호감 50", "%.2f" % Party.share(50), "0.30")
	_check("몫 · 호감 100", "%.2f" % Party.share(100), "0.40")
	var mine := Party.player_dps()
	for nm in ["Tiamat", "Kairon", "Mira"]:
		var n = World.any_npc(nm)
		for rel in [50, 100]:
			n.relation = rel
			var dps: float = Party.shot_damage(n) / float(Party._d().INTERVAL)
			print("  %s(%s) 호감 %d: 1초에 %.1f · 내 피해의 %.2f" % [Names.npc(nm), Party.role(n).name, rel, dps, dps / mine])
	_check("표에 없는 용은 역할이 없다", Party.role(World.any_npc("Nuri")).is_empty(), true)


## 사거리: 브레스가 닿는 거리 안에서 쏘고, 멀면 다가선다 (불은 356. 예전엔 400에서 쏴서 헛방이었다)
func _reach() -> void:
	_check("불 브레스가 닿는 거리", roundi(Party.reach("FIRE")), 356)
	var c := await _dojo()
	var p = GameState.player
	var nara = _follow("Nara", c + Vector2(60, 0))   # 불
	nara.relation = 60
	var s := _foe(c + Vector2(460, 0), "SLIME", 0.0)   # 나라에게서 400. 제자리에 세워 둔다
	var d0 := Util.dist(nara, s)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000 and s.hp >= s.max_hp:
		await get_tree().process_frame
		p.x = c.x; p.y = c.y
	print("  나라 → 슬라임 %d → %d, 슬라임 체력 %d/%d" % [d0, Util.dist(nara, s), s.hp, s.max_hp])
	_check("동료가 닿는 데까지 다가선다", Util.dist(nara, s) < Party.reach("FIRE"), true)
	_check("동료의 불이 실제로 맞는다", s.hp < s.max_hp, true)
	_check("동료는 내 곁을 벗어나지 않는다", Util.dist(nara, p) < 260, true)
	s.remove = true


## 적이 동료도 노린다: 가까운 쪽 · 방금 나를 친 쪽. 하늘에 뜬 나는 날지 못하는 적이 못 노린다
func _targets() -> void:
	var c := await _dojo()
	var p = GameState.player
	var nara = _follow("Nara", c + Vector2(-150, 0))
	var s := _foe(c + Vector2(-300, 0), "SLIME")   # 나라에게서 150, 나에게서 300
	s.aggro = true
	for i in 3: await get_tree().process_frame
	_check("가까운 동료를 노린다", EnemyAI.target_of(s) == nara, true)
	var hp0: float = nara.hp
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000 and nara.hp >= hp0:
		await get_tree().process_frame
		p.x = c.x; p.y = c.y
	_check("적의 한 방이 동료에게 들어간다", nara.hp < hp0, true)
	nara.passive = true   # 나라가 쏘면 '나를 친 쪽'이 나라로 바뀐다
	nara.x = c.x - 150; nara.y = c.y
	s.x = c.x - 250; s.y = c.y   # 나라 100, 나 250: 거리만 보면 나라
	s.hit_by = p; s.hit_at = GameState.game_time
	s.ai.rt = 0.0; s.ai.s = "approach"
	await get_tree().process_frame
	_check("방금 나를 친 쪽을 노린다", EnemyAI.target_of(s) == p, true)
	p.flying = true
	s.x = c.x - 60; s.y = c.y   # 나 60, 나라 90: 거리만 보면 나
	s.hit_by = null
	s.ai.rt = 0.0; s.ai.s = "approach"
	await get_tree().process_frame
	_check("하늘에 뜬 나는 날지 못하는 적이 못 노린다", EnemyAI.target_of(s) == nara, true)
	p.flying = false
	nara.passive = false
	s.remove = true


## 보스는 주로 나를 노리고, 조준하는 패턴 넷 중 하나쯤은 동료 쪽으로 긋는다. 몸통에 부딪히면 동료도 다친다
func _boss() -> void:
	World.travel_to("IGNAR_LAIR")
	for i in 3: await get_tree().process_frame
	var b: Boss = GameState.entities.bosses[0]
	var p = GameState.player
	p.max_hp = 5000.0; p.hp = 5000.0
	p.x = b.x; p.y = b.y + 400
	var nara = _follow("Nara", Vector2(p.x + 80, p.y))
	nara.max_hp = 5000.0; nara.hp = 5000.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000 and (not b.awake or Cutscene.on or GameState.isDialogueOpen):
		await get_tree().process_frame
		_advance()   # 등장 장면을 넘긴다
	var aimed := 0
	var ring := 0
	for i in 400:
		if b._pick_focus("AIMED") != null: aimed += 1
		if b._pick_focus("RING") != null: ring += 1
	print("  조준 패턴 400번 가운데 동료 쪽 %d번" % aimed)
	_check("조준 패턴은 2~3할쯤 동료 쪽", aimed > 60 and aimed < 140, true)
	_check("둥근 탄은 늘 나를 가운데 둔다", ring, 0)
	var hp0: float = nara.hp
	for i in 20:
		nara.x = b.x; nara.y = b.y
		await get_tree().process_frame
	_check("보스 몸통에 부딪힌 동료가 다친다", nara.hp < hp0, true)
	nara.max_hp = float(nara.config.maxHp); nara.hp = nara.max_hp
	p.max_hp = 80.0; p.hp = p.max_hp


## 동료가 발밑의 장판 예고를 비켜선다
func _dodge() -> void:
	var c := await _dojo()
	var p = GameState.player
	var nara = _follow("Nara", c + Vector2(90, 0))
	var hp0: float = nara.hp
	Hazard.add(nara.x, nara.y, { faction = "ENEMY", r = 110, delay = 1.0, damage = 40 })
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1400:
		await get_tree().process_frame
		p.x = c.x; p.y = c.y
	print("  나라 체력 %d → %d, 장판 가운데에서 %d" % [hp0, nara.hp, Util.dist(nara, c + Vector2(90, 0))])
	_check("동료가 장판 예고를 비켜서 안 맞는다", nara.hp >= hp0, true)


## 역할: 막기는 곁의 적을 끌어 두고 덜 다친다. 살리기는 쓰러진 용을 일으키고 다친 나를 돌본다
func _roles() -> void:
	var c := await _dojo()
	var p = GameState.player
	var tia = _follow("Tiamat", c + Vector2(250, 200))   # 막기
	var s := _foe(c + Vector2(0, 200), "SLIME")   # 나 200, 티아맷 250
	s.aggro = true
	s.ai.rt = 0.0
	await get_tree().process_frame
	_check("막기 동료가 곁의 적을 끌어간다", EnemyAI.target_of(s) == tia, true)
	var hp0: float = tia.hp
	tia.take_damage(10)
	_check("막기 동료는 덜 다친다 (10 → 6)", roundi(hp0 - tia.hp), 6)
	s.remove = true
	# 이야기 동료(4장 티아맷)가 쓰러지면 고른 동료 미라(살리기)가 달려가 일으킨다. 고른 칸은 하나라 둘이 같이 가는 건 이때다
	var mira = _follow("Mira", c + Vector2(120, 0))   # 고른 칸이 티아맷에서 미라로
	GameState.quests.active["m5"] = { step = 1, n = 0 }
	Party.sync()
	tia.x = c.x - 150; tia.y = c.y
	tia.take_damage(99999)
	_check("이야기 동료 티아맷이 쓰러진다", tia.down_timer > 0, true)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000 and tia.down_timer > 0:
		await get_tree().process_frame
		p.x = c.x; p.y = c.y
	_check("살리기 동료가 쓰러진 용을 일으킨다 (체력 절반)", tia.down_timer <= 0 and tia.hp >= tia.max_hp * 0.5 and tia.hp < tia.max_hp * 0.6, true)
	_check("일으켜진 이야기 동료는 그대로 따라온다", tia.state, "STORY_FOLLOW")
	GameState.quests.active.erase("m5")
	Party.sync()
	p.hp = p.max_hp * 0.3
	var php: float = p.hp
	mira.x = c.x + 100; mira.y = c.y
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000 and p.hp <= php:
		await get_tree().process_frame
		p.x = c.x; p.y = c.y
	_check("살리기 동료가 다친 나를 돌본다", p.hp > php, true)
	p.hp = p.max_hp


## 따라나선 동료가 쓰러졌다가 저절로 일어나면 그날은 돌아간다. 그날은 다시 부를 수 없다
func _down_home() -> void:
	var c := await _dojo()
	var nara = _follow("Nara", c + Vector2(-120, 0))   # 고른 칸이 미라에서 나라로
	nara.take_damage(99999)
	nara.down_timer = 0.05   # 25초를 기다리지 않는다
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1000 and nara.down_timer > 0: await get_tree().process_frame
	await get_tree().process_frame
	_check("저절로 일어난 동료는 그날 돌아간다", Party.went_home(nara), true)
	_check("고른 칸이 빈다", GameState.companion == null, true)
	_check("일어난 동료의 체력은 절반", nara.hp < nara.max_hp * 0.6, true)
	var menu = NpcActions._own_menu(nara, "Nara")
	_check("그날은 다시 부를 수 없다", str(menu.label).contains("내일 다시 청하자") if menu else false, true)


## 잘고라: 곁의 막기 동료(티아맷)가 번개 머리를 끌어가고, 다른 머리가 들이받아 휘청인다
func _zalgora() -> void:
	World.travel_to("ZALGORA_LAIR")
	for i in 3: await get_tree().process_frame
	var b: Boss = GameState.entities.bosses[0]
	var p = GameState.player
	p.max_hp = 5000.0; p.hp = 5000.0
	p.x = b.x; p.y = b.y + 400
	var tia = _follow("Tiamat", Vector2(b.x + 300, b.y + 250))
	tia.max_hp = 5000.0; tia.hp = 5000.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000 and (not b.awake or Cutscene.on or GameState.isDialogueOpen):
		await get_tree().process_frame
		_advance()   # 등장 장면을 넘긴다
	for x in GameState.entities.bullets: x.remove = true
	await get_tree().process_frame
	b.focus = null
	b._fire("AIMED")
	var m: Vector2 = b._mouth()
	var to_tia := atan2(tia.y - 40 - m.y, tia.x - m.x)
	var pulled := 0
	for x in GameState.entities.bullets:
		if x.faction == "ENEMY" and x.element == "THUNDER" and absf(angle_difference(x.angle, to_tia)) < 0.3: pulled += 1
	_check("번개 머리가 막기 동료 쪽으로 끌려간다", pulled > 0, true)
	_check("머리가 갈라졌다", b._heads_split, true)
	var bumped := false
	for i in 12:
		b._heads_split = true
		b.opening = false
		b._start_pattern()
		if b.opening:
			bumped = true
			break
	_check("다른 머리가 들이받아 휘청인다 (빈틈)", bumped, true)
	tia.max_hp = float(tia.config.maxHp); tia.hp = tia.max_hp
	p.max_hp = 80.0; p.hp = p.max_hp


## 고른 칸은 하나: 짝이 따라오면 그 자리, 아니면 고른 동료
func _slot() -> void:
	var c := await _dojo()
	var nara = _mate("Nara", c + Vector2(-100, 0))
	var mira = World.any_npc("Mira")
	_place(mira, c + Vector2(100, 0))
	mira.relation = 60
	NpcActions._set_companion(mira, true)
	_check("동료를 부르면 따라오던 짝은 마을에서 기다린다", nara.state, "WANDER")
	_check("부른 동료가 따라온다", GameState.companion == mira and mira.state == "COMPANION_FOLLOW", true)
	NpcActions._set_following(nara, true)
	_check("짝을 부르면 따라오던 동료는 돌아간다", GameState.companion == null and mira.state == "WANDER", true)
	_check("짝이 따라온다", nara.state, "PARTNER_FOLLOW")
	GameState.companion = mira   # 화해하고 다시 따라나선 짝 (romance.gd 는 짝 상태만 바꾼다)
	mira.state = "COMPANION_FOLLOW"
	Party.sync()
	_check("짝과 동료가 함께 따라오면 동료가 돌아간다", GameState.companion == null and mira.state == "WANDER", true)
	GameState.partner = null
	nara.state = "WANDER"


## 이야기 동료: 퀘스트 진행을 보고 저절로 따라나서고, 일을 마치면 장면이 다 흐른 뒤 돌아간다
func _story() -> void:
	var c := await _dojo()
	var tia = _follow("Tiamat", c + Vector2(80, 0))   # 고른 칸에 있던 티아맷
	tia.relation = 12
	GameState.quests.active["m5"] = { step = 1, n = 0 }
	Party.sync()
	_check("4장: 잘고라 얘기를 들은 뒤 티아맷이 이야기 동료로 따라나선다", tia.state, "STORY_FOLLOW")
	_check("고른 칸에 있던 용이면 칸이 빈다", GameState.companion == null, true)
	_check("원정대에 든다 (호감이 낮아도)", Party.followers().has(tia), true)
	GameState.quests.active.m5.step = 3
	GameState.questScenes.append({ title = "", lines = [], place = null })
	Party.sync()
	_check("일을 마쳤어도 장면이 남아 있으면 아직 곁에 있다", tia.state, "STORY_FOLLOW")
	GameState.questScenes.clear()
	Party.sync()
	_check("장면이 다 흐르면 제자리로 돌아간다", tia.state, "WANDER")
	GameState.quests.active.erase("m5")
	var ember = World.any_npc("Ember")
	_place(ember, c + Vector2(-80, 0))
	GameState.quests.active["m5b"] = { step = 0, n = 0 }
	Party.sync()
	_check("7장: 엠버가 따라나선다", ember.state, "STORY_FOLLOW")
	_check("메뉴: 이 일이 끝날 때까지 함께 간다", _menu_labels(ember), ["(이 일이 끝날 때까지 함께 간다)"])
	GameState.bossesDefeated["BASIL"] = true
	Party.sync()
	_check("바실을 잡으면 엠버는 돌아간다", ember.state, "WANDER")
	GameState.bossesDefeated.erase("BASIL")
	GameState.quests.active.erase("m5b")


## 저장했다 불러와도 이야기 동료는 그대로 따라온다. 5장 동안은 오늘의 수련이 없다
func _story_load() -> void:
	await _dojo()
	var k = World.any_npc("Kairon")
	GameState.quests.active["m5a"] = { step = 1, n = 0 }
	Party.sync()
	_check("5장: 카이론이 따라나선다", k.state, "STORY_FOLLOW")
	GameState.story.scenes.append("ch1")   # 스승을 소개받은 뒤라야 수련이 있다
	_check("5장 동안은 오늘의 수련이 없다", Training.todays_plan() == null, true)
	GameState.story.scenes.erase("ch1")
	Save.save_game()
	k.state = "WANDER"   # 새로 켠 것처럼
	Save.apply(Save.read())
	for i in 3: await get_tree().process_frame
	_check("불러온 뒤에도 카이론이 따라온다", k.state == "STORY_FOLLOW" and GameState.entities.npcs.has(k), true)
	GameState.quests.active.erase("m5a")
	Party.sync()
	_check("5장이 끝나면 카이론은 돌아간다", k.state, "WANDER")


## 고르는 메뉴: 원정대 표에 없는 용(아이 · 그론)은 동행이 없고, 호감이 모자라면 까닭을 말한다. "with" 거르개
func _menu() -> void:
	var c := await _dojo()
	for nm in ["Nuri", "Gron"]:
		var labels := _menu_labels(World.any_npc(nm))
		_check("%s: 동행 메뉴가 없다" % Names.npc(nm), labels.any(func(l): return l.contains("모험") or l.contains("서먹")), false)
	var tia = World.any_npc("Tiamat")
	_place(tia, c + Vector2(90, 0))
	GameState.quests.done.append("m5a")   # 시험은 한여름 눈까지 본 것으로 두어서, 알 일을 마친 뒤로 둔다 (그 전에는 사절로 떠나 있다)
	tia.relation = 12
	_check("호감이 모자라면 까닭", _menu_labels(tia).has("(같이 먼 길을 가자고 하기엔 아직 서먹하다. 호감 12/50)"), true)
	tia.relation = 60
	_check("호감이 넘으면 역할을 붙여 부른다", _menu_labels(tia).has("🤝 같이 모험을 떠나자 (막기)"), true)
	GameState.quests.done.erase("m5a")
	var nara = _follow("Nara", c + Vector2(-90, 0))
	_check("with Nara", Chronicle._with({ with = "Nara" }), true)
	_check("with !Nara", Chronicle._with({ with = "!Nara" }), false)
	_check("with Tiamat (곁에 없다)", Chronicle._with({ with = "Tiamat" }), false)
	var lost = null
	for ev in Data.get_module("chronicle").CHRONICLE:
		if ev.id == "ev_nuri_lost": lost = ev
	_check("누리를 찾을 때: 동료가 있으면 호숫가로 보내는 줄이 나온다", Chronicle._with(lost.lines[-1]), true)
	GameState.companion = null
	nara.state = "WANDER"
	_check("누리를 찾을 때: 동료가 없으면 그 줄은 없다", Chronicle._with(lost.lines[-1]), false)


## 나 혼자 가는 곳: 8장 화산 · 3장 골짜기에는 동료가 따라 들어오지 않는다. 밖으로 나오면 다시 붙는다
func _alone() -> void:
	var c := await _dojo()
	var nara = _follow("Nara", c + Vector2(90, 0))
	GameState.quests.active["m6"] = { step = 1, n = 0 }
	await _go("AUTUMN")
	_check("단풍골: 동료가 따라온다", GameState.entities.npcs.has(nara), true)
	await _go("VOLCANO")
	_check("잿마루(8장): 동료가 따라 들어오지 않는다", GameState.entities.npcs.has(nara), false)
	_check("동료는 여전히 원정대다 (밖에서 기다린다)", Party.followers().has(nara), true)
	await _go("AUTUMN")
	_check("단풍골로 나오면 다시 붙는다", GameState.entities.npcs.has(nara), true)
	GameState.quests.active.erase("m6")
	GameState.quests.active["m4"] = { step = 0, n = 0 }
	await _go("DOJO")
	await _go("EAST_ROAD")
	await _go("HOLLOW")
	_check("달빛 골짜기(3장 누리를 찾는 동안): 동료가 따라 들어오지 않는다", GameState.entities.npcs.has(nara), false)
	GameState.quests.active.erase("m4")
	GameState.companion = null
	nara.state = "WANDER"


## 카이론: 6장 장례 다짐 뒤로는 짝이어도 따라나서지 않는다. 결투장에 합류했다 풀리면 합류 전 상태로 돌아간다
func _kairon() -> void:
	var c := await _dojo()
	var k = World.any_npc("Kairon")
	_place(k, c + Vector2(100, 0))
	GameState.partner = k
	k.state = "WANDER"
	GameState.quests.done.append("m6w")
	var go = null
	for o in _menu_options(k):
		if o.label == "🤝 같이 가자": go = o
	if go: go.on_select.call()
	_check("다짐 뒤 '같이 가자' → 다짐을 말한다", DialogueBox.current._text.text.contains("다시는 마을을 비우지 않겠다고 했다"), true)
	NpcActions.close()
	k.state = "PARTNER_FOLLOW"
	Party.sync()
	_check("따라오던 중이었어도 마을에 남는다", k.state, "WANDER")
	GameState.quests.done.erase("m6w")
	k.state = "PARTNER_FOLLOW"   # 다짐 전: 짝으로 따라다니던 카이론이 결투장에 합류했다가
	await _go("IGNAR_LAIR")
	_place(k, Vector2(GameState.player.x + 90, GameState.player.y))
	BossShow.ally_joined(k)
	_check("결투장에 합류한다", k.state, "ALLY")
	await _go("VOLCANO_PATH")
	_check("결투장을 떠나면 짝으로 따라다니던 상태로 돌아온다", k.state, "PARTNER_FOLLOW")
	_check("곧바로 같이 나온다", GameState.entities.npcs.has(k), true)
	GameState.partner = null
	k.state = "WANDER"


## 같이 싸운 기록: 보스가 쓰러질 때 곁에 있던 용을 적고 호감이 오른다. 가장 여러 번 같이 싸운 용이 "끝까지 곁에서 싸운 용"
func _records() -> void:
	var c := await _dojo()
	var nara = _follow("Nara", c + Vector2(90, 0))
	nara.relation = 60
	Party.on_boss_down("ZALGORA")
	_check("잘고라: 곁에서 싸운 용", GameState.story.party.fought.ZALGORA, ["Nara"])
	_check("같이 넘긴 만큼 가까워진다 (60 → 65)", roundi(nara.relation), 65)
	var tia = World.any_npc("Tiamat")
	GameState.quests.active["m5"] = { step = 1, n = 0 }
	Party.sync()   # 티아맷이 이야기 동료로 곁에 온다
	Party.on_boss_down("GLACIA")
	_check("글라시아: 곁에서 싸운 용 둘", GameState.story.party.fought.GLACIA.has("Nara") and GameState.story.party.fought.GLACIA.has("Tiamat"), true)
	_check("끝까지 곁에서 싸운 용 (두 번)", GameState.story.party.closest, "Nara")
	GameState.quests.active.erase("m5")
	Party.sync()
	GameState.companion = null
	nara.state = "WANDER"
	GameState.story.party.erase("fought")
	GameState.story.party.erase("closest")


## 이야기 동료 대사: 곁에 누가 왔는지에 따라 줄이 갈린다. 가람은 사막 입구에서 길잡이로 나섰다가 불탄 도시 뒤에 돌아간다
func _scenes() -> void:
	var c := await _dojo()
	var m5 = Quests.by_id("m5")
	var talk: Array = m5.steps[2].scene
	var tia = World.any_npc("Tiamat")
	_place(tia, c + Vector2(90, 0))
	GameState.quests.active["m5"] = { step = 2, n = 0 }
	Party.sync()
	_check("m5 셋째 대목: 티아맷이 곁에 있으면 형제가 쓰러진 자리를 본다", str(_first_shown(talk).text).contains("쓰러진 자리"), true)
	GameState.quests.active.erase("m5")
	Party.sync()
	_check("m5 셋째 대목: 곁에 없으면 전해 듣는다", str(_first_shown(talk).text), "둘 다 형을 불렀다고?")
	var basil = null
	var guide = null
	var city = null
	for ev in Data.get_module("chronicle").CHRONICLE:
		if ev.id == "ev_basil": basil = ev
		if ev.id == "ev_garam_guide": guide = ev
		if ev.id == "ev_city": city = ev
	_check("ev_basil: 엠버가 '여기까지만'이라고 하지 않는다", basil.lines.any(func(l): return str(l.text).contains("여기까지만")), false)
	_check("ev_basil: 엠버가 망치를 들고 따라나선다", basil.lines.any(func(l): return str(l.text).contains("나도 같이 갈래")), true)
	await _go("DESERT")
	GameState.quests.active["m5c"] = { step = 0, n = 0 }
	_check("가람 사건: 사막 입구 · 불탄 도시 가기 전", guide.when.call(Chronicle.context()), true)
	Party.sync()   # 사건을 본 뒤 (시험은 모든 사건을 본 것으로 둔다)
	var garam = World.any_npc("Garam")
	_check("7장: 가람이 길잡이로 따라나선다", garam.state == "STORY_FOLLOW" and GameState.entities.npcs.has(garam), true)
	_check("불탄 도시: 가람이 곁에 있으면 돌아간다는 줄", Chronicle._with(city.lines[-1]), true)
	GameState.quests.active.m5c.step = 1
	_check("가람 사건: 불탄 도시를 본 뒤에는 없다", guide.when.call(Chronicle.context()), false)
	Party.sync()
	_check("불탄 도시를 보면 가람은 돌아간다", garam.state, "WANDER")
	GameState.quests.active.erase("m5c")


## 5장 사절(티아맷 · 유안)은 봉우리에 가 있는 동안 곁을 비운다. 곁에 누가 있느냐에 따라 5장 · 보스 뒤 줄이 갈린다
func _envoys() -> void:
	var c := await _dojo()
	GameState.story.events.erase("ev_glacia")   # 시험은 모든 사건을 본 것으로 두었다. 여기서는 한여름 눈 전으로
	var tia = _follow("Tiamat", c + Vector2(90, 0))
	tia.relation = 60
	GameState.story.trystDay = GameState.day   # 오늘 밀회를 봤다
	Party.sync()
	_check("밀회 날에는 아직 곁에 있다", tia.state, "COMPANION_FOLLOW")
	GameState.day += 1   # 다음 날: 사절이 봉우리로 떠난다
	Party.sync()
	_check("다음 날 사절로 떠난다", tia.state == "WANDER" and GameState.companion == null, true)
	_check("그동안은 부를 수 없다", Party.can_pick(tia), false)
	GameState.quests.done.append("m5a")
	_check("알 일이 끝나면 다시 부를 수 있다", Party.can_pick(tia), true)
	GameState.quests.done.erase("m5a")
	GameState.story.erase("trystDay")
	GameState.day -= 1
	GameState.story.events.append("ev_glacia")
	var poco_talk: Array = Quests.by_id("m5a").steps[2].scene
	var poco = _follow("Poco", c + Vector2(-90, 0))
	_check("포코가 곁에 있으면 봉우리에서 알 이야기", str(_first_shown(poco_talk).text).contains("하나도 안 깨어났대"), true)
	GameState.companion = null
	poco.state = "WANDER"
	_check("곁에 없으면 마을 광장의 눈사람", str(_first_shown(poco_talk).text), "눈 그쳤어! 네가 그친 거지? 그런 거지?!")
	var ridge = null
	for ev in Data.get_module("chronicle").CHRONICLE:
		if ev.id == "ev_snow_ridge": ridge = ev
	var mira = _follow("Mira", c + Vector2(90, 0))
	var shown: Array = ridge.lines.filter(func(l): return Chronicle._with(l)).map(func(l): return str(l.text))
	_check("미라가 곁에 있으면 유안이 '미라한테는 말하지 마라'고 하지 않는다", shown.any(func(t): return t.contains("미라한테는")), false)
	_check("미라가 유안의 날개를 싸맨다", shown.any(func(t): return t.contains("날개 이리 내")), true)
	GameState.companion = null
	mira.state = "WANDER"
	var zal: Array = Quests.by_id("m5").steps[1].scene
	var nara = _follow("Nara", c + Vector2(90, 0))
	var said: Array = zal.filter(func(l): return l.has("with") and Chronicle._with(l)).map(func(l): return l.who)
	_check("잘고라 뒤: 곁에 온 나라만 한마디", said, ["Nara"])
	GameState.companion = null
	nara.state = "WANDER"


## 원정대 창: 동료가 있으면 상태판 밑에 뜬다. 쓰러지면 "쓰러짐", 나 혼자 가는 곳에서는 흐리게 "밖에서 기다린다"
func _panel() -> void:
	var c := await _dojo()
	var hud = Hud.current
	var panel = hud.get_node_or_null("PartyPanel")
	_check("원정대 창이 HUD 에 붙어 있다", panel != null, true)
	_check("상태판 바로 뒤에 그린다 (대화창 · 창들보다 아래)", panel.get_index() == hud.status.get_index() + 1, true)
	await get_tree().create_timer(0.2).timeout
	_check("동료가 없으면 숨는다", panel.visible, false)
	var nara = _follow("Nara", c + Vector2(90, 0))
	await get_tree().create_timer(0.2).timeout
	_check("동료가 있으면 뜬다", panel.visible, true)
	var rows: Array = panel.get_node("List").get_children()
	_check("줄 수 = 동료 수", rows.size(), 1)
	_check("이름 · 역할", [rows[0].get_node("Row/Info/Top/Name").text, rows[0].get_node("Row/Info/Top/Role").text], ["나라", "치기"])
	_check("상태판 밑에 붙는다", panel.position.y > hud.status.position.y + hud.status.size.y * hud.status.scale.y, true)
	nara.take_damage(99999)
	await get_tree().create_timer(0.2).timeout
	_check("쓰러지면 '쓰러짐'", rows[0].get_node("Row/Info/Hp/Num").text, "쓰러짐")
	nara.down_timer = 0.0
	nara.hp = nara.max_hp
	hud.collapse_status(true)
	await get_tree().create_timer(0.1).timeout
	_check("상태판을 접으면 같이 숨는다", panel.visible, false)
	hud.collapse_status(false)
	GameState.quests.active["m6"] = { step = 1, n = 0 }
	await _go("AUTUMN")
	await _go("VOLCANO")
	await get_tree().create_timer(0.2).timeout
	rows = panel.get_node("List").get_children()
	_check("나 혼자 가는 곳: 밖에서 기다린다", rows[0].get_node("Row/Info/Hp/Num").text if not rows.is_empty() else "", "밖에서 기다린다")
	GameState.quests.active.erase("m6")
	GameState.companion = null
	nara.state = "WANDER"


## 장면에서 처음으로 보이는 줄 (고른 것 · 곁의 용으로 거른 뒤)
func _first_shown(lines: Array) -> Dictionary:
	for l in lines:
		if Chronicle._chosen(l) and Chronicle._with(l): return l
	return {}


## 내가 쓰러지면 가진 고기 절반을 잃고, 따라오던 동료는 그날 돌아간다. 마을에서 깬다
func _player_down() -> void:
	var c := await _dojo()
	await get_tree().create_timer(0.4).timeout   # 방금 옮겨 온 길은 잠깐 잠겨 있다 (World._travel_lock)
	var p = GameState.player
	var mira = _follow("Mira", c + Vector2(100, 0))
	p.inventory.meat = 7
	p.invuln = 0.0
	p.take_damage(99999)
	for i in 5: await get_tree().process_frame
	_check("쓰러지면 고기 절반을 잃는다 (7 → 4)", p.inventory.meat, 4)
	_check("따라오던 동료는 그날 돌아간다", Party.went_home(mira) and GameState.companion == null, true)
	_check("마을에서 깬다", GameState.map_id, "VILLAGE")
	_check("체력은 다 찬다", p.hp == p.max_hp, true)


## 쓰러지는 · 무릎 꿇은 · 장면을 기다리는 보스와 땅속의 적은 아무도 쏘지 않는다
func _hittable() -> void:
	var b := Boss.make("ZALGORA")
	_check("잠든 보스", Combat.hittable(b), false)
	b.awake = true
	_check("깨어난 보스", Combat.hittable(b), true)
	b.dying = 1.0
	_check("쓰러지는 보스", Combat.hittable(b), false)
	b.dying = 0.0; b.lingering = true
	_check("무릎 꿇은 보스 (흐릿하게 남음)", Combat.hittable(b), false)
	b.lingering = false; b.yielding = true
	_check("장면을 기다리는 보스", Combat.hittable(b), false)
	b.free()
	var e := Enemy.make(0, 0, "SLIME")
	_check("들판의 적", Combat.hittable(e), true)
	e.is_hidden = true
	_check("땅속에 숨은 적", Combat.hittable(e), false)
	e.free()


# ---------- 돕는 것 ----------

## 지도를 옮긴다 (방금 옮겨 온 길은 잠깐 잠겨 있어서 조금 기다렸다가). 도착해서 열린 장면은 넘긴다
func _go(map_id: String) -> void:
	await get_tree().create_timer(0.4).timeout
	World.travel_to(map_id)
	for i in 3: await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000 and (Cutscene.on or GameState.isDialogueOpen):
		await get_tree().process_frame
		_advance()


## 수련장 가운데에 선다 (들짐승이 저절로 나오지 않는 곳). 선 자리를 돌려준다
func _dojo() -> Vector2:
	if GameState.map_id != "DOJO": await _go("DOJO")
	for e in GameState.entities.enemies: e.remove = true
	var m := World.get_map("DOJO")
	var c := World.clear_spot(m.w / 2.0, m.h / 2.0, m)
	GameState.player.x = c.x; GameState.player.y = c.y
	return c


## 그 용을 이 지도의 그 자리에 세운다 (앞 시험에서 문으로 걸어 나간 용이면 표시가 남아 있다)
func _place(n, at: Vector2) -> void:
	n.walk_to = null; n.down_timer = 0.0; n.passive = false
	n.remove = false; n.is_hidden = false
	n.hp = n.max_hp
	if not GameState.entities.npcs.has(n): World.add_entity("npcs", n)
	n.x = at.x; n.y = at.y


## 그 용을 동료(고른 칸)로 곁에 세운다. 고른 칸은 하나라 먼저 있던 동료는 빠진다
func _follow(nm: String, at: Vector2):
	var n = World.any_npc(nm)
	if GameState.companion and GameState.companion != n: GameState.companion.state = "WANDER"
	GameState.companion = n
	n.state = "COMPANION_FOLLOW"
	_place(n, at)
	return n


## 그 용을 짝으로 곁에 세운다 (따라다닌다)
func _mate(nm: String, at: Vector2):
	var n = World.any_npc(nm)
	GameState.partner = n
	n.state = "PARTNER_FOLLOW"
	_place(n, at)
	return n


## 그 용의 "함께" 메뉴 (묶음이면 펼쳐서) { label, on_select } 들
func _menu_options(npc) -> Array:
	var m = NpcActions._own_menu(npc, str(npc.config.name))
	if m == null: return []
	if str(m.label) != "🤝 함께하자고 한다": return [m]
	m.on_select.call()   # 묶음을 대화창에 펼친다
	var out: Array = DialogueBox.current._list.duplicate()
	NpcActions.close()
	return out


func _menu_labels(npc) -> Array:
	return _menu_options(npc).map(func(o): return str(o.label))


## 쓰러지지 않는 적 하나. speed 를 주면 그 빠르기로 (0 이면 제자리)
func _foe(at: Vector2, type: String, speed := -1.0) -> Enemy:
	var s := Enemy.make(at.x, at.y, type)
	s.def = s.def.duplicate()
	if speed >= 0: s.def.speed = speed
	s.max_hp = 99999.0; s.hp = s.max_hp
	World.add_entity("enemies", s)
	return s


var _last_click := 0
func _advance() -> void:
	if Time.get_ticks_msec() - _last_click < 250: return
	_last_click = Time.get_ticks_msec()
	if Cutscene.busy() and not DialogueBox.is_open(): Cutscene.rush()
	elif DialogueBox.is_open():
		DialogueBox.current._text.visible_characters = -1
		DialogueBox.current._choose(0)


func _check(what: String, got, want) -> void:
	var ok: bool = str(got) == str(want)
	if not ok: _bad += 1
	print("%s %s  (%s%s)" % ["OK  " if ok else "틀림", what, str(got), "" if ok else " · 기대 %s" % str(want)])
