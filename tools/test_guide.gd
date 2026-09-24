extends Node
## 처음 하는 사람 안내 · 일지의 지금까지 이야기 · 에필로그의 생활 줄 (docs/tasks/README.md F 카드)
##   godot --headless --path . res://tools/test_guide.tscn

var _bad := 0


func _ready() -> void:
	Save.slot = 9   # 시험은 9번 칸을 쓴다 (사람이 쓰는 1~3번 칸을 건드리지 않게)
	Save.delete()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.play_intro = false
	main.load_save = false
	add_child(main)
	for i in 5: await get_tree().process_frame
	# 사건이 저절로 끼어들지 않게 모두 본 것으로 두고, 확인할 것만 뺀다
	for ev in Data.get_module("chronicle").CHRONICLE: GameState.story.events.append(ev.id)
	GameState.raidTimer = 99999
	_story_tab()
	_guide()
	await _hud()
	_life()
	print("[끝] 틀린 곳 %d" % _bad)
	get_tree().quit()


## HUD 나뭇가지 칸: 둥지 재료라는 이름이 붙고, 그 때문에 상태판이 크게 넓어지지 않는다
func _hud() -> void:
	var st: HudStatus = Hud.current.status
	var tw: Label = st.get_node("Lines/Inv/Twigs")
	GameState.den.built = false
	GameState.den.twigs = 3
	st.refresh()
	for i in 3: await get_tree().process_frame
	_check("HUD · 나뭇가지 칸에 둥지 이름", tw.text, "🪵 둥지 3/8")
	tw.text = "🪵 3/8"   # 예전 모양과 최소 너비를 견준다
	var old_w: float = st.get_combined_minimum_size().x
	tw.text = "🪵 둥지 3/8"
	var new_w: float = st.get_combined_minimum_size().x
	_check("HUD · 상태판 최소 너비 %dpx → %dpx (40px 넘게 안 는다)" % [old_w, new_w], new_w - old_w <= 40, true)


# ---- 에필로그 생활 줄 ----
func _life() -> void:
	var G := GameState
	var p = G.player
	var L: Dictionary = Data.get_module("ending").LIFE
	for b in G.entities.babies: b.remove = true
	G.kids.clear()
	G.partner = null
	G.story.erase("love")
	G.story.erase("ally")
	G.den.built = false
	G.denDecor = []
	G.quests.done = ["m0", "m1", "m2", "m3", "m4", "m5", "m5g", "m5a", "m6w", "m5b", "m5c", "m6"]
	G.quests.active = {}
	G.story.route = "guardian"

	# 아무것도 꾸리지 않았다: 모임 줄만
	_check("생활 · 없으면 모임 줄만", Ending.life_lines("guardian"), [L.home.gathering.peace])
	G.story.route = "redeem"
	_check("생활 · 데려온 길의 모임", Ending.life_lines("redeem"), [L.home.gathering.redeem])
	G.story.route = "guardian"

	# 짝: 함께 산 날 · 평생의 약속
	var mira = World.any_npc("Mira")
	G.partner = mira
	G.story.love = { pending = {}, mood = {}, ever = [], cheated = false, since = G.day - 12, vow = null, anniv = 0 }
	_check("생활 · 짝과 산 날", Ending.life_lines("guardian")[0], "(미라하고 한 굴에서 산 지 12일째다.)")
	G.story.love.vow = { with = "Mira", day = G.day }
	_check("생활 · 평생을 약속한 짝", Ending.life_lines("guardian")[0], "(평생을 약속한 미라하고 오늘도 한 굴에서 잠든다.)")

	# 아이: 제 부모를 닮는다 (지금 짝은 미라지만 아이는 티아맷의 아이)
	var tiamat = World.any_npc("Tiamat")
	var baby := BabyDragon.make(p.x + 40, p.y + 30, Kids.mix_genes(p, tiamat))
	World.add_entity("babies", baby)
	var kid: Dictionary = Kids.register(baby)
	_check("생활 · 아기는 제 부모를 닮는다", Ending.life_lines("guardian")[1], "(둥지에서는 아기 %s의 숨소리가 들린다. 생김새는 티아맷하고 꼭 닮았다.)" % kid.name)
	kid.stage = "TEEN"
	_check("생활 · 자라는 아이", Ending.life_lines("guardian")[1].begins_with("(요즘 %s의 날갯짓이" % kid.name), true)
	var baby2 := BabyDragon.make(p.x - 40, p.y + 30, Kids.mix_genes(p, mira))
	World.add_entity("babies", baby2)
	var kid2: Dictionary = Kids.register(baby2)
	_check("생활 · 아이 둘", Ending.life_lines("guardian")[1], "(굴 안은 %s, %s의 소리로 하루도 조용할 날이 없다.)" % [kid.name, kid2.name])

	# 굴: 손님이 드는 굴부터 부른다. 아니면 둥지를 지었을 때만
	_check("생활 · 기본 굴은 안 부른다", Ending.life_lines("guardian").size(), 3)
	G.den.built = true
	_check("생활 · 둥지만 지었다", Ending.life_lines("guardian")[2], L.home.built)
	G.denDecor = [{ id = "FIREPLACE", tx = 3, ty = 3 }, { id = "BED", tx = 9, ty = 5 }, { id = "ORB", tx = 5, ty = 3 }]
	_check("생활 · 아늑한 굴", Ending.life_lines("guardian")[2], L.home.den["2"])

	# 끝까지 곁에서 싸운 용 (원정대 G 가 story.ally 에 적는다). 짝이면 또 부르지 않는다
	G.story.ally = "Tiamat"
	_check("생활 · 곁에서 싸운 용", Ending.life_lines("guardian")[-1], "(산꼭대기까지 곁에서 싸워 준 티아맷하고는 요즘도 가끔 같이 사냥을 나간다.)")
	G.story.ally = "Mira"
	_check("생활 · 곁에서 싸운 용이 짝이면 안 부른다", Ending.life_lines("guardian")[-1], L.home.gathering.peace)

	# 어둠의 길: 두고 온 것들
	G.story.route = "dark"
	G.quests.done.erase("m6")
	G.quests.done.append("m7d")
	_check("어둠 · 두고 온 것들", Ending.life_lines("dark"), [L.dark.partner.replace("{partner}", "미라"), L.dark.kids, L.dark.den, L.dark.gathering])
	_check("크레딧 · 내 식구", Ending._family(), "미라 · %s · %s" % [kid.name, kid2.name])

	# 되돌린다
	for b in [baby, baby2]: b.remove = true
	G.kids.clear()
	G.partner = null
	G.story.erase("love")
	G.story.erase("ally")
	G.story.erase("route")
	G.denDecor = []
	_check("크레딧 · 식구가 없으면 빈 칸", Ending._family(), "")


# ---- 처음 하는 사람 안내 ----
# 안내 하나씩 조건을 세우고 Tutorial.update() 를 곧바로 부른다 (그사이 프레임이 돌지 않게). 다른 안내는 본 것으로 둔다
func _guide() -> void:
	var G := GameState
	var t: Dictionary = G.tutorial
	var p = G.player
	G.quests.done = ["m0"]
	G.quests.active = { m1 = { step = 0, n = 0 } }
	G.quests.tracked = "m1"
	G.quests.choices = {}
	G.story.scenes.erase("ch1")
	G.dayTime = 0.4
	G.bannerUntil = 0
	t.ate = true

	# 구경 없이 시작한 판(시험 장면)은 조용하다
	_only(["clue"])
	t.toured = false
	G.story.clues = ["mark"]
	t.erase("tab_record")
	Tutorial.update()
	_check("구경 전 · 안내가 조용하다", [DialogueBox.is_open(), t.hints.has("clue")], [false, false])
	G.story.clues = []

	# 구경 도중에 저장한 판을 불러왔다: 포코가 처음부터 다시 데리고 돈다
	G.quests.active = { m0 = { step = 1, n = 0 } }
	G.elderTutorialDone = true
	G.tour = null
	Tour.update(0.016)
	_check("구경 도중 불러옴 · 다시 돈다", G.tour != null, true)
	_check("구경 도중 불러옴 · 포코를 따라가자", _popped("포코를 따라가자"), true)
	G.tour = null
	G.quests.active = { m1 = { step = 0, n = 0 } }
	t.toured = true

	# 마을 구경 중 한 번도 안 걸었다: 포코 말풍선 + 걷는 법
	_only(["move"])
	t.moved = false
	G.tour = { i = 0, phase = "walk", nag = 3.0 }
	var poco = _summon("Poco")
	Tutorial.update()
	_check("구경 · 포코 말풍선", poco.current_chat, "왜 가만히 있어? 이쪽이야, 이쪽!")
	_check("구경 · 걷는 법 알림", _popped("[WASD]로 걷는다"), true)
	G.tour = null
	t.moved = true

	# 첫 일거리를 해 지기 전에 끝냈다: 안내가 멈추지 않고 첫 밤에 잠자리를 알려 준다
	G.quests.done = ["m0", "m1"]
	G.quests.active = {}
	G.quests.tracked = null
	t.finished = false
	_only(["dusk"])
	G.dayTime = 0.8
	_alone(true)
	Tutorial.update()
	_alone(false)
	_check("m1 을 끝내면 finished (촌장 일과가 본다)", t.finished, true)
	_check("해 질 녘 · 곁에 아무도 없으면 알림만", _popped("해가 진다. 마을 서쪽 내 굴 잠자리 앞에서"), true)
	_only(["dusk"])
	poco.is_hidden = true   # 포코가 먼저다. 티아맷의 말을 보려고 잠깐 감춘다
	_summon("Tiamat")
	Tutorial.update()
	_check("해 질 녘 · 곁의 티아맷이 말을 건다", _said(), "티아맷 | 해 지면 들어가. 밤은 내가 볼게.")
	_close()
	_check("해 질 녘 · 말 뒤에 알림", _popped("🌙 마을 서쪽 내 굴 잠자리 앞에서 [Space]로 잔다."), true)
	G.dayTime = 0.4

	# 나뭇가지: 포코를 만날 때까지 기다린다
	_only(["twig"])
	G.den.twigs = 2
	G.den.built = false
	poco.is_hidden = true
	Tutorial.update()
	_check("나뭇가지 · 포코가 곁에 없으면 기다린다", [DialogueBox.is_open(), t.hints.has("twig")], [false, false])
	_summon("Poco")
	Tutorial.update()
	_check("나뭇가지 · 포코가 말을 건다", _said().begins_with("포코 | 어, 나뭇가지 주웠네!"), true)
	_close()
	_check("나뭇가지 · 둥지 짓는 법 알림", _popped("나뭇가지 8개와 30G를 모아"), true)

	# 성장 포인트: 둘째 날부터 카이론이. 스스로 성장 탭을 열어 봤으면 나오지 않는다
	_only(["growth"])
	G.growth.points = 3
	G.day = 2
	t.erase("tab_growth")
	_summon("Kairon")
	Tutorial.update()
	_check("성장 · 카이론이 말을 건다", _said().ends_with("어디를 키울지는 네가 정해라."), true)
	_close()
	_check("성장 · 성장 나무 알림", _popped("[G] 성장 나무에서 쓴다"), true)
	_only(["growth"])
	Hud.current.journal.toggle_tab("growth")
	Hud.current.journal.close()
	Tutorial.update()
	_check("성장 · 탭을 열어 봤으면 안 나온다", [t.get("tab_growth", false), DialogueBox.is_open(), t.hints.has("growth")], [true, false, false])

	# 넷째 기술
	_only(["skill4"])
	var skills: Array = p.skills.duplicate()
	p.skills = ["TAIL_SWIPE", "ROAR", "METEOR", "WING_GUST"]
	t.erase("tab_skills")
	Tutorial.update()
	_check("기술 넷 · 카이론이 말을 건다", _said(), "카이론 | 기술은 한 번에 셋까지만 몸에 붙는다. 뭘 쓸지는 네가 골라라.")
	_close()
	_check("기술 넷 · 스킬 나무 알림", _popped("[K] 스킬 나무에서"), true)
	p.skills = skills

	# 유물: 그론. 그론이 떠난 뒤에는 알림만
	_only(["relic"])
	G.relics = [Relics.table().keys()[0]]
	t.erase("tab_relics")
	var gron = _summon("Gron")
	Tutorial.update()
	_check("유물 · 그론이 말을 건다", _said().begins_with("그론 | 야, 그 반짝이는 거"), true)
	_close()
	_only(["relic"])
	G.story.dead = ["Gron"]
	gron.is_hidden = true
	Tutorial.update()
	_check("유물 · 그론이 떠났으면 알림만", [DialogueBox.is_open(), _popped("유물은 [J] 일지 [유물]에서")], [false, true])
	G.story.dead = []
	gron.is_hidden = false

	# 첫 단서: 내 속말
	_only(["clue"])
	G.story.clues = ["mark"]
	t.erase("tab_record")
	Tutorial.update()
	_check("단서 · 내 속말", _said().ends_with("(이상한 일이 자꾸 생긴다. 잊기 전에 적어 두자.)") or _said().ends_with("이상한 일이 자꾸 생긴다. 잊기 전에 적어 두자."), true)
	_close()
	_check("단서 · 기록 탭 알림", _popped("[J] 일지 [기록]"), true)

	# 둘째 석비: 포코
	_only(["waystone"])
	var stones: Array = G.waystones.duplicate()
	G.waystones = ["VILLAGE", "EAST_ROAD"]
	t.erase("tab_map")
	_summon("Poco")
	Tutorial.update()
	_check("석비 · 포코가 말을 건다", _said().contains("돌에 손만 얹으면 거기로 슝"), true)
	_close()
	G.waystones = stones

	# 성체: 날기 (누리 사건 뒤) · 첫 밤
	_only(["fly"])
	p.stage_index = Story._adult()
	t.erase("flew")
	Tutorial.update()
	_check("날기 · 알림", _popped("[Z]로 날아오른다"), true)
	p.flying = true
	Tutorial.update()
	p.flying = false
	_check("날기 · 날아 봤으면 적어 둔다", t.get("flew", false), true)
	_only(["night"])
	G.dayTime = 0.95
	_alone(true)
	Tutorial.update()
	_alone(false)
	_check("성체 첫 밤 · 아무도 없으면 알림만", _popped("이제 아무도 재우러 오지 않는다"), true)
	_only(["night"])
	_summon("Kairon")
	Tutorial.update()
	_check("성체 첫 밤 · 카이론", _said().ends_with("자는 것도 수련이다."), true)
	_close()
	G.dayTime = 0.4
	p.stage_index = 0

	# 첫 아이: 엘더 · 가족 창을 열면 적어 둔다
	_only(["kid"])
	var baby := BabyDragon.make(p.x + 40, p.y + 30, Kids.mix_genes(p, null))
	World.add_entity("babies", baby)
	Kids.register(baby)
	t.erase("kids_panel")
	_summon("Elder")
	Tutorial.update()
	_check("아이 · 엘더가 말을 건다", _said().begins_with("엘더 | 허허, 네 아이로구나."), true)
	_close()
	_check("아이 · 가족 창 알림", _popped("[P] 가족 창에서"), true)
	Hud.current.kids.toggle()
	Tutorial.update()
	Hud.current.kids.toggle()
	_check("아이 · 가족 창을 열어 봤다", t.get("kids_panel", false), true)

	# 첫 장을 끝냄: 내 속말 · 지금까지 이야기
	_only(["story"])
	G.quests.done = ["m0", "m1", "m2"]
	t.erase("tab_story")
	Tutorial.update()
	_check("첫 장 · 내 속말", _said().contains("있었던 일을 일지에 적어 두자"), true)
	_close()
	_check("첫 장 · 지금까지 이야기 알림", _popped("[J] 일지 [지금까지 이야기]에 쌓인다"), true)

	# 찾아갈 용이 딴 지도에: 포코가 어디 있는지 알려 준다
	_only(["folk"])
	G.quests.done = ["m0", "m1"]
	G.quests.active = { m2 = { step = 0, n = 0 } }
	G.quests.tracked = "m2"
	t.erase("tab_folk")
	for h in range(6, 21):   # 카이론이 마을 밖에 있는 때로
		G.dayTime = h / 24.0
		if Routine.plan_for("Kairon") and Routine.plan_for("Kairon").map != G.map_id: break
	var where: String = Routine.plan_for("Kairon").mapName.trim_prefix("카이론의 ")
	_summon("Poco")
	Tutorial.update()
	_check("찾아갈 용 · 포코가 말을 건다", _said(), "포코 | 카이론 할아버지 찾아? 이 시간엔 %s에 있어!" % where)
	_close()
	_check("찾아갈 용 · 마을 용들 탭 알림", _popped("[J] 일지 [마을 용들]"), true)
	G.dayTime = 0.4

	# 틈: 하나를 띄우면 12초 동안 다음 안내는 기다린다
	_only(["clue", "fly"])
	G.story.clues = ["mark"]
	t.erase("tab_record")
	p.stage_index = Story._adult()
	t.erase("flew")
	Tutorial.update()
	_close()
	var shown: bool = t.hints.has("clue") or t.hints.has("fly")
	Tutorial.update()
	_check("틈 · 한 번에 하나만", [shown, t.hints.has("clue") and t.hints.has("fly")], [true, false])
	p.stage_index = 0

	# 며칠 쉬었다 돌아옴: 첫 장을 끝냈으면 지난 이야기를 일깨운다
	_only([])
	var now := Time.get_unix_time_from_system()
	for case in [
		{ what = "나흘 만 · 1장 끝냄", last = now - 4 * 86400, done = ["m0", "m1", "m2"], want = true },
		{ what = "한 시간 만", last = now - 3600, done = ["m0", "m1", "m2"], want = false },
		{ what = "나흘 만 · 1장 전", last = now - 4 * 86400, done = ["m0"], want = false },
	]:
		_clear()
		G.quests.done = case.done
		t.lastPlayed = case.last
		Tutorial._greeted = false
		Tutorial.update()
		_check("돌아옴 · %s" % case.what, _popped("지난 이야기는 [J] 일지의 [지금까지 이야기]"), case.want)

	# 퀘스트 · 도움말
	_check("m2 · 레벨 오르는 법", Quests.by_id("m2").steps[1].hint.contains("게시판 잡일을 하면 오른다"), true)
	var col: Node = Hud.current.help.get_node("Frame/Lines/Body/Scroll/Columns/Col2")
	_check("도움말 · 새 줄", ["Row16", "Row17", "Row18", "Row19"].map(func(r): return col.get_node(r + "/Key").text), ["둥지", "잠", "석비", "지난 이야기"])


## 이 안내들 말고는 다 본 것으로 둔다 (다른 안내가 끼어들지 않게). 틈과 알림도 비운다
func _only(ids: Array) -> void:
	GameState.tutorial.hints = {}
	for h in Tutorial._hints():
		if not ids.has(h.id): GameState.tutorial.hints[h.id] = true
	Tutorial._next_at = 0.0
	_clear()


## 그 용을 지금 지도의 내 곁에 세운다 (마을 구경의 포코처럼)
func _summon(nm: String):
	var p = GameState.player
	var e = World.any_npc(nm)
	e.x = p.x + 70; e.y = p.y
	e.remove = false; e.is_hidden = false; e.down_timer = 0.0
	if not GameState.entities.npcs.has(e): World.add_entity("npcs", e)
	return e


## 곁에 아무도 없는 것처럼 (on) · 되돌린다 (off)
var _hidden := []
func _alone(on: bool) -> void:
	if on:
		_hidden = GameState.entities.npcs.filter(func(n): return not n.is_hidden)
		for n in _hidden: n.is_hidden = true
	else:
		for n in _hidden: n.is_hidden = false
		_hidden = []


func _said() -> String:
	if not DialogueBox.is_open(): return ""
	return "%s | %s" % [DialogueBox.current._name.text, DialogueBox.current.shown_text()]


## 떠 있는 대화를 끝까지 넘긴다
func _close() -> void:
	for i in 5:
		if not DialogueBox.is_open(): return
		DialogueBox.current._text.visible_characters = -1
		DialogueBox.current._choose(0)


func _popped(bit: String) -> bool:
	var all: Array = Hud.current._toast_wait.duplicate()
	for c in Hud.current._toasts.get_children(): all.append(c.get_node("Label").text)
	return all.any(func(x): return x.contains(bit))


func _clear() -> void:
	Hud.current._toast_wait.clear()
	for c in Hud.current._toasts.get_children():
		Hud.current._toasts.remove_child(c)
		c.queue_free()


# ---- 일지 · 지금까지 이야기 ----
func _story_tab() -> void:
	var G := GameState
	var main_done := ["m0", "m1", "m2", "m3", "m4", "m5", "m5g", "m5a", "m6w", "m5b", "m5c"]
	G.story.events.erase("ev_first_night")
	G.story.events.erase("ev_messenger")

	# 새 판: 지금 장(1장)과 지금 할 일만
	G.quests.done = []
	G.quests.active = { m0 = { step = 1, n = 0 } }
	G.quests.tracked = "m0"
	var s := _story()
	_check("처음 · 장 머리", s.heads, ["1장 · 웨스턴 마을"])
	_check("처음 · 요약 줄 없음", s.paras.size(), 0)
	_check("처음 · 지금 할 일은 추적 중인 퀘스트", s.now.begins_with("지금 할 일 · 낯선 아침 | 눈을 떠 보니"), true)

	# 1장을 끝냄 (쇠붙이가 뭐냐고 물었다): 최근 장이 위, 고른 줄만
	G.quests.done = ["m0", "m1", "m2"]
	G.quests.choices = { m1 = "ask" }
	G.quests.active = { m3 = { step = 0, n = 0 } }
	G.quests.tracked = "m3"
	s = _story()
	_check("1장 뒤 · 최근 장이 위", s.heads, ["2장 · 나팔 소리", "1장 · 웨스턴 마을"])
	_check("1장 뒤 · 물어본 줄", _has(s, "인간이 놓는 덫"), true)
	_check("1장 뒤 · 안 물은 줄은 없다", _has(s, "말없이 품에"), false)
	_check("1장 뒤 · 못 본 첫 밤은 없다", _has(s, "긴 울음"), false)
	G.story.events.append("ev_first_night")
	s = _story()
	_check("1장 뒤 · 본 첫 밤은 있다", _has(s, "긴 울음"), true)
	_check("1장 뒤 · 지금 할 일", s.now.begins_with("지금 할 일 · 나팔 소리"), true)

	# 맡은 일이 없으면 다음에 할 만한 일
	G.quests.active = {}
	G.quests.tracked = null
	s = _story()
	_check("맡은 일 없음 · 머리에 퀘스트 이름이 없다", s.now.begins_with("지금 할 일 | "), true)

	# 3장 반쯤 (모르가스만 보냄): 3장은 한 번만, 앞 칸 요약 + 지금 할 일
	G.quests.done = ["m0", "m1", "m2", "m3"]
	G.bossesDefeated = { MORGATH = true }
	G.quests.active = { m4 = { step = 1, n = 0 } }
	G.quests.tracked = "m4"
	s = _story()
	_check("3장 반 · 3장 머리는 하나", s.heads.count("3장 · 골짜기의 옛 수호룡"), 1)
	_check("3장 반 · 맨 위가 3장", s.heads[0], "3장 · 골짜기의 옛 수호룡")
	_check("3장 반 · 모르가스 줄", _has(s, "모르가스가 일어났다"), true)
	_check("3장 반 · 폭포 줄은 아직", _has(s, "폭포 길이 녹았다"), false)
	_check("3장 반 · 지금 할 일", s.now.begins_with("지금 할 일 · 골짜기의 옛 수호룡"), true)

	# 끝까지. 길마다 제 줄만, 맨 위에는 결말 알림
	G.bossesDefeated = { MORGATH = true, ZALGORA = true, GLACIA = true, BASIL = true, IGNAR = true }
	G.story.dead = ["Gron"]
	G.quests.active = {}
	G.quests.tracked = null
	G.quests.choices = { m1 = "ask", m3 = "wait", s1 = "tell", m5b = "wall" }
	for route in ["guardian", "redeem", "dark"]:
		G.quests.done = main_done + (["m7d"] if route == "dark" else ["m6"])
		G.story.route = route
		G.story.endingSeen = route
		s = _story()
		_check("%s · 맨 위는 결말 알림" % route, s.paras[0].begins_with("결말을 보았다"), true)
		_check("%s · 장 여덟" % route, s.heads.size(), 8)
		_check("%s · 지금 할 일 없음" % route, s.now, "")
		_check("%s · 수호룡 줄" % route, _has(s, "이 마을의 수호룡"), route == "guardian")
		_check("%s · 호숫가 빈 굴 줄" % route, _has(s, "호숫가 빈 굴"), route == "redeem")
		_check("%s · 잿마루의 일부 줄" % route, _has(s, "잿마루의 일부"), route == "dark")
	_check("고른 것 · 미라에게 촌장님은 아셔야 한다", _has(s, "촌장님은 아셔야"), true)
	_check("고른 것 · 창은 벽에", _has(s, "빈 못 세 개에 걸었다"), true)
	_check("고른 것 · 창은 무덤 곁이 아니다", _has(s, "묻힌 자리 옆에"), false)
	_check("못 본 밤손님은 없다", _has(s, "잿빛 비늘의 낯선 용"), false)
	_check("떠난 그론 · 화덕의 불", _has(s, "화덕의 불이 처음으로 꺼졌다"), true)
	G.story.dead = []
	s = _story()
	_check("그론이 살아 있으면 · 화덕 줄 없음", _has(s, "화덕의 불이 처음으로 꺼졌다"), false)
	G.story.erase("route")
	G.story.erase("endingSeen")


## 일지를 [지금까지 이야기] 탭으로 그리고, 보이는 것을 모은다 { heads, paras, now }
func _story() -> Dictionary:
	var j: JournalPanel = Hud.current.journal
	j.tab = "story"
	j.render()
	var out := { heads = [], paras = [], now = "" }
	for c in j._list.get_children():
		if c is JournalSection: out.heads.append(c.get_node("Title").text)
		elif c is PanelContainer: out.now = "%s | %s" % [c.get_node("Lines/Head").text, c.get_node("Lines/Text").text]
		elif c is Label: out.paras.append(c.text)
	return out


func _has(s: Dictionary, bit: String) -> bool:
	return s.paras.any(func(t): return t.contains(bit))


func _check(what: String, got, want) -> void:
	var ok: bool = str(got) == str(want)
	if not ok: _bad += 1
	print("%s %s  (%s%s)" % ["OK  " if ok else "틀림", what, str(got), "" if ok else " · 기대 %s" % str(want)])
