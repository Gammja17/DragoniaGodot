class_name Prop
extends Node2D
## 2D판 entities/Prop.js. 나무·덤불·집·분수·포탈·석비·굴 입구 같은 붙박이들.
## 노드 원점이 발 위치(x, y)라 부모의 y 정렬이 앞뒤를 가른다.
##
## 밤의 불빛(light)은 연출 단계에서 조명과 함께 붙인다.

# 코드로 찍은 픽셀 아이콘으로 그리는 소품: [배율, 발에서 위로 올릴 px]
const ICON_PROPS := { "CAVE": [8, 48], "DEN_MOUTH": [8, 48], "STAIRS_DOWN": [5, 24], "STAIRS_UP": [5, 24], "ARENA": [4, 26], "TOWER": [7, 77] }
# 늘 움직이는 것들은 매 프레임 다시 그린다 (나무는 뒤에 숨은 것에 따라 투명해진다)
const ANIMATED := ["TREE", "FOUNTAIN", "PORTAL", "CAVE", "TOWER", "WAYSTONE", "WATERFALL", "CAMPFIRE", "BERRY"]

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

var _flame: Node2D           # 모닥불 불꽃 (더하기 섞기라 따로 그린다)


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
	if t == "CAMPFIRE":
		_flame = Node2D.new()
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD   # 2D판 'lighter'
		_flame.material = mat
		_flame.draw.connect(_draw_flame)
		add_child(_flame)
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
	Hud.pop("달콤한 열매를 먹었습니다. (허기 +30, 체력 +15)", "🍒")


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
	# 알은 귀하다. 성체가 된 뒤에만, 쉰에 하나
	if GameState.player.stage_index >= 2 and randf() < 0.02:
		World.add_entity("items", Item.make(x + 30, y + 20, "EGG"))
		Hud.pop("상자 안에 용의 알이 있습니다!", "🥚")
	Vfx.spawn_effect("STAR", x, y - 20)
	Sfx.play("pickup")
	if randf() < 0.22:
		var id = Relics.random_relic()
		if id: Relics.grant(id, x, y)
	# 가끔 굴에 들여놓을 살림살이가 들어 있다
	if randf() < 0.3:
		var pool := Den.furniture().keys().filter(func(k): return Den.furniture()[k].cost.get("gold", 0) <= 120)
		Den.give_furniture(pool.pick_random())
	Hud.pop("보물상자를 열었습니다!", "🎁")
	Quests.notify("chest")


func _process(_dt: float) -> void:
	if ANIMATED.has(type):
		queue_redraw()
		if _flame: _flame.queue_redraw()


func _draw() -> void:
	if is_hidden: return
	match type:
		"WATERFALL": _draw_waterfall()
		"PORTAL": _draw_portal()
		"WAYSTONE": _draw_waystone()
		"CAVE": _draw_cave()
		"TOWER": _draw_tower()
		"FURNITURE": _draw_furniture()
		_:
			if ICON_PROPS.has(type): Pixel.draw_icon(self, type, 0, -ICON_PROPS[type][1], ICON_PROPS[type][0])
			elif sprite: _draw_sprite()
			elif type == "CAMPFIRE": Pixel.draw_icon(self, "LOGS", 0, 0, 3)   # 장작. 불꽃은 _draw_flame


## 모닥불 불꽃 애니메이션 (64x64, 10열 × 6행)
func _draw_flame() -> void:
	var fire := Vfx.texture("campfire")
	if fire == null: return
	var f := floori(GameState.game_time * 24 + seed * 60) % 60
	_flame.draw_texture_rect_region(fire, Rect2(-48, -112, 96, 96), Rect2((f % 10) * 64, floori(f / 10.0) * 64, 64, 64))


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
