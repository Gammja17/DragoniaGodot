class_name FxPanel
extends GamePanel
## 화면 효과 판 [L]. 조명 · 날씨 · 후처리를 손잡이로 고친다. 설정 창의 [화면 효과] 로도 연다.
## 효과가 잘 보이게 화면을 어둡게 가리지 않고 오른쪽에 붙는다. 판을 연 채로 걸어 다니고 싸우며 바로 확인할 수 있다.
## 값은 이 기기에 남는다 (ScreenFx → user://settings.cfg [fx]). 줄마다의 모양은 fx_row.tscn · fx_toggle.tscn.

const MARGIN := 16.0

@onready var _rows: VBoxContainer = $Frame/Lines/Body/Scroll/Rows


func _ready() -> void:
	super()
	$Frame/Lines/Body/Reset.pressed.connect(func():
		ScreenFx.reset()
		Sfx.play("ui")
		_sync()
		Hud.pop("화면 효과를 처음 값으로 되돌렸다.", "🎨"))
	opened.connect(_sync)


## 오른쪽에 붙인다 (GamePanel 은 가운데)
func _layout() -> void:
	var screen := get_viewport_rect().size
	var s := Vector2(minf(panel_size.x, screen.x * 0.95), minf(panel_size.y, screen.y - MARGIN * 2))
	var f: Control = $Frame
	f.offset_right = screen.x / 2 - MARGIN
	f.offset_left = f.offset_right - s.x
	f.offset_top = -s.y / 2
	f.offset_bottom = s.y / 2


func _sync() -> void:
	for r in _rows.get_children():
		if r.has_method("sync"): r.sync()
