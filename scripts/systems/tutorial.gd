class_name Tutorial
## 2D판 systems/tutorial.js. 처음 하는 사람 안내.
## 지금 뭘 해야 하는지는 1장의 퀘스트(m0 → m1 → 오늘의 수련)가 추적창에서 알려 주고,
## 키와 창은 그 일이 처음 쓸모 있어지는 순간에 한 번씩만 알려 준다.
## 알맞은 용이 곁에 있으면 그 용이 먼저 말을 걸고(대화창 한 줄, 컷씬 없이), 조작은 알림으로 덧붙인다.
## 그 용을 만날 때까지 기다리는 안내는, 그 전에 스스로 해 버리면(탭을 열었다 · 둥지를 지었다) 나오지 않는다.
## 첫 일거리 전의 조작 안내(early)와 마을 구경 중의 안내(touring) 말고는 포코의 마을 구경을 마친 판에서만 나온다
## (구경 없이 시작하는 시험 장면 · 촬영 판은 조용하다).
##
## GameState.tutorial = { moved, ate, toured, finished, flew, kids_panel, tab_<일지 탭>, lastPlayed, hints: { id: true } }
##   finished: 첫 일거리(m1)를 끝냈다. 촌장의 일과가 이걸 본다 (Routine). 안내는 그 뒤로도 돈다

const GAP := 12.0            # 안내끼리 띄우는 틈 (초). 한꺼번에 쏟아지지 않게
const NEAR := 420.0          # 이만큼 가까이(화면 안) 있어야 그 용이 말을 건다
const AWAY := 3 * 24 * 3600  # 이만큼(초) 쉬었다 돌아오면 지난 이야기가 어디 있는지 일깨운다
## 포코가 마을 어른들을 부르는 말 (마을 구경 · 연애 대사와 같게). 없으면 이름만
const POCO_CALLS := { "Elder": "할아버지", "Kairon": "할아버지", "Gron": "아저씨", "Dan": "아저씨", "Doran": "아저씨",
	"Soi": "아줌마", "Miru": "아줌마", "Tiamat": "누나", "Nara": "누나", "Ember": "누나", "Mira": "누나", "Seiran": "누나" }

static var _all := []
static var _next_at := 0.0
static var _last_play := 0.0
static var _greeted := false
static var _stamped_at := 0.0


## 안내 하나: { id, icon, when(s), text }
##   who: 말을 걸 용들 (곁에 있는 첫 용) · say: { 용 이름: 대사 } · me: 내 속말 한 줄 (대화창)
##   early: 첫 일거리 전에만 · touring: 마을 구경 중에도 · urgent: 때가 급하다. 곁에 그 용이 없으면 기다리지 않고 알림만 (alone 이 있으면 그 글로)
##   bubble: 대화창 대신 그 용 머리 위 말풍선 (마을 구경 중)
static func _hints() -> Array:
	if not _all.is_empty(): return _all
	_all = [
		{ id = "fight", icon = "🔥", early = true,
		  when = func(s): return s.map_id != "VILLAGE" and s.entities.enemies.any(func(e): return e.type != "PREY" and Util.dist(e, s.player) < 420),
		  text = "마우스로 겨누고 클릭하면 브레스가 나간다. 꾹 누르면 계속 나가고, [Shift]로 피한다." },
		{ id = "dummy", icon = "🎯", early = true,
		  when = func(s): return s.map_id == "VILLAGE" and s.entities.enemies.any(func(e): return e.type == "DUMMY"),
		  text = "허수아비를 마우스로 겨누고 클릭. 꾹 누르면 계속 나간다. [Shift]를 탁 누르면 대시로 피한다." },
		{ id = "eat", icon = "🍖",
		  when = func(s): return not s.tutorial.get("ate") and s.player.hunger < 60 and s.player.inventory.meat > 0,
		  text = "배가 고프다. [C]로 고기를 먹는다." },
		# 마을 구경: 포코가 "이쪽이야!" 하고 부르는데 한 번도 안 걸었다
		{ id = "move", icon = "👣", who = ["Poco"], bubble = true, touring = true,
		  when = func(s): return s.tour != null and float(s.tour.get("nag", 0.0)) > 0 and not s.tutorial.get("moved"),
		  say = { Poco = "왜 가만히 있어? 이쪽이야, 이쪽!" },
		  text = "[WASD]로 걷는다." },
		# 첫 잠 전의 밤. 첫 일거리를 해 지기 전에 끝내도 나온다 (스승을 소개받는 둘째 날 아침 장면 ch1 이 첫 잠의 표시)
		{ id = "dusk", icon = "🌙", who = ["Poco", "Tiamat", "Elder"], urgent = true,
		  when = func(s): return not s.story.get("scenes", []).has("ch1") and not s.quests.active.has("m1n") and (s.dayTime > 0.78 or s.dayTime < 0.2),
		  say = { Poco = "해 진다! 애들은 밤에 돌아다니면 안 된대. 너도 얼른 네 굴 가서 자.",
			Tiamat = "해 지면 들어가. 밤은 내가 볼게.",
			Elder = "벌써 해가 지는구나. 오늘은 네 굴에 들어가 푹 자거라." },
		  text = "마을 서쪽 내 굴 잠자리 앞에서 [Space]로 잔다.",
		  alone = "해가 진다. 마을 서쪽 내 굴 잠자리 앞에서 [Space]로 잔다." },
		# 성체가 되고 처음 맞는 밤. 어릴 때처럼 누가 재워 주지 않는다 (Story.update_bedtime)
		{ id = "night", icon = "🌙", who = ["Kairon", "Elder", "Tiamat"], urgent = true,
		  when = func(s): return s.player.stage_index >= Story._adult() and (s.dayTime >= Story.BEDTIME or s.dayTime < 0.2),
		  say = { Kairon = "이제 어른이다. 재워 주는 이 없으니 잠도 네가 알아서 자라. 자는 것도 수련이다.",
			Elder = "이제 다 컸다고 재우러 다니지는 않으마. 허나 잠은 꼭 챙겨 자거라.",
			Tiamat = "이제 너 재우러 안 다닌다. 알아서 들어가 자." },
		  text = "졸리면 내 굴 잠자리 앞에서 [Space]로 잔다. 자고 일어나야 다음 수련도 받는다.",
		  alone = "이제 아무도 재우러 오지 않는다. 졸리면 내 굴 잠자리 앞에서 [Space]로 잔다. 자고 일어나야 다음 수련도 받는다." },
		{ id = "twig", icon = "🪹", who = ["Poco"],
		  when = func(s): return int(s.den.get("twigs", 0)) > 0 and not s.den.get("built", false),
		  say = { Poco = "어, 나뭇가지 주웠네! 그거 여덟 개 모으면 네 굴 잠자리를 진짜 둥지로 짤 수 있어. 둥지가 있어야 알도 품는대!" },
		  text = "나뭇가지 8개와 30G를 모아, 내 굴 잠자리 앞에서 [Space] → [둥지를 짓는다]." },
		{ id = "growth", icon = "🌟", who = ["Kairon"],
		  when = func(s): return int(s.growth.get("points", 0)) >= 2 and s.day >= 2 and not s.tutorial.get("tab_growth"),
		  say = { Kairon = "몸에 힘이 붙었는데 쌓아 두기만 하냐. 송곳니를 갈든 비늘을 굳히든 날개를 다듬든, 어디를 키울지는 네가 정해라." },
		  text = "성장 포인트는 [G] 성장 나무에서 쓴다. 왼쪽 위 🌟 줄을 눌러도 된다." },
		{ id = "skill4", icon = "📖", who = ["Kairon"],
		  when = func(s): return s.player.skills.size() > Data.get_module("skills").SKILL_SLOTS.size() and not s.tutorial.get("tab_skills"),
		  say = { Kairon = "기술은 한 번에 셋까지만 몸에 붙는다. 뭘 쓸지는 네가 골라라." },
		  text = "[K] 스킬 나무에서 [Q]·[F]·[R]에 끼울 스킬을 고른다." },
		{ id = "relic", icon = "💎", who = ["Gron"],
		  when = func(s): return not s.relics.is_empty() and not s.tutorial.get("tab_relics"),
		  say = { Gron = "야, 그 반짝이는 거 어디서 났냐. …좋은 물건이다. 비늘 밑에 끼워 둬야 힘이 돼. 몸이 클수록 끼울 데도 늘어나고." },
		  text = "유물은 [J] 일지 [유물]에서 끼우고 뺀다." },
		{ id = "clue", icon = "📜", me = "(이상한 일이 자꾸 생긴다. 잊기 전에 적어 두자.)",
		  when = func(s): return not s.story.get("clues", []).is_empty() and not s.tutorial.get("tab_record"),
		  text = "알게 된 것은 [J] 일지 [기록]에 적힌다." },
		{ id = "waystone", icon = "🗿", who = ["Poco"],
		  when = func(s): return s.waystones.size() >= 2 and not s.tutorial.get("tab_map"),
		  say = { Poco = "밖에서 석비 깨웠다며! 이제 돌에 손만 얹으면 거기로 슝 가는 거지? 어땠는지 나중에 얘기해 줘!" },
		  text = "깨운 곳은 [J] 일지 [지도]에 ○로 남는다." },
		# 날 수 있게 된 날. 누리가 사라진 날 엘더가 "너는 오늘부터 날 수 있지" 한다
		{ id = "fly", icon = "🪽",
		  when = func(s): return s.player.stage_index >= Story._adult() and not s.tutorial.get("flew") \
			and (s.story.get("events", []).has("ev_nuri_lost") or s.quests.done.has("m4")),
		  text = "[Z]로 날아오른다. 하늘에선 물도 벽도 못 막지만 배가 빨리 꺼진다." },
		{ id = "kid", icon = "🐣", who = ["Elder", "Miru"],
		  when = func(s): return not s.kids.is_empty() and not s.tutorial.get("kids_panel"),
		  say = { Elder = "허허, 네 아이로구나. 아이는 배고프면 보채고, 크면 제멋대로 돌아다닌단다. 자주 들여다봐 주거라.",
			Miru = "어머, 아기다! 아기는 금방 배고파해. 자주 들여다봐 줘." },
		  text = "아이들은 [P] 가족 창에서 돌본다." },
		{ id = "story", icon = "📖", me = "(여기 온 지 벌써 꽤 됐다. 있었던 일을 일지에 적어 두자.)",
		  when = func(s): return _chapter_done(0) and not s.tutorial.get("tab_story"),
		  text = "끝낸 장의 이야기는 [J] 일지 [지금까지 이야기]에 쌓인다." },
		# 본 이야기에서 찾아갈 용이 딴 지도에 있다. 포코는 누가 어디 있는지 다 안다
		{ id = "folk", icon = "📍", who = ["Poco"],
		  when = func(s): return _far_target() != "" and not s.tutorial.get("tab_folk"),
		  say = { Poco = func(): return "%s 찾아? 이 시간엔 %s에 있어!" % [_poco_call(_far_target()), _where(_far_target())] },
		  text = "누가 지금 어디 있는지는 [J] 일지 [마을 용들]에 적혀 있다." },
	]
	return _all


## 매 프레임 (대화창이 닫혀 있을 때). 조건이 맞는 안내를 하나씩, 틈을 두고 띄운다
static func update() -> void:
	var t = GameState.tutorial
	if not t or GameState.isDialogueOpen or GameState.prologue: return
	if GameState.play_time < _last_play:   # 처음 화면을 거쳐 새 판이 섰다 (시간이 0부터 다시 흐른다)
		_greeted = false
		_next_at = 0.0
	_last_play = GameState.play_time
	if not t.get("finished") and GameState.quests.done.has("m1"): t.finished = true
	_watch(t)
	# 첫 퀘스트의 허수아비: 구경을 마치고 엘더에게 돌아가면 광장에 허수아비 둘이 서 있다 (지도를 오가도 다시 선다).
	# 엘더가 가리키는 대목(셋째)부터 세워 둔다
	var m0 = GameState.quests.active.get("m0")
	if m0 and int(m0.step) >= 2 and int(m0.step) <= 3 and GameState.map_id == "VILLAGE" and not GameState.entities.enemies.any(func(e): return e.type == "DUMMY"):
		for c in [[15, 13], [18, 13]]:
			var d := Enemy.make(c[0] * 96 + 48, c[1] * 96 + 48, "DUMMY")
			d.max_hp = 30; d.hp = 30
			World.add_entity("enemies", d)
	if GameState.play_time < _next_at: return
	if not t.has("hints"): t.hints = {}
	for h in _hints():
		var due: bool = (not t.get("finished")) if h.get("early") else (h.get("touring", false) or t.get("toured", false))
		if t.hints.get(h.id) or not due or not h.when.call(GameState): continue
		if not _show(h): continue   # 말을 걸 용을 기다린다
		t.hints[h.id] = true
		_next_at = GameState.play_time + GAP
		return


## 상태값만으로는 알 수 없는 것들 (게임 곳곳에서 한 줄로 부른다)
static func mark(flag: String) -> void:
	if GameState.tutorial and not GameState.tutorial.get(flag): GameState.tutorial[flag] = true


## 상태로만 알 수 있는 것을 적어 둔다: 날아 봤는가 · 가족 창을 열어 봤는가 · 마지막으로 논 때.
## 며칠 쉬었다 돌아온 판이면 지난 이야기가 어디 있는지 한 번 일깨운다 (첫 장을 끝낸 뒤로)
static func _watch(t: Dictionary) -> void:
	if GameState.player.flying: t.flew = true
	if Hud.current and Hud.current.kids.visible: t.kids_panel = true
	var now := Time.get_unix_time_from_system()
	if not _greeted:
		_greeted = true
		if t.get("lastPlayed") != null and now - float(t.lastPlayed) >= AWAY and _chapter_done(0):
			Hud.pop("지난 이야기는 [J] 일지의 [지금까지 이야기]에서 읽을 수 있다.", "📖")
	if now - _stamped_at >= 60:
		_stamped_at = now
		t.lastPlayed = now


## 안내를 띄운다. 말을 걸 용이 있으면 그 용이 곁에 있을 때 그 용의 말로 먼저. 아직 띄울 때가 아니면 false
static func _show(h: Dictionary) -> bool:
	var toast := func(text: String): Hud.pop(text, h.icon)
	if h.has("me"):
		if not _calm(): return false
		Chronicle.play_scene(null, [{ who = "나", text = h.me }], func(): toast.call(h.text), false)
		return true
	var who: Array = h.get("who", [])
	if who.is_empty():
		toast.call(h.text)
		return true
	var npc = _speaker(who, not h.get("bubble", false))
	if npc == null:
		# 곁에 없다. 때가 급한 안내이거나 말할 용이 다 떠났으면 알림만
		if h.get("urgent") or who.all(func(n): return Routine.is_dead(n)):
			toast.call(h.get("alone", h.text))
			return true
		return false
	var line = h.say[npc.config.name]
	if line is Callable: line = line.call()
	if h.get("bubble"):
		npc.say(line)
		toast.call(h.text)
		return true
	if not _calm(): return false
	npc.emote("!")
	Chronicle.play_scene(null, [{ who = npc.config.name, text = line }], func(): toast.call(h.text), false)
	return true


## 이 지도에 나와 있는 용 가운데 names 순서로 첫 용. near 면 가까이(화면 안) 있어야 한다
static func _speaker(names: Array, near: bool):
	var p = GameState.player
	for nm in names:
		for n in GameState.entities.npcs:
			if n.config.get("name") != nm or n.remove or n.is_hidden or n.down_timer > 0: continue
			if near and Util.dist(n, p) > NEAR: continue
			return n
	return null


## 용이 말을 걸어도 되는 때: 장면 · 싸움 · 습격 · 놀이 · 마을 구경 · 열린 창이 없고, 지역 이름도 걷혔다
static func _calm() -> bool:
	var s := GameState
	return not Cutscene.on and not s.activity and not s.raid.active and s.tour == null and not Ending.playing \
		and not Chronicle._playing and s.questScenes.is_empty() and not Combat.in_fight() and not GamePanel.any_open() \
		and not (s.bannerUntil and s.play_time < s.bannerUntil)


static func _chapter_done(i: int) -> bool:
	return Data.get_module("chapters").CHAPTERS[i].done.call(GameState)


## 추적 중인 본 이야기에서 말을 걸러 가야 할 용이 딴 지도에 있으면 그 용 이름. 아니면 ""
static func _far_target() -> String:
	var q = Quests.tracked_quest()
	if not q or q.act != "main" or Quests.is_complete(q): return ""
	var g: Dictionary = Quests.cur_step(q).goal
	if (g.type != "talk" and g.type != "bring") or g.target == "Poco": return ""
	var plan = Routine.plan_for(g.target)
	return g.target if plan and plan.map != GameState.map_id else ""


static func _poco_call(nm: String) -> String:
	return "%s %s" % [Names.npc(nm), POCO_CALLS[nm]] if POCO_CALLS.has(nm) else Names.npc(nm)


## 그 용이 지금 있는 곳. 제 이름이 붙은 곳은 이름을 뗀다 ("카이론의 수련장" → "수련장")
static func _where(nm: String) -> String:
	return Routine.plan_for(nm).mapName.trim_prefix(Names.npc(nm) + "의 ")
