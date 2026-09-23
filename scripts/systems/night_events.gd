class_name NightEvents
## 2D판 systems/events.js. 밤 이벤트. 해 질 녘에 주사위를 굴려 그날 밤의 이벤트를 정하고, 새벽에 끝난다.
##  BLOOD_MOON: 적이 훨씬 많이 나오지만 경험치 1.5배. 하늘이 붉어진다 (하늘빛은 6단계 조명에서)
##  METEOR:     별똥별이 주변에 떨어져 골드를 남긴다
##
## 하루 시계(2D판 render/lighting.js 의 updateLighting)도 여기서 돌린다.

const EVENT_NAMES := { "BLOOD_MOON": "붉은 달", "METEOR": "유성우" }
const DUSK := 0.8
const DAWN := 0.25

static var _meteor_timer := 0.0
static var _falling := []   # 떨어지는 중인 별 { x, y, t }


static func event_name():
	return EVENT_NAMES[GameState.event] if GameState.event else null


## 하루 중 지금 (오른쪽 위 지역 표시)
static func day_phase_name() -> String:
	var t := GameState.dayTime
	if t < 0.22 or t >= 0.82: return "밤"
	if t < 0.36: return "새벽"
	if t < 0.68: return "낮"
	return "해질녘"


static func enemy_cap_mult() -> float:
	return 1.8 if GameState.event == "BLOOD_MOON" else 1.0


static func xp_mult() -> float:
	return 1.5 if GameState.event == "BLOOD_MOON" else 1.0


## 하루가 흐른다. DAY_LENGTH 초가 하루
static func update_clock(dt: float) -> void:
	GameState.dayTime += dt / Data.get_module("core_config").DAY_LENGTH
	if GameState.dayTime >= 1:
		GameState.dayTime -= 1
		GameState.day += 1


static func update(dt: float, prev_day_time: float) -> void:
	var t := GameState.dayTime
	if prev_day_time < DUSK and t >= DUSK and not GameState.event:
		var r := randf()
		if r < 0.28:
			GameState.event = "BLOOD_MOON"
			Hud.pop("붉은 달이 떠오릅니다… 몬스터가 들끓지만 경험치가 1.5배!", "🌕")
		elif r < 0.56:
			GameState.event = "METEOR"
			Hud.pop("유성우가 쏟아지는 밤입니다. 떨어진 별을 주워 보세요!", "🌠")
	if GameState.event and t >= DAWN and t < DUSK:
		Hud.pop("%s의 밤이 지나갔습니다." % EVENT_NAMES[GameState.event], "🌅")
		GameState.event = null

	if GameState.event == "METEOR":
		_meteor_timer -= dt
		if _meteor_timer <= 0:
			_meteor_timer = Util.rand_range(3, 7)
			var p = GameState.player
			_falling.append({ x = p.x + Util.rand_range(-520, 520), y = p.y + Util.rand_range(-320, 320), t = 0.0 })
	for m in _falling:
		m.t += dt
		if m.t >= 1:
			Vfx.spawn_effect("STAR", m.x, m.y, { size = 1.4 })
			Particles.burst(m.x, m.y, "#fff2b0", 0.9, 14)
			World.add_entity("items", Item.make(m.x, m.y, "GOLD", roundi(Util.rand_range(8, 22))))
	_falling = _falling.filter(func(m): return m.t < 1)


## 떨어지는 별의 꼬리 (월드 좌표, 더하기 섞기 층에서)
static func draw(ci: CanvasItem) -> void:
	for m in _falling:
		var k: float = m.t
		var hx: float = m.x + (1 - k) * 380
		var hy: float = m.y - (1 - k) * 640
		var pts := PackedVector2Array([Vector2(hx + 60, hy - 100), Vector2(hx, hy)])
		var cols := PackedColorArray([Color(1, 242 / 255.0, 176 / 255.0, 0), Color(1, 250 / 255.0, 220 / 255.0, 0.95)])
		ci.draw_polyline_colors(pts, cols, 4, true)
