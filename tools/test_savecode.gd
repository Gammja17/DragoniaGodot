extends Node
## 저장 코드: 칸의 기록을 코드로 내보내고 다시 칸에 들인다 · 메신저가 끼워 넣은 줄바꿈 · 띄어쓰기 · 잘못된 코드 ·
## 게임 안 설정의 [저장 코드 → 복사하기] 창 · 붙여 넣고 불러오기.
## 줄마다 [저장 코드] OK/FAIL 을 찍고, 끝에 실패 수를 센다. 저장은 9번 칸만 쓴다.
##   godot --headless --path . res://tools/test_savecode.tscn

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
	G.day = 7
	G.player.level = 5
	Save.save_game()
	var raw := FileAccess.get_file_as_string(Save.path(9))
	var code := Save.export_code(9)
	_check("코드 머리", code.begins_with(Save.CODE_HEAD))
	_check("코드가 세이브보다 짧다 (%d → %d 글자)" % [raw.length(), code.length()], code.length() < raw.length())
	_check("코드를 풀면 기록 그대로", Save.decode_code(code) == raw)
	var wrapped := ""
	for i in range(0, code.length(), 70): wrapped += code.substr(i, 70) + "\n "
	_check("메신저가 줄을 바꾸고 띄어 써도 읽는다", Save.decode_code(wrapped) == raw)
	_check("잘못된 코드는 받지 않는다", [Save.decode_code("안녕"), Save.decode_code(Save.CODE_HEAD + "AAAA"), Save.decode_code(code.substr(0, code.length() - 40))], ["", "", ""])

	# 칸을 지우고 코드로 되살린다
	Save.delete(9)
	_check("지운 칸", Save.has_save(9), false)
	_check("코드로 들인다", Save.import_code(wrapped, 9))
	var back = Save.read(9)
	_check("되살린 기록: 날짜 · 레벨", [back.day, back.player.level], [7, 5])

	# 게임 안: 설정의 [저장 코드 → 복사하기] → 지금 판을 저장하고 그 칸의 코드 창
	var hud = Hud.current
	hud.settings.save_code_pressed.emit()
	await get_tree().process_frame
	var box: TextEdit = hud.save_code.get_node("Frame/Lines/Body/Code")
	_check("설정에서 저장 코드 창이 열린다", hud.save_code.visible)
	_check("창의 코드는 지금 칸의 코드", box.text == Save.export_code(9))
	hud.save_code.close()
	# 불러오기 창: 잘못된 코드는 까닭을 띄우고, 제대로 된 코드는 칸에 들인다
	Save.delete(9)
	hud.save_code.open_import(9)
	box.text = "망가진 코드"
	hud.save_code._import()
	_check("잘못된 코드면 창이 그대로 · 칸도 그대로", [hud.save_code.visible, Save.has_save(9)], [true, false])
	var got := [-1]
	hud.save_code.imported.connect(func(n): got[0] = n)
	box.text = wrapped
	hud.save_code._import()
	_check("붙여 넣은 코드를 불러온다", [got[0], Save.has_save(9), hud.save_code.visible], [9, true, false])

	# 처음 화면: 칸 줄마다 [저장 코드] (처음 화면 장면은 띄우지 않고 읽히는지만 본다)
	var title: PackedScene = load("res://scenes/title.tscn")
	_check("처음 화면 장면이 읽힌다 (저장 코드 창 포함)", title != null and title.can_instantiate())
	var row: SaveSlotRow = load("res://scenes/ui/save_slot_row.tscn").instantiate()
	add_child(row)
	var asked := [-1]
	row.code_pressed.connect(func(n): asked[0] = n)
	row.show_slot(9)
	row.get_node("Row/Main/Buttons/Code").pressed.emit()
	_check("칸 줄의 [저장 코드]", [row.get_node("Row/Main/Buttons/Code").visible, asked[0]], [true, 9])

	print("[끝] 실패 %d" % _fails)
	get_tree().quit(1 if _fails else 0)


func _check(what: String, got, want = true) -> void:
	var ok: bool = str(got) == str(want)
	if not ok: _fails += 1
	print("[저장 코드] %s %s%s" % ["OK  " if ok else "FAIL", what, "" if ok else "  (%s · 기대 %s)" % [str(got), str(want)]])
