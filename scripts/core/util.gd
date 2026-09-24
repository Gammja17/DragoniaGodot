class_name Util
## 2D판 core/utils.js 와 render/tint.js 의 색 변환. 결과가 2D판과 똑같아야 하는 것들이다
## (지도는 시드 난수로 만들어서, 난수가 한 자리만 달라도 다른 지도가 된다).

const U32 := 0xFFFFFFFF


static func rand_range(lo: float, hi: float) -> float:
	return randf() * (hi - lo) + lo


static func dist(a, b) -> float:
	return Vector2(a.x - b.x, a.y - b.y).length()


## 받침에 맞춰 조사를 붙인다: josa("바실", "을", "를") → "바실을" · josa("엘더", "이", "가") → "엘더가".
## "으로/로" 는 ㄹ 받침이면 "로" 다. 화면에 "(이)가" · "와(과)" 가 그대로 뜨지 않게
static func josa(word: String, with_final: String, without_final: String) -> String:
	if word == "": return without_final
	var c := word.unicode_at(word.length() - 1)
	if c < 0xAC00 or c > 0xD7A3: return word + without_final
	var jong := (c - 0xAC00) % 28
	if with_final == "으로" and jong == 8: return word + "로"
	return word + (with_final if jong != 0 else without_final)


## 글에서 줄을 바꿀 수 있는 곳을 띄어쓰기로만 둔다. 글자판은 한글을 글자마다 끊어서 낱말이 두 줄로 쪼개졌다 ('한|참').
## 띄어쓰기 사이의 글자들을 줄바꿈 금지 문자(WORD JOINER, 보이지 않는다)로 묶는다. 한 줄보다 긴 낱말은 글자판이 알아서 끊는다
const WJ := "\u2060"
static func keep_words(s: String) -> String:
	var out := PackedStringArray()
	for i in s.length():
		out.append(s[i])
		if i + 1 < s.length() and not (s[i] in " \n" or s[i + 1] in " \n"): out.append(WJ)
	return "".join(out)


## JS 의 Math.imul. 32비트 곱의 아래 32비트를 부호 없는 수로 돌려준다
static func imul(a: int, b: int) -> int:
	a &= U32; b &= U32
	var ah := (a >> 16) & 0xFFFF
	var al := a & 0xFFFF
	var bh := (b >> 16) & 0xFFFF
	var bl := b & 0xFFFF
	return (al * bl + (((ah * bl + al * bh) << 16) & U32)) & U32


## 시드 고정 난수 (0~1). 2D판 mulberry32 와 같은 순서로 같은 수를 낸다
class Mulberry32:
	var a: int

	func _init(seed: int) -> void:
		a = seed & U32

	func next() -> float:
		a = (a + 0x6D2B79F5) & U32
		var t := Util.imul(a ^ (a >> 15), 1 | a)
		t = ((t + Util.imul(t ^ (t >> 7), 61 | t)) & U32) ^ t
		return float((t ^ (t >> 14)) & U32) / 4294967296.0


## [h(0~360), s, l] (0~1)
static func rgb_to_hsl(r: float, g: float, b: float) -> Array:
	r /= 255.0; g /= 255.0; b /= 255.0
	var mx: float = max(r, g, b)
	var mn: float = min(r, g, b)
	var l := (mx + mn) / 2.0
	if mx == mn:
		return [0.0, 0.0, l]
	var d := mx - mn
	var s := d / (2.0 - mx - mn) if l > 0.5 else d / (mx + mn)
	var h: float
	if mx == r:
		h = (g - b) / d + (6.0 if g < b else 0.0)
	elif mx == g:
		h = (b - r) / d + 2.0
	else:
		h = (r - g) / d + 4.0
	return [h * 60.0, s, l]


## [r, g, b] (0~255, 소수)
static func hsl_to_rgb(h: float, s: float, l: float) -> Array:
	h = fposmod(h, 360.0)
	var c := (1.0 - absf(2.0 * l - 1.0)) * s
	var x := c * (1.0 - absf(fmod(h / 60.0, 2.0) - 1.0))
	var m := l - c / 2.0
	var rgb: Array
	if h < 60: rgb = [c, x, 0.0]
	elif h < 120: rgb = [x, c, 0.0]
	elif h < 180: rgb = [0.0, c, x]
	elif h < 240: rgb = [0.0, x, c]
	elif h < 300: rgb = [x, 0.0, c]
	else: rgb = [c, 0.0, x]
	return [(rgb[0] + m) * 255.0, (rgb[1] + m) * 255.0, (rgb[2] + m) * 255.0]
