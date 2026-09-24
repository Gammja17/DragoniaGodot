class_name Relics
## 2D판 systems/relics.js. 유물을 얻고 끼운다. 표는 data/systems_relics.json.
## 셋 중 하나 고르기(relicOffer)는 대화창을 옮길 때, 끼우고 빼는 화면은 일지를 옮길 때.

# 몸이 자랄수록 유물을 더 걸 수 있다 (해츨링 · 어린 용 · 성체 · 고룡)
const SLOTS_BY_STAGE := [1, 2, 3, 4]


static func table() -> Dictionary:
	return Data.get_module("systems_relics").RELICS


## 칸 배열을 늘 최대 길이로 맞춰 둔다 (앞쪽 slot_count() 칸만 실제로 쓴다)
static func slots() -> Array:
	while GameState.relicSlots.size() < SLOTS_BY_STAGE[-1]: GameState.relicSlots.append(null)
	return GameState.relicSlots


static func owns(id: String) -> bool:
	return GameState.relics.has(id)


static func grant(id: String, x: float, y: float) -> bool:
	if owns(id): return false
	GameState.relics.append(id)
	var r: Dictionary = table()[id]
	var list := slots()
	var free := -1                                   # 빈 칸이 있으면 바로 끼워 준다
	for i in slot_count():
		if list[i] == null:
			list[i] = id; free = i
			break
	Hud.pop("유물 획득: [%s]. %s" % [r.name, r.desc] + (" (바로 끼웠다)" if free >= 0 else " ([J] 일지 유물 탭에서 끼울 수 있습니다)"), "💎")
	Vfx.spawn_effect("RING", x, y - 30, { size = 1.6 })
	Sfx.play("relic")
	return true


## 아직 없는 일반 유물 중 하나 (다 모았으면 null)
static func random_relic():
	var pool := table().keys().filter(func(id): return not table()[id].get("boss") and not table()[id].get("gift") and not owns(id))
	return pool.pick_random() if not pool.is_empty() else null


static func boss_relic(boss_id: String):
	for id in table():
		if table()[id].get("boss") == boss_id: return id
	return null


static func slot_count() -> int:
	return SLOTS_BY_STAGE[GameState.player.stage_index if GameState.player else 0]


static func equipped() -> Array:
	return GameState.relicSlots.slice(0, slot_count()).filter(func(id): return id != null)


static func has(id: String) -> bool:
	return GameState.relicSlots.slice(0, slot_count()).has(id)


## 같은 갈래(kin)의 유물을 둘 이상 끼면 공명한다
static func resonates(kin: String) -> bool:
	return equipped().filter(func(id): return table().has(id) and table()[id].get("kin") == kin).size() >= 2


## 끼우거나 뺀다 (일지 유물 탭). 칸이 차 있으면 알려 준다
static func toggle(id: String) -> bool:
	if not owns(id): return false
	var list := slots()
	var mx := slot_count()
	var at := list.find(id)
	if at >= 0 and at < mx:   # 빼기
		list[at] = null
		Sfx.play("ui")
		return true
	for i in mx:
		if list[i] == null:
			list[i] = id
			Sfx.play("relic")
			return true
	Hud.pop("유물 칸이 %d칸뿐입니다. 끼운 것을 먼저 빼세요. (몸이 자라면 칸이 늘어납니다)" % mx, "💎")
	return false
