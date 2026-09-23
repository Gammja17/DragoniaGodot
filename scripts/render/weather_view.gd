class_name WeatherView
extends Node2D
## 2D판 systems/weather.js 의 drawWeather. 조명 위에 비·눈·불티·재·번갯불을 그린다 (화면 좌표 층).
## 설원엔 늘 눈, 화산엔 불티(더하기 합성, Embers), 어둠의 결말 뒤의 웨스턴 마을엔 재. 굴 속엔 아무것도 오지 않는다.

var camera: GameCamera

@onready var _embers: Node2D = $Embers


func _ready() -> void:
	_embers.draw.connect(_draw_embers)


func _process(_dt: float) -> void:
	queue_redraw()
	_embers.queue_redraw()


func _falling_kind() -> String:
	var biome := Terrain.active_biome()
	if GameState.map_id == "VILLAGE" and GameState.story.get("route") == "dark" and GameState.quests.get("done", []).has("m7d"): return "ash"
	if biome == "SNOW": return "snow"
	if biome == "VOLCANO": return "ember"
	return ""


func _hidden() -> bool:
	return camera == null or GameState.dungeon != null or GameState.indoors or not ScreenFx.value("weather")


func _draw() -> void:
	if _hidden(): return
	var z := camera.zoom.x
	var view := get_viewport_rect().size
	var t := GameState.game_time
	var kind := _falling_kind()
	if kind == "ash" or kind == "snow":
		if kind == "ash": draw_rect(Rect2(Vector2.ZERO, view), Color8(70, 62, 66, 51))   # 하늘이 재에 가려 마을 빛깔이 죽는다
		_draw_flakes(self, kind, view / z, z, t)
		return
	if kind == "ember": return   # 불티는 Embers 가 더하기 합성으로
	var w: Dictionary = GameState.weather
	if w.intensity > 0.02:
		# 빗줄기마다 고정된 난수로 위치를 정하고, 시간에 따라 아래로 흐르게 한다 (카메라가 움직이면 같이 밀린다)
		var n := floori(160 * w.intensity)
		var pts := PackedVector2Array()
		for i in n:
			var sd := i * 9973
			var speed := 900 + (sd % 400)
			var x := fposmod((sd * 7 % 2000) - camera.position.x - t * 160, view.x / z)
			var y := fposmod((sd * 13 % 2000) - camera.position.y + t * speed, view.y / z)
			pts.append(Vector2(x, y) * z)
			pts.append(Vector2(x - 5, y + 26) * z)
		if pts.size() > 0: draw_multiline(pts, Color8(190, 215, 255, 128), 1.5 * z)
	if w.flash > 0:
		draw_rect(Rect2(Vector2.ZERO, view), Color(235 / 255.0, 240 / 255.0, 1, minf(1, w.flash * 0.45)))


func _draw_embers() -> void:
	if _hidden() or _falling_kind() != "ember": return
	var z := camera.zoom.x
	_draw_flakes(_embers, "ember", get_viewport_rect().size / z, z, GameState.game_time)


## 눈 · 재 · 불티. 눈과 재는 내려오고, 불티는 올라간다
func _draw_flakes(ci: CanvasItem, kind: String, view_world: Vector2, z: float, t: float) -> void:
	var snow := kind != "ember"
	var col := Color8(205, 200, 196, 204) if kind == "ash" else Color8(255, 255, 255, 217) if snow else Color8(255, 140, 60, 204)
	var dir := 1 if snow else -1
	for i in (170 if kind == "ash" else 110):
		var sd := i * 7919
		var speed := 50 + (sd % 70)
		var x := fposmod((sd * 3 % 2400) + sin(t * 0.8 + i) * 40 - camera.position.x, view_world.x)
		var y := fposmod((sd * 11 % 2400) + dir * t * speed - camera.position.y, view_world.y)
		var r := 3.0 + (sd % 3) if kind == "ash" else 2.0 + (sd % 3) if snow else 1.5 + (sd % 2)
		ci.draw_rect(Rect2(x * z, y * z, r * z, r * z), col)
