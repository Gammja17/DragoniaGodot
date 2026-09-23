class_name FxToggle
extends VBoxContainer
## 화면 효과 판의 켜고 끄는 줄: [이름 ─ 켜짐/꺼짐] 과 그 밑의 설명 한 줄. key 는 ScreenFx 의 이름.

@export var key := ""
@export var label := ""
@export_multiline var note := ""

@onready var _button: Button = $Line/Button


func _ready() -> void:
	$Line/Label.text = label
	$Note.text = note
	sync()
	_button.pressed.connect(func():
		ScreenFx.set_value(key, not ScreenFx.value(key))
		Sfx.play("ui")
		sync())


func sync() -> void:
	var on: bool = ScreenFx.value(key)
	_button.text = "켜짐" if on else "꺼짐"
	_button.modulate = Color.WHITE if on else Color(1, 1, 1, 0.55)
