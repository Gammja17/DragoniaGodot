class_name Arena
## 2D판 systems/arena.js. 수련장 시험 표지. 행동별로 무리를 불러내 바로 싸워 본다.
## 수치를 만질 때, 매번 숲을 헤매며 그 적을 찾지 않아도 되게.

const MENU := [
	{ label = "덤빔: 슬라임 ×3", units = [["SLIME", 3]] },
	{ label = "돌진: 붉은 게 ×2", units = [["CRAB", 2]] },
	{ label = "포위: 고블린 ×4", units = [["GOBLIN", 4]] },
	{ label = "사수: 광신도 ×2", units = [["CULTIST", 2]] },
	{ label = "잠복: 독거미 ×2", units = [["SPIDER", 2]] },
	{ label = "방패: 방패 고블린 ×2", units = [["WARDEN", 2]] },
	{ label = "소환: 서리 주술사 ×1", units = [["ICE_MAGE", 1]] },
	{ label = "떼: 박쥐 ×6", units = [["BAT", 6]] },
	{ label = "정예 대장 + 졸개", units = [["GOBLIN", 1, true], ["GOBLIN", 3]] },
	{ label = "섞어서: 사수 2 + 방패 1 + 떼 4", units = [["CULTIST", 2], ["WARDEN", 1], ["BAT", 4]] },
]


static func _close() -> void:
	GameState.isDialogueOpen = false
	DialogueBox.current.hide_dialogue()


static func nearby():
	for p in GameState.entities.props:
		if p.type == "ARENA" and Util.dist(p, GameState.player) < 120: return p
	return null


static func open() -> void:
	var spot = GameState.dojoSpot if GameState.dojoSpot else Vector2(GameState.player.x, GameState.player.y)
	var options: Array = MENU.map(func(m): return { label = m.label, on_select = func():
		_close()
		var i := 0
		for u in m.units:
			for k in int(u[1]):
				var a := (i / 8.0) * TAU
				var r := 160.0 + (i % 3) * 40
				var e := Enemy.make(spot.x + cos(a) * r, spot.y + 60 + sin(a) * r * 0.6, u[0], u.size() > 2 and u[2])
				e.aggro = true
				World.add_entity("enemies", e)
				i += 1
		Hud.pop("%s. 시험 시작" % m.label, "⚔️") })
	options.append({ label = "싸움터를 비운다", on_select = func():
		_close()
		for e in GameState.entities.enemies:
			if e.type != "DUMMY": e.remove = true })
	options.append({ label = "돌아간다", on_select = _close })
	GameState.isDialogueOpen = true
	DialogueBox.current.show_dialogue({
		name = "시험 표지",
		text = "스승이 세워 둔 표지다. 숲의 것들을 흉내 낸 허깨비를 불러낼 수 있다.\n(무엇과 싸워 볼까?)",
		options = options, on_close = _close,
	})
