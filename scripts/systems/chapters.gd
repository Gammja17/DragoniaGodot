class_name Chapters
## 2D판 data/chapters.js 의 함수들. 장(章) 표는 data/chapters.json.
## 세상은 이야기만큼만 열린다. 장마다 갈 수 있는 지도가 늘어나고, 아직 안 열린 길 앞에서는 발이 멈춘다.


static func _list() -> Array:
	return Data.get_module("chapters").CHAPTERS


## 지금 장 (다 끝났으면 마지막 장)
static func current(s) -> Dictionary:
	for c in _list():
		if not c.done.call(s): return c
	return _list()[-1]


## 막힌 길 앞에서 띄울 말
static func blocked_text(s, id: String) -> String:
	for c in _list():
		if not c.maps.has(id): continue
		if _held(s, c, id): return c.hold[id].text
		if c.get("locked"): return c.locked
		break
	return current(s).blocked


## 이 지도에 지금 갈 수 있나. 굴과, 이미 가 본 곳(옛 세이브)은 늘 열려 있다
static func map_open(s, id: String) -> bool:
	if s.visited.has(id): return true
	var list := _list()
	var at := list.find(current(s))
	var owner := -1
	for i in list.size():
		if list[i].maps.has(id):
			owner = i
			break
	if owner >= 0 and _held(s, list[owner], id): return false
	return owner < 0 or owner <= at


## 장이 열렸어도 이야기가 아직 그리로 부르지 않은 곳은 붙들어 둔다 (hold: { 지도: { when, text } }).
## 3장의 무덤은 누리가 사라진 날에야 열린다 — 그 전에 지나다 수호룡과 덜컥 싸우지 않게
static func _held(s, c: Dictionary, id: String) -> bool:
	var h = c.get("hold", {}).get(id)
	return h != null and not h.when.call(s)
