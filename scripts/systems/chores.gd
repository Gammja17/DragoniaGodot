class_name Chores
## 2D판 systems/chores.js. 마을 게시판. 숫자를 채우면 끝나는 일거리는 퀘스트에서 빼서 전부 여기 붙여 두었다.
## 아무도 말을 걸지 않고, 아무 이야기도 열지 않는다. 하고 싶을 때 가서 떼어 오면 된다.
##
## GameState.chores = { day: 쪽지를 붙인 날, offers: [id], taken: { id: 진행도 }, done: [id] }

const MAX_TAKEN := 2      # 한 번에 떼어 올 수 있는 쪽지 수
const OFFER_COUNT := 3    # 하루에 붙는 쪽지 수


static func _c() -> Dictionary:
	if not GameState.chores or not GameState.chores.has("taken"): GameState.chores = { day = 0, offers = [], taken = {}, done = [] }
	return GameState.chores


static func _by_id(id: String):
	for ch in Data.get_module("chores").CHORES:
		if ch.id == id: return ch
	return null


## 날짜가 바뀌면 쪽지를 새로 붙인다. 같은 날이면 늘 같은 셋이 붙어 있다
static func refresh_board() -> Dictionary:
	var c := _c()
	var day := GameState.day
	if c.day == day and not c.offers.is_empty(): return c
	var pool: Array = Data.get_module("chores").CHORES.filter(func(x): return int(x.get("min", 1)) <= GameState.player.level and not c.taken.has(x.id))
	# 날짜를 씨앗으로 고른다 — 저장했다 켜도 그날 게시판은 그대로다
	var picks := []
	var i := 0
	while i < pool.size() and picks.size() < OFFER_COUNT:
		var idx := int(floorf(absf(sin((day + 1) * 97.13 + i * 31.7)) * 1e4)) % pool.size()
		var pick: Dictionary = pool[(idx + i) % pool.size()]
		if not picks.has(pick.id): picks.append(pick.id)
		i += 1
	c.day = day
	c.offers = picks
	c.done = []            # 어제 끝낸 것은 다시 붙을 수 있다. 잡일은 되풀이되는 일거리다
	return c


static func _count(ch: Dictionary) -> int: return int(ch.goal.get("count", 1)) if ch.goal.get("count") else 1


## 고기를 모으는 쪽지는 가방 속을 본다
static func _progress(ch: Dictionary) -> int:
	if ch.goal.type == "collect": return mini(_count(ch), GameState.player.inventory.meat)
	return mini(_count(ch), int(_c().taken.get(ch.id, 0)))


static func _filled(ch: Dictionary) -> bool: return _progress(ch) >= _count(ch)


## 퀘스트와 같은 통지를 듣는다 (Quests.notify 가 넘겨 준다)
static func _on_notify(type: String, target) -> void:
	var c := _c()
	for id in c.taken:
		var ch = _by_id(id)
		if not ch or ch.goal.type != type or ch.goal.type == "collect" or _filled(ch): continue
		var g: Dictionary = ch.goal
		if (type == "kill" or type == "visit") and g.get("target") != target: continue
		if type == "delve": c.taken[id] = maxi(int(c.taken.get(id, 0)), int(target))
		else: c.taken[id] = int(c.taken.get(id, 0)) + 1
		if _filled(ch): Hud.pop("[잡일] %s 완료! 게시판에 가서 값을 받자" % ch.title, "📌")


static func install() -> void:
	Quests.chore_notify = _on_notify


## 떼어 온 쪽지 (HUD 가 읽는다)
static func taken() -> Array:
	var out := []
	for id in _c().taken:
		var ch = _by_id(id)
		if ch: out.append({ id = ch.id, title = ch.title, goal = Quests.goal_text(ch.goal), text = "%d / %d" % [_progress(ch), _count(ch)], complete = _filled(ch) })
	return out


static func _close() -> void:
	GameState.isDialogueOpen = false
	DialogueBox.current.hide_dialogue()


static func _reward_line(r: Dictionary) -> String:
	var parts := []
	if r.get("gold"): parts.append("%dG" % r.gold)
	if r.get("meat"): parts.append("고기 %d" % r.meat)
	if r.get("xp"): parts.append("경험치 %d" % r.xp)
	return " · ".join(parts)


## 게시판을 연다 (마을 광장의 BOARD 소품에서 [E])
static func open_board() -> void:
	var c := refresh_board()
	GameState.isDialogueOpen = true
	var opts := []
	# 떼어 온 쪽지부터. 다 채웠으면 값을 받는다
	for id in c.taken:
		var ch = _by_id(id)
		if not ch: continue
		if _filled(ch): opts.append({ label = "✅ 값을 받는다 — %s (%s)" % [ch.title, _reward_line(ch.reward)], on_select = func(): _pay_out(ch) })
		else: opts.append({ label = "📌 %s — %s %d/%d" % [ch.title, Quests.goal_text(ch.goal), _progress(ch), _count(ch)], on_select = func(): _drop(ch) })
	# 새로 붙은 쪽지
	var room: int = MAX_TAKEN - c.taken.size()
	for id in c.offers:
		if c.taken.has(id) or c.done.has(id): continue
		var ch = _by_id(id)
		if not ch: continue
		if room > 0: opts.append({ label = "📄 %s — %s (%s)" % [ch.title, Quests.goal_text(ch.goal), _reward_line(ch.reward)], on_select = func(): _read(ch) })
		else: opts.append({ label = "📄 %s (손이 모자란다)" % ch.title, on_select = func(): _board("한 번에 두 장까지만 떼어 갈 수 있다. 하던 것부터 끝내라.") })
	opts.append({ label = "돌아선다", on_select = _close })
	_board("%d일째 아침에 붙은 쪽지들이다.\n(잡일은 이야기와 상관없다. 하고 싶을 때만 떼어 가면 된다.)" % GameState.day, opts)


static func _board(text: String, options = null) -> void:
	GameState.isDialogueOpen = true
	DialogueBox.current.show_dialogue({ name = "마을 게시판", text = text, sheet = null, on_close = _close,
		options = options if options else [{ label = "돌아선다", on_select = open_board }] })


static func _read(ch: Dictionary) -> void:
	_board(ch.note, [
		{ label = "📌 떼어 간다 — %s" % Quests.goal_text(ch.goal), on_select = func(): _take(ch) },
		{ label = "그냥 둔다", on_select = open_board },
	])


static func _take(ch: Dictionary) -> void:
	_c().taken[ch.id] = 0
	Hud.pop("잡일: %s — %s" % [ch.title, Quests.goal_text(ch.goal)], "📌")
	Sfx.play("quest")
	Save.save_game()
	open_board()


static func _drop(ch: Dictionary) -> void:
	_board("%s\n\n(%s — %d/%d)" % [ch.note, Quests.goal_text(ch.goal), _progress(ch), _count(ch)], [
		{ label = "🗑️ 쪽지를 도로 붙여 둔다", on_select = func():
			_c().taken.erase(ch.id)
			Save.save_game()
			open_board() },
		{ label = "계속 한다", on_select = open_board },
	])


static func _pay_out(ch: Dictionary) -> void:
	var c := _c()
	var p = GameState.player
	var r: Dictionary = ch.reward
	if ch.goal.type == "collect": p.inventory.meat -= _count(ch)
	c.taken.erase(ch.id)
	c.done.append(ch.id)
	if r.get("gold"): p.gold += r.gold
	if r.get("meat"): p.inventory.meat += r.meat
	Hud.pop("잡일 완료: %s (%s)" % [ch.title, _reward_line(r)], "💰")
	Sfx.play("quest")
	if r.get("xp"): p.gain_xp(r.xp)
	Save.save_game()
	open_board()
