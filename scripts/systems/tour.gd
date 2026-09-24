class_name Tour
## 2D판 systems/tour.js. 첫날, 포코가 마을을 데리고 돈다.
##
## 나를 처음 발견한 포코가 앞장서서 마을을 한 바퀴 돈다. 집집마다 누가 사는지 알려 주고, 마지막에 내 굴 앞에서 끝난다.
## 그 집 용이 마을에 나와 있으면 한마디 거든다 (line.here — 없으면 그 줄은 건너뛴다).
## 다 돌면 퀘스트 m0 의 '마을을 둘러본다' 대목이 넘어가고, 엘더에게 돌아가면 첫 일거리를 받는다.
##
## GameState.tour = { i: 몇 번째 자리, phase: 'walk' | 'talk' }

const GUIDE := "Poco"
const RUN := 230.0   # 포코는 앞서 뛴다 (마을 용들이 일과대로 걷는 150 보다 빠르게. 내 걸음은 250 쯤)

## 광장 → 대장간 → 망루 → 누리네 → 석비 → 포코네 → 도란네 → 미라네 → 내 굴 (마을을 시계 방향으로 한 바퀴)
const STOPS := [
	{ at = [17, 11], stand = [-90, 50], lines = [
		{ who = "Poco", text = "안녕! 나 포코야! 너 내가 발견했어, 내가! 별인 줄 알았는데 용이더라. 근데 용이 더 좋아, 별은 말을 못 하잖아." },
		{ who = "Poco", text = "여기가 광장이야. 네가 떨어진 데가 딱 저기거든. 봐 봐, 돌 깨진 거 보이지? 그론 아저씨가 그것 때문에 사흘째 투덜대고 있어." },
		{ who = "Poco", text = "샘물은 아무나 마셔도 돼. 나는 여기서 물장난 치다가 맨날 혼나지만.", look = "PROP:FOUNTAIN", label = "광장의 샘" },
		{ who = "Poco", text = "저 판때기는 게시판이야. 어른들이 심부름을 쪽지로 붙여 놓는 덴데, 하고 싶은 것만 떼어 가면 된대.", look = "PROP:BOARD", label = "게시판" },
		{ who = "Poco", text = "저 위에 제일 큰 집이 엘더 할아버지네. 아까 만났지? 할아버지는 이 마을에서 제일 오래 살았대. 삼백 년이나!", look = "DEN:DEN_ELDER", label = "엘더의 집", do = [{ cam = "look:DEN:DEN_ELDER", time = 1.2 }] },
		{ who = "Poco", text = "이제 한 바퀴 돌자! 누가 어디 사는지 내가 다 알려 줄게.", do = [{ cam = "auto", time = 0.8 }] },
	] },
	{ at = [22, 7], stand = [-70, 60], via = [[19, 12]], lines = [
		{ who = "Poco", text = "여긴 그론 아저씨 대장간! 숲에서 주운 걸 갖다주면 아저씨가 비늘을 단단하게 해 줘.", look = "DEN:DEN_GRON", label = "대장간 · 그론" },
		{ who = "Poco", text = "옆에 있는 누나는 엠버 누나야. 아저씨 조수인데 맨날 혼나.", look = "Ember", label = "조수 · 엠버", here = "Ember" },
		{ who = "Gron", text = "뭘 봐. 살 거 아니면 가라.", here = "Gron" },
		{ who = "Poco", text = "(작게) 무섭게 생겼지? 근데 있잖아, 나 나팔 소리 나면 맨날 여기 와서 숨거든. 아저씨가 나가라고 한 적 한 번도 없어.", here = "Gron" },
		{ who = "Gron", text = "다 들린다.", here = "Gron" },
	] },
	{ at = [30, 8], stand = [-90, 50], via = [[22, 12], [30, 12]], lines = [
		{ who = "Poco", text = "저 높은 건 망루야. 티아맷 누나가 밤새 저 위에서 마을을 지켜. 사냥꾼이 오면 제일 먼저 나팔을 부는 것도 누나야.", look = "PROP:TOWER", label = "망루" },
		{ who = "Poco", text = "옆에 있는 게 누나네 집인데, 누나는 집에 거의 안 있어. 맨날 순찰만 돌아.", look = "DEN:DEN_TIAMAT", label = "티아맷의 집", do = [{ cam = "look:DEN:DEN_TIAMAT", time = 0.9 }] },
		{ who = "Tiamat", text = "…포코. 또 새로 온 애 끌고 다니냐. 해 지기 전엔 들여보내.", here = "Tiamat", do = [{ cam = "auto", time = 0.8 }] },
		{ who = "Poco", text = "(작게) 봤지? 저래 보여도 나 넘어지면 제일 먼저 달려와.", here = "Tiamat" },
	] },
	{ at = [25, 19], stand = [-110, 40], via = [[30, 12], [25, 12], [25, 17]], lines = [
		{ who = "Poco", text = "여긴 누리네! 단 아저씨는 나무꾼이라 낮에는 숲에 가 있고, 소이 아줌마는 누리 비늘 닦아 주느라 맨날 바빠.", look = "PROP:HOUSE", label = "단 · 소이 · 누리네" },
		{ who = "Soi", text = "어머, 포코가 또 손님을 데려왔네. 오다가다 배고프면 들러. 우리 집 문은 늘 열려 있어.", here = "Soi" },
		{ who = "Nuri", text = "포코 형! 얘가 하늘에서 떨어졌다는 애야? 우와, 날개 진짜 크다!", here = "Nuri" },
		{ who = "Poco", text = "누리는 나보다 어려. 그래서 나를 형이라고 불러. 헤헤.", here = "Nuri" },
	] },
	{ at = [17, 16], stand = [60, 40], via = [[25, 17], [25, 12], [21, 12]], lines = [
		{ who = "Poco", text = "이 돌은 옛날 용들이 세운 거래. 손을 얹으면 막 빛나는데, 밖에 있는 똑같은 돌들도 깨워 놓으면 돌에서 돌로 슝 하고 갈 수 있대.", look = "PROP:WAYSTONE", label = "이동 석비" },
		{ who = "Poco", text = "난 안 써 봤어. 밖에 안 나가거든. …밖은 좀, 그래. 무서운 거 많아." },
	] },
	{ at = [12, 20], stand = [60, 20], via = [[13, 15], [12, 17], [13, 18]], lines = [
		{ who = "Poco", text = "짜잔, 여기가 내 집! 작지? 근데 나한테는 딱 맞아. 비 오는 날 안에서 빗소리 들으면 진짜 좋아.", look = "PROP:HUT", label = "포코의 집" },
		{ who = "Poco", text = "근데 나팔이 울리면 여기 말고 그론 아저씨 대장간으로 뛰어가. 거기가 제일 튼튼하거든." },
	] },
	{ at = [8, 11], stand = [-40, 50], via = [[13, 18], [12, 17], [12, 12]], lines = [
		{ who = "Poco", text = "여긴 도란 아저씨랑 미루 아줌마네! 아저씨는 낚시꾼이라 낮에는 호수에 가 있어. 아줌마가 말린 고기는 마을에서 제일 맛있어.", look = "PROP:HOUSE", label = "도란 · 미루네" },
		{ who = "Miru", text = "어머, 포코가 손님을 다 데려오고. 너 여기 처음이지? 배고프면 아무 때나 들러, 아줌마가 고기 구워 줄게.", here = "Miru" },
		{ who = "Doran", text = "어이구, 포코 따라다니느라 욕보는구먼. 호수 오면 낚시 하나 가르쳐 줌세.", here = "Doran" },
	] },
	{ at = [8, 5], stand = [70, 50], via = [[9, 8]], lines = [
		{ who = "Poco", text = "여긴 미라 누나네. 약초 캐는 누나야. 다치면 여기 오면 돼. 쓴 거 주는데, 먹으면 진짜 나아.", look = "PROP:HOUSE", label = "미라의 집" },
		{ who = "Mira", text = "안녕. 포코한테 붙잡혔구나. 아픈 데 있으면 참지 말고 와. …포코, 너도 무릎 까진 거 또 숨기지 말고.", here = "Mira" },
	] },
	{ at = [3, 8], stand = [90, 60], via = [[9, 8], [8, 12], [3, 12]], lines = [
		{ who = "Poco", text = "짜잔! 여기가 네 굴이야! 비어 있던 덴데 엘더 할아버지가 너한테 주래.", look = "DEN:DEN_MINE", label = "내 굴" },
		{ who = "Poco", text = "안에는 마른 풀 잠자리 하나밖에 없긴 한데, 그건 내가 깔아 놓은 거다? 나도 처음엔 풀 한 줌으로 시작했어.", look = "DEN:DEN_MINE", label = "내 굴" },
		{ who = "Poco", text = "밤 되면 안에 있는 둥지에서 자면 돼. 애들은 밤에 돌아다니면 안 된대. 티아맷 누나한테 걸리면 진짜 무서워." },
		{ who = "Poco", text = "다 봤다! 이제 할아버지한테 가 봐. 너 다 나으면 시킬 일 있다고 하셨거든." },
	] },
]


static func active() -> bool: return GameState.tour != null


## 처음 나눈 말이 끝나면 Dialogue 가 부른다
static func start() -> void:
	if GameState.tour or GameState.tutorial.get("toured"): return
	GameState.tour = { i = 0, phase = "walk", nag = 0.0 }
	Hud.pop("포코를 따라가자.", "👣")


static func _guide(): return World.any_npc(GUIDE)


static func update(dt: float) -> void:
	if not GameState.tour and _cut_short(): start()
	var t = GameState.tour
	if not t or GameState.map_id != "VILLAGE": return
	var e = _guide()
	if not e: return
	if not GameState.entities.npcs.has(e):   # 숨어서 보고 있었다
		e.x = GameState.player.x + 80; e.y = GameState.player.y
		e.remove = false; e.is_hidden = false
		World.add_entity("npcs", e)
	if t.i >= STOPS.size():
		_end()
		return
	var stop: Dictionary = STOPS[t.i]
	var base := World.at(stop.at)
	var goal := Vector2(base.x + stop.stand[0], base.y + stop.stand[1])
	var p = GameState.player

	if t.phase == "walk":
		# 길을 따라 돌아간다 — 풀밭을 가로지르면 흩어진 상자·장작에 걸린다 (stop.via: 거쳐 갈 큰 칸)
		var via: Array = stop.get("via", [])
		var vi: int = t.get("via", 0)
		var target := goal if vi >= via.size() else World.at(via[vi])
		# 포코는 앞서 뛰되, 내가 너무 뒤처지면 기다린다
		var far := Util.dist(p, e) > 380
		e.walk_to = null if far else { x = target.x, y = target.y, speed = RUN }
		e.home_x = target.x; e.home_y = target.y
		t.nag -= dt
		if far and t.nag <= 0:
			e.say("이쪽이야, 이쪽!")
			t.nag = 4.0
		# 소품에 걸려 더 못 가면 그 자리에서 이야기한다 (1.5초 제자리면 다 온 셈). 나를 기다리는 동안은 세지 않는다
		var moved := Vector2(e.x - t.get("lx", 0.0), e.y - t.get("ly", 0.0)).length()
		t.stuck = t.get("stuck", 0.0) + dt if moved < 3 and not far else 0.0
		t.lx = e.x; t.ly = e.y
		# 멀리서 걸렸더라도 3초를 못 움직이면 그 자리에서 이야기한다
		var dg := Vector2(e.x, e.y).distance_to(target)
		var arrived: bool = dg < 48 or (t.stuck > 1.5 and dg < 260) or t.stuck > 3
		if vi < via.size():   # 거쳐 가는 칸에 닿았으면 다음 칸으로
			if arrived:
				t.via = vi + 1
				t.stuck = 0.0
			return
		if arrived and Util.dist(p, e) < 200:
			t.phase = "talk"
			e.walk_to = null
			var lines: Array = stop.lines.filter(func(l): return not l.has("here") or _here(l.here))   # 집에 없는 용의 말은 건너뛴다
			Chronicle.play_scene(null, lines, func():   # 가리키는 것마다 화면이 그쪽을 본다 (line.look)
				t.i += 1
				t.phase = "walk"
				t.via = 0
				t.stuck = 0.0)


## 구경 대목(m0 의 둘째)인데 구경이 돌고 있지 않다: 구경 도중에 저장한 판을 불러왔다 (세이브는 구경을 적지 않는다).
## 그러면 포코가 처음부터 다시 데리고 돈다
static func _cut_short() -> bool:
	var m0 = GameState.quests.active.get("m0")
	return m0 != null and int(m0.step) == 1 and GameState.elderTutorialDone and not GameState.tutorial.get("toured") and not GameState.prologue


## 그 용이 지금 이 마을에 나와 있는가
static func _here(nm: String) -> bool:
	return GameState.entities.npcs.any(func(n): return n.config.get("name") == nm and not n.remove)


static func _end() -> void:
	var e = _guide()
	if e: e.walk_to = null
	GameState.tour = null
	Tutorial.mark("toured")
	Quests.notify("tour")       # m0: 마을을 둘러본다 → 허수아비 → 엘더에게 돌아간다
	Hud.pop("포코가 광장 한쪽의 허수아비를 가리킨다. 마우스로 겨누고 클릭해서 부숴 보자.", "🎯")
	Save.save_game()
