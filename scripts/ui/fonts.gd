class_name Fonts
## 물마루(Mulmaru) 한 벌만 쓴다. 12px 로 그려진 픽셀 글꼴이라 12·24·36px 로만 쓰고,
## 번지지 않게 안티에일리어싱을 끈다 (assets/fonts/Mulmaru.woff2.import).
## 굵게는 글꼴에 없어서 브라우저처럼 덧칠해 만든다.

static var _regular: Font
static var _bold: Font


static func regular() -> Font:
	if _regular == null: _regular = load("res://assets/fonts/Mulmaru.woff2")
	return _regular


static func bold() -> Font:
	if _bold == null: _bold = load("res://assets/fonts/mulmaru_bold.tres")
	return _bold


## 가운데 맞춤 한 줄. (x, y) 는 글자 바탕선의 가운데
static func draw_centered(ci: CanvasItem, font: Font, text: String, x: float, y: float, size: int, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font, Vector2(roundf(x - w / 2), roundf(y)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func text_width(font: Font, text: String, size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
