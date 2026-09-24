class_name Collision
## 2D판 world/collision.js. 지형·소품 충돌.
##
##  - 물   : 헤엄칠 수 없다. 강을 건너려면 여울(흙길)을 찾아야 한다
##  - 소품 : 나무 둥치·바위·집·분수·상자더미가 막는다. 덤불·고사리·표지판·
##           모닥불·보물상자는 통과한다 (주우러 다가가야 하니까)
##
## 날아다니는 적(def.flying)과 보스는 아무것도 신경 쓰지 않는다.

# 소품 종류별 밑동 크기 (월드 px, 중심에서 좌우/위아래 반지름, 셋째 값은 상자 중심을 위아래로 옮기는 값)
const FOOTPRINT := {
	"TREE": [17, 11],
	"ROCK": [22, 13],
	"STUMP": [17, 10],
	# 집은 그림(240x240)이 밑동보다 훨씬 커서, 밑동만 막으면 집 뒤로 돌아 들어간 용이 그림에 통째로 가려진다.
	# 그림이 가리는 자리까지 막는다. 위쪽은 110px 까지만: 더 막으면 집 뒤로 난 길까지 막힌다
	"HOUSE": [100, 71, -39],
	"HUT": [40, 34, -30],       # 포코의 오두막 (그림 93x132px)
	"FOUNTAIN": [42, 24],
	"CRATE": [15, 10],
	"BARREL": [15, 10],
	"WATERFALL": [76, 26],
	# 마을 시트에서 캐낸 것들. 작은 잡동사니(자갈·해골·삭정이)는 일부러 넣지 않는다 — 밟고 지나가야 걸리적거리지 않는다
	"WELL": [26, 16],
	"STALL": [50, 24],
	"GATE": [40, 22],
	"TEMPLE": [30, 16],
	"RUIN": [26, 15],
	"BANNER": [12, 9],
	"STONE_WALL": [30, 18],
	"CAVE_ARCH": [48, 22],
	"GARDEN": [46, 30],
	"VINE_PILLAR": [14, 9],
	"STUMP_TABLE": [30, 16],
	"BARRELS": [22, 12],
	"TOWER": [30, 14],
	"CRATE_BIG": [16, 11],
}

const CELL := 160                   # 공간 해시 칸 크기
# 지날 수 없는 바닥: 물(바깥 세상) · 벽(던전) · 절벽(바위 고원)
const BLOCKING := { "WATER": 1, "WALL": 1, "CLIFF": 1 }

static var _grid := {}              # Vector2i → [{ x, y, rx, ry }, ...]


## 지도를 만든 뒤 한 번 호출. 막히는 소품들을 격자에 담아 둔다
static func build_prop_grid(props: Array) -> void:
	_grid = {}
	for p in props: add_prop(p)


## 나중에 생긴 소품 하나를 격자에 더한다
static func add_prop(p) -> void:
	var f = FOOTPRINT.get(p.type)
	if f == null: return
	var box := { x = p.x, y = p.y + (f[2] if f.size() > 2 else 0), rx = f[0], ry = f[1] }
	for cy in range(floori((box.y - f[1]) / CELL), floori((box.y + f[1]) / CELL) + 1):
		for cx in range(floori((box.x - f[0]) / CELL), floori((box.x + f[0]) / CELL) + 1):
			var k := Vector2i(cx, cy)
			if not _grid.has(k): _grid[k] = []
			_grid[k].append(box)


## (x,y) 에 반지름 r 로 섰을 때 소품에 닿는가
static func _hits_prop(x: float, y: float, r: float) -> bool:
	var cx := floori(x / CELL)
	var cy := floori(y / CELL)
	for j in range(-1, 2):
		for i in range(-1, 2):
			for b in _grid.get(Vector2i(cx + i, cy + j), []):
				if absf(x - b.x) < b.rx + r * 0.75 and absf(y - b.y) < b.ry + r * 0.5: return true
	return false


## 막힌 바닥인가. 발밑 한 점만 보면 타일 모서리에서 끼기 쉬워 좌우도 같이 본다
static func _hits_ground(x: float, y: float, r: float) -> bool:
	return BLOCKING.has(Terrain.ground_at(x, y)) \
		or BLOCKING.has(Terrain.ground_at(x - r * 0.7, y)) \
		or BLOCKING.has(Terrain.ground_at(x + r * 0.7, y))


## 그 자리에 설 수 없으면 true
static func solid_at(x: float, y: float, r := 18.0) -> bool:
	return _hits_ground(x, y, r) or _hits_prop(x, y, r)


## 충돌을 보며 옮긴다. 가로·세로를 따로 밀어 보기 때문에 벽을 따라 미끄러진다.
## 이미 막힌 자리에 끼어 있으면 그냥 보내 준다 (영영 갇히지 않게).
static func slide_move(e, nx: float, ny: float, r := 18.0) -> void:
	if solid_at(e.x, e.y, r):
		e.x = nx; e.y = ny
		return
	if not solid_at(nx, e.y, r): e.x = nx
	if not solid_at(e.x, ny, r): e.y = ny
