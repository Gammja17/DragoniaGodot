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
	# 키가 없고 터치 버튼·게임패드만 누르는 동작 (TouchLayer)
	"attack": [],
	"nextElement": [],
	"prevElement": [],
}

## 게임패드 (Xbox 배치 기준. 다른 패드도 같은 자리에 들어온다).
##   왼쪽 스틱 이동 · 오른쪽 스틱 조준(밀면 쏜다) · RT 숨결 · LB 대시/달리기
##   A 말 걸기·결정 · B 닫기 · X 눈앞의 것 · Y 기술 R · RB 기술 Q · LT 기술 F · R3 필살기 · L3 날기
##   십자키 ←→ 숨결 바꾸기 · ↑ 곁의 용에게 말 걸기 · ↓ 고기 먹기 · Back 일지 · Start 설정
const PADMAP := {
	"confirm": [JOY_BUTTON_A],
	"cancel": [JOY_BUTTON_B, JOY_BUTTON_START],
	"interact": [JOY_BUTTON_X],
	"skillR": [JOY_BUTTON_Y],
	"skillQ": [JOY_BUTTON_RIGHT_SHOULDER],
	"sprint": [JOY_BUTTON_LEFT_SHOULDER],
	"ultimate": [JOY_BUTTON_RIGHT_STICK],
	"fly": [JOY_BUTTON_LEFT_STICK],
	"nextElement": [JOY_BUTTON_DPAD_RIGHT],
	"prevElement": [JOY_BUTTON_DPAD_LEFT],
	"talk": [JOY_BUTTON_DPAD_UP],
	"eat": [JOY_BUTTON_DPAD_DOWN],
	"journal": [JOY_BUTTON_BACK],
}
## 스틱·방아쇠 → 동작 [축, 방향]. 이동 네 방향은 왼쪽 스틱 (대화창 고르기도 이것으로)
const PADAXIS := {
	"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0],
	"up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0],
	"attack": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
	"skillF": [JOY_AXIS_TRIGGER_LEFT, 1.0],
}
const STICK_DEADZONE := 0.3
const AIM_DEADZONE := 0.35

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
## 게임패드로 하는 중인가 (패드를 건드리면 켜지고, 마우스를 움직이면 꺼진다). 조준이 오른쪽 스틱을 따른다
var pad := false


func _ready() -> void:
	for action in KEYMAP:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in KEYMAP[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action in PADMAP:
		for b in PADMAP[action]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = b
			InputMap.action_add_event(action, ev)
	for action in PADAXIS:
		var ev := InputEventJoypadMotion.new()
		ev.axis = PADAXIS[action][0]
		ev.axis_value = PADAXIS[action][1]
		InputMap.action_add_event(action, ev)
		InputMap.action_set_deadzone(action, STICK_DEADZONE)
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
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5): pad = true
	elif event is InputEventMouseMotion and not _emulated(event) and event.relative.length() > 2: pad = false
	if _emulated(event): return
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_down = false
	if event is InputEventMouseMotion: mouse_pos = event.position


## 손가락이 흉내 낸 마우스 (Godot 는 첫 손가락을 마우스로도 보낸다). 진짜 마우스로 치면 조준이 커서 쪽으로 넘어간다
func _emulated(event: InputEvent) -> bool:
	return event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION


func _unhandled_input(event: InputEvent) -> void:
	# 판에 먹히지 않은 손가락 탭은 그 자리를 탭한 것 (용에게 말 걸기). 연사는 [숨결] 단추로만
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


## 터치로 겨누는가: 숨결이 붙잡은 적을 따라가는 유도탄이 된다.
## 휴대폰에서는 늘 (모바일 웹은 손가락이 흉내 낸 마우스가 '진짜 마우스'로 들어와 mouse_inside 가 켜지던 것),
## PC 에서는 터치 화면을 쓰고 마우스를 안 쓰는 동안만
func touch_aim() -> bool:
	return touch and not pad and (UiScale.is_mobile() or not mouse_inside)


## 이동 벡터 (-1..1, -1..1). 키보드·게임패드 왼쪽 스틱이 우선이고, 안 누르고 있으면 터치 스틱
func axis() -> Vector2:
	var dx := (1 if down("right") else 0) - (1 if down("left") else 0)
	var dy := (1 if down("down") else 0) - (1 if down("up") else 0)
	if dx == 0 and dy == 0:
		return virtual_axis
	# 스틱을 살짝만 밀면 그 기울기대로 (키보드는 늘 끝까지 민 셈)
	var v := Input.get_vector("left", "right", "up", "down", STICK_DEADZONE)
	return v if v.length() > 0.05 else Vector2(dx, dy)


## 게임패드 오른쪽 스틱 (조준). 데드존 안이면 0
func aim_stick() -> Vector2:
	var v := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	return v if v.length() > AIM_DEADZONE else Vector2.ZERO


# ---------- 안내 글을 기기에 맞추기 ----------
## 안내 글(알림 · 퀘스트 힌트 · 대사 · 머리 위 안내)은 키보드·마우스 기준으로 쓰여 있다.
## 게임패드나 터치로 하고 있으면 그 기기의 이름으로 바꿔 보여 준다. 조준하는 말은 통째로, 키 이름은 [ ] 안의 것을
const AIM_WORDS := {
	pad = [["마우스로 겨누고 클릭하면", "오른쪽 스틱으로 겨누면"], ["마우스로 겨누고 클릭해서", "오른쪽 스틱으로 겨눠서"],
		["마우스로 겨누고 클릭", "오른쪽 스틱으로 겨누기"], ["꾹 누르면 계속", "밀고 있으면 계속"], ["[WASD]로", "왼쪽 스틱으로"], ["[WASD]", "왼쪽 스틱"]],
	touch = [["마우스로 겨누고 클릭하면", "[숨결]을 누르면"], ["마우스로 겨누고 클릭해서", "[숨결]을 눌러서"],
		["마우스로 겨누고 클릭", "[숨결] 단추로 쏘기"], ["[Shift]로 대시", "[대시]로 피하기"], ["[Shift] 대시로", "[대시]로"], ["[Z]로", "[비행]으로"],
		["[WASD]로", "왼쪽 아래 스틱으로"], ["[WASD]", "왼쪽 아래 스틱"]],
}
## 키 → 그 기기에서 같은 일을 하는 단추 (PADMAP · 터치 단추 이름). 없는 것은 그대로 둔다.
## 글에는 키 이름에 맞춘 조사(로·를)가 붙어 있어서, 받침 없이 끝나는 이름을 고른다 (받침이 있는 [비행]은 위에서 통째로)
const KEY_WORDS := {
	pad = { Space = "A", Shift = "LB", Esc = "B", E = "X", T = "십자 ↑", C = "십자 ↓", J = "Back", K = "Back", B = "Back", G = "Back",
		Z = "L3", X = "R3", Q = "RB", F = "LT", R = "Y" },
	touch = { Space = "말", Shift = "대시", E = "말", C = "먹기", J = "일지", K = "일지", B = "일지", G = "일지", Z = "비행" },
}
var _key_re := RegEx.create_from_string("\\[([A-Za-z]+)\\]")
var _lead_re := RegEx.create_from_string("^((?:Space|E)(?: · (?:Space|E))*) ")   # 머리 위 안내 "Space 대화" · "E · Space 줍는다"


func words(text: String) -> String:
	var dev := "pad" if pad else "touch" if touch and not mouse_inside else ""
	if dev == "" or text == "": return text
	for w in AIM_WORDS[dev]: text = text.replace(w[0], w[1])
	var keys: Dictionary = KEY_WORDS[dev]
	var out := ""
	var at := 0
	for m in _key_re.search_all(text):
		out += text.substr(at, m.get_start() - at)
		out += "[%s]" % keys[m.get_string(1)] if keys.has(m.get_string(1)) else m.get_string()
		at = m.get_end()
	text = out + text.substr(at)
	var lead := _lead_re.search(text)
	if lead:
		var names := []
		for k in lead.get_string(1).split(" · "):
			var n := "[%s]" % keys.get(k, k)
			if not names.has(n): names.append(n)
		text = " · ".join(names) + text.substr(lead.get_end() - 1)
	return text
