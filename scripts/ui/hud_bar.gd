@tool
class_name HudBar
extends Panel
## 글자가 막대 안에 들어가는 막대 (체력·허기·경험). 2D판 .bar
## 채움 색은 위에서 아래로 번지는 두 색 (2D판 linear-gradient(180deg, 밝은색, 제 색))

@export var label := "체력":
	set(v):
		label = v
		if is_node_ready(): $Label.text = v
@export var top_color := Color("#ff6b5e"):
	set(v):
		top_color = v
		if is_node_ready(): _paint()
@export var bottom_color := Color("#e0453a"):
	set(v):
		bottom_color = v
		if is_node_ready(): _paint()

var _ratio := 1.0
var _shown := 1.0


func _ready() -> void:
	$Label.text = label
	_paint()


func _paint() -> void:
	var g := Gradient.new()
	g.colors = PackedColorArray([top_color, bottom_color])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 4
	t.height = 16
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	$Fill.texture = t


## ratio: 0~1, text: 오른쪽에 쓰는 수
func set_value(ratio: float, text: String) -> void:
	_ratio = clampf(ratio, 0, 1)
	$Num.text = text


func _process(dt: float) -> void:
	if Engine.is_editor_hint(): return
	# 2D판 transition: width 0.25s
	_shown = move_toward(_shown, _ratio, dt / 0.25)
	$Fill.size = Vector2((size.x - 2) * _shown, size.y - 2)
