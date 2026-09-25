extends Node
## HUD 판이 뜬 뒤에도 입력이 세상에 닿는지 본다 (그림으로는 알 수 없는 것).
##   클릭 → 숨결이 나가는가 · 추적창 클릭 → 자동 이동 · 판 위 클릭 → 숨결이 안 나가는가 · [U] 접기
##   godot --path . res://tools/test_hud.tscn   (창이 떠야 마우스 좌표가 맞는다)

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.play_intro = false
	main.load_save = false
	add_child(main)
	for i in 10: await get_tree().process_frame
	var hud: Hud = Hud.current
	var vp := get_viewport().get_visible_rect().size
	print("화면 ", vp)
	# 1) 세상 한가운데를 누른다
	var before := _ally_bullets()
	_click(vp / 2 + Vector2(120, 40), true)
	for i in 6: await get_tree().process_frame
	_click(vp / 2 + Vector2(120, 40), false)
	print("[세상 클릭] 숨결 %d → %d" % [before, _ally_bullets()])
	await _wait(1.0)
	# 2) 상태판 위를 누른다: 숨결이 나가면 안 된다
	var st := hud.status.get_global_rect()
	before = _ally_bullets()
	_click(st.get_center(), true)
	for i in 6: await get_tree().process_frame
	_click(st.get_center(), false)
	print("[판 위 클릭] 숨결 %d → %d (그대로여야 한다)" % [before, _ally_bullets()])
	# 3) 추적창을 누른다
	GameState.quests.active.m0 = { step = 4, n = 0 }   # 엘더에게 돌아가는 대목 (본 이야기)
	GameState.quests.tracked = "m0"
	Quests.changed()
	await _wait(0.5)
	var q := hud.right.quest.get_global_rect()
	print("[추적창] 보임=%s 글=%s" % [hud.right.quest.visible, hud.right.quest.get_node("Lines/Title").text])
	_click(q.get_center(), true)
	await get_tree().process_frame
	_click(q.get_center(), false)
	await _wait(0.3)
	print("[추적창 클릭] 자동 이동=%s" % (GameState.nav != null))
	# 4) [U]
	var ev := InputEventKey.new(); ev.physical_keycode = KEY_U; ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	ev = ev.duplicate(); ev.pressed = false
	Input.parse_input_event(ev)
	await get_tree().process_frame
	print("[U] 상태판=%s 오른쪽=%s" % [hud.status.visible, hud.right.visible])
	get_tree().quit()


func _ally_bullets() -> int:
	return GameState.entities.bullets.filter(func(b): return b.faction == "ALLY").size()


func _click(pos: Vector2, down: bool) -> void:
	var m := InputEventMouseMotion.new(); m.position = pos
	Input.parse_input_event(m)
	var e := InputEventMouseButton.new()
	e.position = pos; e.button_index = MOUSE_BUTTON_LEFT; e.pressed = down
	Input.parse_input_event(e)


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000: await get_tree().process_frame
