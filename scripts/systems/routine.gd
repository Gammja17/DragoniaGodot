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


## 그날 이 시각까지의 자리 가운데 내가 갈 수 있는 마지막 자리 (없으면 전날 밤의 갈 수 있는 자리).
## 하나도 없으면 그대로 둔다 (구름마루에 사는 용은 구름마루에 있다)
static func _open_slot(routine: Dictionary, hour: float, slot: Dictionary) -> Dictionary:
	var best = null
	var last = null
	for s in routine.day:
		if not Chapters.map_open(GameState, s.map): continue
		last = s
		if s.h <= hour: best = s
	if best == null: best = last
	return best if best != null else slot


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
	# 일과의 자리가 아직 내가 갈 수 없는 곳(장이 막아 둔 지도)이면, 그날 앞서 있던 갈 수 있는 자리에 머문다.
	# 1장에 포코가 호수로 가 버리면 고기를 건네러 따라갈 수도 없이 세 시간을 기다려야 했다
	if not Chapters.map_open(GameState, slot.map): slot = _open_slot(base, hour, slot)
	var home = Den.partner_home(name, slot)   # 같이 사는 짝이 잘 자리 (내 굴). 아니면 null
	if home == null: home = Den.guest_slot(name, hour)   # 오늘 저녁 내 굴에 놀러 온 손님
	var spot = Gathering.spot_of(name) if Gathering.is_gather_now() else null   # 모임에서 앉을 자리 (이야기에 따라 바뀐다)
	var gather: bool = spot != null
	# 길잡이를 마치기 전에는 촌장이 마을을 뜨지 않는다. 처음 온 아이가 헤매지 않게
	# (모임 날 밤만은 예외다 — 촌장이 빠진 모임은 모임이 아니다)
	if name == "Elder" and not gather and not GameState.tutorial.get("finished", false):
		for d in r.day:
			if d.h == 9:
				slot = d
				break
	# 달이 가장 밝은 밤에는 두 마을이 모두 폭포 아래로 내려온다
	if gather: slot = { map = Gathering.GATHER_MAP, spot = spot, doing = Gathering.doing_of(name) }
	var own = variant if variant != null else r
	# 습격 때 설 자리. raidAfter 는 그 용이 떠난 뒤의 자리다 (그론을 보낸 뒤로 포코는 모루 밑에 숨지 않는다)
	var raid_slot = own.get("raid")
	if own.get("raidAfter") and is_dead(own.raidAfter.of): raid_slot = own.raidAfter
	if GameState.raid.active and raid_slot: slot = raid_slot   # 마을이 불타는 것보다 급한 모임은 없다
	if GameState.raid.active and GameState.raid.get("kind") == "war" and WAR_AWAY.has(name):
		slot = { map = "FALLS", spot = [10, 10], doing = "폭포에서 마을로 달려오고 있다" }
	elif not (GameState.raid.active and raid_slot) and not Gathering.is_gather_now() and own.get("rain") and (GameState.weather.type == "RAIN" or GameState.weather.type == "SNOW"):   # 습격 칸을 비 칸이 덮지 않게
		slot = own.rain
	# 짝은 제 굴 대신 내 굴에서 잔다. 손님은 저녁에 내 굴에 들른다. 비가 와도 그대로이고, 모임과 습격이 먼저다
	if home and not gather and not GameState.raid.active: slot = home
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


# ---------- 매 프레임: 걸어서 들고 나기 ----------

const WALK := 150.0          # 들고 나는 걸음 속도
const ARRIVED := 56.0        # 목표에 이만큼 가까워지면 다 온 것으로 친다
static var _tick := 0.0
static var _was := {}        # 용마다 지난번에 있기로 되어 있던 곳 (굴에서 나오면 그 굴 입구로 나오게)


## 수련·대련의 상대이거나 지금 말을 나누는 중이면 일과 시간이 돼도 자리를 뜨지 않는다
static func _tied_to_player(npc) -> bool:
	var a = GameState.activity
	if a and (a.get("npc") == npc or a.get("rival") == npc): return true
	if GameState.isDialogueOpen and GameState.currentNpc == npc: return true
	return npc.state != "WANDER"


static func _find_npc(nm: String):
	for n in GameState.entities.npcs:
		if n.config.get("name") == nm: return n
	return null


## 지도 가장자리에서 제일 가까운 포탈 (들고 날 문)
static func _nearest_portal(x: float, y: float):
	var best = null
	var best_d := INF
	for p in GameState.entities.props:
		if not p.portal: continue
		var d := Vector2(p.x - x, p.y - y).length()
		if d < best_d:
			best_d = d
			best = p
	return best


## 들고 날 문. 가는 곳(온 곳)이 이 지도에 입구를 둔 굴이면 그 굴 입구, 아니면 가장 가까운 가장자리 문
## (북쪽 제 굴로 자러 가는 촌장이 남쪽 문으로 나가던 것)
static func _door(to: String, x: float, y: float):
	for p in GameState.entities.props:
		if p.type == "DEN_MOUTH" and p.den_id == to: return p
	return _nearest_portal(x, y)


## 매 프레임. 1초에 한 번 일과를 다시 읽고, 바뀐 만큼만 움직인다
static func update(dt: float, get_npc: Callable) -> void:
	# 걷는 중인 용은 매 프레임 옮긴다
	for npc in GameState.entities.npcs:
		if not npc.walk_to or _tied_to_player(npc): continue
		var dx: float = npc.walk_to.x - npc.x
		var dy: float = npc.walk_to.y - npc.y
		if Vector2(dx, dy).length() < ARRIVED:
			if npc.walk_to.get("leave"): npc.remove = true      # 문을 나섰다
			npc.walk_to = null
			continue
		var speed: float = npc.walk_to.get("speed", WALK)
		var before := Vector2(npc.x, npc.y)
		npc.move_by(dx, dy, speed, dt)
		# 잡동사니에 걸려 제자리걸음이면 좌우로 번갈아 비켜 걷는다. 끝내 못 가면 그 자리에서 멈춘다
		# (일과의 중심 home 은 이미 옮겨 두었으니 거기서부터 어슬렁댄다). 마을이 넓어져 걷는 길이 길어졌다
		var stuck: float = npc.get_meta("walk_stuck", 0.0)
		stuck = stuck + dt if Vector2(npc.x, npc.y).distance_to(before) < speed * dt * 0.2 else 0.0
		npc.set_meta("walk_stuck", stuck)
		if stuck > 0.8:
			var side := 1.0 if fmod(stuck, 3.0) < 1.5 else -1.0
			npc.move_by(-dy * side, dx * side, speed, dt)
		if stuck > 4.0:
			if npc.walk_to.get("leave"): npc.remove = true   # 나가려던 문 앞에서 끝내 막혔으면 나간 셈 친다 (굴 입구는 바위 틈에 있기도 하다)
			npc.walk_to = null
			npc.set_meta("walk_stuck", 0.0)
	Gathering.update(dt)   # 모임이 선 폭포: 이 단계에 처음 온 밤의 장면 · 주고받는 말

	_tick -= dt
	if _tick > 0: return
	_tick = 1.0
	Den.update_guest()   # 저녁이 되면 오늘 손님을 정한다
	if GameState.dungeon: return

	var here := GameState.map_id
	for nm in routine_names():
		var plan = plan_for(nm)
		if not plan:
			var gone = _find_npc(nm) if is_dead(nm) else null
			if gone: gone.remove = true
			continue
		var was: String = _was.get(nm, plan.map)
		_was[nm] = plan.map
		var npc = _find_npc(nm)
		if npc and _tied_to_player(npc):   # 나를 따라다니는 중
			npc.walk_to = null
			continue
		if nm == "Poco" and GameState.tour: continue   # 첫날 마을을 데리고 도는 중 (Tour)

		if npc:
			npc.doing = plan.doing
			npc.job = plan.job
			if plan.map == here:
				# 같은 지도 안에서 자리만 옮긴다 — 어슬렁대는 중심을 바꿔 주면 알아서 간다
				if Vector2(npc.home_x - plan.x, npc.home_y - plan.y).length() > 60:
					npc.home_x = plan.x; npc.home_y = plan.y
					npc.walk_to = { x = plan.x, y = plan.y }
			elif not npc.walk_to or not npc.walk_to.get("leave"):
				var gate = _door(plan.map, npc.x, npc.y)                # 문으로 걸어 나간다
				npc.walk_to = { x = gate.x, y = gate.y, leave = true } if gate else null
				if not gate: npc.remove = true
			continue

		# 여기 있어야 하는데 없다 — 문으로 걸어 들어온다
		if plan.map != here: continue
		var gate = _door(was, plan.x, plan.y)
		var from := Vector2(gate.x, gate.y) if gate else Vector2(plan.x, plan.y)
		var fresh = get_npc.call(nm, from)
		fresh.x = from.x; fresh.y = from.y
		fresh.remove = false
		fresh.is_hidden = false
		fresh.home_x = plan.x; fresh.home_y = plan.y
		fresh.doing = plan.doing
		fresh.job = plan.job
		fresh.walk_to = { x = plan.x, y = plan.y }
		World.add_entity("npcs", fresh)


## 일지에 뿌릴 표: 누가 어디서 무엇을 하는지
static func roster() -> Array:
	var fixed: Array = Data.get_module("npcs").FIXED_NPCS
	var out := []
	for nm in routine_names():
		if is_dead(nm): continue
		var npc = _find_npc(nm)
		var plan = plan_for(nm)
		if plan == null and npc == null: continue
		var here: bool = npc != null and _tied_to_player(npc)
		var east := false
		for d in fixed:
			if d.name == nm: east = bool(d.get("east", false))
		var m: String = GameState.map_id if here else (plan.map if plan else "")
		out.append({
			name = nm, label = Names.npc(nm), job = plan.job if plan else "",
			map = m, where = "나와 함께 있다" if here else (plan.mapName if plan else "?"),
			doing = "나를 따라다니고 있다" if here else (plan.doing if plan else ""),
			near = m == GameState.map_id, east = east,
			relation = npc.relation if npc else World.any_npc(nm).relation if World.any_npc(nm) else 0.0,
		})
	return out
