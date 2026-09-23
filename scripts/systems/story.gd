class_name Story
## 2D판 systems/story.js. 스승의 수련 · 승급 시험 · 잠 · 아침 장면 · 장 · 이야기가 세상을 바꾸는 일.
## GameState.story = { scenes: [본 장면 id], lessons: [끝낸 수련 id], lessonDay: 마지막으로 수련한 날, … }
## 수련 중에는 GameState.activity = { type: 'TARGETS' | 'DODGE' | 'DUEL', npc(스승), ... }

# 어린 용의 잘 시간. 성체가 되기 전에는 밤이 깊으면 알아서 잠든다
const BEDTIME := 0.93
const YAWN := 0.88
const RAID_GRACE := 180   # 습격 뒤 잠들지 않는 시간(초)
const BEDTIME_LINES := {
	"Elder": "아직도 안 자고 뭐 하느냐. 어린것들은 잘 시간이란다… 어서 들어가거라.",
	"Kairon": "너 아직도 안 잤냐. 용은 자면서 큰다고 내가 몇 번을 말했는데. 얼른 들어가서 자라.",
	"Tiamat": "밤에는 내가 보고 있을 테니까 너는 들어가서 자. 눈이 벌써 반쯤 감겼어.",
	"Gron": "애가 이 시간까지 뭘 돌아다녀. 가서 자라, 시끄럽다.",
	"Nara": "야, 너 졸면서 걷고 있어. …나? 나도 이제 자러 갈 거거든.",
	"Poco": "하아암… 나 졸려. 너도 자러 가자, 응?",
}
const EGG_SIT_DAYS := 3   # 촌장이 알을 품어 주는 날수


static func _data() -> Dictionary: return Data.get_module("story")
static func _stages() -> Array: return Data.get_module("elements").STAGES
static func _adult() -> int:
	var st := _stages()
	for i in st.size():
		if st[i].id == "ADULT": return i
	return 2


static func _close() -> void:
	GameState.isDialogueOpen = false
	GameState.currentNpc = null
	DialogueBox.current.hide_dialogue()


static func _say(npc, text: String, then = null) -> void:
	GameState.isDialogueOpen = true
	DialogueBox.current.show_dialogue({ name = Names.npc(npc.config.name), text = text, sheet = npc.sheet, on_close = _close,
		options = [{ label = "시작한다!" if then else "알겠습니다.", on_select = func():
			_close()
			if then: then.call() }] })


# ---------- 스승과의 대화에 끼워 넣는 선택지 (NpcActions 가 부른다) ----------

static func next_lesson():
	for l in _data().LESSONS:
		if not GameState.story.lessons.has(l.id): return l
	return null


## 지금 청할 수 있는 승급 시험 (없으면 null)
static func pending_trial():
	var t = next_trial()
	return t if t and not t.blocked else null


## 다음 승급 시험과, 아직 안 되는 이유. 레벨만 채우면 이틀 만에 성체가 되던 것을, 배운 것·겪은 것에도 묶었다
static func next_trial():
	var p = GameState.player
	var t = null
	for tr in _data().TRIALS:
		if tr.stage == p.stage_index + 1: t = tr.duplicate()
	if t == null: return null
	var st: Dictionary = _stages()[int(t.stage)]
	t.blocked = null
	if p.level < st.minLevel: t.blocked = "아직 이르다. 레벨 %d은 되어야 몸이 버틴다. (지금 %d)" % [st.minLevel, p.level]
	elif st.get("needsAllElements") and p.elements.size() < 3: t.blocked = "세 숨결을 모두 제 것으로 만든 뒤의 이야기다."
	elif t.get("needs") and not t.needs.call(GameState): t.blocked = t.why
	return t


static func master_options(npc) -> Array:
	var p = GameState.player
	var opts := []
	# 첫날 밤을 자고 나야(제1장) 엘더가 스승을 소개해 준다
	if not GameState.story.scenes.has("ch1"):
		return [{ label = "[수련] 가르침을 청한다", on_select = func(): _say(npc, "엘더 영감한테 아직 얘기를 못 들었나 보군. 오늘은 마을을 둘러보고, 둥지에서 하룻밤 자고 오너라.") }]
	var trial = next_trial()
	if trial and not trial.blocked:
		opts.append({ label = "[승급 시험] %s(으)로 자란다" % _stages()[int(trial.stage)].name, on_select = func(): start_drill(npc, { type = "DUEL", hp = trial.hp }, { trial = trial }) })
	elif trial:
		opts.append({ label = "[승급 시험] %s (아직 이르다)" % _stages()[int(trial.stage)].name, on_select = func(): _say(npc, trial.blocked) })
	opts.append({ label = "연습 대련을 청한다 (보상 없음)", on_select = func(): start_drill(npc, { type = "DUEL", hp = 220 + p.level * 12 }, { practice = true }) })
	# 수련과 쉬는 날은 여기서 고르지 않는다. 그날 스승이 정해 준다 (Training)
	var lesson = next_lesson()
	if lesson and p.level < lesson.level:
		opts.append({ label = "(다음 기본기: %s → %s. 레벨 %d 필요)" % [lesson.title, Data.get_module("skills").SKILLS[lesson.skill].name, lesson.level],
			on_select = func(): _say(npc, "아직 이르다. 레벨 %d은 돼서 와라. 숲에서 몸을 더 굴리고." % lesson.level) })
	return opts


## 기본기 수련을 시작한다 (Training 이 부른다)
static func start_lesson(npc, lesson: Dictionary) -> void:
	_say(npc, lesson.intro, func(): start_drill(npc, lesson.drill, { lesson = lesson }))


# ---------- 고룡의 깨어남 ----------
## 구름 위 폐허의 빈 둥지 앞에서 [Space]. 처리했으면 true
static func try_awaken() -> bool:
	if GameState.map_id != "SKY_RUINS": return false
	var p = GameState.player
	var nest = null
	for x in GameState.entities.props:
		if x.type == "RUIN" and Util.dist(p, x) < 130: nest = x
	if not nest: return false
	if p.stage_index >= 3:
		Hud.pop("빈 둥지는 조용하다. 여기서 받을 것은 다 받았다.", "🪹"); return true
	if p.stage_index < 2:
		Hud.pop("둥지 안이 희미하게 따뜻하다. 아직 이 온기를 받을 몸이 아니다.", "🪹"); return true
	var lacks := []
	if p.elements.size() < 3: lacks.append("숨결 셋 (지금 %d)" % p.elements.size())
	if p.level < _stages()[3].minLevel: lacks.append("레벨 %d (지금 %d)" % [_stages()[3].minLevel, p.level])
	if not lacks.is_empty():
		Hud.pop("둥지 안이 따뜻하다. 무언가 모자란다: %s" % " · ".join(lacks), "🪹"); return true
	Chronicle.play_scene("빈 둥지", [
		{ who = "나", text = "(둥지 안에 손을 대자 돌이 따뜻했다. 삼백 년 전에도, 얼마 전에도 누가 여기서 태어났다.)" },
		{ who = "나", text = "(품고 있던 숨결들이 한꺼번에 뜨거워진다. 불과 얼음과 번개가 서로 밀어내지 않고 하나로 엮인다.)" },
		{ who = "나", text = "(등이 갈라지는 것 같더니 날개가 한 뼘 더 자랐다. 이건 누가 시험을 내서 얻은 게 아니라, 원래 내 것이었던 것 같다.)" },
	], func():
		p.evolve(3)
		Vfx.spawn_effect("BLOOM", p.x, p.y - 40, { size = 1.8, color = "#fff2b0" })
		Vfx.spawn_effect("RUNE", p.x, p.y, { size = 2.6, color = "#ffe9a0" })
		for i in 14: Skills.later(i * 90, func(): Vfx.spawn_effect("SPARKLE", p.x + Util.rand_range(-90, 90), p.y - Util.rand_range(0, 80), { size = 1.2, color = "#fff2b0" }))
		Save.save_game())
	return true


# ---------- 수련 ----------
## extra.rival: 같이 허수아비를 깨는 맞수 · extra.onEnd(win): 끝났을 때 보상 대신 부를 것
static func start_drill(npc, drill: Dictionary, extra: Dictionary) -> void:
	_close()
	var p = GameState.player
	var a := extra.duplicate()
	a.merge({ type = drill.type, npc = npc, timer = 1.0, time = drill.get("time", 0), max = drill.time if drill.get("time") else drill.get("hp", 1), hp = drill.get("hp", 0), startHp = p.hp }, true)
	GameState.activity = a
	if extra.get("trial"): _say(npc, extra.trial.intro, func(): pass)
	if drill.type == "TARGETS":
		a.dummies = []
		for i in int(drill.count):
			var ang := (i / float(drill.count)) * TAU
			var spot = GameState.dojoSpot if GameState.dojoSpot else Vector2(npc.x, npc.y + 120)
			var d := Enemy.make(spot.x + cos(ang) * 200, spot.y + 40 + sin(ang) * 140, "DUMMY")
			d.max_hp = drill.hp; d.hp = drill.hp
			a.dummies.append(d)
			World.add_entity("enemies", d)
			Vfx.spawn_effect("PUFF", d.x, d.y - 10)
		Hud.pop("내기: %s보다 허수아비를 많이 부수세요!" % Names.npc(extra.rival.config.name) if extra.get("rival") else "수련: 허수아비 %d개를 %d초 안에 부수세요!" % [drill.count, drill.time], "🎯")
	elif drill.type == "DODGE":
		a.rate = drill.rate
		Hud.pop("수련: %d초 동안 불씨를 피하세요! 체력이 40%% 아래로 떨어지면 실패. ([Shift] 대시)" % drill.time, "💨")
	else:
		Hud.pop("스승의 기력을 모두 깎으세요! 체력이 25% 아래로 떨어지면 패배.", "⚔️")
	Sfx.play("warn")


static func _end_drill(win: bool) -> void:
	var a: Dictionary = GameState.activity
	var p = GameState.player
	GameState.activity = null
	Hud.current.set_boss_bar(null)
	for d in a.get("dummies", []): d.remove = true
	for b in GameState.entities.bullets:
		if b.faction == "ENEMY": b.remove = true
	p.hp = maxf(p.hp, p.max_hp * 0.5)
	if a.get("onEnd"):
		a.onEnd.call(win)
		return
	if not win:
		a.npc.say("아직 멀었으니까 더 구르고 다시 와라.")
		Hud.pop("수련 실패… 다시 도전할 수 있습니다.", "💫")
		return
	if a.get("practice"):
		a.npc.say("좋은 몸놀림이다.")
		p.gain_xp(20 + p.level * 4)
		return
	if a.get("trial"):
		p.evolve(int(a.trial.stage))
		play_rite(int(a.trial.stage))        # 마을이 모여 새 이름을 불러 준다
	else:
		GameState.story.lessons.append(a.lesson.id)
		GameState.story.lessonDay = GameState.day
		a.npc.say("잘했다. 오늘은 여기까지.")
		# 같이 구르는 또래가 곁에 있으면 한마디 거든다
		for n in GameState.entities.npcs:
			if n.config.get("name") == "Nara" and Util.dist(n, p) < 900: n.say(Data.get_module("npcTalk").NPC_TALK.Nara.trainingLines.pick_random())
		Skills.learn(a.lesson.skill)
		p.gain_xp(40 + a.lesson.level * 25)
		Hud.pop("%s 완료! 둥지에서 자고 나면 다음 수련을 받을 수 있습니다." % a.lesson.title, "🎓")
	Save.save_game()


## 승급 시험을 넘으면 마을이 너를 달리 대한다 (data/ceremony)
static func play_rite(stage: int) -> void:
	var rites: Dictionary = Data.get_module("ceremony").RITES
	var rite = rites.get(str(stage))
	if not rite: return
	var p = GameState.player
	var ctx := { name = p.config.get("name", ""), element = p.element if p.element else "FIRE", cloudtop = GameState.story.events.has("ev_gathering") }
	if not GameState.story.rites.has(stage): GameState.story.rites.append(stage)
	if rite.get("clue"): Quests.add_clue(rite.clue)
	Chronicle.play_scene(rite.title, rite.lines.call(ctx), func():
		if rite.get("toast"): Hud.pop(rite.toast, "🏅")
		Sfx.play("evolve")
		Save.save_game(), true, rite.get("place"))


## 수련 중 스승의 움직임과 판정. Dragon 이 부른다
static func update_drill(npc, dt: float) -> void:
	var a: Dictionary = GameState.activity
	var p = GameState.player
	var d := Util.dist(npc, p)
	var to_player := atan2(p.y - npc.y, p.x - npc.x)
	var fire := func(angle: float, speed := 300.0, damage := 5.0):
		Projectile.add(Projectile.new(npc.x, npc.y - 50, angle, { faction = "ENEMY", element = "FIRE", damage = damage, speed = speed, life = 3, scale = 0.7 }))
	if a.type == "TARGETS":
		a.time -= dt
		if a.get("rival"): _rival_tick(a, dt)
		var left: int = a.dummies.filter(func(x): return not x.remove).size()
		var mine: int = a.dummies.size() - left - a.get("rivalKills", 0)
		Hud.current.set_boss_bar("나 %d : %d %s" % [mine, a.rivalKills, Names.npc(a.rival.config.name)] if a.get("rival") else "허수아비 %d개 남음" % left, a.time / a.max)
		if left == 0: _end_drill(mine > a.rivalKills if a.get("rival") else true)
		elif a.time <= 0: _end_drill(false)
		return
	if a.type == "DODGE":
		a.time -= dt; a.timer -= dt
		Hud.current.set_boss_bar("불씨 피하기", a.time / a.max)
		if a.timer <= 0:
			a.timer = a.rate
			a.wave = a.get("wave", 0) + 1
			if a.wave % 5 == 0:
				var off := Util.rand_range(0, 6.28)
				for i in 12: fire.call(off + i * PI / 6, 240)
			else:
				for da in [-0.25, 0.0, 0.25]: fire.call(atan2(p.y - 30 - (npc.y - 50), p.x - npc.x) + da, 320)
			npc.animator.play("attack")
		if d > 520: npc.move_by(cos(to_player), sin(to_player), 200, dt)
		if p.hp < p.max_hp * 0.4: _end_drill(false)
		elif a.time <= 0: _end_drill(true)
		return
	# DUEL: 스승과 대련 (수련·승급 시험 공용). 기력(a.hp)은 Dragon.take_damage 가 깎는다
	Hud.current.set_boss_bar("승급 시험: 스승 카이론" if a.get("trial") else "스승과의 대련", a.hp / a.max)
	var mv := to_player if d > 320 else to_player + PI if d < 200 else to_player + PI / 2
	npc.move_by(cos(mv), sin(mv), 185, dt)
	a.timer -= dt
	if a.timer <= 0:
		var hard: bool = a.hp < a.max / 2.0
		a.timer = 0.8 if hard else 1.1
		a.wave = a.get("wave", 0) + 1
		var aim := atan2(p.y - 30 - (npc.y - 50), p.x - npc.x)
		if a.wave % 4 == 0:
			var off := Util.rand_range(0, 6.28)
			var n := 16 if hard else 10
			for i in n: fire.call(off + i * TAU / n, 250, 7)
		else:
			for da in ([-0.3, -0.1, 0.1, 0.3] if hard else [-0.15, 0.15]): fire.call(aim + da, 340, 7)
		npc.animator.play("attack")
	if a.hp <= 0: _end_drill(true)
	elif p.hp < p.max_hp * 0.25 or d > 1200: _end_drill(false)


## 맞수가 가까운 허수아비로 달려가 두들긴다. 제 손으로 깬 것만 제 몫으로 센다
static func _rival_tick(a: Dictionary, dt: float) -> void:
	var r = a.rival
	var alive: Array = a.dummies.filter(func(x): return not x.remove)
	if alive.is_empty(): return
	alive.sort_custom(func(u, v): return Util.dist(r, u) < Util.dist(r, v))
	var d = alive[0]
	if Util.dist(r, d) > 90:
		r.move_by(d.x - r.x, d.y - r.y, 210, dt)
		return
	r.moving = false
	d.hp -= a.rivalDps * dt
	d.hit_flash = 1.0
	if d.hp <= 0:
		d.remove = true
		a.rivalKills += 1
		Vfx.spawn_effect("PUFF", d.x, d.y - 10)
		r.say(["하나!", "내 거!", "느려, 느려!", "또 내 거!"].pick_random())


static func is_drill(a) -> bool:
	return a != null and (a.type == "TARGETS" or a.type == "DODGE" or a.type == "DUEL")


# ---------- 잠과 아침 ----------
static func open_nest_menu() -> void:
	GameState.isDialogueOpen = true
	var busy: bool = GameState.raid.active or GameState.activity != null or GameState.entities.bosses.any(func(b): return b.awake)
	var rest := Den.cozy_rest()
	var opts := []
	if busy: opts = [{ label = "나중에", on_select = _close }]
	else:
		opts.append({ label = "잠을 잔다 (다음 날 아침까지)", on_select = sleep })
		if not GameState.den.built: opts.append({ label = "둥지를 짓는다 (나뭇가지 %d/8, 30G)" % GameState.den.twigs, on_select = _build_nest })
		if Den.in_my_den(): opts.append({ label = "🪑 굴을 꾸민다", on_select = func():
			_close()
			DenPanel.open() })
		opts.append({ label = "아직 안 졸려", on_select = _close })
	DialogueBox.current.show_dialogue({ name = "둥지", on_close = _close, options = opts,
		text = "지금은 잠들 수 없다. 주변이 너무 소란스럽다." if busy else "%d일째. 자고 일어나면 다음 날 아침이 된다.\n(굴: %s. %s)" % [GameState.day, rest.tier.name, rest.tier.note] })


static func _build_nest() -> void:
	var p = GameState.player
	var den: Dictionary = GameState.den
	if den.twigs < 8 or p.gold < 30:
		GameState.isDialogueOpen = true
		DialogueBox.current.show_dialogue({ name = "둥지", text = "재료가 모자란다. 나뭇가지 %d/8, 골드 %d/30. 나뭇가지는 숲의 그루터기에서 [E]로 주울 수 있다." % [den.twigs, p.gold],
			on_close = _close, options = [{ label = "모아 오자", on_select = _close }] })
		return
	_close()
	den.twigs -= 8; p.gold -= 30; den.built = true
	var nest = GameState.entities.nests[0]
	Vfx.spawn_effect("RING", nest.x, nest.y, { size = 1.6 })
	Hud.pop("포근한 둥지를 지었습니다! 이제 알을 품을 수 있습니다.", "🪹")
	Sfx.play("quest")
	Save.save_game()


static func sleep() -> void:
	_close()
	# 이야기가 습격을 기다리는 밤에는 잠들지 못한다. 눕자마자 나팔이 깨운다
	if Raid.wanted():
		_horn_at_night()
		return
	Sfx.play("sleep")
	# 자정을 넘겨 잠들었으면 날짜는 이미 넘어가 있다
	var wake_day := GameState.day + 1 if GameState.dayTime >= 0.27 else GameState.day
	Hud.fade_screen("%d일째 아침" % wake_day, func():
		var p = GameState.player
		GameState.day = wake_day
		GameState.dayTime = 0.27
		GameState.event = null
		GameState.weather.type = "CLEAR"; GameState.weather.timer = Util.rand_range(40, 90)
		GameState.raidTimer = maxf(GameState.raidTimer, 45)   # 눈 뜨자마자 습격당하지 않게
		p.hp = p.max_hp
		# 굴이 아늑할수록 배가 덜 꺼진다
		var rest := Den.cozy_rest()
		p.hunger = maxf(30, p.hunger - roundi(25 * (1 - rest.heal)))
		for n in GameState.entities.npcs:
			if n.config.get("fixed"):
				n.x = n.home_x; n.y = n.home_y; n.hp = n.max_hp; n.down_timer = 0
		for n in [GameState.partner, GameState.companion]:
			if n and n.state != "WANDER":
				n.x = p.x + 70; n.y = p.y + 20
		# 알은 밤에 곁에서 품는 게 제일 빠르다. 아이들은 자고 나면 조금 자라 있다
		if not GameState.entities.nests.is_empty():
			var nest = GameState.entities.nests[0]
			if nest.has_egg:
				nest.progress = minf(100, nest.progress + 25 * (1.5 if Relics.has("NEST_CHARM") else 1.0))
				if nest.progress >= 100: nest.hatch()
				else: Hud.pop("밤새 알을 품었다. 껍데기가 조금 따뜻해졌다.", "🥚")
		for k in GameState.kids:
			if k.get("entity") and k.stage != "ADULT": k.entity.grow(10)
		GameState.story.yesterday = GameState.story.today   # 오늘 있었던 일은 내일 아침의 "어제"가 된다
		GameState.story.today = {}
		Quests.notify("sleep")           # "하룻밤 자고 나서" 로 이어지는 대목
		Save.save_game(), play_morning_scene)


## 잠을 청했는데 습격이 오는 밤. 날은 넘어가지 않고, 한밤의 마을 광장에서 싸움이 시작된다
static func _horn_at_night() -> void:
	Hud.fade_screen("한밤중", func(): GameState.dayTime = 0.9, func():
		Chronicle.play_scene("나팔 소리", [
			{ who = "나", text = "(막 잠이 들려는데 밖이 소란스럽다 싶더니, 나팔 소리가 길게 울린다.)" },
			{ who = "Tiamat", text = "다들 일어나! 사냥꾼이야!" },
		], func(): Raid.trigger(), true, "VILLAGE"))


# ---------- 이야기가 세상을 바꾸는 일 ----------
# story.route: 'guardian'(이그나르를 끝냈다) | 'redeem'(데려왔다) | 'dark'(그의 손을 잡았다)
# story.flags: 그 밖의 한 번 일어난 일들
static func on_flag(flag: String) -> void:
	if not GameState.story.has("flags"): GameState.story.flags = {}
	GameState.story.flags[flag] = true
	match flag:
		"gron_dead": _kill_npc("Gron")
		"ignar_slain": GameState.story.route = "guardian"
		"ignar_spared": GameState.story.route = "redeem"
		"route_dark":                       # 본 이야기(m6)를 내려놓고 그의 편에 선다
			GameState.story.route = "dark"
			GameState.quests.active.erase("m6")
			if GameState.quests.tracked == "m6": GameState.quests.tracked = null
			for b in GameState.entities.bosses:
				if b.id == "IGNAR": b.reset()
		"dark_duel": _dark_duel()
		"couple_egg": GameState.story.coupleEggDay = GameState.day
		"couple_hatched":   # 도란과 미루의 아이. 이름은 플레이어가 짓는다
			NameInput.ask("도란과 미루의 아이 이름을 지어 주세요 (6자까지)", "이슬", func(n: String):
				if not GameState.story.has("npcNames"): GameState.story.npcNames = {}
				GameState.story.npcNames.Iseul = n
				Data.get_module("npcs").NAME_OVERRIDES.Iseul = n
				Hud.pop("아이의 이름은 %s. 내일부터 마을을 뛰어다닌다." % n, "🐣")
				Save.save_game())
	Save.save_game()


## 어둠의 길 끝. 마을 어귀를 스승이 막아선다. 이기면 마을이 넘어가고, 지면 스승이 끌고 돌아온다
static func _dark_duel() -> void:
	var p = GameState.player
	var k = World.any_npc("Kairon")
	if not GameState.entities.npcs.has(k):
		k.remove = false
		World.add_entity("npcs", k)
	k.x = p.x + 160; k.y = p.y; k.walk_to = null
	var dark: Dictionary = _data().DARK_ROUTE
	start_drill(k, { type = "DUEL", hp = 700 + p.level * 20 }, {
		onEnd = func(win: bool):
			if win:
				Chronicle.play_scene("무너진 문", dark.win, func():
					Quests.notify("event", "dark_win")
					Save.save_game())
				return
			# 졌다. 스승이 데리고 돌아온다 — 교화. 본 이야기로 되돌아간다
			Chronicle.play_scene("집에 가자", dark.lose, func():
				GameState.story.route = null
				GameState.story.flags.turned_back = true
				GameState.quests.active.erase("m7d")
				var m6 = Quests.by_id("m6")
				if m6 and not GameState.quests.done.has("m6"):
					Quests.accept(m6)
					if GameState.quests.active.has("m6"): GameState.quests.active.m6.step = maxi(GameState.quests.active.m6.step, 2)
				Save.save_game()),
	})


## 이야기에서 용이 죽는다. 일과와 명단에서 빠지고, 곁에 있었다면 떠난다
static func _kill_npc(nm: String) -> void:
	if not GameState.story.has("dead"): GameState.story.dead = []
	if not GameState.story.dead.has(nm): GameState.story.dead.append(nm)
	if not GameState.story.has("deathDay"): GameState.story.deathDay = {}
	GameState.story.deathDay[nm] = GameState.day
	if GameState.partner and GameState.partner.config.get("name") == nm: GameState.partner = null
	if GameState.companion and GameState.companion.config.get("name") == nm: GameState.companion = null
	for n in GameState.entities.npcs:
		if n.config.get("name") == nm: n.remove = true
	# 그 용이 맡겼던 일은 이제 보고할 데가 없다
	for q in Quests.all():
		if not GameState.quests.active.has(q.id) or q.act == "main" or Quests.turn_in_npc(q) != nm: continue
		GameState.quests.active.erase(q.id)
		Hud.pop("%s의 부탁 [%s]은 끝내 전하지 못했다." % [Names.npc(nm), q.title], "🕯️")
	Quests.changed()
	Save.save_game()


# ---------- 장 ----------
## 매 프레임. 장이 넘어가면 까만 화면에 "제 N 장 · 이름" 을 띄운다
static func update_chapter() -> void:
	if GameState.isDialogueOpen or GameState.prologue or GameState.activity or GameState.raid.active or GameState.tour or GameState.nav: return
	if GameState.bannerUntil and GameState.game_time < GameState.bannerUntil: return   # 지역 이름·퀘스트 배너가 떠 있는 동안은 기다린다
	var ch := Chapters.current(GameState)
	if GameState.story.get("chapter") == ch.id: return
	var turned: bool = GameState.story.get("chapterTitle") != ch.title   # 한 장이 앞뒤로 나뉜 경우엔 이름을 다시 띄우지 않는다
	GameState.story.chapter = ch.id
	GameState.story.chapterTitle = ch.title
	if turned: Hud.show_chapter_card("제 %s 장" % ch.title.replace("장", ""), ch.name, Save.save_game)
	else: Save.save_game()


## 매 프레임. 성체가 되기 전에는 밤이 깊으면 알아서 잠든다 (밤을 새우다 아침 장면을 통째로 놓치는 일이 있었다)
static func update_bedtime() -> void:
	var p = GameState.player
	var t := GameState.dayTime
	if p.stage_index >= _adult() or GameState.isDialogueOpen or GameState.prologue: return
	if t >= YAWN and t < BEDTIME and not GameState.story.today.get("yawned"):
		GameState.story.today.yawned = true
		Hud.pop("하품이 난다. 곧 잘 시간이다.", "🥱")
	if not (t >= BEDTIME or t < 0.2): return
	if Gathering.is_gather_now(): return   # 달맞이 모임은 밤에 선다
	# 습격을 막아 낸 직후에는 3분쯤 숨을 돌린다
	var ended = GameState.story.today.get("raidEndedAt")
	if ended != null and GameState.game_time - ended < RAID_GRACE:
		if not GameState.story.today.get("graceToast"):
			GameState.story.today.graceToast = true
			Hud.pop("습격이 끝났다. 잠들기 전에 마을을 한 바퀴 돌아보자.", "🌙")
		return
	if GameState.nav: return   # 알아서 걸어가는 중이면 다 가고 나서
	if GameState.raid.active or Ambush.active() or Raid.wanted() or GameState.activity or GameState.dungeon or GameState.tour or GameState.prologue \
		or GameState.entities.bosses.any(func(b): return b.awake): return
	var near = null
	for n in GameState.entities.npcs:
		if BEDTIME_LINES.has(n.config.get("name")) and Util.dist(n, p) < 500:
			near = n
			break
	var lines := [{ who = near.config.name, text = BEDTIME_LINES[near.config.name] }] if near else []
	lines.append({ who = "나", text = "(눈꺼풀이 무겁다. 더는 못 버티겠다.)" })
	Chronicle.play_scene(null, lines, func():
		if GameState.map_id != Den.MY_DEN: World.travel_to(Den.MY_DEN)
		sleep(), false)


## 촌장에게 맡긴 알이 오늘 깨어나면 데려다주는 장면. 재생했으면 true
static func _deliver_egg() -> bool:
	var egg = GameState.eggSitting
	if not egg or GameState.day - egg.day < EGG_SIT_DAYS: return false
	GameState.eggSitting = null
	var p = GameState.player
	Chronicle.play_scene("알이 깨어났다", [
		{ who = "Elder", text = "왔다. 문 앞에서 기다리고 있었다." },
		{ who = "Elder", text = "사흘을 품었더니 밤새 발길질을 하더구나. 성질이 급한 아이다." },
		{ who = "Elder", text = "자, 네 아이다. 이제부터는 네가 품어라." },
	], func():
		var baby := BabyDragon.make(p.x + Util.rand_range(-40, 40), p.y + Util.rand_range(20, 50), egg.genes)
		World.add_entity("babies", baby)
		Kids.register(baby)
		Vfx.spawn_effect("RING", baby.x, baby.y)
		Quests.notify("hatch")
		Hud.pop("아기 용이 태어났습니다!", "🐣")
		Save.save_game())
	return true


## 아직 안 본 장면 중 조건이 맞는 첫 번째를 재생 (아침에 눈뜰 때)
static func play_morning_scene() -> void:
	if _deliver_egg(): return   # 맡긴 알이 먼저다
	if Family.morning(): return   # 일을 맡은 아이들이 들고 온 것 · 다 자란 아이의 성년식
	for sc in _data().SCENES:
		if not GameState.story.scenes.has(sc.id) and sc.when.call(GameState):
			GameState.story.scenes.append(sc.id)
			Chronicle.play_scene(sc.title, sc.lines, Save.save_game, true, sc.get("place"))
			return
