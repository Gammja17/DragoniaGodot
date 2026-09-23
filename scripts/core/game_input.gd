extends Node
## 2D판 core/input.js. 키 배치를 그대로 옮기고, 게임 코드는 동작 이름으로만 묻는다.
## physical_keycode 기준이라 한글 입력 상태에서도 WASD 가 먹는다.

const KEYMAP := {
	"up": [KEY_W, KEY_UP],
	"down": [KEY_S, KEY_DOWN],
	"left": [KEY_A, KEY_LEFT],
	"right": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT],
	"confirm": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER],   # 말 걸기 · 대화창 넘기기 (공격은 마우스 왼쪽 버튼)
	"interact": [KEY_E],
	"eat": [KEY_C],            # 고기 먹기. 상호작용과 섞이면 상자를 열려다 고기를 먹는다
	"talk": [KEY_T],
	"journal": [KEY_J],        # 일지 (퀘스트)
	"worldmap": [KEY_M],       # 지도
	"skillbook": [KEY_K, KEY_B],
	"inventory": [KEY_I],
	"growthTab": [KEY_G],
	"kids": [KEY_P],
	"mute": [KEY_O],
	"hideUi": [KEY_U],
	"fly": [KEY_Z],            # 날아오르기·내려앉기 (성체부터)
	"skillQ": [KEY_Q], "skillF": [KEY_F], "skillR": [KEY_R],
	"ultimate": [KEY_X],
	"help": [KEY_H],
	"screenFx": [KEY_L],       # 화면 효과 판
	"num1": [KEY_1], "num2": [KEY_2], "num3": [KEY_3], "num4": [KEY_4], "num5": [KEY_5],
	"num6": [KEY_6], "num7": [KEY_7], "num8": [KEY_8], "num9": [KEY_9],
	"zoom": [KEY_V],
	"debug": [KEY_F3],         # 밸런스 오버레이
	"cancel": [KEY_ESCAPE],
	# 키가 없고 터치 버튼만 누르는 동작 (TouchLayer)
	"attack": [],
	"nextElement": [],
}

## 터치 스틱이 주는 이동 벡터 (ui/touch 가 넣는다)
var virtual_axis := Vector2.ZERO
## 터치 버튼이 누르고 있는 동작
var _virtual := {}
## 휠: 위로 굴리면 +1 (당겨 보기)
var wheel := 0
## 마우스: 화면 좌표, 창 안에 있는가(진짜 마우스를 쓰는 중인가), 왼쪽 버튼을 누르고 있는가(브레스 연사),
## 이번 프레임에 눌렀는가, 이번 프레임에 오른쪽 버튼을 눌렀는가
var mouse_pos := Vector2.ZERO
var mouse_inside := false
var mouse_down := false
var mouse_clicked := false
var mouse_right := false
## 터치로 하는 중인가 (터치 화면이 있거나, 한 번이라도 화면을 짚었으면). 터치 조작 층이 뜨고, 숨결이 겨눈 적을 따라간다
var touch := false


func _ready() -> void:
	for action in KEYMAP:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in KEYMAP[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	touch = DisplayServer.is_touchscreen_available()
	# 휠은 프레임 끝에 비운다. 다른 노드들이 다 읽은 뒤여야 하니 가장 늦게 돈다
	process_priority = 1000


func _process(_dt: float) -> void:
	wheel = 0
	mouse_clicked = false
	mouse_right = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT: mouse_inside = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		mouse_down = false


## 버튼을 놓는 것은 판 위에서 놓아도 받는다 (세상에서 누르고 판 위에서 떼면 연사가 멈추지 않던 것)
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch: touch = true
	if _emulated(event): return
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_down = false
	if event is InputEventMouseMotion: mouse_pos = event.position


## 손가락이 흉내 낸 마우스 (Godot 는 첫 손가락을 마우스로도 보낸다). 진짜 마우스로 치면 조준이 커서 쪽으로 넘어간다
func _emulated(event: InputEvent) -> bool:
	return event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION


func _unhandled_input(event: InputEvent) -> void:
	# 판에 먹히지 않은 손가락 탭은 그 자리를 탭한 것 (용에게 말 걸기). 연사는 [불] 단추로만
	if _emulated(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: tap_at(event.position)
		return
	if event is InputEventMouseMotion:
		mouse_pos = event.position; mouse_inside = true
	elif event is InputEventMouseButton:
		mouse_pos = event.position; mouse_inside = true
		if event.button_index == MOUSE_BUTTON_LEFT:
			mouse_down = event.pressed
			if event.pressed: mouse_clicked = true
		elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT: mouse_right = true
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP: wheel += 1
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: wheel -= 1


func down(action: String) -> bool:
	return Input.is_action_pressed(action) or _virtual.get(action, false)


func pressed(action: String) -> bool:
	return Input.is_action_just_pressed(action)


func set_virtual(action: String, is_down: bool) -> void:
	_virtual[action] = is_down
	# 키를 누른 것과 똑같이 (pressed() 가 이번 프레임에 눌렀는지를 알 수 있게)
	if InputMap.has_action(action):
		if is_down: Input.action_press(action)
		else: Input.action_release(action)


## 터치 조작 층이 삼킨 짧은 탭을 화면 탭으로 넘긴다 (스틱 자리를 툭 친 것 · 판 밖을 짚은 것)
func tap_at(pos: Vector2) -> void:
	mouse_pos = pos
	mouse_clicked = true
	mouse_inside = false


## 이동 벡터 (-1..1, -1..1). 키보드가 우선이고, 안 누르고 있으면 터치 스틱
func axis() -> Vector2:
	var dx := (1 if down("right") else 0) - (1 if down("left") else 0)
	var dy := (1 if down("down") else 0) - (1 if down("up") else 0)
	if dx == 0 and dy == 0:
		return virtual_axis
	return Vector2(dx, dy)
