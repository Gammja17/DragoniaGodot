class_name RoomMap
extends GameMap
## 2D판 world/room.js. 굴 속 한 칸. 용마다 하나씩 배정받아 사는 보금자리다.
## 방 하나뿐이고, 들어갈 때마다 모양이 바뀌지 않는다. 씨앗이 같으면 바닥 무늬까지 늘 같다.
## 바깥 지도(GameMap)와 같은 얼굴을 해서, 나머지 코드가 굴 안인지 밖인지 신경 쓰지 않아도 되게 한다.

const WALL := 0
const FLOOR := 1
const PAD := 2               # 방 둘레의 바위 두께

var room := true
var floor_rect: Rect2        # 방 안쪽의 월드 좌표 범위 (가구를 놓을 수 있는 칸)
var center: Vector2
var _inner_w: int
var _inner_h: int


## spec: data/dens 의 한 굴 { id, name, tw, th, seed, torches }
static func build_room(spec: Dictionary) -> RoomMap:
	var m := RoomMap.new()
	var tw := int(spec.get("tw", 19))
	var th := int(spec.get("th", 13))
	m.id = spec.id
	m.spec = { id = spec.id, biome = "DEN" }
	m._inner_w = tw; m._inner_h = th
	m.tw = tw + PAD * 2; m.th = th + PAD * 2
	m.cw = 0; m.ch = 0
	m.w = m.tw * TILE; m.h = m.th * TILE
	m.floor_rect = Rect2(PAD * TILE, PAD * TILE, tw * TILE, th * TILE)
	m.center = Vector2((PAD + tw / 2.0) * TILE, (PAD + th / 2.0) * TILE)
	m.kinds = PackedByteArray()
	m.kinds.resize(m.tw * m.th)
	for y in th:
		for x in tw:
			m.kinds[(y + PAD) * m.tw + (x + PAD)] = FLOOR
	m.texture = ImageTexture.create_from_image(m._bake_room(int(spec.get("seed", 1)), int(spec.get("torches", 3))))
	m.sparkles = []
	return m


func ground_at(x: float, y: float) -> String:
	var tx := floori(x / TILE)
	var ty := floori(y / TILE)
	var inside := tx >= PAD and ty >= PAD and tx < PAD + _inner_w and ty < PAD + _inner_h
	return "FLOOR" if inside else "WALL"


func _is_floor(tx: int, ty: int) -> bool:
	return tx >= 0 and ty >= 0 and tx < tw and ty < th and kinds[ty * tw + tx] == FLOOR


## 벽 칸 하나가 쓸 구멍 타일을 고른다 (data/tiles.js 의 caveVoidTile). 사방이 다 벽이면 null — 깊은 속은 굳이 그리지 않는다
func _cave_void_tile(tx: int, ty: int):
	return cave_void_tile(tx, ty, _is_floor)


## 굴 벽 오토타일. 굴 속 미궁(DungeonMap)도 같은 것을 쓴다. is_floor(tx, ty) -> bool
static func cave_void_tile(tx: int, ty: int, is_floor: Callable):
	var V: Dictionary = Data.get_module("tiles").CAVE_VOID
	var key := ("N" if is_floor.call(tx, ty - 1) else "") + ("S" if is_floor.call(tx, ty + 1) else "") \
		+ ("W" if is_floor.call(tx - 1, ty) else "") + ("E" if is_floor.call(tx + 1, ty) else "")
	if key == "":
		if is_floor.call(tx + 1, ty + 1): key = "iSE"
		elif is_floor.call(tx - 1, ty + 1): key = "iSW"
		elif is_floor.call(tx + 1, ty - 1): key = "iNE"
		elif is_floor.call(tx - 1, ty - 1): key = "iNW"
		else: return null
	return V.get(key, V.C)


func _bake_room(seed: int, torches: int) -> Image:
	var T: Dictionary = Data.get_module("tiles")
	var rng := Util.Mulberry32.new(seed + 7)
	var img := Image.create_empty(tw * TILE_SRC, th * TILE_SRC, false, Image.FORMAT_RGBA8)
	img.fill(Color("#0a0a10"))
	var sheet := TileImages.get_image("cave")
	var put := func(t: Array, tx: int, ty: int) -> void:
		img.blend_rect(sheet, Rect2i(int(t[0]) * TILE_SRC, int(t[1]) * TILE_SRC, TILE_SRC, TILE_SRC), Vector2i(tx * TILE_SRC, ty * TILE_SRC))
	# 아래쪽 벽면(방을 마주보는 면)에 횃불을 고르게 건다
	var facing_row := []
	for ty in th:
		for tx in tw:
			if kinds[ty * tw + tx] == FLOOR: continue
			if ty + 1 < th and kinds[(ty + 1) * tw + tx] == FLOOR: facing_row.append(tx + ty * tw)
	var lit := {}
	for i in torches:
		if facing_row.is_empty(): break
		lit[facing_row[floori(((i + 0.5) / torches) * facing_row.size())]] = true
	var floor_tiles: Array = T.CAVE_FLOOR
	var rubble: Array = T.CAVE_RUBBLE
	for ty in th:
		for tx in tw:
			var i := ty * tw + tx
			if kinds[i] == FLOOR:
				put.call(floor_tiles[floori(rng.next() * floor_tiles.size())], tx, ty)
				if rng.next() < 0.05: put.call(rubble[floori(rng.next() * rubble.size())], tx, ty)
				continue
			var t = _cave_void_tile(tx, ty)
			if t == null: continue
			put.call(t, tx, ty)
			if lit.has(i): put.call(T.CAVE_TORCH, tx, ty)   # 횃불은 반투명이라 벽 위에 얹는다
	return img
