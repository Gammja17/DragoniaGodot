class_name ScreenFx
## 화면 효과 설정 (조명 · 날씨 · 후처리). "화면 효과" 판(scenes/ui/fx_panel.tscn)에서 고치고,
## 이 기기의 user://settings.cfg [fx] 에 남는다. 그리는 쪽(Lighting · WeatherView · PostFx)은 매 프레임 여기서 읽는다.

const DEFAULTS := {
	"post": true,          # 후처리 전체 (번짐 · 색 어긋남 · 일렁임 · 가장자리 어둠 · 색 보정)
	"bloom": 0.85,         # 번짐 세기 (2D판 BLOOM)
	"threshold": 0.62,     # 이 밝기부터 번진다 (2D판 THRESHOLD)
	"aberration": 1.0,     # 가장자리 색 어긋남 배율
	"warp": 1.0,           # 맞을 때 화면 일렁임 배율
	"vignette": 1.0,       # 화면 가장자리 어둠 배율
	"night": 1.0,          # 밤·굴 속 어둠 (0 이면 늘 낮처럼 밝다)
	"brightness": 1.0,
	"contrast": 1.0,
	"saturation": 1.0,
	"clouds": true,        # 낮의 구름 그림자 · 밤의 반딧불이
	"weather": true,       # 비 · 눈 · 불티 · 번갯불
}

static var _v := {}


static func value(key: String):
	if _v.is_empty(): _load()
	return _v[key]


static func set_value(key: String, v) -> void:
	if _v.is_empty(): _load()
	_v[key] = v
	Prefs.set_value("fx", key, v)


static func reset() -> void:
	for k in DEFAULTS: set_value(k, DEFAULTS[k])


static func _load() -> void:
	for k in DEFAULTS: _v[k] = Prefs.get_value("fx", k, DEFAULTS[k])
