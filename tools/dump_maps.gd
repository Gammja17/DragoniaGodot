extends Node
## 지도 생성이 2D판과 같은지 대조하려고 구운 바닥의 행별 해시를 뽑는다.
##   godot --headless --path . tools/dump_maps.tscn -- VILLAGE LAKE ...
## 2D판 쪽은 브라우저에서 같은 식(h = h*31 + 바이트)으로 뽑아 비교한다.


func _ready() -> void:
	var maps: Dictionary = Data.get_module("maps").MAPS
	var out := {}
	for id in OS.get_cmdline_user_args():
		var spec: Dictionary = maps[id].duplicate()
		spec.id = id
		var m := GameMap.build(spec)
		var img := m.texture.get_image()
		var data := img.get_data()
		var rows := []
		var stride := img.get_width() * 4
		for y in img.get_height():
			var h := 0
			for i in stride:
				h = (h * 31 + data[y * stride + i]) & 0xFFFFFFFF
			rows.append(h)
		out[id] = { w = img.get_width(), h = img.get_height(), sparkles = m.sparkles.size(), sp0 = m.sparkles.slice(0, 3), rows = rows }
	print("JSON:" + JSON.stringify(out))
	get_tree().quit()
