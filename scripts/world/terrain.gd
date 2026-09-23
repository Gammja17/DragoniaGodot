class_name Terrain
extends Node2D
## 2D판 world/terrain.js + mapgen.js 의 draw. "지금 밟고 있는 지도" 하나를 가리키고 바닥을 그린다.
## 구운 바닥 그림 한 장과, 그 위에서 흐르는 물비늘만 그린다.

static var active: GameMap = null


static func set_active_map(m: GameMap) -> void:
	active = m


## 지금 지도의 크기 (월드 px)
static func current_map_bounds() -> Vector2:
	return Vector2(active.w, active.h) if active else Vector2(1920, 1440)


## 밟고 있는 바닥 종류: 'GRASS' | 'DIRT' | 'WATER' | 'CLIFF' | (굴) 'FLOOR' | 'WALL'
static func ground_at(x: float, y: float) -> String:
	return active.ground_at(x, y) if active else "GRASS"


var _sparkle_tex: Texture2D


func _ready() -> void:
	_sparkle_tex = ImageTexture.create_from_image(TileImages.get_image("sparkle"))
	z_index = -10


func _process(_dt: float) -> void:
	queue_redraw()   # 물비늘이 움직인다


func _draw() -> void:
	if not active or not active.texture: return
	var S := GameMap.TILE_SCALE
	draw_texture_rect(active.texture, Rect2(0, 0, active.texture.get_width() * S, active.texture.get_height() * S), false)
	_draw_sparkles()


## 물 위에 흐르는 물비늘. 구운 그림 위에 얹는 유일한 움직이는 바닥
func _draw_sparkles() -> void:
	if active.sparkles.is_empty(): return
	var S: Dictionary = Data.get_module("tiles").SPARKLE_SHEET
	var TILE := GameMap.TILE
	var SRC := GameMap.TILE_SRC
	var t := floori(Time.get_ticks_msec() / 1000.0 * S.fps)
	var view := get_viewport_transform().affine_inverse() * get_viewport_rect()
	var x0 := view.position.x - TILE
	var x1 := view.end.x + TILE
	var y0 := view.position.y - TILE
	var y1 := view.end.y + TILE
	for p in active.sparkles:
		var dx: float = p.tx * TILE
		var dy: float = p.ty * TILE
		if dx < x0 or dx > x1 or dy < y0 or dy > y1: continue
		var f := ((t + int(p.phase)) % int(S.frames)) * SRC
		var src := Rect2(f, p.row * SRC, SRC, SRC)
		# 뒤집기는 폭을 음수로 준 사각형으로
		var dst := Rect2(dx + TILE, dy, -TILE, TILE) if p.flip else Rect2(dx, dy, TILE, TILE)
		draw_texture_rect_region(_sparkle_tex, dst, src)
