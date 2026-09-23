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
		"SCALE3": func(r): return "허기 소모 -%d%%" % roundi(r * 8),
		"SCALE4": func(_r = 0): return "하루 한 번, 쓰러질 공격을 체력 1로 버티고 3초간 무적",
		"WING1": func(r): return "이동 속도 +%d%%" % roundi(r * 3),
		"WING2": func(r): return "대시 재사용 대기 -%d%%" % roundi(r * 8),
		"WING3": func(r): return "스킬 대기 시간 -%d%%" % roundi(r * 4),
		"WING4": func(_r = 0): return "대시한 뒤 3초 동안 브레스 연사 속도 +35%",
	}
	var order := ["FANG1", "FANG2", "FANG3", "FANG4", "SCALE1", "SCALE2", "SCALE3", "SCALE4", "WING1", "WING2", "WING3", "WING4"]
	for i in order.size():
		_table["growth:GROWTH_NODES.%d.desc" % i] = descs[order[i]]
		_table["growth:NODES_BY_ID.%s.desc" % order[i]] = descs[order[i]]
