class_name Overlay
extends Node2D
## 2D판 render/overlay.js 의 '또렷한 층'. 이름표·말풍선·포탈 이름처럼 흰 글씨가 번지면 안 되는 것은
## 세상과 같은 배율로 그리지 않고, 화면 픽셀 단위로 이 층에 따로 그린다 (CanvasLayer 안에 둔다).
##
## 개체는 crisp_anchor()(월드 좌표, 없으면 발 위치)와 draw_crisp(ci, zoom) 를 가지면 여기 그려진다.

var camera: GameCamera
var world: Node2D


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	if camera == null or world == null: return
	var z := camera.zoom.x
	var view := get_viewport_rect().size
	for e in world.get_children():
		if not e.has_method("draw_crisp"): continue
		var a: Vector2 = e.crisp_anchor() if e.has_method("crisp_anchor") else Vector2(roundf(e.x), roundf(e.y))
		var s := (a - camera.position) * z
		if s.x < -300 or s.y < -300 or s.x > view.x + 300 or s.y > view.y + 300: continue
		draw_set_transform(s.round())
		e.draw_crisp(self, z)
	draw_set_transform(Vector2.ZERO)
