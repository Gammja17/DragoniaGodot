class_name Pixel
## 2D판 render/pixel.js. 1단계에서는 빛 번짐만 옮겼다 (아이콘·실루엣은 필요해질 때).

static var _glow: Texture2D


## 가운데가 밝고 가장자리로 사라지는 원형 빛. 흰 빛 한 장을 색으로 물들여 쓴다
static func glow_texture() -> Texture2D:
	if _glow == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 64; t.height = 64
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_glow = t
	return _glow


static func draw_glow(ci: CanvasItem, x: float, y: float, radius: float, color: Color, alpha := 1.0) -> void:
	ci.draw_texture_rect(glow_texture(), Rect2(x - radius, y - radius, radius * 2, radius * 2), false, Color(color, alpha))
