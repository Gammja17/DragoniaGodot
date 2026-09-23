class_name Status
## 2D판 systems/status.js. 상태 이상: BURN(지속 피해), SLOW(이동 절반), STUN(정지),
## WET(젖음. 그 자체로는 해가 없고 연계의 재료), POISON(오래가는 지속 피해). 적/사냥꾼/보스 공용.
## 대상은 hp, take_damage(dmg, silent) 를 가진 개체.

const BURN_DPS := 3.0
const POISON_DPS := 2.2


static func apply(e, type: String, duration: float) -> void:
	if e.status_immune and type == "STUN": duration *= 0.35   # 보스는 기절이 짧다
	if type == "SLOW" and Relics.has("MORGATH_HORN"): duration *= 2
	e.status[type] = maxf(e.status.get(type, 0.0), duration)


## 매 프레임 호출. 이동 속도 배율(0~1)을 돌려준다
static func update(e, dt: float) -> float:
	var s: Dictionary = e.status
	var speed := 1.0
	if s.get("BURN", 0) > 0:
		s.BURN -= dt
		e.take_damage(BURN_DPS * (2.0 if Relics.has("IGNAR_HEART") else 1.0) * dt, true)
	if s.get("POISON", 0) > 0:
		s.POISON -= dt
		e.take_damage(POISON_DPS * dt, true)
	if s.get("WET", 0) > 0: s.WET -= dt
	if s.get("SLOW", 0) > 0:
		s.SLOW -= dt; speed *= 0.5
	if s.get("STUN", 0) > 0:
		s.STUN -= dt; speed = 0.0
	return speed


## 상태에 따른 표시 색 (없으면 null)
static func tint(e):
	var s: Dictionary = e.status
	if s.get("STUN", 0) > 0: return Color("#fff2a8")
	if s.get("SLOW", 0) > 0: return Color("#7fd4ff")
	if s.get("BURN", 0) > 0: return Color("#ff9a3c")
	if s.get("POISON", 0) > 0: return Color("#9fe07a")
	if s.get("WET", 0) > 0: return Color("#7fc4ff")
	return null
