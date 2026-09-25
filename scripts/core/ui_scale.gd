extends Node
## UI 크기 (autoload "UiScale").
## 창이 커지면 글자와 판도 같이 커진다: 창을 기준 크기(데스크톱 960×540, 휴대폰 780×420)에 맞춰 늘리는
## 휴대폰을 세로로 들면 기준도 세워 420×780 으로 (가로일 때와 글자 크기가 같다).
## canvas_items 늘이기를 쓰고, 기준 크기를 설정의 "UI 크기"로 나눈다 (크게 = 기준을 줄여 더 크게 늘린다).
## 960×540 은 1080p 화면에서 딱 2배(픽셀 글꼴이 또렷하다), 720p 에서 1.33배.
## 세상(땅·용)은 GameCamera 가 이 배율만큼 줌을 되돌려, UI 크기와 상관없이 전과 같은 크기로 그린다.
## 창이 기준보다 작으면 줄이지 않는다 (12px 픽셀 글꼴이 뭉개진다). 창 없는 시험(headless)은 늘 1배.

const DESKTOP := Vector2(960, 540)
const MOBILE := Vector2(780, 420)   # 휴대폰은 화면이 작아 기준을 낮춘다 (그래야 글자가 손톱만 하지 않다)
const STEPS := [0.8, 1.0, 1.2, 1.4]
const STEP_NAMES := ["작게", "보통", "크게", "아주 크게"]


func _ready() -> void:
	_grow_window()
	get_window().size_changed.connect(apply)
	apply()


static func setting() -> float:
	var v: float = float(Prefs.get_value("view", "ui_scale", 1.0))
	return v if STEPS.has(v) else 1.0


static func setting_name() -> String: return STEP_NAMES[STEPS.find(setting())]


## 다음 단계로 (설정 창)
func cycle() -> String:
	var i := (STEPS.find(setting()) + 1) % STEPS.size()
	Prefs.set_value("view", "ui_scale", STEPS[i])
	apply()
	return STEP_NAMES[i]


## 시험·사진 도구가 PC 에서 휴대폰 화면을 흉내 낼 때 켠다
static var force_mobile := false


static func is_mobile() -> bool:
	return force_mobile or OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


static func _headless() -> bool: return DisplayServer.get_name() == "headless"


func apply() -> void:
	var win := get_window()
	var phys := Vector2(win.size)
	var base := (MOBILE if is_mobile() else DESKTOP) / setting()
	# 세로로 든 휴대폰은 기준도 세운다 (780×420 을 그대로 대면 짧은 변 420 이 780 으로 늘어나 글자·단추가 가로의 절반만 했다)
	if is_mobile() and phys.y > phys.x: base = Vector2(base.y, base.x)
	var k := minf(phys.x / base.x, phys.y / base.y)
	if k < 1 or _headless(): base = phys   # 창이 더 작으면(또는 시험이면) 늘이지도 줄이지도 않는다
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_size = Vector2i(base.round())


## 지금 UI 가 늘어난 배율 (논리 1px 이 화면 몇 px 인가)
func factor() -> float:
	var win := get_window()
	var base := Vector2(win.content_scale_size)
	if base.x <= 0 or base.y <= 0: return 1.0
	return maxf(0.01, minf(win.size.x / base.x, win.size.y / base.y))


## 세상을 그릴 배율: 화면 자체의 배율 (웹은 devicePixelRatio, 윈도는 DPI/96, 휴대폰은 화면 밀도).
## 2D판이 CSS px 로 그리던 것과 같게, 고해상도 화면에서도 타일이 작아지지 않는다
func world_scale() -> float:
	if _headless(): return 1.0
	var s := DisplayServer.screen_get_scale()
	if OS.get_name() == "Windows": s = DisplayServer.screen_get_dpi() / 96.0
	return clampf(s, 1.0, 4.0)


## PC 에서 창으로 켜면 1280×720 작은 창 대신 화면의 85% 크기(16:9)로 연다
func _grow_window() -> void:
	if OS.has_feature("web") or is_mobile() or _headless(): return
	var win := get_window()
	if win.mode != Window.MODE_WINDOWED: return
	var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
	var s := minf(usable.size.x * 0.85 / 16.0, usable.size.y * 0.85 / 9.0)
	var want := Vector2i(roundi(s * 16), roundi(s * 9))
	if want.x <= win.size.x: return
	win.size = want
	win.position = usable.position + (usable.size - want) / 2
