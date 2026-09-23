class_name TouchLayer
extends Control
## 2D판 ui/touch.js. 모바일(터치) 조작: 왼쪽 아래 가상 스틱 + 오른쪽 아래 단추 무리. 터치 기기에서만 나타난다.
## 단추는 키보드와 같은 동작 이름(GameInput)을 누른 것처럼 처리한다.
##
## 지금 쓸 수 있는 단추만 보인다:
##   · 기술 Q·F·R 은 그 칸에 기술을 끼운 뒤에, 필살기 X 는 융합이 열린 뒤에
##   · [속성] 은 숨결이 둘 이상일 때, [비행] 은 성체부터, [먹기] 는 고기가 있을 때, [가족] 은 짝이나 아이가 생긴 뒤에
## 단추 자리는 px 가 아니라 한 단위 u(짧은 변의 11%, 38~60px)로 잡는다. 폰 세로 화면에서도 스틱과 겹치지 않게.
##
## 여러 손가락을 한꺼번에 받아야 해서(스틱을 밀며 [불]을 누른다) 단추를 GUI 단추로 만들지 않고
## 화면 터치를 직접 받아 자리를 잰다. 스틱 자리를 툭 친 것은 그 자리를 탭한 것으로 넘긴다 (용에게 말 걸기).

signal settings_pressed

# [동작, 오른쪽에서(u), 아래에서(u), 크기(u)]
const BUTTONS := [
	["attack", 0.25, 0.45, 1.5],
	["sprint", 1.9, 0.25, 1.0],
	["confirm", 3.05, 0.25, 1.0],   # 말 걸기 · 상자 · 줍기 · 둥지 (Space 와 같다)
	["skillQ", 0.45, 2.15, 0.85],
	["skillF", 1.5, 1.55, 0.85],
	["skillR", 2.6, 1.45, 0.85],
	["ultimate", 1.75, 2.55, 0.8],
]
const TAP_TIME := 250   # ms. 이보다 짧게 밀지 않고 떼면 탭

@export var btn_style: StyleBox
@export var btn_big_style: StyleBox
@export var btn_down_style: StyleBox
@export var chip_style: StyleBox
@export var chip_down_style: StyleBox

@onready var _stick: Panel = $Stick
@onready var _knob: Panel = $Stick/Knob

var u := 48.0
var _touches := {}      # 손가락 번호 → { kind: 'stick' | 'btn' | 'chip' | 'gear', action, at, origin, moved }
var _refresh_t := 0.0


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var screen := get_viewport_rect().size
	u = clampf(minf(screen.x, screen.y) * 0.11, 38, 60)
	for b in BUTTONS:
		var n: Panel = $Buttons.get_node(b[0])
		var s: float = b[3] * u
		n.size = Vector2(s, s)
		n.position = Vector2(screen.x - 10 - b[1] * u - s, screen.y - 10 - b[2] * u - s)
		n.add_theme_stylebox_override("panel", btn_big_style if b[3] >= 1.4 else btn_style)
		n.get_node("Label").add_theme_font_size_override("font_size", 24 if b[3] >= 1.4 else 12)
	_stick.size = Vector2.ONE * 3.4 * u
	_knob.size = Vector2.ONE * 1.4 * u
	_rest()


## 손을 떼면 스틱은 제자리(왼쪽 아래)로 돌아가 어디를 짚을지 알려 준다
func _rest() -> void:
	var screen := get_viewport_rect().size
	_stick.position = Vector2(16, screen.y - 18 - _stick.size.y)
	_stick.modulate.a = 0.5
	_knob.position = (_stick.size - _knob.size) / 2
	GameInput.virtual_axis = Vector2.ZERO


## 지금 받을 수 있는가. 대화창·판·컷씬이 떠 있으면 그쪽이 손가락을 받는다
func _active() -> bool:
	return visible and not GameState.isDialogueOpen and not GamePanel.any_open()


func _process(dt: float) -> void:
	var on: bool = GameInput.touch and GameState.gameActive and GameState.player != null and not Cutscene.on
	var free := on and not GameState.isDialogueOpen and not GamePanel.any_open()
	visible = on
	$Buttons.visible = free
	$Top.visible = free
	_stick.visible = free
	if not free and not _touches.is_empty(): _release_all()
	_refresh_t -= dt
	if _refresh_t <= 0 and free:
		_refresh_t = 0.1
		_refresh()


# ---------- 손가락 ----------

func _input(event: InputEvent) -> void:
	if not _active(): return
	if event is InputEventScreenTouch:
		if event.pressed: _press(event)
		else: _release(event)
	elif event is InputEventScreenDrag and _touches.has(event.index):
		var t: Dictionary = _touches[event.index]
		if t.kind == "stick": _move_stick(t, event.position)
		get_viewport().set_input_as_handled()


func _press(ev: InputEventScreenTouch) -> void:
	var p := ev.position
	var screen := get_viewport_rect().size
	for b in BUTTONS:
		var n: Panel = $Buttons.get_node(b[0])
		if n.visible and p.distance_to(n.position + n.size / 2) <= n.size.x / 2 + 4:
			_touches[ev.index] = { kind = "btn", action = b[0] }
			GameInput.set_virtual(b[0], true)
			n.add_theme_stylebox_override("panel", btn_down_style)
			get_viewport().set_input_as_handled()
			return
	for c in $Top.get_children():
		if c.visible and c.get_global_rect().has_point(p):
			_touches[ev.index] = { kind = "chip", action = String(c.name) }
			GameInput.set_virtual(c.name, true)
			c.add_theme_stylebox_override("normal", chip_down_style)
			get_viewport().set_input_as_handled()
			return
	if $Gear.get_global_rect().has_point(p):
		_touches[ev.index] = { kind = "gear" }
		$Gear.add_theme_stylebox_override("normal", chip_down_style)
		get_viewport().set_input_as_handled()
		return
	# 왼쪽 아래 어디를 짚든 그 자리에 스틱이 선다 (고정된 원을 눈으로 찾아 엄지를 얹는 건 늘 한 박자 늦었다)
	if p.x < screen.x * 0.46 and p.y > screen.y * 0.42 and not _touches.values().any(func(t): return t.kind == "stick"):
		var t := { kind = "stick", at = Time.get_ticks_msec(), origin = p, moved = false }
		_touches[ev.index] = t
		_stick.position = p - _stick.size / 2
		_stick.modulate.a = 1.0
		_move_stick(t, p)
		get_viewport().set_input_as_handled()


func _release(ev: InputEventScreenTouch) -> void:
	if not _touches.has(ev.index): return
	var t: Dictionary = _touches[ev.index]
	_touches.erase(ev.index)
	match t.kind:
		"btn":
			GameInput.set_virtual(t.action, false)
			$Buttons.get_node(t.action).add_theme_stylebox_override("panel", btn_big_style if t.action == "attack" else btn_style)
		"chip":
			GameInput.set_virtual(t.action, false)
			$Top.get_node(t.action).add_theme_stylebox_override("normal", chip_style)
		"gear":
			$Gear.add_theme_stylebox_override("normal", chip_style)
			settings_pressed.emit()
		"stick":
			_rest()
			# 밀지 않고 툭 친 거라면 스틱이 아니라 '그 자리를 탭' (용에게 말 걸기가 살아 있어야 한다)
			if not t.moved and Time.get_ticks_msec() - t.at < TAP_TIME: GameInput.tap_at(ev.position)
	get_viewport().set_input_as_handled()


func _release_all() -> void:
	for i in _touches.keys():
		var ev := InputEventScreenTouch.new()
		ev.index = i
		ev.pressed = false
		ev.position = Vector2(-999, -999)
		_release(ev)


func _move_stick(t: Dictionary, p: Vector2) -> void:
	var R := _stick.size.x * 0.38
	var d: Vector2 = p - t.origin
	var len := d.length()
	if len > 10: t.moved = true
	if len == 0:
		_knob.position = (_stick.size - _knob.size) / 2
		return
	var k := minf(1, len / R)
	var v := d / len * k
	_knob.position = (_stick.size - _knob.size) / 2 + v * R
	GameInput.virtual_axis = Vector2(v.x if absf(v.x) > 0.2 else 0.0, v.y if absf(v.y) > 0.2 else 0.0)


# ---------- 지금 쓸 수 있는 단추만 ----------

func _refresh() -> void:
	var p = GameState.player
	var defs := Skills.defs()
	for slot in ["Q", "F", "R"]:
		var n: Panel = $Buttons.get_node("skill" + slot)
		var id = p.slots.get(slot)
		n.visible = id != null
		if id:
			n.get_node("Label").text = "%s\n%s" % [slot, defs[id].name]
			n.modulate.a = 0.45 if p.cooldowns.get(id, 0.0) > 0 else 1.0
	var ult: Panel = $Buttons/ultimate
	ult.visible = p.elements.size() >= 3
	ult.self_modulate = Color("#e0b0ff") if p.ult >= 100 else Color.WHITE
	var top := $Top
	top.get_node("nextElement").visible = p.elements.size() >= 2
	if p.elements.size() >= 2: top.get_node("nextElement").text = "속성: %s" % Data.get_module("elements").ELEMENTS[p.element].name
	top.get_node("eat").visible = p.inventory.meat > 0
	top.get_node("fly").visible = p.stage_index >= 2
	top.get_node("kids").visible = GameState.partner != null or not GameState.kids.is_empty()
