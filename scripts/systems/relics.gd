class_name Relics
## 2D판 systems/relics.js 가운데 "지금 끼고 있는가". 유물을 얻고 고르는 것은 3단계 뒷부분에서.

# 몸이 자랄수록 유물을 더 걸 수 있다 (해츨링 · 어린 용 · 성체 · 고룡 · 삼원룡)
const SLOTS_BY_STAGE := [1, 2, 3, 4, 4]


static func slot_count() -> int:
	return SLOTS_BY_STAGE[GameState.player.stage_index if GameState.player else 0]


static func equipped() -> Array:
	return GameState.relicSlots.slice(0, slot_count()).filter(func(id): return id != null)


static func has(id: String) -> bool:
	return GameState.relicSlots.slice(0, slot_count()).has(id)


## 같은 갈래(kin)의 유물을 둘 이상 끼면 공명한다
static func resonates(kin: String) -> bool:
	var relics: Dictionary = Data.get_module("systems_relics").RELICS
	return equipped().filter(func(id): return relics.has(id) and relics[id].get("kin") == kin).size() >= 2
