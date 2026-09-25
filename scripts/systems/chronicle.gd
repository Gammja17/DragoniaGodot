class_name Chronicle
## 2D판 systems/chronicle.js. 사건. "가서 잡아라" 대신, 돌아다니다 보면 일이 벌어지고 그 자리에서 이야기가 열린다.
##
##  · 조건이 맞으면 그 자리에서 장면이 재생된다 (하루의 아무 때나)
##  · 장면이 끝나면 그에 딸린 퀘스트가 저절로 맡겨진다 (auto 퀘스트는 NPC가 따로 주지 않는다)
##  · 한 번 본 사건은 GameState.story.events 에 남아 다시 나오지 않는다
## 조건은 data/chronicle 의 when(ctx) 하나로 쓴다 (GDScript 로 옮긴 것은 Conditions).

static var _check_timer := 0.0
static var _playing := false
# 지금 흐르는 장면. Esc 로 대화창만 닫아 버리면 장면의 끝(then)이 영영 안 불려서 _playing 이 굳는다
static var _current = null    # { skip }  장면을 통째로 건너뛰는 손잡이
# 장면이 도는 중에 들어온 장면들. 앞 장면이 끝난 뒤에 차례로 튼다.
# 겹쳐 틀면 앞 장면이 끝(then)을 못 맺어 _playing 이 굳고, 그 뒤로 사건이 하나도 안 열렸다
static var _waiting := []
static var _choosing := false  # 사건 끝의 선택지가 떠 있다 (건너뛸 수 없다)
static var _party_cd := 0.0


## [Esc]: 장면이면 끝까지 건너뛰고 true. 선택지가 떠 있으면 아무것도 안 하고 true. 장면이 아니면 false
static func skip_scene() -> bool:
	if _choosing: return true
	if _current == null: return false
	_current.skip.call()
	return true


## 사건 조건이 읽는 것들 (data/chronicle 의 when(c))
static func context() -> Dictionary:
	var t := GameState.dayTime
	var s := GameState
	return {
		s = s,
		biome = Terrain.active_biome(),
		map = s.map_id,
		night = t < 0.22 or t > 0.82,
		hour = t * 24,
		clueCount = s.story.get("clues", []).size(),
		flag = func(id): return bool(s.story.get("flags", {}).get(id, false)),
		route = s.story.get("route"),
		day = s.day,
		raids = s.raid.count,
		done = func(id): return s.quests.done.has(id),
		active = func(id): return s.quests.active.has(id),
		lessons = s.story.lessons.size(),
		gathering = Gathering.is_gather_now(),
		boss = func(id): return bool(s.bossesDefeated.get(id, false)),
		# 퀘스트 마무리에서 무엇을 골랐는지. 사건이 그 선택을 기억한다
		chose = func(qid, oid): return s.quests.choices.get(qid) == oid,
		# 그 용과 데이트를 몇 번 했나 (밀회 줄기가 갈린다)
		datesOf = func(nm):
			var n = World.any_npc(nm)
			return n.dates if n else 0,
		relationOf = func(nm):
			for x in s.entities.npcs:
				if x.config.get("name") == nm: return x.relation
			return 0,
		# 지금 곁에 따라와 있는 용 (원정대)
		with = func(nm): return Party.is_with(nm),
	}


static func add_clue(id: String) -> void:
	Quests.add_clue(id)


static func seen_event(id: String) -> bool:
	return GameState.story.events.has(id)


## 큰 용을 쓰러뜨린 날을 적어 둔다 (story.bossDay). 소식을 반기는 인사는 며칠 동안만 나온다
static func _stamp_bosses() -> void:
	if not GameState.story.has("bossDay"): GameState.story.bossDay = {}
	for id in GameState.bossesDefeated:
		if GameState.bossesDefeated[id] and not GameState.story.bossDay.has(id): GameState.story.bossDay[id] = GameState.day


## 5장의 밀회(s1 의 둘째 대목)를 본 날을 적어 둔다 (story.trystDay). 유안은 그다음 날 봉우리에 오르고, 한여름 눈은 그 뒤에 온다
static func _stamp_tryst() -> void:
	if GameState.story.has("trystDay"): return
	var e = GameState.quests.active.get("s1")
	if GameState.quests.done.has("s1") or (e != null and int(e.step) >= 2): GameState.story.trystDay = GameState.day


## 매 프레임 부른다. 0.8초마다 조건이 맞는 사건이 있는지 살핀다
static func update(dt: float) -> void:
	_stamp_bosses()
	_stamp_tryst()
	_glint(dt)
	_party_cd -= dt
	if _party_cd <= 0 and not _playing:
		_party_cd = 0.5
		Party.sync()   # 이야기 동료: 들어올 용은 따라나서고, 일을 마친 용은 장면이 다 흐른 뒤에 돌아간다
	if _playing or Ending.playing or GameState.isDialogueOpen or GameState.dungeon or GameState.activity or GameState.raid.active: return
	if GameState.bannerUntil and GameState.play_time < GameState.bannerUntil: return   # 지역 이름이 떠 있는 동안은 기다린다
	# 잠에서 깨는 동안은 기다린다. 자는 사이 끝난 대목의 장면(장례)을 먼저 틀면, 깨어난 뒤의 아침 장면(아침 · 아이들)이
	# 그 위에 겹쳐 틀려 앞 장면이 끝을 못 맺었다 (_playing 이 풀리지 않아 그 뒤로 사건이 하나도 안 열렸다)
	if Hud.fading(): return
	if GameState.entities.bosses.any(func(b): return b.dying > 0): return   # 보스가 무너지는 동안은 기다린다 (작별은 그 뒤에)
	if Combat.in_fight(): return   # 싸움 한복판에 장면이 끼어들지 않게 (조용해지면 튼다)
	_check_timer -= dt
	if _check_timer > 0: return
	_check_timer = 0.8
	# 퀘스트 대목을 끝내며 밀어 둔 장면이 먼저다. 조용해진 지금 꺼내 재생한다
	var qs = Quests.take_scene()
	if qs:
		_playing = true
		play_scene(qs.title, qs.lines, func():
			_playing = false
			Save.save_game(), true, qs.get("place"))
		return
	# 찾아오는 대목(meet): 말을 걸어야 넘어가는 대목인데, 그 용이 있는 지도에 들어서면 그쪽이 먼저 다가온다
	# (보스를 잡고 돌아와 "누구에게 전한다"를 찾아다니던 심부름을 줄인다)
	if _meet_step(): return
	if _resume_duel(): return
	# 대화 중에 사이가 깊어졌으면, 대화가 끝난 지금 그 장면을 보여 준다
	var bond = GameState.pendingBond
	if bond:
		GameState.pendingBond = null
		var lines = Data.get_module("npcTalk").BOND_SCENES.get(bond.name, {}).get(str(bond.tier))
		if lines:
			_playing = true
			play_scene("%s하고 %s 되었다" % [Names.npc(bond.name), ["", "아는 사이가", "친구가", "절친이"][bond.tier]], lines, func():
				_playing = false
				Save.save_game())
			return
	var ctx := context()
	for ev in Data.get_module("chronicle").CHRONICLE:
		if not seen_event(ev.id) and ev.when.call(ctx):
			_fire(ev)
			return


static func _meet_step() -> bool:
	var p = GameState.player
	for q in Quests.active_quests():
		var st = Quests.cur_step(q)
		if not st or not st.get("meet") or st.goal.type != "talk": continue
		for n in GameState.entities.npcs:
			if n.config.get("name") != st.goal.target or n.remove or n.is_hidden or n.down_timer > 0: continue
			if Util.dist(n, p) > 1600: continue
			_playing = true
			Quests.complete_step(q, true)
			var lines: Array = st.get("scene", [])
			play_scene(q.title, lines if not lines.is_empty() else [{ who = st.goal.target, text = "…왔구나." }], func():
				_playing = false
				Save.save_game())
			return true
	return false


## 화살표 없이 스스로 찾는 대목(step.glint = { map, at })의 자리가 가끔 반짝인다. 가까이 가야 사건이 열린다 (6장의 잿빛 비늘)
static var _glint_t := 0.0
static func _glint(dt: float) -> void:
	_glint_t -= dt
	if _glint_t > 0 or GameState.dungeon: return
	_glint_t = 1.1
	for q in Quests.active_quests():
		var st = Quests.cur_step(q)
		var g = st.get("glint") if st else null
		if g and g.map == GameState.map_id:
			var at := World.at(g.at)
			Vfx.spawn_effect("SPARKLE", at.x, at.y - 12, { size = 1.3, color = "#e8e2d4" })


## 6장: 유안과의 겨루기는 저장되지 않는다. 겨루기 대목에서 폭포에 오면(불러온 판 · 겨루다 멀리 벗어난 판) 유안이 다시 청한다
static func _resume_duel() -> bool:
	var e = GameState.quests.active.get("m6w")
	if not e or int(e.step) != 2 or GameState.map_id != "FALLS": return false
	_playing = true
	play_scene(null, [{ who = "Yuan", text = "…아까 하던 거, 마저 하자. 둘 중 하나가 쓰러질 때까지다." }], func():
		_playing = false
		Story.on_flag("yuan_duel"))
	return true


## 사건 끝에 고르는 것 (ev.choice = { prompt, options: [{ id, label, when(ctx)?, lines, flag?, grant?, clue? }] }).
## 고른 것은 story.choices[사건 id] 에 남는다. when 이 거짓인 선택지는 아예 보이지 않는다 — 숨은 길은 그렇게 숨는다
static func _choose(ev: Dictionary, done: Callable) -> void:
	var ctx := context()
	var options: Array = ev.choice.options.filter(func(o): return not o.get("when") or o.when.call(ctx))
	var pick_one := func(o):
		GameState.isDialogueOpen = false
		DialogueBox.current.hide_dialogue()
		if not GameState.story.has("choices"): GameState.story.choices = {}
		GameState.story.choices[ev.id] = o.id
		play_scene(ev.title, o.get("lines", []) if o.get("lines") else [], func():
			if o.get("clue"): add_clue(o.clue)
			if o.get("grant"):
				var q = Quests.by_id(o.grant)
				if q: Quests.accept(q)
			if o.get("flag"): Quests.raise_flag(o.flag)
			done.call())
	GameState.isDialogueOpen = true
	_choosing = true
	DialogueBox.current.show_dialogue({ name = "", text = ev.choice.prompt, sheet = null, on_close = func(): pass,
		options = options.map(func(o): return { label = o.label, on_select = func():
			_choosing = false
			pick_one.call(o) }) })


## 조건을 따지지 않고 그 사건을 지금 튼다 (아직 안 봤을 때만). then: 다 끝난 뒤에 부를 것 (이미 봤으면 곧바로)
static func fire_now(id: String, then: Callable) -> void:
	for ev in Data.get_module("chronicle").CHRONICLE:
		if ev.id == id and not seen_event(id):
			_fire(ev, then)
			return
	then.call()


static func _fire(ev: Dictionary, then = null) -> void:
	# 본 사건으로 적는 것은 장면이 끝난 뒤다 (_finish_event). 장면 도중에 저장되고 꺼지면 그 사건이 주는 퀘스트를 영영 잃었다.
	# 도는 동안은 _playing 이 같은 사건을 다시 부르지 않게 막는다
	if not GameState.story.has("eventDay"): GameState.story.eventDay = {}
	GameState.story.eventDay[ev.id] = GameState.day   # 그날 밤은 그 사건이 이어진다 (달맞이 모임)
	_playing = true
	var finish := func():
		_finish_event(ev)
		if then: then.call()
	play_scene(ev.title, ev.lines, func():
		if ev.get("choice"): _choose(ev, finish)
		else: finish.call())


static func _finish_event(ev: Dictionary) -> void:
	_playing = false
	if not GameState.story.events.has(ev.id): GameState.story.events.append(ev.id)
	if ev.get("grant"):
		var q = Quests.by_id(ev.grant)
		if q: Quests.accept(q)
	Party.sync()   # 사건이 데려가는 동료는 장면에서 걸어 나가기 전에 붙잡는다
	if ev.get("clue"): add_clue(ev.clue)
	Quests.notify("event", ev.id)      # "그 자리에 가 있기"가 목표인 대목
	if ev.get("raid"):   # 6장: 나팔 소리에 마을로 뛰어 돌아온다
		if GameState.map_id != "VILLAGE": World.travel_to("VILLAGE")
		Raid.trigger(ev.raid)
	if ev.get("flag"): Quests.raise_flag(ev.flag)
	if ev.get("ambush"): Ambush.start(true)   # 사냥꾼 대장의 포위
	if ev.get("toast"): Hud.pop(ev.toast, ev.icon if ev.get("icon") else "📖")
	Save.save_game()


## 대사가 가리키는 것을 찾는다 (line.look). 'PROP:FOUNTAIN' · 'DEN:DEN_MINE' · 'ENEMY:DUMMY' · 'Gron'
static func _look_target(look: String):
	var p = GameState.player
	var props: Array = GameState.entities.props
	var nearest := func(list: Array):
		list.sort_custom(func(a, b): return Util.dist(a, p) < Util.dist(b, p))
		return list[0] if not list.is_empty() else null
	if look.begins_with("PROP:"): return nearest.call(props.filter(func(x): return x.type == look.substr(5)))
	if look.begins_with("DEN:"): return nearest.call(props.filter(func(x): return x.type == "DEN_MOUTH" and x.den_id == look.substr(4)))
	if look.begins_with("ENEMY:"): return nearest.call(GameState.entities.enemies.filter(func(x): return x.type == look.substr(6) and not x.remove))   # 첫날 광장의 허수아비
	for n in GameState.entities.npcs:
		if n.config.get("name") == look: return n
	return null


## 말하는 이를 찾는다. 지금 이 지도에 없어도 찾아낸다 (초상화가 비면 장면이 허전하다)
static func _find(who):
	if who == "나": return GameState.player
	for b in GameState.entities.bosses:
		if b.remove: continue
		if who is String and (b.id == who.to_upper() or b.def.name == who): return b
	return World.any_npc(who) if who is String else null


## 여러 줄짜리 장면을 차례로 보여 준다. 아침 장면(Story)도 이걸 쓴다.
## line = { who: NPC 이름 | '나' | '???', text, look?, label?, do?, zoom?, auto? } — do·zoom·auto 는 Cutscene 의 연출 박자
static func play_scene(title, lines: Array, then = null, cinematic := true, place = null) -> void:
	if _current != null:
		_waiting.append([title, lines, then, cinematic, place])
		return
	lines = _split_directions(lines.filter(func(l): return _chosen(l) and _with(l)))
	# 장면이 벌어질 곳이 따로 있으면 먼저 그리로 간다
	if place and place != GameState.map_id and not GameState.dungeon: World.travel_to(place)
	# 말할 이들은 처음부터 무대에 올린다 — 제 차례에 불쑥 튀어나오지 않게
	var speakers := []
	for l in lines:
		var e = _find(l.get("who"))
		if e and e != GameState.player and not (e is Boss) and not speakers.has(e): speakers.append(e)
	if cinematic: Cutscene.begin(title if title else "", speakers)
	elif title: Hud.pop(title, "📖")
	var st := { i = 0 }
	var me := {}
	_current = me
	var step := func(self_ref: Callable) -> void:
		if _current != me and st.i < lines.size(): return   # 건너뛴 장면의 박자가 뒤늦게 부른 것
		if st.i >= lines.size():
			if _current == me: _current = null
			if Cutscene.busy(): Cutscene.cancel_beats()
			GameState.isDialogueOpen = false
			DialogueBox.current.hide_dialogue()
			if cinematic: Cutscene.finish()
			if then: then.call()
			if _current == null and not _waiting.is_empty():   # 끝(then)이 새 장면을 열지 않았으면 기다리던 장면을 튼다
				var w: Array = _waiting.pop_front()
				play_scene(w[0], w[1], w[2], w[3], w[4])
			return
		var line: Dictionary = lines[st.i]
		st.i += 1
		var show := func(): _show_line(line, st.i < lines.size(), cinematic, func(): self_ref.call(self_ref))
		# 연출 박자가 있으면 대화창을 내리고 먼저 돌린다 (세상은 그대로 멈춰 있다)
		if line.get("do") and Cutscene.on:
			GameState.isDialogueOpen = true
			DialogueBox.current.hide_dialogue()
			Cutscene.run(line.do, show)
		else:
			show.call()
	me.skip = func():
		st.i = lines.size()
		step.call(step)
	step.call(step)


## 앞에서 고른 것을 읽는 줄. "chose": "m1:ask" 는 m1 마무리에서 ask 를 고른 경우에만, "t1:!count" 는 count 를 고르지 않은 경우에만,
## "p1:*" 는 무엇이든 고른 경우(그 퀘스트를 끝낸 경우)에만, "p1:!*" 는 아직 아무것도 고르지 않은 경우에만 나온다.
## 퀘스트 마무리의 선택(quests.choices)과 사건 끝의 선택(story.choices)을 같이 본다
static func _chosen(l: Dictionary) -> bool:
	if not l.has("chose"): return true
	var at: PackedStringArray = str(l.chose).split(":")
	var want := at[1]
	var picked = GameState.quests.choices.get(at[0], GameState.story.get("choices", {}).get(at[0]))
	if want == "*": return picked != null
	if want == "!*": return picked == null
	if want.begins_with("!"): return picked != want.substr(1)
	return picked == want


## 곁에 누가 따라와 있는지 읽는 줄. "with": "Tiamat" 은 티아맷이 곁에 있을 때만, "!Tiamat" 은 없을 때만, "*" 는 누구든 따라와 있을 때만
static func _with(l: Dictionary) -> bool:
	if not l.has("with"): return true
	var w := str(l.with)
	return not Party.is_with(w.substr(1)) if w.begins_with("!") else Party.is_with(w)


## "(티아맷이 날개로 어깨를 쳤다.) 축하해." 처럼 대사에 섞인 긴 무대 지시는 해설 줄로 떼어 낸다 —
## 말하는 이의 말풍선 안에 그 이를 가리키는 묘사가 섞이지 않게. "(웃는다.)" 같은 짧은 몸짓은 그대로 둔다.
## 연출 박자(do)·가리키기(look)는 첫 조각에, 당겨 찍기(zoom)·저절로 넘기기(auto)는 조각마다
static var _direction: RegEx
static func _split_directions(lines: Array) -> Array:
	if _direction == null:
		_direction = RegEx.new()
		_direction.compile("\\([^()]{10,}[.!?…]\\)")
	var out := []
	for l in lines:
		var text: String = str(l.get("text", ""))
		var found := _direction.search_all(text)
		if found.is_empty() or (found.size() == 1 and found[0].get_start() == 0 and found[0].get_end() == text.length()):
			out.append(l)
			continue
		var pieces := []
		var at := 0
		for m in found:
			pieces.append(text.substr(at, m.get_start() - at).strip_edges())
			pieces.append(m.get_string())
			at = m.get_end()
		pieces.append(text.substr(at).strip_edges())
		var first := true
		for p in pieces:
			if p == "": continue
			var nl: Dictionary = l.duplicate()
			if not first:
				nl = { who = l.who } if l.has("who") else {}
				for k in ["zoom", "auto"]:
					if l.has(k): nl[k] = l[k]
			nl.text = p
			out.append(nl)
			first = false
	return out


## 한 줄을 대화창에 띄운다. 대사가 없는 줄(연출만 하는 줄)은 곧바로 다음으로
static func _show_line(line: Dictionary, more: bool, cinematic: bool, nxt: Callable) -> void:
	if not line.get("text"):
		nxt.call()
		return
	var who = line.get("who", "나")
	var speaker = _find(who)
	if cinematic or Cutscene.on:
		Cutscene.focus_on(speaker)
		Cutscene.point_at(_look_target(line.look) if line.get("look") else null, line.get("label", "") if line.get("label") else "")
		Cutscene.line_zoom(line.get("zoom"))
	GameState.isDialogueOpen = true
	var text: String = line.text
	# 통째로 괄호에 든 줄 "(…)" 은 속말·장면 묘사다. 이름표 없이 해설로 보여 준다 (카메라는 그 이를 본다)
	var narration: bool = text.begins_with("(") and text.find(")") == text.length() - 1
	if narration: text = text.substr(1, text.length() - 2)
	DialogueBox.current.show_dialogue({
		name = GameState.player.config.get("name", "") if who == "나" else Names.npc(who),
		text = text,
		narration = narration,
		auto = float(line.get("auto", 0.0)),
		sheet = GameState.player.sheet if who == "나" else (speaker.sheet if speaker and speaker.get("sheet") else null),
		on_close = nxt,
		options = [{ label = "다음" if more else "끝", on_select = nxt }],
	})
	Sfx.play("talk")
