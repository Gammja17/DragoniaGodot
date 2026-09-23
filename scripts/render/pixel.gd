class_name Pixel
## 2D판 render/pixel.js. 빛 번짐 스프라이트와 코드로 찍은 작은 아이콘(data/icons.json).

static var _glow: Texture2D
static var _icons := {}


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


## 팔레트 한 글자 + 한 줄씩의 문자열로 적어 둔 아이콘을 그림으로
static func get_icon(name: String) -> Texture2D:
	if _icons.has(name): return _icons[name]
	var def: Dictionary = Data.get_module("icons").ICONS[name]
	var rows: Array = def.rows
	var img := Image.create_empty(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == ".": continue
			img.set_pixel(x, y, Color(def.palette[ch]))
	var tex := ImageTexture.create_from_image(img)
	_icons[name] = tex
	return tex


## 시트 일부를 (x,y) 기준점(ax, ay: 0~1)에 맞춰 그린다. 기준점은 월드의 정수 좌표로 떨어뜨린다
## (x,y 는 ci 기준이다. 개체 노드는 원점이 소수 좌표라 월드로 옮겨 반올림한 뒤 되돌린다)
static func draw_pixel_sprite(ci: CanvasItem, tex: Texture2D, src: Rect2, x: float, y: float, scale := 3.0, flip := false, ax := 0.5, ay := 1.0, modulate := Color.WHITE) -> void:
	var w := src.size.x * scale
	var h := src.size.y * scale
	var o: Vector2 = ci.position if ci is Node2D else Vector2.ZERO
	var xf := Transform2D(0, Vector2(roundf(x + o.x) - o.x, roundf(y + o.y) - o.y))
	if flip: xf = xf.scaled_local(Vector2(-1, 1))
	ci.draw_set_transform_matrix(xf)
	ci.draw_texture_rect_region(tex, Rect2(-w * ax, -h * ay, w, h), src, modulate)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func draw_icon(ci: CanvasItem, name: String, x: float, y: float, scale := 3.0, modulate := Color.WHITE) -> void:
	var t := get_icon(name)
	draw_pixel_sprite(ci, t, Rect2(Vector2.ZERO, t.get_size()), x, y, scale, false, 0.5, 0.5, modulate)
