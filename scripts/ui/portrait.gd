extends Control
## 2D판 render/spritesheet.js 의 drawPortrait. 정면 대기 프레임을 칸에 꽉 차게 그린다 (대화창·HUD 초상화).
## 칸 바탕은 rgba(0,0,0,.35), 테두리는 금빛 흐린 선.
## animate 를 켜면 대기 동작을 움직이며, 도트가 뭉개지지 않게 정수 배율로 또렷하게 그린다 (새 용 만들기의 큰 그림).

var sheet = null   # SpriteSheet
@export var frame := true   # 바탕과 흐린 금테를 깐다 (외형 고르기 칸은 칸 스스로 테를 두른다)
@export var animate := false

var _t := 0.0


func _process(dt: float) -> void:
	if not animate or not is_visible_in_tree(): return
	_t += dt
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if frame:
		draw_rect(r, Color(0, 0, 0, 0.35))
		draw_rect(r, Color(216 / 255.0, 178 / 255.0, 90 / 255.0, 0.38), false, 1)
	if sheet == null: return
	var idle: Dictionary = sheet.frames.idle
	var frames: Array = idle.down if idle.has("down") else idle.left
	var f: Dictionary = frames[int(_t * 6) % frames.size()] if animate else frames[0]
	var k := minf(size.x / f.sw, size.y / f.sh) * (1.0 if animate else 1.15)
	if animate:
		k = maxf(1, floorf(k))
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # 2D판 초상화는 image-rendering: auto (보간)
	var w: float = f.sw * k
	var h: float = f.sh * k
	var xf := Transform2D(0, Vector2(roundf((size.x - w) / 2) + (w if f.flip else 0.0), roundf((size.y - h) / 2)))
	if f.flip: xf = xf.scaled_local(Vector2(-1, 1))
	draw_set_transform_matrix(xf)
	draw_texture_rect_region(f.tex, Rect2(0, 0, w, h), Rect2(f.sx, f.sy, f.sw, f.sh))
	draw_set_transform_matrix(Transform2D.IDENTITY)
