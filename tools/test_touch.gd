extends Node
## 터치 조작 (headless): 스틱으로 걷기 · [불] 은 붙잡은 적을 따라가는 숨결 · 용을 탭하면 말 걸기 · [일지] 칩
## 그리고 가족 창 · 굴 꾸미기 판.   godot --headless --path . res://tools/test_touch.tscn

func _ready() -> void:
	Save.slot = 9
	get_tree().root.size = Vector2i(1280, 720)   # headless 창은 64×64 라 화면 자리가 다 어긋난다
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.play_intro = false
	main.load_save = false
	add_child(main)
	for i in 5: await get_tree().process_frame
	GameInput.touch = true
	GameState.elderTutorialDone = true
	await _wait(0.3)
	var hud: Hud = Hud.current
	var t: TouchLayer = hud.touch
	var vp := get_viewport().get_visible_rect().size
	print("[터치 층] 보임=%s 단추 %d개 기술 칸 줄=%s 화면 %s" % [t.visible, t.buttons.values().filter(func(b): return b.on).size(), hud.bottom.get_node("Skills").visible, vp])
	# 1) 스틱: 왼쪽 아래를 짚고 오른쪽으로 민다
	var p = GameState.player
	var x0: float = p.x
	var at := Vector2(160, vp.y - 120)
	_touch(0, at, true)
	await get_tree().process_frame
	_drag(0, at + Vector2(80, 0))
	await _wait(0.8)
	print("[스틱] 축=%s 이동 %.0f px" % [GameInput.virtual_axis, p.x - x0])
	_touch(0, at + Vector2(80, 0), false)
	await get_tree().process_frame
	print("[스틱] 놓은 뒤 축=%s" % GameInput.virtual_axis)
	# 2) [불]: 곁의 슬라임을 붙잡아 따라가는 숨결
	var e := Enemy.make(p.x - 200, p.y + 150, "SLIME")
	World.add_entity("enemies", e)
	var hp0: float = e.hp
	var c: Vector2 = t.buttons.attack.c
	_touch(1, c, true)
	await _wait(0.4)
	_touch(1, c, false)
	var homing: Array = GameState.entities.bullets.filter(func(b): return b.faction == "ALLY" and b.homing > 0 and b.homing_target == e)
	print("   마우스 조준=%s 붙잡은 적=%s 슬라임 체력 %.0f → %.0f (숨결이 벌써 맞았으면 줄어 있다)" % [GameInput.mouse_inside, p.aim_lock == e, hp0, e.hp])
	print("[불] 숨결 %d발, 그중 슬라임을 따라가는 것 %d발" % [GameState.entities.bullets.filter(func(b): return b.faction == "ALLY").size(), homing.size()])
	e.remove = true
	# 2-1) 유도탄: 쏜 뒤 옆으로 비켜선 적도 따라가 맞히고, 과녁이 쓰러지면 곁의 다른 적으로 갈아탄다
	await _wait(0.6)
	GameState.entities.bullets.clear()
	p.aim_lock = null
	var dodger := Enemy.make(p.x + 260, p.y, "SLIME")
	World.add_entity("enemies", dodger)
	var d_hp: float = dodger.hp
	p.fire_timer = 0
	p.attack()
	dodger.x += 0; dodger.y -= 110   # 쏘자마자 옆으로 뛴다
	await _wait(0.8)
	print("[유도] 비켜선 슬라임 체력 %.0f → %.0f" % [d_hp, dodger.hp])
	dodger.remove = true
	GameState.entities.bullets.clear()
	var first := Enemy.make(p.x + 300, p.y, "SLIME")
	var second := Enemy.make(p.x + 360, p.y + 90, "SLIME")
	World.add_entity("enemies", first)
	World.add_entity("enemies", second)
	await get_tree().process_frame
	p.aim_lock = null
	p.fire_timer = 0
	p.attack()
	var shot: Array = GameState.entities.bullets.filter(func(b): return b.faction == "ALLY" and b.seek)
	first.remove = true   # 숨결이 닿기 전에 쓰러진다
	await get_tree().process_frame
	await get_tree().process_frame
	print("[유도] 과녁이 쓰러진 뒤 갈아탔다=%s" % shot.any(func(b): return b.homing_target == second))
	second.remove = true
	# 3) 용을 탭하면 말 걸기
	var gron = World.any_npc("Gron")
	p.x = gron.x - 70; p.y = gron.y + 10
	await _wait(0.3)
	var cam := GameCamera.current
	var sp := Vector2((gron.x - cam.cam_x) * cam.zoom.x, (gron.y - 50 - cam.cam_y) * cam.zoom.x)
	GameInput.tap_at(sp)
	await get_tree().process_frame
	await get_tree().process_frame
	print("[탭] 대화=%s 이름=%s" % [DialogueBox.is_open(), DialogueBox.current._name.text if DialogueBox.is_open() else "-"])
	Dialogue.close()
	await get_tree().process_frame
	# 4) [일지] 칩
	await get_tree().process_frame
	var cc: Vector2 = t.buttons.journal.c
	_touch(2, cc, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_touch(2, cc, false)
	await get_tree().process_frame
	print("[일지 단추] 일지 보임=%s, 그동안 터치 층 보임=%s" % [hud.journal.visible, t.visible])
	hud.journal.close()
	# 5) 가족 창
	hud.kids.toggle()
	await get_tree().process_frame
	print("[가족] 보임=%s 글=%s" % [hud.kids.visible, hud.kids.get_node("Frame/Lines/Body/Meta").text])
	hud.kids.close()
	# 6) 굴 꾸미기 판
	World.travel_to("DEN_MINE")
	await _wait(0.5)
	DenPanel.show_panel()
	await get_tree().process_frame
	var list: VBoxContainer = hud.get_node("Den/Frame/Lines/Body/Scroll/List")
	print("[굴 꾸미기] 보임=%s [가진 것] %d줄 · %s" % [DenPanel.panel_open(), list.get_child_count(), hud.get_node("Den/Frame/Lines/Body/Meta/Cozy").text])
	hud.get_node("Den/Frame/Lines/Body/Tabs/craft").pressed.emit()
	await get_tree().process_frame
	print("[굴 꾸미기] [맡긴다] %d줄" % list.get_child_count())
	get_tree().quit()


func _touch(i: int, pos: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = i; ev.position = pos; ev.pressed = down
	Input.parse_input_event(ev)


func _drag(i: int, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = i; ev.position = pos
	Input.parse_input_event(ev)


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000: await get_tree().process_frame
