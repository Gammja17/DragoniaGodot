extends Node
## 사람이 있는 일: 게시판 쪽지를 쓴 용이 고마워한다 · 값은 자란 만큼 · 결말 뒤의 새 쪽지 · 살림살이를 마을 용에게 맡기면 다음 날 아침 굴 앞에.
## 줄마다 [사람] OK/FAIL 을 찍고, 끝에 실패 수를 센다. 저장은 9번 칸만 쓴다.
##   godot --headless --path . res://tools/test_people.tscn

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
	for ev in Data.get_module("chronicle").CHRONICLE: G.story.events.append(ev.id)
	var p = G.player

	# 쪽지의 값은 자란 만큼: 슬라임 쪽지(35G, 레벨 1부터)를 레벨 6에 들어주면 55G
	var slime = Chores._by_id("c_slime")
	p.level = 6
	_check("쪽지 값 · 레벨 6이면 35G → 55G", Chores._reward(slime).gold, 55)
	# 들어주면 쪽지를 쓴 포코가 고마워한다
	var poco = World.any_npc("Poco")
	var before: float = poco.relation
	var gold0: int = p.gold
	Chores.refresh_board()
	G.chores.taken.c_slime = 6
	Chores._pay_out(slime)
	Chores._close()
	_check("쪽지를 쓴 포코와 가까워진다 (+3)", roundi(poco.relation - before), 3)
	_check("값은 55G", p.gold - gold0, 55)
	_check("포코의 고맙다는 말", _popped("빨래는 내가 할게"))

	# 결말 뒤에는 습격 쪽지 대신 새 쪽지가 붙는다
	var deep = Chores._by_id("c_deep5")
	_check("결말 전: 굴 다섯 층 쪽지는 없다", Chores._open(deep), false)
	G.story.endingSeen = "guardian"
	_check("결말 뒤: 굴 다섯 층 쪽지", Chores._open(deep), true)
	_check("결말 뒤: 습격 교대 쪽지는 없다", Chores._open(Chores._by_id("c_raid")), false)
	G.story.endingSeen = ""

	# 살림살이는 마을 용에게 맡긴다: 값을 치르면 다음 날 아침 굴 앞에
	var dan = World.any_npc("Dan")
	var dan0: float = dan.relation
	p.gold = 500
	var had := Den.owned("STOOL")
	_check("나무 걸상은 단에게 맡긴다", Den.maker_of("STOOL"), "Dan")
	Den.craft("STOOL")
	_check("맡긴 날에는 아직 없다", [Den.owned("STOOL"), G.story.get("orders", []).size()], [had, 1])
	_check("단과 조금 가까워진다", roundi(dan.relation - dan0), 2)
	Den.deliver_orders()
	_check("같은 날에는 오지 않는다", Den.owned("STOOL"), had)
	G.day += 1
	G.dayTime = 0.3
	Den.deliver_orders()
	_check("다음 날 아침 굴 앞에 놓여 있다", [Den.owned("STOOL"), G.story.orders.size()], [had + 1, 0])
	_check("마른 풀은 내 손으로 엮는다 (맡길 용이 없다)", Den.maker_of("STRAW"), null)
	G.story.dead = ["Gron"]
	_check("그론이 떠난 뒤로 모루는 엠버에게", Den.maker_of("ANVIL"), "Ember")

	print("[끝] 실패 %d" % _fails)
	get_tree().quit(1 if _fails else 0)


func _popped(bit: String) -> bool:
	for t in Hud.current._toasts.get_children():
		if t.get_node("Label").text.contains(bit): return true
	for t in Hud.current._toast_wait:
		if str(t).contains(bit): return true
	return false


func _check(what: String, got, want = true) -> void:
	var ok: bool = str(got) == str(want)
	if not ok: _fails += 1
	print("[사람] %s %s%s" % ["OK  " if ok else "FAIL", what, "" if ok else "  (%s · 기대 %s)" % [str(got), str(want)]])
