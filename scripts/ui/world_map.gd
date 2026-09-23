class_name WorldMap
extends Control
## 일지 [지도] 탭 (2D판 renderMap). 지도 19장을 이어진 대로 그린다 —
## 가 본 곳은 밝게, 석비를 깨운 곳은 표시, 지금 있는 곳은 금테. 자리는 maps 의 MAP_POS.

const W := 900.0
const H := 470.0


func _draw() -> void:
	var maps: Dictionary = Data.get_module("maps").MAPS
	var map_pos: Dictionary = Data.get_module("maps").MAP_POS
	# 판 폭에 맞춰 가운데에 둔다 (2D판은 900×470 캔버스)
	var k := minf(size.x / W, size.y / H)
	var o := (size - Vector2(W, H) * k) / 2
	draw_rect(Rect2(o, Vector2(W, H) * k), Color("#100f18"))
	var pos := func(id: String) -> Vector2:
		var p: Array = map_pos.get(id, [0.5, 0.5])
		return o + Vector2(60 + p[0] * (W - 120), 40 + p[1] * (H - 80)) * k
	# 길
	for id in maps:
		for pt in maps[id].get("portals", []):
			if not maps.has(pt.to) or id > pt.to: continue
			draw_line(pos.call(id), pos.call(pt.to), Color(216 / 255.0, 178 / 255.0, 90 / 255.0, 0.35), 3)
	# 마디
	var font := Fonts.bold()
	for id in maps:
		var spec: Dictionary = maps[id]
		var p: Vector2 = pos.call(id)
		var seen: bool = GameState.visited.has(id)
		var here: bool = GameState.map_id == id
		var boss: bool = spec.get("fixtures", []).any(func(f): return f.t == "BOSS")
		var r := 13.0 if here else 10.0
		var fill := Color("#2a2836") if not seen else Color("#7a2f2f") if boss else Color("#d8b25a") if spec.get("biome") in ["VILLAGE", "CLOUDTOP"] else Color("#4f6b45")
		draw_circle(p, r, fill)
		if here: draw_arc(p, r, 0, TAU, 32, Color("#ffd84a"), 3)
		if GameState.waystones.has(id): draw_circle(p + Vector2(9, -9), 4, Color("#7fd4ff"))
		var label: String = spec.name if seen else "???"
		var w := Fonts.text_width(font, label, 12)
		draw_string(font, p + Vector2(-w / 2, 30), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#ece3cf") if seen else Color("#6a6478"))
