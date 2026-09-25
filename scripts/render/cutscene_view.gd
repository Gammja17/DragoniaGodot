class_name CutsceneView
extends Node2D
## 2D판 systems/cutscene.js 의 drawCutscene. 화면 좌표로 그린다 (CanvasLayer 안):
## 어둠과 빛 구멍 · 말하는 쪽 머리 위 삼각 표시 · 가리키는 것의 금빛 테와 이름표 · 위아래 띠

const DIM_SHADER := preload("res://shaders/cutscene_dim.gdshader")
const MAX_LIGHTS := 6   # shaders/cutscene_dim.gdshader 의 배열 크기와 같아야 한다

var camera: GameCamera
var _dim: ColorRect


func _ready() -> void:
	_dim = ColorRect.new()
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = DIM_SHADER
	_dim.material = mat
	add_child(_dim)
	_dim.show_behind_parent = true


func _to_screen(x: float, y: float) -> Vector2:
	return (Vector2(x, y) - camera.position) * camera.zoom.x


func _process(_dt: float) -> void:
	var size := get_viewport_rect().size
	_dim.size = size
	_dim.visible = Cutscene.bars > 0.004 and Cutscene.DIM * Cutscene.dim > 0.01
	if _dim.visible:
		# 1) 어둡게 깔고, 무대 위의 이들에게만 구멍을 뚫는다. 말하는 쪽과 나는 넓게, 곁에 선 이들은 조금 좁게
		var centers := PackedVector2Array()
		var radii := PackedFloat32Array()
		for pair in Cutscene.lit():
			var e = pair[0]
			var sp := _to_screen(e.x, e.y - 22)
			# FRAGCOORD 는 화면 위가 0 인 좌표 (canvas_item 은 위에서 아래로)
			centers.append(sp)
			radii.append(210 * camera.zoom.x * Cutscene.dim * pair[1])
			if centers.size() >= MAX_LIGHTS: break
		var n := centers.size()
		while centers.size() < MAX_LIGHTS:
			centers.append(Vector2.ZERO); radii.append(0.0)
		var m: ShaderMaterial = _dim.material
		m.set_shader_parameter("dim", Cutscene.DIM * Cutscene.dim)
		m.set_shader_parameter("centers", centers)
		m.set_shader_parameter("radii", radii)
		m.set_shader_parameter("count", n)
	queue_redraw()


func _draw() -> void:
	if Cutscene.bars <= 0.004 or camera == null: return
	var size := get_viewport_rect().size
	var z := camera.zoom.x
	var t := Time.get_ticks_msec()
	# 2) 말하는 쪽 머리 위에 작은 표시 (이름표를 감췄으니 대신). 그 용의 그림 높이를 따라 머리 위에 띄운다
	#    (늘 104px 위에 그려서 큰 용은 몸통에 박혔다). 머리 위 표시(!·? …)가 떠 있는 동안은 비켜 준다
	var f = Cutscene.focus
	if f and is_instance_valid(f) and Cutscene.dim > 0.4 and f is Dragon and f._emote == "":
		var sp := _to_screen(f.x, f.y - Dragon.head_top(f.sheet) + f.hover_y)
		var ty := sp.y - 14 + sin(t / 260.0) * 2
		var a := minf(1, (Cutscene.dim - 0.4) / 0.4)
		var tri := PackedVector2Array([Vector2(sp.x - 6, ty - 7), Vector2(sp.x + 6, ty - 7), Vector2(sp.x, ty)])
		var rim := tri.duplicate()
		rim.append(tri[0])
		draw_polyline(rim, Color(20 / 255.0, 14 / 255.0, 0, 0.85 * a), 3, true)
		draw_colored_polygon(tri, Color(1, 216 / 255.0, 74 / 255.0, a))
	# 2-1) 가리키는 것: 천천히 뛰는 금빛 테와 이름표
	if Cutscene.poi and is_instance_valid(Cutscene.poi.target) and Cutscene.dim > 0.4:
		var tg = Cutscene.poi.target
		var sp := _to_screen(tg.x, tg.y - 30)
		var beat := (sin(t / 320.0) + 1) / 2
		var a := minf(1, (Cutscene.dim - 0.4) / 0.4)
		var rx := (74 + beat * 10) * z
		var ry := (30 + beat * 4) * z
		var pts := PackedVector2Array()
		for i in 49: pts.append(Vector2(sp.x + cos(TAU * i / 48.0) * rx, sp.y + 34 * z + sin(TAU * i / 48.0) * ry))
		draw_polyline(pts, Color(1, 216 / 255.0, 74 / 255.0, (0.55 + beat * 0.4) * a), 3, true)
		var label: String = Cutscene.poi.label
		if label != "":
			# 이름표 · 길잡이 표시와 같은 12px. 36 · 24 로 키우면 글자가 판을 뚫고 나가 깨져 보였다. 판은 글자 크기에 맞춘다
			var fs := 12
			var font := Fonts.bold()
			var asc := font.get_ascent(fs)
			var bh := asc + font.get_descent(fs) + 10
			var tw := Fonts.text_width(font, label, fs) + 20
			var top := sp.y - 78 * z - bh / 2
			draw_rect(Rect2(sp.x - tw / 2, top, tw, bh), Color(14 / 255.0, 13 / 255.0, 22 / 255.0, 0.9 * a))
			draw_rect(Rect2(sp.x - tw / 2 + 0.5, top + 0.5, tw - 1, bh - 1), Color(216 / 255.0, 178 / 255.0, 90 / 255.0, 0.9 * a), false, 1)
			Fonts.draw_centered(self, font, label, sp.x, top + 5 + asc, fs, Color(1, 216 / 255.0, 74 / 255.0, a))
	# 3) 위아래 띠
	var bar := roundf(size.y * Cutscene.BAR * Cutscene.bars)
	if bar > 0:
		draw_rect(Rect2(0, 0, size.x, bar), Color("#06050c"))
		draw_rect(Rect2(0, size.y - bar, size.x, bar), Color("#06050c"))
		draw_rect(Rect2(0, bar - 1, size.x, 1), Color(216 / 255.0, 178 / 255.0, 90 / 255.0, 0.28))
		draw_rect(Rect2(0, size.y - bar, size.x, 1), Color(216 / 255.0, 178 / 255.0, 90 / 255.0, 0.28))
