class_name GameCamera
extends Camera2D
## 2D판 core/camera.js. 시점은 2D판처럼 왼쪽 위 모서리(cam_x, cam_y)와 월드 기준 화면 크기(w, h)로 다룬다.

# 픽셀아트가 뭉개지지 않게, 타일 배율(3배 × 줌)이 정수가 되는 값만 쓴다.
# 멀리(2배) → 보통(3배) → 가까이(4배) → 아주 가까이(5배) 순으로 늘어놓는다.
const ZOOMS := [2.0 / 3.0, 1.0, 4.0 / 3.0, 5.0 / 3.0]
const ZOOM_NAMES := ["멀리", "보통", "가까이", "아주 가까이"]

static var current: GameCamera     # 흔들림·반동을 어디서든 부를 수 있게

var cam_x := 0.0
var cam_y := 0.0
var w := 0.0              # 월드 기준 화면 크기 (줌을 당기면 작아진다)
var h := 0.0
var shake_x := 0.0
var shake_y := 0.0
var zoom_index := 1
var _shake_power := 0.0
var _boost := 1.0         # 컷씬은 시점을 잠깐 더 당긴다. 줌 단계를 건드리지 않고 배율만 덧씌운다


func _ready() -> void:
	current = self
	anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	# 저장된 값이 없으면: 휴대폰은 '멀리', 아니면 '보통'
	zoom_index = 0 if UiScale.is_mobile() else 1
	var saved = Prefs.get_value("view", "zoom", -1)
	if saved is int and saved >= 0 and saved < ZOOMS.size(): zoom_index = saved
	get_viewport().size_changed.connect(_apply_boost.bind(1.0))
	_apply_boost(1.0)


func zoom_name() -> String:
	return ZOOM_NAMES[zoom_index]


func _apply_boost(b: float) -> void:
	_boost = b
	# UI 크기 배율만큼 되돌리고 화면 배율(고해상도)만큼 키운다: 세상은 UI 크기와 상관없이
	# 늘 "화면 배율 1 에서 타일 3배 × 줌" 크기로 그린다 (2D판이 CSS px 로 그리던 것과 같다)
	var z: float = ZOOMS[zoom_index] * _boost * UiScale.world_scale() / UiScale.factor()
	zoom = Vector2(z, z)
	var screen := get_viewport_rect().size
	w = screen.x / z
	h = screen.y / z


## 줌 단계를 바꾼다. 화면 가운데를 붙잡아 두어 시점이 튀지 않게 한다
func _apply_zoom(index: int) -> String:
	var next := clampi(index, 0, ZOOMS.size() - 1)
	if next == zoom_index: return ZOOM_NAMES[zoom_index]
	zoom_index = next
	Prefs.set_value("view", "zoom", zoom_index)
	var cx := cam_x + w / 2
	var cy := cam_y + h / 2
	_apply_boost(_boost)
	cam_x = cx - w / 2; cam_y = cy - h / 2
	return ZOOM_NAMES[zoom_index]


## [V] 다음 줌 단계로 (끝에 닿으면 처음으로)
func cycle_zoom() -> String:
	return _apply_zoom((zoom_index + 1) % ZOOMS.size())


## 휠을 굴려 한 단계씩. dir > 0 이면 당겨 본다(확대)
func step_zoom(dir: int) -> String:
	return _apply_zoom(zoom_index + signi(dir))


## 화면 흔들림 (세게 맞았을 때, 운석 등)
func shake(power: float) -> void:
	_shake_power = maxf(_shake_power, power)


## 쏠 때의 반동. 겨눈 반대쪽으로 화면을 살짝 밀면 손맛이 난다 (따라가기가 곧 되돌린다)
func kick(a: float, px := 3.0) -> void:
	cam_x -= cos(a) * px
	cam_y -= sin(a) * px


## 화면 px → 월드 좌표 (마우스가 가리키는 곳)
func screen_to_world(p: Vector2) -> Vector2:
	return p / zoom.x + position


func follow(target, smooth := 0.1) -> void:
	var tx: float = target.x
	var ty: float = target.y
	# 컷씬이면 둘 사이를 천천히 본다
	var shot = Cutscene.camera_target(h)
	if shot != null:
		tx = shot.x
		ty = shot.y
		smooth = 1.0 if Cutscene.snap or Cutscene.exact else 0.055   # 카메라 박자는 제 속도로 옮겨 간다
		Cutscene.snap = false
	if absf(_boost - Cutscene.boost) > 0.0015: _apply_boost(Cutscene.boost)
	cam_x += (tx - w / 2 - cam_x) * smooth
	cam_y += (ty - h / 2 - cam_y) * smooth
	# 지도가 화면보다 작으면 가운데에 둔다. 컷씬일 때는 경계를 조금 넘어가도 둔다 —
	# 인물을 대화창 위로 올려야 하는데 작은 지도에서는 경계에 걸려 화면 아래쪽에 박혀 버린다 (어차피 띠가 가린다)
	var b := Terrain.current_map_bounds()
	var slack := h * 0.34 if shot != null else 0.0
	cam_x = (b.x - w) / 2 if b.x <= w else clampf(cam_x, -slack, b.x - w + slack)
	cam_y = (b.y - h) / 2 if b.y <= h and shot == null else clampf(cam_y, -slack, maxf(-slack, b.y - h + slack))
	_shake_power *= 0.86
	shake_x = (randf() - 0.5) * _shake_power * 2
	shake_y = (randf() - 0.5) * _shake_power * 2
	# 정수 좌표: 픽셀아트가 떨리지 않게
	position = Vector2(roundf(cam_x + shake_x), roundf(cam_y + shake_y))

