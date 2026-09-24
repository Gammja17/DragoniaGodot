class_name Party
## 원정대: 나를 따라나선 용들이 같이 싸운다 (data/party.json).
##
##  · 따라나선 용의 화력은 내 피해를 따라 큰다. 동료 하나가 내 브레스의 3~4할쯤
##    (호감 50 → 3할, 100 → 4할. 이야기가 데려온 서먹한 용은 2할까지 내려간다)
##    내 피해는 단계 · 대장간 · 성장 트리만 센다. 유물과 기세는 내 몫이다
##  · 용마다 역할이 하나 있다 (막기 · 살리기 · 치기). 화력은 역할에 따라 조금 더하고 뺀다

const PANEL := "res://scenes/ui/party_panel.tscn"

static func _d() -> Dictionary: return Data.get_module("party")


## 그 용의 원정대 표 (없으면 빈 것)
static func member(nm: String) -> Dictionary:
	return _d().MEMBERS.get(nm, {})


## 그 용의 역할 { name, desc, power }. 표에 없으면 빈 것
static func role(npc) -> Dictionary:
	return _d().ROLES.get(member(str(npc.config.get("name", ""))).get("role", ""), {})


## 알림 끝에 붙이는 역할 설명 " (막기: …)". 역할이 없으면 ""
static func role_note(npc) -> String:
	var r := role(npc)
	return " (%s: %s)" % [r.name, r.desc] if not r.is_empty() else ""


## 원정대 창을 HUD 에 붙인다 (한 번). 상태판 바로 뒤에 두어 대화창 · 창들보다 아래에 그려진다
static func ensure_panel() -> void:
	var hud = Hud.current
	if hud == null or hud.has_node("PartyPanel"): return
	var panel: Control = load(PANEL).instantiate()
	panel.name = "PartyPanel"
	hud.add_child(panel)
	hud.move_child(panel, hud.status.get_index() + 1)


## 내 브레스가 1초에 주는 피해. 타고난 불을 기준으로 단계 · 대장간 · 성장 트리만 센다
static func player_dps() -> float:
	var p = GameState.player
	var fire: Dictionary = Data.get_module("elements").ELEMENTS.FIRE
	var shot: float = fire.damage * p.stage.damage * (1 + 0.08 * GameState.upgrades.get("dmg", 0)) \
		* (1 + Growth.stat("dmg")) * (1 + Growth.stat("breath"))
	return shot * fire.pelletsByStage[p.stage_index] / fire.rate


## 호감에 따른 몫: 0 → 2할, 50 → 3할, 100 → 4할
static func share(relation: float) -> float:
	var s: Dictionary = _d().SHARE
	if relation >= 50: return lerpf(s.mid, s.high, clampf((relation - 50) / 50.0, 0, 1))
	return lerpf(s.low, s.mid, clampf(relation / 50.0, 0, 1))


## 따라나선 용의 브레스 한 발 피해
static func shot_damage(npc) -> float:
	return player_dps() * share(npc.relation) * float(role(npc).get("power", 1.0)) * float(_d().INTERVAL)


## 다음 한 발까지. 여럿이 한꺼번에 쏘지 않게 조금씩 어긋난다
static func interval() -> float:
	return float(_d().INTERVAL) * Util.rand_range(0.9, 1.1)


## 그 속성의 브레스가 닿는 거리 (날아가는 거리 + 맞는 범위)
static func reach(element: String) -> float:
	var els: Dictionary = Data.get_module("elements").ELEMENTS
	var el: Dictionary = els.get(element, els.FIRE)
	return float(el.speed) * float(el.get("life", 1.2)) + float(el.get("radius", 40))


## 그 용의 역할 id ('GUARD' · 'MEDIC' · 'STRIKE'. 표에 없으면 "")
static func role_id(npc) -> String:
	return str(member(str(npc.config.get("name", ""))).get("role", ""))


## 나를 따라나선 막기 동료인가
static func guarding(n) -> bool:
	return n is Dragon and not n.is_player and n.state != "WANDER" and role_id(n) == "GUARD"


## 막기 동료가 곁(taunt)에 있으면, 적은 그 용을 이만큼(px) 더 가까이 있는 셈 친다. 아니면 0
static func taunt_pull(n, from) -> float:
	if not guarding(n): return 0.0
	var g: Dictionary = _d().ROLES.GUARD
	return float(g.pull) if Util.dist(n, from) < float(g.taunt) else 0.0


## 받는 피해 배율. 막기 동료는 덜 다친다
static func taken(n) -> float:
	return float(_d().ROLES.GUARD.taken) if guarding(n) else 1.0


# ---------- 쓰러짐 ----------
# 따라나선 동료가 쓰러졌다가 저절로 일어나면 그날은 마을로 돌아간다 (살리기 동료가 먼저 일으키면 남는다).
# 내가 쓰러지면 따라오던 짝 · 동료가 나를 업어다 놓고 그날은 돌아간다. 돌아간 날은 story.party.home[이름] 에 적는다

## 오늘 쓰러져서 마을로 돌아간 용인가 (다음 날 다시 따라나선다)
static func went_home(npc) -> bool:
	return int(GameState.story.get("party", {}).get("home", {}).get(str(npc.config.name), -1)) == GameState.day


## 오늘은 더 따라오지 않는다. 고른 동료면 칸이 비고, 짝이면 짝인 채로 따라다니기만 멈춘다
static func send_home(npc) -> void:
	if not GameState.story.has("party"): GameState.story.party = {}
	if not GameState.story.party.has("home"): GameState.story.party.home = {}
	GameState.story.party.home[str(npc.config.name)] = GameState.day
	if GameState.companion == npc: GameState.companion = null
	npc.state = "WANDER"
	npc.passive = false
	_walk_out(npc)


## 이 지도를 걸어 나간다 (가장 가까운 문으로). 마을 안이면 일과가 제자리로 데려간다
static func _walk_out(npc) -> void:
	if GameState.map_id == "VILLAGE" or not GameState.entities.npcs.has(npc): return
	var gate = null
	for p in GameState.entities.props:
		if p.portal and (gate == null or Util.dist(npc, p) < Util.dist(npc, gate)): gate = p
	if gate: npc.walk_to = { x = gate.x, y = gate.y, leave = true }
	else: npc.remove = true


## 쓰러졌던 용이 저절로 일어날 때 (Dragon). 따라오던 고른 동료 · 짝은 체력 절반으로 일어나 그날은 돌아간다. 처리했으면 true
static func on_get_up(npc) -> bool:
	if is_story(npc) or npc.state == "ALLY":   # 이야기 동료 · 결투장에 합류한 용은 돌아가지 않는다. 반만 차서 일어난다
		npc.hp = npc.max_hp * 0.5
		npc.say("(툭툭 털고 일어난다.)")
		return true
	var picked: bool = npc == GameState.companion or (npc == GameState.partner and npc.state == "PARTNER_FOLLOW")
	if not picked: return false
	npc.hp = npc.max_hp * 0.5
	send_home(npc)
	Hud.pop("%s 오늘은 마을로 돌아갑니다." % Util.josa(Names.npc(npc.config.name), "은", "는"), "🏠")
	return true


## 내가 쓰러졌을 때 (Dragon). 따라오던 짝 · 동료는 그날 돌아간다. 돌아간 용들의 이름
static func on_player_down() -> Array:
	var gone := []
	for n in [GameState.companion, GameState.partner]:
		if n and n.state != "WANDER" and not gone.has(Names.npc(n.config.name)):
			send_home(n)
			gone.append(Names.npc(n.config.name))
	return gone


# ---------- 원정대 칸 ----------
# 따라나서는 용: 이야기가 데려가는 동료(STORY) + 내가 고른 한 자리 (짝이 따라오면 짝, 아니면 고른 동료).
# 이야기 동료는 퀘스트 진행을 보고 저절로 들고 난다. 불러오면 다시 센다 (story.party.story 는 지난번에 센 것)

## 나를 따라다니는 용들 (이야기 동료 · 짝 · 고른 동료). 결투장에 합류한 용과 몰래 다가가기에 끼운 용은 빼고
static func followers() -> Array:
	var out := []
	for nm in GameState.story.get("party", {}).get("story", []):
		var n = World.any_npc(nm)
		if n and n.state == "STORY_FOLLOW": out.append(n)
	for n in [GameState.partner, GameState.companion]:
		if n and not out.has(n) and (n.state == "PARTNER_FOLLOW" or n.state == "COMPANION_FOLLOW"): out.append(n)
	return out


## 이야기가 데려가는 동료인가
static func is_story(npc) -> bool:
	return npc != null and npc.state == "STORY_FOLLOW"


## 그 용이 지금 곁에 따라와 있나 (장면 줄의 "with"). "*" 는 누구든. 결투장에 합류한 용도 친다
static func is_with(nm: String) -> bool:
	for n in GameState.entities.npcs:
		if n.state != "WANDER" and n.state != "SNEAK_FOLLOW" and (nm == "*" or n.config.get("name") == nm): return true
	return false


## 지금 이야기가 데려가는 용들 (STORY: 그 퀘스트가 진행 중이고 from~to 대목 사이. after 사건을 본 뒤, until 보스를 잡기 전)
static func story_names() -> Array:
	var out := []
	for r in _d().STORY:
		var e = GameState.quests.active.get(r.quest)
		if e == null or Routine.is_dead(r.who) or out.has(r.who): continue
		var st := int(e.step)
		if st < int(r.get("from", 0)) or st > int(r.get("to", 99)): continue
		if r.get("after") and not GameState.story.get("events", []).has(r.after): continue
		if r.get("until") and GameState.bossesDefeated.get(r.until, false): continue
		out.append(r.who)
	return out


## 내가 고를 수 있는 동료인가: 원정대 표에 있고, 호감이 문턱을 넘었고, 마을에 남을 까닭이 없다
static func can_pick(npc) -> bool:
	var nm := str(npc.config.get("name", ""))
	return not member(nm).is_empty() and npc.relation >= join_at(nm) and not Routine.is_dead(nm) and stays_home(npc) == "" and not away(npc)


## 그 용이 따라나서는 호감 (MEMBERS[이름].join, 없으면 JOIN)
static func join_at(nm: String) -> int:
	return int(member(nm).get("join", _d().JOIN))


## 따라나서지 않는 까닭 한 줄 (없으면 ""). MEMBERS[이름].stay = { after: 이 퀘스트를 끝낸 뒤로, line }
static func stays_home(npc) -> String:
	var s = member(str(npc.config.get("name", ""))).get("stay")
	return str(s.line) if s and GameState.quests.done.has(s.after) else ""


## 이야기 때문에 곁을 비우는 동안인가 (MEMBERS[이름].away).
## 5장 사절(티아맷 · 유안)은 봉우리로 떠난 날부터 알 일(m5a)을 마칠 때까지 없다
static func away(npc) -> bool:
	var a = member(str(npc.config.get("name", ""))).get("away")
	return a != null and str(a.while) == "envoys" and _envoys_gone()


## 5장 사절이 봉우리로 떠나 있는가: 밀회를 본 다음 날(유안 "내일 봉우리에 오른다") 또는 한여름 눈부터, m5a 를 마칠 때까지
static func _envoys_gone() -> bool:
	if GameState.quests.done.has("m5a"): return false
	if GameState.story.get("events", []).has("ev_glacia"): return true
	var tryst = GameState.story.get("trystDay")
	return tryst != null and GameState.day > int(tryst)


## 고른 칸을 이 용에게 준다. 먼저 따라오던 고른 동료는 마을로 돌아가고, 따라오던 짝은 마을에서 기다린다
static func take_slot(npc) -> void:
	for n in [GameState.companion, GameState.partner]:
		if n == null or n == npc or not (n.state == "PARTNER_FOLLOW" or n.state == "COMPANION_FOLLOW"): continue
		var nm := Names.npc(n.config.name)
		if n == GameState.companion:
			GameState.companion = null
			Hud.pop("%s 마을로 돌아갑니다." % Util.josa(nm, "은", "는"), "👋")
		else: Hud.pop("%s 마을에서 기다립니다." % Util.josa(nm, "은", "는"), "👋")
		n.state = "WANDER"
		_walk_out(n)


## 이야기 동료를 이야기에 맞춘다: 들어올 용은 따라나서고, 일을 마친 용은 제자리로 돌아간다 (장면이 다 흐른 뒤에).
## 고른 칸은 하나라, 화해하고 다시 따라나선 짝이 있으면 고른 동료가 돌아간다. 마을에 남기로 한 짝은 따라다니지 않는다.
## quiet: 알림 없이 (지도를 옮길 때 · 불러올 때). bring: 이 지도에 없는 이야기 동료를 곁으로 불러온다
static func sync(quiet := false, bring := true) -> void:
	if not GameState.story.has("party"): GameState.story.party = {}
	var P: Dictionary = GameState.story.party
	var had: Array = P.get("story", [])
	var want := story_names()
	var calm: bool = GameState.questScenes.is_empty() and not Cutscene.on and not GameState.entities.get("bosses", []).any(func(b): return b.dying > 0)
	var now := want.duplicate()
	for nm in had:
		if now.has(nm): continue
		if calm: _leave_story(World.any_npc(nm), quiet)
		else: now.append(nm)   # 장면이 남아 있으면 그 뒤에 돌아간다
	for nm in want:
		var n = World.any_npc(nm)
		if n and n.state != "STORY_FOLLOW": _join_story(n, quiet or had.has(nm), bring)   # 불러온 세이브에서는 알림 없이 다시 따라나선다
	P.story = now
	var c = GameState.companion
	var mate = GameState.partner
	if c and mate and c != mate and mate.state == "PARTNER_FOLLOW" and c.state == "COMPANION_FOLLOW":
		GameState.companion = null
		c.state = "WANDER"
		_walk_out(c)
		if not quiet: Hud.pop("%s 마을로 돌아갑니다." % Util.josa(Names.npc(c.config.name), "은", "는"), "👋")
	if mate and mate.state == "PARTNER_FOLLOW" and stays_home(mate) != "":
		mate.state = "WANDER"
		_walk_out(mate)
		if not quiet: Hud.pop("%s 마을에 남습니다." % Util.josa(Names.npc(mate.config.name), "은", "는"), "🏠")
	# 이야기 때문에 곁을 비우는 용 (5장 사절): 따라오던 중이면 그날 떠난다
	for n in [GameState.companion, GameState.partner]:
		if n and (n.state == "COMPANION_FOLLOW" or n.state == "PARTNER_FOLLOW") and away(n):
			if n == GameState.companion: GameState.companion = null
			n.state = "WANDER"
			_walk_out(n)
			if not quiet: Hud.pop(str(member(str(n.config.name)).away.note), "📜")


## 이야기가 이 용을 데려간다. 고른 칸에 있던 용이면 칸이 빈다
static func _join_story(n, quiet: bool, bring: bool) -> void:
	if GameState.companion == n: GameState.companion = null
	n.state = "STORY_FOLLOW"
	n.walk_to = null; n.passive = false; n.remove = false; n.is_hidden = false
	var p = GameState.player
	if bring and p and not GameState.entities.npcs.has(n) and not GameState.dungeon and not alone_here():
		World.add_entity("npcs", n)
		n.x = p.x + 70; n.y = p.y + 20
	if not quiet: Hud.pop("%s 함께 갑니다.%s" % [Util.josa(Names.npc(n.config.name), "이", "가"), role_note(n)], "🤝")


## 이야기가 끝났다. 짝이면 (고른 칸이 비어 있을 때) 다시 짝으로 따라다니고, 아니면 제자리로 돌아간다
static func _leave_story(n, quiet: bool) -> void:
	if n == null or n.state != "STORY_FOLLOW": return
	var picked = GameState.companion
	if n == GameState.partner and not (picked and picked.state == "COMPANION_FOLLOW") and stays_home(n) == "":
		n.state = "PARTNER_FOLLOW"
		return
	n.state = "WANDER"
	_walk_out(n)
	if not quiet: Hud.pop("%s 제자리로 돌아갑니다." % Util.josa(Names.npc(n.config.name), "은", "는"), "👋")


# ---------- 나 혼자 가는 곳 ----------
# 3장 누리를 찾는 골짜기 · 8장 이그나르가 부른 화산 (ALONE). 동료는 따라 들어오지 않고 밖에서 기다린다

## 그 지도가 지금 나 혼자 가야 하는 곳이면 그 규칙 (아니면 빈 것)
static func _alone_rule(map_id: String) -> Dictionary:
	for r in _d().ALONE:
		if not r.maps.has(map_id) or GameState.bossesDefeated.get(r.until, false): continue
		for q in r.quests:
			if GameState.quests.active.has(q): return r
	return {}


static func alone_here() -> bool:
	return not _alone_rule(GameState.map_id).is_empty()


## 혼자 가야 하는 곳에 막 들어섰으면 알려 준다 (was: 방금 떠나온 지도)
static func note_alone(was: String) -> void:
	var r := _alone_rule(GameState.map_id)
	if r.is_empty() or not _alone_rule(was).is_empty() or followers().is_empty(): return
	Hud.pop(str(r.note), "🚶")


# ---------- 같이 싸운 기록 ----------
# 보스를 쓰러뜨린 순간 곁에서 싸운 용을 적는다 (story.party.fought[보스] = [이름들]).
# 가장 많이 같이 싸운 용이 "끝까지 곁에서 싸운 용"이다 (story.party.closest. 에필로그가 읽는다)

## 보스가 쓰러졌을 때 (Boss). 곁에서 싸운 용을 적고, 그 용들의 호감이 조금 오른다 (BOND)
static func on_boss_down(boss_id: String) -> void:
	if not GameState.story.has("party"): GameState.story.party = {}
	var P: Dictionary = GameState.story.party
	if not P.has("fought"): P.fought = {}
	var names := []
	for n in GameState.entities.npcs:
		if n.state == "WANDER" or n.state == "SNEAK_FOLLOW": continue
		names.append(str(n.config.name))
		NpcActions.add_relation(n, float(_d().BOND))   # 같이 넘긴 싸움만큼 가까워진다
	P.fought[boss_id] = names
	P.closest = _closest(P.fought)


## 가장 여러 번 같이 싸운 용 (같으면 호감이 높은 쪽). 없으면 ""
static func _closest(fought: Dictionary) -> String:
	var count := {}
	for b in fought:
		for nm in fought[b]: count[nm] = count.get(nm, 0) + 1
	var best := ""
	for nm in count:
		if best == "" or count[nm] > count[best] or (count[nm] == count[best] and World.any_npc(nm).relation > World.any_npc(best).relation): best = nm
	return best
