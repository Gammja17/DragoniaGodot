class_name Routine
## 2D판 systems/routine.js 가운데 "지도에 들어설 때 누가 어디 있는가". 표는 data/routines.json.
##
## 스타듀처럼, 용마다 시간대별로 있는 자리와 하는 일이 정해져 있다.
## 지도에 들어설 때 지금 그 지도에 있기로 되어 있는 용만 깔린다.
## (시간이 흘러 칸이 바뀔 때 걸어 나가고 들어오는 것은 하루의 흐름을 옮길 때 붙인다)

const ROOM_PAD := 2   # world/room.js 의 방 둘레 바위 두께
# 6장, 마을이 습격당하는 밤에 폭포에서 구름마루와 대치하고 있는 용들
const WAR_AWAY := ["Tiamat", "Kairon", "Nara"]


static func routines() -> Dictionary:
	return Data.get_module("routines").ROUTINES


static func has_routine(name: String) -> bool:
	return routines().has(name)


static func routine_names() -> Array:
	return routines().keys()


## 이야기에서 죽은 용 (state.story.dead)
static func is_dead(name: String) -> bool:
	return GameState.story.get("dead", []).has(name)


## 하루의 칸 가운데 hour 시에 해당하는 것. 하루의 마지막 칸이 자정을 넘어 이어진다
static func slot_at_hour(routine: Dictionary, hour: float) -> Dictionary:
	var day: Array = routine.day
	var best: Dictionary = day[-1]
	for s in day:
		if s.h <= hour: best = s
	return best


## 지금 이 용이 어디서 무엇을 하고 있는가
static func plan_for(name: String, hour := -1.0):
	if hour < 0: hour = GameState.dayTime * 24
	var r = routines().get(name)
	if r == null or is_dead(name) or (r.get("when") and not r.when.call(GameState)): return null
	var variant = null   # 이야기의 갈래에 따라 하루가 통째로 다른 용
	for v in r.get("variants", []):
		if v.when.call(GameState):
			variant = v
			break
	var base = variant
	if base == null:
		base = r.after if r.get("after") and is_dead(r.after.of) else r
	var slot := slot_at_hour(base, hour)
	var gather := Gathering.is_gather_now() and Gathering.GATHER_SPOTS.has(name)
	# 길잡이를 마치기 전에는 촌장이 마을을 뜨지 않는다. 처음 온 아이가 헤매지 않게
	# (모임 날 밤만은 예외다 — 촌장이 빠진 모임은 모임이 아니다)
	if name == "Elder" and not gather and not GameState.tutorial.get("finished", false):
		for d in r.day:
			if d.h == 9:
				slot = d
				break
	# 달이 가장 밝은 밤에는 두 마을이 모두 폭포 아래로 내려온다
	if gather: slot = { map = Gathering.GATHER_MAP, spot = Gathering.GATHER_SPOTS[name], doing = "달 밝은 밤의 모임에 나와 있다" }
	var own = variant if variant != null else r
	if GameState.raid.active and own.get("raid"): slot = own.raid   # 마을이 불타는 것보다 급한 모임은 없다
	if GameState.raid.active and GameState.raid.get("kind") == "war" and WAR_AWAY.has(name):
		slot = { map = "FALLS", spot = [10, 10], doing = "폭포에서 마을로 달려오고 있다" }
	elif not Gathering.is_gather_now() and own.get("rain") and (GameState.weather.type == "RAIN" or GameState.weather.type == "SNOW"):
		slot = own.rain
	var maps: Dictionary = Data.get_module("maps").MAPS
	var dens: Dictionary = Data.get_module("dens").DENS
	if not maps.has(slot.map) and not dens.has(slot.map): return null
	var plan := { job = r.job, map = slot.map, mapName = Names.map(slot.map), doing = slot.doing }
	var TILE := GameMap.TILE
	if dens.has(slot.map):
		plan.x = (ROOM_PAD + slot.spot[0]) * TILE + TILE / 2.0
		plan.y = (ROOM_PAD + slot.spot[1]) * TILE + TILE
	else:
		plan.x = GameMap.coarse_center(slot.spot[0])
		plan.y = GameMap.coarse_center(slot.spot[1])
	return plan


## 지금 이 지도에 있어야 하는 용들의 이름
static func who_is_on(map_id: String, hour := -1.0) -> Array:
	var out := []
	for n in routine_names():
		var p = plan_for(n, hour)
		if p and p.map == map_id: out.append(n)
	return out


## 지도를 새로 깔 때 World 가 부른다. 일과가 있는 용은 여기서만 놓는다
static func place_by_routine(map_id: String, pools: Dictionary, get_npc: Callable) -> void:
	for name in who_is_on(map_id):
		var plan = plan_for(name)
		var npc = get_npc.call(name, Vector2(plan.x, plan.y))
		if pools.npcs.has(npc): continue
		npc.x = plan.x; npc.y = plan.y
		npc.home_x = plan.x; npc.home_y = plan.y
		npc.doing = plan.doing
		npc.job = plan.job
		npc.walk_to = null
		npc.remove = false    # 딴 지도에서 문을 나서며 지워졌던 용이면 표시가 남아 있다
		npc.is_hidden = false    # 프롤로그가 감춰 둔 채 남아 있으면 투명인간이 된다
		pools.npcs.append(npc)
