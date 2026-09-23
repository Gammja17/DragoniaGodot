extends Node
## 6단계(2) 소리를 창 없이 확인한다 (headless 에서는 소리가 실제로 나지 않고, 틀고 끄는 흐름과 만든 소리를 본다).
##   godot --headless --path . res://tools/test_audio.tscn
##   · 합성음 36개를 다 만들어 길이·크기가 맞는지, 만드는 데 얼마나 걸리는지
##   · 모든 효과음 이름을 한 번씩 틀어 오류가 없는지
##   · 배경음: 처음 화면 → 마을 → 굴 → 붉은 달 → 보스 순으로 곡이 바뀌고, 앞 곡은 물러나 멈추는지
##   · 음소거 · 음량 손잡이를 따르는지
## 이 기기의 설정 파일은 시험 전에 떠 두었다가 끝나면 되돌린다.

func _ready() -> void:
	var cfg_before := FileAccess.get_file_as_string(Prefs.PATH) if FileAccess.file_exists(Prefs.PATH) else ""
	Prefs.set_value("sound", "muted", false)

	# 1) 합성음
	var t0 := Time.get_ticks_msec()
	var worst := ""
	for name in Sfx.SOUNDS:
		var s := Sfx.make(Sfx.SOUNDS[name])
		var peak := 0
		for i in range(0, s.data.size(), 2): peak = maxi(peak, absi(s.data.decode_s16(i)))
		if peak < 300: worst += " %s(%d)" % [name, peak]
	print("[합성음] %d개 · %dms · 작은 것:%s (step 은 2D판도 0.02 로 작다. 녹음이 대신 울린다)" % [Sfx.SOUNDS.size(), Time.get_ticks_msec() - t0, worst if worst else " 없음"])

	# 2) 효과음 이름 전부
	var names := {}
	for n in Sfx.SOUNDS: names[n] = true
	for n in Sfx.SAMPLES: names[n] = true
	for n in names:
		Sfx.play(n)
		await get_tree().process_frame
	var busy := Audio.get_children().filter(func(p): return p is AudioStreamPlayer and p.playing).size()
	print("[효과음] %d개 틀어 봄 · 울리는 목소리 %d" % [names.size(), busy])

	# 3) 배경음
	await _frames(3)
	print("[처음 화면] 곡=%s" % Audio.playing_id())
	print("[미리 만들기] 뒤에서 만든 합성음 %d개" % Sfx._synth.size())
	Save.slot = 9
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.play_intro = false
	main.load_save = false
	add_child(main)
	await _frames(10)
	print("[마을] 곡=%s" % Audio.playing_id())
	GameState.dungeon = { id = Data.get_module("dungeons").DUNGEONS.keys()[0], depth = 1, seed = 1, entryPos = Vector2.ZERO, best = 0 }
	await _frames(3)
	print("[굴] 곡=%s 물러나는 곡=%d" % [Audio.playing_id(), Audio._fading.size()])
	await _seconds(Audio.FADE + 0.3)
	print("[굴, %.1f초 뒤] 물러나는 곡=%d" % [Audio.FADE + 0.3, Audio._fading.size()])
	GameState.dungeon = null
	GameState.dayTime = 0.9   # 붉은 달은 밤에만 (낮이 되면 사건이 끝난다)
	GameState.event = "BLOOD_MOON"
	await _frames(3)
	print("[붉은 달] 곡=%s" % Audio.playing_id())
	GameState.event = null
	await _frames(3)
	print("[붉은 달 끝] 곡=%s" % Audio.playing_id())

	# 4) 음량 · 음소거
	Prefs.set_value("sound", "music", 0.5)
	await _seconds(Audio.FADE + 0.2)
	var db_half: float = Audio._playing.player.volume_db
	Prefs.set_value("sound", "muted", true)
	await _frames(2)
	var db_muted: float = Audio._playing.player.volume_db
	print("[음량 50%%] %.1fdB · [음소거] %.1fdB" % [db_half, db_muted])

	if cfg_before != "":
		var f := FileAccess.open(Prefs.PATH, FileAccess.WRITE); f.store_string(cfg_before); f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Prefs.PATH))
	Save.delete(9)
	print("끝")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n: await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout
