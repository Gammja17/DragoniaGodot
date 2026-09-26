class_name Quests
## 2D판 systems/quests.js. 퀘스트 하나는 여러 '대목'으로 이어진다. 표는 data/quests.json.
##
##   숫자 하나를 채우면 끝나는 부탁은 퀘스트가 아니다 (그건 마을 게시판의 잡일). 퀘스트는 대목을 하나씩 넘기며
##   이야기가 굴러가는 것만 남긴다. 대목을 끝내면 그 자리에서 장면이 재생되고(step.scene) 다음 대목이 열린다.
##
## GameState.quests = {
##   active:  { [퀘스트 id]: { step: 지금 몇 번째 대목, n: 그 대목의 진행도 } }
##   done:    [끝낸 id]
##   tracked: 추적창에 띄울 id | null
##   choices: { [퀘스트 id]: 고른 선택지 id }   — 나중 대사·사건이 이걸 읽는다
## }

## 한 번에 떠안을 수 있는 퀘스트 수. 이야기 하나에 집중하게 하는 문턱
const MAX_ACTIVE := 2

## 퀘스트 상태가 바뀔 때 (추적창·로그 갱신용). 추적창을 옮기면 거기서 끼운다
static var on_change := func(): pass
## 대목을 끝내며 세상이 바뀌는 일 (st.flag). Story 가 받아서 처리한다
static var on_flag := func(_f): pass
## 게시판 잡일·스승의 하루 일과도 같은 통지를 듣는다 (각자 시작할 때 끼워 넣는다)
static var chore_notify := func(_t, _w): pass
static var training := {}


## 끼워 넣은 훅을 걷는다. 다른 스크립트의 람다를 쥔 채로 엔진이 닫히면 그 스크립트가 먼저 내려가 튕긴다 (main 이 나갈 때 부른다)
static func reset_hooks() -> void:
	on_change = func(): pass
	on_flag = func(_f): pass
	chore_notify = func(_t, _w): pass
	training = { notify = func(_t, _w): pass, line = func(): return null, row = func(): return null, marker = func(_n): return null }


static func _static_init() -> void:
	reset_hooks()


static func all() -> Array: return Data.get_module("quests").QUESTS
static func by_id(id: String):
	for q in all():
		if q.id == id: return q
	return null


static func changed() -> void: on_change.call()
static func raise_flag(flag: String) -> void: on_flag.call(flag)


## 선택의 대가로 그 용과의 사이가 오르내린다 (하루 상한을 따지지 않는다). 알림으로 보여 준다
static func shift_relation(nm: String, by: float) -> void:
	var n = World.any_npc(nm)
	if n == null or by == 0: return
	NpcActions.add_relation(n, by, false)
	var who := Util.josa(Names.npc(nm), "과", "와")
	Hud.pop("%s 조금 가까워졌다." % who if by > 0 else "%s 사이가 조금 멀어졌다." % who, "💞" if by > 0 else "💢")


## 고른 선택지에 딸린 대가 (퀘스트 선택지): relation { 이름: 얼마 } · clue · meat · flag
static func apply_pick(o: Dictionary) -> void:
	for nm in o.get("relation", {}): shift_relation(nm, float(o.relation[nm]))
	if o.get("clue"): add_clue(o.clue)
	if o.get("meat"): GameState.player.inventory.meat += int(o.meat)
	if o.get("flag"): raise_flag(o.flag)


# ---------- 대목 ----------

## 대목 목록. steps 가 없는 옛 모양(goal 하나)도 그대로 돈다
static func steps(q: Dictionary) -> Array: return q.steps if q.get("steps") else [q]
static func _entry(q: Dictionary): return GameState.quests.active.get(q.id)
static func step_index(q: Dictionary) -> int:
	var e = _entry(q)
	return int(e.step) if e else 0
## 지금 해야 할 대목 (다 끝냈으면 null)
static func cur_step(q: Dictionary):
	var s := steps(q)
	var i := step_index(q)
	return s[i] if i < s.size() else null
## 대목을 다 끝내서 보고만 남은 상태
static func is_complete(q: Dictionary) -> bool: return _entry(q) != null and step_index(q) >= steps(q).size()
## 이 보스를 잡으라는 대목이 지금 걸려 있는가
static func hunting(boss_id: String) -> bool:
	for q in active_quests():
		var st = cur_step(q)
		if st and st.goal.get("type") == "boss" and st.goal.get("id") == boss_id: return true
	return false


static func active_quests() -> Array: return all().filter(func(q): return GameState.quests.active.has(q.id))

static func _goal_count(g) -> int: return int(g.count) if g and g.get("count") else 1
## 가방을 세는 목표 — 건네주는 것은 진행도가 아니라 지금 가진 수를 본다
static func _from_bag(g) -> bool: return g.type == "collect" or g.type == "bring"


## 지금 대목의 진행도
static func progress(q: Dictionary) -> int:
	var st = cur_step(q)
	if not st: return 0
	if _from_bag(st.goal): return mini(_goal_count(st.goal), GameState.player.inventory.meat)
	var e = _entry(q)
	return mini(_goal_count(st.goal), int(e.n) if e else 0)
static func step_total(q: Dictionary) -> int:
	var st = cur_step(q)
	return _goal_count(st.goal) if st else 1
static func _step_filled(q: Dictionary) -> bool: return progress(q) >= step_total(q)

## 보고하러 갈 용. 따로 적지 않으면 의뢰인이다
static func turn_in_npc(q: Dictionary) -> String: return q.turnIn if q.get("turnIn") else q.giver


static func _hint_or_goal(q: Dictionary) -> String:
	var st = cur_step(q)
	return GameInput.words(st.hint) if st and st.get("hint") else step_goal_text(q)


# ---------- 목표를 한 줄로 ----------

## 목표 한 줄 ("슬라임 3마리 처치" 처럼). 게시판 잡일도 이걸 쓴다
static func goal_text(g: Dictionary) -> String:
	var n := _goal_count(g)
	match g.type:
		"kill":
			var nm: String = "인간 사냥꾼" if g.target == "HUNTER" else Data.get_module("enemies").ENEMIES.get(g.target, {}).get("name", g.target)
			return "%s %d%s 처치" % [nm, n, "명" if g.target == "HUNTER" else "마리"]   # 사람은 '명' (습격 알림과 같게)
		"killAny": return "아무 적이나 %d마리 처치" % n
		"elite": return "금빛 정예 %d마리 처치" % n
		"boss": return "%s 처치" % Data.get_module("enemies").BOSSES[g.id].name
		"stage": return "[%s] 단계까지 자라기" % Data.get_module("elements").STAGES[int(g.index)].name
		"collect": return "고기 %d개 모으기" % n
		"bring": return "%s에게 고기 %d개 건네기" % [Names.npc(g.target), n]
		"talk": return "%s에게 말 걸기" % Names.npc(g.target)
		"tour": return "마을 둘러보기"
		"event": return "그 자리에 가 있기"
		"scene": return "이어지는 이야기"
		"visit": return "%s 방문" % Names.map(g.target)
		"sleep": return "%d밤 자고 나기" % n if n > 1 else "하룻밤 자고 나기"
		"hatch": return "알 %d개 부화" % n
		"raid": return "마을 습격 %d회 격퇴" % n
		"spar": return "대련 %d회 승리" % n
		"tag": return "술래잡기 %d회 승리" % n
		"upgrade": return "대장간 단련 %d회" % n
		"chest": return "보물상자 %d개 개봉" % n
		"delve": return "옛 굴 지하 %d층까지 내려가기" % n
		"fish": return "큰 놈 낚기" if g.get("target") == "BIG" else "물고기 %d마리 낚기" % n
	return "목표"


## 지금 대목의 목표 한 줄
static func step_goal_text(q: Dictionary) -> String:
	var st = cur_step(q)
	return goal_text(st.goal) if st else "보고하러 간다"


## 보상 한 줄. rel_got: 보고할 때 실제로 오른 호감 (-1 이면 아직 모른다). 하루 상한에 걸려 안 올랐으면 쓰지 않는다
static func reward_text(q: Dictionary, rel_got := -1.0) -> String:
	var r: Dictionary = q.reward if q.get("reward") else {}
	var parts := []
	if r.get("xp"): parts.append("경험치 %d" % r.xp)
	if r.get("gold"): parts.append("%dG" % r.gold)
	if r.get("meat"): parts.append("고기 %d" % r.meat)
	if r.get("relation") and rel_got != 0: parts.append("호감 상승")
	if r.get("furniture"): parts.append("살림살이: %s" % Den.furniture()[r.furniture].name)
	return " · ".join(parts) if not parts.is_empty() else "-"


# ---------- 장면 대기줄 ----------
# 대목을 끝낸 자리가 싸움 한복판일 수 있다. 장면은 대기줄에 넣어 두고,
# Chronicle 이 조용해진 틈에 꺼내 재생한다

static func _queue_scene(title: String, lines: Array, place = null) -> void:
	GameState.questScenes.append({ title = title, lines = lines, place = place })


## 재생할 장면이 있으면 하나 꺼낸다 (Chronicle 이 부른다)
static func take_scene():
	return GameState.questScenes.pop_front() if not GameState.questScenes.is_empty() else null


# ---------- 대목 넘기기 ----------

## 지금 대목을 끝내고 다음으로 넘긴다. quiet: 장면을 부르는 쪽이 직접 재생한다 (대화 중에 끝낸 대목)
static func complete_step(q: Dictionary, quiet := false):
	var e = _entry(q)
	if not e: return null
	var s := steps(q)
	if e.step >= s.size(): return null
	var st: Dictionary = s[e.step]
	e.step += 1
	e.n = 0
	if not quiet and st.get("scene"): _queue_scene(q.title, st.scene, st.get("place"))
	if st.get("flag"): on_flag.call(st.flag)
	if st.get("toast"): Hud.pop(st.toast, st.icon if st.get("icon") else "📜")
	_catch_up(q)   # 배너는 이미 이룬 대목을 건너뛴 뒤의 할 일을 알린다
	if is_complete(q) and q.get("noReport"):   # 보고할 것 없이 끝나는 이야기 (첫 밤: 자고 나면 아침 장면이 이어 준다)
		GameState.quests.active.erase(q.id)
		GameState.quests.done.append(q.id)
		if GameState.quests.tracked == q.id: GameState.quests.tracked = null
		on_change.call()
		return st
	if is_complete(q): Hud.quest_banner("다음 할 일", q.title, "%s에게 돌아간다%s" % [Names.npc(turn_in_npc(q)), _where_is(turn_in_npc(q))], q)
	else: Hud.quest_banner("다음 할 일", q.title, _hint_or_goal(q), q)
	on_change.call()
	return st


## 이미 이룬 목표(잡아 둔 보스, 다 자란 몸, 가 본 곳, 이미 본 사건)는 받자마자 넘긴다.
## 사건은 한 번만 일어나서, 받기 전에 먼저 봐 버리면 그 대목이 영영 안 넘어갔다 (달맞이 모임 · 불탄 도시)
static func _catch_up(q: Dictionary) -> void:
	for guard in steps(q).size():
		var st = cur_step(q)
		if not st: return
		var g: Dictionary = st.goal
		var already: bool = (g.type == "boss" and GameState.bossesDefeated.get(g.id, false)) \
			or (g.type == "stage" and GameState.player.stage_index >= g.index) \
			or (g.type == "visit" and GameState.visited.has(g.target)) \
			or (g.type == "event" and GameState.story.events.has(g.target)) 			or g.type == "scene"   # 이어지는 장면만 있는 대목: 앞 대목이 끝나면 곧바로 흐른다
		if not already: return
		var e = _entry(q)
		e.step += 1
		e.n = 0
		if st.get("scene"): _queue_scene(q.title, st.scene, st.get("place"))


## 게임 곳곳에서 부른다. 지금 대목의 목표와 맞으면 진행도가 오른다.
##   notify('kill', 'SLIME') / ('stage', 1) / ('boss', 'MORGATH') / ('visit', 'DESERT') / ('talk', 'Gron') / ('sleep') …
## 건네주는 목표(collect·bring)는 여기가 아니라 hand_over() 로 끝낸다
static func notify(type: String, target = null) -> void:
	for q in active_quests():
		var st = cur_step(q)
		if not st or _from_bag(st.goal): continue
		var g: Dictionary = st.goal
		if g.type != type: continue
		if (type == "kill" or type == "visit" or type == "talk" or type == "event" or type == "fish") and g.get("target") != target: continue
		if type == "boss" and g.id != target: continue
		if type == "stage" and target < g.index: continue
		var e = _entry(q)
		# 'delve' 는 쌓이는 게 아니라 "가장 깊이 내려간 층"이다
		if type == "delve": e.n = maxi(int(e.n), int(target))
		else: e.n = int(e.n) + 1
		if _step_filled(q): complete_step(q)
	chore_notify.call(type, target)
	training.notify.call(type, target)
	on_change.call()


## 지금 대목 가운데 이 목표를 기다리는 것이 있나 (그 대목일 때만 달리 벌어지는 일: 새벽 호수의 '큰 놈')
static func wants(type: String, target) -> bool:
	for q in active_quests():
		var st = cur_step(q)
		if st and st.goal.type == type and st.goal.get("target") == target: return true
	return false


# ---------- 말을 걸어서 넘기는 대목 ----------

## 이 용에게 물어보려던 대목이 있으면 그 퀘스트
static func talk_quest_for(npc):
	var nm = npc.config.get("name", "")
	for q in active_quests():
		var st = cur_step(q)
		if st and st.goal.type == "talk" and st.goal.target == nm: return q
	return null


## 이 용에게 건네주려던 대목이 있으면 그 퀘스트
static func bring_quest_for(npc):
	var nm = npc.config.get("name", "")
	for q in active_quests():
		var st = cur_step(q)
		if st and st.goal.type == "bring" and st.goal.target == nm: return q
	return null


## 고기를 건네고 대목을 넘긴다. 모자라면 false
static func hand_over(q: Dictionary) -> bool:
	var st = cur_step(q)
	if not st or not _from_bag(st.goal) or not _step_filled(q): return false
	GameState.player.inventory.meat -= _goal_count(st.goal)
	return true


# ---------- 받고, 보고하고 ----------

## 지금 이 NPC가 건넬 수 있는 부탁. 없으면 null
static func offer_for(npc):
	var cand = _find_offer(npc)
	if not cand: return null
	if cand.act == "main" and resting(): return null   # 큰 대목을 마친 날은 다음 본 이야기를 아침으로 미룬다
	if active_quests().size() >= MAX_ACTIVE: return null
	# 본 이야기가 굴러가는 동안 곁가지는 기다린다. 다섯 용이 한꺼번에 부탁하면 정신이 없다.
	# 다만 본 이야기가 '자라기'(레벨·승급)를 기다리는 동안은 곁가지를 받는다 — 그 시간에 할 이야기가 없었다
	if cand.act != "main" and active_quests().any(func(q):
		var st = cur_step(q)
		return q.act == "main" and not (st and st.goal.type == "stage")): return null
	return cand


## 문턱에 걸려 아직 안 꺼내는 부탁 (NPC가 "그 일이 먼저지" 하고 한마디 한다). 쉬는 날 미뤄 둔 것은 rest_offer 가 따로 말한다
static func held_offer(npc):
	if offer_for(npc) or rest_offer(npc): return null
	return _find_offer(npc)


## 큰 대목(보스를 잡았거나 장이 끝났다)을 보고한 날은 생활할 틈으로 둔다. 다음 본 이야기는 다음 날 새벽부터 꺼낸다 (자고 일어나면 바로)
static func resting() -> bool:
	var until = GameState.story.get("restUntil")
	if until == null: return false
	return GameState.day < int(until) or (GameState.day == int(until) and GameState.dayTime < NightEvents.DAWN)


## 본 이야기가 내일 아침을 기다리는가: 큰 대목을 마친 날, 첫 사냥을 마치고 스승을 소개받기 전(자고 일어나면 1장 아침 장면)
static func waits_for_morning() -> bool:
	return resting() or (GameState.quests.done.has("m1") and not GameState.story.get("scenes", []).has("ch1"))


## 쉬는 날이라 내일 아침으로 미뤄 둔 본 이야기. 없으면 null
static func rest_offer(npc):
	var cand = _find_offer(npc)
	return cand if cand and cand.act == "main" and resting() else null


static func _has_boss(q: Dictionary) -> bool:
	return steps(q).any(func(st): return st.get("goal", {}).get("type") == "boss")


static func _ready_quest(q: Dictionary) -> bool:
	var Q: Dictionary = GameState.quests
	return not Q.active.has(q.id) and not Q.done.has(q.id) and (not q.get("requires") or Q.done.has(q.requires)) \
		and (not q.get("needs") or q.needs.call(GameState))


static func _find_offer(npc):
	for q in all():
		# 스승의 부탁은 수련 진도를 따라 열린다
		if not q.get("auto") and q.giver == npc.config.get("name") and _ready_quest(q): return q
	return null


## 그 용이 지금 어디 있는지 (' (지금 수련장)') · 일과를 모르는 용이면 빈 문자열
static func _where_is(nm: String) -> String:
	var plan = Routine.plan_for(nm)
	return " (지금 %s)" % plan.mapName if plan else ""


## 그 용을 어디서 찾을지 한 줄. 일과를 아는 용은 지금 자리와 하는 일, 일과가 없는 용은 사는 곳
## (뿌리골의 모스 · 바윗골의 가람을 "마을 어딘가에 있다"고 하던 것)
static func whereabouts(nm: String) -> String:
	var plan = Routine.plan_for(nm)
	if plan: return "지금 %s에 있다 · %s" % [plan.mapName, plan.doing]
	var home = Guide.home_of(nm)
	return "%s에 있다" % Names.map(home.map) if home else "마을 어딘가에 있다"


## 이 대목 앞에 끝내야 할 부탁(대목의 after) 가운데 아직 안 끝낸 첫 것. 없으면 null
## (고룡이 되는 대목: 뿌리골 · 바윗골 · 구름마루가 건네는 속성 없이는 빈 둥지가 소용없다)
static func pending_before(q):
	if not q or is_complete(q): return null
	for id in cur_step(q).get("after", []):
		if not GameState.quests.done.has(id): return by_id(id)
	return null


## 추적창의 📍 줄: 이 대목에서 찾아가야 할 용이 지금 어디 있는지. 먼저 끝낼 부탁이 남았으면 그쪽 (화살표와 같이)
static func _where_line(q: Dictionary) -> String:
	var who = null
	var pre = pending_before(q)
	if pre and not GameState.quests.active.has(pre.id): who = pre.giver
	else:
		if pre: q = pre
		if is_complete(q): who = turn_in_npc(q)
		else:
			var g: Dictionary = cur_step(q).goal
			if g.type == "talk" or g.type == "bring": who = g.target
	if not who: return ""
	var plan = Routine.plan_for(who)
	if plan: return "%s · %s" % [Names.npc(who), plan.mapName]
	var home = Guide.home_of(who)   # 일과가 없는 용은 사는 곳
	return "%s · %s" % [Names.npc(who), Names.map(home.map)] if home else ""


## 의뢰인 이름과, 일과를 아는 용이라면 지금 어디 있는지까지
static func giver_line(nm: String) -> String:
	var plan = Routine.plan_for(nm)
	return "%s (지금 %s)" % [Names.npc(nm), plan.mapName] if plan else Names.npc(nm)


## 이 NPC가 준 진행 중인 퀘스트 (대화창에 진행도를 한 줄 깔아 준다)
static func running_for(npc):
	for q in active_quests():
		if q.giver == npc.config.get("name") and not is_complete(q): return q
	return null


## 이 NPC에게 보고할 수 있는 퀘스트
static func reportable_for(npc):
	for q in active_quests():
		if is_complete(q) and turn_in_npc(q) == npc.config.get("name"): return q
	return null


## 맡은 일이 없을 때 "다음에 할 만한 일". { who: 말을 걸 용 | null, title, goal, main?, place? }
static func suggestion():
	# 본 이야기가 내일 아침을 기다리는 날은 그렇다고 말한다 (엉뚱한 부탁이나 할 말 없는 엘더를 가리키던 것)
	if waits_for_morning():
		var side_now := all().filter(func(q): return not q.get("auto") and q.act != "main" and _ready_quest(q)) if resting() else []
		var pass_time = _pastime(false) if side_now.is_empty() else null
		return { who = null, main = false, title = "오늘은 여기까지",
			goal = ("큰일을 치렀다. 다음 이야기는 내일 아침에 이어진다. 오늘은 마을 용들과 어울리거나 굴에서 푹 쉬자." if resting()
				else "오늘 할 일은 끝났다. 마을 서쪽 끝 내 굴에서 자면 내일 이야기가 이어진다.")
				+ (" %s에게 할 말이 있는 눈치다." % Names.npc(side_now[0].giver) if not side_now.is_empty() else "")
				+ (" 할 거리: %s." % pass_time.title if pass_time else "") }
	# 본 이야기는 누구에게 가면 되는지 바로 알려 주고, 곁가지 부탁은 "누군가 할 말이 있는 눈치" 정도로만 귀띔한다
	for q in all():
		if not q.get("auto") and q.act == "main" and _ready_quest(q):
			return { who = q.giver, main = true, title = "%s에게 말을 걸어 보자" % Names.npc(q.giver), goal = whereabouts(q.giver) }
	# 돌아다니다 저절로 열리는 본 이야기. 어디로 가야 열리는지는 lead 가 귀띔한다
	for q in all():
		if q.get("auto") and q.act == "main" and q.get("lead") and _ready_quest(q):
			return { who = null, main = true, place = q.lead.map, title = q.lead.text, goal = "%s 쪽으로 가 본다" % Names.map(q.lead.map) }
	# 본 이야기가 다음 승급을 기다린다 (2장 뒤 성체 시험: 그 뒤에야 누리가 사라진다).
	# 레벨이 차도 알림 한 번뿐이라, 추적창은 곁가지 부탁만 가리키고 다음 이야기가 어디서 이어지는지는 말하지 않았다
	var trial = Story.next_trial()
	if trial and not active_quests().any(func(q): return q.act == "main") and not (trial.get("needs") and not trial.needs.call(GameState)):
		var st: Dictionary = Story._stages()[int(trial.stage)]
		if GameState.player.level < int(st.minLevel):
			# 숲에서 사냥만 하며 며칠을 보내던 것: 지금 할 수 있는 일을 짚고, 그 일로도 레벨이 오른다고 붙인다
			var pass_time = _pastime()
			if pass_time:
				pass_time.kind = "trial"
				pass_time.goal = "%s. [%s]까지 레벨 %d / %d, 이 일로도 레벨이 오른다" % [pass_time.goal, st.name, GameState.player.level, st.minLevel]
				return pass_time
			return { who = null, main = false, kind = "trial", title = "[%s]까지 자라기 (레벨 %d / %d)" % [st.name, GameState.player.level, st.minLevel],
				goal = "레벨 %d부터 스승 카이론에게 [승급 시험]을 청할 수 있다. 다음 이야기는 그 뒤에 이어진다. 숲길에서 싸우거나, 오늘의 수련 · 마을 용들의 부탁을 하면 레벨이 오른다." % st.minLevel }
		return { who = "Kairon", main = true, kind = "trial", title = "스승에게 [승급 시험]을 청하자",
			goal = "[%s]로 자랄 때가 됐다. 카이론에게 말을 걸어 [승급 시험]을 청한다." % st.name }
	var side_hint = _side_hint()
	if side_hint: return side_hint
	var t = training.line.call()
	if t: return { who = "Kairon", title = "오늘의 수련", goal = t.goal if t.get("goal") else "카이론을 찾아간다" }
	# 본 이야기 줄기에서 저절로 열릴 차례인 것만 센다. 조건이 따로 없는 것(밀회 s1 · 어둠의 길 m7d)은 사건이 불러 주는 것이라
	# 첫날부터 "숲길·호수를 걷다 보면 다음 이야기가 열린다"가 떴다 (호수는 아직 닫혀 있었다)
	if all().any(func(q): return q.get("auto") and q.act == "main" and q.get("requires") and _ready_quest(q)):
		return { who = null, title = "세상을 돌아다녀 보자", goal = "숲길·호수를 걷다 보면 다음 이야기가 열린다. 옛 굴을 탐험해 보거나 마을 용들과 이야기해도 좋다" }
	var pass_time = _pastime(false)
	if pass_time: return pass_time
	return { who = null, title = "한숨 돌리자", goal = "굴을 꾸미거나, 게시판의 잡일을 맡거나, 마을 용들과 이야기해 보자" }


## 부탁이 있는 용 하나를 짚어 준다 (머리 위 '!'). 가리키는 화살표는 없고 귀띔만 한다. 없으면 null
static func _side_hint():
	var side := all().filter(func(q): return not q.get("auto") and q.act != "main" and _ready_quest(q))
	if side.is_empty(): return null
	var nm: String = side[0].giver
	var p = Routine.plan_for(nm)
	return { who = nm, main = false, title = "%s에게 할 말이 있는 눈치다" % Names.npc(nm),
		goal = "머리 위에 '!'가 뜬 용에게 말을 걸어 보자%s%s" % [" (지금 %s)" % p.mapName if p else "", ". 부탁이 있는 용이 더 있다" if side.size() > 1 else ""] }


## 본 이야기가 멈춘 동안 지금 바로 할 수 있는 것 하나: 부탁한 용 → 게시판의 새 쪽지 → 물고기 도감. 없으면 null
static func _pastime(with_side := true):
	if with_side:
		var side_hint = _side_hint()
		if side_hint: return side_hint
	var note = Chores.fresh_note()
	if note:
		return { who = null, main = false, title = "게시판에 새 쪽지: %s" % note.title,
			goal = "%s (%s). 마을 광장 게시판에서 [E]로 떼어 간다" % [goal_text(note.goal), Chores._reward_line(Chores._reward(note))] }
	if Chapters.map_open(GameState, "LAKE"):
		var got: int = GameState.stats.get("fishKinds", {}).size()
		var total := DiveFish.kinds().size()
		if got < total:
			return { who = null, main = false, title = "물고기 도감 채우기 (%d / %d)" % [got, total],
				goal = "물가에서 [E]로 낚싯줄을 드리운다%s. 못 잡은 물고기가 어디서 · 언제 잡히는지는 일지 [기록]에 있다" \
					% (". 날 수 있으면 물 위에서 덮쳐도 된다" if GameState.player.stage_index >= Story._adult() else "") }
	return null


## NPC 머리 위 표시: '?' 지금 찾아갈 곳, '!' 새 부탁, 없으면 ""
static func marker(npc) -> String:
	if not npc.config.get("name"): return ""
	if reportable_for(npc) or talk_quest_for(npc) or bring_quest_for(npc): return "?"
	if offer_for(npc): return "!"
	var m = training.marker.call(npc)
	return m if m else ""


## 추적할 퀘스트를 바꾼다 (로그에서 클릭)
static func set_tracked(id) -> void:
	GameState.quests.tracked = null if GameState.quests.tracked == id else id
	on_change.call()


## 지금 추적 중인 퀘스트. 지정한 게 없으면 완료된 것 → 가장 먼저 받은 것 순으로 고른다
static func tracked_quest():
	var act := active_quests()
	if act.is_empty(): return null
	for q in act:
		if q.id == GameState.quests.tracked: return q
	for q in act:
		if is_complete(q): return q
	return act[0]


static func accept(q: Dictionary) -> void:
	var Q: Dictionary = GameState.quests
	if Q.active.has(q.id) or Q.done.has(q.id): return
	Q.active[q.id] = { step = 0, n = 0 }
	_catch_up(q)
	if not Q.tracked: Q.tracked = q.id
	Hud.quest_banner("새 이야기", q.title, "%s에게 돌아간다" % Names.npc(turn_in_npc(q)) if is_complete(q) else _hint_or_goal(q), q)
	on_change.call()


## 정체의 단서를 적어 둔다 (일지 [기록])
static func add_clue(id: String) -> void:
	if not GameState.story.clues.has(id): GameState.story.clues.append(id)


## 보고하고 보상을 받는다. choice_id: 마무리에서 고른 선택지 (q.choice). 나중 대사·사건이 읽는다
## 큰 대목(보스를 잡았거나 장이 끝난 본 이야기)이었으면 true — 그날은 다음 본 이야기를 꺼내지 않는다 (resting)
static func turn_in(q: Dictionary, npc, choice_id = null) -> bool:
	var p = GameState.player
	var r: Dictionary = q.reward if q.get("reward") else {}
	var Q: Dictionary = GameState.quests
	var chapter_before: String = Chapters.current(GameState).id
	if choice_id: Q.choices[q.id] = choice_id
	Q.active.erase(q.id)
	Q.done.append(q.id)
	if Q.tracked == q.id: Q.tracked = null
	if r.get("meat"): p.inventory.meat += int(r.meat)
	if r.get("gold"): p.gold += int(r.gold)
	var rel_got := NpcActions.add_relation(npc, r.relation) if r.get("relation") and npc else -1.0   # 단계를 넘으면 사이 장면이 예약된다
	if r.get("clue"): add_clue(r.clue)
	if r.get("element"): p.unlock_element(r.element)      # 싸워서 얻는 게 아니라 맡겨 받는 숨결
	if r.get("furniture"):   # 받은 선물은 굴 꾸미기의 [가진 것]에 들어간다 (누리의 조약돌 · 하루의 돌)
		GameState.furniture[r.furniture] = Den.owned(r.furniture) + 1
		Hud.pop("%s 받았다. 내 굴에서 [E] 굴 꾸미기로 놓을 수 있다." % Util.josa(Den.furniture()[r.furniture].name, "을", "를"), "🪨")
	Hud.quest_banner("이야기 완료", q.title, reward_text(q, rel_got))
	if r.get("xp"): p.gain_xp(r.xp)
	# 고른 선택지에 딸린 장면이 먼저, 그다음이 퀘스트 마무리 장면
	if q.get("choice"):
		for o in q.choice.options:
			if o.id == choice_id: apply_pick(o)   # 고른 것의 대가 (사이 · 단서 · 깃발)
		for o in q.choice.get("options", []):
			if o.id == choice_id and o.get("scene"): _queue_scene(q.title, o.scene, o.get("place"))
	if r.get("scene"): _queue_scene(q.title, r.scene, r.get("place"))
	# 큰 대목을 마친 날은 생활할 틈으로 둔다. 새벽 전(한밤중)에 마쳤으면 그날 새벽까지만
	var big: bool = q.act == "main" and (_has_boss(q) or Chapters.current(GameState).id != chapter_before)
	if big: GameState.story.restUntil = GameState.day + (0 if GameState.dayTime < NightEvents.DAWN else 1)
	# 끝냈으면 다음에 할 만한 일을 한 번 귀띔한다
	if active_quests().is_empty():
		var s = suggestion()
		if s: Hud.quest_banner("다음에 할 만한 일", s.title, s.goal)
	on_change.call()
	return big


## 추적창에 보여 줄 한 개 (없으면 null)
static func tracked_line():
	var q = tracked_quest()
	if not q:
		var t = training.line.call()
		if t: t.training = true
		return t
	var total := steps(q).size()
	var done := is_complete(q)
	return {
		title = "%s (%d/%d)" % [q.title, mini(step_index(q) + 1, total), total] if total > 1 else q.title,
		goal = "%s에게 돌아간다" % Names.npc(turn_in_npc(q)) if done else _hint_or_goal(q),
		text = "" if done else ("%d / %d" % [progress(q), step_total(q)] if step_total(q) > 1 else ""),
		where = _where_line(q),
		complete = done,
		more = active_quests().size() - 1,
	}


## 퀘스트가 대목 단위로 바뀌기 전 세이브는 진행도가 숫자 하나였다
static func migrate(Q: Dictionary) -> Dictionary:
	var out := { active = {}, done = Q.get("done", []), tracked = Q.get("tracked"), choices = Q.get("choices", {}) }
	var act: Dictionary = Q.get("active", {})
	for id in act:
		var v = act[id]
		out.active[id] = { step = 0, n = v } if (v is int or v is float) else v
	# 이야기가 다시 쓰이면서 사라진 id 는 조용히 버린다 (일지에 빈 줄이 남지 않게)
	for id in out.active.keys():
		if by_id(id) == null: out.active.erase(id)
	if out.tracked and not out.active.has(out.tracked): out.tracked = null
	return out


## 일지 [퀘스트] 탭: 막마다 묶은 줄들. 앞으로 올 대목은 숨긴다 (이야기를 미리 보이지 않게)
static func quest_log() -> Array:
	var Q: Dictionary = GameState.quests
	var acts: Dictionary = Data.get_module("quests").ACT_NAMES
	var groups := []
	var today = training.row.call()
	if today: groups.append({ act = "training", name = "오늘의 수련", rows = [today] })
	var by_act := {}
	for q in all():
		var active: bool = Q.active.has(q.id)
		var done: bool = Q.done.has(q.id)
		if not active and not done: continue   # 아직 받지도 않았으면 로그에 나오지 않는다
		if not by_act.has(q.act):
			by_act[q.act] = { act = q.act, name = acts.get(q.act, q.act), rows = [] }
			groups.append(by_act[q.act])
		var total := steps(q).size()
		var complete: bool = active and is_complete(q)
		var si := step_index(q)
		var st_rows := []
		var qs := steps(q)
		for i in qs.size():
			var st: Dictionary = qs[i]
			var sdone: bool = done or i < si
			var snow: bool = active and i == si
			if sdone or snow: st_rows.append({ hint = GameInput.words(st.hint) if st.get("hint") else goal_text(st.goal), scene = st.get("scene"), done = sdone, now = snow })
		var cs = cur_step(q) if active else null
		by_act[q.act].rows.append({
			id = q.id, title = q.title, giver = giver_line(q.giver),
			summary = q.get("summary", ""),
			hint = "%s에게 돌아가 보고한다." % Names.npc(turn_in_npc(q)) if complete else ((GameInput.words(cs.hint) if cs and cs.get("hint") else step_goal_text(q)) if active else ""),
			goal = step_goal_text(q) if active and not complete else "-",
			reward = reward_text(q),
			progress = "완료" if done else "보고 대기" if complete else "%d / %d" % [progress(q), step_total(q)],
			chapter = "대목 %d / %d" % [mini(si + 1, total), total] if total > 1 and active else "",
			steps = st_rows,
			doneText = q.get("done", "") if done else "",   # 보고 없이 끝나는 대목(첫 밤 m1n)은 마무리 글이 없다
			endScene = q.reward.scene if done and q.get("reward") and q.reward.get("scene") else null,
			done = done, complete = complete, tracked = Q.tracked == q.id,
		})
	# 다음에 열릴 퀘스트를 '???' 로 한 줄 귀띔
	for g in groups:
		for q in all():
			if acts.get(q.act, q.act) != g.name or Q.active.has(q.id) or Q.done.has(q.id): continue
			if q.get("requires") and not Q.done.has(q.requires): continue
			var hint: String = "아직 때가 아니다. 세상을 더 돌아다녀 보자." if q.get("auto") \
				else "다음 이야기는 내일 아침에 이어진다." if q.act == "main" and waits_for_morning() \
				else "%s에게 말을 걸어 보자." % Names.npc(q.giver)
			g.rows.append({ id = q.id, title = "???", giver = giver_line(q.giver), upcoming = true, hint = hint })
			break
	return groups
