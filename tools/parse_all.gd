extends Node
## 모든 스크립트를 한 번씩 불러 문법·형 오류를 드러낸다 (Godot 는 쓰는 스크립트만 컴파일한다).
## godot --headless --path . res://tools/parse_all.tscn

func _ready() -> void:
	var bad := 0
	var n := 0
	for path in _scripts("res://scripts"):
		n += 1
		var s = load(path)   # 문법·형 오류는 여기서 찍힌다
		if s == null:
			bad += 1
			print("FAIL ", path)
	print("parsed %d scripts, %d failed" % [n, bad])
	get_tree().quit()


func _scripts(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"): out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir): out.append_array(_scripts(dir.path_join(d)))
	return out
