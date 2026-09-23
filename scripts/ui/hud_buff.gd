extends Label
## 걸려 있는 효과 한 칸. 좋은 것은 금빛, 나쁜 것은 붉게 (2D판 .buff / .buff.bad)

@export var good_style: StyleBox
@export var bad_style: StyleBox


func setup(t: String, bad: bool) -> void:
	text = t
	add_theme_stylebox_override("normal", bad_style if bad else good_style)
	add_theme_color_override("font_color", Color("#ff8a7a") if bad else Color("#ffe9a0"))
