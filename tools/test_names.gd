extends Node
## 이름 색: 모든 마을 용에게 제 색이 있고 어두운 대사 창에서 읽힌다 · 대사 속 이름만 칠한다 (낱말은 두고) ·
## 내 아이는 태어난 차례대로 · 이름표도 그 색 · 대괄호 글([E])은 그대로 · 글자 찍기가 끝까지 간다.
## 줄마다 [이름 색] OK/FAIL 을 찍고, 끝에 실패 수를 센다. 저장은 9번 칸만 쓴다.
##   godot --headless --path . res://tools/test_names.tscn

var _fails := 0


func _ready() -> void:
	Save.slot = 9
	Save.delete()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.play_intro = false
	main.load_save = false
	add_child(main)
	await get_tree().process_frame
	var npcs: Dictionary = Data.get_module("npcs")

	# 색이 다 있고, 어두운 판에서 읽힌다 (밝기), 본문 글자색과 다르다 (채도)
	var missing: Array = npcs.NPC_NAMES_KO.keys().filter(func(id): return not npcs.NAME_COLORS.has(id))
	_check("마을 용 모두 제 색이 있다", missing, [])
	var dim := []
	for id in npcs.NAME_COLORS:
		var c := Color(npcs.NAME_COLORS[id])
		if c.get_luminance() < 0.45 or c.s < 0.15: dim.append(id)
	for h in npcs.KID_COLORS:
		if Color(h).get_luminance() < 0.45: dim.append(h)
	_check("모든 색이 어두운 판에서 밝고, 흰 글자와 다르다", dim, [])

	# 대사 속 이름: 칠할 것과 둘 것
	_check("여럿이 한 줄에", _names("그날 밤 포코가 미루네 집 앞에서 엠버를 불렀다."), ["포코", "미루", "엠버"])
	_check("조사가 겹쳐도 이름", _names("카이론한테는 말하지 마. 하루야, 가람아!"), ["카이론", "하루", "가람"])
	_check("부름말 앞의 맨이름", _names("나라 누나, 흑단 아저씨가 불러."), ["나라", "흑단"])
	_check("낱말은 두고 (오늘 하루, 단 한 번, 2단까지, 간단)", _names("오늘 하루 종일 단 한 번도 못 쉬었다. 2단까지 올리면 간단하다."), [])
	_check("낱말은 두고 (하루도, 하루만, 도란도란, 펀치, 이슬처럼)", _names("하루도 못 쉰다. 하루만 줘. 도란도란 펀치를 이슬처럼."), [])
	_check("돌 · 온 · 자갈은 대사 속에서 칠하지 않는다 (거의 늘 낱말)", _names("돌이 온 곳은 자갈밭이다."), [])
	_check("해설 속 이름도", _names("(단과 소이가 누리를 붙들고 서 있었다.)"), ["단", "소이", "누리"])

	# 내 아이: 태어난 차례대로 KID_COLORS
	GameState.kids = [{ id = 1, name = "레미" }, { id = 2, name = "카일" }]
	var sp := Names.spans("레미가 카일이랑 논다.")
	_check("아이 이름도 칠한다 (첫째, 둘째 색)", sp.map(func(s): return s[2]), [Color(npcs.KID_COLORS[0]), Color(npcs.KID_COLORS[1])])
	_check("아이 이름표: 덧붙임이 있어도 앞의 이름으로", Names.color_of("레미 (장난꾸러기) ♥♥"), Color(npcs.KID_COLORS[0]))
	GameState.kids = []

	# 대사 창: 이름표 색 · 대사 속 이름 색 · 대괄호 그대로 · 끝까지 찍힌다
	var box := DialogueBox.current
	box.show_dialogue({ name = "포코", text = "엠버가 [E]를 눌러 보래. 오늘 하루도 길다!" })
	_check("이름표는 말하는 용의 색", box._name.label_settings.font_color, Color(npcs.NAME_COLORS.Poco))
	_check("대사 속 엠버만 제 색 (하루도는 낱말)", [box._text.text.contains("[color=#%s]" % Color(npcs.NAME_COLORS.Ember).to_html(false)), box._text.text.count("[color=")], [true, 1])
	_check("보이는 글은 원래 글 그대로 (대괄호 포함)", box.shown_text(), "엠버가 [E]를 눌러 보래. 오늘 하루도 길다!")
	for k in 240:
		await get_tree().process_frame
		if not box.typing(): break
	_check("글자 찍기가 끝까지 간다", [box.typing(), box._text.visible_characters], [false, -1])
	_check("문단 사이 띄우기가 RichTextLabel 에서도 먹는다", ThemeDB.get_default_theme().has_constant("paragraph_separation", "RichTextLabel"))
	box.show_dialogue({ name = "마을 게시판", text = "쪽지들이다." })
	_check("모르는 이름표는 원래 금빛", box._name.label_settings.font_color, box._name_color)
	box.show_dialogue({ name = "", text = "(하루가 웃었다.)", narration = true })
	_check("해설은 바랜 금빛 바탕에 이름만 제 색", [box._text.get_theme_color("default_color"), box._text.text.contains("[color=")], [DialogueBox.NARRATION_COLOR, true])
	box.hide_dialogue()

	print("[끝] 실패 %d" % _fails)
	get_tree().quit(1 if _fails else 0)


func _names(text: String) -> Array:
	return Names.spans(text).map(func(s): return text.substr(s[0], s[1] - s[0]))


func _check(what: String, got, want = true) -> void:
	var ok: bool = got == want
	if not ok: _fails += 1
	print("[이름 색] %s %s%s" % ["OK  " if ok else "FAIL", what, "" if ok else "  (%s, 기대 %s)" % [str(got), str(want)]])
