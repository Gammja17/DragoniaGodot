class_name Romance
## 2D판 systems/romance.js. 마음의 뒷이야기. 데이트 세 번과 고백으로 끝나던 연애에 그 뒤를 붙인다.
##
##   한눈팔기  짝이 있거나 다른 용과도 데이트 중인데 또 데이트를 하면, 그 용이 봤을 수 있다
##   질투      본 용에게 다음에 말을 걸면 따져 묻는다. 사과 · 거짓말(반반) · 그쪽을 고른다
##   다툼      짝이 토라지면 굴을 나가 제 일과로 돌아간다. 고기 세 개를 들고 가서 사과해야 풀린다
##   헤어짐    토라진 짝을 엿새 넘게 내버려 두거나, 토라져 있는데 또 들키면 떠난다. 내가 먼저 말할 수도 있다
##   순애      한 번도 한눈팔지 않고 닷새를 함께 산 짝에게는 평생을 약속할 수 있다 (유물 '언약의 고리')
##   기념일    짝이 된 지 열흘마다 짝이 먼저 챙긴다
##
## GameState.story.love = { pending: {본 용: 같이 있던 용}, mood: {용: {kind, day}}, ever: [], cheated, since, vow, anniv }
##
## ui: NpcActions 가 넘겨 주는 { show(npc, text, options), close(), play_lines(npc, lines, then), hub(npc) }

const MOOD_DAYS := { "EX": 8, "HURT": 5 }
const SULK_LIMIT := 6


static func L() -> Dictionary:
	var s: Dictionary = GameState.story
	if not s.get("love"): s.love = { pending = {}, mood = {}, ever = [], cheated = false, since = null, vow = null, anniv = 0 }
	return s.love


static func _lines(npc):
	return Data.get_module("romance").LOVE_LINES.get(npc.config.name)


static func _choices() -> Dictionary: return Data.get_module("romance").LOVE_CHOICES


static func _fill(text: String, rival: String) -> String:
	return text.replace("{rival}", Names.npc(rival))


## 이 용의 지금 마음 상태. 시간이 지난 것은 걷어 낸다
static func mood_of(nm: String):
	var m = L().mood.get(nm)
	if not m: return null
	if MOOD_DAYS.has(m.kind) and GameState.day - m.day >= MOOD_DAYS[m.kind]:
		L().mood.erase(nm)
		return null
	return m.kind


static func _set_mood(nm: String, kind: String) -> void:
	L().mood[nm] = { kind = kind, day = GameState.day }


## 인사말 대신 나올 말 (토라짐 · 헤어진 뒤 · 마음을 접은 뒤). 없으면 null
static func mood_greeting(npc):
	var kind = mood_of(npc.config.name)
	var t = _lines(npc)
	if not kind or not t: return null
	return t.sulk if kind == "SULK" else t.ex if kind == "EX" else t.hurt


## 마음 메뉴를 아예 닫아 둘 상태인가
static func heart_closed(npc) -> bool:
	var k = mood_of(npc.config.name)
	return k == "EX" or k == "HURT"


static func is_sulking(npc) -> bool: return mood_of(npc.config.name) == "SULK"


## 짝이 되었다 (NpcActions 의 confess)
static func on_partnered(npc) -> void:
	var l := L()
	l.since = GameState.day
	l.anniv = 0
	if not l.ever.has(npc.config.name): l.ever.append(npc.config.name)
	l.pending.erase(npc.config.name)
	# 마음을 주고받던 다른 용들은 여기서 마음을 접는다
	for o in _courting(npc): _cool(o)


## 지금 마음을 주고받는 중인 다른 용들 (데이트를 한 번이라도 했고, 아직 접지 않은)
static func _courting(except) -> Array:
	var out := []
	for nm in Data.get_module("romance").LOVE_LINES:
		var n = World.any_npc(nm)
		if n and n != except and n != GameState.partner and n.config.get("canPartner") and n.dates >= 1 and not mood_of(nm):
			out.append(n)
	return out


## 마음을 접게 한다: 데이트가 처음으로 돌아가고 한동안 서먹하다
static func _cool(npc, relation_loss := 15) -> void:
	npc.dates = 0
	npc.relation = maxf(0, npc.relation - relation_loss)
	_set_mood(npc.config.name, "HURT")
	L().pending.erase(npc.config.name)


## 데이트를 마쳤다 (NpcActions 의 go_on_date). 다른 용이 봤을 수 있다
static func on_date(npc) -> void:
	var l := L()
	var nm: String = npc.config.name
	if not l.ever.has(nm): l.ever.append(nm)
	var others := _courting(npc)
	if GameState.partner and GameState.partner != npc: others.append(GameState.partner)
	if others.is_empty(): return
	l.cheated = true
	for o in others:
		var chance := 0.7 if o == GameState.partner else 0.45
		if randf() < chance: l.pending[o.config.name] = nm


# ---------- 말을 걸었을 때 끼어드는 것들 (NpcActions 의 open_hub 맨 앞) ----------

## 끼어들 일이 있으면 그 장면을 열고 true
static func intercept(npc, ui: Dictionary) -> bool:
	var t = _lines(npc)
	if not t or GameState.raid.active: return false
	var l := L()
	var nm: String = npc.config.name

	# 토라진 짝을 너무 오래 내버려 뒀다
	if npc == GameState.partner and is_sulking(npc) and GameState.day - l.mood[nm].day > SULK_LIMIT:
		_they_leave(npc, ui)
		return true

	var rival = l.pending.get(nm)
	if rival:
		l.pending.erase(nm)
		if npc == GameState.partner:
			if is_sulking(npc):   # 토라져 있는데 또 들켰다
				_they_leave(npc, ui)
				return true
			_jealous_partner(npc, rival, ui)
		elif npc.dates >= 1 and not mood_of(nm): _jealous_rival(npc, rival, ui)
		else: return false
		return true

	# 기념일: 짝이 된 지 열흘마다 짝이 먼저 챙긴다
	if npc == GameState.partner and not is_sulking(npc) and l.since != null:
		var nth := floori((GameState.day - l.since) / 10.0)
		if nth >= 1 and nth > int(l.get("anniv", 0)):
			l.anniv = nth
			ui.play_lines.call(npc, [t.anniv], func():
				var gold := 40 + nth * 20
				GameState.player.gold += gold
				GameState.player.inventory.meat += 2
				npc.relation = minf(100, npc.relation + 5)
				Vfx.spawn_effect("HEART", npc.x, npc.y - 80, { color = "#ff7aa8", size = 1.4 })
				Hud.pop("짝이 된 지 %d일째. %s의 선물: %dG, 고기 2개" % [nth * 10, Names.npc(nm), gold], "💝")
				Save.save_game())
			return true
	return false


static func _jealous_partner(npc, rival: String, ui: Dictionary) -> void:
	var t = _lines(npc)
	var other = World.any_npc(rival)
	var jp: Array = t.jealousPartner
	var lead := jp.slice(0, -1).map(func(x): return _fill(x, rival))
	ui.play_lines.call(npc, lead, func(): ui.show.call(npc, _fill(jp[-1], rival), [
		{ label = _choices().sorry, on_select = func():
			if other: _cool(other)
			_sulk(npc, ui, null) },
		{ label = _choices().lie, on_select = func():
			if randf() < 0.5:
				ui.show.call(npc, "…그래. 네가 그렇다면 그런 거겠지.", [{ label = "(넘어갔다)", on_select = ui.close }])
				return
			npc.relation = maxf(0, npc.relation - 20)
			_sulk(npc, ui, t.lieFail) },
		{ label = _choices().other, on_select = func(): _they_leave(npc, ui) },
	]))


static func _jealous_rival(npc, rival: String, ui: Dictionary) -> void:
	var t = _lines(npc)
	var other = World.any_npc(rival)
	var jr: Array = t.jealousRival
	var lead := jr.slice(0, -1).map(func(x): return _fill(x, rival))
	ui.play_lines.call(npc, lead, func(): ui.show.call(npc, _fill(jr[-1], rival), [
		{ label = _choices().pickYou, on_select = func():
			if other and other != GameState.partner: _cool(other)
			npc.relation = minf(100, npc.relation + 6)
			Vfx.spawn_effect("HEART", npc.x, npc.y - 80, { color = "#ff7aa8", size = 1.2 })
			ui.close.call()
			Save.save_game() },
		{ label = _choices().both, on_select = func():
			_cool(npc, 25)
			ui.show.call(npc, t.hurt, [{ label = "……", on_select = ui.close }])
			Save.save_game() },
	]))


## 짝이 토라진다: 굴을 나가 제 일과로 돌아간다
static func _sulk(npc, ui: Dictionary, line) -> void:
	_set_mood(npc.config.name, "SULK")
	npc.state = "WANDER"
	Hud.pop("%s 토라져서 굴을 나갔습니다. 고기 3개를 들고 찾아가 사과하세요." % Util.josa(Names.npc(npc.config.name), "이", "가"), "💔")
	Sfx.play("hurt")
	Save.save_game()
	if line: ui.show.call(npc, line, [{ label = "……", on_select = ui.close }])
	else: ui.close.call()


## 사과한다 (마음 메뉴). 고기 세 개가 든다
static func apologize(npc, ui: Dictionary) -> void:
	var p = GameState.player
	var t = _lines(npc)
	if p.inventory.meat < 3:
		ui.show.call(npc, "%s\n\n(빈손으로는 말이 안 통할 것 같다. 고기 3개를 들고 오자. 지금 %d개)" % [t.sulk, p.inventory.meat], [{ label = "다시 오자.", on_select = ui.close }])
		return
	p.inventory.meat -= 3
	ui.play_lines.call(npc, t.makeup, func():
		L().mood.erase(npc.config.name)
		npc.state = "PARTNER_FOLLOW"
		npc.relation = minf(100, npc.relation + 8)
		Vfx.spawn_effect("HEART", npc.x, npc.y - 80, { color = "#ff7aa8", size = 1.4 })
		Hud.pop("%s하고 화해했습니다. 다시 함께 다닙니다." % Names.npc(npc.config.name), "💞")
		Save.save_game())


static func _end_it(npc) -> void:
	var l := L()
	if GameState.partner == npc: GameState.partner = null
	npc.state = "WANDER"
	npc.dates = 0
	npc.relation = minf(npc.relation, 35)
	_set_mood(npc.config.name, "EX")
	l.since = null
	l.anniv = 0
	l.vow = null
	l.pending.erase(npc.config.name)
	Sfx.play("hurt")
	Save.save_game()


## 그쪽에서 떠난다
static func _they_leave(npc, ui: Dictionary) -> void:
	ui.play_lines.call(npc, _lines(npc).leave, func():
		_end_it(npc)
		Hud.pop("%s 떠났습니다." % Util.josa(Names.npc(npc.config.name), "이", "가"), "💔"))


## 내가 그만하자고 한다 (마음 메뉴)
static func break_up(npc, ui: Dictionary) -> void:
	ui.show.call(npc, "(정말로 그만하자고 말할까? 한 번 꺼낸 말은 주워 담을 수 없다.)", [
		{ label = "…우리 그만하자.", on_select = func(): ui.play_lines.call(npc, _lines(npc).left, func():
			_end_it(npc)
			Hud.pop("%s하고 헤어졌습니다." % Names.npc(npc.config.name), "💔")) },
		{ label = "아니야, 아무것도.", on_select = func(): ui.hub.call(npc) },
	])


# ---------- 순애 ----------

static func _only(npc) -> bool:
	return L().ever.all(func(n): return n == npc.config.name)


## 평생을 약속할 수 있는가: 이 용 말고는 누구와도 데이트한 적이 없고, 짝으로 닷새를 살았다
static func can_vow(npc) -> bool:
	var l := L()
	return npc == GameState.partner and not l.vow and not l.cheated and l.since != null and GameState.day - l.since >= 5 \
		and _only(npc) and not is_sulking(npc)


## 왜 아직 안 되는지 한 줄 (마음 메뉴에 흐리게 띄운다). 영영 안 되는 경우는 null
static func vow_hint(npc):
	var l := L()
	if npc != GameState.partner or l.vow or l.cheated or not _only(npc): return null
	var since: int = l.since if l.since != null else GameState.day
	var left := 5 - (GameState.day - since)
	return "(평생을 약속하기에는 아직 이르다. 함께 %d일을 더 지내자)" % left if left > 0 else null


static func vowed(npc) -> bool:
	var v = L().vow
	return v != null and v.with == npc.config.name


static func make_vow(npc, ui: Dictionary) -> void:
	ui.play_lines.call(npc, _lines(npc).vow, func():
		L().vow = { with = npc.config.name, day = GameState.day }
		npc.relation = 100.0
		for i in 10: Vfx.spawn_effect("HEART", npc.x + (randf() - 0.5) * 160, npc.y - 40 - randf() * 90, { color = "#ff7aa8", size = 1.2 })
		Vfx.spawn_effect("RING", npc.x, npc.y - 40, { size = 2.2, color = "#ffd0e0" })
		if not Relics.owns("VOW_RING"): Relics.grant("VOW_RING", GameState.player.x, GameState.player.y)
		Hud.pop("%s하고 평생을 약속했습니다." % Names.npc(npc.config.name), "💍")
		Sfx.play("evolve")
		Save.save_game())
