extends Control
## 2D판 render/spritesheet.js 의 drawPortrait. 정면 대기 프레임을 칸에 꽉 차게 그린다 (대화창·HUD 초상화).
## 칸 바탕은 rgba(0,0,0,.35), 테두리는 금빛 흐린 선.

var sheet = null   # SpriteSheet


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0, 0, 0, 0.35))
	draw_rect(r, Color(216 / 255.0, 178 / 255.0, 90 / 255.0, 0.38), false, 1)
	if sheet == null: return
	var idle: Dictionary = sheet.frames.idle
	var f: Dictionary = (idle.down if idle.has("down") else idle.left)[0]
	var k := minf(size.x / f.sw, size.y / f.sh) * 1.15
	var w: float = f.sw * k
	var h: float = f.sh * k
	# 2D판 초상화는 image-rendering: auto (보간)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var xf := Transform2D(0, Vector2((size.x - w) / 2 + (w if f.flip else 0.0), (size.y - h) / 2))
	if f.flip: xf = xf.scaled_local(Vector2(-1, 1))
	draw_set_transform_matrix(xf)
	draw_texture_rect_region(f.tex, Rect2(0, 0, w, h), Rect2(f.sx, f.sy, f.sw, f.sh))
	draw_set_transform_matrix(Transform2D.IDENTITY)
