class_name TouchLayer
extends Control
## 2D판 ui/touch.js. 모바일(터치) 조작. 터치 기기에서만 나타난다.
## 단추는 키보드와 같은 동작 이름(GameInput)을 누른 것처럼 처리한다.
##
## 자리 (모바일 액션 게임 배치 — 포켓몬 유나이트 · 슬램덩크 모바일):
##   · 왼쪽: 짚는 자리에 서는 스틱
##   · 오른쪽 아래: 큰 [숨결] 단추를 기술 Q·F·R 이 부채꼴로 두르고, 그 바깥에 필살기 · [대시] · [말] · [속성]
##   · 작은 단추(일지 · 먹기 · 비행 · 가족 · 설정): 가로 화면은 위쪽 가운데 한 줄, 세로 화면은 오른쪽 가장자리 한 줄
## 기술 단추는 쿨타임이 부채꼴로 걷히며 남은 초를 쓰고, 필살기는 테두리가 게이지만큼 찬다.
## 숨결이 붙잡은 적(유도탄의 과녁)에는 조준 표시가 붙는다.
##
## 지금 쓸 수 있는 단추만 보인다:
##   · 기술 Q·F·R 은 그 칸에 기술을 끼운 뒤에, 필살기는 융합이 열린 뒤에
##   · [속성] 은 숨결이 둘 이상일 때, [비행] 은 성체부터, [먹기] 는 고기가 있을 때, [가족] 은 짝이나 아이가 생긴 뒤에
## 단추 자리는 px 가 아니라 한 단위 u(짧은 변의 11.5%, 40~58px)로 잡는다.
##
## 여러 손가락을 한꺼번에 받아야 해서(스틱을 밀며 [숨결]을 누른다) GUI 단추를 쓰지 않고
## 화면 터치를 직접 받아 자리를 잰다. 스틱 자리를 툭 친 것은 그 자리를 탭한 것으로 넘긴다 (용에게 말 걸기).

signal settings_pressed

const TAP_TIME := 250   # ms. 이보다 짧게 밀지 않고 떼면 탭
const ICONS := { journal = "📜", eat = "🍖", fly = "🪽", kids = "💞", gear = "⚙" }
const NAMES := { journal = "일지", eat = "먹기", fly = "비행", kids = "가족", gear = "설정" }
const GOLD := Color(0.847, 0.698, 0.353)
const INK := Color(0.055, 0.051, 0.086)

var u := 48.0
var portrait := false
## 단추: 동작 → { c: 가운데, r: 반지름, kind: main|skill|ult|round|util, on: 보이는가 }
var buttons := {}
var _touches := {}      # 손가락 번호 → { kind: 'stick' | 'btn', action, at, origin, moved }
var _stick_c := Vector2.ZERO      # 스틱 가운데
var _stick_r := 70.0
var _knob := Vector2.ZERO         # 가운데에서 손잡이까지
var _stick_live := false
var _refresh_t := 0.0
var _ready_flash := {}  # 기술 → 쿨타임이 막 끝나 번쩍이는 남은 시간
var _was_cd := {}
var _font: Font


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_font = Fonts.bold()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var screen := get_viewport_rect().size
	portrait = screen.y > screen.x
	u = clampf(minf(screen.x, screen.y) * 0.115, 40, 58)
	buttons.clear()
	# 큰 [숨결]: 오른쪽 아래 구석. 세로 화면은 아래 가장자리(제스처 막대)에서 조금 더 띄운다
	var R := 0.98 * u
	var main_c := Vector2(screen.x - 0.3 * u - R, screen.y - (0.75 if portrait else 0.3) * u - R)
	_add("attack", main_c, R, "main")
	# 기술 셋은 [숨결]을 부채꼴로 두른다 (왼쪽 → 왼쪽 위 → 위). 엄지를 굴리면 닿는 자리
	var rs := 0.56 * u
	var ring := R + 0.22 * u + rs
	for i in 3:
		_add(["skillQ", "skillF", "skillR"][i], main_c + Vector2.from_angle(deg_to_rad([186.0, 229.0, 272.0][i])) * ring, rs, "skill")
	# 바깥 고리: 필살기 · [속성] 은 위쪽, [말] · [대시] 는 왼쪽
	var outer := ring + 1.3 * u
	_add("ultimate", main_c + Vector2.from_angle(deg_to_rad(248)) * outer, 0.6 * u, "ult")
	_add("nextElement", main_c + Vector2.from_angle(deg_to_rad(284)) * (outer - 0.1 * u), 0.44 * u, "round")
	_add("confirm", main_c + Vector2.from_angle(deg_to_rad(207)) * outer, 0.5 * u, "round")
	_add("sprint", main_c + Vector2.from_angle(deg_to_rad(168)) * outer, 0.56 * u, "round")
	# 작은 단추
	var ur := 0.4 * u
	var utils := ["journal", "eat", "fly", "kids", "gear"]
	for i in utils.size():
		var c: Vector2
		if portrait:
			# 오른쪽 가장자리, 필살기 위에서부터 위로
			c = Vector2(screen.x - 0.25 * u - ur, main_c.y - outer - 1.35 * u - i * 1.18 * u)
		else:
			c = Vector2(screen.x / 2 + (i - (utils.size() - 1) / 2.0) * 1.2 * u, 0.2 * u + ur)
		_add(utils[i], c, ur, "util")
	_stick_r = 1.55 * u
	_rest()
	queue_redraw()


func _add(action: String, c: Vector2, r: float, kind: String) -> void:
	buttons[action] = { c = c.round(), r = r, kind = kind, on = kind != "skill" and kind != "ult" }


## 손을 떼면 스틱은 제자리(왼쪽 아래)로 돌아가 어디를 짚을지 알려 준다
func _rest() -> void:
	var screen := get_viewport_rect().size
	_stick_c = Vector2(0.4 * u + _stick_r, screen.y - (0.9 if portrait else 0.45) * u - _stick_r)
	_knob = Vector2.ZERO
	_stick_live = false
	GameInput.virtual_axis = Vector2.ZERO


## 스틱을 세울 수 있는 자리: 왼쪽 아래 넓게 (단추 무리와 겹치지 않게)
func _stick_zone(p: Vector2) -> bool:
	var screen := get_viewport_rect().size
	if portrait: return p.x < screen.x * 0.55 and p.y > screen.y * 0.45
	return p.x < screen.x * 0.48 and p.y > screen.y * 0.35


## 지금 받을 수 있는가. 대화창·판·컷씬이 떠 있으면 그쪽이 손가락을 받는다
func _active() -> bool:
	return visible and not GameState.isDialogueOpen and not GamePanel.any_open()


func _process(dt: float) -> void:
	var on: bool = GameInput.touch and GameState.gameActive and GameState.player != null and not Cutscene.on
	var free := on and not GameState.isDialogueOpen and not GamePanel.any_open()
	visible = free
	if not free and not _touches.is_empty(): _release_all()
	if not free: return
	for k in _ready_flash.keys(): _ready_flash[k] = maxf(0, _ready_flash[k] - dt)
	_refresh_t -= dt
	if _refresh_t <= 0:
		_refresh_t = 0.1
		_refresh()
	queue_redraw()


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


## 이 자리에 있는 단추 (가장자리를 조금 넉넉하게 쳐 준다)
func button_at(p: Vector2):
	var best = null
	var best_d := INF
	for a in buttons:
		var b: Dictionary = buttons[a]
		if not b.on: continue
		var d: float = p.distance_to(b.c)
		if d <= b.r + 0.14 * u and d - b.r < best_d:
			best = a
			best_d = d - b.r
	return best


func _press(ev: InputEventScreenTouch) -> void:
	var p := ev.position
	var a = button_at(p)
	if a != null:
		_touches[ev.index] = { kind = "btn", action = a }
		if a != "gear": GameInput.set_virtual(a, true)
		get_viewport().set_input_as_handled()
		return
	# 왼쪽 아래 어디를 짚든 그 자리에 스틱이 선다 (고정된 원을 눈으로 찾아 엄지를 얹는 건 늘 한 박자 늦었다)
	if _stick_zone(p) and not _touches.values().any(func(t): return t.kind == "stick"):
		var t := { kind = "stick", at = Time.get_ticks_msec(), origin = p, moved = false }
		_touches[ev.index] = t
		_stick_c = p
		_stick_live = true
		_move_stick(t, p)
		get_viewport().set_input_as_handled()


func _release(ev: InputEventScreenTouch) -> void:
	if not _touches.has(ev.index): return
	var t: Dictionary = _touches[ev.index]
	_touches.erase(ev.index)
	match t.kind:
		"btn":
			if t.action == "gear": settings_pressed.emit()
			else: GameInput.set_virtual(t.action, false)
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
	var R := _stick_r * 0.72
	var d: Vector2 = p - t.origin
	var len := d.length()
	if len > 10: t.moved = true
	# 끝까지 밀고도 더 끌면 스틱 받침이 손가락을 따라온다 (엄지가 받침 밖으로 빠져도 방향이 살아 있게)
	if len > R * 1.6:
		t.origin += d / len * (len - R * 1.6)
		_stick_c = t.origin
		d = p - t.origin
		len = d.length()
	if len == 0:
		_knob = Vector2.ZERO
		return
	var k := minf(1, len / R)
	var v := d / len * k
	_knob = v * R
	GameInput.virtual_axis = v if v.length() > 0.18 else Vector2.ZERO


func _pressed(action: String) -> bool:
	return _touches.values().any(func(t): return t.kind == "btn" and t.action == action)


# ---------- 지금 쓸 수 있는 단추만 ----------

func _refresh() -> void:
	var p = GameState.player
	# 쏘지 않을 때도 누구를 붙잡을지 미리 골라 둔다 (조준 표시가 늘 떠 있어 [숨결]을 누르기 전에 과녁이 보인다)
	if GameInput.touch_aim(): p.aim_angle()
	for slot in ["Q", "F", "R"]:
		var b: Dictionary = buttons["skill" + slot]
		var id = p.slots.get(slot)
		b.on = id != null
		if id:
			var cd: bool = p.cooldowns.get(id, 0.0) > 0
			if _was_cd.get(slot, false) and not cd: _ready_flash[slot] = 0.35   # 막 돌아왔다
			_was_cd[slot] = cd
	buttons.ultimate.on = p.elements.size() >= 3
	buttons.nextElement.on = p.elements.size() >= 2
	buttons.eat.on = p.inventory.meat > 0
	buttons.fly.on = p.stage_index >= 2
	buttons.kids.on = GameState.partner != null or not GameState.kids.is_empty()
	# 작은 단추는 보이는 것끼리 빈틈없이 모은다
	var screen := get_viewport_rect().size
	var shown := ["journal", "eat", "fly", "kids", "gear"].filter(func(a): return buttons[a].on)
	for i in shown.size():
		var b: Dictionary = buttons[shown[i]]
		if portrait: b.c.y = roundf(buttons.ultimate.c.y - buttons.ultimate.r - 1.0 * u - i * 1.18 * u)
		else: b.c.x = roundf(screen.x / 2 + (i - (shown.size() - 1) / 2.0) * 1.2 * u)


# ---------- 그리기 ----------

func _draw() -> void:
	var p = GameState.player
	if p == null: return
	_draw_lock(p)
	_draw_stick()
	var els: Dictionary = Data.get_module("elements").ELEMENTS
	var defs := Skills.defs()
	var el: Dictionary = els[p.element]
	var el_col := Color(el.color)
	for a in buttons:
		var b: Dictionary = buttons[a]
		if not b.on: continue
		var down := _pressed(a)
		var c: Vector2 = b.c
		var r: float = b.r * (0.93 if down else 1.0)   # 누르면 살짝 들어간다
		match b.kind:
			"main":
				_disc(c, r + 3, Color(0, 0, 0, 0.25))
				_disc(c, r, el_col.darkened(0.55 if not down else 0.2) * Color(1, 1, 1, 0.72))
				draw_arc(c, r - 1.5, 0, TAU, 48, el_col.lightened(0.25), 3.0, true)
				draw_arc(c, r * 0.72, 0, TAU, 40, Color(1, 1, 1, 0.12), 1.5, true)
				_text(el.name, c + Vector2(0, -2), 24, Color.WHITE)
				_text("숨결", c + Vector2(0, r * 0.52), 12, Color(1, 1, 1, 0.75))
			"skill":
				var slot: String = a.substr(5)
				var id = p.slots.get(slot)
				var left: float = p.cooldowns.get(id, 0.0)
				var full: float = maxf(0.01, p.cd_max.get(id, defs[id].cooldown))
				_disc(c, r + 2, Color(0, 0, 0, 0.25))
				_disc(c, r, (GOLD * Color(1, 1, 1, 0.5)) if down else INK * Color(1, 1, 1, 0.72))
				if left > 0:
					_pie(c, r - 2, left / full, Color(0, 0, 0, 0.6))
					draw_arc(c, r - 1, 0, TAU, 40, Color(0.5, 0.47, 0.4, 0.8), 2.0, true)
					_text(("%.1f" % left) if left < 1 else str(ceili(left)), c + Vector2(0, 1), 24, Color(1, 1, 1, 0.95))
				else:
					var flash: float = _ready_flash.get(slot, 0.0)
					if flash > 0: _disc(c, r + 6 * flash / 0.35, Color(1, 0.85, 0.3, flash))
					draw_arc(c, r - 1, 0, TAU, 40, GOLD, 2.0, true)
					_label_lines(defs[id].name, c, r, Color(1, 0.95, 0.85))
				_badge(slot, c + Vector2(r * 0.72, -r * 0.72))
			"ult":
				var full_ult: bool = p.ult >= 100
				_disc(c, r + 2, Color(0, 0, 0, 0.25))
				_disc(c, r, Color(0.35, 0.16, 0.5, 0.85) if full_ult else INK * Color(1, 1, 1, 0.72))
				draw_arc(c, r - 1, 0, TAU, 40, Color(1, 1, 1, 0.15), 3.0, true)
				draw_arc(c, r - 1, -PI / 2, -PI / 2 + TAU * clampf(p.ult / 100.0, 0, 1), 40, Color("#e0b0ff"), 3.0, true)
				if full_ult:
					var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)
					draw_arc(c, r + 3 + pulse * 3, 0, TAU, 40, Color(0.88, 0.69, 1, 0.6 * pulse), 2.0, true)
					_text("융합", c + Vector2(0, 1), 12, Color.WHITE)
				else:
					_text("%d%%" % floori(p.ult), c + Vector2(0, 1), 12, Color(1, 1, 1, 0.8))
			"round":
				var col := GOLD
				var label: String = { sprint = "대시", confirm = "말", nextElement = "속성" }[a]
				var dim := false
				if a == "confirm": dim = not Hud.has_interact()   # 눈앞에 말 걸 것 · 주울 것이 있을 때만 또렷하다
				if a == "nextElement":
					col = Color(els[_next_element(p)].color)
					label = String(els[_next_element(p)].name)
				_disc(c, r, (col * Color(1, 1, 1, 0.5)) if down else INK * Color(1, 1, 1, 0.45 if dim else 0.7))
				draw_arc(c, r - 1, 0, TAU, 32, col * Color(1, 1, 1, 0.35 if dim else 0.9), 2.0, true)
				_text(label, c + Vector2(0, 1), 12, Color(1, 1, 1, 0.45 if dim else 1.0))
			"util":
				_disc(c, r, (GOLD * Color(1, 1, 1, 0.5)) if down else INK * Color(1, 1, 1, 0.72))
				draw_arc(c, r - 1, 0, TAU, 28, GOLD * Color(1, 1, 1, 0.7), 1.5, true)
				_text(ICONS[a], c + Vector2(0, 1), 12, Color(1, 0.93, 0.75))
				_text(NAMES[a], c + Vector2(0, r + 9), 12, Color(1, 1, 1, 0.85), true)


func _next_element(p) -> String:
	var have: Array = Data.get_module("elements").ELEMENTS.keys().filter(func(e): return p.elements.has(e))
	if have.size() < 2: return p.element
	return have[(have.find(p.element) + 1) % have.size()]


func _draw_stick() -> void:
	var a := 1.0 if _stick_live else 0.45
	_disc(_stick_c, _stick_r, Color(1, 1, 1, 0.06 * a))
	draw_arc(_stick_c, _stick_r, 0, TAU, 48, Color(1, 1, 1, 0.25 * a), 2.0, true)
	if _stick_live and _knob != Vector2.ZERO:
		# 미는 쪽을 가리키는 호
		var ang := _knob.angle()
		draw_arc(_stick_c, _stick_r - 4, ang - 0.5, ang + 0.5, 12, Color(1, 0.85, 0.3, 0.7), 4.0, true)
	_disc(_stick_c + _knob, 0.62 * u, Color(1, 0.847, 0.29, 0.5 * a))
	draw_arc(_stick_c + _knob, 0.62 * u, 0, TAU, 32, Color(1, 1, 1, 0.55 * a), 2.0, true)


## 숨결이 붙잡은 적 (유도탄이 따라갈 과녁). 네 귀퉁이 꺾쇠가 천천히 돈다
func _draw_lock(p) -> void:
	var tg = p.aim_lock
	if tg == null or not is_instance_valid(tg) or tg.remove or tg.hp <= 0 or p.aim_lock_timer <= 0: return
	var cam := GameCamera.current
	if cam == null: return
	var sc: Vector2 = (Vector2(tg.x, tg.y - 20) - cam.position) * cam.zoom.x
	var r := 26.0 * clampf(cam.zoom.x, 0.7, 1.6)
	var spin := Time.get_ticks_msec() / 900.0
	var col := Color(1, 0.35, 0.25, 0.9) if GameInput.down("attack") else Color(1, 0.85, 0.3, 0.75)
	for i in 4:
		var a0 := spin + i * PI / 2
		draw_arc(sc, r, a0 - 0.35, a0 + 0.35, 8, col, 2.5, true)
	_disc(sc, 2.5, col)


func _disc(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c, r, col, true, -1.0, true)


## 위에서부터 시계 방향으로 frac 만큼 덮는 부채꼴 (쿨타임)
func _pie(c: Vector2, r: float, frac: float, col: Color) -> void:
	if frac <= 0: return
	var pts := PackedVector2Array([c])
	var n := maxi(3, ceili(40 * frac))
	for i in n + 1:
		pts.append(c + Vector2.from_angle(-PI / 2 + TAU * frac * i / n) * r)
	draw_colored_polygon(pts, col)


func _text(s: String, c: Vector2, size: int, col: Color, shadow := false) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(roundf(c.x - w / 2), roundf(c.y + size * 0.38))
	if shadow or size <= 12: draw_string(_font, at + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.8 * col.a))
	draw_string(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## 기술 이름: 단추 폭에 안 들어가면 두 줄로 나눈다
func _label_lines(s: String, c: Vector2, r: float, col: Color) -> void:
	var max_w := r * 1.8
	if _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <= max_w:
		_text(s, c, 12, col)
		return
	var words := s.split(" ")
	var a := s.substr(0, ceili(s.length() / 2.0))
	var b := s.substr(a.length())
	if words.size() >= 2:
		a = " ".join(words.slice(0, ceili(words.size() / 2.0)))
		b = " ".join(words.slice(ceili(words.size() / 2.0)))
	_text(a.strip_edges(), c + Vector2(0, -7), 12, col)
	_text(b.strip_edges(), c + Vector2(0, 7), 12, col)


func _badge(s: String, c: Vector2) -> void:
	_disc(c, 8, Color(0, 0, 0, 0.75))
	draw_arc(c, 8, 0, TAU, 16, GOLD * Color(1, 1, 1, 0.8), 1.0, true)
	_text(s, c + Vector2(0, 0), 12, Color(1, 0.85, 0.3))
