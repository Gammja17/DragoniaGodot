class_name Util
## 2D판 core/utils.js 와 render/tint.js 의 색 변환. 결과가 2D판과 똑같아야 하는 것들이다
## (지도는 시드 난수로 만들어서, 난수가 한 자리만 달라도 다른 지도가 된다).

const U32 := 0xFFFFFFFF


static func rand_range(lo: float, hi: float) -> float:
	return randf() * (hi - lo) + lo


static func dist(a, b) -> float:
	return Vector2(a.x - b.x, a.y - b.y).length()


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
