extends Node
## SKEAM 도전 과제 (docs/skeam.md): 세이브에 남는 값으로 과제를 고르는지, 새로 세는 수(낚시 · 쓰러짐 · 융합 브레스 · 잡일),
## 붉은 달, 한 번에 하나씩 알리기, 테스트 단추를 쓴 판을 본다.
##   godot --headless --path . res://tools/test_skeam.tscn

var _bad := 0
var _seen := {}   # 시험 중에 한 번이라도 열린 과제
var _main: Node


func _ready() -> void:
	Save.slot = 9   # 시험은 9번 칸을 쓴다 (사람이 쓰는 1~3번 칸을 건드리지 않게)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.play_intro = false
	_main.load_save = false
	add_child(_main)
	for i in 5: await get_tree().process_frame
	# 사건이 저절로 끼어들지 않게 모두 본 것으로 둔다
	for ev in Data.get_module("chronicle").CHRONICLE: GameState.story.events.append(ev.id)
	_sdk()
	_check("새 판에서 이룬 과제", Achievements.earned(), [])
	await _counted()
	_moon()
	_saved()
	_send()
	_tested()
	print("[끝] 틀린 곳 %d" % _bad)
	get_tree().quit()


## 웹판 index.html 머리에 SDK 를 넣는 설정 (Pages 워크플로가 이 설정으로 내보낸다)
func _sdk() -> void:
	var cfg := ConfigFile.new()
	cfg.load("res://export_presets.cfg")
	_check("웹판 머리에 SKEAM SDK", cfg.get_value("preset.0.options", "html/head_include", ""),
		'<script src="https://kh32-7.github.io/skeam/skeam-sdk.js"></script>')


## 새로 세는 수: 실제로 그 일을 하면 하나씩 는다
func _counted() -> void:
	var p = GameState.player
	p.fishing = { x = p.x, y = p.y - 100, wait = 0.0, bite = 0.5 }   # 입질이 온 찌
	p.interact()
	_check("입질 때 당기면 물고기 하나", GameState.stats.get("fish", 0), 1)
	p.elements = ["FIRE", "ICE", "THUNDER"]
	p.ult = 100
	p.use_ultimate()
	_check("융합 브레스를 쏘면 하나", GameState.stats.get("fusions", 0), 1)
	p.beam = null
	p.elements = ["FIRE"]
	p.invuln = 0.0
	p.take_damage(99999)
	for i in 5: await get_tree().process_frame
	_check("쓰러지면 하나", GameState.stats.get("downs", 0), 1)
	var ch = Chores._by_id("c_slime")
	Chores._c().taken[ch.id] = 6
	Chores._pay_out(ch)
	Dialogue.close()   # 값을 받으면 게시판이 다시 열린다
	_check("잡일 값을 받으면 하나", GameState.stats.get("chores", 0), 1)


## 붉은 달: 달이 뜬 뒤로 스무 마리. 달이 지면 처음부터 다시 센다
func _moon() -> void:
	var G := GameState
	G.event = "BLOOD_MOON"
	_has("blood_moon", false)   # 달이 뜬 순간의 처치 수를 적어 둔다
	G.stats.kills.SLIME = G.stats.kills.get("SLIME", 0) + 19
	_has("blood_moon", false)
	G.stats.kills.SLIME += 1
	_has("blood_moon")
	G.event = null
	_has("blood_moon", false)
	G.event = "BLOOD_MOON"
	_has("blood_moon", false)   # 새 달은 처음부터
	G.event = null


## 세이브에 남는 값: 하나씩 채우면 그 과제가 열린다 (경계에서는 닫혀 있는지도 본다)
func _saved() -> void:
	var G := GameState
	var p = G.player
	for b in ["MORGATH", "ZALGORA", "GLACIA", "BASIL", "IGNAR"]:
		G.bossesDefeated[b] = true
		_has(b.to_lower())
	for route in ["guardian", "redeem", "dark"]:
		G.story.endingSeen = route
		_has("ending_" + route)
	for i in 3:
		p.stage_index = i + 1
		_has(["stage_teen", "stage_adult", "stage_elder"][i])
	_has("fusion")       # _counted 에서 한 번 쐈다
	_has("first_down")   # _counted 에서 한 번 쓰러졌다
	G.stats.kills = { SLIME = 1 }
	_has("first_kill")
	_has("many_kills", false)
	G.stats.kills.HUNTER = 299
	_has("many_kills")
	G.stats.eliteOffer = true
	_has("first_elite")
	G.stats.brinks = 1
	_has("brink")
	G.raid.count = 5
	G.raid.active = true
	_has("raid_defender", false)   # 5차가 한창이면 아직 넷을 막은 것이다
	G.raid.active = false
	_has("raid_defender")
	G.den.built = true
	_has("nest")
	G.kids.append({ stage = "TEEN" })
	_has("first_kid")
	_has("kid_grown", false)
	G.kids[0].stage = "ADULT"
	_has("kid_grown")
	G.kids.clear()   # 가짜 아이는 저장하면 안 된다 (Save 가 아이의 개체를 읽는다)
	Romance.on_partnered(World.any_npc("Mira"))
	_has("partner")
	Romance.L().vow = { with = "Mira", day = G.day }
	_has("vow")
	World.any_npc("Poco").relation = 74
	_has("best_friend", false)
	World.any_npc("Poco").relation = 75
	_has("best_friend")
	for i in 7: G.denDecor.append({ id = "FIREPLACE", tx = 2 + i, ty = 2 })   # 아늑함 6 × 7 = 42 → '내 집'
	_has("cozy_den")
	G.stats.chores = 10
	_has("chore_regular")
	for id in ["m1", "r1", "w1", "p1", "p2", "t1", "t2", "g1"]: G.quests.done.append(id)
	_has("requests", false)   # 본 이야기 · 건네받은 속성은 세지 않는다. 부탁은 아직 다섯
	G.quests.done.append("n1")
	_has("requests")
	G.day = 99
	_has("hundred_days", false)
	G.day = 100
	_has("hundred_days")
	var stones: Array = Travel.stone_maps()
	G.waystones = stones.slice(0, stones.size() - 1)
	_has("waystones", false)
	G.waystones = stones.duplicate()
	_has("waystones")
	G.story.delve = { FOREST_HOLE = { best = 4, claimed = [] } }
	_has("delve_5", false)
	G.story.delve.FOREST_HOLE.best = 5
	_has("delve_5")
	_has("delve_8", false)
	G.dungeon = { id = "FOREST_HOLE", depth = 8 }   # 아직 굴 안: 나와야 적히는 기록보다 먼저 센다
	_has("delve_8")
	G.dungeon = null
	G.stats.fish = 20
	_has("angler")
	var relics: Array = Data.get_module("systems_relics").RELICS.keys()
	G.relics = relics.slice(0, 9)
	_has("relic_collector", false)
	G.relics = relics.slice(0, 10)
	_has("relic_collector")
	G.story.tryst = { day = -1, fails = 1 }
	_has("sneak_caught")
	_check("과제 35개가 모두 한 번씩 열렸다", _seen.size(), 35)


## 알리기: 한 번에 하나씩, 다 알린 뒤에는 더 알리지 않는다
func _send() -> void:
	Achievements.reset()
	var n: int = Achievements.earned().size()
	Achievements.check()
	_check("한 번에 하나만 알린다", Achievements._sent.size(), 1)
	for i in n + 5: Achievements.check()
	_check("이룬 것을 다 알리면 멈춘다 (%d개)" % n, Achievements._sent.size(), n)


## 설정의 테스트 단추를 쓴 판은 더 알리지 않는다
func _tested() -> void:
	Achievements.reset()
	_main.hud.settings._test_level()
	_check("테스트 단추를 쓰면 판에 표시가 남는다", GameState.story.get("flags", {}).get("tested", false), true)
	Achievements.check()
	_check("표시가 남은 판은 알리지 않는다", Achievements._sent.size(), 0)


func _has(id: String, want := true) -> void:
	var got: bool = Achievements.earned().has(id)
	if got: _seen[id] = true
	_check("%s %s" % [id, "열림" if want else "닫힘"], got, want)


func _check(what: String, got, want) -> void:
	var ok: bool = str(got) == str(want)
	if not ok: _bad += 1
	print("%s %s  (%s%s)" % ["OK  " if ok else "틀림", what, str(got), "" if ok else " · 기대 %s" % str(want)])
