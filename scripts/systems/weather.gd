class_name Weather
## 2D판 systems/weather.js. 날씨가 바뀌고, 비가 오면 숨결 세기가 달라진다. 비·눈을 그리는 것은 6단계(연출)에서.

const NAMES := { "CLEAR": "맑음", "RAIN": "비", "STORM": "폭풍" }
const TARGET := { "CLEAR": 0.0, "RAIN": 0.6, "STORM": 1.0 }


static func weather_name() -> String: return NAMES[GameState.weather.type]


## 비가 오면 불은 약해지고 번개는 세진다
static func damage_mult(element) -> float:
	if GameState.weather.type == "CLEAR": return 1.0
	if element == "FIRE": return 0.8
	if element == "THUNDER": return 1.25
	return 1.0


static func update(dt: float) -> void:
	var w: Dictionary = GameState.weather
	w.timer -= dt
	if w.timer <= 0:
		var rainy := 0.7 if Terrain.active_biome() == "JUNGLE" else 0.4
		var r := randf()
		var nxt := "CLEAR" if w.type != "CLEAR" else "STORM" if r < rainy * 0.3 else "RAIN" if r < rainy else "CLEAR"
		if nxt != w.type:
			w.type = nxt
			if nxt == "RAIN": Hud.pop("비가 내리기 시작합니다. (화염 ↓ 번개 ↑)", "🌧️")
			if nxt == "STORM": Hud.pop("폭풍이 몰려옵니다! (화염 ↓ 번개 ↑)", "⛈️")
		w.timer = Util.rand_range(70, 130) if nxt == "CLEAR" else Util.rand_range(40, 70)
	w.intensity += (TARGET[w.type] - w.intensity) * minf(1, dt * 0.5)
	if w.flash > 0: w.flash -= dt * 2.5
	if w.type == "STORM" and randf() < dt * 0.18: w.flash = 1.0
