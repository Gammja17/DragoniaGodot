class_name Prefs
## 판과 상관없이 이 기기에 남는 설정 (user://settings.cfg). 2D판 localStorage 의 설정 키들.
##   view/zoom · guide/level · dialogue/step · sound/music · sound/sfx · sound/muted

const PATH := "user://settings.cfg"


static func get_value(section: String, key: String, default = null):
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	return cfg.get_value(section, key, default)


static func set_value(section: String, key: String, v) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value(section, key, v)
	cfg.save(PATH)
