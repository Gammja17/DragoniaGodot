class_name Raid
## 2D판 systems/raid.js. 사냥꾼 습격. 회차(GameState.raid.count)가 오를수록 인원이 늘고 새 병종이 섞인다.
## 첫 습격은 이야기가 부른다 (퀘스트가 "습격을 막아라"일 때 그날 밤). 그 뒤로는 시계가 돈다.

const SIDES := {
	"W": { name = "서쪽", dx = -1, dy = 0 }, "E": { name = "동쪽", dx = 1, dy = 0 },
	"N": { name = "북쪽", dx = 0, dy = -1 }, "S": { name = "남쪽", dx = 0, dy = 1 },
}
# 6장의 대습격. 싸울 수 있는 용들이 폭포에 가 있는 틈을 알고 온다. 두 방향에서, 대장까지
const WAR_ROSTER := ["KNIGHT", "KNIGHT", "KNIGHT", "ARCHER", "ARCHER", "ARCHER", "MAGE", "MAGE", "HEAVY", "HEAVY", "CAPTAIN"]


## 이야기가 습격을 기다리고 있나 (지금 대목이 "사냥꾼을 쓰러뜨려라"·"습격을 막아라")
static func wanted() -> bool:
	for q in Quests.active_quests():
		var st = Quests.cur_step(q)
		var g = st.get("goal") if st else null
		if g and (g.type == "raid" or (g.type == "kill" and g.get("target") == "HUNTER")): return true
	return false


## 오른쪽 기둥에 띄우는 한 줄: 습격 중이면 남은 사냥꾼, 아니면 다음 습격까지
static func status_text() -> String:
	var raid: Dictionary = GameState.raid
	if GameState.dungeon: return ""   # 굴 속에서는 습격 시계가 멈춘다
	if not raid.active and raid.count == 0: return ""   # 아직 습격을 겪기 전
	if raid.active:
		var ob = raid.get("objective")
		return "습격 중! 남은 사냥꾼 %d" % GameState.entities.humans.size() + (" · %s 지켜라" % Util.josa(Names.npc(ob.name), "을", "를") if ob and not ob.failed else "")
	if not _still_coming(): return ""   # 나팔은 다시 울리지 않는다
	var t := maxi(0, ceili(GameState.raidTimer))
	return "다음 습격 %d:%02d" % [t / 60, t % 60]


static func _is_night() -> bool:
	return GameState.dayTime < 0.22 or GameState.dayTime > 0.82


## 이야기가 끝나면 때 되면 오던 사냥꾼이 오지 않는다. 숲길을 알려 주던 지도는 잿마루가 흘린 것이었다
## (어둠의 결말: 마을이 잿마루의 일부가 됐다 · 수호룡·교화의 결말: 지도를 흘리던 이가 더는 없다)
static func _still_coming() -> bool:
	if GameState.story.get("route") == "dark" and GameState.quests.done.has("m7d"): return false
	return not Ending.seen()


static func update(dt: float) -> void:
	if Ending.playing: return
	var raid: Dictionary = GameState.raid
	if raid.active:
		if raid.get("captainFell"):
			raid.captainFell = false; _captain_down()
		# 지켜야 하는 용이 쓰러졌는지 본다
		var ob = raid.get("objective")
		if ob and not ob.failed:
			for n in GameState.entities.npcs:
				if n.config.get("name") == ob.name and n.down_timer > 0:
					ob.failed = true; Hud.pop("%s가 쓰러졌다…" % Names.npc(ob.name), "💫")
		# 지도를 옮기면 사냥꾼도 같이 사라진다. 그걸 "격퇴"로 쳐 주면 굴에 들어갔다 나오는 것만으로 이긴다
		if GameState.map_id != "VILLAGE": _abandon()
		elif GameState.entities.humans.is_empty(): _end()
		return
	# 습격은 마을에 있을 때만 벌어진다. 딴 데 있으면 시계가 멈춘다
	if GameState.map_id != "VILLAGE": return
	if wanted() and _is_night():
		trigger()
		return
	if not _still_coming(): return
	# 첫 습격은 이야기가 부른다. 그 전에는 시계가 돌지 않는다
	if raid.count == 0: return
	GameState.raidTimer -= dt
	if GameState.raidTimer <= 0: trigger()


static func _chapter_no() -> int:
	var list: Array = Data.get_module("chapters").CHAPTERS
	return list.find(Chapters.current(GameState)) + 1


## 장마다 달라지는 습격. 2장 정찰대 · 3~4장 그물꾼 · 5장 마법사 · 6장 뒤 중갑과 잦은 대장. 회차는 인원을 조금씩 늘린다
static func _roster(count: int) -> Array:
	var ch := _chapter_no()
	var n := mini(3 + ch + floori(count * 0.7), 16)
	var pool := ["KNIGHT", "KNIGHT", "ARCHER", "ARCHER"]
	if ch >= 3: pool.append_array(["TRAPPER", "TRAPPER"])
	if ch >= 5: pool.append_array(["MAGE", "MAGE"])
	if ch >= 6: pool.append_array(["MAGE", "HEAVY"])
	if ch >= 7: pool.append_array(["HEAVY", "HEAVY", "TRAPPER"])
	var list := []
	for i in n: list.append(pool.pick_random())
	if ch >= 6 and count % 2 == 0: list.append_array(["CAPTAIN", "HEAVY"])       # 전쟁 뒤로는 대장이 자주 온다
	elif ch >= 4 and count % 3 == 0: list.append_array(["CAPTAIN", "HEAVY"])     # 대장은 호위를 데리고 온다
	return list


## 습격마다 목표가 하나 붙기도 한다 (3장부터, 절반쯤). 사냥꾼 몇이 싸우지 못하는 용 하나를 노린다
static func _pick_objective():
	if _chapter_no() < 3 or randf() < 0.5: return null
	var weak := ["Poco", "Mira", "Ember"].filter(func(n): return not Routine.is_dead(n))
	for npc in GameState.entities.npcs:
		if weak.has(npc.config.get("name")) and not (npc.down_timer > 0):
			return { type = "RESCUE", name = npc.config.name, failed = false }
	return null


## 대장이 쓰러졌다: 남은 사냥꾼의 절반이 도망친다
static func _captain_down() -> void:
	if not GameState.raid.active: return
	var rest: Array = GameState.entities.humans.filter(func(h): return not h.remove and h.type != "CAPTAIN")
	var flee := rest.slice(0, floori(rest.size() / 2.0))
	for h in flee: h.remove = true
	if not flee.is_empty(): Hud.pop("대장이 쓰러지자 사냥꾼 %d명이 달아났다!" % flee.size(), "🏃")


## 5장부터는 두 방향에서 한꺼번에 든다
static func _sides() -> Array:
	var keys := SIDES.keys()
	var first: String = keys.pick_random()
	if _chapter_no() < 6: return [SIDES[first]]
	var second: String = keys.filter(func(k): return k != first).pick_random()
	return [SIDES[first], SIDES[second]]


static func _spot(side: Dictionary) -> Vector2:
	# 마을 가장자리 바깥, 그 변을 따라 흩어져서 등장
	var spread := Util.rand_range(-260, 260)
	var b := Terrain.current_map_bounds()
	var cx := b.x / 2
	var cy := b.y / 2
	return Vector2(cx + side.dx * (b.x * 0.38) + (Util.rand_range(-60, 60) if side.dx else spread),
		cy + side.dy * (b.y * 0.36) + (Util.rand_range(-60, 60) if side.dy else spread))


## kind: 'war' 면 각본 있는 대습격 (6장의 사건이 부른다)
static func trigger(kind = null) -> void:
	var raid: Dictionary = GameState.raid
	raid.count += 1
	raid.active = true
	raid.kind = kind
	if kind == "war":
		_spawn_war()
		return
	var sides := _sides()
	var where := "과 ".join(sides.map(func(s): return s.name))
	Hud.current.show_raid_warning("%s에서 습격! (%d차)" % [where, raid.count])
	Sfx.play("raid")
	Hud.pop("사냥꾼 습격 %d차! %s에서 몰려옵니다. 마을 용들과 함께 막아내세요!" % [raid.count, where], "⚔️")
	var list := _roster(raid.count)
	if list.has("TRAPPER") and not GameState.story.get("flags", {}).get("sawTrapper"):
		if not GameState.story.has("flags"): GameState.story.flags = {}
		GameState.story.flags.sawTrapper = true
		Hud.pop("그물꾼이 섞여 있다. 느리게 날아오는 그물은 보고 피하자.", "🕸️")
	raid.objective = _pick_objective()
	if raid.objective: Hud.pop("사냥꾼 몇이 %s 쪽으로 몰려간다. 쓰러지지 않게 지켜 주자!" % Names.npc(raid.objective.name), "🛡️")
	if list.has("CAPTAIN"): Hud.pop("대장이 섞여 있다. 대장을 먼저 쓰러뜨리면 나머지가 흔들린다.", "⚔️")
	for i in list.size():
		var p := _spot(sides[i % sides.size()])
		var h := Human.make(p.x, p.y, list[i])
		h.max_hp = roundf(h.hp * (1 + 0.12 * (raid.count - 1))); h.hp = h.max_hp   # 회차가 오를수록 단단해진다
		h.power = 1 + 0.08 * (raid.count - 1)
		if raid.objective and i % 3 == 0 and list[i] != "CAPTAIN": h.hunts = raid.objective.name   # 셋 중 하나는 그 용만 노린다
		World.add_entity("humans", h)


static func _spawn_war() -> void:
	Hud.current.show_raid_warning("마을이 습격당하고 있다!")
	Sfx.play("raid")
	Hud.pop("사냥꾼들이 두 방향에서 몰려온다. 싸울 수 있는 용들은 전부 폭포에 가 있다!", "⚔️")
	var two := [SIDES.E, SIDES.S]
	for i in WAR_ROSTER.size():
		var p := _spot(two[i % 2])
		World.add_entity("humans", Human.make(p.x, p.y, WAR_ROSTER[i]))


static func _end() -> void:
	var raid: Dictionary = GameState.raid
	var p = GameState.player
	raid.active = false
	raid.kind = null
	GameState.raidTimer = Data.get_module("core_config").RAID_INTERVAL
	var gold: int = 30 + raid.count * 15
	p.gold += gold
	for npc in GameState.entities.npcs:
		if npc.config.get("fixed"): npc.relation = minf(100, npc.relation + 2)
	Hud.pop("습격 %d차 격퇴! (%dG, 마을 용들의 호감 ↑)" % [raid.count, gold], "🛡️")
	p.gain_xp(60 + raid.count * 30)
	GameState.story.today.raid = true   # 내일 아침 "어제 습격" 이야기가 나올 수 있다
	GameState.story.today.raidEndedAt = GameState.play_time   # 이 뒤로 한동안은 잠자리로 끌려가지 않는다
	var ob = raid.get("objective")
	if ob:
		for npc in GameState.entities.npcs:
			if npc.config.get("name") == ob.name and not ob.failed:
				npc.relation = minf(100, npc.relation + 8)
				p.gold += 40; p.gain_xp(80)
				Hud.pop("%s 끝까지 지켜 냈다! (40G, 호감 ↑)" % Util.josa(Names.npc(ob.name), "을", "를"), "🛡️")
				npc.say("고, 고마워… 나 진짜 무서웠어." if ob.name == "Poco" else "덕분에 살았어. 고마워.")
		raid.objective = null
	Quests.notify("raid")


## 싸우다 말고 마을을 떠났다. 보상도, 막아 냈다는 기록도 없다
static func _abandon() -> void:
	GameState.raid.active = false
	GameState.raidTimer = Data.get_module("core_config").RAID_INTERVAL
	Hud.pop("마을을 비운 사이 습격이 지나갔다. 남은 용들이 겨우 막아 냈다.", "🛡️")
