class_name SkillSlot
extends Control
## 기술 칸 하나 (숨결 1~6 · Q F R · X). 2D판 .slot
## 고른 칸은 테두리와 바탕이 제 색으로 물들며 4px 떠오르고, 대기 중이면 아래에서부터 검게 덮인다.

const IDLE_BORDER := Color("#6a5a38")
const LOCKED_BORDER := Color("#2e2819")
const LOCKED_TEXT := Color("#5f584a")
const BG := Color(0.055, 0.051, 0.086, 0.95)
const H := 58.0

@onready var _box: Panel = $Box
@onready var _key: Label = $Box/Key
@onready var _name: Label = $Box/Name
@onready var _rank: Label = $Box/Rank
@onready var _cd: ColorRect = $Box/Cd

var _style: StyleBoxFlat
var _lift := 0.0


func _ready() -> void:
	_style = _box.get_theme_stylebox("panel").duplicate()
	_box.add_theme_stylebox_override("panel", _style)


## accent: 골랐을 때의 테두리 색 · text_accent: 그때의 글자 색
func show_state(key: String, label: String, locked: bool, active: bool, cd_ratio: float, accent: Color, text_accent: Color, rank := "") -> void:
	_key.text = key
	_name.text = label
	_rank.text = rank
	# 잠긴 칸은 글자만 잿빛으로 가라앉힌다. 칸 바탕까지 투명하게 하면 뒤의 땅 글씨(포탈 이름 등)가 비쳐 어지럽다
	_style.border_color = accent if active else LOCKED_BORDER if locked else IDLE_BORDER
	_style.bg_color = BG.lerp(accent, 0.16) if active else BG
	_key.add_theme_color_override("font_color", text_accent if active else LOCKED_TEXT if locked else Color("#ece3cf"))
	_name.add_theme_color_override("font_color", text_accent if active else LOCKED_TEXT if locked else Color("#cdc4af"))
	_set_cd(cd_ratio)
	_lift = 4.0 if active else 0.0


## 필살기 칸: 테두리가 보랏빛, 차 있으면 들썩인다 (2D판 ult-pulse)
func show_ult(ready: bool, fill: float) -> void:
	_key.text = "X"
	_name.text = "융합 브레스"
	_rank.text = ""
	_style.border_color = Color("#e0b0ff") if ready else Color("#8a5fbf")
	_set_cd(1 - fill)
	_lift = 2.0 + 2.0 * sin(Time.get_ticks_msec() / 1000.0 * PI / 0.9) if ready else 0.0


func _set_cd(r: float) -> void:
	var h := H * clampf(r, 0, 1)
	_cd.position = Vector2(0, H - h)
	_cd.size = Vector2(62, h)


func _process(_dt: float) -> void:
	# 2D판 transform: translateY(-4px) (0.12초)
	_box.position.y = lerpf(_box.position.y, 4.0 - _lift, 0.5)
