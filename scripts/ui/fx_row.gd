class_name FxRow
extends VBoxContainer
## 화면 효과 판의 손잡이 한 줄: [이름 ─손잡이─ 값] 과 그 밑의 설명 한 줄.
## key 는 ScreenFx 의 이름. 값은 100 을 곱한 %로 보여 준다 (기본값이 몇 %인지 설명에 적어 둔다).

@export var key := ""
@export var label := ""
@export_multiline var note := ""
@export var min_value := 0.0
@export var max_value := 1.0

@onready var _slider: HSlider = $Line/Slider
@onready var _num: Label = $Line/Num


func _ready() -> void:
	$Line/Label.text = label
	$Note.text = note
	_slider.min_value = min_value
	_slider.max_value = max_value
	_slider.step = 0.01
	sync()
	_slider.value_changed.connect(func(v):
		ScreenFx.set_value(key, v)
		_num.text = "%d%%" % roundi(v * 100))


## 저장된 값으로 손잡이를 맞춘다 (기본값으로 되돌렸을 때)
func sync() -> void:
	_slider.set_value_no_signal(ScreenFx.value(key))
	_num.text = "%d%%" % roundi(_slider.value * 100)
