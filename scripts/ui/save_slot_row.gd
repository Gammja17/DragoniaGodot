class_name SaveSlotRow
extends PanelContainer
## 처음 화면의 세이브 칸 한 줄. 차 있으면 [이어 하기](금빛) [새로 시작] [지우기], 비어 있으면 [새 용](금빛) 만.
## [저장 코드]는 늘 있다: 차 있으면 그 기록을 코드로 복사하고, 비어 있으면 다른 기기의 코드를 붙여 넣는다.
## 좁은 화면(휴대폰 세로)에서는 단추들을 정보 아래 줄로 내리고 작은 얼굴을 접는다 (set_narrow).

signal play_pressed(n: int)
signal new_pressed(n: int)
signal delete_pressed(n: int)
signal code_pressed(n: int)

var slot := 1

@onready var _info: VBoxContainer = $Row/Main/Info
@onready var _buttons: HBoxContainer = $Row/Main/Buttons


func _ready() -> void:
	_buttons.get_node("Play").pressed.connect(func(): play_pressed.emit(slot))
	_buttons.get_node("New").pressed.connect(func(): new_pressed.emit(slot))
	_buttons.get_node("Delete").pressed.connect(func(): delete_pressed.emit(slot))
	_buttons.get_node("Code").pressed.connect(func(): code_pressed.emit(slot))


## 좁은 화면: 단추를 아래 줄로 · 작은 얼굴은 접는다 (처음 화면이 폭을 보고 부른다)
func set_narrow(narrow: bool) -> void:
	$Row/Main.vertical = narrow
	$Row/Portrait.visible = not narrow
	for b in ["Play", "New"]: _buttons.get_node(b).custom_minimum_size.x = 0 if narrow else 96   # 넷이 한 줄에 들어가게


func show_slot(n: int) -> void:
	slot = n
	$Row/No.text = str(n)
	var s = Save.summary(n)
	var d = Save.read(n) if s else null
	_buttons.get_node("Play").visible = s != null
	_buttons.get_node("Delete").visible = s != null
	var new: Button = _buttons.get_node("New")
	new.text = "새로 시작" if s else "새 용"
	new.theme_type_variation = &"" if s else &"PrimaryButton"   # 빈 칸은 [새 용] 이 할 일
	var portrait: Control = $Row/Portrait
	portrait.sheet = null
	portrait.queue_redraw()   # 빈 칸도 자리를 비워 두어 줄이 가지런하다
	if s:
		var c: Dictionary = d.player.config
		portrait.sheet = DragonSprites.get_sheet(c.get("species", "LOOK"), c.get("colors", {}), int(c.get("look", 0)))
		portrait.queue_redraw()
		_info.get_node("Title").text = "%s · Lv.%d %s" % [s.name, s.level, s.stage]
		_info.get_node("Sub").text = "%s%s · %d일째" % ["%s · " % s.chapter if s.chapter else "", s.map, s.day]
		_info.get_node("When").text = "마지막 저장 %s" % s.saved.left(16).replace("T", " ")
		_info.get_node("When").visible = true
		_info.get_node("Title").add_theme_color_override("font_color", Color("#ece3cf"))
	else:
		_info.get_node("Title").text = "빈 칸"
		_info.get_node("Sub").text = "새 용을 만들어 시작한다"
		_info.get_node("When").visible = false
		_info.get_node("Title").add_theme_color_override("font_color", Color("#a39a87"))
