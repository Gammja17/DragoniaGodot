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
	_build_c()


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
		"quests:QUESTS.2.needs": func(s): return _scene_seen(s, "ch1"),
		"quests:QUESTS.6.needs": func(s): return not s.quests.done.has("m5a") and not s.quests.active.has("m5a"),
		"quests:QUESTS.10.needs": func(s): return not _boss(s, "IGNAR"),
		"quests:QUESTS.17.needs": func(s): return s.quests.done.has("m3") and not _dead(s, "Gron"),
		"quests:QUESTS.18.needs": _lessons_at(2),
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
		"story:TRIALS.1.needs": func(s): return _lessons(s) >= 2 and s.quests.done.has("m3"),

		# ---- training.js: 스승이 쉬는 날 · 데리고 나가는 날 ----
		"training:RESTS.0.when": func(_s = null): return true,
		"training:RESTS.1.when": _lessons_at(2),
		"training:RESTS.2.when": _lessons_at(4),
		"training:TRIPS.0.when": func(_s = null): return true,
		"training:TRIPS.1.when": _lessons_at(3),
		"training:TRIPS.2.when": func(s): return _boss(s, "MORGATH"),
	}
	# ---- ceremony.js: 승급 의식 대사. 숨결 × 구름마루를 겪었는가 조합마다 미리 뽑아 둔 것에서 이름만 채운다 ----
	for stage in ["1", "2", "3", "4"]:
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
		1: func(c): return c.night and c.day >= 2 and c.lessons >= 1 and c.map == "VILLAGE",
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
	_table["chronicle:CHRONICLE.16.choice.options.1.when"] = func(c): return c.clueCount >= 4


# ---- [세션 C] 이야기 다시 쓰기 ----
## 이야기 쪽에서 새로 넣거나 바꾼 조건. 앞의 표와 키가 같으면 여기 것이 이긴다
## (여러 세션이 이 파일을 같이 고친다. 합칠 때 부딪히지 않게, 바꾼 조건도 원래 줄은 두고 여기서 덮는다)
static func _build_c() -> void:
	_table.merge({
		# 마을의 시선: 첫 습격을 같이 막기 전까지, 하늘에서 떨어진 아이를 꺼리는 용들이 있다
		"npcTalk:SITUATION_LINES.wary.when": func(s, _n = null): return s.raid.count == 0,
	}, true)
