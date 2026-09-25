class_name Launch
## 처음 화면(Title)이 게임 씬(main)에 넘겨 주는 것. 씬을 바꾸면 노드가 다 사라지므로 정적 변수로 건넨다.
##   slot    쓸 세이브 칸 (1~3)
##   config  새 용의 설정 { name, species, look, accessory, colors }. null 이면 그 칸의 세이브를 이어 한다
##   ready   처음 화면을 거쳐 왔는가. 시험 장면처럼 main 을 곧바로 띄우면 false

static var ready := false
static var slot := 1
static var config = null


static func new_game(n: int, cfg: Dictionary) -> void:
	ready = true
	slot = n
	config = cfg


## 한 판을 새로 시작하기 전에, 시스템들이 정적 변수에 들고 있던 지난 판의 것을 걷는다
## (처음 화면으로 돌아갔다가 다른 칸을 불러올 때 장면·컷씬·대기줄이 그대로 남아 있으면 안 된다)
static func reset_run() -> void:
	GameState.reset()
	Chronicle._playing = false
	Chronicle._choosing = false
	Chronicle._current = null
	Chronicle._waiting = []
	Chronicle._check_timer = 0.0
	Cutscene.reset()
	BossShow.reset()
	Boss._introduced = {}
	Chatter._running = null
	Chatter._timer = 30.0
	Delve._saved = null
	Dialogue._our_cutscene = false
	NightEvents._falling = []
	RelicOffer.clear()
	Spawner._last_map = null
	Training._shown = ""
	Guide._cache_at = -1.0
	Den._last_tile = null
	Feedback._stop = 0.0
	Feedback._flash_a = 0.0
	Achievements.reset()


static func continue_game(n: int) -> void:
	ready = true
	slot = n
	config = null
