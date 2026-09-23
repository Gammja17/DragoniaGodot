class_name RelicOffer
## 2D판 systems/relicOffer.js. 유물 고르기. 보스를 잡거나, 굴의 깊은 층에 처음 닿거나, 베르단을 물리치면 셋 중 하나를 고른다.
## 싸움 한복판일 수 있으니 대기줄에 넣고, 대화가 없는 틈에 연다 (update — main).

static var _queue := []


static func offer(where: String) -> void:
	var table := Relics.table()
	var pool := table.keys().filter(func(id): return not table[id].get("boss") and not table[id].get("gift") and not Relics.owns(id))
	if pool.is_empty(): return
	pool.shuffle()
	_queue.append({ where = where, picks = pool.slice(0, 3) })


static func clear() -> void: _queue.clear()


static func update() -> void:
	if _queue.is_empty() or GameState.isDialogueOpen or GameState.prologue or Cutscene.on or Ending.playing: return
	if GameState.raid.active or GameState.ambush or Combat.in_fight(): return
	# 보스가 살아 있거나, 무너지는 중이거나, 마지막 말을 남기는 중이면 기다린다 (작별 장면이 먼저다)
	if GameState.entities.bosses.any(func(b): return b.awake and not b.remove): return
	var o: Dictionary = _queue.pop_front()
	var close := func():
		GameState.isDialogueOpen = false
		DialogueBox.current.hide_dialogue()
	GameState.isDialogueOpen = true
	Sfx.play("relic")
	var kins: Dictionary = Data.get_module("systems_relics").KINS
	DialogueBox.current.show_dialogue({
		name = "유물",
		text = "%s 빛나는 것 셋을 찾았다. 하나만 가져갈 수 있다." % o.where,
		on_close = close,
		options = o.picks.map(func(id):
			var r: Dictionary = Relics.table()[id]
			var tag: String = " · %s" % kins[r.kin].name if r.get("kin") else ""
			return { label = "💎 %s%s — %s" % [r.name, tag, r.desc], on_select = func():
				close.call()
				Relics.grant(id, GameState.player.x, GameState.player.y) }),
	})
