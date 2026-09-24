extends Node
## 이야기 다시 쓰기(C 세션)를 장마다 확인한다. 판을 세우고 → 사건·퀘스트를 흘려서 → 뜬 대사와 결과를 본다.
##   godot --headless --path . res://tools/test_chapters.tscn
## 줄마다 [장] OK/FAIL 을 찍고, 끝에 실패 수를 센다. 저장은 9번 칸만 쓴다.

var _box: DialogueBox
var _seen := []      # 대화창에 뜬 글을 모아 둔다
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
	GameState.elderTutorialDone = true
	GameState.tutorial.finished = true
	_frame()
	await _chapter1()
	await _chapter2()
	await _chapter3()
	await _chapter4()
	await _chapter5()
	await _chapter6()
	await _chapter7()
	await _chapter8()
	_life()
	print("[끝] 실패 %d" % _fails)
	get_tree().quit()


## 0단계 틀: 고른 것 읽기 · 보스 잡은 날 · 첫인상
func _frame() -> void:
	GameState.quests.choices.m1 = "ask"
	var lines := [{ text = "A", chose = "m1:ask" }, { text = "B", chose = "m1:quiet" }, { text = "C", chose = "m1:!ask" }, { text = "D" }]
	_check("틀", "고른 것 읽기 (m1=ask → A·D)", lines.filter(func(l): return Chronicle._chosen(l)).map(func(l): return l.text) == ["A", "D"])
	GameState.quests.choices.erase("m1")
	GameState.day = 7
	GameState.bossesDefeated.ZALGORA = true
	Chronicle._stamp_bosses()
	_check("틀", "보스 잡은 날 적기", GameState.story.get("bossDay", {}).get("ZALGORA") == 7)
	GameState.bossesDefeated.erase("ZALGORA")
	GameState.story.erase("bossDay")
	GameState.day = 1
	Prologue._first_looks()
	_check("틀", "첫인상 호감 (엘더 15 · 단 0)", World.any_npc("Elder").relation == 15.0 and World.any_npc("Dan").relation == 0.0)


func _chapter1() -> void:
	# 경계: 첫 습격 전까지 단은 하늘에서 떨어진 아이를 꺼린다. 습격을 같이 막은 뒤에는 그 말이 안 나온다
	var dan = World.any_npc("Dan")
	var talk: Dictionary = Data.get_module("npcTalk").NPC_TALK.Dan
	GameState.raid.count = 0
	_check("1장", "첫 습격 전: 단의 경계 인사", _greets(dan, talk, "얼쩡대지"))
	GameState.raid.count = 1
	_check("1장", "첫 습격 뒤: 경계 인사 안 나옴", not _greets(dan, talk, "얼쩡대지"))
	GameState.raid.count = 0
	# 첫 밤: 골짜기의 울음과 엘더의 당부
	GameState.day = 2
	GameState.dayTime = 0.85
	GameState.story.lessons = ["L1"]
	await _play_until(func(): return GameState.story.events.has("ev_first_night"), 30)
	_check("1장", "첫 밤: '그 끝으로는 가지 말거라'", _saw("그 끝으로는 가지 말거라"))
	# p1: 포코가 엿들은 말 → 엘더의 "아직 이르다"
	GameState.dayTime = 0.4
	var p1 = Quests.by_id("p1")
	Quests.accept(p1)
	Quests.complete_step(p1)
	Quests.complete_step(p1)
	Quests.turn_in(p1, World.any_npc("Poco"), "later")
	await _play_until(_idle, 30)
	_check("1장", "p1: 그날 밤 수군거림", _saw("예전 그 아이처럼 되면 어쩌나"))
	_check("1장", "p1: 엘더 '아직 이르구나'", _saw("아직 이르구나"))
	_check("1장", "p1: 고른 줄 (later)", _saw("맨날 아직 이르대"))
	_check("1장", "p1: 단서 whisper", GameState.story.clues.has("whisper") and Data.get_module("chronicle").CLUES.has("whisper"))
	# p2: 포코의 보물은 정말 받는다
	var p2 = Quests.by_id("p2")
	Quests.accept(p2)
	Quests.complete_step(p2)
	Quests.complete_step(p2)
	var gold: int = GameState.player.gold
	Quests.turn_in(p2, World.any_npc("Poco"), null)
	await _play_until(_idle, 30)
	_check("1장", "p2: 포코 보물 50G", GameState.player.gold - gold == 50)
	# 옛 굴: 그론한테 들은 적 없는 말은 하지 않는다
	_check("1장", "ev_cave: 그론 얘기 없음", not JSON.stringify(_event("ev_cave").lines).contains("그론"))


func _chapter2() -> void:
	# 첫 습격을 같이 막은 뒤 한동안: 티아맷이 "네 자리도 있다"
	var tia = World.any_npc("Tiamat")
	var talk: Dictionary = Data.get_module("npcTalk").NPC_TALK.Tiamat
	GameState.raid.count = 1
	_check("2장", "첫 습격 뒤: 티아맷 '네 자리도 있으니까'", _greets(tia, talk, "네 자리도 있으니까"))
	GameState.raid.count = 3
	_check("2장", "세 번째 습격부터는 안 나옴", not _greets(tia, talk, "네 자리도 있으니까"))
	# m3 마무리: 덫을 봤을 때(m1) 묻지 않았으면 엘더가 그걸 기억한다
	GameState.quests.choices.m1 = "quiet"
	var m3 = Quests.by_id("m3")
	Quests.accept(m3)
	for i in 4: Quests.complete_step(m3)
	Quests.turn_in(m3, World.any_npc("Elder"), "press")
	await _play_until(_idle, 40)
	_check("2장", "m3: m1 에서 안 물은 걸 기억 ('이번엔 묻는구나')", _saw("이번엔 묻는구나"))
	_check("2장", "m3: m1=ask 줄은 안 나옴", not _saw("둘만 알자고 했었지"))
	_check("2장", "m3 보고 뒤: 3장에 할 일 (어른 몸이 되기)", _saw("카이론 밑에서 몸을 키우거라"))
	# n1 끝: 나라가 마음을 바꾼다
	var n1 = Quests.by_id("n1")
	Quests.accept(n1)
	for i in 2: Quests.complete_step(n1)
	Quests.turn_in(n1, World.any_npc("Nara"), "tip")
	await _play_until(_idle, 30)
	_check("2장", "n1: '얄미운 애는 그런 거 안 해'", _saw("얄미운 애는 그런 거 안 해"))


func _chapter3() -> void:
	var G := GameState
	for id in ["m0", "m1", "m2"]:
		if not G.quests.done.has(id): G.quests.done.append(id)
	# 3장이 열려도 누리가 사라지기 전에는 무덤이 막혀 있다
	_check("3장", "누리 사건 전: 무덤 막힘", not Chapters.map_open(G, "MORGATH_LAIR") and Chapters.blocked_text(G, "MORGATH_LAIR").contains("냉기"))
	_check("3장", "골짜기는 열림", Chapters.map_open(G, "HOLLOW"))
	# 골짜기 첫 걸음: 울음만 들리고, 카이론도 퀘스트도 없다
	World.travel_to("HOLLOW")
	await _play_until(func(): return G.story.events.has("ev_morgath") and _idle(), 30)
	_check("3장", "골짜기의 울음 (카이론 없이)", _saw("첫날 밤 마을에서 들었던") and not G.quests.active.has("m4"))
	# 성체가 된 날: 의식이 끝나자 누리가 사라진다
	World.travel_to("VILLAGE")
	await _wait(0.5)
	G.player.stage_index = 2
	if not G.story.rites.has(1): G.story.rites.append(1)
	Story.play_rite(2)
	await _play_until(func(): return G.story.events.has("ev_nuri_lost") and _idle(), 60)
	_check("3장", "성체 의식: 단·소이가 떨어져 서 있다", _saw("단과 소이가 누리를 붙들고"))
	_check("3장", "사라진 누리 → m4", G.quests.active.has("m4") and _saw("지금은 네가 제일 빠르구나"))
	_check("3장", "이제 무덤이 열림", Chapters.map_open(G, "MORGATH_LAIR"))
	# 무덤: 모르가스를 쓰러뜨리면 흐릿하게 남아 누리·엘더와 장면이 흐른다
	World.travel_to("MORGATH_LAIR")
	await _wait(0.5)
	var b = null
	for x in G.entities.bosses:
		if x.id == "MORGATH": b = x
	_check("3장", "무덤에 모르가스가 있다 (골짜기의 울음 뒤)", b != null)
	if b:
		G.player.max_hp = 9000; G.player.hp = 9000
		G.player.x = b.x; G.player.y = b.y + 300
		await _play_until(func(): return b.awake and _idle(), 20)
		var t := Time.get_ticks_msec()
		while not G.bossesDefeated.get("MORGATH", false) and Time.get_ticks_msec() - t < 20000:
			if _idle() and b.dying <= 0: b.take_damage(b.hp + 1)
			await get_tree().process_frame
			_advance()
		await _play_until(func(): return _saw("애가 타서 쓰러지겠구나") and _idle(), 90)
	_check("3장", "모르가스 → 엘더 '이제 그만 미뤄라'", _saw("이제 그만 미뤄라"))
	_check("3장", "모르가스 '늦어서 미안하다고 전해 다오'", _saw("늦어서 미안하다고"))
	_check("3장", "누리가 무사하다", _saw("뼈 할아버지"))
	_check("3장", "엘더의 고백: 스승 · 봉우리의 그이 · 예외는 딱 하나", _saw("젊은 나를 가르친 스승") and _saw("글라시아") and _saw("예외는 딱 하나였다"))
	_check("3장", "얼음을 건네받음", G.player.elements.has("ICE"))
	# 마을: 소이가 먼저 다가오고, 단·소이가 마음을 연다
	var dan0: float = World.any_npc("Dan").relation
	World.travel_to("VILLAGE")
	await _wait(0.5)
	var soi = World.any_npc("Soi")
	G.player.x = soi.x - 120; G.player.y = soi.y
	await _play_until(func(): return G.quests.active.has("m4") and int(G.quests.active.m4.step) >= 2 and _idle(), 40)
	_check("3장", "단 '얼쩡대 줘라'", _saw("얼쩡대 줘라"))
	_check("3장", "단 호감 +25", World.any_npc("Dan").relation - dan0 >= 25.0)
	# 모르가스를 보낸 소식은 며칠만 반긴다
	var elder = World.any_npc("Elder")
	var etalk: Dictionary = Data.get_module("npcTalk").NPC_TALK.Elder
	_check("3장", "며칠 안: 엘더 '스승님을 보내 드렸구나'", _greets(elder, etalk, "스승님을 보내 드렸구나"))
	G.day += 6
	_check("3장", "엿새 뒤: 그 인사는 안 나옴", not _greets(elder, etalk, "스승님을 보내 드렸구나"))
	# 폭포 길이 녹았다: 세이란이 속성 둘을 알아본다
	World.travel_to("FALLS")
	await _play_until(func(): return G.story.events.has("ev_falls") and _idle(), 40)
	_check("3장", "세이란 '속성이 둘이구나'", _saw("속성이 둘이구나") and not _saw("두 겹으로"))
	var m4 = Quests.by_id("m4")
	_check("3장", "폭포까지 가면 보고만 남는다", Quests.is_complete(m4))
	Quests.turn_in(m4, elder, null)
	await _play_until(_idle, 30)
	_check("3장", "보고: 세이란 얘기 · 단서 breath", _saw("세이란이라는 아이") and G.story.clues.has("breath"))
	# 다음 날 아침: 누리와 엘더가 찾아온다 (카이론 아님)
	_check("3장", "3장 꿈: 누리·엘더, 카이론 없음", not JSON.stringify(_scene("ch4").lines).contains("Kairon") and JSON.stringify(_scene("ch4").lines).contains("빙결 파동"))
	_check("3장", "재 냄새 꿈: 목소리가 먼저 밝힌다", JSON.stringify(_scene("dream_ice").lines).contains("나도 너처럼 하늘에서 떨어졌다"))


func _chapter4() -> void:
	var G := GameState
	World.travel_to("VILLAGE")
	await _wait(0.5)
	# 뿌리골의 부탁은 쌍두룡을 보낸 뒤에야
	var r1 = Quests.by_id("r1")
	_check("4장", "r1: 잘고라 전에는 안 나옴", not Quests._ready_quest(r1))
	# m5: 잘고라의 마지막 · 티아맷이 같이 불러 달라는 이름 · 엘더가 기억하는 그해 겨울
	G.quests.choices.t1 = "count"
	var m5 = Quests.by_id("m5")
	Quests.accept(m5)
	Quests.complete_step(m5)
	G.bossesDefeated.ZALGORA = true
	Quests.complete_step(m5)
	Quests.complete_step(m5)
	Quests.turn_in(m5, World.any_npc("Elder"), null)
	await _play_until(_idle, 60)
	_check("4장", "잘고라 '둘이 붙어 버렸어' · 번개(숨 아님)", _saw("둘이 붙어 버렸어") and _saw("우리 번개였어"))
	_check("4장", "t1=count: '같이 불러 준 것처럼'", _saw("같이 불러 준 것처럼"))
	_check("4장", "엘더: 그해 겨울엔 먹을 게 없었다", _saw("먹을 게 하나도 없었단다"))
	_check("4장", "r1: 잘고라 뒤에는 나옴", Quests._ready_quest(r1))
	_check("4장", "4장 아침: 그론 '그해 겨울엔 다들 굶었다'", JSON.stringify(_scene("ch5").lines).contains("그해 겨울엔 다들 굶었다"))
	# 고기가 돌아온 며칠: 소이가 누리 얘기를 한다
	G.story.bossDay = { ZALGORA = G.day }
	var soi = World.any_npc("Soi")
	_check("4장", "고기 인사 (소이)", _greets(soi, Data.get_module("npcTalk").NPC_TALK.Soi, "두 점이나"))


func _chapter5() -> void:
	var G := GameState
	# 4장 끝: 스무 해 만의 달맞이 모임에서 봉우리의 알을 데려오기로 정한다
	var m5g = Quests.by_id("m5g")
	Quests.accept(m5g)
	World.travel_to("FALLS")
	await _wait(0.5)
	G.dayTime = 0.88
	await _play_until(func(): return G.story.events.has("ev_gathering") and _idle(), 40)
	_check("5장", "모임: 봉우리의 아이들을 데려오자", _saw("봉우리의 아이들을 데려옵시다"))
	_check("5장", "모임: 왜 지금 (울음이 멎은 뒤 냉기가 짙어짐)", _saw("냉기가 도리어 짙어졌소"))
	_check("5장", "모임: 사절 유안·티아맷", _saw("구름마루에서는 유안이 가오") and _saw("웨스턴에서는 제가 가요"))
	_check("5장", "하루는 두 번째 만남 (폭포에서 봤지?)", _saw("폭포에서 봤지?"))
	World.travel_to("CLOUDTOP")
	await _play_until(func(): return Quests.is_complete(m5g) and _idle(), 30)
	Quests.turn_in(m5g, World.any_npc("Seiran"), null)
	await _play_until(_idle, 30)
	_check("5장", "세이란: 물이 흐려 (물점은 7장)", _saw("물이 흐려") and not G.story.clues.has("sky"))
	# 한여름 눈은 밀회(D 의 s1 둘째 대목)를 본 사흘째에 온다. 그 전에는 오지 않는다
	World.travel_to("VILLAGE")
	G.dayTime = 0.4
	G.day += 3
	await _wait(3.0)
	_check("5장", "밀회 전엔 눈이 안 온다", not G.story.events.has("ev_glacia"))
	G.quests.done.append("s1")   # 밀회를 봤다고 친다
	await _wait(1.0)
	_check("5장", "밀회를 본 날을 적는다", G.story.get("trystDay") == G.day)
	G.day += 2
	await _wait(2.0)
	_check("5장", "밀회 이틀째도 아직", not G.story.events.has("ev_glacia"))
	G.day += 1
	await _play_until(func(): return G.story.events.has("ev_glacia") and _idle(), 40)
	_check("5장", "한여름 눈: 카이론이 나선다 (제자 때문에)", _saw("이번에는 안 빠지오") and G.quests.active.has("m5a"))
	_check("5장", "t2 를 안 했으면 '돌려보냈던 아이'", _saw("내가 돌려보냈던 아이고") and not _saw("가르치기 시작한 아이"))
	_check("5장", "엘더가 카이론에게 스승의 말을 맡긴다", _saw("스승님 말씀을 그분께 전해 주게"))
	# 얼음 능선: 무너진 망루의 사절 둘
	World.travel_to("SNOW_RIDGE")
	await _play_until(func(): return G.story.events.has("ev_snow_ridge") and _idle(), 40)
	_check("5장", "망루: 유안이 티아맷을 덮었다", _saw("웨스턴 용을요"))
	_check("5장", "망루: '미라한테는… 다친 거 말하지 마라'", _saw("미라한테는"))
	_check("5장", "망루: 알 껍데기 조각 얘기는 없다", not _saw("알 껍데기 조각"))
	# 봉우리: 글라시아의 고백과 알 예순 개
	World.travel_to("GLACIA_LAIR")
	await _wait(0.5)
	var b = null
	for x in G.entities.bosses:
		if x.id == "GLACIA": b = x
	_check("5장", "봉우리에 글라시아가 있다", b != null)
	if b:
		G.player.hp = G.player.max_hp
		G.player.x = b.x; G.player.y = b.y + 300
		await _play_until(func(): return b.awake and _idle(), 20)
		var t := Time.get_ticks_msec()
		while not G.bossesDefeated.get("GLACIA", false) and Time.get_ticks_msec() - t < 20000:
			if _idle() and b.dying <= 0: b.take_damage(b.hp + 1)
			await get_tree().process_frame
			_advance()
		await _play_until(func(): return _saw("두 마을 쪽으로 똑같이") and _idle(), 90)
	_check("5장", "글라시아가 그이의 말을 받는다", _saw("미안한 건 나다"))
	_check("5장", "품는 법을 잊었다 (얼린 까닭)", _saw("품는 법을 잊었다"))
	_check("5장", "누이의 알 · 서로 탓 · 카이론", _saw("누이 거다") and _saw("스무 해 전에도 꼭 이렇게 시작했다"))
	# 도란과 미루의 알 소식은 눈이 그친 뒤에
	var ctx := Chronicle.context()
	ctx.map = "VILLAGE"; ctx.hour = 10.0
	var egg_when: Callable = _event("ev_couple_egg").when
	_check("5장", "m5a 전엔 도란·미루 알 소식 없음", not egg_when.call(ctx))
	# 마을: 포코 → 엘더
	World.travel_to("VILLAGE")
	await _wait(0.5)
	var poco = World.any_npc("Poco")
	G.player.x = poco.x - 120; G.player.y = poco.y
	await _play_until(func(): return Quests.is_complete(Quests.by_id("m5a")) and _idle(), 40)
	Quests.turn_in(Quests.by_id("m5a"), World.any_npc("Elder"), null)
	await _play_until(_idle, 40)
	_check("5장", "엘더↔카이론: 알을 끌어안고 잠드셨소", _saw("알을 끌어안고 잠드셨소"))
	ctx = Chronicle.context()
	ctx.map = "VILLAGE"; ctx.hour = 10.0
	_check("5장", "m5a 뒤엔 도란·미루 알 소식", egg_when.call(ctx))
	# 경계석의 유안: 봉우리에서 돌아온 뒤, 폭포의 대치 전까지만
	var torn: Callable = _event("ev_yuan_torn").when
	ctx.map = "FALLS"; ctx.night = false; ctx.gathering = false
	_check("5장", "경계석 유안: 돌아온 뒤엔 나온다", torn.call(ctx))
	G.story.events.append("ev_border")
	_check("5장", "경계석 유안: 폭포 대치 뒤엔 안 나온다", not torn.call(ctx))
	G.story.events.erase("ev_border")
	# 다시 식음: 수군거림이 돈다
	var ember = World.any_npc("Ember")
	_check("5장", "다시 식음: 엠버가 수군거림을 전한다", _greets(ember, Data.get_module("npcTalk").NPC_TALK.Ember, "속성 여럿 가진 애가"))


## 6장 본편은 H 몫. 여기서는 8장이 기대는 다짐과, 이름을 밝히는 자리가 앞의 선택을 읽는지만 본다
func _chapter6() -> void:
	var G := GameState
	var m6w = Quests.by_id("m6w")
	_check("6장", "장례: 카이론 '다시는 마을을 비우지 않겠소'", JSON.stringify(m6w.steps).contains("다시는 마을을 비우지 않겠소"))
	# 이름을 밝히는 장면: p1 을 끝냈고(later), m3 에서 물었다(press)
	G.quests.choices.m3 = "press"
	Chronicle.play_scene("전쟁", m6w.reward.scene)
	await _play_until(_idle, 30)
	_check("6장", "p1 을 읽는다 ('이제는 이르지 않구나')", _saw("이제는 이르지 않구나"))
	_check("6장", "m3=press 를 읽는다 (기다린 줄은 안 나옴)", _saw("이름만은 묻지 말아 달라고") and not _saw("묻지 않고 기다려 주었지"))
	_check("6장", "이그나르 = 엘더가 말한 예외", _saw("내가 말한 예외가 그 아이란다"))
	# 그론이 떠난 뒤 엠버의 줄 (S2 · S5)
	G.story.dead = ["Gron"]
	var ember = World.any_npc("Ember")
	_check("6장", "엠버 인사: 망치질 → 대장간이 덜 조용해", NpcActions._retold(ember, "야, 네가 오면 아저씨 망치질이 부드러워져. 진짜야. 자주 좀 와라.").contains("덜 조용해"))
	_check("6장", "엠버 이야기: '이제 그 소리 들을 일도 없네'", NpcActions._retold(ember, "나 언젠가 아저씨보다 잘 만들 거야. 비밀도 아니야, 맨날 대놓고 말하거든. 그럼 아저씨가 '백 년은 이르다' 그래.").contains("들을 일도 없네"))
	G.story.dead = []
	_check("6장", "밤손님: '여긴 하나도 안 변했군'", JSON.stringify(_event("ev_messenger").lines).contains("하나도 안 변했군"))


func _chapter7() -> void:
	var G := GameState
	for id in ["m6w"]:
		if not G.quests.done.has(id): G.quests.done.append(id)
	# 바윗골·불탄 도시는 모래 폭군이 비킨 뒤에
	_check("7장", "바실 전: 바윗골 막힘", not Chapters.map_open(G, "STONEBACK") and Chapters.blocked_text(G, "STONEBACK").contains("모래 폭군"))
	_check("7장", "바실 전: 불탄 도시 막힘", not Chapters.map_open(G, "ASH_CITY"))
	_check("7장", "사막은 열림", Chapters.map_open(G, "DESERT"))
	# m5b: 그론한테 창을 찾아오겠다고 했으면(g1 ask) 그 약속을 떠올린다
	G.quests.choices.g1 = "ask"
	var m5b = Quests.by_id("m5b")
	Quests.accept(m5b)
	G.bossesDefeated.BASIL = true
	Quests.complete_step(m5b)
	await _play_until(_idle, 40)
	_check("7장", "g1=ask: '찾아오겠다고 큰소리쳤던 창'", _saw("찾아오겠다고 큰소리쳤던 창") and not _saw("가져다줄 용은 이제 없는데"))
	Quests.turn_in(m5b, World.any_npc("Ember"), "wall")
	await _play_until(_idle, 30)
	_check("7장", "바실 뒤: 바윗골·불탄 도시 열림", Chapters.map_open(G, "STONEBACK") and Chapters.map_open(G, "ASH_CITY"))
	# m5c: 불탄 도시 → 카이론 → 리운 → (구름마루에서 이어서) 세이란의 물점 → 엘더의 사과
	var m5c = Quests.by_id("m5c")
	Quests.accept(m5c)
	for i in 3: Quests.complete_step(m5c)
	await _play_until(_idle, 60)
	_check("7장", "리운이 세이란의 약속을 잇는다", _saw("세이란이 그대를 기다리고 있소"))
	World.travel_to("CLOUDTOP")
	await _play_until(func(): return G.story.events.has("ev_seiran_water") and _idle(), 40)
	_check("7장", "물점: 빈 둥지와 알 껍데기 둘 · 단서 sky", _saw("알 껍데기가 하나, 아니 둘") and G.story.clues.has("sky"))
	_check("7장", "하루는 반말 (구름 위)", _saw("날아야 된대!") and not _saw("날아야 된대요"))
	_check("7장", "물점을 보면 보고만 남는다", Quests.is_complete(m5c))
	Quests.turn_in(m5c, World.any_npc("Elder"), null)
	await _play_until(_idle, 40)
	_check("7장", "엘더의 사과가 그날 밤의 다짐을 받는다 (p1)", _saw("이번에는 다르게 기르겠다고 했었지"))


func _chapter8() -> void:
	var G := GameState
	# 삼원룡은 없다: 고룡이 마지막 단계, 의식은 1·2단계뿐
	var stages: Array = Data.get_module("elements").STAGES
	_check("8장", "단계는 넷 (고룡이 마지막)", stages.size() == 4 and stages[-1].id == "ELDER")
	_check("8장", "의식은 1·2단계뿐", Data.get_module("ceremony").RITES.keys() == ["1", "2"])
	for id in ["r1", "e1", "w1"]:
		_check("8장", "%s 는 본편 (건네받은 속성)" % id, Quests.by_id(id).act == "main")
	# 하늘이 붉던 날: 카이론이 가지 않는 까닭은 장례의 다짐
	World.travel_to("VILLAGE")
	G.dayTime = 0.4
	await _play_until(func(): return G.story.events.has("ev_ignar") and _idle(), 40)
	_check("8장", "카이론: '이 마을을 비우지 않기로 했다'", _saw("이 마을을 비우지 않기로 했다") and not _saw("못 가오"))
	_check("8장", "m6 이 걸린다", G.quests.active.has("m6"))
	# 정상은 고룡의 날개로만
	_check("8장", "고룡 전: 정상 막힘", not Chapters.map_open(G, "IGNAR_LAIR") and Chapters.blocked_text(G, "IGNAR_LAIR").contains("바람"))
	# 잿마루: 흑단을 알아보고, 베스나가 꽃과 '받은 것'을 말한다
	if not G.story.has("flags"): G.story.flags = {}
	G.story.flags.messenger = true
	World.travel_to("VOLCANO")
	await _play_until(func(): return G.story.events.has("ev_heukdan") and _idle(), 40)
	_check("8장", "흑단: '그날 밤 말은 전했지'", _saw("그날 밤 말은 전했지"))
	var m6 = Quests.by_id("m6")
	if int(G.quests.active.m6.step) < 1: Quests.complete_step(m6)
	Quests.complete_step(m6)
	await _play_until(_idle, 40)
	_check("8장", "베스나: 불탄 도시의 꽃", _saw("해마다 한 번씩 남쪽 도시에"))
	_check("8장", "베스나: 받은 것으로도 되는지", _saw("받은 것으로도 되는지"))
	# 빈 둥지: 세 마을이 건넨 속성이 없으면 깨어나지 않는다
	World.travel_to("SKY_RUINS")
	await _wait(0.5)
	await _play_until(_idle, 20)
	var nest = null
	for x in G.entities.props:
		if x.type == "RUIN": nest = x
	var p = G.player
	p.stage_index = 2
	p.elements = ["FIRE", "ICE", "THUNDER"]
	if nest:
		p.x = nest.x; p.y = nest.y + 40
	_check("8장", "속성 셋(불·얼음·번개)만으로는 안 깨어난다", Story.try_awaken() and p.stage_index == 2)
	p.elements = ["FIRE", "ICE", "THUNDER", "GRASS", "EARTH", "WATER"]
	Story.try_awaken()
	await _play_until(func(): return p.stage_index == 3 and G.questScenes.is_empty() and _idle(), 40)
	_check("8장", "건네받은 셋을 품으면 고룡 (레벨 상관없이)", p.stage_index == 3 and _saw("건네받은 것들이 나를 여기까지 키웠다"))
	_check("8장", "빈 둥지에 카이론은 안 온다 (마을을 비우지 않는다)", not _saw("스승이다."))
	_check("8장", "고룡 뒤: 정상 열림", Chapters.map_open(G, "IGNAR_LAIR"))
	# 대면: 꿈속 목소리 · 무늬 · 지도를 흘린 것 (선택지 글은 test_ending 이 고르는 그대로)
	var meet := JSON.stringify(_event("ev_ignar_meet"))
	_check("8장", "대면: 꿈에서 말을 걸었다 · 무늬가 증거 · 지도", meet.contains("들리더냐") and meet.contains("무늬가 증거") and meet.contains("지도를 쥐여 준 것도 나다"))
	_check("8장", "대면: '제 숨결 없이' 대신 '불씨 하나만 쥐고'", not meet.contains("숨결") and meet.contains("불씨 하나만 쥐고"))
	var fall := JSON.stringify(_event("ev_ignar_fall"))
	_check("8장", "무릎: 카이론이 곁에 있다 · 선택지 글 유지", fall.contains("카이론, 너도 보고 있구나") and fall.contains("같이 가자") and fall.contains("끝낸다"))


## 장 밖: 생활 대사 · 사냥꾼 · 아이들
func _life() -> void:
	var G := GameState
	var talk: Dictionary = Data.get_module("npcTalk")
	# 어둠의 길 끝: 포코·나라·티아맷의 가장 가까운 이야기도 바뀐다 (S9 · S10)
	G.story.route = "dark"
	G.quests.done.append("m7d")
	_check("장 밖", "어둠 뒤 포코", NpcActions._retold(World.any_npc("Poco"), "나 사실 겁이 엄청 많아. 근데 너랑 같이 있으면 그게 좀 덜해져서 신기해.").contains("티아맷 뒤에서"))
	_check("장 밖", "어둠 뒤 나라", NpcActions._retold(World.any_npc("Nara"), "나는 네 뒤를 쫓아가는 것 말고, 언젠가 네 옆에 나란히 서 있고 싶어.").contains("지금 네가 서 있는 데는 싫어"))
	_check("장 밖", "어둠 뒤 티아맷", NpcActions._retold(World.any_npc("Tiamat"), "너랑 순찰 도는 날은 아무 일도 안 생겨. 심심하다고 말하려다가… 됐어, 그냥 좋다고 하자. 나도 그런 말 할 줄 알아.").contains("잿마루 용들이"))
	G.story.route = null
	G.quests.done.erase("m7d")
	# 이름을 밝히기 전의 엘더 이야기 줄에 이그나르 이름이 없다 (S1)
	_check("장 밖", "엘더 이야기 줄에 이그나르 이름 없음", not JSON.stringify(talk.NPC_TALK.Elder.topics).contains("이그나르"))
	# 티아맷 인연 장면 2는 망루 장면(t1)과 겹치지 않는다 (S11)
	_check("장 밖", "티아맷 인연 2: 망루 세기 대신 발자국", not JSON.stringify(talk.BOND_SCENES.Tiamat["2"]).contains("굴이 열둘"))
	# 아이 말투: 짝이 될 수 있는 용을 삼촌·할아버지로 부르지 않는다 (S12~15)
	var kid := JSON.stringify(talk.KID_TALK)
	_check("장 밖", "아이 말에 포코 삼촌·카이론 할아버지·엘더 할아버지 없음", not kid.contains("포코 삼촌") and not kid.contains("카이론 할아버지") and not kid.contains("엘더 할아버지"))
	# 아이 안부는 짝 본인이 묻지 않는다 (S17~19)
	var kids_when: Callable
	for s in talk.SITUATION_LINES:
		if str(s.lines.get("Elder", "")).contains("네 아이들은"): kids_when = s.when
	var elder = World.any_npc("Elder")
	var old_kids = G.kids
	var old_partner = G.partner
	G.kids = [{}]
	G.partner = elder
	_check("장 밖", "짝(엘더)은 제 아이 안부를 안 묻는다", not kids_when.call(G, elder) and kids_when.call(G, World.any_npc("Poco")))
	G.kids = old_kids
	G.partner = old_partner
	# 잿별: 결말 뒤에도 맞는 말 (S33) · 리운: 카이론을 묻는 까닭 (S34)
	_check("장 밖", "잿별: '산 위에 계셔' 없음", not JSON.stringify(talk.NPC_TALK.Jaetbyeol.topics).contains("산 위에 계셔"))
	_check("장 밖", "리운: 스무 해 전 우리 아이들도 배웠다", JSON.stringify(talk.NPC_TALK.Riun.topics).contains("우리 아이들도 그에게 배웠소"))
	# 사냥꾼이 나를 노리는 까닭 (0-3)
	var amb := JSON.stringify(_event("ev_ambush").lines)
	_check("장 밖", "베르단: 크기 전에 잡아 오라는 값 · 지도", amb.contains("크기 전에 잡아 오라고") and amb.contains("지도까지 돌더라"))
	_check("장 밖", "'두 번 붉어졌다'는 어디에도 없다", not JSON.stringify(talk).contains("두 번 붉") and not JSON.stringify(Data.get_module("quests")).contains("두 번 붉"))


# ---------- 도구 ----------

func _check(ch: String, what: String, ok: bool) -> void:
	if not ok: _fails += 1
	print("[%s] %s %s" % [ch, "OK  " if ok else "FAIL", what])


func _saw(needle: String) -> bool:
	return _seen.any(func(t): return t.contains(needle))


func _event(id: String) -> Dictionary:
	for ev in Data.get_module("chronicle").CHRONICLE:
		if ev.id == id: return ev
	return {}


func _scene(id: String) -> Dictionary:
	for sc in Data.get_module("story").SCENES:
		if sc.id == id: return sc
	return {}


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000:
		await get_tree().process_frame
		_advance()


## 인사는 그때그때 뽑으니 여러 번 뽑아 본다
func _greets(npc, talk: Dictionary, needle: String) -> bool:
	for i in 40:
		if NpcActions._greeting(npc, talk, 0).contains(needle): return true
	return false


func _idle() -> bool:
	return GameState.questScenes.is_empty() and not Chronicle._playing and not DialogueBox.is_open()


func _play_until(cond: Callable, sec: float) -> void:
	var t := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t < sec * 1000:
		await get_tree().process_frame
		_advance()


## 장면을 넘긴다. 뜬 글은 모아 두고, 고를 것이 있으면 첫 줄을 고른다
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
	_box._choose(0)
