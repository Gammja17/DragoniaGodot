class_name Prefs
## 판과 상관없이 이 기기에 남는 설정 (user://settings.cfg). 2D판 localStorage 의 설정 키들.
##   view/zoom · guide/level · dialogue/step · sound/music · sound/sfx · sound/muted · fx/* (화면 효과)
## 소리처럼 자주 읽는 곳이 있어서, 파일은 처음 한 번만 읽어 두고 쓸 때만 파일에 남긴다.

const PATH := "user://settings.cfg"

static var _cfg: ConfigFile


static func _file() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(PATH)
	return _cfg


static func get_value(section: String, key: String, default = null):
	return _file().get_value(section, key, default)


static func set_value(section: String, key: String, v) -> void:
	_file().set_value(section, key, v)
	_cfg.save(PATH)
