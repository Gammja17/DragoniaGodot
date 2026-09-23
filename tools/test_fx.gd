extends Node
## 6단계(1) 조명 · 날씨 · 후처리 · 화면 효과 판을 창 없이 확인한다.
##   godot --headless --path . res://tools/test_fx.tscn
## 이 기기의 설정 파일(user://settings.cfg)은 시험 전에 떠 두었다가 끝나면 되돌린다.

func _ready() -> void:
	var cfg_before := FileAccess.get_file_as_string(Prefs.PATH) if FileAccess.file_exists(Prefs.PATH) else ""
	get_tree().root.size = Vector2i(1280, 720)
	Save.slot = 9
	ScreenFx.reset()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.play_intro = false
	main.load_save = false
	add_child(main)
	for i in 10: await get_tree().process_frame
	var lighting: Lighting = main.get_node("LightLayer/Lighting")
	var hud: Hud = Hud.current

	# 0) [L]
	print("[L 전] 대화=%s" % GameState.isDialogueOpen)
	_key(KEY_L, true); await _frames(1); _key(KEY_L, false); await _frames(1)
	print("[L] 판 열림=%s" % hud.fx.visible)
	hud.fx.close()

	# 1) 낮 · 밤 · 굴 속의 어둠
	for t in [0.5, 0.27, 0.0]:
		GameState.dayTime = t
		await _frames(2)
		print("[하루 %.2f] 어둠=%.2f 광원=%d" % [t, lighting.darkness(), lighting._lights.size()])
	GameState.weather.intensity = 1.0
	await _frames(2)
	print("[밤 + 폭우] 어둠=%.2f" % lighting.darkness())
	GameState.weather.intensity = 0.0
	GameState.event = "BLOOD_MOON"
	await _frames(2)
	print("[붉은 달] 주변광=%s" % lighting._ambient)
	GameState.event = null
	var has_player := lighting._lights.any(func(l): return l.r == 300)
	print("[광원] 내 용의 빛=%s" % has_player)

	# 2) 화면 효과 판: 손잡이가 값을 바꾸고, 되돌리기
	hud.fx.open()
	await _frames(1)
	var frame: Control = hud.fx.get_node("Frame")
	print("[판 자리] x=%d~%d (오른쪽에 붙어야 한다)" % [frame.get_global_rect().position.x, frame.get_global_rect().end.x])
	var night_row: FxRow = hud.fx.get_node("Frame/Lines/Body/Scroll/Rows/night")
	night_row.get_node("Line/Slider").value = 0.0
	await _frames(2)
	print("[밤의 어둠 0%%] 어둠=%.2f 저장=%s" % [lighting.darkness(), Prefs.get_value("fx", "night")])
	var post_row: FxToggle = hud.fx.get_node("Frame/Lines/Body/Scroll/Rows/post")
	post_row.get_node("Line/Button").pressed.emit()
	await _frames(2)
	print("[후처리 끄기] 셰이더 층 보임=%s 단추=%s" % [main.get_node("PostLayer/PostFx").visible, post_row.get_node("Line/Button").text])
	hud.fx.get_node("Frame/Lines/Body/Reset").pressed.emit()
	await _frames(2)
	print("[되돌리기] 밤=%s 후처리=%s 손잡이=%s" % [ScreenFx.value("night"), ScreenFx.value("post"), night_row.get_node("Line/Num").text])

	# 3) 판이 열린 채로 세상을 누르면 그 클릭이 세상에 닿는다 (판은 화면을 막지 않는다)
	hud.fx.open()
	var vp := Vector2(1280, 720)
	_click(vp / 2 + Vector2(-200, 40), true)
	await get_tree().process_frame
	var reached := GameInput.mouse_down
	for i in 6: await get_tree().process_frame
	_click(vp / 2 + Vector2(-200, 40), false)
	print("[판 연 채 세상 클릭] 판=%s 클릭이 세상에 닿음=%s" % [hud.fx.visible, reached])

	# 4) 설정 창의 [화면 효과]
	hud.fx.close()
	hud.settings.open()
	hud.settings.get_node("Frame/Lines/Body/Scroll/Rows/Fx/Button").pressed.emit()
	await _frames(1)
	print("[설정 → 화면 효과] 설정=%s 화면 효과=%s" % [hud.settings.visible, hud.fx.visible])
	hud.fx.close()

	# 5) 날씨 그림: 비일 때 · 굴 속일 때
	var wv: WeatherView = main.get_node("WeatherLayer/Weather")
	GameState.weather.type = "STORM"; GameState.weather.intensity = 1.0; GameState.weather.flash = 1.0
	await _frames(2)
	print("[폭풍] 숨김=%s 종류=%s" % [wv._hidden(), wv._falling_kind()])
	GameState.indoors = true
	await _frames(2)
	print("[굴 속] 숨김=%s 어둠=%.2f" % [wv._hidden(), lighting.darkness()])
	GameState.indoors = false

	if cfg_before != "":
		var f := FileAccess.open(Prefs.PATH, FileAccess.WRITE); f.store_string(cfg_before); f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Prefs.PATH))
	Save.delete(9)
	print("끝")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n: await get_tree().process_frame


func _key(k: Key, down: bool) -> void:
	var ev := InputEventKey.new(); ev.physical_keycode = k; ev.pressed = down
	Input.parse_input_event(ev)


func _click(pos: Vector2, down: bool) -> void:
	var m := InputEventMouseMotion.new(); m.position = pos
	Input.parse_input_event(m)
	var e := InputEventMouseButton.new()
	e.position = pos; e.button_index = MOUSE_BUTTON_LEFT; e.pressed = down
	Input.parse_input_event(e)
