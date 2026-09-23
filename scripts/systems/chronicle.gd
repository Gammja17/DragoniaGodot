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
static var _choosing := false  # 사건 끝의 선택지가 떠 있다 (건너뛸 수 없다)


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
	}


static func add_clue(id: String) -> void:
	Quests.add_clue(id)


static func seen_event(id: String) -> bool:
	return GameState.story.events.has(id)


## 매 프레임 부른다. 0.8초마다 조건이 맞는 사건이 있는지 살핀다
static func update(dt: float) -> void:
	if _playing or GameState.isDialogueOpen or GameState.dungeon or GameState.activity or GameState.raid.active: return
	if GameState.bannerUntil and GameState.game_time < GameState.bannerUntil: return   # 지역 이름이 떠 있는 동안은 기다린다
	_check_timer -= dt
	if _check_timer > 0: return
	_check_timer = 0.8
	# 퀘스트 대목을 끝내며 밀어 둔 장면이 먼저다. 조용해진 지금 꺼내 재생한다
	var qs = Quests.take_scene()
	if qs:
		_playing = true
		play_scene(qs.title, qs.lines, func():
			_playing = false
			Save.save_game())
		return
	# 대화 중에 사이가 깊어졌으면, 대화가 끝난 지금 그 장면을 보여 준다
	var bond = GameState.pendingBond
	if bond:
		GameState.pendingBond = null
		var lines = Data.get_module("npcTalk").BOND_SCENES.get(bond.name, {}).get(str(bond.tier))
		if lines:
			_playing = true
			play_scene("%s와(과) %s가 되었다" % [bond.name, ["", "아는 사이", "친구", "절친"][bond.tier]], lines, func():
				_playing = false
				Save.save_game())
			return
	var ctx := context()
	for ev in Data.get_module("chronicle").CHRONICLE:
		if not seen_event(ev.id) and ev.when.call(ctx):
			_fire(ev)
			return


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


static func _fire(ev: Dictionary) -> void:
	GameState.story.events.append(ev.id)
	_playing = true
	play_scene(ev.title, ev.lines, func():
		if ev.get("choice"): _choose(ev, func(): _finish_event(ev))
		else: _finish_event(ev))


static func _finish_event(ev: Dictionary) -> void:
	_playing = false
	if ev.get("grant"):
		var q = Quests.by_id(ev.grant)
		if q: Quests.accept(q)
	if ev.get("clue"): add_clue(ev.clue)
	Quests.notify("event", ev.id)      # "그 자리에 가 있기"가 목표인 대목
	if ev.get("raid"):   # 6장: 나팔 소리에 마을로 뛰어 돌아온다
		if GameState.map_id != "VILLAGE": World.travel_to("VILLAGE")
		Raid.trigger(ev.raid)
	if ev.get("flag"): Quests.raise_flag(ev.flag)
	if ev.get("ambush"): Ambush.start(true)   # 사냥꾼 대장의 포위
	if ev.get("toast"): Hud.pop(ev.toast, ev.icon if ev.get("icon") else "📖")
	Save.save_game()


## 대사가 가리키는 것을 찾는다 (line.look). 'PROP:FOUNTAIN' · 'DEN:DEN_MINE' · 'Gron'
static func _look_target(look: String):
	var p = GameState.player
	var props: Array = GameState.entities.props
	var nearest := func(list: Array):
		list.sort_custom(func(a, b): return Util.dist(a, p) < Util.dist(b, p))
		return list[0] if not list.is_empty() else null
	if look.begins_with("PROP:"): return nearest.call(props.filter(func(x): return x.type == look.substr(5)))
	if look.begins_with("DEN:"): return nearest.call(props.filter(func(x): return x.type == "DEN_MOUTH" and x.den_id == look.substr(4)))
	for n in GameState.entities.npcs:
		if n.config.get("name") == look: return n
	return null


## 말하는 이를 찾는다. 지금 이 지도에 없어도 찾아낸다 (초상화가 비면 장면이 허전하다)
static func _find(who):
	if who == "나": return GameState.player
	for b in GameState.entities.bosses:
		if b.id == who or b.def.name == who: return b
	return World.any_npc(who) if who is String else null


## 여러 줄짜리 장면을 차례로 보여 준다. 아침 장면(Story)도 이걸 쓴다. line = { who: NPC 이름 | '나' | '???', text, look?, label? }
static func play_scene(title, lines: Array, then = null, cinematic := true, place = null) -> void:
	# 장면이 벌어질 곳이 따로 있으면 먼저 그리로 간다
	if place and place != GameState.map_id and not GameState.dungeon: World.travel_to(place)
	# 말할 이들은 처음부터 무대에 올린다 — 제 차례에 불쑥 튀어나오지 않게
	var speakers := []
	for l in lines:
		var e = _find(l.who)
		if e and e != GameState.player and not (e is Boss) and not speakers.has(e): speakers.append(e)
	if cinematic: Cutscene.begin(title if title else "", speakers)
	elif title: Hud.pop(title, "📖")
	var st := { i = 0 }
	var me := {}
	_current = me
	var step := func(self_ref: Callable) -> void:
		if st.i >= lines.size():
			if _current == me: _current = null
			GameState.isDialogueOpen = false
			DialogueBox.current.hide_dialogue()
			if cinematic: Cutscene.finish()
			if then: then.call()
			return
		var line: Dictionary = lines[st.i]
		st.i += 1
		var speaker = _find(line.who)
		if cinematic:
			Cutscene.focus_on(speaker)
			Cutscene.point_at(_look_target(line.look) if line.get("look") else null, line.get("label", "") if line.get("label") else "")
		GameState.isDialogueOpen = true
		var nxt := func(): self_ref.call(self_ref)
		DialogueBox.current.show_dialogue({
			name = GameState.player.config.get("name", "") if line.who == "나" else Names.npc(line.who),
			text = line.text,
			sheet = GameState.player.sheet if line.who == "나" else (speaker.sheet if speaker else null),
			on_close = nxt,
			options = [{ label = "다음" if st.i < lines.size() else "끝", on_select = nxt }],
		})
		Sfx.play("talk")
	me.skip = func():
		st.i = lines.size()
		step.call(step)
	step.call(step)
