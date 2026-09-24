extends Node
## 처음 화면 → 새 용(2번 칸) → 게임 → 저장하고 처음 화면으로 → 2번 칸 이어 하기 → 지우기.
## 이 노드는 루트에 따로 붙어 있어서, 씬이 바뀌어도 살아남아 지켜본다.
##   godot --headless --path . res://tools/test_title.tscn

const N := 2


func _ready() -> void:
	Save.delete(N)
	var title: Node = load("res://scenes/title.tscn").instantiate()
	get_tree().root.add_child.call_deferred(title)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = title
	var row: SaveSlotRow = title.get_node("Center/Column/Slots/Lines/Slot%d" % N)
	print("[처음 화면] %d번 칸: %s / 이어 하기 단추 %s" % [N, row.get_node("Row/Info/Title").text, row.get_node("Row/Play").visible])
	row.get_node("Row/New").pressed.emit()
	await get_tree().process_frame
	print("[새 용] 만들기 판 보임=%s, 외형 칸 %d개" % [title.get_node("Center/Column/Create").visible, title._cells.size()])
	title._select(title._cells[1])   # 와이번 프리셋 (색을 바꿀 수 있다)
	title.get_node("Center/Column/Create/Lines/Body/Left/Name").text = "시험용"
	title.get_node("Center/Column/Create/Lines/Body/Left/Accessory/Pick").select(6)
	title.get_node("Center/Column/Create/Lines/Buttons/Start").pressed.emit()
	await _wait(1.5)
	var p = GameState.player
	print("[게임] 이름=%s 종족=%s 장신구=%s 칸=%d 프롤로그=%s" % [p.config.name, p.species, p.config.get("accessory"), Save.slot, GameState.prologue != null])
	Prologue.skip()
	await _wait(1.0)
	Hud.skip_chapter_card()
	await _wait(0.5)
	Hud.current.to_title_requested.emit()
	await _wait(1.0)
	var t2 = get_tree().current_scene
	row = t2.get_node("Center/Column/Slots/Lines/Slot%d" % N)
	print("[다시 처음 화면] %d번 칸: %s · %s / 이어 하기 단추 %s" % [N, row.get_node("Row/Info/Title").text, row.get_node("Row/Info/Sub").text, row.get_node("Row/Play").visible])
	row.get_node("Row/Play").pressed.emit()
	await _wait(1.5)
	print("[이어 하기] 이름=%s 종족=%s 지도=%s 프롤로그=%s" % [GameState.player.config.name, GameState.player.species, GameState.map_id, GameState.prologue != null])
	Hud.current.to_title_requested.emit()
	await _wait(1.0)
	t2 = get_tree().current_scene
	row = t2.get_node("Center/Column/Slots/Lines/Slot%d" % N)
	row.get_node("Row/Delete").pressed.emit()
	await get_tree().process_frame
	print("[지우기 확인] ", t2.get_node("Center/Column/Confirm/Lines/Text").text.replace("\n", " "))
	t2.get_node("Center/Column/Confirm/Lines/Buttons/Yes").pressed.emit()
	await get_tree().process_frame
	print("[지운 뒤] %d번 칸: %s, 파일 %s" % [N, row.get_node("Row/Info/Title").text, Save.has_save(N)])
	get_tree().quit()


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000: await get_tree().process_frame
