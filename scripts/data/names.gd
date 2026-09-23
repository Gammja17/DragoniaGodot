class_name Names
## 화면에 보여 줄 이름. 안쪽에서는 영문 키를 그대로 쓴다 (대사·퀘스트·세이브가 이 키로 묶여 있다).
## 2D판 data/npcs.js 의 npcName, data/maps.js 의 mapName.


static func npc(id: String) -> String:
	var npcs: Dictionary = Data.get_module("npcs")
	return npcs.NAME_OVERRIDES.get(id, npcs.NPC_NAMES_KO.get(id, id if id != "" else "???"))


static func map(id: String) -> String:
	var maps: Dictionary = Data.get_module("maps").MAPS
	var dens: Dictionary = Data.get_module("dens").DENS
	if maps.has(id): return maps[id].name
	if dens.has(id): return dens[id].name
	return id
