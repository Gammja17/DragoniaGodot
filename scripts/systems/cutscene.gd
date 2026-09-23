class_name Cutscene
## 2D판 systems/cutscene.js. 컷씬 연출.
##
## 사건이 터지면:
##   · 위아래로 검은 띠가 내려온다 (레터박스)
##   · 화면이 어두워지고, 말하는 용과 나에게만 빛이 남는다
##   · 카메라가 둘 사이로 천천히 옮겨 가고 살짝 당겨진다
##   · HUD·미니맵·길잡이·알림이 숨는다
##   · 장면 제목이 화면 가운데에 한 번 떴다 사라진다
## 세계 자체는 대화창이 떠 있는 동안 main 이 이미 멈춰 둔다. 여기서는 "어떻게 보이는가"만 맡는다.
## 그리는 것은 CutsceneView (화면 좌표 층).

const BAR := 0.11          # 레터박스 띠 높이 (화면의 몇 할)
const STAGE := 168         # 말하는 쪽이 내 곁으로 와서 서는 거리
const AIM := 0.42          # 인물을 화면 위에서 몇 할 지점에 놓을까 (대화창 위)
const DIM := 0.55          # 얼마나 어둡게
const BOOST := 1.18        # 카메라를 얼마나 당길까
const EASE := 0.12

static var on := false
static var bars := 0.0     # 0 → 1 로 자라는 띠
static var dim := 0.0
static var boost := 1.0
static var focus = null    # 지금 말하는 쪽 (개체)
static var poi = null      # { target, label } 이번 대사가 가리키는 것
static var title := ""
static var title_t := 0.0
static var snap := true    # 장면이 막 시작했으면 카메라를 바로 옮긴다

# 무대에 올린 개체들. 끝나면 있던 자리로 돌려놓는다. guest: 이 지도에 없던 용을 잠깐 불러온 경우
static var _cast := []


## 무대에 세운다. 말하는 용이 멀리 있거나 딴 지도에 있으면 연극처럼 불러와 내 곁에 세우되,
## 툭 나타나면 어색하니 옆에서 걸어 들어오게 한다
static func _stage(e) -> void:
	if e == null or e == GameState.player: return
	var p = GameState.player
	var m = null
	for c in _cast:
		if c.e == e: m = c
	if m == null:
		var here: bool = GameState.entities.npcs.has(e) or GameState.entities.bosses.has(e)
		m = { e = e, x = e.x, y = e.y, facing = e.facing, guest = not here, slot = _cast.size(), entered = false }
		_cast.append(m)
		if not here: World.add_entity("npcs", e)     # 이 지도에 없던 용을 잠깐 불러온다
	# 자리: 나를 가운데 두고 좌우로 번갈아 선다
	var side := 1 if m.slot % 2 == 0 else -1
	var rank := floori(m.slot / 2.0)
	m.to = _clear_spot(p.x + side * (STAGE + rank * 92), p.y - 14 - rank * 26)
	m.face = "left" if side > 0 else "right"
	# 처음 오를 때: 멀리 있거나 딴 지도에 있던 용은 화면 밖에서 스르르 걸어 들어온다
	if not m.entered:
		m.entered = true
		var cam := GameCamera.current
		var far: bool = m.guest or Vector2(e.x - m.to.x, e.y - m.to.y).length() > cam.w * 0.55
		if far:
			e.x = m.to.x + side * (cam.w * 0.5 + 120)
			e.y = m.to.y + 30
			e.stage_alpha = 0.0      # 걸어오며 또렷해진다
	p.facing = "right" if side > 0 else "left"


## 이 개체가 지금 무대에 올라 있는가 (컷씬에서 무대 밖의 것은 그리지 않는다)
static func on_stage(e) -> bool:
	if not on: return true
	if e == GameState.player: return true
	if poi and poi.target == e: return true
	for c in _cast:
		if c.e == e: return true
	return false


static func _clear_spot(x: float, y: float) -> Vector2:
	for r in range(0, 181, 30):
		for i in 8:
			var a := (i / 8.0) * TAU
			var px := x + cos(a) * r
			var py := y + sin(a) * r
			if not Collision.solid_at(px, py, 18): return Vector2(px, py)
	return Vector2(x, y)


## 컷씬 시작. speakers: 이 장면에서 말할 이들. 처음부터 다 무대에 올려 두면 제 차례에 불쑥 나타나지 않는다
static func begin(t := "", speakers := []) -> void:
	on = true
	snap = true
	for e in speakers: _stage(e)
	title = t
	title_t = 2.6 if t != "" else 0.0
	Hud.scene_title(t)
	DialogueBox.current.set_cinematic(true)


## 이번 대사를 말하는 쪽을 카메라가 본다
static func focus_on(entity) -> void:
	_stage(entity)
	focus = entity


## 이번 대사가 가리키는 것 (시설이든 용이든). 카메라가 나와 그것 사이를 보고, 빛이 떨어지고, 이름표가 뜬다
static func point_at(target, label := "") -> void:
	poi = { target = target, label = label } if target else null


static func finish() -> void:
	poi = null
	for m in _cast:
		var e = m.e
		if not is_instance_valid(e): continue
		e.x = m.x; e.y = m.y; e.facing = m.facing; e.moving = false
		e.stage_alpha = 1.0
		# 불러왔던 용은 다시 제 일과로 돌려보낸다
		if m.guest:
			GameState.entities.npcs.erase(e)
			if e.is_inside_tree(): e.get_parent().remove_child(e)
	_cast.clear()
	on = false
	focus = null
	title_t = 0.0
	Hud.scene_title("")
	DialogueBox.current.set_cinematic(false)


## 카메라가 볼 자리. 컷씬이면 나와 상대의 가운데. 대화창이 아래를 덮으므로 인물을 화면 위쪽(AIM)에 놓는다
static func camera_target(cam_h: float):
	if not on: return null
	var p = GameState.player
	var f = null
	if poi: f = poi.target
	elif focus and focus != p: f = focus
	var x: float = (p.x + f.x) / 2 if f else p.x
	var y: float = (p.y + f.y) / 2 if f else p.y
	return Vector2(x, y + cam_h * (0.5 - AIM))


## 매 프레임: 띠와 어둠이 스르르 들어오고 나간다 (대화창이 떠 있어도 돌아야 한다)
static func update(dt: float) -> void:
	if on: _walk_cast(dt)        # 세계가 멈춰 있어도 배우는 움직인다
	var want := 1.0 if on else 0.0
	bars += (want - bars) * EASE
	dim += (want - dim) * EASE
	boost += ((BOOST if on else 1.0) - boost) * EASE
	if bars < 0.002 and not on: bars = 0.0
	if title_t > 0:
		title_t -= dt
		if title_t <= 0: Hud.scene_title("")


## 무대에 오른 이들을 제자리로 걸린다. 말하는 쪽은 반걸음 앞으로
static func _walk_cast(dt: float) -> void:
	for m in _cast:
		var e = m.e
		if not is_instance_valid(e): continue
		var speaking: bool = focus == e
		var tx: float = m.to.x
		var ty: float = m.to.y + (14 if speaking else 0)   # 말할 차례엔 앞으로 나선다
		var dx: float = tx - e.x
		var dy: float = ty - e.y
		var d := Vector2(dx, dy).length()
		if d > 2:
			var k := minf(1, (dt * 260) / d)
			e.x += dx * k; e.y += dy * k
			e.moving = d > 24
		else:
			e.moving = false
		if e.stage_alpha < 1: e.stage_alpha = minf(1, e.stage_alpha + dt * 1.4)
		e.facing = m.face
