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
	var text: String = _box._text.text
	if _seen.is_empty() or _seen[-1] != text: _seen.append(text)
	_box._text.visible_characters = -1
	_box._choose(0)
