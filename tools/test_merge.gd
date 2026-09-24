extends Node
## 여러 세션을 합친 뒤 남은 것(docs/tasks/README.md 6절)을 고친 것을 확인한다.
## 옛 세이브의 대목 옮기기 · 도란의 수군거림 잡담 · 경계석 유안이 s1 에서 고른 것을 읽는 줄 · 골짜기 나들이
##   godot --headless --path . res://tools/test_merge.tscn

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

	# ---- 옛 세이브: 대목이 바뀐 퀘스트의 번호를 옮긴다 ----
	Save.save_game()
	_check("새 세이브에는 표시가 있다", Save.read().get("questLayout"), 2)
	for case in [
		{ what = "옛 m4 모르가스 대목(1) → 새 0", id = "m4", old = 1, want = 0 },
		{ what = "옛 m4 성체 대목(0) → 새 0", id = "m4", old = 0, want = 0 },
		{ what = "옛 m4 폭포 대목(3) → 새 2", id = "m4", old = 3, want = 2 },
		{ what = "옛 s1 미라 대목(0) → 새 2", id = "s1", old = 0, want = 2 },
	]:
		_check(case.what, _load_old(case.id, case.old, false), case.want)
	_check("새 세이브의 m4 1 은 그대로", _load_old("m4", 1, true), 1)

	# ---- 도란의 수군거림: 봉우리의 알 소식 뒤, 전쟁 전까지만 ----
	var rumor = null
	for c in Data.get_module("chatter").CHATTER:
		if c.get("id") == "doran_rumor": rumor = c
	_check("수군거림 잡담이 있다", rumor != null and rumor.pair == ["Doran", "Miru"], true)
	GameState.quests.done = []
	_check("수군거림 · 알 소식 전에는 없다", rumor.when.call(GameState), false)
	GameState.quests.done = ["m5a"]
	_check("수군거림 · 알 소식 뒤에 돈다", rumor.when.call(GameState), true)
	GameState.quests.done = ["m5a", "m6w"]
	_check("수군거림 · 전쟁 뒤에는 그친다", rumor.when.call(GameState), false)

	# ---- 경계석의 유안: s1 에서 고른 것을 읽는다 ----
	var torn = null
	for e in Data.get_module("chronicle").CHRONICLE:
		if e.id == "ev_yuan_torn": torn = e
	for pick in [null, "cover", "warn", "tell"]:
		GameState.quests.choices.erase("s1")
		if pick: GameState.quests.choices["s1"] = pick
		var shown: Array = torn.lines.filter(func(l): return Chronicle._chosen(l)).map(func(l): return l.get("chose", ""))
		var extra: Array = shown.filter(func(c): return c != "")
		_check("유안 · 고른 것 %s" % str(pick), extra, [] if pick == null else ["s1:%s" % pick])
	GameState.quests.choices.erase("s1")

	# ---- 골짜기 나들이: 모르가스는 엘더의 스승이다 ----
	var hollow = null
	for t in Data.get_module("training").TRIPS:
		if t.id == "hollow": hollow = t
	var all_text := " ".join(PackedStringArray((hollow.offer + hollow.done).map(func(l): return l.text)))
	_check("나들이 · '우리 스승님'이 없다", all_text.contains("우리 스승님"), false)
	_check("나들이 · 엘더 심부름", all_text.contains("영감 심부름"), true)

	print("[끝] 틀린 곳 %d" % _bad)
	get_tree().quit()


## 저장해 둔 세이브를 옛 세이브처럼 꾸며(questLayout 없음) 불러오고, 그 퀘스트의 대목 번호를 돌려준다
func _load_old(id: String, step: int, keep_layout: bool) -> int:
	var data: Dictionary = Save.read()
	if not keep_layout: data.erase("questLayout")
	data.quests.active = { id: { step = step, n = 0 } }
	data.bossesDefeated = {}
	data.visited = ["VILLAGE"]
	Save.apply(data)
	return int(GameState.quests.active.get(id, { step = -1 }).step)


func _check(what: String, got, want) -> void:
	var ok: bool = str(got) == str(want)
	if not ok: _bad += 1
	print("%s %s  (%s%s)" % ["OK  " if ok else "틀림", what, str(got), "" if ok else " · 기대 %s" % str(want)])
