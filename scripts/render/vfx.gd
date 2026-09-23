class_name Vfx
## 2D판 render/vfx.js 의 효과 시트. 시트 이름이 곧 assets/vfx/ 의 파일 이름이다.
## (효과 재생 자체는 전투를 옮길 때 붙인다)

static var _textures := {}


static func texture(key: String) -> Texture2D:
	if not _textures.has(key):
		_textures[key] = load("res://assets/vfx/%s.png" % key)
	return _textures[key]
