class_name Weather
## 2D판 systems/weather.js 가운데 숨결 배율. 날씨가 바뀌고 비·눈이 내리는 것은 6단계(연출)에서 옮긴다.


## 비가 오면 불은 약해지고 번개는 세진다
static func damage_mult(element) -> float:
	if GameState.weather.type == "CLEAR": return 1.0
	if element == "FIRE": return 0.8
	if element == "THUNDER": return 1.25
	return 1.0
