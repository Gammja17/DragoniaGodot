class_name NightEvents
## 2D판 systems/events.js 의 배율. 밤 이벤트(핏빛 달·유성우) 자체는 6단계(낮밤)에서 옮긴다.


static func enemy_cap_mult() -> float:
	return 1.8 if GameState.event == "BLOOD_MOON" else 1.0


static func xp_mult() -> float:
	return 1.5 if GameState.event == "BLOOD_MOON" else 1.0
