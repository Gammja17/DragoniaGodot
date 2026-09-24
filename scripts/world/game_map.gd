class_name GameMap
extends RefCounted
## 2D판 world/mapgen.js 의 buildMap 이 돌려주던 지도 한 장.
##
## 지형은 "큰 칸"(2×2 타일 = 96px) 단위로 만든다. 흙·물 영역의 폭이 늘 2타일 이상이라
## 변 4 + 바깥 모서리 4 + 안쪽 모서리 4 + 가운데, 13종 타일만으로 빈틈없이 이어진다.
## 시드 난수를 부르는 순서까지 2D판과 같아야 같은 지도가 나온다.

const COARSE_TILES := 2                     # 큰 칸 한 변의 타일 수
const GRASS_ID := 0
const DIRT_ID := 1
const WATER_ID := 2
const CLIFF_ID := 3
const GROUND_NAMES := ["GRASS", "DIRT", "WATER", "CLIFF"]
# 절벽 네모의 아래 세 줄은 아래로 늘어진 바위 면이 되고, 그 위가 고원 윗면(풀밭)이 된다
const FACE_ROWS := 3

static var TILE_SRC: int
static var TILE_SCALE: int
static var TILE: int
static var COARSE_PX: int

var id: String
var spec: Dictionary
var cw: int
var ch: int
var tw: int
var th: int
var w: int
var h: int
var kinds: PackedByteArray
var texture: ImageTexture        # 구운 바닥 (원본 16px 격자 그대로. 그릴 때 TILE_SCALE 배로 늘린다)
var sparkles: Array = []         # [{ tx, ty, row, flip, phase }]


static func _static_init() -> void:
	var t: Dictionary = Data.get_module("tiles")
	TILE_SRC = int(t.TILE_SRC)
	TILE_SCALE = int(t.TILE_SCALE)
	TILE = int(t.TILE)
	COARSE_PX = TILE * COARSE_TILES


## 큰 칸 좌표 → 그 칸 중심의 월드 좌표
static func coarse_center(c: float) -> float:
	return (c + 0.5) * COARSE_PX


## 월드 좌표 → 큰 칸 좌표
static func to_coarse(world: float) -> int:
	return floori(world / COARSE_PX)


func ground_at(x: float, y: float) -> String:
	var tx := floori(x / TILE)
	var ty := floori(y / TILE)
	if tx < 0 or ty < 0 or tx >= tw or ty >= th:
		return "GRASS"
	return GROUND_NAMES[kinds[ty * tw + tx]]


## 지도 한 장을 만든다.
##   spec.cw, spec.ch   큰 칸 수 (한 칸 96px)
##   spec.biome         색상판과 등장 몬스터를 고른다 (world_biomes.json)
##   spec.plaza         [cx, cy, cw, ch] 흙으로 깔 네모 (마을 광장)
##   spec.yards         [[cx, cy, cw, ch], ...] 집 앞마당 (광장과 달리 가장자리를 들쭉날쭉 빼지 않는다)
##   spec.clearings     [[cx, cy, r], ...] 흙 공터 (결투장·수련장, r 은 큰 칸 수)
##   spec.ponds         [[cx, cy, r], ...] 물웅덩이
##   spec.roads         [[[cx,cy],[cx,cy], ...], ...] 이어 걷는 흙길
##   spec.nests         [[cx, cy], ...] 둥지 돌무더기 자리
##   절벽은 spec 에 적지 않는다 — 바이옴이 정한 수만큼 저절로 선다
static func build(map_spec: Dictionary) -> GameMap:
	var m := GameMap.new()
	m.id = map_spec.get("id", "")
	m.spec = map_spec
	m.cw = int(map_spec.cw); m.ch = int(map_spec.ch)
	m.tw = m.cw * COARSE_TILES; m.th = m.ch * COARSE_TILES
	m.w = m.tw * TILE; m.h = m.th * TILE
	m.kinds = PackedByteArray()
	m.kinds.resize(m.tw * m.th)
	var rng := Util.Mulberry32.new(int(map_spec.get("seed", 1)) if map_spec.get("seed") else 1)

	var nests: Array = map_spec.get("nests", [])
	var is_nest := func(cx: int, cy: int) -> bool:
		for n in nests:
			if int(n[0]) == cx and int(n[1]) == cy: return true
		return false

	# 1) 물웅덩이
	for p in map_spec.get("ponds", []):
		for cy in m.ch:
			for cx in m.cw:
				if is_nest.call(cx, cy): continue
				if Vector2(cx - p[0], cy - p[1]).length() <= p[2]: m._fill(cx, cy, WATER_ID)
	# 2) 흙 공터 (결투장·수련장)
	for p in map_spec.get("clearings", []):
		for cy in m.ch:
			for cx in m.cw:
				if Vector2(cx - p[0], cy - p[1]).length() <= p[2]: m._fill(cx, cy, DIRT_ID)
	# 3) 마을 광장 (가장자리는 가끔 빼서 네모 반듯하지 않게)
	if map_spec.get("plaza"):
		var pl: Array = map_spec.plaza
		var px := int(pl[0]); var py := int(pl[1]); var pw := int(pl[2]); var ph := int(pl[3])
		for cy in range(py, py + ph):
			for cx in range(px, px + pw):
				if is_nest.call(cx, cy): continue
				var edge := cx == px or cy == py or cx == px + pw - 1 or cy == py + ph - 1
				var corner := (cx == px or cx == px + pw - 1) and (cy == py or cy == py + ph - 1)
				if corner or (edge and rng.next() < 0.35): continue
				m._fill(cx, cy, DIRT_ID)
	# 3-2) 집 앞마당: 흙으로 깐 작은 네모. 풀밭에 흩뿌리는 나무·잡동사니가 집과 문 앞을 덮지 않게 한다
	for yd in map_spec.get("yards", []):
		for cy in range(int(yd[1]), int(yd[1]) + int(yd[3])):
			for cx in range(int(yd[0]), int(yd[0]) + int(yd[2])):
				m._fill(cx, cy, DIRT_ID)
	# 4) 흙길: 점을 가로세로로 번갈아 이어 간다. 물은 건너뛴다
	for road in map_spec.get("roads", []):
		for i in range(1, road.size()):
			var x := int(road[i - 1][0]); var y := int(road[i - 1][1])
			var tx2 := int(road[i][0]); var ty2 := int(road[i][1])
			var horizontal := true
			var guard := 0
			while (x != tx2 or y != ty2) and guard < 400:
				guard += 1
				if m._kind_at(x, y) != WATER_ID and not is_nest.call(x, y): m._fill(x, y, DIRT_ID)
				if horizontal and x != tx2: x += signi(tx2 - x)
				elif y != ty2: y += signi(ty2 - y)
				else: x += signi(tx2 - x)
				horizontal = not horizontal
			m._fill(tx2, ty2, WATER_ID if m._kind_at(tx2, ty2) == WATER_ID else DIRT_ID)

	# 5) 절벽: 직사각형 바위 고원. 길을 막아 지도에 "돌아가는 길"이 생긴다.
	#    네모로만 세우는 건 타일 때문이다 — 오목한 모서리용 타일이 시트에 없다.
	#    둘레 한 칸까지 전부 풀일 때만 세워서 길·물·광장·둥지를 덮지 않는다.
	#    가장자리에서 세 칸 떨어뜨리는 건 포탈이 변 한가운데에 놓이기 때문이다.
	var biome: Dictionary = Data.get_module("world_biomes").BIOMES.get(map_spec.get("biome", ""), {})
	var cliff_count := int(biome.get("cliffs", 0))
	var made := 0
	var tries := 0
	while made < cliff_count and tries < 300:
		tries += 1
		var bw := 3 + floori(rng.next() * 3)
		var bh := 3 + floori(rng.next() * 2)
		if m.cw - bw - 6 < 1 or m.ch - bh - 6 < 1: break   # 지도가 너무 작으면 포기
		var bx := 3 + floori(rng.next() * (m.cw - bw - 6))
		var by := 3 + floori(rng.next() * (m.ch - bh - 6))
		var clear := true
		for y in range(by - 1, by + bh + 1):
			if not clear: break
			for x in range(bx - 1, bx + bw + 1):
				if m._kind_at(x, y) != GRASS_ID or is_nest.call(x, y):
					clear = false
					break
		if not clear: continue
		for y in range(by, by + bh):
			for x in range(bx, bx + bw):
				m._fill(x, y, CLIFF_ID)
		made += 1

	m.texture = ImageTexture.create_from_image(m._bake(rng))
	m.sparkles = m._make_sparkles(rng)
	return m


func _fill(cx: int, cy: int, kind: int) -> void:
	if cx < 0 or cy < 0 or cx >= cw or cy >= ch: return
	for dy in COARSE_TILES:
		for dx in COARSE_TILES:
			kinds[(cy * COARSE_TILES + dy) * tw + cx * COARSE_TILES + dx] = kind


## 지도 밖을 물으면 JS 배열처럼 undefined — 어떤 종류와도 같지 않다
func _kind_at(cx: int, cy: int) -> int:
	var i := cy * COARSE_TILES * tw + cx * COARSE_TILES
	if i < 0 or i >= kinds.size(): return -1
	return kinds[i]


func _pick_tile(tiles: Dictionary, tx: int, ty: int) -> Array:
	var me := kinds[ty * tw + tx]
	var same := func(dx: int, dy: int) -> bool:
		var x := tx + dx; var y := ty + dy
		if x < 0 or y < 0 or x >= tw or y >= th: return true
		return kinds[y * tw + x] == me
	var key := ("" if same.call(0, -1) else "N") + ("" if same.call(0, 1) else "S") \
		+ ("" if same.call(-1, 0) else "W") + ("" if same.call(1, 0) else "E")
	if key == "":
		key = "iSE" if not same.call(1, 1) else "iSW" if not same.call(-1, 1) \
			else "iNE" if not same.call(1, -1) else "iNW" if not same.call(-1, -1) else "C"
	return _pick_from(tiles.get(key, tiles.C), key, tx, ty)


## 원본 시트의 2칸 반복 무늬가 이어지도록 위치 홀짝으로 고른다
static func _pick_from(list: Array, key: String, tx: int, ty: int) -> Array:
	var px := 0 if tx % 2 else 1
	var py := 0 if ty % 2 else 1
	if list.size() == 4: return list[py * 2 + px]
	if list.size() == 2: return list[px if (key == "N" or key == "S") else py]
	return list[0]


## 이 칸 아래로 절벽이 몇 칸 이어지는가. 0 이면 절벽의 맨 아랫줄이다
func _cliff_depth(tx: int, ty: int) -> int:
	var n := 0
	var y := ty + 1
	while y < th and kinds[y * tw + tx] == CLIFF_ID:
		n += 1; y += 1
	return n


## 고원 윗면의 테두리. _pick_tile 과 방식은 같지만 '고원 윗면'끼리만 같다고 본다 —
## 절벽 칸이면 다 같다고 보면 아래로 늘어진 바위 면까지 한 덩어리가 되어 아래쪽 테두리(S)가 사라진다
func _pick_cliff_tile(cliff: Dictionary, tx: int, ty: int) -> Array:
	var same := func(dx: int, dy: int) -> bool:
		var x := tx + dx; var y := ty + dy
		if x < 0 or y < 0 or x >= tw or y >= th: return true
		return kinds[y * tw + x] == CLIFF_ID and _cliff_depth(x, y) >= FACE_ROWS
	var key := ("" if same.call(0, -1) else "N") + ("" if same.call(0, 1) else "S") \
		+ ("" if same.call(-1, 0) else "W") + ("" if same.call(1, 0) else "E")
	if key == "": key = "C"   # 네모로만 세우니 오목한 모서리는 생기지 않는다
	return _pick_from(cliff.get(key, cliff.C), key, tx, ty)


func _bake(rng: Util.Mulberry32) -> Image:
	var T: Dictionary = Data.get_module("tiles")
	var base := TileImages.get_image("ground")
	var biome: Dictionary = Data.get_module("world_biomes").BIOMES.get(spec.get("biome", ""), Data.get_module("world_biomes").BIOMES.FOREST)
	var palette := int(biome.get("palette", 0))
	var sheet := TileImages.get_image("ground" + (str(palette + 1) if palette else ""))
	if sheet == null: sheet = base

	var img := Image.create_empty(tw * TILE_SRC, th * TILE_SRC, false, Image.FORMAT_RGBA8)
	var grass: Array = T.GRASS
	var decor: Array = T.GRASS_DECOR
	for ty in th:
		for tx in tw:
			var kind := kinds[ty * tw + tx]
			var t: Array
			if kind == DIRT_ID: t = _pick_tile(T.DIRT, tx, ty)
			elif kind == WATER_ID: t = _pick_tile(T.WATER, tx, ty)
			elif kind == CLIFF_ID:
				# 아래 세 줄은 늘어진 바위 면(맨 아랫줄은 둥근 마감), 그 위는 고원 윗면
				var below := _cliff_depth(tx, ty)
				if below == 0: t = T.CLIFF_FACE.foot[tx % 2]
				elif below < FACE_ROWS: t = T.CLIFF_FACE.body[tx % 2]
				else: t = _pick_cliff_tile(T.CLIFF, tx, ty)
			elif rng.next() < 0.09: t = decor[floori(rng.next() * decor.size())]   # 풀밭이 너무 반반해서 꽃·잔돌을 조금 더 섞는다
			else: t = grass[(ty % 2) * 2 + (tx % 2)]
			img.blit_rect(sheet, Rect2i(int(t[0]) * TILE_SRC, int(t[1]) * TILE_SRC, TILE_SRC, TILE_SRC), Vector2i(tx * TILE_SRC, ty * TILE_SRC))
	# 둥지 돌무더기 (2×2 타일). 풀 위에 겹쳐 그린다
	var ring: Array = T.NEST_RING
	for n in spec.get("nests", []):
		var nx := int(n[0]) * COARSE_TILES
		var ny := int(n[1]) * COARSE_TILES
		for i in ring.size():
			img.blend_rect(base, Rect2i(int(ring[i][0]) * TILE_SRC, int(ring[i][1]) * TILE_SRC, TILE_SRC, TILE_SRC),
				Vector2i((nx + i % 2) * TILE_SRC, (ny + (i >> 1)) * TILE_SRC))
	return img


## 물비늘을 놓을 자리를 고른다. 물은 구운 그림이라 가만히 있는데, 그 위에서 이것만 움직여도
## 물이 흐르는 것처럼 보인다. 가장자리에는 작은 조각을 드문드문, 트인 물 한가운데에는 온칸짜리를 아주 가끔만
func _make_sparkles(rng: Util.Mulberry32) -> Array:
	var S: Dictionary = Data.get_module("tiles").SPARKLE_SHEET
	var spots := []
	var is_water := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < tw and y < th and kinds[y * tw + x] == WATER_ID
	for ty in th:
		for tx in tw:
			if not is_water.call(tx, ty): continue
			var edge: bool = not is_water.call(tx - 1, ty) or not is_water.call(tx + 1, ty) \
				or not is_water.call(tx, ty - 1) or not is_water.call(tx, ty + 1)
			var r := rng.next()
			if (r < 0.35) if edge else (r < 0.05):
				var row := int(S.SMALL) if edge else int(S.FULL)
				var flip := rng.next() < 0.5
				spots.append({ tx = tx, ty = ty, row = row, flip = flip, phase = floori(rng.next() * S.frames) })
	return spots
