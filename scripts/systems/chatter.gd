class_name Chatter
## 2D판 systems/chatter.js. 마을 용들끼리의 잡담. 일과대로 서 있기만 하던 용들이 가까이 있으면 몇 마디 주고받는다.
## 마을이 배경이 아니라 동네로 보이게 하는 것이 목적이라, 이야기와는 무관한 말만 한다.

static var _timer := 30.0
static var _running = null   # { lines, i, t, npcs }


static func update(dt: float) -> void:
	if _running:
		_running.t -= dt
		if _running.t <= 0:
			if _running.i >= _running.lines.size():
				_running = null
				return
			var line: Array = _running.lines[_running.i]
			_running.i += 1
			var who = _running.npcs.get(line[0])
			if who and is_instance_valid(who) and not who.remove: who.say(line[1])
			_running.t = 2.6
		return
	if not ["VILLAGE", "CLOUDTOP", "ROOTVALE", "STONEBACK", "VOLCANO"].has(GameState.map_id) or GameState.raid.active or GameState.isDialogueOpen or GameState.tour or GameState.prologue: return
	_timer -= dt
	if _timer > 0: return
	_timer = Util.rand_range(50, 90)   # 예전엔 18~32초. 말풍선이 쉴 새 없이 떠서 줄였다
	# 가까이 서 있는 두 용의 잡담 하나
	var here := {}
	for n in GameState.entities.npcs:
		if n.config.get("fixed") and not n.remove and not n.down_timer > 0 and n.state == "WANDER": here[n.config.name] = n
	var options: Array = Data.get_module("chatter").CHATTER.filter(func(c):
		var a: String = c.pair[0]
		var b: String = c.pair[1]
		return here.has(a) and here.has(b) and not Routine.is_dead(a) and not Routine.is_dead(b) \
			and Util.dist(here[a], here[b]) < 320 and Util.dist(here[a], GameState.player) < 900)
	if options.is_empty(): return
	var c: Dictionary = options.pick_random()
	_running = { lines = c.lines, i = 0, t = 0.0, npcs = { c.pair[0]: here[c.pair[0]], c.pair[1]: here[c.pair[1]] } }
