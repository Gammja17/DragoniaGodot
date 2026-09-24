extends Node
## 결말 세 갈래를 끝까지 돈다: 이그나르와의 대면 → 싸움 → 무릎 꿇기 → 고르기 → (암전) 저녁 → 마지막 장 → 에필로그 → 크레딧 → 자유롭게
##   godot --headless --path . res://tools/test_ending.tscn -- guardian | redeem | dark
## 대화는 저절로 넘기고, 고를 것은 길에 맞는 줄을 고른다. 크레딧은 2초 보고 건너뛴다.

var _route := "guardian"
var _log := []
var _shots := ""       # 두 번째 인자로 폴더를 주면 (창을 띄워 돌릴 때) 장면마다 사진을 남긴다
var _n := 0
var _last_shot := 0
var _last_text := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_route = args[0] if args.size() > 0 else "guardian"
	_shots = args[1] if args.size() > 1 else ""
	if _shots != "": DirAccess.make_dir_recursive_absolute(_shots)
	Save.slot = 9
	Save.delete()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.play_intro = false
	main.load_save = false
	add_child(main)
	await get_tree().process_frame
	_setup()
	# 화산 꼭대기로
	World.travel_to("IGNAR_LAIR")
	await _wait(0.5)
	var p: Dragon = GameState.player
	var b: Boss = GameState.entities.bosses[0]
	p.x = b.x; p.y = b.y + 460
	print("[대면 전] m6=%s 보스 깨어남=%s" % [GameState.quests.active.get("m6"), b.awake])
	# 대면 장면과 고르기
	await _play_until(func(): return GameState.story.get("choices", {}).has("ev_ignar_meet") and not Chronicle._playing, 40)
	print("[대면] 고른 것=%s 길=%s" % [GameState.story.choices.get("ev_ignar_meet"), GameState.story.get("route")])
	if _route == "dark":
		await _dark_path()
	else:
		await _fight_and_choose(b)
	# 결말이 흐른다
	var t0 := Time.get_ticks_msec()
	var saw_credits := false
	while Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
		if Credits.is_rolling():
			if not saw_credits:
				saw_credits = true
				print("[크레딧] 올라간다 (%.1f초)" % ((Time.get_ticks_msec() - t0) / 1000.0))
				await _wait(2.0)
				Credits.current.skip()
			continue
		_advance()
		if not Ending.playing and Ending.seen(): break
	await _wait(1.0)
	print("[끝] 결말=%s 크레딧=%s m6=%s m7d=%s 지도=%s 날=%d 시각=%.2f 대화=%s 컷씬=%s" % [GameState.story.get("endingSeen"), saw_credits,
		"완료" if GameState.quests.done.has("m6") else GameState.quests.active.get("m6"),
		"완료" if GameState.quests.done.has("m7d") else GameState.quests.active.get("m7d"),
		GameState.map_id, GameState.day, GameState.dayTime, GameState.isDialogueOpen, Cutscene.on])
	print("[결말 뒤] 습격 오는가=%s 본 장면=%s 유물=%s" % [Raid._still_coming(), GameState.story.scenes.filter(func(s): return s.begins_with("ending")), GameState.relics])
	print("[장면 순서] %s" % " → ".join(_log))
	if DialogueBox.is_open(): print("[그 뒤 열린 대화] %s | %s | 제목=%s" % [DialogueBox.current._name.text, DialogueBox.current._text.text.left(50), Cutscene.title])
	get_tree().quit()


## 8장 정상 직전의 판
func _setup() -> void:
	var G := GameState
	var p: Dragon = G.player
	G.elderTutorialDone = true
	G.tutorial.finished = true
	G.quests.done = ["m0", "m1", "m2", "m3", "m4", "m5", "m5g", "m5a", "m6w", "m5b", "m5c"]
	G.quests.active = { m6 = { step = 3, n = 0 } }
	G.quests.tracked = "m6"
	G.bossesDefeated = { MORGATH = true, ZALGORA = true, GLACIA = true, BASIL = true }
	G.story.events = ["ev_morgath", "ev_zalgora", "ev_glacia", "ev_basil", "ev_ignar", "ev_falls", "ev_gathering", "ev_border", "ev_city", "ev_volcano", "ev_volcano_path", "ev_messenger"]
	G.story.scenes = ["ch1", "ch1b", "ch3", "ch4", "ch5", "dream_ice", "dream_thunder", "dream_city", "ch6"]
	G.story.clues = ["mark", "breath", "seiran", "sky", "city", "brother"]
	G.story.rites = [1, 2, 3]
	G.story.flags = { messenger = true, gron_dead = true }
	G.story.dead = ["Gron"]
	G.raid.count = 6
	G.visited = ["VILLAGE", "EAST_ROAD", "DOJO", "LAKE", "SOUTH_ROAD", "FALLS", "CLOUDTOP", "VOLCANO", "VOLCANO_PATH", "IGNAR_LAIR", "SKY_RUINS"]
	p.level = 14
	p.stage_index = 3
	p.elements = ["FIRE", "ICE", "THUNDER"]
	p.max_hp = 6000; p.hp = 6000


func _fight_and_choose(b: Boss) -> void:
	var t0 := Time.get_ticks_msec()
	while not b.awake and Time.get_ticks_msec() - t0 < 10000:
		await get_tree().process_frame
		_advance()
	await _wait(1.0)
	print("[싸움] 깨어남=%s 막대=%s" % [b.awake, Hud.current.get_node("BossBar").visible])
	# 마지막 판 앞에서 카이론이 내려앉는 장면이 끼므로 (한 방에 쓰러뜨려도 그 판부터 다시), 무릎 꿇을 때까지 친다
	for i in 3:
		if b.lingering or b.dying > 0: break
		b.take_damage(b.hp + 1)
		await _play_until(func(): return b.lingering or (not b.yielding and not Cutscene.on), 20)
	await _play_until(func(): return b.lingering, 10)
	print("[무릎] 남음=%s m6=%s" % [b.lingering, GameState.quests.active.get("m6")])
	await _play_until(func(): return GameState.story.get("choices", {}).has("ev_ignar_fall") or Ending.playing, 40)
	print("[쓰러진 뒤] 고른 것=%s 결말 흐름=%s" % [GameState.story.get("choices", {}).get("ev_ignar_fall"), Ending.playing])


## 어둠의 길: 베스나 → 마을 어귀 → 스승과의 대결에서 이긴다
func _dark_path() -> void:
	var m7d = Quests.by_id("m7d")
	print("[어둠] m7d=%s" % GameState.quests.active.get("m7d"))
	Quests.complete_step(m7d, false)   # 베스나와 불가의 밤
	await _play_until(func(): return GameState.questScenes.is_empty() and not Chronicle._playing and not DialogueBox.is_open(), 40)
	World.travel_to("VILLAGE")
	await _play_until(func(): return GameState.activity != null, 40)
	print("[대결] 상대=%s 기력=%s" % [GameState.activity.npc.config.name if GameState.activity else "-", GameState.activity.get("hp") if GameState.activity else "-"])
	GameState.activity.hp = 0
	await _play_until(func(): return Ending.playing, 20)


func _play_until(cond: Callable, sec: float) -> void:
	var t := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t < sec * 1000:
		await get_tree().process_frame
		_advance()


var _last := 0
var _last_title := ""
## 장면을 넘긴다. 고를 것이 있으면 길에 맞는 줄을
func _advance() -> void:
	_maybe_shoot()
	if Hud.chapter_card_on(): Hud.skip_chapter_card()
	if Time.get_ticks_msec() - _last < 200: return
	_last = Time.get_ticks_msec()
	if Cutscene.title != "" and Cutscene.title != _last_title:
		_last_title = Cutscene.title
		_log.append(Cutscene.title)
	if Cutscene.busy() and not DialogueBox.is_open():
		Cutscene.rush()
		return
	if not DialogueBox.is_open(): return
	var box := DialogueBox.current
	if _shots != "" and box.typing(): return   # 사진을 찍을 때는 글이 다 찍히길 기다린다
	box._text.visible_characters = -1
	var want := 0
	var labels: Array = box._list.map(func(o): return o.label)
	for i in labels.size():
		var l: String = labels[i]
		if _route == "dark" and l.begins_with("…계속 말해"): want = i
		if _route == "redeem" and l.find("같이 가자") >= 0: want = i   # 말로 하는 선택지는 따옴표로 묶여 있다
		if _route == "guardian" and l == "끝낸다": want = i
	box._choose(want)


func _wait(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000: await get_tree().process_frame


func _maybe_shoot() -> void:
	if _shots == "": return
	var now := Time.get_ticks_msec()
	var text: String = DialogueBox.current._text.text if DialogueBox.is_open() and not DialogueBox.current.typing() else ""
	if (text != "" and text != _last_text) or now - _last_shot > 900:
		_last_text = text if text != "" else _last_text
		_last_shot = now
		_shoot()


func _shoot() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%03d.png" % [_shots, _n])
	_n += 1
