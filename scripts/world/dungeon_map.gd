class_name DungeonMap
extends GameMap
## 2D판 world/dungeon.js. 무너진 용의 둥지 — 들어갈 때마다 새로 그려지는 지하 미궁.
## 바깥 세상은 늘 같은 자리에 같은 것이 있어서 이야기를 심을 수 있고, 이곳은 매번 달라져서 탐험 그 자체가 목적이 된다.
##
## 지도는 방과 복도로만 이뤄진다. 0 = 벽(못 지나감), 1 = 바닥.
## 벽은 바닥에 뚫린 검은 구멍이라 한 장짜리 그림이 아니라 오토타일로 두른다 (굴 보금자리와 같다).

const WALL := 0
const FLOOR := 1

var rooms := []     # [{ x, y, w, h, cx, cy }]
var entry: Dictionary
var exit: Dictionary
var seed := 0
var depth := 1


static func tiles_per_side() -> int: return ceili(3072.0 / TILE)   # 한 변 타일 수 (64)


## 방 두 개가 겹치는가 (한 칸 띄워서 본다)
static func _overlaps(a: Dictionary, b: Dictionary) -> bool:
	return a.x - 1 < b.x + b.w + 1 and a.x + a.w + 1 > b.x - 1 and a.y - 1 < b.y + b.h + 1 and a.y + a.h + 1 > b.y - 1


## 한 층을 만든다. seed 가 같으면 같은 층 (되돌아왔을 때 모양이 유지된다). 깊을수록 방이 많고 넓다
static func generate(floor_seed: int, floor_depth: int, biome: String) -> DungeonMap:
	var m := DungeonMap.new()
	var rng := Util.Mulberry32.new(floor_seed)
	var N := tiles_per_side()
	m.seed = floor_seed
	m.depth = floor_depth
	m.id = "DUNGEON"
	m.spec = { id = "DUNGEON", biome = biome }   # 소품·몬스터 색상판
	m.tw = N; m.th = N; m.cw = 0; m.ch = 0
	m.w = N * TILE; m.h = N * TILE
	m.kinds = PackedByteArray()
	m.kinds.resize(N * N)   # 전부 벽으로 시작
	var wanted := mini(14, 7 + floor_depth)
	var tries := 0
	while tries < 300 and m.rooms.size() < wanted:
		tries += 1
		var w := 6 + floori(rng.next() * (5 + mini(4, floor_depth)))
		var h := 6 + floori(rng.next() * (5 + mini(4, floor_depth)))
		var x := 2 + floori(rng.next() * (N - w - 4))
		var y := 2 + floori(rng.next() * (N - h - 4))
		var room := { x = x, y = y, w = w, h = h, cx = floori(x + w / 2.0), cy = floori(y + h / 2.0) }
		if m.rooms.any(func(r): return _overlaps(room, r)): continue
		m.rooms.append(room)

	var carve := func(tx: int, ty: int) -> void:
		if tx > 0 and ty > 0 and tx < N - 1 and ty < N - 1: m.kinds[ty * N + tx] = FLOOR
	for r in m.rooms:
		for j in r.h:
			for i in r.w: carve.call(r.x + i, r.y + j)

	# 복도: 방을 차례로 ㄱ자로 잇고, 몇 개는 더 이어 고리를 만든다 (막다른 길만 있으면 답답하다)
	var link := func(a: Dictionary, b: Dictionary) -> void:
		var x: int = a.cx
		var y: int = a.cy
		var horizontal_first := rng.next() < 0.5
		for pass_i in 2:
			if (pass_i == 0) == horizontal_first:
				while x != b.cx:
					x += signi(b.cx - x)
					carve.call(x, y); carve.call(x, y + 1)
			else:
				while y != b.cy:
					y += signi(b.cy - y)
					carve.call(x, y); carve.call(x + 1, y)
	var order := m.rooms.duplicate()
	order.sort_custom(func(a, b): return (a.cx + a.cy) < (b.cx + b.cy))
	for i in range(1, order.size()): link.call(order[i - 1], order[i])
	var extra := 0
	while extra < 2 + floor_depth / 2.0 and order.size() > 3:
		link.call(order[floori(rng.next() * order.size())], order[floori(rng.next() * order.size())])
		extra += 1

	# 들어온 자리는 첫 방, 더 깊이 가는 계단은 가장 먼 방
	m.entry = order[0]
	m.exit = order[-1]
	var far := 0.0
	for r in order:
		var d := Vector2(r.cx - m.entry.cx, r.cy - m.entry.cy).length()
		if d > far:
			far = d
			m.exit = r
	m.texture = ImageTexture.create_from_image(m._bake_floor())
	m.sparkles = []
	return m


static func tile_center(tx: int, ty: int) -> Vector2:
	return Vector2(tx * TILE + TILE / 2.0, ty * TILE + TILE / 2.0)


## 방 안의 아무 바닥 칸 (가장자리는 피한다)
static func spot_in_room(room: Dictionary, rng: Util.Mulberry32) -> Vector2:
	var tx: int = room.x + 1 + floori(rng.next() * maxi(1, room.w - 2))
	var ty: int = room.y + 1 + floori(rng.next() * maxi(1, room.h - 2))
	return tile_center(tx, ty)


func ground_at(x: float, y: float) -> String:
	var tx := floori(x / TILE)
	var ty := floori(y / TILE)
	if tx < 0 or ty < 0 or tx >= tw or ty >= th: return "WALL"
	return "FLOOR" if kinds[ty * tw + tx] == FLOOR else "WALL"


func _is_floor(tx: int, ty: int) -> bool:
	return tx >= 0 and ty >= 0 and tx < tw and ty < th and kinds[ty * tw + tx] == FLOOR


## 층 하나를 그림으로 구워 둔다
func _bake_floor() -> Image:
	var T: Dictionary = Data.get_module("tiles")
	var rng := Util.Mulberry32.new(seed + 99)
	var img := Image.create_empty(tw * TILE_SRC, th * TILE_SRC, false, Image.FORMAT_RGBA8)
	img.fill(Color("#0a0a10"))
	var sheet := TileImages.get_image("cave")
	var put := func(t: Array, tx: int, ty: int) -> void:
		img.blend_rect(sheet, Rect2i(int(t[0]) * TILE_SRC, int(t[1]) * TILE_SRC, TILE_SRC, TILE_SRC), Vector2i(tx * TILE_SRC, ty * TILE_SRC))
	var floor_tiles: Array = T.CAVE_FLOOR
	var rubble: Array = T.CAVE_RUBBLE
	for ty in th:
		for tx in tw:
			if _is_floor(tx, ty):
				put.call(floor_tiles[floori(rng.next() * floor_tiles.size())], tx, ty)
				if rng.next() < 0.05: put.call(rubble[floori(rng.next() * rubble.size())], tx, ty)   # 가끔 돌덩이
				continue
			# 바닥과 맞닿은 칸만 테두리를 두르고, 깊은 속은 굳이 그리지 않는다 (어차피 바탕이 같은 검은색이다)
			var t = RoomMap.cave_void_tile(tx, ty, _is_floor)
			if t != null: put.call(t, tx, ty)
	return img
