class_name Gathering
## 2D판 systems/gathering.js 의 날짜 셈. 달이 가장 밝은 밤, 두 마을이 폭포 아래로 모인다.
## (모임 장면 자체는 스토리 단계에서 옮긴다)

const GATHER_EVERY := 8        # 며칠마다
const GATHER_FROM := 20        # 몇 시부터
const GATHER_MAP := "FALLS"

## 모임 때 각자 서는 자리 (구름 폭포의 큰 칸 좌표)
const GATHER_SPOTS := {
	"Riun": [12, 9], "Seiran": [13, 10], "Haru": [11, 11], "Yuan": [14, 9],
	"Elder": [8, 9], "Kairon": [7, 10], "Nara": [9, 11], "Tiamat": [6, 9], "Gron": [8, 12], "Poco": [10, 12],
}


## 오늘이 모임 날인가
static func is_gather_day(day := -1) -> bool:
	if day < 0: day = GameState.day
	return _first_gathering() or (day > 0 and day % GATHER_EVERY == 0)


## 스무 해 만에 다시 서는 첫 모임. 주인공이 와서 볼 때까지 밤마다 불을 피운다 (퀘스트 m5g)
static func _first_gathering() -> bool:
	return GameState.quests.active.has("m5g") and not GameState.story.events.has("ev_gathering")


## 지금 모임이 서 있는가
static func is_gather_now() -> bool:
	return is_gather_day() and GameState.dayTime * 24 >= GATHER_FROM


## 다음 모임까지 며칠
static func days_to_gather() -> int:
	var left := GATHER_EVERY - (GameState.day % GATHER_EVERY)
	if left == GATHER_EVERY:
		return GATHER_EVERY if GameState.dayTime * 24 >= GATHER_FROM else 0
	return left


## 폭포 위로 올라가 본 적이 있는가 (모임에 한 번 나가면 열린다)
static func invited_up() -> bool:
	return GameState.story.events.has("ev_gathering")
