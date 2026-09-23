class_name Marks
extends Node2D
## 월드 좌표 층의 표시들: 굴에 놓을 살림살이의 반투명 그림자, 퀘스트 목표 위의 금빛 화살표.
## 2D판 render() 에서 개체들 다음, 파티클 앞에 그리던 것 (drawDenGhost · drawGuideMarker).

var camera: GameCamera


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not GameState.player: return
	Den.draw_ghost(self)
	if camera: Guide.draw_marker(self, camera.zoom.x)
