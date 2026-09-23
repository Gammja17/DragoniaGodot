extends Node
## test_story 가 남긴 세이브를 불러 이어 하는지 본다.
##   godot --headless --path . res://tools/test_load.tscn

func _ready() -> void:
	Save.slot = 9   # 시험은 9번 칸을 쓴다 (사람이 쓰는 1~3번 칸을 건드리지 않게)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var p: Dragon = GameState.player
	print("[불러오기] 지도=%s 날짜=%d 자리=(%d,%d) 고기=%d 아이=%s 둥지 지음=%s 튜토리얼=%s 프롤로그=%s" % [
		GameState.map_id, GameState.day, p.x, p.y, p.inventory.meat, GameState.kids.map(func(k): return k.name),
		GameState.den.built, GameState.elderTutorialDone, GameState.prologue])
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 2000: await get_tree().process_frame
	print("[2초 뒤] 아이 개체=%d 대화=%s" % [GameState.entities.babies.size(), GameState.isDialogueOpen])
	get_tree().quit()
