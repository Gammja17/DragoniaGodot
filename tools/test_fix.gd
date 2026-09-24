extends Node
## B 세션(조건·구조 고치기 · 확인된 버그)에서 고친 것을 하나씩 확인한다.
## 줄마다 기대한 값과 실제 값을 찍고, 맞으면 OK · 틀리면 틀림. 맨 끝에 틀린 곳의 수.
##   godot --headless --path . res://tools/test_fix.tscn

var _box: DialogueBox
var _bad := 0


func _ready() -> void:
	Save.slot = 9   # 시험은 9번 칸을 쓴다 (사람이 쓰는 1~3번 칸을 건드리지 않게)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.play_intro = false
	main.load_save = false
	add_child(main)
	for i in 5: await get_tree().process_frame
	_box = DialogueBox.current
	var p: Dragon = GameState.player
	# 사건이 저절로 끼어들지 않게 모두 본 것으로 둔다 (여기서는 조건 · 대사만 본다)
	for ev in Data.get_module("chronicle").CHRONICLE: GameState.story.events.append(ev.id)
	var elder = World.any_npc("Elder")
	var kairon = World.any_npc("Kairon")
	var tia = World.any_npc("Tiamat")
	var poco = World.any_npc("Poco")
	var nara = World.any_npc("Nara")

	# ---- 날씨: 폭풍은 번개 치는 센 비. 비가 그려지지 않는 곳에서는 그친다 ----
	GameState.weather.type = "RAIN"
	GameState.weather.storm = true
	GameState.weather.timer = 50.0
	_check("날씨 · 폭풍은 센 비", [Weather.stormy(), Weather.weather_name(), GameState.weather.type], [true, "폭풍", "RAIN"])
	Weather.update(0.1)
	_check("날씨 · 마을에서는 폭풍이 이어진다", GameState.weather.type, "RAIN")
	Save.save_game()
	_check("날씨 · 폭풍을 저장한다", Save.read().weather, "STORM")
	World.travel_to("SNOW_ROAD")
	await _wait(0.5)   # 지도를 옮긴 뒤 잠깐은 다시 옮길 수 없다 (World 의 이동 잠금)
	Weather.update(0.1)
	_check("날씨 · 설원에 들어서면 비가 그친다", [Terrain.active_biome(), GameState.weather.type], ["SNOW", "CLEAR"])
	World.travel_to("VILLAGE")
	await _wait(0.5)
	_check("시험 준비 · 마을로 돌아왔다", GameState.map_id, "VILLAGE")
	GameState.weather.type = "CLEAR"
	GameState.weather.storm = false

	# ---- 옛 굴에서 받은 성장 포인트: 불러와도 남는다 ----
	p.level = 1
	p.stage_index = 0
	GameState.growth = { points = 0, nodes = {}, ranks = {} }
	GameState.story.delve = { FOREST_HOLE = { best = 8, claimed = [3, 5, 8] } }
	Growth.reconcile_points()
	_check("성장 포인트 · 옛 굴 이정표(2+3)", GameState.growth.points, 5)

	# ---- 인연 장면: 다른 데서 호감을 올려 단계를 건너뛰어도 사라지지 않는다 ----
	GameState.day = 2   # 첫날에는 인연 장면을 꺼내지 않는다 (NpcActions._book_bond)
	GameState.story.bonds = []
	GameState.pendingBond = null
	tia.relation = 60.0
	NpcActions.add_relation(tia, 1)
	_check("인연 · 건너뛴 1단계부터", _bond(), "Tiamat:1")
	GameState.pendingBond = null   # 장면을 본 셈
	NpcActions.add_relation(tia, 1)
	_check("인연 · 다음은 2단계", _bond(), "Tiamat:2")
	NpcActions.add_relation(tia, 1)
	_check("인연 · 기다리는 장면이 있으면 덮어쓰지 않는다", _bond(), "Tiamat:2")
	GameState.pendingBond = null
	poco.relation = 20.0
	var fake := { id = "zz_test_reward", act = "Poco", giver = "Poco", title = "시험", reward = { relation = 10 } }
	Quests.turn_in(fake, poco)
	GameState.quests.done.erase("zz_test_reward")
	GameState.questScenes.clear()
	_check("인연 · 퀘스트 보상의 호감도 장면을 예약한다", _bond(), "Poco:1")
	GameState.pendingBond = null
	for n in GameState.entities.npcs:
		if n.config.get("fixed"): n.relation = 0.0
	elder.relation = 24.0
	GameState.raid.active = true
	Raid._end()
	_check("인연 · 습격을 막은 호감도 장면을 예약한다", _bond(), "Elder:1")
	GameState.pendingBond = null
	GameState.day = 1
	elder.relation = 30.0
	GameState.story.bonds = []
	NpcActions.add_relation(elder, 1)
	_check("인연 · 첫날에는 장면을 꺼내지 않는다", _bond(), "없음")

	# ---- 엘더 · 카이론이 짝이어도 동행 · 나들이 메뉴가 있다 ----
	GameState.partner = elder
	_check("짝 엘더 · 축복과 동행을 한데 묶는다", NpcActions._own_menu(elder, "Elder").label, "🤝 함께하자고 한다")
	GameState.partner = null
	_check("짝 아닌 엘더 · 축복만", NpcActions._own_menu(elder, "Elder").label, "✨ 축복을 청한다")
	_check("짝 아닌 카이론 · 가르침만", NpcActions._own_menu(kairon, "Kairon").label, "🎓 가르침을 청한다")

	# ---- 수련 중인 스승은 보스의 둥지까지 따라가지 않는다 ----
	_check("수련 · 보스가 사는 곳", [Training._boss_lair("MORGATH_LAIR"), Training._boss_lair("VILLAGE")], [true, false])
	if not GameState.story.scenes.has("ch1"): GameState.story.scenes.append("ch1")
	GameState.story.plan = { day = GameState.day, kind = "HUNT_CLEAN", stage = "active", n = 1 }
	GameState.companion = kairon
	kairon.state = "COMPANION_FOLLOW"
	GameState.isDialogueOpen = false
	var real_map: String = GameState.map_id
	GameState.map_id = "MORGATH_LAIR"
	Training.update()
	GameState.map_id = real_map
	_check("수련 · 둥지 앞에서 동행이 끝난다", GameState.companion == null, true)
	_check("수련 · 오늘 수련은 다시 청할 수 있다", [GameState.story.plan.stage, GameState.story.plan.n], ["offered", 0])
	_check("수련 · 문으로 걸어 나간다", kairon.walk_to != null and kairon.walk_to.get("leave", false), true)
	kairon.walk_to = null
	kairon.remove = false
	kairon.state = "WANDER"
	GameState.partner = kairon
	GameState.companion = kairon
	kairon.state = "COMPANION_FOLLOW"
	Training._end_company()
	_check("수련 · 짝인 스승은 수련이 끝나도 따라다닌다", kairon.state, "PARTNER_FOLLOW")
	GameState.partner = null
	kairon.state = "WANDER"

	# ---- 큰 대목을 마친 날은 다음 본 이야기를 내일 아침에 ----
	GameState.story.erase("restUntil")
	GameState.dayTime = 0.5
	GameState.quests = { active = { m2 = { step = 2, n = 0 } }, done = ["m0", "m1"], tracked = null, choices = {} }
	var big := Quests.turn_in(Quests.by_id("m2"), elder)
	GameState.questScenes.clear()
	_check("흐름 · 장이 끝나는 대목은 큰 대목", big, true)
	_check("흐름 · 보스 대목도 큰 대목", Quests._has_boss(Quests.by_id("m5")), true)
	_check("흐름 · 그날은 다음 본 이야기를 꺼내지 않는다", Quests.offer_for(elder) == null, true)
	_check("흐름 · 할 이야기는 내일 아침에", _id(Quests.rest_offer(elder)), "m3")
	_check("흐름 · '부탁할 일이 있는 눈치'가 아니다", Quests.held_offer(elder) == null, true)
	_check("흐름 · 추적창 귀띔", Quests.suggestion().title, "오늘은 여기까지")
	GameState.dayTime = 0.95
	_check("흐름 · 그날 밤에도 쉰다", Quests.resting(), true)
	GameState.day += 1
	GameState.dayTime = 0.1
	_check("흐름 · 자정을 넘겨도 새벽 전에는 쉰다", Quests.resting(), true)
	GameState.dayTime = 0.27
	_check("흐름 · 아침이면 꺼낸다", _id(Quests.offer_for(elder)), "m3")
	GameState.quests = { active = {}, done = ["m0", "m1", "m2"], tracked = null, choices = {} }

	# ---- 게시판: 떠난 용의 쪽지 · 결말 뒤의 습격 쪽지 ----
	var goblin = Chores._by_id("c_goblin")
	var chest = Chores._by_id("c_chest")
	var upgrade = Chores._by_id("c_upgrade")
	var ember_note = Chores._by_id("c_upgrade_ember")
	var raid_note = Chores._by_id("c_raid")
	_check("게시판 · 그론이 있을 때", [Chores._open(goblin), Chores._open(chest), Chores._open(upgrade), Chores._open(ember_note)], [true, true, true, false])
	GameState.story.dead = ["Gron"]
	GameState.story.deathDay = { Gron = GameState.day }
	_check("게시판 · 그론이 떠난 뒤", [Chores._open(goblin), Chores._open(chest), Chores._open(upgrade), Chores._open(ember_note)], [false, false, false, false])
	GameState.story.deathDay.Gron = GameState.day - 3
	_check("게시판 · 불이 다시 붙으면 엠버의 쪽지", Chores._open(ember_note), true)
	GameState.story.dead = []
	GameState.story.erase("deathDay")
	_check("게시판 · 결말 전 습격 쪽지", Chores._open(raid_note), true)
	GameState.story.endingSeen = "guardian"
	_check("게시판 · 결말 뒤 습격 쪽지는 빠진다", Chores._open(raid_note), false)
	GameState.story.endingSeen = ""

	# ---- 잡담: 미라가 털어놓은 뒤로 엘더가 모르는 척하지 않는다 ----
	var em: Dictionary = Data.get_module("chatter").CHATTER.filter(func(c): return c.get("id") == "elder_mira_falls")[0]
	_check("잡담 · s1 전 엘더와 미라의 폭포 잡담", em.when.call(GameState), true)
	GameState.quests.done.append("s1")
	_check("잡담 · s1 뒤에는 빠진다", em.when.call(GameState), false)
	GameState.quests.done.erase("s1")

	# ---- 일과: 어둠의 길 뒤의 스승 · 나라의 저녁 · 이그나르의 직함 ----
	GameState.story.route = "dark"
	GameState.quests.done.append("m7d")
	_check("일과 · 어둠의 길 뒤 카이론의 아침", Routine.plan_for("Kairon", 8.5).doing, "아무도 오지 않는 수련장 문을 열어 두고 서 있다")
	_check("수련 · 어둠의 길 뒤로는 오늘의 수련이 없다", Training.todays_plan(), null)
	GameState.story.erase("route")
	GameState.quests.done.erase("m7d")
	_check("일과 · 평소 카이론의 아침", Routine.plan_for("Kairon", 8.5).doing, "나라의 자세를 하나하나 고쳐 준다")
	_check("일과 · 나라의 저녁은 마을 모닥불 · 밤은 수련장", [Routine.plan_for("Nara", 19.5).map, Routine.plan_for("Nara", 21.5).map], ["VILLAGE", "DOJO"])
	_check("일과 · 이그나르 어둠의 갈래 직함 (데이터)", Data.get_module("routines").ROUTINES.Ignar.variants[0].get("job"), "잿마루의 주인")

	# ---- 자는 칸: 말을 걸면 부스스 깬다 ----
	var doran = World.any_npc("Doran")
	var saved_doing = doran.doing
	doran.doing = "집 앞 평상에서 코를 골고 있다"
	var sleeping := NpcActions._asleep(doran)
	doran.doing = "호숫가에 낚싯줄을 드리우고 꾸벅꾸벅 존다"
	_check("자는 칸 · 평상에서 코를 곤다 / 낚시", [sleeping, NpcActions._asleep(doran)], [true, false])
	doran.doing = saved_doing

	# ---- 질투할 때 부르는 말 ----
	_check("호칭 · 나라가 엘더를", Romance._fill(nara, "어제 {rival}하고", "Elder"), "어제 우리 아빠하고")
	_check("호칭 · 포코가 티아맷을", Romance._fill(poco, "{rival}하고", "Tiamat"), "티아맷 누나하고")
	_check("호칭 · 카이론이 이그나르를", Romance._fill(kairon, "{rival}하고", "Ignar"), "형하고")
	_check("호칭 · 표에 없으면 이름", Romance._fill(elder, "{rival}하고", "Kairon"), "카이론하고")

	# ---- 일지 [마을 용들]: 달맞이 모임 줄 · 사이 단계 ----
	# 맨 앞에서 사건을 모두 본 것으로 둔 탓에 첫 모임도 본 셈이 됐다. 폭포 · 모임은 아직 안 본 것으로 되돌린다
	GameState.story.events.erase("ev_gathering")
	GameState.story.events.erase("ev_falls")
	var j: JournalPanel = Hud.current.journal
	j.tab = "folk"
	j.render()
	_check("일지 · 모임을 알기 전에는 달맞이 줄이 없다", _texts(j).any(func(t): return t.contains("달맞이")), false)
	GameState.quests.active.m5g = { step = 0, n = 0 }
	j.render()
	_check("일지 · 첫 모임 날", _texts(j).any(func(t): return t.contains("스무 해 만에 달맞이 모임이 다시 선다")), true)
	GameState.partner = tia
	j.render()
	_check("일지 · 짝은 '짝'", _texts(j).any(func(t): return t.ends_with("· 짝")), true)
	_check("일지 · '연인'은 없다", _texts(j).any(func(t): return t.contains("연인")), false)
	GameState.partner = null

	# ---- 말을 걸면 뜨는 퀘스트 한 줄: 힌트로, 하나짜리는 숫자 없이 ----
	NpcActions.open_hub(elder, true)
	var hub_text: String = _box.shown_text()
	_check("진행 줄 · 힌트로 ('그 자리에 가 있기 0/1'이 아니다)", hub_text.contains("해가 진 뒤") and not hub_text.contains("그 자리에") and not hub_text.contains("0/1"), true)
	NpcActions.close()
	GameState.quests.active.erase("m5g")

	# ---- 화살표 이름표 ----
	_check("화살표 · 보스 이름", Guide._boss_place("MORGATH").label, "옛 수호룡 모르가스")

	# ---- 알 맡기기: 성체에게는 '아직 어렵다'고 하지 않는다 ----
	p.stage_index = 2
	p.carrying = "EGG"
	GameState.eggSitting = null
	NpcActions._entrust_egg(elder)
	_box._text.visible_characters = -1
	_box._choose(0)
	_check("알 · 성체에게", _box.shown_text().begins_with("이제 네 몸으로도"), true)
	NpcActions.close()
	GameState.eggSitting = null

	# ---- 엠버가 모루를 맡으면 엠버의 말투 ----
	var ember = World.any_npc("Ember")
	NpcActions._open_goods(ember)
	_check("대장간 · 엠버(골드로 산다)", _box.shown_text().begins_with("돈으로 사겠다면 안 말릴게."), true)
	NpcActions._forge_one(ember, Forge.recipes()[0])
	_check("대장간 · 엠버(재료가 모자라)", _box.shown_text().begins_with("재료가 모자라."), true)
	NpcActions.close()

	# ---- 혼잣말: 묶음에는 누가 해도 맞는 줄만 ----
	var dl: Dictionary = Data.get_module("dialogues")
	_check("혼잣말 · 그론의 줄은 묶음에서 빠지고 그론 표로", [dl.IDLE_LINES.GRUMPY.has("요즘 쇠가 예전 쇠가 아니야."), dl.IDLE_BY_NPC.Gron.has("요즘 쇠가 예전 쇠가 아니야.")], [false, true])
	_check("술래잡기 · 받침 있는 이름", Util.josa("이슬", "이", "가"), "이슬이")

	print("[끝] 틀린 곳 %d" % _bad)
	get_tree().quit()


func _check(what: String, got, want) -> void:
	var ok: bool = typeof(got) == typeof(want) and got == want
	if not ok: _bad += 1
	print("[%s] %s  (기대 %s · 실제 %s)" % [what, "OK" if ok else "틀림", str(want), str(got)])


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000: await get_tree().process_frame


func _bond() -> String:
	var b = GameState.pendingBond
	return "%s:%d" % [b.name, b.tier] if b else "없음"


func _id(q) -> String:
	return q.id if q else "없음"


## 일지 목록에 떠 있는 글 전부
func _texts(j: JournalPanel) -> Array:
	var out := []
	var stack: Array = j._list.get_children()
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is Label: out.append(n.text)
		stack.append_array(n.get_children())
	return out
