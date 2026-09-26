class_name Conditions
## 2D판 데이터 속 함수들을 GDScript 로 옮긴 것.
##
## tools/export_data.mjs 가 함수 자리에 { "$fn": 원래 소스, "$at": 모듈 안 경로 } 를 남긴다.
## Data 가 모듈을 읽을 때 그 자리를 여기 있는 Callable 로 바꿔 끼운다. 키는 "모듈:경로".
## 인자 s 는 GameState (2D판의 state).
##
## 옮기지 않은 함수가 남아 있으면 Data 가 경고하고, 그 자리는 늘 false 를 돌려준다.

static var _table := {}


static func lookup(module: String, at: String) -> Variant:
	if _table.is_empty(): _build()
	return _table.get(module + ":" + at)


static func _done(id: String) -> Callable:
	return func(s): return s.quests.done.has(id)


static func _flag(s, key: String) -> bool:
	return bool(s.story.get("flags", {}).get(key, false))


static func _build() -> void:
	_table = {
		# ---- chapters.js: 장이 끝났는가 ----
		"chapters:CHAPTERS.0.done": _done("m2"),
		"chapters:CHAPTERS.1.done": _done("m3"),
		"chapters:CHAPTERS.2.done": func(s): return bool(s.bossesDefeated.get("MORGATH", false)),
		"chapters:CHAPTERS.3.done": _done("m4"),
		"chapters:CHAPTERS.4.done": _done("m5g"),
		"chapters:CHAPTERS.5.done": _done("m5a"),
		"chapters:CHAPTERS.6.done": _done("m6w"),
		"chapters:CHAPTERS.7.done": _done("m5c"),
		"chapters:CHAPTERS.8.done": func(s): return s.quests.done.has("m6") or s.quests.done.has("m7d"),

		# ---- routines.js: 이야기의 갈래에 따라 달라지는 하루 ----
		"routines:ROUTINES.Nara.variants.0.when": func(s): return s.story.get("route") == "dark" and s.quests.done.has("m7d"),
		"routines:ROUTINES.Ignar.when": func(s):
			return (s.story.get("route") == "redeem" and s.quests.done.has("m6")) \
				or (s.story.get("route") == "dark" and s.quests.done.has("m7d")),
		"routines:ROUTINES.Ignar.variants.0.when": func(s): return s.story.get("route") == "dark",
		# 비류: 달맞이 모임으로 두 마을이 다시 오가기 전에는 구름마루를 떠나지 않는다 (그 뒤로 오후엔 호수에서 헤엄친다)
		"routines:ROUTINES.Biryu.variants.0.when": func(s): return not s.story.get("events", []).has("ev_gathering") or s.story.get("route") == "dark",
		"routines:ROUTINES.Doran.variants.0.when": func(s): return _flag(s, "couple_egg") and not _flag(s, "couple_hatched"),
		"routines:ROUTINES.Miru.variants.0.when": func(s): return _flag(s, "couple_egg") and not _flag(s, "couple_hatched"),
		"routines:ROUTINES.Iseul.when": func(s): return _flag(s, "couple_hatched"),
	}
	# ---- growth.js: 성장 트리 노드 설명 (찍은 단수 r 을 받는다). 표가 두 벌이라(목록·id 별) 두 경로에 다 건다 ----
	var descs := {
		"FANG1": func(r): return "주는 피해 +%d%%" % roundi(r * 4),
		"FANG2": func(r): return "브레스 피해 +%d%%" % roundi(r * 6),
		"FANG3": func(r): return "스킬 피해 +%d%%" % roundi(r * 7),
		"FANG4": func(_r = 0): return "체력이 35% 아래일 때 주는 피해 +45%",
		"SCALE1": func(r): return "최대 체력 +%d" % (r * 25),
		"SCALE2": func(r): return "받는 피해 -%d%%" % roundi(r * 3),
		"SCALE3": func(r): return "배 꺼지는 속도 -%d%%" % roundi(r * 8),
		"SCALE4": func(_r = 0): return "하루 한 번, 쓰러질 공격을 체력 1로 버티고 3초간 무적",
		"WING1": func(r): return "이동 속도 +%d%%" % roundi(r * 3),
		"WING2": func(r): return "대시 재사용 대기 -%d%%" % roundi(r * 8),
		"WING3": func(r): return "스킬 재사용 대기 -%d%%" % roundi(r * 4),
		"WING4": func(_r = 0): return "대시한 뒤 3초 동안 브레스 연사 속도 +35%",
	}
	var order := ["FANG1", "FANG2", "FANG3", "FANG4", "SCALE1", "SCALE2", "SCALE3", "SCALE4", "WING1", "WING2", "WING3", "WING4"]
	for i in order.size():
		_table["growth:GROWTH_NODES.%d.desc" % i] = descs[order[i]]
		_table["growth:NODES_BY_ID.%s.desc" % order[i]] = descs[order[i]]
	_build_story()
	_build_talk()
	_build_chronicle()
	_build_fix()   # [세션 B]
	_build_c()
	_build_g()   # [세션 G]


# ---- 자주 쓰는 것들 ----
static func _lessons(s) -> int: return s.story.get("lessons", []).size()
static func _scene_seen(s, id: String) -> bool: return s.story.get("scenes", []).has(id)
static func _event_seen(s, id: String) -> bool: return s.story.get("events", []).has(id)
## 결말(어느 길이든)을 향한 마지막 퀘스트를 끝냈거나 결말을 봤는가
static func _finale_done(s) -> bool:
	return s.quests.done.has("m6") or s.quests.done.has("m7d") or s.quests.active.has("m7d") or s.story.get("endingSeen", "") != ""


static func _dead(s, nm: String) -> bool: return s.story.get("dead", []).has(nm)
static func _boss(s, id: String) -> bool: return bool(s.bossesDefeated.get(id, false))
static func _lessons_at(n: int) -> Callable: return func(s): return _lessons(s) >= n


static func _build_story() -> void:
	var t := {
		# ---- quests.js: 부탁이 나오는 조건 ----
		# 자라나는 날개: 엘더가 "카이론한테 구르고 있다지?" 하고 꺼낸다. 첫 수련을 받은 뒤라야 말이 맞는다
		# (스승을 소개받자마자 걸려서, 추적창은 카이론의 수련을 가리키는데 화살표는 엘더를 가리켰다)
		"quests:QUESTS.2.needs": func(s): return _scene_seen(s, "ch1") and _lessons(s) >= 1,
		"quests:QUESTS.6.needs": func(s): return not s.quests.done.has("m5a") and not s.quests.active.has("m5a"),
		"quests:QUESTS.10.needs": func(s): return not _boss(s, "IGNAR"),
		"quests:QUESTS.17.needs": func(s): return s.quests.done.has("m3") and not _dead(s, "Gron"),
		"quests:QUESTS.18.needs": func(s): return _lessons(s) >= 2 and s.quests.done.has("m3"),   # 나라의 첫 부탁(n1)은 첫 습격을 같이 막은 뒤에
		"quests:QUESTS.23.needs": _done("m5c"),
		"quests:QUESTS.24.needs": _lessons_at(2),
		"quests:QUESTS.25.needs": func(s): return _lessons(s) >= 4 and Chapters.map_open(s, "VOLCANO"),

		# ---- story.js: 아침 장면 · 승급 시험 ----
		"story:SCENES.0.when": func(s): return s.day >= 2,
		"story:SCENES.1.when": _lessons_at(1),
		"story:SCENES.2.when": func(s): return bool(s.story.get("yesterday", {}).get("raid", false)) and _scene_seen(s, "ch1") and s.story.get("dead", []).is_empty(),
		"story:SCENES.3.when": func(s): return _boss(s, "MORGATH"),
		"story:SCENES.4.when": func(s): return _boss(s, "ZALGORA") and not _dead(s, "Gron"),   # 그론이 말하는 아침 (그가 떠난 뒤에는 나오지 않는다)
		"story:SCENES.5.when": func(s): return _boss(s, "MORGATH") and _scene_seen(s, "ch4"),
		"story:SCENES.6.when": func(s): return _boss(s, "ZALGORA") and _scene_seen(s, "ch5"),
		# 떠나기 전날의 장면들은 결말 뒤에 나오면 안 된다 (잠을 미루면 끝난 이야기 뒤에 흘러나왔다)
		"story:SCENES.7.when": func(s): return s.quests.done.has("m5c") and _scene_seen(s, "ch6") and not _finale_done(s),
		"story:SCENES.8.when": func(s): return s.quests.done.has("m5c") and not _finale_done(s),
		"story:SCENES.9.when": func(s): return s.quests.done.has("m6") and s.story.get("route") != "redeem" and s.story.get("route") != "dark",
		"story:SCENES.10.when": func(s): return s.quests.done.has("m6") and s.story.get("route") == "redeem",
		"story:TRIALS.0.needs": _lessons_at(1),
		"story:TRIALS.1.needs": func(s): return _lessons(s) >= 3 and s.quests.done.has("m3"),   # 성체는 8일째쯤 (레벨 10 · 수련 셋)

		# ---- training.js: 스승이 쉬는 날 · 데리고 나가는 날 ----
		"training:RESTS.0.when": func(_s = null): return true,
		# 엘더네 밥 · 수련장 그늘은 나라가 제자가 되기 전의 이야기다 ("제자로 안 받아 주니", "문 앞에서 기웃거리는 놈")
		"training:RESTS.1.when": func(s): return _lessons(s) >= 2 and not s.quests.done.has("n3"),
		"training:RESTS.2.when": func(s): return _lessons(s) >= 4 and not s.quests.done.has("n3"),
		"training:TRIPS.0.when": func(_s = null): return true,
		"training:TRIPS.1.when": _lessons_at(3),
		"training:TRIPS.2.when": func(s): return _boss(s, "MORGATH"),
	}
	# ---- ceremony.js: 승급 의식 대사. 숨결 × 구름마루를 겪었는가 조합마다 미리 뽑아 둔 것에서 이름만 채운다 (의식은 1 · 2단계뿐) ----
	for stage in ["1", "2"]:
		t["ceremony:RITES.%s.lines" % stage] = func(c = {}):
			var key := "%s|%s" % [c.get("element", "FIRE"), "true" if c.get("cloudtop", false) else "false"]
			var lines: Array = Data.get_module("ceremony_lines").RITE_LINES[stage][key]
			return lines.map(func(l): return { who = l.who, text = l.text.replace("{name}", c.get("name", "")) })
	_table.merge(t)


static func _build_talk() -> void:
	var mourning := func(s): return _dead(s, "Gron") and s.day - int(s.story.get("deathDay", {}).get("Gron", 0)) < 6
	var sulking := func(s):
		var love = s.story.get("love")
		if not s.partner or not love: return false
		var m = love.mood.get(s.partner.config.name)
		return m != null and m.kind == "SULK"
	_table.merge({
		# ---- npcTalk.js: 마음을 꺼낼 수 있는 때 ----
		"npcTalk:ROMANCE_GATES.Kairon.gate": _lessons_at(5),
		"npcTalk:ROMANCE_GATES.Seiran.gate": func(s): return _event_seen(s, "ev_gathering"),
		"npcTalk:ROMANCE_GATES.Ignar.gate": func(s): return s.story.get("route") == "redeem" or s.story.get("route") == "dark",
		"npcTalk:ROMANCE_GATES.Haru.gate": func(s): return _event_seen(s, "ev_gathering"),
		"npcTalk:ROMANCE_GATES.Elder.gate": _done("m3"),
		"npcTalk:ROMANCE_GATES.Gron.gate": _done("g1"),
		# ---- npcTalk.js: 상황에 맞는 인사 (s, npc) ----
		"npcTalk:SITUATION_LINES.0.when": func(s, _n = null): return s.story.get("route") == "dark" and s.quests.done.has("m7d"),
		"npcTalk:SITUATION_LINES.1.when": func(s, _n = null): return mourning.call(s),
		"npcTalk:SITUATION_LINES.2.when": func(s, _n = null): return _dead(s, "Gron") and not mourning.call(s),
		"npcTalk:SITUATION_LINES.3.when": func(s, _n = null): return s.weather.type != "CLEAR",
		"npcTalk:SITUATION_LINES.4.when": func(s, _n = null): return s.dayTime < 0.22 or s.dayTime > 0.84,
		"npcTalk:SITUATION_LINES.5.when": func(s, _n = null): return s.event == "BLOOD_MOON",
		"npcTalk:SITUATION_LINES.6.when": func(s, _n = null): return s.raid.active,
		"npcTalk:SITUATION_LINES.7.when": func(s, _n = null): return s.raid.count >= 3 and not s.raid.active,
		"npcTalk:SITUATION_LINES.8.when": func(s, _n = null): return s.kids.size() > 0,
		"npcTalk:SITUATION_LINES.9.when": func(s, _n = null): return _flag(s, "couple_egg") and not _flag(s, "couple_hatched"),
		"npcTalk:SITUATION_LINES.10.when": func(s, _n = null): return _flag(s, "couple_hatched"),
		"npcTalk:SITUATION_LINES.11.when": func(s, _n = null): return sulking.call(s),
		"npcTalk:SITUATION_LINES.12.when": func(s, _n = null): return s.partner != null and s.partner.config.name == "Elder",
		"npcTalk:SITUATION_LINES.13.when": func(s, _n = null): return s.partner != null and s.partner != _n,   # 짝 본인이 제 짝을 축하하지 않게
		"npcTalk:SITUATION_LINES.14.when": func(s, _n = null): return _boss(s, "MORGATH"),
		"npcTalk:SITUATION_LINES.15.when": func(s, _n = null): return _boss(s, "ZALGORA"),
		"npcTalk:SITUATION_LINES.16.when": func(s, _n = null): return s.player.stage_index >= 3,
		"npcTalk:SITUATION_LINES.17.when": func(s, _n = null): return s.player.hp < s.player.max_hp * 0.4,
	})


## chronicle.js 의 사건 조건. 인자 c 는 Chronicle.context()
static func _build_chronicle() -> void:
	var D := func(c, id): return c.done.call(id)
	var A := func(c, id): return c.active.call(id)
	var B := func(c, id): return c.boss.call(id)
	var ev := func(c, id): return c.s.story.get("events", []).has(id)
	var home_night := func(c): return c.night and (c.map == "VILLAGE" or c.map == "DEN_MINE")
	var near := func(c, type: String, r: float):
		for p in c.s.entities.props:
			if p.type == type and Vector2(p.x - c.s.player.x, p.y - c.s.player.y).length() < r: return true
		return false
	var only_map := func(id: String): return func(c): return c.map == id
	var w := {
		0: func(c): return c.s.story.scenes.has("ch1") and c.map == "DOJO",
		# 첫 밤: 첫날 첫 사냥을 보고하고 게시판 얘기까지 들었으면 연다 (낮이면 해 질 녘으로 건너간다 · ev.dusk).
		# 그날을 놓친 판은 예전처럼 수련을 시작한 뒤의 밤에
		1: func(c): return c.map == "VILLAGE" and ((c.day == 1 and D.call(c, "m1") and ev.call(c, "ev_board")) or (c.night and c.day >= 2 and c.lessons >= 1)),
		2: func(c): return c.map == "VILLAGE" and D.call(c, "m1"),
		3: func(c): return c.s.story.rites.has(1) and home_night.call(c),
		4: func(c): return c.map == "FALLS" and c.s.story.get("clues", []).has("mark") and ev.call(c, "ev_falls"),
		5: func(c): return D.call(c, "m3") and not D.call(c, "m4") and not A.call(c, "m4") and c.map == "HOLLOW",
		6: func(c): return A.call(c, "m5") and not B.call(c, "ZALGORA") and c.map == "JUNGLE",
		7: func(c): return D.call(c, "m5") and (D.call(c, "m5g") or B.call(c, "GLACIA")) and not D.call(c, "m5a") and not A.call(c, "m5a") and c.map == "VILLAGE",
		8: func(c): return (D.call(c, "m6w") or B.call(c, "BASIL")) and not D.call(c, "m5b") and not A.call(c, "m5b") and c.map == "DESERT",
		9: func(c): return (D.call(c, "m5c") or (D.call(c, "m5b") and B.call(c, "IGNAR"))) and not D.call(c, "m6") and not A.call(c, "m6") and c.map == "VILLAGE",   # 붉은 하늘은 마을에서 본다 (엘더·카이론이 곁에 있다)
		10: func(c): return c.map == "VILLAGE" and bool(c.s.den.get("built", false)),
		11: only_map.call("FALLS"),
		12: func(c): return c.map == "FALLS" and c.gathering,
		13: only_map.call("CLOUDTOP"),
		14: func(c): return D.call(c, "m6w") and home_night.call(c) and c.clueCount >= 3 and not c.s.raid.active,
		15: func(c): return c.map == "IGNAR_LAIR" and A.call(c, "m6") and not B.call(c, "IGNAR"),
		16: func(c): return c.map == "IGNAR_LAIR" and B.call(c, "IGNAR") and A.call(c, "m6"),
		17: func(c): return c.map == "VILLAGE" and A.call(c, "m7d") and c.route == "dark",
		18: only_map.call("ASH_CITY"),
		19: func(c): return c.map == "FALLS" and A.call(c, "m6w") and c.s.quests.active.m6w.step >= 1,
		20: func(c): return c.map == "FALLS" and c.hour >= 17 and c.hour < 20 and D.call(c, "m5g") and not c.gathering and c.datesOf.call("Haru") == 0 and not ev.call(c, "ev_tryst_mine"),
		21: func(c): return c.map == "FALLS" and c.hour >= 17 and c.hour < 20 and D.call(c, "m5g") and not c.gathering and c.datesOf.call("Haru") >= 1 and not ev.call(c, "ev_tryst"),
		22: func(c): return c.map == "VILLAGE" and c.night and A.call(c, "t1") and not c.s.raid.active \
			and Vector2(c.s.player.x - (30 * 96 + 48), c.s.player.y - (8 * 96 + 48)).length() < 300,
		23: func(c): return c.map == "VILLAGE" and D.call(c, "m5g") and c.hour >= 7 and c.hour < 18 and not c.s.raid.active and not c.flag.call("couple_egg"),
		24: func(c): return c.map == "VILLAGE" and c.flag.call("couple_egg") and not c.flag.call("couple_hatched") \
			and c.day - int(c.s.story.get("coupleEggDay", 0)) >= 6 and c.hour >= 7 and c.hour < 18 and not c.s.raid.active,
		25: func(c): return ["EAST_ROAD", "SOUTH_ROAD", "LAKE"].has(c.map) and c.raids >= 2 and D.call(c, "m4") and c.hour >= 7 and c.hour < 18 and not c.s.raid.active and not c.s.activity,
		26: func(c): return (c.map == "FALLS" or c.map == "CLOUDTOP") and D.call(c, "s1") and not c.night and not c.gathering and not D.call(c, "m6w"),
		27: func(c): return c.map == "DOJO" and c.hour >= 8 and c.hour < 12 and c.datesOf.call("Elder") >= 1 and not c.gathering,
		28: func(c): return near.call(c, "WAYSTONE", 340) and c.map != "VILLAGE" and D.call(c, "m1"),
		29: func(c): return near.call(c, "CAVE", 360) and D.call(c, "m1"),
		30: only_map.call("SKY_RUINS"),
		31: only_map.call("HOLLOW_DEEP"),
		32: only_map.call("SNOW_RIDGE"),
		33: only_map.call("JUNGLE_DEEP"),
		34: only_map.call("DESERT_BONES"),
		35: only_map.call("VOLCANO_PATH"),
		36: only_map.call("SNOW_ROAD"),
		37: func(c): return c.map == "VOLCANO" and ev.call(c, "ev_volcano") and c.s.story.rites.has(3),
		38: only_map.call("VOLCANO"),
	}
	for i in w: _table["chronicle:CHRONICLE.%d.when" % i] = w[i]
	_table["chronicle:CHRONICLE.15.choice.options.1.when"] = func(c): return c.flag.call("messenger")
	# 이그나르를 살리는 길: 단서 개수(본편만 해도 다 모인다) 대신, 카이론의 옛이야기(k2)를 들었는가
	_table["chronicle:CHRONICLE.16.choice.options.1.when"] = func(c): return c.done.call("k2")

	# ---- [세션 D] 해 질 녘 폭포 ----
	# 누구나 한 번은 보는 밀회 (설정집 5-0). 포코의 귓속말(하루와 사귀는 중이면 하루의 초대)로 s1 이 걸리고,
	# 해 질 녘 폭포에서 몰래 다가가기(Sneak)가 열린다. 성공 장면(ev_tryst · ev_tryst_mine)은 놀이가 직접 연다.
	# 여기서는 Sneak 을 부르지 않는다: 이 파일은 Data 가 뜨기 전에 컴파일되어, Sneak 을 거쳐 World · GameMap 이 먼저 불리면 깨진다.
	# 거는 자리는 tryst_hook 한 곳이다: 달맞이 모임 다음 날 아침의 마을. 5장을 다시 짜면 여기만 옮긴다
	var tryst_hook := func(c): return c.map == "VILLAGE" and c.hour >= 7 and c.hour < 13 and not c.s.raid.active \
		and ev.call(c, "ev_gathering") and int(c.s.story.get("eventDay", {}).get("ev_gathering", -1)) < c.day \
		and not A.call(c, "s1") and not D.call(c, "s1")
	# 하루와 사귀는 중: 짝이거나 데이트를 한 번 이상 했다 (마음을 접거나 헤어지면 데이트 수가 0 으로 돌아간다)
	var with_haru := func(c): return c.datesOf.call("Haru") >= 1 or (c.s.partner != null and c.s.partner.config.get("name") == "Haru")
	# 해 질 녘(18~20시) 폭포, s1 첫 대목, 하루에 한 판. 하루가 불렀으면(ev_tryst_invite) 하루 판
	var tryst_dusk := func(c, mine: bool): return c.map == "FALLS" and c.hour >= 18 and c.hour < 20 and not c.gathering \
		and A.call(c, "s1") and int(c.s.quests.active.s1.step) == 0 \
		and int(c.s.story.get("tryst", {}).get("day", -1)) != c.day and ev.call(c, "ev_tryst_invite") == mine
	_table["chronicle:CHRONICLE.ev_tryst_rumor.when"] = func(c): return tryst_hook.call(c) and not with_haru.call(c)
	_table["chronicle:CHRONICLE.ev_tryst_invite.when"] = func(c): return tryst_hook.call(c) and with_haru.call(c)
	_table["chronicle:CHRONICLE.ev_tryst_dusk.when"] = func(c): return tryst_dusk.call(c, false)
	_table["chronicle:CHRONICLE.ev_tryst_mine_dusk.when"] = func(c): return tryst_dusk.call(c, true)
	_table["chronicle:CHRONICLE.ev_tryst.when"] = func(_c): return false        # 엿들을 자리에 닿으면 Sneak 이 연다
	_table["chronicle:CHRONICLE.ev_tryst_mine.when"] = func(_c): return false

# ---- [세션 B] 조건·구조 고치기 ----
## 게시판 쪽지 · 잡담 · 일과의 갈래. 새 항목의 경로는 번호 대신 id 로 짓는다
static func _build_fix() -> void:
	_table.merge({
		# 게시판: 그론의 쪽지는 그가 떠난 뒤로 붙지 않는다. 모루 쪽지는 불이 다시 붙은 뒤(사흘) 엠버가 붙인다
		"chores:CHORES.c_goblin.when": func(s): return not _dead(s, "Gron"),
		"chores:CHORES.c_chest.when": func(s): return not _dead(s, "Gron"),
		"chores:CHORES.c_upgrade.when": func(s): return not _dead(s, "Gron"),
		"chores:CHORES.c_upgrade_ember.when": func(s): return _dead(s, "Gron") and s.day - int(s.story.get("deathDay", {}).get("Gron", s.day)) >= 3,
		# 게시판: 결말을 본 뒤로는 습격이 오지 않는다 (Raid._still_coming 과 같은 판단. Raid 를 부르면 Data 가 서기 전에 지도 스크립트까지 끌려와 튕긴다)
		"chores:CHORES.c_raid.when": func(s): return not (s.story.get("route") == "dark" and s.quests.done.has("m7d")) and s.story.get("endingSeen", "") == "",
		# 도란의 물고기 쪽지 (호수가 열린 뒤 · 모임이 다시 선 뒤) · 결말 뒤에 습격 쪽지 대신 붙는 것들
		"chores:CHORES.c_fish3.when": func(s): return Chapters.map_open(s, "LAKE") and not _dead(s, "Doran"),
		"chores:CHORES.c_fish_moon.when": func(s): return s.story.get("events", []).has("ev_gathering") and s.story.get("route") != "dark",
		"chores:CHORES.c_deep5.when": func(s): return s.story.get("endingSeen", "") != "",
		"chores:CHORES.c_elite3.when": func(s): return s.story.get("endingSeen", "") != "",
		# 잡담: 미라가 폭포 일을 털어놓은(s1) 뒤로 엘더가 모르는 척 묻지 않는다
		"chatter:CHATTER.elder_mira_falls.when": func(s): return not s.quests.done.has("s1"),
		# 잡담: 봉우리의 알 소식 뒤로 전쟁 전까지 도란이 수군거린다 (6장에서 도란이 "그 소리, 처음 꺼낸 게 나여" 하고 사과한다)
		"chatter:CHATTER.doran_rumor.when": func(s): return s.quests.done.has("m5a") and not s.quests.done.has("m6w"),
		# 바윗골의 무게: 가람은 모래 폭군(바실)이 사라진 뒤에야 빚을 갚겠다고 한다. 조건이 없어서 첫날부터 '가람에게 말을 걸어 보자'가 떴다
		"quests:QUESTS.e1.needs": func(s): return _boss(s, "BASIL"),
		# 마을 최고의 술래: 포코의 두 부탁(엿들은 말 · 술래잡기)이 첫날 한꺼번에 이어져, 첫날에 포코와 절친이 되었다. 술래잡기는 사흘째부터
		"quests:QUESTS.p2.needs": func(s): return s.day >= 3,
		# [H] 6장: 폭포 싸움터의 잿빛 비늘. 반짝이는 자리(m6w 넷째 대목의 glint) 가까이 가야 눈에 띈다
		"chronicle:CHRONICLE.ev_ash_scale.when": func(c):
			if c.map != "FALLS" or not c.active.call("m6w") or int(c.s.quests.active.m6w.step) != 3: return false
			var at: Array = Data.get_module("quests").QUESTS.filter(func(q): return q.id == "m6w")[0].steps[3].glint.at
			return Vector2(c.s.player.x, c.s.player.y).distance_to(Vector2((at[0] + 0.5) * 96, (at[1] + 0.5) * 96)) < 170,
		# 일과: 어둠의 길 끝에 나라가 떠난 뒤의 스승
		"routines:ROUTINES.Kairon.variants.after_dark.when": func(s): return s.story.get("route") == "dark" and s.quests.done.has("m7d"),
	})

# ---- [세션 C] 이야기 다시 쓰기 ----
## 이야기 쪽에서 새로 넣거나 바꾼 조건. 앞의 표와 키가 같으면 여기 것이 이긴다
## (여러 세션이 이 파일을 같이 고친다. 합칠 때 부딪히지 않게, 바꾼 조건도 원래 줄은 두고 여기서 덮는다)
static func _build_c() -> void:
	_table.merge({
		# 마을의 시선: 첫 습격을 같이 막기 전까지, 하늘에서 떨어진 아이를 꺼리는 용들이 있다.
		# 나라의 줄은 스승님이 나를 받은 걸 샘내는 말이라, 수련장에서 나라를 만난 뒤(ev_nara)부터 (첫날부터 "오늘 또 뭘 가르쳐 주셨는데?"가 나왔다)
		"npcTalk:SITUATION_LINES.wary.when": func(s, _n = null): return s.raid.count == 0 			and (_n == null or _n.config.get("name") != "Nara" or s.story.get("events", []).has("ev_nara")),
		# 첫 습격을 같이 막은 뒤 한동안은, 꺼리던 용들의 말이 조금씩 풀린다 (세 번째 습격부터는 [7] 이 받는다)
		"npcTalk:SITUATION_LINES.thaw.when": func(s, _n = null): return s.raid.count >= 1 and s.raid.count < 3,
		# 아이 안부는 짝 본인이 묻지 않는다 (제 아이를 두고 "네 아이들은 잘 크느냐"고 하던 것)
		"npcTalk:SITUATION_LINES.8.when": func(s, _n = null): return s.kids.size() > 0 and s.partner != _n,
		# 소식을 반기는 인사는 그 일이 있고 며칠 동안만 (수십 일 뒤에도 "이겼다고?!"가 나오던 것)
		"npcTalk:SITUATION_LINES.13.when": func(s, _n = null): return s.partner != null and s.partner != _n and _fresh(s.story.get("love", {}).get("since"), s),
		"npcTalk:SITUATION_LINES.14.when": func(s, _n = null): return _fresh(s.story.get("bossDay", {}).get("MORGATH"), s),
		"npcTalk:SITUATION_LINES.15.when": func(s, _n = null): return _fresh(s.story.get("bossDay", {}).get("ZALGORA"), s),

		# ---- 3장: 모르가스와의 우연한 마주침 ----
		# 골짜기에 처음 들어서면 울음이 들린다 (수호룡은 이 장면을 본 뒤에야 무덤에 나온다: enemies BOSSES.MORGATH.needs)
		"chronicle:CHRONICLE.5.when": func(c): return c.done.call("m3") and not c.boss.call("MORGATH") and (c.map == "HOLLOW" or c.map == "HOLLOW_DEEP"),
		# 성체가 된 날, 누리가 골짜기 끝으로 사라진다
		"chronicle:CHRONICLE.ev_nuri_lost.when": func(c): return c.map == "VILLAGE" and c.s.story.rites.has(2) and c.done.call("m3") \
			and not c.active.call("m4") and not c.done.call("m4") and not c.boss.call("MORGATH"),
		# 무덤은 누리를 찾으러 갈 때 열린다
		"chapters:CHAPTERS.c3.hold.MORGATH_LAIR.when": func(s): return s.quests.active.has("m4") or s.quests.done.has("m4") or _boss(s, "MORGATH"),

		# ---- 4장: 굶는 계절 ----
		# 모르가스를 보낸 뒤 마을로 돌아오면, 해 질 녘 빈 걸이대 (잘고라를 잡으러 갈 까닭. 고기를 소이에게 건네는 m5h 가 걸린다)
		"chronicle:CHRONICLE.ev_hunger.when": func(c): return c.map == "VILLAGE" and c.done.call("m4") and not c.active.call("m5h") and not c.done.call("m5h") \
			and not c.active.call("m5") and not c.done.call("m5") and not c.s.raid.active,
		# 뿌리골의 부탁은 쌍두룡을 보낸 뒤에 ("쌍두룡을 보내 준 게 너라고 들었단다")
		"quests:QUESTS.r1.needs": func(s): return _boss(s, "ZALGORA"),

		# ---- 5장: 맡긴 알 ----
		# 한여름 눈은 밀회(s1 둘째 대목) 사흘째부터: 유안이 "내일 봉우리에 오른다"고 한 다음 날 사절이 떠나고, 그 뒤에 봉우리가 문을 닫는다
		"chronicle:CHRONICLE.7.when": func(c): return c.map == "VILLAGE" and c.done.call("m5g") and not c.done.call("m5a") and not c.active.call("m5a") \
			and _snow_due(c.s),
		# 경계석의 유안: 봉우리에서 돌아온 뒤, 폭포의 대치 전까지 (밀회 뒤 그 사이에는 유안이 봉우리에 갇혀 있다)
		"chronicle:CHRONICLE.26.when": func(c): return (c.map == "FALLS" or c.map == "CLOUDTOP") and c.done.call("m5a") and not c.night and not c.gathering \
			and c.s.story.has("trystDay") and not c.s.story.get("events", []).has("ev_border"),
		# 얼어붙은 망루에서 다친 사절 둘을 찾는다
		"chronicle:CHRONICLE.32.when": func(c): return c.map == "SNOW_RIDGE" and c.active.call("m5a") and not c.boss.call("GLACIA"),
		# 도란과 미루의 알 소식은 눈이 그친 뒤에 (눈이 쏟아지는 한가운데 태평한 소식이 끼어들던 것)
		"chronicle:CHRONICLE.23.when": func(c): return c.map == "VILLAGE" and c.done.call("m5a") and c.hour >= 7 and c.hour < 18 \
			and not c.s.raid.active and not c.flag.call("couple_egg"),
		# 마을의 시선: 봉우리의 알이 하나도 안 남았다는 걸 안 뒤로 수군거림이 돈다
		"npcTalk:SITUATION_LINES.chill.when": func(s, _n = null): return s.quests.done.has("m5a") and not s.quests.done.has("m6w"),
		# 그론을 보낸 뒤: 수군거림을 처음 꺼낸 이가 먼저 와서 사과한다
		# (도란 · 미루의 줄은 평상에서 사과를 들은 뒤로는 되풀이하지 않는다)
		"npcTalk:SITUATION_LINES.family.when": func(s, _n = null): return s.quests.done.has("m6w") and not s.quests.done.has("m5c") \
			and not (_n != null and ["Doran", "Miru"].has(_n.config.get("name")) and s.story.get("events", []).has("ev_doran_sorry")),

		# ---- 7장: 사막 길 ----
		# 바윗골과 불탄 도시는 모래 폭군이 비킨 뒤에 (바실을 잡기 전에 가면 "모래 폭군을 네가 잡았다고 들었다"가 틀린 말이 되던 것)
		"chapters:CHAPTERS.c7.hold.STONEBACK.when": func(s): return _boss(s, "BASIL"),
		"chapters:CHAPTERS.c7.hold.ASH_CITY.when": func(s): return _boss(s, "BASIL"),
		# 세이란의 물점: 리운과 이야기를 마치면 그 자리(구름마루)에서 이어진다
		"chronicle:CHRONICLE.ev_seiran_water.when": func(c): return c.map == "CLOUDTOP" and c.active.call("m5c") and int(c.s.quests.active.m5c.step) >= 3,

		# ---- 8장: 잿마루 ----
		# 정상의 바람은 고룡의 날개로만 뚫린다 (힌트로만 말하던 것을 길로도)
		"chapters:CHAPTERS.c8.hold.IGNAR_LAIR.when": func(s): return s.player.stage_index >= 3 or _boss(s, "IGNAR"),
		# 잿마루에서 그날 밤의 밤손님을 알아본다
		"chronicle:CHRONICLE.ev_heukdan.when": func(c): return c.map == "VOLCANO" and c.s.story.get("events", []).has("ev_volcano") and c.flag.call("messenger"),

		# ---- 나라 줄기: 스승님의 제자 ----
		# 어둠의 길로 들어선 판에서는 나라가 마을을 떠난다
		"quests:QUESTS.n3.needs": func(s): return s.story.get("route") != "dark",
		# 엘더와 함께 수련장에 들어서면 엘더가 약속을 거둔다
		"chronicle:CHRONICLE.ev_nara_trial.when": func(c): return c.map == "DOJO" and c.active.call("n3") and int(c.s.quests.active.n3.step) == 2,

		# ---- 마을 이웃 이야기 ----
		# 도란의 '큰 놈': 호수가 열리고, 바늘을 보여 줄 그론이 살아 있을 때
		"quests:QUESTS.dr1.needs": func(s): return Chapters.map_open(s, "LAKE") and not _dead(s, "Gron"),
		# 단네 저녁상: 누리를 골짜기에서 찾아 준 뒤
		"quests:QUESTS.sn1.needs": func(s): return s.quests.done.has("m4"),
		# 해가 지면 단 · 소이네 집 앞에서
		"chronicle:CHRONICLE.ev_nuri_dinner.when": func(c): return c.map == "VILLAGE" and c.active.call("sn1") and int(c.s.quests.active.sn1.step) == 0 \
			and c.hour >= 17 and c.hour < 22 and Vector2(c.s.player.x - (26 * 96 + 48), c.s.player.y - (19 * 96 + 48)).length() < 380,
		# 저녁상 다음 날 낮, 단이 나무하는 숲 어귀에서
		"chronicle:CHRONICLE.ev_nuri_forest.when": func(c): return c.map == "EAST_ROAD" and c.active.call("sn1") and int(c.s.quests.active.sn1.step) == 1 \
			and c.hour >= 7 and c.hour < 16 and c.day > int(c.s.story.get("eventDay", {}).get("ev_nuri_dinner", c.day)),
		# 하루 · 세이란 · 유안 · 엠버: 어둠의 길로 들어선 판에서는 구름마루와 마을이 갈라선다
		"quests:QUESTS.hr1.needs": func(s): return s.quests.done.has("m6w") and s.story.get("route") != "dark",
		# 같이 자라기: 포코는 그론을 보낸 다음 날부터 성체 시험을 청하고, 하루는 징검돌 뒤에 성년례를 치른다
		"quests:QUESTS.p3.needs": func(s): return _dead(s, "Gron") and s.day > int(s.story.get("deathDay", {}).get("Gron", 99999)) and s.story.get("route") != "dark",
		"quests:QUESTS.hr2.needs": func(s): return s.quests.done.has("hr1") and s.story.get("route") != "dark",
		"chronicle:CHRONICLE.ev_poco_trial.when": func(c): return c.map == "DOJO" and _step(c.s, "p3") == 0 and c.hour >= 7 and c.hour < 18,
		"chronicle:CHRONICLE.ev_haru_rite.when": func(c): return c.map == "CLOUDTOP" and _step(c.s, "hr2") == 0 and c.hour >= 6 and c.hour < 18,
		"quests:QUESTS.sr1.needs": func(s): return s.quests.done.has("m5c") and s.story.get("route") != "dark",   # 샘물이 맑아진 뒤 (5장 모임 때는 물이 흐려 읽지 못했다)
		"quests:QUESTS.yu1.needs": func(s): return s.quests.done.has("m5c") and s.story.get("route") != "dark",
		"quests:QUESTS.em1.needs": func(s): return s.quests.done.has("m5b") and s.story.get("route") != "dark",
		# 하루의 조약돌: 마을 광장 분수 둘레에서
		"chronicle:CHRONICLE.ev_haru_pebble.when": func(c): return c.map == "VILLAGE" and _step(c.s, "hr1") == 0 \
			and Vector2(c.s.player.x - (17 * 96 + 48), c.s.player.y - (12 * 96 + 48)).length() < 300,
		# 징검돌: 낮에 폭포 아래에서
		"chronicle:CHRONICLE.ev_haru_stones.when": func(c): return c.map == "FALLS" and _step(c.s, "hr1") == 2 and c.hour >= 7 and c.hour < 18,
		# 세이란의 샘: 밤에 구름마루에서
		"chronicle:CHRONICLE.ev_seiran_pool.when": func(c): return c.map == "CLOUDTOP" and _step(c.s, "sr1") == 0 and (c.hour >= 20 or c.hour < 4),
		# 누이의 알: 봉우리의 알 벽 앞에서 · 망루 자리: 낮에 폭포 아래에서
		"chronicle:CHRONICLE.ev_yuan_egg.when": func(c): return c.map == "GLACIA_LAIR" and _step(c.s, "yu1") == 0,
		"chronicle:CHRONICLE.ev_yuan_tower.when": func(c): return c.map == "FALLS" and _step(c.s, "yu1") == 1 and c.hour >= 7 and c.hour < 18,
		# 미루의 옛 둥지: 새 알이 생긴 뒤 깨기 전까지 · 도란네 집 뒤에서
		"quests:QUESTS.mi1.needs": func(s): return _flag(s, "couple_egg") and not _flag(s, "couple_hatched") and s.story.get("route") != "dark",
		"chronicle:CHRONICLE.ev_miru_nest.when": func(c): return c.map == "VILLAGE" and _step(c.s, "mi1") == 0 \
			and Vector2(c.s.player.x - (6 * 96 + 48), c.s.player.y - (10 * 96 + 48)).length() < 350,
		# 도란의 사과: 그론을 보낸 뒤, 저녁에 도란네 집 앞을 지나면 미루가 불러 앉힌다
		"chronicle:CHRONICLE.ev_doran_sorry.when": func(c): return c.map == "VILLAGE" and c.done.call("m6w") and c.s.story.get("route") != "dark" \
			and c.hour >= 16 and c.hour < 22 and Vector2(c.s.player.x - (6 * 96 + 48), c.s.player.y - (10 * 96 + 48)).length() < 350,
	}, true)


## 맡고 있는 퀘스트의 지금 대목 번호. 안 맡았으면 -1
static func _step(s, id: String) -> int:
	var e = s.quests.active.get(id)
	return int(e.step) if e else -1


## 5장: 봉우리에 눈이 퍼부을 때가 되었는가. 밀회를 본 날(Chronicle 이 적는다)로부터 사흘째.
## 밀회가 아예 걸리지 않은 판(s1 이 시작도 안 됐다)이면 모임 닷새째에 그냥 온다 — 이야기가 거기서 멈추지 않게
static func _snow_due(s) -> bool:
	var tryst = s.story.get("trystDay")
	if tryst != null: return s.day - int(tryst) >= 3
	if s.quests.active.has("s1") or s.quests.done.has("s1"): return false
	var met = s.story.get("eventDay", {}).get("ev_gathering")
	return met == null or s.day - int(met) >= 5


const NEWS_DAYS := 5   # 소식이 소식인 동안 (날)

## 그 일이 있은 날(day)로부터 며칠 안 됐는가. 적힌 날이 없으면 아니다
static func _fresh(day, s) -> bool:
	return day != null and s.day - int(day) < NEWS_DAYS


# ---- [세션 G] 원정대 ----
## 이야기 동료가 들고 나는 자리. 새 항목의 경로는 id 로 짓는다
static func _build_g() -> void:
	_table.merge({
		# 7장: 바실을 보낸 뒤 불탄 도시로 가는 길, 사막 입구에서 바윗골의 가람이 길잡이로 나선다 (party.json STORY 의 after)
		"chronicle:CHRONICLE.ev_garam_guide.when": func(c): return c.map == "DESERT" and c.active.call("m5c") and int(c.s.quests.active.m5c.step) == 0,
	})
