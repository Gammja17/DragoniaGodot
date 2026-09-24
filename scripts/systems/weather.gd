class_name Weather
## 2D판 systems/weather.js. 날씨가 바뀌고, 비가 오면 숨결 세기가 달라진다. 비·눈을 그리는 것은 6단계(연출)에서.
##
## 날씨는 맑음(CLEAR)과 비(RAIN) 둘이다. 폭풍은 따로 두지 않고 번개 치는 센 비(RAIN + storm)로 친다.
## 비 혼잣말 · 비 올 때의 일과 · 스승이 쉬어 가는 날이 모두 RAIN 만 보는데, 폭풍일 때는 셋 다 빠졌다.
## 비는 비가 그려지는 곳에만 내린다. 설원(늘 눈) · 화산(불티) · 재가 내리는 마을에 들어서면 그친다
## (눈이 쏟아지는데 "빗소리 들으면 잠이 와"가 뜨고, 보이지 않는 비가 불을 약하게 하던 것).

const NAMES := { "CLEAR": "맑음", "RAIN": "비" }
const TARGET := { "CLEAR": 0.0, "RAIN": 0.6 }
const STORM_INTENSITY := 1.0


static func stormy() -> bool: return GameState.weather.type == "RAIN" and bool(GameState.weather.get("storm", false))


static func weather_name() -> String: return "폭풍" if stormy() else NAMES.get(GameState.weather.type, "맑음")


## 지금 있는 곳에 비가 그려지는가 (WeatherView 와 같은 판단). 굴 속 · 굴 안은 그리지 않을 뿐 바깥 비는 그대로 둔다
static func rain_falls_here() -> bool:
	if GameState.dungeon or GameState.indoors: return true
	var biome := Terrain.active_biome()
	if biome == "SNOW" or biome == "VOLCANO": return false
	return not (GameState.map_id == "VILLAGE" and GameState.story.get("route") == "dark" and GameState.quests.get("done", []).has("m7d"))


## 비가 오면 불은 약해지고 번개는 세진다
static func damage_mult(element) -> float:
	if GameState.weather.type == "CLEAR": return 1.0
	if element == "FIRE": return 0.8
	if element == "THUNDER": return 1.25
	return 1.0


static func update(dt: float) -> void:
	var w: Dictionary = GameState.weather
	var here := rain_falls_here()
	if w.type != "CLEAR" and not here:   # 비가 그려지지 않는 곳에 들어섰다. 그곳에 있는 동안은 비가 오지 않는다
		w.type = "CLEAR"
		w.storm = false
	w.timer -= dt
	if w.timer <= 0:
		var rainy := 0.7 if Terrain.active_biome() == "JUNGLE" else 0.4
		var r := randf()
		var nxt := "CLEAR" if w.type != "CLEAR" or not here else "RAIN" if r < rainy else "CLEAR"
		var storm := nxt == "RAIN" and r < rainy * 0.3
		if nxt != w.type:
			w.type = nxt
			if storm: Hud.pop("폭풍이 몰려옵니다! (불 ↓ 번개 ↑)", "⛈️")
			elif nxt == "RAIN": Hud.pop("비가 내리기 시작합니다. (불 ↓ 번개 ↑)", "🌧️")
		w.storm = storm
		w.timer = Util.rand_range(70, 130) if nxt == "CLEAR" else Util.rand_range(40, 70)
	var target: float = STORM_INTENSITY if stormy() else TARGET.get(w.type, 0.0)
	w.intensity += (target - w.intensity) * minf(1, dt * 0.5)
	if w.flash > 0: w.flash -= dt * 2.5
	if stormy() and randf() < dt * 0.18: w.flash = 1.0
