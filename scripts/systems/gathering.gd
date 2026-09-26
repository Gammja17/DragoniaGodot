class_name Gathering
## 2D판 systems/gathering.js 의 날짜 셈. 달이 가장 밝은 밤, 두 마을이 폭포 아래로 모인다.
## 모임은 두 마을 사이의 온도계다. 이야기에 따라 서지 않기도 하고, 앉는 자리와 하는 일과 주고받는 말이 바뀐다 (data/gathering 의 PHASES).
##   첫 모임(5장) → 봉우리에 눈이 내린 뒤부터 전쟁이 끝날 때까지는 서지 않는다 → 전쟁 뒤(7장) → 나란히(8장) → 끝난 뒤
##   잿빛 날개 길을 고르면 다시는 서지 않는다
## 첫 모임의 장면은 사건(chronicle 의 ev_gathering)이 맡는다. 그 뒤로는 단계마다 처음 온 밤에 짧은 장면을 한 번 튼다

const GATHER_EVERY := 8        # 며칠마다
const GATHER_FROM := 20        # 몇 시부터
const GATHER_MAP := "FALLS"

static var _talk = null        # 지금 주고받는 말 { lines, i, t }
static var _talk_wait := 8.0   # 다음 주고받기까지 (초)
static var _said := {}         # 주고받기 id → 나온 날 (한 밤에 같은 말을 되풀이하지 않게)


static func _phases() -> Dictionary: return Data.get_module("gathering").PHASES


## 지금 이야기에서 모임의 모습 (PHASES 의 열쇠). 모임이 서지 않는 때는 ""
static func phase() -> String:
	var s = GameState
	if _first_gathering(): return "first"   # 첫 모임 밤은 늘 선다
	if s.story.get("route") == "dark": return ""
	if s.quests.done.has("m6"): return "redeem" if s.story.get("route") == "redeem" else "peace"
	if s.quests.done.has("m5c"): return "together"
	if s.quests.done.has("m6w"): return "after_war"
	if s.quests.active.has("m5a") or at_war(): return ""
	return "first"


## 오늘이 모임 날인가
## 스무 해 동안 끊겼던 모임은 첫 모임(m5g)에서 다시 선다. 그 전에는 여드레째 밤이 와도 아무도 폭포에 가지 않는다
## (폭포 길이 얼어 있는데 마을이 통째로 비어 보고할 이를 못 찾던 것). 멈춘 때(phase 가 "")에도 서지 않는다
static func is_gather_day(day := -1) -> bool:
	if day < 0: day = GameState.day
	return _first_gathering() or (invited_up() and phase() != "" and day > 0 and day % GATHER_EVERY == 0)


## 스무 해 만에 다시 서는 첫 모임. 주인공이 와서 볼 때까지 밤마다 불을 피운다 (퀘스트 m5g).
## 장면이 끝났다고 모두가 곧장 흩어지면 모임이 아니다 — 그 밤은 끝까지 선다
static func _first_gathering() -> bool:
	if GameState.story.get("eventDay", {}).get("ev_gathering", -1) == GameState.day: return true
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


## 두 마을 사이가 얼어붙어 모임이 멈춰 있는가 (봉우리의 눈 · 전쟁 · 잿빛 날개 길). 일지 · 굴 손님이 본다
static func paused() -> bool:
	return invited_up() and phase() == ""


## 6장 전쟁 동안 (맡긴 알 m5a 를 끝낸 뒤부터 m6w 까지). 두 마을이 폭포에서 맞서 있다
static func at_war() -> bool:
	return GameState.quests.done.has("m5a") and not GameState.quests.done.has("m6w")


## 모임이 멈춘 까닭 한 줄 (일지). 멈추지 않았으면 ""
static func pause_reason() -> String:
	if not paused(): return ""
	if GameState.story.get("route") == "dark": return "잿빛 날개 편에 선 뒤로 폭포 아래 모임에는 나갈 수 없다."
	if GameState.quests.active.has("m5a"): return "봉우리에 한여름 눈이 내린 뒤로 달맞이 모임이 멈춰 있다."
	return "폭포에서 두 마을이 부딪친 뒤로 달맞이 모임이 멈춰 있다."


## 폭포 위로 올라가 본 적이 있는가 (모임에 한 번 나가면 열린다)
static func invited_up() -> bool:
	return GameState.story.events.has("ev_gathering")


## 구름마루를 아는가 (폭포에서 처음 마주친 뒤)
static func knows_cloudtop() -> bool: return GameState.story.get("events", []).has("ev_falls")


## 모임 때 이 용이 앉는 자리 (구름 폭포의 큰 칸 좌표). 이번 모임에 나오지 않는 용이면 null
static func spot_of(name: String):
	var p = _phases().get(phase())
	return p.spots.get(name) if p else null


## 모임에서 이 용이 하는 일 (일지 · 인사 앞 한 줄)
static func doing_of(name: String) -> String:
	var d: Dictionary = _phases().get(phase(), {}).get("doing", {})
	return d.get(name, d.get("default", "달 밝은 밤의 모임에 나와 있다"))


# ---------- 모임 자리에서: 장면 한 번 · 주고받는 말 ----------

## 매 프레임 (Routine 이 부른다. 대화나 장면이 떠 있는 동안은 세상과 함께 멈춰 있다)
static func update(dt: float) -> void:
	if GameState.map_id != GATHER_MAP or not is_gather_now() or GameState.raid.active:
		_talk = null
		return
	if _talk:   # 주고받는 중: 2.6초마다 한 줄씩 말풍선으로
		_talk.t -= dt
		if _talk.t > 0: return
		if _talk.i >= _talk.lines.size():
			_talk = null
			return
		var line: Array = _talk.lines[_talk.i]
		_talk.i += 1
		var who = _here(line[0])
		if who: who.say(line[1])
		_talk.t = 2.6
		return
	if _scene(): return
	_talk_wait -= dt
	if _talk_wait > 0: return
	_talk_wait = Util.rand_range(25, 40)
	var p = _phases().get(phase())
	if not p: return
	var options: Array = p.get("talk", []).filter(func(c): return _said.get(c.id) != GameState.day \
		and c.lines.all(func(l): return _here(l[0]) != null))
	if options.is_empty(): return
	var c: Dictionary = options.pick_random()
	_said[c.id] = GameState.day
	_talk = { lines = c.lines, i = 0, t = 0.0 }


## 이 단계 모임에 처음 온 밤, 짧은 장면을 한 번 튼다 (본 단계는 story.gatherings). 틀었으면 true
static func _scene() -> bool:
	var ph := phase()
	var sc = _phases().get(ph, {}).get("scene")
	if not sc or GameState.story.get("gatherings", []).has(ph): return false
	if GameState.isDialogueOpen or Cutscene.busy() or GameState.activity or Ending.playing or Combat.in_fight(): return false
	if GameState.bannerUntil and GameState.play_time < GameState.bannerUntil: return false
	# 말할 이들이 다 와서 자리에 앉아 있어야 한다 (걸어 들어오는 중이면 기다린다)
	for l in sc.lines:
		if l.who != "나" and _here(l.who, true) == null: return false
	Chronicle.play_scene(sc.title, sc.lines, func():
		if not GameState.story.has("gatherings"): GameState.story.gatherings = []
		if not GameState.story.gatherings.has(ph): GameState.story.gatherings.append(ph)
		Save.save_game())
	return true


## 모임 자리에 와 있는 그 용 (내 곁 가까이). settled: 걸어오는 중이 아니라 자리에 앉아 있어야
static func _here(nm: String, settled := false):
	for n in GameState.entities.npcs:
		if n.config.get("name") != nm or n.remove or n.down_timer > 0: continue
		if settled and n.walk_to: continue
		if Util.dist(n, GameState.player) < 1100: return n
	return null
