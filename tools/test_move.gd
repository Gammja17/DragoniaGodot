extends Node
## 걷기·대시·충돌이 도는지 본다. 메인 씬을 띄우고 동작을 눌러 가며 용의 위치를 찍는다.
##   godot --headless --path . tools/test_move.tscn


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.play_intro = false
	main.load_save = false
	add_child(main)
	await get_tree().process_frame
	var p: Dragon = GameState.player
	var t0 := Vector2(p.x, p.y)
	print("시작 ", t0, " ", p.facing)
	await _hold("right", 1.0)
	print("오른쪽 1초 ", Vector2(p.x, p.y), " 이동 ", p.x - t0.x, " (기대 ≈ 260×0.95 = 247) ", p.facing)
	var t1: float = p.x
	Input.action_press("right"); Input.action_press("sprint")
	await _wait(0.25)
	Input.action_release("sprint"); Input.action_release("right")
	print("대시 0.25초 ", p.x - t1, " (기대 ≈ 247×3.4×0.2 + 달리기) ")
	# 물가로 옮겨 놓고 물 쪽으로 걸어 본다 (LAKE 연못은 큰 칸 (8,10) 반지름 4)
	var maps: Dictionary = Data.get_module("maps").MAPS
	var spec: Dictionary = maps.LAKE.duplicate(); spec.id = "LAKE"
	Terrain.set_active_map(GameMap.build(spec))
	Collision.build_prop_grid([])   # 바닥만 본다 (마을 소품이 남아 있으면 엉뚱한 데서 막힌다)
	p.x = GameMap.coarse_center(8); p.y = GameMap.coarse_center(4)
	await _hold("down", 3.0)
	print("연못 쪽으로 3초: y=", p.y, " 발밑 ", Terrain.ground_at(p.x, p.y), " (물에 들어가면 안 된다)")
	get_tree().quit()


func _hold(action: String, sec: float) -> void:
	Input.action_press(action)
	await _wait(sec)
	Input.action_release(action)


func _wait(sec: float) -> void:
	var end := Time.get_ticks_msec() + sec * 1000
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame
