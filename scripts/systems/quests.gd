class_name Quests
## 2D판 systems/quests.js. 퀘스트는 4단계(시스템)에서 옮긴다.
## 지금은 전투가 알려 주는 일(처치·상자·정예)을 받을 자리만 있다.


## 퀘스트 목표가 셀 일이 생겼다. kind: 'kill' | 'killAny' | 'elite' | 'chest' | 'stage' …
static func notify(_kind: String, _what = null) -> void:
	pass
