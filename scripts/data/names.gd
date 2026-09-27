class_name Names
## 화면에 보여 줄 이름. 안쪽에서는 영문 키를 그대로 쓴다 (대사·퀘스트·세이브가 이 키로 묶여 있다).
## 2D판 data/npcs.js 의 npcName, data/maps.js 의 mapName.


static func npc(id: String) -> String:
	var npcs: Dictionary = Data.get_module("npcs")
	return npcs.NAME_OVERRIDES.get(id, npcs.NPC_NAMES_KO.get(id, id if id != "" else "???"))


static func map(id: String) -> String:
	var maps: Dictionary = Data.get_module("maps").MAPS
	var dens: Dictionary = Data.get_module("dens").DENS
	if maps.has(id): return maps[id].name
	if dens.has(id): return dens[id].name
	return id


# ---------- 이름 색 (대사 창의 이름표와 대사 속 이름) ----------

## 이름 뒤에 붙어도 되는 것 (조사, 부름말). 이 밖의 글자가 붙으면 이름이 아니라 낱말이다 (도란도란, 펀치)
static var _suffix := RegEx.create_from_string("^(?:이)?(?:랑|하고|한테|에게|께서|께|네|님|씨)?(?:은|는|이|가|을|를|와|과|도|만|의|야|아|처럼|보다|까지|부터|만큼|라고|라는|란|라도|나|서|요)?$")
const _TITLES := ["아저씨", "아줌마", "누나", "언니", "형", "오빠", "할아버지", "할머니", "어른", "그놈", "녀석", "님", "씨"]


## 보여 주는 이름 → 색. 마을 용은 data/npcs NAME_COLORS, 내 아이는 태어난 차례대로 KID_COLORS. 모르는 이름이면 null.
## 아이 이름표처럼 이름 뒤에 덧붙임이 있으면("레미 (장난꾸러기) ♥♥") 앞의 이름으로 본다
static func color_of(display: String):
	for e in _entries(true):
		if display == e.name or display.begins_with(e.name + " "): return e.color
	return null


## 대사 속 이름 자리 [[시작, 끝, 색], …] (앞에서부터, 겹치지 않게).
## 이름 앞은 글자가 아니어야 하고(간단, 2단까지), 뒤에는 조사만 붙어야 한다(도란도란, 펀치).
## 흔한 낱말과 겹치는 이름(NAME_WORDS: 하루, 나라 …)은 띄어 쓴 뒤에 부름말(아저씨, 누나 …)이 올 때만 맨이름으로 친다
## (오늘 하루, 단 한 번). NAME_NOT 은 조사까지 붙어도 낱말인 자리(하루를 마무리한다), 이름표에만 칠하는 이름(돌, 온)은 뺀다
static func spans(text: String) -> Array:
	var out := []
	var ents := _entries(false)
	var nots: Dictionary = Data.get_module("npcs").NAME_NOT
	var n := text.length()
	var i := 0
	while i < n:
		if not _hangul(text, i) or (i > 0 and (_hangul(text, i - 1) or _alnum(text, i - 1))):
			i += 1
			continue
		var hit := []
		for e in ents:
			var nm: String = e.name
			if text.substr(i, nm.length()) != nm: continue
			if nots.get(nm, []).any(func(p): return text.substr(i, p.length()) == p): continue
			var j := i + nm.length()
			var k := j
			while k < n and _hangul(text, k): k += 1
			if k > j:
				if not _suffix.search(text.substr(j, k - j)): continue
			elif e.word and j < n and text[j] == " ":
				var rest := text.substr(j + 1, 4)
				if not _TITLES.any(func(t): return rest.begins_with(t)): continue
			hit = [i, j, e.color]
			break
		if hit.is_empty():
			i += 1
		else:
			out.append(hit)
			i = hit[1]
	return out


## [{ name, color, word }] 긴 이름부터 (이그나르가 이그보다 먼저 걸리게). plate: 이름표에만 칠하는 이름까지
static func _entries(plate: bool) -> Array:
	var npcs: Dictionary = Data.get_module("npcs")
	var out := []
	for id in npcs.NAME_COLORS:
		if not plate and npcs.NAME_PLATE_ONLY.has(id): continue
		out.append({ name = npc(id), color = Color(npcs.NAME_COLORS[id]), word = npcs.NAME_WORDS.has(id) })
	var kc: Array = npcs.KID_COLORS
	for k in GameState.kids:
		out.append({ name = str(k.name), color = Color(kc[(int(k.get("id", 1)) - 1) % kc.size()]), word = false })
	out.sort_custom(func(a, b): return a.name.length() > b.name.length())
	return out


static func _hangul(s: String, i: int) -> bool:
	var c := s.unicode_at(i)
	return c >= 0xAC00 and c <= 0xD7A3


static func _alnum(s: String, i: int) -> bool:
	var c := s.unicode_at(i)
	return (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122)
