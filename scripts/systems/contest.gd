class_name Contest
## 달맞이 모임의 겨루기. 스무 해 전까지 두 마을은 모임 밤마다 대표끼리 한 판씩 겨뤘다 (설정집 "달맞이 모임의 겨루기").
## 첫 모임 뒤로 모임이 서는 밤마다 한 판: 폭포 경주(비류) → 낚시 겨루기(세이란) → 겨루기(유안)를 돌아가며.
## 구름마루의 맞수는 지면 다음 모임까지 연습해서 한 판 더 세진다. 불가의 용들이 제 마을 쪽을 응원한다.
## 한 밤에 한 판. 이기든 지든 다음 모임에 또 선다.
##   GameState.story.contest = { day (마지막으로 겨룬 날), wins, losses, level: { RACE, FISH, DUEL } }
##   낚시 겨루기는 물고기를 덮쳐야 해서 activity 를 쓰지 않는다: Contest.fishing = { t, target } (이 판 동안만)

const KINDS := ["RACE", "FISH", "DUEL"]
const RIVAL := { "RACE": "Biryu", "FISH": "Seiran", "DUEL": "Yuan" }
const NAME := { "RACE": "폭포 경주", "FISH": "낚시 겨루기", "DUEL": "겨루기" }
const CLOUDTOP := ["Riun", "Seiran", "Yuan", "Haru", "Biryu", "On"]
const PRIZE := [40, 60, 90]

## 폭포 길: 모임 자리 앞에서 떠나 폭포 위를 돌아 한 바퀴. 비류는 폭포 밑 소(웅덩이)를 세 바퀴 돈다
const FALLS_COURSE := { map = "FALLS", title = "폭포 경주",
	rings = [[912, 700], [1100, 330], [1392, 180], [1750, 420], [1700, 900], [1350, 1300], [800, 1380], [330, 1150], [300, 620], [600, 330]],
	center = Vector2(1392, 528), swim_r = 180.0 }
const RACE_TIMES := [22.0, 16.5, 12.5]   # 판마다 비류가 소를 세 바퀴 도는 시간
const FISH_TIMES := [75.0, 55.0, 40.0]   # 판마다 세이란이 큰 고기를 건지는 시간
const DUEL_HP := [1.0, 1.2, 1.4]         # 판마다 유안의 기력

const LINES := {
	"RACE": { offer = "옛날엔 모임 날마다 두 마을이 한 판씩 겨뤘대. 오늘 밤은 폭포 경주다. 고리 열 개를 돌아 모임 자리 앞으로 먼저 오는 쪽이 이긴다. 나는 폭포 밑 소를 세 바퀴 돈다.",
		win = "폭포 물살은 내 편이지! 다음 모임에 또 와.", lose = "…또 졌네. 다음 모임까지 폭포 밑에서 살 거다. 두고 봐." },
	"FISH": { offer = "모임 날엔 두 마을이 한 판씩 겨루는 게 옛날 법이었대. 오늘 밤은 낚시야. 폭포 밑 소에서 큰 고기를 먼저 건지는 쪽이 이겨. 나는 물을 읽고, 너는 하늘에서 내리꽂고. …공평하지?",
		win = "물이 여기라고 하더라. 반은 운이야. 나머지 반은… 비밀.", lose = "하늘에서 보면 그렇게 훤해? …다음엔 나도 물을 더 깊이 읽어 볼게." },
	"DUEL": { offer = "모임 날엔 대표끼리 한 판 겨루는 게 예전 법도였다. 다치게 하지는 않는다. 먼저 기력이 다하는 쪽이 진다.",
		win = "…발이 아직 무겁다. 스승님이라면 그렇게 말씀하셨을 거다.", lose = "졌다. 다음 모임까지 창 대신 발부터 다시 익히겠다." },
}
const CHEER_WEST := ["힘내!", "조금만 더!", "그렇지, 그렇게!", "우리 마을 체면이 걸렸다!"]
const CHEER_CLOUD := ["아직 안 끝났어!", "물살을 타!", "구름마루 체면 좀 살려 줘!"]

static var fishing = null        # 낚시 겨루기 중: { t, target, npc }
static var live := ""            # 지금 벌어지는 겨루기 (응원은 이때만)
static var _told_day := -1       # 오늘 밤 겨루기를 알렸나
static var _cheer := 4.0


static func _c() -> Dictionary:
	if not GameState.story.has("contest"): GameState.story.contest = { day = -1, wins = 0, losses = 0, level = { RACE = 0, FISH = 0, DUEL = 0 } }
	return GameState.story.contest


## 오늘 밤의 겨루기 (모임 날마다 돌아간다)
static func kind_tonight() -> String:
	return KINDS[int(GameState.day / Gathering.GATHER_EVERY) % KINDS.size()]


static func level_of(kind: String) -> int: return int(_c().level.get(kind, 0))


## 지금 겨룰 수 있나: 모임이 선 폭포, 첫 모임 밤은 아니고, 오늘 밤 아직 안 겨뤘다
static func open_now() -> bool:
	if GameState.map_id != Gathering.GATHER_MAP or not Gathering.is_gather_now(): return false
	if GameState.story.get("eventDay", {}).get("ev_gathering", -1) == GameState.day: return false   # 첫 모임 밤은 모임만
	if not GameState.story.get("events", []).has("ev_gathering"): return false
	if kind_tonight() == "RACE" and Race.resting(): return false   # 비류가 다리를 다쳐 쉬는 밤
	return int(_c().day) != GameState.day and fishing == null and not GameState.activity


## 맞수의 [함께하자] 메뉴에 붙는 한 줄. 오늘 밤 그 용이 맞수가 아니면 null
static func menu_option(npc):
	var kind := kind_tonight()
	if npc.config.get("name") != RIVAL[kind] or not open_now(): return null
	return { label = "🏆 모임 겨루기: %s" % NAME[kind], on_select = func(): _offer(npc, kind) }


static func _offer(npc, kind: String) -> void:
	NpcActions.show(npc, LINES[kind].offer, [
		{ label = "좋아, 한 판 붙자.", on_select = func(): start(npc, kind) },
		{ label = "다음에.", on_select = func(): NpcActions.open_hub(npc) },
	])


static func start(npc, kind: String) -> void:
	NpcActions.close()
	var lv := mini(level_of(kind), 2)
	var p = GameState.player
	live = kind
	_cheer = 1.5
	match kind:
		"RACE":
			Race.start(npc, FALLS_COURSE, RACE_TIMES[lv], func(win: bool, t: float): _result(npc, kind, win, "%.1f초" % t if win else ""))
		"FISH":
			fishing = { t = 0.0, target = FISH_TIMES[lv], npc = npc }   # 세이란은 불가에 앉은 채 물을 읽는다
			Hud.pop("낚시 겨루기! 폭포 밑 소에서 큰 고기를 세이란보다 먼저 건지자. 큰 그림자는 힘을 다 모았다가 덮친다.", "🎣")
		"DUEL":
			npc.x = p.x + 200; npc.y = p.y; npc.walk_to = null
			Story.start_drill(npc, { type = "DUEL", hp = (420 + p.level * 14) * DUEL_HP[lv] }, { label = "모임 겨루기: 유안", who = "유안", element = "WATER",
				onEnd = func(win: bool): _result(npc, kind, win, "") })
	Sfx.play("warn")


## 물고기를 잡았다 (DiveFish.caught). 낚시 겨루기 중에 큰 고기면 이겼다
static func on_catch(kind: Dictionary) -> void:
	if fishing == null or not kind.get("big"): return
	var f: Dictionary = fishing
	fishing = null
	Hud.current.set_boss_bar(null)
	_result(f.npc, "FISH", true, kind.name)


## 모임 자리에서 매 프레임 (Gathering.update 가 부른다): 오늘 밤 겨루기를 알리고 · 낚시 겨루기의 시계 · 응원
static func update(dt: float) -> void:
	if _told_day != GameState.day and open_now() and not GameState.isDialogueOpen:
		_told_day = GameState.day
		var kind := kind_tonight()
		Hud.pop("오늘 밤 모임 겨루기는 [%s]. %s에게 말을 걸면 나설 수 있다." % [NAME[kind], Names.npc(RIVAL[kind])], "🏆")
	if fishing != null:
		var f: Dictionary = fishing
		f.t += dt
		Hud.current.set_boss_bar("낚시 겨루기 · 세이란이 물을 읽는 중", 1.0 - f.t / f.target)
		if GameState.map_id != Gathering.GATHER_MAP:   # 폭포를 떠났다
			fishing = null
			Hud.current.set_boss_bar(null)
			_result(f.npc, "FISH", false, "")
		elif f.t >= f.target:
			fishing = null
			Hud.current.set_boss_bar(null)
			Particles.burst(f.npc.x, f.npc.y - 20, "#bfe9ff", 1, 16)
			_result(f.npc, "FISH", false, "")
	if live != "" and GameState.map_id == Gathering.GATHER_MAP:
		_cheer -= dt
		if _cheer <= 0:
			_cheer = Util.rand_range(3.5, 6.0)
			_shout()


## 불가의 용 하나가 제 마을 쪽을 응원한다
static func _shout() -> void:
	var pool := []
	for n in GameState.entities.npcs:
		if n.remove or not n.config.get("fixed") or Util.dist(n, GameState.player) > 1400: continue
		if n == _rival_now(): continue   # 맞수는 응원하지 않는다
		pool.append(n)
	if pool.is_empty(): return
	var n = pool.pick_random()
	n.say((CHEER_CLOUD if CLOUDTOP.has(n.config.get("name")) else CHEER_WEST).pick_random())


static func _rival_now():
	if fishing != null: return fishing.npc
	var a = GameState.activity
	return a.get("npc") if a else null


static func _result(npc, kind: String, win: bool, detail: String) -> void:
	live = ""
	var c := _c()
	c.day = GameState.day
	var lv := mini(level_of(kind), 2)
	var p = GameState.player
	if win:
		c.wins = int(c.wins) + 1
		c.winDay = GameState.day   # 마을 용들의 소식
		c.level[kind] = level_of(kind) + 1   # 진 쪽은 다음 모임까지 연습한다
		p.gold += PRIZE[lv]
		var got := NpcActions.add_relation(npc, 6)
		npc.say(LINES[kind].lose)
		Vfx.spawn_effect("RING", p.x, p.y, { size = 1.4 })
		Hud.pop("모임 겨루기에서 이겼다!%s (%dG · %s)" % [" " + detail if detail != "" else "", PRIZE[lv], NpcActions.gain_note(got)], "🏆")
		if int(c.wins) == 1:   # 처음 이긴 밤: 굴에 걸어 둘 기념품
			Hud.pop("리운이 두 마을 깃발을 건넸다. \"스무 해 만의 대표구려. 굴에 걸어 두시오.\"", "🏳️")
			Den.give_furniture("KEEP_FLAG")
	else:
		c.losses = int(c.losses) + 1
		NpcActions.add_relation(npc, 1)
		npc.say(LINES[kind].win)
		Hud.pop("모임 겨루기에서 졌다. 다음 모임에 또 선다.", "🏆")
	Save.save_game()


## 일지 [기록]의 한 줄
static func record_line() -> Array:
	var c = GameState.story.get("contest")
	if c == null: return ["달맞이 모임 겨루기", "아직 안 나갔다", true]
	return ["달맞이 모임 겨루기", "%d승 %d패" % [int(c.wins), int(c.losses)]]


## 추적창이 빈 시간에 짚는 한 줄 (Quests._pastime): 오늘 밤 모임 겨루기. 모임 날이 아니거나 이미 겨뤘으면 null
static func pastime():
	if tonight_note() == "" or int(_c().day) == GameState.day: return null
	if kind_tonight() == "RACE" and Race.resting(): return null   # 비류가 쉬는 밤
	var kind := kind_tonight()
	var rival := Names.npc(RIVAL[kind])
	return { who = null, main = false, title = "오늘 밤 모임 겨루기: %s" % NAME[kind],
		goal = "지금 구름 폭포 아래에서 모임이 열리고 있다. %s에게 말을 걸면 나설 수 있다" % rival if Gathering.is_gather_now() \
			else "해가 지면 구름 폭포 아래로. 오늘 밤 맞수는 %s" % rival }


## 일지 [마을] 달맞이 모임 줄에 덧붙는 말 (모임 날, 첫 모임 뒤로)
static func tonight_note() -> String:
	if not GameState.story.get("events", []).has("ev_gathering") or not Gathering.is_gather_day(): return ""
	if GameState.story.get("eventDay", {}).get("ev_gathering", -1) == GameState.day: return ""   # 첫 모임 밤은 모임만
	if int(_c().day) == GameState.day: return " 오늘 밤 겨루기는 끝났다."
	if kind_tonight() == "RACE" and Race.resting(): return " 오늘 밤 겨루기는 쉰다. 비류가 다리를 다쳤다."
	var kind := kind_tonight()
	return " 오늘 밤 겨루기는 [%s], 맞수는 %s." % [NAME[kind], Names.npc(RIVAL[kind])]
