class_name World
## 2D판 systems/world.js. 여러 장의 지도를 오가는 살림살이.
##
##  · 지도는 한 번 만들면 캐시해 둔다 (같은 씨앗이라 다시 와도 모양이 같다)
##  · 들어갈 때마다 그 지도의 개체(소품·NPC·적)를 새로 깐다. 기억해야 하는 것만 따로 남긴다
##      NPC      이름으로 캐시해 두고 다시 쓴다 (호감도·데이트 횟수가 살아 있어야 한다)
##      보물상자 GameState.openedChests['지도id:번호'] 로 기억한다
##  · 개체 노드는 container(y 정렬되는 World 노드) 아래에 붙는다
##  · 짝·동료·아이들은 언제나 따라다닌다

const PORTAL_RANGE := 62
const EDGE_WALL := 2          # 가장자리 몇 칸을 나무로 막을지 (큰 칸 수)
const OPPOSITE := { "N": "S", "S": "N", "E": "W", "W": "E" }
# 지역 이름 밑에 한 줄로 붙는 설명
const BIOME_LABEL := {
	"VILLAGE": "용들의 마을", "FOREST": "푸른 숲", "LAKE": "물가", "HOLLOW": "달빛이 고인 골짜기",
	"JUNGLE": "무성한 밀림", "SNOW": "눈과 서리의 땅", "DESERT": "메마른 사구",
	"AUTUMN": "단풍이 지는 골", "VOLCANO": "잿빛 화산 지대",
}

static var container: Node2D          # main 이 넣어 준다
static var _map_cache := {}           # id → GameMap
static var _npc_cache := {}           # 이름 → Dragon (호감도 유지)
static var _travel_lock := 0          # 이 시각(ms)까지는 포탈을 다시 밟지 않는다
static var _nag := 0.0                # 막힌 길 안내를 너무 자주 띄우지 않게
static var _border_cool := 0.0
# 노드로 지도에 붙는 무리 (탄·효과·빛 알갱이는 FxLayer 가 그린다)
const NODE_GROUPS := ["props", "npcs", "enemies", "humans", "bosses", "items", "nests", "babies"]


static func maps() -> Dictionary: return Data.get_module("maps").MAPS
static func dens() -> Dictionary: return Data.get_module("dens").DENS


## 지도 인스턴스 (없으면 만들어 캐시)
static func get_map(id: String) -> GameMap:
	if not _map_cache.has(id):
		if dens().has(id):
			_map_cache[id] = RoomMap.build_room(dens()[id])
			return _map_cache[id]
		if not maps().has(id):
			push_error("알 수 없는 지도: " + id)
			return null
		var spec: Dictionary = maps()[id].duplicate()
		spec.id = id
		_map_cache[id] = GameMap.build(spec)
	return _map_cache[id]


## 굴 안 한 칸. 바깥 지도와 달리 방 하나뿐이고 살림살이가 놓여 있다
static func _populate_den(id: String) -> Dictionary:
	var m: RoomMap = get_map(id)
	var spec: Dictionary = dens()[id]
	var pools := GameState.empty_pools()
	var T := GameMap.TILE
	# 나가는 문 — 방 아래쪽 한가운데
	var mouth := _prop(m.center.x, m.floor_rect.position.y + m.floor_rect.size.y - T * 0.4, "PORTAL")
	var out := at(spec.at)
	mouth.portal = { to = spec.outer, name = Names.map(spec.outer), spot = { x = out.x, y = out.y } }
	pools.props.append(mouth)
	# 살림살이
	for d in Den.decor_of(id):
		var f = Den.furniture().get(d.id)
		if not f: continue
		var w := Den.tile_to_world(d.tx, d.ty)
		var item := _prop(w.x + (f.span[0] - 1) * T / 2.0, w.y, "FURNITURE")
		item.fid = d.id
		pools.props.append(item)
	# 내 굴에는 둥지가 있다. 들어서자마자 눈에 들어오도록 방 가운데 위쪽에 둔다
	if spec.get("mine"):
		var nest := Nest.make(m.center.x, m.floor_rect.position.y + m.floor_rect.size.y * 0.34)
		if GameState.denNest:
			nest.has_egg = GameState.denNest.hasEgg
			nest.progress = GameState.denNest.progress
			nest.genes = GameState.denNest.genes
		pools.nests.append(nest)
	Routine.place_by_routine(id, pools, get_npc)
	return { map = m, pools = pools }


## 큰 칸 좌표 → 월드 좌표
static func at(c: Array) -> Vector2:
	return Vector2(GameMap.coarse_center(c[0]), GameMap.coarse_center(c[1]))


## 포탈이 놓이는 자리 (가장자리 가운데에서 한 칸 안쪽)
static func portal_spot(m: GameMap, side: String) -> Vector2:
	if side == "N": return at([floori(m.cw / 2.0), 1])
	if side == "S": return at([floori(m.cw / 2.0), m.ch - 2])
	if side == "W": return at([1, floori(m.ch / 2.0)])
	return at([m.cw - 2, floori(m.ch / 2.0)])


static func _prop(px: float, py: float, type: String) -> Prop:
	return Prop.new().setup(px, py, type)


# ---------------- 지도 채우기 ----------------

## 가장자리를 나무로 둘러 막는다. 포탈 앞은 비워 둔다
static func _edge_walls(m: GameMap, props: Array, rng: Util.Mulberry32, portals: Array) -> void:
	var gaps := []
	for p in portals: gaps.append(portal_spot(m, p.side))
	var CP := GameMap.COARSE_PX
	for cy in m.ch:
		for cx in m.cw:
			var edge := cx < EDGE_WALL or cy < EDGE_WALL or cx >= m.cw - EDGE_WALL or cy >= m.ch - EDGE_WALL
			if not edge: continue
			# 바깥 줄은 빈틈없이, 안쪽 줄은 셋 중 하나만. 두 줄을 다 채우면 캐노피(240px)가
			# 겹쳐 화면 한쪽이 통째로 초록 벽이 되고, 길이며 굴 입구가 그 뒤에 묻힌다
			var outer := cx == 0 or cy == 0 or cx == m.cw - 1 or cy == m.ch - 1
			if (cx + cy) % 2 == 1 if outer else rng.next() > 0.34: continue
			var p := at([cx, cy])
			var open := false
			for g in gaps:
				if absf(g.x - p.x) < CP * 1.6 and absf(g.y - p.y) < CP * 1.6: open = true
			if open: continue
			if m.ground_at(p.x, p.y) == "WATER": continue
			props.append(_prop(p.x + Util.rand_range(-20, 20), p.y + Util.rand_range(-20, 20), "TREE"))


## 지도 하나의 개체를 전부 만든다
static func _populate(id: String) -> Dictionary:
	if dens().has(id): return _populate_den(id)
	var m := get_map(id)
	var spec: Dictionary = maps()[id]
	var rng := Util.Mulberry32.new(int(spec.get("seed", 1) if spec.get("seed") else 1) * 31 + 7)
	var pools := GameState.empty_pools()
	var portals: Array = spec.get("portals", [])

	# 1) 나무·덤불·열매·상자
	# 나무 한 그루는 240x288px 이나 차지한다. 그루 수를 줄이고 서로 최소 간격을 두어 빈터와 길이 저절로 나게 한다
	var trees: float = spec.get("trees", 0.4) if spec.get("trees") != null else 0.4
	var area := m.cw * m.ch
	# min_gap: 같은 종류끼리 이만큼(px)은 떨어뜨린다
	var scatter := func(n: int, make: Callable, min_gap := 0.0) -> void:
		var placed := []
		var i := 0
		var tries := 0
		while i < n and tries < n * 24:
			tries += 1
			var x := rng.next() * m.w
			var y := rng.next() * m.h
			if m.ground_at(x, y) != "GRASS": continue
			var near_portal := false
			for p in portals:
				if Vector2(x, y).distance_to(portal_spot(m, p.side)) < 150: near_portal = true
			if near_portal: continue
			var crowded := false
			if min_gap:
				for q in placed:
					if Vector2(q.x - x, q.y - y).length() < min_gap: crowded = true
			if crowded: continue
			make.call(x, y)
			placed.append(Vector2(x, y))
			i += 1
	# 나무는 길에서 떨어져 선다 — 캐노피(240px)가 길을 덮으면 어디가 길인지 안 보인다
	var near_road := func(x: float, y: float) -> bool:
		for d in [[0, 0], [95, 0], [-95, 0], [0, 80], [0, -80]]:
			if m.ground_at(x + d[0], y + d[1]) == "DIRT": return true
		return false
	scatter.call(roundi(area * trees * 0.11), func(x, y):
		if not near_road.call(x, y): pools.props.append(_prop(x, y, "TREE")), 220)
	scatter.call(roundi(area * 0.22), func(x, y): pools.props.append(_prop(x, y, ["BUSH", "BUSH", "FERN", "ROCK", "STUMP"].pick_random())), 70)
	scatter.call(roundi(area * 0.06), func(x, y): pools.props.append(_prop(x, y, "BERRY")), 90)

	# 바이옴마다 다른 잡동사니와 랜드마크. 이게 없으면 색상판만 다른 같은 풀밭이 19장 나온다
	var biomes: Dictionary = Data.get_module("world_biomes").BIOMES
	var biome: Dictionary = biomes.get(spec.get("biome", ""), biomes.FOREST)
	if biome.get("decor"):
		scatter.call(roundi(area * 0.10), func(x, y): pools.props.append(_prop(x, y, biome.decor.pick_random())), 110)
	if biome.get("landmarks"):
		scatter.call(2 + floori(rng.next() * 2), func(x, y): pools.props.append(_prop(x, y, biome.landmarks.pick_random())), 520)

	var chest_no := [0]
	scatter.call(int(spec.get("chests", 3)) if spec.get("chests") != null else 3, func(x, y):
		var chest := _prop(x, y, "CHEST")
		chest.chest_id = "%s:%d" % [id, chest_no[0]]
		chest_no[0] += 1
		if GameState.openedChests.get(chest.chest_id):
			chest.opened = true
			chest.sprite = Data.get_module("tiles").PROP_SPRITES.CHEST_OPEN[0]
		pools.props.append(chest))

	_edge_walls(m, pools.props, rng, portals)

	# 2) 포탈
	for p in portals:
		var s := portal_spot(m, p.side)
		var gate := _prop(s.x, s.y, "PORTAL")
		gate.portal = { side = p.side, to = p.to, name = p.get("name") if p.get("name") else Names.map(p.to), needsFlight = bool(p.get("needsFlight", false)) }
		pools.props.append(gate)

	# 3) 지도마다의 것들
	for f in spec.get("fixtures", []):
		var pos := at(f.at) if f.get("at") else Vector2(m.w / 2.0, m.h / 2.0)
		match f.t:
			"PROP": pools.props.append(_prop(pos.x, pos.y, f.type))
			"WAYSTONE":
				var stone := _prop(pos.x, pos.y, "WAYSTONE")
				stone.stone_id = id
				pools.props.append(stone)
			"CAVE":
				var cave := _prop(pos.x, pos.y, "CAVE")
				cave.cave_id = f.id
				pools.props.append(cave)
			"DUMMY_SPOT": GameState.dojoSpot = pos
			"NPC":
				if Routine.has_routine(f.name): continue    # 일과가 있는 용은 Routine 이 놓는다
				var npc := get_npc(f.name, pos)
				npc.x = pos.x; npc.y = pos.y
				npc.home_x = pos.x; npc.home_y = pos.y
				npc.is_hidden = false; npc.remove = false
				pools.npcs.append(npc)
			"BOSS":
				if GameState.bossesDefeated.get(f.id): continue
				if f.id == "IGNAR" and GameState.story.get("route") == "dark" and GameState.quests.done.has("m7d"): continue
				# 사건을 겪기 전에는 둥지가 비어 있다. 지나가다 덜컥 마주치지 않게
				var need = Data.get_module("enemies").BOSSES.get(f.id, {}).get("needs")
				if need and not GameState.story.get("events", []).has(need): continue
				var boss := Boss.make(f.id)
				boss.x = pos.x; boss.y = pos.y
				boss.home = pos
				pools.bosses.append(boss)
			# "NEST" 는 둥지를 옮길 때

	# 3-2) 이 지도에 입구가 있는 굴들
	for den_id in dens():
		if dens()[den_id].outer != id: continue
		var pos := at(dens()[den_id].at)
		var mouth := _prop(pos.x, pos.y, "DEN_MOUTH")
		mouth.den_id = den_id
		pools.props.append(mouth)

	# 4) 일과대로 지금 이 지도에 있어야 하는 용들
	Routine.place_by_routine(id, pools, get_npc)

	# 5) 떠돌이 용 (마을과 숲길에만 한둘). 광장 한복판에 불쑥 서 있으면 "쟤 어디서 났어" 소리가 나서,
	#    지도 가장자리(문 근처)에 놓고 마을에는 드물게만 온다
	if not spec.get("clearings") and spec.get("wanderer") != false and rng.next() < (0.35 if id == "VILLAGE" else 0.7):
		var npcs: Dictionary = Data.get_module("npcs")
		var species: String = "LOOK" if rng.next() < 0.8 else npcs.WANDER_SPECIES.pick_random()
		var side := 0.16 + rng.next() * 0.1 if rng.next() < 0.5 else 0.74 + rng.next() * 0.1
		var wx := rng.next() < 0.5
		var x0 := m.w * (side if wx else 0.25 + rng.next() * 0.5)
		var y0 := m.h * (0.25 + rng.next() * 0.5 if wx else side)
		var spot := clear_spot(x0, y0, m)
		pools.npcs.append(Dragon.new().setup(spot.x, spot.y, {
			name = npcs.WANDER_NAMES.pick_random(), personality = npcs.WANDER_PERSONALITIES.pick_random(), species = species,
			colors = npcs.SPECIES_COLORS.get(species, npcs.SPECIES_COLORS.WESTERN),
			look = npcs.WANDER_LOOKS.pick_random(), accessory = npcs.WANDER_ACCESSORIES.pick_random(),
			scale = Util.rand_range(0.85, 1.1), canPartner = false,
		}))

	return { map = m, pools = pools }


## 고정 NPC 는 한 번 만들고 계속 쓴다 (호감도·데이트가 그 안에 들어 있다)
static func get_npc(name: String, pos: Vector2) -> Dragon:
	if not _npc_cache.has(name):
		var def := {}
		for d in Data.get_module("npcs").FIXED_NPCS:
			if d.name == name: def = d.duplicate()
		def.fixed = true
		_npc_cache[name] = Dragon.new().setup(pos.x, pos.y, def)
	return _npc_cache[name]


## 고정 NPC 를 모두 미리 만들어 둔다. 세이브 복원이 이름으로 찾을 수 있어야 한다
static func _prime_npcs() -> void:
	# 일과가 있는 용은 어느 지도의 fixtures 에도 없을 수 있다. 먼저 만들어 둔다
	for name in Routine.routine_names():
		var plan = Routine.plan_for(name, 12)
		if plan: get_npc(name, Vector2(plan.x, plan.y)).home_map = plan.map
	for id in maps():
		for f in maps()[id].get("fixtures", []):
			if f.t != "NPC": continue
			get_npc(f.name, at(f.at)).home_map = id


## 세이브를 불러올 때 NPC 상태를 찾아 쓰도록
static func fixed_npcs() -> Array: return _npc_cache.values()


## 이름으로 그 용을 찾는다. 지금 지도에 없어도 캐시에서 꺼내 준다
## (말하는 용이 딴 지도에 있어도 컷씬 초상화가 비지 않게)
static func any_npc(nm: String):
	if GameState.entities and GameState.entities.has("npcs"):
		for n in GameState.entities.npcs:
			if n.config.get("name") == nm: return n
	if _npc_cache.has(nm): return _npc_cache[nm]
	for d in Data.get_module("npcs").FIXED_NPCS:
		if d.name == nm: return get_npc(nm, Vector2.ZERO)   # 만들어 두면 다음부터 캐시에서 나온다
	return null


## 짝·동료·아이들을 지금 지도로 데려온다
static func _bring_family(pools: Dictionary, x: float, y: float) -> void:
	for n in [GameState.partner, GameState.companion]:
		if not n or n.state == "WANDER": continue   # 기다리라고 한 짝은 두고 간다
		if not pools.npcs.has(n): pools.npcs.append(n)
		n.x = x + Util.rand_range(50, 90); n.y = y + Util.rand_range(-30, 40)
	for k in GameState.kids:
		var e = k.get("entity")
		if not e: continue
		if not pools.babies.has(e): pools.babies.append(e)
		e.x = x - Util.rand_range(50, 90); e.y = y + Util.rand_range(-30, 40)


# ---------------- 드나들기 ----------------

## 물·바위 위로 떨어지지 않게, 가까운 설 수 있는 자리로 밀어 준다
static func clear_spot(x: float, y: float, m: GameMap) -> Vector2:
	var inside := func(px: float, py: float) -> bool: return px > 40 and py > 40 and px < m.w - 40 and py < m.h - 40
	if inside.call(x, y) and not Collision.solid_at(x, y, 20): return Vector2(x, y)
	for r in range(48, 901, 48):
		for i in 16:
			var a := (i / 16.0) * TAU
			var px := x + cos(a) * r
			var py := y + sin(a) * r
			if inside.call(px, py) and not Collision.solid_at(px, py, 20): return Vector2(px, py)
	return Vector2(x, y)   # 온통 막혀 있으면 어쩔 수 없다


## 지도를 바꾼다. from: 어느 쪽에서 들어왔는지 ('N'|'S'|'E'|'W'). 그 반대편 포탈 앞에 선다. spot: 자리를 콕 집을 때
static func enter_map(id: String, from = null, spot = null) -> GameMap:
	Ambush.maybe(id)   # 베르단을 한 번 만난 뒤로는 길에서 또 마주칠 수 있다
	# 떠나기 전에 둥지 상태를 갈무리한다 (내 굴에만 있다)
	if GameState.entities and not GameState.entities.get("nests", []).is_empty():
		var leaving = GameState.entities.nests[0]
		GameState.denNest = { hasEgg = leaving.has_egg, progress = leaving.progress, genes = leaving.genes }
	# 소품(나무·덤불)은 만들어질 때 바이옴으로 색상판을 고른다. 지도를 먼저 활성화하지 않으면
	# 설원·화산·구름 위의 나무가 직전 지도의 초록 시트로 나온다
	Terrain.set_active_map(get_map(id))
	var made := _populate(id)
	var m: GameMap = made.map
	var pools: Dictionary = made.pools
	GameState.map_id = id
	GameState.indoors = dens().has(id)

	# 설 자리를 고르기 전에 소품 격자를 먼저 깔아야 solid_at() 이 제대로 답한다
	Collision.build_prop_grid(pools.props)

	var p := Vector2.ZERO
	if spot != null: p = spot
	elif from != null:
		var s := portal_spot(m, from)
		# 포탈 바로 위에 서면 곧장 되돌아가 버린다. 안쪽으로 한 칸 밀어 놓는다
		var push: Array = { "N": [0, 1], "S": [0, -1], "E": [-1, 0], "W": [1, 0] }[from]
		p = Vector2(s.x + push[0] * GameMap.COARSE_PX * 1.3, s.y + push[1] * GameMap.COARSE_PX * 1.3)
	elif m is RoomMap:
		# 굴에 들어설 때는 문 안쪽에 선다 (한복판에 떨어뜨리면 둥지 위에 겹친다. 문에 너무 붙으면 도로 튕겨 나간다)
		p = Vector2(m.center.x, m.floor_rect.position.y + m.floor_rect.size.y - GameMap.TILE * 2.8)
	else:
		var stone = null
		for pr in pools.props:
			if pr.type == "WAYSTONE": stone = pr; break
		p = Vector2(stone.x, stone.y + 70) if stone else Vector2(m.w / 2.0, m.h / 2.0)
	p = clear_spot(p.x, p.y, m)
	GameState.player.x = p.x; GameState.player.y = p.y
	_bring_family(pools, p.x, p.y)

	_swap_nodes(pools)
	GameState.entities = pools
	if not GameState.visited.has(id): GameState.visited.append(id)
	if dens().has(id): Den.intro(id)
	return m


## 떠나는 지도의 노드를 걷고 새 지도의 노드를 붙인다. 캐시한 마을 용과 나는 지우지 않고 떼어만 둔다
static func _swap_nodes(pools: Dictionary) -> void:
	for c in container.get_children():
		container.remove_child(c)
		if c != GameState.player and not _keep(c): c.queue_free()
	container.add_child(GameState.player)
	for group in NODE_GROUPS:
		for e in pools[group]: container.add_child(e)


## 개체 무리를 통째로 갈아 끼운다 (굴 속 한 층처럼 World 밖에서 만든 무리)
static func swap_pools(pools: Dictionary) -> void:
	_swap_nodes(pools)
	GameState.entities = pools


## 지도를 옮겨도 살려 두는 노드: 캐시한 마을 용, 짝·동료, 아이들
static func _keep(n) -> bool:
	if _npc_cache.values().has(n) or n == GameState.partner or n == GameState.companion: return true
	for k in GameState.kids:
		if k.get("entity") == n: return true
	return false


## 새로 생긴 개체 (적·떨어진 물건 …) 를 지금 지도에 더한다
static func add_entity(group: String, e) -> void:
	GameState.entities[group].append(e)
	if e is Node: container.add_child(e)


## 다 쓴 개체를 걷는다. 노드인 것은 지우되, 캐시해 둔 마을 용은 떼어만 둔다
static func prune() -> void:
	var E: Dictionary = GameState.entities
	for key in ["bullets", "effects", "hazards", "bosses", "enemies", "humans", "items", "particles", "babies", "npcs"]:
		var keep := []
		for e in E[key]:
			if not e.remove:
				keep.append(e)
			elif e is Node and e.is_inside_tree():
				container.remove_child(e)
				if not _keep(e): e.queue_free()
		E[key] = keep


## 지금 지도에 어울리는 적 종류
static func map_enemies() -> Array:
	var spec = maps().get(GameState.map_id)
	var table: Dictionary = Data.get_module("enemies").BIOME_ENEMIES
	return table.get(spec.biome if spec else "FOREST", table.FOREST)


## 이 지도에 보스가 살아 있나 (살아 있으면 야생 적을 뿌리지 않는다)
static func map_has_boss() -> bool:
	return GameState.entities.bosses.size() > 0


## 쓰러졌을 때: 마을 광장에서 눈을 뜬다
static func revive_in_village() -> void:
	if GameState.dungeon: return                 # 굴에서는 그 자리에서 일어난다
	var start: String = Data.get_module("maps").START_MAP
	if GameState.map_id == start: return
	travel_to(start)


## 판을 접을 때: 떼어 둔(지금 지도에 없는) 마을 용 노드를 치운다
static func dispose() -> void:
	for n in _npc_cache.values():
		if is_instance_valid(n) and not n.is_inside_tree(): n.free()
	_npc_cache.clear()
	_map_cache.clear()


## 살림살이를 놓거나 치웠을 때, 굴 안 소품만 다시 깐다
static func refresh_den() -> void:
	if not dens().has(GameState.map_id): return
	var made := _populate_den(GameState.map_id)
	# 지금 서 있는 나와 따라다니는 식구는 그대로 두고 소품만 바꾼다
	for pr in GameState.entities.props:
		if pr.is_inside_tree(): container.remove_child(pr)
		pr.queue_free()
	for n in made.pools.nests: n.free()   # 둥지는 지금 것을 그대로 쓴다
	GameState.entities.props = made.pools.props
	for pr in made.pools.props: container.add_child(pr)
	Collision.build_prop_grid(GameState.entities.props)


## 굴 입구 가까이 있으면 그 입구 소품
static func nearby_den_mouth():
	var p = GameState.player
	var best = null
	var best_d := 120.0
	for m in GameState.entities.props:
		if m.type != "DEN_MOUTH": continue
		var d := Util.dist(p, m)
		if d < best_d:
			best = m
			best_d = d
	return best


## 새 게임: 플레이어를 만들고 첫 지도에 놓는다. 튜토리얼용 엘더를 돌려준다
static func init_world(config: Dictionary):
	_map_cache.clear()
	_npc_cache.clear()
	GameState.player = Dragon.new().setup(0, 0, {
		name = config.get("name"), species = config.get("species"), colors = config.get("colors", {}),
		accessory = config.get("accessory"), look = config.get("look", 0),
	}, true)
	_prime_npcs()
	# 첫 잠자리 한 벌은 마을에서 챙겨서 굴에 깔아 놓아 준다 (빈 굴에 혼자 들어서면 휑하다)
	GameState.furniture = {}
	GameState.denDecor = [{ id = "BED", tx = 9, ty = 5 }, { id = "STRAW", tx = 2, ty = 4 }]
	var start: String = Data.get_module("maps").START_MAP
	enter_map(start)
	var v := get_map(start)
	GameState.player.x = v.w / 2.0; GameState.player.y = v.h * 0.62
	for n in GameState.entities.npcs:
		if n.config.get("role") == "ELDER": return n
	return null


## 매 프레임: 포탈을 밟았으면 넘어간다
static func update_portals() -> void:
	if Time.get_ticks_msec() < _travel_lock or GameState.isDialogueOpen or GameState.activity or GameState.dungeon: return
	var p = GameState.player
	var gate = null
	for x in GameState.entities.props:
		if x.portal and Util.dist(p, x) < PORTAL_RANGE:
			gate = x
			break
	if gate == null: return
	var nag := func(text: String, icon: String) -> void:
		if GameState.game_time - _nag > 4:
			_nag = GameState.game_time
			Hud.pop(text, icon)
	if GameState.raid.active:
		Hud.pop("사냥꾼이 마을을 치고 있다. 지금 떠날 수는 없다.", "⚔️")
		return
	# 세상은 이야기만큼만 열린다
	if not Chapters.map_open(GameState, gate.portal.to):
		nag.call(Chapters.blocked_text(GameState, gate.portal.to), "🚧")
		return
	# 폭포 위는 남의 마을이다. 모임에 한 번 나가 봐야 올라갈 수 있다 (유안이 막아선다)
	if gate.portal.to == "CLOUDTOP" and not Gathering.invited_up():
		_block_at_border()
		return
	# 하늘길. 날고 있어야 건넌다 (Z)
	if gate.portal.get("needsFlight") and not p.flying:
		nag.call("여기서부터는 하늘이다. 날아야 건넌다." if p.stage_index >= 2 else "여기서부터는 하늘이다. 성체가 되어야 날 수 있다.", "☁️")
		return
	var spot = null
	if gate.portal.get("spot"): spot = Vector2(gate.portal.spot.x, gate.portal.spot.y + 84)   # 굴에서 나올 때는 들어갔던 입구 앞에 선다
	travel_to(gate.portal.to, OPPOSITE[gate.portal.side] if gate.portal.get("side") else null, spot)


## 2D판 systems/borderGate.js. 폭포 위로 올라가려 할 때 유안이 막아선다
static func _block_at_border() -> void:
	if GameState.game_time < _border_cool: return     # 포탈 앞에서 반복해 뜨지 않게
	_border_cool = GameState.game_time + 6
	GameState.isDialogueOpen = true
	Sfx.play("talk")
	var yuan = null
	for n in GameState.entities.npcs:
		if n.config.get("name") == "Yuan": yuan = n
	var when := "오늘 밤이 그날이다. 해가 지거든 다시 오너라." if Gathering.is_gather_day() else "%d일 뒤 밤이 그날이다." % Gathering.days_to_gather()
	var close := func():
		GameState.isDialogueOpen = false
		DialogueBox.current.hide_dialogue()
	DialogueBox.current.show_dialogue({
		name = Names.npc("Yuan"),
		text = "거기까지다. 이 위는 구름마루의 땅이다.

달이 가장 밝은 밤에는 폭포 아래에서 모임이 선다. 그날은 누구도 이빨을 드러내지 않기로 했지. 올라오고 싶거든 그날 여기로 와라.

(%s)" % when,
		sheet = yuan.sheet if yuan else null,
		on_close = close,
		options = [{ label = "알겠다", on_select = close }],
	})


## 포탈·이동 석비로 지도를 옮긴다. 화면을 까맣게 덮지 않는다 — 곧바로 옮기고, 지역 이름만 위쪽에 잠깐 띄웠다 지운다
static func travel_to(id: String, from = null, spot = null) -> void:
	if Time.get_ticks_msec() < _travel_lock: return
	enter_map(id, from, spot)
	Hud.current.show_region_banner(Names.map(id), BIOME_LABEL.get(maps()[id].biome, "") if maps().has(id) else "")
	# 도착하자마자 뒤돌아 다시 포탈을 밟는 일이 없게 아주 짧게만 잠근다
	_travel_lock = Time.get_ticks_msec() + 350
