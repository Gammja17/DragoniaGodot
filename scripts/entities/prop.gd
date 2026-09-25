class_name Prop
extends Node2D
## 2D판 entities/Prop.js. 나무·덤불·집·분수·포탈·석비·굴 입구 같은 붙박이들.
## 노드 원점이 발 위치(x, y)라 부모의 y 정렬이 앞뒤를 가른다.
##
## 밤의 불빛(light)은 연출 단계에서 조명과 함께 붙인다.

# 코드로 찍은 픽셀 아이콘으로 그리는 소품: [배율, 발에서 위로 올릴 px]
const ICON_PROPS := { "CAVE": [8, 48], "DEN_MOUTH": [8, 48], "STAIRS_DOWN": [5, 24], "STAIRS_UP": [5, 24], "ARENA": [4, 26], "TOWER": [7, 77],
	"DRAGON_SKULL": [5, 32], "BONES": [4, 20], "RIB": [5, 45], "RIB_L": [5, 45] }   # 결투장: 옛 용의 뼈
# 같은 아이콘을 좌우로 뒤집어 그리는 소품 (갈비뼈 한 쌍이 서로 마주 보고 휜다)
const ICON_FLIP := { "RIB_L": "RIB" }
# 늘 움직이는 것들은 매 프레임 다시 그린다 (나무는 뒤에 숨은 것에 따라 투명해진다)
const ANIMATED := ["TREE", "FOUNTAIN", "PORTAL", "CAVE", "TOWER", "WAYSTONE", "WATERFALL", "CAMPFIRE", "BERRY", "FROST", "WISP", "EGG_WALL", "MARK_STONE", "SAND_BOIL"]

var x: float:
	get: return position.x
	set(v): position.x = v
var y: float:
	get: return position.y
	set(v): position.y = v

var type: String
var seed: float
var sprite = null            # data/tiles.json PROP_SPRITES 의 한 칸
var sheet_key = null
var remove := false
var is_hidden := false
# 종류에 따라 붙는 것들
var portal = null            # { side, to, name, needsFlight } 또는 굴의 { to, name, spot }
var chest_id = null
var opened := false
var stone_id = null
var cave_id = null
var den_id = null
var ripe_at := 0.0
var fid = null               # 굴 살림살이 (data/furniture.json 의 id)

const BERRY_REGROW := 100.0  # 초

var _flame: Node2D           # 모닥불 불꽃 · 도깨비불 (더하기 섞기라 따로 그린다)


func setup(px: float, py: float, t: String) -> Prop:
	x = px; y = py
	type = t
	seed = fmod(absf(sin(px * 12.9898 + py * 78.233) * 43758.5453), 1.0)   # 위치로 정해지는 고정 난수
	var variants = Data.get_module("tiles").PROP_SPRITES.get(t)
	if variants: sprite = variants[floori(seed * variants.size())]
	# 숲 소품은 바이옴 색상판에 맞는 시트를 쓴다 (trees → trees2, trees3)
	var biomes: Dictionary = Data.get_module("world_biomes").BIOMES
	var palette := int(biomes.get(Terrain.active_biome(), biomes.FOREST).palette)
	if sprite:
		sheet_key = sprite.sheet
		if (sprite.sheet == "trees" or sprite.sheet == "props") and palette: sheet_key = sprite.sheet + str(palette + 1)
	name = "%s_%d_%d" % [t, int(px), int(py)]
	if t == "CAMPFIRE" or t == "WISP":
		_flame = Node2D.new()
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD   # 2D판 'lighter'
		_flame.material = mat
		_flame.draw.connect(_draw_flame if t == "CAMPFIRE" else _draw_wisp)
		add_child(_flame)
	if t == "FROST" or t == "SAND_BOIL": z_index = -5   # 바닥에 깔린다 (지형 위, 다른 모든 것 아래)
	return self


## 이동 석비가 깨어 있는가
var awake: bool:
	get: return stone_id != null and GameState.waystones.has(stone_id)

## 열매 덤불(type 'BERRY')은 따고 나면 얼마 뒤에 다시 열린다
var ripe: bool:
	get: return GameState.game_time >= ripe_at


## 그루터기(type 'STUMP')에서 나뭇가지를 줍는다. 열매처럼 시간이 지나면 다시 생긴다
func gather() -> void:
	ripe_at = GameState.game_time + BERRY_REGROW
	var n := 2 if randf() < 0.4 else 1
	GameState.den.twigs += n
	Sfx.play("pickup")
	Hud.pop("나뭇가지 +%d (%d / 8)" % [n, GameState.den.twigs], "🪵")


func harvest() -> void:
	ripe_at = GameState.game_time + BERRY_REGROW
	var p = GameState.player
	p.hunger = minf(100, p.hunger + 30)
	p.hp = minf(p.max_hp, p.hp + 15)
	Hud.pop("달콤한 열매를 먹었습니다. (배부름 +30, 체력 +15)", "🍒")


## 보물상자 열기 (type 'CHEST'). chest_id 로 열린 상자를 기억한다
func open() -> void:
	opened = true
	sprite = Data.get_module("tiles").PROP_SPRITES.CHEST_OPEN[0]
	sheet_key = sprite.sheet
	queue_redraw()
	if chest_id != null: GameState.openedChests[chest_id] = true   # 굴의 상자는 한 판짜리라 기록하지 않는다
	var far := Vector2(x - 1200, y - 1200).length() / 1000   # 마을에서 멀수록 두둑하다
	var gold := roundi(20 + far * 25 + randf() * 20)
	World.add_entity("items", Item.make(x, y + 30, "GOLD", gold))
	if randf() < 0.6: World.add_entity("items", Item.make(x - 30, y + 20, "MEAT"))
	for i in 1 + floori(randf() * 2): World.add_entity("items", Item.make(x - 50 - i * 24, y + 26, "MAT", "ORE"))
	# 상자에서 알은 나오지 않는다. 아이는 짝과 품은 알에서만 (주운 알은 부모를 알 수 없어 뺐다)
	Vfx.spawn_effect("STAR", x, y - 20)
	Sfx.play("pickup")
	if randf() < 0.22:
		var id = Relics.random_relic()
		if id: Relics.grant(id, x, y)
	# 가끔 굴에 들여놓을 살림살이가 들어 있다 (이웃에게 받는 선물은 상자에서 나오지 않는다)
	if randf() < 0.3:
		var pool := Den.furniture().keys().filter(func(k): return not Den.furniture()[k].get("gift") and Den.furniture()[k].cost.get("gold", 0) <= 120)
		Den.give_furniture(pool.pick_random())
	Hud.pop("보물상자를 열었습니다!", "🎁")
	Quests.notify("chest")


func _process(_dt: float) -> void:
	if ANIMATED.has(type):
		queue_redraw()
		if _flame: _flame.queue_redraw()


## 밤에 주변을 밝히는 빛 (render/lighting.gd)
func light():
	var t := GameState.game_time
	match type:
		"CAMPFIRE": return { r = 340 + sin(t * 13 + seed * 9) * 22, color = "#ffab5c", dy = -30, emissive = true }
		"HOUSE": return { r = 210, color = "#ffd38a", intensity = 0.85, dy = -50 }   # 창문 불빛
		"HUT": return { r = 150, color = "#ffd38a", intensity = 0.7, dy = -34 }
		"FOUNTAIN": return { r = 170, color = "#9fd8ff", intensity = 0.5, dy = -20 }
		"BERRY": return { r = 70, color = "#ff7a9a", intensity = 0.4, dy = -20 } if ripe else null
		"CHEST": return null if opened else { r = 110, color = "#ffd84a", intensity = 0.7, dy = -16 }
		"WAYSTONE": return { r = 130, color = "#7fd4ff", intensity = 0.85 if awake else 0.35, dy = -40 }
		"STAIRS_UP": return { r = 200, color = "#ffe9b0", intensity = 0.9, dy = -20, emissive = true }
		"CAVE": return { r = 170, color = "#c58aff", intensity = 0.6, dy = -34, emissive = true }
		"DEN_MOUTH": return { r = 190, color = "#ffc87a", intensity = 0.75, dy = -34, emissive = true }
		"TOWER": return { r = 230, color = "#ffc87a", intensity = 0.8, dy = -120, emissive = true }   # 망루의 등불
		"FURNITURE":   # 스스로 빛나는 살림살이 (화로·구슬)
			var f = Den.furniture().get(fid)
			if not f or not f.get("light"): return null
			return { r = 240 + sin(t * 9 + seed * 7) * 16, color = f.light, dy = -28, emissive = true }
		"PORTAL": return { r = 150, color = "#9fe3ff", intensity = 0.7, dy = -40, emissive = true }
		"WATERFALL": return { r = 260, color = "#bfe9ff", intensity = 0.45, dy = -160 }
		"MARK_STONE":   # 새긴 무늬의 홈이 불씨처럼 빛난다. 이그나르가 무릎을 꿇으면 꺼진다
			var mk := BossShow.lair_alpha(x, y, 1.0)
			return null if mk <= 0.02 else { r = 150, color = "#ff9a3c", intensity = 0.6 * mk, dy = -132, emissive = true }
		"EGG_WALL":   # 알을 가둔 얼음벽이 희미하게 빛난다. 녹으면 꺼진다
			var ice := BossShow.lair_alpha(x, y, 1.0)
			return null if ice <= 0.02 else { r = 330, color = "#9fe3ff", intensity = 0.5 * ice, dy = -110, emissive = true }
		"WISP":   # 도깨비불. 보스를 보내면 함께 꺼진다
			var k := BossShow.lair_alpha(x, y, 1.0)
			return null if k <= 0.02 else { r = 190 + sin(t * 5 + seed * 9) * 14, color = "#7fd4ff", intensity = 0.7 * k, dy = -52, emissive = true }
	return null


func _draw() -> void:
	if is_hidden: return
	match type:
		"WATERFALL": _draw_waterfall()
		"PORTAL": _draw_portal()
		"WAYSTONE": _draw_waystone()
		"CAVE": _draw_cave()
		"TOWER": _draw_tower()
		"FURNITURE": _draw_furniture()
		"FROST": _draw_frost()
		"EGG_WALL": _draw_egg_wall()
		"MARK_STONE": _draw_mark_stone()
		"SAND_BOIL": _draw_sand_boil()
		"TOMB": _draw_art("morgath_grave")          # 모르가스의 무덤
		"TWIN_NEST": _draw_art("twin_nest")         # 잘고라 형제의 둥지 (구멍 둘, 못 박은 팽이)
		"BEAST_BONES": _draw_art("beast_bones")     # 바실의 사구: 묻힌 짐승 뼈와 부러진 창 셋
		_:
			if ICON_FLIP.has(type):
				var tex := Pixel.get_icon(ICON_FLIP[type])
				Pixel.draw_pixel_sprite(self, tex, Rect2(Vector2.ZERO, tex.get_size()), 0, -ICON_PROPS[type][1], ICON_PROPS[type][0], true, 0.5, 0.5)
			elif ICON_PROPS.has(type): Pixel.draw_icon(self, type, 0, -ICON_PROPS[type][1], ICON_PROPS[type][0])
			elif sprite: _draw_sprite()
			elif type == "CAMPFIRE": Pixel.draw_icon(self, "LOGS", 0, 0, 3)   # 장작. 불꽃은 _draw_flame


## 모닥불 불꽃 애니메이션 (64x64, 10열 × 6행)
func _draw_flame() -> void:
	var fire := Vfx.texture("campfire")
	if fire == null: return
	var f := floori(GameState.game_time * 24 + seed * 60) % 60
	_flame.draw_texture_rect_region(fire, Rect2(-48, -112, 96, 96), Rect2((f % 10) * 64, floori(f / 10.0) * 64, 64, 64))


## 도깨비불: 무덤가를 떠도는 푸른 불 (5px 알갱이). 위로 갈수록 흔들린다. 보스를 보내면 함께 사라진다
func _draw_wisp() -> void:
	var k := BossShow.lair_alpha(x, y, 1.0)
	if k <= 0.01: return
	var t := GameState.game_time * 2.0 + seed * 7.0
	var bob := -56.0 + sin(t) * 8.0
	var sway := sin(t * 1.7) * 4.0
	const PX := 5
	Pixel.draw_glow(_flame, sway, bob - 18, 52 + sin(t * 3.1) * 5, Color("#4fb8ff"), 0.55 * k)   # 둘레의 푸른 빛
	Pixel.draw_glow(_flame, 0, -4, 26, Color("#4fb8ff"), 0.22 * k)                            # 바닥에 비친 빛
	const ROWS := ["..w..", ".wbw.", ".wbw.", "wbcbw", "wbcbw", ".bcb.", "..b.."]
	const COLS := { "w": "#4fb8ff", "b": "#9fe3ff", "c": "#eaffff" }
	for ry in ROWS.size():
		var row: String = ROWS[ry]
		var shift := roundf(sin(t * 4.0 + ry * 0.9) * (4.0 - ry)) if ry < 3 else 0.0
		for rx in row.length():
			var ch := row[rx]
			if ch == ".": continue
			_flame.draw_rect(Rect2(roundf(sway) + shift + (rx - 2.5) * PX, roundf(bob) + (ry - 7) * PX, PX, PX), Color(COLS[ch], k * (0.8 if ch == "w" else 1.0)))


## 끓는 모래 (바실의 결투장): 모래 밑에서 무언가 움직이듯 물결이 번지고 거품이 터진다. 바실이 쓰러지면 잦아든다
func _draw_sand_boil() -> void:
	var k := BossShow.lair_alpha(x, y, 1.0)
	if k <= 0.01: return
	var t := GameState.game_time * 1.4 + seed * 9.0
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.42))
	draw_circle(Vector2.ZERO, 26, Color(0.62, 0.47, 0.2, 0.35 * k))   # 가운데 짙은 모래
	for i in 3:   # 번지는 물결
		var ph := fmod(t + i / 3.0, 1.0)
		draw_arc(Vector2.ZERO, 20 + ph * 70, 0, TAU, 32, Color(0.95, 0.82, 0.5, (1.0 - ph) * 0.45 * k), 3.0)
	draw_set_transform(Vector2.ZERO)
	for i in 4:   # 거품이 솟았다 터진다
		var ph := fmod(t * 1.3 + i * 0.27 + seed, 1.0)
		var at := Vector2(roundf(cos(seed * 30.0 + i * 1.7) * 30), roundf(sin(seed * 30.0 + i * 1.7) * 12) - ph * 8)
		draw_arc(at, 3.0 + ph * 5.0, 0, TAU, 12, Color(0.98, 0.9, 0.62, (1.0 - ph) * 0.8 * k), 2.0)


## 하늘 용의 표식(한 줄이 셋으로 갈라졌다가 다시 모이는 무늬)을 새긴 돌. 이그나르의 결투장을 두른다.
## 홈이 불씨처럼 숨 쉬듯 빛나다가, 이그나르가 무릎을 꿇으면 꺼진다
func _draw_mark_stone() -> void:
	_draw_art("mark_monolith")
	var k := BossShow.lair_alpha(x, y, 1.0)
	if k <= 0.01: return
	var t := GameState.game_time * 1.8 + seed * 6.0
	Pixel.draw_glow(self, 0, -132, 34 + sin(t) * 4, Color("#ff9a3c"), (0.35 + 0.15 * sin(t)) * k)


## 글라시아의 알 벽: 얼음 속에 알이 가지런히 박혀 있다. 글라시아가 잠들면 얼음이 녹아 눈 둥지에 알만 남는다 (BossShow.lair_alpha)
func _draw_egg_wall() -> void:
	var ice := BossShow.lair_alpha(x, y, 1.0)   # 1: 얼어 있음 → 0: 다 녹음
	if ice < 1.0: _draw_art("egg_nest")         # 녹은 자리: 눈 둥지의 알
	if ice > 0.0: _draw_art("egg_wall", ice)    # 얼음벽 속의 알


## 결투장 그림 (assets/sprites/arena). 발 위치가 그림 밑동의 가운데다. 타일 소품과 같은 픽셀 크기로 세 배 키워 찍는다.
## 타일 시트처럼 한 번 불러 Image 로 바꿔 둔다 (가져온 텍스처를 곧바로 그리면 창에서 회색 네모로만 나왔다)
static var _art := {}
func _draw_art(file: String, alpha := 1.0) -> void:
	if not _art.has(file):
		var path := "res://assets/sprites/arena/%s.png" % file
		var src = load(path) if ResourceLoader.exists(path) else null
		_art[file] = ImageTexture.create_from_image(src.get_image()) if src else null
	var tex = _art[file]
	if tex == null: return
	var w: float = tex.get_width() * 3.0
	var h: float = tex.get_height() * 3.0
	draw_texture_rect(tex, Rect2(roundf(x - w / 2) - x, roundf(y - h) - y, w, h), false, Color(1, 1, 1, alpha))


## 모르가스의 서리. 무덤가 바닥에 옅게 깔려 있다가, 보스가 깨어나면 무덤에서부터 번져 짙어지고, 잠들면 녹는다
func _draw_frost() -> void:
	var a := BossShow.lair_alpha(x, y, 0.35, true)
	if a <= 0.01: return
	var r := 70.0 + seed * 50.0
	# 가장자리가 번진 흐린 자락 몇 겹 (둥근 선이 비치지 않게 부드러운 빛 그림을 눕혀 쓴다)
	var soft := Pixel.glow_texture()
	var rime := Color(0.66, 0.86, 1.0, 0.6 * a)
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.45))
	draw_texture_rect(soft, Rect2(-r, -r, r * 2, r * 2), false, rime)
	draw_texture_rect(soft, Rect2(r * 0.1, -r * 0.9, r * 1.4, r * 1.4), false, rime)
	draw_texture_rect(soft, Rect2(-r * 1.25, -r * 0.35, r * 1.2, r * 1.2), false, rime)
	draw_set_transform(Vector2.ZERO)
	for i in 5:   # 얼음 결정: 네 갈래로 반짝인다
		var ang := seed * 40.0 + i * 2.3
		var rr := r * (0.15 + fmod(seed * float(i + 3) * 7.13, 0.65))
		var px := roundf(cos(ang) * rr)
		var py := roundf(sin(ang) * rr * 0.45)
		var tw := 0.5 + 0.5 * sin(GameState.game_time * 2.6 + i * 1.7 + seed * 9.0)
		var c := Color(0.9, 0.97, 1.0, (0.25 + 0.7 * tw) * a)
		draw_rect(Rect2(px - 1, py - 4, 3, 9), c)
		draw_rect(Rect2(px - 4, py - 1, 9, 3), c)


## 폭포. 세 부분을 쌓는다: 맨 윗칸 → 떨어지는 물(두 행을 번갈아) → 바닥 물보라.
## 물보라는 마지막 낙수 칸을 덮어야 물줄기가 허공에서 뚝 끊기지 않는다.
func _draw_waterfall() -> void:
	var sheet := TileImages.get_texture("waterfall")
	var W: Dictionary = Data.get_module("tiles").WATERFALL_SHEET
	var TILE := GameMap.TILE
	var SRC := GameMap.TILE_SRC
	var f := (floori(GameState.game_time * W.fps + seed * W.frames) % int(W.frames)) * SRC
	var cols := 3
	var rows := 7
	var left := roundf(x) - x - cols * TILE / 2.0
	var top := roundf(y) - y - rows * TILE
	var put := func(row: float, gx: int, gy: int, flip := false) -> void:
		var dx := left + gx * TILE
		var dy := top + gy * TILE
		var dst := Rect2(dx + TILE, dy, -TILE, TILE) if flip else Rect2(dx, dy, TILE, TILE)
		draw_texture_rect_region(sheet, dst, Rect2(f, row * SRC, SRC, SRC))
	# 뒤쪽 어두운 바위 틈. 없으면 폭포가 허공에 뜬 것처럼 보인다
	draw_rect(Rect2(left - 6, top - 10, cols * TILE + 12, rows * TILE - TILE), Color("#10202e"))
	for gx in cols:
		put.call(W.TOP, gx, 0)
		for gy in range(1, rows): put.call(W.FALL[(gy - 1) % 2], gx, gy)
	for gx in cols:
		put.call(W.SPLASH[0], gx, rows - 2); put.call(W.SPLASH[1], gx, rows - 1)
	put.call(W.CAP[0], -1, rows - 2); put.call(W.CAP[1], -1, rows - 1)
	put.call(W.CAP[0], cols, rows - 2, true); put.call(W.CAP[1], cols, rows - 1, true)


## 굴에 놓은 살림살이. 타일 시트에서 칸 하나를 떠 온다
func _draw_furniture() -> void:
	var f = Den.furniture().get(fid)
	if not f: return
	var sheet := TileImages.get_texture(Den.sheet_of(f))
	var T := GameMap.TILE
	var S := GameMap.TILE_SRC
	var w: float = f.span[0] * T
	var h: float = f.span[1] * T
	draw_texture_rect_region(sheet, Rect2(roundf(x - w / 2) - x, roundf(y - h) - y, w, h), Rect2(f.tile[0] * S, f.tile[1] * S, f.span[0] * S, f.span[1] * S))


## 다른 지도로 넘어가는 문. 이름표는 Overlay 가 화면 픽셀로 따로 단다
func _draw_portal() -> void:
	var t := GameState.game_time * 2 + seed * 6
	Pixel.draw_glow(self, 0, -44, 52, Color("#9fe3ff"), 0.55 + sin(t) * 0.18)
	var o := Vector2(roundf(x) - x, roundf(y) - y)
	draw_rect(Rect2(o + Vector2(-34, -96), Vector2(68, 96)), Color(12 / 255.0, 20 / 255.0, 34 / 255.0, 0.85))
	var frame := Color("#7fd4ff")
	draw_rect(Rect2(o + Vector2(-36, -100), Vector2(72, 5)), frame)
	draw_rect(Rect2(o + Vector2(-36, -100), Vector2(5, 100)), frame)
	draw_rect(Rect2(o + Vector2(31, -100), Vector2(5, 100)), frame)


## 굴 입구. 잿빛 바위가 초록 바닥에 묻혀 안 보인다는 말이 많아서, 안쪽에서 보랏빛이 새어 나온다
func _draw_cave() -> void:
	var t := GameState.game_time * 1.6 + seed * 6
	Pixel.draw_glow(self, 0, -30, 70 + sin(t) * 6, Color("#c58aff"), 0.42 + sin(t) * 0.08)
	Pixel.draw_icon(self, "CAVE", 0, -48, 8)
	# 어두운 입 안쪽에 불빛 한 점
	draw_rect(Rect2(roundf(x) - x - 3, roundf(y) - y - 34, 6, 6), Color(210 / 255.0, 160 / 255.0, 1, 0.55 + sin(t * 2) * 0.2))


## 마을 망루. 퀘스트가 "망루로 가라"고 하는데 어디가 망루인지 몰라서, 그림과 이름표를 단다
func _draw_tower() -> void:
	Pixel.draw_icon(self, "TOWER", 0, -ICON_PROPS.TOWER[1], ICON_PROPS.TOWER[0])
	var t := GameState.game_time * 2 + seed * 5
	Pixel.draw_glow(self, 0, -118, 46 + sin(t) * 4, Color("#ffc87a"), 0.32 + sin(t) * 0.06)


## 이동 석비: 깨우기 전엔 흐릿하고, 깨우면 룬이 푸르게 돈다
func _draw_waystone() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 20, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO)
	if awake: Pixel.draw_glow(self, 0, -46, 46 + sin(GameState.game_time * 2 + seed * 6) * 6, Color("#7fd4ff"), 0.5)
	Pixel.draw_icon(self, "WAYSTONE", 0, -42, 5, Color(1, 1, 1, 1.0 if awake else 0.72))


## 타일셋 소품. 그림자는 스프라이트에 포함돼 있다
func _draw_sprite() -> void:
	var sp: Dictionary = sprite
	var S := GameMap.TILE_SCALE
	var w: float = sp.sw * S
	var h: float = sp.sh * S
	var left: float = x - w * sp.ax
	var top: float = y - h * sp.ay
	# 플레이어·적·아이템·상자 등이 나무 뒤에 가려지면 반투명하게
	var hides := false
	if type == "TREE":
		for e in GameState.fadeTargets:
			if not is_instance_valid(e): continue   # 굴 층을 옮긴 프레임엔 지난 층의 것이 남아 있다
			if e.y < y + 10 and e.y > top - 20 and absf(e.x - x) < w * 0.5:
				hides = true
				break
	var sx: float = sp.sx
	var sy: float = sp.sy
	if sp.get("frames"):
		var fr: Array = sp.frames[floori(GameState.game_time * sp.fps) % sp.frames.size()]
		sx = fr[0]; sy = fr[1]
	draw_texture_rect_region(TileImages.get_texture(sheet_key), Rect2(roundf(left) - x, roundf(top) - y, w, h),
		Rect2(sx, sy, sp.sw, sp.sh), Color(1, 1, 1, 0.32 if hides else 1.0))
	if type == "BERRY" and ripe:        # 익은 열매 알갱이
		for b in [[-18, -52], [6, -62], [20, -40], [-6, -34], [-26, -30]]:
			var bx := roundf(x + b[0]) - x
			var by := roundf(y + b[1]) - y
			draw_rect(Rect2(bx - 1, by - 1, 8, 8), Color("#7a1230"))
			draw_rect(Rect2(bx, by, 6, 6), Color("#ff4d78"))
			draw_rect(Rect2(bx + 1, by + 1, 2, 2), Color("#ffc2d2"))


## 화면 픽셀로 다는 이름표 (Overlay 가 부른다). ci 의 원점은 이 소품의 발 위치를 화면으로 옮긴 곳
func draw_crisp(ci: CanvasItem, zoom: float) -> void:
	if Cutscene.on: return   # 컷씬에서는 안내 글자를 비운다
	var label := ""
	var ly := 0.0
	var color: Color
	match type:
		"PORTAL":
			label = portal.name if portal else ""
			ly = -146; color = Color("#9fe3ff")
		"CAVE":
			label = Data.get_module("dungeons").DUNGEONS.get(cave_id, {}).get("name", "굴")
			ly = -126; color = Color("#d9b8ff")
		"TOWER":
			label = "망루"
			ly = -178 * zoom - 19; color = Color("#ffd98a")
		_: return
	var font := Fonts.bold()
	var w := ceilf(Fonts.text_width(font, label, 12)) + 16
	ci.draw_rect(Rect2(-w / 2, ly, w, 19), Color(10 / 255.0, 9 / 255.0, 16 / 255.0, 0.85))
	Fonts.draw_centered(ci, font, label, 0, ly + 14, 12, color)
