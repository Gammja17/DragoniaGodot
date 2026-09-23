class_name SaveSlotRow
extends PanelContainer
## 처음 화면의 세이브 칸 한 줄. 차 있으면 [이어 하기](금빛) [새로 시작] [지우기], 비어 있으면 [새 용](금빛) 만.

signal play_pressed(n: int)
signal new_pressed(n: int)
signal delete_pressed(n: int)

var slot := 1


func _ready() -> void:
	$Row/Play.pressed.connect(func(): play_pressed.emit(slot))
	$Row/New.pressed.connect(func(): new_pressed.emit(slot))
	$Row/Delete.pressed.connect(func(): delete_pressed.emit(slot))


func show_slot(n: int) -> void:
	slot = n
	$Row/No.text = str(n)
	var s = Save.summary(n)
	var d = Save.read(n) if s else null
	$Row/Play.visible = s != null
	$Row/Delete.visible = s != null
	$Row/New.text = "새로 시작" if s else "새 용"
	$Row/New.theme_type_variation = &"" if s else &"PrimaryButton"   # 빈 칸은 [새 용] 이 할 일
	var portrait: Control = $Row/Portrait
	portrait.sheet = null
	portrait.queue_redraw()   # 빈 칸도 자리를 비워 두어 줄이 가지런하다
	if s:
		var c: Dictionary = d.player.config
		portrait.sheet = DragonSprites.get_sheet(c.get("species", "LOOK"), c.get("colors", {}), int(c.get("look", 0)))
		portrait.queue_redraw()
		$Row/Info/Title.text = "%s · Lv.%d %s" % [s.name, s.level, s.stage]
		$Row/Info/Sub.text = "%s%s · %d일째" % ["%s · " % s.chapter if s.chapter else "", s.map, s.day]
		$Row/Info/When.text = "마지막 저장 %s" % s.saved.left(16).replace("T", " ")
		$Row/Info/When.visible = true
		$Row/Info/Title.add_theme_color_override("font_color", Color("#ece3cf"))
	else:
		$Row/Info/Title.text = "빈 칸"
		$Row/Info/Sub.text = "새 용을 만들어 시작한다"
		$Row/Info/When.visible = false
		$Row/Info/Title.add_theme_color_override("font_color", Color("#a39a87"))
