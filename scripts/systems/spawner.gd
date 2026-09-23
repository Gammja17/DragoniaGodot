class_name Spawner
## 2D판 world/spawn.js. 지금 밟고 있는 지도에만 적을 뿌린다.
## 마을·호수처럼 safe 한 곳과 보스 결투장에는 야생 적이 나오지 않는다.

const ELITE_CHANCE := 0.08
const DESPAWN_RANGE := 1500

static var _next_pack := 2.0      # 다음 무리까지 남은 시간(초)
static var _last_map = null       # 지도를 옮기면 시계를 되돌린다


static func _peaceful() -> bool:
	var b = Data.get_module("world_biomes").BIOMES.get(Terrain.active_biome())
	var spec = World.maps().get(GameState.map_id)
	return (b and b.get("safe")) or (spec and spec.get("safe")) or World.map_has_boss() or GameState.dungeon != null


## 이 지도에 한 번에 있을 수 있는 적 수
static func _cap() -> float:
	var spec = World.maps().get(GameState.map_id)
	var per_map: int = spec.get("enemyCap", 10) if spec and spec.get("enemyCap") else 10
	return mini(Data.get_module("core_config").MAX_ENEMIES, per_map) * NightEvents.enemy_cap_mult()


## 화면 밖 빈 땅 한 점 (없으면 null)
static func _open_spot():
	var p = GameState.player
	var b := Terrain.current_map_bounds()
	for tries in 12:
		var a := Util.rand_range(0, TAU)
		var r := Util.rand_range(620, 1050)
		var x: float = p.x + cos(a) * r
		var y: float = p.y + sin(a) * r
		if x < 120 or y < 120 or x > b.x - 120 or y > b.y - 120: continue
		if Collision.solid_at(x, y, 20): continue
		# 포탈 앞은 비워 둔다 (지도를 넘자마자 얻어맞지 않게)
		var near_gate := false
		for q in GameState.entities.props:
			if q.portal and Util.dist(Vector2(x, y), q) < 260: near_gate = true
		if near_gate: continue
		return Vector2(x, y)
	return null


## 무리 하나를 내보낸다 (data/packs). 대장 자리엔 정예가 선다. 편성표가 없는 바이옴은 낱개로
static func spawn_pack(force_type = null) -> void:
	var spot = _open_spot()
	if spot == null: return
	var pack = { units = [{ t = force_type, n = 3 }] } if force_type else _pick_pack(Terrain.active_biome())
	if pack == null:
		var type: String = World.map_enemies().pick_random()
		World.add_entity("enemies", Enemy.make(spot.x, spot.y, type, type != "PREY" and randf() < ELITE_CHANCE))
		return
	var i := 0
	for u in pack.units:
		for k in int(u.n):
			var a := (i / 7.0) * TAU
			var r := 0.0 if i == 0 else 40.0 + i * 14
			var x: float = spot.x + cos(a) * r
			var y: float = spot.y + sin(a) * r
			var elite: bool = u.get("lead", false) or (u.t != "PREY" and randf() < ELITE_CHANCE * 0.4)
			var blocked := Collision.solid_at(x, y, 14)
			World.add_entity("enemies", Enemy.make(spot.x if blocked else x, spot.y if blocked else y, u.t, elite))
			i += 1


static func _pick_pack(biome: String):
	var list = Data.get_module("packs").PACKS.get(biome)
	if not list: return null
	var total := 0.0
	for p in list: total += p.w
	var r := randf() * total
	for p in list:
		r -= p.w
		if r <= 0: return p
	return list[-1]


## 매 프레임: 멀어진 적은 치우고, 부족하면 보충. 12~20초에 하나, 상한은 지도마다
static func update(dt: float) -> void:
	var E: Dictionary = GameState.entities
	for e in E.enemies:
		if Util.dist(e, GameState.player) > DESPAWN_RANGE: e.remove = true
	if _peaceful(): return
	var alive := func() -> int: return E.enemies.filter(func(e): return e.def.move != "none" and not e.remove).size()
	# 새 지도에 들어서면 빈 땅이 아니라 이미 무리가 돌아다니고 있어야 한다
	if GameState.map_id != _last_map:
		_last_map = GameState.map_id
		_next_pack = 4.0
		for i in 3:
			if alive.call() >= _cap(): break
			spawn_pack()
	# 퀘스트가 잡으라는 놈을 늘 두어 마리 두는 것은 퀘스트를 옮길 때
	_next_pack -= dt
	if _next_pack > 0: return
	_next_pack = Util.rand_range(8, 14)
	if alive.call() < _cap(): spawn_pack()
