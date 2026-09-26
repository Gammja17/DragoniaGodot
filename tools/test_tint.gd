extends Node
## 주인공 그림 칠하기 (DragonSprites.tint_image): 기본 색이면 원본 그대로 · 눈 · 문양 색이 모든 모습에서 먹는다 ·
## 흰색 · 검은색이 분홍 · 남색으로 새지 않는다 · 문양 색만 바꿔도 새 그림이 나온다 · 옛 기록(문양 색 없음)은 눈이 그대로.
## 줄마다 [칠하기] OK/FAIL 을 찍고, 끝에 실패 수를 센다. 칠한 모습 한 장을 user://tint_test.png 로 남긴다.
##   godot --headless --path . res://tools/test_tint.tscn

const DEFAULT := { body = "#e03030", wing = "#f2c230", mark = "#3fa0ff" }
const SETS := [
	{ body = "#3060e0", wing = "#e8e8f0", mark = "#ffc020" },
	{ body = "#30a050", wing = "#f08030", mark = "#e03030" },
	{ body = "#282830", wing = "#8040c0", mark = "#40e060" },
	{ body = "#f0f0f0", wing = "#f070a0", mark = "#8050e0" },
]

var _fails := 0


func _ready() -> void:
	var desc: Dictionary = Data.get_module("sprites").DRAGON_SHEETS.HERO
	var raw: Image = DragonSprites._raw_images("HERO").sheet
	var fw := int(desc.fw)
	var fh := int(desc.fh)
	var cells := []
	for look in 15: cells.append(raw.get_region(Rect2i((look % 3) * fw, floori(look / 3.0) * fh, fw, fh)))

	# 기본 색 = 원본 (눈 · 문양만 기본 파랑으로)
	var diff := 0.0
	var n := 0
	var marks_per := []
	for c: Image in cells:
		var out := DragonSprites.tint_image(c, desc.zones, DEFAULT)
		var marks := DragonSprites._find_marks(c.get_data(), fw, fh)
		marks_per.append(marks.size())
		var a := c.get_data()
		var b := out.get_data()
		for i in range(0, a.size(), 4):
			if a[i + 3] < 8 or marks.has(i): continue
			diff += absi(a[i] - b[i]) + absi(a[i + 1] - b[i + 1]) + absi(a[i + 2] - b[i + 2])
			n += 1
	_check("기본 색이면 원본 그대로 (픽셀 평균 차 %.2f)" % (diff / n), diff / n < 6.0)
	print("[칠하기] 칸마다 눈 · 문양 픽셀: %s" % str(marks_per))
	_check("아기 다섯은 모두 눈 · 문양을 찾는다", [0, 3, 6, 9, 12].all(func(k): return marks_per[k] >= 40))
	_check("청소년 · 어른도 대부분 찾는다 (10칸 가운데 %d칸)" % [1, 2, 4, 5, 7, 8, 10, 11, 13, 14].filter(func(k): return marks_per[k] > 0).size(),
		[1, 2, 4, 5, 7, 8, 10, 11, 13, 14].filter(func(k): return marks_per[k] > 0).size() >= 7)

	# 문양 색을 바꾸면 눈이 바뀐다
	var baby: Image = cells[0]
	var blue := DragonSprites.tint_image(baby, desc.zones, DEFAULT).get_data()
	var green := DragonSprites.tint_image(baby, desc.zones, { body = DEFAULT.body, wing = DEFAULT.wing, mark = "#40e060" }).get_data()
	var changed := 0
	for i in range(0, blue.size(), 4):
		if blue[i] != green[i] or blue[i + 1] != green[i + 1] or blue[i + 2] != green[i + 2]: changed += 1
	_check("문양 색만 바꿔도 눈 · 문양 픽셀이 바뀐다 (%d픽셀)" % changed, changed >= 40)

	# 옛 기록: 문양 색이 없으면 눈은 원본 그대로
	var old := DragonSprites.tint_image(baby, desc.zones, { body = "#3060e0", wing = "#f2c230" }).get_data()
	var orig := baby.get_data()
	var baby_marks := DragonSprites._find_marks(orig, fw, fh)
	var kept := baby_marks.keys().all(func(i): return old[i] == orig[i] and old[i + 1] == orig[i + 1] and old[i + 2] == orig[i + 2])
	_check("문양 색이 없는 옛 기록은 눈이 원본 그대로", kept)

	# 흰색 · 검은색: 몸(원본의 진한 빨강)이 정말 희고 검다
	var white := DragonSprites.tint_image(baby, desc.zones, { body = "#f0f0f0", wing = DEFAULT.wing, mark = DEFAULT.mark }).get_data()
	var black := DragonSprites.tint_image(baby, desc.zones, { body = "#282830", wing = DEFAULT.wing, mark = DEFAULT.mark }).get_data()
	var ws := 0.0
	var wl := 0.0
	var bs := 0.0
	var bl := 0.0
	var m := 0
	for i in range(0, orig.size(), 4):
		if orig[i + 3] < 8: continue
		var hsl := Util.rgb_to_hsl(orig[i], orig[i + 1], orig[i + 2])
		if not (hsl[1] > 0.5 and hsl[2] > 0.3 and hsl[2] < 0.65 and (hsl[0] < 8 or hsl[0] > 352)): continue
		var w := Util.rgb_to_hsl(white[i], white[i + 1], white[i + 2])
		var k := Util.rgb_to_hsl(black[i], black[i + 1], black[i + 2])
		ws += w[1] * (1.0 - absf(2.0 * w[2] - 1.0)); wl += w[2]
		bs += k[1] * (1.0 - absf(2.0 * k[2] - 1.0)); bl += k[2]
		m += 1
	_check("흰 몸은 희다 (밝기 %.2f · 색기 %.3f)" % [wl / m, ws / m], wl / m > 0.75 and ws / m < 0.05)
	_check("검은 몸은 검다 (밝기 %.2f · 색기 %.3f)" % [bl / m, bs / m], bl / m < 0.25 and bs / m < 0.05)

	# 캐시: 문양 색이 다르면 다른 그림
	var s1 := DragonSprites.get_sheet("HERO", DEFAULT, 0)
	var s2 := DragonSprites.get_sheet("HERO", { body = DEFAULT.body, wing = DEFAULT.wing, mark = "#40e060" }, 0)
	_check("문양 색이 다르면 캐시에서 옛 그림을 꺼내지 않는다", s1 != s2)

	# 빠르기: 새 용 만들기에서 색을 바꿀 때마다 여섯 칸을 칠한다
	var t0 := Time.get_ticks_usec()
	for k in 5: DragonSprites.tint_image(cells[k * 3], desc.zones, SETS[k % SETS.size()])
	var ms := (Time.get_ticks_usec() - t0) / 5000.0
	_check("한 칸 칠하기 %.1fms" % ms, ms < 400.0)

	# 새 용 만들기: 색을 끄는 동안에도 큰 미리보기가 따라오고(담아 두지는 않고), 손을 멈추면 생김새 칸까지 칠한다
	var title: Control = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame
	title._slot = 2
	title._show(title._create)
	await get_tree().process_frame
	var before = title._preview.sheet
	var kept_n := DragonSprites._cache.size()
	title._body.color = Color("#3060e0")
	title._body.color_changed.emit(title._body.color)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("색을 끄는 동안에도 큰 미리보기가 바로 바뀐다", title._preview.sheet != before)
	_check("스치는 색은 담아 두지 않는다", DragonSprites._cache.size(), kept_n)
	await get_tree().create_timer(0.4).timeout
	for k in 8: await get_tree().process_frame
	_check("손을 멈추면 생김새 칸까지 새 색으로 칠한다", title._repaint.is_empty() and DragonSprites._cache.size() > kept_n)
	title.queue_free()

	# 눈으로 볼 한 장: 줄 = 모습 15칸, 칸 = 기본 + 색 넷
	var sheet := Image.create(fw * 5, fh * 15, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#28283a"))
	for look in 15:
		for j in 5:
			var img := DragonSprites.tint_image(cells[look], desc.zones, DEFAULT if j == 0 else SETS[j - 1])
			sheet.blend_rect(img, Rect2i(0, 0, fw, fh), Vector2i(j * fw, look * fh))
	sheet.save_png("user://tint_test.png")
	print("[끝] 실패 %d" % _fails)
	get_tree().quit(1 if _fails else 0)


func _check(what: String, got, want = true) -> void:
	var ok: bool = got == want
	if not ok: _fails += 1
	print("[칠하기] %s %s%s" % ["OK  " if ok else "FAIL", what, "" if ok else "  (%s · 기대 %s)" % [str(got), str(want)]])
