class_name GamePanel
extends Control
## 판 공통 (설정 · 도움말 · 일지 · 가족 · 굴 꾸미기). 2D판 .panel
## 뒤의 세상을 어둡게 가리고, 금테 판을 가운데 띄운다. 머리에 제목과 [닫기], 그 밑에 금빛 줄 한 줄.
## 2D판처럼 판이 떠 있어도 세상은 돈다 (대화창과 다르다). 판 위의 클릭은 판이 먹어서 숨결이 나가지 않는다.

signal opened
signal closed

@export var title := "창":
	set(v):
		title = v
		if is_node_ready(): $Frame/Lines/Head/Title.text = v
## 판 크기. 화면이 작으면 화면의 95% · 88% 까지만 (2D판 min(1040px, 95vw) × min(760px, 88vh))
@export var panel_size := Vector2(1040, 760)
@export var close_label := "닫기"

## 떠 있는 판들 (Esc 는 맨 위의 것부터 닫는다)
static var _open := []

@onready var body: VBoxContainer = $Frame/Lines/Body
@onready var extra: HBoxContainer = $Frame/Lines/Head/Extra


func _ready() -> void:
	$Frame/Lines/Head/Title.text = title
	$Frame/Lines/Head/Close.text = close_label
	$Frame/Lines/Head/Close.pressed.connect(close)
	$Dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed: close())   # 바깥을 누르면 닫는다
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var screen := get_viewport_rect().size
	var s := Vector2(minf(panel_size.x, screen.x * 0.95), minf(panel_size.y, screen.y * 0.88))
	var f: Control = $Frame
	f.offset_left = -s.x / 2
	f.offset_right = s.x / 2
	f.offset_top = -s.y / 2
	f.offset_bottom = s.y / 2


func is_open() -> bool: return visible


func open() -> void:
	if visible: return
	visible = true
	_open.erase(self)
	_open.append(self)
	Sfx.play("ui")
	opened.emit()


func close() -> void:
	if not visible: return
	visible = false
	_open.erase(self)
	closed.emit()


func toggle() -> void:
	if visible: close()
	else: open()


## 떠 있는 판을 하나 닫는다. 닫은 게 있으면 true (Esc)
static func close_top() -> bool:
	_open = _open.filter(func(p): return is_instance_valid(p) and p.visible)
	if _open.is_empty(): return false
	_open[-1].close()
	return true


static func any_open() -> bool:
	_open = _open.filter(func(p): return is_instance_valid(p) and p.visible)
	return not _open.is_empty()
