class_name Tutorial
## 2D판 systems/tutorial.js. 처음 며칠의 조작 안내.
## 지금 뭘 해야 하는지는 1장의 퀘스트(m0 → m1 → 오늘의 수련)가 추적창에서 알려 주고,
## 키는 그 일이 닥친 순간에 한 번씩만 알려 준다.
##
## GameState.tutorial = { moved, ate, journal, toured, finished, hints: { id: true } }

static func _hints() -> Array:
	return [
		{ id = "fight", icon = "🔥",
		  when = func(s): return s.map_id != "VILLAGE" and s.entities.enemies.any(func(e): return e.type != "PREY" and Util.dist(e, s.player) < 420),
		  text = "마우스로 겨누고 클릭하면 숨결이 나간다. 꾹 누르면 계속 나가고, [Shift]로 피한다." },
		{ id = "dummy", icon = "🎯",
		  when = func(s): return s.map_id == "VILLAGE" and s.entities.enemies.any(func(e): return e.type == "DUMMY"),
		  text = "허수아비를 마우스로 겨누고 클릭. 꾹 누르면 계속 나간다. [Shift]를 탁 누르면 대시로 피한다." },
		{ id = "eat", icon = "🍖",
		  when = func(s): return not s.tutorial.get("ate") and s.player.hunger < 60 and s.player.inventory.meat > 0,
		  text = "배가 고프다. [C]로 고기를 먹는다." },
		{ id = "dusk", icon = "🌙",
		  when = func(s): return s.day == 1 and s.dayTime > 0.78 and s.dayTime < 0.9,
		  text = "해가 진다. 마을 서쪽 내 굴에 들어가, 둥지에서 [Space]로 잔다." },
	]


## 매 프레임. 첫 일거리를 끝내면 안내는 끝난다
static func update() -> void:
	var t = GameState.tutorial
	if not t or t.get("finished") or GameState.isDialogueOpen or GameState.prologue: return
	if GameState.quests.done.has("m1"):
		t.finished = true
		return
	# 첫 퀘스트의 허수아비 대목: 광장에 허수아비 둘이 서 있어야 한다 (지도를 오가도 다시 선다)
	var m0 = GameState.quests.active.get("m0")
	if m0 and m0.step == 2 and GameState.map_id == "VILLAGE" and not GameState.entities.enemies.any(func(e): return e.type == "DUMMY"):
		for c in [[10, 9], [13, 9]]:
			var d := Enemy.make(c[0] * 96 + 48, c[1] * 96 + 48, "DUMMY")
			d.max_hp = 30; d.hp = 30
			World.add_entity("enemies", d)
	if not t.has("hints"): t.hints = {}
	for h in _hints():
		if t.hints.get(h.id) or not h.when.call(GameState): continue
		t.hints[h.id] = true
		Hud.pop(h.text, h.icon)
		return


## 상태값만으로는 알 수 없는 것들 (게임 곳곳에서 한 줄로 부른다)
static func mark(flag: String) -> void:
	if GameState.tutorial and not GameState.tutorial.get(flag): GameState.tutorial[flag] = true
